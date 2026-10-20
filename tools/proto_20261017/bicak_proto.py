# -*- coding: utf-8 -*-
"""BIÇAK vuruş animasyonu + efekti PROTOTİPLERİ (2026-10-17, oyuna bağlı DEĞİL). Kullanıcı: "bıçağın vuruş animasyonu ve efekti
için yeni prototip hazırla".

Bugün (teşhis; weapon.gd _do_melee_swing + Characters.MAIN_WEAPON + fx_assasin_slash.tscn):
  - Silah düğümü top_level (dünya ölçeği 1): ikon dinlenme yerinden hedefin 8 dünya px önüne uçar (0,12 sn), saldırı yönüne dik
    ±24 dünya px "Z" zikzağı (0,09 + 0,09 sn), efekt bitene kadar bekler (0,42 sn), 0,26 sn'de döner. Bıçak hareket yönüne bakar.
  - Efekt: 128 px YUMUŞAK boyalı kırmızı X (piksel değil), 24 fps 10 kare, ölçek 1,2375 x sahip 0,5 = 0,62 dünya px/piksel (~79 px kare),
    konumu son zikzak noktası (hedefin 24 px yanı), saldırı yönüyle döner.
  - Hasar 3 parça, ATIŞ ANINDA (0 / 0,1 / 0,2 sn): ilk sayı ikon hedefe varmadan (0,12 sn) çıkar. Prototiplerde isabet = temas anı
    (oyuna alınırken kılıçtaki gibi bir temas gecikmesi gerekir, bkz. SwordSwingMath.contact_delay).

Dört yön (hepsi 1 sanat pikseli = 0,575 dünya px = Zanaatkâr silahlarıyla aynı yoğunluk; uçlar sivrilir, kırıntılanarak söner):
  A Çelik Hilal       - üç hızlı kavisli kesik (üstten, alttan, yatay); her kesik bıçağın ucunu izleyen çelik-beyaz hilal
  B Kıvılcım Saplama  - geri çek + üç saplama (son saplama derin); hız çizgileri + krem-kehribar yıldız patlaması + kırıntı
  C Rüzgâr Fırıldağı  - bıçak hedefin çevresinde 2:1 elips tam tur atar (arkadan geçerken yaratığın arkasında); krem rüzgâr halkası,
                        tur kapanınca dışa açılan halka (alan hasarı hissi); efekt dönmez (Topuz gibi sabit açı)
  D Kızıl Çarpı       - bugünkü X fikri piksel sanatıyla: iki çapraz kesik (\\ sonra /) X olunca bir kare krem parlar, sonra ortaya
                        kısa saplama + kızıl yıldız

Çıktılar (out/bicak/): bicak_oyun.gif (1080p oyun ölçeği, gerçek hız, 2 vuruş; ŞU AN + A-D), bicak_yavas.gif (x0,25 hız, x2 yakın),
bicak_kareler.png (kare şeridi x2), bicak_oyun_kare.png.
Çalıştırma: python tools/proto_20261017/bicak_proto.py [oyun|yavas|kareler]   (argümansız: hepsi)
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mermi_proto as MP  # noqa: E402  (çimen, varlık yükleme, Bayer, parçacıklar, yazı)
from mermi_proto import E, cl, hx, on, PS, spawn, draw_pts, step_pts, asset, label, grass, SPARK  # noqa: E402

OUT = os.path.join(HERE, "out", "bicak")
ZOOM = 2.0
WPP = 0.575  # silah + efekt sanat pikseli (dünya px) = weapon_tier_art.gd WORLD_PX
CHAR_K = 2.2368375 * 0.8075 * 0.5  # Assasin dünya px / karakter pikseli
SLIME_K = 0.94905
FPS = 50
INTERVAL = 1.1111 / 0.7  # weapon_dagger.tscn fire_rate / GameManager.WEAPON_ATTACK_SPEED_MULT
FXFPS = 30  # yeni efektler sprite sayfası gibi 30 fps'e kuantalanır
CUR_FX_K = 1.2375 * 0.5  # fx_assasin_slash ölçeği x sahip ölçeği
REST_ANG = -math.pi / 4  # zanaat ikonunda bıçak -45 derece (sprite_forward_angle_deg)

# şerit (dünya px)
LWW, LHW = 236, 92
CHAR = (34.0, 52.0)
REST = (CHAR[0] + 22.0, CHAR[1] - 34.0)
TGT = (CHAR[0] + 100.0, CHAR[1] + 6.0)
_d = (TGT[0] - REST[0], TGT[1] - REST[1])
DIR_ANG = math.atan2(_d[1], _d[0])
DIRV = (math.cos(DIR_ANG), math.sin(DIR_ANG))
SC = (TGT[0] - DIRV[0] * 8.0, TGT[1] - DIRV[1] * 8.0)  # strike center: hedefin 8 px önü

FXW, FXH = 150, 110  # efekt tuvali (sanat px), merkez = çerçeve orijini


def S(p):
    return (p[0] * ZOOM, p[1] * ZOOM)


# ------------------------------------------------------------------ numpy blit (NEAREST, yumuşak alfa destekli)
_NP = {}


def _np(im):
    k = id(im)
    if k not in _NP:
        _NP[k] = (im, np.asarray(im.convert("RGBA"), dtype=np.float32))
    return _NP[k][1]


def blit(F, src, cx, cy, k, rot=0.0, pivot=None, alpha=1.0, tint=None):
    """F: (H, W, 3) float kare; (cx, cy) pivotun ekran konumu; k = ekran px / sanat pikseli; Godot NEAREST döndürme taklidi."""
    Sa = src if isinstance(src, np.ndarray) else _np(src)
    sh, sw = Sa.shape[:2]
    px, py = pivot if pivot else (sw / 2.0, sh / 2.0)
    c, s = math.cos(rot), math.sin(rot)
    rad = int(math.hypot(max(px, sw - px), max(py, sh - py)) * k) + 2
    H, W = F.shape[:2]
    x0, x1 = max(0, int(cx) - rad), min(W, int(cx) + rad)
    y0, y1 = max(0, int(cy) - rad), min(H, int(cy) + rad)
    if x0 >= x1 or y0 >= y1:
        return
    X, Y = np.meshgrid(np.arange(x0, x1) + 0.5 - cx, np.arange(y0, y1) + 0.5 - cy)
    u = np.floor((c * X + s * Y) / k + px).astype(np.int32)
    v = np.floor((-s * X + c * Y) / k + py).astype(np.int32)
    m = (u >= 0) & (u < sw) & (v >= 0) & (v < sh)
    if not m.any():
        return
    samp = np.zeros((y1 - y0, x1 - x0, 4), np.float32)
    samp[m] = Sa[v[m], u[m]]
    a = samp[..., 3:4] / 255.0 * alpha
    col = samp[..., :3] if tint is None else np.array(tint, np.float32)
    F[y0:y1, x0:x1] = F[y0:y1, x0:x1] * (1.0 - a) + col * a


# ------------------------------------------------------------------ hareket
def ease(kind, x):
    x = min(1.0, max(0.0, x))
    if kind == "out":
        return math.sin(x * math.pi / 2)
    if kind == "in":
        return x * x
    if kind == "inout":
        return 0.5 - 0.5 * math.cos(math.pi * x)
    if kind == "back":  # ileri fırlayıp hafif geri oturur
        s = 1.6
        x -= 1.0
        return x * x * ((s + 1) * x + s) + 1.0
    return x


def lerp_ang(a, b, t):
    d = (b - a + math.pi) % (2 * math.pi) - math.pi
    return a + d * t


class Seg:
    def __init__(self, t0, t1, kind, ez="out", p1=None, c=None, rx=0.0, ry=0.0, a0=0.0, a1=0.0, aim=None, tween=False):
        self.t0, self.t1, self.kind, self.ez = t0, t1, kind, ez
        self.p1, self.c, self.rx, self.ry, self.a0, self.a1 = p1, c, rx, ry, a0, a1
        self.aim, self.tween = aim, tween
        self.p0 = None  # çizgide önceki parçanın bitişi (dünya)


class Motion:
    """Bıçak ikonunun yolu. Çerçeve: rotating=True -> orijin SC, +x saldırı yönü (efekt de yönle döner); False -> orijin hedef,
    eksenler dünya (efekt sabit açı)."""

    def __init__(self, segs, rotating=True, pulses=()):
        self.segs, self.rot, self.pulses = segs, rotating, list(pulses)
        prev = REST
        for sg in segs:
            if sg.kind in ("line", "ret"):
                sg.p0 = prev
            if sg.kind != "hold":
                prev = self.seg_pos(sg, 1.0)

    def W(self, p):
        if self.rot:
            c, s = DIRV
            return (SC[0] + c * p[0] - s * p[1], SC[1] + s * p[0] + c * p[1])
        return (TGT[0] + p[0], TGT[1] + p[1])

    def fang(self, a):
        return a + (DIR_ANG if self.rot else 0.0)

    def seg_pos(self, sg, e):
        if sg.kind == "line":
            q = self.W(sg.p1)
            return (sg.p0[0] + (q[0] - sg.p0[0]) * e, sg.p0[1] + (q[1] - sg.p0[1]) * e)
        if sg.kind == "ret":
            return (sg.p0[0] + (REST[0] - sg.p0[0]) * e, sg.p0[1] + (REST[1] - sg.p0[1]) * e)
        if sg.kind == "arc":
            a = sg.a0 + (sg.a1 - sg.a0) * e
            return self.W((sg.c[0] + sg.rx * math.cos(a), sg.c[1] + sg.ry * math.sin(a)))
        return None  # hold

    def at(self, t):
        for i, sg in enumerate(self.segs):
            if sg.t0 <= t < sg.t1:
                return i, sg, (t - sg.t0) / (sg.t1 - sg.t0)
        return -1, None, 0.0

    def pos(self, t):
        i, sg, u = self.at(t)
        if sg is None:
            return REST
        if sg.kind == "hold":
            return self.pos(sg.t0 - 1e-6) if i > 0 else REST
        return self.seg_pos(sg, ease(sg.ez, u))

    def move_ang(self, sg, e):
        if sg.aim == "T":
            p = self.seg_pos(sg, e)
            tg = self.W((8.0, 0.0)) if self.rot else TGT
            return math.atan2(tg[1] - p[1], tg[0] - p[0])
        if isinstance(sg.aim, float):
            return self.fang(sg.aim)
        a = self.seg_pos(sg, max(0.0, e - 0.02))
        b = self.seg_pos(sg, min(1.0, e + 0.02))
        return math.atan2(b[1] - a[1], b[0] - a[0])

    def ang(self, t):
        i, sg, u = self.at(t)
        if sg is None:
            return REST_ANG
        prev = self.ang(sg.t0 - 1e-6) if i > 0 else REST_ANG
        e = ease(sg.ez, u)
        if sg.kind == "hold":
            return prev
        if sg.kind == "ret":
            return lerp_ang(prev, REST_ANG, e)
        if sg.tween:
            return lerp_ang(prev, self.move_ang(sg, 1.0), ease("out", u))
        return self.move_ang(sg, e)

    def scale(self, t):
        k = 1.0
        for (tp, amp, dur) in self.pulses:
            if tp - dur * 0.3 <= t < tp + dur:
                x = (t - tp + dur * 0.3) / (dur * 1.3)
                k += amp * math.sin(math.pi * x)
        return k


# ------------------------------------------------------------------ efekt çizimi (sanat pikseli tuvali)
class FxL:
    def __init__(self):
        self.im = Image.new("RGBA", (FXW, FXH), (0, 0, 0, 0))
        self.p = self.im.load()

    def put(self, x, y, col, a=1.0):
        if 0 <= x < FXW and 0 <= y < FXH and on(x, y, a):
            self.p[x, y] = (col[0], col[1], col[2], 255)


def fx_px(p):
    return (FXW / 2.0 + p[0] / WPP, FXH / 2.0 + p[1] / WPP)


def arc_band(L, c, rx, ry, a0, a1, w, cols, head=1.0, tail=0.0, thin=0.0, ol=None, flash=False, peak=1.6, fade=1.0):
    """Elips yay şeridi (dış kenar elipste, içe doğru w sanat px). a0 -> a1 yönünde u = 0..1; tail..head arası görünür; kalınlık
    sin(pi*s^peak) (iki uç sivri, tepe başa yakın). thin 0..1 inceltir + kuyruktan kırıntılanır."""
    if head <= tail + 1e-3 or thin >= 1.0:
        return
    cx, cy = fx_px(c)
    Rx, Ry = rx / WPP, ry / WPP
    span = abs(a1 - a0)
    sg = 1.0 if a1 >= a0 else -1.0
    n = len(cols)
    for y in range(int(cy - Ry - 2), int(cy + Ry + 3)):
        for x in range(int(cx - Rx - 2), int(cx + Rx + 3)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            t = math.atan2(dy / Ry, dx / Rx)
            dl = ((t - a0) * sg) % (2 * math.pi)
            if dl > span + 1e-6:
                continue
            u = dl / span if span > 0 else 0.0
            if u < tail or u > head:
                continue
            s = (u - tail) / (head - tail)
            wv = w * (math.sin(math.pi * min(1.0, s ** peak)) ** 0.6) * (1.0 - thin)
            rho = math.hypot(dx / Rx, dy / Ry)
            rt = math.hypot(Rx * math.cos(t), Ry * math.sin(t))
            d = (1.0 - rho) * rt
            a = fade * min(1.0, s * 4.0) * (1.0 - max(0.0, thin - 0.35) / 0.65)
            if 0.0 <= d < wv:
                f = d / max(wv, 1e-3)
                ci = 0 if (flash or f < 0.34) else (1 if f < 0.67 else 2)
                if s < 0.3 and not flash:
                    ci = min(n - 1, ci + 1)
                L.put(x, y, cols[min(n - 1, ci)], a)
            elif ol is not None and wv >= 1.2 and (wv <= d < wv + 1.0 or -1.0 <= d < 0.0):
                L.put(x, y, ol, a)


def line_band(L, p0, p1, w, cols, head=1.0, tail=0.0, thin=0.0, ol=None, flash=False, bulge=0.0, peak=1.3, fade=1.0):
    """Düz (bulge ile hafif kavisli) kesik: p0 -> p1, ortası kalın uçlar sivri, merkezi en açık ton."""
    if head <= tail + 1e-3 or thin >= 1.0:
        return
    ax, ay = fx_px(p0)
    bx, by = fx_px(p1)
    Dx, Dy = bx - ax, by - ay
    ln2 = Dx * Dx + Dy * Dy
    ln = math.sqrt(ln2)
    nx, ny = -Dy / ln, Dx / ln
    bl = bulge / WPP
    n = len(cols)
    pad = w + abs(bl) + 3
    for y in range(int(min(ay, by) - pad), int(max(ay, by) + pad) + 1):
        for x in range(int(min(ax, bx) - pad), int(max(ax, bx) + pad) + 1):
            qx, qy = x + 0.5 - ax, y + 0.5 - ay
            u = (qx * Dx + qy * Dy) / ln2
            if u < tail or u > head:
                continue
            d = qx * nx + qy * ny - bl * math.sin(math.pi * u)
            s = (u - tail) / (head - tail)
            hw = w * 0.5 * (math.sin(math.pi * min(1.0, s ** peak)) ** 0.6) * (1.0 - thin)
            a = fade * min(1.0, s * 4.0) * (1.0 - max(0.0, thin - 0.35) / 0.65)
            ad = abs(d)
            if ad <= hw:
                f = ad / max(hw, 1e-3)
                ci = 0 if (flash or f < 0.4) else (1 if f < 0.75 else 2)
                if s < 0.25 and not flash:
                    ci = min(n - 1, ci + 1)
                L.put(x, y, cols[min(n - 1, ci)], a)
            elif ol is not None and hw >= 0.9 and ad <= hw + 1.0:
                L.put(x, y, ol, a)


def star(L, p, r, cols, k):
    """4 kollu parlama: kollar sivri (merkezde 3 px), çaprazlar kısa; k = yaş 0..1 -> kollar kısalır, renk koyulaşır."""
    cx, cy = (int(round(v)) for v in fx_px(p))
    n = len(cols)
    ln = r * (1.0 - 0.75 * k)
    dg = r * 0.45 * (1.0 - k)
    sh = min(n - 1, int(k * 2.5))
    a = 1.0 - max(0.0, k - 0.55) / 0.45
    for i in range(int(ln) + 1):
        f = i / max(ln, 1.0)
        col = cols[min(n - 1, sh + int(f * (n - 1 - sh) + 0.4))]
        js = (0,) if f > 0.45 else ((-1, 0, 1) if f <= 0.15 and k < 0.5 else (0, 1))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            for j in js:
                L.put(cx + dx * i + dy * j, cy + dy * i + dx * j, col, a)
    for i in range(1, int(dg) + 1):
        col = cols[min(n - 1, sh + 1 + i // 2)]
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            L.put(cx + dx * i, cy + dy * i, col, a)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if abs(dx) + abs(dy) <= (1 if k > 0.4 else 2):
                L.put(cx + dx, cy + dy, cols[sh], a)


def ring_burst(L, c, rx0, ry0, rx1, ry1, w, cols, k, nbreak=5, phase=0.0, ol=None, half=None):
    """Dışa açılan elips halka; k büyüdükçe incelir ve nbreak hilale kırılır. half: 'back' (üst yarı) / 'front' (alt yarı) / None."""
    if k >= 1.0:
        return
    e = math.sin(k * math.pi / 2)
    rx, ry = rx0 + (rx1 - rx0) * e, ry0 + (ry1 - ry0) * e
    cx, cy = fx_px(c)
    Rx, Ry = rx / WPP, ry / WPP
    n = len(cols)
    for y in range(int(cy - Ry - 2), int(cy + Ry + 3)):
        if half == "back" and y + 0.5 >= cy:
            continue
        if half == "front" and y + 0.5 < cy:
            continue
        for x in range(int(cx - Rx - 2), int(cx + Rx + 3)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            t = math.atan2(dy / Ry, dx / Rx)
            m = 0.6 + 0.4 * math.sin(nbreak * t + phase) - k * 0.75
            if m <= 0.0:
                continue
            wv = w * m * (1.0 - k * 0.6)
            rho = math.hypot(dx / Rx, dy / Ry)
            rt = math.hypot(Rx * math.cos(t), Ry * math.sin(t))
            d = (1.0 - rho) * rt
            a = 1.0 - max(0.0, k - 0.5) / 0.5
            if 0.0 <= d < wv:
                f = d / max(wv, 1e-3)
                ci = min(n - 1, (0 if f < 0.4 else 1) + int(k * 2.2))
                L.put(x, y, cols[ci], a)
            elif ol is not None and wv > 1.2 and wv <= d < wv + 1.0:
                L.put(x, y, ol, a)


# ------------------------------------------------------------------ renkler
STEEL = cl("#ffffff #dde7ee #a9bccb #7a8ea1")
STEEL_OL = hx("#46546a")
CREAM = cl("#ffffff #fff2c4 #fbd27a #ee9c42 #c4602a")
CREAM_L = cl("#fffbee #f4e6c0 #dcc690")
WINDC = cl("#fffdf6 #f2ead6 #d8ccae #aa9e82")
WIND_OL = hx("#8a7f66")
KIZIL = cl("#fff2dc #ffa66a #e8503a #ac2630")
KIZIL_OL = hx("#561424")
KIZIL_ST = cl("#ffffff #fff0c8 #ffa66a #e8503a #ac2630")

D2R = math.pi / 180.0


def fade_phase(age, form, life):
    """age < form: oluşuyor (head 0->1); sonra life boyunca söner. Dönüş: (head, tail, thin)."""
    if age < form:
        h = ease("inout", age / form)
        return min(1.0, h + 0.08), max(0.0, h - 0.9), 0.0
    k = min(1.0, (age - form) / life)
    return 1.0, min(1.0, 0.9 * k ** 0.9), k ** 1.15


# ---- A Çelik Hilal
A_C = (8.0, 0.0)
A_R, A_RF = 16.0, 19.0
A_F3C, A_F3R = (8.0, 30.0), 34.0


def A_motion():
    c, R = A_C, A_R

    def on_c(a):
        return (c[0] + R * math.cos(a * D2R), c[1] + R * math.sin(a * D2R))

    def on_3(a):
        return (A_F3C[0] + A_F3R * math.cos(a * D2R), A_F3C[1] + A_F3R * math.sin(a * D2R))

    return Motion([
        Seg(0.00, 0.09, "line", "out", p1=on_c(-160), tween=True),
        Seg(0.09, 0.16, "arc", "inout", c=c, rx=R, ry=R, a0=-160 * D2R, a1=-20 * D2R),
        Seg(0.16, 0.18, "line", "inout", p1=on_c(20)),
        Seg(0.18, 0.25, "arc", "inout", c=c, rx=R, ry=R, a0=20 * D2R, a1=160 * D2R),
        Seg(0.25, 0.27, "line", "inout", p1=on_3(-125)),
        Seg(0.27, 0.33, "arc", "inout", c=A_F3C, rx=A_F3R, ry=A_F3R, a0=-125 * D2R, a1=-55 * D2R),
        Seg(0.33, 0.41, "hold"),
        Seg(0.41, 0.65, "ret", "inout"),
    ])


def A_fx(L, t):
    for t0, dur, c, r, a0, a1, w in ((0.09, 0.07, A_C, A_RF, -160, -20, 4.0), (0.18, 0.07, A_C, A_RF, 20, 160, 4.0),
                                     (0.27, 0.06, A_F3C, A_F3R + 3.0, -125, -55, 5.0)):
        age = t - t0
        if 0.0 <= age < dur + 0.16:
            h, tl, th = fade_phase(age, dur, 0.16)
            arc_band(L, c, r, r, a0 * D2R, a1 * D2R, w, STEEL, h, tl, th, ol=STEEL_OL)


# ---- B Kıvılcım Saplama
B_STABS = [  # (geri çekiliş -> saplama), temas, yıldız yarıçapı
    ((-14.0, -3.0), (-1.0, -2.5), 0.09, 0.13, 7.0),
    ((-15.0, -0.5), (-1.0, 2.5), 0.19, 0.23, 7.0),
    ((-18.0, 0.0), (2.0, 0.0), 0.29, 0.33, 11.0),
]


def B_motion():
    return Motion([
        Seg(0.00, 0.09, "line", "out", p1=(-14.0, -3.0), aim="T", tween=True),
        Seg(0.09, 0.13, "line", "in", p1=(-1.0, -2.5), aim="T"),
        Seg(0.13, 0.15, "hold"),
        Seg(0.15, 0.19, "line", "out", p1=(-15.0, -0.5), aim="T"),
        Seg(0.19, 0.23, "line", "in", p1=(-1.0, 2.5), aim="T"),
        Seg(0.23, 0.25, "hold"),
        Seg(0.25, 0.29, "line", "out", p1=(-18.0, 0.0), aim="T"),
        Seg(0.29, 0.33, "line", "in", p1=(2.0, 0.0), aim="T"),
        Seg(0.33, 0.43, "hold"),
        Seg(0.43, 0.67, "ret", "inout"),
    ], pulses=[(0.33, 0.18, 0.10)])


def _tip(p, q, k=9.0):
    dx, dy = A_C[0] - p[0], A_C[1] - p[1]
    ln = math.hypot(dx, dy) or 1.0
    return (q[0] + dx / ln * k, q[1] + dy / ln * k)


B_SIDE_LINES = True  # 2026-10-19 (madde 299): oyundaki sayfa yan çizgisiz (kullanıcı: "pençe gibi 3 çizik değil 1 çizik") - gen_dagger_stab_fx.py False yapar


def B_fx(L, t):
    for i, (back, inn, t0, tc, r) in enumerate(B_STABS):
        tip0, tip1 = _tip(back, back), _tip(back, inn)
        age = t - t0
        big = i == 2
        if 0.0 <= age < 0.14:  # hız çizgileri: saplama yolunun arkasında, uçla birlikte ilerler
            h, tl, th = fade_phase(age, tc - t0, 0.08)
            dx, dy = tip1[0] - tip0[0], tip1[1] - tip0[1]
            ln = math.hypot(dx, dy) or 1.0
            nx, ny = -dy / ln, dx / ln
            b0 = (tip0[0] - dx / ln * 6.0, tip0[1] - dy / ln * 6.0)
            lines = ((0.0, 2.6 if big else 2.0, CREAM_L), (2.6, 1.3, CREAM_L[1:]), (-2.6, 1.3, CREAM_L[1:]))
            for off, w, cc in (lines if B_SIDE_LINES else lines[:1]):
                o = (nx * off, ny * off)
                line_band(L, (b0[0] + o[0], b0[1] + o[1]), (tip1[0] - dx / ln * 3.0 + o[0], tip1[1] - dy / ln * 3.0 + o[1]),
                          w, cc, h, tl, th)
        age = t - tc
        if 0.0 <= age < (0.16 if big else 0.12):
            k = age / (0.16 if big else 0.12)
            star(L, (tip1[0] - 3.0, tip1[1]), r, CREAM, k)
            if big:
                ring_burst(L, (tip1[0] - 2.0, tip1[1]), 3.0, 3.0, 14.0, 14.0, 3.0, CREAM[1:], k, nbreak=6, phase=0.4)


# ---- C Rüzgâr Fırıldağı (sabit çerçeve: orijin hedef)
C_RX, C_RY = 20.0, 10.0


def C_motion():
    return Motion([
        Seg(0.00, 0.10, "line", "out", p1=(-C_RX, 0.0), tween=True),
        Seg(0.10, 0.34, "arc", "lin", c=(0.0, 0.0), rx=C_RX, ry=C_RY, a0=math.pi, a1=3 * math.pi),
        Seg(0.34, 0.40, "arc", "out", c=(0.0, 0.0), rx=C_RX, ry=C_RY, a0=3 * math.pi, a1=3 * math.pi + 0.7),
        Seg(0.40, 0.64, "ret", "inout"),
    ], rotating=False)


def C_head(t):
    if t < 0.10:
        return None
    if t < 0.34:
        return math.pi + 2 * math.pi * (t - 0.10) / 0.24
    return 3 * math.pi + 0.7 * ease("out", (t - 0.34) / 0.06)


def C_fx(L, t, half):
    if 0.10 <= t < 0.56:
        h = C_head(min(t, 0.40)) + 0.25
        if t < 0.34:
            ln = min(4.4, h - math.pi)
            th = 0.0
        else:
            k = min(1.0, (t - 0.34) / 0.22)
            ln = 4.4 * (1.0 - k)
            th = k ** 1.1
        if ln > 0.05:
            _arc_half(L, (0.0, 0.0), C_RX + 2.0, C_RY + 1.0, h - ln, h, 4.0, WINDC, th, WIND_OL, half)
    if 0.34 <= t < 0.58:
        ring_burst(L, (0.0, 0.0), C_RX + 2.0, C_RY + 1.0, 36.0, 18.0, 4.0, WINDC, (t - 0.34) / 0.24, nbreak=5, phase=1.1,
                   ol=WIND_OL, half=half)


def _arc_half(L, c, rx, ry, a0, a1, w, cols, thin, ol, half):
    tmp = FxL()
    arc_band(tmp, c, rx, ry, a0, a1, w, cols, 1.0, 0.0, thin, ol=ol, peak=2.2)
    cy = FXH / 2.0
    src = tmp.p
    for y in range(FXH):
        if (half == "back" and y + 0.5 >= cy) or (half == "front" and y + 0.5 < cy):
            continue
        for x in range(FXW):
            p = src[x, y]
            if p[3]:
                L.p[x, y] = p


# ---- D Kızıl Çarpı
D_C = (8.0, 0.0)


def D_motion():
    c = D_C
    return Motion([
        Seg(0.00, 0.09, "line", "out", p1=(c[0] - 12, c[1] - 12), tween=True),
        Seg(0.09, 0.15, "line", "inout", p1=(c[0] + 12, c[1] + 12)),
        Seg(0.15, 0.19, "line", "inout", p1=(c[0] + 12, c[1] - 12), tween=True),
        Seg(0.19, 0.25, "line", "inout", p1=(c[0] - 12, c[1] + 12)),
        Seg(0.25, 0.28, "line", "out", p1=(c[0] - 13, c[1]), aim="T", tween=True),
        Seg(0.28, 0.31, "line", "in", p1=(c[0] - 3, c[1]), aim="T"),
        Seg(0.31, 0.40, "hold"),
        Seg(0.40, 0.64, "ret", "inout"),
    ], pulses=[(0.31, 0.15, 0.08)])


def D_fx(L, t):
    c = D_C
    flash = 0.25 <= t < 0.25 + 1.0 / FXFPS
    for t0, p0, p1 in ((0.09, (c[0] - 16, c[1] - 16), (c[0] + 16, c[1] + 16)), (0.19, (c[0] + 16, c[1] - 16), (c[0] - 16, c[1] + 16))):
        age = t - t0
        if age < 0.0:
            continue
        if age < 0.06:
            h = min(1.0, ease("inout", age / 0.06) + 0.08)
            line_band(L, p0, p1, 4.0, KIZIL, h, max(0.0, h - 0.95), 0.0, ol=KIZIL_OL, bulge=1.2)
        elif t < 0.25 + 1.0 / FXFPS:
            line_band(L, p0, p1, 4.0, KIZIL, 1.0, 0.0, 0.0, ol=KIZIL_OL, flash=flash, bulge=1.2)
        else:
            k = min(1.0, (t - 0.25 - 1.0 / FXFPS) / 0.2)
            if k < 1.0:
                line_band(L, p0, p1, 4.0, KIZIL, 1.0, 0.9 * k ** 0.9, k ** 1.15, ol=KIZIL_OL, bulge=1.2)
    age = t - 0.31
    if 0.0 <= age < 0.14:
        star(L, (c[0] - 2.0, c[1]), 7.0, KIZIL_ST, age / 0.14)


# ------------------------------------------------------------------ yön tablosu
DIRS = {
    "A": dict(title="A - Çelik Hilal", sub="üç kavisli kesik (üst, alt, yatay), uç izinde çelik-beyaz hilal", motion=A_motion, fx=A_fx,
              hits=[0.125, 0.215, 0.30], spark=PS("plus", cl("#ffffff #dde7ee #a9bccb"), n=3, life=(0.08, 0.16), v=(40, 90))),
    "B": dict(title="B - Kıvılcım Saplama", sub="geri çek + üç saplama (sonuncusu derin), hız çizgisi + yıldız + kırıntı",
              motion=B_motion, fx=B_fx, hits=[0.13, 0.23, 0.33],
              spark=PS("dot", cl("#fff2c4 #fbd27a #ee9c42"), n=4, life=(0.12, 0.25), v=(40, 100), aim="fwd", spread=1.8)),
    "C": dict(title="C - Rüzgâr Fırıldağı", sub="hedefin çevresinde tam tur (arkadan geçerken arkada), kapanınca dışa açılan halka",
              motion=C_motion, fx=C_fx, hits=[0.18, 0.26, 0.34], split=True,
              spark=PS("dot", WINDC, n=3, life=(0.15, 0.3), v=(30, 70))),
    "D": dict(title="D - Kızıl Çarpı", sub="bugünkü X fikri piksel sanatıyla: iki kesik, X olunca parlar, ortaya saplama",
              motion=D_motion, fx=D_fx, hits=[0.12, 0.22, 0.31],
              spark=PS("plus", SPARK, n=3, life=(0.08, 0.16), v=(40, 90))),
}
ORDER = ["cur", "A", "B", "C", "D"]


# ---- ŞU AN (oyundaki): zikzak + boyalı X atlas
def CUR_motion():
    return Motion([
        Seg(0.00, 0.12, "line", "out", p1=(0.0, 24.0), tween=True),
        Seg(0.12, 0.21, "line", "out", p1=(0.0, -24.0), tween=True),
        Seg(0.21, 0.30, "line", "out", p1=(0.0, 24.0), tween=True),
        Seg(0.30, 0.30 + 10.0 / 24.0, "hold"),
        Seg(0.30 + 10.0 / 24.0, 0.56 + 10.0 / 24.0, "ret", "inout"),
    ])


_ATLAS = []


def cur_atlas():
    if not _ATLAS:
        im = asset("assets/weapons/assasin/slash_atlas.png")
        for i in range(10):
            fr = im.crop(((i % 5) * 128, (i // 5) * 128, (i % 5) * 128 + 128, (i // 5) * 128 + 128))
            _ATLAS.append(np.asarray(fr, dtype=np.float32))
    return _ATLAS


# ------------------------------------------------------------------ şerit
_BG = {}


def lane_bg(idx):
    if idx not in _BG:
        g = grass(int(LWW * ZOOM), int(LHW * ZOOM), 31 + idx)
        F = np.asarray(g.convert("RGB"), dtype=np.float32).copy()
        ch = asset("assets/characters/assasin/sheets/idle.png", (0, 96, 48, 144))
        cx, cy = S(CHAR)
        blit(F, ch, cx, cy, CHAR_K * ZOOM)
        _BG[idx] = F
    return _BG[idx].copy()


SLIME = None


def slime():
    global SLIME
    if SLIME is None:
        SLIME = asset("visuals/Yaratıklar/Tüm Yaratıklar/Slime 1/PNG/Slime1/With_shadow/Slime1_Walk_with_shadow.png", (0, 0, 64, 64))
    return SLIME


ICON = None


def icon():
    global ICON
    if ICON is None:
        ICON = asset("assets/weapons/zanaat/dagger_L3.png")
    return ICON


class Lane:
    def __init__(self, did, idx, t_first=0.15):
        self.did, self.idx = did, idx
        self.cur = did == "cur"
        self.mo = CUR_motion() if self.cur else DIRS[did]["motion"]()
        self.hits = [0.0, 0.1, 0.2] if self.cur else DIRS[did]["hits"]
        self.spark = None if self.cur else DIRS[did]["spark"]
        self.t_first = t_first
        self.rng = random.Random(77 + idx)
        self.pts = []
        self.fired = set()
        self.cache = {}

    def attack_time(self, t):
        """(saldırı başından beri geçen süre, saldırı no) - en son başlamış saldırı."""
        if t < self.t_first:
            return None, -1
        n = int((t - self.t_first) // INTERVAL)
        return t - self.t_first - n * INTERVAL, n

    def step(self, t, dt):
        ta, n = self.attack_time(t)
        if ta is not None:
            for j, th in enumerate(self.hits):
                if ta >= th and (n, j) not in self.fired:
                    self.fired.add((n, j))
                    if self.spark:
                        hp = self.hit_point(th)
                        spawn(self.spark, hp[0], hp[1], DIRV[0], DIRV[1], self.rng, self.pts)
        self.pts = step_pts(self.pts, dt)

    def hit_point(self, th):
        p = self.mo.pos(th)
        a = self.mo.ang(th)
        q = (p[0] + math.cos(a) * 7.0, p[1] + math.sin(a) * 7.0)
        if self.did == "C":
            q = (TGT[0] + (p[0] - TGT[0]) * 0.6, TGT[1] + (p[1] - TGT[1]) * 0.6)
        return S(q)

    def fx_canvas(self, ta, half=None):
        q = int(ta * FXFPS)
        key = (q, half)
        if key not in self.cache:
            L = FxL()
            tq = q / float(FXFPS)
            if self.did == "C":
                C_fx(L, tq, half)
            else:
                DIRS[self.did]["fx"](L, tq)
            self.cache[key] = np.asarray(L.im, dtype=np.float32)
        return self.cache[key]

    def render(self, t):
        F = lane_bg(self.idx)
        ta, _ = self.attack_time(t)
        if ta is None:
            ta = 99.0
        p = self.mo.pos(ta)
        a = self.mo.ang(ta)
        sc = self.mo.scale(ta)
        ix, iy = S(p)
        k_icon = WPP * ZOOM * sc
        behind = self.did == "C" and 0.10 <= ta < 0.40 and p[1] < TGT[1] - 0.5
        ## enemy.gd: HIT_FLASH_DURATION 0,12 sn doğrusal söner, HIT_FLASH_MIN_INTERVAL 0,4 -> 3 parçadan sadece ilki parlar
        fl = ta - self.hits[0]
        flash = 1.0 - fl / 0.12 if 0.0 <= fl < 0.12 else 0.0
        rot_fx = 0.0 if self.did == "C" else DIR_ANG
        fxc = S(SC) if self.mo.rot else S(TGT)
        piv = (FXW / 2.0, FXH / 2.0)
        if self.did == "C":
            blit(F, self.fx_canvas(ta, "back"), fxc[0], fxc[1], WPP * ZOOM, 0.0, piv)
        if behind:
            blit(F, icon(), ix, iy, k_icon, a - REST_ANG)
        tx, ty = S(TGT)
        blit(F, slime(), tx, ty - 2, SLIME_K * ZOOM)
        if flash > 0.0:
            blit(F, slime(), tx, ty - 2, SLIME_K * ZOOM, alpha=flash, tint=(255, 255, 255))
        if not behind:
            blit(F, icon(), ix, iy, k_icon, a - REST_ANG)
        if self.cur:
            age = ta
            fi = int(age * 24.0)
            if 0 <= fi < 10:
                c, s = DIRV
                fp = (SC[0] - s * 24.0, SC[1] + c * 24.0)
                blit(F, cur_atlas()[fi], fp[0] * ZOOM, fp[1] * ZOOM, CUR_FX_K * ZOOM, DIR_ANG)
        elif self.did == "C":
            blit(F, self.fx_canvas(ta, "front"), fxc[0], fxc[1], WPP * ZOOM, 0.0, piv)
        else:
            blit(F, self.fx_canvas(ta), fxc[0], fxc[1], WPP * ZOOM, rot_fx, piv)
        im = Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")
        draw_pts(im, self.pts)
        return im


TITLES = {"cur": ("ŞU AN (oyundaki)", "zikzak + yumuşak boyalı X; hasar atış anında (ikon varmadan)")}
for _k, _v in DIRS.items():
    TITLES[_k] = (_v["title"], _v["sub"])


def lane_label(im, did, small=False):
    d = ImageDraw.Draw(im)
    t, s = TITLES[did]
    label(d, 6, 3, t, 12)
    if not small:
        label(d, 6, im.height - 16, s, 10, (226, 220, 204))


def header(w, title, sub):
    im = Image.new("RGB", (w, 36), (30, 34, 32))
    d = ImageDraw.Draw(im)
    label(d, 8, 3, title, 14)
    label(d, 8, 20, sub, 10, (200, 196, 182))
    return im


def stack_v(parts, gap=4):
    W = max(p.width for p in parts)
    H = sum(p.height for p in parts) + gap * (len(parts) - 1)
    im = Image.new("RGB", (W, H), (18, 20, 20))
    y = 0
    for p in parts:
        im.paste(p, (0, y))
        y += p.height + gap
    return im


def save_gif(frames, path, fps, sample_idx):
    sample = stack_v([frames[i] for i in sample_idx], 0)
    pal = sample.quantize(255, method=Image.Quantize.MEDIANCUT)
    q = [fr.quantize(palette=pal, dither=Image.Dither.NONE) for fr in frames]
    q[0].save(path, save_all=True, append_images=q[1:], duration=int(round(1000.0 / fps)), loop=0, disposal=1)
    print("gif", path, len(q))


# ------------------------------------------------------------------ çıktılar
def build_game():
    lanes = [Lane(d, i) for i, d in enumerate(ORDER)]
    loop = 2.0 * INTERVAL
    n = int(round(loop * FPS))
    dt = loop / n
    hd = header(int(LWW * ZOOM), "Bıçak vuruşu  ·  oyun ölçeği (1080p), gerçek hız",
                "L3 bıçak  ·  aralık %.2f sn  ·  kıvılcım = temas (hasar), beyaz = ilk isabet" % INTERVAL)
    frames = []
    for st in range(n):
        t = st * dt
        parts = [hd]
        for ln in lanes:
            ln.step(t, dt)
            im = ln.render(t)
            lane_label(im, ln.did)
            parts.append(im)
        frames.append(stack_v(parts))
    save_gif(frames, os.path.join(OUT, "bicak_oyun.gif"), 1.0 / dt, [int(0.40 * FPS), int(0.30 * FPS), int(0.22 * FPS)])
    frames[int((0.15 + 0.24) * FPS)].save(os.path.join(OUT, "bicak_oyun_kare.png"))


CROP = (int((REST[0] - 8) * ZOOM), int((REST[1] - 8) * ZOOM), int((SC[0] + 40) * ZOOM), int((SC[1] + 32) * ZOOM))
STRIP_CROP = (int((SC[0] - 38) * ZOOM), int((SC[1] - 30) * ZOOM), int((SC[0] + 40) * ZOOM), int((SC[1] + 30) * ZOOM))


def build_slow(speed=0.25, z=2):
    lanes = [Lane(d, i, t_first=0.05) for i, d in enumerate(ORDER)]
    fps = 40
    real_len = 1.05
    n = int(round(real_len / speed * fps))
    dt = real_len / n
    cw, ch = (CROP[2] - CROP[0]) * z, (CROP[3] - CROP[1]) * z
    frames = []
    for st in range(n):
        t = st * dt
        tiles = []
        for ln in lanes:
            ln.step(t, dt)
            im = ln.render(t).crop(CROP).resize((cw, ch), Image.NEAREST)
            lane_label(im, ln.did, small=True)
            tiles.append(im)
        info = Image.new("RGB", (cw, ch), (30, 34, 32))
        d = ImageDraw.Draw(info)
        label(d, 12, 12, "YAVAŞ ÇEKİM x%.2f" % speed, 16)
        label(d, 12, 40, "yakınlaştırma x%d (1 dünya px = %d ekran px)" % (z, int(ZOOM * z)), 11, (220, 214, 198))
        label(d, 12, 60, "süre: %.2f sn (gerçek)" % max(0.0, t - 0.05), 11, (220, 214, 198))
        label(d, 12, 86, "kıvılcım = temas, beyaz = ilk isabet", 11, (220, 214, 198))
        label(d, 12, 104, "ŞU AN: hasar atışla aynı anda,", 11, (220, 214, 198))
        label(d, 12, 120, "bıçak hedefe 0,12 sn sonra varır", 11, (220, 214, 198))
        tiles.append(info)
        g = Image.new("RGB", (cw * 3 + 8, ch * 2 + 4), (18, 20, 20))
        for i, tl in enumerate(tiles):
            g.paste(tl, ((i % 3) * (cw + 4), (i // 3) * (ch + 4)))
        frames.append(g)
    save_gif(frames, os.path.join(OUT, "bicak_yavas.gif"), fps, [int(0.15 / dt), int(0.25 / dt), int(0.35 / dt)])


def build_strip(z=2):
    times = [0.09, 0.12, 0.15, 0.18, 0.21, 0.24, 0.27, 0.30, 0.34, 0.40, 0.48]
    rows = []
    cw, ch = (STRIP_CROP[2] - STRIP_CROP[0]) * z, (STRIP_CROP[3] - STRIP_CROP[1]) * z
    LBL = 150
    for i, did in enumerate(ORDER):
        ln = Lane(did, i, t_first=0.0)
        row = Image.new("RGB", (LBL + len(times) * (cw + 2), ch + 18), (24, 26, 26))
        d = ImageDraw.Draw(row)
        t, dt = 0.0, 1.0 / 200.0
        for j, tt in enumerate(times):
            while t < tt:
                ln.step(t, dt)
                t += dt
            im = ln.render(tt).crop(STRIP_CROP).resize((cw, ch), Image.NEAREST)
            row.paste(im, (LBL + j * (cw + 2), 18))
            label(d, LBL + j * (cw + 2) + 4, 2, "%.2f sn" % tt, 10, (220, 214, 198))
        label(d, 6, 22, TITLES[did][0], 12)
        rows.append(row)
    im = stack_v(rows, 6)
    path = os.path.join(OUT, "bicak_kareler.png")
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
