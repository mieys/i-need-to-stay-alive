"""Ateş Asası püskürtme sesi (2026-10-11, kullanıcı: "ateş asası ateş püskürtünce ses efekti çıkarsın buna uygun").
Çıktı: assets/audio/fire_staff_spray_loop.wav - dikişsiz döngü (dosya boyu tam sayıda LFO devri, gürültü frekans uzayında
şekillendirildiği için periyodik). Katmanlar: (1) alev nefesi: 120 Hz - 3 kHz arası pembe "fışşş" + hızlı titreşim (gaz alevi),
(2) alçak uğultu (yanma gövdesi), (3) seyrek kor çıtırtıları. Döngüyü fx_enchant_sprite.gd ("loop_sfx") çalışma anında açar.
gen_weather_sounds.py ile aynı yardımcılar.
"""
import os
import wave

import numpy as np

SR = 22050
OUT_AUDIO = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
RNG = np.random.default_rng(20261011)


def shaped_noise(n, gain_fn):
    spec = np.fft.rfft(RNG.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = 1e-3
    out = np.fft.irfft(spec * gain_fn(f), n)
    return out / (np.sqrt(np.mean(out ** 2)) + 1e-12)


def lfo(n, cycles, phase=0.0):
    t = np.arange(n) / n
    return np.sin(2 * np.pi * cycles * t + phase)


def add_wrapped(buf, start, grain):
    n = len(buf)
    idx = (start + np.arange(len(grain))) % n
    np.add.at(buf, idx, grain)


def flame(seconds=3.0):
    n = int(SR * seconds)
    # Nefes: 120 Hz alti ve ~3 kHz ustu yumusak kisik, hafif pembe
    breath = shaped_noise(n, lambda f: (f ** 2 / (f ** 2 + 120.0 ** 2)) ** 0.5
                          / np.sqrt(1.0 + (f / 3000.0) ** 3) / np.maximum(f, 80.0) ** 0.35)
    flutter = 0.82 + 0.10 * lfo(n, 27, 0.4) + 0.06 * lfo(n, 41, 1.9) + 0.04 * lfo(n, 6, 2.7)
    out = breath * flutter
    # Govde ugultusu
    rumble = shaped_noise(n, lambda f: (f ** 2 / (f ** 2 + 45.0 ** 2)) ** 0.5 / np.sqrt(1.0 + (f / 260.0) ** 4))
    out += rumble * (0.55 + 0.1 * lfo(n, 3, 0.8))
    # Kor citirtilari: kisa, keskin, yuksek frekansli tikirtilar
    for _ in range(int(seconds * 9)):
        ln = int(SR * RNG.uniform(0.003, 0.009))
        t = np.arange(ln) / ln
        grain = RNG.standard_normal(ln) * np.exp(-t * 6.0) * RNG.uniform(0.6, 1.4)
        grain = np.diff(np.concatenate([[0.0], grain]))  # yuksek geciren: citir
        add_wrapped(out, int(RNG.integers(0, n)), grain * 2.2)
    out -= np.mean(out)
    return out / np.max(np.abs(out)) * 0.7


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
    write_wav("fire_staff_spray_loop.wav", flame())
