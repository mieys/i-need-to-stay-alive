# -*- coding: utf-8 -*-
"""KALKAN VURUŞ ANİMASYONU prototipleri v2 (2026-10-20, oyuna bağlı DEĞİL). Kullanıcı (kalkan oyunda, madde 338): "vuruş animasyonunu
beğenmedim çok sıradan duruyor". Efekt aynı kalır (seçilen D "Hayalet Kalkan" silüeti temasta), HAREKET değişir.
  ŞU AN       - oyundaki darbe (scripts/kalkan_bash_math.gd STEPS = kalkan_proto.shield_pose): öne çık, kurul, çarp, kısa duraklama
  A Hücum     - geriye yaslanıp kurulur, öne eğilerek fırlar (arkasında hız çizgileri), sert çarpma + uzun duraklama, geri seker ve
                sallanarak durulur; hayalet daha büyük
  B Çakılma   - havaya kalkar (yerdeki gölgesi küçülür), sivri ucuyla hedefin önüne yere çakılır: yerde iki hayalet halka + çatlak,
                hayalet silüet yerden yükselir, kalkan saplı titrer, çekilip döner; vurulanlar çakılma noktasından dışa itilir
  C Fırıldak  - kendi dikey ekseninde dönerek (8 yön görünüşü art arda = 3B dönüş) kavisli yoldan hedefe uçar, yüzü hedefe dönük
                durup çarpar, geri seker, dönerek eve gelir; uçarken etrafında iki kısa krem yay
  D Süpürme   - hedefin yanına geçip karakterin önünden yay çizerek süpürür (yüzü hep dışa): yoldaki düşmanlar SIRAYLA vurulur
                (geçtiği an), sonda ağır duraklama + hayalet
Sahne kalkan_proto.py ile aynı (Talon + Şövalye L3; 1. darbe SAĞA, 2. AŞAĞI; hedef + 2 yandaki vurulur, uzaktaki vurulmaz, 45 px itme).
Çıktılar (out/kalkan/): kalkan_vurus.gif (oyun ölçeği, gerçek hız), kalkan_vurus_yavas.gif (sağa darbe x0,25), kalkan_vurus_kareler.png.
Çalıştırma: python tools/proto_20261020/kalkan_vurus_proto.py [kareler|oyun|yavas]
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kalkan_proto as KP  # noqa: E402  (sahne, tuval, çizim yardımcıları)
import kalkan_yon as KY  # noqa: E402
from kalkan_proto import BP, TP, S, unit, lerp, ez, clamp01, blit, blit_xy, label, header, stack_v, save_gif  # noqa: E402

OUT = KP.OUT
ZOOM, WPP = KP.ZOOM, KP.WPP
FPS = 50
INTERVAL, LOOP, T_FIRST = KP.INTERVAL, KP.LOOP, KP.T_FIRST
LV = 3
PUSH = KP.PUSH
GHOST_TINT = (255, 236, 168)
CREAM_W = KP.CREAM_W

_FLIP = {}


def sector_of(d):
    a = math.degrees(math.atan2(d[0], d[1])) % 360.0
    return int(round(a / 45.0)) % 8


def sector_img(sector, lv=LV):
    s = sector % 8
    idx = s if s <= 4 else 8 - s
    img = KP.IMGS[(lv, KY.ANGLES[idx])]
    if s > 4:
        if (lv, idx) not in _FLIP:
            _FLIP[(lv, idx)] = img.transpose(Image.FLIP_LEFT_RIGHT)
        img = _FLIP[(lv, idx)]
    return img


def axis_scale(sp, sq, d):
    ax, ay = abs(d[0]), abs(d[1])
    n = max(1e-4, ax + ay)
    ax, ay = ax / n, ay / n
    return ax * sp + ay * sq, ax * sq + ay * sp


def blit_rs(F, src, cx, cy, k, sx=1.0, sy=1.0, rot=0.0, alpha=1.0, tint=None):
    """Ölçek (sx, sy) sonra döndürme (derece, saat yönü) - Godot NEAREST taklidi."""
    Sa = BP._np(src)
    sh, sw = Sa.shape[:2]
    px, py = sw / 2.0, sh / 2.0
    rad = int(math.hypot(sw, sh) / 2.0 * k * max(sx, sy, 1.0)) + 2
    H, W = F.shape[:2]
    x0, x1 = max(0, int(cx) - rad), min(W, int(cx) + rad)
    y0, y1 = max(0, int(cy) - rad), min(H, int(cy) + rad)
    if x0 >= x1 or y0 >= y1 or alpha <= 0.0:
        return
    X, Y = np.meshgrid(np.arange(x0, x1) + 0.5 - cx, np.arange(y0, y1) + 0.5 - cy)
    r = math.radians(rot)
    c, s = math.cos(r), math.sin(r)
    xr = c * X + s * Y
    yr = -s * X + c * Y
    u = np.floor(xr / (k * sx) + px).astype(np.int32)
    v = np.floor(yr / (k * sy) + py).astype(np.int32)
    m = (u >= 0) & (u < sw) & (v >= 0) & (v < sh)
    if not m.any():
        return
    samp = np.zeros((y1 - y0, x1 - x0, 4), np.float32)
    samp[m] = Sa[v[m], u[m]]
    a = samp[..., 3:4] / 255.0 * alpha
    col = samp[..., :3] if tint is None else np.array(tint, np.float32)
    F[y0:y1, x0:x1] = F[y0:y1, x0:x1] * (1.0 - a) + col * a


def shadow(F, gx, gy, rx, ry, a=0.28):
    cx, cy = gx * ZOOM, gy * ZOOM
    RX, RY = rx * ZOOM, ry * ZOOM
    H, W = F.shape[:2]
    x0, x1 = max(0, int(cx - RX) - 1), min(W, int(cx + RX) + 2)
    y0, y1 = max(0, int(cy - RY) - 1), min(H, int(cy + RY) + 2)
    if x0 >= x1 or y0 >= y1:
        return
    X, Y = np.meshgrid(np.arange(x0, x1) + 0.5 - cx, np.arange(y0, y1) + 0.5 - cy)
    m = ((X / RX) ** 2 + (Y / RY) ** 2) <= 1.0
    F[y0:y1, x0:x1][m] *= (1.0 - a)


def pose(pos, sector, sp=1.0, sq=1.0, rot=0.0, flash=0.0, d=(1.0, 0.0), gnd=None, z=0.0):
    return dict(pos=pos, sector=sector, sp=sp, sq=sq, rot=rot, flash=flash, d=d, gnd=gnd, z=z)


def seg(ta, t0, t1):
    return clamp01((ta - t0) / max(1e-6, t1 - t0))


def add(p, q, k=1.0):
    return (p[0] + q[0] * k, p[1] + q[1] * k)


# ------------------------------------------------------------------ hareketler (ta = saldırı başından; dönüş None = dinlenme)
REST = KP.REST
BODY = (KP.CHAR[0], KP.CHAR[1] - 4.0)


class Base:
    T_END = 0.70

    def __init__(self, geo):
        self.g = geo
        self.d = geo.d
        self.sec = sector_of(geo.d)
        self.perp = (-geo.d[1], geo.d[0])

    def hits(self):
        """[(yaratık sırası, isabet anı, itme yönü)]"""
        return [(i, self.T_HIT, self.g.push[i]) for i in range(len(self.g.hit))]

    def ghost(self, F, ta):
        pass

    def fx(self, Lg, Lf, ta):
        pass


class Now(Base):
    T_HIT = KP.T_HIT
    T_END = KP.T_HOME

    def pose(self, ta):
        pos, vk, sp, sq, flash = KP.shield_pose(self.g, ta)
        return pose(pos, self.sec if vk == "tgt" else 0, sp, sq, 0.0, 0.35 * flash, self.d)

    def ghost(self, F, ta):
        age = ta - self.T_HIT
        if 0.0 <= age < 0.3:
            k = age / 0.3
            e = ez("out", k)
            gp = add(self.g.cp, self.d, 26.0 * e)
            sx, sy = axis_scale(1.0, 1.0, self.d)
            sc = 1.25 + 0.6 * e
            blit_rs(F, sector_img(self.sec), *S(gp), WPP * ZOOM, sc, sc, 0.0, 0.7 * (1.0 - k) ** 1.4, GHOST_TINT)


class Hucum(Base):
    T_OUT, T_WIND, T_HIT, T_STOP, T_BOUNCE, T_HOLD, T_END = 0.10, 0.24, 0.285, 0.355, 0.46, 0.52, 0.78
    LEAN = 22.0

    def pose(self, ta):
        g, d = self.g, self.d
        back = add(g.ready, d, -15.0)
        over = add(g.cp, d, 5.0)
        bounce = add(g.cp, d, -14.0)
        lean = self.LEAN * d[0]
        if ta < 0.0 or ta >= self.T_END:
            return None
        if ta < self.T_OUT:
            return pose(lerp(REST, g.ready, ez("out", seg(ta, 0, self.T_OUT))), self.sec, d=d)
        if ta < self.T_WIND:
            e = ez("inout", seg(ta, self.T_OUT, self.T_WIND))
            return pose(lerp(g.ready, back, e), self.sec, 1.0 - 0.12 * e, 1.0 + 0.08 * e, -lean * e, d=d)
        if ta < self.T_HIT:
            e = ez("in", seg(ta, self.T_WIND, self.T_HIT))
            return pose(lerp(back, over, e), self.sec, 0.88 + 0.37 * e, 1.08 - 0.22 * e, -lean + 1.8 * lean * e, d=d)
        if ta < self.T_STOP:
            k = seg(ta, self.T_HIT, self.T_STOP)
            return pose(over, self.sec, 0.70, 1.24, 0.8 * lean * (1.0 - k), 1.0 - k, d=d)
        if ta < self.T_BOUNCE:
            e = seg(ta, self.T_STOP, self.T_BOUNCE)
            eo = ez("out", e)
            wob = 13.0 * math.sin(e * math.pi * 3.0) * (1.0 - e)
            return pose(lerp(over, bounce, eo), self.sec, 0.70 + 0.30 * eo, 1.24 - 0.24 * eo, -wob, d=d)
        if ta < self.T_HOLD:
            return pose(bounce, self.sec, d=d)
        e = ez("inout", seg(ta, self.T_HOLD, self.T_END))
        return pose(lerp(bounce, REST, e), self.sec if e < 0.55 else 0, d=d)

    def ghost(self, F, ta):
        age = ta - self.T_HIT
        if 0.0 <= age < 0.34:
            k = age / 0.34
            e = ez("out", k)
            gp = add(self.g.cp, self.d, 4.0 + 34.0 * e)
            sc = 1.4 + 0.8 * e
            blit_rs(F, sector_img(self.sec), *S(gp), WPP * ZOOM, sc, sc, 0.0, 0.75 * (1.0 - k) ** 1.3, GHOST_TINT)

    def fx(self, Lg, Lf, ta):
        d, p = self.d, self.perp
        ## hız çizgileri: atılışta arkasında, isabetten sonra 0,05 sn'de kısalıp biter
        if self.T_WIND <= ta < self.T_HIT + 0.05:
            pp = self.pose(ta)["pos"]
            c = KP.rel(self.g, pp)
            if ta < self.T_HIT:
                ln = 6.0 + 22.0 * seg(ta, self.T_WIND, self.T_HIT)
            else:
                ln = 28.0 * (1.0 - seg(ta, self.T_HIT, self.T_HIT + 0.05))
            for j, off in enumerate((-7.0, 0.0, 7.0)):
                l2 = ln * (0.7 if j != 1 else 1.0)
                a0 = add(add(c, p, off), d, -8.0)
                streak(Lf, a0, add(a0, d, -l2), CREAM_W)
        age = ta - self.T_HIT
        if 0.0 <= age < 0.1:
            KP.star4(Lf, (d[0] * 6.0, d[1] * 6.0), 10.0 * (1.0 - age / 0.1) + 1.0, CREAM_W)


class Cakilma(Base):
    T_OUT, T_RISE, T_HIT, T_STOP, T_TREM, T_PULL, T_END = 0.10, 0.28, 0.33, 0.39, 0.50, 0.58, 0.84
    SH = 9.0  # sivri uç yerdeyken kalkan merkezi yerin bu kadar üstünde
    LIFT = 30.0

    def __init__(self, geo):
        super().__init__(geo)
        t = geo.g["target"]
        self.gp = (t[0] - geo.d[0] * 15.0, t[1] + 6.0 - geo.d[1] * 15.0)  # çakılma noktası (yer)
        self.ready_g = (geo.ready[0], geo.ready[1] + self.SH + 4.0)
        self.cracks = TP.make_cracks(11, 6, 10.0, 22.0)

    def hits(self):
        out = []
        for i, e in enumerate(self.g.hit):
            r = unit((e[0] - self.gp[0], e[1] + 7.0 - self.gp[1]))
            out.append((i, self.T_HIT, r))
        return out

    def pose(self, ta):
        g, d = self.g, self.d
        if ta < 0.0 or ta >= self.T_END:
            return None
        top = (self.gp[0], self.gp[1] - self.SH)
        if ta < self.T_OUT:
            return pose(lerp(REST, g.ready, ez("out", seg(ta, 0, self.T_OUT))), self.sec, d=d)
        if ta < self.T_RISE:
            e = seg(ta, self.T_OUT, self.T_RISE)
            gx = lerp(self.ready_g, self.gp, ez("inout", e))
            z = self.LIFT * ez("out", e)
            base = lerp(g.ready, top, ez("inout", e))
            return pose((base[0], base[1] - z), self.sec, 1.0, 1.0, -6.0 * d[0] * e, d=(0.0, 1.0), gnd=gx, z=z)
        if ta < self.T_HIT:
            e = ez("in", seg(ta, self.T_RISE, self.T_HIT))
            z = self.LIFT * (1.0 - e)
            return pose((top[0], top[1] - z), self.sec, 1.15, 0.9, -6.0 * d[0] * (1.0 - e), d=(0.0, 1.0), gnd=self.gp, z=z)
        if ta < self.T_STOP:
            k = seg(ta, self.T_HIT, self.T_STOP)
            return pose((top[0], top[1] + 2.0), self.sec, 0.78, 1.18, 0.0, 1.0 - k, d=(0.0, 1.0), gnd=self.gp)
        if ta < self.T_TREM:
            e = seg(ta, self.T_STOP, self.T_TREM)
            sh = 1.2 * math.sin(e * math.pi * 7.0) * (1.0 - e)
            sy = 0.78 + 0.22 * ez("out", e)
            return pose((top[0] + sh, top[1] + 2.0 * (1.0 - e)), self.sec, sy, 1.18 - 0.18 * ez("out", e), 0.0, d=(0.0, 1.0), gnd=self.gp)
        if ta < self.T_PULL:
            e = ez("out", seg(ta, self.T_TREM, self.T_PULL))
            return pose((top[0], top[1] - 8.0 * e), self.sec, d=d, gnd=self.gp, z=8.0 * e)
        e = ez("inout", seg(ta, self.T_PULL, self.T_END))
        return pose(lerp((top[0], top[1] - 8.0), REST, e), self.sec if e < 0.55 else 0, d=d)

    def ghost(self, F, ta):
        age = ta - self.T_HIT
        if 0.0 <= age < 0.36:
            k = age / 0.36
            e = ez("out", k)
            gp = (self.gp[0], self.gp[1] - self.SH - 22.0 * e)
            sc = 1.2 + 0.5 * e
            blit_rs(F, sector_img(self.sec), *S(gp), WPP * ZOOM, sc, sc, 0.0, 0.72 * (1.0 - k) ** 1.3, GHOST_TINT)

    def fx(self, Lg, Lf, ta):
        age = ta - self.T_HIT
        if age < 0.0:
            return
        c = KP.rel(self.g, self.gp)
        KP.np_ring(Lg, c, 4.0, 2.0, 38.0, 19.0, 3.0, KP.GHOST, age / 0.34, nbreak=6, phase=0.5, ol=KP.GHOST_OL, fade=1.0, brk=0.5)
        KP.np_ring(Lg, c, 3.0, 1.5, 24.0, 12.0, 2.0, KP.GHOST, (age - 0.07) / 0.3, nbreak=5, phase=1.7, ol=KP.GHOST_OL, fade=1.0, brk=0.5)
        if age < 0.55:
            fade = 1.0 if age < 0.35 else 1.0 - (age - 0.35) / 0.2
            TP.draw_cracks(Lg, c, self.cracks, min(1.0, age / 0.08), fade, (70, 58, 40), (150, 132, 98))
        if age < 0.1:
            KP.star4(Lf, (c[0], c[1] - 2.0), 9.0 * (1.0 - age / 0.1) + 1.0, CREAM_W)


class Firildak(Base):
    T_FLY, T_STOP, T_RECOIL, T_END = 0.30, 0.35, 0.44, 0.74
    T_HIT = 0.30

    def __init__(self, geo):
        super().__init__(geo)
        mid = lerp(REST, geo.cp, 0.5)
        self.ctrl = add(mid, self.perp, -20.0 if geo.d[1] > 0.7 else 18.0)
        self.back = add(geo.cp, geo.d, -7.0)
        self.ret_ctrl = add(lerp(self.back, REST, 0.5), self.perp, 14.0)

    def _bez(self, a, c, b, t):
        return ((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * c[0] + t * t * b[0], (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * c[1] + t * t * b[1])

    def yaw(self, ta):
        if ta < self.T_FLY:
            e = seg(ta, 0, self.T_FLY)
            total = 720.0 + self.sec * 45.0
            return total * (1.0 - (1.0 - e) ** 2)
        if ta < self.T_RECOIL:
            return 720.0 + self.sec * 45.0
        e = ez("inout", seg(ta, self.T_RECOIL, self.T_END))
        a0 = self.sec * 45.0
        return a0 + (360.0 - a0 + 360.0) * e

    def pose(self, ta):
        g, d = self.g, self.d
        if ta < 0.0 or ta >= self.T_END:
            return None
        sec = int(round(self.yaw(ta) / 45.0)) % 8
        if ta < self.T_FLY:
            e = ez("inout", seg(ta, 0, self.T_FLY))
            pul = 1.0 + 0.06 * math.sin(ta * 60.0)
            return pose(self._bez(REST, self.ctrl, g.cp, e), sec, pul, 1.0, 0.0, d=d)
        if ta < self.T_STOP:
            k = seg(ta, self.T_FLY, self.T_STOP)
            return pose(g.cp, self.sec, 0.76, 1.16, 0.0, 1.0 - k, d=d)
        if ta < self.T_RECOIL:
            e = ez("out", seg(ta, self.T_STOP, self.T_RECOIL))
            return pose(lerp(g.cp, self.back, e), self.sec, 0.76 + 0.24 * e, 1.16 - 0.16 * e, d=d)
        e = ez("inout", seg(ta, self.T_RECOIL, self.T_END))
        return pose(self._bez(self.back, self.ret_ctrl, REST, e), sec, d=d)

    def ghost(self, F, ta):
        age = ta - self.T_HIT
        if 0.0 <= age < 0.3:
            k = age / 0.3
            e = ez("out", k)
            gp = add(self.g.cp, self.d, 28.0 * e)
            sc = 1.3 + 0.6 * e
            blit_rs(F, sector_img(self.sec), *S(gp), WPP * ZOOM, sc, sc, 0.0, 0.72 * (1.0 - k) ** 1.4, GHOST_TINT)

    def fx(self, Lg, Lf, ta):
        ## uçarken etrafında dönen iki kısa krem yay (yaw ile)
        if 0.03 <= ta < self.T_FLY or self.T_RECOIL + 0.03 <= ta < self.T_END - 0.05:
            p = self.pose(ta)
            if p is None:
                return
            c = KP.rel(self.g, p["pos"])
            yaw = math.radians(self.yaw(ta) * 1.0)
            for off in (0.0, math.pi):
                arc_dots(Lf, c, 13.0, 6.5, yaw + off, yaw + off + 1.1, CREAM_W)
        age = ta - self.T_HIT
        if 0.0 <= age < 0.1:
            KP.star4(Lf, (self.d[0] * 6.0, self.d[1] * 6.0), 9.0 * (1.0 - age / 0.1) + 1.0, CREAM_W)


class Supurme(Base):
    T_OUT, T_WIND, T_SWEEP, T_STOP, T_HOLD, T_END = 0.12, 0.20, 0.36, 0.41, 0.50, 0.76
    SPAN0, SPAN1 = 60.0, -55.0

    def __init__(self, geo):
        super().__init__(geo)
        self.phi = math.degrees(math.atan2(geo.d[1], geo.d[0]))
        self.R = math.hypot(geo.cp[0] - BODY[0], geo.cp[1] - BODY[1])
        self.T_HIT = self.T_SWEEP

    def at(self, a_deg, r):
        a = math.radians(a_deg)
        return (BODY[0] + math.cos(a) * r, BODY[1] + math.sin(a) * r)

    def ang(self, ta):
        e = ez("inout", seg(ta, self.T_WIND, self.T_SWEEP))
        return self.phi + self.SPAN0 + 12.0 + (self.SPAN1 - self.SPAN0 - 12.0) * e

    def hits(self):
        out = []
        tang = (math.cos(math.radians(self.phi - 90.0)), math.sin(math.radians(self.phi - 90.0)))
        for i, e in enumerate(self.g.hit):
            a = math.degrees(math.atan2(e[1] - BODY[1], e[0] - BODY[0]))
            rel = (a - self.phi + 180.0) % 360.0 - 180.0
            ## süpürme açısı bu yaratığa geldiği an (ease inout tersinden)
            a0 = self.SPAN0 + 12.0
            f = clamp01((rel - a0) / (self.SPAN1 - a0))
            lo, hi = 0.0, 1.0
            for _ in range(24):
                m = (lo + hi) * 0.5
                if ez("inout", m) < f:
                    lo = m
                else:
                    hi = m
            t = self.T_WIND + (self.T_SWEEP - self.T_WIND) * lo
            r = unit((e[0] - BODY[0], e[1] - BODY[1]))
            out.append((i, t, unit((r[0] + 0.7 * tang[0], r[1] + 0.7 * tang[1]))))
        return out

    def pose(self, ta):
        if ta < 0.0 or ta >= self.T_END:
            return None
        a_start = self.phi + self.SPAN0
        p0 = self.at(a_start, self.R * 0.8)
        if ta < self.T_OUT:
            return pose(lerp(REST, p0, ez("out", seg(ta, 0, self.T_OUT))), sector_of(unit((p0[0] - BODY[0], p0[1] - BODY[1]))))
        if ta < self.T_WIND:
            e = ez("inout", seg(ta, self.T_OUT, self.T_WIND))
            a = a_start + 12.0 * e
            p = self.at(a, self.R * (0.8 - 0.05 * e))
            return pose(p, sector_of(unit((p[0] - BODY[0], p[1] - BODY[1]))), 0.92, 1.05)
        if ta < self.T_SWEEP:
            a = self.ang(ta)
            p = self.at(a, self.R)
            rd = unit((p[0] - BODY[0], p[1] - BODY[1]))
            tg = (math.cos(math.radians(a - 90.0)), math.sin(math.radians(a - 90.0)))
            sx, sy = axis_scale(1.15, 0.92, tg)
            return pose(p, sector_of(rd), 1.0, 1.0, 0.0, d=rd) | {"sx": sx, "sy": sy}
        a_end = self.phi + self.SPAN1
        pe = self.at(a_end, self.R)
        rd = unit((pe[0] - BODY[0], pe[1] - BODY[1]))
        if ta < self.T_STOP:
            k = seg(ta, self.T_SWEEP, self.T_STOP)
            return pose(pe, sector_of(rd), 0.8, 1.15, 0.0, 1.0 - k, d=rd)
        if ta < self.T_HOLD:
            return pose(pe, sector_of(rd), d=rd)
        e = ez("inout", seg(ta, self.T_HOLD, self.T_END))
        return pose(lerp(pe, REST, e), sector_of(rd) if e < 0.55 else 0, d=rd)

    def ghost(self, F, ta):
        age = ta - self.T_SWEEP
        if 0.0 <= age < 0.3:
            k = age / 0.3
            e = ez("out", k)
            a_end = self.phi + self.SPAN1
            pe = self.at(a_end, self.R)
            tg = (math.cos(math.radians(a_end - 90.0)), math.sin(math.radians(a_end - 90.0)))
            rd = unit((pe[0] - BODY[0], pe[1] - BODY[1]))
            gp = add(add(pe, tg, 16.0 * e), rd, 10.0 * e)
            sc = 1.25 + 0.6 * e
            blit_rs(F, sector_img(sector_of(rd)), *S(gp), WPP * ZOOM, sc, sc, 0.0, 0.7 * (1.0 - k) ** 1.4, GHOST_TINT)

    def fx(self, Lg, Lf, ta):
        ## süpürme izi değil (ardıl görüntü yok, madde 256): her isabette küçük yıldız
        for i, t, _ in self.hits():
            age = ta - t
            if 0.0 <= age < 0.09:
                e = self.g.hit[i]
                KP.star4(Lf, KP.rel(self.g, (e[0] - 6.0, e[1] - 4.0)), 6.0 * (1.0 - age / 0.09) + 1.0, CREAM_W)


def streak(L, a, b, cols):
    """Düz çizgi (temasa göre dünya), baştan sona renk koyulaşır."""
    x0, y0 = KP.fpx(a)
    x1, y1 = KP.fpx(b)
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n + 1):
        u = i / float(n)
        L.put(int(x0 + (x1 - x0) * u), int(y0 + (y1 - y0) * u), cols[min(len(cols) - 1, int(u * len(cols)))])


def arc_dots(L, c, rx, ry, a0, a1, cols):
    n = 14
    for i in range(n + 1):
        u = i / float(n)
        a = a0 + (a1 - a0) * u
        x, y = KP.fpx((c[0] + math.cos(a) * rx, c[1] + math.sin(a) * ry))
        L.put(int(x), int(y), cols[min(len(cols) - 1, int((1.0 - u) * len(cols)))])


SPEC = {
    "N": ("ŞU AN", "oyundaki: öne çık, kurul, çarp, kısa duraklama", Now),
    "A": ("A - Hücum", "geriye yaslan, öne eğilip fırla (hız çizgisi), sert çarp, geri sek + sallan", Hucum),
    "B": ("B - Çakılma", "havaya kalk, sivri ucuyla yere çakıl: halka + çatlak, hayalet yerden yükselir", Cakilma),
    "C": ("C - Fırıldak", "kendi ekseninde dönerek uç (8 görünüş), yüzü hedefe dönük çarp, dönerek dön", Firildak),
    "D": ("D - Süpürme", "önünden yay çizerek süpür: düşmanlar sırayla vurulur, sonda ağır duraklama", Supurme),
}
ORDER = ["N", "A", "B", "C", "D"]


class Lane:
    def __init__(self, did, idx, t_first=T_FIRST, groups=(0, 1)):
        self.did, self.idx = did, idx
        self.t_first = t_first
        self.groups = groups
        self.mv = [SPEC[did][2](KP.GEOS[g]) for g in range(len(KP.GROUPS))]

    def attack(self, t):
        if t < self.t_first:
            return -1.0, -1
        n = int((t - self.t_first) // INTERVAL)
        return t - self.t_first - n * INTERVAL, n

    def enemy_state(self, gj, i, t):
        """(ofset, zıplama, isabetten beri)"""
        if gj not in self.groups:
            return (0.0, 0.0), 0.0, -1.0
        k = self.groups.index(gj)
        mv = self.mv[gj]
        h = [x for x in mv.hits() if x[0] == i]
        if not h:
            return (0.0, 0.0), 0.0, -1.0
        _, th, pd = h[0]
        per = INTERVAL * len(self.groups)
        age = (t - (self.t_first + k * INTERVAL + th)) % per
        if age < 0.2:
            kk = ez("out", age / 0.2)
            return (pd[0] * PUSH * kk, pd[1] * PUSH * kk), 0.0, age
        if age < 0.35:
            return (pd[0] * PUSH, pd[1] * PUSH), 0.0, age
        if age < 1.25:
            kk = (age - 0.35) / 0.9
            rem = 1.0 - ez("inout", kk)
            hop = abs(math.sin(kk * math.pi * 4.0)) * 3.0 * (1.0 - kk)
            return (pd[0] * PUSH * rem, pd[1] * PUSH * rem), hop, age
        return (0.0, 0.0), 0.0, age

    def render(self, t):
        F = KP.lane_bg(self.idx)
        ta, n = self.attack(t)
        gi = self.groups[n % len(self.groups)] if n >= 0 else self.groups[0]
        geo = KP.GEOS[gi]
        mv = self.mv[gi]
        tq = int(ta * 30.0) / 30.0 if n >= 0 else -1.0  ## efekt 30 fps'e kuantalı
        Lg, Lf = TP.Lay(), TP.Lay()
        if n >= 0:
            mv.fx(Lg, Lf, tq)
        tx, ty = S(geo.cp)
        k_fx = WPP * ZOOM
        cg, cf = Lg.cropped(), Lf.cropped()
        if cg is not None:
            blit(F, cg[0], tx, ty, k_fx, 0.0, cg[1])
        p = mv.pose(ta) if n >= 0 else None
        if p is not None and p.get("gnd") is not None:
            z = p["z"]
            shadow(F, p["gnd"][0], p["gnd"][1], 7.5 * (1.0 - z / 70.0), 3.2 * (1.0 - z / 70.0))
        items = [(KP.CHAR[1] + 18.0, "char", None)]
        for gj, gg in enumerate(KP.GROUPS):
            g2 = KP.GEOS[gj]
            for i, en in enumerate(g2.hit):
                off, hop, age = self.enemy_state(gj, i, t)
                pp = (en[0] + off[0], en[1] + off[1] - hop)
                items.append((pp[1] + 7.0, "slime", (pp, age)))
            for en in gg["miss"]:
                items.append((en[1] + 7.0, "slime", (en, -1.0)))
        for _, kind, data in sorted(items, key=lambda q: q[0]):
            if kind == "char":
                cx, cy = S(KP.CHAR)
                blit(F, KP.char_img(), cx, cy, KP.CHAR_K * ZOOM)
                continue
            pp, age = data
            sx, sy = S(pp)
            blit(F, KP.slime(), sx, sy - 2, KP.SLIME_K * ZOOM)
            if 0.0 <= age < 0.1:
                blit(F, KP.slime(), sx, sy - 2, KP.SLIME_K * ZOOM, alpha=0.85 * (1.0 - age / 0.1), tint=(255, 255, 255))
        if p is None:
            bob = math.sin(t * 2.6) * 0.8
            px, py = S((REST[0], REST[1] + bob))
            blit_rs(F, sector_img(0), px, py, WPP * ZOOM)
        else:
            if "sx" in p:
                sxx, syy = p["sx"], p["sy"]
            else:
                sxx, syy = axis_scale(p["sp"], p["sq"], p["d"])
            px, py = S(p["pos"])
            img = sector_img(p["sector"])
            blit_rs(F, img, px, py, WPP * ZOOM, sxx, syy, p["rot"])
            if p["flash"] > 0.0:
                blit_rs(F, img, px, py, WPP * ZOOM, sxx, syy, p["rot"], 0.55 * p["flash"], (255, 250, 235))
        if n >= 0:
            mv.ghost(F, ta)
        if cf is not None:
            blit(F, cf[0], tx, ty, k_fx, 0.0, cf[1])
        return Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")


def lane_label(im, did, kind=None, small=False):
    dd = ImageDraw.Draw(im)
    label(dd, 6, 3, SPEC[did][0], 12)
    if kind:
        label(dd, im.width - 110, 3, kind, 11, (250, 228, 160))
    if not small:
        label(dd, 6, im.height - 16, SPEC[did][1], 10, (226, 220, 204))


INFO = [
    "efekt aynı: D Hayalet Kalkan silüeti temasta (seçildi)",
    "değişen HAREKET: ŞU AN oyundaki, A-D yeni",
    "A isabet 0,285 sn, 0,07 sn duraklama + geri sekme",
    "B isabet 0,33 sn (havaya kalkış), saplı titreme",
    "C isabet 0,30 sn, 2 tam dönüş (8 görünüş)",
    "D yoldakiler SIRAYLA (0,2-0,36 sn), sonda duraklama",
    "beyaz parlama = isabet; uzaktaki slime vurulmaz",
    "aralık %.2f sn, 45 px itme, Talon + Şövalye L3" % INTERVAL,
]


def build_game():
    lanes = [Lane(d, i) for i, d in enumerate(ORDER)]
    n = int(round(LOOP * FPS))
    dt = LOOP / n
    lw, lh = int(KP.LWW * ZOOM), int(KP.LHW * ZOOM)
    info = KP.info_tile(lw, lh, INFO, "Kalkan vuruşu - hareket prototipleri")
    hd = header(lw * 2 + 4, "Kalkan vuruşu  ·  oyun ölçeği (1080p), gerçek hız", "1. darbe SAĞA (yan görünüş), 2. darbe AŞAĞI (ön görünüş)")
    frames = []
    for st in range(n):
        t = st * dt
        tiles = []
        for ln in lanes:
            im = ln.render(t)
            _, na = ln.attack(t)
            lane_label(im, ln.did, kind=KP.GROUPS[na % 2]["name"] if na >= 0 else None)
            tiles.append(im)
        tiles.append(info)
        frames.append(stack_v([hd, TP.grid(tiles, 2)]))
    th = T_FIRST + 0.3
    save_gif(frames, os.path.join(OUT, "kalkan_vurus.gif"), 1.0 / dt,
             [int(th * FPS), int((th + 0.1) * FPS), int((th + INTERVAL) * FPS)])
    frames[int((th + 0.02) * FPS)].save(os.path.join(OUT, "kalkan_vurus_kare.png"))


def build_slow(speed=0.25, z=2):
    lanes = [Lane(d, i, t_first=0.05, groups=(0,)) for i, d in enumerate(ORDER)]
    fps = 40
    real_len = 0.9
    n = int(round(real_len / speed * fps))
    dt = real_len / n
    crop = (int((KP.CHAR[0] - 20) * ZOOM), int((KP.CHAR[1] - 56) * ZOOM), int((KP.CHAR[0] + 150) * ZOOM), int((KP.CHAR[1] + 46) * ZOOM))
    cw, ch = (crop[2] - crop[0]) * z // 2, (crop[3] - crop[1]) * z // 2
    info = Image.new("RGB", (cw, ch), (30, 34, 32))
    frames = []
    for st in range(n):
        t = st * dt
        tiles = []
        for ln in lanes:
            im = ln.render(t).crop(crop).resize((cw, ch), Image.NEAREST)
            lane_label(im, ln.did, small=True)
            tiles.append(im)
        tiles.append(info)
        frames.append(stack_v([header(cw * 2 + 4, "Kalkan vuruşu SAĞA - YAVAŞ ÇEKİM x%.2f" % speed,
                                      "süre %.2f sn (gerçek)" % max(0.0, t - 0.05)), TP.grid(tiles, 2)]))
    save_gif(frames, os.path.join(OUT, "kalkan_vurus_yavas.gif"), fps, [int(0.33 / dt), int(0.4 / dt), int(0.25 / dt)])


def build_strip():
    """Sağa darbe, her yön kendi isabetine hizalı 8 kare."""
    offs = [-0.2, -0.1, -0.04, 0.0, 0.04, 0.1, 0.18, 0.3]
    crop = (int((KP.CHAR[0] - 10) * ZOOM), int((KP.CHAR[1] - 52) * ZOOM), int((KP.CHAR[0] + 136) * ZOOM), int((KP.CHAR[1] + 44) * ZOOM))
    cw, ch = crop[2] - crop[0], crop[3] - crop[1]
    LBL = 150
    rows = []
    for i, did in enumerate(ORDER):
        ln = Lane(did, i, t_first=0.0, groups=(0,))
        th = ln.mv[0].T_HIT
        row = Image.new("RGB", (LBL + len(offs) * (cw + 2), ch + 18), (24, 26, 26))
        dd = ImageDraw.Draw(row)
        for j, o in enumerate(offs):
            row.paste(ln.render(max(0.0, th + o)).crop(crop), (LBL + j * (cw + 2), 18))
            label(dd, LBL + j * (cw + 2) + 4, 2, "%+.2f sn%s" % (o, "  isabet" if o == 0.0 else ""), 10, (220, 214, 198))
        label(dd, 6, 22, SPEC[did][0], 12)
        rows.append(row)
    im = stack_v(rows, 6)
    im.save(os.path.join(OUT, "kalkan_vurus_kareler.png"))
    print("kareler", im.size)


if __name__ == "__main__":
    KP.setup()
    for w in (sys.argv[1:] or ["kareler", "oyun", "yavas"]):
        {"oyun": build_game, "yavas": build_slow, "kareler": build_strip}[w]()
