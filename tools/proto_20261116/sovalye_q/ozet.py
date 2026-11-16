#!/usr/bin/env python3
"""q_proto.py çıktısından özet tablo: her seçenek x anahtar anlar, gerçek Şovalye idle karesi + çim, x3 en yakın.
Satırlar: A/B/C temel, A/B/C + Meydan Okuma. Çıktı out/ozet.png (yalnız kontrol amaçlı; asıl sunum q_sayfa.py)."""
import json
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "out")
GRASS = (122, 173, 85, 255)
TIMES = [0.05, 0.15, 0.3, 0.45, 0.7, 1.05, 1.3, 2.6]
Z = 3


def main():
    meta = json.load(open(os.path.join(OUT, "meta.json"), encoding="utf-8"))
    W, H, ox, oy, cols, fps = meta["w"], meta["h"], meta["ox"], meta["oy"], meta["cols"], meta["fps"]
    knight = Image.open(os.path.join(ROOT, "assets/characters/sovalye/sheets/idle.png")).convert("RGBA").crop((0, 0, 48, 48))
    cw, ch = 104, 84
    cache = {}

    def frame(name, layer, i):
        key = (name, layer)
        if key not in cache:
            cache[key] = Image.open(os.path.join(OUT, f"{name}_{layer}.png")).convert("RGBA")
        sh = cache[key]
        return sh.crop(((i % cols) * W, (i // cols) * H, (i % cols) * W + W, (i // cols) * H + H))

    rows = []
    for taunt in (False, True):
        for v in "abc":
            rows.append((v, taunt))
    img = Image.new("RGBA", (len(TIMES) * cw * Z, len(rows) * ch * Z + 20), (30, 30, 36, 255))
    d = ImageDraw.Draw(img)
    for r, (v, taunt) in enumerate(rows):
        for c, t in enumerate(TIMES):
            cell = Image.new("RGBA", (W, H), GRASS)
            if t < 1.0:
                i = int(t * fps)
                layers = [(f"{v}_cast", i)]
            else:
                layers = [(f"{v}_loop", int(((t - 1.0) % 1.0) * fps))]
            tl = [(f"{v}_taunt", int(t * fps))] if taunt and t < 1.2 else []
            for nm, i in layers + tl:
                cell.alpha_composite(frame(nm, "back", i))
            cell.alpha_composite(knight, (ox - 24, oy - 40))
            for nm, i in layers + tl:
                cell.alpha_composite(frame(nm, "front", i))
            cell = cell.crop(((W - cw) // 2, oy - 62, (W - cw) // 2 + cw, oy - 62 + ch))
            img.paste(cell.resize((cw * Z, ch * Z), Image.NEAREST), (c * cw * Z, r * ch * Z + 20))
        d.text((4, r * ch * Z + 24), v.upper() + (" + Meydan Okuma" if taunt else ""), fill=(255, 255, 255, 255))
    for c, t in enumerate(TIMES):
        d.text((c * cw * Z + 4, 4), f"{t:.2f} sn", fill=(255, 220, 120, 255))
    img.save(os.path.join(OUT, "ozet.png"))
    print(img.size)


if __name__ == "__main__":
    main()
