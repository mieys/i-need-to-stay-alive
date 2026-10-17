"""Cadı Q (Zehirli Duman) - YENİ duman prototipleri (kullanıcı 2026-10-13: "zehirli duman pek duman gibi değil,
sağa sola dönükken karakterin arkasından çıkmıyor"). 4 seçenek, aynı sahnede: sağa yürüyen cadı, arkasında şişe, duman
ayağının hemen arkasında doğar; soldaki bulutlar daha yaşlı (en solda sönüş).

Her seçenek tek bir kare işlevi: frame(g, t, e) -> RGBA (g büyüme 0..1, t döngü evresi 0..1, e sönüş 0..1) - seçilen
işlev sonra tools/gen_cadi_fx.py smoke_frame'in yerine geçer (intro / loop / outro sayfası aynı şekilde üretilir).

    python -I tools/proto_20261013/cadi_duman_proto.py          -> out/cadi_duman_secenek2.png (2. tur: temiz E-H)
    python -I tools/proto_20261013/cadi_duman_proto.py --tur1   -> out/cadi_duman_secenek.png (1. tur: A-D)
    --gif eklenirse hareketli .gif
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, '..')))
import gen_cadi_fx as G  # noqa: E402
from gen_cadi_fx import Canvas, TAU, WHITE, bayer, lnoise, ppx, star  # noqa: E402

FW, FH = 104, 76  # kare; zemin merkezi (GX, GY)
GX, GY = 52.0, 56.0

# [-, koyu, orta, açık, parlak]
PAL_A = [None, (104, 140, 92), (150, 188, 122), (196, 224, 162), (232, 246, 208)]  # soluk nane - sis
PAL_B = [None, (92, 124, 80), (138, 174, 100), (186, 216, 136), (228, 244, 188)]  # hastalıklı yeşil - kabaran duman
PAL_C = [None, (84, 104, 86), (126, 150, 120), (172, 194, 158), (218, 232, 200)]  # gri-yeşil: en 'duman' rengi
PAL_D = [None, (98, 74, 138), (112, 160, 72), (176, 218, 104), (232, 248, 180)]  # yeşil duman, mor gölge
CURL_D = (84, 120, 60)
MOTE = G.TOXIC_MOTE


def dmask(cv, field, edge):
    by = bayer(cv)
    return (field > edge) | ((field > 0.0) & (by < field / edge))


def paint(cv, mask, v, pal, cuts=(0.2, 0.46, 0.74)):
    tone = np.where(v < cuts[0], 4, np.where(v < cuts[1], 3, np.where(v < cuts[2], 2, 1)))
    for k in range(1, 5):
        cv.put(mask & (tone == k), pal[k])


def puff_field(cv, puffs, squash=1.0):
    """puffs: (x, y, r). Döner: alan (0..1, merkezde 1), baskın topun yerel (nx, ny) ofseti (-1..1)."""
    X, Y = cv.grid()
    field = np.zeros((cv.h, cv.w))
    nx = np.zeros((cv.h, cv.w))
    ny = np.zeros((cv.h, cv.w))
    for (x, y, r) in puffs:
        if r <= 0.6:
            continue
        dx, dy = (X - x) / r, (Y - y) / (r * squash)
        f = 1.0 - np.sqrt(dx * dx + dy * dy)
        m = f > field
        field = np.where(m, f, field)
        nx = np.where(m, dx, nx)
        ny = np.where(m, dy, ny)
    return field, nx, ny


def fade(cv, mask, field, e, t, seed):
    """Sönüş: içinde delikler açılır, kenardan erir."""
    if e <= 0.0:
        return mask
    n = lnoise(cv, 13.0, seed, t) * 0.6 + lnoise(cv, 6.0, seed + 1, t) * 0.4
    return mask & ((n + field * 0.35) > e * 1.05) & (bayer(cv) > e * 0.75 - 0.2)


def motes(cv, t, g, e, spots):
    if e > 0.4 or g < 0.8:
        return
    for k, (bx, by) in enumerate(spots):
        ph = (int(round(t * 8)) + k * 3) % 8
        if ph == 0:
            ppx(cv, GX + bx, GY + by, MOTE)
        elif ph == 1:
            star(cv, int(GX + bx), int(GY + by), 1, core=WHITE, arm=MOTE)


# ---------------------------------------------------------------- A: Sürünen Sis
def frame_a(g, t, e, u=0.0):
    """Yere yayılan alçak, katmanlı sis: yatay şeritler kayar, arası delikli, uçlarından lif lif dağılır."""
    cv = Canvas(FW, FH)
    X, Y = cv.grid()
    rng = random.Random(11)
    puffs = []
    for k in range(8):
        a = rng.uniform(-1.0, 1.0)
        x = GX + a * 27 * g + math.sin(TAU * (t + rng.random())) * 2.5
        y = GY - 5 + rng.uniform(-6, 5) - 4.0 * e
        puffs.append((x, y, rng.uniform(15, 21) * (0.45 + 0.55 * g)))
    for (bx, by, r) in ((-38, -3, 9), (40, 0, 8), (-30, -12, 7), (31, -11, 7)):
        puffs.append((GX + (bx + math.sin(TAU * (t + bx * 0.1)) * 3.0) * g, GY + by - 4.0 * e, r * g))
    field, _nx, _ny = puff_field(cv, puffs, squash=0.55)
    streak = lnoise(cv, 34.0, 21, t, ysq=4.5)
    fine = lnoise(cv, 12.0, 22, t, ysq=2.5)
    dens = field - 0.3 * (1.0 - streak) - 0.1 * (1.0 - fine)
    mask = dmask(cv, dens, 0.26)
    mask = fade(cv, mask, dens, e, t, 23)
    v = 0.84 - dens * 1.2 + (fine - 0.5) * 0.3
    paint(cv, mask, v, PAL_A)
    motes(cv, t, g, e, ((-18, -2), (9, 2), (24, -4), (-30, 1)))
    return cv.rgba.copy()


def sphere_v(nx, ny):
    """Yuvarlak top gölgesi: ışık sol üstten; 0 aydınlık .. 1 gölge (bantlar EĞRİ - düz bant kaya gibi durur)."""
    nz = np.sqrt(np.clip(1.0 - nx * nx - ny * ny, 0.0, 1.0))
    return 1.0 - np.clip(-0.38 * nx - 0.62 * ny + 0.69 * nz, 0.0, 1.0)


# ---------------------------------------------------------------- B: Kabaran Duman
def frame_b(g, t, e, u=0.0):
    """Klasik duman: tabanda kütle, üstünden toplar kopup yükselir ve küçülerek kaybolur. Toplar yuvarlak gölgelenir."""
    cv = Canvas(FW, FH)
    X, Y = cv.grid()
    rng = random.Random(5)
    puffs = []
    for (x, y, r) in ((-19, 0, 10), (-6, -4, 13), (9, -3, 12), (21, 1, 9), (0, 3, 10)):
        ph = rng.random()
        puffs.append((GX + x * g + math.cos(TAU * (t + ph)) * 1.2, GY + y - 4 - 6.0 * e, r * (0.45 + 0.55 * g) * (1.0 + 0.07 * math.sin(TAU * (t + ph)))))
    for k in range(7):
        ph, bx, R = rng.random(), rng.uniform(-18, 18), rng.uniform(7.5, 10.0)
        p = (t + ph) % 1.0
        r = R * (1.0 - p) ** 0.8 * min(1.0, p / 0.18) * g * (1.0 - 0.4 * e)
        x = GX + bx * (1.0 - 0.25 * p) * g + math.sin(TAU * (p * 0.8 + ph)) * 3.0
        y = GY - 9 - p * 28.0 * g - 6.0 * e
        puffs.append((x, y, r))
    field, nx, ny = puff_field(cv, puffs, squash=0.95)
    hgt = np.clip((GY - 10 - Y) / 26.0, 0.0, 1.0)  # yükseldikçe seyrelir
    mask = dmask(cv, field - hgt * 0.22, 0.26)
    low = np.clip((Y - (GY + 1.0)) / 9.0, 0.0, 1.0)  # zemine oturmasın: tabanı dither ile erir
    mask &= bayer(cv) > low * 1.1 - 0.05
    mask = fade(cv, mask, field, e, t, 31)
    n = lnoise(cv, 15.0, 32, t)
    v = sphere_v(nx, ny) * 1.05 + (n - 0.5) * 0.2 - 0.08
    paint(cv, mask, v, PAL_B, cuts=(0.24, 0.52, 0.8))
    motes(cv, t, g, e, ((-14, -6), (12, 0), (-2, -14)))
    return cv.rgba.copy()


# ---------------------------------------------------------------- C: Dağılan Duman
def frame_c(g, t, e, u=0.0):
    """Yırtık kenarlı, içi akan duman; YAŞLANDIKÇA genişler ve seyrelir (u = ömrün ne kadarı geçti)."""
    cv = Canvas(FW, FH)
    X, Y = cv.grid()
    rng = random.Random(8)
    grow = 0.72 + 0.5 * u
    puffs = []
    for (x, y, r) in ((-17, 0, 12), (-4, -6, 15), (11, -4, 14), (21, 1, 10), (1, 3, 12), (-10, -13, 10), (13, -14, 9)):
        ph = rng.random()
        puffs.append((GX + (x * g + math.cos(TAU * (t + ph)) * 1.6) * grow, GY - 4 + (y - 5.0 * u) * grow - 6.0 * e, r * grow * (0.45 + 0.55 * g)))
    field, _nx, _ny = puff_field(cv, puffs, squash=0.85)
    # gürültü yukarı akar: alanı yırtar, içinde koyu damarlar açar
    wx = lnoise(cv, 20.0, 61, t)
    n1 = lnoise(cv, 17.0, 62, t, ysq=0.75)
    n2 = lnoise(cv, 7.5, 63, t)
    tear = n1 * 0.65 + n2 * 0.35
    thin = 0.3 + 0.55 * u
    dens = field * (0.62 + 0.75 * tear) - thin * (1.0 - tear) * 0.55
    mask = dmask(cv, dens, 0.2 + 0.12 * u)
    mask = fade(cv, mask, dens, e, t, 64)
    v = 0.92 - dens * 1.5 + (wx - 0.5) * 0.3 + 0.18 * u
    paint(cv, mask, v, PAL_C)
    motes(cv, t, g, e, ((-16, -4), (8, 1), (20, -8), (-4, -12)))
    return cv.rgba.copy()


# ---------------------------------------------------------------- D: Girdaplı Bulut
def frame_d(g, t, e, u=0.0):
    """Çizgi film dumanı: iri toplar, büyüklerinin içinde dönen kıvrım çizgisi; gölgesi MOR (çimenden/çalıdan ayrışır)."""
    cv = Canvas(FW, FH)
    X, Y = cv.grid()
    rng = random.Random(14)
    puffs = []
    spec = ((-20, 0, 11), (-5, -7, 14), (12, -3, 13), (24, 2, 9), (2, 4, 11), (-12, -15, 8), (16, -16, 7))
    for (x, y, r) in spec:
        ph = rng.random()
        puffs.append((GX + x * g + math.cos(TAU * (t + ph)) * 1.5, GY + y - 4 + math.sin(TAU * (t + ph)) * 1.2 - 7.0 * e,
                      r * (0.45 + 0.55 * g) * (1.0 + 0.09 * math.sin(TAU * (t + ph * 2.0))) * (1.0 - 0.25 * e)))
    nbig = 3
    for k in range(3):  # kopan küçük toplar
        p = (t + k / 3.0) % 1.0
        puffs.append((GX + (-26, 4, 28)[k] * g + math.sin(TAU * p + k) * 2.0, GY - 20 - p * 16.0 - 7.0 * e, (4.4 * (1.0 - p) ** 0.7 + 0.4) * g * (1.0 - e)))
    field, nx, ny = puff_field(cv, puffs, squash=0.9)
    mask = dmask(cv, field, 0.2)
    mask = fade(cv, mask, field, e, t, 51)
    v = sphere_v(nx, ny) * 1.1 - 0.1
    paint(cv, mask, v, PAL_D, cuts=(0.2, 0.56, 0.86))
    # kıvrım: sadece en iri 3 topta, ince tek kol
    for (x, y, r) in sorted(puffs, key=lambda q: -q[2])[:nbig]:
        dx, dy = (X - x) / r, (Y - y) / (r * 0.9)
        rho = np.sqrt(dx * dx + dy * dy)
        arm = (np.arctan2(dy, dx) / TAU + rho * 1.3 - t) % 1.0
        cv.put(mask & (rho > 0.22) & (rho < 0.66) & (np.abs(arm - 0.5) < 0.06), CURL_D)
    motes(cv, t, g, e, ((-16, -3), (11, 3), (23, -6), (-2, -10)))
    return cv.rgba.copy()


# ================================================================ 2. TUR: temiz (ditherSİZ) dumanlar
# Kullanıcı (2026-10-13): "B ve D'ye benzeyen fakat PARAZİTLİ OLMAYAN daha iyi dumanlar". Parazit = Bayer dither kenar,
# gürültüyle ton, karelenerek sönüş, serpme pikseller. Burada hiçbiri yok: toplar ressam sırasıyla TAM daire çizilir
# (kesişimler yay olur - 1. turdaki "kaya" yüzeyi baskın-top gölgesinden geliyordu), 4 düz ton, sönüş = toplar sırayla
# küçülüp kaybolur (+ oyunda sprite saydamlığı).
SQ = 0.92  # topların dikey basıklığı
PAL_E = [None, (98, 136, 86), (148, 186, 110), (194, 224, 144), (232, 247, 192)]  # soluk yeşil, yeşil gölge
PAL_F = [None, (116, 92, 152), (148, 186, 110), (194, 224, 144), (232, 247, 192)]  # aynı, alt gölge mor
PAL_G = [None, (104, 80, 144), (136, 184, 84), (184, 224, 110), (234, 249, 180)]  # canlı sarı-yeşil, mor gölge
LINE_G = (92, 132, 64)


def clean_cloud(cv, puffs, pal, scallop=False, under=2, shade=6, min_r=4.0):
    """puffs: (x, y, r) ressam sırasıyla (ilk = en arkada). Gölge top başına DEĞİL kütlenin bütününe göre (top başına
    parlaklık + hilal "baloncuk yığını" gibi durdu): gövde tek ton, sol-üst kenarda ışık bandı, altta 2 kademe gölge.
    scallop: öndeki her topun sol-üst kenarı da ışık alır (kütlenin içinde açık renk yaylar = hacim).
    Döner: (siluet, sahip indeks dizisi)."""
    X, Y = cv.grid()
    sil = np.zeros((cv.h, cv.w), bool)
    tone = np.zeros((cv.h, cv.w), np.uint8)
    owner = np.full((cv.h, cv.w), -1, np.int32)
    for i, (x, y, r) in enumerate(puffs):
        if r < min_r:
            continue
        disc = (X - x) ** 2 + ((Y - y) / SQ) ** 2 <= r * r
        tone[disc] = 3
        if scallop and r >= 5.0:
            tx, ty = 0.06 * r + 0.5, 0.11 * r + 0.9
            tone[disc & ~((X - (x + tx)) ** 2 + ((Y - (y + ty)) / SQ) ** 2 <= r * r)] = 4
        sil |= disc
        owner[disc] = i
    tone[sil & ~np.roll(sil, (2, 1), (0, 1))] = 4  # dış sol-üst kenar: ışık bandı
    tone[sil & ~np.roll(sil, -shade, 0) & (tone == 3)] = 2  # alt gövde: orta ton
    tone[sil & ~np.roll(sil, -under, 0)] = 1  # en alt: gölge
    for k in range(1, 5):
        cv.put(tone == k, pal[k])
    return sil, owner


def shrink(e, k):
    """Sönüşte toplar SIRAYLA küçülür (k: topa özgü 0..1)."""
    return max(0.0, min(1.0, 1.0 - (e * 1.55 - k * 0.55))) ** 0.8


def puffs_kabaran(g, t, e):
    """B düzeni: tabanda kütle, arkasından toplar kopup yükselir ve küçülür."""
    rng = random.Random(5)
    out = []
    for k in range(3):  # yükselenler: tabanın ARKASINDA doğar
        ph, bx, R = (k + rng.random() * 0.5) / 3.0, (-15, 16, 1)[k], rng.uniform(9.0, 10.5)
        p = (t + ph) % 1.0
        r = R * (1.0 - p) ** 0.7 * min(1.0, p / 0.18) * g * shrink(e, ph)
        out.append((GX + bx * (1.0 - 0.25 * p) * g + math.sin(TAU * (p * 0.8 + ph)) * 2.5, GY - 10 - p * 24.0 * g - 8.0 * e, r))
    for (x, y, r) in ((-8, -8, 13), (9, -7, 12), (-21, -2, 10), (23, -1, 9), (1, 1, 12)):
        ph = rng.random()
        out.append((GX + x * g + math.cos(TAU * (t + ph)) * 1.2, GY + y - 4 + math.sin(TAU * (t + ph)) * 0.8 - 8.0 * e,
                    r * (0.45 + 0.55 * g) * (1.0 + 0.06 * math.sin(TAU * (t + ph * 2.0))) * shrink(e, ph)))
    return out


def puffs_bulut(g, t, e):
    """D düzeni: iri topların öbeği, üstünden küçük toplar kopar."""
    rng = random.Random(14)
    out = []
    for k in range(2):
        p = (t + k / 2.0) % 1.0
        out.append((GX + (-24, 22)[k] * g + math.sin(TAU * p + k) * 2.0, GY - 22 - p * 13.0 - 8.0 * e, (6.4 * (1.0 - p) ** 0.55) * g * (1.0 - e)))
    for (x, y, r) in ((-12, -15, 8), (16, -16, 7), (-5, -8, 14), (12, -4, 13), (-21, 0, 11), (25, 2, 9), (2, 4, 11)):
        ph = rng.random()
        out.append((GX + x * g + math.cos(TAU * (t + ph)) * 1.4, GY + y - 4 + math.sin(TAU * (t + ph)) * 1.0 - 8.0 * e,
                    r * (0.45 + 0.55 * g) * (1.0 + 0.07 * math.sin(TAU * (t + ph * 2.0))) * shrink(e, ph)))
    return out


def curls(cv, puffs, sil, owner, t, col, n=3):
    """En iri n topun içinde dönen ince (1 px) kıvrım kancası; sadece o topun görünen yüzeyinde."""
    big = sorted(range(len(puffs)), key=lambda i: -puffs[i][2])[:n]
    for j, i in enumerate(big):
        x, y, r = puffs[i]
        if r < 8.0:
            continue
        d = 1.0 if j % 2 == 0 else -1.0
        for q in range(90):
            s = q / 89.0
            a = d * TAU * (t + s * 1.1) + j * 2.1
            rho = (0.18 + 0.46 * s) * r
            yy, xx = cv.idx(x + rho * math.cos(a) - 0.5, y + rho * math.sin(a) * SQ - 0.5)
            if 0 <= xx < cv.w and 0 <= yy < cv.h and sil[yy, xx] and owner[yy, xx] == i:
                cv.rgba[yy, xx] = (col[0], col[1], col[2], 255)


def frame_e(g, t, e, u=0.0):
    cv = Canvas(FW, FH)
    clean_cloud(cv, puffs_kabaran(g, t, e), PAL_E)
    return cv.rgba.copy()


def frame_f(g, t, e, u=0.0):
    cv = Canvas(FW, FH)
    clean_cloud(cv, puffs_kabaran(g, t, e), PAL_F, scallop=True)
    return cv.rgba.copy()


def frame_g(g, t, e, u=0.0):
    cv = Canvas(FW, FH)
    clean_cloud(cv, puffs_bulut(g, t, e), PAL_G, scallop=True)
    return cv.rgba.copy()


def frame_h(g, t, e, u=0.0):
    cv = Canvas(FW, FH)
    pf = puffs_bulut(g, t, e)
    sil, owner = clean_cloud(cv, pf, PAL_G)
    if e < 0.5:
        curls(cv, pf, sil, owner, t, LINE_G)
    return cv.rgba.copy()


ROUND1 = [('A · Sürünen Sis', frame_a, PAL_A), ('B · Kabaran Duman', frame_b, PAL_B), ('C · Dağılan Duman', frame_c, PAL_C), ('D · Girdaplı Bulut', frame_d, PAL_D)]
ROUND2 = [('E · Kabaran - sade', frame_e, PAL_E), ('F · Kabaran - mor gölge + hacim yayları', frame_f, PAL_F),
          ('G · Bulut - hacim yayları', frame_g, PAL_G), ('H · Bulut - kıvrımlı', frame_h, PAL_G)]
CLEAN = '--tur1' not in sys.argv
VARIANTS = ROUND2 if CLEAN else ROUND1


# ---------------------------------------------------------------- sahne
Z = 3
W, H = 330, 92
FEET_Y = 72
DROP_PX = 36.4  # 0,4 sn x 91 sanat px/sn
SHOW_LIFE = 2.9  # görselde sönüş burada gösterilir (oyunda 6 sn)
BOT = (-15.0, -27.0)  # şişe gövde merkezi, ayağa göre (yer 3. adımda kesinleşecek)
LAND = (-27.0, -1.0)  # dumanın doğduğu nokta: ayağın hemen arkası


def cloud_frame(fn, age, t_anim, ph=0.0):
    g = G.lerp(0.22, 1.0, G.ease_out(min(1.0, age / 0.5)))
    e = min(1.0, max(0.0, (age - (SHOW_LIFE - 0.9)) / 0.9))
    return fn(g, (t_anim + age / 0.8 + ph) % 1.0, e, min(1.0, age / SHOW_LIFE)), e


def pour(pal, t):
    """Ağızdan yere inen kısa akış (seçeneğin kendi renginde)."""
    cv = Canvas(40, 40)
    mx, my = BOT[0] - 8.1, BOT[1] + 8.1
    circles = []
    for k in range(5):
        s = (k + t) / 5.0
        circles.append((20 + (LAND[0] - mx) * s + math.sin(TAU * (s + t)) * 0.8, 4 + (LAND[1] - my) * s ** 1.15, (1.5 + 3.6 * s) * min(1.0, (1.0 - s) / 0.2 + 0.3)))
    if CLEAN:
        clean_cloud(cv, circles, pal, under=1, shade=2, min_r=1.0)
    else:
        G.soft_cloud(cv, circles, [None] + pal[1:], t, 53, squash=1.0, edge=0.3)
    return cv.rgba.copy(), (mx - 20, my - 4)


def row(fn, pal, walk, potion, wx, t_anim, wf):
    dst = G.grass(W, H)
    clouds = []
    k = 0
    while True:
        age = k * 0.4 + (t_anim * 0.4 if wf is not None else 0.12)
        if age > SHOW_LIFE:
            break
        clouds.append((age, wx + LAND[0] - age * 91.0, k))
        k += 1
    for (age, cxp, ci) in sorted(clouds, reverse=True):
        # oyunda her bulut döngüye RASTGELE kareden başlar + rastgele aynalanır (yan yana aynı bulut dizilmesin)
        rng = random.Random(ci * 7 + 3)
        still = CLEAN and wf is None
        fr, e = cloud_frame(fn, age, t_anim, rng.random() if still else 0.0)
        if still and rng.random() < 0.5:
            fr = fr[:, ::-1]
        G.blit(dst, fr, cxp - GX, FEET_Y + LAND[1] - GY, alpha=0.9 * (1.0 - 0.55 * e) if CLEAN else 0.86)
    G.shadow(dst, wx, FEET_Y + 1, 8, 2.6)
    st, off = pour(pal, t_anim)
    G.blit(dst, st, wx + off[0], FEET_Y + off[1], alpha=0.9)
    G.blit(dst, potion[int(t_anim * 8) % 8], wx + BOT[0] - G.POT_CX, FEET_Y + BOT[1] - G.POT_CY)
    G.char_at(dst, walk[2][(wf or 0) % 6], wx, FEET_Y)
    return dst


def sheet(t_anim=0.0, wf=None):
    walk = G.load_game_sheet('cadi', 'walk')
    potion = G.q_potion_frames()
    full = np.zeros((H * 4, W, 3), np.uint8)
    for i, (_name, fn, pal) in enumerate(VARIANTS):
        full[i * H:(i + 1) * H] = row(fn, pal, walk, potion, 292, t_anim, wf)
        full[i * H] = (60, 86, 44)
    im = G.up(full, Z)
    for i, (name, _fn, _pal) in enumerate(VARIANTS):
        G.label(im, 8, i * H * Z + 6, name, 17)
    return im


def main():
    out = os.path.join(HERE, 'out')
    name = 'cadi_duman_secenek2' if CLEAN else 'cadi_duman_secenek'
    if '--gif' in sys.argv:
        ims = [sheet((f % 8) / 8.0, f // 2) for f in range(8)]
        G.save_gif(ims, os.path.join(out, name + '.gif'), 100)
    else:
        sheet().save(os.path.join(out, name + '.png'))
        print('  tools/proto_20261013/out/%s.png' % name)


if __name__ == '__main__':
    main()
