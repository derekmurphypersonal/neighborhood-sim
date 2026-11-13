# game/sim — simulation core

Plain typed GDScript with no scene nodes, rendering, input or wall-clock time (D-017, D-029). Everything here can run headless.

| Directory | Responsibility | May depend on |
|---|---|---|
| `clock/` | Calendar arithmetic and the single persistent clock | nothing |
| `rng/` | Seeded random streams | nothing |
| `state/` | Record shapes (`records.gd`) and mutable state (`world_state.gd`) | nothing |
| `world/` | The static area: streets, buildings, exits, routes | nothing |
| `io/` | Reading and validating data; building a world from a scenario; saves | `clock/`, `state/`, `world/` |
| `systems/` | Rules, as static functions called by `simulation.gd`: `lifecycle`, `economy` (day level); `needs`, `behavior`, `social` (minute level) | `clock/`, `state/`, `world/` |
| `simulation.gd` | Owns clock, RNG and state; `tick()`; player orders; save and restore | all of the above |

Rules:

- Scripts refer to each other with `preload` constants, not `class_name`.
- No fractional numbers in state; record shapes are defined only in `state/records.gd`.
- No file here names a particular place. Which world runs comes from the scenario.
- All randomness comes from `rng/`; all time from the clock.

Not built yet: interiors, a routine detail level, goals, employment, businesses.
