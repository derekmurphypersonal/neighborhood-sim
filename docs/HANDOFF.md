# Handoff

Last updated: 2026-11-15, by Claude (Opus 5.5), after the first M1-P polish commits.

This file says what is in progress and what is next. Settled matters are in [DECISIONS.md](../DECISIONS.md) and [ROADMAP.md](ROADMAP.md) and are not repeated here. Read `DECISIONS.md` first, then this.

## 1. Session goal

Derek accepted M1 ("good for now"), confirmed P-016 to P-022, said relationship pace and first-week rent are fine as they are, and asked for continued work on playability, graphics and look and feel so the week feels like a well-polished, fun game. That is recorded as D-048 to D-057; the polish pass is called **M1-P**. Its scope and working look are proposal **P-023**, which awaits Derek.

## 2. Completed this session

| Commit (cloud copy) | What |
|---|---|
| Record the M1 judgment | D-048 to D-057, P-023, Q-008 updated; `M1_PLAYTEST.md` §4 filled in; `ROADMAP.md` and `CLAUDE.md` status |
| M1-P: restyle the interface | `game/view/hud.gd`: one theme in code (paper, teal, mustard, cherry), top bar with clock and date, coloured need bars, household tabs, neighbor rows, feed newest-first, sheets as cards over a click-blocking backdrop, shortcut tooltips |
| M1-P: redraw the street | `game/view/world_view.gd`: gabled houses with windows, doors, chimneys; brick store with sign and open/closed tag; sidewalks, walks, fences, trees, shrubs, lamps, parked cars; moving shadows, evening light, lit windows and lamp pools; walking figures, children smaller; stacked bubbles; hover highlight and labels; restyled home cutaway. Camera: scroll zoom, drag/arrow pan, R reset; clicks act on release. `main.gd`: `--zoom` for screenshots |
| (this commit) | `docs/ARCHITECTURE.md` view notes; this file |

The simulation core, data and tests are untouched: all state hashes are unchanged.

## 3. Test status

Run in the cloud on Linux, Godot 4.7.2 stable, on the code of the map commit:

| Command | Result |
|---|---|
| `godot --headless --path game --script res://tests/run_tests.gd` | `105 tests, 2014 checks, 0 failed` |
| `godot --headless --path game --script res://tools/validate_data.gd` | `Data validation: 0 error(s).` |
| `godot --path game -- --self-check` (virtual display) | `SELF-CHECK  passed` |
| `godot --headless --path game --script res://tools/playtest_week.gd` | hash `109ad66bc899bdf3db4356d62c3913b40abf64999e34050c683832868f176911` (unchanged) |

Screenshots were checked at 16:00, 18:30, 21:00 and 02:00, and zoomed in. **Not verified:** mouse dragging, wheel zoom and hover were not exercised by a person; nobody has played the new look on the Mac.

## 4. Remaining tasks, in order

1. Derek plays the new look and says what he thinks, and confirms, changes or rejects P-023.
2. Candidate next polish items (none started; each small, presentation-only unless noted):
   - A follow-camera that keeps the selected person in view (key F).
   - A short welcome card on a new game explaining the controls.
   - Sound: soft ambient birds by day and crickets at night, a door sound on entering a building (original or generated, no licensed audio).
   - The kitchen in the home cutaway is narrow; long activity text is cut off there.
   - Possibly "things to try this week" prompts. This edges towards M2 goals, so it needs Derek's say-so first.
3. Pacing questions 2, 3, 4, 5 and 7 in `M1_PLAYTEST.md` stay open; changing them alters the simulation and needs Derek.

## 5. Gotchas

Everything in section 8 of the previous version of this file still holds (git in Derek's folder needs delete permission; commit as Derek with the no-reply address; never touch `iuvonauts`; `const preload`, no `class_name`; untyped declarations are errors). Additionally:

- Godot is not installed on Derek's Mac's Linux shell. Work in a cloud copy made from a `git bundle` of his folder, and bring commits back with `git format-patch` and `git am --committer-date-is-author-date`.
- Decorations use `String.hash()` and their own `RandomNumberGenerator`s, never the simulation's streams. Keep it that way so the simulation hash cannot change because of drawing.
- Map clicks now fire on mouse **release** (so dragging the view does not click). Right-click still fires on press.
- The HUD agent's sheet backdrop blocks clicks on the map while a sheet is open; keyboard handling is unchanged.
