# -*- coding: utf-8 -*-
"""LICH BÜYÜLÜ ATIŞI prototipleri (2026-10-19, oyuna bağlı DEĞİL). Kullanıcı: "lichlerin büyülü atışlarını yeniden tasarla".

ŞU AN (teşhis): Lich 1/2/3 Demon/İblis/Röntgen ile AYNI mermiyi atar (`enemy_projectile.tscn` + `fx_projectile_orb.gd`: katmanlı piksel
küre + 3 piksel iz), sadece `projectile_tint` farklı: limon yeşili (0,5, 1, 0,55). Lich sprite'larının asa ucu parlaması ise TURKUAZ
(#30f9c2 / #2ab1b7 / #25849c) - renk uyuşmuyor. Ayrıca mermi saldırı klibinin 0. karesinde yaratığın merkezinden çıkar; asadaki
büyü parlaması 5-6. karede (8 kare / 8,6 fps -> ~0,6 sn SONRA) gelir: mermi ~125 dünya px uzaktayken asa parlıyor.
İki atış var: büyü (`_fire_ranged_attack`, asıl atış) + normal atış (`_fire_homing_attack`, aynı küre `lightened(0.35)`).

Dört yön (hepsi lich'in kendi turkuaz + kemik paletiyle, 1 sanat px = PixelDraw.TEXEL 1,212 dünya px ~ lich pikseli 1,230):
  A Ruh Alevi      - turkuaz hayalet ateşi: titreyen baş + dalgalanan 3 dil, arkasında yükselen kor; isabet = alev sıçraması
  B Çığlık Kafatası - küçük kemik kafatası (parlayan göz, çene açılıp kapanır) + dalgalanan ruh kuyruğu; isabet = kafatası kırılır
  C Rün Yıldızı    - asadaki parlamanın kendisi: dönen 4 köşeli yıldız + ters dönen kesik rün halkası + 2 ardıl yıldız
  D Kemik Mızrağı  - sivri kemik kıymığı + etrafında sarmal iki turkuaz iplik; isabet = kemik kıymıkları + mühür halkası
Normal atış her yönde aynı dilin KÜÇÜK, sade hâli (büyüden ayırt edilsin). Lich 2 / 3 için isteğe bağlı ince ayrım: dış hat lacivert
(Lich 2 zırhı) / altın (Lich 3 tacı) - çekirdek hep turkuaz (asa parlaması üçünde de aynı).
Yeni şeritlerde mermi ASA UCUNDAN ve klibin parlama karesinde (6) çıkar (öneri: klip 6. kareden başlar -> oynanış zamanı değişmez).

Çıktılar (out/lich_mermi/, .gdignore): lich_mermi_karsilastirma.png (1080p oyun ölçeği, uçuşun ortası), lich_mermi_oyun.gif (5 şerit,
25 fps, 2,8 sn döngü), lich_mermi_detay.png (kareler x4 + 8 yön oyun ölçeğinde + Lich 1/2/3 ayrımı).
Çalıştırma: python tools/proto_20261019/lich_mermi_proto.py [kars|gif|detay]   (argümansız: hepsi)
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(HERE, "out", "lich_mermi")

TEXEL = 1.212  # PixelDraw.TEXEL (dünya px / sanat px)
ZOOM = 2.0  # 1080p: 1 dünya px = 2 ekran px
S = TEXEL * ZOOM  # ekran px / sanat px
LICH_K = 1.52325 * 0.95 * 0.85  # lich Sprite2D ölçeği x EntityScale.SIZE
LICH_OFF_Y = -7.8  # Sprite2D offset (doku px)
CHAR_K = 2.2368375 * 0.8075 * 0.5  # Elara dünya px / karakter px (mermi_proto ile aynı)
SPEED = 208.0 * ZOOM  # ekran px / sn (enemy_projectile.gd speed)
LICH_FPS = 8.6
FPS = 25
LOOP = 2.8


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


def ramp(s):
    return [hx(c) for c in s.split()]


TEAL = ramp("#0b2427 #114641 #1a6b66 #23959a #2fc4c0 #3cf0cb #a6ffe4 #f4fff9")
BONE = ramp("#25201f #5b4d40 #8d8373 #aaa290 #d2cebc #edebdb")
# Lich 2 lacivert zırh / Lich 3 altın taç: sadece dış katmanlar (rim, out) + kıvılcım
TIERS = {
    1: dict(rim=TEAL[1], out=TEAL[2], mid=TEAL[3], spark=TEAL[6]),
    2: dict(rim=hx("#1b1f40"), out=hx("#34407a"), mid=hx("#4f6aa8"), spark=hx("#b6caf0")),
    3: dict(rim=hx("#4a1a0c"), out=hx("#9a6a2a"), mid=hx("#d4af56"), spark=hx("#f6e48a")),
}


def mix(a, b, k):
    return tuple(int(round(a[i] + (b[i] - a[i]) * k)) for i in range(3)) + (255,)


# ------------------------------------------------------------------ tuval (sanat pikseli)
class Cv:
    def __init__(self, w=64, h=48):
        self.w, self.h = w, h
        self.cx, self.cy = w // 2, h // 2
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.p = self.im.load()

    def put(self, x, y, c, a=1.0):
        if c is None:
            return
        X, Y = int(math.floor(x)) + self.cx, int(math.floor(y)) + self.cy
        if not (0 <= X < self.w and 0 <= Y < self.h):
            return
        ca = c[3] / 255.0 * a
        if ca >= 0.999:
            self.p[X, Y] = c[:3] + (255,)
            return
        d = self.p[X, Y]
        da = d[3] / 255.0
        oa = ca + da * (1 - ca)
        if oa <= 0:
            return
        rgb = tuple(int(round((c[i] * ca + d[i] * da * (1 - ca)) / oa)) for i in range(3))
        self.p[X, Y] = rgb + (int(round(oa * 255)),)

    def get(self, x, y):
        X, Y = x + self.cx, y + self.cy
        if 0 <= X < self.w and 0 <= Y < self.h:
            return self.p[X, Y]
        return (0, 0, 0, 0)

    def field(self, fn, ang=0.0):
        """fn(u, v) -> renk|None; (u, v) mermi çerçevesi (+u uçuş yönü), piksel merkezinden döndürülmüş."""
        c, s = math.cos(ang), math.sin(ang)
        for j in range(self.h):
            for i in range(self.w):
                x, y = i - self.cx + 0.5, j - self.cy + 0.5
                u, v = x * c + y * s, -x * s + y * c
                col = fn(u, v, x, y)
                if col is not None:
                    self.p[i, j] = col

    def outline(self, col, only_empty=True):
        src = self.im.copy().load()
        for j in range(self.h):
            for i in range(self.w):
                if src[i, j][3] > 0:
                    continue
                for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ii, jj = i + di, j + dj
                    if 0 <= ii < self.w and 0 <= jj < self.h and src[ii, jj][3] > 200:
                        self.p[i, j] = col
                        break


def ascii_draw(cv, rows, legend, ox, oy, flip=False):
    for j, row in enumerate(rows):
        n = len(row)
        for i, ch in enumerate(row):
            c = legend.get(ch)
            if c is not None:
                x = (n - 1 - i) if flip else i
                cv.put(ox + x, oy + j, c)


# ------------------------------------------------------------------ ŞU AN (fx_projectile_orb.gd'nin birebir kopyası, sanat px)
NOW_TINT = (0.5, 1.0, 0.55)


def gcol(rgb, a=1.0):
    return (int(rgb[0] * 255), int(rgb[1] * 255), int(rgb[2] * 255), int(a * 255))


def lighten(rgb, k):
    return tuple(c + (1 - c) * k for c in rgb)


def pd_disc(cv, r, col):
    rt = int(r)
    for iy in range(-rt, rt + 1):
        hw = math.sqrt(max(0.0, rt * rt - iy * iy))
        if hw < 0.5:
            continue
        for ix in range(int(math.floor(-hw)), int(math.ceil(hw))):
            cov = min(ix + 1, hw) - max(ix, -hw)
            if cov > 0.5:
                cv.put(ix, iy, col)


def pd_px(cv, x, y, n, col):
    x0, y0 = round(x - n * 0.5), round(y - n * 0.5)
    for j in range(n):
        for i in range(n):
            cv.put(x0 + i, y0 + j, col)


def now_shot(ang, f, normal=False):
    cv = Cv()
    c = lighten(NOW_TINT, 0.35) if normal else NOW_TINT
    dx, dy = math.cos(ang), math.sin(ang)
    for i in range(3):
        d = 6.0 + i * 2.5
        pd_px(cv, -dx * d, -dy * d, 2 if i == 0 else 1, gcol(c, 0.55 - i * 0.17))
    pd_disc(cv, 5.0, gcol(c, 0.3))
    pd_disc(cv, 3.5, gcol(c, 0.85))
    hot = lighten(c, 0.45)
    pd_disc(cv, 2.0, gcol(hot, 0.95))
    pd_px(cv, 0, 0, 2, gcol((1, 1, 1), 0.95))
    for k in range(4):
        a = math.pi * 0.25 + k * math.pi * 0.5
        pd_px(cv, math.cos(a) * 5, math.sin(a) * 5, 1, gcol(hot, 0.5))
    return cv.im


def now_impact(t, normal=False):
    LIFE = 0.28
    if t >= LIFE:
        return None
    cv = Cv()
    c = lighten(NOW_TINT, 0.35) if normal else NOW_TINT
    p = t / LIFE
    eo = 1 - (1 - p) * (1 - p)
    fade = 1 - p
    hot = lighten(c, 0.45)
    if p < 0.35:
        pd_px(cv, 0, 0, 3, gcol(hot, 0.9 * (1 - p / 0.35)))
    rr = (4.0 + 14.0 * eo) / TEXEL
    for k in range(8):
        a = k * math.pi / 4
        pd_px(cv, math.cos(a) * rr, math.sin(a) * rr, 1, gcol(c, fade * 0.9))
    for i in range(6):
        a = math.pi / 8 + i * 1.047
        d = (5.0 + (16.0 + (i % 3) * 4.0) * eo) / TEXEL
        pd_px(cv, math.cos(a) * d, math.sin(a) * d, 1, gcol(hot, fade))
    return cv.im


# ------------------------------------------------------------------ A RUH ALEVİ
def flame_fn(f, nf, head_r, tongues, pal, core_r):
    ph0 = 2 * math.pi * f / nf
    Lmax = max(t[0] for t in tongues)

    def depth(u, v):
        d = head_r - math.hypot(u * 0.92, v)
        for (L, yo, amp, ph, w0) in tongues:
            Lf = L * (1.0 + 0.13 * math.sin(ph0 * 2 + ph))
            if -Lf <= u <= 0.6:
                t = max(0.0, -u) / Lf
                cy = yo * t + amp * math.sin(ph + ph0 - u * 0.55) * t
                hw = w0 * (1 - t) ** 0.85
                d = max(d, hw - abs(v - cy))
        return d

    def fn(u, v, x, y):
        d = depth(u, v)
        if d < -0.85:
            return None
        tf = min(1.0, max(0.0, -u) / Lmax)
        if d < 0:
            return pal["rim"] if tf < 0.75 else None
        dc = core_r - math.hypot(u - 0.9, v)
        if dc > 0:
            return TEAL[7]
        if dc > -0.9:
            return TEAL[6]
        lev = d - tf * 1.6
        if lev >= 1.3:
            return TEAL[5]
        if lev >= 0.55:
            return TEAL[4]
        if lev >= 0.0:
            return TEAL[3] if tf < 0.5 else pal["mid"]
        return pal["out"]

    return fn


A_NF = 6


def A_shot(ang, f, normal=False, tier=1):
    pal = TIERS[tier]
    cv = Cv()
    if normal:
        fn = flame_fn(f, A_NF, 2.3, [(6.5, 0.0, 0.9, 0.0, 1.9)], pal, 0.9)
    else:
        fn = flame_fn(f, A_NF, 3.5, [(15.0, 0.0, 1.5, 0.0, 2.6), (10.0, -3.2, 1.6, 1.9, 1.5), (11.0, 3.0, 1.6, 3.6, 1.5)], pal, 1.4)
    cv.field(fn, ang)
    return cv.im


def A_impact(t, normal=False, tier=1):
    pal = TIERS[tier]
    LIFE = 0.36 if not normal else 0.26
    if t >= LIFE:
        return None
    p = t / LIFE
    cv = Cv()
    k = 0.6 if normal else 1.0
    # yukarı kıvrılan 5 alev dili (ruh ateşi yükselir)
    for i, (a0, L0) in enumerate(((-90, 9), (-130, 7), (-50, 7), (-165, 5), (-15, 5))):
        a = math.radians(a0)
        L = L0 * k * (0.5 + 0.9 * p) * (1.0 - 0.2 * p)
        w0 = 1.9 * k * (1 - p)
        if w0 < 0.35:
            continue
        r0 = 1.5 * k + 3 * p * k
        bx, by = math.cos(a) * r0, math.sin(a) * r0

        def fn(u, v, x, y, L=L, w0=w0, bx=bx, by=by, a=a):
            uu, vv = (x - bx) * math.cos(a) + (y - by) * math.sin(a), -(x - bx) * math.sin(a) + (y - by) * math.cos(a)
            if not (0 <= uu <= L):
                return None
            tt = uu / max(L, 0.1)
            hw = w0 * (1 - tt) ** 0.8 + 0.2
            dd = hw - abs(vv - math.sin(tt * 3 + i) * 0.6 * tt)
            if dd < 0:
                return None
            if dd > 0.9 and tt < 0.4:
                return TEAL[6]
            return TEAL[5] if tt < 0.55 else (TEAL[4] if tt < 0.8 else pal["mid"])

        cv.field(fn)
    # merkez parlama
    if p < 0.4:
        r = (3.6 - p * 6) * k
        cv.field(lambda u, v, x, y: (TEAL[7] if math.hypot(x, y) < r * 0.55 else TEAL[6]) if math.hypot(x, y) < r else None)
    # taban halkası (yere yayılan)
    rr = (3 + 7 * p) * k
    for i in range(16):
        a = i * math.pi / 8
        if (i + int(p * 4)) % 3 == 0:
            continue
        cv.put(math.cos(a) * rr, math.sin(a) * rr * 0.5 + 2, pal["mid"] if p < 0.6 else pal["out"])
    return cv.im


# ------------------------------------------------------------------ B ÇIĞLIK KAFATASI
SKULL_C = [
    "..ooooo..",
    ".oHHhhho.",
    "oHhhhhhbo",
    "ohEEhEEbo",
    "ohEEhEEbo",
    "obhhnhhbo",
    ".obhhhbo.",
    ".otbtbto.",
    "..ooooo..",
]
SKULL_O = [
    "..ooooo..",
    ".oHHhhho.",
    "oHhhhhhbo",
    "ohEEhEEbo",
    "ohEEhEEbo",
    "obhhnhhbo",
    ".obhhhbo.",
    ".ommmmmo.",
    ".otbtbto.",
    "..ooooo..",
]
B_NF = 6


def wisp_fn(f, nf, L, w0, amp, pal, rim=True):
    ph0 = 2 * math.pi * f / nf

    def fn(u, v, x, y):
        if u > 1.5 or u < -L:
            return None
        t = (1.5 - u) / (L + 1.5)
        cy = amp * math.sin(ph0 - u * 0.5) * t
        hw = w0 * (1 - t) ** 0.8 + 0.35
        d = hw - abs(v - cy)
        if d < 0:
            return pal["rim"] if (rim and d > -0.85 and t < 0.55) else None
        lev = d - t * 1.4
        if lev >= 1.4:
            return TEAL[5]
        if lev >= 0.6:
            return TEAL[4]
        if lev >= 0:
            return TEAL[3] if t < 0.55 else pal["mid"]
        return pal["out"]

    return fn


def B_shot(ang, f, normal=False, tier=1):
    pal = TIERS[tier]
    cv = Cv()
    if normal:
        cv.field(wisp_fn(f, B_NF, 7.0, 2.0, 1.2, pal), ang)
        cv.field(lambda u, v, x, y: (TEAL[7] if math.hypot(u - 0.3, v) < 1.0 else TEAL[5]) if math.hypot(u, v) < 2.2 else None, ang)
        return cv.im
    cv.field(wisp_fn(f, B_NF, 14.0, 3.8, 1.7, pal), ang)
    flip = math.cos(ang) < -0.01
    open_ = f >= 3
    rows = SKULL_O if open_ else SKULL_C
    eye = TEAL[7] if f % 2 == 0 else TEAL[6]
    leg = {"o": BONE[0], "H": BONE[5], "h": BONE[4], "b": BONE[3], "n": BONE[1], "t": BONE[1], "E": eye, "m": TEAL[5]}
    oy = -4 - (1 if open_ else 0) + (1 if f in (1, 2) else 0)  # hafif süzülme
    ascii_draw(cv, rows, leg, -4, oy, flip)
    return cv.im


def B_impact(t, normal=False, tier=1):
    pal = TIERS[tier]
    LIFE = 0.4 if not normal else 0.26
    if t >= LIFE:
        return None
    p = t / LIFE
    cv = Cv()
    # turkuaz ruh dumanı: genişleyen düz bant halkası
    r1 = (2.5 + 6.5 * p) * (0.6 if normal else 1.0)
    r0 = r1 - (2.2 * (1 - p) + 0.6)
    cv.field(lambda u, v, x, y: (TEAL[4] if p < 0.4 else (TEAL[3] if p < 0.7 else pal["out"])) if r0 <= math.hypot(x, y * 1.15) <= r1 else None)
    if normal:
        return cv.im
    if p < 0.2:  # kafatası beyaz parlar
        ascii_draw(cv, SKULL_C, {"o": TEAL[6], "H": TEAL[7], "h": TEAL[7], "b": TEAL[7], "n": TEAL[6], "t": TEAL[6], "E": TEAL[5]}, -4, -4)
    else:  # 4 kemik parçası savrulur + iki göz ışığı yükselip söner
        q = (p - 0.2) / 0.8
        for (ax, ay, sx) in ((-1, -1, 3), (1, -1, 3), (-1, 0.6, 2), (1, 0.6, 2)):
            px_, py_ = ax * (2 + 7 * q), ay * (2 + 5 * q) + 9 * q * q
            for k in range(sx):
                cv.put(px_ + k * ax * 0.6, py_, BONE[4] if k == 0 else BONE[3])
            cv.put(px_, py_ + 1, BONE[0])
        if q < 0.7:
            for ex in (-2, 2):
                cv.put(ex, -1 - 6 * q, TEAL[7] if q < 0.35 else TEAL[5])
    return cv.im


# ------------------------------------------------------------------ C RÜN YILDIZI
C_NF = 6


def astro(u, v, R, a):
    c, s = math.cos(a), math.sin(a)
    x, y = u * c + v * s, -u * s + v * c
    return abs(x) ** 0.5 + abs(y) ** 0.5 <= R ** 0.5


def star_fn(R, a, pal, ring=None, ring_a=0.0, dim=0):
    lv = [TEAL[2 - dim if dim < 2 else 1], TEAL[4 - dim], TEAL[5 - dim], TEAL[6 - dim], TEAL[7 - dim]]

    def fn(u, v, x, y):
        if ring is not None:
            r = math.hypot(u, v)
            if ring[0] <= r <= ring[1]:
                th = (math.atan2(v, u) - ring_a) % (math.pi / 2)
                if th < math.radians(52):
                    return pal["mid"] if th < math.radians(8) or th > math.radians(44) else TEAL[4]
        if not astro(u, v, R * 1.2, a):
            return None
        if math.hypot(u, v) < R * 0.2:
            return lv[4]
        if astro(u, v, R * 0.38, a):
            return lv[3]
        if astro(u, v, R * 0.62, a):
            return lv[2]
        if astro(u, v, R * 0.88, a):
            return lv[1]
        return pal["out"] if dim == 0 else lv[0]

    return fn


def C_shot(ang, f, normal=False, tier=1):
    pal = TIERS[tier]
    cv = Cv()
    spin = f * math.pi / 2 / C_NF  # 6 karede 90 derece (4 kat simetri)
    dx, dy = math.cos(ang), math.sin(ang)
    if normal:
        g = star_fn(2.8, spin, pal, dim=1)
        cv.field(lambda u, v, x, y: g(x + dx * 6, y + dy * 6, 0, 0))
        cv.field(star_fn(4.6, spin, pal))
        return cv.im
    for (d, R, dim) in ((13, 3.4, 2), (7.5, 4.8, 1)):  # ardıl yıldızlar (geride kalan iz)
        g = star_fn(R, spin - 0.3, pal, dim=dim)
        cv.field(lambda u, v, x, y, g=g, d=d: g(x + dx * d, y + dy * d, 0, 0))
    cv.field(star_fn(6.4, spin, pal, ring=(6.3, 7.3), ring_a=-spin * 1.4))
    return cv.im


def C_impact(t, normal=False, tier=1):
    pal = TIERS[tier]
    LIFE = 0.34 if not normal else 0.24
    if t >= LIFE:
        return None
    p = t / LIFE
    k = 0.6 if normal else 1.0
    cv = Cv()
    # asa parlamasının aynısı: dikey uzun, yatay kısa artı; açılır sonra incelir
    up = math.sin(min(1.0, p * 2.2) * math.pi * 0.5) * (1 - max(0.0, p - 0.45) / 0.55)
    LV, LH = 11 * k * up, 7 * k * up
    for i in range(-int(LV), int(LV) + 1):
        c = TEAL[7] if abs(i) < LV * 0.3 else (TEAL[6] if abs(i) < LV * 0.65 else TEAL[4])
        cv.put(0, i, c)
        if abs(i) < LV * 0.35:
            cv.put(-1, i, TEAL[5])
            cv.put(1, i, TEAL[5])
    for i in range(-int(LH), int(LH) + 1):
        c = TEAL[7] if abs(i) < LH * 0.3 else (TEAL[6] if abs(i) < LH * 0.65 else TEAL[4])
        cv.put(i, 0, c)
        if abs(i) < LH * 0.35:
            cv.put(i, -1, TEAL[5])
            cv.put(i, 1, TEAL[5])
    # kesik halka dışa açılır
    rr = (3 + 9 * p) * k
    for i in range(24):
        a = i * math.pi / 12 + p
        if i % 3 == 2:
            continue
        cv.put(math.cos(a) * rr, math.sin(a) * rr, pal["mid"] if p < 0.55 else pal["out"])
    # köşegen kıvılcımlar
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        d = (3 + 8 * p) * k
        if p < 0.85:
            cv.put(math.cos(a) * d, math.sin(a) * d, pal["spark"])
    return cv.im


# ------------------------------------------------------------------ D KEMİK MIZRAĞI
D_NF = 6


def bone_in(u, v, small):
    v -= 0.5  # tek sayıda satır (açı 0'da piksel merkezleri yarım sayıda)
    if small:
        if -3.0 <= u <= 1.5 and abs(v) <= 0.6:
            return True
        return 1.5 < u <= 3.6 and abs(v) <= 0.6 * (3.6 - u) / 2.1 + 0.05
    if -4.5 <= u <= 2.5 and abs(v) <= 1.1:
        return True
    if 2.5 < u <= 6.6 and abs(v) <= 1.1 * (6.6 - u) / 4.1 + 0.05:
        return True
    for ky in (-1.2, 1.2):  # arka uçta iki boğum (uyluk kemiği)
        if math.hypot(u + 5.3, v - ky) <= 1.3:
            return True
    return False


def D_shot(ang, f, normal=False, tier=1):
    """Temiz kemik kıymığı (iplik kemiğin ÜSTÜNDEN geçmez - geçince çizgili/gürültülü okunuyordu) + boğumlardan çıkan çift sarmal kuyruk."""
    pal = TIERS[tier]
    cv = Cv()
    ph0 = 2 * math.pi * f / D_NF
    cs = math.cos(ang)
    small = normal
    u0 = -3.0 if small else -5.0
    Lt = 7.0 if small else 14.0
    A0 = 1.2 if small else 2.0

    def strands(u, v, x, y):
        if u > u0 + 1.0 or u < u0 - Lt:
            return None
        q = (u0 + 1.0 - u) / (Lt + 1.0)
        amp = A0 * (1 - q * 0.55)
        hit = False
        for k in range(1 if small else 2):
            ph = ph0 + u * 0.8 + k * math.pi
            yv, dy = amp * math.sin(ph), amp * 0.8 * math.cos(ph)
            if abs(v - 0.5 - yv) / math.sqrt(1 + dy * dy) < 0.6:
                hit = True
        if not hit:
            if not small and abs(v - 0.5) < 0.6 and q < 0.65:
                return pal["out"]
            return None
        return TEAL[6] if q < 0.25 else (TEAL[5] if q < 0.5 else (TEAL[4] if q < 0.75 else pal["mid"]))

    cv.field(strands, ang)
    lay = Cv()
    tip = 3.6 if small else 6.6

    def bone(u, v, x, y):
        if not bone_in(u, v, small):
            return None
        if u > tip - 1.3 and abs(v - 0.5) < 0.6:
            return TEAL[6]  # uçta nekrotik parıltı
        sh = (v - 0.5) * cs  # ekran-yukarı ışık
        if sh < -0.5:
            return BONE[5]
        if sh > 0.5:
            return BONE[3]
        return BONE[4]

    lay.field(bone, ang)
    lay.outline(BONE[0])
    cv.im.alpha_composite(lay.im)
    return cv.im


def D_impact(t, normal=False, tier=1):
    pal = TIERS[tier]
    LIFE = 0.38 if not normal else 0.26
    if t >= LIFE:
        return None
    p = t / LIFE
    k = 0.6 if normal else 1.0
    cv = Cv()
    # mühür halkası (zemine yatık elips) + 4 rün çentiği
    rr = (2.5 + 6 * p) * k
    if p < 0.8:
        for i in range(28):
            a = i * math.pi / 14
            cv.put(math.cos(a) * rr, math.sin(a) * rr * 0.55, TEAL[5] if p < 0.4 else pal["mid"])
        for i in range(4):
            a = i * math.pi / 2 + 0.4
            cv.put(math.cos(a) * (rr + 1.5), math.sin(a) * (rr + 1.5) * 0.55, TEAL[6])
    if p < 0.25:
        cv.field(lambda u, v, x, y: TEAL[7] if math.hypot(x, y) < 2.2 * k * (1 - p * 2) + 0.6 else None)
    if not normal:
        rng = random.Random(7)
        for i in range(5):  # kemik kıymıkları
            a = -math.pi * (0.15 + 0.7 * i / 4) + rng.uniform(-0.2, 0.2)
            sp = rng.uniform(6, 10)
            x0, y0 = math.cos(a) * sp * p, math.sin(a) * sp * p + 10 * p * p
            if p < 0.9:
                cv.put(x0, y0, BONE[4])
                cv.put(x0 - math.cos(a), y0 - math.sin(a), BONE[2])
    return cv.im


DIRS = {
    "NOW": dict(name="ŞU AN (Demon ile aynı küre, limon yeşili)", shot=lambda a, f, n=False, t=1: now_shot(a, f, n),
                imp=lambda t, n=False, tr=1: now_impact(t, n), nf=1, afps=1),
    "A": dict(name="A - Ruh Alevi", shot=A_shot, imp=A_impact, nf=A_NF, afps=14),
    "B": dict(name="B - Çığlık Kafatası", shot=B_shot, imp=B_impact, nf=B_NF, afps=10),
    "C": dict(name="C - Rün Yıldızı", shot=C_shot, imp=C_impact, nf=C_NF, afps=16),
    "D": dict(name="D - Kemik Mızrağı", shot=D_shot, imp=D_impact, nf=D_NF, afps=14),
}


# ------------------------------------------------------------------ dünya parçacıkları (iz)
class Pt:
    __slots__ = ("x", "y", "vx", "vy", "age", "life", "cols", "g")

    def __init__(self, x, y, vx, vy, life, cols, g=0.0):
        self.x, self.y, self.vx, self.vy, self.age, self.life, self.cols, self.g = x, y, vx, vy, 0.0, life, cols, g


def emit_for(did, normal):
    """(her kaç ekran px'te bir, üretici) - seyrek + düzensiz (madde 199 tuzak 2)."""
    if did == "A":
        return (26 if not normal else 60), lambda r, x, y, dx, dy: Pt(x - dx * 14 + r.uniform(-4, 4), y + r.uniform(-5, 5), r.uniform(-6, 6),
                                                                 r.uniform(-34, -18), r.uniform(0.35, 0.6), [TEAL[6], TEAL[5], TEAL[3]])
    if did == "B":
        return (34 if not normal else 70), lambda r, x, y, dx, dy: Pt(x - dx * 26 + r.uniform(-3, 3), y + r.uniform(-4, 4), -dx * 8, r.uniform(-10, -2),
                                                                 r.uniform(0.3, 0.5), [TEAL[4], TEAL[3], TEAL[2]])
    if did == "C":
        return (30 if not normal else 64), lambda r, x, y, dx, dy: Pt(x - dx * 10 + r.uniform(-6, 6), y + r.uniform(-6, 6), 0, 0,
                                                                 r.uniform(0.18, 0.3), [TEAL[7], TEAL[6], TEAL[4]])
    if did == "D":
        return (38 if not normal else 80), lambda r, x, y, dx, dy: Pt(x - dx * 8 + r.uniform(-2, 2), y + r.uniform(-2, 2), r.uniform(-8, 8),
                                                                 r.uniform(4, 14), r.uniform(0.25, 0.4), [BONE[4], BONE[3], BONE[2]], g=60)
    return None


def draw_pts(img, pts):
    d = ImageDraw.Draw(img)
    for p in pts:
        k = min(1.0, p.age / p.life)
        c = p.cols[min(len(p.cols) - 1, int(k * len(p.cols)))]
        x, y = math.floor(p.x / S) * S, math.floor(p.y / S) * S
        d.rectangle((round(x), round(y), round(x + S) - 1, round(y + S) - 1), fill=c[:3])


# ------------------------------------------------------------------ ekrana basma
_CACHE = {}


def to_screen(im, k=S):
    w, h = im.size
    return im.resize((max(1, round(w * k)), max(1, round(h * k))), Image.NEAREST)


def paste_c(dst, im, x, y, pivot=None):
    """im'i (x, y) merkezine; pivot = im içindeki merkez (varsayılan orta)."""
    px, py = pivot if pivot else (im.width / 2.0, im.height / 2.0)
    dst.alpha_composite(im, (int(round(x - px)), int(round(y - py)))) if dst.mode == "RGBA" else dst.paste(im, (int(round(x - px)), int(round(y - py))), im)


def snapS(v):
    return math.floor(v / S) * S


def shot_screen(did, ang, f, normal, tier=1):
    key = ("s", did, round(ang, 3), f, normal, tier)
    if key not in _CACHE:
        im = DIRS[did]["shot"](ang, f, normal, tier)
        _CACHE[key] = to_screen(im)
    return _CACHE[key]


def imp_screen(did, t, normal, tier=1):
    fi = int(t * 25)
    key = ("i", did, fi, normal, tier)
    if key not in _CACHE:
        im = DIRS[did]["imp"](fi / 25.0, normal, tier)
        _CACHE[key] = to_screen(im) if im is not None else None
    return _CACHE[key]


# ------------------------------------------------------------------ sahne
LICH_DIR = "visuals/Yaratıklar/Tüm Yaratıklar/Lich %d/PNG/Lich%d/With_shadow/Lich%d_%s_with_shadow.png"
_ASSET = {}


def asset(path, box=None):
    k = (path, box)
    if k not in _ASSET:
        im = Image.open(os.path.join(GAME, path)).convert("RGBA")
        _ASSET[k] = im.crop(box) if box else im
    return _ASSET[k]


def lich_frame(n, sheet, col, row=3):
    return asset(LICH_DIR % (n, n, n, sheet), (col * 64, row * 64, col * 64 + 64, row * 64 + 64))


def staff_tip(n):
    """Saldırı sayfası, sağa bakan satır, 6. kare: turkuaz parlamanın en parlak kümesinin merkezi (doku px, hücre merkezine göre)."""
    im = lich_frame(n, "Attack", 6)
    p = im.load()
    xs, ys = [], []
    for y in range(64):
        for x in range(64):
            r, g, b, a = p[x, y]
            if a > 200 and g > 200 and b > 150 and r < 140:
                xs.append(x)
                ys.append(y)
    return (sum(xs) / len(xs) - 32, sum(ys) / len(ys) - 32) if xs else (14, -6)


def font(sz):
    try:
        return ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", sz)
    except OSError:
        return ImageFont.load_default()


def label(d, x, y, s, sz=14, col=(240, 234, 218)):
    f = font(sz)
    d.text((x + 1, y + 1), s, fill=(20, 24, 20), font=f)
    d.text((x, y), s, fill=col, font=f)


G0, G1, G2, G3 = (108, 152, 88), (118, 160, 94), (98, 141, 82), (88, 128, 74)


def grass(w, h, seed):
    rng = random.Random(seed)
    W, H = w // 2 + 1, h // 2 + 1
    im = Image.new("RGB", (W, H), G0)
    d = ImageDraw.Draw(im)
    for _ in range(W * H // 160):
        x, y, r = rng.randrange(W), rng.randrange(H), rng.randint(3, 8)
        d.ellipse((x - r, y - r * 0.6, x + r, y + r * 0.6), fill=rng.choice([G1, G2]))
    px = im.load()
    for _ in range(W * H // 60):
        x, y = rng.randrange(W), rng.randrange(H)
        if px[x, y] in (G0, G1, G2):
            px[x, y] = G3
    return im.resize((W * 2, H * 2), Image.NEAREST).crop((0, 0, w, h)).convert("RGBA")


LANE_W, LANE_H = 640, 150
LICH_X, LICH_Y = 86, 96  # yaratık düğümü (ekran)
TGT_X, TGT_Y = 566, 116


class Lane:
    def __init__(self, did, idx, tier=1):
        self.did, self.idx, self.tier = did, idx, tier
        self.bg = grass(LANE_W, LANE_H, 31 + idx)
        tip = staff_tip(tier)
        k = LICH_K * ZOOM
        self.tip = (LICH_X + tip[0] * k, LICH_Y + (tip[1] + LICH_OFF_Y) * k)
        self.src = (LICH_X, LICH_Y) if did == "NOW" else self.tip
        self.ang = math.atan2(TGT_Y - 8 - self.src[1], TGT_X - self.src[0])
        self.dist = math.hypot(TGT_X - self.src[0], TGT_Y - 8 - self.src[1])
        self.shots = [(0.15, False), (1.55, True)]  # (atış zamanı, normal mi) - gerçekte 2 sn arayla sırayla
        self.rng = random.Random(idx * 13 + 5)
        self.pts, self.acc, self.last = [], {}, {}

    def lich_img(self, t):
        """Atıştan beri geçen süreye göre saldırı karesi; yoksa bekleme (Idle) döngüsü."""
        for (t0, _n) in self.shots:
            s = (t - t0) % LOOP
            start = 0 if self.did == "NOW" else 6  # yeni: klip parlama karesinden başlar
            fi = start + int(s * LICH_FPS)
            if s >= 0 and fi < 8 and s < 8 / LICH_FPS:
                return lich_frame(self.tier, "Attack", fi)
        return lich_frame(self.tier, "Idle", int(t * LICH_FPS * 0.6) % 4)

    def render(self, t, dt, sim=True):
        im = self.bg.copy()
        k = LICH_K * ZOOM
        li = to_screen(self.lich_img(t), k)
        paste_c(im, li, LICH_X, LICH_Y + LICH_OFF_Y * k)
        el = to_screen(asset("assets/characters/elara/sheets/idle.png", (0, 48 * 2, 48, 48 * 3)), CHAR_K * ZOOM)
        paste_c(im, el, TGT_X, TGT_Y)
        dx, dy = math.cos(self.ang), math.sin(self.ang)
        draw_now = []
        for i, (t0, normal) in enumerate(self.shots):
            s = (t - t0) % LOOP
            trav = SPEED * s
            if trav < self.dist:
                x, y = self.src[0] + dx * trav, self.src[1] + dy * trav
                if sim:
                    em = emit_for(self.did, normal)
                    if em:
                        every, mk = em
                        last = self.last.get(i, trav)
                        if trav < last:
                            last = 0.0
                        a = self.acc.get(i, 0.0) + (trav - last)
                        while a >= every:
                            a -= every * self.rng.uniform(0.6, 1.4)
                            self.pts.append(mk(self.rng, x, y, dx, dy))
                        self.acc[i], self.last[i] = a, trav
                d = DIRS[self.did]
                f = int(s * d["afps"]) % d["nf"]
                draw_now.append((shot_screen(self.did, self.ang, f, normal, self.tier), snapS(x), snapS(y)))
            else:
                self.last[i] = 0.0
                ti = (trav - self.dist) / SPEED
                ii = imp_screen(self.did, ti, normal, self.tier)
                if ii is not None:
                    draw_now.append((ii, snapS(TGT_X), snapS(TGT_Y - 8)))
        if sim:
            keep = []
            for p in self.pts:
                p.age += dt
                if p.age < p.life:
                    p.vy += p.g * dt
                    p.x += p.vx * dt
                    p.y += p.vy * dt
                    keep.append(p)
            self.pts = keep
        draw_pts(im, self.pts)
        for (sp, x, y) in draw_now:
            paste_c(im, sp, x, y)
        return im


ORDER = ["NOW", "A", "B", "C", "D"]


def lane_label(im, did):
    d = ImageDraw.Draw(im)
    label(d, 236, 6, DIRS[did]["name"], 15)
    if did != "NOW":
        label(d, 236, 26, "asa ucundan, parlama karesinde", 12, (200, 220, 210))
    else:
        label(d, 236, 26, "gövde merkezinden, klibin 0. karesinde (asa parlaması ~0,6 sn sonra)", 12, (230, 200, 190))


def build_gif():
    lanes = [Lane(did, i) for i, did in enumerate(ORDER)]
    dt = 1.0 / FPS
    # ısınma: parçacıklar döngüye otursun
    t = 0.0
    for _ in range(int(LOOP * FPS)):
        for ln in lanes:
            ln.render(t, dt)
        t += dt
    frames = []
    for i in range(int(LOOP * FPS)):
        tt = i * dt
        rows = []
        for ln in lanes:
            li = ln.render(tt, dt)
            lane_label(li, ln.did)
            rows.append(li)
        im = Image.new("RGB", (LANE_W, (LANE_H + 4) * len(rows) - 4), (18, 20, 20))
        for k, r in enumerate(rows):
            im.paste(r.convert("RGB"), (0, k * (LANE_H + 4)))
        frames.append(im.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    path = os.path.join(OUT, "lich_mermi_oyun.gif")
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=int(1000 / FPS), loop=0, disposal=1)
    print("gif", path, frames[0].size, len(frames))


def compare():
    """Uçuşun ortası (büyü + normal atış aynı karede), 1080p ölçeği."""
    rows = []
    for i, did in enumerate(ORDER):
        ln = Lane(did, i)
        ln.shots = [(0.0, False), (0.36, True)]
        dt = 1.0 / FPS
        t = 0.0
        while t < 0.64:
            im = ln.render(t, dt)
            t += dt
        lane_label(im, did)
        rows.append(im)
    W = LANE_W
    im = Image.new("RGB", (W, (LANE_H + 4) * len(rows) - 4), (18, 20, 20))
    for k, r in enumerate(rows):
        im.paste(r.convert("RGB"), (0, k * (LANE_H + 4)))
    path = os.path.join(OUT, "lich_mermi_karsilastirma.png")
    im.save(path)
    print("kars", path, im.size)


def detail():
    """Her yön: büyü kareleri x4, normal atış x4, isabet x4, 8 yön (oyun ölçeği), Lich 1/2/3."""
    Z = 4
    CELL = 64 * Z // 2  # kırpılmış 32x32 sanat alanı x4
    blocks = []
    for did in ["A", "B", "C", "D"]:
        d = DIRS[did]
        parts = []

        def crop(im):
            return im.crop((8, 8, 48, 40))

        sp = [to_screen(crop(d["shot"](0.0, f, False, 1)), Z) for f in range(d["nf"])]
        nm = [to_screen(crop(d["shot"](0.0, f, True, 1)), Z) for f in range(0, d["nf"], 2)]
        imps = []
        for fi in range(0, 12):
            r = d["imp"](fi / 25.0, False, 1)
            if r is None:
                break
            imps.append(to_screen(crop(r), Z))
        rot = []
        for k in range(8):
            a = k * math.pi / 4 + 0.2
            rot.append(to_screen(d["shot"](a, 0, False, 1).crop((12, 4, 52, 44)), S))
        tiers = [to_screen(crop(d["shot"](0.0, 1, False, tr)), Z) for tr in (1, 2, 3)]
        parts = [("büyü kareleri (x4)", sp), ("normal atış", nm), ("isabet (25 fps)", imps), ("8 yön, oyun ölçeği", rot), ("Lich 1 / 2 / 3", tiers)]
        W = 16 + sum(max(1, len(p[1])) for p in parts[:1]) * (CELL + 6)
        blocks.append((did, parts))
    # yerleşim: her yön bir satır grubu
    PAD = 6
    width = 1500
    rows_imgs = []
    for did, parts in blocks:
        lines = []
        cur, cw, ch = [], 0, 0
        for title, ims in parts:
            w = sum(i.width + PAD for i in ims) + 10
            if cw + w > width and cur:
                lines.append(cur)
                cur, cw = [], 0
            cur.append((title, ims, w))
            cw += w
        if cur:
            lines.append(cur)
        hdr = 30
        lh = [max(max(i.height for i in ims) for (_t, ims, _w) in ln) + 22 for ln in lines]
        im = Image.new("RGB", (width, hdr + sum(lh) + 8), (34, 38, 40))
        dr = ImageDraw.Draw(im)
        label(dr, 10, 6, DIRS[did]["name"], 17, (250, 230, 170))
        y = hdr
        for ln, h in zip(lines, lh):
            x = 10
            for (title, ims, w) in ln:
                label(dr, x, y, title, 12, (190, 200, 196))
                xx = x
                for sub in ims:
                    bgc = Image.new("RGBA", sub.size, (62, 84, 56, 255))
                    bgc.alpha_composite(sub)
                    im.paste(bgc.convert("RGB"), (xx, y + 18))
                    xx += sub.width + PAD
                x += w
            y += h
        rows_imgs.append(im)
    H = sum(r.height + 4 for r in rows_imgs)
    out = Image.new("RGB", (width, H), (18, 20, 20))
    y = 0
    for r in rows_imgs:
        out.paste(r, (0, y))
        y += r.height + 4
    path = os.path.join(OUT, "lich_mermi_detay.png")
    out.save(path)
    print("detay", path, out.size)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    args = sys.argv[1:] or ["kars", "detay", "gif"]
    for a in args:
        {"kars": compare, "gif": build_gif, "detay": detail}[a]()
