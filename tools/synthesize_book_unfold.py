"""Original cartoon paper gesture; no recordings or previous cues are inputs.

Requires numpy. Rebuild: python tools/synthesize_book_unfold.py
The legacy asset name is retained for all existing Paper/Postcard callers.
"""
from pathlib import Path
import hashlib
import json
import wave

import numpy as np


RATE = 44100
DURATION = 0.52


def bandpass(source, frequency, q):
    """Continuous resonator sweep, with no discontinuities between blocks."""
    result = np.zeros_like(source)
    x1 = x2 = y1 = y2 = 0.0
    for i, value in enumerate(source):
        omega = 2 * np.pi * frequency[i] / RATE
        alpha = np.sin(omega) / (2 * q)
        a0 = 1 + alpha
        b0 = alpha / a0
        a1 = -2 * np.cos(omega) / a0
        a2 = (1 - alpha) / a0
        y = b0 * (value - x2) - a1 * y1 - a2 * y2
        result[i] = y
        x2, x1, y2, y1 = x1, value, y1, y
    return result


def gesture(t, start, length):
    p = np.clip((t - start) / length, 0, 1)
    return np.sin(np.pi * p) ** 1.8


def soften(source, cutoff=1800):
    """Two-pole Butterworth low-pass for a rounded, dull paper edge."""
    omega = 2 * np.pi * cutoff / RATE
    cosine = np.cos(omega)
    alpha = np.sin(omega) / np.sqrt(2)
    a0 = 1 + alpha
    b0 = (1 - cosine) / (2 * a0)
    a1, a2 = -2 * cosine / a0, (1 - alpha) / a0
    result = np.zeros_like(source)
    x1 = x2 = y1 = y2 = 0.0
    for i, value in enumerate(source):
        y = b0 * (value + 2 * x1 + x2) - a1 * y1 - a2 * y2
        result[i] = y
        x2, x1, y2, y1 = x1, value, y1, y
    return result


def render():
    rng = np.random.default_rng(230923)
    t = np.arange(round(RATE * DURATION)) / RATE
    # A broad, soft paper sweep follows the middle of the sine-eased opening.
    sweep = np.sin(np.pi * np.clip(t / .50, 0, 1))
    paper = bandpass(rng.normal(size=len(t)), 720 + 650 * sweep, .80)
    # Two overlapping bends suggest a page flexing, without recorded crinkles.
    folds = .86 * gesture(t, .012, .275) + .52 * gesture(t, .205, .255)
    flutter = 1 + .13 * np.sin(2 * np.pi * (9 * t + 12 * t * t))
    paper *= folds * flutter
    # A noise-excited, round formant adds cartoon elasticity, not a musical note.
    body = bandpass(rng.normal(size=len(t)), 320 + 330 * sweep, 1.5)
    lift = gesture(t, .030, .275)
    rebound = gesture(t, .245, .205)
    body *= .90 * lift + .55 * rebound
    # A soft, low rubbery bend follows the page; no separate boing at the end.
    # One buoyant lift and a smaller, faster rebound, both inside the opening.
    frequency = 235 + 205 * lift + 120 * rebound
    phase = np.cumsum(frequency) * (2 * np.pi / RATE)
    elastic = np.sin(phase) * (.88 * lift + .48 * rebound)
    sound = soften(.45 * paper + .55 * body + .070 * elastic)
    # Silence at both boundaries; no closing hit, pop, or reverb tail.
    sound *= np.minimum(t / .040, 1) * np.clip((.505 - t) / .07, 0, 1)
    sound -= np.mean(sound)
    sound *= np.minimum(t / .005, 1) * np.clip((DURATION - t - 1 / RATE) / .005, 0, 1)
    sound *= 10 ** (-26 / 20) / np.sqrt(np.mean(sound * sound))
    assert np.max(np.abs(sound)) < .9
    return np.round(sound * 32767).astype('<i2')


if __name__ == '__main__':
    target = Path(__file__).resolve().parents[1] / 'resource/audio/sfx/home-paper-h08c.wav'
    pcm = render()
    with wave.open(str(target), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    samples = pcm.astype(float) / 32768
    print(json.dumps(dict(duration=len(pcm) / RATE,
                         rms_db=20 * np.log10(np.sqrt(np.mean(samples ** 2))),
                         peak_db=20 * np.log10(np.max(np.abs(samples))),
                         boundary_samples=[int(pcm[0]), int(pcm[-1])],
                         sha256=hashlib.sha256(target.read_bytes()).hexdigest())))
