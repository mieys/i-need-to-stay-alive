#!/usr/bin/env python3
"""Korsan'in TUM yetenek efektlerini pixel-art spritesheet olarak pisirir.

Kullanici istegi (2026-09-24): "korsanin patlama yetenegini 48x48 pixel art olarak yeniden tasarla ve spritesheete
donustur pixeldraw olarak kalmasin fpsi cok dusuruyor diger yeteneklerinin de spritesheet oldugundan emin ol."
"48x48" = oyunun piksel YOGUNLUGU (karakterler 48x48 sanat pikseli; bkz. hafiza feedback_pixel_density_48): 1 sanat
pikseli = PixelDraw.TEXEL (1.212) dunya birimi, 1 px kontur/detay, iri 2-3 px bloklar yok. Eskiden bu efektlerin hepsi
HER KAREDE pixel_draw.gd ile yuzlerce/binlerce draw_rect cagrisiyla ciziliyordu (patlama tek basina 4 buyuk dolu disk +
yanik izi diskleri + duman diskleri); artik oyunda her biri TEK bir AnimatedSprite2D.

Cikti (assets/fx/korsan/):
  explosion_big_sheet.png / explosion_big_frames.tres    - bomba patlamasi (R0 = 150 dunya birimi), "play" tek sefer
  explosion_small_sheet.png / explosion_small_frames.tres - Bombardiman mermisi patlamasi (R0 = 68), "play" tek sefer
  bomb_sheet.png / bomb_frames.tres                       - "drop" (dusup sekme, tek sefer) + "idle" (fitil + goz, dongu)
  strike_sheet.png / strike_frames.tres                   - Bombardiman mermisi: daralan hedef halkasi + dusen gulle
  zone_sheet.png / zone_frames.tres                       - Bombardiman alani (R = 380), yuruyen kesikli halka dongusu
  puff_dust / puff_spark / puff_smoke (sheet + frames)    - bomba birakma tozu / detonator kivilcimi / kanal dumani
Yeni PNG'ler icin Godot'ta bir kez `--headless --import` gerekir.
"""
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "korsan")
TEXEL = 1.212  # PixelDraw.TEXEL - 1 sanat pikseli = bu kadar dunya birimi

BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def rgba(r, g, b, a=1.0):
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)), int(round(a * 255)))


def put(im, x, y, c):
    x, y = int(x), int(y)
    if 0 <= x < im.width and 0 <= y < im.height and c[3] > 0:
        if c[3] >= 255:
            im.putpixel((x, y), c)
        else:
            base = im.getpixel((x, y))
            a = c[3] / 255.0
            ba = base[3] / 255.0
            oa = a + ba * (1 - a)
            if oa <= 0:
                return
            mix = [int(round((c[i] * a + base[i] * ba * (1 - a)) / oa)) for i in range(3)]
            im.putpixel((x, y), (mix[0], mix[1], mix[2], int(round(oa * 255))))


def disc(im, cx, cy, r, c):
    ri = int(math.ceil(r))
    for dy in range(-ri, ri + 1):
        for dx in range(-ri, ri + 1):
            if dx * dx + dy * dy <= r * r:
                put(im, cx + dx, cy + dy, c)


def save_sheet(frames, name):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0), f)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + "_sheet.png")
    sheet.save(path)
    print("wrote", path, sheet.size)
    return w, h


FIRE = [rgba(1.0, 0.98, 0.84), rgba(1.0, 0.86, 0.34), rgba(1.0, 0.6, 0.14), rgba(0.9, 0.28, 0.07), rgba(0.55, 0.1, 0.06)]
OUTLINE_FIRE = rgba(0.3, 0.05, 0.04)


def fire_at(t):
    """0 = beyaz cekirdek .. 1 = koyu kor."""
    t = max(0.0, min(0.999, t))
    return FIRE[int(t * len(FIRE))]


def ease_out(x):
    x = max(0.0, min(1.0, x))
    return 1.0 - (1.0 - x) * (1.0 - x)


# ---------------------------------------------------------------------------------------------------------- patlama
def explosion_frames(R, frames, seed):
    """R: sanat pikseli cinsinden patlama yaricapi.
    Tasarim (klasik pixel-art patlama dili): ates bulutu, merkeze yakin 7-8 daire "lob"un BIRLESIMI - her piksel icin
    en sicak lobun "isi"si (1 - uzaklik/yaricap) hesaplanir ve SERT renk bantlarina (beyaz-sari-turuncu-kirmizi, dither
    YOK) ayrilir, disina 1 px koyu kor kontur. Zamanla esikler soguk tarafa kayar (ates kizarir), sonra AYNI loblar gri
    iki tonlu (ustte acik) bir duman bulutuna donusup yukselir ve adim adim saydamlasir. Ilk karelerde yildiz bicimli
    parlama, disa acilan ince kesikli sok halkasi, ucusan korlar; zeminde duzensiz yanik izi (sadece alfa ile solar -
    dama/dither YOK, bkz. 2026-09-22 "kare kare" sikayeti)."""
    rnd = random.Random(seed)
    size = int(R * 2 + 12)
    c = size // 2
    life = 1.0
    lobes = [(0.0, 0.0, 0.62)]
    for i in range(7):
        a = i * math.tau / 7 + rnd.uniform(-0.3, 0.3)
        d = rnd.uniform(0.28, 0.46)
        lobes.append((math.cos(a) * d, math.sin(a) * d * 0.85, rnd.uniform(0.3, 0.44)))
    debris = [(rnd.uniform(0, math.tau), rnd.uniform(0.55, 1.15), rnd.choice([1, 1, 2]), rnd.random()) for _ in range(22)]
    scorch = [(rnd.uniform(-0.2, 0.2), rnd.uniform(-0.1, 0.1), rnd.uniform(0.3, 0.46)) for _ in range(6)]
    ## Duman: acik tonlu ve (2026-09-24 ekran goruntusu) ates topundan KUCUK - yukselirken buzulerek dagilir, erken
    ## saydamlasir (eski hali ekrani kaplayan koyu, opak bir kaya gibi duruyordu).
    SMOKE = [rgba(0.66, 0.64, 0.68), rgba(0.5, 0.49, 0.53), rgba(0.38, 0.37, 0.41)]

    out = []
    for fi in range(frames):
        t = fi / (frames - 1) * life
        im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        # 1) yanik izi (zemin): duz alfa, son %40'ta alfa ile solar
        sg = ease_out(t / 0.15)
        sf = 1.0 - max(0.0, (t - 0.6) / 0.4)
        if sf > 0 and sg > 0:
            a_sc = 0.4 * sf
            ri = int(R * 0.75) + 2
            for dy in range(-ri, ri + 1):
                for dx in range(-ri, ri + 1):
                    inside = False
                    for ox, oy, rr in scorch:
                        rs = rr * R * sg
                        if ((dx - ox * R * sg) / max(rs, 1)) ** 2 + ((dy - oy * R * sg) / max(rs * 0.6, 1)) ** 2 <= 1.0:
                            inside = True
                            break
                    if inside:
                        put(im, c + dx, c + dy + int(R * 0.1), rgba(0.06, 0.04, 0.04, a_sc))
        # 2) parlama: yildiz bicimli cekirdek + 4 uzun, 4 kisa isin
        if t < 0.12:
            k = 1.0 - t / 0.12
            core = R * (0.2 + 0.1 * k)
            for dy in range(-int(core) - 1, int(core) + 2):
                for dx in range(-int(core) - 1, int(core) + 2):
                    if abs(dx) + abs(dy) <= core * 1.25 and dx * dx + dy * dy <= core * core * 1.1:
                        put(im, c + dx, c + dy, FIRE[0] if abs(dx) + abs(dy) < core * 0.8 else FIRE[1])
            for kk in range(8):
                ang = kk * math.tau / 8
                ln = R * (0.62 if kk % 2 == 0 else 0.4) * (0.6 + 0.4 * k)
                for s_ in range(int(core), int(ln)):
                    x, y = c + math.cos(ang) * s_, c + math.sin(ang) * s_
                    put(im, x, y, FIRE[0] if s_ < ln * 0.6 else FIRE[1])
                    if kk % 2 == 0 and s_ < ln * 0.5:
                        put(im, x + round(-math.sin(ang)), y + round(math.cos(ang)), FIRE[1])
        # 3) ates -> duman bulutu (lob birlesimi)
        grow = ease_out(t / 0.22)
        cool = max(0.0, min(1.0, (t - 0.18) / 0.42))
        rise = max(0.0, t - 0.35) * R * 0.7
        swell = 1.0 - max(0.0, t - 0.45) * 0.9
        smoke_alpha = 0.8 if t < 0.6 else (0.58 if t < 0.72 else (0.38 if t < 0.84 else 0.18))
        scale = R * 0.62 * grow * swell
        if scale > 1.5:
            ri = int(scale * 1.25) + 3
            for dy in range(-ri, ri + 1):
                for dx in range(-ri, ri + 1):
                    heat = -1.0
                    rel_y = 0.0  # en sicak lobun merkezine gore dikey konum (-1 ust .. +1 alt) - dumanda lob basina isik
                    for lx, ly, lr in lobes:
                        rr = lr * scale
                        d = math.hypot(dx - lx * scale, dy - ly * scale)
                        hv = 1.0 - d / max(rr, 0.5)
                        if hv > heat:
                            heat = hv
                            rel_y = (dy - ly * scale) / max(rr, 0.5)
                    x, y = c + dx, c + dy - int(rise)
                    if heat < -0.07:
                        continue
                    if heat < 0.0:
                        if cool < 0.55:
                            put(im, x, y, OUTLINE_FIRE)
                        else:
                            put(im, x, y, rgba(0.27, 0.26, 0.3, smoke_alpha))
                        continue
                    h = heat - cool * 1.1
                    if cool < 0.55 and h > -0.35:
                        if h > 0.62:
                            col = FIRE[0]
                        elif h > 0.4:
                            col = FIRE[1]
                        elif h > 0.18:
                            col = FIRE[2]
                        elif h > -0.05:
                            col = FIRE[3]
                        else:
                            col = FIRE[4]
                        put(im, x, y, col)
                    else:
                        # her lobun ust-sol kismi acik, alt kismi koyu: kabarik "cumulus" puflari
                        if rel_y < -0.35 and heat > 0.18:
                            sc = SMOKE[0]
                        elif rel_y < 0.35 or heat > 0.45:
                            sc = SMOKE[1]
                        else:
                            sc = SMOKE[2]
                        put(im, x, y, (sc[0], sc[1], sc[2], int(255 * smoke_alpha)))
            if cool < 0.4:
                for lx, ly, lr in lobes[1:]:
                    ang = math.atan2(ly, lx)
                    base = math.hypot(lx, ly) * scale + lr * scale
                    for s_ in range(3):
                        put(im, c + math.cos(ang) * (base + s_), c + math.sin(ang) * (base + s_) - int(rise), FIRE[3] if s_ < 2 else FIRE[4])
        # 4) sok halkasi: ince, kesikli, disa acilir ve kararir
        rk = t / 0.42
        if rk < 1.0:
            rr = R * ease_out(rk)
            n_seg = max(24, int(math.tau * rr))
            col = fire_at(0.1 + rk * 0.8)
            for i in range(n_seg):
                if (i // 5) % 3 == 2:
                    continue
                a = i / n_seg * math.tau
                put(im, c + math.cos(a) * rr, c + math.sin(a) * rr, col)
                if rk < 0.4:
                    put(im, c + math.cos(a) * (rr - 1), c + math.sin(a) * (rr - 1), col)
        # 5) korlar: disa ucar, yavaslar, hafif duser, kararir
        dk = t / 0.62
        if dk < 1.0:
            for ang, sp, sz, ct in debris:
                dist = R * sp * (0.15 + 0.9 * ease_out(dk))
                x = c + math.cos(ang) * dist
                y = c + math.sin(ang) * dist + (dk ** 2) * R * 0.14
                col = fire_at(0.05 + dk * 0.85 + ct * 0.1)
                s2 = sz if dk < 0.6 else 1
                for oy in range(s2):
                    for ox in range(s2):
                        put(im, x + ox, y + oy, col)
        out.append(im)
    return out


# ---------------------------------------------------------------------------------------------------------- bomba
BOMB_ART = [
    "....cccc....",
    "...occcco...",
    "..oddddddo..",
    ".oddmmmmddo.",
    ".odmhhmmmdo.",
    "odmhmmmmmmdo",
    "odmmwwwwmmdo",
    "odmmwowowmdo",
    "odmmmwwwmmdo",
    ".odmmmmmmdo.",
    ".oddmmmmddo.",
    "..ooddddoo..",
    "....oooo....",
]
BOMB_PAL = {
    "o": rgba(0.05, 0.05, 0.09), "d": rgba(0.14, 0.14, 0.2), "m": rgba(0.26, 0.26, 0.35),
    "h": rgba(0.62, 0.62, 0.75), "w": rgba(0.93, 0.9, 0.84), "c": rgba(0.42, 0.37, 0.3),
}


def bomb_frame(lift_art, spark_phase, blink):
    W, H = 24, 48
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ground = H - 8  # bomba merkezi (lift=0) bu satirda
    # golge: yukseldikce kuculur (PixelDraw.ground_shadow ile ayni dil)
    shrink = 1.0 - min(0.4, lift_art / 40.0)
    rx, ry = 6 * shrink, 2.1 * shrink
    for dy in range(-3, 4):
        for dx in range(-8, 9):
            if (dx / max(rx, 0.5)) ** 2 + (dy / max(ry, 0.5)) ** 2 <= 1.0:
                core = (dx / max(rx * 0.6, 0.5)) ** 2 + (dy / max(ry * 0.6, 0.5)) ** 2 <= 1.0
                put(im, W // 2 + dx, ground + 6 + dy, rgba(0, 0, 0, 0.36 if core else 0.25))
    cx = W // 2 - 6
    cy = ground - 6 - int(round(lift_art)) - 1
    for y, row in enumerate(BOMB_ART):
        for x, ch in enumerate(row):
            if ch in BOMB_PAL:
                put(im, cx + x, cy + y, BOMB_PAL[ch])
    if blink:
        put(im, cx + 5, cy + 7, rgba(1.0, 0.18, 0.1))
        put(im, cx + 7, cy + 7, rgba(1.0, 0.18, 0.1))
    # fitil: baslikdan saga-yukari kivrilan 5 piksel + titresen kivilcim
    top = (cx + 6, cy - 1)
    for fx, fy in ((1, -1), (2, -2), (2, -3), (3, -4), (4, -4)):
        put(im, top[0] + fx, top[1] + fy, rgba(0.56, 0.36, 0.16))
    tx, ty = top[0] + 4, top[1] - 5
    if spark_phase == 0:
        put(im, tx, ty, rgba(1.0, 0.98, 0.8))
        for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            put(im, tx + ox, ty + oy, rgba(1.0, 0.8, 0.25))
    elif spark_phase == 1:
        put(im, tx, ty, rgba(1.0, 0.9, 0.5))
        for ox, oy in ((1, 1), (-1, -1), (1, -1), (-1, 1)):
            put(im, tx + ox, ty + oy, rgba(1.0, 0.5, 0.12))
    else:
        put(im, tx, ty, rgba(1.0, 0.65, 0.15))
        put(im, tx + 1, ty, rgba(1.0, 0.65, 0.15))
        put(im, tx, ty - 2, rgba(1.0, 0.9, 0.4))
    return im


def bomb_frames():
    drop_time, bounce_time = 0.28, 0.16
    drop = []
    n_drop = 7
    for i in range(n_drop):
        life = i / (n_drop - 1) * (drop_time + bounce_time)
        if life < drop_time:
            k = 1.0 - life / drop_time
            lift = k * k * 34.0
        else:
            b = (life - drop_time) / bounce_time
            lift = math.sin(b * math.pi) * 5.0
        drop.append(bomb_frame(lift / TEXEL, i % 3, False))
    idle = [bomb_frame(0, i % 3, i < 2) for i in range(14)]  # 14 kare @14fps = 1 sn: gozler saniyede bir yanip soner
    return drop, idle


# ---------------------------------------------------------------------------------------------------------- mermi
SHELL = [".ooo.", "odddo", "dmhdd", "odddo", ".ooo."]
SHELL_PAL = {"o": rgba(0.05, 0.05, 0.09), "d": rgba(0.16, 0.16, 0.22), "m": rgba(0.3, 0.3, 0.4), "h": rgba(0.7, 0.7, 0.85)}


def strike_frames(radius_world, drop_world, frames):
    R = radius_world / TEXEL
    D = drop_world / TEXEL
    W = int(R * 2 + 12)
    H = int(D + R + 16)
    cx, cy = W // 2, int(D + 8)  # hedef merkezi (patlama noktasi) karede bu konumda
    out = []
    for fi in range(frames):
        k = fi / frames  # son kare tam dususten hemen once; patlama sahnesi ayri
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ring_r = R * (1.0 - 0.35 * k)
        col = rgba(1.0, 0.32, 0.12) if fi % 2 == 0 else rgba(1.0, 0.72, 0.2)
        n = max(24, int(math.tau * ring_r))
        for i in range(n):
            if ((i + fi * 2) // 4) % 2 == 1:
                continue
            a = i / n * math.tau
            put(im, cx + math.cos(a) * ring_r, cy + math.sin(a) * ring_r, col)
        for q in range(4):
            a = q * math.pi * 0.5 + math.pi * 0.25
            px_, py_ = cx + math.cos(a) * (ring_r + 2), cy + math.sin(a) * (ring_r + 2)
            for ox in range(2):
                for oy in range(2):
                    put(im, px_ + ox, py_ + oy, col)
        for ox, oy in ((0, 0), (2, 0), (-2, 0), (0, 2), (0, -2)):
            put(im, cx + ox, cy + oy, col)
        # gulle golgesi: yaklastikca buyuyen duz koyu elips (dama/dither YOK)
        sr = R * 0.16 * (0.4 + 0.6 * k)
        for dy in range(-int(sr) - 1, int(sr) + 2):
            for dx in range(-int(sr) - 1, int(sr) + 2):
                if (dx / max(sr, 0.5)) ** 2 + (dy / max(sr * 0.5, 0.5)) ** 2 <= 1.0:
                    put(im, cx + dx, cy + dy, rgba(0.02, 0.02, 0.04, 0.45))
        # gulle: karesel hizlanarak duser, arkasinda sonen ates/duman izi
        y = cy - D * (1.0 - k) * (1.0 - k)
        for i in range(1, 7):
            ty = y - i * 3
            tk = i / 7.0
            tcol = fire_at(0.15 + tk * 0.8)
            s = 2 if i < 3 else 1
            wob = int(round(math.sin(fi * 1.3 + i)))
            for ox in range(s):
                for oy in range(s):
                    put(im, cx + wob + ox, ty + oy, tcol)
        for yy, row in enumerate(SHELL):
            for xx, ch in enumerate(row):
                if ch in SHELL_PAL:
                    put(im, cx - 2 + xx, y - 2 + yy, SHELL_PAL[ch])
        put(im, cx + 2, y - 3, rgba(1.0, 0.9, 0.5))
        out.append(im)
    return out, (cx, cy)


# ---------------------------------------------------------------------------------------------------------- alan
def zone_frames(radius_world, frames):
    R = radius_world / TEXEL
    S = int(R * 2 + 14)
    c = S // 2
    out = []
    outer = rgba(1.0, 0.55, 0.12)
    inner = rgba(0.85, 0.2, 0.08)
    for fi in range(frames):
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        n = int(math.tau * R / 2)  # 2 texel'lik adimlar - 2 px kalin dis halka
        for i in range(n):
            if ((i + fi) // 3) % 2 == 1:  # 3 acik / 3 kapali, kare basina 1 adim kayar -> 6 karede kusursuz dongu
                continue
            a = i / n * math.tau
            for dr in (0, 1):
                put(im, c + math.cos(a) * (R - dr), c + math.sin(a) * (R - dr), outer)
        Ri = R - 7
        ni = int(math.tau * Ri)
        for i in range(ni):
            if ((i - fi) % 6) >= 2:  # 2 acik / 4 kapali, ters yonde kayar
                continue
            a = i / ni * math.tau
            put(im, c + math.cos(a) * Ri, c + math.sin(a) * Ri, inner)
        for k in range(16):  # halkadaki bomba/elmas isaretleri
            a = k * math.tau / 16
            x, y = c + math.cos(a) * R, c + math.sin(a) * R
            big = k % 4 == 0
            col = rgba(1.0, 0.85, 0.35) if big else rgba(1.0, 0.6, 0.15)
            s = 3 if big else 2
            for ox in range(s):
                for oy in range(s):
                    put(im, x - s // 2 + ox, y - s // 2 + oy, col)
            if big:
                for ox, oy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
                    put(im, x + ox * 1.5, y + oy * 1.5, rgba(0.8, 0.18, 0.08))
        out.append(im)
    return out


# ---------------------------------------------------------------------------------------------------------- puflar
def puff_frames(kind, frames, seed):
    rnd = random.Random(seed)
    S = 40 if kind != "smoke" else 56
    c = S // 2
    if kind == "dust":
        cols = [rgba(0.55, 0.45, 0.32), rgba(0.7, 0.6, 0.44), rgba(0.4, 0.32, 0.22)]
    elif kind == "spark":
        cols = [rgba(1.0, 0.98, 0.8), rgba(1.0, 0.85, 0.3), rgba(1.0, 0.6, 0.15)]
    else:
        cols = [rgba(0.2, 0.19, 0.22), rgba(0.32, 0.3, 0.34), rgba(0.45, 0.43, 0.47), rgba(0.14, 0.13, 0.16)]
    parts = []
    for _ in range(20 if kind == "dust" else (14 if kind != "smoke" else 16)):
        a = rnd.uniform(0, math.tau)
        sp = rnd.uniform(0.35, 1.0)
        parts.append((a, sp, rnd.choice(cols), rnd.choice([1, 1, 2])))
    out = []
    for fi in range(frames):
        t = fi / (frames - 1)
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        reach = (S * 0.46) * ease_out(t * 1.2)
        for a, sp, col, sz in parts:
            x = c + math.cos(a) * reach * sp
            y = c + math.sin(a) * reach * sp * (0.6 if kind == "dust" else 1.0) - (t * S * 0.2 if kind == "smoke" else 0)
            s2 = sz if t < 0.6 else max(0, sz - 1) if t < 0.85 else 0
            if kind == "smoke":
                s2 = sz + 1 if t < 0.7 else sz
            for ox in range(s2):
                for oy in range(s2):
                    put(im, x + ox, y + oy, col)
            if kind == "smoke" and t >= 0.85:
                put(im, x, y, col)
        out.append(im)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)

    def frames_res(name, cell, anims):
        write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), "res://assets/fx/korsan/%s_sheet.png" % name,
                            cell[0], cell[1], anims)

    # patlamalar: LIFE 0.8 sn
    for name, radius, n, seed in (("explosion_big", 150.0, 14, 7), ("explosion_small", 68.0, 12, 11)):
        fr = explosion_frames(radius / TEXEL, n, seed)
        cell = save_sheet(fr, name)
        frames_res(name, cell, [("play", (0, 0), n, False, n / 0.8)])

    drop, idle = bomb_frames()
    cell = save_sheet(drop + idle, "bomb")
    frames_res("bomb", cell, [("drop", (0, 0), len(drop), False, len(drop) / 0.44),
                              ("idle", (len(drop), 0), len(idle), True, 14.0)])

    sf, anchor = strike_frames(68.0, 190.0, 8)
    cell = save_sheet(sf, "strike")
    frames_res("strike", cell, [("play", (0, 0), len(sf), False, len(sf) / 0.34)])
    print("strike anchor (hedef merkezi, kare icinde):", anchor, "kare:", cell)

    zf = zone_frames(380.0, 6)
    cell = save_sheet(zf, "zone")
    frames_res("zone", cell, [("loop", (0, 0), len(zf), True, 10.0)])

    for kind, n, life, seed in (("dust", 7, 0.4, 3), ("spark", 7, 0.4, 5), ("smoke", 9, 0.6, 9)):
        pf = puff_frames(kind, n, seed)
        cell = save_sheet(pf, "puff_" + kind)
        frames_res("puff_" + kind, cell, [("play", (0, 0), n, False, n / life)])


if __name__ == "__main__":
    main()
