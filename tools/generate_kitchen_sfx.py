#!/usr/bin/env python3
"""Generate Project Cake's original, deterministic P1 kitchen SFX pack."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import struct
import wave
from pathlib import Path


MIX_RATE = 32_000
GENERATOR_VERSION = "project-cake-kitchen-sfx-v1"
GENERATED_ON = "2026-08-02"
TAU = math.tau

CUE_SPECS = {
    "batter_drop": {
        "seed": 1101,
        "duration": 0.72,
        "description": "Thick batter falling onto hot iron: wet body, three soft plops, short pan contact.",
        "trigger": "A successful automatic measured batter pour.",
    },
    "spreader_scrape": {
        "seed": 1102,
        "duration": 0.42,
        "description": "T-spreader dragging through wet batter with a restrained metal-on-iron edge.",
        "trigger": "Accepted distance-sampled batter or egg spreading movement.",
    },
    "cooking_sizzle": {
        "seed": 1103,
        "duration": 2.40,
        "description": "Seamless hot-iron cooking bed with many small moisture crackles.",
        "trigger": "Loops while poured batter is actively cooking; heat and moisture drive level and pitch.",
    },
    "pancake_flip": {
        "seed": 1104,
        "duration": 0.56,
        "description": "Spatula lift, brief pancake whoosh, iron tap, and soft landing.",
        "trigger": "A successful guarded first-side flip.",
    },
    "sauce_brush": {
        "seed": 1105,
        "duration": 0.38,
        "description": "Wet sauce brush dragging across a cooked pancake.",
        "trigger": "A brush sample that actually applies sauce to new cells.",
    },
    "pancake_fold": {
        "seed": 1106,
        "duration": 0.48,
        "description": "Cooked pancake rustle, crease, and soft fold landing.",
        "trigger": "Each successfully committed left or right fold.",
    },
    "order_serve": {
        "seed": 1107,
        "duration": 0.78,
        "description": "Wrapped order slide, counter set-down, and restrained two-note service accent.",
        "trigger": "A valid serve action that opens the customer result.",
    },
}


def _envelope(t: float, start: float, length: float, attack: float = 0.02, release: float = 0.15) -> float:
    local = t - start
    if local < 0.0 or local >= length:
        return 0.0
    attack_gain = min(local / max(attack, 1e-6), 1.0)
    release_gain = min((length - local) / max(release, 1e-6), 1.0)
    return max(0.0, min(attack_gain, release_gain))


def _noise(count: int, rng: random.Random) -> list[float]:
    return [rng.uniform(-1.0, 1.0) for _ in range(count)]


def _lowpass(samples: list[float], cutoff_hz: float) -> list[float]:
    alpha = 1.0 - math.exp(-TAU * cutoff_hz / MIX_RATE)
    state = 0.0
    output: list[float] = []
    for sample in samples:
        state += alpha * (sample - state)
        output.append(state)
    return output


def _highpass(samples: list[float], cutoff_hz: float) -> list[float]:
    low = _lowpass(samples, cutoff_hz)
    return [sample - low_sample for sample, low_sample in zip(samples, low)]


def _bandpass(samples: list[float], low_hz: float, high_hz: float) -> list[float]:
    return _lowpass(_highpass(samples, low_hz), high_hz)


def _soft_limit(samples: list[float], target_peak: float = 0.82) -> list[float]:
    shaped = [math.tanh(sample * 1.25) for sample in samples]
    peak = max((abs(sample) for sample in shaped), default=1.0)
    gain = target_peak / max(peak, 1e-9)
    return [sample * gain for sample in shaped]


def _batter_drop(spec: dict) -> list[float]:
    rng = random.Random(spec["seed"])
    count = round(spec["duration"] * MIX_RATE)
    body_noise = _lowpass(_noise(count, rng), 520.0)
    pan_hiss = _bandpass(_noise(count, rng), 1_800.0, 7_000.0)
    output = [0.0] * count
    for index in range(count):
        t = index / MIX_RATE
        sample = 0.025 * pan_hiss[index] * _envelope(t, 0.08, 0.58, 0.01, 0.20)
        for start, strength, frequency in ((0.08, 0.90, 92.0), (0.20, 0.62, 78.0), (0.31, 0.42, 66.0)):
            local = t - start
            if 0.0 <= local < 0.25:
                decay = math.exp(-local * 18.0)
                pitch_drop = frequency * (1.0 - 0.45 * min(local / 0.20, 1.0))
                sample += strength * 0.34 * math.sin(TAU * pitch_drop * local) * decay
                sample += strength * 0.20 * body_noise[index] * decay
        output[index] = sample
    return _soft_limit(output, 0.80)


def _spreader_scrape(spec: dict) -> list[float]:
    rng = random.Random(spec["seed"])
    count = round(spec["duration"] * MIX_RATE)
    friction = _bandpass(_noise(count, rng), 420.0, 5_200.0)
    edge = _highpass(_noise(count, rng), 2_800.0)
    output = [0.0] * count
    for index in range(count):
        t = index / MIX_RATE
        env = _envelope(t, 0.0, spec["duration"], 0.025, 0.08)
        hand_pulse = 0.72 + 0.18 * math.sin(TAU * 8.0 * t) + 0.10 * math.sin(TAU * 13.0 * t + 0.7)
        metal = math.sin(TAU * (1_180.0 + 90.0 * math.sin(TAU * 2.4 * t)) * t)
        output[index] = env * (0.42 * friction[index] * hand_pulse + 0.07 * edge[index] + 0.025 * metal)
    return _soft_limit(output, 0.68)


def _cooking_sizzle(spec: dict) -> list[float]:
    rng = random.Random(spec["seed"])
    count = round(spec["duration"] * MIX_RATE)
    duration = spec["duration"]
    phases = [rng.uniform(0.0, TAU) for _ in range(18)]
    bins = [rng.randint(70, 620) for _ in phases]
    events = [
        (
            rng.randrange(count),
            rng.uniform(0.25, 1.0),
            rng.uniform(0.0015, 0.007),
            rng.randint(round(2_800.0 * duration), round(6_200.0 * duration)),
            rng.uniform(0.0, TAU),
        )
        for _ in range(190)
    ]
    output = [0.0] * count
    for index in range(count):
        t = index / MIX_RATE
        bed = 0.0
        for bin_index, phase in zip(bins, phases):
            bed += math.sin(TAU * (bin_index / duration) * t + phase)
        sample = 0.0065 * bed
        for center, strength, width_seconds, carrier_bin, carrier_phase in events:
            distance = abs(index - center)
            distance = min(distance, count - distance)
            width = width_seconds * MIX_RATE
            if distance < width * 4.0:
                crackle = math.exp(-0.5 * (distance / max(width, 1.0)) ** 2)
                carrier = math.sin(TAU * (carrier_bin / duration) * t + carrier_phase)
                sample += 0.16 * strength * crackle * carrier
        output[index] = sample
    return _soft_limit(output, 0.56)


def _pancake_flip(spec: dict) -> list[float]:
    rng = random.Random(spec["seed"])
    count = round(spec["duration"] * MIX_RATE)
    air = _bandpass(_noise(count, rng), 300.0, 4_800.0)
    impact_noise = _lowpass(_noise(count, rng), 1_200.0)
    output = [0.0] * count
    for index in range(count):
        t = index / MIX_RATE
        whoosh_env = _envelope(t, 0.015, 0.33, 0.09, 0.10)
        whoosh_shape = 0.45 + 0.55 * math.sin(math.pi * min(max((t - 0.015) / 0.33, 0.0), 1.0))
        sample = 0.34 * air[index] * whoosh_env * whoosh_shape
        for start, strength, frequency in ((0.035, 0.22, 710.0), (0.34, 0.72, 128.0), (0.405, 0.38, 82.0)):
            local = t - start
            if 0.0 <= local < 0.16:
                decay = math.exp(-local * 32.0)
                sample += strength * 0.28 * math.sin(TAU * frequency * local) * decay
                sample += strength * 0.15 * impact_noise[index] * decay
        output[index] = sample
    return _soft_limit(output, 0.78)


def _sauce_brush(spec: dict) -> list[float]:
    rng = random.Random(spec["seed"])
    count = round(spec["duration"] * MIX_RATE)
    wet = _lowpass(_noise(count, rng), 1_100.0)
    bristles = _bandpass(_noise(count, rng), 900.0, 6_500.0)
    output = [0.0] * count
    for index in range(count):
        t = index / MIX_RATE
        env = _envelope(t, 0.0, spec["duration"], 0.018, 0.07)
        stroke = 0.62 + 0.25 * math.sin(TAU * 7.5 * t + 0.4) + 0.13 * math.sin(TAU * 16.0 * t)
        squish = math.sin(TAU * (155.0 - 55.0 * t) * t) * math.exp(-t * 7.0)
        output[index] = env * (0.34 * wet[index] * stroke + 0.18 * bristles[index] + 0.10 * squish)
    return _soft_limit(output, 0.66)


def _pancake_fold(spec: dict) -> list[float]:
    rng = random.Random(spec["seed"])
    count = round(spec["duration"] * MIX_RATE)
    rustle = _bandpass(_noise(count, rng), 250.0, 4_200.0)
    body = _lowpass(_noise(count, rng), 680.0)
    output = [0.0] * count
    for index in range(count):
        t = index / MIX_RATE
        movement = _envelope(t, 0.015, 0.36, 0.035, 0.10)
        sample = 0.30 * rustle[index] * movement * (0.72 + 0.28 * math.sin(TAU * 9.0 * t))
        for start, strength, frequency in ((0.22, 0.38, 360.0), (0.315, 0.78, 96.0)):
            local = t - start
            if 0.0 <= local < 0.16:
                decay = math.exp(-local * 28.0)
                sample += strength * 0.25 * math.sin(TAU * frequency * local) * decay
                sample += strength * 0.12 * body[index] * decay
        output[index] = sample
    return _soft_limit(output, 0.72)


def _order_serve(spec: dict) -> list[float]:
    rng = random.Random(spec["seed"])
    count = round(spec["duration"] * MIX_RATE)
    slide = _bandpass(_noise(count, rng), 180.0, 2_300.0)
    body = _lowpass(_noise(count, rng), 750.0)
    output = [0.0] * count
    for index in range(count):
        t = index / MIX_RATE
        slide_env = _envelope(t, 0.02, 0.32, 0.03, 0.12)
        sample = 0.25 * slide[index] * slide_env
        local = t - 0.30
        if 0.0 <= local < 0.20:
            decay = math.exp(-local * 25.0)
            sample += 0.23 * body[index] * decay + 0.22 * math.sin(TAU * 112.0 * local) * decay
        for start, frequency, strength in ((0.39, 659.25, 0.11), (0.51, 880.0, 0.09)):
            note_t = t - start
            if 0.0 <= note_t < 0.22:
                note_env = (1.0 - math.exp(-note_t * 90.0)) * math.exp(-note_t * 10.0)
                sample += strength * note_env * (
                    math.sin(TAU * frequency * note_t) + 0.30 * math.sin(TAU * frequency * 2.0 * note_t)
                )
        output[index] = sample
    return _soft_limit(output, 0.74)


GENERATORS = {
    "batter_drop": _batter_drop,
    "spreader_scrape": _spreader_scrape,
    "cooking_sizzle": _cooking_sizzle,
    "pancake_flip": _pancake_flip,
    "sauce_brush": _sauce_brush,
    "pancake_fold": _pancake_fold,
    "order_serve": _order_serve,
}


def _wav_bytes(samples: list[float]) -> bytes:
    pcm = bytearray()
    for sample in samples:
        pcm.extend(struct.pack("<h", max(-32768, min(32767, round(sample * 32767.0)))))
    import io

    output = io.BytesIO()
    with wave.open(output, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(MIX_RATE)
        wav_file.writeframes(bytes(pcm))
    return output.getvalue()


def _build_pack() -> tuple[dict[str, bytes], dict]:
    files: dict[str, bytes] = {}
    cues: list[dict] = []
    for cue_name, spec in CUE_SPECS.items():
        filename = f"{cue_name}.wav"
        data = _wav_bytes(GENERATORS[cue_name](spec))
        sha256 = hashlib.sha256(data).hexdigest()
        files[filename] = data
        cues.append(
            {
                "cue": cue_name,
                "file": filename,
                "description": spec["description"],
                "trigger": spec["trigger"],
                "seed": spec["seed"],
                "duration_seconds": spec["duration"],
                "sha256": sha256,
            }
        )
    manifest = {
        "schema_version": 1,
        "generator": GENERATOR_VERSION,
        "generated_on": GENERATED_ON,
        "origin": "Original deterministic procedural synthesis; no third-party recordings, samples, or melodies.",
        "format": {"sample_rate_hz": MIX_RATE, "channels": 1, "sample_width_bits": 16, "encoding": "PCM"},
        "cues": cues,
    }
    return files, manifest


def generate(output_dir: Path) -> None:
    files, manifest = _build_pack()
    output_dir.mkdir(parents=True, exist_ok=True)
    for filename, data in files.items():
        (output_dir / filename).write_bytes(data)
    (output_dir / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(files)} deterministic kitchen SFX in {output_dir}")


def verify(output_dir: Path) -> None:
    expected_files, expected_manifest = _build_pack()
    manifest_path = output_dir / "manifest.json"
    if not manifest_path.is_file():
        raise SystemExit(f"Missing manifest: {manifest_path}")
    actual_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if actual_manifest != expected_manifest:
        raise SystemExit("Manifest does not match the deterministic generator output")
    failures: list[str] = []
    for filename, expected in expected_files.items():
        path = output_dir / filename
        if not path.is_file():
            failures.append(f"missing {filename}")
        elif path.read_bytes() != expected:
            failures.append(f"content mismatch {filename}")
    if failures:
        raise SystemExit("Kitchen SFX verification failed: " + ", ".join(failures))
    print(f"KITCHEN_SFX_REPRODUCIBILITY_PASS ({len(expected_files)} files)")


def main() -> None:
    default_output = Path(__file__).resolve().parents[1] / "resources" / "audio" / "sfx"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=default_output)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    if args.verify:
        verify(args.output.resolve())
    else:
        generate(args.output.resolve())


if __name__ == "__main__":
    main()
