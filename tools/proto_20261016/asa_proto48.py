# -*- coding: utf-8 -*-
"""Asa prototipleri v2 (2026-10-16): 48x48, ayrıntılı, Terraria asaları tadında (kullanıcı: "32x32 çok düşük 48x48 olsun,
daha ayrıntılı daha ilgi çekici"). 4 asa x 3 stil ailesi; eski oyun sanatına bakılmadı.

Yön: sol-alttan sağ-üste 45 derece (oyunda sprite_forward_angle_deg ~ -45). Çizim (a, b) çerçevesinde:
a = asa ekseni (sağ-üst +, uç ~ +31), b = eksene dik (b<0 sol-üst = ışıklı taraf). Sınır: |b| <= 31.4 - a.
Motor: her parça ışıklı tüp / küre / eğimli levha / kesme taş / ışıyan katman olarak gölgelenir (ışık sol-üstten),
öndeki parça arkadakinin üstüne koyu iç çizgi çeker, dış çizgi seçici (malzemenin koyusu), ışıyan parçalara 2 kademeli hale.

Çıktılar (bu klasör): asa48_<A|B|C>_<ates|yildirim|arcane|buz>.png, asa48_sayfa.png (x5), asa48_oyun_olcegi.png.
Çalıştırma: python tools/proto_20261016/asa_proto48.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(ROOT, "..", ".."))
N = 48
O = (24.5, 24.5)  # eksen piksel merkezlerinden geçer -> gövde tam 3 köşegen
R2 = math.sqrt(2.0)
AS = 0.955  # eksen boyunca hafif sıkıştırma: topuz ve uç tuvale (dış çizgi + hale payıyla) sığsın


def _n3(x, y, z):
    l = math.sqrt(x * x + y * y + z * z)
    return (x / l, y / l, z / l)


LIGHT = _n3(-0.49, -0.686, 0.539)
HALF = _n3(LIGHT[0], LIGHT[1], LIGHT[2] + 1.0)
TH = (0.34, 0.52, 0.69, 0.85)


def hx(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


# 0 dış çizgi, 1..5 koyudan açığa, 6 parlama
P = {k: [hx(c) for c in v.split()] for k, v in {
    "wood": "#241208 #4a2814 #6b3c1f #8e562d #b2763f #d39a5c #f0c48a",
    "ash": "#1e1c22 #3d3940 #5e5958 #827b74 #a69d92 #cbc2b2 #ece5d6",
    "plum": "#1a0f22 #3a2140 #57335a #774b74 #976690 #b98ab0 #dcb6d4",
    "birch": "#232a36 #6a7482 #98a2ae #bec6ce #dce1e6 #f3f5f7 #ffffff",
    "leaf": "#0f2420 #1d3d36 #2a5a4c #3a7a62 #529a78 #74b892 #b0e0c0",
    "iron": "#0f0f16 #22232e #363846 #4d5062 #686d83 #8b91a8 #c3c9dc",
    "steel": "#141a26 #2e3748 #48546a #66748e #8896b0 #b2bfd4 #eef3fb",
    "silver": "#1d2532 #46546a #6c7c94 #93a3b9 #b9c7d8 #dde6f0 #ffffff",
    "gold": "#2b1907 #5e3a10 #8c5c1a #b9842a #dfab3e #f6d266 #fff4c0",
    "copper": "#2d150c #57291a #84412a #ac5e38 #cf7f4c #eda772 #ffdcbc",
    "leather": "#22100a #3f1f14 #5a2d1c #763d26 #925034 #ad6a46 #c98a63",
    "ruby": "#2a0508 #5a0d14 #8a1620 #b8232c #e04a46 #ff8a7a #ffe0d8",
    "obsid": "#07060b #141119 #201b28 #2f2838 #423a4e #5a5068 #9a8fb0",
    "stone": "#121019 #24212d #353140 #484355 #5e5970 #79738b #a7a1b8",
    "glass": "#121830 #20305a #2e4680 #3f5fa2 #6688c4 #9fbde6 #ffffff",
    "fire": "#5a1208 #9e2416 #d24618 #ee7a1f #f9ab2c #fdd85a #fff6c8",
    "bolt": "#4a3608 #9a6e0e #cf9e1a #ecc832 #f8e25a #fff3a0 #ffffff",
    "arc": "#1c0b33 #3a176a #5e2aa8 #8546d8 #a970f0 #cfa8ff #f6ecff",
    "ice": "#0f2742 #1d4f80 #2f78b4 #4fa3d8 #7fc8ee #b6e6fb #f0fcff",
}.items()}


def ab(qx, qy):
    px, py = qx - O[0], qy - O[1]
    return (px - py) / R2 / AS, (px + py) / R2


def xy(a, b):
    a *= AS
    return (O[0] + (a + b) / R2, O[1] + (b - a) / R2)


def hsh(x, y, k=0):
    return (((x * 73856093) ^ (y * 19349663) ^ (k * 83492791)) & 0xFFFF) / 65535.0


def lit_idx(n, shine=0.0, amb=0.16):
    d = max(0.0, n[0] * LIGHT[0] + n[1] * LIGHT[1] + n[2] * LIGHT[2])
    I = amb + (1.0 - amb) * d
    idx = 1 + sum(1 for t in TH if I > t)
    if shine > 0.0:
        s = max(0.0, n[0] * HALF[0] + n[1] * HALF[1] + n[2] * HALF[2]) ** 28
        if s > 1.0 - shine:
            idx = 6
    return idx


def seg_closest(p, q, r):
    dx, dy = q[0] - p[0], q[1] - p[1]
    L = dx * dx + dy * dy
    t = 0.0 if L == 0 else max(0.0, min(1.0, ((r[0] - p[0]) * dx + (r[1] - p[1]) * dy) / L))
    return (p[0] + t * dx, p[1] + t * dy), t


def in_poly(pts, q):
    x, y = q
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def in_tri(a, b, c, p):
    def s(p1, p2, p3):
        return (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1])
    d1, d2, d3 = s(p, a, b), s(p, b, c), s(p, c, a)
    neg = d1 < 0 or d2 < 0 or d3 < 0
    pos = d1 > 0 or d2 > 0 or d3 > 0
    return not (neg and pos)


def spike(base, tip, w, shoulder=0.3, wb=None):
    """Uzun kristal/diken çokgeni (a,b): taban-sol, omuz-sol, uç, omuz-sağ, taban-sağ."""
    (a0, b0), (a1, b1) = base, tip
    da, db = a1 - a0, b1 - b0
    L = math.hypot(da, db)
    pa, pb = -db / L, da / L
    wb = w * 0.55 if wb is None else wb
    sa, sb = a0 + da * shoulder, b0 + db * shoulder
    return [(a0 - pa * wb, b0 - pb * wb), (sa - pa * w, sb - pb * w), (a1, b1), (sa + pa * w, sb + pb * w), (a0 + pa * wb, b0 + pb * wb)]


def ribbon(pts, w0, w1, miter=1.8):
    """Keskin köşeli şerit çokgeni: orta çizgiden w0 -> w1 genişlikte (zikzak şimşek için)."""
    n = len(pts)
    left, right = [], []
    for i, (a, b) in enumerate(pts):
        w = w0 + (w1 - w0) * i / (n - 1)
        dirs = []
        if i > 0:
            dirs.append((a - pts[i - 1][0], b - pts[i - 1][1]))
        if i < n - 1:
            dirs.append((pts[i + 1][0] - a, pts[i + 1][1] - b))
        nrm = []
        for da, db in dirs:
            l = math.hypot(da, db)
            nrm.append((-db / l, da / l))
        na, nb = sum(v[0] for v in nrm), sum(v[1] for v in nrm)
        l = math.hypot(na, nb)
        na, nb = na / l, nb / l
        k = min(miter, 1.0 / max(0.2, na * nrm[0][0] + nb * nrm[0][1]))
        left.append((a + na * w * k, b + nb * w * k))
        right.append((a - na * w * k, b - nb * w * k))
    return left + right[::-1]


def seg_quads(pts, w0, w1, ext=0.7):
    """Zikzak için parça parça dörtgenler: köşelerde uzatılıp sivri kesişir (şimşek kırığı)."""
    n = len(pts)
    ws = [w0 + (w1 - w0) * i / (n - 1) for i in range(n)]
    out = []
    for i in range(n - 1):
        (a0, b0), (a1, b1) = pts[i], pts[i + 1]
        da, db = a1 - a0, b1 - b0
        L = math.hypot(da, db)
        ua, ub = da / L, db / L
        na, nb = -ub, ua
        e0 = ext * ws[i] if i > 0 else 0.0
        e1 = ext * ws[i + 1] if i < n - 2 else 0.0
        p = (a0 - ua * e0, b0 - ub * e0)
        q = (a1 + ua * e1, b1 + ub * e1)
        out.append([(p[0] + na * ws[i], p[1] + nb * ws[i]), (q[0] + na * ws[i + 1], q[1] + nb * ws[i + 1]),
                    (q[0] - na * ws[i + 1], q[1] - nb * ws[i + 1]), (p[0] - na * ws[i], p[1] - nb * ws[i])])
    return out


def circle_pts(ca, cb, r, n=28, ra=None):
    ra = r if ra is None else ra
    return [(ca + ra * math.cos(2 * math.pi * i / n), cb + r * math.sin(2 * math.pi * i / n)) for i in range(n + 1)]


def scale_poly(pts, ca, cb, k):
    return [(ca + (a - ca) * k, cb + (b - cb) * k) for a, b in pts]


class Canvas:
    def __init__(self):
        self.pix = {}  # (x,y) -> [rgb, pid]
        self.parts = []
        self.post = {}  # (x,y) -> rgba

    def _part(self, mat, sep, emis, outline):
        self.parts.append({"mat": mat, "sep": sep, "emis": emis, "outline": outline})
        return len(self.parts) - 1

    def _scan(self, pts_xy, pad, fn, pid, clip):
        xs = [p[0] for p in pts_xy]
        ys = [p[1] for p in pts_xy]
        for y in range(max(0, int(min(ys) - pad) - 1), min(N, int(max(ys) + pad) + 2)):
            for x in range(max(0, int(min(xs) - pad) - 1), min(N, int(max(xs) + pad) + 2)):
                q = (x + 0.5, y + 0.5)
                if clip is not None and not clip(*ab(*q)):
                    continue
                c = fn(q, x, y)
                if c is not None:
                    self.pix[(x, y)] = [c, pid]

    # ---- ilkel parçalar
    def tube(self, pts, r, mat, shine=0.25, tex=None, glow=None, sep=True, emis=False, outline=True, clip=None):
        """Işıklı tüp (çoklu çizgi). r sabit ya da (r0, r1) uçtan uca. glow=(iç,orta,dış) indeksleri -> ışıyan çizgi."""
        xyp = [xy(*p) for p in pts]
        segs = list(zip(xyp[:-1], xyp[1:]))
        lens = [math.dist(p, q) for p, q in segs]
        tot = sum(lens) or 1.0
        rmax = r if isinstance(r, (int, float)) else max(r)
        pid = self._part(mat, sep, emis or glow is not None, outline)

        def fn(q, x, y):
            best = None
            acc = 0.0
            for (p0, p1), L in zip(segs, lens):
                c, t = seg_closest(p0, p1, q)
                s = (acc + t * L) / tot
                rr = r if isinstance(r, (int, float)) else r[0] + (r[1] - r[0]) * s
                d = math.dist(c, q)
                if d <= rr and (best is None or d / rr < best[0]):
                    best = (d / rr, c, rr, s)
                acc += L
            if best is None:
                return None
            _, c, rr, s = best
            vx, vy = (q[0] - c[0]) / rr, (q[1] - c[1]) / rr
            vl = math.hypot(vx, vy)
            if glow is not None:
                idx = glow[0] if vl < 0.4 else (glow[1] if vl < 0.75 else glow[2])
            else:
                idx = lit_idx((vx, vy, math.sqrt(max(0.0, 1.0 - vl * vl))), shine)
            a, b = ab(*q)
            if tex is not None:
                idx = tex(idx, a, b, x, y, s, vl)
            return idx if isinstance(idx, tuple) else P[mat][max(1, min(6, idx))]

        self._scan(xyp, rmax, fn, pid, clip)

    def sphere(self, c, r, mat, shine=0.3, glow=False, sep=True, emis=False, clip=None, tex=None):
        cx, cy = xy(*c)
        pid = self._part(mat, sep, emis or glow, True)

        def fn(q, x, y):
            vx, vy = (q[0] - cx) / r, (q[1] - cy) / r
            vl = math.hypot(vx, vy)
            if vl > 1.0:
                return None
            if glow:
                hx_, hy_ = vx + 0.28, vy + 0.36  # sıcak nokta sol-üstte
                d = math.hypot(hx_, hy_)
                idx = 6 if d < 0.32 else (5 if d < 0.62 else (4 if d < 0.9 else 3))
            else:
                idx = lit_idx((vx, vy, math.sqrt(1.0 - vl * vl)), shine)
            if tex is not None:
                idx = tex(idx, *ab(*q), x, y, vl)
            return idx if isinstance(idx, tuple) else P[mat][max(1, min(6, idx))]

        self._scan([(cx, cy)], r, fn, pid, clip)

    def plate(self, poly, mat, bevel=1.6, shine=0.15, tex=None, sep=True, flat_bias=0, emis=False):
        """Eğimli kenarlı levha (kanat, bıçak, kâse)."""
        xyp = [xy(*p) for p in poly]
        edges = list(zip(xyp, xyp[1:] + xyp[:1]))
        pid = self._part(mat, sep, emis, True)

        def fn(q, x, y):
            if not in_poly(xyp, q):
                return None
            best = None
            for p0, p1 in edges:
                c, _ = seg_closest(p0, p1, q)
                d = math.dist(c, q)
                if best is None or d < best[0]:
                    best = (d, c)
            d, c = best
            if d < bevel and d > 1e-6:
                t = 1.0 - d / bevel
                n = _n3((c[0] - q[0]) / d * t * 1.2, (c[1] - q[1]) / d * t * 1.2, 1.0)
            else:
                n = (0.0, 0.0, 1.0)
            idx = lit_idx(n, shine) + (flat_bias if d >= bevel else 0)
            if tex is not None:
                idx = tex(idx, *ab(*q), x, y, d)
            return idx if isinstance(idx, tuple) else P[mat][max(1, min(6, idx))]

        self._scan(xyp, 0, fn, pid, None)

    def gem(self, poly, mat, center=None, table=0.0, steep=0.85, shine=0.35, emis=True, sep=True, table_bias=1):
        """Kesme taş: merkezden yelpaze yüzeyler, isteğe bağlı düz tabla."""
        xyp = [xy(*p) for p in poly]
        if center is None:
            center = (sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly))
        c = xy(*center)
        tri = []
        for p0, p1 in zip(xyp, xyp[1:] + xyp[:1]):
            ex, ey = p1[0] - p0[0], p1[1] - p0[1]
            nx, ny = ey, -ex
            mx, my = (p0[0] + p1[0]) / 2 - c[0], (p0[1] + p1[1]) / 2 - c[1]
            if nx * mx + ny * my < 0:
                nx, ny = -nx, -ny
            l = math.hypot(nx, ny) or 1.0
            tri.append((p0, p1, _n3(nx / l * steep, ny / l * steep, 1.0)))
        tab = [(c[0] + (p[0] - c[0]) * table, c[1] + (p[1] - c[1]) * table) for p in xyp] if table > 0 else None
        pid = self._part(mat, sep, emis, True)

        def fn(q, x, y):
            if not in_poly(xyp, q):
                return None
            if tab is not None and in_poly(tab, q):
                return P[mat][max(1, min(6, lit_idx((0.0, 0.0, 1.0), shine) + table_bias))]
            for p0, p1, n in tri:
                if in_tri(c, p0, p1, q):
                    return P[mat][lit_idx(n, shine)]
            return P[mat][3]

        self._scan(xyp, 0, fn, pid, None)

    def layers(self, polys, mat, idxs, sep=True, outline=True):
        """Işıyan katmanlar (alev): dıştan içe çokgenler, her biri tek renk."""
        xyps = [[xy(*p) for p in poly] for poly in polys]
        pid = self._part(mat, sep, True, outline)

        def fn(q, x, y):
            out = None
            for poly, idx in zip(xyps, idxs):
                if in_poly(poly, q):
                    out = P[mat][idx]
            return out

        self._scan(xyps[0], 0, fn, pid, None)

    def layers_union(self, groups, mat, idxs, sep=True, outline=True):
        """Işıyan katmanlar, her katman birden çok çokgenin birleşimi (dıştan içe)."""
        xg = [[[xy(*p) for p in poly] for poly in g] for g in groups]
        pid = self._part(mat, sep, True, outline)

        def fn(q, x, y):
            out = None
            for g, idx in zip(xg, idxs):
                if any(in_poly(poly, q) for poly in g):
                    out = P[mat][idx]
            return out

        self._scan([p for poly in xg[0] for p in poly], 0, fn, pid, None)

    def dot(self, a, b, mat, idx, emis=True):
        x, y = xy(a, b)
        pid = self._part(mat, False, emis, True)
        if 0 <= int(x) < N and 0 <= int(y) < N:
            self.pix[(int(x), int(y))] = [P[mat][idx], pid]

    def star(self, a, b, mat, size=1):
        x, y = xy(a, b)
        x, y = int(x), int(y)
        self._post(x, y, P[mat][6] + (255,))
        for k in range(1, size + 1):
            col = P[mat][6 - k] + ((255,) if k == 1 else (200,))
            for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
                self._post(x + dx, y + dy, col)

    def glint(self, a, b, mat, idx=6):
        x, y = xy(a, b)
        self._post(int(x), int(y), P[mat][idx] + (255,))

    def _post(self, x, y, c):
        if 0 <= x < N and 0 <= y < N:
            self.post[(x, y)] = c

    # ---- sonlandırma
    def render(self, halo=True):
        pix = {k: list(v) for k, v in self.pix.items()}
        # iç çizgi: öndeki (sonra çizilen) ayrık parça, arkadakinin komşu pikselini kendi koyusuna boyar
        for (x, y), (c, pid) in self.pix.items():
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                o = self.pix.get((x + dx, y + dy))
                if o is not None and o[1] > pid and self.parts[o[1]]["sep"]:
                    pix[(x, y)][0] = P[self.parts[o[1]]["mat"]][0]
                    break
        img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        for (x, y), (c, pid) in pix.items():
            img.putpixel((x, y), c + (255,))
        outl = {}
        for (x, y), (c, pid) in self.pix.items():
            part = self.parts[pid]
            if not part["outline"]:
                continue
            ol = P[part["mat"]][0]
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                k = (x + dx, y + dy)
                if k in self.pix or not (0 <= k[0] < N and 0 <= k[1] < N):
                    continue
                if k not in outl or sum(ol) < sum(outl[k]):
                    outl[k] = ol
        for k, c in outl.items():
            img.putpixel(k, c + (255,))
        if halo:
            em = [(k, self.parts[v[1]]["mat"]) for k, v in self.pix.items() if self.parts[v[1]]["emis"]]
            for y in range(N):
                for x in range(N):
                    if (x, y) in self.pix or (x, y) in outl:
                        continue
                    best = None
                    for (ex, ey), m in em:
                        d = math.hypot(ex - x, ey - y)
                        if d <= 2.3 and (best is None or d < best[0]):
                            best = (d, m)
                    if best:
                        col = P[best[1]][4]
                        img.putpixel((x, y), col + ((110,) if best[0] < 1.5 else (48,)))
        for (x, y), c in self.post.items():
            under = img.getpixel((x, y))
            if c[3] < 255 and under[3] == 255:
                continue
            img.putpixel((x, y), c)
        return img


# ---------------------------------------------------------------- dokular
def grain(idx, a, b, x, y, s, v):
    if idx > 1 and hsh(int(round(b * R2)), int(math.floor(a / 2.3))) < 0.2:
        return idx - 1
    return idx


def speckle(idx, a, b, x, y, *rest):
    return idx - 1 if idx > 1 and hsh(x, y, 3) < 0.16 else idx


def wrap(idx, a, b, x, y, s, v):
    return idx - 1 if int(math.floor((a - b * 0.9) * 0.75)) % 2 == 0 else idx


def shaft(c, a0, a1, mat, r=1.3, tex=None, shine=0.25, sep=True):
    c.tube([(a0, 0.0), (a1, 0.0)], r, mat, shine=shine, tex=tex, sep=sep)


def band(c, a0, a1, mat, r=1.95, shine=0.35):
    c.tube([(a0, 0.0), (a1, 0.0)], r, mat, shine=shine)


def coil(c, a0, n, mat, step=1.5, r=0.55):
    for k in range(n):
        a = a0 + k * step
        c.tube([(a - 0.45, -1.9), (a + 0.45, 1.9)], r, mat, shine=0.3)


def pommel(c, mat, gem=None):
    c.tube([(-30.2, 0.0), (-27.2, 0.0)], (1.5, 2.0), mat, shine=0.35)
    band(c, -27.6, -26.0, mat, r=2.05)
    if gem:
        c.sphere((-29.2, 0.0), 0.9, gem, glow=True)


# ---------------------------------------------------------------- A: AHŞAP + ÇEKİRDEK
def a_fire(c):
    """Köz Kütüğü: budaklı kütük, iki kıvrık dal kor taşını kavrar, üstünden üç dilli alev."""
    pommel(c, "iron")
    c.tube([(-26.4, 0), (-15, 0.3), (-4, -0.2), (6, 0.2)], 1.3, "wood", tex=grain)
    c.tube([(-13, 0), (-6, 0)], 1.8, "leather", tex=wrap, shine=0.1)
    fo = [(15, -4.5), (18.5, -5.4), (20.2, -3.8), (23.2, -6.6), (23.8, -3.0), (26.6, -2.4), (30.6, 0.2),
          (26.6, 1.8), (25.0, 4.4), (23.0, 2.6), (20.6, 5.4), (18.0, 4.8), (15, 4.4)]
    c.layers([fo, scale_poly(fo, 16.5, 0, 0.7), scale_poly(fo, 16.0, 0, 0.42), scale_poly(fo, 15.5, 0, 0.18)],
             "fire", (3, 4, 5, 6))
    c.tube([(4, 0), (10, 0)], (1.9, 1.6), "wood", tex=grain, sep=False)
    c.sphere((14.6, 0.0), 4.4, "fire", glow=True)
    c.tube([(9, -3.4), (10.2, -7.0), (12.4, -8.6)], (0.9, 0.5), "wood", tex=grain)
    c.tube([(4.5, -0.4), (8, -2.8), (11.5, -5.6), (15.5, -6.6), (19.2, -5.0)], (1.6, 0.75), "wood", tex=grain)
    c.tube([(4.5, 0.4), (8, 2.8), (11.5, 5.4), (15.2, 6.0), (18.2, 4.4)], (1.6, 0.75), "wood", tex=grain)
    c.dot(12.6, -8.8, "fire", 5)
    c.dot(18.6, -5.4, "fire", 4)
    c.star(24.0, -6.8, "fire", 1)
    c.star(21.2, 7.4, "fire", 1)
    c.glint(28.6, -2.2, "fire", 5)
    c.glint(27.4, 3.4, "fire", 4)


def a_lightning(c):
    """Fırtına Çatalı: yıldırım çarpmış soluk dal (parlayan yarık), bakır tel sargı, çatalda süzülen sarı kristal."""
    pommel(c, "copper")
    shaft(c, -26.4, 4.5, "ash", tex=grain)
    c.tube([(-9, 0), (-6.5, 0.55), (-4, -0.55), (-1.5, 0.55), (1, -0.45), (3.5, 0.3)], 0.42, "bolt", glow=(6, 5, 5), sep=False, outline=False)
    coil(c, -16, 5, "copper")
    zig1 = [(23.6, -1.4), (24.6, -3.0), (23.8, -4.2), (25.0, -5.4)]
    zig2 = [(20.6, 2.0), (21.8, 3.2), (21.0, 4.4), (21.8, 5.4)]
    c.tube(zig1, 0.45, "bolt", glow=(6, 6, 5), outline=False, sep=False)
    c.tube(zig2, 0.45, "bolt", glow=(6, 6, 5), outline=False, sep=False)
    c.tube([(4, -0.5), (9, -3.4), (14, -6.2), (19, -7.6), (23, -7.2), (25.4, -5.4)], (1.55, 0.7), "ash", tex=grain)
    c.tube([(11.5, -5.0), (11.6, -8.8)], (0.8, 0.45), "ash")
    c.tube([(4, 0.5), (9, 3.4), (14, 5.9), (18.5, 6.6), (21.6, 5.4)], (1.55, 0.7), "ash", tex=grain)
    coil(c, 2.4, 2, "copper", step=1.4)
    c.gem([(10.5, 0), (14, -2.5), (21, -2.5), (26, 0), (21, 2.5), (14, 2.5)], "bolt", table=0.42)
    c.star(28.2, -1.4, "bolt", 2)
    c.star(15.6, 9.0, "bolt", 1)
    c.glint(18.0, -10.2, "bolt", 6)


def a_arcane(c):
    """Sarmal Kök: iki kök sarmal halinde mor küreyi sarar, kökte iki yaprak, kürede iç parıltı."""
    pommel(c, "gold", gem="arc")
    shaft(c, -26.4, 6, "plum", tex=grain)
    band(c, -11, -8.6, "gold")
    c.sphere((-9.8, -1.6), 0.8, "arc", glow=True)
    c.sphere((17.2, 0.0), 5.3, "arc", shine=0.4, emis=True)
    for a, b, k in ((15.6, 1.2, 5), (18.6, 2.2, 4), (16.4, 3.0, 4), (19.4, -0.4, 4)):
        c.dot(a, b, "arc", k)
    c.tube([(19.6, 6.4), (22.8, 3.0), (24.6, -0.8), (26.6, -2.6)], (0.95, 0.6), "plum", tex=grain)
    c.tube([(5, -0.6), (9, -3.6), (13, -6.6), (17, -7.1), (21, -5.6), (23.6, -2.6), (24.4, 0.8), (23.0, 3.8)], (1.45, 0.6), "plum", tex=grain)
    c.tube([(5, 0.6), (9, 3.4), (12.5, 6.2), (16.5, 6.9), (19.6, 6.4)], (1.45, 0.95), "plum", tex=grain)
    c.plate([(12.6, -7.4), (14.4, -9.8), (17.4, -10.6), (15.8, -8.2), (13.8, -7.1)], "leaf", bevel=1.0)
    c.plate([(9.4, 4.0), (9.0, 7.4), (10.6, 9.6), (11.0, 6.8), (10.4, 4.6)], "leaf", bevel=1.0)
    c.star(21.4, -8.6, "arc", 2)
    c.star(11.0, 8.8, "arc", 1)
    c.glint(27.6, 2.6, "arc", 5)
    c.glint(6.6, -6.0, "arc", 4)


def a_ice(c):
    """Kayın Buzu: kara benekli beyaz kayın, üst kısmı kırağılı, gümüş bilezik, yelpaze gibi açılan buz kristalleri."""
    pommel(c, "silver", gem="ice")

    def birch(idx, a, b, x, y, s, v):
        for k, side in ((-22, 1), (-17.5, -1), (-12, 1), (-6.5, -1), (-1.5, 1)):
            if k <= a <= k + 1.0 and b * side > -0.3:
                return P["birch"][0] if abs(b) < 0.4 else P["birch"][1]
        if a > -3 and hsh(x, y, 7) < 0.12 + (a + 3) * 0.04:
            return P["ice"][5]
        return idx

    shaft(c, -26.4, 7, "birch", tex=birch, shine=0.1)
    for base, tip, w in (((7.5, -2.6), (9.6, -6.6), 1.0), ((7.5, 2.6), (9.4, 6.2), 1.0)):
        c.gem(spike(base, tip, w), "ice")
    c.gem(spike((8, -1.8), (19.6, -11.2), 2.3), "ice")
    c.gem(spike((8, 1.8), (18.2, 9.6), 2.1), "ice")
    band(c, 5.2, 8.4, "silver", r=2.2)
    c.sphere((6.8, -1.9), 0.75, "ice", glow=True)
    c.gem(spike((7.8, 0), (30.8, 0), 3.4, shoulder=0.28), "ice")
    c.star(22.2, -7.6, "ice", 2)
    c.star(26.8, 3.6, "ice", 1)
    c.glint(14.6, 9.6, "ice", 6)
    c.glint(29.0, -2.0, "ice", 5)


# ---------------------------------------------------------------- B: DÖVME METAL
def b_fire(c):
    """Mangal: demir gövde, yakut kakmalı altın bilezikler, kıvrımlı altın süs kanatları, altın kaburgalı kâse ve alev."""
    pommel(c, "gold")
    shaft(c, -26.4, 8, "iron", shine=0.35)
    band(c, -21, -19.2, "gold")
    band(c, -7.6, -5.0, "gold")
    c.sphere((-6.3, -1.8), 0.95, "ruby", shine=0.5)
    for sg in (-1, 1):
        c.tube([(7, 1.6 * sg), (8.2, 4.2 * sg), (7.2, 6.8 * sg), (5.0, 7.8 * sg), (3.4, 6.6 * sg), (4.4, 5.2 * sg)],
               (0.95, 0.55), "gold", shine=0.4)
    fo = [(14, -6.5), (17.5, -7.4), (19.5, -5.8), (22.0, -8.2), (23.2, -5.0), (26.0, -3.8), (30.6, 0.0),
          (26.6, 2.2), (24.6, 5.2), (22.6, 3.6), (20.6, 6.6), (18.0, 5.8), (14, 6.5)]
    c.layers([fo, scale_poly(fo, 16.5, 0, 0.72), scale_poly(fo, 16.0, 0, 0.45), scale_poly(fo, 15.5, 0, 0.2)],
             "fire", (3, 4, 5, 6))
    c.plate([(8, -1.8), (10, -4.6), (13, -6.6), (15.6, -7.3), (15.6, 7.3), (13, 6.6), (10, 4.6), (8, 1.8)], "iron", bevel=2.0, shine=0.2)
    for b0, b1 in ((0, 0), (-2.8, -4.8), (2.8, 4.8)):
        c.tube([(9.2, b0), (15.0, b1)], 0.55, "gold", shine=0.4)
    c.tube([(15.6, -7.8), (15.6, 7.8)], 1.0, "gold", shine=0.45)
    c.sphere((7.6, 0.0), 1.9, "gold", shine=0.45)
    c.sphere((7.6, 0.0), 0.9, "ruby", shine=0.6)
    c.star(24.2, -8.4, "fire", 1)
    c.star(22.4, 7.6, "fire", 1)
    c.glint(29.4, -2.4, "fire", 5)


def b_lightning(c):
    """Plazma Küresi: çelik gövde, bakır bobinler, altın taç pençeleri, içinde şimşek dalları olan cam küre, paratoner iğnesi."""
    pommel(c, "copper")
    shaft(c, -26.4, 6, "steel", shine=0.4)
    band(c, -19, -17.4, "copper")
    coil(c, -4, 5, "copper", step=1.5)
    c.tube([(21.0, 0), (30.8, 0)], (1.15, 0.45), "steel", shine=0.45)
    band(c, 21.6, 23.0, "gold", r=1.7)
    c.sphere((15.4, 0.0), 6.3, "glass", shine=0.45)
    for pts in ([(15.4, 0), (17.0, -1.6), (16.6, -3.2), (18.4, -4.6)], [(15.4, 0), (18.0, 0.8), (19.4, -0.2), (20.8, 0.6)],
                [(15.4, 0), (14.6, 2.0), (16.0, 3.4), (15.4, 5.0)], [(15.4, 0), (13.2, -1.0), (12.4, -2.8), (10.8, -3.6)],
                [(15.4, 0), (13.0, 1.6), (11.0, 1.4)]):
        c.tube(pts, 0.45, "bolt", glow=(6, 5, 5), sep=False, outline=False)
    c.sphere((15.4, 0.0), 1.4, "bolt", glow=True, sep=False)
    band(c, 5, 8, "gold", r=2.3)
    for sg in (-1, 1):
        c.tube([(7, 2.0 * sg), (10, 5.6 * sg), (14, 7.3 * sg), (16.8, 6.6 * sg)], (1.05, 0.6), "gold", shine=0.45)
    c.star(29.0, -1.9, "bolt", 2)
    c.tube([(9.4, -7.6), (10.4, -8.6), (9.8, -9.6)], 0.42, "bolt", glow=(6, 6, 5), outline=False, sep=False)
    c.glint(22.6, 7.0, "bolt", 6)


def b_arcane(c):
    """Hale: koyu demir gövde, ametist kakmalı bilezikler, altın tüy kanatlar, ışınlı altın halka ve ortasında mor kesme taş."""
    pommel(c, "gold", gem="arc")
    shaft(c, -26.4, 9, "iron", shine=0.35)
    band(c, -21, -19.2, "gold")
    band(c, -9.4, -7.0, "gold")
    c.sphere((-8.2, -1.8), 0.95, "arc", glow=True)
    for sg in (-1, 1):
        for pts, r in (([(8, 1.4 * sg), (9, 5 * sg), (9.6, 8.6 * sg)], (1.0, 0.5)),
                       ([(7, 1.4 * sg), (6.5, 5 * sg), (5.4, 8.0 * sg)], (0.95, 0.45)),
                       ([(6, 1.2 * sg), (4.3, 4 * sg), (2.6, 5.8 * sg)], (0.85, 0.4))):
            c.tube(pts, r, "gold", shine=0.4)
    c.tube([(7.6, 0), (12.6, 0)], (1.7, 1.1), "gold", shine=0.45)
    ca, cr = 19.0, 6.3
    for ang, r1 in ((0, 9.8), (40, 8.6), (-40, 8.6), (80, 9.4), (-80, 9.4)):
        t = math.radians(ang)
        c.tube([(ca + 7.2 * math.cos(t), 7.2 * math.sin(t)), (ca + r1 * math.cos(t), r1 * math.sin(t))], (0.85, 0.35), "gold", shine=0.4)
    c.tube(circle_pts(ca, 0.0, cr), 1.2, "gold", shine=0.45)
    c.gem([(14.6, 0), (17.4, -3.0), (20.8, -3.0), (23.6, 0), (20.8, 3.0), (17.4, 3.0)], "arc", center=(19.0, 0.0), table=0.45)
    c.star(13.6, -9.0, "arc", 2)
    c.star(28.6, 2.0, "arc", 1)
    c.glint(23.4, -7.8, "arc", 5)


def b_ice(c):
    """Pençe Yuvası: gümüş gövde, buz taşlı altın bilezik, geriye açılan buz dikenleri, altın pençelerin kavradığı iri buz taşı."""
    pommel(c, "silver", gem="ice")
    shaft(c, -26.4, 9, "silver", shine=0.4)
    band(c, -8.6, -6.2, "gold")
    c.sphere((-7.4, -1.8), 0.95, "ice", glow=True)
    band(c, -20.4, -19.0, "gold", r=1.8)
    c.gem(spike((8, -2.4), (5.6, -9.0), 1.4), "ice")
    c.gem(spike((8, 2.4), (5.6, 9.0), 1.4), "ice")
    c.gem([(9.5, -2.4), (12.5, -5.4), (24.4, -5.4), (30.6, 0), (24.4, 5.4), (12.5, 5.4), (9.5, 2.4)], "ice",
          center=(19.0, 0.0), table=0.5)
    band(c, 6.4, 9.8, "gold", r=2.3)
    for sg in (-1, 1):
        c.tube([(8.6, 1.8 * sg), (10.6, 5.4 * sg), (14.5, 7.2 * sg), (18.5, 7.0 * sg), (20.4, 5.2 * sg)], (1.2, 0.6), "gold", shine=0.45)
    c.sphere((8.1, 0.0), 0.9, "ice", glow=True)
    c.star(27.2, -3.2, "ice", 2)
    c.star(14.0, 10.0, "ice", 1)
    c.glint(23.0, 7.6, "ice", 6)


# ---------------------------------------------------------------- C: SAF ELEMENT
def c_fire(c):
    """Obsidyen Alev: camsı obsidyen gövde ve pürüzlü bıçak uç, içinden geçen erimiş lav damarları, kor kıvılcımları."""
    c.gem(spike((-26.0, 0), (-31.0, 0), 1.7, shoulder=0.2), "obsid", emis=False)
    shaft(c, -26.4, 6, "obsid", shine=0.5)
    for pts in ([(-21, 0.3), (-19, -0.5), (-17.4, 0.4)], [(-11, -0.4), (-9, 0.5), (-7, -0.3)], [(-1, 0.3), (1, -0.5), (3, 0.4)]):
        c.tube(pts, 0.42, "fire", glow=(5, 5, 4), sep=False, outline=False)
    shard = [(5, -2), (9, -4.2), (12, -3.5), (15.5, -7.4), (17.6, -4.8), (20, -5.8), (21.6, -3.0), (31, 0), (21.6, 3.0),
             (19.6, 5.6), (17.6, 4.6), (15, 7.6), (12, 3.6), (9, 4.2), (5, 2)]
    c.plate(shard, "obsid", bevel=2.2, shine=0.35)
    main = [(7, 0), (11, -0.8), (14.5, 0.6), (18.5, -0.6), (23, 0.4), (27.6, 0)]
    c.tube(main, (1.25, 0.45), "fire", glow=(6, 5, 4), sep=False, outline=False)
    for a, b in ((10.0, 2.4), (17.0, -3.0), (20.6, 2.2), (13.4, -1.8)):
        c.dot(a, b, "fire", 4)
    for pts in ([(11, -0.8), (13, -3.0)], [(14.5, 0.6), (15.4, 4.4)], [(18.5, -0.6), (19.4, -3.4)], [(23, 0.4), (23.6, 2.2)]):
        c.tube(pts, (0.5, 0.35), "fire", glow=(5, 4, 4), sep=False, outline=False)
    c.star(24.8, -5.8, "fire", 1)
    c.star(25.0, 5.4, "fire", 1)
    c.glint(29.6, -1.4, "fire", 5)
    c.glint(18.6, -9.6, "fire", 4)


def c_lightning(c):
    """Şimşek: koyu demir gövde, altın bilezikler ve hilal koruma, kalın şimşek zikzağı baş (beyaz çekirdek), kopan kıvılcımlar."""
    pommel(c, "gold", gem="bolt")
    shaft(c, -26.4, 5, "iron", shine=0.35)
    band(c, -20.6, -19.2, "gold")
    band(c, -9.0, -7.6, "gold")
    ## uzun ileri bacaklar + geriye kırılan kısa basamaklar = her açıda şimşek okunur
    zz = [(7.0, 0.0), (16.5, -5.4), (15.2, 3.0), (24.2, -3.0), (23.0, 2.4), (30.6, -0.4)]
    c.layers_union([seg_quads(zz, 2.3, 0.4), seg_quads(zz, 1.45, 0.25), seg_quads(zz, 0.7, 0.1)], "bolt", (4, 5, 6))
    band(c, 3.0, 6.8, "iron", r=2.4, shine=0.45)
    band(c, 5.6, 6.8, "gold", r=2.5)
    c.sphere((4.2, 0.0), 1.0, "bolt", glow=True)
    for pts in ([(12.4, -8.0), (13.4, -9.2), (12.6, -10.2)], [(19.0, 4.6), (20.2, 5.8), (19.4, 6.8)]):
        c.tube(pts, 0.42, "bolt", glow=(6, 6, 5), outline=False, sep=False)
    c.star(27.6, -3.0, "bolt", 2)
    c.glint(23.6, 4.4, "bolt", 6)


def c_arcane(c):
    """Rün Taşı: pürüzlü taş gövdede parlayan rünler, sivri taş uç, yörünge halkası, süzülen çekirdek ve dört kıymık."""
    pommel(c, "stone", gem="arc")
    shaft(c, -26.4, 9, "stone", r=1.4, tex=speckle, shine=0.1)
    glyphs = [[(0, 0), (1, -1), (1, 1), (-1, 1)], [(0, -1), (0, 0), (1, 0), (-1, 1)], [(-1, -1), (0, 0), (1, 0), (0, 1)]]
    for g, a in zip(glyphs, (-19, -10, -1)):
        x0, y0 = xy(a, 0.0)
        pid = c._part("arc", False, True, True)
        for dx, dy in g:
            c.pix[(int(x0) + dx, int(y0) + dy)] = [P["arc"][5] if (dx, dy) == (0, 0) else P["arc"][4], pid]
    c.gem(spike((8, 0), (13.0, 0), 2.0, shoulder=0.15, wb=1.4), "stone", emis=False)
    orbit = circle_pts(18.0, 0.0, 7.4, n=40, ra=3.2)
    xo = set()
    for k, (a, b) in enumerate(orbit):
        x, y = xy(a, b)
        if k % 2 == 0 and (int(x), int(y)) not in xo:
            xo.add((int(x), int(y)))
    c.sphere((18.0, 0.0), 2.4, "arc", glow=True)
    c.gem(spike((22.6, 0), (30.8, 0), 2.0), "arc")
    c.gem(spike((15.2, -4.4), (20.2, -10.6), 1.6), "arc")
    c.gem(spike((15.2, 4.4), (19.0, 9.6), 1.6), "arc")
    c.gem(spike((11.0, -5.2), (9.4, -8.8), 0.95), "arc")
    c.gem(spike((11.0, 5.2), (9.4, 8.8), 0.95), "arc")
    for (x, y) in xo:
        if (x, y) not in c.pix:
            c._post(x, y, P["arc"][5] + (170,))
    c.star(25.6, -5.0, "arc", 1)
    c.glint(24.0, 6.4, "arc", 6)


def c_ice(c):
    """Buz Sarkıtı: gövdesi dahil buz; gövdede büyüyen küçük kristaller, tepede tek dev kesme kristal mızrak."""
    c.gem(spike((-26.0, 0), (-31.0, 0), 1.8, shoulder=0.2), "ice")

    def streak(idx, a, b, x, y, s, v):
        if abs(b - 0.0) < 0.3 and int(math.floor(a / 2.6)) % 3 == 0:
            return 6
        return idx

    shaft(c, -26.4, 6, "ice", tex=streak, shine=0.45)
    for base, tip, w in (((-12, -1.0), (-14.2, -4.6), 0.85), ((-4, 1.0), (-5.6, 4.8), 0.85), ((1.5, -1.0), (0.2, -5.0), 0.95),
                         ((-19, 1.0), (-20.4, 3.8), 0.7)):
        c.gem(spike(base, tip, w), "ice")
    for base, tip, w in (((6.0, -2.0), (2.4, -5.6), 1.0), ((6.0, 2.0), (2.6, 5.4), 1.0),
                         ((7.4, -2.6), (5.2, -7.4), 1.1), ((7.4, 2.6), (5.4, 7.0), 1.1)):
        c.gem(spike(base, tip, w), "ice")
    c.gem(spike((5.0, 0), (31.0, 0), 4.9, shoulder=0.34, wb=2.0), "ice")
    c.star(22.4, -7.0, "ice", 2)
    c.star(17.0, 8.6, "ice", 1)
    c.glint(28.6, 1.6, "ice", 6)


STAFFS = [("ates", "Ateş Asası"), ("yildirim", "Yıldırım Asası"), ("arcane", "Arcane Asası"), ("buz", "Buz Asası")]
STYLES = [
    ("A", "Ahşap + çekirdek", [a_fire, a_lightning, a_arcane, a_ice], ["Köz Kütüğü", "Fırtına Çatalı", "Sarmal Kök", "Kayın Buzu"]),
    ("B", "Dövme metal", [b_fire, b_lightning, b_arcane, b_ice], ["Mangal", "Plazma Küresi", "Hale", "Pençe Yuvası"]),
    ("C", "Saf element", [c_fire, c_lightning, c_arcane, c_ice], ["Obsidyen Alev", "Şimşek", "Rün Taşı", "Buz Sarkıtı"]),
]


def font(sz, bold=False):
    for f in (("C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf"), "C:/Windows/Fonts/arial.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, sz)
    return ImageFont.load_default()


def build_all():
    out = {}
    for sid, _, fns, _ in STYLES:
        for (key, _), fn in zip(STAFFS, fns):
            cv = Canvas()
            fn(cv)
            img = cv.render()
            img.save(os.path.join(ROOT, "asa48_%s_%s.png" % (sid, key)))
            bb = img.getbbox()
            edge = bb[0] == 0 or bb[1] == 0 or bb[2] == N or bb[3] == N
            print(sid, key, bb, "KENAR!" if edge else "")
            out[(sid, key)] = img
    return out


def sheet(imgs, z=5):
    cell = N * z
    lw, gap, top = 150, 18, 46
    W = lw + len(STYLES) * (cell + gap) + gap
    H = top + len(STAFFS) * (cell + 30 + gap)
    im = Image.new("RGBA", (W, H), (34, 38, 40, 255))
    d = ImageDraw.Draw(im)
    for si, (sid, sname, _, names) in enumerate(STYLES):
        x0 = lw + gap + si * (cell + gap)
        d.text((x0, 12), "%s - %s" % (sid, sname), fill=(235, 230, 215), font=font(20, True))
        for ri, (key, label) in enumerate(STAFFS):
            y0 = top + ri * (cell + 30 + gap)
            d.rectangle([x0, y0, x0 + cell - 1, y0 + cell - 1], fill=(62, 82, 56))
            big = imgs[(sid, key)].resize((cell, cell), Image.NEAREST)
            im.alpha_composite(big, (x0, y0))
            d.text((x0 + 4, y0 + cell + 4), names[ri], fill=(200, 196, 182), font=font(16))
            if si == 0:
                d.text((12, y0 + cell // 2 - 10), label, fill=(235, 230, 215), font=font(18, True))
    im.convert("RGB").save(os.path.join(ROOT, "asa48_sayfa.png"))


def blit_world(dst, src, cx, cy, world_per_px, zoom, rot=0.0):
    """Godot NEAREST örneklemesi taklidi (alfa karışımlı)."""
    sw, sh = src.size
    k = world_per_px * zoom
    cs, sn = math.cos(rot), math.sin(rot)
    rad = int(math.hypot(sw, sh) * k / 2) + 2
    sp, dp = src.load(), dst.load()
    for y in range(int(cy) - rad, int(cy) + rad):
        for x in range(int(cx) - rad, int(cx) + rad):
            if not (0 <= x < dst.size[0] and 0 <= y < dst.size[1]):
                continue
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            u = (cs * dx + sn * dy) / k + sw / 2
            v = (-sn * dx + cs * dy) / k + sh / 2
            iu, iv = int(math.floor(u)), int(math.floor(v))
            if 0 <= iu < sw and 0 <= iv < sh:
                p = sp[iu, iv]
                if p[3] > 0:
                    t = p[3] / 255.0
                    q = dp[x, y]
                    dp[x, y] = tuple(int(q[i] * (1 - t) + p[i] * t) for i in range(3))


def context(imgs):
    """Oyun ölçeği: kamera zoom 2, büyücü idle + 4 asa (uzun kenar 28 dünya px); üst doğal açı, alt sağa nişan."""
    zoom = 2.0
    char_world_px = 2.2368375 * 0.8075 * 0.5
    wiz = Image.open(os.path.join(GAME, "assets/characters/buyucu/sheets/idle.png")).convert("RGBA").crop((0, 0, 48, 48))
    panel_w, panel_h = 300, 150
    W = 20 + len(STYLES) * (panel_w + 20)
    H = 40 + 2 * (panel_h + 20)
    im = Image.new("RGB", (W, H), (34, 38, 40))
    d = ImageDraw.Draw(im)
    slots = [(-34, -18), (34, -18), (-34, 20), (34, 20)]
    for si, (sid, sname, _, _) in enumerate(STYLES):
        x0 = 20 + si * (panel_w + 20)
        d.text((x0, 10), "%s - %s (oyun ölçeği, zoom 2)" % (sid, sname), fill=(235, 230, 215), font=font(15, True))
        for row, aim in enumerate((None, -0.35)):
            y0 = 40 + row * (panel_h + 20)
            pc = Image.new("RGB", (panel_w, panel_h), (74, 98, 64))
            cx, cy = panel_w / 2, panel_h / 2
            blit_world(pc, wiz, cx, cy, char_world_px, zoom)
            for (key, _), (sx, sy) in zip(STAFFS, slots):
                img = imgs[(sid, key)]
                bb = img.getbbox()
                wpp = 28.0 / max(bb[2] - bb[0], bb[3] - bb[1])
                rot = 0.0 if aim is None else aim + math.radians(45.0)
                blit_world(pc, img, cx + sx * zoom, cy + sy * zoom, wpp, zoom, rot)
            im.paste(pc, (x0, y0))
            d.text((x0 + 6, y0 + panel_h - 20), "doğal açı" if aim is None else "sağa nişan", fill=(225, 230, 210), font=font(13))
    im.save(os.path.join(ROOT, "asa48_oyun_olcegi.png"))


if __name__ == "__main__":
    imgs = build_all()
    sheet(imgs)
    context(imgs)
    print("ok", len(imgs))
