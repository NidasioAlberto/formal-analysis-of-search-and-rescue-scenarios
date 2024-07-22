#import "polimi-thesis-classical-format/src/lib.typ": puttitle
#import "@preview/wrap-it:0.1.0": wrap-content

#show: doc => puttitle(
  title: [Formal Analysis of Search-and-Rescue Scenarios],
  subtitle: [Project for Formal Methods for Concurrent and Realtime Systems course],
  authors: ("Alberto Nidasio", "Federico Mandelli", "Niccolò Betto"),
  student_id: none,
  advisor: "Prof. Pierluigi San Pietro",
  coadvisor: "Dr. Livia Lestingi",
  academic_year: [2023-24],
  doc,
)

= Abstract

This document presents a formal model implemented with #link("https://uppaal.org/")[Uppaal] of search-and-rescue scenarios. Inside a rectangular map of arbitrary size, civilian _survivors_ have to be brought to safety by either reaching an exit or being assisted by _first-responders_. _Drones_ survey the area and coordinate the rescue efforts by instructing _survivors_ on what to do. The model then undergoes formal verification to highlight key behavioral aspects and identify optimal configurations for maximizing _survivors'_ safety.

#show outline.entry.where(
  level: 1
): it => {
  v(12pt, weak: true)
  strong(it)
}
#outline(indent: auto)

#pagebreak()

#set heading(numbering: "1.1")

= High-Level Model Description

The model adopted for the search-and-rescue mission involves 3 different types of agents: _survivors_, _first-responders_ and _drones_. They are placed in different numbers inside a rectangular map, where exits (i.e. safe zones reached by _survivors_ to get to safety) and fires are fixed in place from the beginning of the simulation.

The key characteristics of the agents are these:
- *Survivors*: Can be in 3 different states, depending whether they find themselves near a fire or if they are following instructions.
  - *In-need* (i.e. near a fire): They cannot move and needs to be assisted. After $T_v$ time units, they became a casualty and die.
  - *Busy* (acting as _zero-responders_): The _survivor_ is following an instruction and can be either assisting directly or contacting a _first-responder_ to get help.
  - *Moving*: When _survivors_ are not near a fire or busy enacting some instruction, they can move towards an exit to get to safety following some _moving policy_.
- *First-responders*:
  - *Assisting*: When a survivor _in-need_ is within a 1-cell range, the _first-responder_ will assist them for $T_"fr"$ time units. After that, the assisted _survivor_ is considered safe.
  - *Moving*: When free from other tasks, the _first-responder_ can move following some _moving policy_.
- *Drones*: They survey their surroundings, limited by the field of view $N_v$ of the sensors, and following a pre-determined path moving 1 cell at each time step. When two _survivors_, one _in-need_ and one free, are detected, the _drone_ can instruct the free _survivor_ to assist the one _in-need_ directly or to contact a _first-responder_.

== Model Assumptions

To simplify the model described in the assignment, the following assumptions have been made:
- The map is a 2D grid with a fixed number of rows and columns, and fires and exits are static (i.e. they won't change during simulation).
- Movements from one cell to another allows for diagonal movements. Therefore, the distance can be easily computed as the maximum between the difference of the x and y coordinates.
- Movements of _survivors_ and _first-responders_ towards a human target (e.g. a _survivor_ goes to a _first-responder_), are modeled with a wait state, where the agents remains idle for the duration of the movement, and then with a change in coordinates. This reduces the complexity of the model, lowering the number of states of the simulation and thus speeding up the verification process.
- _Drones_ know the global position of all the _first-responders_ and their status, at any given time. This allows them to instruct _survivors_ to contact the nearest _first-responder_.
- All _survivors_ know the location of the exits and can determine the nearest one.
- _Survivors_ cannot start the simulation inside a fire cell.

#pagebreak()

= Model Description and Design Choices

== Faster Model <faster_model>

After developing the model described below we discovered that the verification process was too slow, making it difficult to test different scenarios and configurations. To speed up the verification process, we have made some changes to the model described in the following sections. Instead of modeling the interaction between the actors, as they happen in real life, we model only the necessary part of it. Instead of the actors moving on the map, we model the movement as a wait states. This means that when an agent is instructed to move to a certain position, it will wait for a specific amount of time before teleport to the target position. If a movement is composed of different steps ( i.e. _zero-responder_ going to call a _fist-responder_ and then back to the _in-need_) it is now modelled as a unique wait state of the time needed to travel that distance. This simplifies the model and reduces the number of states and transitions, which in turn speeds up the verification process.

When a _drone_ detects a survivor _in-need_ and a _zero-responder_ (and a _first-responder_ if needed), it sends a message to the _zero-responder_ with the correct wait time (depending on the distance and the assistance time). The same applies to the _first-responder_ (if needed) and the _in-need_, so that the _in-need_ waits either until they are dead or the wait time has expired (becoming safe).

To reduce computation, frequently used variables are stored in global variables, i.e. instead of searching for the position of an actor in the map we store it in a global variable.

In each of the following sections we will describe the model as it was before the changes, and then we will describe the changes made to the model.

== State and Parameters Representation

// The model is implemented in Uppaal, a tool that allows to model, validate and verify NTAs and NSTAs.

Each agent type (_survivor_, _first-responder_, _drone_) is represented by an automaton, called *template* in Uppaal. These templates are characterized by many different parameters, and are implemented in Uppaal in the following way:
- The template signature (the parameters list) contains only one constant parameter, the agent id, annotated with a custom type defined as an integer with the range of possible ids (e.g. `typedef int[0, N_DRONES-1] drone_t;`). This way, by listing the template names in the _System declarations_ (`system Drone, Survivor, FirstResponder;`), Uppaal can automatically generate the right number of instances of each template;
- The other agents' parameters (e.g. $N_v$, $N_r$, $T_"zr"$, etc.) are defined in constant global arrays (e.g. `const int N_v[drone_t] = {1, 1};`). Each template instance can then index these arrays with its own id to access its own parameters (e.g. `N_v[id]`).

This setup allows for easily defining the simulation parameters all inside the _Declarations_ section, thus without modifying either the templates or the _System declarations_, and to easily assign different parameters to each template instance.

In the *faster model* some of the agents parameters are stored in variables, not arrays, loosing the possibility to specify different parameters for each agent but reducing the complexity of the drone template.
=== Map Representation

#wrap-content(rect(fill: luma(240), radius: 1mm, inset: 0.5em, [
```cpp
// Map cell status enumeration
const int CELL_EMPTY =      0;
const int CELL_FIRE =       1;
const int CELL_EXIT =       2;
const int CELL_FIRST_RESP = 3;
const int CELL_SURVIVOR =   4;
const int CELL_ZERO_RESP =  5;
const int CELL_IN_NEED =    6;
const int CELL_ASSISTED =   7;
const int CELL_ASSISTING =  8;

typedef int[0, 8] cell_t;

// Map array
cell_t map[N_COLS][N_ROWS];
```
]), align: right)[
Despite each agent holding internally its own position, a global representation of the map is needed for agents who require to know the state of other agents (e.g. _drones_ need to know the position of _first-responders_ to instruct _survivors_ to contact them).

The map is represented as a 2D grid of cells, with each cell indicating which type of human agent is within. This choice is made to avoid each agent holding a reference to all other agents, which would make the model more complex and harder to maintain.

When one agent changes position, it updates the map accordingly. For example, when a _survivor_ moves, it empties the cell it was occupying and fills the new cell with its type.
]

#align(center, rect(fill: luma(240), radius: 1mm, inset: 0.5em, [
```cpp
  void move(int i, int j) {
    set_map(pos, CELL_EMPTY);
    pos.x += i;
    pos.y += j;
    set_map(pos, CELL_SURVIVOR);
}
```
]))

In the *faster model* other then the map the position of each actor (and exit) is stored in an array and updated at each movement to reduce calculation in the following templates.

== Synchronization and Message Passing

Between the different agents, there are some interactions that require a way to pass a payload. For example, when a _survivor_ is instructed by a _drone_ to contact a _first-responder_, the _survivor_ must receive from the _drone_ both the positions of the _first-responder_ and that of the one _in-need_ to assist.

This synchronization with message passing is implemented via Uppaal's built-in channels, augmented with global variables used to temporarily store the payload. The channels themselves are 2D matrices to allow targeting a specific agent. Each agent can trigger a channel at a given coordinate or listen to a channel at its own current position.

Following the previous example, the synchronization follows these steps:
1. The _drone_ saves the positions of the target _first-responder_ and _in-need_ in two global variables and then triggers the channel at the coordinates of the targeted _survivor_.
2. The _survivor_, upon receiving the signal through the channel, reads the global variables to get the positions of the _first-responder_ and _in-need_.

#align(center, image("images/Synchronization and message passing.png", width: auto))

In the *faster model* the message passing is simplified by only passing, to all the actors involved, the total waiting time needed to complete the action.
This could be a drone passing the waiting time to a _zero-responder_ , _in-need_ and _first-responder_ (if present) or a _first-responder_ passing the waiting time to the _in-need_.
== Moving Policies

Both _survivors_ and _first-responders_ are characterized by a custom moving policy. _Survivors_ use this moving policy to reach the nearest exit, while _first-responders_ use it to reach a _survivor_ in need of assistance.

These moving policies all function in the same way; given a target position, they produce the next move to take towards the target. Therefore, they can be abstracted and implemented in a generalized way.

A move is considered valid if the target is in the map bound and the cell is empty, i.e. not occupied by a fire or another agent.

In order to support random choices, the moving policy implementation works as follows:
- On the edge where we want to perform the move, a non-deterministic selection of offsets `i` and `j` is performed to identify a possible adjacent cell to move to (shown in @moving_policy_edge);
- The function `is_move_valid(i, j)` evaluates whether a given adjacent cell is a valid move or not, using the selected moving policy.

To experiment with different moving policies, we have implemented 2 simple policies:
- The *random* policy simply checks if the move is feasible (i.e. whether the cell is not occupied by a fire or another agent). In @moving_policy_random we can see that the move is valid if the cell is empty. By "enabling" all the feasible moves, the model non-deterministically selects one of them;
- The *direct* policy enables only the moves with the lowest direct distance to the target. As shown by @moving_policy_direct, if more than one adjacent cell has the same distance to the target, the policy enables all of them and the model will randomly select among those.

#align(center, grid(columns: 3, gutter: 1cm, align: bottom,
  [#figure(
    image("images/Moving policy edge.png", width: 4cm),
    caption: [Moving edge]
  ) <moving_policy_edge>],
  [#figure(
    image("images/Moving policy random.png", width: 4cm),
    caption: [\ Moving policy `RANDOM`]
  ) <moving_policy_random>],
  [#figure(
    image("images/Moving policy direct.png", width: 4cm),
    caption: [\ Moving policy `DIRECT`]
  ) <moving_policy_direct>]
))

Below are the implementations of the two moving policies. The _direct_ policy computes the distance of the best feasible move to the target, and then enables all those moves with that same distance. The policy is implemented this way in order to avoid preferring one direction over another if more than one move has the same distance to the target.

#rect(fill: luma(240), radius: 1mm, inset: 0.5em, [
```cpp
// Random policy allows all movements that are feasible
bool random_is_move_valid(pos_t pos, pos_t move, pos_t target, cell_t type) {
    return is_move_feasible(pos, move, type);
}

// Direct policy follows the best direct path
bool direct_is_move_valid(pos_t pos, pos_t move, pos_t target, cell_t type) {
    int min_distance;

    if (!is_move_feasible(pos, move, type))
        return false;

    // Find the distance to the target of the best possible move
    min_distance = compute_best_move_distance(pos, target, type);

    // A move to be valid must have minimum distance
    return distance(move, target) == min_distance;
}
```
])

Both moving are not changed in the *faster model* except for using the position of actors stored in the global arrays when needed.

== Templates

=== Initializer

#wrap-content(rect(fill: luma(240), radius: 1mm, inset: 0.5em, [
```cpp
void init_map() {
  // Fires
  map[4][3] = CELL_FIRE;
  map[4][4] = CELL_FIRE;
  ...

  // Exits
  map[0][4] = CELL_EXIT;
  map[0][5] = CELL_EXIT;
  ...
}
```
]), align: right)[
The _Initializer_ template is a simple automaton with three states and two edges used to set up the map and then start all other agents.

Its initial state is a committed state, meaning that the model must follow one of its edges right away. Its only edge runs the function `init_map()`, which configures the position of fires and exits in the map 2D array representation (agents will later set their position on their own). One could initialize the array in place in the _declarations_, but with increasing map sizes, it would become unmanageable. The use of a function allows for a clear definition of where entities are placed.

Then the _Initializer_ has a second committed state with one edge that triggers the `init_done` broadcast channel. All other agents have their initial state with a single arc that synchronizes them on the `init_done` channel. When the channel fires, all the agents perform a simple initialization step (e.g., they set their position in the map) and then they become ready for the simulation to properly start.
]

=== Survivor

At the beginning of the simulation, _survivors_ position themselves on predetermined coordinates in the map. If they are near a fire, they become survivors _in-need_ of assistance; otherwise, they are considered normal _survivors_.

Survivors _in-need_ cannot move, and if they are not assisted within a certain time period $T_v$, they become casualties. However, if they receive assistance within the time period, they become safe. This behavior is modeled by setting bounds on the _survivor_'s clock. When the time period $T_v$ is exceeded, the model transitions to the `Dead` state. In both cases, the _survivors_ leave the simulation, freeing the map cell they were occupying.

Other _survivors_ who are not near a fire default to moving towards an exit, following their designated _moving policy_. This movement can stop in four cases:
- If they move within a one-cell range of an exit, they become safe and leave the simulation, freeing the map cell they were occupying.
- If they receive an instruction from a _drone_ to directly assist someone _in-need_ or call a _first-responder_, they stop targeting an exit and start following the instruction. In both cases, the _survivor_ reaching the new target is modeled by waiting for a duration equal to the distance to the target, rather than actually moving on the map. Although this does not accurately model the simulated scenario, particularly the interaction between moving agents on the map, it is necessary to keep the model simple and maintain acceptable verification times.
- When they have no available moves. This could be due to the map topology blocking the _survivor_'s path or the moving policy not allowing any moves. For example, the `DIRECT` moving policies presented earlier can potentially lead to a _survivor_ being stuck in a loop where moving around an obstacle frees the previous cell, which is then re-selected. We deemed these cases acceptable because we considered it reasonable for the map topology to present challenges and for civilians to struggle in finding the proper path.

Note that we built the model such that _survivors_ will never move near a fire, thus they cannot become _in-need_ during the simulation.

=== First-responder

_First-responders_ defaults to moving towards the nearest survivor _in-need_, but can stop moving in 2 cases:
- When they reach the targeted survivor _in-need_ they start assisting. After $T_"fr"$ the assistance is completed and the survivor _in-need_ is considered safe;
- When they are asked by a _survivor_ to assist someone _in-need_, they stop moving to wait for the _survivor_ to reach them. This is modeled with a wait equal to the distance between the _survivor_ and the _first-responder_.

=== Drone

_Drones_ are equipped with vision sensors capable of detecting _survivors_ within a predetermined range $N_v$. When they detect both a "free" _survivor_ (a.k.a. _zero-responder_) and someone _in-need_, they can instruct the _survivor_ to assist.

When a possible _zero-responder_ and someone _in-need_ are in range of the sensors, the _drone_ start a sequence to select the agents to involve in a particular command. It first selects the possible _zero-responder_, it selects the survivor _in-need_ and then, depending on whether there is at least one _first-responder_ available or not, decides whether to make the _zero-responder_ assist directly or making him call a _first-responder_ which is then selected.

#wrap-content(
  figure(
    image("images/Drone moving pattern.png", width: 4cm),
    caption: [Drone moving pattern],
    numbering: none
  ), align: right)[
_Drones_ also have a fixed moving pattern that follows a predetermined path. This path is decided prior to the simulation and is not influenced by the state of the map or the agents. This is a simplification to keep the model complexity low and to avoid the need for the _drone_ to plan its path dynamically. The current path is a square with a parametric side length, each _drone_ can be setup with a different dimension and with a specific starting position.
]

In the *faster model* after selecting the actor needed to perform an action the _drone_ sends a message to all the actors involved with the total waiting time needed to complete the action.


= Scenarios & Properties

To highlight the strength and weaknesses of the model, we have defined a set of scenarios that we have simulated trough it. The scenarios are designed to test the model in different conditions, such as the presence of multiple fires, the distribution of agents, and the effectiveness of the moving policies.

For all models, we have established the following parameters, which are scenario-independent and cannot be controlled:
- $T_v = 30$: The time before an _in-need_ becomes a casualty;
- $T_"zr" = 10$: The time a zero-responder needs to assist an _in-need_;
The other parameters are changed to illustrate the functionality and efficiency of the system.

We always kept T_scs at 60 second to allow the system to reach a stable state before the simulation ends.
For each scenario, we calculated:
- $N%_max$: The maximum percentage of safe individuals over the total number of survivors in T_scs;
- $N%$: The guaranteed number of safe individuals within T_scs.

All the optional stochastic features have been implemented:
- The _survivors_ acknowledge the instruction and enact with probability $S#sub[listen]$, and ignore it (or miss it) with probability $1 - S#sub[listen]$. We assume _survivors_ share the same behavior, hence the same probability is used for all of them.
- The _drones_ vision sensors fail with probability $P#sub[fail]$. We assume _drones_ share the same sensors, hence the same failure probability is used for all of them.

#align(center, grid(columns: 3, gutter: 1cm, align: bottom,
  figure(
    image("images/scenario_1.png", width: 5cm),
    caption: [Plane crash],
    numbering: none
  ),
  figure(
    image("images/scenario_2.png", width: 5cm),
    caption: [Lone survivor],
    numbering: none
  ),
  figure(
    image("images/scenario_3.png", width: 5cm),
    caption: [Dividing branches],
    numbering: none
  )
))

== Plane Crash

A plane crashed and it is currently on fire. Passengers exited the plane and are scattered around the map. A single ambulance arrives on the scene, providing the _survivors_ with one exit spot. The area is free of obstacles and _survivors_ and _first-responders_ can clearly see their surroundings, therefore they are configured with the policy `DIRECT`. The scenario is considered to vary depending on two factors:
- The _drones_ vision range depends on the environment. If the incident is in an open field, the _drones_ have a larger vision range, while in a forest, the vision range is smaller;
- The ambulance staff may not be prepared to directly assisting the _survivors_, therefore _first-responders_ may not be available.

#align(center, table(columns: 9,
  [*$N_"SURV."$*], [*$N_"FR"$*], [*$N_"DRONES"$*], [*$N_v$*], [*$T_"fr"$*], [*$T_"zr"$*], [*$T_v$*], [*min $N_%$*], [*max $N_%$*],
  [8], [0], [0], [-], [5], [8], [30], [25%], [25%],
  [8], [0], [4], [1], [5], [8], [30], [25%], [25%],
  [8], [0], [4], [2], [5], [8], [30], [37,5%], [50%],
  [8], [2], [0], [-], [5], [8], [30], [100%], [100%],
  [8], [2], [4], [1], [5], [8], [30], [100%], [100%],
))

The plane crash scenario emphasizes the importance of _first-responders_ in ensuring the safety of survivors. Without _first-responders_, when more civilians are _in-need_ rather than not, there will always be someone _in-need_ that cannot be brought to safety. In this case the presence of _drones_ allows to save some lives, but this is not enough to ensure the safety of all the survivors. When instead _first-responders_ are present, all the survivors can be saved and drones could be superfluous depending on the number of _first-responders_, their training level and moving policy.

Since _drones_ are superfluous in this scenario _first_responders_ are not influenced by the failure of the drones sensors nor the probability of the _survivors_ to listen to the instructions, running the smc model yeld the same result that $N%_max$ = $N%$ = 100% independently from the probability parameters.
#figure(
    image("images/planeProb.png", width: 12cm),
    caption: [Probability of all survivors being safe after T_scs],
    numbering: none
  )

== Lone survivor

During a fire, one _first-responder_ is called to save as many lives as possible. Due to the particular topography and the lack of wind, the space is full of smoke, impeding the _first-responder_ ability to see anyone directly (moving policy `RANDOM`). On the opposite, the _survivors_ are locals and can navigate the space even with their eyes closed (moving policy `DIRECT`).



#align(center, table(columns: 9,
  [*$N_"SURV."$*], [*$N_"FR"$*], [*$N_"DRONES"$*], [*$N_v$*], [*$T_"fr"$*], [*$T_"zr"$*], [*$T_v$*], [*min $N_%$*], [*max $N_%$*],
  [6], [1], [0], [-], [5], [8], [30], [16.7%], [83.3%],
  [6], [1], [2], [1], [5], [8], [30], [50%], [66.7%],
  [6], [1], [2], [2], [4], [8], [30], [66.6%], [83.3%],
  [6], [1], [2], [2], [3], [8], [30], [66.6%], [83.3%],
  [6], [1], [2], [2], [2], [8], [30], [83.3%], [100%],
  [6], [1], [2], [2], [1], [8], [30], [83.3%], [100%],
))

In this scenario, without _drone_ assistance, the _first-responder_ is able to save a limited number of lives. This depends heavily on his inability to clearly see the survivors and reaching them directly. In very rare cases, the _first-responder_ is lucky enough to reach the _survivors_ in a very short set of moves. This is reflected by extreme values of $N_%$.

By deploying two _drones_, _survivors_ are instructed to reach out to the _first-responder_, and bring him close to the others _in-need_. In this case, the _first-responder_ will reach the group of _in-needs_ consistently more often. This is reflected in an higher $N_"%min"$, meaning that it is guaranteed that more _survivors_ will always be saved. A drawback is that we will always achieve a lower survival rate (i.e. a lower $N_"%max"$). This reflects the fact that the _first-responder_ has to wait more time for the survivor to reach him with respect to the time it would take if it could use the policy `DIRECT`.

Due to the single _first-responder_ present on the scene, a lower assist time is crucial to save more individuals. Also, since we cannot change the movement speed, we can only improve the assist time for example by providing better training or better equipment. Lowering $T_"fr"$ allows to increase the survival rate as shown by the experimental results.

Setting the probability of the _drones_ sensor to fail to 10% and the probability of the _survivors_ to listen to the instructions to 40% , we can guarantee that, within T_scs, that at least 2 survivors will be safe ($N%$ = 33%) with a probability of 96.93%.
The max possible number of survivors saved is 6 with a probability of $N%max$ = 32.40%.

#align(center, grid(columns: 3, gutter: 1cm, align: bottom,
  figure(
    image("images/lone_min.png", width: 7cm),
    caption: [2 safe],
    numbering: none
  ),
  figure(
    image("images/lone_max.png", width: 7cm),
    caption: [6 safe],
    numbering: none
  )
))

== Divided branches

First responders arriving on the scene finds a wall of fire dividing the space in two. Due to their training, all the _first-responders_ moves to the nearest _in-need_ (moving policy `DIRECT`). Survivors are also assumed to use the moving policy `DIRECT`.

#align(center, table(columns: 10,
  [*Description*], [*$N_"SURV."$*], [*$N_"FR"$*], [*$N_"DRONES"$*], [*$N_v$*], [*$T_"fr"$*], [*$T_"zr"$*], [*$T_v$*], [*min $N_%$*], [*max $N_%$*],
  [No drones], [10], [2], [0], [-], [5], [8], [30], [40%], [60%],
  [1 drone], [10], [2], [2], [1], [5], [8], [30], [50%], [60%],
))

This scenario is designed to test the effectiveness of the model to bring _first-responders_ to all groups of survivors _in-need_. With the moving policy `DIRECT`, _first-responders_ try to reach the save nearest group, and remains in that spot until all the _in-need_ individuals of that group are brought to safety. Even if enough _first-responders_ are deployed to save all _survivors_, they will be stuck on the first group while trying to assist them.

When drones are deployed, _survivors_ that are not in need of assistance are instructed to reach the _first-responders_ to bring them to their group. This effectively spreads out the _first-responders_, solving the policy's limitation. This is reflected in an higher $N_"%min"$, meaning that more _survivors_ are guaranteed to be saved.

Although an improvement is achieved, the survival rates are not improved by much. This highlights a weakness of the system: the drones always prefer the _first-responder_ when available, even if they are very far away, keeping them occupied longer. In this case to further improve the survival rate either more _fist-responders_ are needed or a better decision policy for the _drones_ has to be implemented.

With or without drones, when executing the stochastic queries we obtain $N%_max$ = $N%$ = 50%.

#figure(
    image("images/branchProb.png", width: 12cm),
    caption: [Probability of all survivors being safe after T_scs],
    numbering: none
  )
= Conclusion

In this project, we developed a model using Uppaal to simulate search-and-rescue operations involving survivors, first responders, and drones. The model is quiet flexible and almost every parameter can be changed to suit most simulations.

Developing two models allowed us at first to create a complex but true to life model, capable of simulating easier scenarios in a more expressive and easy to understand way, and then by simplifying it to understand what was essential and what could be removed in order to speed up simulation time while maintaining the same core functionalities.

Statistical model checking introduces uncertainty allowing us to understand the model's behavior in a more realistic scenario, where agents can make mistakes or fail to perform their tasks.

In conclusion, our graphical interface allows us to easily create different scenarios and our model enable us to study them, maximizing the survival rate by assessing the effect that changes in different parameters have on the system.


#pagebreak()

= Appendix

== Simulation Graphical Tool

To facilitate the development of the model we've created a graphical tool capable of visually represent and interact with the simulation model. The tool supports 3 working modes: editor, trace visualizer and live visualizer.

Creating a simulation scenario requires deciding on various parameters, such as the map dimensions, agent placements, locations of fires and exits, and specific agent parameters like a _drone_'s vision range. To facilitate the placement of entities on the map, the graphical tool can be launched in editor mode. This mode enables selective placement of entities through a combination of mouse and keyboard inputs:
- Clicking the mouse places an entity in a cell.
- Clicking again cycles through different available entities, with the cycling direction determined by the use of either the left or right mouse button.
- Clearing a cell can be accomplished by clicking the middle mouse button.
- _Drones_ can be placed by holding the shift key while clicking.
- To draw over a larger area, move the mouse while keeping the button pressed.
- Once the map design is complete, pressing `CTRL+S` generates the code required for integration into the Uppaal model.

#align(center, grid(columns: 3, gutter: 1cm, align: horizon,
  figure(
    image("images/Editor drag operation.png", width: 7.2cm),
    caption: [Editor drag operation],
    numbering: none
  ),
  figure(
    image("images/Trace visualizer.png", width: 7cm),
    caption: [Trace visualizer],
    numbering: none
  ),
))

When performing simulations in Uppaal, understanding how the scenario evolves can be really challenging. This is because through the Uppaal's interface you have access to global and template's local variables, which can be hard to decipher at a glance. To ease the understanding of the simulation, the graphical tool is able to visualize a trace file saved through the _Symbolic Simulator_. The interface visualizes for each simulation step the complete status of the map, indicating the agents' index with a number and their status (e.g. when _first-responders_ are busy assisting, an "A" appears). The user can move through the simulation with the "Previous" and "Next" buttons or with the arrow keys.

Since the live visualizer proved to be very useful, we decided to further extend its capabilities by supporting the live visualization of the simulation. To achieve this functionality, we needed a way to make an external application talk to Uppaal, which can be accomplished thanks to Uppaal's external functions. This feature allows Uppaal to call a function coded in another language during the simulation, and is implemented by dynamically linking a user-provided library. Our tool provides a simple function (`send_state_via_post_request(...)`) that sends the map status via a `POST` request to a local endpoint. This function is called at each model's update thanks to the `before_update` and `after_update` statements. The endpoint is a simple web server that runs alongside the graphical tool, that listens for the requests and updates the visualization accordingly. The tool's live visualization feature allows seeing both the symbolic or concrete simulation in real-time!