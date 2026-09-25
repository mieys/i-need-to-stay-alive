"""Kullanici istegi (2026-09-25): "oyundaki yaratiklarin turlerine bagli olarak olduklerinde fazla dikkat
cekmeyen bir olum sesi ciksin. mesela slime yapiskan bisey patlama sesi gibi, iskelet iskelet yikilma sesi gibi".

Her yaratik AILESI (enemy.gd family_of_id: creature_id'nin rakamsiz kismi) icin kisa (0.15-0.45 sn), yumusak,
alcak tizlikli prosedurel bir olum sesi uretir: assets/audio/creature_death/<aile>_<n>.wav (aile basina 2 varyant,
tekrar hissi olmasin diye). Hepsi "dikkat cekmesin" diye: sert atak yok (min 3-8 ms), ayni RMS'e esitlenip (tepe
en fazla -1 dBFS) oyunda ayrica kisik caliniyor (bkz. scripts/creature_death_sound.gd VOLUME_DB), tiz uclar lowpass'li.

Calistir: python tools/gen_creature_death_sounds.py
Sonra Godot editorune donunce .wav.import dosyalari otomatik olusur (ya da --headless --import).
"""

import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "creature_death")


# ---------------------------------------------------------------- yardimcilar

def n_of(sec):
    return int(SR * sec)


def t_axis(sec):
    return np.arange(n_of(sec)) / SR


def env(n, attack=0.005, decay_pow=2.0):
    e = np.ones(n)
    a = max(1, n_of(attack))
    a = min(a, n - 1)
    e[:a] = np.linspace(0, 1, a) ** 0.7
    e[a:] = np.linspace(1, 0, n - a) ** decay_pow
    return e


def onepole_lp(x, cutoff):
    """Tek kutuplu lowpass; cutoff sabit ya da ornek basina dizi olabilir."""
    cut = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), x.shape)
    a = 1.0 - np.exp(-2 * np.pi * cut / SR)
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


def bandpass(x, center, q=4.0):
    """Durum-degiskenli (Chamberlin) bandpass; center sabit ya da dizi."""
    c = np.broadcast_to(np.asarray(center, dtype=np.float64), x.shape)
    f = 2 * np.sin(np.pi * np.minimum(c, SR / 6) / SR)
    damp = 1.0 / q
    low = band = 0.0
    y = np.empty_like(x)
    for i in range(len(x)):
        high = x[i] - low - damp * band
        band += f[i] * high
        low += f[i] * band
        y[i] = band
    return y


def osc(freq, kind="sine"):
    """freq: ornek basina Hz dizisi."""
    ph = 2 * np.pi * np.cumsum(freq) / SR
    if kind == "sine":
        return np.sin(ph)
    if kind == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    if kind == "tri":
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1.0) - 1) - 1
    raise ValueError(kind)


def place(buf, x, at_sec, gain=1.0):
    i = n_of(at_sec)
    j = min(len(buf), i + len(x))
    if i < len(buf):
        buf[i:j] += x[: j - i] * gain


def click(rng, center, length=0.025, q=6.0, decay=3.0):
    """Kisa rezonansli 'tik' (kemik/tas/tahta carpmasi)."""
    n = n_of(length)
    x = rng.standard_normal(n) * env(n, 0.001, decay)
    return bandpass(x, center, q)


def bubble(freq0, length, rise=1.6, rng=None):
    """Su/balcik kabarcigi: yukari kayan sinus + hizli sonum (klasik 'blup')."""
    n = n_of(length)
    t = np.arange(n) / SR
    f = freq0 * (1 + (rise - 1) * (t / length))
    return osc(f) * env(n, 0.004, 2.5)


TARGET_RMS = 0.13  # aileler arasi algilanan yukseklik esit olsun (tepe normalizasyonu demon'u ~12 dB baskin birakiyordu)


def save(name, x, peak_db=-1.0):
    x = np.asarray(x, dtype=np.float64)
    x = x - np.mean(x)
    rms = np.sqrt(np.mean(x ** 2)) or 1.0
    x = x * (TARGET_RMS / rms)
    peak_max = 10 ** (peak_db / 20)
    peak = np.max(np.abs(x))
    if peak > peak_max:
        x = x * (peak_max / peak)
    f = n_of(0.006)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print("wrote", os.path.normpath(path), f"{len(x) / SR:.2f}s")


# ---------------------------------------------------------------- aileler

def slime(rng):
    """Yapiskan bir seyin patlamasi: yumusak islak 'splot' + ardindan 2-3 kucuk kabarcik."""
    sec = 0.36
    out = np.zeros(n_of(sec))
    n = n_of(0.09)
    splat = lp(rng.standard_normal(n), np.linspace(1800, 300, n)) * env(n, 0.003, 1.6)
    place(out, splat, 0.0, 1.0)
    place(out, bubble(170 + rng.uniform(-15, 15), 0.08, 1.9), 0.0, 0.7)
    for k in range(3):
        place(out, bubble(rng.uniform(260, 420), rng.uniform(0.03, 0.05), 1.7), 0.07 + k * rng.uniform(0.05, 0.08), 0.35 - k * 0.08)
    return lp(out, 2600, 1)


def iskelet(rng):
    """Kemik yiginina donusme: 6-9 tahta-tiz 'tak'ın hizlanip seyrekleserek dusmesi."""
    sec = 0.45
    out = np.zeros(n_of(sec))
    t = 0.0
    count = rng.integers(6, 10)
    for k in range(count):
        g = 1.0 - k / count * 0.75
        place(out, click(rng, rng.uniform(1300, 2600), 0.03, 8.0, 3.5), t, g)
        place(out, click(rng, rng.uniform(500, 800), 0.04, 5.0, 3.0), t + 0.004, g * 0.5)
        t += rng.uniform(0.025, 0.06) * (1 + k * 0.12)
        if t > sec - 0.05:
            break
    return lp(out, 4200, 1)


def zombie(rng):
    """Kisa, bogulmus inilti + islak cokme."""
    sec = 0.42
    n = n_of(sec)
    t = t_axis(sec)
    f = 120 * np.exp(-t * 1.6) + 55 + 4 * np.sin(2 * np.pi * 7 * t)
    groan = osc(f, "saw")
    groan = bandpass(groan, 520, 3.0) * 0.6 + lp(groan, 700) * 0.6
    groan *= env(n, 0.03, 1.8)
    out = groan
    m = n_of(0.12)
    squish = lp(rng.standard_normal(m), np.linspace(1200, 200, m)) * env(m, 0.004, 1.5)
    place(out, squish, 0.2, 0.55)
    return out


def ork(rng):
    """Alcak 'hrrgh' homurtu + yere yigilma tok sesi."""
    sec = 0.4
    n = n_of(sec)
    t = t_axis(sec)
    f = 105 * np.exp(-t * 1.2) + 60
    g = osc(f, "saw") * (1 + 0.5 * rng.standard_normal(n) * 0.3)
    g = bandpass(g, 380, 2.5) + lp(g, 500) * 0.8
    g *= env(n, 0.02, 2.2)
    out = g * 0.8
    m = n_of(0.14)
    thud = osc(np.linspace(90, 45, m)) * env(m, 0.003, 2.5) + lp(rng.standard_normal(m), 300) * env(m, 0.002, 3.0) * 0.6
    place(out, thud, 0.22, 0.9)
    return out


def rat(rng):
    """Kisa, kisik bir cik + minik dusme."""
    sec = 0.2
    n = n_of(0.1)
    t = np.arange(n) / SR
    f = 1900 + 500 * np.sin(np.pi * t / 0.1) - 900 * t / 0.1
    sq = osc(f) * env(n, 0.006, 1.8)
    out = np.zeros(n_of(sec))
    place(out, sq, 0.0, 0.7)
    m = n_of(0.05)
    place(out, lp(rng.standard_normal(m), 600) * env(m, 0.002, 3.0), 0.09, 0.5)
    return lp(out, 3500, 1)


def lich(rng):
    """Buyulu dagilma: asagi kayan titrek iki ton + havali fisilti."""
    sec = 0.45
    n = n_of(sec)
    t = t_axis(sec)
    base = rng.uniform(420, 480)
    f1 = base * np.exp(-t * 1.4) * (1 + 0.012 * np.sin(2 * np.pi * 9 * t))
    tone = osc(f1) + 0.5 * osc(f1 * 1.5) + 0.25 * osc(f1 * 2.01)
    tone *= env(n, 0.015, 1.8)
    air = bandpass(rng.standard_normal(n), np.linspace(2400, 700, n), 2.0) * env(n, 0.05, 1.4)
    return lp(tone * 0.6 + air * 0.5, 3000, 1)


def agac(rng):
    """Tahta catirdamasi: gicirti (alcak darbeli dizi) + kuru 'crack'."""
    sec = 0.45
    n = n_of(sec)
    t = t_axis(sec)
    rate = 38 + 25 * t / sec
    pulses = np.sin(2 * np.pi * np.cumsum(rate) / SR)
    train = (np.maximum(pulses, 0) ** 12)
    creak = bandpass(train + 0.05 * rng.standard_normal(n), np.linspace(700, 450, n), 7.0) * env(n, 0.04, 1.5)
    out = creak * 1.2
    for k in range(4):
        place(out, click(rng, rng.uniform(900, 1600), 0.05, 3.0, 2.5), 0.12 + k * rng.uniform(0.02, 0.05), 0.7 - k * 0.12)
    m = n_of(0.12)
    place(out, lp(rng.standard_normal(m), 250) * env(m, 0.003, 2.0), 0.28, 0.6)
    return lp(out, 3500, 1)


def bitki(rng):
    """Yaprak hisirtisi + yumusak sap kopmasi."""
    sec = 0.34
    n = n_of(sec)
    t = t_axis(sec)
    flutter = 0.55 + 0.45 * np.sin(2 * np.pi * rng.uniform(22, 30) * t) ** 2
    rustle = bandpass(rng.standard_normal(n), 2600, 1.5) * flutter * env(n, 0.03, 1.6)
    out = rustle * 0.6
    place(out, click(rng, 1100, 0.04, 4.0, 2.2), 0.02, 0.9)
    m = n_of(0.07)
    place(out, bubble(210, 0.07, 0.6), 0.03, 0.4)
    return lp(out, 4500, 1)


def golem(rng):
    """Tas ufalanmasi: tok gumbur + seyrek cakil catirtisi."""
    sec = 0.48
    n = n_of(sec)
    t = t_axis(sec)
    boom = osc(70 * np.exp(-t * 2.0) + 35) * env(n, 0.006, 3.0)
    rumble = lp(rng.standard_normal(n), 180) * env(n, 0.01, 1.8)
    out = boom * 0.8 + rumble * 1.4
    count = rng.integers(10, 16)
    for _ in range(count):
        at = rng.uniform(0.03, sec - 0.06)
        place(out, click(rng, rng.uniform(700, 1800), 0.02, 5.0, 3.0), at, rng.uniform(0.15, 0.4) * (1 - at / sec))
    return lp(out, 2800, 1)


def mantar(rng):
    """Spor 'puf'u: yumusak sisen hava + alcak pop."""
    sec = 0.38
    n = n_of(sec)
    puff = bandpass(rng.standard_normal(n), np.linspace(900, 2200, n), 1.2) * env(n, 0.06, 2.2)
    out = puff * 0.7
    place(out, bubble(140, 0.07, 1.4), 0.0, 0.7)
    return lp(out, 3000, 1)


def demon(rng):
    """Alcak, hafif distorsiyonlu hirlama sonumu + ates cizirtisi."""
    sec = 0.45
    n = n_of(sec)
    t = t_axis(sec)
    f = 85 * np.exp(-t * 1.5) + 45 + 6 * rng.standard_normal(n).cumsum() / np.sqrt(np.arange(1, n + 1)) * 0.2
    g = np.tanh(2.5 * osc(f, "saw"))
    g = lp(g, 650) * env(n, 0.02, 1.9)
    sizzle = hp(rng.standard_normal(n), 3000) * env(n, 0.05, 1.3) * (0.5 + 0.5 * np.sign(rng.standard_normal(n)) * 0.3)
    return lp(g * 0.9 + lp(sizzle, 6000) * 0.12, 3500, 1)


def iblis(rng):
    """Kucuk seytan: kisa tiz ciyak + 'fsss' sonme."""
    sec = 0.34
    n = n_of(0.12)
    t = np.arange(n) / SR
    f = 900 + 350 * np.sin(np.pi * t / 0.12) - 400 * t / 0.12
    yelp = np.tanh(1.5 * osc(f, "tri")) * env(n, 0.008, 1.6)
    out = np.zeros(n_of(sec))
    place(out, lp(yelp, 2500), 0.0, 0.7)
    m = n_of(0.24)
    fizz = bandpass(rng.standard_normal(m), np.linspace(3500, 1200, m), 1.5) * env(m, 0.02, 1.4)
    place(out, fizz, 0.08, 0.45)
    return lp(out, 4500, 1)


def hayalet(rng):
    """Hayalet sonmesi: asagi suzulen titrek 'uuuh' + nefes."""
    sec = 0.5
    n = n_of(sec)
    t = t_axis(sec)
    f = rng.uniform(560, 620) * np.exp(-t * 1.1) * (1 + 0.025 * np.sin(2 * np.pi * 6 * t))
    wail = osc(f) + 0.3 * osc(f * 2) + 0.15 * osc(f * 0.5)
    wail *= env(n, 0.06, 1.5)
    breath = bandpass(rng.standard_normal(n), 1500, 1.2) * env(n, 0.08, 1.3)
    return lp(wail * 0.55 + breath * 0.3, 2600, 1)


def vampire(rng):
    """Kan emiciye yakisir: disli bir tislama + kul olup dagilma."""
    sec = 0.4
    n = n_of(sec)
    hiss = bandpass(rng.standard_normal(n), np.linspace(4200, 1800, n), 2.0) * env(n, 0.015, 1.7)
    out = hiss * 0.6
    m = n_of(0.18)
    t = np.arange(m) / SR
    low = osc(220 * np.exp(-t * 4) + 70) * env(m, 0.01, 2.2)
    place(out, low, 0.0, 0.5)
    for _ in range(6):
        at = rng.uniform(0.12, sec - 0.04)
        place(out, click(rng, rng.uniform(2000, 3200), 0.012, 6.0, 3.0), at, rng.uniform(0.08, 0.2))
    return lp(out, 5000, 1)


def rontgen(rng):
    """Goz yaratigi (Beholder): asagi kayan titrek 'vuuu' enerji sonmesi + islak goz 'pop'u."""
    sec = 0.4
    n = n_of(sec)
    t = t_axis(sec)
    f = 700 * np.exp(-t * 4.0) + 120 + 30 * np.sin(2 * np.pi * 18 * t) * np.exp(-t * 3)
    zap = osc(f, "tri") * env(n, 0.006, 2.0)
    out = lp(zap, 1800) * 0.7
    m = n_of(0.08)
    pop = lp(rng.standard_normal(m), np.linspace(1500, 250, m)) * env(m, 0.002, 1.8)
    place(out, pop, 0.0, 0.6)
    place(out, bubble(240, 0.06, 1.8), 0.02, 0.5)
    return out


FAMILIES = {
    "slime": slime, "iskelet": iskelet, "zombie": zombie, "ork": ork, "rat": rat, "lich": lich,
    "agac": agac, "bitki": bitki, "golem": golem, "mantar": mantar, "demon": demon, "iblis": iblis,
    "hayalet": hayalet, "vampire": vampire, "rontgen": rontgen,
}
VARIANTS = 2

if __name__ == "__main__":
    for fam_i, (fam, fn) in enumerate(FAMILIES.items()):
        for v in range(VARIANTS):
            rng = np.random.default_rng(1000 + fam_i * 17 + v)
            save(f"{fam}_{v + 1}.wav", fn(rng))
