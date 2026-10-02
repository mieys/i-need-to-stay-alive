"""Tur 2: karar verilmeyen olaylar icin C / D secenekleri. gen_event_sfx.py'nin yardimcilarini kullanir."""
import sys

import numpy as np

from gen_event_sfx import (N, T, buf, place, nf, phase_of, onepole_lp, lp, hp, bp, noise, attack_env, dec,
                           bell, chime, marimba, coin, pluck, saw, thump, woodblock, pad, reverb, finish, write)


def square(freq, d, harm=15):
    """Bant sinirli kare dalga (tek harmonikler) - 8-bit/chiptune tinisi."""
    n = N(d)
    ph = phase_of(freq, n)
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
    out = np.zeros(n)
    for k in range(1, 2 * harm, 2):
        out += ((f * k) < 44100 * 0.45) * np.sin(k * ph) / k
    return out * 0.7


def chip_note(f, d, decay=0.06, vib=0.0):
    t = T(d)
    fr = f * (1 + vib * np.sin(2 * np.pi * 6 * t) * np.clip((t - 0.08) / 0.1, 0, 1))
    env = np.minimum(1, t / 0.004) * np.clip((d - t) / 0.03, 0, 1) * (0.75 + 0.25 * np.exp(-t / decay))
    return lp(square(fr, d) * env, 7000, 1)


def whistle(notes, d):
    """Islik: notalar arasi kayan sinus + vibrato + nefes. notes = [(nota, baslangic, sure)]."""
    t = T(d)
    f = np.full(len(t), nf(notes[0][0]))
    amp = np.zeros(len(t))
    for n_, at, ln in notes:
        i0, i1 = N(at), min(len(t), N(at + ln))
        f[i0:] = nf(n_)
        tt = t[i0:i1] - at
        amp[i0:i1] = np.maximum(amp[i0:i1], np.minimum(1, tt / 0.025) * np.clip((ln - tt) / 0.05, 0, 1))
    f = onepole_lp(f, 30) * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * t))
    amp = onepole_lp(amp, 40)
    ph = phase_of(f, len(t))
    return (np.sin(ph) + 0.06 * np.sin(2 * ph) + bp(noise(d), 1500, 5000) * 0.035) * amp


def camel_bell(f=780, d=0.9):
    """Kervan cani: kalin pirinc, kisa tini."""
    return bell(f, d, 0.3, 2.41, 1.8, 0.2) + 0.5 * bell(f * 1.19, d, 0.22, 2.41, 1.4, 0.1)


def glass_shards(d, count, seed, lo=2500, hi=7500):
    r = np.random.default_rng(seed)
    out = buf(d)
    for i in range(count):
        at = 0.25 * (i / count) ** 1.5 + r.uniform(0, 0.03)
        place(out, chime(r.uniform(lo, hi), 0.35, r.uniform(0.04, 0.12)), at, r.uniform(0.15, 0.35) * (1 - 0.5 * i / count))
    return out


def tri(f, d):
    return (2 / np.pi) * np.arcsin(np.sin(phase_of(f, N(d))))


def mission_start_C():
    # Kilic cekme: metal suruntu + cinlayan bicak + alcak darbe
    d = 1.4
    x = buf(d)
    t = T(0.32)
    cut = 1500 + 3500 * (t / 0.32)
    scrape = lp(hp(noise(0.32), cut), cut * 1.8, 1) * np.sin(np.pi * t / 0.32) ** 0.7
    place(x, scrape, 0.0, 0.5)
    place(x, coin(1850, 1.0, 0.45), 0.24, 0.45)
    place(x, coin(2480, 1.0, 0.35), 0.245, 0.25)
    place(x, thump(120, 50, 0.5, 0.18), 0.26, 0.85)
    return finish(reverb(x, 1.3, 0.3, 1.0), 0.12)


def mission_start_D():
    # Geri sayim bitti: uc tik + parlak "BASLA" akoru + yukari mini arpej (chiptune)
    d = 1.4
    x = buf(d)
    for i in range(3):
        place(x, woodblock(1100 if i < 2 else 1400, 0.1), i * 0.16, 0.55)
    hit = 0.5
    for n in ("C5", "E5", "G5"):
        place(x, chip_note(nf(n), 0.5, 0.08), hit, 0.22)
        place(x, pluck(nf(n) * 2, 0.8, 0.8), hit, 0.18)
    for i, n in enumerate(("G5", "C6", "E6", "G6")):
        place(x, chip_note(nf(n), 0.09, 0.03), hit + 0.12 + i * 0.05, 0.16)
    place(x, thump(140, 60, 0.3, 0.1), hit, 0.7)
    return finish(reverb(x, 1.0, 0.24, 0.8), 0.12)


def mission_success_C():
    # Kristal kaskad: inen sonra cikan glockenspiel cagleyani + sicak akor
    d = 2.6
    x = buf(d)
    for i, n in enumerate(("E7", "D7", "C7", "A6", "G6", "E6")):
        place(x, chime(nf(n), 0.7, 0.3), i * 0.04, 0.3)
    for i, n in enumerate(("G6", "C7", "E7", "G7")):
        place(x, chime(nf(n), 1.2, 0.55), 0.3 + i * 0.07, 0.36)
    place(x, pad([nf("C4"), nf("G4"), nf("C5"), nf("E5")], 1.9, 0.12, 1.1, 2600), 0.3, 1.0)
    place(x, marimba(nf("C4"), 0.8, 0.3), 0.3, 0.5)
    return finish(reverb(x, 1.9, 0.34, 1.2), 0.12)


def mission_success_D():
    # 8-bit zafer: chiptune 'seviye gecildi' jingle'i + titresimli son nota
    d = 1.9
    x = buf(d)
    seq = (("G4", 0.0, 0.09), ("C5", 0.1, 0.09), ("E5", 0.2, 0.09), ("G5", 0.3, 0.09),
           ("C6", 0.4, 0.09), ("E6", 0.5, 0.09), ("G6", 0.6, 0.22), ("E6", 0.84, 0.22), ("G6", 1.08, 0.6))
    for n, at, ln in seq:
        place(x, chip_note(nf(n), ln, 0.05, 0.01 if ln > 0.5 else 0.0), at, 0.28)
    for n, at, ln in (("C3", 0.0, 0.38), ("G3", 0.4, 0.38), ("C4", 0.84, 0.22), ("C3", 1.08, 0.6)):
        t = T(ln)
        place(x, tri(nf(n), ln) * np.clip((ln - t) / 0.04, 0, 1), at, 0.35)
    return finish(reverb(x, 0.9, 0.18, 0.6), 0.11)


def mission_fail_C():
    # Sonen marimba: yumusak inen minor arpej, ciddi ama sert degil
    d = 2.0
    x = buf(d)
    for i, n in enumerate(("A4", "F4", "D4", "A3")):
        place(x, marimba(nf(n), 1.0, 0.35 + 0.1 * i), i * 0.17, 0.6)
    place(x, pad([nf("D3"), nf("F3"), nf("A3")], 1.4, 0.3, 0.9, 900), 0.4, 0.7)
    return finish(reverb(x, 1.6, 0.32, 1.0), 0.10)


def mission_fail_D():
    # 8-bit kayip: inen chiptune notalari + 'bwoop' perde dususu
    d = 1.6
    x = buf(d)
    for i, n in enumerate(("B4", "F4", "D4")):
        place(x, chip_note(nf(n), 0.16, 0.05), i * 0.18, 0.26)
    t = T(0.6)
    f = nf("C4") * (0.35 ** (t / 0.6))
    place(x, lp(square(f, 0.6) * np.clip((0.6 - t) / 0.2, 0, 1) * attack_env(len(t), 0.006), 3000, 1), 0.56, 0.3)
    return finish(reverb(x, 0.8, 0.18, 0.5), 0.10)


def merchant_arrive_C():
    # Islik calan tuccar + kese sikirtisi
    d = 1.5
    x = whistle((("G5", 0.0, 0.13), ("C6", 0.15, 0.13), ("E6", 0.3, 0.12), ("D6", 0.44, 0.1), ("G6", 0.56, 0.45)), d) * 0.7
    r = np.random.default_rng(31)
    for i in range(5):
        place(x, coin(r.uniform(2600, 3900), 0.35, 0.15), 0.62 + i * 0.035, 0.1)
    return finish(reverb(x, 1.2, 0.3, 0.9), 0.10)


def merchant_arrive_D():
    # Kervan canlari: uc ritmik salinim + para
    d = 1.6
    x = buf(d)
    r = np.random.default_rng(12)
    for at in (0.0, 0.26, 0.52):
        for k in range(3):
            place(x, camel_bell(r.uniform(700, 900), 0.9), at + k * 0.035 + r.uniform(0, 0.01), 0.35 * (1 - 0.15 * k))
    place(x, coin(3400, 0.45, 0.2), 0.62, 0.12)
    place(x, coin(4000, 0.45, 0.2), 0.68, 0.1)
    return finish(reverb(x, 1.3, 0.28, 0.9), 0.10)


def merchant_leave_C():
    # Islik, inen ve uzaklasan
    d = 1.5
    x = whistle((("G6", 0.0, 0.14), ("E6", 0.16, 0.14), ("C6", 0.32, 0.14), ("G5", 0.48, 0.5)), d) * 0.7
    x *= np.linspace(1, 0.45, len(x))
    x = lp(x, np.linspace(6000, 1800, len(x)), 1)
    return finish(reverb(x, 1.3, 0.32, 0.9), 0.085)


def merchant_leave_D():
    # Kervan uzaklasiyor: canlar giderek boguk ve kisik
    d = 1.8
    x = buf(d)
    r = np.random.default_rng(13)
    for g, at in enumerate((0.0, 0.3, 0.6)):
        for k in range(3):
            place(x, camel_bell(r.uniform(680, 860), 0.8), at + k * 0.04, 0.35 * (1 - 0.3 * g))
    x = lp(x, np.linspace(5000, 1000, len(x)), 1)
    return finish(reverb(x, 1.4, 0.34, 0.9), 0.085)


def chat_C():
    # Damla: su damlasi 'blup' + kucuk yanki
    d = 0.35
    x = buf(d)
    t = T(0.08)
    f = 700 * np.clip(2.6 ** (t / 0.03), 1, 2.6)
    place(x, np.sin(phase_of(f, len(t))) * np.exp(-t / 0.022) * attack_env(len(t), 0.002), 0.0, 0.9)
    place(x, np.sin(phase_of(f * 1.25, len(t))) * np.exp(-t / 0.015) * attack_env(len(t), 0.003), 0.11, 0.25)
    return finish(reverb(x, 0.7, 0.2, 0.35), 0.09)


def chat_D():
    # Mini ruzgar cani: uc yumusak cam tini
    d = 0.6
    x = buf(d)
    for i, (n, g) in enumerate((("A6", 0.5), ("E7", 0.35), ("C#7", 0.22))):
        place(x, chime(nf(n), 0.5, 0.16), i * 0.05, g)
    return finish(reverb(x, 0.9, 0.24, 0.4), 0.085)


def ally_down_C():
    # Yas borusu: bogulmus, alcak, inen tek boru notasi
    d = 2.0
    t = T(1.5)
    f = nf("F3") * np.where(t < 0.5, 1.0, (nf("D3") / nf("F3")) ** np.clip((t - 0.5) / 0.25, 0, 1))
    f = f * (1 + 0.006 * np.sin(2 * np.pi * 4.5 * t))
    env = np.minimum(1, t / 0.12) * np.clip((1.5 - t) / 0.6, 0, 1)
    x = buf(d)
    place(x, lp(saw(f, 1.5, 24) * env, 500 + 500 * env, 2), 0.0, 1.0)
    place(x, thump(80, 40, 0.5, 0.2), 0.0, 0.4)
    return finish(reverb(x, 1.8, 0.35, 1.0, 2500), 0.10)


def ally_down_D():
    # Kirilan kristal: dokulen cam parcalari + tok darbe
    d = 1.4
    x = buf(d)
    place(x, glass_shards(0.9, 18, 41), 0.0, 1.0)
    place(x, bp(noise(0.12), 2000, 9000) * dec(0.12, 0.03), 0.0, 0.3)
    place(x, thump(110, 45, 0.5, 0.18), 0.02, 0.7)
    place(x, bell(nf("E4"), 1.0, 0.4, 2.0, 0.8, 0.1), 0.05, 0.25)
    return finish(reverb(x, 1.4, 0.3, 0.9), 0.10)


ROUND2 = {k: v for k, v in globals().items() if k.endswith(("_C", "_D")) and callable(v)}

if __name__ == "__main__":
    only = set(sys.argv[1:])
    for name, fn in ROUND2.items():
        if not only or name in only:
            write(name, fn())
