#!/usr/bin/env python3
"""Pence (claw) silahinin savurus efekti - pixel-art spritesheet, 3 varyant.

Kullanici istegi (2026-09-24): "pencenin saldiri efektini saldiri animasyonuyla uyumlu olacak sekilde yeniden tasarlayip
sifirdan daha iyi bir pence efekti tasarla pixel tarzda. ve bunu sonrasinda spritesheete donustur performans kaybi
yasamamak icin (2-3 varyasonu daha olsun spam gibi olmamasi icin)".

SALDIRI ANIMASYONUYLA UYUM (bkz. weapon.gd _do_melee_swing): pence ikonu hedefin ustunde, saldiri yonune DIK eksende
bir yandan (+perp) obur yana (-perp) ~0.21 sn'de suprulur (2 vurus). Bu yuzden efekt: 3 paralel, hafif kavisli pence
izi, AYNI yonde (+y -> -y, dokunun yerel uzayinda +x = saldiri yonu, +y = perp) ucundan baslayarak yirtilir; onde giden
ucta beyaz parilti + kucuk kivilcimlar; sonra izler kuyruktan uca dogru kizarip incelir ve soner. fx_claw_slash.gd
efekti savurusun MERKEZINE hizalar (align_to_swing).

Tasarim: 1 sanat pikseli = PixelDraw.TEXEL dunya birimi (48x48 karakter yogunlugu), 1 px koyu kontur, beyaz cekirdek /
acik kirmizi kenar. Varyantlar: v0 duz dik 3 iz, v1 saga egik + daha kavisli, v2 sola egik + ortasi uzun.
Kare 64x64, 12 kare (30 fps = 0.4 sn - eski efektle ayni sure).

Kullanim (repo kokunden):  python tools/gen_claw_slash_fx.py
Cikti: assets/fx/claw/claw_sheet.png (12 kare x 3 satir) + claw_frames.tres (animasyonlar "v0", "v1", "v2")
Yeni PNG icin Godot'ta bir kez `--headless --import` gerekir.
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "fx", "claw")
RES = "res://assets/fx/claw/claw_sheet.png"

SIZE = 64
FRAMES = 12
FPS = 30.0
REVEAL_FRAMES = 4  ## 0..3: izler ucundan yirtilarak uzar (ikonun ~0.12-0.21 sn'lik supurusuyle ayni hizda)
HOLD_FRAMES = 2  ## 4..5: tam, parlak
## 6..11: kuyruktan uca kizarip incelerek soner

WHITE = (255, 252, 244, 255)
CREAM = (255, 226, 214, 255)
PINK = (255, 132, 128, 255)
RED = (214, 44, 52, 255)
DARK = (104, 16, 30, 255)
OUTLINE = (40, 8, 14, 255)

## varyant: her iz icin (x_offset, uzunluk, kavis, egim)
VARIANTS = [
    [(-8, 38, 4.0, 0.0), (0, 42, 4.5, 0.0), (8, 36, 4.0, 0.0)],
    [(-8, 36, 6.0, 5.0), (0, 40, 6.5, 5.0), (8, 34, 6.0, 5.0)],
    [(-9, 32, 3.0, -5.0), (0, 44, 3.5, -5.0), (9, 32, 3.0, -5.0)],
]


def hash01(a, b, c):
    x = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
    x = (x ^ (x >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((x ^ (x >> 16)) & 0xFFFF) / 65535.0


def mark_point(mark, s):
    """s: +1 = baslangic (+y, supurusun basladigi yan), -1 = bitis (-y). Donus: (x, y) tuval koordinati."""
    xo, length, bow, tilt = mark
    c = SIZE / 2.0
    y = c + s * length / 2.0
    x = c + xo + bow * (1.0 - s * s) + tilt * s
    return x, y


def render(frame, variant):
    marks = VARIANTS[variant]
    ## katman: 0 bos, 1 kenar, 2 cekirdek, 3 onde giden parlak uc
    layer = [[0] * SIZE for _ in range(SIZE)]
    heat = [[0.0] * SIZE for _ in range(SIZE)]  ## 0 = taze/parlak, 1 = sonmus
    for mi, mark in enumerate(marks):
        stagger = mi * 0.35  ## izler hafif sirayla yirtilir (pence parmaklari)
        if frame < REVEAL_FRAMES:
            reveal = max(0.0, min(1.0, (frame + 1 - stagger) / REVEAL_FRAMES))
            s_head = 1.0 - 2.0 * reveal
            s_tail = 1.0
            fade = 0.0
        elif frame < REVEAL_FRAMES + HOLD_FRAMES:
            s_head, s_tail, fade = -1.0, 1.0, 0.0
        else:
            k = (frame - REVEAL_FRAMES - HOLD_FRAMES + 1) / float(FRAMES - REVEAL_FRAMES - HOLD_FRAMES)
            s_head = -1.0
            s_tail = 1.0 - 2.0 * min(1.0, k * 1.15)  ## kuyruk uca dogru kayar
            fade = k
        if reveal_done := (s_head >= s_tail):
            continue
        s = s_tail
        while s >= s_head:
            x, y = mark_point(mark, s)
            mid = 1.0 - s * s
            w = (0.6 + 1.6 * mid) * (1.0 - 0.55 * fade)
            head = frame < REVEAL_FRAMES and (s - s_head) < 0.18
            for yy in range(int(y - 3), int(y + 4)):
                for xx in range(int(x - 3), int(x + 4)):
                    if not (0 <= xx < SIZE and 0 <= yy < SIZE):
                        continue
                    d = math.hypot(xx + 0.5 - x, yy + 0.5 - y)
                    if d > w + 0.35:
                        continue
                    lvl = 3 if head else (2 if d <= w * 0.45 else 1)
                    if lvl > layer[yy][xx]:
                        layer[yy][xx] = lvl
                    heat[yy][xx] = max(heat[yy][xx], fade)
            s -= 0.02
    im = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = im.load()
    for y in range(SIZE):
        for x in range(SIZE):
            lvl = layer[y][x]
            if lvl == 0:
                continue
            h = heat[y][x]
            if lvl == 3:
                c = WHITE
            elif lvl == 2:
                c = WHITE if h < 0.2 else (CREAM if h < 0.45 else (PINK if h < 0.7 else RED))
            else:
                c = PINK if h < 0.3 else (RED if h < 0.65 else DARK)
            px[x, y] = c
    ## 1 px koyu kontur (sonerken inceltmek icin son karelerde konturu atla)
    if frame < FRAMES - 2:
        out = im.copy()
        op = out.load()
        for y in range(SIZE):
            for x in range(SIZE):
                if px[x, y][3] > 0:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < SIZE and 0 <= ny < SIZE and px[nx, ny][3] > 0:
                        op[x, y] = OUTLINE
                        break
        im = out
        px = im.load()
    ## kivilcimlar: onde giden uclardan saldiri yonune (+x) ve yana sacilan tek pikseller (2..8. kareler)
    if 1 <= frame <= 8:
        for mi, mark in enumerate(marks):
            for k in range(3):
                seed_s = 0.9 - 0.6 * k - 0.1 * mi
                bx, by = mark_point(mark, seed_s)
                age = frame - 1 - k
                if age < 0 or age > 5:
                    continue
                vx = 2.0 + 3.0 * hash01(variant, mi, k)
                vy = -1.5 + 3.0 * hash01(mi, k, variant + 7)
                sx = int(round(bx + vx * age))
                sy = int(round(by + vy * age))
                if 0 <= sx < SIZE and 0 <= sy < SIZE:
                    px[sx, sy] = WHITE if age < 2 else (PINK if age < 4 else RED)
    return im


def write_tres(path):
    lines = ['[gd_resource type="SpriteFrames" format=3]', "", '[ext_resource type="Texture2D" path="%s" id="1"]' % RES, ""]
    at = 0
    blocks = []
    for v in range(len(VARIANTS)):
        ids = []
        for f in range(FRAMES):
            lines += ['[sub_resource type="AtlasTexture" id="AT_%d"]' % at, 'atlas = ExtResource("1")',
                      "region = Rect2(%d, %d, %d, %d)" % (f * SIZE, v * SIZE, SIZE, SIZE), ""]
            ids.append(at)
            at += 1
        entries = ",\n".join('{\n"duration": 1.0,\n"texture": SubResource("AT_%d")\n}' % i for i in ids)
        blocks.append('{\n"frames": [%s],\n"loop": false,\n"name": &"v%d",\n"speed": %s\n}' % (entries, v, FPS))
    lines += ["[resource]", "animations = [%s]" % ", ".join(blocks), ""]
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print("wrote", path)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    sheet = Image.new("RGBA", (SIZE * FRAMES, SIZE * len(VARIANTS)), (0, 0, 0, 0))
    for v in range(len(VARIANTS)):
        for f in range(FRAMES):
            sheet.paste(render(f, v), (f * SIZE, v * SIZE))
    path = os.path.join(OUT_DIR, "claw_sheet.png")
    sheet.save(path)
    print("wrote", path, sheet.size)
    write_tres(os.path.join(OUT_DIR, "claw_frames.tres"))
    preview = os.environ.get("CLAW_PREVIEW_DIR")
    if preview:
        bg = Image.new("RGBA", sheet.size, (70, 110, 60, 255))
        bg.alpha_composite(sheet)
        bg.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(os.path.join(preview, "claw_preview.png"))


if __name__ == "__main__":
    main()
