# Handoff

Last updated: 2026-11-15, by Claude (Opus 5.5), after the sixth M1-P round.

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

### Second round (after Derek accepted the look: D-058, D-059)

| Commit (cloud copy) | What |
|---|---|
| Record D-058 and D-059 | P-023 confirmed; "things to try this week" authorized |
| Things to try this week: the report | `game/sim/reports/week_goals.gd` (read-only, from the event log, membership and current regard) and `game/tests/test_week_goals.gd`. Seven goals: meet neighbors, a long chat, make a friend, catch up at the store, stock the pantry, a full week's work, nobody goes hungry |
| M1-P second round | Goals card under the home cutaway, "Done:" toasts with a chime, goals in the week sheet; welcome card on a new game; F follows the selected person; chimney smoke at mealtimes, flower beds, mailboxes, a clothesline, cloud shadows, birds, porch lights; tidier cutaway in narrow rooms; synthesized day (birds) and night (crickets) ambience that follows the game clock, under one "Sounds" toggle with the chimes |

Observations from this round, not acted on:
- **The goals are easy.** Left alone, the default seed completes all seven in the first week. Raise thresholds after Derek plays.
- "Make a friend" reads current regard, so it stays done in later weeks, and a past week's sheet shows today's regard.
- For a household with Saturday shifts, "A full week's work" could show done on Friday and then missed, because a Saturday absence is logged on Sunday. The player's household works weekdays only.
- Godot's `.uid` files and the older `.ogg.import` files are untracked in the cloud copy and have never been committed; the new ones were left uncommitted the same way.

### Third round (Derek: "keep making it more polished")

Three subagents worked in parallel and were all cut off by a usage limit before reporting. Their work was recovered from the working tree, one parse error fixed (`near` declared twice in `world_view.gd`), and everything checked as below before committing.

- **Title screen** painted in code (New game, Continue, Settings, Quit), fade into the game, "Main menu" and "Settings" in the in-game menu.
- **Settings**: music and sound volume (Music and Sounds buses), full screen, kept in `user://settings.cfg`; N toggles sounds. Window letterboxes at 1280×720 and allows HiDPI.
- **Interface**: portrait and mood for the selected person, need icons with smooth bars, a this-week money ledger, neighbors sorted by warmth with a relationship word and two-way regard bars, feed icons and coloured regard changes, a "paused" pill and dimmed street, a new-day ribbon, sheet open/close animations.
- **Week summary** as "The Fixture Street Weekly", with a headline, money chart, closest pairs and goal results; it says the street is made up.
- **Goals**: a pool of fourteen, seven shown each week, chosen from the week's first day.
- **Street**: porches, dormers, bay windows, shutters, curtains, a striped store awning and bench, utility poles and wires, hydrants, garbage cans, a bicycle and wagon, blossoming trees, tulips, mowed stripes, more varied people (hats, builds, children with toys, sitting out on chairs), a vignette and hazy distance.

Not known: whether each agent finished every item on its list (for example a minimum window size and window title). Anything missing will show up on the next pass.

### Fourth round (Derek tried round three on the Mac: "looks great")

Three subagents on Fable 5.2. The map agent stopped on a usage limit before reporting; its work was checked in the working tree (it parses, runs, and the features below are present in the code) and committed. The other two finished and reported.

- **Map:** dashed path and marker to where the selected person was sent; click ripples; doors that swing when people go in and out; a wave when a conversation starts; a cat and a dog (invented decoration, asleep at night); a card about the person under the pointer. Not confirmed: the draw-time measurement and any performance work the agent planned.
- **Building page:** a drawn page with the building's own sketch and separately tagged panels: what the record says (NOT DOCUMENTED on Fixture Street), the invented interior with a floor plan, who lives here (fictional), and the store's hours.
- **Tips:** one-time contextual tips (first select, first conversation, payday, week summary, night, goal done), a Show tips setting; never written by the self-check or screenshots.
- **Tooltips** across the panel; neighbor row hover; Talk greyed with a reason when it can't be used.
- **Sound:** synthesized interface sounds (click, hover on title buttons, sheet open/close, order, doors, goal flourish, payday bell) and a calmer evening music piece that crossfades with the waltz by the game clock; the title plays the evening piece.
- **Title:** parallax, twinkling stars, windows lighting on and off, fade-in, "M1-P preview build" line. Window title "The Neighborhood (working title)", minimum size 960×540.

### Fifth round (on Opus; two subagents, interrupted once by Derek and resumed from their partial work)

- **Performance:** the map is drawn in layers that redraw only when needed (see `ARCHITECTURE.md`). Measured under xvfb, average draw time with a still camera went from about 5–9 ms to 1.4–3.3 ms; panning costs about the same as before (~7 ms).
- **Labels stay inside the map:** bubbles, pills, the hover card and the order flag are nudged inward; bubble stacks near the top flip below the figure.
- **Small touches:** petals drifting from blossoming trees; moths round lit lamps at night.
- **Finding things:** clicking a feed line, a neighbor's name or an already-selected household tab pans the camera there with a brief ring (`focus_ring.gd`, `world_view.focus_on_person/focus_on_building`).
- **Help:** H or F1, a Help button in the top bar, the menu and the title screen open "How to play" (`help_sheet.gd`).
- **F12** saves a picture to `user://screenshots/` (blocked in self-check and screenshot runs; never exercised for real).
- **Speed gauge** beside the speed buttons; clock shimmer at 1 hour/s; pause menu opens with the week so far.
- **HUD edges:** goal progress bars, neighbors list ends on a whole row, empty ledger reads "No money in or out yet this week", long text ellipsizes with a tooltip.

### Sixth round (on Opus; two subagents, both finished)

- **Mini-map** inset (bottom right of the map) when part of the street is out of view; click or drag it to move the camera.
- **Street labels** setting and L key: everyone / your household / only on hover.
- **Morning mist** 05:00–08:00; **double-click** a person to follow them.
- **Feed filters** (All, Your household, Money, Neighbors) and folding of runs of similar news into one expandable line.
- **Settings** in sections (Sound, Display, Play): text size Normal/Large (+14%), street labels, mini-map, show tips, pause in the background (on by default).
- **Tab / Shift+Tab** cycle household members and find them on the street.
- **Colour-independent cues:** arrows on regard changes in the feed and on the map, direction points on neighbor bars, a warning mark on needs below 30%.
- The first week's paper opens with "The street carries on. A new week begins Monday."

Known: with a household member selected, the first click of a double-click on a neighbor still orders a talk (as a single click does). Draw time with a still camera stayed at 1.2–3.2 ms average.

## 3. Test status

Run in the cloud on Linux, Godot 4.7.2 stable, after the sixth round (also: a normal launch through the title screen for 600 frames, no script errors):

| Command | Result |
|---|---|
| `godot --headless --path game --script res://tests/run_tests.gd` | `112 tests, 2246 checks, 0 failed` |
| `godot --headless --path game --script res://tools/validate_data.gd` | `Data validation: 0 error(s).` |
| `godot --path game -- --self-check` (virtual display) | `SELF-CHECK  passed` |
| `godot --headless --path game --script res://tools/playtest_week.gd` | hash `109ad66bc899bdf3db4356d62c3913b40abf64999e34050c683832868f176911` (unchanged) |
| `godot --headless --path game --script res://tools/run_decade.gd -- --seed 1950` | hash `9d475ec1085756455fbc51a0322e45d9fca9fc497ca07a744adf06b2506014bb` (unchanged) |

Screenshots were checked at 07:30, 16:00, 18:30, 21:00 and 02:00, zoomed in, and with the welcome card. **Not verified:** dragging, wheel zoom, hover, F-follow and the "Done:" toast were not exercised by a person; nobody has listened to the ambience (it was checked by measurement: levels, spectrum, loop seams).

## 4. Remaining tasks, in order

1. Derek pushes the commits and plays the second round.
2. Tune the goals' difficulty once he has played (they are constants in `week_goals.gd`).
3. Further polish candidates: a little more variety of weekly goals drawn from a pool; seasons-of-the-day touches (morning mist, rain showers as pure presentation); a nicer week-summary sheet with small charts; keyboard shortcut for Sounds.
4. Pacing questions 2, 3, 4, 5 and 7 in `M1_PLAYTEST.md` stay open; changing them alters the simulation and needs Derek.

## 5. Gotchas

Everything in section 8 of the previous version of this file still holds (git in Derek's folder needs delete permission; commit as Derek with the no-reply address; never touch `iuvonauts`; `const preload`, no `class_name`; untyped declarations are errors). Additionally:

- Godot is not installed on Derek's Mac's Linux shell. Work in a cloud copy made from a `git bundle` of his folder, and bring commits back with `git format-patch` and `git am --committer-date-is-author-date`.
- Decorations use `String.hash()` and their own `RandomNumberGenerator`s, never the simulation's streams. Keep it that way so the simulation hash cannot change because of drawing.
- Map clicks now fire on mouse **release** (so dragging the view does not click). Right-click still fires on press.
- The HUD agent's sheet backdrop blocks clicks on the map while a sheet is open; keyboard handling is unchanged.
