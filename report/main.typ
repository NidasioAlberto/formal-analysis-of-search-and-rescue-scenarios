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

The model adopted for the search-and-rescue mission involves 3 different types of agents: _survivors_, _first-responders_ and _drones_. They are placed in different numbers inside a rectangular map, where exits (i.e. safe zones reached by survivors to get to safety) and fires are fixed in place from the beginning of the scenario.

The key characteristics of the agents are these:
- *Survivors*: Can be in 3 different states, depending whether they find themselves near a fire or if they are following instructions.
  - *In-need* (i.e. near a fire): They cannot move and needs to be assisted. After $T_v$ time units, they became a casualty.
  - *Busy* (acting as _zero-responders_): The survivor is following an instruction and can be either assisting directly or contacting a _first-responder_ to get help.
  - *Moving*: When survivors are not near a fire or busy enacting some instruction, they can move towards an exit to get to safety following some _moving policy_.
- *First-responders*:
  - *Assisting*: When a survivor _in-need_ is within a 1-cell range, the _first-responder_ will assist them for $T_"fr"$ time units. After that, the assisted survivor is considered safe.
  - *Moving*: When free from other tasks, the _first-responder_ can move following some _moving policy_.
- *Drones*: They survey their surroundings, limited by the field of view $N_v$ of the sensors, and following a pre-determined path moving 1 cell at each time step. When two survivors, one _in-need_ and one free, are detected, the drone can instruct the free survivor to assist the one _in-need_ directly or to contact a _first-responder_.

== Model Assumptions

To simplify the model described in the assignment, the following assumptions have been made:
- The map is a 2D grid with a fixed number of rows and columns, and fires and exits are static (i.e. they won't change during simulation).
- Movements from one cell to another allows for diagonal movements. Therefore, the distance can be easily computed as the maximum between the difference of the x and y coordinates.
- Movements of _survivors_ and _first-responders_ towards a human target (e.g. a _survivor_ goes to a _first-responder_), are modeled with a wait state, where the agents remains idle for the duration of the movement, and then with a change in coordinates. This reduces the complexity of the model, lowering the number of states of the simulation and thus speeding up the verification process.
- Drones know the global position of all the _first-responders_ and their status, at any given time. This allows them to instruct _survivors_ to contact the nearest _first-responder_.
- All _survivors_ know the location of the exits and can determine the nearest one.
- _Survivors_ cannot start the simulation inside a fire cell.

#pagebreak()

= Model Description and Design Choices

== State and Parameters Representation

// The model is implemented in Uppaal, a tool that allows to model, validate and verify NTAs and NSTAs.

Each agent type (_survivor_, _first-responder_, _drone_) is represented by an automaton, called *template* in Uppaal. These templates are characterized by many different parameters, and are implemented in Uppaal in the following way:
- The template signature (the parameters list) contains only one constant parameter, the agent id, annotated with a custom type defined as an integer with the range of possible ids (e.g. `typedef int[0, N_DRONES-1] drone_t;`). This way, by listing the template names in the _System declarations_ (`system Drone, Survivor, FirstResponder;`), Uppaal can automatically generate the right number of instances of each template;
- The other agents' parameters (e.g. $N_v$, $N_r$, $T_"zr"$, etc.) are defined in constant global arrays (e.g. `const int N_v[drone_t] = {1, 1};`). Each template instance can then index these arrays with its own id to access its own parameters (e.g. `N_v[id]`).

This setup allows for easily defining the simulation parameters all inside the _Declarations_ section, thus without modifying either the templates or the _System declarations_, and to easily assign different parameters to each template instance.
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
Despite each agent holding internally its own position, a global representation of the map is needed for agents who require to know the state of other agents (e.g. drones need to know the position of _first-responders_ to instruct _survivors_ to contact them).

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

== Syncronization and Message Passing

Between the different agents, there are some interactions that require a way to pass a payload. For example, when a _survivor_ is instructed by a _drone_ to contact a _first-responder_, the _survivor_ must receive from the _drone_ both the positions of the _first-responder_ and that of the one _in-need_ to assist.

This synchronization with message passing is implemented via Uppaal's built-in channels, augmented with global variables used to temporarily store the payload. The channels themselves are 2D matrices to allow targeting a specific agent. Each agent can trigger a channel at a given coordinate or listen to a channel at its own current position.

Following the previous example, the synchronization follows these steps:
1. The _drone_ saves the positions of the target _first-responder_ and _in-need_ in two global variables and then triggers the channel at the coordinates of the targeted _survivor_.
2. The _survivor_, upon receiving the signal through the channel, reads the global variables to get the positions of the _first-responder_ and _in-need_.

#align(center, image("images/Synchronization and message passing.png", width: auto))

== Moving Policies

Both _survivors_ and _first-responders_ are characterized by a custom moving policy. _Survivors_ use this moving policy to reach the nearest exit, while _first-responders_ use it to reach a _survivor_ in need of assistance.

These moving policies all function in the same way; given a target position, they produce the next move to take towards the target. Therefore, they can be abstracted and implemented in a generalized way.

In order to support random choices, the moving policy implementation works as follows:
- On the edge where we want to perform the move, a non-deterministic selection of offsets `i` and `j` is performed to identify a possible adjacent cell to move to (shown in @moving_policy_edge);
- The function `is_move_valid(i, j)` evaluates whether a given adjacent cell is a valid move or not, using the selected moving policy.

To experiment with different moving policies, we have implemented 2 simple policies:
- The *random* policy simply checks if the move is feasible (i.e. whether the cell is not occupied by a fire or another agent). In @moving_policy_random we can see that the move is valid if the cell is empty. By "enabling" all the feasible moves, the model non-deterministically selects one of them;
- The *direct* policy enables only the moves with the lowest direct distance to the target. As shown by @moving_policy_direct, if more than one adjacent cell has the same distance to the target, the policy enables all of them and the model will randomly select among those.

#align(center, grid(columns: 3, gutter: 1cm, align: bottom,
  [#figure(
    image("images/Moving policy edge.png", width: 4cm),
    caption: [Moving edge],
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

=== Surivor

At the beginning of the simulation, _survivors_ position themselves on predetermined coordinates in the map. If they are near a fire, they become survivors _in-need_ of assistance; otherwise, they are considered normal _survivors_.

Survivors _in-need_ cannot move, and if they are not assisted within a certain time period $T_v$, they become casualties. However, if they receive assistance within the time period, they become safe. This behavior is modeled by setting bounds on the _survivor_'s clock. When the time period $T_v$ is exceeded, the model transitions to the `Dead` state. In both cases, the survivors leave the simulation, freeing the map cell they were occupying.

Other _survivors_ who are not near a fire default to moving towards an exit, following their designated _moving policy_. This movement can stop in four cases:
- If they move within a one-cell range of an exit, they become safe and leave the simulation, freeing the map cell they were occupying.
- If they receive an instruction from a _drone_ to directly assist someone _in-need_ or call a _first-responder_, they stop targeting an exit and start following the instruction. In both cases, the survivor reaching the new target is modeled by waiting for a duration equal to the distance to the target, rather than actually moving on the map. Although this does not accurately model the simulated scenario, particularly the interaction between moving agents on the map, it is necessary to keep the model simple and maintain acceptable verification times.
- When they have no available moves. This could be due to the map topology blocking the survivor's path or the moving policy not allowing any moves. For example, the `DIRECT` moving policies presented earlier can potentially lead to a survivor being stuck in a loop where moving around an obstacle frees the previous cell, which is then reselected. We deemed these cases acceptable because we considered it reasonable for the map topology to present challenges and for civilians to struggle in finding the proper path.

Note that we built the model such that _survivors_ will never move near a fire, thus they cannot become _in-need_ during the simulation.

=== First-responder

_First-responders_ defaults to moving towards the nearest survivor _in-need_, but can stop moving in 2 cases:
- When they reach the targeted survivor _in-need_ they start assisting. After $T_"fr"$ the assistance is completed and the _in-need_ survivor is considered safe;
- When they are asked by a _survivor_ to assist someone _in-need_, they stop moving to wait for the _survivor_ to reach them. This is modeled with a wait equal to the distance between the _survivor_ and the _first-responder_.

=== Drone

Drones are equipped with vision sensors capable of detecting _survivors_ within a predetermined range $N_v$. When they detect both a "free" _survivor_ (a.k.a. _zero-responder_) and someone _in-need_, they can instruct the _survivor_ to assist.

When a possible _zero-responder_ and someone _in-need_ are in range of the sensors, the drone start a sequence to select the agents to involve in a particular command. It first selects the possible _zero-responder_, it selects the survivor _in-need_ and then, depending on whether there is at least one _first-responder_ available or not, decides whether to make the _zero-responder_ assist directly or making him call a _first-risponder_ which is then selected.

#wrap-content(
  figure(
    image("images/Drone moving pattern.png", width: 4cm),
    caption: [Drone moving pattern],
    numbering: none
  ), align: right)[
Drones also have a fixed moving pattern that follows a predetermined path. This path is decided prior to the simulation and is not influenced by the state of the map or the agents. This is a simplification to keep the model complexity low and to avoid the need for the drone to plan its path dynamically. The current path is a square with a parametric side length, each drone can be setup with a different dimension and with a specific starting position.
]

= Simulation Graphical tool

To facilitate the development of the model we've created a graphical tool capable of visually represent and interact with the simulation model. The tool supports 3 working modes: editor, trace visualizer and live visualizer.

Creating a simulation scenario requires deciding on various parameters, such as the map dimensions, agent placements, locations of fires and exits, and specific agent parameters like a drone's vision range. To facilitate the placement of entities on the map, the graphical tool can be launched in editor mode. This mode enables selective placement of entities through a combination of mouse and keyboard inputs:
- Clicking the mouse places an entity in a cell.
- Clicking again cycles through different available entities, with the cycling direction determined by the use of either the left or right mouse button.
- Clearing a cell can be accomplished by clicking the middle mouse button.
- Drones can be placed by holding the shift key while clicking.
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

= Scenarios
To highlight the strength and weaknesses of the model, we have defined a set of scenarios that we have run through the model. The scenarios are designed to test the model in different conditions, such as the presence of multiple fires, the distribution of agents, and the effectiveness of the moving policies.

This scenarios are the ones used in the verification process, and are used to fine tune the parameters to reach the survival rate required.
== Basic scenario
This is the first scenario we used to test the model, it is the one used in the assignment. It was used as a benchmark to our model and to verify the correctness of the implementation and of the queries.

While verifying different query we realized that our model was too complex and slow. We then decided to simplify the model as explained in section @faster_model. This allowed us to reduce the number of states and transitions, and thus the verification time.

== Lone survivor
This scenario is designed to test the effectiveness of the model to bring a FirstResponder (moving randomly) to a group of in need of assistance. A single survivor is placed in a corner of the map near a group of in need, with the FirstResponder on the opposite corner. The survivor is tasked by the drone to go get the FirstResponder amd must navigate through the map to reach the FirstResponder to assist an in need. After that the FirstResponder start helping all the in need near him, until either all are dead or safe.

== Divided branches
This scenario is designed to test the effectiveness of the model to bring a FirstResponder (moving directly to the closest in need) to a group of in need further then the already assisted. The policy of the FirstResponder is to go to the closest in need, and then to the next closest, and so on. Without the drone assistance all the FirstResponders would go to the same in need, leaving the others to die. With our system only the needed first responder are instructed to go to the in need, while the others are left to assist other in need.

= Faster Model <faster_model>

To speed up the verification process, we have made some changes to the model. Instead of modeling the interaction between the actors, we just model the part of the interaction needed. Instead of having the actors move on the map, we have decided to model the movement as a wait state. This means that when an agent is instructed to move to a certain position, it will wait for a certain amount of time before reaching the target position. This simplifies the model and reduces the number of states and transitions, which in turn speeds up the verification process.
Instead of the various actors interacting with each other, we have decided to model the interaction as a message passing system. When a drone detects a survivor in need and a zero-responder (and a first responder if needed), it will send a message to the zero-responder with the correct time to wait (depending on the distance and the assistance time) same with the first responder (if needed) and the in need, so that it waits either until is dead or the passed wait has expired (becoming safe).

Other model specific optimization has been made to reduce computations, by saving position of actors in global variables, removing the need to search the position of the actors in the map.
= Properties
For all models we have set the following parameters as they do not depend by the scenario and cannot be controlled:
- $T_v = 30$: the time before an in need becomes a casualty;
- $T_"zr" = 10$: the time a zero responder needs to assist an in need;
The other parameters are changed to illustrate the functionality and affability of the system.

For each scenario we calculated:
- $N%_max$: The maximum number of safe in percentage over the total number of survivor (checked by: "sup{safe_survivors + dead_survivors == N_SURVIVORS}: safe_survivors")
- $N%$: The number of safe guaranteed (checked by "inf{safe_survivors + dead_survivors == N_SURVIVORS}: safe_survivors")

== Basic scenario
At first we run the basic scenario without drone assistance, to see how the system behaves without any help. Since our survivors have a self-preservation instinct, they will try to reach the nearest exit without ending a turn near the fire, one of the in need is saved by the first responder while the other is a causality since the FirstResponder cannot get to it in time; $N%_max$ = $N%$ = 88.89%.

Activating the system (enabling the drones) with $N_v$ = 1 and $N_r$ = 2 improves $N%_max$ to 100% while not changing $N%$.
Improving the drones vision to $N_v$ = 3 allow the drones better understand the situation bumping $N%$ to 100% (this is the configuration presented in faster_model_scenario_1).

== Lone survivor

== Divided branches

= Conclusion
#lorem(50)
