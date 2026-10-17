# -*- coding: utf-8 -*-
"""SANDIK görünüşü PROTOTİPLERİ v2 (2026-10-17, oyuna bağlı DEĞİL). Kullanıcı: "normal ve elit sandığın görünüşleri için mmorpg
oyunlarından esinlenerek yeni prototipler üret" -> v1 (sandik_proto_v1.py, out/sandik/v1/) için: "bunlar şekil olarak farklı olsa da
çizim olarak hep aynı kişi çizmiş gibi duruyor".

v1'in hatası: dört yön de aynı ELDEN çıktı - aynı #2a1a10 düz kontür, aynı yatay tahta çizgisi, aynı 4 tonlu düz gölge, aynı
efektler. v2'de her yönün ÇİZİM DİLİ (kontür, gölgeleme modeli, palet, doku, piksel yoğunluğu, efekt dili) kendi oyunundan:

  A Kubbeli Hazine  (WoW, elle boyanmış)  - 1 dünya px/piksel. İri abartılı oranlar, DİKEY tahtalar, 6 tonlu renk kaydırmalı
                    rampa (gölge mora, ışık sarıya kayar), kalın eğimli metal + iri perçin başları, RENKLİ kontür (alt/sağ koyu,
                    üst/sol komşu renginden), dither YOK (boya bantları). Efekt: dolu kama ışınlar, katmanlı parıltı, iri sikkeler.
  B Işık Sütunu     (Lost Ark / Diablo, kasvetli gerçekçi) - 0,5 dünya px/piksel (2x ince). Soluk koyu palet, gürültü dokusu
                    (lif, çizik, budak, PAS lekeleri), siyah kontür YOK (sel-out: kenar komşu rengin koyusu), kapak taşması +
                    altına düşen gölge, metal üstünde tek piksel parlama. Efekt: ganimet ışık sütunu + ince halka, keskin ince
                    ışınlar, kıvılcım/kor, toz bulutu.
  C Zincirli Mühür  (Black Desert, cilalı süslü) - 0,5 dünya px/piksel. Lake/maun yumuşak geçiş (ince Bayer), yansıma bandı +
                    kayan parıltı, kemerli kapak, altın kakma kıvrımlar, örgü ip, kabartmalı mum mühür, mürekkepli etiket,
                    YUMUŞATILMIŞ (AA) kontür. Elit: obsidyen + altın işleme + ince zincir + ince çizgili büyü mührü. Efekt:
                    ince halka dalgası, ince ışınlar, yükselen altın toz.
  D Tombul Masal    (MapleStory, çizgi film) - 1 dünya px/piksel. Kalın koyu mor-siyah çizgi (içte de), İKİ TONLU sert gölge
                    + beyaz parlama, şeker renkler, tıknaz oran + küçük ayaklar, zıplama. Efekt: çizgi roman patlama yıldızı,
                    kontürlü yıldız/sikke, konfeti, sallanmada hareket çizgileri.

Çıktılar (out/sandik/): sandik_ozet.png, sandik_oyun.gif (gerçek oyun ölçeği, kamera x2, gerçek harita + karakter; ince
piksel yönler ekran pikseline 1:1), sandik_oyun_kare.png, sandik_odul.gif (ödül ekranı gibi yakın, tam dizi).
Çalıştırma: python tools/proto_20261017/sandik_proto.py [ozet|oyun|odul]   (argümansız: hepsi)
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from mermi_proto import label, asset, on, GAME  # noqa: E402  (yazı, varlık yükleme, Bayer)

OUT = os.path.join(HERE, "out", "sandik")
CW, CH = 64, 96  # sandık tuvali, dünya px
CX, BY = 32, 84  # gövde ortası, zemin (dünya px)
ZOOM = 2
FPS = 20
CHAR_K = 2.2368375 * 0.8075 * 0.5  # Assasin dünya px / karakter pikseli
RES = {"cur": 1, "A": 1, "B": 2, "C": 2, "D": 1}  # sanat pikseli / dünya px


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def R(s):
    return [C(x) for x in s.split()]


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def ci(v, lo, hi):
    v = int(math.floor(v + 0.5)) if isinstance(v, float) else int(v)
    return lo if v < lo else hi if v > hi else v


def hn(x, y, s=0):
    h = (int(x) * 374761393 + int(y) * 668265263 + s * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def vn(x, y, s=0):
    xi, yi = math.floor(x), math.floor(y)
    fx, fy = x - xi, y - yi
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = hn(xi, yi, s), hn(xi + 1, yi, s)
    c, d = hn(xi, yi + 1, s), hn(xi + 1, yi + 1, s)
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy


def dith(x, y, v, n):
    """Sürekli değer -> rampa indisi, iki komşu ton arası Bayer (C'nin yumuşak geçişi)."""
    i = math.floor(v)
    if on(int(x) & 1023, int(y) & 1023, v - i):
        i += 1
    return ci(i, 0, n - 1)


WHITE = C("#fffaf0")


# ------------------------------------------------------------------ tuval
class L:
    def __init__(self, r=1):
        self.r, self.W, self.H = r, CW * r, CH * r
        self.a = np.zeros((self.H, self.W, 4), np.uint8)

    def px(self, x, y, c):
        x, y = int(math.floor(x + 0.5)), int(math.floor(y + 0.5))
        if c is not None and 0 <= x < self.W and 0 <= y < self.H:
            self.a[y, x] = c

    def solid(self, x, y):
        return 0 <= x < self.W and 0 <= y < self.H and self.a[y, x, 3] > 0

    def rect(self, x0, y0, x1, y1, c):
        x0, y0, x1, y1 = max(0, int(x0)), max(0, int(y0)), min(self.W - 1, int(x1)), min(self.H - 1, int(y1))
        if x1 >= x0 and y1 >= y0:
            self.a[y0:y1 + 1, x0:x1 + 1] = c

    def hl(self, x0, x1, y, c):
        self.rect(x0, y, x1, y, c)

    def vl(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)

    def over(self, x, y, c):
        if self.solid(int(math.floor(x + 0.5)), int(math.floor(y + 0.5))):
            self.px(x, y, c)

    def glow(self, x, y, c, a, steps=4):
        """Efekt pikseli: DÜZ, dither YOK (v2'nin Bayer noktaları "parazit gibi, çok ai duruyor"). Alfa birkaç basamağa
        yuvarlanır -> solma bant bant olur; üst üste yazımda en opak olan kalır."""
        x, y = int(math.floor(x + 0.5)), int(math.floor(y + 0.5))
        if c is None or not (0 <= x < self.W and 0 <= y < self.H):
            return
        a = round(max(0.0, min(1.0, a)) * steps) / float(steps)
        A = int(a * 255)
        if A > 0 and A >= self.a[y, x, 3]:
            self.a[y, x] = (c[0], c[1], c[2], A)

    def gline(self, x0, y0, x1, y1, c, a=1.0):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            u = i / float(n)
            self.glow(x0 + (x1 - x0) * u, y0 + (y1 - y0) * u, c, a)

    def gellipse(self, cx, cy, rx, ry, c, a=1.0):
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                if ((x - cx) / max(rx, 0.5)) ** 2 + ((y - cy) / max(ry, 0.5)) ** 2 <= 1.0:
                    self.glow(x, y, c, a)

    def gring(self, cx, cy, rx, ry, c, a=1.0):
        """Kesintisiz 1 px elips çizgisi."""
        n = int((rx + ry) * 4) + 8
        for i in range(n):
            t = i / float(n) * math.tau
            self.glow(cx + math.cos(t) * rx, cy + math.sin(t) * ry, c, a)

    def sprite(self, rows, x0, y0, pal, flip=False):
        for j, r in enumerate(rows):
            w = len(r)
            for i, ch in enumerate(r):
                if ch in pal:
                    self.px(x0 + (w - 1 - i if flip else i), y0 + j, pal[ch])

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                if ((x - cx) / max(rx, 0.5)) ** 2 + ((y - cy) / max(ry, 0.5)) ** 2 <= 1.0:
                    self.px(x, y, c)


def _edges(S):
    m = S.a[:, :, 3] > 0
    up, dn, lf, rt = (np.zeros_like(m) for _ in range(4))
    up[1:, :] = m[:-1, :]
    dn[:-1, :] = m[1:, :]
    lf[:, 1:] = m[:, :-1]
    rt[:, :-1] = m[:, 1:]
    return m, (up | dn | lf | rt) & ~m, up, dn, lf, rt


def outline_flat(S, col):
    _, e, *_ = _edges(S)
    S.a[e] = col


def outline_paint(S, dark):
    """A (boyalı): alt/sağ kenar en koyu ton; üst/sol kenar komşu rengin morlaşmış koyusu."""
    m, e, up, dn, lf, rt = _edges(S)
    src = S.a.copy()
    for y, x in zip(*np.nonzero(e)):
        if up[y, x] or lf[y, x]:
            S.a[y, x] = dark
        else:
            ny, nx = (y + 1, x) if dn[y, x] else (y, x + 1)
            c = src[ny, nx]
            S.a[y, x] = (int(c[0] * 0.42 + 14), int(c[1] * 0.34 + 6), int(c[2] * 0.44 + 22), 255)


def outline_selout(S, k_lit=0.5, k_dark=0.3):
    """B (gerçekçi): siyah çizgi yok - kenar pikseli komşu rengin koyusu."""
    m, e, up, dn, lf, rt = _edges(S)
    src = S.a.copy()
    for y, x in zip(*np.nonzero(e)):
        cs = [src[y + dy, x + dx, :3].astype(int) for dy, dx, f in ((-1, 0, up), (1, 0, dn), (0, -1, lf), (0, 1, rt)) if f[y, x]]
        c = np.mean(cs, axis=0)
        k = k_dark if (up[y, x] or lf[y, x]) else k_lit
        S.a[y, x] = (int(c[0] * k), int(c[1] * k), int(c[2] * k), 255)


def outline_aa(S, col, aa=120):
    """C (cilalı): koyu kontür + köşelerde yarı saydam ara piksel (yumuşatma)."""
    outline_flat(S, col)
    m, _, up, dn, lf, rt = _edges(S)
    corner = ~m & ((up & lf) | (up & rt) | (dn & lf) | (dn & rt))
    S.a[corner] = (col[0], col[1], col[2], aa)


def comp(*layers):
    W, H = layers[0].W, layers[0].H
    oc = np.zeros((H, W, 3), np.float32)
    oa = np.zeros((H, W, 1), np.float32)
    for l in layers:
        a = l.a.astype(np.float32)
        sa = a[:, :, 3:4] / 255.0
        na = sa + oa * (1 - sa)
        oc = np.where(na > 0, (a[:, :, :3] * sa + oc * oa * (1 - sa)) / np.maximum(na, 1e-6), 0)
        oa = na
    return np.concatenate([oc, oa * 255.0], axis=2).round().astype(np.uint8)


def star4(F, x, y, r, core, col, a=1.0, hlen=None):
    """Temiz 4 kollu parıltı (tek tek saçılmış noktalar yerine): ortası beyaz, kollar iç yarı core dış yarı col.
    hlen: yatay kol boyu ayrı (B'nin mercek parlaması gibi uzun yatay)."""
    if r < 0:
        return
    F.glow(x, y, WHITE, a)
    hl_ = r if hlen is None else hlen
    for k in range(1, max(r, hl_) + 1):
        if k <= r:
            c = core if k <= (r + 1) // 2 else col
            F.glow(x, y - k, c, a)
            F.glow(x, y + k, c, a)
        if k <= hl_:
            c = core if k <= (hl_ + 1) // 2 else col
            F.glow(x - k, y, c, a)
            F.glow(x + k, y, c, a)


def twinkle(T, ph, period=0.9, rmax=2):
    """Parıltı boyu zamanla 0 -> rmax -> 0 (yanıp sönme yerine büyüyüp küçülür); -1 = görünmez."""
    u = ((T + ph) % period) / period
    if u > 0.75:
        return -1
    return int(round(math.sin(u / 0.75 * math.pi) * rmax))


# ------------------------------------------------------------------ durum (zaman çizelgesi)
class St:
    """ph: idle | shake | open; pt: evredeki sn (ödül ekranı ölçeği); T: genel saat; step: sallanma adımı 0-3."""

    def __init__(self, ph, pt=0.0, T=0.0):
        self.ph, self.pt, self.T = ph, pt, T
        self.step = min(3, int(pt / 0.13)) if ph == "shake" else 0

    @property
    def k(self):
        return (self.step + 1) / 4.0 if self.ph == "shake" else 0.0

    def lift(self):
        return 0 if self.ph != "shake" else (1 if self.step % 2 == 0 else 2)

    def dx(self):
        return 0 if self.ph != "shake" else (-1, 1, -1, 1)[self.step]


def bob(st):
    return int(round(math.sin(st.T * 4.0) * 2.0)) if st.ph == "idle" else 0


def hop(T):
    """D: (yükseklik, en farkı, boy farkı, havada mı) - 1,8 sn'de bir bas-zıpla-yere bas."""
    t = T % 1.8
    if 1.10 <= t < 1.22:
        return 0, 2, -2, False
    if 1.22 <= t < 1.62:
        u = (t - 1.22) / 0.40
        return int(round(6.0 * math.sin(math.pi * u))), (-1 if u < 0.5 else 0), (1 if u < 0.5 else 0), True
    if 1.62 <= t < 1.72:
        return 0, 2, -1, False
    return 0, 0, 0, False


def lid_pop(pt, seq=(-2, -1, 0)):
    return seq[min(len(seq) - 1, int(pt / 0.05))]


# =================================================================== A  WoW - elle boyanmış
WOOD_A = R("#2c1420 #5a2a24 #8a4528 #b8682f #de9446 #f7c477")
STEEL_A = R("#1e1c30 #3a3c5c #5f6688 #8d98b6 #c3cee0 #f4f7ff")
GOLD_A = R("#3a1a14 #7a3e18 #b8701e #e8a630 #ffd35a #fff3b4")
WAL_A = R("#1a0c16 #3a1822 #5a2828 #7c3c2c #a05634 #c47a48")
RUBY_A = R("#2e0818 #7a1226 #c8242a #ff5a40 #ffb8a0 #fff0e6")
OUT_A = C("#1e0f1a")
LIGHT_A = (C("#ffd35a"), C("#fff3b4"))
LIGHT_AE = (C("#ffb43a"), C("#fff0b0"))  # turuncu = ateş yelpazesi gibi okunuyordu


def a_wood(W, x, y, x0, x1, pw, extra, seed):
    k, i = (x - x0) % pw, (x - x0) // pw
    idx = 4 if k == 0 else 2 if k == pw - 1 else 3
    gx = x0 + i * pw + 2 + int(round(math.sin(y * 0.55 + i * 1.7 + seed) * 0.7))
    if x == gx and 0 < k < pw - 1 and (y * 3 + i) % 7 != 0:
        idx += 1
    if x == x1:
        idx = min(idx, 2)
    return W[ci(idx + extra, 0, 5)]


def a_band(S, bx, y0, y1, M, shift=0, rivet=4):
    for y in range(y0, y1 + 1):
        for i, idx in enumerate((4, 3, 2, 1)):
            S.over(bx + i, y, M[ci(idx + shift, 0, 5)])
    y = y0 + 2
    while y < y1 - 1:
        for (dx, dy, idx) in ((1, 0, 5), (2, 0, 3), (1, 1, 3), (2, 1, 1)):
            S.over(bx + dx, y + dy, M[ci(idx + shift, 0, 5)])
        y += rivet


def a_plate(S, x0, y0, x1, y1, M):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            idx = 3
            if y == y0 or x == x0 or (x == x0 + 1 and y > y0):
                idx = 4
            if x == x1 or y == y1:
                idx = 1
            elif x == x1 - 1 or y == y1 - 1:
                idx = 2
            S.px(x, y, M[idx])


def a_coin(F, x, y, ph, G=GOLD_A):
    x, y = int(round(x)), int(round(y))
    if ph % 3 != 1:
        for dx, dy, i in ((1, 0, 5), (0, 1, 4), (1, 1, 3), (2, 1, 2), (1, 2, 1)):
            F.px(x + dx, y + dy, G[i])
    else:
        for dy, i in ((0, 5), (1, 3), (2, 1)):
            F.px(x + 1, y + dy, G[i])


def a_sparkle(F, x, y, col, r):
    F.px(x, y, WHITE)
    for k in range(1, r + 2):
        F.px(x, y - k, col if k > 1 else WHITE)
        F.px(x, y + k, col if k > 1 else WHITE)
    for k in range(1, r + 1):
        F.px(x - k, y, col)
        F.px(x + k, y, col)
    if r >= 2:
        for dx, dy in ((1, 1), (-1, -1), (1, -1), (-1, 1)):
            F.px(x + dx, y + dy, col)


def a_wedges(F, cx, cy, n, reach, w_end, pt, light, core, seed):
    if pt > 0.55:
        return
    g = min(1.0, pt / 0.10)
    sh = 1.0 if pt < 0.22 else max(0.0, 1.0 - (pt - 0.22) / 0.33)
    rng = random.Random(seed)
    for i in range(n):
        ang = -math.pi / 2 + (i - (n - 1) / 2.0) / max(1, n - 1) * 1.7 + rng.uniform(-0.06, 0.06)
        ln = reach * (0.7 + 0.3 * rng.random()) * g * (0.55 + 0.45 * sh)
        we = w_end * (0.4 + 0.6 * sh) * (0.7 + 0.3 * rng.random())
        ca, sa = math.cos(ang), math.sin(ang)
        for d in range(3, int(ln)):
            u = d / ln
            half = we * u * 0.5 + 0.3
            for s in range(-int(half + 0.5), int(half + 0.5) + 1):
                F.px(cx + ca * d - sa * s, cy + sa * d + ca * s, core if abs(s) <= half * 0.35 and u < 0.75 else light)


def draw_A(Lb, S, F, Fo, elite, st):
    W, M = (WAL_A, GOLD_A) if elite else (WOOD_A, STEEL_A)
    light, core = LIGHT_AE if elite else LIGHT_A
    w, bh, dh = (31, 12, 13) if elite else (25, 10, 11)
    feet = 3 if elite else 0
    cx = CX + st.dx()
    by = BY - feet + bob(st)
    x0, x1 = cx - w // 2, cx + w // 2
    bt = by - bh
    pw = 5
    bands = (x0 + 5, x1 - 8) if elite else (x0 + 4, x1 - 7)
    seed = 3 if elite else 1
    # gövde: dikey tahtalar, ağız altı gölgesi, alt kenar koyu
    for y in range(bt, by):
        ex = -1 if (y == bt or y >= by - 2) else 0
        for x in range(x0, x1 + 1):
            S.px(x, y, a_wood(W, x, y, x0, x1, pw, ex, seed))
    lift = st.lift()
    if st.ph == "open":
        oy = bt - 4
        S.hl(x0, x1, oy, W[4])
        S.rect(x0, oy + 1, x1, bt - 1, W[0])
        S.vl(x0, oy + 1, bt - 1, W[1])
        S.vl(x1, oy + 1, bt - 1, W[1])
        for x in range(x0 + 3, x1 - 2):  # yığın: iri boyalı sikkeler
            u = (x - x0 - 3) / float(w - 6)
            hgt = int(round((2.6 if elite else 1.8) * math.sin(u * math.pi)))
            for k in range(hgt + 2):
                top = k == hgt + 1
                S.px(x, bt - 1 - k, GOLD_A[5 if (top and x % 3 == 0) else 4 if top else 3 if (x + k) % 2 else 2])
        if elite:
            for gx in (x0 + 8, cx + 1, x1 - 8):
                S.px(gx, bt - 3, RUBY_A[4])
                S.px(gx + 1, bt - 3, RUBY_A[2])
        oh = dh - 2  # arkada dikilen kapak: üstte metal ağız, iç tahtalar koyu
        ly1 = oy - 1 + lid_pop(st.pt)
        ly0 = ly1 - oh + 1
        ins = [2, 1] + [0] * oh
        for j in range(oh):
            xa, xb = x0 + ins[j], x1 - ins[j]
            for x in range(xa, xb + 1):
                c = M[3 if j == 0 else 1] if j <= 1 else a_wood(W, x, ly0 + j, x0, x1, pw, -2, seed)
                S.px(x, ly0 + j, c)
        for bx in bands:
            a_band(S, bx, ly0 + 2, ly1, M, shift=-2, rivet=99)
    else:
        ly0 = bt - dh - lift
        ins = ([6, 4, 3, 2, 1, 1] if elite else [6, 4, 2, 1, 1]) + [0] * dh
        for j in range(dh):
            xa, xb = x0 + ins[j], x1 - ins[j]
            y = ly0 + j
            for x in range(xa, xb + 1):
                ex = 1 if j <= 1 else (-1 if j >= dh - 4 else 0)
                if x > x0 + w * 0.72:
                    ex -= 1
                c = a_wood(W, x, y, x0, x1, pw, ex, seed)
                if j in (1, 2) and xa + 2 <= x <= cx - 2 and not (j == 2 and x > cx - 5):
                    c = W[5]
                S.px(x, y, c)
            if elite:  # kubbe çevresi altın kaplama
                S.px(xa, y, GOLD_A[4])
                S.px(xb, y, GOLD_A[2])
                if j == 0:
                    S.hl(xa, xb, y, GOLD_A[4])
        for bx in bands:
            a_band(S, bx, ly0, bt - 4 - lift, M)
        for k, idx in enumerate((4, 3, 0)):  # kapak ağzı: 3 satır kalın metal (alt satır koyu = ek yeri)
            S.hl(x0, x1, bt - 3 - lift + k, M[idx])
        if lift:  # aralıktan sızan dolu ışık kaması
            for y in range(bt - lift, bt):
                S.hl(x0 + 1, x1 - 1, y, core)
            n = 3 + int(st.k * 6)
            for i in range(1, n + 1):
                hh = max(0, 2 - i * 3 // n)
                for dy in range(-hh, hh + 1):
                    F.px(x0 - i, bt - 1 + dy, light)
                    F.px(x1 + i, bt - 1 + dy, light)
    for bx in bands:
        a_band(S, bx, bt + 1, by - 2, M)
    for sx, d in ((x0, 1), (x1, -1)):  # köşe başlıkları
        sh = 0 if d == 1 else -1
        nn = 6 if elite else 5
        for j in range(nn):
            S.px(sx, by - 1 - j, M[ci(3 + sh, 0, 5)])
            S.px(sx + d, by - 1 - j, M[ci(4 + sh, 0, 5)] if j > 1 else M[ci(3 + sh, 0, 5)])
        for i in range(nn):
            S.px(sx + d * i, by - 1, M[1])
            S.px(sx + d * i, by - 2, M[ci(4 + sh, 0, 5)] if i > 1 else M[ci(3 + sh, 0, 5)])
        S.px(sx + d, by - 3, M[5])
        if elite:  # pençe ayaklar
            for i in range(5):
                S.px(sx + d * i, by, GOLD_A[3 if i % 2 == 0 else 2])
                if i % 2 == 0:
                    S.px(sx + d * i, by + 1, GOLD_A[2])
                    S.px(sx + d * i, by + 2, GOLD_A[1])
    if elite:  # arma + yakut
        sh = ["#########", "#########", "#########", "#########", "#########", "#########", ".#######.", ".#######.",
              "..#####..", "...###...", "....#...."]
        ax0 = cx - 4
        ay0 = (bt - 1) if st.ph == "open" else (bt - 6 - lift)
        for j, r in enumerate(sh):
            for i, ch in enumerate(r):
                if ch != "#":
                    continue
                idx = 4 if (j == 0 or i <= 1) else 3
                if i == len(r) - 1 or (i + 1 < len(r) and r[i + 1] == ".") or j == len(sh) - 1:
                    idx = 1
                elif j >= 8:
                    idx = 2
                S.px(ax0 + i, ay0 + j, GOLD_A[idx])
        gy = ay0 + 4
        pulse = 0.5 + 0.5 * math.sin(st.T * 5.0)
        S.sprite(["..a..", ".abc.", "abxcd", ".cdd.", "..d.."], cx - 2, gy - 2,
                 {"a": RUBY_A[4], "b": RUBY_A[3], "c": RUBY_A[2], "d": RUBY_A[1], "x": RUBY_A[5] if pulse > 0.6 else RUBY_A[4]})
        if st.ph == "idle":
            pts = [(x0 + 3, bt + 3), (x1 - 4, bt - 7), (cx + 7, by - 4), (x0 + 7, bt - 10), (cx - 2, gy - 1)]
            i = int(st.T / 0.55) % len(pts)
            a_sparkle(F, pts[i][0], pts[i][1], core, (0, 1, 2, 1, 0)[int((st.T % 0.55) / 0.11) % 5])
    else:  # iri pirinç kilit
        ly = (bt - 1) if st.ph == "open" else (bt - 4 - lift)
        a_plate(S, cx - 3, ly, cx + 3, ly + 8, GOLD_A)
        S.sprite([".o.", "ooo", ".o.", ".o."], cx - 1, ly + 2, {"o": GOLD_A[0]})
        S.px(cx - 1, ly + 2, GOLD_A[5])
        if st.ph == "idle":
            g = (st.T % 2.4) - 1.9
            if 0 <= g < 0.5:
                a_sparkle(F, cx + 2, ly + 1, core, (0, 1, 2, 2, 1, 0)[int(g / 0.5 * 6) % 6])
    return dict(cx=cx, mouth=(cx, bt - 2), w=w, x0=x0, x1=x1)


def fx_A(F, Fo, g, elite, st):
    if st.ph != "open":
        return
    pt = st.pt
    light, core = LIGHT_AE if elite else LIGHT_A
    mx, my = g["mouth"]
    if pt < 0.16:  # katmanlı boya parıltısı
        k = 1.0 - pt / 0.16
        for i, c in enumerate((light, core, WHITE)):
            F.ellipse(mx, my, (g["w"] / 2.0 + 3) * (1 - i * 0.3) * (0.6 + 0.4 * k), (5.0 - i * 1.4) * k + 0.5, c)
    a_wedges(F, mx, my - 1, 7 if elite else 5, 34 if elite else 26, 4, pt, light, core, 4 + elite)
    if 0 < pt < 0.75:
        rng = random.Random(9 + elite)
        for i in range(10 if elite else 7):
            vx, vy = rng.uniform(-44, 44), -rng.uniform(75, 115)
            t = pt - rng.uniform(0, 0.05)
            if t <= 0:
                continue
            y = min(BY + 1, my + vy * t + 150 * t * t)
            a_coin(F, mx + vx * t - 1, y - 1, int(pt * 18 + i))
    if pt > 0.45:
        T = st.T
        pulse = 0.5 + 0.5 * math.sin(T * 5.0)
        for j, y in enumerate(range(my - 1, my - 5, -1)):  # ağızdan yükselen düz, bantlı sıcak ışık
            ins = 3 + j
            for x in range(g["x0"] + ins, g["x1"] - ins + 1):
                F.glow(x, y, core if j == 0 else light, (0.75 if j == 0 else 0.5 if j == 1 else 0.25) * (0.75 + 0.25 * pulse))
        i = int(T / 0.4) % 3
        a_sparkle(F, mx + (-6, 5, 0)[i], my - 6 - i * 2, core, (1, 2, 1, 0)[int((T % 0.4) / 0.1) % 4])


def shadow_A(Sh, cx, y, w, k=1.0):
    Sh.ellipse(cx, y, w / 2.0 + 1, 3.2, (30, 18, 40, 80))
    Sh.ellipse(cx, y, w / 2.0 - 3, 2.0, (30, 18, 40, 150))


# =================================================================== B  Lost Ark / Diablo - kasvetli gerçekçi (2x)
WOOD_B = R("#15100c #271d16 #3b2c20 #53402e #6e5640 #8c7256")
IRON_B = R("#0e1013 #1d2126 #30363d #4a525b #6c757f #a3acb5")
RUST_B = R("#3a1c10 #5e2e18 #86452a #a8623c")
DGOLD_B = R("#2a1e0a #4e3a14 #7a5c22 #a88232 #d2ac52 #f4dc96")
GEM_B = R("#1e0a2e #45166a #7a2fb0 #b56ae8 #ecd2ff")
BST_B = R("#0a0a0e #16161c #24242c #383842 #54545f #868692")
BEAM_B = {False: (C("#ffb84a"), C("#ffe9a8")), True: (C("#9a4af0"), C("#d6a6ff"))}  # çimen üstünde beyaz dither naneye döner


def b_wood(S, x0, y0, x1, y1, Wr, seed, plank=6, extra=0.0, ao_top=0):
    for y in range(y0, y1 + 1):
        py = (y - y0) % plank
        for x in range(x0, x1 + 1):
            if py == plank - 1:
                S.px(x, y, Wr[0] if hn(x, y, seed) < 0.75 else Wr[1])
                continue
            g = vn(x / 8.0 + seed * 3.1, (y - y0) / 1.7, seed)
            v = 2.3 + (g - 0.5) * 2.4 + (hn(x, y, seed + 7) - 0.5) * 1.0 + extra
            if py == 0:
                v += 0.9
            if ao_top and y - y0 < ao_top:
                v -= (ao_top - (y - y0)) * 0.55
            if x == x1:
                v -= 0.8
            S.px(x, y, Wr[ci(v, 1, 5)])
    rng = random.Random(seed * 7 + 1)
    area = (x1 - x0) * (y1 - y0)
    for _ in range(area // 140):  # çizikler
        sx, sy = rng.randint(x0 + 2, max(x0 + 2, x1 - 6)), rng.randint(y0, max(y0, y1 - 1))
        a = rng.uniform(-0.35, 0.35)
        for d in range(rng.randint(3, 7)):
            S.over(sx + d * math.cos(a), sy + d * math.sin(a), Wr[5] if d % 3 else Wr[4])
    if area > 300:  # budak
        kx, ky = rng.randint(x0 + 6, x1 - 8), rng.randint(y0 + 1, y1 - 3)
        S.sprite([".bb.", "bddb", ".bb."], kx, ky, {"b": Wr[4], "d": Wr[0]})


def b_iron(S, x0, y0, x1, y1, M, seed, extra=0.0, rust=True, bevel=True):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if rust and vn(x / 5.0 + 11, y / 5.0, seed + 5) > 0.64:
                S.px(x, y, RUST_B[ci(vn(x / 2.0, y / 2.0, seed + 9) * 4.0 - 0.5, 0, 3)])
                continue
            if rust:  # dövme demir: benekli
                v = 2.6 + (vn(x / 2.5, y / 2.5, seed) - 0.5) * 1.2 + (hn(x, y, seed + 3) - 0.5) * 0.9 + extra
            else:  # kararmış çelik plaka: yatay fırça izi
                v = 2.5 + (vn(x / 13.0, y / 1.3, seed) - 0.5) * 1.3 + (hn(x, y, seed + 3) - 0.5) * 0.35 + extra
            if bevel:
                if x == x0 or y == y0:
                    v += 1.0
                if x == x1 or y == y1:
                    v -= 1.0
            S.px(x, y, M[ci(v, 0, 5)])


def b_rivet(S, x, y, M, spec=False):
    for dy, row in enumerate(((4, 5, 3), (3, 3, 1), (1, 1, 0))):
        for dx, i in enumerate(row):
            S.px(x + dx, y + dy, M[i])
    if spec:
        S.px(x + 1, y, WHITE)


def b_pillar(Lb, cx, base, h, wc, ws, light, core, T, boost=0.0, shrink=1.0):
    """Işık sütunu: düz çekirdek + iki yarı saydam yan bant, yukarı doğru incelir ve BANT BANT söner (dither yok);
    nefes = genişlik dalgası (kumlanma yok)."""
    h = int(h)
    for y in range(base - h, base + 1):
        u = (base - y) / float(max(1, h))
        fade = max(0.0, 1.0 - u) + boost
        wob = math.sin(T * 5.0 + y * 0.12) * 0.5
        w_c = max(0.6, (wc + wob * 0.4) * shrink * (1.0 - 0.15 * u))
        w_s = max(0.0, (ws + wob) * shrink * (1.0 - 0.1 * u))
        for x in range(int(cx - w_c - w_s - 1), int(cx + w_c + w_s + 2)):
            dd = abs(x - cx)
            if dd <= w_c:
                Lb.glow(x, y, core if u < 0.55 else light, min(1.0, fade * 1.3), steps=6)
            elif dd <= w_c + w_s * 0.5:
                Lb.glow(x, y, light, fade * 0.55, steps=6)
            elif dd <= w_c + w_s:
                Lb.glow(x, y, light, fade * 0.3, steps=6)


RUNE_B = [[".#.", "###", ".#.", "#.#", "#.#"], ["##.", "#..", "###", "..#", ".##"], ["#.#", "###", "#.#", "#.#", ".#."]]


def b_ring(Lb, F, cx, cy, rx, ry, light, T, runes=0, rcol=None, scale=1.0, alpha=1.0):
    """Yerde kesintisiz ince halka (ön yarısı sandığın önünde) + 3 dönen parlak yay; elitte rünler. Solma = alfa bandı."""
    rx, ry = rx * scale, ry * scale
    m = int((rx + ry) * 4.0)
    for i in range(m):
        a = i / float(m) * math.tau
        seg = ((a - T * 0.9) % math.tau) / math.tau * 3.0
        bright = (seg % 1.0) < 0.22
        (F if math.sin(a) > 0 else Lb).glow(cx + math.cos(a) * rx, cy + math.sin(a) * ry, WHITE if bright else light,
                                           alpha * (1.0 if bright else 0.75))
    for r in range(runes):
        a = r / float(runes) * math.tau - T * 0.5
        x, y = cx + math.cos(a) * (rx + 7), cy + math.sin(a) * (ry + 4)
        L_ = F if math.sin(a) > 0 else Lb
        for j, row in enumerate(RUNE_B[r % 3]):
            for i, ch in enumerate(row):
                if ch == "#":
                    L_.glow(x - 1 + i, y - 2 + j, rcol, alpha)


def draw_B(Lb, S, F, Fo, elite, st):
    r = 2
    cx = CX * r + st.dx() * r
    by = BY * r
    light, core = BEAM_B[elite]
    w, bh, lf, lt = (54, 22, 12, 9) if elite else (46, 18, 10, 8)
    x0, x1 = cx - w // 2, cx + w // 2 - 1
    bt = by - bh
    T = st.T
    seed = 8 if elite else 4
    if st.ph in ("idle", "shake"):  # ışık sütunu + yer halkası
        k = st.k
        b_ring(Lb, F, cx, by - 2, (38 if elite else 31) + 2 * k, (14 if elite else 11) + k, light, T * (1 + 2 * k),
               runes=6 if elite else 0, rcol=GEM_B[3])
        b_pillar(Lb, cx, bt - 6, (118 if elite else 80) + 12 * k, (3 if elite else 2) + k, (9 if elite else 7) + 3 * k,
                 light, core, T, boost=0.15 * k)
        if st.ph == "idle":  # sütunda yükselen birkaç temiz parıltı (tek piksel serpinti değil)
            for i in range(3 if elite else 2):
                u = (T * 0.4 + i / (3.0 if elite else 2.0)) % 1.0
                yy = bt - 14 - u * (96 if elite else 62)
                xx = cx + math.sin(T * 1.6 + i * 2.0) * 2.5
                star4(Lb, xx, yy, twinkle(T, i * 0.31, 0.8, 2), core, light, hlen=twinkle(T, i * 0.31, 0.8, 3))
    elif st.pt < 0.45:
        pt = st.pt
        b_pillar(Lb, cx, bt - 6, (130 if elite else 92) * (1 - pt / 0.45), 4, 11, light, core, T, boost=0.3,
                 shrink=max(0.0, 1 - pt / 0.3) + 0.12)
        b_ring(Lb, F, cx, by - 2, 38 if elite else 31, 14 if elite else 11, light, T, runes=6 if elite else 0,
               rcol=GEM_B[3], scale=1 + pt * 1.2, alpha=1 - pt / 0.45)
    lift = st.lift() * r
    if elite:  # kararmış çelik plakalar + donuk altın kenar + oymalı köşe
        b_iron(S, x0, bt, x1, by - 1, BST_B, seed, rust=False)
        for yy in range(bt + 8, by - 2, 8):
            S.hl(x0 + 2, x1 - 2, yy, BST_B[0])
            for xx in range(x0 + 6, x1 - 6, 9):
                S.px(xx, yy + 2, BST_B[5])
                S.px(xx + 1, yy + 3, BST_B[1])
        for yy in range(bt, by):
            for xx, i in ((x0, 4), (x0 + 1, 3), (x1 - 1, 2), (x1, 1)):
                S.px(xx, yy, DGOLD_B[i])
        S.hl(x0, x1, by - 1, DGOLD_B[1])
        S.hl(x0, x1, by - 2, DGOLD_B[2])
        for sx, d in ((x0, 1), (x1, -1)):
            for j in range(9):
                for i in range(9 - j):
                    c = DGOLD_B[3] if (i + j) < 7 else DGOLD_B[1]
                    if (i - j) % 3 == 0 and i + j < 7:
                        c = DGOLD_B[1]
                    if i == 0 or j == 0:
                        c = DGOLD_B[4]
                    S.px(sx + d * i, by - 1 - j, c)
    else:  # aşınmış tahta + paslı demir çerçeve, dikey kayışlar
        b_wood(S, x0 + 3, bt + 2, x1 - 3, by - 4, WOOD_B, seed, ao_top=4)
        b_iron(S, x0, bt, x0 + 2, by - 1, IRON_B, seed)
        b_iron(S, x1 - 2, bt, x1, by - 1, IRON_B, seed + 1)
        b_iron(S, x0, by - 3, x1, by - 1, IRON_B, seed + 2)
        b_iron(S, x0, bt, x1, bt + 1, IRON_B, seed + 3, extra=-0.8)
        for sx in (x0 + 12, x1 - 15):
            b_iron(S, sx, bt, sx + 3, by - 1, IRON_B, seed + sx)
            for yy in range(bt + 4, by - 4, 6):
                b_rivet(S, sx, yy, IRON_B, spec=(yy // 6) % 2 == 0)
        for yy in range(bt + 3, by - 4, 6):
            b_rivet(S, x0, yy, IRON_B)
            b_rivet(S, x1 - 2, yy, IRON_B)
    if st.ph == "open":
        ot = 8
        oy = bt - ot
        b_iron(S, x0 - 1, oy, x1 + 1, oy + 1, BST_B if elite else IRON_B, seed + 4, rust=not elite)
        for y in range(oy + 2, bt):  # içerisi ışığın kaynağı
            for x in range(x0 + 1, x1):
                d = math.hypot((x - cx) / (w * 0.42), (y - (bt - 1)) / 5.5)
                v = 3.2 - d * 2.6
                S.px(x, y, WHITE if v > 2.4 else core if v > 1.6 else light if v > 0.8 else
                     (GEM_B[1] if elite else WOOD_B[1]) if v > 0.0 else (GEM_B[0] if elite else WOOD_B[0]))
        ly1 = oy - 1 + lid_pop(st.pt, (-4, -2, 0))
        ly0 = ly1 - (lf + lt) + 1
        if elite:
            b_iron(S, x0 - 1, ly0, x1 + 1, ly1, BST_B, seed + 6, extra=-1.2, rust=False)
            for yy in range(ly0, ly1 + 1):
                S.px(x0 - 1, yy, DGOLD_B[2])
                S.px(x1 + 1, yy, DGOLD_B[1])
        else:
            b_wood(S, x0 + 2, ly0 + 2, x1 - 2, ly1, WOOD_B, seed + 5, extra=-1.4)
            b_iron(S, x0 - 1, ly0, x0 + 1, ly1, IRON_B, seed + 6, extra=-0.8)
            b_iron(S, x1 - 1, ly0, x1 + 1, ly1, IRON_B, seed + 7, extra=-1.2)
            b_iron(S, x0 - 1, ly0, x1 + 1, ly0 + 1, IRON_B, seed + 8)
        mouth_y = bt - 3
    else:
        ft = bt - lift - lf
        tt = ft - lt
        lx0, lx1 = x0 - 1, x1 + 1
        if elite:
            b_iron(S, lx0, tt, lx1, ft - 1, BST_B, seed + 11, extra=1.0, rust=False)
            b_iron(S, lx0, ft, lx1, bt - 1 - lift, BST_B, seed + 12, rust=False)
            for yy in range(tt, bt - lift):
                for xx, i in ((lx0, 4), (lx0 + 1, 3), (lx1 - 1, 2), (lx1, 1)):
                    S.px(xx, yy, DGOLD_B[i])
            S.hl(lx0, lx1, tt, DGOLD_B[4])
            S.hl(lx0, lx1, ft, DGOLD_B[3])
            S.hl(lx0, lx1, bt - 1 - lift, DGOLD_B[1])
            gx, gy = cx, ft + lf // 2 - 1  # mor taş: altın yuva + yüzeyli taş, nabız
            S.ellipse(gx, gy, 6.4, 6.4, DGOLD_B[2])
            S.ellipse(gx - 0.5, gy - 0.5, 5.5, 5.5, DGOLD_B[4])
            S.ellipse(gx, gy, 5.2, 5.2, DGOLD_B[1])
            pulse = 0.5 + 0.5 * math.sin(T * 4.0)
            for yy in range(gy - 4, gy + 5):
                for xx in range(gx - 4, gx + 5):
                    fx_, fy_ = xx - gx, yy - gy
                    if abs(fx_) + abs(fy_) <= 6:
                        i = 3 if (fx_ <= 0 and fy_ <= 0) else 2 if fy_ <= 0 else 1
                        if fx_ + fy_ > 3:
                            i = 0
                        if fx_ == -1 and fy_ == -2:
                            i = 4
                        S.px(xx, yy, GEM_B[min(4, i + (1 if pulse > 0.75 and i < 3 else 0))])
            if pulse > 0.8:  # taşta tek mercek parıltısı
                star4(F, gx - 2, gy - 2, 2, GEM_B[4], GEM_B[3], hlen=4)
        else:
            b_wood(S, lx0 + 3, tt + 2, lx1 - 3, ft - 1, WOOD_B, seed + 13, plank=4, extra=1.2)
            b_wood(S, lx0 + 3, ft + 2, lx1 - 3, bt - 4 - lift, WOOD_B, seed + 14, plank=5)
            b_iron(S, lx0, tt, lx0 + 2, bt - 1 - lift, IRON_B, seed + 15, extra=0.4)
            b_iron(S, lx1 - 2, tt, lx1, bt - 1 - lift, IRON_B, seed + 16, extra=-0.4)
            b_iron(S, lx0, tt, lx1, tt + 1, IRON_B, seed + 17, extra=1.0)
            b_iron(S, lx0, ft, lx1, ft + 1, IRON_B, seed + 18, extra=0.6)
            b_iron(S, lx0, bt - 3 - lift, lx1, bt - 1 - lift, IRON_B, seed + 19, extra=-0.3)
            for sx in (x0 + 12, x1 - 15):
                b_iron(S, sx, tt, sx + 3, bt - 1 - lift, IRON_B, seed + 20 + sx, extra=0.3)
                b_rivet(S, sx, ft + 3, IRON_B, spec=True)
            b_iron(S, cx - 3, bt - 6 - lift, cx + 2, bt + 3, IRON_B, seed + 21, extra=0.5)  # asma kilit
            for a in range(14):
                an = math.pi + a / 13.0 * math.pi
                S.px(cx - 0.5 + math.cos(an) * 3.5, bt + 5 + math.sin(an) * 3.5, IRON_B[4 if a < 7 else 2])
            for yy in range(bt + 5, bt + 13):
                for xx in range(cx - 5, cx + 5):
                    v = 3.0 + (hn(xx, yy, 5) - 0.5) * 1.2 + (1 if xx < cx - 2 else -1 if xx > cx + 2 else 0)
                    S.px(xx, yy, DGOLD_B[ci(v, 0, 5)])
            S.vl(cx, bt + 8, bt + 10, DGOLD_B[0])
            S.px(cx - 4, bt + 5, DGOLD_B[5])
        if lift:  # ince keskin aralık ışığı
            for y in range(bt - lift, bt):
                S.hl(x0, x1, y, core)
            n = 6 + int(st.k * 14)
            for i in range(1, n + 1):
                F.glow(x0 - i, bt - 1, light, 1 - i / float(n + 1))
                F.glow(x1 + i, bt - 1, light, 1 - i / float(n + 1))
        mouth_y = bt - 1
    return dict(cx=cx, mouth=(cx, mouth_y), w=w, x0=x0, x1=x1, by=by)


def fx_B(F, Fo, g, elite, st):
    if st.ph != "open":
        return
    r = 2
    pt = st.pt
    light, core = BEAM_B[elite]
    mx, my = g["mouth"]
    if pt < 0.14:  # düz katmanlı flaş: beyaz çekirdek + iki yarı saydam bant
        k = 1 - pt / 0.14
        rx = g["w"] * 0.62 * (0.7 + 0.3 * k)
        F.gellipse(mx, my, rx, 7.0 * k + 1, light, 0.35)
        F.gellipse(mx, my, rx * 0.72, 5.0 * k + 1, core, 0.7)
        F.gellipse(mx, my, rx * 0.42, 3.0 * k + 1, WHITE, 1.0)
    if pt < 0.55:  # keskin ince ışınlar: düz çizgi, uca doğru bant bant söner
        g_ = min(1.0, pt / 0.08)
        fade = 1.0 if pt < 0.2 else max(0.0, 1 - (pt - 0.2) / 0.35)
        rng = random.Random(21 + elite)
        for i in range(9 if elite else 7):
            n = 9 if elite else 7
            ang = -math.pi / 2 + (i - (n - 1) / 2.0) / ((n - 1) / 2.0) * 0.95 + rng.uniform(-0.05, 0.05)
            ln = (90 if elite else 70) * (0.6 + 0.4 * rng.random()) * g_
            for d in range(4, int(ln)):
                u = d / ln
                F.glow(mx + math.cos(ang) * d, my + math.sin(ang) * d, WHITE if u < 0.3 else core if u < 0.6 else light,
                       (1.0 if u < 0.6 else 0.5) * fade)
    if 0.0 < pt < 0.7:
        k = pt / 0.7  # zeminde iki yana açılan toz: birkaç dolu yarı saydam bulut, alfa bantlı söner
        for s in (-1, 1):
            for j in range(3):
                px_ = mx + s * (14 + j * 9) * (0.4 + k)
                F.gellipse(px_, BY * r - 3 - j, 7 - j + 6 * k, 3.5 + 2 * k, (150, 138, 120, 255), 0.5 * (1 - k))
                F.gellipse(px_ - s, BY * r - 5 - j, (7 - j + 6 * k) * 0.6, 2 + k, (184, 172, 152, 255), 0.5 * (1 - k))
        rng = random.Random(33 + elite)  # kıvılcım: hız yönünde kısa düz çizgi (nokta değil)
        for i in range(10 if elite else 7):
            vx, vy = rng.uniform(-90, 90), -rng.uniform(130, 220)
            t = pt - rng.uniform(0, 0.05)
            if t <= 0 or t > 0.55:
                continue
            x, y = mx + vx * t, my + vy * t + 240 * t * t
            dvx, dvy = vx, vy + 480 * t
            sp = math.hypot(dvx, dvy) or 1.0
            ln = 5.0 * (1 - t / 0.55) + 1
            col = C("#fff2c0") if t < 0.18 else C("#ffb04a")
            if elite and i % 2:
                col = GEM_B[4] if t < 0.2 else GEM_B[3]
            F.gline(x - dvx / sp * ln, y - dvy / sp * ln, x, y, col)
        rng = random.Random(44 + elite)  # küçük gerçekçi sikkeler
        for i in range(10 if elite else 7):
            vx, vy = rng.uniform(-80, 80), -rng.uniform(150, 220)
            t = pt - rng.uniform(0, 0.05)
            if t <= 0:
                continue
            y = min(BY * r + 2, my + vy * t + 300 * t * t)
            x = mx + vx * t
            if int(pt * 20 + i) % 3 == 1:
                F.vl(int(x) + 1, int(y), int(y) + 2, DGOLD_B[4])
            else:
                F.sprite([".a.", "abc", ".c."], int(x), int(y), {"a": DGOLD_B[5], "b": DGOLD_B[4], "c": DGOLD_B[2]})
    if pt > 0.45:  # açık beklemede ağızdan yükselen 2 temiz parıltı
        T = st.T
        for i in range(2):
            u = (T * 0.7 + i * 0.5) % 1.0
            star4(F, mx + (-7, 8)[i], my - 4 - u * 22, twinkle(T, i * 0.4, 0.7, 2), core, light, hlen=twinkle(T, i * 0.4, 0.7, 3))


def shadow_B(Sh, cx, y, w, k=1.0):
    rx, ry = w / 2.0 + 6, 7.0
    for yy in range(int(y - ry - 1), int(y + ry + 2)):
        for xx in range(int(cx - rx - 1), int(cx + rx + 2)):
            d = ((xx - cx) / rx) ** 2 + ((yy - y) / ry) ** 2
            if d < 1.0:
                Sh.px(xx, yy, (8, 10, 8, int(170 * (1 - d) ** 0.8)))


# =================================================================== C  Black Desert - cilalı süslü (2x)
MAH_C = R("#160806 #2e0f0a #4a1a10 #6c2816 #923a1e #ba5a2e #e08a50")
BRASS_C = R("#2a1806 #5a3a10 #8c6420 #c09434 #e8c25a #fff0a8")
ROPE_C = R("#3a2a14 #6a5028 #9a7a44 #c8a868 #ecd8a0")
WAX_C = R("#3a0810 #6e1018 #a8202a #d8463e #ff8a78")
PAPER_C = R("#6a5a40 #a8946c #d8c69c #f4e8c8 #fffaf0")
INK_C = C("#2a2030")
OBS_C = R("#050409 #0d0b16 #171428 #241f3c #352d56 #4e4478 #7a6eb0")
GOLD_C = R("#3a2408 #7a5414 #b8862a #e6b84a #ffe08a #fff8d8")
CHAIN_C = R("#14161c #2c323e #4c5666 #7a8698 #b4c0d0 #eef4ff")
MAGIC_C = R("#2a0a4a #5a1e96 #9a4ae0 #d29aff #f6e6ff")
VELV_C = R("#1a0610 #3a0e1e #5e1830 #8a2a46")
VELV_CE = R("#0e061a #22103c #3a1c62 #5a2e8e")
OUT_C = C("#120706")
LIGHT_C = {False: (C("#ffd98a"), C("#fff4d6")), True: (C("#c48aff"), C("#f6e6ff"))}


def c_lacquer(S, x0, y0, x1, y1, ramp, base, slope, seed, gloss_rows=None, streak=None, grain=0.5, arch=None):
    n = len(ramp)
    h = max(1, y1 - y0)
    for y in range(y0, y1 + 1):
        j = y - y0
        ins = arch[j] if arch and j < len(arch) else 0
        for x in range(x0 + ins, x1 - ins + 1):
            v = base - j / float(h) * slope + (vn(x / 14.0, y / 1.4, seed) - 0.5) * grain
            if x >= x1 - 1 - ins:
                v -= 1.2
            elif x <= x0 + ins:
                v += 0.6
            if gloss_rows:
                ga, gb, gs = gloss_rows
                if ga <= j <= gb:
                    v += gs * (1.0 - abs(j - (ga + gb) / 2.0) / ((gb - ga) / 2.0 + 0.8))
            if streak is not None:
                sx, sw, ss = streak
                dd = abs(x - sx - (y - y0) * 0.6)
                if dd < sw:
                    v += ss * (1 - dd / sw)
            S.px(x, y, ramp[dith(x, y, v, n)])


def c_curl(S, cx, cy, d, M, turns=2.4, a0=0.0, k=0.62, rmin=0.8, flip_y=1):
    th = 0.0
    while th < turns * math.pi:
        rr = rmin + th * k
        S.px(cx + d * rr * math.cos(th + a0), cy + flip_y * rr * math.sin(th + a0) * 0.85,
             M[4] if math.sin(th + a0) * flip_y < 0 else M[3])
        th += 0.18 / max(0.6, rr * 0.25)


def c_bracket(S, cx, cy, dx, dy, M, n=8):
    for i in range(n):
        for t in range(2):
            S.px(cx + dx * i, cy + dy * t, M[4 if t == 0 else 2])
            S.px(cx + dx * t, cy + dy * i, M[4 if t == 0 else 2])
    c_curl(S, cx + dx * 4, cy + dy * 4, dx, M, turns=1.6, a0=math.pi if dy < 0 else 0.0, k=0.7, flip_y=dy)


def c_rope_v(S, x0, y0, y1, ramp, shift=0):
    for y in range(y0, y1 + 1):
        for i in range(4):
            t = (y + shift + i) % 6 if i < 2 else (y + shift - i) % 6
            S.px(x0 + i, y, ramp[(1, 2, 3, 4, 3, 2)[t] - (1 if i == 3 else 0)])


def c_rope_h(S, x0, x1, y0, ramp, shift=0):
    for x in range(x0, x1 + 1):
        for j in range(4):
            t = (x + shift + j) % 6 if j < 2 else (x + shift - j) % 6
            S.px(x, y0 + j, ramp[(1, 2, 3, 4, 3, 2)[t] - (1 if j == 3 else 0)])


def c_chain(S, p0, p1, M, phase=0):
    n = int(math.hypot(p1[0] - p0[0], p1[1] - p0[1]))
    dx, dy = (p1[0] - p0[0]) / n, (p1[1] - p0[1]) / n
    for i in range(0, n, 4):
        x, y = p0[0] + dx * i, p0[1] + dy * i
        if ((i // 4) + phase) % 2 == 0:
            S.sprite([".bc.", "a..d", ".dd."], int(x) - 1, int(y) - 1, {"a": M[3], "b": M[5], "c": M[4], "d": M[1]})
        else:
            S.sprite(["b", "c", "d"], int(x), int(y) - 1, {"b": M[4], "c": M[3], "d": M[1]})


def c_seal(F, cx, cy, T, crack=0.0, burst=-1.0):
    """İnce çizgili büyü mührü: iki halka, arasında dönen rün çentikleri, içte ters dönen altıgen yıldız."""
    def put(x, y, c):
        a = 1.0
        if burst >= 0:  # 6 bütün yay parçası dışa uçar (piksel piksel saçılmaz), alfa bant bant söner
            seg = int((math.atan2(y - cy, x - cx) % math.tau) / (math.tau / 6))
            am = (seg + 0.5) * math.tau / 6
            dd = burst * 90
            x, y = x + math.cos(am) * dd, y + math.sin(am) * dd + 160 * burst * burst
            a = 1 - burst / 0.4
        F.glow(x, y, c, a)
    for rr, col in ((14, MAGIC_C[3]), (11, MAGIC_C[2])):
        n = int(rr * 6.6)
        for i in range(n):
            if crack > 0 and (i * 7) % 11 < crack * 4:
                continue
            a = i / float(n) * math.tau
            put(cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.92, col)
    for k in range(12):
        a = k / 12.0 * math.tau + T * 0.8
        x, y = cx + math.cos(a) * 12.5, cy + math.sin(a) * 12.5 * 0.92
        put(x, y, MAGIC_C[4] if k % 3 == 0 else MAGIC_C[3])
    for tri, sgn in ((0, 1), (1, -1)):
        pts = [(cx + math.cos(sgn * T * 0.6 + tri * math.pi / 3 + q * math.tau / 3 - math.pi / 2) * 9,
                cy + math.sin(sgn * T * 0.6 + tri * math.pi / 3 + q * math.tau / 3 - math.pi / 2) * 9 * 0.92) for q in range(3)]
        for q in range(3):
            a_, b_ = pts[q], pts[(q + 1) % 3]
            for s in range(16):
                u = s / 16.0
                put(a_[0] + (b_[0] - a_[0]) * u, a_[1] + (b_[1] - a_[1]) * u, MAGIC_C[2])
    pulse = 0.5 + 0.5 * math.sin(T * 4.0)
    for dx_, dy_ in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
        put(cx + dx_, cy + dy_, WHITE if (dx_, dy_) == (0, 0) or pulse > 0.5 else MAGIC_C[4])


def draw_C(Lb, S, F, Fo, elite, st):
    r = 2
    cx = CX * r + st.dx() * r
    by = BY * r + bob(st) * r
    light, core = LIGHT_C[elite]
    if elite:
        w, bh, lf, lt, LAC, TR = 54, 22, 12, 10, OBS_C, GOLD_C
    else:
        w, bh, lf, lt, LAC, TR = 46, 18, 10, 9, MAH_C, BRASS_C
    x0, x1 = cx - w // 2, cx + w // 2 - 1
    bt = by - bh
    T = st.T
    seed = 6 if elite else 2
    lift = st.lift() * r
    gl = (T % 2.4) / 0.7  # kayan parıltı (2,4 sn'de bir)
    streak = (x0 - 10 + gl * (w + 30), 4, 2.2) if st.ph == "idle" and gl < 1.0 else None
    c_lacquer(S, x0, bt, x1, by - 1, LAC, 3.4 if elite else 3.6, 1.8, seed, streak=streak, grain=0.3 if elite else 0.8)
    if elite:  # gövde altın kakma: orta madalyon + iki yanda S kıvrımlar
        my_ = bt + bh // 2 + 1
        S.ellipse(cx, my_, 3.6, 3.6, TR[2])
        S.ellipse(cx - 0.4, my_ - 0.4, 2.6, 2.6, TR[4])
        S.px(cx, my_, TR[5])
        for d in (-1, 1):
            c_curl(S, cx + d * 9, my_ - 2, d, TR, turns=2.2, k=0.55)
            c_curl(S, cx + d * 17, my_ + 2, -d, TR, turns=2.0, k=0.5, flip_y=-1)
            for i in range(4, 9):
                S.px(cx + d * i, my_ + (1 if i % 2 else 0) - 1, TR[3])
        for yy in range(bt, by):
            S.px(x0 + 1, yy, TR[4])
            S.px(x1 - 1, yy, TR[2])
        S.hl(x0 + 1, x1 - 1, by - 2, TR[2])
    else:
        c_rope_h(S, x0, x1, by - 9, ROPE_C, st.step if st.ph == "shake" else 0)
        for x in range(x0 + 1, x1):
            S.over(x, by - 5, LAC[1])
    for sx, d in ((x0, 1), (x1, -1)):
        c_bracket(S, sx, by - 1, d, -1, TR, n=8 if elite else 7)
    if st.ph == "open":
        ot = 8
        oy = bt - ot
        S.hl(x0, x1, oy, TR[4])
        S.hl(x0, x1, oy + 1, TR[2])
        V = VELV_CE if elite else VELV_C
        for y in range(oy + 2, bt):
            for x in range(x0 + 1, x1):
                S.px(x, y, V[dith(x, y, 1.4 + (y - oy) / float(ot) * 1.6 + (0.6 if (x + y) % 5 == 0 else 0), 4)])
        if elite:  # ışıyan kristaller
            for kx, kh in ((cx - 10, 7), (cx - 2, 11), (cx + 7, 8), (cx + 13, 5)):
                for j in range(kh):
                    half = max(0, int((kh - j) * 0.35 + 0.5)) if j > kh * 0.4 else int(j * 0.9)
                    for i in range(-half, half + 1):
                        S.px(kx + i, bt - 2 - j, MAGIC_C[4] if i < 0 else MAGIC_C[3] if i == 0 else MAGIC_C[2])
        else:  # ince sikke yığını
            for x in range(x0 + 4, x1 - 3):
                u = (x - x0 - 4) / float(w - 8)
                hgt = int(round(4.5 * math.sin(u * math.pi)))
                for k in range(hgt + 1):
                    S.px(x, bt - 2 - k, BRASS_C[5 if (x * 3 + k) % 7 == 0 else 4 if k == hgt else 3 if (x + k) % 3 else 2])
        oh = lf + lt - 2
        ly1 = oy - 1 + lid_pop(st.pt, (-4, -2, 0))
        ly0 = ly1 - oh + 1
        c_lacquer(S, x0, ly0, x1, ly1, LAC, 1.6, 0.6, seed + 3, arch=[4, 2, 1, 1], grain=0.4)
        for y in range(ly0 + 3, ly1 + 1):
            for x in range(x0 + 3, x1 - 2):
                S.px(x, y, V[dith(x, y, 1.0 + (y - ly0) / float(oh) * 1.2, 4)])
        S.hl(x0 + 1, x1 - 1, ly1, TR[2])
        mouth_y = bt - 3
    else:
        ft = bt - lift - lf
        tt = ft - lt
        c_lacquer(S, x0 - 1, tt, x1 + 1, ft - 1, LAC, 5.0 if elite else 5.4, 1.4, seed + 1, arch=[5, 3, 2, 1, 1], grain=0.3)
        c_lacquer(S, x0 - 1, ft, x1 + 1, bt - 1 - lift, LAC, 4.0 if elite else 4.2, 1.2, seed + 2,
                  gloss_rows=(2, 4, 2.4), streak=streak, grain=0.3 if elite else 0.7)
        S.hl(x0 - 1, x1 + 1, bt - 2 - lift, TR[4])
        S.hl(x0 - 1, x1 + 1, bt - 1 - lift, TR[1])
        S.hl(x0 + 4, x1 - 4, tt, TR[4])
        for sx, d in ((x0 - 1, 1), (x1 + 1, -1)):
            c_bracket(S, sx, bt - 2 - lift, d, -1, TR, n=6)
        if elite:
            for xx in range(x0 + 3, x1 - 2):  # kapak üstü ince altın çerçeve
                S.px(xx, ft + 2, TR[3])
                S.px(xx, bt - 4 - lift, TR[2])
            c_curl(S, cx - 4, ft + 5, -1, TR, turns=1.8, k=0.5)
            c_curl(S, cx + 4, ft + 5, 1, TR, turns=1.8, k=0.5)
            jit = st.step % 2 if st.ph == "shake" else 0
            c_chain(S, (x0 + 2, tt + 3), (x1 - 4, by - 4), CHAIN_C, phase=jit)
            c_chain(S, (x1 - 3, tt + 3), (x0 + 1, by - 4), CHAIN_C, phase=1 - jit)
            sy = bt - 3 - lift + (int(round(math.sin(T * 2.5) * 1.5)) if st.ph == "idle" else 0)
            c_seal(F, cx, sy, T * (1 + 2 * st.k), crack=st.k if st.ph == "shake" else 0.0)
            if st.ph == "idle":  # mührün iki yanında yavaş yükselen 2 ince parıltı
                for i in range(2):
                    u = (T * 0.3 + i * 0.5) % 1.0
                    star4(F, cx + (-18, 17)[i], sy + 2 - u * 18, twinkle(T, i * 0.5, 1.0, 2), MAGIC_C[4], MAGIC_C[3])
        else:
            c_rope_v(S, cx - 2, tt + 3, by - 1, ROPE_C, st.step if st.ph == "shake" else 0)
            sy = bt - 2 - lift  # kabartmalı mum mühür + damla
            for yy in range(sy - 6, sy + 7):
                for xx in range(cx - 6, cx + 7):
                    d = math.hypot(xx - cx, (yy - sy) * 1.05)
                    if d <= 6.3:
                        v = 3.0 + (-(xx - cx) - (yy - sy)) / 6.0 * 0.9
                        if 3.4 < d < 4.4:
                            v -= 1.3
                        if d > 5.6:
                            v -= 0.7
                        S.px(xx, yy, WAX_C[dith(xx, yy, v, 5)])
            S.sprite(["..a..", ".aba.", "abcba", ".aba.", "..a.."], cx - 2, sy - 2, {"a": WAX_C[4], "b": WAX_C[2], "c": WAX_C[1]})
            S.px(cx - 3, sy + 6, WAX_C[2])
            S.px(cx - 3, sy + 7, WAX_C[1])
            S.px(cx + 2, sy + 6, WAX_C[2])
            sw = math.sin(T * 2.2) * 2.0 if st.ph == "idle" else st.dx() * 2  # mürekkepli etiket (ipe asılı)
            tx, ty = x1 - 14, by - 5
            for j in range(4):
                S.px(tx + 4 + sw * j / 14.0, ty + j, ROPE_C[2])
            for j in range(13):
                o = int(round(sw * (j + 4) / 14.0))
                for i in range(10):
                    if j == 12 and i in (0, 9):
                        continue
                    c = PAPER_C[dith(tx + i, ty + 4 + j, 3.1 - j / 13.0 * 0.8 + (0.5 if i < 2 else -0.5 if i > 7 else 0), 5)]
                    if j in (5, 7, 9) and 2 <= i <= 7 and (i + j) % 4 != 0:
                        c = INK_C
                    if j == 2 and 4 <= i <= 5:
                        c = BRASS_C[3]
                    S.px(tx + i + o, ty + 4 + j, c)
        if lift:  # ince ışık çizgisi + yumuşak taşma
            for y in range(bt - lift, bt):
                S.hl(x0, x1, y, core if y == bt - 1 else light)
            for i in range(1, 8 + int(st.k * 18)):
                F.glow(x0 - i, bt - 1, light, 1 - i / 26.0)
                F.glow(x1 + i, bt - 1, light, 1 - i / 26.0)
        mouth_y = bt - 1
    return dict(cx=cx, mouth=(cx, mouth_y), w=w, x0=x0, x1=x1, by=by, bt=bt)


def fx_C(F, Fo, g, elite, st):
    if st.ph != "open":
        return
    pt = st.pt
    light, core = LIGHT_C[elite]
    mx, my = g["mouth"]
    if pt < 0.5:  # ince halka dalgası: kesintisiz 1 px çizgi, alfa bantla söner
        k = pt / 0.5
        F.gring(mx, my, 16 + 70 * k, 6 + 26 * k, core if k < 0.4 else light, 1 - k)
    if pt < 0.6:  # ince ışınlar: düz çizgi, uca doğru bant bant söner
        g_ = min(1.0, pt / 0.1)
        fade = 1.0 if pt < 0.25 else max(0.0, 1 - (pt - 0.25) / 0.35)
        for i in range(9):
            ang = -math.pi / 2 + (i - 4) / 4.0 * 1.05
            ln = (78 if elite else 62) * (0.75 + 0.25 * math.sin(i * 2.7)) * g_
            for d in range(5, int(ln)):
                u = d / ln
                F.glow(mx + math.cos(ang) * d, my + math.sin(ang) * d, core if u < 0.4 else light,
                       (0.9 if u < 0.4 else 0.6 if u < 0.75 else 0.3) * fade)
    if elite and pt < 0.4:
        c_seal(F, mx, g["bt"] - 3, st.T, burst=pt)
    if pt > 0.05:  # yavaş yükselen birkaç ince 4 kollu parıltı (tek piksel serpinti yerine)
        rng = random.Random(7 + elite)
        for i in range(5 if elite else 4):
            t = pt - 0.05 - i * 0.12
            if t <= 0 or t > 1.4:
                continue
            x = mx + rng.uniform(-g["w"] * 0.4, g["w"] * 0.4) + math.sin(t * 3 + i) * 2
            y = my - 4 - t * rng.uniform(22, 34)
            rr = twinkle(t, 0.0, 1.0, 2)
            star4(F, x, y, rr, MAGIC_C[4] if elite else BRASS_C[5], MAGIC_C[3] if elite else BRASS_C[4])
    if not elite and 0 < pt < 0.7:  # kopan ip lifleri + kırılan mühür
        rng = random.Random(12)
        for i in range(6):
            vx, vy = rng.uniform(-80, 80), -rng.uniform(40, 110)
            x, y = mx + vx * pt, g["bt"] + vy * pt + 280 * pt * pt
            if y < BY * 2 + 2:
                for d in range(4):
                    F.glow(x + d * (1 if vx > 0 else -1), y + d * 0.4, ROPE_C[3] if d % 2 else ROPE_C[4], 1 - pt / 0.7)
        for s in (-1, 1):
            x, y = mx + s * (3 + 40 * pt), g["bt"] + 1 - 50 * pt + 280 * pt * pt
            if y < BY * 2 + 2:
                F.sprite(["ab", "bc"] if s < 0 else ["ba", "cb"], int(x), int(y), {"a": WAX_C[4], "b": WAX_C[2], "c": WAX_C[1]})


def shadow_C(Sh, cx, y, w, k=1.0):
    rx, ry = w / 2.0 + 3, 5.0
    for yy in range(int(y - ry - 1), int(y + ry + 2)):
        for xx in range(int(cx - rx - 1), int(cx + rx + 2)):
            d = ((xx - cx) / rx) ** 2 + ((yy - y) / ry) ** 2
            if d < 1.0:
                Sh.px(xx, yy, (14, 10, 18, int(130 * min(1.0, (1 - d) * 3.0))))


# =================================================================== D  MapleStory - çizgi film
OUT_D = C("#24122c")
D_RED = (C("#ff5e52"), C("#c8304a"))
D_YEL = (C("#ffd84a"), C("#e8941e"))
D_SKY = (C("#62c4ff"), C("#2f7ee0"))
D_PINK = (C("#ff8ad8"), C("#d9489e"))
D_WING = (C("#ffffff"), C("#c4d0f0"))
D_IN = (C("#7a2a3a"), C("#4a1828"))
D_INE = (C("#2f4fa4"), C("#1c2c66"))
LIGHT_D = {False: C("#fff09a"), True: C("#bfe6ff")}
STAR_D = ["...o...", "..oyo..", "oooyooo", "oyyyyso", ".oyyso.", "oyso.so", "ooo..oo"]
WINGD_UP = ["...oo....", "..owwo...", ".owwwwo..", "owwwwwwoo", "owwswwwwo", ".oswwswwo", "..oossswo", "....oooo."]
WINGD_DN = list(reversed(WINGD_UP))


def d_cel(pal, x, y, xa, xb, yb):
    return pal[1] if (x > xa + (xb - xa) * 0.68 or y >= yb - 1) else pal[0]


def d_star(L_, x, y, fill, shade, out=OUT_D):
    L_.sprite(STAR_D, int(x) - 3, int(y) - 3, {"o": out, "y": fill, "s": shade})


def d_burst(F, cx, cy, R_, rot, fill, inner):
    for y in range(int(cy - R_ - 2), int(cy + R_ + 3)):
        for x in range(int(cx - R_ - 2), int(cx + R_ + 3)):
            dx_, dy_ = x - cx, (y - cy) * 1.15
            d = math.hypot(dx_, dy_)
            s = ((math.atan2(dy_, dx_) + rot) / math.tau * 8.0) % 1.0
            rr = R_ * (0.5 + 0.5 * (1 - 2 * abs(s - 0.5)) ** 1.6)
            if d < rr - 1.2:
                F.px(x, y, WHITE if d < rr * 0.45 else inner if d < rr * 0.7 else fill)
            elif d < rr:
                F.px(x, y, OUT_D)


def draw_D(Lb, S, F, Fo, elite, st):
    BODY = D_YEL if elite else D_RED
    LID = D_SKY if elite else D_RED
    RIM = D_YEL
    light = LIGHT_D[elite]
    hgt, sx, sy, air = hop(st.T) if st.ph == "idle" else (0, 0, 0, False)
    w = (25 if elite else 23) + sx
    if w % 2 == 0:
        w += 1
    bh = (11 if elite else 10) + min(0, sy)
    dh = 12 + max(0, sy)
    cx = CX + st.dx()
    by = BY - hgt
    x0, x1 = cx - w // 2, cx + w // 2
    bt = by - 2 - bh
    T = st.T
    for fx0 in (x0 + 2, x1 - 5):  # ayaklar
        S.sprite([".yy.", "yyss"], fx0, by - 2, {"y": RIM[0], "s": RIM[1]})
    for y in range(bt, by - 2):  # gövde: cel + üstte kalın sarı şerit, iç çizgiler
        ins = 1 if y == by - 3 else 0
        for x in range(x0 + ins, x1 - ins + 1):
            S.px(x, y, d_cel(BODY, x, y, x0, x1, by - 2))
    S.hl(x0, x1, bt, OUT_D)
    for y in (bt + 1, bt + 2):
        for x in range(x0, x1 + 1):
            S.px(x, y, d_cel(RIM, x, y, x0, x1, 999))
    S.hl(x0, x1, bt + 3, OUT_D)
    if elite:  # mavi dikey kayışlar (çizgili)
        for px0 in (x0 + 3, x1 - 5):
            for y in range(bt + 4, by - 3):
                S.px(px0, y, OUT_D)
                S.px(px0 + 1, y, D_SKY[0])
                S.px(px0 + 2, y, OUT_D)
    else:
        S.hl(x0 + 2, x0 + 3, bt + 5, WHITE)
    lw, lx0 = w + 2, x0 - 1
    ins = [7, 4, 3, 2, 1, 1] + [0] * dh
    lift = st.lift()
    if st.ph == "open":
        oy = bt - 4
        S.hl(x0, x1, oy, OUT_D)
        V = D_INE if elite else D_IN
        for y in range(oy + 1, bt):
            for x in range(x0 + 1, x1):
                S.px(x, y, V[1] if y < oy + 2 else V[0])
            S.px(x0, y, OUT_D)
            S.px(x1, y, OUT_D)
        for x in range(x0 + 3, x1 - 2):  # çizgili sikke yığını
            u = (x - x0 - 3) / float(w - 6)
            hh = int(round(2.4 * math.sin(u * math.pi)))
            for k in range(hh + 1):
                S.px(x, bt - 1 - k, D_YEL[0] if (x + k) % 3 else D_YEL[1])
            S.px(x, bt - 2 - hh, OUT_D)
        if elite:
            d_star(S, cx, bt - 4, D_PINK[0], D_PINK[1])
        oh = dh - 2
        ly1 = oy - 1 + lid_pop(st.pt, (-4, -1, 1, 0))
        ly0 = ly1 - oh + 1
        for j in range(oh):
            xa, xb = lx0 + ins[j + 1], lx0 + lw - 1 - ins[j + 1]
            for x in range(xa, xb + 1):
                c = RIM[0] if j <= 1 else OUT_D if j == 2 else V[1] if (j + x) % 4 == 0 else V[0]
                S.px(x, ly0 + j, c)
        mouth_y = bt - 2
        wy = oy - 2
    else:
        ly0 = bt - dh - lift
        for j in range(dh):
            xa, xb = lx0 + ins[j], lx0 + lw - 1 - ins[j]
            y = ly0 + j
            for x in range(xa, xb + 1):
                if j == dh - 1 or j == dh - 4:
                    c = OUT_D
                elif j >= dh - 3:
                    c = d_cel(RIM, x, y, xa, xb, 999)
                else:
                    c = LID[0] if j <= 1 else d_cel(LID, x, y, xa, xb, ly0 + dh - 4)
                S.px(x, y, c)
        gx = lx0 + 4  # anime parlama şeritleri
        S.hl(gx + 2, gx + 6, ly0 + 2, WHITE)
        S.hl(gx + 1, gx + 2, ly0 + 3, WHITE)
        S.px(gx + 8, ly0 + 2, WHITE)
        if (T % 2.0) < 0.25 and st.ph == "idle":
            d_star(Fo, gx + 6, ly0 + 1, WHITE, D_WING[1])
        if elite:
            d_star(S, cx, ly0 - 2, D_PINK[0], D_PINK[1])
        ky = bt - 4 - lift  # iri yuvarlak kilit: çizgili halka + cel + parlama
        for yy in range(ky, ky + 9):
            for xx in range(cx - 4, cx + 5):
                d = math.hypot(xx - cx, yy - (ky + 4))
                if d <= 4.3:
                    S.px(xx, yy, OUT_D if d > 3.3 else (RIM[1] if (xx - cx) + (yy - ky - 4) > 1 else RIM[0]))
        S.px(cx - 2, ky + 2, WHITE)
        S.vl(cx, ky + 4, ky + 6, OUT_D)
        S.px(cx, ky + 3, OUT_D)
        if lift:
            for y in range(bt - lift, bt):
                S.hl(x0 + 1, x1 - 1, y, light)
            for ddx, ddy in ((-3, -6), (-5, -2), (-4, 2), (3, -6), (5, -2), (4, 2)):  # hareket çizgileri
                side = x0 - 3 if ddx < 0 else x1 + 3
                for k in range(int(2 + st.k * 2)):
                    F.px(side + (-k if ddx < 0 else k) + ddx // 3, bt + ddy + st.step % 2, OUT_D)
        mouth_y = bt - 1
        wy = ly0 + 4
    if elite:
        flap = (int(T / 0.08) % 2 == 0) if (air or st.ph != "idle") else (int(T / 0.45) % 2 == 0)
        rows = WINGD_UP if flap else WINGD_DN
        pal = {"o": OUT_D, "w": D_WING[0], "s": D_WING[1]}
        S.sprite(rows, lx0 - 8, wy, pal)
        S.sprite(rows, lx0 + lw - 1, wy, pal, flip=True)
    return dict(cx=cx, mouth=(cx, mouth_y), w=w, x0=x0, x1=x1, hgt=hgt)


def fx_D(F, Fo, g, elite, st):
    if st.ph != "open":
        return
    pt = st.pt
    mx, my = g["mouth"]
    light = LIGHT_D[elite]
    if pt < 0.22:
        k = pt / 0.08 if pt < 0.08 else 1 - (pt - 0.08) / 0.14
        d_burst(F, mx, my - 3, 4 + 14 * k, pt * 3, D_SKY[0] if elite else D_YEL[0], light)
    if 0 < pt < 0.85:
        rng = random.Random(5 + elite)
        for i in range(7 if elite else 5):  # kontürlü yıldızlar
            vx, vy = rng.uniform(-50, 50), -rng.uniform(80, 120)
            t = pt - rng.uniform(0, 0.06)
            if t <= 0 or t > 0.7:
                continue
            pal = D_PINK if (elite and i % 2) else D_YEL
            d_star(Fo, mx + vx * t, my + vy * t + 170 * t * t, pal[0], pal[1])
        rng = random.Random(15 + elite)
        for i in range(6):  # kontürlü sikkeler
            vx, vy = rng.uniform(-40, 40), -rng.uniform(90, 125)
            t = pt - rng.uniform(0.02, 0.08)
            if t <= 0 or t > 0.7:
                continue
            x, y = mx + vx * t, min(BY, my + vy * t + 280 * t * t)
            if int(pt * 16 + i) % 2:
                Fo.sprite([".oo.", "oyso", "oyso", ".oo."], int(x) - 2, int(y) - 2, {"o": OUT_D, "y": D_YEL[0], "s": D_YEL[1]})
            else:
                Fo.sprite(["oo", "yo", "so", "oo"], int(x), int(y) - 2, {"o": OUT_D, "y": D_YEL[0], "s": D_YEL[1]})
        rng = random.Random(25 + elite)
        cols = [D_PINK[0], D_SKY[0], D_YEL[0], WHITE] if elite else [D_RED[0], D_YEL[0], C("#7ee06a"), D_SKY[0]]
        for i in range(9):  # konfeti: az sayıda iri parça (3x1 / 1x3 / 2x2 döner), parça parça kaybolur
            vx, vy = rng.uniform(-60, 60), -rng.uniform(70, 120)
            x, y = int(mx + vx * pt), int(my + vy * pt + 150 * pt * pt)
            if pt > 0.55 + (i % 4) * 0.06:
                continue
            ph = int(pt * 14 + i) % 3
            if ph == 0:
                F.hl(x - 1, x + 1, y, cols[i % 4])
            elif ph == 1:
                F.vl(x, y - 1, y + 1, cols[i % 4])
            else:
                F.rect(x, y, x + 1, y + 1, cols[i % 4])
    if pt > 0.5 and (st.T % 0.6) < 0.3:
        d_star(Fo, mx + (5 if int(st.T / 0.6) % 2 else -6), my - 7, WHITE, D_WING[1])


def shadow_D(Sh, cx, y, w, k=1.0):
    Sh.ellipse(cx, y, (w / 2.0) * k, 2.4 * k, (36, 18, 44, 120))


# ------------------------------------------------------------------ çizim girişi
STYLE = {
    "A": (draw_A, fx_A, lambda S: outline_paint(S, OUT_A), shadow_A),
    "B": (draw_B, fx_B, lambda S: outline_selout(S), shadow_B),
    "C": (draw_C, fx_C, lambda S: outline_aa(S, OUT_C), shadow_C),
    "D": (draw_D, fx_D, lambda S: outline_flat(S, OUT_D), shadow_D),
}


def render(did, elite, st):
    """(gölge, sandık) RGBA numpy; boyut CW*r x CH*r."""
    r = RES[did]
    Sh, Lb, S, F, Fo = L(r), L(r), L(r), L(r), L(r)
    draw, fx, outl, shad = STYLE[did]
    g = draw(Lb, S, F, Fo, elite, st)
    outl(S)
    fx(F, Fo, g, elite, st)
    outline_flat(Fo, OUT_D)
    k = max(0.55, 1.0 - g.get("hgt", 0) / 12.0)
    shad(Sh, CX * r + st.dx() * r, (BY + 1) * r - (r - 1), g["w"] + 3 * r, k)
    return comp(Sh), comp(Lb, S, Fo, F)


# ------------------------------------------------------------------ ŞU AN (mevcut sayfalar)
_CUR = {}


def cur_sheet(elite):
    if elite not in _CUR:
        _CUR[elite] = asset("assets/sprites/chests/%s.png" % ("chest_elite" if elite else "chest_normal_t1"))
    return _CUR[elite]


REWARD_TL = [[0, 0.18], [1, 0.12], [2, 0.08], [3, 0.08], [4, 0.14], [5, 0.12], [6, 0.12], [7, 0.14],
             [8, 0.07], [9, 0.06], [10, 0.06], [11, 0.06], [12, 0.07], [13, 0.07], [14, 0.08], [15, 0.08]]


def cur_frame_reward(ot):
    t = 0.0
    for f, d in REWARD_TL:
        if ot < t + d:
            return f
        t += d
    return [16, 17, 18, 19][int((ot - t) / 0.12) % 4]


def render_cur(elite, frame, dy=0):
    im = cur_sheet(elite).crop((frame * 48, 0, frame * 48 + 48, 48))
    out = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    out.alpha_composite(im, (CX - 24, BY - 42 + dy))
    sh = L(1)
    sh.ellipse(CX, BY + 1, 13, 2.6, (16, 22, 14, 92))
    return comp(sh), np.asarray(out)


def cur_idle_frame(elite, T):
    if elite:
        return int(T / 0.16) % 4
    t = T % 2.4
    return 2 if 2.24 < t <= 2.32 else 3 if t > 2.32 else 0


def frame_for(did, elite, st):
    if did == "cur":
        if st.ph == "idle":
            return render_cur(elite, cur_idle_frame(elite, st.T), bob(st))
        if st.ph == "shake":
            return render_cur(elite, 4 + st.step)
        return render_cur(elite, cur_frame_reward(0.98 + st.pt))
    return render(did, elite, st)


def st_at(ot, T):
    if ot < 0.46:
        return St("idle", 0.0, T)
    if ot < 0.98:
        return St("shake", ot - 0.46, T)
    return St("open", ot - 0.98, T)


# ------------------------------------------------------------------ çıktı yardımcıları
ORDER = ["cur", "A", "B", "C", "D"]
NAMES = {"cur": "ŞU AN", "A": "A  Kubbeli Hazine", "B": "B  Işık Sütunu", "C": "C  Zincirli Mühür", "D": "D  Tombul Masal"}
REFS = {"cur": "gen_chest_sprites.py", "A": "WoW · elle boyanmış", "B": "Lost Ark/Diablo · kasvetli, 2x ince",
        "C": "Black Desert · cilalı süslü, 2x ince", "D": "MapleStory · çizgi film"}


def to_img(arr, did, k):
    """Tuval -> ekran: k = dünya px başına ekran px; ince yönlerde (r=2) sanat pikseli k/2."""
    s = max(1, k // RES[did])
    im = Image.fromarray(arr, "RGBA")
    return im.resize((im.width * s, im.height * s), Image.NEAREST)


def header(w, title, sub):
    im = Image.new("RGBA", (w, 38), (30, 34, 32, 255))
    d = ImageDraw.Draw(im)
    label(d, 8, 3, title, 14)
    label(d, 8, 21, sub, 10, (200, 196, 182))
    return im


def stack(parts, gap=3):
    W = max(p.width for p in parts)
    H = sum(p.height for p in parts) + gap * (len(parts) - 1)
    im = Image.new("RGBA", (W, H), (18, 20, 20, 255))
    y = 0
    for p in parts:
        im.alpha_composite(p, (0, y))
        y += p.height + gap
    return im


def save_gif(frames, path, fps):
    rgb = [f.convert("RGB") for f in frames]
    sample = Image.new("RGB", (rgb[0].width, rgb[0].height * 3))
    for i, idx in enumerate((len(rgb) // 4, len(rgb) // 2, int(len(rgb) * 0.8))):
        sample.paste(rgb[idx], (0, rgb[0].height * i))
    pal = sample.quantize(255, method=Image.Quantize.MEDIANCUT)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in rgb]
    q[0].save(path, save_all=True, append_images=q[1:], duration=int(round(1000.0 / fps)), loop=0, disposal=1)
    print("gif", path, len(q))


# ------------------------------------------------------------------ özet
def build_ozet():
    k = 4
    cw, chh = 60 * k, 66 * k
    top, lab_w = 46, 110
    W = lab_w + len(ORDER) * cw
    rows = [("normal  kapalı", False, St("idle", 0, 0.5)), ("normal  açık", False, St("open", 1.0, 0.3)),
            ("elit  kapalı", True, St("idle", 0, 0.5)), ("elit  açık", True, St("open", 1.0, 0.3))]
    H = top + len(rows) * chh
    im = Image.new("RGBA", (W, H), (34, 38, 40, 255))
    d = ImageDraw.Draw(im)
    for i, did in enumerate(ORDER):
        label(d, lab_w + i * cw + 8, 6, NAMES[did], 12)
        label(d, lab_w + i * cw + 8, 24, REFS[did], 10, (190, 186, 170))
    for ri, (nm, el, st) in enumerate(rows):
        y0 = top + ri * chh
        d.rectangle((0, y0, W, y0 + chh - 1), fill=(44, 50, 46, 255) if ri % 2 == 0 else (40, 46, 44, 255))
        label(d, 8, y0 + chh // 2 - 8, nm, 12)
    for ri, (nm, el, st) in enumerate(rows):
        y0 = top + ri * chh
        for i, did in enumerate(ORDER):
            for arr in frame_for(did, el, st):
                part = to_img(arr, did, k)
                ox = lab_w + i * cw + (cw - part.width) // 2
                oy = y0 + chh - (BY + 6) * k
                ct = max(0, y0 + 2 - oy)
                if ct:
                    part = part.crop((0, ct, part.width, part.height))
                im.alpha_composite(part, (ox, oy + ct))
    im = im.convert("RGB")
    p = os.path.join(OUT, "sandik_ozet.png")
    im.save(p)
    print("png", p, im.size)


# ------------------------------------------------------------------ oyun ölçeği
LANE_W, LANE_H = 250, 92
_BGW = None


def lane_bg(i):
    global _BGW
    if _BGW is None:
        im = Image.open(os.path.join(GAME, "tools/proto_20261016/harita_renk/harita_doygunluk_once_sonra.png")).convert("RGBA")
        _BGW = im.crop((494, 336, 494 + 250, 336 + 128))
    y = (0, 36, 18, 30, 6)[i]
    c = _BGW.crop((0, y, LANE_W, y + LANE_H))
    if i % 2:
        c = c.transpose(Image.FLIP_LEFT_RIGHT)
    c = c.resize((LANE_W * ZOOM, LANE_H * ZOOM), Image.NEAREST)
    ch = asset("assets/characters/assasin/sheets/idle.png", (0, 96, 48, 144))
    kk = CHAR_K * ZOOM
    chi = ch.resize((int(48 * kk), int(48 * kk)), Image.NEAREST)
    c.alpha_composite(chi, (22 * ZOOM - chi.width // 2, 82 * ZOOM - int(40 * kk)))
    return c


def world_state(T, offset):
    """Dünyada: 2,4 sn bekleme -> 0,2 sn sallanma -> 0,45 sn açılış (ödül saatinin ~1,6 katı hızlı) + 0,18 sn sönme."""
    t = (T + offset) % 3.6
    if t < 2.4:
        return St("idle", 0, T), min(1.0, t / 0.2)
    if t < 2.6:
        return St("shake", (t - 2.4) / 0.2 * 0.52, T), 1.0
    if t > 3.23:
        return St("idle", 0, T), 0.0
    return St("open", (t - 2.6) * 1.6, T), (1.0 if t < 3.05 else max(0.0, 1.0 - (t - 3.05) / 0.18))


def build_oyun():
    lanes = [lane_bg(i) for i in range(len(ORDER))]
    hd = header(LANE_W * ZOOM, "Sandıklar v2  ·  oyun ölçeği (kamera x2, gerçek harita + karakter)",
                "sol: normal  ·  sağ: elit  ·  B ve C 2x ince piksel (0,5 dünya px)")
    n = int(3.6 * FPS)
    frames = []
    for s in range(n):
        T = s / float(FPS)
        parts = [hd]
        for i, did in enumerate(ORDER):
            lane = lanes[i].copy()
            for j, el in enumerate((False, True)):
                st, a = world_state(T, 0.25 * j)
                if a <= 0.0:
                    continue
                if did == "cur" and st.ph == "open":
                    pair = render_cur(el, min(12, 8 + int(st.pt / 0.08)))
                else:
                    pair = frame_for(did, el, st)
                cx = 105 + j * 85
                for arr in pair:
                    im = to_img(arr, did, ZOOM)
                    if a < 1.0:
                        al = np.asarray(im).copy()
                        al[:, :, 3] = (al[:, :, 3] * a).astype(np.uint8)
                        im = Image.fromarray(al, "RGBA")
                    lane.alpha_composite(im, ((cx - CX) * ZOOM, (86 - BY) * ZOOM))
            label(ImageDraw.Draw(lane), 6, 4, NAMES[did], 11)
            parts.append(lane)
        frames.append(stack(parts))
    save_gif(frames, os.path.join(OUT, "sandik_oyun.gif"), FPS)
    frames[int(1.0 * FPS)].save(os.path.join(OUT, "sandik_oyun_kare.png"))


# ------------------------------------------------------------------ ödül ekranı (yakın)
def build_odul():
    kk = 4  # dünya px başına 4 ekran px (ince yönlerde sanat pikseli 2x2)
    cw, chh = 60 * kk, 76 * kk
    top = 44
    W = len(ORDER) * cw
    H = top + 2 * chh + 20
    n = int((0.98 + 0.55 + 0.9) * FPS)
    hd = header(W, "Ödül ekranı gibi yakın (dünya x4)  ·  tam açılış dizisi",
                "üst: normal  ·  alt: elit  ·  bekleme 0,46 sn -> sallanma 0,52 sn -> patlama")
    frames = []
    for s in range(n):
        ot = s / float(FPS)
        im = Image.new("RGBA", (W, H), (26, 24, 30, 255))
        im.alpha_composite(hd, (0, 0))
        d = ImageDraw.Draw(im)
        for i, did in enumerate(ORDER):
            label(d, i * cw + 8, top + 2, NAMES[did], 11)
            for ri, el in enumerate((False, True)):
                _, ch = frame_for(did, el, st_at(ot, ot))
                part = to_img(ch, did, kk)
                ox = i * cw + (cw - part.width) // 2
                oy = top + 18 + ri * chh + chh - (BY + 6) * kk
                ct = max(0, top + 18 + ri * chh - oy)
                if ct:
                    part = part.crop((0, ct, part.width, part.height))
                im.alpha_composite(part, (ox, oy + ct))
        frames.append(im)
    save_gif(frames, os.path.join(OUT, "sandik_odul.gif"), FPS)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    which = sys.argv[1:] or ["ozet", "oyun", "odul"]
    if "ozet" in which:
        build_ozet()
    if "oyun" in which:
        build_oyun()
    if "odul" in which:
        build_odul()
