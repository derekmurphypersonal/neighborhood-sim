# game/sim — simulation core

Plain typed GDScript with no scene nodes, rendering, input or wall-clock time (D-017, D-029). Everything here can run headless.

| Directory | Responsibility | May depend on |
|---|---|---|
| `clock/` | Calendar arithmetic and the single persistent clock | nothing |
| `rng/` | Seeded random streams | nothing |
| `state/` | Record shapes (`records.gd`) and mutable state (`world_state.gd`) | nothing |
| `world/` | The static area: streets, buildings, exits, routes, institutions and their hours, fictional interiors | `clock/` (for the kind of day, to check opening hours) |
| `io/` | Reading and validating data; building a world from a scenario, including the interiors it assigns; saves (load only through `SaveGame.restore()`) | `clock/`, `state/`, `world/` |
| `systems/` | Rules, as static functions called by `simulation.gd`: `lifecycle`, `economy` (day level, and the abstract level's day of money); `social`, `needs`, `behavior`, `economy` (minute level) | `clock/`, `state/`, `world/` |
| `reports/` | Read-only accounts for the player: `week_summary.gd` (a household's week, from the event log alone), `building_info.gd` (documented exterior, fictional interior, institution and fictional households, kept apart) and `week_goals.gd` (a household's things to try this week, D-059; prompts only, no state or rewards). They change nothing (P-021). | `clock/`; they are handed the simulation or its state |
| `simulation.gd` | Owns clock, RNG and state; `tick()`; player orders; save and restore | all of the above |

Rules:

- Scripts refer to each other with `preload` constants, not `class_name`.
- No fractional numbers in state; record shapes are defined only in `state/records.gd`.
- No file here names a particular place. Which world runs comes from the scenario.
- All randomness comes from `rng/`; all time from the clock.

Not built yet: a routine detail level, resident goals, employment, businesses.
