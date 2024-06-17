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

= High Level Model Description

= Component Description

== Design Choices

= Properties

= Conclusion