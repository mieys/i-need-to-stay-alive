# -*- coding: utf-8 -*-
"""ASA PARTİKÜLLERİ prototipleri (2026-10-19, oyuna bağlı DEĞİL). Kullanıcı: "buz asası ucundan buza benzer parlak partikülleri ateş
asası da ateş partikülleri döksün arcane asası morumsu sihirli partiküller döksün (hepsi harekete bağlı olarak arkada kalacak
çıkardığı partiküller) yıldırım asasının ucunda elektrik parçacıkları olsun ve isabet ettiği yaratıklardan elektrik partikülleri
dökülsün hafif."

ŞU AN (oyunda): asa ucunda partikül YOK (yalnız kademe 5 uç parıltısı, madde 247). Yıldırım ışını = bolt_tiles şeridi + uçta
"orb" + hedefte "impact" döngüsü (fx_lightning_beam.gd); renkler SARI-ALTIN (#fffff6 #fff4aa #ffd040 #e88c20) - mavi değil.

Hareket = oyundaki HÜCUM takibi (weapon_follow_math.gd): tepe slotu (0,-62,5), yay w=13 ζ=0,45 ile gidiş yönüne 9 px + yatayda 6 px
alçalma, uç gidiş yönüne (TURN_RATE 14), salınım 1,75 px x (1 - 0,7 hız). Uç = weapon_tip.gd (ileri eksende en uzak opak piksel -
6 px). Partiküller DÜNYADA kalır (asa yürüdükçe arkada iz olur), doğma hızı uç hızıyla artar (dururken uçta hafif damla).
Partikül pikseli = KARAKTER pikseli 0,903 dünya px (Şovalye; silah/mermi pikseli 0,575 1080p'de tek ekran pikseline düşüp kayboldu). Dither / nokta gürültüsü YOK: düz renk + 4 adım saydamlık,
az sayıda şekilli parçacık (madde 241 dersleri).

Üç yön (her yön kendi çizim dili):
  A Sade Toz          - 1 piksellik tanecikler, sadece renk adımıyla söner; ateş yükselen kor, buz yavaş düşen kırağı + yanıp
                        sönen parıltı, arcane girdaplı mor zerre, yıldırım uçta küçük cızırtı + yay çizen kıvılcım çizgisi.
  B Element Parçaları - 3-6 piksel ŞEKİLLİ parçalar, halka gölgeli: ateş küçük alev dili (söner, duman olur), buz yuvarlanan kristal
                        kıymığı (düşer) + büyüyüp küçülen 4 kollu parıltı, arcane dönen yıldız + açılan rün halkası, yıldırım uçta
                        dallanan mini şimşek + kuyruklu kıvılcım boncukları.
  C Dökülen           - partiküller uçtan YERE dökülür (asanın altındaki ayak hizasına düşer), yerde kısa süre kalır: ateş kora
                        döner + duman, buz kırağı parıltısı, arcane küçük rün halkası, yıldırım kıvılcımı bir kez seker.
Yıldırım isabeti (ışın hedefindeki yaratıktan, hafif): A gövde kenarından fırlayıp düşen kıvılcım çizgileri, B gövdede gezinen
küçük şimşek yayları + boncuklar, C kıvılcımlar yaratığın çevresine dökülüp seker.

Çıktılar (out/asa_partikul/): asa_<anahtar>.gif (1080p oyun ölçeği, kamera sabit, A/B/C yan yana, 30 fps),
yildirim_isabet.gif (ŞU AN + A/B/C, ışın + uç + isabet), asa_ozet.png (hepsi, yürürken an), asa_yakin.png (x4 yakın).
Çalıştırma: python tools/proto_20261019/asa_partikul_proto.py [yuru|isabet|ozet]   (argümansız: hepsi)
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "proto_20261017")))
import silah_takip_proto as T  # noqa: E402
from silah_takip_proto import blit2, ellipse, icon_np, WPP, CHAR_K, CHAR_OFF_Y, SPEED, slime_frame, SLIME_K  # noqa: E402
from mermi_proto import label, asset  # noqa: E402
from bicak_proto import header, stack_v, save_gif  # noqa: E402

OUT = os.path.join(HERE, "out", "asa_partikul")
TICK = 60
DT = 1.0 / TICK
FPS_OUT = 30
STEP_OUT = TICK // FPS_OUT
TX = CHAR_K  # partikül pikseli = karakter pikseli 0,903 dünya px (48x48 kuralı; silah pikseli 0,575 1080p'de kayboluyordu)
D2R = math.pi / 180.0
FWD = -45.0 * D2R  # zanaat asalarında uç sağ-üstte (weapon_tier_art.gd FORWARD)
SLOT_TOP = (0.0, -62.5)  # player.gd WEAPON_ICON_SLOTS[0] x 0,5
FEET = 12.0  # ayak / silah gölgesi hizası (P.y + 12)


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


def ramp(s):
    return [hx(c) for c in s.split()]


FIRE = ramp("#fff6c8 #fdd85a #f9ab2c #e0741e #a8401a")
SMOKE = hx("#a19b91")
ICE = ramp("#ffffff #e0f4fc #b4dcec #88bcd4 #5e8aa0")
ICE_OL = hx("#2e4a5e")
ARC = ramp("#fbf2ff #e8d2fa #c8a0f0 #9c64dc #6a3aa8")
ELEC = ramp("#fffff6 #fff4aa #ffd040 #e88c20")

STAFFS = [("fire_staff", "Ateş Asası", "fire"), ("buz_asasi", "Buz Asası", "ice"), ("arcane", "Arcane Asa", "arc"),
          ("lightning_staff", "Yıldırım Asası", "elec")]
## A ömürleri (sn): "uzun" = ilk gösterilen; "kisa" = kullanıcı 2026-10-19: "A ları beğendim fakat çok uzuyor parıltının kuyruğu,
## biraz daha kısa olmalı" -> ~%60 (%50 kuyruğu asanın gövdesinin altına sokuyordu; oyuna pişirilen değerler bunlar, tools/gen_staff_tip_fx.py).
A_LIFE = {"uzun": {"ember": (0.45, 0.75), "frost": (0.55, 0.9), "mote": (0.55, 0.85), "spark": (0.22, 0.36)},
          "kisa": {"ember": (0.27, 0.45), "frost": (0.33, 0.54), "mote": (0.33, 0.51), "spark": (0.15, 0.25)}}
A_MODE = "uzun"

VARIANTS = [("A", "A · Sade Toz", "1-2 px tanecik, renk adımıyla söner"),
            ("B", "B · Element Parçaları", "şekilli 3-7 px parça, halka gölge"),
            ("C", "C · Dökülen", "uçtan yere dökülür, yerde kısa kalır")]


# ------------------------------------------------------------------ yürüyüş
def make_track(path, start):
    loop = sum(d for d, _ in path)
    n = int(round(loop * TICK))
    out = []
    x, y = start
    face, walk_t, prev = (0, 1), 0.0, None
    for i in range(n):
        t = i * DT
        acc, d = 0.0, None
        for dur, dd in path:
            if t < acc + dur - 1e-9:
                d = dd
                break
            acc += dur
        if d is not None:
            if d != prev:
                walk_t = 0.0
            face = d
        vx, vy = (d[0] * SPEED, d[1] * SPEED) if d else (0.0, 0.0)
        out.append({"t": t, "P": (x, y), "V": (vx, vy), "moving": d is not None, "face": face, "walk_t": walk_t})
        x += vx * DT
        y += vy * DT
        walk_t = walk_t + DT if d is not None else 0.0
        prev = d
    return out, loop


_TIP = {}


def tip_px(key):
    """weapon_tip.gd: ileri eksende en uzak opak piksel, 6 px içeri (doku pikseli, merkez 24,24'e göre)."""
    if key not in _TIP:
        a = icon_np(key)[..., 3]
        ys, xs = np.nonzero(a > 8)
        fx, fy = math.cos(FWD), math.sin(FWD)
        px = xs + 0.5 - 24.0
        py = ys + 0.5 - 24.0
        pr = px * fx + py * fy
        m = pr >= pr.max() - 0.75
        tx, ty = float(px[m].mean()), float(py[m].mean())
        _TIP[key] = (tx - fx * 6.0, ty - fy * 6.0)
    return _TIP[key]


def ang_lerp(a, b, f):
    d = (b - a + math.pi) % (2.0 * math.pi) - math.pi
    return a + d * f


class Follow:
    """weapon_follow_math.gd HÜCUM (tepe slotu)."""

    def __init__(self, key, ang=math.pi / 2.0):
        self.key = key
        self.w = [0.0, 0.0]
        self.wv = [0.0, 0.0]
        self.ang = ang

    def step(self, st, aim=None):
        P, V, t = st["P"], st["V"], st["t"]
        L = math.hypot(V[0], V[1])
        tgt = (0.0, 0.0) if L < 1.0 else (V[0] / L * min(1.0, L / 60.0), V[1] / L * min(1.0, L / 60.0))
        w2, c = 13.0 * 13.0, 2.0 * 0.45 * 13.0
        for k in (0, 1):
            a = (tgt[k] - self.w[k]) * w2 - self.wv[k] * c
            self.wv[k] += a * DT
            self.w[k] += self.wv[k] * DT
        wl = math.hypot(self.w[0], self.w[1])
        bob = math.sin(t * 2.2 + 0.4) * 1.75 * (1.0 - min(1.0, wl) * 0.7)
        x = P[0] + SLOT_TOP[0] + self.w[0] * 9.0
        y = P[1] + SLOT_TOP[1] + self.w[1] * 9.0 + 6.0 * min(1.0, abs(self.w[0])) + bob
        pos = (round(x * 2.0) / 2.0, round(y * 2.0) / 2.0)
        if aim is not None:
            self.ang = ang_lerp(self.ang, math.atan2(aim[1] - pos[1], aim[0] - pos[0]), min(1.0, 12.0 * DT))
        elif L >= 25.0:
            self.ang = ang_lerp(self.ang, math.atan2(V[1], V[0]), min(1.0, 14.0 * DT))
        rot = self.ang - FWD
        tp = tip_px(self.key)
        c, s = math.cos(rot), math.sin(rot)
        tip = (pos[0] + (c * tp[0] - s * tp[1]) * WPP, pos[1] + (s * tp[0] + c * tp[1]) * WPP)
        return pos, rot, tip


# ------------------------------------------------------------------ partikül katmanı (silah pikseli ızgarası)
class Layer:
    def __init__(self, x0, y0, w, h, tx=None):
        self.x0, self.y0 = x0, y0
        self.tx = tx or TX
        self.W = int(math.ceil(w / self.tx)) + 2
        self.H = int(math.ceil(h / self.tx)) + 2
        self.a = np.zeros((self.H, self.W, 4), np.float32)

    def tc(self, wx, wy):
        return int(math.floor((wx - self.x0) / self.tx)), int(math.floor((wy - self.y0) / self.tx))

    def put(self, x, y, col, a=1.0):
        if a <= 0.0 or not (0 <= x < self.W and 0 <= y < self.H):
            return
        p = self.a[y, x]
        p[0] = col[0] * a + p[0] * (1.0 - a)
        p[1] = col[1] * a + p[1] * (1.0 - a)
        p[2] = col[2] * a + p[2] * (1.0 - a)
        p[3] = a + p[3] * (1.0 - a)

    def line(self, x0, y0, x1, y1, col, a=1.0, skip_last=False):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        x, y = x0, y0
        while True:
            if not (skip_last and x == x1 and y == y1):
                self.put(x, y, col, a)
            if x == x1 and y == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x += sx
            if e2 <= dx:
                err += dx
                y += sy

    def plus(self, x, y, r, cc, ca, a=1.0, diag=False):
        for i in range(1, r + 1):
            col = ca[min(len(ca) - 1, i - 1)] if isinstance(ca, list) else ca
            for dx, dy in (((i, i), (-i, i), (i, -i), (-i, -i)) if diag else ((i, 0), (-i, 0), (0, i), (0, -i))):
                self.put(x + dx, y + dy, col, a)
        self.put(x, y, cc, a)

    def mask(self, m, ox, oy, cols, a=1.0, light=None):
        """Halka gölgeli dolu şekil: m (h,w bool), dış halka cols[0] ... çekirdek cols[-1]; light=(dx,dy) parlak piksel kayması."""
        h, w = m.shape
        cur = m.copy()
        lvl = np.full(m.shape, -1, np.int32)
        k = 0
        while cur.any() and k < len(cols):
            er = cur.copy()
            er[1:, :] &= cur[:-1, :]
            er[:-1, :] &= cur[1:, :]
            er[:, 1:] &= cur[:, :-1]
            er[:, :-1] &= cur[:, 1:]
            ring = cur & ~er
            if k == len(cols) - 1:
                ring = cur
            lvl[ring] = k
            cur = er
            k += 1
        for yy in range(h):
            for xx in range(w):
                if lvl[yy, xx] >= 0:
                    self.put(ox + xx, oy + yy, cols[lvl[yy, xx]], a)
        if light is not None:
            ys, xs = np.nonzero(lvl == lvl.max())
            if len(xs):
                self.put(ox + int(xs.mean() + light[0]), oy + int(ys.mean() + light[1]), light[2], a)

    def composite(self, F, z):
        Hs, Ws = F.shape[:2]
        ys = np.minimum(((np.arange(Hs) + 0.5) / z / self.tx).astype(np.int32), self.H - 1)
        xs = np.minimum(((np.arange(Ws) + 0.5) / z / self.tx).astype(np.int32), self.W - 1)
        U = self.a[ys][:, xs]
        F *= (1.0 - U[..., 3:4])
        F += U[..., :3]


def band(a, steps=4):
    """Saydamlığı 4 adıma yuvarla (düz bantlar, dither yok)."""
    return max(0.0, math.ceil(a * steps - 1e-6) / steps)


_FLAME = {}


def flame_mask(h):
    if h not in _FLAME:
        w = max(2, int(round(h * 0.62)))
        r = w / 2.0
        ccy = h - r
        m = np.zeros((h, w), bool)
        for y in range(h):
            for x in range(w):
                cx, cy = x + 0.5 - r, y + 0.5
                if cy >= ccy:
                    m[y, x] = cx * cx + (cy - ccy) ** 2 <= r * r + 0.15
                else:
                    m[y, x] = abs(cx) <= r * (cy / ccy) ** 1.25 + 0.2
        _FLAME[h] = m
    return _FLAME[h]


_RH = {}


def rhombus_mask(L, Wd, q):
    key = (L, Wd, q)
    if key not in _RH:
        R = int(math.ceil(max(L, Wd) / 2.0)) + 1
        n = 2 * R + 1
        a = q * math.pi / 4.0
        c, s = math.cos(a), math.sin(a)
        m = np.zeros((n, n), bool)
        for y in range(n):
            for x in range(n):
                dx, dy = x - R, y - R
                u, v = c * dx + s * dy, -s * dx + c * dy
                m[y, x] = abs(u) / (L / 2.0) + abs(v) / (Wd / 2.0) <= 1.0 + 1e-6
        ys, xs = np.nonzero(m)
        m = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        _RH[key] = m
    return _RH[key]


# ------------------------------------------------------------------ partiküller
def zigzag(rng, n, seg, spread, base):
    pts = [(0.0, 0.0)]
    a = base
    x = y = 0.0
    for _ in range(n):
        a2 = a + rng.uniform(-spread, spread)
        L = rng.uniform(*seg)
        x += math.cos(a2) * L
        y += math.sin(a2) * L
        pts.append((x, y))
    return pts


class Emitter:
    """Bir asanın ucundan (ya da yıldırım isabetinde yaratıktan) partikül doğurur / ilerletir / çizer."""

    def __init__(self, elem, var, seed):
        self.elem, self.var, self.seed = elem, var, seed
        self.ps = []
        self.acc = 0.0
        self.arc_t = 0.0
        self.hit_acc = 0.0

    def rng(self, i, salt=0):
        return random.Random(self.seed * 1000003 + salt * 7919 + i)

    # ---- uç
    def emit_tip(self, i, tip, P, speed):
        e, v = self.elem, self.var
        base, k = {"A": (10.0, 0.33), "B": (5.0, 0.16), "C": (5.0, 0.14)}[v]
        if e == "elec" and v != "C":
            base, k = base * 0.7, k * 0.75
        self.acc += (base + k * min(220.0, speed)) * DT
        rng = self.rng(i)
        while self.acc >= 1.0:
            self.acc -= 1.0
            self.spawn(rng, tip, P)
        if e == "elec":  # uçta sürekli elektrik
            self.arc_t -= DT
            if self.arc_t <= 0.0:
                r2 = self.rng(i, 3)
                self.arc_t = r2.uniform(0.04, 0.08) if v != "B" else r2.uniform(0.06, 0.1)
                if v == "B":
                    pts = zigzag(r2, 4, (2.5, 4.5), 0.65, r2.uniform(0, 2 * math.pi))
                    br = None
                    if r2.random() < 0.7:
                        j = 2
                        bx, by = pts[j]
                        br = [(bx, by)] + [(bx + px, by + py) for px, py in zigzag(r2, 2, (1.6, 2.6), 0.6, r2.uniform(0, 6.28))[1:]]
                    self.ps.append({"k": "bolt", "rel": True, "pts": pts, "br": br, "age": 0.0, "life": r2.uniform(0.06, 0.1)})
                else:
                    pts = zigzag(r2, r2.choice([3, 4]), (2.0, 3.4), 0.8, r2.uniform(0, 2 * math.pi))
                    self.ps.append({"k": "crack", "rel": True, "pts": pts, "age": 0.0, "life": 0.07})

    def spawn(self, rng, tip, P):
        e, v = self.elem, self.var
        x = tip[0] + rng.uniform(-1.2, 1.2) * TX
        y = tip[1] + rng.uniform(-1.2, 1.2) * TX
        p = {"x": x, "y": y, "age": 0.0, "ph": rng.uniform(0, 6.283)}
        if v == "C":
            p.update(k="pour", gx=x, gy=P[1] + FEET + rng.uniform(-2.5, 2.5), vx=rng.uniform(-6.0, 6.0), vh=rng.uniform(-4.0, 10.0),
                     landed=False, bounced=False, land_life=rng.uniform(0.3, 0.5) if e != "elec" else rng.uniform(0.18, 0.28))
            p["h"] = p["gy"] - y
            self.ps.append(p)
            return
        if v == "A":
            if e == "fire":
                p.update(k="ember", vx=rng.uniform(-6, 6), vy=rng.uniform(-26, -14), life=rng.uniform(*A_LIFE[A_MODE]["ember"]), big=rng.random() < 0.25)
            elif e == "ice":
                p.update(k="frost", vx=rng.uniform(-5, 5), vy=rng.uniform(4, 12), life=rng.uniform(*A_LIFE[A_MODE]["frost"]), glint=rng.random() < 0.4)
            elif e == "arc":
                p.update(k="mote", vx=rng.uniform(-5, 5), vy=rng.uniform(-10, -3), life=rng.uniform(*A_LIFE[A_MODE]["mote"]), dia=rng.random() < 0.35)
            else:
                a = rng.uniform(-math.pi * 0.95, -math.pi * 0.05)  # yukarı yarım
                sp = rng.uniform(14, 30)
                p.update(k="spark", vx=math.cos(a) * sp, vy=math.sin(a) * sp, g=95.0, life=rng.uniform(*A_LIFE[A_MODE]["spark"]))
        else:  # B
            if e == "fire":
                p.update(k="flame", vx=rng.uniform(-4, 4), vy=rng.uniform(-28, -16), life=rng.uniform(0.45, 0.65), h0=rng.choice([5, 6, 5, 7]))
            elif e == "ice":
                p.update(k="shard", vx=rng.uniform(-12, 12), vy=rng.uniform(-16, -6), g=75.0, life=rng.uniform(0.55, 0.8),
                         q0=rng.randrange(4), spin=rng.choice([-1, 1]), sz=rng.choice([(5, 3), (5, 3), (6, 4), (4, 3)]))
                if rng.random() < 0.4:
                    self.ps.append({"k": "tw", "x": x + rng.uniform(-3, 3), "y": y + rng.uniform(-3, 3), "age": 0.0, "life": 0.3})
            elif e == "arc":
                p.update(k="star", vx=rng.uniform(-6, 6), vy=rng.uniform(-14, -6), life=rng.uniform(0.5, 0.75), r0=rng.choice([2, 3, 2]))
                if rng.random() < 0.35:
                    self.ps.append({"k": "rune", "x": x, "y": y, "age": 0.0, "life": 0.45})
            else:
                a = rng.uniform(-math.pi * 0.95, -math.pi * 0.05)
                sp = rng.uniform(16, 34)
                p.update(k="bead", vx=math.cos(a) * sp, vy=math.sin(a) * sp, g=120.0, life=rng.uniform(0.28, 0.42))
        self.ps.append(p)

    # ---- yıldırım isabeti (yaratık gövdesi: merkez c, elips rx, ry; ayak gy)
    def emit_hit(self, i, c, rx, ry, gy):
        v = self.var
        rate = {"A": 10.0, "B": 9.0, "C": 10.0}[v]
        self.hit_acc += rate * DT
        rng = self.rng(i, 11)
        while self.hit_acc >= 1.0:
            self.hit_acc -= 1.0
            a = rng.uniform(0, 2 * math.pi)
            x, y = c[0] + math.cos(a) * rx, c[1] + math.sin(a) * ry
            if v == "A":
                sp = rng.uniform(22, 40)
                self.ps.append({"k": "spark", "x": x, "y": y, "vx": math.cos(a) * sp, "vy": math.sin(a) * sp * 0.6 - 16.0, "g": 110.0,
                                "age": 0.0, "life": rng.uniform(0.28, 0.42)})
            elif v == "B":
                x, y = c[0] + math.cos(a) * rx * rng.uniform(0.3, 0.9), c[1] + math.sin(a) * ry * rng.uniform(0.3, 0.9)
                pts = zigzag(rng, 3, (1.6, 2.6), 0.9, rng.uniform(0, 6.28))
                self.ps.append({"k": "crack", "rel": False, "x": x, "y": y, "pts": pts, "age": 0.0, "life": rng.uniform(0.07, 0.1),
                                "bright": True})
                if rng.random() < 0.6:
                    sp = rng.uniform(14, 26)
                    self.ps.append({"k": "bead", "x": x, "y": y, "vx": math.cos(a) * sp, "vy": -abs(math.sin(a)) * sp - 6.0, "g": 110.0,
                                    "age": 0.0, "life": rng.uniform(0.25, 0.38)})
            else:
                self.ps.append({"k": "pour", "x": x, "y": y, "gx": x + math.cos(a) * 2.0, "gy": gy + rng.uniform(-1.5, 2.5),
                                "vx": math.cos(a) * rng.uniform(8, 18), "vh": rng.uniform(6.0, 18.0), "landed": False, "bounced": False,
                                "land_life": rng.uniform(0.18, 0.28), "age": 0.0, "ph": 0.0, "h": max(1.0, gy - y), "force_elec": True})

    # ---- ilerletme
    def update(self):
        keep = []
        for p in self.ps:
            p["age"] += DT
            k = p["k"]
            if k == "pour":
                if not p["landed"]:
                    p["vh"] -= 200.0 * DT
                    p["h"] += p["vh"] * DT
                    p["gx"] += p["vx"] * DT
                    if p["h"] <= 0.0:
                        p["h"] = 0.0
                        if (self.elem == "elec" or p.get("force_elec")) and not p["bounced"]:
                            p["vh"] = -p["vh"] * 0.38
                            p["vx"] *= 0.6
                            p["bounced"] = True
                        else:
                            p["landed"] = True
                            p["land_t"] = p["age"]
                    if p["age"] > 3.0:
                        continue
                elif p["age"] - p["land_t"] > p["land_life"]:
                    continue
                keep.append(p)
                continue
            if p["age"] >= p["life"]:
                continue
            if "vx" in p:
                vx, vy = p["vx"], p["vy"]
                if k == "ember":
                    vx += math.sin(p["age"] * 9.0 + p["ph"]) * 5.0
                    p["vy"] *= (1.0 - 0.8 * DT)
                elif k == "mote":
                    vx += math.cos(p["age"] * 6.0 + p["ph"]) * 9.0
                    vy += math.sin(p["age"] * 6.0 + p["ph"]) * 5.0
                elif k == "star":
                    vx += math.cos(p["age"] * 5.0 + p["ph"]) * 7.0
                elif k == "flame":
                    p["vy"] *= (1.0 - 0.6 * DT)
                p["x"] += vx * DT
                p["y"] += vy * DT
                if "g" in p:
                    p["vy"] += p["g"] * DT
            keep.append(p)
        self.ps = keep

    # ---- çizim
    def draw(self, air, ground, tip):
        for p in self.ps:
            k = p["k"]
            if k == "pour":
                self._draw_pour(p, air, ground)
                continue
            f = p["age"] / p["life"]
            if p.get("rel"):
                ox, oy = air.tc(tip[0], tip[1])
            elif "pts" in p:
                ox, oy = air.tc(p["x"], p["y"])
            else:
                x, y = air.tc(p["x"], p["y"])
            if k == "ember":
                i = min(4, int((f ** 1.5) * 5.0))
                if p["big"] and f < 0.35:
                    air.plus(x, y, 1, FIRE[0], FIRE[2], 1.0)
                else:
                    air.put(x, y, FIRE[i], 1.0 if f < 0.8 else 0.75)
                    if f < 0.55:
                        air.put(x, y + 1, FIRE[min(4, i + 1)], 0.75)
            elif k == "frost":
                if p["glint"]:
                    r = [0, 1, 2, 1, 0][min(4, int(f * 5.0))]
                    air.plus(x, y, r, ICE[0], ICE[1 + min(2, int(f * 3.0))], 1.0 if f < 0.8 else 0.75)
                else:
                    air.put(x, y, ICE[min(3, int(f * 3.0))], 1.0 if f < 0.75 else 0.5)
                    if f < 0.45:
                        air.put(x + 1, y, ICE[1], 0.75)
            elif k == "mote":
                i = min(4, int(f * 5.0))
                if p["dia"] and f < 0.7:
                    air.plus(x, y, 1, ARC[max(0, i - 1)], ARC[min(4, i + 1)], 1.0)
                else:
                    air.put(x, y, ARC[i], 1.0 if f < 0.8 else 0.75)
                    if f < 0.5:
                        air.put(x, y + 1, ARC[min(4, i + 2)], 0.75)
            elif k == "spark":
                i = min(3, int(f * 4.0))
                L = math.hypot(p["vx"], p["vy"]) + 1e-6
                tl = 3 if f < 0.5 else 2 if f < 0.8 else 1
                x1 = x - int(round(p["vx"] / L * tl))
                y1 = y - int(round(p["vy"] / L * tl))
                air.line(x1, y1, x, y, ELEC[min(3, i + 1)], 0.75)
                air.put(x, y, ELEC[i], 1.0)
            elif k == "flame":
                h = int(round(p["h0"] * (1.0 - f * 0.8)))
                wob = int(round(math.sin(p["age"] * 22.0 + p["ph"]) * 0.6))
                if f > 0.78:
                    air.put(x, y - 1, SMOKE, 0.5)
                    air.put(x + 1, y - 1, SMOKE, 0.25)
                    air.put(x, y, FIRE[4], 0.75)
                elif h >= 3:
                    m = flame_mask(h)
                    cols = [FIRE[4], FIRE[3], FIRE[2], FIRE[1]] if f < 0.4 else [FIRE[4], FIRE[3], FIRE[2]]
                    air.mask(m, x - m.shape[1] // 2 + wob, y - h + 1, cols, 1.0, light=(0, 1, FIRE[0]) if f < 0.3 else None)
                else:
                    air.put(x, y, FIRE[2], 1.0)
                    air.put(x, y - 1, FIRE[3], 0.75)
            elif k == "shard":
                if f > 0.82:
                    air.plus(x, y, 1, ICE[0], ICE[2], 0.75)
                else:
                    q = (p["q0"] + p["spin"] * int(p["age"] / 0.09)) % 4
                    L_, W_ = p["sz"]
                    if f > 0.6:
                        L_, W_ = max(2, L_ - 1), max(2, W_ - 1)
                    m = rhombus_mask(L_, W_, q)
                    air.mask(m, x - m.shape[1] // 2, y - m.shape[0] // 2, [ICE_OL, ICE[3], ICE[1]], 1.0, light=(-0.5, -0.5, ICE[0]))
            elif k == "tw":
                r = [1, 2, 3, 2, 1][min(4, int(f * 5.0))]
                air.plus(x, y, r, ICE[0], [ICE[1], ICE[2], ICE[3]], 1.0 if f < 0.8 else 0.75)
            elif k == "star":
                r = max(1, int(round(p["r0"] * math.sin(math.pi * min(1.0, f * 1.1)))))
                diag = int(p["age"] / 0.08) % 2 == 1
                rr = r if not diag else max(1, r - 1)
                arms = [ARC[1], ARC[2], ARC[3]] if f < 0.6 else [ARC[2], ARC[3], ARC[4]]
                air.plus(x, y, rr, ARC[0] if f < 0.6 else ARC[1], arms, 1.0 if f < 0.8 else 0.75, diag=diag)
            elif k == "rune":
                r = 1 + int(f * 3.0)
                col = ARC[2] if f < 0.5 else ARC[3]
                a = 1.0 if f < 0.5 else 0.75 if f < 0.8 else 0.5
                for d in range(-r, r + 1):
                    e = r - abs(d)
                    air.put(x + d, y + e, col, a)
                    air.put(x + d, y - e, col, a)
            elif k == "bead":
                i = min(3, int(f * 4.0))
                L = math.hypot(p["vx"], p["vy"]) + 1e-6
                ux, uy = p["vx"] / L, p["vy"] / L
                air.line(x - int(round(ux * 3)), y - int(round(uy * 3)), x, y, ELEC[min(3, i + 2)], 0.5 if f > 0.5 else 0.75)
                air.line(x - int(round(ux * 1.6)), y - int(round(uy * 1.6)), x, y, ELEC[min(3, i + 1)], 1.0)
                air.put(x, y, ELEC[0] if f < 0.5 else ELEC[1], 1.0)
                if f < 0.4:
                    air.put(x + 1, y, ELEC[1], 0.75)
            elif k in ("crack", "bolt"):
                self._draw_bolt(air, ox, oy, p, f)

    def _draw_bolt(self, air, ox, oy, p, f):
        pts = [(ox + int(round(px)), oy + int(round(py))) for px, py in p["pts"]]  # ofsetler zaten partikül pikseli
        lines = [pts]
        if p.get("br"):
            lines.append([(ox + int(round(px)), oy + int(round(py))) for px, py in p["br"]])
        if p["k"] == "bolt":
            for ln in lines:  # parıltı: çekirdeğin çevresine koyu altın
                for (x0, y0), (x1, y1) in zip(ln, ln[1:]):
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        air.line(x0 + dx, y0 + dy, x1 + dx, y1 + dy, ELEC[3], 0.5)
            for ln in lines:
                for (x0, y0), (x1, y1) in zip(ln, ln[1:]):
                    air.line(x0, y0, x1, y1, ELEC[2], 1.0)
            for ln in lines:
                for (x0, y0), (x1, y1) in zip(ln, ln[1:]):
                    air.line(x0, y0, x1, y1, ELEC[0] if f < 0.6 else ELEC[1], 1.0)
                air.put(ln[0][0], ln[0][1], ELEC[0], 1.0)
        else:
            col = ELEC[0] if p.get("bright") else ELEC[1]
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                air.line(x0, y0, x1, y1, ELEC[2], 0.75)
            for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:-1] + [pts[-1]]):
                air.line(x0, y0, x1, y1, col, 1.0, skip_last=True)

    def _draw_pour(self, p, air, ground):
        e = "elec" if p.get("force_elec") else self.elem
        if not p["landed"]:
            x, y = air.tc(p["gx"], p["gy"] - p["h"])
            falling = p["vh"] < 0.0
            ty = -1 if falling else 1  # kuyruk hareketin tersine
            if e == "fire":
                air.put(x, y, FIRE[0], 1.0)
                air.put(x + 1, y, FIRE[1], 1.0)
                air.put(x, y + ty, FIRE[2], 1.0)
                air.put(x, y + 2 * ty, FIRE[3], 0.75)
            elif e == "ice":
                tw = int(p["age"] / 0.1 + p["ph"]) % 3 == 0
                if tw:
                    air.plus(x, y, 1, ICE[0], ICE[2], 1.0)
                else:
                    air.put(x, y, ICE[0], 1.0)
                    air.put(x + 1, y, ICE[1], 1.0)
                air.put(x, y + ty, ICE[2], 0.75)
                air.put(x, y + 2 * ty, ICE[3], 0.5)
            elif e == "arc":
                sw = int(round(math.sin(p["age"] * 8.0 + p["ph"]) * 0.7))
                air.put(x + sw, y, ARC[0], 1.0)
                air.put(x + sw + 1, y, ARC[2], 1.0)
                air.put(x + sw, y + ty, ARC[2], 0.75)
                air.put(x + sw, y + 2 * ty, ARC[3], 0.5)
            else:
                vx, vy = p["vx"], -p["vh"]
                L = math.hypot(vx, vy) + 1e-6
                air.line(x - int(round(vx / L * 3)), y - int(round(vy / L * 3)), x, y, ELEC[2], 0.75)
                air.put(x, y, ELEC[0], 1.0)
                air.put(x + 1, y, ELEC[1], 0.75)
            return
        la = (p["age"] - p["land_t"]) / p["land_life"]
        x, y = ground.tc(p["gx"], p["gy"])
        a = 1.0 if la < 0.5 else 0.75 if la < 0.8 else 0.5
        if e == "fire":
            if la < 0.4:
                ground.plus(x, y, 1, FIRE[1], FIRE[3], a)
            else:
                ground.put(x, y, FIRE[3] if la < 0.7 else FIRE[4], a)
                ground.put(x + 1, y, FIRE[4], a * 0.75)
            if 0.2 < la < 0.9:
                air.put(x, y - 1 - int(la * 8.0), SMOKE, 0.5 if la < 0.6 else 0.25)
        elif e == "ice":
            if la < 0.55:
                ground.plus(x, y, 1, ICE[0], ICE[2], a)
            else:
                ground.put(x, y, ICE[3], 0.5)
        elif e == "arc":
            r = 1 + int(la * 2.0)
            col = ARC[2] if la < 0.5 else ARC[3]
            for d in range(-r, r + 1):
                ee = r - abs(d)
                ground.put(x + d, y + ee, col, a * 0.85)
                ground.put(x + d, y - ee, col, a * 0.85)
        else:
            if la < 0.35:
                ground.plus(x, y, 1, ELEC[0], ELEC[2], a)
            else:
                ground.put(x, y, ELEC[1] if la < 0.65 else ELEC[3], a)


# ------------------------------------------------------------------ yürüyüş sahnesi
WALK_PATH = [(0.40, None), (1.00, (1, 0)), (0.40, None), (0.50, (0, -1)), (1.00, (-1, 0)), (0.50, (0, 1))]
WALK_START = (250.0, 215.0)
WALK_TRACK, WALK_LOOP = make_track(WALK_PATH, WALK_START)
WALK_VIEW = (WALK_START[0] - 54.0, WALK_START[1] - 41.0 - 100.0, WALK_START[0] + 82.0 + 54.0, WALK_START[1] + 34.0)


def bg_crop(z, view):
    G = T.ground(z)
    x0, y0 = int(round(view[0] * z)), int(round(view[1] * z))
    w, h = int(round((view[2] - view[0]) * z)), int(round((view[3] - view[1]) * z))
    return G[y0:y0 + h, x0:x0 + w].astype(np.float32).copy()


def draw_char(F, z, view, st):
    def S(p):
        return ((p[0] - view[0]) * z, (p[1] - view[1]) * z)
    P = st["P"]
    sx, sy = S((P[0], P[1] + 12.0))
    ellipse(F, sx, sy, 9.0 * z, 3.5 * z, (0, 0, 0), 0.32)
    fr = T.char_frame(st["moving"], st["face"], st["walk_t"], st["t"])
    sx, sy = S((P[0], P[1] + CHAR_OFF_Y))
    blit2(F, fr, sx, sy, CHAR_K * z)


def draw_staff(F, z, view, key, pos, rot, P):
    def S(p):
        return ((p[0] - view[0]) * z, (p[1] - view[1]) * z)
    rx, ry = T.cur_shadow_radii(key, 0.0)
    gx, gy = S((pos[0], P[1] + FEET))
    ellipse(F, gx, gy, rx * z, ry * z, (0, 0, 0), 0.32 * 0.4)
    x, y = S(pos)
    blit2(F, icon_np(key), x, y, WPP * z, rot)


def run_walk(key, elem, var, z, view, want_frames=True, at_times=None):
    """3 tur simüle eder, 3. turu çizer (partiküller dikişsiz). Dönen: kare listesi (PIL) ya da at_times anları."""
    eidx = [s[2] for s in STAFFS].index(elem)
    em = Emitter(elem, var, 31 + eidx * 10 + "ABC".index(var))
    fo = Follow(key)
    n = len(WALK_TRACK)
    frames, snaps = [], {}
    prev_tip = None
    for lap in range(3):
        em.acc = 0.0
        for i in range(n):
            st = WALK_TRACK[i]
            pos, rot, tip = fo.step(st)
            sp = 0.0 if prev_tip is None else math.hypot(tip[0] - prev_tip[0], tip[1] - prev_tip[1]) / DT
            prev_tip = tip
            em.update()
            em.emit_tip(i, tip, st["P"], sp)
            if lap < 2:
                continue
            want = (want_frames and i % STEP_OUT == 0)
            hit_t = at_times is not None and any(abs(st["t"] - a) < DT * 0.5 for a in at_times)
            if not (want or hit_t):
                continue
            F = bg_crop(z, view)
            gnd = Layer(view[0], view[1], view[2] - view[0], view[3] - view[1])
            air = Layer(view[0], view[1], view[2] - view[0], view[3] - view[1])
            em.draw(air, gnd, tip)
            gnd.composite(F, z)
            draw_char(F, z, view, st)
            draw_staff(F, z, view, key, pos, rot, st["P"])
            air.composite(F, z)
            im = Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")
            if want:
                frames.append(im)
            if hit_t:
                snaps[round(st["t"], 3)] = (im, tip)
    return frames if at_times is None else snaps


def tile_label(im, title, sub=None):
    d = ImageDraw.Draw(im)
    label(d, 6, 4, title, 12)
    if sub:
        label(d, 6, 19, sub, 10, (226, 220, 204))
    return im


def hstack(parts, gap=4, bg=(18, 20, 20)):
    W = sum(p.width for p in parts) + gap * (len(parts) - 1)
    H = max(p.height for p in parts)
    im = Image.new("RGB", (W, H), bg)
    x = 0
    for p in parts:
        im.paste(p, (x, 0))
        x += p.width + gap
    return im


def build_walk():
    os.makedirs(OUT, exist_ok=True)
    for key, name, elem in STAFFS:
        lanes = []
        for vid, title, sub in VARIANTS:
            fr = run_walk(key, elem, vid, 2, WALK_VIEW)
            lanes.append([tile_label(f, title, sub) for f in fr])
            print(key, vid, len(fr))
        frames = []
        n = len(lanes[0])
        for i in range(n):
            row = hstack([ln[i] for ln in lanes])
            hd = header(row.width, "%s · uç partikülleri (prototip, oyuna bağlı değil)" % name,
                        "1080p oyun ölçeği · HÜCUM takibi, uç gidiş yönüne · partiküller dünyada kalır (kamera sabit) · ŞU AN: uçta partikül yok")
            frames.append(stack_v([hd, row], 0))
        save_gif(frames, os.path.join(OUT, "asa_%s.gif" % key), FPS_OUT, [0, n // 4, n // 2, 3 * n // 4])


# ------------------------------------------------------------------ yıldırım isabeti sahnesi
BEAM_PATH = [(0.55, None), (0.45, (0, -1)), (0.55, None), (0.45, (0, 1)), (0.80, None)]
BEAM_START = (300.0, 200.0)
BEAM_TRACK, BEAM_LOOP = make_track(BEAM_PATH, BEAM_START)
SLIME_C = (BEAM_START[0] + 124.0, BEAM_START[1] - 6.0)  # yaratık merkezi (ışının hedefi)
BEAM_VIEW = (BEAM_START[0] - 52.0, BEAM_START[1] - 37.0 - 96.0, BEAM_START[0] + 160.0, BEAM_START[1] + 34.0)
_BOLT = None


def bolt_tiles():
    global _BOLT
    if _BOLT is None:
        _BOLT = asset("assets/fx/lightning_staff/bolt_tiles.png")
    return _BOLT


def sheet_frame(path, i, w, h):
    return np.asarray(asset(path, (i * w, 0, i * w + w, h)), dtype=np.float32)


def beam_strip(L, codes):
    """lightning_strip.gd draw: 24x15 karolar, 6 varyant, >=6 dikey aynalı; 1 sanat px = 1 dünya px."""
    n = int(math.ceil(L / 24.0))
    im = Image.new("RGBA", (max(1, int(math.ceil(L))), 15), (0, 0, 0, 0))
    src = bolt_tiles()
    for i in range(n):
        w = int(min(24.0, L - 24.0 * i))
        if w <= 0:
            break
        code = codes[i % len(codes)]
        tile = src.crop(((code % 6) * 24, 0, (code % 6) * 24 + w, 15))
        if code >= 6:
            tile = tile.transpose(Image.FLIP_TOP_BOTTOM)
        im.paste(tile, (i * 24, 0), tile)
    return np.asarray(im, dtype=np.float32)


def run_beam(var, z, view, want_frames=True, at_times=None):
    em = None if var == "cur" else Emitter("elec", var, 77 + "ABC".index(var))
    fo = Follow("lightning_staff", ang=0.0)
    n = len(BEAM_TRACK)
    frames, snaps = [], {}
    prev_tip = None
    codes = [0, 7, 2, 9]
    for lap in range(3):
        if em:
            em.acc = 0.0
            em.hit_acc = 0.0
        for i in range(n):
            st = BEAM_TRACK[i]
            pos, rot, tip = fo.step(st, aim=SLIME_C)
            sp = 0.0 if prev_tip is None else math.hypot(tip[0] - prev_tip[0], tip[1] - prev_tip[1]) / DT
            prev_tip = tip
            if i % 3 == 0:  # FLICKER_INTERVAL 0,05 sn
                r = random.Random(500 + i)
                codes = [r.randrange(6) + (6 if r.random() < 0.5 else 0) for _ in range(9)]
            if em:
                em.update()
                em.emit_tip(i, tip, st["P"], sp)
                em.emit_hit(i, SLIME_C, 8.0, 5.5, SLIME_C[1] + 9.0)
            if lap < 2:
                continue
            want = (want_frames and i % STEP_OUT == 0)
            hit_t = at_times is not None and any(abs(st["t"] - a) < DT * 0.5 for a in at_times)
            if not (want or hit_t):
                continue
            t = st["t"]
            F = bg_crop(z, view)

            def S(p):
                return ((p[0] - view[0]) * z, (p[1] - view[1]) * z)
            gnd = Layer(view[0], view[1], view[2] - view[0], view[3] - view[1])
            air = Layer(view[0], view[1], view[2] - view[0], view[3] - view[1])
            if em:
                em.draw(air, gnd, tip)
            gnd.composite(F, z)
            # yaratık (+ isabet parlaması: HIT_FLASH 0,12 sn, en sık 0,4 sn)
            ex, ey = S((SLIME_C[0], SLIME_C[1] - 1.0))
            blit2(F, slime_frame(t), ex, ey, SLIME_K * z)
            fl = (t % 0.4) / 0.12
            if fl < 1.0:
                blit2(F, slime_frame(t), ex, ey, SLIME_K * z, alpha=0.8 * (1.0 - fl), tint=(255, 255, 255))
            draw_char(F, z, view, st)
            draw_staff(F, z, view, "lightning_staff", pos, rot, st["P"])
            # ışın (ŞU AN aynısı)
            L = math.hypot(SLIME_C[0] - tip[0], SLIME_C[1] - tip[1])
            ang = math.atan2(SLIME_C[1] - tip[1], SLIME_C[0] - tip[0])
            strip = beam_strip(L, codes)
            mx, my = (tip[0] + SLIME_C[0]) / 2.0, (tip[1] + SLIME_C[1]) / 2.0
            cx, cy = S((mx, my))
            blit2(F, strip, cx, cy, z, ang)
            fi = int(t * 16.0) % 8
            ix, iy = S(SLIME_C)
            blit2(F, sheet_frame("assets/fx/lightning_staff/impact_sheet.png", fi, 40, 40), ix, iy, z)
            oi = int(t * 12.0) % 6
            ox, oy = S(tip)
            blit2(F, sheet_frame("assets/fx/lightning_staff/orb_sheet.png", oi, 20, 20), ox, oy, z)
            air.composite(F, z)
            im = Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")
            if want:
                frames.append(im)
            if hit_t:
                snaps[round(t, 3)] = (im, tip)
    return frames if at_times is None else snaps


BEAM_TITLES = {"cur": ("ŞU AN (oyundaki)", "ışın + uçta top + hedefte çekirdek"),
               "A": ("A · Sade Toz", "uçta cızırtı + kıvılcım · isabette fırlayan çizgiler"),
               "B": ("B · Element Parçaları", "uçta dallanan şimşek · gövdede gezinen yay"),
               "C": ("C · Dökülen", "kıvılcımlar uçtan ve yaratıktan yere dökülüp seker")}


def build_beam():
    os.makedirs(OUT, exist_ok=True)
    lanes = {}
    for v in ("cur", "A", "B", "C"):
        fr = run_beam(v, 2, BEAM_VIEW)
        lanes[v] = [tile_label(f, *BEAM_TITLES[v]) for f in fr]
        print("beam", v, len(fr))
    frames = []
    n = len(lanes["cur"])
    for i in range(n):
        r1 = hstack([lanes["cur"][i], lanes["A"][i]])
        r2 = hstack([lanes["B"][i], lanes["C"][i]])
        hd = header(r1.width, "Yıldırım Asası · ışın, uç elektriği + isabet partikülleri (prototip, oyuna bağlı değil)",
                    "1080p oyun ölçeği · ışın / top / çekirdek oyunun kendi sayfaları · yeni partiküller altın-sarı (ışınla aynı palet)")
        frames.append(stack_v([hd, r1, r2], 4))
    save_gif(frames, os.path.join(OUT, "yildirim_isabet.gif"), FPS_OUT, [0, n // 3, 2 * n // 3])


# ------------------------------------------------------------------ özet + yakın
def build_ozet():
    os.makedirs(OUT, exist_ok=True)
    times = [0.95, 3.05]  # sağa yürürken (1. sn) ve sola dönüşte
    rows = []
    near = []
    for key, name, elem in STAFFS:
        tiles = []
        ntiles = []
        for vid, title, sub in VARIANTS:
            snaps = run_walk(key, elem, vid, 2, WALK_VIEW, want_frames=False, at_times=times)
            im, _ = snaps[round(times[0], 3)]
            tiles.append(tile_label(im.copy(), "%s · %s" % (name, title)))
            z = 4
            sn4 = run_walk(key, elem, vid, z, WALK_VIEW, want_frames=False, at_times=[times[0]])
            im4, tip = sn4[round(times[0], 3)]
            cx, cy = (tip[0] - WALK_VIEW[0]) * z, (tip[1] - WALK_VIEW[1]) * z
            crop = im4.crop((int(cx - 46 * z), int(cy - 22 * z), int(cx + 14 * z), int(cy + 30 * z)))
            ntiles.append(tile_label(crop, "%s · %s" % (name, vid)))
        rows.append(hstack(tiles))
        near.append(hstack(ntiles))
    im = stack_v([header(rows[0].width, "Asa uç partikülleri · özet (sağa yürürken, 1080p ölçek)", "A Sade Toz · B Element Parçaları · C Dökülen")] + rows, 4)
    im.save(os.path.join(OUT, "asa_ozet.png"))
    im2 = stack_v([header(near[0].width, "Asa uç partikülleri · x4 yakın (piksel ayrıntısı)", "partikül pikseli = karakter pikseli 0,903 dünya px")] + near, 4)
    im2.save(os.path.join(OUT, "asa_yakin.png"))
    print("ozet", im.size, im2.size)


def build_kisa():
    """A önceki (uzun kuyruk) / A kısa yan yana, 4 asa alt alta; + yıldırım ışını A kısa."""
    global A_MODE
    os.makedirs(OUT, exist_ok=True)
    rows = []
    for key, name, elem in STAFFS:
        cols = []
        for mode, title in (("uzun", "A · önceki (uzun kuyruk)"), ("kisa", "A · kısa kuyruk (oyuna giden)")):
            A_MODE = mode
            fr = run_walk(key, elem, "A", 2, WALK_VIEW)
            cols.append([tile_label(f, "%s · %s" % (name, title)) for f in fr])
        rows.append(cols)
        print("kisa", key)
    A_MODE = "kisa"
    frames = []
    n = len(rows[0][0])
    for i in range(n):
        parts = [header(rows[0][0][0].width * 2 + 4, "Asa uç partikülleri · A Sade Toz · kuyruk kısaltıldı (ömür ~%60)",
                        "1080p oyun ölçeği · solda önceki, sağda yeni · kamera sabit")]
        for r in rows:
            parts.append(hstack([r[0][i], r[1][i]]))
        frames.append(stack_v(parts, 4))
    save_gif(frames, os.path.join(OUT, "asa_A_kisa.gif"), FPS_OUT, [0, n // 4, n // 2, 3 * n // 4])


if __name__ == "__main__":
    if "kisa" in sys.argv[1:]:
        build_kisa()
        sys.exit(0)
    what = sys.argv[1:] or ["yuru", "isabet", "ozet"]
    if "ozet" in what:
        build_ozet()
    if "isabet" in what:
        build_beam()
    if "yuru" in what:
        build_walk()
