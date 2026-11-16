# Architecture

Status: updated 2026-11-15 for M1-B steps 1 to 10. Confirmed: engine (D-015, pinned at 4.7.2 by D-036), presentation (D-016), separate seeded core (D-017, D-025), JSON data layers (D-020), requirements D-023 to D-029, testing approach (D-031), area and scenario data (D-039), exact saves (D-040). Also confirmed: plain-dictionary records under a no-fractions rule (D-042) and the save-loading contract (D-047). Choices made while building M1-B are proposals P-016 to P-022, implemented and awaiting Derek's confirmation; they are named where they apply. Sections below say what is built and what is design only. See [DECISIONS.md](../DECISIONS.md).

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

Multi-story buildings need a way to show upper-floor dwellings (cutaways or floor switching). M1 should test this on whatever building types the first block turns out to have. As built in M1-B, the player's home is shown as a cutaway of one floor beside the map; upper floors are not shown.

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
- **Stage it.** M0 built the clock and the abstract level. M1-A added the close level. M1-B gave the abstract level its own day of money (below). The routine level and hand-off arrive in M2, when there is more world than the player can see.

### As built (M1-B, steps 1 to 10)

- **One way of advancing time.** `Simulation.tick()` advances one minute: day-level work if it is midnight (`lifecycle`, then `economy`), then conversations (`social`), then for each resident in ID order their needs, their behavior and the economy's count of minutes worked, then the clock. `advance_day_abstract()` runs the same day-level work, then the abstract level's own day of money (`Economy.abstract_day()`), and jumps to the next midnight.
- **Systems** are small scripts of static functions under `sim/systems/`, called in a fixed order: `lifecycle` and `economy` (day level), `social`, `needs`, `behavior`, and `economy` again (minute level). There is no registry or framework.
- **Reports** are read-only scripts under `sim/reports/` (P-021): `week_summary.gd` builds a household's Monday-to-Sunday week from the event log alone (plus who belongs to the household); `building_info.gd` returns what is known about a building as separate parts: documented exterior with its provenance, fictional interior, institution, fictional households; `week_goals.gd` works out a household's "things to try this week" (D-059) from the week's events, household membership and wages, and current relationships, each goal `done`, `on_track`, `open` or `missed` (all settled once the week is over). None changes state, and tests check that.
- **An action** is the one record of what a resident is doing, where, and until when. Timetables, needs, errands, idle choices, player orders and conversations all produce actions. Precedence is player order; then the timetable (sleep, work or school, a fixed household meal such as Sunday dinner); then hunger and rest; then a shopping errand; then fun or company, whichever is lower; then idle (dropping in at an open institution, sitting out front, being at home).
- **Timetables by kind of day** (P-016): each schedule has a `weekday`, `saturday` and `sunday` plan.
- **Rooms and institutions** (P-017). The area may contain institutions: a building with a kind and opening hours for each kind of day. A building may have a fictional interior, assigned by the scenario. Actions name a kind of room (`kitchen`, `bedroom`, `living`), not a particular room. Visitors are put out of an institution when it closes; staff finish their shift.
- **A conversation holds up what it interrupts** (P-018). Being inside an institution, working there, shopping, or going where the player sent someone is taken up again after a talk, with its end moved back by the length of the talk.
- **Money follows behavior** (P-019; `sim/systems/economy.gd`). At close detail a day counts as worked when enough minutes were spent at work; the wage is credited at the next midnight and paid on Friday. Rent is due at the start of each Monday and any shortfall is carried forward. Meals come out of a pantry when the `eat` action finishes; an adult restocks it at the store when it runs low, and the purchase happens when the `shop` action finishes. With an empty pantry a meal is a thin one. Money never goes below zero.
- **The abstract level reckons money from timetables.** On an abstract day everyone whose timetable has them at work that day is credited the wage, and each household pays for a day of groceries. `state.last_abstract_day` records the last such day; wages for a day are settled at midnight only if that day was followed minute by minute, so no day is paid twice. Because of this the two levels agree exactly only on what the calendar drives (birthdays, paydays, rent days) and agree on money only roughly (P-020).
- **Player orders** enter through `Simulation.give_order()`, are validated, queued on the resident, and recorded with their minute in `input_log` (inputs, not state). Orders are `go_home`, `go_to` a building, `talk_to` a person, `enter` an institution, and `use_room` in the player's own home.
- **Walking** follows waypoints from the area: door, front of the house on the street edge, target. Doors and fronts are derived from footprints and the street line when the area is loaded.
- **`Simulation.trails`** holds where each person walked during the latest tick. It exists only so the view can draw walking smoothly; it is not state, is never saved, and no system reads it.
- **No fractional numbers in state** (D-042).
- **The save contract** (D-040, D-047) is written at the top of `sim/io/save_game.gd`. `SaveGame.to_text(simulation)` gives the whole save as text. `SaveGame.restore(text, world)` is the one call that turns save text back into a simulation; it returns `ok`, `error`, `simulation` and `changed_data`, and never crashes on bad input. `SaveGame.parse(text)` checks that a save has every required part. `Simulation.from_save(world, saved)` takes only the save's `simulation` part and is the low-level step `restore()` uses. `write_file` and `read_file` report failures as text. Nothing in the core decides where saves are kept; the view's menu uses one file, `user://saved_game.json` (P-022), and tests use a scratch folder under the system temp folder, never the per-user data folder. Positions are whole inches, money whole cents, needs whole units, time whole minutes.

## 5. Repository layout

As built at M1-B step 10:

```
CLAUDE.md  DECISIONS.md  README.md  .gitignore
docs/                    design and research documents
research/                working copies of source scans (images not in version control)
data/
  historical/            sourced records with provenance (immutable; empty so far)
  fiction/
    scenarios/           where and when a game starts, who lives there, which interiors are used
    schedules.json       timetables for weekdays, Saturdays and Sundays
    interiors/           fictional floor plans
  tuning/                labeled parameters (daily_life.json, economy.json)
  dev_fixture/
    areas/fixture_street/   "Fixture Street": fictional placeholder area
game/                    the Godot project (project.godot lives here)
  sim/                   simulation core (no scene nodes)
    clock/               sim_date.gd (calendar arithmetic, ages), sim_clock.gd
    rng/                 sim_rng.gd (seeded streams)
    state/               records.gd (record shapes), world_state.gd
    world/               area.gd (streets, buildings, exits, routes, institutions, interiors)
    systems/             lifecycle, economy, needs, behavior, social
    reports/             week_summary.gd, building_info.gd, week_goals.gd (read-only)
    io/                  data_files, data_validator, world_loader, save_game
    simulation.gd        owns clock, RNG and state; tick and orders
  view/                  main.tscn, main.gd, title_screen.gd, settings_sheet.gd, world_view.gd,
                         hud.gd, hud_art.gd, week_paper.gd, building_page.gd, tips.gd, screen_fx.gd,
                         help_sheet.gd, focus_ring.gd,
                         describe.gd
  audio/                 placeholder music (day and evening), chimes, interface sounds and day/night ambience
  tests/                 run_tests.gd, test_case.gd, test_*.gd
  tools/                 run_decade.gd, run_days.gd, playtest_week.gd, validate_data.gd
tools/                   make_audio.py (regenerates placeholder audio; Python, numpy, ffmpeg)
```

Notes:

- **Areas and scenarios (D-039).** `world_loader.gd` takes a scenario name, reads the scenario, then the area it names, the floor plans, schedules and tuning, gives each building the interior the scenario assigns it (refusing a plan not made for that building type), and returns one "world" for the simulation. An area file that declares `"fictional": true` marks the area as a stand-in, and the view shows a banner. A researched area would sit under `data/historical/areas/` with the same record shapes. A test checks that no file in the core mentions a particular place.
- **`data/` sits beside the Godot project,** so research files can be reviewed without the engine. This works when running from the repository; an exported build needs a decision (Q-016).
- **Scripts refer to each other with `preload` constants, not `class_name`,** so headless runs do not depend on the editor's import step.
- **The view** builds its controls in code. `main.gd` owns the simulation and advances it with real time, and handles the menu (save and load through `SaveGame`), the week summary and the building sheet; `world_view.gd` draws the street and the cutaway of the player's home, owns the camera (scroll to zoom, drag or arrow keys to pan, R to reset) and turns clicks into orders on mouse release (right-click asks for building information); its decorations (trees, shrubs, fences, lamps, parked cars, paint colors) are invented, chosen deterministically from IDs and never stored in simulation state (P-023); `hud.gd` shows the clock, panel, feed, the week's things to try (a card under the home cutaway) and sheets; `main.gd` works the goals out each time the simulation advances and announces one only when it becomes done during play; `describe.gd` turns actions, events and reports into words. They read state, call the read-only reports, and call `give_order()`; loading a save replaces the simulation through `SaveGame.restore()`.
- **The map is drawn in layers** (`world_view.gd`): ground, shadows, one child layer per fixed object (house, tree, lamp...) and per figure, and overlays. Fixed layers are redrawn only when the view, the light or their own state changes, which keeps a still camera cheap. Godot renumbers the stacking after a child is added, so figure layers are made up front and the stacking is reapplied for a few frames after any later addition.
- **M1-P view additions** (presentation only, D-058): `title_screen.gd` is the title screen painted in code (New game, Continue, Settings, How to play, Quit); `settings_sheet.gd` edits music and sound volume and full screen, which `main.gd` applies to the Music and Sounds audio buses and keeps in `user://settings.cfg` (never written by the self-check, screenshots or tests); `hud_art.gd` draws portraits, mood faces and need and event icons; `week_paper.gd` lays out the week summary as a small paper from the two reports; `screen_fx.gd` dims the street while paused and shows a ribbon when a new day begins. The window keeps the 1280×720 layout and letterboxes when resized (`stretch/aspect="keep"`).
- **Building page and first-time tips** (presentation only, D-058). `building_page.gd` draws what is known about a building as a page, from `sim/reports/building_info.gd` alone: a front elevation sketched in code (captioned as the game's own sketch; siding, roof, door, shutter and curtain colours are chosen from the building ID exactly as `world_view.gd` chooses them, so it matches the map), then separate labelled panels with a tag each: "What the record says" (the research status, or "not documented", and for a placeholder area that the street is made up, D-035), "Inside (invented layout)" with a small floor plan (D-032; room shapes are read from the area's interior), and "Who lives here (fictional)" with portraits and a relationship word for the selected member of the player's household, or for a business its opening hours and whether it is open now. `main.gd`'s `_show_building` opens it; `Describe.building_info` remains as the plain-text form used by the tests. `tips.gd` is one dismissible bubble in the map's top-right corner that shows a tip the first time something happens (a household member selected, a conversation, payday, the week summary, night, a goal done); `main.gd` offers the tips and keeps the seen list and a "Show tips" switch in `user://settings.cfg` (`show_tips`, `tips_seen`), never written by the self-check or screenshots, and screenshots show no tip unless run with `--show tip`. Every HUD control has a tooltip, styled by the theme in `hud.gd`. `--show neighbor` opens the page of the first neighbor's house for a screenshot.
- **Help, finding things and pictures** (presentation only, D-058). `help_sheet.gd` is "How to play": the controls as key caps, what the panels are for, the week's things to try, and that Fixture Street is made up (D-035); it reads nothing from the simulation. H or F1 opens it in a game or on the title screen, and it is also in the in-game menu, the top bar and the title screen; `main.gd` stops the clock while it is open and restores the speed afterwards. Clicking a line in *What has happened* asks `main.gd` (signal `focus_requested`) to show where it happened: `hud.gd`'s `event_target` picks the person or building (the player's household member first in a conversation, the home for money news, the store for shopping), `world_view.focus_on_person` / `focus_on_building` pans the camera, and `focus_ring.gd` draws spreading rings and a bobbing marker on it for about two seconds, asking `world_view` each frame where the target is. Clicking a neighbor's name, or a household tab that is already selected, does the same for that person. F12 saves a PNG of the window to `user://screenshots/neighborhood-YYYYMMDD-HHMMSS.png` with a white flash and a "Picture saved" toast; the self-check and `--screenshot` runs never write one. The top bar has a small speed gauge and a shimmer on the clock at the fastest speed; the pause menu opens with a one-line summary of the week so far (day, money, things to try done), worked out from `sim/reports` like the week sheet. `--show help` opens the help sheet for a screenshot.
- **Noticing things is the view's job.** After each batch of ticks `main.gd` compares the simulation with what it last saw (activities, who is on the map, the event log, household money) and tells the view to pop a bubble, float a number, show a notice or play a chime. The simulation knows nothing of this and its results are unaffected.
- **Audio** (`game/audio/`) is loaded straight from files at run time, so it needs no editor import step. The files are generated by `tools/make_audio.py` and are original placeholders (Q-019). The day and night ambience loops are mixed by the main scene from the simulation clock's time of day, never from wall-clock time. The music does the same on the Music bus: a day waltz and an evening piece, crossfaded by the clock (evening from about 19:00 to 05:00, and on the title screen), with real time used only to limit how fast the change is heard. Short interface sounds go to the Sounds bus and obey the Sounds toggle and volume: a click on every button (the main scene listens to the scene tree's `node_added` signal, so buttons made later by any screen are covered without those screens knowing about audio), a quiet hover tick on the title buttons, sheet open and close, an order accepted, a door when a member of the player's household enters or leaves a building (not at the fastest speed), a flourish for a finished goal and a bell for the player's payday. All of it is presentation: it reads simulation state and the event log and changes neither.
- **Not yet present:** a routine detail level and hand-off between levels, interruption of fast-forward, summaries of skipped time beyond the week summary, goals, employment, businesses, more than one interior or institution.

## 6. Testing and validation *(confirmed, D-031)*

**A lightweight in-repository test runner, no add-ons.** Verified on the pinned engine version: Godot provides headless execution of a script (`--headless --script`) and process exit codes; it does not ship a GDScript unit-test framework. The runner is about seventy lines built on those. There are currently 105 tests, making 2014 checks.

- `game/tests/run_tests.gd` finds every `test_*.gd` in `game/tests/`, runs each method whose name starts with `test_` on a fresh instance, prints a report, and exits 0 if all passed or 1 otherwise. A test that makes no checks counts as a failure.
- `game/tests/test_case.gd` is the base class, with `check` and `check_eq`.
- No mocking or fixtures machinery. If the runner starts growing features an established framework already has, evaluate those frameworks and record the choice in `DECISIONS.md`.

Commands are in the [README](../README.md).

| Kind | What it checks | State |
|---|---|---|
| **Data validation** | Layer matches directory; provenance rules; sources registered and not tertiary-only; hypothesis has reasoning; no fictional or placeholder status in `historical/`; fixture declared fictional and free of real place names; tuning values labeled; every scenario loads with valid references, including interior assignments that fit the building type and whole-number money fields | Built |
| **Calendar and age tests** | Real weekdays and leap years; every day from 1880 to 1960 round-trips; ages from dates of birth | Built |
| **Randomness tests** | Same seed repeats; different seeds differ; streams are independent | Built |
| **World tests** | Scenario loads; the player's home has a fictional interior; placeholder flag; derived doors and fronts; routes; a second area works; the core names no particular place | Built |
| **Reproducibility tests** | Same seed gives the same state hash, day by day and minute by minute; stopping and continuing equals running straight through | Built |
| **Save and load tests** | No fractional numbers in state; save, load, save is byte-identical; continuing after a save at thirteen points (with and without orders) matches an uninterrupted run; every record field is in the save and new field values come back exactly; saving mid-shopping, while a talk holds something up, with someone in a room and someone in the store, with wages earned and rent owed, and after abstract days; a week with a save in the middle matches a week straight through; `restore()` returns the simulation or refuses bad, incomplete or wrong-scenario saves without crashing; changed data is reported; file round trip in a scratch folder; file failures are reported | Built |
| **Detail agreement** | What the calendar drives (birthdays, paydays) falls on the same days in minute-by-minute and day-by-day runs; household money at the two levels agrees to within a quarter of four weeks' income (P-020); days run abstractly are not paid twice | Built for the two levels that exist |
| **Daily life tests** | Everyone home asleep at night; workers and pupils away on weekdays only; Saturday and Sunday differ; the store is staffed and visited; people look after themselves; needs are met in the right places; fun falls and is restored; neighbors meet and relationships change | Built |
| **Places tests** | Interior rooms lie inside the building; people use the right room; the player can send someone to a room; institution hours; going into an institution; a closed one turns people away; visitors leave at closing; an interrupted action resumes after a conversation; the new state survives a save | Built |
| **Economy tests** | Wages paid on Friday for days worked; a day kept home earns nothing; other income is paid without work; rent on Monday and shortfall carried forward; meals come out of the pantry; a low pantry sends someone to the store; shopping buys only what can be afforded; money is never negative and always whole | Built |
| **Week summary tests** | A week runs Monday to Sunday; the summary counts only the log; it accounts for every cent; it survives save and load | Built |
| **Week goals tests** | A fresh week has everything still to do; a hand-built log ticks each goal (and misses the two that can fail); a household without wages has no work goal; goals from a played week are in a fixed order, settled, within their targets, and evaluating them changes nothing | Built |
| **Building information tests** | A placeholder building documents nothing; a building without an interior says so; the store is reported with its own status; a sourced building keeps its provenance; the text for a placeholder claims nothing; looking changes nothing | Built |
| **Order tests** | Only the player's household takes orders; go-to and talk-to work; orders change the outcome | Built |
| **Immutability test** | Every file under `data/` is byte-identical after running | Built |
| **Presentation** | `-- --self-check` loads the main scene, confirms the audio loaded (both pieces of music, chimes, every interface sound and both ambience loops, each on its bus, and that no player was ever started) and checks the ambience and music day/night mixes, gives an order, runs a day and a half through the same path as play, opens every building sheet and the week summary, and saves and loads through the menu into a scratch folder, checking the state is identical; a screenshot can be captured under a virtual display (`-- --screenshot <file> --minutes <n>`, optionally with `--show week`, `building`, `store` or `menu` to open a sheet first, or `--show title` for the title screen, and `--zoom <factor>` to zoom the map) | Built as a command, not part of the test suite. Looks and sound are judged by a person; mouse and keyboard control is not exercised automatically |

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
