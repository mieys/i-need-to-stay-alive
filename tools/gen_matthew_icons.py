#!/usr/bin/env python3
"""Matthew'in yetenek ikonlari (Q Tilki Hucumu / E Vahsi Hiz / R Feda Kalkani / pasif) -> assets/skills/*.png

Kullanim (repo kokunden):
    python tools/gen_matthew_icons.py      (sonra Godot editorune donunce import olur ya da `--headless --import`)

Kullanici istegi (2026-09-25): "matthewin yeteneklerinin ikonlarini yeteneklerine uyumlu sekilde pixel tarzinda sifirdan
tasarlamani istiyorum, distan hafif vinyetli minimalist 48x48 sirin pixel art". Eskiden buyuk (1000 px) yumusak AI
cizimleriydi, pasif yuvarlak bir madalyondu ve Q (Tilki Hucumu) kendine ait ikonu olmadigi icin R'nin (Feda Kalkani)
ikonunu kullaniyordu - artik matthew_tilki_hucumu_icon.png ayri.

Dil: tools/gen_elara_korsan_icons.py ile AYNI kare karo (tile: koyu kontur, dither'li 4 bant degrade, yumusak isik,
kose vinyeti) ve AYNI yardimcilar; 48x48 sanat izgarasi, 1 px detay, 3x NEAREST -> 144x144 PNG. Tilkinin renkleri
oyundaki tilki sprite'indan (assets/pets/fox/fox_idle.png: pas turuncusu + krem gogus + koyu kahve kulak ucu).
"""
import math
import os
import sys

from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_elara_korsan_icons import C, canvas, finish, mix, put, sparkle, tile  # noqa: E402

FOX_L = C('#e0874a')   # alin isigi
FOX_O = C('#c4602f')   # ana pas turuncusu
FOX_D = C('#94402a')   # golge
FOX_K = C('#4e2025')   # kulak ucu / goz / burun
CREAM = C('#fbeede')
CREAM_D = C('#dcc3ad')
EAR_IN = C('#f2b9a0')
BLUSH = C('#f08a8a')
EYE_HI = C('#ffffff')

GOLD = (C('#fff1a8'), C('#f2c440'), C('#c88a1c'), C('#7e4c0c'))

# Tilki yuzu, SOL YARI (son sutun = orta sutun; sag yari aynalanir). 19x15.
#  K koyu uc/goz, I kulak ici, O turuncu, W krem, P allik, H goz parlamasi, E goz, N burun, . bos
FACE_LEFT = [
    "K.........",
    "KK........",
    "KIO.......",
    "OIIO......",
    "OIIIO.....",
    "OIIIOOOOOO",
    "OOIIOOOOOO",
    "OOOOOOOOOO",
    "OOOOOOOOOO",
    "OOO@@OOOOO",   # @ = goz satiri 1 (goz tipine gore doldurulur)
    "OOO##OOOOO",   # # = goz satiri 2
    "WWPPOOWWWW",
    ".WWWWWWWNN",
    "..WWWWWWWN",
    "....WWWWWW",
]
EYES = {
    "open": ("HE", "EE"),
    "closed": ("OE", "EO"),   # ^ ^ mutlu/kapali goz (aynalaninca simetrik)
}


def fox_face(e, x0, y0, eyes="open"):
    """19x15 tilki yuzu, sol ust kosesi (x0, y0). Sag tarafa golge, alna isik uygulanir."""
    top, bot = EYES[eyes]
    rows = []
    for r in FACE_LEFT:
        r = r.replace("@@", top).replace("##", bot)
        rows.append(r + r[-2::-1])  # orta sutun tek sefer
    pal = {'K': FOX_K, 'I': EAR_IN, 'O': FOX_O, 'W': CREAM, 'P': BLUSH, 'H': EYE_HI, 'E': FOX_K, 'N': FOX_K}
    w = len(rows[0])
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch not in pal:
                continue
            col = pal[ch]
            if ch == 'O':
                if 5 <= y <= 6 and 6 <= x <= w - 7:
                    col = FOX_L
                elif x >= w - 4 and y >= 5:
                    col = FOX_D
            elif ch == 'W' and x >= w - 5:
                col = CREAM_D
            put(e, [(x0 + x, y0 + y)], col)


def fox_face_ears_only(e, x0, y0):
    """Sadece kulaklar (kalkanin ust koselerine) - FACE_LEFT'in ilk 5 satiri."""
    for y, r in enumerate(FACE_LEFT[:5]):
        row = r + r[-2::-1]
        for x, ch in enumerate(row):
            col = {'K': FOX_K, 'I': EAR_IN, 'O': FOX_O}.get(ch)
            if col is not None:
                put(e, [(x0 + x, y0 + y)], col)


def streak(fx, x0, x1, y, col_hi, col_lo, thick=1):
    """Soldan saga incelip parlayan hiz cizgisi (kontursuz fx)."""
    n = max(1, x1 - x0)
    for i in range(n + 1):
        t = i / n
        c = mix(col_lo, col_hi, t)
        c = c[:3] + (int(90 + 165 * t),)
        for k in range(thick):
            if thick == 1 or i > n * 0.35 or k == 0:
                put(fx, [(x0 + i, y + k)], c)


# ============================================================== Q - Tilki Hucumu
def tilki_hucumu():
    im = tile(C('#b8463a'), C('#3a1218'), C('#e2704a'), C('#f7a07a'), C('#4a1418'), glow_center=(29, 22), glow_r=(14, 13))
    e = canvas()
    fx = canvas()
    fox_face(e, 20, 12, "open")
    # ileri atilan tilkinin arkasinda hiz cizgileri
    y_hi, y_lo = C('#ffe6a8'), C('#e0703a')
    streak(fx, 4, 19, 16, y_hi, y_lo, 2)
    streak(fx, 8, 19, 21, y_hi, y_lo, 1)
    streak(fx, 3, 18, 25, y_hi, y_lo, 2)
    # pence izi: uc egik cizik (yuzun altinda, sagda)
    claw_hi, claw_lo = C('#fff6e0'), C('#ffb060')
    for i, (x, y) in enumerate(((25, 43), (30, 43), (35, 42))):
        n = 11
        for k in range(n):
            px = x + (k * 6) // n
            put(fx, [(px, y - k)], claw_hi if 2 <= k <= n - 3 else claw_lo)
            if 3 <= k <= n - 4:
                put(fx, [(px + 1, y - k)], claw_lo)
    sparkle(fx, 42, 9, C('#ffffff'), C('#ffd48a'), 1)
    finish(im, e, fx, "matthew_tilki_hucumu_icon.png")


# ============================================================== E - Vahsi Hiz
def paw(d, cx, cy):
    """Tilki pati izi: ana taban + 4 parmak (pas turuncusu, sol-ust isikli)."""
    d.ellipse((cx - 6, cy - 2, cx + 6, cy + 7), fill=FOX_O)
    d.polygon([(cx - 6, cy + 3), (cx + 6, cy + 3), (cx + 3, cy + 8), (cx - 3, cy + 8)], fill=FOX_O)
    for (tx, ty) in ((cx - 8, cy - 5), (cx - 3, cy - 9), (cx + 3, cy - 9), (cx + 8, cy - 5)):
        d.ellipse((tx - 2, ty - 3, tx + 2, ty + 3), fill=FOX_O)
    # golge (sag/alt) + isik (sol/ust)
    d.arc((cx - 6, cy - 2, cx + 6, cy + 7), -10, 100, fill=FOX_D)
    d.line((cx - 3, cy + 8, cx + 3, cy + 8), fill=FOX_D)
    for (tx, ty) in ((cx - 8, cy - 5), (cx - 3, cy - 9), (cx + 3, cy - 9), (cx + 8, cy - 5)):
        d.line((tx + 2, ty - 1, tx + 2, ty + 2), fill=FOX_D)
        d.point((tx - 1, ty - 2), fill=FOX_L)
    d.arc((cx - 5, cy - 1, cx + 5, cy + 6), 190, 260, fill=FOX_L)
    d.point((cx - 3, cy), fill=C('#f4a878'))


def chevron(e, cx, cy, col_hi, col):
    """Yukari bakan kalin ok ucu (^), 9 genis."""
    for i in range(5):
        put(e, [(cx - i, cy + i), (cx + i, cy + i)], col_hi if i < 2 else col)
        put(e, [(cx - i, cy + i + 1), (cx + i, cy + i + 1)], col)


def vahsi_hiz():
    im = tile(C('#4f9a44'), C('#163319'), C('#7fcf5a'), C('#b6ef8e'), C('#123014'), glow_center=(21, 26), glow_r=(15, 14))
    e = canvas()
    fx = canvas()
    paw(ImageDraw.Draw(e), 20, 28)
    # saldiri + hareket hizi: iki ust uste yukari ok
    chevron(e, 37, 9, C('#fbffd8'), C('#e6f25a'))
    chevron(e, 37, 16, C('#fbffd8'), C('#c6e03a'))
    # patinin arkasinda ruzgar
    w_hi, w_lo = C('#eaffd0'), C('#5fae4a')
    streak(fx, 4, 11, 20, w_hi, w_lo)
    streak(fx, 3, 9, 30, w_hi, w_lo)
    streak(fx, 5, 11, 38, w_hi, w_lo)
    sparkle(fx, 31, 38, C('#ffffff'), C('#d8ff9a'), 1)
    finish(im, e, fx, "matthew_vahsi_hiz_icon.png")


# ============================================================== R - Feda Kalkani
def feda_kalkani():
    im = tile(C('#3d4f9a'), C('#141a3c'), C('#6b86d8'), C('#a8bcf5'), C('#141a3c'), glow_center=(24, 26), glow_r=(15, 15))
    e = canvas()
    fx = canvas()
    d = ImageDraw.Draw(e)
    L, A, M, D = GOLD
    # kalkan govdesi (tilki kulakli): once altin cerceve, sonra turuncu ic
    outer = [(12, 14), (36, 14), (36, 27), (33, 34), (24, 42), (15, 34), (12, 27)]
    inner = [(14, 16), (34, 16), (34, 27), (31, 33), (24, 40), (17, 33), (14, 27)]
    d.polygon(outer, fill=A)
    d.line((12, 14, 36, 14), fill=L)
    d.line((12, 14, 12, 27), fill=L)
    d.line((36, 15, 36, 27, 33, 34, 24, 42), fill=M)
    d.polygon(inner, fill=FOX_O)
    d.line((14, 16, 34, 16), fill=FOX_L)
    d.line((34, 17, 34, 27, 31, 33, 24, 40), fill=FOX_D)
    # kulaklar kalkanin ust koselerinden cikiyor (yuz haritasiyla ayni kulak)
    fox_face_ears_only(e, 11, 9)
    # yuz: kapali ^ ^ gozler (feda: huzurlu), allik, krem burun bolgesi
    for sx in (-1, 1):
        cx = 24 + sx * 5
        put(e, [(cx, 22), (cx - 1, 23), (cx + 1, 23)], FOX_K)
        put(e, [(24 + sx * 7, 26), (24 + sx * 6, 26)], BLUSH)
    d.polygon([(19, 28), (29, 28), (26, 34), (24, 36), (22, 34)], fill=CREAM)
    d.line((27, 29, 25, 35), fill=CREAM_D)
    put(e, [(23, 29), (24, 29), (25, 29), (24, 30)], FOX_K)
    # hale (feda) - kulaklarin arasinda, kontursuz parlak
    halo, halo_lo = C('#fff6c0'), C('#f2c440')
    for x in range(19, 30):
        put(fx, [(x, 5)], halo if 21 <= x <= 27 else halo_lo)
    put(fx, [(18, 6), (30, 6)], halo_lo)
    for x in range(19, 30):
        put(fx, [(x, 7)], halo_lo)
    sparkle(fx, 8, 38, C('#ffffff'), C('#ffe38a'), 1)
    sparkle(fx, 41, 30, C('#ffffff'), C('#ffe38a'), 1)
    put(fx, [(40, 12), (7, 22)], C('#fff1a8'))
    finish(im, e, fx, "matthew_feda_kalkani_icon.png")


# ============================================================== Pasif - sadik tilki (30 sn'de yeniden dogar)
def pasif():
    im = tile(C('#2f7a6a'), C('#10302c'), C('#58b89a'), C('#9ae6cc'), C('#0e2a26'), glow_center=(24, 22), glow_r=(15, 14))
    e = canvas()
    fx = canvas()
    fox_face(e, 15, 12, "open")
    # yeniden dogus: yuzu saran, ok uclu 3/4 halka (kontursuz, soluk nane)
    ring_hi, ring_lo = C('#f0fff8'), C('#8fe3c4')
    cx, cy, r = 24, 22, 17
    end_deg = 120 + 250
    for i in range(0, 251):
        a = math.radians(120 + i)
        put(fx, [(round(cx + r * math.cos(a)), round(cy + r * math.sin(a)))], ring_hi if i > 140 else ring_lo)
    # ok ucu (halkanin bittigi yerde, saat yonunde): teget yonune bakan dolu ucgen
    a = math.radians(end_deg)
    ex, ey = cx + r * math.cos(a), cy + r * math.sin(a)
    tx, ty = -math.sin(a), math.cos(a)          # saat yonu teget
    nx, ny = math.cos(a), math.sin(a)           # disa normal
    tri = [(ex + tx * 3, ey + ty * 3), (ex + nx * 3 - tx, ey + ny * 3 - ty), (ex - nx * 3 - tx, ey - ny * 3 - ty)]
    ImageDraw.Draw(fx).polygon([(round(x), round(y)) for x, y in tri], fill=ring_hi)
    # kucuk kalp: yaratik sana bagli
    heart_hi, heart = C('#ffc0c8'), C('#ef5a6e')
    hx, hy = 24, 37
    put(e, [(hx - 2, hy), (hx - 1, hy), (hx + 1, hy), (hx + 2, hy),
            (hx - 3, hy + 1), (hx - 2, hy + 1), (hx - 1, hy + 1), (hx, hy + 1), (hx + 1, hy + 1), (hx + 2, hy + 1), (hx + 3, hy + 1),
            (hx - 2, hy + 2), (hx - 1, hy + 2), (hx, hy + 2), (hx + 1, hy + 2), (hx + 2, hy + 2),
            (hx - 1, hy + 3), (hx, hy + 3), (hx + 1, hy + 3), (hx, hy + 4)], heart)
    put(e, [(hx - 2, hy + 1)], heart_hi)
    sparkle(fx, 40, 9, C('#ffffff'), C('#bff5e2'), 1)
    finish(im, e, fx, "matthew_passive_icon.png")


if __name__ == "__main__":
    print("Matthew ikonlari:")
    tilki_hucumu()
    vahsi_hiz()
    feda_kalkani()
    pasif()
