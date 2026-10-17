"""Level atlama + kart seçme sesi PROTOTİPLERİ (2026-10-17). Kullanıcı: "şu ankiler yorucu".

Mevcut sesler (assets/audio/level_ekrani.wav 3,3 sn, card_pick.wav 2,75 sn) uzun, ~2 sn plato yapıyor ve seçim
sesinin enerjisinin yarısı 40-50 Hz alt basta; her level atlamada ikisi üst üste biniyor. Adaylar kısa (0,35-1,2 sn),
hızla sönen, 120 Hz altı temiz, 6 kHz üstü yumuşak, mevcutlardan ~3 dB sessiz (K-ağırlıklı anlık ses eşitleme,
sınırlayıcı YOK - tepe aşarsa bütün dosya kısılır). Hepsi Re majör (ekran + seçim üst üste binse de uyumlu).

Level (ekran açılışı): A Sıcak Yükseliş (tokmaklı 4 nota + yumuşak pad kabarması), B Kadife Çan (vibrafon 2 nota +
hafif tok), C Kısa Fanfar (sıcak pirinç kabarması + çan kapağı). Seçim: A Tahta Tık (tahta tık + marimba),
B Yumuşak Pop (baloncuk kayması + 2 nota), C Kadife Onay (keçeli piyano ikilisi + sessiz ışıltı).

Çalıştır: python tools/proto_20261017/ses_proto.py  -> tools/proto_20261017/out/ses/*.wav + rapor.txt
Oyuna bağlı DEĞİL. Seçilen: level -> assets/audio/level_ekrani.wav, seçim -> assets/audio/card_pick.wav (eskiyi yedekle).
"""

import os
import wave

import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out", "ses")
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
TWO_PI = 2.0 * np.pi

# Re majör frekansları
N = {"D3": 146.83, "A3": 220.0, "D4": 293.66, "F#4": 369.99, "A4": 440.0, "D5": 587.33, "F#5": 739.99,
     "A5": 880.0, "D6": 1174.66}


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def fft_filter(x, hp=None, lp=None, hp_order=2, lp_order=2):
    """Sıfır fazlı yumuşak alçak/yüksek geçiren (Butterworth genlik eğrisi)."""
    pad = 4096
    x = np.pad(x, (pad, pad))
    n = len(x)
    X = np.fft.rfft(x)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 1e-3)
    g = np.ones_like(f)
    if hp:
        g *= 1.0 / np.sqrt(1.0 + (hp / f) ** (2 * hp_order))
    if lp:
        g *= 1.0 / np.sqrt(1.0 + (f / lp) ** (2 * lp_order))
    return np.fft.irfft(X * g, n=n)[pad:-pad]


def attack_ramp(x, sec):
    a = max(1, int(SR * sec))
    x[:a] *= 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, a))
    return x


def partial_tone(freq, dur, partials, attack=0.003, phase_seed=0):
    """partials: (oran, genlik, t60) listesi; her kısmi ses kendi hızında söner."""
    t = t_axis(dur)
    rng = np.random.RandomState(phase_seed)
    x = np.zeros_like(t)
    for ratio, amp, t60 in partials:
        x += amp * np.sin(TWO_PI * freq * ratio * t + rng.uniform(0, TWO_PI)) * np.exp(-6.91 * t / t60)
    return attack_ramp(x, attack)


def marimba(freq, dur=0.6):
    x = partial_tone(freq, dur, [(1.0, 1.0, 0.42), (4.0, 0.42, 0.14), (10.08, 0.08, 0.05)], attack=0.0015)
    n_click = int(SR * 0.004)
    click = np.random.RandomState(3).randn(n_click) * np.linspace(1, 0, n_click) ** 2
    x[:n_click] += fft_filter(np.pad(click, (0, 64)), hp=1500, lp=5000)[:n_click] * 0.25
    return x


def vibraphone(freq, dur=1.0):
    return partial_tone(freq, dur, [(1.0, 1.0, 0.8), (4.0, 0.3, 0.4), (10.0, 0.04, 0.15)], attack=0.004)


def felt_piano(freq, dur=0.7, t60=0.8):
    x = partial_tone(freq, dur, [(1.0, 1.0, t60), (2.0, 0.45, t60 * 0.7), (3.0, 0.18, t60 * 0.5),
                                 (4.0, 0.07, t60 * 0.4), (5.0, 0.025, t60 * 0.3)], attack=0.007)
    return fft_filter(x, lp=3800)


def soft_bell(freq, dur=0.8, t60=0.7):
    return partial_tone(freq, dur, [(1.0, 1.0, t60), (2.0, 0.35, t60 * 0.7), (2.76, 0.22, t60 * 0.55),
                                    (5.4, 0.07, t60 * 0.35)], attack=0.002)


def brass_pad(freqs, dur, attack, hold, release, lp=2400, detune=0.003):
    """Bant sınırlı testere (ek harmonikler) x 2 ses hafif detune; yumuşak kabarma zarfı."""
    t = t_axis(dur)
    x = np.zeros_like(t)
    rng = np.random.RandomState(11)
    for f0 in freqs:
        for d in (1.0 - detune, 1.0 + detune):
            f = f0 * d
            k = 1
            while f * k < 3600 and k <= 16:
                x += np.sin(TWO_PI * f * k * t + rng.uniform(0, TWO_PI)) / k
                k += 1
    n = len(t)
    env = np.zeros(n)
    a = int(SR * attack)
    h = int(SR * hold)
    r = min(n - a - h, int(SR * release))
    env[:a] = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, a))
    env[a:a + h] = 1.0
    env[a + h:a + h + r] = (0.5 + 0.5 * np.cos(np.linspace(0, np.pi, r))) ** 1.3
    x *= env
    return fft_filter(x, lp=lp, lp_order=3) / len(freqs)


def thump(freq_hi, freq_lo, dur=0.09, t60=0.05):
    """Kısa tok vuruş: perdesi düşen sinüs (alt basa inmez)."""
    t = t_axis(dur)
    f = freq_lo + (freq_hi - freq_lo) * np.exp(-t / 0.02)
    ph = np.cumsum(TWO_PI * f / SR)
    return attack_ramp(np.sin(ph) * np.exp(-6.91 * t / t60), 0.001)


def bubble(f0, f1, dur=0.06, t60=0.05):
    t = t_axis(dur)
    f = f0 + (f1 - f0) * (t / dur) ** 0.7
    ph = np.cumsum(TWO_PI * f / SR)
    return attack_ramp(np.sin(ph) * np.exp(-6.91 * t / t60), 0.002)


def air(dur, hp, lp, attack, release, seed=5):
    t = t_axis(dur)
    x = fft_filter(np.random.RandomState(seed).randn(len(t)), hp=hp, lp=lp)
    env = np.minimum(1.0, t / attack) ** 2 * np.exp(-6.91 * np.maximum(0, t - attack) / release)
    return x * env


def reverb(x, t60=0.7, wet_db=-12.0, pre=0.012, lp=4500, seed=1):
    """Küçük oda: sönen gürültü IR (birim enerji) + FFT evrişimi. Çıkış dry + wet (uzunluk kuyruk kadar artar)."""
    n_ir = int(SR * t60 * 1.3)
    t = np.arange(n_ir) / SR
    ir = np.random.RandomState(seed).randn(n_ir) * np.exp(-6.91 * t / t60)
    ir = fft_filter(ir, lp=lp)
    ir = attack_ramp(ir, 0.003)
    ir /= np.sqrt(np.sum(ir ** 2))
    p = int(SR * pre)
    total = len(x) + n_ir + p
    wet = np.fft.irfft(np.fft.rfft(x, n=total) * np.fft.rfft(ir, n=total), n=total)
    out = np.zeros(total)
    out[: len(x)] += x
    out[p:] += wet[: total - p] * (10 ** (wet_db / 20))
    return out


def place(buf, sig, start, gain=1.0):
    s = int(SR * start)
    e = min(len(buf), s + len(sig))
    buf[s:e] += sig[: e - s] * gain


def finish(x, hp=120, lp=9000, tail_db=-60):
    """Alt bas temizliği, tiz yumuşatma, sessiz kuyruğu kırp, son 15 ms sönüm."""
    x = fft_filter(x, hp=hp, lp=lp, hp_order=3, lp_order=2)
    hop = int(SR * 0.01)
    env = np.array([np.sqrt(np.mean(x[i:i + hop] ** 2)) for i in range(0, len(x) - hop, hop)])
    thr = 10 ** (tail_db / 20)
    loud = np.where(env > thr)[0]
    end = min(len(x), (loud[-1] + 2) * hop) if len(loud) else len(x)
    x = x[:end].copy()
    f = int(SR * 0.015)
    x[-f:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, f))
    return x


# ---------- ölçüm ----------
def k_weight(x):
    n = len(x)
    X = np.fft.rfft(x)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 1e-3)
    hp = 1.0 / np.sqrt(1.0 + (38.0 / f) ** 4)
    shelf = 1.0 + (10 ** (4.0 / 20) - 1.0) / (1.0 + (1680.0 / f) ** 4)
    return np.fft.irfft(X * hp * shelf, n=n)


def max_momentary_db(x, win=0.4, hop=0.05):
    y = k_weight(x) ** 2
    w = int(SR * win)
    if len(y) < w:
        y = np.pad(y, (0, w - len(y)))
    c = np.concatenate([[0.0], np.cumsum(y)])
    h = max(1, int(SR * hop))
    vals = [(c[i + w] - c[i]) / w for i in range(0, len(y) - w + 1, h)]
    return 10 * np.log10(max(vals) + 1e-12)


def read_mono(path):
    with wave.open(path, "rb") as w:
        sr = w.getframerate()
        ch = w.getnchannels()
        sw = w.getsampwidth()
        raw = w.readframes(w.getnframes())
    dt = {2: np.int16, 4: np.int32}[sw]
    d = np.frombuffer(raw, dtype=dt).astype(np.float64) / float(2 ** (8 * sw - 1))
    if ch > 1:
        d = d.reshape(-1, ch).mean(axis=1)
    if sr != SR:
        d = np.interp(np.arange(0, len(d), sr / SR), np.arange(len(d)), d)
    return d


def analyze(x, label):
    n = len(x)
    peak = float(np.abs(x).max())
    X = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(n, 1.0 / SR)
    tot = X.sum() + 1e-12
    bands = [(0, 150), (150, 500), (500, 2000), (2000, 5000), (5000, 22050)]
    shares = [100 * X[(f >= a) & (f < b)].sum() / tot for a, b in bands]
    hop = int(SR * 0.02)
    env = np.array([np.sqrt(np.mean(x[i:i + hop] ** 2)) for i in range(0, n - hop, hop)])
    env_db = 20 * np.log10(env + 1e-9)
    pk = env_db.max()
    i_pk = int(env_db.argmax())
    below = np.where(env_db[i_pk:] < pk - 20)[0]
    t20 = (below[0] * hop / SR) if len(below) else n / SR
    jump = float(np.abs(np.diff(x)).max())
    tail = 20 * np.log10(np.sqrt(np.mean(x[-int(SR * 0.01):] ** 2)) + 1e-9)
    return (f"{label:<26} süre {n / SR:5.2f} sn | tepe {peak:.2f} | anlık K {max_momentary_db(x):6.1f} dB | "
            f"tepeden -20 dB'e {t20:4.2f} sn | bant% <150:{shares[0]:4.1f} 150-500:{shares[1]:4.1f} "
            f"500-2k:{shares[2]:4.1f} 2k-5k:{shares[3]:4.1f} 5k+:{shares[4]:4.1f} | son 10 ms {tail:6.1f} dB | "
            f"maks sıçrama {jump:.2f}")


def normalize(x, target_db, peak_cap=0.78):
    cur = max_momentary_db(x)
    g = 10 ** ((target_db - cur) / 20)
    note = ""
    if np.abs(x).max() * g > peak_cap:
        g2 = peak_cap / np.abs(x).max()
        note = f" (tepe sınırı: hedefin {20 * np.log10(g2 / g):.1f} dB altında kaldı)"
        g = g2
    return x * g, note


def save(name, x):
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    return path


# ---------- LEVEL (ekran açılışı) ----------
def level_a():
    """Sıcak Yükseliş: tokmaklı D4 F#4 A4 D5 hızlı çıkış + arkadan yumuşak pad kabarması + hafif hava."""
    buf = np.zeros(int(SR * 1.3))
    for i, (note, g) in enumerate([("D4", 0.7), ("F#4", 0.8), ("A4", 0.9), ("D5", 1.0)]):
        place(buf, marimba(N[note], 0.7), 0.09 * i, g)
    pad = brass_pad([N["D3"], N["A3"], N["D4"], N["F#4"]], 1.1, attack=0.18, hold=0.08, release=0.55, lp=1600)
    place(buf, pad, 0.16, 0.34)
    place(buf, air(0.6, 700, 3200, attack=0.22, release=0.18), 0.0, 0.05)
    return finish(reverb(buf, t60=0.65, wet_db=-13))


def level_b():
    """Kadife Çan: vibrafon A4 -> D5 + ilk notada yumuşak tok vuruş."""
    buf = np.zeros(int(SR * 1.2))
    place(buf, thump(190, 125, dur=0.1, t60=0.06), 0.0, 0.55)
    place(buf, vibraphone(N["A4"], 1.0), 0.0, 0.8)
    place(buf, vibraphone(N["D5"], 1.0), 0.13, 1.0)
    place(buf, vibraphone(N["F#5"], 0.8), 0.13, 0.25)
    return finish(reverb(buf, t60=0.8, wet_db=-11, lp=5000))


def level_c():
    """Kısa Fanfar: sıcak pirinç akoru kabarıp sönüyor + timpani toku + çan kapağı."""
    buf = np.zeros(int(SR * 1.3))
    place(buf, thump(140, 95, dur=0.14, t60=0.09), 0.06, 0.4)
    pad = brass_pad([N["D3"], N["A3"], N["D4"], N["F#4"], N["A4"]], 1.15, attack=0.11, hold=0.14, release=0.6, lp=2300)
    place(buf, pad, 0.0, 0.9)
    place(buf, soft_bell(N["D5"], 0.8, t60=0.55), 0.24, 0.45)
    place(buf, soft_bell(N["A5"], 0.6, t60=0.4), 0.3, 0.18)
    return finish(reverb(buf, t60=0.7, wet_db=-12), hp=130)


# ---------- SEÇİM (kart seçme) ----------
def pick_a():
    """Tahta Tık: tahta tık + sönük tahta rezonansı + kısa marimba D5."""
    buf = np.zeros(int(SR * 0.5))
    n_click = int(SR * 0.003)
    click = np.random.RandomState(9).randn(n_click) * np.linspace(1, 0, n_click)
    place(buf, fft_filter(np.pad(click, (0, 256)), hp=1200, lp=5500), 0.0, 0.5)
    place(buf, partial_tone(680, 0.12, [(1.0, 1.0, 0.07), (2.3, 0.3, 0.04)], attack=0.001), 0.0, 0.45)
    place(buf, marimba(N["D5"], 0.4), 0.012, 0.75)
    return finish(reverb(buf, t60=0.4, wet_db=-18), lp=10000)


def pick_b():
    """Yumuşak Pop: baloncuk kayması + A4 -> D5 iki yumuşak nota."""
    buf = np.zeros(int(SR * 0.55))
    place(buf, bubble(320, 900, dur=0.06, t60=0.05), 0.0, 0.6)
    tone = [(1.0, 1.0, 0.28), (2.0, 0.25, 0.18), (3.0, 0.06, 0.1)]
    place(buf, partial_tone(N["A4"], 0.4, tone, attack=0.004), 0.02, 0.7)
    place(buf, partial_tone(N["D5"], 0.45, tone, attack=0.004), 0.085, 0.85)
    return finish(reverb(buf, t60=0.45, wet_db=-16))


def pick_c():
    """Kadife Onay: keçeli piyano D4+A4 ikilisi + çok sessiz D6 ışıltısı."""
    buf = np.zeros(int(SR * 0.7))
    place(buf, felt_piano(N["D4"], 0.6, t60=0.45), 0.0, 0.8)
    place(buf, felt_piano(N["A4"], 0.6, t60=0.42), 0.004, 0.65)
    place(buf, soft_bell(N["D6"], 0.4, t60=0.25), 0.03, 0.14)
    return finish(reverb(buf, t60=0.5, wet_db=-15, lp=4500), lp=7000)


def main():
    os.makedirs(OUT, exist_ok=True)
    cur_level = read_mono(os.path.join(ROOT, "assets", "audio", "level_ekrani.wav"))
    cur_pick = read_mono(os.path.join(ROOT, "assets", "audio", "card_pick.wav"))
    ref_level = max_momentary_db(cur_level)
    ref_pick = max_momentary_db(cur_pick)
    lines = ["MEVCUT:", analyze(cur_level, "level_ekrani.wav"), analyze(cur_pick, "card_pick.wav"),
             f"hedef: level {ref_level - 3:.1f} dB, seçim {ref_pick - 3:.1f} dB (mevcudun 3 dB altı)", "", "ADAYLAR:"]
    jobs = [("level_A_sicak_yukselis.wav", level_a, ref_level - 3), ("level_B_kadife_can.wav", level_b, ref_level - 3),
            ("level_C_kisa_fanfar.wav", level_c, ref_level - 3), ("secim_A_tahta_tik.wav", pick_a, ref_pick - 3),
            ("secim_B_yumusak_pop.wav", pick_b, ref_pick - 3), ("secim_C_kadife_onay.wav", pick_c, ref_pick - 3)]
    for name, fn, target in jobs:
        x, note = normalize(fn(), target)
        save(name, x)
        lines.append(analyze(x, name) + note)
    report = "\n".join(lines)
    with open(os.path.join(OUT, "rapor.txt"), "w", encoding="utf-8") as fh:
        fh.write(report + "\n")
    print(report)


if __name__ == "__main__":
    main()
