# -*- coding: utf-8 -*-
"""TIRPAN vuruş animasyonu + efekti PROTOTİPLERİ (2026-11-09, oyuna bağlı DEĞİL). Kullanıcı: "pençe artık tırpan olduğuna göre
tırpan için yeni efekt tasarlaman gerekiyor şuanki haline uygun olacak şekilde, ayrıca tırpan geniş açılı vuruyor pençe gibi ufak
ufak değil animasyonu da değişmeli o yüzden gif olarak göster".

Bugün (madde 505): Pençe = Tırpan çizimi (assets/weapons/yeni/tirpan.png, 40x40, sap sol-alt -> baş sağ-üst, bıçak baştan aşağı
kıvrık), animasyon hâlâ pençenin "Kanca Çekiş"i (pence_hook_math.gd: geri sin, saplan, titre, çekerek yırt; ikon MERKEZİNDEN döner)
+ pençe için pişirilmiş 3 yırtık efekti. Mekanik: menzil 110, 2 hasar parçası, alan 80 px (yarı hasar), aralık 1,59 sn.

Yeni yönlerin ortak kuralı: tırpan SAPINDAN (el, sanat px (5,33)) döner, bıçak hareketin ÖNÜNDE (çizimde bıçak sapın saat yönü
tarafında -> açı ARTARKEN keser; sola saldırıda oyunda flip_v gerekir). Tırpan boyu ~20 dünya px (WORLD_PX 0,575). İz = bıçağın
taradığı alan (bıçak çizgisi her alt örnekte çizilir, en yeni örnek üstte; yaşa göre renk bandı, kuyruk uca doğru incelir) -
dither YOK, solma tek tip saydamlıkla.
  A Kızıl Hilal   - geri kurulur, hedefin önünde 260 derece tek geniş biçme; kızıl hilal iz, hedefte ince kesik + kan damlaları.
  B Ölüm Çemberi  - bir buçuk tur döner, bıçak hedeften iki kez geçer (iki hasar parçası = iki geçiş); koyu gölge halkası,
                    kızıl kenar, kızıl kıvılcım.
  C Hasat Çekişi  - hedefin ötesine uzanır, biçerek oyuncuya doğru çeker (eski kanca fikrinin geniş hâli); krem rüzgâr hilali,
                    kesilen ot parçaları.
  D Gölge Tırpan  - A'nın savuruşu + arkasında 2,2 kat dev hayalet tırpan: alanı kaplayan yarı saydam kızıl-mor hilal.

Çıktılar (out/tirpan/): tirpan_oyun.gif (1080p oyun ölçeği, gerçek hız, 2 vuruş; ŞU AN + A-D), tirpan_yavas.gif (x0,25 hız,
x2 yakın), tirpan_kareler.png (1. temasa hizalı kare şeridi).
Çalıştırma: python -I tools/proto_20261109/tirpan_proto.py [oyun|yavas|kareler]   (argümansız: hepsi)
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
P17 = os.path.join(os.path.dirname(HERE), "proto_20261017")
sys.path.insert(0, P17)
import bicak_proto as BP  # noqa: E402
import topuz_proto as TP  # noqa: E402
import pence_proto as PP  # noqa: E402
from mermi_proto import cl, hx, asset, label  # noqa: E402
from bicak_proto import header, stack_v, save_gif  # noqa: E402
from topuz_proto import Track, clamp01, draw_sparks  # noqa: E402

OUT = os.path.join(HERE, "out", "tirpan")
ZOOM = PP.ZOOM
WPP = TP.WPP
FPS = 50
FXFPS = 30
INTERVAL = PP.INTERVAL
AOE = 80.0  # player.gd _configure_pence_melee (madde 240'tan beri 80)
D2R = math.pi / 180.0
ART_FWD = TP.ART_FWD  # -45: tırpanın sapı sol-alt -> sağ-üst (weapon_tier_art.gd FORWARD)

ICON_PATH = "assets/weapons/yeni/tirpan.png"
CENTER_PX = (20.0, 20.0)
GRIP_PX = (5.0, 33.0)  # el (sapın alt ucu biraz yukarısı): yeni yönlerde dönme merkezi
## bıçak: baştan (sapın bağlandığı yer) uca, sanat px
BLADE_PX = [(30.0, 9.0), (33.0, 13.0), (34.5, 18.0), (34.5, 23.0), (33.0, 27.5), (31.0, 30.5)]

TGT, CHAR, REST_C = TP.TGT, TP.CHAR, TP.REST_C
DIR_ANG, DIRV = TP.DIR_ANG, TP.DIRV
PERP = (-DIRV[1], DIRV[0])  # Godot perp: saldırı yönünün saat yönü tarafı (bıçağın baktığı taraf)
EXTRA_IN = (TGT[0] + 40.0, TGT[1] - 24.0)  # alanın içinde (47 px) -> yarı hasar
EXTRA_OUT = (TGT[0] + 86.0, TGT[1] + 18.0)  # alanın dışında (88 px)
REST_ANG = -math.pi / 2  # dinlenmede dik (weapon_tier_art.gd REST -45)


def S(p):
    return (p[0] * ZOOM, p[1] * ZOOM)


def off(p):
    return (p[0] - TGT[0], p[1] - TGT[1])


def _rot(v, a):
    c, s = math.cos(a), math.sin(a)
    return (c * v[0] - s * v[1], s * v[0] + c * v[1])


def LW(x, y):
    """Yerel çerçeve (orijin hedef, +x saldırı yönü, +y bıçak tarafı) -> dünya."""
    return (TGT[0] + DIRV[0] * x + PERP[0] * y, TGT[1] + DIRV[1] * x + PERP[1] * y)


def LG(x, y, a_deg, sl=1.0, sw=1.0):
    """Sap pivotlu poz: el yerel (x, y)'de, sap yerel a_deg açısında."""
    w = LW(x, y)
    return (w[0], w[1], DIR_ANG + a_deg * D2R, sl, sw)


def px_world(pose, piv, p, k=1.0):
    """pose (pivotun dünya konumu + sap açısı) iken p pikselinin dünya konumu (k: boyut çarpanı, hayalet tırpan)."""
    x, y, a = pose[0], pose[1], pose[2]
    r = _rot(((p[0] - piv[0]) * WPP * k, (p[1] - piv[1]) * WPP * k), a - ART_FWD)
    return (x + r[0], y + r[1])


GRIP_REST = px_world((REST_C[0], REST_C[1], REST_ANG), CENTER_PX, GRIP_PX)
REST_GRIP = (GRIP_REST[0], GRIP_REST[1], REST_ANG, 1.0, 1.0)
REST_CENTER = (REST_C[0], REST_C[1], REST_ANG, 1.0, 1.0)


def blit_tool(F, src, pw, ang, k, piv, sl=1.0, sw=1.0, alpha=1.0, tint=None):
    """TP.blit_mace + saydamlık/renk (hayalet tırpan)."""
    Sa = BP._np(src)
    sh, swd = Sa.shape[:2]
    px, py = piv
    rad = int(math.hypot(max(px, swd - px), max(py, sh - py)) * k * max(sl, sw, 1.0)) + 2
    H, Wd = F.shape[:2]
    cx, cy = pw
    x0, x1 = max(0, int(cx) - rad), min(Wd, int(cx) + rad)
    y0, y1 = max(0, int(cy) - rad), min(H, int(cy) + rad)
    if x0 >= x1 or y0 >= y1:
        return
    X, Y = np.meshgrid(np.arange(x0, x1) + 0.5 - cx, np.arange(y0, y1) + 0.5 - cy)
    ca, sa = math.cos(ang), math.sin(ang)
    mx = (ca * X + sa * Y) / (k * sl)
    my = (-sa * X + ca * Y) / (k * sw)
    cf, sf = math.cos(ART_FWD), math.sin(ART_FWD)
    u = np.floor(cf * mx - sf * my + px).astype(np.int32)
    v = np.floor(sf * mx + cf * my + py).astype(np.int32)
    m = (u >= 0) & (u < swd) & (v >= 0) & (v < sh)
    if not m.any():
        return
    samp = np.zeros((y1 - y0, x1 - x0, 4), np.float32)
    samp[m] = Sa[v[m], u[m]]
    a = samp[..., 3:4] / 255.0 * alpha
    col = samp[..., :3] if tint is None else np.array(tint, np.float32)
    F[y0:y1, x0:x1] = F[y0:y1, x0:x1] * (1.0 - a) + col * a


class Lay2(TP.Lay):
    """Dither'sız katman: saydamlık piksele yazılır (oyunda modulate.a / sayfa alfası gibi tek tip solma)."""

    def put(self, x, y, col, a=1.0):
        if 0 <= x < TP.FXW and 0 <= y < TP.FXH and a > 0.02:
            self.a[y, x, 0:3] = col
            self.a[y, x, 3] = 255.0 * min(1.0, a)

    def paint(self, y0, x0, mask, cols, alpha):
        h, w = mask.shape
        al = np.broadcast_to(np.asarray(alpha, np.float32), mask.shape)
        m = mask & (al > 0.02)
        if not m.any():
            return
        sub = self.a[y0:y0 + h, x0:x0 + w]
        c = np.asarray(cols, np.float32)
        sub[m, 0:3] = c[m] if c.ndim == 3 else c
        sub[m, 3] = 255.0 * np.minimum(1.0, al[m])


# ------------------------------------------------------------------ bıçak izi
def blade_trail(L, tr, t, t0, t1, win, cols, ol=None, linger=0.05, eat=0.10, n=26, k=1.0, taper=0.8, alphas=(1.0, 1.0, 1.0, 0.7),
                lag=0.0, width=3, fade=1.0):
    """[t0, t1] savuruşunda bıçağın son `win` saniyede taradığı alan. Yaşa göre renk bandı (cols[0] en yeni = ön kenar), eskidikçe
    bıçak uca doğru kısalır (kuyruk sivrilir). Savuruş bitince `linger` durur, `eat` sürede kuyruktan yenir."""
    if t < t0:
        return
    te = min(t, t1)
    tb = max(t0, te - win)
    if t > t1 + linger:
        kk = (t - t1 - linger) / eat
        if kk >= 1.0:
            return
        tb += (te - tb) * kk
    if te - tb < 0.003:
        return
    ## alt örnek sayısı: bıçak ucu örnekler arasında en çok ~1,5 sanat px yol alsın (hızlı dönüşte iz çizgili kalmasın)
    p_a = px_world(tr.pose(max(0.0, te - lag)), tr.piv, BLADE_PX[0], k)
    span = 0.0
    for j in range(1, 13):
        p_b = px_world(tr.pose(max(0.0, te - (te - tb) * j / 12.0 - lag)), tr.piv, BLADE_PX[0], k)
        span += math.hypot(p_b[0] - p_a[0], p_b[1] - p_a[1]) / WPP
        p_a = p_b
    n = int(min(320, max(n, span / 1.5)))
    img = Image.new("I", (TP.FXW, TP.FXH), -1)
    d = ImageDraw.Draw(img)
    ages = []
    nb = len(BLADE_PX)
    for j in range(n):
        s = tb + (te - tb) * j / (n - 1)
        age = (te - s) / win
        ages.append(age)
        pose = tr.pose(max(0.0, s - lag))
        pts = [TP.fpx(off(px_world(pose, tr.piv, p, k))) for p in BLADE_PX]
        u0 = min(0.92, taper * age) * (nb - 1)  # eskidikçe baş tarafı kesilir
        i0 = int(u0)
        f = u0 - i0
        a0 = pts[i0]
        b0 = pts[min(nb - 1, i0 + 1)]
        sub = [(a0[0] + (b0[0] - a0[0]) * f, a0[1] + (b0[1] - a0[1]) * f)] + pts[i0 + 1:]
        if len(sub) >= 2:
            d.line(sub, fill=j, width=width, joint="curve")
    A = np.array(img)
    mask = A >= 0
    if not mask.any():
        return
    ag = np.where(mask, np.array(ages, np.float32)[np.clip(A, 0, n - 1)], 9.0)
    ci = np.where(ag < 0.16, 0, np.where(ag < 0.42, 1, np.where(ag < 0.72, 2, 3)))
    C = np.array(cols, np.float32)[np.minimum(ci, len(cols) - 1)]
    al = np.array(alphas, np.float32)[np.minimum(ci, len(alphas) - 1)] * fade
    if ol is not None:
        dil = mask.copy()
        dil[1:] |= mask[:-1]
        dil[:-1] |= mask[1:]
        dil[:, 1:] |= mask[:, :-1]
        dil[:, :-1] |= mask[:, 1:]
        near = np.zeros_like(mask)
        young = mask & (ag < 0.6)
        near[1:] |= young[:-1]
        near[:-1] |= young[1:]
        near[:, 1:] |= young[:, :-1]
        near[:, :-1] |= young[:, 1:]
        L.paint(0, 0, dil & ~mask & near, ol, fade)
    L.paint(0, 0, mask, C, al)


def angle_time(tr, a_local_deg, t0, t1, step=0.0005):
    """Sap açısının (yerel) ilk kez a_local_deg'i geçtiği an."""
    target = DIR_ANG + a_local_deg * D2R
    prev = tr.pose(t0)[2]
    t = t0
    while t < t1:
        t += step
        cur = tr.pose(t)[2]
        if (prev - target) * (cur - target) <= 0.0 and prev != cur:
            return t
        prev = cur
    return t1


def _sparks(seed, n, a0, a1, v, life):
    return PP._sparks(seed, n, a0, a1, v, life)  # açılar saldırı yönüne göre (+90 = bıçak tarafı)


def tangent_cut(Ls, age, life, length, cols, ol, a_local=90.0, w=3.0):
    """Hedefte bıçağın gidiş yönünde ince kesik (BP.line_band): çıkar, durur, incelir."""
    if not (0.0 <= age < life):
        return
    th = DIR_ANG + a_local * D2R
    h = length / 2.0
    p0 = (-math.cos(th) * h, -math.sin(th) * h - 2.0)
    p1 = (math.cos(th) * h, math.sin(th) * h - 2.0)
    grow = clamp01(age / 0.04)
    thin = clamp01((age - 0.08) / (life - 0.08))
    BP.line_band(Ls["f"], p0, p1, w, cols, head=grow, tail=0.0, thin=thin, ol=ol, peak=0.9)


# ------------------------------------------------------------------ renkler (tırpanın kendi paleti: #c42430 #891e2b #571c27, kontur #0e071b)
BLOOD = cl("#ffe2da #f0606a #c42430 #891e2b")
BLOOD_OL = hx("#2a0a14")
CUT = cl("#fff4ee #ffc2b8 #f0606a")
CUT_OL = hx("#571c27")
DROP = cl("#f0606a #c42430 #891e2b #571c27")
SHADOW = cl("#f0606a #a82838 #3c1a36 #24122a")
SHADOW_OL = hx("#0e071b")
SPARK_R = cl("#ffe2da #f0606a #c42430 #891e2b")
WIND = cl("#fffdf6 #f2ead6 #d8ccae #aa9e82")
WIND_OL = hx("#6e6450")
GRASS = cl("#b8e07a #7cb84a #4f8a34 #2f5e26")
GHOST = cl("#f07a86 #c43a56 #7e2a58 #4a1c48")
GHOST_TINT = hx("#b8344e")


# ------------------------------------------------------------------ ŞU AN: pençenin Kanca Çekişi (pence_hook_math.gd), tırpan çizimiyle
def CUR_track():
    tr = Track(REST_CENTER, CENTER_PX)
    tr.to(0.10, "out", PP.LP(-20.0, -5.0, 0.0, 0.9, 1.06))
    tr.to(0.045, "in", PP.LP(12.0, 0.0, 0.0, 1.15, 0.92))
    tr.to(0.03, "lin", PP.LP(12.0, 0.0, 0.0, 0.85, 1.12))
    base = tr.cur

    def shake(e):
        dd = 0.8 * math.sin(e * math.pi * 6.0)
        return (base[0] - DIRV[1] * dd, base[1] + DIRV[0] * dd, base[2], 1.0, 1.0)

    tr.add(PP.B_DIG[1] - PP.B_DIG[0], "lin", shake)
    tr.to(0.03, "out", PP.LP(-14.0, 3.0, 12.0))
    tr.to(0.055, "out", PP.LP(-20.0, 4.0, 8.0))
    tr.hold(0.10)
    return tr.home(0.26)


# ------------------------------------------------------------------ A Kızıl Hilal: hedefin önünde 260 derece tek biçme
A_WIND, A_TENSE, A_SWING, A_FOLLOW = 0.13, 0.04, 0.10, 0.06
A_T0 = A_WIND + A_TENSE
A_T1 = A_T0 + A_SWING


def A_track():
    tr = Track(REST_GRIP, GRIP_PX)
    tr.to(A_WIND, "out", LG(-18.0, -3.0, -150.0))  # geri kurul (bıçak arkada)
    tr.to(A_TENSE, "inout", LG(-19.0, -4.0, -162.0))  # gerilme
    tr.to(A_SWING, "acc", LG(-14.0, 2.0, 98.0))  # biç (260 derece, hızlanarak)
    tr.to(A_FOLLOW, "out", LG(-13.0, 3.0, 120.0))  # savuruş sonu
    tr.hold(0.10)
    return tr.home(0.26)


A_TR = A_track()
A_HIT1 = angle_time(A_TR, -36.0, A_T0, A_T1)  # bıçağın ucu hedefin içinden geçer
A_HIT2 = A_T1  # savuruş biter: 2. parça (alan)
A_DROPS = _sparks(5, 7, 55.0, 125.0, (55.0, 120.0), (0.22, 0.36))


def A_live(L, tr, t):
    blade_trail(L, tr, t, A_T0 - 0.01, A_T1 + A_FOLLOW * 0.5, 0.075, BLOOD, BLOOD_OL)


def A_fx(Ls, tr, t):
    tangent_cut(Ls, t - A_HIT1, 0.22, 16.0, CUT, CUT_OL)
    draw_sparks(Ls["f"], (0.0, -2.0), A_DROPS, t - A_HIT1, DROP, g=320.0)


# ------------------------------------------------------------------ B Ölüm Çemberi: bir buçuk tur, hedeften iki geçiş
B_WIND, B_SPIN = 0.12, 0.27
B_T0 = B_WIND
B_T1 = B_T0 + B_SPIN


def B_track():
    tr = Track(REST_GRIP, GRIP_PX)
    tr.to(B_WIND, "out", LG(-16.0, -2.0, -150.0))
    tr.to(B_SPIN, "inout", LG(-15.0, 0.0, 345.0))  # 495 derece
    tr.to(0.05, "out", LG(-15.0, 0.0, 362.0))
    tr.hold(0.06)
    tr2 = tr.home(0.26)
    return tr2


B_TR = B_track()
B_HIT1 = angle_time(B_TR, -36.0, B_T0, B_T1)
B_HIT2 = angle_time(B_TR, 324.0, B_T0, B_T1)
B_SP1 = _sparks(11, 6, 50.0, 130.0, (60.0, 130.0), (0.14, 0.26))
B_SP2 = _sparks(12, 6, 50.0, 130.0, (60.0, 130.0), (0.14, 0.26))


def B_live(L, tr, t):
    blade_trail(L, tr, t, B_T0, B_T1 + 0.03, 0.10, SHADOW, SHADOW_OL, alphas=(1.0, 1.0, 0.9, 0.6), linger=0.04, eat=0.12)


def B_fx(Ls, tr, t):
    for hit, sp in ((B_HIT1, B_SP1), (B_HIT2, B_SP2)):
        draw_sparks(Ls["f"], (0.0, -2.0), sp, t - hit, SPARK_R, g=260.0)
        tangent_cut(Ls, t - hit, 0.18, 12.0, CUT, CUT_OL, w=2.6)


# ------------------------------------------------------------------ C Hasat Çekişi: ötesine uzan, biçerek oyuncuya çek
C_REACH, C_DRAW, C_FOLLOW = 0.13, 0.13, 0.05
C_T0 = C_REACH
C_T1 = C_T0 + C_DRAW


def C_track():
    tr = Track(REST_GRIP, GRIP_PX)
    tr.to(C_REACH, "out", LG(8.0, -18.0, 8.0))  # hedefin ötesine, bıçak tarafının karşısına uzan
    tr.to(C_DRAW, "inout", LG(-24.0, 10.0, 150.0))  # biçerek oyuncuya doğru çek
    tr.to(C_FOLLOW, "out", LG(-27.0, 12.0, 162.0))
    tr.hold(0.08)
    return tr.home(0.26)


C_TR = C_track()
C_HIT1 = angle_time(C_TR, 50.0, C_T0, C_T1)
C_HIT2 = C_T1
C_GRASS = _sparks(21, 10, 120.0, 200.0, (40.0, 95.0), (0.30, 0.48))  # oyuncuya doğru savrulan ot
C_GRASS2 = _sparks(22, 6, 60.0, 140.0, (30.0, 70.0), (0.26, 0.40))


def C_live(L, tr, t):
    blade_trail(L, tr, t, C_T0 + 0.01, C_T1 + 0.02, 0.085, WIND, WIND_OL, alphas=(1.0, 1.0, 0.95, 0.65))


def C_fx(Ls, tr, t):
    tangent_cut(Ls, t - C_HIT1, 0.20, 14.0, CUT, CUT_OL, a_local=150.0)
    draw_sparks(Ls["f"], (0.0, 4.0), C_GRASS, t - C_HIT1, GRASS, g=150.0)
    draw_sparks(Ls["f"], (-6.0, 6.0), C_GRASS2, t - C_HIT2 + 0.02, GRASS, g=150.0)


# ------------------------------------------------------------------ D Gölge Tırpan: A + dev hayalet tırpan
D_K = 2.2
D_LAG = 0.022


def D_live(L, tr, t):
    blade_trail(L, tr, t, A_T0 + 0.01, A_T1 + 0.03, 0.09, GHOST, None, k=D_K, lag=D_LAG, width=4, alphas=(0.7, 0.58, 0.46, 0.3),
                linger=0.03, eat=0.14)
    blade_trail(L, tr, t, A_T0 - 0.01, A_T1 + A_FOLLOW * 0.5, 0.06, BLOOD, BLOOD_OL)


def D_ghost_alpha(t):
    if t < A_T0 - 0.03 or t > A_T1 + 0.20:
        return 0.0
    if t < A_T0:
        return 0.45 * clamp01((t - (A_T0 - 0.03)) / 0.03)
    if t <= A_T1 + 0.03:
        return 0.45
    return 0.45 * (1.0 - clamp01((t - A_T1 - 0.03) / 0.17))


def D_fx(Ls, tr, t):
    tangent_cut(Ls, t - A_HIT1, 0.22, 16.0, CUT, CUT_OL)


DIRS = {
    "cur": dict(title="ŞU AN - Kanca Çekiş (pençe hareketi)", sub="tırpan çizimi pençenin animasyonu + pençe için çizilmiş 3 yırtıkla",
                track=CUR_track, fx=PP.B_fx, live=PP.B_live, hits=(PP.B_HIT1, PP.B_HIT2), cur=True),
    "A": dict(title="A - Kızıl Hilal", sub="geri kurulur, hedefin önünde 260 derece biçer: kızıl hilal iz, kesik + kan damlası",
              track=lambda: A_TR, fx=A_fx, live=A_live, hits=(A_HIT1, A_HIT2)),
    "B": dict(title="B - Ölüm Çemberi", sub="bir buçuk tur döner, hedeften iki kez geçer: koyu gölge halkası, kızıl kıvılcım",
              track=lambda: B_TR, fx=B_fx, live=B_live, hits=(B_HIT1, B_HIT2)),
    "C": dict(title="C - Hasat Çekişi", sub="hedefin ötesine uzanır, biçerek oyuncuya çeker: krem rüzgâr hilali, kesilen ot",
              track=lambda: C_TR, fx=C_fx, live=C_live, hits=(C_HIT1, C_HIT2)),
    "D": dict(title="D - Gölge Tırpan", sub="A'nın biçmesi + arkasında 2,2 kat hayalet tırpan: alanı kaplayan yarı saydam hilal",
              track=lambda: A_TR, fx=D_fx, live=D_live, hits=(A_HIT1, A_HIT2), ghost=True),
}
ORDER = ["cur", "A", "B", "C", "D"]


def icon():
    return asset(ICON_PATH)


class Lane:
    def __init__(self, did, idx, t_first=0.15):
        self.did, self.idx, self.D = did, idx, DIRS[did]
        self.tr = self.D["track"]()
        self.t_first = t_first
        self.cache = {}
        self.cur = self.D.get("cur", False)

    def attack(self, t):
        if t < self.t_first:
            return 99.0, 0
        n = int((t - self.t_first) // INTERVAL)
        return t - self.t_first - n * INTERVAL, n

    def _lay(self):
        return TP.Lay() if self.cur else Lay2()

    def layers(self, ta):
        q = int(ta * FXFPS)
        if q not in self.cache:
            Ls = {"g": self._lay(), "f": self._lay()}
            self.D["fx"](Ls, self.tr, q / float(FXFPS))
            self.cache[q] = {k: v.cropped() for k, v in Ls.items()}
        return self.cache[q]

    def render(self, t):
        F = PP.lane_bg(self.idx)
        ta, _ = self.attack(t)
        lay = self.layers(ta)
        tx, ty = S(TGT)
        k_fx = WPP * ZOOM

        def put_layer(c):
            if c is not None:
                BP.blit(F, c[0], tx, ty, k_fx, 0.0, c[1])

        put_layer(lay["g"])
        fl = ta - self.D["hits"][0]
        flash = 1.0 - fl / 0.12 if 0.0 <= fl < 0.12 else 0.0
        for p in sorted([TGT, EXTRA_IN, EXTRA_OUT], key=lambda q: q[1]):
            sx, sy = S(p)
            BP.blit(F, PP.slime(), sx, sy - 2, PP.SLIME_K * ZOOM)
            if flash > 0.0 and p is not EXTRA_OUT:
                BP.blit(F, PP.slime(), sx, sy - 2, PP.SLIME_K * ZOOM, alpha=flash, tint=(255, 255, 255))
        x, y, a, sl, sw = self.tr.pose(ta)
        if self.D.get("ghost"):
            ga = D_ghost_alpha(ta)
            if ga > 0.0:
                gx, gy, gang, _, _ = self.tr.pose(max(0.0, ta - D_LAG))
                blit_tool(F, icon(), S((gx, gy)), gang, WPP * ZOOM * D_K, self.tr.piv, alpha=ga, tint=GHOST_TINT)
        L = TP.Lay() if self.cur else Lay2()
        self.D["live"](L, self.tr, ta)
        put_layer(L.cropped())
        blit_tool(F, icon(), S((x, y)), a, WPP * ZOOM * self.D.get("k", 1.0), self.tr.piv, sl, sw)
        put_layer(lay["f"])
        return Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")


def lane_label(im, did, small=False):
    d = ImageDraw.Draw(im)
    label(d, 6, 3, DIRS[did]["title"], 12)
    if not small:
        label(d, 6, im.height - 16, DIRS[did]["sub"], 10, (226, 220, 204))


def info_tile(w, h, lines, title=None):
    im = Image.new("RGB", (w, h), (30, 34, 32))
    d = ImageDraw.Draw(im)
    y = 12
    if title:
        label(d, 12, y, title, 16)
        y += 30
    for s in lines:
        label(d, 12, y, s, 11, (220, 214, 198))
        y += 18
    return im


INFO = [
    "aralık %.2f sn  ·  2 hasar parçası, alan %d px (yarı hasar)" % (INTERVAL, AOE),
    "beyaz parlama = 1. isabet (hedef + alandaki yaratık)",
    "sağdaki uzak yaratık alanın dışında (88 px), parlamaz",
    "yeni yönler: tırpan SAPINDAN döner, bıçak önde keser",
    "temas: A %.2f/%.2f · B %.2f/%.2f · C %.2f/%.2f sn" % (A_HIT1, A_HIT2, B_HIT1, B_HIT2, C_HIT1, C_HIT2),
    "efektler tırpanın paletinden, dither yok",
    "Talon + tırpan çizimi (0,575 dünya px/piksel)",
]


def build_game():
    lanes = [Lane(d, i) for i, d in enumerate(ORDER)]
    loop = 2.0 * INTERVAL
    n = int(round(loop * FPS))
    dt = loop / n
    lw, lh = int(TP.LWW * ZOOM), int(TP.LHW * ZOOM)
    info = info_tile(lw, lh, INFO, "Tırpan vuruşu")
    hd = header(lw * 2 + 4, "Tırpan vuruşu  ·  oyun ölçeği (1080p), gerçek hız", "Talon + tırpan çizimi  ·  2 vuruş döngüsü")
    frames = []
    for st in range(n):
        t = st * dt
        tiles = []
        for ln in lanes:
            im = ln.render(t)
            lane_label(im, ln.did)
            tiles.append(im)
        tiles.append(info)
        frames.append(stack_v([hd, TP.grid(tiles, 2)]))
    save_gif(frames, os.path.join(OUT, "tirpan_oyun.gif"), 1.0 / dt,
             [int(0.38 * FPS), int(0.42 * FPS), int(0.46 * FPS), int(0.52 * FPS)])
    frames[int((0.15 + 0.40) * FPS)].save(os.path.join(OUT, "tirpan_oyun_kare.png"))


CROP = (int((TGT[0] - 70) * ZOOM), int((TGT[1] - 56) * ZOOM), int((TGT[0] + 66) * ZOOM), int((TGT[1] + 52) * ZOOM))


def build_slow(speed=0.25, z=2):
    lanes = [Lane(d, i, t_first=0.05) for i, d in enumerate(ORDER)]
    fps = 40
    real_len = 0.85
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
        tiles.append(info_tile(cw, ch, [
            "yakınlaştırma x%d (1 dünya px = %d ekran px)" % (z, int(ZOOM * z)),
            "süre: %.2f sn (gerçek)" % max(0.0, t - 0.05),
            "",
            "temaslar: A %.2f/%.2f · B %.2f/%.2f" % (A_HIT1, A_HIT2, B_HIT1, B_HIT2),
            "C %.2f/%.2f · D = A" % (C_HIT1, C_HIT2),
            "ŞU AN %.3f/%.3f sn" % (PP.B_HIT1, PP.B_HIT2),
            "beyaz parlama = 1. isabet",
        ], "YAVAŞ ÇEKİM x%.2f" % speed))
        frames.append(TP.grid(tiles, 3))
    save_gif(frames, os.path.join(OUT, "tirpan_yavas.gif"), fps, [int(0.24 / dt), int(0.28 / dt), int(0.34 / dt)])


OFFS = [-0.10, -0.05, -0.02, 0.0, 0.02, 0.04, 0.07, 0.11, 0.18, 0.28]
SCROP = (int((TGT[0] - 66) * ZOOM), int((TGT[1] - 54) * ZOOM), int((TGT[0] + 62) * ZOOM), int((TGT[1] + 50) * ZOOM))


def build_strip(z=1):
    rows = []
    cw, ch = (SCROP[2] - SCROP[0]) * z, (SCROP[3] - SCROP[1]) * z
    LBL = 150
    for i, did in enumerate(ORDER):
        ln = Lane(did, i, t_first=0.0)
        t0 = DIRS[did]["hits"][0]
        row = Image.new("RGB", (LBL + len(OFFS) * (cw + 2), ch + 18), (24, 26, 26))
        d = ImageDraw.Draw(row)
        for j, o in enumerate(OFFS):
            tt = max(0.0, t0 + o)
            im = ln.render(tt).crop(SCROP).resize((cw, ch), Image.NEAREST)
            row.paste(im, (LBL + j * (cw + 2), 18))
            label(d, LBL + j * (cw + 2) + 4, 2, "%.2f sn%s" % (tt, "  1. temas" if o == 0.0 else ""), 10, (220, 214, 198))
        label(d, 6, 22, DIRS[did]["title"].split(" (")[0], 12)
        rows.append(row)
    im = stack_v(rows, 6)
    path = os.path.join(OUT, "tirpan_kareler.png")
    im.save(path)
    print("kareler", path, im.size)


# ================================================================== v2: GÖLGE TIRPAN güzelleştirme (kullanıcı D'yi seçti)
## Kullanıcı: "gölge tırpan istiyorum ama bu efekt daha iyi olabilir. biraz daha güzel hale getir, ayrıca tırpan biraz daha büyük
## görünmeli böyle balta gibi olmuş". Tırpan x1,57 (weapon_tier_art.gd SIZE_MULT: piksel = karakter pikseli 0,903, boy ~36 dünya px).
## Eski D'nin sorunları: hayalet = 2,2 kat büyütülmüş İRİ pikselli düz pembe silüet; hilal tek renk yarı saydam leke (yön/kenar yok).
## Yeni hayalet bıçak efekt ızgarasında (0,575) çizilir: göbekten uca sivrilen bıçak + kenar/iç tonları; sap yok (yalnız bıçak).
import random  # noqa: E402

ICON_K = 1.57
GK = 1.45  # hayalet bıçak, gerçek tırpanın x1,45'i (toplam x2,28)
BLADE_GHOST_PX = [(27.0, 6.5)] + BLADE_PX
GB_W = [9.0, 8.0, 7.0, 6.0, 5.0, 3.5, 2.0]  # efekt pikseli kalınlık, uca sivrilir


def big_track():
    rest = px_world((REST_C[0], REST_C[1], REST_ANG), CENTER_PX, GRIP_PX, ICON_K)
    tr = Track((rest[0], rest[1], REST_ANG, 1.0, 1.0), GRIP_PX)
    tr.to(A_WIND, "out", LG(-27.0, -5.0, -150.0))
    tr.to(A_TENSE, "inout", LG(-28.0, -6.0, -162.0))
    tr.to(A_SWING, "acc", LG(-22.0, 2.0, 98.0))
    tr.to(A_FOLLOW, "out", LG(-21.0, 3.0, 120.0))
    tr.hold(0.10)
    return tr.home(0.26)


V_TR = big_track()
V_HIT1 = angle_time(V_TR, -36.0, A_T0, A_T1)
V_HIT2 = A_T1
GKT = ICON_K * GK


def _shift(m, dy, dx):
    o = np.zeros_like(m)
    h, w = m.shape
    o[max(0, dy):h + min(0, dy), max(0, dx):w + min(0, dx)] = m[max(0, -dy):h + min(0, -dy), max(0, -dx):w + min(0, -dx)]
    return o


def erode(m):
    return m & _shift(m, 1, 0) & _shift(m, -1, 0) & _shift(m, 0, 1) & _shift(m, 0, -1)


def blade_mask(pose, piv, k):
    pts = [TP.fpx(off(px_world(pose, piv, p, k))) for p in BLADE_GHOST_PX]
    img = Image.new("L", (TP.FXW, TP.FXH), 0)
    d = ImageDraw.Draw(img)
    for i in range(len(pts) - 1):
        w = GB_W[i]
        d.line([pts[i], pts[i + 1]], fill=255, width=max(1, int(round(w))))
        r = w / 2.0 - 0.5
        x, y = pts[i + 1]
        if r > 0.5:
            d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return np.array(img) > 0


def ghost_blade(L, pose, piv, k, cols, alpha):
    """Hayalet bıçak: dış kenar cols[0], bir iç halka cols[1], çekirdek cols[2]."""
    if alpha <= 0.02:
        return
    m = blade_mask(pose, piv, k)
    e1 = erode(m)
    e2 = erode(e1)
    L.paint(0, 0, m & ~e1, cols[0], alpha)
    L.paint(0, 0, e1 & ~e2, cols[1], alpha)
    L.paint(0, 0, e2, cols[2], alpha * 0.92)


def make_motes(seed, n, tr, k, t0, t1, lag):
    rng = random.Random(seed)
    ms = []
    nb = len(BLADE_PX)
    for i in range(n):
        s = t0 + (t1 - t0) * (i + rng.random()) / n
        u = rng.uniform(0.3, 1.0) * (nb - 1)
        pose = tr.pose(max(0.0, s - lag))
        i0 = int(u)
        f = u - i0
        a = px_world(pose, tr.piv, BLADE_PX[i0], k)
        b = px_world(pose, tr.piv, BLADE_PX[min(nb - 1, i0 + 1)], k)
        p = (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
        ms.append((s, off(p), rng.uniform(-10.0, 10.0), rng.uniform(-40.0, -20.0), rng.uniform(0.30, 0.52), rng.random() < 0.45))
    return ms


def draw_motes(L, ms, t, cols):
    n = len(cols)
    for (s, p, vx, vy, life, big) in ms:
        age = t - s
        if age < 0.0 or age >= life:
            continue
        k = age / life
        x = p[0] + vx * age
        y = p[1] + vy * age * (1.0 - 0.35 * k)
        cx, cy = (int(v) for v in TP.fpx((x, y)))
        col = cols[min(n - 1, int(k * n))]
        a = 1.0 - k * k
        L.put(cx, cy, col, a)
        if big and k < 0.55:
            L.put(cx + 1, cy, col, a)
            L.put(cx, cy + 1, col, a)
            L.put(cx + 1, cy + 1, col, a)


def ghost_env(t):
    """Hayaletin görünürlüğü: savuruştan hemen önce belirir, biçme boyunca tam, sonra 0,17 sn'de söner."""
    if t < A_T0 - 0.03 or t > A_T1 + 0.20:
        return 0.0
    if t < A_T0:
        return clamp01((t - (A_T0 - 0.03)) / 0.03)
    if t <= A_T1 + 0.03:
        return 1.0
    return 1.0 - clamp01((t - A_T1 - 0.03) / 0.17)


def real_trail(L, tr, t):
    blade_trail(L, tr, t, A_T0 - 0.01, A_T1 + A_FOLLOW * 0.5, 0.05, BLOOD, BLOOD_OL, k=ICON_K, width=4)


def hit_cut(Ls, t):
    tangent_cut(Ls, t - V_HIT1, 0.22, 18.0, CUT, CUT_OL, w=3.4)


# ---- D1 Ruh Bıçağı: ışıyan hayalet bıçak + ışıyan hilal (ön kenar açık pembe, kuyruk mora söner) + yükselen ruh zerreleri
SOUL = cl("#ffe0d6 #f0505e #a82848 #4e1a4a")
SOUL_BLADE = cl("#ffe0d6 #f0505e #a82848")
SOUL_MOTE = cl("#ffe0d6 #f6909a #c04466 #6a2450")
D1_MOTES = make_motes(31, 16, V_TR, GKT, A_T0, A_T1 + 0.02, D_LAG)


def D1_live(L, tr, t):
    g = ghost_env(t)
    blade_trail(L, tr, t, A_T0 + 0.005, A_T1 + 0.03, 0.085, SOUL, None, k=GKT, lag=D_LAG, width=5,
                alphas=(0.9, 0.72, 0.5, 0.28), linger=0.03, eat=0.14, taper=0.9)
    ghost_blade(L, tr.pose(max(0.0, t - D_LAG)), tr.piv, GKT, SOUL_BLADE, 0.8 * g)
    real_trail(L, tr, t)


def D1_fx(Ls, tr, t):
    hit_cut(Ls, t)
    draw_motes(Ls["f"], D1_MOTES, t, SOUL_MOTE)


# ---- D2 Yankılanan Bıçak: dolu hilal yok; hayalet bıçak + arkasından gelen 3 soluk yankısı (ardıl görüntü), ince kızıl kenar izi
ECHO = cl("#ffd6cc #e0485a #8a2450")
ECHO_LAGS = ((0.0, 0.85), (0.022, 0.55), (0.044, 0.34), (0.066, 0.18))
D2_MOTES = make_motes(41, 10, V_TR, GKT, A_T0, A_T1 + 0.02, D_LAG)


def D2_live(L, tr, t):
    g = ghost_env(t)
    blade_trail(L, tr, t, A_T0 + 0.005, A_T1 + 0.03, 0.06, SOUL, None, k=GKT, lag=D_LAG, width=2,
                alphas=(0.85, 0.6, 0.35, 0.18), linger=0.02, eat=0.10, taper=0.3)
    for lag, a in reversed(ECHO_LAGS):
        ghost_blade(L, tr.pose(max(0.0, t - D_LAG - lag)), tr.piv, GKT, ECHO, a * g)
    real_trail(L, tr, t)


def D2_fx(Ls, tr, t):
    hit_cut(Ls, t)
    draw_motes(Ls["f"], D2_MOTES, t, SOUL_MOTE)


# ---- D3 Kara Hasat: koyu (gölge) hayalet bıçak kızıl kenarlı, koyu hilal, sonunda yükselen koyu duman + kızıl kor
DARK = cl("#f06078 #8a2a56 #34183c #1c0e22")
DARK_BLADE = cl("#f06078 #4a2048 #24122c")
SMOKE_D = cl("#7a4a7e #64386c #4c2a56 #361e40")
EMBER_R = cl("#ffd8d0 #f06078 #c42430 #6a1a2a")
## Duman (2026-11-09 kullanıcı: "kara hasat iyi ama dumanlar daha çabuk solsun"): ömür 0,42-0,56 -> 0,20-0,28 sn, saydamlık (1-k)^2.
SMOKE_LIFE = (0.20, 0.28)


def d3_particles(tr):
    """Koru + duman pufları (yer çekimi yok); gen_tirpan_fx.py çerçeveyi sağa çevirince yeniden kurar."""
    embers = make_motes(51, 9, tr, GKT, A_T0, A_T1, D_LAG)
    rng = random.Random(52)
    puffs = []
    for i in range(7):
        s = A_T0 + 0.012 + (A_T1 - A_T0 - 0.012) * i / 6.0
        pose = tr.pose(max(0.0, s - D_LAG))
        p = off(px_world(pose, tr.piv, BLADE_PX[rng.randint(2, 5)], GKT))
        puffs.append((s + 0.03, p, rng.uniform(2.6, 3.6), rng.uniform(*SMOKE_LIFE)))
    return embers, puffs


D3_EMBERS, D3_PUFFS = d3_particles(V_TR)


def D3_live(L, tr, t):
    g = ghost_env(t)
    blade_trail(L, tr, t, A_T0 + 0.005, A_T1 + 0.03, 0.09, DARK, None, k=GKT, lag=D_LAG, width=5,
                alphas=(0.95, 0.82, 0.62, 0.36), linger=0.03, eat=0.14, taper=0.9)
    ghost_blade(L, tr.pose(max(0.0, t - D_LAG)), tr.piv, GKT, DARK_BLADE, 0.88 * g)
    real_trail(L, tr, t)


def D3_fx(Ls, tr, t):
    for (s, p, r0, life) in D3_PUFFS:
        age = t - s
        if 0.0 <= age < life:
            k = age / life
            e = math.sin(k * math.pi / 2)
            TP.np_cloud(Ls["g"], [(p[0] - 1.5, p[1] - 9.0 * e, r0 * (0.8 + 0.7 * e)), (p[0] + 1.8, p[1] - 9.0 * e + 1.0, r0 * (0.6 + 0.6 * e))],
                        SMOKE_D, None, 0.42 * (1.0 - k) ** 2)
    hit_cut(Ls, t)
    draw_motes(Ls["f"], D3_EMBERS, t, EMBER_R)


DIRS.update({
    "D1": dict(title="D1 - Ruh Bıçağı", sub="ışıyan hayalet bıçak + ışıyan hilal (açık pembe kenar, mora söner) + yükselen ruh zerreleri",
               track=lambda: V_TR, fx=D1_fx, live=D1_live, hits=(V_HIT1, V_HIT2), k=ICON_K),
    "D2": dict(title="D2 - Yankılanan Bıçak", sub="dolu hilal yok: hayalet bıçak + arkasından 3 soluk yankısı, ince kenar izi",
               track=lambda: V_TR, fx=D2_fx, live=D2_live, hits=(V_HIT1, V_HIT2), k=ICON_K),
    "D3": dict(title="D3 - Kara Hasat", sub="koyu gölge bıçak kızıl kenarlı, koyu hilal, sonunda yükselen duman + kızıl kor",
               track=lambda: V_TR, fx=D3_fx, live=D3_live, hits=(V_HIT1, V_HIT2), k=ICON_K),
})
DIRS["D"]["title"] = "ESKİ D - Gölge Tırpan (küçük tırpan)"
ORDER2 = ["D", "D1", "D2", "D3"]
CROP2 = (int((TGT[0] - 84) * ZOOM), int((TGT[1] - 62) * ZOOM), int((TGT[0] + 56) * ZOOM), int((TGT[1] + 60) * ZOOM))


def build_v2_game():
    lanes = [Lane(d, i) for i, d in enumerate(ORDER2)]
    loop = 2.0 * INTERVAL
    n = int(round(loop * FPS))
    dt = loop / n
    lw = int(TP.LWW * ZOOM)
    hd = header(lw * 2 + 4, "Gölge Tırpan v2  ·  oyun ölçeği (1080p), gerçek hız",
                "tırpan x1,57 (piksel = karakter pikseli)  ·  hayalet bıçak efekt ızgarasında, dither yok  ·  temas %.2f / %.2f sn" % (V_HIT1, V_HIT2))
    frames = []
    for st in range(n):
        t = st * dt
        tiles = []
        for ln in lanes:
            im = ln.render(t)
            lane_label(im, ln.did)
            tiles.append(im)
        frames.append(stack_v([hd, TP.grid(tiles, 2)]))
    save_gif(frames, os.path.join(OUT, "golge_v2_oyun.gif"), 1.0 / dt,
             [int(0.38 * FPS), int(0.42 * FPS), int(0.46 * FPS), int(0.52 * FPS)])
    frames[int((0.15 + 0.41) * FPS)].save(os.path.join(OUT, "golge_v2_oyun_kare.png"))


def build_v2_slow(speed=0.25, z=2):
    lanes = [Lane(d, i, t_first=0.05) for i, d in enumerate(ORDER2)]
    fps = 40
    real_len = 0.80
    n = int(round(real_len / speed * fps))
    dt = real_len / n
    cw, ch = (CROP2[2] - CROP2[0]) * z, (CROP2[3] - CROP2[1]) * z
    frames = []
    for st in range(n):
        t = st * dt
        tiles = []
        for ln in lanes:
            im = ln.render(t).crop(CROP2).resize((cw, ch), Image.NEAREST)
            lane_label(im, ln.did, small=True)
            tiles.append(im)
        frames.append(TP.grid(tiles, 2))
    save_gif(frames, os.path.join(OUT, "golge_v2_yavas.gif"), fps, [int(0.27 / dt), int(0.31 / dt), int(0.36 / dt)])


V2_OFFS = [-0.08, -0.04, -0.02, 0.0, 0.02, 0.04, 0.07, 0.11, 0.17, 0.26]


def build_v2_strip():
    rows = []
    cw, ch = CROP2[2] - CROP2[0], CROP2[3] - CROP2[1]
    LBL = 150
    for i, did in enumerate(ORDER2):
        ln = Lane(did, i, t_first=0.0)
        t0 = DIRS[did]["hits"][0]
        row = Image.new("RGB", (LBL + len(V2_OFFS) * (cw + 2), ch + 18), (24, 26, 26))
        d = ImageDraw.Draw(row)
        for j, o in enumerate(V2_OFFS):
            tt = max(0.0, t0 + o)
            row.paste(ln.render(tt).crop(CROP2), (LBL + j * (cw + 2), 18))
            label(d, LBL + j * (cw + 2) + 4, 2, "%.2f sn%s" % (tt, "  1. temas" if o == 0.0 else ""), 10, (220, 214, 198))
        label(d, 6, 22, DIRS[did]["title"].split(" (")[0], 12)
        rows.append(row)
    im = stack_v(rows, 6)
    im.save(os.path.join(OUT, "golge_v2_kareler.png"))
    print("kareler v2", im.size)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    gi = os.path.join(HERE, "out", ".gdignore")
    if not os.path.exists(gi):
        open(gi, "w").close()
    for w in (sys.argv[1:] or ["kareler", "oyun", "yavas"]):
        {"oyun": build_game, "yavas": build_slow, "kareler": build_strip,
         "v2": build_v2_game, "v2yavas": build_v2_slow, "v2kareler": build_v2_strip}[w]()
