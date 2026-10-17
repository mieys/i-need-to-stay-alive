# -*- coding: utf-8 -*-
"""SANDIK görünüşü PROTOTİPLERİ (2026-10-17, oyuna bağlı DEĞİL). Kullanıcı: "normal ve elit sandığın görünüşleri için mmorpg
oyunlarından esinlenerek yeni prototipler üret".

Bugün (gen_chest_sprites.py): 48x48 kare, 20 karelik şerit, düz önden kutu (~22x18 sanat px), normal = meşe + demir kayış +
pirinç kilit, elit = aynı silüet mor ahşap + altın. Dünyada 1 sanat px = 1 dünya px (sandık kökü ölçeksiz), ±2 px süzülme,
açılış 0-3 bekleme / 4-7 sallanma / 8 patlama / 9-15 ışın / 16-19 açık döngü. Elit normalden sadece RENGİYLE ayrılıyor.

Dört MMORPG yönü (hepsinde elit SİLÜETİYLE de büyür; 1 px koyu kontür, sıcak palet, tek odak vurgusu):
  A Kubbeli Hazine  (WoW / klasik MMO) - kubbe kapak, demir köşe başlıkları + perçinli kayışlar, pirinç asma kilit.
                    Elit: ceviz + altın kaplama, pençe ayaklar, yakut taşlı arma, kubbe sırtı altın.
  B Işık Sütunu     (Lost Ark / Diablo / PoE ganimet ışığı) - sade demir çerçeveli sandık + yerde dönen noktalı halka +
                    üstünden yükselen ışık sütunu: uzaktan bulunur. Elit: uzun mor sütun, halkada rünler, mor taşlı kilit.
                    Açılışta sütun parlar, sandığa çöker.
  C Zincirli Mühür  (Black Desert / Lost Ark mühürlü sandık) - normal: ip ile bağlı, kırmızı mum mühür + sallanan etiket;
                    açılışta ip kopar. Elit: kara demir, çapraz zincirler + önünde dönen mor büyü mührü; açılışta mühür
                    parçalanır, zincirler düşer.
  D Tombul Masal    (MapleStory / Ragnarok) - kapak gövdeden geniş tombul sandık, cilalı kırmızı, iri yuvarlak kilit;
                    süzülmek yerine ara ara ZIPLAR (bas-zıpla-yere bas). Elit: altın gövde + mavi kapak, yıldız taş,
                    çırpan küçük kanatlar. Açılışta kapak yaylanır, konfeti yıldızlar.

Normal sandığın ödül ekranındaki ışık rengi bugün eşyanın nadirliği (tier 1-4) - her yönde LIGHT parametresi aynı mantıkla
değişebilir; prototipte sıcak beyaz-altın gösterilir.

Çıktılar (out/sandik/):
  sandik_ozet.png  - 5 sütun (ŞU AN + A-D) x 4 satır (normal kapalı / açık, elit kapalı / açık), x3
  sandik_oyun.gif  - gerçek oyun ölçeği (kamera x2, gerçek harita çizimi + gerçek karakter), bekleme + dünyadaki kısa açılış
  sandik_odul.gif  - ödül ekranı gibi yakın (x3, karartılmış zemin), tam açılış dizisi
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

OUT = os.path.join(HERE, "out", "sandik", "v1")
CW, CH = 64, 96  # sandık tuvali (1 sanat px = 1 dünya px)
CX, BY = 32, 84  # gövde ortası, gövde altı (son satır BY-1)
ZOOM = 2
FPS = 20
CHAR_K = 2.2368375 * 0.8075 * 0.5  # Assasin dünya px / karakter pikseli


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def P(s):
    k = s.split()
    return dict(zip(("hi", "md", "dk", "dd"), [C(x) for x in k]))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


OUTL = C("#2a1a10")
INSIDE = C("#1c110a")
WHITE = C("#fffaf0")

OAK = P("#d69656 #b06e3a #854e28 #5e341b")
IRON = P("#c4ced6 #8c99a6 #5e6976 #3e4650")
BRASS = P("#ffe39a #eab748 #b07a22 #7d5212")
GOLD = P("#fff0a8 #f0be46 #b47e24 #7a5216")
WALNUT = P("#94603e #6e432c #4c2c1e #301c12")
RUBY = P("#ffd6cc #e8503a #ac2630 #561424")
STEEL_D = P("#8a94a2 #5c6574 #3c4350 #252a33")
SILVER = P("#f2f4f8 #c4cad6 #8a92a4 #585f70")
VIOLET = P("#f6d6ff #c77dff #8a3fd1 #54208c")
ROPE = P("#ecd49c #c9a464 #8e6e3a #5e4622")
WAX = P("#ffa090 #d8433a #8e2228 #5a1418")
PAPER = P("#fbf3dc #e6d6b0 #b8a27a #7e6a48")
LACQ = P("#ee7458 #c4452f #8c2b22 #5c1a16")
ROYAL = P("#9cc0ff #4f7fe0 #2f4fa4 #1c2c66")
WING = P("#ffffff #eaeef6 #b4bdd2 #7c86a0")
PINK = P("#ffe6f4 #ff9ad5 #d8569e #8a2a62")

LIGHT_N = C("#ffe39a")  # normal: sıcak altın-beyaz (oyunda nadirlik rengi)
LIGHTS = {
    ("A", False): LIGHT_N, ("A", True): C("#ffb84a"),
    ("B", False): LIGHT_N, ("B", True): C("#c77dff"),
    ("C", False): LIGHT_N, ("C", True): C("#c77dff"),
    ("D", False): LIGHT_N, ("D", True): C("#9cc0ff"),
}


# ------------------------------------------------------------------ tuval
class L:
    def __init__(self):
        self.a = np.zeros((CH, CW, 4), np.uint8)

    def px(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if c is not None and 0 <= x < CW and 0 <= y < CH:
            self.a[y, x] = c

    def get(self, x, y):
        if 0 <= x < CW and 0 <= y < CH:
            return tuple(int(v) for v in self.a[y, x])
        return (0, 0, 0, 0)

    def solid(self, x, y):
        return 0 <= x < CW and 0 <= y < CH and self.a[y, x, 3] > 0

    def rect(self, x0, y0, x1, y1, c):
        x0, y0 = max(0, int(x0)), max(0, int(y0))
        x1, y1 = min(CW - 1, int(x1)), min(CH - 1, int(y1))
        if x1 >= x0 and y1 >= y0:
            self.a[y0:y1 + 1, x0:x1 + 1] = c

    def hl(self, x0, x1, y, c):
        self.rect(x0, y, x1, y, c)

    def vl(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)

    def over(self, x, y, c):
        """Sadece dolu piksele boya (kayış/süs gövdenin dışına taşmasın)."""
        if self.solid(int(x), int(y)):
            self.px(x, y, c)

    def dpx(self, x, y, c, a):
        x, y = int(round(x)), int(round(y))
        if a > 0 and on(x & 1023, y & 1023, min(1.0, a)):
            self.px(x, y, c)

    def sprite(self, rows, x0, y0, pal, flip=False):
        for j, r in enumerate(rows):
            w = len(r)
            for i, ch in enumerate(r):
                if ch != ".":
                    self.px(x0 + (w - 1 - i if flip else i), y0 + j, pal[ch])


def outline(S, col=OUTL):
    m = S.a[:, :, 3] > 0
    d = np.zeros_like(m)
    d[1:, :] |= m[:-1, :]
    d[:-1, :] |= m[1:, :]
    d[:, 1:] |= m[:, :-1]
    d[:, :-1] |= m[:, 1:]
    e = d & ~m
    S.a[e] = col


def comp(*layers):
    """Katmanları sırayla üst üste, düz (straight) alfa (piksel opak ya da yarı saydam gölge)."""
    oc = np.zeros((CH, CW, 3), np.float32)
    oa = np.zeros((CH, CW, 1), np.float32)
    for l in layers:
        a = l.a.astype(np.float32)
        sa = a[:, :, 3:4] / 255.0
        na = sa + oa * (1 - sa)
        oc = np.where(na > 0, (a[:, :, :3] * sa + oc * oa * (1 - sa)) / np.maximum(na, 1e-6), 0)
        oa = na
    return np.concatenate([oc, oa * 255.0], axis=2).round().astype(np.uint8)


# ------------------------------------------------------------------ ortak parçalar
def wood(S, x0, y0, x1, y1, W, plank=4, seed=0, edge=True):
    S.rect(x0, y0, x1, y1, W["md"])
    y = y1 - plank
    while y > y0:
        S.hl(x0, x1, y, W["dk"])
        y -= plank
    rng = random.Random(seed)
    for _ in range(max(1, (x1 - x0) * (y1 - y0) // 26)):
        gx, gy = rng.randint(x0 + 1, x1 - 3), rng.randint(y0, y1 - 1)
        if S.get(gx, gy) == W["md"] and S.get(gx + 2, gy) == W["md"]:
            S.hl(gx, gx + rng.randint(1, 2), gy, W["dk"])
    if edge:
        S.hl(x0, x1, y1, W["dk"])
        S.vl(x1, y0, y1, W["dk"])


def vband(S, x, y0, y1, M, w=2, rivet=0, ry0=None):
    for y in range(y0, y1 + 1):
        cols = [M["hi"], M["dk"]] if w == 2 else [M["hi"], M["md"], M["dk"]] if w == 3 else [M["md"]]
        for i, c in enumerate(cols):
            S.over(x + i, y, c)
    if rivet:
        y = (ry0 if ry0 is not None else y0) + 1
        while y < y1:
            S.over(x + (w - 1) // 2, y, M["dd"])
            y += rivet


def plate(S, x0, y0, x1, y1, M):
    S.rect(x0, y0, x1, y1, M["md"])
    S.hl(x0, x1, y0, M["hi"])
    S.vl(x0, y0, y1, M["hi"])
    S.hl(x0 + 1, x1, y1, M["dk"])
    S.vl(x1, y0 + 1, y1, M["dk"])


def rows_shape(S, x0, y0, w, insets, fill_fn):
    """insets[j] = j. satırın iki yandan girintisi; fill_fn(x, y, j, xa, xb) renk döndürür."""
    for j, ins in enumerate(insets):
        xa, xb = x0 + ins, x0 + w - 1 - ins
        for x in range(xa, xb + 1):
            S.px(x, y0 + j, fill_fn(x, y0 + j, j, xa, xb))


def gem3(S, cx, cy, G, bright=0.0):
    S.px(cx, cy - 1, G["md"])
    S.px(cx - 1, cy, G["md"])
    S.px(cx + 1, cy, G["dk"])
    S.px(cx, cy + 1, G["dk"])
    S.px(cx, cy, WHITE if bright > 0.5 else G["hi"])


def keyhole(S, cx, cy, c):
    S.px(cx, cy, c)
    S.px(cx, cy + 1, c)


# ------------------------------------------------------------------ efekt yardımcıları
def sparkle(F, x, y, c, r):
    """Artı parıltı: r 0 = nokta, 1-2 = kollar."""
    F.px(x, y, WHITE)
    for k in range(1, r + 1):
        cc = WHITE if k == 1 and r == 2 else c
        for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            F.px(x + dx, y + dy, cc)


def seam_glow(F, x0, x1, y0, y1, light, k):
    """Aralanan kapağın arasından sızan ışık (satır y0..y1) + yanlara taşan çizgiler (k 0..1)."""
    for y in range(y0, y1 + 1):
        for x in range(x0 + 1, x1):
            F.px(x, y, WHITE if abs(x - (x0 + x1) / 2.0) < (x1 - x0) * 0.25 else light)
    n = int(2 + 7 * k)
    yc = (y0 + y1) // 2
    for i in range(1, n + 1):
        a = 1.0 - i / float(n + 1)
        F.dpx(x0 - i, yc, light, a)
        F.dpx(x1 + i, yc, light, a)


def rays(F, cx, cy, light, pt, n, reach, seed, spread=1.0):
    """Patlama ışınları: hızla uzar, söner (pt = patlamadan beri sn)."""
    if pt > 0.55:
        return
    g = min(1.0, pt / 0.10)
    fade = 1.0 if pt < 0.25 else max(0.0, 1.0 - (pt - 0.25) / 0.30)
    rng = random.Random(seed)
    for i in range(n):
        ang = -math.pi / 2 + (i - (n - 1) / 2.0) / max(1, n - 1) * 1.9 * spread + rng.uniform(-0.08, 0.08)
        ln = reach * (0.65 + 0.35 * rng.random()) * g
        for d in range(2, int(ln)):
            u = d / max(1.0, ln)
            x, y = cx + math.cos(ang) * d, cy + math.sin(ang) * d
            F.dpx(x, y, WHITE if u < 0.3 else light, (1.0 - u) * fade * 1.15)


def flash(F, cx, cy, rx, ry, light, pt):
    if pt > 0.12:
        return
    k = 1.0 - pt / 0.12
    for y in range(int(cy - ry - 3), int(cy + ry + 4)):
        for x in range(int(cx - rx - 4), int(cx + rx + 5)):
            d = ((x - cx) / (rx + 3.0)) ** 2 + ((y - cy) / (ry + 2.5)) ** 2
            if d < 0.45:
                F.px(x, y, WHITE)
            elif d < 1.0:
                F.dpx(x, y, light, k * (1.0 - d) * 2.2)


def coin(F, x, y, ph):
    x, y = int(round(x)), int(round(y))
    if ph % 2 == 0:
        F.px(x, y, GOLD["hi"])
        F.px(x + 1, y, GOLD["md"])
        F.px(x, y + 1, GOLD["md"])
        F.px(x + 1, y + 1, GOLD["dk"])
    else:
        F.px(x, y, GOLD["hi"])
        F.px(x, y + 1, GOLD["dk"])


def coins(F, cx, cy, pt, n, seed, ground, spread=42.0, pal_fn=None):
    if pt <= 0.0 or pt > 0.75:
        return
    rng = random.Random(seed)
    for i in range(n):
        vx = rng.uniform(-spread, spread)
        vy = -rng.uniform(70.0, 112.0)
        t = pt - rng.uniform(0.0, 0.06)
        if t <= 0:
            continue
        x = cx + vx * t
        y = cy + vy * t + 0.5 * 300.0 * t * t
        if y > ground:
            y = ground
        if t > 0.55 and not on(i, int(pt * 30) & 3, 1.0 - (t - 0.55) / 0.2):
            continue
        if pal_fn:
            pal_fn(F, x, y, i, int(pt * 18 + i))
        else:
            coin(F, x, y, int(pt * 18 + i))


def motes(F, cx, cy, w, h, T, light, n, seed, speed=10.0):
    rng = random.Random(seed)
    for i in range(n):
        ph = rng.random()
        u = (T * speed / h + ph) % 1.0
        x = cx + rng.uniform(-w / 2.0, w / 2.0) + math.sin(T * 2.0 + i) * 0.8
        y = cy - u * h
        if u < 0.85:
            F.px(x, y, WHITE if u < 0.3 else light)


def inner_glow(F, x0, x1, ytop, light, T, h=5):
    for y in range(ytop - h, ytop + 1):
        a = (1.0 - (ytop - y) / float(h + 1)) * (0.75 + 0.25 * math.sin(T * 6.0))
        for x in range(x0 + 1, x1):
            edge = min(x - x0, x1 - x) / 3.0
            F.dpx(x, y, light, a * min(1.0, edge))


def heap(S, x0, x1, y, mound=1, gems=None, seed=3):
    """Açık sandığın ağzında altın yığını (y = ağız alt satırı); kenarlarda karanlık iç görünür."""
    rng = random.Random(seed)
    x0, x1 = x0 + 2, x1 - 2
    for x in range(x0 + 1, x1):
        u = (x - x0) / float(x1 - x0)
        hgt = int(round((mound + 0.6) * math.sin(u * math.pi)))
        for k in range(hgt + 1):
            c = GOLD["md"] if (x + k) % 3 else GOLD["hi"]
            if k == hgt:
                c = GOLD["hi"] if rng.random() < 0.5 else GOLD["md"]
            S.px(x, y - k, c)
        S.px(x, y + 1, GOLD["dk"])
    for g in gems or []:
        gx, G = g
        S.px(x0 + gx, y - mound, G["md"])
        S.px(x0 + gx, y - mound - 1, G["hi"])


def mouth(S, x0, x1, bt, W, rim=None, ot=4):
    """Açık sandığın ağzı: arka kenar (açık renk) + karanlık iç; döner: ağzın üst satırı."""
    oy = bt - ot
    S.rect(x0, oy, x1, bt - 1, W["dk"])
    S.hl(x0, x1, oy, rim or W["hi"])
    S.rect(x0 + 1, oy + 1, x1 - 1, bt - 1, INSIDE)
    return oy


def open_lid(S, x0, w, ly1, oh, W, insets=None, edge=None):
    """Arkada dikilen kapağın İÇ yüzü: koyu, açık renk üst kenar (kapağın ağzı) + seyrek tahta çizgisi."""
    ins = insets or [0] * oh
    for j in range(oh):
        xa, xb = x0 + ins[j], x0 + w - 1 - ins[j]
        y = ly1 - oh + 1 + j
        for x in range(xa, xb + 1):
            c = W["dd"]
            if j == 0 or x in (xa, xb):
                c = edge or W["dk"]
            elif (ly1 - y) % 3 == 1:
                c = W["dk"]
            S.px(x, y, c)
    return ly1 - oh + 1


def shadow(Sh, cx, y, w, k=1.0):
    rx, ry = w / 2.0 * k, 2.6 * k
    for yy in range(int(y - 4), int(y + 5)):
        for xx in range(int(cx - rx - 1), int(cx + rx + 2)):
            if ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - y) / ry) ** 2 <= 1.0:
                Sh.px(xx, yy, (16, 22, 14, 92))


# ------------------------------------------------------------------ durum (zaman çizelgesi)
class St:
    """ph: idle | shake | open; pt: evredeki sn (ödül ekranı ölçeği); T: genel saat; step: sallanma adımı 0-3."""

    def __init__(self, ph, pt=0.0, T=0.0, world=False):
        self.ph, self.pt, self.T, self.world = ph, pt, T, world
        self.step = min(3, int(pt / 0.13)) if ph == "shake" else 0

    @property
    def k(self):  # sallanma ilerleyişi
        return (self.step + 1) / 4.0 if self.ph == "shake" else 0.0

    def lift(self):
        return 0 if self.ph != "shake" else (1 if self.step % 2 == 0 else 2) if self.step >= 1 else 1

    def dx(self):
        return 0 if self.ph != "shake" else (-1, 1, -1, 1)[self.step]


def bob(st):
    return int(round(math.sin(st.T * 4.0) * 2.0)) if st.ph == "idle" else 0


# ------------------------------------------------------------------ A  Kubbeli Hazine
def draw_A(Lb, S, F, elite, st):
    light = LIGHTS[("A", elite)]
    W, M, K = (WALNUT, GOLD, GOLD) if elite else (OAK, IRON, BRASS)
    w = 29 if elite else 23
    bh = 11 if elite else 9
    dh = 11 if elite else 9
    feet = 2 if elite else 0
    cx = CX + st.dx()
    by = BY - feet + bob(st)
    x0, x1 = cx - w // 2, cx + w // 2
    bt = by - bh
    seed = 11 if elite else 5
    # gövde
    wood(S, x0, bt, x1, by - 1, W, plank=4, seed=seed)
    ins = [5, 3, 2, 1, 1, 0, 0, 0, 0, 0, 0][:dh] if elite else [4, 2, 1, 1, 0, 0, 0, 0, 0]

    def dome_fill(W):
        def f(x, y, j, xa, xb):
            if j <= 1:
                c = W["hi"]
            elif j <= 3:
                c = W["hi"] if (x + j) % 3 == 0 else W["md"]
            elif j >= dh - 2:
                c = W["dk"]
            else:
                c = W["md"]
            if x == xb and j > 0:
                c = W["dk"]
            return c
        return f

    if st.ph == "open":
        # ağız + arkada dikilen kapak (iç yüzü)
        oy = mouth(S, x0, x1, bt, W)
        ly1 = oy - 1 + (-2 if st.pt < 0.06 else -1 if st.pt < 0.12 else 0)
        oh = dh - 1
        iins = ins[1:] if len(ins) > oh else ins
        open_lid(S, x0, w, ly1, oh, W, iins[:oh], edge=M["md"] if elite else None)
        for bx in ((x0 + 4, x1 - 5) if not elite else (x0 + 5, x1 - 6)):
            vband(S, bx, ly1 - oh + 2, ly1, dict(hi=M["dk"], md=M["dk"], dk=M["dd"], dd=M["dd"]), 2)
        heap(S, x0 + 1, x1 - 1, bt - 1, mound=2 if elite else 1,
             gems=[(6, RUBY), (w - 9, RUBY), (w // 2 - 1, RUBY)] if elite else None)
        mouth_y = bt - 2
    else:
        lift = st.lift()
        ly0 = bt - dh - lift
        rows_shape(S, x0, ly0, w, ins, dome_fill(W))
        S.hl(x0, x1, bt - 1 - lift, OUTL)  # kapak alt kenarı / ek yeri
        bands = (x0 + 4, x1 - 5) if not elite else (x0 + 5, x1 - 6)
        for bx in bands:
            vband(S, bx, ly0, bt - 2 - lift, M, 2, rivet=3)
        if elite:
            for x in range(x0, x1 + 1):  # kubbe sırtı + alt kenar altın
                S.over(x, ly0, M["hi"])
            S.hl(x0, x1, bt - 2 - lift, M["md"])
            S.hl(x0 + 1, x1, bt - 2 - lift, M["md"])
            S.px(x1, bt - 2 - lift, M["dk"])
        if lift:
            seam_glow(F, x0, x1, bt - lift, bt - 1, light, st.k)
        mouth_y = bt - 1
    # gövde kayışları + köşe başlıkları
    bands = (x0 + 4, x1 - 5) if not elite else (x0 + 5, x1 - 6)
    for bx in bands:
        vband(S, bx, bt, by - 2, M, 2, rivet=3)
    if elite:
        S.hl(x0, x1, bt, M["hi"])
        for sx, d in ((x0, 1), (x1, -1)):  # üçgen köşe kaplaması
            for j in range(4):
                for i in range(4 - j):
                    S.px(sx + d * i, by - 1 - j, M["md"] if i + j < 3 else M["dk"])
            S.px(sx, by - 1, M["hi"])
            for i in range(3):  # pençe ayaklar
                S.px(sx + d * i, by, M["dk"] if i == 1 else M["md"])
                if i != 1:
                    S.px(sx + d * i, by + 1, M["dk"])
    else:
        for sx, d in ((x0, 1), (x1, -1)):
            for j in range(3):
                S.px(sx, by - 1 - j, M["md"])
                S.px(sx + d * j, by - 1, M["md"])
            S.px(sx, by - 1, M["hi"])
            S.px(sx + d, by - 2, M["dk"])
    # kilit / arma
    if elite:
        sh = ["#######", "#######", "#######", "#######", ".#####.", ".#####.", "..###..", "...#..."]
        ax0, ay0 = cx - 3, (bt - 1 if st.ph == "open" else bt - 4 - (st.lift() if st.ph == "shake" else 0))
        for j, r in enumerate(sh):
            for i, ch in enumerate(r):
                if ch == "#":
                    c = K["md"]
                    if j == 0 or i == 0 or (i == 1 and j > 3):
                        c = K["hi"]
                    if i == len(r) - 1 or r[min(i + 1, 6)] == "." or j == len(sh) - 1:
                        c = K["dk"]
                    S.px(ax0 + i, ay0 + j, c)
        pulse = 0.5 + 0.5 * math.sin(st.T * 5.0)
        gem3(S, cx, ay0 + 3, RUBY, pulse)
        if st.ph == "idle":
            pts = [(x0 + 2, bt + 2), (x1 - 3, bt - 6), (cx + 6, by - 3), (x0 + 6, bt - 8), (cx - 1, ay0 + 1)]
            i = int(st.T / 0.55) % len(pts)
            r = (0, 1, 2, 1, 0)[int((st.T % 0.55) / 0.11) % 5]
            sparkle(F, pts[i][0], pts[i][1], light, r)
    else:
        lx0, ly = cx - 2, bt - 3 - (st.lift() if st.ph == "shake" else 0)
        if st.ph == "open":
            ly = bt - 1
            plate(S, lx0, ly, lx0 + 4, ly + 3, K)
            keyhole(S, cx, ly + 1, K["dd"])
        else:
            plate(S, lx0, ly, lx0 + 4, ly + 5, K)
            keyhole(S, cx, ly + 2, K["dd"])
            S.px(cx, ly + 4, K["dk"])
            if st.ph == "idle":  # kilitte gezen parıltı
                g = (st.T % 2.4) - 2.0
                if 0 <= g < 0.4:
                    gx = lx0 - 1 + int(g / 0.4 * 7)
                    for d in range(-1, 2):
                        S.over(gx + d, ly + 1 + d, WHITE)
    return dict(cx=cx, mouth=(cx, mouth_y), w=w, x0=x0, x1=x1, by=by + feet, light=light)


# ------------------------------------------------------------------ B  Işık Sütunu
def pillar(Lb, cx, base, h, wcore, wside, light, core, T, k_boost=0.0, shrink=1.0):
    h = int(h)
    for y in range(base - h, base + 1):
        u = (base - y) / float(max(1, h))
        a = (1.0 - u) ** 1.2 * (0.85 + 0.15 * math.sin(T * 5.0 + y * 0.35)) + k_boost
        hw = (wcore + wside) * shrink
        for x in range(int(cx - hw - 1), int(cx + hw + 2)):
            dxx = abs(x - cx)
            if dxx <= wcore * shrink:
                Lb.dpx(x, y, core if u < 0.55 else light, a * 1.4)
            elif dxx <= hw:
                Lb.dpx(x, y, light, a * (1.0 - (dxx - wcore) / max(1.0, wside)) * 0.9)


def ground_ring(Lb, F, cx, cy, rx, ry, light, T, n=28, runes=0, rune_col=None, scale=1.0, alpha=1.0):
    rx, ry = rx * scale, ry * scale
    m = int(n * 2.2)
    for i in range(m):
        a = i / float(m) * math.tau
        x, y = cx + math.cos(a) * rx, cy + math.sin(a) * ry
        seg = ((a - T * 0.9) % math.tau) / math.tau * 3.0  # 3 dönen parlak yay
        bright = (seg % 1.0) < 0.28
        if (alpha >= 1.0 or on(i, 0, alpha)) and (bright or i % 2 == 0):
            (F if math.sin(a) > 0 else Lb).px(x, y, WHITE if bright else light)
    for r in range(runes):
        a = r / float(runes) * math.tau - T * 0.6
        x, y = int(round(cx + math.cos(a) * rx)), int(round(cy + math.sin(a) * ry))
        L_ = F if math.sin(a) > 0 else Lb
        glyph = [(0, -1), (0, 0), (0, 1), (-1, 0) if r % 2 else (1, 0), (1, -1) if r % 3 == 0 else (-1, 1)]
        for gx, gy in glyph:
            L_.px(x + gx, y + gy, rune_col if alpha >= 1.0 or on(r, gy & 3, alpha) else None)


def draw_B(Lb, S, F, elite, st):
    light = LIGHTS[("B", elite)]
    core = C("#f6e8ff") if elite else C("#fffaf0")
    W = WALNUT if elite else OAK
    M = STEEL_D if elite else IRON
    w = 25 if elite else 21
    bh = 10 if elite else 8
    lf, lt = (5, 3) if elite else (4, 3)
    cx = CX + st.dx()
    by = BY
    x0, x1 = cx - w // 2, cx + w // 2
    bt = by - bh
    gcy = by - 1
    # zemin halkası + sütun
    T = st.T
    if st.ph == "idle":
        ground_ring(Lb, F, cx, gcy, 17 if elite else 14, 6 if elite else 5, light, T, n=34 if elite else 28,
                    runes=6 if elite else 0, rune_col=VIOLET["hi"])
        pillar(Lb, cx, bt - 2, 58 if elite else 38, 2 if elite else 1.5, 5 if elite else 4, light, core, T)
        motes(Lb, cx, bt - 4, 6, 50 if elite else 30, T, light, 5 if elite else 3, 7)
    elif st.ph == "shake":
        ground_ring(Lb, F, cx, gcy, 17 if elite else 14, 6 if elite else 5, light, T * 3.0, n=34 if elite else 28,
                    runes=6 if elite else 0, rune_col=VIOLET["hi"])
        pillar(Lb, cx, bt - 2, (58 if elite else 38) + 6 * st.k, (2 if elite else 1.5) + st.k, (5 if elite else 4) + 2 * st.k,
               light, core, T, k_boost=0.15 * st.k)
    else:
        pt = st.pt
        if pt < 0.45:  # sütun çöker, halka dışa açılıp söner
            sh = max(0.0, 1.0 - pt / 0.30)
            pillar(Lb, cx, bt - 2, (64 if elite else 44) * (1.0 - pt / 0.45), 3, 6, light, core, T, k_boost=0.3, shrink=sh + 0.15)
            ground_ring(Lb, F, cx, gcy, 17 if elite else 14, 6 if elite else 5, light, T, n=40,
                        runes=6 if elite else 0, rune_col=VIOLET["hi"], scale=1.0 + pt * 1.3, alpha=1.0 - pt / 0.45)
    # sandık: demir çerçeveli düz kutu
    wood(S, x0, bt, x1, by - 1, W, plank=3, seed=21 if elite else 9)
    S.rect(x0, bt, x0 + 1, by - 1, M["md"])
    S.vl(x0, bt, by - 1, M["hi"])
    S.rect(x1 - 1, bt, x1, by - 1, M["dk"])
    S.hl(x0, x1, by - 1, M["dk"])
    S.hl(x0, x1, bt, M["hi"])
    if st.ph == "open":
        oy = mouth(S, x0, x1, bt, M, rim=M["md"])
        ly1 = oy - 1 + (-2 if st.pt < 0.06 else 0)
        ly0 = open_lid(S, x0, w, ly1, lf + lt, W, edge=M["dk"])
        S.rect(x0, ly0, x0 + 1, ly1, M["dk"])
        S.rect(x1 - 1, ly0, x1, ly1, M["dd"])
        S.hl(x0, x1, ly0, M["md"])
        for y in range(oy + 1, bt):  # ışığın kaynağı: ağız parlak
            for x in range(x0 + 2, x1 - 1):
                S.px(x, y, WHITE if (y == bt - 1 and abs(x - cx) < w // 4) else light if y >= bt - 2 else mix(light, INSIDE, 0.5))
        if elite:
            for x in range(x0 + 2, x1 - 1, 3):
                S.px(x, bt - 2, VIOLET["md"] if x % 2 else VIOLET["hi"])
        mouth_y = bt - 2
        inner_glow(F, x0 + 1, x1 - 1, bt - 2, light, T, h=4)
    else:
        lift = st.lift()
        ft = bt - lift - lf
        tt = ft - lt
        S.rect(x0, tt, x1, ft - 1, W["hi"])
        S.hl(x0, x1, ft - 1, mix(W["hi"], W["md"], 0.5))
        wood(S, x0, ft, x1, bt - 1 - lift, W, plank=9, seed=3, edge=False)
        S.hl(x0, x1, bt - 1 - lift, OUTL)
        S.rect(x0, tt, x0 + 1, bt - 2 - lift, M["md"])
        S.vl(x0, tt, bt - 2 - lift, M["hi"])
        S.rect(x1 - 1, tt, x1, bt - 2 - lift, M["dk"])
        S.hl(x0, x1, tt, M["hi"])
        S.hl(x0, x1, ft, M["md"])
        if elite:  # gümüş perçinler
            for x in (x0 + 4, x1 - 4):
                for y in (ft + 2, bt + 3, by - 3):
                    S.px(x, y, SILVER["hi"])
                    S.px(x + 1, y + 1, SILVER["dk"])
        if lift:
            seam_glow(F, x0, x1, bt - lift, bt - 1, light, st.k)
        mouth_y = bt - 1
        # kilit
        if elite:
            plate(S, cx - 2, bt - 3 - lift, cx + 2, bt + 2, SILVER)
            gem3(S, cx, bt - 1 - lift, VIOLET, 0.5 + 0.5 * math.sin(T * 5.0))
        else:
            S.px(cx - 1, bt - 2 - lift, M["dk"])
            S.px(cx + 1, bt - 2 - lift, M["dk"])
            S.px(cx, bt - 3 - lift, M["md"])
            plate(S, cx - 2, bt - 1, cx + 2, bt + 2, BRASS)
            keyhole(S, cx, bt, BRASS["dd"])
    return dict(cx=cx, mouth=(cx, mouth_y), w=w, x0=x0, x1=x1, by=by, light=light)


# ------------------------------------------------------------------ C  Zincirli Mühür
def rope_px(S, x, y, i, R):
    S.px(x, y, R["hi"] if i % 2 == 0 else R["md"])


def chain(S, p0, p1, M, phase=0):
    n = int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1])))
    for i in range(0, n + 1):
        u = i / float(max(1, n))
        x = p0[0] + (p1[0] - p0[0]) * u
        y = p0[1] + (p1[1] - p0[1]) * u
        if (i + phase) % 3 == 0:
            S.px(x, y, M["hi"])
            S.px(x + 1, y, M["md"])
            S.px(x, y + 1, M["md"])
            S.px(x + 1, y + 1, M["dd"])
        elif (i + phase) % 3 == 1:
            S.px(x, y, M["dk"])


def seal_circle(F, cx, cy, r, T, col, hi, crack=0.0, burst=-1.0):
    """Önde dönen büyü mührü: halka + 4 dönen rün çentiği + ortada yıldız. burst >= 0: halka parçaları dışa uçar."""
    n = int(r * 6.4)
    for i in range(n):
        a = i / float(n) * math.tau
        seg = int(i / float(n) * 6)
        if burst >= 0:
            d = burst * 70.0
            am = (seg + 0.5) / 6.0 * math.tau
            x = cx + math.cos(a) * r + math.cos(am) * d
            y = cy + math.sin(a) * r + math.sin(am) * d + 120 * burst * burst
            if on(i, seg, 1.0 - burst / 0.35):
                F.px(x, y, hi if i % 3 == 0 else col)
            continue
        if crack > 0 and i % max(2, int(8 - crack * 6)) == 0 and seg % 2 == 0:
            continue
        F.px(cx + math.cos(a) * r, cy + math.sin(a) * r, col)
    if burst >= 0:
        return
    for k in range(4):
        a = k / 4.0 * math.tau + T * 1.6
        for rr in (r - 2, r - 1):
            F.px(cx + math.cos(a) * rr, cy + math.sin(a) * rr, hi)
    for k in range(4):
        a = k / 4.0 * math.tau - T * 1.1 + math.pi / 4
        F.px(cx + math.cos(a) * (r + 2), cy + math.sin(a) * (r + 2), col if (int(T * 8) + k) % 2 else hi)
    pulse = 0.5 + 0.5 * math.sin(T * 4.0)
    F.px(cx, cy, WHITE)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        F.px(cx + dx, cy + dy, hi if pulse > 0.4 else col)
    if pulse > 0.7:
        for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
            F.px(cx + dx, cy + dy, col)


def draw_C(Lb, S, F, elite, st):
    light = LIGHTS[("C", elite)]
    W = STEEL_D if elite else OAK
    WB = WALNUT if elite else OAK
    w = 27 if elite else 23
    bh = 11 if elite else 9
    lf, lt = (5, 4) if elite else (4, 4)
    cx = CX + st.dx()
    by = BY + bob(st)
    x0, x1 = cx - w // 2, cx + w // 2
    bt = by - bh
    T = st.T
    # gövde
    wood(S, x0, bt, x1, by - 1, WB, plank=4, seed=31 if elite else 13)
    if elite:  # kara demir kaplama: kenar + köşe
        S.rect(x0, bt, x0 + 1, by - 1, W["md"])
        S.vl(x0, bt, by - 1, W["hi"])
        S.rect(x1 - 1, bt, x1, by - 1, W["dk"])
        S.hl(x0, x1, by - 1, W["dd"])
        S.hl(x0, x1, by - 2, W["dk"])
        S.hl(x0, x1, bt, W["hi"])
    if st.ph == "open":
        oy = mouth(S, x0, x1, bt, WB)
        ly1 = oy - 1 + (-2 if st.pt < 0.06 else 0)
        ly0 = open_lid(S, x0, w, ly1, lf + lt, WB, edge=W["md"] if elite else None)
        if elite:
            S.rect(x0, ly0, x0 + 1, ly1, W["dk"])
            S.rect(x1 - 1, ly0, x1, ly1, W["dd"])
            S.hl(x0, x1, ly0, W["md"])
            for x, y in ((cx - 4, bt - 2), (cx + 3, bt - 2), (cx, bt - 3)):  # ışıyan kristaller
                S.px(x, y, VIOLET["hi"])
                S.px(x, y + 1, VIOLET["md"])
                S.px(x + 1, y + 1, VIOLET["dk"])
        else:
            heap(S, x0 + 1, x1 - 1, bt - 1, mound=1)
        mouth_y = bt - 2
        pt = st.pt
        if pt < 0.6:  # kopan ip / düşen zincir parçaları
            rng = random.Random(41)
            for i in range(10 if elite else 6):
                vx = rng.uniform(-50, 50)
                vy = rng.uniform(-60, -20)
                x = cx + rng.uniform(-w / 2.5, w / 2.5) + vx * pt
                y = bt + rng.uniform(-6, 6) + vy * pt + 0.5 * 320 * pt * pt
                if y < by + 2 and on(i, 1, 1.0 - pt / 0.6):
                    if elite:
                        S.px(x, y, SILVER["md"])
                        S.px(x + 1, y, SILVER["dk"])
                        S.px(x, y + 1, SILVER["dk"])
                    else:
                        for d in range(3):
                            S.px(x + d * (1 if vx > 0 else -1), y + (d // 2), ROPE["md"] if d % 2 else ROPE["hi"])
            if not elite:  # kırılan mum mühür iki yarısı
                for s in (-1, 1):
                    x = cx + s * (2 + 30 * pt)
                    y = bt + 1 + -30 * pt + 0.5 * 320 * pt * pt
                    if y < by + 2:
                        S.px(x, y, WAX["md"])
                        S.px(x + s, y, WAX["dk"])
                        S.px(x, y + 1, WAX["dk"])
            else:
                seal_circle(F, cx, bt - 1, 7, T, VIOLET["md"], VIOLET["hi"], burst=pt)
    else:
        lift = st.lift()
        ft = bt - lift - lf
        tt = ft - lt
        S.rect(x0, tt, x1, ft - 1, WB["hi"])
        S.hl(x0, x1, ft - 1, mix(WB["hi"], WB["md"], 0.5))
        wood(S, x0, ft, x1, bt - 1 - lift, WB, plank=9, seed=4, edge=False)
        S.hl(x0, x1, bt - 1 - lift, OUTL)
        if elite:
            S.rect(x0, tt, x0 + 1, bt - 2 - lift, W["md"])
            S.vl(x0, tt, bt - 2 - lift, W["hi"])
            S.rect(x1 - 1, tt, x1, bt - 2 - lift, W["dk"])
            S.hl(x0, x1, tt, W["hi"])
            S.hl(x0, x1, ft, W["md"])
            S.hl(x0, x1, bt - 2 - lift, W["dk"])
            # kilit plakası
            plate(S, cx - 3, bt - 3 - lift, cx + 3, bt + 2, W)
            # çapraz zincirler (gerilir: sallanmada titrer)
            jit = st.step % 2 if st.ph == "shake" else 0
            CHN = dict(hi=STEEL_D["hi"], md=STEEL_D["md"], dk=STEEL_D["dd"], dd=OUTL)
            chain(S, (x0 + 1, tt + 1), (x1 - 2, by - 3), CHN, phase=jit)
            chain(S, (x1 - 2, tt + 1), (x0 + 1, by - 3), CHN, phase=1 - jit)
            sy = bt - 1 - lift + (int(round(math.sin(T * 2.5))) if st.ph == "idle" else 0)
            crack = st.k if st.ph == "shake" else 0.0
            seal_circle(F, cx, sy, 7, T * (1.0 + 2.0 * crack), VIOLET["md"], VIOLET["hi"], crack=crack)
            if st.ph == "idle":
                motes(F, cx, sy - 2, 12, 14, T, VIOLET["md"], 3, 5, speed=7.0)
        else:
            # ip: yatay (gövde ortası) + dikey (kapak üstünden), düğüm + mum mühür + etiket
            ry = by - 5
            jit = st.step % 2 if st.ph == "shake" else 0
            for x in range(x0, x1 + 1):
                rope_px(S, x, ry, x + jit, ROPE)
                rope_px(S, x, ry + 1, x + 1 + jit, ROPE)
            for y in range(tt, by):
                rope_px(S, cx - 1, y, y + jit, ROPE)
                rope_px(S, cx, y, y + 1 + jit, ROPE)
            S.vl(cx + 1, ft, by - 1, ROPE["dk"])
            # mum mühür (ek yerinde)
            sy0 = bt - 3 - lift
            rows_shape(S, cx - 2, sy0, 5, [1, 0, 0, 0, 1],
                       lambda x, y, j, xa, xb: WAX["hi"] if (j == 1 and x == xa + 1) else WAX["dk"] if (j == 4 or x == xb) else WAX["md"])
            S.px(cx, sy0 + 2, WAX["dk"])
            # etiket (ipe bağlı, sallanır)
            sw = int(round(math.sin(T * 2.2) * 1.2)) if st.ph == "idle" else st.dx()
            tx = x1 - 6
            S.px(tx, ry + 2, ROPE["dk"])
            tag = ["#####", "#.###", "#####", "#####", ".###."]
            for j, r in enumerate(tag):
                for i, ch in enumerate(r):
                    if ch == "#":
                        S.px(tx - 2 + i + (sw if j > 1 else 0), ry + 3 + j,
                             PAPER["dk"] if i == 4 or j == 4 else PAPER["hi"] if j == 0 else PAPER["md"])
                    elif j == 1:
                        S.px(tx - 2 + i, ry + 3 + j, PAPER["dd"])
        if lift:
            seam_glow(F, x0, x1, bt - lift, bt - 1, light, st.k)
        mouth_y = bt - 1
    return dict(cx=cx, mouth=(cx, mouth_y), w=w, x0=x0, x1=x1, by=by, light=light)


# ------------------------------------------------------------------ D  Tombul Masal
WING_UP = ["....hh..", "..hhhhh.", ".hhhhhhm", "hhhmhhmm", ".hmmhmmm", "..mm.mmm", "......mm"]
WING_DN = ["......mm", "..hhhhmm", ".hhhhhhm", "hhhmhhmm", "hhmmhmm.", ".mm.mm..", "........"]
STAR5 = ["..#..", ".###.", "#####", ".###.", ".#.#."]


def hop(T):
    """(yükseklik px, en farkı, boy farkı, havada mı) - 1,8 sn'lik döngüde bir zıplama."""
    t = T % 1.8
    if 1.10 <= t < 1.22:
        return 0, 2, -2, False
    if 1.22 <= t < 1.62:
        u = (t - 1.22) / 0.40
        return int(round(6.0 * math.sin(math.pi * u))), -1 if u < 0.5 else 0, 1 if u < 0.5 else 0, True
    if 1.62 <= t < 1.72:
        return 0, 2, -1, False
    return 0, 0, 0, False


def draw_D(Lb, S, F, elite, st):
    light = LIGHTS[("D", elite)]
    BODY = GOLD if elite else LACQ
    LID = ROYAL if elite else LACQ
    RIM = GOLD
    w0 = 25 if elite else 23
    hgt, sx, sy, air = hop(st.T) if st.ph == "idle" else (0, 0, 0, False)
    w = w0 + sx
    if w % 2 == 0:
        w += 1
    bh = (10 if elite else 9) + (sy if sy < 0 else 0)
    dh = (11 if elite else 10) + (sy if sy > 0 else 0)
    cx = CX + st.dx()
    by = BY - hgt
    x0, x1 = cx - w // 2, cx + w // 2
    bt = by - bh
    T = st.T
    # gövde: alt köşeleri yuvarlak
    for y in range(bt, by):
        ins = 1 if y == by - 1 else 0
        for x in range(x0 + ins, x1 - ins + 1):
            c = BODY["md"]
            if x == x1 - ins or y == by - 1:
                c = BODY["dk"]
            elif x == x0 + ins:
                c = BODY["hi"]
            S.px(x, y, c)
    if elite:  # mavi dikey kayışlar (kenarlara yakın)
        for px0 in (x0 + 3, x1 - 5):
            S.rect(px0, bt + 2, px0 + 2, by - 2, ROYAL["md"])
            S.vl(px0, bt + 2, by - 2, ROYAL["hi"])
            S.vl(px0 + 2, bt + 2, by - 2, ROYAL["dk"])
    else:
        for y in range(bt + 3, by - 1, 3):
            S.hl(x0 + 2, x1 - 2, y, BODY["dk"])
    S.hl(x0, x1, bt, RIM["hi"])
    S.hl(x0, x1, bt + 1, RIM["dk"])
    lw = w + 2
    lx0 = x0 - 1
    ins_c = [6, 4, 3, 2, 1, 1, 0, 0, 0, 0, 0, 0][:dh]

    def lid_fill(x, y, j, xa, xb):
        if j >= dh - 2:
            return RIM["md"] if j == dh - 2 else RIM["dk"]
        c = LID["md"]
        if j <= 1:
            c = LID["hi"]
        elif x == xb or j == dh - 3:
            c = LID["dk"]
        elif x == xa:
            c = LID["hi"]
        return c

    if st.ph == "open":
        oy = mouth(S, x0, x1, bt, BODY)
        boing = (-4, -1, 1, 0)[min(3, int(st.pt / 0.05))]
        ly1 = oy - 1 + boing
        oh = dh - 1
        open_lid(S, lx0, lw, ly1, oh, LID, ins_c[:oh], edge=RIM["dk"])
        heap(S, x0 + 1, x1 - 1, bt - 1, mound=2, gems=[(5, PINK), (w - 8, ROYAL)] if elite else [(w // 2, RUBY)])
        mouth_y = bt - 2
        wy = oy - 3
    else:
        lift = st.lift()
        ly0 = bt - dh - lift
        rows_shape(S, lx0, ly0, lw, ins_c, lid_fill)
        S.hl(lx0 + 1, lx0 + lw - 2, bt - 1 - lift, OUTL)
        # cila parıltısı
        S.px(lx0 + 5, ly0 + 2, WHITE)
        S.px(lx0 + 6, ly0 + 2, WHITE)
        S.px(lx0 + 4, ly0 + 3, mix(LID["hi"], WHITE, 0.6))
        if elite:
            pal = {"#": PINK["md"]}
            S.sprite(STAR5, cx - 2, ly0 - 2, pal)
            S.px(cx, ly0 - 1, PINK["hi"])
            S.px(cx - 1, ly0, WHITE)
            if int(T / 0.12) % 9 == 0:
                sparkle(F, cx + 2, ly0 - 3, PINK["hi"], 1)
        # iri yuvarlak kilit
        ky = bt - 4 - lift
        rows_shape(S, cx - 3, ky, 7, [2, 1, 0, 0, 0, 1, 2],
                   lambda x, y, j, xa, xb: GOLD["hi"] if (j <= 1 or x == xa) else GOLD["dk"] if (j >= 5 or x == xb) else GOLD["md"])
        S.px(cx, ky + 2, GOLD["dd"])
        S.px(cx, ky + 3, GOLD["dd"])
        S.px(cx, ky + 4, GOLD["dd"])
        S.px(cx - 1, ky + 2, GOLD["dk"])
        if lift:
            seam_glow(F, x0, x1, bt - lift, bt - 1, light, st.k)
        mouth_y = bt - 1
        wy = ly0 + 3
    if elite:  # kanatlar
        flap = (int(T / 0.08) % 2 == 0) if air else (int(T / 0.45) % 2 == 0)
        if st.ph != "idle":
            flap = int(T / 0.06) % 2 == 0
        rows = WING_UP if flap else WING_DN
        pal = {"h": WING["hi"], "m": WING["dk"], "d": WING["dd"]}
        S.sprite(rows, lx0 - 7, wy + 4, pal)
        S.sprite(rows, lx0 + lw - 1, wy + 4, pal, flip=True)
    return dict(cx=cx, mouth=(cx, mouth_y), w=w0, x0=x0, x1=x1, by=BY, light=light, hgt=hgt)


def confetti(F, cx, cy, pt, seed, elite):
    if pt <= 0 or pt > 0.8:
        return
    rng = random.Random(seed)
    cols = [PINK["md"], ROYAL["hi"], GOLD["hi"], WHITE] if elite else [LACQ["hi"], GOLD["hi"], WHITE, C("#8fd16a")]
    for i in range(12 if elite else 9):
        vx = rng.uniform(-55, 55)
        vy = -rng.uniform(70, 120)
        x = cx + vx * pt
        y = cy + vy * pt + 0.5 * 200 * pt * pt
        c = cols[i % len(cols)]
        if pt > 0.55 and not on(i, 2, 1.0 - (pt - 0.55) / 0.25):
            continue
        if i % 3 == 0:
            sparkle(F, x, y, c, 1)
        else:
            F.px(x, y, c)
            if int(pt * 20 + i) % 2:
                F.px(x + 1, y, c)


# ------------------------------------------------------------------ çizim girişi
DRAW = {"A": draw_A, "B": draw_B, "C": draw_C, "D": draw_D}


def render(did, elite, st):
    """Sandık tuvali (64x96 RGBA numpy): gölge katmanı ayrı döner (zemine yarı saydam)."""
    Sh, Lb, S, F = L(), L(), L(), L()
    g = DRAW[did](Lb, S, F, elite, st)
    outline(S)
    cx, mx, my = g["cx"], g["mouth"][0], g["mouth"][1]
    light = g["light"]
    k = 1.0
    if did == "D" and g.get("hgt"):
        k = max(0.6, 1.0 - g["hgt"] / 14.0)
    shadow(Sh, CX + st.dx(), BY + 1, g["w"] + 3, k)
    if st.ph == "open":
        pt = st.pt
        flash(F, mx, my, g["w"] / 2.0 - 2, 3, light, pt)
        rays(F, mx, my - 1, light, pt, 7 if elite else 5, 30 if elite else 22, 5 + elite)
        if did == "D":
            confetti(F, mx, my - 2, pt, 9, elite)
            coins(F, mx, my - 1, pt, 6, 13, BY + 2)
        elif did == "C" and elite:
            pass
        else:
            coins(F, mx, my - 1, pt, 11 if elite else 7, 3 + elite, BY + 2)
        if pt > 0.45:
            inner_glow(F, g["x0"] + 1, g["x1"] - 1, my, light, st.T, h=4)
            rng = random.Random(int(st.T * 3))
            if rng.random() < 0.5:
                tt = (st.T * 3) % 1.0
                sparkle(F, mx + rng.randint(-6, 6), my - 4 - int(tt * 8), light, (0, 1, 2, 1, 0)[int(tt * 5) % 5])
    return comp(Sh), comp(Lb, S, F)


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
    sh = cur_sheet(elite)
    im = sh.crop((frame * 48, 0, frame * 48 + 48, 48))
    out = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    out.alpha_composite(im, (CX - 24, BY - 42 + dy))
    shadow_l = L()
    shadow(shadow_l, CX, BY + 1, 25)
    return comp(shadow_l), np.asarray(out)


def cur_idle_frame(elite, T):
    if elite:
        return int(T / 0.16) % 4
    t = T % 2.4
    return 2 if 2.24 < t <= 2.32 else 3 if t > 2.32 else 0


# ------------------------------------------------------------------ çıktı yardımcıları
def np_img(a):
    return Image.fromarray(a, "RGBA")


def paste_scaled(dst, arr, x, y, k):
    im = np_img(arr).resize((CW * k, CH * k), Image.NEAREST)
    dst.alpha_composite(im, (int(x), int(y)))


def header(w, title, sub):
    im = Image.new("RGBA", (w, 38), (30, 34, 32, 255))
    d = ImageDraw.Draw(im)
    label(d, 8, 3, title, 14)
    label(d, 8, 21, sub, 10, (200, 196, 182))
    return im


ORDER = ["cur", "A", "B", "C", "D"]
NAMES = {"cur": "ŞU AN", "A": "A  Kubbeli Hazine", "B": "B  Işık Sütunu", "C": "C  Zincirli Mühür", "D": "D  Tombul Masal"}
REFS = {"cur": "gen_chest_sprites.py", "A": "WoW / klasik MMO", "B": "Lost Ark / Diablo", "C": "Black Desert / Lost Ark",
        "D": "MapleStory / Ragnarok"}


def frame_for(did, elite, st):
    if did == "cur":
        if st.ph == "idle":
            return render_cur(elite, cur_idle_frame(elite, st.T), bob(st))
        if st.ph == "shake":
            return render_cur(elite, 4 + st.step)
        return render_cur(elite, cur_frame_reward(0.98 + st.pt))
    return render(did, elite, st)


def st_at(ot, T):
    """Ödül ekranı zaman çizelgesi: ot < 0.46 bekleme, 0.46-0.98 sallanma, sonra açık (pt = patlamadan beri)."""
    if ot < 0.46:
        return St("idle", 0.0, T)
    if ot < 0.98:
        return St("shake", ot - 0.46, T)
    return St("open", ot - 0.98, T)


# ------------------------------------------------------------------ özet
def build_ozet():
    k = 3
    cw, chh = 60 * k, 70 * k
    top = 46
    lab_w = 120
    W = lab_w + len(ORDER) * cw
    rows = [("normal  kapalı", False, St("idle", 0, 0.0)), ("normal  açık", False, St("open", 0.8, 0.3)),
            ("elit  kapalı", True, St("idle", 0, 0.0)), ("elit  açık", True, St("open", 0.8, 0.3))]
    H = top + len(rows) * chh
    im = Image.new("RGBA", (W, H), (34, 38, 40, 255))
    d = ImageDraw.Draw(im)
    for i, did in enumerate(ORDER):
        label(d, lab_w + i * cw + 8, 6, NAMES[did], 12)
        label(d, lab_w + i * cw + 8, 24, REFS[did], 10, (190, 186, 170))
    for r, (nm, el, st) in enumerate(rows):
        y0 = top + r * chh
        bgc = (44, 50, 46, 255) if r % 2 == 0 else (40, 46, 44, 255)
        d.rectangle((0, y0, W, y0 + chh - 1), fill=bgc)
        label(d, 8, y0 + chh // 2 - 8, nm, 12)
        for i, did in enumerate(ORDER):
            sh, ch = frame_for(did, el, st)
            ox = lab_w + i * cw + (cw - CW * k) // 2
            oy = y0 + chh - (BY + 6) * k
            paste_scaled(im, sh, ox, oy, k)
            paste_scaled(im, ch, ox, oy, k)
    im = im.convert("RGB")
    p = os.path.join(OUT, "sandik_ozet.png")
    im.save(p)
    print("png", p, im.size)


# ------------------------------------------------------------------ oyun ölçeği
_BGW = None


def world_bg():
    """Gerçek oyun çizimi (madde 191 doygunluk karşılaştırması, 'Köprü / çayır - SONRA' paneli, 1 px = 1 dünya px)."""
    global _BGW
    if _BGW is None:
        im = Image.open(os.path.join(GAME, "tools/proto_20261016/harita_renk/harita_doygunluk_once_sonra.png")).convert("RGBA")
        _BGW = im.crop((494, 336, 494 + 250, 336 + 128))
    return _BGW


LANE_W, LANE_H = 250, 92


def lane_bg(i):
    bg = world_bg()
    y = (0, 36, 18, 30, 6)[i]
    c = bg.crop((0, y, LANE_W, y + LANE_H))
    if i % 2:
        c = c.transpose(Image.FLIP_LEFT_RIGHT)
    ch = asset("assets/characters/assasin/sheets/idle.png", (0, 96, 48, 144))
    k = CHAR_K
    chi = ch.resize((int(48 * k), int(48 * k)), Image.NEAREST)
    c = c.copy()
    c.alpha_composite(chi, (22 - chi.width // 2, 82 - int(40 * k)))
    return c


def world_state(T, offset):
    """Dünyada: 2,4 sn bekleme -> 0,2 sn sallanma -> 0,45 sn açılış (ödül saatinin ~2 katı hızlı) + 0,18 sn sönme -> yeniden."""
    loop = 3.6
    t = (T + offset) % loop
    if t < 2.4:
        return St("idle", 0, T, True), min(1.0, t / 0.2)
    if t < 2.6:
        return St("shake", (t - 2.4) / 0.2 * 0.52, T, True), 1.0
    if t > 3.23:
        return St("idle", 0, T, True), 0.0
    a = 1.0 if t < 3.05 else max(0.0, 1.0 - (t - 3.05) / 0.18)
    return St("open", (t - 2.6) * 1.6, T, True), a


def build_oyun():
    lanes = []
    for i, did in enumerate(ORDER):
        lanes.append(lane_bg(i))
    W = LANE_W * ZOOM
    hd = header(W, "Sandıklar  ·  oyun ölçeği (kamera x2, gerçek harita + karakter)",
                "sol: normal  ·  sağ: elit  ·  bekleme -> dünyadaki kısa açılış")
    n = int(3.6 * FPS)
    frames = []
    for s in range(n):
        T = s / float(FPS)
        parts = [hd]
        for i, did in enumerate(ORDER):
            lane = lanes[i].copy()
            for j, el in enumerate((False, True)):
                st, a = world_state(T, 0.25 * j)
                if did == "cur" and st.ph == "open":
                    fr = min(12, 8 + int(st.pt / 0.08))
                    sh, ch = render_cur(el, fr)
                else:
                    sh, ch = frame_for(did, el, st)
                if a <= 0.0:
                    continue
                cx = 105 + j * 85
                ox, oy = cx - CX, 86 - BY
                for arr in (sh, ch):
                    im = np_img(arr)
                    if a < 1.0:
                        al = np.asarray(im).copy()
                        al[:, :, 3] = (al[:, :, 3] * a).astype(np.uint8)
                        im = np_img(al)
                    lane.alpha_composite(im, (ox, oy))
            big = lane.resize((LANE_W * ZOOM, LANE_H * ZOOM), Image.NEAREST)
            d = ImageDraw.Draw(big)
            label(d, 6, 4, NAMES[did], 11)
            parts.append(big)
        frames.append(stack(parts))
    save_gif(frames, os.path.join(OUT, "sandik_oyun.gif"), FPS)
    frames[int(1.0 * FPS)].save(os.path.join(OUT, "sandik_oyun_kare.png"))


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
    for i, idx in enumerate((0, len(rgb) // 2, int(len(rgb) * 0.8))):
        sample.paste(rgb[idx], (0, rgb[0].height * i))
    pal = sample.quantize(255, method=Image.Quantize.MEDIANCUT)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in rgb]
    q[0].save(path, save_all=True, append_images=q[1:], duration=int(round(1000.0 / fps)), loop=0, disposal=1)
    print("gif", path, len(q))


# ------------------------------------------------------------------ ödül ekranı (yakın)
def build_odul():
    k = 3
    cw, chh = 62 * k, 92 * k
    top = 44
    W = len(ORDER) * cw
    H = top + 2 * chh + 20
    total = 0.98 + 0.55 + 0.9
    n = int(total * FPS)
    hd = header(W, "Ödül ekranı gibi yakın (x3)  ·  tam açılış dizisi", "üst: normal  ·  alt: elit  ·  bekleme 0,46 sn -> sallanma 0,52 sn -> patlama")
    frames = []
    for s in range(n):
        ot = s / float(FPS)
        im = Image.new("RGBA", (W, H), (26, 24, 30, 255))
        im.alpha_composite(hd, (0, 0))
        d = ImageDraw.Draw(im)
        for i, did in enumerate(ORDER):
            label(d, i * cw + 8, top + 2, NAMES[did], 11)
            for r, el in enumerate((False, True)):
                st = st_at(ot, ot)
                sh, ch = frame_for(did, el, st)
                ox = i * cw + (cw - CW * k) // 2
                oy = top + 18 + r * chh + chh - (BY + 6) * k
                paste_scaled(im, ch, ox, oy, k)
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
