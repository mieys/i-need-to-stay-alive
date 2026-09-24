#!/usr/bin/env python3
""""Konvoyu Koru" gorevi arabasi (scripts/mission_van.gd) icin pixel-art spritesheet.

Kullanici istegi (2026-09-24): "Konvoy arabasinin goruntusunu sifirdan pixel art olarak tasarla 4 direction ve
hareket edebilen bir konvoy arabasi olmali" - eskiden araba her karede draw_rect/draw_circle ile cizilen kahverengi
bir kutu + iki siyah daireydi.

Tasarim: brandali (ustu kubbeli kanvas ortulu) ahsap erzak arabasi, atsiz - oyuncular itiyor, arkasinda itme kolu var,
on kosesinde kirmizi bir sancak. 4 yon (sag/sol yan gorunus, asagi = on gorunus, yukari = arka gorunus), her yon 4
karelik "yuruyus" dongusu: yan gorunuste tekerlek parmaklari 22.5 derece doner (4 kare = 90 derece, 4 parmakli
tekerlegin simetrisiyle kusursuz dongu), on/arka gorunuste tekerlek sirti izleri kayar; govde 1 texel sallanir,
sancak dalgalanir. Duruyorken oyun ilk karede durdurur (bkz. mission_van.gd).

Piksel yogunlugu karakterlerle ayni (48x48 dili, 1 texel detay, 1 px koyu kontur - bkz. hafiza "Pixel density 48x48",
"Pixel-style FX"); oyun ici olcek PixelDraw.TEXEL (1.212). Zemin temas cizgisi karenin GROUND_Y satiri.

Kullanim (repo kokunden):  python tools/gen_convoy_wagon_sprite.py
Cikti:
  assets/fx/mission_van/wagon_sheet.png   (4 kare x 4 satir, her kare 48x44: satirlar right, left, down, up)
  assets/fx/mission_van/wagon_frames.tres (SpriteFrames: "right"/"left"/"down"/"up", 4 kare dongu)
Yeni PNG icin Godot'ta bir kez `--headless --import` gerekir.
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "fx", "mission_van")

W, H = 48, 44
FRAMES = 4
GROUND_Y = 40  ## tekerleklerin yere degdigi satir (mission_van.gd SHEET_GROUND_Y ile ayni)

OUTLINE = (22, 15, 11, 255)
WOOD_D = (84, 50, 27, 255)
WOOD_M = (124, 79, 42, 255)
WOOD_L = (163, 110, 61, 255)
WOOD_HL = (192, 140, 86, 255)
CANVAS_D = (158, 136, 98, 255)
CANVAS_M = (206, 188, 146, 255)
CANVAS_L = (236, 224, 188, 255)
HOOP = (132, 104, 70, 255)
IRON_D = (58, 60, 68, 255)
IRON_L = (116, 120, 132, 255)
INTERIOR = (48, 32, 22, 255)
CRATE = (150, 104, 56, 255)
CRATE_D = (102, 68, 36, 255)
FLAG = (178, 48, 42, 255)
FLAG_D = (128, 30, 30, 255)
GOLD = (236, 190, 76, 255)
SHADOW_EDGE = (0, 0, 0, 60)
SHADOW_CORE = (0, 0, 0, 90)


class Canvas:
    def __init__(self):
        self.im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.px = self.im.load()

    def put(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < H:
            self.px[x, y] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / max(n, 1)
            self.put(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c)


def outline(im):
    """Seffaf pikselleri, dolu bir 4-komsusu varsa koyu kontur yapar (tools/gen_tree_assets.py ile ayni teknik)."""
    px = im.load()
    out = im.copy()
    op = out.load()
    for y in range(H):
        for x in range(W):
            if px[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and px[nx, ny][3] > 0:
                    op[x, y] = OUTLINE
                    break
    return out


def ground_shadow(cx, half_w, half_h=2):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()
    for dy in range(-half_h, half_h + 1):
        for dx in range(-half_w, half_w + 1):
            if (dx / (half_w + 0.5)) ** 2 + (dy / (half_h + 0.5)) ** 2 <= 1.0:
                core = abs(dx) <= half_w * 0.6 and abs(dy) <= max(half_h - 1, 0)
                x, y = cx + dx, GROUND_Y + dy
                if 0 <= x < W and 0 <= y < H:
                    px[x, y] = SHADOW_CORE if core else SHADOW_EDGE
    return im


def compose(shadow, sprite):
    base = shadow.copy()
    base.alpha_composite(outline(sprite))
    return base


# ------------------------------------------------------------------------------------------------ yan gorunus (sag)
def side_wheel(cv, cx, cy, r, angle):
    for y in range(cy - r - 1, cy + r + 2):
        for x in range(cx - r - 1, cx + r + 2):
            d = math.hypot(x - cx, y - cy)
            if d <= r + 0.4:
                if d >= r - 1.1:
                    cv.put(x, y, IRON_D if d >= r - 0.4 else WOOD_D)  ## demir lastik + ahsap jant
                elif d >= r - 2.0:
                    cv.put(x, y, WOOD_M)
    for k in range(4):  ## 4 parmak
        a = angle + k * math.pi / 2.0
        for s in range(1, r - 1):
            cv.put(cx + math.cos(a) * s, cy + math.sin(a) * s, WOOD_L if k % 2 == 0 else WOOD_M)
    cv.rect(cx - 1, cy - 1, cx, cy, IRON_L)  ## gobek
    cv.put(cx - 1, cy - 1, (170, 174, 184, 255))


def flag(cv, px_x, top, frame, facing_left=False):
    """Direk (px_x) tepesinde dalgalanan kirmizi sancak; frame dalgayi kaydirir."""
    cv.line(px_x, top, px_x, top + 16, WOOD_D)
    cv.put(px_x, top - 1, GOLD)
    for col in range(6):
        wave = int(round(math.sin((col * 0.9) - frame * math.pi / 2.0) * 0.8))
        x = px_x - 1 - col if facing_left else px_x + 1 + col
        h = 4 - (col // 3)
        for row in range(h):
            c = FLAG_D if row == h - 1 else FLAG
            if col == 2 and row == 1:
                c = GOLD  ## sancak arması
            cv.put(x, top + 1 + row + wave, c)


def side_frame(frame):
    cv = Canvas()
    bob = 1 if frame in (1, 3) else 0
    wheel_r = 7
    wy = GROUND_Y - wheel_r
    angle = frame * (math.pi / 8.0)  ## 22.5 derece/kare
    # arka itme kolu (sol) - govdenin arkasinda, bel hizasinda
    cv.line(1, 22 + bob, 6, 25 + bob, WOOD_M)
    cv.rect(0, 21 + bob, 1, 22 + bob, WOOD_L)
    # kasa (ahsap yatak)
    top = 22 + bob
    cv.rect(5, top, 42, top + 8, WOOD_M)
    for x in range(5, 43):
        cv.put(x, top, WOOD_L)  ## ust kenar isigi
        cv.put(x, top + 4, WOOD_D)  ## tahta araligi
        cv.put(x, top + 8, WOOD_D)
    for x in (5, 23, 42):
        cv.line(x, top, x, top + 8, WOOD_D)  ## dikmeler
    for x in (6, 24):
        cv.line(x, top + 1, x, top + 7, WOOD_HL)
    for (x0, x1) in ((5, 7), (40, 42)):
        cv.rect(x0, top + 2, x1, top + 3, IRON_D)  ## kose demirleri
        cv.put(x0 + 1, top + 2, IRON_L)
    # kanvas kubbe
    cx, base_y = 23.5, top - 1
    half_w, dome_h = 17.0, 14.0
    for x in range(6, 42):
        u = (x - cx) / half_w
        if abs(u) > 1.0:
            continue
        h = int(round(dome_h * math.sqrt(max(0.0, 1.0 - u * u)) ** 0.8))
        for y in range(int(base_y) - h, int(base_y) + 1):
            depth = (y - (base_y - h)) / max(h, 1)
            c = CANVAS_L if depth < 0.22 else (CANVAS_M if depth < 0.7 else CANVAS_D)
            cv.put(x, y, c)
    for hx in (13, 23, 33):  ## cemberler
        u = (hx - cx) / half_w
        h = int(round(dome_h * math.sqrt(max(0.0, 1.0 - u * u)) ** 0.8))
        cv.line(hx, base_y - h + 1, hx, base_y, HOOP)
    for x in range(8, 40, 3):  ## kanvas alt kenari baglari
        cv.put(x, base_y, CANVAS_D)
    # on sancak diregi
    flag(cv, 40, 4 + bob, frame)
    # tekerlekler (govdenin onunde)
    side_wheel(cv, 12, wy, wheel_r, angle)
    side_wheel(cv, 35, wy, wheel_r, angle + 0.3)
    return compose(ground_shadow(24, 20), cv.im)


# ------------------------------------------------------------------------------------------------ on / arka
def end_wheel(cv, x0, frame, bob):
    """On/arka gorunuste yandan gorunen tekerlek: dar dikey demir lastik, sirt izleri asagi kayar."""
    top, bottom = GROUND_Y - 13, GROUND_Y
    for y in range(top, bottom + 1):
        if y in (top, bottom):
            cv.rect(x0 + 1, y, x0 + 2, y, IRON_D)  ## yuvarlak uclar
            continue
        cv.rect(x0, y, x0 + 3, y, WOOD_D)
        cv.put(x0, y, IRON_D)
        cv.put(x0 + 3, y, IRON_D)
    for k in range(4):
        y = top + 1 + ((k * 4 + frame) % 12)
        cv.rect(x0 + 1, y, x0 + 2, y, IRON_L)
    cv.rect(x0 + 1, GROUND_Y - 8 + bob, x0 + 2, GROUND_Y - 6 + bob, IRON_L)  ## dingil ucu


def dome_front(cv, cx, base_y, half_w, dome_h, inner, frame_bob):
    """Kanvasin on/arka yuzu: kalin kanvas halka + icinde `inner` renkli acik ya da buzgulu kapali yuz."""
    for y in range(base_y - dome_h, base_y + 1):
        for x in range(int(cx - half_w) - 1, int(cx + half_w) + 2):
            u = (x - cx) / half_w
            v = (base_y - y) / dome_h
            if u * u + v * v > 1.0:
                continue
            rim = u * u + v * v > 0.58
            if rim:
                c = CANVAS_L if v > 0.75 else (CANVAS_M if v > 0.3 else CANVAS_D)
            else:
                c = inner
            cv.put(x, y, c)


def front_frame(frame):
    cv = Canvas()
    bob = 1 if frame in (1, 3) else 0
    top = 23 + bob
    cx = 23.5
    # kanvas kubbe (on acik: karanlik ic + sandik)
    dome_front(cv, cx, top, 13.0, 17, INTERIOR, bob)
    cv.rect(19, top - 5, 27, top - 1, CRATE)  ## icerideki sandik
    cv.line(19, top - 5, 27, top - 5, WOOD_HL)
    cv.line(19, top - 3, 27, top - 3, CRATE_D)
    cv.line(23, top - 5, 23, top - 1, CRATE_D)
    # kasa on yuzu
    cv.rect(10, top, 37, top + 9, WOOD_M)
    for x in range(10, 38):
        cv.put(x, top, WOOD_L)
        cv.put(x, top + 4, WOOD_D)
        cv.put(x, top + 9, WOOD_D)
    for x in (10, 37):
        cv.line(x, top, x, top + 9, WOOD_D)
    cv.rect(11, top + 1, 12, top + 3, IRON_D)
    cv.rect(35, top + 1, 36, top + 3, IRON_D)
    cv.rect(21, top + 5, 26, top + 7, WOOD_L)  ## on tahta levha
    cv.put(23, top + 6, GOLD)
    cv.put(24, top + 6, GOLD)
    # oka (araba kolu) izleyiciye dogru
    cv.rect(23, top + 10, 24, GROUND_Y - 1, WOOD_L)
    cv.put(23, GROUND_Y - 1, WOOD_D)
    cv.put(24, GROUND_Y - 1, WOOD_D)
    # sancak sag on kosede
    flag(cv, 36, 3 + bob, frame)
    # tekerlekler yanlarda
    end_wheel(cv, 5, frame, bob)
    end_wheel(cv, 39, frame, bob)
    return compose(ground_shadow(24, 19), cv.im)


def back_frame(frame):
    cv = Canvas()
    bob = 1 if frame in (1, 3) else 0
    top = 23 + bob
    cx = 23.5
    # sancak arka gorunuste govdenin ARKASINDA (once cizilir, kubbe ustune biner)
    flag(cv, 11, 3 + bob, frame, facing_left=True)
    # kanvas kubbe (arka kapali: buzgulu kanvas + ortada kucuk karanlik agiz)
    dome_front(cv, cx, top, 13.0, 17, CANVAS_M, bob)
    for k, x in enumerate(range(15, 33, 3)):  ## buzgu cizgileri merkeze toplanir
        cv.line(x, top - 1, cx + (x - cx) * 0.25, top - 9, CANVAS_D)
    cv.rect(22, top - 10, 25, top - 8, INTERIOR)
    cv.line(21, top - 11, 26, top - 11, HOOP)  ## buzgu ipi
    # arka kapak (tailgate) + demir mentese
    cv.rect(10, top, 37, top + 9, WOOD_M)
    for x in range(10, 38):
        cv.put(x, top, WOOD_L)
        cv.put(x, top + 3, WOOD_D)
        cv.put(x, top + 6, WOOD_D)
        cv.put(x, top + 9, WOOD_D)
    for x in (10, 37):
        cv.line(x, top, x, top + 9, WOOD_D)
    for x in (14, 33):
        cv.rect(x - 1, top + 1, x + 1, top + 8, IRON_D)
        cv.line(x, top + 1, x, top + 8, IRON_L)
    # itme kolu (oyuncularin tuttugu yer) - kasanin altinda yatay
    cv.rect(13, top + 11, 34, top + 12, WOOD_L)
    cv.line(13, top + 12, 34, top + 12, WOOD_D)
    cv.line(15, top + 9, 15, top + 11, WOOD_D)
    cv.line(32, top + 9, 32, top + 11, WOOD_D)
    end_wheel(cv, 5, frame, bob)
    end_wheel(cv, 39, frame, bob)
    return compose(ground_shadow(24, 19), cv.im)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    rows = []
    rows.append([side_frame(f) for f in range(FRAMES)])  # right
    rows.append([im.transpose(Image.FLIP_LEFT_RIGHT) for im in rows[0]])  # left
    rows.append([front_frame(f) for f in range(FRAMES)])  # down (izleyiciye dogru)
    rows.append([back_frame(f) for f in range(FRAMES)])  # up (izleyiciden uzaga)
    sheet = Image.new("RGBA", (W * FRAMES, H * len(rows)), (0, 0, 0, 0))
    for r, frames in enumerate(rows):
        for f, im in enumerate(frames):
            sheet.paste(im, (f * W, r * H))
    path = os.path.join(OUT_DIR, "wagon_sheet.png")
    sheet.save(path)
    print("wrote", path, sheet.size)
    write_sprite_frames(
        os.path.join(OUT_DIR, "wagon_frames.tres"),
        "res://assets/fx/mission_van/wagon_sheet.png",
        W, H,
        [(name, (0, row), FRAMES, True, 8.0) for row, name in enumerate(("right", "left", "down", "up"))],
    )
    # onizleme (4x buyutulmus) - repo'ya girmez, sadece gozle kontrol icin
    preview_dir = os.environ.get("WAGON_PREVIEW_DIR")
    if preview_dir:
        big = sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST)
        bg = Image.new("RGBA", big.size, (96, 128, 72, 255))
        bg.alpha_composite(big)
        bg.save(os.path.join(preview_dir, "wagon_preview.png"))


if __name__ == "__main__":
    main()
