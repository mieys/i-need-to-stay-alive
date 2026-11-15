"""BUYUCU KIZ "Arcane Patlama" (E1 evrimi) patlama efekti PROTOTIPLERI A-D (2026-11-11, oyuna bagli DEGIL).

Kullanici: "buyucu kizin arcane patlamasi yeteneginin patlama efektleri icin 4 yeni prototip hazirla, suankiler gorsel okunurluk
acisindan kotu".
Bugun her isabette IKI patlama ust uste: fx_arcane_impact lanet_burst (32 px = 29 dunya, alan 150 dunya capinda) + eski "Kadim
Patlama" pasifinin muhru fx_mage_passive_burst (1 px'lik noktali halkalar, altin yildiz, pembe sutunlar, kristal noktalari, dither
disk; 4 renk; halka 0,62 basik elips ama hasar DAIRE).
Hepsinde ayni kurallar: alan = gercek hasar dairesi (EVO_BUYUCU_ARCANE_BLAST_RADIUS; 75 dunya = 83 px, madde 563 sonrasi 52,5 = 58 px),
ilk karede gorunur (hasar o karede), lanet paleti HEX + krem cekirdek, ici dolu kutleler + 1 px koyu kontur, tek piksel / dither yok,
~0,6 sn (20 fps). Lanet gozu, ayak muhru ve lanet ipi AYNI kalir (temel yetenek); degisen yalniz patlama.

  A Sok Halkasi   : kalin tek halka merkezden alanin kenarina acilir, kenarda bir an durur, hilallere ayrilarak soner
  B Muhur Dairesi : butun alan ilk karede dolu muhur olarak yanar, icten oyularak runlu bir halkaya incelir + isik sutunu
  C Kiymik Yildizi: 8 lanet kristali merkezden firlar, alanin kenarina saplanip topraga gomulur (halka yok, alan 8 noktayla)
  D Lanet Alevi   : alanin kenarinda bir alev tacı yukselir (arka yari yaratiklarin altinda), merkezde alev patlamasi

Piksel = Buyucu sanat pikseli (BuyucuFx.PX 0,903 dunya). Capa (AX, AY) = isabet noktasi (yaratik konumu); zemin merkezi 8 px altta
(fx_arcane_impact BRAND_DROP - ayak hizasi). Katmanlar: front z 50 (yaratiklarin ustu), ground z 0 (sahne koku: haritanin ustu,
yaratiklarin alti). Cikti out/sheets/<kod>_<katman>.png + <kod>.json, onizleme out/sanat_onizleme.png.
Gercek oyun: arcane_patlama_run.ps1.
"""

import json
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", ".."))
import pixfx as P  # noqa: E402

OUT = os.path.join(HERE, "out")
SHEETS = os.path.join(OUT, "sheets")

WORLD_PX = 0.903
BLAST_WORLD = 52.5       # player.gd EVO_BUYUCU_ARCANE_BLAST_RADIUS (madde 563: 75 -> 52,5; onceki 3 tur 75 ile cizildi)
R = BLAST_WORLD / WORLD_PX  # hasar dairesi (sanat pikseli)
W, H = 188, 200
AX, AY = 94, 98          # isabet noktasi
GX, GY = 94, 106         # zemin merkezi (ayak hizasi)
FPS = 20
NF = 12
TAU = math.tau

HEX = [(46, 10, 50), (112, 28, 124), (182, 64, 200), (236, 140, 240), (255, 230, 250)]
CREAM = P.CREAM


def new():
    return P.Canvas(W, H)


def clamp01(x):
    return max(0.0, min(1.0, x))


# ====================================================================== ortak parcalar
def flash(cv, k, r0=9.0, r1=12.0, rays=True):
    """Merkez parlamasi (k 0..1): krem disk + acik kenar + 4 kalin isin (ilk iki kare)."""
    r = r0 + (r1 - r0) * k
    P.disc_flash(cv, AX, AY, r, core=CREAM, rim=HEX[4])
    if rays:
        L = r + 7.0 * (1.0 - 0.5 * k)
        for a in (0.0, math.pi / 2, math.pi, 1.5 * math.pi):
            P.thick_line(cv, AX + math.cos(a) * r * 0.6, AY + math.sin(a) * r * 0.6,
                         AX + math.cos(a) * L, AY + math.sin(a) * L, 2.2, HEX[4])
    P.thick_line(cv, AX, AY, AX, AY, 1.0, CREAM)


def core_puffs(cv, k, seed=0, n=6, base_r=4.2, spread=10.0):
    """Parlama sonrasi merkezde disari acilip hilale asinarak sonen kucuk lanet kumeleri (k 0..1)."""
    circles, cuts = [], []
    for i in range(n):
        a = TAU * i / n + 0.4 + seed
        d = 4.0 + spread * P.ease_out(k)
        r = base_r * (1.0 - 0.6 * k)
        x, y = AX + math.cos(a) * d, AY + math.sin(a) * d * 0.8 - 3.0 * k
        circles.append((x, y, r))
        cuts.append((x - math.cos(a) * r * 0.4 + r * 0.25, y - math.sin(a) * r * 0.4 - r * 0.25, r * (0.3 + 0.8 * k)))
    P.puffs(cv, circles, HEX, cut=cuts)


# ====================================================================== A Sok Halkasi
def a_frame(f):
    front, ground = new(), new()
    grow = [0.34, 0.64, 0.84, 0.95, 1.0]
    r = R * (grow[f] if f < len(grow) else 1.0)
    th = 7.0 if f < 4 else max(2.4, 7.0 - (f - 3) * 0.75)
    mult = None
    if f >= 7:
        mult = P.break_mult(ground, GX, GY, 1.0, clamp01((f - 6) / 5.0), 3.0, lobes=7)
    if f < NF - 1:
        P.ring_band(ground, GX, GY, r, th, HEX, mult=mult)
    if f <= 1:
        flash(front, f / 1.0)
    elif f <= 5:
        core_puffs(front, (f - 2) / 3.0, n=5, base_r=6.0, spread=8.0)
    return front, ground


# ====================================================================== B Muhur Dairesi
def rune_marks(cv, cx, cy, r_mid, band, rot, col, n=6):
    """Bandin ortasina oyulmus run isaretleri (2 px kalin T / ok bicimli, aciya gore doner)."""
    for i in range(n):
        a = rot + TAU * i / n
        ca, sa = math.cos(a), math.sin(a)
        tx, ty = -sa, ca  # teget
        h = band * 0.32
        x0, y0 = cx + ca * (r_mid - h), cy + sa * (r_mid - h)
        x1, y1 = cx + ca * (r_mid + h), cy + sa * (r_mid + h)
        P.thick_line(cv, x0, y0, x1, y1, 2.0, col)
        P.thick_line(cv, x1 - tx * 2.5, y1 - ty * 2.5, x1 + tx * 2.5, y1 + ty * 2.5, 2.0, col)


def b_frame(f):
    front, ground = new(), new()
    inner = [0.0, 0.5, 0.72, 0.82, 0.86, 0.86, 0.87, 0.88, 0.89, 0.9, 0.92, 0.95]
    ri = R * inner[f]
    band = R - ri
    if f < NF - 1:
        X, Y = ground.grid()
        d = np.hypot(X - GX, Y - GY)
        mult = 1.0
        if f >= 8:
            mult = P.break_mult(ground, GX, GY, 1.0, clamp01((f - 7) / 4.0), 1.3, lobes=6)
        thick = band * mult
        m = (d <= R) & (d >= R - thick) & (np.asarray(thick) > 0.6)
        if m.any():
            k = (d - (R - band)) / max(band, 0.5)  # 0 ic, 1 dis
            if f == 0:
                tone = np.where(d > R - 2.2, 4, np.where(d > R - 5.0, 3, 2))
            else:
                tone = np.where(d > R - 2.2, 4, np.where(k > 0.45, 3, np.where(k > 0.12, 2, 1)))
            for t in range(1, 5):
                ground.put(m & (tone == t), HEX[t])
            ground.put(P.outline_of(m) & ~ground.filled(), HEX[0])
            if 1 <= f <= 9 and band >= 7.0:
                rune_marks(ground, GX, GY, R - band * 0.48, band, 0.35 + 0.12 * f, HEX[1])
    # isik sutunu (muhrun ortasindan yukari)
    col_h = [30, 38, 32, 22, 10]
    col_w = [15, 12, 9, 6, 3]
    if f < len(col_h):
        h, w = col_h[f], col_w[f]
        m = np.zeros((front.h, front.w), dtype=bool)
        X, Y = front.grid()
        top = AY + 4 - h
        m = (np.abs(X - AX) <= w / 2.0) & (Y >= top) & (Y <= AY + 4)
        # tepe sivri
        m &= (Y - top) >= np.abs(X - AX) * 2.2
        m &= (AY + 4 - Y) >= np.abs(X - AX) * 0.35
        front.put(m, HEX[3])
        front.put(m & (np.abs(X - AX) <= max(0.6, w / 2.0 - 2.0)), HEX[4])
        front.put(m & (np.abs(X - AX) <= max(0.0, w / 2.0 - 4.5)), CREAM)
        front.put(P.outline_of(m) & ~front.filled(), HEX[1])
    return front, ground


# ====================================================================== C Kiymik Yildizi
def shard(cv, x, y, a, L, w, alpha_cut=0.0):
    """Radyal lanet kristali (uc disa): iki yuz (isikli / golgeli) + parlak uc + kontur."""
    ca, sa = math.cos(a), math.sin(a)
    tx, ty = -sa, ca
    tip = (x + ca * L * 0.55, y + sa * L * 0.55)
    tail = (x - ca * L * 0.45, y - sa * L * 0.45)
    lft = (x + tx * w * 0.5, y + ty * w * 0.5)
    rgt = (x - tx * w * 0.5, y - ty * w * 0.5)
    # isik sol ustten: hangi yuz isikli
    lit_left = (tx * P.LIGHT[0] + ty * P.LIGHT[1]) > 0
    faces = [([tip, lft, tail], 3 if lit_left else 1), ([tip, rgt, tail], 1 if lit_left else 3)]
    m = P.facets(cv, faces, HEX)
    cv.px(tip[0] - ca * 1.2, tip[1] - sa * 1.2, HEX[4])
    cv.px(x + ca * 0.5, y + sa * 0.5, HEX[4])
    return m


def c_frame(f):
    front, ground = new(), new()
    n = 8
    dist = [0.16, 0.5, 0.8, 0.97, 1.0]
    for i in range(n):
        a = TAU * i / n + 0.2
        ca, sa = math.cos(a), math.sin(a)
        d = R * (dist[f] if f < len(dist) else 1.0) - 5.0
        x, y = GX + ca * d, GY + sa * d
        cv = ground if sa < -0.05 else front
        if f <= 9:
            L = 19.0 if f < 4 else max(6.0, 19.0 - (f - 3) * 2.2)
            if 1 <= f <= 3:
                # kisa sivrilen iz (kristalin arkasinda, 2 -> 1 px)
                back = 9.0 + 3.0 * f
                for s_ in range(int(back)):
                    t = s_ / back
                    px_ = x - ca * (L * 0.45 + s_)
                    py_ = y - sa * (L * 0.45 + s_)
                    P.thick_line(cv, px_, py_, px_, py_, 2.4 * (1.0 - t) + 0.8, HEX[3] if t < 0.5 else HEX[2])
            ## saplanınca kuyruk tarafından kısalır (ucu yerinde = toprağa gömülür); kırıntı saçılmaz (gürültü)
            shard(cv, x + ca * (19.0 - L) * 0.55, y + sa * (19.0 - L) * 0.55, a, L, 8.0 * (L / 19.0) ** 0.5)
        # saplandigi yerde zemin cukuru
        if 3 <= f <= 9:
            ex, ey = GX + ca * (R - 3.0), GY + sa * (R - 3.0)
            m = P.ellipse_mask(ground, ex, ey, 3.2, 2.0)
            ground.put(m & ~ground.filled(), HEX[1])
            ground.put(P.outline_of(m) & ~ground.filled(), HEX[0])
    # merkez: elmas parlama + zeminde catlak yildiz
    if f <= 1:
        s = 10.0 - 3.0 * f
        pts = [(AX, AY - s), (AX + s * 0.75, AY), (AX, AY + s), (AX - s * 0.75, AY)]
        m = P.poly_mask(front, pts)
        front.put(m, HEX[4])
        front.put(P.erode(P.erode(m)), CREAM)
        front.put(P.outline_of(m) & ~front.filled(), HEX[2])
    if 2 <= f <= 4:
        core_puffs(front, (f - 2) / 2.0, n=4, base_r=5.0, spread=6.0)
    return front, ground


# ====================================================================== D Lanet Alevi
def tongue(cv, x, base, h, w, sway, pal):
    """Yukari sivrilen alev dili (isi golgesi: dis koyu, cekirdek krem)."""
    if h < 1.5:
        return None
    pts = [(x - w / 2.0, base), (x - w * 0.45 + sway * 0.3, base - h * 0.45), (x + sway, base - h),
           (x + w * 0.45 + sway * 0.5, base - h * 0.5), (x + w / 2.0, base)]
    m = P.poly_mask(cv, pts)
    P.heat_fill(cv, m, pal, levels=(1, 2, 3, 4))
    return m


def d_frame(f):
    front, ground = new(), new()
    # zemin halkasi (ince, alevlerin oturdugu cizgi)
    rr = [0.82, 0.95, 1.0]
    r = R * (rr[f] if f < len(rr) else 1.0)
    if f < NF - 1:
        mult = P.break_mult(ground, GX, GY, 1.0, clamp01((f - 7) / 4.0), 5.0, lobes=8) if f >= 8 else None
        P.ring_band(ground, GX, GY, r, 3.2, HEX, mult=mult)
    env = [0.0, 0.55, 1.0, 0.96, 0.86, 0.72, 0.58, 0.44, 0.3, 0.16, 0.06, 0.0]
    n = 20
    for i in range(n):
        a = TAU * i / n + 0.1
        ca, sa = math.cos(a), math.sin(a)
        lag = (i * 7) % 3 * 0.12
        e = env[f] if f < len(env) else 0.0
        if f >= 1:
            e = env[min(NF - 1, f)] * (1.0 - lag) if f <= 2 else env[min(NF - 1, f)]
        h = (15.0 + 6.0 * ((i * 5) % 4) / 3.0) * e
        x, y = GX + ca * r, GY + sa * r
        sway = math.sin(f * 1.3 + i * 1.7) * 1.5
        cv = ground if sa < -0.05 else front
        tongue(cv, x, y + 1.0, h, 8.5, sway, HEX)
    # merkez: parlama + alev patlamasi
    if f <= 1:
        flash(front, f, r0=8.0, r1=10.0, rays=False)
    cenv = [0.6, 1.0, 0.9, 0.7, 0.45, 0.2]
    if 1 <= f < len(cenv) + 1 and f - 1 < len(cenv):
        e = cenv[f - 1]
        for dx, hh in ((-8.0, 18.0), (0.0, 28.0), (8.0, 19.0)):
            tongue(front, AX + dx, AY + 7.0, hh * e, 11.0, math.sin(f + dx) * 1.2, HEX)
    return front, ground


# ====================================================================== A YUMUSAK varyantlari (2. tur)
## Kullanici (A secildi): "A guzel ama cok dikkat cekiyor gibi hissettirdi, saydamlik veya parlaklik yumusamasi v.s nasil olurdu?
## biraz daha sihir gibi gorunmesi lazim". A'yi "bagiran" seyler: 7 px kalin halka + beyaza yakin dis kenar + koyu kontur + krem parlama
## ve 4 isin. Varyantlar ayni zamanlama/olcu (alan yine 75 dunya, ilk karede gorunur), sonme ASINMA yerine yumusak solma
## (FADE: kare basina saydamlik sayfaya pisirilir). Koyu tonlar yari saydam yapilmaz (cimende camur - madde 516 dersi).
FADE = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.9, 0.75, 0.58, 0.4, 0.22, 0.0]
## [kontur, koyu, orta, acik, parlak] - HEX'in bir basamak kisigi (beyaza yakin ton yok)
HEX_SOFT = [(80, 26, 92), (130, 48, 150), (172, 84, 196), (210, 130, 230), (232, 178, 246)]
## toplamali (ADD) palet: renk = eklenen isik; koyu = zayif isik. YESIL kanal ~0: cimene (yesil) eklenince beyaza degil
## pembe-mora gider (ilk deneme (34,10,48)..(196,140,232) cimende bembeyaz halka oldu).
GLOW = [(0, 0, 0), (40, 0, 54), (82, 6, 108), (132, 16, 164), (186, 58, 214)]

RUNES = [
    ["..#..", ".###.", "#.#.#", "..#..", "..#.."],
    ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
    [".###.", "#...#", "#.#.#", "#...#", ".###."],
    ["#.#.#", ".###.", "..#..", ".###.", "#.#.#"],
]


def a_ring_r(f):
    grow = [0.34, 0.64, 0.84, 0.95, 1.0]
    return R * (grow[f] if f < len(grow) else 1.0)


def soft_core(cv, f, pal, r0=6.0):
    """Kucuk merkez isigi (isinsiz): 3 basamakli disk, 3 karede kuculur."""
    if f > 2:
        return
    r = r0 * (1.0 - 0.28 * f)
    for rr, col in ((r, pal[2]), (r * 0.66, pal[3]), (r * 0.33, pal[4])):
        X, Y = cv.grid()
        cv.put((X - AX) ** 2 + (Y - AY) ** 2 <= rr * rr, col)


def glyph(cv, x, y, g, col, edge):
    m = np.zeros((cv.h, cv.w), dtype=bool)
    for j, row in enumerate(g):
        for i, ch in enumerate(row):
            if ch == "#":
                yy, xx = cv.idx(x - 2 + i, y - 2 + j)
                if 0 <= xx < cv.w and 0 <= yy < cv.h:
                    m[yy, xx] = True
    cv.put(P.dilate(m) & ~m & ~cv.filled(), edge)
    cv.put(m, col)


def a1_frame(f):
    """A1 Saydam Halka: A'nin bicimi, isinsiz kucuk parlama, %70 saydam (pisirilmis), asinmadan solar. Koyu kontur ve koyu tonlar
    YOK: ilk denemede (A'nin tam paleti %60) mor + cimen yesili karisip GRI oldu - yalniz acik tonlar saydam."""
    front, ground = new(), new()
    th = 6.0 if f < 4 else max(3.0, 6.0 - (f - 3) * 0.5)
    P.ring_band(ground, GX, GY, a_ring_r(f), th, [HEX[2], HEX[2], HEX[3], HEX[3], HEX[4]], outline=False)
    soft_core(front, f, HEX, 7.0)
    return front, ground


def a2_frame(f):
    """A2 Kisik Isik: ince (4 -> 2 px) konturusuz halka, bir basamak kisik palet (beyaz yok), kucuk merkez isigi."""
    front, ground = new(), new()
    th = 4.0 if f < 4 else max(2.0, 4.0 - (f - 3) * 0.4)
    P.ring_band(ground, GX, GY, a_ring_r(f), th, HEX_SOFT, outline=False)
    soft_core(front, f, HEX_SOFT, 6.0)
    return front, ground


def a3_frame(f):
    """A3 Run Halkasi (sihirli): ince isik cizgisi + uzerinde 8 run (acilirken yerine oturur, sirayla soner) + halkadan yukselen
    4 kollu kivilcimlar; merkezde kucuk muhur."""
    front, ground = new(), new()
    r = a_ring_r(f)
    P.ring_band(ground, GX, GY, r, 2.2, [HEX_SOFT[0], HEX_SOFT[2], HEX_SOFT[2], HEX_SOFT[3], HEX_SOFT[4]], outline=False)
    n = 8
    for i in range(n):
        a = TAU * i / n + 0.35 + 0.06 * f  # yavasca doner
        if f >= 6 and (i * 3) % n < (f - 5) * 2:  # sirayla soner
            continue
        x, y = GX + math.cos(a) * r, GY + math.sin(a) * r
        cv = ground if math.sin(a) < -0.05 else front
        glyph(cv, x, y, RUNES[i % len(RUNES)], HEX[4] if f < 4 else HEX[3], HEX[2])
    # yukselen kivilcimlar (seyrek, 4 kollu)
    for i in range(6):
        a = TAU * i / 6 + 0.9
        k = (f - 2 - (i % 3)) / 5.0
        if 0.0 <= k <= 1.0:
            x = GX + math.cos(a) * R * 0.92
            y = GY + math.sin(a) * R * 0.92 - 16.0 * P.ease_out(k)
            P.star(front, x, y, 2 if k < 0.6 else 1, core=HEX[4], arm=HEX[3])
    # merkez muhru: kucuk halka + 4 centik
    if f <= 5:
        rr = 6.0 + 2.0 * min(f, 2)
        P.ring_band(ground, GX, GY, rr, 1.6, [HEX_SOFT[0], HEX_SOFT[2], HEX_SOFT[3], HEX_SOFT[3], HEX_SOFT[4]], outline=False)
        for q in range(4):
            a = q * math.pi / 2 + 0.2 * f
            ground.px(GX + math.cos(a) * (rr + 2), GY + math.sin(a) * (rr + 2), HEX[4])
    soft_core(front, f, HEX_SOFT, 5.0)
    return front, ground


def a4_frame(f):
    """A4 Isilti (TOPLAMALI): halka ve merkez isik olarak eklenir (kontursuz, zemin rengi icinden parlar), ust uste gelince guclenir;
    halkadan yavas yukselen 2x2 isik tozlari."""
    front, ground = new(), new()
    r = a_ring_r(f)
    th = 7.0 if f < 4 else max(3.0, 7.0 - (f - 3) * 0.6)
    P.ring_band(ground, GX, GY, r, th, GLOW, outline=False, lit_outer=False)
    if f <= 3:
        X, Y = front.grid()
        d2 = (X - AX) ** 2 + (Y - AY) ** 2
        s = 1.0 - 0.22 * f
        for rr, col in ((13 * s, GLOW[1]), (9 * s, GLOW[2]), (5 * s, GLOW[3]), (2.5 * s, GLOW[4])):
            front.put(d2 <= rr * rr, col)
    for i in range(8):
        a = TAU * i / 8 + 0.5
        k = (f - 2 - (i % 4) * 0.5) / 6.0
        if 0.0 <= k <= 1.0:
            x = GX + math.cos(a) * r
            y = GY + math.sin(a) * r - 18.0 * k
            col = GLOW[4] if k < 0.4 else GLOW[3]
            for dx in (0, 1):
                for dy in (0, 1):
                    front.px(x + dx, y + dy, col)
    return front, ground


# ====================================================================== M BUYU PATLAMASI (3. tur)
## Kullanici: "dumduz bir halka buyuyormus gibi degil de hafif sihir patlamasi oluyormus gibi gorunen yeni bir prototip; buna isinamadim
## hissiyat olarak". Halka YOK: merkezde 4 kollu parilti acilir (sihir "tink"i), isik tozu / bulut / yaprak alanin kenarina kadar
## acilir - alan bunlarin durdugu yerden okunur. Hepsi TOPLAMALI (GLOW, yesil kanal ~0). GENIS SOLUK DOLGU YOK: ilk denemede
## alan boyu soluk mor isik (GLOW[1]/[2]) yesil cimene eklenince GRI pus oldu (mor + yesil = gri) - yalniz parlak parcalar (>= GLOW[3]).
GLOWB = [(0, 0, 0), (120, 10, 150), (150, 30, 180), (186, 58, 214), (226, 130, 240)]  ## bulut icin parlak rampa (koyu ton cimende gri)
FADE_M = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.85, 0.68, 0.5, 0.3, 0.0]


def flare(cv, x, y, L, w, pal, diag=True):
    """4 kollu sihir parlamasi: yatay + dikey ince elmas (uclar sivri), ic ton + cekirdek; buyukken capraz kisa kollar."""
    if L < 1.5:
        return
    def diamonds(l_, w_):
        return [[(x - l_, y), (x, y - w_), (x + l_, y), (x, y + w_)], [(x, y - l_), (x + w_, y), (x, y + l_), (x - w_, y)]]
    m = np.zeros((cv.h, cv.w), dtype=bool)
    for pts in diamonds(L, w):
        m |= P.poly_mask(cv, pts)
    if diag and L > 10:
        l2, w2 = L * 0.42, w * 0.8
        for pts in ([(x - l2 * 0.7, y - l2 * 0.7), (x + w2 * 0.7, y - w2 * 0.7), (x + l2 * 0.7, y + l2 * 0.7), (x - w2 * 0.7, y + w2 * 0.7)],
                    [(x + l2 * 0.7, y - l2 * 0.7), (x + w2 * 0.7, y + w2 * 0.7), (x - l2 * 0.7, y + l2 * 0.7), (x - w2 * 0.7, y - w2 * 0.7)]):
            m |= P.poly_mask(cv, pts)
    cv.put(m, pal[2])
    inner = np.zeros_like(m)
    for pts in diamonds(L * 0.6, w * 0.6):
        inner |= P.poly_mask(cv, pts)
    cv.put(inner, pal[3])
    X, Y = cv.grid()
    cv.put((X - x) ** 2 + (Y - y) ** 2 <= (w * 0.75) ** 2, pal[4])


def twinkle(cv, x, y, s, pal):
    """Kucuk 4 kollu yildiz tozu (s 1..3)."""
    if s <= 0:
        return
    P.star(cv, x, y, s, core=pal[4], arm=pal[3] if s > 1 else pal[4])


def glow_disc(cv, cx, cy, r, tones):
    """Toplamali yumusak isik lekesi: ic ice diskler (disari dogru zayif). tones: [(yaricap orani, renk)] buyukten kucuge."""
    X, Y = cv.grid()
    d2 = (X - cx) ** 2 + (Y - cy) ** 2
    for k, col in tones:
        cv.put(d2 <= (r * k) ** 2, col)


def m1_frame(f):
    """M1 Yildiz Tozu: merkezde buyuk 8 kollu parilti; 16 isik tozu hafif sarmal cizerek ucup alanin kenarina konar (yarisi biraz
    iceride), konunca zeminde kisa yatay pirilti, sonra pirildayip yukselir. Halka / dolgu yok."""
    front, ground = new(), new()
    fl = [(14, 3.2), (19, 3.6), (12, 2.8), (7, 2.0), (3, 1.4)]
    if f < len(fl):
        flare(front, AX, AY, fl[f][0], fl[f][1], GLOW)
    n = 16
    prog = [0.0, 0.12, 0.42, 0.7, 0.9, 1.0]
    for i in range(n):
        a = TAU * i / n + 0.15
        if f < 1:
            continue
        p = prog[f] if f < len(prog) else 1.0
        ang = a + 0.45 * (1.0 - p)  # sarmal: ici donuk baslar
        rr = R * (0.9 if i % 2 else 1.0)
        sx, sy = AX, AY
        ex, ey = GX + math.cos(ang) * rr, GY + math.sin(ang) * rr
        x, y = sx + (ex - sx) * P.ease_out(p), sy + (ey - sy) * P.ease_out(p)
        rise = max(0, f - 5) * 2.2
        s_ = 2 if f < 5 else (2 if (f + i) % 3 else 3)
        if f >= 9:
            s_ = 1
        twinkle(front, x, y - rise, s_, GLOW)
        if 2 <= f <= 4:  # kisa iz: arkada bir sonuk toz
            px_ = sx + (ex - sx) * P.ease_out(max(0.0, p - 0.12))
            py_ = sy + (ey - sy) * P.ease_out(max(0.0, p - 0.12))
            twinkle(front, px_, py_, 1, [GLOW[0], GLOW[3], GLOW[3], GLOW[3], GLOW[3]])
        if 5 <= f <= 7:  # kondugu yerde zeminde kisa yatay pirilti
            w = [3.0, 2.0, 1.0][f - 5]
            P.thick_line(ground, ex - w, ey + 1, ex + w, ey + 1, 1.0, GLOW[3])
    return front, ground


def m2_frame(f):
    """M2 Buyu Bulutu: merkezde parilti + kucuk isik bulutu kumeleri disari acilip (alan yarisina) hilale asinarak dagilir; bulutun
    icinden 10 kristal kivilcim alanin kenarina firlar, orada pirildayip soner."""
    front, ground = new(), new()
    if f <= 2:
        flare(front, AX, AY, [12, 15, 8][f], [3.0, 3.2, 2.2][f], GLOW)
    if 1 <= f <= 8:
        k = (f - 1) / 7.0
        circles, cuts = [], []
        for i in range(7):
            a = TAU * i / 7 + 0.3
            d = R * (0.06 + 0.34 * P.ease_out(k))  # ust uste binen kumeler = tek bulut (ayri toplar "uzum" gibi durdu)
            r = 13.0 * (1.0 - 0.55 * k)
            x, y = AX + math.cos(a) * d, AY + 6.0 + math.sin(a) * d * 0.85 - 6.0 * k
            circles.append((x, y, r))
            if k > 0.3:
                cuts.append((x - math.cos(a) * r * 0.3 + r * 0.2, y - math.sin(a) * r * 0.3 - r * 0.25, r * (k - 0.1) * 1.1))
        if k < 0.4:
            circles.append((AX, AY + 4.0, 12.0 * (1.0 - k)))
        P.puffs(front, circles, GLOWB, cut=cuts or None, outline=False)
    n = 10
    for i in range(n):
        a = TAU * i / n + 0.55
        if f < 1:
            continue
        p = min(1.0, (f - 1) / 3.0)
        x = AX + (GX + math.cos(a) * R * 0.96 - AX) * P.ease_out(p)
        y = AY + (GY + math.sin(a) * R * 0.96 - AY) * P.ease_out(p)
        if f <= 4:
            # kucuk elmas kivilcim (ucus yonunde uzun)
            ca, sa = math.cos(a), math.sin(a)
            L = 5.0
            pts = [(x + ca * L, y + sa * L), (x - sa * 1.6, y + ca * 1.6), (x - ca * L, y - sa * L), (x + sa * 1.6, y - ca * 1.6)]
            m = P.poly_mask(front, pts)
            front.put(m, GLOW[3])
            front.px(x + ca * 2, y + sa * 2, GLOW[4])
        else:
            twinkle(front, x, y - (f - 4) * 1.5, 2 if (f + i) % 2 else 1, GLOW)
    return front, ground


def m3_frame(f):
    """M3 Buyu Cicegi: merkezden 6 isik yapragi (cizgi) acilir, uclari alanin kenarina degip uc pariltisi verir, yapraklar yavasca
    doner ve iceri kapanarak soner; merkezde parilti."""
    front, ground = new(), new()
    open_ = [0.3, 0.62, 0.86, 0.97, 1.0, 1.0, 1.0, 0.94, 0.8, 0.6, 0.38, 0.15]
    L = R * open_[f]
    rot = 0.25 + 0.05 * f
    X, Y = ground.grid()
    for i in range(6):
        a = rot + TAU * i / 6
        ca, sa = math.cos(a), math.sin(a)
        # yaprak: merkezden uca mercek bicimi - yalniz 2 px parlak kenar cizgisi (dolgu cimende gri olur)
        u = (X - GX) * ca + (Y - GY) * sa
        v = -(X - GX) * sa + (Y - GY) * ca
        t = u / max(L, 1.0)
        half = 0.16 * L * np.sqrt(np.clip(t * (1.0 - t), 0.0, 1.0)) * 2.0
        m = (t >= 0.0) & (t <= 1.0) & (np.abs(v) <= half)
        rim = m & ~P.erode(P.erode(m))
        ground.put(rim, GLOW[3])
        ground.put(m & ~P.erode(m) & (t > 0.35) & (t < 0.8), GLOW[4])
        if 2 <= f <= 8:
            twinkle(front, GX + ca * L, GY + sa * L - 1.0, 3 if f in (3, 4) else 2, GLOW)
    if f <= 3:
        flare(front, AX, AY, [13, 17, 11, 6][f], [3.0, 3.4, 2.6, 1.8][f], GLOW)
    elif f <= 7:
        glow_disc(front, AX, AY + 2, 5.0 - (f - 4), [(1.0, GLOW[2]), (0.5, GLOW[3])])
    return front, ground


# ====================================================================== kaydet
CODES = {"A": a_frame, "B": b_frame, "C": c_frame, "D": d_frame,
         "A1": a1_frame, "A2": a2_frame, "A3": a3_frame, "A4": a4_frame,
         "M1": m1_frame, "M2": m2_frame, "M3": m3_frame}
LABEL = {"A": "A Sok Halkasi", "B": "B Muhur Dairesi", "C": "C Kiymik Yildizi", "D": "D Lanet Alevi",
         "A1": "A1 Saydam Halka", "A2": "A2 Kisik Isik", "A3": "A3 Run Halkasi", "A4": "A4 Isilti (toplamali)",
         "M1": "M1 Yildiz Tozu", "M2": "M2 Buyu Bulutu", "M3": "M3 Buyu Cicegi"}
## kod -> (pisirilmis butun saydamlik, kare solmasi, karisim)
STYLE = {"A1": (0.7, FADE, "mix"), "A2": (0.85, FADE, "mix"), "A3": (0.9, FADE, "mix"), "A4": (1.0, FADE, "add"),
         "M1": (1.0, FADE_M, "add"), "M2": (1.0, FADE_M, "add"), "M3": (1.0, FADE_M, "add")}


def _bake_alpha(img, k):
    if k >= 0.999:
        return img
    a = np.array(img)
    a[:, :, 3] = (a[:, :, 3].astype(np.float32) * k).round().astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def render(code):
    fn = CODES[code]
    alpha, fade, blend = STYLE.get(code, (1.0, None, "mix"))
    fronts, grounds = [], []
    for f in range(NF):
        fr, gr = fn(f)
        k = alpha * (fade[f] if fade else 1.0)
        fronts.append(_bake_alpha(fr.image(), k))
        grounds.append(_bake_alpha(gr.image(), k))
    meta = {"w": W, "h": H, "ax": AX, "ay": AY, "fps": FPS, "frames": NF, "world_px": WORLD_PX, "layers": ["ground", "front"],
            "blend": blend, "blast_world": BLAST_WORLD}
    for layer, imgs in (("front", fronts), ("ground", grounds)):
        strip = Image.new("RGBA", (W * NF, H), (0, 0, 0, 0))
        for i, im in enumerate(imgs):
            strip.paste(im, (i * W, 0))
        strip.save(os.path.join(SHEETS, "%s_%s.png" % (code, layer)))
    with open(os.path.join(SHEETS, "%s.json" % code), "w", encoding="utf-8") as fh:
        json.dump(meta, fh)
    return fronts, grounds


def _add(cell, layer):
    """Toplamali onizleme: renk x alfa zemine eklenir (Godot BLEND_MODE_ADD)."""
    c = np.array(cell).astype(np.float32)
    l_ = np.array(layer).astype(np.float32)
    c[:, :, :3] = np.minimum(255.0, c[:, :, :3] + l_[:, :, :3] * (l_[:, :, 3:4] / 255.0))
    return Image.fromarray(c.astype(np.uint8), "RGBA")


def preview(all_frames, name):
    sc = 2
    bg = (96, 140, 72)
    sheet = Image.new("RGB", (W * NF * sc // 2, H * len(all_frames) * sc // 2), bg)
    for r, (code, (fronts, grounds)) in enumerate(all_frames.items()):
        add = STYLE.get(code, (1.0, None, "mix"))[2] == "add"
        for f in range(NF):
            cell = Image.new("RGBA", (W, H), bg + (255,))
            for lay in (grounds[f], fronts[f]):
                if add:
                    cell = _add(cell, lay)
                else:
                    cell.alpha_composite(lay)
            cell = cell.resize((W * sc // 2, H * sc // 2), Image.NEAREST)
            sheet.paste(cell.convert("RGB"), (f * W * sc // 2, r * H * sc // 2))
    sheet.save(os.path.join(OUT, name))


def main():
    """Argumansiz: A-D (1. tur) -> sanat_onizleme.png; "yumusak": A + A1-A4 (2. tur) -> sanat_onizleme_yumusak.png; ya da kod listesi."""
    os.makedirs(SHEETS, exist_ok=True)
    args = sys.argv[1:]
    name = "sanat_onizleme.png"
    if args == ["yumusak"]:
        only, name = ["A", "A1", "A2", "A3", "A4"], "sanat_onizleme_yumusak.png"
    elif args == ["buyu"]:
        only, name = ["M1", "M2", "M3"], "sanat_onizleme_buyu.png"
    elif args == ["hepsi"]:
        only, name = list(CODES), "sanat_onizleme_hepsi.png"
    else:
        only = args or ["A", "B", "C", "D"]
        if args:
            name = "sanat_onizleme_%s.png" % "_".join(args)
    done = {}
    for code in only:
        done[code] = render(code)
        print("tamam", code)
    preview(done, name)


if __name__ == "__main__":
    main()
