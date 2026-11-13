# game/audio

Placeholder audio, all of it generated from scratch by `tools/make_audio.py` at the repository root. Nothing here is sampled or copied from any recording or existing piece of music.

| File | What it is |
|---|---|
| `music_placeholder_waltz.ogg` | A simple original waltz loop, about a minute long, used as background music |
| `chime_talk.ogg` | A two-note chime played when someone in your household starts a conversation |
| `chime_notice.ogg` | A three-note chime for notices (payday, birthdays, a household short of money) |

These are stand-ins. They make no claim to period authenticity; the game's real music is an open question (Q-019 in `DECISIONS.md`).

The game loads these files directly at run time, so they work without the editor's import step. If a file is missing the game runs silently.
