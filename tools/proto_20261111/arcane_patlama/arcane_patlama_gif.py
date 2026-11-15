"""Arcane Patlama prototip cekimlerini birlestirir (arcane_patlama_capture.gd ciktisi out/oyun/).

  python -I tools/proto_20261111/arcane_patlama/arcane_patlama_gif.py
Cikti out/:
  karsilastirma.gif - SU AN | A | B / C | D, butun zincir (4 sekme + patlama), GERCEK HIZ (oyun zamani; cekim x0,25 yavas alindi)
  yakin.gif         - ilk patlamanin cevresi, 5 kod yan yana, YARI HIZ
  ozet.png          - her satir bir kod: ilk patlamanin 0 / 50 / 100 / ... ms kareleri
Kirpma kare pikseli -> dunya: oyuncu kirpmada (100, 300) x k, 1 dunya = 2 x k piksel (kamera zoom 2; k = kare genisligi / 1040).
"""

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
## --src <out altindaki klasor> --tag <cikti oneki>: evrimsiz cekim -> --src oyun_evrimsiz --tag evrimsiz_
_args = sys.argv[1:]
SRC = os.path.join(OUT, _args[_args.index("--src") + 1] if "--src" in _args else "oyun")
TAG = _args[_args.index("--tag") + 1] if "--tag" in _args else ""
## --yaricap <metin>: aciklama paneli (madde 563 sonrasi cekim 52,5)
RADIUS_TXT = _args[_args.index("--yaricap") + 1] if "--yaricap" in _args else "75"
CODES = ["now", "A", "B", "C", "D", "A1", "A2", "A3", "A4", "M1", "M2", "M3"]
LABEL = {"now": "SU AN", "A": "A Sok Halkasi", "B": "B Muhur Dairesi", "C": "C Kiymik Yildizi", "D": "D Lanet Alevi",
         "A1": "A1 Saydam Halka", "A2": "A2 Kisik Isik", "A3": "A3 Run Halkasi", "A4": "A4 Isilti",
         "M1": "M1 Yildiz Tozu", "M2": "M2 Buyu Bulutu", "M3": "M3 Buyu Cicegi"}
FONT = os.path.join(HERE, "..", "..", "..", "assets", "fonts", "m5x7.ttf")
BG = (24, 20, 28)
INK = (236, 214, 170)


def font(sz):
    try:
        return ImageFont.truetype(FONT, sz)
    except OSError:
        return ImageFont.load_default()


_cache = {}


def load(code, idx):
    key = (code, idx)
    if key not in _cache:
        _cache[key] = Image.open(os.path.join(SRC, "%s_%03d.png" % (code, idx))).convert("RGB")
    return _cache[key]


def nearest(tl, target):
    return min(range(len(tl)), key=lambda q: abs(tl[q] - target))


def at_or_after(tl, target):
    """Patlama ani: patlamanin dogdugu kare (hedef anindan ONCEKI kare patlamayi henuz gostermez)."""
    for q, t in enumerate(tl):
        if t >= target:
            return q
    return len(tl) - 1


def main():
    z = json.load(open(os.path.join(SRC, "zamanlar.json"), encoding="utf-8"))
    times, marks = z["times"], z["marks"]
    ## isabet ani: E1 patlamasi; evrimsizde patlama yok -> gozun carpmasi (lanet_burst)
    blasts = {c: (z["blasts"].get(c) or z.get("hits", {}).get(c) or []) for c in times}
    if TAG.startswith("evrimsiz"):
        LABEL["now"] = "EVRIMSIZ"
    codes = [c for c in CODES if c in times]
    w, h = load(codes[0], 0).size
    k = w / float(z["crop"][2])
    px_world = 2.0 * k
    ox, oy = -z["crop"][0] * k, -z["crop"][1] * k  # oyuncu kirpmada

    # ---- 1) karsilastirma.gif: 3 x 2 izgara, gercek hiz, E basildigi ana hizali
    many = len(codes) > 6  ## 12 panel (madde 563 kucuk alan turu): 4 sutun, kucuk olcek
    s = 0.3 if many else 0.42
    tw, th = int(w * s), int(h * s)
    head = 30
    cols = 4 if many else min(3, len(codes))
    rows = (len(codes) + cols - 1) // cols
    step = 40
    frames = []
    for ms in range(-200, 2500, step):
        canvas = Image.new("RGB", (tw * cols, (th + head) * rows), BG)
        d = ImageDraw.Draw(canvas)
        for n, code in enumerate(codes):
            tl = times[code]
            t0 = tl[marks[code]]
            im = load(code, nearest(tl, t0 + ms)).resize((tw, th), Image.BOX)
            x, y = (n % cols) * tw, (n // cols) * (th + head)
            canvas.paste(im, (x, y + head))
            d.text((x + 8, y + 2), LABEL[code], fill=INK, font=font(32))
        if len(codes) < cols * rows:
            x, y = (len(codes) % cols) * tw, (len(codes) // cols) * (th + head)
            d.text((x + 16, y + head + 20), "Arcane Patlama (E1) - gercek hiz", fill=INK, font=font(32))
            d.text((x + 16, y + head + 60), "her isabette patlama, alan = %s birim" % RADIUS_TXT, fill=INK, font=font(32))
            d.text((x + 16, y + head + 100), "sekme: goz varinca vurur (yeni ritim)", fill=INK, font=font(32))
            d.text((x + 16, y + head + 160), "t = %+d ms" % ms, fill=INK, font=font(32))
        frames.append(canvas)
    frames[0].save(os.path.join(OUT, TAG + "karsilastirma.gif"), save_all=True, append_images=frames[1:], duration=step, loop=0)

    # ---- 2) yakin.gif: ilk patlama cevresi (+-110 dunya), yari hiz
    R_W = 85.0 if many else 110.0
    half = int(R_W * px_world)
    sz = 2 * half
    sc2 = 0.5 if many else 0.75
    t2 = int(sz * sc2)
    cols2 = 6 if many else len(codes)
    rows2 = (len(codes) + cols2 - 1) // cols2
    frames2 = []
    for ms in range(-150, 750, 20):
        canvas = Image.new("RGB", (t2 * cols2, (t2 + head) * rows2), BG)
        d = ImageDraw.Draw(canvas)
        for n, code in enumerate(codes):
            b = blasts[code][0]
            cx, cy = ox + b[1] * px_world, oy + b[2] * px_world
            tl = times[code]
            im = load(code, at_or_after(tl, b[0] + ms)).crop((int(cx - half), int(cy - half), int(cx + half), int(cy + half)))
            x, y = (n % cols2) * t2, (n // cols2) * (t2 + head)
            canvas.paste(im.resize((t2, t2), Image.BOX), (x, y + head))
            d.text((x + 8, y + 2), LABEL[code], fill=INK, font=font(32))
        frames2.append(canvas)
    frames2[0].save(os.path.join(OUT, TAG + "yakin.gif"), save_all=True, append_images=frames2[1:], duration=40, loop=0)

    # ---- 3) ozet.png: ilk patlama, satir basina kod
    offs = [0, 50, 100, 150, 200, 300, 400, 500, 600]
    sc3 = 0.5
    t3 = int(sz * sc3)
    lab_w = 230
    sheet = Image.new("RGB", (lab_w + t3 * len(offs), head + (t3 + 4) * len(codes)), BG)
    d = ImageDraw.Draw(sheet)
    for j, o in enumerate(offs):
        d.text((lab_w + j * t3 + 8, 2), "+%d ms" % o, fill=INK, font=font(32))
    for r, code in enumerate(codes):
        b = blasts[code][0]
        cx, cy = ox + b[1] * px_world, oy + b[2] * px_world
        tl = times[code]
        y = head + r * (t3 + 4)
        d.text((8, y + t3 // 2 - 14), LABEL[code], fill=INK, font=font(32))
        for j, o in enumerate(offs):
            im = load(code, at_or_after(tl, b[0] + o)).crop((int(cx - half), int(cy - half), int(cx + half), int(cy + half)))
            sheet.paste(im.resize((t3, t3), Image.BOX), (lab_w + j * t3, y))
    sheet.save(os.path.join(OUT, TAG + "ozet.png"))
    print("tamam", len(frames), "+", len(frames2), "kare; olcek", round(px_world, 3), "px/dunya")


if __name__ == "__main__":
    main()
