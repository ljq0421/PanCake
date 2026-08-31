#!/usr/bin/env python3
"""Generate Project Cake's original, deterministic kitchen audio pack."""

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
GENERATOR_VERSION = "project-cake-kitchen-audio-v4"
GENERATED_ON = "2026-08-31"
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
    "morning_ambience": {
        "seed": 1201,
        "duration": 6.00,
        "description": "Seamless restrained breakfast-street bed: distant traffic air, room tone, and sparse birds.",
        "trigger": "Loops while the live workstation scene is open.",
    },
    "customer_arrive": {
        "seed": 1202,
        "duration": 0.64,
        "description": "Soft entrance step and a short two-tone counter chime.",
        "trigger": "A new customer order enters an active service slot.",
    },
    "patience_warning": {
        "seed": 1203,
        "duration": 0.54,
        "description": "Two dry counter taps with a muted warning tone; informative rather than alarming.",
        "trigger": "An order crosses the critical patience threshold for the first time.",
    },
    "payment_collect": {
        "seed": 1204,
        "duration": 0.76,
        "description": "Several small coins gathered from the counter with a restrained bright finish.",
        "trigger": "Pending customer payment is successfully collected.",
    },
    "youtiao_load": {
        "seed": 1205,
        "duration": 0.48,
        "description": "Soft dough pieces landing in a wire fryer basket.",
        "trigger": "Youtiao dough is successfully loaded into the fryer.",
    },
    "fryer_start": {
        "seed": 1206,
        "duration": 0.92,
        "description": "Fryer basket entering hot oil with a fast rising burst of bubbles.",
        "trigger": "A loaded fryer lane successfully starts cooking.",
    },
    "fryer_ready": {
        "seed": 1207,
        "duration": 0.72,
        "description": "Wire basket lift, oil drip, and a small readiness ping.",
        "trigger": "A ready fryer basket is successfully lifted or stored.",
    },
    "soy_cup_place": {
        "seed": 1208,
        "duration": 0.38,
        "description": "Paper cup lifted from its stack and placed beneath a nozzle.",
        "trigger": "An empty soy-milk cup is successfully placed.",
    },
    "soy_dispense": {
        "seed": 1209,
        "duration": 0.86,
        "description": "Warm soy milk flowing into a paper cup with a soft machine hum.",
        "trigger": "A manual or automatic soy-milk dispense begins.",
    },
    "soy_ready": {
        "seed": 1210,
        "duration": 0.52,
        "description": "Liquid flow stops, cup settles, and the machine gives a gentle ready click.",
        "trigger": "A soy-milk fill completes successfully.",
    },
    "drink_restock": {
        "seed": 1211,
        "duration": 0.50,
        "description": "A packaged juice carton placed firmly into its display tray.",
        "trigger": "At least one packaged drink restock unit completes.",
    },
    "drink_pickup": {
        "seed": 1212,
        "duration": 0.42,
        "description": "A carton slides free of the display tray with a light paper rustle.",
        "trigger": "A stocked packaged drink begins a delivery drag.",
    },
    "night_grill_place": {
        "seed": 1301,
        "duration": 0.58,
        "description": "Bamboo skewer settling on an iron rack with an immediate grease hiss.",
        "trigger": "A grill item is successfully placed over charcoal.",
    },
    "night_grill_sizzle": {
        "seed": 1302,
        "duration": 2.40,
        "description": "Seamless charcoal-grill bed with fat crackles and restrained ember texture.",
        "trigger": "Loops while at least one skewer remains on the grill.",
    },
    "night_grill_flip": {
        "seed": 1303,
        "duration": 0.44,
        "description": "A short bamboo-skewer turn with two light iron-rack contacts.",
        "trigger": "A grill slot is successfully flipped.",
    },
    "night_grill_lift": {
        "seed": 1304,
        "duration": 0.54,
        "description": "Skewer scraping free of the rack and landing on a ceramic plate.",
        "trigger": "A cooked grill item is successfully moved to the shared plate.",
    },
    "night_fryer_lower": {
        "seed": 1305,
        "duration": 0.92,
        "description": "Night-stall fryer basket entering hot oil with a fast bubble bloom.",
        "trigger": "A loaded night-market basket is successfully lowered into oil.",
    },
    "night_fryer_bubbles": {
        "seed": 1306,
        "duration": 2.40,
        "description": "Seamless active-oil bubble bed with denser high-frequency droplets.",
        "trigger": "Loops while the night-market fryer basket is cooking.",
    },
    "night_fryer_lift": {
        "seed": 1307,
        "duration": 0.72,
        "description": "Wire basket lift followed by a short trail of oil drips.",
        "trigger": "The night-market fryer basket is successfully raised to drain.",
    },
    "night_season": {
        "seed": 1308,
        "duration": 0.48,
        "description": "Dry seasoning shaken across a plated skewer in three restrained passes.",
        "trigger": "A plated night-market item is successfully seasoned.",
    },
    "night_ready_cue": {
        "seed": 1310,
        "duration": 0.46,
        "description": "Two bright bamboo-and-brass ticks marking a night-market best-action window.",
        "trigger": "Plays once when grill, fryer, or draining food first enters its best-action window.",
    },
    "night_overcook_warning": {
        "seed": 1309,
        "duration": 0.62,
        "description": "Dry char crackle and two low rack knocks signalling food has crossed into overcooked state.",
        "trigger": "Plays once when active grill or fryer food first becomes overcooked.",
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


def _morning_ambience(spec: dict) -> list[float]:
    rng = random.Random(spec["seed"])
    count = round(spec["duration"] * MIX_RATE)
    duration = spec["duration"]
    air_components = [
        (rng.randint(330, 8_400), rng.uniform(0.0, TAU), rng.uniform(0.55, 1.0))
        for _ in range(48)
    ]
    hum_bins = ((6, 0.020), (11, 0.012), (19, 0.007), (31, 0.004))
    bird_events = ((0.82, 1850.0), (2.73, 2210.0), (4.92, 1710.0))
    output = [0.0] * count
    for index in range(count):
        t = index / MIX_RATE
        sample = 0.0
        for cycles, phase, strength in air_components:
            sample += 0.0022 * strength * math.sin(TAU * (cycles / duration) * t + phase)
        for cycles, strength in hum_bins:
            sample += strength * math.sin(TAU * (cycles / duration) * t)
        for start, frequency in bird_events:
            local = t - start
            if 0.0 <= local < 0.20:
                env = math.sin(math.pi * local / 0.20) ** 2
                chirp = frequency + 480.0 * local / 0.20
                sample += 0.018 * env * math.sin(TAU * chirp * local)
        output[index] = sample
    return _soft_limit(output, 0.34)


def _impact_cue(
    spec: dict,
    hits: tuple[tuple[float, float, float, float], ...],
    noise_windows: tuple[tuple[float, float, float, float], ...] = (),
    notes: tuple[tuple[float, float, float], ...] = (),
    peak: float = 0.70,
) -> list[float]:
    rng = random.Random(spec["seed"])
    count = round(spec["duration"] * MIX_RATE)
    low_noise = _lowpass(_noise(count, rng), 900.0)
    paper_noise = _bandpass(_noise(count, rng), 350.0, 5_600.0)
    output = [0.0] * count
    for index in range(count):
        t = index / MIX_RATE
        sample = 0.0
        for start, frequency, strength, decay_rate in hits:
            local = t - start
            if 0.0 <= local < 0.24:
                decay = math.exp(-local * decay_rate)
                sample += strength * math.sin(TAU * frequency * local) * decay
                sample += strength * 0.42 * low_noise[index] * decay
        for start, length, strength, pulse_hz in noise_windows:
            env = _envelope(t, start, length, 0.012, min(0.10, length * 0.35))
            sample += strength * paper_noise[index] * env * (0.82 + 0.18 * math.sin(TAU * pulse_hz * t))
        for start, frequency, strength in notes:
            local = t - start
            if 0.0 <= local < 0.28:
                env = (1.0 - math.exp(-local * 100.0)) * math.exp(-local * 11.0)
                sample += strength * env * (
                    math.sin(TAU * frequency * local) + 0.24 * math.sin(TAU * frequency * 2.0 * local)
                )
        output[index] = sample
    return _soft_limit(output, peak)


def _customer_arrive(spec: dict) -> list[float]:
    return _impact_cue(spec, ((0.04, 92.0, 0.30, 24.0), (0.18, 112.0, 0.22, 28.0)), ((0.01, 0.28, 0.13, 6.0),), ((0.28, 659.25, 0.12), (0.40, 783.99, 0.10)), 0.66)


def _patience_warning(spec: dict) -> list[float]:
    return _impact_cue(spec, ((0.05, 178.0, 0.52, 34.0), (0.24, 166.0, 0.45, 36.0)), notes=((0.09, 392.0, 0.055), (0.28, 349.23, 0.050)), peak=0.64)


def _payment_collect(spec: dict) -> list[float]:
    return _impact_cue(spec, ((0.04, 1180.0, 0.22, 42.0), (0.13, 1470.0, 0.20, 44.0), (0.22, 980.0, 0.24, 40.0), (0.31, 1620.0, 0.18, 46.0)), ((0.02, 0.38, 0.10, 13.0),), ((0.40, 783.99, 0.08), (0.52, 1046.50, 0.07)), 0.72)


def _youtiao_load(spec: dict) -> list[float]:
    return _impact_cue(spec, ((0.07, 84.0, 0.52, 25.0), (0.17, 73.0, 0.42, 27.0), (0.29, 620.0, 0.16, 38.0)), ((0.04, 0.33, 0.18, 10.0),), peak=0.70)


def _fryer_start(spec: dict) -> list[float]:
    rng = random.Random(spec["seed"])
    count = round(spec["duration"] * MIX_RATE)
    oil = _bandpass(_noise(count, rng), 950.0, 8_500.0)
    basket = _bandpass(_noise(count, rng), 280.0, 3_400.0)
    output = [0.0] * count
    for index in range(count):
        t = index / MIX_RATE
        plunge = _envelope(t, 0.02, 0.30, 0.02, 0.12)
        bubbles = _envelope(t, 0.10, 0.80, 0.10, 0.18)
        rise = min(max((t - 0.08) / 0.22, 0.0), 1.0)
        output[index] = 0.26 * basket[index] * plunge + 0.38 * oil[index] * bubbles * (0.45 + 0.55 * rise)
    return _soft_limit(output, 0.72)


def _fryer_ready(spec: dict) -> list[float]:
    return _impact_cue(spec, ((0.04, 510.0, 0.28, 35.0), (0.16, 770.0, 0.19, 42.0), (0.32, 118.0, 0.18, 30.0)), ((0.02, 0.32, 0.15, 12.0),), ((0.38, 880.0, 0.09),), 0.68)


def _soy_cup_place(spec: dict) -> list[float]:
    return _impact_cue(spec, ((0.05, 146.0, 0.34, 31.0), (0.22, 224.0, 0.28, 39.0)), ((0.02, 0.26, 0.12, 9.0),), peak=0.58)


def _soy_dispense(spec: dict) -> list[float]:
    rng = random.Random(spec["seed"])
    count = round(spec["duration"] * MIX_RATE)
    liquid = _bandpass(_noise(count, rng), 180.0, 3_300.0)
    machine = _lowpass(_noise(count, rng), 380.0)
    output = [0.0] * count
    for index in range(count):
        t = index / MIX_RATE
        env = _envelope(t, 0.0, spec["duration"], 0.05, 0.12)
        stream_pulse = 0.78 + 0.14 * math.sin(TAU * 11.0 * t) + 0.08 * math.sin(TAU * 23.0 * t)
        hum = math.sin(TAU * 96.0 * t) + 0.24 * math.sin(TAU * 192.0 * t)
        output[index] = env * (0.34 * liquid[index] * stream_pulse + 0.08 * machine[index] + 0.045 * hum)
    return _soft_limit(output, 0.64)


def _soy_ready(spec: dict) -> list[float]:
    return _impact_cue(spec, ((0.04, 104.0, 0.24, 28.0), (0.18, 238.0, 0.32, 38.0)), ((0.01, 0.17, 0.13, 7.0),), ((0.27, 698.46, 0.075),), 0.60)


def _drink_restock(spec: dict) -> list[float]:
    return _impact_cue(spec, ((0.08, 126.0, 0.40, 30.0), (0.26, 154.0, 0.34, 34.0)), ((0.02, 0.38, 0.22, 8.0),), peak=0.64)


def _drink_pickup(spec: dict) -> list[float]:
    return _impact_cue(spec, ((0.24, 188.0, 0.26, 36.0),), ((0.01, 0.34, 0.28, 12.0),), peak=0.58)


def _night_grill_place(spec: dict) -> list[float]:
    return _impact_cue(
        spec,
        ((0.04, 520.0, 0.22, 40.0), (0.16, 690.0, 0.16, 44.0), (0.28, 104.0, 0.30, 28.0)),
        ((0.10, 0.42, 0.24, 16.0),),
        peak=0.68,
    )


def _night_grill_flip(spec: dict) -> list[float]:
    return _impact_cue(
        spec,
        ((0.04, 760.0, 0.25, 46.0), (0.17, 540.0, 0.23, 43.0), (0.27, 126.0, 0.16, 32.0)),
        ((0.02, 0.30, 0.10, 13.0),),
        peak=0.62,
    )


def _night_grill_lift(spec: dict) -> list[float]:
    return _impact_cue(
        spec,
        ((0.05, 610.0, 0.20, 42.0), (0.30, 172.0, 0.40, 31.0), (0.36, 890.0, 0.13, 48.0)),
        ((0.02, 0.28, 0.16, 11.0),),
        peak=0.66,
    )


def _night_fryer_lift(spec: dict) -> list[float]:
    return _impact_cue(
        spec,
        ((0.04, 480.0, 0.25, 36.0), (0.15, 720.0, 0.18, 42.0), (0.40, 116.0, 0.15, 30.0)),
        ((0.02, 0.52, 0.18, 14.0),),
        peak=0.66,
    )


def _night_season(spec: dict) -> list[float]:
    return _impact_cue(
        spec,
        ((0.05, 820.0, 0.10, 45.0), (0.18, 910.0, 0.09, 47.0), (0.31, 760.0, 0.08, 44.0)),
        ((0.02, 0.40, 0.28, 18.0),),
        peak=0.54,
    )


def _night_ready_cue(spec: dict) -> list[float]:
    return _impact_cue(
        spec,
        ((0.04, 880.0, 0.22, 52.0), (0.18, 1_175.0, 0.25, 50.0), (0.31, 196.0, 0.10, 36.0)),
        ((0.02, 0.34, 0.08, 18.0),),
        peak=0.58,
    )


def _night_overcook_warning(spec: dict) -> list[float]:
    rng = random.Random(spec["seed"])
    count = round(spec["duration"] * MIX_RATE)
    char = _bandpass(_noise(count, rng), 1_400.0, 7_800.0)
    body = _lowpass(_noise(count, rng), 720.0)
    output = [0.0] * count
    for index in range(count):
        t = index / MIX_RATE
        sample = 0.30 * char[index] * _envelope(t, 0.0, 0.50, 0.01, 0.14)
        for start, frequency, strength in ((0.12, 138.0, 0.48), (0.36, 126.0, 0.42)):
            local = t - start
            if 0.0 <= local < 0.20:
                decay = math.exp(-local * 34.0)
                sample += strength * 0.25 * math.sin(TAU * frequency * local) * decay
                sample += strength * 0.12 * body[index] * decay
        output[index] = sample
    return _soft_limit(output, 0.64)


GENERATORS = {
    "batter_drop": _batter_drop,
    "spreader_scrape": _spreader_scrape,
    "cooking_sizzle": _cooking_sizzle,
    "pancake_flip": _pancake_flip,
    "sauce_brush": _sauce_brush,
    "pancake_fold": _pancake_fold,
    "order_serve": _order_serve,
    "morning_ambience": _morning_ambience,
    "customer_arrive": _customer_arrive,
    "patience_warning": _patience_warning,
    "payment_collect": _payment_collect,
    "youtiao_load": _youtiao_load,
    "fryer_start": _fryer_start,
    "fryer_ready": _fryer_ready,
    "soy_cup_place": _soy_cup_place,
    "soy_dispense": _soy_dispense,
    "soy_ready": _soy_ready,
    "drink_restock": _drink_restock,
    "drink_pickup": _drink_pickup,
    "night_grill_place": _night_grill_place,
    "night_grill_sizzle": _cooking_sizzle,
    "night_grill_flip": _night_grill_flip,
    "night_grill_lift": _night_grill_lift,
    "night_fryer_lower": _fryer_start,
    "night_fryer_bubbles": _cooking_sizzle,
    "night_fryer_lift": _night_fryer_lift,
    "night_season": _night_season,
    "night_ready_cue": _night_ready_cue,
    "night_overcook_warning": _night_overcook_warning,
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
