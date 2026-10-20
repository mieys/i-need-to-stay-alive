# -*- coding: utf-8 -*-
"""YİN YANG KİTABI vuruş + kalkan efekti PROTOTİPLERİ (2026-10-20, oyuna bağlı DEĞİL). Kullanıcı görünüş olarak B "Açık Sayfalar"ı
seçti (yinyang_sanat.py).

Önerilen mekanik (oyunda yok): menzilli tek hedef, isabet %100 saldırı gücü, aralık 1,2 / 0,7 = 1,71 sn; isabet başına %10 saldırı
gücü kalkan MENZİLSİZ: kalkanı oransal en boş canlı oyuncuya (tek kişilikte hep sahibine). Fikir: vuruşun kara (yin) yarısı
düşmanda kalır, ak (yang) yarısı kalkanı alana uçar.
Sahne: Talon (kitabın sahibi) + Şovalye (dost) + 3 slime. 1. vuruş üstteki slime -> yang DOSTA, 2. vuruş alttaki slime -> yang
KENDİNE (tek kişilik). Kitap: açık sayfalar L3, atıştan önce hafifçe kalkar ve parlar.
Efektler (30 fps'e kuantalı = sprite sayfası gibi; dither YOK, solma gerçek saydamlıkla):
  A Dönen Küre    - dönen yin-yang küresi; çarpınca ikiye ayrılır: kara yarı düşmanda mürekkep damlalarıyla dağılır, ak yarı
                    kavisle kalkan alana uçar, varışta krem halka + parıltı
  B İkiz Sarmal   - kara ve ak iki küre birbirinin çevresinde sarmal çizerek uçar; kara olan vurur, ak olan sarmal izle döner,
                    alıcının belinde bir tur atıp söner
  C Kâğıt Tılsım  - kitaptan sayfa kopar, mühürlü tılsım olup çırpınarak uçar, düşmana yapışır; yerde mürekkep mührü, kâğıt
                    ak parçalara bölünüp alıcıya süzülür ve halka olur
  D Fırça Darbesi - kitaptan hedefe mürekkep fırça çizgisi (kuru fırça izli), hedefte mürekkep lekesi; hedeften alıcıya ak fırça
                    çizgisi akar, alıcının ayağında ak enso (fırça halkası)

Çıktılar (out/yinyang/): yinyang_oyun.gif (oyun ölçeği 1080p, gerçek hız), yinyang_yavas.gif (dosta vuruş x0,25, x2),
yinyang_oyun_kare.png. Çalıştırma: python tools/proto_20261020/yinyang_proto.py [oyun|yavas]
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
import topuz_proto as TP  # noqa: E402
from mermi_proto import cl, hx, asset, label, grass  # noqa: E402
from bicak_proto import blit, header, stack_v, save_gif  # noqa: E402
import yinyang_sanat as YS  # noqa: E402

OUT = YS.OUT
ZOOM = 2.0
WPP = 0.575
CHAR_K = 2.2368375 * 0.8075 * 0.5
SLIME_K = 0.94905
FPS = 50
FXFPS = 30
INTERVAL = 1.2 / 0.7
LOOP = 2.0 * INTERVAL
T_FIRST = 0.15
LV_ART = 3
FX_K = 1.45  # efekt piksel boyları (yarıçap / kalınlık) çarpanı: ilk sürüm oyun ölçeğinde fazla ince okunuyordu

LWW, LHW = 270, 190
AW, AH = int(LWW / WPP) + 2, int(LHW / WPP) + 2
_YY, _XX = np.mgrid[0:AH, 0:AW]

CHAR = (96.0, 92.0)
ALLY = (46.0, 136.0)
REST = (CHAR[0] + 17.0, CHAR[1] - 15.0)
SLIMES = [(200.0, 60.0), (206.0, 128.0), (244.0, 94.0)]
ATTACKS = [dict(tgt=0, rcp=ALLY, name="yang -> DOSTA"), dict(tgt=1, rcp=CHAR, name="yang -> KENDİNE")]

INK = cl("#0c0a12 #1c1826 #2e2a3a #4a4458")
INK_OL = hx("#060509")
CREAM = cl("#fffdf6 #f2ead6 #d8ccae #aa9e82")
CREAM_OL = hx("#6e6450")
SEAL = hx("#b8302a")
PAPER = cl("#fffaee #ebe3cf #c9bea4")


def S(p):
    return (p[0] * ZOOM, p[1] * ZOOM)


def A(p):
    """dünya -> sanat pikseli (efekt ızgarası)"""
    return (p[0] / WPP, p[1] / WPP)


def lerp(p, q, e):
    return (p[0] + (q[0] - p[0]) * e, p[1] + (q[1] - p[1]) * e)


def unit(v):
    L = math.hypot(*v) or 1.0
    return (v[0] / L, v[1] / L)


def clamp01(x):
    return max(0.0, min(1.0, x))


def ez(kind, x):
    x = clamp01(x)
    if kind == "out":
        return 1.0 - (1.0 - x) ** 3
    if kind == "in":
        return x ** 3
    if kind == "inout":
        return 3 * x * x - 2 * x * x * x
    return x


def bez(p0, p1, p2, u):
    v = 1.0 - u
    return (v * v * p0[0] + 2 * v * u * p1[0] + u * u * p2[0], v * v * p0[1] + 2 * v * u * p1[1] + u * u * p2[1])


def bez_len(p0, p1, p2, n=16):
    pts = [bez(p0, p1, p2, i / float(n)) for i in range(n + 1)]
    return sum(math.dist(a, b) for a, b in zip(pts, pts[1:]))


def body(p):
    return (p[0], p[1] + 3.0)


def feet(p):
    return (p[0], p[1] + 17.0)


def slime_body(p):
    return (p[0], p[1] + 1.0)


# ------------------------------------------------------------------ efekt katmanı: gerçek saydamlık (dither YOK)
class Lyr:
    def __init__(self):
        self.c = np.zeros((AH, AW, 3), np.float32)
        self.a = np.zeros((AH, AW), np.float32)

    def over(self, y0, x0, mask, col, alpha=1.0):
        h, w = mask.shape
        if h <= 0 or w <= 0 or not mask.any():
            return
        sc = self.c[y0:y0 + h, x0:x0 + w]
        sa = self.a[y0:y0 + h, x0:x0 + w]
        al = mask.astype(np.float32) * np.asarray(alpha, np.float32)
        col = np.asarray(col, np.float32)
        if col.ndim == 1:
            col = np.broadcast_to(col, (h, w, 3))
        oa = al + sa * (1.0 - al)
        num = col * al[..., None] + sc * (sa * (1.0 - al))[..., None]
        sc[...] = np.where(oa[..., None] > 1e-6, num / np.maximum(oa[..., None], 1e-6), sc)
        sa[...] = oa

    def put(self, x, y, col, alpha=1.0):
        x, y = int(x), int(y)
        if 0 <= x < AW and 0 <= y < AH:
            self.over(y, x, np.ones((1, 1), bool), col, alpha)


def win(cx, cy, r, pad=2):
    x0, x1 = max(0, int(cx - r - pad)), min(AW, int(cx + r + pad) + 1)
    y0, y1 = max(0, int(cy - r - pad)), min(AH, int(cy + r + pad) + 1)
    if x0 >= x1 or y0 >= y1:
        return None
    return x0, x1, y0, y1, _XX[y0:y1, x0:x1] + 0.5 - cx, _YY[y0:y1, x0:x1] + 0.5 - cy


def dilate(m):
    d = m.copy()
    d[1:] |= m[:-1]
    d[:-1] |= m[1:]
    d[:, 1:] |= m[:, :-1]
    d[:, :-1] |= m[:, 1:]
    return d


def disc(L, p, r, col, alpha=1.0, ol=None):
    r *= FX_K
    cx, cy = A(p)
    w = win(cx, cy, r)
    if not w or r <= 0.2:
        return
    x0, x1, y0, y1, X, Y = w
    m = np.hypot(X, Y) <= r
    if ol is not None:
        L.over(y0, x0, dilate(m) & ~m, ol, alpha)
    L.over(y0, x0, m, col, alpha)


def yy_disc(L, p, r, rot, alpha=1.0, part=None, ol=INK_OL, dark=INK[2], light=CREAM[1]):
    """Dönen yin-yang (r sanat px). part 'yin' / 'yang' -> yalnız o yarı (balık)."""
    r *= FX_K
    cx, cy = A(p)
    w = win(cx, cy, r)
    if not w:
        return
    x0, x1, y0, y1, X, Y = w
    g = YS.YY(0.0, 0.0, r, rot=rot or 1e-4)
    g.dtop, g.dbot = g.top, g.bot  # kayan küre: piksel köşesine oturtma yok
    g.dr = max(0.8, r * 0.2)
    ins = np.hypot(X, Y) <= r
    side = np.zeros(X.shape, bool)  # True = yang
    for iy in range(X.shape[0]):
        for ix in range(X.shape[1]):
            if ins[iy, ix]:
                side[iy, ix] = g.side(X[iy, ix], Y[iy, ix]) == "yang"
    if part == "yin":
        m = ins & ~side
    elif part == "yang":
        m = ins & side
    else:
        m = ins
    if ol is not None:
        L.over(y0, x0, dilate(m) & ~m, ol, alpha)
    col = np.where(side[..., None], np.array(light, np.float32), np.array(dark, np.float32))
    ## ışık sol-üst: kenar tonları
    edge = (X + Y) / max(r, 1.0)
    col = np.where((edge < -0.9)[..., None] & side[..., None], np.array(CREAM[0], np.float32), col)
    col = np.where((edge > 0.9)[..., None] & ~side[..., None], np.array(INK[1], np.float32), col)
    L.over(y0, x0, m, col, alpha)


def trail(L, pts, w0, cols, alpha=1.0, ol=None, grow_head=False):
    """Sivrilen iz: pts dünya, en yeni önce; w0 sanat px (baş kalınlığı)."""
    if len(pts) < 2:
        return
    w0 *= FX_K
    Pp = [A(p) for p in pts]
    xs = [p[0] for p in Pp]
    ys = [p[1] for p in Pp]
    x0, x1 = max(0, int(min(xs) - w0 - 2)), min(AW, int(max(xs) + w0 + 3))
    y0, y1 = max(0, int(min(ys) - w0 - 2)), min(AH, int(max(ys) + w0 + 3))
    if x0 >= x1 or y0 >= y1:
        return
    X = _XX[y0:y1, x0:x1] + 0.5
    Y = _YY[y0:y1, x0:x1] + 0.5
    best = np.full(X.shape, 1e9, np.float32)
    bs = np.zeros(X.shape, np.float32)
    bd = np.full(X.shape, 1e9, np.float32)
    bhw = np.zeros(X.shape, np.float32)
    n = len(Pp)
    for j in range(n - 1):
        ax, ay = Pp[j]
        bx, by = Pp[j + 1]
        dx, dy = bx - ax, by - ay
        ln2 = max(dx * dx + dy * dy, 1e-6)
        u = np.clip(((X - ax) * dx + (Y - ay) * dy) / ln2, 0.0, 1.0)
        d = np.hypot(X - (ax + u * dx), Y - (ay + u * dy))
        s = (j + u) / (n - 1)
        hw = 0.5 * w0 * (1.0 - s) ** 0.8 + 0.35
        r = d / hw
        upd = r < best
        best = np.where(upd, r, best)
        bs = np.where(upd, s, bs)
        bd = np.where(upd, d, bd)
        bhw = np.where(upd, hw, bhw)
    inside = best <= 1.0
    ci = np.where(best < 0.45, 0, np.where(best < 0.85, 1, 2)) + (bs > 0.6)
    C = np.array(cols, np.float32)[np.minimum(ci, len(cols) - 1)]
    a = alpha * (1.0 - np.clip((bs - 0.5) / 0.5, 0.0, 1.0) * 0.8)
    if ol is not None:
        olm = (~inside) & (bd <= bhw + 1.0) & (bhw > 0.9) & (bs < 0.75)
        L.over(y0, x0, olm, ol, a)
    L.over(y0, x0, inside, C, a)


def stroke(L, pts, widths, col, alpha=1.0, ol=None, dry=0.0, seed=0, light=None):
    """Fırça çizgisi: pts dünya (baştan sona), widths her nokta için sanat px yarı genişlik; dry > 0 kuru fırça çizgileri."""
    if len(pts) < 2:
        return
    widths = [w * FX_K for w in widths]
    Pp = [A(p) for p in pts]
    wmax = max(widths) + 2
    xs = [p[0] for p in Pp]
    ys = [p[1] for p in Pp]
    x0, x1 = max(0, int(min(xs) - wmax)), min(AW, int(max(xs) + wmax + 1))
    y0, y1 = max(0, int(min(ys) - wmax)), min(AH, int(max(ys) + wmax + 1))
    if x0 >= x1 or y0 >= y1:
        return
    X = _XX[y0:y1, x0:x1] + 0.5
    Y = _YY[y0:y1, x0:x1] + 0.5
    best = np.full(X.shape, 1e9, np.float32)
    side = np.zeros(X.shape, np.float32)
    bs = np.zeros(X.shape, np.float32)
    n = len(Pp)
    for j in range(n - 1):
        ax, ay = Pp[j]
        bx, by = Pp[j + 1]
        dx, dy = bx - ax, by - ay
        ln2 = max(dx * dx + dy * dy, 1e-6)
        u = np.clip(((X - ax) * dx + (Y - ay) * dy) / ln2, 0.0, 1.0)
        d = np.hypot(X - (ax + u * dx), Y - (ay + u * dy))
        hw = widths[j] + (widths[j + 1] - widths[j]) * u
        r = d / np.maximum(hw, 0.3)
        cr = ((X - ax) * dy - (Y - ay) * dx) / math.sqrt(ln2)  # işaretli yan uzaklık
        upd = r < best
        best = np.where(upd, r, best)
        side = np.where(upd, cr / np.maximum(hw, 0.3), side)
        bs = np.where(upd, (j + u) / (n - 1), bs)
    inside = best <= 1.0
    if dry > 0.0:
        ## kuru fırça: yan uzaklığa göre bantlar, kuyrukta (bs büyük) daha çok boşluk
        lane = np.floor((side + 1.0) * 3.5).astype(np.int64)
        rnd = (((lane * 73856093) ^ (seed * 19349663)) & 0xFFFF).astype(np.float32) / 65535.0
        gap = (rnd < dry * (0.25 + 0.9 * bs)) & (np.abs(side) > 0.25)
        inside &= ~gap
    if ol is not None:
        L.over(y0, x0, dilate(inside) & ~inside, ol, alpha)
    C = np.broadcast_to(np.array(col, np.float32), X.shape + (3,)).copy()
    if light is not None:
        C[(side < -0.35) & inside] = light
    L.over(y0, x0, inside, C, alpha)


def ring(L, p, rx, ry, w, col, alpha=1.0, ol=None, sweep=None, a0=0.0):
    """Elips halka (dünya rx, ry; w sanat px kalınlık). sweep (radyan) verilirse a0'dan başlayan yay, uçlara incelir."""
    w *= FX_K
    cx, cy = A(p)
    Rx, Ry = rx / WPP, ry / WPP
    w_ = win(cx, cy, max(Rx, Ry) + w)
    if not w_:
        return
    x0, x1, y0, y1, X, Y = w_
    t = np.arctan2(Y / Ry, X / Rx)
    rho = np.hypot(X / Rx, Y / Ry)
    rt = np.hypot(Rx * np.cos(t), Ry * np.sin(t))
    d = (1.0 - rho) * rt
    ww = np.full(X.shape, float(w), np.float32)
    if sweep is not None:
        rel = (t - a0) % (2 * math.pi)
        f = rel / max(sweep, 1e-3)
        ww = np.where(f <= 1.0, w * np.clip(np.minimum(f, 1.0 - f) * 5.0, 0.25, 1.0), -1.0)
    m = (d >= -ww * 0.5) & (d < ww * 0.5)
    if ol is not None:
        L.over(y0, x0, dilate(m) & ~m, ol, alpha)
    L.over(y0, x0, m, col, alpha)


def star4(L, p, r, cols, alpha=1.0):
    x, y = (int(q) for q in A(p))
    r = int(round(r * FX_K))
    if r <= 0:
        return
    for i in range(-r, r + 1):
        k = abs(i) / float(r)
        col = cols[min(len(cols) - 1, int(k * len(cols)))]
        L.put(x + i, y, col, alpha)
        L.put(x, y + i, col, alpha)
    for i in range(1, max(1, r // 2)):
        for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            L.put(x + sx * i, y + sy * i, cols[min(len(cols) - 1, 1 + i)], alpha)


def rect_card(L, p, hw, hh, col, ol, alpha=1.0, seal=False):
    hw, hh = hw * FX_K, hh * FX_K
    cx, cy = A(p)
    w = win(cx, cy, max(hw, hh) + 1)
    if not w:
        return
    x0, x1, y0, y1, X, Y = w
    m = (np.abs(X) <= hw) & (np.abs(Y) <= hh)
    L.over(y0, x0, dilate(m) & ~m, ol, alpha)
    C = np.broadcast_to(np.array(col, np.float32), X.shape + (3,)).copy()
    if seal and hw >= 1.2:
        C[(np.hypot(X, Y + hh * 0.15) <= 1.3)] = SEAL
        C[(np.abs(X) < 0.6) & (Y > hh * 0.35) & (Y < hh - 0.6)] = INK[2]
        C[(np.abs(X) < 0.6) & (Y < -hh * 0.55) & (Y > -hh + 0.6)] = INK[2]
    L.over(y0, x0, m, C, alpha)


def rng_list(seed, n, f):
    r = random.Random(seed)
    return [f(r) for _ in range(n)]


# ------------------------------------------------------------------ zaman çizelgesi
class Shot:
    """Bir vuruşun geometrisi + zamanları (saldırı başından sn)."""

    def __init__(self, att, did):
        self.att = att
        self.did = did
        self.src = (REST[0], REST[1] - 1.0)
        self.tgt = slime_body(SLIMES[att["tgt"]])
        self.rcp = body(att["rcp"])
        self.self_rcp = att["rcp"] is CHAR
        d = unit((self.tgt[0] - self.src[0], self.tgt[1] - self.src[1]))
        self.d = d
        mid = lerp(self.src, self.tgt, 0.5)
        arc = {"A": 10.0, "B": 0.0, "C": 18.0, "D": 7.0}[did]
        self.c1 = (mid[0], mid[1] - arc)
        L = bez_len(self.src, self.c1, self.tgt)
        self.t_launch = {"A": 0.10, "B": 0.10, "C": 0.12, "D": 0.08}[did]
        speed = {"A": 300.0, "B": 300.0, "C": 250.0, "D": 900.0}[did]
        self.flight = L / speed
        self.t_hit = self.t_launch + self.flight
        ## dönüş yayı: hedef -> alıcı, yukarı kavisli
        ## dosta: kitabın sahibinden UZAK tarafa eğilir (yoksa sahibine dönüyor gibi okunur); kendine: yukarı
        mid2 = lerp(self.tgt, self.rcp, 0.5)
        dist2 = math.dist(self.tgt, self.rcp)
        nv = unit((-(self.rcp[1] - self.tgt[1]), self.rcp[0] - self.tgt[0]))
        bow = max(14.0, dist2 * 0.3)
        ca = (mid2[0] + nv[0] * bow, mid2[1] + nv[1] * bow)
        cb = (mid2[0] - nv[0] * bow, mid2[1] - nv[1] * bow)
        if self.self_rcp:
            self.c2 = ca if ca[1] < cb[1] else cb
        else:
            own = body(CHAR)
            self.c2 = ca if math.dist(ca, own) > math.dist(cb, own) else cb
        L2 = bez_len(self.tgt, self.c2, self.rcp)
        self.t_ret = self.t_hit + {"A": 0.04, "B": 0.03, "C": 0.16, "D": 0.06}[did]
        rs = {"A": 240.0, "B": 230.0, "C": 210.0, "D": 520.0}[did]
        self.ret = L2 / rs
        self.t_arr = self.t_ret + self.ret
        if did == "B":
            ## v2 (kullanıcı: "hedeften hedefe atlamasın, atıldığı anda ikiye bölünsün, kitaptan havaya yükselip ayrılsın"):
            ## iki küre kitaptan sarmal çizerek yükselir, tepede ayrılır: kara -> düşman, ak -> kalkanı alan (aynı anda)
            self.t_split = self.t_launch + B_RISE
            dk0, lt0, _ = B_rise(self, self.t_split)
            self.dk0, self.lt0 = dk0, lt0
            self.cd = (dk0[0] + (self.tgt[0] - dk0[0]) * 0.4, min(dk0[1], self.tgt[1]) - 8.0)
            self.flight_d = bez_len(dk0, self.cd, self.tgt) / B_SPEED_DARK
            self.t_hit = self.t_split + self.flight_d
            if self.self_rcp:
                self.cl = (lt0[0] - 6.0, lt0[1] - 12.0)
            else:
                m2 = lerp(lt0, self.rcp, 0.5)
                nv2 = unit((-(self.rcp[1] - lt0[1]), self.rcp[0] - lt0[0]))
                bw = max(12.0, math.dist(lt0, self.rcp) * 0.25)
                ca2 = (m2[0] + nv2[0] * bw, m2[1] + nv2[1] * bw)
                cb2 = (m2[0] - nv2[0] * bw, m2[1] - nv2[1] * bw)
                own = body(CHAR)
                self.cl = ca2 if math.dist(ca2, own) > math.dist(cb2, own) else cb2
            self.flight_l = max(0.22, bez_len(lt0, self.cl, self.rcp) / B_SPEED_LIGHT)
            self.t_ret, self.ret = self.t_split, self.flight_l
            self.t_arr = self.t_split + self.flight_l

    def proj(self, ta):
        u = clamp01((ta - self.t_launch) / self.flight)
        return bez(self.src, self.c1, self.tgt, u), u

    def back(self, ta, e="inout"):
        u = clamp01((ta - self.t_ret) / self.ret)
        return bez(self.tgt, self.c2, self.rcp, ez(e, u) if e else u), u


# ------------------------------------------------------------------ efektler: (yer katmanı Lg, ön katman Lf, shot, ta)
A_DROPS = rng_list(5, 8, lambda r: (r.uniform(0, 2 * math.pi), r.uniform(26.0, 48.0), r.uniform(1.2, 2.2)))


def A_fx(sh, Lg, Lf, ta):
    if sh.t_launch <= ta < sh.t_hit:
        pos, u = sh.proj(ta)
        past = [sh.proj(max(sh.t_launch, ta - k * 0.014))[0] for k in range(7)]
        trail(Lf, past, 5.0, CREAM, 0.75, ol=None)
        yy_disc(Lf, pos, 5.0, ta * 13.0)
    age = ta - sh.t_hit
    if age >= 0.0:
        if age < 0.07:
            star4(Lf, sh.tgt, 7.0 * (1.0 - age / 0.07) + 1.0, CREAM)
        if age < 0.2:  # kara yarı düşmana gömülür
            k = age / 0.2
            p = (sh.tgt[0] + sh.d[0] * 3.0 * k, sh.tgt[1] + sh.d[1] * 3.0 * k)
            yy_disc(Lf, p, 5.0 * (1.0 - 0.4 * k), sh.t_hit * 13.0, alpha=1.0 - k, part="yin")
        if age < 0.34:  # mürekkep damlaları + ince halka
            k = age / 0.34
            for (th, v, r) in A_DROPS:
                dd = v * 0.34 * ez("out", k)
                p = (sh.tgt[0] + math.cos(th) * dd, sh.tgt[1] + math.sin(th) * dd * 0.7 + 10.0 * k * k)
                disc(Lf, p, r * (1.0 - 0.6 * k), INK[2], 1.0 - k * k, ol=INK_OL)
            if age < 0.24:
                ring(Lf, sh.tgt, 3.0 + 9.0 * ez("out", age / 0.24), 2.0 + 6.0 * ez("out", age / 0.24), 1.6, INK[3], 0.9 * (1.0 - age / 0.24))
    ## ak yarı geri döner
    if sh.t_ret <= ta < sh.t_arr:
        pos, u = sh.back(ta)
        past = [sh.back(max(sh.t_ret, ta - k * 0.016))[0] for k in range(8)]
        trail(Lf, past, 4.0, CREAM, 0.8, ol=CREAM_OL)
        yy_disc(Lf, pos, 4.6, sh.t_hit * 13.0 + (ta - sh.t_ret) * 9.0, part="yang", ol=CREAM_OL)
    arrival_ring(sh, Lg, Lf, ta)


def arrival_ring(sh, Lg, Lf, ta, n_spark=4):
    age = ta - sh.t_arr
    if 0.0 <= age < 0.45:
        k = age / 0.45
        e = ez("out", k)
        ring(Lf, sh.rcp, 5.0 + 9.0 * e, 3.0 + 5.0 * e, 2.0 * (1.0 - 0.5 * k) + 0.6, CREAM[1], 1.0 - k, ol=CREAM_OL if k < 0.5 else None)
        for i in range(n_spark):
            th = i * 2 * math.pi / n_spark + 0.4
            p = (sh.rcp[0] + math.cos(th) * (6.0 + 6.0 * e), sh.rcp[1] + math.sin(th) * 3.0 - 9.0 * e)
            star4(Lf, p, 2.6 * (1.0 - k) + 0.6, CREAM, 1.0 - k * k)


B_SHARDS = rng_list(9, 6, lambda r: (r.uniform(0, 2 * math.pi), r.uniform(30.0, 55.0)))


B_RISE = 0.2         # kitaptan yükselme (sn)
B_RISE_H = 13.0      # yükselme yüksekliği (dünya px)
B_SPIN_R = 3.6       # sarmal yarıçapı (dünya px)
B_SPEED_DARK = 330.0
B_SPEED_LIGHT = 230.0


def B_rise(sh, ta):
    """Yükselme: iki küre ortak merkezin çevresinde (yere yatık elips) dönerek kitaptan çıkar -> (kara, ak, kara önde mi)."""
    tau = clamp01((ta - sh.t_launch) / B_RISE)
    e = ez("out", tau)
    c = (sh.src[0] + sh.d[0] * 4.0 * e, sh.src[1] - B_RISE_H * e)
    r = B_SPIN_R * e
    ph = 2 * math.pi * 1.6 * tau + 0.6
    o = (math.cos(ph) * r, math.sin(ph) * r * 0.6)
    return (c[0] + o[0], c[1] + o[1]), (c[0] - o[0], c[1] - o[1]), math.sin(ph)


def B_dark(sh, ta):
    if ta < sh.t_split:
        return B_rise(sh, ta)[0]
    u = clamp01((ta - sh.t_split) / sh.flight_d)
    return bez(sh.dk0, sh.cd, sh.tgt, 0.3 * u * u + 0.7 * u)


def B_light(sh, ta):
    if ta < sh.t_split:
        return B_rise(sh, ta)[1]
    u = clamp01((ta - sh.t_split) / sh.flight_l)
    return bez(sh.lt0, sh.cl, sh.rcp, ez("inout", u))


def B_fx(sh, Lg, Lf, ta):
    if sh.t_launch <= ta < max(sh.t_hit, sh.t_arr):
        _, _, front = B_rise(sh, min(ta, sh.t_split))
        draws = []
        if ta < sh.t_hit:
            pd = [B_dark(sh, max(sh.t_launch, ta - k * 0.014)) for k in range(8)]
            draws.append((pd, INK[2], INK_OL, INK[1:], None))
        if ta < sh.t_arr:
            pl = [B_light(sh, max(sh.t_launch, ta - k * 0.014)) for k in range(8)]
            draws.append((pl, CREAM[1], CREAM_OL, CREAM, CREAM_OL if ta >= sh.t_split else None))
        if ta < sh.t_split and front > 0:  # yükselirken önde olan sonra çizilir
            draws.reverse()
        for pts, c, o, tc, tol in draws:
            trail(Lf, pts, 2.6, tc, 0.8, ol=tol)
        for pts, c, o, tc, tol in draws:
            disc(Lf, pts[0], 2.6, c, ol=o)
    age = ta - sh.t_hit
    if 0.0 <= age < 0.3:
        k = age / 0.3
        for (th, v) in B_SHARDS:
            r0, r1 = v * 0.3 * ez("out", k), v * 0.3 * ez("out", k) + 4.0 * (1.0 - k)
            p0 = (sh.tgt[0] + math.cos(th) * r0, sh.tgt[1] + math.sin(th) * r0 * 0.75)
            p1 = (sh.tgt[0] + math.cos(th) * r1, sh.tgt[1] + math.sin(th) * r1 * 0.75)
            trail(Lf, [p0, p1], 2.2 * (1.0 - k) + 0.8, INK[1:], 1.0 - k)
        if age < 0.2:
            ring(Lf, sh.tgt, 3.0 + 8.0 * ez("out", age / 0.2), 2.5 + 5.0 * ez("out", age / 0.2), 1.4, INK[2], 1.0 - age / 0.2)
        if age < 0.06:
            star4(Lf, sh.tgt, 5.0 * (1.0 - age / 0.06) + 1.0, CREAM)
    age = ta - sh.t_arr
    if 0.0 <= age < 0.32:  # belde bir tur
        k = age / 0.32
        th = -math.pi / 2 + 2 * math.pi * ez("inout", k)
        pts = []
        for j in range(8):
            tj = th - j * 0.22
            pts.append((sh.rcp[0] + math.cos(tj) * 9.0, sh.rcp[1] + 2.0 + math.sin(tj) * 4.5))
        trail(Lf if math.sin(th) > 0 else Lg, pts, 2.6, CREAM, 0.9, ol=CREAM_OL)
        disc(Lf if math.sin(th) > 0 else Lg, pts[0], 2.4, CREAM[0], ol=CREAM_OL)
    if 0.32 <= age < 0.62:
        k = (age - 0.32) / 0.3
        for i in range(6):
            a = i * math.pi / 3 + 0.3
            p = (sh.rcp[0] + math.cos(a) * (4.0 + 8.0 * ez("out", k)), sh.rcp[1] + 2.0 + math.sin(a) * (2.0 + 4.0 * ez("out", k)))
            star4(Lf, p, 2.2 * (1.0 - k) + 0.5, CREAM, 1.0 - k)


C_FLAKES = rng_list(13, 6, lambda r: (r.uniform(0, 2 * math.pi), r.uniform(8.0, 14.0), r.uniform(-14.0, 14.0), r.uniform(0.0, 0.07),
                                      r.choice([(1.6, 2.2), (2.2, 1.6), (1.9, 1.9)])))


def C_fx(sh, Lg, Lf, ta):
    if sh.t_launch <= ta < sh.t_hit:
        pos, u = sh.proj(ta)
        fl = abs(math.cos(ta * 17.0))
        rect_card(Lf, pos, 4.2 * max(0.25, fl), 6.2, PAPER[0] if fl > 0.5 else PAPER[2], CREAM_OL, seal=fl > 0.45)
    age = ta - sh.t_hit
    if 0.0 <= age < sh.t_ret - sh.t_hit:  # yapışır, titrer
        j = 0.5 * math.sin(age * 90.0)
        rect_card(Lf, (sh.tgt[0] + j, sh.tgt[1] - 1.0), 4.2, 6.2, PAPER[0], CREAM_OL, seal=True)
    if 0.0 <= age < 0.55:  # yerde mürekkep mührü
        k = age / 0.55
        rr = 7.0 + 3.0 * ez("out", min(1.0, age / 0.12))
        al = 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
        f = feet((SLIMES[sh.att["tgt"]][0], SLIMES[sh.att["tgt"]][1] - 10.0))
        ring(Lg, f, rr, rr * 0.5, 2.2, INK[2], al, sweep=2 * math.pi * ez("out", min(1.0, age / 0.14)), a0=-2.0)
        ring(Lg, f, rr * 0.55, rr * 0.27, 1.3, SEAL, al * 0.9)
    ## kâğıt parçaları alıcıya süzülür
    t0 = sh.t_ret
    if ta >= t0 and ta < sh.t_arr + 0.08:
        for i, (th, burst, side, dl, (hw, hh)) in enumerate(C_FLAKES):
            tt = ta - t0 - dl
            if tt < 0.0:
                p = sh.tgt
            else:
                pop = ez("out", min(1.0, tt / 0.1))
                bp = (sh.tgt[0] + math.cos(th) * burst * pop, sh.tgt[1] + math.sin(th) * burst * 0.6 * pop)
                u = clamp01((tt - 0.06) / max(0.05, sh.ret - 0.06))
                c2 = (sh.c2[0] + side, sh.c2[1] + side * 0.4)
                p = bez(bp, c2, sh.rcp, ez("inout", u)) if tt > 0.06 else bp
                if u >= 1.0:
                    continue
            fl = abs(math.cos(ta * 15.0 + i))
            rect_card(Lf, p, hw * max(0.3, fl), hh, PAPER[0] if fl > 0.5 else PAPER[1], CREAM_OL)
    age = ta - sh.t_arr
    if 0.0 <= age < 0.45:
        k = age / 0.45
        ring(Lf, sh.rcp, 9.0 + 3.0 * ez("out", k), 4.5 + 1.5 * ez("out", k), 2.2 * (1.0 - 0.5 * k), PAPER[0], 1.0 - k * k, ol=CREAM_OL if k < 0.6 else None,
             sweep=2 * math.pi * ez("out", min(1.0, age / 0.12)), a0=-1.6)


D_BLOTS = rng_list(21, 6, lambda r: (r.uniform(-5.0, 5.0), r.uniform(-4.0, 4.0), r.uniform(1.4, 3.2), r.uniform(0.0, 0.05)))
D_SPLAT = rng_list(22, 7, lambda r: (r.uniform(-1.2, 1.2), r.uniform(25.0, 45.0), r.uniform(0.9, 1.6)))


def D_curve(p0, c, p1, n=18):
    return [bez(p0, c, p1, i / float(n)) for i in range(n + 1)]


def D_widths(n, peak, head=0.7, tail=0.35):
    out = []
    for i in range(n + 1):
        s = i / float(n)
        w = peak * (min(1.0, s / 0.35) ** 0.6) * (1.0 - max(0.0, s - 0.75) / 0.25 * 0.55)
        out.append(max(tail, w) if i else head)
    return out


def D_fx(sh, Lg, Lf, ta):
    n = 18
    pts = D_curve(sh.src, sh.c1, sh.tgt, n)
    wd = D_widths(n, 2.8)
    if ta >= sh.t_launch:
        head = clamp01((ta - sh.t_launch) / sh.flight)
        fade = clamp01((ta - sh.t_hit - 0.10) / 0.2)
        i1 = int(round(head * n))
        i0 = int(round(fade * n))
        if i1 - i0 >= 1 and fade < 1.0:
            stroke(Lf, pts[i0:i1 + 1], wd[i0:i1 + 1], INK[1], 1.0 - 0.6 * fade, ol=None, dry=0.55, seed=3, light=INK[2])
    age = ta - sh.t_hit
    if 0.0 <= age < 0.42:
        k = age / 0.42
        al = 1.0 if k < 0.55 else 1.0 - (k - 0.55) / 0.45
        for (ox, oy, r, dl) in D_BLOTS:
            if age >= dl:
                disc(Lf, (sh.tgt[0] + ox, sh.tgt[1] + oy * 0.7), r * min(1.0, (age - dl) / 0.05), INK[1], al, ol=INK_OL)
        for (dx, v, r) in D_SPLAT:
            th = math.atan2(sh.d[1], sh.d[0]) + dx
            dd = v * 0.3 * ez("out", min(1.0, age / 0.3))
            if age < 0.3:
                disc(Lf, (sh.tgt[0] + math.cos(th) * dd, sh.tgt[1] + math.sin(th) * dd * 0.7 + 8.0 * k * k), r, INK[2], 1.0 - age / 0.3, ol=INK_OL)
    ## ak fırça dönüşü
    pts2 = D_curve(sh.tgt, sh.c2, sh.rcp, n)
    wd2 = D_widths(n, 2.2)
    if ta >= sh.t_ret:
        head = clamp01((ta - sh.t_ret) / sh.ret)
        fade = clamp01((ta - sh.t_arr - 0.06) / 0.2)
        i1 = int(round(ez("out", head) * n))
        i0 = int(round(fade * n))
        if i1 - i0 >= 1 and fade < 1.0:
            stroke(Lf, pts2[i0:i1 + 1], wd2[i0:i1 + 1], CREAM[1], 1.0 - 0.5 * fade, ol=CREAM_OL, dry=0.35, seed=7, light=CREAM[0])
    age = ta - sh.t_arr
    if 0.0 <= age < 0.5:  # ayakta ak enso
        k = age / 0.5
        sw = 2 * math.pi * 0.9 * ez("out", min(1.0, age / 0.16))
        al = 1.0 if k < 0.5 else 1.0 - (k - 0.5) / 0.5
        f = feet((sh.rcp[0], sh.rcp[1] - 3.0))
        ring(Lg, f, 11.0, 5.5, 2.6, CREAM[1], al, ol=CREAM_OL, sweep=sw, a0=2.4)


SPEC = {
    "A": dict(title="A - Dönen Küre", sub="dönen yin-yang; kara yarı düşmanda dağılır, ak yarı alıcıya uçar"),
    "B": dict(title="B - İkiz Sarmal", sub="kara + ak küre sarmal uçar; kara vurur, ak sarmal izle döner"),
    "C": dict(title="C - Kâğıt Tılsım", sub="sayfa kopar, tılsım yapışır; yerde mühür, ak parçalar alıcıya"),
    "D": dict(title="D - Fırça Darbesi", sub="mürekkep fırça çizgisi + leke; ak fırça alıcıya, ayakta enso"),
}
FX = {"A": A_fx, "B": B_fx, "C": C_fx, "D": D_fx}
ORDER = ["A", "B", "C", "D"]


# ------------------------------------------------------------------ şerit
_BG = {}
_MAP = {}
BOOK = {}


def lane_bg(idx):
    if idx not in _BG:
        g = grass(int(LWW * ZOOM), int(LHW * ZOOM), 71 + idx)
        _BG[idx] = np.asarray(g.convert("RGB"), dtype=np.float32).copy()
    return _BG[idx].copy()


def comp(F, L):
    H, W = F.shape[:2]
    if (H, W) not in _MAP:
        k = WPP * ZOOM
        U = np.clip(((np.arange(W) + 0.5) / k).astype(np.int32), 0, AW - 1)
        V = np.clip(((np.arange(H) + 0.5) / k).astype(np.int32), 0, AH - 1)
        _MAP[(H, W)] = (U, V)
    U, V = _MAP[(H, W)]
    a = L.a[V][:, U][..., None]
    if not a.any():
        return
    c = L.c[V][:, U]
    F[...] = F * (1.0 - a) + c * a


def slime():
    return asset("visuals/Yaratıklar/Tüm Yaratıklar/Slime 1/PNG/Slime1/With_shadow/Slime1_Walk_with_shadow.png", (0, 0, 64, 64))


def char_img(who):
    return asset("assets/characters/%s/sheets/idle.png" % who, (0, 96, 48, 144))


class Lane:
    def __init__(self, did, idx, t_first=T_FIRST, atts=(0, 1)):
        self.did, self.idx = did, idx
        self.t_first = t_first
        self.atts = atts
        self.shots = [Shot(ATTACKS[a], did) for a in atts]
        self.cache = {}

    def attack(self, t):
        if t < self.t_first:
            return -1.0, -1
        n = int((t - self.t_first) // INTERVAL)
        return t - self.t_first - n * INTERVAL, n

    def layers(self, t):
        """Son iki vuruşun efektleri (önceki vuruşun varışı yenisine taşabilir); 30 fps'e kuantalı."""
        q = int(t * FXFPS)
        if q in self.cache:
            return self.cache[q]
        tq = q / float(FXFPS)
        Lg, Lf = Lyr(), Lyr()
        ta, n = self.attack(tq)
        for back in (1, 0):
            m = n - back
            if m < 0:
                continue
            sh = self.shots[m % len(self.shots)]
            FX[self.did](sh, Lg, Lf, ta + back * INTERVAL)
        self.cache[q] = (Lg, Lf)
        return Lg, Lf

    def flash_of(self, t):
        """-> (hedef slime indeksi -> beyaz parlama), (alıcı -> krem parlama), kitap (kalkış, parlama)"""
        ta, n = self.attack(t)
        hit, rcv = {}, {}
        lift, glow = 0.0, 0.0
        for back in (1, 0):
            m = n - back
            if m < 0:
                continue
            sh = self.shots[m % len(self.shots)]
            a = ta + back * INTERVAL
            h = a - sh.t_hit
            if 0.0 <= h < 0.1:
                hit[sh.att["tgt"]] = 0.6 * (1.0 - h / 0.1)
            r = a - sh.t_arr
            if 0.0 <= r < 0.14:
                rcv[id(sh.att["rcp"])] = 0.5 * (1.0 - r / 0.14)
            if back == 0:
                if a < sh.t_launch:
                    e = a / sh.t_launch
                    lift, glow = 2.0 * ez("out", e), 0.55 * e
                elif a < sh.t_launch + 0.2:
                    e = (a - sh.t_launch) / 0.2
                    lift, glow = 2.0 * (1.0 - ez("inout", e)), 0.55 * (1.0 - e)
        return hit, rcv, lift, glow

    def render(self, t):
        F = lane_bg(self.idx)
        Lg, Lf = self.layers(t)
        comp(F, Lg)
        hit, rcv, lift, glow = self.flash_of(t)
        items = [(CHAR[1] + 18.0, "char", (CHAR, "talon")), (ALLY[1] + 18.0, "char", (ALLY, "sovalye"))]
        for i, p in enumerate(SLIMES):
            items.append((p[1] + 7.0, "slime", (p, i)))
        for _, kind, data in sorted(items, key=lambda q: q[0]):
            if kind == "char":
                p, who = data
                x, y = S(p)
                blit(F, char_img(who), x, y, CHAR_K * ZOOM)
                fl = rcv.get(id(p), 0.0)
                if fl > 0.0:
                    blit(F, char_img(who), x, y, CHAR_K * ZOOM, alpha=fl, tint=(255, 248, 226))
                continue
            p, i = data
            x, y = S(p)
            blit(F, slime(), x, y - 2, SLIME_K * ZOOM)
            if i in hit:
                blit(F, slime(), x, y - 2, SLIME_K * ZOOM, alpha=hit[i], tint=(255, 255, 255))
        bob = math.sin(t * 2.4) * 0.8
        bx, by = S((REST[0], REST[1] + bob - lift))
        img = BOOK[LV_ART]
        blit(F, img, bx, by, WPP * ZOOM)
        if glow > 0.0:
            blit(F, img, bx, by, WPP * ZOOM, alpha=glow, tint=(255, 250, 232))
        comp(F, Lf)
        return Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")


def lane_label(im, did, kind=None, small=False):
    dd = ImageDraw.Draw(im)
    label(dd, 6, 3, SPEC[did]["title"], 12)
    if kind:
        label(dd, im.width - 128, 3, kind, 11, (250, 228, 160))
    if not small:
        label(dd, 6, im.height - 16, SPEC[did]["sub"], 10, (226, 220, 204))


def info_tile(w, h, lines, title):
    im = Image.new("RGB", (w, h), (30, 34, 32))
    dd = ImageDraw.Draw(im)
    label(dd, 12, 12, title, 16)
    y = 40
    for s in lines:
        label(dd, 12, y, s, 11, (220, 214, 198))
        y += 17
    return im


def views_tile(w, h):
    F = np.full((h, w, 3), (52, 66, 48), np.float32)
    for lv in range(1, 6):
        blit(F, BOOK[lv], 60 + (lv - 1) * 100, h // 2, WPP * ZOOM)
    im = Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")
    dd = ImageDraw.Draw(im)
    label(dd, 8, 4, "Seçilen görünüş: B - Açık Sayfalar (oyun ölçeği)", 12)
    for lv in range(1, 6):
        label(dd, 30 + (lv - 1) * 100, h // 2 + 44, "L%d %s" % (lv, YS.TA[lv]["name"]), 10, (220, 214, 198))
    return im


INFO = [
    "aralık %.2f sn (1,2 / 0,7) · isabet %%100 saldırı gücü" % INTERVAL,
    "kalkan %10 saldırı gücü, MENZİLSİZ: kalkanı en boş oyuncu",
    "  (tek kişilikte hep kendine)",
    "1. vuruş: üst slime, yang DOSTA (Şovalye)",
    "2. vuruş: alt slime, yang KENDİNE",
    "kitap atıştan önce hafifçe kalkıp parlar",
    "hedef beyaz, kalkanı alan krem parlar",
    "Talon + Açık Sayfalar L3 · efekt 30 fps, dither yok",
]


def setup():
    YS.frame("horiz")
    for lv in range(1, 6):
        cv = YS.Cv(lv)
        YS.B_book(cv, lv)
        BOOK[lv] = cv.render()
    os.makedirs(OUT, exist_ok=True)


def build_game():
    lanes = [Lane(d, i) for i, d in enumerate(ORDER)]
    n = int(round(LOOP * FPS))
    dt = LOOP / n
    lw, lh = int(LWW * ZOOM), int(LHW * ZOOM)
    info = info_tile(lw, lh, INFO, "Yin Yang Kitabı - vuruş + kalkan")
    views = views_tile(lw, lh)
    hd = header(lw * 2 + 4, "Yin Yang Kitabı  ·  oyun ölçeği (1080p), gerçek hız", "1. vuruş: yang DOSTA  ·  2. vuruş: yang KENDİNE (tek kişilik)")
    frames = []
    for st in range(n):
        t = st * dt
        tiles = []
        for ln in lanes:
            im = ln.render(t)
            _, na = ln.attack(t)
            lane_label(im, ln.did, kind=ATTACKS[na % 2]["name"] if na >= 0 else None)
            tiles.append(im)
        tiles += [views, info]
        frames.append(stack_v([hd, TP.grid(tiles, 2)]))
    sh = lanes[0].shots[0]
    i_hit = int((T_FIRST + sh.t_hit + 0.03) * FPS)
    i_arr = int((T_FIRST + sh.t_arr + 0.05) * FPS)
    save_gif(frames, os.path.join(OUT, "yinyang_oyun.gif"), 1.0 / dt, [i_hit, i_arr, int((T_FIRST + 0.3) * FPS), int((T_FIRST + INTERVAL + 0.4) * FPS)])
    frames[i_hit].save(os.path.join(OUT, "yinyang_oyun_kare.png"))


def build_slow(speed=0.25, z=2):
    lanes = [Lane(d, i, t_first=0.05, atts=(0,)) for i, d in enumerate(ORDER)]
    fps = 40
    real_len = 1.45
    n = int(round(real_len / speed * fps))
    dt = real_len / n
    crop = (int(20 * ZOOM), int(30 * ZOOM), int(230 * ZOOM), int(170 * ZOOM))
    cw, ch = (crop[2] - crop[0]) * z // 2, (crop[3] - crop[1]) * z // 2
    frames = []
    for st in range(n):
        t = st * dt
        tiles = []
        for ln in lanes:
            im = ln.render(t).crop(crop).resize((cw, ch), Image.NEAREST)
            lane_label(im, ln.did, small=True)
            tiles.append(im)
        frames.append(stack_v([header(cw * 2 + 4, "Yin Yang Kitabı - dosta vuruş - YAVAŞ ÇEKİM x%.2f" % speed,
                                      "süre %.2f sn (gerçek)" % max(0.0, t - 0.05)), TP.grid(tiles, 2)]))
    sh = lanes[0].shots[0]
    save_gif(frames, os.path.join(OUT, "yinyang_yavas.gif"), fps,
             [int((0.05 + sh.t_hit) / dt), int((0.05 + sh.t_arr) / dt), int((0.05 + sh.t_launch + 0.1) / dt)])


def build_b(speed=0.4, z=4):
    """Seçilen B (v2: kitaptan yükselip ayrılma): solda gerçek hız (iki vuruş), sağda iki vuruşun yavaş çekimi alt alta."""
    real = Lane("B", 1)
    slow = [Lane("B", 1, t_first=0.05, atts=(0,)), Lane("B", 1, t_first=0.05, atts=(1,))]
    fps = 40
    real_len = LOOP * speed  # yavaş GIF süresi = gerçek hızdaki iki vuruşluk döngü
    n = int(round(real_len / speed * fps))
    dt = real_len / n
    crop = (int(24 * ZOOM), int(36 * ZOOM), int(226 * ZOOM), int(162 * ZOOM))
    cw, ch = (crop[2] - crop[0]) * z // 2, (crop[3] - crop[1]) * z // 2
    frames = []
    for st in range(n):
        t = st * dt
        tr = T_FIRST + (t / speed) % LOOP  # gerçek hız
        left = real.render(tr)
        _, na = real.attack(tr)
        lane_label(left, "B", kind=ATTACKS[na % 2]["name"] if na >= 0 else None, small=True)
        tiles = []
        for i, ln in enumerate(slow):
            im = ln.render(t).crop(crop).resize((cw, ch), Image.NEAREST)
            dd = ImageDraw.Draw(im)
            label(dd, 6, 3, "yavaş x%.2f  ·  %s" % (speed, ATTACKS[i]["name"]), 10, (250, 228, 160))
            tiles.append(im)
        right = stack_v(tiles, 4)
        body_im = Image.new("RGB", (left.width + 4 + right.width, max(left.height, right.height)), (18, 20, 20))
        body_im.paste(left, (0, 0))
        body_im.paste(right, (left.width + 4, 0))
        frames.append(stack_v([header(body_im.width, "B - İkiz Sarmal v2: kitaptan yükselip ayrılır (kara -> düşman, ak -> kalkanı alan)",
                                      "solda gerçek hız (1. vuruş dosta, 2. vuruş kendine) · sağda yavaş çekim"), body_im]))
    sh = slow[0].shots[0]
    save_gif(frames, os.path.join(OUT, "yinyang_B_ayrilma.gif"), fps,
             [int((0.05 + sh.t_split) / dt), int((0.05 + sh.t_hit) / dt), int((0.05 + sh.t_arr) / dt)])
    frames[int((0.05 + sh.t_split + 0.06) / dt)].save(os.path.join(OUT, "yinyang_B_ayrilma_kare.png"))


if __name__ == "__main__":
    setup()
    for w in (sys.argv[1:] or ["oyun", "yavas"]):
        {"oyun": build_game, "yavas": build_slow, "b": build_b}[w]()
