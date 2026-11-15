"""Generates the game's placeholder audio from scratch.

Everything here is synthesized by this script: an original, simple waltz
loop, two short chimes, and two ambience loops (a daytime outdoor bed with
birdsong, and a night bed with crickets). Nothing is sampled or copied from
any recording or existing composition. Run from the repository root:

    python3 tools/make_audio.py              # everything
    python3 tools/make_audio.py ambience     # only the two ambience loops
    python3 tools/make_audio.py music        # only the waltz and the chimes

Requires numpy and ffmpeg. Writes game/audio/*.ogg. The synthesis is seeded,
and the encoder is run in bit-exact mode, so a rerun gives the same files.
(The waltz and chimes were first written before bit-exact mode was used, so
regenerating them changes their bytes, though not their sound.)
"""
import subprocess, sys, wave
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


# --- Ambience ----------------------------------------------------------------
# Both loops are built to be exactly periodic: the air is shaped noise made in
# the frequency domain (so it wraps around by construction), every slow swell
# completes a whole number of cycles in the loop, and any sound that runs past
# the end is folded back onto the start, crossfading the tail into the head.

AMBIENCE_RATE = 22050
AMBIENCE_SECONDS = 24.0


def air(n: int, rng: np.random.Generator, low_hz: float, high_hz: float) -> np.ndarray:
    """Soft, periodic, band-limited noise with a gentle pink tilt; unit RMS."""
    freqs = np.fft.rfftfreq(n, 1.0 / AMBIENCE_RATE)
    shape = np.zeros_like(freqs)
    band = freqs > 0
    shape[band] = 1.0 / np.sqrt(freqs[band])
    shape *= 1.0 / (1.0 + (low_hz / np.maximum(freqs, 1e-9)) ** 4)   # roll off rumble
    shape *= 1.0 / (1.0 + (freqs / high_hz) ** 4)                      # roll off hiss
    spectrum = shape * np.exp(2j * np.pi * rng.random(len(freqs)))
    noise = np.fft.irfft(spectrum, n)
    return noise / np.sqrt(np.mean(noise ** 2))


def swell(n: int, cycles: list[int], depth: float, rng: np.random.Generator) -> np.ndarray:
    """A slow, loop-periodic level change (whole cycles only), between 1-depth and 1."""
    t = np.arange(n) / n
    s = sum(np.sin(2 * np.pi * c * t + rng.random() * 2 * np.pi) for c in cycles) / len(cycles)
    return 1.0 - depth * (0.5 + 0.5 * s)


def fold(track: np.ndarray, sound: np.ndarray, start: int) -> None:
    """Adds a sound at a sample offset, wrapping anything past the end onto the start."""
    index = (start + np.arange(len(sound))) % len(track)
    np.add.at(track, index, sound)


def chirp(f0: float, f1: float, seconds: float, level: float) -> np.ndarray:
    """One bird note: a sine swept from f0 to f1 with a soft overtone."""
    n = int(seconds * AMBIENCE_RATE)
    t = np.arange(n) / AMBIENCE_RATE
    sweep = f0 + (f1 - f0) * (t / seconds) ** 0.8
    phase = 2 * np.pi * np.cumsum(sweep) / AMBIENCE_RATE
    envelope = np.sin(np.pi * t / seconds) ** 2
    return level * envelope * (np.sin(phase) + 0.12 * np.sin(2 * phase))


# Each imagined bird has its own range of pitch, note length and phrase length.
BIRDS = [
    {"low": 2600.0, "high": 3600.0, "note": (0.06, 0.12), "notes": (2, 4), "gap": (0.06, 0.12), "level": 0.30},
    {"low": 3400.0, "high": 4800.0, "note": (0.03, 0.06), "notes": (3, 6), "gap": (0.04, 0.07), "level": 0.18},
    {"low": 1900.0, "high": 2700.0, "note": (0.15, 0.25), "notes": (2, 3), "gap": (0.10, 0.18), "level": 0.22},
]


def bird_phrase(bird: dict, rng: np.random.Generator) -> np.ndarray:
    notes = int(rng.integers(bird["notes"][0], bird["notes"][1] + 1))
    base = rng.uniform(bird["low"], bird["high"])
    upward = rng.random() < 0.5
    pieces = []
    for i in range(notes):
        length = rng.uniform(*bird["note"])
        top = base * rng.uniform(1.10, 1.35)
        f0, f1 = (base, top) if (upward ^ (i % 2 == 1)) else (top, base)
        level = bird["level"] * rng.uniform(0.6, 1.0) * (0.85 if i == notes - 1 else 1.0)
        pieces.append(chirp(f0, f1, length, level))
        pieces.append(np.zeros(int(rng.uniform(*bird["gap"]) * AMBIENCE_RATE)))
        base *= rng.uniform(0.94, 1.06)
    return np.concatenate(pieces)


def make_day() -> np.ndarray:
    rng = np.random.default_rng(1950)
    n = int(AMBIENCE_SECONDS * AMBIENCE_RATE)
    bed = 0.045 * air(n, rng, 120.0, 1400.0) * swell(n, [1, 3], 0.55, rng)
    birds = np.zeros(n)
    # Sparse phrases: one every few seconds, from a randomly chosen bird.
    at = rng.uniform(0.3, 1.5)
    while at < AMBIENCE_SECONDS:
        bird = BIRDS[int(rng.integers(len(BIRDS)))]
        phrase = bird_phrase(bird, rng)
        # Farther birds are quieter and a touch duller.
        distance = rng.uniform(0.35, 1.0)
        fold(birds, distance * phrase, int(at * AMBIENCE_RATE))
        at += rng.uniform(2.2, 5.5)
    return normalize(bed + birds, 0.55)


def make_night() -> np.ndarray:
    rng = np.random.default_rng(1959)
    n = int(AMBIENCE_SECONDS * AMBIENCE_RATE)
    bed = 0.025 * air(n, rng, 90.0, 900.0) * swell(n, [1, 2], 0.5, rng)
    crickets = np.zeros(n)
    t = np.arange(n) / AMBIENCE_RATE
    # (carrier Hz, chirps in the loop, pulses per chirp, level, swell cycles).
    # Whole numbers of chirps per loop keep each cricket's rhythm unbroken at the seam.
    for carrier, chirps, pulses, level, cycles in ((4400.0, 60, 3, 0.20, [2]),
                                                  (4850.0, 44, 4, 0.13, [1, 3]),
                                                  (4050.0, 78, 2, 0.08, [1])):
        period = n // chirps
        pulse = int(0.016 * AMBIENCE_RATE)
        gap = int(0.014 * AMBIENCE_RATE)
        one = np.zeros(period)
        shape = np.sin(np.pi * np.arange(pulse) / pulse) ** 2
        for p in range(pulses):
            one[p * (pulse + gap): p * (pulse + gap) + pulse] = shape
        gate = np.tile(one, chirps + 1)[:n]
        gate = np.roll(gate, int(rng.integers(period)))
        vibrato = 1.0 + 0.002 * np.sin(2 * np.pi * 7.0 * t)
        tone_ = np.sin(2 * np.pi * carrier * np.cumsum(vibrato) / AMBIENCE_RATE)
        crickets += level * gate * tone_ * swell(n, cycles, 0.6, rng)
    return normalize(bed + crickets, 0.45)


def normalize(samples: np.ndarray, peak: float) -> np.ndarray:
    return samples / np.max(np.abs(samples)) * peak


def write(path: str, samples: np.ndarray, rate: int = RATE, quality: str = "4") -> None:
    wav_path = path.replace(".ogg", ".wav")
    with wave.open(wav_path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes((samples * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", quality,
                    "-fflags", "+bitexact", "-flags", "+bitexact", "-map_metadata", "-1", path], check=True)
    subprocess.run(["rm", wav_path], check=True)


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    if which not in ("all", "music", "ambience"):
        sys.exit("usage: make_audio.py [all|music|ambience]")
    if which in ("all", "music"):
        write("game/audio/music_placeholder_waltz.ogg", make_music())
        write("game/audio/chime_talk.ogg", make_chime(["E5", "A5"]))
        write("game/audio/chime_notice.ogg", make_chime(["C5", "E5", "G5"]))
    if which in ("all", "ambience"):
        write("game/audio/ambience_day.ogg", make_day(), AMBIENCE_RATE, "2")
        write("game/audio/ambience_night.ogg", make_night(), AMBIENCE_RATE, "2")
    print("audio written")
