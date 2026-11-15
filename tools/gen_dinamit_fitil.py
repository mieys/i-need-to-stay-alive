"""Dinamit (eski Fisek) fitil kivilcimi spritesheet'i - madde 651.

Kivilcim TASARIMI Korsan bombasininkiyle AYNI (tools/gen_korsan_bomb_sprite.py draw_spark: nefes alan sicak hale + titresen
cekirdek + ucusan korlar, 12 karelik kusursuz dongu); burada govdesiz, tek basina pisirilir cunku dinamit havada DONER:
govde (assets/weapons/yeni/dinamit.png) firework_projectile.gd'de doner, kivilcim ayri AnimatedSprite2D olarak fitil
ucunu izler ve DONMEZ (korlar hep asagi duser).

Olcek: 1 sayfa pikseli = 1 dinamit pikseli (firework_projectile.gd ART_WORLD_PX).
Calistir: python tools/gen_dinamit_fitil.py  (sonra Godot --headless --path . --import)
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402
import gen_korsan_bomb_sprite as kb  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "dinamit")
W, H = 40, 40
TIP = (20.0, 22.0)  # fitil ucu karede (merkez + firework_projectile.gd FUSE_SHEET_OFFSET)


def main():
    os.makedirs(OUT, exist_ok=True)
    frames = []
    for i in range(kb.N_LOOP):
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        kb.draw_spark(im, TIP[0], TIP[1], i, i)
        frames.append(im)
    # kirpilma denetimi: buyuk tuvalde ciz, tasan piksel var mi
    for i in range(kb.N_LOOP):
        big = Image.new("RGBA", (W * 3, H * 3), (0, 0, 0, 0))
        kb.draw_spark(big, TIP[0] + W, TIP[1] + H, i, i)
        x0, y0, x1, y1 = big.getbbox()
        assert x0 >= W and y0 >= H and x1 <= 2 * W and y1 <= 2 * H, ("kare tasiyor", i, (x0 - W, y0 - H, x1 - W, y1 - H))
    sheet = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * W, 0))
    sheet.save(os.path.join(OUT, "fuse_sheet.png"))
    write_sprite_frames(os.path.join(OUT, "fuse_frames.tres"), "res://assets/fx/dinamit/fuse_sheet.png", W, H,
                        [("loop", (0, 0), len(frames), True, 14.0)])
    print("sheet", sheet.size, "FUSE_SHEET_OFFSET = Vector2(%.1f, %.1f)" % (W / 2 - TIP[0], H / 2 - TIP[1]))


if __name__ == "__main__":
    main()
