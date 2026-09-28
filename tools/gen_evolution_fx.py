"""Yetenek evrimleri (2026-09-28) - pixel-art sprite sayfalari -> assets/fx/evolution/

Kullanici istegi: "bu ekstra nitelikler karakterlerin yetenek efektlerini de biraz etkilemeli bunlarla uyumlu olmasi icin
ozel efektler hazirlamayi unutma" + "varolan efektleri de bu gelistirmelere gore guncelleyebilirsin". Hicbir efekt her
karede _draw() ile cizilmez (performans - bkz. hafiza "Hadime ... all FX must be sprite sheets"): hepsi burada bir kez
uretilen sayfalardan AnimatedSprite2D ile oynar.

Hepsi 1 sanat pikseli = TEXEL 1.212 birim (projedeki FX dili, hafiza "pixel density 48"): 1 piksel halka/cizgi, 1 piksel
parlamalar, iri blok yok, az alfa seviyesi. Dunya konumlu olanlar (sahne kokunde) = 1.212 dunya birimi / sanat px;
karaktere bagli olanlar (Player/RemotePlayer'in cocugu, kok 0.5 olcekli) = 1.212 yerel birim / sanat px. Yaricapi
oyunda degisen efektler sahnesindeki "base_radius" (fx_evo_burst.gd setup) ile olceklenir - asagidaki R_* yorumlarina bkz.

  Genel         evo_gain         (64x72, 14 kare)  evrim alindiginda ayak altinda mor-altin run halkasi + yukselen zerreler
  Hadime  Q1    curse_burst      (96x64,  9 kare)  "Patlayan Lanet": yesil-mor lanet patlamasi (R 70 dunya birimi)
          EF    hole_burst       (208x120,12 kare) "Supernova": kara delik icine cokup mor sok dalgasiyla patlar (R 110)
  Vampir  Q4    blood_shield     (40x56, 10 kare)  "Kan Kalkani": kan damlalari karakterin onunde kalkan isaretine akar
          E4    bat_swoop        (40x28,  6 kare)  "Kanat Darbesi": savrulan yaratikta kanat hilali (+x yonune, dondurulur)
          RF    blood_burst      (104x64, 8 kare)  "Kan Patlamasi": kan halkasi + damlalar (R 55)
  Melek   R2    heal_pulse       (64x72, 10 kare)  "Kutsal Isik": dostun ayaginda altin-yesil sifa nabzi + yukselen artilar
          RF    cooldown_reset   (40x40, 12 kare)  "Yeniden Dogus" / Talon "Yansiyan Hiz": basin ustunde donen yenileme oku
  Talon   EF    talon_ward       (232x232, 8 kare dongu) "Kalkan Cemberi": salvo cemberinde turuncu koruyucu halka
                talon_block      (24x24,  6 kare)  cemberde sonen yaratik mermisi
          E3    spin_spark       (24x16,  5 kare)  "Keskin Cember": donen silahin carptigi yaratikta kivilcim
  Elara   QF    vanish           (48x56, 10 kare)  "Kaybolan Golge": camgobegi duman puf + kivilcim
          RF    shield_refill    (56x64, 12 kare)  "Kalkan Tetigi" / Sovalye "Aninda Kalkan": mavi kalkan isareti parlamasi
  Sovalye R2    reflect_spark    (28x20,  5 kare)  "Yansitan Kubbe": kalkana vuran yaratiga geri donen altin kivilcim
          R1    shockwave        (408x212, 9 kare) "Sarsici Patlama": genis sok dalgasi (R 240)
          EF    retribution      (344x180,11 kare) "Intikam Patlamasi": altin sutun + sok dalgasi (R 200)
  Korsan  QF    korsan_fire      (160x96, 8 kare dongu) "Cehennem Atesi": zeminde yanan ates alani (evo_area.gd)
          EF    korsan_mine      (16x16,  4 kare dongu) "Mayin Sacan": yanip sonen mayin
                mine_pop         (40x40,  7 kare)  mayin patlamasi

Calistir: python tools/gen_evolution_fx.py   (sonra Godot --headless --import; yepyeni sayfalar icin 2 import gerekebilir)
"""

import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402
from gen_hadime_fx import plot, disc, ring, line, spark, outline, fade_img, sheet, new, q_alpha  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "evolution")
RES = "res://assets/fx/evolution/"
TAU = 2 * math.pi

# --- evrim: mor + altin ---
EV_OUT = (34, 12, 52)
EV_DEEP = (78, 34, 122)
EV_MID = (146, 86, 214)
EV_LIGHT = (204, 164, 255)
EV_WHITE = (246, 238, 255)
GOLD = (255, 198, 84)
GOLD_L = (255, 236, 168)
# --- Hadime: hastalikli yesil + mor ---
HG_DEEP = (34, 96, 34)
HG_MID = (111, 220, 74)
HG_LIGHT = (200, 255, 154)
HG_WHITE = (240, 255, 226)
HV_DEEP = (42, 15, 58)
HV_MID = (91, 42, 134)
HV_LIGHT = (150, 92, 204)
BLACK = (8, 4, 12)
# --- kan ---
B_OUT = (40, 4, 10)
B_DEEP = (110, 12, 24)
B_MID = (185, 28, 40)
B_LIGHT = (235, 82, 82)
B_HI = (255, 176, 164)
# --- Talon turuncu ---
O_DEEP = (122, 40, 12)
O_MID = (232, 112, 32)
O_LIGHT = (255, 182, 84)
O_WHITE = (255, 236, 192)
# --- kalkan mavisi ---
S_OUT = (14, 30, 70)
S_DEEP = (26, 60, 128)
S_MID = (64, 134, 232)
S_LIGHT = (144, 204, 255)
S_WHITE = (232, 246, 255)
# --- kutsal / sifa ---
H_GOLD = (255, 212, 92)
H_LIGHT = (255, 242, 176)
H_GREEN = (122, 230, 112)
H_GREEN_L = (196, 255, 176)
# --- ruzgar/camgobegi ---
C_DEEP = (24, 92, 124)
C_MID = (74, 192, 232)
C_LIGHT = (174, 240, 255)
# --- ates ---
F_SCORCH = (46, 22, 14)
F_DEEP = (112, 26, 8)
F_MID = (222, 82, 22)
F_LIGHT = (255, 162, 52)
F_HI = (255, 232, 142)
SMOKE = (58, 50, 54)
METAL_D = (38, 34, 36)
METAL = (84, 78, 82)
METAL_L = (140, 134, 138)


def ease_out(t):
    return 1.0 - (1.0 - t) * (1.0 - t)


def save(name, frames, anim, loop, fps):
    os.makedirs(OUT, exist_ok=True)
    sheet(frames).save(os.path.join(OUT, name + "_sheet.png"))
    w, h = frames[0].size
    write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), RES + name + "_sheet.png", w, h,
                        [(anim, (0, 0), len(frames), loop, fps)])
    print("   %-16s %dx%d x %d kare" % (name, w, h, len(frames)))


def fill_ellipse(im, cx, cy, rx, ry, col, a):
    """Elips ici DUZ, az alfali dolgu (dama/tarama deseni YOK - kullanici Korsan patlamasindaki dama dolguyu reddetmisti)."""
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if ((x + 0.5 - cx) / max(rx, 0.5)) ** 2 + ((y + 0.5 - cy) / max(ry, 0.5)) ** 2 <= 1.0:
                plot(im, x, y, col, a)


# ====================================================================== genel: evrim kazanimi
def evo_gain():
    frames = []
    n = 14
    gx, gy = 32, 60
    for i in range(n):
        t = i / (n - 1)
        im = new(64, 72)
        # ayak alti run halkasi: buyur, sonra soner
        rr = 6 + 20 * ease_out(min(1.0, t * 1.6))
        fade = 1.0 if t < 0.6 else max(0.0, 1.0 - (t - 0.6) / 0.4)
        ring(im, gx, gy, rr, rr * 0.42, EV_MID, fade)
        ring(im, gx, gy, rr * 0.62, rr * 0.62 * 0.42, GOLD, fade * 0.8)
        for k in range(8):  # halka uzerinde run tikleri
            a = TAU * k / 8 + t * 1.5
            plot(im, gx + math.cos(a) * rr, gy + math.sin(a) * rr * 0.42, EV_WHITE if k % 2 else GOLD_L, fade)
        # hafif isik sutunu (seyrek noktalar - tarama degil)
        colh = 50 * min(1.0, t * 2.0)
        colfade = fade * 0.55
        for y in range(int(gy - colh), gy - 2, 3):
            plot(im, gx, y, EV_LIGHT, colfade)
        # yukselen zerreler (spiral)
        for k in range(16):
            ph = (k * 0.37) % 1.0
            h = t * 52 * (0.55 + 0.45 * ph)
            if h < 1:
                continue
            a = TAU * k / 16 + t * 5.0
            rad = 9 * (1.0 - t * 0.6)
            px = gx + math.cos(a) * rad
            py = gy - h + math.sin(a) * rad * 0.4
            col = EV_LIGHT if k % 2 else GOLD
            alpha = 1.0 if t < 0.75 else max(0.0, 1.0 - (t - 0.75) / 0.25)
            plot(im, px, py, col, alpha)
            plot(im, px, py + 1, EV_MID if k % 2 else GOLD, alpha * 0.55)
        # tepe parlamasi
        if 0.3 <= t <= 0.72:
            p = 1.0 - abs(t - 0.5) / 0.22
            spark(im, gx, 12, max(1, int(round(4 * p))), EV_WHITE, GOLD_L, 1.0)
        frames.append(im)
    save("evo_gain", frames, "play", False, 20.0)


# ====================================================================== Hadime
def curse_burst():
    """R 70 dunya birimi = 58 sanat px (elips ry yari)."""
    frames = []
    n = 9
    cx, cy = 48, 34
    rmax = 58
    for i in range(n):
        t = i / (n - 1)
        im = new(96, 64)
        fade = 1.0 if t < 0.5 else max(0.0, 1.0 - (t - 0.5) / 0.5)
        if i <= 2:
            disc(im, cx, cy, 5 - i, HG_MID, 1.0, ry=(5 - i) * 0.7)
            disc(im, cx, cy, 2.5 - i * 0.6, HG_WHITE, 1.0)
        rx = 6 + (rmax - 6) * ease_out(t)
        ring(im, cx, cy, rx, rx * 0.5, HG_MID if t < 0.45 else HV_LIGHT, fade)
        ring(im, cx, cy, rx * 0.84, rx * 0.84 * 0.5, HV_MID, fade * 0.7)
        for k in range(10):  # disa savrulan lanet kiriklari
            a = TAU * k / 10 + 0.3
            d = rx * (0.9 + 0.1 * (k % 2))
            x0 = cx + math.cos(a) * d
            y0 = cy + math.sin(a) * d * 0.5
            x1 = cx + math.cos(a) * (d + 3)
            y1 = cy + math.sin(a) * (d + 3) * 0.5
            line(im, x0, y0, x1, y1, HG_LIGHT if k % 2 else HV_LIGHT, fade)
        if 0.2 < t:  # halkadan yukselen mor-yesil zerreler
            for k in range(8):
                a = TAU * k / 8 + 0.4
                h = 3 + 14 * (t - 0.2) * (0.6 + 0.4 * (k % 3) / 2.0)
                x = cx + math.cos(a) * rx * 0.75
                y = cy + math.sin(a) * rx * 0.75 * 0.5 - h
                plot(im, x, y, HV_LIGHT if k % 2 else HG_LIGHT, fade)
                plot(im, x, y + 1, HV_MID, fade * 0.55)
        frames.append(im)
    save("curse_burst", frames, "play", False, 22.0)


def hole_burst():
    """R 110 dunya birimi = 91 sanat px."""
    frames = []
    n = 12
    cx, cy = 104, 62
    rmax = 91
    rnd = random.Random(7)
    motes = [(rnd.uniform(0, TAU), rnd.uniform(0.7, 1.0)) for _ in range(28)]
    for i in range(n):
        im = new(208, 120)
        if i < 4:  # icine cokus
            t = i / 3.0
            for (a, f) in motes:
                d = rmax * f * (1.0 - t)
                x = cx + math.cos(a + t * 1.2) * d
                y = cy + math.sin(a + t * 1.2) * d * 0.5
                plot(im, x, y, HV_LIGHT, 1.0)
                plot(im, x - math.cos(a) * 2, y - math.sin(a), HV_MID, 0.8)
            r = 7 + 5 * t
            disc(im, cx, cy, r + 2, HV_MID, 1.0, ry=(r + 2) * 0.6)
            disc(im, cx, cy, r, BLACK, 1.0, ry=r * 0.6)
            ring(im, cx, cy, r + 3, (r + 3) * 0.55, HG_LIGHT, 0.8)
        elif i == 4:  # patlama flasi
            disc(im, cx, cy, 20, HV_LIGHT, 1.0, ry=12)
            disc(im, cx, cy, 13, EV_WHITE, 1.0, ry=8)
            spark(im, cx, cy - 12, 5, EV_WHITE, HG_LIGHT)
        else:  # sok dalgasi
            t = (i - 5) / (n - 6)
            fade = 1.0 if t < 0.45 else max(0.0, 1.0 - (t - 0.45) / 0.55)
            rx = 18 + (rmax - 18) * ease_out(t)
            ring(im, cx, cy, rx, rx * 0.5, HV_LIGHT, fade)
            ring(im, cx, cy, rx - 2, (rx - 2) * 0.5, HV_MID, fade * 0.8)
            ring(im, cx, cy, rx * 0.72, rx * 0.72 * 0.5, HG_MID, fade * 0.6)
            for k in range(16):
                a = TAU * k / 16
                d0 = rx * 0.55
                d1 = rx * 0.55 + 6 * (1 - t)
                line(im, cx + math.cos(a) * d0, cy + math.sin(a) * d0 * 0.5, cx + math.cos(a) * d1,
                     cy + math.sin(a) * d1 * 0.5, EV_LIGHT if k % 2 else HG_LIGHT, fade * 0.9)
            r = 9 * (1 - t)
            if r > 1:
                disc(im, cx, cy, r, BLACK, fade, ry=r * 0.6)
        frames.append(im)
    save("hole_burst", frames, "play", False, 18.0)


# ====================================================================== Vampir
def blood_shield():
    frames = []
    n = 10
    cx, cy = 20, 30
    for i in range(n):
        t = i / (n - 1)
        im = new(40, 56)
        if i < 5:  # damlalar icine akar
            u = i / 4.0
            for k in range(5):
                a = TAU * k / 5 + u * 2.5
                d = 17 * (1 - u) + 3
                x = cx + math.cos(a) * d
                y = cy + math.sin(a) * d * 0.8
                plot(im, x, y, B_MID, 1.0)
                plot(im, x, y - 1, B_LIGHT, 1.0)
                plot(im, x + math.cos(a), y + math.sin(a), B_DEEP, 0.8)
        if i >= 3:  # kalkan isareti
            u = min(1.0, (i - 3) / 2.0)
            fade = 1.0 if t < 0.7 else max(0.0, 1.0 - (t - 0.7) / 0.3)
            w = 6 * u
            h = 8 * u
            if w >= 1:
                pts = [(cx - w, cy - h), (cx + w, cy - h), (cx + w, cy + h * 0.2), (cx, cy + h), (cx - w, cy + h * 0.2)]
                for j in range(len(pts)):
                    x0, y0 = pts[j]
                    x1, y1 = pts[(j + 1) % len(pts)]
                    line(im, x0, y0, x1, y1, S_LIGHT if i in (4, 5) else S_MID, fade)
                disc(im, cx, cy - h * 0.2, w * 0.45, B_MID, fade * 0.8, ry=h * 0.35)
                if i == 5:
                    spark(im, cx, cy - h - 2, 2, S_WHITE, S_LIGHT)
        frames.append(im)
    save("blood_shield", frames, "play", False, 16.0)


def bat_swoop():
    """+x yonune bakan hilal; sahne efekti vurus yonune dondurur."""
    frames = []
    n = 6
    cx, cy = 14, 14
    for i in range(n):
        t = i / (n - 1)
        im = new(40, 28)
        fade = 1.0 if t < 0.5 else max(0.0, 1.0 - (t - 0.5) / 0.5)
        sweep = min(1.0, t * 2.0)
        a0 = -1.1
        a1 = -1.1 + 2.2 * sweep
        steps = 18
        for s in range(steps + 1):
            a = a0 + (a1 - a0) * s / steps
            r = 11 + 2 * t
            plot(im, cx + math.cos(a) * r + 4 * t, cy + math.sin(a) * r, HV_LIGHT if s % 3 else B_LIGHT, fade)
            plot(im, cx + math.cos(a) * (r - 1) + 4 * t, cy + math.sin(a) * (r - 1), HV_MID, fade * 0.8)
        # iki minik yarasa kanadi (V)
        for k in range(2):
            bx = cx + 10 + 12 * t + k * 5
            by = cy - 4 + k * 8
            flap = 1 if (i + k) % 2 else 0
            plot(im, bx, by, HV_DEEP, fade)
            plot(im, bx - 1, by - 1 - flap, HV_DEEP, fade)
            plot(im, bx + 1, by - 1 - flap, HV_DEEP, fade)
            plot(im, bx - 2, by - flap, HV_MID, fade * 0.8)
            plot(im, bx + 2, by - flap, HV_MID, fade * 0.8)
        frames.append(im)
    save("bat_swoop", frames, "play", False, 22.0)


def blood_burst():
    """R 55 dunya birimi = 45 sanat px."""
    frames = []
    n = 8
    cx, cy = 52, 34
    rmax = 45
    rnd = random.Random(13)
    drops = [(rnd.uniform(0, TAU), rnd.uniform(0.5, 1.0)) for _ in range(14)]
    for i in range(n):
        t = i / (n - 1)
        im = new(104, 64)
        fade = 1.0 if t < 0.5 else max(0.0, 1.0 - (t - 0.5) / 0.5)
        if i <= 1:
            disc(im, cx, cy, 6 - i * 2, B_MID, 1.0, ry=(6 - i * 2) * 0.7)
            disc(im, cx, cy - 1, 3 - i, B_HI, 1.0)
        rx = 5 + (rmax - 5) * ease_out(t)
        ring(im, cx, cy, rx, rx * 0.5, B_LIGHT if t < 0.4 else B_MID, fade)
        ring(im, cx, cy, rx * 0.8, rx * 0.8 * 0.5, B_DEEP, fade * 0.7)
        for (a, f) in drops:
            d = rx * f
            x = cx + math.cos(a) * d
            y = cy + math.sin(a) * d * 0.5 - 10 * f * math.sin(math.pi * t)
            plot(im, x, y, B_MID, fade)
            plot(im, x, y - 1, B_LIGHT, fade * 0.8)
        frames.append(im)
    save("blood_burst", frames, "play", False, 20.0)


# ====================================================================== Melek
def heal_pulse():
    frames = []
    n = 10
    gx, gy = 32, 60
    for i in range(n):
        t = i / (n - 1)
        im = new(64, 72)
        fade = 1.0 if t < 0.55 else max(0.0, 1.0 - (t - 0.55) / 0.45)
        rx = 4 + 22 * ease_out(t)
        ring(im, gx, gy, rx, rx * 0.42, H_GOLD, fade)
        ring(im, gx, gy, rx * 0.7, rx * 0.7 * 0.42, H_GREEN, fade * 0.8)
        # isik sutunu
        colh = 44 * min(1.0, t * 2.5)
        for y in range(int(gy - colh), gy):
            if (y + i) % 2 == 0:
                plot(im, gx, y, H_LIGHT, fade * 0.8)
            plot(im, gx - 3, y, H_GREEN, fade * 0.3 if y % 3 == 0 else 0.0)
            plot(im, gx + 3, y, H_GREEN, fade * 0.3 if y % 3 == 1 else 0.0)
        # yukselen artilar
        for k in range(3):
            h = t * 36 + k * 8
            x = gx + (k - 1) * 11
            y = gy - 10 - h
            if 4 < y < 70:
                for (dx, dy) in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                    plot(im, x + dx, y + dy, H_GREEN_L if (dx, dy) == (0, 0) else H_GREEN, fade)
        frames.append(im)
    save("heal_pulse", frames, "play", False, 16.0)


def cooldown_reset():
    frames = []
    n = 12
    cx, cy = 20, 20
    for i in range(n):
        t = i / (n - 1)
        im = new(40, 40)
        fade = 1.0 if t < 0.7 else max(0.0, 1.0 - (t - 0.7) / 0.3)
        r = 6 + 5 * ease_out(min(1.0, t * 2.0))
        rot = t * TAU * 1.2
        span = TAU * 0.8
        steps = 30
        for s in range(steps + 1):
            a = rot + span * s / steps
            plot(im, cx + math.cos(a) * r, cy + math.sin(a) * r, GOLD if s < steps - 3 else GOLD_L, fade)
        # ok ucu
        a = rot + span
        tip = (cx + math.cos(a) * r, cy + math.sin(a) * r)
        tan = (-math.sin(a), math.cos(a))
        nrm = (math.cos(a), math.sin(a))
        for (u, v) in ((-2, 2), (-2, -2), (-1, 1), (-1, -1)):
            plot(im, tip[0] + tan[0] * u + nrm[0] * v * 0.8, tip[1] + tan[1] * u + nrm[1] * v * 0.8, GOLD_L, fade)
        if 0.5 <= t <= 0.8:
            spark(im, cx, cy, 2, EV_WHITE, GOLD_L, 1.0)
        frames.append(im)
    save("cooldown_reset", frames, "play", False, 20.0)


# ====================================================================== Talon
def talon_ward():
    """Salvo cemberi: yerel 130 birim / 1.212 = ~107 sanat px yaricapli daire (silah ikonlari ayni cemberde)."""
    frames = []
    n = 8
    c = 116
    r = 107
    for i in range(n):
        im = new(232, 232)
        ph = (i / n) * (TAU / 12)
        ring(im, c, c, r, r, O_MID, 0.8)
        ring(im, c, c, r - 3, r - 3, O_DEEP, 0.55)
        for k in range(12):  # disa bakan koseli isaretler, bir kare = 1/8 aralik
            a = TAU * k / 12 + ph
            ca, sa = math.cos(a), math.sin(a)
            bx, by = c + ca * (r - 1), c + sa * (r - 1)
            for u in (-2, -1, 0, 1, 2):
                off = abs(u)
                plot(im, bx - sa * u + ca * (1 - off), by + ca * u + sa * (1 - off), O_LIGHT, 0.9)
        for k in range(3):  # cember uzerinde gezen parlak noktalar (TAU/3 periyot - kusursuz dongu)
            a = TAU * k / 3 + (i / n) * (TAU / 3)
            spark(im, c + math.cos(a) * r, c + math.sin(a) * r, 1, O_WHITE, O_LIGHT, 1.0)
        ring(im, c, c, r - 7, r - 7, O_DEEP, 0.3)
        frames.append(im)
    save("talon_ward", frames, "loop", True, 10.0)


def talon_block():
    frames = []
    n = 6
    c = 12
    for i in range(n):
        t = i / (n - 1)
        im = new(24, 24)
        fade = 1.0 if t < 0.4 else max(0.0, 1.0 - (t - 0.4) / 0.6)
        r = 2 + 7 * ease_out(t)
        for k in range(6):
            a = TAU * k / 6 + 0.26
            plot(im, c + math.cos(a) * r, c + math.sin(a) * r, O_LIGHT, fade)
            plot(im, c + math.cos(a) * (r - 1), c + math.sin(a) * (r - 1), O_MID, fade * 0.7)
        if i <= 2:
            spark(im, c, c, 3 - i, O_WHITE, O_LIGHT)
        frames.append(im)
    save("talon_block", frames, "play", False, 24.0)


def spin_spark():
    frames = []
    n = 5
    for i in range(n):
        t = i / (n - 1)
        im = new(24, 16)
        fade = 1.0 if t < 0.35 else max(0.0, 1.0 - (t - 0.35) / 0.65)
        L = 4 + 8 * ease_out(t)
        line(im, 12 - L, 8 + L * 0.2, 12 + L, 8 - L * 0.2, O_WHITE if i < 2 else O_LIGHT, fade)
        line(im, 12 - L * 0.6, 9 + L * 0.12, 12 + L * 0.6, 9 - L * 0.12, O_MID, fade * 0.7)
        for k in range(4):
            a = -0.9 + 0.6 * k
            d = 3 + 6 * t
            plot(im, 12 + math.cos(a) * d, 8 + math.sin(a) * d, O_LIGHT, fade)
        frames.append(im)
    save("spin_spark", frames, "play", False, 24.0)


# ====================================================================== Elara
def vanish():
    frames = []
    n = 10
    cx, cy = 24, 34
    rnd = random.Random(5)
    puffs = [(rnd.uniform(0, TAU), rnd.uniform(0.4, 1.0)) for _ in range(7)]
    for i in range(n):
        t = i / (n - 1)
        im = new(48, 56)
        fade = 1.0 if t < 0.4 else max(0.0, 1.0 - (t - 0.4) / 0.6)
        for (a, f) in puffs:
            d = 4 + 12 * f * ease_out(t)
            x = cx + math.cos(a) * d
            y = cy + math.sin(a) * d * 0.7 - 6 * t
            r = 2 + 3 * f * (1 - t * 0.5)
            disc(im, x, y, r, C_DEEP, fade * 0.7, over=False)
            disc(im, x - 0.5, y - 0.5, r * 0.55, C_MID, fade * 0.7, over=False)
        for k in range(5):
            h = 6 + t * 28 + k * 4
            x = cx + (k - 2) * 5 + math.sin(t * 6 + k) * 1.5
            plot(im, x, cy - h * 0.8, C_LIGHT, fade)
        if i <= 1:
            spark(im, cx, cy - 6, 3, (240, 252, 255), C_LIGHT)
        frames.append(im)
    save("vanish", frames, "play", False, 18.0)


def shield_refill():
    frames = []
    n = 12
    cx, cy = 28, 34
    for i in range(n):
        t = i / (n - 1)
        im = new(56, 64)
        fade = 1.0 if t < 0.6 else max(0.0, 1.0 - (t - 0.6) / 0.4)
        u = ease_out(min(1.0, t * 2.2))
        w = 9 * u
        h = 12 * u
        if w >= 1:
            pts = [(cx - w, cy - h), (cx + w, cy - h), (cx + w, cy + h * 0.25), (cx, cy + h), (cx - w, cy + h * 0.25)]
            for j in range(len(pts)):
                x0, y0 = pts[j]
                x1, y1 = pts[(j + 1) % len(pts)]
                line(im, x0, y0, x1, y1, S_WHITE if i in (4, 5) else S_LIGHT, fade)
            for y in range(int(cy - h) + 1, int(cy + h)):
                for x in range(int(cx - w) + 1, int(cx + w)):
                    inside = y <= cy + h * 0.25 or abs(x - cx) < (cy + h - y) * (w / max(1.0, h * 0.75))
                    if inside and (x + y + i) % 3 == 0:
                        plot(im, x, y, S_MID, fade * 0.6)
            line(im, cx, cy - h + 2, cx, cy + h - 3, S_LIGHT, fade * 0.8)
        # yukselen zerreler
        for k in range(6):
            h2 = t * 40 + k * 6
            x = cx + (k - 2.5) * 6
            y = cy + 14 - h2
            if 2 < y < 62:
                plot(im, x, y, S_LIGHT if k % 2 else S_WHITE, fade)
        if i == 4:
            ring(im, cx, cy, 16, 16, S_WHITE, 0.8)
        frames.append(im)
    save("shield_refill", frames, "play", False, 18.0)


# ====================================================================== Sovalye
def reflect_spark():
    frames = []
    n = 5
    for i in range(n):
        t = i / (n - 1)
        im = new(28, 20)
        fade = 1.0 if t < 0.35 else max(0.0, 1.0 - (t - 0.35) / 0.65)
        x = 6 + 14 * ease_out(t)
        for k in range(3):  # ileri bakan kose isaretleri
            bx = x - k * 4
            for u in (-2, -1, 0, 1, 2):
                plot(im, bx - abs(u), 10 + u, H_GOLD if k else H_LIGHT, fade * (1.0 - 0.25 * k))
        if i == 0:
            spark(im, 6, 10, 3, (255, 252, 230), H_GOLD)
        frames.append(im)
    save("reflect_spark", frames, "play", False, 24.0)


def shockwave():
    """R 240 dunya birimi = ~198 sanat px."""
    frames = []
    n = 9
    cx, cy = 204, 108
    rmax = 198
    for i in range(n):
        t = i / (n - 1)
        im = new(408, 212)
        fade = 1.0 if t < 0.4 else max(0.0, 1.0 - (t - 0.4) / 0.6)
        rx = 16 + (rmax - 16) * ease_out(t)
        ring(im, cx, cy, rx, rx * 0.5, S_WHITE, fade)
        ring(im, cx, cy, rx - 2, (rx - 2) * 0.5, S_LIGHT, fade * 0.85)
        ring(im, cx, cy, rx - 5, (rx - 5) * 0.5, S_MID, fade * 0.6)
        for k in range(24):  # halkadaki toz
            a = TAU * k / 24 + 0.13
            d = rx + 2 + (k % 3)
            plot(im, cx + math.cos(a) * d, cy + math.sin(a) * d * 0.5, (206, 196, 176), fade * 0.8)
        if i <= 1:
            disc(im, cx, cy, 14 - i * 5, S_WHITE, 1.0, ry=(14 - i * 5) * 0.55)
        frames.append(im)
    save("shockwave", frames, "play", False, 20.0)


def retribution():
    """R 200 dunya birimi = ~165 sanat px."""
    frames = []
    n = 11
    cx, cy = 172, 110
    rmax = 165
    rnd = random.Random(21)
    shards = [(rnd.uniform(0, TAU), rnd.uniform(0.5, 1.0)) for _ in range(22)]
    for i in range(n):
        t = i / (n - 1)
        im = new(344, 180)
        fade = 1.0 if t < 0.45 else max(0.0, 1.0 - (t - 0.45) / 0.55)
        if i < 5:  # altin sutun
            ch = 90 * min(1.0, (i + 1) / 3.0)
            w = 4 if i < 3 else 3 - (i - 3)
            for y in range(int(cy - ch), cy):
                for x in range(-w, w + 1):
                    col = H_LIGHT if abs(x) < 2 else H_GOLD
                    if (y + x) % 2 == 0 or abs(x) < 2:
                        plot(im, cx + x, y, col, 1.0 if i < 4 else 0.6)
            disc(im, cx, cy, 12 - i, H_LIGHT, 1.0, ry=(12 - i) * 0.5)
        rx = 10 + (rmax - 10) * ease_out(t)
        ring(im, cx, cy, rx, rx * 0.5, H_LIGHT, fade)
        ring(im, cx, cy, rx - 2, (rx - 2) * 0.5, H_GOLD, fade * 0.9)
        ring(im, cx, cy, rx * 0.78, rx * 0.78 * 0.5, B_LIGHT, fade * 0.6)
        for (a, f) in shards:
            d = rx * f
            x0 = cx + math.cos(a) * d
            y0 = cy + math.sin(a) * d * 0.5
            line(im, x0, y0, x0 + math.cos(a) * 3, y0 + math.sin(a) * 1.5, H_GOLD if f > 0.75 else B_LIGHT, fade)
        frames.append(im)
    save("retribution", frames, "play", False, 18.0)


# ====================================================================== Korsan
def korsan_fire():
    """Zemin elipsi rx 74 x ry 37 sanat px, zemin merkezi (80, 56) - evo_area.gd FIRE_ART_RADIUS / FIRE_GROUND_ART."""
    frames = []
    n = 8
    gx, gy = 80, 56
    rx, ry = 74, 37
    rnd = random.Random(33)
    flames = []
    while len(flames) < 26:
        x = rnd.uniform(-rx, rx)
        y = rnd.uniform(-ry, ry)
        if (x / rx) ** 2 + (y / ry) ** 2 <= 0.85:
            flames.append((x, y, rnd.randint(0, n - 1), rnd.uniform(0.6, 1.0)))
    flames.sort(key=lambda f: f[1])
    for i in range(n):
        im = new(160, 96)
        fill_ellipse(im, gx, gy, rx, ry, F_SCORCH, 0.3)
        fill_ellipse(im, gx, gy, rx * 0.78, ry * 0.78, F_DEEP, 0.3)
        ring(im, gx, gy, rx, ry, F_DEEP, 0.55)
        for (fx, fy, ph, sz) in flames:
            k = (i + ph) % n
            h = (4 + 6 * sz) * (0.75 + 0.25 * math.sin(TAU * k / n))
            bx = round(gx + fx)
            by = round(gy + fy)
            for s in range(int(h) + 1):
                u = s / max(1.0, h)
                half = 1 if u < 0.55 else 0  # tabanda 3, tepede 1 texel genislik
                col = F_MID if u < 0.3 else (F_LIGHT if u < 0.7 else F_HI)
                wob = round(math.sin(TAU * (k / n) + fy * 0.3 + u * 2.0) * u * 1.3)
                for dx in range(-half, half + 1):
                    plot(im, bx + wob + dx, by - s, col if dx == 0 else F_MID, 1.0)
            plot(im, bx - 2, by, F_DEEP, 0.8)
            plot(im, bx + 2, by, F_DEEP, 0.8)
            if k == 0:
                plot(im, bx, by - h - 3, F_HI, 0.8)  # kopan kivilcim
        frames.append(im)
    save("korsan_fire", frames, "loop", True, 12.0)


def korsan_mine():
    """16x16, zemin merkezi (8, 10) - evo_area.gd MINE_GROUND_ART."""
    frames = []
    n = 4
    cx, cy = 8, 9
    for i in range(n):
        im = new(16, 16)
        disc(im, cx, cy + 2, 5, (20, 16, 18), 0.55, ry=2)  # golge
        disc(im, cx, cy, 4, METAL, 1.0, ry=3)
        disc(im, cx - 1, cy - 1, 2, METAL_L, 1.0, ry=1.2)
        for (dx, dy) in ((-5, 0), (5, 0), (0, -4), (-3, -3), (3, -3)):
            plot(im, cx + dx, cy + dy, METAL_D, 1.0)
        outline(im, METAL_D, 1.0)
        on = i < 2
        plot(im, cx, cy - 1, B_HI if on else B_DEEP, 1.0)
        plot(im, cx + 1, cy - 1, B_LIGHT if on else B_DEEP, 1.0)
        if on:
            plot(im, cx, cy - 2, B_LIGHT, 0.8)
            plot(im, cx + 1, cy - 2, B_MID, 0.55)
        frames.append(im)
    save("korsan_mine", frames, "loop", True, 6.0)


def mine_pop():
    frames = []
    n = 7
    c = 20
    for i in range(n):
        t = i / (n - 1)
        im = new(40, 40)
        fade = 1.0 if t < 0.4 else max(0.0, 1.0 - (t - 0.4) / 0.6)
        r = 3 + 10 * ease_out(t)
        if i <= 2:
            disc(im, c, c, r, F_LIGHT, 1.0, ry=r * 0.8)
            disc(im, c, c, r * 0.55, F_HI, 1.0, ry=r * 0.45)
        else:
            for k in range(6):
                a = TAU * k / 6 + t
                disc(im, c + math.cos(a) * r * 0.7, c + math.sin(a) * r * 0.5 - 3 * t, 3 * (1 - t) + 1, SMOKE, fade * 0.7, over=False)
        ring(im, c, c, r + 2, (r + 2) * 0.6, F_MID, fade)
        for k in range(8):
            a = TAU * k / 8 + 0.4
            d = r + 3
            plot(im, c + math.cos(a) * d, c + math.sin(a) * d * 0.7, F_HI if k % 2 else F_LIGHT, fade)
        frames.append(im)
    save("mine_pop", frames, "play", False, 22.0)


if __name__ == "__main__":
    print("Evrim FX ->", os.path.relpath(OUT, ROOT))
    evo_gain()
    curse_burst()
    hole_burst()
    blood_shield()
    bat_swoop()
    blood_burst()
    heal_pulse()
    cooldown_reset()
    talon_ward()
    talon_block()
    spin_spark()
    vanish()
    shield_refill()
    reflect_spark()
    shockwave()
    retribution()
    korsan_fire()
    korsan_mine()
    mine_pop()
