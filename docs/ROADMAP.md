# Roadmap and First Playable Milestone

Status: updated 2026-11-15. **M0 is reviewed and accepted. M1 is accepted by Derek (D-048). A polish pass, M1-P, is authorized before M2 (D-057); its working scope is proposal P-023.** See [DECISIONS.md](../DECISIONS.md).

Milestones are defined by what a player can do at the end of each, not by which systems exist.

## Overview

| Milestone | Name | A player can... | Status |
|---|---|---|---|
| Pre-production | Documentation and review | — read a documented, reviewed design and plan | Done |
| **M0** | Groundwork | — nothing yet; a decade runs headless on a fixture, and candidate blocks in the real Linden are identified | Done; no historical data entered yet |
| **M1** | **A Week on the Block** | live one week of spring 1950 with one household on one block, with pause and speed controls | Accepted (D-048); polish pass M1-P under way (D-057) |
| M2 | A Year on the Block | play through 1950 continuously, fast-forwarding at will, with birthdays, life events and summaries of skipped time | |
| M3 | The Decade on the Block | play 1950–1959 on that block, with documented changes arriving on their dates | |
| M4+ | Widening Linden | play on a growing map, block by researched block | |

## M0: Groundwork

### What was asked and what was delivered

| # | M0 item | Result |
|---|---|---|
| 1 | Cross-check all project documents for consistency | Done. Links, decision IDs and section references are checked by script; stale wording removed. |
| 2 | Finalize the historical research plan and source register | Done. See [HISTORICAL_RESEARCH_PLAN.md](HISTORICAL_RESEARCH_PLAN.md) and [research/SOURCES.md](research/SOURCES.md). |
| 3 | Identify candidate Linden blocks from available digital evidence | Done. Three candidate blocks, read from the Sanborn volume corrected to March 1951 (sheets 62 and 70), are in [research/CANDIDATE_BLOCKS.md](research/CANDIDATE_BLOCKS.md). The readings are `probable`, not verified. The choice (Q-001) is Derek's. |
| 4 | Preserve unresolved historical questions | Done. "Known unknowns" in [research/FINDINGS.md](research/FINDINGS.md); Q-001, Q-002, Q-006, Q-011 in `DECISIONS.md`. |
| 5 | Prepare the Godot project structure | Done. `game/` with `sim/`, `tests/`, `tools/`, `view/`; `data/` with four layers. |
| 6 | Establish the lightweight simulation test runner | Done. `game/tests/run_tests.gd`, no add-ons (D-031). |
| 7 | Verify headless execution | Done on Godot 4.7.2, Linux. Tests, the decade run, data validation and the main scene all ran headless. |
| 8 | Verify seeded deterministic simulation | Done. Same seed gives the same state hash; different seeds differ; stopping and continuing matches running straight through. |
| 9 | Document how to run and test the project | Done. See the [README](../README.md). |

### What the code did at the end of M0

- A continuous calendar from 1 January 1950 to 31 December 1959 with real weekdays and leap years, and one forward-only clock, with no dependency on rendering.
- Age computed from date of birth, with birthdays, including the 29 February convention.
- Seeded random streams, one per system.
- A fictional fixture world ("Fixture Street": twelve residents in four households) loaded from data.
- Day-by-day (abstract level) simulation of two things only: birthdays, and a simple weekly household budget with seeded variation. Events are written to a life-event log.
- A data validator enforcing the provenance and layer rules, including that the fixture is marked fictional and never uses the real place names.
- 31 automated tests at the end of M0 (105 now).

It deliberately does **not** include: needs, schedules, movement, conversations, relationships, jobs, interiors, any drawing of a map, player control, saves, or the close and routine detail levels. Those are M1 and M2.

### Not verified

- Running on macOS. All verification was on Linux; Godot was not available on Derek's Mac from this session. The code uses nothing platform-specific, but this should be confirmed by running the test command once on the Mac.
- An exported (packaged) build. `data/` is read from beside the project folder, which works when running from the repository. Packaging data into an export is a later task.

### Left over from M0

- **Mac verification.** Derek has Godot 4.7.2 on the Mac, has played M1-A there, and reported one failing test, `test_save_file_round_trip`. That failure was reproduced on Linux by making the per-user data folder unwritable, and fixed (see M1-A stabilization below). After the fix Derek ran the README's commands on the Mac (Godot 4.7.2) and reported: 59 tests, 270 checks, 0 failed; data validation 0 errors; the decade hash and the three-day hash identical to the Linux values; self-check passed. Identical hashes on macOS and Linux confirm the simulation reproduces across machines.
- **Version control.** The folder is a git repository whose remote is Derek's personal repository, https://github.com/derekmurphypersonal/neighborhood-sim (D-011). Pushing is done from the Mac, because the assistant's environment has no GitHub credentials for it. Never add a remote under the `iuvonauts` organization.
- **Historical data.** None entered. Maynard Street is chosen (D-037); its readings await confirmation.

## M1: A Week on the Block (first playable) *(confirmed, D-021)*

**The claim M1 tests:** a handful of fictional households on one block, over one ordinary week, is enjoyable to watch and to direct, and feels like a place.

M1 is delivered in two parts with a review between them (D-038). The full plan, dependencies and order are in [M1_PLAN.md](M1_PLAN.md).

**Where:** the Oliver Street end of Maynard Street, about eight to ten houses (D-037). Until the map readings for it are confirmed and entered, M1 runs on the fictional Fixture Street (D-035), which is always identified as fictional on screen and in data. Because areas and scenarios are separate data behind one loader (D-039), the swap needs no simulation code changes.

### M1-A: a small playable loop — accepted (D-041, D-044)

What you can do now, on Fixture Street:

- Watch three households (ten residents) from Monday 3 April 1950, 06:00, in a plain isometric view, with pause and three speeds.
- See residents keep their timetables (sleep, work or school away from the street, home), look after three needs (fed, rested, company), walk between places, and fall into conversation with neighbors on their own.
- Direct the members of your household: send one to a house, send one home, or have one go and talk to a neighbor.
- See change: each conversation shifts how two people regard each other; household money is settled each Friday; a feed lists what has happened.

Added after Derek's review of the first build:

- **Bubbles:** everyone outdoors has a bubble saying what they are doing; a new activity makes the bubble pop and stay highlighted for a few seconds. Notes appear over a house when someone inside starts something.
- **Clearer signals:** a pulsing ring and bright line mark people talking; regard changes float up as +3 or -2 when a conversation ends; notices cross the bottom of the map for things involving your household (a conversation starting, a first meeting, payday, an order given); people leaving for and returning from work or school are announced at the end of the street; new feed lines are marked NEW; the view darkens at night and houses with someone awake show a lit window.
- **Sound:** an original placeholder waltz as background music, and two soft chimes, each with an on/off button (M toggles music).

Built underneath: one way of advancing time in minutes; exact save and load with reproducibility tests; area and scenario data with one loader.

Not in M1-A, by design: interiors, an enterable building, wages tied to days worked, shopping, the end-of-week summary, the building info view, save and load in the menu, a second detail level.

| M1-A done when | Result |
|---|---|
| Three days pass untouched and residents keep routines and talk to each other | Met in automated tests: everyone home asleep at 03:00; workers and pupils away on weekday mornings and home on Sunday; nobody runs out of food or rest; 39 conversations in three days with seed 1950 |
| Directing your household gives a visibly different outcome | Met in automated tests: an ordered conversation happens and the run's state differs from an undirected one |
| Saving at an arbitrary moment and continuing equals running straight through | Met in automated tests at thirteen save points, with and without orders |
| Derek can start it and play it | Met for the first build: Derek played it on the Mac and judged the loop good. Derek then tried the bubbles, signals and music and accepted them (D-044). |

#### M1-A stabilization (2026-11-13)

- **The failing test.** `test_save_file_round_trip` wrote its file into the per-user data folder. Where that folder cannot be written the write failed, and the test then crashed reading a save that was not there. The test now uses a scratch folder of its own under the system temp folder and cleans up after itself.
- **The save contract** is now explicit and tested (D-047): `SaveGame.to_text()` writes a whole save; `SaveGame.restore()` is the one call that turns save text back into a simulation and never crashes on bad input; `SaveGame.parse()` checks a save has every part; `Simulation.from_save()` is the low-level step `restore()` uses. File writing creates its folder and reports the reason for any failure.
- **A scene self-check** (`-- --self-check`) loads the main scene, confirms the audio loaded, gives an order and runs a day and a half through the same path as play.
- **Verified on Linux, Godot 4.7.2:** 59 tests, 270 checks, 0 failed, also with the per-user data folder unwritable; data validation 0 errors; decade hash and three-day hash unchanged from the README; self-check passed headless and with drawing under a virtual display.
- **Verified on the Mac by Derek** after the fix, with the same results and the same hashes.
- **Not verified by any automated check:** how the game looks and sounds.

### Before M1-B can begin

Done: Derek reviewed the stabilization, ran the checks on the Mac, and authorized M1-B on 2026-11-13 (D-046).

### M1-B: the complete first week — authorized (D-046); steps 1 to 10 built

Scope and order as set by Derek (D-045). Implement only this, in this order, entirely on the fictional fixture:

1. Expand the fictional fixture scenario to four to six households and fifteen to twenty-five residents.
2. Add seven-day schedules with clear weekday, Saturday and Sunday behavior.
3. Define and test any new action and place capabilities needed for interiors, institution entry, shopping and need fulfillment.
4. Add a fictional player-home interior, explicitly labelled fictional.
5. Add one fictional enterable institution.
6. Add the `fun` need and place-specific actions that satisfy needs.
7. Add behavior-based household finances: attendance-based wages, rent, groceries and shortfall.
8. Add the end-of-week summary generated from the event log.
9. Add the building information view, keeping documented exterior facts separate from fictional interiors and fixture content.
10. Add menu save and load, and extend the exact-save tests for every new state field.
11. Playtest the full week and record pacing observations and the final M1 judgment. (Observations from unattended runs are in [M1_PLAYTEST.md](M1_PLAYTEST.md); the playtest by a person and the judgment are Derek's.)

Maynard Street is not part of M1-B. It remains `probable`, unconfirmed research (finding F-058) and is not entered as historical data until confirmed (D-037). Nothing from M2 is to be added.

For every step: tests first when fixing a bug; the core stays independent of scenes, rendering, input and wall-clock time; seeded randomness only; no fractional numbers in state; documents updated when a contract changes; `DECISIONS.md` updated for lasting choices; small single-purpose commits; exact commands and actual results reported.

#### What steps 1 to 10 built (2026-11-15)

Each step was committed on its own, on Fixture Street only. The lasting choices made on the way are proposals P-016 to P-022 in `DECISIONS.md`, implemented and awaiting Derek's confirmation.

1. Five households and seventeen residents, all fictional, with names that are plainly invented.
2. Timetables for weekdays, Saturdays and Sundays: a Saturday shift for one worker, the storekeeper's six-day week, Sunday dinner at 13:00 for every household (P-016).
3. Rooms, institutions with opening hours, the `enter` and `use_room` orders, conversation inside an institution, and a talk that holds up what it interrupts (P-017, P-018).
4. A fictional floor plan for the player's home, drawn as a cutaway labelled "FICTIONAL INTERIOR (invented layout)"; clicking a room sends the selected person there.
5. The Fixture Store: a fictional shop with hours, a storekeeper from the street who works there, and neighbors who drop in.
6. The `fun` need, with a pastime at home, play outdoors for children, looking around the store, and a little from talking.
7. Money that follows behavior: wages for days actually worked, paid Friday; rent on Monday with any shortfall carried forward; a pantry restocked at the store; thin meals when it is empty (P-019). Every amount is invented. The abstract level now agrees with minute-by-minute play on money only roughly (P-020).
8. The end-of-week summary, computed from the event log, opening at each week's end and on request (P-021).
9. Building information on right-click, keeping documented exterior, fictional interior and fictional scenario content apart (P-021). On Fixture Street nothing is documented, and the sheet says so.
10. Menu save and load of one saved game in the per-user data folder (P-022), with exact-save tests for every new state field.

Not built, by design: anything from M2, a routine detail level, Maynard Street data.

**Verified on Linux, Godot 4.7.2, on 2026-11-15:** 105 tests, 2014 checks, 0 failed; data validation 0 errors; self-check passed, including a save and load through the menu; three-day, decade and first-week hashes as given in the README. **Not verified:** none of M1-B has been run on Derek's Mac, and nobody has played M1-B by hand.

### M1 done when (unchanged)

The list below is unchanged. Where each item stands on 2026-11-15, after M1-B step 10, follows it.

1. A new game starts on the block and plays through seven days without errors.
2. If on real data: every building shown traces to a record with provenance and validation passes. If on the fixture: everything is marked placeholder, the game says the place is fictional, and nothing uses real Linden names.
3. Residents left alone keep themselves fed, rested and occupied, keep their schedules, and form or change at least some relationships during the week.
4. The player's choices produce visibly different weeks.
5. Save, quit, load and continue gives the same result as playing straight through.
6. Automated tests pass.
7. Derek plays it and decides whether the loop is worth extending. That judgment, and first observations on pacing (Q-004), are written into `DECISIONS.md`.

| Item | Where it stands |
|---|---|
| 1. Seven days without errors | Met in unattended runs: `playtest_week.gd` runs the first seven days minute by minute and exits 0; tests run up to four weeks. The scene itself has been run for a day and a half by the self-check, not for a full week by a person. |
| 2. Fixture marked fictional | Met: every fixture record is `placeholder`, the banner and the building sheet say the place is fictional, and validation, which forbids the real place names in fixture files, reports 0 errors. |
| 3. Residents look after themselves and relationships change | Met in the unattended week: no need reached zero; 209 conversations; 52 pairs of neighbors met. |
| 4. Choices produce visibly different weeks | Met in automated tests (an ordered conversation happens and the state differs from an undirected run). Whether the difference is visible to a player is for Derek to judge. |
| 5. Save, quit, load and continue | Met in automated tests and in the self-check's save and load through the menu. |
| 6. Automated tests pass | Met: 105 tests, 2014 checks, 0 failed. |
| 7. Derek's judgment and pacing observations | Met: Derek accepted M1 on 2026-11-15 (D-048) and answered two pacing questions (D-056). Observations and his judgment are in [M1_PLAYTEST.md](M1_PLAYTEST.md). |

### Research still needed for Maynard Street

1. Full-resolution images of 1951 sheet 62 and the matching 1957 sheet from loc.gov, to confirm street numbers, stories and construction for the Oliver St. end of Maynard St. (finding F-058 is `probable`).
2. A person's confirmation of those readings.
3. A 1950s aerial photograph and a 1950s street directory (still not found).
4. An answer to Q-017 (how the scenario's fictional residents are named).

## M1-P: polish pass *(authorized, D-057)*

Make the accepted week look and play like a finished small game, still on Fixture Street: a warmer, more detailed drawing of the street, houses and people; a clearer, better-looking interface; smoother controls; and small playability fixes. No M2 systems. Scope and the working look are proposal P-023. What has been done is listed in `docs/HANDOFF.md` until the pass is reviewed.

## M2: A Year on the Block

Continuous play through 1950 with fast-forward; the routine and abstract detail levels in play, with hand-off and agreement tests; interruptions for important events; summaries of skipped time; birthdays and stage transitions; the first life events (births, jobs, courtship, moving) for all households; goals; simulated business fortunes for establishments on the block. Decide Q-007 (household switching). Gather pacing evidence for Q-004.

## M3: The Decade on the Block

The full 1950–1959 run in play; the historical timeline with verified events; documented building and business changes on the block; the remaining life events; player-driven divergence of anchored history, recorded with dates, causes and source references (D-033); the end-of-decade retrospective.

## M4 and beyond

Widen the map block by block as research is completed, which needs Q-002 (boundaries); resident-generation rules informed by Q-006; community events; neighborhood memory and reputation; art direction (Q-008); title (Q-009).
