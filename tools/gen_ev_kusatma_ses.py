#!/usr/bin/env python3
"""EV KUSATMASI sesleri (2026-10-19, madde 313) - repo kokundeki telifsiz "Sound FX Starter Pack Vol. 1"den islenir.

Kullanim (repo kokunden):  python tools/gen_ev_kusatma_ses.py
Yazar: assets/audio/ev/
  duvar_vurus_1..4.wav : evin icinden duyulan BOGUK duvar vuruslari (yaratiklar dis duvara vuruyor): alcak geciren (~380 Hz,
                         4. derece) + hafif tok oda yankisi, perde biraz asagi.
  deprem.wav           : acilistaki deprem gurultusu (Earthquake Loop 0-7.5 sn, yumusak giris/cikis, tizler kisik).
  ev_yikilis.wav       : ev yikilirken tahta kirilmasi + govde gurultusu.
Not: tanh sinirlayici YOK (kullanici reddetti); yalniz tepe normalizasyonu + yumusak kenarlar.
"""
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.path.join(ROOT, "Sound FX Starter Pack Vol. 1")
OUT = os.path.join(ROOT, "assets", "audio", "ev")
SR = 44100


def load(rel):
    w = wave.open(os.path.join(PACK, rel))
    n, ch, sr = w.getnframes(), w.getnchannels(), w.getframerate()
    a = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float64).reshape(-1, ch).mean(1) / 32768.0
    assert sr == SR, (rel, sr)
    return a


def cut(a, t0, t1):
    return a[int(t0 * SR):int(t1 * SR)].copy()


def biquad_lp(a, fc, q=0.707):
    w0 = 2 * np.pi * fc / SR
    al = np.sin(w0) / (2 * q)
    c = np.cos(w0)
    b0, b1, b2 = (1 - c) / 2, 1 - c, (1 - c) / 2
    a0, a1, a2 = 1 + al, -2 * c, 1 - al
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros_like(a)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(a)):
        x0 = a[i]
        y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        y[i] = y0
        x2, x1, y2, y1 = x1, x0, y1, y0
    return y


def highpass_dc(a, fc=30.0):
    """Cok alcak (DC) kaymayi temizler: tek kutuplu yuksek geciren."""
    r = np.exp(-2 * np.pi * fc / SR)
    y = np.zeros_like(a)
    prev_x = prev_y = 0.0
    for i in range(len(a)):
        prev_y = a[i] - prev_x + r * prev_y
        prev_x = a[i]
        y[i] = prev_y
    return y


def repitch(a, ratio):
    """ratio < 1 = daha pes ve uzun (basit dogrusal yeniden ornekleme)."""
    n = int(len(a) / ratio)
    return np.interp(np.arange(n) * ratio, np.arange(len(a)), a)


def room(a, delays_ms=(23, 37, 53), gains=(0.32, 0.22, 0.14)):
    """Kucuk tahta oda: birkac erken yansima (bogukluk hissi, yapay yankidan kacinmak icin kisa)."""
    out = np.concatenate([a, np.zeros(int(SR * 0.08))])
    for d, g in zip(delays_ms, gains):
        k = int(SR * d / 1000)
        out[k:k + len(a)] += a * g
    return out


def fade(a, fin, fout):
    n_in, n_out = int(fin * SR), int(fout * SR)
    if n_in:
        a[:n_in] *= np.linspace(0, 1, n_in) ** 2
    if n_out:
        a[-n_out:] *= np.linspace(1, 0, n_out) ** 2
    return a


def norm(a, peak):
    m = np.abs(a).max()
    return a * (peak / m) if m > 0 else a


def save(name, a):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(a, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"yazildi: assets/audio/ev/{name} ({len(a) / SR:.2f} sn)")


def muffled(a, ratio, fc):
    a = repitch(a, ratio)
    a = biquad_lp(biquad_lp(a, fc), fc) ## 4. derece: duvarin arkasindan
    a = room(a)
    a = highpass_dc(a)
    return norm(fade(a, 0.004, 0.18), 0.72)


def main():
    save("duvar_vurus_1.wav", muffled(cut(load("Motions and Impacts/Impact Redwood.wav"), 0.0, 0.9), 0.82, 380))
    save("duvar_vurus_2.wav", muffled(cut(load("Hollywood/Bust Door Open.wav"), 0.0, 0.9), 0.78, 340))
    save("duvar_vurus_3.wav", muffled(cut(load("Motions and Impacts/Impact Axe Fall.wav"), 0.0, 1.0), 0.86, 420))
    save("duvar_vurus_4.wav", muffled(cut(load("Hollywood/Deathpunch.wav"), 0.0, 0.5), 0.7, 300))
    q = cut(load("Hollywood/Earthquake Loop.wav"), 0.0, 7.5)
    q = highpass_dc(biquad_lp(q, 1400))
    save("deprem.wav", norm(fade(q, 0.9, 2.2), 0.8))
    crash = cut(load("Hollywood/Wooden Crate Destruction.wav"), 0.0, 1.5)
    axe = cut(load("Motions and Impacts/Impact Axe Fall.wav"), 0.0, 2.6)
    rumble = biquad_lp(cut(load("Hollywood/Earthquake Loop.wav"), 2.0, 5.0), 600)
    mix = np.zeros(int(SR * 3.2))
    mix[:len(rumble)] += fade(rumble, 0.05, 1.6) * 0.55
    mix[:len(axe)] += biquad_lp(axe, 2200) * 0.8
    k = int(SR * 0.12)
    mix[k:k + len(crash)] += crash * 0.9
    save("ev_yikilis.wav", norm(fade(highpass_dc(mix), 0.003, 0.9), 0.85))


if __name__ == "__main__":
    main()
