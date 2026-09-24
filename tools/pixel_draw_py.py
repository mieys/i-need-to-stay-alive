"""scripts/pixel_draw.gd'nin RASTER PNG uretimi icin Python karsiligi.

Kullanici isteği (2026-09-23): kalkan catlama / Oakley ari surusu halkasi / sarmasik gibi
HER KAREDE yuzlerce-binlerce draw_rect() cagrisiyla prosedurel cizilen FX'ler, coklu ornek
ayni anda canli oldugunda FPS'i cokertiyordu (bkz. proje kokundeki CLAUDE.md'ye eklenen not
+ fx_paladin_barrier.gd/fx_shield_hit.gd uzerindeki "light mod" denemesi). Kalici cozum:
GORUNUMU AYNI tutarak bu efektleri BIR KERE PNG'ye "pisirip" (bake) oyun icinde AnimatedSprite2D/
Sprite2D/Line2D ile (tek doku cizimi, CPU'nun binlerce draw_rect hazirlamasi yerine) oynatmak.

Bu modul pixel_draw.gd'deki px/line/ring/disc_dither fonksiyonlarinin AYNI matematigini
RASTER PIKSEL biriminde (1 raster px = 1 oyun texel'i, yani TEXEL=1.0 kabul edilir - PNG
Godot'ta node.scale = PixelDraw.TEXEL ile olceklenerek oyuna konur) yeniden uygular; boylece
uretilen PNG'ler prosedurel cizimle GORSEL OLARAK ES DEGER olur.
"""
import math

from PIL import Image


def col(r, g, b, a=1.0):
    """0..1 float renk -> 0..255 int RGBA tuple."""
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)), int(round(max(0.0, min(1.0, a)) * 255)))


def new_canvas(w, h):
    return Image.new("RGBA", (int(w), int(h)), (0, 0, 0, 0))


def blend_px(im, xy, rgba):
    """Tek raster pikseli standart 'over' (straight alpha) ile bindirir - draw_rect'in
    alfa < 1 iken altindaki katmanla karismasinin karsiligi."""
    x, y = int(round(xy[0])), int(round(xy[1]))
    w, h = im.size
    if not (0 <= x < w and 0 <= y < h):
        return
    r, g, b, a = rgba
    af = a / 255.0
    if af <= 0.0:
        return
    if af >= 1.0:
        im.putpixel((x, y), (r, g, b, 255))
        return
    cr, cg, cb, ca = im.getpixel((x, y))
    caf = ca / 255.0
    out_af = af + caf * (1.0 - af)
    if out_af <= 0.0001:
        im.putpixel((x, y), (0, 0, 0, 0))
        return
    out_r = (r * af + cr * caf * (1.0 - af)) / out_af
    out_g = (g * af + cg * caf * (1.0 - af)) / out_af
    out_b = (b * af + cb * caf * (1.0 - af)) / out_af
    im.putpixel((x, y), (int(round(out_r)), int(round(out_g)), int(round(out_b)), int(round(out_af * 255))))


def px(im, pos, n, rgba):
    """pixel_draw.gd px(): pos merkezli n x n 'sanat pikseli' kare."""
    x, y = pos
    x0 = int(round(x - n / 2.0))
    y0 = int(round(y - n / 2.0))
    for iy in range(n):
        for ix in range(n):
            blend_px(im, (x0 + ix, y0 + iy), rgba)


def line(im, a, b, rgba, n=1):
    ax, ay = a
    bx, by = b
    dist = math.hypot(bx - ax, by - ay)
    step = max(n, 1)
    steps = max(1, int(dist / step))
    for i in range(steps + 1):
        t = i / steps
        px(im, (ax + (bx - ax) * t, ay + (by - ay) * t), n, rgba)


def ring(im, center, radius, rgba, n=1, dash_on=0, dash_off=0, phase=0.0, from_angle=0.0, sweep=2 * math.pi):
    if radius <= 0.0:
        return
    cx, cy = center
    step = max(n, 1)
    count = max(8, int(abs(sweep) * radius / step))
    period = dash_on + dash_off
    for i in range(count):
        if period > 0 and (int(i + phase) % period) >= dash_on:
            continue
        a = from_angle + sweep * i / count
        px(im, (cx + math.cos(a) * radius, cy + math.sin(a) * radius), n, rgba)


def disc_dither(im, center, radius, rgba, parity=0, cell=1):
    if radius <= 0.0:
        return
    cx, cy = center
    cs = max(cell, 1)
    rc = int(radius / cs)
    for iy in range(-rc, rc + 1):
        hw = int(math.sqrt(max(0.0, float(rc * rc - iy * iy))))
        for ix in range(-hw, hw + 1):
            if ((ix + iy + parity) & 1) == 0:
                continue
            x0 = cx + ix * cs - cs / 2.0
            y0 = cy + iy * cs - cs / 2.0
            for yy in range(cs):
                for xx in range(cs):
                    blend_px(im, (x0 + xx, y0 + yy), rgba)


def clamp(v, lo, hi):
    return max(lo, min(hi, v))
