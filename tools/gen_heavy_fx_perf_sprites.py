#!/usr/bin/env python3
"""Kullanici isteği (2026-09-24, kalkan/ari/sarmasik/ruhani donusumunun devami): "hepsini
basla" - en agir 3 PROSEDUREL efekti (fx_matthew_fox_shield.gd, fx_talon_form.gd,
fx_buyucu_tornado.gd) PNG'ye pisirir. Bunlar HER KAREDE, SURDURULEBILIR SURE boyunca (kalkan
aktif oldugu sure / 15sn form / 15sn x3 hortum) ~1000-3600+ draw_rect() cagrisiyla ciziyordu -
bkz. bu oturumdaki performans denetimi. Yontem tools/gen_perf_sprite_fx.py + gen_spirit_
perf_sprites.py ile AYNI ("STEADY-STATE donen/turbulan kismi kisa, SEAMLESS DONGU yapan bir
PNG serit olarak pisir; tek seferlik patlama/kapanis AYRI kisa bir flipbook olarak pisir; ucuz
tekil parcaciklar PROSEDUREL kalabilir - ama bu 3 efektte oyle ayri, ucuz bir kisim yok, o
yuzden HEPSI pisirildi").

OLCEK NOTU (bkz. gen_perf_sprite_fx.py'deki AYNI not, BURADA DA GECERLI): bu 3 efektin
radius/pos sabitleri (RADIUS=44, FUNNEL_H=84 vb.) ZATEN world biriminde - pixel_draw_py.py'nin
px/ring/disc_dither'i "n" parametresini DOGRUDAN raster piksel olarak kullanir (TEXEL=1.0
kabul), o yuzden PNG'ler "1 raster piksel = 1 WORLD birimi" olarak cikar ve oyun ici node'lar
BASKA bir olcek çarpanı UYGULAMAZ (sadece degisken yaricap/boyut varsa oran uygulanir).

Cikti:
  assets/fx/matthew_fox_shield/loop_sheet.png   (steady-state donen kalkan, seamless loop)
  assets/fx/matthew_fox_shield/pop_sheet.png    (patlama, tek seferlik)
  assets/fx/talon_form/loop_sheet.png           (alev/parilti govdesi, seamless loop)
  assets/fx/talon_form/intro_sheet.png          (donusum soku, tek seferlik)
  assets/fx/buyucu_tornado/loop_sheet.png       (huni govdesi, seamless loop)

Yeni PNG'ler icin Godot'ta bir kez `--headless --import` gerekir.
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel_draw_py import blend_px, col, disc_dither, line, new_canvas, px, ring  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def save(im, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print("wrote", path, im.size)


def save_sheet(frames, path):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0), f)
    save(sheet, path)
    return w, h


def rect(im, pos, w, h, rgba):
    """pixel_draw.gd rect(): pos merkezli w x h dikdortgen (px() ile AYNI n=1 raster-birim kurali)."""
    x, y = pos
    x0 = int(round(x - w / 2.0))
    y0 = int(round(y - h / 2.0))
    for iy in range(int(h)):
        for ix in range(int(w)):
            blend_px(im, (x0 + ix, y0 + iy), rgba)


def fire_color(t):
    stops = [
        (1.0, 0.96, 0.7), (1.0, 0.78, 0.22), (1.0, 0.5, 0.1), (0.9, 0.2, 0.06), (0.45, 0.08, 0.06),
    ]
    t = max(0.0, min(1.0, t)) * (len(stops) - 1)
    i = min(int(t), len(stops) - 2)
    f = t - i
    a, b = stops[i], stops[i + 1]
    return col(a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, 1.0)


def hash01(seed):
    x = (seed * 374761393 + 668265263) & 0xFFFFFFFF
    x = (x ^ (x >> 13)) & 0xFFFFFFFF
    x = (x * 1274126177) & 0xFFFFFFFF
    x = (x ^ (x >> 16)) & 0xFFFFFFFF
    return (x & 0xFFFF) / 65535.0


# =====================================================================================================
# 1) BUYUCU KIZ - HORTUM (fx_buyucu_tornado.gd) - _spin += delta*6.0, bir cok alt terim _spin'in
#    TAM SAYIYA yakin olmayan katlari (1.4x, 2.6x, 3.6x vb.) - bkz. gen_spirit_perf_sprites.py'deki
#    AYNI kabul (ADC alevi de 9x/11x gibi ortak-olmayan katlar kullaniyordu): DOMINANT terimin
#    (_spin'in kendisi, katsayi 1.0) TAM bir 2*pi donusunu tek dongu say, ikincil terimlerdeki
#    (dust ring 1.4x, debris 2.6x/3.6x) kucuk faz sicramasi kabul edilebilir - gorsel olarak zaten
#    cok sayida bagimsiz donen katman var, tek bir dikisin farkina varilmiyor.
# =====================================================================================================
TORNADO_SPIN_RATE = 6.0
TORNADO_LOOP_PERIOD = 2.0 * math.pi / TORNADO_SPIN_RATE
TORNADO_FRAMES = 36

T_FUNNEL_H = 84.0
T_R_BOTTOM = 5.0
T_R_TOP = 27.0
T_BASE_Y = 12.0
T_C_DARK = col(0.26, 0.34, 0.62)
T_C_MID = col(0.56, 0.75, 0.96)
T_C_LIGHT = col(0.9, 0.97, 1.0)
T_C_ARCANE = col(0.84, 0.58, 1.0)
T_C_DUST = (0.72, 0.66, 0.56)


def t_funnel_radius(h):
    return T_R_BOTTOM + (T_R_TOP - T_R_BOTTOM) * (h ** 1.3)


def t_funnel_center(h, spin):
    return (math.sin(spin * 0.55 + h * 3.4) * 4.0 * h, T_BASE_Y - T_FUNNEL_H * h)


def t_ellipse_ring(im, center, rx, ry, phase, front_col, back_col, dashed):
    n = max(16, int(2 * math.pi * rx))
    for i in range(n):
        if dashed and (i % 3) == 0:
            continue
        a = 2 * math.pi * i / n + phase
        front = math.sin(a) > 0.0
        px(im, (center[0] + math.cos(a) * rx, center[1] + math.sin(a) * ry), 1, front_col if front else back_col)


def _mul_a(rgba, mult):
    r, g, b, a = rgba
    return (r, g, b, int(round(a * mult)))


def render_tornado_frame(spin, size, cx, cy):
    im = new_canvas(size, size)
    # --- yer golgesi ---
    sh_rx, sh_ry = 17, 5
    for iy in range(-sh_ry, sh_ry + 1):
        hw = int(sh_rx * math.sqrt(max(0.0, 1.0 - (iy / float(sh_ry)) ** 2)))
        for ix in range(-hw, hw + 1):
            if ((ix + iy) & 1) == 0:
                continue
            blend_px(im, (cx + ix, cy + T_BASE_Y + 3.0 + iy), col(0.0, 0.0, 0.0, 0.34))
    # --- taban toz halkalari ---
    t_ellipse_ring(im, (cx, cy + T_BASE_Y + 2.0), 15.0, 4.6, spin * 1.4, col(*T_C_DUST, 0.75), col(*T_C_DUST, 0.3), True)
    t_ellipse_ring(im, (cx, cy + T_BASE_Y + 3.0), 21.0, 6.4, -spin * 1.0, col(*T_C_DUST, 0.42), col(*T_C_DUST, 0.16), True)
    # --- govde ---
    rows = int(T_FUNNEL_H)
    for r in range(rows + 1):
        h = r / float(rows)
        fc = t_funnel_center(h, spin)
        c = (cx + fc[0], cy + fc[1])
        rad = t_funnel_radius(h)
        half_w = int(rad)
        if half_w < 1:
            continue
        rect(im, c, half_w * 2, 1, _mul_a(T_C_DARK, 0.4))
        px(im, (c[0] - rad, c[1]), 1, _mul_a(T_C_DARK, 0.95))
        px(im, (c[0] + rad, c[1]), 1, _mul_a(T_C_DARK, 0.95))
        px(im, (c[0] - rad + 1.0, c[1]), 1, _mul_a(T_C_MID, 0.55))
        for k in range(4):
            theta = spin * (1.5 + 0.6 * (1.0 - h)) - h * 7.0 + k * math.pi * 0.5
            cs = math.cos(theta)
            if cs < -0.25:
                continue
            x = c[0] + math.sin(theta) * rad * 0.92
            len_t = int(2.0 + 3.0 * abs(cs))
            rect(im, (x, c[1]), len_t, 1, _mul_a(T_C_LIGHT, 0.95) if cs > 0.2 else _mul_a(T_C_MID, 0.6))
    # --- katmanli donen kesikli halkalar ---
    for h2 in (0.1, 0.28, 0.46, 0.64, 0.82, 1.0):
        fc2 = t_funnel_center(h2, spin)
        c2 = (cx + fc2[0], cy + fc2[1])
        rad2 = t_funnel_radius(h2)
        t_ellipse_ring(im, c2, rad2, rad2 * 0.3, spin * (1.2 + h2) + h2 * 5.0, _mul_a(T_C_LIGHT, 0.85), _mul_a(T_C_MID, 0.3), True)
    # --- bulut basligi ---
    top_fc = t_funnel_center(1.0, spin)
    top = (cx + top_fc[0], cy + top_fc[1])
    t_ellipse_ring(im, (top[0], top[1] - 2.0), T_R_TOP + 5.0, (T_R_TOP + 5.0) * 0.28, -spin * 0.8, _mul_a(T_C_DARK, 0.9), _mul_a(T_C_DARK, 0.4), False)
    t_ellipse_ring(im, (top[0], top[1] - 4.0), T_R_TOP - 6.0, (T_R_TOP - 6.0) * 0.26, spin * 0.6, _mul_a(T_C_ARCANE, 0.55), _mul_a(T_C_ARCANE, 0.2), True)
    # --- spiral yukselen dokuntu ---
    debris_cols = [col(0.36, 0.26, 0.18), col(0.4, 0.62, 0.3), T_C_LIGHT]
    for i in range(11):
        hh = math.fmod(i * 0.37 + spin * 0.06 * (1.0 + 0.25 * (i % 3)), 1.0)
        if hh < 0.0:
            hh += 1.0
        ang = spin * 2.6 + i * 2.4
        cc_fc = t_funnel_center(hh, spin)
        cc = (cx + cc_fc[0], cy + cc_fc[1])
        rr = t_funnel_radius(hh) * 1.2
        p = (cc[0] + math.cos(ang) * rr, cc[1] + math.sin(ang) * rr * 0.3)
        dc = debris_cols[i % 3]
        px(im, p, 1, _mul_a(dc, 0.95 if math.sin(ang) > -0.2 else 0.4))
    # --- arcane kivilcimlar ---
    for i in range(5):
        h3 = 0.15 + 0.16 * i
        ang2 = -spin * 3.6 + i * 1.7
        c3_fc = t_funnel_center(h3, spin)
        c3 = (cx + c3_fc[0], cy + c3_fc[1])
        rr3 = t_funnel_radius(h3) * 1.05
        px(im, (c3[0] + math.cos(ang2) * rr3, c3[1] + math.sin(ang2) * rr3 * 0.3), 1, _mul_a(T_C_ARCANE, 0.95))
    return im


def gen_tornado():
    ## Dikey kapsam: govde tepesi cy+(BASE_Y-FUNNEL_H)=cy-72, bulut basligi bunun ~11 uzerine
    ## cikiyor (cy-83); taban golgesi/toz halkasi cy+BASE_Y+~10=cy+22 - ikisi de payla sigsin.
    size = 140
    cx, cy = size / 2.0, 95.0
    frames = []
    for f in range(TORNADO_FRAMES):
        spin = TORNADO_SPIN_RATE * (TORNADO_LOOP_PERIOD * f / TORNADO_FRAMES)
        frames.append(render_tornado_frame(spin, size, cx, cy))
    w, h = save_sheet(frames, os.path.join(ROOT, "assets", "fx", "buyucu_tornado", "loop_sheet.png"))
    print("tornado: %dx%d cell, %d frames, loop=%.3fs" % (w, h, TORNADO_FRAMES, TORNADO_LOOP_PERIOD))
    return size


# =====================================================================================================
# 2) MATTHEW - FEDA KALKANI KALKANI (fx_matthew_fox_shield.gd) - iki durum: "steady" (kalkan aktif,
#    SURDURULEBILIR - dongu olarak pisirilir) ve "pop" (0.4sn patlama - tek seferlik flipbook).
#    Dongu periyodu: en GORSEL BASKIN hareket olan yorunge (3 tilki atesi kuresi, t*1.5 rad/s,
#    periyot 2*pi/1.5=4.189s) - dash-donen halka (t*22) gibi DAHA HIZLI ikincil detaylar bu
#    dongude TAM SAYIYA yakin olmayan kat ediyor (kucuk faz sicramasi kabul edildi, bkz. dosya
#    ustu Buyucu Hortum notundaki AYNI tercih/gen_spirit_perf_sprites.py ADC alevi emsali).
# =====================================================================================================
SH2_RADIUS = 44.0
SH2_POP_DURATION = 0.4
SH2_LOOP_PERIOD = 2.0 * math.pi / 1.5
SH2_LOOP_FRAMES = 60
SH2_POP_FRAMES = 20

M_DARK = (0.6, 0.24, 0.02)
M_ORANGE = (1.0, 0.6, 0.1)
M_BRIGHT = (1.0, 0.8, 0.3)
M_CREAM = (1.0, 0.95, 0.72)
M_RED = (0.85, 0.28, 0.05)

EAR_ART = [
    "...oo.........",
    "..oaao........",
    "..oabao.......",
    ".oaabbao......",
    ".oaaccbao.....",
    "oaaacccbao....",
    "oaaaccccbao...",
    "oaaacccccbao..",
    "oaaaccccccbao.",
    "oaaacccccccbbo",
    ".oaaaccccccbo.",
    "..oaaaccccbbo.",
    "...oooooooooo.",
]
EAR_PALETTE = {"o": M_DARK, "a": M_ORANGE, "b": M_BRIGHT, "c": M_CREAM}


def art(im, center, rows, palette, alpha_mult, flip_x):
    h = len(rows)
    if h == 0:
        return
    w = len(rows[0])
    cell = 1.0
    ox = center[0] - w * cell / 2.0
    oy = center[1] - h * cell / 2.0
    for y in range(h):
        row = rows[y]
        for x in range(w):
            ch = row[x]
            if ch not in palette:
                continue
            xx = (w - 1 - x) if flip_x else x
            rgba = _mul_a(col(*palette[ch]), alpha_mult)
            rect(im, (ox + xx * cell + cell / 2.0, oy + y * cell + cell / 2.0), cell, cell, rgba)


def _mfs_ring(im, center, radius, rgba, n=1, dash_on=0, dash_off=0, phase=0.0, from_angle=0.0, sweep=2 * math.pi):
    ring(im, center, radius, rgba, n, dash_on, dash_off, phase, from_angle, sweep)


def render_matthew_shield_frame(t, popping, p, size, cx, cy):
    im = new_canvas(size, size)
    alive = 1.0 - p
    texel = 1.0
    breath = round(math.sin(t * 2.8)) * texel
    r = (SH2_RADIUS + breath) * (1.0 + p * 0.35)
    rt = int(r / texel)
    c = (cx, cy)

    # --- sihirli cam dolgu ---
    band_row = int(t * 16.0) % max(rt, 1)
    iy = -rt
    while iy <= rt:
        hw = math.sqrt(max(0.0, float(rt * rt - iy * iy))) * texel
        if hw >= texel:
            y = float(iy) * texel
            dist_to_band = abs(iy - (rt - 2 * band_row))
            if dist_to_band <= 2:
                gcol, ga = M_BRIGHT, 0.42
            else:
                gcol, ga = M_ORANGE, 0.2
            rect(im, (c[0], c[1] + y), hw * 2.0, texel, _mul_a(col(*gcol), ga * alive))
        iy += 2

    # --- halka ---
    _mfs_ring(im, c, r - texel * 1.6, _mul_a(col(*M_DARK), 0.9 * alive), 1)
    if not popping:
        _mfs_ring(im, c, r, col(*M_ORANGE), 2)
        _mfs_ring(im, c, r, col(*M_BRIGHT), 2, 5, 11, t * 22.0)
        _mfs_ring(im, c, r - texel * 0.4, col(*M_CREAM), 1, 0, 0, 0.0, math.radians(200.0), math.radians(70.0))
        for k in range(8):
            a2 = k * 2.0 * math.pi / 8.0 + math.pi / 8.0
            pulse = int(t * 3.0 + k) % 2 == 0
            px(im, (c[0] + math.cos(a2) * (r + texel * 2.0), c[1] + math.sin(a2) * (r + texel * 2.0)), 2 if pulse else 1, col(*M_CREAM))
    else:
        _mfs_ring(im, c, r, _mul_a(col(*M_ORANGE), alive), 2, 4, 5 + int(p * 30.0), p * 10.0)

    # --- kulaklar ---
    flick = -texel if (math.fmod(t, 2.6) < 0.12 and not popping) else 0.0
    fall = p * p * 34.0
    ear_h = len(EAR_ART) * texel
    left_base = (math.cos(math.radians(-124.0)) * (r - texel), math.sin(math.radians(-124.0)) * (r - texel))
    right_base = (math.cos(math.radians(-56.0)) * (r - texel), math.sin(math.radians(-56.0)) * (r - texel))
    art(im, (c[0] + left_base[0] - texel * 3.0, c[1] + left_base[1] - ear_h * 0.42 + flick + fall), EAR_ART, EAR_PALETTE, alive, False)
    art(im, (c[0] + right_base[0] + texel * 3.0, c[1] + right_base[1] - ear_h * 0.42 + flick + fall), EAR_ART, EAR_PALETTE, alive, True)

    # --- tilki atesi kureleri / kiymiklar ---
    if not popping:
        for k in range(3):
            base_a = t * 1.5 + k * 2.0 * math.pi / 3.0
            orbit_r = r * 0.74
            for tail in range(5, -1, -1):
                ta = base_a - tail * 0.13
                pos = (c[0] + math.cos(ta) * orbit_r, c[1] + math.sin(ta) * 0.92 * orbit_r)
                if tail == 0:
                    px(im, pos, 5, col(*M_ORANGE))
                    px(im, pos, 3, col(*M_BRIGHT))
                    px(im, (pos[0], pos[1] - texel * 3.0 - round(math.sin(t * 18.0 + k) * texel)), 2, col(*M_CREAM))
                else:
                    px(im, pos, 3 if tail < 3 else 2, fire_color(tail / 6.0))
    else:
        for k in range(28):
            ang = hash01(k + 11) * 2.0 * math.pi
            speed_f = 0.85 + hash01(k + 71) * 0.9
            spos = (c[0] + math.cos(ang) * (r + p * r * speed_f), c[1] + math.sin(ang) * (r + p * r * speed_f))
            sz = 2 if p < 0.55 else 1
            px(im, spos, sz, _mul_a(col(*M_BRIGHT) if k % 3 != 0 else col(*M_RED), alive))
    return im


def gen_matthew_shield():
    size = 130
    cx = cy = size / 2.0
    loop_frames = []
    for f in range(SH2_LOOP_FRAMES):
        t = SH2_LOOP_PERIOD * f / SH2_LOOP_FRAMES
        loop_frames.append(render_matthew_shield_frame(t, False, 0.0, size, cx, cy))
    save_sheet(loop_frames, os.path.join(ROOT, "assets", "fx", "matthew_fox_shield", "loop_sheet.png"))

    pop_size = int(2 * (SH2_RADIUS * 1.35 + 40))
    pcx = pcy = pop_size / 2.0
    pop_frames = []
    for f in range(SH2_POP_FRAMES):
        p = f / float(SH2_POP_FRAMES - 1)
        pop_frames.append(render_matthew_shield_frame(0.0, True, p, pop_size, pcx, pcy))
    save_sheet(pop_frames, os.path.join(ROOT, "assets", "fx", "matthew_fox_shield", "pop_sheet.png"))
    print("matthew_shield: loop %dx%d x%d frames (%.3fs), pop %dx%d x%d frames (%.3fs)" % (
        size, size, SH2_LOOP_FRAMES, SH2_LOOP_PERIOD, pop_size, pop_size, SH2_POP_FRAMES, SH2_POP_DURATION))
    return size, pop_size


if __name__ == "__main__":
    gen_tornado()
    ## 2026-09-24: Matthew kalkani pixel-art olarak yeniden tasarlandi -> tools/gen_matthew_shield_fx.py uretiyor.
    ## gen_matthew_shield() artik CAGRILMIYOR (cagrilirsa yeni sayfalarin uzerine eski tasarimi yazardi).
    print("ok")
