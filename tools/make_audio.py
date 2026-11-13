"""Generates the game's placeholder audio from scratch.

Everything here is synthesized by this script: an original, simple waltz
loop and two short chimes. Nothing is sampled or copied from any recording
or existing composition. Run from the repository root:

    python3 tools/make_audio.py

Requires numpy and ffmpeg. Writes game/audio/*.ogg.
"""
import subprocess, wave
import numpy as np

RATE = 44100
BPM = 92
BEAT = 60.0 / BPM

NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def freq(name: str) -> float:
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[pitch] + 12 * (octave + 1) - 69) / 12)


def tone(name: str, seconds: float, level: float, bright: float = 0.25) -> np.ndarray:
    """A soft, plucked, piano-like tone with a decaying envelope."""
    t = np.arange(int(seconds * RATE)) / RATE
    f = freq(name)
    wave_ = (np.sin(2 * np.pi * f * t)
             + bright * np.sin(2 * np.pi * 2 * f * t) * np.exp(-3 * t)
             + bright * 0.5 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-5 * t))
    envelope = np.minimum(t / 0.012, 1.0) * np.exp(-2.2 * t / max(seconds, 0.4))
    tail = np.minimum((seconds - t) / 0.05, 1.0).clip(0, 1)
    return level * wave_ * envelope * tail


def place(track: np.ndarray, sound: np.ndarray, at_seconds: float) -> None:
    start = int(at_seconds * RATE)
    end = min(start + len(sound), len(track))
    track[start:end] += sound[: end - start]


# A sixteen-bar waltz in C, played twice with a varied melody.
CHORDS = ["C", "Am", "F", "G7", "C", "Am", "Dm", "G7", "F", "C", "Dm", "G7", "C", "F", "G7", "C"]
VOICING = {
    "C": ("C2", ["E3", "G3", "C4"]), "Am": ("A2", ["E3", "A3", "C4"]),
    "F": ("F2", ["F3", "A3", "C4"]), "G7": ("G2", ["F3", "G3", "B3"]),
    "Dm": ("D2", ["F3", "A3", "D4"]),
}
# One entry per bar: (note, start beat, length in beats).
MELODY_A = [
    [("E5", 0, 2), ("G5", 2, 1)], [("A5", 0, 2), ("E5", 2, 1)], [("F5", 0, 1), ("A5", 1, 1), ("C6", 2, 1)], [("B5", 0, 3)],
    [("G5", 0, 2), ("E5", 2, 1)], [("C5", 0, 1), ("E5", 1, 2)], [("D5", 0, 1), ("F5", 1, 1), ("A5", 2, 1)], [("G5", 0, 3)],
    [("A5", 0, 2), ("C6", 2, 1)], [("G5", 0, 2), ("E5", 2, 1)], [("F5", 0, 1), ("D5", 1, 2)], [("D5", 0, 2), ("B4", 2, 1)],
    [("C5", 0, 1), ("E5", 1, 1), ("G5", 2, 1)], [("A5", 0, 2), ("F5", 2, 1)], [("D5", 0, 1), ("F5", 1, 1), ("B4", 2, 1)], [("C5", 0, 3)],
]
MELODY_B = [
    [("G5", 0, 1), ("E5", 1, 1), ("C5", 2, 1)], [("E5", 0, 3)], [("A5", 0, 1), ("F5", 1, 1), ("A5", 2, 1)], [("G5", 0, 2), ("D5", 2, 1)],
    [("E5", 0, 1), ("G5", 1, 1), ("C6", 2, 1)], [("A5", 0, 3)], [("F5", 0, 2), ("D5", 2, 1)], [("B4", 0, 1), ("D5", 1, 2)],
    [("C6", 0, 2), ("A5", 2, 1)], [("G5", 0, 3)], [("F5", 0, 1), ("A5", 1, 1), ("D5", 2, 1)], [("F5", 0, 2), ("D5", 2, 1)],
    [("E5", 0, 2), ("C5", 2, 1)], [("F5", 0, 1), ("A5", 1, 2)], [("G5", 0, 1), ("F5", 1, 1), ("D5", 2, 1)], [("C5", 0, 3)],
]


def make_music() -> np.ndarray:
    bars = len(CHORDS) * 2
    total = bars * 3 * BEAT
    track = np.zeros(int(total * RATE) + RATE * 3)
    for bar in range(bars):
        chord = CHORDS[bar % len(CHORDS)]
        bass, upper = VOICING[chord]
        t0 = bar * 3 * BEAT
        place(track, tone(bass, BEAT * 2.6, 0.30, 0.15), t0)
        for beat in (1, 2):
            for name in upper:
                place(track, tone(name, BEAT * 0.9, 0.075, 0.2), t0 + beat * BEAT)
        melody = (MELODY_A if bar < len(CHORDS) else MELODY_B)[bar % len(CHORDS)]
        for name, start, length in melody:
            place(track, tone(name, BEAT * length * 1.15, 0.16, 0.3), t0 + start * BEAT)
    # A little room sound, then fold the tail back onto the start so the loop is seamless.
    wet = track.copy()
    for delay, gain in ((0.11, 0.25), (0.23, 0.15), (0.37, 0.08)):
        shift = int(delay * RATE)
        wet[shift:] += gain * track[:-shift]
    body = int(total * RATE)
    loop = wet[:body].copy()
    tail = wet[body:]
    loop[: len(tail)] += tail
    return loop / np.max(np.abs(loop)) * 0.7


def make_chime(notes: list[str]) -> np.ndarray:
    track = np.zeros(int(0.9 * RATE))
    for index, name in enumerate(notes):
        place(track, tone(name, 0.6, 0.4, 0.4), index * 0.11)
    return track / np.max(np.abs(track)) * 0.6


def write(path: str, samples: np.ndarray) -> None:
    wav_path = path.replace(".ogg", ".wav")
    with wave.open(wav_path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes((samples * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "4", path], check=True)
    subprocess.run(["rm", wav_path], check=True)


if __name__ == "__main__":
    write("game/audio/music_placeholder_waltz.ogg", make_music())
    write("game/audio/chime_talk.ogg", make_chime(["E5", "A5"]))
    write("game/audio/chime_notice.ogg", make_chime(["C5", "E5", "G5"]))
    print("audio written")
