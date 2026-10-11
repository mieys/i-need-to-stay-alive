"""Üst-orta boss çubuğu - 3. TUR: 4 yeni prototip (2026-10-10, kullanıcı: "hafif rpg tarzı, can barı kırmızı kalkan barı mavi,
fazla karmaşık olmayan fakat boss barı olduğunu hissettirmeli").
İlkeler: ağır ahşap plaket yok, bar'ın kendisi ön planda; boss hissini TEK bir küçük öğe verir (mücevher uçlar / kafatası madalyonu /
boynuzlar / sancak). Can her zaman kırmızı, kalkan her zaman mavi, ikisinde de sayı. Kırmızının arkasında açık renkli "son hasar izi".
1 art px = 3 ekran px, m5x7 1x yazı, oyun kitinin paleti.

R1 Mücevherli Demir - ince koyu demir çerçeve, iki ucunda altın çerçeveli kırmızı mücevher, isim altın süslü çizgilerin ortasında
R2 Kafatası Madalyonu - solda büyük yuvarlak kafatası madalyonu, çubuklar sağa doğru bıçak ucu gibi sivrilir, isim çubuğun üstünde sola yaslı
R3 Boynuzlu - iki yanda yukarı kıvrılan kemik boynuzlar, ortada küçük isim sekmesi
R4 Sancak - üstte çatallı kırmızı kumaş sancakta isim, altın çerçeve, çubukların solunda küçük kalkan + kalp simgesi
"""
import math
from art import *

TRAIL = hexc("#d98670")      # son hasar izi (kırmızının arkasındaki açık şerit)
TRACK_RED = hexc("#2a0f10")
GEM_HI = hexc("#ffb3a0")


def fmt(n):
    return f"{int(round(n)):,}".replace(",", ".")


def label(a, x, y, w, h, cur, mx):
    s = f"{fmt(cur)} / {fmt(mx)}"
    tw = a.text_width(s)
    a.text(x + (w - tw) // 2, y + (h - 7) // 2, s, CREAM, outline=OUT2)


def ticks(a, x, y, w, h, n=10, alpha=0.35, full_w=None):
    fw = full_w or w
    for i in range(1, n):
        tx = x + round(fw * i / n)
        if tx >= x + w - 1:
            break
        for yy in range(y, y + h):
            a.shade(tx, yy, OUT2, alpha)


def hp_bar(a, x, y, w, h, hp, trail, track=TRACK_RED):
    a.rect(x, y, w, h, track)
    tw = int(round(w * min(1.0, hp + trail)))
    if trail > 0 and tw > 0:
        a.rect(x, y, tw, h, TRAIL)
    fill_bar_noframe(a, x, y, w, h, hp, HP_BANDS)
    ticks(a, x, y, int(round(w * max(0.0, hp))), h, n=10, full_w=w)


def sh_bar(a, x, y, w, h, sh):
    a.rect(x, y, w, h, EMPTY_BLUE)
    fill_bar_noframe(a, x, y, w, h, sh, SH_BANDS)


def fill_bar_noframe(a, x, y, w, h, ratio, bands):
    fw = int(round(w * max(0.0, min(1.0, ratio))))
    if ratio > 0 and fw < 1:
        fw = 1
    if fw > 0:
        vgrad(a, x, y, fw, h, bands)
        if fw < w:
            a.vline(x + fw - 1, y, h, bands[0])


def outline_layer(layer, color):
    """Saydam olmayan piksellerin 4-komşu dış çevresine 1 px anahat."""
    src = [[layer.px[x, y][3] for x in range(layer.w)] for y in range(layer.h)]
    for y in range(layer.h):
        for x in range(layer.w):
            if src[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < layer.w and 0 <= yy < layer.h and src[yy][xx]:
                    layer.px[x, y] = color
                    break


def gem(a, cx, cy):
    """9x9 altın çerçeveli kırmızı mücevher (eşkenar dörtgen)."""
    for dy in range(-4, 5):
        r = 4 - abs(dy)
        for dx in range(-r, r + 1):
            d = abs(dx) + abs(dy)
            if d == 4:
                c = OUT2
            elif d == 3:
                c = GOLD_L if dy < 0 or (dy == 0 and dx < 0) else GOLD_D
            else:
                c = RED_L if (dx + dy) < 0 else RED_M
            a.set(cx + dx, cy + dy, c)
    a.set(cx - 1, cy - 1, GEM_HI)


# ------------------------------------------------------------------ R1 Mücevherli Demir
def top_r1(name, hp, sh, hp_max, sh_max, trail=0.0, W=224):
    H = 37
    a = Art(W, H)
    # isim satırı: ortada isim, iki yanda altın çizgi + elmas
    tw = a.text_width(name)
    nx = (W - tw) // 2
    a.text(nx, 2, name, CREAM, outline=OUT2)
    for side in (-1, 1):
        x0 = nx - 6 if side < 0 else nx + tw + 5
        a.set(x0, 5, GOLD_L)
        a.set(x0 + side, 5, GOLD)
        a.set(x0, 4, GOLD)
        a.set(x0, 6, GOLD_D)
        for i in range(3, 46):
            c = GOLD if i < 30 else GOLD_D
            if i >= 40 and i % 2:
                continue
            a.set(x0 + side * i, 5, c)
            a.set(x0 + side * i, 6, OUT2)
    # çerçeve
    fx, fy, fw, fh = 7, 11, W - 14, 25
    a.rrect(fx, fy, fw, fh, OUT2)
    a.rect(fx + 1, fy + 1, fw - 2, fh - 2, IRON_D)
    a.hline(fx + 2, fy + 1, fw - 4, IRON_L)
    a.hline(fx + 2, fy + fh - 2, fw - 4, hexc("#17141c"))
    bx, bw = fx + 3, fw - 6
    sh_bar(a, bx, fy + 2, bw, 9, sh)
    a.hline(bx, fy + 11, bw, OUT2)
    hp_bar(a, bx, fy + 12, bw, 11, hp, trail)
    label(a, bx, fy + 2, bw, 9, sh * sh_max, sh_max)
    label(a, bx, fy + 12, bw, 11, hp * hp_max, hp_max)
    # uçlarda mücevher
    gem(a, 5, fy + fh // 2)
    gem(a, W - 6, fy + fh // 2)
    return a


# ------------------------------------------------------------------ R2 Kafatası Madalyonu
BIG_SKULL = [
    "...XXXXXXX...",
    "..XWWWWWWWX..",
    ".XWWWWWWWWWX.",
    "XWWWWWWWWWWWX",
    "XWKKKWWWKKKWX",
    "XWKKKWWWKKKWX",
    "XWKKWWWWWKKWX",
    ".XWWWWKWWWWX.",
    "..XWWKKKWWX..",
    "..XWWWWWWWX..",
    "..XWXWXWXWX..",
    "...XXXXXXX...",
]


def top_r2(name, hp, sh, hp_max, sh_max, trail=0.0, W=226):
    H = 38
    a = Art(W, H)
    R = 15
    mcx, mcy = 16, 21
    bx0 = 26
    tip = 8
    # çubuk bloğu (sağ ucu bıçak gibi sivri) ayrı katmanda, sonra anahat
    layer = Art(W, H)
    by, bh = 12, 22
    end = W - 2
    layer.rect(bx0 - 6, by, end - (bx0 - 6), bh, IRON_D)
    sh_bar(layer, bx0, by + 1, end - bx0 - tip, 9, sh)
    hp_bar(layer, bx0, by + 11, end - bx0 - tip, 10, hp, trail)
    layer.hline(bx0, by + 10, end - bx0 - tip, OUT2)
    # sivri uç: son `tip` sütunda dikey olarak daralır
    for i in range(tip):
        x = end - tip + i
        half = (bh / 2) * (1 - (i + 1) / (tip + 1))
        for yy in range(by, by + bh):
            if abs(yy + 0.5 - (by + bh / 2)) > half:
                layer.set(x, yy, CLEAR)
            else:
                layer.set(x, yy, IRON if yy < by + bh / 2 else IRON_D)
    for x in range(end - tip - 1, end):
        layer.set(x, by + bh // 2 - 1, IRON_L)
    outline_layer(layer, OUT2)
    a.paste(layer, 0, 0)
    a.hline(bx0, by, end - bx0 - tip, IRON_L)
    label(a, bx0, by + 1, end - bx0 - tip, 9, sh * sh_max, sh_max)
    label(a, bx0, by + 11, end - bx0 - tip, 10, hp * hp_max, hp_max)
    # isim: çubuğun üstünde, madalyonun sağında
    a.text(bx0 + 6, 2, name, CREAM, outline=OUT2)
    # madalyon
    for (x, y, d) in circle_points(mcx, mcy, R):
        if d <= R:
            if d > R - 1.2:
                c = OUT2
            elif d > R - 3.2:
                ang = math.atan2(y + 0.5 - mcy, x + 0.5 - mcx)
                c = GOLD_L if -2.6 < ang < -0.6 else (GOLD_D if 0.6 < ang < 2.6 else GOLD)
            elif d > R - 4.2:
                c = OUT2
            else:
                c = RED_M if y < mcy - 3 else RED_D
            a.set(x, y, c)
    a.blit(BIG_SKULL, {"X": OUT2, "W": BONE, "K": OUT2}, mcx - 6, mcy - 6)
    a.set(mcx - 4, mcy + 1, BONE_D)
    a.set(mcx + 4, mcy + 1, BONE_D)
    return a


# ------------------------------------------------------------------ R3 Boynuzlu
HORN = [
    "X...............",
    "XX..............",
    "XWX.............",
    "XWWX............",
    ".XWWX...........",
    ".XWWWX..........",
    ".XDWWWX.........",
    "..XDWWWX........",
    "..XDWWWWX.......",
    "..XDDWWWWX......",
    "...XDDWWWWXX....",
    "...XDDDWWWWWXX..",
    "....XDDDWWWWWWXX",
    ".....XXDDDDWWWWX",
    ".......XXXDDDDDX",
    "..........XXXXXX",
]


def top_r3(name, hp, sh, hp_max, sh_max, trail=0.0, W=232):
    H = 38
    a = Art(W, H)
    fx, fw = 16, W - 32
    fy, fh = 12, 25
    # boynuzlar (çerçevenin arkasında)
    pal = {"X": OUT2, "W": BONE, "D": BONE_D}
    hl = Art(16, 16)
    hl.blit(HORN, pal, 0, 0)
    for y in (5, 9, 12):  # halka çizgileri
        for x in range(16):
            if hl.px[x, y][3] and hl.px[x, y] != OUT2:
                hl.px[x, y] = BONE_DD
    a.paste(hl, fx - 12, fy - 9)
    hr = Art(16, 16)
    hr.im = hl.im.transpose(Image.FLIP_LEFT_RIGHT)
    hr.px = hr.im.load()
    a.paste(hr, fx + fw - 4, fy - 9)
    # çerçeve
    a.rrect(fx, fy, fw, fh, OUT2)
    a.rect(fx + 1, fy + 1, fw - 2, fh - 2, TRACK2)
    a.hline(fx + 2, fy + 1, fw - 4, hexc("#4a2c22"))
    bx, bw = fx + 3, fw - 6
    sh_bar(a, bx, fy + 2, bw, 9, sh)
    a.hline(bx, fy + 11, bw, OUT2)
    hp_bar(a, bx, fy + 12, bw, 11, hp, trail)
    label(a, bx, fy + 2, bw, 9, sh * sh_max, sh_max)
    label(a, bx, fy + 12, bw, 11, hp * hp_max, hp_max)
    # isim sekmesi
    tw = a.text_width(name)
    sk = skull()
    tabw = tw + 9 + 10
    tx = (W - tabw) // 2
    a.rrect(tx, 0, tabw, 13, OUT2)
    a.rect(tx + 1, 1, tabw - 2, 12, TRACK2)
    a.hline(tx + 2, 1, tabw - 4, hexc("#4a2c22"))
    a.paste(sk, tx + 3, 2)
    a.text(tx + 15, 3, name, CREAM)
    return a


# ------------------------------------------------------------------ R4 Sancak
SHIELD_ICON = [
    "XXXXXXX",
    "XLLLBBX",
    "XLBBBBX",
    "XLBBBDX",
    ".XBBDX.",
    "..XDX..",
    "...X...",
]
HEART_ICON = [
    ".XX.XX.",
    "XLLXRRX",
    "XLRRRRX",
    "XRRRRMX",
    ".XRRMX.",
    "..XMX..",
    "...X...",
]


def top_r4(name, hp, sh, hp_max, sh_max, trail=0.0, W=224):
    H = 38
    a = Art(W, H)
    fx, fy, fw, fh = 0, 10, W, 27
    # altın çerçeve
    a.rrect(fx, fy, fw, fh, OUT)
    a.rect(fx + 1, fy + 1, fw - 2, fh - 2, GOLD)
    a.hline(fx + 1, fy + 1, fw - 2, GOLD_L)
    a.hline(fx + 1, fy + fh - 2, fw - 2, GOLD_D)
    a.vline(fx + fw - 2, fy + 1, fh - 2, GOLD_D)
    a.rect(fx + 2, fy + 2, fw - 4, fh - 4, OUT)
    a.rect(fx + 3, fy + 3, fw - 6, fh - 6, TRACK2)
    for (rx, ry) in ((fx + 1, fy + 1), (fx + fw - 2, fy + 1), (fx + 1, fy + fh - 2), (fx + fw - 2, fy + fh - 2)):
        a.set(rx, ry, CREAM)
    # simgeler
    a.blit(SHIELD_ICON, {"X": OUT2, "L": BLUE_HI, "B": BLUE_L, "D": BLUE}, fx + 5, fy + 4)
    a.blit(HEART_ICON, {"X": OUT2, "L": RED_HI, "R": RED_L, "M": RED}, fx + 5, fy + 15)
    bx, bw = fx + 15, fw - 18
    sh_bar(a, bx, fy + 3, bw, 9, sh)
    a.hline(bx, fy + 12, bw, OUT)
    hp_bar(a, bx, fy + 13, bw, 11, hp, trail)
    a.vline(bx - 1, fy + 3, 21, OUT)
    label(a, bx, fy + 3, bw, 9, sh * sh_max, sh_max)
    label(a, bx, fy + 13, bw, 11, hp * hp_max, hp_max)
    # sancak (isim) - çatallı kuyruklar arkada
    tw = a.text_width(name)
    bw2 = tw + 16
    sx = (W - bw2) // 2
    for side in (-1, 1):
        tx0 = sx - 7 if side < 0 else sx + bw2 - 1
        tail = Art(8, 12)
        for yy in range(1, 11):
            for xx in range(8):
                notch = (yy >= 4 and yy <= 7 and (xx if side < 0 else 7 - xx) < 2 + (1 - abs(yy - 5.5) // 1))
                if not notch:
                    tail.set(xx, yy, RED_M if yy < 9 else RED_D)
        outline_layer(tail, OUT2)
        a.paste(tail, tx0, 1)
    a.rrect(sx, 0, bw2, 13, OUT2)
    a.rect(sx + 1, 1, bw2 - 2, 11, RED)
    a.hline(sx + 1, 1, bw2 - 2, RED_L)
    a.hline(sx + 1, 11, bw2 - 2, RED_M)
    a.text(sx + 8, 3, name, CREAM, outline=RED_D)
    return a


TOPS = {
    "r1": ("R1 Mücevherli Demir", top_r1),
    "r2": ("R2 Kafatası Madalyonu", top_r2),
    "r3": ("R3 Boynuzlu", top_r3),
    "r4": ("R4 Sancak", top_r4),
}
