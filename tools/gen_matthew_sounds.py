"""Kullanici istegi (2026-09-23): "ses efekti de ekle matthewin skilleri icin tum" - Matthew'in 3 yetenegi
(Tilki Hucumu/Q, Vahsi Hiz/E, Feda Kalkani/R) arasinda E'nin HIC sesi yoktu (bkz. player.gd _skill_matthew_
haste - hicbir ses cagrisi yok), Q'nun sadece TEK BIR aktivasyon sesi vardi (claw_slash.mp3, fx_matthew_fox_
strike.gd uzerinden) ama yeni dash-vurus-sirasi tasarimindaki (bkz. player.gd _matthew_fox_dash_sequence)
HER BIR isabette hic ses yoktu. Bu script:
  - matthew_haste.wav: E (Vahsi Hiz) aktivasyonu icin parlak, yukselen bir "hiz artisi" whoosh'u.
  - matthew_fox_impact.wav: Q'nun HER dash isabeti icin cok kisa/darbeli bir "vurus" sesi (claw_slash.mp3
    tek seferlik aktivasyonda kalmaya devam ediyor, bu YENI ses hizli art arda tekrarlanabilecek kadar kisa).

Calistir: python tools/gen_matthew_sounds.py
Sonra: Godot --headless --import (yeni .wav.import dosyalarini olusturur).
"""

import os
import wave

import numpy as np

SR = 44100
OUT_AUDIO = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def t_axis(sec):
    return np.linspace(0, sec, int(SR * sec), endpoint=False)


def env_ad(n, attack, release_pow=2.2):
    e = np.ones(n)
    a = max(1, int(SR * attack))
    e[:a] = np.linspace(0, 1, a)
    tail = np.linspace(1, 0, n - a) ** release_pow
    e[a:] = tail
    return e


def lowpass(x, cutoff_hz):
    rc = 1.0 / (2 * np.pi * cutoff_hz)
    a = (1.0 / SR) / (rc + 1.0 / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def add_reverb(x, mix=0.25):
    out = x.copy()
    for delay_ms, gain in ((37, 0.45), (61, 0.35), (97, 0.25), (143, 0.15)):
        d = int(SR * delay_ms / 1000.0)
        pad = np.zeros(d)
        out += mix * gain * np.concatenate([pad, x])[: len(x)]
    return out


def save_wav(name, x, gain=0.9):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    f = int(SR * 0.005)
    x[-f:] *= np.linspace(1, 0, f)
    data = (x * 32767).astype(np.int16)
    os.makedirs(OUT_AUDIO, exist_ok=True)
    path = os.path.join(OUT_AUDIO, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", path)


def snd_matthew_haste():
    # Vahsi Hiz (E) aktivasyonu: parlak, hizla yukselen bir "hiz kazanma" whoosh'u -
    # filtrelenmis gurultu (yuksek frekansa dogru acilan) + yukselen ince bir sweep tonu.
    sec = 0.45
    n = int(SR * sec)
    t = t_axis(sec)
    noise = np.random.RandomState(11).randn(n)
    bright = noise - lowpass(noise, 1200.0)
    open_env = np.clip(t / sec, 0.0, 1.0) ** 0.6
    whoosh = bright * open_env * env_ad(n, 0.03, 1.4) * 0.7
    f = 500.0 * (1 + 3.2 * (t / sec) ** 1.3)
    sweep = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(n, 0.02, 1.6) * 0.5
    pop_t = t_axis(0.1)
    pop = np.sin(2 * np.pi * 900 * pop_t) * np.exp(-pop_t * 26) * 0.4
    out = whoosh + sweep
    out[-len(pop):] += pop
    save_wav("matthew_haste.wav", add_reverb(out, 0.18))


def snd_matthew_fox_impact():
    # Q'nun her dash isabeti icin cok kisa (~0.11sn) darbeli "vurus" sesi - dusuk bir
    # "thump" (kisa sine patlamasi) + parlak bir "crack" (filtrelenmis gurultu transienti).
    sec = 0.11
    n = int(SR * sec)
    t = t_axis(sec)
    thump = np.sin(2 * np.pi * 140.0 * t) * env_ad(n, 0.002, 3.2) * 0.75
    noise = np.random.RandomState(23).randn(n)
    crack = (noise - lowpass(noise, 3000.0)) * env_ad(n, 0.001, 4.5) * 0.55
    out = thump + crack
    save_wav("matthew_fox_impact.wav", out, gain=0.85)


def make_sounds():
    snd_matthew_haste()
    snd_matthew_fox_impact()


if __name__ == "__main__":
    make_sounds()
