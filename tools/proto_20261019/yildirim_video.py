"""Yıldırım Asası ses VİDEOLARI (2026-10-19, madde 294): yildirim_video_run.ps1'in gerçek oyun yakalamasına (AVI, eski uğultu + ortak ateş
sesi susturulmuş; yaratık ölümü/ortam sesleri duruyor) dört ses sürümünü bindirir ve MP4 yapar:
  simdiki.mp4 : bugünkü hâl (uğultu -4,5 dB hedefte + her tikte fire.mp3 -10 dB oyuncuda)
  A.mp4 / B.mp4 / C.mp4 : uğultu -7,5 dB + tikte 120 ms -4 dB çökme + hedefte tik / kritik / kilit sesleri (parcalar/*.wav)
  hepsi.mp4   : dördü arka arkaya, sol üstte etiketli
Konumlu ses Godot AudioStreamPlayer2D gibi: çarpan (1 - uzaklık / 1500), sağ-sol kaydırma ekran konumundan (olaylar.json "off").
Dört sürüm AYNI ortak kazançla (en yüksek tepe 0,89; sınırlayıcı yok). Gerekir: numpy, miniaudio, imageio-ffmpeg.
Çalıştır: python tools/proto_20261019/yildirim_video.py  -> tools/proto_20261019/out/yildirim_video/
  --gercek : yakalama YV_REAL=1 ile alındıysa (oyuna bağlı sesler) AVI sesi olduğu gibi -> oyunda_A.mp4 (bindirme yok)
"""

import json
import os
import subprocess
import sys
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import yildirim_ses_proto as Y  # noqa: E402

sp = Y.sp
SR = Y.SR
CAP = os.path.join(os.environ.get("TEMP", HERE), "yildirim_video_cap")
OUT = os.path.join(HERE, "out", "yildirim_video")
PARTS = os.path.join(HERE, "out", "yildirim_ses", "parcalar")
FPS = 60
MAX_DIST = 1500.0      # fx_lightning_beam.tscn / player.tscn max_distance
CANVAS_SCALE = 2.0     # ekran ofseti / dünya ofseti (olaylar.json: slime (95,-35) -> (190,-70))
LEAD = 0.5
LABELS = {"simdiki": "ŞİMDİKİ", "A": "A - Çatırtı + Küt Darbe", "B": "B - Tesla Zap", "C": "C - Gök Gürültüsü"}


def ffmpeg():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def run(args):
    r = subprocess.run([ffmpeg(), "-hide_banner", "-loglevel", "error", "-y"] + args, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(r.stderr)


def avi_frames(avi):
    r = subprocess.run([ffmpeg(), "-hide_banner", "-i", avi, "-map", "0:v", "-c", "copy", "-f", "null", "-"],
                       capture_output=True, text=True)
    import re
    m = re.findall(r"frame=\s*(\d+)", r.stderr)
    return int(m[-1]) if m else -1


def read_stereo(path):
    with wave.open(path, "rb") as w:
        assert w.getframerate() == SR and w.getnchannels() == 2 and w.getsampwidth() == 2
        d = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
    return d.reshape(-1, 2)


def write_stereo(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def pos_gains(off, screen_w):
    """AudioStreamPlayer2D benzeri: (1 - d / max) uzaklık çarpanı + ekran x'inden kaydırma (sol, sağ)."""
    ox, oy = off
    dist = np.hypot(ox, oy) / CANVAS_SCALE
    mult = max(0.0, 1.0 - dist / MAX_DIST)
    pan = float(np.clip(2.0 * ox / screen_w, -1.0, 1.0)) * 0.5
    return mult * (1.0 - pan), mult * (1.0 + pan)


def place_st(buf, sig, t, gain, lr):
    s = int(round(t * SR))
    e = min(len(buf), s + len(sig))
    if e <= s or s < 0:
        return
    buf[s:e, 0] += sig[: e - s] * gain * lr[0]
    buf[s:e, 1] += sig[: e - s] * gain * lr[1]


def build(version, ev, bed, t0, screen_w, hum, fire, parts):
    """t0 = kesitin başlangıcı (sn, AVI zamanı); olay zamanları kare/FPS."""
    out = bed.copy()
    n = len(out)
    rng = np.random.RandomState(11)
    new = version != "simdiki"
    hum_db = Y.HUM_DB_NEW if new else Y.HUM_DB_NOW
    ticks = [e for e in ev if e["t"] == "tick"]
    # Uğultu: her ışın kilitlenmede baştan başlar, sonunda kesilir (10 ms yumuşak kenar); tikte çökme (yalnız yeni sürümlerde).
    duck = np.ones(n)
    if new:
        tt = np.arange(n) / SR
        g_db = np.zeros(n)
        for e in ticks:
            ts = e["f"] / FPS - t0
            m = (tt >= ts) & (tt < ts + Y.DUCK_SEC)
            g_db[m] = np.minimum(g_db[m], Y.DUCK_DB * (1.0 - (tt[m] - ts) / Y.DUCK_SEC) ** 2)
        duck = 10 ** (g_db / 20)
    ends = {e["id"]: e["f"] for e in ev if e["t"] == "end"}
    last_lock = -1.0e9
    for e in ev:
        if e["t"] != "lock":
            continue
        s = max(0, int((e["f"] / FPS - t0) * SR))
        stop = min(n, int((ends.get(e["id"], 10 ** 9) / FPS - t0) * SR)) if e["id"] in ends else n
        if stop <= s:
            continue
        seg = np.tile(hum, (stop - s) // len(hum) + 1)[: stop - s].copy()
        f = min(len(seg) // 2, int(SR * 0.01))
        seg[:f] *= np.linspace(0, 1, f)
        seg[-f:] *= np.linspace(1, 0, f)
        l, r = pos_gains(e["off"], screen_w)
        g = 10 ** (hum_db / 20) * duck[s:stop]
        out[s:stop, 0] += seg * g * l
        out[s:stop, 1] += seg * g * r
        if new and e["f"] / FPS - last_lock >= Y.STRIKE_GAP:  # A: ilk çakış en fazla 0,5 sn'de bir
            last_lock = e["f"] / FPS
            sig, gain = parts["kilit"]
            place_st(out, sig, e["f"] / FPS - t0, gain, (l, r))
    last = -1
    for e in ticks:
        ts = e["f"] / FPS - t0
        if not new:
            place_st(out, Y.resample(fire, rng.uniform(0.92, 1.08)), ts, 10 ** (Y.FIRE_DB / 20), (1.0, 1.0))
            continue
        lr = pos_gains(e["off"], screen_w)
        if e["crit"]:
            sig, gain = parts["kritik"]
        else:
            k = rng.randint(len(parts["tik"]))
            if k == last:
                k = (k + 1) % len(parts["tik"])
            last = k
            sig, gain = parts["tik"][k]
        place_st(out, Y.resample(sig, rng.uniform(0.94, 1.06)), ts, gain, lr)
    return out


def load_parts(key):
    def ld(name, game_k):
        x = sp.read_mono(os.path.join(PARTS, f"{key}_{name}.wav"))
        return x, Y.k_gain(x, game_k)
    return {"tik": [ld(f"tik_{i}", Y.TICK_GAME_K) for i in range(1, 5)], "kritik": ld("kritik", Y.CRIT_GAME_K),
            "kilit": ld("kilit", Y.lock_k(key))}


def main():
    os.makedirs(OUT, exist_ok=True)
    avi = os.path.join(CAP, "yakalama.avi")
    with open(os.path.join(CAP, "olaylar.json"), encoding="utf-8") as f:
        log = json.load(f)
    ev = log["events"]
    screen_w = float(log["viewport"][0])
    nf = avi_frames(avi)
    # AVI karesi k <-> oyun karesi k + 1 (Movie Maker her yinelemede bir kare + 1/60 sn ses yazar; get_process_frames 1'den başlar).
    off = 1
    print(f"AVI {nf} kare, yakalama {log['rec_start']} -> {log['end']} (oyun karesi)")
    ## Kesit ilk kilitlenme karesinden (slime'lar o karede doğar) başlar; öne LEAD sn ilk karenin kopyası eklenir ki ilk çakış sesi
    ## videonun en başında kesilmesin (ses: o anki oyun sesi).
    start_f = log["rec_start"] - off
    end_f = min(log["end"] - off, nf - 1)
    t0 = start_f / FPS - LEAD
    dur = (end_f - start_f) / FPS + LEAD
    bed_path = os.path.join(CAP, "oyun_sesi.wav")
    run(["-i", avi, "-vn", "-ac", "2", "-ar", str(SR), "-acodec", "pcm_s16le", bed_path])
    bed_all = read_stereo(bed_path)
    bed = bed_all[int(t0 * SR): int(t0 * SR) + int(dur * SR)]
    # olay karelerini AVI karesine çevir
    ev = [dict(e, f=e["f"] - off) for e in ev]
    if "--gercek" in sys.argv:
        mp4 = os.path.join(OUT, "oyunda_A.mp4")
        vf = (f"trim=start_frame={start_f}:end_frame={end_f},setpts=PTS-STARTPTS,tpad=start_duration={LEAD}:start_mode=clone,"
              f"crop=640:360:640:360,scale=1280:720:flags=neighbor,drawtext=fontfile='C\\:/Windows/Fonts/arialbd.ttf':"
              f"text='OYUNDA (A + ilk çakış)':x=24:y=20:fontsize=34:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=12")
        wav = os.path.join(CAP, "oyunda.wav")
        write_stereo(wav, bed * (0.89 / max(1e-9, np.abs(bed).max())))
        run(["-i", avi, "-i", wav, "-filter_complex", f"[0:v]{vf}[v]", "-map", "[v]", "-map", "1:a", "-c:v", "libx264", "-preset",
             "medium", "-crf", "20", "-pix_fmt", "yuv420p", "-r", str(FPS), "-c:a", "aac", "-b:a", "192k", "-shortest",
             "-movflags", "+faststart", mp4])
        print(f"oyun sesi tepe {np.abs(bed).max():.3f} (Master 0 dB), anlık K maks {sp.max_momentary_db(bed.mean(axis=1)):.1f} dB -> {mp4}")
        return
    hum = Y.decode_mp3("assets/audio/lightning/electric_loop.mp3")
    fire = Y.decode_mp3("assets/audio/fire.mp3")
    mixes = {"simdiki": build("simdiki", ev, bed, t0, screen_w, hum, fire, None)}
    for key in ("A", "B", "C"):
        mixes[key] = build(key, ev, bed, t0, screen_w, hum, fire, load_parts(key))
    common = 0.89 / max(np.abs(m).max() for m in mixes.values())
    print(f"ortak kazanç {20 * np.log10(common):+.1f} dB, oyun sesi (yatak) tepe {np.abs(bed).max():.3f}")
    font = "C\\:/Windows/Fonts/arialbd.ttf"
    vids = []
    for key, m in mixes.items():
        wav = os.path.join(CAP, f"karisim_{key}.wav")
        write_stereo(wav, m * common)
        mp4 = os.path.join(OUT, f"{key}.mp4")
        label = LABELS[key].replace(":", "\\:")
        ## Oyun penceresi 1920x1080: oyuncunun çevresi (640x360, slime'lar ekran ofseti <= 250 px) tam 2x yakınlaştırılır (piksel bozulmaz),
        ## HUD / debug FPS yazısı kadrajın dışında kalır.
        vf = (f"trim=start_frame={start_f}:end_frame={end_f},setpts=PTS-STARTPTS,tpad=start_duration={LEAD}:start_mode=clone,crop=640:360:640:360,scale=1280:720:flags=neighbor,"
              f"drawtext=fontfile='{font}':text='{label}':x=24:y=20:fontsize=34:fontcolor=white:"
              f"box=1:boxcolor=black@0.55:boxborderw=12")
        run(["-i", avi, "-i", wav, "-filter_complex", f"[0:v]{vf}[v]", "-map", "[v]", "-map", "1:a",
             "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p", "-r", str(FPS),
             "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", mp4])
        vids.append(mp4)
        k = sp.max_momentary_db((m * common).mean(axis=1))
        print(f"  {key}.mp4  {dur:.1f} sn, ses tepe {np.abs(m * common).max():.2f}, anlık K maks {k:.1f} dB")
    lst = os.path.join(CAP, "liste.txt")
    with open(lst, "w", encoding="utf-8", newline="\n") as f:
        for v in vids:
            f.write("file '" + v.replace("\\", "/") + "'\n")
    run(["-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", "-movflags", "+faststart", os.path.join(OUT, "hepsi.mp4")])
    print("BITTI", OUT)


if __name__ == "__main__":
    main()
