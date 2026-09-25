#!/usr/bin/env python3
"""Sovalye Adam: E (Koruma Bariyeri) + pasif (Dikenli Zirh) ikonlari -> assets/skills/*.png

Kullanim (repo kokunden):
    python tools/gen_sovalye_icons.py      (sonra Godot editorune donunce import olur)

Kullanici istegi (2026-09-25): "pasifi ve E yetenegi icin (cunku ikonsuzlar) yeni ikon tasarlamani istiyorum hafif
viynetli sirin pixel art tarzinda". tools/gen_matthew_icons.py / gen_elara_korsan_icons.py ile AYNI dil ve yardimcilar:
48x48 sanat izgarasi, kare karo (koyu kontur, dither'li degrade, yumusak isik, kose vinyeti), 1 px detay, 3x NEAREST.
  - E  Koruma Bariyeri: mor-mavi baloncuk, etrafinda iki egik yorungede donen serit (oyundaki efektle ayni dil), ortada
       minik bir kalp - dostu koruyor.
  - Pasif Dikenli Zirh: dikenli celik kalkan + ondan geri seken kirmizi ok (hasar yansitma).
"""
import math
import os
import sys

from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_elara_korsan_icons import C, canvas, finish, put, sparkle, tile  # noqa: E402

B_DEEP = C('#2c2880')
B_INDIGO = C('#4e52d6')
B_BLUE = C('#708eff')
B_LAV = C('#aa8cff')
B_PALE = C('#ced8ff')
WHITE = C('#ffffff')

STEEL = (C('#f4f7fb'), C('#c3cbd8'), C('#8a93a6'), C('#4c5366'))  # parlama, acik, orta, golge
RED = (C('#ffb0a8'), C('#f0505a'), C('#b8283a'))


def orbit_arc(e, cx, cy, r, incl, tilt, head, span, cols_front, cols_back, front_only=False):
    """3B egik yorungede bas tarafi parlak serit; on yarisi parlak, arka yarisi soluk."""
    steps = 120
    for s in range(steps + 1):
        u = s / steps
        phi = head - span * (1 - u)
        x3 = r * math.cos(phi)
        y3 = r * math.sin(phi) * math.cos(incl)
        z3 = r * math.sin(phi) * math.sin(incl)
        xs = x3 * math.cos(tilt) - y3 * math.sin(tilt)
        ys = x3 * math.sin(tilt) + y3 * math.cos(tilt)
        front = z3 > 0
        if front_only and not front:
            continue
        cols = cols_front if front else cols_back
        col = cols[min(len(cols) - 1, int(u * len(cols)))]
        put(e, [(round(cx + xs), round(cy + ys))], col)
        if u > 0.3:  # 2 piksel kalin serit (dis tarafa bir ton koyusu)
            put(e, [(round(cx + xs * 1.07), round(cy + ys * 1.07))], cols[max(0, min(len(cols) - 1, int(u * len(cols))) - 1)])


# ============================================================== E - Koruma Bariyeri
def koruma_bariyeri():
    im = tile(C('#4a3f9e'), C('#15123a'), C('#7b73e6'), C('#b9b2ff'), C('#15123a'), glow_center=(24, 24), glow_r=(15, 15))
    back = canvas()
    e = canvas()
    fx = canvas()
    cx, cy, r = 24, 24, 15
    d = ImageDraw.Draw(back)
    # baloncuk: yari saydam govde + kenar
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=C('#5a5ee0', 150))
    d.ellipse((cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2), fill=C('#6f7cf0', 120))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=B_PALE)
    # sol ust parlama yayi + minik parilti
    d.arc((cx - r + 3, cy - r + 3, cx + r - 3, cy + r - 3), 200, 255, fill=WHITE)
    put(back, [(cx - 8, cy - 9), (cx - 9, cy - 8)], WHITE)
    im.alpha_composite(back)
    # ortada minik kalp (korunan dost)
    heart_hi, heart, heart_d = C('#ffd0e0'), C('#ff6f96'), C('#c83c6a')
    hx, hy = cx, cy - 1
    pts = [(hx - 2, hy), (hx - 1, hy), (hx + 1, hy), (hx + 2, hy),
           (hx - 3, hy + 1), (hx - 2, hy + 1), (hx - 1, hy + 1), (hx, hy + 1), (hx + 1, hy + 1), (hx + 2, hy + 1), (hx + 3, hy + 1),
           (hx - 3, hy + 2), (hx - 2, hy + 2), (hx - 1, hy + 2), (hx, hy + 2), (hx + 1, hy + 2), (hx + 2, hy + 2), (hx + 3, hy + 2),
           (hx - 2, hy + 3), (hx - 1, hy + 3), (hx, hy + 3), (hx + 1, hy + 3), (hx + 2, hy + 3),
           (hx - 1, hy + 4), (hx, hy + 4), (hx + 1, hy + 4), (hx, hy + 5)]
    put(e, pts, heart)
    put(e, [(hx + 3, hy + 2), (hx + 2, hy + 3), (hx + 1, hy + 4), (hx, hy + 5)], heart_d)
    put(e, [(hx - 2, hy + 1)], heart_hi)
    # iki egik yorungede donen seritler (bubble'dan biraz buyuk)
    front_cols = [B_BLUE, B_LAV, B_PALE, WHITE]
    back_cols = [B_INDIGO, B_BLUE, B_BLUE, B_LAV]
    orbit_arc(fx, cx, cy, r + 2, math.radians(66), math.radians(26), math.radians(172), math.radians(150), front_cols, back_cols, True)
    orbit_arc(fx, cx, cy, r + 2, math.radians(-66), math.radians(-26), math.radians(352), math.radians(150), front_cols, back_cols, True)
    sparkle(fx, 41, 8, WHITE, B_PALE, 1)
    sparkle(fx, 8, 40, WHITE, B_LAV, 1)
    finish(im, e, fx, "sovalye_koruma_bariyeri_icon.png")


# ============================================================== Pasif - Dikenli Zirh
def dikenli_zirh():
    im = tile(C('#8a3a36'), C('#2a0f12'), C('#c0605a'), C('#f0a49a'), C('#2a0f12'), glow_center=(22, 25), glow_r=(15, 14))
    e = canvas()
    fx = canvas()
    d = ImageDraw.Draw(e)
    L, A, M, D = STEEL
    cx, cy = 21, 26
    # dikenler (kalkanin cevresinde, disari bakan ucgenler)
    for k in range(8):
        a = math.radians(-90 + k * 45)
        bx, by = cx + 11 * math.cos(a), cy + 11 * math.sin(a)
        tx, ty = cx + 16 * math.cos(a), cy + 16 * math.sin(a)
        px, py = -math.sin(a) * 2.2, math.cos(a) * 2.2
        d.polygon([(round(bx + px), round(by + py)), (round(tx), round(ty)), (round(bx - px), round(by - py))], fill=M)
        put(e, [(round(tx), round(ty))], L)
    # yuvarlak celik kalkan (buckler)
    d.ellipse((cx - 12, cy - 12, cx + 12, cy + 12), fill=M)
    d.ellipse((cx - 11, cy - 11, cx + 11, cy + 11), fill=A)
    d.arc((cx - 11, cy - 11, cx + 11, cy + 11), 20, 160, fill=M)
    d.arc((cx - 10, cy - 10, cx + 10, cy + 10), 190, 260, fill=L)
    d.ellipse((cx - 6, cy - 6, cx + 6, cy + 6), outline=M)
    # ortada gobek + parlama
    d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=L)
    d.arc((cx - 3, cy - 3, cx + 3, cy + 3), 0, 120, fill=M)
    put(e, [(cx - 1, cy - 1)], WHITE)
    # sirin yuz: kucuk kararli gozler (kalkan "canli")
    put(e, [(cx - 4, cy + 7), (cx + 4, cy + 7)], D)
    # geri seken kirmizi ok: kalkanin sag ust kenarindan disari, yukari kivrilan kalin ok (hasar geri yansiyor)
    rl, rm, rd = RED
    path = []
    for i in range(0, 31):
        t = i / 30
        path.append((31 + 9 * t, 21 - 13 * t + 3 * t * t))
    for (x, y) in path:
        put(e, [(round(x), round(y)), (round(x) + 1, round(y))], rm)
    for (x, y) in path[1:-4:3]:
        put(e, [(round(x), round(y))], rl)
    ex, ey = path[-1]
    dx, dy = 9.0, -13.0 + 6.0
    ln = math.hypot(dx, dy)
    dx, dy = dx / ln, dy / ln
    px, py = -dy, dx
    tip = (ex + dx * 4, ey + dy * 4)
    d.polygon([(round(tip[0]), round(tip[1])), (round(ex - dx + px * 3.5), round(ey - dy + py * 3.5)),
               (round(ex - dx - px * 3.5), round(ey - dy - py * 3.5))], fill=rm)
    put(e, [(round(ex + dx * 2 - px), round(ey + dy * 2 - py))], rl)
    # carpma noktasinda kucuk kivilcim
    sparkle(fx, 30, 22, WHITE, C('#ffe0a0'), 2)
    finish(im, e, fx, "sovalye_passive_icon.png")


if __name__ == "__main__":
    print("Sovalye ikonlari:")
    koruma_bariyeri()
    dikenli_zirh()
