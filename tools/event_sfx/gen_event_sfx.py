"""Olay sesleri (gorev/satici/boss/altin/sohbet/olum/dirilis) - her olay icin A ve B secenegi.
Tamamen prosedurel (numpy): FM can, marimba, metal para, Karplus-Strong pluck, katki testere, gurultu, Schroeder reverb.
Cikti: <bu klasor>/event_sfx/<olay>_<A|B>.wav (44.1 kHz, 16 bit, stereo)."""

import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "event_sfx")
RNG = np.random.default_rng(7)


# ------------------------------------------------------------------ temel

def N(d):
    return int(round(SR * d))


def T(d):
    return np.arange(N(d)) / SR


def buf(d):
    return np.zeros(N(d))


def place(dst, src, at, gain=1.0):
    i = N(at)
    if i >= len(dst):
        return
    n = min(len(src), len(dst) - i)
    seg = src[:n].copy()
    # her katmanin sonu yumusak sonsun (sonmeden kesilen kisim = tik sesi)
    k = min(N(0.04), n // 3)
    if k > 1:
        ramp = np.linspace(1, 0, k) ** 2
        seg[-k:] *= ramp if seg.ndim == 1 else ramp[:, None]
    dst[i:i + n] += seg * gain


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def nf(name):
    """'C5' -> Hz."""
    pitch, octv = name[:-1], int(name[-1])
    return mtof(12 * (octv + 1) + NOTE[pitch])


def phase_of(freq, n):
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
    return 2 * np.pi * np.cumsum(f) / SR


def osc(freq, d, ph0=0.0):
    return np.sin(phase_of(freq, N(d)) + ph0)


def attack_env(n, a=0.002):
    e = np.ones(n)
    k = max(1, min(n, N(a)))
    e[:k] = np.linspace(0, 1, k) ** 0.8
    return e


def dec(d, tau, a=0.002):
    t = T(d)
    return np.exp(-t / tau) * attack_env(len(t), a)


def fade_out(x, d):
    k = min(len(x), N(d))
    if k > 0:
        x[-k:] *= np.linspace(1, 0, k) ** 2
    return x


def noise(d):
    return RNG.standard_normal(N(d))


def onepole_lp(x, cutoff):
    cut = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), x.shape)
    a = 1.0 - np.exp(-2 * np.pi * np.clip(cut, 5, SR * 0.45) / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def lp(x, cutoff, order=2):
    for _ in range(order):
        x = onepole_lp(x, cutoff)
    return x


def hp(x, cutoff):
    return x - onepole_lp(x, cutoff)


def bp(x, lo, hi):
    return lp(hp(x, lo), hi)


# ------------------------------------------------------------------ enstrumanlar

def bell(f, d=1.2, tau=0.5, ratio=3.5, index=1.6, bright=0.3):
    """FM can: parlak atak, yumusak kuyruk."""
    t = T(d)
    mod = index * np.exp(-t / (tau * 0.35)) * np.sin(2 * np.pi * f * ratio * t)
    car = np.sin(2 * np.pi * f * t + mod) * np.exp(-t / tau)
    oct2 = bright * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t / (tau * 0.4))
    return (car + oct2) * attack_env(len(t), 0.0015)


def chime(f, d=1.0, tau=0.6):
    """Cam/kristal zil: harmonik olmayan ama tatli kismi sesler."""
    t = T(d)
    out = np.zeros_like(t)
    for r, a, k in ((1.0, 1.0, 1.0), (2.0, 0.35, 0.55), (3.01, 0.18, 0.35), (4.17, 0.1, 0.22)):
        out += a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / (tau * k))
    return out * attack_env(len(t), 0.001)


def marimba(f, d=0.6, tau=0.22):
    t = T(d)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / tau)
    x += 0.35 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t / 0.035)
    x += 0.12 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t / 0.01)
    return x * attack_env(len(t), 0.0012)


def coin(f, d=0.45, tau=0.28):
    """Metal para 'tink': harmonik olmayan kismi sesler + hafif vuru (detune) + mikro tik."""
    t = T(d)
    x = np.zeros_like(t)
    for r, a, k in ((1.0, 1.0, 1.0), (2.76, 0.6, 0.6), (5.40, 0.4, 0.35), (8.93, 0.22, 0.2)):
        x += a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / (tau * k))
        x += 0.5 * a * np.sin(2 * np.pi * f * r * 1.004 * t) * np.exp(-t / (tau * k))
    click = hp(noise(0.004), 4000) * np.linspace(1, 0, N(0.004))
    x[:len(click)] += 0.6 * click
    return x * attack_env(len(t), 0.0005)


def pluck(f, d=0.8, bright=0.55, decay=0.996):
    """Karplus-Strong (blok vektorlu)."""
    n = N(d)
    D = max(2, int(round(SR / f)))
    y = np.zeros(n + D + 1)
    y[:D] = lp(RNG.uniform(-1, 1, D), 1500 + 9000 * bright, 1)
    s = D
    while s < n + D:
        e = min(s + D, n + D)
        a = y[s - D:e - D]
        b = y[s - D - 1:e - D - 1] if s - D - 1 >= 0 else np.concatenate(([0.0], y[s - D:e - D - 1]))
        y[s:e] = decay * 0.5 * (a + b)
        s = e
    out = y[D:D + n]
    out = out / (np.max(np.abs(out)) + 1e-9)
    return out * attack_env(n, 0.001)


def saw(freq, d, harm=24):
    n = N(d)
    ph = phase_of(freq, n)
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
    out = np.zeros(n)
    for k in range(1, harm + 1):
        mask = (f * k) < SR * 0.45
        out += mask * np.sin(k * ph) / k
    return out * 0.6


def thump(f0, f1, d=0.5, tau=0.18, sweep=0.08, a=0.001):
    t = T(d)
    f = f1 + (f0 - f1) * np.exp(-t / sweep)
    return np.sin(phase_of(f, len(t))) * np.exp(-t / tau) * attack_env(len(t), a)


def woodblock(f=900, d=0.12):
    t = T(d)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.025) + 0.4 * np.sin(2 * np.pi * f * 2.3 * t) * np.exp(-t / 0.01)
    x += 0.3 * bp(noise(d), 800, 3000) * np.exp(-t / 0.006)
    return x * attack_env(len(t), 0.0005)


def riser(d, f0=300, f1=6000, gain_pow=2.0):
    """Yukselen gurultu 'whoosh' (zamanla acilan lowpass)."""
    t = T(d)
    cut = f0 * (f1 / f0) ** (t / d)
    x = lp(hp(noise(d), 200), cut, 2)
    return x * (t / d) ** gain_pow


def sparkle(d, notes, count, t0=0.0, spread=None, gain=0.25, seed=3):
    """Rastgele zamanli kucuk para/zil pirildilari (pentatonik notalardan)."""
    r = np.random.default_rng(seed)
    out = buf(d)
    spread = spread if spread is not None else d - t0 - 0.3
    for i in range(count):
        at = t0 + spread * (i / max(1, count - 1)) ** 1.3 + r.uniform(-0.02, 0.02)
        f = nf(notes[r.integers(len(notes))])
        g = gain * (1.0 - 0.6 * i / max(1, count))
        place(out, chime(f, 0.5, 0.18), max(0.0, at), g * r.uniform(0.6, 1.0))
    return out


def pad(freqs, d, attack=0.4, release=0.6, cutoff=2400, vib=5.0, detune=0.006):
    """Koro/yay pad: detune'lu testereler + vibrato + yumusak lowpass."""
    t = T(d)
    out = np.zeros(len(t))
    for f in freqs:
        for dt in (-detune, 0.0, detune):
            fr = f * (1 + dt) * (1 + 0.004 * np.sin(2 * np.pi * vib * t + RNG.uniform(0, 6)))
            out += saw(fr, d, 12)
    env = np.minimum(1.0, t / attack) * np.minimum(1.0, (d - t) / release)
    return lp(out * np.clip(env, 0, 1), cutoff, 2) / (3 * len(freqs))


# ------------------------------------------------------------------ uzay (reverb) + stereo

def _comb(x, D, g):
    y = x.copy()
    s = D
    while s < len(y):
        e = min(s + D, len(y))
        y[s:e] += g * y[s - D:e - D]
        s = e
    return y


def _allpass(x, D, g):
    y = np.zeros_like(x)
    s = 0
    while s < len(x):
        e = min(s + D, len(x))
        xd = x[s - D:e - D] if s >= D else np.zeros(e - s)
        yd = y[s - D:e - D] if s >= D else np.zeros(e - s)
        y[s:e] = -g * x[s:e] + xd + g * yd
        s = e
    return y


def reverb(x, rt60=1.2, wet=0.25, tail=1.0, damp=5000, spread=1.0):
    """Schroeder reverb, L/R farkli gecikmeler = genis, ASMR 'oda' hissi. Girdi mono, cikti (n,2)."""
    xx = np.concatenate([x, np.zeros(N(tail))])
    chans = []
    for side, mul in ((0, 1.0), (1, 1.0 + 0.031 * spread)):
        acc = np.zeros_like(xx)
        for ms in (29.7, 37.1, 41.1, 43.7):
            D = int(SR * ms * mul / 1000.0)
            g = 10 ** (-3 * D / (rt60 * SR))
            acc += _comb(xx, D, g)
        acc = _allpass(acc, int(SR * 0.005 * mul), 0.7)
        acc = _allpass(acc, int(SR * 0.0017 * mul), 0.7)
        acc = lp(acc, damp, 1) * 0.25
        chans.append(acc)
    dry = np.stack([xx, xx], axis=1)
    return dry * (1 - wet * 0.5) + np.stack(chans, axis=1) * wet


def pan(x, p):
    """p: -1 sol .. +1 sag (esit guc)."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1) * 1.414


def finish(st, target_rms=0.11, peak=0.89, end_fade=0.08):
    if st.ndim == 1:
        st = np.stack([st, st], axis=1)
    for c in range(2):
        st[:, c] = hp(st[:, c], 28)
    # sondaki sessizligi kirp
    mag = np.max(np.abs(st), axis=1)
    thr = np.max(mag) * 10 ** (-58 / 20)
    idx = np.nonzero(mag > thr)[0]
    if len(idx):
        st = st[:idx[-1] + N(0.02)]
    st[:N(0.002)] *= np.linspace(0, 1, N(0.002))[:, None]
    k = min(len(st), N(end_fade))
    st[-k:] *= (np.linspace(1, 0, k) ** 2)[:, None]
    act = mag[mag > np.max(mag) * 0.05]
    rms = np.sqrt(np.mean(st[:len(act)] ** 2)) + 1e-9 if len(act) else 1.0
    g = min(target_rms / rms, peak / (np.max(np.abs(st)) + 1e-9))
    return st * g


def write(name, st):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(st, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("%-28s %.2fs peak %.2f" % (name, len(st) / SR, np.max(np.abs(st))))


# ------------------------------------------------------------------ sesler

def mission_warn_A():
    # Haber zili: iki parlak can (A5 -> E6) + altinda yukselen yumusak gerilim
    d = 1.3
    x = buf(d)
    place(x, bell(nf("A5"), 1.0, 0.45, 3.5, 1.4), 0.0, 0.8)
    place(x, bell(nf("E6"), 1.0, 0.5, 3.5, 1.4), 0.17, 0.8)
    place(x, riser(0.9, 400, 3500, 2.5), 0.25, 0.10)
    return finish(reverb(x, 1.4, 0.32, 1.0), 0.10)


def mission_warn_B():
    # Iki tok davul + yukari marimba uclusu ("hazir ol")
    d = 1.1
    x = buf(d)
    place(x, thump(140, 60, 0.5, 0.16), 0.0, 0.9)
    place(x, thump(140, 60, 0.5, 0.16), 0.19, 0.75)
    for i, n in enumerate(("D5", "F#5", "A5")):
        place(x, marimba(nf(n), 0.6, 0.2), 0.42 + i * 0.09, 0.55)
    return finish(reverb(x, 1.0, 0.25, 0.8), 0.11)


def mission_start_A():
    # Hucum: whoosh -> gogse vuran darbe + parlak majör akor (pluck) + pirilti
    d = 1.5
    x = buf(d)
    place(x, riser(0.32, 300, 7000, 2.2), 0.0, 0.22)
    hit = 0.32
    place(x, thump(110, 45, 0.6, 0.2), hit, 1.0)
    place(x, hp(noise(0.08), 1500) * dec(0.08, 0.02), hit, 0.18)
    for n in ("C5", "E5", "G5", "C6"):
        place(x, pluck(nf(n), 1.0, 0.75, 0.997), hit + 0.005, 0.32)
    place(x, sparkle(1.2, ["C7", "E7", "G7", "D7"], 5, 0.05, 0.4, 0.12), hit, 1.0)
    return finish(reverb(x, 1.3, 0.3, 1.0), 0.13)


def mission_start_B():
    # Boru cagrisi: G4 -> C5 kayan 'bwaa' (testere, acilan filtre) + trampet
    d = 1.4
    t = T(d)
    f = np.where(t < 0.16, nf("G4"), nf("C5") + (nf("G4") - nf("C5")) * np.exp(-(t - 0.16) / 0.025))
    f = f * (1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.4) / 0.3, 0, 1))
    horn = saw(f, d, 20)
    env = np.minimum(1, t / 0.03) * np.where(t < 0.13, 1.0, 1.0) * np.clip((1.15 - t) / 0.5, 0, 1)
    env[(t > 0.13) & (t < 0.17)] *= 0.55
    cut = 700 + 2600 * np.clip(t / 0.08, 0, 1) * np.exp(-np.maximum(0, t - 0.2) / 0.6)
    x = lp(horn * env, cut, 2) * 0.9
    sn = bp(noise(0.2), 900, 6000) * dec(0.2, 0.05)
    place(x, sn, 0.0, 0.25)
    place(x, sn, 0.16, 0.3)
    place(x, thump(120, 55, 0.4, 0.15), 0.16, 0.6)
    return finish(reverb(x, 1.2, 0.28, 0.9), 0.12)


def mission_success_A():
    # Hazine fanfari: hizli marimba/can arpeji -> asili majör pad + para piriltisi kuyrugu
    d = 2.4
    x = buf(d)
    notes = ("C5", "E5", "G5", "C6", "E6")
    for i, n in enumerate(notes):
        place(x, marimba(nf(n), 0.7, 0.25), i * 0.065, 0.55)
        place(x, chime(nf(n) * 2, 0.6, 0.25), i * 0.065, 0.12)
    top = 5 * 0.065
    place(x, bell(nf("C6"), 1.8, 0.8, 3.5, 1.2, 0.35), top, 0.55)
    place(x, bell(nf("G6"), 1.6, 0.6, 3.5, 1.0, 0.3), top + 0.01, 0.3)
    place(x, pad([nf("C5"), nf("E5"), nf("G5"), nf("C6")], 1.7, 0.08, 1.0, 3200), top, 0.9)
    place(x, sparkle(1.9, ["C7", "D7", "E7", "G7", "A7"], 12, 0.0, 1.3, 0.14, 11), top, 1.0)
    return finish(reverb(x, 1.8, 0.33, 1.2), 0.12)


def mission_success_B():
    # Altin yagmuru: yukselen pluck arpeji + para selalesi + buyuk final can (oktav)
    d = 2.2
    x = buf(d)
    seq = ("G4", "C5", "E5", "G5", "C6", "E6", "G6")
    for i, n in enumerate(seq):
        place(x, pluck(nf(n), 0.6, 0.8, 0.996), i * 0.05, 0.45)
    top = len(seq) * 0.05
    r = np.random.default_rng(5)
    for i in range(16):
        at = top + 0.9 * (i / 15) ** 1.6
        place(x, coin(r.uniform(2400, 4200), 0.4, 0.2), at, 0.16 * (1 - 0.5 * i / 16))
    place(x, bell(nf("C6"), 1.6, 0.9, 1.41, 1.0, 0.4), top, 0.7)
    place(x, bell(nf("C7"), 1.4, 0.6, 1.41, 0.8, 0.3), top + 0.005, 0.3)
    return finish(reverb(x, 1.6, 0.3, 1.1), 0.12)


def mission_fail_A():
    # Sonen boru: "wah wah wah wahhh" (kisik trompet, inen yarim tonlar, son nota titresimli)
    d = 2.0
    x = buf(d)
    seq = (("G4", 0.0, 0.26), ("F#4", 0.3, 0.26), ("F4", 0.6, 0.26), ("E4", 0.9, 0.95))
    for n, at, ln in seq:
        t = T(ln)
        f = nf(n) * (1 + (0.012 * np.sin(2 * np.pi * 6 * t) * np.clip((t - 0.15) / 0.2, 0, 1) if ln > 0.5 else 0))
        s = saw(f, ln, 16)
        env = np.minimum(1, t / 0.03) * np.clip((ln - t) / 0.12, 0, 1)
        wah = 500 + 1300 * np.sin(np.pi * np.clip(t / min(ln, 0.3), 0, 1)) ** 2
        if ln > 0.5:
            wah = 500 + 900 * (0.5 + 0.5 * np.sin(2 * np.pi * 3 * t)) * np.exp(-t / 0.6)
        place(x, lp(s * env, wah, 2), at, 0.8)
    return finish(reverb(x, 1.0, 0.22, 0.8), 0.10)


def mission_fail_B():
    # Kirik can: kisik minör can ikilisi asagi kayar + yumusak tok darbe
    d = 1.8
    x = buf(d)
    place(x, thump(90, 40, 0.6, 0.22), 0.0, 0.7)
    place(x, bell(nf("A4"), 1.4, 0.55, 2.0, 1.2, 0.15), 0.0, 0.45)
    place(x, bell(nf("C5"), 1.4, 0.55, 2.0, 1.2, 0.15), 0.0, 0.35)
    place(x, bell(nf("G#4"), 1.4, 0.6, 2.0, 1.0, 0.15), 0.38, 0.45)
    place(x, bell(nf("B4"), 1.4, 0.6, 2.0, 1.0, 0.15), 0.38, 0.3)
    x = lp(x, 2800, 1)
    return finish(reverb(x, 1.5, 0.3, 1.0), 0.10)


def shop_bell(f=2200, d=0.7, shakes=3, gap=0.055):
    """Dukkan kapisi zili: kucuk pirinc zilin birkac kez sallanmasi."""
    x = buf(d)
    for i in range(shakes):
        g = 1.0 - 0.25 * i
        place(x, bell(f * (1 + 0.01 * (i % 2)), d, 0.25, 2.76, 0.8, 0.25), i * gap, g)
        place(x, bell(f * 1.5, d, 0.18, 2.76, 0.6, 0.2), i * gap + 0.012, 0.35 * g)
    return x


def merchant_arrive_A():
    # Dukkan kapi zili (iki sallanma) + kucuk para sikirtisi
    d = 1.3
    x = buf(d)
    place(x, shop_bell(2093, 0.9, 3), 0.0, 0.6)
    place(x, shop_bell(2349, 0.9, 2), 0.22, 0.5)
    r = np.random.default_rng(9)
    for i in range(6):
        place(x, coin(r.uniform(2600, 3800), 0.35, 0.16), 0.32 + i * 0.04 + r.uniform(0, 0.02), 0.13)
    return finish(reverb(x, 1.1, 0.26, 0.9), 0.10)


def merchant_arrive_B():
    # Tuccar melodisi: neseli "ta-da-da-DING" pluck + kapanista para
    d = 1.4
    x = buf(d)
    for i, (n, g) in enumerate((("G5", 0.45), ("C6", 0.45), ("E6", 0.45))):
        place(x, pluck(nf(n), 0.5, 0.7), i * 0.09, g)
    place(x, bell(nf("G6"), 1.1, 0.5, 3.5, 1.0, 0.3), 0.29, 0.5)
    place(x, pluck(nf("G6"), 0.6, 0.7), 0.29, 0.3)
    place(x, coin(3500, 0.4, 0.2), 0.33, 0.12)
    place(x, coin(4100, 0.4, 0.2), 0.39, 0.1)
    return finish(reverb(x, 1.1, 0.27, 0.9), 0.10)


def merchant_leave_A():
    # Ayni zil, inen ve daha yumusak + kapanan ahsap kapi 'tok'
    d = 1.2
    x = buf(d)
    place(x, shop_bell(2349, 0.8, 2, 0.07), 0.0, 0.45)
    place(x, shop_bell(1760, 0.8, 2, 0.07), 0.2, 0.4)
    place(x, woodblock(260, 0.15), 0.45, 0.6)
    place(x, thump(120, 70, 0.25, 0.06), 0.45, 0.4)
    x = lp(x, 5000, 1)
    return finish(reverb(x, 1.0, 0.25, 0.8), 0.085)


def merchant_leave_B():
    # Melodinin tersi, inen, sonen
    d = 1.4
    x = buf(d)
    for i, (n, g) in enumerate((("G6", 0.35), ("E6", 0.33), ("C6", 0.31), ("G5", 0.4))):
        place(x, pluck(nf(n), 0.7, 0.5), i * 0.11, g)
    place(x, bell(nf("G5"), 1.0, 0.45, 3.5, 0.8, 0.2), 0.33, 0.25)
    x = lp(x, 4500, 1)
    return finish(reverb(x, 1.2, 0.28, 0.9), 0.085)


def shop_open_A():
    # Sandik kapagi: tok ahsap 'thock' + iki paralik 'cha-ching'
    d = 0.75
    x = buf(d)
    place(x, woodblock(380, 0.14), 0.0, 0.8)
    place(x, thump(200, 110, 0.15, 0.04), 0.0, 0.5)
    place(x, coin(3100, 0.5, 0.22), 0.07, 0.3)
    place(x, coin(3950, 0.5, 0.25), 0.12, 0.28)
    place(x, chime(nf("E7"), 0.5, 0.2), 0.12, 0.08)
    return finish(reverb(x, 0.8, 0.2, 0.6), 0.10)


def shop_open_B():
    # Kumas/kagit hisirtisi + tek kucuk zil
    d = 0.7
    x = buf(d)
    t = T(0.18)
    rustle = bp(noise(0.18), 1500, 7000) * np.sin(np.pi * t / 0.18) ** 1.5
    rustle *= 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 23 * t))
    place(x, rustle, 0.0, 0.35)
    place(x, bell(nf("A6"), 0.6, 0.28, 3.5, 0.9, 0.3), 0.12, 0.45)
    place(x, chime(nf("E7"), 0.5, 0.2), 0.13, 0.1)
    return finish(reverb(x, 0.8, 0.2, 0.6), 0.09)


def taiko(d=0.9, f0=95, f1=38, tau=0.35):
    x = thump(f0, f1, d, tau, 0.06)
    x += 0.35 * lp(noise(d), 900, 2) * dec(d, 0.05)
    x += 0.15 * bp(noise(d), 1500, 5000) * dec(d, 0.01)
    return x


def boss_A():
    # Savas davullari: 3 agir vurus + acilan alcak bakir drone + gok gurultusu
    d = 3.0
    x = buf(d)
    for i, g in enumerate((0.8, 0.85, 1.0)):
        place(x, taiko(1.0), i * 0.36, g)
    t = T(2.6)
    drone = saw(nf("D2") * (1 + 0.003 * np.sin(2 * np.pi * 0.7 * t)), 2.6, 30) + saw(nf("A2") * 1.002, 2.6, 30) * 0.7 + saw(nf("D3") * 0.998, 2.6, 30) * 0.4
    cut = 150 + 1200 * np.clip((t - 0.2) / 1.2, 0, 1) ** 1.5
    env = np.clip(t / 0.9, 0, 1) * np.clip((2.6 - t) / 1.0, 0, 1)
    place(x, lp(drone * env, cut, 2), 0.3, 0.55)
    rumble = lp(noise(2.6), 120, 3) * np.clip(t / 1.2, 0, 1) * np.clip((2.6 - t) / 1.0, 0, 1)
    place(x, rumble, 0.3, 1.2)
    st = reverb(x, 2.0, 0.3, 1.2, 3000)
    return finish(np.tanh(st * 1.4) / 1.4, 0.15)


def boss_B():
    # Ugursuz gong: buyuk, harmonik olmayan, titreyen alcak gong + derin dusus
    d = 3.2
    t = T(d)
    f = 98.0
    x = np.zeros(len(t))
    for r, a, tau in ((1.0, 1.0, 1.6), (1.52, 0.7, 1.2), (2.03, 0.55, 1.0), (2.61, 0.45, 0.8), (3.47, 0.35, 0.6), (4.79, 0.25, 0.4), (6.1, 0.15, 0.3)):
        wob = 1 + 0.004 * np.sin(2 * np.pi * (0.9 + r * 0.3) * t)
        swell = 1 - 0.6 * np.exp(-t / 0.15) if r > 2 else 1.0  # tiz kismi sesler gec acilir (gong 'bloom')
        x += a * np.sin(phase_of(f * r * wob, len(t))) * np.exp(-t / tau) * swell
    x *= attack_env(len(t), 0.004)
    x += 0.4 * bp(noise(d), 300, 3000) * dec(d, 0.04)
    place(x, thump(70, 28, 1.5, 0.6, 0.3), 0.0, 0.9)
    fade_out(x, 0.6)
    st = reverb(x, 2.4, 0.3, 1.0, 3500)
    return finish(np.tanh(st * 1.3) / 1.3, 0.15)


def gold_gift_A():
    # Para selalesi: hizlanan sonra seyrelen ~14 para (stereo dagilimli) + final 'bling'
    d = 1.5
    st = np.zeros((N(d), 2))
    r = np.random.default_rng(21)
    times = np.cumsum(np.concatenate([[0.0], 0.075 * np.exp(-np.arange(13) / 4.0) + 0.018]))
    for i, at in enumerate(times):
        c = pan(coin(r.uniform(2300, 4300), 0.45, 0.2), r.uniform(-0.7, 0.7))
        place(st, c, at, 0.22 * (0.7 + 0.3 * r.random()))
    end = times[-1] + 0.06
    bl = np.zeros(N(1.0))
    place(bl, bell(nf("C7"), 1.0, 0.45, 1.41, 0.9, 0.3), 0.0, 0.45)
    place(bl, bell(nf("E7"), 1.0, 0.45, 1.41, 0.9, 0.3), 0.06, 0.38)
    place(bl, bell(nf("G7"), 1.0, 0.4, 1.41, 0.9, 0.3), 0.12, 0.3)
    place(st, np.stack([bl, bl], axis=1), end, 1.0)
    mono = st.mean(axis=1)
    wet = reverb(mono, 1.1, 0.25, 0.7)
    wet[:len(st)] += st * 0.6
    return finish(wet, 0.11)


def gold_gift_B():
    # Kese: bir avuc para birden 'shink' + hizli yukselen pirilti arpeji
    d = 1.3
    x = buf(d)
    r = np.random.default_rng(4)
    for i in range(9):
        place(x, coin(r.uniform(2000, 4500), 0.4, 0.16), r.uniform(0, 0.06), 0.18)
    place(x, bp(noise(0.08), 3000, 9000) * dec(0.08, 0.015), 0.0, 0.25)
    for i, n in enumerate(("C6", "E6", "G6", "C7", "E7")):
        place(x, chime(nf(n), 0.6, 0.3), 0.14 + i * 0.045, 0.32)
    return finish(reverb(x, 1.2, 0.28, 0.8), 0.11)


def chat_A():
    # Baloncuk pop: hizli yukari kayan sinus + ikinci kucuk pop
    d = 0.32
    x = buf(d)
    for at, f0, f1, g in ((0.0, 380, 950, 0.9), (0.075, 600, 1400, 0.6)):
        t = T(0.09)
        f = f0 + (f1 - f0) * (1 - np.exp(-t / 0.02))
        place(x, np.sin(phase_of(f, len(t))) * np.exp(-t / 0.025) * attack_env(len(t), 0.001), at, g)
    return finish(reverb(x, 0.5, 0.15, 0.3), 0.10)


def chat_B():
    # Iki yumusak marimba notasi (E6 -> A6)
    d = 0.45
    x = buf(d)
    place(x, marimba(nf("E6"), 0.35, 0.09), 0.0, 0.7)
    place(x, marimba(nf("A6"), 0.35, 0.11), 0.08, 0.7)
    return finish(reverb(x, 0.6, 0.18, 0.35), 0.09)


def ally_down_A():
    # Uzak can: kisik, alcak can iki kez calar (minör kisimli)
    d = 2.0
    x = buf(d)
    place(x, bell(nf("C4"), 1.6, 0.7, 2.4, 1.4, 0.1), 0.0, 0.7)
    place(x, bell(nf("D#4"), 1.6, 0.6, 2.4, 1.0, 0.1), 0.0, 0.25)
    place(x, bell(nf("C4"), 1.6, 0.6, 2.4, 1.2, 0.1), 0.5, 0.45)
    x = lp(x, 2000, 1)
    return finish(reverb(x, 1.8, 0.35, 1.2), 0.10)


def ally_down_B():
    # Huzunlu ikili: inen minör tersi (E5 -> C5) pluck + yumusak tok darbe
    d = 1.5
    x = buf(d)
    place(x, thump(100, 50, 0.4, 0.14), 0.0, 0.6)
    place(x, pluck(nf("E5"), 0.9, 0.4), 0.0, 0.5)
    place(x, pluck(nf("C5"), 1.0, 0.35), 0.24, 0.55)
    place(x, pluck(nf("A4"), 1.0, 0.35), 0.24, 0.3)
    x = lp(x, 3500, 1)
    return finish(reverb(x, 1.4, 0.3, 1.0), 0.10)


def self_down_A():
    # Kalp atisi (lub-dub) + inen sinus + kapanan filtre (bilinc kaybi)
    d = 2.2
    x = buf(d)
    for at, g in ((0.0, 1.0), (0.17, 0.7), (0.85, 0.7), (1.02, 0.45)):
        place(x, thump(75, 42, 0.35, 0.09, 0.03, 0.006), at, g)
    t = T(1.6)
    f = 520 * (150 / 520) ** (t / 1.6)
    tone = np.sin(phase_of(f, len(t))) + 0.4 * np.sin(phase_of(f * 1.5, len(t)))
    tone *= np.clip(t / 0.05, 0, 1) * np.clip((1.6 - t) / 0.8, 0, 1)
    place(x, lp(tone, 2500 * np.exp(-t / 0.6) + 150, 2), 0.05, 0.35)
    return finish(reverb(x, 1.6, 0.3, 1.1, 2500), 0.11)


def self_down_B():
    # Agir dusus: tok darbe + uyumsuz, inen minör pad, boguklasarak soner
    d = 2.2
    x = buf(d)
    place(x, taiko(0.8, 85, 35, 0.3), 0.0, 0.9)
    t = T(1.9)
    bend = 1 - 0.06 * (t / 1.9) ** 1.5
    p = pad([nf("A3") * 1.0, nf("C4"), nf("D#4"), nf("A4")], 1.9, 0.05, 1.2, 1800, 4.0, 0.009)
    p = p * bend[:len(p)] ** 0  # (perde egrisi pad icinde yok; dusus hissi filtreden geliyor)
    place(x, lp(p, 1600 * np.exp(-t / 0.7) + 180, 1), 0.02, 1.0)
    return finish(reverb(x, 1.7, 0.3, 1.1, 2600), 0.11)


def revive_A():
    # Melek nefesi: yukari arp glisando (pentatonik) + koro pad acilisi + tepe can + pirilti
    d = 2.6
    x = buf(d)
    gl = ("C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6", "G6", "A6", "C7")
    for i, n in enumerate(gl):
        place(x, pluck(nf(n), 0.9, 0.6, 0.997), i * 0.042, 0.26 + 0.02 * i)
    top = len(gl) * 0.042
    place(x, pad([nf("C4"), nf("G4"), nf("C5"), nf("E5"), nf("G5")], 2.0, 0.35, 1.1, 2800, 5.0, 0.007), 0.05, 1.3)
    place(x, bell(nf("C7"), 1.6, 0.7, 1.41, 0.9, 0.3), top, 0.45)
    place(x, bell(nf("G6"), 1.6, 0.7, 1.41, 0.9, 0.3), top + 0.01, 0.3)
    place(x, sparkle(1.6, ["C7", "E7", "G7", "A7", "D7"], 10, 0.0, 1.0, 0.11, 17), top, 1.0)
    return finish(reverb(x, 2.0, 0.36, 1.3), 0.12)


def revive_B():
    # Yeniden dogus: ters can sisligi (emme) -> parlak kristal akor + pirilti
    d = 2.3
    x = buf(d)
    sw = bell(nf("C6"), 0.7, 0.3, 3.5, 1.2, 0.3)[::-1] * np.linspace(0, 1, N(0.7)) ** 2
    place(x, sw, 0.0, 0.5)
    place(x, riser(0.7, 500, 9000, 3.0), 0.0, 0.12)
    hit = 0.7
    for n, g in (("C6", 0.5), ("E6", 0.42), ("G6", 0.38), ("C7", 0.3)):
        place(x, chime(nf(n), 1.5, 0.7), hit, g)
    place(x, thump(160, 80, 0.3, 0.08), hit, 0.35)
    place(x, sparkle(1.5, ["C7", "E7", "G7", "B7"], 9, 0.02, 0.9, 0.11, 23), hit, 1.0)
    return finish(reverb(x, 1.9, 0.34, 1.2), 0.12)


SOUNDS = {
    "mission_warn_A": mission_warn_A, "mission_warn_B": mission_warn_B,
    "mission_start_A": mission_start_A, "mission_start_B": mission_start_B,
    "mission_success_A": mission_success_A, "mission_success_B": mission_success_B,
    "mission_fail_A": mission_fail_A, "mission_fail_B": mission_fail_B,
    "merchant_arrive_A": merchant_arrive_A, "merchant_arrive_B": merchant_arrive_B,
    "merchant_leave_A": merchant_leave_A, "merchant_leave_B": merchant_leave_B,
    "shop_open_A": shop_open_A, "shop_open_B": shop_open_B,
    "boss_A": boss_A, "boss_B": boss_B,
    "gold_gift_A": gold_gift_A, "gold_gift_B": gold_gift_B,
    "chat_A": chat_A, "chat_B": chat_B,
    "ally_down_A": ally_down_A, "ally_down_B": ally_down_B,
    "self_down_A": self_down_A, "self_down_B": self_down_B,
    "revive_A": revive_A, "revive_B": revive_B,
}

if __name__ == "__main__":
    import sys
    only = set(sys.argv[1:])
    for name, fn in SOUNDS.items():
        if only and name not in only:
            continue
        write(name, fn())
