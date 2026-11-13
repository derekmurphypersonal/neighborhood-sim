# Roadmap and First Playable Milestone

Status: updated 2026-11-13. **M0 is reviewed and accepted. M1-A is built and its loop accepted by Derek (D-041); the additions he asked for are in and awaiting his check. M1-B has not been started or authorized.** See [DECISIONS.md](../DECISIONS.md).

Milestones are defined by what a player can do at the end of each, not by which systems exist.

## Overview

| Milestone | Name | A player can... | Status |
|---|---|---|---|
| Pre-production | Documentation and review | — read a documented, reviewed design and plan | Done |
| **M0** | Groundwork | — nothing yet; a decade runs headless on a fixture, and candidate blocks in the real Linden are identified | Done; no historical data entered yet |
| **M1** | **A Week on the Block** | live one week of spring 1950 with one household on one block, with pause and speed controls | M1-A accepted; M1-B not started |
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
- 31 automated tests (55 after M1-A).

It deliberately does **not** include: needs, schedules, movement, conversations, relationships, jobs, interiors, any drawing of a map, player control, saves, or the close and routine detail levels. Those are M1 and M2.

### Not verified

- Running on macOS. All verification was on Linux; Godot was not available on Derek's Mac from this session. The code uses nothing platform-specific, but this should be confirmed by running the test command once on the Mac.
- An exported (packaged) build. `data/` is read from beside the project folder, which works when running from the repository. Packaging data into an export is a later task.

### Left over from M0

- **Mac verification.** Not yet reported. The commands and expected results are in the [README](../README.md); the expected hashes changed in M1-A.
- **Version control.** The folder is a git repository whose remote is Derek's personal repository, https://github.com/derekmurphypersonal/neighborhood-sim (D-011). Pushing is done from the Mac, because the assistant's environment has no GitHub credentials for it. Never add a remote under the `iuvonauts` organization.
- **Historical data.** None entered. Maynard Street is chosen (D-037); its readings await confirmation.

## M1: A Week on the Block (first playable) *(confirmed, D-021)*

**The claim M1 tests:** a handful of fictional households on one block, over one ordinary week, is enjoyable to watch and to direct, and feels like a place.

M1 is delivered in two parts with a review between them (D-038). The full plan, dependencies and order are in [M1_PLAN.md](M1_PLAN.md).

**Where:** the Oliver Street end of Maynard Street, about eight to ten houses (D-037). Until the map readings for it are confirmed and entered, M1 runs on the fictional Fixture Street (D-035), which is always identified as fictional on screen and in data. Because areas and scenarios are separate data behind one loader (D-039), the swap needs no simulation code changes.

### M1-A: a small playable loop — built and accepted by Derek (D-041)

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
| Derek can start it and play it | Met for the first build: Derek played it on the Mac and judged the loop good. The bubbles, signals and audio added afterwards were checked by screenshot on Linux only; the audio has not been heard by anyone. |

### Before M1-B can begin

1. Derek tries the additions (bubbles, signals, music) and says whether they are what he wanted.
2. Derek confirms or rejects P-014 and answers Q-018.
3. Derek authorizes M1-B.
4. New commits are pushed to https://github.com/derekmurphypersonal/neighborhood-sim (D-011); see Q-020 for who pushes.

### M1-B: the complete first week — not started

- Four to six households, fifteen to twenty-five residents.
- The player household's home interior, from a fictional floor-plan module matched to the building type (D-032).
- One enterable institution (for Maynard St., the branch library on Oliver St.; on the fixture, a fictional equivalent).
- A fourth need, and needs met by specific actions in specific places.
- Money that follows behavior: wages for days worked, rent, a shopping errand, running short.
- Seven full days with weekday, Saturday and Sunday differences; fast passage while your household sleeps or is away.
- End-of-week summary from the event log.
- Building info view: documented exterior facts with sources; interiors and the fixture labelled fictional.
- Save and load from the menu.
- Maynard St. data in place of the fixture, if confirmed by then.

### M1 done when (unchanged)

1. A new game starts on the block and plays through seven days without errors.
2. If on real data: every building shown traces to a record with provenance and validation passes. If on the fixture: everything is marked placeholder, the game says the place is fictional, and nothing uses real Linden names.
3. Residents left alone keep themselves fed, rested and occupied, keep their schedules, and form or change at least some relationships during the week.
4. The player's choices produce visibly different weeks.
5. Save, quit, load and continue gives the same result as playing straight through.
6. Automated tests pass.
7. Derek plays it and decides whether the loop is worth extending. That judgment, and first observations on pacing (Q-004), are written into `DECISIONS.md`.

### Research still needed for Maynard Street

1. Full-resolution images of 1951 sheet 62 and the matching 1957 sheet from loc.gov, to confirm street numbers, stories and construction for the Oliver St. end of Maynard St. (finding F-058 is `probable`).
2. A person's confirmation of those readings.
3. A 1950s aerial photograph and a 1950s street directory (still not found).
4. An answer to Q-017 (how the scenario's fictional residents are named).

## M2: A Year on the Block

Continuous play through 1950 with fast-forward; the routine and abstract detail levels in play, with hand-off and agreement tests; interruptions for important events; summaries of skipped time; birthdays and stage transitions; the first life events (births, jobs, courtship, moving) for all households; goals; simulated business fortunes for establishments on the block. Decide Q-007 (household switching). Gather pacing evidence for Q-004.

## M3: The Decade on the Block

The full 1950–1959 run in play; the historical timeline with verified events; documented building and business changes on the block; the remaining life events; player-driven divergence of anchored history, recorded with dates, causes and source references (D-033); the end-of-decade retrospective.

## M4 and beyond

Widen the map block by block as research is completed, which needs Q-002 (boundaries); resident-generation rules informed by Q-006; community events; neighborhood memory and reputation; art direction (Q-008); title (Q-009).
