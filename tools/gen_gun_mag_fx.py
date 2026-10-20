"""Tabanca + Tüfek şarjör efektleri (2026-10-19, madde 296): boş kovan, düşen şarjör.

Çıktı: assets/fx/gun/
  casings.png  - 8 sütun (45 derecelik dönüş kareleri) x 4 satır, 12x12 hücre:
                 0 tabanca kovanı, 1 tüfek kovanı, 2 tabanca şarjörü, 3 tüfek şarjörü

Doku pikseli silah sanatıyla aynı ızgarada çizilir (weapon_tier_art.gd WORLD_PX 0,575 dünya px) - oyunda bu ölçekle gösterilir.
Palet zanaat silahlarından (assets/weapons/zanaat/*_L3.png): pirinç, demir, koyu kontur. Işık sol üstten, dönüşte de sabit.
Kullanım: python tools/gen_gun_mag_fx.py
"""
import math
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "gun")

OUTLINE = (42, 30, 12, 255)      # #2a1e0c
IRON_OUT = (26, 29, 36, 255)     # #1a1d24
BRASS_DK = (122, 90, 36, 255)    # #7a5a24
BRASS = (154, 116, 50, 255)      # #9a7432
BRASS_LT = (201, 164, 90, 255)   # #c9a45a
BRASS_HI = (248, 184, 68, 255)   # #f8b844
MOUTH = (87, 64, 24, 255)        # #574018
IRON_DK = (56, 61, 70, 255)      # #383d46
IRON = (85, 91, 100, 255)        # #555b64
IRON_LT = (114, 120, 130, 255)   # #727882

CELL = 12
SS = 8  # süper örnekleme
LIGHT = (-0.7071, -0.7071)  # ışık yönü (sol üst)


def _zone_casing(s, u, length, rifle):
    """Kovan ekseni s (0 = taban, length = ağız), u = yanal (-1..1). Döner: renk ya da None."""
    if s < 0 or s > length:
        return None
    half = 1.0
    if rifle and s > length - 1.6:
        half = 0.62  # şişe boynu
    if abs(u) > half:
        return None
    if s > length - 0.9:
        return MOUTH
    if s < 0.9:
        return BRASS_DK  # taban kenarı
    return "body"


def _zone_mag(s, u, length, width, rifle):
    hw = width / 2.0
    if s < 0 or s > length or abs(u) > hw:
        return None
    if s > length - 1.1:
        # üstte görünen mermi ucu (pirinç), ortada
        return "tip" if abs(u) < hw * 0.55 else None
    if s < 1.0:
        return "base"
    return "box"


def _raster(angle, zone_fn, length):
    """Eksen boyunca (s) yukarı bakan nesneyi `angle` kadar döndürüp CELL x CELL ızgaraya örnekler."""
    ax = (math.sin(angle), -math.cos(angle))  # s ekseni (angle 0 = yukarı)
    pp = (math.cos(angle), math.sin(angle))   # u ekseni
    # ışığa bakan yan = u ekseninin ışıkla aynı yöne baktığı taraf
    lit_sign = 1.0 if (pp[0] * LIGHT[0] + pp[1] * LIGHT[1]) > 0 else -1.0
    cx = cy = CELL / 2.0
    grid = {}
    for py in range(CELL):
        for px in range(CELL):
            votes = {}
            for sy in range(SS):
                for sx in range(SS):
                    x = px + (sx + 0.5) / SS - cx
                    y = py + (sy + 0.5) / SS - cy
                    s = x * ax[0] + y * ax[1] + length / 2.0
                    u = x * pp[0] + y * pp[1]
                    z = zone_fn(s, u)
                    if z is None:
                        continue
                    key = (z, 1 if u * lit_sign > 0.15 else (-1 if u * lit_sign < -0.15 else 0))
                    votes[key] = votes.get(key, 0) + 1
            total = sum(votes.values())
            if total >= SS * SS * 0.45:
                grid[(px, py)] = max(votes.items(), key=lambda kv: kv[1])[0]
    return grid


def _paint(img, ox, oy, grid, palette, outline):
    for (px, py), key in grid.items():
        img.putpixel((ox + px, oy + py), palette(key))
    for py in range(CELL):
        for px in range(CELL):
            if (px, py) in grid:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (px + dx, py + dy) in grid:
                    img.putpixel((ox + px, oy + py), outline)
                    break


def _casing_palette(key):
    zone, side = key
    if zone == "body":
        return BRASS_HI if side > 0 else (BRASS if side < 0 else BRASS_LT)
    return zone


def _mag_palette(key):
    zone, side = key
    if zone == "tip":
        return BRASS_HI if side > 0 else BRASS_LT
    if zone == "base":
        return IRON_DK
    return IRON_LT if side > 0 else (IRON_DK if side < 0 else IRON)


def build_casings():
    img = Image.new("RGBA", (CELL * 8, CELL * 4), (0, 0, 0, 0))
    rows = [
        (lambda s, u: _zone_casing(s, u, 4.2, False), 4.2, _casing_palette, OUTLINE),
        (lambda s, u: _zone_casing(s, u, 5.8, True), 5.8, _casing_palette, OUTLINE),
        (lambda s, u: _zone_mag(s, u, 6.2, 3.0, False), 6.2, _mag_palette, IRON_OUT),
        (lambda s, u: _zone_mag(s, u, 7.4, 3.6, True), 7.4, _mag_palette, IRON_OUT),
    ]
    for r, (fn, length, pal, outline) in enumerate(rows):
        for f in range(8):
            ang = f * math.pi / 4.0
            grid = _raster(ang, fn, length)
            _paint(img, f * CELL, r * CELL, grid, pal, outline)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    build_casings().save(os.path.join(OUT, "casings.png"))
    print("ok", OUT)


if __name__ == "__main__":
    main()
