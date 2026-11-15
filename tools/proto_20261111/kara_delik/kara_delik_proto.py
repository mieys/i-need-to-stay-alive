"""HADIME E KARA DELIK efekt PROTOTIPLERI A-C (2026-11-11, oyuna bagli DEGIL; D shader'dir: kara_delik_d.gdshader).

Kullanici: "hadimenin kara delik yetenegi icin 4 adet prototip hazirla, suanki goruntusunu begenmiyorum".
Bugunku sayfa (tools/gen_hadime_fx.py black_hole): 1,212 dunya px (karakterden iri), dama desenli karartma, tek piksel sarmal
zerreler, kesik cizgili alan halkasi, ortada kucuk "goz" gibi duran disk + kure.

Hepsi: karakter pikseli 0,903 dunya (stil rehberi), cekim yaricapi HOLE_RADIUS 110 dunya = 122 sanat px, zemin elipsi 2:1,
zaman cizelgesi AYNI (ses senkronu): giris 8 kare 20 fps (0,4 sn), dongu, cikis 8 kare 16 fps ve CARPMA ANI cikisin 4. karesi
(= 6,25 sn, sesin cokus vurusu). Dongu 32 kare 16 fps (2 sn; zerreler cekim hizina yakin ilerler).

  A Coken Zemin   : yer yarilir, catlaklarin ortasinda dibi yesil lanet isigiyla parlayan bir cukur, toprak/cimen parcalari sarmal
                    cizerek kayip cukura duser; bitis: cukur kapanir, yesil isik sutunu + toz halkasi. (opak, konturlu, toprak)
  B Yutan Kure    : havada asili kara kure + foton halkasi + yatik birikim diski, yerden kure ye sarmal madde seritleri cekilir,
                    zeminde ice dogru daralan dalgalar; bitis: kure noktaya coker, beyaz yildiz + yer sok halkasi. (isik dili)
  C Hiclik Girdabi: tum cekim alanini kaplayan, ice dogru donen 3 kollu yari saydam girdap, ortada yesil halkali bosluk, kollarda
                    kopmus yapraklar; bitis: kollar merkeze sarilir, yesil yildiz + kirilan halka. (konturs uz, duz saydam bantlar)
  D Bukulen Uzay  : ciziM degil - zeminin kendisi deligin cevresinde bukulup ice kayar (shader, ekran dokusu), ortada kara ufuk +
                    1 px foton halkasi; bitis: buzulur, sok dalgasi zemini disa dogru kirar.

Cikti out/sheets/<kod>_<katman>.png (yatay serit: giris 8 + dongu 32 + cikis 8 kare) + <kod>.json; katman ground = deligin
dugumu (haritanin hemen ustu, yaratik/oyuncu altinda), front = z 20 (havadakiler). Onizleme out/sanat_onizleme.png.
Gercek oyun: kara_delik_run.ps1.   python -I tools/proto_20261111/kara_delik/kara_delik_proto.py
"""

import json
import math
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SHEETS = os.path.join(OUT, "sheets")

WORLD_PX = 0.903
W, H = 272, 180
AX, AY = 136, 112          # deligin dugum konumu (Hadime'nin ayagi) = cekim merkezi
SQ = 0.5                   # zemin elipsi
R = 110.0 / WORLD_PX       # cekim yaricapi, sanat px (122)
N_IN, N_LOOP, N_OUT = 8, 32, 8
FPS_IN, FPS_LOOP, FPS_OUT = 20, 16, 16
TAU = 2 * math.pi

xs = np.arange(W) + 0.5 - AX
ys = np.arange(H) + 0.5 - AY
GX, GY = np.meshgrid(xs, ys)
PU, PV = GX, GY / SQ
PR = np.hypot(PU, PV)
PT = np.arctan2(PV, PU)


def clamp01(x):
    return max(0.0, min(1.0, x))


def ease_out(t):
    t = clamp01(t)
    return 1.0 - (1.0 - t) ** 2


def ease_in(t):
    return clamp01(t) ** 2


def hash01(*v):
    h = 2166136261
    for x in v:
        h = (h ^ (int(x) & 0xFFFFFFFF)) * 16777619 & 0xFFFFFFFF
        h ^= h >> 13
    return (h & 0xFFFF) / 65535.0


# ====================================================================== katman yardimcilari (ortak, cizim dili degil)
def layer():
    return np.zeros((H, W, 4), dtype=np.uint8)


def band(a):
    """Saydamlik 3 basamak (duz bantlar, dither yok)."""
    if a > 0.8:
        return 1.0
    if a > 0.45:
        return 0.66
    if a > 0.12:
        return 0.33
    return 0.0


def put(L, mask, col, a=1.0):
    a = band(a)
    if a <= 0:
        return
    L[mask, 0] = col[0]
    L[mask, 1] = col[1]
    L[mask, 2] = col[2]
    L[mask, 3] = int(round(255 * a))


def px(L, x, y, col, a=1.0):
    a = band(a)
    x, y = int(math.floor(x)), int(math.floor(y))
    if 0 <= x < W and 0 <= y < H and a > 0:
        L[y, x] = (col[0], col[1], col[2], int(round(255 * a)))


def dilate(m):
    o = m.copy()
    o[1:, :] |= m[:-1, :]
    o[:-1, :] |= m[1:, :]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    return o


def erode(m):
    o = m.copy()
    o[1:, :] &= m[:-1, :]
    o[:-1, :] &= m[1:, :]
    o[:, 1:] &= m[:, :-1]
    o[:, :-1] &= m[:, 1:]
    return o


def ring1(mask):
    """Dolu maskenin 1 px ic kenari (elipste her yerde tam 1 ekran pikseli)."""
    return mask & ~erode(mask)


def ell(cx, cy, rx, ry):
    """Ekran koordinatli elips maskesi (cx, cy capaya gore)."""
    if rx <= 0.3 or ry <= 0.3:
        return np.zeros((H, W), bool)
    return ((GX - cx) / rx) ** 2 + ((GY - cy) / ry) ** 2 <= 1.0


def plane_disc(r, wob=None):
    """Zemin duzleminde r yaricapli daire (ekranda 2:1 elips). wob: aci -> carpan."""
    if r <= 0.3:
        return np.zeros((H, W), bool)
    if wob is None:
        return PR <= r
    return PR <= r * wob(PT)


def to_screen(rho, th, h=0.0):
    return AX + rho * math.cos(th), AY + rho * math.sin(th) * SQ - h


def disc_at(L, x, y, r, col, a=1.0):
    put(L, ell(x - AX, y - AY, r, r), col, a)


def line(L, x0, y0, x1, y1, col, a=1.0):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n + 1):
        t = i / max(1, n)
        px(L, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, col, a)


def vnoise(scale, seed):
    """Duzgun deger gurultusu 0..1 (ekran pikselinde)."""
    gx = (GX + AX) / scale
    gy = (GY + AY) / scale
    x0 = np.floor(gx).astype(int)
    y0 = np.floor(gy).astype(int)
    fx = gx - x0
    fy = gy - y0
    rng = np.random.default_rng(seed)
    tab = rng.random((int(H / scale) + 3, int(W / scale) + 3))

    def g(x, y):
        return tab[np.clip(y, 0, tab.shape[0] - 1), np.clip(x, 0, tab.shape[1] - 1)]

    sx = fx * fx * (3 - 2 * fx)
    sy = fy * fy * (3 - 2 * fy)
    a = g(x0, y0) * (1 - sx) + g(x0 + 1, y0) * sx
    b = g(x0, y0 + 1) * (1 - sx) + g(x0 + 1, y0 + 1) * sx
    return a * (1 - sy) + b * sy


def comp(dst, src):
    """src'yi dst'nin ustune koyar (alfa > 0 olan pikseller ezer - piksel dili, karisim yok)."""
    m = src[:, :, 3] > 0
    dst[m] = src[m]


# ====================================================================== A - COKEN ZEMIN (toprak, opak, 1 px koyu kontur)
A_OUT = (30, 19, 14)
A_ED = (68, 45, 31)
A_EM = (112, 78, 52)
A_EL = (158, 116, 78)
A_EH = (196, 156, 108)
A_GD = (46, 86, 36)
A_GM = (82, 132, 52)
A_GL = (128, 176, 72)
A_PIT = (12, 6, 14)
A_WALL_DEEP = (36, 24, 24)
A_CG1 = (34, 96, 34)
A_CG2 = (111, 220, 74)
A_CG3 = (214, 255, 170)
A_DUST = [(92, 76, 58), (140, 122, 98), (180, 164, 138), (214, 202, 178)]
A_TEX = vnoise(3.0, 11)
A_CRACKS = []
for _j in range(8):
    _rng = np.random.default_rng(100 + _j)
    _th = TAU * _j / 8 + _rng.uniform(-0.25, 0.25)
    _ln = _rng.uniform(26, 52)
    _pts = []
    _a = _th
    for _s in range(0, int(_ln) + 1, 3):
        _a += _rng.uniform(-0.09, 0.09)
        _pts.append((_s, _a))
    A_CRACKS.append(_pts)


def a_wob(th):
    return 1 + 0.08 * np.sin(3 * th + 1.0) + 0.05 * np.sin(5 * th + 2.0) + 0.04 * np.sin(7 * th + 0.5)


def a_wob2(th):
    return 1 + 0.10 * np.sin(4 * th + 0.3) + 0.07 * np.sin(9 * th + 1.7) + 0.05 * np.sin(13 * th + 4.0)


A_RP = 26.0   # cukur (duzlem px)
A_RR = 34.0   # moloz halkasinin disi


def a_pit(L, k, glow, ph, jit=0):
    """Cukur + moloz halkasi + ic duvar + dibindeki yesil isik. k: boyut 0..1."""
    if k <= 0.04:
        return
    rp, rr = A_RP * k, A_RR * k
    shift = np.roll(PR, jit, axis=1) if jit else PR
    pit = shift <= rp * a_wob(PT)
    rub = (shift <= rr * a_wob2(PT)) & ~pit
    allm = pit | rub
    # moloz: koyu kontur, govde, isik sol-ustte, cukura bakan ic kenar koyu, gurultuyle kirik toprak lekeleri
    put(L, dilate(allm) & ~allm, A_OUT)
    put(L, rub, A_EM)
    put(L, rub & (A_TEX > 0.62), A_ED)
    put(L, rub & (A_TEX < 0.25), A_EL)
    lit = rub & ~erode(allm) & (GY + AY < AY + 2) & (GX < 6)
    put(L, lit, A_EH)
    put(L, rub & dilate(pit), A_ED)
    # cukur: tamami kara; uzak yarida gorunen ic duvar (katman katman toprak), dibinde yesil isik
    put(L, pit, A_PIT)
    dep = max(2.0, 7.0 * k)
    floor_m = (PU ** 2 + ((GY - dep) / SQ) ** 2) <= (rp * 0.86) ** 2
    wall = pit & ~floor_m & (GY < dep * 0.6)
    if wall.any():
        top = np.full(W, 10 ** 6)
        cols = np.where(wall.any(axis=0))[0]
        for c in cols:
            top[c] = np.argmax(pit[:, c])
        d = np.arange(H)[:, None] - top[None, :]
        tones = [(0, A_EL), (1, A_EM), (2, A_ED), (3, A_ED), (4, A_WALL_DEEP), (5, A_WALL_DEEP)]
        for dd, col in tones:
            put(L, wall & (d == dd), col)
        put(L, wall & (d >= 6), (24, 30, 22))
    if glow > 0:
        gr = rp * (0.48 + 0.06 * math.sin(TAU * ph * 2))
        gm = (PU ** 2 + ((GY - dep - 1) / SQ) ** 2) <= gr ** 2
        put(L, gm & pit, A_CG1, 0.66 * glow + 0.34 * (glow > 0.99))
        core = (PU ** 2 + ((GY - dep - 1) / SQ) ** 2) <= (gr * 0.45) ** 2
        put(L, core & pit, A_CG2 if glow < 1.2 else A_CG3, 1.0 if glow >= 0.66 else 0.66)
        put(L, ring1(gm) & pit & (GY > 0), A_CG2, 0.66)
    # yakin dudak (on kenar) acik, uzak dis kenar koyu
    put(L, dilate(pit) & ~pit & (GY > 1), A_EH)


def a_cracks(L, length_k, base_r):
    for pts in A_CRACKS:
        n = max(1, int(len(pts) * clamp01(length_k)))
        for idx in range(n - 1):
            s0, a0 = pts[idx]
            s1, a1 = pts[idx + 1]
            x0, y0 = to_screen(base_r + s0, a0)
            x1, y1 = to_screen(base_r + s1, a1)
            wide = idx < n * 0.55
            line(L, x0, y0 + 1, x1, y1 + 1, A_EL, 0.66)
            line(L, x0, y0, x1, y1, A_OUT)
            if wide:
                line(L, x0 + 1, y0, x1 + 1, y1, A_OUT)


A_CLODS = []
for _j in range(12):
    A_CLODS.append({
        "th": TAU * _j / 12 + hash01(_j, 3) * 0.5,
        "off": (_j * 5 % 12) / 12.0,
        "turf": _j % 3 == 0,
        "size": 3.0 + (_j % 3) * 0.8,
        "seed": _j,
    })
A_SPIN = 1.5


def a_clod_pos(c, u):
    rho = A_RP + (R - 6 - A_RP) * (1 - u / 0.86) if u < 0.86 else A_RP * (1 - (u - 0.86) / 0.14 * 0.6)
    th = c["th"] + A_SPIN * u
    x, y = to_screen(rho, th)
    if u >= 0.86:
        y += (u - 0.86) / 0.14 * 8
    return x, y


def a_clod(L, c, u, pitmask):
    if u < 0 or u >= 1:
        return
    x, y = a_clod_pos(c, u)
    s = c["size"] * (min(1.0, u / 0.08)) * (1 - 0.35 * clamp01((u - 0.6) / 0.4))
    if s < 1.0:
        return
    falling = u >= 0.86
    # surukleme izi (kisa duz cizgi)
    if not falling and u > 0.06:
        x0, y0 = a_clod_pos(c, u - 0.05)
        line(L, x0, y0 + s * 0.6, x, y + s * 0.6, A_ED, 0.33)
    rx, ry = s, s * 0.8
    m = ell(x - AX, y - AY, rx, ry)
    rng = np.random.default_rng(c["seed"])
    cut = ell(x - AX + rng.uniform(-1, 1) * s, y - AY - s * 0.9, s * 0.7, s * 0.5)
    m = m & ~(cut & (hash01(c["seed"], 7) > 0.5))
    if falling:
        m = m & pitmask
        if not m.any():
            return
        put(L, dilate(m) & ~m & pitmask, A_OUT)
        put(L, m, A_ED if u < 0.93 else A_WALL_DEEP)
        return
    put(L, dilate(m) & ~m, A_OUT)
    if c["turf"]:
        put(L, m, A_EM)
        top = m & (GY + AY < y)
        put(L, top, A_GM)
        put(L, top & ~np.roll(top, 1, axis=0), A_GL)
    else:
        put(L, m, A_EM)
        put(L, m & (GY + AY < y - s * 0.25) & (GX + AX < x + s * 0.2), A_EL)
        put(L, m & ((GY + AY > y + s * 0.3) | (GX + AX > x + s * 0.55)), A_ED)
        px(L, x - s * 0.35, y - s * 0.35, A_EH)


def a_dust_ring(L, rr, lift, size, erode_k, seed=0):
    """Toz halkasi TEK KUTLE: farkli boyda ust uste binen yuvarlaklar birlesir, isik/golge tum kutleden hesaplanir
    (tek tek ayni diskler 'mantar/para yigini' gibi okunur). erode_k: sonme - kutle ustten hilale asinir."""
    if size < 0.8:
        return
    rng = np.random.default_rng(seed)
    m = np.zeros((H, W), bool)
    cut = np.zeros((H, W), bool)
    n = 16
    for j in range(n):
        th = TAU * j / n + rng.uniform(-0.12, 0.12)
        r = size * rng.uniform(0.55, 1.0)
        x, y = to_screen(rr * rng.uniform(0.9, 1.08), th, lift * rng.uniform(0.5, 1.0))
        m |= ell(x - AX, y - AY, r, r * 0.75)
        if erode_k > 0:
            cut |= ell(x - AX + r * 0.3, y - AY - r * (0.35 + 0.5 * erode_k), r * (0.5 + 0.55 * erode_k), r * 0.8)
    m &= ~cut
    if not m.any():
        return
    up = np.roll(m, 2, axis=0)
    put(L, m, A_DUST[1])
    put(L, m & ~up, A_DUST[2])
    put(L, m & ~np.roll(m, 1, axis=0), A_DUST[3])
    put(L, m & ~np.roll(m, -2, axis=0), A_DUST[0])


def a_frame(phase, i):
    g, f = layer(), layer()
    seam = ring1(plane_disc(R - 2))
    if phase == "in":
        t = i / (N_IN - 1)
        k = ease_out(t * 1.15)
        put(g, seam, A_ED, 0.33 if t > 0.4 else 0.0)
        a_cracks(g, ease_out(t * 1.3), A_RR * k)
        a_pit(g, k, t, 0.0)
        a_dust_ring(f, 10 + 40 * ease_out(t), 5 * math.sin(math.pi * t), 6.0 * (1 - t) + 1.0,
                    clamp01((t - 0.35) / 0.65), seed=3)
        if i >= 5:
            pitm = plane_disc(A_RP * k, a_wob)
            for c in A_CLODS:
                a_clod(g, c, ((c["off"]) % 1.0) * min(1.0, (i - 4) / 3.0), pitm)
    elif phase == "loop":
        ph = i / N_LOOP
        put(g, seam, A_ED, 0.33)
        a_cracks(g, 1.0, A_RR)
        a_pit(g, 1.0, 1.0, ph)
        pitm = plane_disc(A_RP, a_wob)
        for c in A_CLODS:
            a_clod(g, c, (ph + c["off"]) % 1.0, pitm)
    else:
        if i < 4:
            k = 1.0 - 0.12 * i / 3
            jit = (1 if i % 2 == 0 else -1) if i > 0 else 0
            put(g, seam, A_ED, 0.33)
            a_cracks(g, 1.0, A_RR * k)
            a_pit(g, k, 1.0 + 0.4 * i / 3, 0.0, jit)
            pitm = plane_disc(A_RP * k, a_wob)
            for c in A_CLODS:
                a_clod(g, c, (c["off"] + 0.12 * i * (1 + i * 0.3)) % 1.0, pitm)
        else:
            u = (i - 4) / 3.0
            a_cracks(g, 1.0 - u, A_RR * (0.6 - 0.3 * u))
            if i == 4:
                a_pit(g, 0.45, 1.5, 0.0)
            elif i == 5:
                a_pit(g, 0.2, 0.0, 0.0)
            # yesil isik sutunu (dik): 4. karede tam, sonra hilale asinir
            if i <= 6:
                hgt = 40 if i == 4 else (30 if i == 5 else 18)
                wb = 7 if i == 4 else (5 if i == 5 else 3)
                col = ell(0, -hgt / 2, wb, hgt / 2) & (GY < 2)
                if i >= 5:
                    col = col & ~ell(-1, -hgt / 2 - 4 * (i - 4), wb * 0.9, hgt / 2)
                put(f, dilate(col) & ~col, A_CG1)
                put(f, col, A_CG2)
                put(f, col & ell(0, -hgt / 2 + 2, max(1, wb - 3), hgt / 2 - 3), A_CG3)
                if i == 4:
                    put(g, ell(0, 0, 14, 7), A_CG2, 0.66)
                    put(g, ell(0, 0, 8, 4), A_CG3)
            # toz halkasi (tek kutle, ustten hilale asinir)
            a_dust_ring(f, 30 + 34 * ease_out(u), 3 * (1 - u), 7.0 * (1 - 0.55 * u), u * 0.9, seed=5)
    return {"ground": g, "front": f}


# ====================================================================== B - YUTAN KURE (havada; isik cizgisi, konturs uz, parlak kenar)
B_VOID = [(26, 8, 44), (66, 26, 116), (124, 64, 204), (184, 136, 255), (238, 218, 255)]
B_BLACK = (6, 2, 10)
B_CREAM = (255, 246, 250)
B_SHADOW = (20, 8, 30)
B_RIB_HI = (212, 186, 255)
B_STREAK_LO = (146, 104, 222)
B_RING = (96, 56, 170)
B_HO = 34.0
B_ORB = 10.0


def b_ground(g, ph, rip_a, ring_a, shadow_k):
    if shadow_k > 0:
        put(g, ell(0, 0, 21 * shadow_k, 8 * shadow_k), B_SHADOW, 0.33)
        put(g, ell(0, 0, 14 * shadow_k, 5.5 * shadow_k), B_SHADOW, 0.66)
    # cizgiler OPAK 1 px (yari saydam lavanta cimende griye doner); sonme = yaya bolunme
    if ring_a > 0:
        rm = ring1(plane_disc((R - 1) * min(1.0, ring_a)))
        put(g, rm, B_RING)
        rot = TAU * ph / 3
        put(g, rm & (((PT - rot) % (TAU / 3)) < 0.55), B_VOID[3])


def b_lane(j, s, rot):
    rho = R * 0.92 * (1 - s) ** 1.35 + B_ORB * 0.6 * s
    h = B_HO * s ** 0.7
    th = TAU * j / 3 + 0.3 + rot + 2.7 * s
    x, y = to_screen(rho, th, h)
    return x, y, th


def b_ribbons(back, front, ph, s_lo, s_hi, width_k=1.0):
    """Yerden kureye 3 sarmal hatta akan ISIK CIZGILERI (kalin tup seritler 'dokunac' gibi okunur - madde 516). Her cizgi
    hiz yonunde kisa, kureye yaklastikca uzar ve parlar; bas pikseli krem. Opak (yari saydam lavanta cimende gri)."""
    rot = TAU * ph / 3
    for j in range(3):
        for k in range(7):
            sh = (ph * 2 + k / 7.0 + j * 0.05) % 1.0
            if sh < s_lo or sh > s_hi:
                continue
            ln = (0.06 + 0.1 * sh) * width_k
            st = max(s_lo, sh - ln)
            pts = [b_lane(j, st + (sh - st) * q / 8.0, rot) for q in range(9)]
            for q in range(8):
                x0, y0, th0 = pts[q]
                x1, y1, _ = pts[q + 1]
                sq = st + (sh - st) * q / 8.0
                dst = back if (sq > 0.6 and math.sin(th0) < 0) else front
                col = B_STREAK_LO if sq < 0.45 else (B_VOID[3] if sq < 0.75 else B_RIB_HI)
                # govde 2 px (alt sira bir ton koyu); kuyrugun son ucte biri ince
                if q >= 3:
                    line(dst, x0, y0 + 1, x1, y1 + 1, B_RING if sq < 0.45 else B_STREAK_LO)
                line(dst, x0, y0, x1, y1, col)
            hx, hy, hth = pts[-1]
            dst = back if (sh > 0.6 and math.sin(hth) < 0) else front
            if sh > 0.5:
                disc_at(dst, hx, hy, 1.2, B_RIB_HI)
            px(dst, hx, hy, B_VOID[4] if sh > 0.3 else B_VOID[3])


def b_orb(L, back, ph, r_k, disk_k, cy_off=0.0):
    ox, oy = 0.0, -B_HO + cy_off
    if r_k <= 0.05:
        return
    r = B_ORB * r_k
    # disk: yatik halka - arka yari kureden once
    if disk_k > 0.05:
        rxo, ryo = 25 * disk_k, 6.5 * disk_k
        rxi, ryi = 14 * disk_k, 3.4 * disk_k
        ann = ell(ox, oy, rxo, ryo) & ~ell(ox, oy, rxi, ryi)
        ang = np.arctan2((GY - oy) / max(ryo, 0.1), (GX - ox) / max(rxo, 0.1))
        rot = TAU * ph * 2
        br = 0.5 + 0.35 * np.cos(ang - rot) + 0.25 * np.cos(ang - math.pi)
        for lo, col in ((-9, B_VOID[1]), (0.35, B_VOID[2]), (0.62, B_VOID[3]), (0.86, B_VOID[4])):
            m = ann & (br >= lo)
            put(back, m & (GY < oy), col)
        disk_front = []
        for lo, col in ((-9, B_VOID[1]), (0.35, B_VOID[2]), (0.62, B_VOID[3]), (0.86, B_VOID[4])):
            disk_front.append((ann & (br >= lo) & (GY >= oy), col))
    else:
        disk_front = []
    # kure + foton halkasi + ustte bukulen disk goruntusu
    orb = ell(ox, oy, r, r)
    halo = ell(ox, oy, r + 1.2, r + 1.2) & ~orb
    put(L, ring1(ell(ox, oy, r + 3.6, r + 3.2)) & (GY < oy - r * 0.35), B_VOID[3], 0.66)
    put(L, halo, B_CREAM)
    put(L, orb, B_BLACK)
    put(L, ring1(orb) & (GY > oy + r * 0.2), (30, 12, 44))
    for m, col in disk_front:
        put(L, m, col)


def b_star(L, x, y, size, core, arm):
    for d in range(1, size + 1):
        a = 1.0 if d < size * 0.6 else 0.66
        for dx, dy in ((d, 0), (-d, 0), (0, d), (0, -d)):
            px(L, x + dx, y + dy, arm, a)
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
        px(L, x + dx, y + dy, core)
    if size >= 6:
        for d in range(1, size // 3 + 1):
            for dx, dy in ((d, d), (-d, d), (d, -d), (-d, -d)):
                px(L, x + dx, y + dy, arm, 0.66)


def b_frame(phase, i):
    g, back, fr = layer(), layer(), layer()
    ox, oy = AX, AY - B_HO
    if phase == "in":
        t = i / (N_IN - 1)
        e = ease_out(t)
        h_off = B_HO * (1 - e)
        b_ground(g, 0.0, 1.0 if i >= 5 else 0.0, e, e)
        if i <= 2:
            b_star(fr, AX, AY - 2 - 6 * t, 7 - 2 * i, B_CREAM, B_VOID[3])
        if i >= 4:
            b_ribbons(back, fr, 0.0, 1.0 - (i - 3) / 4.0, 1.0)
        b_orb(fr, back, 0.0, 0.2 + 0.8 * e, ease_out((i - 2) / 5.0) if i >= 3 else 0.0, h_off)
    elif phase == "loop":
        ph = i / N_LOOP
        b_ground(g, ph, 1.0, 1.0, 1.0)
        b_ribbons(back, fr, ph, 0.0, 1.0)
        b_orb(fr, back, ph, 1.0, 1.0)
    else:
        if i < 4:
            u = i / 4.0
            b_ground(g, 0.0, 1.0 - u, 1.0, 1.0 - 0.3 * u)
            b_ribbons(back, fr, 0.0, 0.25 * (i + 1), 1.0, 1.0 - 0.15 * i)
            b_orb(fr, back, 0.0, 1.0 - 0.18 * i, 1.0 - 0.28 * i)
        else:
            u = (i - 4) / 3.0
            rr = 22 + (R - 26) * ease_out(u)
            rm = ring1(plane_disc(rr))
            if u > 0:
                gaps = ((PT * 3 + 0.5) % TAU) < TAU * 0.45 * u
                rm = rm & ~gaps
            put(g, rm, B_CREAM if i == 4 else B_VOID[3], 1.0 if i < 6 else 0.66)
            if i == 4:
                put(g, ring1(plane_disc(rr - 2)), B_VOID[3], 0.66)
                put(fr, ell(0, -B_HO, 6, 6), B_CREAM)
                b_star(fr, ox, oy, 13, B_CREAM, B_VOID[3])
            else:
                for j in range(6):
                    a = TAU * j / 6 + 0.4
                    d0 = 6 + 13 * (i - 4)
                    x0, y0 = ox + d0 * math.cos(a), oy + d0 * math.sin(a) * 0.8
                    x1, y1 = ox + (d0 + 5 - (i - 5) * 2) * math.cos(a), oy + (d0 + 5 - (i - 5) * 2) * math.sin(a) * 0.8
                    line(fr, x0, y0, x1, y1, B_VOID[4] if i == 5 else B_VOID[3], 1.0 if i < 7 else 0.66)
                if i == 5:
                    b_star(fr, ox, oy, 6, B_CREAM, B_VOID[3])
    comp(back, fr)
    return {"ground": g, "front": back}


# ====================================================================== C - HICLIK GIRDABI (zeminde, konturs uz, duz yari saydam bantlar)
C_ARM_D = (34, 14, 56)
C_ARM_M = (68, 32, 108)
C_ARM_L = (118, 68, 178)
C_RIM = (188, 150, 240)
C_VOIDC = (8, 3, 14)
C_G1 = (54, 124, 28)
C_G2 = (112, 194, 46)
C_G3 = (220, 255, 180)
C_LEAF = [((120, 92, 40), (196, 156, 70)), ((96, 124, 40), (170, 196, 72)), ((100, 62, 34), (164, 112, 62))]
C_LEAF_OUT = (26, 34, 18)
C_K = 2.3
C_VR = 17.0


C_ARMS = 5


def c_arms(L, reach, rot, wk=1.0):
    """C_ARMS ince logaritmik kol; ic (on) kenari parlak 1 px cizgi, govde ACIK ton yari saydam (koyu yari saydam
    cimende camur gibi), merkeze yaklastikca kalinlasip koyulasir."""
    if reach < 6:
        return
    per = TAU / C_ARMS
    inside = (PR <= reach) & (PR > C_VR * 0.6)
    lr = np.log(np.maximum(PR, 1.0) / R)
    s = (PT - C_K * lr - rot) % per / per
    e = PR / reach
    w = (0.16 + 0.22 * (1 - e)) * wk * np.clip((1 - e) / 0.3, 0, 1) ** 0.8
    # kol genisligi piksel olarak cok inceyse cizme (uc kirintilari yok)
    w = np.where(w * per * PR * 0.7 < 1.6, 0.0, w)
    arm = inside & (s < w)
    lead = arm & ~np.roll(arm, 1, axis=1) & ~np.roll(arm, 1, axis=0)
    lead = arm & (s < np.maximum(0.035, w * 0.18))
    # govde = zemine dusen KOYU oluk (koyu mor-lacivert yari saydam -> cimen golgesi gibi koyulasir, gri olmaz)
    put(L, arm, C_ARM_D, 0.33)
    put(L, arm & (e < 0.45), C_ARM_D, 0.66)
    put(L, lead & (e < 0.85), C_RIM, 1.0)
    put(L, lead & (e >= 0.85), C_RIM, 0.66)


def c_void(L, k, glow):
    if k <= 0.05:
        return
    vr = C_VR * k
    vm = plane_disc(vr)
    put(L, plane_disc(vr + 5) & ~vm, C_ARM_D, 0.66)
    put(L, vm, C_VOIDC)
    put(L, ring1(vm), C_G2 if glow < 1.0 else C_G3)
    put(L, ring1(vm) & (GY < 0), C_G1)
    put(L, ring1(plane_disc(vr - 3)) & (GY > 0), C_G1, 0.66)


C_LEAVES = []
for _j in range(9):
    C_LEAVES.append({"th": TAU * _j / 9 + hash01(_j, 9) * 0.6, "off": (_j * 4 % 9) / 9.0, "kind": _j % 3})


def c_leaf_pos(lf, u, reach=R):
    rho = (reach - 4) * math.exp(-2.1 * u) * (1 - 0.15 * u)
    th = lf["th"] + C_K * 2.1 * u * 0.55
    return to_screen(rho, th), rho


def c_leaf(L, lf, u, reach=R):
    if u < 0 or u >= 1:
        return
    (x, y), rho = c_leaf_pos(lf, u, reach)
    if rho < C_VR + 1:
        return
    dark, light = C_LEAVES_COL(lf)
    # takla atan yaprak: yatay / capraz / dik elips, 1 px koyu kontur, ust yari acik
    flip = int(u * 10 + lf["kind"]) % 3
    rx, ry = ((3.0, 1.6), (2.4, 2.0), (1.6, 2.6))[flip]
    m = ell(x - AX, y - AY, rx, ry)
    put(L, dilate(m) & ~m, C_LEAF_OUT)
    put(L, m, dark)
    put(L, m & (GY + AY < y), light)


def C_LEAVES_COL(lf):
    return C_LEAF[lf["kind"]]


def c_star(L, x, y, size, core, arm):
    for d in range(1, size + 1):
        a = 1.0 if d <= size // 2 else 0.66
        for dx, dy in ((d, 0), (-d, 0), (0, d * 0.5), (0, -d)):
            px(L, x + dx, y + dy, arm, a)
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1)):
        px(L, x + dx, y + dy, core)


def c_frame(phase, i):
    g = layer()
    if phase == "in":
        t = i / (N_IN - 1)
        e = ease_out(t)
        c_arms(g, R * e, -TAU * 0.35 * (1 - e) ** 2)
        c_void(g, min(1.0, 0.3 + e), 1.0 if i < 3 else 0.0)
        if i < 3:
            c_star(g, AX, AY - 1, 6 - 2 * i, C_G3, C_G2)
        if i >= 5:
            for lf in C_LEAVES:
                c_leaf(g, lf, lf["off"] * (i - 4) / 3.0)
    elif phase == "loop":
        ph = i / N_LOOP
        c_arms(g, R, TAU / C_ARMS * ph)
        c_void(g, 1.0, 0.0)
        for lf in C_LEAVES:
            c_leaf(g, lf, (ph + lf["off"]) % 1.0)
    else:
        if i < 4:
            u = i / 4.0
            reach = R * (1 - 0.72 * ease_in(u + 0.25))
            c_arms(g, reach, TAU / 3 * u * 1.5, 1.0 + 0.3 * u)
            c_void(g, 1.0 - 0.15 * u, u)
            for lf in C_LEAVES:
                c_leaf(g, lf, (lf["off"] + 0.2 * i) % 1.0, max(reach, C_VR + 6))
        else:
            u = (i - 4) / 3.0
            if i == 4:
                put(g, plane_disc(14), C_G2, 0.66)
                put(g, plane_disc(8), C_G3)
                c_star(g, AX, AY - 1, 12, (255, 255, 255), C_G2)
            rr = 18 + (R - 22) * ease_out(u * 1.1)
            rm = ring1(plane_disc(rr)) | ring1(plane_disc(rr - 2))
            if u > 0:
                rm = rm & ~(((PT * 2 + 1.0) % TAU) < TAU * 0.5 * u)
            put(g, rm, C_G2 if i < 6 else C_ARM_L, 1.0 if i < 6 else 0.66)
            if 4 < i < 7:
                for lf in C_LEAVES:
                    th = lf["th"] + 1.0
                    rho = 22 + 26 * (i - 4) + lf["kind"] * 4
                    x, y = to_screen(rho, th)
                    dark, light = C_LEAVES_COL(lf)
                    px(g, x, y, light)
                    px(g, x + 1, y, dark)
    return {"ground": g}


# ====================================================================== kaydet + onizleme
PROTOS = {"A": a_frame, "B": b_frame, "C": c_frame}


def build(code):
    fn = PROTOS[code]
    frames = []
    for ph, n in (("in", N_IN), ("loop", N_LOOP), ("out", N_OUT)):
        for i in range(n):
            frames.append(fn(ph, i))
    layers = [k for k in frames[0].keys() if any(f[k][:, :, 3].any() for f in frames)]
    os.makedirs(SHEETS, exist_ok=True)
    edge = []
    for lname in layers:
        s = np.zeros((H, W * len(frames), 4), dtype=np.uint8)
        for n, f in enumerate(frames):
            a = f[lname]
            if a[0, :, 3].any() or a[-1, :, 3].any() or a[:, 0, 3].any() or a[:, -1, 3].any():
                edge.append((lname, n))
            s[:, n * W:(n + 1) * W] = a
        Image.fromarray(s, "RGBA").save(os.path.join(SHEETS, "%s_%s.png" % (code, lname)))
    meta = {"w": W, "h": H, "ax": AX, "ay": AY, "world_px": WORLD_PX, "layers": layers,
            "n_in": N_IN, "n_loop": N_LOOP, "n_out": N_OUT, "fps_in": FPS_IN, "fps_loop": FPS_LOOP, "fps_out": FPS_OUT}
    with open(os.path.join(SHEETS, code + ".json"), "w", encoding="utf-8") as fh:
        json.dump(meta, fh)
    print("  %s katman=%s kare=%d kenar=%s" % (code, layers, len(frames), edge[:4] if edge else "temiz"))
    return frames, layers


def preview(all_frames):
    pick = [("in", 2), ("in", 5), ("loop", 0), ("loop", 10), ("loop", 21), ("out", 2), ("out", 4), ("out", 5), ("out", 7)]
    idx = {"in": 0, "loop": N_IN, "out": N_IN + N_LOOP}
    S = 2
    bg = (78, 128, 58)
    rows = []
    for code, (frames, layers) in all_frames.items():
        row = Image.new("RGB", (W * S * len(pick), H * S), bg)
        for n, (ph, k) in enumerate(pick):
            f = frames[idx[ph] + k]
            im = Image.new("RGBA", (W, H), bg + (255,))
            for lname in ("ground", "front"):
                if lname in layers:
                    im.alpha_composite(Image.fromarray(f[lname], "RGBA"))
            row.paste(im.convert("RGB").resize((W * S, H * S), Image.NEAREST), (n * W * S, 0))
        rows.append(row)
    out = Image.new("RGB", (rows[0].width, sum(r.height for r in rows)), bg)
    y = 0
    for r in rows:
        out.paste(r, (0, y))
        y += r.height
    out.save(os.path.join(OUT, "sanat_onizleme.png"))


def main():
    import sys
    codes = sys.argv[1:] or list(PROTOS)
    allf = {}
    for c in codes:
        allf[c] = build(c)
    preview(allf)
    print("tamam")


if __name__ == "__main__":
    main()
