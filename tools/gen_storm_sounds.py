"""Saganak havasinin sesleri -> assets/audio/storm/*.wav

Kullanici istegi (2026-09-25): "... yildirim dusmeli ... dusmeden once dusecegi yerde hafif elektriklenme olmali ...
ses efektlerini buna gore tasarlamayi unutma". Yagmur/ruzgar dongusu zaten var (tools/gen_weather_sounds.py) -
saganakta ikisi birlikte calar. Bu script yildirim ailesini uretir:

  charge.wav            (1.3 sn) dusecegi yerde elektriklenme: yukselen alcak vizilti + sikligi artan citirtilar (kisik).
  thunder_strike_1/2    (3.4 sn) yakina dusen yildirim: sert beyaz "CRACK" + hemen ardindan yuvarlanan alcak gurultu.
  thunder_distant_1/2   (4.0 sn) uzaktan gok gurultusu (yildirimsiz sema parlamalarinda): yumusak, dalgali gurultu.

Calistir: python tools/gen_storm_sounds.py
"""

import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "storm")


def n_of(sec):
    return int(SR * sec)


def lp(x, cutoff):
    cut = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), x.shape)
    a = 1.0 - np.exp(-2 * np.pi * cut / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def hp(x, cutoff):
    return x - lp(x, cutoff)


def save(name, x, peak=0.9):
    x = np.asarray(x, dtype=np.float64)
    x = x - np.mean(x)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    f = n_of(0.01)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print("wrote", os.path.normpath(path), "%.2fs" % (len(x) / SR))


def charge(rng):
    sec = 1.3
    n = n_of(sec)
    t = np.arange(n) / SR
    rise = (t / sec) ** 1.5
    f = 70 + 60 * rise
    ph = 2 * np.pi * np.cumsum(f) / SR
    buzz = (2 * ((ph / (2 * np.pi)) % 1.0) - 1) * 0.5 + np.sin(ph * 2) * 0.3
    buzz = lp(buzz, 900) * (0.15 + 0.6 * rise)
    # citirtilar: sikligi zamanla artan kisa, tiz tiklar
    crackle = np.zeros(n)
    k = 0
    while k < n:
        k += int(SR * rng.uniform(0.012, 0.09) * (1.2 - rise[min(k, n - 1)]))
        if k >= n:
            break
        ln = rng.integers(40, 160)
        seg = rng.standard_normal(ln) * np.exp(-np.arange(ln) / 25.0)
        crackle[k:k + ln] += seg[: max(0, min(ln, n - k))] * rng.uniform(0.3, 1.0)
    crackle = hp(crackle, 2500)
    env = np.minimum(1.0, t / 0.25) * np.minimum(1.0, (sec - t) / 0.05)
    return (buzz + crackle * 0.35) * env


def thunder_strike(rng):
    sec = 3.4
    n = n_of(sec)
    t = np.arange(n) / SR
    # 1) CRACK: sert beyaz gurultu patlamasi, cok kisa
    crack = rng.standard_normal(n) * np.exp(-t / 0.045)
    crack = hp(crack, 600) * 1.0 + lp(crack, 2500) * 0.6
    # birkac ikincil citirti (yildirimin dallari)
    for _ in range(4):
        st = n_of(rng.uniform(0.02, 0.18))
        ln = n_of(0.03)
        crack[st:st + ln] += rng.standard_normal(ln) * np.exp(-np.arange(ln) / (SR * 0.01)) * 0.6
    # 2) RUMBLE: alcak, dalgalanan, yavas sonen gurultu
    rumble = lp(lp(rng.standard_normal(n), 180), 120)
    wob = 0.6 + 0.4 * np.sin(2 * np.pi * rng.uniform(1.5, 3.0) * t + rng.uniform(0, 6))
    renv = np.minimum(1.0, t / 0.08) * np.exp(-t / 1.1)
    rumble = rumble * wob * renv
    rumble = rumble / (np.max(np.abs(rumble)) or 1.0)
    return crack * 0.8 + rumble * 1.0


def thunder_distant(rng):
    sec = 4.0
    n = n_of(sec)
    t = np.arange(n) / SR
    rumble = lp(lp(rng.standard_normal(n), 140), 90)
    wob = 0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(0.8, 1.6) * t + rng.uniform(0, 6)) ** 2
    env = np.minimum(1.0, t / 0.6) * np.exp(-np.maximum(0.0, t - 0.6) / 1.3)
    return rumble * wob * env


if __name__ == "__main__":
    rng = np.random.default_rng(2026)
    save("charge.wav", charge(rng), 0.7)
    save("thunder_strike_1.wav", thunder_strike(np.random.default_rng(11)))
    save("thunder_strike_2.wav", thunder_strike(np.random.default_rng(12)))
    save("thunder_distant_1.wav", thunder_distant(np.random.default_rng(21)), 0.8)
    save("thunder_distant_2.wav", thunder_distant(np.random.default_rng(22)), 0.8)
