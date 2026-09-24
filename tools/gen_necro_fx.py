#!/usr/bin/env python3
"""Necromancer pixel-art efektleri (spritesheet) - cagirma + yeni ULTI (Lanetli Kafatasi) + korku gostergesi + R ikonu.

Kullanici istegi (2026-09-24): "necromancerin yetenekleri icin (yaratik spawnlandiginda) ozel efektler hazirla pixel tarzda.
Necromancerin ultisi: bundan sonra dev bir kafatasini dusmanlara dogru gonderir, kafatasi 10 saniye boyunca dusmanlara dogru
carpar (kalabaliga ve bosslara oncelik verir) ve her isabette onlara %110 ap hasar vererek 3 saniyeliğine korkutur, korkan
dusmanlar etrafa rasgele yonlerde yurumeye calisir ve hasar veremez. (60 saniye yetenek bekleme suresi) bunun icin pixel
tarzda ozel efekt hazirlamani istiyorum ... bu efektleri yaptiktan sonrasinda sprite'a donustur performans kaybi olmasin diye."
Renkler Necromancer'in kendisinden: turkuaz-yesil ruh atesi (saci) + mor (kanatlari) + kemik.

Ciktilar (assets/fx/necro/, 1 sanat pikseli = TEXEL 1.212 dunya birimi, oyunda tek AnimatedSprite2D):
  skull_*   72x72  "fly" (6 kare, 10 fps dongu: cene takirdar, goz cukurlarinda ve tepesinde ruh atesi),
                   "appear" (6 kare: atesten toplanarak belirir), "vanish" (7 kare: ruh dumanina dagilir),
                   "shadow" (1 kare: yerdeki golge elipsi)
  impact_*  128x128 "play" (9 kare, 22 fps): carpma - parlama, 56 px yaricapli turkuaz sok halkasi (= 68 birim,
                   necro_skull.gd IMPACT_RADIUS), disa savrulan ruhlar, kemik kiriklari
  summon_*  64x64  "play" (12 kare, 16 fps): iskelet cagirma - yerde cizilen mor run cemberi, karanlik havuz, havuzdan
                   uzanan kemik eller, yukselen turkuaz ruh alevleri
  trail_*   16x16  "play" (5 kare, 16 fps): kafatasinin arkasinda kalan kucuk ruh dumani
  fear_*    16x16  "loop" (6 kare, 8 fps): korkmus dusmanin basinin ustunde titreyen kucuk hayalet (notr renk -
                   Melek'in Kutsal Korku'su da ayni gostergeyi kullanir)
  assets/skills/necromancer_lanetli_kafatasi_icon.png - 48x48 kare ikon (3x -> 144), tools/gen_elara_korsan_icons.py dili.
Kullanim: python tools/gen_necro_fx.py [onizleme.png]   (sonra Godot'ta --headless --import)
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_enemy_ability_fx import put, rgba, with_alpha, outline_pass, ease_out, _puff  # noqa: E402
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "necro")
RES = "res://assets/fx/necro/"

# ruh atesi (turkuaz)
T0, T1, T2, T3, T4 = rgba(0.05, 0.16, 0.18), rgba(0.1, 0.43, 0.43), rgba(0.24, 0.77, 0.69), rgba(0.59, 0.96, 0.84), rgba(0.9, 1.0, 0.96)
# mor
V0, V1, V2, V3 = rgba(0.12, 0.05, 0.17), rgba(0.31, 0.14, 0.47), rgba(0.54, 0.27, 0.77), rgba(0.77, 0.55, 0.96)
# kemik
BL, BM, BS, BD = rgba(0.95, 0.92, 0.84), rgba(0.82, 0.77, 0.66), rgba(0.6, 0.55, 0.47), rgba(0.35, 0.3, 0.3)
OUTL = rgba(0.07, 0.04, 0.1)
HOLE = rgba(0.06, 0.03, 0.08)


def fire_tone(heat):
    if heat > 0.82:
        return T4
    if heat > 0.6:
        return T3
    if heat > 0.36:
        return T2
    return T1


def flame_tongue(im, x, base_y, h, w, sway, phase_heat=1.0):
    """Yukari dogru incelen tek ruh atesi dili (sert tonlu, kenari koyu)."""
    top = int(round(h))
    for yy in range(top + 1):
        u = min(1.0, yy / max(h, 1.0))
        # yuvarlak govdeli, ucta sivrilen dil (kristal/diken gibi durmasin)
        half = w * (1.0 - u) ** 0.55 * (0.8 + 0.2 * math.sin(min(1.0, u * 2.2) * math.pi))
        cx = x + sway * u * u
        for xx in range(int(cx - half - 1), int(cx + half + 2)):
            d = abs(xx + 0.5 - cx) / max(half, 0.5)
            if d > 1.0:
                continue
            # katmanlar yataya yakin (cekirdek altta-ortada, uc koyu) - dikey serit/kristal gorunumu olmasin
            heat = ((1.0 - d * d) * 0.38 + (1.0 - u) ** 1.15 * 0.62) * phase_heat
            put(im, xx, base_y - yy, fire_tone(heat))


# ============================================================================================================ KAFATASI
SK = 72
SCX, SCY = 36, 42  # kafatasi (kubbe) merkezi


def draw_skull(im, jaw_open, eye_heat, flicker):
    """Onden goruntu dev kafatasi: genis kubbe, iri goz cukurlari (icinde ruh atesi), burun, elmacik, takirdayan cene."""
    d = ImageDraw.Draw(im)
    # kubbe + elmacik
    d.ellipse((SCX - 19, SCY - 23, SCX + 19, SCY + 13), fill=BM)
    d.polygon([(SCX - 17, SCY + 4), (SCX + 17, SCY + 4), (SCX + 14, SCY + 14), (SCX - 14, SCY + 14)], fill=BM)
    # ust cene (dis sirasi tabani)
    d.rectangle((SCX - 10, SCY + 13, SCX + 10, SCY + 16), fill=BM)
    # kure golgelendirme (isik sol ustten)
    for y in range(SCY - 24, SCY + 17):
        for x in range(SCX - 20, SCX + 21):
            if im.getpixel((x, y))[3] == 0:
                continue
            nx, ny = (x + 0.5 - SCX) / 19.0, (y + 0.5 - (SCY - 5)) / 19.0
            lit = -(nx * 0.7 + ny * 0.8)
            if lit > 0.62 and nx * nx + ny * ny < 0.85:
                im.putpixel((x, y), BL)
            elif lit < -0.55:
                im.putpixel((x, y), BS)
    # sakak cukurlari (yanlarda hafif golge)
    for s in (-1, 1):
        for y in range(SCY - 2, SCY + 8):
            put(im, SCX + s * 17, y, BS)
            put(im, SCX + s * 16, y + 1, BS)
    # alin catlagi
    for (x, y) in ((SCX + 5, SCY - 20), (SCX + 6, SCY - 19), (SCX + 6, SCY - 18), (SCX + 7, SCY - 17), (SCX + 6, SCY - 16),
                   (SCX + 7, SCY - 15), (SCX + 8, SCY - 14)):
        put(im, x, y, BD)
    put(im, SCX + 8, SCY - 17, BD)
    put(im, SCX + 9, SCY - 18, BD)
    # goz cukurlari (iri, hafif egik) + ruh atesi
    for s in (-1, 1):
        ex, ey = SCX + s * 8, SCY + 1
        for y in range(ey - 6, ey + 6):
            for x in range(ex - 6, ex + 7):
                e = ((x + 0.5 - ex) / 6.2) ** 2 + ((y + 0.5 - ey) / 5.4) ** 2
                if e <= 1.0:
                    im.putpixel((x, y), HOLE)
        # cukur ust kenari (kas kemigi) acik
        for x in range(ex - 5, ex + 6):
            put(im, x, ey - 6, BL if s < 0 else BM)
        # ofkeli kas: dista yuksek, burna dogru alcalan egik cizgi; cizginin ustunde kalan cukur kemikle kapanir
        for x in range(ex - 6, ex + 7):
            t = (x - (ex - 6)) / 12.0 if s < 0 else ((ex + 6) - x) / 12.0  # 0 dis .. 1 ic
            ly = ey - 6 + t * 3.5
            for y in range(ey - 7, int(ly)):
                if im.getpixel((x, y)) == HOLE:
                    im.putpixel((x, y), BS)
            put(im, x, int(ly), BD)
        # ic ates: goz bebegi + yukari yalayan kucuk dil
        # goz atesi: damla bicimli kucuk alev (ustu titrer)
        fl = flicker if s < 0 else -flicker
        for (dx, dy) in ((-2, 1), (2, 1), (-2, 0), (2, 0), (-1, 2), (0, 2), (1, 2)):
            put(im, ex + dx, ey + dy, T1)
        for (dx, dy) in ((-1, 1), (1, 1), (-1, -1), (1, -1), (0, -2), (-1, 0), (1, 0), (0, 1)):
            put(im, ex + dx, ey + dy, T2 if dy >= 0 else T3)
        put(im, ex, ey, T4 if eye_heat > 0.7 else T3)
        put(im, ex, ey - 1, T4 if eye_heat > 0.85 else T3)
        put(im, ex + fl, ey - 3, T2)
        put(im, ex + fl, ey - 4, T1)
    # burun deligi (ters kalp)
    for (x, y) in ((SCX - 1, SCY + 8), (SCX, SCY + 8), (SCX + 1, SCY + 8), (SCX - 2, SCY + 7), (SCX + 2, SCY + 7),
                   (SCX - 1, SCY + 9), (SCX + 1, SCY + 9), (SCX, SCY + 10), (SCX - 2, SCY + 6), (SCX + 2, SCY + 6)):
        put(im, x, y, HOLE)
    # ust dis sirasi
    for i, x in enumerate(range(SCX - 9, SCX + 10)):
        put(im, x, SCY + 16, BD if i % 3 == 2 else BL)
        put(im, x, SCY + 17, BD if i % 3 == 2 else BM)
    # alt cene (acilip kapanir)
    jy = SCY + 18 + jaw_open
    if jaw_open > 0:
        for y in range(SCY + 18, jy):
            for x in range(SCX - 8, SCX + 9):
                put(im, x, y, HOLE)
    d.polygon([(SCX - 11, jy), (SCX + 11, jy), (SCX + 10, jy + 5), (SCX + 5, jy + 8), (SCX - 5, jy + 8), (SCX - 10, jy + 5)], fill=BM)
    for i, x in enumerate(range(SCX - 9, SCX + 10)):
        put(im, x, jy, BD if i % 3 == 2 else BL)
    for x in range(SCX - 9, SCX + 10):
        put(im, x, jy + 5 if abs(x - SCX) < 9 else jy + 4, BS)
    for x in range(SCX - 4, SCX + 5):
        put(im, x, jy + 7, BS)
    put(im, SCX - 10, jy + 1, BL)
    put(im, SCX - 10, jy + 2, BL)


def skull_fire(im, fi, strength=1.0):
    """Kubbenin ustunu saran ruh atesi kutlesi: her sutunda kubbe yuzeyinden yukari, 5 dilin tepe egrisine kadar dolu alev
    (dis kenar koyu turkuaz, ice/asagi dogru parlak) - tek tek diken gibi degil, tepeyi yalayan tek bir alev. Kafatasindan
    ONCE cizilir (tabani kubbenin arkasinda kalir)."""
    ph = fi / 6.0 * math.tau
    tongues = []
    for (ox, h0, w0, p0) in ((-13, 9, 6.0, 0.0), (-6, 15, 6.5, 1.9), (1, 19, 7.0, 3.6), (8, 14, 6.5, 5.1), (14, 8, 5.5, 2.6)):
        h = h0 * strength * (0.8 + 0.2 * math.sin(ph + p0))
        tongues.append((SCX + ox + math.sin(ph + p0) * 1.2, h, w0))
    for x in range(SCX - 21, SCX + 22):
        dx = (x + 0.5 - SCX) / 19.5
        if abs(dx) > 1.0:
            continue
        y_d = (SCY - 5) - 18.0 * math.sqrt(1.0 - dx * dx)
        ht = 3.0 * strength
        for (tx, h, w) in tongues:
            k = 1.0 - ((x + 0.5 - tx) / w) ** 2
            if k > 0:
                ht = max(ht, h * k ** 0.7 + 3.0 * strength)
        y_top = y_d - ht
        y_bot = y_d + 3
        for y in range(int(math.floor(y_top)), int(y_bot) + 1):
            t = (y + 0.5 - y_top) / max(1.0, y_bot - y_top)  # 0 tepe .. 1 taban
            if t < 0.22:
                col = T1
            elif t < 0.5:
                col = T2
            elif t < 0.78:
                col = T3
            else:
                col = T4
            put(im, x, y, col)
    # dillerden kopan kucuk alev parcalari
    for k, (tx, h, w) in enumerate(tongues):
        if (fi + k) % 3 == 0 and h > 10:
            dxn = (tx - SCX) / 19.5
            top = (SCY - 5) - 18.0 * math.sqrt(max(0.0, 1.0 - dxn * dxn)) - h - 6
            put(im, tx, top, T2)
            put(im, tx, top + 1, T1)


def eye_flames(im, fi):
    """Goz cukurlarindan alnin uzerine yalayan ruh atesi dilleri (kafatasi + konturdan SONRA, konturlanmaz)."""
    ph = fi / 6.0 * math.tau
    for s, p0 in ((-1, 0.0), (1, 2.4)):
        ex, ey = SCX + s * 8, SCY + 1
        h = 11 + 3 * math.sin(ph + p0)
        flame_tongue(im, ex, ey + 2, h, 3.4, math.sin(ph * 2 + p0) * 1.6 - s * 0.8)
        flame_tongue(im, ex - s * 3, ey + 1, h * 0.45, 1.8, -s * 1.2)
        put(im, ex, ey, T4)
        put(im, ex, ey + 1, T4)


def spirit_glow(im, fi):
    """Konturun disina 1 px soluk turkuaz ruh parlamasi (nabiz atar)."""
    src = im.copy()
    w, h = im.size
    a = 0.45 + 0.25 * math.sin(fi / 6.0 * math.tau)
    for y in range(h):
        for x in range(w):
            if src.getpixel((x, y))[3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src.getpixel((nx, ny)) == OUTL:
                    im.putpixel((x, y), with_alpha(T2, a))
                    break


def skull_frame(fi, fire_strength=1.0, jaw=None):
    im = Image.new("RGBA", (SK, SK), (0, 0, 0, 0))
    jaw_open = jaw if jaw is not None else (0, 1, 2, 2, 1, 0)[fi % 6]
    eye_heat = 0.75 + 0.25 * math.sin(fi / 6.0 * math.tau)
    draw_skull(im, jaw_open, eye_heat, (0, 1, 0, -1, 0, 1)[fi % 6])
    outline_pass(im, OUTL)
    spirit_glow(im, fi)
    if fire_strength > 0:
        eye_flames(im, fi)
    # tepeden kopup yukselen ruh zerrecikleri (kontursuz)
    for k in range(4):
        u = ((fi / 6.0) + k / 4.0) % 1.0
        x = SCX + math.sin(u * 5 + k * 2.2) * 11
        y = SCY - 26 - u * 14
        put(im, x, y, with_alpha(T3 if u < 0.5 else T2, 1.0 - u))
        put(im, x, y + 1, with_alpha(T1, 0.6 * (1.0 - u)))
    return im


def skull_fly():
    return [skull_frame(i) for i in range(6)]


def skull_appear():
    """Ruh atesi merkezde toplanir, kafatasi alttan ustte 'dolarak' belirir."""
    frames = []
    full = skull_frame(0)
    for i in range(6):
        u = (i + 1) / 6.0
        im = Image.new("RGBA", (SK, SK), (0, 0, 0, 0))
        # kafatasi: alttan yukari maske ile ortaya cikar
        cut = int(SK - u * (SK - 6))
        part = full.crop((0, cut, SK, SK))
        if u < 1.0:
            part = Image.blend(Image.new("RGBA", part.size, (0, 0, 0, 0)), part, min(1.0, 0.35 + u))
        im.paste(part, (0, cut), part)
        # donen toplanan ruh parcaciklari
        for k in range(10):
            a = k / 10.0 * math.tau + u * 3.0
            r = (1.0 - u) * 30 + 4
            x = SCX + math.cos(a) * r
            y = SCY - 4 + math.sin(a) * r * 0.8
            put(im, x, y, with_alpha(T3, 1.0))
            put(im, x - math.cos(a) * 2, y - math.sin(a) * 2, with_alpha(T2, 0.7))
        if i == 5:
            for k in range(16):
                a = k / 16.0 * math.tau
                put(im, SCX + math.cos(a) * 24, SCY - 2 + math.sin(a) * 22, with_alpha(T3, 0.8))
        frames.append(im)
    return frames


def skull_vanish():
    """Kafatasi solar, icinden 14 kucuk ruh (2x2 parlak bas + kuyruk) kivrilarak yukselip soner."""
    frames = []
    rnd = random.Random(5)
    souls = [(SCX + rnd.uniform(-15, 15), SCY + rnd.uniform(-16, 14), rnd.uniform(0, math.tau), rnd.uniform(0.7, 1.2)) for _ in range(14)]
    base = skull_frame(0)
    for i in range(7):
        u = i / 6.0
        im = Image.new("RGBA", (SK, SK), (0, 0, 0, 0))
        if i < 4:
            faded = Image.blend(Image.new("RGBA", base.size, (0, 0, 0, 0)), base, max(0.0, 1.0 - u * 1.5))
            im.alpha_composite(faded)
        for (sx, sy, p0, sp) in souls:
            rise = ease_out(u) * 22 * sp
            hx = sx + math.sin(p0 + u * 5) * 3
            hy = sy - rise
            al = min(1.0, 0.4 + u * 2) * (1.0 - u * 0.8)
            for (dx, dy, col) in ((0, 0, T4), (1, 0, T3), (0, 1, T3), (1, 1, T2)):
                put(im, hx + dx, hy + dy, with_alpha(col, al))
            for j in range(1, 4):
                put(im, sx + math.sin(p0 + (u - j * 0.06) * 5) * 3 + 0.5, hy + 1 + j * 2, with_alpha(T2 if j < 2 else T1, al * (1 - j / 4)))
        frames.append(im)
    return frames


def skull_shadow():
    im = Image.new("RGBA", (SK, SK), (0, 0, 0, 0))
    for y in range(-4, 5):
        for x in range(-16, 17):
            e = (x / 16.5) ** 2 + (y / 4.6) ** 2
            if e <= 1.0:
                put(im, SCX + x, SK - 8 + y, rgba(0.05, 0.02, 0.08, 0.42 if e < 0.55 else 0.26))
    return [im]


# ============================================================================================================ CARPMA
IM = 128


def impact_frames():
    rnd = random.Random(21)
    c = IM / 2.0
    souls = [(k / 8.0 * math.tau + rnd.uniform(-0.2, 0.2), rnd.uniform(0.8, 1.1)) for k in range(8)]
    chips = [(rnd.uniform(0, math.tau), rnd.uniform(18, 34), rnd.choice((BL, BM))) for _ in range(7)]
    frames = []
    for i in range(9):
        u = i / 8.0
        im = Image.new("RGBA", (IM, IM), (0, 0, 0, 0))
        # zeminde mor iz (yanik)
        if i >= 1:
            a = 0.35 * (1.0 - u)
            for y in range(-9, 10):
                for x in range(-22, 23):
                    if (x / 22.0) ** 2 + (y / 9.0) ** 2 <= 1.0:
                        put(im, c + x, c + y + 2, with_alpha(V1, a))
        # sok halkalari (turkuaz on, mor arka)
        r1 = 8 + 48 * ease_out(u * 1.15)
        r2 = 6 + 40 * ease_out(max(0.0, u - 0.12) * 1.2)
        for rr, col, al, th in ((r2, V2, 0.75 * (1 - u), 1.0), (r1, T3 if i < 4 else T2, 1.0 - u * 0.85, 1.6 if i < 3 else 1.0)):
            if rr <= 0:
                continue
            for y in range(int(c - rr - 2), int(c + rr + 3)):
                for x in range(int(c - rr - 2), int(c + rr + 3)):
                    dd = math.hypot(x + 0.5 - c, y + 0.5 - c)
                    if abs(dd - rr) <= th * 0.5 + 0.25:
                        put(im, x, y, with_alpha(col, al))
        # merkez parlama
        if i < 3:
            fr = (10, 14, 9)[i]
            for y in range(-fr, fr + 1):
                for x in range(-fr, fr + 1):
                    dd = math.hypot(x, y)
                    if dd <= fr:
                        col = T4 if dd < fr * 0.45 else (T3 if dd < fr * 0.75 else T2)
                        put(im, c + x, c + y, with_alpha(col, 0.95 if i < 2 else 0.6))
        # merkezden yukari fiskiran ruh atesi (1..4)
        if 1 <= i <= 4:
            hh = (10, 20, 16, 8)[i - 1]
            flame_tongue(im, c, c + 4, hh, 7.0, (0, 1, -1, 0)[i - 1] * 1.5, 1.0 - 0.15 * (i - 1))
            flame_tongue(im, c - 9, c + 5, hh * 0.55, 4.0, -1.5, 0.9)
            flame_tongue(im, c + 9, c + 5, hh * 0.6, 4.0, 1.5, 0.9)
        # disa savrulan ruhlar (2x2 bas + kuyruk)
        if 1 <= i <= 7:
            for (a, sp) in souls:
                rr = (12 + 42 * ease_out(u)) * sp
                hx, hy = c + math.cos(a) * rr, c + math.sin(a) * rr * 0.85 - u * 8
                al = 1.0 - u * 0.85
                for (dx, dy, col) in ((0, 0, T4), (1, 0, T3), (0, 1, T3), (1, 1, T2)):
                    put(im, hx + dx, hy + dy, with_alpha(col, al))
                for j in range(1, 5):
                    put(im, hx + 0.5 - math.cos(a) * j * 2, hy + 0.5 - math.sin(a) * j * 1.7, with_alpha(T2 if j < 3 else T1, al * (1 - j / 5)))
        # kemik kiriklari (yercekimli)
        if 1 <= i <= 6:
            for (a, dist, col) in chips:
                rr = dist * ease_out(u * 1.3)
                x = c + math.cos(a) * rr
                y = c + math.sin(a) * rr * 0.7 - 14 * math.sin(min(1.0, u * 1.3) * math.pi)
                put(im, x, y, col)
                put(im, x + 1, y, BS)
        frames.append(im)
    return frames


# ============================================================================================================ CAGIRMA
SM = 64


def summon_frames():
    cx, gy = SM / 2.0, 46.0
    rnd = random.Random(3)
    motes = [(rnd.uniform(-14, 14), rnd.uniform(0, 1)) for _ in range(7)]
    frames = []
    for i in range(12):
        u = i / 11.0
        im = Image.new("RGBA", (SM, SM), (0, 0, 0, 0))
        fade = 1.0 if i < 9 else (11 - i) / 3.0
        # karanlik havuz
        pr = min(1.0, i / 3.0) * 12
        if pr > 0:
            for y in range(-5, 6):
                for x in range(-13, 14):
                    if (x / max(pr, 0.1)) ** 2 + (y / max(pr * 0.38, 0.1)) ** 2 <= 1.0:
                        put(im, cx + x, gy + y, with_alpha(V0, 0.9 * fade))
        # run cemberi: yay cizilerek tamamlanir (ilk 4 kare), sonra nabiz
        sweep = min(1.0, (i + 1) / 4.0)
        n = 64
        for k in range(int(n * sweep)):
            a = -math.pi / 2 + k / n * math.tau
            put(im, cx + math.cos(a) * 21, gy + math.sin(a) * 8.2, with_alpha(V3 if i in (3, 4) else V2, 0.95 * fade))
        # 6 run isareti (cember uzerinde kucuk dikey cizgi) - cember tamamlaninca
        if i >= 3:
            for k in range(6):
                a = k / 6.0 * math.tau + 0.3
                rx, ry = cx + math.cos(a) * 21, gy + math.sin(a) * 8.2
                put(im, rx, ry - 1, with_alpha(V3, fade))
                put(im, rx, ry - 2, with_alpha(T3 if (k + i) % 3 == 0 else V2, fade))
        # havuzdan uzanan iki kemik el (3..8)
        if 3 <= i <= 8:
            rise = (0, 0, 0, 2, 4, 5, 5, 4, 2)[i]
            for s in (-1, 1):
                hx = cx + s * 6
                for yy in range(rise):
                    put(im, hx, gy - yy, BM)
                if rise >= 3:
                    tip = gy - rise
                    put(im, hx - 1, tip, BL)
                    put(im, hx + 1, tip, BL)
                    put(im, hx, tip - 1, BL)
                    put(im, hx - 1, tip - 1, BM)
                    put(im, hx + s * 2, tip + 1, BM)
        # yukselen ruh alevleri (2..9)
        if 2 <= i <= 9:
            k = i - 2
            h = (4, 12, 20, 26, 24, 18, 11, 5)[k]
            sway = (0, 1, 0, -1, 0, 1, 0, -1)[k]
            flame_tongue(im, cx, gy - 1, h, 6.0, sway * 1.5)
            flame_tongue(im, cx - 8, gy, h * 0.55, 4.0, -sway)
            flame_tongue(im, cx + 8, gy, h * 0.6, 4.0, sway)
        # parlama (cagirma ani, kare 5)
        if i == 5:
            for k in range(8):
                a = k / 8.0 * math.tau
                for j in (9, 11):
                    put(im, cx + math.cos(a) * j, gy - 14 + math.sin(a) * j, with_alpha(T4, 0.8))
        # yukselen ruh zerrecikleri
        if i >= 4:
            for (mx, p0) in motes:
                p = (u + p0) % 1.0
                put(im, cx + mx, gy - 4 - p * 34, with_alpha(T3, (1.0 - p) * fade))
        frames.append(im)
    return frames


# ============================================================================================================ IZ + KORKU
def trail_frames():
    frames = []
    for i in range(5):
        u = i / 4.0
        im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        _puff(im, 8, 8 - u * 2, 2.6 + u * 2.2, (T3, T2, T1) if i < 2 else (T2, T1, V1), 0.85 * (1.0 - u * 0.85))
        frames.append(im)
    return frames


GH_L, GH_M, GH_D = rgba(0.95, 0.94, 1.0), rgba(0.8, 0.78, 0.94), rgba(0.55, 0.5, 0.74)


def fear_frames():
    """Kucuk titreyen hayalet: iri yuvarlak gozler + 'o' agiz, dalgali etek; yaninda damlayan ter damlasi."""
    frames = []
    for i in range(6):
        im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        bob = (0, 0, -1, -1, 0, 0)[i]
        shake = (0, 1, 0, -1, 0, 1)[i]
        ox, oy = 4 + shake, 3 + bob
        body = [".###.", "#####", "#####", "#####", "#####", "#.#.#" if i % 2 == 0 else ".#.#."]
        # 7 genislik: kenar sutunlari ekle
        for y, row in enumerate(body):
            for x, ch in enumerate(row):
                if ch == "#":
                    put(im, ox + 1 + x, oy + y, GH_M)
            if 1 <= y <= 4:
                put(im, ox, oy + y, GH_M)
                put(im, ox + 6, oy + y, GH_M)
        put(im, ox + 2, oy, GH_L)
        put(im, ox + 1, oy + 1, GH_L)
        for y in range(1, 5):
            put(im, ox + 6, oy + y, GH_D)
        # gozler (iri, korkmus) + agiz
        put(im, ox + 2, oy + 2, OUTL)
        put(im, ox + 4, oy + 2, OUTL)
        put(im, ox + 3, oy + 4, OUTL)
        outline_pass(im, rgba(0.16, 0.12, 0.26))
        # ter damlasi (kontursuz)
        dy = (0, 1, 2, 3, 0, 1)[i]
        put(im, ox + 8, oy + dy, rgba(0.62, 0.86, 1.0))
        if dy < 2:
            put(im, ox + 8, oy + dy - 1, rgba(0.62, 0.86, 1.0, 0.6))
        frames.append(im)
    return frames


# ============================================================================================================ R IKONU
def make_icon():
    import gen_elara_korsan_icons as ik
    base = ik.tile(ik.C('#3a2458'), ik.C('#120a1c'), ik.C('#2f8a80'), ik.C('#7a58b0'), ik.C('#0a0610'))
    e = ik.canvas()
    d = ImageDraw.Draw(e)
    cx, cy = 24, 25
    # kubbe + elmacik + cene (kucuk olcekli kafatasi)
    d.ellipse((cx - 11, cy - 13, cx + 11, cy + 8), fill=BM)
    d.polygon([(cx - 10, cy + 2), (cx + 10, cy + 2), (cx + 8, cy + 9), (cx - 8, cy + 9)], fill=BM)
    d.polygon([(cx - 7, cy + 11), (cx + 7, cy + 11), (cx + 6, cy + 14), (cx - 6, cy + 14)], fill=BM)
    for y in range(cy - 13, cy + 9):
        for x in range(cx - 11, cx + 12):
            if e.getpixel((x, y))[3] == 0:
                continue
            nx, ny = (x + 0.5 - cx) / 11.0, (y + 0.5 - (cy - 3)) / 11.0
            lit = -(nx * 0.7 + ny * 0.8)
            if lit > 0.6 and nx * nx + ny * ny < 0.8:
                e.putpixel((x, y), BL)
            elif lit < -0.5:
                e.putpixel((x, y), BS)
    for s in (-1, 1):
        ex, ey = cx + s * 5, cy + 1
        d.ellipse((ex - 3, ey - 3, ex + 3, ey + 3), fill=HOLE)
        # ofkeli kas (dista yuksek, ice dogru alcalir)
        for x in range(ex - 4, ex + 5):
            t = (x - (ex - 4)) / 8.0 if s < 0 else ((ex + 4) - x) / 8.0
            ly = int(ey - 4 + t * 2.5)
            for y in range(ey - 4, ly):
                if e.getpixel((x, y)) == HOLE:
                    e.putpixel((x, y), BS)
            put(e, x, ly, BD)
    for (x, y) in ((cx - 1, cy + 6), (cx, cy + 6), (cx + 1, cy + 6), (cx, cy + 7)):
        put(e, x, y, HOLE)
    for i, x in enumerate(range(cx - 6, cx + 7)):
        put(e, x, cy + 9, BD if i % 3 == 2 else BL)
        put(e, x, cy + 10, HOLE)
        put(e, x, cy + 11, BD if i % 3 == 1 else BL)
    fx = ik.canvas()
    # goz cukurlarindan alna yalayan ruh atesi (kontursuz katman)
    for s in (-1, 1):
        ex, ey = cx + s * 5, cy + 1
        flame_tongue(fx, ex, ey + 2, 8, 2.4, -s * 0.8)
        put(fx, ex, ey + 1, T4)
    # sagdan sola hiz cizgileri (firlatilan kafatasi)
    for (y, x0, ln) in ((17, 3, 6), (24, 2, 5), (31, 4, 6)):
        for x in range(x0, x0 + ln):
            put(fx, x, y, with_alpha(T3, 0.4 + 0.6 * (x - x0) / ln))
    ik.finish(base, e, fx, "necromancer_lanetli_kafatasi_icon.png")


# ============================================================================================================ YAZ
def save_rows(name, rows, cell):
    w, h = cell
    cols = max(len(r) for r in rows)
    sheet = Image.new("RGBA", (w * cols, h * len(rows)), (0, 0, 0, 0))
    for ri, row in enumerate(rows):
        for ci, f in enumerate(row):
            sheet.paste(f, (ci * w, ri * h), f)
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, name + "_sheet.png"))
    return sheet


def main():
    fly, appear, vanish, shadow = skull_fly(), skull_appear(), skull_vanish(), skull_shadow()
    save_rows("skull", [fly, appear, vanish, shadow], (SK, SK))
    write_sprite_frames(os.path.join(OUT, "skull_frames.tres"), RES + "skull_sheet.png", SK, SK,
                        [("fly", (0, 0), 6, True, 10.0), ("appear", (0, 1), 6, False, 14.0),
                         ("vanish", (0, 2), 7, False, 14.0), ("shadow", (0, 3), 1, True, 1.0)])
    imp = impact_frames()
    save_rows("impact", [imp], (IM, IM))
    write_sprite_frames(os.path.join(OUT, "impact_frames.tres"), RES + "impact_sheet.png", IM, IM,
                        [("play", (0, 0), 9, False, 22.0)])
    summ = summon_frames()
    save_rows("summon", [summ], (SM, SM))
    write_sprite_frames(os.path.join(OUT, "summon_frames.tres"), RES + "summon_sheet.png", SM, SM,
                        [("play", (0, 0), 12, False, 16.0)])
    tr = trail_frames()
    save_rows("trail", [tr], (16, 16))
    write_sprite_frames(os.path.join(OUT, "trail_frames.tres"), RES + "trail_sheet.png", 16, 16,
                        [("play", (0, 0), 5, False, 16.0)])
    fe = fear_frames()
    save_rows("fear", [fe], (16, 16))
    write_sprite_frames(os.path.join(OUT, "fear_frames.tres"), RES + "fear_sheet.png", 16, 16,
                        [("loop", (0, 0), 6, True, 8.0)])
    make_icon()
    if len(sys.argv) > 1:
        bg = (58, 96, 48, 255)
        S = 3
        rows = [fly + appear[:0], appear, vanish, imp[:5], imp[5:], summ[:6], summ[6:], tr + fe]
        width = max(sum(f.width for f in r) for r in rows) * S + 60
        height = sum(max(f.height for f in r) for r in rows) * S + 10 * len(rows) + 10
        prev = Image.new("RGBA", (width, height), bg)
        y = 10
        for r in rows:
            x = 10
            for f in r:
                prev.alpha_composite(f.resize((f.width * S, f.height * S), Image.NEAREST), (x, y))
                x += f.width * S + 4
            y += max(f.height for f in r) * S + 10
        prev.save(sys.argv[1])


if __name__ == "__main__":
    main()
