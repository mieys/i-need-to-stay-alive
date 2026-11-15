"""FRAGMAN SAHNE 1 v2 kurgusu ("Asla yalnız değilsin"): sahne1.ps1 çıktısı -> 1920x1080 60 kare/sn mp4.

Kullanım:  python -I tools/tanitim/sahne_kurgu.py [--dil tr|en] [--onizleme]
Çıktı:     tools/tanitim/out/sahne1_<dil>.mp4      (--onizleme: yalnız %TEMP%/tanitim_cap/sahne1/onizleme.jpg kare sayfası)

Girdi (%TEMP%/tanitim_cap/sahne1): kareler/sahne/*.jpg (gerçek zamanlı, değişken aralık), zaman.json (t_us, kare başı hp / ts / hit,
rec_T0, sig = olayların duvar zamanı), ses.wav. Ağır çekim oyunun içinde çekildi (Engine.time_scale) - burada hız değiştirilmez.
Duygu katmanı (hepsi olay zamanlarına bağlı):
- renk: ruh hâline göre doygunluk (yalnızken solgun, Talon gelince renk döner, kalabalıkta yine solar, zaferde canlı) + sıcak ton + vinyet
- can azken kalp atışı ritminde kırmızı kenar + her gerçek isabette kırmızı tık (kubbe açılınca söner)
- beyaz parlama + sarsıntı: Talon'un hamlesi, kubbenin inişi, meteor; kalabalık girerken hafif titreme
- sinematik siyah bant: ağır çekim anlarında (yardım, bakışma, meteor)
- yazılar: oyunun m5x7 yazısı (kurgu.py text_block) - "Tek başına..." / "...ama asla yalnız değil." / "Onlar kalabalık." / "Biz birlikteyiz."
- ses: oyun sesi (ağır çekimde boğuk + kısık), rüzgâr, oyunun kendi aksan sesleri, kapanışta başlangıç sesi; kapanış kartı POTPOURRI
"""
import argparse
import bisect
import json
import math
import os
import subprocess
import sys
from concurrent.futures import ProcessPoolExecutor

import imageio_ffmpeg
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kurgu as K  # noqa: E402  (m5x7 piksel yazı + palet: önceki fragmanlarla aynı dil)

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
CAP = os.path.join(os.environ.get("TEMP", "."), "tanitim_cap", "sahne1")
OUT_DIR = os.path.join(HERE, "out")
SFX = os.path.join(ROOT, "assets", "audio")
W, H, FPS = 1920, 1080, 60
CARD_DUR = 4.6

TEXTS = {
    "tr": {"c1": "Tek başına...", "c2": "...ama asla yalnız değil.", "c3": "Onlar kalabalık.", "c4": "Biz birlikteyiz.",
           "alt": "8 kişiye kadar co-op", "cta": "YAKINDA"},
    "en": {"c1": "Alone...", "c2": "...but never on her own.", "c3": "They are many.", "c4": "We stand together.",
           "alt": "Co-op for up to 8", "cta": "COMING SOON"},
}

# ───────────────────────────── zaman çizelgesi ─────────────────────────────

Z = None
EV = {}


def load():
    global Z, EV
    Z = json.load(open(os.path.join(CAP, "zaman.json"), encoding="utf-8"))
    t0 = float(Z.get("rec_T0", 0.0))
    EV = {k: float(v) - t0 for k, v in Z.get("sig", {}).items() if float(v) >= 0.0}


def ev(name, default=None):
    return EV.get(name, default)


def kf(v, keys):
    """Doğrusal anahtar kareler: [(t, değer), ...] (None zamanlı anahtarlar atlanır)."""
    ks = sorted((t, x) for t, x in keys if t is not None)
    if not ks:
        return 0.0
    if v <= ks[0][0]:
        return ks[0][1]
    for (ta, xa), (tb, xb) in zip(ks, ks[1:]):
        if v <= tb:
            f = (v - ta) / max(1e-6, tb - ta)
            return xa + (xb - xa) * f
    return ks[-1][1]


def win(v, a, b, ramp=0.25):
    """[a,b] penceresinde 1, kenarlarda yumuşak geçiş."""
    if a is None or b is None:
        return 0.0
    if v < a - ramp or v > b + ramp:
        return 0.0
    if v < a:
        x = (v - (a - ramp)) / ramp
    elif v > b:
        x = 1.0 - (v - b) / ramp
    else:
        return 1.0
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


def pulse(v, at, dur, peak):
    if at is None or v < at or v > at + dur:
        return 0.0
    x = (v - at) / dur
    return peak * (1.0 - x) ** 2


def plus(a, b):
    return None if a is None else a + b


def params(v, hp, hits):
    """Bir çıktı karesinin tüm efekt değerleri."""
    help_, tq, horde, blink, dome = ev("help"), ev("talon_q"), ev("horde"), ev("blink"), ev("dome")
    look, impact = ev("look"), ev("impact")
    desat = kf(v, [(0.0, 0.10), (5.0, 0.36), (help_, 0.55), (plus(help_, 2.2), 0.5), (tq, 0.5), (plus(tq, 0.35), 0.12),
                   (plus(horde, 0.6), 0.18), (plus(horde, 2.4), 0.46), (blink, 0.42), (plus(dome, 0.15), 0.14),
                   (look, 0.24), (plus(impact, -0.2), 0.24), (plus(impact, 0.4), -0.04), (plus(impact, 3.0), -0.16)])
    dark = kf(v, [(0.0, 0.30), (5.0, 0.42), (help_, 0.60), (plus(help_, 2.2), 0.5), (plus(tq, 0.35), 0.30), (plus(horde, 2.4), 0.52),
                  (plus(dome, 0.15), 0.34), (look, 0.52), (plus(impact, 0.4), 0.30), (plus(impact, 3.0), 0.26)])
    ## can azken kalp atışı (72 nabız: çift vuruş) - kubbe açılınca koruma altında, söner
    red = 0.0
    protected = dome is not None and v > dome + 0.2
    if hp < 0.32:
        p = (v % 0.83)
        beat = max(math.exp(-((p - 0.0) / 0.055) ** 2), 0.65 * math.exp(-((p - 0.21) / 0.055) ** 2))
        lvl = (0.32 - hp) / 0.32
        red = (0.18 + 0.5 * beat) * lvl * (0.25 if protected else 1.0)
    if not protected:
        i = bisect.bisect_right(hits, v) - 1
        if i >= 0 and v - hits[i] < 0.22:
            red = max(red, 0.4 * (1.0 - (v - hits[i]) / 0.22))
    if impact is not None and v > impact + 0.3:
        red = 0.0
    flash = max(pulse(v, plus(tq, 0.05), 0.16, 0.45), pulse(v, plus(dome, 0.04), 0.24, 0.62), pulse(v, impact, 0.28, 0.5))
    bars = max(win(v, plus(help_, -0.1), plus(help_, 2.3)), win(v, look, plus(look, 2.5)), win(v, impact, plus(impact, 2.0)))
    ## sarsıntı (px): zarf x gürültü
    amp = 0.0
    for at, a, d in ((plus(tq, 0.05), 10.0, 0.4), (plus(dome, 0.04), 16.0, 0.6), (impact, 13.0, 1.8), (plus(horde, 0.15), 4.0, 0.9)):
        if at is not None and at <= v <= at + d:
            amp = max(amp, a * (1.0 - (v - at) / d) ** 1.5)
    dx = int(round(amp * (math.sin(v * 91.3) + 0.6 * math.sin(v * 53.7 + 1.3)) / 1.6))
    dy = int(round(amp * (math.sin(v * 77.9 + 0.7) + 0.6 * math.sin(v * 41.1 + 2.1)) / 1.6))
    caps = []
    for key, a, b in (("c1", 1.5, 4.7), ("c2", plus(tq, 0.7), plus(tq, 3.5)), ("c3", plus(horde, 1.5), plus(ev("sov_run"), -0.2)),
                      ("c4", plus(dome, 0.9), plus(dome, 3.7))):
        al = win(v, a, b, 0.35)
        if al > 0.0:
            caps.append((key, al))
    return {"desat": desat, "dark": dark, "red": red, "flash": flash, "bars": bars, "dx": dx, "dy": dy, "caps": caps}


# ───────────────────────────── kare işleme (işçi süreçler) ─────────────────────────────

_G = {}


def _init_worker(lang):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    r = np.sqrt(((xx - W / 2) / (W * 0.6)) ** 2 + ((yy - H / 2) / (H * 0.6)) ** 2)
    _G["vig"] = (np.clip((r - 0.5) / 0.65, 0, 1) ** 1.6)[..., None]
    _G["redm"] = (np.clip((r - 0.62) / 0.5, 0, 1) ** 1.5)[..., None] ## yalnız kenarlar
    _G["caps"] = {}
    t = TEXTS[lang]
    for key, color, scale in (("c1", K.C_TEXT, 6), ("c2", K.C_TEXT, 6), ("c3", K.C_TEXT, 6), ("c4", K.C_GOLD, 7)):
        blk = K.text_block([(t[key], color)], scale)
        a = np.asarray(blk, dtype=np.float32) / 255.0
        x = (W - blk.width) // 2
        y = int(905 - blk.height / 2)
        _G["caps"][key] = (a, x, y)
    _G["card"] = card_layer(lang)


def _grade(img, p):
    g = img @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    img = img + (g[..., None] - img) * p["desat"]
    img = (img - 0.5) * 1.05 + 0.5
    img *= np.array([1.03, 1.0, 0.95], dtype=np.float32)
    img *= (1.0 - p["dark"] * _G["vig"])
    if p["red"] > 0.003:
        m = _G["redm"] * p["red"]
        img = img * (1.0 - m) + m * np.array([0.62, 0.04, 0.05], dtype=np.float32)
    if p["flash"] > 0.003:
        img = img + (1.0 - img) * p["flash"]
    return img


def _finish(img, p):
    if p["dx"] or p["dy"]:
        rows = np.clip(np.arange(H) - p["dy"], 0, H - 1)
        cols = np.clip(np.arange(W) - p["dx"], 0, W - 1)
        img = img[rows][:, cols]
    for key, al in p["caps"]:
        a, x, y = _G["caps"][key]
        h, w = a.shape[:2]
        reg = img[y:y + h, x:x + w]
        aa = a[..., 3:4] * al
        img[y:y + h, x:x + w] = reg * (1.0 - aa) + a[..., :3] * aa
    bh = int(round(110 * p["bars"]))
    if bh > 0:
        img[:bh] = 0.0
        img[H - bh:] = 0.0
    return img


def render_frame(job):
    path, p, card = job
    img = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0
    img = _grade(img, p)
    img = _finish(img, p)
    if card is not None:
        img = img * (1.0 - card["dark"])
        if card["title"] > 0.0:
            a, x, y = _G["card"]
            aa = a[..., 3:4] * card["title"]
            img[y:y + a.shape[0], x:x + a.shape[1]] = img[y:y + a.shape[0], x:x + a.shape[1]] * (1.0 - aa) + a[..., :3] * aa
    return (np.clip(img, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8).tobytes()


def card_layer(lang):
    t = TEXTS[lang]
    title = K.text_block([("POTPOURRI", K.C_GOLD)], 13)
    alt = K.text_block([(t["alt"], K.C_TEXT)], 6)
    cta = K.text_block([(t["cta"], K.C_SOFT)], 5)
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for b, cy in ((title, 470), (alt, 610), (cta, 700)):
        lay.alpha_composite(b, ((W - b.width) // 2, int(cy - b.height / 2)))
    bbox = lay.getbbox()
    crop = lay.crop(bbox)
    return (np.asarray(crop, dtype=np.float32) / 255.0, bbox[0], bbox[1])


# ───────────────────────────── ana akış ─────────────────────────────

def jobs(lang):
    t = Z["t_us"]
    hp = Z.get("hp", [0.5] * len(t))
    hit_flags = Z.get("hit", [0] * len(t))
    hits = [t[i] / 1e6 for i in range(len(t)) if hit_flags[i]]
    dur = float(Z["dur"])
    n_scene = int(dur * FPS) - 2
    out = []
    for n in range(n_scene):
        v = n / FPS
        i = max(0, bisect.bisect_right(t, v * 1e6) - 1)
        p = params(v, hp[i], hits)
        card = None
        fade = (v - (dur - 0.9)) / 0.9
        if fade > 0:
            card = {"dark": 0.75 * min(1.0, fade), "title": 0.0 }
        if v < 0.6:
            card = {"dark": 1.0 - v / 0.6, "title": 0.0 }
        out.append((os.path.join(CAP, "kareler", "sahne", f"{i:05d}.jpg"), p, card))
    last = out[-1][0]
    p_last = params(dur, hp[-1], hits)
    p_last.update({"dx": 0, "dy": 0, "caps": [], "flash": 0.0, "bars": 0.0})
    for k in range(int(CARD_DUR * FPS)):
        c = k / FPS
        title = min(1.0, max(0.0, (c - 0.25) / 0.6))
        dark = 0.75 if c < CARD_DUR - 0.6 else 0.75 + 0.25 * (c - (CARD_DUR - 0.6)) / 0.6
        out.append((last, p_last, {"dark": min(1.0, dark), "title": title if c < CARD_DUR - 0.6 else title * (1 - (c - (CARD_DUR - 0.6)) / 0.6) }))
    return out, dur


def audio(lang, scene_dur, video_path, out_path):
    total = scene_dur + CARD_DUR
    tempo = (float(Z["audio_len"]) / float(Z["dur"])) if Z.get("audio_len") else 1.0
    slow = [(ev("help"), 2.3), (ev("talon_pre"), 1.2), (plus(ev("blink"), 0.08), 1.7), (ev("look"), 2.4), (ev("impact"), 2.0)]
    en = "+".join(f"between(t,{a:.3f},{a + d:.3f})" for a, d in slow if a is not None) or "0"
    ins = ["-i", video_path, "-i", os.path.join(CAP, "ses.wav"), "-stream_loop", "-1", "-i", os.path.join(SFX, "weather_wind_loop.wav")]
    stingers = [  # (dosya, olay zamanı, kazanç)
        ("events/ally_down.wav", plus(ev("help"), 0.05), 0.55),
        ("events/revive.wav", plus(ev("talon_q"), 0.1), 0.45),
        ("events/boss.wav", plus(ev("horde"), 0.2), 0.8),
        ("events/mission_warn.wav", plus(ev("sov_run"), 0.1), 0.35),
        ("shield_regen.wav", plus(ev("dome"), 0.05), 0.7),
        ("shield_damage.wav", plus(ev("dome"), 1.4), 0.5),
        ("shield_damage.wav", plus(ev("dome"), 2.1), 0.5),
        ("shield_damage.wav", plus(ev("dome"), 2.8), 0.55),
        ("events/mission_success.wav", plus(ev("impact"), 3.0), 0.6),
        ("başlangıç sesi.mp3", scene_dur + 0.2, 0.9),
    ]
    fc = [f"[1:a]atempo={tempo:.5f},aresample=48000,lowpass=f=950:enable='{en}',volume=0.5:enable='{en}',apad,atrim=0:{total:.3f}[g]",
          f"[2:a]aresample=48000,atrim=0:{total:.3f},volume=0.16,afade=t=in:d=1.2,afade=t=out:st={total - 1.0:.3f}:d=1.0[w]"]
    labels = ["[g]", "[w]"]
    k = 3
    for f, at, gain in stingers:
        if at is None:
            continue
        p = os.path.join(SFX, f)
        if not os.path.exists(p):
            print("ses yok:", f)
            continue
        ins += ["-i", p]
        ms = int(max(0.0, at) * 1000)
        fc.append(f"[{k}:a]aresample=48000,adelay={ms}|{ms},volume={gain}[s{k}]")
        labels.append(f"[s{k}]")
        k += 1
    fc.append("".join(labels) + f"amix=inputs={len(labels)}:normalize=0:duration=longest,atrim=0:{total:.3f},"
              f"afade=t=in:d=0.4,loudnorm=I=-15:TP=-1.5:LRA=11,aresample=48000[a]")
    cmd = [imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-hide_banner", "-loglevel", "warning"] + ins + [
        "-filter_complex", ";".join(fc), "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
        "-movflags", "+faststart", "-t", f"{total:.3f}", out_path]
    subprocess.run(cmd, check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dil", default="tr")
    ap.add_argument("--onizleme", action="store_true")
    a = ap.parse_args()
    load()
    print("olaylar:", {k: round(v, 2) for k, v in sorted(EV.items(), key=lambda x: x[1])})
    js, dur = jobs(a.dil)
    if a.onizleme:
        _init_worker(a.dil)
        picks = [js[int(len(js) * f)] for f in [i / 20 for i in range(20)]]
        sheet = Image.new("RGB", (384 * 5, 216 * 4))
        for n, j in enumerate(picks):
            im = Image.frombytes("RGB", (W, H), render_frame(j)).resize((384, 216), Image.LANCZOS)
            sheet.paste(im, ((n % 5) * 384, (n // 5) * 216))
        p = os.path.join(CAP, "onizleme.jpg")
        sheet.save(p, quality=88)
        print("onizleme:", p)
        return
    os.makedirs(OUT_DIR, exist_ok=True)
    vtmp = os.path.join(CAP, f"video_{a.dil}.mkv")
    ff = subprocess.Popen([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-hide_banner", "-loglevel", "warning",
                           "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                           "-vf", "scale=out_range=limited:out_color_matrix=bt709,format=yuv420p",
                           "-c:v", "libx264", "-preset", "medium", "-crf", "15",
                           "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv", vtmp],
                          stdin=subprocess.PIPE)
    with ProcessPoolExecutor(max_workers=max(2, (os.cpu_count() or 4) - 2), initializer=_init_worker, initargs=(a.dil,)) as ex:
        for n, buf in enumerate(ex.map(render_frame, js, chunksize=6)):
            ff.stdin.write(buf)
            if n % 300 == 0:
                print(f"kare {n}/{len(js)}", flush=True)
    ff.stdin.close()
    ff.wait()
    out = os.path.join(OUT_DIR, f"sahne1_{a.dil}.mp4")
    audio(a.dil, (len(js) / FPS) - CARD_DUR, vtmp, out)
    print("Hazir:", out, f"({os.path.getsize(out) / 1e6:.1f} MB, {len(js) / FPS:.1f} sn)")


if __name__ == "__main__":
    main()
