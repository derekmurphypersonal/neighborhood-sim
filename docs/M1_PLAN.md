# M1 Implementation Plan (proposal)

Status: 2026-11-13. **Approved by Derek, including the document changes in §8, which have been applied. M1-A (steps 1 to 10) has been built and is awaiting review; M1-B has not been started.** Current status is tracked in [ROADMAP.md](ROADMAP.md). One departure from this plan: step 3 kept records as plain dictionaries under a no-fractions rule instead of typed classes (proposal P-014 in `DECISIONS.md`).

The M1 milestone and its outcome are unchanged (D-021, [ROADMAP.md](ROADMAP.md)): one week on one block, with one player household among autonomous neighbors, that is enjoyable to watch and direct. This plan only splits the work in two.

## 1. Maynard Street

Derek's direction: the experience should start on Maynard Street.

What the 1951 Sanborn sheet shows there, as read by Claude from a medium-resolution image (status `probable`, same caveats as F-053 and F-054 in [research/FINDINGS.md](research/FINDINGS.md); not yet logged as its own finding):

- "Maynard St. (Av.)" runs between Salem St. and Oliver St. on sheet 62, with Sanborn block 24 on its north side (toward Bellvale) and block 25 on its south side (toward Claremont).
- Every building fronting it is marked as a dwelling, mostly 1½ to 2½ stories, with small outbuildings marked "A". Roughly twenty-five to thirty houses in all. There are no shops or institutions on Maynard itself.
- A watercourse crosses both blocks near the Salem St. end.
- The school, the M.E. church, and the firehouse with its branch library are one to two blocks north, on Oliver St.

Consequences for the plan:

- Maynard St. is a good first street: a plain residential block is exactly what M1-A needs, and it can be drawn from the map alone.
- That is more than M1 needs. Recommend the **Oliver St. end of Maynard**, about eight to ten houses on both sides, so the walk to the school and library is short when those are added.
- The requirement in M1 for "at least one enterable shop or institution if the block has one" is met by reaching just off the street to Oliver St. (the branch library is the natural choice), in M1-B.
- Nothing can be entered as historical data until a person confirms the readings against full-resolution images (see [research/CANDIDATE_BLOCKS.md](research/CANDIDATE_BLOCKS.md)). Until then M1 runs on Fixture Street (D-035), built in the same data shape so the swap is a data change (§5).

## 2. Proposed scope

### M1-A: a small playable loop

**The smallest convincing experience:** one street seen in plain isometric view, on which you can watch a few households live through two or three days, step in and direct one of them, and see that something is different at the end because of what happened.

| | In M1-A |
|---|---|
| Place | One street: about six house lots drawn as flat footprints from data, the street, and an "off-map" edge where people leave for work and school. On Fixture Street, labelled fictional on screen. No interiors: a resident who goes home is shown as "inside". |
| Time | The continuous clock at minute resolution, starting from a scenario date in spring 1950 (D-034). Pause, normal, fast. Runs as long as you like; two to three days shows the loop. |
| People | Three households, eight to ten residents, each with a date of birth, two or three traits, and a weekday and weekend schedule. |
| Autonomy | Residents follow their schedules (sleep, work or school off-map, home), and in free time act on three needs: hunger, rest, company. They walk between places and stop to talk to each other on their own. |
| Player | One household is yours. Click a member, then click a place to send them there or a person to have them talk. |
| Change you can see | Relationships between residents rise or fall with each conversation and are shown in a panel. Household money changes on payday. A running event feed says what happened ("Testa and Stub talked for 20 minutes"; "household Two is short of money"). Day turns to night. |
| Under the hood | Save and load of the full simulation state, exercised by automated tests (no menu yet). |

Deliberately left for M1-B: interiors, an enterable institution, the full needs set, wages tied to going to work, shopping, the end-of-week summary, the building info view, save/load in the menu.

**Done when:** you can start it, watch three days pass without touching anything and see residents keep their routines and talk to each other; you can direct your household and get a visibly different outcome; a headless test shows that saving at an arbitrary moment and continuing gives the same result as running straight through.

### M1-B: the complete first week

Everything in the M1 "In scope" and "Done when" lists in [ROADMAP.md](ROADMAP.md) that M1-A does not cover:

- Four to six households, fifteen to twenty-five residents.
- The player household's home interior, from a fictional floor-plan module matched to the building type (D-032).
- One enterable institution (on Maynard St., the branch library on Oliver St.; on the fixture, a fictional equivalent).
- A slightly fuller needs set (add fun), and needs met by specific actions in specific places.
- Money that follows behavior: wages for days actually worked, rent on its due day, groceries bought as an errand, running short.
- Seven full days with weekday, Saturday and Sunday differences; fast passage while your household sleeps or is away.
- End-of-week summary built from the event log.
- Building info view: documented exterior facts with sources; interiors and the fixture labelled fictional.
- Save and load from the menu.
- Maynard St. data in place of the fixture, if confirmed by then.
- Derek's playtest and the written judgment (ROADMAP "Done when" item 7).

## 3. Dependencies

```
clock (exists) ──► tick pipeline ──► actions ──► movement ──► view
                        │               ▲  ▲  ▲
places + scenario ──────┤               │  │  └── player commands
(world data)            │        schedules │
                        │                needs
state classes ──► save/load        social interaction ──► relationships ──► memories
                        ▲                                      │
                        └──────────── event log ◄──────────────┘
finances ◄── schedules (attendance), actions (shopping), event log
```

What depends on what, and why it matters for order:

- **Save/load depends on the shape of every piece of state.** Each system added later adds state. If save/load is built last, every system is retrofitted. Built first, with a round-trip test, every later system is forced to be saveable as it is written.
- **Schedules, needs, player commands and social interaction all make a resident do something.** They need one shared notion of "what this resident is doing now, where, until when". If each invents its own, they conflict. That shared piece (an **action**) comes before all four.
- **Schedules come before needs.** A need is acted on in the time a schedule leaves free, and an obligation overrides a need.
- **Movement comes before social interaction.** Two residents can only talk when they are in the same place.
- **Relationships depend on interactions and on the event log,** since a relationship's history is references to logged events.
- **Finances depend on schedules** (wages for days worked) **and on actions** (shopping). The weekly lump-sum budget from M0 is enough for M1-A and is replaced in M1-B.
- **Places and the scenario come before everything that happens somewhere.** Settling their data shape first is also what makes the Fixture-to-Linden swap cheap (§5).
- **The view depends only on places, positions and the event feed.** It should arrive early, as soon as something moves, because watching is how most M1 problems will be found.

## 4. Implementation order

Each step ends with tests passing and, from step 5 on, something visible. Nothing is started before approval.

**M1-A**

1. **Housekeeping.** Correct `.gitignore` (§7, R-7). Create the repository (D-011). Confirm the Mac run (§6).
2. **Tick pipeline.** One way of advancing time, in minutes, with day-boundary work triggered when midnight is crossed. The M0 day-by-day run becomes "advance many minutes with only day-level systems active". Systems register in a fixed order. Fixes R-1.
3. **State classes and save/load.** People and households become small typed classes with explicit save and restore. Save format and the reproducibility tests of §5a. Fixes R-2, R-3.
4. **World data: places and scenario.** Record shapes for street, lot and building footprint in feet; a scenario file; one world loader. Fixture Street rewritten in that shape. Validator extended. Fixes R-4. (§5)
5. **Actions and schedules.** The action record; a scheduler that puts each resident where their timetable says. Off-map work and school.
6. **Movement and the first view.** Residents walk along the street between places; plain isometric drawing of lots, street and people; clock and speed controls. First time something can be watched.
7. **Needs.** Three needs that change over time and choose free-time actions.
8. **Social interaction and relationships.** Meeting, talking, relationship change, events logged, memories as event references.
9. **Player commands.** Select, send, talk. Commands are timestamped inputs, recorded so runs can be replayed.
10. **Feed and panels.** Event feed, household panel, relationship panel. M1-A review with Derek.

**M1-B**

11. Scale the scenario to full size; weekday, Saturday and Sunday schedules.
12. Finances by behavior: attendance-based wages, rent, shopping errand, shortfall.
13. Interior for the player's home; enter and leave buildings.
14. One enterable institution.
15. Fourth need and place-specific need actions.
16. End-of-week summary; building info view.
17. Save and load in the menu.
18. Swap in Maynard St. data if confirmed. Playtest and written judgment.

## 5. Replacing Fixture Street with a Linden block

The rule: **the simulation core never knows which world it is running.** It receives a set of place records and a scenario, and nothing in it mentions "fixture" or "Linden".

What M0 has now does not meet that rule (§7, R-4): the loader is named for the fixture, reads a fixed fixture path, and the fixture file mixes two different things, the place and the people.

Proposed arrangement:

| Thing | What it is | Where it lives | Real Linden version |
|---|---|---|---|
| **Area** | Streets, lots, building exteriors in feet, in the record shapes of [WORLD_DATA_MODEL.md §5](WORLD_DATA_MODEL.md) | `data/dev_fixture/areas/fixture_street/` (status `placeholder`) | `data/historical/areas/maynard_st/` (status with sources) |
| **Scenario** | Start date; which area to load; the starting households and residents; which household is the player's; the seed | `data/fiction/scenarios/` (status `fictional`). Residents are fictional in every case (D-006). | Same directory; a different file pointing at the Linden area |
| **Interior assignment** | Which fictional floor plan a building uses | In the scenario or beside it; always `fictional` | Same |

- One **world loader** takes a scenario name, reads the scenario, reads the area it names, validates both, and hands the core a starting world. The fixture loader is retired.
- **Area records have the same shape in both layers.** The only differences are the directory, the provenance, and the validator's rules for each. A scenario refers to buildings by ID.
- Swapping worlds is then: add the Linden area files, add a scenario that names that area and places households in its dwellings, and select it. No simulation code changes.
- A test keeps this honest: the core's source files are checked for the words "fixture", "linden" and "maynard", and a second tiny area is loaded through the same loader.
- The view reads from the loaded world whether the area is a placeholder, and shows the "fictional" banner when it is (D-035).

## 5a. Save and load

**Principle:** a save is the complete simulation state at a moment between two ticks, plus enough to rebuild everything else from data. Loading it and continuing must be indistinguishable from never having stopped.

**What a save contains**

| Section | Contents | Notes |
|---|---|---|
| Header | Save format version; engine version; scenario ID; a fingerprint (hash) of each data file the world was built from | On load, a mismatch in fingerprints is reported, not silently accepted |
| Time | Day index and minute of day | The single clock (D-013) |
| Randomness | Master seed; the internal state of every random stream that has been used | Streams not yet used are recreated from the master seed on first use, exactly as in an uninterrupted run |
| Households | Every household: members, dwelling, money, recurring income and expenses, player flag | |
| Residents | Every resident: identity, date of birth, traits, needs, position or place, **current action and its progress**, queued actions, schedule position | The in-progress action is what makes a mid-day save continue correctly |
| Relationships | Every pair's values and history references | |
| Event history | The full life-event log, in order, and the next event number | Memories and summaries are rebuilt from it |
| Pending inputs | Player commands issued but not yet carried out | |

Not saved: historical and fixture data (referred to by ID and fingerprint), anything derived (ages, life stages), and presentation state such as camera position or the current speed setting.

**How it is kept exact**

- **Saved only between ticks,** never in the middle of one.
- **Whole numbers stay whole.** Godot's JSON reader turns every number into a decimal (confirmed on 4.7.2: `12000` comes back as `12000.0`, and integers beyond about 9 quadrillion lose digits). Each state class therefore restores its own fields with explicit types, and 64-bit values such as random-stream states are written as text. Confirmed on 4.7.2: a stream restored from its text state continues with the same numbers.
- **One canonical form.** The state hash is computed from the same serialized form that is written to disk, so "same hash" and "same save" mean the same thing.
- **Ordered data.** Anything iterated during simulation is kept in a defined order, so restoring cannot reorder outcomes.
- **Written safely:** to a temporary file, then renamed, in the engine's per-user data folder.

**Tests that define "reproducible"**

1. Run N days straight through; separately run to an arbitrary midpoint, save, discard everything, load, and continue to the same end. The two state hashes are identical. Repeated at several midpoints, including mid-action and across midnight and a payday.
2. Save, load, save again: the two files are identical byte for byte.
3. The same with a scripted list of player commands, to cover inputs.
4. Loading a save whose data fingerprints do not match is detected.

These are written in step 3, before any M1 system exists, and every later system must keep them passing.

## 6. Mac verification

Install Godot **4.7.2 stable**, standard build (not .NET), from godotengine.org. Then in Terminal:

```
cd /Users/derekmurphy/lindensims
alias godot="/Applications/Godot.app/Contents/MacOS/Godot"

godot --version
godot --headless --path game --script res://tests/run_tests.gd ; echo "exit code: $?"
godot --headless --path game --script res://tools/run_decade.gd -- --seed 1950
godot --headless --path game --script res://tools/validate_data.gd ; echo "exit code: $?"
```

Expected:

| Command | Expected |
|---|---|
| `--version` | Starts with `4.7.2.stable` |
| Tests | Last line `31 tests, 80 checks, 0 failed`, then `exit code: 0` |
| Decade run | `Events logged: 128` and `State hash: c7f76bda7cddf1e4ad96630866ea1cf010f455e19e6a5fda4666ce6493cc01a7` |
| Validation | `Data validation: 0 error(s).`, then `exit code: 0` |

The hash line matters most: the same hash on the Mac as on Linux shows the simulation is reproducible across machines, not only across runs. A different hash is not a failure of the Mac but is something to investigate before M1 (§7, R-5).

If the app is somewhere other than `/Applications`, adjust the alias. If macOS blocks the first launch, open Godot once from Finder.

## 7. Architectural risks found in M0

Reviewed against what M1 will ask of the code. Ordered by how costly each would be if left.

| # | Risk | Why it would get expensive | Recommendation |
|---|---|---|---|
| R-1 | **Time advances only in whole days.** The clock can count minutes, but the simulation's only loop is day-by-day, with birthdays and budgets called directly inside it. | M1 needs minute stepping. Adding it as a second loop beside the first creates two code paths that must agree forever (the detail-level agreement D-026 asks for), and every new system would be written twice. | Step 2: one tick pipeline; the day loop becomes a special case of it. Do this before any M1 system. |
| R-2 | **State is plain dictionaries, and the state hash is taken from Godot's JSON text of them.** | Works for hashing, but not for loading: every number returns as a decimal (confirmed). Integer money, day indexes and IDs would change type after a load, and results would drift. M0 flagged the dictionaries as temporary; saves make it urgent. | Step 3: small typed state classes with explicit save and restore. |
| R-3 | **No save/load exists, and it is listed late in M1.** | Every system adds state; retrofitting saves after ten systems is the costly way. | Build the save core and its tests in step 3; add only the menu in M1-B. |
| R-4 | **The world loader is fixture-specific, and the fixture file mixes place and people.** | The swap to Linden would mean a second loader and reshaped data, with fixture assumptions already spread through M1 code. | Step 4: area and scenario split, one loader, same record shapes (§5). |
| R-5 | **Random streams are seeded through the engine's text-hash function.** | Reproducibility then depends on that function not changing between engine versions, and it yields only about four billion distinct seeds. Cross-platform agreement is unverified. | Keep the engine pinned (D-036). Check the Mac hash (§6). Record the seeding method in the save header so a future change is detectable. Replacing it with a fixed, self-contained mixing function is cheap now and worth doing in step 3. |
| R-6 | **Events carry a day but no time of day and no sequence number.** | Fine at day resolution; ambiguous once several things happen within a day, and relationship histories need stable references to events. | Step 3: give events a minute and a running number. |
| R-7 | **`.gitignore` excludes `*.import` files.** | In Godot 4 those files hold each asset's import settings and belong in version control; only the `.godot/` folder should be ignored. Harmless today (there are no assets), wrong the moment art is added. | Step 1: remove that line. |
| R-8 | **Data is read from beside the project folder.** | Works from the repository; will not work in an exported build, and saves will introduce a second file location. Already noted in M0. | No change for M1 (played from the project). Decide before the first exported build; record as a question. |
| R-9 | **The data validator finds source IDs by reading a Markdown table.** | A formatting change to `SOURCES.md` could make validation report "no sources" or miss an ID. | Leave for now; the validator already fails loudly if it reads no IDs. Revisit if the register grows. |
| R-10 | **Names differ between documents and code** (the data model says `birth_date`; the code stores `birth_day` as a day number). | Small, but confusing across two assistants. | Settle names in step 3 and update `WORLD_DATA_MODEL.md` to match. |

Checked and found sound: the calendar arithmetic and age rules (covered by tests over every day from 1880 to 1960); integer cents for money; one random stream per system; the core's independence from scenes; untyped declarations really are rejected by the project setting (confirmed: a script with an untyped variable fails to load).

Not recommended, though they might seem useful: an entity-component framework, an event bus library, a generic plugin system for systems, binary save formats, pathfinding libraries, or the routine detail level. None is needed for M1.

## 8. Recommended changes to DECISIONS.md and ROADMAP.md

None of these alters a confirmed decision. None has been applied.

**DECISIONS.md**

1. **Record Derek's direction on the first area.** New confirmed entry: the first playable area is on Maynard Street. Q-001 moves to resolved for the street, with a narrower follow-up question: which stretch of Maynard St. and how many lots (recommendation: the Oliver St. end, eight to ten houses).
2. **New proposal: M1 is delivered in two parts,** M1-A (small playable loop) and M1-B (complete first week), with a review between them. The M1 milestone and outcome (D-021) are unchanged.
3. **New proposal: area and scenario are separate data,** loaded through one world loader, with scenarios in `data/fiction/scenarios/` (§5).
4. **New proposal: save format and reproducibility tests** as in §5a, built before M1's systems.
5. **New open question:** where data and saves live in an exported build (R-8).
6. **New open question:** how the scenario's fictional residents are named and described before Q-006 research is done. Recommendation: plainly invented names from an authored pool, with no assumptions about ethnicity or religion built in.

**ROADMAP.md**

1. Under M1, add the M1-A / M1-B split and their "done when" lists (§2), keeping the existing M1 scope and outcome.
2. Move "save and load" from the end of M1's list to an early step, with the menu remaining in M1-B.
3. Replace "one block" wording with "the Oliver St. end of Maynard Street" once item 1 above is confirmed.
4. Add to "Before M1 can begin": the Mac verification results (§6), including whether the state hash matched.
5. Add a research item: log the Maynard St. reading as a finding, and confirm it against full-resolution sheets from both the 1951 and 1957 volumes.

## 9. What is needed from Derek

1. Approve, amend or reject the M1-A / M1-B scope (§2) and the order (§4).
2. Confirm the stretch of Maynard St. (§1).
3. Run the Mac commands (§6) and report the output.
4. Say whether the recommended document changes (§8) should be applied.
5. Authorize M1-A when ready.
