# -*- coding: utf-8 -*-
"""TOPUZ vuruş animasyonu + efekti PROTOTİPLERİ (2026-10-17, oyuna bağlı DEĞİL). Kullanıcı: "topuzun animasyonları ve efekti için
yeni prototipler hazırla".

Bugün (teşhis; weapon_topuz.tscn + player.gd _configure_topuz_melee + weapon.gd _do_melee_swing / _spawn_slash_fx):
  - Menzil 120, tek parça, alan hasarı yarıçap 95 dünya px (yarı hasar). Aralık 1,1111 / 0,7 = 1,59 sn.
  - İkon hedefin 8 px önü + saldırı yönüne DİK 24 px'e uçar (0,12 sn, baş uçuş yönüne bakar): hedefin YANINA park eder, vurmaz.
    Efekt bitene kadar (8 kare / 18 fps = 0,44 sn) bekler, 0,26 sn'de döner. Hasar ATIŞ ANINDA (ikon varmadan).
  - Efekt fx_topuz_slash: 128 px sayfa (beyaz nokta -> turuncu halka + gri puflar -> çapraz çizgilere dağılan duman), ölçek
    1,125 x sahip 0,5 = 0,5625 dünya px/piksel (~72 px kare), aynı yerde (hedefin 24 px yanı), dönmez, yöne göre aynalanır.
    Halka en geniş ~31 dünya px yarıçap: alan hasarının (95) üçte biri.

Dört yön (hepsi 1 sanat pikseli = 0,575 dünya px = Zanaatkâr silahlarıyla aynı yoğunluk; efekt 30 fps'e kuantalı = sprite sayfası
gibi; isabet = temas anı; yeni yönlerde topuz SAPINDAN döner (oyunda Sprite2D offset gerekir), ŞU AN ikon merkezinden):
  A Yer Sarsıntısı  - başın üstüne kaldır, geri ger, yere indir (tutukluk + ezilme): yer çatlağı + çukur, toz dalgası ALAN SINIRINA
                      (95 px) kadar açılıp hilallere kırılır, taş kırıntıları sekerek düşer
  B Demir Savuruş   - hedefin önünde geniş çapraz yay (sapı merkeze yakın döner), çelik iz hilali savuruş boyunca uzar, temasta
                      çatırtı yıldızı + darbe çizgileri + öne kıvılcım; yerde sadece küçük toz. Yönle döner.
  C Fırıldak Çekiç  - hedefin üstünde 1,5 tur hızlanarak döner (krem dönüş izi) ve baş aşağı düşer: kehribar şok halkaları +
                      yer parıltısı + yükselen korlar
  D Toz ve Kor      - bugünkü halka + duman fikri piksel sanatıyla: kısa çakma, kehribar halka, tek dış çizgili gri duman bulutu
                      hilallere dağılır, birkaç kor
Halkalar yerde 2:1 elips çizilir; koddaki alan hasarı DAİRE (Enemy.get_enemies_near). Oyuna alınırken ya alan elipse çevrilir
(Şovalye kubbesi gibi) ya da halka daire çizilir.

Çıktılar (out/topuz/): topuz_oyun.gif (1080p oyun ölçeği, gerçek hız, 2 vuruş; ŞU AN + A-D), topuz_yavas.gif (x0,25 hız, x2 yakın),
topuz_kareler.png (temasa hizalı kare şeridi), topuz_oyun_kare.png.
Çalıştırma: python tools/proto_20261017/topuz_proto.py [oyun|yavas|kareler]   (argümansız: hepsi)
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bicak_proto as BP  # noqa: E402  (numpy blit, yıldız/yay/çizgi bantları, başlık, GIF)
import mermi_proto as MP  # noqa: E402  (çimen, varlık yükleme, Bayer, yazı)
from mermi_proto import cl, hx, on, asset, label, grass  # noqa: E402
from bicak_proto import blit, header, stack_v, save_gif  # noqa: E402

OUT = os.path.join(HERE, "out", "topuz")
ZOOM = 2.0
WPP = 0.575  # silah + efekt sanat pikseli (dünya px) = weapon_tier_art.gd WORLD_PX
CHAR_K = 2.2368375 * 0.8075 * 0.5  # Şovalye dünya px / karakter pikseli (characters.gd ölçek x EntityScale x oyuncu kökü)
SLIME_K = 0.94905
FPS = 50
INTERVAL = 1.1111 / 0.7  # weapon_topuz.tscn fire_rate / GameManager.WEAPON_ATTACK_SPEED_MULT
FXFPS = 30
CUR_FX_K = 1.125 * 0.5  # fx_topuz_slash ölçeği x sahip ölçeği
CUR_FX_FPS = 18.0  # hit_frames.tres speed
CUR_FX_N = 8
AOE = 95.0  # player.gd _configure_topuz_melee aoe_radius

ART_FWD = -math.pi / 4  # zanaat topuzunda baş sağ-üstte (weapon_tier_art.gd FORWARD)
REST_ANG = -math.pi / 2  # dinlenmede baş yukarı (REST -45 döner)
GRIP_PX = (12.0, 35.0)  # topuz_L3.png sapın tutma noktası (yeni yönlerde dönme merkezi)
HEAD_PX = (35.5, 13.5)  # topuz başının merkezi
CENTER_PX = (24.0, 24.0)
L_HEAD = math.hypot(HEAD_PX[0] - GRIP_PX[0], HEAD_PX[1] - GRIP_PX[1]) * WPP  # tutma noktası -> baş (dünya px)

# şerit (dünya px)
LWW, LHW = 250, 132
CHAR = (36.0, 60.0)
REST_C = (CHAR[0] + 22.0, CHAR[1] - 34.0)  # dinlenmede ikon merkezi
TGT = (138.0, 64.0)
G_OFF = (0.0, 7.0)  # yaratığın ayağı (alan hasarı merkezi), TGT'ye göre
EXTRA = [(TGT[0] + 46.0, TGT[1] - 22.0), (TGT[0] - 30.0, TGT[1] + 26.0)]  # alan içindeki iki yaratık daha
_d = (TGT[0] - REST_C[0], TGT[1] - REST_C[1])
DIR_ANG = math.atan2(_d[1], _d[0])
DIRV = (math.cos(DIR_ANG), math.sin(DIR_ANG))
D2R = math.pi / 180.0

FXW, FXH = 360, 260  # efekt tuvali (sanat px), merkez = TGT
BP.FXW, BP.FXH = FXW, FXH  # BP.star / arc_band / line_band aynı tuvali kullansın
_YY, _XX = np.mgrid[0:FXH, 0:FXW]
BAYT = (np.array(MP.BAY, np.float32)[_YY & 3, _XX & 3] + 0.5) / 16.0


def S(p):
    return (p[0] * ZOOM, p[1] * ZOOM)


def W(p):
    """B'nin yerel çerçevesi (x = saldırı yönü) -> TGT'ye göre dünya ofseti."""
    c, s = DIRV
    return (c * p[0] - s * p[1], s * p[0] + c * p[1])


def off(p):
    return (p[0] - TGT[0], p[1] - TGT[1])


def clamp01(x):
    return min(1.0, max(0.0, x))


# ------------------------------------------------------------------ topuz ikonu (sap pivotu + boy/en ezilmesi)
def _rot(v, a):
    c, s = math.cos(a), math.sin(a)
    return (c * v[0] - s * v[1], s * v[0] + c * v[1])


def blit_mace(F, src, pw, ang, k, piv, sl=1.0, sw=1.0):
    """pw: pivot pikselinin ekran konumu; ang: başın baktığı dünya açısı; sl/sw: topuzun BOYU/ENİ boyunca ölçek (ezilme)."""
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
    a = samp[..., 3:4] / 255.0
    F[y0:y1, x0:x1] = F[y0:y1, x0:x1] * (1.0 - a) + samp[..., :3] * a


def pivot_world_from_center(center, ang, piv):
    """İkon merkezi `center`dayken `piv` pikselinin dünya konumu."""
    v = ((piv[0] - CENTER_PX[0]) * WPP, (piv[1] - CENTER_PX[1]) * WPP)
    r = _rot(v, ang - ART_FWD)
    return (center[0] + r[0], center[1] + r[1])


GRIP_REST = pivot_world_from_center(REST_C, REST_ANG, GRIP_PX)


# ------------------------------------------------------------------ hareket
def ez(kind, x):
    x = clamp01(x)
    if kind == "out":
        return math.sin(x * math.pi / 2)
    if kind == "in":
        return x * x
    if kind == "inout":
        return 0.5 - 0.5 * math.cos(math.pi * x)
    if kind == "acc":  # hızlanarak (sıfırdan başlamaz)
        return 0.3 * x + 0.7 * x * x
    return x


def P(x, y, ang_deg, sl=1.0, sw=1.0):
    return (x, y, ang_deg * D2R, sl, sw)


def grip_for_head(head, ang_deg):
    a = ang_deg * D2R
    return (head[0] - L_HEAD * math.cos(a), head[1] - L_HEAD * math.sin(a))


class Track:
    """İkon yolu: parçalar (t0, t1, ease, fn(e) -> poz). Poz = (x, y, açı, boy ölçeği, en ölçeği): x, y pivotun dünya konumu
    (yeni yönlerde sapın tutma noktası, ŞU AN'da ikon merkezi), açı = başın baktığı dünya açısı (radyan, sarmasız)."""

    def __init__(self, start, pivot_px=GRIP_PX):
        self.segs, self.t, self.cur, self.start, self.piv = [], 0.0, start, start, pivot_px

    def add(self, dur, kind, fn):
        self.segs.append((self.t, self.t + dur, kind, fn))
        self.t += dur
        self.cur = fn(1.0)
        return self

    def to(self, dur, kind, pose):
        a = self.cur
        return self.add(dur, kind, lambda e, a=a, b=pose: tuple(a[i] + (b[i] - a[i]) * e for i in range(5)))

    def hold(self, dur):
        return self.to(dur, "lin", self.cur)

    def home(self, dur):
        a = self.cur
        d = (self.start[2] - a[2] + math.pi) % (2 * math.pi) - math.pi  # en kısa yoldan dinlenme açısına
        return self.to(dur, "inout", (self.start[0], self.start[1], a[2] + d, 1.0, 1.0))

    def pose(self, t):
        for (t0, t1, kind, fn) in self.segs:
            if t0 <= t < t1:
                return fn(ez(kind, (t - t0) / (t1 - t0)))
        return self.start

    def head(self, t):
        x, y, a, sl, _ = self.pose(t)
        return (x + L_HEAD * sl * math.cos(a), y + L_HEAD * sl * math.sin(a))


REST_POSE = (GRIP_REST[0], GRIP_REST[1], REST_ANG, 1.0, 1.0)


# ---- ŞU AN (oyundaki): hedefin 8 px önü + dik 24 px'e uç, efekt boyunca bekle, dön
CUR_FX_HOLD = CUR_FX_N / CUR_FX_FPS
_perp = (-DIRV[1], DIRV[0])
CUR_PARK = (TGT[0] - DIRV[0] * 8.0 + _perp[0] * 24.0, TGT[1] - DIRV[1] * 8.0 + _perp[1] * 24.0)
CUR_FX_POS = CUR_PARK  # _spawn_slash_fx: at_position - dir*8 + _melee_final_swing_offset (aynı nokta)


def CUR_track():
    seg_ang = math.atan2(CUR_PARK[1] - REST_C[1], CUR_PARK[0] - REST_C[0])
    tr = Track((REST_C[0], REST_C[1], REST_ANG, 1.0, 1.0), CENTER_PX)
    return tr.to(0.12, "out", (CUR_PARK[0], CUR_PARK[1], seg_ang, 1.0, 1.0)).hold(CUR_FX_HOLD).home(0.26)


# ---- A Yer Sarsıntısı
A_HIT = 0.27
A_HEAD = (TGT[0] - 4.0, TGT[1] + 1.0)


def A_track():
    gc = grip_for_head(A_HEAD, 40.0)
    tr = Track(REST_POSE)
    tr.to(0.15, "out", P(TGT[0] - 20.0, TGT[1] - 36.0, -150.0))
    tr.to(0.06, "inout", P(TGT[0] - 22.0, TGT[1] - 40.0, -168.0))  # geri ger (beklenti)
    tr.to(0.06, "in", P(gc[0], gc[1], 40.0))  # tepeden indir
    tr.to(0.03, "lin", P(gc[0], gc[1], 40.0, 0.86, 1.2))  # tutukluk + ezilme
    tr.to(0.04, "out", P(gc[0], gc[1], 40.0))
    tr.to(0.06, "out", P(gc[0] - 2.0, gc[1] - 5.0, 22.0))  # geri seker
    tr.hold(0.10)
    return tr.home(0.26)


# ---- B Demir Savuruş (yerel çerçeve: x = saldırı yönü)
B_HIT = 0.24
B_C = (-14.0, 0.0)  # savuruş merkezi (oyuncu ile hedef arası)
B_RH = 22.0  # merkez -> baş
B_RG = B_RH - L_HEAD  # merkez -> tutma noktası


def _b_pose(a_deg):
    a = a_deg * D2R
    g = W((B_C[0] + B_RG * math.cos(a), B_C[1] + B_RG * math.sin(a)))
    return (TGT[0] + g[0], TGT[1] + g[1], a + DIR_ANG, 1.0, 1.0)


def B_track():
    tr = Track(REST_POSE)
    tr.to(0.13, "out", _b_pose(-110.0))

    def arc(a0, a1):
        return lambda e: _b_pose(a0 + (a1 - a0) * e)

    tr.add(0.05, "inout", arc(-110.0, -135.0))  # geri ger
    tr.add(0.06, "in", arc(-135.0, 0.0))  # savur -> temas
    tr.hold(0.04)  # tutukluk
    tr.add(0.06, "out", arc(0.0, 70.0))  # devam
    tr.hold(0.12)
    return tr.home(0.26)


def B_head_deg(t):
    """Savuruş açısı (yerel, derece) - iz hilali başı izler."""
    if t < 0.13:
        return None
    if t < 0.18:
        return -110.0 - 25.0 * ez("inout", (t - 0.13) / 0.05)
    if t < 0.24:
        return -135.0 + 135.0 * ez("in", (t - 0.18) / 0.06)
    if t < 0.28:
        return 0.0
    return 70.0 * ez("out", (t - 0.28) / 0.06)


# ---- C Fırıldak Çekiç
C_HIT = 0.36
C_HEAD = (TGT[0] - 2.0, TGT[1] + 2.0)
C_M1 = (TGT[0] - 2.0, TGT[1] - 34.0)
C_MC = (C_HEAD[0], C_HEAD[1] - L_HEAD / 2.0)


def _c_from_mid(m, a):
    return (m[0] - L_HEAD / 2.0 * math.cos(a), m[1] - L_HEAD / 2.0 * math.sin(a))


def C_track():
    g1 = _c_from_mid(C_M1, REST_ANG)
    tr = Track(REST_POSE)
    tr.to(0.12, "out", (g1[0], g1[1], REST_ANG, 1.0, 1.0))

    def spin(e):  # 540 derece döner (baş yukarıdan aşağıya), sona doğru düşer
        a = (-90.0 + 540.0 * e) * D2R
        m = (C_M1[0] + (C_MC[0] - C_M1[0]) * e, C_M1[1] + (C_MC[1] - C_M1[1]) * e ** 2.2)
        g = _c_from_mid(m, a)
        return (g[0], g[1], a, 1.0, 1.0)

    tr.add(0.24, "acc", spin)
    gc = tr.cur
    tr.to(0.03, "lin", (gc[0], gc[1], gc[2], 0.85, 1.2))
    tr.to(0.03, "out", (gc[0], gc[1], gc[2], 1.0, 1.0))
    tr.to(0.06, "out", (gc[0] - 1.0, gc[1] - 6.0, gc[2] - 20.0 * D2R, 1.0, 1.0))
    tr.hold(0.08)
    return tr.home(0.26)


# ---- D Toz ve Kor
D_HIT = 0.16
D_HEAD = (TGT[0] - 4.0, TGT[1] + 1.0)


def D_track():
    gc = grip_for_head(D_HEAD, 25.0)
    tr = Track(REST_POSE)
    tr.to(0.11, "out", P(TGT[0] - 22.0, TGT[1] - 16.0, -125.0))
    tr.to(0.05, "in", P(gc[0], gc[1], 25.0))
    tr.to(0.02, "lin", P(gc[0], gc[1], 25.0, 0.9, 1.12))
    tr.to(0.03, "out", P(gc[0], gc[1], 25.0))
    tr.to(0.05, "out", P(gc[0] - 1.0, gc[1] - 4.0, 10.0))
    tr.hold(0.14)
    return tr.home(0.26)


# ------------------------------------------------------------------ efekt tuvali (sanat pikseli, numpy)
class Lay:
    def __init__(self):
        self.a = np.zeros((FXH, FXW, 4), np.float32)

    def put(self, x, y, col, a=1.0):
        if 0 <= x < FXW and 0 <= y < FXH and on(x, y, a):
            self.a[y, x, 0:3] = col
            self.a[y, x, 3] = 255.0

    def paint(self, y0, x0, mask, cols, alpha):
        """mask (h, w); cols (h, w, 3) ya da tek renk; alpha skaler ya da (h, w); Bayer ile."""
        h, w = mask.shape
        m = mask & (np.asarray(alpha, np.float32) > BAYT[y0:y0 + h, x0:x0 + w])
        if not m.any():
            return
        sub = self.a[y0:y0 + h, x0:x0 + w]
        c = np.asarray(cols, np.float32)
        sub[m, 0:3] = c[m] if c.ndim == 3 else c
        sub[m, 3] = 255.0

    def cropped(self):
        al = self.a[..., 3]
        ys, xs = np.nonzero(al)
        if len(ys) == 0:
            return None
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        return self.a[y0:y1, x0:x1].copy(), (FXW / 2.0 - x0, FXH / 2.0 - y0)


def fpx(p):
    return (FXW / 2.0 + p[0] / WPP, FXH / 2.0 + p[1] / WPP)


def _box(cx, cy, rx, ry, pad=3):
    x0, x1 = max(0, int(cx - rx - pad)), min(FXW, int(cx + rx + pad) + 1)
    y0, y1 = max(0, int(cy - ry - pad)), min(FXH, int(cy + ry + pad) + 1)
    return (x0, x1, y0, y1) if x0 < x1 and y0 < y1 else None


def np_ring(L, c, rx0, ry0, rx1, ry1, w, cols, k, nbreak=6, phase=0.0, ol=None, fade=1.0, brk=0.75):
    """Dışa açılan elips halka (dış kenar elipste, içe w sanat px); k büyüdükçe incelir ve nbreak hilale kırılır."""
    if k < 0.0 or k >= 1.0:
        return
    e = math.sin(k * math.pi / 2)
    Rx, Ry = max(0.5, (rx0 + (rx1 - rx0) * e) / WPP), max(0.5, (ry0 + (ry1 - ry0) * e) / WPP)
    cx, cy = fpx(c)
    b = _box(cx, cy, Rx, Ry)
    if not b:
        return
    x0, x1, y0, y1 = b
    X = _XX[y0:y1, x0:x1] + 0.5 - cx
    Y = _YY[y0:y1, x0:x1] + 0.5 - cy
    t = np.arctan2(Y / Ry, X / Rx)
    rho = np.hypot(X / Rx, Y / Ry)
    rt = np.hypot(Rx * np.cos(t), Ry * np.sin(t))
    d = (1.0 - rho) * rt
    m = 0.6 + 0.4 * np.sin(nbreak * t + phase) - k * brk
    wv = w * m * (1.0 - k * 0.6)
    band = (m > 0) & (d >= 0) & (d < wv)
    f = d / np.maximum(wv, 1e-3)
    ci = np.clip((f >= 0.4).astype(np.int32) + int(k * 2.2), 0, len(cols) - 1)
    C = np.array(cols, np.float32)[ci]
    a = fade * (1.0 - max(0.0, k - 0.5) / 0.5)
    if ol is not None:
        olm = (m > 0) & (wv > 1.2) & (((d >= wv) & (d < wv + 1.0)) | ((d < 0) & (d >= -1.0))) & ~band
        L.paint(y0, x0, olm, ol, a)
    L.paint(y0, x0, band, C, a)


def np_cloud(L, puffs, cols, ol, a=1.0, cut=0.0):
    """Tek dış çizgili puf bulutu: puffs = [(x, y, r)] (TGT'ye göre dünya). Işık sol-üstte; cut 0..1 sol-üstten oyarak
    hilallere çevirir (oyunun dağılan kütleleri gibi)."""
    pp = [(fpx((x, y)), r / WPP) for (x, y, r) in sorted(puffs, key=lambda q: q[1]) if r > 0.2]
    if not pp:
        return
    x0 = max(0, int(min(c[0] - R for c, R in pp)) - 2)
    x1 = min(FXW, int(max(c[0] + R for c, R in pp)) + 3)
    y0 = max(0, int(min(c[1] - R for c, R in pp)) - 2)
    y1 = min(FXH, int(max(c[1] + R for c, R in pp)) + 3)
    if x0 >= x1 or y0 >= y1:
        return
    X = _XX[y0:y1, x0:x1] + 0.5
    Y = _YY[y0:y1, x0:x1] + 0.5
    idx = np.full(X.shape, -1, np.int32)
    for i, ((cx, cy), R) in enumerate(pp):
        ins = np.hypot(X - cx, Y - cy) <= R
        if cut > 0.0:
            ins &= np.hypot(X - (cx - 0.45 * R), Y - (cy - 0.55 * R)) > R * cut * 1.3
        idx[ins] = i
    mask = idx >= 0
    if not mask.any():
        return
    ## gölgelendirme bulutun BÜTÜNÜNE göre (puf başına değil, yoksa her puf ayrı yumurta gibi okunur): sol-üst kenar açık,
    ## sağ-alt kenar koyu, içi orta ton
    def outside(dx, dy):
        sh = np.zeros_like(mask)
        h, w = mask.shape
        ys, yd = (slice(dy, h), slice(0, h - dy)) if dy >= 0 else (slice(0, h + dy), slice(-dy, h))
        xs, xd = (slice(dx, w), slice(0, w - dx)) if dx >= 0 else (slice(0, w + dx), slice(-dx, w))
        sh[ys, xs] = mask[yd, xd]
        return ~sh

    ci = np.full(mask.shape, 1, np.int32)
    ci[outside(2, 2)] = 0  # (x-2, y-2) dışarıda -> sol-üst kenar
    ci[outside(-2, -2)] = 2
    ci[outside(-1, -1)] = 3
    C = np.array(cols, np.float32)[np.minimum(ci, len(cols) - 1)]
    if ol is not None:
        dil = mask.copy()
        dil[1:] |= mask[:-1]
        dil[:-1] |= mask[1:]
        dil[:, 1:] |= mask[:, :-1]
        dil[:, :-1] |= mask[:, 1:]
        L.paint(y0, x0, dil & ~mask, ol, a)
    L.paint(y0, x0, mask, C, a)


def np_trail(L, pts, w0, cols, ol=None, fade=1.0):
    """Hareket izi: pts = başın son konumları (TGT'ye göre dünya, en yeni önce). Başta w0 sanat px kalın, kuyruğa sivrilir,
    ortası açık ton, kuyruk koyulaşıp kırıntılanır."""
    if len(pts) < 2:
        return
    Pp = [fpx(p) for p in pts]
    pad = w0 + 3
    x0 = max(0, int(min(p[0] for p in Pp) - pad))
    x1 = min(FXW, int(max(p[0] for p in Pp) + pad) + 1)
    y0 = max(0, int(min(p[1] for p in Pp) - pad))
    y1 = min(FXH, int(max(p[1] for p in Pp) + pad) + 1)
    if x0 >= x1 or y0 >= y1:
        return
    X = _XX[y0:y1, x0:x1] + 0.5
    Y = _YY[y0:y1, x0:x1] + 0.5
    best = np.full(X.shape, 1e9, np.float32)
    bd = np.full(X.shape, 1e9, np.float32)
    bhw = np.zeros(X.shape, np.float32)
    bs = np.zeros(X.shape, np.float32)
    n = len(Pp)
    for j in range(n - 1):
        ax, ay = Pp[j]
        bx, by = Pp[j + 1]
        dx, dy = bx - ax, by - ay
        ln2 = max(dx * dx + dy * dy, 1e-6)
        u = np.clip(((X - ax) * dx + (Y - ay) * dy) / ln2, 0.0, 1.0)
        d = np.hypot(X - (ax + u * dx), Y - (ay + u * dy))
        s = (j + u) / (n - 1)
        hw = 0.5 * w0 * (1.0 - s) ** 0.8 + 0.3
        r = d / hw
        upd = r < best
        best = np.where(upd, r, best)
        bd = np.where(upd, d, bd)
        bhw = np.where(upd, hw, bhw)
        bs = np.where(upd, s, bs)
    inside = best <= 1.0
    ci = np.where(best < 0.45, 0, np.where(best < 0.8, 1, 2)) + (bs > 0.55)
    C = np.array(cols, np.float32)[np.minimum(ci, len(cols) - 1)]
    a = fade * (1.0 - np.clip((bs - 0.55) / 0.45, 0.0, 1.0) * 0.85)
    if ol is not None:
        olm = (~inside) & (bd <= bhw + 1.0) & (bhw > 1.0) & (bs < 0.7)
        L.paint(y0, x0, olm, ol, a)
    L.paint(y0, x0, inside, C, a)


def np_crater(L, c, rx, ry, cols, fade):
    """Yer çukuru: içi koyu toprak, üst kenarı açık dudak."""
    cx, cy = fpx(c)
    Rx, Ry = rx / WPP, ry / WPP
    b = _box(cx, cy, Rx, Ry, 2)
    if not b:
        return
    x0, x1, y0, y1 = b
    X = (_XX[y0:y1, x0:x1] + 0.5 - cx) / Rx
    Y = (_YY[y0:y1, x0:x1] + 0.5 - cy) / Ry
    rho = np.hypot(X, Y)
    ins = rho <= 1.0
    ci = np.where((Y < -0.35) & (rho > 0.62), 0, np.where(rho < 0.62, 2, 1))
    L.paint(y0, x0, ins, np.array(cols, np.float32)[ci], fade)


def np_glow(L, c, rx, ry, cols, fade):
    """Yer parıltısı: Bayer ile merkezden dışa seyrelen dolu elips."""
    cx, cy = fpx(c)
    Rx, Ry = rx / WPP, ry / WPP
    b = _box(cx, cy, Rx, Ry, 1)
    if not b:
        return
    x0, x1, y0, y1 = b
    rho = np.hypot((_XX[y0:y1, x0:x1] + 0.5 - cx) / Rx, (_YY[y0:y1, x0:x1] + 0.5 - cy) / Ry)
    ins = rho < 1.0
    ci = np.where(rho < 0.35, 0, np.where(rho < 0.7, 1, 2))
    L.paint(y0, x0, ins, np.array(cols, np.float32)[np.minimum(ci, len(cols) - 1)], fade * np.clip(1.0 - rho, 0.0, 1.0) ** 0.6)


def make_cracks(seed, n, lmin, lmax):
    rng = random.Random(seed)
    out = []
    for i in range(n):
        th = 2 * math.pi * i / n + rng.uniform(-0.3, 0.3)
        ln = rng.uniform(lmin, lmax)
        pts = [(0.0, 0.0)]
        for s in range(1, 6):
            a = th + rng.uniform(-0.32, 0.32)
            r = ln * s / 5.0
            pts.append((math.cos(a) * r, 0.5 * math.sin(a) * r))
        out.append(pts)
    return out


def draw_cracks(L, c, cracks, h, fade, col, lip):
    """Yer çatlakları: ilk %45 iki piksel kalın + üstte açık dudak, sonra tek piksel; h 0..1 uzunluk."""
    for pts in cracks:
        segs = list(zip(pts[:-1], pts[1:]))
        tot = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in segs)
        run = 0.0
        for a, b in segs:
            ln = math.hypot(b[0] - a[0], b[1] - a[1])
            n = max(1, int(ln / WPP * 2))
            for i in range(n + 1):
                u = i / float(n)
                f = (run + ln * u) / tot
                if f > h:
                    break
                x, y = fpx((c[0] + a[0] + (b[0] - a[0]) * u, c[1] + a[1] + (b[1] - a[1]) * u))
                x, y = int(x), int(y)
                if f < 0.45:
                    L.put(x, y - 1, lip, fade)
                    L.put(x, y + 1, col, fade)
                L.put(x, y, col, fade)
            run += ln


def make_chunks(seed, n, v, vz, sizes):
    rng = random.Random(seed)
    return [(rng.uniform(0, 2 * math.pi), rng.uniform(*v), rng.uniform(*vz), rng.choice(sizes), rng.randrange(3)) for _ in range(n)]


def draw_chunks(L, origin, chunks, age, cols, ol, g=420.0, rest=0.14):
    """Taş kırıntıları: yerde (cos, 0,5 sin) yönünde kayar, z'de sıçrar, düşünce kısa süre durup söner."""
    if age < 0.0:
        return
    for (th, v, vz, sz, ci) in chunks:
        T = 2.0 * vz / g
        tau = min(age, T)
        gx = origin[0] + math.cos(th) * v * tau
        gy = origin[1] + 0.5 * math.sin(th) * v * tau
        z = vz * tau - 0.5 * g * tau * tau if age < T else 0.0
        fade = 1.0 if age < T else 1.0 - (age - T) / rest
        if fade <= 0.0:
            continue
        x, y = (int(q) for q in fpx((gx, gy - z)))
        for dy in range(-1, sz + 1):
            for dx in range(-1, sz + 1):
                inner = 0 <= dx < sz and 0 <= dy < sz
                if inner:
                    L.put(x + dx, y + dy, cols[0] if (dx == 0 and dy == 0 and sz > 1) else cols[1 + ci % 2], fade)
                elif (dx in (-1, sz)) != (dy in (-1, sz)):  # köşesiz dış çizgi
                    L.put(x + dx, y + dy, ol, fade)


def make_embers(seed, n, spread, v, vz, life):
    rng = random.Random(seed)
    out = []
    for _ in range(n):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.2, 1.0)
        out.append((math.cos(a) * spread[0] * r, math.sin(a) * spread[1] * r, math.cos(a) * rng.uniform(*v),
                    0.5 * math.sin(a) * rng.uniform(*v), rng.uniform(*vz), rng.uniform(*life)))
    return out


def draw_embers(L, origin, embers, age, cols, g=70.0):
    """Yükselen korlar: yavaşlayarak yükselir, rengi soğur, Bayer ile söner."""
    if age < 0.0:
        return
    n = len(cols)
    for (ox, oy, vx, vy, vz, life) in embers:
        if age >= life:
            continue
        k = age / life
        z = vz * age - 0.5 * g * age * age
        x, y = (int(q) for q in fpx((origin[0] + ox + vx * age, origin[1] + oy + vy * age - z)))
        col = cols[min(n - 1, int(k * n))]
        a = 1.0 - max(0.0, k - 0.4) / 0.6
        L.put(x, y, col, a)
        if k < 0.35:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                L.put(x + dx, y + dy, cols[min(n - 1, 1 + int(k * n))], a)


def make_sparks(seed, n, a0, a1, v, life):
    rng = random.Random(seed)
    return [(rng.uniform(a0, a1) * D2R, rng.uniform(*v), rng.uniform(*life)) for _ in range(n)]


def draw_sparks(L, origin, sparks, age, cols, g=260.0):
    """Ekran düzleminde fırlayan kıvılcım: kısa çizgi (hız yönünde 2-3 px), sonra tek nokta."""
    if age < 0.0:
        return
    n = len(cols)
    for (th, v, life) in sparks:
        if age >= life:
            continue
        k = age / life
        vx, vy = math.cos(th) * v, math.sin(th) * v + g * age
        x = origin[0] + math.cos(th) * v * age
        y = origin[1] + math.sin(th) * v * age + 0.5 * g * age * age
        sp = math.hypot(vx, vy) or 1.0
        col = cols[min(n - 1, int(k * n))]
        ln = 3 if k < 0.5 else 1
        for i in range(ln):
            px, py = fpx((x - vx / sp * i * WPP, y - vy / sp * i * WPP))
            L.put(int(px), int(py), col if i == 0 else cols[min(n - 1, int(k * n) + 1)], 1.0 - k * k)


def smear_pts(tr, t, t0, t1, win, n=9):
    """[t0, t1] boyunca başın son `win` saniyelik yolu (en yeni önce); hareket bitince kuyruk 0,06 sn'de başa yetişir."""
    if t < t0:
        return []
    te = min(t, t1)
    tb = max(t0, te - win)
    if t > t1:
        tb = max(tb, te - win * (1.0 - (t - t1) / 0.06))
    if te - tb < 0.004:
        return []
    return [off(tr.head(te - (te - tb) * i / (n - 1))) for i in range(n)]


# ------------------------------------------------------------------ renkler
DUST = cl("#f6eedc #e0d2b2 #bca782 #8e7a58")
DUST_OL = hx("#54452f")
DIRT = cl("#9a8462 #6e5a40 #4a3c2a")
CRACK = hx("#2e2418")
CRACK_LIP = hx("#a89470")
STONE = cl("#a89a84 #7a6c58 #5a4e40")
STONE_OL = hx("#3a3024")
STEEL = cl("#eef2f6 #b8c0ca #8a94a2 #646e7e")
STEEL_OL = hx("#323a46")
CREAM = cl("#ffffff #fff2c4 #fbd27a #ee9c42 #c4602a")
CREAM_L = cl("#fffbee #f4e6c0 #dcc690")
WINDC = cl("#fffdf6 #f2ead6 #d8ccae #aa9e82")
WIND_OL = hx("#8a7f66")
AMBER = cl("#fff6c8 #fdd85a #f9ab2c #e0741e #a8401a")
AMBER_OL = hx("#5e2410")
GLOW = cl("#fff2b0 #fbc84e #ec8a2a")
EMBER = cl("#fff6c8 #fdd85a #f9ab2c #e0741e #a8401a")
SMOKE = cl("#f2eee6 #cdc7bc #a19b91 #77726a")
SMOKE_OL = hx("#403c38")


# ---- A Yer Sarsıntısı
A_CRACKS = make_cracks(11, 7, 11.0, 21.0)
A_CHUNKS = make_chunks(5, 10, (22.0, 58.0), (55.0, 110.0), (2, 2, 3))
A_PUFFS = [(-8.0, 1.0, 4.2), (8.0, 1.0, 4.2), (-3.5, -2.5, 5.0), (3.5, -2.5, 5.0), (0.0, 2.0, 5.2), (-12.5, 2.5, 3.0), (12.5, 2.5, 3.0)]


def A_fx(Ls, t):
    age = t - A_HIT
    if age < 0.0:
        return
    hd = off(A_HEAD)
    fade = 1.0 - clamp01((age - 0.30) / 0.30)
    if fade > 0.0:
        np_crater(Ls["g"], G_OFF, 8.0 * min(1.0, 0.6 + age / 0.05), 4.0 * min(1.0, 0.6 + age / 0.05), DIRT, fade)
        draw_cracks(Ls["g"], G_OFF, A_CRACKS, clamp01(age / 0.05), fade, CRACK, CRACK_LIP)
    np_ring(Ls["g"], G_OFF, 6.0, 3.0, AOE, AOE / 2.0, 11.0, DUST, age / 0.38, nbreak=5, phase=0.5, ol=DUST_OL, brk=0.5)
    if age < 0.12:
        BP.star(Ls["f"], hd, 10.0, CREAM, age / 0.12)
    k = clamp01(age / 0.30)
    if k < 1.0:
        e = math.sin(k * math.pi / 2)
        np_cloud(Ls["f"], [(G_OFF[0] + x * (1.0 + 0.5 * e), G_OFF[1] + y - 5.0 * e, r * (0.7 + 0.5 * e)) for x, y, r in A_PUFFS],
                 DUST, DUST_OL, 1.0, clamp01((age - 0.08) / 0.22))
    draw_chunks(Ls["f"], G_OFF, A_CHUNKS, age, STONE, STONE_OL)


def A_live(L, tr, t):
    np_trail(L, smear_pts(tr, t, 0.21, A_HIT, 0.035), 15.0, STEEL, STEEL_OL)


# ---- B Demir Savuruş
B_SPARKS = make_sparks(9, 7, 20.0, 100.0, (70.0, 150.0), (0.16, 0.30))
B_LINES = [-75, -40, -10, 20, 50, 85, 120]


def B_fx(Ls, t):
    age = t - B_HIT
    if age < 0.0:
        return
    hd = W((B_C[0] + B_RH, B_C[1]))
    if age < 0.12:
        BP.star(Ls["f"], hd, 12.0, CREAM, age / 0.12)
    if age < 0.10:  # darbe çizgileri: temastan dışa fırlayan kısa kalın çizgiler
        e = math.sin(clamp01(age / 0.10) * math.pi / 2)
        for i, a in enumerate(B_LINES):
            aw = (a * D2R) + DIR_ANG
            r0, r1 = 6.0 + 9.0 * e, 10.0 + (9.0 if i % 2 else 13.0) * e
            p0 = (hd[0] + math.cos(aw) * r0, hd[1] + math.sin(aw) * r0)
            p1 = (hd[0] + math.cos(aw) * r1, hd[1] + math.sin(aw) * r1)
            BP.line_band(Ls["f"], p0, p1, 3.0, CREAM_L, 1.0, 0.0, clamp01((age - 0.03) / 0.07))
    sw = [_rot((math.cos(a), math.sin(a)), DIR_ANG) for a, _, _ in B_SPARKS]
    draw_sparks(Ls["f"], hd, [(math.atan2(v[1], v[0]), s, lf) for v, (_, s, lf) in zip(sw, B_SPARKS)], age, EMBER)
    k = clamp01(age / 0.24)
    if k < 1.0:  # yerde küçük toz (savuruş yönünde)
        e = math.sin(k * math.pi / 2)
        f = W((4.0 + 6.0 * e, 0.0))
        np_cloud(Ls["g"], [(G_OFF[0] + f[0] + dx, G_OFF[1] + f[1] + dy - 2.0 * e, r * (0.5 + 0.6 * e))
                           for dx, dy, r in ((-4.0, 0.5, 2.6), (3.0, -0.5, 3.0), (0.0, 1.5, 2.2))],
                 DUST, DUST_OL, 1.0, clamp01((age - 0.06) / 0.18))


def B_live(L, tr, t):
    """Çelik iz hilali: savuruş başlangıcından başa kadar; savuruş bitince kuyruktan yenir."""
    a = B_head_deg(min(t, 0.34))
    if a is None or t >= 0.52:
        return
    a0 = -135.0 if t >= 0.18 else a + 1.0
    if t < 0.18 or abs(a - a0) < 2.0:
        return
    c = W(B_C)
    if t < 0.34:
        tail, thin = 0.0, 0.0
    else:
        k = (t - 0.34) / 0.18
        tail, thin = min(1.0, 0.9 * k ** 0.9), k ** 1.15
    BP.arc_band(L, c, B_RH + 2.0, B_RH + 2.0, (a0 * D2R) + DIR_ANG, (a * D2R) + DIR_ANG, 6.0, STEEL, 1.0, tail, thin,
                ol=STEEL_OL, peak=1.8)


# ---- C Fırıldak Çekiç
C_EMBERS = make_embers(21, 14, (11.0, 5.5), (6.0, 26.0), (40.0, 95.0), (0.30, 0.55))


def C_fx(Ls, t):
    age = t - C_HIT
    if age < 0.0:
        return
    hd = off(C_HEAD)
    if age < 0.16:
        np_glow(Ls["g"], G_OFF, 16.0, 8.0, GLOW, 1.0 - age / 0.16)
    np_ring(Ls["g"], G_OFF, 4.0, 2.0, 58.0, 29.0, 5.0, AMBER, age / 0.30, nbreak=6, phase=1.3, ol=AMBER_OL)
    np_ring(Ls["g"], G_OFF, 3.0, 1.5, 36.0, 18.0, 3.0, CREAM, (age - 0.06) / 0.24, nbreak=5, phase=0.2)
    if age < 0.12:
        BP.star(Ls["f"], hd, 11.0, CREAM, age / 0.12)
    draw_embers(Ls["f"], G_OFF, C_EMBERS, age, EMBER)


def C_live(L, tr, t):
    np_trail(L, smear_pts(tr, t, 0.14, C_HIT, 0.07, 12), 8.0, WINDC, WIND_OL)


# ---- D Toz ve Kor
D_PUFFS = [(math.cos(a * D2R) * 9.0, math.sin(a * D2R) * 4.5, 1.0) for a in range(0, 360, 60)] + [(0.0, 0.0, 1.2)]
D_EMBERS = make_embers(33, 6, (6.0, 3.0), (20.0, 40.0), (30.0, 60.0), (0.25, 0.40))


def D_fx(Ls, t):
    age = t - D_HIT
    if age < 0.0:
        return
    hd = off(D_HEAD)
    if age < 1.0 / FXFPS:  # bugünkü ilk kare: beyaz nokta
        np_glow(Ls["f"], hd, 3.0, 3.0, cl("#ffffff #fff6dc #fff2c4"), 1.0)
    np_ring(Ls["g"], G_OFF, 3.0, 1.9, 30.0, 18.6, 3.5, AMBER, age / 0.30, nbreak=5, phase=0.9, ol=AMBER_OL, brk=0.6)
    k = clamp01(age / 0.40)
    if k < 1.0:
        e = math.sin(k * math.pi / 2)
        np_cloud(Ls["f"], [(G_OFF[0] + x * (0.6 + 0.6 * e), G_OFF[1] + y * (0.6 + 0.6 * e) - 5.0 * e, r * (2.0 + 3.6 * e))
                           for x, y, r in D_PUFFS], SMOKE, SMOKE_OL, 1.0, clamp01((age - 0.10) / 0.30))
    draw_embers(Ls["f"], G_OFF, D_EMBERS, age, EMBER, g=50.0)


def D_live(L, tr, t):
    np_trail(L, smear_pts(tr, t, 0.11, D_HIT, 0.028), 11.0, STEEL, STEEL_OL)


# ------------------------------------------------------------------ yön tablosu
DIRS = {
    "cur": dict(title="ŞU AN (oyundaki)", sub="hedefin 24 px yanına park eder, turuncu halka + duman; hasar atış anında",
                track=CUR_track, hit=0.0, align=0.12),
    "A": dict(title="A - Yer Sarsıntısı", sub="kaldır + indir: çatlak, toz dalgası alan sınırına (95 px) kadar, taş kırıntısı",
              track=A_track, fx=A_fx, live=A_live, hit=A_HIT),
    "B": dict(title="B - Demir Savuruş", sub="geniş çapraz savuruş, çelik iz hilali, çatırtı yıldızı + kıvılcım; yönle döner",
              track=B_track, fx=B_fx, live=B_live, hit=B_HIT),
    "C": dict(title="C - Fırıldak Çekiç", sub="havada 1,5 tur dönüp baş aşağı düşer: kehribar şok halkaları + korlar",
              track=C_track, fx=C_fx, live=C_live, hit=C_HIT),
    "D": dict(title="D - Toz ve Kor", sub="bugünkü halka + duman fikri piksel sanatıyla: kısa çakma, gri bulut, kor",
              track=D_track, fx=D_fx, live=D_live, hit=D_HIT),
}
ORDER = ["cur", "A", "B", "C", "D"]

_CUR_FR = []


def cur_frames():
    if not _CUR_FR:
        for i in range(1, CUR_FX_N + 1):
            _CUR_FR.append(np.asarray(asset("assets/weapons/topuz/hit/frame%d.png" % i), dtype=np.float32))
    return _CUR_FR


# ------------------------------------------------------------------ şerit
_BG = {}


def lane_bg(idx):
    if idx not in _BG:
        g = grass(int(LWW * ZOOM), int(LHW * ZOOM), 41 + idx)
        F = np.asarray(g.convert("RGB"), dtype=np.float32).copy()
        ch = asset("assets/characters/sovalye/sheets/idle.png", (0, 96, 48, 144))
        cx, cy = S(CHAR)
        blit(F, ch, cx, cy, CHAR_K * ZOOM)
        _BG[idx] = F
    return _BG[idx].copy()


def slime():
    return asset("visuals/Yaratıklar/Tüm Yaratıklar/Slime 1/PNG/Slime1/With_shadow/Slime1_Walk_with_shadow.png", (0, 0, 64, 64))


def icon():
    return asset("assets/weapons/zanaat/topuz_L3.png")


class Lane:
    def __init__(self, did, idx, t_first=0.15):
        self.did, self.idx, self.D = did, idx, DIRS[did]
        self.tr = self.D["track"]()
        self.t_first = t_first
        self.cache = {}

    def attack_time(self, t):
        if t < self.t_first:
            return 99.0
        n = int((t - self.t_first) // INTERVAL)
        return t - self.t_first - n * INTERVAL

    def layers(self, ta):
        q = int(ta * FXFPS)
        if q not in self.cache:
            Ls = {"g": Lay(), "b": Lay(), "f": Lay()}
            if "fx" in self.D:
                self.D["fx"](Ls, q / float(FXFPS))
            self.cache[q] = {k: v.cropped() for k, v in Ls.items()}
        return self.cache[q]

    def render(self, t):
        F = lane_bg(self.idx)
        ta = self.attack_time(t)
        lay = self.layers(ta)
        tx, ty = S(TGT)
        k_fx = WPP * ZOOM

        def put_layer(c):
            if c is not None:
                blit(F, c[0], tx, ty, k_fx, 0.0, c[1])

        put_layer(lay["g"])
        ## enemy.gd: HIT_FLASH_DURATION 0,12 sn; alan hasarı alanlar da aynı anda parlar
        fl = ta - self.D["hit"]
        flash = 1.0 - fl / 0.12 if 0.0 <= fl < 0.12 else 0.0
        for p in sorted([TGT] + EXTRA, key=lambda q: q[1]):
            sx, sy = S(p)
            blit(F, slime(), sx, sy - 2, SLIME_K * ZOOM)
            if flash > 0.0:
                blit(F, slime(), sx, sy - 2, SLIME_K * ZOOM, alpha=flash, tint=(255, 255, 255))
        put_layer(lay["b"])
        if "live" in self.D:
            L = Lay()
            self.D["live"](L, self.tr, ta)
            put_layer(L.cropped())
        x, y, a, sl, sw = self.tr.pose(ta)
        blit_mace(F, icon(), S((x, y)), a, WPP * ZOOM, self.tr.piv, sl, sw)
        if self.did == "cur":
            fi = int(ta * CUR_FX_FPS)
            if 0 <= fi < CUR_FX_N:
                fx, fy = S(CUR_FX_POS)
                blit(F, cur_frames()[fi], fx, fy, CUR_FX_K * ZOOM)
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


def grid(tiles, cols, gap=4):
    w, h = tiles[0].size
    rows = (len(tiles) + cols - 1) // cols
    g = Image.new("RGB", (cols * w + (cols - 1) * gap, rows * h + (rows - 1) * gap), (18, 20, 20))
    for i, tl in enumerate(tiles):
        g.paste(tl, ((i % cols) * (w + gap), (i // cols) * (h + gap)))
    return g


# ------------------------------------------------------------------ çıktılar
INFO = [
    "aralık %.2f sn  ·  tek ağır darbe, alan hasarı %d px (yarı hasar)" % (INTERVAL, AOE),
    "beyaz parlama = isabet (hedef + alandaki iki yaratık)",
    "ŞU AN: hasar atış anında; topuz hedefin 24 px yanına park",
    "eder, halka en geniş ~31 px (alanın üçte biri)",
    "yeni yönler: isabet = temas anı, topuz sapından döner",
    "halkalar yerde 2:1 elips; koddaki alan daire",
    "Zanaatkâr L3 topuz  ·  efekt 30 fps (sprite sayfası gibi)",
]


def build_game():
    lanes = [Lane(d, i) for i, d in enumerate(ORDER)]
    loop = 2.0 * INTERVAL
    n = int(round(loop * FPS))
    dt = loop / n
    lw, lh = int(LWW * ZOOM), int(LHW * ZOOM)
    info = info_tile(lw, lh, INFO, "Topuz vuruşu")
    hd = header(lw * 2 + 4, "Topuz vuruşu  ·  oyun ölçeği (1080p), gerçek hız", "Şovalye + Zanaatkâr L3 topuz  ·  2 vuruş döngüsü")
    frames = []
    for st in range(n):
        t = st * dt
        tiles = []
        for ln in lanes:
            im = ln.render(t)
            lane_label(im, ln.did)
            tiles.append(im)
        tiles.append(info)
        frames.append(stack_v([hd, grid(tiles, 2)]))
    save_gif(frames, os.path.join(OUT, "topuz_oyun.gif"), 1.0 / dt, [int(0.44 * FPS), int(0.50 * FPS), int(0.56 * FPS)])
    frames[int((0.15 + 0.45) * FPS)].save(os.path.join(OUT, "topuz_oyun_kare.png"))


CROP = (int((TGT[0] - 56) * ZOOM), int((TGT[1] - 52) * ZOOM), int((TGT[0] + 56) * ZOOM), int((TGT[1] + 56) * ZOOM))


def build_slow(speed=0.25, z=2):
    lanes = [Lane(d, i, t_first=0.05) for i, d in enumerate(ORDER)]
    fps = 40
    real_len = 1.0
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
            "temas: A %.2f · B %.2f · C %.2f · D %.2f sn" % (A_HIT, B_HIT, C_HIT, D_HIT),
            "ŞU AN: hasar 0,00 sn, topuz 0,12 sn'de varır",
            "beyaz parlama = isabet",
        ], "YAVAŞ ÇEKİM x%.2f" % speed))
        frames.append(grid(tiles, 3))
    save_gif(frames, os.path.join(OUT, "topuz_yavas.gif"), fps, [int(0.30 / dt), int(0.33 / dt), int(0.40 / dt)])


OFFS = [-0.12, -0.06, -0.03, 0.0, 0.034, 0.067, 0.10, 0.16, 0.24, 0.34]
SCROP = (int((TGT[0] - 60) * ZOOM), int((TGT[1] - 50) * ZOOM), int((TGT[0] + 60) * ZOOM), int((TGT[1] + 58) * ZOOM))


def build_strip(z=1):
    rows = []
    cw, ch = (SCROP[2] - SCROP[0]) * z, (SCROP[3] - SCROP[1]) * z
    LBL = 150
    for i, did in enumerate(ORDER):
        ln = Lane(did, i, t_first=0.0)
        t0 = DIRS[did].get("align", DIRS[did]["hit"])
        row = Image.new("RGB", (LBL + len(OFFS) * (cw + 2), ch + 18), (24, 26, 26))
        d = ImageDraw.Draw(row)
        for j, o in enumerate(OFFS):
            tt = max(0.0, t0 + o)
            im = ln.render(tt).crop(SCROP).resize((cw, ch), Image.NEAREST)
            row.paste(im, (LBL + j * (cw + 2), 18))
            label(d, LBL + j * (cw + 2) + 4, 2, "%.2f sn%s" % (tt, "  temas" if o == 0.0 else ""), 10, (220, 214, 198))
        label(d, 6, 22, DIRS[did]["title"], 12)
        rows.append(row)
    im = stack_v(rows, 6)
    path = os.path.join(OUT, "topuz_kareler.png")
    im.save(path)
    print("kareler", path, im.size)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    gi = os.path.join(HERE, "out", ".gdignore")
    if not os.path.exists(gi):
        open(gi, "w").close()
    args = sys.argv[1:] or ["oyun", "yavas", "kareler"]
    for w in args:
        {"oyun": build_game, "yavas": build_slow, "kareler": build_strip}[w]()
