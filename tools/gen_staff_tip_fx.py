# -*- coding: utf-8 -*-
"""Asa ucu partikül sayfaları (CLAUDE.md madde 299; prototip madde 295 "A - Sade Toz", kullanıcı 2026-10-19: "A ları beğendim fakat
çok uzuyor parıltının kuyruğu, biraz daha kısa olmalı" -> ömürler prototipin A_LIFE["kisa"] değerleri).

Çizim kuralları prototipin AYNISI (tools/proto_20261019/asa_partikul_proto.py Emitter.draw "ember" / "frost" / "mote" / "spark"
+ uçtaki "crack"); renkler oradaki rampalar. 1 sanat px = karakter pikseli 0,903 dünya px (scripts/staff_tip_fx.gd TEXEL).
Sayfa düzeni scripts/fx_particle_trail.gd ile aynı (shaders/particle_trail.gdshader): sütun = ömür karesi (8), satır = varyant.
Satırların bir kısmı ömrün daha erken bir yerinde biter (prototipteki rastgele ömür aralığı yerine). Kor / kırağı / zerre
kendi hızıyla shader'da uçar (emitter rastgele hız verir); mor zerrenin girdabı ve kıvılcımların yörüngesi (yerçekimi dahil)
sayfaya pişirilir (kıvılcım çizgisi hız yönünde - döndürülemeyen sayfada yön satırla seçilir).

Çıktılar assets/fx/staff_tip/: ember_sheet.png (Ateş), frost_sheet.png (Buz), mote_sheet.png (Arcane), spark_tip_sheet.png
(Yıldırım ucu, 8 yukarı yön), spark_hit_sheet.png (Yıldırım isabeti, 8 dış yön), crackle_sheet.png (uçta cızırtı, 8 kare),
prism_sheet.png (Gökkuşağı Asası, madde 309: ışın paletinin 6 rengi x 3 satır; satır = renk, emitter rastgele satır seçer ->
tanecik başına rastgele renk).
Çalıştırma: python tools/gen_staff_tip_fx.py   (sonra Godot --headless --import)
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "proto_20261019"))
import asa_partikul_proto as AP  # noqa: E402

OUT = os.path.join(ROOT, "assets", "fx", "staff_tip")
TEXEL = AP.TX  # 0,903 dünya px
FRAMES = 8
LIFE = {k: v[1] for k, v in AP.A_LIFE["kisa"].items()}  # satırların en uzunu = stil ömrü (staff_tip_fx.gd STYLES)
FIRE, ICE, ARC, ELEC = AP.FIRE, AP.ICE, AP.ARC, AP.ELEC


class Cell:
    """Tek kare (premultiplied birikim, düz alfa ile kaydedilir)."""

    def __init__(self, n):
        self.n = n
        self.c = n // 2
        self.a = np.zeros((n, n, 4), np.float32)

    def put(self, x, y, col, a=1.0):
        x, y = int(x) + self.c, int(y) + self.c
        if a <= 0.0 or not (0 <= x < self.n and 0 <= y < self.n):
            return
        p = self.a[y, x]
        p[:3] = np.array(col, np.float32) * a + p[:3] * (1.0 - a)
        p[3] = a + p[3] * (1.0 - a)

    def line(self, x0, y0, x1, y1, col, a=1.0, skip_last=False):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        x, y = x0, y0
        while True:
            if not (skip_last and x == x1 and y == y1):
                self.put(x, y, col, a)
            if x == x1 and y == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x += sx
            if e2 <= dx:
                err += dx
                y += sy

    def plus(self, x, y, r, cc, ca, a=1.0):
        for i in range(1, r + 1):
            col = ca[min(len(ca) - 1, i - 1)] if isinstance(ca, list) else ca
            for dx, dy in ((i, 0), (-i, 0), (0, i), (0, -i)):
                self.put(x + dx, y + dy, col, a)
        self.put(x, y, cc, a)

    def rgba(self):
        out = np.zeros_like(self.a)
        al = self.a[..., 3]
        m = al > 1e-4
        out[m, :3] = self.a[m, :3] / al[m, None]
        out[..., 3] = al * 255.0
        return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def frac(k, end):
    """k. ömür karesinin satır içi yaşı (0..1); satır `end` oranında biter -> >= 1 boş kare."""
    return ((k + 0.5) / FRAMES) / end


# ------------------------------------------------------------------ partikül kareleri (prototip Emitter.draw kuralları)
def ember(cell, f, big):
    i = min(4, int((f ** 1.5) * 5.0))
    if big and f < 0.35:
        cell.plus(0, 0, 1, FIRE[0], FIRE[2], 1.0)
    else:
        cell.put(0, 0, FIRE[i], 1.0 if f < 0.8 else 0.75)
        if f < 0.55:
            cell.put(0, 1, FIRE[min(4, i + 1)], 0.75)


def frost(cell, f, glint):
    if glint:
        r = [0, 1, 2, 1, 0][min(4, int(f * 5.0))]
        cell.plus(0, 0, r, ICE[0], ICE[1 + min(2, int(f * 3.0))], 1.0 if f < 0.8 else 0.75)
    else:
        cell.put(0, 0, ICE[min(3, int(f * 3.0))], 1.0 if f < 0.75 else 0.5)
        if f < 0.45:
            cell.put(1, 0, ICE[1], 0.75)


def mote(cell, f, dia, ph, life):
    age = f * life
    ox = (9.0 / 6.0) * (math.sin(age * 6.0 + ph) - math.sin(ph)) / TEXEL  # prototip: vx += cos(6 yaş + faz) x 9
    oy = (5.0 / 6.0) * (math.cos(ph) - math.cos(age * 6.0 + ph)) / TEXEL  # vy += sin(6 yaş + faz) x 5
    x, y = int(round(ox)), int(round(oy))
    i = min(4, int(f * 5.0))
    if dia and f < 0.7:
        cell.plus(x, y, 1, ARC[max(0, i - 1)], ARC[min(4, i + 1)], 1.0)
    else:
        cell.put(x, y, ARC[i], 1.0 if f < 0.8 else 0.75)
        if f < 0.5:
            cell.put(x, y + 1, ARC[min(4, i + 2)], 0.75)


# Gökkuşağı Asası (madde 309): renkler ışın shader'ının AYNISI (shaders/gokkusagi_isin.gdshader RB + CREAM). Işın gibi üç ton:
# krem (yalnız parıltı merkezi) / renk ile kremin yarı karışımı (ışının orta bandı, tanecik doğarken) / saf renk (dış bant, söner).
RB = [AP.hx(c) for c in "#f06a5a #f7a24a #f4d85a #86d26e #62b2ec #a87ae6".split()]
CREAM = AP.hx("#fffaf0")


def light(c, k=0.5):
    return tuple(int(round(c[i] * (1.0 - k) + CREAM[i] * k)) for i in range(3))


def prism(cell, f, col, twinkle, horiz):
    """1-2 px ışık tozu: açık tonla doğar, saf renge döner, 0,75 / 0,5 saydamlıkla söner. twinkle: ömrün ortasında 1 px kollu
    krem merkezli kısa parıltı (buzun 'glint'inden küçük). horiz: doğarkenki ikinci pikselin yönü (yatay / dikey)."""
    lt = light(col)
    if twinkle and 0.15 <= f < 0.45:
        cell.plus(0, 0, 1, CREAM, col, 1.0)
        return
    cell.put(0, 0, lt if f < 0.3 else col, 1.0 if f < 0.6 else 0.75 if f < 0.85 else 0.5)
    if not twinkle and f < 0.45:
        cell.put(1 if horiz else 0, 0 if horiz else 1, col, 0.75)


def spark(cell, f, life, v0, g):
    age = f * life
    px = v0[0] * age / TEXEL
    py = (v0[1] * age + 0.5 * g * age * age) / TEXEL
    vx, vy = v0[0], v0[1] + g * age
    L = math.hypot(vx, vy) + 1e-6
    x, y = int(math.floor(px + 0.5)), int(math.floor(py + 0.5))
    i = min(3, int(f * 4.0))
    tl = 3 if f < 0.5 else 2 if f < 0.8 else 1
    cell.line(x - int(round(vx / L * tl)), y - int(round(vy / L * tl)), x, y, ELEC[min(3, i + 1)], 0.75)
    cell.put(x, y, ELEC[i], 1.0)


# ------------------------------------------------------------------ sayfalar
def bake(name, rows, draw, cell_n):
    """rows: satır parametreleri; draw(cell, f, row) çizer. Sütun = ömür karesi."""
    sheet = Image.new("RGBA", (cell_n * FRAMES, cell_n * len(rows)), (0, 0, 0, 0))
    for r, row in enumerate(rows):
        for k in range(FRAMES):
            f = frac(k, row[0])
            if f >= 1.0:
                continue
            c = Cell(cell_n)
            draw(c, f, row)
            im = c.rgba()
            a = np.asarray(im)[..., 3]
            if a[0, :].any() or a[-1, :].any() or a[:, 0].any() or a[:, -1].any():
                raise SystemExit("%s satır %d kare %d hücre kenarına taştı (hücre %d)" % (name, r, k, cell_n))
            sheet.paste(im, (k * cell_n, r * cell_n))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    sheet.save(path)
    print("wrote", path, sheet.size, "hücre", cell_n, "satır", len(rows))


TIP_DIRS = [-math.pi * 0.95 + k * (math.pi * 0.9 / 7.0) for k in range(8)]  # prototip: yukarı yarım (-0,95π .. -0,05π)
TIP_ENDS = [1.0, 0.7, 0.85, 1.0, 0.65, 0.8, 0.9, 0.75]
HIT_ENDS = [1.0, 0.8, 0.9, 0.75, 1.0, 0.85, 0.7, 0.95]
SPARK_TIP_SPEED, SPARK_TIP_G = 22.0, 95.0  # prototip: hız 14-30, yerçekimi 95
SPARK_HIT_SPEED, SPARK_HIT_G = 31.0, 110.0  # prototip isabet A: hız 22-40, dikey x0,6 - 16, yerçekimi 110
HIT_LIFE = 0.36


def main():
    bake("ember_sheet.png", [(1.0, False), (0.6, False), (0.8, True), (0.75, False)],
         lambda c, f, row: ember(c, f, row[1]), 5)
    bake("frost_sheet.png", [(1.0, False), (0.65, False), (1.0, True), (0.75, True)],
         lambda c, f, row: frost(c, f, row[1]), 7)
    bake("mote_sheet.png", [(1.0, False, 0.0), (0.7, False, math.pi), (1.0, True, math.pi / 2), (0.75, True, math.pi * 1.5)],
         lambda c, f, row: mote(c, f, row[1], row[2], LIFE["mote"] * row[0]), 11)
    # satır 3k..3k+2 = RB[k]: uzun toz / kısa toz / parıltı (bitişler renkten renge kayar, hep aynı anda sönmesinler);
    # stil ömrü 0,5 sn (staff_tip_fx.gd STYLES "rainbow"), buz/arcane kısa ömürleriyle aynı aralık
    prism_rows = []
    for k, col in enumerate(RB):
        prism_rows += [((1.0, 0.9, 0.95, 0.85, 1.0, 0.9)[k], col, False, k % 2 == 0),
                       ((0.65, 0.75, 0.7, 0.75, 0.65, 0.7)[k], col, False, k % 2 == 1),
                       ((0.85, 0.8, 0.9, 0.85, 0.8, 0.9)[k], col, True, False)]
    bake("prism_sheet.png", prism_rows, lambda c, f, row: prism(c, f, row[1], row[2], row[3]), 5)
    tip_rows = [(e, (math.cos(a) * SPARK_TIP_SPEED, math.sin(a) * SPARK_TIP_SPEED)) for e, a in zip(TIP_ENDS, TIP_DIRS)]
    bake("spark_tip_sheet.png", tip_rows, lambda c, f, row: spark(c, f, LIFE["spark"] * row[0], row[1], SPARK_TIP_G), 21)
    hit_rows = []
    for k, e in enumerate(HIT_ENDS):  # satır k = dış yön k x 45 derece (staff_tip_fx.gd emit_hit_spark satırı açıdan seçer)
        a = k * math.pi / 4.0
        hit_rows.append((e, (math.cos(a) * SPARK_HIT_SPEED, math.sin(a) * SPARK_HIT_SPEED * 0.6 - 16.0)))
    bake("spark_hit_sheet.png", hit_rows, lambda c, f, row: spark(c, f, HIT_LIFE * row[0], row[1], SPARK_HIT_G), 29)
    # uçta cızırtı: 8 rastgele zikzak (prototip "crack": 3-4 parça, 2,0-3,4 px, koyu altın + açık çekirdek)
    rng = random.Random(4417)
    n = 17
    sheet = Image.new("RGBA", (n * 8, n), (0, 0, 0, 0))
    k = 0
    while k < 8:
        pts = AP.zigzag(rng, rng.choice([3, 4]), (2.0, 3.4), 0.8, rng.uniform(0, 2 * math.pi))
        P = [(int(round(x)), int(round(y))) for x, y in pts]
        if max(max(abs(x), abs(y)) for x, y in P) > n // 2 - 1:
            continue
        c = Cell(n)
        for (x0, y0), (x1, y1) in zip(P, P[1:]):
            c.line(x0, y0, x1, y1, ELEC[2], 0.75)
        for (x0, y0), (x1, y1) in zip(P[:-1], P[1:-1] + [P[-1]]):
            c.line(x0, y0, x1, y1, ELEC[1], 1.0, skip_last=True)
        sheet.paste(c.rgba(), (k * n, 0))
        k += 1
    path = os.path.join(OUT, "crackle_sheet.png")
    sheet.save(path)
    print("wrote", path, sheet.size)
    print("ömürler", LIFE, "isabet", HIT_LIFE)


if __name__ == "__main__":
    main()
