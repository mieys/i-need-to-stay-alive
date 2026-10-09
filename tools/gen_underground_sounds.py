"""Yeraltı Canavarı (Kademe 5 bossu) için prosedürel (numpy) sesler: assets/audio/underground/*.wav

Kullanıcı isteği (2026-10-09): "yeraltından korkutucu sesler gelecek". Çıktı (mono, 44,1 kHz, 16 bit):
  rumble_1..3  yeraltı gümbürtüsü (2,8-3,6 sn: kaba alt frekans + kahverengi gürültü, yavaş nabız, uzaktan çatırtılar)
  growl_1..2   alçak hırıltı (1,5-1,9 sn: perde düşen darbe dizisi + iki formant, nefesli gürültü, düzensiz titreme)
  emerge       uzvun delikten çıkışı / gömülmesi (0,8 sn: toprak patlaması + alt vuruş + kırıntı)
  burst        uzvun parçalanması (0,55 sn: ıslak patlama + alt vuruş + damlalar)
  spit         asit tükürüğü (0,4 sn: yükselen tıslama + "pop")
  hiss         savurma uyarısı (0,5 sn: yükselen titrek tıslama)
Hepsi ~-1 dBFS'e normalize; oyunda scripts/underground_sound.gd kısık çalar. Ayrıca "ambient" projedeki Horror paketinden (Gore And Larvae Loop).
Çalıştır: python tools/gen_underground_sounds.py     Sonra Godot'u `--headless --import` ile bir kez aç (.wav.import dosyaları oluşur).
"""
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "underground")


def n_of(sec):
    return int(SR * sec)


def t_axis(sec):
    return np.arange(n_of(sec)) / SR


def band(x, lo, hi, order=4):
    """FFT süzgeci: lo-hi Hz arası geçer (yumuşak yamaçlar)."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    f[0] = 1e-6
    m = np.ones_like(f)
    if lo > 0:
        m *= 1.0 / (1.0 + (lo / f) ** order)
    if hi < SR / 2:
        m *= 1.0 / (1.0 + (f / hi) ** order)
    return np.fft.irfft(spec * m, len(x))


def formant(x, centers, widths, gains):
    """Verilen merkezlerde Gauss tepeli (formant) süzgeç."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    m = np.full_like(f, 0.08)
    for c, w, g in zip(centers, widths, gains):
        m += g * np.exp(-0.5 * ((f - c) / w) ** 2)
    return np.fft.irfft(spec * m, len(x))


def smooth_env(n, attack, release):
    a = max(int(SR * attack), 1)
    r = max(int(SR * release), 1)
    env = np.ones(n)
    env[:a] = np.linspace(0, 1, a) ** 2
    env[-r:] = np.minimum(env[-r:], np.linspace(1, 0, r) ** 1.5)
    return env


def norm(x, peak=0.89):
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    data = (np.clip(norm(x), -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}.wav  {len(data) / SR:.2f} sn")


def rumble(seed, f0, dur, throb_hz):
    rng = np.random.default_rng(seed)
    t = t_axis(dur)
    n = len(t)
    f = f0 * (1.0 + 0.07 * np.sin(2 * np.pi * 0.33 * t + rng.uniform(0, 6.28)) + 0.03 * np.sin(2 * np.pi * 0.9 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.45 * np.sin(2 * ph + 0.7) + 0.2 * np.sin(3 * ph + 1.3)
    noise = band(rng.standard_normal(n), 22, 170)
    noise = noise / (np.max(np.abs(noise)) + 1e-9)
    grit = band(rng.standard_normal(n), 120, 520) * 0.25
    throb = 0.62 + 0.38 * np.sin(2 * np.pi * throb_hz * t + rng.uniform(0, 6.28)) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.21 * t))
    x = (0.75 * tone / 1.65 + 1.1 * noise + grit) * throb
    ## uzaktan çatırtılar (taş/toprak kayması)
    for _ in range(int(rng.integers(2, 5))):
        at = int(rng.uniform(0.25, 0.85) * n)
        ln = n_of(0.22)
        if at + ln >= n:
            continue
        click = band(rng.standard_normal(ln), 220, 1400) * np.exp(-np.arange(ln) / (SR * 0.05))
        x[at:at + ln] += 0.35 * click / (np.max(np.abs(click)) + 1e-9)
    return x * smooth_env(n, 0.9, 1.3)


def growl(seed, f_start, f_end, dur):
    rng = np.random.default_rng(seed)
    t = t_axis(dur)
    n = len(t)
    prog = t / dur
    f = f_start + (f_end - f_start) * prog ** 0.7
    f *= 1.0 + 0.04 * np.sin(2 * np.pi * 6.5 * t) + 0.02 * rng.standard_normal(n).cumsum() / np.sqrt(n)
    ph = np.cumsum(f) / SR
    saw = 2.0 * (ph % 1.0) - 1.0
    pulse = np.maximum(saw, -0.2) ** 3
    voiced = formant(pulse, [330, 760, 1500], [110, 220, 400], [1.0, 0.75, 0.25])
    breath = band(rng.standard_normal(n), 180, 2600) * 0.35
    trem = 0.7 + 0.3 * np.sin(2 * np.pi * 7.3 * t + 1.0) * np.sin(2 * np.pi * 2.1 * t + 0.4)
    x = (voiced / (np.max(np.abs(voiced)) + 1e-9) + breath) * trem
    return x * smooth_env(n, 0.18, 0.7)


def emerge():
    rng = np.random.default_rng(31)
    dur = 0.8
    t = t_axis(dur)
    n = len(t)
    thump = np.sin(2 * np.pi * np.cumsum(28 + 52 * np.exp(-t / 0.09)) / SR) * np.exp(-t / 0.22)
    soil = band(rng.standard_normal(n), 60, 950) * np.exp(-t / 0.28)
    soil[:int(SR * 0.004)] *= np.linspace(0, 1, int(SR * 0.004))
    crackle = np.zeros(n)
    for _ in range(26):
        at = int(rng.uniform(0.02, 0.5) * n)
        ln = n_of(0.02)
        crackle[at:at + ln] += band(rng.standard_normal(ln), 400, 3500) * np.hanning(ln) * rng.uniform(0.2, 0.6)
    return 1.0 * thump + 0.9 * soil / (np.max(np.abs(soil)) + 1e-9) + 0.4 * crackle


def burst():
    rng = np.random.default_rng(47)
    dur = 0.55
    t = t_axis(dur)
    n = len(t)
    splat = band(rng.standard_normal(n), 280, 2600) * np.exp(-t / 0.085)
    thump = np.sin(2 * np.pi * np.cumsum(40 + 55 * np.exp(-t / 0.05)) / SR) * np.exp(-t / 0.14)
    x = 0.9 * splat / (np.max(np.abs(splat)) + 1e-9) + 1.1 * thump
    for _ in range(6):
        at = int(rng.uniform(0.12, 0.45) * n)
        ln = n_of(0.03)
        d = band(rng.standard_normal(ln), 600, 3000) * np.exp(-np.arange(ln) / (SR * 0.008))
        x[at:at + ln] += 0.35 * d / (np.max(np.abs(d)) + 1e-9)
    return x


def spit():
    rng = np.random.default_rng(53)
    dur = 0.4
    t = t_axis(dur)
    n = len(t)
    hiss = band(rng.standard_normal(n), 1600, 9500) * np.clip(t / 0.22, 0, 1) ** 1.5 * np.exp(-np.maximum(t - 0.22, 0) / 0.05)
    pop_at = int(0.27 * SR)
    pt = np.arange(n - pop_at) / SR
    pop = np.sin(2 * np.pi * np.cumsum(520 * np.exp(-pt / 0.03) + 120) / SR) * np.exp(-pt / 0.03)
    x = hiss / (np.max(np.abs(hiss)) + 1e-9) * 0.6
    x[pop_at:] += 0.9 * pop
    return x


def hiss():
    rng = np.random.default_rng(61)
    dur = 0.5
    t = t_axis(dur)
    n = len(t)
    base = band(rng.standard_normal(n), 1800, 8500)
    trem = 0.65 + 0.35 * np.sin(2 * np.pi * 24 * t)
    x = base / (np.max(np.abs(base)) + 1e-9) * (np.clip(t / 0.4, 0, 1) ** 1.3) * trem
    x[-n_of(0.04):] *= np.linspace(1, 0, n_of(0.04))
    return x


def main():
    write("rumble_1", rumble(11, 41, 3.2, 3.1))
    write("rumble_2", rumble(12, 47, 2.8, 4.4))
    write("rumble_3", rumble(13, 36, 3.6, 2.5))
    write("growl_1", growl(21, 92, 52, 1.7))
    write("growl_2", growl(22, 74, 43, 1.9))
    write("emerge", emerge())
    write("burst", burst())
    write("spit", spit())
    write("hiss", hiss())


if __name__ == "__main__":
    main()
