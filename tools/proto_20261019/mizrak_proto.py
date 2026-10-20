# -*- coding: utf-8 -*-
"""MIZRAK saplama animasyonu + efekti + CİRİT PROTOTİPLERİ (2026-10-19, oyuna bağlı DEĞİL). Kullanıcı: "silahın görünüşü ve efekti
için 4 prototip üretmeye başla" (yeni silah Mızrak; öneri: düz hatta delerek hattaki herkese %120 saldırı gücü, menzil 150; özellik
"Cirit": her 4. saplamada mızrak 280 birim düz hatta fırlatılır, yolundaki herkese %90, 0,4 sn sonra elde yeniden belirir).

Varsayılan mekanik ölçüleri (oyunda henüz yok, prototip için seçildi):
  - Mızrak diğer yakın dövüş silahları gibi hedefe uçar (hedefin 20 px önüne), geri çekilip SAPLAR; hat = ucun başladığı yerden
    hedefin 80 px gerisine kadar, yarı genişlik 12 px. Hattaki herkes vurulur; beyaz parlama ucun / efektin geçiş sırasıyla.
  - Aralık 1,1111 / 0,7 = 1,59 sn (diğer 4 yakın dövüş silahıyla aynı). Cirit 760 px/sn, karakterden 280 px'e kadar.
  - Sahne: Talon + Zanaatkâr L3 mızrak (mizrak_sanat.py), 5 slime: hedef + hattaki 2 (36 / 70 px geride), hattın 30 px yanında 1
    (vurulmaz), 128 px geride 1 (sadece cirit ulaşır).
Dört yön (görünüş = mizrak_sanat.py aynı harf; 1 sanat pikseli = 0,575 dünya px; efekt 30 fps'e kuantalı = sprite sayfası gibi):
  A Yaprak Uç   · Işık Hattı      - temiz saplama; uçtan hattın sonuna sivri krem ışık çizgisi, delinen her yaratıkta yıldız + kırıntı.
                                     Cirit: uzun krem iz.
  B Kanatlı     · Rüzgâr Burgusu  - burgu gibi dönerek saplar; hat boyunca iki sarmal rüzgâr şeridi + ileri giden ok başı dalgalar,
                                     ayak dibinde toz. Cirit: sarmal + arkada kalan hava halkaları.
  C Delici Şiş  · Kıvılcım Hattı  - ağır hamle; kızgın çizgi (soğuyarak), delinen her yaratıktan ileri saçılan kıvılcım, yerde soğuyan
                                     yanık izi + kor. Cirit: kızgın uç, saçılan kıvılcım, yerde yanık.
  D Püsküllü    · Ruh Uzantısı    - kısa saplama; uçtan hattın sonuna düz renkli (dither'sız) ruh mızrağı uzar, dipten uca zerrelere
                                     dağılır, delinenlerin ayağında halka. Cirit: mızrağı saran büyük ruh mızrağı.

Çıktılar (out/mizrak/): mizrak_oyun.gif (1080p oyun ölçeği, gerçek hız, saplama + cirit döngüsü), mizrak_yavas.gif (saplama x0,25,
x2 yakın), mizrak_kareler.png (saplama kareleri, isabete hizalı), mizrak_cirit_kareler.png, mizrak_oyun_kare.png.
Çalıştırma: python tools/proto_20261019/mizrak_proto.py [oyun|yavas|kareler]   (argümansız: hepsi; önce mizrak_sanat.py'yi çağırır)
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
P17 = os.path.normpath(os.path.join(HERE, "..", "proto_20261017"))
sys.path.insert(0, HERE)
sys.path.insert(0, P17)
import bicak_proto as BP  # noqa: E402  (numpy blit, yıldız/çizgi bantları, başlık, GIF)
import topuz_proto as TP  # noqa: E402  (Track, efekt tuvali, iz/bulut/halka/kıvılcım/kor)
import mermi_proto as MP  # noqa: E402
from mermi_proto import cl, hx, asset, label, grass  # noqa: E402
from bicak_proto import blit, header, stack_v, save_gif  # noqa: E402
from topuz_proto import Lay, Track, clamp01, ez, np_trail, np_cloud, np_ring, draw_sparks, draw_embers  # noqa: E402
import mizrak_sanat as MS  # noqa: E402

OUT = os.path.join(HERE, "out", "mizrak")
ZOOM = 2.0
WPP = 0.575
CHAR_K = 2.2368375 * 0.8075 * 0.5
SLIME_K = 0.94905
FPS = 50
FXFPS = 30
INTERVAL = 1.1111 / 0.7
D2R = math.pi / 180.0
CENTER_PX = (24.0, 24.0)

# ------------------------------------------------------------------ sahne (dünya px)
LWW, LHW = 340, 124
CHAR = (40.0, 58.0)
TGT = (152.0, 72.0)
_d = (TGT[0] - CHAR[0], TGT[1] - CHAR[1])
DIST_T = math.hypot(*_d)
DIR_ANG = math.atan2(_d[1], _d[0])
CA, SA = math.cos(DIR_ANG), math.sin(DIR_ANG)
G_OFF = (0.0, 7.0)  # yaratığın ayağı (TGT'ye göre)
REST_C = (CHAR[0] + 16.0, CHAR[1] - 22.0)
REST_POSE = (REST_C[0], REST_C[1], DIR_ANG, 1.0, 1.0)
LINE_X0, LINE_X1, LINE_HW = -22.0, 80.0, 12.0  # hat (yerel x: hedeften saldırı yönüne)
CIRIT_RANGE, CIRIT_V = 280.0, 760.0
X_END = CIRIT_RANGE - DIST_T  # ciritin bittiği yerel x
ENEMIES = [(0.0, 0.0), (36.0, 3.0), (70.0, -4.0), (26.0, 30.0), (128.0, 2.0)]  # yerel (x, dik)

# efekt tuvali: geniş (karakterden cirit sonuna), merkez = TGT
FXW, FXH = 680, 260
TP.FXW, TP.FXH = FXW, FXH
BP.FXW, BP.FXH = FXW, FXH
TP._YY, TP._XX = np.mgrid[0:FXH, 0:FXW]
TP.BAYT = (np.array(MP.BAY, np.float32)[TP._YY & 3, TP._XX & 3] + 0.5) / 16.0


def S(p):
    return (p[0] * ZOOM, p[1] * ZOOM)


def LW(x, y):
    """Yerel (x saldırı yönü, y Godot dik) -> dünya."""
    return (TGT[0] + CA * x - SA * y, TGT[1] + SA * x + CA * y)


def LO(x, y=0.0):
    """Yerel -> TGT'ye göre (efekt tuvali)."""
    return (CA * x - SA * y, SA * x + CA * y)


def add(p, q):
    return (p[0] + q[0], p[1] + q[1])


def off(p):
    return (p[0] - TGT[0], p[1] - TGT[1])


def to_local_x(p):
    o = off(p)
    return o[0] * CA + o[1] * SA


def in_line(e):
    return LINE_X0 <= e[0] <= LINE_X1 and abs(e[1]) <= LINE_HW


def U(x):
    return (x - LINE_X0) / (LINE_X1 - LINE_X0)


def body(e):
    return add(LO(*e), (0.0, -2.0))


def foot(e):
    return add(LO(*e), G_OFF)


# ------------------------------------------------------------------ renkler
CREAM_W = cl("#fffdf6 #f2ead6 #d8ccae #aa9e82")
CREAM_W_OL = hx("#6e6450")
CREAM = TP.CREAM
CREAM_L = TP.CREAM_L
EMBER = TP.EMBER
DUST, DUST_OL = TP.DUST, TP.DUST_OL
HOT = cl("#ffffff #fff4c8 #ffd060 #f39a2e #c4561c")
HOT_MID = cl("#fff4c8 #ffc04a #ec7e2a #b04a1c")
HOT_OLD = cl("#f09a3a #c4561c #8a3216 #5e2410")
HOT_OL = hx("#5e2410")
SCORCH_HOT = cl("#ffd060 #f08a2a #b04a1c")
SCORCH = cl("#5a4028 #3e2c1c #2c2016")
GHOST = cl("#fffdf0 #fff3c4 #f6dc8a #e2b45a")
GHOST_OL = hx("#8a6a2e")


# ------------------------------------------------------------------ mızrak ikonu (orta pivot, boy/en ölçeği, saydamlık)
def blit_spear(F, Sa, pw, ang, k, piv, sl=1.0, sw=1.0, alpha=1.0):
    sh, swd = Sa.shape[:2]
    px, py = piv
    rad = int(math.hypot(max(px, swd - px), max(py, sh - py)) * k * max(sl, sw, 1.0)) + 2
    H, Wd = F.shape[:2]
    cx, cy = pw
    x0, x1 = max(0, int(cx) - rad), min(Wd, int(cx) + rad)
    y0, y1 = max(0, int(cy) - rad), min(H, int(cy) + rad)
    if x0 >= x1 or y0 >= y1 or alpha <= 0.0:
        return
    X, Y = np.meshgrid(np.arange(x0, x1) + 0.5 - cx, np.arange(y0, y1) + 0.5 - cy)
    ca, sa = math.cos(ang), math.sin(ang)
    mx = (ca * X + sa * Y) / (k * sl)
    my = (-sa * X + ca * Y) / (k * sw)
    cf, sf = math.cos(-math.pi / 4), math.sin(-math.pi / 4)  # sanatta uç sağ-üstte
    u = np.floor(cf * mx - sf * my + px).astype(np.int32)
    v = np.floor(sf * mx + cf * my + py).astype(np.int32)
    m = (u >= 0) & (u < swd) & (v >= 0) & (v < sh)
    if not m.any():
        return
    samp = np.zeros((y1 - y0, x1 - x0, 4), np.float32)
    samp[m] = Sa[v[m], u[m]]
    a = samp[..., 3:4] / 255.0 * alpha
    F[y0:y1, x0:x1] = F[y0:y1, x0:x1] * (1.0 - a) + samp[..., :3] * a


def _sparks(seed, n, a0, a1, v, life, both=False):
    rng = random.Random(seed)
    out = []
    for i in range(n):
        a = rng.uniform(a0, a1) * (-1 if (both and i % 2) else 1)
        out.append((a * D2R + DIR_ANG, rng.uniform(*v), rng.uniform(*life)))
    return out


def _embers_at(seed, n, spread, v, vz, life):
    return TP.make_embers(seed, n, spread, v, vz, life)


# ------------------------------------------------------------------ yön tanımları
SPEC = {
    "A": dict(title="A - Yaprak Uç · Işık Hattı", sub="temiz saplama; uçtan hattın sonuna krem ışık çizgisi, her delişte yıldız",
              set_x=-20.0, back=7.0, d_back=0.07, past=16.0, d_thr=0.045, shake=0.5, roll=False, pull=16.0, V=1700.0),
    "B": dict(title="B - Kanatlı · Rüzgâr Burgusu", sub="dönerek saplar; hat boyunca sarmal rüzgâr + ileri giden ok başı dalgalar, toz",
              set_x=-20.0, back=8.0, d_back=0.08, past=20.0, d_thr=0.06, shake=0.0, roll=True, pull=18.0, V=1500.0),
    "C": dict(title="C - Delici Şiş · Kıvılcım Hattı", sub="ağır hamle; kızgın çizgi, delinen her yaratıktan kıvılcım, yerde soğuyan iz",
              set_x=-22.0, back=13.0, d_back=0.11, past=22.0, d_thr=0.05, shake=1.0, roll=False, pull=18.0, V=1400.0),
    "D": dict(title="D - Püsküllü · Ruh Uzantısı", sub="kısa saplama; uçtan hattın sonuna ruh mızrağı uzar, zerrelere dağılır",
              set_x=-18.0, back=6.0, d_back=0.07, past=8.0, d_thr=0.04, shake=0.4, roll=False, pull=10.0, V=1900.0),
}
ORDER = ["A", "B", "C", "D"]


class Dir:
    def __init__(self, did):
        self.did = did
        self.__dict__.update(SPEC[did])
        self.tipd = MS.TIPS[(did, 3)] * 0.955 * WPP  # ikon merkezinden uca (dünya px)
        self.img = BP._np(Image.open(os.path.join(MS.ART, "mizrak_%s_L3.png" % did)).convert("RGBA"))
        self._thrust()
        self._cirit()

    def cpose(self, x_tip, sl=1.0, sw=1.0):
        wx, wy = LW(x_tip - self.tipd * sl, 0.0)
        return (wx, wy, DIR_ANG, sl, sw)

    def tip(self, tr, t):
        x, y, a, sl, _ = tr.pose(t)
        return (x + self.tipd * sl * math.cos(a), y + self.tipd * sl * math.sin(a))

    def _thrust(self):
        tr = Track(REST_POSE, CENTER_PX)
        tr.to(0.13, "out", self.cpose(self.set_x))
        xb = self.set_x - self.back
        tr.to(self.d_back, "inout", self.cpose(xb, 0.93, 1.05))
        self.t_thr0 = tr.t
        if self.roll:
            def fn(e, xb=xb):  # burgu: en ekseninde "dönme" (genişlik nefesi)
                return self.cpose(xb + (self.past - xb) * e, 0.93 + 0.17 * e, 1.0 - 0.45 * abs(math.sin(e * math.pi * 2.0)))
            tr.add(self.d_thr, "in", fn)
        else:
            tr.to(self.d_thr, "in", self.cpose(self.past, 1.1, 0.94))
        self.hit = self.t_thr0 + math.sqrt((0.0 - xb) / (self.past - xb)) * self.d_thr
        base, amp = self.cpose(self.past), self.shake

        def shake(e):
            dd = amp * math.sin(e * math.pi * 6.0) * (1.0 - e)
            return (base[0] - SA * dd, base[1] + CA * dd, base[2], 1.0, 1.0)
        tr.add(0.06, "lin", shake)
        tr.to(0.08, "out", self.cpose(self.past - self.pull))
        tr.hold(0.03)
        tr.home(0.26)
        self.tr_t = tr

    def _cirit(self):
        tr = Track(REST_POSE, CENTER_PX)
        tr.to(0.13, "out", self.cpose(self.set_x))
        self.x_r = self.set_x - 14.0
        tr.to(0.12, "inout", self.cpose(self.x_r, 0.9, 1.08))
        self.t_rel = tr.t
        dist = X_END - self.x_r
        t_fl = dist / CIRIT_V

        def fn(e):
            return self.cpose(self.x_r + dist * e, 0.9 + 0.1 * min(1.0, e * 6.0), 1.0)
        tr.add(t_fl, "lin", fn)
        self.t_end = tr.t
        tr.hold(0.08)  # sonda durup söner
        self.t_back = self.t_end + 0.4
        self.tr_c = tr

    def ctip_x(self, t):
        return min(X_END, self.x_r + CIRIT_V * max(0.0, t - self.t_rel))

    def track(self, kind):
        return self.tr_t if kind == "thrust" else self.tr_c

    def alpha(self, kind, t):
        if kind == "thrust" or t < self.t_end:
            return 1.0
        if t < self.t_end + 0.08:
            return 1.0 - (t - self.t_end) / 0.08
        if t < self.t_back:
            return 0.0
        return clamp01((t - self.t_back) / 0.08)

    def passes(self, kind):
        """yaratık sırası -> ucun / efektin geçtiği an"""
        out = {}
        for i, e in enumerate(ENEMIES):
            if kind == "thrust":
                if in_line(e):
                    out[i] = self.hit + max(0.0, e[0]) / self.V
            elif abs(e[1]) <= LINE_HW and self.x_r < e[0] <= X_END:
                out[i] = self.t_rel + (e[0] - self.x_r) / CIRIT_V
        return out


DIRS = {}  # setup() kurar (önce sanat üretilir)


def hist(d, tr, t, t0, t1, win, linger=0.03, eat=0.06, n=10):
    """[t0, t1] boyunca ucun son `win` saniyelik yolu (en yeni önce, TGT'ye göre)."""
    if t < t0:
        return []
    te = min(t, t1)
    tb = max(t0, te - win)
    if t > t1 + linger:
        k = (t - t1 - linger) / eat
        if k >= 1.0:
            return []
        tb += (te - tb) * k
    if te - tb < 0.003:
        return []
    return [off(d.tip(tr, te - (te - tb) * j / (n - 1))) for j in range(n)]


def line_seg(L, xa, xb, w, cols, head=1.0, tail=0.0, thin=0.0, ol=None, peak=1.3, fade=1.0, y=0.0, dy=(0.0, 0.0)):
    if xb - xa < 0.5:
        return
    BP.line_band(L, add(LO(xa, y), dy), add(LO(xb, y), dy), w, cols, head, tail, thin, ol=ol, peak=peak, fade=fade)


# ---- A Işık Hattı
A_SHARDS = {i: _sparks(30 + i, 4, 65.0, 115.0, (40.0, 90.0), (0.10, 0.20), both=True) for i in range(len(ENEMIES))}
A_END = _sparks(41, 7, -35.0, 35.0, (50.0, 120.0), (0.12, 0.24))


def A_fx_t(d, Ls, t):
    age = t - d.hit
    if age < 0.0:
        return
    head = U(min(LINE_X1, d.V * age))
    tail = ez("in", clamp01((age - 0.04) / 0.12))
    thin = clamp01((age - 0.07) / 0.12)
    line_seg(Ls["f"], LINE_X0, LINE_X1, 4.6, CREAM_W, head, tail, thin, ol=CREAM_W_OL, peak=2.4)
    for i, tp in d.passes("thrust").items():
        a2 = t - tp
        if 0.0 <= a2 < 0.10:
            BP.star(Ls["f"], body(ENEMIES[i]), 7.0 if i == 0 else 5.5, CREAM, a2 / 0.10)
        draw_sparks(Ls["f"], body(ENEMIES[i]), A_SHARDS[i], a2, CREAM_L, g=120.0)
    ae = age - LINE_X1 / d.V
    if 0.0 <= ae < 0.08:
        BP.star(Ls["f"], LO(LINE_X1), 4.0, CREAM, ae / 0.08)


def A_live_t(d, L, t):
    np_trail(L, hist(d, d.tr_t, t, d.t_thr0, d.hit + 0.01, 0.035, linger=0.0, eat=0.05), 2.6, CREAM_W, CREAM_W_OL)


def A_fx_c(d, Ls, t):
    for i, tp in d.passes("cirit").items():
        a2 = t - tp
        if 0.0 <= a2 < 0.10:
            BP.star(Ls["f"], body(ENEMIES[i]), 6.0, CREAM, a2 / 0.10)
        draw_sparks(Ls["f"], body(ENEMIES[i]), A_SHARDS[i], a2, CREAM_L, g=120.0)
    ae = t - d.t_end
    if 0.0 <= ae < 0.12:
        BP.star(Ls["f"], LO(X_END), 7.0, CREAM, ae / 0.12)
    draw_sparks(Ls["f"], LO(X_END), A_END, ae, CREAM_L, g=90.0)
    ab = t - d.t_back
    if 0.0 <= ab < 0.10:
        BP.star(Ls["f"], off(REST_C), 5.0, CREAM, ab / 0.10)


def A_live_c(d, L, t):
    np_trail(L, hist(d, d.tr_c, t, d.t_rel, d.t_end, 0.09, linger=0.0, eat=0.08, n=12), 5.0, CREAM_W, CREAM_W_OL)


# ---- B Rüzgâr Burgusu
def helix(L, xa, xb, phase, amp, lam, w, cols, fade=1.0):
    if xb - xa < 2.0:
        return
    n = max(4, int((xb - xa) / 1.4))
    for sg in (0.0, math.pi):
        pts = [LO(xb - (xb - xa) * j / (n - 1), amp * math.sin(2 * math.pi * (xb - (xb - xa) * j / (n - 1)) / lam + phase + sg))
               for j in range(n)]
        np_trail(L, pts, w, cols, None, fade)


def chevron(L, x, h, w, cols, fade):
    for sg in (-1.0, 1.0):
        BP.line_band(L, LO(x - 4.5, sg * h), LO(x, 0.0), w, cols, 1.0, 0.0, 0.0, ol=None, peak=1.0, fade=fade)


def dust(L, e, a2, push=6.0):
    k = clamp01(a2 / 0.26)
    if a2 < 0.0 or k >= 1.0:
        return
    ee = math.sin(k * math.pi / 2)
    f = foot(e)
    p = LO(push * ee)
    np_cloud(L, [(f[0] + p[0] + dx, f[1] + p[1] + dy - 2.0 * ee, r * (0.5 + 0.6 * ee))
                 for dx, dy, r in ((-4.0, 0.5, 2.4), (3.0, -0.5, 2.8), (0.0, 1.5, 2.0))],
             DUST, DUST_OL, 1.0, clamp01((a2 - 0.06) / 0.18))


def B_fx_t(d, Ls, t):
    age = t - d.hit
    if age < 0.0:
        return
    xb = min(LINE_X1, d.V * age)
    xa = LINE_X0 + (LINE_X1 - LINE_X0) * ez("in", clamp01((age - 0.06) / 0.12))
    if age < 0.2:
        helix(Ls["f"], xa, xb, age * 40.0, 3.4, 24.0, 2.2, CREAM_L)
    for k in range(3):
        xk = 1150.0 * (age - k * 0.03)
        if 0.0 <= xk <= LINE_X1 + 4.0:
            chevron(Ls["f"], xk, 4.5 + 0.05 * xk, 2.6, CREAM_L, 1.0 - clamp01((xk - (LINE_X1 - 22.0)) / 26.0))
    for i, tp in d.passes("thrust").items():
        dust(Ls["g"], ENEMIES[i], t - tp)


def B_live_t(d, L, t):
    np_trail(L, hist(d, d.tr_t, t, d.t_thr0, d.hit + 0.01, 0.03, linger=0.0, eat=0.05), 2.2, CREAM_W, CREAM_W_OL)


def B_fx_c(d, Ls, t):
    for k in range(40):
        ts = d.t_rel + 0.03 + k * 0.045
        if ts > d.t_end:
            break
        a = t - ts
        if a >= 0.0:
            np_ring(Ls["f"], LO(d.ctip_x(ts) - 8.0), 1.0, 3.0, 3.4, 9.5, 1.8, CREAM_L, a / 0.24, nbreak=4, phase=k * 1.3, fade=1.0, brk=0.4)
    for i, tp in d.passes("cirit").items():
        dust(Ls["g"], ENEMIES[i], t - tp, push=10.0)
    ae = t - d.t_end
    for k in range(2):
        xk = X_END + 260.0 * (ae - k * 0.04)
        if ae >= k * 0.04 and xk < X_END + 18.0:
            chevron(Ls["f"], xk, 5.0 + (xk - X_END) * 0.2, 2.4, CREAM_L, 1.0 - clamp01((xk - X_END) / 18.0))


def B_live_c(d, L, t):
    if t < d.t_rel:
        return
    xb = d.ctip_x(t)
    if t > d.t_end + 0.1:
        return
    xa = max(d.x_r, xb - 46.0) if t <= d.t_end else xb - 46.0 * (1.0 - (t - d.t_end) / 0.1)
    helix(L, xa, xb, t * 48.0, 3.0, 20.0, 1.9, CREAM_L)


# ---- C Kıvılcım Hattı
C_SPARKS = {i: _sparks(50 + i, 7, 12.0, 62.0, (70.0, 150.0), (0.16, 0.30), both=True) for i in range(len(ENEMIES))}
C_EMBERS = {i: _embers_at(60 + i, 5, (6.0, 3.0), (4.0, 14.0), (30.0, 60.0), (0.3, 0.55)) for i in range(len(ENEMIES))}
C_END = _sparks(71, 10, -50.0, 50.0, (60.0, 150.0), (0.16, 0.32))


def _hot(age):
    return HOT if age < 0.06 else (HOT_MID if age < 0.14 else HOT_OLD)


def C_fx_t(d, Ls, t):
    age = t - d.hit
    if age < 0.0:
        return
    xh = min(LINE_X1, d.V * age)
    head = U(xh)
    tail = ez("in", clamp01((age - 0.06) / 0.14))
    line_seg(Ls["f"], LINE_X0, LINE_X1, 5.2, _hot(age), head, tail, clamp01((age - 0.10) / 0.12), ol=HOT_OL, peak=2.0)
    if age < 0.10:
        BP.star(Ls["f"], body(ENEMIES[0]), 9.0, HOT, age / 0.10)
    ## yerde yanık izi: hattın ayak hizasındaki gölgesi, kızgın -> koyu, söner
    fade = 1.0 - clamp01((age - 0.30) / 0.35)
    if fade > 0.0:
        line_seg(Ls["g"], LINE_X0 + 8.0, max(LINE_X0 + 9.0, xh), 2.4, SCORCH_HOT if age < 0.12 else SCORCH, dy=G_OFF, peak=0.6, fade=fade)
    for i, tp in d.passes("thrust").items():
        a2 = t - tp
        draw_sparks(Ls["f"], body(ENEMIES[i]), C_SPARKS[i], a2, EMBER, g=260.0)
        draw_embers(Ls["f"], foot(ENEMIES[i]), C_EMBERS[i], a2 - 0.05, EMBER, g=60.0)


def C_live_t(d, L, t):
    np_trail(L, hist(d, d.tr_t, t, d.t_thr0, d.hit + 0.01, 0.035, linger=0.0, eat=0.05), 3.0, HOT_MID, HOT_OL)


C_SHED = [_sparks(80 + k, 2, 150.0, 200.0, (30.0, 70.0), (0.14, 0.24), both=True) for k in range(40)]


def C_fx_c(d, Ls, t):
    xt = d.ctip_x(t)
    ## yerde yanık: bırakılan yerden ucun altına; son 30 px kızgın
    if t >= d.t_rel:
        fade = 1.0 - clamp01((t - d.t_end - 0.2) / 0.4)
        if fade > 0.0:
            line_seg(Ls["g"], d.x_r + 10.0, xt, 2.2, SCORCH, dy=G_OFF, peak=0.4, fade=fade)
            if t <= d.t_end + 0.12:
                line_seg(Ls["g"], max(d.x_r + 10.0, xt - 30.0), xt, 2.4, SCORCH_HOT, dy=G_OFF, peak=2.0, fade=fade)
    for k in range(40):
        ts = d.t_rel + 0.02 + k * 0.025
        if ts > d.t_end:
            break
        draw_sparks(Ls["f"], LO(d.ctip_x(ts) - 4.0), C_SHED[k], t - ts, EMBER, g=300.0)
    for i, tp in d.passes("cirit").items():
        a2 = t - tp
        if 0.0 <= a2 < 0.08:
            BP.star(Ls["f"], body(ENEMIES[i]), 7.0, HOT, a2 / 0.08)
        draw_sparks(Ls["f"], body(ENEMIES[i]), C_SPARKS[i], a2, EMBER, g=260.0)
    ae = t - d.t_end
    draw_sparks(Ls["f"], LO(X_END), C_END, ae, EMBER, g=260.0)
    draw_embers(Ls["f"], add(LO(X_END), G_OFF), C_EMBERS[4], ae, EMBER, g=60.0)


def C_live_c(d, L, t):
    if d.t_rel <= t <= d.t_end:
        np_trail(L, hist(d, d.tr_c, t, d.t_rel, d.t_end, 0.05, linger=0.0, eat=0.06), 3.6, HOT_MID, HOT_OL)
        BP.star(L, off(d.tip(d.tr_c, t)), 4.0 if int(t * 30) % 2 else 3.0, HOT, 0.15)


# ---- D Ruh Uzantısı (düz renk, dither'sız)
D_MOTES = [_embers_at(90 + k, 3, (2.0, 1.5), (2.0, 8.0), (18.0, 40.0), (0.25, 0.45)) for k in range(12)]


def ghost_spear(L, xb, xt, w_shaft, w_head, head_len, cols, ol, thin=0.0):
    """xb (dip) -> xt (uç): ince ışık sapı + yaprak uç, düz renk."""
    if xt - xb < 1.0:
        return
    hb = max(xb, xt - head_len)
    if hb - xb > 2.0:
        BP.line_band(L, LO(xb), LO(hb + head_len * 0.3), w_shaft, cols, 1.0, 0.0, thin, ol=None, peak=1.0)
    BP.line_band(L, LO(hb), LO(xt), w_head * (xt - hb) / head_len, cols, 1.0, 0.0, thin, ol=ol, peak=1.0)


def motes_along(L, xa, xb, t, t_pass_fn):
    for k in range(12):
        x = xa + (xb - xa) * (k + 0.5) / 12.0
        tp = t_pass_fn(x)
        if tp is not None:
            draw_embers(L, LO(x), D_MOTES[k], t - tp, GHOST, g=-20.0)


def D_fx_t(d, Ls, t):
    age = t - d.hit
    if age < 0.0:
        return
    xt = min(LINE_X1, d.V * age)
    k = ez("in", clamp01((age - 0.11) / 0.14))
    xb = 4.0 + (LINE_X1 - 4.0) * k
    if k < 1.0:
        ghost_spear(Ls["f"], xb, xt, 3.4, 10.0, 17.0, GHOST, GHOST_OL, thin=clamp01((k - 0.7) / 0.3))
    motes_along(Ls["f"], 4.0, LINE_X1, t, lambda x: d.hit + 0.11 + 0.14 * math.sqrt(clamp01((x - 4.0) / (LINE_X1 - 4.0))))
    for i, tp in d.passes("thrust").items():
        a2 = t - tp
        if a2 >= 0.0:
            np_ring(Ls["g"], foot(ENEMIES[i]), 3.0, 1.5, 11.0, 5.5, 2.0, GHOST, a2 / 0.28, nbreak=5, phase=i, ol=GHOST_OL, fade=1.0, brk=0.5)


def D_live_t(d, L, t):
    np_trail(L, hist(d, d.tr_t, t, d.t_thr0, d.hit + 0.01, 0.03, linger=0.0, eat=0.05), 2.4, GHOST, GHOST_OL)


def D_fx_c(d, Ls, t):
    if t < d.t_rel:
        return
    xt = d.ctip_x(t) + 5.0
    if t <= d.t_end:
        ghost_spear(Ls["f"], max(d.x_r, xt - 48.0), xt, 3.2, 10.0, 20.0, GHOST, GHOST_OL)
    else:
        k = clamp01((t - d.t_end) / 0.12)
        if k < 1.0:
            ghost_spear(Ls["f"], xt - 48.0 + 48.0 * k, xt, 3.2, 10.0, 20.0, GHOST, GHOST_OL, thin=k * 0.8)
        motes_along(Ls["f"], X_END - 43.0, X_END + 5.0, t, lambda x: d.t_end + 0.12 * (x - (X_END - 43.0)) / 48.0)
    for i, tp in d.passes("cirit").items():
        a2 = t - tp
        if a2 >= 0.0:
            np_ring(Ls["g"], foot(ENEMIES[i]), 3.0, 1.5, 11.0, 5.5, 2.0, GHOST, a2 / 0.28, nbreak=5, phase=i, ol=GHOST_OL, fade=1.0, brk=0.5)


def D_live_c(d, L, t):
    pass


FX = {"A": (A_fx_t, A_live_t, A_fx_c, A_live_c), "B": (B_fx_t, B_live_t, B_fx_c, B_live_c),
      "C": (C_fx_t, C_live_t, C_fx_c, C_live_c), "D": (D_fx_t, D_live_t, D_fx_c, D_live_c)}


# ------------------------------------------------------------------ şerit
_BG = {}


def lane_bg(idx):
    if idx not in _BG:
        g = grass(int(LWW * ZOOM), int(LHW * ZOOM), 71 + idx)
        F = np.asarray(g.convert("RGB"), dtype=np.float32).copy()
        ch = asset("assets/characters/talon/sheets/idle.png", (0, 96, 48, 144))
        cx, cy = S(CHAR)
        blit(F, ch, cx, cy, CHAR_K * ZOOM)
        _BG[idx] = F
    return _BG[idx].copy()


_SLIME = []


def slime():
    if not _SLIME:
        _SLIME.append(asset("visuals/Yaratıklar/Tüm Yaratıklar/Slime 1/PNG/Slime1/With_shadow/Slime1_Walk_with_shadow.png", (0, 0, 64, 64)))
    return _SLIME[0]


class Lane:
    def __init__(self, did, idx, t_first=0.15, kinds=("thrust", "cirit")):
        self.did, self.idx = did, idx
        self.d = DIRS[did]
        self.t_first = t_first
        self.kinds = kinds
        self.cache = {}

    def attack(self, t):
        if t < self.t_first:
            return 99.0, 0
        n = int((t - self.t_first) // INTERVAL)
        return t - self.t_first - n * INTERVAL, n

    def layers(self, kind, ta):
        q = int(ta * FXFPS)
        key = (kind, q)
        if key not in self.cache:
            Ls = {"g": Lay(), "f": Lay()}
            fxt, _, fxc, _ = FX[self.did]
            (fxt if kind == "thrust" else fxc)(self.d, Ls, q / float(FXFPS))
            self.cache[key] = {k: v.cropped() for k, v in Ls.items()}
        return self.cache[key]

    def render(self, t):
        F = lane_bg(self.idx)
        ta, n = self.attack(t)
        kind = self.kinds[n % len(self.kinds)]
        d = self.d
        lay = self.layers(kind, ta)
        tx, ty = S(TGT)
        k_fx = WPP * ZOOM

        def put_layer(c):
            if c is not None:
                blit(F, c[0], tx, ty, k_fx, 0.0, c[1])

        put_layer(lay["g"])
        pas = d.passes(kind)
        for i in sorted(range(len(ENEMIES)), key=lambda j: LW(*ENEMIES[j])[1]):
            sx, sy = S(LW(*ENEMIES[i]))
            blit(F, slime(), sx, sy - 2, SLIME_K * ZOOM)
            if i in pas:
                fl = ta - pas[i]
                if 0.0 <= fl < 0.12:
                    blit(F, slime(), sx, sy - 2, SLIME_K * ZOOM, alpha=1.0 - fl / 0.12, tint=(255, 255, 255))
        _, livet, _, livec = FX[self.did]
        L = Lay()
        (livet if kind == "thrust" else livec)(d, L, ta)
        put_layer(L.cropped())
        tr = d.track(kind)
        x, y, a, sl, sw = tr.pose(ta)
        blit_spear(F, d.img, S((x, y)), a, WPP * ZOOM, CENTER_PX, sl, sw, d.alpha(kind, ta))
        put_layer(lay["f"])
        return Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")


def lane_label(im, did, small=False, kind=None):
    dd = ImageDraw.Draw(im)
    label(dd, 6, 3, SPEC[did]["title"], 12)
    if kind:
        label(dd, im.width - 150, 3, kind, 11, (250, 228, 160))
    if not small:
        label(dd, 6, im.height - 16, SPEC[did]["sub"], 10, (226, 220, 204))


def info_tile(w, h, lines, title=None):
    im = Image.new("RGB", (w, h), (30, 34, 32))
    dd = ImageDraw.Draw(im)
    y = 12
    if title:
        label(dd, 12, y, title, 16)
        y += 28
    for s in lines:
        label(dd, 12, y, s, 11, (220, 214, 198))
        y += 17
    return im


def art_tile(w, h):
    """4 yön x 5 seviye, oyun ölçeğinde (1 sanat px = 0,575 dünya px, zoom 2)."""
    F = np.full((h, w, 3), (52, 66, 48), np.float32)
    im0 = Image.new("RGB", (w, h))
    for r, did in enumerate(ORDER):
        for lv in range(1, 6):
            src = Image.open(os.path.join(MS.ART, "mizrak_%s_L%d.png" % (did, lv))).convert("RGBA")
            blit(F, src, 150 + (lv - 1) * 104, 34 + r * 58, WPP * ZOOM)
    im0 = Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")
    dd = ImageDraw.Draw(im0)
    label(dd, 8, 4, "Görünüş - 5 seviye, oyun ölçeği", 12)
    for r, did in enumerate(ORDER):
        label(dd, 8, 28 + r * 58, SPEC[did]["title"].split(" · ")[0], 11, (230, 224, 206))
    for lv in range(1, 6):
        label(dd, 132 + (lv - 1) * 104, h - 16, "%d %s" % (lv, MS.TA[lv]["name"]), 10, (210, 204, 188))
    return im0


grid = TP.grid

INFO = [
    "aralık %.2f sn · hattaki herkese %%120 saldırı gücü (önerilen)" % INTERVAL,
    "hat: uçtan hedefin 80 px gerisine, yarı genişlik 12 px",
    "beyaz parlama = isabet, uç / efekt geçtikçe sırayla",
    "alttaki slime hattın 30 px yanında: vurulmaz",
    "en sağdaki slime 128 px geride: sadece cirit ulaşır",
    "CİRİT: her 4. saplama (burada her 2.); 280 px, 760 px/sn,",
    "%90 saldırı gücü, mızrak 0,4 sn sonra elde belirir",
    "Talon + Zanaatkâr L3 mızrak · efekt 30 fps (sprite sayfası)",
]


def setup():
    MS.build()
    for k in ORDER:
        DIRS[k] = Dir(k)
    os.makedirs(OUT, exist_ok=True)


def build_game():
    lanes = [Lane(dd, i) for i, dd in enumerate(ORDER)]
    loop = 2.0 * INTERVAL
    n = int(round(loop * FPS))
    dt = loop / n
    lw, lh = int(LWW * ZOOM), int(LHW * ZOOM)
    info = info_tile(lw, lh, INFO, "Mızrak - saplama + cirit")
    arts = art_tile(lw, lh)
    hd = header(lw * 2 + 4, "Mızrak  ·  oyun ölçeği (1080p), gerçek hız", "1. vuruş SAPLAMA, 2. vuruş CİRİT (oyunda her 4. saplama)")
    frames = []
    for st in range(n):
        t = st * dt
        tiles = []
        for ln in lanes:
            im = ln.render(t)
            _, na = ln.attack(t)
            lane_label(im, ln.did, kind="saplama" if na % 2 == 0 else "CİRİT")
            tiles.append(im)
        tiles += [arts, info]
        frames.append(stack_v([hd, grid(tiles, 2)]))
    save_gif(frames, os.path.join(OUT, "mizrak_oyun.gif"), 1.0 / dt,
             [int(0.40 * FPS), int(0.48 * FPS), int((0.15 + INTERVAL + 0.32) * FPS), int((0.15 + INTERVAL + 0.45) * FPS)])
    frames[int((0.15 + INTERVAL + 0.40) * FPS)].save(os.path.join(OUT, "mizrak_oyun_kare.png"))


CROP = (int((TGT[0] - 54) * ZOOM), int((TGT[1] - 40) * ZOOM), int((TGT[0] + 100) * ZOOM), int((TGT[1] + 42) * ZOOM))


def build_slow(speed=0.25, z=2):
    lanes = [Lane(dd, i, t_first=0.05, kinds=("thrust",)) for i, dd in enumerate(ORDER)]
    fps = 40
    real_len = 0.75
    n = int(round(real_len / speed * fps))
    dt = real_len / n
    cw, ch = (CROP[2] - CROP[0]) * z, (CROP[3] - CROP[1]) * z
    frames = []
    for st in range(n):
        t = st * dt
        tiles = []
        for ln in lanes:
            im = ln.render(t).crop(CROP).resize((cw, ch), Image.NEAREST)
            lane_label(im, ln.did, small=True)
            tiles.append(im)
        frames.append(stack_v([header(cw * 2 + 4, "Mızrak saplaması - YAVAŞ ÇEKİM x%.2f, yakınlaştırma x%d" % (speed, z),
                                      "süre %.2f sn (gerçek) · isabet: A %.2f · B %.2f · C %.2f · D %.2f sn" % (
                                          max(0.0, t - 0.05), DIRS["A"].hit, DIRS["B"].hit, DIRS["C"].hit, DIRS["D"].hit)),
                               grid(tiles, 2)]))
    save_gif(frames, os.path.join(OUT, "mizrak_yavas.gif"), fps, [int(0.30 / dt), int(0.36 / dt), int(0.45 / dt)])


OFFS = [-0.06, -0.02, 0.0, 0.03, 0.067, 0.10, 0.16, 0.26]
SCROP = (int((TGT[0] - 50) * ZOOM), int((TGT[1] - 36) * ZOOM), int((TGT[0] + 96) * ZOOM), int((TGT[1] + 40) * ZOOM))


def build_strip():
    rows = []
    cw, ch = SCROP[2] - SCROP[0], SCROP[3] - SCROP[1]
    LBL = 170
    for i, did in enumerate(ORDER):
        ln = Lane(did, i, t_first=0.0, kinds=("thrust",))
        t0 = DIRS[did].hit
        row = Image.new("RGB", (LBL + len(OFFS) * (cw + 2), ch + 18), (24, 26, 26))
        dd = ImageDraw.Draw(row)
        for j, o in enumerate(OFFS):
            tt = max(0.0, t0 + o)
            row.paste(ln.render(tt).crop(SCROP), (LBL + j * (cw + 2), 18))
            label(dd, LBL + j * (cw + 2) + 4, 2, "%+.2f sn%s" % (o, "  isabet" if o == 0.0 else ""), 10, (220, 214, 198))
        label(dd, 6, 22, SPEC[did]["title"].split(" · ")[0], 12)
        label(dd, 6, 40, SPEC[did]["title"].split(" · ")[1], 11, (226, 220, 204))
        rows.append(row)
    im = stack_v(rows, 6)
    im.save(os.path.join(OUT, "mizrak_kareler.png"))
    print("kareler", im.size)
    ## cirit: bırakış, hedeften geçiş, uzak slime, son, yeniden belirme
    rows = []
    CC = (int((TGT[0] - 70) * ZOOM), int((TGT[1] - 34) * ZOOM), int((TGT[0] + 190) * ZOOM), int((TGT[1] + 44) * ZOOM))
    cw, ch = CC[2] - CC[0], CC[3] - CC[1]
    for i, did in enumerate(ORDER):
        d = DIRS[did]
        ln = Lane(did, i, t_first=0.0, kinds=("cirit",))
        ts = [d.t_rel + 0.05, d.t_rel + 0.14, d.t_end - 0.02, d.t_end + 0.07]
        row = Image.new("RGB", (LBL + len(ts) * (cw + 2), ch + 18), (24, 26, 26))
        dd = ImageDraw.Draw(row)
        for j, tt in enumerate(ts):
            row.paste(ln.render(tt).crop(CC), (LBL + j * (cw + 2), 18))
            label(dd, LBL + j * (cw + 2) + 4, 2, "bırakıştan %+.2f sn" % (tt - d.t_rel), 10, (220, 214, 198))
        label(dd, 6, 22, SPEC[did]["title"].split(" · ")[0], 12)
        label(dd, 6, 40, "CİRİT", 11, (250, 228, 160))
        rows.append(row)
    im = stack_v(rows, 6)
    im.save(os.path.join(OUT, "mizrak_cirit_kareler.png"))
    print("cirit kareler", im.size)


if __name__ == "__main__":
    setup()
    args = sys.argv[1:] or ["kareler", "oyun", "yavas"]
    for w in args:
        {"oyun": build_game, "yavas": build_slow, "kareler": build_strip}[w]()
