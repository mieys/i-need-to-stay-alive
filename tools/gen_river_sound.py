"""Kullanici istegi (2026-09-27): "oyunda nehire yaklasinca nehir su akintisi sesi eklemeni istiyorum". Projede/ses
paketinde nehir akintisi yoktu (Sound FX Starter Pack'teki "Ocean Loop" dalga sesi, nehre uymuyor) - bu script tek bir
DONGU uretir (gen_weather_sounds.py ile ayni dikissiz yontem: tum filtreler frekans uzayinda, dairesel):

  - river_flow_loop.wav : suyun hisirtili akis yatagi (orta-tiz bant, yavasca dalgalanan) + alcak akis ugultusu +
                          sik, kucuk "gurul" kabarciklari (perdesi hafifce yukselen, hizla sonen sinusler) + seyrek
                          daha iri su sesleri.

Calistir: python tools/gen_river_sound.py   (sonra Godot --headless --import)
Oyunda: scripts/river_ambience.gd (nehre en yakin noktaya konan AudioStreamPlayer2D).
"""

import os
import wave

import numpy as np

SR = 22050
OUT_AUDIO = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
RNG = np.random.default_rng(20260927)


def shaped_noise(n, gain_fn):
    spec = np.fft.rfft(RNG.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = 1e-3
    out = np.fft.irfft(spec * gain_fn(f), n)
    return out / (np.sqrt(np.mean(out ** 2)) + 1e-12)


def lfo(n, cycles, phase=0.0):
    t = np.arange(n) / n
    return np.sin(2 * np.pi * cycles * t + phase)


def add_wrapped(buf, start, grain):
    n = len(buf)
    idx = (start + np.arange(len(grain))) % n
    np.add.at(buf, idx, grain)


def smooth_lowpass(signal, cutoff):
    n = len(signal)
    spec = np.fft.rfft(signal)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    return np.fft.irfft(spec / np.sqrt(1.0 + (f / cutoff) ** 4), n)


def bubble(f0, tau, amp):
    """Kucuk su kabarcigi: perdesi hafifce YUKSELEN (su sesi karakteri), hizla sonen sinus."""
    length = int(SR * tau * 5)
    t = np.arange(length) / SR
    freq = f0 * (1.0 + 0.6 * (1.0 - np.exp(-t / (tau * 0.8))))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    env = (1.0 - np.exp(-t / 0.0015)) * np.exp(-t / tau)
    return np.sin(phase) * env * amp


def river(seconds=14.0):
    n = int(SR * seconds)
    # Akis yatagi: 250 Hz alti ve ~6 kHz ustu kisik, 1-2 kHz civari dolgun hisirti; hafif, yavas dalgalanma.
    bed = shaped_noise(n, lambda f: (f ** 2 / (f ** 2 + 250.0 ** 2)) ** 0.5
                       / np.sqrt(1.0 + (f / 6000.0) ** 2) / (np.maximum(f, 80.0) / 1200.0) ** 0.35)
    swell = 1.0 + 0.10 * lfo(n, 2, 0.7) + 0.06 * lfo(n, 5, 2.3) + 0.04 * lfo(n, 11, 4.1)
    out = bed * 0.16 * swell
    # Alcak ugultu (akan suyun govdesi).
    rumble = shaped_noise(n, lambda f: (f ** 2 / (f ** 2 + 40.0 ** 2)) ** 0.5 / np.sqrt(1.0 + (f / 320.0) ** 4))
    out += rumble * 0.09 * (1.0 + 0.15 * lfo(n, 3, 1.1))
    # Sik kucuk kabarciklar (gurul) - kumeler halinde (su kayalardan akarken).
    for _ in range(int(70 * seconds)):
        start = int(RNG.integers(0, n))
        for k in range(int(RNG.integers(1, 4))):
            g = bubble(RNG.uniform(500.0, 1700.0), RNG.uniform(0.004, 0.012), RNG.uniform(0.02, 0.06))
            add_wrapped(out, start + int(RNG.integers(0, int(SR * 0.03))) * k, g)
    # Seyrek iri su sesleri (plop).
    for _ in range(int(4 * seconds)):
        g = bubble(RNG.uniform(260.0, 520.0), RNG.uniform(0.015, 0.03), RNG.uniform(0.05, 0.1))
        add_wrapped(out, int(RNG.integers(0, n)), g)
    out = smooth_lowpass(out, 6500.0)
    return out / np.max(np.abs(out)) * 0.6


def write_wav(name, data):
    path = os.path.join(OUT_AUDIO, name)
    pcm = np.clip(data * 32767.0, -32768, 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("yazildi:", os.path.normpath(path), f"{len(data) / SR:.1f} sn")


if __name__ == "__main__":
    write_wav("river_flow_loop.wav", river())
