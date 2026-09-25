#!/usr/bin/env python3
"""Ruhani Yetenekler (scripts/spiritual_skills.gd) icin ikon + ses assetlerini uretir.

Kullanim (repo kokunden):
    python tools/gen_spirit_assets.py

1) (ikonlar artik tools/gen_spirit_vampir_icons.py'de)
2) assets/audio/spiritual/*.wav        - kisa, prosedurel (numpy) ses efektleri. Uzun/loop ses YOK (bkz. hafiza:
   bow hum). Yeni PNG/WAV'lar icin Godot'ta bir kez `--headless --import` gerekir.
"""
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_AUDIO = os.path.join(ROOT, "assets", "audio", "spiritual")

# ---------------------------------------------------------------- ikonlar
# 2026-09-25: ruhani ikonlar tools/gen_spirit_vampir_icons.py ile yeniden cizildi (kullanici istegi: "tum ruhani buyulerin
# ikonlarini ... yeniden pixel tarzda 48x48 tasarla"). Eski yuvarlak madalyon ciziminin kodu buradan SILINDI ki bu betik
# tekrar calistirilirsa yeni ikonlarin uzerine yazmasin - bu dosya artik sadece sesleri uretir.


# ------------------------------------------------------------------ sesler
SR = 44100


def t_axis(sec):
    return np.linspace(0, sec, int(SR * sec), endpoint=False)


def env_ad(n, attack, release_pow=2.2):
    """Kisa atak + ustel sonum zarfi."""
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


def save_wav(name, x, gain=0.85):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    f = int(SR * 0.01)
    x[-f:] *= np.linspace(1, 0, f)
    data = (x * 32767).astype(np.int16)
    os.makedirs(OUT_AUDIO, exist_ok=True)
    with wave.open(os.path.join(OUT_AUDIO, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def tone(freq, sec, harmonics=((1, 1.0), (2, 0.3), (3, 0.12))):
    t = t_axis(sec)
    y = np.zeros_like(t)
    for h, g in harmonics:
        y += g * np.sin(2 * np.pi * freq * h * t)
    return y


def snd_can():
    # yukselen 4 notali sifa cani (C5-E5-G5-C6), her nota canli, sonda parilti
    notes = [523.25, 659.25, 783.99, 1046.5]
    total = np.zeros(int(SR * 1.3))
    for i, f in enumerate(notes):
        seg = tone(f, 0.9) * env_ad(int(SR * 0.9), 0.005, 3.0)
        s = int(SR * 0.11 * i)
        total[s:s + len(seg)] += seg * (0.7 + 0.1 * i)
    sparkle_n = np.random.RandomState(1).randn(int(SR * 0.5))
    sparkle_n = (sparkle_n - lowpass(sparkle_n, 3000)) * env_ad(len(sparkle_n), 0.05, 2.0) * 0.05
    total[int(SR * 0.4):int(SR * 0.4) + len(sparkle_n)] += sparkle_n
    save_wav("spirit_can.wav", add_reverb(total, 0.35))


def snd_adc():
    # yukselen "guc" sweep'i + keskin vurus: testere sweep + gurultu
    n = int(SR * 0.75)
    t = t_axis(0.75)
    f = 180 * (1 + 4.5 * (t / 0.75) ** 1.6)
    phase = 2 * np.pi * np.cumsum(f) / SR
    saw = 2 * ((phase / (2 * np.pi)) % 1) - 1
    sq = np.sign(np.sin(phase))
    y = (0.6 * saw + 0.3 * sq) * env_ad(n, 0.02, 1.3)
    noise = np.random.RandomState(2).randn(n)
    noise = (noise - lowpass(noise, 1500)) * env_ad(n, 0.01, 2.0) * 0.4
    hit = tone(90, 0.3) * env_ad(int(SR * 0.3), 0.002, 2.5)
    out = y + noise
    out[:len(hit)] += hit * 1.2
    save_wav("spirit_adc.wav", add_reverb(out, 0.15))


def snd_tank():
    # agir metalik "kalkan" vurusu: dusuk sine + metal inharmonik ust tonlar
    sec = 0.9
    t = t_axis(sec)
    low = np.sin(2 * np.pi * 70 * t * (1 + 0.5 * np.exp(-t * 20))) * np.exp(-t * 6)
    metal = np.zeros_like(t)
    for f, g in ((311, 0.6), (523, 0.5), (846, 0.35), (1290, 0.25), (1811, 0.15)):
        metal += g * np.sin(2 * np.pi * f * t) * np.exp(-t * (5 + f / 400))
    thump = np.random.RandomState(3).randn(len(t))
    thump = lowpass(thump, 400) * np.exp(-t * 30) * 1.5
    save_wav("spirit_tank.wav", add_reverb(low * 1.4 + metal * 0.8 + thump, 0.2))


def snd_tank_reflect():
    sec = 0.3
    t = t_axis(sec)
    y = np.zeros_like(t)
    for f, g in ((880, 0.7), (1320, 0.5), (1975, 0.35), (2960, 0.2)):
        y += g * np.sin(2 * np.pi * f * t) * np.exp(-t * (14 + f / 500))
    y += 0.4 * np.random.RandomState(4).randn(len(t)) * np.exp(-t * 60)
    save_wav("spirit_tank_reflect.wav", y, gain=0.7)


def snd_taktik():
    # hizli "zip": yuksekten alcaga suzulen filtre gurultu + kisa sinus sweep
    sec = 0.42
    n = int(SR * sec)
    t = t_axis(sec)
    noise = np.random.RandomState(5).randn(n)
    bright = noise - lowpass(noise, 2500)
    low = lowpass(noise, 900)
    mix = bright * (1 - t / sec) + low * (t / sec)
    mix *= env_ad(n, 0.02, 1.6)
    f = 1800 * np.exp(-t * 5.5) + 300
    sweep = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(n, 0.005, 2.0) * 0.5
    pop_t = t_axis(0.12)
    pop = np.sin(2 * np.pi * 520 * pop_t) * np.exp(-pop_t * 30) * 0.6
    out = mix * 0.9 + sweep
    out[:len(pop)] += pop
    save_wav("spirit_taktik.wav", out)


def snd_dukkan():
    # 3sn'lik yukselen "odaklanma" parilti: tam olarak kanal suresi kadar; tek atimlik (loop YOK)
    sec = 3.0
    n = int(SR * sec)
    t = t_axis(sec)
    glide = 220 * (1 + 2.2 * (t / sec) ** 1.4)
    ph = 2 * np.pi * np.cumsum(glide) / SR
    base = np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)
    trem = 0.75 + 0.25 * np.sin(2 * np.pi * (3 + 6 * t / sec) * t)
    env = np.minimum(1.0, t / 0.25) * (0.35 + 0.65 * (t / sec) ** 1.2)
    shimmer = np.zeros(n)
    rs = np.random.RandomState(6)
    for i in range(46):
        st = rs.uniform(0.2, 2.8)
        fq = rs.choice([1568, 1976, 2349, 2637, 3136])
        s = int(SR * st)
        m = min(int(SR * 0.25), n - s)
        tt = np.arange(m) / SR
        shimmer[s:s + m] += 0.10 * np.sin(2 * np.pi * fq * tt) * np.exp(-tt * 14) * (0.3 + st / 3)
    out = base * trem * env * 0.55 + shimmer
    save_wav("spirit_dukkan.wav", add_reverb(out, 0.25), gain=0.7)


def snd_teleport():
    # ısınlanma "pop": kisa alcalan sweep + parilti
    sec = 0.55
    t = t_axis(sec)
    f = 1400 * np.exp(-t * 7) + 180
    sweep = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(len(t), 0.004, 2.2)
    sp = np.zeros(len(t))
    rs = np.random.RandomState(7)
    for i in range(14):
        s = int(SR * rs.uniform(0.02, 0.35))
        m = min(int(SR * 0.12), len(t) - s)
        tt = np.arange(m) / SR
        sp[s:s + m] += 0.18 * np.sin(2 * np.pi * rs.choice([1976, 2637, 3136]) * tt) * np.exp(-tt * 24)
    save_wav("spirit_teleport.wav", add_reverb(sweep * 0.9 + sp, 0.3))


def snd_kalkan_bagi():
    # Iki ayri "kalkan" notasinin birlesip tek bir uyumlu akorda donustugu kisa bir "baglanma" sesi.
    sec = 0.7
    t = t_axis(sec)
    a = tone(392.0, sec, harmonics=((1, 1.0), (2, 0.25))) * env_ad(len(t), 0.02, 2.0)
    b = tone(523.25, sec, harmonics=((1, 1.0), (2, 0.25))) * env_ad(len(t), 0.02, 2.0)
    glide_in = np.minimum(1.0, t / 0.18)
    out = (a * (1.0 - 0.4 * (1.0 - glide_in)) + b * glide_in) * 0.6
    shimmer = np.zeros(len(t))
    rs = np.random.RandomState(9)
    for i in range(10):
        s = int(SR * rs.uniform(0.05, 0.5))
        m = min(int(SR * 0.15), len(t) - s)
        tt = np.arange(m) / SR
        shimmer[s:s + m] += 0.12 * np.sin(2 * np.pi * rs.choice([1568, 1976, 2349]) * tt) * np.exp(-tt * 18)
    save_wav("spirit_kalkan_bagi.wav", add_reverb(out + shimmer, 0.3))


def make_sounds():
    snd_can()
    snd_adc()
    snd_tank()
    snd_tank_reflect()
    snd_taktik()
    snd_dukkan()
    snd_teleport()
    snd_kalkan_bagi()


if __name__ == "__main__":
    make_sounds()
    print("ok")
