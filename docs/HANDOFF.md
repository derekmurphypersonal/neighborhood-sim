# Handoff

Last updated: 2026-11-15, by Claude (Opus), after finishing the handover tasks left by Claude (Fable 5.2).

This file says what is in progress and what is next. Settled matters are in [DECISIONS.md](../DECISIONS.md), [ROADMAP.md](ROADMAP.md) and [M1_PLAN.md](M1_PLAN.md) and are not repeated here. Read `DECISIONS.md` first, then this.

## 1. Session goal

Derek authorized M1-B (D-046) and asked for its eleven steps to be implemented in order, on the fictional fixture only, exactly as scoped in D-045 (the list is in [ROADMAP.md](ROADMAP.md), "M1-B"). Steps 1 to 10 were built by Claude (Fable 5.2), which then wrote a handoff. This session, a second model took over to do only what that handoff left: reconcile the documents with what is built, write up step 11 as far as it can go without a person playing, and refresh the Claude project copies of the main documents. No code, data or game behavior was changed.

## 2. Completed

All of this is committed in Derek's folder (`/Users/derekmurphy/lindensims`, branch `main`). Hashes are those in Derek's folder. According to the folder's own record of the remote (not refreshed by a fetch), `origin/main` is at `cae78e3`, so the commits below it appear to have been pushed; the three commits from this session are not pushed.

| Commit | What | Main files |
|---|---|---|
| `1ce9d18` | Mac verification recorded, D-046 and D-047, self-check no longer plays audio | `DECISIONS.md`, `CLAUDE.md`, `docs/ROADMAP.md`, `game/view/main.gd` |
| `e52c433` | Step 1: five households, seventeen residents | `data/fiction/scenarios/fixture_street_spring_1950.json`, tests |
| `d6422d6` | Step 2: weekday, Saturday and Sunday timetables; Sunday dinner | `data/fiction/schedules.json`, `game/sim/systems/behavior.gd`, `game/sim/clock/sim_date.gd` |
| `7979d3a` | Step 3: rooms, institutions with hours, `enter` and `use_room` orders, talk indoors, resume after a talk | `game/sim/world/area.gd`, `behavior.gd`, `social.gd`, `simulation.gd`, `game/tests/test_places.gd` |
| `74051b1` | Step 4: fictional floor plan for the player's home, cutaway labelled fictional | `data/fiction/interiors/floor_plans.json`, `game/sim/io/world_loader.gd`, `game/view/world_view.gd` |
| `d40ca8d` | Step 5: Fixture Store, a storekeeper who works on the street, drop-ins | `data/dev_fixture/areas/fixture_street/area.json`, scenario, `behavior.gd`, view |
| `8de4b34` | Step 6: the `fun` need; table-driven need gains; pastime and play | `game/sim/systems/needs.gd`, `records.gd`, `data/tuning/daily_life.json`, `hud.gd` |
| `4d164df` | Step 7: wages by attendance, rent, pantry and shopping, shortfall | `game/sim/systems/economy.gd`, `behavior.gd`, `records.gd`, `world_state.gd`, `data/tuning/economy.json`, scenario, `game/tests/test_economy.gd`, `hud.gd`, `describe.gd` |
| `505705f` | Step 8: week summary from the event log, shown at week's end and on request | `game/sim/reports/week_summary.gd`, `game/tests/test_week_summary.gd`, `hud.gd` (the sheet), `main.gd`, `describe.gd` |
| `38be69d` | Step 9: building information on right-click | `game/sim/reports/building_info.gd`, `game/tests/test_building_info.gd`, `world_view.gd`, `main.gd`, `describe.gd` |
| `b1f096b` | Step 10: Menu with Save game and Load game; exact-save tests for every new field | `game/view/main.gd`, `hud.gd`, `game/tests/test_save_load.gd` |
| `d3cdb08` | A tool that runs the first week and prints pacing figures | `game/tools/playtest_week.gd` |
| `5425c91` | Proposals P-016 to P-022 recorded; the handoff rule added to `CLAUDE.md` | `DECISIONS.md`, `CLAUDE.md` |
| `cae78e3` | The previous version of this file | `docs/HANDOFF.md` |
| `9c6f800` | Documents reconciled with M1-B steps 1 to 10 | `README.md`, `CLAUDE.md`, `docs/ARCHITECTURE.md`, `docs/WORLD_DATA_MODEL.md`, `docs/TIME_AND_LIFECYCLE.md`, `docs/GAME_DESIGN.md`, `docs/ROADMAP.md`, `docs/M1_PLAN.md`, `game/sim/README.md`, `data/fiction/README.md`, `data/tuning/README.md` |
| `2143ce9` | Step 11 write-up: pacing observations from unattended runs; Q-004 points to it | `docs/M1_PLAYTEST.md`, `DECISIONS.md`, `README.md`, `docs/ROADMAP.md`, `docs/M1_PLAN.md` |
| (this commit) | This file brought up to date | `docs/HANDOFF.md` |

The Claude project copies of `DECISIONS.md`, `CLAUDE.md`, `docs/ROADMAP.md`, `docs/GAME_DESIGN.md` and `docs/research/FINDINGS.md` were replaced with the repository versions as of `2143ce9`. The project copy of this file is replaced from this commit as the last step of the session. The project tool could not upload the files directly in this session, so their text was passed to it as written content; if a project copy ever differs from the repository, the repository is authoritative.

## 3. In progress

Nothing. `git status` in Derek's folder was empty after `2143ce9`, and tracked files matched the cloud working copy exactly (checksum of all tracked files except `LICENSE`).

## 4. Remaining tasks, in order

1. **Report to Derek** with the exact commands run and their results (section 6), and ask for the items in section 7.
2. Nothing else is to be done without Derek. In particular, not to be started: anything in M2, the routine detail level, entering Maynard Street as data, or any change prompted by the pacing questions in `docs/M1_PLAYTEST.md`.

## 5. Decisions and proposals

- Confirmed by Derek and recorded: **D-046** (M1-B authorized), **D-047** (save contract).
- Proposed, implemented, **not confirmed**: **P-016** timetables by kind of day; **P-017** institutions as area data, interiors assigned by the scenario; **P-018** a talk holds up what it interrupts; **P-019** money follows behavior; **P-020** detail levels agree exactly only on calendar-driven events; **P-021** read-only reports; **P-022** one saved game in the per-user folder.
- No decision was changed this session. `DECISIONS.md` gained a change-log line for 2026-11-15 and Q-004 now points to `docs/M1_PLAYTEST.md`.
- Open questions touched but not resolved: Q-004 (pacing), Q-016 (where saves live in an exported build).

## 6. Test status

Run on Linux with Godot 4.7.2 stable on 2026-11-15, on the content of `2143ce9` (code and data unchanged since `5425c91`):

| Command | Actual result |
|---|---|
| `godot --headless --path game --script res://tests/run_tests.gd` | `105 tests, 2014 checks, 0 failed`, exit 0 |
| `godot --headless --path game --script res://tools/validate_data.gd` | `Data validation: 0 error(s).`, exit 0 |
| `godot --path game -- --self-check` (under a virtual display) | `SELF-CHECK  passed`, including "saved and loaded through the menu; the state is identical", exit 0 |
| `godot --headless --path game --script res://tools/run_days.gd -- --days 3 --seed 1950` | hash `609012b31177b5e61809d25fd118507f1cc5fb658eb55d7ac31fc58458e494b5` |
| `godot --headless --path game --script res://tools/run_decade.gd -- --seed 1950` | `Events logged: 5388`, hash `9d475ec1085756455fbc51a0322e45d9fca9fc497ca07a744adf06b2506014bb` |
| `godot --headless --path game --script res://tools/playtest_week.gd` | hash `109ad66bc899bdf3db4356d62c3913b40abf64999e34050c683832868f176911` |

The README now gives these three hashes as the expected values.

**Not verified:** none of M1-B has been run on Derek's Mac, and nobody has played M1-B by hand.

## 7. Waiting on Derek

1. `git push` from his folder (three commits: `9c6f800`, `2143ce9` and the one that adds this version of this file). The assistant has no GitHub credentials there and must not be given passwords or tokens.
2. Run the commands in section 6 on the Mac and report whether the three hashes match.
3. Play a week and give the M1 judgment (M1 "done when" item 7 in `ROADMAP.md`); the place for it is section 4 of `docs/M1_PLAYTEST.md`.
4. Confirm, change or reject P-016 to P-022.
5. The pacing questions in section 3 of `docs/M1_PLAYTEST.md`, including whether the first week should charge rent (below).

## 8. Gotchas and unrecorded observations

**Working setup**
- The authoritative copy is Derek's folder. A cloud working copy only lasts for one session; do not assume it exists. If you work in a cloud copy, move commits across as one `git format-patch --stdout` file and `git am --committer-date-is-author-date` it, then compare checksums of tracked files on both sides. Commit hashes differ between the two copies, because Derek's folder has a `LICENSE` file the cloud copy lacks.
- Git in Derek's folder fails with "Operation not permitted" until delete access to the folder has been granted in that session, because git replaces files by deleting them.
- Derek's folder has a `LICENSE` file that came from GitHub; leave it.
- The remote is `derekmurphypersonal/neighborhood-sim`. Never create, push to, or add a remote in the `iuvonauts` organization, and do not apply that organization's repository template here (D-011).
- Commit as "Derek Murphy" with the GitHub no-reply address already set in the folder's git config. Keep his work email out of the repository and out of any external service.
- Do not get past bot checks or CAPTCHAs for research sources; use official bulk downloads.
- The project tool's `local_path` upload was refused in this session ("not available in this session"); document text had to be passed as content.

**Code**
- Scripts use `const X := preload(...)`, never `class_name`. Untyped declarations are errors.
- Only commit when tests, data validation and the self-check all pass.
- When a patch script makes several edits, confirm each one applied.
- The self-check and screenshots need a display. `-- --screenshot <png> --minutes <n> --show week|building|store|menu` opens a sheet before the picture is taken.
- `Simulation.new_game` sets `state.last_abstract_day` to the day before the start. Wages are settled at midnight for the day just ended, and only for days that were followed minute by minute; abstract days credit wages themselves. That is what stops a day being paid twice.
- A meal counts against the pantry when the `eat` action finishes, and a shopping trip buys when the `shop` action finishes. An action dropped before it finishes does neither.
- Visitors are put out of an institution when it closes; staff finish their shift. No talk starts indoors within the longest talk's length of closing time.
- The player's order outranks the timetable. Keeping the worker at home all day loses that day's wage and logs `missed_work`; this is intended.
- The old test that required identical household money at both detail levels was replaced (P-020). Do not restore it.

**Found this session, not changed** (each would change behavior or code, so each waits for Derek)
- **No rent in the first week.** The scenario starts on Monday at 06:00. Day-level work (birthdays, wage settlement, rent on Mondays) runs when a tick lands on midnight, and `new_game` does not run it for the starting day, so the first rent is collected on Monday 10 April. Confirmed by a one-off run: rent events on 10 and 17 April, paydays on 7 and 14 April. A birthday falling on the start day would be missed the same way; none does in the fixture. Raised as pacing question 6 in `docs/M1_PLAYTEST.md`.
- **Stale code comments.** The header of `game/sim/simulation.gd` still says day-level work is "birthdays, the weekly budget"; the weekly budget was replaced in step 7. The header of `game/view/main.gd` calls it "the game's main scene for M1-A". Comments only; left alone because this session was documents-only.

**What the unattended week showed**: now written up in [M1_PLAYTEST.md](M1_PLAYTEST.md), with every figure re-measured this session. Nobody has played M1-B by hand.
