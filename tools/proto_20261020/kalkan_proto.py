# -*- coding: utf-8 -*-
"""KALKAN DARBESİ animasyonu + efekt PROTOTİPLERİ (2026-10-20, oyuna bağlı DEĞİL). Kullanıcı B "Şövalye" görünüşünü seçti ve
"kalkanın yan pozisyonları olmalı, böyle vurunca vurduğu hissedilmez" dedi -> kalkan_yon.py (8 yön, yüz hedefe döner).

Önerilen mekanik (oyunda yok): yakın dövüş, geniş darbe %80 saldırı gücü, vurulanlar 45 px geri itilir (bosslar itilmez),
aralık 1,1111 / 0,7 = 1,59 sn (diğer yakın dövüşlerle aynı).
Darbe (dört yönde ortak): kalkan yüzünü hedefe çevirip öne çıkar, geri çekilir (kurulma), hızla çarpar (isabet), 0,04 sn
DURAKLAMA (hit-stop) + hareket yönünde ezilme, sarsılır, eve döner. Vurulanlar beyaz parlar, 45 px savrulur (hızlı başlayıp
yavaşlar), sonra zıplayarak geri gelir.
Efektler (efekt 30 fps'e kuantalı = sprite sayfası gibi, dither YOK):
  A Toz Yayı        - önde yerde yay biçimli toz bulutu + taş kırıntıları; savrulanların ayağında kayma tozu
  B Darbe Dalgası   - kalkan yüzünden öne açılan iki krem hilal dalga + çarpma yıldızı
  C Kıvılcım Çanı   - metal çınlaması: kalkan bir an beyaz parlar, öne yelpaze kıvılcım, isabetlerde küçük yıldız
  D Hayalet Kalkan  - kalkanın büyük altın-krem silüeti öne doğru itilip söner; vurulanların ayağında halka
Sahne: Talon + Şövalye L3 (Çelik). 1. darbe SAĞA (yan görünüş 72°), 2. darbe AŞAĞI (ön görünüş). Her grupta hedef + 2 yandaki
(geniş darbe) + 1 uzak (vurulmaz).

Çıktılar (out/kalkan/): kalkan_oyun.gif (oyun ölçeği, gerçek hız), kalkan_yavas.gif (sağa darbe x0,25, x2), kalkan_oyun_kare.png.
Çalıştırma: python tools/proto_20261020/kalkan_proto.py [oyun|yavas]   (argümansız: ikisi; önce kalkan_yon.py görünüşlerini üretir)
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
P17 = os.path.normpath(os.path.join(HERE, "..", "proto_20261017"))
sys.path.insert(0, HERE)
sys.path.insert(0, P17)
import bicak_proto as BP  # noqa: E402
import topuz_proto as TP  # noqa: E402
import mermi_proto as MP  # noqa: E402
from mermi_proto import cl, hx, asset, label, grass  # noqa: E402
from bicak_proto import blit, header, stack_v, save_gif  # noqa: E402
from topuz_proto import Lay, clamp01, np_ring, np_cloud, draw_sparks, make_sparks, make_chunks, draw_chunks  # noqa: E402
import kalkan_yon as KY  # noqa: E402

OUT = KY.OUT
ZOOM = 2.0
WPP = 0.575
CHAR_K = 2.2368375 * 0.8075 * 0.5
SLIME_K = 0.94905
FPS = 50
FXFPS = 30
INTERVAL = 1.1111 / 0.7
LOOP = 2.0 * INTERVAL
T_FIRST = 0.15
LV_ART = 3
PUSH = 45.0

LWW, LHW = 270, 200
CHAR = (96.0, 74.0)
REST = (CHAR[0] + 18.0, CHAR[1] - 12.0)
GROUPS = [
    dict(name="SAĞA", target=(156.0, 72.0), others=[(150.0, 50.0), (152.0, 98.0)], miss=[(228.0, 44.0)]),
    dict(name="AŞAĞI", target=(100.0, 128.0), others=[(76.0, 124.0), (124.0, 126.0)], miss=[(36.0, 140.0)]),
]

## efekt tuvali (sanat px, 0,575 dünya px), merkez = temas noktası
FXW, FXH = 240, 190
TP.FXW, TP.FXH = FXW, FXH
TP._YY, TP._XX = np.mgrid[0:FXH, 0:FXW]
TP.BAYT = (np.array(MP.BAY, np.float32)[TP._YY & 3, TP._XX & 3] + 0.5) / 16.0

DUST, DUST_OL = TP.DUST, TP.DUST_OL
STONE, STONE_OL = TP.STONE, TP.STONE_OL
EMBER = TP.EMBER
CREAM_W = cl("#fffdf6 #f2ead6 #d8ccae #aa9e82")
CREAM_W_OL = hx("#6e6450")
GHOST = cl("#fffdf0 #fff3c4 #f6dc8a #e2b45a")
GHOST_OL = hx("#8a6a2e")
SPARK = cl("#ffffff #fff4c8 #ffd060 #f39a2e #c4561c")

# ------------------------------------------------------------------ zaman çizelgesi (saldırı başından, sn)
T_OUT, T_WIND, T_HIT, T_STOP, T_SETTLE, T_HOLD, T_HOME = 0.12, 0.20, 0.245, 0.285, 0.33, 0.40, 0.66


def S(p):
    return (p[0] * ZOOM, p[1] * ZOOM)


def unit(v):
    L = math.hypot(*v) or 1.0
    return (v[0] / L, v[1] / L)


def lerp(p, q, e):
    return (p[0] + (q[0] - p[0]) * e, p[1] + (q[1] - p[1]) * e)


def ez(kind, x):
    x = clamp01(x)
    if kind == "out":
        return 1.0 - (1.0 - x) ** 3
    if kind == "in":
        return x ** 3
    if kind == "inout":
        return 3 * x * x - 2 * x * x * x
    return x


def body(p):
    return (p[0], p[1] - 2.0)


class Geo:
    """Bir grubun saldırı geometrisi."""

    def __init__(self, g):
        self.g = g
        tb = body(g["target"])
        self.d = unit((tb[0] - CHAR[0], tb[1] - (CHAR[1] - 4.0)))
        dx, dy = self.d
        self.ready = (CHAR[0] + dx * 16.0, CHAR[1] - 4.0 + dy * 16.0)
        self.wind = (self.ready[0] - dx * 7.0, self.ready[1] - dy * 7.0)
        self.cp = (tb[0] - dx * 13.0, tb[1] - dy * 13.0)  # temas noktası (kalkan merkezi)
        self.over = (self.cp[0] + dx * 3.0, self.cp[1] + dy * 3.0)
        self.hit = [g["target"]] + g["others"]
        self.push = []
        for e in self.hit:
            r = unit((e[0] - self.cp[0], e[1] - self.cp[1]))
            self.push.append(unit((dx + 0.6 * r[0], dy + 0.6 * r[1])))

    def view(self, imgs):
        return KY.view_for(self.d[0], self.d[1], imgs, LV_ART)


def shield_pose(geo, ta):
    """-> (konum, görünüş anahtarı 'tgt'/'rest', s_par, s_perp, beyaz parlama 0..1)"""
    if ta < 0.0 or ta >= T_HOME:
        return REST, "rest", 1.0, 1.0, 0.0
    if ta < T_OUT:
        e = ez("out", ta / T_OUT)
        return lerp(REST, geo.ready, e), "tgt", 1.0, 1.0, 0.0
    if ta < T_WIND:
        e = ez("inout", (ta - T_OUT) / (T_WIND - T_OUT))
        return lerp(geo.ready, geo.wind, e), "tgt", 1.0 - 0.07 * e, 1.0 + 0.04 * e, 0.0
    if ta < T_HIT:
        e = ez("in", (ta - T_WIND) / (T_HIT - T_WIND))
        return lerp(geo.wind, geo.over, e), "tgt", 0.93 + 0.12 * e, 1.04 - 0.04 * e, 0.0
    if ta < T_STOP:  # duraklama: hareket yönünde ezilme
        return geo.over, "tgt", 0.80, 1.12, 1.0 - (ta - T_HIT) / (T_STOP - T_HIT)
    if ta < T_SETTLE:
        e = (ta - T_STOP) / (T_SETTLE - T_STOP)
        p = lerp(geo.over, geo.cp, ez("out", e))
        sh = 1.4 * math.sin(e * math.pi * 4.0) * (1.0 - e)
        px, py = -geo.d[1], geo.d[0]
        return (p[0] + px * sh, p[1] + py * sh), "tgt", 0.80 + 0.2 * ez("out", e), 1.12 - 0.12 * ez("out", e), 0.0
    if ta < T_HOLD:
        return geo.cp, "tgt", 1.0, 1.0, 0.0
    e = ez("inout", (ta - T_HOLD) / (T_HOME - T_HOLD))
    return lerp(geo.cp, REST, e), ("tgt" if e < 0.55 else "rest"), 1.0, 1.0, 0.0


def enemy_offset(geo, i, age):
    """Vurulan yaratığın savrulma ofseti (yaş = isabetten beri, döngüye göre)."""
    if age < 0.0:
        return (0.0, 0.0), 0.0
    pd = geo.push[i]
    if age < 0.2:
        k = ez("out", age / 0.2)
        return (pd[0] * PUSH * k, pd[1] * PUSH * k), 0.0
    if age < 0.35:
        return (pd[0] * PUSH, pd[1] * PUSH), 0.0
    if age < 1.25:
        k = (age - 0.35) / 0.9
        rem = 1.0 - ez("inout", k)
        hop = abs(math.sin(k * math.pi * 4.0)) * 3.0 * (1.0 - k)
        return (pd[0] * PUSH * rem, pd[1] * PUSH * rem), hop
    return (0.0, 0.0), 0.0


# ------------------------------------------------------------------ çizim yardımcıları
def blit_xy(F, src, cx, cy, k, sx=1.0, sy=1.0, alpha=1.0, tint=None):
    Sa = src if isinstance(src, np.ndarray) else BP._np(src)
    sh, sw = Sa.shape[:2]
    px, py = sw / 2.0, sh / 2.0
    rad = int(max(sw, sh) * k * max(sx, sy, 1.0) / 1.4) + 2
    H, W = F.shape[:2]
    x0, x1 = max(0, int(cx) - rad), min(W, int(cx) + rad)
    y0, y1 = max(0, int(cy) - rad), min(H, int(cy) + rad)
    if x0 >= x1 or y0 >= y1 or alpha <= 0.0:
        return
    X, Y = np.meshgrid(np.arange(x0, x1) + 0.5 - cx, np.arange(y0, y1) + 0.5 - cy)
    u = np.floor(X / (k * sx) + px).astype(np.int32)
    v = np.floor(Y / (k * sy) + py).astype(np.int32)
    m = (u >= 0) & (u < sw) & (v >= 0) & (v < sh)
    if not m.any():
        return
    samp = np.zeros((y1 - y0, x1 - x0, 4), np.float32)
    samp[m] = Sa[v[m], u[m]]
    a = samp[..., 3:4] / 255.0 * alpha
    col = samp[..., :3] if tint is None else np.array(tint, np.float32)
    F[y0:y1, x0:x1] = F[y0:y1, x0:x1] * (1.0 - a) + col * a


def fpx(p):
    return (FXW / 2.0 + p[0] / WPP, FXH / 2.0 + p[1] / WPP)


def arc_wave(L, c, ang, r, w, span, cols, squash=1.0, ol=None):
    """c merkezli (temasa göre dünya), ang yönünde, yarıçap r (dünya), kalınlık w (sanat px), yarım açı span hilal; uçlara incelir."""
    cx, cy = fpx(c)
    R = r / WPP
    X = TP._XX + 0.5 - cx
    Y = (TP._YY + 0.5 - cy) / squash
    d = np.hypot(X, Y)
    th = np.arctan2(Y, X) - ang
    th = (th + math.pi) % (2 * math.pi) - math.pi
    f = np.clip(1.0 - np.abs(th) / span, 0.0, 1.0)
    wl = w * np.sqrt(f)
    band = (d <= R) & (d > R - wl) & (f > 0.0)
    if not band.any():
        return
    q = (R - d) / np.maximum(wl, 1e-3)
    ci = np.clip((q * len(cols)).astype(np.int32), 0, len(cols) - 1)
    C = np.array(cols, np.float32)[ci]
    if ol is not None:
        olm = (d <= R + 1.0) & (d > R - wl - 1.0) & (f > 0.0) & ~band & (wl > 1.5)
        L.paint(0, 0, olm, ol, 1.0)
    L.paint(0, 0, band, C, 1.0)


def star4(L, c, r, cols):
    x, y = (int(q) for q in fpx(c))
    r = int(round(r))
    if r <= 0:
        return
    for i in range(-r, r + 1):
        k = abs(i) / float(r)
        col = cols[min(len(cols) - 1, int(k * len(cols)))]
        L.put(x + i, y, col)
        L.put(x, y + i, col)
    for i in range(1, max(1, r // 2) + 1):
        col = cols[min(len(cols) - 1, 1 + i)]
        for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            L.put(x + sx * i, y + sy * i, col)


def rel(geo, p):
    return (p[0] - geo.cp[0], p[1] - geo.cp[1])


# ------------------------------------------------------------------ efektler: (yer katmanı, ön katman) temasa göre, yaş = isabetten beri
def A_fx(geo, Lg, Lf, age):
    if age < 0.0:
        return
    th = math.atan2(geo.d[1], geo.d[0])
    e = ez("out", age / 0.32)
    if age < 0.42:
        puffs = []
        for k in range(7):
            a = th + (k - 3) * 0.36
            rr = 6.0 + 22.0 * e
            pr = (4.6 - 2.4 * e) * (1.0 - 0.13 * abs(k - 3))
            puffs.append((math.cos(a) * rr, 6.0 + math.sin(a) * rr * 0.5, pr))
        np_cloud(Lg, puffs, DUST, DUST_OL, 1.0, cut=clamp01((age - 0.18) / 0.24))
    draw_chunks(Lf, (geo.d[0] * 4.0, 4.0 + geo.d[1] * 2.0), CHUNKS_A, age, STONE, STONE_OL, g=420.0, rest=0.12)
    for i, en in enumerate(geo.hit):  # kayma tozu (savrulma boyunca ayakta)
        if 0.02 < age < 0.34:
            off, _ = enemy_offset(geo, i, age)
            foot = rel(geo, (en[0] + off[0], en[1] + off[1] + 7.0))
            k = (age - 0.02) / 0.32
            pd = geo.push[i]
            puffs = [(foot[0] - pd[0] * 4.0, foot[1] - pd[1] * 2.0, 2.6 * (1.0 - k) + 0.6),
                     (foot[0] - pd[0] * 9.0, foot[1] - pd[1] * 4.0, 1.8 * (1.0 - k) + 0.4)]
            np_cloud(Lg, puffs, DUST, DUST_OL, 1.0, cut=clamp01(k * 1.3 - 0.3))


def A_live(geo, L, age):
    pass


def B_fx(geo, Lg, Lf, age):
    if age < 0.0:
        return
    th = math.atan2(geo.d[1], geo.d[0])
    base = (-geo.d[0] * 6.0, -geo.d[1] * 6.0)
    for j, dl in enumerate((0.0, 0.07)):
        a2 = age - dl
        if 0.0 <= a2 < 0.26:
            k = a2 / 0.26
            r = 10.0 + 30.0 * ez("out", k)
            w = (5.0 - 3.6 * k) * (1.0 if j == 0 else 0.75)
            arc_wave(Lf, base, th, r, w, 1.05 - 0.25 * k, CREAM_W, ol=CREAM_W_OL if k < 0.6 else None)
    if age < 0.12:
        star4(Lf, (geo.d[0] * 4.0, geo.d[1] * 4.0), 7.0 * (1.0 - age / 0.12) + 1.0, CREAM_W)


def B_live(geo, L, age):
    pass


def C_fx(geo, Lg, Lf, age):
    if age < 0.0:
        return
    o = (geo.d[0] * 5.0, geo.d[1] * 5.0)
    fw, bk = _sparks_for(geo, 21 if geo is GEOS[0] else 33)
    draw_sparks(Lf, o, fw, age, SPARK, g=200.0)
    draw_sparks(Lf, o, bk, age, SPARK, g=200.0)
    if age < 0.12:  # çınlama halkası: kısa, keskin, tam daire
        k = age / 0.12
        arc_wave(Lf, o, 0.0, 4.0 + 12.0 * ez("out", k), 3.0 - 2.0 * k, math.pi, SPARK[1:])
    if age < 0.09:
        star4(Lf, o, 10.0 * (1.0 - age / 0.09) + 1.0, SPARK)
    for i, en in enumerate(geo.hit[1:], 1):
        a2 = age - 0.02 * i
        if 0.0 <= a2 < 0.08:
            off, _ = enemy_offset(geo, i, age)
            star4(Lf, rel(geo, (en[0] + off[0], en[1] + off[1] - 4.0)), 4.0 * (1.0 - a2 / 0.08) + 1.0, SPARK)


def C_live(geo, L, age):
    pass


def D_fx(geo, Lg, Lf, age):
    if age < 0.0:
        return
    for i, en in enumerate(geo.hit):
        off, _ = enemy_offset(geo, i, age)
        np_ring(Lg, rel(geo, (en[0] + off[0], en[1] + off[1] + 7.0)), 3.0, 1.5, 12.0, 6.0, 2.0, GHOST, age / 0.3,
                nbreak=5, phase=i, ol=GHOST_OL, fade=1.0, brk=0.5)


def D_live(geo, L, age):
    pass


CHUNKS_A = make_chunks(7, 7, (40.0, 90.0), (50.0, 110.0), (1, 2))

SPEC = {
    "A": dict(title="A - Toz Yayı", sub="önde yay biçimli toz + taş kırıntısı, savrulanların ayağında kayma tozu"),
    "B": dict(title="B - Darbe Dalgası", sub="kalkan yüzünden öne açılan iki krem hilal + çarpma yıldızı"),
    "C": dict(title="C - Kıvılcım Çanı", sub="metal çınlaması: kalkan beyaz parlar, öne yelpaze kıvılcım"),
    "D": dict(title="D - Hayalet Kalkan", sub="kalkanın büyük silüeti öne itilip söner, ayaklarda halka"),
}
FX = {"A": A_fx, "B": B_fx, "C": C_fx, "D": D_fx}
ORDER = ["A", "B", "C", "D"]


# ------------------------------------------------------------------ şerit
_BG = {}
_SL = []
IMGS = {}
GEOS = []


def lane_bg(idx):
    if idx not in _BG:
        g = grass(int(LWW * ZOOM), int(LHW * ZOOM), 91 + idx)
        F = np.asarray(g.convert("RGB"), dtype=np.float32).copy()
        _BG[idx] = F
    return _BG[idx].copy()


def slime():
    if not _SL:
        _SL.append(asset("visuals/Yaratıklar/Tüm Yaratıklar/Slime 1/PNG/Slime1/With_shadow/Slime1_Walk_with_shadow.png", (0, 0, 64, 64)))
    return _SL[0]


def char_img():
    return asset("assets/characters/talon/sheets/idle.png", (0, 96, 48, 144))


class Lane:
    def __init__(self, did, idx, t_first=T_FIRST, groups=(0, 1)):
        self.did, self.idx = did, idx
        self.t_first = t_first
        self.groups = groups
        self.cache = {}

    def attack(self, t):
        if t < self.t_first:
            return -1.0, -1
        n = int((t - self.t_first) // INTERVAL)
        return t - self.t_first - n * INTERVAL, n

    def hit_age(self, gi, t):
        """gi grubunun son isabetinden beri geçen süre (döngüye sarılı)."""
        k = self.groups.index(gi) if gi in self.groups else None
        if k is None:
            return -1.0
        th = self.t_first + k * INTERVAL + T_HIT
        per = INTERVAL * len(self.groups)
        a = (t - th) % per
        return a

    def fx_layers(self, gi, age):
        q = int(age * FXFPS)
        key = (gi, q)
        if key not in self.cache:
            Lg, Lf = Lay(), Lay()
            FX[self.did](GEOS[gi], Lg, Lf, q / float(FXFPS))
            self.cache[key] = (Lg.cropped(), Lf.cropped())
        return self.cache[key]

    def render(self, t):
        F = lane_bg(self.idx)
        ta, n = self.attack(t)
        gi = self.groups[n % len(self.groups)] if n >= 0 else self.groups[0]
        geo = GEOS[gi]
        k_fx = WPP * ZOOM
        age_cur = ta - T_HIT if n >= 0 else -1.0
        lay_g = lay_f = None
        if age_cur >= 0.0 and age_cur < 1.0:
            lay_g, lay_f = self.fx_layers(gi, age_cur)
        tx, ty = S(geo.cp)
        if lay_g is not None:
            blit(F, lay_g[0], tx, ty, k_fx, 0.0, lay_g[1])
        ## yaratıklar + karakter (ayak sırası)
        items = []
        cx, cy = S(CHAR)
        items.append((CHAR[1] + 18.0, "char", None))
        for gj, gg in enumerate(GROUPS):
            gg_geo = GEOS[gj]
            age = self.hit_age(gj, t)
            for i, en in enumerate(gg_geo.hit):
                off, hop = enemy_offset(gg_geo, i, age)
                p = (en[0] + off[0], en[1] + off[1] - hop)
                items.append((p[1] + 7.0, "slime", (p, age)))
            for en in gg["miss"]:
                items.append((en[1] + 7.0, "slime", (en, -1.0)))
        for _, kind, data in sorted(items, key=lambda q: q[0]):
            if kind == "char":
                blit(F, char_img(), cx, cy, CHAR_K * ZOOM)
                continue
            p, age = data
            sx, sy = S(p)
            blit(F, slime(), sx, sy - 2, SLIME_K * ZOOM)
            if 0.0 <= age < 0.1:
                blit(F, slime(), sx, sy - 2, SLIME_K * ZOOM, alpha=0.85 * (1.0 - age / 0.1), tint=(255, 255, 255))
        ## kalkan
        pos, vk, spar, sperp, flash = shield_pose(geo, ta if n >= 0 else -1.0)
        img = geo.view(IMGS) if vk == "tgt" else IMGS[(LV_ART, 0)]
        bob = 0.0 if vk == "tgt" else math.sin(t * 2.6) * 0.8
        ax, ay = abs(geo.d[0]), abs(geo.d[1])
        sxx = ax * spar + ay * sperp
        syy = ax * sperp + ay * spar
        px, py = S((pos[0], pos[1] + bob))
        blit_xy(F, img, px, py, WPP * ZOOM, sxx, syy)
        if self.did == "C" and flash > 0.0:
            blit_xy(F, img, px, py, WPP * ZOOM, sxx, syy, alpha=0.85 * flash, tint=(255, 250, 235))
        elif flash > 0.0:
            blit_xy(F, img, px, py, WPP * ZOOM, sxx, syy, alpha=0.35 * flash, tint=(255, 250, 235))
        ## D: hayalet silüet (alfa karışımı, dither yok)
        if self.did == "D" and 0.0 <= age_cur < 0.3:
            k = age_cur / 0.3
            e = ez("out", k)
            gp = (geo.cp[0] + geo.d[0] * 26.0 * e, geo.cp[1] + geo.d[1] * 26.0 * e)
            gx, gy = S(gp)
            sc = 1.25 + 0.6 * e
            blit_xy(F, geo.view(IMGS), gx, gy, WPP * ZOOM, sc * sxx, sc * syy, alpha=0.7 * (1.0 - k) ** 1.4, tint=(255, 236, 168))
        if lay_f is not None:
            blit(F, lay_f[0], tx, ty, k_fx, 0.0, lay_f[1])
        return Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")


def lane_label(im, did, kind=None, small=False):
    dd = ImageDraw.Draw(im)
    label(dd, 6, 3, SPEC[did]["title"], 12)
    if kind:
        label(dd, im.width - 110, 3, kind, 11, (250, 228, 160))
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
    """L3 ve L5, 8 yön (oyun ölçeği)."""
    F = np.full((h, w, 3), (52, 66, 48), np.float32)
    for r, lv in enumerate((3, 5)):
        for i in range(8):
            th = math.radians(i * 45)
            dx, dy = math.sin(th), math.cos(th)
            img = KY.view_for(dx, dy, IMGS, lv)
            blit(F, img, 70 + i * 58, 92 + r * 130, WPP * ZOOM)
    im = Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")
    dd = ImageDraw.Draw(im)
    label(dd, 8, 4, "Yüz hedefe döner - 8 yön (soldakiler ayna)", 12)
    names = ["aşağı", "sağ-aş.", "sağ", "sağ-yu.", "yukarı", "sol-yu.", "sol", "sol-aş."]
    for i, nm in enumerate(names):
        label(dd, 50 + i * 58, h - 18, nm, 10, (210, 204, 188))
    for r, lv in enumerate((3, 5)):
        label(dd, 8, 34 + r * 130, "L%d %s" % (lv, KY.TA[lv]["name"]), 11, (230, 224, 206))
    return im


INFO = [
    "aralık %.2f sn · geniş darbe %%80 saldırı gücü (önerilen)" % INTERVAL,
    "vurulanlar %d px geri savrulur (bosslar itilmez)" % int(PUSH),
    "kalkan yüzünü hedefe çevirir: yan = 72°, sola ayna",
    "kurulma 0,08 sn -> çarpma 0,045 sn -> 0,04 sn DURAKLAMA",
    "  (hit-stop) + hareket yönünde ezilme, sonra sarsılma",
    "beyaz parlama = isabet; hedef + 2 yandaki = geniş darbe",
    "uzaktaki slime vurulmaz",
    "Talon + Şövalye L3 (Çelik) · efekt 30 fps, dither yok",
]


def setup():
    imgs = KY.build()
    IMGS.update(imgs)
    for g in GROUPS:
        GEOS.append(Geo(g))
    os.makedirs(OUT, exist_ok=True)


def _sparks_for(geo, seed):
    th = math.degrees(math.atan2(geo.d[1], geo.d[0]))
    fw = make_sparks(seed, 18, th - 75.0, th + 75.0, (90.0, 190.0), (0.16, 0.32))
    bk = make_sparks(seed + 1, 5, th + 130.0, th + 230.0, (50.0, 90.0), (0.10, 0.18))
    return fw, bk


def build_game():
    lanes = [Lane(d, i) for i, d in enumerate(ORDER)]
    n = int(round(LOOP * FPS))
    dt = LOOP / n
    lw, lh = int(LWW * ZOOM), int(LHW * ZOOM)
    info = info_tile(lw, lh, INFO, "Kalkan darbesi (Şövalye)")
    views = views_tile(lw, lh)
    hd = header(lw * 2 + 4, "Kalkan darbesi  ·  oyun ölçeği (1080p), gerçek hız", "1. darbe SAĞA (yan görünüş), 2. darbe AŞAĞI (ön görünüş)")
    frames = []
    for st in range(n):
        t = st * dt
        tiles = []
        for ln in lanes:
            im = ln.render(t)
            _, na = ln.attack(t)
            lane_label(im, ln.did, kind=GROUPS[na % 2]["name"] if na >= 0 else None)
            tiles.append(im)
        tiles += [views, info]
        frames.append(stack_v([hd, TP.grid(tiles, 2)]))
    th = T_FIRST + T_HIT
    save_gif(frames, os.path.join(OUT, "kalkan_oyun.gif"), 1.0 / dt,
             [int((th + 0.03) * FPS), int((th + 0.12) * FPS), int((th + INTERVAL + 0.05) * FPS)])
    frames[int((th + 0.05) * FPS)].save(os.path.join(OUT, "kalkan_oyun_kare.png"))


def build_slow(speed=0.25, z=2):
    lanes = [Lane(d, i, t_first=0.05, groups=(0,)) for i, d in enumerate(ORDER)]
    fps = 40
    real_len = 0.85
    n = int(round(real_len / speed * fps))
    dt = real_len / n
    g = GROUPS[0]
    crop = (int((CHAR[0] - 20) * ZOOM), int((CHAR[1] - 52) * ZOOM), int((CHAR[0] + 150) * ZOOM), int((CHAR[1] + 50) * ZOOM))
    cw, ch = (crop[2] - crop[0]) * z // 2, (crop[3] - crop[1]) * z // 2
    frames = []
    for st in range(n):
        t = st * dt
        tiles = []
        for ln in lanes:
            im = ln.render(t).crop(crop).resize((cw, ch), Image.NEAREST)
            lane_label(im, ln.did, small=True)
            tiles.append(im)
        frames.append(stack_v([header(cw * 2 + 4, "Kalkan darbesi SAĞA - YAVAŞ ÇEKİM x%.2f" % speed,
                                      "süre %.2f sn (gerçek) · isabet %.3f sn" % (max(0.0, t - 0.05), T_HIT)), TP.grid(tiles, 2)]))
    th = 0.05 + T_HIT
    save_gif(frames, os.path.join(OUT, "kalkan_yavas.gif"), fps, [int((th + 0.02) / dt), int((th + 0.1) / dt), int((th - 0.06) / dt)])


OFFS = [-0.09, -0.03, 0.0, 0.03, 0.07, 0.12, 0.2, 0.3]


def build_strip():
    """Sağa ve aşağı darbe: isabete hizalı kareler, dört efekt alt alta."""
    rows = []
    for gi, crop in ((0, (int((CHAR[0] - 8) * ZOOM), int((CHAR[1] - 44) * ZOOM), int((CHAR[0] + 136) * ZOOM), int((CHAR[1] + 44) * ZOOM))),
                     (1, (int((CHAR[0] - 70) * ZOOM), int((CHAR[1] - 20) * ZOOM), int((CHAR[0] + 74) * ZOOM), int((CHAR[1] + 112) * ZOOM)))):
        cw, ch = crop[2] - crop[0], crop[3] - crop[1]
        LBL = 150
        for i, did in enumerate(ORDER):
            ln = Lane(did, i, t_first=0.0, groups=(gi,))
            row = Image.new("RGB", (LBL + len(OFFS) * (cw + 2), ch + 18), (24, 26, 26))
            dd = ImageDraw.Draw(row)
            for j, o in enumerate(OFFS):
                row.paste(ln.render(max(0.0, T_HIT + o)).crop(crop), (LBL + j * (cw + 2), 18))
                label(dd, LBL + j * (cw + 2) + 4, 2, "%+.2f sn%s" % (o, "  isabet" if o == 0.0 else ""), 10, (220, 214, 198))
            label(dd, 6, 22, SPEC[did]["title"], 12)
            label(dd, 6, 40, GROUPS[gi]["name"], 11, (250, 228, 160))
            rows.append(row)
    im = stack_v(rows, 6)
    im.save(os.path.join(OUT, "kalkan_kareler.png"))
    print("kareler", im.size)


if __name__ == "__main__":
    setup()
    for w in (sys.argv[1:] or ["kareler", "oyun", "yavas"]):
        {"oyun": build_game, "yavas": build_slow, "kareler": build_strip}[w]()
