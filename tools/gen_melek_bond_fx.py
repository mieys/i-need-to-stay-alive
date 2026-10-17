"""Melek Q/E "SİHİRLİ BAĞ + DALGA" (A Işık İpi) oyun sanatı - madde 204/212. Prototip: tools/proto_20261017/gen_melek_bag.py
(kullanıcı A'yı seçti). Çizim AYNI ilkellerle (gen_melek_fx.py ring/plus/diamond/crack_keep) yapılır, ölçü prototiple aynı:
1 sanat pikseli = 1 Melek pikseli = 2,2368375 x 0,8075 x 0,5 = 0,903 dünya birimi.
Çıktılar:
  assets/fx/melek_bond/ring_heal.png, ring_shield.png  dostun bel halkası; 2 satır (0 = arka yarı, 1 = ön yarı), 40x18 kareler:
      0-11 döngü (4 rün çentiği 90 derece döner), 12-23 aynı döngünün parlak hâli (varış/kuruluş), 24-25 açılış (parlak, %56/%89),
      26-31 kapanış (%86 -> %14), 32-38 yankı halkası (dışa açılıp hilallere kırılır)
  assets/fx/melek_bond/glyphs.png  15x15 kareler: 0-2 yeşil artı r3/r2/r1, 3-4 mana kristali büyük/küçük, 5-8 mavi yıldız 4(çapraz)/
      3(çapraz)/2/1, 9-10 kuruluşta koşan baş parlaması (Q yeşil / E mavi)
  scripts/melek_halo_table.gd  Melek atlasının her 48x48 bölgesinde halenin en sol / en sağ altın pikselinin merkezi (kare pikseli);
      bağ buradan çıkar (kullanıcı: "tam halkadan çıksın"). Melek sanatı değişirse bu betiği yeniden çalıştır.
Kullanım (proje kökünden): python -I tools/gen_melek_bond_fx.py
"""
import math
import os
import re
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..'))
sys.path.insert(0, os.path.join(HERE, 'proto_20261017'))
import gen_melek_fx as M  # noqa: E402
from gen_melek_fx import P, ring, plus, diamond, crack_keep  # noqa: E402

TAU = math.tau
OUT = os.path.join(PROJECT, 'assets', 'fx', 'melek_bond')
os.makedirs(OUT, exist_ok=True)
LIFE, MANA, CREAM = M.LIFE, M.MANA, M.CREAM
PKQ = [LIFE[0], LIFE[1], M.HOLY[2], M.HOLY[3], CREAM]  ## Q dalga paketi (yeşilden hale altınına)
PKE = [MANA[0], MANA[1], MANA[3], MANA[4], CREAM]
RING_RX, RING_RY = 9.5, 3.3
FW, FH = 40, 18
CX, CY = 19.5, 8.5  ## px() indeks koordinatında kare merkezi (simetrik: x 10..29, y 5..12)
LOOP = 12
ECHO = 7
CLOSE_SC = [1.0 - k / 7.0 for k in range(1, 7)]
OPEN_SC = [P.ease_out(1.0 / 3.0), P.ease_out(2.0 / 3.0)]
GLYPH = 15


def hot_pal(pal):
    return PKQ if pal is LIFE else PKE


def bond_ring(back, front, a0, pal, scale=1.0, bright=False):
    """gen_melek_bag.py bond_ring ile aynı çizim (merkez kare ortası)."""
    rx, ry = RING_RX * scale, RING_RY * scale
    if rx < 1.5:
        return
    ring(back, front, CX, CY, rx, ry, pal, thick=2, bright=bright, edge=pal[1])
    for i in range(4):
        a = a0 + i * TAU / 4
        x, y = CX + math.cos(a) * rx, CY + math.sin(a) * ry
        tgt = front if math.sin(a) >= 0 else back
        col = CREAM if bright else hot_pal(pal)[3]
        tgt.px(x, y, col)
        tgt.px(x + (1 if math.cos(a) < 0 else -1), y, col)


def ring_sheet(pal, name):
    frames = []  ## [(back, front)]
    for bright in (False, True):
        for i in range(LOOP):
            b, f = P.Canvas(FW, FH), P.Canvas(FW, FH)
            bond_ring(b, f, i * (TAU / 4) / LOOP, pal, 1.0, bright)
            frames.append((b, f))
    for sc in OPEN_SC:
        b, f = P.Canvas(FW, FH), P.Canvas(FW, FH)
        bond_ring(b, f, 0.0, pal, sc, True)
        frames.append((b, f))
    for sc in CLOSE_SC:
        b, f = P.Canvas(FW, FH), P.Canvas(FW, FH)
        bond_ring(b, f, 0.0, pal, sc, False)
        frames.append((b, f))
    for k in range(ECHO):
        b, f = P.Canvas(FW, FH), P.Canvas(FW, FH)
        tt = k / (ECHO - 1)
        R = RING_RX + 7 * P.ease_out(tt)
        ring(b, f, CX, CY, R, R * 0.35, pal, thick=1, keep=crack_keep(2.1, max(0.0, tt - 0.3) * 1.5, 5))
        frames.append((b, f))
    sheet = Image.new('RGBA', (FW * len(frames), FH * 2), (0, 0, 0, 0))
    for i, (b, f) in enumerate(frames):
        for row, cv in enumerate((b, f)):
            im = cv.image()
            assert not np.array(im)[:, :, 3][[0, -1], :].any() and not np.array(im)[:, :, 3][:, [0, -1]].any(), \
                '%s kare %d tuval kenarına değiyor' % (name, i)
            sheet.alpha_composite(im, (i * FW, row * FH))
    sheet.save(os.path.join(OUT, name))
    return len(frames)


def glyph_sheet():
    cells = []

    def cell(fn):
        cv = P.Canvas(GLYPH, GLYPH)
        fn(cv)
        cells.append(cv)
    for r in (3, 2, 1):
        cell(lambda cv, r=r: plus(cv, 7, 7, r, LIFE))
    cell(lambda cv: diamond(cv, 7, 7, 1.5, 2.5, MANA))
    cell(lambda cv: diamond(cv, 7, 7, 1.0, 1.6, MANA))
    for size, dg in ((4, True), (3, True), (2, False), (1, False)):
        cell(lambda cv, size=size, dg=dg: P.star(cv, 7, 7, size, P.WHITE, MANA[3], diag=dg))
    for pal in (LIFE, MANA):
        def head(cv, pal=pal):
            P.disc_flash(cv, 7.5, 7.5, 1.6, core=CREAM, rim=pal[3])
            P.star(cv, 7, 7, 2, P.WHITE, pal[3])
        cell(head)
    sheet = Image.new('RGBA', (GLYPH * len(cells), GLYPH), (0, 0, 0, 0))
    for i, cv in enumerate(cells):
        sheet.alpha_composite(cv.image(), (i * GLYPH, 0))
    sheet.save(os.path.join(OUT, 'glyphs.png'))
    return len(cells)


GOLD = {(247, 203, 63), (243, 204, 65), (239, 216, 47)}


def halo_table():
    """melek_frames.tres'teki her AtlasTexture (sayfa + 48x48 bölge) için halenin en sol / en sağ altın pikseli."""
    tres = open(os.path.join(PROJECT, 'assets', 'characters', 'melek_frames.tres'), encoding='utf-8').read()
    sheets = {i: p for p, i in re.findall(r'\[ext_resource type="Texture2D" path="res://([^"]+)" id="([^"]+)"\]', tres)}
    pairs = re.findall(r'atlas = ExtResource\("([^"]+)"\)\s*region = Rect2\(([\d.]+), ([\d.]+), 48, 48\)', tres)
    by_sheet = {}
    for sid, x, y in pairs:
        by_sheet.setdefault(sheets[sid], set()).add((int(float(x)), int(float(y))))
    blocks, n_found, n_total = [], 0, 0
    for path in sorted(by_sheet):
        img = np.array(Image.open(os.path.join(PROJECT, path)).convert('RGBA')).astype(int)
        name = os.path.splitext(os.path.basename(path))[0]
        rows = []
        for (x, y) in sorted(by_sheet[path]):
            n_total += 1
            blk = img[y:y + 48, x:x + 48]
            m = np.zeros(blk.shape[:2], dtype=bool)
            for (r, g, b) in GOLD:
                m |= (blk[:, :, 3] > 0) & (blk[:, :, 0] == r) & (blk[:, :, 1] == g) & (blk[:, :, 2] == b)
            ys, xs = np.where(m)
            if len(xs) == 0:
                continue
            n_found += 1
            lx, rx = xs.min(), xs.max()
            ly, ry = ys[xs == lx].mean(), ys[xs == rx].mean()
            rows.append('\t\tVector2i(%d, %d): [Vector2(%.1f, %.1f), Vector2(%.1f, %.1f)],' % (x, y, lx + 0.5, ly + 0.5, rx + 0.5, ry + 0.5))
        if rows:
            blocks.append('\t"%s": {\n%s\n\t},' % (name, '\n'.join(rows)))
    src = ('## OTOMATİK ÜRETİLDİ - elle düzenleme: tools/gen_melek_bond_fx.py (Melek sanatı değişirse yeniden çalıştır).\n'
           '## Melek sayfa adı (assets/characters/melek/sheets/<ad>.png) -> 48x48 bölge konumu -> halenin en sol ve en sağ ALTIN\n'
           '## pikselinin merkezi (kare pikseli, sol üst 0,0). Melek Q/E bağı (melek_bond_fx.gd) haleden buradan çıkar; halesiz kareler yok.\n'
           'const POINTS := {\n' + '\n'.join(blocks) + '\n}\n')
    with open(os.path.join(PROJECT, 'scripts', 'melek_halo_table.gd'), 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(src)
    return n_found, n_total


def main():
    n1 = ring_sheet(LIFE, 'ring_heal.png')
    n2 = ring_sheet(MANA, 'ring_shield.png')
    g = glyph_sheet()
    h, total = halo_table()
    print('halka kareleri:', n1, n2, '| glif:', g, '| hale tablosu:', h, '/', total, 'bölge')


if __name__ == '__main__':
    main()
