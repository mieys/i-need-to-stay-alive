"""Talon Silah Salvosu (E) zincir halkaları -> assets/fx/talon_chain/links.png (scripts/fx_talon_chains.gd okur).

Oyunda 1 halka pikseli = 0,5 dünya pikseli çizilir (fx_talon_chains.gd LINK_PX; 1080p'de 1 ekran pikseli). Halkalar 180 derece üzerinde 32 yön için önceden
pişirilir (halka 180 derece dönünce aynıdır -> 5,6 derecelik adım; çalışma anında döndürme yok, pikseller hep ızgarada temiz kalır).
Sayfa: 32 sütun (yön d: açı = pi * d / 32) x 4 satır, hücre 16x16, halka merkezi hücre pikseli (7, 6):
  satır 0  yüzü dönük oval halka - ALT katman: kontur (maskenin 1 piksel genişletilmişi, opak) + 3 piksel aşağıda yer gölgesi (alfa 0,33)
  satır 1  yüzü dönük oval halka - GÖVDE: gri ton (1.0 ışık alan / 0.78 orta / 0.55 gölge) - oyunda halka rengiyle çarpılır (modulate)
  satır 2  kenardan görünen halka - ALT katman: sadece kontur (gölgeyi komşu ovaller zaten kaplıyor; üst üste binip koyulaşmasın)
  satır 3  kenardan görünen halka - GÖVDE
Oyunda önce bir katmandaki TÜM halkaların alt katmanı, sonra gövdeleri çizilir -> zincirin bütünü tek koyu konturla çevrilir.
Şekil matematiği prototiple (tools/proto_20261012/gen_talon_form_zincir.py _make_links) birebir aynıdır.
Kullanım (proje kökünden): python -I tools/gen_talon_chain_links.py   (sonra Godot --headless --import)
"""
import math
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', 'assets', 'fx', 'talon_chain', 'links.png'))

DIRS = 32
CELL = 16
CX, CY = 7, 6
LIGHT = (-0.507, -0.862)  ## ışık sol üstten
SHADOW_DY = 3
SHADOW_ALPHA = 84


def shift(m, dx, dy):
    out = np.zeros_like(m)
    h, w = m.shape
    x0, x1 = max(0, -dx), min(w, w - dx)
    y0, y1 = max(0, -dy), min(h, h - dy)
    out[y0 + dy:y1 + dy, x0 + dx:x1 + dx] = m[y0:y1, x0:x1]
    return out


def dilate4(m):
    return m | shift(m, 1, 0) | shift(m, -1, 0) | shift(m, 0, 1) | shift(m, 0, -1)


def link_masks(d):
    """(oval maske, oval ton, çubuk maske, çubuk ton) - 4x4 alt örnekleme, kaplama >= %50."""
    ang = math.pi * d / DIRS
    ux, uy = math.cos(ang), math.sin(ang)
    nx, ny = -uy, ux
    ys, xs = np.mgrid[0:CELL, 0:CELL]
    cov_o = np.zeros((CELL, CELL))
    cov_i = np.zeros((CELL, CELL))
    for sy in (-0.375, -0.125, 0.125, 0.375):
        for sx in (-0.375, -0.125, 0.125, 0.375):
            dx, dy = xs - CX + sx, ys - CY + sy
            al, ac = dx * ux + dy * uy, dx * nx + dy * ny
            outer = (np.abs(al) / 4.3) ** 2.6 + (np.abs(ac) / 2.9) ** 2.6 <= 1.0
            hole = (al / 2.3) ** 2 + (ac / 1.0) ** 2 <= 1.0
            cov_o += outer & ~hole
            ex = np.maximum(np.abs(al) - 2.3, 0.0)
            cov_i += ex * ex + ac * ac <= 1.0
    dx, dy = xs - CX, ys - CY
    lit = dx * LIGHT[0] + dy * LIGHT[1]
    tone_o = np.where(lit > 1.1, 1.0, np.where(lit < -1.1, 0.55, 0.78))
    side = (dx * nx + dy * ny) * (1.0 if (nx * LIGHT[0] + ny * LIGHT[1]) >= 0.0 else -1.0)
    tone_i = np.where(side >= 0.0, 1.0, 0.6)
    return cov_o >= 8, tone_o, cov_i >= 8, tone_i


def under(mask, with_shadow):
    a = np.zeros((CELL, CELL, 4), np.uint8)
    ol = dilate4(mask)
    if with_shadow:
        a[shift(ol, 0, SHADOW_DY) & ~ol] = (255, 255, 255, SHADOW_ALPHA)
    a[ol] = (255, 255, 255, 255)
    return a


def body(mask, tone):
    a = np.zeros((CELL, CELL, 4), np.uint8)
    g = np.round(tone * 255.0).astype(np.uint8)
    a[..., 0] = a[..., 1] = a[..., 2] = np.where(mask, g, 0)
    a[..., 3] = np.where(mask, 255, 0)
    return a


def main():
    sheet = np.zeros((CELL * 4, CELL * DIRS, 4), np.uint8)
    for d in range(DIRS):
        m_o, t_o, m_i, t_i = link_masks(d)
        for row, cell in enumerate((under(m_o, True), body(m_o, t_o), under(m_i, False), body(m_i, t_i))):
            ## Hücre kenarına taşan piksel komşu hücreye sızar: şekil hücreye sığmalı.
            assert not cell[0].any() and not cell[-1].any() and not cell[:, 0].any() and not cell[:, -1].any(), (d, row)
            sheet[row * CELL:(row + 1) * CELL, d * CELL:(d + 1) * CELL] = cell
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(sheet, 'RGBA').save(OUT)
    print('yazildi:', OUT, sheet.shape[1], 'x', sheet.shape[0])


if __name__ == '__main__':
    main()
