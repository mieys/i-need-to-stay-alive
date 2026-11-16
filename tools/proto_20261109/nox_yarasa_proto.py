#!/usr/bin/env python3
"""Nox yarasa formu GUZELLESTIRME prototipleri (2026-11-16, kullanici: "sprite sheet'i biraz guzellestirelim prototip sunar misin").

Kaynak: assets/characters/vampir/bat_sheet.png (gen_vampir_bat_form.py ciktisi, kullanicinin bat_fly.png'si + kafa dikeni temizligi).
Siluet, kare sayisi, hucre (96x112) AYNI kalir - yalniz boyama degisir (duz bantlar, DITHER YOK):
  A  Yumusak golge   ayni renkler; kanat zari 3 bant (kemige yakin koyu / taban / dis kenar acik), govde + kemiklerin ust kenarinda isik
  B  Kizil parilti   kanat zari kemikten uzakliga gore 4 bant + parlak kizil arka kenar, gozler parlar (cekirdek + kizil hale)
  C  Nox renkleri    Nox'un pelerin kizili (#411310 / #5b1610 / #8b1b16 / #b22c2e) + kurk koyulari, Nox'un konturuyla (#171212) 1 px dis kontur
Cikti: tools/proto_20261109/out/nox_yarasa_formu/proto/<kod>.png (bat_sheet.png duzeninde) + orijinal kopyasi O.png.
Kullanim: python tools/proto_20261109/nox_yarasa_proto.py
"""
import os
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHEET = os.path.join(ROOT, "assets", "characters", "vampir", "bat_sheet.png")
OUT = os.path.join(ROOT, "tools", "proto_20261109", "out", "nox_yarasa_formu", "proto")
CW, CH = 96, 112

D = (31, 14, 20)    # koyu: govde, kemik, yakin kanat
M = (80, 27, 46)    # kanat zari / yuz
R = (255, 0, 0)     # goz
F = (247, 228, 205)  # dis
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
N8 = N4 + ((1, 1), (1, -1), (-1, 1), (-1, -1))


def hexc(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


class Cell:
    """Tek karenin piksel siniflari + yardimci olcumler (hucre koordinatinda)."""

    def __init__(self, im):
        self.im = im
        self.px = im.load()
        self.cls = {}
        for y in range(CH):
            for x in range(CW):
                p = self.px[x, y]
                if p[3]:
                    self.cls[(x, y)] = {D: "D", M: "M", R: "R", F: "F"}.get(p[:3], "?")

    def at(self, x, y):
        return self.cls.get((x, y), "T")

    def edge(self, x, y, dirs=N4):
        return any(self.at(x + dx, y + dy) == "T" for dx, dy in dirs)

    def dist_to(self, kinds, over="M"):
        """over sinifindaki her piksel icin kinds siniflarina 4-komsu BFS uzakligi."""
        dist = {}
        q = deque()
        for p, k in self.cls.items():
            if k in kinds:
                dist[p] = 0
                q.append(p)
        while q:
            x, y = q.popleft()
            for dx, dy in N4:
                n = (x + dx, y + dy)
                if n not in dist and self.cls.get(n) == over:
                    dist[n] = dist[(x, y)] + 1
                    q.append(n)
        return dist

    def components(self, kind):
        """kind sinifinin 4-komsu bilesenleri -> {piksel: bilesen boyu}."""
        size = {}
        seen = set()
        for p, k in self.cls.items():
            if k != kind or p in seen:
                continue
            comp = [p]
            seen.add(p)
            i = 0
            while i < len(comp):
                x, y = comp[i]
                i += 1
                for dx, dy in N4:
                    n = (x + dx, y + dy)
                    if n not in seen and self.cls.get(n) == kind:
                        seen.add(n)
                        comp.append(n)
            for c in comp:
                size[c] = len(comp)
        return size


def put(cell, x, y, rgb):
    cell.px[x, y] = rgb + (255,)


def variant_a(cell):
    m_dark, m_light, d_light = (58, 18, 33), (124, 46, 70), (64, 34, 48)
    msize = cell.components("M")
    dist = cell.dist_to({"D"})
    for (x, y), k in cell.cls.items():
        if k == "M" and msize[(x, y)] >= 40:  # kanat zari (yuz / ayak parmaklari kucuk bilesen, dokunulmaz)
            if cell.edge(x, y):
                put(cell, x, y, m_light)
            elif dist.get((x, y), 99) == 1:
                put(cell, x, y, m_dark)
        elif k == "D" and cell.at(x, y - 1) == "T":
            put(cell, x, y, d_light)


def variant_b(cell):
    bands = [(58, 14, 30), (84, 22, 44), (110, 28, 54), (134, 36, 62)]
    rim = (178, 54, 76)
    d_light = (64, 30, 46)
    glow = (128, 30, 44)
    eye_core = (255, 120, 110)
    msize = cell.components("M")
    dist = cell.dist_to({"D"})
    for (x, y), k in cell.cls.items():
        if k == "M" and msize[(x, y)] >= 40:
            if cell.edge(x, y):
                put(cell, x, y, rim)
            else:
                d = dist.get((x, y), 99)
                put(cell, x, y, bands[0] if d <= 1 else bands[1] if d <= 3 else bands[2] if d <= 6 else bands[3])
        elif k == "D" and cell.at(x, y - 1) == "T":
            put(cell, x, y, d_light)
        elif k == "M" and any(cell.at(x + dx, y + dy) == "R" for dx, dy in N8):
            put(cell, x, y, glow)  # goz cevresi kizil hale (yuz pikselleri)
    for (x, y), k in cell.cls.items():
        if k == "R" and cell.at(x, y - 1) != "R":
            put(cell, x, y, eye_core)  # her gozun ust pikseli parlak cekirdek


def variant_c(cell):
    root, base, light, edge = hexc("#411310"), hexc("#5b1610"), hexc("#8b1b16"), hexc("#b22c2e")
    fur, fur_light, face = hexc("#1d1d22"), hexc("#3a2d38"), hexc("#5b1610")
    outline = hexc("#171212")
    msize = cell.components("M")
    dist = cell.dist_to({"D"})
    for (x, y), k in cell.cls.items():
        if k == "M" and msize[(x, y)] >= 40:
            if cell.edge(x, y):
                put(cell, x, y, edge)
            else:
                d = dist.get((x, y), 99)
                put(cell, x, y, root if d <= 1 else base if d <= 4 else light)
        elif k == "M":
            put(cell, x, y, face)
        elif k == "D":
            put(cell, x, y, fur_light if cell.at(x, y - 1) == "T" else fur)
    ## 1 px dis kontur (8-komsu), Nox'un kendi kontur rengi.
    for y in range(CH):
        for x in range(CW):
            if (x, y) not in cell.cls and any((x + dx, y + dy) in cell.cls for dx, dy in N8):
                put(cell, x, y, outline)


VARIANTS = {"A": variant_a, "B": variant_b, "C": variant_c}


def main():
    os.makedirs(OUT, exist_ok=True)
    src = Image.open(SHEET).convert("RGBA")
    src.save(os.path.join(OUT, "O.png"))
    cols, rows = src.width // CW, src.height // CH
    for code, fn in VARIANTS.items():
        out = src.copy()
        for r in range(rows):
            for c in range(cols):
                box = (c * CW, r * CH, (c + 1) * CW, (r + 1) * CH)
                cell = Cell(out.crop(box))
                fn(cell)
                out.paste(cell.im, box[:2])
        out.save(os.path.join(OUT, f"{code}.png"))
        print("yazildi", code)


if __name__ == "__main__":
    main()
