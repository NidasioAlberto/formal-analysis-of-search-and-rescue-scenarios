#import "polimi-thesis-classical-format/src/lib.typ": puttitle

#show: doc => puttitle(
  title: [Formal Analysis of Search-and-Rescue Scenarios],
  authors: ("Alberto Nidasio", "Federico Mandelli", "Niccolò Betto"),
  student_id: none,
  advisor: "Prof. Pierluigi San Pietro",
  coadvisor: "Dr.  Livia Lestingi",
  academic_year: [2023-24],
  doc,
)

= Abstract

This document presents a formal model of search-and-rescue scenarios featuring
drones, civilians, and first-responders. The scenario analyzed involves a fire
outbreak inside a building, modeled using a network of timed automata within the
UPPAAL tool. A fleet of drones is deployed on the scene to instruct human
subjects to assist those in need or request intervention from a first-responder.
The model then undergoes formal verification to ensure correctness, and the
drones' decision-making policy is formally checked to guarantee that survivors
can reach safety.

#pagebreak()

= High Level Model Description

= Component Description

== Design Choices

= Properties

= Conclusion