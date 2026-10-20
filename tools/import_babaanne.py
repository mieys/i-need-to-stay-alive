#!/usr/bin/env python3
"""Masaustu "Babanne" klasorunu oyuna alir (2026-10-19, madde 310): cozy evde yasayan BABAANNE NPC'si.

Kullanim (repo kokunden):
    python tools/import_babaanne.py [--src "<Babanne klasoru>"]

Kaynak sayfalar ($_<ad>_f<kare>.png) piksel sanatinin 6 kat buyutulmus hali (288 px hucre); 48 px'e KAYIPSIZ indirilir (tam katlama
dogrulanir). Satirlar down/left/right/up; "paint" sayfasinda yalniz left/right var.
Yazar: assets/npc/babaanne/sheets/*.png + assets/npc/babaanne/babaanne_frames.tres.

TURETILMIS kareler (kaynakta yok, mevcut pikseller yeniden dizilir):
  - seated: "sit" klibinin SON karesi (sit = ayaktan oturmaya GECIS; koltukta otururken bu poz sabit kalir).
  - sitread: seated + "read" karelerinin KITAP/EL pikselleri (mor kitap, beyaz sayfa, ten, koyu kontur; yuzun altindan) oturus pozuna
    tasinir (sol: +5,+2 / sag: -5,+2 - oturus govdesi okuma pozuna gore bu kadar kayik). Koltukta oturup kitap okuma.
  - sleep: "death" asagi son karesi (yan yatmis) 90 derece saga cevrilir -> bas ustte; cift kisilik yatakta yastikta yatar (yorgan
    babaanne_npc.gd'de yatagin kendi karolarindan ustune cizilir).
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "npc", "babaanne")
RES_DIR = "res://assets/npc/babaanne"
CELL = 48
DEFAULT_SRC = os.path.join(os.path.expanduser("~"), "Desktop", "Babanne")
DIRS4 = ["down", "left", "right", "up"]
# kaynak ad -> satirlarin yonleri
SOURCES = {
    "idle": DIRS4, "walk": DIRS4, "sit": DIRS4, "read": DIRS4, "water": DIRS4, "think": DIRS4, "shrug": DIRS4,
    "wave": DIRS4, "laugh": DIRS4, "eat": DIRS4, "drink": DIRS4, "death": DIRS4, "paint": ["left", "right"],
}
# klip: (klip adi, sayfa adi, kare sayisi, dongu, fps)
CLIPS = [
    ("idle", "idle", 4, True, 4.0),
    ("walk", "walk", 6, True, 8.0),
    ("sit", "sit", 4, False, 6.0),
    ("seated", "seated", 1, True, 1.0),
    ("read", "read", 4, True, 3.0),
    ("sitread", "sitread", 4, True, 2.5),
    ("wipe", "paint", 4, True, 6.0),      # raf/dolap silme
    ("stir", "paint", 4, True, 4.0),      # kazan karistirma (ayni kareler, daha yavas)
    ("water", "water", 4, True, 5.0),
    ("think", "think", 4, True, 3.0),
    ("shrug", "shrug", 4, False, 6.0),
    ("wave", "wave", 4, True, 6.0),
    ("laugh", "laugh", 3, True, 6.0),
    ("eat", "eat", 3, True, 5.0),         # corbanin tadina bakma
    ("drink", "drink", 3, True, 4.0),
    ("sleep", "sleep", 1, True, 1.0),
    ("death", "death", 3, False, 5.0),    # disarida yaratiklarca oldurulme (madde 313; kalici)
]


def downsample(path):
    a = np.array(Image.open(path).convert("RGBA"))
    h, w = a.shape[:2]
    rows = h // 288
    if h % 288 or w % 288:
        raise SystemExit(f"{path}: beklenmeyen boyut {w}x{h}")
    small = a[::6, ::6]
    if not (np.repeat(np.repeat(small, 6, axis=0), 6, axis=1) == a).all():
        raise SystemExit(f"{path}: tam 6x nearest buyutme degil")
    return Image.fromarray(small), rows


def find_src(folder, name):
    hits = [f for f in os.listdir(folder) if f.lower().endswith(".png") and f"_{name}_f" in f.lower()]
    if len(hits) != 1:
        raise SystemExit(f"{folder}: '{name}' icin {len(hits)} dosya: {hits}")
    return os.path.join(folder, hits[0])


def cell(img, c, r):
    return img.crop((c * CELL, r * CELL, (c + 1) * CELL, (r + 1) * CELL))


def sheet_from_rows(rows_by_dir, frames):
    """rows_by_dir: yon -> [kare Image...]; 4 satirlik (down/left/right/up) sayfa; eksik yon bos kalir."""
    out = Image.new("RGBA", (frames * CELL, 4 * CELL))
    for ri, d in enumerate(DIRS4):
        for ci, im in enumerate(rows_by_dir.get(d, [])):
            out.alpha_composite(im, (ci * CELL, ri * CELL))
    return out


def book_overlay(seat, read_frame, region, off):
    """Okuma karesinin kitap/el piksellerini oturus pozuna tasir (yuzu bozmamak icin bolge yuzun altindan baslar)."""
    base = seat.copy()
    bp, sp = base.load(), read_frame.load()
    x0, y0, x1, y1 = region
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = sp[x, y]
            if a == 0:
                continue
            purple = b > r and b > g + 20
            page = r > 200 and g > 190 and b > 180
            skin = r > 200 and 140 < g < 215 and 100 < b < 190 and r > g > b
            dark = r < 70 and g < 60 and b < 80
            if purple or page or skin or dark:
                bp[x + off[0], y + off[1]] = (r, g, b, a)
    return base


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=DEFAULT_SRC)
    args = ap.parse_args()
    os.makedirs(os.path.join(OUT_DIR, "sheets"), exist_ok=True)
    small = {}
    for name, dirs in SOURCES.items():
        img, rows = downsample(find_src(args.src, name))
        if rows != len(dirs):
            raise SystemExit(f"{name}: {rows} satir, beklenen {len(dirs)}")
        small[name] = (img, dirs)
        if dirs == DIRS4:
            img.save(os.path.join(OUT_DIR, "sheets", f"{name}.png"))
        else:  # paint: left/right satirlarini 4 satirlik duzene yerlestir
            frames = img.width // CELL
            sheet_from_rows({d: [cell(img, c, r) for c in range(frames)] for r, d in enumerate(dirs)}, frames).save(
                os.path.join(OUT_DIR, "sheets", f"{name}.png"))
    sit, _ = small["sit"]
    read, _ = small["read"]
    death, _ = small["death"]
    seated = {d: [cell(sit, 3, r)] for r, d in enumerate(DIRS4)}
    sheet_from_rows(seated, 1).save(os.path.join(OUT_DIR, "sheets", "seated.png"))
    sitread = {
        "left": [book_overlay(cell(sit, 3, 1), cell(read, k, 1), (10, 21, 25, 31), (5, 2)) for k in range(4)],
        "right": [book_overlay(cell(sit, 3, 2), cell(read, k, 2), (23, 21, 38, 31), (-5, 2)) for k in range(4)],
        "down": [cell(sit, 3, 0)] * 4, "up": [cell(sit, 3, 3)] * 4,
    }
    sheet_from_rows(sitread, 4).save(os.path.join(OUT_DIR, "sheets", "sitread.png"))
    lie = cell(death, 2, 0).transpose(Image.ROTATE_270)   # bas ustte
    sheet_from_rows({d: [lie] for d in DIRS4}, 1).save(os.path.join(OUT_DIR, "sheets", "sleep.png"))
    write_frames()


def write_frames():
    ext, subs, anims = [], [], []
    ext_ids = {}
    for clip, sheet, count, loop, fps in CLIPS:
        if sheet not in ext_ids:
            ext.append(f'[ext_resource type="Texture2D" path="{RES_DIR}/sheets/{sheet}.png" id="{len(ext) + 1}"]')
            ext_ids[sheet] = len(ext)
        eid = ext_ids[sheet]
        dirs = SOURCES.get(sheet, DIRS4) if sheet != "paint" else ["left", "right"]
        for d in dirs:
            row = DIRS4.index(d)
            refs = []
            for c in range(count):
                sid = f"AtlasTexture_{clip}_{d}_{c}"
                subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{eid}")\n'
                            f'region = Rect2({c * CELL}, {row * CELL}, {CELL}, {CELL})\n')
                refs.append('{"duration": 1.0,"texture": SubResource("%s")}' % sid)
            anims.append('{"frames": [%s],"loop": %s,"name": &"%s_%s","speed": %s}' % (
                ", ".join(refs), "true" if loop else "false", clip, d, fps))
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(ext) + len(subs) + 1} format=3]', ""]
    lines += ext + [""] + ["\n".join(subs)] + ["[resource]", "animations = [" + ", ".join(anims) + "]", ""]
    out = os.path.join(OUT_DIR, "babaanne_frames.tres")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"yazildi: {os.path.relpath(out, ROOT)} ({len(ext)} doku, {len(subs)} kare, {len(anims)} klip)")


if __name__ == "__main__":
    main()
