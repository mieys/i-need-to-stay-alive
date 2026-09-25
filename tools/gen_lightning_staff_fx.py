"""Yildirim Asasi pixel efektleri -> assets/fx/lightning_staff/

Kullanici istegi (2026-09-25): "yildirim asasinin yildirim efektini v.s yeniden tasarlamani istiyorum pixel tarzda
sonrasinda spritesheete donustur ki performans dusmesin".

Eski efekt (fx_lightning_beam.gd / fx_lightning_chain.gd) her karede yumusak (antialias) draw_line zikzaklari +
script'te tek tek hesaplanan kivilcim parcaciklari ciziyordu. Isinin boyu/yonu surekli degistigi icin tek parca bir
sprite olamaz; bunun yerine:

  bolt_tiles.png (6 varyant x 24x15, tek satir): UCLARI BIRBIRINE DIKISSIZ BAGLANAN simsek karolari - her karo soldan
                  (0,7)'den girer, saga (23,7)'den cikar, arada zikzak (bazilarinda kucuk bir catal). Isin boyunca bu
                  karolar dosenir ve ~20 kez/sn rastgele degistirilir (cizirti) - isin basina ~10 draw cagrisi.
  impact  (40x40, 8 kare, 16 fps, dongu): hedefte cizirdayan kivilcim cekirdegi + rastgele kisa arklar.
  orb     (20x20, 6 kare, 12 fps, dongu): asanin ucunda titreyen kucuk elektrik topu.
  chain_hit (40x40, 6 kare, 20 fps, tek sefer): zincir sicramasinin carptigi yaratikta kisa patlama + halka.

Olcek: 1 sanat pikseli = 1 dunya birimi (dunyada duran efektler; karakterin sanat pikseli ~1.12). Renk: eskisiyle ayni
kimlik - beyaz cekirdek, soluk/parlak sari, amber hale.
Calistir: python tools/gen_lightning_staff_fx.py
"""

import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "lightning_staff")
RES = "res://assets/fx/lightning_staff/"

WHITE = (255, 255, 246)
PALE = (255, 244, 170)
YELLOW = (255, 208, 64)
AMBER = (232, 140, 32)
DEEP = (170, 80, 20)

TILE_W, TILE_H, MID = 24, 15, 7


def qa(a):
    for lv in (1.0, 0.8, 0.55, 0.3):
        if a >= lv - 0.12:
            return lv
    return 0.0


def put(img, x, y, col, a=1.0, over=False):
    x, y = int(round(x)), int(round(y))
    if not (0 <= x < img.width and 0 <= y < img.height):
        return
    a = qa(a)
    if a <= 0:
        return
    if not over and img.getpixel((x, y))[3] >= int(255 * a):
        return
    img.putpixel((x, y), col + (int(255 * a),))


def line_pts(x0, y0, x1, y1):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    return [(round(x0 + (x1 - x0) * i / max(1, n)), round(y0 + (y1 - y0) * i / max(1, n))) for i in range(n + 1)]


def draw_bolt(img, pts, core=WHITE, a=1.0, glow=True):
    """Zikzak polyline: 1 px beyaz cekirdek, ustte/altta sari, disinda dither'li amber hale."""
    cells = []
    for (xa, ya), (xb, yb) in zip(pts, pts[1:]):
        cells += line_pts(xa, ya, xb, yb)
    cells = list(dict.fromkeys(cells))
    if glow:
        for (x, y) in cells:
            for dy in (-2, 2):
                if (x + y) % 2 == 0:
                    put(img, x, y + dy, AMBER, a * 0.55)
            for dx, dy in ((0, -1), (0, 1)):
                put(img, x + dx, y + dy, YELLOW, a * 0.8)
    for (x, y) in cells:
        put(img, x, y, core, a, over=True)
    return cells


def save_sheet(name, frames, anim, loop, fps):
    os.makedirs(OUT, exist_ok=True)
    w, h = frames[0].size
    s = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (i * w, 0))
    s.save(os.path.join(OUT, name + "_sheet.png"), optimize=True)
    write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), RES + name + "_sheet.png", w, h,
                        [(anim, (0, 0), len(frames), loop, fps)])


# ---------------------------------------------------------------- bolt tiles
def bolt_tiles():
    variants = 6
    sheet = Image.new("RGBA", (TILE_W * variants, TILE_H), (0, 0, 0, 0))
    for v in range(variants):
        rng = random.Random(40 + v)
        img = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
        xs = [0, 5 + rng.randint(-1, 1), 11 + rng.randint(-1, 1), 17 + rng.randint(-1, 1), TILE_W - 1]
        pts = [(xs[0], MID)]
        for x in xs[1:-1]:
            pts.append((x, MID + rng.choice([-4, -3, -2, 2, 3, 4])))
        pts.append((xs[-1], MID))
        cells = draw_bolt(img, pts)
        if v in (1, 3, 5):  # kucuk catal
            bx, by = cells[len(cells) // 2]
            sgn = -1 if by > MID else 1
            fork = [(bx, by), (bx + 3, by + sgn * 3), (bx + 5, by + sgn * 5)]
            draw_bolt(img, fork, core=PALE, a=0.8, glow=False)
        sheet.paste(img, (v * TILE_W, 0))
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, "bolt_tiles.png"))
    print("wrote", os.path.join(OUT, "bolt_tiles.png"))


# ---------------------------------------------------------------- impact (loop)
def arcs(img, rng, cx, cy, count, rmin, rmax, a):
    for _ in range(count):
        ang = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(rmin, rmax)
        n = 3
        pts = [(cx, cy)]
        for k in range(1, n + 1):
            t = k / n
            jitter = rng.uniform(-2.5, 2.5)
            pts.append((cx + math.cos(ang) * r * t - math.sin(ang) * jitter, cy + math.sin(ang) * r * t + math.cos(ang) * jitter))
        draw_bolt(img, pts, a=a, glow=False)
        put(img, pts[-1][0], pts[-1][1], PALE, a, over=True)


def core(img, cx, cy, r, a=1.0):
    for y in range(img.height):
        for x in range(img.width):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d <= r:
                put(img, x, y, WHITE if d < r * 0.5 else PALE, a if d < r * 0.5 else a * 0.8, over=True)
            elif d <= r + 2 and (x + y) % 2 == 0:
                put(img, x, y, YELLOW, a * 0.55)


def impact():
    frames = []
    for f in range(8):
        rng = random.Random(200 + f)
        img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
        pulse = 0.5 + 0.5 * math.cos(2 * math.pi * f / 8)
        core(img, 20, 20, 2.5 + 1.5 * pulse)
        arcs(img, rng, 20, 20, 4, 7, 16, 1.0)
        for _ in range(5):  # savrulan kivilcim noktalari
            ang = rng.uniform(0, 2 * math.pi)
            r = rng.uniform(8, 18)
            put(img, 20 + math.cos(ang) * r, 20 + math.sin(ang) * r, PALE if rng.random() < 0.5 else YELLOW, 0.8, over=True)
        frames.append(img)
    save_sheet("impact", frames, "loop", True, 16)


def orb():
    frames = []
    for f in range(6):
        rng = random.Random(300 + f)
        img = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
        pulse = 0.5 + 0.5 * math.sin(2 * math.pi * f / 6)
        core(img, 10, 10, 2.0 + pulse)
        arcs(img, rng, 10, 10, 2, 4, 8, 0.8)
        frames.append(img)
    save_sheet("orb", frames, "loop", True, 12)


def chain_hit():
    frames = []
    for f in range(6):
        t = f / 5
        rng = random.Random(400 + f)
        img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
        a = 1.0 - t * 0.85
        if t < 0.5:
            core(img, 20, 20, 4.5 * (1 - t), a)
        r = 5 + 13 * (1 - (1 - t) ** 2)
        n = int(2 * math.pi * r * 1.4)
        for i in range(n):
            ang = 2 * math.pi * i / n
            if (i // 2) % 2 == 0:
                put(img, 20 + r * math.cos(ang), 20 + r * math.sin(ang) * 0.75, PALE if t < 0.5 else YELLOW, a)
        arcs(img, rng, 20, 20, 3, 6, 14 * (1 - t * 0.5), a)
        frames.append(img)
    save_sheet("chain_hit", frames, "burst", False, 20)


if __name__ == "__main__":
    bolt_tiles()
    impact()
    orb()
    chain_hit()
