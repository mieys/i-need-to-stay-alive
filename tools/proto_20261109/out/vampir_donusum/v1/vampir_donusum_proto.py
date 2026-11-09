"""VAMPIR COCUK yarasa donusumu efekt PROTOTIPLERI A-D (2026-11-09, oyuna bagli DEGIL).

Kullanici: "vampir cocugun yarasaya donusup geri donunceki partikul efektini yeniden tasarlar misin, suanki kalitesiz".
Bugunku "puff" (scripts/vampir_fx.gd): 30 rastgele kare piksel (2-4 x 1,212 dunya = karakter pikselinden 3-6 kat iri) 80 birime
kadar sacilir, giris ve cikis ayni. Oyunda sprite donusum ANINDA degisir (ayni karede puff dogar) -> her prototip ilk karede
govdeyi ORTER, sonra acilir.

  A Yarasa Surusu : duman bulutu + oyunun kendi mini yarasalari (mini_bat_1..3) disari sacilir / donuste iceri sarmal doner
  B Pelerin       : kirmizi gozlu kapali pelerin kanat gibi acilip yirtilir / donuste perde gibi yere duser
  C Kizil Sis     : yuvarlak sis donerek yukselen girdaba doner / donuste yere coker, halka olur
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
SHADE = [(7, 3, 10), (30, 14, 34), (58, 30, 66), (124, 28, 50), (206, 70, 88)]
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
A_BATS_IN = [(-160, 52, 0.5), (-125, 48, -0.4), (-92, 50, 0.3), (-58, 47, -0.5), (-22, 52, 0.4), (200, 40, -0.3)]
A_BATS_OUT = [(-150, 0), (-35, 1), (40, 2), (145, 0)]


def a_cloud(t, rise):
    base = [(0, 2, 11), (-6, 10, 8), (6, 10, 8), (-6, -5, 8), (6, -5, 7), (0, -10, 7), (0, 16, 7)]
    items = []
    s = ease_out(t)
    for (dx, dy, r) in base:
        L = math.hypot(dx, dy) or 1.0
        items.append((CX + dx + dx / L * 6 * s, CY + dy + dy / L * 4 * s + rise * t, r * (1.06 - 0.4 * t)))
    return items


def a_in(i):
    t = i / (NF_IN - 1)
    f = new()
    if t < 0.82:
        core = (CX, CY, 4.5 - 4 * t, WING[3] if i == 0 else WING[2]) if i < 3 else None
        smoke(f, a_cloud(t, -8), clamp01((t - 0.12) / 0.62), seed=1, core=core)
    if i >= 1:
        u = (i - 1) / (NF_IN - 2)
        for k, (ang, dist, curl) in enumerate(A_BATS_IN):
            a = math.radians(ang) + curl * u
            d = 4 + dist * ease_out(u * 1.05)
            x = CX + math.cos(a) * d
            y = CY - 2 + math.sin(a) * d * 0.85 - 6 * u
            alpha = 1.0 if u < 0.62 else 1.0 - (u - 0.62) / 0.38
            sprite(f, MINI[(i + k) % 3], x, y, alpha)
    return f, None


def a_out(i):
    t = i / (NF_OUT - 1)
    f = new()
    if t < 0.62:
        core = (CX, CY, 4.0, WING[2]) if i < 2 else None
        smoke(f, a_cloud(t * 0.8, 7), clamp01((t - 0.08) / 0.5), seed=3, core=core)
    for k, (ang, ph) in enumerate(A_BATS_OUT):
        u = t
        a = math.radians(ang) + 4.2 * ease_out(u)
        d = 24 * (1.0 - ease_in(u)) + 3
        x = CX + math.cos(a) * d
        y = CY + 2 + math.sin(a) * d * 0.6 + 4 * u
        alpha = 1.0 if d > 11 else (d - 3) / 8.0
        if alpha > 0.1:
            sprite(f, MINI[(i + ph) % 3], x, y, alpha)
    return f, None


# ====================================================================== B - Pelerin
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
    # on kenar: hafif disa bombe
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
    return pts, tip, fing, scallops, (nx, ny)


def b_wing(cv, side, open_k, L, rt, rb, erode_k=0.0):
    pts, tip, fing, scallops, _n = _wing_poly(side, open_k, L, rt, rb)
    tmp = new()
    m = P.poly_mask(tmp, pts)
    if erode_k > 0.0:
        X, Y = tmp.grid()
        for (sx, sy, sl) in scallops:
            r = sl * 0.95 * erode_k
            m &= (X - sx) ** 2 + (Y - sy) ** 2 > r * r
        # uca dogru da kisalir
        r = L * 0.9 * max(0.0, erode_k - 0.45)
        m &= (X - tip[0]) ** 2 + (Y - tip[1]) ** 2 > r * r
    if not m.any():
        return
    X, Y = tmp.grid()
    # ton: on kenara yakin acik, kemik cizgileri koyu
    lx, ly = tip[0] - rt[0], tip[1] - rt[1]
    ll = math.hypot(lx, ly) or 1.0
    dist_le = np.abs((X - rt[0]) * ly - (Y - rt[1]) * lx) / ll
    tone = np.where(dist_le < 2.2, 3, 2)
    for t in (2, 3):
        tmp.put(m & (tone == t), WING[t])
    bones = np.zeros_like(m)
    for fp in fing[1:3]:
        bx, by = fp[0] - rt[0], fp[1] - rt[1]
        bl = math.hypot(bx, by) or 1.0
        tt = np.clip(((X - rt[0]) * bx + (Y - rt[1]) * by) / (bl * bl), 0, 0.92)
        bones |= np.hypot(X - (rt[0] + tt * bx), Y - (rt[1] + tt * by)) <= 0.55
    tmp.put(m & bones, WING[1])
    tt = np.clip(((X - rt[0]) * lx + (Y - rt[1]) * ly) / (ll * ll), 0, 1)
    edge = np.hypot(X - (rt[0] + tt * lx), Y - (rt[1] + tt * ly)) <= 1.0
    tmp.put(m & edge, FUR[3])
    tmp.put(P.outline_of(m) & ~tmp.filled(), WING[0])
    over(cv, tmp)


def b_cocoon(cv, top_cut=None, eyes=True):
    tmp = new()
    X, Y = tmp.grid()
    m = ((X - CX) / 12.0) ** 2 + ((Y - (CY + 2)) / 19.5) ** 2 <= 1.0
    # yaka: iki sivri uc
    m |= P.poly_mask(tmp, [(CX - 12, CY - 19), (CX - 4, CY - 12), (CX - 9, CY - 9)])
    m |= P.poly_mask(tmp, [(CX + 12, CY - 19), (CX + 4, CY - 12), (CX + 9, CY - 9)])
    # etek: yarasa kanadi oyuklari
    for k in range(-2, 3):
        m &= (X - (CX + k * 6)) ** 2 + (Y - (CY + 24.5)) ** 2 > 3.6 ** 2
    if top_cut is not None:
        wave = top_cut + 1.6 * np.sin(X * 0.9)
        m &= Y > wave
    if not m.any():
        return m
    nx_ = (X - CX) / 12.0
    tone = np.where(nx_ < -0.35, 3, np.where(nx_ < 0.4, 2, 1))
    for t in (1, 2, 3):
        tmp.put(m & (tone == t), WING[t])
    folds = (np.abs(X - (CX - 3.5)) < 0.5) | (np.abs(X - (CX + 3.5)) < 0.5)
    tmp.put(m & folds & (Y > CY - 6), WING[1])
    tmp.put(m & (np.abs(X - (CX + 3.5)) < 0.5) & (Y > CY - 6), WING[0])
    if top_cut is not None:
        rim = m & ~P.erode(m) & (Y < top_cut + 3.5)
        tmp.put(rim, WING[3])
    tmp.put(P.outline_of(m) & ~tmp.filled(), WING[0])
    if eyes and top_cut is None:
        for ex in (-2, 2):
            tmp.px(CX + ex, CY - 9, EYE)
    over(cv, tmp)
    return m


B_SHREDS = [(-30, -4, -0.6), (-18, 2, 0.4), (-36, 6, 0.2), (30, -3, 0.5), (19, 3, -0.4), (37, 7, -0.2)]


def b_shred(cv, x, y, rot, s=1.0):
    pts = []
    for (px_, py_) in ((-2.5, -1.2), (2.6, -0.6), (0.6, 2.4), (-1.0, 1.0)):
        c, sn = math.cos(rot), math.sin(rot)
        pts.append((x + (px_ * c - py_ * sn) * s, y + (px_ * sn + py_ * c) * s))
    tmp = new()
    m = P.poly_mask(tmp, pts)
    if not m.any():
        tmp.px(x, y, WING[2])
        over(cv, tmp)
        return
    tmp.put(m, WING[2])
    tmp.put(m & ~P.erode(m) & (tmp.grid()[1] < y), WING[3])
    tmp.put(P.outline_of(m) & ~tmp.filled(), WING[0])
    over(cv, tmp)


def b_in(i):
    f = new()
    if i <= 1:
        for side in (-1, 1):
            b_wing(f, side, 0.0 if i == 0 else 0.35, 20 + 4 * i, (CX + side * 3, CY - 9), (CX + side * 4, CY + 15))
        b_cocoon(f)
        return f, None
    k = ease_out((i - 1) / 3.0)
    spread_out = 3 + 5 * clamp01((i - 4) / 10)
    u = clamp01((i - 5) / (NF_IN - 6))
    for side in (-1, 1):
        rt = (CX + side * spread_out, CY - 9 - 5 * u)
        rb = (CX + side * (spread_out + 2), CY + 12 - 9 * u)
        b_wing(f, side, k, 22 + 13 * k, rt, rb, erode_k=ease_in(u) * 1.35)
    if i <= 3:
        # pelerin acilirken govde sutunu daralip kaybolur
        tmp = new()
        X, Y = tmp.grid()
        ry = 19.5 * (1.0 - 0.33 * (i - 1))
        rx = 12.0 * (1.0 - 0.38 * (i - 1))
        m = ((X - CX) / rx) ** 2 + ((Y - (CY + 2)) / ry) ** 2 <= 1.0
        tmp.put(m, WING[1])
        tmp.put(m & ((X - CX) < -rx * 0.3), WING[2])
        tmp.put(P.outline_of(m) & ~tmp.filled(), WING[0])
        over(f, tmp)
    if 2 <= i <= 4:
        # uclarin cizdigi savrulma yayi
        for side in (-1, 1):
            a1 = math.radians(-160 if side < 0 else -20)
            a0 = math.radians(150 if side < 0 else 30)
            if side > 0:
                a0, a1 = math.radians(-25), math.radians(75)
            else:
                a0, a1 = math.radians(105), math.radians(205)
            tmp = new()
            P.arc_band(tmp, CX, CY - 4, 34, a0, a1, 2.2, 0.6, WING, squash=0.8)
            over(f, tmp, 1.0 if i < 4 else 0.66)
    if i >= 5:
        v = (i - 5) / (NF_IN - 6)
        for k2, (dx, dy, spin) in enumerate(B_SHREDS):
            if v > 0.95:
                continue
            x = CX + dx * (1 + 0.35 * v) + math.sin(v * 6 + k2) * 2
            y = CY + dy - 6 + 26 * v * v + 4 * v
            b_shred(f, x, y, spin + v * 5 * (1 if k2 % 2 else -1), 1.0 - 0.3 * v)
            if v > 0.7:
                pass
    return f, None


def b_out(i):
    f = new()
    g = new()
    t = i / (NF_OUT - 1)
    if i <= 2:
        k = 1.0 - i / 2.5
        for side in (-1, 1):
            b_wing(f, side, k * 0.8, 20 + 10 * k, (CX + side * 3, CY - 9), (CX + side * 4, CY + 15))
        b_cocoon(f)
        return f, None
    if i <= 3:
        b_cocoon(f)
        return f, None
    u = clamp01((i - 4) / 7.0)
    top = CY - 20 + (GY - CY + 22) * ease_in(u)
    if u < 1.0:
        b_cocoon(f, top_cut=top, eyes=False)
    # yere dusen pelerin birikintisi
    if i >= 7:
        v = clamp01((i - 7) / (NF_OUT - 8))
        rx = 9 + 9 * ease_out(min(1.0, v * 1.6)) - 7 * ease_in(max(0.0, v - 0.5) * 2)
        if rx > 1.5:
            m = P.blob_mask(g, GX, GY + 1, rx, rx * 0.36, seed=7, wobble=0.12)
            if v > 0.45:
                m &= P.break_mult(g, GX, GY + 1, 0.36, (v - 0.45) / 0.55, 2.0) > 0.35
            g.put(m, WING[1])
            g.put(m & ~P.erode(m), WING[2])
            g.put(P.outline_of(m) & ~g.filled(), WING[0])
    return f, g


# ====================================================================== C - Kizil Sis
def c_in(i):
    t = i / (NF_IN - 1)
    f = new()
    items = []
    if t < 0.35:
        k = 1.0 - t / 0.35
        for (dy, r) in ((-9, 8.5), (2, 11), (13, 8.5)):
            items.append((CX, CY + dy, r * (0.3 + 0.7 * k)))
    arms = []
    for arm in range(3):
        for j in range(3):
            a = arm * TAU / 3 + j * 0.62 + 3.4 * ease_out(t) + 0.4
            rad = (2.5 + 5.5 * j) * (0.35 + 1.6 * ease_out(t))
            r = (8.5 - 2.0 * j) * (1.0 - 0.62 * t)
            y = CY + 4 - 22 * ease_out(t) * (0.7 + 0.22 * j)
            arms.append((CX + math.cos(a) * rad, y + math.sin(a) * rad * 0.42, r))
    if t < 0.9:
        cool = clamp01((t - 0.18) / 0.62)
        pal = CRIM if t < 0.16 else ([CRIM[0], SMK[1], CRIM[1], CRIM[2], CRIM[3]] if t < 0.32 else SMK)
        smoke(f, items + arms, cool, pal=pal, seed=5,
              core=(CX, CY + 1, 5.0 - 10 * t, CRIM[3]) if t < 0.35 else None)
    # kor cizgileri: az, kisa, teget
    if 2 <= i <= 11:
        u = (i - 2) / 9.0
        for k in range(5):
            a = k * TAU / 5 + 0.7 + 2.6 * u
            rad = 10 + 22 * ease_out(u)
            x = CX + math.cos(a) * rad
            y = CY - 4 - 20 * u + math.sin(a) * rad * 0.42
            tx, ty = -math.sin(a), math.cos(a) * 0.42
            tl = math.hypot(tx, ty) or 1.0
            ln = 3 if u < 0.6 else 2
            for s in range(ln):
                f.px(x - tx / tl * s, y - ty / tl * s - s * 0.5, PINK if s == 0 else EYE)
    return f, None


def c_out(i):
    t = i / (NF_OUT - 1)
    f = new()
    g = new()
    items = []
    if t < 0.3:
        k = 1.0 - t / 0.3
        for (dy, r) in ((-9, 8.5), (2, 11), (13, 8.5)):
            items.append((CX, CY + dy + 6 * (1 - k), r * (0.35 + 0.65 * k)))
    n = 8
    s = ease_out(min(1.0, t * 1.5))
    for k in range(n):
        a = k * TAU / n + 0.2
        R = 4 + 17 * s
        y_body = CY + 6 + (k % 3 - 1) * 5
        y = y_body + (GY - 2 - y_body) * s + math.sin(a) * R * 0.36
        r = (7.0 - 3.8 * t) * (1.0 - 0.25 * (k % 2))
        items.append((CX + math.cos(a) * R, y, r))
    if t < 0.85:
        cool = clamp01((t - 0.15) / 0.62)
        smoke(f, items, cool, pal=SMK if t > 0.1 else [CRIM[0], SMK[1], SMK[2], CRIM[2], CRIM[3]], seed=9,
              core=(CX, CY + 2, 4.0, CRIM[3]) if i == 0 else None)
    if 2 <= i <= 12:
        v = (i - 2) / 10.0
        P.shock_ring(g, GX, GY, 10 + 18 * ease_out(v), 2.6 - 1.4 * v, v, CRIM, 0.4, 3.0, break_from=0.4)
    return f, g


# ====================================================================== D - Golge Sutunu
D_TONGUES = [(-11, 26, 3.2, 0.9), (-6, 38, 4.2, 1.2), (-1, 45, 4.8, 1.0), (4, 41, 4.4, 1.35), (9, 32, 3.6, 1.1), (13, 22, 2.8, 0.8)]


def tongue_mask(cv, x, base, tip, w, sway, both=False):
    h = base - tip
    if h < 1.5:
        return np.zeros((cv.h, cv.w), dtype=bool)
    n = max(3, int(h / 2.2))
    items = []
    for q in range(n + 1):
        u = q / n
        rx = (w * (math.sin(math.pi * u) ** 0.7) if both else w * (1.0 - u) ** 0.75) + 0.55
        items.append((x + sway * math.sin(u * 2.6), base - h * u, rx, 2.4, 0.0))
    return P.ellipses_mask(cv, items)


def d_pool(g, rx, k_break=0.0):
    if rx < 1.5:
        return
    m = P.blob_mask(g, GX, GY + 1, rx, rx * 0.38, seed=4, wobble=0.1)
    if k_break > 0.0:
        m &= P.break_mult(g, GX, GY + 1, 0.38, k_break, 1.0) > 0.35
    g.put(m, FUR[1])
    g.put(m & P.erode(m) & ~P.erode(P.erode(P.erode(m))), FUR[2])
    g.put(m & ~P.erode(m), WING[2])
    g.put(P.outline_of(m) & ~g.filled(), FUR[0])


def d_in(i):
    t = i / (NF_IN - 1)
    f = new()
    g = new()
    m = np.zeros((H, W), dtype=bool)
    for k, (dx, h, w, sp) in enumerate(D_TONGUES):
        lift = 40 * ease_in(clamp01(t * sp * 1.15 - 0.05))
        base = GY + 1 - lift
        tip = base - h * (1.0 - 0.75 * ease_out(t)) * (1.0 if lift < 2 else 0.85)
        ww = w * (1.0 - 0.7 * t)
        sway = (1.4 if k % 2 else -1.4) * (0.4 + t)
        if lift > 3:
            m |= tongue_mask(f, CX + dx, base, tip, ww * 0.9, sway, both=True)
        else:
            m |= tongue_mask(f, CX + dx, base, tip, ww, sway)
    if t < 0.92 and m.any():
        P.heat_fill(f, m, SHADE, levels=(1, 2, 3, 5))
    d_pool(g, 9 + 11 * ease_out(min(1.0, t * 2.2)) - 4 * ease_in(max(0.0, t - 0.5) * 2), clamp01((t - 0.55) / 0.45))
    if 1 <= i <= 9:
        v = (i - 1) / 8.0
        P.shock_ring(g, GX, GY + 1, 12 + 16 * ease_out(v), 2.4 - 1.2 * v, v, WING, 0.38, 2.0, break_from=0.45)
    return f, g


def d_out(i):
    t = i / (NF_OUT - 1)
    f = new()
    g = new()
    m = np.zeros((H, W), dtype=bool)
    for k, (dx, h, w, sp) in enumerate(D_TONGUES):
        sink = ease_in(clamp01(t * (0.9 + 0.35 * sp)))
        hh = h * (1.0 - sink)
        sway = (1.2 if k % 2 else -1.2) * (1.0 - t)
        m |= tongue_mask(f, CX + dx, GY + 1, GY + 1 - hh, w * (1.0 - 0.3 * t), sway)
    # yukaridan havuza dusen damlalar
    for k, (dx, t0) in enumerate(((-7, 0.0), (6, 0.1), (0, 0.2))):
        u = clamp01((t - t0) / 0.38)
        if 0.0 < u < 1.0:
            y = CY - 30 + (GY - CY + 28) * ease_in(u)
            m |= tongue_mask(f, CX + dx, y + 3, y - 4 - 2 * u, 1.9, 0.0, both=True)
    if m.any():
        P.heat_fill(f, m, SHADE, levels=(1, 2, 3, 5))
    rx = 19 - 2 * math.sin(t * 9) * (1 - t) - 17 * ease_in(max(0.0, t - 0.45) / 0.55)
    d_pool(g, rx, clamp01((t - 0.7) / 0.3) * 0.5)
    return f, g


DESIGNS = {"A": (a_in, a_out), "B": (b_in, b_out), "C": (c_in, c_out), "D": (d_in, d_out)}
NAMES = {"A": "Yarasa Surusu", "B": "Pelerin", "C": "Kizil Sis", "D": "Golge Sutunu"}


def render(code, phase):
    fn = DESIGNS[code][0 if phase == "in" else 1]
    nf = NF_IN if phase == "in" else NF_OUT
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
