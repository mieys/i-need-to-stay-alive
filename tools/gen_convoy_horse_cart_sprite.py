#!/usr/bin/env python3
""""Konvoyu Koru" gorevi arabasi (scripts/mission_van.gd) icin AT + ARABA spritesheet'i.

Kullanici istegi (2026-11-13): "konvoy gorevindeki konvoy suanda ai. onu oyunumdaki at arabasi ve at assetiyle
degistirmeni istiyorum calisma mantigi ayni olacak ama goruntusu degisecek. seyyar saticidakine benzer denebilir".
Eski brandali arabayi (tools/gen_convoy_wagon_sprite.py ile cizilmisti) bu sayfa degistirir.

Kaynak sanat (proje kokunun YANINDAKI "Harita icerikleri" klasoru, seyyar satici ile AYNI parcalar - bkz.
harita/Seyyar satici.tmx):
  - araba: "seyyar satici/Tiled_files/Objects.png" 16 px karolar, sutun 0-4 x satir 32-35 (yesil brandali araba,
    oklar sola bakar). Satici sahnesindeki katman sirasi aynen: govde (sutun 1-4) -> AT -> on parca (sutun 0 tum
    satirlar + sutun 1 satir 34-35; oklar + on tekerlek atin USTUNDE).
  - at: "hayvanlar/Tiled/Horse_with_shadow.png" 64x64 kareler; satir 3 = sola yuruyus (6 kare), satir 7 = sola bekleme
    (4 kare). At karesi arabaya gore satici sahnesindeki gibi (-32, +16) px.
Saga bakis oyunda flip_h ile (kaynakta yalniz yan gorunus araba var; yukari/asagi rotada son yatay yon korunur).

Kullanim (repo kokunden):  python tools/gen_convoy_horse_cart_sprite.py
Cikti:
  assets/fx/mission_van/horse_cart_sheet.png   (W x H kareler: satir 0 = "walk" 6 kare, satir 1 = "idle" 4 kare; sola bakar)
  assets/fx/mission_van/horse_cart_frames.tres (SpriteFrames "walk" / "idle")
Yeni PNG icin Godot'ta bir kez `--headless --import` gerekir.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(os.path.dirname(ROOT), "Harita içerikleri")
OUT_DIR = os.path.join(ROOT, "assets", "fx", "mission_van")

W, H = 96, 58
CART_OFF = (22, -6)  ## arabanin 80x64 karo blogunun kare icindeki sol-ust kosesi
HORSE_OFF = (CART_OFF[0] - 32, CART_OFF[1] + 16)  ## satici sahnesi: at karesi arabaya gore (-32, +16)
WALK_ROW, WALK_FRAMES = 3, 6
IDLE_ROW, IDLE_FRAMES = 7, 4


def main():
    objects = Image.open(os.path.join(ART, "seyyar satıcı", "Tiled_files", "Objects.png")).convert("RGBA")
    horse = Image.open(os.path.join(ART, "hayvanlar", "Tiled", "Horse_with_shadow.png")).convert("RGBA")
    cart = _remove_wares(_remove_sack(objects.crop((0, 32 * 16, 5 * 16, 36 * 16))))
    body = cart.copy()
    body.paste((0, 0, 0, 0), (0, 0, 16, 64))  ## sutun 0 govdede yok (on parca)
    front = Image.new("RGBA", cart.size, (0, 0, 0, 0))
    front.paste(cart.crop((0, 0, 16, 64)), (0, 0))
    front.paste(cart.crop((16, 32, 32, 64)), (16, 32))

    sheet = Image.new("RGBA", (W * WALK_FRAMES, H * 2), (0, 0, 0, 0))
    for row, (src_row, count) in enumerate(((WALK_ROW, WALK_FRAMES), (IDLE_ROW, IDLE_FRAMES))):
        for i in range(count):
            frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            _paste(frame, body, CART_OFF)
            horse_frame = horse.crop((i * 64, src_row * 64, i * 64 + 64, src_row * 64 + 64))
            _paste(frame, horse_frame, HORSE_OFF)
            horse_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            _paste(horse_layer, horse_frame, HORSE_OFF)
            _harness(frame, horse_layer.getchannel("A"))
            _paste(frame, front, CART_OFF)
            sheet.paste(frame, (i * W, row * H))
    os.makedirs(OUT_DIR, exist_ok=True)
    sheet.save(os.path.join(OUT_DIR, "horse_cart_sheet.png"))
    write_sprite_frames(
        os.path.join(OUT_DIR, "horse_cart_frames.tres"),
        "res://assets/fx/mission_van/horse_cart_sheet.png",
        W, H,
        [("walk", (0, 0), WALK_FRAMES, True, 8.0), ("idle", (0, 1), IDLE_FRAMES, True, 2.5)],
    )
    print("yazildi:", OUT_DIR)


## Kullanici (2026-11-13): "yerdeki poseti kaldirman gerek" - satici arabasinin karosunda arka tekerlegin onunde yerde bir cuval var
## (araba ile birlikte kayiyordu). Cuval pikselleri (renkleriyle, kutu icinde) silinir; arkasinda kalan arka tekerlek parcasi tekerlegin
## gorunen sag yarisinin aynasindan (merkez x 61.5) doldurulur, tekerlegin solunda kalan yer arabanin alt kirisi / golge seridi / bos olur.
SACK_BOX = (46, 48, 61, 63)  ## x0, y0, x1, y1 (araba karo blogu yerel px, dahil degil)
SACK_COLORS = {
    (49, 37, 34), (171, 156, 117), (84, 69, 65), (128, 111, 93), (142, 125, 101),
    (72, 60, 56), (64, 54, 50), (103, 89, 78), (88, 74, 67),
}
SHADOW = (58, 47, 57, 89)
WHEEL_MIRROR_SUM = 123  ## x' = 123 - x (hub sutunlari 61-62)
WHEEL_LEFT_X = 53


def _remove_sack(cart):
    src = cart.copy()
    out = cart.copy()
    x0, y0, x1, y1 = SACK_BOX
    for y in range(y0, y1):
        for x in range(x0, x1):
            p = src.getpixel((x, y))
            sack = p[3] > 0 and p[:3] in SACK_COLORS
            sack_shadow = p == SHADOW and y >= 53
            if not (sack or sack_shadow):
                continue
            mx = WHEEL_MIRROR_SUM - x
            m = src.getpixel((mx, y)) if x >= WHEEL_LEFT_X and mx < cart.width else (0, 0, 0, 0)
            if m[3] > 0 and m[:3] not in SACK_COLORS:
                out.putpixel((x, y), m)
            elif y == 49:
                out.putpixel((x, y), (52, 33, 31, 255))  ## arabanin alt kirisi
            elif 50 <= y <= 52:
                out.putpixel((x, y), SHADOW)  ## araba altindaki golge seridi
            else:
                out.putpixel((x, y), (0, 0, 0, 0))
    return out


## Kullanici (2026-11-13): "iksir siseleri ve raf falan olmasin" - satici arabasinin ortasindaki tezgah (siseler + brandaya asili
## cuvallar/fener) silinir: brandanin altinda bos arabanin karanlik ici (dikey tahtalar), altinda tezgah yerine arabanin yan duvari
## (karonun tezgah onundeki dikey cita deseni yukari uzatilir). Yanlardaki sandiklar (yuk) kalir. Koordinatlar araba karo blogu yerel px.
WOOD = {
    "a": (38, 47, 32, 255), "b": (59, 72, 45, 255), "c": (70, 82, 51, 255),  ## branda kenari
    "h": (65, 45, 42, 255), "i": (83, 57, 50, 255), "r": (73, 51, 45, 255), "e": (56, 44, 40, 255),  ## karanlik ic
    "n": (52, 33, 31, 255), "z": (141, 95, 69, 255), "P": (123, 81, 63, 255), "y": (157, 109, 71, 255),  ## yan duvar
}
WARE_COLORS = {
    (84, 69, 65), (142, 125, 101), (171, 156, 117), (128, 111, 93), (72, 60, 56), (64, 54, 50), (103, 89, 78), (88, 74, 67),
    (33, 62, 42), (55, 54, 84), (84, 191, 78), (45, 36, 39), (128, 95, 99), (112, 173, 225), (61, 125, 70), (64, 144, 66),
    (157, 107, 110), (103, 132, 182), (62, 40, 35), (173, 111, 40), (87, 67, 72), (185, 134, 41), (111, 84, 89), (78, 61, 65),
    (91, 107, 152), (77, 173, 72), (132, 80, 41), (112, 65, 39), (56, 110, 69), (68, 54, 58), (89, 53, 40), (76, 83, 119),
    (57, 40, 38), (56, 44, 40),
}
INTERIOR_X = (30, 52)  ## brandanin altinda tamamen yeniden boyanan ic (asili cuval/fener + sise boyunlari)
WALL_X = (27, 58)  ## tezgahin yerini alan yan duvar
WARE_Y = (29, 45)  ## branda ustundeki kanca (26-28) yukarida elle duzeltilir


def _interior(x, y):
    if y == 29:
        return WOOD["a"]
    if y == 30:
        return WOOD["h"]
    return WOOD[("r", "h", "i")[(x - 37) % 3]] if y < 35 else WOOD["e"]


def _wall(x, y):
    if y == 36:
        return WOOD["n"]
    if y == 37:
        return WOOD["y"]
    return WOOD["P"] if (x - 27) % 3 == 0 else WOOD["z"]


def _remove_wares(cart):
    out = cart.copy()
    ## Brandaya asili fenerin kancasi (branda ustu).
    for x, y, k in ((33, 26, "c"), (32, 27, "c"), (33, 27, "c"), (34, 27, "c"), (32, 28, "b"), (33, 28, "b"), (34, 28, "b")):
        out.putpixel((x, y), WOOD[k])
    for y in range(WARE_Y[0], WARE_Y[1]):
        for x in range(cart.width):
            p = cart.getpixel((x, y))
            if 29 <= y <= 35 and INTERIOR_X[0] <= x < INTERIOR_X[1]:
                out.putpixel((x, y), _interior(x, y))
            elif 36 <= y <= 44 and WALL_X[0] <= x < WALL_X[1]:
                out.putpixel((x, y), _wall(x, y))
            elif p[3] > 0 and p[:3] in WARE_COLORS and 24 <= x <= 60:
                ## Kutularin disina tasan sise/esya pikselleri: brandanin altinda ic, tezgah satirlarinda duvar.
                out.putpixel((x, y), _interior(x, y) if y <= 35 else _wall(x, y))
    return out


## "ata ip bagli olsun": at arabaya koşulu gorunsun - boynuna gogus kayisi (tasma) + kayistan ust oka (sirt kayisi) ve alt oka (cekme ipi).
## Her karede atin kendi boyun piksellerine gore (yuruyuste bas/govde iner-kalkar). Kare koordinatlari (sola bakan sayfa).
COLLAR_X = (14, 15)
UPPER_SHAFT_TIP = (22, 22)
LOWER_SHAFT_TIP = (22, 34)
ROPE_LIGHT = (171, 128, 74, 255)
ROPE_MID = (123, 81, 63, 255)
ROPE_DARK = (52, 33, 31, 255)


def _harness(frame, horse_mask):
    cols = {}
    for x in COLLAR_X:
        ys = [y for y in range(frame.height) if horse_mask.getpixel((x, y)) == 255]
        if not ys:
            return
        cols[x] = (min(ys) + 1, min(min(ys) + 11, max(ys) - 2))
    for x, color in zip(COLLAR_X, (ROPE_LIGHT, ROPE_MID)):
        top, bot = cols[x]
        for y in range(top, bot + 1):
            if horse_mask.getpixel((x, y)) == 255:
                frame.putpixel((x, y), color)
        frame.putpixel((x, top - 1), ROPE_DARK)
        frame.putpixel((x, bot + 1), ROPE_DARK)
    top, bot = cols[COLLAR_X[1]]
    _rope(frame, (COLLAR_X[1] + 1, top + 1), UPPER_SHAFT_TIP)
    _rope(frame, (COLLAR_X[1] + 1, (top + bot) // 2 + 1), LOWER_SHAFT_TIP)


def _rope(frame, a, b):
    """1 px ip (acik) + altinda 1 px koyu golge - Bresenham."""
    (x0, y0), (x1, y1) = a, b
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        frame.putpixel((x0, y0), ROPE_LIGHT)
        if y0 + 1 < frame.height:
            frame.putpixel((x0, y0 + 1), ROPE_DARK)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def _paste(dst, src, off):
    """alpha_composite negatif ofseti kabul etmez - kaynagi kirpip yapistir."""
    sx, sy = max(0, -off[0]), max(0, -off[1])
    dx, dy = max(0, off[0]), max(0, off[1])
    w = min(src.width - sx, dst.width - dx)
    h = min(src.height - sy, dst.height - dy)
    if w > 0 and h > 0:
        dst.alpha_composite(src.crop((sx, sy, sx + w, sy + h)), (dx, dy))


if __name__ == "__main__":
    main()
