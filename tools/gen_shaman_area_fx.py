#!/usr/bin/env python3
"""Shaman ALAN TOTEMI (mor, skill3 id 28) yetenek alani - MINIMAL pixel-art spritesheet'ler.

Kullanici istegi (2026-09-24): "Alan hasari veren mor totemin de daha minimalist bir alana sahip olmasini istiyorum skill
efektinin, bunu da pixel tarzda hazirla. bu efektleri yaptiktan sonrasinda sprite'a donustur performans kaybi olmasin diye."
Eski alan: shaders/totem_void_aura.gdshader (her karede tum ekran-karesi icin: dither girdap kollari + 16 run + iki kesikli
halka + kivilcimlar) + her tikte prosedurel _draw nabiz halkasi + dusmanlarda prosedurel PixelDraw "void" patlamasi.
Yeni (hepsi onceden pisirilmis kareler, oyunda TEK AnimatedSprite2D):
  * aura  ("loop", 12 kare / 6 fps): tek, keskin 1 pikselik mor cember (dista 1 px koyu kontur - cimende okunur),
    icinde duz ve cok soluk mor dolgu (kenara yakin bir kademe daha koyu - dama/dither YOK), cember uzerinde 6 kucuk
    ay-evresi runu; bir isik run'dan run'a sirayla gezer (yer degistirmez -> dongu dikissiz), birkac soluk ates bocegi.
  * pulse ("play", 7 kare / 16 fps, tek seferlik): her hasar tikinde totemin dibinden yayilan ince halka.
  * wisp  ("play", 7 kare / 14 fps, tek seferlik): alan hasari yiyen dusmanin ustunde kivrilarak yukselen kucuk mor ruh.
1 sanat pikseli = TEXEL (1.212) dunya birimi. Cember yaricapi 148 px = 179.4 birim ~ totem_area.gd totem_radius (180).
Cikti: assets/fx/shaman_area/{aura,pulse,wisp}_sheet.png + *_frames.tres
Kullanim: python tools/gen_shaman_area_fx.py [onizleme.png]
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "shaman_area")
RES = "res://assets/fx/shaman_area/"


def rgba(r, g, b, a=255):
    return (int(r), int(g), int(b), int(max(0, min(255, a))))


def put(im, x, y, col):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < im.size[0] and 0 <= y < im.size[1]:
        im.putpixel((x, y), col)


P0 = (40, 18, 64)
P1 = (94, 50, 158)
P2 = (150, 92, 224)
P3 = (204, 160, 255)
P4 = (244, 230, 255)


def a(col, alpha):
    return rgba(col[0], col[1], col[2], alpha * 255)


def lerp(c1, c2, t):
    return tuple(c1[i] + (c2[i] - c1[i]) * t for i in range(3))


# ------------------------------------------------------------------ AURA
R_RING = 148
AURA_N = 2 * R_RING + 8  # 304
AURA_FRAMES = 12
AURA_FPS = 6.0
RUNES = 6
# 5x5 ay-evresi / ruh isaretleri ('#' = piksel)
GLYPHS = [
    [".###.", "#....", "#....", "#....", ".###."],   # hilal
    [".###.", "#...#", "#.#.#", "#...#", ".###."],   # goz
    ["..#..", ".#.#.", "#...#", ".#.#.", "..#.."],   # elmas
    [".###.", "#####", "#####", "#####", ".###."],   # dolunay
    ["###..", "...#.", ".##.#", "#....", ".###."],   # sarmal
    ["..#..", "..#..", "#####", "..#..", "..#.."],   # yildiz
]
FILL_ALPHA = 0.10
BAND_ALPHA = 0.18
BAND_WIDTH = 8
MOTES = [(0.21, 0.35, 0.0), (0.55, 1.9, 0.33), (0.78, 3.6, 0.66), (0.40, 4.8, 0.17), (0.66, 0.9, 0.5), (0.30, 2.7, 0.83),
         (0.86, 5.6, 0.25), (0.48, 3.1, 0.58)]  # (yaricap orani, aci, faz)


def aura_frame(fi):
    n = AURA_N
    c = n / 2.0
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = im.load()
    rune_pos = []
    for k in range(RUNES):
        ang = -math.pi / 2 + k * 2 * math.pi / RUNES
        rune_pos.append((c + math.cos(ang) * R_RING, c + math.sin(ang) * R_RING))
    for y in range(n):
        for x in range(n):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c)
            if d > R_RING + 1.5:
                continue
            # runlerin arkasinda cember acik kalir (runler cemberi "keser")
            near_rune = any(abs(x + 0.5 - rx) <= 4.5 and abs(y + 0.5 - ry) <= 4.5 for (rx, ry) in rune_pos)
            if R_RING - 0.5 <= d < R_RING + 0.5:
                if not near_rune:
                    px[x, y] = a(P2, 0.9)
            elif R_RING + 0.5 <= d <= R_RING + 1.5:
                if not near_rune:
                    px[x, y] = a(P0, 0.5)
            elif R_RING - BAND_WIDTH <= d < R_RING - 0.5:
                px[x, y] = a(P1, BAND_ALPHA)
            else:
                px[x, y] = a(P1, FILL_ALPHA)
    # runler: sirayla gezen isik (her run sabit yerinde; parlaklik fazi 12 karede bir tur)
    for k, (rx, ry) in enumerate(rune_pos):
        ph = (fi / AURA_FRAMES - k / RUNES) % 1.0
        lit = max(0.0, math.cos(ph * 2 * math.pi)) ** 3  # kisa, yumusak parlama
        body = lerp(P2, P4, lit)
        g = GLYPHS[k % len(GLYPHS)]
        x0, y0 = int(round(rx)) - 2, int(round(ry)) - 2
        # 1 px koyu cerceve (okunurluk) - glifin 4-komsulugunda
        for gy in range(5):
            for gx in range(5):
                if g[gy][gx] != "#":
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = gx + dx, gy + dy
                    if not (0 <= nx < 5 and 0 <= ny < 5) or g[ny][nx] != "#":
                        if px[x0 + nx, y0 + ny][3] < 120:
                            px[x0 + nx, y0 + ny] = a(P0, 0.6)
        for gy in range(5):
            for gx in range(5):
                if g[gy][gx] == "#":
                    px[x0 + gx, y0 + gy] = a(body, 0.75 + 0.25 * lit)
        # parlarken run etrafinda cemberin iki yanina kisa isik
        if lit > 0.3:
            for s in (-1, 1):
                ang = math.atan2(ry - c, rx - c) + s * 6.5 / R_RING
                put(im, c + math.cos(ang) * R_RING, c + math.sin(ang) * R_RING, a(P3, 0.9 * lit))
    # soluk ates bocekleri: sabit yerlerinde yavasca yukselip soner
    for (rr, ang, ph0) in MOTES:
        ph = (fi / AURA_FRAMES + ph0) % 1.0
        mx = c + math.cos(ang) * rr * R_RING
        my = c + math.sin(ang) * rr * R_RING - ph * 6
        put(im, mx, my, a(P3, 0.8 * math.sin(ph * math.pi)))
    return im


# ------------------------------------------------------------------ PULSE (tik nabzi)
PULSE_N = 72
PULSE_FRAMES = 7
PULSE_FPS = 16.0


def pulse_frame(fi):
    n = PULSE_N
    c = n / 2.0
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    u = fi / (PULSE_FRAMES - 1)
    r = 6 + 27 * (1 - (1 - u) ** 2)
    fade = 1.0 - u
    for y in range(n):
        for x in range(n):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c)
            if r - 0.5 <= d < r + 0.5:
                im.putpixel((x, y), a(lerp(P2, P1, u), 0.95 * fade))
            elif r - 1.5 <= d < r - 0.5 and fi < 4:
                im.putpixel((x, y), a(P3, 0.6 * fade))
    # dort kisa isik cizgisi (capraz yonlerde, halkayla birlikte disari)
    for k in range(4):
        ang = math.pi / 4 + k * math.pi / 2
        for s in (0.8, 1.1):
            put(im, c + math.cos(ang) * r * s, c + math.sin(ang) * r * s, a(P3, 0.9 * fade))
    return im


# ------------------------------------------------------------------ WISP (dusman ustu ruh)
WISP_W, WISP_H = 24, 32
WISP_FRAMES = 7
WISP_FPS = 14.0


def wisp_frame(fi):
    im = Image.new("RGBA", (WISP_W, WISP_H), (0, 0, 0, 0))
    u = fi / (WISP_FRAMES - 1)
    cx, base = WISP_W / 2.0, WISP_H - 6
    # zeminde kisa halka (ilk kareler)
    if fi < 3:
        rr = 3 + fi * 2
        for k in range(16):
            ang = k * 2 * math.pi / 16
            put(im, cx + math.cos(ang) * rr, base + math.sin(ang) * rr * 0.45, a(P2, 0.7 * (1 - fi / 3)))
    # kivrilarak yukselen ruh: bas (parlak) + incelen kuyruk
    head_y = base - 4 - u * 18
    fade = 1.0 if u < 0.6 else (1 - u) / 0.4
    for j in range(6):
        yy = head_y + j * 1.6
        xx = cx + math.sin(u * 6 + j * 0.9) * (1.5 + j * 0.35)
        col = P4 if j == 0 else (P3 if j < 3 else P2)
        put(im, xx, yy, a(col, (0.95 - j * 0.12) * fade))
    hx = cx + math.sin(u * 6) * 1.5
    put(im, hx + 1, head_y, a(P3, 0.9 * fade))
    put(im, hx, head_y - 1, a(P3, 0.8 * fade))
    put(im, hx + 1, head_y - 1, a(P2, 0.7 * fade))
    return im


def sheet(frames, w, h):
    s = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (i * w, 0), f)
    return s


def main():
    os.makedirs(OUT, exist_ok=True)
    aura = [aura_frame(i) for i in range(AURA_FRAMES)]
    pulse = [pulse_frame(i) for i in range(PULSE_FRAMES)]
    wisp = [wisp_frame(i) for i in range(WISP_FRAMES)]
    sheet(aura, AURA_N, AURA_N).save(os.path.join(OUT, "aura_sheet.png"))
    sheet(pulse, PULSE_N, PULSE_N).save(os.path.join(OUT, "pulse_sheet.png"))
    sheet(wisp, WISP_W, WISP_H).save(os.path.join(OUT, "wisp_sheet.png"))
    write_sprite_frames(os.path.join(OUT, "aura_frames.tres"), RES + "aura_sheet.png", AURA_N, AURA_N,
                        [("loop", (0, 0), AURA_FRAMES, True, AURA_FPS)])
    write_sprite_frames(os.path.join(OUT, "pulse_frames.tres"), RES + "pulse_sheet.png", PULSE_N, PULSE_N,
                        [("play", (0, 0), PULSE_FRAMES, False, PULSE_FPS)])
    write_sprite_frames(os.path.join(OUT, "wisp_frames.tres"), RES + "wisp_sheet.png", WISP_W, WISP_H,
                        [("play", (0, 0), WISP_FRAMES, False, WISP_FPS)])
    if len(sys.argv) > 1:
        # onizleme: cimen zemin, aura karesi 0 ve 3 (x2) + nabiz/ruh kareleri (x6)
        bg = (58, 96, 48, 255)
        prev = Image.new("RGBA", (AURA_N * 4 + 30, AURA_N * 2 + 40 + PULSE_N * 2 + WISP_H * 5), bg)
        for j, fi in enumerate((0, 3)):
            prev.alpha_composite(aura[fi].resize((AURA_N * 2, AURA_N * 2), Image.NEAREST), (10 + j * (AURA_N * 2 + 10), 10))
        y0 = AURA_N * 2 + 20
        for i, f in enumerate(pulse):
            prev.alpha_composite(f.resize((PULSE_N * 2, PULSE_N * 2), Image.NEAREST), (10 + i * (PULSE_N * 2 + 4), y0))
        for i, f in enumerate(wisp):
            prev.alpha_composite(f.resize((WISP_W * 5, WISP_H * 5), Image.NEAREST), (10 + i * (WISP_W * 5 + 4), y0 + PULSE_N * 2 + 4))
        prev.save(sys.argv[1])


if __name__ == "__main__":
    main()
