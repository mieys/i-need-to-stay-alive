"""2026-11-16 BÜYÜCÜ KIZ - HORTUM için YENİ prototipler (kullanıcı: "Büyücü kızın hortum yeteneği için yeni prototipler hazırla").
OYUNA BAĞLI DEĞİL. MEKANİK AYNI (madde 178 dersi): 3 hortum (Büyü Fırtınası 5), 15 sn, 102 dünya/sn rastgele yaratıklara yürür,
temas 46 dünya, aynı yaratığa saniyede 1 vuruş, bitişte 0,8 sn çözülme. Oyundaki şimdiki görünüm = madde 188 (beyaz-lavanta DOLU sarmal
huni, `assets/fx/buyucu/hortum_*.png`, üretici `tools/gen_buyucu_fx.py` <- `proto_20261016/gen_buyucu_buyu.py tornado()`).

4 yön; her biri AYRI silüet + AYRI çizim eli (madde 241 sandık / 443 kart dersi: aynı elden çıkmış gibi durmasın):
  A Rüzgâr İpleri : dolu gövde YOK. Alttan doğup yükseldikçe genişleyen ince (1-2 px) rüzgâr halkaları + tek uzun sarmal iplik,
                    arkadakiler yarı saydam; yapraklar döner, tabanda ince toz çizgileri (çizgi dili - kum yılanları gibi, madde 718).
  B Arcane Girdap : KONTURSUZ, parlayan menekşe huni: beyaz çekirdek -> açık -> menekşe düz alfa bantları, nefes alan hale, tepede
                    kıvrılan ışık tutamları, sarmalda büyüyüp küçülen 4 kollu yıldızlar; ayak altında dönen 2:1 rün halkası.
                    Bitişte huni rüne çöker, rün parlar, yıldızlar yükselir.
  C Toz Şeytanı   : altı GENİŞ (etekli) kum sütunu, sel-out kontur (malzemenin koyu tonu, harita sanatı kuralı), sarmal kum çizgileri,
                    tepesi tutamlara ayrılıp saydamlaşır; çakıl / çimen / Set 2 sıcak kor zerreleri savrulur.
  D Halka Kulesi  : üst üste 5 kalın elips halka (yukarı büyür), yay gibi faz farkıyla salınır, kalın koyu kontur + 2 ton cel + dönen
                    beyaz parlak benek; delikten ince çekirdek görünür. Bitişte halkalar tepeden başlayarak uçup küçülerek söner.
DITHER YOK (kalıcı kural, "parazit"): solmalar katman başına düz alfa basamağı (1 / 0,75 / 0,5 / 0,25), saydamlık düz bantlar.
Ölçek: 1 GIF pikseli = 1 Büyücü sanat pikseli = 0,903 dünya. Özet GIF x2 ~ 1080p oyun ekranındaki boyut (kamera zoom 2).
Çıktı: out/hortum_{a,b,c,d}.gif (x3), out/hortum_ozet.gif (2x2, x2), out/hortum_sayfa.png (şimdiki + A-D, döngü kareleri).
Kullanım (proje kökünden): python -I tools/proto_20261116/hortum/gen_hortum_v2.py
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)
sys.path.insert(0, os.path.join(PROJECT, 'tools'))
sys.path.insert(0, os.path.join(PROJECT, 'tools', 'proto_20261012'))
sys.path.insert(0, os.path.join(PROJECT, 'tools', 'proto_20261016'))
import pixfx as P  # noqa: E402
import gen_buyucu_buyu as G  # noqa: E402  (Büyücü karesi, slime, yol yürüme, çimen)
from gen_matthew_simsek import font  # noqa: E402

TAU = math.tau
WHITE = P.WHITE
## [kontur, koyu, orta, açık, parlak]
HOR = G.HOR
ARC = G.ARC
WARM = G.WARM
LEAF = G.LEAF
SAND = [(96, 70, 44), (158, 122, 80), (196, 162, 112), (226, 202, 156), (246, 232, 198)]  ## açık toz (koyu kahve kütük gibi durdu)
PERI = [(34, 28, 82), (88, 84, 184), (138, 144, 230), (198, 208, 255), (255, 255, 255)]
SHADE = (24, 20, 28)  ## nötr yer gölgesi (çöl/kar haritalarında yeşil gölge yanlış durur)

## Zaman çizelgesi eski prototiple AYNI (karşılaştırma için): 15 fps
CAST, GROW0, GROW, END, ENDN = 4, 9, 6, 58, 12
F = END + ENDN + 4


# ====================================================================== ortak yardımcılar
def fade(cv, level):
    """Katmanı DÜZ alfa basamağıyla soldurur (dither yok): 1 / 0,75 / 0,5 / 0,25 / 0."""
    lv = round(max(0.0, min(1.0, level)) * 4) / 4.0
    if lv >= 1.0:
        return
    cv.rgba[:, :, 3] = (cv.rgba[:, :, 3].astype(np.float32) * lv).astype(np.uint8)


def dot(cv, x, y, w, col, a=255, vert=True):
    """Çizgi örneği: w < 1,5 tek piksel, 1,5-2,4 iki piksel (çizgi yataysa dikey kalınlık), >= 2,4 artı."""
    cv.px(x, y, col, a)
    if w >= 2.4:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            cv.px(x + dx, y + dy, col, a)
    elif w >= 1.5:
        if vert:
            cv.px(x, y + 1, col, a)
        else:
            cv.px(x + 1, y, col, a)


def arc_pts(cx, cy, R, sq, a0, span, wmax, wmin=0.6):
    """Elips yay örnekleri (th 0 = ön/aşağı, kameraya bakan yarı). İki ucu sivrilir (sin profili)."""
    n = max(6, int(abs(span) * max(R, 1.0) * 1.6))
    out = []
    for i in range(n + 1):
        u = i / n
        th = a0 + span * u
        w = wmin + (wmax - wmin) * math.sin(math.pi * u)
        vert = abs(math.cos(th)) >= abs(sq * math.sin(th))
        out.append((cx + R * math.sin(th), cy + R * sq * math.cos(th), w, math.cos(th) >= 0.0, vert))
    return out


def stroke(cv, pts, front_col, back_col, back_a=150, which='both', thin_col=None):
    """Önce arka (yarı saydam) sonra ön yarı; thin_col: ön yarının ince uçları (sivrilen uç bir ton koyu)."""
    for (x, y, w, fr, vert) in pts:
        if fr and which != 'back':
            dot(cv, x, y, w, front_col if (thin_col is None or w >= 1.5) else thin_col, 255, vert)
        elif not fr and which != 'front':
            dot(cv, x, y, w, back_col, back_a, vert)


def orbit(t, q, n, seed, speed=0.8, rise=0.03):
    s = (t * rise + q / n + seed * 0.1) % 1.0
    a = t * speed + q * 2.1 + seed
    return s, a


# ====================================================================== A - Rüzgâr İpleri
def a_shape(t, seed, g, e):
    r1 = 13.5 * (0.6 + 0.4 * g) * (1.0 + e * 0.45)
    return (lambda s: (2.0 + (r1 - 2.0) * s ** 1.15),
            lambda s: 3.0 * s ** 1.4 * math.sin(t * 0.42 + seed + s * 2.2))


def a_body(cv, x, gy, t, g, e, seed):
    h = 48.0 * g + e * 6.0
    if h < 3:
        return
    rad, sway = a_shape(t, seed, g, e)
    base = gy - 1.5 - e * 8.0
    SQ = 0.36
    N = 7
    rings = []
    for k in range(N):
        s = (k + (t * 0.055) % 1.0) / N
        if s < e:  ## çözülme alttan
            continue
        edge = min(1.0, s / 0.12, (1.0 - s) / 0.1)
        span = (3.3 + 0.9 * math.sin(k * 1.7 + seed)) * max(edge, 0.05) ** 0.5
        a0 = -t * 0.62 * (1.0 + 0.25 * (1 - s)) + k * 2.2 + seed
        rings.append(arc_pts(x + sway(s), base - s * h, rad(s), SQ, a0, span, 1.0 + 1.3 * edge))
    hel = []  ## tabandan tepeye tek uzun sarmal iplik
    n = int(h * 2.2)
    for i in range(n):
        s = 0.05 + 0.9 * i / n
        if s < e:
            continue
        th = s * TAU * 1.5 - t * 0.6 + seed
        R = rad(s) * 1.05
        vert = abs(math.cos(th)) >= abs(SQ * math.sin(th))
        hel.append((x + sway(s) + R * math.sin(th), base - s * h + R * SQ * math.cos(th), 1.0, math.cos(th) >= 0, vert))

    def leaves(front):
        for q in range(3):
            s, a = orbit(t, q, 3, seed)
            if s < e or (math.cos(a) >= 0) != front:
                continue
            R = rad(s) + 2.0
            xx, yy = x + sway(s) + R * math.sin(a), base - s * h + R * SQ * math.cos(a)
            if front:
                cv.px(xx, yy, LEAF[3])
                cv.px(xx + 1, yy - 1, LEAF[2])
                cv.px(xx - 1, yy + 1, LEAF[1])
            else:
                cv.px(xx, yy, LEAF[1], 200)
                cv.px(xx + 1, yy - 1, LEAF[1], 200)

    ## soluk düz perde: ipler dağınık çizgi yığını gibi durmasın, huni silüeti okunsun (iki düz alfa bandı, dither yok)
    X, Y = cv.grid()
    s_ = (base - Y) / h
    sc = np.clip(s_, 0, 1)
    xc = x + 3.0 * sc ** 1.4 * np.sin(t * 0.42 + seed + sc * 2.2)
    r1 = rad(1.0)
    rr = (2.0 + (r1 - 2.0) * sc ** 1.15) * (0.92 + 0.08 * np.sin(sc * 19.0 - t * 1.3 + seed))
    uu = np.clip((X - xc) / np.maximum(rr, 0.5), -1, 1)
    band = np.sin(np.arcsin(uu) * 2.0 + sc * 13.0 - t * 1.5 + seed) > -0.15  ## sarmal bantlar (düz cam gibi durmasın)
    veil = (s_ >= max(e, 0.0)) & (s_ <= 0.93) & (np.abs(X - xc) <= rr) & band
    cv.put(veil, HOR[3], 50)
    cv.put(veil & (np.abs(uu) <= 0.4), HOR[4], 74)
    for pts in rings:
        stroke(cv, pts, HOR[4], HOR[2], 150, 'back')
    stroke(cv, hel, HOR[3], HOR[1], 130, 'back')
    leaves(False)
    for pts in rings:
        stroke(cv, pts, HOR[4], HOR[2], 150, 'front', thin_col=HOR[3])
    stroke(cv, hel, HOR[3], HOR[1], 130, 'front')
    leaves(True)


def a_ground(cv, x, gy, t, g, e, seed):
    for j in range(2):
        a0 = -t * 0.5 + j * math.pi + seed
        stroke(cv, arc_pts(x, gy, (9.0 + 3.0 * g) * (1 + e * 0.6), 0.42, a0, 2.4, 1.6 * g + 0.4), P.DUST[3], P.DUST[2], 170,
               thin_col=P.DUST[2])


def a_seed(cv, x, y, f, i):
    for j in range(2):
        stroke(cv, arc_pts(x, y - 2, 3.5, 0.6, -f * 0.9 + i + j * math.pi, 2.6, 1.6), HOR[4], HOR[2], 150)


def a_cast(cv, ex, feet, k, f):
    for j in range(3):
        stroke(cv, arc_pts(ex, feet, 4.0 + k * 3.2, 0.45, -f * 0.8 + j * TAU / 3, 2.2, 1.8 * (1 - k / 5) + 0.5),
               HOR[4], HOR[2], 150, thin_col=HOR[3])


def a_hit(cv, tx, tsf, k, j):
    cy = tsf - 9
    for q in range(2):  ## çapraz iki ince rüzgâr kesiği
        a0 = (0.6 if q == 0 else 3.6) + k * 0.5 + j
        stroke(cv, arc_pts(tx, cy, 9.0 + k * 1.5, 0.75, a0, 1.7, 2.4 * (1 - k / 4) + 0.6), WHITE, HOR[3], 255, thin_col=HOR[3])
    if k == 0:
        P.star(cv, tx, cy, 3, WHITE, HOR[3])
    for q in range(2):  ## savrulan yapraklar
        lx, ly = tx + (q * 2 - 1) * (5 + k * 3), cy - 2 - k * 2 + k * k * 0.6
        cv.px(lx, ly, LEAF[3])
        cv.px(lx + 1, ly - 1, LEAF[2])


# ====================================================================== B - Arcane Girdap
def b_ground(cv, x, gy, t, g, e, seed):
    R = (10.5 + 0.9 * math.sin(t * 0.33 + seed)) * (0.45 + 0.55 * g)
    flash = 0.5 <= e < 0.75  ## huni rüne çöktüğü an rün parlar
    X, Y = cv.grid()
    dx, dy = X - x, (Y - gy) / 0.5
    d = np.sqrt(dx * dx + dy * dy)
    th = np.arctan2(dy, dx)
    cv.put(d <= R - 1.0, ARC[3] if flash else ARC[2], 110 if flash else 56)
    cv.put((d <= R - 3.0) & (d > R - 4.0) & (np.sin(th * 3.0 - t * 0.2 + seed) > -0.3), ARC[3], 150)
    cv.put((d <= R) & (d > R - 1.05), ARC[4] if flash else ARC[3], 230)
    for q in range(4):  ## dönen rün çentikleri
        a = t * 0.1 + q * TAU / 4 + seed
        nx, ny = x + (R - 0.5) * math.cos(a), gy + (R - 0.5) * 0.5 * math.sin(a)
        cv.px(nx, ny, WHITE)
        cv.px(nx, ny - 1, ARC[4])
        cv.px(nx, ny + 1, ARC[4])


def b_body(cv, x, gy, t, g, e, seed):
    col = max(0.0, 1.0 - e / 0.55)  ## e 0,55'te huni tamamen rüne çökmüş olur
    h = 52.0 * g * col
    base = gy - 1.0
    if e > 0.45:  ## çöküşten sonra yükselen yıldızlar
        u = (e - 0.45) / 0.55
        for q in range(4):
            a = q * TAU / 4 + seed
            P.star(cv, x + math.cos(a) * (4 + u * 6), base - 6 - u * 26 - q * 3, 2 if q % 2 == 0 else 1, WHITE, ARC[3])
    if h < 3:
        return
    X, Y = cv.grid()
    kr = (0.5 + 0.5 * g) * (0.55 + 0.45 * col)

    def rad(s):
        return (1.8 + 9.5 * np.clip(s, 0, 1) ** 1.6) * kr

    def sway(s):
        return 2.5 * np.clip(s, 0, 1) ** 1.5 * np.sin(t * 0.4 + seed + s * 2.6)

    s = (base - Y) / h
    xc = x + sway(s)
    rr = rad(s) * (1.0 + 0.07 * np.sin(s * 17.0 - t * 1.6 + seed))
    inside = (s >= 0.0) & (s <= 1.0)
    u = (X - xc) / np.maximum(rr, 0.6)
    au = np.abs(u)
    body = inside & (au <= 1.0)
    breath = 1.2 + 1.0 * (0.5 + 0.5 * math.sin(t * 0.5 + seed))
    halo = inside & (np.abs(X - xc) <= rr + breath) & ~body
    th = np.arcsin(np.clip(u, -1, 1))
    stripe = np.sin(th * 2.0 + s * 14.0 - t * 1.8 + seed)

    def sparks(front):
        for q in range(4):
            sq, a = orbit(t, q, 4, seed, 0.9, 0.04)
            if (math.cos(a) >= 0) != front:
                continue
            R = float(rad(sq)) + 2.5
            xx, yy = x + float(sway(sq)) + R * math.sin(a), base - sq * h + R * 0.36 * math.cos(a)
            if front:
                P.star(cv, xx, yy, 2 if ((int(t) + q * 3) % 8) < 4 else 1, WHITE, ARC[3])
            else:
                cv.px(xx, yy, ARC[3], 190)

    sparks(False)
    cv.put(halo, ARC[3], 80)
    outer = body & (au > 0.7)
    mid = body & (au <= 0.7) & (au > 0.32)
    core = body & (au <= 0.32)
    cv.put(outer, ARC[2], 165)
    cv.put(outer & (stripe > 0.45), ARC[3], 205)
    cv.put(mid, ARC[3], 225)
    cv.put(mid & (stripe < -0.45), ARC[2], 215)
    cv.put(mid & (stripe > 0.6), ARC[4], 245)
    cv.put(core, ARC[4])
    cv.put(core & (stripe > 0.5), WHITE)
    ## ağız: ışık çemberi + koyu iç (derinlik), çevresinde hale
    xt, top, r1 = x + float(sway(1.0)), base - h, float(rad(1.0))
    rim = ((X - xt) / max(r1, 1.0)) ** 2 + ((Y - top) / max(r1 * 0.3, 0.8)) ** 2 <= 1.0
    mouth = ((X - xt) / max(r1 - 1.6, 0.5)) ** 2 + ((Y - top + 0.4) / max(r1 * 0.3 - 0.9, 0.5)) ** 2 <= 1.0
    cv.put(P.dilate(P.dilate(rim)) & ~rim & ~body, ARC[3], 80)
    cv.put(rim, ARC[3], 230)
    cv.put(rim & (Y > top + r1 * 0.12), ARC[4], 245)
    cv.put(mouth, ARC[1], 200)
    for q in range(4):  ## ağızdan dışa kıvrılan ışık tutamları
        a = t * 0.45 + q * TAU / 4 + seed
        fr = math.cos(a) >= 0
        sx, sy = xt + r1 * 0.9 * math.sin(a), top + r1 * 0.3 * math.cos(a)
        out = 1 if math.sin(a) >= 0 else -1
        pts = []
        for i in range(9):
            v = i / 8
            pts.append((sx + out * (v * 4.0 + v * v * 2.0), sy - v * 4.5 + v * v * 3.0, 2.0 * (1 - v) + 0.5, fr, True))
        stroke(cv, pts, ARC[4], ARC[3], 170, thin_col=ARC[3])
    sparks(True)


def b_seed(cv, x, y, f, i):
    P.star(cv, x, y - 3, 2 if (f + i) % 4 < 2 else 1, WHITE, ARC[3])
    cv.px(x - 3, y - 2, ARC[3], 200)
    cv.px(x - 5, y - 1, ARC[2], 150)


def b_cast(cv, ex, feet, k, f):
    span = TAU * min(1.0, (k + 1) / 4.0)  ## rün halkası ayakta çizilerek kapanır
    pts = arc_pts(ex, feet, 9.0, 0.5, -1.2, span, 1.2, 1.0)
    stroke(cv, pts, ARC[3], ARC[3], 220)
    if k >= 3:
        X, Y = cv.grid()
        cv.put(((X - ex) / 8.0) ** 2 + ((Y - feet) / 4.0) ** 2 <= 1.0, ARC[2], 70)
    hx, hy = pts[-1][0], pts[-1][1]
    P.star(cv, hx, hy, 2, WHITE, ARC[3])


def b_hit(cv, tx, tsf, k, j):
    cy = tsf - 8
    if k <= 1:
        P.disc_flash(cv, tx, cy, 3.0 + k * 2.0, WHITE, ARC[3])
    if k >= 1:
        R = 4.0 + k * 2.6
        X, Y = cv.grid()
        d = np.sqrt((X - tx) ** 2 + (Y - cy) ** 2)
        th = np.arctan2(Y - cy, X - tx)
        m = (d <= R) & (d > R - (1.6 if k < 3 else 1.0)) & (np.sin(th * 3.0 + j) > (-0.6 if k < 3 else 0.2))
        cv.put(m, ARC[3] if k < 3 else ARC[2], 230 if k < 3 else 150)
    if k < 3:
        for q in range(3):
            a = q * TAU / 3 + j - math.pi / 2
            P.star(cv, tx + math.cos(a) * (5 + k * 2), cy + math.sin(a) * (5 + k * 2) - k, 1, WHITE, ARC[3])


# ====================================================================== C - Toz Şeytanı (2026-11-16 kullanıcı seçti -> oyunda, madde 728)
LOOP = 28  ## oyundaki hortum_loop kare sayısı: C'nin BÜTÜN zaman terimleri bu sürede tam sayıda tur atar (dikişsiz döngü, gen_buyucu_fx.py)


def _ph(t):
    return TAU * t / LOOP


def c_shape(t, seed, g, e):
    kr = 0.55 + 0.45 * g
    ph = _ph(t)

    def rad(s):
        s = np.clip(s, 0, 1)
        return (7.5 - 2.0 * s + 3.0 * s ** 3 + 3.2 * np.clip(1.0 - s / 0.18, 0, 1) ** 2 * (1 + e)) * kr

    def sway(s):
        return 3.5 * np.clip(s, 0, 1) ** 1.3 * np.sin(ph * 2 + seed + s * 3.0)
    return rad, sway


def c_body(cv, x, gy, t, g, e, seed):
    h = 46.0 * g * (1.0 - 0.75 * e)  ## çözülme: sütun yere çöker, etek açılır
    if h < 3:
        return
    rad, sway = c_shape(t, seed, g, e)
    ph = _ph(t)
    X, Y = cv.grid()
    base = gy - 0.5
    s = (base - Y) / h
    xc = x + sway(s)
    rr = rad(s) + 0.7 * np.sin(s * 25.0 - ph * 6 + seed)
    inside = (s >= 0) & (s <= 1)
    u = (X - xc) / np.maximum(rr, 0.6)
    th = np.arcsin(np.clip(u, -1, 1))
    body = inside & (np.abs(u) <= 1)
    fray = np.sin(th * 3.0 + s * 9.0 - ph * 5 + seed)  ## tepe tutamlara ayrılır
    body &= ~((s > 0.62) & (fray < -1.0 + (s - 0.62) * 4.2))
    streak = np.sin(th * 1.6 + s * 22.0 - ph * 9 + seed)  ## sarmal kum çizgileri
    tone = np.where(u < -0.45, 4, np.where(u > 0.45, 2, 3))
    tone = np.where(streak > 0.55, np.minimum(tone + 1, 4), np.where(streak < -0.7, np.maximum(tone - 1, 2), tone))
    tone = np.where(s > 0.6, np.maximum(tone, 3), tone)  ## seyrelen tepe açık kum (saydam koyu ton çimende zeytin yeşili oluyordu)
    alpha = np.where(s < 0.35, 255, np.where(s < 0.65, 235, 205))

    def bits(front):
        for q in range(6):
            sq = (t / LOOP + q / 6.0 + seed * 0.1) % 1.0  ## döngüde bir kez yükselir
            a = ph * (3 if q % 2 == 0 else 4) + q * 2.1 + seed
            if (math.cos(a) >= 0) != front:
                continue
            R = float(rad(sq)) + 1.5
            xx, yy = x + float(sway(sq)) + R * math.sin(a), base - sq * h + R * 0.36 * math.cos(a)
            if q in (0, 3):  ## çakıl
                cv.px(xx, yy, P.STONE[3] if front else P.STONE[1])
                cv.px(xx + 1, yy, P.STONE[2] if front else P.STONE[1])
            elif q in (1, 4):  ## çimen yaprağı
                cv.px(xx, yy, LEAF[2] if front else LEAF[1])
                cv.px(xx + 1, yy - 1, LEAF[3] if front else LEAF[1])
            else:  ## Set 2 sıcak kor
                cv.px(xx, yy, WARM[4] if front else WARM[2], 255 if front else 190)
                if front:
                    cv.px(xx, yy + 1, WARM[2])

    swirls = []  ## gövdeyi saran kum çizgileri (dönüşü gösterir)
    for q in range(3):
        sq = 0.18 + 0.27 * q + 0.06 * math.sin(ph + q)
        a0 = -ph * 3 + q * 2.3 + seed
        swirls.append(arc_pts(x + float(sway(sq)), base - sq * h, float(rad(sq)) + 1.8, 0.36, a0, 2.2, 1.8))
    for pts in swirls:
        stroke(cv, pts, SAND[4], SAND[2], 150, 'back')
    bits(False)
    for tt in range(1, 5):
        for aa in (255, 235, 205):
            cv.put(body & (tone == tt) & (alpha == aa), SAND[tt], aa)
    ol = P.outline_of(body) & (s < 0.4) & (s > -0.12) & (X >= xc)  ## yumuşak sel-out: yalnız gölge yanı, alt gövde
    cv.put(ol, SAND[1], 220)
    for pts in swirls:
        stroke(cv, pts, P.CREAM, SAND[2], 150, 'front', thin_col=SAND[4])
    bits(True)


def c_ground(cv, x, gy, t, g, e, seed):
    X, Y = cv.grid()
    cv.put(((X - x) / (11.0 * (0.6 + 0.4 * g) * (1 + e * 0.4))) ** 2 + ((Y - gy) / 3.5) ** 2 <= 1.0, SHADE, 80)
    for j in range(3):
        a0 = -_ph(t) * 2 + j * TAU / 3 + seed
        R = (12.0 + 2.0 * j) * (0.6 + 0.4 * g) * (1 + e * 0.35)  ## 48 px kareye sığsın (çözülmede en çok ~22)
        sq = 0.38 / (1 + e * 0.35)  ## çözülmede yalnız YATAY açılır (oyun karesinde zemin satırının altında 8 px var)
        stroke(cv, arc_pts(x, gy, R, sq, a0, 1.9 + 0.4 * j, 1.8 - 0.3 * j), SAND[3], SAND[2], 170, thin_col=SAND[2])


def c_seed(cv, x, y, f, i):
    stroke(cv, arc_pts(x, y - 1, 3.5, 0.6, -f * 0.9 + i, 3.4, 1.8), SAND[3], SAND[2], 170)


def c_cast(cv, ex, feet, k, f):
    for j in range(3):  ## ayağa doğru daralan zemin çizikleri
        stroke(cv, arc_pts(ex, feet, 15.0 - k * 2.6, 0.4, -f * 0.7 + j * TAU / 3, 1.8, 1.7), SAND[3], SAND[2], 170,
               thin_col=SAND[2])


def c_hit(cv, tx, tsf, k, j):
    for q in range(5):  ## yukarı yelpaze kum çizgileri
        a = -math.pi / 2 + (q - 2) * 0.55 + j * 0.3
        r0 = 3.0 + k * 3.0
        L = 3.5 - k * 0.6
        x0, y0 = tx + math.cos(a) * r0, tsf - 4 + math.sin(a) * r0 * 0.8
        P.thick_line(cv, x0, y0, x0 + math.cos(a) * L, y0 + math.sin(a) * L * 0.8, 1.0, SAND[4] if k < 2 else SAND[3])
    for q in (-1, 1):  ## sıçrayan çakıllar
        px_, py_ = tx + q * (4 + k * 3), tsf - 7 - k * 3 + k * k
        cv.px(px_, py_, P.STONE[3])
        cv.px(px_ + 1, py_, P.STONE[1])


# ====================================================================== D - Halka Kulesi
def d_ring(cv, X, Y, cx, cy, R, tube, t, k, seed, SQ=0.42):
    if R < 1.5:
        return
    outer = ((X - cx) / R) ** 2 + ((Y - cy) / (R * SQ)) ** 2 <= 1.0
    ri = max(R - tube, 0.0)
    if ri > 0.8:
        hole = ((X - cx) / ri) ** 2 + ((Y - cy + tube * 0.25) / (ri * SQ)) ** 2 <= 1.0
        wall = hole & ~(((X - cx) / ri) ** 2 + ((Y - cy + tube * 0.25 - 1.5) / (ri * SQ)) ** 2 <= 1.0)
    else:
        hole = np.zeros_like(outer)
        wall = hole
    band = outer & ~hole
    back = band & (Y < cy - 0.2)
    cv.put(back, PERI[2])
    cv.put(band & ~back, PERI[3])
    under = band & ~back & ~(((X - cx) / R) ** 2 + ((Y - cy + 1.0) / (R * SQ)) ** 2 <= 1.0)
    cv.put(under, PERI[2])  ## cel gölge: ön bandın alt kenarı
    cv.put(wall, PERI[1])  ## deliğin içinde arka duvar
    a = t * 0.85 * (1.0 + 0.12 * k) + k * 1.3 + seed  ## dönen parlak benek
    if math.cos(a) > 0.15:
        rm = (R + ri) / 2.0
        gx, gy_ = cx + rm * math.sin(a), cy + rm * SQ * math.cos(a)
        cv.px(gx, gy_, WHITE)
        cv.px(gx - 1, gy_, WHITE)
        if R > 7:
            cv.px(gx + 1, gy_, PERI[4])
    cv.put(P.outline_of(outer), PERI[0])
    if R > 4.5:  ## dönüş yönünü gösteren rüzgâr kuyruğu (halka katı simge gibi dönmesin)
        ta = a - 0.6
        stroke(cv, arc_pts(cx, cy, R + 1.6, SQ, ta - 1.3, 1.3, 1.9), WHITE, PERI[3], 190, thin_col=PERI[3])


def d_body(cv, x, gy, t, g, e, seed):
    NR = 5
    X, Y = cv.grid()
    rings = []
    for k in range(NR):
        ap = min(1.0, max(0.0, g * NR - k))  ## doğuşta halkalar alttan sırayla belirir
        if ap <= 0:
            continue
        p = min(1.0, max(0.0, (e - (NR - 1 - k) * 0.13) / 0.35))  ## çözülme: tepeden başlayarak uçar
        if p >= 1.0:
            continue
        R = (3.6 + 2.9 * k) * (0.35 + 0.65 * ap) * (1 - 0.55 * p)
        tube = (2.0 + 0.45 * k) * (1 - 0.4 * p)
        cx = x + 3.0 * (k / (NR - 1)) * math.sin(t * 0.55 - k * 0.9 + seed)
        cy = gy - 4.0 - k * 8.3 - p * 18.0
        rings.append((k, cx, cy, R, tube, p))
    if not rings:
        return
    ## çekirdek: halkaları bağlayan ince sütun (deliklerden görünür)
    chain = [(x, gy - 1.0)] + [(r[1], r[2]) for r in rings if r[5] <= 0.0]
    for (ax, ay), (bx, by) in zip(chain, chain[1:]):
        n = int(abs(ay - by)) + 1
        for i in range(n):
            v = i / n
            xx, yy = ax + (bx - ax) * v, ay + (by - ay) * v
            cv.px(xx, yy, PERI[3], 230)
            cv.px(xx + 1, yy, PERI[2], 230)
    for (k, cx, cy, R, tube, p) in rings:
        d_ring(cv, X, Y, cx, cy, R, tube, t, k, seed)
        if (int(t) + k * 5) % 9 < 3 and p <= 0.0 and k >= 1:  ## çizgi film hız çizgisi
            side = 1 if (k + int(t / 9)) % 2 == 0 else -1
            stroke(cv, arc_pts(cx, cy, R + 2.5, 0.42, side * math.pi / 2 - 0.5 * side, 0.9 * side, 1.2), WHITE, PERI[3], 200)
        if 0.7 < p:
            P.star(cv, cx, cy, 2, WHITE, PERI[3])


def d_ground(cv, x, gy, t, g, e, seed):
    X, Y = cv.grid()
    k = (0.6 + 0.4 * g) * (1.0 - 0.6 * e)
    cv.put(((X - x) / (8.0 * k)) ** 2 + ((Y - gy) / 2.8) ** 2 <= 1.0, SHADE, 90)
    for j in range(2):
        stroke(cv, arc_pts(x, gy, 9.5 * k, 0.4, -t * 0.7 + j * math.pi + seed, 1.6, 1.8), WHITE, PERI[3], 200, thin_col=PERI[3])


def d_seed(cv, x, y, f, i):
    X, Y = cv.grid()
    d_ring(cv, X, Y, x, y - 3, 3.2, 1.6, f, 0, i * 1.0)


def d_cast(cv, ex, feet, k, f):
    X, Y = cv.grid()
    d_ring(cv, X, Y, ex, feet - 2 - k * 1.5, 3.0 + k * 1.8, 2.0, f, 0, 0.0)


def d_hit(cv, tx, tsf, k, j):
    cy = tsf - 9
    if k <= 1:  ## çizgi film vuruş yıldızı (kalın kontur)
        tmp = P.Canvas(cv.bw, cv.bh)
        P.star(tmp, tx, cy, 3 + k * 2, WHITE, PERI[4], diag=True)
        m = tmp.filled()
        cv.put(P.outline_of(m), PERI[0])
        cv.put(m, WHITE)
    if k >= 1:
        for q in range(4):
            a = q * TAU / 4 + math.pi / 4 + j * 0.2
            r0 = 5.0 + k * 2.0
            P.thick_line(cv, tx + math.cos(a) * r0, cy + math.sin(a) * r0 * 0.8,
                         tx + math.cos(a) * (r0 + 3.0), cy + math.sin(a) * (r0 + 3.0) * 0.8, 1.0, WHITE if k < 3 else PERI[3])


STYLES = [
    dict(key='a', name='A  Rüzgâr İpleri', tint=HOR, body=a_body, ground=a_ground, seed=a_seed, cast=a_cast, hit=a_hit,
         label='A  Rüzgâr İpleri: dolu gövde yok - yükselip genişleyen ince rüzgâr halkaları + sarmal iplik'),
    dict(key='b', name='B  Arcane Girdap', tint=ARC, body=b_body, ground=b_ground, seed=b_seed, cast=b_cast, hit=b_hit,
         label='B  Arcane Girdap: kontursuz parlayan menekşe huni, beyaz çekirdek, ayakta rün halkası'),
    dict(key='c', name='C  Toz Şeytanı', tint=SAND, body=c_body, ground=c_ground, seed=c_seed, cast=c_cast, hit=c_hit,
         label='C  Toz Şeytanı: altı geniş kum sütunu, tepesi tutamlara ayrılır, çakıl/çimen/kor savrulur'),
    dict(key='d', name='D  Halka Kulesi', tint=PERI, body=d_body, ground=d_ground, seed=d_seed, cast=d_cast, hit=d_hit,
         label='D  Halka Kulesi: üst üste 5 kalın halka yay gibi salınır, tepeden uçarak söner'),
]


# ====================================================================== sahne (eski prototiple aynı kurgu: 3 hortum, 5 yaratık)
def grow_end(f):
    g = P.ease_out(min(1.0, max(0.0, (f - GROW0 + 1) / GROW)))
    e = min(1.0, max(0.0, (f - END) / ENDN)) if f >= END else 0.0
    return g, e


def scene(st):
    W, H = 360, 196
    ex, feet = 56, 150
    SPD = 102.0 * G.PXW * 0.066  ## 102 dünya/sn
    TG = [(172, 132), (252, 184), (306, 116), (220, 80), (330, 164)]
    PATHS = [[(100, 184), (150, 186), (200, 176), (252, 186), (300, 172)],
             [(116, 140), (172, 136), (204, 118), (228, 92), (222, 74)],
             [(92, 100), (150, 106), (232, 120), (302, 116), (334, 150)]]
    PACE = (0.9, 0.75, 1.1)
    last_hit, react = {}, {}
    frames = []
    for f in range(F):
        img = G.grass(W, H, 260)
        g, e = grow_end(f)
        lv = 1.0 if e < 0.5 else 1.0 - (e - 0.5) / 0.5
        if CAST <= f < CAST + 5:
            cv = P.Canvas(W, H)
            st['cast'](cv, ex, feet, f - CAST, f)
            G.cc(img, cv)
        pos = []
        for i, path in enumerate(PATHS):
            if f < GROW0:  ## tohum: ayaktan sarmal açılarak başlangıç noktasına
                u = P.ease_out(max(0.0, (f - CAST) / (GROW0 - CAST)))
                curl = math.sin(u * math.pi) * 10.0
                ang = math.atan2(path[0][1] - feet, path[0][0] - ex) + math.pi / 2
                x = P.lerp(ex, path[0][0], u) + math.cos(ang) * curl
                y = P.lerp(feet, path[0][1], u) + math.sin(ang) * curl * 0.5
            else:
                x, y = G._walk(path, (min(f, END) - GROW0) * SPD * PACE[i])
            pos.append((x, y))
            if f >= CAST:
                cv = P.Canvas(W, H)
                if f < GROW0:
                    st['seed'](cv, x, y, f, i)
                else:
                    st['ground'](cv, x, y, f + i * 7.0, g, e, i * 2.3)
                    fade(cv, lv)
                G.cc(img, cv)
        if GROW0 + GROW <= f < END:  ## temas: aynı çift saniyede bir
            for i, (x, y) in enumerate(pos):
                for j, (tx, tsf) in enumerate(TG):
                    if math.hypot(tx - x, (tsf - y) * 1.6) < 20 and f - last_hit.get((i, j), -99) >= 15:
                        last_hit[(i, j)] = f
                        react[j] = f
        draw = [(tsf, 'slime', j) for j, (tx, tsf) in enumerate(TG)]
        draw.append((feet, 'mage', 0))
        draw += [(y + 0.5, 'tor', i) for i, (x, y) in enumerate(pos)]
        draw.sort(key=lambda d: d[0])
        for (_, kind, j) in draw:
            if kind == 'slime':
                tx, tsf = TG[j]
                k = f - react.get(j, -99)
                lift = (3.0, 5.0, 5.0, 3.0, 1.0)[k] if 0 <= k < 5 else 0.0
                G.put_slime_fx(img, tx, tsf, tint=st['tint'] if 0 <= k < 2 else None, squash=0.4 if k in (0, 1) else 0.0, lift=lift)
            elif kind == 'mage':
                G.put_mage(img, f, ex, feet)
            elif f >= GROW0:
                x, y = pos[j]
                tv = P.Canvas(W, H)
                st['body'](tv, x, y, f + j * 7.0, g, e, j * 2.3)
                fade(tv, lv)
                G.cc(img, tv)
        cv = P.Canvas(W, H)
        for j, (tx, tsf) in enumerate(TG):
            k = f - react.get(j, -99)
            if 0 <= k < 4:
                st['hit'](cv, tx, tsf, k, j)
        G.cc(img, cv)
        frames.append(img)
    return frames


# ====================================================================== çıktılar
def label(im, x, y, text, size=15):
    d = ImageDraw.Draw(im)
    fnt = font(size)
    d.text((x + 1, y + 1), text, fill=(20, 30, 14), font=fnt)
    d.text((x, y), text, fill=(250, 246, 226), font=fnt)


def save_gif(path, frames, ms=66):
    q = [fr.convert('RGB').quantize(colors=200, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for fr in frames]
    q[0].save(path, save_all=True, append_images=q[1:], duration=ms, loop=0, disposal=1)


def big(fr, scale):
    return fr.convert('RGB').resize((fr.width * scale, fr.height * scale), Image.NEAREST)


def stills_sheet():
    """Döngü kareleri yan yana (karakter boyuna göre): üstte OYUNDAKİ şimdiki sayfa, altında A-D. x3."""
    W, H, feet, S = 236, 86, 76, 3
    cur = Image.open(os.path.join(PROJECT, 'assets', 'fx', 'buyucu', 'hortum_loop.png')).convert('RGBA')
    a = np.array(cur.crop((0, 0, 48, 72)))
    bottom = int(np.nonzero(a[:, :, 3].any(axis=1))[0].max())  ## sayfanın taban satırı ayak çizgisine
    rows = []
    for r in range(5):
        img = G.grass(W, H, 40 + r * 90)
        G.put_mage(img, 0, 24, feet)
        for c, xx in enumerate((76, 122, 168, 212)):
            if r == 0:
                G.comp(img, cur.crop((c * 7 * 48, 0, c * 7 * 48 + 48, 72)), xx - 24, feet + 1 - bottom)
            else:
                st = STYLES[r - 1]
                t = 30.0 + c * 5.0
                gc = P.Canvas(W, H)
                st['ground'](gc, xx, feet, t, 1.0, 0.0, 0.0)
                G.cc(img, gc)
                bc = P.Canvas(W, H)
                st['body'](bc, xx, feet, t, 1.0, 0.0, 0.0)
                G.cc(img, bc)
        im = big(img, S)
        label(im, 6, 4, 'Şimdiki (oyunda, madde 188)' if r == 0 else STYLES[r - 1]['name'])
        rows.append(im)
    sheet = Image.new('RGB', (rows[0].width, sum(r.height + 4 for r in rows)), (24, 30, 20))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height + 4
    sheet.save(os.path.join(OUT, 'hortum_sayfa.png'))


def main():
    only = set(sys.argv[1:])
    scenes = {}
    for st in STYLES:
        if only and st['key'] not in only:
            continue
        fr = scene(st)
        scenes[st['key']] = fr
        out = []
        for im in fr:
            b = big(im, 3)
            label(b, 8, 6, st['label'])
            out.append(b)
        save_gif(os.path.join(OUT, 'hortum_%s.gif' % st['key']), out)
        print('yazıldı', st['key'])
    if len(scenes) == 4:  ## 2x2 özet, x2 (~ oyundaki boyut)
        Wb, Hb = 360 * 2, 196 * 2
        out = []
        for i in range(F):
            canvas = Image.new('RGB', (Wb * 2 + 4, Hb * 2 + 4), (24, 30, 20))
            for n, st in enumerate(STYLES):
                b = big(scenes[st['key']][i], 2)
                label(b, 6, 4, st['name'])
                canvas.paste(b, ((n % 2) * (Wb + 4), (n // 2) * (Hb + 4)))
            out.append(canvas)
        save_gif(os.path.join(OUT, 'hortum_ozet.gif'), out)
    stills_sheet()
    print('tamam:', sorted(os.listdir(OUT)))


if __name__ == '__main__':
    main()
