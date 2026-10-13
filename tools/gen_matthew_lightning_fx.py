#!/usr/bin/env python3
"""Matthew rework (2026-10-12, madde 98): şimşek efektlerinin oyun sprite sayfaları + 4 yetenek ikonu.

Çizim kodu prototip üreticisinde (tools/proto_20261012/gen_matthew_simsek.py - kullanıcının onayladığı kareler); burası aynı
fonksiyonları çağırıp oyunun okuduğu sayfalara dizer. Oyunda her sayfa TEXEL (1.212) ölçeğiyle gösterilir (1 sanat pikseli = 1 texel).
Kare boyutları / kare sayıları scripts/matthew_lightning.gd SHEETS tablosuyla AYNI olmalı.

Kullanım (repo kökünden):  python -I tools/gen_matthew_lightning_fx.py      (sonra Godot --headless --import ya da editöre dön)
Çıktı: assets/fx/matthew_lightning/*.png  +  assets/skills/matthew_{simsek_hucumu,elektrik_topu,yildirim_kalkani,yildirim_hizi}_icon.png
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'proto_20261012'))
import gen_matthew_simsek as g  # noqa: E402

OUT = os.path.join(ROOT, 'assets', 'fx', 'matthew_lightning')

## ORAN DÜZELTMESİ: prototipte Matthew'in pikseli = efekt pikseli sayılmıştı; oyunda Matthew'in sprite ölçeği 1,968417 x 0,8075
## = 1,5895 dünya birimi / piksel, efektler ise TEXEL = 1,212 ile çizilir. Kullanıcının GÖVDEYE GÖRE onayladığı boyutlar
## (kalkan yarıçapı 26, top yarıçapı 13 / 19,5 karakter pikseli) bu oranla efekt pikseline çevrilir - ekrandaki oran prototiple aynı kalır.
CHAR_TEXEL = 1.968417 * 0.95 * 0.85
FX_TEXEL = 1.212
K = CHAR_TEXEL / FX_TEXEL  ## ~1,311
DOME_R = round(26 * K)  ## 34
BALL_R = round(13 * K)  ## 17
BALL_R_BIG = round(19.5 * K * 2) / 2.0  ## 25,5
SKILLS = os.path.join(ROOT, 'assets', 'skills')
os.makedirs(OUT, exist_ok=True)


def _img(layer):
    return layer.img() if isinstance(layer, g.Layer) else layer


def _check_border(name, frames):
    """Hiçbir kare tuval kenarına değmemeli (kenarda düz kesilen efekt - bkz. hafıza: fx-texel-density)."""
    for i, fr in enumerate(frames):
        a = np.array(fr)[:, :, 3]
        if a[0, :].any() or a[-1, :].any() or a[:, 0].any() or a[:, -1].any():
            print('   UYARI: %s kare %d tuval kenarına değiyor' % (name, i))


def save_sheet(name, frames, cols=None, check=True):
    frames = [_img(f) for f in frames]
    if check:
        _check_border(name, frames)
    fw, fh = frames[0].size
    cols = cols or len(frames)
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new('RGBA', (fw * cols, fh * rows), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr, ((i % cols) * fw, (i // cols) * fh))
    path = os.path.join(OUT, name + '.png')
    sheet.save(path)
    print('  %s  kare %dx%d x %d (%d sütun)' % (os.path.relpath(path, ROOT), fw, fh, len(frames), cols))


def impact_frames(size, R, with_ring, seed):
    out = []
    for f in range(5):
        ly = g.Layer(size, size)
        g.impact(ly, size / 2.0, size / 2.0, R, f, seed=seed, with_ring=with_ring)
        out.append(ly)
    return out


def trail_frames(strong):
    """3 varyant (satır) x 8 evre (sütun), karo 16x32. Dikiş kenarları (sol/sağ) bilerek tuvale değer."""
    out = []
    for v in range(3):
        for stage in range(g.TRAIL_STAGES):
            out.append(g.trail_tile(v, stage, strong))
    return out


def form_burst_frames():
    """Topa dönüşme / toptan çıkma patlaması: krem disk + 6 şimşek -> küçülen disk -> kıvılcımlar."""
    size = int(2 * BALL_R + 40)
    c = size / 2.0
    f0 = g.burst_form(BALL_R, 5)
    f1 = g.Layer(size, size)
    g.impact(f1, c, c, 19, 2, seed=31)
    f2 = g.Layer(size, size)
    g.impact(f2, c, c, 19, 3, seed=31)
    f3 = g.Layer(size, size)
    g.impact(f3, c, c, 19, 4, seed=31)
    return [f0, f1, f2, f3]


def cast_frames():
    """R çağırma şimşeği: yukarıdan Matthew'in başına iner. Kare 64x110, hedef nokta (32, 86)."""
    import random
    W, H = 64, 110
    tx, ty = 32, 86
    out = []
    for s in range(5):
        ly = g.Layer(W, H)
        rng = random.Random(60 + min(s, 2))
        pts = g.zig(rng, (tx + 20, 3), (tx, ty), 11, 6.0)
        if s == 0:
            g.bolt(ly, pts, w=1, outl=False, core=g.G[3])
        elif s == 1:
            g.branches(ly, rng, pts, 2, 8, 14)
            g.bolt(ly, pts, w=5, taper=3)
        elif s == 2:
            g.bolt(ly, pts, w=3, taper=3)
        elif s == 3:
            g.bolt(ly, pts, w=1, outl=False, core=g.G[3], keep=g.dash(0.5, 3))
        if s >= 1:
            g.impact(ly, tx, ty, 10, s - 1, seed=21)
        out.append(ly)
    return out


def main():
    print('Matthew şimşek efektleri:')
    save_sheet('impact', impact_frames(56, 13, False, 3))
    save_sheet('impact_ring', impact_frames(72, 14, True, 11))
    save_sheet('trail', trail_frames(False), cols=g.TRAIL_STAGES, check=False)
    save_sheet('trail_max', trail_frames(True), cols=g.TRAIL_STAGES, check=False)
    save_sheet('ball', [g.ball(i, BALL_R, pad=13) for i in range(8)])
    save_sheet('ball_big', [g.ball(i, BALL_R_BIG, pad=14.5) for i in range(8)])
    save_sheet('form_burst', form_burst_frames())
    g.DOME_R = float(DOME_R)
    save_sheet('shield_loop', [g.shield_loop(i, size=96) for i in range(24)], cols=6)
    save_sheet('shield_pop', [g.shield_pop(f, size=196) for f in range(8)])
    save_sheet('nova', [g.shield_explosion(f) for f in range(10)])
    save_sheet('cast', cast_frames())
    print('İkonlar:')
    for name, fn in (('matthew_simsek_hucumu_icon', g.icon_q), ('matthew_elektrik_topu_icon', g.icon_e), ('matthew_yildirim_kalkani_icon', g.icon_r), ('matthew_yildirim_hizi_icon', g.icon_pasif)):
        path = os.path.join(SKILLS, name + '.png')
        fn().resize((144, 144), Image.NEAREST).save(path)
        print('  ' + os.path.relpath(path, ROOT))


if __name__ == '__main__':
    main()
