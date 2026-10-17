"""ŞOVALYE E (Koruma Bariyeri) - "dostun hasarını emme" anı için yeni pixel efekt prototipleri (kullanıcı 2026-10-14:
"şovalye adamın E yeteneğinin arkadaşlarının hasarını emmesiyle ilgili yeni bir pixel efekt ... hiç hasarlarını emiyormuş
gibi hissettirmiyor").

Kök sorun: oyundaki iki E görseli (dostta guard_bubble, Şovalye'de guard_absorb) SÜREKLİ döngü - darbe gelse de gelmese de
aynı oynuyor; hasar aktarıldığı AN (player.gd take_damage -> sync_redirected_damage) hiçbir şey görünmüyor, dosttan
Şovalye'ye giden bir şey yok. Bu prototipler o ANI gösterir (dört aile, aynı zaman çizelgesi: tek darbe, çift darbe,
büyük darbe):
  A Hasar Kırıntıları - darbe noktasından kırmızı kırıntılar kopar, yay çizerek Şovalye'ye uçar, yolda mora döner
  B Bağ Işını         - E boyunca ikisi arasında ince, Şovalye'ye doğru akan bağ; her darbede bağ boyunca ışık topu koşar
  C Kalkan Yakalar    - darbe noktasında Şovalye'nin kalkan mührü belirir, darbeyi kapar, Şovalye'ye fırlar ve çarpar
  D Yankı Darbesi     - anlık enerji yayı + aynı darbe Şovalye'nin üstünde de patlar

    python -I tools/proto_20261014/sovalye_e_emilim_proto.py   -> out/sovalye_e_emilim_A-D.gif (+ --kareler)
Çizim karakter pikseli ölçeğinde (1 sanat px = 1 Şovalye pikseli = ~0,9 dünya birimi); dost ile Şovalye arası ~80 dünya.
Dosttaki soluk halka = mevcut guard_bubble'ın sadeleştirilmiş hali (bağlam için).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, '..')))
import gen_cadi_fx as G  # noqa: E402

TAU = 2.0 * math.pi
W, H = 190, 86
Z = 3
FPS = 15
DUR = 4.4
AF = (52, 74)            # dostun ayak noktası
KF = (142, 62)           # Şovalye'nin ayak noktası
A = np.array([AF[0], AF[1] - 16.0])   # dostun gövde ortası
K = np.array([KF[0], KF[1] - 16.0])   # Şovalye'nin gövde ortası
BUB_R = 21               # mevcut baloncuk yarıçapı (20,6 dünya)

V_OUT = (26, 20, 70)
V_DEEP = (44, 40, 128)
V_IND = (78, 82, 214)
V_BLUE = (112, 142, 255)
V_LAV = (170, 140, 255)
V_PALE = (206, 216, 255)
V_WHITE = (242, 244, 255)
R_OUT = (70, 14, 28)
R_DEEP = (150, 34, 52)
R_MID = (228, 64, 60)
R_LIGHT = (255, 142, 110)
R_PALE = (255, 226, 200)
CREAM = (255, 250, 228)
ORB = [(90, 20, 12), (200, 60, 24), (255, 150, 60), (255, 230, 170)]

# (çarpma anı, saldırganın yönü (ekran açısı, y aşağı), güç 1 = normal 2 = büyük)
HITS = [(0.55, math.pi, 1), (1.7, -2.35, 1), (1.98, 2.45, 1), (3.15, math.pi + 0.25, 2)]


# ------------------------------------------------------------------ çizim yardımcıları
def qa(a):
    for lv in (1.0, 0.8, 0.55, 0.3):
        if a >= lv - 0.12:
            return lv
    return 0.0


def layer():
    return np.zeros((H, W, 4), np.float32)


def px(L, x, y, col, a=1.0, force=False):
    x, y = int(round(x)), int(round(y))
    if not (0 <= x < W and 0 <= y < H):
        return
    a = qa(a)
    if a <= 0:
        return
    if force or a >= L[y, x, 3]:
        L[y, x, :3] = col
        L[y, x, 3] = a


def dil(m):
    o = m.copy()
    o[1:] |= m[:-1]
    o[:-1] |= m[1:]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    return o


def outline(L, col=V_OUT, thr=0.75, a=0.85):
    m = L[:, :, 3] >= thr
    ring = dil(m) & ~m & (L[:, :, 3] < 0.3)
    L[ring, :3] = col
    L[ring, 3] = a


def halo(L, col=V_LAV, thr=0.75):
    """Büyü parıltısı: parlak piksellerin çevresine 1 px soluk hale."""
    m = L[:, :, 3] >= thr
    ring = dil(m) & ~m & (L[:, :, 3] == 0)
    L[ring, :3] = col
    L[ring, 3] = 0.3


def comp(dst, L):
    a = L[:, :, 3:4]
    dst[:] = (dst.astype(np.float32) * (1 - a) + L[:, :, :3] * a + 0.5).astype(np.uint8)


def ramp(cols, t):
    t = max(0.0, min(1.0, t))
    n = len(cols) - 1
    i = min(n - 1, int(t * n))
    f = t * n - i
    a, b = cols[i], cols[i + 1]
    return tuple(int(round(a[k] + (b[k] - a[k]) * f)) for k in range(3))


def ease_in_out(u):
    return u * u * (3 - 2 * u)


def bez3(p0, p1, p2, p3, u):
    v = 1 - u
    return p0 * v ** 3 + 3 * p1 * v * v * u + 3 * p2 * v * u * u + p3 * u ** 3


def bez2(p0, p1, p2, u):
    v = 1 - u
    return p0 * v * v + 2 * p1 * v * u + p2 * u * u


def ring(L, c, r, col, a, ry=None, a0=0.0, a1=TAU):
    ry = r if ry is None else ry
    n = max(16, int(TAU * max(r, 1) * 1.5))
    for i in range(n):
        ang = TAU * i / n
        d = (ang - a0) % TAU
        if d > (a1 - a0) % TAU and (a1 - a0) < TAU - 1e-6:
            continue
        px(L, c[0] + r * math.cos(ang), c[1] + ry * math.sin(ang), col, a)


def plus(L, c, col_core, col_arm, a=1.0, arm=1):
    for k in range(1, arm + 1):
        for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            px(L, c[0] + dx, c[1] + dy, col_arm, a * (1.0 if k == 1 else 0.55))
    px(L, c[0], c[1], col_core, a, force=True)


def hit_dir(ang):
    return np.array([math.cos(ang), math.sin(ang)])


def impact_pt(ang):
    return A + hit_dir(ang) * 7


SHIELD = [
    "..#####..",
    ".#######.",
    "#########",
    "#########",
    "#########",
    "#########",
    ".#######.",
    ".#######.",
    "..#####..",
    "...###...",
    "....#....",
]


def shield_mask(big=False):
    m = np.array([[c == '#' for c in row] for row in SHIELD])
    w, h = (14, 17) if big else (11, 13)
    im = Image.fromarray(m.astype(np.uint8) * 255).resize((w, h), Image.NEAREST)
    return np.array(im) > 127


def draw_shield(L, c, a, big=False, flash=0.0, red=0.0):
    """Kalkan mührü: koyu kontur, mavi gövde, sol üst parlama, ortada dikey parlak çizgi."""
    m = shield_mask(big)
    h, w = m.shape
    x0, y0 = int(round(c[0] - w / 2)), int(round(c[1] - h / 2))
    edge = m & ~(np.pad(m, 1)[2:, 1:-1] & np.pad(m, 1)[:-2, 1:-1] & np.pad(m, 1)[1:-1, 2:] & np.pad(m, 1)[1:-1, :-2])
    for yy in range(h):
        for xx in range(w):
            if not m[yy, xx]:
                continue
            if edge[yy, xx]:
                col = V_LAV
            elif xx < w * 0.45 and yy < h * 0.4:
                col = V_PALE
            elif abs(xx - (w - 1) / 2) < 0.6:
                col = V_WHITE
            else:
                col = V_IND if yy > h * 0.55 else V_BLUE
            if red > 0:
                dd = math.hypot(xx - (w - 1) / 2, yy - h * 0.42)
                if dd < 1.0 + 1.6 * red:
                    col = R_PALE if dd < 0.8 else (R_LIGHT if dd < 1.8 else R_MID)
            if flash > 0:
                col = ramp([col, V_WHITE], flash)
            px(L, x0 + xx, y0 + yy, col, a, force=True)


# ------------------------------------------------------------------ ortak sahne ögeleri
def projectile(L, t):
    for (th, ang, s) in HITS:
        age = t - th
        if not (-0.3 <= age < 0.0):
            continue
        d = hit_dir(ang)
        P = impact_pt(ang)
        for k in range(7):
            q = (-age + k * 0.018) / 0.3
            pos = P + d * (q * 44)
            if k == 0:
                for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                    px(L, pos[0] + dx, pos[1] + dy, ORB[3] if (dx, dy) == (0, 0) else ORB[2], 1.0, force=True)
                if s > 1:
                    for dx, dy in ((-1, 0), (2, 0), (0, -1), (0, 2), (-1, 1), (2, 1), (1, -1), (1, 2)):
                        px(L, pos[0] + dx, pos[1] + dy, ORB[1], 1.0)
            else:
                px(L, pos[0], pos[1], ORB[2] if k < 3 else ORB[1], 1.0 - k * 0.13)


def impact(L, t, center_fn=impact_pt, tint=None, delay=0.0):
    for (th, ang, s) in HITS:
        age = t - th - delay
        if not (0.0 <= age < 0.18):
            continue
        c = center_fn(ang)
        p = age / 0.18
        reach = 2 + (3 if s > 1 else 2) * p
        core = CREAM if tint is None else tint[0]
        arm = ORB[2] if tint is None else tint[1]
        for k in range(8):
            ang2 = TAU * k / 8 + 0.4
            ln = reach if k % 2 == 0 else reach * 0.6
            for r in np.arange(1, ln + 0.01, 1.0):
                px(L, c[0] + r * math.cos(ang2), c[1] + r * math.sin(ang2), arm, 1.0 - p)
        if p < 0.5:
            plus(L, c, core, arm, 1.0, arm=2 if s > 1 else 1)


def bubble(L, t, flash_fn=None):
    """Mevcut guard_bubble'ın sadeleştirilmiş hali: soluk halka + dönen parıltı yayı (bağlam)."""
    ring(L, A, BUB_R, V_LAV, 0.3)
    th = t * TAU / 2.4
    for i in range(18):
        ang = th + i * 0.05
        px(L, A[0] + BUB_R * math.cos(ang), A[1] + BUB_R * math.sin(ang), V_PALE, 0.55)
        ang = th + math.pi + i * 0.05
        px(L, A[0] + BUB_R * math.cos(ang), A[1] + BUB_R * math.sin(ang), V_PALE, 0.55)


def bubble_hit_arc(L, t, span=0.7, life=0.25, delay=0.0):
    for (th, ang, s) in HITS:
        age = t - th - delay
        if not (0.0 <= age < life):
            continue
        a = 1.0 - age / life
        for i in range(-12, 13):
            g = ang + span * i / 12
            col = V_WHITE if abs(i) < 5 else V_PALE
            px(L, A[0] + BUB_R * math.cos(g), A[1] + BUB_R * math.sin(g), col, a * (1.0 if abs(i) < 8 else 0.6), force=True)
            px(L, A[0] + (BUB_R - 1) * math.cos(g), A[1] + (BUB_R - 1) * math.sin(g), V_LAV, a * 0.55)


def knight_arrival(L, t, arrivals, big_r=10):
    """Şovalye'nin göğsünde emilim: beyaz çekirdek + dışa açılan halka. arrivals = [(an, güç)]."""
    tint = 0.0
    for (ta, s) in arrivals:
        age = t - ta
        if not (0.0 <= age < 0.3):
            continue
        p = age / 0.3
        r = 2 + (big_r if s > 1 else big_r * 0.7) * p
        ring(L, K, r, V_PALE if p < 0.4 else V_LAV, 1.0 - p)
        if p < 0.35:
            plus(L, K, V_WHITE, V_PALE, 1.0, arm=2 if s > 1 else 1)
        tint = max(tint, (0.55 if s > 1 else 0.4) * (1 - age / 0.14) if age < 0.14 else 0.0)
    return tint


# ------------------------------------------------------------------ A - Hasar Kırıntıları
class FamA:
    name = 'A - Hasar Kirintilari'
    FL = 0.5

    def draw(self, under, over, solid, t):
        bubble(under, t)
        bubble_hit_arc(over, t, life=0.2)
        arrivals = []
        for (th, ang, s) in HITS:
            d = hit_dir(ang)
            perp = np.array([-d[1], d[0]])
            P = impact_pt(ang)
            n = 5 if s == 1 else 9
            for i in range(n):
                t0 = th + 0.04 + i * 0.03
                arrivals.append((t0 + self.FL, s if i == n - 1 else 1))
                age = t - t0
                spread = (i - (n - 1) / 2) / max(1.0, (n - 1) / 2)
                # önce darbe yönüne fırlar (yaradan kopma), sonra yay çizip Şovalye'ye döner
                P1 = P + d * 16 + perp * spread * 12
                P2 = K + np.array([-18.0, -24.0 + spread * 10])
                for k in range(8):
                    u = (age - k * 0.024) / self.FL
                    if not (0.0 <= u <= 1.0):
                        continue
                    pos = bez3(P, P1, P2, K, ease_in_out(u))
                    col = ramp([R_MID, R_LIGHT, V_LAV, V_PALE, V_WHITE], u)
                    if k == 0:
                        if u > 0.97:
                            continue
                        big = s > 1 and i % 2 == 0
                        r = 2 if big else 1
                        for dx in range(-r, r + 1):
                            for dy in range(-r, r + 1):
                                if abs(dx) + abs(dy) > r:
                                    continue
                                c2 = ramp([col, V_WHITE if u > 0.45 else R_PALE], 0.7) if (dx, dy) == (0, 0) else col
                                px(solid, pos[0] + dx, pos[1] + dy, c2, 1.0, force=True)
                    else:
                        a = (1.0 - k / 8) * 0.95
                        px(over, pos[0], pos[1], col, a)
                        if k < 4:
                            px(over, pos[0], pos[1] + 1, col, a * 0.8)
        tint = knight_arrival(over, t, arrivals, big_r=11)
        outline(solid, R_OUT)
        halo(over)
        return tint, 0.0


# ------------------------------------------------------------------ B - Bağ Işını
class FamB:
    name = 'B - Bag Isini'
    TRAVEL = 0.32

    def __init__(self):
        ctrl = (K + A) / 2 + np.array([0.0, 16.0])
        us = np.linspace(0, 1, 600)
        pts = np.array([bez2(K, ctrl, A, u) for u in us])
        seg = np.hypot(*(pts[1:] - pts[:-1]).T)
        self.cum = np.concatenate([[0], np.cumsum(seg)])
        self.pts = pts
        # bağ dostun baloncuk kenarında biter
        dist = np.hypot(*(pts - A).T)
        idx = np.argmax(dist < BUB_R + 0.5)
        self.L_end = self.cum[idx]
        self.L_start = 5.0

    def at(self, s):
        i = int(np.searchsorted(self.cum, s))
        i = max(0, min(len(self.pts) - 1, i))
        return self.pts[i]

    def draw(self, under, over, solid, t):
        bubble(under, t)
        bubble_hit_arc(over, t)
        pulses = []
        arrivals = []
        boost = 0.0
        for (th, ang, s) in HITS:
            t0 = th + 0.06
            arrivals.append((t0 + self.TRAVEL, s))
            age = t - t0
            if -0.06 <= age < self.TRAVEL + 0.18:
                boost = max(boost, 1.0 if age < self.TRAVEL else 1.0 - (age - self.TRAVEL) / 0.18)
            if 0.0 <= age < self.TRAVEL:
                u = (age / self.TRAVEL) ** 1.5
                pulses.append((self.L_end - (self.L_end - self.L_start) * u, s))
        # bağ: Şovalye'ye doğru akan kesik çizgi, iki ucu incelir
        span = self.L_end - self.L_start
        for si in range(int(self.L_start), int(self.L_end) + 1):
            s_ = float(si)
            p = self.at(s_)
            taper = min(1.0, (s_ - self.L_start) / 8.0, (self.L_end - s_) / 5.0)
            on = ((s_ + t * 22.0) % 6.0) < 3.5
            base = (0.6 if on else 0.3) * taper
            a = base + (0.95 - base) * boost * taper
            col = V_LAV if not boost else ramp([V_LAV, V_PALE], boost * 0.6)
            px(under, p[0], p[1] + 1, V_DEEP, a * 0.45)
            px(over, p[0], p[1], col, a)
            if boost > 0.3:  # darbe anında bağ kalınlaşır (gerilir)
                px(over, p[0], p[1] - 1, V_LAV, a * 0.7 * boost)
        # bağın iki ucundaki düğümler
        e = self.at(self.L_end)
        plus(over, e, V_PALE, V_LAV, 0.8)
        # ışık topları (kuyruklu)
        for (sp, s) in pulses:
            tail = 20 if s > 1 else 15
            for k in range(1, tail):
                q = self.at(min(self.L_end, sp + k))
                f = 1.0 - k / tail
                px(solid, q[0], q[1], V_WHITE if k < 4 else V_PALE, f, force=True)
                if k < tail * 0.6:
                    px(solid, q[0], q[1] - 1, V_PALE if k < 5 else V_LAV, f * 0.9, force=True)
                    if s > 1:
                        px(solid, q[0], q[1] + 1, V_LAV, f * 0.8, force=True)
            c = self.at(sp)
            r = 3 if s > 1 else 2
            for dx in range(-r, r + 1):
                for dy in range(-r, r + 1):
                    if abs(dx) + abs(dy) > r:
                        continue
                    col = V_WHITE if abs(dx) + abs(dy) <= r - 1 else V_PALE
                    px(solid, c[0] + dx, c[1] + dy, col, 1.0, force=True)
            ring(over, c, r + 2, V_LAV, 0.55)
        tint = 0.0
        for (ta, s) in arrivals:
            age = t - ta
            if 0.0 <= age < 0.32:
                p = age / 0.32
                sh = np.array([K[0], K[1] - 1.0])
                if p < 0.75:
                    draw_shield(solid, sh, 1.0, big=s > 1, flash=max(0.0, 1.0 - p * 4))
                ring(over, K, 4 + (10 if s > 1 else 7) * p, V_PALE if p < 0.4 else V_LAV, 1.0 - p)
                tint = max(tint, 0.45 * (1 - age / 0.14) if age < 0.14 else 0.0)
        outline(solid, V_OUT)
        halo(over)
        return tint, 0.0


# ------------------------------------------------------------------ C - Kalkan Yakalar
class FamC:
    name = 'C - Kalkan Yakalar'
    CATCH = 0.14
    FLY = 0.42

    def draw(self, under, over, solid, t):
        bubble(under, t)
        arrivals = []
        for (th, ang, s) in HITS:
            d = hit_dir(ang)
            P = A + d * 13
            age = t - th
            big = s > 1
            t_arr = th + self.CATCH + self.FLY
            arrivals.append((t_arr, s))
            if 0.0 <= age < self.CATCH:
                p = age / self.CATCH
                pop = 1.0 if p > 0.3 else 0.7
                draw_shield(solid, P, 1.0, big=big and pop > 0.8, flash=max(0.0, 1.0 - p * 2.5), red=0.7 * min(1.0, p * 2))
                # darbenin içine çekilen kırmızı zerreler
                for k in range(5):
                    g = ang + (k - 2) * 0.5
                    r = 9 * (1 - p)
                    px(over, P[0] + r * math.cos(g), P[1] + r * math.sin(g), R_LIGHT, 1.0 - p * 0.5)
            fl = (age - self.CATCH) / self.FLY
            if 0.0 <= fl < 1.0:
                P1 = P + np.array([0.0, -24.0])
                P2 = K + np.array([-10.0, -26.0])
                for g in range(3, 0, -1):  # ardıl görüntüler
                    ug = max(0.0, fl - g * 0.07)
                    pos = bez3(P, P1, P2, K, ease_in_out(ug) ** 1.2)
                    m = shield_mask(big)
                    for (yy, xx) in zip(*np.nonzero(m)):
                        if (xx + yy + g) % 2 == 0:
                            px(over, pos[0] - m.shape[1] / 2 + xx, pos[1] - m.shape[0] / 2 + yy, V_LAV, 0.55 - g * 0.12)
                pos = bez3(P, P1, P2, K, ease_in_out(fl) ** 1.2)
                draw_shield(solid, pos, 1.0, big=big, red=0.7 * (1.0 - fl))
        tint = 0.0
        for (ta, s) in arrivals:
            age = t - ta
            if not (0.0 <= age < 0.4):
                continue
            p = age / 0.4
            if p < 0.12:
                draw_shield(solid, K, 1.0, big=s > 1, flash=1.0)
            # kalkan parçalanır: dışa uçan mavi parçalar
            n = 8 if s > 1 else 6
            for k in range(n):
                g = TAU * k / n + 0.3
                r = 3 + (12 if s > 1 else 9) * (1 - (1 - p) ** 2)
                c = K + np.array([math.cos(g), math.sin(g) * 0.8]) * r
                col = ramp([V_PALE, V_BLUE, V_IND], p)
                px(solid, c[0], c[1], col, 1.0 - p, force=True)
                if p < 0.5:
                    px(solid, c[0] + 1, c[1], col, 1.0 - p, force=True)
            ring(over, K, 3 + (12 if s > 1 else 9) * p, V_PALE if p < 0.3 else V_LAV, (1.0 - p) * 0.8)
            tint = max(tint, 0.6 * (1 - age / 0.16) if age < 0.16 else 0.0)
        outline(solid, V_OUT)
        halo(over)
        return tint, 0.0


# ------------------------------------------------------------------ D - Yankı Darbesi
class FamD:
    name = 'D - Yanki Darbesi'
    LIFE = 0.32
    DELAY = 0.03

    def draw(self, under, over, solid, t):
        bubble(under, t)
        bubble_hit_arc(over, t, life=0.2)
        tint = 0.0
        for (th, ang, s) in HITS:
            age = t - th - self.DELAY
            if not (0.0 <= age < self.LIFE):
                continue
            p = age / self.LIFE
            # yay baloncuğun Şovalye'ye bakan üst kenarından çıkar, dostun gövdesini kesmez
            to_k = math.atan2(K[1] - A[1], K[0] - A[0]) - 0.6
            P = A + np.array([math.cos(to_k), math.sin(to_k)]) * BUB_R
            mid = (P + K) / 2
            dv = K - P
            perp = np.array([dv[1], -dv[0]]) / np.hypot(*dv)
            ctrl = mid + perp * (16 if perp[1] < 0 else -16)
            n = 160
            lo = 0.5 * max(0.0, (p - 0.35) / 0.65)
            for i in range(n + 1):
                u = i / n
                if u < lo or u > 1 - lo:
                    continue
                q = bez2(P, ctrl, K, u)
                wob = math.sin(u * 22 - t * 40) * (1.0 if p < 0.4 else 0.5)
                q = q + perp * wob
                end = min(1.0, (u - lo) * 14, (1 - lo - u) * 14)
                if p < 0.18:
                    px(solid, q[0], q[1], V_WHITE, end, force=True)
                    px(over, q[0] + perp[0], q[1] + perp[1], V_PALE, end)
                    px(over, q[0] - perp[0], q[1] - perp[1], V_PALE, end)
                elif p < 0.45:
                    px(solid, q[0], q[1], V_PALE, end * 0.95)
                    if (i // 3) % 2 == 0:
                        px(over, q[0] + perp[0], q[1] + perp[1], V_LAV, end * 0.55)
                else:
                    if ((i + int(p * 30)) // 4) % 3 != 2:
                        px(over, q[0], q[1], V_LAV, end * (1.0 - p) * 1.6)
            # yay boyunca savrulan kıvılcımlar
            for k in range(5):
                u = (k + 0.5) / 5
                q = bez2(P, ctrl, K, u) + perp * (2 + 6 * p) * (1 if k % 2 else -1)
                px(over, q[0], q[1], V_PALE, 1.0 - p)
            tint = max(tint, (0.35 if s > 1 else 0.25) * max(0.0, 1 - age / 0.12))
        # aynı darbe Şovalye'de de patlar (mor tonlu)
        impact(solid, t, center_fn=lambda ang: K + hit_dir(ang) * 7, tint=(V_WHITE, V_LAV), delay=self.DELAY + 0.02)
        for (th, ang, s) in HITS:
            age = t - th - self.DELAY - 0.02
            if 0.0 <= age < 0.28:
                p = age / 0.28
                ring(over, K + hit_dir(ang) * 7, 2 + (8 if s > 1 else 6) * p, V_PALE if p < 0.4 else V_LAV, 1.0 - p)
        halo(over)
        return tint, 0.0


FAMILIES = [FamA(), FamB(), FamC(), FamD()]


# ------------------------------------------------------------------ sahne
def tinted(frame, k, col=V_PALE):
    if k <= 0:
        return frame
    f = frame.astype(np.float32).copy()
    m = f[:, :, 3] > 0
    f[m, :3] = f[m, :3] * (1 - k) + np.array(col, np.float32) * k
    return f.astype(np.uint8)


def ally_frame(sheets, t):
    idle, hurt = sheets
    for (th, _a, _s) in HITS:
        if 0.0 <= t - th < 0.28:
            return hurt[2][0 if t - th < 0.14 else 1]
    return idle[2][int(t * 4) % 4]


def scene(fam, t, ally_sheets, knight_sheets):
    base = G.grass(W, H, seed=5)
    G.shadow(base, AF[0], AF[1] + 1, 8, 2.6)
    G.shadow(base, KF[0], KF[1] + 1, 8, 2.6)
    under, over, solid = layer(), layer(), layer()
    tint_k, tint_a = fam.draw(under, over, solid, t)
    proj = layer()
    projectile(proj, t)
    outline(proj, ORB[0], thr=0.95)
    imp = layer()
    impact(imp, t)
    comp(base, under)
    # y-sıralama: Şovalye (yukarıda) önce
    G.char_at(base, tinted(knight_sheets[0][1][int(t * 4 + 1) % 4], tint_k), KF[0], KF[1])
    G.char_at(base, tinted(ally_frame(ally_sheets, t), tint_a), AF[0], AF[1])
    comp(base, over)
    comp(base, solid)
    comp(base, proj)
    comp(base, imp)
    return base


def phase(t):
    if t < 1.2:
        return 'tek darbe'
    if t < 2.7:
        return 'cift darbe'
    return 'buyuk darbe'


def grid_frame(t, ally_sheets, knight_sheets):
    cw, ch = W * Z, H * Z
    head = 30
    im = Image.new('RGB', (cw * 2, ch * 2 + head), (24, 30, 22))
    for i, fam in enumerate(FAMILIES):
        sc = scene(fam, t, ally_sheets, knight_sheets)
        x, y = (i % 2) * cw, head + (i // 2) * ch
        im.paste(G.up(sc, Z), (x, y))
        G.label(im, x + 8, y + 6, fam.name, 17)
    d = ImageDraw.Draw(im)
    d.line([(cw, head), (cw, head + ch * 2)], fill=(24, 30, 22), width=2)
    d.line([(0, head + ch), (cw * 2, head + ch)], fill=(24, 30, 22), width=2)
    G.label(im, 10, 6, phase(t), 16, (255, 236, 160))
    G.label(im, cw * 2 - 330, 6, 'sol: dost (Assasin)  sag: Sovalye  -  x3', 14, (200, 220, 255))
    return im


def main():
    out = os.path.join(HERE, 'out')
    os.makedirs(out, exist_ok=True)
    ally = (G.load_game_sheet('assasin', 'idle'), G.load_game_sheet('assasin', 'hurt'))
    knight = (G.load_game_sheet('sovalye', 'idle'),)
    n = int(round(DUR * FPS))
    ims = [grid_frame(f / FPS, ally, knight) for f in range(n)]
    G.save_gif(ims, os.path.join(out, 'sovalye_e_emilim_A-D.gif'), int(1000 / FPS))
    if '--kareler' in sys.argv:
        for tt in (0.62, 0.8, 1.0, 3.25, 3.45, 3.7):
            grid_frame(tt, ally, knight).save(os.path.join(out, 'sovalye_e_kare_%04d.png' % int(tt * 100)))


if __name__ == '__main__':
    main()
