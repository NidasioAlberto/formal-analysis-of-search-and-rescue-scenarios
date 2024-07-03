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

This document presents a formal model implemented with #link("https://uppaal.org/")[Uppaal] of search-and-rescue scenarios. Inside a rectangular map of arbitrary size, civilians have to be brought to safety by either reaching an exit or being assisted by first-responders. Drones surveys the area and coordinate the rescue efforts by instructing civilians on what to do. The model then undergoes formal verification to highlight key behavioral aspects and identify optimal configurations for maximizing civilian safety.

#pagebreak()

#set heading(numbering: "1.1")

= High Level Model Description

The model adopted for the search-and-rescue mission involves 3 different types of agents: Civilians, First-responders and Drones. They are placed in different numbers inside a rectangular map, where exits (i.e. safe zones reached by civilians to get to safety) and fires are fixed in placed from the beginning of the scenario.

The key characteristics of the agents are these:
- *Civilians*: Can be in 3 different states, depending whether they find themselves near a fire or if they are following instructions
  - *In-need* (i.e. near a fire): They cannot move and needs to be assisted. After $T_v$ time units near a fire, they became a casualty
  - *Busy*: The civilian is following an instructions and can be either assisting directly or contacting a _first-responder_ to get help
  - *Moving*: When civilians are not near a fire or busy enacting some instruction, they can move towards an exit to get to safety following a some _moving policy_
- *First-responders*:
  - *Assisting*: When a civilian _in-need_ is within a 1-cell range, the _first-responder_ will assist them for $T_"fr"$ time units. After that, the assisted civilian is considered safe
  - *Moving*: When free from other tasks, the _first-responder_ can move following some _moving policy_
- *Drones*: They survey their surroundings, limited by the field of view $N_v$ of the sensors, and follow a pre-determined path moving 1 cell at each time step. When two civilians, one _in_need_ and one free, are detected the drone can instruct the free civilian to assist the _in_need_ directly or to contact a _first-responder_

== Model Assumptions

To simplify the model described in the assignment the following assumptions have been made:
- The map is a 2D grid with a fixed number of rows and columns, and fires and exits are static (i.e. they won't change during simulation);
- The distance between 2 cells is considered as the number of step needed to move from one cell to the other allowing diagonal movement, not the Euclidean distance;
- When a _civilian_ need to move towards someone _in_need_ or a _first-responder_, the model consider it moving for the whole duration of the movement and considering it safe at the end, without modeling the actual movement of the _civilian_;
- Drones know the global position of all the _first-responders_ and their status, at any given time;
- All _civilians_ know the location of the exits and can determine the nearest one;
- _survivors_ cannot start the simulation inside a fire cell.

= Model Description and Design Choices

== Map Representation
// image("images/assignment_scenario.jpg", width: 7cm)
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
  The map is represented as a 2D grid of cells N_COLS x N_ROWS, each cell can be in one of the following states:
  - `CELL_EMPTY`: The cell is empty and can be traversed by agents
  - `CELL_FIRE`: The cell is on fire and cannot be traversed by agents
  - `CELL_EXIT`: The cell is an exit and can be reached by civilians to get to safety
  - `CELL_FIRST_RESP`: The cell is occupied by a first-responder
  - `CELL_SURVIVOR`: The cell is occupied by a civilian in a safe state
  - `CELL_ZERO_RESP`: The cell is occupied by a civilian following a drone instruction
  - `CELL_IN_NEED`: The cell is occupied by a civilian in need of assistance
  - `CELL_ASSISTED`: The cell is occupied by a civilian _in_need_ that is being assisted
  - `CELL_ASSISTING`: The cell is occupied by a first-responder assisting a civilian
]
The map is populated by the actors described in the following sections.

== Civilian
The civilian agent is the actor in danger that needs to get to safety.

At the beginning of the simulation the civilians position themselves in the map; if they are near a fire they become _in_need_ otherwise they are considered _survivors_.

+ _in_need_: The civilian cannot move and needs to be assisted. After $T_v$ time units near a fire, they became a casualty, if assisted in time they are considered safe. In both cases they leave the simulation freeing the map cell they were occupying.
+ _survivors_: The civilian moves towards an exit following a _moving policy_. If they are within a 1-cell range from an exit they are considered safe and leave the simulation freeing the map cell they were occupying.
  In this state they can receive instructions from the drone to either assist a _in_need_ civilian or to contact a _first-responder_ to get help.
  - Assisting a _in_need_ civilian: The civilian "moves" towards the _in_need_ civilian by staying in the same cell for the time needed to reach the _in_need_ (the distance between the two). The Civilian "assist" the _in_need_ by waiting $T_"zr"$. After that the civilian is considered safe and leaves the simulation.
  - Calling a First responder: The civilian "moves" towards the _first-responder_ by staying in the same cell for the time needed to reach the _first-responder_ (the distance between the two). The Civilian "calls" the _first-responder_ that will assist the _in_need_ civilian. When the _first-responder_ ends the assist the civilian is considered safe and leaves the simulation.

At the end of the simulation all civilians are either safe or casualties.
== First-responder
#lorem(50)

== Drone
#lorem(50)

== Initializer
#lorem(50)

== Design Choices

#lorem(100)

= Properties
#lorem(50)

= Conclusion
#lorem(50)