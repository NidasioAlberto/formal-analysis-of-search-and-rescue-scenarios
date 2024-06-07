# Assignemt model's specifications

Layout:
- [X] Emergency exits are places on the boundary layout
- [X] Positions of boundary cells corresponding to exists must be configurable
- [X] Positions of fires must be configurable
- [X] Agents occupy one cell at a time
- [X] Each cell is occupied by only one human agent at a time
- [X] Drones can hover over cells occupied by a human
- [X] Agents position refresh each time unit

Drones:
- [X] The drones' movement patterns is pre-determined
- [X] You design the drones' movement pattern
- [X] The drones communicates with survivor when it detects both a survivor and a person in need within its vision range
- [X] You design the decision-making policy. The simplest one is purely random choice. Potential refinements can take into account for example distances

First responders rules:
1. [X] If a person is within a 1cell range, the first responder will assist them for $T_{fr}$. After such time, the assisted survivor is considered safe
2. [X] Otherwise the first responder can move. You design the moving policy

Survivors rules:
1. [X] If an exit is within a 1cell range, they are considered safe
2. [X] If a tile occupied by a fire is within a 1cell range, they are considered in need. If they remain near a fire for more than $T_v$ they die
3. [X] If the survivor has been instructed to help, they are busy acting as a zero responder. After $T_{zr}$ both the zero responder and the survivor in need
4. [X] If the survivor has been instructed to contact the first responder, they are busy enacting this instruction. When the first responder has completed the assistance, both survivors are considered safe
5. [X] The survivor can move. You design the moving policy

# Stochastic Version

Drones:
- [ ] The drones' vision sensors are not faultless. When in the proximity of a survivor and a victim, the drone detects it with probability $1 - P_{fail}$

Survivors:
- [ ] Survivors are not professionals, when instructed, they acknowledge the instruction and enact with probability $p_{listen}$

# Configurable parameters

Drones:
- $N_v$ vision range
- $p_{fail}$ probability of vision sensors to fail

First responders:
- $T_{fr}$: Assistance time

Survivors:
- $T_{zr}$: Assistance time
- $T_v$: Death time
- $p_{listen}$: Probability to listen to commands

# Open questions

- What happens if two drones detects the same survivor-victim pair (especially if they send conflicting instructions)?
