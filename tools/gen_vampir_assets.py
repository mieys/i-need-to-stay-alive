#!/usr/bin/env python3
"""Vampir Cocuk icin oyun assetlerini uretir.

Kullanim (repo kokunden):
    python tools/gen_vampir_assets.py --src <animasyon sayfalarinin (Idle.png, Walk.png ...) oldugu klasor>

1) Kullanicinin verdigi animasyon sayfalarini (her hucre 288x288 = 48x48 piksel sanatinin 6 kat buyutulmusu;
   satirlar yukaridan asagiya: asagi, sol, sag, yukari) KAYIPSIZ olarak 48x48 hucrelere indirip
   assets/characters/vampir/sheets/<ad>.png olarak yazar (SpriteFrames bunlari AtlasTexture ile okur,
   bkz. tools/gen_vampir_frames.py). Kaynak sayfa tam 6x buyutme degilse durur.
2) "Buyuk yarasa" formunu (E yetenegi) PIXEL-ART kareler olarak cizer: bat_<yon>_<1..4>.png.
3) Yetenek/pasif ikonlarini (32x32 sanat -> 128x128 NEAREST) cizer.
4) Portreyi (Idle sayfasi, asagi bakan ilk kare) yazar.
--src verilmezse sadece 2) ve 3) (ve mini yarasalar) uretilir.
SpriteFrames (.tres) burada uretilmez, bkz. tools/gen_vampir_frames.py.
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_CHAR = os.path.join(ROOT, "assets", "characters")
OUT_DIR = os.path.join(OUT_CHAR, "vampir")
OUT_SHEETS = os.path.join(OUT_DIR, "sheets")
OUT_SKILL = os.path.join(ROOT, "assets", "skills")

CELL = 48  # bir animasyon karesi (piksel sanati boyutu)
SRC_SCALE = 6  # kaynak sayfalar 6x buyutulmus gelir
# oyundaki sayfa adi -> kaynak dosya adi (uzantisiz, buyuk/kucuk harf fark etmez)
SHEET_SOURCES = {
    "idle": "Idle",
    "walk": "Walk",
    "run": "Run",
    "eat": "Eat",
    "hurt": "Hurt",
    "read": "Read",
    "shrug": "Shrug",
    "downed": "Down",
    "death": "death",
    "strike": "Strike",
    "chop": "Chop",
    "pickup": "Pickup",
}

OUTLINE = (22, 8, 16, 255)
FUR_D = (44, 20, 38, 255)
FUR_M = (72, 32, 60, 255)
FUR_L = (110, 52, 86, 255)
MEM_D = (60, 16, 36, 255)
MEM_M = (100, 24, 48, 255)
MEM_L = (146, 38, 66, 255)
BONE = (34, 14, 26, 255)
EYE = (255, 72, 72, 255)
EYE_H = (255, 214, 210, 255)
FANG = (244, 238, 226, 255)
EAR_IN = (168, 62, 92, 255)
BLOOD = (196, 24, 40, 255)
BLOOD_D = (120, 12, 28, 255)
BLOOD_L = (255, 96, 96, 255)


def import_sheets(src):
    os.makedirs(OUT_SHEETS, exist_ok=True)
    found = {f.lower(): f for f in os.listdir(src)}
    for name, src_name in SHEET_SOURCES.items():
        fn = found.get(src_name.lower() + ".png")
        if fn is None:
            raise SystemExit(f"eksik animasyon sayfasi: {src_name}.png ({src})")
        a = np.array(Image.open(os.path.join(src, fn)).convert("RGBA"))
        if a.shape[0] % (CELL * SRC_SCALE) or a.shape[1] % (CELL * SRC_SCALE):
            raise SystemExit(f"{fn}: boyut {a.shape[1]}x{a.shape[0]}, {CELL * SRC_SCALE} px'lik hucrelerin kati olmali")
        small = a[::SRC_SCALE, ::SRC_SCALE]
        if not (np.repeat(np.repeat(small, SRC_SCALE, axis=0), SRC_SCALE, axis=1) == a).all():
            raise SystemExit(f"{fn}: tam {SRC_SCALE}x buyutulmus piksel sanati degil, kayipsiz kucultulemez")
        Image.fromarray(small).save(os.path.join(OUT_SHEETS, name + ".png"))
        print(f"  {name}.png  {small.shape[1] // CELL} kare x {small.shape[0] // CELL} yon")
    # Portre: Idle sayfasi, ilk satir (asagi) ilk kare - diger karakterlerdeki gibi tam kare.
    idle = Image.open(os.path.join(OUT_SHEETS, "idle.png"))
    idle.crop((0, 0, CELL, CELL)).save(os.path.join(OUT_CHAR, "vampir_portrait.png"))


def new_layer(size=96):
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def outline(img, color=OUTLINE):
    a = np.array(img)
    alpha = a[:, :, 3] > 0
    grown = alpha.copy()
    grown[1:, :] |= alpha[:-1, :]
    grown[:-1, :] |= alpha[1:, :]
    grown[:, 1:] |= alpha[:, :-1]
    grown[:, :-1] |= alpha[:, 1:]
    edge = grown & ~alpha
    a[edge] = color
    return Image.fromarray(a)


def wing_pts(side, phase):
    """Kanat: omuzdan kola, kanat ucuna, tarak (scallop) kenarli zar. phase 0 yukari, 2 asagi."""
    tip_y = [14, 34, 66, 34][phase]
    elb_y = [22, 30, 46, 30][phase]
    mem_y = [50, 52, 62, 52][phase]
    sx = 1 if side == "r" else -1
    cx = 48

    def X(dx):
        return cx + sx * dx

    return [
        (X(9), 46),
        (X(22), elb_y),
        (X(40), tip_y),
        (X(36), (tip_y + mem_y) // 2 + 2),
        (X(31), mem_y - 2),
        (X(27), (tip_y + mem_y) // 2 + 8),
        (X(22), mem_y + 2),
        (X(17), (tip_y + mem_y) // 2 + 10),
        (X(12), mem_y - 2),
        (X(9), 56),
    ]


def draw_wing(d, side, phase):
    pts = wing_pts(side, phase)
    d.polygon(pts, fill=MEM_M)
    inner = [(48 + (p[0] - 48) * 0.55, 46 + (p[1] - 46) * 0.7) for p in pts]
    d.polygon(inner, fill=MEM_D)
    d.line([pts[0], pts[1], pts[2]], fill=BONE, width=2)
    d.line([pts[1], pts[4]], fill=BONE, width=1)
    d.line([pts[1], pts[6]], fill=BONE, width=1)
    d.line([pts[1], pts[8]], fill=BONE, width=1)
    d.line([pts[2], pts[3], pts[4]], fill=MEM_L, width=1)


def draw_head_front(d, back=False):
    cx = 48
    d.polygon([(cx - 13, 30), (cx - 12, 12), (cx - 3, 26)], fill=FUR_M)
    d.polygon([(cx + 13, 30), (cx + 12, 12), (cx + 3, 26)], fill=FUR_M)
    if not back:
        d.polygon([(cx - 11, 27), (cx - 11, 17), (cx - 6, 25)], fill=EAR_IN)
        d.polygon([(cx + 11, 27), (cx + 11, 17), (cx + 6, 25)], fill=EAR_IN)
    d.ellipse([cx - 12, 24, cx + 12, 46], fill=FUR_M)
    d.ellipse([cx - 9, 27, cx + 9, 44], fill=FUR_L if not back else FUR_M)
    if back:
        d.ellipse([cx - 7, 30, cx + 7, 42], fill=FUR_D)
        return
    d.rectangle([cx - 8, 33, cx - 5, 36], fill=EYE)
    d.rectangle([cx + 5, 33, cx + 8, 36], fill=EYE)
    d.point([(cx - 7, 33), (cx + 7, 33)], fill=EYE_H)
    d.polygon([(cx - 2, 38), (cx + 2, 38), (cx, 41)], fill=FUR_D)
    d.rectangle([cx - 5, 42, cx + 5, 44], fill=MEM_D)
    d.polygon([(cx - 4, 43), (cx - 2, 43), (cx - 3, 48)], fill=FANG)
    d.polygon([(cx + 4, 43), (cx + 2, 43), (cx + 3, 48)], fill=FANG)


def draw_body_front(d, phase, back=False):
    cx = 48
    bob = [0, 1, 2, 1][phase]
    d.ellipse([cx - 11, 44 + bob, cx + 11, 72 + bob], fill=FUR_M)
    d.ellipse([cx - 8, 47 + bob, cx + 8, 68 + bob], fill=FUR_L if not back else FUR_D)
    d.rectangle([cx - 7, 71 + bob, cx - 4, 75 + bob], fill=FUR_D)
    d.rectangle([cx + 4, 71 + bob, cx + 7, 75 + bob], fill=FUR_D)
    if not back:
        d.polygon([(cx - 5, 50 + bob), (cx + 5, 50 + bob), (cx, 62 + bob)], fill=BLOOD_D)


def bat_front(phase, back=False):
    img = new_layer()
    d = ImageDraw.Draw(img)
    draw_wing(d, "l", phase)
    draw_wing(d, "r", phase)
    draw_body_front(d, phase, back)
    draw_head_front(d, back)
    return outline(img)


def bat_side(phase):
    """Saga bakan profil. Yakin kanat one, uzak kanat biraz arkada ve koyu."""
    img = new_layer()
    d = ImageDraw.Draw(img)
    tip = [12, 34, 68, 34][phase]
    elb = [26, 38, 56, 38][phase]

    def wing(dx, col_a, col_b, off_y):
        pts = [(46, 50), (40 + dx, elb + off_y), (26 + dx, tip + off_y), (30 + dx, (tip + 50) // 2 + 6),
               (36 + dx, 56 + off_y // 2), (40 + dx, (tip + 56) // 2 + 10), (46, 58)]
        d.polygon(pts, fill=col_a)
        d.polygon([(46 + (p[0] - 46) * 0.6, 50 + (p[1] - 50) * 0.7) for p in pts], fill=col_b)
        d.line([pts[0], pts[1], pts[2]], fill=BONE, width=2)
        d.line([pts[1], pts[4]], fill=BONE, width=1)
        d.line([pts[2], pts[3]], fill=MEM_L, width=1)

    wing(6, MEM_D, BONE, 2)
    d.polygon([(30, 56), (18, 60), (30, 62)], fill=FUR_D)
    d.ellipse([28, 42, 62, 66], fill=FUR_M)
    d.ellipse([32, 46, 58, 64], fill=FUR_L)
    d.rectangle([34, 64, 38, 69], fill=FUR_D)
    d.rectangle([46, 64, 50, 69], fill=FUR_D)
    d.polygon([(58, 36), (64, 18), (72, 34)], fill=FUR_M)
    d.polygon([(62, 33), (65, 23), (69, 33)], fill=EAR_IN)
    d.ellipse([56, 34, 80, 54], fill=FUR_M)
    d.ellipse([60, 37, 78, 52], fill=FUR_L)
    d.rectangle([72, 40, 75, 43], fill=EYE)
    d.point([(74, 40)], fill=EYE_H)
    d.polygon([(76, 46), (82, 46), (80, 50)], fill=FUR_D)
    d.polygon([(70, 50), (73, 50), (72, 56)], fill=FANG)
    wing(-4, MEM_M, MEM_D, 0)
    return outline(img)


# Yarasa kareleri ayni SpriteFrames'te oldugu icin karakterin anim.offset'ini paylasir (bkz. characters.gd
# Vampir "offset": (0, 10) - 48x48 karakter karelerinin ayaklari yerde dursun diye asagi kaydirilmis).
# Eski 64x64 karakterde offset (0, -5) idi ve 96x96 yarasa gorunumu ayaklarin ~9 texel ustunde havada
# duruyordu. Ayni yuksekligi korumak icin yarasa 96x112 tuvale, 7 piksel yukari kaydirilarak yerlestirilir:
#   dunya y (texel) = (govde_merkezi_satiri - tuval_yuksekligi / 2) + offset_y = (37 - 56) + 10 = -9  (eskisi: 44 - 48 - 5 = -9)
BAT_CANVAS = (96, 112)
BAT_SHIFT_Y = -7


def _to_bat_canvas(frame):
    canvas = Image.new("RGBA", BAT_CANVAS, (0, 0, 0, 0))
    canvas.paste(frame, (0, BAT_SHIFT_Y))
    return canvas


def make_bat_frames():
    os.makedirs(OUT_DIR, exist_ok=True)
    for phase in range(4):
        front = bat_front(phase, back=False)
        back = bat_front(phase, back=True)
        side_r = bat_side(phase)
        side_l = side_r.transpose(Image.FLIP_LEFT_RIGHT)
        _to_bat_canvas(front).save(os.path.join(OUT_DIR, f"bat_down_{phase + 1}.png"))
        _to_bat_canvas(back).save(os.path.join(OUT_DIR, f"bat_up_{phase + 1}.png"))
        _to_bat_canvas(side_r).save(os.path.join(OUT_DIR, f"bat_right_{phase + 1}.png"))
        _to_bat_canvas(side_l).save(os.path.join(OUT_DIR, f"bat_left_{phase + 1}.png"))


# ---------------------------------------------------------------- ikonlar (32x32 sanat -> 128x128)
def icon_base():
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)
    for y in range(32):
        for x in range(32):
            r = ((x - 16) ** 2 + (y - 16) ** 2) ** 0.5
            v = max(0.0, 1.0 - r / 22.0)
            level = int(v * 4)
            if level == 3 and (x + y) % 2 == 0:
                level = 2
            col = [(8, 2, 6), (36, 6, 16), (72, 10, 26), (110, 14, 34)][max(0, min(3, level))]
            d.point((x, y), fill=col + (255,))
    return img, d


def finish_icon(img, name):
    a = np.array(img)
    a[0, :, :3] = 0
    a[-1, :, :3] = 0
    a[:, 0, :3] = 0
    a[:, -1, :3] = 0
    img = Image.fromarray(a).resize((128, 128), Image.NEAREST)
    img.save(os.path.join(OUT_SKILL, name))


def blood_drop(d, cx, cy, s=1):
    pts = [(cx, cy - 6 * s), (cx + 4 * s, cy + 1 * s), (cx + 3 * s, cy + 5 * s), (cx, cy + 7 * s),
           (cx - 3 * s, cy + 5 * s), (cx - 4 * s, cy + 1 * s)]
    d.polygon(pts, fill=BLOOD)
    d.polygon([(cx, cy - 3 * s), (cx + 2 * s, cy + 1 * s), (cx, cy + 5 * s), (cx - 2 * s, cy + 1 * s)], fill=BLOOD_L)
    d.point([(cx - 1, cy + 1), (cx - 1, cy + 2)], fill=(255, 220, 220, 255))
    d.line([(cx - 4 * s, cy + 1 * s), (cx - 3 * s, cy + 5 * s), (cx, cy + 7 * s)], fill=BLOOD_D, width=1)


def icon_q():
    img, d = icon_base()
    for (sx, sy) in [(4, 5), (27, 5), (16, 27)]:
        d.ellipse([sx - 2, sy - 2, sx + 2, sy + 2], fill=(30, 26, 34, 255))
        d.point([(sx - 1, sy), (sx + 1, sy)], fill=EYE)
        steps = 12
        for i in range(steps):
            t = i / steps
            px = sx + (16 - sx) * t
            py = sy + (16 - sy) * t
            d.point([(int(px), int(py))], fill=BLOOD_L if i % 3 == 0 else BLOOD)
    blood_drop(d, 16, 16, 1)
    d.polygon([(13, 22), (15, 22), (14, 26)], fill=FANG)
    d.polygon([(17, 22), (19, 22), (18, 26)], fill=FANG)
    finish_icon(img, "vampir_kan_emme_icon.png")


def mini_bat(d, cx, cy, wings_up, col=(20, 10, 16, 255), eye=True):
    if wings_up:
        pts_l = [(cx - 1, cy), (cx - 4, cy - 3), (cx - 7, cy - 3), (cx - 6, cy - 1), (cx - 4, cy)]
        pts_r = [(cx + 1, cy), (cx + 4, cy - 3), (cx + 7, cy - 3), (cx + 6, cy - 1), (cx + 4, cy)]
    else:
        pts_l = [(cx - 1, cy), (cx - 4, cy + 1), (cx - 7, cy + 3), (cx - 5, cy + 1), (cx - 3, cy - 1)]
        pts_r = [(cx + 1, cy), (cx + 4, cy + 1), (cx + 7, cy + 3), (cx + 5, cy + 1), (cx + 3, cy - 1)]
    d.polygon(pts_l, fill=col)
    d.polygon(pts_r, fill=col)
    d.rectangle([cx - 1, cy - 1, cx + 1, cy + 2], fill=col)
    d.point([(cx - 1, cy - 2), (cx + 1, cy - 2)], fill=col)
    if eye:
        d.point([(cx - 1, cy - 1), (cx + 1, cy - 1)], fill=EYE)


def icon_e():
    img, d = icon_base()
    d.polygon([(16, 15), (9, 9), (2, 8), (3, 15), (6, 21), (8, 18), (11, 22), (13, 19), (16, 22)], fill=(24, 10, 20, 255))
    d.polygon([(16, 15), (23, 9), (30, 8), (29, 15), (26, 21), (24, 18), (21, 22), (19, 19), (16, 22)], fill=(24, 10, 20, 255))
    d.line([(16, 15), (9, 9), (3, 9)], fill=MEM_L, width=1)
    d.line([(16, 15), (23, 9), (29, 9)], fill=MEM_L, width=1)
    d.ellipse([12, 12, 20, 24], fill=(30, 12, 24, 255))
    d.polygon([(12, 14), (12, 8), (15, 12)], fill=(30, 12, 24, 255))
    d.polygon([(20, 14), (20, 8), (17, 12)], fill=(30, 12, 24, 255))
    d.rectangle([13, 15, 14, 16], fill=EYE)
    d.rectangle([18, 15, 19, 16], fill=EYE)
    d.point([(13, 15), (19, 15)], fill=EYE_H)
    d.polygon([(14, 19), (15, 19), (14, 22)], fill=FANG)
    d.polygon([(17, 19), (18, 19), (18, 22)], fill=FANG)
    for y in (26, 28):
        d.line([(6, y), (12, y)], fill=BLOOD_D, width=1)
        d.line([(20, y), (26, y)], fill=BLOOD_D, width=1)
    finish_icon(img, "vampir_yarasa_formu_icon.png")


def icon_r():
    img, d = icon_base()
    blood_drop(d, 16, 17, 1)
    ring = [(16, 4), (26, 9), (27, 22), (16, 28), (5, 22), (6, 9)]
    for i, (bx, by) in enumerate(ring):
        mini_bat(d, bx, by, i % 2 == 0)
    finish_icon(img, "vampir_kan_yarasalari_icon.png")


def icon_passive():
    img, d = icon_base()
    d.polygon([(8, 5), (14, 5), (12, 20), (10, 24)], fill=FANG)
    d.polygon([(18, 5), (24, 5), (23, 20), (21, 24)], fill=FANG)
    d.polygon([(9, 6), (11, 6), (11, 18)], fill=(200, 196, 186, 255))
    d.polygon([(19, 6), (21, 6), (22, 18)], fill=(200, 196, 186, 255))
    d.line([(10, 24), (10, 27)], fill=BLOOD, width=1)
    d.line([(21, 24), (21, 28)], fill=BLOOD, width=1)
    d.point([(10, 28), (21, 29)], fill=BLOOD_L)
    hx, hy = 16, 27
    d.polygon([(hx - 3, hy - 2), (hx - 1, hy - 3), (hx, hy - 2), (hx + 1, hy - 3), (hx + 3, hy - 2), (hx + 3, hy),
               (hx, hy + 3), (hx - 3, hy)], fill=BLOOD)
    finish_icon(img, "vampir_passive_icon.png")


def mini_bat_frame(phase):
    """R yeteneginin kucuk yarasasi: 16x16 sanat pikseli, ustten/onden simetrik gorunum (yone gore dondurmeye
    gerek kalmasin diye), 3 kare kanat cirpma dongusu (0 yukari, 1 orta, 2 asagi)."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    tip_y = [1, 6, 12][phase]
    mid_y = [4, 7, 10][phase]
    low_y = [9, 10, 12][phase]
    for sx in (-1, 1):
        def X(dx):
            return 8 + sx * dx
        pts = [(X(2), 8), (X(4), mid_y), (X(7), tip_y), (X(6), (tip_y + low_y) // 2 + 1), (X(4), low_y), (X(3), low_y - 1), (X(2), 11)]
        d.polygon(pts, fill=MEM_M)
        d.line([(X(2), 8), (X(4), mid_y), (X(7), tip_y)], fill=BONE, width=1)
        d.line([(X(7), tip_y), (X(6), (tip_y + low_y) // 2 + 1), (X(4), low_y)], fill=MEM_L, width=1)
    d.ellipse([6, 7, 9, 12], fill=FUR_M)
    d.point([(7, 9), (8, 9)], fill=FUR_L)
    d.rectangle([6, 4, 9, 7], fill=FUR_M)
    d.point([(6, 3), (9, 3)], fill=FUR_M)
    d.point([(7, 5), (8, 5)], fill=EYE)
    d.point([(7, 7)], fill=FANG)
    return outline(img)


def make_mini_bats():
    os.makedirs(OUT_DIR, exist_ok=True)
    for phase in range(3):
        mini_bat_frame(phase).save(os.path.join(OUT_DIR, f"mini_bat_{phase + 1}.png"))


def make_icons():
    os.makedirs(OUT_SKILL, exist_ok=True)
    icon_q()
    icon_e()
    icon_r()
    icon_passive()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", help="animasyon sayfalarinin (Idle.png, Walk.png ...) oldugu klasor; verilmezse sadece yarasa+ikonlar uretilir")
    args = ap.parse_args()
    if args.src:
        import_sheets(args.src)
    make_bat_frames()
    make_mini_bats()
    make_icons()
    print("tamam")
