#!/usr/bin/env python3
"""Synthesize the app's sound effects (correct, wrong, combo, complete, evolve).

Every sound is made here from sine partials, so there is no third-party audio to license.
The WAV files go into Assets.xcassets/Sounds/<name>.dataset and the app loads them with NSDataAsset.

    python3 tools/GenerateSounds.py
"""
import json
import math
import struct
import wave
from pathlib import Path

RATE = 22_050
ROOT = Path(__file__).resolve().parent.parent / "Assets.xcassets" / "Sounds"


def hz(note: str) -> float:
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3,
             "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    name, octave = note[:-1], int(note[-1])
    return 440.0 * 2 ** ((names[name] + (octave - 4) * 12) / 12)


def silence(seconds: float) -> list[float]:
    return [0.0] * int(RATE * seconds)


def tone(note: str | float, seconds: float, *, partials=((1, 1.0), (2, 0.35), (3, 0.12)),
         decay=6.0, attack=0.006, glide_to: float | None = None, vibrato=0.0) -> list[float]:
    """A bell-like tone: harmonics with an exponential decay and a click-free attack."""
    start = hz(note) if isinstance(note, str) else note
    count = int(RATE * seconds)
    out = []
    phase = [0.0] * len(partials)
    for i in range(count):
        t = i / RATE
        progress = i / max(1, count - 1)
        base = start if glide_to is None else start * (glide_to / start) ** progress
        if vibrato:
            base *= 1 + vibrato * math.sin(2 * math.pi * 6 * t)
        env = min(1.0, t / attack) * math.exp(-decay * t)
        # A short release so a note never ends on a click.
        env *= min(1.0, (count - i) / (RATE * 0.01))
        sample = 0.0
        for k, (mult, amp) in enumerate(partials):
            freq = base * mult
            if freq >= RATE / 2 * 0.9:
                continue
            phase[k] += 2 * math.pi * freq / RATE
            sample += amp * math.sin(phase[k])
        out.append(sample * env)
    return out


def mix(*tracks: tuple[float, list[float]]) -> list[float]:
    """Each track is (start seconds, samples)."""
    length = max(int(start * RATE) + len(samples) for start, samples in tracks)
    out = [0.0] * length
    for start, samples in tracks:
        offset = int(start * RATE)
        for i, value in enumerate(samples):
            out[offset + i] += value
    return out


def sparkle(start: float, notes: list[str], step: float, length=0.35) -> list[tuple[float, list[float]]]:
    bright = ((1, 1.0), (2.76, 0.25), (5.4, 0.08))  # glockenspiel-like inharmonic partials
    return [(start + i * step, [v * 0.45 for v in tone(n, length, partials=bright, decay=9)])
            for i, n in enumerate(notes)]


def normalize(samples: list[float], peak: float) -> list[float]:
    top = max(abs(v) for v in samples) or 1
    return [v / top * peak for v in samples]


def write(name: str, samples: list[float], peak=0.7) -> None:
    folder = ROOT / f"{name}.dataset"
    folder.mkdir(parents=True, exist_ok=True)
    data = normalize(samples, peak)
    with wave.open(str(folder / f"{name}.wav"), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32_767)) for v in data))
    contents = {"data": [{"filename": f"{name}.wav", "idiom": "universal", "universal-type-identifier": "com.microsoft.waveform-audio"}],
                "info": {"author": "xcode", "version": 1}}
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    (ROOT / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")

    # Correct: two bright rising notes.
    write("sfx-correct", mix((0, tone("E6", 0.18, decay=14)), (0.08, tone("B6", 0.32, decay=9))))

    # Wrong: a soft, low two-step down. Quiet on purpose: a miss is not a punishment.
    soft = ((1, 1.0), (2, 0.15))
    write("sfx-wrong", mix((0, tone("A3", 0.16, partials=soft, decay=10)),
                           (0.12, tone("E3", 0.3, partials=soft, decay=8))), peak=0.45)

    # Combos: longer and higher arpeggios for 3, 5 and 10 in a row.
    arps = {"sfx-combo3": ["C6", "E6", "G6"],
            "sfx-combo5": ["C6", "E6", "G6", "C7"],
            "sfx-combo10": ["G5", "C6", "E6", "G6", "C7", "E7"]}
    for name, notes in arps.items():
        step = 0.065
        tracks = [(i * step, tone(n, 0.3, decay=10)) for i, n in enumerate(notes)]
        tail = len(notes) * step
        tracks.append((tail, tone(notes[-1], 0.6, decay=4.5, vibrato=0.004)))
        if name == "sfx-combo10":
            tracks += sparkle(tail + 0.05, ["E7", "G7", "C8", "G7", "C8"], 0.06)
        write(name, mix(*tracks))

    # Complete: a short fanfare that lands on a chord.
    fanfare = [(0.0, "C5"), (0.12, "E5"), (0.24, "G5")]
    tracks = [(t, tone(n, 0.25, decay=8)) for t, n in fanfare]
    for n in ["C5", "E5", "G5", "C6"]:
        tracks.append((0.4, [v * 0.6 for v in tone(n, 1.1, decay=3, vibrato=0.003)]))
    tracks += sparkle(0.45, ["G6", "C7", "E7"], 0.08)
    write("sfx-complete", mix(*tracks))

    # Evolve: a rising shimmer, a pause of held breath, then a big bright chord.
    sweep = [v * 0.5 for v in tone(220.0, 1.3, partials=((1, 1.0), (2, 0.5), (3, 0.25)), decay=0.3,
                                    attack=0.4, glide_to=1_320.0, vibrato=0.01)]
    tracks = [(0.0, sweep)]
    tracks += sparkle(0.2, ["C6", "E6", "G6", "C7", "E7", "G7", "C8"], 0.14, length=0.25)
    tracks.append((1.3, silence(0.15)))
    for n in ["C5", "G5", "C6", "E6", "G6"]:
        tracks.append((1.45, [v * 0.55 for v in tone(n, 1.4, decay=2.2, vibrato=0.004)]))
    tracks += sparkle(1.5, ["C7", "E7", "G7", "C8", "G7", "C8"], 0.07)
    write("sfx-evolve", mix(*tracks), peak=0.8)

    print("wrote", ", ".join(sorted(p.stem for p in ROOT.glob("*.dataset"))))


if __name__ == "__main__":
    main()
