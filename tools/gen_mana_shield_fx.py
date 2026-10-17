"""MANA KALKANI "B - Mühür" efekt sayfaları (kullanıcı 2026-10-14: prototip B seçildi; Kale mor, Enerji sarı; kazma vuruşunda
çatlak yok; kırılınca HER TARAFTAN kırılmış görünmeli). Prototip: tools/proto_20261014/mana_kalkan_proto.py (Sigil).

Sayfalar RENK değil TON NUMARASI taşır (R=G=B = ton*36, A = saydamlık): 0 kontur, 1 koyu, 2 orta, 3 açık, 4 parlak,
5 krem, 6 beyaz. Renk oyunda shaders/mana_shield.gdshader'da kalkan türünün paletinden gelir (scripts/mana_shield_fx.gd
PALETTES) - 4 tür tek sayfa, renk değişikliği yeniden çizim istemez.
Ölçek: 1 sanat px = 1 KARAKTER pikseli (sprite ölçeği = karakterin anim.scale'i), prototiple birebir.

    python -I tools/gen_mana_shield_fx.py          -> assets/fx/mana_shield/*.png + tools/proto_20261014/out/mana_muhur_onizleme.gif
Sonra: Godot --headless --path . --import
"""
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..'))
OUT = os.path.join(PROJECT, 'assets', 'fx', 'mana_shield')
TAU = 2.0 * math.pi
TONE_STEP = 36

# ---- ortak sabitler (scripts/mana_shield_fx.gd ile AYNI tutulmalı) ----
DISC_R = 10.5            # darbe mührü yarıçapı
DISC_CELL = 30
DISC_WIDTHS = [0.4, 0.6, 0.8, 1.0]  # yatay basıklık sınıfları: f = 0.4 + 0.6*|sin(açı)|
DISC_ROT_FRAMES = 6      # desen 90 derecede bir tekrar eder
BREAK_CELL = (88, 96)
BREAK_BODY = (44.0, 42.0)  # hücrede gövde merkezi
BREAK_FRAMES = 14        # 20 fps, 0,7 sn
SHELL_R = (19.0, 21.0)   # kırılırken karakteri saran küre mührün yarıçapı (x, y)
DEBRIS_CELL = (88, 48)   # yere düşen kırıklar (kırılmanın son karesi), ayak hücrede DEBRIS_FEET'te
DEBRIS_FEET = (44.0, 24.0)
DEBRIS_FRAMES = 2        # 0 = yeni düşmüş (parıltılı), 1 = sönmüş (parıltı yok, bir ton koyu); kayboluş saydamlıkla
GROUND_CELL = (46, 22)
GROUND_C = (23.0, 11.0)
GROUND_R = (17.0, 6.0)
RISE_CELL = (40, 58)
RISE_FEET = (20.0, 48.0)
RISE_FRAMES = 11         # 20 fps, 0,55 sn
RISE_H = 36.0
FEET_TO_BODY = 15.0      # ayak -> gövde merkezi (karakter pikseli)

RUNES = [
    ['#.#.#', '.###.', '..#..', '..#..', '..#..'],
    ['#..', '##.', '#.#', '##.', '#..'],
    ['..#..', '.#.#.', '#.#.#', '..#..', '..#..'],
    ['#...#', '##.##', '#.#.#', '##.##', '#...#'],
]


class Cv:
    """Ton tuvali: tone (-1 boş) + alpha."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.tone = np.full((h, w), -1, np.int16)
        self.a = np.zeros((h, w), np.uint8)
        yy, xx = np.mgrid[0:h, 0:w]
        self.X, self.Y = xx + 0.5, yy + 0.5
        self.B = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0)[yy % 4, xx % 4]

    def put(self, m, tone, a=255):
        self.tone[m] = tone
        self.a[m] = a

    def px(self, x, y, tone, a=255):
        x, y = int(math.floor(x)), int(math.floor(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.tone[y, x] = tone
            self.a[y, x] = a

    def ell(self, cx, cy, rx, ry):
        return ((self.X - cx) / max(rx, 0.01)) ** 2 + ((self.Y - cy) / max(ry, 0.01)) ** 2 <= 1.0

    def filled(self):
        return self.tone >= 0

    def fade(self, k):
        self.a = (self.a.astype(np.float32) * max(0.0, min(1.0, k)) + 0.5).astype(np.uint8)
        self.tone[self.a == 0] = -1

    def glow(self):
        """1 px yumuşak hale (prototip glow ile aynı)."""
        m = self.filled() & (self.a > 90)
        if not m.any():
            return
        empty = ~self.filled()
        h1 = dil(m) & ~m & empty
        h2 = dil(dil(m)) & ~dil(m) & empty & (self.B < 0.5)
        self.put(h1, 3, 70)
        self.put(h2, 3, 38)

    def rgba(self):
        out = np.zeros((self.h, self.w, 4), np.uint8)
        m = self.filled()
        v = (np.clip(self.tone, 0, 6) * TONE_STEP).astype(np.uint8)
        for c in range(3):
            out[:, :, c] = np.where(m, v, 0)
        out[:, :, 3] = np.where(m, self.a, 0)
        return out


def dil(m):
    o = m.copy()
    o[1:] |= m[:-1]
    o[:-1] |= m[1:]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    return o


def ero(m):
    return ~dil(~m)


def outline(m):
    return dil(m) & ~m


def ang_d(a, b):
    return np.abs((a - b + math.pi) % TAU - math.pi)


def ease_out(x):
    x = min(1.0, max(0.0, x))
    return 1.0 - (1.0 - x) ** 3


def glyph(cv, rows, x, y, core, edge):
    h, w = len(rows), len(rows[0])
    m = np.zeros((cv.h, cv.w), bool)
    x0, y0 = int(round(x - w / 2.0)), int(round(y - h / 2.0))
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            if ch == '#' and 0 <= y0 + r < cv.h and 0 <= x0 + c < cv.w:
                m[y0 + r, x0 + c] = True
    cv.put(outline(m), edge)
    cv.put(m, core)


def disc(cv, cx, cy, R, f, rot, cracked=0.0, flash=False, only=None):
    """Büyü mührü (prototip Sigil._disc). f = yatay basıklık. only: çizimi bu maskeyle sınırla (parçalar için)."""
    if R < 1.0:
        return None
    rx, ry = R * f, R
    u, v = (cv.X - cx) / rx, (cv.Y - cy) / ry
    rho = np.sqrt(u * u + v * v)
    th = np.arctan2(v, u)
    d = rho <= 1.0
    lim = only if only is not None else np.ones_like(d)
    cv.put(d & lim, 1, 110)  # yarı saydam büyü camı
    ring = d & ~ero(ero(d))
    cv.put(outline(d) & lim, 0)
    cv.put(ring & lim, 2)
    cv.put(ring & (v < -0.2) & lim, 3)
    inner = rho <= 0.6
    cv.put(inner & ~ero(inner) & lim, 3)
    ticks = (rho > 0.66) & (rho < 0.84) & (ang_d((th - rot) * 4.0 % TAU, 0.0) < 0.55)
    cv.put(ticks & d & lim, 4)
    dia = (np.abs(np.cos(rot) * u + np.sin(rot) * v) + np.abs(-np.sin(rot) * u + np.cos(rot) * v)) < 0.36
    cv.put(dia & lim, 4)
    cv.put(((np.abs(u) + np.abs(v)) < 0.14) & lim, 5)
    if cracked > 0:
        for j in range(5):
            ca = j * 1.257 + 0.4
            for r in np.linspace(0, cracked, 10):
                jit = math.sin(r * 9 + j * 2) * 0.14
                cv.px(cx + math.cos(ca + jit) * r * rx, cy + math.sin(ca + jit) * r * ry, 5)
    if flash:
        m = (cv.filled() & dil(dil(d))) & lim
        cv.put(m & (d | outline(d)), 5)
    return d, th, rx, ry


# ------------------------------------------------------------------ sayfalar
def disc_sheet():
    """Satır = basıklık sınıfı; sütun = [beliriş 0,35, beliriş 0,7, krem flaş, dönüş 0..5]."""
    cols = 3 + DISC_ROT_FRAMES
    sheet = np.zeros((DISC_CELL * len(DISC_WIDTHS), DISC_CELL * cols, 4), np.uint8)
    c0 = DISC_CELL / 2.0
    for r, f in enumerate(DISC_WIDTHS):
        for c in range(cols):
            cv = Cv(DISC_CELL, DISC_CELL)
            if c == 0:
                disc(cv, c0, c0, DISC_R * 0.35, f, 0.0)
            elif c == 1:
                disc(cv, c0, c0, DISC_R * 0.7, f, 0.0)
            elif c == 2:
                disc(cv, c0, c0, DISC_R, f, 0.0, flash=True)
            else:
                disc(cv, c0, c0, DISC_R, f, (c - 3) * (math.pi / 2) / DISC_ROT_FRAMES)
            cv.glow()
            sheet[r * DISC_CELL:(r + 1) * DISC_CELL, c * DISC_CELL:(c + 1) * DISC_CELL] = cv.rgba()
    return sheet


def shell(cv, cx, cy, sc, rot, cracked=0.0, flash=False):
    """Karakteri saran küre mühür (kırılma anı): kenar bandı + dönen çentikler + iç halka + 6 rün, saydam cam."""
    rx, ry = SHELL_R[0] * sc, SHELL_R[1] * sc
    if rx < 1.0:
        return None
    u, v = (cv.X - cx) / rx, (cv.Y - cy) / ry
    rho = np.sqrt(u * u + v * v)
    th = np.arctan2(v, u)
    d = rho <= 1.0
    cv.put(d, 2, 40)  # çok hafif cam: karakter görünür kalsın
    rim = d & ~ero(ero(d))
    cv.put(outline(d), 0)
    cv.put(rim, 2)
    cv.put(rim & (v < -0.3), 3)
    inner = rho <= 0.82
    cv.put(inner & ~ero(inner), 3, 200)
    ticks = (rho > 0.86) & (rho < 0.95) & (ang_d((th - rot) * 8.0 % TAU, 0.0) < 0.7)
    cv.put(ticks & d & ~rim, 4)
    for j in range(6):
        ga = rot * 0.5 + j * TAU / 6
        glyph(cv, RUNES[j % 4], cx + math.cos(ga) * rx * 0.9, cy + math.sin(ga) * ry * 0.9, 4, 1)
    if cracked > 0:  # çatlaklar HER yönden: kenarın 9 noktasından içe doğru, kırık çizgiler
        for j in range(9):
            ca = j * TAU / 9 + 0.25
            for r in np.linspace(1.0, 1.0 - 0.75 * cracked, 16):
                jit = math.sin(r * 11 + j * 3) * 0.16
                x, y = cx + math.cos(ca + jit) * r * rx, cy + math.sin(ca + jit) * r * ry
                cv.px(x, y + 1, 0)  # alttaki koyu piksel çatlağı camın üstünde seçilir kılar
                cv.px(x, y, 5)
    if flash:
        glass = d & (cv.a < 100)
        cv.put(d & ~glass, 5)
        cv.put(glass, 5, 80)
    return d, th, rho, rx, ry


def break_frame(i, side):
    """Kırılma (kullanıcı: "kalkan kırılınca her taraftan kırılmış gibi görünmeli"): karakteri saran küre mühür belirir,
    her yanından aynı anda çatlar, 20 parçaya ayrılıp DÖRT BİR YANA saçılır. side = 'back' (yukarı/geri uçan parçalar +
    ayak dibindeki şok halkası, karakterin ardında) / 'front'."""
    t = i / 20.0
    W, H = BREAK_CELL
    bx, by = BREAK_BODY
    cv = Cv(W, H)
    rot = t * 3.0
    if side == 'back':  # ayak dibinde genişleyen şok halkası
        k = (t - 0.22) / 0.36
        if 0.0 <= k < 1.0:
            fx, fy = bx, by + FEET_TO_BODY
            r = 10.0 + 22.0 * ease_out(k)
            m = cv.ell(fx, fy, r, r * 0.34) & ~cv.ell(fx, fy, r - 1.4, r * 0.34 - 1.0)
            cv.put(m, 4 if k < 0.35 else 3, int(255 * (1.0 - k)))
    if t < 0.25:
        if side == 'front':
            sc = 0.75 + 0.25 * ease_out((t + 0.05) / 0.1)
            cracked = 0.0 if t < 0.1 else min(1.0, (t - 0.1) / 0.1)
            shell(cv, bx, by, sc, rot, cracked=cracked, flash=(0.05 <= t < 0.1) or (0.2 <= t < 0.25))
        cv.glow()
        return cv.rgba()
    return shards(cv, min(1.0, (t - 0.25) / 0.4), side)


def shards(cv, k, side):
    """20 parça fırlar, kavis çizip YERE düşer, küçük bir sekme yapıp yerde kalır (kullanıcı 2026-10-14: "kalkan
    patladığında çatlaklar yere düşüp yavaşça kaybolsun"). k = 1 -> yerdeki son hal (DEBRIS sayfasının ilk karesi).
    side: 'back' = ayağın gerisine düşenler (karakterin ardında), 'front', 'all'."""
    W, H = BREAK_CELL
    bx, by = BREAK_BODY
    fx, fy = bx, by + FEET_TO_BODY
    full = Cv(W, H)
    d, th, rho, rx, ry = shell(full, bx, by, 1.0, 0.25 * 3.0, cracked=1.0)
    km = min(1.0, k / 0.82)
    hop = 1.5 * math.sin(math.pi * (k - 0.82) / 0.18) if k > 0.82 else 0.0
    for ring in range(2):
        r_in, r_out = (0.0, 0.62) if ring == 0 else (0.62, 1.01)
        n = 7 if ring == 0 else 13
        for w in range(n):
            wa = w * TAU / n + ring * 0.21
            piece = d & (rho >= r_in) & (rho < r_out) & (ang_d(th, wa) < TAU / (2 * n) - 0.05)
            if not piece.any():
                continue
            rl = (8.0 + 3.0 * (w % 3)) if ring == 0 else (17.0 + 5.0 * (w % 3))
            lx, ly = fx + math.cos(wa) * rl, fy + math.sin(wa) * rl * 0.55
            back = ly < fy - 1.0
            if side != 'all' and back != (side == 'back'):
                continue
            ys, xs = np.nonzero(piece)
            cx0, cy0 = xs.mean() + 0.5, ys.mean() + 0.5
            mx = (lx - cx0) * (1.0 - (1.0 - km) ** 2)
            my = (ly - cy0) * km - 22.0 * km * (1.0 - km) - hop
            sx, sy = int(round(mx)), int(round(my))
            sh = np.roll(np.roll(piece, sy, 0), sx, 1)
            src_t = np.roll(np.roll(full.tone, sy, 0), sx, 1)
            src_a = np.roll(np.roll(full.a, sy, 0), sx, 1)
            cv.tone[sh] = np.where(src_a[sh] < 100, 2, src_t[sh])  # cam kısmı parçada kalkan renginde
            cv.a[sh] = np.maximum(src_a[sh], 190)
            edge = sh & ~ero(sh)
            cv.put(edge, 5 if k < 0.3 else 0)
    cv.glow()
    return cv.rgba()


def debris_frames():
    """Yerdeki kırıklar: kırılmanın son karesiyle BİREBİR aynı başlar, sonra piksel piksel (Bayer) çözülür."""
    W, H = BREAK_CELL
    landed = shards(Cv(W, H), 1.0, 'all')
    x0 = int(BREAK_BODY[0] - DEBRIS_FEET[0])
    y0 = int(BREAK_BODY[1] + FEET_TO_BODY - DEBRIS_FEET[1])
    base = landed[y0:y0 + DEBRIS_CELL[1], x0:x0 + DEBRIS_CELL[0]].copy()
    assert base[:, :, 3].sum() == landed[:, :, 3].sum(), 'kırıklar debris hücresine sığmalı'
    dim = base.copy()
    dim[dim[:, :, 3] < 90] = 0  # parlak hale söner
    tone = np.rint(dim[:, :, 0] / float(TONE_STEP)).astype(int)
    tone = np.where(tone >= 3, tone - 1, tone)  # parlak tonlar bir kademe koyulaşır
    for c in range(3):
        dim[:, :, c] = np.where(dim[:, :, 3] > 0, tone * TONE_STEP, 0)
    out = [base, dim]
    return out


def strip(frames):
    return np.concatenate(frames, axis=1)


def ground_sheet():
    """Yenilenme mührü: TAM ve PARLAK hali. Dolan kısım / soluk kısım ayrımını shader yapar (progress, açıya göre)."""
    W, H = GROUND_CELL
    cv = Cv(W, H)
    gx, gy = GROUND_C
    rx, ry = GROUND_R
    band = cv.ell(gx, gy, rx + 1, ry + 1) & ~cv.ell(gx, gy, rx - 1, ry - 1)
    ring_in = cv.ell(gx, gy, rx - 4, ry - 2) & ~cv.ell(gx, gy, rx - 5, ry - 3)
    cv.put(outline(band) & ~ring_in, 0)
    cv.put(band, 2)
    cv.put(band & (cv.Y >= gy), 3)
    cv.put(ring_in, 3)
    for j in range(4):
        ga = math.pi / 2 + j * TAU / 4 + 0.4
        glyph(cv, RUNES[j], gx + (rx - 2.5) * math.cos(ga), gy + (ry - 1.5) * math.sin(ga), 4, 1)
    cv.glow()
    return cv.rgba()


def rise_frame(i, side):
    """Doldu: ayaktan başa tarayan halka (arka yarı karakterin ardında, ön yarı önünde)."""
    k = i / float(RISE_FRAMES - 1) * 0.999
    W, H = RISE_CELL
    cv = Cv(W, H)
    fx, fy = RISE_FEET
    yy = fy - RISE_H * ease_out(k)
    band = cv.ell(fx, yy, 15, 5.2) & ~cv.ell(fx, yy, 13.5, 4.0)
    if side == 'back':
        cv.put(band & (cv.Y < yy), 3)
    else:
        fr = band & (cv.Y >= yy)
        cv.put(outline(fr) & (cv.Y > yy) & ~band, 1)
        cv.put(fr, 4 if k < 0.5 else 3)
    cv.glow()
    cv.fade(1.0 - k)
    return cv.rgba()


# ------------------------------------------------------------------ önizleme (pişen sayfalarla, prototip sahnesinde)
PALS = {  # scripts/mana_shield_fx.gd PALETTES ile AYNI
    'Standart': [(14, 22, 70), (36, 70, 164), (74, 136, 232), (150, 204, 255), (228, 244, 255)],
    'Savaş': [(64, 8, 20), (146, 28, 40), (222, 68, 64), (255, 146, 124), (255, 230, 222)],
    'Enerji': [(70, 44, 4), (164, 112, 14), (236, 186, 36), (255, 226, 108), (255, 249, 212)],
    'Kale': [(34, 12, 64), (86, 38, 148), (146, 84, 214), (204, 156, 250), (244, 228, 255)],
}
CREAM, WHITE = (255, 250, 228), (255, 255, 255)


def colorize(rgba, pal, progress=None, center=None, radii=None):
    full = list(pal) + [CREAM, WHITE]
    tone = np.rint(rgba[:, :, 0].astype(np.float32) / TONE_STEP).astype(int)
    a = rgba[:, :, 3].astype(np.float32) / 255.0
    out = np.zeros((rgba.shape[0], rgba.shape[1], 4), np.float32)
    for k in range(7):
        m = tone == k
        out[m, :3] = full[k]
    out[:, :, 3] = a
    if progress is not None:
        h, w = tone.shape
        yy, xx = np.mgrid[0:h, 0:w]
        rel = (np.arctan2((yy + 0.5 - center[1]) / radii[1], (xx + 0.5 - center[0]) / radii[0]) - math.pi / 2) % TAU
        beyond = rel > progress * TAU
        out[beyond & (tone == 0), :3] = full[1]
        out[beyond & (tone != 0), :3] = full[3]
        out[beyond, 3] = np.where(a[beyond] < 0.4, 0.0, np.minimum(a[beyond], 0.32))
    return out


def blit(dst, src, x, y):
    x, y = int(round(x)), int(round(y))
    h, w = src.shape[:2]
    H, W = dst.shape[:2]
    x0, y0, x1, y1 = max(0, x), max(0, y), min(W, x + w), min(H, y + h)
    if x1 <= x0 or y1 <= y0:
        return
    s = src[y0 - y:y1 - y, x0 - x:x1 - x]
    a = s[:, :, 3:4]
    d = dst[y0:y1, x0:x1].astype(np.float32)
    dst[y0:y1, x0:x1] = (d * (1 - a) + s[:, :, :3] * a + 0.5).astype(np.uint8)


def preview(sheets):
    sys.path.insert(0, HERE)
    import gen_cadi_fx as G
    disc_s, brk_b, brk_f, grd, rise_b, rise_f, debris = sheets
    idle = G.load_game_sheet('assasin', 'idle')
    hurt = G.load_game_sheet('assasin', 'hurt')
    W, H, CX, FY = 100, 76, 50, 56
    BCY = FY - FEET_TO_BODY
    hits = [(0.6, math.pi), (1.5, 0.0), (2.4, -1.9)]  # sonuncusu kırar
    ticks = [5.9, 6.45, 7.0, 7.55]
    full_t = 7.95
    dur = 8.7
    ims = []
    names = list(PALS.keys())
    for f in range(int(dur * 20)):
        t = f / 20.0
        row = []
        for name in names:
            pal = PALS[name]
            dst = G.grass(W, H, seed=3)
            G.shadow(dst, CX, FY + 1, 8, 2.6)
            front = []
            # yenilenme mührü
            if ticks[0] <= t < full_t + 0.55:
                ti = max(i for i, x in enumerate(ticks) if t >= x)
                tage = t - ticks[ti]
                prog = (ti + (ease_out(tage / 0.25) if t < full_t else 1.0)) / len(ticks)
                g = colorize(grd, pal, prog, GROUND_C, GROUND_R)
                if t >= full_t:
                    g[:, :, 3] *= 1.0 - (t - full_t) / 0.55
                blit(dst, g, CX - GROUND_C[0], FY + 1 - GROUND_C[1])
            if full_t <= t < full_t + 0.55:
                i = min(RISE_FRAMES - 1, int((t - full_t) * 20))
                cw = RISE_CELL[0]
                blit(dst, colorize(rise_b[:, i * cw:(i + 1) * cw], pal), CX - RISE_FEET[0], FY - RISE_FEET[1])
                front.append((colorize(rise_f[:, i * cw:(i + 1) * cw], pal), CX - RISE_FEET[0], FY - RISE_FEET[1]))
            for (th_, a) in hits:
                age = t - th_
                if th_ == hits[-1][0]:
                    dage = age - BREAK_FRAMES / 20.0
                    if 0 <= dage < 2.6:
                        j = 0 if dage < 0.6 else 1
                        dw = DEBRIS_CELL[0]
                        dc = colorize(debris[:, j * dw:(j + 1) * dw], pal)
                        dc[:, :, 3] *= 1.0 - max(0.0, (dage - 1.0) / 1.6)
                        blit(dst, dc, CX - DEBRIS_FEET[0], FY - DEBRIS_FEET[1])
                    if 0 <= age < BREAK_FRAMES / 20.0:
                        i = int(age * 20)
                        cw = BREAK_CELL[0]
                        ox, oy = CX - BREAK_BODY[0], BCY - BREAK_BODY[1]
                        blit(dst, colorize(brk_b[:, i * cw:(i + 1) * cw], pal), ox, oy)
                        front.append((colorize(brk_f[:, i * cw:(i + 1) * cw], pal), ox, oy))
                    continue
                if 0 <= age < 0.6:
                    wcls = int(round((0.4 + 0.6 * abs(math.sin(a)) - 0.4) / 0.2))
                    col = 0 if age < 0.045 else 1 if age < 0.09 else 2 if age < 0.13 else 3 + int(age * 19) % DISC_ROT_FRAMES
                    cell = disc_s[wcls * DISC_CELL:(wcls + 1) * DISC_CELL, col * DISC_CELL:(col + 1) * DISC_CELL]
                    c = colorize(cell, pal)
                    c[:, :, 3] *= 1.0 - max(0.0, (age - 0.3) / 0.3)
                    ix, iy = CX + math.cos(a) * 15.0, BCY + math.sin(a) * 9.0
                    if math.sin(a) < -0.3:
                        blit(dst, c, ix - DISC_CELL / 2, iy - DISC_CELL / 2)
                    else:
                        front.append((c, ix - DISC_CELL / 2, iy - DISC_CELL / 2))
            fr = idle[0][int(t * 4) % 4]
            for (th_, a) in hits:
                if 0 <= t - th_ < 0.28:
                    fr = hurt[0][0 if t - th_ < 0.14 else 1]
            G.char_at(dst, fr, CX, FY)
            for (c, x, y) in front:
                blit(dst, c, x, y)
            row.append(dst)
        strip_im = np.concatenate(row, axis=1)
        im = G.up(strip_im, 3)
        for k, name in enumerate(names):
            G.label(im, k * W * 3 + 6, 4, name, 15)
        ims.append(im)
    G.save_gif(ims, os.path.join(HERE, 'proto_20261014', 'out', 'mana_muhur_onizleme.gif'), 50)


def main():
    os.makedirs(OUT, exist_ok=True)
    ds = disc_sheet()
    bb = strip([break_frame(i, 'back') for i in range(BREAK_FRAMES)])
    bf = strip([break_frame(i, 'front') for i in range(BREAK_FRAMES)])
    gs = ground_sheet()
    db = strip(debris_frames())
    rb = strip([rise_frame(i, 'back') for i in range(RISE_FRAMES)])
    rf = strip([rise_frame(i, 'front') for i in range(RISE_FRAMES)])
    for name, arr in (('disc', ds), ('break_back', bb), ('break_front', bf), ('ground', gs), ('rise_back', rb), ('rise_front', rf), ('debris', db)):
        # kenar taraması: hiçbir kare tuvalin kenarına değmemeli
        Image.fromarray(arr, 'RGBA').save(os.path.join(OUT, name + '.png'))
        print('  assets/fx/mana_shield/%s.png %dx%d' % (name, arr.shape[1], arr.shape[0]))
    border_check(ds, DISC_CELL, DISC_CELL, 'disc')
    border_check(bb, *BREAK_CELL, 'break_back')
    border_check(bf, *BREAK_CELL, 'break_front')
    border_check(rb, *RISE_CELL, 'rise_back')
    border_check(rf, *RISE_CELL, 'rise_front')
    border_check(gs, *GROUND_CELL, 'ground')
    border_check(db, *DEBRIS_CELL, 'debris')
    if '--onizleme' in sys.argv or True:
        preview((ds, bb, bf, gs, rb, rf, db))


def border_check(arr, cw, ch, name):
    for y0 in range(0, arr.shape[0], ch):
        for x0 in range(0, arr.shape[1], cw):
            c = arr[y0:y0 + ch, x0:x0 + cw, 3]
            if c[0].any() or c[-1].any() or c[:, 0].any() or c[:, -1].any():
                print('  UYARI: %s kare (%d,%d) kenara değiyor' % (name, x0 // cw, y0 // ch))


if __name__ == '__main__':
    main()
