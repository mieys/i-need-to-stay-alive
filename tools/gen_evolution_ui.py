"""Yetenek evrimi kart satırları (2026-09-28) -> assets/ui/game/levelup_evo_row_{3,4}.png + levelup_evo_row_glow.png

Level atlama ekranının evrim modu (scripts/level_up_screen.gd "YETENEK EVRİMİ" bloğu) normal satırlarla (gen_menu_kit.py
levelup_row, 268x50 sanat px = 804x150) AYNI çizim dilini kullanır; sadece açıklama metni sığsın diye daha uzun: 268x66 sanat
px (3x = 804x198) ve ikon yuvası dikeyde ortalı. Normal evrim Tier 3 (mor), FİNAL Tier 4 (altın-kırmızı) çerçeve.
gen_menu_kit.py'nin TÜMÜNÜ yeniden üretmemek için (diğer dokular değişmesin) sadece bu üç dosya yazılır.

Çalıştır: python tools/gen_evolution_ui.py   (sonra Godot --headless --import)
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_menu_kit as mk  # noqa: E402
from ui_kit_lib import Art  # noqa: E402

ROW_W, ROW_H = 268, 66
SLOT = 38  # ikon yuvası (sanat px) - levelup_row ile aynı


def evo_row(t, w=ROW_W, h=ROW_H):
    f = mk.LEVELUP_TIER.get(t, mk.TIER_FIELD[t])
    body = mk.mix(mk.LEVELUP_BODY, f['deep'], 0.35)
    a = Art(w, h)
    for y in range(h):
        for x in range(w):
            if x in (0, w - 1) or y in (0, h - 1):
                c = mk.OUTL
            elif x in (1, w - 2) or y in (1, h - 2):
                c = f['hi'] if y == 1 else f['dk'] if y == h - 2 else f['md']
            elif x in (2, w - 3) or y in (2, h - 3):
                c = f['deep']
            else:
                c = body
            a.set(x, y, c)
    x0 = 6
    y0 = (h - SLOT) // 2
    for y in range(y0, y0 + SLOT):
        for x in range(x0, x0 + SLOT):
            d = min(x - x0, x0 + SLOT - 1 - x, y - y0, y0 + SLOT - 1 - y)
            a.set(x, y, mk.OUTL if d == 0 else f['lt'] if d == 1 else f['dd'])
    return a


if __name__ == '__main__':
    mk.use_palette(mk.GAME_PAL, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'ui', 'game'))
    for t in (3, 4):
        mk.save(evo_row(t), 'levelup_evo_row_%d.png' % t)
    mk.save(mk.tier_card_glow(ROW_W, ROW_H, 5, 0), 'levelup_evo_row_glow.png')
    print('evrim satırları ->', os.path.abspath(mk.OUTDIR))
