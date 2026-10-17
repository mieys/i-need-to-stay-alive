"""MANA KALKANI - yeni görsel prototipler (kullanıcı 2026-10-14: "mana kalkanları için yeni prototipler üretir misin eskileri
referans almadan çalışma biçimine uygun bir şekilde. ama unutma bunlar sihirli kalkanlar").

Eski baloncuk/çatlak sanatına BAKILMADAN, kalkanın ÇALIŞMA BİÇİMİNDEN tasarlandı (shield_enchant_defs.gd + player.gd):
  - dolu dururken görünmez; hasarın bir KISMINI (%55-75) soğurur, kalanı cana geçer
  - yetenekler bu kalkandan harcar ("MANA K. YETERSİZ")
  - 0'a inince kırılır; hasardan sonra 6-8 sn bekler (Savaş beklemez), sonra SANİYEDE 1 TİK dolar
  - 4 tür = 4 renk (Standart mavi, Savaş kırmızı, Enerji yeşil, Kale turkuaz)

Dört aile, aynı zaman çizelgesi (darbe, darbe, yetenek, kırılma, bekleme, 4 tik yenilenme, doldu):
  A Rün Çemberi    - belde dönen rün halkası; halkanın UZUNLUĞU + yanan rün sayısı = kalan kalkan; darbe yönünde rünlü duvar
  B Mühür          - darbe yönünde beliren dönen büyü mührü (disk); kırılınca parçalanır; yenilenme = ayak altında çizilen mühür
  C Mana Örtüsü    - karakterin siluetini saran mana ışığı (her karakter/yön/animasyonda shader ile çalışır); tik = ışığın yükselmesi
  D Mana Kristalleri - etrafta dönen 4 kristal, her biri kalkanın 1/4'ü; içlerindeki mana seviyesi = kalan kalkan

    python -I tools/proto_20261014/mana_kalkan_proto.py   -> out/mana_kalkan_A-D.gif + out/mana_kalkan_renkler.png
Çizim karakter pikseli ölçeğinde (1 sanat px = 1 karakter pikseli, oyunda ~0,9 dünya birimi); büyütme x3.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, '..')))
import gen_cadi_fx as G  # noqa: E402

TAU = 2.0 * math.pi
W, H = 100, 80
CX, FY = 50, 58          # karakterin ayak noktası
BCY = FY - 15            # gövde merkezi
Z = 4
FPS = 10
DUR = 7.6
CREAM = (255, 250, 228)
WHITE = (255, 255, 255)

# [koyu kontur, koyu, orta, açık, parlak]
TYPES = [
    ('Standart', [(14, 22, 70), (36, 70, 164), (74, 136, 232), (150, 204, 255), (228, 244, 255)]),
    ('Savaş', [(64, 8, 20), (146, 28, 40), (222, 68, 64), (255, 146, 124), (255, 230, 222)]),
    ('Enerji', [(70, 44, 4), (164, 112, 14), (236, 186, 36), (255, 226, 108), (255, 249, 212)]),  # sarı (2026-10-14)
    ('Kale', [(34, 12, 64), (86, 38, 148), (146, 84, 214), (204, 156, 250), (244, 228, 255)]),  # mor (2026-10-14)
]
BOLT = [(90, 20, 12), (200, 60, 24), (255, 150, 60), (255, 230, 170)]

# ------------------------------------------------------------------ zaman çizelgesi (sn)
MAXS, MAXHP = 150.0, 200.0
HITS = [(0.75, math.pi), (1.65, 0.0), (3.35, -2.35)]  # (çarpma anı, saldırganın yönü: ekran açısı, y aşağı)
FLIGHT = 0.3
SPEND = (2.3, 2.9)
BREAK_T = HITS[2][0]
WAIT = (4.1, 4.6)
TICKS = [4.6, 5.15, 5.7, 6.25]
FULL_T = 6.65
FLARE = 0.6


def shield_at(t):
    s, hp = MAXS, MAXHP
    for (th, _a) in HITS:
        if t >= th:
            absorb = min(s, 80.0 * 0.65)
            s -= absorb
            hp -= 80.0 - absorb
    if t >= SPEND[0]:
        s -= 30.0 * min(1.0, (t - SPEND[0]) / (SPEND[1] - SPEND[0]))
    if t >= BREAK_T:
        s = 0.0
    for tk in TICKS:
        if t >= tk:
            s += MAXS / len(TICKS)
    return max(0.0, min(MAXS, s)), hp


def phase(t):
    if t < 0.45 or t >= 7.25:
        return 'DOLU - görünmez'
    if t < 2.25:
        return 'DARBE - hasarın %65\'ini soğurur'
    if t < 3.05:
        return 'YETENEK - kalkandan mana harcar'
    if t < WAIT[0]:
        return 'KIRILMA - kalkan bitti'
    if t < WAIT[1]:
        return 'BEKLEME (8 sn, kısaltıldı)'
    if t < FULL_T:
        return 'YENİLENME - saniyede 1 tik'
    return 'DOLDU - söner'


def last_event(t, times):
    """En son geçmiş olayın (indeks, yaş) çifti, yoksa (-1, büyük)."""
    best = (-1, 99.0)
    for i, x in enumerate(times):
        if t >= x:
            best = (i, t - x)
    return best


# ------------------------------------------------------------------ çizim yardımcıları
YY, XX = np.mgrid[0:H, 0:W]
PX, PY = XX + 0.5, YY + 0.5
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0)[YY % 4, XX % 4]


def layer():
    return np.zeros((H, W, 4), np.uint8)


def put(L, m, col, a=255):
    L[m, 0], L[m, 1], L[m, 2], L[m, 3] = col[0], col[1], col[2], a


def px(L, x, y, col, a=255):
    x, y = int(math.floor(x)), int(math.floor(y))
    if 0 <= x < W and 0 <= y < H:
        L[y, x] = (col[0], col[1], col[2], a)


def ell(cx, cy, rx, ry):
    return ((PX - cx) / max(rx, 0.01)) ** 2 + ((PY - cy) / max(ry, 0.01)) ** 2 <= 1.0


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


def poly(pts):
    im = Image.new('L', (W, H), 0)
    ImageDraw.Draw(im).polygon([(x, y) for (x, y) in pts], fill=255)
    return np.array(im) > 0


def comp(dst, L, alpha=1.0):
    """L'yi (RGBA) dst'nin üstüne basar; dst RGB (sahne) ya da RGBA (ön katman) olabilir."""
    if alpha <= 0.0:
        return
    a = L[:, :, 3:4].astype(np.float32) / 255.0 * alpha
    src = L[:, :, :3].astype(np.float32)
    if dst.shape[2] == 4:
        da = dst[:, :, 3:4].astype(np.float32) / 255.0
        oa = a + da * (1.0 - a)
        rgb = (src * a + dst[:, :, :3].astype(np.float32) * da * (1.0 - a)) / np.maximum(oa, 1e-6)
        dst[:, :, :3] = (rgb + 0.5).astype(np.uint8)
        dst[:, :, 3] = (oa[:, :, 0] * 255.0 + 0.5).astype(np.uint8)
        return
    dst[:] = (dst.astype(np.float32) * (1 - a) + src * a + 0.5).astype(np.uint8)


def star(L, x, y, size, core=WHITE, arm=None):
    arm = arm or core
    px(L, x, y, core)
    for k in range(1, size + 1):
        c = core if k < size else arm
        for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            px(L, x + dx, y + dy, c)


def glyph(L, rows, x, y, core, edge):
    """5 satırlık rün bitmap'i (x, y merkezli), 1 px koyu kontur."""
    h, w = len(rows), len(rows[0])
    m = np.zeros((H, W), bool)
    x0, y0 = int(round(x - w / 2.0)), int(round(y - h / 2.0))
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            if ch == '#' and 0 <= y0 + r < H and 0 <= x0 + c < W:
                m[y0 + r, x0 + c] = True
    put(L, outline(m), edge)
    put(L, m, core)


RUNES = [
    ['#.#.#', '.###.', '..#..', '..#..', '..#..'],
    ['#..', '##.', '#.#', '##.', '#..'],
    ['..#..', '.#.#.', '#.#.#', '..#..', '..#..'],
    ['#...#', '##.##', '#.#.#', '##.##', '#...#'],
    ['##.', '#.#', '##.', '#.#', '#.#'],
    ['.#.', '#.#', '.#.', '#.#', '#.#'],
]


def ease_out(x):
    x = min(1.0, max(0.0, x))
    return 1.0 - (1.0 - x) ** 3


def projectile(L, t, impact_pt):
    """Saldırganın mermisi: ekran dışından çarpma noktasına."""
    for (th, a) in HITS:
        k = (t - (th - FLIGHT)) / FLIGHT
        if 0.0 <= k < 1.0:
            ix, iy = impact_pt(a)
            sx, sy = ix + math.cos(a) * 70, iy + math.sin(a) * 50
            x, y = sx + (ix - sx) * k, sy + (iy - sy) * k
            dx, dy = (ix - sx), (iy - sy)
            n = math.hypot(dx, dy)
            dx, dy = dx / n, dy / n
            for j in range(6, 0, -1):
                px(L, x - dx * j, y - dy * j, BOLT[1] if j > 3 else BOLT[2])
            put(L, ell(x, y, 2.2, 2.2), BOLT[1])
            put(L, ell(x, y, 1.4, 1.4), BOLT[2])
            px(L, x, y, BOLT[3])


def sparks(L, pt, a, age, pal, n=4, reach=9.0, seed=0):
    """Çarpma kıvılcımları: çoğu saldırgana geri seker (soğurulan kısım), 2 küçük turuncu kıvılcım içeri geçer (cana geçen kısım)."""
    if age < 0.0 or age > 0.35:
        return
    k = age / 0.35
    for i in range(n):
        da = (i - (n - 1) / 2.0) * 0.55 + math.sin(seed * 3.1 + i) * 0.15
        d = reach * ease_out(k) * (0.7 + 0.3 * ((i * 7 + seed) % 3) / 2.0)
        x, y = pt[0] + math.cos(a + da) * d, pt[1] + math.sin(a + da) * d * 0.8
        tail = max(1, int(3 * (1 - k)))
        for j in range(tail):
            px(L, x - math.cos(a + da) * j, y - math.sin(a + da) * j * 0.8, CREAM if j == 0 and k < 0.5 else pal[3])
    for i in range(2):
        d = 6.0 * ease_out(k)
        b = a + math.pi + (i - 0.5) * 0.5
        px(L, pt[0] + math.cos(b) * d, pt[1] + math.sin(b) * d * 0.8, BOLT[2] if k < 0.6 else BOLT[1])


def impact_flash(L, pt, age, pal, r=4.0):
    if age < 0.0 or age > 0.18:
        return
    k = age / 0.18
    rr = r * (0.6 + 0.6 * k)
    m = ell(pt[0], pt[1], rr, rr * 0.9)
    if k < 0.45:
        put(L, outline(m), pal[3])
        put(L, m, CREAM)
    else:
        put(L, m & ~ell(pt[0] + 1, pt[1], rr - 1.4, rr * 0.9 - 1.4), pal[4])


# ------------------------------------------------------------------ A: Rün Çemberi
class RuneRing:
    name = 'A  Rün Çemberi'
    RCY = FY - 11
    RX, RY = 19.0, 6.5

    def impact_pt(self, a):
        return CX + self.RX * math.cos(a), self.RCY + self.RY * math.sin(a) - 7

    def _band(self, cx, cy, sx, frac, start, taper=True):
        rx, ry = self.RX * sx, self.RY * sx
        band = ell(cx, cy, rx + 1.0, ry + 1.0) & ~ell(cx, cy, rx - 1.0, ry - 1.0)
        th = np.arctan2((PY - cy) / ry, (PX - cx) / rx)
        rel = (th - start) % TAU
        span = TAU * frac
        m = band & (rel <= span)
        if taper and frac < 0.999:  # baş ve kuyruk 1 px'e incelir (keskin bitiş yok)
            thin = (rel < 0.2) | (rel > span - 0.28)
            core = ell(cx, cy, rx + 0.4, ry + 0.4) & ~ell(cx, cy, rx - 0.4, ry - 0.4)
            m &= ~thin | core
        return m, th

    def draw(self, back, front, t, st, pal, char_mask):
        s, _hp = st
        frac = s / MAXS
        rot = t * 1.4
        cx, cy = CX, self.RCY
        vis, sx, lift, flash, spin = 0.0, 1.0, 0.0, 0.0, 0.0
        hi, hage = last_event(t, [h[0] for h in HITS])
        ti, tage = last_event(t, TICKS)
        arc = 1.0
        if hi >= 0 and hage < FLARE and hi < 2:
            vis = 1.0 - max(0.0, (hage - 0.35) / 0.25)
        if SPEND[0] - 0.1 <= t < SPEND[1] + 0.25:
            vis = max(vis, 1.0 - max(0.0, (t - SPEND[1]) / 0.25))
            rot += (min(t, SPEND[1]) - SPEND[0]) * 9.0
            spin = 1.0
        if TICKS[0] <= t < FULL_T + 0.6:
            vis = 1.0
            if t >= FULL_T:
                k = (t - FULL_T) / 0.6
                lift = -10.0 * ease_out(k)
                vis = 1.0 - k
                flash = max(0.0, 1.0 - k * 4)
        cy += lift
        # kırılma: halka 6 parçaya ayrılıp dışa açılır ve düşer, rünler döküler
        bage = t - BREAK_T
        if 0.0 <= bage < 0.75:
            k = bage / 0.75
            L = layer()
            for i in range(6):
                a0 = i * TAU / 6 + rot
                ex = 1.0 + 0.55 * ease_out(k)
                ox, oy = math.cos(a0 + 0.52) * 6 * ease_out(k), 18 * k * k
                m, th = self._band(cx + ox, cy + oy, ex, 1.0, 0.0, taper=False)
                m &= ang_d(th, a0 + 0.52) < 0.4 - 0.25 * k
                put(L, outline(m), pal[0])
                put(L, m, CREAM if k < 0.12 else pal[2 if k > 0.5 else 3])
                rx, ry = self.RX * ex, self.RY * ex
                gx, gy = cx + ox + rx * math.cos(a0 + 0.52), cy + oy + ry * math.sin(a0 + 0.52) - 3
                if (int(t * 20) + i) % 3 or k < 0.5:
                    glyph(L, RUNES[i], gx, gy + 10 * k * k, pal[4] if k < 0.5 else pal[3], pal[0])
            comp(front, L, 1.0 - max(0.0, (k - 0.6) / 0.4))
            ip = self.impact_pt(HITS[2][1])
            impact_flash(front, ip, bage, pal, 6)
            sparks(front, ip, HITS[2][1], bage, pal, n=6, reach=13, seed=3)
            return
        if vis <= 0.0:
            self._wall(front, t, pal)
            return
        start = math.pi * 0.5 - TAU * arc * 0.5
        m, th = self._band(cx, cy, 1.0, arc, start)
        lb, lf = layer(), layer()
        for L, side in ((lb, PY < cy), (lf, PY >= cy)):
            mm = m & side
            put(L, outline(mm) & ~m, pal[0])
            put(L, mm, pal[2])
            put(L, mm & ~ell(cx, cy + 1, self.RX + 1.0, self.RY + 1.0), pal[3])
            if flash > 0:
                put(L, mm, CREAM)
        put(lf, m & (PY >= cy) & ~ell(cx, cy - 1, self.RX + 1.0, self.RY + 1.0) & (ang_d(th, math.pi / 2) < 0.22), pal[4])
        # rünler: halka uzunluğu boyunca, sayısı kalan kalkanla
        n_lit = int(math.ceil(frac * 6 - 1e-6))
        for i in range(6):
            a = rot + i * TAU / 6
            rel = (a - start) % TAU
            if rel > TAU * arc:
                continue
            gx, gy = cx + self.RX * math.cos(a), cy + self.RY * math.sin(a) - 3
            behind = math.sin(a) < 0
            fresh = ti >= 0 and tage < 0.18 and i == n_lit - 1 and t < FULL_T
            lit = i < n_lit
            if lit:
                core = CREAM if (fresh or flash > 0) else (pal[3] if behind else pal[4])
            else:  # sönmüş rün: koyu yuva
                core = pal[1] if not behind else pal[0]
            glyph(lb if behind else lf, RUNES[i], gx, gy, core, pal[0] if not behind else pal[1])
            if fresh:
                star(lf, gx, gy - 5, 2, WHITE, pal[4])
            if not lit and hi >= 0 and hi < 2 and hage < 0.25 and i in (n_lit, n_lit + 1):
                star(lb if behind else lf, gx, gy, 1, CREAM, pal[3])
        if spin:  # harcanan mana halkadan yukarı süzülür
            for j in range(5):
                k = ((t - SPEND[0]) * 2.2 + j / 5.0) % 1.0
                a = rot * 0.5 + j * 1.3
                x = cx + self.RX * math.cos(a) * (1 - k)
                y = cy + self.RY * math.sin(a) * (1 - k) - 26 * k
                px(lf, x, y, pal[4] if k < 0.6 else pal[3])
                px(lf, x, y + 1, pal[2])
        comp(back, lb, vis)
        comp(front, lf, vis)
        self._wall(front, t, pal)

    def _wall(self, front, t, pal):
        """Darbe yönünde halkadan yükselen rünlü duvar parçası."""
        for (th_, a) in HITS:
            age = t - th_
            if age < 0.0 or age > 0.55:
                continue
            k = age / 0.55
            hgt = 15.0 * (1.0 - 0.35 * k)
            span = 0.55 if abs(math.sin(a)) > 0.5 else 0.42
            L = layer()
            m = np.zeros((H, W), bool)
            for hh in range(int(hgt)):
                rb = ell(CX, self.RCY - hh, self.RX + 0.5, self.RY + 0.5) & ~ell(CX, self.RCY - hh, self.RX - 0.5, self.RY - 0.5)
                tha = np.arctan2((PY - (self.RCY - hh)) / self.RY, (PX - CX) / self.RX)
                taper = span * (1.0 - (hh / hgt) ** 3)
                m |= rb & (ang_d(tha, a) < taper)
            if abs(math.sin(a)) < 0.5:  # yandan gelen darbede duvar yandan görünür: kalınlaştır
                m = dil(dil(m))
            put(L, m, pal[2], 150)
            put(L, outline(m), pal[3] if k > 0.2 else CREAM)
            put(L, m & ~dil(~m) & (PY < self.RCY - hgt * 0.5), pal[4], 200)
            ix, iy = self.impact_pt(a)
            glyph(L, RUNES[(int(th_ * 10)) % 6], ix, iy, CREAM if k < 0.3 else pal[4], pal[1])
            comp(front, L, 1.0 - max(0.0, (k - 0.5) / 0.5))
            if th_ != BREAK_T:
                impact_flash(front, (ix, iy), age, pal)
            sparks(front, (ix, iy), a, age, pal, seed=int(th_ * 10))


# ------------------------------------------------------------------ B: Mühür
class Sigil:
    name = 'B  Mühür'
    R = 10.5

    def impact_pt(self, a):
        return CX + math.cos(a) * 15.0, BCY + math.sin(a) * 9.0

    def _disc(self, L, cx, cy, a, sc, rot, pal, cracked=0.0, face_cam=False):
        R = self.R * sc
        if R < 1.0:
            return None
        rx = R if face_cam else R * (0.4 + 0.6 * abs(math.sin(a)))
        ry = R
        u, v = (PX - cx) / rx, (PY - cy) / ry
        rho = np.sqrt(u * u + v * v)
        th = np.arctan2(v, u)
        disc = rho <= 1.0
        put(L, disc, pal[1], 110)  # yarı saydam büyü camı
        ring = disc & ~ero(ero(disc))
        put(L, outline(disc), pal[0])
        put(L, ring, pal[2])
        put(L, ring & (v < -0.2), pal[3])
        inner = rho <= 0.6
        put(L, inner & ~ero(inner), pal[3])
        ticks = (rho > 0.66) & (rho < 0.84) & (ang_d((th - rot) * 4.0 % TAU, 0.0) < 0.55)
        put(L, ticks & disc, pal[4])
        dia = (np.abs(np.cos(rot) * u + np.sin(rot) * v) + np.abs(-np.sin(rot) * u + np.cos(rot) * v)) < 0.36
        put(L, dia, pal[4])
        put(L, (np.abs(u) + np.abs(v)) < 0.14, CREAM)
        if cracked > 0:
            for j in range(4):
                ca = j * 1.7 + 0.4
                for r in np.linspace(0, cracked, 8):
                    jit = math.sin(r * 9 + j) * 0.12
                    px(L, cx + math.cos(ca + jit) * r * rx, cy + math.sin(ca + jit) * r * ry, CREAM)
        return disc, th, rx, ry

    def draw(self, back, front, t, st, pal, char_mask):
        s, _hp = st
        # darbede mühür
        for (th_, a) in HITS:
            age = t - th_
            if age < -0.04 or age > 0.6:
                continue
            ix, iy = self.impact_pt(a)
            L = layer()
            tgt = back if math.sin(a) < -0.3 else front
            if th_ == BREAK_T:
                if age < 0.2:
                    self._disc(L, ix, iy, a, ease_out((age + 0.04) / 0.1), t * 6, pal, cracked=min(1.0, max(0.0, age - 0.05) / 0.12))
                    comp(tgt, L)
                else:  # 7 parçaya ayrılır
                    k = (age - 0.2) / 0.4
                    full = layer()
                    disc, th, rx, ry = self._disc(full, ix, iy, a, 1.0, t * 6, pal)
                    for j in range(7):
                        wa = j * TAU / 7
                        wedge = disc & (ang_d(th, wa) < TAU / 14 - 0.05)
                        dx = math.cos(wa) * rx * 0.9 * ease_out(k) + math.cos(a) * 6 * k
                        dy = math.sin(wa) * ry * 0.9 * ease_out(k) + 14 * k * k
                        sh = np.roll(np.roll(wedge, int(round(dy)), 0), int(round(dx)), 1)
                        src = np.roll(np.roll(full, int(round(dy)), 0), int(round(dx)), 1)
                        L[sh] = src[sh]
                        L[sh & ~ero(sh), :3] = pal[0] if k > 0.3 else CREAM
                    comp(front, L, 1.0 - k)
                impact_flash(front, (ix, iy), age, pal, 7)
                sparks(front, (ix, iy), a, age, pal, n=6, reach=14, seed=3)
                continue
            if age < 0:
                continue
            sc = ease_out(age / 0.09) * (1.0 - 0.2 * max(0.0, (age - 0.3) / 0.3))
            self._disc(L, ix, iy, a, sc, t * 5, pal)
            if age < 0.07:
                put(L, L[:, :, 3] > 0, CREAM)
            comp(tgt, L, 1.0 - max(0.0, (age - 0.3) / 0.3))
            impact_flash(front, (ix, iy), age, pal)
            sparks(front, (ix, iy), a, age, pal, seed=int(th_ * 10))
        # yetenek: elin önünde küçük mühür döner, söner
        if SPEND[0] <= t < SPEND[1] + 0.2:
            k = (t - SPEND[0]) / (SPEND[1] - SPEND[0])
            L = layer()
            sc = 0.6 * ease_out(min(1.0, k * 4))
            self._disc(L, CX + 9, BCY - 6, 1.57, sc, t * 9, pal, face_cam=True)
            comp(front, L, 1.0 - max(0.0, (t - SPEND[1]) / 0.2))
        # yenilenme: ayak altında mühür çember çizilir; doldu: halka bedenden yukarı tarar
        if TICKS[0] <= t < FULL_T + 0.55:
            ti, tage = last_event(t, TICKS)
            frac = (ti + (ease_out(tage / 0.25) if t < FULL_T else 1.0)) / len(TICKS)
            gx, gy, rx, ry = CX, FY + 1, 17.0, 6.0
            L = layer()
            band = ell(gx, gy, rx + 1, ry + 1) & ~ell(gx, gy, rx - 1, ry - 1)
            th = np.arctan2((PY - gy) / ry, (PX - gx) / rx)
            rel = (th - math.pi / 2) % TAU
            m = band & (rel <= TAU * frac)
            ring_in = ell(gx, gy, rx - 4, ry - 2) & ~ell(gx, gy, rx - 5, ry - 3)
            inner = ring_in & (rel <= TAU * frac)
            alpha_g = 1.0
            if t >= FULL_T:
                alpha_g = 1.0 - (t - FULL_T) / 0.55
            put(L, band | ring_in, pal[1], 150)  # mührün tamamı soluk görünür
            put(L, outline(band) & ~ring_in, pal[0], 150)
            put(L, outline(m), pal[0])
            put(L, m, pal[2])
            put(L, m & (PY >= gy), pal[3])
            put(L, inner, pal[3])
            for j in range(4):
                ga = math.pi / 2 + j * TAU / 4 + 0.4
                if (ga - math.pi / 2) % TAU <= TAU * frac:
                    glyph(L, RUNES[j], gx + (rx - 2.5) * math.cos(ga), gy + (ry - 1.5) * math.sin(ga), pal[4], pal[1])
            if t < FULL_T and tage < 0.3:
                ha = math.pi / 2 + TAU * frac
                star(L, gx + rx * math.cos(ha), gy + ry * math.sin(ha), 2, WHITE, pal[4])
                for j in range(3):  # tikte yükselen ışık taneleri
                    ra = ha - 0.5 * j
                    px(L, gx + rx * math.cos(ra), gy + ry * math.sin(ra) - 22 * tage - 2 * j, pal[4])
            comp(back, L, alpha_g)
            if t >= FULL_T:
                k = (t - FULL_T) / 0.55
                yy = FY - 36 * ease_out(k)
                band2 = ell(CX, yy, 15, 5.2) & ~ell(CX, yy, 13.5, 4.0)
                lb, lf = layer(), layer()
                put(lb, band2 & (PY < yy), pal[3])
                put(lf, band2 & (PY >= yy), pal[4] if k < 0.5 else pal[3])
                put(lf, outline(band2 & (PY >= yy)) & (PY > yy), pal[1])
                comp(back, lb, 1.0 - k)
                comp(front, lf, 1.0 - k)


# ------------------------------------------------------------------ C: Mana Örtüsü
class Veil:
    name = 'C  Mana Örtüsü'

    def impact_pt(self, a):
        return CX + math.cos(a) * 9.0, BCY + math.sin(a) * 15.0

    def draw(self, back, front, t, st, pal, char_mask):
        s, _hp = st
        o1 = outline(char_mask)
        o2 = outline(char_mask | o1)
        ang = np.arctan2(PY - BCY, PX - CX)
        hf = np.clip((FY + 1 - PY) / 34.0, 0.0, 1.0)
        I = np.zeros((H, W))
        cover = np.ones((H, W), bool)
        hi, hage = last_event(t, [h[0] for h in HITS])
        ti, tage = last_event(t, TICKS)
        vis = 0.0
        if hi >= 0 and hi < 2 and hage < FLARE:
            a = HITS[hi][1]
            vis = 1.0 - max(0.0, (hage - 0.3) / 0.3)
            d = ang_d(ang, a)
            I = 0.45 + 0.55 * np.clip(1.0 - d / 1.2, 0, 1)
            wave = np.exp(-((d - 5.0 * hage) / 0.45) ** 2) * (1.0 - hage / FLARE)
            I = np.maximum(I, 0.5 + 0.5 * wave)
        if SPEND[0] - 0.05 <= t < SPEND[1] + 0.2:
            vis = max(vis, 1.0 - max(0.0, (t - SPEND[1]) / 0.2))
            I = np.maximum(I, 0.55 + 0.25 * np.sin(t * 30 + PX * 0.6))
        if TICKS[0] <= t < FULL_T + 0.5:
            frac = s / MAXS
            if t < FULL_T and tage < 0.25:
                frac = (ti + ease_out(tage / 0.25)) / len(TICKS)
            vis = 1.0
            crest = np.abs(hf - frac) < 0.06
            I = np.where(crest, 1.0, 0.62 + (0.25 * max(0.0, 1.0 - tage / 0.3) if t < FULL_T else 0.0))
            cover = hf <= frac + 0.03
            if t >= FULL_T:
                k = (t - FULL_T) / 0.5
                I[:] = 1.0 if k < 0.25 else 0.8
                vis = 1.0 - k
                cover[:] = True
        L = layer()
        bage = t - BREAK_T
        if 0.0 <= bage < 0.75:  # siluet ışığı parçalanıp taneler halinde dağılır
            k = bage / 0.75
            if k < 0.1:
                put(L, o1, CREAM)
                put(L, o2, pal[3])
            ys, xs = np.nonzero(o1)
            for j in range(0, len(ys), 2):
                x, y = xs[j] + 0.5, ys[j] + 0.5
                dx, dy = x - CX, y - BCY
                n = math.hypot(dx, dy) + 0.01
                sp = 10.0 + (j * 37 % 9)
                nx, ny = x + dx / n * sp * ease_out(k), y + dy / n * sp * ease_out(k) * 0.7 - 8 * k
                if (j // 2) % 3 != 0 and k > 0.15:
                    continue
                if BAYER[min(H - 1, max(0, int(ny))), min(W - 1, max(0, int(nx)))] > k * 0.8:
                    put(L, ell(nx, ny, 1.1, 1.1), pal[3] if k < 0.4 else pal[2])
                    px(L, nx, ny, CREAM if k < 0.3 else pal[4])
            comp(front, L)
            ix, iy = self.impact_pt(HITS[2][1])
            impact_flash(front, (ix, iy), bage, pal, 6)
            sparks(front, (ix, iy), HITS[2][1], bage, pal, n=6, reach=12, seed=3)
            return
        if vis > 0.0:
            m1 = o1 & cover
            put(L, m1 & (I > 0.0), pal[2])
            put(L, m1 & (I > 0.55), pal[3])
            put(L, m1 & (I > 0.8), pal[4])
            put(L, m1 & (I > 0.96), CREAM)
            m2 = o2 & cover & (BAYER < (I - 0.35) * 1.4)
            put(L, m2, pal[2], 170)
            # tepe kenarından yükselen küçük mana alevleri
            top_pix = m1 & ~np.roll(char_mask | o1, 1, 0) & (PY < FY - 12)
            ys, xs = np.nonzero(top_pix)
            for j in range(len(xs)):
                x, y = xs[j], ys[j]
                hh = int(1.5 + 2.5 * (0.5 + 0.5 * math.sin(t * 9 + x * 1.7))) if (x + int(t * 6)) % 3 == 0 else 0
                for q in range(1, hh + 1):
                    px(L, x, y - q, pal[4] if q == hh else pal[3], 220)
            if SPEND[0] <= t < SPEND[1]:  # harcanan mana baştan yukarı süzülür
                for j in range(5):
                    k = ((t - SPEND[0]) * 2.4 + j / 5.0) % 1.0
                    px(L, CX - 4 + j * 2 + math.sin(t * 8 + j) * 2, FY - 34 - 16 * k, pal[4] if k < 0.5 else pal[3])
            if TICKS[0] <= t < FULL_T and tage < 0.4:  # tik: taneler dışarıdan bedene akar
                for j in range(7):
                    a = j * TAU / 7 + ti * 0.7
                    k = ease_out(tage / 0.4) if tage < 0.4 else 1.0
                    r = 26.0 * (1.0 - k) + 8.0
                    x, y = CX + math.cos(a) * r, BCY + math.sin(a) * r * 0.75
                    px(L, x, y, pal[4])
                    px(L, x + math.cos(a), y + math.sin(a) * 0.75, pal[2])
            comp(front, L, vis)
        for (th_, a) in HITS[:2]:
            age = t - th_
            ix, iy = self.impact_pt(a)
            if 0.0 <= age < 0.3:
                g = layer()
                star(g, ix, iy, 3 if age < 0.12 else 2, CREAM, pal[4])
                comp(front, g)
            impact_flash(front, (ix, iy), age, pal, 3)
            sparks(front, (ix, iy), a, age, pal, seed=int(th_ * 10))


# ------------------------------------------------------------------ D: Mana Kristalleri
class Crystals:
    name = 'D  Mana Kristalleri'
    N = 4
    ORX, ORY = 17.0, 6.0
    OCY = FY - 15

    def impact_pt(self, a):
        return CX + math.cos(a) * 15.0, BCY + math.sin(a) * 9.0

    def _crystal(self, L, x, y, sc, lv, pal, dim=False, flash=False):
        hw, hh = 3.0 * sc, 5.6 * sc
        if hw < 0.6:
            return
        m = poly([(x, y - hh), (x + hw, y), (x, y + hh), (x - hw, y)])
        if not m.any():
            px(L, x, y, pal[4])
            return
        put(L, outline(m), pal[0])
        level_y = y + hh - 2 * hh * lv
        full = m & (PY >= level_y)
        put(L, m, pal[1], 200)  # boş kısım: koyu, yarı saydam cam
        put(L, full & (PX < x), pal[3] if not dim else pal[2])
        put(L, full & (PX >= x), pal[2] if not dim else pal[1])
        put(L, full & (PX < x) & (PY < y) & (PX > x - hw * 0.6), pal[4])
        if lv < 0.98:
            put(L, m & (np.abs(PY - level_y) < 0.5), pal[4])
        if flash:
            put(L, m, CREAM)

    def _shatter(self, L, x, y, age, pal, big=False):
        if age < 0.0 or age > 0.55:
            return
        k = age / 0.55
        for j in range(6 if big else 5):
            a = j * TAU / (6 if big else 5) + 0.3
            d = (12.0 if big else 8.0) * ease_out(k)
            sx, sy = x + math.cos(a) * d, y + math.sin(a) * d * 0.8 + 8 * k * k
            m = poly([(sx, sy - 1.6), (sx + 1.2, sy + 1.0), (sx - 1.2, sy + 1.0)])
            put(L, m, pal[3] if k < 0.5 else pal[2])
            if k < 0.4:
                px(L, sx, sy, CREAM)
        if k < 0.25:
            put(L, ell(x, y, 3 + 6 * k, 3 + 6 * k) & ~ell(x, y, 2 + 6 * k, 2 + 6 * k), CREAM)
        if big and k < 0.6:
            r = 6 + 20 * ease_out(k)
            put(L, ell(x, y + 6, r, r * 0.35) & ~ell(x, y + 6, r - 1.2, r * 0.35 - 1.0), pal[3])

    def draw(self, back, front, t, st, pal, char_mask):
        s, _hp = st
        per = MAXS / self.N
        rot = t * 1.3
        vis = min(1.0, max(0.0, (t - (HITS[0][0] - 0.2)) / 0.1))
        if t >= FULL_T:
            k = (t - FULL_T) / 0.6
            rot += 6 * ease_out(min(1.0, k)) if k < 1 else 6
            vis = max(0.0, 1.0 - max(0.0, (k - 0.3) / 0.7))
        lb, lf = layer(), layer()
        ti, tage = last_event(t, TICKS)
        events = []  # (zaman, kristal indeksi, tür)
        # her darbede EN SON dolu kristal yakalamaya fırlar; boşalan parçalanır
        for (th_, a) in HITS:
            before, _ = shield_at(th_ - 1e-4)
            after, _ = shield_at(th_ + 1e-4)
            idx = max(0, int(math.ceil(before / per)) - 1)
            events.append((th_, a, idx, before, after))
        catcher = {}
        for (th_, a, idx, before, after) in events:
            age = t - th_
            if -0.12 <= age < 0.45:
                catcher[idx] = (age, a, after <= idx * per + 1e-3, th_ == BREAK_T)
        for i in range(self.N):
            lv = min(1.0, max(0.0, s / per - i))
            a = rot + i * TAU / self.N
            x = CX + self.ORX * math.cos(a)
            y = self.OCY + self.ORY * math.sin(a) + math.sin(t * 3.0 + i * 1.7) * 1.0
            behind = math.sin(a) < 0
            sc, flash = 1.0, False
            if i in catcher:
                age, ha, shatters, big = catcher[i]
                ix, iy = self.impact_pt(ha)
                k = ease_out((age + 0.12) / 0.12) if age < 0 else 1.0
                if age >= 0 and shatters:
                    self._shatter(lf, ix, iy, age, pal, big=big)
                    sparks(lf, (ix, iy), ha, age, pal, n=6 if big else 4, reach=12 if big else 9, seed=i)
                    continue
                if age > 0.2:
                    k = 1.0 - ease_out((age - 0.2) / 0.25)
                x, y = x + (ix - x) * k, y + (iy - y) * k
                behind = False
                flash = 0 <= age < 0.08
                if 0 <= age < 0.3:
                    impact_flash(lf, (ix, iy), age, pal)
                    sparks(lf, (ix, iy), ha, age, pal, seed=i)
            if lv <= 0.0:
                if i == 1 and SPEND[0] <= t < SPEND[1] + 0.25:  # yetenek bu kristali boşalttı: boş kabuk sönerek kaybolur
                    sc = 1.0 - max(0.0, (t - SPEND[1]) / 0.25)
                    self._crystal(lb if behind else lf, x, y, sc, 0.0, pal, dim=behind)
                continue
            if ti >= 0 and i == ti and tage < 0.4 and t < FULL_T:
                if tage < 0.25:
                    for j in range(5):
                        b = j * TAU / 5
                        r = 9.0 * (1.0 - tage / 0.25)
                        px(lf, x + math.cos(b) * r, y + math.sin(b) * r * 0.8, pal[4])
                    continue
                sc = ease_out((tage - 0.25) / 0.15)
                flash = tage < 0.32
            if t >= FULL_T and (t - FULL_T) < 0.12:
                flash = True
            self._crystal(lb if behind else lf, x, y, sc, lv, pal, dim=behind, flash=flash)
            if not behind and lv > 0.99 and int(t * 4 + i) % 6 == 0:
                px(lf, x - 1, y - 2, WHITE)
        # yetenek: dolu olmayan kristalden mana ele akar
        if SPEND[0] <= t < SPEND[1]:
            for j in range(4):
                k = ((t - SPEND[0]) * 2.5 + j / 4.0) % 1.0
                i = 1
                a = rot + i * TAU / self.N
                x0, y0 = CX + self.ORX * math.cos(a), self.OCY + self.ORY * math.sin(a)
                x1, y1 = CX + 6, BCY - 4
                px(lf, x0 + (x1 - x0) * k, y0 + (y1 - y0) * k - math.sin(k * math.pi) * 5, pal[4])
        # kırılmadan sonra dağılan son kristal (catcher zaten çizdi), yenilenmede 4 kristal tek tek doğar
        comp(back, lb, vis)
        comp(front, lf, vis)


FAMILIES = [RuneRing(), Sigil(), Veil(), Crystals()]


# ------------------------------------------------------------------ sahne
def char_frame(sheets, t):
    idle, hurt, strike = sheets
    for (th_, _a) in HITS:
        if 0.0 <= t - th_ < 0.28:
            return hurt[0][0 if t - th_ < 0.14 else 1]
    if SPEND[0] <= t < SPEND[1]:
        return strike[0][min(3, int((t - SPEND[0]) / (SPEND[1] - SPEND[0]) * 4))]
    return idle[0][int(t * 4) % 4]


def glow(L, pal):
    """Sihir parıltısı: kalkan piksellerinin çevresine 1 px yumuşak, açık renk hale (oyunda: katman altına aynı sprite'ın
    büyütülmüş + saydam kopyası ya da add blend)."""
    m = L[:, :, 3] > 90
    if not m.any():
        return
    h1 = dil(m) & ~m & (L[:, :, 3] == 0)
    h2 = dil(dil(m)) & ~dil(m) & (L[:, :, 3] == 0) & (BAYER < 0.5)
    put(L, h1, pal[3], 70)
    put(L, h2, pal[3], 38)


def bars(dst, st, pal):
    s, hp = st
    x0, y0, w = CX - 22, H - 9, 44
    for row, (val, mx, col, dark) in enumerate(((s, MAXS, pal[2], pal[0]), (hp, MAXHP, (214, 52, 52), (70, 14, 14)))):
        y = y0 + row * 4
        dst[y - 1:y + 3, x0 - 1:x0 + w + 1] = (20, 22, 26)
        dst[y:y + 2, x0:x0 + w] = dark
        fw = int(round(w * val / mx))
        if fw > 0:
            dst[y:y + 2, x0:x0 + fw] = col
            dst[y, x0:x0 + fw] = tuple(min(255, int(c * 1.25 + 20)) for c in col)


def scene(fam, t, sheets, pal, with_bars=True):
    """Zemin -> kalkanın arka yüzü -> karakter -> kalkanın ön yüzü -> mermi -> göstergeler."""
    base = G.grass(W, H, seed=3)
    G.shadow(base, CX, FY + 1, 8, 2.6)
    frame = char_frame(sheets, t)
    cm = np.zeros((H, W), bool)
    cm[FY - 40:FY + 8, CX - 24:CX + 24] = frame[:, :, 3] > 0
    st = shield_at(t)
    back, front = layer(), layer()
    fam.draw(back, front, t, st, pal, cm)
    glow(back, pal)
    comp(base, back)
    G.char_at(base, frame, CX, FY)
    glow(front, pal)
    comp(base, front)
    proj = layer()
    projectile(proj, t, fam.impact_pt)
    comp(base, proj)
    if with_bars:
        bars(base, st, pal)
    return base


def load_sheets():
    k = 'assasin'
    return G.load_game_sheet(k, 'idle'), G.load_game_sheet(k, 'hurt'), G.load_game_sheet(k, 'strike')


def grid_frame(t, sheets, pal_i=0):
    pal = TYPES[pal_i][1]
    cw, ch = W * Z, H * Z
    head = 30
    im = Image.new('RGB', (cw * 2, ch * 2 + head), (24, 30, 22))
    for i, fam in enumerate(FAMILIES):
        sc = scene(fam, t, sheets, pal)
        tile = G.up(sc, Z)
        x, y = (i % 2) * cw, head + (i // 2) * ch
        im.paste(tile, (x, y))
        G.label(im, x + 8, y + 6, fam.name, 17)
    d = ImageDraw.Draw(im)
    d.line([(cw, head), (cw, head + ch * 2)], fill=(24, 30, 22), width=2)
    d.line([(0, head + ch), (cw * 2, head + ch)], fill=(24, 30, 22), width=2)
    G.label(im, 10, 6, phase(t), 16, (255, 236, 160))
    G.label(im, cw * 2 - 260, 6, 'Standart (mavi)  -  x4', 14, (200, 220, 255))
    return im


def colour_sheet(sheets):
    """Her ailenin aynı anı (yenilenme ortası + darbe) 4 kalkan türü renginde."""
    moments = [1.85, 0.98, 1.0, 6.0]  # aileye göre en açıklayıcı an
    cx0, cy0, cw, chh = CX - 32, FY - 50, 64, 62
    z = 3
    pad = 26
    im = Image.new('RGB', (pad + 4 * cw * z, pad + 4 * chh * z), (24, 30, 22))
    for r, fam in enumerate(FAMILIES):
        for c, (tname, pal) in enumerate(TYPES):
            sc = scene(fam, moments[r], sheets, pal, with_bars=False)[cy0:cy0 + chh, cx0:cx0 + cw]
            im.paste(G.up(sc, z), (pad + c * cw * z, pad + r * chh * z))
            if r == 0:
                G.label(im, pad + c * cw * z + 8, 4, tname, 15)
        G.label(im, pad + 6, pad + r * chh * z + 4, fam.name[:1], 16)
    return im


def main():
    out = os.path.join(HERE, 'out')
    os.makedirs(out, exist_ok=True)
    sheets = load_sheets()
    n = int(DUR * FPS)
    ims = [grid_frame(f / FPS, sheets) for f in range(n)]
    G.save_gif(ims, os.path.join(out, 'mana_kalkan_A-D.gif'), int(1000 / FPS))
    colour_sheet(sheets).save(os.path.join(out, 'mana_kalkan_renkler.png'))
    print('   tools/proto_20261014/out/mana_kalkan_renkler.png')
    if '--kareler' in sys.argv:
        for tt in (0.95, 1.9, 2.6, 3.45, 3.7, 5.0, 5.9, 6.8):
            grid_frame(tt, sheets).save(os.path.join(out, 'mana_kalkan_kare_%04d.png' % int(tt * 100)))


if __name__ == '__main__':
    main()
