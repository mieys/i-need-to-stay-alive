"""Yıldırım Asası ışın DÖNGÜ sesi (uğultu) PROTOTİPLERİ (2026-10-19, madde 294 devamı). Kullanıcı: "hala looplu yıldırım sesi için
prototip sunmadın".

Bugünkü döngü (assets/audio/lightning/electric_loop.mp3): 1,5 sn, enerjinin %55'i 5 kHz üstü (tıslama), %27'si 150 Hz altı; oyunda her
karede rastgele perde (0,94-1,08) + ses (±1,5 dB) titremesi, dosya bitince finished -> play() ile baştan (dikişte ~1 kare boşluk).
Adaylar (3 sn, DİKİŞSİZ: tonlar 1/3 Hz'in katı + FM sapması döngüde sıfır ortalamalı; gürültü katmanları uçtan uca eş güçlü çapraz
geçişli; son süzgeç dairesel FFT):
  L1 Derin Uğultu   : sıcak, güçlü alçak-orta elektrik uğultusu (100 Hz testere + 1/3 Hz vuruşan ikinci ses), seyrek kıvılcım, yavaş nabız
  L2 Cızırdayan Ark : kesik kesik vızıldayan ark (125 Hz kare dalga, düzensiz kapı) + sık çıtırtı + şebeke cızırtısı, dalgalanan şiddet
  L3 Akan Enerji    : plazma akışı (gezinen rezonanslı gürültü 600-2400 Hz) + alçak tok uğultu + seyrek kıvılcım; en az yorucu
Seviye: hepsi bugünkü döngünün ORTALAMA anlık K'sına eşit (adil kıyas; oyunda BEAM_SFX_DB -7,5 aynen). Sınırlayıcı yok.
Videolar: yildirim_video_run.ps1 kaydı (uğultu susturulur; A vuruşları / ilk çakış OYUNUN kendi sesi) + döngü bindirme: Godot 2D pan kuralı
(ortada kanal başına 0,5), uzaklık (1 - d / 1500), tikte 120 ms -4 dB çökme; ŞİMDİKİ'de oyundaki kare başı perde/ses titremesi ve dikiş
boşluğu da taklit edilir, adaylarda titreme YOK (hareket döngünün içinde; seçilirse kod titremesi kalkar).
Çalıştır: python tools/proto_20261019/yildirim_dongu_proto.py -> out/yildirim_dongu/ (L1..L3.wav döngü, *_onizleme.wav, rapor.txt,
dongu_simdiki/L1/L2/L3.mp4, dongu_hepsi.mp4). Oyuna bağlı DEĞİL.
"""

import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import yildirim_ses_proto as Y  # noqa: E402
import yildirim_video as V  # noqa: E402

sp = Y.sp
SR = Y.SR
L = 3.0
N = int(SR * L)
XF = int(SR * 0.25)
OUT = os.path.join(HERE, "out", "yildirim_dongu")
GAME_FPS = 60.0
LABELS = {"simdiki": "ŞİMDİKİ DÖNGÜ", "L1": "L1 - Derin Uğultu", "L2": "L2 - Cızırdayan Ark", "L3": "L3 - Akan Enerji"}


# ---------- dikişsiz yapı taşları ----------
def t_ext(n):
    return np.arange(n) / SR


def wrap(x):
    """N + XF uzunluğunda üretilmiş katman -> N; son XF başa eş güçlü çapraz geçişle (dikişsiz)."""
    out = x[:N].copy()
    w = np.linspace(0.0, np.pi / 2, XF)
    out[:XF] = x[:XF] * np.sin(w) + x[N:N + XF] * np.cos(w)
    return out


def fit(x, n):
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def noise_layer(seed, fn):
    r = np.random.RandomState(seed)
    return wrap(fit(fn(r, N + XF), N + XF))


def smooth_rand(seed, hz):
    """Dikişsiz yavaş rastgele kontrol sinyali (-1..1, sıfır ortalama)."""
    x = noise_layer(seed, lambda r, n: sp.fft_filter(r.randn(n), lp=hz, lp_order=2))
    x -= x.mean()
    return x / (np.abs(x).max() + 1e-9)


def qf(f):
    return max(1, round(f * L)) / L


def lfo(rate, phase=0.0):
    return np.sin(2 * np.pi * qf(rate) * np.arange(N) / SR + phase)


def tone(f0, harmonics, fm=None, fm_depth=0.0, odd_only=False, rolloff=1.0):
    """Periyodik ton: f0 = k/L, FM sapması sıfır ortalamalı -> faz döngü sonunda tam 2*pi*k (dikişsiz)."""
    f0 = qf(f0)
    f = np.full(N, f0)
    if fm is not None:
        dev = fm * fm_depth * f0
        f = f + (dev - dev.mean())
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.zeros(N)
    for h in range(1, harmonics + 1):
        if odd_only and h % 2 == 0:
            continue
        x += np.where(h * f < SR * 0.45, np.sin(h * ph) / h ** rolloff, 0.0)
    return x


def crackle_layer(seed, rate, hp, lp):
    return noise_layer(seed, lambda r, n: Y.crackle(r, n / SR, rate, 1.0e9, hp=hp, lp=lp))


def band_noise(seed, hp, lp):
    return noise_layer(seed, lambda r, n: sp.fft_filter(r.randn(n), hp=hp, lp=lp, hp_order=2, lp_order=2))


def moving_band(seed, center_fn, q_oct=0.45, lp=6000):
    """Gezinen rezonanslı gürültü (STFT, Hann pencere, 1/4 adım): her çerçevede merkez frekansı etrafında log-Gauss bant."""
    def fn(r, n):
        x = r.randn(n)
        win, hop = 1024, 256
        w = np.hanning(win)
        f = np.maximum(np.fft.rfftfreq(win, 1.0 / SR), 1.0)
        out = np.zeros(n + win)
        centers = center_fn(np.arange(n) / SR)
        for i in range(0, n - win, hop):
            fc = centers[i + win // 2]
            g = np.exp(-0.5 * (np.log2(f / fc) / q_oct) ** 2) / np.sqrt(1.0 + (f / lp) ** 4)
            out[i:i + win] += np.fft.irfft(np.fft.rfft(x[i:i + win] * w) * g, n=win) * w
        return out[:n] / 1.5
    return noise_layer(seed, fn)


def circ_filter(x, hp=None, lp=None, hp_order=2, lp_order=2):
    """Döngü üzerinde dairesel süzgeç (dikiş bozulmaz)."""
    X = np.fft.rfft(x)
    f = np.maximum(np.fft.rfftfreq(len(x), 1.0 / SR), 1e-3)
    g = np.ones_like(f)
    if hp:
        g *= 1.0 / np.sqrt(1.0 + (hp / f) ** (2 * hp_order))
    if lp:
        g *= 1.0 / np.sqrt(1.0 + (f / lp) ** (2 * lp_order))
    return np.fft.irfft(X * g, n=len(x))


def db(v):
    return 10 ** (v / 20)


def norm_rms(x):
    return x / (np.sqrt(np.mean(x ** 2)) + 1e-12)


# ---------- adaylar ----------
def loop_l1():
    """Derin Uğultu: sıcak testere (100 Hz) + vuruşan ikinci ses, yavaş nabız + titreşim, seyrek kıvılcım, hafif cızırtı."""
    fm = smooth_rand(11, 3.0)
    a = tone(100.0, 32, fm=fm, fm_depth=0.012, rolloff=1.0)
    b = tone(100.0 + 1.0 / L, 32, fm=fm, fm_depth=0.012, rolloff=1.15)
    buzz = circ_filter(a + 0.7 * b, hp=150, lp=3000, hp_order=2, lp_order=2)  # temel 100 Hz inceltilir (dizüstünde çamur olmasın)
    pulse = 1.0 + 0.16 * lfo(1.33) + 0.07 * lfo(7.0, 1.0) + 0.08 * smooth_rand(12, 2.0)
    sizzle = band_noise(13, 1500, 5000) * (0.55 + 0.45 * np.abs(np.sin(np.pi * qf(100.0) * np.arange(N) / SR)))
    x = (norm_rms(buzz) * pulse * db(0) + norm_rms(crackle_layer(14, 110, 2200, 7000)) * db(-13)
         + norm_rms(sizzle) * db(-17))
    return circ_filter(x, hp=60, lp=9000)


def loop_l2():
    """Cızırdayan Ark: kesik kesik kare dalga vızıltı + sık çıtırtı + şebeke cızırtısı, dalgalanan şiddet."""
    fm = smooth_rand(21, 8.0)
    sq = circ_filter(tone(125.0, 45, fm=fm, fm_depth=0.04, odd_only=True, rolloff=1.0), hp=150, lp=6500)
    gate = smooth_rand(22, 55.0)
    gate = np.clip(0.55 + 0.9 * gate, 0.15, 1.0)
    swell = 1.0 + 0.22 * smooth_rand(23, 1.2)
    mains = band_noise(24, 3000, 6500) * (0.4 + 0.6 * np.abs(np.sin(np.pi * qf(125.0) * np.arange(N) / SR)) ** 4)
    x = (norm_rms(sq) * gate * swell * db(0) + norm_rms(crackle_layer(25, 520, 2000, 8500)) * swell * db(-5)
         + norm_rms(mains) * db(-14))
    return circ_filter(x, hp=110, lp=8500)


def loop_l3():
    """Akan Enerji: gezinen rezonanslı plazma akışı + alçak tok uğultu (vuruşan) + seyrek kıvılcım + ince ışıltı."""
    slow = smooth_rand(31, 0.9)
    tt = np.arange(N) / SR

    def centers(t):
        n = len(t)
        s = np.interp(np.arange(n) % N, np.arange(N), slow)
        return 950.0 * 2.0 ** (0.85 * np.sin(2 * np.pi * qf(0.67) * t) + 0.35 * s)
    flow = moving_band(32, centers)
    hum = circ_filter(tone(80.0, 8, rolloff=1.1) + 0.6 * tone(80.0 + 2.0 / L, 6, rolloff=1.3), hp=110)
    hum = hum * (1.0 + 0.12 * lfo(0.67, 0.5))
    shimmer = band_noise(33, 5000, 8500) * (0.6 + 0.4 * lfo(2.0))
    x = (norm_rms(flow) * db(0) + norm_rms(hum) * db(-1) + norm_rms(crackle_layer(34, 70, 2500, 7500)) * db(-14)
         + norm_rms(shimmer) * db(-21))
    return circ_filter(x, hp=55, lp=8500)


LOOPS = {"L1": loop_l1, "L2": loop_l2, "L3": loop_l3}


# ---------- ölçüm ----------
def mean_k(x, reps=3):
    """Döngünün ortalama anlık K'sı (0,4 sn pencere, 0,1 sn adım, ENERJİ ortalaması) - döngü seviyesi için."""
    y = sp.k_weight(np.tile(x, reps)) ** 2
    w, h = int(SR * 0.4), int(SR * 0.1)
    c = np.concatenate([[0.0], np.cumsum(y)])
    vals = [(c[i + w] - c[i]) / w for i in range(0, len(y) - w + 1, h)]
    return 10 * np.log10(np.mean(vals) + 1e-12)


def seam_report(x):
    d = np.abs(np.diff(x))
    jump = abs(x[0] - x[-1])
    e = lambda s: 20 * np.log10(np.sqrt(np.mean(s ** 2)) + 1e-12)
    return f"dikiş sıçraması {jump:.4f} (fark p99 {np.percentile(d, 99):.4f}, en büyük {d.max():.4f}) | ilk/son 20 ms {e(x[:882]):.1f}/{e(x[-882:]):.1f} dB"


# ---------- oyun gibi döngü izi ----------
def godot_pan(off, screen_w):
    """Godot 4 AudioStreamPlayer2D: çarpan (1 - d / max_distance); pan = x / ekran_genişliği (+0,5), sol 1 - pan, sağ pan."""
    dist = np.hypot(off[0], off[1]) / V.CANVAS_SCALE
    mult = max(0.0, 1.0 - dist / V.MAX_DIST)
    pan = float(np.clip(off[0] / screen_w + 0.5, 0.0, 1.0))
    return mult * (1.0 - pan), mult * pan


def loop_track(loop, ev, t0, n, screen_w, legacy, rng):
    """Her ışın kilitlenmede döngüyü baştan çalar, sonunda keser (5 ms rampa). legacy: kare başı perde/ses titremesi + dikiş boşluğu."""
    out = np.zeros((n, 2))
    tt = np.arange(n) / SR
    g_db = np.zeros(n)
    for e in ev:
        if e["t"] == "tick":
            ts = e["f"] / V.FPS - t0
            m = (tt >= ts) & (tt < ts + Y.DUCK_SEC)
            g_db[m] = np.minimum(g_db[m], Y.DUCK_DB * (1.0 - (tt[m] - ts) / Y.DUCK_SEC) ** 2)
    duck = 10 ** (g_db / 20)
    ends = {e["id"]: e["f"] for e in ev if e["t"] == "end"}
    gap = int(SR / GAME_FPS)
    src = np.concatenate([loop, np.zeros(gap)]) if legacy else loop
    for e in ev:
        if e["t"] != "lock":
            continue
        s = max(0, int((e["f"] / V.FPS - t0) * SR))
        stop = min(n, int((ends[e["id"]] / V.FPS - t0) * SR)) if e["id"] in ends else n
        if stop <= s:
            continue
        m = stop - s
        if legacy:
            frames = int(m / SR * GAME_FPS) + 2
            p = np.empty(frames)
            v = np.empty(frames)
            pc, vc = 1.0, Y.HUM_DB_NEW
            for k in range(frames):
                pc = pc + (rng.uniform(0.94, 1.08) - pc) * 0.4
                vc = vc + (Y.HUM_DB_NEW + rng.uniform(-1.5, 1.5) - vc) * 0.4
                p[k], v[k] = pc, vc
            fr = np.arange(m) / SR * GAME_FPS
            pitch = np.interp(fr, np.arange(frames), p)
            vol = 10 ** (np.interp(fr, np.arange(frames), v) / 20)
        else:
            pitch = np.ones(m)
            vol = np.full(m, 10 ** (Y.HUM_DB_NEW / 20))
        pos = np.concatenate([[0.0], np.cumsum(pitch)[:-1]]) % len(src)
        i0 = np.floor(pos).astype(int)
        fr_ = pos - i0
        seg = src[i0] * (1 - fr_) + src[(i0 + 1) % len(src)] * fr_
        r = min(m // 2, int(SR * 0.005))
        seg[:r] *= np.linspace(0, 1, r)
        seg[-r:] *= np.linspace(1, 0, r)
        lg, rg = godot_pan(e["off"], screen_w)
        out[s:stop, 0] += seg * vol * duck[s:stop] * lg
        out[s:stop, 1] += seg * vol * duck[s:stop] * rg
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    hum = Y.decode_mp3("assets/audio/lightning/electric_loop.mp3")
    target = mean_k(hum)
    lines = ["Yıldırım Asası DÖNGÜ prototipleri - ölçüm", ""]
    lines.append(sp.analyze(np.tile(hum, 2), "şimdiki (electric_loop)") + f" | ortalama K {target:.1f}")
    loops = {"simdiki": hum}
    for key, fn in LOOPS.items():
        x = fn()
        x *= 10 ** ((target - mean_k(x)) / 20)
        peak = np.abs(x).max()
        note = ""
        if peak > 0.89:
            x *= 0.89 / peak
            note = f" (tepe sınırı: {20 * np.log10(0.89 / peak):.1f} dB kısık)"
        loops[key] = x
        sp.save(os.path.join(OUT, f"{key}.wav"), x)
        sp.save(os.path.join(OUT, f"{key}_onizleme.wav"), np.tile(x, 3))
        lines.append(sp.analyze(np.tile(x, 2), f"{key} - {LABELS[key][5:]}") + f" | ortalama K {mean_k(x):.1f}{note}")
        lines.append("    " + seam_report(x))
    sp.save(os.path.join(OUT, "simdiki_onizleme.wav"), np.tile(hum, 6))
    # --- videolar ---
    avi = os.path.join(V.CAP, "yakalama.avi")
    with open(os.path.join(V.CAP, "olaylar.json"), encoding="utf-8") as f:
        log = json.load(f)
    screen_w = float(log["viewport"][0])
    nf = V.avi_frames(avi)
    off = 1
    start_f = log["rec_start"] - off
    end_f = min(log["end"] - off, nf - 1)
    t0 = start_f / V.FPS - V.LEAD
    dur = (end_f - start_f) / V.FPS + V.LEAD
    bed_path = os.path.join(V.CAP, "oyun_sesi.wav")
    V.run(["-i", avi, "-vn", "-ac", "2", "-ar", str(SR), "-acodec", "pcm_s16le", bed_path])
    bed = V.read_stereo(bed_path)[int(t0 * SR): int(t0 * SR) + int(dur * SR)]
    ev = [dict(e, f=e["f"] - off) for e in log["events"]]
    mixes = {}
    for key, lp in loops.items():
        mixes[key] = bed + loop_track(lp, ev, t0, len(bed), screen_w, key == "simdiki", np.random.RandomState(5))
    common = 0.89 / max(np.abs(m).max() for m in mixes.values())
    lines += ["", f"Videolar ortak kazanç {20 * np.log10(common):+.1f} dB (yatak = oyunun kendi sesi: A vuruşları + ilk çakış, uğultu susturulmuş)"]
    font = "C\\:/Windows/Fonts/arialbd.ttf"
    vids = []
    for key, m in mixes.items():
        wav = os.path.join(V.CAP, f"dongu_{key}.wav")
        V.write_stereo(wav, m * common)
        mp4 = os.path.join(OUT, f"dongu_{key}.mp4")
        vf = (f"trim=start_frame={start_f}:end_frame={end_f},setpts=PTS-STARTPTS,tpad=start_duration={V.LEAD}:start_mode=clone,"
              f"crop=640:360:640:360,scale=1280:720:flags=neighbor,"
              f"drawtext=fontfile='{font}':text='{LABELS[key]}':x=24:y=20:fontsize=34:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=12")
        V.run(["-i", avi, "-i", wav, "-filter_complex", f"[0:v]{vf}[v]", "-map", "[v]", "-map", "1:a", "-c:v", "libx264", "-preset",
               "medium", "-crf", "20", "-pix_fmt", "yuv420p", "-r", str(V.FPS), "-c:a", "aac", "-b:a", "192k", "-shortest",
               "-movflags", "+faststart", mp4])
        vids.append(mp4)
        lines.append(f"  dongu_{key}.mp4 {dur:.1f} sn, tepe {np.abs(m * common).max():.2f}, anlık K maks {sp.max_momentary_db((m * common).mean(axis=1)):.1f}")
    lst = os.path.join(V.CAP, "dongu_liste.txt")
    with open(lst, "w", encoding="utf-8", newline="\n") as f:
        for v in vids:
            f.write("file '" + v.replace("\\", "/") + "'\n")
    V.run(["-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", "-movflags", "+faststart", os.path.join(OUT, "dongu_hepsi.mp4")])
    with open(os.path.join(OUT, "rapor.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    if "--sadece-ses" in sys.argv:
        os.makedirs(OUT, exist_ok=True)
        hum = Y.decode_mp3("assets/audio/lightning/electric_loop.mp3")
        print(sp.analyze(np.tile(hum, 2), "şimdiki") + f" | ortalama K {mean_k(hum):.1f}")
        for key, fn in LOOPS.items():
            x = fn()
            x *= 10 ** ((mean_k(hum) - mean_k(x)) / 20)
            print(sp.analyze(np.tile(x, 2), key) + f" | tepe {np.abs(x).max():.2f}")
            print("    " + seam_report(x))
    else:
        main()
