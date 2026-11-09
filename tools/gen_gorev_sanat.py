"""Görev sanatı (madde 496, 2026-11-08): Yuvaları Kapat yuvası + Gezici Işık ruh feneri.

Çıktı assets/fx/gorev/:
  yuva.png   - 5 kare x 44x32: 0-3 nabız (çukurdan mor ışık + yükselen zerreler), 4 = çökmüş yuva (ışık yok, moloz)
  fener.png  - 6 kare x 20x28: süzülen camgöbeği ruh alevi, üç titreyen dil (Batık Nekropol ruh ateşli heykelin rengi)
  fener_isik.png - 56x24 zemin ışığı (3 düz bant, toplamalı)

1 sanat pikseli = 1 dünya birimi (zindan / harita karolarıyla aynı yoğunluk). Dither yok, düz bantlar; tek ton zemin gölgesi (madde 487).
Çalıştır: python -I tools/gen_gorev_sanat.py
"""
from __future__ import annotations

import math
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "gorev")


def rgba(h: str, a: int = 255) -> tuple[int, int, int, int]:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# Yuva paleti: koyu toprak / taş + mor yarık ışığı (yaratık rengi, oyunun mor kristalleriyle aynı aile)
OUTLINE = rgba("1c1315")
SHADOW = rgba("140c10", 96)
DIRT_D = rgba("35251f")
DIRT_M = rgba("4c3527")
DIRT_L = rgba("6a4b34")
DIRT_H = rgba("86613f")
STONE_D = rgba("3f3a3d")
STONE_L = rgba("6b6466")
PIT = rgba("0b070c")
GLOW = [rgba("3a1a52"), rgba("5f2a86"), rgba("8c43bd"), rgba("b978ef"), rgba("ead0ff")]
BONE = rgba("d8cdb4")
BONE_D = rgba("9c8f76")

W, H = 44, 32


def in_ellipse(x: float, y: float, cx: float, cy: float, rx: float, ry: float) -> float:
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2


def nest_frame(phase: int, collapsed: bool) -> Image.Image:
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()
    cx, cy = 22.0, 21.0
    # tek ton zemin gölgesi
    for y in range(H):
        for x in range(W):
            if in_ellipse(x + 0.5, y + 0.5, cx, cy + 4.5, 20.0, 6.0) <= 1.0:
                px[x, y] = SHADOW
    # höyük gövdesi (alt yarısı daha geniş, tepesi ezik)
    body = set()
    for y in range(H):
        for x in range(W):
            fx, fy = x + 0.5, y + 0.5
            d = in_ellipse(fx, fy, cx, cy, 18.0, 9.5 if fy < cy else 7.0)
            if d <= 1.0:
                body.add((x, y))
    # kenardaki kaya tümsekleri
    bumps = [(7, 18, 4.0, 3.2), (36, 19, 4.2, 3.0), (14, 13.5, 3.4, 2.6), (30, 13, 3.6, 2.6), (22, 27, 5.0, 2.2)]
    stones = set()
    for bx, by, rx, ry in bumps:
        for y in range(H):
            for x in range(W):
                if in_ellipse(x + 0.5, y + 0.5, bx, by, rx, ry) <= 1.0:
                    body.add((x, y))
                    stones.add((x, y))
    for (x, y) in body:
        # ışık sol üstten: üst-sol açık, alt-sağ koyu (düz bantlar)
        t = (x - cx) / 18.0 * 0.45 + (y - cy) / 9.0 * 0.75
        if (x, y) in stones:
            px[x, y] = STONE_L if t < -0.15 else STONE_D
        elif t < -0.55:
            px[x, y] = DIRT_H
        elif t < -0.1:
            px[x, y] = DIRT_L
        elif t < 0.45:
            px[x, y] = DIRT_M
        else:
            px[x, y] = DIRT_D
    # dış hat
    for (x, y) in list(body):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in body and 0 <= n[0] < W and 0 <= n[1] < H:
                px[n[0], n[1]] = OUTLINE
    pcx, pcy = 22.0, 17.5
    if collapsed:
        # çukur molozla dolu: koyu taşlar, ışık yok
        for y in range(H):
            for x in range(W):
                d = in_ellipse(x + 0.5, y + 0.5, pcx, pcy, 8.0, 3.6)
                if d <= 1.0:
                    px[x, y] = STONE_D if (x * 7 + y * 3) % 5 else DIRT_D
        for (x, y) in ((17, 17), (18, 17), (25, 18), (26, 18), (21, 16)):
            px[x, y] = STONE_L
        return im
    # çukur + mor ışık halkası (nabız: halka kalınlığı/parlaklık faza göre)
    pulse = [0, 1, 2, 1][phase % 4]
    for y in range(H):
        for x in range(W):
            d = in_ellipse(x + 0.5, y + 0.5, pcx, pcy, 8.0, 3.6)
            if d <= 1.0:
                if d < 0.42:
                    px[x, y] = PIT
                elif d < 0.62:
                    px[x, y] = GLOW[1 + pulse]
                elif d < 0.82:
                    px[x, y] = GLOW[pulse]
                else:
                    px[x, y] = GLOW[0]
            elif d <= 1.35 and y < pcy + 1 and pulse >= 1:
                # çukur ağzının üst kenarına vuran ışık (yalnız parlak fazlarda)
                if (x, y) in body and px[x, y] in (DIRT_M, DIRT_L, DIRT_H):
                    px[x, y] = GLOW[1]
    # kemik parçaları (yuva süsü)
    for (x, y, c) in ((9, 21, BONE), (10, 21, BONE), (11, 22, BONE_D), (33, 23, BONE), (34, 23, BONE_D), (28, 25, BONE)):
        px[x, y] = c
    # yükselen zerreler (faza göre yukarı kayar)
    motes = [(19, 0), (24, 2), (22, 5)]
    for i, (mx, off) in enumerate(motes):
        yy = 14 - ((phase * 2 + off + i) % 9)
        if 2 <= yy < 15:
            c = GLOW[4] if (phase + i) % 2 == 0 else GLOW[3]
            px[mx, yy] = c
            if yy + 1 < H and px[mx, yy + 1][3] == 0:
                px[mx, yy + 1] = GLOW[2]
    return im


# Ruh feneri paleti (Statue_fire camgöbeği ruh ateşi ailesi)
F_OUT = rgba("0f3a4a")
F_D = rgba("1e7f9e")
F_M = rgba("38b9d6")
F_L = rgba("8ff0ff")
F_C = rgba("eafdff")
FW, FH = 20, 28


def wisp_frame(i: int) -> Image.Image:
    """Ruh alevi: yuvarlak gövde + titreyen üç dil (orta uzun, yanlar kısa), dipte beyaz çekirdek. Dil uçları kareye göre kayar."""
    im = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    px = im.load()
    cx = 10.0
    ph = i / 6.0 * math.tau
    tongues = [  # (x kayması, tepe y, yarı genişlik)
        (math.sin(ph) * 1.2, 2.5 + math.sin(ph * 2.0) * 1.2, 3.6),
        (-3.4 + math.sin(ph + 1.7) * 0.8, 9.0 + math.sin(ph + 2.4) * 1.5, 2.2),
        (3.4 + math.sin(ph + 3.1) * 0.8, 9.5 + math.sin(ph + 0.9) * 1.5, 2.2),
    ]
    shape = set()
    for y in range(FH):
        for x in range(FW):
            fx, fy = x + 0.5, y + 0.5
            if in_ellipse(fx, fy, cx, 20.0, 5.6, 5.2) <= 1.0:
                shape.add((x, y))
                continue
            for ox, top, hw in tongues:
                base_y = 19.0
                if top <= fy <= base_y:
                    k = (base_y - fy) / (base_y - top)
                    half = hw * (1.0 - k) ** 0.8 + 0.4
                    xc = cx + ox * k
                    if abs(fx - xc) <= half:
                        shape.add((x, y))
                        break
    for (x, y) in shape:
        fx, fy = x + 0.5, y + 0.5
        d = in_ellipse(fx, fy, cx, 19.0, 3.4, 4.6)
        if d < 0.3:
            px[x, y] = F_C
        elif d < 0.9:
            px[x, y] = F_L
        elif fy < 12.0 or d < 1.9:
            px[x, y] = F_M
        else:
            px[x, y] = F_D
    for (x, y) in list(shape):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in shape and 0 <= n[0] < FW and 0 <= n[1] < FH:
                px[n[0], n[1]] = F_OUT
    # kopan kıvılcım
    sx = int(cx + math.sin(ph * 1.5) * 6.0)
    sy = int(4 + (i % 3) * 2)
    if 0 <= sx < FW and px[sx, sy][3] == 0:
        px[sx, sy] = F_L
    return im


def glow_pool() -> Image.Image:
    """Fenerin zemine düşen ışığı: 3 düz bant elips (dither yok), toplamalı çizilir."""
    w, h = 56, 24
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    bands = [(1.0, 40), (0.68, 70), (0.38, 105)]
    for y in range(h):
        for x in range(w):
            d = in_ellipse(x + 0.5, y + 0.5, w / 2, h / 2, w / 2, h / 2)
            a = 0
            for r, al in bands:
                if d <= r * r:
                    a = al
            if a:
                px[x, y] = (110, 220, 240, a)
    return im


def sheet(frames: list[Image.Image]) -> Image.Image:
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    nest = sheet([nest_frame(i, False) for i in range(4)] + [nest_frame(0, True)])
    nest.save(os.path.join(OUT, "yuva.png"))
    wisp = sheet([wisp_frame(i) for i in range(6)])
    wisp.save(os.path.join(OUT, "fener.png"))
    glow_pool().save(os.path.join(OUT, "fener_isik.png"))
    if "--onizleme" in sys.argv:
        big = Image.new("RGBA", (nest.width * 4, (nest.height + wisp.height + 4) * 4), (60, 80, 50, 255))
        big.paste(nest.resize((nest.width * 4, nest.height * 4), Image.NEAREST), (0, 0), nest.resize((nest.width * 4, nest.height * 4), Image.NEAREST))
        w4 = wisp.resize((wisp.width * 4, wisp.height * 4), Image.NEAREST)
        big.paste(w4, (0, (nest.height + 4) * 4), w4)
        big.save(os.path.join(OUT, "_onizleme.png"))
    print("yazildi:", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
