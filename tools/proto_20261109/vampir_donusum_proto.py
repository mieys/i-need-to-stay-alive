"""VAMPIR COCUK yarasa donusumu efekt PROTOTIPLERI A-D (2026-11-09, oyuna bagli DEGIL).

Kullanici: "vampir cocugun yarasaya donusup geri donunceki partikul efektini yeniden tasarlar misin, suanki kalitesiz".
Bugunku "puff" (scripts/vampir_fx.gd): 30 rastgele kare piksel (2-4 x 1,212 dunya = karakter pikselinden 3-6 kat iri) 80 birime
kadar sacilir, giris ve cikis ayni. Oyunda sprite donusum ANINDA degisir (ayni karede puff dogar) -> her prototip ilk karede
govdeyi ORTER, sonra acilir.

  A Yarasa Surusu : duman bulutu + oyunun kendi mini yarasalari (mini_bat_1..3) disari sacilir / donuste iceri sarmal doner
  B Pelerin       : kirmizi gozlu kapali pelerin kanat gibi acilip yirtilir / donuste perde gibi yere duser
  C Kizil Girdap  : kizil hilaller govdeyi sarip donerek yukselir (arka yarisi karakterin arkasinda) / donuste yere iner, halka olur
  D Golge Sutunu  : yerde golge havuzu + yukselen kara alev dilleri / donuste havuza cekilir

Dil (feedback: pixfx): ICI DOLU kutleler, 5 tonlu rampa + 1 px koyu kontur, sonme hilale asinma; sacilan tek piksel / dither yok.
Piksel = Vampir karakter pikseli (2,09797 x 0,8075 x 0,5 = 0,847 dunya). Capa (AX, AY) = oyunun puff noktasi (oyuncu + (0,-6) dunya).
Cikti out/vampir_donusum/sheets/<kod>_<faz>_<katman>.png + <kod>_<faz>.json (faz in/out, katman front z 20 / ground z 0),
onizleme out/vampir_donusum/sanat_onizleme.png. Gercek oyun: vampir_donusum_run.ps1.
"""

import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import pixfx as P  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(HERE, "out", "vampir_donusum")
SHEETS = os.path.join(OUT, "sheets")

WORLD_PX = 0.847
W = H = 136
AX, AY = 68, 60          # puff noktasi
CX, CY = 68, 66          # govde ortasi (insan capaya gore y -10..+24 px)
GX, GY = 68, 84          # ayak cizgisi
FPS = 24
NF_IN = 16
NF_OUT = 14
TAU = math.tau

# ---- paletler [kontur, koyu, orta, acik, parlak] - yarasa sayfasindan
FUR = [(7, 3, 10), (28, 13, 22), (44, 26, 50), (66, 44, 74), (98, 72, 110)]
SMK = [(14, 6, 18), (38, 20, 44), (62, 38, 70), (94, 66, 106), (134, 106, 146)]
WING = [(51, 9, 20), (92, 18, 35), (134, 25, 45), (184, 57, 74), (236, 140, 150)]
CRIM = [(51, 9, 20), (120, 20, 36), (184, 40, 58), (236, 92, 100), (255, 198, 196)]
EYE = (255, 48, 48)
PINK = (255, 214, 214)

MINI = [np.array(Image.open(os.path.join(ROOT, "assets", "characters", "vampir", "mini_bat_%d.png" % i)).convert("RGBA"))
        for i in (1, 2, 3)]


def clamp01(x):
    return max(0.0, min(1.0, x))


def ease_out(t):
    return 1.0 - (1.0 - clamp01(t)) ** 2


def ease_in(t):
    return clamp01(t) ** 2


def band(a):
    """Saydamlik 3 basamak (duz bantlar, dither yok)."""
    if a > 0.8:
        return 1.0
    if a > 0.45:
        return 0.66
    if a > 0.12:
        return 0.33
    return 0.0


def new():
    return P.Canvas(W, H)


def over(dst, src, alpha=1.0):
    """src tuvalini dst ustune alfa ile bindirir (alfa bantli)."""
    a = band(alpha)
    if a <= 0.0:
        return
    m = src.rgba[:, :, 3] > 0
    if a >= 1.0:
        dst.rgba[m] = src.rgba[m]
        return
    d = dst.rgba[m].astype(float)
    s = src.rgba[m].astype(float)
    da = d[:, 3:4] / 255.0
    col = s[:, :3] * a + d[:, :3] * (1.0 - a) * da
    out_a = a + da[:, 0] * (1.0 - a)
    col = col / np.maximum(out_a[:, None], 1e-6)
    res = np.zeros_like(d)
    res[:, :3] = col
    res[:, 3] = out_a * 255.0
    dst.rgba[m] = np.clip(np.round(res), 0, 255).astype(np.uint8)


def sprite(cv, arr, x, y, alpha=1.0):
    """Oyunun mini yarasasi 1:1 (merkezi x, y)."""
    tmp = new()
    h, w = arr.shape[:2]
    y0, x0 = cv.idx(x - w / 2.0, y - h / 2.0)
    for yy in range(h):
        for xx in range(w):
            if arr[yy, xx, 3] > 0 and 0 <= y0 + yy < H and 0 <= x0 + xx < W:
                tmp.rgba[y0 + yy, x0 + xx] = arr[yy, xx]
    over(cv, tmp, alpha)


def smoke(cv, items, cool, pal=SMK, seed=0, core=None):
    """Duman kumesi: items [(x, y, r)], cool 0..1 hilale asinma (sag ustten yenir). core: ilk karelerde ic parlama."""
    circles, cuts = [], []
    for k, (x, y, r) in enumerate(items):
        if r < 0.8:
            continue
        circles.append((x, y, r))
        if cool > 0.0:
            ang = -0.8 + 0.5 * math.sin(seed + k * 1.7)
            cuts.append((x + math.cos(ang) * r * 0.5, y + math.sin(ang) * r * 0.5, r * (0.15 + 0.95 * cool)))
    if not circles:
        return None
    m = P.puffs(cv, circles, pal, cut=cuts or None)
    if core is not None and m.any():
        cx, cy, r, col = core
        X, Y = cv.grid()
        inner = m & P.erode(P.erode(m)) & (((X - cx) / r) ** 2 + ((Y - cy) / (r * 1.4)) ** 2 <= 1.0)
        cv.put(inner, col)
    return m


# ====================================================================== A - Yarasa Surusu
## Oyunun onayli duman dili (pixfx.burst = Cadi binis dumani): parlama -> dolu bulutlar -> halkada hilallere ayrilma; sarap
## moru sicak palet -> mor duman, parlama krem yerine pembe. Ustune oyunun kendi mini yarasalari (R'deki yarasalar) 1:1.
HOT = [(26, 6, 22), (70, 14, 40), (112, 24, 58), (160, 44, 82), (214, 112, 140)]
NF_A_IN = 20
A_FLY = 11   ## yarasa ucus karesi, sonra 4 karelik kucuk duman pufu
A_POOF = 4
A_BATS_IN = [(-150, 50, 0.45, 1), (-112, 52, -0.35, 1), (-74, 50, 0.3, 2), (-36, 48, -0.4, 2), (-2, 44, 0.35, 3), (196, 42, -0.3, 3)]
A_BATS_OUT = [(-150, 0), (-35, 1), (35, 2), (150, 0)]


def burst_vamp(cv, R, t, seed, squash, cy=None):
    old = P.CREAM
    P.CREAM = PINK
    try:
        P.burst(cv, CX, CY + 1 if cy is None else cy, R, t, HOT, SMK, seed, n_puffs=7, squash=squash, shards=False)
    finally:
        P.CREAM = old


def a_bat_pos(k, i):
    ang, dist, curl, start = A_BATS_IN[k]
    age = i - start
    u = clamp01(age / A_FLY)
    a = math.radians(ang) + curl * u
    d = 7 + dist * ease_out(u)
    x = CX + math.cos(a) * d
    y = CY - 2 + math.sin(a) * d * 0.8 - 7 * u
    return x, y, age


def mini_poof(cv, x, y, k):
    """Yarasanin sonu: kucuk mor duman pufu (k 0..1), saydamlik yok - hilale asinir."""
    P.burst(cv, x, y, 9, 0.3 + 0.7 * k, SMK, SMK, 11, n_puffs=5, squash=0.9, shards=False)


def a_in(i):
    t = 0.05 + 0.95 * min(1.0, i / 15.0)
    f = new()
    ## yeni cikan yarasa (ilk karesi) dumanin ALTINDA - icinden cikiyor gibi
    for k in range(len(A_BATS_IN)):
        x, y, age = a_bat_pos(k, i)
        if age == 0:
            sprite(f, MINI[(i + k) % 3], x, y)
    if i <= 15:
        burst_vamp(f, 25, t, 4, 1.2)
    for k in range(len(A_BATS_IN)):
        x, y, age = a_bat_pos(k, i)
        if 0 < age <= A_FLY:
            sprite(f, MINI[(i + k) % 3], x, y)
        elif A_FLY < age <= A_FLY + A_POOF:
            mini_poof(f, x, y, (age - A_FLY - 1) / (A_POOF - 1))
    return f, None


A_ARRIVE = [6, 7, 8, 9]


def a_out(i):
    t = 0.05 + 0.95 * i / (NF_OUT - 1)
    f = new()
    burst_vamp(f, 22, min(1.0, t * 1.1), 6, 1.2, cy=CY + 3)
    for k, (ang, ph) in enumerate(A_BATS_OUT):
        arr = A_ARRIVE[k]
        u = clamp01(i / arr)
        a = math.radians(ang) + 3.6 * ease_out(u)
        d = 25 * (1.0 - ease_in(u)) + 5
        x = CX + math.cos(a) * d
        y = CY + 2 + math.sin(a) * d * 0.6 + 4 * u
        if i < arr:
            sprite(f, MINI[(i + ph) % 3], x, y)
        elif i < arr + A_POOF:
            mini_poof(f, x, y, (i - arr) / (A_POOF - 1))
    return f, None


# ====================================================================== B - Pelerin
## Siyah pelerin, kirmizi astar: kapali koza (yaka arasindan iki kirmizi goz) kanat gibi acilir, astar = yarasa kanadi zari;
## acik kanatlar oyuklarindan yirtilip yukari suzulur, zar parcalari duser. Donus: kanatlar kapanir, koza yere cokup birikinti olur.
def _wing_poly(side, open_k, L, rt, rb):
    a = math.radians(98 + (-20 - 98) * open_k)
    dx, dy = math.cos(a) * side, math.sin(a)
    tip = (rt[0] + dx * L, rt[1] + dy * L)
    tx, ty = rb[0] - tip[0], rb[1] - tip[1]
    seg = math.hypot(tx, ty) or 1.0
    nx, ny = -ty / seg, tx / seg
    mx, my = (tip[0] + rb[0]) / 2 - rt[0], (tip[1] + rb[1]) / 2 - rt[1]
    if nx * mx + ny * my < 0:
        nx, ny = -nx, -ny
    fing = [tip,
            (tip[0] + tx * 0.36 + nx * 2.2, tip[1] + ty * 0.36 + ny * 2.2),
            (tip[0] + tx * 0.7 + nx * 1.6, tip[1] + ty * 0.7 + ny * 1.6),
            rb]
    pts = []
    lx, ly = tip[0] - rt[0], tip[1] - rt[1]
    ll = math.hypot(lx, ly) or 1.0
    px_, py_ = -ly / ll, lx / ll
    if px_ * (-nx) + py_ * (-ny) < 0:
        px_, py_ = -px_, -py_
    for q in range(6):
        u = q / 5
        b = math.sin(math.pi * u) * L * 0.07
        pts.append((rt[0] + lx * u + px_ * b, rt[1] + ly * u + py_ * b))
    scallops = []
    for s in range(3):
        p0, p1 = fing[s], fing[s + 1]
        sl = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        for q in range(1, 6):
            u = q / 6
            dep = math.sin(math.pi * u) * sl * 0.22
            pts.append((p0[0] + (p1[0] - p0[0]) * u - nx * dep, p0[1] + (p1[1] - p0[1]) * u - ny * dep))
        scallops.append(((p0[0] + p1[0]) / 2 + nx * sl * 0.1, (p0[1] + p1[1]) / 2 + ny * sl * 0.1, sl))
        pts.append(p1)
    return pts, tip, fing, scallops


def b_wing(cv, side, open_k, L, rt, rb, erode_k=0.0, alpha=1.0):
    pts, tip, fing, scallops = _wing_poly(side, open_k, L, rt, rb)
    tmp = new()
    m = P.poly_mask(tmp, pts)
    X, Y = tmp.grid()
    if erode_k > 0.0:
        for (sx, sy, sl) in scallops:
            r = sl * 0.95 * erode_k
            m &= (X - sx) ** 2 + (Y - sy) ** 2 > r * r
        r = L * 0.9 * max(0.0, erode_k - 0.45)
        m &= (X - tip[0]) ** 2 + (Y - tip[1]) ** 2 > r * r
    if not m.any():
        return
    lx, ly = tip[0] - rt[0], tip[1] - rt[1]
    ll = math.hypot(lx, ly) or 1.0
    dist_le = np.abs((X - rt[0]) * ly - (Y - rt[1]) * lx) / ll
    tmp.put(m, WING[2])
    tmp.put(m & (dist_le < 2.2), WING[3])
    bones = np.zeros_like(m)
    for fp in fing[1:3]:
        bx, by = fp[0] - rt[0], fp[1] - rt[1]
        bl = math.hypot(bx, by) or 1.0
        tt = np.clip(((X - rt[0]) * bx + (Y - rt[1]) * by) / (bl * bl), 0, 0.92)
        bones |= np.hypot(X - (rt[0] + tt * bx), Y - (rt[1] + tt * by)) <= 0.55
    tmp.put(m & bones, WING[1])
    tt = np.clip(((X - rt[0]) * lx + (Y - rt[1]) * ly) / (ll * ll), 0, 1)
    edge = np.hypot(X - (rt[0] + tt * lx), Y - (rt[1] + tt * ly)) <= 1.0
    tmp.put(m & edge, FUR[2])
    tmp.put(P.outline_of(m) & ~tmp.filled(), FUR[0])
    over(cv, tmp, alpha)


def dilate_x(mask):
    o = mask.copy()
    o[:, 1:] |= mask[:, :-1]
    o[:, :-1] |= mask[:, 1:]
    return o


def b_cocoon(cv, cyc=None, rx=12.0, ry=19.5, eyes=True):
    """Kapali pelerin: siyah kumas (sol ustten isik), ortada kirmizi astar yarigi, sivri yaka (ici kirmizi), yarasa kanadi
    oyuklu etek. cyc/rx/ry: elips merkezi + yaricaplar (cokerken etek yerde kalir)."""
    cyc = CY + 2 if cyc is None else cyc
    tmp = new()
    X, Y = tmp.grid()
    v01 = np.clip((Y - (cyc - ry)) / (2.0 * ry), 0.0, 1.0)
    rxy = rx * (0.74 + 0.3 * v01)
    m = ((X - CX) / rxy) ** 2 + ((Y - cyc) / ry) ** 2 <= 1.0
    collar = np.zeros_like(m)
    if ry > 14:
        top = cyc - ry
        collar |= P.poly_mask(tmp, [(CX - rx * 1.12, top + 1), (CX - 3.0, top + 6), (CX - rx * 0.7, top + 11)])
        collar |= P.poly_mask(tmp, [(CX + rx * 1.12, top + 1), (CX + 3.0, top + 6), (CX + rx * 0.7, top + 11)])
    if ry > 10:
        for k in range(-2, 3):
            m &= (X - (CX + k * rx / 2.0)) ** 2 + (Y - (cyc + ry + 2.6)) ** 2 > 3.4 ** 2
    allm = m | collar
    if not allm.any():
        return allm
    nx_ = (X - CX) / rx
    ny_ = (Y - cyc) / ry
    s = nx_ * P.LIGHT[0] + ny_ * P.LIGHT[1]
    tone = np.where(s > 0.45, 3, np.where(s > -0.2, 2, 1))
    for t in (1, 2, 3):
        tmp.put(m & (tone == t), FUR[t])
    # kumas kivrimlari
    for fx in (-rx * 0.45, rx * 0.5):
        tmp.put(m & (np.abs(X - (CX + fx)) < 0.5) & (Y > cyc - ry * 0.3), FUR[1])
    # on yarik: kirmizi astar
    sw = 0.6 + 2.6 * np.clip((Y - (cyc + ry * 0.2)) / (ry * 0.8), 0.0, 1.0)
    slit = m & (np.abs(X - CX) < sw) & (Y > cyc - ry * 0.55)
    tmp.put(slit, WING[2])
    tmp.put(slit & (np.abs(X - (CX - sw + 0.5)) < 0.6), WING[3])
    tmp.put(m & ~slit & dilate_x(slit) & (X > CX), FUR[0])
    # yaka: ic yuzu kirmizi
    tmp.put(collar & ~m, WING[2])
    tmp.put(collar & ~m & ~P.erode(collar), WING[3])
    tmp.put(P.outline_of(allm) & ~tmp.filled(), FUR[0])
    if eyes and ry > 14:
        for ex in (-2, 2):
            tmp.px(CX + ex, cyc - ry + 8, EYE)
    over(cv, tmp)
    return allm


B_SHREDS = [(-30, -4, -0.6), (-18, 2, 0.4), (-36, 6, 0.2), (30, -3, 0.5), (19, 3, -0.4), (37, 7, -0.2)]


def b_shred(cv, x, y, rot, s=1.0, alpha=1.0):
    pts = []
    c, sn = math.cos(rot), math.sin(rot)
    for (px_, py_) in ((-2.6, -1.2), (2.6, -0.6), (0.6, 2.4), (-1.0, 1.0)):
        pts.append((x + (px_ * c - py_ * sn) * s, y + (px_ * sn + py_ * c) * s))
    tmp = new()
    m = P.poly_mask(tmp, pts)
    if not m.any():
        return
    tmp.put(m, WING[2])
    tmp.put(m & ~P.erode(m) & (tmp.grid()[1] < y), WING[3])
    tmp.put(P.outline_of(m) & ~tmp.filled(), FUR[0])
    over(cv, tmp, alpha)


def b_in(i):
    f = new()
    if i == 0:
        b_cocoon(f, rx=12.5)
        return f, None
    k = ease_out(i / 4.0)
    spread_out = 3 + 5 * clamp01((i - 4) / 10)
    u = clamp01((i - 5) / (NF_IN - 6))
    for side in (-1, 1):
        rt = (CX + side * spread_out, CY - 9 - 6 * u)
        rb = (CX + side * (spread_out + 2), CY + 12 - 10 * u)
        b_wing(f, side, k, 22 + 13 * k, rt, rb, erode_k=ease_in(u) * 1.7)
    if i <= 3:
        ## pelerin acilirken govde sutunu daralip kaybolur
        b_cocoon(f, rx=12.5 * (1.0 - 0.27 * i), ry=19.5 * (1.0 - 0.2 * i), eyes=i <= 1)
    if i >= 4:
        v = (i - 4) / (NF_IN - 5)
        for k2, (dx, dy, spin) in enumerate(B_SHREDS):
            if v > 0.97:
                continue
            x = CX + dx * (1 + 0.3 * v) + math.sin(v * 6 + k2) * 2
            y = CY + dy - 7 + 24 * v * v + 3 * v
            b_shred(f, x, y, spin + v * 5 * (1 if k2 % 2 else -1), 1.0 - 0.6 * v)
    return f, None


def b_out(i):
    f = new()
    g = new()
    if i <= 1:
        k = 0.55 if i == 0 else 0.25
        for side in (-1, 1):
            b_wing(f, side, k, 20 + 12 * k, (CX + side * 3, CY - 9), (CX + side * 4, CY + 15))
        b_cocoon(f)
        return f, None
    if i <= 3:
        b_cocoon(f)
        return f, None
    u = clamp01((i - 4) / (NF_OUT - 6))
    e = ease_in(u)
    ry = 19.5 + (2.6 - 19.5) * e
    rx = 12.0 + 6.5 * e
    cyc = GY + 2 - ry
    target = f if ry > 6.5 else g
    if u < 1.0:
        b_cocoon(target, cyc=cyc, rx=rx, ry=ry, eyes=False)
    else:
        v = clamp01((i - (NF_OUT - 2)) / 1.0)
        rr = 18.5 * (1.0 - 0.5 * v)
        m = P.blob_mask(g, GX, GY, rr, 2.6, seed=7, wobble=0.1)
        m &= ~P.ellipse_mask(g, GX + 3, GY - 1, rr * (0.35 + 0.6 * v), 2.4 + v)
        g.put(m, FUR[1])
        g.put(m & ~P.erode(m) & (g.grid()[1] > GY), WING[2])
        g.put(P.outline_of(m) & ~g.filled(), FUR[0])
    return f, g


# ====================================================================== C - Kizil Sis
## Top bulut yerine SERIT: govdeyi saran uc sarap rengi sis seridi (isi golgesi: dis koyu, ic acik) cozulup donerek yukselir,
## parcalara ayrilip incelir; az sayida kisa kor cizgisi. Donus: seritler asagi kayip yerde yayilir + kizil halka.
MIST = [(18, 5, 16), (52, 14, 38), (86, 24, 56), (128, 40, 76), (178, 78, 112)]
WHIRL = [(51, 9, 20), (104, 18, 38), (152, 32, 58), (206, 76, 98), (248, 168, 178)]
WHIRL_BACK = [(20, 6, 16), (46, 12, 30), (66, 18, 40), (88, 28, 52), (112, 40, 64)]
COCOON_MIST = [(18, 5, 16), (46, 12, 32), (70, 20, 46), (96, 30, 60), (130, 48, 80)]
SQ = 0.36
## (yukseklik orani 0..1 ayaktan basa, faz, yon) - bes hilal govdeyi ayaktan basa sarar
C_ARCS = [(0.0, 0.2, 1), (0.25, 2.3, 1), (0.5, 4.4, 1), (0.75, 1.1, 1), (1.0, 3.3, 1)]


def whirl_arc(front, back, cy, r, head, span, th_head, th_tail, brk, seed):
    """Elips yorungede kalin hilal (basi kalin + parlak, kuyrugu ince); yorungenin ON yarisi front tuvaline, ARKA yarisi
    back tuvaline (oyuncunun altindaki katman - girdap karakterin arkasindan dolanir)."""
    if span < 0.2 or th_head < 0.5:
        return
    a0 = head - span
    ## Elips zinciri: kalinlik EKRAN pikselinde (arc_band'in yaricap kalinligi elipste on/arka tarafta SQ kadar inceliyordu).
    segs = {True: [], False: []}
    n = max(8, int(span * r * 0.9))
    for q in range(n + 1):
        sp = q / n
        a = a0 + span * sp
        w = th_tail + (th_head - th_tail) * sp ** 1.1
        if sp > 0.84:
            w *= math.sqrt(max(0.0, 1.0 - ((sp - 0.84) / 0.16) ** 2))   ## bas yuvarlanir, duz kesilmez
        if brk > 0.0:
            w *= clamp01(((1.0 - 1.8 * brk) - math.sin(sp * 7.0 + seed)) / 0.5)
        if w < 0.55:
            continue
        segs[math.sin(a) > -0.08].append((CX + math.cos(a) * r, cy + math.sin(a) * r * SQ, w, w * 0.85, 0.0))
    for is_front, cv, pal in ((False, back, WHIRL_BACK), (True, front, WHIRL)):
        if not segs[is_front]:
            continue
        tmp = new()
        m = P.ellipses_mask(tmp, segs[is_front])
        P.heat_fill(tmp, m, pal, levels=(1, 2, 3, 4))
        over(cv, tmp)


def mist_cocoon(cv, k):
    """Ilk 2 kare: govdeyi orten koyu sis (donusum aninin ortusu)."""
    tmp = new()
    m = P.blob_mask(tmp, CX, CY + 2, 11.5 * k, 19.0 * k, seed=8, wobble=0.12)
    if m.any():
        P.heat_fill(tmp, m, COCOON_MIST, levels=(1, 3, 5, 7))
        over(cv, tmp)


def c_embers(f, i, t0, t1, rise):
    if not (t0 <= i <= t1):
        return
    u = (i - t0) / max(1, t1 - t0)
    for k in range(4):
        a = k * TAU / 4 + 0.7 + 3.0 * u
        rad = 14 + 18 * ease_out(u)
        x = CX + math.cos(a) * rad
        y = CY - 2 + rise * u + math.sin(a) * rad * SQ
        tx, ty = -math.sin(a), math.cos(a) * SQ
        tl = math.hypot(tx, ty) or 1.0
        for st in range(3 if u < 0.6 else 2):
            f.px(x - tx / tl * st, y - ty / tl * st, PINK if st == 0 else EYE)


def c_in(i):
    t = i / (NF_IN - 1)
    f = new()
    g = new()
    if i <= 1:
        mist_cocoon(f, 1.0 if i == 0 else 0.72)
    e = ease_out(t)
    for k, (hk, ph, _d) in enumerate(C_ARCS):
        cy = GY - 1 - hk * 32 - 16 * e * (0.6 + 0.4 * hk)
        r = 10 + 2 * (k % 2) + 15 * e
        head = ph + 7.0 * e
        span = 2.7 * (1.0 - 0.45 * t)
        whirl_arc(f, g, cy, r, head, span, 3.0 * (1.0 - 0.5 * t), 0.6, clamp01((t - 0.5) / 0.5), k * 1.3)
    c_embers(f, i, 2, 11, -18)
    return f, g


def c_out(i):
    t = i / (NF_OUT - 1)
    f = new()
    g = new()
    if i <= 1:
        mist_cocoon(f, 1.0 if i == 0 else 0.72)
    e = ease_out(t)
    if 4 <= i <= 13:
        v = (i - 4) / 9.0
        P.shock_ring(g, GX, GY, 14 + 14 * ease_out(v), 2.2 - 1.1 * v, v, WING, SQ, 3.0, break_from=0.4)
    for k, (hk, ph, _d) in enumerate(C_ARCS):
        cy0 = GY - 1 - hk * 32
        cy = cy0 + (GY - cy0) * e
        r = 10 + 2 * (k % 2) + 14 * e
        head = ph - 6.0 * e
        span = 2.7 * (1.0 - 0.4 * t)
        whirl_arc(f, g, cy, r, head + span, span, 3.0 * (1.0 - 0.45 * t), 0.6, clamp01((t - 0.45) / 0.55), k * 1.7)
    return f, g


# ====================================================================== D - Golge Sutunu
## Yerde golge havuzu (on dudagi kizil), havuzdan govdeyi orten kara alev dilleri (cekirdek kisik kizil); diller kopup kivrik
## tutsu dumani gibi yukselir ve sonar. Donus: diller havuza cekilir, ustten damlalar duser, havuz kapanir.
SHADE = [(7, 3, 10), (26, 12, 30), (48, 24, 56), (84, 20, 42), (140, 36, 60)]
D_TONGUES = [(-9, 27, 3.6, 0.95), (-4.5, 39, 4.4, 1.25), (0, 46, 5.0, 1.05), (4.5, 40, 4.4, 1.35), (9, 28, 3.6, 1.1)]


def tongue_mask(cv, x, base, tip, w, sway, both=False):
    h = base - tip
    if h < 1.5:
        return np.zeros((cv.h, cv.w), dtype=bool)
    n = max(3, int(h / 1.6))
    items = []
    for q in range(n + 1):
        u = q / n
        rx = (w * (math.sin(math.pi * u) ** 0.8) * (1.0 - 0.5 * u) if both else w * (1.0 - u) ** 0.8) + 0.5
        bend = sway * (math.sin(u * math.pi * 0.9) + 0.6 * u * u)
        items.append((x + bend, base - h * u, rx, 2.0, 0.0))
    return P.ellipses_mask(cv, items)


def d_fill(cv, m, alpha=1.0):
    if not m.any():
        return
    tmp = new()
    P.heat_fill(tmp, m, SHADE, levels=(2, 3, 5, 8))
    over(cv, tmp, alpha)


def d_pool(g, rx, alpha=1.0):
    if rx < 1.5:
        return
    tmp = new()
    m = P.blob_mask(tmp, GX, GY + 1, rx, rx * 0.36, seed=4, wobble=0.08)
    tmp.put(m, FUR[1])
    tmp.put(m & P.ellipse_mask(tmp, GX, GY + 0.5, rx * 0.62, rx * 0.2), FUR[0])
    Y = tmp.grid()[1]
    tmp.put(m & ~P.erode(m) & (Y > GY + 1), WING[2])
    tmp.put(m & ~P.erode(m) & (Y <= GY + 1), FUR[2])
    tmp.put(P.outline_of(m) & ~tmp.filled(), FUR[0])
    over(g, tmp, alpha)


def d_in(i):
    t = i / (NF_IN - 1)
    f = new()
    g = new()
    attached = np.zeros((H, W), dtype=bool)
    for k, (dx, h, w, sp) in enumerate(D_TONGUES):
        lift = 42 * ease_in(clamp01(t * sp * 1.2 - 0.06))
        base = GY + 1 - lift
        sway = (1.6 if k % 2 else -1.6) * (0.5 + t)
        if lift > 3:
            k_l = clamp01(lift / 44.0)
            hh = h * (0.55 - 0.3 * t) * (1.0 - 0.6 * k_l)
            ww = w * (0.85 - 0.45 * t) * (1.0 - 0.75 * k_l)
            m = tongue_mask(f, CX + dx * (1 + 0.4 * t), base, base - hh, ww, sway, both=True)
            d_fill(f, m)
        else:
            attached |= tongue_mask(f, CX + dx, base, base - h * (1.0 - 0.6 * ease_out(t)), w, sway)
    d_fill(f, attached)
    d_pool(g, 9 + 12 * ease_out(min(1.0, t * 2.4)) - 19 * ease_in(max(0.0, t - 0.5) / 0.5))
    if 1 <= i <= 9:
        v = (i - 1) / 8.0
        P.shock_ring(g, GX, GY + 1, 13 + 15 * ease_out(v), 2.0 - 1.0 * v, v, WING, 0.36, 2.0, break_from=0.45)
    return f, g


def d_out(i):
    t = i / (NF_OUT - 1)
    f = new()
    g = new()
    m = np.zeros((H, W), dtype=bool)
    for k, (dx, h, w, sp) in enumerate(D_TONGUES):
        sink = ease_in(clamp01(t * (0.95 + 0.4 * sp)))
        sway = (1.4 if k % 2 else -1.4) * (1.0 - t)
        m |= tongue_mask(f, CX + dx, GY + 1, GY + 1 - h * (1.0 - sink), w * (1.0 - 0.3 * t), sway)
    for k, (dx, t0) in enumerate(((-7, 0.0), (6, 0.12), (0, 0.24))):
        u = clamp01((t - t0) / 0.36)
        if 0.0 < u < 1.0:
            y = CY - 30 + (GY - CY + 28) * ease_in(u)
            m |= tongue_mask(f, CX + dx, y + 3, y - 4 - 3 * u, 1.9, 0.0, both=True)
    d_fill(f, m)
    rx = 19 - 2 * math.sin(t * 9) * (1 - t) - 17.5 * ease_in(max(0.0, t - 0.45) / 0.55)
    d_pool(g, rx)
    return f, g


DESIGNS = {"A": (a_in, a_out, NF_A_IN, NF_OUT), "B": (b_in, b_out, NF_IN, NF_OUT), "C": (c_in, c_out, NF_IN, NF_OUT),
           "D": (d_in, d_out, NF_IN, NF_OUT)}
NAMES = {"A": "Yarasa Surusu", "B": "Pelerin", "C": "Kizil Girdap", "D": "Golge Sutunu"}


def render(code, phase):
    fn = DESIGNS[code][0 if phase == "in" else 1]
    nf = DESIGNS[code][2 if phase == "in" else 3]
    fronts, grounds = [], []
    for i in range(nf):
        fcv, gcv = fn(i)
        fronts.append(fcv.image())
        grounds.append(gcv.image() if gcv is not None else None)
    layers = {"front": fronts}
    if any(gim is not None and gim.getbbox() for gim in grounds):
        layers["ground"] = [gim if gim is not None else Image.new("RGBA", (W, H)) for gim in grounds]
    for name, frames in layers.items():
        strip = Image.new("RGBA", (W * nf, H))
        for i, im in enumerate(frames):
            a = np.array(im)[:, :, 3]
            if a[0, :].any() or a[-1, :].any() or a[:, 0].any() or a[:, -1].any():
                print("UYARI kenar:", code, phase, name, i)
            strip.paste(im, (i * W, 0))
        strip.save(os.path.join(SHEETS, "%s_%s_%s.png" % (code, phase, name)))
    meta = {"name": NAMES[code], "w": W, "h": H, "frames": nf, "fps": FPS, "ax": AX, "ay": AY, "world_px": WORLD_PX,
            "layers": list(layers.keys())}
    with open(os.path.join(SHEETS, "%s_%s.json" % (code, phase)), "w", encoding="utf-8") as fh:
        json.dump(meta, fh, ensure_ascii=False)
    return layers


def preview(all_layers):
    """Duz cimen zemin uzerinde x3 kare kare (ground altta, front ustte)."""
    Z = 3
    rows = []
    for code in DESIGNS:
        for phase in ("in", "out"):
            layers = all_layers[(code, phase)]
            nf = len(layers["front"])
            row = Image.new("RGBA", (W * Z * nf // 2, H * Z // 2 + 2), (86, 128, 64, 255))
            for i in range(nf):
                cell = Image.new("RGBA", (W, H), (86, 128, 64, 255))
                if "ground" in layers:
                    cell.alpha_composite(layers["ground"][i])
                cell.alpha_composite(layers["front"][i])
                cell = cell.crop((W // 4, H // 4, W * 3 // 4, H * 3 // 4)).resize((W * Z // 2, H * Z // 2), Image.NEAREST)
                row.paste(cell, (i * W * Z // 2, 0))
            rows.append(row)
    wmax = max(r.width for r in rows)
    out = Image.new("RGBA", (wmax, sum(r.height for r in rows)), (40, 40, 40, 255))
    y = 0
    for r in rows:
        out.paste(r, (0, y))
        y += r.height
    out.save(os.path.join(OUT, "sanat_onizleme.png"))


def main():
    os.makedirs(SHEETS, exist_ok=True)
    random.seed(1)
    all_layers = {}
    for code in DESIGNS:
        for phase in ("in", "out"):
            all_layers[(code, phase)] = render(code, phase)
    preview(all_layers)
    print("tamam", SHEETS)


if __name__ == "__main__":
    main()
