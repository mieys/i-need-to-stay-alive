"""ZEHİR ASASI (eski Tüftüf, madde 402) - mermi + asa ucu partikülü PROTOTİPLERİ (2026-11-06, oyuna bağlı DEĞİL).

Kullanıcı: "Zehir Asası'na asaya uygun yeni mermi ve uç partikülü" -> "Evet, prototiple".
Sahne oyun ölçeğinde (1080p, kamera zoom 2): gerçek harita zemini, Şovalye + HÜCUM takibindeki Zehir Asası (masaüstü çizimi,
tepe slotu, nişan slime'a), slime hedef. Asa ~1 sn'de bir atar (oyunda 2,0 sn; %100 saldırı hızında 1 sn), mermi 460 dünya px/sn.
Mermi pikseli 0,575 dünya px (madde 201 mermileri = silah pikseli), uç partikülü 0,903 (madde 299: 0,575'te 1080p'de kayboluyor).
Kurallar (kullanıcının eski geri bildirimleri): dither / dağınık 1 px "parazit" yok - saydamlık 4 adım (band), katı şey dolu + koyu
kontur, gaz konturuz temiz bulut, efekt kaynağından (asa ucu / mermi kuyruğu) çıkar.

  ŞU AN  - bambu dart + açık iz + düşen zehir damlası (zehir_damla sayfası), uçta partikül yok.
  A Zehir Damlası - parlak, konturlu damla (baş önde); kuyruğundan damlalar kopup YERE düşer, yerde küçük gölcük olur.
                    Uç: asa ucunda damla belirip ayak hizasına düşer. İsabet: taç sıçraması + gölcük.
  B Zehir Küresi  - koyu çekirdekli, içinde dönen ışıkla zehir küresi; kuyruğunda kabarcıklar yükselip patlar.
                    Uç: küçük kabarcıklar yükselip patlar. İsabet: kabarcık patlaması.
  C Zehir Işığı   - konturuz parlak çekirdek + sivrilen yeşil ışık izi (oyundaki Arcane/Buz "Işık İzi" ailesi).
                    Uç: diğer asalardaki gibi "Sade Toz" (yeşil). İsabet: krem parlama + dışa saçılan zerre.
  D Zehir Bulutu  - dönmeyen küçük zehir bulutu topu (4 düz ton, konturuz); kuyruğunda büyüyüp sönen buhar topları.
                    Uç: küçük buhar topları kıvrılarak yükselir. İsabet: buhar patlaması.

Çıktı (out/zehir/): zehir_oyun.gif (5 sahne + bilgi, 30 fps, 4 sn döngü), zehir_ozet.png (uçuşun ortası + x2 yakın).
Çalıştırma: python tools/proto_20261106/zehir_asasi_proto.py
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "proto_20261017")))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "proto_20261019")))
import asa_partikul_proto as AP  # noqa: E402
import silah_takip_proto as T  # noqa: E402
from silah_takip_proto import blit2, ellipse, WPP, CHAR_K, slime_frame, SLIME_K  # noqa: E402
from mermi_proto import label, asset  # noqa: E402
from bicak_proto import header, save_gif  # noqa: E402

OUT = os.path.join(HERE, "out", "zehir")
GAME = os.path.normpath(os.path.join(HERE, "..", ".."))
DT, TICK = AP.DT, AP.TICK
FPS_OUT = 30
STEP_OUT = TICK // FPS_OUT
Z = 2  # 1080p oyun kamerası
FEET = 12.0
PROJ_SPEED = 460.0  # dart_projectile.tscn speed
SHOTS = [0.25, 1.25, 2.25, 3.25]
PATH = [(0.5, None), (0.35, (0, -1)), (0.5, None), (0.35, (0, 1)), (0.6, (1, 0)), (0.6, (-1, 0)), (1.1, None)]
START = (300.0, 200.0)
TRACK, LOOP = AP.make_track(PATH, START)
SLIME_C = (START[0] + 128.0, START[1] - 6.0)
SLIME_FEET = SLIME_C[1] + 9.0
VIEW = (START[0] - 66.0, START[1] - 118.0, START[0] + 156.0, START[1] + 26.0)
GRAV = 300.0


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


def ramp(s):
    return [hx(c) for c in s.split()]


## Asanın kendi yeşilleri (#9bee9d #7fda76 #6fc161 #5a9652) etrafında: 0 krem ... 5 en koyu
P = ramp("#f0ffe6 #b6f4ae #86e07c #66c05a #46924a #2c5e30")
OL = hx("#18261a")
POIS_CUR = ramp("#d8f4b0 #a8dc84 #7cb860 #5a9a44")


# ------------------------------------------------------------------ asa
_ICON = None
_TIPP = None


def staff_icon():
    global _ICON
    if _ICON is None:
        _ICON = np.asarray(Image.open(os.path.join(GAME, "assets/weapons/yeni/zehir_asasi.png")).convert("RGBA"), dtype=np.float32)
    return _ICON


def staff_tip():
    """weapon_tip.gd: ileri (-45) eksende en uzak opak piksel, 6 doku px içeri; doku merkezine göre."""
    global _TIPP
    if _TIPP is None:
        a = staff_icon()[..., 3]
        h, w = a.shape
        ys, xs = np.nonzero(a > 127)
        fx, fy = math.cos(AP.FWD), math.sin(AP.FWD)
        px, py = xs + 0.5 - w / 2.0, ys + 0.5 - h / 2.0
        pr = px * fx + py * fy
        m = pr >= pr.max() - 0.75
        _TIPP = (float(px[m].mean()) - fx * 6.0, float(py[m].mean()) - fy * 6.0)
    return _TIPP


AP._TIP["zehir"] = None  # Follow.tip_px yerine kendi ucumuz (aşağıda)


class Follow(AP.Follow):
    def step(self, st, aim=None):
        AP._TIP["zehir"] = staff_tip()
        return super().step(st, aim)


def draw_staff(F, view, pos, rot, Pp):
    def S(p):
        return ((p[0] - view[0]) * Z, (p[1] - view[1]) * Z)
    gx, gy = S((pos[0], Pp[1] + FEET))
    ellipse(F, gx, gy, 6.0 * Z, 2.2 * Z, (0, 0, 0), 0.32 * 0.4)
    x, y = S(pos)
    blit2(F, staff_icon(), x, y, WPP * Z, rot)


# ------------------------------------------------------------------ mermi gövdeleri (doku, +x = uçuş yönü)
def tex(w, h, fn):
    A = np.zeros((h, w, 4), np.float32)
    inside = np.zeros((h, w), bool)
    col = {}
    for y in range(h):
        for x in range(w):
            r = fn(x + 0.5 - w / 2.0, y + 0.5 - h / 2.0)
            if r is not None:
                inside[y, x] = True
                col[(x, y)] = r
    for (x, y), r in col.items():
        c, a = (r, 1.0) if len(r) == 3 else (r[0], r[1])
        A[y, x, :3] = c
        A[y, x, 3] = 255.0 * a
    return A, inside


def outline(A, inside, col=OL):
    h, w = inside.shape
    for y in range(h):
        for x in range(w):
            if not inside[y, x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if not (0 <= xx < w and 0 <= yy < h) or not inside[yy, xx]:
                    A[y, x, :3] = col
                    A[y, x, 3] = 255.0
                    break
    return A


def pad(A, n=1):
    return np.pad(A, ((n, n), (n, n), (0, 0)))


_BODY = {}


def body_A(fr):
    """Damla: yuvarlak baş önde (+x), kuyruk geride sivrilir; 2 kare hafif sallanma."""
    if ("A", fr) not in _BODY:
        sx, sy = (1.0, 1.0) if fr == 0 else (1.08, 0.88)

        def fn(u, v):
            hu, hr = 3.0, 4.9
            inside = ((u - hu) / (hr * sx)) ** 2 + (v / (hr * sy)) ** 2 <= 1.0
            if not inside and -8.0 <= u <= hu:
                inside = abs(v) <= hr * sy * ((u + 8.0) / (hu + 8.0)) ** 1.6
            if not inside:
                return None
            d = math.hypot(u - 4.2, v + 2.0)
            if d < 1.3:
                return P[0]
            return P[min(4, 1 + int(d / 2.5))]
        A, ins = tex(21, 13, fn)
        _BODY[("A", fr)] = pad(outline(A, ins))
    return _BODY[("A", fr)]


def body_B(fr):
    """Küre: konturlu, açık kenar, koyu çekirdek, içinde dönen iki ışık (4 kare) + sabit krem parlama sol üstte."""
    if ("B", fr) not in _BODY:
        R = 6.2
        ph = fr * math.pi / 2.0
        sw = [(math.cos(ph) * 2.6, math.sin(ph) * 2.6), (math.cos(ph + math.pi) * 2.1, math.sin(ph + math.pi) * 2.1)]

        def fn(u, v):
            r = math.hypot(u, v)
            if r > R:
                return None
            if math.hypot(u + 2.4, v + 2.4) < 1.25:
                return P[0]
            for k, (a, b) in enumerate(sw):
                if math.hypot(u - a, v - b) < (1.25 if k == 0 else 0.95):
                    return P[2] if k == 0 else P[3]
            if r > R - 1.6:
                return P[2]
            return P[4] if r > 2.9 else P[5]
        A, ins = tex(15, 15, fn)
        _BODY[("B", fr)] = pad(outline(A, ins))
    return _BODY[("B", fr)]


def body_C(fr):
    """Konturuz ışık çekirdeği (elips), uçuş yönünde uzun."""
    if ("C", fr) not in _BODY:
        def fn(u, v):
            q = math.hypot(u / 6.2, v / 3.7)
            if q > 1.0:
                return None
            if q < 0.38:
                return P[0]
            if q < 0.66:
                return P[1]
            if q < 0.86:
                return P[2]
            return (P[3], 0.75)
        A, _ = tex(15, 9, fn)
        _BODY[("C", fr)] = pad(A)
    return _BODY[("C", fr)]


D_PUFFS = [(-2.1, 1.6, 4.6), (3.0, 1.0, 4.0), (0.4, -2.5, 4.4), (-5.1, -0.5, 3.3), (4.7, -2.1, 2.8)]


def body_D(fr):
    """Bulut topu: 5 yuvarlak top tek kütle, ton kütlenin yüksekliğine göre 4 düz basamak, kontur yok; 2 kare kabarma."""
    if ("D", fr) not in _BODY:
        g = 1.0 if fr == 0 else 1.07

        def fn(u, v):
            if not any(math.hypot(u - a, v - b) <= r * g for a, b, r in D_PUFFS):
                return None
            hgt = (v + 6.5) / 12.0 + u * 0.025  # üst açık, alt koyu (kütlenin tamamı)
            idx = 1 if hgt < 0.28 else (2 if hgt < 0.55 else (3 if hgt < 0.8 else 4))
            return P[idx]
        A, _ = tex(23, 19, fn)
        _BODY[("D", fr)] = pad(A)
    return _BODY[("D", fr)]


def body_cur(fr):
    if ("cur", 0) not in _BODY:
        _BODY[("cur", 0)] = np.asarray(asset("assets/weapons/mermi/dart_govde.png"), dtype=np.float32)
        sh = asset("assets/weapons/mermi/dart_iz.png")
        fw = sh.width // 5
        _BODY[("cur_iz", 0)] = np.asarray(sh.crop((3 * fw, 0, 4 * fw, sh.height)), dtype=np.float32)
        _BODY[("cur_iz", 1)] = np.asarray(sh.crop((4 * fw, 0, 5 * fw, sh.height)), dtype=np.float32)
    return _BODY[("cur", 0)]


# ------------------------------------------------------------------ parçacıklar
class Pt:
    __slots__ = ("x", "y", "vx", "vy", "g", "life", "age", "kind", "gy", "r", "seed", "layer")

    def __init__(self, x, y, vx, vy, life, kind, layer, g=0.0, gy=None, r=1.0, seed=0):
        self.x, self.y, self.vx, self.vy, self.g = x, y, vx, vy, g
        self.life, self.age, self.kind, self.layer = life, 0.0, kind, layer
        self.gy, self.r, self.seed = gy, r, seed


_DAMLA = None


def damla_sheet():
    global _DAMLA
    if _DAMLA is None:
        _DAMLA = np.asarray(asset("assets/fx/projectile_trails/zehir_damla_sheet.png"), dtype=np.float32)
    return _DAMLA


def disc(L, cx, cy, r, colfn, a):
    """Doku ızgarasında dolu daire; colfn(dx, dy) -> renk."""
    ri = int(math.ceil(r))
    for dy in range(-ri, ri + 1):
        for dx in range(-ri, ri + 1):
            if dx * dx + dy * dy <= r * r + 0.3:
                L.put(cx + dx, cy + dy, colfn(dx, dy), a)


def draw_pt(p, L):
    f = min(1.0, p.age / p.life)
    a = AP.band(1.0 - f) if f > 0.45 else 1.0
    cx, cy = L.tc(p.x, p.y)
    k = p.kind
    if k == "drop":  # düşen damla: 2x2 (hızlanınca 2x3), üst açık, alt koyu
        n = 3 if p.vy > 120 else 2
        for i in range(n):
            col = P[1] if i == 0 else (P[3] if i < n - 1 else P[4])
            L.put(cx, cy - n + 1 + i, col, 1.0)
            L.put(cx + 1, cy - n + 1 + i, P[2] if i == 0 else P[4], 1.0)
    elif k == "drop_big":  # uçtan kopan damla: 2x2 + parlama
        L.put(cx, cy, P[1], 1.0)
        L.put(cx + 1, cy, P[3], 1.0)
        L.put(cx, cy + 1, P[3], 1.0)
        L.put(cx + 1, cy + 1, P[4], 1.0)
    elif k == "splat":  # yerde gölcük (yassı elips, koyu kenar), sonlara doğru 4 adımda söner
        a = AP.band(1.0 - (f - 0.5) / 0.5) if f > 0.5 else 1.0
        rx, ry = p.r, max(1.0, p.r * 0.5)
        for dy in range(-int(ry), int(ry) + 1):
            for dx in range(-int(rx), int(rx) + 1):
                q = (dx / (rx + 0.3)) ** 2 + (dy / (ry + 0.3)) ** 2
                if q <= 1.0:
                    L.put(cx + dx, cy + dy, P[4] if q > 0.55 else P[3], a * 0.9)
        L.put(cx - int(rx * 0.4), cy - (1 if ry >= 1.5 else 0), P[1], a * 0.9)
    elif k == "bubble":  # kabarcık: halka + krem parlama, merkez yarı saydam
        r = p.r * (1.0 + 0.35 * f)
        ri = int(round(r))
        if ri <= 1:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                L.put(cx + dx, cy + dy, P[2], a)
            L.put(cx, cy, P[4], a * 0.5)
            L.put(cx - 1, cy - 1, P[0], a)
        else:
            for dy in range(-ri, ri + 1):
                for dx in range(-ri, ri + 1):
                    d2 = dx * dx + dy * dy
                    if (ri - 0.7) ** 2 <= d2 <= (ri + 0.4) ** 2:
                        L.put(cx + dx, cy + dy, P[2], a)
                    elif d2 < (ri - 0.7) ** 2:
                        L.put(cx + dx, cy + dy, P[4], a * 0.45)
            L.put(cx - 1, cy - 1, P[0], a)
    elif k == "pop":  # patlama: 4 çapraz piksel dışa
        d = 1 + int(f * 2.0)
        for dx, dy in ((d, d), (-d, d), (d, -d), (-d, -d)):
            L.put(cx + dx, cy + dy, P[1], AP.band(1.0 - f))
    elif k == "dot":  # Sade Toz: 1-2 px tanecik, renk adımıyla söner
        idx = min(4, 1 + int(f * 4.0))
        L.put(cx, cy, P[idx], a)
        if p.r > 1.2 and f < 0.5:
            L.put(cx + 1, cy, P[idx], a)
    elif k == "mote":  # ışık izi zerresi
        L.put(cx, cy, P[1] if f < 0.5 else P[2], a)
    elif k == "puff":  # konturuz buhar topu: büyür, üst açık / alt koyu 3 ton, 4 adımda söner
        r = p.r * (0.55 + 0.75 * math.sqrt(f))
        aa = AP.band((1.0 - f) * 0.85)

        def cf(dx, dy):
            hh = (dy + r) / (2.0 * r + 0.01)
            return P[1] if hh < 0.35 else (P[2] if hh < 0.7 else P[3])
        disc(L, cx, cy, r, cf, aa)
    elif k == "flash":  # krem artı parlama
        rr = 1 + int((1.0 - f) * 2.5)
        L.plus(cx, cy, rr, P[0], [P[1], P[2], P[3]], AP.band(1.0 - f))
    elif k == "cur_drip":  # ŞU AN: zehir_damla sayfası (sütun = ömür karesi)
        sh = damla_sheet()
        cell = 5
        cols, rows = sh.shape[1] // cell, max(1, sh.shape[0] // cell)
        fi = min(cols - 1, int(f * cols))
        row = p.seed % rows
        sub = sh[row * cell:(row + 1) * cell, fi * cell:(fi + 1) * cell]
        for yy in range(cell):
            for xx in range(cell):
                al = sub[yy, xx, 3] / 255.0
                if al > 0.02:
                    L.put(cx + xx - 2, cy + yy - 2, tuple(sub[yy, xx, :3]), al)


def step_pts(pts, ground_out):
    keep = []
    for p in pts:
        p.age += DT
        p.vy += p.g * DT
        p.x += p.vx * DT
        p.y += p.vy * DT
        if p.gy is not None and p.y >= p.gy and p.kind in ("drop", "drop_big"):
            ground_out.append(Pt(p.x, p.gy, 0, 0, 0.75, "splat", p.layer, r=3.0 if p.kind == "drop" else 2.5))
            continue
        if p.age >= p.life:
            if p.kind == "bubble":
                keep.append(Pt(p.x, p.y, 0, 0, 0.09, "pop", p.layer))
            continue
        keep.append(p)
    return keep


# ------------------------------------------------------------------ çeşitler
class Variant:
    def __init__(self, code):
        self.code = code
        self.rng = random.Random(1234 + ORDER.index(code))
        self.pts = []  # hava
        self.gnd = []  # yer
        self.projs = []
        self.acc_tip = 0.0
        self.hits = []  # (t, x, y)

    # -- uç
    def emit_tip(self, tip, Pp, speed):
        c, rng = self.code, self.rng
        if c == "cur":
            return
        rate = {"A": 1.6 + 0.012 * speed, "B": 5.0 + 0.035 * speed, "C": 10.0 + 0.33 * min(220.0, speed), "D": 4.5 + 0.03 * speed}[c]
        self.acc_tip += rate * DT
        while self.acc_tip >= 1.0:
            self.acc_tip -= 1.0
            if c == "A":
                self.pts.append(Pt(tip[0] + rng.uniform(-0.6, 0.6), tip[1] + 1.0, rng.uniform(-4, 4), rng.uniform(5, 20), 3.0, "drop_big", "tip",
                                   g=GRAV, gy=Pp[1] + FEET))
            elif c == "B":
                self.pts.append(Pt(tip[0] + rng.uniform(-1.5, 1.5), tip[1] + rng.uniform(-1, 1), rng.uniform(-6, 6), rng.uniform(-22, -12),
                                   rng.uniform(0.35, 0.6), "bubble", "tip", r=1.0))
            elif c == "C":
                self.pts.append(Pt(tip[0] + rng.uniform(-1, 1), tip[1] + rng.uniform(-1, 1), rng.uniform(-6, 6), rng.uniform(4, 14),
                                   rng.uniform(0.3, 0.5), "dot", "tip", r=rng.choice((1.0, 1.0, 2.0))))
            else:
                self.pts.append(Pt(tip[0] + rng.uniform(-1, 1), tip[1], rng.uniform(-5, 5), rng.uniform(-16, -9),
                                   rng.uniform(0.45, 0.7), "puff", "tip", r=rng.uniform(1.4, 2.0)))

    # -- atış
    def fire(self, tip, Pp, t):
        dx, dy = SLIME_C[0] - tip[0], SLIME_C[1] - tip[1]
        L = math.hypot(dx, dy)
        h0 = Pp[1] + FEET - tip[1]
        self.projs.append({"x": tip[0], "y": tip[1], "dx": dx / L, "dy": dy / L, "L": L, "s": 0.0, "h0": h0, "t0": t, "acc": 0.0,
                           "hist": [(tip[0], tip[1])]})

    def step_projs(self, t):
        c, rng = self.code, self.rng
        keep = []
        for pr in self.projs:
            pr["x"] += pr["dx"] * PROJ_SPEED * DT
            pr["y"] += pr["dy"] * PROJ_SPEED * DT
            pr["s"] = min(1.0, pr["s"] + PROJ_SPEED * DT / pr["L"])
            pr["hist"] = (pr["hist"] + [(pr["x"], pr["y"])])[-6:]
            h = pr["h0"] + (SLIME_FEET - SLIME_C[1] - pr["h0"]) * pr["s"]
            gy = pr["y"] + h
            tx, ty = pr["x"] - pr["dx"] * 5.5, pr["y"] - pr["dy"] * 5.5  # kuyruk
            rate = {"cur": 45.0, "A": 26.0, "B": 32.0, "C": 24.0, "D": 38.0}[c]
            pr["acc"] += rate * DT
            while pr["acc"] >= 1.0:
                pr["acc"] -= 1.0
                if c == "cur":
                    self.pts.append(Pt(tx, ty, rng.uniform(-3, 3), rng.uniform(0, 5), 0.33, "cur_drip", "proj", g=80.0, seed=rng.randrange(8)))
                elif c == "A":
                    self.pts.append(Pt(tx + rng.uniform(-1, 1), ty, pr["dx"] * 40.0, pr["dy"] * 40.0 + rng.uniform(0, 20), 3.0, "drop", "proj",
                                       g=GRAV, gy=gy))
                elif c == "B":
                    nx, ny = -pr["dy"], pr["dx"]
                    o = rng.uniform(-2.5, 2.5)
                    self.pts.append(Pt(tx + nx * o, ty + ny * o, rng.uniform(-4, 4), rng.uniform(-14, -6), rng.uniform(0.3, 0.5), "bubble",
                                       "proj", r=rng.choice((2.0, 2.0, 3.0))))
                elif c == "C":
                    self.pts.append(Pt(tx + rng.uniform(-1.5, 1.5), ty + rng.uniform(-1.5, 1.5), rng.uniform(-5, 5), rng.uniform(4, 12),
                                       rng.uniform(0.25, 0.4), "mote", "proj"))
                else:
                    self.pts.append(Pt(tx + rng.uniform(-1, 1), ty + rng.uniform(-1, 1), rng.uniform(-6, 6), rng.uniform(-10, -3),
                                       rng.uniform(0.4, 0.6), "puff", "proj", r=rng.uniform(3.8, 5.2)))
            if math.hypot(pr["x"] - SLIME_C[0], pr["y"] - SLIME_C[1]) <= 6.0:
                self.hit(pr["x"], pr["y"], t)
                continue
            keep.append(pr)
        self.projs = keep

    def hit(self, x, y, t):
        c, rng = self.code, self.rng
        self.hits.append((t, x, y))
        if c == "A":
            for i in range(6):
                ang = -math.pi / 2.0 + (i - 2.5) * 0.42 + rng.uniform(-0.1, 0.1)
                sp = rng.uniform(45, 75)
                self.pts.append(Pt(x, y, math.cos(ang) * sp, math.sin(ang) * sp, 3.0, "drop", "proj", g=GRAV, gy=SLIME_FEET + rng.uniform(-2, 3)))
            self.gnd.append(Pt(x, SLIME_FEET + 1.0, 0, 0, 0.9, "splat", "proj", r=5.0))
        elif c == "B":
            for i in range(6):
                ang = i * math.pi / 3.0 + rng.uniform(-0.2, 0.2)
                sp = rng.uniform(25, 40)
                self.pts.append(Pt(x, y, math.cos(ang) * sp, math.sin(ang) * sp - 6, rng.uniform(0.18, 0.3), "bubble", "proj",
                                   r=rng.choice((2.0, 3.0))))
        elif c == "C":
            self.pts.append(Pt(x, y, 0, 0, 0.14, "flash", "proj"))
            for i in range(8):
                ang = i * math.pi / 4.0
                self.pts.append(Pt(x, y, math.cos(ang) * 55, math.sin(ang) * 55, 0.22, "mote", "proj"))
        elif c == "D":
            for i in range(5):
                ang = i * 2.0 * math.pi / 5.0 + rng.uniform(-0.3, 0.3)
                self.pts.append(Pt(x + math.cos(ang) * 2, y + math.sin(ang) * 2, math.cos(ang) * 22, math.sin(ang) * 22 - 6,
                                   rng.uniform(0.45, 0.6), "puff", "proj", r=rng.uniform(3.5, 4.5)))

    def update(self):
        moved = []
        self.pts = step_pts(self.pts, moved)
        self.gnd = step_pts(self.gnd, []) + moved

    def draw_proj(self, F, view, t):
        c = self.code

        def S(p):
            return ((p[0] - view[0]) * Z, (p[1] - view[1]) * Z)
        for pr in self.projs:
            age = t - pr["t0"]
            ang = math.atan2(pr["dy"], pr["dx"])
            x, y = S((pr["x"], pr["y"]))
            if c == "cur":
                b = body_cur(0)
                iz = _BODY[("cur_iz", int(age * 25.0) % 2)]
                ox, oy = math.cos(ang) * -20.5 * WPP, math.sin(ang) * -20.5 * WPP
                ix, iy = S((pr["x"] + ox, pr["y"] + oy))
                blit2(F, iz, ix, iy, WPP * Z, ang)
                blit2(F, b, x, y, WPP * Z, ang)
            elif c == "A":
                blit2(F, body_A(int(age * 12.0) % 2), x, y, WPP * Z, ang)
            elif c == "B":
                blit2(F, body_B(int(age * 16.0) % 4), x, y, WPP * Z, 0.0)
            elif c == "C":
                blit2(F, body_C(0), x, y, WPP * Z, ang)
            else:
                blit2(F, body_D(int(age * 8.0) % 2), x, y, WPP * Z, 0.0)

    def draw_streak(self, L):
        """C: mermiden geriye sivrilen ışık izi (doku ızgarasında satır satır, 4 adımda söner)."""
        if self.code != "C":
            return
        for pr in self.projs:
            n = 36
            for i in range(n):
                f = i / float(n)
                d = 4.0 + i * 1.0
                wx, wy = pr["x"] - pr["dx"] * d * WPP, pr["y"] - pr["dy"] * d * WPP
                cx, cy = L.tc(wx, wy)
                w = 2 if f < 0.3 else (1 if f < 0.7 else 0)
                col = P[1] if f < 0.25 else (P[2] if f < 0.55 else P[3])
                a = AP.band(1.0 - f * 0.9)
                nx, ny = -pr["dy"], pr["dx"]
                for k in range(-w, w + 1):
                    L.put(int(round(cx + nx * k)), int(round(cy + ny * k)), col if abs(k) < w or w == 0 else P[3], a)


def render_variant(code, at_times=None):
    v = Variant(code)
    fo = Follow("zehir", ang=0.0)
    n = len(TRACK)
    frames, snaps = [], {}
    prev_tip = None
    shot_ticks = {int(round(s * TICK)) for s in SHOTS}
    for lap in range(3):
        v.acc_tip = 0.0
        for i in range(n):
            st = TRACK[i]
            t = st["t"]
            pos, rot, tip = fo.step(st, aim=SLIME_C)
            sp = 0.0 if prev_tip is None else math.hypot(tip[0] - prev_tip[0], tip[1] - prev_tip[1]) / DT
            prev_tip = tip
            v.update()
            v.emit_tip(tip, st["P"], sp)
            if i in shot_ticks:
                v.fire(tip, st["P"], lap * LOOP + t)
            v.step_projs(lap * LOOP + t)
            if lap < 2:
                continue
            want = i % STEP_OUT == 0 and at_times is None
            snap = at_times is not None and any(abs(t - a) < DT * 0.5 for a in at_times)
            if not (want or snap):
                continue
            F = AP.bg_crop(Z, VIEW)

            def S(p):
                return ((p[0] - VIEW[0]) * Z, (p[1] - VIEW[1]) * Z)
            mk = lambda tx: AP.Layer(VIEW[0], VIEW[1], VIEW[2] - VIEW[0], VIEW[3] - VIEW[1], tx)  # noqa: E731
            gP, gT, aP, aT = mk(WPP), mk(CHAR_K), mk(WPP), mk(CHAR_K)
            for p in v.gnd:
                draw_pt(p, gP if p.layer == "proj" else gT)
            gP.composite(F, Z)
            gT.composite(F, Z)
            ex, ey = S((SLIME_C[0], SLIME_C[1] - 1.0))
            blit2(F, slime_frame(t), ex, ey, SLIME_K * Z)
            tnow = lap * LOOP + t
            if any(0.0 <= tnow - ht < 0.12 for ht, _, _ in v.hits):
                blit2(F, slime_frame(t), ex, ey, SLIME_K * Z, alpha=0.7, tint=(255, 255, 255))
            AP.draw_char(F, Z, VIEW, st)
            draw_staff(F, VIEW, pos, rot, st["P"])
            v.draw_streak(aP)
            aP.composite(F, Z)
            aP = mk(WPP)
            v.draw_proj(F, VIEW, tnow)
            for p in v.pts:
                draw_pt(p, aP if p.layer == "proj" else aT)
            aP.composite(F, Z)
            aT.composite(F, Z)
            im = Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")
            if want:
                frames.append(im)
            if snap:
                snaps[round(t, 3)] = (im, [(pr["x"], pr["y"]) for pr in v.projs], pos)
    return frames if at_times is None else snaps


TITLES = {
    "cur": ("ŞU AN", "bambu dart + damla izi, uçta partikül yok"),
    "A": ("A · Zehir Damlası", "damlalar kopup yere düşer, gölcük"),
    "B": ("B · Zehir Küresi", "dönen ışıklı küre, kabarcık izi"),
    "C": ("C · Zehir Işığı", "Arcane/Buz gibi ışık izi, uçta Sade Toz"),
    "D": ("D · Zehir Bulutu", "konturuz bulut topu, buhar izi"),
}
ORDER = ["cur", "A", "B", "C", "D"]


def tile(im, code):
    d = ImageDraw.Draw(im)
    label(d, 6, 4, TITLES[code][0], 12)
    label(d, 6, 19, TITLES[code][1], 10, (226, 220, 204))
    return im


def info_panel(w, h):
    im = Image.new("RGB", (w, h), (30, 34, 32))
    d = ImageDraw.Draw(im)
    lines = ["Oyun ölçeği: 1080p, kamera zoom 2", "Asa: masaüstü çizimi, HÜCUM tepe slotu", "Atış ~1 sn (oyunda 2 sn; %100 saldırı",
             "  hızıyla 1 sn), mermi 460 px/sn", "Mermi pikseli 0,575 = silah pikseli", "Uç partikülü 0,903 = karakter pikseli",
             "Mekanik/hasar aynı - sadece görünüş"]
    for k, s in enumerate(lines):
        label(d, 10, 12 + k * 17, s, 11, (226, 220, 204))
    return im


def grid(ims, cols, gap=4, bg=(18, 20, 20)):
    w, h = ims[0].width, ims[0].height
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGB", (cols * w + (cols - 1) * gap, rows * h + (rows - 1) * gap), bg)
    for k, im in enumerate(ims):
        out.paste(im, ((k % cols) * (w + gap), (k // cols) * (h + gap)))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    gi = os.path.join(os.path.dirname(OUT), ".gdignore")
    if not os.path.exists(gi):
        open(gi, "w").close()
    allf = {}
    for c in ORDER:
        allf[c] = render_variant(c)
        print(c, len(allf[c]))
    n = min(len(f) for f in allf.values())
    w, h = allf["cur"][0].size
    info = info_panel(w, h)
    head = header(3 * w + 8, "ZEHİR ASASI - mermi + asa ucu partikülü prototipleri (oyuna bağlı DEĞİL)",
                  "mekanik aynı; seçilen çeşit oyuna bağlanır (yerel + uzak oyuncu)")
    frames = []
    for i in range(n):
        g = grid([tile(allf[c][i].copy(), c) for c in ORDER] + [info], 3)
        out = Image.new("RGB", (g.width, g.height + head.height), (18, 20, 20))
        out.paste(head, (0, 0))
        out.paste(g, (0, head.height))
        frames.append(out)
    save_gif(frames, os.path.join(OUT, "zehir_oyun.gif"), FPS_OUT, [8, 30, 70, 100])
    # özet: uçuşun ortası (atıştan 0,13 sn sonra) + mermi çevresi x2
    tmid = SHOTS[0] + 0.15
    twalk = 2.18  # sağa yürürken (1,7 - 2,3 sn), atıştan önce
    tops, zooms, tips = [], [], []
    for c in ORDER:
        snaps = render_variant(c, at_times=[tmid, twalk])
        near = lambda tt: snaps[min(snaps, key=lambda k: abs(k - tt))]  # noqa: E731
        im, pp, _ = near(tmid)
        wim, _, spos = near(twalk)
        sx, sy = int((spos[0] - 14.0 - VIEW[0]) * Z), int((spos[1] + 8.0 - VIEW[1]) * Z)
        tips.append(wim.crop((sx - 90, sy - 60, sx + 90, sy + 60)).resize((360, 240), Image.NEAREST))
        tops.append(tile(im.copy(), c))
        px, py = pp[0] if pp else (START[0] + 60.0, START[1] - 45.0)
        cx = int((px - 12.0 - VIEW[0]) * Z)
        cy = int((py - VIEW[1]) * Z)
        zc = im.crop((cx - 90, cy - 60, cx + 90, cy + 60)).resize((360, 240), Image.NEAREST)
        zooms.append(zc)
    row1 = grid(tops, 5)
    row2 = grid([z.resize((w, int(w * 240 / 360)), Image.NEAREST) for z in zooms], 5)
    row3 = grid([z.resize((w, int(w * 240 / 360)), Image.NEAREST) for z in tips], 5)
    hh = header(row1.width, "ZEHİR ASASI - uçuşun ortası / mermi çevresi x2 / yürürken asa ucu x2",
                "ŞU AN / A Damla / B Küre / C Işık / D Bulut (1080p oyun ölçeği; alt iki satır x2 yakın)")
    ozet = Image.new("RGB", (row1.width, hh.height + row1.height + row2.height + row3.height + 12), (18, 20, 20))
    ozet.paste(hh, (0, 0))
    ozet.paste(row1, (0, hh.height + 4))
    ozet.paste(row2, (0, hh.height + row1.height + 8))
    ozet.paste(row3, (0, hh.height + row1.height + row2.height + 12))
    ozet.save(os.path.join(OUT, "zehir_ozet.png"))
    print("ozet", os.path.join(OUT, "zehir_ozet.png"))


if __name__ == "__main__":
    main()
