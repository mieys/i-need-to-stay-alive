"""Tur 8: Hadime Q - lanet FIRLATMA sesi (4) + KARA BUYU (Q acilis) sesi (4). Dosyalar hadime_launch_A..D / hadime_spell_A..D."""
import numpy as np

from gen_event_sfx import (N, T, buf, place, nf, phase_of, lp, hp, bp, noise, attack_env, dec,
                           bell, chime, saw, thump, pad, reverb, finish, write, fade_out)
from round7_sfx import whisper, ghost_tone, crackle


# ================================================================ firlatma (kisa, her atista bir kez)

def hadime_launch_A():
    # Karanlik fisilti firlatma: yukari kayan hava + kisa fisilti kuyrugu
    d = 0.6
    x = buf(d)
    t = T(0.25)
    place(x, lp(hp(noise(0.25), 400), 800 + 4000 * (t / 0.25), 2) * np.sin(np.pi * t / 0.25) ** 1.2, 0.0, 0.6)
    t2 = T(0.3)
    place(x, whisper(0.3, 600, 1100, 2400, 14, 4) * np.exp(-t2 / 0.1) * attack_env(len(t2), 0.01), 0.08, 0.4)
    return finish(reverb(x, 0.9, 0.24, 0.4, 3500), 0.10)


def hadime_launch_B():
    # Golge ok: hizli, keskin hava 'fiiiut' + kucuk karanlik ting
    d = 0.5
    x = buf(d)
    t = T(0.16)
    sweep = bp(noise(0.16), 1200 + 3000 * (t / 0.16), 2500 + 6000 * (t / 0.16)) * np.sin(np.pi * t / 0.16) ** 0.8
    place(x, sweep, 0.0, 0.7)
    place(x, bell(nf("C#6"), 0.35, 0.1, 2.4, 0.9, 0.1), 0.06, 0.25)
    return finish(reverb(x, 0.8, 0.22, 0.35), 0.10)


def hadime_launch_C():
    # Ruh firlamasi: yukari kayan kisa hayalet tonu + hava
    d = 0.6
    x = buf(d)
    t = T(0.28)
    g = ghost_tone(nf("A4"), nf("A5"), 0.28, 10) * np.clip(t / 0.03, 0, 1) * np.exp(-t / 0.12)
    place(x, lp(g, 2600, 1), 0.0, 0.5)
    place(x, lp(hp(noise(0.2), 600), 3000, 2) * np.sin(np.pi * T(0.2) / 0.2), 0.0, 0.25)
    return finish(reverb(x, 1.0, 0.28, 0.4), 0.10)


def hadime_launch_D():
    # Mor kivilcim: cityrtili enerji patlamasi + yukari 'vuss'
    d = 0.5
    x = buf(d)
    t = T(0.25)
    place(x, crackle(0.25, 160, 9) * np.exp(-t / 0.08), 0.0, 0.7)
    place(x, lp(hp(noise(0.2), 500), 1000 + 3500 * (T(0.2) / 0.2), 2) * np.sin(np.pi * T(0.2) / 0.2), 0.0, 0.45)
    place(x, thump(140, 90, 0.15, 0.04, 0.02, 0.003), 0.0, 0.35)
    return finish(reverb(x, 0.8, 0.22, 0.35), 0.10)


# ================================================================ kara buyu (Q acilisi)

def growl(f0, d, rough=30.0):
    """Iblis hiriltisi: alcak testere + puruzlu genlik + agiz formanti."""
    t = T(d)
    r = np.random.default_rng(5)
    jitter = 1 + 0.03 * np.interp(t, np.linspace(0, d, int(d * rough) + 2), r.uniform(-1, 1, int(d * rough) + 2))
    x = saw(f0 * jitter, d, 40)
    x = bp(x, 250, 900) + 0.6 * bp(x, 900, 1600)
    am = 0.7 + 0.3 * np.abs(np.sin(2 * np.pi * 23 * t))
    return x * am


def hadime_spell_A():
    # Ters zikir: tersten kabaran fisildayan koro -> derin bum + alcak karanlik ugultu
    d = 2.2
    x = buf(d)
    t = T(0.8)
    w = whisper(0.8, 500, 950, 2300, 9, 8) + 0.6 * lp(pad([nf("D3"), nf("F3"), nf("G#3")], 0.8, 0.05, 0.05, 1200), 1200, 1)
    place(x, (w * np.linspace(0, 1, len(t)) ** 2.2), 0.0, 0.6)
    hit = 0.8
    place(x, thump(70, 30, 1.2, 0.45, 0.08, 0.004), hit, 1.0)
    t2 = T(1.3)
    drone = lp(saw(nf("D2"), 1.3, 30) + saw(nf("G#2") * 1.003, 1.3, 30), 500, 2) * np.clip(t2 / 0.05, 0, 1) * np.clip((1.3 - t2) / 0.7, 0, 1)
    place(x, drone, hit, 0.45)
    return finish(reverb(x, 2.0, 0.34, 1.2, 2800), 0.12)


def hadime_spell_B():
    # Kadim muhur: kabaran uyumsuz alcak kume + metalik titresim + iki kalp vurusu
    d = 2.2
    x = buf(d)
    t = T(1.8)
    clus = np.zeros(len(t))
    for n in ("C3", "C#3", "G3", "G#3"):
        clus += saw(nf(n) * (1 + 0.004 * np.sin(2 * np.pi * 0.7 * t + len(n))), 1.8, 24)
    env = np.clip(t / 0.6, 0, 1) ** 1.5 * np.clip((1.8 - t) / 0.7, 0, 1)
    place(x, lp(clus * env, 300 + 1200 * env, 2) / 4, 0.0, 0.7)
    shimmer = (np.sin(phase_of(nf("C#6"), len(t))) + np.sin(phase_of(nf("G6") * 1.01, len(t)))) * env * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * t))
    place(x, shimmer, 0.0, 0.06)
    for at, g in ((0.55, 0.8), (0.72, 0.6)):
        place(x, thump(70, 40, 0.35, 0.1, 0.03, 0.005), at, g)
    return finish(reverb(x, 1.9, 0.33, 1.1, 3000), 0.12)


def hadime_spell_C():
    # Lanet sozu: alcalan iblis hiriltisi + fisilti + ters can
    d = 2.0
    x = buf(d)
    t = T(1.2)
    gr = growl(nf("A1") * (1 - 0.25 * (t / 1.2)), 1.2) * np.clip(t / 0.15, 0, 1) * np.clip((1.2 - t) / 0.5, 0, 1)
    place(x, gr, 0.15, 0.6)
    place(x, whisper(1.2, 450, 900, 2200, 8, 12) * np.clip(t / 0.3, 0, 1) * np.clip((1.2 - t) / 0.5, 0, 1), 0.2, 0.35)
    sw = bell(nf("D5"), 0.4, 0.2, 2.4, 1.0, 0.1)[::-1] * np.linspace(0, 1, N(0.4)) ** 2
    place(x, sw, 0.0, 0.25)
    return finish(reverb(x, 1.8, 0.33, 1.1, 2800), 0.12)


def hadime_spell_D():
    # Kara girdap: donen alcak gurultu girdabi (filtre salinimi) + alt dusus + minor can
    d = 2.2
    x = buf(d)
    t = T(1.7)
    cut = 300 + 900 * (0.5 + 0.5 * np.sin(2 * np.pi * (2 + 3 * t / 1.7) * t))
    vortex = lp(noise(1.7), cut, 2) * np.clip(t / 0.4, 0, 1) * np.clip((1.7 - t) / 0.6, 0, 1)
    place(x, vortex, 0.0, 0.9)
    place(x, thump(90, 28, 1.2, 0.5, 0.3, 0.01), 0.3, 0.8)
    place(x, bell(nf("A3"), 1.4, 0.6, 2.0, 1.2, 0.1), 0.3, 0.3)
    place(x, bell(nf("C4"), 1.4, 0.6, 2.0, 1.0, 0.1), 0.3, 0.2)
    return finish(reverb(x, 2.0, 0.34, 1.1, 2800), 0.12)


if __name__ == "__main__":
    for k in ("A", "B", "C", "D"):
        write("hadime_launch_" + k, globals()["hadime_launch_" + k]())
        write("hadime_spell_" + k, globals()["hadime_spell_" + k]())


def hadime_spell_D_fit(end=0.68, launch=0.3):
    """Kara girdap, oyundaki zamanlamaya oturtulmus (kullanici 2026-10-01: "q acilis sesi toplar yukari cikarkenki an ile
    ayni anda bitmeli"): Q basildi = 0, ilk lanetler HadimeMath.Q_FIRST_CURSE_DELAY (0.3) sn'de firlar, CURSE_RISE_TIME
    (0.38) sn yukselir -> tepe = 0.68 sn. Girdap 0..0.68 boyunca doner/kabarir, derin dusus + minor can firlatma aninda
    (0.3), ses (reverb kuyrugu dahil) tam 0.68'de soner."""
    x = buf(end + 0.2)
    t = T(end)
    cut = 300 + 900 * (0.5 + 0.5 * np.sin(2 * np.pi * (4 + 6 * t / end) * t))
    vortex = lp(noise(end), cut, 2) * np.clip(t / 0.12, 0, 1) * (0.7 + 0.3 * t / end)
    place(x, vortex, 0.0, 0.9)
    place(x, thump(90, 28, 0.6, 0.25, 0.12, 0.01), launch, 0.8)
    place(x, bell(nf("A3"), 0.6, 0.35, 2.0, 1.2, 0.1), launch, 0.3)
    place(x, bell(nf("C4"), 0.6, 0.35, 2.0, 1.0, 0.1), launch, 0.2)
    st = reverb(x, 1.2, 0.3, 0.2, 2800)[:N(end)]
    k = N(0.12)
    st[-k:] *= (np.linspace(1, 0, k) ** 2)[:, None]
    peak = np.max(np.abs(st))
    return st * (0.89 / peak) * 0.75


if __name__ == "__main__":
    write("hadime_spell_D_fit", hadime_spell_D_fit())
