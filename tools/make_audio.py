"""Generates the game's placeholder audio from scratch.

Everything here is synthesized by this script: two original, simple music
loops (a waltz for the day and a slower piece for the evening), short chimes,
two ambience loops (a daytime outdoor bed with birdsong, and a night bed with
crickets) and a handful of short interface sounds (clicks, a page swish, a
door, a bell). Nothing is sampled or copied from any recording or existing
composition, and no sound imitates a particular product's sound.
Run from the repository root:

    python3 tools/make_audio.py --missing    # only files that do not exist yet
    python3 tools/make_audio.py              # everything
    python3 tools/make_audio.py ambience     # only the two ambience loops
    python3 tools/make_audio.py music        # only the waltz and the two chimes
    python3 tools/make_audio.py evening      # only the evening piece
    python3 tools/make_audio.py ui           # only the interface sounds

Requires numpy and ffmpeg. Writes game/audio/*.ogg. The synthesis is seeded,
and the encoder is run in bit-exact mode, so a rerun gives the same files.
(The waltz and chimes were first written before bit-exact mode was used, so
regenerating them changes their bytes, though not their sound. --missing
leaves every existing file alone.)
"""
import os
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


# --- The evening piece ---------------------------------------------------------
# A second original placeholder: slower than the waltz, four beats to the bar,
# in F, with broken chords under a sparse melody. Sixteen bars, about a minute.

EVENING_BPM = 66
EVENING_BEAT = 60.0 / EVENING_BPM
EVENING_CHORDS = ["F", "Dm", "Bb", "C", "F", "Am", "Bb", "C", "Dm", "Bb", "F", "C", "Bb", "Am", "Gm", "C"]
# Bass note, then the broken chord played on beats 1, 2, 3 and the half beat after.
EVENING_VOICING = {
    "F": ("F2", ["C3", "F3", "A3", "C4"]), "Dm": ("D2", ["A2", "D3", "F3", "A3"]),
    "Bb": ("A#1", ["F3", "A#3", "D4", "F3"]), "C": ("C2", ["G2", "C3", "E3", "G3"]),
    "Am": ("A1", ["E3", "A3", "C4", "E3"]), "Gm": ("G1", ["D3", "G3", "A#3", "D3"]),
}
# One entry per bar: (note, start beat, length in beats). Long notes, with rests.
EVENING_MELODY = [
    [("A4", 0, 3), ("C5", 3, 1)], [("D5", 0, 2), ("A4", 2, 2)], [("A#4", 0, 3), ("D5", 3, 1)], [("C5", 0, 4)],
    [("A4", 1, 1), ("C5", 2, 2)], [("E5", 0, 3), ("C5", 3, 1)], [("D5", 0, 2), ("A#4", 2, 2)], [("G4", 0, 4)],
    [("F5", 0, 3), ("D5", 3, 1)], [("D5", 0, 2), ("A#4", 2, 2)], [("C5", 0, 3), ("A4", 3, 1)], [("G4", 0, 2), ("E4", 2, 2)],
    [("D5", 1, 1), ("F5", 2, 2)], [("E5", 0, 2), ("C5", 2, 2)], [("D5", 0, 2), ("A#4", 2, 2)], [("G4", 0, 3), ("E4", 3, 1)],
]


def make_evening() -> np.ndarray:
    beat = EVENING_BEAT
    bars = len(EVENING_CHORDS)
    total = bars * 4 * beat
    track = np.zeros(int(total * RATE) + RATE * 4)
    for bar in range(bars):
        bass, broken = EVENING_VOICING[EVENING_CHORDS[bar]]
        t0 = bar * 4 * beat
        place(track, tone(bass, beat * 3.8, 0.26, 0.10), t0)
        for step, name in enumerate(broken):
            place(track, tone(name, beat * 1.6, 0.065, 0.12), t0 + (1 + step * 0.75) * beat)
        for name, start, length in EVENING_MELODY[bar]:
            place(track, tone(name, beat * length * 1.2, 0.13, 0.18), t0 + start * beat)
    # A longer, softer room than the waltz's, then fold the tail onto the start.
    wet = track.copy()
    for delay, gain in ((0.13, 0.28), (0.29, 0.18), (0.47, 0.11), (0.71, 0.06)):
        shift = int(delay * RATE)
        wet[shift:] += gain * track[:-shift]
    body = int(total * RATE)
    loop = wet[:body].copy()
    tail = wet[body:]
    loop[: len(tail)] += tail
    return loop / np.max(np.abs(loop)) * 0.6


# --- Interface sounds ------------------------------------------------------------
# Short, soft and quiet. Each is built from decaying sines and shaped noise.

def ui_rng(name: str) -> np.random.Generator:
    return np.random.default_rng(sum(ord(c) * (i + 1) for i, c in enumerate(name)))


def seconds_of(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def ping(hz: float, seconds: float, decay: float, attack: float = 0.003, glide: float = 1.0) -> np.ndarray:
    """A decaying sine. glide is the ratio of the end pitch to the start pitch."""
    t = seconds_of(seconds)
    sweep = hz * glide ** (t / seconds)
    phase = 2 * np.pi * np.cumsum(sweep) / RATE
    return np.sin(phase) * np.minimum(t / attack, 1.0) * np.exp(-decay * t)


def band_noise(seconds: float, low_hz: float, high_hz: float, rng: np.random.Generator) -> np.ndarray:
    """Noise limited to a band by shaping its spectrum; unit RMS."""
    n = int(seconds * RATE)
    freqs = np.fft.rfftfreq(n, 1.0 / RATE)
    shape = 1.0 / (1.0 + (low_hz / np.maximum(freqs, 1e-9)) ** 4) / (1.0 + (freqs / high_hz) ** 4)
    noise = np.fft.irfft(np.fft.rfft(rng.standard_normal(n)) * shape, n)
    return noise / np.sqrt(np.mean(noise ** 2))


def finish(samples: np.ndarray, peak: float) -> np.ndarray:
    """Removes any offset, fades the last few milliseconds to nothing, and sets the level."""
    samples = samples - np.mean(samples)
    edge = int(0.004 * RATE)
    samples[:edge // 2] *= np.linspace(0.0, 1.0, edge // 2)
    samples[-edge:] *= np.linspace(1.0, 0.0, edge)
    return samples / np.max(np.abs(samples)) * peak


def make_click() -> np.ndarray:
    """A soft "tock": a short falling tone with a breath of noise at the front."""
    t = seconds_of(0.07)
    body = ping(760.0, 0.07, 70.0, 0.002, 0.7) + 0.35 * ping(1520.0, 0.07, 120.0, 0.002, 0.8)
    tick = 0.25 * band_noise(0.07, 1500.0, 5000.0, ui_rng("click")) * np.exp(-400.0 * t)
    return finish(body + tick, 0.35)


def make_hover() -> np.ndarray:
    """A very quiet tick."""
    return finish(ping(1250.0, 0.04, 130.0, 0.004, 0.92), 0.12)


def make_swish(opening: bool) -> np.ndarray:
    """A page turning: breathy noise whose brightness rises (open) or falls (close)."""
    seconds = 0.26 if opening else 0.20
    rng = ui_rng("swish_open" if opening else "swish_close")
    t = seconds_of(seconds)
    dull = band_noise(seconds, 500.0, 1600.0, rng)
    bright = band_noise(seconds, 1800.0, 6500.0, rng)
    along = t / seconds if opening else 1.0 - t / seconds
    envelope = np.sin(np.pi * (t / seconds) ** (0.6 if opening else 0.45)) ** 2
    flutter = 1.0 + 0.25 * np.sin(2 * np.pi * 38.0 * t)
    return finish(((1.0 - along) * dull + along * 0.8 * bright) * envelope * flutter, 0.22)


def make_order() -> np.ndarray:
    """Two quick rising notes: "understood"."""
    track = np.zeros(int(0.30 * RATE))
    for index, name in enumerate(("G5", "D6")):
        note = ping(freq(name), 0.2, 22.0) + 0.2 * ping(freq(name) * 2, 0.2, 40.0)
        place(track, note, index * 0.075)
    return finish(track, 0.30)


def thunk(seconds: float, hz: float, rng: np.random.Generator) -> np.ndarray:
    """Wood meeting wood: a low falling thump with a dull knock of noise."""
    t = seconds_of(seconds)
    body = ping(hz, seconds, 28.0, 0.004, 0.6) + 0.5 * ping(hz * 2.3, seconds, 60.0, 0.003, 0.8)
    knock = 0.5 * band_noise(seconds, 200.0, 1200.0, rng) * np.exp(-90.0 * t)
    return body + knock


def make_door(opening: bool) -> np.ndarray:
    rng = ui_rng("door_open" if opening else "door_close")
    track = np.zeros(int(0.42 * RATE))
    if opening:
        # The latch lifts, then the door comes away from its frame.
        latch = 0.35 * band_noise(0.03, 1800.0, 5000.0, rng) * np.exp(-250.0 * seconds_of(0.03))
        place(track, latch, 0.0)
        place(track, 0.7 * thunk(0.3, 150.0, rng), 0.05)
    else:
        # The door meets the frame, and the latch drops a moment after.
        place(track, thunk(0.3, 120.0, rng), 0.0)
        latch = 0.22 * band_noise(0.03, 1500.0, 4500.0, rng) * np.exp(-250.0 * seconds_of(0.03))
        place(track, latch, 0.07)
    return finish(track, 0.38)


def make_goal() -> np.ndarray:
    """A small three-note flourish, the last note held a little."""
    track = np.zeros(int(1.1 * RATE))
    for index, (name, at, length) in enumerate((("G5", 0.0, 0.35), ("C6", 0.10, 0.35), ("E6", 0.20, 0.85))):
        place(track, tone(name, length, 0.4, 0.35), at)
        place(track, 0.06 * ping(freq(name) * 3, length, 9.0), at)
    return finish(track, 0.45)


def make_ding() -> np.ndarray:
    """A small desk-bell "ding" after a soft mechanical knock, for payday."""
    track = np.zeros(int(1.0 * RATE))
    rng = ui_rng("ding")
    place(track, 0.25 * thunk(0.12, 260.0, rng), 0.0)
    base = freq("A6")
    # Bell-like, slightly out-of-tune partials, the higher ones dying sooner.
    for ratio, level, decay in ((1.0, 1.0, 5.0), (2.76, 0.35, 9.0), (5.40, 0.15, 16.0), (0.5, 0.2, 7.0)):
        place(track, level * ping(base * ratio, 0.9, decay, 0.002), 0.06)
    return finish(track, 0.40)


# File name, what makes it, sample rate, encoder quality, and the group it is in.
FILES = [
    ("music_placeholder_waltz.ogg", make_music, RATE, "4", "music"),
    ("chime_talk.ogg", lambda: make_chime(["E5", "A5"]), RATE, "4", "music"),
    ("chime_notice.ogg", lambda: make_chime(["C5", "E5", "G5"]), RATE, "4", "music"),
    ("ambience_day.ogg", make_day, AMBIENCE_RATE, "2", "ambience"),
    ("ambience_night.ogg", make_night, AMBIENCE_RATE, "2", "ambience"),
    ("music_placeholder_evening.ogg", make_evening, RATE, "4", "evening"),
    ("ui_click.ogg", make_click, RATE, "3", "ui"),
    ("ui_hover.ogg", make_hover, RATE, "3", "ui"),
    ("ui_sheet_open.ogg", lambda: make_swish(True), RATE, "3", "ui"),
    ("ui_sheet_close.ogg", lambda: make_swish(False), RATE, "3", "ui"),
    ("ui_order.ogg", make_order, RATE, "3", "ui"),
    ("door_open.ogg", lambda: make_door(True), RATE, "3", "ui"),
    ("door_close.ogg", lambda: make_door(False), RATE, "3", "ui"),
    ("chime_goal.ogg", make_goal, RATE, "3", "ui"),
    ("chime_payday.ogg", make_ding, RATE, "3", "ui"),
]
GROUPS = ("all", "music", "ambience", "evening", "ui")


if __name__ == "__main__":
    args = sys.argv[1:]
    only_missing = "--missing" in args
    args = [a for a in args if a != "--missing"]
    which = args[0] if args else "all"
    if which not in GROUPS or len(args) > 1:
        sys.exit("usage: make_audio.py [--missing] [%s]" % "|".join(GROUPS))
    written = []
    for name, maker, rate, quality, group in FILES:
        path = "game/audio/" + name
        if which not in ("all", group) or (only_missing and os.path.exists(path)):
            continue
        write(path, maker(), rate, quality)
        written.append(name)
    print("audio written: " + (", ".join(written) if written else "nothing (every file already exists)"))
