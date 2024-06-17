#import "polimi-thesis-classical-format/src/lib.typ": puttitle

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

This document presents a formal model implemented with
#link("https://uppaal.org/")[Uppaal] of search-and-resque scenarios. Inside a
rectangular map of arbitrary size, civilians have to be brought to safety by
either reaching an exit or being assisted by first-responders. Drones surveys
the area and coordinate the rescue efforts by instructing civilians on what to
do. The model then undergoes formal verification to highlight key behavioral
aspects and identify optimal configurations for maximizing civilian safety.

#pagebreak()

#set heading(numbering: "1.1")

= High Level Model Description

The model adopted for the search-and-resque mission involves 3 different types
of agents:
- *Civilians*: Can be in 3 different states, depending whether they find
  themselves near a fire or if they are following instructions
  - *In-need* (i.e. near a fire): They cannot move and needs to be assisted. After $T_v$ time
    units near a fire, they became a casualty
  - *Busy*: The civilian is following an instructions and can be either assisting
    directly or contacting a _first-responder_ to get help
  - *Moving*: When civilians are not near a fire or busy enacting some instruction,
    they can move towards an exit to get to safety following a some _moving policy_
- *First-responders*:
  - *Assisting*: When a civilian _in-need_ is withing a 1-cell range, the _first-responder_ will
    assist them for $T_"fr"$ time units. After that, the assisted civilian is
    considered safe
  - *Moving*: When free from other tasks, the _first-responder_ can move following
    some _moving policy_
- *Drones*: They survey their surroundings, limited by the field of view $N_v$ of
  the sensors, and follow a pre-determined path moving 1 cell at each time step.
  When two civilians, one _in_need_ and one free, the drones can assign instruct
  the free civilian to either assist directly or contacting a _first-responder_

= Component Description

== Design Choices

= Properties

= Conclusion