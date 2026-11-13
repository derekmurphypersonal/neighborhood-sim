# Architecture

Status: updated 2026-11-13 for M1-A. Confirmed: engine (D-015, pinned at 4.7.2 by D-036), presentation (D-016), separate seeded core (D-017, D-025), JSON data layers (D-020), requirements D-023 to D-029, testing approach (D-031), area and scenario data (D-039), exact saves (D-040). Also confirmed: plain-dictionary records under a no-fractions rule (D-042). Sections below say what is built and what is design only. See [DECISIONS.md](../DECISIONS.md).

This document must be kept current: when the structure of the code changes, this file changes in the same commit, and any change of decision is recorded in `DECISIONS.md`.

## 1. Engine *(confirmed, D-015)*

**Godot 4.7.2 stable, standard build, with statically typed GDScript** (D-015, D-036). The project treats untyped declarations as errors.

The evaluation that led here, kept for the record:

| Option | For | Against |
|---|---|---|
| **Godot 4, GDScript** (chosen) | Free and open source. Scenes, scripts and resources are text files, which suits version control and assistant-driven editing. Runs headless. Good 2D, including isometric tile layers and Y-sorting. Fast iteration. | Smaller ecosystem than Unity. GDScript is slower than compiled languages for heavy simulation. Assistants make more API mistakes with Godot 4 than with older engines, so the pinned version's documentation should be consulted rather than assumed. |
| Godot 4, C# | Stronger typing and performance; mature test tooling | A second toolchain; more setup and export friction; no need demonstrated |
| Unity | Largest ecosystem | Licensing uncertainty; more opaque project files; editor-centric workflow |
| Web stack (TypeScript with a 2D library) | Excellent testing and assistant support | No editor for scenes, maps and UI |
| Custom or Rust-based engine | Full control | Far more work before anything is playable |

The risk of the choice is contained by §3: the simulation does not depend on the engine's scene system.

## 2. Presentation *(confirmed, D-016)*

**Isometric 2D.** World geometry is stored in real-world feet, independent of presentation ([WORLD_DATA_MODEL.md §3](WORLD_DATA_MODEL.md)); projection, tiles and pixels belong to the view. The prototype uses a deliberately plain look; final art direction is deferred (Q-008).

Multi-story buildings need a way to show upper-floor dwellings (cutaways or floor switching). M1 should test this on whatever building types the first block turns out to have.

## 3. Structure: simulation core and presentation shell *(confirmed, D-017, D-023, D-029)*

```
┌─────────────────────────────────────────────────────────┐
│ Presentation (Godot scenes)                             │
│ map view · resident sprites · UI panels · input · audio │
└───────────────▲──────────────────────┬──────────────────┘
                │ state + events       │ commands, focus
                │ (read-only)          │
┌───────────────┴──────────────────────▼──────────────────┐
│ Simulation core (plain typed GDScript, no scene nodes)  │
│ clock · mutable state · systems · event log · RNG       │
└───────────────▲─────────────────────────────────────────┘
                │ load / validate (read-only at runtime)
┌───────────────┴─────────────────────────────────────────┐
│ Data (JSON): historical · fiction · tuning · dev_fixture│
└─────────────────────────────────────────────────────────┘
```

Rules:

1. **The core does not reference scene nodes, rendering, input, frame rate or wall-clock time.** It can be created and advanced in a headless run with nothing on screen. The continuous calendar lives here (D-029).
2. **Presentation reads state and listens for events. It affects the simulation only by sending commands** ("resident X: go to place Y and do Z", "set speed", "fast-forward to date D") **and by reporting focus** (which household is the player's, where the player is looking).
3. **One clock.** The core owns the single persistent calendar from 1 January 1950 to 31 December 1959. Presentation asks the core to advance time; it never keeps its own.
4. **Historical data is immutable at runtime** (D-023). It is loaded once, validated, and exposed read-only. All change lives in simulation state, which refers to historical records by ID. Divergence is recorded in state with a reference back to the record's provenance (D-024); see [WORLD_DATA_MODEL.md §8](WORLD_DATA_MODEL.md).
5. **All randomness goes through the core's seeded generators,** one stream per system (D-025). No global random calls in simulation code. Generator state is part of a save.
6. **Systems are plain objects with explicit dependencies,** registered in a fixed order. No general-purpose entity-component framework unless a real need appears.

## 4. Time and detail levels *(confirmed, D-013, D-026, D-027, D-028)*

The model is described in [TIME_AND_LIFECYCLE.md §2–§4](TIME_AND_LIFECYCLE.md). Its consequences for the code:

- **Each system can advance at three levels of detail:** `close` (per minute, per resident), `routine` (per block of hours, from schedules, in aggregate) and `abstract` (per day). A system that has nothing meaningful to do at a level does nothing there.
- **A detail manager in the core assigns each resident and household a level** from the focus reported by presentation and the current speed. During fast-forward everyone is `abstract`. At watching speeds the player's household and those near or interacting with it are `close`; the rest of the neighborhood is `routine`.
- **Hand-off functions** convert a resident's state between levels: raising to `close` produces a concrete position, activity and need values consistent with schedule and recent history; lowering summarizes them. Hand-off uses the seeded generators so it is reproducible.
- **Important events are produced by level-independent rules** and always written to the life-event log, which is what summaries of skipped time are built from.
- **Fast-forward is the abstract level run in a loop** toward a target, with interruption when an event above the importance threshold involves the player's household.
- **Reproducibility is defined over inputs.** Focus changes and time commands are inputs, recorded with their timestamps. Same data, seed and inputs give the same state. Different focus gives small differences; agreement tests (§6) keep those within bounds.
- **Stage it.** M0 built the clock and the abstract level. M1-A added the close level. The routine level and hand-off arrive in M2, when there is more world than the player can see.

### As built (M1-A)

- **One way of advancing time.** `Simulation.tick()` advances one minute: day-level work if it is midnight, then conversations, then each resident's needs and behavior in ID order, then the clock. `advance_day_abstract()` runs only the day-level work and jumps to the next midnight. Both call the same day-level code, and a test checks they agree.
- **Systems** are small scripts of static functions under `sim/systems/`, called in a fixed order by `tick()`: `lifecycle` and `economy` (day level), `social`, `needs`, `behavior`. There is no registry or framework.
- **An action** is the one record of what a resident is doing, where, and until when. Timetables, needs, idle choices, player orders and conversations all produce actions; precedence is player order, then timetable, then need, then idle.
- **Player orders** enter through `Simulation.give_order()`, are validated, queued on the resident, and recorded with their minute in `input_log` (inputs, not state).
- **Walking** follows waypoints from the area: door, front of the house on the street edge, target. Doors and fronts are derived from footprints and the street line when the area is loaded.
- **`Simulation.trails`** holds where each person walked during the latest tick. It exists only so the view can draw walking smoothly; it is not state, is never saved, and no system reads it.
- **No fractional numbers in state** (D-042).
- **The save contract** (D-040, D-047) is written at the top of `sim/io/save_game.gd`. `SaveGame.to_text(simulation)` gives the whole save as text. `SaveGame.restore(text, world)` is the one call that turns save text back into a simulation; it returns `ok`, `error`, `simulation` and `changed_data`, and never crashes on bad input. `SaveGame.parse(text)` checks that a save has every required part. `Simulation.from_save(world, saved)` takes only the save's `simulation` part and is the low-level step `restore()` uses. `write_file` and `read_file` report failures as text. Nothing in the core decides where saves are kept; tests use a scratch folder under the system temp folder, never the per-user data folder. Positions are whole inches, money whole cents, needs whole units, time whole minutes.

## 5. Repository layout

As built for M1-A:

```
CLAUDE.md  DECISIONS.md  README.md  .gitignore
docs/                    design and research documents
research/                working copies of source scans (images not in version control)
data/
  historical/            sourced records with provenance (immutable; empty so far)
  fiction/
    scenarios/           where and when a game starts and who lives there
    schedules.json       daily timetables
  tuning/                labeled parameters
  dev_fixture/
    areas/fixture_street/   "Fixture Street": fictional placeholder area
game/                    the Godot project (project.godot lives here)
  sim/                   simulation core (no scene nodes)
    clock/               sim_date.gd (calendar arithmetic, ages), sim_clock.gd
    rng/                 sim_rng.gd (seeded streams)
    state/               records.gd (record shapes), world_state.gd
    world/               area.gd (streets, buildings, exits, routes)
    systems/             lifecycle, economy, needs, behavior, social
    io/                  data_files, data_validator, world_loader, save_game
    simulation.gd        owns clock, RNG and state; tick and orders
  view/                  main.tscn, main.gd, world_view.gd, hud.gd, describe.gd
  audio/                 placeholder music and chimes
  tests/                 run_tests.gd, test_case.gd, test_*.gd
  tools/                 run_decade.gd, run_days.gd, validate_data.gd
tools/                   make_audio.py (regenerates placeholder audio; Python, numpy, ffmpeg)
```

Notes:

- **Areas and scenarios (D-039).** `world_loader.gd` takes a scenario name, reads the scenario, then the area it names, plus schedules and tuning, and returns one "world" for the simulation. An area file that declares `"fictional": true` marks the area as a stand-in, and the view shows a banner. A researched area would sit under `data/historical/areas/` with the same record shapes. A test checks that no file in the core mentions a particular place.
- **`data/` sits beside the Godot project,** so research files can be reviewed without the engine. This works when running from the repository; an exported build needs a decision (Q-016).
- **Scripts refer to each other with `preload` constants, not `class_name`,** so headless runs do not depend on the editor's import step.
- **The view** builds its controls in code. `main.gd` owns the simulation and advances it with real time; `world_view.gd` draws; `hud.gd` shows the clock, panel and feed; `describe.gd` turns actions and events into words. They read state and call `give_order()`, nothing else.
- **Noticing things is the view's job.** After each batch of ticks `main.gd` compares the simulation with what it last saw (activities, who is on the map, the event log, household money) and tells the view to pop a bubble, float a number, show a notice or play a chime. The simulation knows nothing of this and its results are unaffected.
- **Audio** (`game/audio/`) is loaded straight from files at run time, so it needs no editor import step. The files are generated by `tools/make_audio.py` and are original placeholders (Q-019).
- **Not yet present:** interiors, a routine detail level, save and load in the menu.

## 6. Testing and validation *(confirmed, D-031)*

**A lightweight in-repository test runner, no add-ons.** Verified on the pinned engine version: Godot provides headless execution of a script (`--headless --script`) and process exit codes; it does not ship a GDScript unit-test framework. The runner is about seventy lines built on those. There are currently 59 tests.

- `game/tests/run_tests.gd` finds every `test_*.gd` in `game/tests/`, runs each method whose name starts with `test_` on a fresh instance, prints a report, and exits 0 if all passed or 1 otherwise. A test that makes no checks counts as a failure.
- `game/tests/test_case.gd` is the base class, with `check` and `check_eq`.
- No mocking or fixtures machinery. If the runner starts growing features an established framework already has, evaluate those frameworks and record the choice in `DECISIONS.md`.

Commands are in the [README](../README.md).

| Kind | What it checks | State |
|---|---|---|
| **Data validation** | Layer matches directory; provenance rules; sources registered and not tertiary-only; hypothesis has reasoning; no fictional or placeholder status in `historical/`; fixture declared fictional and free of real place names; tuning values labeled; every scenario loads with valid references | Built |
| **Calendar and age tests** | Real weekdays and leap years; every day from 1880 to 1960 round-trips; ages from dates of birth | Built |
| **Randomness tests** | Same seed repeats; different seeds differ; streams are independent | Built |
| **World tests** | Scenario loads; placeholder flag; derived doors and fronts; routes; a second area works; the core names no particular place | Built |
| **Reproducibility tests** | Same seed gives the same state hash, day by day and minute by minute; stopping and continuing equals running straight through | Built |
| **Save and load tests** | No fractional numbers in state; save, load, save is byte-identical; continuing after a save at thirteen points (with and without orders) matches an uninterrupted run; `restore()` returns the simulation or refuses bad, incomplete or wrong-scenario saves without crashing; changed data is reported; file round trip in a scratch folder; file failures are reported | Built |
| **Detail agreement** | Day-level results agree between minute-by-minute and day-by-day runs | Built for the two levels that exist |
| **Daily life tests** | Everyone home asleep at night; away only on weekdays; needs never bottom out; small children stay home; neighbors meet and relationships change | Built |
| **Order tests** | Only the player's household takes orders; go-to and talk-to work; orders change the outcome | Built |
| **Immutability test** | Every file under `data/` is byte-identical after running | Built |
| **Presentation** | `-- --self-check` loads the main scene, confirms the audio loaded, gives an order and runs a day and a half through the same path as play; a screenshot can be captured under a virtual display (`-- --screenshot <file> --minutes <n>`) | Built as a command, not part of the test suite. Looks and sound are judged by a person; mouse and keyboard control is not exercised automatically |

Still to add when the data exists: checks on IDs resolving between records, validity intervals and geometry.

## 7. Dependencies

Default answer to a new dependency is no (D-007). Accepted so far: the engine only. (`tools/make_audio.py` uses Python, numpy and ffmpeg, but only to regenerate the placeholder audio files, which are committed; nothing needs it to run or test the game.) Anything else, including a test framework, needs an entry in `DECISIONS.md` saying what it replaces and why it is worth it.

## 8. Performance stance

Neighborhood scale means tens to low hundreds of residents. Write clear code first and measure before optimizing. Detail levels (§4) are a confirmed design requirement, not a speculative optimization: they are what makes a continuous decade with fast-forward possible, and they keep cost tied to what the player is looking at. The decade test's run time is the early warning.

## 9. Architecture documentation requirements

- This file describes the structure as it is, not as it was hoped to be.
- `game/sim/README.md` states each directory's responsibility and what it may depend on. Update it when a directory is added.
- A new system is added to the systems table in [GAME_DESIGN.md §5](GAME_DESIGN.md) with what the player experiences from it, and states what it does at each detail level.
- Decisions with lasting consequences get a `DECISIONS.md` entry, not only a code comment.
