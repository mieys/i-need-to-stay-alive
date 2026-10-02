"""Telefon HUD'u yuvarlak yetenek cerceveleri (kullanici onayli, 2026-10-01: "deminki gibi olsun ama cok kalin olmasin").
assets/ui/kit/hud_skill_frame.png'nin paleti ve isik yonu (sol ust), IKONLA AYNI piksel yogunlugunda (48 px ikon + 3 px kenar):
1 px koyu dis hat + 2 px ahsap halka + 1 px koyu ic hat, 45 derecelerde 1 px altin percin.
Not: ilk deneme 26 sanat pikseli x3 cizilmisti - ikonun 48 px ayrintisinin yaninda kaba/kalin durdu ("iğrenç ötesi").

Calistir: python tools/gen_round_skill_frame.py
Cikti: assets/ui/kit/hud_skill_frame_round.png (54x54), hud_skill_frame_spirit_round.png (54x54, mor)."""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "kit")
OUTLINE = (56, 32, 17, 255)
RIVET = (183, 136, 35, 255)
WOOD = [(104, 62, 32, 255), (132, 86, 44, 255), (155, 107, 58, 255), (174, 128, 78, 255)]
SPIRIT = [(69, 28, 108, 255), (99, 45, 149, 255), (128, 72, 175, 255), (169, 133, 194, 255)]
SIZE = 54
RING = 2


def frame(n, ring_w, pal):
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    c = (n - 1) / 2.0
    r_out = n / 2.0 - 0.2
    r_ro = r_out - 1.0
    r_ri = r_ro - ring_w
    r_in = r_ri - 1.0
    for y in range(n):
        for x in range(n):
            dx, dy = x - c, y - c
            d = math.hypot(dx, dy)
            if d > r_out or d <= r_in:
                continue
            lit = (-(dx + dy) / (d * 1.4142)) if d > 0 else 0
            if d > r_ro or d <= r_ri:
                im.putpixel((x, y), OUTLINE)
            else:
                idx = 3 if lit > 0.55 else 2 if lit > 0.05 else 1 if lit > -0.5 else 0
                im.putpixel((x, y), pal[idx])
    rm = (r_ri + r_ro) / 2.0
    for a in (45, 135, 225, 315):
        im.putpixel((round(c + math.cos(math.radians(a)) * rm), round(c + math.sin(math.radians(a)) * rm)), RIVET)
    return im


if __name__ == "__main__":
    frame(SIZE, RING, WOOD).save(os.path.join(OUT, "hud_skill_frame_round.png"))
    frame(SIZE, RING, SPIRIT).save(os.path.join(OUT, "hud_skill_frame_spirit_round.png"))
    print("ok")
