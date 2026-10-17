"""Sovalye R (Koruma Baloncugu) icin IZOMETRIK kubbe prototipleri A-D (2026-10-14, oyuna bagli DEGIL).

Kullanici: "sovalye adamin koruma bariyeri icin izometrik 2d pixel art sihirli koruma bariyeri tasarlar misin. silahlar
bariyerin disinda duracagi icin izometrik olmasini istedim uyumlu olmasi acisindan. prototip"

Model: dunya yariciapi R olan yarim kure, 2:1 izometrik (yukseklik acisi 30 derece) ortografik izdusum.
  zemin elipsi: yatay R, dikey R*0.5 | kubbe tepesi merkezin R*0.866 ustunde
  arka kabuk (karakterlerin ARKASINDA) + on kabuk (karakterlerin ONUNDE) ayri katman -> oyunda iki sprite olur.
Silahlar madde 154 halkasinda (R + RIM_GAP) ama ZEMIN ELIPSI uzerinde, yerden HOVER kadar yukarida + kucuk golge;
arkadakiler kubbenin icinden gorunur, ondekiler kubbenin onunde.

Olcek: 1 sanat pikseli = 1 dunya px (mevcut tools/gen_paladin_dome_fx.py ile ayni), onizleme kamera gibi x2.
Karakter pikseli = 2.2368375 x 0.8075 x 0.5 = 0.903 dunya px.

Cikti: tools/proto_20261014/out/sovalye_izo_kubbe_A-D.gif (+ _kare.png tek kare, _eski_yeni.png karsilastirma)
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "out")

R = 126.0  # player.gd PALADIN_ULTI_ZONE_RADIUS
K = 0.5  # 2:1 izometrik
SIN, COS = K, math.sqrt(1.0 - K * K)
RIM_GAP = 12.0  # dome_weapon_ring.gd
HOVER = 14.0  # silah yerden bu kadar yukarida suzer (dunya px)
CHAR_PX = 2.2368375 * 0.8075 * 0.5
ZOOM = 2
W, H = 340, 300
CX, CY = 170, 166
FRAMES = 24
FPS = 12
HIT_F = 13  # dusman mermisi bu karede kubbeye carpar

rng = np.random.default_rng(7)

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1.0 / 32.0
yy, xx = np.mgrid[0:H, 0:W]
THR = BAYER[yy % 4, xx % 4]
THR2 = BAYER[(yy + 2) % 4, (xx + 1) % 4]
SX = xx + 0.5 - CX
SY = yy + 0.5 - CY
D2 = SX * SX + SY * SY
INSIDE = D2 < R * R
T = np.sqrt(np.clip(R * R - D2, 0.0, None))
FY = -SY * COS + T * SIN
FZ = SY * SIN + T * COS
FRONT = INSIDE & (FY >= 0)
BY = -SY * COS - T * SIN
BZ = SY * SIN - T * COS
BACK = INSIDE & (BY >= 0)
NF = np.stack([SX, FY, FZ], -1) / R
NB = np.stack([SX, BY, BZ], -1) / R
RIM = 1.0 - T / R  # fresnel: kenarda 1, ortada 0
GE = np.sqrt(SX * SX + (SY / K) ** 2) - R  # zemin elipsine uzaklik (zemin birimi)
FLOOR_IN = GE < 0
SANG = np.degrees(np.arctan2(SY, SX))  # ekran acisi (yukari = -90)

ALPHA_LEVELS = np.array([0.0, 0.3, 0.55, 0.8, 1.0])

PALS = {
    "blue": [(20, 58, 128), (27, 79, 156), (58, 142, 230), (124, 200, 255), (200, 236, 255), (255, 255, 255)],
    "gold": [(110, 66, 14), (160, 104, 26), (222, 160, 46), (255, 210, 104), (255, 238, 186), (255, 255, 240)],
    "pale": [(36, 96, 160), (60, 132, 200), (100, 180, 240), (160, 220, 255), (220, 245, 255), (255, 255, 255)],
    "cryst": [(30, 40, 120), (44, 70, 170), (64, 120, 220), (110, 190, 250), (196, 238, 255), (255, 255, 255)],
}


def dither_alpha(a):
    a = np.clip(a, 0.0, 1.0)
    i = np.clip(np.searchsorted(ALPHA_LEVELS, a, side="right") - 1, 0, len(ALPHA_LEVELS) - 2)
    lo, hi = ALPHA_LEVELS[i], ALPHA_LEVELS[i + 1]
    f = (a - lo) / (hi - lo)
    return np.where(f > THR, hi, lo)


def shade(b, pal):
    n = len(pal)
    x = np.clip(b, 0.0, 1.0) * (n - 1)
    lo = np.floor(x).astype(int)
    idx = np.clip(np.where(x - lo > THR2, lo + 1, lo), 0, n - 1)
    return np.array(pal, dtype=np.float32)[idx]


def to_img(b, a, mask, pal):
    arr = np.zeros((H, W, 4), np.uint8)
    arr[..., :3] = shade(b, pal).astype(np.uint8)
    arr[..., 3] = (dither_alpha(np.where(mask, a, 0.0)) * 255).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def up(img):
    return img.resize((img.width * ZOOM, img.height * ZOOM), Image.NEAREST)


def edges(idmap, mask):
    e = np.zeros(mask.shape, bool)
    e[:, :-1] |= (idmap[:, :-1] != idmap[:, 1:]) & mask[:, :-1] & mask[:, 1:]
    e[:-1, :] |= (idmap[:-1, :] != idmap[1:, :]) & mask[:-1, :] & mask[1:, :]
    return e


def outline(mask):
    e = np.zeros(mask.shape, bool)
    m = mask
    e[1:-1, 1:-1] = m[1:-1, 1:-1] & ~(m[:-2, 1:-1] & m[2:, 1:-1] & m[1:-1, :-2] & m[1:-1, 2:])
    return e


def fib_sphere(n):
    i = np.arange(n) + 0.5
    phi = np.arccos(1.0 - 2.0 * i / n)
    th = math.pi * (1.0 + 5 ** 0.5) * i
    return np.stack([np.cos(th) * np.sin(phi), np.cos(phi), np.sin(th) * np.sin(phi)], -1)


def voronoi(nvec, mask, pts):
    idx = np.nonzero(mask)
    d = nvec[idx] @ pts.T
    cell = np.full(mask.shape, -1)
    cell[idx] = np.argmax(d, axis=1)
    return cell


def norm(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def screen_of(p):
    """3B nokta (x, y=yukseklik, z=izleyiciye dogru) -> panel ekran konumu (dunya px)."""
    return CX + p[0], CY + p[2] * SIN - p[1] * COS


HIT_N = norm([0.78, 0.38, 0.5])
HIT_S = screen_of(HIT_N * R)


def ripple(nvec, f):
    if f < HIT_F:
        return np.zeros((H, W))
    age = f - HIT_F
    g = np.arccos(np.clip(nvec @ HIT_N, -1.0, 1.0))
    r = 0.06 + age * 0.12
    ring = np.exp(-(((g - r) / 0.07) ** 2)) * max(0.0, 1.0 - age / 8.0)
    spot = np.exp(-((g / 0.13) ** 2)) * max(0.0, 1.0 - age / 2.5)
    return ring + spot


def angles(nvec):
    az = np.arctan2(nvec[..., 2], nvec[..., 0])
    el = np.arcsin(np.clip(nvec[..., 1], -1.0, 1.0))
    return az, el


def floor_layer(f, pal, strength=1.0, runes=False):
    """Zemin: ayak izi elipsi (1 px cizgi) + iceride hafif isik + disarida ince hale. Karakterlerin ALTINDA."""
    t = f / FRAMES
    line = outline(FLOOR_IN)
    a = np.zeros((H, W))
    b = np.zeros((H, W))
    inner = FLOOR_IN & (GE > -10)
    a = np.where(inner, 0.45 * np.exp(GE / 4.0), a)
    b = np.where(inner, 0.55, b)
    a = np.where(FLOOR_IN & (GE <= -10), 0.07, a)
    b = np.where(FLOOR_IN & (GE <= -10), 0.45, b)
    halo = (~FLOOR_IN) & (GE < 5)
    a = np.where(halo, 0.3 * np.exp(-GE / 2.0), a)
    b = np.where(halo, 0.6, b)
    if runes:
        # Ruen cemberi: ic ikinci halka + aralarinda yavasca donen kucuk isaretler (zemin acisiyla izometrik basik)
        gx, gz = SX, SY / K
        ang = (np.degrees(np.arctan2(gz, gx)) + 360.0 + t * 15.0) % 360.0
        rad = np.sqrt(gx * gx + gz * gz)
        ring2 = outline(rad < R - 14)
        band = (rad > R - 12) & (rad < R - 3)
        cellang = np.floor(ang / 7.5).astype(int)
        sub = (ang / 7.5) % 1.0
        rr = (rad - (R - 12)) / 9.0
        hsh = (cellang * 2654435761) % 97
        glyph = band & (((hsh % 3 == 0) & (np.abs(sub - 0.5) < 0.14))
                        | ((hsh % 3 == 1) & (np.abs(rr - 0.5) < 0.16) & (sub > 0.2) & (sub < 0.8))
                        | ((hsh % 3 == 2) & (np.abs(sub - rr) < 0.12)))
        glow = 0.5 + 0.5 * np.sin(2 * math.pi * (t * 2.0) + np.radians(ang) * 2.0)
        a = np.where(ring2, 0.8, a)
        b = np.where(ring2, 0.75, b)
        a = np.where(glyph, 0.55 + 0.4 * glow, a)
        b = np.where(glyph, 0.7 + 0.3 * glow, b)
    a = np.where(line, 0.95, a)
    b = np.where(line, 0.85, b)
    return to_img(b, a * strength, np.ones((H, W), bool), pal)


def crescent_highlight():
    """Baloncuk parlamasi: sol ustte kenara yakin ince hilal + kucuk nokta."""
    dn = np.sqrt(D2) / R
    cres = FRONT & (dn > 0.855) & (dn < 0.9) & (SANG > -152) & (SANG < -122)
    dot = FRONT & (np.abs(dn - 0.79) < 0.022) & (np.abs(SANG + 128) < 2.2)
    return cres | dot


CRES = crescent_highlight()
OUT_F = outline(FRONT)
FOOT_F = FRONT & (FY < 3.0)


# ---------------------------------------------------------------- A: Petek Kubbe (mevcut altigen orgunun 3B hali)
PTS_A = fib_sphere(300)
CELL_FA = voronoi(NF, FRONT, PTS_A)
CELL_BA = voronoi(NB, BACK, PTS_A)
EDGE_FA = edges(CELL_FA, FRONT)
EDGE_BA = edges(CELL_BA, BACK)
PH_A = rng.random(len(PTS_A))
SWEEP_DIR = norm([0.8, 0.35, 0.45])


def shell_A(nvec, mask, cell, edge, f, back):
    t = f / FRAMES
    a = 0.07 + 0.5 * RIM ** 2.2
    b = 0.2 + 0.45 * RIM
    a = np.where(edge, 0.5, a)
    b = np.where(edge, 0.62, b)
    sh = np.clip(np.sin(2 * math.pi * (t * 2.0 + PH_A[np.clip(cell, 0, None)])), 0, 1) ** 14
    a = a + np.where(edge, 0.3, 0.16) * sh
    b = b + 0.3 * sh
    s = nvec @ SWEEP_DIR
    band = np.exp(-(((s - (-1.5 + 3.0 * t)) / 0.09) ** 2))
    a = a + band * np.where(edge, 0.45, 0.14)
    b = b + band * 0.45
    rp = ripple(nvec, f)
    a = a + rp * np.where(edge, 0.6, 0.3)
    b = b + rp * 0.6
    if f >= HIT_F and f < HIT_F + 4:  # tum kubbe hafifce parlar (mevcut flash gibi)
        k = 1.0 - (f - HIT_F) / 4.0
        a = a + np.where(edge, 0.25, 0.05) * k
        b = b + 0.15 * k
    if back:
        return b * 0.75, a * 0.5
    a = np.where(OUT_F | FOOT_F, 0.9, a)
    b = np.where(OUT_F | FOOT_F, 0.8, b)
    a = np.where(CRES, 0.85, a)
    b = np.where(CRES, 1.0, b)
    return b, a


def variant_A(f):
    bb, ba = shell_A(NB, BACK, CELL_BA, EDGE_BA, f, True)
    fb, fa = shell_A(NF, FRONT, CELL_FA, EDGE_FA, f, False)
    pal = PALS["blue"]
    return floor_layer(f, pal), to_img(bb, ba, BACK, pal), to_img(fb, fa, FRONT, pal)


# ---------------------------------------------------------------- B: Kutsal Run Kubbesi (altin meridyen kafes + zemin run cemberi)
N_MER = 8
PAR_STEP = math.radians(26.0)


def shell_B_ids(nvec, mask):
    az, el = angles(nvec)
    mer = np.floor((az + math.pi) / (2 * math.pi / N_MER) + 0.5).astype(int) % N_MER
    par = np.floor(el / PAR_STEP).astype(int)
    e_mer = edges(mer, mask) & (el < math.radians(70))
    e_par = edges(par, mask)
    return az, el, e_mer, e_par


AZ_FB, EL_FB, EM_FB, EP_FB = shell_B_ids(NF, FRONT)
AZ_BB, EL_BB, EM_BB, EP_BB = shell_B_ids(NB, BACK)
APEX = screen_of(np.array([0.0, R, 0.0]))


def star_mask(f):
    """Kubbenin tepesinde yanip sonen 4 kollu yildiz."""
    tw = 0.5 + 0.5 * math.sin(2 * math.pi * (f / FRAMES) * 2)
    ax, ay = APEX
    dx, dy = np.abs(xx + 0.5 - ax), np.abs(yy + 0.5 - ay)
    return ((dx < 1) & (dy < 3 + 2 * tw)) | ((dy < 1) & (dx < 3 + 2 * tw)) | (dx + dy < 1.6)


def shell_B(nvec, az, el, e_mer, e_par, f, back):
    t = f / FRAMES
    lines = e_mer | e_par
    a = 0.05 + 0.38 * RIM ** 2.5
    b = 0.45 + 0.35 * RIM
    a = np.where(lines, 0.6, a)
    b = np.where(lines, 0.55, b)
    # Meridyenlerden yukari tirmanan isik nabizlari (her meridyen farkli fazda)
    mer_i = np.floor((az + math.pi) / (2 * math.pi / N_MER) + 0.5) % N_MER
    ep = ((t * 2.0 + mer_i * 0.37) % 1.0) * (math.pi / 2)
    pulse = np.exp(-(((el - ep) / 0.09) ** 2)) * e_mer
    a = a + pulse * 0.4
    b = b + pulse * 0.45
    rp = ripple(nvec, f)
    a = a + rp * np.where(lines, 0.5, 0.28)
    b = b + rp * 0.5
    if back:
        return b * 0.8, a * 0.5
    a = np.where(OUT_F | FOOT_F, 0.9, a)
    b = np.where(OUT_F | FOOT_F, 0.85, b)
    # Tepede yildiz pariltisi
    star = star_mask(f)
    a = np.where(star, 1.0, a)
    b = np.where(star, 1.0, b)
    return b, a


def variant_B(f):
    pal = PALS["gold"]
    bb, ba = shell_B(NB, AZ_BB, EL_BB, EM_BB, EP_BB, f, True)
    fb, fa = shell_B(NF, AZ_FB, EL_FB, EM_FB, EP_FB, f, False)
    return floor_layer(f, pal, runes=True), to_img(bb, ba, BACK, pal), to_img(fb, fa, FRONT | star_mask(f), pal)


# ---------------------------------------------------------------- C: Isik Perdesi (en sade: sadece kenar isigi + yukselen isik cizgileri)
N_STREAK = 16
STREAK_AZ = rng.random(N_STREAK) * 2 * math.pi
STREAK_PH = rng.random(N_STREAK)
AZ_FC, EL_FC = angles(NF)
AZ_BC, EL_BC = angles(NB)


def shell_C(nvec, az, el, f, back):
    t = f / FRAMES
    a = 0.04 + 0.62 * RIM ** 2.6
    b = 0.25 + 0.6 * RIM
    streak = np.zeros((H, W))
    for k in range(N_STREAK):
        daz = np.abs(((az - STREAK_AZ[k] + math.pi) % (2 * math.pi)) - math.pi)
        width = 1.1 / (R * np.maximum(np.cos(el), 0.15))
        p = ((t + STREAK_PH[k]) % 1.0) * 1.7 - 0.2
        env = np.exp(-(((el - p) / 0.28) ** 2)) * np.clip(1.0 - el / 1.35, 0, 1)
        streak = np.maximum(streak, (daz < width) * env)
    a = a + streak * 0.55
    b = b + streak * 0.5
    rp = ripple(nvec, f)
    a = a + rp * 0.35
    b = b + rp * 0.55
    if back:
        return b * 0.85, a * 0.45
    a = np.where(FOOT_F, 0.85, a)
    b = np.where(FOOT_F, 0.8, b)
    a = np.where(CRES, 0.7, a)
    b = np.where(CRES, 1.0, b)
    return b, a


def variant_C(f):
    pal = PALS["pale"]
    bb, ba = shell_C(NB, AZ_BC, EL_BC, f, True)
    fb, fa = shell_C(NF, AZ_FC, EL_FC, f, False)
    return floor_layer(f, pal, strength=0.85), to_img(bb, ba, BACK, pal), to_img(fb, fa, FRONT, pal)


# ---------------------------------------------------------------- D: Kristal Kubbe (duz golgeli yuzeyler, kenarlarda isik)
PTS_D = fib_sphere(120)
CELL_FD = voronoi(NF, FRONT, PTS_D)
CELL_BD = voronoi(NB, BACK, PTS_D)
EDGE_FD = edges(CELL_FD, FRONT)
EDGE_BD = edges(CELL_BD, BACK)
LIGHT = norm([-0.55, 0.7, 0.45])
FACET_TONE = np.clip(PTS_D @ LIGHT, -1, 1) * 0.5 + 0.5
GLINT_ORDER = rng.permutation(len(PTS_D))


def shell_D(nvec, cell, edge, f, back):
    t = f / FRAMES
    c = np.clip(cell, 0, None)
    tone = FACET_TONE[c]
    a = 0.1 + 0.22 * tone + 0.25 * RIM ** 2
    b = 0.15 + 0.55 * tone
    a = np.where(edge, 0.6, a)
    b = np.where(edge, 0.78, b)
    # Her 3 karede bir yuzey beyaz parlar (yuzeyin kenarlari + hafif dolgu)
    g = GLINT_ORDER[(f // 3) % len(GLINT_ORDER)]
    g2 = GLINT_ORDER[(f // 3 + 7) % len(GLINT_ORDER)]
    hit = (c == g) | (c == g2)
    ph = 1.0 - (f % 3) / 3.0
    a = a + hit * np.where(edge, 0.4, 0.18) * ph
    b = b + hit * 0.45 * ph
    rp = ripple(nvec, f)
    a = a + rp * np.where(edge, 0.5, 0.25)
    b = b + rp * 0.5
    if back:
        return b * 0.7, a * 0.45
    a = np.where(OUT_F | FOOT_F, 0.9, a)
    b = np.where(OUT_F | FOOT_F, 0.85, b)
    a = np.where(CRES, 0.8, a)
    b = np.where(CRES, 1.0, b)
    return b, a


def variant_D(f):
    pal = PALS["cryst"]
    bb, ba = shell_D(NB, CELL_BD, EDGE_BD, f, True)
    fb, fa = shell_D(NF, CELL_FD, EDGE_FD, f, False)
    return floor_layer(f, pal), to_img(bb, ba, BACK, pal), to_img(fb, fa, FRONT, pal)


# ---------------------------------------------------------------- sahne: cimen, karakterler, silahlar, dusman mermisi
def make_grass():
    base = [(70, 122, 52), (80, 138, 58), (92, 152, 64), (62, 110, 48)]
    lo = rng.random((H // 8 + 2, W // 8 + 2))
    lo = np.kron(lo, np.ones((8, 8)))[:H, :W]
    n = lo * 0.6 + rng.random((H, W)) * 0.4
    idx = np.where(n > 0.78, 2, np.where(n > 0.5, 1, np.where(n < 0.18, 3, 0)))
    arr = np.array(base, np.uint8)[idx]
    img = Image.fromarray(arr, "RGB").convert("RGBA")
    px = img.load()
    for _ in range(90):  # kucuk cimen tutamlari
        x, y = int(rng.integers(2, W - 2)), int(rng.integers(3, H - 1))
        px[x, y - 1] = (104, 166, 70, 255)
        px[x - 1, y] = (104, 166, 70, 255)
        px[x + 1, y] = (56, 100, 44, 255)
    return up(img)


def load_char(name):
    sheet = Image.open(os.path.join(ROOT, "assets", "characters", name, "sheets", "idle.png")).convert("RGBA")
    frames = []
    s = round(48 * CHAR_PX * ZOOM)
    for i in range(4):
        fr = sheet.crop((i * 48, 0, i * 48 + 48, 48))
        frames.append(fr.resize((s, s), Image.NEAREST))
    return frames


WEAPON_FILES = ["tabanca/icon_v2.png", "tufek/icon.png", "uzunkilic/icon.png", "buz_asasi/icon.png",
                "crossbow/icon.png", "topuz/icon.png"]


def load_weapon(rel, size_world=26):
    im = Image.open(os.path.join(ROOT, "assets", "weapons", rel)).convert("RGBA")
    im = im.crop(im.getbbox())
    s = size_world * ZOOM / max(im.size)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    a = np.array(im)
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
    return Image.fromarray(a, "RGBA")


def weapon_slots(f, iso=True):
    """madde 154 sirasi: tepeden (arka) baslar, saat yonunde esit aralik. iso: zemin elipsi + yukseklik."""
    out = []
    n = len(WEAPON_FILES)
    for i in range(n):
        ang = -math.pi / 2 + 2 * math.pi * i / n
        gx, gz = math.cos(ang) * (R + RIM_GAP), math.sin(ang) * (R + RIM_GAP)
        bob = math.sin(2 * math.pi * (f / FRAMES + i / n)) * 1.5
        if iso:
            sx, sy = CX + gx, CY + gz * SIN
            out.append((i, gz, (sx, sy), (sx, sy - (HOVER + bob) * COS), gx < -1))
        else:
            sx, sy = CX + gx, CY + gz
            out.append((i, gz, (sx, sy + 9), (sx, sy + bob), gx < -1))
    return out


def blob_shadow(draw, x, y, rx, ry):
    draw.ellipse([(x - rx) * ZOOM, (y - ry) * ZOOM, (x + rx) * ZOOM, (y + ry) * ZOOM], fill=(20, 40, 20, 80))


def paste_center_bottom(canvas, img, x, y):
    canvas.alpha_composite(img, (round(x * ZOOM - img.width / 2), round(y * ZOOM - img.height)))


def paste_center(canvas, img, x, y):
    canvas.alpha_composite(img, (round(x * ZOOM - img.width / 2), round(y * ZOOM - img.height / 2)))


def projectile_layer(f):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    hx, hy = HIT_S
    sx0, sy0 = W + 6, hy - 18
    if HIT_F - 4 <= f < HIT_F:
        k = (f - (HIT_F - 4)) / 4.0
        x, y = sx0 + (hx - sx0) * k, sy0 + (hy - sy0) * k
        dx, dy = (hx - sx0) / 30.0, (hy - sy0) / 30.0
        for j in range(5, 0, -1):
            tx, ty = int(x - dx * j * 1.3), int(y - dy * j * 1.3)
            if 0 <= tx < W and 0 <= ty < H:
                px[tx, ty] = (255, 150, 60, 110 + 20 * (5 - j))
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                if 0 <= int(x) + ox < W and 0 <= int(y) + oy < H:
                    px[int(x) + ox, int(y) + oy] = (255, 230, 150, 255) if ox == 0 and oy == 0 else (255, 120, 40, 255)
    elif HIT_F <= f < HIT_F + 3:  # kivilcimlar
        age = f - HIT_F
        for k in range(7):
            a = 2 * math.pi * k / 7 + 0.3
            d = 3 + age * 4
            x, y = int(hx + math.cos(a) * d + 4), int(hy + math.sin(a) * d * 0.8)
            if 0 <= x < W and 0 <= y < H:
                px[x, y] = (255, 210, 120, 255 - age * 70)
    return up(img)


GRASS = None
CHARS = None
WEAPONS = None


def compose(variant_fn, f, label):
    floor, back, front = variant_fn(f)
    canvas = GRASS.copy()
    shadows = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadows)
    slots = weapon_slots(f)
    for _, _, (gx, gy), _, _ in slots:
        blob_shadow(sd, gx, gy, 7, 2.5)
    char_pos = [("sovalye", -20.0, 10.0), ("elara", 26.0, -16.0)]
    for _, x, z in char_pos:
        blob_shadow(sd, CX + x, CY + z * SIN, 8, 3)
    canvas.alpha_composite(shadows)
    canvas.alpha_composite(up(floor))
    for i, gz, _, (wx, wy), flip in sorted(slots, key=lambda s: s[1]):
        if gz < 0:
            w = WEAPONS[i].transpose(Image.FLIP_LEFT_RIGHT) if flip else WEAPONS[i]
            paste_center(canvas, w, wx, wy)
    canvas.alpha_composite(up(back))
    for name, x, z in sorted(char_pos, key=lambda c: c[2]):
        fr = CHARS[name][(f // 6) % 4]
        foot = 4 * CHAR_PX  # karenin altindaki bos satirlar
        paste_center_bottom(canvas, fr, CX + x, CY + z * SIN + foot)
    canvas.alpha_composite(up(front))
    for i, gz, _, (wx, wy), flip in sorted(slots, key=lambda s: s[1]):
        if gz >= 0:
            w = WEAPONS[i].transpose(Image.FLIP_LEFT_RIGHT) if flip else WEAPONS[i]
            paste_center(canvas, w, wx, wy)
    canvas.alpha_composite(projectile_layer(f))
    d = ImageDraw.Draw(canvas)
    font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 22)
    d.text((14, 12), label, font=font, fill=(0, 0, 0, 200))
    d.text((12, 10), label, font=font, fill=(255, 255, 255, 255))
    return canvas


def old_dome_panel(f):
    """Simdiki kubbe (duz daire, loop_sheet) + daire halkada silahlar - karsilastirma icin."""
    sheet = Image.open(os.path.join(ROOT, "assets", "fx", "paladin_dome", "loop_sheet.png")).convert("RGBA")
    fr = sheet.crop(((f % 16) * 264, 0, (f % 16) * 264 + 264, 264))
    canvas = GRASS.copy()
    for name, x, z in sorted([("sovalye", -20.0, 10.0), ("elara", 26.0, -16.0)], key=lambda c: c[2]):
        paste_center_bottom(canvas, CHARS[name][0], CX + x, CY + z * SIN + 4 * CHAR_PX)
    canvas.alpha_composite(up(fr), (round((CX - 132) * ZOOM), round((CY - 132) * ZOOM)))
    for i, gz, _, (wx, wy), flip in weapon_slots(f, iso=False):
        w = WEAPONS[i].transpose(Image.FLIP_LEFT_RIGHT) if flip else WEAPONS[i]
        paste_center(canvas, w, wx, wy)
    return canvas


def dashed_circle(canvas, r, col):
    d = ImageDraw.Draw(canvas)
    for k in range(0, 360, 6):
        a0, a1 = math.radians(k), math.radians(k + 3)
        d.line([((CX + math.cos(a0) * r) * ZOOM, (CY + math.sin(a0) * r) * ZOOM),
                ((CX + math.cos(a1) * r) * ZOOM, (CY + math.sin(a1) * r) * ZOOM)], fill=col, width=2)


def main():
    global GRASS, CHARS, WEAPONS
    os.makedirs(OUT, exist_ok=True)
    GRASS = make_grass()
    CHARS = {"sovalye": load_char("sovalye"), "elara": load_char("elara")}
    WEAPONS = [load_weapon(p) for p in WEAPON_FILES]
    variants = [(variant_A, "A  Petek Kubbe"), (variant_B, "B  Kutsal Run"),
                (variant_C, "C  Isik Perdesi"), (variant_D, "D  Kristal Kubbe")]
    pw, ph = W * ZOOM, H * ZOOM
    frames = []
    for f in range(FRAMES):
        sheet = Image.new("RGBA", (pw * 2 + 6, ph * 2 + 6), (16, 16, 20, 255))
        for k, (fn, label) in enumerate(variants):
            sheet.alpha_composite(compose(fn, f, label), ((k % 2) * (pw + 6), (k // 2) * (ph + 6)))
        frames.append(sheet)
        if f == HIT_F + 1:
            sheet.save(os.path.join(OUT, "sovalye_izo_kubbe_kare.png"))
        print("kare", f)
    pal_frames = [fr.convert("RGB").quantize(colors=255, method=Image.MEDIANCUT, dither=Image.NONE) for fr in frames]
    pal_frames[0].save(os.path.join(OUT, "sovalye_izo_kubbe_A-D.gif"), save_all=True, append_images=pal_frames[1:],
                       duration=int(1000 / FPS), loop=0, disposal=1)
    # Eski / yeni + oyun alani karsilastirmasi
    cmp_img = Image.new("RGBA", (pw * 2 + 6, ph), (16, 16, 20, 255))
    old = old_dome_panel(4)
    new = compose(variant_A, 4, "A (izometrik)")
    dashed_circle(new, R, (255, 80, 80, 230))
    font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 22)
    ImageDraw.Draw(old).text((12, 10), "SIMDIKI", font=font, fill=(255, 255, 255, 255))
    ImageDraw.Draw(new).text((12, ph - 34), "kirmizi kesik = bugunku koruma alani (daire)", font=ImageFont.truetype(
        "C:/Windows/Fonts/arial.ttf", 18), fill=(255, 200, 200, 255))
    cmp_img.alpha_composite(old, (0, 0))
    cmp_img.alpha_composite(new, (pw + 6, 0))
    cmp_img.save(os.path.join(OUT, "sovalye_izo_kubbe_eski_yeni.png"))
    print("tamam ->", OUT)


if __name__ == "__main__":
    main()
