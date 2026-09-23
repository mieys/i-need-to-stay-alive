"""Kullanici istegi (2026-09-23): "oyundaki exp toplama sesini degistir, survival-like
oyunlardaki (Vampire Survivors/Brotato tarzi) gibi yuksek dopamin saglayan mini exp orb
toplama sesi istiyorum. Calisma mantigi (pitch artisi vs) degismesin."

Eski assets/audio/xp_pickup.mp3 duz/donuk bir "pop" sesiydi. Bu script onun yerine gecen
assets/audio/xp_pickup.wav'i uretir: cok kisa (~130ms), parlak, hafif yukselen bir "pop"
+ hemen ardindan gelen tiz bir "sparkle" notasi (bes araligi) - klasik survival-like
"exp gem" toplama sesi karakteri. player.gd'deki streak pitch mekanizmasina (XP_STREAK_
PITCH_STEP=0.01, tavan pitch_scale=1.0+50*0.01=1.5, bkz. player.gd _play_xp_pickup_sound)
HICBIR SEKILDE dokunulmadi - bu script SADECE $XPPickupSound'un ham stream'ini degistirir,
pitch_scale zaten Godot tarafinda calisma anda uygulaniyor. Taban perde (880 Hz), 1.5x
streak tavaninda bile (1320 Hz) tiz/rahatsiz edici olmayacak sekilde secildi.

Calistir: python tools/gen_xp_pickup_sound.py
Sonra Godot'u --headless --import ile calistirip .wav.import dosyasini olustur.
"""

import os
import wave

import numpy as np

SR = 44100
OUT_AUDIO = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def t_axis(sec):
    return np.linspace(0, sec, int(SR * sec), endpoint=False)


def env_ad(n, attack, release_pow=2.2):
    """Kisa atak + ustel sonum zarfi (gen_spirit_assets.py ile ayni desen)."""
    e = np.ones(n)
    a = max(1, int(SR * attack))
    e[:a] = np.linspace(0, 1, a)
    tail = np.linspace(1, 0, n - a) ** release_pow
    e[a:] = tail
    return e


def lowpass(x, cutoff_hz):
    rc = 1.0 / (2 * np.pi * cutoff_hz)
    a = (1.0 / SR) / (rc + 1.0 / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def save_wav(name, x, gain=0.9):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    f = int(SR * 0.005)
    x[-f:] *= np.linspace(1, 0, f)
    data = (x * 32767).astype(np.int16)
    os.makedirs(OUT_AUDIO, exist_ok=True)
    path = os.path.join(OUT_AUDIO, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", path)


def snd_xp_pickup():
    sec = 0.13
    n = int(SR * sec)
    t = t_axis(sec)

    # Ana "ding": taban nota 880 Hz (A5), ilk ~11ms'de perde hafifce YUKARIDAN
    # inip yerlesiyor (klasik "coin pop"/bounce hissi), sonra hizla sonuyor.
    base_freq = 880.0
    pop_amount = 260.0
    pop_env = np.exp(-t * 95.0)
    inst_freq = base_freq + pop_amount * pop_env
    phase = 2 * np.pi * np.cumsum(inst_freq) / SR
    ding = np.sin(phase) + 0.45 * np.sin(2 * phase) + 0.18 * np.sin(3 * phase)
    ding *= env_ad(n, 0.003, 1.8)

    # Ikinci, bes araligi (perfect fifth) yukarida, hafif gecikmeli giren tiz
    # "sparkle" notasi - dogal cift-nota "gem/coin" karakteri.
    sparkle_freq = base_freq * 1.5
    sparkle = np.sin(2 * np.pi * sparkle_freq * t) * env_ad(n, 0.001, 2.6) * 0.35
    delay_samples = int(SR * 0.016)
    sparkle_delayed = np.zeros(n)
    sparkle_delayed[delay_samples:] = sparkle[: n - delay_samples]

    # Cok kisa parlak "tik" transienti - atagi keskinlestirip "crisp" yapiyor.
    click = np.random.RandomState(42).randn(n)
    click = (click - lowpass(click, 4000)) * env_ad(n, 0.0005, 5.0) * 0.22

    out = ding * 0.8 + sparkle_delayed + click
    save_wav("xp_pickup.wav", out, gain=0.9)


if __name__ == "__main__":
    snd_xp_pickup()
