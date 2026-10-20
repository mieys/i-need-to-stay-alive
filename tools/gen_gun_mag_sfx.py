"""Tabanca + Tüfek şarjör sesleri (2026-10-19, kullanıcı: "bunun için ses efektleri de ekle").

Mekanik sesler kısa gürültü darbesiyle uyarılan rezonatörlerle (biquad bant geçiren) kurulur - metal parçaların kendi
çınlaması gibi. Hepsi kısa (0,2-0,3 sn), hızlı söner, 120 Hz altı kesik (tekrarlanan seslerde yorgunluk notu, madde 225).
  gun_mag_out.wav  - mandal tıkı + şarjörün kayarak çıkışı
  gun_mag_in.wav   - şarjörün yerine oturduğu tok "klak" + mandal
  gun_cock.wav     - horoz/sürgü çekme: "çık-çak"
  shell_tink.wav   - pirinç kovanın yere düşüp sektiği ince çınlama
Tüfek aynı dosyaları daha pes çalar (gun_mag_math.gd SOUND_PITCH).
Peak sınırlayıcı/tanh YOK (sadece ölçekleme).

Çalıştır: python tools/gen_gun_mag_sfx.py  (sonra Godot --headless --import)
"""
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "gun")
RNG = np.random.RandomState(19)


def silence(sec):
    return np.zeros(int(SR * sec))


def burst(ms, color="white"):
    n = max(1, int(SR * ms / 1000.0))
    x = RNG.randn(n)
    if color == "pink":
        x = np.cumsum(x) * 0.08 + x * 0.5
    return x * np.hanning(n * 2)[n:] if n > 4 else x


def biquad_bp(x, f, q):
    w0 = 2 * np.pi * f / SR
    alpha = np.sin(w0) / (2 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1 + alpha, -2 * np.cos(w0), 1 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros(len(x))
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        xi = x[i]
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        y[i] = yi
    return y


def highpass(x, f):
    # 2. derece biquad yüksek geçiren
    w0 = 2 * np.pi * f / SR
    q = 0.707
    alpha = np.sin(w0) / (2 * q)
    c = np.cos(w0)
    b0, b1, b2 = (1 + c) / 2, -(1 + c), (1 + c) / 2
    a0, a1, a2 = 1 + alpha, -2 * c, 1 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros(len(x))
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        xi = x[i]
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        y[i] = yi
    return y


def lowpass1(x, f):
    a = 1.0 - np.exp(-2 * np.pi * f / SR)
    y = np.zeros(len(x))
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def ring(excite_ms, modes, length, color="white"):
    """modes: [(frekans, Q, kazanç)] - aynı darbe her rezonatörü uyarır (metal parçanın çınlaması)."""
    x = np.zeros(int(SR * length))
    e = burst(excite_ms, color)
    x[: len(e)] += e
    out = np.zeros_like(x)
    for f, q, g in modes:
        out += biquad_bp(x, f, q) * g
    return out


def modal(freqs, amps, decays_ms, length, detune=1.0):
    t = np.arange(int(SR * length)) / SR
    y = np.zeros_like(t)
    for f, a, d in zip(freqs, amps, decays_ms):
        y += a * np.sin(2 * np.pi * f * detune * t + RNG.rand() * 6.28) * np.exp(-t / (d / 1000.0))
    att = int(SR * 0.0008)
    y[:att] *= np.linspace(0, 1, att)
    return y


def thunk(f0, f1, decay_ms, length):
    t = np.arange(int(SR * length)) / SR
    f = f1 + (f0 - f1) * np.exp(-t / 0.02)
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = np.sin(ph) * np.exp(-t / (decay_ms / 1000.0))
    att = int(SR * 0.001)
    y[:att] *= np.linspace(0, 1, att)
    return y


def place(dst, src, at_sec, gain=1.0):
    # parçanın sonu kesik bitmesin (spektrogramda dikey bant = tık): son %40 / en çok 40 ms kosinüsle söner
    src = np.array(src, dtype=np.float64)
    f = min(int(len(src) * 0.4), int(SR * 0.04))
    if f > 1:
        src[-f:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, f))
    i = int(SR * at_sec)
    n = min(len(src), len(dst) - i)
    if n > 0:
        dst[i:i + n] += src[:n] * gain


def finish(x, peak_db=-3.0, hp=120.0, fade_ms=12.0):
    x = highpass(x, hp)
    f = int(SR * fade_ms / 1000.0)
    x[-f:] *= np.linspace(1, 0, f) ** 2
    s = int(SR * 0.0005)
    x[:s] *= np.linspace(0, 1, s)
    peak = np.max(np.abs(x)) or 1.0
    return x / peak * (10 ** (peak_db / 20.0))


def save(name, x):
    os.makedirs(OUT, exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", os.path.normpath(path), "%.2f s" % (len(x) / SR))


def snd_mag_out():
    L = 0.24
    x = silence(L)
    # mandal: kısa, parlak tık
    place(x, ring(1.2, [(2900, 9, 1.0), (4700, 12, 0.7), (7200, 10, 0.35)], 0.07), 0.0, 1.0)
    # şarjör kayıyor: bant geçiren sürtünme, kabarıp söner
    n = int(SR * 0.13)
    slide = biquad_bp(RNG.randn(n), 2600, 1.4) * 0.5 + biquad_bp(RNG.randn(n), 5200, 2.0) * 0.25
    env = np.sin(np.linspace(0, np.pi, n)) ** 1.6
    place(x, slide * env, 0.018, 0.32)
    # çıkış anında hafif boş metal tınısı
    place(x, modal([1850, 3120, 4410], [0.35, 0.22, 0.12], [45, 30, 22], 0.12), 0.12, 0.45)
    return finish(x, -4.0)


def snd_mag_in():
    L = 0.22
    x = silence(L)
    # tok gövde: kısa inen sinüs + orta frekans vuruş
    place(x, thunk(240, 130, 26, 0.16), 0.0, 0.8)
    place(x, ring(2.0, [(950, 5, 1.0), (1850, 7, 0.8), (3300, 9, 0.45)], 0.1, "pink"), 0.0, 0.9)
    # mandal oturuyor (12 ms sonra)
    place(x, ring(0.9, [(3400, 14, 1.0), (5300, 16, 0.6)], 0.08), 0.013, 0.75)
    place(x, modal([2650, 4020], [0.25, 0.14], [55, 35], 0.12), 0.013, 0.5)
    return finish(x, -3.0)


def snd_cock():
    L = 0.30
    x = silence(L)
    # "çık": sürgü/horoz geri
    place(x, ring(1.4, [(1650, 7, 1.0), (3050, 10, 0.75), (4900, 10, 0.3)], 0.08), 0.0, 0.85)
    # kısa sürtünme
    n = int(SR * 0.06)
    fr = biquad_bp(RNG.randn(n), 3600, 1.8) * np.sin(np.linspace(0, np.pi, n)) ** 2
    place(x, fr, 0.012, 0.22)
    # "çak": ileri kapanış - daha sert, metal çınlama
    place(x, ring(1.0, [(2400, 9, 1.0), (4200, 12, 0.9), (6500, 12, 0.45)], 0.09), 0.085, 1.0)
    place(x, thunk(300, 170, 18, 0.11), 0.085, 0.45)
    place(x, modal([3300, 5150, 7350], [0.3, 0.18, 0.08], [80, 50, 30], 0.2), 0.086, 0.55)
    return finish(x, -3.0)


def snd_shell_tink():
    L = 0.26
    x = silence(L)
    base = [3650, 5370, 7630, 10070]
    amps = [1.0, 0.62, 0.38, 0.18]
    dec = [85, 60, 40, 26]
    for at, g, det, dmul in ((0.0, 1.0, 1.0, 1.0), (0.072, 0.42, 1.03, 0.7), (0.118, 0.18, 0.97, 0.5)):
        place(x, modal(base, amps, [d * dmul for d in dec], 0.15, det), at, g)
        place(x, ring(0.5, [(6000, 3, 1.0)], 0.01), at, 0.35 * g)
    x = lowpass1(x, 9000)
    return finish(x, -4.0, hp=1500.0)


def main():
    save("gun_mag_out.wav", snd_mag_out())
    save("gun_mag_in.wav", snd_mag_in())
    save("gun_cock.wav", snd_cock())
    save("shell_tink.wav", snd_shell_tink())


if __name__ == "__main__":
    main()
