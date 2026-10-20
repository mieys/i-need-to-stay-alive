# -*- coding: utf-8 -*-
"""GÖKKUŞAĞI ASASI oyun sanatı (madde 306; prototip madde 298: asa = A Prizma, ışın = C Parıltılı Huzme).

Yazdıkları:
  assets/weapons/zanaat/gokkusagi_L<1..5>.png   asa (48x48, Zanaatkâr merdiveni; çizim tools/proto_20261019/gokkusagi_proto.py A_prism, L1 = A_prism_fork madde 320)
  assets/fx/gokkusagi/sparkle.png               ışın boyunca parıltı taneciği: 3 boy (r 2/1/0) x 6 renk satırı, 5x5 hücre
  assets/fx/gokkusagi/impact.png                vuruş tiki (0,5 sn'de bir hedefte): 6 kare 25x25 (30 fps), 6 renkli nokta + krem yıldız
  assets/fx/enchant/rainbow_dazzle_sheet.png    KAMAŞMA anı (EnchantFx "sprite" -> diğer oyunculara da gider): 10 kare 64x64 (24 fps)
  + rainbow_dazzle_frames.tres                  (fx_enchant_sprite.gd TEXEL 1,212 -> çağıran scale 1/1,212 verir = 1 dünya px/doku pikseli)
Işın gövdesi doku değil shader: shaders/gokkusagi_isin.gdshader (renkler aşağıdaki RB ile aynı).
Çalıştırma: python tools/gen_gokkusagi_fx.py [staff]  (staff = yalnız asa; sonra Godot --headless --path . --import)
"""
import math
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
sys.path.insert(0, os.path.join(ROOT, "tools", "proto_20261019"))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402
import gokkusagi_proto as G  # noqa: E402

ZANAAT = os.path.join(ROOT, "assets", "weapons", "zanaat")
FXDIR = os.path.join(ROOT, "assets", "fx", "gokkusagi")
ENCH = os.path.join(ROOT, "assets", "fx", "enchant")

RB = [tuple(int(c) for c in v) for v in G.RB]
CREAM = tuple(int(c) for c in G.CREAM)


def light(c, k=0.5):
    return tuple(int(round(c[i] * (1.0 - k) + CREAM[i] * k)) for i in range(3))


class Cnv:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), np.float32)

    def put(self, x, y, col, al=1.0):
        if al <= 0.0 or not (0 <= x < self.w and 0 <= y < self.h):
            return
        p = self.a[y, x]
        p[:3] = np.array(col, np.float32) / 255.0 * al + p[:3] * (1.0 - al)
        p[3] = al + p[3] * (1.0 - al)

    def plus(self, x, y, r, cc, arms, al=1.0):
        for i in range(1, r + 1):
            col = arms[min(len(arms) - 1, i - 1)]
            for dx, dy in ((i, 0), (-i, 0), (0, i), (0, -i)):
                self.put(x + dx, y + dy, col, al)
        self.put(x, y, cc, al)

    def line(self, x0, y0, x1, y1, col, al=1.0):
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            f = i / max(1, n)
            self.put(int(round(x0 + (x1 - x0) * f)), int(round(y0 + (y1 - y0) * f)), col, al)

    def image(self):
        out = np.zeros((self.h, self.w, 4), np.uint8)
        al = np.clip(self.a[..., 3], 0.0, 1.0)
        safe = np.maximum(al, 1e-6)[..., None]
        out[..., :3] = np.clip(self.a[..., :3] / safe * 255.0, 0, 255).astype(np.uint8)
        out[..., 3] = (np.ceil(al * 4.0 - 1e-6) / 4.0 * 255.0).astype(np.uint8)  # 4 adım saydamlık (dither yok)
        return Image.fromarray(out, "RGBA")


def qa(a):
    return math.ceil(max(0.0, min(1.0, a)) * 4.0 - 1e-6) / 4.0


def strip(frames):
    w, h = frames[0].size
    im = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im.paste(f, (i * w, 0))
    return im


# ---------------------------------------------------------------- asa
def build_staff():
    G.build_icons()
    os.makedirs(ZANAAT, exist_ok=True)
    for lv in range(1, 6):
        G.ICONS[("A", lv)].save(os.path.join(ZANAAT, "gokkusagi_L%d.png" % lv))
    print("asa: gokkusagi_L1..5")


# ---------------------------------------------------------------- parıltı taneciği
def build_sparkle():
    cell = 5
    im = Image.new("RGBA", (cell * 3, cell * 6), (0, 0, 0, 0))
    for row, col in enumerate(RB):
        for k, r in enumerate((2, 1, 0)):
            c = Cnv(cell, cell)
            c.plus(2, 2, r, CREAM if r > 0 else light(col, 0.35), [col, col])
            im.paste(c.image(), (k * cell, row * cell))
    os.makedirs(FXDIR, exist_ok=True)
    im.save(os.path.join(FXDIR, "sparkle.png"))
    print("sparkle", im.size)


# ---------------------------------------------------------------- vuruş tiki
def build_impact():
    frames = []
    n, S = 6, 25
    cx = S // 2
    for i in range(n):
        f = i / n
        c = Cnv(S, S)
        rad = 2.0 + f * 9.0
        for k in range(6):
            an = math.radians(k * 60.0 + 15.0)
            px, py = cx + int(round(math.cos(an) * rad)), cx + int(round(math.sin(an) * rad))
            if f < 0.5:
                c.plus(px, py, 1, RB[k], [RB[k]])
            else:
                c.put(px, py, RB[k], 0.75)
        rs = int(round(3.0 * (1.0 - f))) + 1
        c.plus(cx, cx, rs, CREAM, [CREAM, light(RB[2]), light(RB[4])])
        frames.append(c.image())
    strip(frames).save(os.path.join(FXDIR, "impact.png"))
    print("impact", n, S)


# ---------------------------------------------------------------- kamaşma
def build_dazzle():
    n, S = 10, 64
    cx = S // 2
    frames = []
    for i in range(n):
        dt = i / 24.0
        c = Cnv(S, S)
        f = dt / 0.42
        r = 5.0 + 24.0 * (1.0 - (1.0 - f) ** 2)
        thk = 3.4 * (1.0 - f) + 0.9
        al = qa(1.0 - f * f)
        rot = dt * 1.5
        for y in range(S):
            for x in range(S):
                dx, dy = x + 0.5 - cx, y + 0.5 - cx
                rr = math.hypot(dx, dy)
                if abs(rr - r) > thk * 0.5:
                    continue
                ang = (math.atan2(dy, dx) + rot) % (2.0 * math.pi)
                sec = ang / (2.0 * math.pi / 6.0)
                k = int(sec) % 6
                frac = sec - int(sec)
                if f > 0.55 and abs(frac - 0.5) > 0.5 - (1.0 - f) * 0.9:
                    continue  # kırılma: dilimlerin ucu açılır -> hilaller
                c.put(x, y, light(RB[k]) if rr < r else RB[k], al)
        if dt < 0.3:
            g = dt / 0.3
            ln = int(round(13.0 * (1.0 - g))) + 1
            ca = 1.0 if g < 0.5 else 0.75
            for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                c.line(cx, cx, cx + ddx * ln, cx + ddy * ln, CREAM, ca)
            for ddx, ddy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
                c.line(cx, cx, cx + ddx * (ln // 2), cx + ddy * (ln // 2), CREAM, 0.75)
        frames.append(c.image())
    os.makedirs(ENCH, exist_ok=True)
    strip(frames).save(os.path.join(ENCH, "rainbow_dazzle_sheet.png"))
    write_sprite_frames(os.path.join(ENCH, "rainbow_dazzle_frames.tres"), "res://assets/fx/enchant/rainbow_dazzle_sheet.png", S, S,
                        [("play", (0, 0), n, False, 24.0)])
    print("dazzle", n, S)


if __name__ == "__main__":
    build_staff()
    if "staff" not in sys.argv[1:]:  # "staff": yalnız asa ikonları
        build_sparkle()
        build_impact()
        build_dazzle()
