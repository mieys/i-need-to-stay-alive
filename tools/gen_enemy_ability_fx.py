#!/usr/bin/env python3
"""Yaratik yeteneklerinin (2026-09-24) TUM efektlerini pixel-art spritesheet olarak pisirir.

Kullanici istegi: "Tum bunlar icin ozel pixel art efektler hazirlayip sonrasinda sprite sheete donustur ki performans
kaybi yasamayalim." - hicbiri oyunda _draw()/pixel_draw.gd ile HER KAREDE cizilmez; her biri TEK bir AnimatedSprite2D
(ya da lazer/uyari cizgisi icin tekrarlanan tek bir Sprite2D) olarak oynatilir.
Piksel yogunlugu: oyunun 48x48 dili (bkz. hafiza feedback_pixel_density_48) - 1 sanat pikseli = PixelDraw.TEXEL
(1.212) dunya birimi, 1 px kontur/detay, iri bloklar yok, dama/dither yok (bkz. Korsan "kare kare" sikayeti).

Cikti (assets/fx/enemy_abilities/):
  ghost_sheet.png / ghost_frames.tres            - Hayalet: "vanish" (iceri kivrilan duman, tek sefer) + "appear"
  fireball_sheet.png / fireball_frames.tres      - Iblis ates topu: "fly" (saga bakan, dongu)
  fire_impact_sheet.png / fire_impact_frames.tres - ates topu isabeti: "play" (tek sefer)
  burn_sheet.png / burn_frames.tres              - oyuncu uzerindeki yanma alevleri: "loop"
  laser_warn.png                                 - Rontgen uyari cizgisi karosu (yatay tekrarlanir, kodla kaydirilir)
  laser_beam_0..3.png                            - Rontgen isini karolari (yatay tekrarlanir, kodla sirayla degisir)
  laser_flash_sheet.png / laser_flash_frames.tres - isin agzi + uc parlamasi: "muzzle", "hit" (tek sefer)
  vampire_sheet.png / vampire_frames.tres        - Vampir isinlanma: "blink" (kan sisi + yarasalar, tek sefer)
  zombie_sheet.png / zombie_frames.tres          - Zombi olum patlamasi: "burst" (tek sefer)
  acid_sheet.png / acid_frames.tres              - zehirli asit gol: "intro", "loop", "outro"
  thorns_warn_sheet.png / thorns_warn_frames.tres - Agac dikeni uyarisi: "loop"
  thorns_sheet.png / thorns_frames.tres          - Agac dikenleri: "erupt" (tek sefer)
Yeni PNG'ler icin Godot bir kez import etmeli (editor acilinca kendiliginden yapar ya da `--headless --import`).
Kullanim: python tools/gen_enemy_ability_fx.py [onizleme.png]
"""
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "enemy_abilities")
RES = "res://assets/fx/enemy_abilities/"


def rgba(r, g, b, a=1.0):
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)), int(round(max(0.0, min(1.0, a)) * 255)))


def with_alpha(c, a):
    return (c[0], c[1], c[2], int(round(max(0.0, min(1.0, a)) * c[3])))


def put(im, x, y, c):
    x, y = int(math.floor(x)), int(math.floor(y))
    if not (0 <= x < im.width and 0 <= y < im.height) or c[3] <= 0:
        return
    if c[3] >= 255:
        im.putpixel((x, y), c)
        return
    base = im.getpixel((x, y))
    a = c[3] / 255.0
    ba = base[3] / 255.0
    oa = a + ba * (1 - a)
    if oa <= 0:
        return
    mix = [int(round((c[i] * a + base[i] * ba * (1 - a)) / oa)) for i in range(3)]
    im.putpixel((x, y), (mix[0], mix[1], mix[2], int(round(oa * 255))))


def ease_out(x):
    x = max(0.0, min(1.0, x))
    return 1.0 - (1.0 - x) * (1.0 - x)


def outline_pass(im, color):
    """Opak piksellerin bos komsularina 1 px kontur (sadece tamamen bos pikseller boyanir)."""
    src = im.copy()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if src.getpixel((x, y))[3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src.getpixel((nx, ny))[3] >= 200:
                    im.putpixel((x, y), color)
                    break


def save_sheet(rows, name):
    """rows: [[frame, ...], ...] - her satir bir animasyon, kareler soldan saga. Hepsi ayni hucre boyutunda."""
    w, h = rows[0][0].size
    cols = max(len(r) for r in rows)
    sheet = Image.new("RGBA", (w * cols, h * len(rows)), (0, 0, 0, 0))
    for ri, row in enumerate(rows):
        for ci, f in enumerate(row):
            sheet.paste(f, (ci * w, ri * h), f)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + "_sheet.png")
    sheet.save(path)
    print("wrote", path, sheet.size)
    return w, h


def frames_tres(name, cell, anims):
    """anims: [(anim_name, row, count, loop, fps)]"""
    write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), RES + name + "_sheet.png", cell[0], cell[1],
                        [(a, (0, row), n, loop, fps) for a, row, n, loop, fps in anims])


# ------------------------------------------------------------------------------------------------------ HAYALET
GHOST = [rgba(0.95, 0.97, 1.0), rgba(0.74, 0.8, 1.0), rgba(0.55, 0.52, 0.9), rgba(0.33, 0.26, 0.6)]


def _puff(im, x, y, r, tones, alpha):
    """Iki-uc tonlu kabarik duman topu: ust-sol acik, alt koyu; kenarda duzensiz 1 px girinti."""
    ri = int(math.ceil(r)) + 1
    for dy in range(-ri, ri + 1):
        for dx in range(-ri, ri + 1):
            d2 = dx * dx + dy * dy
            if d2 > r * r:
                continue
            if d2 > (r - 1) ** 2 and (int(x + dx) * 7 + int(y + dy) * 3) % 5 == 0:
                continue
            if dx + dy < -r * 0.45:
                col = tones[0]
            elif dy < r * 0.35:
                col = tones[1]
            else:
                col = tones[2]
            put(im, x + dx, y + dy, with_alpha(col, alpha))


def ghost_frames(appear):
    """Hayaletin kayboluşu ("vanish"): govdenin yerinde 8 soluk-mor duman topu belirir, merkez etrafinda donerek
    yukselir, kuculur ve saydamlasir; arkalarinda ince duman kuyrugu, cevrede sonen yildizciklar. "appear": duman
    toplari disaridan merkeze kivrilarak toplanir, sonunda merkezde bir parlama ve disa acilan ince halka."""
    rnd = random.Random(11 if appear else 7)
    W, H = 64, 76
    cx, cy = W // 2, 46
    puffs = [(i * math.tau / 8 + rnd.uniform(-0.25, 0.25), rnd.uniform(0.55, 1.0), rnd.uniform(3.2, 5.2)) for i in range(8)]
    stars = [(rnd.uniform(-24, 24), rnd.uniform(-34, 12), rnd.random()) for _ in range(12)]
    tones = [GHOST[0], GHOST[1], GHOST[2]]
    n = 12
    out = []
    for fi in range(n):
        t = fi / (n - 1)
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        # u: dumanin "dagilmislik" durumu (0 = govdede toplu, 1 = tamamen dagilmis/yukselmis)
        u = t if not appear else 1.0 - t
        fade = 1.0 - max(0.0, (u - 0.45) / 0.55)
        for base_a, dist, rad in puffs:
            ang = base_a + u * 2.6
            rr = (6 + 18 * ease_out(u)) * dist
            x = cx + math.cos(ang) * rr
            y = cy - 10 + math.sin(ang) * rr * 0.55 - u * 22
            r = rad * (1.0 - 0.55 * u)
            for s_ in range(1, 5):
                u2 = max(0.0, u - s_ * 0.04)
                a2 = base_a + u2 * 2.6
                r2 = (6 + 18 * ease_out(u2)) * dist
                put(im, cx + math.cos(a2) * r2, cy - 10 + math.sin(a2) * r2 * 0.55 - u2 * 22,
                    with_alpha(GHOST[2], fade * (0.8 - s_ * 0.15)))
            if r > 0.6:
                _puff(im, x, y, r, tones, 0.9 * fade)
        outline_pass(im, with_alpha(GHOST[3], 0.75))
        glow = (1.0 - t / 0.25) if (not appear and t < 0.25) else ((t - 0.7) / 0.3 if (appear and t > 0.7) else 0.0)
        if glow > 0:
            r = 2 + int(4 * glow)
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if abs(dx) + abs(dy) <= r:
                        put(im, cx + dx, cy - 12 + dy, with_alpha(GHOST[0] if abs(dx) + abs(dy) < r - 1 else GHOST[1], glow))
        if appear and t > 0.6:
            rr = 4 + 22 * ease_out((t - 0.6) / 0.4)
            segs = int(math.tau * rr)
            for i in range(segs):
                if (i // 3) % 3 == 2:
                    continue
                a = i / segs * math.tau
                put(im, cx + math.cos(a) * rr, cy - 4 + math.sin(a) * rr * 0.5, with_alpha(GHOST[1], 1.0 - (t - 0.6) / 0.4))
        for sx, sy, ph in stars:
            tw = (t * 2.2 + ph) % 1.0
            if tw < 0.55 and fade > 0.1:
                x, y = cx + sx * (0.5 + 0.5 * u), cy - 8 + sy - u * 6
                put(im, x, y, with_alpha(GHOST[0], fade))
                if tw < 0.28:
                    for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        put(im, x + ox, y + oy, with_alpha(GHOST[1], fade * 0.8))
        out.append(im)
    return out


# ------------------------------------------------------------------------------------------------------ ATES
FIRE = [rgba(1.0, 0.98, 0.84), rgba(1.0, 0.86, 0.34), rgba(1.0, 0.6, 0.14), rgba(0.9, 0.28, 0.07), rgba(0.55, 0.1, 0.06)]
FIRE_OUT = rgba(0.3, 0.05, 0.04)


def fire_col(heat):
    """heat 1 = beyaz cekirdek .. 0 = koyu kor."""
    if heat > 0.8:
        return FIRE[0]
    if heat > 0.6:
        return FIRE[1]
    if heat > 0.38:
        return FIRE[2]
    if heat > 0.16:
        return FIRE[3]
    return FIRE[4]


def fireball_frames():
    """Saga bakan ates topu: 5 px yaricapli sert bantli cekirdek + titresen, sola uzanan alev kuyrugu + kopan kivilcimlar."""
    W, H = 30, 20
    cx, cy = 21, 10
    n = 6
    out = []
    for fi in range(n):
        ph = fi / n * math.tau
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        for y in range(H):
            for x in range(W):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                # kuyruk: sola dogru daralan, sinusle titreyen alev dili
                tail = 0.0
                if dx < 0:
                    along = -dx / 17.0
                    if along < 1.0:
                        wob = math.sin(ph + along * 7.0) * 1.6 * along
                        half = 5.2 * (1.0 - along) ** 0.8
                        d = abs(dy - wob)
                        if d < half:
                            tail = (1.0 - d / half) * (1.0 - along) * 0.85
                r = math.hypot(dx, dy)
                core = 1.0 - r / 5.6 if r < 5.6 else 0.0
                heat = max(core * 1.15, tail)
                if heat > 0.02:
                    put(im, x, y, fire_col(heat))
        # kopan kivilcimlar
        rnd = random.Random(fi * 13 + 1)
        for _ in range(3):
            sx = cx - rnd.uniform(8, 17)
            sy = cy + rnd.uniform(-5, 5)
            put(im, sx, sy, FIRE[1] if rnd.random() < 0.5 else FIRE[2])
        outline_pass(im, FIRE_OUT)
        out.append(im)
    return out


def fire_impact_frames():
    """Kucuk ates patlamasi: merkezde parlama, disa acilan 8 alev lobu, ucusan korlar, kararan duman."""
    rnd = random.Random(5)
    W = H = 44
    c = W // 2
    lobes = [(i * math.tau / 8 + rnd.uniform(-0.25, 0.25), rnd.uniform(0.7, 1.0)) for i in range(8)]
    embers = [(rnd.uniform(0, math.tau), rnd.uniform(0.6, 1.2)) for _ in range(12)]
    n = 10
    out = []
    for fi in range(n):
        t = fi / (n - 1)
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        grow = ease_out(t / 0.35)
        cool = max(0.0, (t - 0.25) / 0.75)
        R = 15 * grow
        for y in range(H):
            for x in range(W):
                dx, dy = x + 0.5 - c, y + 0.5 - c
                d = math.hypot(dx, dy)
                ang = math.atan2(dy, dx)
                best = 0.0
                for la, lr in lobes:
                    da = abs((ang - la + math.pi) % math.tau - math.pi)
                    reach = R * lr * (1.0 - da / 1.3) if da < 1.3 else 0.0
                    reach = max(reach, R * 0.55)
                    if d < reach:
                        best = max(best, 1.0 - d / max(reach, 0.1))
                if best <= 0:
                    continue
                heat = best - cool * 0.9
                if heat > 0.05:
                    put(im, x, y, fire_col(heat + 0.1))
                elif cool > 0.3:
                    put(im, x, y, rgba(0.35, 0.3, 0.32, 0.7 * (1.0 - t)))
        for ang, sp in embers:
            dist = 20 * sp * ease_out(t / 0.8)
            if t < 0.85:
                put(im, c + math.cos(ang) * dist, c + math.sin(ang) * dist + t * t * 5, fire_col(0.7 - t * 0.6))
        if t < 0.7:
            outline_pass(im, with_alpha(FIRE_OUT, 1.0 - t))
        out.append(im)
    return out


def burn_frames():
    """Oyuncunun ustunde 3 sn yanan alevler: govdenin alt yarisindan yukselen 5 alev dili (farkli faz/boy) + kopan
    kivilcimlar. 8 kare, kesintisiz dongu (her dilin fazi 2pi/8 adimla ilerler)."""
    W, H = 34, 42
    base_y = 36
    tongues = [(-10, 11, 0.0), (-4, 17, 1.7), (2, 14, 3.1), (8, 18, 4.4), (13, 10, 2.3)]
    n = 8
    out = []
    for fi in range(n):
        ph = fi / n * math.tau
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        for ox, hgt, p0 in tongues:
            h = hgt * (0.8 + 0.2 * math.sin(ph + p0))
            sway = math.sin(ph * 1.0 + p0) * 1.5
            for yy in range(int(h) + 1):
                u = yy / max(h, 1)
                half = 3.4 * (1.0 - u) ** 0.9 + 0.3
                cxx = W / 2 + ox + sway * u
                for xx in range(int(cxx - half - 1), int(cxx + half + 2)):
                    d = abs(xx + 0.5 - cxx)
                    if d <= half:
                        heat = (1.0 - d / half) * 0.6 + (1.0 - u) * 0.45
                        put(im, xx, base_y - yy, fire_col(heat))
        rnd = random.Random(fi * 7 + 3)
        for _ in range(3):
            put(im, rnd.uniform(4, W - 4), rnd.uniform(4, base_y - 16), FIRE[1] if rnd.random() < 0.5 else FIRE[2])
        outline_pass(im, with_alpha(FIRE_OUT, 0.85))
        out.append(im)
    return out


# ------------------------------------------------------------------------------------------------------ RONTGEN LAZERI
LASER = [rgba(1.0, 0.97, 1.0), rgba(0.98, 0.62, 1.0), rgba(0.72, 0.28, 0.95), rgba(0.36, 0.08, 0.52)]


def laser_warn_tile():
    """16x5 karo: ortada 1 px parlak kirmizi kesikli cizgi (10 acik/6 kapali), ust/altta yari saydam kirmizi kenar."""
    im = Image.new("RGBA", (16, 5), (0, 0, 0, 0))
    for x in range(16):
        if x < 10:
            put(im, x, 2, rgba(1.0, 0.32, 0.28))
            put(im, x, 1, rgba(1.0, 0.2, 0.2, 0.45))
            put(im, x, 3, rgba(1.0, 0.2, 0.2, 0.45))
        else:
            put(im, x, 2, rgba(0.7, 0.1, 0.1, 0.35))
    return im


def laser_beam_tiles():
    """4 adet 16x11 karo: 3 px beyaz cekirdek, pembe-mor bantlar, dis kenarda titresen seyrek kivilcim pikselleri."""
    tiles = []
    for fi in range(4):
        rnd = random.Random(40 + fi)
        im = Image.new("RGBA", (16, 11), (0, 0, 0, 0))
        wob = [0, 1, 0, -1][fi]
        for x in range(16):
            for y in range(11):
                d = abs(y - 5)
                if d <= 1:
                    c = LASER[0]
                elif d == 2:
                    c = LASER[1]
                elif d == 3:
                    c = LASER[2] if (x + fi) % 5 else LASER[1]
                elif d == 4:
                    c = with_alpha(LASER[3], 0.85) if ((x * 3 + fi * 5 + y) % 4) else (0, 0, 0, 0)
                else:
                    c = (0, 0, 0, 0)
                if c[3]:
                    put(im, x, y + (wob if d >= 3 else 0), c)
        for _ in range(2):
            put(im, rnd.randrange(16), rnd.choice([0, 1, 9, 10]), LASER[1])
        tiles.append(im)
    return tiles


def laser_flash_frames(kind):
    """"muzzle": isin agzinda 8 kollu yildiz parlamasi + halka. "hit": isin ucunda sacilan mor kivilcimlar."""
    W = H = 28
    c = W // 2
    n = 8
    rnd = random.Random(3 if kind == "muzzle" else 9)
    sparks = [(rnd.uniform(0, math.tau), rnd.uniform(0.5, 1.0)) for _ in range(9)]
    out = []
    for fi in range(n):
        t = fi / (n - 1)
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        k = 1.0 - t
        if kind == "muzzle":
            core = 2 + 3 * k
            for dy in range(-6, 7):
                for dx in range(-6, 7):
                    if abs(dx) + abs(dy) <= core:
                        put(im, c + dx, c + dy, LASER[0] if abs(dx) + abs(dy) < core - 1.5 else LASER[1])
            for kk in range(8):
                ang = kk * math.tau / 8
                ln = (11 if kk % 2 == 0 else 7) * k
                for s_ in range(int(core), int(core + ln)):
                    put(im, c + math.cos(ang) * s_, c + math.sin(ang) * s_, LASER[1] if s_ < core + ln * 0.5 else LASER[2])
            rr = 3 + 10 * ease_out(t)
            for i in range(28):
                a = i / 28 * math.tau
                if i % 3 != 2:
                    put(im, c + math.cos(a) * rr, c + math.sin(a) * rr, with_alpha(LASER[2], k))
        else:
            for ang, sp in sparks:
                dist = 12 * sp * ease_out(t)
                x, y = c + math.cos(ang) * dist, c + math.sin(ang) * dist
                put(im, x, y, LASER[1] if t < 0.5 else LASER[2])
                put(im, x - math.cos(ang), y - math.sin(ang), with_alpha(LASER[2], k))
            if t < 0.5:
                for dy in range(-2, 3):
                    for dx in range(-2, 3):
                        if abs(dx) + abs(dy) <= 2:
                            put(im, c + dx, c + dy, LASER[0])
        out.append(im)
    return out


# ------------------------------------------------------------------------------------------------------ VAMPIR
BLOOD = [rgba(1.0, 0.45, 0.45), rgba(0.82, 0.1, 0.16), rgba(0.52, 0.03, 0.09), rgba(0.26, 0.01, 0.05)]
BAT_BODY = rgba(0.13, 0.05, 0.16)
BAT_WING = rgba(0.24, 0.08, 0.28)


def draw_bat(im, x, y, flap):
    """9x5 (kanat acik) / 9x3 (kanat asagida) piksellik yarasa: koyu mor govde, 2 kulak, 2 kirmizi goz."""
    x, y = int(x), int(y)
    for dx, dy in ((0, 0), (0, 1), (-1, 0), (1, 0), (0, -1)):
        put(im, x + dx, y + dy, BAT_BODY)
    put(im, x - 1, y - 2, BAT_BODY)
    put(im, x + 1, y - 2, BAT_BODY)
    put(im, x - 1, y - 1, rgba(1.0, 0.25, 0.25))
    put(im, x + 1, y - 1, rgba(1.0, 0.25, 0.25))
    if flap:
        wing = [(-2, -1), (-3, -2), (-4, -2), (-4, -1), (-3, -1), (-2, 0),
                (2, -1), (3, -2), (4, -2), (4, -1), (3, -1), (2, 0)]
    else:
        wing = [(-2, 0), (-3, 1), (-4, 1), (-3, 0), (2, 0), (3, 1), (4, 1), (3, 0)]
    for dx, dy in wing:
        put(im, x + dx, y + dy, BAT_WING)


def vampire_frames():
    """Vampirin isinlanmasi: govde bir an kan kirmizisi parlar, etrafinda 10 duzensiz kan sisi topu disa savrulup
    yukselir ve saydamlasir (ustleri acik, altlari koyu), 6 yarasa kanat cirparak disa dagilir, yere birkac damla duser."""
    rnd = random.Random(21)
    W = H = 72
    c = W // 2
    puffs = [(rnd.uniform(0, math.tau), rnd.uniform(0.3, 1.0), rnd.uniform(3.0, 5.0)) for _ in range(10)]
    bats = [(i * math.tau / 6 + rnd.uniform(-0.3, 0.3), rnd.uniform(0.8, 1.1)) for i in range(6)]
    drops = [(rnd.uniform(-14, 14), rnd.uniform(4, 12)) for _ in range(6)]
    tones = [BLOOD[0], BLOOD[1], BLOOD[2]]
    n = 12
    out = []
    for fi in range(n):
        t = fi / (n - 1)
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        spread = ease_out(t / 0.75)
        fade = 1.0 - max(0.0, (t - 0.45) / 0.55)
        for ang, dist, rad in puffs:
            x = c + math.cos(ang) * dist * 24 * spread
            y = c + math.sin(ang) * dist * 14 * spread - t * 8
            r = rad * (0.5 + 0.7 * spread) * (1.0 - 0.45 * t)
            if r > 0.6:
                _puff(im, x, y, r, tones, 0.88 * fade)
        outline_pass(im, with_alpha(BLOOD[3], 0.8 * fade))
        if t < 0.2:
            k = 1.0 - t / 0.2
            r = int(3 + 6 * k)
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if abs(dx) + abs(dy) <= r:
                        put(im, c + dx, c + dy, BLOOD[0] if abs(dx) + abs(dy) < r - 2 else BLOOD[1])
        for ang, sp in bats:
            if t < 0.08:
                continue
            d = 32 * sp * ease_out((t - 0.08) / 0.9)
            draw_bat(im, c + math.cos(ang) * d, c + math.sin(ang) * d * 0.7 - t * 12, fi % 2 == 0)
        for dx, dy in drops:
            if 0.2 < t < 0.95:
                u = (t - 0.2) / 0.75
                put(im, c + dx, c + dy * u + 6, with_alpha(BLOOD[1], 1.0 - u))
                put(im, c + dx, c + dy * u + 5, with_alpha(BLOOD[0], 1.0 - u))
        out.append(im)
    return out


# ------------------------------------------------------------------------------------------------------ ZOMBI / ASIT
ACID = [rgba(0.86, 1.0, 0.6), rgba(0.56, 0.95, 0.24), rgba(0.3, 0.7, 0.14), rgba(0.14, 0.38, 0.08), rgba(0.07, 0.2, 0.05)]


def zombie_burst_frames():
    """Zombinin olum patlamasi: yesil irin balonu sisip titrer, yildiz bicimli bir sicrama ile patlar, irin yere yayilan
    duzensiz bir lekeye doner (asit golunun basladigi yer), 14 damla yay cizerek disa savrulup yere carpar."""
    rnd = random.Random(33)
    W = H = 64
    c = W // 2
    gy = c + 6
    drops = [(rnd.uniform(0, math.tau), rnd.uniform(0.6, 1.1), rnd.choice([1, 2, 2])) for _ in range(14)]
    spikes = [(i * math.tau / 9 + rnd.uniform(-0.2, 0.2), rnd.uniform(0.7, 1.0)) for i in range(9)]
    n = 10
    out = []
    for fi in range(n):
        t = fi / (n - 1)
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        if t < 0.25:
            r = 5 + 5 * (t / 0.25) + (1 if fi % 2 else 0)
            for dy in range(-int(r) - 1, int(r) + 2):
                for dx in range(-int(r) - 1, int(r) + 2):
                    d2 = dx * dx + dy * dy
                    if d2 <= r * r:
                        col = ACID[0] if (dx + dy) < -r * 0.6 else (ACID[1] if d2 < (r * 0.65) ** 2 else ACID[2])
                        put(im, c + dx, gy - 6 + dy, col)
        else:
            u = (t - 0.25) / 0.75
            if u < 0.45:
                k = u / 0.45
                R = 8 + 10 * ease_out(k)
                for y in range(-22, 23):
                    for x in range(-24, 25):
                        d = math.hypot(x, y * 1.4)
                        ang = math.atan2(y * 1.4, x)
                        reach = R * 0.55
                        for sa, sl in spikes:
                            da = abs((ang - sa + math.pi) % math.tau - math.pi)
                            if da < 0.35:
                                reach = max(reach, R * sl * (1.0 - da / 0.35))
                        if d < reach:
                            col = ACID[1] if d < reach * 0.6 else ACID[2]
                            put(im, c + x, gy - 4 + y, with_alpha(col, 1.0 - k * 0.3))
            sp = ease_out(u / 0.6)
            rx, ry = 6 + 16 * sp, 3 + 7 * sp
            for y in range(-int(ry) - 1, int(ry) + 2):
                for x in range(-int(rx) - 1, int(rx) + 2):
                    ang = math.atan2(y, x)
                    wob = 1.0 + 0.12 * math.sin(ang * 5 + 1.0)
                    e = (x / (rx * wob)) ** 2 + (y / (ry * wob)) ** 2
                    if e <= 1.0:
                        col = ACID[2] if e > 0.55 else ACID[1]
                        put(im, c + x, gy + y, with_alpha(col, 0.9 - max(0.0, u - 0.7) * 2.5))
            for ang, spd, sz in drops:
                k = min(1.0, u / 0.7)
                dist = 26 * spd * ease_out(k)
                lift = math.sin(k * math.pi) * 14 * spd
                x = c + math.cos(ang) * dist
                y = gy + math.sin(ang) * dist * 0.45 - lift
                if k < 1.0:
                    for oy in range(sz):
                        for ox in range(sz):
                            put(im, x + ox, y + oy, ACID[1] if oy == 0 else ACID[2])
                else:
                    put(im, x, y, with_alpha(ACID[2], 1.0 - (u - 0.7) / 0.3))
                    put(im, x + 1, y, with_alpha(ACID[2], 1.0 - (u - 0.7) / 0.3))
        outline_pass(im, with_alpha(ACID[4], 0.9))
        out.append(im)
    return out


ACID_RX, ACID_RY = 34, 16


def acid_frame(scale, bubbles_phase, alpha, rnd_seed):
    W, H = 80, 44
    cx, cy = W // 2, H // 2
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rnd = random.Random(rnd_seed)
    rx, ry = ACID_RX * scale, ACID_RY * scale
    if rx < 1:
        return im
    # duzensiz kenar: aciya gore sabit (her karede ayni) dalgalanma
    for y in range(H):
        for x in range(W):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            ang = math.atan2(dy, dx)
            wob = 1.0 + 0.08 * math.sin(ang * 5 + 0.6) + 0.05 * math.sin(ang * 9 + 2.0)
            e = (dx / (rx * wob)) ** 2 + (dy / (ry * wob)) ** 2
            if e > 1.0:
                continue
            if e > 0.8:
                col = ACID[3]
            elif e > 0.45:
                col = ACID[2]
            else:
                col = ACID[1] if (dy < -ry * 0.1 or e > 0.2) else ACID[2]
            put(im, x, y, with_alpha(col, alpha * (0.78 if e > 0.8 else 0.72)))
    # parlak yuzey yansimalari (sabit)
    for sx, sy, ln in ((-12, -6, 6), (6, -3, 4), (-2, 4, 3)):
        for i in range(ln):
            put(im, cx + sx * scale + i, cy + sy * scale, with_alpha(ACID[0], alpha * 0.8))
    # kabarciklar: 6 kabarcik, her biri kendi fazinda buyuyup patlar (dongu)
    for i in range(6):
        bx = cx + (rnd.uniform(-0.7, 0.7)) * rx
        by = cy + (rnd.uniform(-0.55, 0.55)) * ry
        ph = (bubbles_phase + i / 6.0) % 1.0
        if ph < 0.7:
            r = 0.6 + 2.2 * (ph / 0.7)
            for a in range(10):
                an = a / 10 * math.tau
                put(im, bx + math.cos(an) * r, by + math.sin(an) * r, with_alpha(ACID[0], alpha))
            put(im, bx - r * 0.4, by - r * 0.4, with_alpha(rgba(1, 1, 1), alpha))
        elif ph < 0.85:
            for ox, oy in ((-2, -1), (2, -1), (0, -2), (-1, 1), (1, 1)):
                put(im, bx + ox, by + oy, with_alpha(ACID[0], alpha * 0.9))
    return im


def acid_frames():
    intro = [acid_frame(ease_out((i + 1) / 6), 0.0, 1.0, 77) for i in range(6)]
    loop = [acid_frame(1.0, i / 8.0, 1.0, 77) for i in range(8)]
    outro = [acid_frame(1.0 - 0.35 * (i / 5), 0.0, 1.0 - i / 5.5, 77) for i in range(6)]
    return intro, loop, outro


# ------------------------------------------------------------------------------------------------------ AGAC DIKENLERI
BARK = [rgba(0.86, 0.68, 0.42), rgba(0.62, 0.42, 0.22), rgba(0.42, 0.26, 0.12), rgba(0.2, 0.11, 0.05)]
MOSS = rgba(0.45, 0.62, 0.22)
WARN = [rgba(1.0, 0.36, 0.22), rgba(0.85, 0.16, 0.1), rgba(0.45, 0.06, 0.04)]
DIRT = [rgba(0.55, 0.42, 0.28), rgba(0.36, 0.26, 0.16)]


def thorns_warn_frames():
    """Diken uyarisi (zeminde, basik elips): nabiz gibi kalinlasan kirmizi dis halka, iceride donen kesikli halka,
    merkezden disa uzanan 6 yer catlagi ve zipplayan toprak kirintilari. 10 kare dongu."""
    W, H = 64, 36
    cx, cy = W // 2, H // 2
    RX, RY = 27, 13
    rnd = random.Random(8)
    cracks = []
    for i in range(6):
        a = i * math.tau / 6 + rnd.uniform(-0.3, 0.3)
        pts = [(0.0, 0.0)]
        for s in range(1, 5):
            r = s / 4 * 0.85
            a2 = a + rnd.uniform(-0.25, 0.25)
            pts.append((math.cos(a2) * r, math.sin(a2) * r))
        cracks.append(pts)
    specks = [(rnd.uniform(-0.8, 0.8), rnd.uniform(-0.7, 0.7), rnd.random()) for _ in range(9)]
    n = 10
    out = []
    for fi in range(n):
        ph = fi / n
        pulse = 0.5 + 0.5 * math.sin(ph * math.tau)
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        # hafif kirmizi zemin
        for y in range(H):
            for x in range(W):
                e = ((x + 0.5 - cx) / RX) ** 2 + ((y + 0.5 - cy) / RY) ** 2
                if e <= 1.0:
                    put(im, x, y, with_alpha(WARN[1], 0.14 + 0.1 * pulse))
        # catlaklar
        for pts in cracks:
            for i in range(len(pts) - 1):
                x0, y0 = pts[i]
                x1, y1 = pts[i + 1]
                steps = 8
                for s in range(steps):
                    f = s / steps
                    x = cx + (x0 + (x1 - x0) * f) * RX
                    y = cy + (y0 + (y1 - y0) * f) * RY
                    put(im, x, y, with_alpha(WARN[2], 0.9))
        # dis halka (kalinlik nabizla 1-2 px)
        segs = int(math.tau * RX)
        for i in range(segs):
            a = i / segs * math.tau
            x, y = cx + math.cos(a) * RX, cy + math.sin(a) * RY
            put(im, x, y, WARN[0] if pulse > 0.4 else WARN[1])
            if pulse > 0.55:
                put(im, cx + math.cos(a) * (RX - 1), cy + math.sin(a) * (RY - 1), with_alpha(WARN[1], 0.8))
        # donen kesikli ic halka
        rx2, ry2 = RX * 0.6, RY * 0.6
        segs2 = int(math.tau * rx2)
        for i in range(segs2):
            if ((i + fi * 2) // 3) % 2:
                continue
            a = i / segs2 * math.tau
            put(im, cx + math.cos(a) * rx2, cy + math.sin(a) * ry2, with_alpha(WARN[0], 0.85))
        # toprak kirintilari
        for sx, sy, p0 in specks:
            hop = abs(math.sin((ph + p0) * math.tau)) * 3
            put(im, cx + sx * RX, cy + sy * RY - hop, DIRT[0])
        out.append(im)
    return out


def draw_spike(im, bx, by, width, height, lean):
    """Yerden cikan tek diken: asagida genis, uca dogru incelen agac kabugu; sol yari acik, sag yari koyu, ucu acik,
    1 px koyu kontur (sonra outline_pass), gövdede 1-2 yosun lekesi."""
    h = int(round(height))
    if h <= 0:
        return
    for yy in range(h):
        u = yy / max(h - 1, 1)
        half = width / 2 * (1.0 - u) ** 0.85
        cxx = bx + lean * u * height * 0.35
        for xx in range(int(cxx - half - 1), int(cxx + half + 2)):
            d = xx + 0.5 - cxx
            if abs(d) <= half + 0.01:
                if u > 0.82:
                    col = BARK[0]
                elif d < -half * 0.2:
                    col = BARK[1]
                elif d < half * 0.45:
                    col = BARK[2]
                else:
                    col = BARK[3]
                put(im, xx, by - yy, col)
    if h > 10:
        put(im, bx - 1, by - int(h * 0.3), MOSS)
        put(im, bx, by - int(h * 0.3) - 1, MOSS)


def thorns_frames():
    """Diken patlamasi: once zeminde toprak kabarir (2 kare), 7 diken hizla yerden firlar (dis ikisi yana egik), kisa bir
    sure dikilir, sonra toprak tozuyla birlikte geri gomulur. Tek sefer, 14 kare."""
    W, H = 72, 84
    cx, gy = W // 2, 66  # zemin merkezi
    rnd = random.Random(19)
    spikes = []
    for i in range(7):
        ang = i / 7 * math.tau + rnd.uniform(-0.3, 0.3)
        rr = 0.0 if i == 0 else rnd.uniform(0.35, 0.95)
        ox = math.cos(ang) * 26 * rr
        oy = math.sin(ang) * 11 * rr
        hgt = rnd.uniform(28, 38) if i == 0 else rnd.uniform(16, 28)
        wid = rnd.uniform(9.0, 10.5) if i == 0 else rnd.uniform(6.5, 8.5)
        lean = (ox / 26.0) * 0.8
        spikes.append((ox, oy, hgt, wid, lean, rnd.uniform(0, 0.12)))
    spikes.sort(key=lambda s: s[1])  # arkadakiler once cizilir
    dust = [(rnd.uniform(-28, 28), rnd.uniform(-9, 9), rnd.uniform(0.5, 1.0)) for _ in range(18)]
    n = 14
    out = []
    for fi in range(n):
        t = fi / (n - 1)
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        # toprak catlagi / kabarma
        mound = min(1.0, t / 0.12) * (1.0 - max(0.0, (t - 0.8) / 0.2))
        for y in range(-12, 13):
            for x in range(-30, 31):
                e = (x / 30.0) ** 2 + (y / 12.0) ** 2
                if e <= 1.0 and mound > 0:
                    put(im, cx + x, gy + y, with_alpha(DIRT[1], 0.55 * mound * (1.0 - e * 0.6)))
        # dikenler
        for ox, oy, hgt, wid, lean, delay in spikes:
            if t < 0.12 + delay:
                continue
            up = ease_out((t - 0.12 - delay) / 0.12)
            down = max(0.0, (t - 0.7) / 0.3)
            height = hgt * up * (1.0 - down)
            draw_spike(im, cx + ox, gy + oy, wid, height, lean)
        outline_pass(im, BARK[3])
        # toz / toprak kirintilari (konturdan sonra - konturlanmasin)
        if 0.1 < t < 0.95:
            u = (t - 0.1) / 0.85
            for sx, sy, sp in dust:
                lift = math.sin(min(1.0, u * 1.4) * math.pi) * 9 * sp
                put(im, cx + sx * (0.6 + 0.6 * u), gy + sy - lift, with_alpha(DIRT[0], 1.0 - u))
        out.append(im)
    return out


# ------------------------------------------------------------------------------------------------------ ANA
def main():
    os.makedirs(OUT, exist_ok=True)
    preview = []

    vanish, appear = ghost_frames(False), ghost_frames(True)
    cell = save_sheet([vanish, appear], "ghost")
    frames_tres("ghost", cell, [("vanish", 0, len(vanish), False, 20.0), ("appear", 1, len(appear), False, 20.0)])
    preview += [vanish, appear]

    fb = fireball_frames()
    cell = save_sheet([fb], "fireball")
    frames_tres("fireball", cell, [("fly", 0, len(fb), True, 14.0)])
    preview.append(fb)

    fi = fire_impact_frames()
    cell = save_sheet([fi], "fire_impact")
    frames_tres("fire_impact", cell, [("play", 0, len(fi), False, 22.0)])
    preview.append(fi)

    bf = burn_frames()
    cell = save_sheet([bf], "burn")
    frames_tres("burn", cell, [("loop", 0, len(bf), True, 12.0)])
    preview.append(bf)

    laser_warn_tile().save(os.path.join(OUT, "laser_warn.png"))
    tiles = laser_beam_tiles()
    for i, tile in enumerate(tiles):
        tile.save(os.path.join(OUT, "laser_beam_%d.png" % i))
    print("wrote laser tiles")
    preview.append([laser_warn_tile()] + tiles)
    mz, ht = laser_flash_frames("muzzle"), laser_flash_frames("hit")
    cell = save_sheet([mz, ht], "laser_flash")
    frames_tres("laser_flash", cell, [("muzzle", 0, len(mz), False, 24.0), ("hit", 1, len(ht), False, 24.0)])
    preview += [mz, ht]

    vb = vampire_frames()
    cell = save_sheet([vb], "vampire")
    frames_tres("vampire", cell, [("blink", 0, len(vb), False, 20.0)])
    preview.append(vb)

    zb = zombie_burst_frames()
    cell = save_sheet([zb], "zombie")
    frames_tres("zombie", cell, [("burst", 0, len(zb), False, 20.0)])
    preview.append(zb)

    intro, loop, outro = acid_frames()
    cell = save_sheet([intro, loop, outro], "acid")
    frames_tres("acid", cell, [("intro", 0, len(intro), False, 20.0), ("loop", 1, len(loop), True, 8.0),
                               ("outro", 2, len(outro), False, 16.0)])
    preview += [intro, loop, outro]

    tw = thorns_warn_frames()
    cell = save_sheet([tw], "thorns_warn")
    frames_tres("thorns_warn", cell, [("loop", 0, len(tw), True, 12.0)])
    preview.append(tw)

    th = thorns_frames()
    cell = save_sheet([th], "thorns")
    frames_tres("thorns", cell, [("erupt", 0, len(th), False, 16.0)])
    preview.append(th)

    if len(sys.argv) > 1:
        S = 4
        rows_h = [max(f.size[1] for f in row) * S + 6 for row in preview]
        width = max(sum(f.size[0] * S + 4 for f in row) for row in preview) + 8
        sheet = Image.new("RGBA", (width, sum(rows_h) + 8), (58, 72, 52, 255))
        y = 4
        for row, rh in zip(preview, rows_h):
            x = 4
            for f in row:
                big = f.resize((f.size[0] * S, f.size[1] * S), Image.NEAREST)
                sheet.alpha_composite(big, (x, y))
                x += f.size[0] * S + 4
            y += rh
        sheet.save(sys.argv[1])
        print("preview ->", sys.argv[1])


if __name__ == "__main__":
    main()
