# game/audio

Placeholder audio, all of it generated from scratch by `tools/make_audio.py` at the repository root. Nothing here is sampled or copied from any recording or existing piece of music.

| File | What it is |
|---|---|
| `music_placeholder_waltz.ogg` | A simple original waltz loop, about a minute long: the background music by day |
| `music_placeholder_evening.ogg` | A second original loop in the same synthesized style, slower (four beats to the bar, broken chords under a sparse melody), about 58 seconds: the background music in the evening and overnight, and on the title screen |
| `chime_talk.ogg` | A two-note chime played when someone in your household starts a conversation |
| `chime_notice.ogg` | A three-note chime for notices (birthdays, rent, shopping, a household short of money) |
| `ambience_day.ogg` | A 24-second seamless loop: very quiet filtered-noise "air" with a slow breeze-like swell, and sparse synthesized bird chirps (swept sine notes in short phrases, from three imagined birds) |
| `ui_click.ogg` | A soft "tock" (a short falling tone) when any button is pressed |
| `ui_hover.ogg` | A very quiet tick when the pointer comes onto a title-screen button |
| `ui_sheet_open.ogg`, `ui_sheet_close.ogg` | A page-like swish of shaped noise when a sheet (menu, building page, week summary, settings) opens or closes |
| `ui_order.ogg` | Two quick rising notes when an order is accepted |
| `door_open.ogg`, `door_close.ogg` | A soft wooden thump with a small latch noise, when someone in your household leaves a building (open) or goes into one (close) |
| `chime_goal.ogg` | A three-note flourish when one of the week's things to try is done |
| `chime_payday.ogg` | A small bell "ding" after a soft knock, for your household's payday |
| `ambience_night.ogg` | A 24-second seamless loop: three synthesized crickets (pulsed sine tones around 4 to 5 kHz, each at its own chirp rate) over a quieter, darker air bed |

The ambience follows the in-game time of day, read from the simulation clock: the day loop is full from 06:30 to 18:30, crossfades to the night loop through dusk (18:30 to 20:30) and back through dawn (04:30 to 06:30). It plays under the music and is switched with the chimes and interface sounds by the "Sounds" button (and follows the Sounds volume); the music has its own button and volume.

The music also follows the in-game clock: the evening piece comes in over 18:30 to 19:30 and gives way to the waltz over 04:30 to 05:30, with an equal-power crossfade that never moves faster than a quarter of the way per real second, so it stays gentle at the fastest game speed. With no game on screen (the title) the evening piece plays.

The interface sounds are built from decaying sine tones and shaped noise. They are generic and imitate no particular product's sound; the door and the bell are sound effects, not a claim about any real door or cash register. The birds and crickets are generic sound effects, not a claim about which species lived in Linden.

To regenerate, from the repository root:

    python3 tools/make_audio.py --missing    # only files that do not exist yet
    python3 tools/make_audio.py              # everything
    python3 tools/make_audio.py ambience     # only the two ambience loops
    python3 tools/make_audio.py music        # only the waltz and the talk and notice chimes
    python3 tools/make_audio.py evening      # only the evening piece
    python3 tools/make_audio.py ui           # only the interface sounds

The synthesis is seeded and ffmpeg runs in bit-exact mode, so rerunning gives byte-identical ambience, evening and interface files. The waltz and the talk and notice chimes were first encoded before bit-exact mode was added, so regenerating them changes their bytes (not their sound); use `--missing` or a single group to leave them alone.

These are stand-ins. Both pieces of music are original placeholders written for this project; they make no claim to period authenticity and are not arrangements of any existing tune; the game's real music is an open question (Q-019 in `DECISIONS.md`).

The game loads these files directly at run time, so they work without the editor's import step. If a file is missing the game runs without that sound. The `.ogg.import` files are Godot's import settings, created by `godot --headless --path game --import`.
