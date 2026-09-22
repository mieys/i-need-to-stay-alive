#!/usr/bin/env python3
"""Oakley Ari Surusu (Q) icin vizildayan ari ses efekti uretir: assets/audio/oakley/oakley_bees.wav

Kullanim (repo kokunden):  python tools/gen_oakley_fx_assets.py
Kisa (~1.8sn) bir vizilti "kumesi": birden cok hafifce detune edilmis testere sesi + kanat cirpisi genlik titresimi + yumusak
giris/cikis. oakley_bee_swarm_ring.gd bunu alan yasadigi surece aralikli tekrar calar (uzun loop yok - bkz. hafiza: bow hum).
Yeni WAV icin Godot'ta bir kez `--headless --import` gerekir.
"""
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "oakley")
SR = 44100


def lowpass(x, cutoff_hz):
    rc = 1.0 / (2 * np.pi * cutoff_hz)
    a = (1.0 / SR) / (rc + 1.0 / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def make_bees():
    sec = 1.8
    n = int(SR * sec)
    t = np.arange(n) / SR
    rs = np.random.RandomState(11)
    mix = np.zeros(n)
    for v in range(7):
        base = rs.uniform(150.0, 240.0)
        vib_f = rs.uniform(2.0, 5.5)
        vib_d = rs.uniform(4.0, 14.0)
        freq = base + vib_d * np.sin(2 * np.pi * vib_f * t + rs.uniform(0, 6.28))
        phase = 2 * np.pi * np.cumsum(freq) / SR
        saw = 2 * ((phase / (2 * np.pi)) % 1.0) - 1.0
        wing = 0.55 + 0.45 * np.abs(np.sin(np.pi * (rs.uniform(28, 46)) * t + rs.uniform(0, 3)))
        drift = 0.6 + 0.4 * np.sin(2 * np.pi * rs.uniform(0.3, 1.1) * t + rs.uniform(0, 6.28))
        mix += saw * wing * drift * rs.uniform(0.6, 1.0)
    noise = rs.randn(n)
    band = lowpass(noise, 3200) - lowpass(noise, 900)
    mix = mix / 7.0 + 0.25 * band
    mix = lowpass(mix, 2600)
    env = np.minimum(1.0, t / 0.25) * np.minimum(1.0, (sec - t) / 0.35)
    out = mix * env
    out = out / (np.max(np.abs(out)) or 1.0) * 0.7
    data = (out * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, "oakley_bees.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


if __name__ == "__main__":
    make_bees()
    print("ok")
