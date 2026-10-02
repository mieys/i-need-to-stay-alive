"""Tur 3: gorev basladi / gorev basarili / arkadas dustu icin E-H secenekleri (8-bit yok, pirilti kuyrugu yok)."""
import sys

import numpy as np

from gen_event_sfx import (N, T, buf, place, nf, phase_of, onepole_lp, lp, hp, bp, noise, attack_env, dec,
                           bell, chime, marimba, coin, pluck, saw, thump, pad, reverb, finish, write, fade_out)


def brass(f, d, attack=0.07, release=0.25, bright=2600, scoop=0.94, vib=0.004):
    """Bakir nefesli: aşağıdan kayarak oturan perde, 3 detune testere, nefesle acilan filtre."""
    t = T(d)
    fr = f * (1 - (1 - scoop) * np.exp(-t / 0.035)) * (1 + vib * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.25) / 0.2, 0, 1))
    x = saw(fr, d, 30) + saw(fr * 1.004, d, 30) + saw(fr * 0.996, d, 30)
    env = np.minimum(1, t / attack) ** 1.5 * np.clip((d - t) / release, 0, 1)
    cut = 250 + bright * env * (0.8 + 0.2 * np.exp(-t / 0.3))
    x = lp(x * env, cut, 2) / 3
    x += 0.012 * lp(bp(noise(d), 800, 3000), 3000, 2) * env
    return x


def taiko(d=0.9, f0=95, f1=38, tau=0.35, a=0.001):
    x = thump(f0, f1, d, tau, 0.06, a)
    x += 0.35 * lp(noise(d), 900, 2) * dec(d, 0.05)
    x += 0.12 * bp(noise(d), 1500, 5000) * dec(d, 0.01)
    return x


def cymbal_swell(d, peak=1.0):
    t = T(d)
    x = hp(noise(d), 4500)
    return lp(x, 12000, 1) * (t / d) ** 2.5 * peak


def cymbal_hit(d=1.4):
    return lp(hp(noise(d), 3500), 9000, 1) * dec(d, 0.26, 0.001)


def timpani_roll(d, f=98.0, rate=22, seed=2):
    r = np.random.default_rng(seed)
    out = buf(d)
    t = 0.0
    while t < d - 0.05:
        g = 0.25 + 0.75 * (t / d) ** 1.5
        place(out, thump(f * 1.15, f, 0.25, 0.12, 0.02, 0.003), t, g * r.uniform(0.6, 1.0))
        t += 1.0 / rate * r.uniform(0.85, 1.15)
    return out


def strum(freqs, d, gap=0.022, bright=0.65, gain=0.3):
    out = buf(d)
    for i, f in enumerate(freqs):
        place(out, pluck(f, d - i * gap, bright, 0.998), i * gap, gain)
    return out


# ---------------------------------------------------------------- gorev basladi

def mission_start_E():
    # Savas borusu (B'nin ciddi hali): alcak beşli bakir ses, asagidan oturur + taiko + zil kabarmasi
    d = 2.0
    x = buf(d)
    place(x, cymbal_swell(0.35, 0.5), 0.0, 0.25)
    hit = 0.3
    for f, g in ((nf("D3"), 0.5), (nf("A3"), 0.4), (nf("D4"), 0.3), (nf("D2"), 0.35)):
        place(x, brass(f, 1.2, 0.09, 0.45, 2200), hit, g)
    place(x, taiko(1.0, 90, 36, 0.4), hit, 0.9)
    place(x, cymbal_hit(1.2), hit, 0.12)
    return finish(np.tanh(reverb(x, 1.8, 0.32, 1.1, 3500) * 1.3) / 1.3, 0.13)


def mission_start_F():
    # Hucum II: ters zil kabarmasi -> dev taiko + kisa alcak bakir vurgu, pirilti yok
    d = 1.9
    x = buf(d)
    place(x, cymbal_swell(0.55, 1.0), 0.0, 0.35)
    place(x, timpani_roll(0.5, 73.4, 26), 0.05, 0.35)
    hit = 0.55
    place(x, taiko(1.2, 100, 34, 0.45), hit, 1.0)
    for f, g in ((nf("D2"), 0.4), (nf("A2"), 0.35), (nf("D3"), 0.3), (nf("F3"), 0.2)):
        place(x, brass(f, 0.45, 0.02, 0.2, 2800, 0.97, 0.0), hit, g)
    place(x, cymbal_hit(1.3), hit, 0.14)
    return finish(np.tanh(reverb(x, 1.7, 0.3, 1.0, 3500) * 1.4) / 1.4, 0.14)


def mission_start_G():
    # Celik: iki kilic carpismasi + ortse taiko, cinlama yavasca soner
    d = 1.8
    x = buf(d)
    for at, f, g in ((0.0, 1650, 0.5), (0.2, 2100, 0.6)):
        place(x, coin(f, 1.0, 0.4), at, g * 0.6)
        place(x, coin(f * 1.33, 0.8, 0.3), at + 0.003, g * 0.3)
        place(x, bp(noise(0.06), 2500, 9000) * dec(0.06, 0.012), at, g * 0.5)
    place(x, taiko(1.0, 95, 38, 0.38), 0.42, 0.95)
    place(x, brass(nf("D3"), 0.9, 0.05, 0.4, 1600), 0.42, 0.3)
    place(x, brass(nf("A3"), 0.9, 0.05, 0.4, 1600), 0.42, 0.22)
    return finish(np.tanh(reverb(x, 1.6, 0.3, 1.0) * 1.3) / 1.3, 0.13)


def mission_start_H():
    # Davul sayimi: hizlanan uc taiko (alcak-alcak-yuksek) + tek buyuk birlikte vurus
    d = 1.9
    x = buf(d)
    for at, f0, g in ((0.0, 85, 0.6), (0.24, 85, 0.65), (0.42, 120, 0.7)):
        place(x, taiko(0.6, f0, f0 * 0.42, 0.25), at, g)
    hit = 0.62
    place(x, taiko(1.2, 95, 33, 0.45), hit, 1.0)
    place(x, brass(nf("D3"), 0.8, 0.015, 0.35, 3000, 0.98, 0.0), hit, 0.35)
    place(x, brass(nf("A3"), 0.8, 0.015, 0.35, 3000, 0.98, 0.0), hit, 0.28)
    place(x, cymbal_hit(1.2), hit, 0.12)
    return finish(np.tanh(reverb(x, 1.5, 0.28, 1.0, 3500) * 1.4) / 1.4, 0.14)


# ---------------------------------------------------------------- gorev basarili

def mission_success_E():
    # Hazine fanfari II: A'nin aynisi ama pirilti kuyrugu yok, sicak ve temiz bir sonla biter
    d = 2.2
    x = buf(d)
    for i, n in enumerate(("C5", "E5", "G5", "C6", "E6")):
        place(x, marimba(nf(n), 0.7, 0.25), i * 0.065, 0.55)
        place(x, chime(nf(n) * 2, 0.5, 0.2), i * 0.065, 0.1)
    top = 5 * 0.065
    place(x, bell(nf("C6"), 1.5, 0.6, 3.5, 1.2, 0.3), top, 0.55)
    place(x, pad([nf("C4"), nf("G4"), nf("C5"), nf("E5"), nf("G5")], 1.5, 0.06, 0.9, 2800), top, 1.0)
    place(x, marimba(nf("C4"), 0.9, 0.35), top, 0.45)
    return finish(reverb(x, 1.5, 0.28, 0.9), 0.12)


def mission_success_F():
    # Pirinc zafer: "ta-ta-ta-taaa" bakir fanfar + timpani yuvarlanmasi + zil
    d = 2.4
    x = buf(d)
    place(x, timpani_roll(0.45, 98.0, 24, 5), 0.0, 0.3)
    for i in range(3):
        for f, g in ((nf("G4"), 0.32), (nf("D4"), 0.22), (nf("B3"), 0.18)):
            place(x, brass(f, 0.13, 0.015, 0.05, 3000, 0.98, 0.0), 0.08 + i * 0.12, g)
    hit = 0.45
    for f, g in ((nf("C5"), 0.4), (nf("G4"), 0.3), (nf("E4"), 0.28), (nf("C4"), 0.3), (nf("C3"), 0.25)):
        place(x, brass(f, 1.3, 0.05, 0.6, 3000, 0.97, 0.005), hit, g)
    place(x, taiko(1.0, 100, 50, 0.35), hit, 0.6)
    place(x, cymbal_hit(1.5), hit, 0.14)
    return finish(np.tanh(reverb(x, 1.7, 0.3, 1.0, 4000) * 1.2) / 1.2, 0.13)


def mission_success_G():
    # Altin yagmuru II: tel arpeji yukari + para dokulmesi + sicak akor (8-bit / uzun pirilti yok)
    d = 2.2
    x = buf(d)
    seq = ("C4", "G4", "C5", "E5", "G5", "C6")
    for i, n in enumerate(seq):
        place(x, pluck(nf(n), 0.9, 0.7, 0.997), i * 0.055, 0.4)
    top = len(seq) * 0.055
    r = np.random.default_rng(8)
    for i in range(10):
        place(x, coin(r.uniform(2300, 3900), 0.35, 0.16), top + 0.45 * (i / 9) ** 1.4, 0.14 * (1 - 0.4 * i / 10))
    place(x, pad([nf("C4"), nf("E4"), nf("G4"), nf("C5")], 1.4, 0.05, 0.8, 2400), top, 0.9)
    place(x, bell(nf("C6"), 1.2, 0.5, 1.41, 0.9, 0.3), top, 0.45)
    return finish(reverb(x, 1.4, 0.27, 0.9), 0.12)


def mission_success_H():
    # Kristal akor: tek buyuk, dolgun arp akoru (Cmaj9) + yumusak can + koro, temiz son
    d = 2.2
    x = buf(d)
    chord = [nf(n) for n in ("C3", "G3", "C4", "E4", "G4", "B4", "D5", "E5", "G5")]
    place(x, strum(chord, 1.8, 0.024, 0.7, 0.28), 0.0, 1.0)
    place(x, pad([nf("C4"), nf("E4"), nf("G4"), nf("B4"), nf("D5")], 1.7, 0.25, 0.9, 2600), 0.05, 1.1)
    place(x, bell(nf("G5"), 1.4, 0.55, 1.41, 0.8, 0.3), 0.2, 0.3)
    place(x, bell(nf("E6"), 1.4, 0.5, 1.41, 0.8, 0.3), 0.24, 0.22)
    return finish(reverb(x, 1.6, 0.3, 0.9), 0.12)


# ---------------------------------------------------------------- arkadas dustu

def ally_down_E():
    # Yardim cagrisi: kisik iki tonlu can alarmi (Mi-Do, Mi-Do) - "git kaldir" hissi
    d = 1.6
    x = buf(d)
    for i, (n, at) in enumerate((("E5", 0.0), ("C5", 0.16), ("E5", 0.45), ("C5", 0.61))):
        place(x, bell(nf(n), 0.6, 0.22, 2.0, 1.0, 0.15), at, 0.5 if i < 2 else 0.4)
    x = lp(x, 3500, 1)
    return finish(reverb(x, 1.3, 0.28, 0.9), 0.10)


def ally_down_F():
    # Uzak kalp atisi: bogulmus tek 'lub-dub' + alcak, inen bir ton
    d = 2.0
    x = buf(d)
    place(x, thump(70, 40, 0.35, 0.1, 0.03, 0.006), 0.0, 1.0)
    place(x, thump(70, 40, 0.35, 0.1, 0.03, 0.006), 0.17, 0.7)
    t = T(1.4)
    f = nf("A3") * (nf("E3") / nf("A3")) ** np.clip((t - 0.3) / 0.8, 0, 1)
    tone = np.sin(phase_of(f, len(t))) + 0.3 * np.sin(phase_of(f * 2, len(t)))
    tone *= np.clip(t / 0.15, 0, 1) * np.clip((1.4 - t) / 0.6, 0, 1)
    place(x, lp(tone, 900, 2), 0.15, 0.35)
    x = lp(x, 1800, 1)
    return finish(reverb(x, 2.0, 0.38, 1.2, 2000), 0.10)


def ally_down_G():
    # Cello inisi: yavas, kederli iki yay notasi (Re -> La), yay surtunmesiyle
    d = 2.3
    x = buf(d)
    for n, at, ln, g in (("D4", 0.0, 0.8, 0.5), ("A3", 0.65, 1.3, 0.55)):
        t = T(ln)
        f = nf(n) * (1 + 0.007 * np.sin(2 * np.pi * 5.0 * t) * np.clip((t - 0.15) / 0.2, 0, 1))
        s = saw(f, ln, 30) + saw(f * 1.003, ln, 30)
        env = np.clip(t / 0.12, 0, 1) * np.clip((ln - t) / 0.35, 0, 1)
        s = lp(s * env, 1400, 2) / 2
        s += 0.012 * lp(bp(noise(ln), 1500, 4000), 4000, 2) * env
        place(x, s, at, g)
    return finish(reverb(x, 1.9, 0.35, 1.1, 3000), 0.10)


def ally_down_H():
    # Tibet kasesi: vurulan sarki kasesi, yavas vuru (titresim), uzun sonus + yumusak alcak dusus
    d = 2.6
    t = T(d)
    f = 330.0
    x = np.zeros(len(t))
    for r, a, tau, beat in ((1.0, 1.0, 1.4, 1.3), (2.71, 0.5, 0.9, 2.1), (5.15, 0.25, 0.5, 3.0), (8.2, 0.1, 0.25, 4.0)):
        x += a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / tau) * (0.75 + 0.25 * np.cos(2 * np.pi * beat * t))
    x *= attack_env(len(t), 0.002)
    x += 0.15 * bp(noise(d), 1000, 5000) * dec(d, 0.008)
    place(x, thump(90, 45, 0.6, 0.25, 0.1, 0.004), 0.0, 0.35)
    fade_out(x, 0.5)
    return finish(reverb(x, 2.0, 0.32, 1.2), 0.10)


ROUND3 = {k: v for k, v in globals().items() if k.startswith(("mission_start_", "mission_success_", "ally_down_")) and callable(v)}

if __name__ == "__main__":
    only = set(sys.argv[1:])
    for name, fn in ROUND3.items():
        if not only or name in only:
            write(name, fn())
