"""Gok gurultusu sesleri -> assets/audio/storm/thunder_strike_1/2.wav + thunder_distant_1/2.wav

Kullanici istegi (2026-09-26): "yagmurdaki yildirim sesi hic gok gurultusu sesi gibi degil bunu yeniden tasarlar misin".
Eski sesler tamamen sentezdi (tools/gen_storm_sounds.py): yakin yildirim enerjisinin %90'i 12.8 kHz'e kadar yayilan
beyaz gurultu cizirtisi + 0.5 sn'de bir tekrarlanan duzenli "tumsekler" - gok gurultusunden cok parazit gibiydi.

Artik temel GERCEK bir kayit: "Sound FX Starter Pack Vol. 1/Community Requests/Rolling Thunder.wav" (repo kokunde, telifsiz
lisans paketin icinde). 10.6 sn, ~1.2 sn'de kabarir, 5-6 sn duzensiz yuvarlanir, enerjisinin %90'i 194 Hz altinda.

  thunder_distant_1/2  uzak gurultu (yildirimsiz sema parlamasi, konumsuz AudioStreamPlayer -> STEREO): kaydin iki farkli
                       bolumu; 2. varyant biraz pes + daha boguk (daha uzak). Dogal kabarma korunur.
  thunder_strike_1/2   yakina dusen yildirim (AudioStreamPlayer2D -> MONO): sentez "CRACK" (kisa, parlak yirtilma
                       citirtisi + sert patlama + derin BUM, kisa dis mekan yankisi) hemen ardindan kaydin en guclu
                       bolumunden yuvarlanan gurleme.
Ses seviyeleri eski dosyalarla A-agirlikli (kulaga gore) eslestirilir - oyundaki volume_db ayarlari aynen gecerli kalir.
charge.wav (elektriklenme) bu script'e dahil DEGIL, hala gen_storm_sounds.py uretir (o script'in gok gurultusu kismi artik
kullanilmiyor - calistirirsan bu script'i de ardindan calistir).

Calistir: python tools/gen_thunder_sounds.py
"""

import math
import os
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, "Sound FX Starter Pack Vol. 1", "Community Requests", "Rolling Thunder.wav")
OUT = os.path.join(ROOT, "assets", "audio", "storm")
SR = 44100


def load_wav(path):
    with wave.open(path) as w:
        assert w.getsampwidth() == 2 and w.getframerate() == SR
        ch = w.getnchannels()
        d = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
    return d.reshape(-1, ch)


def save_wav(path, x):
    x = np.clip(x, -1.0, 1.0)
    if x.ndim == 1:
        x = x[:, None]
    with wave.open(path, "wb") as w:
        w.setnchannels(x.shape[1])
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767.0).astype(np.int16).tobytes())


def fft_filter(x, gain_fn):
    """Faz kaymasiz frekans alani filtre: gain_fn(f) -> genlik carpani. x: (n,) ya da (n, ch)."""
    one = x.ndim == 1
    if one:
        x = x[:, None]
    n = x.shape[0]
    pad = 1 << int(math.ceil(math.log2(n + SR)))
    f = np.fft.rfftfreq(pad, 1.0 / SR)
    g = gain_fn(np.maximum(f, 1e-3))
    y = np.fft.irfft(np.fft.rfft(x, n=pad, axis=0) * g[:, None], n=pad, axis=0)[:n]
    return y[:, 0] if one else y


def lowpass(x, fc, order=2):
    return fft_filter(x, lambda f: 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order)))


def highpass(x, fc, order=2):
    return fft_filter(x, lambda f: 1.0 / np.sqrt(1.0 + (fc / f) ** (2 * order)))


def bandpass(x, lo, hi):
    return lowpass(highpass(x, lo), hi)


def resample(x, ratio):
    """ratio < 1 = daha pes ve daha uzun (yavasca calinmis kayit)."""
    n = x.shape[0]
    m = int(n / ratio)
    t = np.arange(m) * ratio
    if x.ndim == 1:
        return np.interp(t, np.arange(n), x)
    return np.stack([np.interp(t, np.arange(n), x[:, c]) for c in range(x.shape[1])], axis=1)


def fade(x, fade_in, fade_out):
    n = x.shape[0]
    env = np.ones(n)
    a = int(fade_in * SR)
    b = int(fade_out * SR)
    if a > 0:
        env[:a] = np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    if b > 0:
        ## Kuyruk: dogal sonumlenme gibi ustel-ish (cos^3) - sert kesilmesin.
        env[n - b:] *= np.cos(np.linspace(0, np.pi / 2, b)) ** 3
    return x * (env if x.ndim == 1 else env[:, None])


def a_weight(f):
    f2 = f * f
    r = (12194 ** 2 * f2 ** 2) / ((f2 + 20.6 ** 2) * np.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2)) * (f2 + 12194 ** 2))
    return r / 0.7943  # 1 kHz'de ~1


def loudness_db(x, window=1.5):
    """En gurultulu `window` sn'lik bolumun A-agirlikli RMS'i (dBFS)."""
    m = x.mean(axis=1) if x.ndim == 2 else x
    y = fft_filter(m, a_weight)
    w = int(window * SR)
    hop = w // 4
    best = 1e-12
    for i in range(0, max(1, len(y) - w), hop):
        best = max(best, float(np.mean(y[i:i + w] ** 2)))
    return 10 * math.log10(best)


def match_loudness(x, ref_db, peak_limit=0.95):
    g = 10 ** ((ref_db - loudness_db(x)) / 20.0)
    y = x * g
    pk = float(np.abs(y).max())
    if pk > peak_limit:
        ## Tepe sinirlamasi: yumusak (tanh) - crack'in keskinligi kalsin, clip olmasin.
        y = np.tanh(y / peak_limit * 1.2) * peak_limit / math.tanh(1.2)
    return y


def crack(rng, length=1.4):
    """Yakin yildirim: yirtilma citirtisi (~110 ms, sikligi artan) -> sert patlama -> derin BUM + kisa dis yanki. Mono."""
    n = int(length * SR)
    out = np.zeros(n)
    t_bang = 0.11 + rng.uniform(-0.02, 0.02)
    ## 1) Yirtilma: kisa gurultu tanecikleri, bang'e dogru sikisan ve guclenen.
    grains = 28
    for i in range(grains):
        u = (i + rng.uniform(0, 1)) / grains
        t = t_bang * (u ** 0.55)
        amp = 0.12 + 0.55 * u ** 1.5
        glen = int(rng.uniform(0.002, 0.006) * SR)
        g = rng.standard_normal(glen) * np.exp(-np.arange(glen) / (glen * 0.25)) * amp
        s = int(t * SR)
        out[s:s + glen] += g[: max(0, min(glen, n - s))]
    out = highpass(out, 1400.0)
    ## 2) Patlama: genis bantli, cok kisa.
    s = int(t_bang * SR)
    bl = int(0.25 * SR)
    tb = np.arange(bl) / SR
    bang = rng.standard_normal(bl) * (np.exp(-tb / 0.016) + 0.25 * np.exp(-tb / 0.07))
    bang = lowpass(bang, 6500.0, 1) * 1.0
    out[s:s + bl] += bang[: n - s]
    ## 3) BUM: 72 -> 36 Hz kayan alcak ton + alcak gurultu govdesi.
    ul = int(0.9 * SR)
    tu = np.arange(ul) / SR
    freq = 36.0 + 36.0 * np.exp(-tu / 0.12)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    boom = np.sin(phase) * np.exp(-tu / 0.28) * (1 - np.exp(-tu / 0.004))
    body = lowpass(rng.standard_normal(ul), 180.0) * np.exp(-tu / 0.35) * 2.2
    out[s:s + ul] += (boom * 0.9 + body * 0.8)[: n - s]
    ## 4) Dis mekan yankisi: sonumlenen gurultu darbe tepkisi, koyu (yanki tizleri erken kaybeder).
    il = int(0.9 * SR)
    ti = np.arange(il) / SR
    ir = rng.standard_normal(il) * np.exp(-ti / 0.28)
    ir[: int(0.012 * SR)] = 0.0  # dogrudan sesle karismasin
    ir = lowpass(ir, 2200.0, 1)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = np.convolve(out, ir)[:n]
    return out + wet * 0.55


def rumble_segment(src_mono, start, length, rate=1.0):
    seg = src_mono[int(start * SR): int((start + length / rate) * SR) + 2]
    if rate != 1.0:
        seg = resample(seg, rate)
    return seg[: int(length * SR)]


def main():
    rng = np.random.default_rng(20260926)
    src = load_wav(SRC)
    ## DC/sub-bas temizligi (fade'lerden ONCE - sonrasinda ortalama cikarmak iki uca tik ekler).
    src = highpass(src, 28.0)
    mono = src.mean(axis=1)
    refs = {}
    for name in ["thunder_strike_1", "thunder_strike_2", "thunder_distant_1", "thunder_distant_2"]:
        p = os.path.join(OUT, name + ".wav")
        refs[name] = loudness_db(load_wav(p)) if os.path.exists(p) else -14.0

    ## ---- UZAK: kaydin kendisi (stereo), bogukluk + uzaklik.
    d1 = src[: int(8.6 * SR)].copy()
    d1 = lowpass(d1, 700.0, 1)
    d1 = fade(d1, 0.05, 2.4)
    d2 = resample(src[int(1.6 * SR): int(8.9 * SR)], 0.86)  # daha pes, daha yavas yuvarlanan
    d2 = lowpass(d2, 420.0, 1)
    d2 = fade(d2[: int(8.0 * SR)], 0.7, 2.6)  # yavasca kabarir (uzaktan gelen)
    ## ---- YAKIN: crack + kaydin en guclu bolumunden gurleme (mono).
    strikes = []
    for i, (start, rate) in enumerate([(1.05, 1.0), (2.9, 0.93)]):
        c = crack(rng)
        r = rumble_segment(mono, start, 5.6, rate)
        ## Yakin gurlemede biraz daha "govde" (kayit 194 Hz alti - kucuk hoparlorde kaybolmasin): 150-900 Hz hafif one.
        r = r + bandpass(r, 150.0, 900.0) * 0.8
        r = fade(r, 0.06, 2.0)
        out = np.zeros(int(6.0 * SR))
        off = int((0.11 + 0.035) * SR)  # gurleme patlamadan hemen sonra baslar
        out[off: off + len(r)] += r * (1.6 if i == 0 else 1.4)
        out[: len(c)] += c
        out = fade(out, 0.002, 1.2)
        strikes.append(out)

    save_wav(os.path.join(OUT, "thunder_distant_1.wav"), match_loudness(d1, refs["thunder_distant_1"]))
    save_wav(os.path.join(OUT, "thunder_distant_2.wav"), match_loudness(d2, refs["thunder_distant_2"]))
    save_wav(os.path.join(OUT, "thunder_strike_1.wav"), match_loudness(strikes[0], refs["thunder_strike_1"]))
    save_wav(os.path.join(OUT, "thunder_strike_2.wav"), match_loudness(strikes[1], refs["thunder_strike_2"]))
    for k, v in refs.items():
        print(f"{k}: eski A-agirlikli {v:.1f} dBFS -> yeni {loudness_db(load_wav(os.path.join(OUT, k + '.wav'))):.1f}")


if __name__ == "__main__":
    main()
