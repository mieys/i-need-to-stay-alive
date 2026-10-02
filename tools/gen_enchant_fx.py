"""Efsun efektleri (2026-09-30 yeni efsun seti) - pixel-art sprite sayfalari -> assets/fx/enchant/<ad>_sheet.png +
<ad>_frames.tres (43 sayfa). IKINCI TASARIM: kullanici ilk seti reddetti ("hepsi cok kotu, sifirdan tasarla, 48x48
pixel sanatiyla uyussun" - ilk set 1 px noktali halkalar / dagink zerrelerdi). Dil: tools/pixfx.py (ici dolu golgeli
kutleler, 5 ton rampa, 1 px koyu kontur, krem parlama, hilale asinarak sonme; alev/enerji icin ISI golgesi - cekirdek
parlak, kenar koyu; oyundaki hit_effects/big_burst, korsan patlamasi, burn/fire_min, assasin shadow_hit ornek alindi).
Tuval boyutlari, kokler ve tasarim yaricaplari SABIT - oyun kodu (fx_enchant_sprite olcekleri, enchant_area
sheet_scale'leri, SHEET_RX / SHEET_R / SHEET_WIDTH sabitleri) bunlara bagli; bir boyutu degistirirsen kodu da guncelle.
Karolar (zeus_tile, magma_tile, volt_tile, rift_tile) x'te 16 px periyodik - dikissiz dosenir.

Calistir: python tools/gen_enchant_fx.py [ad ...]   (ad verilmezse hepsi)
"""

import math
import os
import random
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402
from gen_hadime_fx import sheet  # noqa: E402
import pixfx as P  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "enchant")
RES = "res://assets/fx/enchant/"
TAU = P.TAU


def save(name, frames, anim, loop, fps):
    """Kareleri sayfaya dizer. Cizim P.PAD kadar genis tuvalde yapildi: tum karelerin birlesik dolu alani bulunur ve her
    eksende iki yandan ESIT kirpilir (1 px bos kenar kalir) -> merkez (oyunda sprite capasi) tasarimdaki yerinde kalir,
    hicbir sey tuval kenarinda duz kesilmez."""
    os.makedirs(OUT, exist_ok=True)
    imgs = [f.image() for f in frames]
    W, H = imgs[0].size
    used = np.zeros((H, W), dtype=bool)
    for f in frames:
        used |= f.rgba[:, :, 3] > 0
    ys, xs = np.nonzero(used)
    if len(xs):
        cx_ = 0 if name in TILES else max(0, min(int(xs.min()), W - 1 - int(xs.max())) - 1)
        cy_ = max(0, min(int(ys.min()), H - 1 - int(ys.max())) - 1)
        imgs = [im.crop((cx_, cy_, W - cx_, H - cy_)) for im in imgs]
    sheet(imgs).save(os.path.join(OUT, name + "_sheet.png"))
    w, h = imgs[0].size
    write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), RES + name + "_sheet.png", w, h,
                        [(anim, (0, 0), len(imgs), loop, fps)])
    print("   %-18s %dx%d x %d kare (%s)" % (name, w, h, len(imgs), anim))


# ====================================================================== Destiny: ates / buz puskurtmesi
def spray(name, pal, ice, S=1):
    """Koni +x: tuval (100x72)*S, kok (6, 36)*S. Menzil 91*S px (110*S dunya). S=2: Destiny finali ("boyut iki katina
    cikar") icin ayri '_big' sayfa - buyutulmus kaba piksel yerine ayni texel yogunlugunda cizilir. TEK PARCA surekli
    koni: agizda 3 px, uca dogru genisler; ton eksene uzakliga gore (ortada parlak cekirdek, kenarda koyu, koyu kontur -
    burn/fire_min dili), disari akan gurultu yalayan dil dokusu verir. Uc kismi gurultuyle kopuk alev/sis parcalarina
    ayrilir ve bir ton soguk. Kisa omurlu (0,25 sn) - ust uste dogar."""
    n = 6
    ox, oy = 6 * S, 36 * S
    frames = []
    for i in range(n):
        cv = P.Canvas(100 * S, 72 * S)
        t = i / (n - 1)
        rng = random.Random((97 if ice else 13) + i * 7)
        X, Y = cv.grid()
        u = (X - ox) / S
        v = (Y - oy) / S
        Xs, Ys = X / S, Y / S
        grow = min(1.0, 0.45 + t * 1.4)
        L = 88 * grow
        half = 1.6 + 0.36 * np.maximum(u, 0)
        billow = 1.0 + 0.2 * np.sin(u * 0.2 - t * 9.0 + np.sign(v) * 1.3)
        flow = P.noise_xy(Xs - t * 30, Ys, 22, 5 if ice else 3)
        edge = half * billow * (0.72 + 0.5 * flow)
        k = np.abs(v) / np.maximum(edge, 0.5)
        m = (u >= 0) & (k <= 1.0) & (u <= L + 10 * (flow - 0.5))
        tipzone = np.clip((u - (L - 28)) / 30.0, 0, 1)
        brk = P.noise_xy(Xs - t * 40, Ys * 1.3, 15, 11)
        m &= ~((tipzone > 0) & (brk < 0.2 + 0.55 * tipzone + 0.2 * max(0.0, t - 0.6)))
        for _o in range(2 * S):
            m = P.dilate(P.erode(m))
        m &= P.fill_holes(m)
        kk = k + 0.22 * (flow - 0.5) + 0.45 * tipzone
        tone = np.where(kk < 0.3, 4, np.where(kk < 0.58, 3, np.where(kk < 0.85, 2, 1)))
        for tt in range(1, 5):
            cv.put(m & (tone == tt), pal[tt])
        cv.put(P.outline_of(m) & ~cv.filled(), pal[0])
        P.disc_flash(cv, ox + 1.5 * S, oy, 2.2 * S, core=P.WHITE if ice else P.CREAM, rim=pal[4])
        if ice:
            for q in range(4 * S):
                a = rng.uniform(-0.4, 0.4)
                d = rng.uniform(20, 82) * grow * S
                x, y = ox + math.cos(a) * d, oy + math.sin(a) * d
                shard = P.ellipses_mask(cv, [(x, y, 3.4, 1.3, a + rng.uniform(-0.5, 0.5))])
                cv.put(shard, P.ICE[4])
                cv.put(P.outline_of(shard) & ~cv.filled(), P.ICE[1])
            for q in range(3 * S):
                a = rng.uniform(-0.45, 0.45)
                d = (L + rng.uniform(-10, 4)) * S
                x, y = ox + math.cos(a) * d, oy + math.sin(a) * d - t * 3 * S
                r = 3.5 - t * 1.2
                P.puffs(cv, [(x, y, r), (x + r * 0.7, y + 0.8, r * 0.7)], P.WIND, cut=[(x, y - r * 0.9, r * (0.2 + 0.6 * t))])
        else:
            for q in range(5 * S):
                a = rng.uniform(-0.5, 0.5)
                d = rng.uniform(30, L + 6) * S
                P.star(cv, ox + math.cos(a) * d, oy + math.sin(a) * d - t * 6 * S, 1 if q % 2 else 0, core=P.FIRE[4], arm=P.FIRE[3])
        frames.append(cv)
    save(name, frames, "play", False, 24.0)


# ====================================================================== zemin: lav birikintisi
def lava_pool():
    """80x48 dongu, zemin merkezi tuval merkezi, rx 37 px = 45 dunya (Destiny finali lav birikintisi; oyunda olcek ~1).
    Kavrulmus kabuk kenari + erimis ic: soguyan koyu kabuk adacaklari, organik parlak catlak damarlari (sirtli gurultu),
    patlayan kabarciklar."""
    n = 6
    W, H = 80, 48
    cx, cy = W / 2, H / 2
    K = 37 / 29
    frames = []
    rng = random.Random(5)
    bubbles = [(rng.uniform(-17, 17) * K, rng.uniform(-5, 5) * K, rng.randint(0, n - 1), rng.uniform(1.8, 2.6)) for _ in range(7)]
    for i in range(n):
        cv = P.Canvas(W, H)
        outer = P.blob_mask(cv, cx, cy, 29 * K, 14 * K, 11, wobble=0.12, lobes=6)
        inner = P.blob_mask(cv, cx, cy + 0.5, 23 * K, 10 * K, 12, wobble=0.16, lobes=5)
        crust = outer & ~inner
        X, Y = cv.grid()
        cv.put(crust, P.EARTH[1])
        cv.put(crust & (P.value_noise(cv, 6, 3) > 0.62), P.EARTH[2])
        cv.put(crust & ~P.erode(crust) & (Y > cy + 2), P.EARTH[0])
        nz = P.value_noise(cv, 22 * K, 7, t=i / n)
        cv.put(inner, P.FIRE[2])
        cool = inner & (nz > 0.66)
        cv.put(cool, P.EMBER[1])
        cv.put(cool & (P.value_noise(cv, 5, 9) > 0.7), P.EMBER[0])
        ridge = np.abs(nz - 0.5)
        cv.put(inner & (ridge < 0.07) & ~cool, P.FIRE[3])
        cv.put(inner & (ridge < 0.028), P.FIRE[4])
        cv.put(inner & ~P.erode(inner) & (Y > cy), P.FIRE[1])
        for (bx, by, bph, br) in bubbles:
            k = (i - bph) % n
            x, y = cx + bx, cy + by
            if k == 0:
                P.puffs(cv, [(x, y, br * 0.7)], P.FIRE)
            elif k == 1:
                P.puffs(cv, [(x, y - 0.5, br)], P.FIRE)
            elif k == 2:
                P.star(cv, x, y - 2, 1, core=P.FIRE[4], arm=P.FIRE[3])
        cv.put(P.outline_of(outer) & ~cv.filled(), P.EARTH[0])
        frames.append(cv)
    save("lava_pool", frames, "loop", True, 8.0)


# ====================================================================== Donen Saldiri: 360 derece savurma
SPIN_PAL = [(44, 14, 22), (176, 34, 44), (150, 156, 176), (206, 214, 228), (255, 255, 255)]


def spin_slash():
    """160x96 tek seferlik, elips rx 72 ry 40 (dunyada 90 birim). KALIN kesik izi: dis kenar beyaz agiz, govde celik, ic
    kenar kan kirmizisi; bastan (15 px) kuyruga incelir. Son karelerde incelip parcalanir. Bas saat yonunde ~1,15 tur."""
    n = 8
    cx, cy = 80, 48
    sq = 0.56
    frames = []
    for i in range(n):
        cv = P.Canvas(160, 96)
        t = i / (n - 1)
        head = -math.pi / 2 + TAU * 1.15 * P.ease_out(min(1.0, t * 1.25))
        span = math.radians(70 + 170 * min(1.0, t * 2.2))
        fade = max(0.0, t - 0.55) / 0.45
        th_head = 15.0 * (1.0 - 0.75 * fade)
        a0 = head - span * (1.0 - 0.6 * fade)
        mult = P.break_mult(cv, cx, cy, sq, (fade - 0.3) / 0.7, t * 7) if fade > 0.3 else None
        P.arc_band(cv, cx, cy, 72, a0, head, th_head, 1.0, SPIN_PAL, squash=sq, mult=mult)
        hx = cx + math.cos(head) * 66
        hy = cy + math.sin(head) * 66 * sq
        if t < 0.7:
            P.star(cv, hx, hy, 3 if i % 2 == 0 else 2, core=P.WHITE, arm=SPIN_PAL[3], diag=True)
        frames.append(cv)
    save("spin_slash", frames, "play", False, 22.0)


# ====================================================================== Endless Void: karadelik
def void_hole():
    """106x106 dongu, tasarim yaricapi 66 px = 80 dunya cekim alani (Endless Void; oyunda olcek ~1, 100 birimde 1,25).
    Arka yari yigilma diski -> kara cekirdek + parlak olay ufku -> on yari disk; iceri sarmal cekilen parcaciklar."""
    n = 8
    c = 53
    K = 66 / 40
    frames = []
    rng = random.Random(9)
    motes = [(rng.uniform(0, TAU), rng.uniform(0.0, 1.0)) for _ in range(20)]
    for i in range(n):
        cv = P.Canvas(106, 106)
        t = i / n
        X, Y = cv.grid()
        rot = TAU * t
        gaps = [(rot + 0.6, rot + 1.5), (rot + 3.4, rot + 4.1)]
        back = P.Canvas(106, 106)
        P.ring_band(back, c, c, 26 * K, 5 * K, P.VOID, squash=0.36, gaps=gaps)
        bm = back.filled() & (Y < c)
        cv.rgba[bm] = back.rgba[bm]
        P.disc_flash(cv, c, c, 10.5 * K, core=P.VOID[3], rim=P.VOID[4])
        P.disc_flash(cv, c, c, 8.6 * K, core=(6, 2, 12))
        cv.px(c - 5, c - 6, P.VOID[2])
        cv.px(c - 4, c - 7, P.VOID[2])
        front = P.Canvas(106, 106)
        P.ring_band(front, c, c, 26 * K, 5 * K, P.VOID, squash=0.36, gaps=gaps)
        fm = front.filled() & (Y >= c)
        cv.rgba[fm] = front.rgba[fm]
        for (a0, ph) in motes:
            u = (ph + t) % 1.0
            d = (30 * (1.0 - u) + 11) * K
            a = a0 + u * 4.0
            x = c + math.cos(a) * d
            y = c + math.sin(a) * d * 0.62
            if u > 0.75:
                P.star(cv, x, y, 1, core=P.VOID[4], arm=P.VOID[3])
            else:
                P.chunk(cv, x, y, 2 if u < 0.4 else 1, P.VOID)
        frames.append(cv)
    save("void_hole", frames, "loop", True, 12.0)


# ====================================================================== Sismik Dalga: toprak sok dalgasi
def rough_ring(cv, cx, cy, R, thick, sq, seed, pal, mult=None):
    """Puruzlu (tirtikli dis kenar) toprak bandi, ust yari isikli, kontur. mult: parcalanma carpani (uclar incelir)."""
    X, Y = cv.grid()
    dx, dy = X - cx, (Y - cy) / sq
    r = np.sqrt(dx * dx + dy * dy)
    th = np.arctan2(dy, dx)
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, TAU, 3)
    wob = 1.6 * np.sin(th * 11 + ph[0]) + 1.0 * np.sin(th * 23 + ph[1]) + 0.6 * np.sin(th * 5 + ph[2])
    th_a = thick * mult if mult is not None else thick
    m = (r <= R + wob) & (r >= R - th_a + 0.5 * wob) & (np.asarray(th_a) > 0.6)
    if not m.any():
        return m
    k = (r - (R - thick)) / max(thick, 0.5)
    top = np.sin(th) < -0.15
    tone = np.where(k > 0.7, 3, np.where(k > 0.35, 2, 1))
    tone = np.where(top, np.minimum(tone + 1, 4), tone)
    for tt in range(1, 5):
        cv.put(m & (tone == tt), pal[tt])
    cv.put(P.outline_of(m) & ~cv.filled(), pal[0])
    return m


def seismic_ring():
    """192x104 tek seferlik, halka rx en fazla 91 px (110 dunya), basiklik ~0.52. Carpma parlamasi + kisa kirik catlaklar,
    genisleyen KALIN tirtikli toprak dalgasi, dis kenarinda firlayan taslar ve asinarak sonen buyuk toz bulutlari."""
    n = 9
    cx, cy = 96, 52
    sq = 0.52
    frames = []
    rng = random.Random(23)
    cracks = []
    for k in range(5):
        a = rng.uniform(0, TAU)
        pts = [(cx, cy)]
        for _s in range(3):
            a += rng.uniform(-0.5, 0.5)
            L = rng.uniform(6, 10)
            x, y = pts[-1]
            pts.append((x + math.cos(a) * L, y + math.sin(a) * L * sq))
        cracks.append(pts)
    rocks = [(rng.uniform(0, TAU), rng.uniform(0.6, 1.0)) for _ in range(16)]
    dust = [TAU * k / 12 + rng.uniform(-0.2, 0.2) for k in range(12)]
    for i in range(n):
        cv = P.Canvas(192, 104)
        t = i / (n - 1)
        R = 12 + 78 * P.ease_out(t)
        for a in dust:
            x = cx + math.cos(a) * (R + 3)
            y = cy + math.sin(a) * (R + 3) * sq - 4 - 5 * t
            pr = 9.0 * (1.0 - 0.45 * t)
            cut = [(x - pr * 0.1, y - pr * (0.3 + 0.9 * t), pr * (0.2 + 0.75 * t))] if t > 0.25 else None
            P.puffs(cv, [(x, y, pr), (x + pr * 0.8, y + 1, pr * 0.72), (x - pr * 0.7, y + 1.5, pr * 0.6)], P.DUST, cut=cut)
        if t < 0.6:
            for pts in cracks:
                for (a_, b_) in zip(pts[:-1], pts[1:]):
                    P.thick_line(cv, a_[0], a_[1], b_[0], b_[1], 2.0, P.EARTH[0])
                    P.thick_line(cv, a_[0], a_[1] - 1, b_[0], b_[1] - 1, 0.9, P.EARTH[2])
        thick = 11.0 * (1.0 - 0.55 * t)
        mult = P.break_mult(cv, cx, cy, sq, (t - 0.6) / 0.4, 1.3, lobes=7) if t > 0.6 else None
        rough_ring(cv, cx, cy, R, thick, sq, 31, P.EARTH, mult=mult)
        for (a, sp) in rocks:
            d = R + 2 + 4 * sp
            h = math.sin(min(1.0, t * 1.2) * math.pi) * 16 * sp
            if t < 0.92:
                P.chunk(cv, cx + math.cos(a) * d, cy + math.sin(a) * d * sq - h, 3 if sp > 0.85 else 2, P.EARTH)
        if i == 0:
            P.disc_flash(cv, cx, cy, 10, core=P.CREAM, rim=P.DUST[3], squash=0.6)
        elif i == 1:
            P.disc_flash(cv, cx, cy, 6, core=P.DUST[4], rim=P.DUST[2], squash=0.6)
        frames.append(cv)
    save("seismic_ring", frames, "play", False, 20.0)


# ====================================================================== zemin: buz / radyasyon
def frost_ground():
    """96x56 dongu, rx 45 px = 55 dunya (Destiny buz finali; oyunda olcek ~1). Kar kenari + catlak buz tabakasi (voronoi
    hucreleri, her hucre kendi tonu, beyaz catlak cizgileri), kenardan cikan kucuk buz dikenleri; capraz kayan parilti
    bandi + goz kirpan yildizlar."""
    n = 6
    W, H = 96, 56
    cx, cy = W / 2, H / 2
    K = 45 / 29
    rng = random.Random(41)
    seeds = [(cx + rng.uniform(-24, 24) * K, cy + rng.uniform(-10, 10) * K) for _ in range(16)]
    tones = [rng.choice((2, 2, 3)) for _ in seeds]
    spikes = [(rng.uniform(0, TAU), rng.uniform(0.8, 1.2)) for _ in range(13)]
    twinkles = [(cx + rng.uniform(-20, 20) * K, cy + rng.uniform(-8, 8) * K) for _ in range(n)]
    frames = []
    for i in range(n):
        cv = P.Canvas(W, H)
        X, Y = cv.grid()
        outer = P.blob_mask(cv, cx, cy, 29 * K, 14 * K, 43, wobble=0.12, lobes=6)
        inner = P.blob_mask(cv, cx, cy + 0.5, 24 * K, 10.5 * K, 44, wobble=0.14, lobes=5)
        snow = outer & ~inner
        cv.put(snow, P.WIND[3])
        cv.put(snow & (P.value_noise(cv, 5, 45) > 0.6), P.WIND[4])
        cv.put(snow & ~P.erode(snow) & (Y > cy + 1), P.WIND[1])
        d1 = np.full((cv.h, cv.w), 1e9)
        d2 = np.full((cv.h, cv.w), 1e9)
        idx = np.zeros((cv.h, cv.w), dtype=int)
        for k, (sx, sy) in enumerate(seeds):
            d = np.hypot(X - sx, (Y - sy) * 1.8)
            closer = d < d1
            d2 = np.where(closer, d1, np.minimum(d2, d))
            idx = np.where(closer, k, idx)
            d1 = np.where(closer, d, d1)
        for k in range(len(seeds)):
            cv.put(inner & (idx == k), P.ICE[tones[k]])
        cell_hi = inner & (d1 < 3.6) & ((X - np.array([s[0] for s in seeds])[idx]) < 0)
        cv.put(cell_hi, P.ICE[3])
        cv.put(inner & (d2 - d1 < 1.1), P.ICE[4])
        band = (X + Y * 1.6 - (i / n) * 110 * K + 20) % (110 * K)
        cv.put(inner & (band < 3) & (d2 - d1 >= 1.1), P.ICE[4])
        cv.put(inner & ~P.erode(inner) & (Y > cy), P.ICE[1])
        for (a, sz) in spikes:
            bx = cx + math.cos(a) * 26 * K
            by = cy + math.sin(a) * 12 * K
            h = 4 * sz
            tri = P.poly_mask(cv, [(bx - 1.6, by), (bx + 1.6, by), (bx + 0.3 * math.cos(a), by - h)])
            cv.put(tri, P.ICE[3])
            cv.put(tri & (X < bx), P.ICE[4])
        cv.put(P.outline_of(cv.filled()) & ~cv.filled(), P.ICE[0])
        for q in range(2):
            tx, ty = twinkles[(i + q * 3) % n]
            P.star(cv, tx, ty, 2 - q, core=P.WHITE, arm=P.ICE[4])
        frames.append(cv)
    save("frost_ground", frames, "loop", True, 8.0)


def radiation():
    """104x60 dongu, rx 49 px = 60 dunya (Nuukler radyasyon alani; oyunda olcek ~1). Koyu camur kenarli parlak zehirli
    sivi: halkali (sirtli) akinti damarlari, ortada parlak radyasyon cekirdegi, patlayan kabarciklar ve yukselip hilale
    asinan yesil buhar kumeleri."""
    n = 6
    W, H = 104, 60
    cx, cy = W / 2, H / 2 + 1
    K = 49 / 29
    rng = random.Random(51)
    bubbles = [(rng.uniform(-18, 18) * K, rng.uniform(-5, 5) * K, rng.randint(0, n - 1), rng.uniform(1.8, 2.8)) for _ in range(10)]
    vapors = [(rng.uniform(-16, 16) * K, rng.randint(0, n - 1)) for _ in range(5)]
    frames = []
    for i in range(n):
        cv = P.Canvas(W, H)
        X, Y = cv.grid()
        outer = P.blob_mask(cv, cx, cy, 29 * K, 13.5 * K, 52, wobble=0.14, lobes=6)
        inner = P.blob_mask(cv, cx, cy + 0.5, 24 * K, 10 * K, 53, wobble=0.16, lobes=7)
        rim = outer & ~inner
        cv.put(rim, P.TOXIC[1])
        cv.put(rim & (P.value_noise(cv, 5, 54) > 0.62), P.TOXIC[0])
        cv.put(rim & ~P.erode(rim) & (Y < cy - 2), P.TOXIC[2])
        nz = P.value_noise(cv, 18 * K, 55, t=i / n)
        cv.put(inner, P.TOXIC[2])
        ridge = np.abs(nz - 0.5)
        cv.put(inner & (ridge < 0.09), P.TOXIC[3])
        cv.put(inner & (ridge < 0.03), P.TOXIC[4])
        core = P.blob_mask(cv, cx, cy, (8 + (i % 2)) * K, 3.6 * K, 56, wobble=0.2, lobes=5)
        cv.put(inner & core, P.TOXIC[3])
        cv.put(inner & P.erode(P.erode(core)), P.TOXIC[4])
        cv.put(inner & ~P.erode(inner) & (Y > cy), P.TOXIC[1])
        cv.put(P.outline_of(outer) & ~cv.filled(), P.TOXIC[0])
        for (bx, by, bph, br) in bubbles:
            k = (i - bph) % n
            x, y = cx + bx, cy + by
            if k == 0:
                P.puffs(cv, [(x, y, br * 0.7)], P.TOXIC)
            elif k == 1:
                P.puffs(cv, [(x, y - 0.5, br)], P.TOXIC, cut=[(x + 0.3, y - 0.3, br * 0.55)])
            elif k == 2:
                P.star(cv, x, y - 2, 1, core=P.TOXIC[4], arm=P.TOXIC[3])
        for (vx, vph) in vapors:
            k = (i - vph) % n
            if k > 3:
                continue
            x = cx + vx
            y = cy - 4 - k * 3.5
            r = 3.6 - k * 0.5
            P.puffs(cv, [(x, y, r), (x + r * 0.7, y + 1, r * 0.7)], P.TOXIC, cut=[(x + 0.4, y + r * 0.5, r * (0.25 * k))] if k else None)
        frames.append(cv)
    save("radiation", frames, "loop", True, 8.0)


# ====================================================================== Valerius: shuriken
def shuriken():
    """12x12 dongu (4 kare = 90 derece; 4 kollu yildiz simetrisi). Kancali celik kollar: her kolun on yuzu acik, arka yuzu
    koyu, kontur; ortada kan kirmizisi delik."""
    frames = []
    c = 6.0
    for i in range(4):
        cv = P.Canvas(12, 12)
        rot = i * (math.pi / 2) / 4
        faces = []
        for k in range(4):
            a = rot + k * math.pi / 2
            tip = (c + math.cos(a + 0.28) * 5.8, c + math.sin(a + 0.28) * 5.8)
            left = (c + math.cos(a + 1.1) * 1.9, c + math.sin(a + 1.1) * 1.9)
            right = (c + math.cos(a - 0.75) * 2.0, c + math.sin(a - 0.75) * 2.0)
            mid = (c + math.cos(a + 0.1) * 2.6, c + math.sin(a + 0.1) * 2.6)
            lit = math.cos(a + 0.28) * P.LIGHT[0] + math.sin(a + 0.28) * P.LIGHT[1]
            faces.append(([left, tip, mid], 3 if lit > -0.3 else 2))
            faces.append(([mid, tip, right], 2 if lit > -0.3 else 1))
        faces.append(([(c - 2, c - 2), (c + 2, c - 2), (c + 2, c + 2), (c - 2, c + 2)], 2))
        P.facets(cv, faces, P.STEEL)
        cv.px(c - 0.5, c - 0.5, P.BLOOD[2])
        cv.px(c + 0.5, c - 0.5, P.BLOOD[1])
        cv.px(c - 0.5, c + 0.5, P.BLOOD[1])
        cv.px(c + 0.5, c + 0.5, P.BLOOD[0])
        frames.append(cv)
    save("shuriken", frames, "loop", True, 16.0)


# ====================================================================== Wind Sword: ruzgar dalgasi
def wind_wave():
    """28x48 dongu, +x'e ilerleyen hilal (dunyada genislik 40 = ~33 px). Iki dairenin farki: ortada kalin, uclarda sivri;
    dis (on) kenar beyaz, ic taraf mavi-gri, kontur. Arkada kopuk ince hilaller + hiz cizgileri kayar."""
    frames = []
    cy = 24
    for i in range(4):
        cv = P.Canvas(28, 48)
        X, Y = cv.grid()
        wob = (i % 2) * 0.6

        def crescent(ox, r_out, shift, sq):
            a = np.hypot(X - ox, (Y - cy) / sq) <= r_out
            b = np.hypot(X - (ox - shift), (Y - cy) / sq) <= r_out - 0.4
            return a & ~b

        back2 = crescent(-12 - i * 1.0, 19, 1.6, 1.25)
        back1 = crescent(-7 - i * 0.6, 21, 2.2, 1.3)
        main = crescent(-2 + wob, 23, 6.5, 1.35)
        for m, col, ph in ((back2, P.WIND[2], 0.4), (back1, P.WIND[3], 2.1)):
            gap = np.sin(Y * 0.28 + i * 1.3 + ph) > 0.7
            cv.put(m & ~gap, col)
        X_ = X - (-2 + wob)
        rr = np.hypot(X_, (Y - cy) / 1.35)
        k = (rr - 16.5) / 6.5
        tone = np.where(k > 0.72, 4, np.where(k > 0.45, 3, np.where(k > 0.2, 2, 1)))
        for t in range(1, 5):
            cv.put(main & (tone == t), P.WIND[t])
        cv.put(P.outline_of(main) & ~cv.filled(), P.WIND[0])
        frames.append(cv)
    save("wind_wave", frames, "loop", True, 14.0)


# ====================================================================== Endless Void: cokus patlamasi
def void_collapse():
    """160x160 tek seferlik, tasarim yaricapi 66 px = 80 dunya (karadelik yaricapi; oyunda olcek ~1). Karadelik once kendi
    icine coker (disk daralir, cekirdek kuculur), mor-beyaz parlama, sonra mor dolu patlama kumeleri + genisleyen
    parcalanan halka + yildiz kivilcimlari."""
    n = 10
    c = 80
    K = 66 / 40
    frames = []
    for i in range(n):
        cv = P.Canvas(160, 160)
        if i < 2:
            P.ring_band(cv, c, c, (22 - i * 9) * K, (4 - i) * K, P.VOID, squash=0.4)
            P.disc_flash(cv, c, c, (9 - i * 3) * K, core=P.VOID[3], rim=P.VOID[4])
            P.disc_flash(cv, c, c, (7 - i * 3) * K, core=(6, 2, 12))
            frames.append(cv)
            continue
        t = (i - 2) / (n - 3)
        R = (12 + 30 * P.ease_out(t)) * K
        if t > 0.08:
            P.shock_ring(cv, c, c, R + 4 * K, max(2.0, 6 * K * (1 - t)), t, P.VOID, 1.0, 3, break_from=0.4)
        P.burst(cv, c, c, 36 * K, min(1.0, t * 0.95 + 0.06), P.VOID, P.SHADOW, 77, n_puffs=10, shard_col=P.VOID[4])
        if i == 2:
            P.disc_flash(cv, c, c, 12 * K, core=P.VOID[4], rim=P.VOID[3])
            P.disc_flash(cv, c, c, 6 * K, core=P.WHITE)
            for q in range(4):
                a = q * TAU / 4 + math.pi / 4
                for d in range(int(12 * K), int(24 * K)):
                    cv.px(c + math.cos(a) * d, c + math.sin(a) * d, P.VOID[4] if d < 18 * K else P.VOID[3])
        frames.append(cv)
    save("void_collapse", frames, "play", False, 20.0)


# ====================================================================== Arrow Rain
def arrow_sprite(cv, x, y, length, pal_wood=None):
    """Asagi bakan ok (uc (x, y)'de): celik uc, tahta govde, kirmizi tuy; kontur."""
    pal_wood = pal_wood or P.WOOD
    m = np.zeros((cv.h, cv.w), dtype=bool)
    xi, yi = int(round(x)), int(round(y))
    cols = {}
    for d in range(length):
        yy = yi - 3 - d
        cols[(xi, yy)] = pal_wood[3] if d % 3 else pal_wood[2]
    for dy, xs in ((0, (0,)), (-1, (-1, 0, 1)), (-2, (-1, 0, 1))):
        for dx in xs:
            cols[(xi + dx, yi + dy)] = P.STEEL[4] if dx < 0 or dy == 0 else P.STEEL[2]
    top = yi - 3 - length
    for dy in range(3):
        cols[(xi - 1, top + 1 + dy)] = P.BLOOD[2]
        cols[(xi + 1, top + 1 + dy)] = P.BLOOD[1]
    for (px_, py_), col in cols.items():
        iy, ix = cv.idx(px_, py_)
        if 0 <= ix < cv.w and 0 <= iy < cv.h:
            cv.px(px_, py_, col)
            m[iy, ix] = True
    cv.put(P.outline_of(m) & ~cv.filled(), (30, 20, 16))
    return m


def arrow_rain():
    """128x112 dongu, zemin merkezi (64, 76) = tuval merkezinin 20 px alti, rx 58 ry 26 (= 70 dunya; oyunda olcek ~1).
    Zeminde soluk hedef halkasi (yavasca doner); dusen oklar (golgesiyle), saplaninca toz puflari, saplanmis ok bir sure
    kalir. Oklar sabit boyutlu nesne - alan buyudukce sayilari artar, kendileri buyumez."""
    n = 8
    gx, gy, rx, ry = 64, 76, 58, 26
    rng = random.Random(11)
    drops = []
    while len(drops) < 20:
        dx, dy = rng.uniform(-1, 1), rng.uniform(-1, 1)
        if dx * dx + dy * dy < 0.8:
            drops.append((dx * rx, dy * ry, rng.randint(0, n - 1)))
    frames = []
    for i in range(n):
        cv = P.Canvas(128, 112)
        rot = i / n * (TAU / 16)
        gaps = [(rot + TAU * k / 16, rot + TAU * k / 16 + 0.12) for k in range(16)]
        tmp = P.Canvas(128, 112)
        ring = P.ring_band(tmp, gx, gy, rx, 1.6, P.DUST, squash=ry / rx, gaps=gaps, outline=False)
        cv.put(ring, (236, 224, 196), 130)
        order = sorted(drops, key=lambda d: d[1])
        for (dx, dy, ph) in order:
            k = (i + ph) % n
            bx, by = gx + dx, gy + dy
            if k < 3:
                sh = P.ellipse_mask(cv, bx, by, 2.2 - k * 0.3 + 0.8, 1.0)
                cv.put(sh & ~cv.filled(), (40, 30, 26), 110)
                h = 46 - k * 16
                arrow_sprite(cv, bx, by - h, 8)
                for s_ in range(3):
                    cv.px(bx, by - h - 13 - s_ * 2, P.WIND[3], 200)
            elif k == 3:
                P.puffs(cv, [(bx - 2.5, by, 2.4), (bx + 2.5, by + 0.5, 2.2), (bx, by - 1.5, 2.6)], P.DUST)
                arrow_sprite(cv, bx, by + 1, 6)
                P.star(cv, bx, by - 5, 1, core=P.WHITE, arm=P.DUST[4])
            elif k == 4:
                P.puffs(cv, [(bx - 4, by - 1, 2.0), (bx + 4, by, 1.8)], P.DUST, cut=[(bx - 4, by - 2.3, 1.4), (bx + 4, by - 1.3, 1.3)])
                arrow_sprite(cv, bx, by + 1, 6)
            elif k == 5:
                arrow_sprite(cv, bx, by + 1, 6)
        frames.append(cv)
    save("arrow_rain", frames, "loop", True, 12.0)


def ballista():
    """80x120 tek seferlik, zemin (40, 100). Dev balista oku yukaridan iner (hiz cizgileri), saplanir: krem parlama,
    catlaklar, toz halkasi (dolu puflar), firlayan taslar; ok sonda parcalanir."""
    n = 11
    gx, gy = 40, 100
    rng = random.Random(61)
    rocks = [(rng.uniform(0, TAU), rng.uniform(0.6, 1.0)) for _ in range(10)]
    cracks = []
    for k in range(5):
        a = TAU * k / 5 + rng.uniform(-0.3, 0.3)
        pts = [(gx, gy)]
        for _s in range(3):
            a += rng.uniform(-0.45, 0.45)
            x, y = pts[-1]
            L = rng.uniform(4, 7)
            pts.append((x + math.cos(a) * L, y + math.sin(a) * L * 0.45))
        cracks.append(pts)

    def bolt(cv, tipy, shaft_len):
        x = gx
        m = np.zeros((cv.h, cv.w), dtype=bool)
        shaft = P.poly_mask(cv, [(x - 1.5, tipy - 7), (x + 1.5, tipy - 7), (x + 1.5, tipy - 7 - shaft_len), (x - 1.5, tipy - 7 - shaft_len)])
        cv.put(shaft, P.WOOD[2])
        cv.put(shaft & (cv.grid()[0] < x - 0.5), P.WOOD[3])
        m |= shaft
        head = [([(x, tipy), (x - 4.5, tipy - 8), (x, tipy - 6)], 4), ([(x, tipy), (x, tipy - 6), (x + 4.5, tipy - 8)], 2)]
        m |= P.facets(cv, head, P.STEEL, outline=False)
        top = tipy - 7 - shaft_len
        fl = [([(x - 1.5, top + 9), (x - 6, top + 2), (x - 5, top - 1), (x - 1.5, top + 3)], 2),
              ([(x + 1.5, top + 9), (x + 6, top + 2), (x + 5, top - 1), (x + 1.5, top + 3)], 1)]
        m |= P.facets(cv, fl, P.BLOOD, outline=False)
        cv.put(P.outline_of(m) & ~cv.filled(), (30, 20, 16))

    frames = []
    for i in range(n):
        cv = P.Canvas(80, 120)
        if i < 3:
            tipy = 8 + i * 30 + 26
            sh = P.ellipse_mask(cv, gx, gy, 3 + i * 2, 1.5 + i * 0.6)
            cv.put(sh, (40, 30, 26), 110)
            for q in (-3, 0, 3):
                for s_ in range(10):
                    cv.px(gx + q, tipy - 50 - s_ * 2 - abs(q), P.WIND[3], 190)
            bolt(cv, tipy, 30)
            frames.append(cv)
            continue
        t = (i - 3) / (n - 4)
        R = 8 + 28 * P.ease_out(t)
        for q in range(12):
            a = TAU * q / 12 + 0.2
            x = gx + math.cos(a) * R
            y = gy + math.sin(a) * R * 0.42 - 3 - 4 * t
            pr = 5.5 * (1 - 0.5 * t)
            cut = [(x, y - pr * (0.3 + 0.8 * t), pr * (0.2 + 0.8 * t))] if t > 0.3 else None
            if math.sin(a) < 0:
                P.puffs(cv, [(x, y, pr), (x + pr * 0.7, y + 1, pr * 0.7)], P.DUST, cut=cut)
        if t < 0.7:
            for pts in cracks:
                for (a_, b_) in zip(pts[:-1], pts[1:]):
                    P.thick_line(cv, a_[0], a_[1], b_[0], b_[1], 1.6, P.EARTH[0])
        if i == 3:
            P.disc_flash(cv, gx, gy - 2, 14, core=P.CREAM, rim=P.DUST[4], squash=0.5)
        if t < 0.85:
            bolt(cv, gy + 2, 26 - int(8 * max(0.0, t - 0.6) / 0.25))
        else:
            for q in range(4):
                P.chunk(cv, gx - 4 + q * 3, gy - 6 - q * 3 + (t - 0.85) * 30, 2, P.WOOD)
        for q in range(12):
            a = TAU * q / 12 + 0.2
            x = gx + math.cos(a) * R
            y = gy + math.sin(a) * R * 0.42 - 3 - 4 * t
            pr = 5.5 * (1 - 0.5 * t)
            cut = [(x, y - pr * (0.3 + 0.8 * t), pr * (0.2 + 0.8 * t))] if t > 0.3 else None
            if math.sin(a) >= 0:
                P.puffs(cv, [(x, y, pr), (x + pr * 0.7, y + 1, pr * 0.7)], P.DUST, cut=cut)
        for (a, sp) in rocks:
            d = R * 0.8 + 3 * sp
            h = math.sin(min(1.0, t * 1.3) * math.pi) * 22 * sp
            if t < 0.9:
                P.chunk(cv, gx + math.cos(a) * d, gy + math.sin(a) * d * 0.42 - h, 3 if sp > 0.85 else 2, P.EARTH)
        frames.append(cv)
    save("ballista", frames, "play", False, 20.0)


# ====================================================================== karo uclari
def cap_taper(X, cap):
    """Karo UCU (cap=True): serit sol uctan (x~1) sag kenara (x~14) yumusakca kalinlasir - hat kare kesik baslamaz /
    bitmez. Oyunda ilk karo bu, son karo bunun yatay aynasi (enchant_area._setup_sheet). cap=False: 1."""
    if not cap:
        return np.ones_like(X)
    return np.clip((X - 0.5) / 13.5, 0.0, 1.0) ** 0.55


# ====================================================================== Beam of Zeus
def zeus_tile(cap=False):
    """16x28 dongu, +x boyunca 16 px aralikla DOSENIR (x'te tam periyodik - dikis yok). Kalin isin govdesi (15 px):
    eksende beyaz cekirdek, disari dogru sari tonlar, koyu altin kenar; kenar dalgasi periyodik; govdeden kopup donen
    kucuk simsek kivrimlari (karo icinde kalir)."""
    frames = []
    cy = 14
    rng = random.Random(71)
    for i in range(4):
        cv = P.Canvas(16, 28)
        X, Y = cv.grid()
        ph = i * TAU / 4
        tp = cap_taper(X, cap)
        edge = (6.3 + 0.9 * np.sin(X / 16 * TAU * 2 + ph) + 0.5 * np.sin(X / 16 * TAU + ph * 2)) * tp
        v = np.abs(Y - cy)
        m = (v <= edge) & (tp > 0.06)
        edge = np.maximum(edge, 0.5)
        k = v / edge
        core_w = 0.18 + 0.08 * math.sin(ph * 2)
        tone = np.where(k < core_w, 4, np.where(k < 0.5, 3, np.where(k < 0.8, 2, 1)))
        for t in range(1, 5):
            cv.put(m & (tone == t), P.BOLT[t])
        pulse = ((X - i * 4) % 16 < 3) & (k < 0.55)
        cv.put(m & pulse, P.BOLT[4])
        cv.put(P.outline_of(m) & ~cv.filled() & (v < edge + 1.5), P.BOLT[0])
        for side in (-1, 1):
            if rng.random() < 0.8:
                x0 = rng.uniform(3, 9)
                if cap and x0 < 8:
                    continue
                pts = [(x0, cy + side * 6)]
                for s_ in range(3):
                    pts.append((pts[-1][0] + rng.uniform(-1.5, 2.2), cy + side * (8 + s_ * 1.8 + rng.uniform(-0.8, 0.8))))
                P.draw_bolt(cv, pts, P.BOLT, core_w=0.8, glow_w=2.2)
        frames.append(cv)
    save("zeus_tile_cap" if cap else "zeus_tile", frames, "loop", True, 16.0)


def electric_burst(name, size, n, R, fps):
    """Elektrik patlamasi: beyaz parlama -> 6 cizgi zikzak simsek disari (cekirdek beyaz, sari hale, kontur), sari dolu
    halka acilir ve kirilir, kivilcimlar."""
    c = size / 2
    rng = random.Random(len(name) * 13)
    rays = [(TAU * k / 6 + rng.uniform(-0.3, 0.3), rng.uniform(0.75, 1.05)) for k in range(6)]
    frames = []
    for i in range(n):
        cv = P.Canvas(size, size)
        t = i / (n - 1)
        if t > 0.45:
            P.shock_ring(cv, c, c, R * (0.55 + 0.45 * P.ease_out(t)), max(1.2, 2.6 * (1 - t)), t, P.BOLT, 1.0, 2, break_from=0.6)
        if t < 0.75:
            for (a, lk) in rays:
                L = R * lk * (0.5 + 0.6 * P.ease_out(min(1.0, t * 2.2)))
                start = R * 0.3 * max(0.0, t - 0.3) / 0.45
                pts = P.bolt_path(rng, c + math.cos(a) * (3 + start), c + math.sin(a) * (3 + start),
                                  c + math.cos(a) * L, c + math.sin(a) * L, 4, 2.6)
                P.draw_bolt(cv, pts, P.BOLT, core_w=1.0, glow_w=2.6)
                if lk > 0.9 and t < 0.5:
                    mx, my = pts[2]
                    fa = a + rng.choice((-0.9, 0.9))
                    P.draw_bolt(cv, [(mx, my), (mx + math.cos(fa) * 4, my + math.sin(fa) * 4)], P.BOLT, core_w=0.8, glow_w=2.0)
        if t < 0.45:
            r = R * (0.34 - 0.5 * t)
            P.puffs(cv, [(c, c, r + 1.2)], P.BOLT)
            P.disc_flash(cv, c, c, r, core=P.WHITE if i < 2 else P.BOLT[4])
        if 0.3 < t:
            for q in range(5):
                a = rng.uniform(0, TAU)
                d = R * (0.8 + 0.4 * t) * rng.uniform(0.8, 1.1)
                P.star(cv, c + math.cos(a) * d, c + math.sin(a) * d, 1 if t < 0.7 else 0, core=P.BOLT[4], arm=P.BOLT[2])
        frames.append(cv)
    save(name, frames, "play", False, fps)


def fire_burst(name, size, n, R, fps, pal=None, smoke=None, seed=5):
    c = size / 2
    frames = []
    for i in range(n):
        cv = P.Canvas(size, size)
        P.burst(cv, c, c, R, i / (n - 1), pal or P.FIRE, smoke or P.SMOKE, seed, n_puffs=6)
        frames.append(cv)
    save(name, frames, "play", False, fps)


# ====================================================================== Magma / Lightning Trail karolari
def magma_tile(cap=False):
    """16x16 dongu, +x'te 16 px aralikla dosenir (periyodik). Kavrulmus toprak serit (kenarlar dalgali) + ic lav kanali:
    periyodik sirtli damarlar, soguyan kabuk adacaklari, x boyunca kayan isi nabzi."""
    n = 6
    frames = []
    for i in range(n):
        cv = P.Canvas(16, 16)
        X, Y = cv.grid()
        tp = cap_taper(X, cap)
        e_out = (5.6 + 0.8 * np.sin(X / 16 * TAU + 0.7) + 0.5 * np.sin(X / 16 * TAU * 3 + 2.0)) * tp
        e_in = (3.2 + 0.7 * np.sin(X / 16 * TAU * 2 + 1.3)) * tp - 0.4 * (1 - tp)
        v = Y - 8
        outer = (np.abs(v) <= e_out) & (tp > 0.06)
        inner = (np.abs(v + 0.4) <= e_in) & (tp > 0.2)
        crust = outer & ~inner
        cv.put(crust, P.EARTH[1])
        cv.put(crust & (P.noise_xy(X, Y, 8, 81, period_x=16) > 0.72), P.EARTH[0])
        cv.put(crust & (v < -e_out + 1.5), P.EARTH[2])
        nz = P.noise_xy(X - i * 16 / n, Y * 0.8, 16, 82, period_x=16)
        cv.put(inner, P.FIRE[2])
        cv.put(inner & (nz > 0.7), P.EMBER[1])
        ridge = np.abs(nz - 0.42)
        cv.put(inner & (ridge < 0.1), P.FIRE[3])
        cv.put(inner & (ridge < 0.035), P.FIRE[4])
        cv.put(inner & (np.abs(v + 0.4) > e_in - 1) & (v > 0), P.FIRE[1])
        if i % 2 == 0 and not (cap and (i * 5 + 3) % 16 < 8):
            cv.px((i * 5 + 3) % 16, 8 - 3 - (i % 3), P.FIRE[4])
        frames.append(cv)
    save("magma_tile_cap" if cap else "magma_tile", frames, "loop", True, 10.0)


def volt_tile(cap=False):
    """16x16 dongu, dosenir. Kararmis serit + serit boyunca x=0 ve x=16'da ayni yukseklikte biten zikzak elektrik akimi
    (her kare farkli), kucuk ark kivilcimlari."""
    n = 6
    rng = random.Random(83)
    frames = []
    for i in range(n):
        cv = P.Canvas(16, 16)
        X, Y = cv.grid()
        tp = cap_taper(X, cap)
        e_out = (5.2 + 0.7 * np.sin(X / 16 * TAU + 1.1) + 0.4 * np.sin(X / 16 * TAU * 3)) * tp
        outer = (np.abs(Y - 8) <= e_out) & (tp > 0.06)
        cv.put(outer, (46, 40, 36))
        cv.put(outer & (P.noise_xy(X, Y, 5, 84, period_x=16) > 0.6), (70, 62, 50))
        cv.put(outer & (np.abs(Y - 8) > e_out - 1), (30, 26, 24))
        pts = [(3.0 if cap else 0.0, 8.0)]
        for s_ in range(1, 4):
            pts.append((s_ * 4.0, 8 + rng.uniform(-3.2, 3.2) * (0.5 if cap and s_ == 1 else 1.0)))
        pts.append((16.0, 8.0))
        P.draw_bolt(cv, pts, P.BOLT, core_w=1.0, glow_w=2.8)
        if i % 2 == 1:
            x = rng.uniform(8 if cap else 3, 13)
            P.draw_bolt(cv, [(x, 8), (x + 1.5, 8 - rng.choice((-4, 4))), (x + 3, 8 + rng.uniform(-1, 1))], P.BOLT, core_w=0.8, glow_w=2.0)
        frames.append(cv)
    save("volt_tile_cap" if cap else "volt_tile", frames, "loop", True, 10.0)


# ====================================================================== Hunter's Eye
def execute_mark():
    """32x32 tek seferlik. Kirmizi nisangah halkasi (4 ic diski) daralip hedefe kilitlenir, beyaz-kirmizi kalin capraz
    infaz kesigi, halka dort parcaya bolunup disari ucar, kan damlalari."""
    n = 9
    c = 16
    frames = []
    for i in range(n):
        cv = P.Canvas(32, 32)
        t = i / (n - 1)
        if i < 5:
            r = 13 - 4 * P.ease_out(min(1.0, i / 3))
            rot = 0.4 * (1 - min(1.0, i / 3))
            m = P.ring_band(cv, c, c, r, 2.2, P.BLOOD)
            for q in range(4):
                a = rot + q * math.pi / 2
                pts = [(c + math.cos(a) * (r - 1) - math.sin(a) * 1.4, c + math.sin(a) * (r - 1) + math.cos(a) * 1.4),
                       (c + math.cos(a) * (r - 1) + math.sin(a) * 1.4, c + math.sin(a) * (r - 1) - math.cos(a) * 1.4),
                       (c + math.cos(a) * (r - 5), c + math.sin(a) * (r - 5))]
                P.facets(cv, [(pts, 3)], P.BLOOD)
        else:
            k = (i - 5) / 3
            for q in range(4):
                a = q * math.pi / 2 + math.pi / 4
                r = 9 + 8 * k
                P.arc_band(cv, c + math.cos(a) * 4 * k, c + math.sin(a) * 4 * k, r, a - 0.45, a + 0.45, max(1.0, 2.4 - 1.4 * k), max(1.0, 2.4 - 1.4 * k), P.BLOOD)
        if 3 <= i <= 7:
            k = (i - 3) / 4
            L = 14 * min(1.0, (i - 2) / 2)
            w = 3.2 * (1 - k) + 0.8
            m = P.thick_line(P.Canvas(32, 32), c - L, c - L, c + L, c + L, w, P.WHITE)
            cv.put(m, P.WHITE)
            cv.put(m & ~P.erode(m), P.BLOOD[3])
            cv.put(P.outline_of(m) & ~cv.filled(), P.BLOOD[0])
            if i >= 5:
                for q in range(3):
                    P.chunk(cv, c + 3 + q * 3, c - 4 + q * 2 + (i - 5) * 2, 2, P.BLOOD)
        if i == 3:
            P.star(cv, c, c, 4, core=P.WHITE, arm=P.BLOOD[4], diag=True)
        frames.append(cv)
    save("execute_mark", frames, "play", False, 20.0)


def heal_orb():
    """12x12 dongu: yesil golgeli kure (kontur) + ortada beyaz arti; nabiz gibi buyuyup kuculur, ust solda parilti."""
    frames = []
    for i in range(4):
        cv = P.Canvas(12, 12)
        r = 3.9 + (0.6 if i in (1, 2) else 0.0)
        P.puffs(cv, [(6.0, 6.0, r)], P.HEAL)
        for (x, y) in ((6, 5), (6, 6), (6, 7), (5, 6), (7, 6)):
            cv.px(x - 1, y - 1, P.WHITE)
        if i == 2:
            P.star(cv, 9.5, 2.5, 1, core=P.WHITE, arm=P.HEAL[4])
        frames.append(cv)
    save("heal_orb", frames, "loop", True, 10.0)


# ====================================================================== Matryoshka
def mini_fw():
    """8x8 dongu: kucuk havai fisek topu (parlak cekirdek, turuncu hale, kontur) + titreyen kivilcim kuyrugu."""
    frames = []
    for i in range(2):
        cv = P.Canvas(8, 8)
        m = P.puffs(cv, [(4.5, 3.5, 2.3 + 0.3 * i)], P.FIRE)
        cv.px(4, 3, P.WHITE)
        cv.px(2 - i, 6, P.FIRE[3])
        cv.px(1 + i, 7, P.FIRE[2])
        if i == 1:
            cv.px(6.5, 1, P.FIRE[4])
        frames.append(cv)
    save("mini_fw", frames, "loop", True, 12.0)


def mini_pop():
    """64x64 tek seferlik havai fisek patlamasi, tasarim yaricapi 29 px = 35 dunya (Matryoshka; oyunda olcek ~1): beyaz
    cekirdek, 14 isinda renkli kivilcim basliklari (altin / kirmizi / camgobegi / mor) kuyruklariyla disari acilir, sonra
    yercekimiyle sarkip goz kirpar."""
    n = 7
    c = 32
    R = 29
    frames = []
    rng = random.Random(91)
    rays = [(TAU * k / 14 + rng.uniform(-0.1, 0.1), P.FW_COLS[k % 4], rng.uniform(0.85, 1.05)) for k in range(14)]
    for i in range(n):
        cv = P.Canvas(64, 64)
        t = i / (n - 1)
        if i == 0:
            P.star(cv, c, c, 5, core=P.WHITE, arm=P.FIRE[4], diag=True)
            P.disc_flash(cv, c, c, 2.2, core=P.WHITE)
            frames.append(cv)
            continue
        d = R * P.ease_out(min(1.0, t * 1.5))
        drop = 9 * max(0.0, t - 0.4) ** 1.5
        for (a, cols, lk) in rays:
            dd = d * lk
            hx = c + math.cos(a) * dd
            hy = c + math.sin(a) * dd + drop * 3
            if t > 0.65 and (i + int(a * 10)) % 2:
                continue
            tail = 6 if t < 0.6 else 2
            for s_ in range(1, tail):
                f = s_ / tail
                cv.px(c + math.cos(a) * (dd - s_ * 1.5), c + math.sin(a) * (dd - s_ * 1.5) + drop * 3 * (1 - f * 0.4), cols[0 if f > 0.5 else 1])
            cv.px(hx, hy, cols[2])
            if t < 0.6:
                cv.px(hx + 1, hy, cols[1])
                cv.px(hx, hy + 1, cols[1])
                cv.px(hx + 1, hy + 1, cols[0])
        if i == 1:
            P.disc_flash(cv, c, c, 5, core=P.WHITE, rim=P.FIRE[4])
        frames.append(cv)
    save("mini_pop", frames, "play", False, 22.0)


# ====================================================================== Seken Mermiler / Valerius vurus
def bounce_spark():
    """16x16 tek seferlik sekme kivilcimi: beyaz arti parlama, disari firlayan 5 kisa sari-beyaz cizgi (kontursuz isik),
    sonda noktalara soner."""
    n = 5
    c = 8
    frames = []
    rng = random.Random(95)
    rays = [(rng.uniform(0, TAU), rng.uniform(0.7, 1.0)) for _ in range(5)]
    for i in range(n):
        cv = P.Canvas(16, 16)
        t = i / (n - 1)
        if i < 2:
            P.star(cv, c, c, 3 - i, core=P.WHITE, arm=P.BOLT[3], diag=i == 0)
        for (a, lk) in rays:
            d0 = 2 + 5 * t * lk
            L = max(1, int(3 * (1 - t)) + 1)
            for s_ in range(L):
                cv.px(c + math.cos(a) * (d0 + s_), c + math.sin(a) * (d0 + s_) + t * t * 2, P.BOLT[4] if s_ == L - 1 else P.BOLT[2])
        frames.append(cv)
    save("bounce_spark", frames, "play", False, 24.0)


def shuriken_hit():
    """20x20 tek seferlik: celik kesik capraz (beyaz agiz, kan kirmizisi kontur) + firlayan kan damlalari."""
    n = 5
    c = 10
    frames = []
    for i in range(n):
        cv = P.Canvas(20, 20)
        t = i / (n - 1)
        if i < 4:
            L = 7 * min(1.0, (i + 1) / 2)
            w = 2.6 * (1 - t) + 0.6
            for sgn in (1, -1):
                m = P.thick_line(P.Canvas(20, 20), c - L, c - L * sgn, c + L, c + L * sgn, w, P.WHITE)
                cv.put(m, P.WHITE)
                cv.put(P.outline_of(m) & ~cv.filled(), P.BLOOD[1])
        for q in range(5):
            a = -math.pi / 2 + (q - 2) * 0.55
            d = 3 + 7 * P.ease_out(t)
            if i >= 1:
                P.chunk(cv, c + math.cos(a) * d, c + math.sin(a) * d + t * t * 6, 2 if t < 0.6 else 1, P.BLOOD)
        frames.append(cv)
    save("shuriken_hit", frames, "play", False, 24.0)


# ====================================================================== genel sok dalgalari
def shockwave(name, w, h, rx_max, n, fps, pal, puff_pal=None, sparks=None, seed=3, swirl=False, stars=False, core=None):
    """Genisleyen KALIN dolu halka (dis kenar parlak, kontur), basta krem parlama + 4 isin; halkanin disinda kisa hiz
    cizgileri, istege bagli: puff_pal ile halka boyunca dolu toz/bulut puflari, sparks renkli kivilcim, swirl halka
    icinde donen hilal kesikler, stars kozmik yildizlar. Sonda halka parcalanir."""
    cx, cy = w / 2, h / 2
    sq = (h / w) * 0.95
    rng = random.Random(seed)
    lines = [TAU * k / 16 + rng.uniform(-0.1, 0.1) for k in range(16)]
    star_pts = [(rng.uniform(0, TAU), rng.uniform(0.2, 1.0)) for _ in range(14)]
    frames = []
    for i in range(n):
        cv = P.Canvas(w, h)
        t = i / (n - 1)
        R = 8 + (rx_max - 8) * P.ease_out(t)
        thick = max(2.5, min(R * 0.32, rx_max * 0.11 * (1.0 - 0.55 * t)))
        if core is not None and i > 0:
            P.burst(cv, cx, cy, rx_max * 0.42, min(1.0, 0.13 + t * 1.05), core[0], core[1], seed + 40, n_puffs=7,
                    squash=min(1.0, sq * 1.5), shard_col=core[0][4])
        if puff_pal is not None and i > 0:
            for q in range(14):
                a = TAU * q / 14 + 0.2
                x = cx + math.cos(a) * (R - thick * 0.5)
                y = cy + math.sin(a) * (R - thick * 0.5) * sq - 2 - 3 * t
                pr = rx_max * 0.1 * (1 - 0.45 * t)
                cut = [(x, y - pr * (0.3 + 0.8 * t), pr * (0.2 + 0.8 * t))] if t > 0.3 else None
                P.puffs(cv, [(x, y, pr), (x + pr * 0.7, y + 1, pr * 0.7)], puff_pal, cut=cut)
        if swirl and 0 < i and t < 0.9:
            for q in range(4):
                a1 = TAU * q / 4 + t * 4.0
                P.arc_band(cv, cx, cy, R * 0.78, a1 - 1.5, a1, max(2.0, rx_max * 0.09 * (1 - t)), 1.0, pal, squash=sq)
                P.arc_band(cv, cx, cy, R * 0.5, a1 + 0.8 - 1.1, a1 + 0.8, max(1.5, rx_max * 0.06 * (1 - t)), 1.0, pal, squash=sq)
        if i > 0:
            P.shock_ring(cv, cx, cy, R, thick, t, pal, sq, seed, break_from=0.45)
        if 0 < i and t < 0.7:
            for a in lines:
                d0 = R + 3 + (i % 2)
                L = max(1, int(rx_max * 0.08 * (1 - t)))
                for s_ in range(L):
                    cv.px(cx + math.cos(a) * (d0 + s_ * 1.5), cy + math.sin(a) * (d0 + s_ * 1.5) * sq, pal[4] if s_ == 0 else pal[3])
        if stars:
            for (a, dk) in star_pts:
                d = R * dk
                if rng.random() < 1.0 - 0.6 * t:
                    P.star(cv, cx + math.cos(a + t) * d, cy + math.sin(a + t) * d * sq, 1 if dk > 0.6 else 0, core=P.CREAM, arm=P.VOID[4])
        if sparks is not None and 0 < i:
            for q in range(10):
                a = rng.uniform(0, TAU)
                d = R * rng.uniform(0.6, 1.1)
                if rng.random() < 1.0 - t * 0.7:
                    P.star(cv, cx + math.cos(a) * d, cy + math.sin(a) * d * sq, 1 if q % 3 == 0 else 0, core=sparks[1], arm=sparks[0])
        if i == 0:
            r0 = rx_max * 0.14
            P.disc_flash(cv, cx, cy, r0, core=P.CREAM, rim=pal[4], squash=sq * 1.2)
            for q in range(4):
                a = q * TAU / 4
                for d in range(int(r0) + 1, int(r0 * 2.4)):
                    cv.px(cx + math.cos(a) * d, cy + math.sin(a) * d * sq * 1.2, pal[4] if d < r0 * 1.7 else pal[3])
        elif i == 1:
            P.disc_flash(cv, cx, cy, rx_max * 0.09, core=pal[4], squash=sq * 1.2)
        frames.append(cv)
    save(name, frames, "play", False, fps)


# ====================================================================== BIGerang: kasirga
def vortex():
    """200x152 dongu, tasarim yaricapi 99 px = 120 dunya (BIGerang kasirgasi; oyunda olcek ~1), yerde basik (0,75). Dort
    kalin sarmal ruzgar kolu (on kenar beyaz, arka mavi, kontur) doner; ortada bos goz; kollarla savrulan yaprak / toz
    parcalari."""
    n = 6
    cx, cy = 100, 76
    K = 99 / 40
    sq = 0.75
    rng = random.Random(101)
    debris = [(rng.uniform(0, TAU), rng.uniform(12, 36) * K, rng.choice((P.HEAL, P.DUST))) for _ in range(18)]
    frames = []
    for i in range(n):
        cv = P.Canvas(200, 152)
        X, Y = cv.grid()
        dx, dy = X - cx, (Y - cy) / sq
        r = np.hypot(dx, dy) / K
        th = np.arctan2(dy, dx)
        rot = TAU * i / n / 4
        m_all = np.zeros((cv.h, cv.w), dtype=bool)
        tone = np.zeros((cv.h, cv.w), dtype=int)
        for arm in range(4):
            base = arm * TAU / 4 + rot
            phase = np.mod(th - base - r * 0.11 + math.pi, TAU) - math.pi
            half = 0.42 * np.clip((r - 4) / 8, 0, 1) * np.clip((38 - r) / 16, 0, 1)
            m = (np.abs(phase) < half) & (r > 4) & (r < 38)
            k = (phase / np.maximum(half, 1e-3) + 1) / 2
            tt = np.where(k > 0.75, 4, np.where(k > 0.45, 3, np.where(k > 0.2, 2, 1)))
            tone = np.where(m, tt, tone)
            m_all |= m
        for t in range(1, 5):
            cv.put(m_all & (tone == t), P.WIND[t])
        cv.put(P.outline_of(m_all) & ~cv.filled(), P.WIND[0])
        for (a0, d, pal) in debris:
            a = a0 + TAU * i / n / 4 * 2.2
            P.chunk(cv, cx + math.cos(a) * d, cy + math.sin(a) * d * sq, 2, pal)
        frames.append(cv)
    save("vortex", frames, "loop", True, 12.0)


# ====================================================================== Nuukler: mantar bulutu
def mushroom():
    """144x184 tek seferlik, zemin (72, 168) - Nuukler 100 birim alanina gore 1,5 kat buyuk tasarim (oyunda olcek 1). Yer parlamasi -> ates topu yukselir -> sap + mantar sapkasi (ic ates ISI
    golgesi, dis kabuk dumana doner) + yerde yayilan toz halkasi -> tamamen duman, hilale asinarak dagilir."""
    n = 12
    K = 1.5
    gx, gy = 72, 168
    rng = random.Random(111)
    cap_off = []
    for k in range(13):
        a_ = TAU * k / 13 + rng.uniform(-0.2, 0.2)
        rr = 0.55 + 0.45 * (k % 2)
        cap_off.append((math.cos(a_) * rr, math.sin(a_) * rr * 0.75 - 0.1, rng.uniform(0.34, 0.46)))
    for k in range(5):
        cap_off.append((-0.8 + 0.4 * k, 0.42 + rng.uniform(-0.05, 0.05), 0.3))
    frames = []
    for i in range(n):
        cv = P.Canvas(144, 184)
        t = i / (n - 1)
        # yerde toz halkasi (arka yari)
        ring_r = (10 + 32 * P.ease_out(min(1.0, t * 1.3))) * K
        dust = []
        for q in range(16):
            a = TAU * q / 16
            dust.append((gx + math.cos(a) * ring_r, gy + math.sin(a) * ring_r * 0.3, 5.5 * K * (1 - 0.5 * t), a))
        dcut = lambda x, y, pr: [(x, y - pr * (0.3 + 0.8 * t), pr * (0.2 + 0.8 * t))] if t > 0.45 else None
        if i > 0:
            for (x, y, pr, a) in dust:
                if math.sin(a) < 0:
                    P.puffs(cv, [(x, y - 2, pr)], P.DUST, cut=dcut(x, y - 2, pr))
        if i == 0:
            P.disc_flash(cv, gx, gy - 3, 16 * K, core=P.CREAM, rim=P.FIRE[4], squash=0.45)
            P.star(cv, gx, gy - 6, 9, core=P.WHITE, arm=P.FIRE[4])
            frames.append(cv)
            continue
        rise = P.ease_out(min(1.0, (i - 1) / 4))
        top = gy - (12 + 62 * rise) * K
        cap_r = (9 + 15 * P.ease_out(min(1.0, (i - 1) / 5))) * K
        cool = max(0.0, (t - 0.3) / 0.7)
        fade = max(0.0, (t - 0.62) / 0.38)
        stem = []
        q = 0
        y = gy - 6 * K
        while y > top + cap_r * 0.3:
            w = (6.0 - q * 0.08) * K * (1 - 0.3 * cool)
            if y < gy - (6 + 70 * fade) * K:
                stem.append((gx + 1.5 * math.sin(q * 0.6 + i * 0.7), y - 3 * K * fade, w * (1 - 0.3 * fade)))
            y -= 3.5
            q += 1
        cap = []
        for k, (dx, dy, rk) in enumerate(cap_off):
            drift = 1 + 0.25 * fade
            cap.append((gx + dx * cap_r * 0.95 * drift, top + dy * cap_r * 0.7 - 4 * K * fade, cap_r * rk * (1 - 0.45 * fade)))
        cap.append((gx, top - 4 * K * fade, cap_r * 0.5 * (1 - 0.45 * fade)))
        if cool < 0.15:
            pal = P.FIRE
        elif cool < 0.45:
            pal = P.EMBER
        elif cool < 0.7:
            pal = [P.SMOKE[0], P.EMBER[1], P.SMOKE[2], P.SMOKE[3], P.SMOKE[4]]
        else:
            pal = P.SMOKE
        cuts = None
        if fade > 0:
            cuts = [(x + r * 0.35, y + r * 0.4, r * (0.3 + 0.75 * fade)) for (x, y, r) in cap + stem[::2]]
        m = P.puffs(cv, stem + cap, pal, cut=cuts)
        if cool < 0.4:
            X, Y = cv.grid()
            hot = m & (np.hypot(X - gx, (Y - top - cap_r * 0.35) * 1.6) < cap_r * (0.3 - 0.5 * cool)) & P.erode(P.erode(m))
            cv.put(hot, P.FIRE[4] if cool < 0.15 else P.FIRE[3])
        if i > 0:
            for (x, y, pr, a) in dust:
                if math.sin(a) >= 0:
                    P.puffs(cv, [(x, y - 2, pr), (x + pr * 0.7, y - 1, pr * 0.7)], P.DUST, cut=dcut(x, y - 2, pr))
        if i < 4:
            P.disc_flash(cv, gx, gy - 4, (8 - i * 2) * K, core=P.CREAM, rim=P.FIRE[4], squash=0.5)
        frames.append(cv)
    save("mushroom", frames, "play", False, 16.0)


# ====================================================================== Prizm: kristaller
def crystal(name, pal):
    """20x28 dongu: yuzeyli prizma kristali (sol yuzler acik, sag yuzler koyu, orta sirt parlak, kontur), zeminde koyu
    golge; parilti bandi asagi kayar, tepede yildiz goz kirpar."""
    frames = []
    for i in range(6):
        cv = P.Canvas(20, 28)
        sh = P.ellipse_mask(cv, 10, 25.5, 6, 1.6)
        cv.put(sh, (30, 30, 40), 110)
        top, lft, rgt, bl, br_, mid_t, mid_b = (10, 1.5), (3, 10), (17, 10), (6.5, 25), (13.5, 25), (10.5, 9), (10, 25)
        faces = [([top, lft, mid_t], 4), ([top, mid_t, rgt], 2), ([lft, bl, mid_b, mid_t], 3), ([mid_t, mid_b, br_, rgt], 1)]
        m = P.facets(cv, faces, pal)
        X, Y = cv.grid()
        band = (Y - X * 0.6 - i * 5.5) % 33
        cv.put(m & (band < 2.0) & (X < 10), pal[4])
        cv.put(m & (band < 1.2) & (X >= 10), pal[3])
        if i in (1, 4):
            P.star(cv, 10, 3 if i == 1 else 12, 2, core=P.WHITE, arm=pal[4])
        frames.append(cv)
    save(name, frames, "loop", True, 8.0)


def crystal_shard(name, pal):
    """8x12 dongu: Prizm sarapnel parcasi (ucu yukari, oyunda ucus yonune dondurulur; olcek 1 - buyuk kristali 0,4'e
    kucultmek pikselleri bozuyordu). Iki yuzlu ince prizma + kontur, parilti kareden kareye kayar."""
    frames = []
    for i in range(4):
        cv = P.Canvas(8, 12)
        top, lft, rgt, bot, mid = (4, 0.8), (1.6, 6), (6.4, 6), (4, 11.2), (4.2, 6)
        m = P.facets(cv, [([top, lft, mid], 4), ([top, mid, rgt], 2), ([lft, bot, mid], 3), ([mid, bot, rgt], 1)], pal)
        cv.px(3, 2 + (i % 4) * 2, P.WHITE if i % 2 == 0 else pal[4])
        frames.append(cv)
    save(name, frames, "loop", True, 12.0)


def crystal_burst():
    """40x40 tek seferlik kristal parcalanmasi: beyaz parlama, 7 ucgen buz parcasi (yuzeyli, kontur) donerek disari
    ucar ve kuculur, ince kirik halka, parilti yildizlari."""
    n = 7
    c = 20
    rng = random.Random(121)
    shards = [(TAU * k / 7 + rng.uniform(-0.2, 0.2), rng.uniform(0.8, 1.1), rng.uniform(0, TAU)) for k in range(7)]
    frames = []
    for i in range(n):
        cv = P.Canvas(40, 40)
        t = i / (n - 1)
        if 0 < i:
            P.shock_ring(cv, c, c, 6 + 12 * P.ease_out(t), max(1.2, 2.6 * (1 - t)), t, P.ICE, 1.0, 5, break_from=0.3)
        for (a, dk, spin) in shards:
            d = 3 + 14 * P.ease_out(t) * dk
            x, y = c + math.cos(a) * d, c + math.sin(a) * d + t * t * 3
            s = 4.0 * (1 - 0.6 * t)
            sp = spin + t * 5
            pts = [(x + math.cos(sp) * s, y + math.sin(sp) * s), (x + math.cos(sp + 2.3) * s * 0.6, y + math.sin(sp + 2.3) * s * 0.6),
                   (x + math.cos(sp + 3.9) * s * 0.6, y + math.sin(sp + 3.9) * s * 0.6)]
            if s > 1.2:
                P.facets(cv, [([pts[0], pts[1], (x, y)], 4), ([pts[0], (x, y), pts[2]], 2), ([pts[1], pts[2], (x, y)], 3)], P.ICE)
            else:
                cv.px(x, y, P.ICE[4])
        if i == 0:
            P.disc_flash(cv, c, c, 6, core=P.WHITE, rim=P.ICE[4])
            P.star(cv, c, c, 9, core=P.WHITE, arm=P.ICE[3])
        elif 2 <= i <= 4:
            P.star(cv, c + (i - 3) * 6, c - 6 + i, 1, core=P.WHITE, arm=P.ICE[4])
        frames.append(cv)
    save("crystal_burst", frames, "play", False, 20.0)


# ====================================================================== Bumerang Testeresi
def saw():
    """80x80 dongu, testere yaricapi 33 px = 40 dunya (oyunda olcek ~1). Celik disk (sol ust isikli, koyu kontur), 20 egik
    dis, ic oluk halkasi, ortada gobek + civata; 4 kare = bir dis araligi donus (kesintisiz dongu); disinda donen beyaz
    hiz hilalleri."""
    frames = []
    c = 40
    NT = 20
    for i in range(4):
        cv = P.Canvas(80, 80)
        rot = i * (TAU / NT) / 4
        faces = []
        for k in range(NT):
            a = rot + TAU * k / NT
            p0 = (c + math.cos(a) * 25.5, c + math.sin(a) * 25.5)
            p1 = (c + math.cos(a + 0.2) * 33.0, c + math.sin(a + 0.2) * 33.0)
            p2 = (c + math.cos(a + 0.3) * 25.5, c + math.sin(a + 0.3) * 25.5)
            lit = math.cos(a) * P.LIGHT[0] + math.sin(a) * P.LIGHT[1]
            faces.append(([p0, p1, p2], 4 if lit > 0.3 else (3 if lit > -0.3 else 2)))
        teeth = P.facets(cv, faces, P.STEEL, outline=False)
        disk = P.Canvas(80, 80)
        dm = P.puffs(disk, [(c, c, 26.5)], P.STEEL, outline=False)
        cv.rgba[dm] = disk.rgba[dm]
        X, Y = cv.grid()
        rr = np.hypot(X - c, Y - c)
        cv.put(dm & (rr > 21.5) & (rr < 23.0), P.STEEL[1])
        cv.put(dm & (rr > 23.0) & (rr < 24.0) & (Y < c), P.STEEL[4])
        hub = rr < 10.5
        cv.put(hub, P.STEEL[1])
        cv.put(rr < 8.5, P.STEEL[2])
        cv.put((rr < 8.5) & (X < c - 1) & (Y < c - 1), P.STEEL[3])
        cv.put(rr < 3.0, P.STEEL[0])
        cv.put((rr < 2.0) & (X < c) & (Y < c), P.STEEL[2])
        for k in range(4):
            a = rot * 4 + TAU * k / 4 + 0.4
            x, y = c + math.cos(a) * 15.5, c + math.sin(a) * 15.5
            hole = np.hypot(X - x, Y - y) < 2.4
            cv.put(hole, P.STEEL[0])
        allm = teeth | dm
        cv.put(P.outline_of(allm) & ~cv.filled(), P.STEEL[0])
        for k in range(3):
            a1 = rot * 6 + k * TAU / 3
            P.arc_band(cv, c, c, 38.5, a1 - 0.9, a1, 2.0, 1.0, P.WIND, outline=False)
        frames.append(cv)
    save("saw", frames, "loop", True, 20.0)


# ====================================================================== Earthquake / Tektonik
def quake_tile():
    """24x20 tek seferlik (hat boyunca ~20 dunya aralikla dizilir), zemin y 14. Kirik catlak acilir (koyu yarik + acik
    dudak), toprak parcalari firlar, dolu toz puflari kalkar ve hilale asinir."""
    n = 8
    gy = 14
    rng = random.Random(131)
    rocks = [(rng.uniform(-8, 8), rng.uniform(0.6, 1.2)) for _ in range(4)]
    crack = [(1, gy + 0.5), (6, gy - 0.5), (10, gy + 1), (14, gy - 0.5), (18, gy + 0.8), (23, gy)]
    frames = []
    for i in range(n):
        cv = P.Canvas(24, 20)
        t = i / (n - 1)
        if t < 0.85:
            for (a_, b_) in zip(crack[:-1], crack[1:]):
                P.thick_line(cv, a_[0], a_[1], b_[0], b_[1], 2.2 if t < 0.6 else 1.4, P.EARTH[0])
            if t < 0.6:
                for (a_, b_) in zip(crack[:-1], crack[1:]):
                    P.thick_line(cv, a_[0], a_[1] - 1.4, b_[0], b_[1] - 1.4, 0.9, P.EARTH[3])
        if 0 < i:
            k = t
            for q, (dx, r0) in enumerate(((-6, 3.4), (0, 4.2), (6, 3.4))):
                x = 12 + dx * (1 + 0.3 * k)
                y = gy - 1 - 3 * k
                r = r0 * (0.7 + 0.5 * min(1.0, k * 3)) * (1 - 0.35 * k)
                cut = [(x - r * 0.1, y - r * (0.3 + 0.8 * k), r * (0.25 + 0.8 * k))] if k > 0.35 else None
                P.puffs(cv, [(x, y, r)], P.DUST, cut=cut)
        for (dx, sp) in rocks:
            h = math.sin(min(1.0, t * 1.3) * math.pi) * 9 * sp
            if t < 0.9:
                P.chunk(cv, 12 + dx * (1 + 0.4 * t), gy - 1 - h, 2, P.EARTH)
        if i == 0:
            P.disc_flash(cv, 12, gy - 1, 4, core=P.DUST[4], rim=P.DUST[3], squash=0.5)
        frames.append(cv)
    save("quake_tile", frames, "play", False, 18.0)


def rift_tile(name="rift_tile", H=12, K=1.0, cap=False):
    """16xH dongu, +x'te 16 px aralikla dosenir (periyodik). Kavrulmus koyu kenarli, icinde kor gibi parlayan zikzak
    yarik: eksende beyaz-sari cekirdek, kenarda kirmizi; x boyunca kayan parlaklik nabzi. rift_tile (12 px = 20 dunya
    serit) Tektonik yariklari; rift_tile_wide (36 px, K 2,75 = 40 dunya) Earthquake finali - y'de 2 kat buyutmek yerine
    ayni texel yogunlugunda."""
    n = 6
    cyc = H / 2
    frames = []
    for i in range(n):
        cv = P.Canvas(16, H)
        X, Y = cv.grid()
        tp = cap_taper(X, cap)
        path = cyc + ((1.6 + 0.7 * (K - 1)) * np.sin(X / 16 * TAU * 2 + 0.4) + 0.7 * K * np.sin(X / 16 * TAU * 3 + 1.9) * min(1.0, K / 2)) * tp
        v = np.abs(Y - path)
        w = (1.5 + 0.5 * np.sin(X / 16 * TAU + 2.2)) * (1 + 0.45 * (K - 1)) * tp
        scorch = (np.abs(Y - cyc) <= (5.2 + 0.5 * np.sin(X / 16 * TAU * 2 + 1.0)) * K * tp) & (tp > 0.06)
        cv.put(scorch, (44, 30, 26))
        cv.put(scorch & (P.noise_xy(X, Y, 6, 141, period_x=16) > 0.62), (62, 44, 34))
        if K > 1.5:
            cv.put(scorch & (np.abs(Y - cyc) > 5.2 * K - 1.5), (34, 24, 22))
            cv.put(scorch & (P.noise_xy(X, Y * 0.7, 5, 142, period_x=16) > 0.7) & (v > w + 3), P.EARTH[1])
        cv.put(scorch & (v < w + 1.4), P.EARTH[0])
        glow = v < w
        pulse = 0.5 + 0.5 * np.cos((X / 16 - i / n) * TAU)
        cv.put(glow, P.FIRE[1])
        cv.put(glow & (v < w * 0.65), P.FIRE[2])
        cv.put(glow & (v < w * 0.4) & (pulse > 0.3), P.FIRE[3])
        cv.put(glow & (v < w * 0.3) & (pulse > 0.75), P.FIRE[4])
        cv.put(scorch & (v >= w) & (v < w + 1.4) & (Y < path), P.EARTH[2])
        frames.append(cv)
    save(name + ("_cap" if cap else ""), frames, "loop", True, 8.0)


def pillar():
    """48x96 tek seferlik, zemin (24, 88). Yuzeyli kaya sutunu (sol yuz acik, on orta, sag koyu, yatay tabaka cizgileri,
    sivri kirik tepe) yerden firlar, dibinde catlak + toz puflari; sonda parcalanip coker."""
    n = 12
    gx, gy = 24, 88
    rng = random.Random(151)
    frames = []
    for i in range(n):
        cv = P.Canvas(48, 96)
        t = i / (n - 1)
        rise = P.ease_out(min(1.0, i / 3))
        crumble = max(0.0, (t - 0.7) / 0.3)
        H = 64 * rise * (1 - 0.85 * crumble)
        # dip toz (arka)
        for q in range(4):
            x = gx - 14 + q * 9.5
            y = gy - 2 - 2 * t
            r = (4.5 + (q % 2)) * (0.6 + 0.4 * min(1.0, i / 2)) * (1 - 0.4 * t)
            if i > 0 and q in (1, 2):
                P.puffs(cv, [(x, y - 3, r)], P.DUST, cut=[(x, y - 3 - r * 0.8, r * t)] if t > 0.3 else None)
        if H > 3:
            base_w, top_w = 11.0, 4.0
            y0, y1 = gy, gy - H
            tipx = gx + 1.5
            faces = [([(gx - base_w, y0), (gx - top_w - 1, y1 + 6), (gx - top_w + 3, y1 + 4), (gx - base_w + 6, y0)], 3),
                     ([(gx - base_w + 6, y0), (gx - top_w + 3, y1 + 4), (gx + top_w - 1, y1 + 4), (gx + base_w - 5, y0)], 2),
                     ([(gx + base_w - 5, y0), (gx + top_w - 1, y1 + 4), (gx + top_w + 1, y1 + 5), (gx + base_w, y0)], 1),
                     ([(gx - top_w - 1, y1 + 6), (tipx - 2, y1), (tipx + 1.5, y1 + 2), (gx + top_w + 1, y1 + 5), (gx + top_w - 1, y1 + 4),
                       (gx - top_w + 3, y1 + 4)], 4)]
            rock = P.Canvas(48, 96)
            m = P.facets(rock, faces, P.STONE, outline=False)
            X, Y = cv.grid()
            notch = m & ~P.erode(P.erode(m)) & (P.noise_xy(X, Y * 0.6, 5, 153) < 0.33) & (Y < gy - 2)
            m &= ~notch
            cv.rgba[m] = rock.rgba[m]
            for (ox_, oy_, L_) in ((-3, 0.3, 7), (2, 0.55, 6), (-1, 0.78, 5)):
                yy = y1 + (y0 - y1) * oy_
                pts = [(gx + ox_, yy), (gx + ox_ + 2, yy + L_ * 0.4), (gx + ox_ + 1, yy + L_)]
                for (a_, b_) in zip(pts[:-1], pts[1:]):
                    cv.put(P.thick_line(P.Canvas(48, 96), a_[0], a_[1], b_[0], b_[1], 1.0, P.STONE[1]) & m, P.STONE[1])
            cv.put(P.outline_of(m) & ~cv.filled(), P.STONE[0])
            if crumble > 0:
                for q in range(5):
                    P.chunk(cv, gx + rng.uniform(-10, 10), gy - rng.uniform(4, H + 4) + crumble * 8, 3, P.STONE)
        if i <= 3:
            for k in range(4):
                a = math.pi + k * math.pi / 3 + 0.3
                P.thick_line(cv, gx, gy, gx + math.cos(a) * 14, gy - math.sin(a) * 3 + 1, 1.4, P.EARTH[0])
        for q in (0, 3):
            x = gx - 14 + q * 9.5
            y = gy - 2 - 2 * t
            r = 5.0 * (0.6 + 0.4 * min(1.0, i / 2)) * (1 - 0.4 * t)
            if i > 0:
                P.puffs(cv, [(x, y, r), (x + r * 0.8 * (1 if q else -1), y + 1, r * 0.7)], P.DUST,
                        cut=[(x, y - r * 0.8, r * t)] if t > 0.3 else None)
        if i < 3:
            for q in range(5):
                a = -math.pi / 2 + (q - 2) * 0.5
                d = 8 + i * 8
                P.chunk(cv, gx + math.cos(a) * d * 0.8, gy - 20 + math.sin(a) * d, 2, P.STONE)
        frames.append(cv)
    save("pillar", frames, "play", False, 16.0)


def crack_x():
    """64x48 tek seferlik, merkez (32, 24). Yerde X bicimli iki kirik yarik acilir: icleri kor lav (ISI - beyaz cekirdek,
    kirmizi kenar), koyu kavrulmus dudak; taslar firlar; kor sogur (turuncu -> koyu kirmizi -> kapanir)."""
    n = 8
    cx, cy = 32, 24
    rng = random.Random(161)
    arms = []
    for sgn in (1, -1):
        for d in (1, -1):
            pts = [(cx, cy)]
            a = math.atan2(0.62 * sgn * d, d)
            for s_ in range(4):
                x, y = pts[-1]
                aa = a + rng.uniform(-0.35, 0.35)
                pts.append((x + math.cos(aa) * 7.5, y + math.sin(aa) * 7.5))
            arms.append(pts)
    rocks = [(rng.uniform(0, TAU), rng.uniform(0.6, 1.0)) for _ in range(8)]
    frames = []
    for i in range(n):
        cv = P.Canvas(64, 48)
        t = i / (n - 1)
        grow = min(1.0, (i + 1) / 3)
        cool = max(0.0, (t - 0.35) / 0.65)
        lava = np.zeros((cv.h, cv.w), dtype=bool)
        lip = np.zeros((cv.h, cv.w), dtype=bool)
        tmp = P.Canvas(64, 48)
        for pts in arms:
            nseg = max(1, int(round(grow * 4)))
            for k, (a_, b_) in enumerate(zip(pts[:nseg], pts[1:nseg + 1])):
                w = 4.2 - k * 0.7
                lip |= P.thick_line(tmp, a_[0], a_[1], b_[0], b_[1], w + 2.4, P.EARTH[0])
                lava |= P.thick_line(tmp, a_[0], a_[1], b_[0], b_[1], max(1.0, w * (1 - 0.6 * cool)), P.FIRE[2])
        cv.put(lip, P.EARTH[0])
        cv.put(lip & ~lava & (cv.grid()[1] < cy), P.EARTH[1])
        if cool < 0.95:
            pal = P.FIRE if cool < 0.4 else P.EMBER
            sub = P.Canvas(64, 48)
            P.heat_fill(sub, lava, pal, levels=(1, 2, 3, 5), outline=False)
            fm = sub.filled()
            cv.rgba[fm] = sub.rgba[fm]
        for (a, sp) in rocks:
            h = math.sin(min(1.0, t * 1.4) * math.pi) * 14 * sp
            d = 6 + 16 * P.ease_out(t) * sp
            if t < 0.9 and i > 0:
                P.chunk(cv, cx + math.cos(a) * d, cy + math.sin(a) * d * 0.6 - h, 2 if sp < 0.85 else 3, P.EARTH)
        if i == 0:
            P.disc_flash(cv, cx, cy, 7, core=P.CREAM, rim=P.FIRE[4], squash=0.6)
            P.star(cv, cx, cy, 5, core=P.WHITE, arm=P.FIRE[4])
        frames.append(cv)
    save("crack_x", frames, "play", False, 18.0)


def fault_blast():
    """128x96 tek seferlik, merkez (64, 70). Yer yarilir (parlama), lav fiskiyesi (ISI golgeli dolu kutle) yukselir, lav
    toplari ve taslar balistik ucar, yere lav sicramalari; fiskiye dumana donup hilale asinir, sicramalar sogur."""
    n = 12
    cx, cy = 64, 70
    rng = random.Random(171)
    blobs = [(rng.uniform(-1, 1), rng.uniform(0.55, 1.0), rng.random() < 0.55) for _ in range(12)]
    splats = [(rng.uniform(-44, 44), rng.uniform(-6, 8), rng.uniform(2.2, 3.6)) for _ in range(6)]
    frames = []
    for i in range(n):
        cv = P.Canvas(128, 96)
        t = i / (n - 1)
        # zemin yarigi + sicramalar
        X, Y = cv.grid()
        w = 40 * P.ease_out(min(1.0, t * 3))
        if w > 1:
            gash = P.blob_mask(cv, cx, cy + 2, w, 5 * (1 - 0.4 * t), 172, wobble=0.25, lobes=9)
            cv.put(gash, (40, 24, 20))
            inner = P.erode(P.erode(gash))
            cv.put(inner, P.FIRE[1] if t < 0.6 else P.EMBER[0])
            if t < 0.5:
                cv.put(P.erode(inner), P.FIRE[3])
        if t > 0.35:
            for (sx, sy, sr) in splats:
                k = min(1.0, (t - 0.35) / 0.25)
                col = P.FIRE if t < 0.65 else P.EMBER
                P.puffs(cv, [(cx + sx, cy + sy, sr * k)], col, squash=0.5)
        # fiskiye
        if 0 < i < 9:
            k = (i - 1) / 7
            H = 58 * math.sin(min(1.0, k * 1.6) * math.pi * 0.5) * (1 - 0.7 * max(0.0, k - 0.6) / 0.4)
            circles = []
            yy = cy
            q = 0
            while yy > cy - H:
                rr = 11.5 - q * 0.35 + 1.6 * math.sin(q * 1.9 + i)
                circles.append((cx + 3 * math.sin(q * 0.8 + i * 0.9), yy, rr))
                yy -= 5
                q += 1
            circles.append((cx, cy - H, 14 * (1 - 0.3 * k)))
            circles.append((cx - 11, cy - H + 5, 9 * (1 - 0.3 * k)))
            circles.append((cx + 11, cy - H + 6, 8.5 * (1 - 0.3 * k)))
            circles.append((cx - 13, cy - 4, 8 * (1 - 0.3 * k)))
            circles.append((cx + 13, cy - 3, 7.5 * (1 - 0.3 * k)))
            if k < 0.55:
                mm = np.zeros((cv.h, cv.w), dtype=bool)
                for (x, y, r) in circles:
                    mm |= np.hypot(X - x, Y - y) <= r
                P.heat_fill(cv, mm, P.FIRE, levels=(1, 2, 4, 6))
            else:
                kk = (k - 0.55) / 0.45
                P.puffs(cv, circles, P.SMOKE if kk > 0.4 else [P.SMOKE[0], P.EMBER[1], P.SMOKE[2], P.EMBER[3], P.SMOKE[4]],
                        cut=[(x + r * 0.3, y + r * 0.35, r * (0.3 + 0.7 * kk)) for (x, y, r) in circles])
        if 1 <= i <= 6:
            P.burst(cv, cx, cy - 4, 34, 0.14 + (i - 1) / 6 * 0.86, P.FIRE, P.SMOKE, 173, n_puffs=8, squash=0.55)
        for (dx, sp, is_lava) in blobs:
            if i == 0:
                continue
            h = math.sin(min(1.0, t * 1.3) * math.pi) * 70 * sp
            x = cx + dx * 50 * P.ease_out(min(1.0, t * 1.2))
            if t < 0.85:
                if is_lava:
                    P.puffs(cv, [(x, cy - h, 2.4 * sp + 0.6)], P.FIRE if t < 0.5 else P.EMBER)
                else:
                    P.chunk(cv, x, cy - h, 3 if sp > 0.8 else 2, P.EARTH)
        if i == 0:
            P.disc_flash(cv, cx, cy, 14, core=P.CREAM, rim=P.FIRE[4], squash=0.45)
            P.star(cv, cx, cy - 2, 12, core=P.WHITE, arm=P.FIRE[4])
        frames.append(cv)
    save("fault_blast", frames, "play", False, 16.0)


# ====================================================================== Golge Yankisi / Astral Yorunge
def shade_slash():
    """40x32 tek seferlik, +x'e bakan golge kesigi (assasin shadow_hit dili): kalin mor hilal bastan kuyruga incelir, dis
    kenar parlak lila, koyu kontur; bas ucunda parlama; sonda incelip parcalanir."""
    n = 6
    cx, cy = 12, 16
    frames = []
    for i in range(n):
        cv = P.Canvas(40, 32)
        t = i / (n - 1)
        head = -1.25 + 2.5 * P.ease_out(min(1.0, t * 1.5))
        span = 0.6 + 1.4 * min(1.0, t * 2)
        fade = max(0.0, t - 0.5) / 0.5
        mult = P.break_mult(cv, cx, cy, 0.72, (fade - 0.3) / 0.7, 1.0, lobes=11) if fade > 0.3 else None
        P.arc_band(cv, cx, cy, 20, head - span * (1 - 0.5 * fade), head, 6.0 * (1 - 0.7 * fade), 1.0, P.SHADOW, squash=0.72,
                   mult=mult)
        hx = cx + math.cos(head) * 17
        hy = cy + math.sin(head) * 17 * 0.72
        if t < 0.6:
            P.star(cv, hx, hy, 3 if i % 2 == 0 else 2, core=P.WHITE, arm=P.SHADOW[4], diag=i == 0)
        frames.append(cv)
    save("shade_slash", frames, "play", False, 22.0)


def astral_orb():
    """20x20 dongu (oyunda olcek 1): mor golgeli kure (kontur, sol ust parlak) + etrafinda basik yorungede donen krem
    yildiz (kurenin arkasina gecince gizlenir)."""
    frames = []
    c = 10
    for i in range(6):
        cv = P.Canvas(20, 20)
        a = i * TAU / 6
        sx, sy = c + math.cos(a) * 8.2, c + math.sin(a) * 3.4
        behind = math.sin(a) < 0
        if behind:
            cv.px(sx, sy, P.VOID[4])
        P.puffs(cv, [(c, c, 5.4)], P.VOID)
        cv.px(c - 3, c - 3, P.WHITE)
        cv.px(c - 2, c - 3, P.VOID[4])
        if not behind:
            P.star(cv, sx, sy, 1, core=P.CREAM, arm=P.VOID[4])
        frames.append(cv)
    save("astral_orb", frames, "loop", True, 12.0)


def cosmic_disk():
    """152x152 dongu, disk yaricapi 74 px = 90 dunya (Astral Yorunge finali; oyunda olcek ~1). Yari saydam koyu uzay
    diski (altindaki zemin sezilir; kenari mor bantli, kontur), icinde uc kalin donen sarmal galaksi kolu (on kenar
    lila-beyaz), parlak cekirdek, goz kirpan yildizlar. 8 kare = 1/3 tur (kesintisiz dongu)."""
    n = 8
    c = 76
    K = 74 / 42
    rng = random.Random(181)
    stars = [(rng.uniform(0, TAU), rng.uniform(10, 40) * K, rng.randint(0, n - 1)) for _ in range(30)]
    frames = []
    for i in range(n):
        cv = P.Canvas(152, 152)
        X, Y = cv.grid()
        dx, dy = X - c, Y - c
        r = np.hypot(dx, dy)
        rn = r / K
        th = np.arctan2(dy, dx)
        disk = rn <= 42
        cv.put(disk, (22, 10, 40), 175)
        cv.put(disk & (P.noise_xy(X, Y, 20, 182) > 0.64), (40, 18, 70), 190)
        rot = TAU * i / n / 3
        arms = np.zeros((cv.h, cv.w), dtype=bool)
        tone = np.zeros((cv.h, cv.w), dtype=int)
        for arm in range(3):
            phase = np.mod(th - arm * TAU / 3 - rot - rn * 0.085 + math.pi, TAU) - math.pi
            half = 0.5 * np.clip((rn - 4) / 8, 0, 1) * np.clip((41 - rn) / 18, 0, 1)
            m = (np.abs(phase) < half) & (rn > 4) & (rn < 41)
            k = (phase / np.maximum(half, 1e-3) + 1) / 2
            tt = np.where(k > 0.78, 4, np.where(k > 0.5, 3, np.where(k > 0.22, 2, 1)))
            tone = np.where(m, tt, tone)
            arms |= m
        for t in range(1, 5):
            cv.put(arms & (tone == t), P.VOID[t])
        rim = disk & (rn > 39.8)
        cv.put(rim, P.VOID[2])
        cv.put(rim & (dy < -10 * K), P.VOID[3])
        P.puffs(cv, [(c, c, 6.2 * K)], P.VOID)
        P.disc_flash(cv, c, c, 3.2 * K, core=P.CREAM, rim=P.VOID[4])
        cv.put(P.outline_of(disk) & (cv.rgba[:, :, 3] == 0), P.VOID[0])
        for (a0, d, ph) in stars:
            a = a0 + rot * (20 * K / d)
            x, y = c + math.cos(a) * d, c + math.sin(a) * d
            k = (i - ph) % n
            if k == 0:
                P.star(cv, x, y, 2, core=P.WHITE, arm=P.CREAM)
            elif k < 4:
                cv.px(x, y, P.CREAM)
        frames.append(cv)
    save("cosmic_disk", frames, "loop", True, 12.0)


ALL = {
    "spray_fire": lambda: spray("spray_fire", P.FIRE, False),
    "spray_ice": lambda: spray("spray_ice", P.ICE, True),
    "spray_fire_big": lambda: spray("spray_fire_big", P.FIRE, False, S=2),
    "spray_ice_big": lambda: spray("spray_ice_big", P.ICE, True, S=2),
    "lava_pool": lava_pool,
    "spin_slash": spin_slash,
    "void_hole": void_hole,
    "seismic_ring": seismic_ring,
    "frost_ground": frost_ground,
    "radiation": radiation,
    "shuriken": shuriken,
    "wind_wave": wind_wave,
    "void_collapse": void_collapse,
    "arrow_rain": arrow_rain,
    "ballista": ballista,
    "zeus_tile": zeus_tile,
    "zeus_burst": lambda: electric_burst("zeus_burst", 40, 7, 17, 20.0),
    "magma_tile": magma_tile,
    "volt_tile": volt_tile,
    "trail_pop_fire": lambda: fire_burst("trail_pop_fire", 32, 7, 13, 20.0),
    "trail_pop_volt": lambda: electric_burst("trail_pop_volt", 32, 7, 13, 20.0),
    "execute_mark": execute_mark,
    "heal_orb": heal_orb,
    "mini_fw": mini_fw,
    "mini_pop": mini_pop,
    "bounce_spark": bounce_spark,
    "shuriken_hit": shuriken_hit,
    "charged_shock": lambda: shockwave("charged_shock", 176, 96, 82, 9, 20.0, P.CHARGE, puff_pal=P.DUST, sparks=(P.CHARGE[3], P.WHITE), seed=3, core=(P.FIRE, P.SMOKE_LIGHT)),
    "kinetic_blast": lambda: shockwave("kinetic_blast", 128, 72, 58, 8, 22.0, P.BOLT, sparks=(P.BOLT[3], P.WHITE), seed=5, core=(P.BOLT, P.DUST)),
    "air_ring": lambda: shockwave("air_ring", 208, 112, 99, 8, 22.0, P.WIND, swirl=True, seed=7),
    "cosmic_blast": lambda: shockwave("cosmic_blast", 160, 88, 74, 9, 20.0, P.VOID, puff_pal=P.SHADOW, stars=True, seed=9, core=(P.VOID, P.SHADOW)),
    "vortex": vortex,
    "mushroom": mushroom,
    "crystal_ice": lambda: crystal("crystal_ice", P.ICE),
    "crystal_arcane": lambda: crystal("crystal_arcane", P.VOID),
    "crystal_ice_shard": lambda: crystal_shard("crystal_ice_shard", P.ICE),
    "crystal_arcane_shard": lambda: crystal_shard("crystal_arcane_shard", P.VOID),
    "crystal_burst": crystal_burst,
    "saw": saw,
    "quake_tile": quake_tile,
    "rift_tile": rift_tile,
    "rift_tile_wide": lambda: rift_tile("rift_tile_wide", 36, 2.75),
    "rift_tile_cap": lambda: rift_tile(cap=True),
    "rift_tile_wide_cap": lambda: rift_tile("rift_tile_wide", 36, 2.75, cap=True),
    "zeus_tile_cap": lambda: zeus_tile(cap=True),
    "magma_tile_cap": lambda: magma_tile(cap=True),
    "volt_tile_cap": lambda: volt_tile(cap=True),
    "pillar": pillar,
    "crack_x": crack_x,
    "fault_blast": fault_blast,
    "shade_slash": shade_slash,
    "astral_orb": astral_orb,
    "cosmic_disk": cosmic_disk,
}

## x'te 16 px periyodik karolar: x'te kenar payi YOK (dizilimde karo genisligi = adim), yalniz y'de.
TILES = {"zeus_tile", "magma_tile", "volt_tile", "rift_tile", "rift_tile_wide",
         "zeus_tile_cap", "magma_tile_cap", "volt_tile_cap", "rift_tile_cap", "rift_tile_wide_cap"}

if __name__ == "__main__":
    names = sys.argv[1:] or list(ALL.keys())
    print("Efsun FX ->", os.path.relpath(OUT, ROOT))
    for nm in names:
        P.PAD[:] = [0, 12] if nm in TILES else [48, 48]
        ALL[nm]()
