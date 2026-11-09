"""TANITIM VİDEOLARI kurgusu (2026-11-08): tools/tanitim/cek.ps1'in dikey (1080x1920) gerçek oyun çekimlerinden (Movie Maker AVI +
cekimler.json) Shorts / Reels / TikTok videoları yapar. Yazılar oyunun kendi m5x7 yazısıyla, oyunun paletiyle (hud_theme.gd: TEXT krem,
ACCENT altın, OUTLINE koyu kahve), piksel ızgarasında (16 punto çizilip tam sayı katla büyütülür). Ses = oyunun kendi sesi (müzik yok;
Music bus çekimde susturulur) -> platformda trend müzik eklenebilir.
Kullanım:
  python -I tools/tanitim/kurgu.py bak <plan>          : her çekimden kareler -> out/bak_<plan>.jpg (zamanlama seçmek için)
  python -I tools/tanitim/kurgu.py yap [kisa_ad ...]   : videolar -> out/<kisa_ad>_<dil>.mp4 (dil: tr, en)
Gerekir: Pillow, imageio-ffmpeg. AVI karesi k <-> oyun karesi k + 1 (yildirim_video.py ile aynı).
"""

import json
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
CAP = os.path.join(os.environ.get("TEMP", HERE), "tanitim_cap")
OUT = os.path.join(HERE, "out")
WORK = os.path.join(CAP, "_kurgu")
W, H, FPS = 1080, 1920, 60
FONT = os.path.join(ROOT, "assets", "fonts", "m5x7.ttf")
C_TEXT = (243, 230, 204)
C_GOLD = (240, 192, 112)
C_OUT = (32, 21, 13)
C_DEEP = (20, 14, 9)
C_SOFT = (226, 192, 138)
SFX = os.path.join(ROOT, "assets", "audio")


def ffmpeg():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def run(args):
    r = subprocess.run([ffmpeg(), "-hide_banner", "-loglevel", "error", "-y"] + args, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("ffmpeg hata:\n" + r.stderr[-3000:])


# ───────────────────────────── çekim verisi ─────────────────────────────

_SHOTS = {}


def coop_file():
    """Co-op çekimi (tanitim_coop.gd, gerçek zamanlı ~35 fps, değişken aralık) -> zaman damgasıyla 60 fps CFR mkv (+ ses, Dummy sürücünün
    yavaş karışımı yüzünden görüntü süresine esnetilir). Bir kez yapılır."""
    d = os.path.join(CAP, "coop")
    out = os.path.join(d, "coop.mkv")
    z = json.load(open(os.path.join(d, "zaman.json"), encoding="utf-8"))
    if os.path.exists(out) and os.path.getmtime(out) > os.path.getmtime(os.path.join(d, "zaman.json")):
        return out, z
    t = z["t_us"]
    lst = os.path.join(d, "kareler.ffconcat")
    with open(lst, "w", encoding="utf-8") as f:
        f.write("ffconcat version 1.0\n")
        for i in range(len(t)):
            dur = ((t[i + 1] - t[i]) if i + 1 < len(t) else 33000) / 1.0e6
            f.write(f"file 'kareler/coop/{i:05d}.jpg'\nduration {dur:.6f}\n")
        f.write(f"file 'kareler/coop/{len(t) - 1:05d}.jpg'\n")
    tempo = z["audio_len"] / z["dur"] if z.get("audio_len") else 1.0
    run(["-f", "concat", "-safe", "0", "-i", lst, "-i", os.path.join(d, "ses.wav"),
         "-filter_complex", f"[0:v]fps={FPS},format=yuv420p[v];[1:a]atempo={tempo:.5f},aresample=48000[a]",
         "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-preset", "medium", "-crf", "12", "-r", str(FPS),
         "-c:a", "pcm_s16le", out])
    return out, z


def shots(plan):
    if plan == "coop" and plan not in _SHOTS:
        _, z = coop_file()
        n = int(z["dur"] * FPS)
        _SHOTS[plan] = {"coop": {"name": "coop", "a": 1, "b": n + 1, "f0": 1, "frames": n}}
    if plan not in _SHOTS:
        with open(os.path.join(CAP, plan, "cekimler.json"), encoding="utf-8") as f:
            d = json.load(f)
        _SHOTS[plan] = {s["name"]: s for s in d["shots"]}
    return _SHOTS[plan]


def avi(plan):
    return os.path.join(CAP, plan, "cekim.avi")


def shot_len(plan, name):
    s = shots(plan)[name]
    return s.get("frames", s["b"] - s["a"]) / FPS


def seq_pattern(plan, name):
    return os.path.join(CAP, plan, "kareler", name, "%05d.png")


def frame_path(plan, name, idx):
    s = shots(plan)[name]
    idx = max(0, min(int(idx), s.get("frames", 1) - 1))
    return os.path.join(CAP, plan, "kareler", name, f"{idx:05d}.png")


def locate(plan, name, at, rel="a"):
    """(PNG dizisinde başlangıç karesi, AVI ses zamanı). at: rel karesinden (a = çekim başı, cast = yeteneğe basış) saniye."""
    s = shots(plan)[name]
    f0 = s.get("f0", s["a"])
    base = s.get(rel, s["a"]) if rel != "a" else f0
    g = base + at * FPS  # oyun karesi
    idx = int(round(g - f0))
    return max(0, idx), (f0 + max(0, idx) - 1) / FPS


# ───────────────────────────── piksel yazı ─────────────────────────────

def _line_img(txt, color):
    """16 punto m5x7, kenar yumuşatmasız; 1 piksel kontur (8 yön) + 1 piksel alt gölge. Döner: 1:1 RGBA."""
    f = ImageFont.truetype(FONT, 16)
    asc, desc = f.getmetrics()
    tw = int(f.getlength(txt))
    img = Image.new("RGBA", (tw + 6, asc + desc + 6), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    ox, oy = 3, 2
    d.text((ox, oy + 2), txt, font=f, fill=C_DEEP + (255,))
    d.text((ox + 1, oy + 2), txt, font=f, fill=C_DEEP + (255,))
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if dx or dy:
                d.text((ox + dx, oy + dy), txt, font=f, fill=C_OUT + (255,))
    d.text((ox, oy), txt, font=f, fill=tuple(color) + (255,))
    return img.crop(img.getbbox())


def text_block(lines, scale, gap=2):
    """lines: [(metin, renk), ...] ortalı blok, tam sayı katla büyütülmüş."""
    ims = [_line_img(t, c) for t, c in lines]
    bw = max(i.width for i in ims)
    bh = sum(i.height for i in ims) + gap * (len(ims) - 1)
    blk = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    y = 0
    for i in ims:
        blk.alpha_composite(i, ((bw - i.width) // 2, y))
        y += i.height + gap
    return blk.resize((bw * scale, bh * scale), Image.NEAREST)


def layer(blocks):
    """blocks: [(blok, merkez_y)] -> tam kare RGBA."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for b, cy in blocks:
        x = (W - b.width) // 2
        img.alpha_composite(b, (max(0, x), int(cy - b.height / 2)))
    return img


def fit_scale(lines, want, max_w=980):
    s = want
    while s > 3:
        if text_block(lines, s).width <= max_w:
            return s
        s -= 1
    return s


# ───────────────────────────── bölümler ─────────────────────────────

def caption_png(path, cap, style):
    """cap: satır listesi (ilk satır vurgulu olabilir). style: story / big / name / tier."""
    if not cap:
        Image.new("RGBA", (W, H), (0, 0, 0, 0)).save(path)
        return
    if style == "name":
        ad = [(cap[0], C_GOLD)]
        alt = [(t, C_TEXT) for t in cap[1:]]
        blocks = [(text_block(ad, fit_scale(ad, 10)), 330)]
        if alt:
            blocks.append((text_block(alt, fit_scale(alt, 6)), 330 + 105))
        layer(blocks).save(path)
        return
    if style == "tier":
        b = [(cap[0], C_GOLD)]
        blocks = [(text_block(b, fit_scale(b, 12)), 360)]
        if len(cap) > 1:
            a = [(t, C_TEXT) for t in cap[1:]]
            blocks.append((text_block(a, fit_scale(a, 6)), 470))
        layer(blocks).save(path)
        return
    if style == "big":
        ls = [(t, C_GOLD) for t in cap]
        layer([(text_block(ls, fit_scale(ls, 13)), 400)]).save(path)
        return
    ls = [(t, C_TEXT) for t in cap]
    layer([(text_block(ls, fit_scale(ls, 8)), 380)]).save(path)


def seg_clip(i, spec, lang):
    """Oyun çekiminden bir bölüm: kes, (yavaşlat), yazıyı bindir, beyaz parlama ile aç (isteğe bağlı)."""
    plan, name = spec["src"]
    rel = spec.get("rel", "a")
    if rel not in shots(plan)[name]:
        rel = "a"
    idx0, t0 = locate(plan, name, spec.get("at", 0.0), rel)
    speed = spec.get("speed", 1.0)
    dur = spec["dur"]
    src_dur = dur * speed
    cap = spec.get("cap", {}).get(lang) if isinstance(spec.get("cap"), dict) else spec.get("cap")
    png = os.path.join(WORK, f"cap_{i:02d}_{lang}.png")
    caption_png(png, cap, spec.get("style", "story"))
    out = os.path.join(WORK, f"seg_{i:02d}_{lang}.mkv")
    v = f"[0:v]trim=duration={src_dur:.4f},setpts=(PTS-STARTPTS)/{speed},fps={FPS}"
    if spec.get("mask_bottom"):
        y = int(spec["mask_bottom"])
        v += f",drawbox=x=0:y={y}:w={W}:h={H - y}:color=black:t=fill"
    if spec.get("flash"):
        v += ",fade=in:st=0:d=0.14:color=white"
    if spec.get("fadein"):
        v += f",fade=in:st=0:d={spec['fadein']}"
    v += "[v]"
    cap_in = spec.get("cap_in", 0.06)
    t = "[1:v]format=rgba[t]" if cap_in < 0 else f"[1:v]format=rgba,fade=in:st={cap_in}:d=0.12:alpha=1[t]"
    a = "[2:a]atrim=duration={:.4f},asetpts=PTS-STARTPTS".format(src_dur)
    if speed != 1.0:
        a += f",atempo={1.0 / speed:.4f}"
    a += f",aresample=48000,afade=in:d=0.015,afade=out:st={max(0.0, dur - 0.03):.4f}:d=0.03[a]"
    fc = f"{v};{t};[v][t]overlay=0:0:format=auto,format=yuv420p[vo];{a}"
    if plan == "coop":
        mkv, _ = coop_file()
        vin = ["-ss", f"{idx0 / FPS:.4f}", "-i", mkv]
        ain = ["-ss", f"{idx0 / FPS:.4f}", "-i", mkv]
    else:
        vin = ["-framerate", str(FPS), "-start_number", str(idx0), "-i", seq_pattern(plan, name)]
        ain = ["-ss", f"{t0:.4f}", "-i", avi(plan)]
    run(vin + ["-loop", "1", "-framerate", str(FPS), "-t", f"{dur:.4f}", "-i", png] + ain + [
         "-filter_complex", fc, "-map", "[vo]", "-map", "[a]", "-t", f"{dur:.4f}",
         "-c:v", "libx264", "-preset", "medium", "-crf", "15", "-pix_fmt", "yuv420p", "-r", str(FPS),
         "-c:a", "pcm_s16le", "-ar", "48000", "-ac", "2", out])
    return out


END = {
    "tr": {"alt": ["8 kişiye kadar co-op"], "cta": "YAKINDA"},
    "en": {"alt": ["Co-op for up to 8"], "cta": "COMING SOON"},
}


def seg_card(i, spec, lang):
    """Kapanış kartı: kararmış oyun karesi + POTPOURRI + alt yazı + çağrı."""
    plan, name = spec["bg"]
    idx, _ = locate(plan, name, spec.get("at", 0.0))
    bg = Image.open(frame_path(plan, name, idx)).convert("RGB")
    dark = Image.new("RGB", (W, H), C_DEEP)
    bg = Image.blend(bg, dark, 0.62).convert("RGBA")
    e = END[lang]
    title = text_block([("POTPOURRI", C_GOLD)], 15)
    alt = text_block([(t, C_TEXT) for t in spec.get("alt", {}).get(lang, e["alt"])], 7)
    cta = text_block([(spec.get("cta", {}).get(lang, e["cta"]), C_SOFT)], 6)
    bg.alpha_composite(layer([(title, 820), (alt, 1010), (cta, 1160)]))
    card = os.path.join(WORK, f"card_{i:02d}_{lang}.png")
    bg.convert("RGB").save(card)
    dur = spec["dur"]
    out = os.path.join(WORK, f"seg_{i:02d}_{lang}.mkv")
    sound = spec.get("sound")
    ins = ["-loop", "1", "-framerate", str(FPS), "-t", f"{dur:.4f}", "-i", card]
    if sound:
        ins += ["-i", os.path.join(SFX, sound)]
        a = f"[1:a]aresample=48000,volume={spec.get('sound_gain', 1.0)},apad,atrim=duration={dur:.4f},afade=out:st={dur - 0.4:.4f}:d=0.4[a]"
    else:
        ins += ["-f", "lavfi", "-t", f"{dur:.4f}", "-i", "anullsrc=r=48000:cl=stereo"]
        a = "[1:a]anull[a]"
    fc = f"[0:v]fps={FPS},fade=in:st=0:d=0.25,format=yuv420p[vo];{a}"
    run(ins + ["-filter_complex", fc, "-map", "[vo]", "-map", "[a]", "-t", f"{dur:.4f}",
               "-c:v", "libx264", "-preset", "medium", "-crf", "15", "-pix_fmt", "yuv420p", "-r", str(FPS),
               "-c:a", "pcm_s16le", "-ar", "48000", "-ac", "2", out])
    return out


def build(short, lang):
    os.makedirs(WORK, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    segs = []
    for i, spec in enumerate(SHORTS[short]):
        segs.append(seg_card(i, spec, lang) if "bg" in spec else seg_clip(i, spec, lang))
    lst = os.path.join(WORK, f"liste_{short}_{lang}.txt")
    with open(lst, "w", encoding="utf-8") as f:
        for s in segs:
            f.write("file '" + s.replace("\\", "/") + "'\n")
    mp4 = os.path.join(OUT, f"{short}_{lang}.mp4")
    run(["-f", "concat", "-safe", "0", "-i", lst, "-c:v", "copy",
         "-af", "loudnorm=I=-15:TP=-1.5:LRA=11", "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
         "-movflags", "+faststart", mp4])
    total = sum(s.get("dur", 0) for s in SHORTS[short])
    print(f"{mp4}  ~{total:.1f} sn")
    return mp4


# ───────────────────────────── inceleme ─────────────────────────────

def bak(plan, points=(0.1, 0.4, 0.7, 0.95), scale=0.18):
    """Her çekimden birkaç kare -> tek sayfa (satır = çekim)."""
    os.makedirs(WORK, exist_ok=True)
    rows = []
    for name, s in shots(plan).items():
        ims = []
        for p in points:
            fp = frame_path(plan, name, s.get("frames", 1) * p)
            ims.append(Image.open(fp).convert("RGB").resize((int(W * scale), int(H * scale)), Image.BILINEAR))
        rows.append((name, ims))
    cw, ch = int(W * scale), int(H * scale)
    sheet = Image.new("RGB", ((cw + 4) * len(points) + 4, (ch + 22) * len(rows)), (16, 16, 16))
    d = ImageDraw.Draw(sheet)
    for r, (name, ims) in enumerate(rows):
        y = r * (ch + 22)
        d.text((6, y + 4), f"{name}  ({shot_len(plan, name):.1f} sn)", fill=(255, 220, 140))
        for c, im in enumerate(ims):
            sheet.paste(im, (4 + c * (cw + 4), y + 20))
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, f"bak_{plan}.jpg")
    sheet.save(p, quality=82)
    print(p, sheet.size)


SHORTS = {}
sys.path.insert(0, HERE)
try:
    from kurgu_senaryo import SHORTS as _S  # noqa: E402
    SHORTS.update(_S)
except ImportError:
    pass


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "yap"
    if cmd == "bak":
        bak(sys.argv[2])
    elif cmd == "yap":
        names = sys.argv[2:] or list(SHORTS.keys())
        langs = [x for x in ("tr", "en") if os.environ.get("TN_LANG", "tr,en").find(x) >= 0]
        for n in names:
            for lg in langs:
                build(n, lg)
        if os.path.isdir(WORK) and os.environ.get("TN_KEEP") != "1":
            shutil.rmtree(WORK, ignore_errors=True)
    else:
        print(__doc__)
