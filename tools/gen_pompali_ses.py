"""Pompalı Tüfek sesleri (madde 448 ek, 2026-11-08): kullanıcının "tüfek ateşleme.mp3" dosyasını ATIŞ + POMPA ÇEKİŞİ diye ikiye ayırır.

Kullanıcı: "pompalı tüfeğin çekiş sesi de vardı attığım seste, ateşledikten sonra hemen o oynatılıyordu". Dosyada pompa ayrı bir parça
DEĞİL: patlamadan 0,10-0,40 sn sonra, yankı kuyruğunun içine gömülü 4-8 ms'lik metal tıkları (0,120 / 0,136-0,144 / 0,227 / 0,391 sn;
1,5 kHz üstünde kuyruktan 6-10 dB yüksek). Oyunda -8 dB + savaş sesleri altında bu tıklar duyulmuyordu. Ayırma:
  1. hb = 700 Hz üstü (FFT, sıfır fazlı 4. derece Butterworth genliği), lb = x - hb (patlamanın gövdesi, dokunulmaz).
  2. Tık kazancı g(t): hb zarfı (1 ms) kayan taban zarfının (40 ms ortanca) GATE_DB üstüne çıktığı yerler, 1 ms atak / RELEASE_MS bırakma.
     Yalnız [WIN_START, WIN_END] penceresinde (ilk patlama 0,02-0,10 sn hiç değişmez).
  3. ATIŞ  = lb + hb * (1 - DUCK * g)   -> tıklar kuyruktan ~15 dB kısılır (pompa ayrı çalınca iki kez duyulmasın).
     POMPA = LP9k(hb) * g + BODY * lb * g -> tıklar + aynı anlardaki alt bant (gövde), ilk tık 10 ms'ye kaydırılır, tepe -3 dBFS.
Oyunda (scripts/pump_shot_sound.gd): atış hemen, pompa `pump_delay` sonra kendi çalıcısından, ağda "weapon_sound" zinciriyle.
Kaynak dosyaya dokunulmaz (assets/audio/pompali_fire.mp3 = kullanıcının dosyası birebir).
Kullanım: python -I tools/gen_pompali_ses.py
"""
import os
import sys

import miniaudio
import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "audio", "pompali_fire.mp3")
OUT_FIRE = os.path.join(ROOT, "assets", "audio", "pompali_atis.wav")
OUT_PUMP = os.path.join(ROOT, "assets", "audio", "pompali_pompa.wav")

HP_HZ = 700.0
WIN_START, WIN_END = 0.105, 0.47   # tıkların bulunduğu pencere (sn)
GATE_DB = 5.0                      # zarf, taban zarfının bu kadar üstündeyse tık
FULL_DB = 11.0                     # bu kadar üstünde tam kazanç (arası yumuşak)
RELEASE_MS = 22.0                  # tıktan sonra metal sürtünmesinin kuyruğu
DUCK = 0.82                        # atıştaki tık kısması (1 = tamamen sil)
PUMP_PEAK_DB = -3.0
## Pompaya gövde: yalnız tıklar 700 Hz üstü kalınca ince/cızırtılı (300 Hz altı %0, 8 kHz üstü %24; oyundaki gun_cock.wav %43 / %1).
## Aynı anlardaki alt bandı (lb) da aynı kazançla alır (metalin "küt"ü) + 9 kHz üstünü yumuşatır. Atıştan alt bant ÇIKARILMAZ.
BODY = 0.55
PUMP_LP_HZ = 9000.0


def load(path):
    d = miniaudio.decode_file(path, output_format=miniaudio.SampleFormat.FLOAT32)
    x = np.frombuffer(d.samples, dtype=np.float32).reshape(-1, d.nchannels).astype(np.float64)
    return x, d.sample_rate


def highpass(x, sr, fc):
    F = np.fft.rfft(x, axis=0)
    f = np.fft.rfftfreq(x.shape[0], 1.0 / sr)
    g = 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-3)) ** 8)
    return np.fft.irfft(F * g[:, None], n=x.shape[0], axis=0)


def lowpass(x, sr, fc):
    F = np.fft.rfft(x, axis=0)
    f = np.fft.rfftfreq(x.shape[0], 1.0 / sr)
    g = 1.0 / np.sqrt(1.0 + (f / fc) ** 4)
    return np.fft.irfft(F * g[:, None], n=x.shape[0], axis=0)


def moving(a, n, fn):
    pad = n // 2
    ap = np.pad(a, (pad, pad), mode="edge")
    view = np.lib.stride_tricks.sliding_window_view(ap, n)[: len(a)]
    return fn(view, axis=1)


def click_gain(hb, sr):
    mono = np.abs(hb).mean(axis=1)
    env = moving(mono, max(1, int(sr * 0.001)), np.mean)
    # taban: 40 ms ortanca, 4 ms adımla (hız) hesaplanıp örneğe yayılır
    step = int(sr * 0.004)
    idx = np.arange(0, len(env), step)
    win = int(sr * 0.040) // step
    coarse = moving(env[idx], max(3, win | 1), np.median)
    floor = np.interp(np.arange(len(env)), idx, coarse)
    over = 20.0 * np.log10((env + 1e-9) / (floor + 1e-9))
    raw = np.clip((over - GATE_DB) / (FULL_DB - GATE_DB), 0.0, 1.0)
    t = np.arange(len(env)) / sr
    raw[(t < WIN_START) | (t > WIN_END)] = 0.0
    # 1 ms atak / RELEASE_MS bırakma (tepe tutucu)
    a_att = np.exp(-1.0 / (sr * 0.001))
    a_rel = np.exp(-1.0 / (sr * RELEASE_MS / 1000.0))
    g = np.zeros_like(raw)
    v = 0.0
    for i, r in enumerate(raw):
        v = a_att * v + (1 - a_att) * r if r > v else a_rel * v + (1 - a_rel) * r
        g[i] = v
    return np.clip(g / max(g.max(), 1e-9), 0.0, 1.0), t


def fade(y, sr, fin_ms, fout_ms):
    n_in, n_out = int(sr * fin_ms / 1000), int(sr * fout_ms / 1000)
    if n_in:
        y[:n_in] *= np.linspace(0, 1, n_in)[:, None]
    if n_out:
        y[-n_out:] *= np.linspace(1, 0, n_out)[:, None]
    return y


def main():
    x, sr = load(SRC)
    hb = highpass(x, sr, HP_HZ)
    lb = x - hb
    g, t = click_gain(hb, sr)
    fire = lb + hb * (1.0 - DUCK * g)[:, None]
    pump_full = lowpass(hb, sr, PUMP_LP_HZ) * g[:, None] + BODY * lb * g[:, None]

    on = np.nonzero(g > 0.05)[0]
    if len(on) == 0:
        sys.exit("tık bulunamadı - GATE_DB/WIN ayarlarına bak")
    first, last = on[0], on[-1]
    lead = int(sr * 0.010)
    a = max(0, first - lead)
    b = min(len(x), last + int(sr * 0.030))
    pump = pump_full[a:b].copy()
    pump = fade(pump, sr, 2, 25)
    pump *= 10 ** (PUMP_PEAK_DB / 20) / max(np.abs(pump).max(), 1e-9)

    peak_src = np.abs(x).max()
    if np.abs(fire).max() > peak_src:
        fire *= peak_src / np.abs(fire).max()
    sf.write(OUT_FIRE, fire.astype(np.float32), sr, subtype="PCM_16")
    sf.write(OUT_PUMP, pump.astype(np.float32), sr, subtype="PCM_16")

    # rapor: bulunan tıklar
    hits, inside = [], False
    for i in range(len(g)):
        if g[i] > 0.5 and not inside:
            hits.append(round(t[i], 3))
            inside = True
        elif g[i] < 0.2:
            inside = False
    print("tıklar (sn):", hits)
    print("pompa: %.3f sn (kaynakta %.3f-%.3f), ilk tık %.3f sn" % ((b - a) / sr, a / sr, b / sr, (first - a) / sr))
    print("ok", OUT_FIRE, OUT_PUMP)


if __name__ == "__main__":
    main()
