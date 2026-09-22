"""assets/ui/kit çıktısının 9-slice büyütülmüş önizlemesi (Godot StyleBoxTexture'ı taklit eder). Kullanım: python tools/preview_ui_kit.py <out.png>"""
import os
import sys
from PIL import Image

KIT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'ui', 'kit')


def load(n):
    return Image.open(os.path.join(KIT, n)).convert('RGBA')


def nine(im, w, h, ml, mt, mr, mb):
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    iw, ih = im.size
    xs = [(0, ml, 0, ml), (ml, w - mr, ml, iw - mr), (w - mr, w, iw - mr, iw)]
    ys = [(0, mt, 0, mt), (mt, h - mb, mt, ih - mb), (h - mb, h, ih - mb, ih)]
    for (dx0, dx1, sx0, sx1) in xs:
        for (dy0, dy1, sy0, sy1) in ys:
            if dx1 <= dx0 or dy1 <= dy0 or sx1 <= sx0 or sy1 <= sy0:
                continue
            piece = im.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST)
            out.alpha_composite(piece, (dx0, dy0))
    return out


def nine_tile(im, w, h, ml, mt, mr, mb):
    """StyleBoxTexture AXIS_STRETCH_MODE_TILE emulasyonu: kenar ve orta bolgeler esnetilmeden karo olarak tekrarlanir."""
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    iw, ih = im.size

    def fill(dx0, dy0, dx1, dy1, sx0, sy0, sx1, sy1):
        if dx1 <= dx0 or dy1 <= dy0 or sx1 <= sx0 or sy1 <= sy0:
            return
        tile = im.crop((sx0, sy0, sx1, sy1))
        tw, th = tile.size
        for yy in range(dy0, dy1, th):
            for xx in range(dx0, dx1, tw):
                piece = tile.crop((0, 0, min(tw, dx1 - xx), min(th, dy1 - yy)))
                out.alpha_composite(piece, (xx, yy))

    xs = [(0, ml, 0, ml), (ml, w - mr, ml, iw - mr), (w - mr, w, iw - mr, iw)]
    ys = [(0, mt, 0, mt), (mt, h - mb, mt, ih - mb), (h - mb, h, ih - mb, ih)]
    for (dx0, dx1, sx0, sx1) in xs:
        for (dy0, dy1, sy0, sy1) in ys:
            fill(dx0, dy0, dx1, dy1, sx0, sy0, sx1, sy1)
    return out


def main(dst):
    bg = Image.new('RGBA', (1500, 900), (78, 96, 60, 255))
    y = 10
    # butonlar
    x = 10
    for name, w in (('wood', 300), ('wood', 180), ('green', 200), ('dark', 220), ('red', 200)):
        for st in ('normal', 'hover', 'pressed', 'disabled', 'focus'):
            if st != 'normal' and name != 'wood':
                continue
            b = nine_tile(load('btn_%s_%s.png' % (name, st)), w if st == 'normal' else 200, 64 if st == 'normal' else 56, 20, 16, 20, 16)
            bg.alpha_composite(b, (x, y))
            x += b.width + 12
            if x > 1300:
                x = 10
                y += 80
        y += 80 if name != 'wood' else 0
        x = 10
    y = 260
    # paneller
    win = nine(load('panel_window.png'), 620, 340, 36, 36, 36, 36)
    bg.alpha_composite(win, (10, y))
    ins = nine(load('panel_inset.png'), 200, 120, 12, 12, 12, 12)
    bg.alpha_composite(ins, (650, y))
    x = 650
    for n in ('panel_card.png', 'panel_card_selected.png', 'panel_card_sold.png'):
        c = nine(load(n), 150, 220, 18, 18, 18, 18)
        bg.alpha_composite(c, (x, y + 140))
        x += 160
    pl = nine(load('panel_plaque.png'), 360, 56, 20, 16, 20, 16)
    bg.alpha_composite(pl, (880, y))
    # HUD parçaları
    y2 = 620
    av = load('hud_avatar_frame.png')
    port = Image.new('RGBA', av.size, (90, 60, 120, 255))
    bg.alpha_composite(port, (10, y2))
    bg.alpha_composite(av, (10, y2))
    bg.alpha_composite(load('hud_level_badge.png'), (70, y2 + 74))
    for i, k in enumerate(('hp', 'shield')):
        fr = nine(load('hud_bar_frame_%s.png' % k), 340, 36, 30, 0, 10, 0)
        under = nine(load('hud_bar_under.png'), 340 - 30 - 10, 24, 0, 0, 0, 0)
        fill = load('hud_bar_fill.png').resize((int((340 - 40) * (0.7 if k == 'hp' else 0.45)), 24), Image.NEAREST)
        tint = (70, 190, 80) if k == 'hp' else (61, 150, 232)
        px = fill.load()
        for yy in range(fill.height):
            for xx in range(fill.width):
                r, g, b, a = px[xx, yy]
                px[xx, yy] = (r * tint[0] // 255, g * tint[1] // 255, b * tint[2] // 255, a)
        bg.alpha_composite(under, (130 + 30, y2 + 10 + i * 46 + 6))
        bg.alpha_composite(fill, (130 + 30, y2 + 10 + i * 46 + 6))
        bg.alpha_composite(fr, (130, y2 + 10 + i * 46))
    x = 500
    for n in ('hud_skill_frame.png', 'hud_skill_frame_spirit.png', 'hud_skill_frame_small.png'):
        f = load(n)
        slot = Image.new('RGBA', f.size, (30, 22, 16, 255))
        bg.alpha_composite(slot, (x, y2))
        bg.alpha_composite(f, (x, y2))
        x += f.width + 16
    bg.alpha_composite(load('hud_minimap_ring.png'), (x + 20, y2 - 20))
    bg.save(dst)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'preview_ui_kit.png')
