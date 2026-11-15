# Handoff

Last updated: 2026-11-15, by Claude (Fable 5.2), at the point of handing over to another model.

This file says what is in progress and what is next. Settled matters are in [DECISIONS.md](../DECISIONS.md), [ROADMAP.md](ROADMAP.md) and [M1_PLAN.md](M1_PLAN.md) and are not repeated here. Read `DECISIONS.md` first, then this.

## 1. Session goal

Derek authorized M1-B (D-046) and asked for its eleven steps to be implemented in order, on the fictional fixture only, exactly as scoped in D-045 (the list is in [ROADMAP.md](ROADMAP.md), "M1-B"). The per-step rules are in the same place. He then asked for this handoff so that work can move to another model without re-reading the conversation.

## 2. Completed

All of this is committed in Derek's folder (`/Users/derekmurphy/lindensims`, branch `main`). **Nothing has been pushed: `main` is 13 commits ahead of `origin/main`, plus the commit that adds this file.** Hashes are those in Derek's folder.

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

## 3. In progress

Nothing is half-written. `git status` in Derek's folder was clean after `5425c91`; the only change after it is this file.

Work stopped between step 10 and step 11. The week has been run and measured (figures in section 8), but none of it is written into the documents yet, and the documents still describe the game as it was at M1-A.

## 4. Remaining tasks, in order

1. **Reconcile the documents with what is built.** Each of these still describes M1-A:
   - `README.md`: status line; the Play section (interiors, the store, right-click, This week, Menu and Esc, money panel); test count; the three-day and decade hashes; the `playtest_week.gd` command; remove "no interiors, no saving from the menu".
   - `docs/ARCHITECTURE.md`: section 4 "As built", section 5 layout and "Not yet present", section 6 test count and table (add economy, places, week summary, building information; reword "Detail agreement" per P-020).
   - `docs/WORLD_DATA_MODEL.md` sections 13 and 14: institution records, interiors and their assignment, schedule day kinds, new person and household fields, `last_abstract_day`.
   - `docs/TIME_AND_LIFECYCLE.md`: what the abstract level now does for money; the week summary.
   - `docs/GAME_DESIGN.md` systems table; `docs/ROADMAP.md` M1-B status; `docs/M1_PLAN.md` status notes; `CLAUDE.md` "Current phase"; `game/sim/README.md`; `data/fiction/README.md`, `data/tuning/README.md`.
   - Done when: no document says M1-B is unstarted or lists as missing something that exists; every count and hash in a document matches a command actually run; the full check in section 6 still passes. One commit.
2. **Step 11, the write-up.** Add the pacing observations (section 8) to `docs/M1_PLAN.md` or a short `docs/M1_PLAYTEST.md`, saying plainly that they come from unattended runs and screenshots, not from a person playing. Done when the observations and the open pacing questions are in the repository and Q-004 points to them. The final M1 judgment is Derek's and stays blank until he gives it.
3. **Refresh the Claude project copies** of `DECISIONS.md`, `CLAUDE.md`, `docs/ROADMAP.md`, `docs/GAME_DESIGN.md`, `docs/research/FINDINGS.md`, and add this file. Done when the project copies match the repository.
4. **Report to Derek** with the exact commands run and their actual results, and ask for the items in section 7.

Not to be started without Derek: anything in M2, the routine detail level, entering Maynard Street as data.

## 5. Decisions and proposals this session

- Confirmed by Derek and recorded: **D-046** (M1-B authorized), **D-047** (save contract).
- Proposed, implemented, **not confirmed**: **P-016** timetables by kind of day; **P-017** institutions as area data, interiors assigned by the scenario; **P-018** a talk holds up what it interrupts; **P-019** money follows behavior; **P-020** detail levels agree exactly only on calendar-driven events; **P-021** read-only reports; **P-022** one saved game in the per-user folder.
- No decision was changed. `DECISIONS.md` reflects all of the above as of `5425c91`, including a log line for 2026-11-15.
- Open questions touched but not resolved: Q-004 (pacing; see section 8), Q-016 (where saves live in an exported build).

## 6. Test status

Run on Linux with Godot 4.7.2 stable on 2026-11-15, at the content of `5425c91`:

| Command | Actual result |
|---|---|
| `godot --headless --path game --script res://tests/run_tests.gd` | `105 tests, 2014 checks, 0 failed`, exit 0 |
| `godot --headless --path game --script res://tools/validate_data.gd` | `Data validation: 0 error(s).`, exit 0 |
| `godot --path game -- --self-check` (under a virtual display) | `SELF-CHECK  passed`, including "saved and loaded through the menu; the state is identical", exit 0 |
| `godot --headless --path game --script res://tools/run_days.gd -- --days 3 --seed 1950` | hash `609012b31177b5e61809d25fd118507f1cc5fb658eb55d7ac31fc58458e494b5` |
| `godot --headless --path game --script res://tools/run_decade.gd -- --seed 1950` | `Events logged: 5388`, hash `9d475ec1085756455fbc51a0322e45d9fca9fc497ca07a744adf06b2506014bb` |
| `godot --headless --path game --script res://tools/playtest_week.gd` | hash `109ad66bc899bdf3db4356d62c3913b40abf64999e34050c683832868f176911` |

**Not verified:** none of M1-B has been run on Derek's Mac. The hashes in `README.md` are the old M1-A ones and will not match.

## 7. Waiting on Derek

1. `git push` from his folder. The assistant has no GitHub credentials there and must not be given passwords or tokens.
2. Run the commands in section 6 on the Mac and report whether the three hashes match.
3. Play a week and give the M1 judgment (M1 "done when" item 7 in `ROADMAP.md`).
4. Confirm, change or reject P-016 to P-022.
5. Pacing choices raised in section 8.

## 8. Gotchas and unrecorded observations

**Working setup**
- The authoritative copy is Derek's folder. A cloud working copy only lasts for one session; do not assume it exists. If you work in a cloud copy, move commits across as one `git format-patch --stdout` file and `git am` it, then compare checksums of tracked files on both sides.
- Git in Derek's folder fails with "Operation not permitted" until delete access to the folder has been granted in that session, because git replaces files by deleting them.
- Derek's folder has a `LICENSE` file that came from GitHub; leave it.
- The remote is `derekmurphypersonal/neighborhood-sim`. Never create, push to, or add a remote in the `iuvonauts` organization, and do not apply that organization's repository template here (D-011).
- Commit as "Derek Murphy" with the GitHub no-reply address already set in the folder's git config. Keep his work email out of the repository and out of any external service.
- Do not get past bot checks or CAPTCHAs for research sources; use official bulk downloads.

**Code**
- Scripts use `const X := preload(...)`, never `class_name`. Untyped declarations are errors.
- Only commit when tests, data validation and the self-check all pass. A step was once committed with a failing test; the check is now run before every commit.
- When a patch script makes several edits, confirm each one applied. Two were lost midway earlier in the session.
- The self-check and screenshots need a display. `-- --screenshot <png> --minutes <n> --show week|building|store|menu` opens a sheet before the picture is taken.
- `Simulation.new_game` sets `state.last_abstract_day` to the day before the start. Wages are settled at midnight for the day just ended, and only for days that were followed minute by minute; abstract days credit wages themselves. That is what stops a day being paid twice.
- A meal counts against the pantry when the `eat` action finishes, and a shopping trip buys when the `shop` action finishes. An action dropped before it finishes does neither.
- Visitors are put out of an institution when it closes; staff finish their shift. No talk starts indoors within the longest talk's length of closing time.
- The player's order outranks the timetable. Keeping the worker at home all day loses that day's wage and logs `missed_work`; this is intended.
- The old test that required identical household money at both detail levels was replaced (P-020). Do not restore it.

**What the unattended week showed** (seed 1950; all amounts invented for the fixture)
- Nobody's needs bottomed out: four person-hours with hunger below 20 in the week, none for the other needs.
- 209 conversations in the week, 49 of them on Saturday. The player's household alone had 87 talks with outsiders, and one pair reached regard +40 and +62 in seven days. That is probably too fast for a decade-long game and is the main pacing question for Derek.
- Children played outdoors for only 7 hours in total; `sit_out` took 257 hours. Play may be too rare to notice.
- For 42% of the daytime none of the player's household was out on the street, talking or shopping.
- Money: every household ended the first week ahead. Over four weeks the household with only other income (Twoson) had six days with an empty pantry and went short on groceries twice, as its figures were set to allow. The two-earner household (Fourman) piles up money quickly and had one empty-pantry day, because its only free shopper gets home half an hour before the store shuts.
- The HUD overflow with seventeen residents is fixed: the neighbor list scrolls and the money panel shows only the player's household.
- These come from unattended runs and screenshots. Nobody has played M1-B by hand.
