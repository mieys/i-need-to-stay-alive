"""Üst-orta boss çubuğu - 2. TUR: 4 yeni prototip (2026-10-09, kullanıcı: "şuanki çok ai duruyor").
Şikayet: T1 Ahşap Plaket simetrik/temiz/"kit çerçevesi" gibiydi. Bu tur ilkeler: asimetri, aşınmış/kırık kenarlar, malzemeye özgü doku, dolgunun ucunda malzemeye özgü davranış
(kan menisküsü, mürekkep sıçraması...), çerçeveyi bar'ın kendisinden türetmek, ince dekor. Hepsi kodla çizilir, 1 art px = 3 ekran px, m5x7 1x yazı, oyun kitinin paleti.

P1 Yosunlu Taş   - kırık kenarlı oyma taş levha, sarkan sarmaşık/yosun, can = taşa oyulmuş kan oluğu, kalkan = ince buz kristali oluğu
P2 Mürekkep Rulo - uçları kıvrık yırtık parşömen, can = fırça darbesi mürekkep (sıçrayan uç), kalkan = mavi mürekkep şeridi, kırmızı mühür
P3 Cam Tüp       - pirinç başlıklı iki cam tüp (alkimya): can = kırmızı sıvı + meniskus + kabarcık, kalkan = üstte mavi sıvı, ölçü çizgileri
P4 Omurga        - çerçevesiz: 10 omurdan oluşan bir kemik zinciri (can) + üstünde 10 kaburga yayı (kalkan); hasar alan omur kırılır
"""
import math
import random
from art import *

GREEN_D = hexc("#25421d")
GREEN = hexc("#3f6b2e")
GREEN_L = hexc("#5e8f3a")
GREEN_HI = hexc("#8bb84f")
STONE_OUT = hexc("#1c1b22")
STONE_D = hexc("#34333d")
STONE = hexc("#4b4a55")
STONE_M = hexc("#5f5d6a")
STONE_L = hexc("#7b7886")
STONE_HI = hexc("#9a96a6")
ICE_HI = hexc("#d8fff8")
ICE_L = hexc("#7fe0d6")
ICE = hexc("#3aa7b5")
ICE_D = hexc("#1e5f73")
ICE_EMPTY = hexc("#13303c")
INK_RED_HI = hexc("#c5453a")
INK_RED = hexc("#9a2a2c")
INK_RED_D = hexc("#6e1a20")
INK_BLUE = hexc("#2c5a98")
INK_BLUE_D = hexc("#1c3c6a")
INK_BLUE_L = hexc("#4f86c8")
WAX = hexc("#9c1f2a")
WAX_L = hexc("#c4373f")
WAX_D = hexc("#5f1118")
PAPER = hexc("#d5b988")
PAPER_HI = hexc("#e6cfa3")
PAPER_SH = hexc("#b89763")
PAPER_DD = hexc("#8f7348")
GLASS_OUT = hexc("#141b26")
GLASS = hexc("#25334a")
GLASS_L = hexc("#3b5070")
GLASS_HI = hexc("#bfd8f2")
BRASS_HI = hexc("#e0c876")
BRASS = hexc("#b78b2a")
BRASS_D = hexc("#7a5a16")
BRASS_DD = hexc("#4b3510")
LIQ_HI = hexc("#ff9e84")
LIQ = hexc("#d2413a")
LIQ_D = hexc("#8c1a25")
LIQB_HI = hexc("#a8dcff")
LIQB = hexc("#4c8ede")
LIQB_D = hexc("#244a8a")


def fmt(n):
    s = f"{int(n):,}".replace(",", ".")
    return s


def num_text(a, cx, y, cur, mx, color=CREAM, outline=OUT, align="center"):
    s = f"{fmt(cur)}/{fmt(mx)}"
    w = a.text_width(s)
    x = cx - w // 2 if align == "center" else cx
    a.text(x, y, s, color, outline=outline)


def jitter(seed, n, lo=0, hi=1):
    r = random.Random(seed)
    return [r.randint(lo, hi) for _ in range(n)]


# =============================================================== P1 Yosunlu Taş
def top_p1(name, hp, sh, hp_max, sh_max, W=232):
    H = 46
    a = Art(W, H)
    top_off = jitter(11, W, 0, 2)
    bot_off = jitter(23, W, 0, 2)
    # sağ uç kırık (köşe çapraz kopuk), sol uç basamaklı
    y0, y1 = 9, 43
    for x in range(W):
        lo = y0 + top_off[x] + (0 if x > 3 else (3 - x))
        hi = y1 - bot_off[x] - (0 if x < W - 9 else (x - (W - 9)) // 2 + 1)
        lo += (2 if x > W - 26 and x % 7 < 2 else 0)
        for y in range(lo, hi):
            a.set(x, y, STONE)
    # kenar çizgisi: dış piksellere koyu anahat (4-komşu)
    base = {(x, y) for x in range(W) for y in range(H) if a.get(x, y)[3]}
    for (x, y) in base:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in base:
                a.set(x + dx, y + dy, STONE_OUT)
    # aydınlık üst/sol, gölge alt/sağ (taş yüzü) + damar noktaları
    rnd = random.Random(5)
    for (x, y) in sorted(base):
        up = (x, y - 1) not in base
        down = (x, y + 1) not in base
        left = (x - 1, y) not in base
        if up or left:
            a.set(x, y, STONE_L)
        elif y - 1 >= 0 and (x, y - 2) not in base and rnd.random() < 0.7:
            a.set(x, y, STONE_M)
        if down:
            a.set(x, y, STONE_D)
        elif rnd.random() < 0.035:
            a.set(x, y, STONE_M if rnd.random() < 0.6 else STONE_D)
    # çatlak (barlara girmeden sağ tarafta)
    cx = W - 30
    for i, dy in enumerate([0, 1, 1, 2, 1, 2, 2]):
        yy = y0 + 4 + i * 2
        a.set(cx - (i % 3), yy, STONE_OUT)
        a.set(cx - (i % 3) + 1, yy + 1, STONE_D)
    # oyma kafatası halkası (sol)
    sx, sy = 8, 17
    a.rect(sx, sy, 17, 17, STONE_OUT)
    a.rect(sx + 1, sy + 1, 15, 15, STONE_D)
    a.hline(sx + 1, sy + 15, 15, STONE_M)
    a.vline(sx + 15, sy + 1, 15, STONE_M)
    a.paste(skull(BONE_D, BONE_DD, STONE_OUT, STONE_OUT), sx + 4, sy + 4)
    # isim (oyma: üstte koyu, altta açık)
    nx, ny = 31, 11
    a.text(nx, ny + 1, name, STONE_OUT)
    a.text(nx, ny, name, hexc("#d8d2c0"))
    # kalkan oluğu (ince, buz kristali) ve can oluğu (kan)
    gx, gw = 31, W - 31 - 9
    sy2, hy2 = 22, 30
    a.rect(gx - 1, sy2 - 1, gw + 2, 7, STONE_OUT)
    a.rect(gx, sy2, gw, 5, ICE_EMPTY)
    fw = int(round(gw * sh))
    if fw > 0:
        for yy, c in enumerate([ICE_HI, ICE_L, ICE, ICE, ICE_D]):
            a.hline(gx, sy2 + yy, fw, c)
        # buz ucu: tırtıklı kristal
        for k in range(3):
            a.set(gx + fw - 1 - k, sy2 + (k % 2), ICE_HI if k == 0 else ICE_L)
        for k in range(0, fw - 2, 7):
            a.set(gx + k + 2, sy2 + 1, ICE_HI)
    a.rect(gx - 1, hy2 - 1, gw + 2, 11, STONE_OUT)
    a.rect(gx, hy2, gw, 9, TRACK)
    a.hline(gx, hy2 + 8, gw, TRACK2)
    fw = int(round(gw * hp))
    if hp > 0 and fw < 2:
        fw = 2
    if fw > 0:
        for yy, c in enumerate([RED_L, RED, RED, RED_M, RED_M, RED_M, RED_D, RED_D, RED_D]):
            a.hline(gx, hy2 + yy, fw, c)
        a.hline(gx, hy2, fw, RED_HI)
        # kanın ucu: oluğun içinde tırtıklı, kurumuş kenar
        if fw < gw:
            for k, (yy, c) in enumerate([(0, RED_M), (2, RED_D), (4, RED_M), (6, RED_D), (8, RED_M)]):
                a.set(gx + fw, hy2 + yy, c)
                a.set(gx + fw - 1, hy2 + yy + 1, RED_HI if k % 2 == 0 else RED_L)
    # yosun öbekleri (üst kenarda): 2-4 px yüksek, parlak uçlu; bir de sol köşede büyük bir küme
    mr = random.Random(9)
    for mx, span in ((9, 15), (44, 9), (86, 12), (128, 8), (163, 13), (201, 11)):
        for i in range(span):
            x = mx + i
            top = y0 + top_off[min(x, W - 1)]
            hump = int(2.2 * math.sin(math.pi * (i + 0.5) / span)) + (1 if mr.random() < 0.4 else 0)
            for k in range(max(1, hump)):
                a.set(x, top - k, GREEN_L if k else GREEN)
            a.set(x, top - max(1, hump), GREEN_HI if mr.random() < 0.6 else GREEN_L)
            a.set(x, top + 1, GREEN_D)
    for vx, vlen in ((20, 20), (62, 9), (117, 14), (185, 17)):
        top = y0 + top_off[vx]
        for i in range(vlen):
            sway = 1 if (i // 4) % 2 else 0
            a.set(vx + sway, top + i, GREEN_D)
            if i % 4 == 1:
                a.set(vx - 1 + sway, top + i, GREEN)
                a.set(vx - 2 + sway, top + i + 1, GREEN_L)
            if i % 4 == 3:
                a.set(vx + 1 + sway, top + i, GREEN_L)
                a.set(vx + 2 + sway, top + i + 1, GREEN_HI)
    # taş blok dikişleri (düzensiz): okunur bir duvar hissi
    for sx0, sy0, ln in ((28, 17, 40), (92, 40, 36), (150, 17, 30), (60, 40, 20)):
        for i in range(ln):
            yy = sy0 + (1 if (i // 9) % 3 == 1 else 0)
            if a.get(sx0 + i, yy) == STONE_L or a.get(sx0 + i, yy) == STONE_M or a.get(sx0 + i, yy) == STONE:
                a.set(sx0 + i, yy, STONE_D)
    # sayılar (oluk üstünde)
    num_text(a, gx + gw // 2, hy2 + 1, hp * hp_max, hp_max)
    if sh > 0 or True:
        pass
    return a


# =============================================================== P2 Mürekkep Rulo
def top_p2(name, hp, sh, hp_max, sh_max, W=232):
    H = 46
    a = Art(W, H)
    rr = random.Random(31)
    bw0, bw1 = 11, W - 11
    top_w = jitter(2, W, 0, 1)
    bot_w = jitter(4, W, 0, 2)
    y0, y1 = 8, 38
    for x in range(bw0, bw1):
        lo = y0 + top_w[x]
        hi = y1 - bot_w[x] - (2 if (x // 9) % 5 == 3 else 0)
        for y in range(lo, hi):
            a.set(x, y, PAPER)
    # yırtık alt kenar: kahve anahat + gölge
    paper = {(x, y) for x in range(W) for y in range(H) if a.get(x, y)[3]}
    for (x, y) in list(paper):
        if (x, y + 1) not in paper:
            a.set(x, y, PAPER_SH)
            a.set(x, y + 1, PAPER_DD)
        if (x, y - 1) not in paper:
            a.set(x, y, PAPER_HI)
    # lif/leke noktaları
    for _ in range(70):
        x, y = rr.randint(bw0, bw1 - 1), rr.randint(y0 + 2, y1 - 4)
        if (x, y) in paper and a.get(x, y) == PAPER:
            a.set(x, y, PAPER_SH if rr.random() < 0.7 else PAPER_HI)
    # kıvrık uç silindirleri (sol/sağ)
    for (cx0, flip) in ((0, False), (W - 12, True)):
        for y in range(y0 - 1, y1 + 1):
            for x in range(12):
                inner = x if not flip else 11 - x
                c = [PAPER_DD, PAPER_SH, PAPER, PAPER_HI, PAPER_HI, PAPER, PAPER_SH, PAPER_SH, PAPER_DD, PAPER_DD, OUT, OUT][inner]
                if inner <= 1 or inner >= 10:
                    c = OUT if inner in (0, 11) else PAPER_DD
                a.set(cx0 + x, y, c)
        # halka (kesit): üst ve alt
        for x in range(12):
            a.set(cx0 + x, y0 - 1, OUT)
            a.set(cx0 + x, y1, OUT)
        for k in range(3):
            a.set(cx0 + (5 if not flip else 6) + (k - 1), y0 + 3 + k * 8, PAPER_DD)
    # isim (mürekkep) + altında el çizimi dalgalı çizgi + küçük baklava
    tw = a.text_width(name)
    nx = 34
    a.text(nx, 11, name, INK)
    for i in range(tw + 6):
        a.set(nx - 2 + i, 20 + (1 if (i // 3) % 2 else 0), INK)
    a.set(nx + tw + 6, 19, INK)
    a.set(nx + tw + 7, 20, INK)
    a.set(nx + tw + 6, 21, INK)
    # mavi mürekkep kalkan şeridi
    gx, gw = 34, bw1 - 34 - 8
    sy = 23
    for x in range(gw):
        a.set(gx + x, sy + 6, PAPER_SH if x % 4 else PAPER_DD)  # kuru rehber çizgisi
    fw = int(round(gw * sh))
    for x in range(fw):
        j = rr.randint(0, 1) if x > fw - 6 else (1 if (x // 11) % 3 == 1 else 0)
        for y in range(sy + 1 - 0, sy + 5 - j):
            a.set(gx + x, y, INK_BLUE_L if y == sy + 1 else INK_BLUE if y < sy + 4 else INK_BLUE_D)
    if fw > 0:
        for (dx, dy) in ((fw + 2, 1), (fw + 4, 3), (fw + 5, 0)):
            a.set(gx + dx, sy + dy, INK_BLUE)
    # kırmızı fırça darbesi can
    hy = 29
    for x in range(gw):
        for y in range(hy + 5, hy + 7):
            a.set(gx + x, y + 1, PAPER_SH if x % 3 == 0 else PAPER)
    fw = int(round(gw * hp))
    if hp > 0 and fw < 3:
        fw = 3
    rng2 = random.Random(77)
    prev_top, prev_bot = 0, 0
    for x in range(fw):
        near_end = x > fw - 9
        top_j = rng2.randint(0, 2) if near_end else (1 if (x // 5) % 4 == 2 else 0)
        bot_j = rng2.randint(0, 2) if near_end else (1 if (x // 7) % 5 == 1 else 0)
        for y in range(hy + top_j, hy + 9 - bot_j):
            c = INK_RED_HI if y == hy + top_j else (INK_RED if y < hy + 6 else INK_RED_D)
            a.set(gx + x, y, c)
        if x % 6 == 2:
            a.set(gx + x, hy + 2, INK_RED_D)  # fırça lifi izi
    for (dx, dy) in ((fw + 2, 2), (fw + 5, 5), (fw + 3, 7), (fw + 8, 1)):
        if hp < 0.995:
            a.set(gx + dx, hy + dy, INK_RED)
    s2 = f"{fmt(hp * hp_max)}/{fmt(hp_max)}"
    a.text(gx + gw - a.text_width(s2) - 4, hy + 1, s2, CREAM, outline=INK_RED_D)
    # kırmızı balmumu mühür (kafatası), kağıdın sol alt köşesine biner
    mx, my, r = 24, 30, 9
    for (x, y, d) in circle_points(mx, my, r):
        jr = ((x * 7 + y * 13) % 5) * 0.18
        if d <= r + jr - 0.4:
            a.set(x, y, WAX)
    wax = {(x, y) for x in range(W) for y in range(H) if a.get(x, y) == WAX}
    for (x, y) in wax:
        if (x - 1, y - 1) not in wax or (x, y - 1) not in wax:
            a.set(x, y, WAX_L)
        if (x + 1, y + 1) not in wax or (x, y + 1) not in wax:
            a.set(x, y, WAX_D)
    for (x, y, d) in circle_points(mx, my, 6.5):
        if d <= 6.4 and (x, y) in wax:
            a.set(x, y, WAX_D if d > 5.6 else hexc("#7d1822"))
    a.paste(skull(hexc("#e7b9a5"), hexc("#b87d70"), hexc("#7d1822"), WAX_D), mx - 4, my - 4)
    return a


# =============================================================== P3 Cam Tüp
def tube(a, x, y, w, h, ratio, liquid, name_empty):
    """Yatay cam tüp: içi, sıvı (meniskus + kabarcık), cam parlaması."""
    hi, mid, lo = liquid
    a.rect(x - 1, y - 1, w + 2, h + 2, GLASS_OUT)
    a.rect(x, y, w, h, GLASS)
    a.rect(x, y + h - 2, w, 2, GLASS_L)
    fw = int(round(w * ratio))
    if ratio > 0 and fw < 2:
        fw = 2
    rr = random.Random(int(w * 7 + h))
    if fw > 0:
        for xx in range(fw):
            surf = 0
            if xx > fw - 5:
                surf = (5 - (fw - xx)) // 2  # sıvı ucu bombeli: üst/alt iç içe girer (menisküs)
            for yy in range(surf, h - surf):
                c = lo if yy >= h - 3 else (hi if yy == surf else mid)
                a.set(x + xx, y + yy, c)
        for _ in range(max(2, fw // 24)):
            bx, by = rr.randint(2, max(3, fw - 8)), rr.randint(1, h - 3)
            a.set(x + bx, y + by, hi)
            if rr.random() < 0.5:
                a.set(x + bx + 1, y + by - 1, hi)
    # cam parlaması (üstte kesikli beyaz çizgi) + yan yansıma
    for xx in range(2, w - 2):
        if (xx // 6) % 3 != 2:
            a.shade(x + xx, y + 1, GLASS_HI, 0.55)
    a.shade(x + 1, y + 1, GLASS_HI, 0.8)
    a.vline(x + 1, y + 2, h - 4, GLASS_L if h > 6 else GLASS)
    # ölçü çizgileri alt kenarda
    for i in range(1, 10):
        tx = x + int(w * i / 10)
        a.set(tx, y + h + 1, GLASS_L if i != 5 else GLASS_HI)
        if i == 5:
            a.set(tx, y + h + 2, GLASS_HI)


def cap(a, x, y, h, flip=False):
    """Pirinç başlık (dikey kısa silindir) + perçin."""
    w = 8
    for yy in range(h):
        for xx in range(w):
            ix = xx if not flip else w - 1 - xx
            c = [BRASS_DD, BRASS_HI, BRASS, BRASS, BRASS, BRASS_D, BRASS_D, BRASS_DD][ix]
            a.set(x + xx, y + yy, c)
    a.hline(x, y, w, BRASS_DD)
    a.hline(x, y + h - 1, w, BRASS_DD)
    ry = y + h // 2
    a.set(x + (3 if not flip else 4), ry, BRASS_HI)
    a.set(x + (4 if not flip else 3), ry, BRASS_D)


def top_p3(name, hp, sh, hp_max, sh_max, W=232):
    H = 46
    a = Art(W, H)
    # isim: sol üstte pirinç etiket (zincirle asılı gibi iki ince çizgi)
    tw = a.text_width(name)
    a.rect(10, 0, 1, 5, BRASS_D)
    a.rect(10 + tw + 8, 0, 1, 5, BRASS_D)
    a.rect(8, 5, tw + 13, 11, BRASS_DD)
    a.rect(9, 6, tw + 11, 9, BRASS)
    a.hline(9, 6, tw + 11, BRASS_HI)
    a.hline(9, 14, tw + 11, BRASS_D)
    a.text(14, 7, name, BRASS_DD)
    for nx in (11, tw + 17):
        a.set(nx, 10, BRASS_HI)
        a.set(nx, 11, BRASS_DD)
    # kafatası madalyonu (tüplerin solunda, cam kapaklı)
    a.rect(2, 20, 21, 21, GLASS_OUT)
    for (x, y, d) in circle_points(12.5, 30.5, 10):
        if d <= 10:
            a.set(x, y, BRASS_DD if d > 9 else (BRASS if d > 7.4 else GLASS))
    for (x, y, d) in circle_points(12.5, 30.5, 7.4):
        if d <= 7.4:
            a.set(x, y, hexc("#3a1620") if d > 3 else hexc("#4a1c28"))
    a.paste(skull(), 8, 26)
    for k in range(3):
        a.set(7 + k, 24 - k + 1, GLASS_HI)
    # kalkan tüpü (ince, üstte) ve can tüpü
    tx0 = 31
    tw_ = W - tx0 - 14
    cap(a, tx0 - 8, 19, 12)
    tube(a, tx0, 20, tw_, 10, sh, (LIQB_HI, LIQB, LIQB_D), "")
    cap(a, tx0 + tw_, 19, 12, True)
    cap(a, tx0 - 8, 31, 16)
    tube(a, tx0, 32, tw_, 14 - 2, hp, (LIQ_HI, LIQ, LIQ_D), "")
    cap(a, tx0 + tw_, 31, 16, True)
    num_text(a, tx0 + tw_ // 2, 34, hp * hp_max, hp_max)
    return a


# =============================================================== P4 Omurga (çerçevesiz)
FLAME_O = hexc("#ff8a2a")
FLAME_Y = hexc("#ffd75a")
FLAME_W = hexc("#fff4c8")
FLAME_B = hexc("#4aa0ff")
FLAME_BC = hexc("#c9ecff")
WAX_C = hexc("#e9ddc2")
WAX_CD = hexc("#b9a98a")
WAX_CDD = hexc("#8a7a60")
WOOD_T = hexc("#3b2416")
WOOD_TH = hexc("#5a3922")


def candle(a, x, y_base, fill, shield_lit, shield_part, seed):
    """Tek mum (7 px genişlik): yükseklik = can oranı (en çok 15 px); sönükse kısa kütük + duman. shield_lit: mavi alev; shield_part: küçük mavi alev."""
    w = 7
    if fill <= 0.0:
        # kütük + erimiş mum birikintisi + duman
        a.rect(x + 1, y_base - 2, w - 2, 2, WAX_CD)
        a.hline(x + 1, y_base - 2, w - 2, WAX_C)
        a.rect(x, y_base - 1, w, 1, WAX_CDD)
        a.set(x + 3, y_base - 3, OUT)  # kararmış fitil
        for i, (dx, dy) in enumerate([(3, -5), (4, -7), (3, -9), (2, -11)]):
            a.set(x + dx, y_base + dy, hexc("#8d8d96") if i % 2 == 0 else hexc("#6d6d78"))
        return
    h = 3 + int(round(12 * fill))
    top = y_base - h
    for yy in range(h):
        for xx in range(w):
            c = WAX_C if xx < 4 else WAX_CD
            if xx == 0 or xx == w - 1:
                c = WAX_CD if xx == 0 else WAX_CDD
            a.set(x + xx, top + yy, c)
    a.hline(x, top, w, hexc("#fff6e0"))
    # kenar anahat
    a.vline(x - 1, top + 1, h - 1, OUT)
    a.vline(x + w, top + 1, h - 1, OUT)
    a.hline(x, top - 1, w, OUT)
    # akan mum damlaları
    r = random.Random(seed)
    for k in range(2):
        dx = r.randint(1, w - 2)
        ln = r.randint(2, min(6, h - 2))
        a.vline(x + dx, top + 1, ln, WAX_C)
        a.set(x + dx, top + 1 + ln, hexc("#fff6e0"))
    # fitil + alev
    wx = x + 3
    a.set(wx, top - 2, OUT2)
    a.set(wx, top - 1, OUT2)
    if shield_lit:
        cols = (FLAME_B, FLAME_BC, FLAME_B)
        a.rect(wx - 1, top - 6, 3, 4, FLAME_B)
        a.set(wx, top - 7, FLAME_B)
        a.vline(wx, top - 6, 3, FLAME_BC)
        a.set(wx - 2, top - 4, hexc("#1d4fa0"))
        a.set(wx + 2, top - 4, hexc("#1d4fa0"))
    elif shield_part:
        a.rect(wx - 1, top - 5, 2, 3, FLAME_B)
        a.set(wx, top - 6, FLAME_B)
        a.set(wx - 1, top - 4, FLAME_BC)
    else:
        a.rect(wx - 1, top - 5, 2, 3, FLAME_O)
        a.set(wx, top - 6, FLAME_O)
        a.set(wx, top - 4, FLAME_Y)
        a.set(wx - 1, top - 3, FLAME_Y)
        a.set(wx, top - 3, FLAME_W)


def top_p4(name, hp, sh, hp_max, sh_max, W=232):
    H = 46
    a = Art(W, H)
    # sol: karartılmış tabela (kafatası + isim)
    tw = a.text_width(name)
    a.rect(0, 3, tw + 23, 12, OUT)
    a.rect(1, 4, tw + 21, 10, WOOD_T)
    a.hline(1, 4, tw + 21, WOOD_TH)
    a.paste(skull(), 4, 5)
    a.text(16, 5, name, CREAM)
    # mum sırası: 10 mum, altında uzun koyu ahşap/pirinç tepsi
    n = 10
    gx = 8
    step = (W - gx * 2) // n
    base_y = 36
    for i in range(n):
        lo, hi = i / n, (i + 1) / n
        f = 0.0 if hp <= lo else (1.0 if hp >= hi else (hp - lo) * n)
        lit = sh >= hi - 1e-6 and sh > 0
        part = (not lit) and sh > lo and sh > 0
        candle(a, gx + 4 + i * step, base_y, f, lit, part, i * 17 + 3)
    # tepsi
    a.rect(2, base_y, W - 4, 8, OUT)
    a.rect(3, base_y + 1, W - 6, 6, WOOD_T)
    a.hline(3, base_y + 1, W - 6, BRASS)
    a.hline(3, base_y + 2, W - 6, BRASS_D)
    a.hline(3, base_y + 6, W - 6, OUT2)
    for k in range(n):
        a.set(gx + 7 + k * step, base_y + 3, WOOD_TH)
    s = f"{fmt(hp * hp_max)}/{fmt(hp_max)}"
    a.text(W // 2 - a.text_width(s) // 2, base_y + 1, s, CREAM, outline=WOOD_T)
    return a


PROTOS = [
    ("P1", "Yosunlu Taş", top_p1),
    ("P2", "Mürekkep Rulo", top_p2),
    ("P3", "Cam Tüp", top_p3),
    ("P4", "Omurga", top_p4),
]
