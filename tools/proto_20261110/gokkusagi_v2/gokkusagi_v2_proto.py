# -*- coding: utf-8 -*-
"""GÖKKUŞAĞI ASASI v2 görünüş PROTOTİPLERİ (2026-11-10, oyuna bağlı DEĞİL). Kullanıcı: "gökkuşağı asası isabet ettiği düşmanın etrafına
gökkuşağı ışınları saçarak yakınındaki düşmanlara yarısı kadar hasar versin ayrıca gökkuşağı asasının final formu da (içinden geçebilme
özelliği) görüş açısına kadar olacak şekilde dümdüz bir çizgi halinde loldeki lux ultisine benzer gökkuşağı tonlarında düz ve kalın bir
ışın olarak gönderilsin, bunların görünüşü için prototipler hazırla."

1) SAÇILMA (temel ışın, her 0,5 sn vuruşta): vurulan düşmandan 60 dünya px içindeki en çok 4 düşmana yarım hasar. Işının kendisi OYUNDAKİ
   (shaders/gokkusagi_isin.gdshader birebir, BASE_W 6), vuruş patlaması + parıltılar oyunun kendi sayfaları (assets/fx/gokkusagi/).
     A Kırılan Işınlar   - vurulandan komşulara dümdüz ince renkli ışın (her komşuya ayrı renk), uç önden gider kuyruk arkadan toplanır.
     B Işık Yıldızı     - vurulandan HER YÖNE 10 renkli ışık çizgisi saçılır; menzilde söner, komşuya denk gelen orada patlar.
     C Gökkuşağı Köprüsü - vurulandan her komşuya küçük ∩ gökkuşağı kemeri (4 bant) atlar, inişte krem bulutçuk.
     D Prizma Kıymıkları - vurulandan komşulara kavisle uçan elmas ışık kıymıkları, kısa renk izi, varışta 4 kollu yıldız.
2) FİNAL (Gökkuşağı Mızrağı): ışın hedef yönünde GÖRÜŞ ELİPSİNİN kenarına kadar (vision_fog.gd: yarıçap 250, yatayda x1,4 = 350;
   merkez oyuncu) dümdüz, kalın (yarı genişlik ~11 dünya px; bugün 8 + mızrak ucu, menzil 185), hattaki herkes delinir. Sis oyundaki
   formülle (FOG_TINT/DARKNESS/DESATURATION, kenar 0,14 yumuşak). Döngü: gönderiliş (0,12 sn) -> 0,5 sn vuruşlar -> bırakış.
     A Lux Huzmesi       - krem çekirdek + açık bant + doygun bant + yarı saydam dış hale; renk ışın boyunca uzun dilimlerle akar.
     B Prizma Yelpazesi  - asadan BEYAZ ince ışık çıkar, 40 px'de 6 bantlı tayfa açılır (üst kırmızı -> alt mor), bantlarda akan pırıltı.
     C Lux Atışı         - sürekli ince gökkuşağı hattı + HER VURUŞTA hat boyunca kalın tayf patlaması (Lux R gibi gönderilir, söner).
     D Halkalı Işın      - soluk krem kalın gövde + her vuruşta asadan uca koşan 3 renkli halka (ışını saran).
Ölçek: 1080p (zoom 2 -> 1 dünya px = 2 ekran px), ışın pikseli 1 dünya px, asa = oyundaki çizim assets/weapons/yeni/gokkusagi.png
(0,575 dünya px), karakter Şovalye, hedef Slime, asa HÜCUM tepe slotunda nişanlı (asa_partikul_proto.Follow).
Çıktılar out/: sacilma.gif (2x2), final.gif (2x2), ozet_sacilma.png, ozet_final.png (ilk satır ŞU AN).
Çalıştırma: python tools/proto_20261110/gokkusagi_v2/gokkusagi_v2_proto.py [sacilma|final|ozet]  (argümansız: hepsi)
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.normpath(os.path.join(HERE, "..", ".."))
ROOT = os.path.normpath(os.path.join(TOOLS, ".."))
sys.path.insert(0, os.path.join(TOOLS, "proto_20261019"))
import asa_partikul_proto as AP  # noqa: E402  (proto_20261017 + proto_20261016 yollarını da ekler)
import silah_takip_proto as T  # noqa: E402
from silah_takip_proto import blit2, slime_frame, SLIME_K  # noqa: E402
from bicak_proto import header, stack_v, save_gif  # noqa: E402
from gokkusagi_proto import beam_grid, lay_over, qa, RB, CREAM, RBL  # noqa: E402

OUT = os.path.join(HERE, "out")
KEY = "gokkusagi"
FPS = 25
TICK = 0.5
Z = 2
CR = tuple(float(v) for v in CREAM)


def C(c):
    return tuple(float(v) for v in c)


# ------------------------------------------------------------------ oyunun kendi dokuları
def _rgba(path):
    return np.asarray(Image.open(os.path.join(ROOT, path)).convert("RGBA"), dtype=np.float32)


def _load_staff():
    im = Image.open(os.path.join(ROOT, "assets/weapons/yeni/gokkusagi.png")).convert("RGBA")
    c = Image.new("RGBA", (48, 48))
    c.paste(im, ((48 - im.width) // 2, (48 - im.height) // 2))
    T.ICON_PX[KEY] = np.asarray(c, dtype=np.float32)


_load_staff()
_IMP = _rgba("assets/fx/gokkusagi/impact.png")
IMPACT = [_IMP[:, i * 25:(i + 1) * 25] for i in range(6)]
_SPK = _rgba("assets/fx/gokkusagi/sparkle.png")
SPARK = [[_SPK[r * 5:(r + 1) * 5, c * 5:(c + 1) * 5] for c in range(3)] for r in range(6)]


def ease_out(f):
    f = min(1.0, max(0.0, f))
    return 1.0 - (1.0 - f) ** 2


def clamp01(f):
    return min(1.0, max(0.0, f))


def lerp(a, b, f):
    return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)


# ------------------------------------------------------------------ BUGÜNKÜ ışın (shaders/gokkusagi_isin.gdshader birebir)
def beam_now(layer, p0, p1, t, W, spear=False):
    I, J, s, d, L = beam_grid(layer, p0, p1, W + 4.0)
    s = np.floor(s) + 0.5
    d = np.floor(d + 0.5)
    ad = np.abs(d)
    w = W * np.clip((s + 0.5) / max(5.0, W * 1.2), 0.35, 1.0)
    if spear:
        w = w * np.clip((L - s) / max(14.0, W * 2.8), 0.0, 1.0) ** 0.7
        inside = (s >= 0.0) & (s <= L) & (ad <= w + 0.15)
    else:
        inside = (s >= 0.0) & (((s <= L) & (ad <= w + 0.15)) | ((s > L) & (d * d + (s - L) ** 2 <= w * w)))
    h = np.mod(np.floor((s - t * 110.0) / 13.0), 6).astype(np.int32)
    core = ad < np.maximum(0.5, w * 0.22)
    mid = ad <= np.maximum(1.0, w * 0.58)
    rgb = np.where(core[:, None], CREAM, np.where(mid[:, None], RBL[h], RB[h]))
    a = np.where(inside, np.where(core | mid, 1.0, 0.5), 0.0)
    lay_over(layer, I, J, rgb.astype(np.float32), a.astype(np.float32))
    return L


class Sparks:
    """Işın yanında doğup ileri sürüklenen parıltı tanecikleri (fx_rainbow_beam.gd: 24/sn temel, genişliğin x0,5..x1,2 yanında)."""

    def __init__(self, seed, rate, W):
        self.rng = random.Random(seed)
        self.rate, self.W = rate, W
        self.p = []
        self.acc = 0.0

    def step(self, p0, p1, L, dt, on=True):
        ux, uy = (p1[0] - p0[0]) / L, (p1[1] - p0[1]) / L
        if on:
            self.acc += self.rate * dt
            while self.acc >= 1.0:
                self.acc -= 1.0
                ss = self.rng.uniform(6.0, max(8.0, L - 4.0))
                side = self.rng.choice((-1.0, 1.0))
                off = side * self.rng.uniform(0.5, 1.2) * self.W
                self.p.append([p0[0] + ux * ss - uy * off, p0[1] + uy * ss + ux * off, ux * 16.0 - uy * side * 7.0,
                               uy * 16.0 + ux * side * 7.0, 0.0, self.rng.uniform(0.32, 0.5), self.rng.randrange(6)])
        for q in self.p:
            q[0] += q[2] * dt
            q[1] += q[3] * dt
            q[4] += dt
        self.p = [q for q in self.p if q[4] < q[5]]

    def draw(self, F, view):
        for x, y, _, _, age, life, ci in self.p:
            col = min(2, int(age / life * 3.0))
            blit2(F, SPARK[ci][col], (x - view[0]) * Z, (y - view[1]) * Z, Z)


def draw_impact(F, view, pos, age, alpha=1.0, k=1.0):
    fi = int(age * 30.0)
    if 0 <= fi < 6:
        blit2(F, IMPACT[fi], (pos[0] - view[0]) * Z, (pos[1] - view[1]) * Z, Z * k, alpha=alpha)


def tip_flare(layer, tip, t):
    gx, gy = layer.tc(*tip)
    r = 2 if int(t * 15) % 2 == 0 else 1
    k = int(t * 6) % 6
    col = C(RBL[k])
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            layer.put(gx + dx, gy + dy, CR if dx == 0 or dy == 0 else col, 1.0 if dx == 0 or dy == 0 else 0.5)
    layer.plus(gx, gy, r + 1, CR, [col, col, col], 0.75)


# ------------------------------------------------------------------ sahne
def draw_world(F, view, slimes, flashes, st):
    """slimes: [(konum, tohum)], flashes: {indeks: (yaş, güç)} beyaz parlama. Y sırasıyla Şovalye + slime'lar."""
    t = st["t"]
    items = [(sp[1], "s", i) for i, (sp, _) in enumerate(slimes)] + [(st["P"][1], "c", -1)]
    for _, kind, i in sorted(items):
        if kind == "c":
            AP.draw_char(F, Z, view, st)
            continue
        sp, seed = slimes[i]
        ex, ey = (sp[0] - view[0]) * Z, (sp[1] - 1.0 - view[1]) * Z
        fr = slime_frame(t, seed)
        blit2(F, fr, ex, ey, SLIME_K * Z)
        if i in flashes:
            age, power = flashes[i]
            fl = age / 0.12
            if 0.0 <= fl < 1.0:
                blit2(F, fr, ex, ey, SLIME_K * Z, alpha=0.75 * power * (1.0 - fl), tint=(255, 255, 255))


FOG_TINT = np.array([0.02, 0.05, 0.12], np.float32) * 255.0
VISION_R = 250.0
VISION_X = 1.4
EDGE = 0.14


def fog_factor(view, P):
    W, H = int(round((view[2] - view[0]) * Z)), int(round((view[3] - view[1]) * Z))
    xs = view[0] + (np.arange(W) + 0.5) / Z
    ys = view[1] + (np.arange(H) + 0.5) / Z
    X, Y = np.meshgrid(xs, ys)
    n = np.hypot((X - P[0]) / (VISION_R * VISION_X), (Y - P[1]) / VISION_R)
    hb = EDGE * 0.5
    x = np.clip((n - (1.0 - hb)) / (2.0 * hb), 0.0, 1.0)
    return (x * x * (3.0 - 2.0 * x)).astype(np.float32)[..., None]


def apply_fog(F, fog):
    luma = (F[..., 0] * 0.299 + F[..., 1] * 0.587 + F[..., 2] * 0.114)[..., None]
    fogged = (F * 0.7 + luma * 0.3) * 0.68 + FOG_TINT * 0.32
    F[:] = F * (1.0 - fog) + fogged * fog


def vision_end(P, p0, ang):
    """p0'dan ang yönünde görüş elipsinin (merkez P) kenarı."""
    ux, uy = math.cos(ang), math.sin(ang)
    lo, hi = 0.0, 1200.0
    for _ in range(40):
        m = (lo + hi) * 0.5
        x, y = p0[0] + ux * m - P[0], p0[1] + uy * m - P[1]
        if math.hypot(x / (VISION_R * VISION_X), y / VISION_R) < 1.0:
            lo = m
        else:
            hi = m
    return (p0[0] + ux * lo, p0[1] + uy * lo)


# ================================================================== 1) SAÇILMA
SP_P = (300.0, 190.0)
S0 = (SP_P[0] + 120.0, SP_P[1] - 6.0)
NEIGH = [(S0[0] + 34.0, S0[1] - 34.0), (S0[0] + 46.0, S0[1] + 14.0), (S0[0] - 6.0, S0[1] + 42.0)]
OUTSIDE = (S0[0] + 92.0, S0[1] - 6.0)  # 92 px: menzil (60) dışında, saçılma almaz
SPLASH_R = 60.0
SP_VIEW = (255.0, 100.0, 535.0, 250.0)
SP_LOOP = 2.0
SP_T0 = 0.05  # vuruş anları SP_T0 + k x 0,5


class Splash:
    def __init__(self, did):
        self.did = did

    def ray_col(self, k, tick):
        return RB[(k * 2 + tick) % 6]

    def draw(self, air, F, view, age, tick, flashes):
        getattr(self, "_" + self.did)(air, F, view, age, tick, flashes)

    # --- A: kırılan dümdüz ışınlar
    def _A(self, air, F, view, age, tick, flashes):
        if age < 0.1:
            f = age / 0.1
            gx, gy = air.tc(*S0)
            ln = int(round(6.0 * (1.0 - f))) + 2
            for i in range(6):
                an = math.radians(i * 60.0 + 30.0)
                air.line(gx, gy, gx + int(round(math.cos(an) * ln)), gy + int(round(math.sin(an) * ln)), C(RBL[i]), 0.75)
            air.plus(gx, gy, 2, CR, [CR, CR], 1.0)
        for k, n in enumerate(NEIGH):
            col = self.ray_col(k, tick)
            d0 = math.hypot(n[0] - S0[0], n[1] - S0[1])
            ux, uy = (n[0] - S0[0]) / d0, (n[1] - S0[1]) / d0
            a0 = (S0[0] + ux * 5.0, S0[1] + uy * 5.0)
            hp = clamp01(age / 0.06)
            tp = clamp01((age - 0.12) / 0.08)
            if tp < 1.0:
                p0, p1 = lerp(a0, n, tp), lerp(a0, n, hp)
                I, J, s, d, L = beam_grid(air, p0, p1, 3.0)
                d = np.floor(d + 0.5)
                inside = (s >= -0.5) & (s <= L + 0.5) & (np.abs(d) <= 1.0)
                rgb = np.where((np.abs(d) < 0.5)[:, None], col * 0.45 + CREAM * 0.55, col)
                if hp < 1.0:  # önden giden uç krem
                    rgb = np.where((s > L - 2.0)[:, None], CREAM, rgb)
                lay_over(air, I, J, rgb.astype(np.float32), np.where(inside, 1.0, 0.0).astype(np.float32))
            ha = age - 0.06
            if 0.0 <= ha < 0.14:
                f = ha / 0.14
                gx, gy = air.tc(*n)
                air.plus(gx, gy, int(round(3.0 * (1.0 - f))) + 1, CR, [C(col), C(col), C(col * 0.8)], 1.0 if f < 0.5 else 0.75)
                flashes[k + 1] = (ha, 0.55)

    # --- B: her yöne saçılan ışık çizgileri
    def _B(self, air, F, view, age, tick, flashes):
        dirs = [math.radians(i * 36.0 + tick * 17.0) for i in range(10)]
        hit = {}
        for k, n in enumerate(NEIGH):
            an = math.atan2(n[1] - S0[1], n[0] - S0[0])
            j = min(range(10), key=lambda i: abs((dirs[i] - an + math.pi) % (2 * math.pi) - math.pi))
            dirs[j] = an
            hit[j] = (k, math.hypot(n[0] - S0[0], n[1] - S0[1]))
        if age < 0.12:
            f = age / 0.12
            r = 3.0 + 6.0 * f
            I, J, s, d, _ = beam_grid(air, S0, (S0[0] + 0.01, S0[1]), r + 2.0)
            rr = np.hypot(s, d)
            m = np.abs(rr - r) <= 0.6
            lay_over(air, I[m], J[m], np.tile(CREAM, (int(m.sum()), 1)).astype(np.float32),
                     np.full(int(m.sum()), float(qa(np.array([1.0 - f]))[0]), np.float32))
        f = clamp01(age / 0.22)
        head = 5.0 + (SPLASH_R - 5.0) * ease_out(f)
        for i, an in enumerate(dirs):
            col = RB[(i + tick) % 6]
            stop = SPLASH_R
            if i in hit:
                stop = hit[i][1]
            hd = min(head, stop)
            tl = max(5.0, hd - 12.0)
            al = 1.0 if f < 0.55 else (0.75 if f < 0.8 else 0.5)
            if i in hit and head >= stop:
                ha = (age - 0.22 * self._inv_ease((stop - 5.0) / (SPLASH_R - 5.0)))
                if ha < 0.14:
                    gx, gy = air.tc(*hit_pos(hit[i][0]))
                    ff = ha / 0.14
                    air.plus(gx, gy, int(round(4.0 * (1.0 - ff))) + 1, CR, [CR, C(col), C(col), C(col)], 1.0)
                    air.plus(gx, gy, max(1, int(round(3.0 * (1.0 - ff)))), CR, [C(col), C(col)], 0.75, diag=True)
                    flashes[hit[i][0] + 1] = (ha, 0.55)
                continue
            if f >= 1.0:
                continue
            ux, uy = math.cos(an), math.sin(an)
            p0 = (S0[0] + ux * tl, S0[1] + uy * tl)
            p1 = (S0[0] + ux * hd, S0[1] + uy * hd)
            I, J, s, d, L = beam_grid(air, p0, p1, 3.0)
            d = np.floor(d + 0.5)
            inside = (s >= -0.5) & (s <= L + 0.5) & (np.abs(d) <= 1.0)
            rgb = np.where((s > L - 3.0)[:, None], col * 0.4 + CREAM * 0.6, np.where((np.abs(d) < 0.5)[:, None], col * 0.6 + CREAM * 0.4, col))
            lay_over(air, I, J, rgb.astype(np.float32), np.where(inside, al, 0.0).astype(np.float32))

    @staticmethod
    def _inv_ease(y):
        y = clamp01(y)
        return 1.0 - math.sqrt(1.0 - y)

    # --- C: gökkuşağı köprüsü (∩ kemer)
    def _C(self, air, F, view, age, tick, flashes):
        bands = [RB[0], RB[2], RB[3], RB[4]]
        for k, n in enumerate(NEIGH):
            a0 = (S0[0], S0[1] - 7.0)
            a1 = (n[0], n[1] - 7.0)
            dist = math.hypot(a1[0] - a0[0], a1[1] - a0[1])
            mid = lerp(a0, a1, 0.5)
            ctrl = (mid[0], mid[1] - (0.55 * dist + 8.0))
            uh = ease_out(age / 0.14)
            ut = clamp01((age - 0.24) / 0.12)
            if ut >= 1.0:
                pass
            else:
                N = 260
                for i in range(N + 1):
                    u = i / N
                    if u < ut or u > uh:
                        continue
                    x = (1 - u) ** 2 * a0[0] + 2 * (1 - u) * u * ctrl[0] + u * u * a1[0]
                    y = (1 - u) ** 2 * a0[1] + 2 * (1 - u) * u * ctrl[1] + u * u * a1[1]
                    tx_ = 2 * (1 - u) * (ctrl[0] - a0[0]) + 2 * u * (a1[0] - ctrl[0])
                    ty_ = 2 * (1 - u) * (ctrl[1] - a0[1]) + 2 * u * (a1[1] - ctrl[1])
                    tl = math.hypot(tx_, ty_) or 1.0
                    nx, ny = ty_ / tl, -tx_ / tl  # dış (üst) yön
                    if ny > 0:
                        nx, ny = -nx, -ny
                    # uçlara doğru incelir (bulut ağzı)
                    taper = min(1.0, min(u, 1.0 - u) / 0.12)
                    nb = max(2, int(round(len(bands) * (0.5 + 0.5 * taper))))
                    for bi in range(nb):
                        o = (len(bands) - 1) * 0.5 - bi
                        gx, gy = air.tc(x + nx * o, y + ny * o)
                        air.put(gx, gy, C(bands[bi]), 1.0)
                    if abs(u - uh) < 1.5 / N and uh < 1.0:
                        gx, gy = air.tc(x, y)
                        air.plus(gx, gy, 2, CR, [CR, CR], 1.0)
            ha = age - 0.14
            if 0.0 <= ha < 0.3:
                f = ha / 0.3
                for j, (dx, dy, r) in enumerate(((0.0, 0.0, 3.2), (-4.0, 1.0, 2.4), (4.0, 1.0, 2.4), (0.0, -2.0, 2.2))):
                    c = (n[0] + dx * (1.0 + 0.5 * f), n[1] - 6.0 + dy - 3.0 * f)
                    rr = r * (1.0 - 0.6 * f)
                    I, J, s, d, _ = beam_grid(air, c, (c[0] + 0.01, c[1]), rr + 1.0)
                    m = np.hypot(s, d) <= rr
                    lay_over(air, I[m], J[m], np.tile(CREAM if j else CREAM * 0.94, (int(m.sum()), 1)).astype(np.float32),
                             np.full(int(m.sum()), 1.0 if f < 0.4 else (0.75 if f < 0.7 else 0.5), np.float32))
                if ha < 0.14:
                    flashes[k + 1] = (ha, 0.55)
            if age < 0.1:
                gx, gy = air.tc(*a0)
                air.plus(gx, gy, 2, CR, [CR, C(RBL[0])], 0.75)

    # --- D: prizma kıymıkları
    def _D(self, air, F, view, age, tick, flashes):
        if age < 0.08:
            f = age / 0.08
            r = 2.0 + 4.0 * f
            I, J, s, d, _ = beam_grid(air, (S0[0], S0[1] - 4.0), (S0[0] + 0.01, S0[1] - 4.0), r + 2.0)
            rr = np.hypot(s, d)
            m = np.abs(rr - r) <= 0.6
            lay_over(air, I[m], J[m], np.tile(CREAM, (int(m.sum()), 1)).astype(np.float32), np.full(int(m.sum()), 0.75, np.float32))
        FL = 0.16
        for k, n in enumerate(NEIGH):
            col = self.ray_col(k, tick)
            a0 = (S0[0], S0[1] - 4.0)
            a1 = (n[0], n[1] - 3.0)
            mid = lerp(a0, a1, 0.5)
            dx, dy = a1[0] - a0[0], a1[1] - a0[1]
            dl = math.hypot(dx, dy)
            side = 1.0 if k % 2 == 0 else -1.0
            ctrl = (mid[0] - dy / dl * 12.0 * side, mid[1] + dx / dl * 12.0 * side - 6.0)

            def at(u):
                return ((1 - u) ** 2 * a0[0] + 2 * (1 - u) * u * ctrl[0] + u * u * a1[0],
                        (1 - u) ** 2 * a0[1] + 2 * (1 - u) * u * ctrl[1] + u * u * a1[1])
            if age < FL:
                u = (age / FL) ** 1.4
                for j, lag in enumerate((0.05, 0.1, 0.16, 0.22, 0.28)):
                    uu = u - lag
                    if uu <= 0.0:
                        continue
                    gx, gy = air.tc(*at(uu))
                    if j < 2:
                        air.plus(gx, gy, 1, C(col * 0.5 + CREAM * 0.5), [C(col)], 1.0)
                    else:
                        air.put(gx, gy, C(col * 0.85), 0.75 if j < 4 else 0.5)
                p = at(u)
                q = at(max(0.0, u - 0.02))
                ang = math.atan2(p[1] - q[1], p[0] - q[0]) if u > 0.02 else math.atan2(dy, dx)
                I, J, s, d, _ = beam_grid(air, p, (p[0] + math.cos(ang) * 0.01, p[1] + math.sin(ang) * 0.01), 7.0)
                m = (np.abs(s) / 4.6 + np.abs(d) / 2.4) <= 1.0
                rgb = np.where((s > 1.8)[:, None], CREAM, np.where((d < 0.0)[:, None], col * 0.5 + CREAM * 0.5, np.where((s < -2.5)[:, None], col * 0.75, col)))
                lay_over(air, I[m], J[m], rgb[m].astype(np.float32), np.ones(int(m.sum()), np.float32))
            ha = age - FL
            if 0.0 <= ha < 0.16:
                f = ha / 0.16
                gx, gy = air.tc(*a1)
                air.plus(gx, gy, int(round(4.0 * (1.0 - f))) + 1, CR, [CR, C(col), C(col)], 1.0 if f < 0.6 else 0.75)
                air.plus(gx, gy, max(1, int(round(2.0 * (1.0 - f)))), CR, [C(col)], 0.75, diag=True)
                r = 2.0 + 5.0 * f
                I, J, s, d, _ = beam_grid(air, a1, (a1[0] + 0.01, a1[1]), r + 2.0)
                m = np.abs(np.hypot(s, d) - r) <= 0.55
                lay_over(air, I[m], J[m], np.tile(col, (int(m.sum()), 1)).astype(np.float32),
                         np.full(int(m.sum()), 0.75 if f < 0.5 else 0.5, np.float32))
                flashes[k + 1] = (ha, 0.55)


def hit_pos(k):
    return NEIGH[k]


SPLASH_INFO = {
    "A": ("A · Kırılan Işınlar", "vurulandan komşulara dümdüz ince renkli ışın"),
    "B": ("B · Işık Yıldızı", "her yöne 10 ışık çizgisi, menzilde söner"),
    "C": ("C · Gökkuşağı Köprüsü", "her komşuya küçük ∩ kemer, inişte bulutçuk"),
    "D": ("D · Prizma Kıymıkları", "kavisle uçan elmas kıymık + renk izi"),
}


def run_splash(did, want_times=None):
    sty = Splash(did) if did != "NOW" else None
    fo = AP.Follow(KEY, ang=0.0)
    st0 = {"t": 0.0, "P": SP_P, "V": (0.0, 0.0), "moving": False, "face": (1, 0), "walk_t": 0.0}
    spk = Sparks(77, 24.0, 6.0)
    slimes = [(S0, 0)] + [(n, i + 1) for i, n in enumerate(NEIGH)] + [(OUTSIDE, 4)]
    for _ in range(60):
        fo.step(dict(st0), aim=S0)
    n = int(round(SP_LOOP * FPS))
    dt = 1.0 / FPS
    frames, snaps = [], {}
    for lap in range(2):
        for i in range(n):
            t = i * dt
            st = dict(st0, t=t)
            pos, rot, tip = fo.step(st, aim=S0)
            L = max(1.0, math.hypot(S0[0] - tip[0], S0[1] - tip[1]))
            spk.step(tip, S0, L, dt)
            if lap == 0:
                continue
            want = want_times is None or any(abs(t - w) < dt * 0.5 for w in want_times)
            if not want:
                continue
            k = int(math.floor((t - SP_T0) / TICK)) if t >= SP_T0 else -1
            tick = k % 4
            age = t - (SP_T0 + k * TICK) if k >= 0 else t + (SP_LOOP - SP_T0 - 3 * TICK)
            F = AP.bg_crop(Z, SP_VIEW)
            flashes = {0: (age, 1.0)}
            air = AP.Layer(SP_VIEW[0], SP_VIEW[1], SP_VIEW[2] - SP_VIEW[0], SP_VIEW[3] - SP_VIEW[1], tx=1.0)
            fx = AP.Layer(SP_VIEW[0], SP_VIEW[1], SP_VIEW[2] - SP_VIEW[0], SP_VIEW[3] - SP_VIEW[1], tx=1.0)
            if sty is not None:
                sty.draw(fx, F, SP_VIEW, age, tick, flashes)
            draw_world(F, SP_VIEW, slimes, flashes, st)
            AP.draw_staff(F, Z, SP_VIEW, KEY, pos, rot, st["P"])
            beam_now(air, tip, S0, t, 6.0)
            tip_flare(air, tip, t)
            air.composite(F, Z)
            spk.draw(F, SP_VIEW)
            draw_impact(F, SP_VIEW, S0, age)
            fx.composite(F, Z)
            im = Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")
            if sty is None:
                title, sub = "ŞU AN", "saçılma yok (ışın ilk düşmanda durur)"
            else:
                title, sub = SPLASH_INFO[did]
            im = AP.tile_label(im, title, sub)
            if want_times is None:
                frames.append(im)
            else:
                snaps[round(t, 3)] = im
    return frames if want_times is None else snaps


# ================================================================== 2) FİNAL: görüşe kadar düz kalın ışın
FN_P = (150.0, 205.0)
FN_ANG = math.radians(7.0)
FN_VIEW = (100.0, 95.0, 560.0, 262.0)
FN_LOOP = 3.0
LAUNCH = 0.12
REL_T = 2.40
REL_D = 0.30
FN_W = 11.0
TICKS = [LAUNCH + k * TICK for k in range(5)]  # 0,12 0,62 1,12 1,62 2,12


def fn_slimes(tip):
    ux, uy = math.cos(FN_ANG), math.sin(FN_ANG)
    on = [(tip[0] + ux * dd, tip[1] + uy * dd + 4.0) for dd in (78.0, 150.0, 222.0, 296.0)]
    off = [(FN_P[0] + 186.0, FN_P[1] + 12.0)]
    return on, off


class Final:
    def __init__(self, did):
        self.did = did
        rate = {"NOW": 44.0, "A": 90.0, "A2": 90.0, "A3": 90.0, "A4": 90.0, "B": 0.0, "C": 60.0, "D": 0.0}[did]
        self.spk = Sparks(300 + len(did) * 7 + ord(did[0]), rate, 8.0 if did == "NOW" else FN_W * 0.9)

    @staticmethod
    def phase(t):
        if t < LAUNCH:
            return "launch", t / LAUNCH
        if t < REL_T:
            return "hold", 0.0
        if t < REL_T + REL_D:
            return "rel", (t - REL_T) / REL_D
        return "off", 0.0

    def draw(self, air, tip, end, t, Lfull):
        ph, f = self.phase(t)
        if ph == "off":
            return 0.0
        Lv = Lfull * ease_out(f) if ph == "launch" else Lfull
        endv = lerp(tip, end, Lv / Lfull)
        getattr(self, "_" + self.did)(air, tip, endv, t, ph, f, Lfull)
        return Lv

    # --- ŞU AN: bugünkü mızrak (menzil 185, FINAL_W 8, sivri uç)
    def _NOW(self, air, tip, end, t, ph, f, Lfull):
        if ph == "rel":
            return
        beam_now(air, tip, end, t, 8.0, spear=True)

    def _fade_end(self, s, Lfull):
        """Sise karışan son 28 px: saydamlık adımları."""
        e = np.clip((Lfull - s) / 28.0, 0.0, 1.0)
        return np.where(e > 0.75, 1.0, np.where(e > 0.5, 0.75, np.where(e > 0.25, 0.5, np.where(e > 0.0, 0.25, 0.0))))

    # --- A: Lux huzmesi
    def _A(self, air, tip, end, t, ph, f, Lfull):
        W = FN_W
        if ph == "rel":
            W = FN_W * (1.0 - ease_out(f))
            if W < 0.6:
                return
        I, J, s, d, L = beam_grid(air, tip, end, W + 3.0)
        s = np.floor(s) + 0.5
        d = np.floor(d + 0.5)
        w = W * np.clip((s + 0.5) / 16.0, 0.35, 1.0)
        if ph == "launch":
            w = w * np.clip((L - s) / 10.0, 0.0, 1.0) ** 0.5 + np.where(np.abs(s - L) < 6.0, 2.0, 0.0)
        u = np.abs(d) / np.maximum(w, 0.6)
        inside = (s >= 0.0) & (s <= L) & (np.abs(d) <= w + 0.15)
        x = (s - t * 160.0) / 40.0
        h0 = np.mod(np.floor(x), 6).astype(np.int32)
        fr = (np.floor((x - np.floor(x)) * 5.0) / 5.0)[:, None]
        hue = RB[h0] * (1.0 - fr) + RB[(h0 + 1) % 6] * fr
        rgb = np.where((u < 0.22)[:, None], CREAM, np.where((u < 0.5)[:, None], hue * 0.5 + CREAM * 0.5, hue))
        a = np.where(u < 0.22, 1.0, np.where(u < 0.85, 0.75, 0.5))
        g = np.mod(s - t * 260.0, 54.0) < 4.0
        rgb[g & (u < 0.85)] = rgb[g & (u < 0.85)] * 0.5 + CREAM * 0.5
        a = a * self._fade_end(s, Lfull)
        if ph == "launch":
            front = np.abs(s - L) < 5.0
            rgb[front] = rgb[front] * 0.3 + CREAM * 0.7
        lay_over(air, I, J, rgb.astype(np.float32), qa(np.where(inside, a, 0.0)).astype(np.float32))
        gx, gy = air.tc(*tip)
        rr = 5 if int(t * 12) % 2 == 0 else 4
        air.plus(gx, gy, rr, CR, [CR, CR, C(RBL[int(t * 6) % 6]), C(RB[int(t * 6) % 6]), C(RB[(int(t * 6) + 1) % 6])], 1.0 if ph != "rel" else 0.5)
        air.plus(gx, gy, 2, CR, [C(RBL[(int(t * 6) + 3) % 6])], 0.75, diag=True)

    # --- B: prizma yelpazesi
    def _B(self, air, tip, end, t, ph, f, Lfull):
        W = FN_W
        I, J, s, d, L = beam_grid(air, tip, end, W + 2.0)
        s = np.floor(s) + 0.5
        d = np.floor(d + 0.5)
        fan = np.clip((s - 12.0) / 30.0, 0.0, 1.0)
        fan_e = 1.0 - (1.0 - fan) ** 2
        w = 2.5 + (W - 2.5) * fan_e
        if ph == "rel":
            w = np.where(fan > 0, 2.5 + (w - 2.5) * (1.0 - ease_out(f)), w)
        inside = (s >= 0.0) & (s <= L) & (np.abs(d) <= w + 0.15)
        u = np.clip(d / np.maximum(w, 0.6), -0.999, 0.999)
        k = np.clip(np.floor((u + 1.0) * 0.5 * 6.0), 0, 5).astype(np.int32)
        mixf = np.floor(fan * 4.0) / 4.0
        band = RB[k] * mixf[:, None] + CREAM * (1.0 - mixf[:, None])
        # her bandın ortasından akan pırıltı (bant başına farklı hız)
        sp = np.array([170.0, 205.0, 150.0, 230.0, 185.0, 160.0], np.float32)[k]
        glint = (np.mod(s - t * sp + k * 17.0, 46.0) < 6.0) & (fan >= 1.0)
        band[glint] = band[glint] * 0.45 + CREAM * 0.55
        edge = np.abs(u) > 0.9
        a = np.where(fan < 0.5, 1.0, np.where(edge, 0.5, 0.75))
        a = a * self._fade_end(s, Lfull)
        if ph == "rel":
            a = a * (1.0 if f < 0.6 else (0.5 if f < 0.85 else 0.25))
        if ph == "launch":
            front = np.abs(s - L) < 4.0
            band[front] = band[front] * 0.3 + CREAM * 0.7
        lay_over(air, I, J, band.astype(np.float32), qa(np.where(inside, a, 0.0)).astype(np.float32))
        gx, gy = air.tc(*tip)
        air.plus(gx, gy, 3, CR, [CR, CR, C(CREAM * 0.9)], 1.0 if ph != "rel" else 0.5)

    # --- C: Lux atışı (ince hat + vuruşta kalın tayf patlaması)
    def _C(self, air, tip, end, t, ph, f, Lfull):
        # ince hat (bugünkü ışının dili, yarı genişlik 2,5)
        if ph != "rel" or f < 0.7:
            I, J, s, d, L = beam_grid(air, tip, end, 6.0)
            s = np.floor(s) + 0.5
            d = np.floor(d + 0.5)
            w = 2.5
            inside = (s >= 0.0) & (s <= L) & (np.abs(d) <= w + 0.15)
            h = np.mod(np.floor((s - t * 110.0) / 13.0), 6).astype(np.int32)
            rgb = np.where((np.abs(d) < 0.6)[:, None], CREAM, np.where((np.abs(d) <= 1.5)[:, None], RBL[h], RB[h]))
            a = np.where(np.abs(d) <= 1.5, 1.0, 0.5) * self._fade_end(s, Lfull)
            lay_over(air, I, J, rgb.astype(np.float32), qa(np.where(inside, a, 0.0)).astype(np.float32))
        # son vuruşun patlaması
        tk = [x for x in TICKS if x <= t]
        if not tk:
            return
        ba = t - tk[-1]
        if ba >= 0.32:
            return
        if ba < 0.04:
            wf = ba / 0.04
        elif ba < 0.10:
            wf = 1.0
        else:
            wf = 1.0 - (ba - 0.10) / 0.22
        W = FN_W * 1.2 * math.floor(wf * 5.0 + 0.999) / 5.0
        if W < 0.6:
            return
        reach = min(Lfull, ba * 3200.0)
        endb = lerp(tip, end, min(1.0, reach / max(1.0, math.hypot(end[0] - tip[0], end[1] - tip[1]))))
        I, J, s, d, L = beam_grid(air, tip, endb, W + 2.0)
        s = np.floor(s) + 0.5
        d = np.floor(d + 0.5)
        w = W * np.clip((s + 0.5) / 20.0, 0.3, 1.0)
        inside = (s >= 0.0) & (s <= L) & (np.abs(d) <= w + 0.15)
        u = np.clip(d / np.maximum(w, 0.6), -0.999, 0.999)
        k = np.clip(np.floor((u + 1.0) * 0.5 * 6.0), 0, 5).astype(np.int32)
        au = np.abs(u)
        rgb = np.where((au < 0.3)[:, None], CREAM, np.where((au < 0.5)[:, None], RB[k] * 0.5 + CREAM * 0.5, RB[k]))
        a = np.where(au < 0.3, 1.0, np.where(au > 0.86, 0.5, 0.75)) * self._fade_end(s, Lfull)
        if ba > 0.1:
            a = a * (1.0 if ba < 0.2 else 0.75)
        lay_over(air, I, J, rgb.astype(np.float32), qa(np.where(inside, a, 0.0)).astype(np.float32))
        gx, gy = air.tc(*tip)
        rr = int(round(6.0 * (1.0 - ba / 0.32))) + 2
        air.plus(gx, gy, rr, CR, [CR, CR, C(RB[2]), C(RB[1]), C(RB[0]), C(RB[0])], 1.0)
        air.plus(gx, gy, max(1, rr // 2), CR, [CR, C(RB[4])], 0.75, diag=True)

    # --- D: halkalı ışın
    def _D(self, air, tip, end, t, ph, f, Lfull):
        W = FN_W * 0.82
        if ph == "rel":
            W = W * (1.0 - ease_out(f))
            if W < 0.6:
                return
        I, J, s, d, L = beam_grid(air, tip, end, W + 8.0)
        s = np.floor(s) + 0.5
        d = np.floor(d + 0.5)
        w = W * np.clip((s + 0.5) / 14.0, 0.35, 1.0)
        u = np.abs(d) / np.maximum(w, 0.6)
        inside = (s >= 0.0) & (s <= L) & (np.abs(d) <= w + 0.15)
        h = np.mod(np.floor((s - t * 90.0) / 60.0), 6).astype(np.int32)
        pale = RB[h] * 0.3 + CREAM * 0.7
        rgb = np.where((u < 0.3)[:, None], CREAM, np.where((u < 0.8)[:, None], pale, RB[h]))
        a = np.where(u < 0.3, 1.0, 0.5) * self._fade_end(s, Lfull)
        lay_over(air, I, J, rgb.astype(np.float32), qa(np.where(inside, a, 0.0)).astype(np.float32))
        # halkalar: her vuruşta (ve gönderilişte) 3 renkli halka uca koşar
        rings = []
        for x in TICKS:
            ra = t - x
            if 0.0 <= ra < 0.6:
                for j in range(3):
                    pos = ra * 720.0 - j * 15.0
                    if 4.0 < pos < L - 4.0:
                        rings.append((pos, (TICKS.index(x) * 3 + j) % 6))
        Hr = FN_W * 0.82 + 6.0
        for pos, ci in rings:
            col = RB[ci]
            e = np.clip((Lfull - pos) / 40.0, 0.0, 1.0)
            al = 1.0 if e > 0.5 else (0.75 if e > 0.25 else 0.5)
            ring = np.abs(np.hypot((s - pos) / 3.2, d / Hr) - 1.0) <= 0.3
            front = ring & (s >= pos)
            back = ring & (s < pos)
            if back.any():
                lay_over(air, I[back], J[back], np.tile(col * 0.8, (int(back.sum()), 1)).astype(np.float32),
                         np.full(int(back.sum()), 0.5 * al, np.float32))
            if front.any():
                cc = np.where((np.abs(d[front]) < 2.0)[:, None], col * 0.4 + CREAM * 0.6, col)
                lay_over(air, I[front], J[front], cc.astype(np.float32), np.full(int(front.sum()), al, np.float32))
        gx, gy = air.tc(*tip)
        air.plus(gx, gy, 3, CR, [CR, C(RBL[int(t * 6) % 6]), C(RB[int(t * 6) % 6])], 1.0 if ph != "rel" else 0.5)

    # --- A2: A Lux Huzmesi + D'nin halkaları (kullanıcı: "uzun kalın ışın efekti için ise D nin koşan halkalarını A ya da eklemeni istiyorum")
    def _A2(self, air, tip, end, t, ph, f, Lfull):
        self._A(air, tip, end, t, ph, f, Lfull)
        k = 1.0 - ease_out(f) if ph == "rel" else 1.0
        if k > 0.05:
            self._rings(air, tip, end, t, Lfull, FN_W + 6.0, k, "random")

    # --- A4: A + BELİRGİN halka atışları (kullanıcı: "istediğim halka atışları hala görünmüyor A da?" - A2'nin 1-2 px halkaları ışının
    # kendi renkleriyle aynı tonda, gövdeye karışıyordu): kalın halka + koyu dış hat, ışının dışına daha çok taşar, 560 px/sn (daha uzun
    # görünür), fırlarken asada krem çıkış halkası; renkler A2 gibi rastgele ve farklı
    def _A4(self, air, tip, end, t, ph, f, Lfull):
        self._A(air, tip, end, t, ph, f, Lfull)
        k = 1.0 - ease_out(f) if ph == "rel" else 1.0
        if k > 0.05:
            self._rings_bold(air, tip, end, t, Lfull, FN_W + 9.0, k)

    def _rings_bold(self, air, tip, end, t, Lfull, Hr, k=1.0, speed=560.0, a_s=4.5):
        I, J, s, d, L = beam_grid(air, tip, end, Hr * 1.4 + 3.0)
        s = np.floor(s) + 0.5
        d = np.floor(d + 0.5)
        life = (Lfull + 40.0) / speed
        for x in TICKS:
            ra = t - x
            if not 0.0 <= ra < life:
                continue
            ti = TICKS.index(x)
            cols3 = self.ring_colors(ti)
            # asada çıkış halkası (ilk 0,1 sn)
            if ra < 0.1:
                fr = ra / 0.1
                rr = 4.0 + 9.0 * fr
                ring0 = np.abs(np.hypot(s / (rr * 0.45), d / rr) - 1.0) <= 0.22
                lay_over(air, I[ring0], J[ring0], np.tile(CREAM, (int(ring0.sum()), 1)).astype(np.float32),
                         np.full(int(ring0.sum()), float(qa(np.array([(1.0 - fr) * k]))[0]), np.float32))
            for j in range(3):
                pos = ra * speed - j * 18.0
                if not 6.0 < pos < L - 2.0:
                    continue
                col = RB[cols3[j]]
                e = np.clip((Lfull - pos) / 36.0, 0.0, 1.0)  # uçta sise karışarak söner
                al = (1.0 if e > 0.66 else (0.75 if e > 0.33 else 0.5)) * k
                r = np.hypot((s - pos) / a_s, d / Hr)
                band = np.abs(r - 1.0)
                core = band <= 0.3
                edge = (band > 0.3) & (band <= 0.55)
                front = s >= pos
                for m, rgb_of, a_mul in (
                        (edge & ~front, lambda n: np.tile(col * 0.35, (n, 1)), 0.5),
                        (core & ~front, lambda n: np.tile(col * 0.8, (n, 1)), 0.6),
                        (edge & front, lambda n: np.tile(col * 0.4, (n, 1)), 0.85),
                        (core & front, None, 1.0)):
                    if not m.any():
                        continue
                    n = int(m.sum())
                    if rgb_of is None:
                        rgb = np.where((np.abs(d[m]) < 3.0)[:, None], col * 0.35 + CREAM * 0.65, np.tile(col, (n, 1)))
                    else:
                        rgb = rgb_of(n)
                    lay_over(air, I[m], J[m], rgb.astype(np.float32), np.full(n, float(qa(np.array([al * a_mul]))[0]), np.float32))

    # --- A3: A + halkalar, her halka kendi içinde gökkuşağı (açıya göre 6 renk)
    def _A3(self, air, tip, end, t, ph, f, Lfull):
        self._A(air, tip, end, t, ph, f, Lfull)
        k = 1.0 - ease_out(f) if ph == "rel" else 1.0
        if k > 0.05:
            self._rings(air, tip, end, t, Lfull, FN_W + 6.0, k, "rainbow")

    @staticmethod
    def ring_colors(ti):
        """Kullanıcı: halkalar "rengarenk rasgele renkte" -> her vuruşta 3 halka rastgele, birbirinden farklı ve spektrumda yan yana
        olmayan renk (eskisi ardışık 3 renkti: sarı-turuncu-kırmızı gibi tek ton ailesi)."""
        rng = random.Random(4100 + ti * 37)
        while True:
            c = rng.sample(range(6), 3)
            if not any(set(c) == {a, (a + 1) % 6, (a + 2) % 6} for a in range(6)):  # ardışık üç ton (tek renk ailesi) değil
                return c

    def _rings(self, air, tip, end, t, Lfull, Hr, k=1.0, color_mode="seq"):
        """D'nin halkaları: her vuruşta (ve gönderilişte) asadan uca 720 px/sn koşan 3 renkli halka; arka yarı soluk (ışının arkası)."""
        I, J, s, d, L = beam_grid(air, tip, end, Hr * 1.35 + 2.0)
        s = np.floor(s) + 0.5
        d = np.floor(d + 0.5)
        for x in TICKS:
            ra = t - x
            if not 0.0 <= ra < 0.6:
                continue
            for j in range(3):
                pos = ra * 720.0 - j * 15.0
                if not 4.0 < pos < L - 4.0:
                    continue
                ti = TICKS.index(x)
                col = RB[self.ring_colors(ti)[j]] if color_mode == "random" else RB[(ti * 3 + j) % 6]
                e = np.clip((Lfull - pos) / 40.0, 0.0, 1.0)
                al = (1.0 if e > 0.5 else (0.75 if e > 0.25 else 0.5)) * k
                ring = np.abs(np.hypot((s - pos) / 3.2, d / Hr) - 1.0) <= 0.3
                front = ring & (s >= pos)
                back = ring & (s < pos)
                if color_mode == "rainbow":  # halka boyunca 6 renk (üstten alta tayf), her halkada başka başlangıç
                    an = np.mod(np.arctan2(d / Hr, (s - pos) / 3.2) + math.pi + (ti * 3 + j) * 1.05, 2.0 * math.pi)
                    cols = RB[np.clip(np.floor(an / (2.0 * math.pi) * 6.0), 0, 5).astype(np.int32)]
                else:
                    cols = np.tile(col, (len(s), 1))
                if back.any():
                    lay_over(air, I[back], J[back], (cols[back] * 0.8).astype(np.float32),
                             np.full(int(back.sum()), float(qa(np.array([0.5 * al]))[0]), np.float32))
                if front.any():
                    cc = np.where((np.abs(d[front]) < 2.0)[:, None], cols[front] * 0.4 + CREAM * 0.6, cols[front])
                    lay_over(air, I[front], J[front], cc.astype(np.float32), np.full(int(front.sum()), float(qa(np.array([al]))[0]), np.float32))


FINAL_INFO = {
    "A2": ("A + halkalar · rastgele renk", "her vuruşta 3 halka, her biri rastgele ve farklı renk"),
    "A3": ("A + halkalar · halka içinde gökkuşağı", "her halka kendi içinde 6 renk"),
    "A4": ("A + belirgin halka atışları", "kalın halka + koyu kenar, ışından taşar, asada çıkış halkası, rastgele renk"),
    "NOW": ("ŞU AN · Gökkuşağı Mızrağı", "menzil 185, yarı genişlik 8, sivri uç"),
    "A": ("A · Lux Huzmesi", "krem çekirdek + akan renk dilimleri, görüşün kenarına kadar"),
    "B": ("B · Prizma Yelpazesi", "asadan beyaz çıkar, 6 bantlı tayfa açılır"),
    "C": ("C · Lux Atışı", "ince hat + her vuruşta kalın tayf patlaması"),
    "D": ("D · Halkalı Işın", "soluk kalın gövde + vuruşta uca koşan halkalar"),
}


def run_final(did, want_times=None):
    sty = Final(did)
    fo = AP.Follow(KEY, ang=0.0)
    st0 = {"t": 0.0, "P": FN_P, "V": (0.0, 0.0), "moving": False, "face": (1, 0), "walk_t": 0.0}
    aim = (FN_P[0] + 300.0, FN_P[1] - 62.0 + math.tan(FN_ANG) * 300.0)
    for _ in range(80):
        _, _, tip = fo.step(dict(st0), aim=aim)
    on, off = fn_slimes(tip)
    slimes = [(p, i) for i, p in enumerate(on)] + [(p, 9) for p in off]
    fog = fog_factor(FN_VIEW, FN_P)
    n = int(round(FN_LOOP * FPS))
    dt = 1.0 / FPS
    frames, snaps = [], {}
    for lap in range(2):
        for i in range(n):
            t = i * dt
            st = dict(st0, t=t)
            pos, rot, tip = fo.step(st, aim=aim)
            ang = math.atan2(aim[1] - tip[1], aim[0] - tip[0])
            if did == "NOW":
                end = (tip[0] + math.cos(ang) * 185.0, tip[1] + math.sin(ang) * 185.0)
            else:
                end = vision_end(FN_P, tip, ang)
            Lfull = max(1.0, math.hypot(end[0] - tip[0], end[1] - tip[1]))
            ph, _ = Final.phase(t)
            sty.spk.step(tip, end, Lfull, dt, on=ph == "hold")
            if lap == 0:
                continue
            want = want_times is None or any(abs(t - w) < dt * 0.5 for w in want_times)
            if not want:
                continue
            F = AP.bg_crop(Z, FN_VIEW)
            air = AP.Layer(FN_VIEW[0], FN_VIEW[1], FN_VIEW[2] - FN_VIEW[0], FN_VIEW[3] - FN_VIEW[1], tx=1.0)
            Lv = sty.draw(air, tip, end, t, Lfull)
            # vurulanlar: hattaki slime'lar (ışının ulaştığı)
            flashes, hits = {}, []
            tk = [x for x in TICKS if x <= t and t < REL_T]
            ux, uy = math.cos(ang), math.sin(ang)
            for si, sp in enumerate(on):
                dd = (sp[0] - tip[0]) * ux + (sp[1] - tip[1]) * uy
                if dd <= Lv and dd <= Lfull and tk:
                    age = t - tk[-1]
                    flashes[si] = (age, 1.0)
                    hits.append((sp, age))
            draw_world(F, FN_VIEW, slimes, flashes, st)
            AP.draw_staff(F, Z, FN_VIEW, KEY, pos, rot, st["P"])
            air.composite(F, Z)
            sty.spk.draw(F, FN_VIEW)
            for sp, age in hits:
                draw_impact(F, FN_VIEW, sp, age)
            apply_fog(F, fog)
            im = Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")
            title, sub = FINAL_INFO[did]
            if t < LAUNCH:
                sub2 = "gönderiliş"
            elif t < REL_T:
                sub2 = "vuruş her 0,5 sn · hattaki herkes delinir"
            elif t < REL_T + REL_D:
                sub2 = "bırakış"
            else:
                sub2 = "ateş yok"
            im = AP.tile_label(im, title, sub + " · " + sub2)
            if want_times is None:
                frames.append(im)
            else:
                snaps[round(t, 3)] = im
    return frames if want_times is None else snaps


# ================================================================== çıktılar
def grid2(ims, gap=4, bg=(18, 20, 20)):
    top = AP.hstack(ims[:2], gap, bg)
    bot = AP.hstack(ims[2:4], gap, bg)
    return stack_v([top, bot], gap)


def build_splash_gif():
    runs = [run_splash(d) for d in "ABCD"]
    frames = []
    for parts in zip(*runs):
        g = grid2(list(parts))
        hd = header(g.width, "Gökkuşağı Asası · SAÇILMA prototipleri (oyuna bağlı değil)",
                    "1080p oyun ölçeği · vurulandan 60 px içindeki komşulara yarım hasar · vuruş 0,5 sn · sağdaki slime menzil dışında")
        frames.append(stack_v([hd, g], 0))
    n = len(frames)
    save_gif(frames, os.path.join(OUT, "sacilma.gif"), FPS, [1, 3, 6, n // 2 + 2])


def build_final_gif():
    runs = [run_final(d) for d in "ABCD"]
    frames = []
    for parts in zip(*runs):
        g = grid2(list(parts))
        hd = header(g.width, "Gökkuşağı Asası · FİNAL düz ışın prototipleri (oyuna bağlı değil)",
                    "1080p oyun ölçeği · ışın görüş elipsinin kenarına kadar (sis oyundaki gibi) · yarı genişlik ~11 dünya px · "
                    "gönderiliş -> vuruşlar -> bırakış")
        frames.append(stack_v([hd, g], 0))
    n = len(frames)
    save_gif(frames, os.path.join(OUT, "final.gif"), FPS, [1, 3, 20, int(n * 0.83)])


def build_ozet():
    # saçılma: her yön 3 an (vuruştan 0,04 / 0,08 / 0,16 sn sonra; 2. vuruş)
    t0 = SP_T0 + TICK
    times = [round(t0 + x, 3) for x in (0.04, 0.08, 0.16)]
    times = [round(round(x * FPS) / FPS, 3) for x in times]
    rows = []
    for d in "ABCD":
        sn = run_splash(d, times)
        rows.append(AP.hstack([sn[k] for k in sorted(sn)]))
    g = stack_v(rows, 4)
    hd = header(g.width, "Gökkuşağı Asası · SAÇILMA · vuruştan 0,04 / 0,08 / 0,16 sn sonra",
                "A Kırılan Işınlar · B Işık Yıldızı · C Gökkuşağı Köprüsü · D Prizma Kıymıkları (1080p ölçeği)")
    stack_v([hd, g], 0).save(os.path.join(OUT, "ozet_sacilma.png"))
    # final: gönderiliş + vuruş anı
    ft = [round(round(x * FPS) / FPS, 3) for x in (0.08, TICKS[2] + 0.08)]
    rows = []
    for d in ("NOW", "A", "B", "C", "D"):
        sn = run_final(d, ft)
        rows.append(AP.hstack([sn[k] for k in sorted(sn)]))
    g = stack_v(rows, 4)
    hd = header(g.width, "Gökkuşağı Asası · FİNAL · solda gönderiliş (0,08 sn), sağda vuruş anı",
                "ilk satır ŞU AN (menzil 185 mızrak) · A Lux Huzmesi · B Prizma Yelpazesi · C Lux Atışı · D Halkalı Işın")
    stack_v([hd, g], 0).save(os.path.join(OUT, "ozet_final.png"))
    print("ozet ok")


# ================================================================== 3) YANSIMA (saçılma v2, kullanıcı: "devamlı süren bir saçılma olmasını
# istiyorum patlamalı patlamalı değil, ... bu sıçramaları gibi değil yansıma gibi düşün"): ışın düşmana değdiği SÜRECE vurulandan 60 px
# içindeki komşulara (en çok 4) yansıyan ışık kesintisiz durur; 0,5 sn hasar tikinde yalnız yansımalar boyunca hafif bir parlaklık dalgası
# + komşuda soluk beyazlama (patlama YOK). Sağ üstteki slime menzile girip çıkar: yansıma ona uzanır / geri çekilir.
RF_LOOP = 3.0
RF_STATIC = [(S0[0] - 4.0, S0[1] - 44.0), (S0[0] + 44.0, S0[1] + 22.0), (S0[0] - 12.0, S0[1] + 38.0)]
MOV_ANG = math.radians(-25.0)
GROW = 0.1
RF_TICKS = [SP_T0 + k * TICK for k in range(6)]


def mover_pos(t):
    d = 62.0 + 28.0 * math.cos(2.0 * math.pi * t / RF_LOOP)
    return (S0[0] + math.cos(MOV_ANG) * d, S0[1] + math.sin(MOV_ANG) * d), d


def ray_ends(n, p):
    dx, dy = n[0] - S0[0], n[1] - 2.0 - S0[1]
    dl = math.hypot(dx, dy)
    ux, uy = dx / dl, dy / dl
    a0 = (S0[0] + ux * 5.0, S0[1] + uy * 5.0)
    a1 = (n[0], n[1] - 2.0)
    return a0, lerp(a0, a1, p), dl


def wave_band(rgb, s, L, age, width=2.5):
    if age < 0.1:
        g = np.abs(s - (age / 0.1) * L) < width
        rgb[g] = rgb[g] * 0.35 + CREAM * 0.65
    return rgb


class Reflect:
    def __init__(self, did):
        self.did = did

    def draw(self, air, F, t, age, targets):
        getattr(self, "_" + self.did)(air, F, t, age, targets)

    @staticmethod
    def contact(air, pos, t, k, col):
        gx, gy = air.tc(*pos)
        r = 2 if int(t * 14 + k) % 2 == 0 else 1
        air.plus(gx, gy, r, CR, [C(col), C(col)], 1.0)

    # --- A: Ayna Işını - ana ışının ince kopyası, renk dilimleri komşuya akar
    def _A(self, air, F, t, age, targets):
        for k, n, p in targets:
            a0, a1, _ = ray_ends(n, p)
            W = 2.5
            I, J, s, d, L = beam_grid(air, a0, a1, W + 3.0)
            s = np.floor(s) + 0.5
            d = np.floor(d + 0.5)
            ad = np.abs(d)
            w = W * np.clip((s + 0.5) / 5.0, 0.5, 1.0)
            inside = (s >= 0.0) & (((s <= L) & (ad <= w + 0.15)) | ((s > L) & (d * d + (s - L) ** 2 <= w * w)))
            h = np.mod(np.floor((s - t * 110.0) / 9.0), 6).astype(np.int32)
            core, mid = ad < 0.6, ad <= 1.5
            rgb = np.where(core[:, None], CREAM, np.where(mid[:, None], RBL[h], RB[h]))
            a = np.where(core | mid, 1.0, 0.5)
            rgb = wave_band(rgb, s, L, age)
            lay_over(air, I, J, rgb.astype(np.float32), np.where(inside, a, 0.0).astype(np.float32))
            if p >= 1.0:
                self.contact(air, a1, t, k, RBL[(int(t * 6) + k) % 6])
        gx, gy = air.tc(*S0)
        air.plus(gx, gy, 3 if int(t * 10) % 2 == 0 else 2, CR, [CR, C(RBL[int(t * 6) % 6]), C(RB[int(t * 6) % 6])], 1.0)

    # --- B: Prizma Tayfı - her komşuya TEK saf renk; renk yansımanın açısından gelir (prizma gibi)
    def _B(self, air, F, t, age, targets):
        for k, n, p in targets:
            a0, a1, _ = ray_ends(n, p)
            ang = math.atan2(a1[1] - a0[1], a1[0] - a0[0])
            x = (ang + math.pi) / (2.0 * math.pi) * 6.0
            h0 = int(math.floor(x)) % 6
            fr = math.floor((x - math.floor(x)) * 4.0) / 4.0
            col = RB[h0] * (1.0 - fr) + RB[(h0 + 1) % 6] * fr
            I, J, s, d, L = beam_grid(air, a0, a1, 4.0)
            s = np.floor(s) + 0.5
            d = np.floor(d + 0.5)
            ad = np.abs(d)
            inside = (s >= 0.0) & (s <= L + 0.5) & (ad <= 2.0)
            rgb = np.where((ad < 0.5)[:, None], col * 0.45 + CREAM * 0.55, np.tile(col, (len(s), 1)))
            sh = np.mod(s - t * 140.0 + k * 7.0, 22.0) < 3.0
            rgb[sh & (ad < 1.5)] = rgb[sh & (ad < 1.5)] * 0.5 + CREAM * 0.5
            a = np.where(ad <= 1.0, 1.0, 0.25)
            rgb = wave_band(rgb, s, L, age)
            lay_over(air, I, J, rgb.astype(np.float32), np.where(inside, a, 0.0).astype(np.float32))
            if p >= 1.0:
                self.contact(air, a1, t, k, col)
        # vurulanın üstünde dönen küçük prizma parıltısı
        I, J, s, d, _ = beam_grid(air, S0, (S0[0] + 0.01, S0[1]), 6.0)
        m = (np.abs(s) / 3.2 + np.abs(d) / 4.6) <= 1.0
        an = np.mod(np.arctan2(d, s) + t * 3.0, 2.0 * math.pi)
        kk = np.clip(np.floor(an / (2.0 * math.pi) * 6.0), 0, 5).astype(np.int32)
        rgb = np.where((np.abs(s) + np.abs(d) < 1.6)[:, None], CREAM, RBL[kk])
        lay_over(air, I[m], J[m], rgb[m].astype(np.float32), np.ones(int(m.sum()), np.float32))

    # --- C: Işık Konisi - vurulandan komşuya genişleyen yarı saydam ışık hüzmesi, komşunun üstüne yayılır
    def _C(self, air, F, t, age, targets):
        boost = 0.25 if age < 0.12 else 0.0
        for k, n, p in targets:
            a0, a1, _ = ray_ends(n, p)
            I, J, s, d, L = beam_grid(air, a0, a1, 9.0)
            s = np.floor(s) + 0.5
            d = np.floor(d + 0.5)
            hw = 1.0 + 6.0 * np.clip(s / max(1.0, L), 0.0, 1.0) * p
            ad = np.abs(d)
            inside = (s >= 0.0) & (s <= L) & (ad <= hw + 0.6)
            u = np.clip(d / np.maximum(hw, 0.6), -0.999, 0.999)
            kk = np.clip(np.floor((u + 1.0) * 0.5 * 6.0), 0, 5).astype(np.int32)
            rgb = RB[kk] * 0.6 + CREAM * 0.4
            core = (ad < 0.5) & (s < 0.75 * L)
            rgb[core] = CREAM
            a = np.where(core, 0.75, np.where(ad <= hw, 0.5, 0.25)) + boost
            lay_over(air, I, J, rgb.astype(np.float32), qa(np.where(inside, a, 0.0)).astype(np.float32))
            if p >= 1.0:
                for rx, ry, al in ((7.0, 5.0, 0.25), (4.0, 3.0, 0.5)):
                    I2, J2, s2, d2, _ = beam_grid(air, a1, (a1[0] + 0.01, a1[1]), rx + 1.0)
                    m = np.hypot(s2 / rx, d2 / ry) <= 1.0
                    lay_over(air, I2[m], J2[m], np.tile(CREAM, (int(m.sum()), 1)).astype(np.float32),
                             np.full(int(m.sum()), float(qa(np.array([al]))[0]), np.float32))
        I, J, s, d, _ = beam_grid(air, S0, (S0[0] + 0.01, S0[1]), 7.0)
        m = np.hypot(s / 5.0, d / 4.0) <= 1.0
        lay_over(air, I[m], J[m], np.tile(CREAM, (int(m.sum()), 1)).astype(np.float32), np.full(int(m.sum()), 0.5, np.float32))

    # --- D: Parlama Yıldızı - vurulanda dönen ışık yıldızı + komşulara ince ışık iplikleri, iplikte akan parıltı taneleri
    def _D(self, air, F, t, age, targets):
        gx, gy = air.tc(*S0)
        for i in range(8):
            an = math.radians(i * 45.0) + t * 0.7
            ln = 9.0 + 5.0 * math.sin(t * 6.0 + i * 1.7)
            col = RB[(i + int(t * 3)) % 6]
            for j in range(int(ln)):
                x = gx + int(round(math.cos(an) * (j + 2)))
                y = gy + int(round(math.sin(an) * (j + 2)))
                air.put(x, y, CR if j < 3 else C(col), 1.0 if j < 3 else (0.75 if j < ln * 0.7 else 0.5))
        air.plus(gx, gy, 2, CR, [CR, CR], 1.0)
        self._motes = []
        for k, n, p in targets:
            a0, a1, _ = ray_ends(n, p)
            col = RB[(k * 2 + 1) % 6]
            I, J, s, d, L = beam_grid(air, a0, a1, 3.0)
            s = np.floor(s) + 0.5
            d = np.floor(d + 0.5)
            ad = np.abs(d)
            inside = (s >= 0.0) & (s <= L + 0.5) & (ad <= 1.0)
            rgb = np.where((ad < 0.5)[:, None], CREAM, np.tile(col, (len(s), 1)))
            rgb = wave_band(rgb, s, L, age)
            lay_over(air, I, J, rgb.astype(np.float32), np.where(inside, np.where(ad < 0.5, 1.0, 0.5), 0.0).astype(np.float32))
            if p >= 1.0:
                self.contact(air, a1, t, k, col)
                for j in range(2):
                    f = (t * 1.7 + j * 0.5 + k * 0.17) % 1.0
                    self._motes.append((lerp(a0, a1, f), (k * 2 + j) % 6, f))

    def sprites(self, F, view):
        if self.did != "D":
            return
        for pos, ci, f in self._motes:
            blit2(F, SPARK[ci][0 if f < 0.7 else 1], (pos[0] - view[0]) * Z, (pos[1] - view[1]) * Z, Z)


REFLECT_INFO = {
    "A": ("A · Ayna Işını", "ana ışının ince kopyası, renk dilimleri komşuya akar"),
    "B": ("B · Prizma Tayfı", "her komşuya tek saf renk, renk yansıma açısından"),
    "C": ("C · Işık Konisi", "komşuya genişleyen yarı saydam ışık, üstüne yayılır"),
    "D": ("D · Parlama Yıldızı", "dönen ışık yıldızı + ince iplikte akan parıltılar"),
}


def run_reflect(did, want_times=None):
    sty = Reflect(did)
    fo = AP.Follow(KEY, ang=0.0)
    st0 = {"t": 0.0, "P": SP_P, "V": (0.0, 0.0), "moving": False, "face": (1, 0), "walk_t": 0.0}
    spk = Sparks(77, 24.0, 6.0)
    for _ in range(60):
        fo.step(dict(st0), aim=S0)
    n = int(round(RF_LOOP * FPS))
    dt = 1.0 / FPS
    pm = 0.0
    frames, snaps = [], {}
    for lap in range(2):
        for i in range(n):
            t = i * dt
            st = dict(st0, t=t)
            pos, rot, tip = fo.step(st, aim=S0)
            L = max(1.0, math.hypot(S0[0] - tip[0], S0[1] - tip[1]))
            spk.step(tip, S0, L, dt)
            mp, md = mover_pos(t)
            pm = clamp01(pm + (dt if md <= SPLASH_R else -dt) / GROW)
            if lap == 0:
                continue
            want = want_times is None or any(abs(t - w) < dt * 0.5 for w in want_times)
            if not want:
                continue
            tk = [x for x in RF_TICKS if x <= t]
            age = t - tk[-1] if tk else t + (RF_LOOP - RF_TICKS[-1])
            targets = [(k, nn, 1.0) for k, nn in enumerate(RF_STATIC)]
            if pm > 0.0:
                targets.append((3, mp, ease_out(pm)))
            slimes = [(S0, 0)] + [(nn, k + 1) for k, nn in enumerate(RF_STATIC)] + [(mp, 4)]
            flashes = {0: (age, 1.0)}
            for k, _, p in targets:
                if p >= 1.0:
                    flashes[k + 1] = (age, 0.4)
            F = AP.bg_crop(Z, SP_VIEW)
            air = AP.Layer(SP_VIEW[0], SP_VIEW[1], SP_VIEW[2] - SP_VIEW[0], SP_VIEW[3] - SP_VIEW[1], tx=1.0)
            fx = AP.Layer(SP_VIEW[0], SP_VIEW[1], SP_VIEW[2] - SP_VIEW[0], SP_VIEW[3] - SP_VIEW[1], tx=1.0)
            sty.draw(fx, F, t, age, targets)
            draw_world(F, SP_VIEW, slimes, flashes, st)
            AP.draw_staff(F, Z, SP_VIEW, KEY, pos, rot, st["P"])
            beam_now(air, tip, S0, t, 6.0)
            tip_flare(air, tip, t)
            air.composite(F, Z)
            spk.draw(F, SP_VIEW)
            draw_impact(F, SP_VIEW, S0, age)
            fx.composite(F, Z)
            sty.sprites(F, SP_VIEW)
            im = Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")
            title, sub = REFLECT_INFO[did]
            state = "sağ üstteki menzil dışında" if md > SPLASH_R else "sağ üstteki menzilde"
            im = AP.tile_label(im, title, sub + " · " + state)
            if want_times is None:
                frames.append(im)
            else:
                snaps[round(t, 3)] = im
    return frames if want_times is None else snaps


def build_reflect():
    runs = [run_reflect(d) for d in "ABCD"]
    frames = []
    for parts in zip(*runs):
        g = grid2(list(parts))
        hd = header(g.width, "Gökkuşağı Asası · YANSIMA prototipleri (saçılma v2, sürekli; oyuna bağlı değil)",
                    "1080p oyun ölçeği · ışın değdikçe 60 px içindeki komşulara (en çok 4) kesintisiz yansıma, yarım hasar · "
                    "0,5 sn tikte yalnız hafif parlaklık dalgası")
        frames.append(stack_v([hd, g], 0))
    n = len(frames)
    save_gif(frames, os.path.join(OUT, "yansima.gif"), FPS, [2, 20, 40, 60])
    times = [round(round(x * FPS) / FPS, 3) for x in (0.32, 0.80, RF_TICKS[3] + 0.04)]
    rows = []
    for d in "ABCD":
        sn = run_reflect(d, times)
        rows.append(AP.hstack([sn[k] for k in sorted(sn)]))
    g = stack_v(rows, 4)
    hd = header(g.width, "Gökkuşağı Asası · YANSIMA · solda 3 komşu, ortada 4. komşu menzile giriyor, sağda tik dalgası",
                "A Ayna Işını · B Prizma Tayfı · C Işık Konisi · D Parlama Yıldızı (1080p ölçeği)")
    stack_v([hd, g], 0).save(os.path.join(OUT, "ozet_yansima.png"))
    print("yansima ok")


# ================================================================== 4) RASTGELE SAÇILMA (saçılma v3, kullanıcı: "görünüşleri güzel ancak ben
# hedef odaklı değil rasgele ışınlar saçmasını istedim etrafına"): ışın düşmana değdiği sürece vurulandan RASTGELE yönlere kesintisiz ışınlar
# saçılır (her biri kısa ömürlü, yerine yenisi doğar, aynı anda 4-6 tane); boyları en çok 60 px = hasar alanını gösterir. Hasar alan kuralı
# (60 px içindeki komşulara yarım hasar), ışınlar hedef seçmez. Döngü dikişsiz: ışın takvimi 3 sn'lik dairesel zamanda üretilir.
SC_STATIC = RF_STATIC
BACK_ANG = math.atan2(SP_P[1] - 62.0 - S0[1], SP_P[0] - S0[0])  # vurulandan asaya doğru (gelen ışının üstü)
BACK_SEP = math.radians(28.0)  # gelen ışının üstüne geri düşen ışın onunla birleşip kayboluyordu


def _angdiff(a, b):
    return abs((a - b + math.pi) % (2.0 * math.pi) - math.pi)


def make_schedule(seed, rate, life_rng, len_rng, sep):
    rng = random.Random(seed)
    n = int(round(rate * RF_LOOP))
    rays = []
    for i in range(n):
        born = ((i + rng.uniform(-0.35, 0.35)) / rate) % RF_LOOP
        life = rng.uniform(*life_rng)

        def overlaps(r):
            return (born - r["born"]) % RF_LOOP < r["life"] or (r["born"] - born) % RF_LOOP < life
        ang = rng.uniform(0.0, 2.0 * math.pi)
        for _ in range(40):
            if _angdiff(ang, BACK_ANG) > BACK_SEP and all(_angdiff(ang, r["ang"]) > sep for r in rays if overlaps(r)):
                break
            ang = rng.uniform(0.0, 2.0 * math.pi)
        rays.append({"born": born, "life": life, "ang": ang, "L": rng.uniform(*len_rng), "ci": rng.randrange(6), "k": i})
    return rays


SC_PARAMS = {  # yön: (oran/sn, ömür, boy, en az açı farkı)
    "A": (12.0, (0.35, 0.55), (30.0, 60.0), math.radians(32.0)),
    "B": (12.0, (0.35, 0.55), (30.0, 60.0), math.radians(32.0)),
    "C": (7.0, (0.55, 0.85), (34.0, 60.0), math.radians(45.0)),
    "D": (10.0, (0.45, 0.7), (30.0, 60.0), math.radians(35.0)),
}


class Scatter:
    def __init__(self, did):
        self.did = did
        rate, life, ln, sep = SC_PARAMS[did]
        self.rays = make_schedule(1100 + ord(did), rate, life, ln, sep)
        self._motes = []

    def alive(self, t):
        out = []
        for r in self.rays:
            age = (t - r["born"]) % RF_LOOP
            if age < r["life"]:
                out.append((r, age))
        return out

    @staticmethod
    def span(r, age, grow=0.07, shrink=0.12):
        """(baş, kuyruk) oranı: dışa doğru 0,07 sn'de uzar, son 0,12 sn'de kuyruğu dışa çekilir (ışık uzaklaşıyor gibi)."""
        head = ease_out(age / grow)
        tail = clamp01((age - (r["life"] - shrink)) / shrink)
        return head, tail

    @staticmethod
    def ends(r, head, tail, start=5.0):
        ux, uy = math.cos(r["ang"]), math.sin(r["ang"])
        L = r["L"]
        s0 = start + (L - start) * tail
        s1 = start + (L - start) * head
        return (S0[0] + ux * s0, S0[1] + uy * s0), (S0[0] + ux * s1, S0[1] + uy * s1)

    def draw(self, air, F, t, age_tick):
        getattr(self, "_" + self.did)(air, t, age_tick)

    # --- A: Ayna Işını (ana ışının ince kopyası, renk dilimleri dışa akar)
    def _A(self, air, t, age_tick):
        for r, age in self.alive(t):
            head, tail = self.span(r, age)
            if head <= tail:
                continue
            a0, a1 = self.ends(r, head, tail)
            W = 2.0
            I, J, s, d, L = beam_grid(air, a0, a1, W + 3.0)
            s = np.floor(s) + 0.5
            d = np.floor(d + 0.5)
            ad = np.abs(d)
            w = W * np.where(tail > 0.0, 1.0, np.clip((s + 0.5) / 5.0, 0.5, 1.0))
            inside = (s >= 0.0) & (((s <= L) & (ad <= w + 0.15)) | ((s > L) & (d * d + (s - L) ** 2 <= w * w)))
            h = np.mod(np.floor((s - t * 110.0) / 9.0) + r["ci"], 6).astype(np.int32)
            core, mid = ad < 0.6, ad <= 1.2
            rgb = np.where(core[:, None], CREAM, np.where(mid[:, None], RBL[h], RB[h]))
            a = np.where(core | mid, 1.0, 0.5)
            rgb = wave_band(rgb, s, L, age_tick)
            lay_over(air, I, J, rgb.astype(np.float32), np.where(inside, a, 0.0).astype(np.float32))
        gx, gy = air.tc(*S0)
        air.plus(gx, gy, 3 if int(t * 10) % 2 == 0 else 2, CR, [CR, C(RBL[int(t * 6) % 6]), C(RB[int(t * 6) % 6])], 1.0)

    # --- B: Prizma Tayfı (her ışın tek saf renk, renk yönünden)
    def _B(self, air, t, age_tick):
        for r, age in self.alive(t):
            head, tail = self.span(r, age)
            if head <= tail:
                continue
            a0, a1 = self.ends(r, head, tail)
            x = (r["ang"] % (2.0 * math.pi)) / (2.0 * math.pi) * 6.0
            h0 = int(math.floor(x)) % 6
            fr = math.floor((x - math.floor(x)) * 4.0) / 4.0
            col = RB[h0] * (1.0 - fr) + RB[(h0 + 1) % 6] * fr
            I, J, s, d, L = beam_grid(air, a0, a1, 4.0)
            s = np.floor(s) + 0.5
            d = np.floor(d + 0.5)
            ad = np.abs(d)
            inside = (s >= 0.0) & (s <= L + 0.5) & (ad <= 2.0)
            rgb = np.where((ad < 0.5)[:, None], col * 0.45 + CREAM * 0.55, np.tile(col, (len(s), 1)))
            sh = np.mod(s - t * 140.0 + r["k"] * 7.0, 22.0) < 3.0
            rgb[sh & (ad < 1.5)] = rgb[sh & (ad < 1.5)] * 0.5 + CREAM * 0.5
            a = np.where(ad <= 1.0, 1.0, 0.25)
            rgb = wave_band(rgb, s, L, age_tick)
            lay_over(air, I, J, rgb.astype(np.float32), np.where(inside, a, 0.0).astype(np.float32))
        I, J, s, d, _ = beam_grid(air, S0, (S0[0] + 0.01, S0[1]), 6.0)
        m = (np.abs(s) / 3.2 + np.abs(d) / 4.6) <= 1.0
        an = np.mod(np.arctan2(d, s) + t * 3.0, 2.0 * math.pi)
        kk = np.clip(np.floor(an / (2.0 * math.pi) * 6.0), 0, 5).astype(np.int32)
        rgb = np.where((np.abs(s) + np.abs(d) < 1.6)[:, None], CREAM, RBL[kk])
        lay_over(air, I[m], J[m], rgb[m].astype(np.float32), np.ones(int(m.sum()), np.float32))

    # --- C: Işık Konisi (dışa genişleyen yarı saydam tayf hüzmeleri, yumuşak belirip söner)
    def _C(self, air, t, age_tick):
        boost = 0.25 if age_tick < 0.12 else 0.0
        for r, age in self.alive(t):
            fin = clamp01(age / 0.12)
            fout = clamp01((r["life"] - age) / 0.18)
            vis = min(fin, fout)
            a0 = (S0[0] + math.cos(r["ang"]) * 4.0, S0[1] + math.sin(r["ang"]) * 4.0)
            a1 = (S0[0] + math.cos(r["ang"]) * r["L"], S0[1] + math.sin(r["ang"]) * r["L"])
            I, J, s, d, L = beam_grid(air, a0, a1, 8.0)
            s = np.floor(s) + 0.5
            d = np.floor(d + 0.5)
            hw = 1.0 + 5.0 * np.clip(s / max(1.0, L), 0.0, 1.0)
            ad = np.abs(d)
            # uç yumuşak: son %25'te saydamlaşır
            endf = np.clip((L - s) / (0.25 * L), 0.0, 1.0)
            inside = (s >= 0.0) & (s <= L) & (ad <= hw + 0.6)
            u = np.clip(d / np.maximum(hw, 0.6), -0.999, 0.999)
            kk = np.clip(np.floor((u + 1.0) * 0.5 * 6.0), 0, 5).astype(np.int32)
            rgb = RB[kk] * 0.6 + CREAM * 0.4
            core = (ad < 0.5) & (s < 0.6 * L)
            rgb[core] = CREAM
            a = (np.where(core, 0.75, np.where(ad <= hw, 0.5, 0.25)) + boost) * vis * np.where(endf > 0.5, 1.0, 0.5)
            lay_over(air, I, J, rgb.astype(np.float32), qa(np.where(inside, a, 0.0)).astype(np.float32))
        I, J, s, d, _ = beam_grid(air, S0, (S0[0] + 0.01, S0[1]), 7.0)
        m = np.hypot(s / 5.0, d / 4.0) <= 1.0
        lay_over(air, I[m], J[m], np.tile(CREAM, (int(m.sum()), 1)).astype(np.float32), np.full(int(m.sum()), 0.5, np.float32))

    # --- D: Parlama Yıldızı (dönen yıldız + rastgele ince iplikler, iplikte dışa akan parıltılar)
    def _D(self, air, t, age_tick):
        gx, gy = air.tc(*S0)
        for i in range(8):
            an = math.radians(i * 45.0) + t * 0.7
            ln = 9.0 + 5.0 * math.sin(t * 6.0 + i * 1.7)
            col = RB[(i + int(t * 3)) % 6]
            for j in range(int(ln)):
                x = gx + int(round(math.cos(an) * (j + 2)))
                y = gy + int(round(math.sin(an) * (j + 2)))
                air.put(x, y, CR if j < 3 else C(col), 1.0 if j < 3 else (0.75 if j < ln * 0.7 else 0.5))
        air.plus(gx, gy, 2, CR, [CR, CR], 1.0)
        self._motes = []
        for r, age in self.alive(t):
            head, tail = self.span(r, age, grow=0.08, shrink=0.15)
            if head <= tail:
                continue
            a0, a1 = self.ends(r, head, tail, start=8.0)
            col = RB[r["ci"]]
            I, J, s, d, L = beam_grid(air, a0, a1, 3.0)
            s = np.floor(s) + 0.5
            d = np.floor(d + 0.5)
            ad = np.abs(d)
            inside = (s >= 0.0) & (s <= L + 0.5) & (ad <= 1.0)
            rgb = np.where((ad < 0.5)[:, None], CREAM, np.tile(col, (len(s), 1)))
            rgb = wave_band(rgb, s, L, age_tick)
            lay_over(air, I, J, rgb.astype(np.float32), np.where(inside, np.where(ad < 0.5, 1.0, 0.5), 0.0).astype(np.float32))
            gx2, gy2 = air.tc(*a1)
            if tail <= 0.0:
                air.plus(gx2, gy2, 1, CR, [C(col)], 1.0)
            f = clamp01(age / (r["life"] * 0.9))
            self._motes.append((lerp(a0, a1, f), r["ci"], f))

    def sprites(self, F, view):
        if self.did != "D":
            return
        for pos, ci, f in self._motes:
            blit2(F, SPARK[ci][0 if f < 0.6 else 1], (pos[0] - view[0]) * Z, (pos[1] - view[1]) * Z, Z)


SCATTER_INFO = {
    "A": ("A · Ayna Işınları", "ana ışının ince kopyaları rastgele yönlere"),
    "B": ("B · Prizma Tayfı", "rastgele ışınlar, her biri yönüne göre tek saf renk"),
    "C": ("C · Işık Konileri", "dışa genişleyen yarı saydam hüzmeler, yumuşak söner"),
    "D": ("D · Parlama Yıldızı", "dönen yıldız + rastgele iplikte dışa akan parıltı"),
}


def run_scatter(did, want_times=None):
    sty = Scatter(did)
    fo = AP.Follow(KEY, ang=0.0)
    st0 = {"t": 0.0, "P": SP_P, "V": (0.0, 0.0), "moving": False, "face": (1, 0), "walk_t": 0.0}
    spk = Sparks(77, 24.0, 6.0)
    for _ in range(60):
        fo.step(dict(st0), aim=S0)
    n = int(round(RF_LOOP * FPS))
    dt = 1.0 / FPS
    slimes = [(S0, 0)] + [(nn, k + 1) for k, nn in enumerate(SC_STATIC)] + [(OUTSIDE, 4)]
    frames, snaps = [], {}
    for lap in range(2):
        for i in range(n):
            t = i * dt
            st = dict(st0, t=t)
            pos, rot, tip = fo.step(st, aim=S0)
            L = max(1.0, math.hypot(S0[0] - tip[0], S0[1] - tip[1]))
            spk.step(tip, S0, L, dt)
            if lap == 0:
                continue
            want = want_times is None or any(abs(t - w) < dt * 0.5 for w in want_times)
            if not want:
                continue
            tk = [x for x in RF_TICKS if x <= t]
            age = t - tk[-1] if tk else t + (RF_LOOP - RF_TICKS[-1])
            flashes = {0: (age, 1.0)}
            for k in range(len(SC_STATIC)):
                flashes[k + 1] = (age, 0.4)
            F = AP.bg_crop(Z, SP_VIEW)
            air = AP.Layer(SP_VIEW[0], SP_VIEW[1], SP_VIEW[2] - SP_VIEW[0], SP_VIEW[3] - SP_VIEW[1], tx=1.0)
            fx = AP.Layer(SP_VIEW[0], SP_VIEW[1], SP_VIEW[2] - SP_VIEW[0], SP_VIEW[3] - SP_VIEW[1], tx=1.0)
            sty.draw(fx, F, t, age)
            draw_world(F, SP_VIEW, slimes, flashes, st)
            AP.draw_staff(F, Z, SP_VIEW, KEY, pos, rot, st["P"])
            beam_now(air, tip, S0, t, 6.0)
            tip_flare(air, tip, t)
            air.composite(F, Z)
            spk.draw(F, SP_VIEW)
            draw_impact(F, SP_VIEW, S0, age)
            fx.composite(F, Z)
            sty.sprites(F, SP_VIEW)
            im = Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")
            title, sub = SCATTER_INFO[did]
            im = AP.tile_label(im, title, sub)
            if want_times is None:
                frames.append(im)
            else:
                snaps[round(t, 3)] = im
    return frames if want_times is None else snaps


def build_scatter():
    runs = [run_scatter(d) for d in "ABCD"]
    frames = []
    for parts in zip(*runs):
        g = grid2(list(parts))
        hd = header(g.width, "Gökkuşağı Asası · RASTGELE SAÇILMA prototipleri (saçılma v3, sürekli; oyuna bağlı değil)",
                    "1080p oyun ölçeği · ışın değdikçe vurulandan rastgele yönlere kesintisiz ışınlar (boy en çok 60 px = hasar alanı) · "
                    "60 px içindeki komşulara yarım hasar · sağdaki slime alan dışında")
        frames.append(stack_v([hd, g], 0))
    save_gif(frames, os.path.join(OUT, "rastgele.gif"), FPS, [2, 20, 40, 60])
    times = [round(round(x * FPS) / FPS, 3) for x in (0.40, 1.24, RF_TICKS[4] + 0.04)]
    rows = []
    for d in "ABCD":
        sn = run_scatter(d, times)
        rows.append(AP.hstack([sn[k] for k in sorted(sn)]))
    g = stack_v(rows, 4)
    hd = header(g.width, "Gökkuşağı Asası · RASTGELE SAÇILMA · üç ayrı an (sağda hasar tiki dalgası)",
                "A Ayna Işınları · B Prizma Tayfı · C Işık Konileri · D Parlama Yıldızı (1080p ölçeği)")
    stack_v([hd, g], 0).save(os.path.join(OUT, "ozet_rastgele.png"))
    print("rastgele ok")


# ================================================================== 5) AKIŞ (saçılma v4, kullanıcı: "bitişleri solarak bitmiyor keskin bir
# şekilde bitiyor, ayrıca bu bir ışık olduğu için yansımaların kopuk kopuk değil devamlı ve rasgele konumlarda olması gerekiyor hareketsel
# olarak"): ışınlar doğup sönmez, ışın değdiği sürece HEP AÇIK; her biri kendi yuvası etrafında farklı frekanslı sinüs karışımıyla rastgele
# gibi ama KESİNTİSİZ gezinir (boyu da nefes alır); uç incelerek ve 8 adımda saydamlaşarak SÖNER. Gelen ışının üstüne gelen ışın orada
# yumuşakça kısılır. Döngü 3 sn'de dikişsiz (frekanslar döngünün tam katları).
FL_N = {"A": 5, "B": 5, "C": 4, "D": 5}


def q8(a):
    return np.floor(np.clip(a, 0.0, 1.0) * 8.0 + 0.5) / 8.0


def smooth01(x):
    x = clamp01(x)
    return x * x * (3.0 - 2.0 * x)


def flow_rays(did, t):
    n = FL_N[did]
    rng = random.Random(2000 + ord(did))
    w = 2.0 * math.pi * t / RF_LOOP
    out = []
    for i in range(n):
        base = BACK_ANG + (i + 0.5) * 2.0 * math.pi / n
        k1, k2 = rng.sample([1, 2, 3], 2)
        k3 = rng.choice([1, 2, 3])
        p1, p2, p3 = (rng.uniform(0.0, 2.0 * math.pi) for _ in range(3))
        nz = 0.62 * math.sin(k1 * w + p1) + 0.38 * math.sin(k2 * w + p2)
        ang = base + nz * 0.6 * (2.0 * math.pi / n)
        L = 54.0 + 10.0 * math.sin(k3 * w + p3)  # uç söndüğü için görünen boy ~%70: alan (60 px) yine dolsun
        vis = smooth01((_angdiff(ang, BACK_ANG) - BACK_SEP * 0.5) / BACK_SEP)
        out.append((ang, L, vis, i))
    return out


# NEFES (saçılma v5, kullanıcı: "ışınlar kısalıp uzunlamalı olabilir bu direk oynayan çubuklar gibi oldu, ama görünüşleri güzel sadece
# hareketleri tuhaf"): ışın SAVRULMAZ; her ışın kendi yönünde yumuşakça uzar ve geri kısalır (sin), boyu sıfıra indiği anda yeni rastgele
# yönden yeniden uzar (yön değişimi görünmez). Işınlar farklı periyot/fazda -> ekranda hep ışık var. Döngü dikişsiz (periyot sayısı tam).
NF_N = {"A": 6, "B": 6, "C": 5, "D": 6}
NEFES_RAY_ALPHA = 0.6  # A/B/D ışın gövdesi saydamlık çarpanı (çekirdek dahil); merkez parıltısı 0,85


def _hash01(*xs):
    h = 2166136261
    for x in xs:
        h = ((h ^ (int(x) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return (h % 100003) / 100003.0


def breath_rays(did, t):
    n = NF_N[did]
    rng = random.Random(3000 + ord(did))
    out = []
    for i in range(n):
        c = rng.choice([2, 3, 3, 4])  # döngüde kaç nefes (1,5 / 1,0 / 0,75 sn)
        ph = (i / n + rng.uniform(-0.08, 0.08)) % 1.0
        x = c * t / RF_LOOP + ph
        k = int(math.floor(x))
        u = x - k
        cyc = k % c
        spacing = 2.0 * math.pi / n
        ang = BACK_ANG + (i + 0.5) * spacing + (_hash01(ord(did), i, cyc) - 0.5) * 0.9 * spacing
        ang += 0.06 * (u - 0.5)  # nefes boyunca hafif kayma (birkaç derece)
        Lmax = 48.0 + 16.0 * _hash01(ord(did), i, cyc, 7)
        grow = math.sin(math.pi * u) ** 0.85
        L = 6.0 + (Lmax - 6.0) * grow
        vis = smooth01((_angdiff(ang, BACK_ANG) - BACK_SEP * 0.5) / BACK_SEP) * smooth01(grow / 0.25)
        out.append((ang, L, vis, i))
    return out


def fade_along(s, L, start=0.4):
    """Işın boyunca: ilk %40 tam, sonra uca doğru yumuşak sönüş (uçta 0)."""
    f = np.clip(s / max(1.0, L), 0.0, 1.0)
    return np.clip((1.0 - f) / (1.0 - start), 0.0, 1.0) ** 1.3, f


def flow_ends(ang, L, start=4.0):
    ux, uy = math.cos(ang), math.sin(ang)
    return (S0[0] + ux * start, S0[1] + uy * start), (S0[0] + ux * L, S0[1] + uy * L)


class Flow:
    def __init__(self, did, mode="akis"):
        self.did = did
        self.mode = mode
        self.base = did[0]  # C2/C3 = C'nin ışınları + D'nin yıldızı
        self._motes = []
        # kullanıcı (nefes v2): "sadece C değil diğer ışınlar da biraz opak olabilir" -> A/B/D ışınları da yarı saydam (C zaten öyle)
        self.ak = NEFES_RAY_ALPHA if (mode == "nefes" and self.base != "C") else 1.0

    def rays(self, t):
        return breath_rays(self.base, t) if self.mode == "nefes" else flow_rays(self.base, t)

    def draw(self, air, F, t, age_tick):
        getattr(self, "_" + self.did)(air, t, age_tick)

    # --- A: Ayna Işınları
    def _A(self, air, t, age_tick):
        for ang, L, vis, i in self.rays(t):
            if vis <= 0.0:
                continue
            a0, a1 = flow_ends(ang, L)
            I, J, s, d, Lr = beam_grid(air, a0, a1, 4.0)
            s = np.floor(s) + 0.5
            d = np.floor(d + 0.5)
            ad = np.abs(d)
            fade, f = fade_along(s, Lr)
            w = 2.2 * (1.0 - 0.6 * f) * np.clip((s + 0.5) / 4.0, 0.6, 1.0)
            inside = (s >= 0.0) & (s <= Lr) & (ad <= w + 0.15)
            h = np.mod(np.floor((s - t * 110.0) / 9.0) + i, 6).astype(np.int32)
            core, mid = ad < 0.6, ad <= w * 0.6
            rgb = np.where(core[:, None], CREAM, np.where(mid[:, None], RBL[h], RB[h]))
            a = np.where(core | mid, 1.0, 0.5) * fade * vis * self.ak
            rgb = wave_band(rgb, s, Lr, age_tick)
            lay_over(air, I, J, rgb.astype(np.float32), q8(np.where(inside, a, 0.0)).astype(np.float32))
        gx, gy = air.tc(*S0)
        air.plus(gx, gy, 3 if int(t * 10) % 2 == 0 else 2, CR, [CR, C(RBL[int(t * 6) % 6]), C(RB[int(t * 6) % 6])], min(1.0, self.ak + 0.25))

    # --- B: Prizma Tayfı (renk = yön; ışın gezindikçe rengi akar)
    def _B(self, air, t, age_tick):
        for ang, L, vis, i in self.rays(t):
            if vis <= 0.0:
                continue
            x = (ang % (2.0 * math.pi)) / (2.0 * math.pi) * 6.0
            h0 = int(math.floor(x)) % 6
            fr = math.floor((x - math.floor(x)) * 4.0) / 4.0
            col = RB[h0] * (1.0 - fr) + RB[(h0 + 1) % 6] * fr
            a0, a1 = flow_ends(ang, L)
            I, J, s, d, Lr = beam_grid(air, a0, a1, 4.0)
            s = np.floor(s) + 0.5
            d = np.floor(d + 0.5)
            ad = np.abs(d)
            fade, f = fade_along(s, Lr)
            w = 1.6 * (1.0 - 0.6 * f)
            inside = (s >= 0.0) & (s <= Lr) & (ad <= w + 1.0)
            rgb = np.where((ad < 0.5)[:, None], col * 0.45 + CREAM * 0.55, np.tile(col, (len(s), 1)))
            sh = np.mod(s - t * 140.0 + i * 7.0, 22.0) < 3.0
            rgb[sh & (ad < 1.5)] = rgb[sh & (ad < 1.5)] * 0.5 + CREAM * 0.5
            a = np.where(ad <= w, 1.0, 0.25) * fade * vis * self.ak
            rgb = wave_band(rgb, s, Lr, age_tick)
            lay_over(air, I, J, rgb.astype(np.float32), q8(np.where(inside, a, 0.0)).astype(np.float32))
        I, J, s, d, _ = beam_grid(air, S0, (S0[0] + 0.01, S0[1]), 6.0)
        m = (np.abs(s) / 3.2 + np.abs(d) / 4.6) <= 1.0
        an = np.mod(np.arctan2(d, s) + t * 3.0, 2.0 * math.pi)
        kk = np.clip(np.floor(an / (2.0 * math.pi) * 6.0), 0, 5).astype(np.int32)
        rgb = np.where((np.abs(s) + np.abs(d) < 1.6)[:, None], CREAM, RBL[kk])
        lay_over(air, I[m], J[m], rgb[m].astype(np.float32), np.ones(int(m.sum()), np.float32))

    # --- C: Işık Konileri (dışa genişleyip uçta erir)
    def _C(self, air, t, age_tick):
        boost = 0.2 if age_tick < 0.12 else 0.0
        for ang, L, vis, i in self.rays(t):
            if vis <= 0.0:
                continue
            a0, a1 = flow_ends(ang, L)
            I, J, s, d, Lr = beam_grid(air, a0, a1, 8.0)
            s = np.floor(s) + 0.5
            d = np.floor(d + 0.5)
            ad = np.abs(d)
            fade, f = fade_along(s, Lr, start=0.3)
            hw = 1.0 + 5.0 * f
            inside = (s >= 0.0) & (s <= Lr) & (ad <= hw + 0.6)
            u = np.clip(d / np.maximum(hw, 0.6), -0.999, 0.999)
            kk = np.clip(np.floor((u + 1.0) * 0.5 * 6.0), 0, 5).astype(np.int32)
            rgb = RB[kk] * 0.6 + CREAM * 0.4
            core = ad < 0.5
            rgb[core] = CREAM
            edge = np.clip((hw + 0.6 - ad) / 1.2, 0.0, 1.0)  # kenar da yumuşak
            a = (np.where(core, 0.75, 0.5) + boost) * edge * fade * vis
            lay_over(air, I, J, rgb.astype(np.float32), q8(np.where(inside, a, 0.0)).astype(np.float32))
        I, J, s, d, _ = beam_grid(air, S0, (S0[0] + 0.01, S0[1]), 7.0)
        rr = np.hypot(s / 5.0, d / 4.0)
        m = rr <= 1.0
        lay_over(air, I[m], J[m], np.tile(CREAM, (int(m.sum()), 1)).astype(np.float32), q8(0.6 * (1.0 - rr[m] ** 2)).astype(np.float32))

    # --- D: Parlama Yıldızı (dönen yıldız + gezinen iplikler, iplikte dışa akıp sönen parıltılar)
    def _D(self, air, t, age_tick):
        gx, gy = air.tc(*S0)
        for i in range(8):
            an = math.radians(i * 45.0) + t * 0.7
            ln = 9.0 + 5.0 * math.sin(t * 6.0 + i * 1.7)
            col = RB[(i + int(t * 3)) % 6]
            for j in range(int(ln)):
                x = gx + int(round(math.cos(an) * (j + 2)))
                y = gy + int(round(math.sin(an) * (j + 2)))
                fa = float(q8(np.array([(1.0 - j / ln) * min(1.0, self.ak + 0.25)]))[0])
                air.put(x, y, CR if j < 3 else C(col), fa)
        air.plus(gx, gy, 2, CR, [CR, CR], 1.0)
        self._motes = []
        for ang, L, vis, i in self.rays(t):
            if vis <= 0.0:
                continue
            col = RB[(i * 2 + 1) % 6]
            a0, a1 = flow_ends(ang, L, start=8.0)
            I, J, s, d, Lr = beam_grid(air, a0, a1, 3.0)
            s = np.floor(s) + 0.5
            d = np.floor(d + 0.5)
            ad = np.abs(d)
            fade, _ = fade_along(s, Lr)
            inside = (s >= 0.0) & (s <= Lr) & (ad <= 1.0)
            rgb = np.where((ad < 0.5)[:, None], CREAM, np.tile(col, (len(s), 1)))
            rgb = wave_band(rgb, s, Lr, age_tick)
            a = np.where(ad < 0.5, 1.0, 0.5) * fade * vis * self.ak
            lay_over(air, I, J, rgb.astype(np.float32), q8(np.where(inside, a, 0.0)).astype(np.float32))
            for j in range(3):
                fr = (t * 1.4 + j / 3.0 + i * 0.21) % 1.0
                al = vis * (1.0 if fr < 0.4 else max(0.0, (1.0 - fr) / 0.6)) * min(1.0, self.ak + 0.2)
                if al > 0.05:
                    self._motes.append((lerp(a0, a1, fr), (i * 2 + j) % 6, fr, al))

    # --- C2: C + D'nin dönen yıldızı (küçük, hafif); C3: + konilerde dışa akıp sönen parıltılar
    # (kullanıcı: "C ye D deki yıldız efektlerinden ekler misin biraz")
    def _star(self, air, t, k=0.9):
        # D'nin yıldızı (4,5-9,5 ve D boyu 6-14 px ana ışının ucundaki parlamanın altında kayboluyordu -> uzun kol 11-18, kısa 4-11, açık renk)
        gx, gy = air.tc(*S0)
        for i in range(8):
            an = math.radians(i * 45.0) + t * 0.7
            ln = (15.0 if i % 2 == 0 else 8.0) + 3.5 * math.sin(t * 6.0 + i * 1.7)  # uzun kollar vuruş parlamasının (~12 px) dışına taşar
            col = RBL[(i + int(t * 3)) % 6] if i % 2 == 0 else RB[(i + int(t * 3)) % 6]
            for j in range(int(ln)):
                x = gx + int(round(math.cos(an) * (j + 3)))
                y = gy + int(round(math.sin(an) * (j + 3)))
                fa = float(q8(np.array([(1.0 - (j / ln) ** 2) * k]))[0])  # sönüş uca ertelenir (doğrusalda dış yarı kayboluyordu)
                air.put(x, y, CR if j < (5 if i % 2 == 0 else 3) else C(col), fa)
        air.plus(gx, gy, 2, CR, [CR, CR], 1.0)

    def _C2(self, air, t, age_tick):
        self._C(air, t, age_tick)
        self._star(air, t)

    def _C3(self, air, t, age_tick):
        self._C(air, t, age_tick)
        self._star(air, t)
        self._motes = []
        for ang, L, vis, i in self.rays(t):
            if vis <= 0.0:
                continue
            a0, a1 = flow_ends(ang, L)
            for j in range(2):
                fr = (t * 1.1 + j * 0.5 + i * 0.23) % 1.0
                al = vis * (0.9 if fr < 0.35 else max(0.0, 0.9 * (1.0 - fr) / 0.65))
                if al > 0.05:
                    self._motes.append((lerp(a0, a1, fr * 0.85), (i * 2 + j) % 6, fr, al))

    def sprites(self, F, view):
        if self.did not in ("D", "C3"):
            return
        for pos, ci, fr, al in self._motes:
            blit2(F, SPARK[ci][0 if fr < 0.5 else 1], (pos[0] - view[0]) * Z, (pos[1] - view[1]) * Z, Z, alpha=al)


FLOW_INFO = {
    "A": ("A · Ayna Işınları", "hep açık, gezinir, uçta incelip söner"),
    "B": ("B · Prizma Tayfı", "hep açık, renk yönle akar, uçta söner"),
    "C": ("C · Işık Konileri", "hep açık yarı saydam hüzme, uçta erir"),
    "D": ("D · Parlama Yıldızı", "dönen yıldız + gezinen iplik, akan parıltı"),
}

NEFES_INFO = {
    "C2": ("C + yıldız", "konilerin ortasında D'nin dönen yıldızı (küçük)"),
    "C3": ("C + yıldız + parıltı", "+ konilerde dışa akıp sönen parıltılar"),
    "A": ("A · Ayna Işınları", "yerinde uzayıp kısalır, uçta incelip söner"),
    "B": ("B · Prizma Tayfı", "uzayıp kısalır, renk yönden, uçta söner"),
    "C": ("C · Işık Konileri", "yarı saydam hüzme uzayıp kısalır, uçta erir"),
    "D": ("D · Parlama Yıldızı", "dönen yıldız + uzayıp kısalan iplik"),
}


def run_flow(did, want_times=None, mode="akis"):
    sty = Flow(did, mode)
    fo = AP.Follow(KEY, ang=0.0)
    st0 = {"t": 0.0, "P": SP_P, "V": (0.0, 0.0), "moving": False, "face": (1, 0), "walk_t": 0.0}
    spk = Sparks(77, 24.0, 6.0)
    for _ in range(60):
        fo.step(dict(st0), aim=S0)
    n = int(round(RF_LOOP * FPS))
    dt = 1.0 / FPS
    slimes = [(S0, 0)] + [(nn, k + 1) for k, nn in enumerate(SC_STATIC)] + [(OUTSIDE, 4)]
    frames, snaps = [], {}
    for lap in range(2):
        for i in range(n):
            t = i * dt
            st = dict(st0, t=t)
            pos, rot, tip = fo.step(st, aim=S0)
            L = max(1.0, math.hypot(S0[0] - tip[0], S0[1] - tip[1]))
            spk.step(tip, S0, L, dt)
            if lap == 0:
                continue
            want = want_times is None or any(abs(t - w) < dt * 0.5 for w in want_times)
            if not want:
                continue
            tk = [x for x in RF_TICKS if x <= t]
            age = t - tk[-1] if tk else t + (RF_LOOP - RF_TICKS[-1])
            flashes = {0: (age, 1.0)}
            for k in range(len(SC_STATIC)):
                flashes[k + 1] = (age, 0.4)
            F = AP.bg_crop(Z, SP_VIEW)
            air = AP.Layer(SP_VIEW[0], SP_VIEW[1], SP_VIEW[2] - SP_VIEW[0], SP_VIEW[3] - SP_VIEW[1], tx=1.0)
            fx = AP.Layer(SP_VIEW[0], SP_VIEW[1], SP_VIEW[2] - SP_VIEW[0], SP_VIEW[3] - SP_VIEW[1], tx=1.0)
            sty.draw(fx, F, t, age)
            draw_world(F, SP_VIEW, slimes, flashes, st)
            AP.draw_staff(F, Z, SP_VIEW, KEY, pos, rot, st["P"])
            beam_now(air, tip, S0, t, 6.0)
            tip_flare(air, tip, t)
            air.composite(F, Z)
            spk.draw(F, SP_VIEW)
            draw_impact(F, SP_VIEW, S0, age)
            fx.composite(F, Z)
            sty.sprites(F, SP_VIEW)
            im = Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")
            title, sub = (NEFES_INFO if mode == "nefes" else FLOW_INFO)[did]
            im = AP.tile_label(im, title, sub)
            if want_times is None:
                frames.append(im)
            else:
                snaps[round(t, 3)] = im
    return frames if want_times is None else snaps


def build_flow(mode="akis"):
    runs = [run_flow(d, mode=mode) for d in "ABCD"]
    frames = []
    for parts in zip(*runs):
        g = grid2(list(parts))
        if mode == "nefes":
            hd = header(g.width, "Gökkuşağı Asası · NEFES prototipleri (saçılma v5, kesintisiz; oyuna bağlı değil)",
                        "1080p oyun ölçeği · ışınlar savrulmaz: kendi yönünde uzayıp kısalır, kısalınca yeni rastgele yönden uzar · "
                        "uçlar incelip söner · 60 px içindeki komşulara yarım hasar")
        else:
            hd = header(g.width, "Gökkuşağı Asası · AKIŞ prototipleri (saçılma v4, kesintisiz; oyuna bağlı değil)",
                        "1080p oyun ölçeği · ışın değdikçe vurulandan hep açık, rastgele gezinen ışınlar · uçlar incelip söner · "
                        "60 px içindeki komşulara yarım hasar")
        frames.append(stack_v([hd, g], 0))
    save_gif(frames, os.path.join(OUT, "%s.gif" % mode), FPS, [2, 20, 40, 60])
    times = [round(round(x * FPS) / FPS, 3) for x in (0.40, 1.40, RF_TICKS[4] + 0.04)]
    rows = []
    for d in "ABCD":
        sn = run_flow(d, times, mode)
        rows.append(AP.hstack([sn[k] for k in sorted(sn)]))
    g = stack_v(rows, 4)
    hd = header(g.width, "Gökkuşağı Asası · %s · üç ayrı an (sağda hasar tiki dalgası)" % mode.upper(),
                "A Ayna Işınları · B Prizma Tayfı · C Işık Konileri · D Parlama Yıldızı (1080p ölçeği)")
    stack_v([hd, g], 0).save(os.path.join(OUT, "ozet_%s.png" % mode))
    print(mode, "ok")


def build_cstar():
    runs = [run_flow(d, mode="nefes") for d in ("C", "C2", "C3")]
    frames = []
    for parts in zip(*runs):
        row = AP.hstack(list(parts))
        hd = header(row.width, "Gökkuşağı Asası · C Işık Konileri + D'nin yıldızı (oyuna bağlı değil)",
                    "1080p oyun ölçeği · solda bugünkü C, ortada + küçük dönen yıldız, sağda + konilerde akan parıltılar")
        frames.append(stack_v([hd, row], 0))
    save_gif(frames, os.path.join(OUT, "c_yildiz.gif"), FPS, [2, 20, 40, 60])
    times = [round(round(x * FPS) / FPS, 3) for x in (0.40, 1.40)]
    rows = []
    for d in ("C", "C2", "C3"):
        sn = run_flow(d, times, "nefes")
        rows.append([sn[k] for k in sorted(sn)])
    cols = [AP.hstack([r[j] for r in rows]) for j in range(2)]
    g = stack_v(cols, 4)
    hd = header(g.width, "Gökkuşağı Asası · C + yıldız · iki ayrı an", "C · C + yıldız · C + yıldız + parıltı (1080p ölçeği)")
    stack_v([hd, g], 0).save(os.path.join(OUT, "ozet_c_yildiz.png"))
    print("c_yildiz ok")


def build_final_rings():
    runs = [run_final(d) for d in ("A2", "A3")]
    frames = []
    for parts in zip(*runs):
        row = AP.hstack(list(parts))
        hd = header(row.width, "Gökkuşağı Asası · FİNAL: A Lux Huzmesi + D'nin halkaları, rengarenk (oyuna bağlı değil)",
                    "1080p oyun ölçeği · solda her halka rastgele ve farklı renk, sağda her halka kendi içinde gökkuşağı · halkalar her 0,5 sn vuruşta asadan uca koşar")
        frames.append(stack_v([hd, row], 0))
    n = len(frames)
    save_gif(frames, os.path.join(OUT, "final_a_halka.gif"), FPS, [1, 8, 20, int(n * 0.83)])
    times = [round(round(x * FPS) / FPS, 3) for x in (0.08, TICKS[2] + 0.12, TICKS[2] + 0.32)]
    rows = []
    for d in ("A2", "A3"):
        sn = run_final(d, times)
        rows.append(stack_v([sn[k] for k in sorted(sn)], 4))
    g = AP.hstack(rows)
    hd = header(g.width, "Gökkuşağı Asası · FİNAL A + halkalar · yukarıdan aşağı: gönderiliş / vuruştan 0,12 sn / 0,32 sn sonra",
                "sol halkalar rastgele renk · sağ halka içinde gökkuşağı (1080p ölçeği)")
    stack_v([hd, g], 0).save(os.path.join(OUT, "ozet_final_a_halka.png"))
    print("final_a_halka ok")


def build_secim():
    """Seçilen ikili tek GIF'te: üstte FİNAL A + rastgele renkli halkalar, altta SAÇILMA C + yıldız (ikisi de 3 sn döngü)."""
    fin = run_final("A2")  # kullanıcı belirgin (A4) yerine ince halkaları seçti
    spl = run_flow("C2", mode="nefes")
    frames = []
    for a, b in zip(fin, spl):
        W = max(a.width, b.width)
        low = Image.new("RGB", (W, b.height), (18, 20, 20))
        low.paste(b, ((W - b.width) // 2, 0))
        body = stack_v([a, low], 4)
        hd = header(body.width, "Gökkuşağı Asası · SEÇİLENLER (prototip, oyuna bağlı değil)",
                    "üstte FİNAL: A Lux Huzmesi + rastgele renkli halkalar · altta SAÇILMA: C Işık Konileri + yıldız · 1080p oyun ölçeği")
        frames.append(stack_v([hd, body], 0))
    save_gif(frames, os.path.join(OUT, "secim.gif"), FPS, [2, 20, 40, 60])
    print("secim ok")


def build_ring_bold():
    runs = [run_final(d) for d in ("A2", "A4")]
    frames = []
    for parts in zip(*runs):
        body = stack_v(list(parts), 4)
        hd = header(body.width, "Gökkuşağı Asası · FİNAL halka atışları: üstte şimdiki (ince), altta BELİRGİN (oyuna bağlı değil)",
                    "1080p oyun ölçeği · her 0,5 sn vuruşta asadan 3 halka fırlar ve ışın boyunca düşmanlara koşar · renkler rastgele")
        frames.append(stack_v([hd, body], 0))
    save_gif(frames, os.path.join(OUT, "halka_belirgin.gif"), FPS, [2, 20, 40, 60])
    print("halka_belirgin ok")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    what = sys.argv[1:] or ["sacilma", "final", "ozet", "yansima", "rastgele", "akis", "nefes"]
    if "akis" in what:
        build_flow("akis")
    if "nefes" in what:
        build_flow("nefes")
    if "cyildiz" in what:
        build_cstar()
    if "ahalka" in what:
        build_final_rings()
    if "secim" in what:
        build_secim()
    if "hbelirgin" in what:
        build_ring_bold()
    if "rastgele" in what:
        build_scatter()
    if "yansima" in what:
        build_reflect()
    if "ozet" in what:
        build_ozet()
    if "sacilma" in what:
        build_splash_gif()
    if "final" in what:
        build_final_gif()
