# game/audio

Placeholder audio, all of it generated from scratch by `tools/make_audio.py` at the repository root. Nothing here is sampled or copied from any recording or existing piece of music.

| File | What it is |
|---|---|
| `music_placeholder_waltz.ogg` | A simple original waltz loop, about a minute long, used as background music |
| `chime_talk.ogg` | A two-note chime played when someone in your household starts a conversation |
| `chime_notice.ogg` | A three-note chime for notices (payday, birthdays, a household short of money) |
| `ambience_day.ogg` | A 24-second seamless loop: very quiet filtered-noise "air" with a slow breeze-like swell, and sparse synthesized bird chirps (swept sine notes in short phrases, from three imagined birds) |
| `ambience_night.ogg` | A 24-second seamless loop: three synthesized crickets (pulsed sine tones around 4 to 5 kHz, each at its own chirp rate) over a quieter, darker air bed |

The ambience follows the in-game time of day, read from the simulation clock: the day loop is full from 06:30 to 18:30, crossfades to the night loop through dusk (18:30 to 20:30) and back through dawn (04:30 to 06:30). It plays under the music and is switched with the chimes by the "Sounds" button; the music has its own button. The birds and crickets are generic sound effects, not a claim about which species lived in Linden.

To regenerate, from the repository root:

    python3 tools/make_audio.py              # everything
    python3 tools/make_audio.py ambience     # only the two ambience loops
    python3 tools/make_audio.py music        # only the waltz and the chimes

The synthesis is seeded and ffmpeg runs in bit-exact mode, so rerunning gives byte-identical ambience files. The waltz and chimes were first encoded before bit-exact mode was added, so regenerating them changes their bytes (not their sound); use `ambience` to leave them alone.

These are stand-ins. They make no claim to period authenticity; the game's real music is an open question (Q-019 in `DECISIONS.md`).

The game loads these files directly at run time, so they work without the editor's import step. If a file is missing the game runs without that sound. The `.ogg.import` files are Godot's import settings, created by `godot --headless --path game --import`.
