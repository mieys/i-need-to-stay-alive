"""Sandık sprite sayfaları - "B Işık Sütunu" (Lost Ark / Diablo esinli, kasvetli gerçekçi; 2026-10-17, madde 241/242).

Kullanıcı: "normal ve elit sandığın görünüşleri için mmorpg oyunlarından esinlenerek yeni prototipler üret" -> B yönü seçildi
(prototip: tools/proto_20261017/sandik_proto.py v3; efektler DÜZ/BANTLI, dither noktası yok - "parazit gibi, çok ai duruyor").
Eski 48 px meşe/mor sandık üreticisi git geçmişinde (57ba6d98).

1 sanat pikseli = 0,5 dünya px (silahlarla aynı yoğunluk; oyunda Sprite2D ölçeği 0,5, bkz. scripts/chest_art.gd).

SANDIK sayfaları: 20 kare x 96x96 px (= 48 dünya px, eski 48 px kareyle aynı yer kaplar), sandığın alt kenarı y=84, ortası x=48.
  0-3   bekleme (normal: 2-3 asma kilitte kısa parıltı; elit: mor taş nabız atar, 1'de mercek parıltısı)
  4-7   sallanma: kapak 1-2 sanat px aralanır, aralıktan düz ışık + yanlara bantla sönen çizgi
  8     patlama: kapak arkaya, düz katmanlı flaş
  9-15  keskin ince ışınlar + hız yönünde kısa kıvılcım çizgileri + küçük sikkeler + zeminde toz
  16-19 açık bekleme döngüsü (içerisi ışığın kaynağı, ağızdan yükselen 2 parıltı)
  chest_normal.png = dünya (sıcak altın ışık), chest_normal_t1..t4.png = ödül ekranı, ışık = çıkacak eşyanın nadirliği,
  chest_elite.png = elit (kararmış çelik + donuk altın + yüzeyli mor taş).

IŞIK SÜTUNU sayfaları (sandığın ARKASINDA ayrı sprite): 37 kare x 128x192 px, sandık altı (64, 176).
  0-23  bekleme döngüsü (10 fps = 2,4 sn; halka yayları / rünler / genişlik dalgası / parıltılar bu sürede tam tur atar)
  24-27 sallanma (sütun uzar + genişler, halka hızlanır)
  28-36 çökme (0,05 sn arayla: sütun sandığa çöker, halka dışa açılıp bant bant söner)
  chest_beam.png (dünya), chest_beam_t1..t4.png (ödül ekranı, nadirlik rengi), chest_beam_elite.png.

Çalıştır: python tools/gen_chest_sprites.py   (sonra Godot editörü ya da `--headless --import` yeni dosyaları içe aktarır)
"""
import math
import os
import random

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'sprites', 'chests')

CF = 96               # sandık karesi (px)
N_CHEST = 20
CCX, CBY = 48, 84     # sandık karesinde sandığın ortası / alt kenarı
BW, BH = 128, 192     # ışık sütunu karesi
BCX, BBY = 64, 176
N_BEAM = 37
BEAM_IDLE, BEAM_SHAKE, BEAM_COLLAPSE = 24, 24, 28
LOOP = 2.4            # bekleme döngüsü (sn) - tüm periyodik hareketler bunun tam böleni
W_RING = (math.tau / 3.0) / LOOP       # 3 parlak yay: 1/3 tur = döngü
W_WOB = math.tau * 2.0 / LOOP          # sütun genişlik dalgası


def C(h, a=255):
    h = h.lstrip('#')
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


WHITE = C('#fffaf0')
WOOD = R('#15100c #271d16 #3b2c20 #53402e #6e5640 #8c7256')
IRON = R('#0e1013 #1d2126 #30363d #4a525b #6c757f #a3acb5')
RUST = R('#3a1c10 #5e2e18 #86452a #a8623c')
DGOLD = R('#2a1e0a #4e3a14 #7a5c22 #a88232 #d2ac52 #f4dc96')
GEM = R('#1e0a2e #45166a #7a2fb0 #b56ae8 #ecd2ff')
BST = R('#0a0a0e #16161c #24242c #383842 #54545f #868692')
## (yan ışık, çekirdek). Normalde ödül ekranı nadirliği: 1 gri-beyaz, 2 mavi, 3 mor, 4 altın (chest_open_anim LIGHT_COLORS ailesi).
LIGHTS = {
    'world': (C('#ffb84a'), C('#ffe9a8')),
    1: (C('#aebccd'), C('#eef3f8')),
    2: (C('#4f8fff'), C('#c4dcff')),
    3: (C('#a35cff'), C('#e6ccff')),
    4: (C('#ffb84a'), C('#ffe9a8')),
    'elite': (C('#9a4af0'), C('#d6a6ff')),
}


class L:
    def __init__(self, w, h):
        self.W, self.H = w, h
        self.a = np.zeros((h, w, 4), np.uint8)

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

    def sprite(self, rows, x0, y0, pal):
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch in pal:
                    self.px(x0 + i, y0 + j, pal[ch])

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                if ((x - cx) / max(rx, 0.5)) ** 2 + ((y - cy) / max(ry, 0.5)) ** 2 <= 1.0:
                    self.px(x, y, c)

    def glow(self, x, y, c, a, steps=4):
        """Efekt pikseli: DÜZ, dither YOK; alfa birkaç basamağa yuvarlanır (solma bant bant), üst üste en opak kalır."""
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


def outline_selout(S, k_lit=0.5, k_dark=0.3):
    """Siyah kontür yok: kenar pikseli komşu rengin koyusu (gerçekçi B dili)."""
    m = S.a[:, :, 3] > 0
    up, dn, lf, rt = (np.zeros_like(m) for _ in range(4))
    up[1:, :] = m[:-1, :]
    dn[:-1, :] = m[1:, :]
    lf[:, 1:] = m[:, :-1]
    rt[:, :-1] = m[:, 1:]
    e = (up | dn | lf | rt) & ~m
    src = S.a.copy()
    for y, x in zip(*np.nonzero(e)):
        cs = [src[y + dy, x + dx, :3].astype(int) for dy, dx, f in ((-1, 0, up), (1, 0, dn), (0, -1, lf), (0, 1, rt)) if f[y, x]]
        c = np.mean(cs, axis=0)
        k = k_dark if (up[y, x] or lf[y, x]) else k_lit
        S.a[y, x] = (int(c[0] * k), int(c[1] * k), int(c[2] * k), 255)


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
    """Temiz 4 kollu parıltı (ortası beyaz; kolların iç yarısı core, dış yarısı col); hlen = ayrı yatay kol boyu."""
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


def twinkle(T, ph, period=0.8, rmax=2):
    """Parıltı boyu 0 -> rmax -> 0 (yanıp sönmek yerine büyüyüp küçülür); -1 = görünmez."""
    u = ((T + ph) % period) / period
    if u > 0.75:
        return -1
    return int(round(math.sin(u / 0.75 * math.pi) * rmax))


class St:
    """ph: idle | shake | open; pt: evredeki sn; T: genel saat; step: sallanma adımı 0-3."""

    def __init__(self, ph, pt=0.0, T=0.0):
        self.ph, self.pt, self.T = ph, pt, T
        self.step = min(3, int(pt / 0.13)) if ph == 'shake' else 0

    @property
    def k(self):
        return (self.step + 1) / 4.0 if self.ph == 'shake' else 0.0

    def lift(self):
        return 0 if self.ph != 'shake' else (1 if self.step % 2 == 0 else 2)

    def dx(self):
        return 0 if self.ph != 'shake' else (-1, 1, -1, 1)[self.step]


def lid_pop(pt, seq=(-4, -2, 0)):
    return seq[min(len(seq) - 1, int(pt / 0.05))]


# ------------------------------------------------------------------ doku parçaları
def wood(S, x0, y0, x1, y1, seed, plank=6, extra=0.0, ao_top=0):
    for y in range(y0, y1 + 1):
        py = (y - y0) % plank
        for x in range(x0, x1 + 1):
            if py == plank - 1:
                S.px(x, y, WOOD[0] if hn(x, y, seed) < 0.75 else WOOD[1])
                continue
            g = vn(x / 8.0 + seed * 3.1, (y - y0) / 1.7, seed)
            v = 2.3 + (g - 0.5) * 2.4 + (hn(x, y, seed + 7) - 0.5) * 1.0 + extra
            if py == 0:
                v += 0.9
            if ao_top and y - y0 < ao_top:
                v -= (ao_top - (y - y0)) * 0.55
            if x == x1:
                v -= 0.8
            S.px(x, y, WOOD[ci(v, 1, 5)])
    rng = random.Random(seed * 7 + 1)
    area = (x1 - x0) * (y1 - y0)
    for _ in range(area // 140):  # çizikler
        sx, sy = rng.randint(x0 + 2, max(x0 + 2, x1 - 6)), rng.randint(y0, max(y0, y1 - 1))
        a = rng.uniform(-0.35, 0.35)
        for d in range(rng.randint(3, 7)):
            S.over(sx + d * math.cos(a), sy + d * math.sin(a), WOOD[5] if d % 3 else WOOD[4])
    if area > 300:  # budak
        kx, ky = rng.randint(x0 + 6, x1 - 8), rng.randint(y0 + 1, y1 - 3)
        S.sprite(['.bb.', 'bddb', '.bb.'], kx, ky, {'b': WOOD[4], 'd': WOOD[0]})


def iron(S, x0, y0, x1, y1, M, seed, extra=0.0, rust=True, bevel=True):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if rust and vn(x / 5.0 + 11, y / 5.0, seed + 5) > 0.64:
                S.px(x, y, RUST[ci(vn(x / 2.0, y / 2.0, seed + 9) * 4.0 - 0.5, 0, 3)])
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


def rivet(S, x, y, M, spec=False):
    for dy, row in enumerate(((4, 5, 3), (3, 3, 1), (1, 1, 0))):
        for dx, i in enumerate(row):
            S.px(x + dx, y + dy, M[i])
    if spec:
        S.px(x + 1, y, WHITE)


# ------------------------------------------------------------------ sandık
def draw_chest(S, F, elite, st, light, core, glint=-1):
    cx = CCX + st.dx() * 2
    by = CBY
    w, bh, lf, lt = (54, 22, 12, 9) if elite else (46, 18, 10, 8)
    x0, x1 = cx - w // 2, cx + w // 2 - 1
    bt = by - bh
    T = st.T
    seed = 8 if elite else 4
    lift = st.lift() * 2
    if elite:  # kararmış çelik plakalar + donuk altın kenar + oymalı köşe
        iron(S, x0, bt, x1, by - 1, BST, seed, rust=False)
        for yy in range(bt + 8, by - 2, 8):
            S.hl(x0 + 2, x1 - 2, yy, BST[0])
            for xx in range(x0 + 6, x1 - 6, 9):
                S.px(xx, yy + 2, BST[5])
                S.px(xx + 1, yy + 3, BST[1])
        for yy in range(bt, by):
            for xx, i in ((x0, 4), (x0 + 1, 3), (x1 - 1, 2), (x1, 1)):
                S.px(xx, yy, DGOLD[i])
        S.hl(x0, x1, by - 1, DGOLD[1])
        S.hl(x0, x1, by - 2, DGOLD[2])
        for sx, d in ((x0, 1), (x1, -1)):
            for j in range(9):
                for i in range(9 - j):
                    c = DGOLD[3] if (i + j) < 7 else DGOLD[1]
                    if (i - j) % 3 == 0 and i + j < 7:
                        c = DGOLD[1]
                    if i == 0 or j == 0:
                        c = DGOLD[4]
                    S.px(sx + d * i, by - 1 - j, c)
    else:  # aşınmış tahta + paslı demir çerçeve, dikey kayışlar
        wood(S, x0 + 3, bt + 2, x1 - 3, by - 4, seed, ao_top=4)
        iron(S, x0, bt, x0 + 2, by - 1, IRON, seed)
        iron(S, x1 - 2, bt, x1, by - 1, IRON, seed + 1)
        iron(S, x0, by - 3, x1, by - 1, IRON, seed + 2)
        iron(S, x0, bt, x1, bt + 1, IRON, seed + 3, extra=-0.8)
        for sx in (x0 + 12, x1 - 15):
            iron(S, sx, bt, sx + 3, by - 1, IRON, seed + sx)
            for yy in range(bt + 4, by - 4, 6):
                rivet(S, sx, yy, IRON, spec=(yy // 6) % 2 == 0)
        for yy in range(bt + 3, by - 4, 6):
            rivet(S, x0, yy, IRON)
            rivet(S, x1 - 2, yy, IRON)
    if st.ph == 'open':
        ot = 8
        oy = bt - ot
        iron(S, x0 - 1, oy, x1 + 1, oy + 1, BST if elite else IRON, seed + 4, rust=not elite)
        for y in range(oy + 2, bt):  # içerisi ışığın kaynağı (düz bantlar)
            for x in range(x0 + 1, x1):
                d = math.hypot((x - cx) / (w * 0.42), (y - (bt - 1)) / 5.5)
                v = 3.2 - d * 2.6
                S.px(x, y, WHITE if v > 2.4 else core if v > 1.6 else light if v > 0.8 else
                     (GEM[1] if elite else WOOD[1]) if v > 0.0 else (GEM[0] if elite else WOOD[0]))
        ly1 = oy - 1 + lid_pop(st.pt)
        ly0 = ly1 - (lf + lt) + 1
        if elite:
            iron(S, x0 - 1, ly0, x1 + 1, ly1, BST, seed + 6, extra=-1.2, rust=False)
            for yy in range(ly0, ly1 + 1):
                S.px(x0 - 1, yy, DGOLD[2])
                S.px(x1 + 1, yy, DGOLD[1])
        else:
            wood(S, x0 + 2, ly0 + 2, x1 - 2, ly1, seed + 5, extra=-1.4)
            iron(S, x0 - 1, ly0, x0 + 1, ly1, IRON, seed + 6, extra=-0.8)
            iron(S, x1 - 1, ly0, x1 + 1, ly1, IRON, seed + 7, extra=-1.2)
            iron(S, x0 - 1, ly0, x1 + 1, ly0 + 1, IRON, seed + 8)
        mouth_y = bt - 3
    else:
        ft = bt - lift - lf
        tt = ft - lt
        lx0, lx1 = x0 - 1, x1 + 1
        if elite:
            iron(S, lx0, tt, lx1, ft - 1, BST, seed + 11, extra=1.0, rust=False)
            iron(S, lx0, ft, lx1, bt - 1 - lift, BST, seed + 12, rust=False)
            for yy in range(tt, bt - lift):
                for xx, i in ((lx0, 4), (lx0 + 1, 3), (lx1 - 1, 2), (lx1, 1)):
                    S.px(xx, yy, DGOLD[i])
            S.hl(lx0, lx1, tt, DGOLD[4])
            S.hl(lx0, lx1, ft, DGOLD[3])
            S.hl(lx0, lx1, bt - 1 - lift, DGOLD[1])
            gx, gy = cx, ft + lf // 2 - 1  # mor taş: altın yuva + yüzeyli taş, nabız
            S.ellipse(gx, gy, 6.4, 6.4, DGOLD[2])
            S.ellipse(gx - 0.5, gy - 0.5, 5.5, 5.5, DGOLD[4])
            S.ellipse(gx, gy, 5.2, 5.2, DGOLD[1])
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
                        S.px(xx, yy, GEM[min(4, i + (1 if pulse > 0.75 and i < 3 else 0))])
            if pulse > 0.8:  # taşta tek mercek parıltısı
                star4(F, gx - 2, gy - 2, 2, GEM[4], GEM[3], hlen=4)
        else:
            wood(S, lx0 + 3, tt + 2, lx1 - 3, ft - 1, seed + 13, plank=4, extra=1.2)
            wood(S, lx0 + 3, ft + 2, lx1 - 3, bt - 4 - lift, seed + 14, plank=5)
            iron(S, lx0, tt, lx0 + 2, bt - 1 - lift, IRON, seed + 15, extra=0.4)
            iron(S, lx1 - 2, tt, lx1, bt - 1 - lift, IRON, seed + 16, extra=-0.4)
            iron(S, lx0, tt, lx1, tt + 1, IRON, seed + 17, extra=1.0)
            iron(S, lx0, ft, lx1, ft + 1, IRON, seed + 18, extra=0.6)
            iron(S, lx0, bt - 3 - lift, lx1, bt - 1 - lift, IRON, seed + 19, extra=-0.3)
            for sx in (x0 + 12, x1 - 15):
                iron(S, sx, tt, sx + 3, bt - 1 - lift, IRON, seed + 20 + sx, extra=0.3)
                rivet(S, sx, ft + 3, IRON, spec=True)
            iron(S, cx - 3, bt - 6 - lift, cx + 2, bt + 3, IRON, seed + 21, extra=0.5)  # asma kilit
            for a in range(14):
                an = math.pi + a / 13.0 * math.pi
                S.px(cx - 0.5 + math.cos(an) * 3.5, bt + 5 + math.sin(an) * 3.5, IRON[4 if a < 7 else 2])
            for yy in range(bt + 5, bt + 13):
                for xx in range(cx - 5, cx + 5):
                    v = 3.0 + (hn(xx, yy, 5) - 0.5) * 1.2 + (1 if xx < cx - 2 else -1 if xx > cx + 2 else 0)
                    S.px(xx, yy, DGOLD[ci(v, 0, 5)])
            S.vl(cx, bt + 8, bt + 10, DGOLD[0])
            S.px(cx - 4, bt + 5, DGOLD[5])
            if glint >= 0:  # kilitte kısa parıltı (dünyada 2,4 sn'de bir, kare 2-3)
                star4(F, cx - 4, bt + 5, glint, DGOLD[5], light, hlen=glint + 1)
        if lift:  # ince keskin aralık ışığı
            for y in range(bt - lift, bt):
                S.hl(x0, x1, y, core)
            n = 6 + int(st.k * 14)
            for i in range(1, n + 1):
                F.glow(x0 - i, bt - 1, light, 1 - i / float(n + 1))
                F.glow(x1 + i, bt - 1, light, 1 - i / float(n + 1))
        mouth_y = bt - 1
    return dict(cx=cx, mouth=(cx, mouth_y), w=w, x0=x0, x1=x1, by=by)


def fx_open(F, g, elite, st, light, core, loop_phase=None):
    pt = st.pt
    mx, my = g['mouth']
    if pt < 0.14:  # düz katmanlı flaş
        k = 1 - pt / 0.14
        rx = g['w'] * 0.62 * (0.7 + 0.3 * k)
        F.gellipse(mx, my, rx, 7.0 * k + 1, light, 0.35)
        F.gellipse(mx, my, rx * 0.72, 5.0 * k + 1, core, 0.7)
        F.gellipse(mx, my, rx * 0.42, 3.0 * k + 1, WHITE, 1.0)
    if pt < 0.55:  # keskin ince ışınlar: düz çizgi, uca doğru bant bant söner (kare 96 px'e sığar)
        g_ = min(1.0, pt / 0.08)
        fade = 1.0 if pt < 0.2 else max(0.0, 1 - (pt - 0.2) / 0.35)
        rng = random.Random(21 + elite)
        n = 9 if elite else 7
        for i in range(n):
            ang = -math.pi / 2 + (i - (n - 1) / 2.0) / ((n - 1) / 2.0) * 0.95 + rng.uniform(-0.05, 0.05)
            ln = (56 if elite else 48) * (0.6 + 0.4 * rng.random()) * g_
            for d in range(4, int(ln)):
                u = d / ln
                F.glow(mx + math.cos(ang) * d, my + math.sin(ang) * d, WHITE if u < 0.3 else core if u < 0.6 else light,
                       (1.0 if u < 0.6 else 0.5) * fade)
    if 0.0 < pt < 0.7:
        k = pt / 0.7  # zeminde iki yana açılan toz: birkaç dolu yarı saydam bulut
        for s in (-1, 1):
            for j in range(3):
                px_ = mx + s * (12 + j * 7) * (0.4 + 0.8 * k)
                F.gellipse(px_, CBY - 3 - j, 6 - j + 4 * k, 3.0 + 1.5 * k, (150, 138, 120, 255), 0.5 * (1 - k))
                F.gellipse(px_ - s, CBY - 5 - j, (6 - j + 4 * k) * 0.6, 2 + k, (184, 172, 152, 255), 0.5 * (1 - k))
        rng = random.Random(33 + elite)  # kıvılcım: hız yönünde kısa düz çizgi
        for i in range(10 if elite else 7):
            vx, vy = rng.uniform(-70, 70), -rng.uniform(110, 160)
            t = pt - rng.uniform(0, 0.05)
            if t <= 0 or t > 0.55:
                continue
            x, y = mx + vx * t, my + vy * t + 240 * t * t
            dvx, dvy = vx, vy + 480 * t
            sp = math.hypot(dvx, dvy) or 1.0
            ln = 5.0 * (1 - t / 0.55) + 1
            F.gline(x - dvx / sp * ln, y - dvy / sp * ln, x, y, core if t < 0.18 else light)
        rng = random.Random(44 + elite)  # küçük sikkeler
        for i in range(10 if elite else 7):
            vx, vy = rng.uniform(-55, 55), -rng.uniform(110, 150)
            t = pt - rng.uniform(0, 0.05)
            if t <= 0:
                continue
            y = min(CBY + 2, my + vy * t + 300 * t * t)
            x = mx + vx * t
            if int(pt * 20 + i) % 3 == 1:
                F.vl(int(x) + 1, int(y), int(y) + 2, DGOLD[4])
            else:
                F.sprite(['.a.', 'abc', '.c.'], int(x), int(y), {'a': DGOLD[5], 'b': DGOLD[4], 'c': DGOLD[2]})
    if loop_phase is not None:  # açık bekleme: ağızdan yükselen 2 temiz parıltı (4 karelik döngüye dikişsiz)
        for i in range(2):
            u = (loop_phase + i * 0.5) % 1.0
            r = int(round(math.sin(u * math.pi) * 2))
            star4(F, mx + (-7, 8)[i], my - 4 - u * 18, r, core, light, hlen=r + 1)


def chest_frame(fi, elite, light, core):
    S, F = L(CF, CF), L(CF, CF)
    loop_phase = None
    glint = -1
    if fi <= 3:
        st = St('idle', 0.0, (0.0, 0.393, 0.785, 1.178)[fi])  # elit taş nabzı: 0,5 / 1 / 0,5 / 0
        if not elite and fi >= 2:
            glint = fi - 1
    elif fi <= 7:
        st = St('shake', (fi - 4) * 0.13 + 0.01)
    elif fi <= 15:
        st = St('open', (0.02, 0.08, 0.14, 0.20, 0.26, 0.33, 0.40, 0.48)[fi - 8])
    else:
        st = St('open', 0.72)  # sikke/toz/kıvılcım bitmiş olsun (döngüde yerde donuk kalmasın)
        loop_phase = (fi - 16) / 4.0
    g = draw_chest(S, F, elite, st, light, core, glint)
    outline_selout(S)
    if st.ph == 'open':
        fx_open(F, g, elite, st, light, core, loop_phase)
    return comp(S, F)


# ------------------------------------------------------------------ ışık sütunu + yer halkası
RUNES = [['.#.', '###', '.#.', '#.#', '#.#'], ['##.', '#..', '###', '..#', '.##']]


def pillar(Lb, cx, base, h, wc, ws, light, core, T, boost=0.0, shrink=1.0):
    """Düz çekirdek + iki yarı saydam yan bant, yukarı az incelir, BANT BANT söner; nefes = genişlik dalgası."""
    h = int(h)
    for y in range(base - h, base + 1):
        u = (base - y) / float(max(1, h))
        fade = max(0.0, 1.0 - u) + boost
        wob = math.sin(T * W_WOB + y * 0.12) * 0.5
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


def ring(Lb, cx, cy, rx, ry, light, T, runes=0, rcol=None, scale=1.0, alpha=1.0):
    """Kesintisiz ince halka + 3 dönen parlak yay; elitte ters dönen rünler (2 şekil -> 1/3 turda döngü kapanır)."""
    rx, ry = rx * scale, ry * scale
    m = int((rx + ry) * 4.0)
    for i in range(m):
        a = i / float(m) * math.tau
        seg = ((a - T * W_RING) % math.tau) / math.tau * 3.0
        bright = (seg % 1.0) < 0.22
        Lb.glow(cx + math.cos(a) * rx, cy + math.sin(a) * ry, WHITE if bright else light, alpha * (1.0 if bright else 0.75))
    for r in range(runes):
        a = r / float(runes) * math.tau - T * W_RING
        x, y = cx + math.cos(a) * (rx + 7), cy + math.sin(a) * (ry + 4)
        for j, row in enumerate(RUNES[r % 2]):
            for i, ch in enumerate(row):
                if ch == '#':
                    Lb.glow(x - 1 + i, y - 2 + j, rcol, alpha)


def beam_frame(fi, elite, light, core):
    Lb = L(BW, BH)
    cx, by = BCX, BBY
    bt = by - (22 if elite else 18)
    runes = 6 if elite else 0
    rx, ry = (38, 14) if elite else (31, 11)
    if fi < BEAM_SHAKE:
        T = fi * (LOOP / BEAM_IDLE)
        ring(Lb, cx, by - 2, rx, ry, light, T, runes, GEM[3])
        pillar(Lb, cx, bt - 6, 118 if elite else 80, 3 if elite else 2, 9 if elite else 7, light, core, T)
        n = 3 if elite else 2  # sütunda yükselen birkaç temiz parıltı
        for i in range(n):
            u = (T / LOOP + i / float(n)) % 1.0
            yy = bt - 14 - u * (96 if elite else 62)
            xx = cx + math.sin(T * W_WOB * 0.5 + i * 2.0) * 2.5
            star4(Lb, xx, yy, twinkle(T, i * 0.31, 0.8, 2), core, light, hlen=twinkle(T, i * 0.31, 0.8, 3))
    elif fi < BEAM_COLLAPSE:
        step = fi - BEAM_SHAKE
        k = (step + 1) / 4.0
        T = step * 0.13
        ring(Lb, cx, by - 2, rx + 2 * k, ry + k, light, T * (1 + 2 * k) * 3.0, runes, GEM[3])
        pillar(Lb, cx, bt - 6, (118 if elite else 80) + 12 * k, (3 if elite else 2) + k, (9 if elite else 7) + 3 * k,
               light, core, T, boost=0.15 * k)
    else:
        pt = (fi - BEAM_COLLAPSE) * 0.05
        pillar(Lb, cx, bt - 6, (130 if elite else 92) * (1 - pt / 0.45), 4, 11, light, core, 0.0, boost=0.3,
               shrink=max(0.0, 1 - pt / 0.3) + 0.12)
        ring(Lb, cx, by - 2, rx, ry, light, 0.0, runes, GEM[3], scale=1 + pt * 1.2, alpha=1 - pt / 0.45)
    return Lb.a


def save_strip(frames, w, h, name):
    im = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, a in enumerate(frames):
        im.paste(Image.fromarray(a, 'RGBA'), (i * w, 0))
    p = os.path.join(OUT, name)
    im.save(p)
    print(name, im.size)


def main():
    os.makedirs(OUT, exist_ok=True)
    kinds = [('chest_normal.png', 'chest_beam.png', False, 'world')]
    kinds += [('chest_normal_t%d.png' % t, 'chest_beam_t%d.png' % t, False, t) for t in (1, 2, 3, 4)]
    kinds += [('chest_elite.png', 'chest_beam_elite.png', True, 'elite')]
    for cname, bname, elite, key in kinds:
        light, core = LIGHTS[key]
        save_strip([chest_frame(i, elite, light, core) for i in range(N_CHEST)], CF, CF, cname)
        save_strip([beam_frame(i, elite, light, core) for i in range(N_BEAM)], BW, BH, bname)


if __name__ == '__main__':
    main()
