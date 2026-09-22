#!/usr/bin/env python3
"""Korsan'in 3. yetenegi (Bombardiman, skill3 id 34, R tusu) icin EKSIK olan skill ikonunu uretir.

Kullanici bildirimi (2026-09-22): "Korsanin ultisinin skill ikonu yok yeniden tasarla" - characters.gd DEFS[9]'de
skill3 icin "skill3_icon" anahtari hic yoktu (skill/skill2'nin aksine), HUD'da bos/placeholder kaliyordu.

Sablon, Korsan'in var olan 3 ikonuyle (korsan_patlat_icon.png, korsan_saatli_bomba_icon.png, korsan_passive_icon.png)
AYNI: 128x128, disardan icariye 4px seffaf pay + 4px siyah halka + 4px renkli (karaktere ozel) halka + 4px siyah
halka + koyu sicak-gri ic disk. Renkli halka Bombardiman icin KOYU KIRMIZI (topcu/tehlike rengi) - kardes
ikonlardan (bronz/turuncu/altin) farkli ama ailenin sicak paletinde kaliyor.

Icerik: yerde kesikli kirmizi hedef isareti (fx_korsan_strike.gd'deki gercek efektle AYNI dil: daralan halka +
kose centigi + arti) + gokten dusen top mermileri (buyugu az sonra vuracak, ikisi arkada daha yuksekte) + her
birinin arkasinda duz, kisalan bir ates/duman izi. Tum icerik CONTENT_R disina TASMAYACAK sekilde kirpilir.

Kullanim: python tools/gen_korsan_bombardment_icon.py
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "skills", "korsan_bombardiman_icon.png")
N = 128
CX, CY = 64, 64

OUTER_R = 60
RING1 = 56  # siyah -> renkli sinir
RING2 = 52  # renkli -> siyah sinir
CONTENT_R = 48

BLACK = (10, 10, 12, 255)
RING_COLOR = (196, 40, 28, 255)  # koyu kirmizi (topcu/tehlike) - bronz(bomba)/turuncu(patlat)/altin(pasif)'ten farkli
BG = (52, 40, 36, 255)


def dist(x, y):
    return math.hypot(x + 0.5 - CX, y + 0.5 - CY)


def badge_base():
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    px = im.load()
    for y in range(N):
        for x in range(N):
            d = dist(x, y)
            if d > OUTER_R:
                continue
            if d > RING1:
                px[x, y] = BLACK
            elif d > RING2:
                px[x, y] = RING_COLOR
            elif d > CONTENT_R:
                px[x, y] = BLACK
            else:
                px[x, y] = BG
    return im


def fire_color(t):
    stops = [
        (255, 245, 178), (255, 199, 56), (255, 128, 26), (230, 51, 15), (115, 20, 15),
    ]
    t = max(0.0, min(1.0, t)) * (len(stops) - 1)
    i = min(int(t), len(stops) - 2)
    f = t - i
    a, b = stops[i], stops[i + 1]
    return tuple(int(a[k] + (b[k] - a[k]) * f) for k in range(3)) + (255,)


def blk(px, x0, y0, w, h, col):
    """CONTENT_R disina tasan pikselleri ATLAR - ic disk kenari her zaman temiz kalir."""
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            if 0 <= x < N and 0 <= y < N and dist(x, y) <= CONTENT_R:
                px[x, y] = col


def draw_reticle(px, cx, cy, r):
    """fx_korsan_strike.gd'deki hedef isaretiyle AYNI dil: kesikli halka + 4 kose centigi + merkez arti."""
    ry = r * 0.55
    steps = 90
    for i in range(steps):
        if i % 5 >= 3:
            continue  # kesikli
        a = math.tau * i / steps
        x = int(round(cx + math.cos(a) * r))
        y = int(round(cy + math.sin(a) * ry))
        blk(px, x - 1, y - 1, 2, 2, RING_COLOR)
    for qi in range(4):
        a = qi * math.pi / 2 + math.pi / 4
        x = int(round(cx + math.cos(a) * (r + 4)))
        y = int(round(cy + math.sin(a) * (ry + 3)))
        blk(px, x - 1, y - 1, 3, 3, RING_COLOR)
    for (dx, dy, w, h) in ((-4, 0, 3, 2), (2, 0, 3, 2), (0, -4, 2, 3), (0, 2, 2, 3)):
        blk(px, cx + dx, cy + dy, w, h, (255, 214, 100, 255))


SHELL = [
    "..ooo..",
    ".ommmo.",
    "ommhmmo",
    "ommmmmo",
    ".ommmo.",
    "..ooo..",
]


def draw_shell(px, cx, cy, scale):
    """Kucuk top mermisi (fx_korsan_strike.gd SHELL_ART ile AYNI ruh): koyu govde + parlak vurgu, dikey (dusuyor)."""
    pal = {"o": (14, 12, 16, 255), "m": (46, 44, 56, 255), "h": (150, 148, 168, 255)}
    h = len(SHELL)
    w = len(SHELL[0])
    for yy in range(h):
        for xx in range(w):
            ch = SHELL[yy][xx]
            if ch not in pal:
                continue
            ox = int(round((xx - w / 2.0) * scale))
            oy = int(round((yy - h / 2.0) * scale))
            sz = max(1, int(round(scale)))
            blk(px, cx + ox, cy + oy, sz, sz, pal[ch])


def draw_trail(px, cx, cy, length, width, seed):
    """Mermiden yukari-geriye uzanan DUZ, incelen/solan ates izi (dagitilmis nokta bulutu degil)."""
    steps = max(4, int(length / 3))
    for i in range(steps):
        f = i / steps
        x = cx + int(round(math.sin(seed + f * 2.4) * width * 0.5 * f))
        y = cy - int(round(2 + i * 3))
        col = fire_color(0.1 + f * 0.8)
        sz = max(1, int(round(width * (1.0 - f * 0.65))))
        blk(px, x - sz // 2, y - sz // 2, sz, sz, col)


def build():
    im = badge_base()
    px = im.load()
    # 1) yerde hedef isareti (asagi-orta) - mermilerin vuracagi nokta
    draw_reticle(px, CX, CY + 22, 22)
    # 2) az sonra vuracak buyuk mermi (merkeze en yakin) + izi
    draw_trail(px, CX - 2, CY - 4, 34, 5, 0.6)
    draw_shell(px, CX - 2, CY - 4, 3.4)
    # 3) arkada, daha yuksekte/kucuk iki mermi (henuz dusuyor) + izleri
    draw_trail(px, CX - 20, CY - 26, 22, 3, 2.1)
    draw_shell(px, CX - 20, CY - 26, 2.1)
    draw_trail(px, CX + 18, CY - 22, 22, 3, 4.0)
    draw_shell(px, CX + 18, CY - 22, 2.1)
    return im


if __name__ == "__main__":
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    build().save(OUT)
    print("yazildi ->", os.path.abspath(OUT))
