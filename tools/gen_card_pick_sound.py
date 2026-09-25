"""Kullanici istegi (2026-09-25): "bir karti secince parilti ve odullendirici bir ses efekti ciksin ve 1 saniye boyunca kart
parildasin sonrasinda level kart secim ekrani kapansin boyle cok ruhsuz."

assets/audio/card_pick.wav uretir (~1.1 sn, kart parlamasinin 1 sn'lik suresini kaplar):
  - kisa, yumusak bir "vurus" (dusen perdeli alcak sinus) - secimin agirligi / savas hissi,
  - kilicin kinindan cekilisi gibi yukari suzulen metalik "shing" (bant gecirgen gurultu),
  - yukselen parlak can arpeji (Do-Mi-Sol-Do, hafif inharmonik can kismi sesleri),
  - arkasindan sonumlenen majör akor + rastgele tiz "isilti" damlalari, hafif yanki.
Kademe (tier) farki calisma aninda pitch_scale ile verilir (bkz. scripts/tier_card_fx.gd celebrate).

Calistir: python tools/gen_card_pick_sound.py   (sonra Godot --headless --import)
"""

import os
import wave

import numpy as np

SR = 44100
OUT_AUDIO = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
RNG = np.random.RandomState(7)


def t_axis(sec):
    return np.linspace(0, sec, int(SR * sec), endpoint=False)


def env_ad(n, attack, release_pow=2.2):
    e = np.ones(n)
    a = max(1, int(SR * attack))
    e[:a] = np.linspace(0, 1, a)
    e[a:] = np.linspace(1, 0, n - a) ** release_pow
    return e


def onepole_lp(x, cutoff_hz):
    rc = 1.0 / (2 * np.pi * cutoff_hz)
    a = (1.0 / SR) / (rc + 1.0 / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def place(buf, sig, start_sec, gain=1.0):
    s = int(SR * start_sec)
    e = min(len(buf), s + len(sig))
    buf[s:e] += sig[: e - s] * gain


def bell(freq, sec, decay):
    t = t_axis(sec)
    partials = ((1.0, 1.0), (2.0, 0.45), (3.01, 0.22), (4.16, 0.12), (5.43, 0.06))
    x = np.zeros_like(t)
    for mult, amp in partials:
        x += amp * np.sin(2 * np.pi * freq * mult * t) * np.exp(-t * decay * (0.8 + 0.4 * mult))
    atk = int(SR * 0.002)
    x[:atk] *= np.linspace(0, 1, atk)
    return x


def save_wav(name, x, gain=0.88):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    f = int(SR * 0.02)
    x[-f:] *= np.linspace(1, 0, f)
    data = (x * 32767).astype(np.int16)
    os.makedirs(OUT_AUDIO, exist_ok=True)
    path = os.path.join(OUT_AUDIO, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", os.path.abspath(path))


def snd_card_pick():
    total = 1.15
    n = int(SR * total)
    out = np.zeros(n)

    # 1) yumusak vurus: 150 -> 55 Hz dusen sinus, 0.22 sn
    sec = 0.22
    t = t_axis(sec)
    f = 55.0 + 95.0 * np.exp(-t * 18.0)
    thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(len(t), 0.004, 2.5)
    place(out, thump, 0.0, 0.55)

    # 2) metalik "shing": gurultu, yukari kayan rezonans (2.2k -> 6k), 0.32 sn
    sec = 0.32
    t = t_axis(sec)
    noise = RNG.randn(len(t))
    hp = noise - onepole_lp(noise, 1800.0)
    fc = 2200.0 + 3800.0 * (t / sec)
    ring = np.sin(2 * np.pi * np.cumsum(fc) / SR)
    shing = (0.55 * hp + 0.45 * ring * (0.6 + 0.4 * hp)) * env_ad(len(t), 0.01, 1.6)
    place(out, shing, 0.01, 0.16)

    # 3) yukselen can arpeji: C6 E6 G6 C7
    for i, fr in enumerate((1046.5, 1318.5, 1568.0, 2093.0)):
        place(out, bell(fr, 0.75, 6.5), 0.05 + i * 0.065, 0.42 if i < 3 else 0.5)

    # 4) sonumlenen akor (C5 E5 G5 C6) - odul "doygunlugu"
    sec = 0.9
    t = t_axis(sec)
    pad = np.zeros_like(t)
    for fr in (523.25, 659.25, 783.99, 1046.5):
        pad += np.sin(2 * np.pi * fr * t) + 0.25 * np.sin(2 * np.pi * fr * 2 * t)
    pad *= env_ad(len(t), 0.05, 2.0)
    place(out, pad, 0.24, 0.1)

    # 5) isilti damlalari: 3-6 kHz kisa sinusler, zamanla seyrelir
    for k in range(22):
        st = 0.18 + (k / 22.0) ** 1.3 * 0.8 + RNG.uniform(-0.02, 0.02)
        fr = RNG.uniform(3000.0, 6200.0)
        d = 0.045
        tt = t_axis(d)
        blip = np.sin(2 * np.pi * fr * tt) * env_ad(len(tt), 0.001, 3.0)
        place(out, blip, st, 0.13 * (1.0 - k / 26.0))

    # 6) hafif yanki (iki kisa gecikme)
    wet = np.zeros_like(out)
    for dl, g in ((0.083, 0.22), (0.151, 0.12)):
        s = int(SR * dl)
        wet[s:] += out[:-s] * g
    out = out + wet
    save_wav("card_pick.wav", out)


if __name__ == "__main__":
    snd_card_pick()
