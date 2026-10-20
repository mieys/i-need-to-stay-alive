# -*- coding: utf-8 -*-
"""YAKIN DÖVÜŞ VURUŞ İZİ prototipleri (2026-10-19, oyuna bağlı DEĞİL). Kullanıcı: "yakın dövüş silahları saldırı esnasında silah
türlerine bağlı olarak arkasında iz bıraksın iyi bir vuruş hissiyatı sağlasınlar."

ŞU AN (oyundaki, birebir): Uzunkılıç = sword_swing_math.gd yayı + pişmiş hilal (sweep_sheet, 26 fps) + kesik parlaması (sword_hit);
Bıçak = "Kıvılcım Saplama" (bicak_proto B = dagger_stab_math / stab_sheet); Topuz = "Yer Sarsıntısı" (topuz_proto A: iz = tek kısa
çelik leke 0,035 sn); Pençe = "Kanca Çekiş" (pence_proto B: atılışta 0,03 sn'lik 3 kısa iz). Yeni yönler hareketi ve isabet
efektlerini (çatlak, toz, yıldız, kıvılcım) DEĞİŞTİRMEZ; sadece silahın arkasındaki izi değiştirir (Kılıçta pişmiş hilal yerine).

İz = silahın GERÇEK geçmiş konumlarından (hareket matematiği ile örneklenir), sadece vuruş anlarında (kılıç süpürmesi
0,11-0,26; bıçak 3 saplama; topuz iniş 0,21-0,27; pençe atılış + yırtma). Piksel = silah pikseli 0,575 dünya px (mevcut yakın
dövüş efektleriyle aynı), dither YOK (düz renk + 4 adım saydamlık), uçlar sivrilir.
  A Dolu Hilal         - bıçağın taradığı alan dolu leke (anime "smear"): ön kenarda beyaz parlama, keskin kenar açık çizgi,
                         kuyruk koyulaşıp içten dışa incelir. Kılıç geniş çelik hilal, bıçak sivri saplama kaması, topuz kalın
                         ağır yay (sap ortasından baş dışına), pençe 3 ince tırnak şeridi.
  B Uç Çizgileri       - sadece ince hız çizgileri (1 px): kılıçta 3 (uç, 3/4, yarı), bıçakta uç + iki yan çizgi, topuzda başın
                         4 çizgisi (kalın orta), pençede 3 tırnak ucu; daha uzun kalır, bantlarla söner.
  C Işık Kesiği        - havada daha uzun asılı kalan 2-3 px parlak kesik çizgisi (kuyruktan yenir) + silah türüne göre
    + Kıvılcım           parçacık: kılıç çelik parıltı + temas kıvılcımı, bıçak krem kıvılcım, topuz toz pufu + taş kırığı,
                         pençe kor kıvılcımı (geriye, yırtma yönünde).
Çıktılar (out/yakin_iz/): iz_<silah>.gif (1080p oyun ölçeği, gerçek hız, ŞU AN + A/B/C), iz_yavas.gif (hepsi, x0,25 yavaş,
hedef çevresi), iz_ozet.png (vuruş anı kareleri).
Çalıştırma: python tools/proto_20261019/yakin_iz_proto.py [oyun|yavas|ozet]   (argümansız: hepsi)
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "proto_20261017")))
import bicak_proto as BP  # noqa: E402
import topuz_proto as TP  # noqa: E402
import pence_proto as PP  # noqa: E402
from mermi_proto import asset  # noqa: E402
from asa_partikul_proto import Layer, tile_label, hstack, hx, ramp  # noqa: E402
from bicak_proto import header, stack_v, save_gif  # noqa: E402

OUT = os.path.join(HERE, "out", "yakin_iz")
WPP = 0.575
Z = 2.0
D2R = math.pi / 180.0
FWD = -math.pi / 4.0
INTERVAL = BP.INTERVAL
FPS = 30

STEEL = ramp("#ffffff #dcefff #a2c8ea #6c98c4")  # ŞU AN kılıç hilalinin çelik mavisi
CREAM = ramp("#ffffff #fff2c4 #fbd27a #ee9c42")
MACE = ramp("#fffaf0 #ece2cc #c4b28e #8e7a58")  # topuz: sıcak toz tonu (kılıçtan ayrılsın)
HOOK = ramp("#ffffff #fff2c4 #fbd27a #e0a040")
DUST = ramp("#f6eedc #e0d2b2 #bca782 #8e7a58")
STONE = ramp("#a89a84 #7a6c58 #5a4e40")
EMBER = ramp("#fff6c8 #fdd85a #f9ab2c #e0741e")


def dirv(a):
    return (math.cos(a), math.sin(a))


def add(p, q, k=1.0):
    return (p[0] + q[0] * k, p[1] + q[1] * k)


def lerp_ang(a, b, t):
    d = (b - a + math.pi) % (2 * math.pi) - math.pi
    return a + d * t


# ------------------------------------------------------------------ Uzunkılıç (sword_swing_math.gd, k = 1)
SW_CHAR, SW_TGT, SW_REST = TP.CHAR, TP.TGT, TP.REST_C
_d = (SW_TGT[0] - SW_CHAR[0], SW_TGT[1] - SW_CHAR[1])
_L = math.hypot(*_d)
SW_DIR = (_d[0] / _L, _d[1] / _L)
SW_MID = math.atan2(SW_DIR[1], SW_DIR[0])
SW_PIVOT = add(SW_TGT, SW_DIR, -30.0)
SW_APPROACH, SW_SWEEP, SW_FOLLOW, SW_RETURN = 0.11, 0.15, 0.06, 0.26
SW_CONTACT = SW_APPROACH + SW_SWEEP * 0.5
SW_HALF = 75.0 * D2R
SW_TIP_F, SW_BASE_F = 13.4, -3.5  # uzunkilic_L3: ileri eksende uç +23,3 sanat px (x0,575), kabza tarafı


def sw_side(n):
    return -1.0 if n % 2 == 0 else 1.0  # weapon.gd: _sword_side = -_sword_side (ilk savuruş -1)


def sw_pose(ta, side):
    """(ikon merkezi, bıçak açısı)."""
    a0, a1 = SW_MID - side * SW_HALF, SW_MID + side * SW_HALF
    p0 = add(SW_PIVOT, dirv(a0), 17.0)
    p1 = add(SW_PIVOT, dirv(a1), 17.0)
    if ta < 0.0 or ta >= SW_APPROACH + SW_SWEEP + SW_FOLLOW + SW_RETURN:
        return SW_REST, FWD
    if ta < SW_APPROACH:
        x = ta / SW_APPROACH
        e = 1.0 - (1.0 - x) ** 3
        return (SW_REST[0] + (p0[0] - SW_REST[0]) * e, SW_REST[1] + (p0[1] - SW_REST[1]) * e), lerp_ang(FWD, a0, e)
    if ta < SW_APPROACH + SW_SWEEP:
        x = (ta - SW_APPROACH) / SW_SWEEP
        e = 0.5 - 0.5 * math.cos(math.pi * x)
        a = a0 + (a1 - a0) * e
        return add(SW_PIVOT, dirv(a), 17.0), a
    if ta < SW_APPROACH + SW_SWEEP + SW_FOLLOW:
        return p1, a1
    x = (ta - SW_APPROACH - SW_SWEEP - SW_FOLLOW) / SW_RETURN
    e = 0.5 - 0.5 * math.cos(math.pi * x)
    return (p1[0] + (SW_REST[0] - p1[0]) * e, p1[1] + (SW_REST[1] - p1[1]) * e), lerp_ang(a1, FWD, e)


_SW_ICON = None


def sw_icon():
    global _SW_ICON
    if _SW_ICON is None:
        _SW_ICON = np.asarray(asset("assets/weapons/zanaat/uzunkilic_L3.png"), dtype=np.float32)
    return _SW_ICON


def sheet(path, n, w, h):
    im = asset(path)
    return [np.asarray(im.crop((i * w, 0, i * w + w, h)), dtype=np.float32) for i in range(n)]


_SWEEP = None
_SWHIT = None


def sweep_frames():
    global _SWEEP, _SWHIT
    if _SWEEP is None:
        _SWEEP = sheet("assets/fx/sword_sweep/sweep_sheet.png", 8, 72, 72)
        _SWHIT = sheet("assets/fx/sword_hit/hit_sheet.png", 6, 30, 30)
    return _SWEEP, _SWHIT


# ------------------------------------------------------------------ silah tanımları: bıçak parçaları (taban, uç) + vuruş pencereleri
def blades_sword(ta, n):
    c, a = sw_pose(ta, sw_side(n))
    return [(add(c, dirv(a), SW_BASE_F), add(c, dirv(a), SW_TIP_F))]


_BMO = BP.DIRS["B"]["motion"]()


def blades_dagger(ta, n):
    p, a, sc = _BMO.pos(ta), _BMO.ang(ta), _BMO.scale(ta)
    return [(add(p, dirv(a), -9.5 * sc), add(p, dirv(a), 8.0 * sc))]  # (kabza ucu, bıçak ucu): dagger_L3 -17,7 / +14,8 sanat px


_TTR = TP.DIRS["A"]["track"]()
MACE_RH = 3.4  # baş yarıçapı (dünya)


def blades_mace(ta, n):
    x, y, a, sl, _ = _TTR.pose(ta)
    head = _TTR.head(ta)
    return [(add((x, y), dirv(a), TP.L_HEAD * sl * 0.45), add(head, dirv(a), MACE_RH))]


_PTR = PP.DIRS["B"]["track"]()


def blades_claw(ta, n):
    a = _PTR.pose(ta)[2]
    return [(add(tp, dirv(a), -3.0), tp) for tp in PP.tips(_PTR, ta)]


WEAPONS = {
    "uzunkilic": dict(name="Uzunkılıç", blades=blades_sword, win=[(SW_APPROACH, SW_APPROACH + SW_SWEEP)], cols=STEEL,
                      contacts=[SW_CONTACT], A=dict(win=0.075, linger=0.03, eat=0.06), B=dict(win=0.11, linger=0.04, eat=0.08),
                      C=dict(win=0.15, linger=0.08, eat=0.12), lines=[1.0, 0.78, 0.56], cut_w=2),
    "dagger": dict(name="Bıçak", blades=blades_dagger, win=[(0.09, 0.13), (0.19, 0.23), (0.29, 0.33)], cols=CREAM,
                   contacts=[0.13, 0.23, 0.33], A=dict(win=0.04, linger=0.025, eat=0.05), B=dict(win=0.05, linger=0.04, eat=0.07),
                   C=dict(win=0.05, linger=0.06, eat=0.09), cap_w=[4.6, 4.6, 6.2], side_lines=2.6, cut_w=2),
    "topuz": dict(name="Topuz", blades=blades_mace, win=[(0.21, TP.A_HIT)], cols=MACE, contacts=[TP.A_HIT],
                  A=dict(win=0.06, linger=0.04, eat=0.08), B=dict(win=0.08, linger=0.05, eat=0.09),
                  C=dict(win=0.08, linger=0.08, eat=0.12), cut_w=3),
    "pence": dict(name="Pençe", blades=blades_claw, win=[(0.10, PP.B_HIT1), (PP.B_DIG[1], PP.B_DIG[1] + 0.085)], cols=HOOK,
                  contacts=[PP.B_HIT1, PP.B_HIT2], A=dict(win=0.045, linger=0.03, eat=0.06), B=dict(win=0.06, linger=0.05, eat=0.08),
                  C=dict(win=0.06, linger=0.07, eat=0.1), cap_w=[2.4, 2.4], cut_w=1),
}
ORDER = ["uzunkilic", "dagger", "topuz", "pence"]
VARS = [("cur", "ŞU AN (oyundaki)", None), ("A", "A · Dolu Hilal", "bıçağın taradığı alan dolu leke, kuyruk incelir"),
        ("B", "B · Uç Çizgileri", "ince hız çizgileri, daha uzun kalır"),
        ("C", "C · Işık Kesiği + Kıvılcım", "asılı kalan parlak kesik + türüne göre parçacık")]
CUR_SUB = {"uzunkilic": "pişmiş çelik hilal (26 fps) + kesik parlaması",
           "dagger": "Kıvılcım Saplama: saplama kıvılcımı, ayrı iz yok",
           "topuz": "Yer Sarsıntısı: inişte 0,035 sn'lik tek kısa leke",
           "pence": "Kanca Çekiş: atılışta 0,03 sn'lik 3 kısa iz"}


def history(blades, n, ta, windows, cfg, h=1.0 / 360.0):
    """Her vuruş penceresi için bıçak parçalarının geçmişi: [ [(taban, uç) x parça] en yeni önce ], ve pencere no."""
    out = []
    for wi, (w0, w1) in enumerate(windows):
        if ta < w0:
            continue
        te = min(ta, w1)
        tb = max(w0, te - cfg["win"])
        if ta > w1 + cfg["linger"]:
            k = (ta - w1 - cfg["linger"]) / cfg["eat"]
            if k >= 1.0:
                continue
            tb += (te - tb) * k
        if te - tb < 0.002:
            continue
        m = max(2, int((te - tb) / h) + 1)
        out.append((wi, [blades(te - (te - tb) * i / (m - 1), n) for i in range(m)]))
    return out


# ------------------------------------------------------------------ çizim yardımcıları (Layer üstünde, vektörel)
def paint(L, m, C, A):
    if not m.any():
        return
    sub = L.a[m]
    a = A[m][:, None] if np.ndim(A) else np.full((int(m.sum()), 1), float(A), np.float32)
    sub[:, :3] = C[m] * a + sub[:, :3] * (1.0 - a) if np.ndim(C) == 3 else np.asarray(C, np.float32) * a + sub[:, :3] * (1.0 - a)
    sub[:, 3:4] = a + sub[:, 3:4] * (1.0 - a)
    L.a[m] = sub


def s_alpha(s):
    return np.where(s < 0.3, 1.0, np.where(s < 0.55, 0.75, np.where(s < 0.8, 0.5, 0.25))).astype(np.float32)


def fan(L, segs, cols, r0=0.3):
    """A: dolu tarama (hilal). segs = [(taban, uç)] en yeni önce (dünya). İç kenar yaşla dışa çekilir (kuyruk uca doğru incelir);
    renk iç kenardan dışa (dış kenar = keskin kenar, en açık), gövde yarı saydam, en yeni şerit parlar."""
    N = len(segs)
    if N < 2:
        return
    img = Image.new("I", (L.W, L.H), -1)
    d = ImageDraw.Draw(img)

    def T(p):
        return ((p[0] - L.x0) / L.tx, (p[1] - L.y0) / L.tx)
    for j in range(N - 2, -1, -1):
        b0, t0 = segs[j]
        b1, t1 = segs[j + 1]
        d.polygon([T(b0), T(t0), T(t1), T(b1)], fill=j)
    J = np.asarray(img, dtype=np.int32)
    m = J >= 0
    if not m.any():
        return
    ys, xs = np.nonzero(m)
    jj = J[m]
    B = np.array([T(sg[0]) for sg in segs], np.float32)
    Tp = np.array([T(sg[1]) for sg in segs], np.float32)
    bx, by = B[jj, 0], B[jj, 1]
    vx, vy = Tp[jj, 0] - bx, Tp[jj, 1] - by
    r = np.clip(((xs + 0.5 - bx) * vx + (ys + 0.5 - by) * vy) / np.maximum(vx * vx + vy * vy, 1e-6), 0.0, 1.0)
    s = jj / float(N - 1)
    r_in = r0 + (1.0 - r0) * s * 0.85
    keep = r >= r_in
    q = (r - r_in) / np.maximum(1.0 - r_in, 1e-3)
    ci = np.where(s < 0.08, 0, np.where(q > 0.8, 0, np.where(q > 0.5, 1, np.where(q > 0.25, 2, 3))))
    A = np.where(s < 0.3, 0.75, np.where(s < 0.85, 0.5, 0.25)).astype(np.float32)
    A = np.minimum(1.0, A + np.where((q > 0.8) | (s < 0.08), 0.25, 0.0))
    C = np.array(cols, np.float32)[ci]
    full_m = np.zeros(m.shape, bool)
    full_C = np.zeros(m.shape + (3,), np.float32)
    full_A = np.zeros(m.shape, np.float32)
    ys, xs, C, A = ys[keep], xs[keep], C[keep], A[keep]
    full_m[ys, xs] = True
    full_C[ys, xs] = C
    full_A[ys, xs] = A
    paint(L, full_m, full_C, full_A)


def capsule(L, pts, w0, cols):
    """A (bıçak / pençe): sivrilen dolu şerit. pts dünya, en yeni önce; w0 baş kalınlığı (dünya)."""
    if len(pts) < 2:
        return
    P = np.array([((p[0] - L.x0) / L.tx, (p[1] - L.y0) / L.tx) for p in pts], np.float32)
    hw0 = w0 / L.tx * 0.5
    x0, x1 = max(0, int(P[:, 0].min() - hw0 - 2)), min(L.W, int(P[:, 0].max() + hw0 + 3))
    y0, y1 = max(0, int(P[:, 1].min() - hw0 - 2)), min(L.H, int(P[:, 1].max() + hw0 + 3))
    if x0 >= x1 or y0 >= y1:
        return
    Y, X = np.mgrid[y0:y1, x0:x1].astype(np.float32) + 0.5
    best = np.full(X.shape, 1e9, np.float32)
    bs = np.zeros(X.shape, np.float32)
    n = len(P)
    for j in range(n - 1):
        ax, ay = P[j]
        bx, by = P[j + 1]
        dx, dy = bx - ax, by - ay
        ln2 = max(dx * dx + dy * dy, 1e-6)
        u = np.clip(((X - ax) * dx + (Y - ay) * dy) / ln2, 0.0, 1.0)
        dd = np.hypot(X - (ax + u * dx), Y - (ay + u * dy))
        s = (j + u) / (n - 1)
        hw = hw0 * (1.0 - s) ** 0.8 + 0.35
        rr = dd / hw
        upd = rr < best
        best = np.where(upd, rr, best)
        bs = np.where(upd, s, bs)
    inside = best <= 1.0
    ci = np.where(best < 0.45, np.where(bs < 0.5, 0, 1), np.where(best < 0.8, np.where(bs < 0.5, 1, 2), np.where(bs < 0.5, 2, 3)))
    C = np.array(cols, np.float32)[ci]
    A = s_alpha(bs)
    m = np.zeros((L.H, L.W), bool)
    Cf = np.zeros((L.H, L.W, 3), np.float32)
    Af = np.zeros((L.H, L.W), np.float32)
    m[y0:y1, x0:x1] = inside
    Cf[y0:y1, x0:x1] = C
    Af[y0:y1, x0:x1] = A
    paint(L, m, Cf, Af)


def polyline(L, pts, cols, w=1, head=True, glow=False):
    """B / C: ince çizgi (en yeni önce); renk + saydamlık yaşa göre bantlı. w = kalınlık (texel). glow: iki yanda yarı saydam bant."""
    n = len(pts)
    if n < 2:
        return
    T = [L.tc(p[0], p[1]) for p in pts]
    if glow:
        for j in range(n - 1):
            s = j / float(n - 1)
            if s > 0.7:
                break
            (xa, ya), (xb, yb) = T[j], T[j + 1]
            if (xa, ya) == (xb, yb):
                continue
            hor = abs(xb - xa) >= abs(yb - ya)
            for o in (-1, w):
                ox, oy = (0, o) if hor else (o, 0)
                L.line(xa + ox, ya + oy, xb + ox, yb + oy, cols[2], 0.5 if s < 0.35 else 0.25, skip_last=True)
    for j in range(n - 1):
        s = j / float(n - 1)
        col = cols[0] if s < 0.18 else cols[1] if s < 0.5 else cols[2] if s < 0.8 else cols[3]
        a = 1.0 if s < 0.35 else 0.75 if s < 0.6 else 0.5 if s < 0.85 else 0.25
        ww = w if s < 0.55 else max(1, w - 1)
        (xa, ya), (xb, yb) = T[j], T[j + 1]
        if (xa, ya) == (xb, yb):
            continue
        for o in range(ww):
            ox, oy = (0, o) if abs(xb - xa) >= abs(yb - ya) else (o, 0)
            L.line(xa + ox, ya + oy, xb + ox, yb + oy, col, a, skip_last=True)
    if head:
        L.put(T[0][0], T[0][1], cols[0], 1.0)


# ------------------------------------------------------------------ C parçacıkları (saldırı zamanına bağlı, analitik)
def make_particles(key):
    W = WEAPONS[key]
    rng = random.Random(ORDER.index(key) * 97 + 5)
    ps = []
    blades = W["blades"]
    if key == "uzunkilic":
        for i in range(5):  # süpürme boyunca çelik parıltı
            t0 = SW_APPROACH + SW_SWEEP * (0.15 + 0.17 * i)
            ps.append(dict(k="glint", t0=t0, life=0.24, r=4 if i in (1, 3) else 3, side_dep=True, frac=0.92 + rng.uniform(-0.05, 0.05)))
        for i in range(5):  # temas kıvılcımı
            a = SW_MID + rng.uniform(-0.7, 0.7)
            sp = rng.uniform(90, 150)
            ps.append(dict(k="spark", t0=SW_CONTACT, x=SW_TGT[0], y=SW_TGT[1] - 3.5, vx=math.cos(a) * sp, vy=math.sin(a) * sp, g=60.0,
                           life=rng.uniform(0.12, 0.2), cols=STEEL))
    elif key == "dagger":
        for ci, tc in enumerate(W["contacts"]):
            tip = blades(tc, 0)[0][1]
            for _ in range(5 if ci == 2 else 3):
                a = BP.DIR_ANG + rng.uniform(-0.6, 0.6)
                sp = rng.uniform(80, 140) * (1.2 if ci == 2 else 1.0)
                ps.append(dict(k="spark", t0=tc, x=tip[0], y=tip[1], vx=math.cos(a) * sp, vy=math.sin(a) * sp, g=80.0,
                               life=rng.uniform(0.1, 0.18), cols=CREAM))
    elif key == "topuz":
        head = blades(TP.A_HIT, 0)[0][1]
        for i in range(6):
            a = math.pi + (i / 5.0) * math.pi + rng.uniform(-0.2, 0.2)  # üst yarı
            ps.append(dict(k="puff", t0=TP.A_HIT - 0.01, x=head[0] + math.cos(a) * 4.0, y=head[1] + 2.0 + math.sin(a) * 2.0,
                           vx=math.cos(a) * rng.uniform(10, 22), vy=math.sin(a) * rng.uniform(4, 10) - 6.0, g=0.0,
                           life=rng.uniform(0.32, 0.45), r0=rng.choice([2, 3, 2])))
        for i in range(5):
            a = -math.pi / 2 + rng.uniform(-1.1, 1.1)
            sp = rng.uniform(50, 90)
            ps.append(dict(k="chip", t0=TP.A_HIT, x=head[0], y=head[1] + 1.0, vx=math.cos(a) * sp, vy=math.sin(a) * sp, g=420.0,
                           life=rng.uniform(0.25, 0.36)))
        for i in range(3):  # iniş boyunca hava kırıntısı
            t0 = 0.215 + 0.018 * i
            ps.append(dict(k="glint", t0=t0, life=0.16, r=2, side_dep=False, frac=1.0))
    else:
        for ci, tc in enumerate(W["contacts"]):
            tps = PP.tips(_PTR, tc)
            for tp in tps:
                for _ in range(2):
                    a = PP.DIR_ANG + math.pi + rng.uniform(-0.7, 0.7)  # oyuncuya doğru (yırtma)
                    sp = rng.uniform(60, 110)
                    ps.append(dict(k="spark", t0=tc, x=tp[0], y=tp[1], vx=math.cos(a) * sp, vy=math.sin(a) * sp, g=120.0,
                                   life=rng.uniform(0.14, 0.24), cols=EMBER))
    return ps


PARTS = {k: make_particles(k) for k in ORDER}


def draw_particles(L, key, ta, n):
    W = WEAPONS[key]
    for p in PARTS[key]:
        age = ta - p["t0"]
        if age < 0.0 or age >= p["life"]:
            continue
        f = age / p["life"]
        if p["k"] == "glint":
            bl = W["blades"](p["t0"], n)[0]
            b, t = bl
            x, y = L.tc(b[0] + (t[0] - b[0]) * p["frac"], b[1] + (t[1] - b[1]) * p["frac"])
            r = max(1, int(round(p["r"] * math.sin(math.pi * min(1.0, f * 1.15)))))
            L.plus(x, y, r, W["cols"][0], [W["cols"][1], W["cols"][2], W["cols"][3]], 1.0 if f < 0.7 else 0.75)
            continue
        px = p["x"] + p["vx"] * age
        py = p["y"] + p["vy"] * age + 0.5 * p["g"] * age * age
        x, y = L.tc(px, py)
        if p["k"] == "spark":
            vx, vy = p["vx"], p["vy"] + p["g"] * age
            Ln = math.hypot(vx, vy) + 1e-6
            tl = 3 if f < 0.5 else 2
            cols = p["cols"]
            L.line(x - int(round(vx / Ln * tl)), y - int(round(vy / Ln * tl)), x, y, cols[2] if f < 0.6 else cols[3], 0.75)
            L.put(x, y, cols[0] if f < 0.5 else cols[1], 1.0)
        elif p["k"] == "puff":
            r = p["r0"] + int(f * 2.0)
            col = DUST[0] if f < 0.3 else DUST[1] if f < 0.65 else DUST[2]
            a = 0.75 if f < 0.5 else 0.5 if f < 0.8 else 0.25
            for dy in range(-r, r + 1):
                for dx in range(-r - 1, r + 2):
                    if (dx / (r + 1.0)) ** 2 + (dy / float(r)) ** 2 <= 1.0:
                        L.put(x + dx, y + dy, col, a)
            L.put(x - 1, y - r + 1, DUST[0], a)
        elif p["k"] == "chip":
            col = STONE[0] if f < 0.5 else STONE[1]
            L.put(x, y, col, 1.0)
            L.put(x + 1, y, STONE[2], 1.0)
            L.put(x, y + 1, STONE[2], 1.0)


def draw_trail(F, key, var, ta, n, lw, lh):
    W = WEAPONS[key]
    cfg = W[var]
    L = Layer(0.0, 0.0, lw, lh, tx=WPP)
    for wi, hist in history(W["blades"], n, ta, W["win"], cfg):
        nb = len(hist[0])
        for bi in range(nb):
            segs = [h[bi] for h in hist]
            tips = [s[1] for s in segs]
            if var == "A":
                if key in ("uzunkilic", "topuz"):
                    fan(L, segs, W["cols"], r0=0.3 if key == "uzunkilic" else 0.5)
                else:
                    if key == "dagger" and len(tips) >= 2:
                        # saplama bıçağın kendi ekseninde (13 px): uç izi bıçağın altında kalırdı -> kama KABZANIN gerisinden, 10 px uzantı
                        bases = [sg[0] for sg in segs]
                        a = math.atan2(tips[0][1] - tips[-1][1], tips[0][0] - tips[-1][0])
                        tips = bases + [add(bases[-1], dirv(a), -10.0 * k / 4.0) for k in (1, 2, 3, 4)]
                    capsule(L, tips, W["cap_w"][min(wi, len(W["cap_w"]) - 1)], W["cols"])
            elif var == "B":
                if key == "uzunkilic":
                    for fr in W["lines"]:
                        polyline(L, [(b[0] + (t[0] - b[0]) * fr, b[1] + (t[1] - b[1]) * fr) for b, t in segs], W["cols"], 2 if fr == 1.0 else 1)
                elif key == "dagger":
                    polyline(L, tips, W["cols"], 2)
                    a = math.atan2(tips[0][1] - tips[-1][1], tips[0][0] - tips[-1][0])
                    pr = (-math.sin(a), math.cos(a))
                    m = len(tips)
                    for sg in (-1.0, 1.0):  # yan çizgiler: daha kısa, geriden
                        o = W["side_lines"] * sg
                        polyline(L, [add(p, pr, o) for p in tips[m // 4:]], W["cols"][1:] + [W["cols"][3]], 1, head=False)
                elif key == "topuz":
                    for fr, w in ((1.0, 1), (0.82, 2), (0.6, 1), (0.25, 1)):
                        polyline(L, [(b[0] + (t[0] - b[0]) * fr, b[1] + (t[1] - b[1]) * fr) for b, t in segs], W["cols"], w)
                else:
                    polyline(L, tips, W["cols"], 1)
            else:  # C
                polyline(L, tips, W["cols"], W["cut_w"], glow=True)
    if var == "C":
        draw_particles(L, key, ta, n)
    L.composite(F, Z)


# ------------------------------------------------------------------ şerit çizimleri
## True: yeni yönlerde de oyundaki iz/hilal (kılıç pişmiş hilal, topuz/pençe "live" lekesi) çizilir - yakin_ardil_proto.py (madde 299)
## mevcut efektlerin ÜSTÜNE ardıl görüntü ekler; draw_trail'i de kendi çizimiyle değiştirir (modül globali, çağrı anında okunur).
KEEP_CUR_FX = False


def flash_at(ta, t_hit):
    fl = ta - t_hit
    return 1.0 - fl / 0.12 if 0.0 <= fl < 0.12 else 0.0


class SwordLane:
    def __init__(self, idx):
        self.idx = idx

    def attack(self, t):
        if t < 0.15:
            return 99.0, 0
        n = int((t - 0.15) // INTERVAL)
        return t - 0.15 - n * INTERVAL, n

    def render(self, t, var):
        F = TP.lane_bg(self.idx)
        ta, n = self.attack(t)
        side = sw_side(n)
        tx, ty = TP.S(SW_TGT)
        fl = flash_at(ta, SW_CONTACT)
        TP.blit(F, TP.slime(), tx, ty - 2, TP.SLIME_K * Z)
        if fl > 0.0:
            TP.blit(F, TP.slime(), tx, ty - 2, TP.SLIME_K * Z, alpha=fl, tint=(255, 255, 255))
        if var != "cur":
            draw_trail(F, "uzunkilic", var, ta, n, TP.LWW, TP.LHW)
        c, a = sw_pose(ta, side)
        cx, cy = TP.S(c)
        TP.blit(F, sw_icon(), cx, cy, WPP * Z, a - FWD)
        sweep, hit = sweep_frames()
        if var == "cur" or KEEP_CUR_FX:
            fi = int((ta - SW_APPROACH) * 26.0)
            if 0 <= fi < 8 and ta >= SW_APPROACH:
                fr = sweep[fi][::-1] if side < 0 else sweep[fi]  # flip_v
                px, py = TP.S(SW_PIVOT)
                TP.blit(F, fr, px, py, 34.0 / 32.0 * Z, SW_MID)
        hi = int((ta - SW_CONTACT) * 24.0)
        if 0 <= hi < 6 and ta >= SW_CONTACT:
            TP.blit(F, hit[hi], tx, ty - 3.5 * Z, Z, SW_MID)
        return Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")


class DaggerLane:
    def __init__(self, idx):
        self.ln = BP.Lane("B", idx)

    def step(self, t, dt):
        self.ln.step(t, dt)

    def render(self, t, var):
        ln = self.ln
        if var == "cur":
            return ln.render(t)
        F = BP.lane_bg(ln.idx)
        ta, n = ln.attack_time(t)
        if ta is None:
            ta, n = 99.0, 0
        p, a, sc = ln.mo.pos(ta), ln.mo.ang(ta), ln.mo.scale(ta)
        ix, iy = BP.S(p)
        fl = flash_at(ta, ln.hits[0])
        tx, ty = BP.S(BP.TGT)
        BP.blit(F, BP.slime(), tx, ty - 2, BP.SLIME_K * Z)
        if fl > 0.0:
            BP.blit(F, BP.slime(), tx, ty - 2, BP.SLIME_K * Z, alpha=fl, tint=(255, 255, 255))
        draw_trail(F, "dagger", var, ta, n, BP.LWW, BP.LHW)
        BP.blit(F, BP.icon(), ix, iy, WPP * Z * sc, a - BP.REST_ANG)
        fxc = BP.S(BP.SC) if ln.mo.rot else BP.S(BP.TGT)
        BP.blit(F, ln.fx_canvas(ta), fxc[0], fxc[1], WPP * Z, BP.DIR_ANG, (BP.FXW / 2.0, BP.FXH / 2.0))
        im = Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")
        BP.draw_pts(im, ln.pts)
        return im


class MaceLane:
    def __init__(self, idx):
        self.ln = TP.Lane("A", idx)

    def render(self, t, var):
        ln = self.ln
        if var == "cur":
            return ln.render(t)
        F = TP.lane_bg(ln.idx)
        ta = ln.attack_time(t)
        n = 0 if t < 0.15 else int((t - 0.15) // INTERVAL)
        lay = ln.layers(ta)
        tx, ty = TP.S(TP.TGT)

        def put_layer(c):
            if c is not None:
                TP.blit(F, c[0], tx, ty, WPP * Z, 0.0, c[1])
        put_layer(lay["g"])
        fl = flash_at(ta, TP.A_HIT)
        for q in sorted([TP.TGT] + TP.EXTRA, key=lambda q: q[1]):
            sx, sy = TP.S(q)
            TP.blit(F, TP.slime(), sx, sy - 2, TP.SLIME_K * Z)
            if fl > 0.0:
                TP.blit(F, TP.slime(), sx, sy - 2, TP.SLIME_K * Z, alpha=fl, tint=(255, 255, 255))
        put_layer(lay["b"])
        if KEEP_CUR_FX and "live" in ln.D:
            L0 = TP.Lay()
            ln.D["live"](L0, ln.tr, ta)
            put_layer(L0.cropped())
        draw_trail(F, "topuz", var, ta, n, TP.LWW, TP.LHW)
        x, y, a, sl, sw = ln.tr.pose(ta)
        TP.blit_mace(F, TP.icon(), TP.S((x, y)), a, WPP * Z, ln.tr.piv, sl, sw)
        put_layer(lay["f"])
        return Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")


class ClawLane:
    def __init__(self, idx):
        self.ln = PP.Lane("B", idx)

    def render(self, t, var):
        ln = self.ln
        if var == "cur":
            return ln.render(t)
        F = PP.lane_bg(ln.idx)
        ta, n = ln.attack(t)
        lay = ln.layers(ta)
        tx, ty = PP.S(PP.TGT)

        def put_layer(c):
            if c is not None:
                PP.blit(F, c[0], tx, ty, WPP * Z, 0.0, c[1])
        put_layer(lay["g"])
        fl = flash_at(ta, PP.DIRS["B"]["hits"][0])
        for q in sorted([PP.TGT, PP.EXTRA_IN, PP.EXTRA_OUT], key=lambda q: q[1]):
            sx, sy = PP.S(q)
            PP.blit(F, PP.slime(), sx, sy - 2, PP.SLIME_K * Z)
            if fl > 0.0 and q is not PP.EXTRA_OUT:
                PP.blit(F, PP.slime(), sx, sy - 2, PP.SLIME_K * Z, alpha=fl, tint=(255, 255, 255))
        if KEEP_CUR_FX and "live" in ln.D:
            L0 = PP.Lay()
            ln.D["live"](L0, ln.tr, ta)
            put_layer(L0.cropped())
        draw_trail(F, "pence", var, ta, n, getattr(PP, "LWW", TP.LWW), getattr(PP, "LHW", TP.LHW))
        x, y, a, sl, sw = ln.tr.pose(ta)
        TP.blit_mace(F, PP.icon(), PP.S((x, y)), a, WPP * Z, ln.tr.piv, sl, sw)
        put_layer(lay["f"])
        return Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")


LANES = {"uzunkilic": SwordLane, "dagger": DaggerLane, "topuz": MaceLane, "pence": ClawLane}


def lane_set(key):
    return [LANES[key](i) for i in range(4)]


# ------------------------------------------------------------------ çıktılar
def build_oyun():
    os.makedirs(OUT, exist_ok=True)
    loop = 2.0 * INTERVAL
    nfr = int(round(loop * FPS))
    dt = loop / nfr
    for key in ORDER:
        lanes = lane_set(key)
        frames = []
        for i in range(nfr):
            t = i * dt
            parts = []
            for ln, (vid, title, sub) in zip(lanes, VARS):
                if hasattr(ln, "step"):
                    ln.step(t, dt)
                im = ln.render(t, vid)
                parts.append(tile_label(im, title, sub if vid != "cur" else CUR_SUB[key]))
            hd = header(parts[0].width, "%s · vuruş izi (prototip, oyuna bağlı değil)" % WEAPONS[key]["name"],
                        "1080p oyun ölçeği, gerçek hız · aralık %.2f sn · hareket ve isabet efektleri oyundaki gibi, sadece iz değişir" % INTERVAL)
            frames.append(stack_v([hd] + parts, 3))
        hit = WEAPONS[key]["contacts"][0] + 0.15
        save_gif(frames, os.path.join(OUT, "iz_%s.gif" % key), FPS, [int(hit * FPS), int((hit - 0.04) * FPS), int((hit + 0.06) * FPS)])


SLOW_CROP = {  # dünya: hedef çevresi
    "uzunkilic": (TP.TGT[0] - 78, TP.TGT[1] - 58, TP.TGT[0] + 34, TP.TGT[1] + 30),
    "dagger": (BP.TGT[0] - 70, BP.TGT[1] - 46, BP.TGT[0] + 34, BP.TGT[1] + 30),
    "topuz": (TP.TGT[0] - 78, TP.TGT[1] - 80, TP.TGT[0] + 34, TP.TGT[1] + 26),  # topuz başın üstüne kalkar
    "pence": (PP.TGT[0] - 78, PP.TGT[1] - 50, PP.TGT[0] + 34, PP.TGT[1] + 38),
}


def crop_cell(im, key):
    c = SLOW_CROP[key]
    return im.crop(tuple(int(v * Z) for v in c))


def build_yavas(speed=0.25):
    os.makedirs(OUT, exist_ok=True)
    span = 0.62
    nfr = int(round(span / speed * 25))
    sets = {k: lane_set(k) for k in ORDER}
    frames = []
    for i in range(nfr):
        ta = i * span / nfr
        t = 0.15 + ta
        rows = []
        for key in ORDER:
            cells = []
            for ln, (vid, title, _) in zip(sets[key], VARS):
                if hasattr(ln, "step"):
                    ln.step(t, span / nfr)
                cells.append(tile_label(crop_cell(ln.render(t, vid), key), "%s · %s" % (WEAPONS[key]["name"], title.split(" (")[0])))
            rows.append(hstack(cells))
        hd = header(rows[0].width, "Vuruş izleri · x0,25 yavaş (tek saldırı, hedef çevresi, 1080p ölçek)",
                    "ŞU AN · A Dolu Hilal · B Uç Çizgileri · C Işık Kesiği + Kıvılcım  ·  saldırı +%.2f sn" % ta)
        frames.append(stack_v([hd] + rows, 3))
    save_gif(frames, os.path.join(OUT, "iz_yavas.gif"), 25, [int(nfr * 0.3), int(nfr * 0.45), int(nfr * 0.55)])


def build_ozet():
    """Her silah için vuruş anına yakın 2 kare (ŞU AN + A/B/C), x2 büyütülmüş hedef çevresi."""
    os.makedirs(OUT, exist_ok=True)
    moments = {"uzunkilic": [0.16, 0.21], "dagger": [0.125, 0.33], "topuz": [0.255, 0.29], "pence": [0.14, 0.25]}
    rows = []
    for key in ORDER:
        for ta in moments[key]:
            lanes = lane_set(key)
            cells = []
            for ln, (vid, title, _) in zip(lanes, VARS):
                if hasattr(ln, "step"):
                    tt = 0.0
                    while tt < 0.15 + ta:
                        ln.step(tt, 1.0 / 120.0)
                        tt += 1.0 / 120.0
                c = crop_cell(ln.render(0.15 + ta, vid), key)
                c = c.resize((c.width * 2, c.height * 2), Image.NEAREST)
                cells.append(tile_label(c, "%s · %s · +%.3f sn" % (WEAPONS[key]["name"], title.split(" (")[0], ta)))
            rows.append(hstack(cells))
    im = stack_v([header(rows[0].width, "Vuruş izleri · özet (x2 yakın, 1080p ölçeğin iki katı)", "ŞU AN · A Dolu Hilal · B Uç Çizgileri · C Işık Kesiği + Kıvılcım")] + rows, 3)
    im.save(os.path.join(OUT, "iz_ozet.png"))
    print("ozet", im.size)


if __name__ == "__main__":
    what = sys.argv[1:] or ["ozet", "yavas", "oyun"]
    if "ozet" in what:
        build_ozet()
    if "yavas" in what:
        build_yavas()
    if "oyun" in what:
        build_oyun()
