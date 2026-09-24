#!/usr/bin/env python3
"""Ruhani Yetenek aura'lari (Tank/Can/Adc/Dukkan) icin PNG'ye pisirilmis parcalar uretir.

Kullanici isteği (2026-09-23, kalkan/ari/sarmasik donusumunun devami): "ayni seyi ruhani
buyuler icin de yapar misin". Bu 4 aura HER KAREDE, tum sure boyunca (3-10sn) disc_dither/
genis ring dongusu cagiriyordu (~700-1200+ draw_rect/kare) - fx_spirit_taktik/blink/
fx_kalkan_bagi_link BUNA SAHIP DEGIL (disc_dither yok, zaten ucuz), o yuzden onlar
DEGISTIRILMEDI - sadece asil pahali 4 tanesi burada.

Yontem: her aura'nin STEADY-STATE (surekli acik kalan) kismi birkaç KATMANA ayrilir, her
katman ya (a) STATIK bir doku + script'te rotation/scale/modulate ile hareket ettirilir
(bkz. oakley_bee_swarm_ring.gd'deki halka donusu deseni), ya da (b) rengin zamanla
degistigi yerlerde NOTR (beyaz) bir doku + script'te modulate rengi (Dukkan sutunu gibi).
Acilis patlamasi (~0.5-0.7sn, TEK SEFERLIK, düşük toplam maliyet) VE ucuz parcaciklar
(kıvılcım/artı isareti, birkaç px() cagrisi) PROSEDUREL BIRAKILDI - donusumun asil kazanci
zaten SURDURULEBILIR (many-second) kisimda.

Cikti: assets/fx/spirit_tank/, assets/fx/spirit_can/, assets/fx/spirit_adc/, assets/fx/spirit_dukkan/
Tumu "1 raster px = 1 WORLD birimi" (bkz. tools/gen_perf_sprite_fx.py OLCEK NOTU - TEXEL ile
AYRICA olceklenmez).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel_draw_py import blend_px, col, disc_dither, line, new_canvas, px, ring  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def hex_points(radius, rot, cx=0.0, cy=0.0):
    pts = []
    for k in range(6):
        a = rot + k * (2 * math.pi / 6.0)
        pts.append((cx + math.cos(a) * radius, cy + math.sin(a) * radius * 0.92))
    return pts


def save(im, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print("wrote", path, im.size)


# ============================================================= TANK =============================================================
def gen_tank():
    out = os.path.join(ROOT, "assets", "fx", "spirit_tank")
    RADIUS = 36.0
    size = int(2 * (RADIUS + 8))
    c = size / 2.0

    outer_pts = hex_points(RADIUS, 0.0, c, c)
    im = new_canvas(size, size)
    disc_dither(im, (c, c), RADIUS - 2.0, col(0.55, 0.78, 1.0, 0.2), 0, 1)
    for i in range(6):
        a_pt, b_pt = outer_pts[i], outer_pts[(i + 1) % 6]
        line(im, a_pt, b_pt, col(0.72, 0.88, 1.0, 0.95), 1)
        mx, my = (a_pt[0] + b_pt[0]) / 2.0, (a_pt[1] + b_pt[1]) / 2.0
        dx, dy = c - mx, c - my
        dl = math.hypot(dx, dy) or 1.0
        inw = (dx / dl, dy / dl)
        line(im, (a_pt[0] + inw[0], a_pt[1] + inw[1]), (b_pt[0] + inw[0], b_pt[1] + inw[1]), col(0.45, 0.65, 0.95, 0.75), 1)
    for i in range(6):
        px(im, outer_pts[i], 3, col(1.0, 0.86, 0.4, 1.0))
        px(im, outer_pts[i], 1, col(1.0, 0.98, 0.8, 1.0))
    save(im, os.path.join(out, "hex_outer.png"))

    inner_pts = hex_points(RADIUS - 3.0, 0.0, c, c)
    im2 = new_canvas(size, size)
    for i in range(6):
        line(im2, inner_pts[i], inner_pts[(i + 1) % 6], col(0.55, 0.72, 0.95, 0.4), 1)
    save(im2, os.path.join(out, "hex_inner.png"))


# ============================================================== CAN ==============================================================
def gen_can():
    out = os.path.join(ROOT, "assets", "fx", "spirit_can")
    DOME_RADIUS = 31.0
    size = int(2 * (DOME_RADIUS + 6))
    c = size / 2.0

    fill = new_canvas(size, size)
    disc_dither(fill, (c, c), DOME_RADIUS, col(1.0, 0.9, 0.45, 0.28), 0, 1)
    save(fill, os.path.join(out, "dome_fill.png"))

    r1 = new_canvas(size, size)
    ring(r1, (c, c), DOME_RADIUS, col(1.0, 0.88, 0.4, 1.0), 1, 5, 1, 0.0)
    save(r1, os.path.join(out, "ring1.png"))

    r2 = new_canvas(size, size)
    ring(r2, (c, c), DOME_RADIUS + 1.5, col(1.0, 0.95, 0.6, 0.55), 1, 3, 3, 0.0)
    save(r2, os.path.join(out, "ring2.png"))

    r3 = new_canvas(size, size)
    ring(r3, (c, c), DOME_RADIUS - 3.0, col(1.0, 1.0, 0.85, 0.3), 1, 2, 5, 0.0)
    save(r3, os.path.join(out, "ring3.png"))

    rivets = new_canvas(size, size)
    for k in range(6):
        a = k * (2 * math.pi / 6.0)
        px(rivets, (c + math.cos(a) * DOME_RADIUS, c + math.sin(a) * DOME_RADIUS), 1, col(1.0, 0.97, 0.7, 0.95))
    save(rivets, os.path.join(out, "rivets.png"))


# ============================================================== ADC ==============================================================
FLAME_PERIOD = 2 * math.pi / 11.0  # sin(_t*11+..) periyodu - flame licks tam bu surede seamless loop yapar


def adc_render_flames(t, size, cx, gy):
    im = new_canvas(size, size)
    texel = 1.0
    for i in range(9):
        u = (i / 8.0) * 2.0 - 1.0
        x0 = u * 20.0
        h = 16.0 + 22.0 * (1.0 - abs(u)) + 5.0 * math.sin(t * 11.0 + i * 1.9)
        rows = int(h / texel)
        for r in range(rows):
            k = r / max(rows, 1)
            sway = math.sin(t * 9.0 + i + r * 0.3) * k * texel * 2.0
            fc = _fire_color(0.15 + k * 0.7)
            px(im, (cx + x0 + sway - u * k * 6.0, gy - r * texel), 1, fc)
    return im


def _fire_color(t):
    stops = [
        (1.0, 0.96, 0.7), (1.0, 0.78, 0.22), (1.0, 0.5, 0.1), (0.9, 0.2, 0.06), (0.45, 0.08, 0.06),
    ]
    t = max(0.0, min(1.0, t)) * (len(stops) - 1)
    i = min(int(t), len(stops) - 2)
    f = t - i
    a, b = stops[i], stops[i + 1]
    r = a[0] + (b[0] - a[0]) * f
    g = a[1] + (b[1] - a[1]) * f
    bl = a[2] + (b[2] - a[2]) * f
    return col(r, g, bl, 1.0)


def gen_adc():
    out = os.path.join(ROOT, "assets", "fx", "spirit_adc")
    size = 96
    cx = size / 2.0
    gy = size - 14.0  # zemin cizgisi tabana yakin, alevler yukari uzansin diye pay birakiliyor

    # --- Zemin dither elips: statik (titreme atlandi, bkz. sinif ustu not) ---
    ground = new_canvas(size, size)
    rx = 26.0
    for iy in range(-6, 7):
        hw = int(round(math.sqrt(max(0.0, 1.0 - (iy / 6.5) ** 2)) * rx))
        for ix in range(-hw, hw + 1):
            if ((ix + iy) & 1) == 0:
                continue
            blend_px(ground, (cx + ix, gy + iy), col(1.0, 0.36, 0.12, 0.5))
    save(ground, os.path.join(out, "ground.png"))

    # --- Alevler: FLAME_PERIOD boyunca seamless loop (bkz. sinif ustu FLAME_PERIOD notu) ---
    frames = 12
    sheet_w = size * frames
    from PIL import Image
    sheet = Image.new("RGBA", (sheet_w, size), (0, 0, 0, 0))
    for f in range(frames):
        t = FLAME_PERIOD * f / frames
        frame = adc_render_flames(t, size, cx, gy)
        sheet.paste(frame, (f * size, 0), frame)
    save(sheet, os.path.join(out, "flames.png"))

    # --- 3 elmas: sabit bicimde (0 derece referans), script rotation=_t*5.0 ile dondurulur ---
    dsize = 72
    dc = dsize / 2.0
    dia = new_canvas(dsize, dsize)
    tcol = col(1.0, 0.75, 0.25, 1.0)  ## bkz. not: on/arka parlaklik farki basitlik icin atlandi
    for k in range(3):
        a2 = k * (2 * math.pi / 3.0)
        p = (dc + math.cos(a2) * 26.0, dc + math.sin(a2) * 18.0 - 2.0)
        px(dia, p, 2, tcol)
        px(dia, (p[0] + 2.0, p[1]), 1, tcol)
        px(dia, (p[0] - 2.0, p[1]), 1, tcol)
        px(dia, (p[0], p[1] + 2.0), 1, tcol)
        px(dia, (p[0], p[1] - 2.0), 1, tcol)
    save(dia, os.path.join(out, "diamonds.png"))


# ============================================================= DUKKAN =============================================================
def gen_dukkan():
    out = os.path.join(ROOT, "assets", "fx", "spirit_dukkan")
    size = 92
    c = size / 2.0

    def ellipse_ring(im, rx, ry, color, dash_on, dash_off):
        count = max(24, int(2 * math.pi * max(rx, ry)))
        period = dash_on + dash_off
        for i in range(count):
            if period > 0 and (i % period) >= dash_on:
                continue
            a = 2 * math.pi * i / count
            blend_px(im, (c + math.cos(a) * rx, c + math.sin(a) * ry), color)

    r1 = new_canvas(size, size)
    ellipse_ring(r1, 34.0, 15.0, col(0.72, 0.5, 1.0, 0.9), 5, 1)
    ellipse_ring(r1, 32.5, 14.0, col(0.55, 0.35, 0.9, 0.6), 5, 1)
    save(r1, os.path.join(out, "ring_violet.png"))

    r2 = new_canvas(size, size)
    ellipse_ring(r2, 24.0, 10.5, col(1.0, 0.85, 0.45, 0.75), 3, 3)
    save(r2, os.path.join(out, "ring_gold.png"))

    runes = new_canvas(size, size)
    for k in range(6):
        a = k * (2 * math.pi / 6.0)
        p = (c + math.cos(a) * 29.0, c + math.sin(a) * 12.7)
        px(runes, p, 1, col(1.0, 0.95, 0.75, 1.0))
        px(runes, (p[0], p[1] - 1.0), 1, col(0.85, 0.7, 1.0, 0.8))
    save(runes, os.path.join(out, "runes.png"))

    ## Sutun: NOTR (beyaz) dither doku, azami yukseklikte pisirilir - script'te scale.y (buyume)
    ## + modulate (mor->altin renk gecisi) ile kontrol edilir (bkz. sinif ustu not).
    col_w, col_h = 20, 100
    column = new_canvas(col_w, col_h)
    half_w = 9
    for iy in range(col_h):
        taper = 1.0 - (iy / float(col_h)) * 0.6
        hw = max(1, int(round(half_w * taper)))
        for ix in range(-hw, hw + 1):
            if ((ix + iy) & 1) == 0:
                continue
            blend_px(column, (col_w / 2.0 + ix, col_h - 1 - iy), col(1.0, 1.0, 1.0, 0.85))
    save(column, os.path.join(out, "column.png"))


if __name__ == "__main__":
    gen_tank()
    gen_can()
    gen_adc()
    gen_dukkan()
    print("ok")
