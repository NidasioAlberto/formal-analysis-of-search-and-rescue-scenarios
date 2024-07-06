#import "polimi-thesis-classical-format/src/lib.typ": puttitle
#import "@preview/wrap-it:0.1.0": wrap-content

#show: doc => puttitle(
  title: [Formal Analysis of Search-and-Rescue Scenarios],
  subtitle: [Project for Formal Methods for Concurrent and Realtime Systems course],
  authors: ("Alberto Nidasio", "Federico Mandelli", "Niccolò Betto"),
  student_id: none,
  advisor: "Prof. Pierluigi San Pietro",
  coadvisor: "Dr.  Livia Lestingi",
  academic_year: [2023-24],
  doc,
)

= Abstract

This document presents a formal model implemented with #link("https://uppaal.org/")[Uppaal] of search-and-rescue scenarios. Inside a rectangular map of arbitrary size, civilian _survivors_ have to be brought to safety by either reaching an exit or being assisted by _first-responders_. _Drones_ surveys the area and coordinate the rescue efforts by instructing _survivors_ on what to do. The model then undergoes formal verification to highlight key behavioral aspects and identify optimal configurations for maximizing _survivor_ safety.

#show outline.entry.where(
  level: 1
): it => {
  v(12pt, weak: true)
  strong(it)
}
#outline(indent: auto)


#pagebreak()

#set heading(numbering: "1.1")

= High Level Model Description

The model adopted for the search-and-rescue mission involves 3 different types of agents: _survivors_, _first-responders_ and _drones_. They are placed in different numbers inside a rectangular map, where exits (i.e. safe zones reached by survivors to get to safety) and fires are fixed in placed from the beginning of the scenario.

The key characteristics of the agents are these:
- *Survivors*: Can be in 3 different states, depending whether they find themselves near a fire or if they are following instructions
  - *In-need* (i.e. near a fire): They cannot move and needs to be assisted. After $T_v$ time units, they became a casualty
  - *Busy*: The survivor is following an instructions and can be either assisting directly or contacting a _first-responder_ to get help
  - *Moving*: When survivors are not near a fire or busy enacting some instruction, they can move towards an exit to get to safety following some _moving policy_
- *First-responders*:
  - *Assisting*: When a survivor _in-need_ is within a 1-cell range, the _first-responder_ will assist them for $T_"fr"$ time units. After that, the assisted survivor is considered safe
  - *Moving*: When free from other tasks, the _first-responder_ can move following some _moving policy_
- *Drones*: They survey their surroundings, limited by the field of view $N_v$ of the sensors, and following a pre-determined path moving 1 cell at each time step. When two survivors, one _in_need_ and one free, are detected the drone can instruct the free survivor to assist the _in_need_ directly or to contact a _first-responder_

== Model Assumptions

To simplify the model described in the assignment, the following assumptions have been made:
- The map is a 2D grid with a fixed number of rows and columns, and fires and exits are static (i.e. they won't change during simulation)
- Movements from one cell to another allows for diagonal movements. Therefore, the distance can be esily computed as the maximum between the difference of the x and y coordinates
- Movements of _survivors_ and _first-responders_ towards a human target (e.g. a _survivor_ goes to a _first-responder_), are modeled with a wait state, where the agents remains idle for the duration of the movement, and then with a change in coordinates. This reduces the complexity of the model, lowering the number of states of the simulation and thus speeding up the verification process
- Drones know the global position of all the _first-responders_ and their status, at any given time. This allows them to instruct _survivors_ to contact the nearest _first-responder_
- All _survivors_ know the location of the exits and can determine the nearest one
- _survivors_ cannot start the simulation inside a fire cell

#pagebreak()

= Model Description and Design Choices

== State and Parameters Representation

// The model is implemented in Uppaal, a tool that allows to model, validate and verify NTAs and NSTAs.

Each agent type (_survivor_, _first-responder_, _drone_) is represented by an automaton, called *template* in Uppaal. These templates are characterized by many different parameters, and are implemented in Uppaal in the following way:
- The template signature (the parameters list) contains only one constant parameter, the agent id, annotated with a custom type defined as an integer with the range of possible ids (e.g. `typedef int[0, N_DRONES-1] drone_t;`). This way, by listing the template names in the _System declarations_ (`system Drone, Survivor, FirstResponder;`), Uppaal can automatically generate the right number of instances of each template;
- The other agents' parameters (e.g. $N_v$, $N_r$, $T_"zr"$, etc.) are defined in constant global arrays (e.g. `const int N_v[drone_t] = {1, 1};`). Each template instance can then index these arrays with its own id as an index for these arrays (e.g. `N_v[id]`).

This setup allows to easily define the simulation parameters all inside the _Declarations_ section, thus without modifying neither the templates nor the _System declarations_, and to easily assign different parameters to each template instance.

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
Desipite each agent holding internally its own position, a global representation of the map is needed for agents who require to know the state of other agents (e.g. drones need to know the position of _first-responders_ to instruct _survivors_ to contact them).

The map is represented as a 2D grid of cells, with each cell indicating which type of human agent is within (drones positions are not neeed, so they are not included in this representation). This choice is made to avoid each agent holding a reference to all other agents, which would make the model more complex and harder to maintain.

When one agent changes position, it updates the map accordingly. For example, when a _survivor_ moves, it empties the cell it was occupying and fills the new cell with its type.

```cpp
  void move(int i, int j) {
    set_map(pos, CELL_EMPTY);
    pos.x += i;
    pos.y += j;
    set_map(pos, CELL_SURVIVOR);
}
```
]

== Syncronization and Message Passing

Between the different agents, there are some interactions that require a way to pass a payload. For example, when a _survivor_ is instructed by a _drone_ to contact a _first-responder_, the _survivor_ must receive from the _drone_ both the positions of the _first-responder_ and that of the one _in-need_ to assist.

This synchronization with message passing is implemented via Uppaal's built-in channels, augmented with global variables used to temporarily store the payload. The channels themselves are 2D matrices to allow targeting a specific agent. Each agent can trigger a channel at a given coordinate or listen at a channel on its own current position.

Following the previous example, the synchronization follows these steps:
1. The _drone_ saves the positions of the target _first-responder_ and _in-need_ in two global variables and then triggers the channel at the coordinates of the targeted _survivor_.
2. The _survivor_, upon receiving the signal through the channel, reads the global variables to get the positions of the _first-responder_ and _in-need_.

#align(center, image("images/Synchronization and message passing.png", width: 8cm))

== Moving Policies

Both _survivors_ and _first-responders_ are characterized by a custom moving policy. _Survivors_ use this moving policy to reach the nearest exit, while _first-responders_ use it to reach a _survivor_ in need of assistance.

These moving policies all function in the same way, given a target position they produce the next move to take towards the target. Therefore they can be abstracted and implemented in a generalized way.

In order to support random choices, the moving policy implementation works as follows:
- On the edge where we want to perform the move, a non-deterministic selection of offets `i` and `j` is performed to identify a possible adjacent cell to move to (shown in @moving_policy_edge);
- The function `is_move_valid(i, j)` evaluates whether a given adjacent cell is a valid move or not, using the selected moving policy.


To experiment with different moving policies, we have impleted 2 simple policies:
- The *random* policy simply checks if the move is feasible (i.e. wheter the cell is not occupied by a fire or another agent). In @moving_policy_random we can see that the move is valid if the cell is empty. By "enablig" all the feasible moves, the model non-deterministically selects one of them;
- The *direct* policy enables only the moves with the lowest direct distance to the target. As shown by @moving_policy_direct, if more than one adjacent cell have the same distance to the target, the policy enables all of them and the model will randomly select among those.

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

```cpp
// Random policy allows all movements that are feasible
bool random_is_move_valid(pos_t pos, pos_t move, pos_t target, cell_t type) {
    return is_move_feasible(pos, move, type);
}

// Direct policy follows the best direct path (i.e. without considering obstacles)
bool direct_is_move_valid(pos_t pos, pos_t move, pos_t target, cell_t type) {
    int min_distance;

    if (!is_move_feasible(pos, move, type))
        return false;

    // Find the distance to the target of the best possible move
    min_distance = compute_best_move_distance(pos, target, type);

    // A move to be valid must have minimum distance among the possible moves
    return distance(move, target) == min_distance;
}
```

== Templates

=== Initializer

=== Surivor

At the beginning of the simulation, _survivors_ position themselves in the map; if they are near a fire they become _in_need_ otherwise they are considered _survivors_.

+ _in_need_: The survivor cannot move and needs to be assisted. After $T_v$ time units near a fire, they became a casualty, if assisted in time they are considered safe. In both cases they leave the simulation freeing the map cell they were occupying.
+ _survivors_: The survivor moves towards an exit following a _moving policy_. If they are within a 1-cell range from an exit they are considered safe and leave the simulation freeing the map cell they were occupying.
  In this state they can receive instructions from the drone to either assist a _in_need_ survivor or to contact a _first-responder_ to get help.
  - Assisting a _in_need_ survivor: The survivor "moves" towards the _in_need_ survivor by staying in the same cell for the time needed to reach the _in_need_ (the distance between the two). The survivor "assist" the _in_need_ by waiting $T_"zr"$. After that the survivor is considered safe and leaves the simulation.
  - Calling a First responder: The survivor "moves" towards the _first-responder_ by staying in the same cell for the time needed to reach the _first-responder_ (the distance between the two). The survivor "calls" the _first-responder_ that will assist the _in_need_ survivor. When the _first-responder_ ends the assist the survivor is considered safe and leaves the simulation.

At the end of the simulation all survivors are either safe or casualties.

=== First-responder

#lorem(50)

=== Drone

#lorem(50)

=== Initializer

#lorem(50)

= Properties
#lorem(50)

= Conclusion
#lorem(50)