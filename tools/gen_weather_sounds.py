"""Kullanici istegi (2026-09-25): gun-gece + hava durumu sistemi (bkz. scripts/atmosphere.gd). Soru-cevapta yagmur ve
ruzgar icin ortam sesini "ben ureteyim" secenegi secildi. Bu script iki DONGU sesi uretir:

  - weather_rain_loop.wav : yumusak "hisirti" yatagi + rastgele ince damla tikirtilari (plink) + seyrek iri damlalar
                            (plop); siddeti hafifce dalgalanir.
  - weather_wind_loop.wav : alcak, dalgalanan bir ugultu (ruzgar hamleleri) + cok kisik, hafif islik gibi ust katman.

DIKISSIZ DONGU: tum filtreleme FREKANS UZAYINDA yapiliyor (FFT ile carp, ters FFT) - bu dairesel (circular) bir filtre,
yani cikti tam olarak dosya uzunlugunda periyodik: sonu basina tik/ciziltisiz baglanir. Yavas dalgalanmalar (LFO)
dosya boyunca TAM SAYIDA devir yapar, damlalar sona tasarsa basa sarar - ayni gerekceyle.
Godot tarafinda dongu atmosphere.gd'de calisma aninda aciliyor (AudioStreamWAV.loop_mode), .import ayari gerekmez.

Calistir: python tools/gen_weather_sounds.py
Sonra: Godot editoru dosyalari otomatik import eder (ya da: Godot --headless --import).
"""

import os
import wave

import numpy as np

SR = 22050
OUT_AUDIO = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
RNG = np.random.default_rng(20260925)


def shaped_noise(n, gain_fn):
    """Beyaz gurultuyu frekans uzayinda gain_fn(f) ile sekillendirir (dairesel -> periyodik cikti)."""
    spec = np.fft.rfft(RNG.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = 1e-3
    out = np.fft.irfft(spec * gain_fn(f), n)
    return out / (np.sqrt(np.mean(out ** 2)) + 1e-12)


def lfo(n, cycles, phase=0.0):
    """Dosya boyunca TAM SAYIDA devir yapan sinus (dikissiz dongu icin)."""
    t = np.arange(n) / n
    return np.sin(2 * np.pi * cycles * t + phase)


def add_wrapped(buf, start, grain):
    """grain'i buf'a start'tan itibaren ekler; sona tasani basa sarar."""
    n = len(buf)
    idx = (start + np.arange(len(grain))) % n
    np.add.at(buf, idx, grain)


def smooth_lowpass(signal, cutoff):
    n = len(signal)
    spec = np.fft.rfft(signal)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    return np.fft.irfft(spec / np.sqrt(1.0 + (f / cutoff) ** 4), n)


def rain(seconds=12.0):
    n = int(SR * seconds)
    # Yatak: 400 Hz alti ve 5 kHz ustu yumusakca kisilmis, hafif pembe egimli hisirti.
    bed = shaped_noise(n, lambda f: (f ** 2 / (f ** 2 + 400.0 ** 2)) ** 0.5
                       / np.sqrt(1.0 + (f / 5000.0) ** 2) / np.sqrt(np.maximum(f, 50.0) / 1000.0))
    swell = 1.0 + 0.12 * lfo(n, 3, 0.4) + 0.07 * lfo(n, 7, 1.9)
    out = bed * 0.11 * swell

    # Ince damlalar (plink): kisa, hizla sonen yuksek sinusler.
    for _ in range(int(55 * seconds)):
        f0 = RNG.uniform(2500.0, 5500.0)
        tau = RNG.uniform(0.003, 0.008)
        length = int(SR * tau * 6)
        t = np.arange(length) / SR
        grain = np.sin(2 * np.pi * f0 * t) * np.exp(-t / tau) * RNG.uniform(0.015, 0.06)
        add_wrapped(out, int(RNG.integers(0, n)), grain)

    # Iri damlalar (plop): daha alcak, sesi hafifce asagi kayan, biraz daha uzun.
    for _ in range(int(5 * seconds)):
        f0 = RNG.uniform(700.0, 1600.0)
        tau = RNG.uniform(0.010, 0.025)
        length = int(SR * tau * 6)
        t = np.arange(length) / SR
        freq = f0 * (1.0 - 0.35 * (1.0 - np.exp(-t / (tau * 0.6))))
        phase = 2 * np.pi * np.cumsum(freq) / SR
        grain = np.sin(phase) * np.exp(-t / tau) * RNG.uniform(0.04, 0.09)
        add_wrapped(out, int(RNG.integers(0, n)), grain)

    out = smooth_lowpass(out, 7000.0)
    return out / np.max(np.abs(out)) * 0.6


def wind(seconds=16.0):
    n = int(SR * seconds)
    # Ugultu: 60 Hz alti ve ~900 Hz ustu kisik kahverengi-pembe gurultu.
    rumble = shaped_noise(n, lambda f: (f ** 2 / (f ** 2 + 60.0 ** 2)) ** 0.5
                          / np.sqrt(1.0 + (f / 900.0) ** 4) / np.maximum(f, 40.0) ** 0.5)
    gust = 0.55 + 0.28 * lfo(n, 2, 0.3) + 0.14 * lfo(n, 5, 2.1) + 0.05 * lfo(n, 11, 4.0)
    out = rumble * gust

    # Islik: dar bantli gurultu katmanlari, her biri kendi hamlesinde yukselip alcalir -> perdesi kayan hafif islik.
    for center, cycles, ph in ((620.0, 3, 0.0), (860.0, 4, 1.7), (1120.0, 5, 3.1)):
        band = shaped_noise(n, lambda f, c=center: 1.0 / (1.0 + ((f - c) / (c * 0.035)) ** 2))
        env = np.clip(lfo(n, cycles, ph), 0.0, 1.0) ** 2
        out += band * env * 0.06

    out = smooth_lowpass(out, 2500.0)
    return out / np.max(np.abs(out)) * 0.55


def storm_wind(seconds=14.0):
    """Saganak ruzgari (kullanici bildirimi 2026-09-25: "firtina ... ruzgar firtina sesi gelmiyor fazla"): normal ruzgar
    dongusunden cok daha genis bantli, guclu ve derin hamleli bir ugultu + belirgin, yukselip alcalan fırtına islikleri.
    Saganakta normal ruzgarin USTUNE ayri bir katman olarak calar (bkz. atmosphere.gd STORM_WIND_SOUND_PATH)."""
    n = int(SR * seconds)
    roar = shaped_noise(n, lambda f: (f ** 2 / (f ** 2 + 90.0 ** 2)) ** 0.5
                        / np.sqrt(1.0 + (f / 1800.0) ** 4) / np.maximum(f, 60.0) ** 0.35)
    gust = 0.45 + 0.35 * np.clip(lfo(n, 3, 0.9), -1.0, 1.0) + 0.15 * lfo(n, 7, 2.4) + 0.05 * lfo(n, 13, 0.2)
    gust = np.maximum(gust, 0.12)
    out = roar * gust
    # Islikler: ruzgar bosluklardan gecerken - her biri kendi hamlesinde belirgin sekilde yukselir.
    for center, cycles, ph, g in ((480.0, 2, 0.4, 0.16), (720.0, 3, 2.2, 0.14), (1050.0, 4, 4.0, 0.1), (1500.0, 5, 1.1, 0.07)):
        band = shaped_noise(n, lambda f, c=center: 1.0 / (1.0 + ((f - c) / (c * 0.05)) ** 2))
        env = np.clip(lfo(n, cycles, ph), 0.0, 1.0) ** 1.5
        out += band * env * g
    out = smooth_lowpass(out, 3500.0)
    return out / np.max(np.abs(out)) * 0.8


def write_wav(name, data):
    path = os.path.join(OUT_AUDIO, name)
    pcm = np.clip(data * 32767.0, -32768, 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("yazildi:", os.path.normpath(path), f"{len(data) / SR:.1f} sn")


if __name__ == "__main__":
    write_wav("weather_rain_loop.wav", rain())
    write_wav("weather_wind_loop.wav", wind())
    ## (en sonda uretilir ki RNG sirasi ve yukaridaki iki dosya aynen kalsin)
    os.makedirs(os.path.join(OUT_AUDIO, "storm"), exist_ok=True)
    write_wav(os.path.join("storm", "storm_wind_loop.wav"), storm_wind())
