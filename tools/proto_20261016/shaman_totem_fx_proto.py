"""Shaman v4 totem EFEKT prototipleri (madde 176 devami) - OYUNA BAGLI DEGIL.

Kullanici (2026-10-16, totemler oyuna baglandiktan sonra): "efektleri kotu yeni efektler tasarlar misin Q ve E icin".
Gercek cizicide (tools/proto_20261016/totem_capture.gd TC_MODE=genis) gorulen sorunlar: uc buyuk noktali halka ust uste (Q menzil 260
turuncu, E menzil 220 mavi, E alan 180 mor + rombik runler), soluk gri nabiz halkalari, mor renk yeni totemlerle uyumsuz (eski R'den
kalma), E'de muttefike ucan kucuk kalkan ikonu ucuz duruyor.

Oneri (her yonde ortak): totem basina TEK halka = alan hasari yaricapi 180 (dusmanin yandigi yer); Q menzili (260) ve E kalkan menzili
(220) ayrica cizilmez - atislar/aktarimlar kimin icinde oldugunu zaten gosterir. Renkler totemin elementi (Q ates, E mavi ruh).
Uc yon (her biri Q + E tum set: halka, 1 sn'lik nabiz, Q ates oku + isabet + alandaki dusmana yanma, E kalkan aktarimi + dusmana kivilcim):
  A Element Halkasi - kalin parlayan halka (icine dogru noktali sonus), uzerinde donen iki parlak yay; nabizda merkezden halkaya dalga;
                      Q iri ates topu + kuyruk + patlama, alandaki dusmanda alev dilleri; E totemden muttefike kavisli isik seridi +
                      basinin ustunde kalkan muhru + ayakta halka; dusmanda mavi kivilcim
  B Run Muhru       - halka + ic kesik halka + uzerinde yavasca donen 8 iri element runu (koyu taban diskli); nabizda runler parlar +
                      iceri isinlar + totem altinda muhur; Q runlu kure (donen kivilcimlar), isabette yerde ates muhru; E muttefikin
                      ayagi altinda muhur + isik sutunu + basinda run (Mana Kalkani "Muhur" dili); dusmanin basinda run
  C Akis            - cizgi YOK: sinir halka boyunca suzulen iri tanelerle (Q kor, E mavi isik) + renkli noktali kenar; nabizda
                      merkezden disa tane fiskirmasi; Q uzun alev ruhu + sarmal kor izi, isabette alev sutunu; E totemden muttefike
                      akan isik taneleri + baloncuk parlamasi; dusmanda iceri cekilen taneler
Olcek: 1 sanat px = Shaman pikseli (0.903 dunya); halka 180 dunya = 199 px; GIF x2 (kamera zoom 2'ye yakin), 12 kare = 1 sn.
Ilk surum cok soluktu (1 px ayrinti cimende kayboldu) -> her sey 2-3 kat iri: `dot` (dolu isik noktasi), kalin bantlar, 7x7 runler.
Ciktilar: tools/proto_20261016/totem_fx/ (.gdignore). Calistir: python tools/proto_20261016/shaman_totem_fx_proto.py
"""
import importlib.util
import math
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(HERE, "totem_fx")
_spec = importlib.util.spec_from_file_location("p2", os.path.join(HERE, "shaman_totem_proto2.py"))
art = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(art)

TAU = 2 * math.pi
FPS = 12
NF = 12
WPX = 0.903
R = round(180 / WPX)  # 199
CW, CH = 420, 424
OX, OY = 210, 214  # totem ayak noktasi
FIRE, SPIRIT = art.FIRE, art.SPIRIT
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
SMOKE = ((70, 66, 70), (110, 104, 108))


# ------------------------------------------------------------------ tuval
class Frame:
    def __init__(self):
        self.ground = np.zeros((CH, CW, 4), dtype=np.float32)  # zemin efekti (sprite'larin altinda)
        self.over = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))  # sprite'larin ustu
        self.sprites = []  # (ayak_y, img, x, y)

    def g_px(self, x, y, c, a):
        x, y = int(math.floor(x + 0.5)), int(math.floor(y + 0.5))
        if 0 <= x < CW and 0 <= y < CH and a > 0:
            cur = self.ground[y, x]
            a = min(1.0, a)
            cur[:3] = cur[:3] * (1 - a) + np.array(c[:3]) * a
            cur[3] = max(cur[3], a)

    def px(self, x, y, c, a=1.0):
        x, y = int(math.floor(x + 0.5)), int(math.floor(y + 0.5))
        if not (0 <= x < CW and 0 <= y < CH) or a <= 0:
            return
        a = min(1.0, a)
        cur = self.over.getpixel((x, y))
        if cur[3] == 0:
            self.over.putpixel((x, y), (c[0], c[1], c[2], int(255 * a)))
        else:
            self.over.putpixel((x, y), tuple(int(cur[i] * (1 - a) + c[i] * a) for i in range(3)) + (max(cur[3], int(255 * a)),))

    def glow(self, x, y, c, a=1.0, halo=0.35):
        if halo > 0:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                self.px(x + dx, y + dy, c, a * halo)
        self.px(x, y, c, a)

    def sprite(self, img, foot_x, foot_y, ax, ay):
        self.sprites.append((foot_y, img, int(foot_x - ax), int(foot_y - ay)))

    def compose(self, bg):
        out = bg.copy()
        g = np.zeros((CH, CW, 4), dtype=np.uint8)
        g[..., :3] = np.clip(self.ground[..., :3], 0, 255).astype(np.uint8)
        g[..., 3] = (np.clip(self.ground[..., 3], 0, 1) * 255).astype(np.uint8)
        out.alpha_composite(Image.fromarray(g, "RGBA"))
        for (_, img, x, y) in sorted(self.sprites, key=lambda s: s[0]):
            out.paste(img, (x, y), img)
        out.alpha_composite(self.over)
        return out


YY, XX = np.mgrid[0:CH, 0:CW]
DX, DY = XX - OX, YY - OY
DIST = np.hypot(DX, DY)
ANG = np.arctan2(DY, DX)
DITH = BAYER[YY % 4, XX % 4]


def ground_layer(fr, alpha, col):
    a = np.clip(alpha, 0, 1)[..., None]
    c = np.array(col[:3], dtype=np.float32)
    fr.ground[..., :3] = fr.ground[..., :3] * (1 - a) + c * a
    fr.ground[..., 3] = np.maximum(fr.ground[..., 3], a[..., 0])


def dot(fr, x, y, r, pal, a=1.0, halo=0.4):
    """Dolu isik noktasi: merkez beyaza yakin, kenar element rengi; cimende kaybolmasin diye 1 px'ten iri."""
    rr = int(math.ceil(r)) + 1
    for dy in range(-rr, rr + 1):
        for dx in range(-rr, rr + 1):
            d = math.hypot(dx, dy)
            if d <= max(0.5, r):
                c = pal[5] if d < r * 0.35 else (pal[4] if d < r * 0.7 else pal[3])
                fr.glow(x + dx, y + dy, c, a, halo if d > r - 1 else 0)


def ease_out(u):
    return 1 - (1 - u) ** 2.2


def bez(p0, p1, p2, s):
    return ((1 - s) ** 2 * p0[0] + 2 * (1 - s) * s * p1[0] + s * s * p2[0], (1 - s) ** 2 * p0[1] + 2 * (1 - s) * s * p1[1] + s * s * p2[1])


# ------------------------------------------------------------------ sahne
def load_char(rel, row=0, col=0, size=48):
    im = Image.open(os.path.join(ROOT, rel)).convert("RGBA")
    return im.crop((col * size, row * size, col * size + size, row * size + size))


def load_enemy():
    p = os.path.join(ROOT, "visuals", "Yaratıklar", "Tüm Yaratıklar", "Ağaç Canavarı 1", "PNG", "Ent1", "With_shadow", "Ent1_Walk_with_shadow.png")
    fr = Image.open(p).convert("RGBA").crop((0, 0, 128, 128))
    fr = fr.crop(fr.getbbox())
    k = 44 / fr.height
    return fr.resize((max(1, round(fr.width * k)), 44), Image.NEAREST)


SHAMAN = load_char("assets/characters/shaman/sheets/idle.png")
KNIGHT = load_char("assets/characters/sovalye/sheets/idle.png")
ENEMY = load_enemy()
TOTEM = {k: [art.totem_a(k, f) for f in range(art.FRAMES)] for k in ("q", "e")}
CORE = (0, -32)  # Q cekirdegi / E kalkani (totem ayagina gore)

SCENE = {
    "q": {"enemies": [(-132, -46), (104, 86)], "allies": [("shaman", (64, -92))], "target": 0},
    "e": {"enemies": [(36, 146)], "allies": [("shaman", (-104, -36)), ("knight", (98, 54))]},
}


def place_scene(fr, kind, f):
    tf = int(f * art.FPS / FPS) % art.FRAMES
    fr.sprite(TOTEM[kind][tf], OX, OY, 19, art.GY)
    for (ex, ey) in SCENE[kind]["enemies"]:
        fr.sprite(ENEMY, OX + ex, OY + ey, ENEMY.width // 2, ENEMY.height - 4)
    for (who, (ax, ay)) in SCENE[kind]["allies"]:
        fr.sprite(SHAMAN if who == "shaman" else KNIGHT, OX + ax, OY + ay, 24, 41)


def enemy_chest(e):
    return (OX + e[0], OY + e[1] - 18)


def ally_head(a):
    return (OX + a[0], OY + a[1] - 40)


# ------------------------------------------------------------------ ortak parcalar
def fireball(fr, x, y, vx, vy, f, pal=FIRE, size=1.0, tail=14):
    n = math.hypot(vx, vy) or 1.0
    ux, uy = vx / n, vy / n
    for k in range(int(tail), 0, -1):  # kuyruk (yeni dogan topta kisa - totemin icine uzanmasin)
        s = k * 1.0 * size
        jx = math.sin(f * 1.7 + k) * 0.8 * (k / 14) * size
        cx, cy = x - ux * s - uy * jx, y - uy * s + ux * jx
        rr = max(0.0, (2.7 - k * 0.17) * size)
        c = pal[3] if k < 4 else (pal[2] if k < 9 else pal[1])
        a = 1.0 - k / 15
        for dy in range(-5, 6):
            for dx in range(-5, 6):
                if math.hypot(dx, dy) <= rr:
                    fr.px(cx + dx, cy + dy, c, a)
    dot(fr, x, y, 3.4 * size, pal, 1.0, 0.45)


def burst(fr, x, y, u, pal, r0=3, r1=9, n=8, seed=0, smoke=True):
    """Patlama: dolu cekirdek + genisleyen 2 px halka + firlayan korlar + duman."""
    if u >= 1:
        return
    if u < 0.35:
        dot(fr, x, y, r0 + (r1 - r0) * u / 0.35 * 0.6, pal, 1.0, 0.4)
    ring = r0 + (r1 - r0) * ease_out(u)
    for i in range(int(TAU * ring * 1.3)):
        a = i / (ring * 1.3)
        for w in (0, 1):
            fr.px(x + math.cos(a) * (ring + w), y + math.sin(a) * (ring + w) * 0.8, pal[3 - w] if u < 0.5 else pal[2 - w], (1 - u) ** 1.1)
    for i in range(n):
        a = TAU * (i + 0.37 * seed) / n + seed
        d = 3 + r1 * 1.3 * ease_out(u)
        dot(fr, x + math.cos(a) * d, y + math.sin(a) * d * 0.8 - 8 * u * u, 1.4 * (1 - u * 0.6), pal, (1 - u) ** 0.8, 0.3)
    if smoke and u > 0.35:
        v = (u - 0.35) / 0.65
        for i in range(3):
            sx, sy = x + (i - 1) * 6, y - 4 - 14 * v - i
            for dy in range(-3, 4):
                for dx in range(-3, 4):
                    if math.hypot(dx, dy) <= 3.2 - v:
                        fr.px(sx + dx, sy + dy, SMOKE[1] if dy < 0 else SMOKE[0], 0.55 * (1 - v))


def flame_lick(fr, x, y, u, pal, h=13):
    """Yaratigin ayaginda alev dilleri (Q alan yanmasi)."""
    if u >= 1 or u < 0:
        return
    hh = h * math.sin(math.pi * min(1.0, u * 1.3))
    for k, off in enumerate((-6, 0, 6)):
        hk = hh * (1.0 if k == 1 else 0.7)
        for j in range(int(hk)):
            v = j / max(1, hk)
            w = 2.6 * (1 - v * 0.8)
            for dx in range(-3, 4):
                if abs(dx) <= w:
                    fr.glow(x + off + dx + math.sin(u * 9 + j * 0.8 + k) * v * 1.5, y - j,
                            pal[5] if (v < 0.2 and abs(dx) < 1) else (pal[4] if v < 0.4 else (pal[3] if v < 0.7 else pal[2])), 1 - u * 0.5, 0.25)


def sparks(fr, x, y, u, pal, n=6, seed=0):
    if u >= 1:
        return
    for i in range(n):
        a = TAU * i / n + seed
        d0, d1 = 3 + 10 * u, 8 + 14 * u
        for s in np.linspace(d0, d1, 6):
            fr.glow(x + math.cos(a) * s, y + math.sin(a) * s, pal[3], 1 - u, 0.35)
        dot(fr, x + math.cos(a) * d1, y + math.sin(a) * d1, 1.3, pal, 1 - u)


def mini_shield(fr, x, y, a, pal=SPIRIT):
    rows = (5, 6, 6, 6, 6, 6, 5, 5, 4, 3, 2, 1, 0)
    for j, hw in enumerate(rows):
        for dx in range(-hw, hw + 1):
            rim = j == 0 or abs(dx) == hw or j == len(rows) - 1
            c = (pal[4] if dx <= 0 else pal[3]) if rim else (pal[2] if dx < 0 else pal[1])
            fr.glow(x + dx, y + j - 6, c, a, 0.4 if rim else 0)
    for (dx, dy) in ((-3, -3), (0, -3), (3, -3), (-3, -2), (0, -2), (3, -2), (-2, -1), (-1, -1), (0, -1), (1, -1), (2, -1),
                     (0, 0), (0, 1), (0, 2)):
        fr.px(x + dx, y + dy, pal[5], a)


RUNES = {
    "q": (["...X...", "..XX...", "..X.X..", ".X..X..", "X..X..X", "X.....X", ".XXXXX."],
          ["X.....X", ".X...X.", "..X.X..", "...X...", "..X.X..", ".X...X.", "X.....X"]),
    "e": (["X..X..X", "X..X..X", ".X.X.X.", "..XXX..", "...X...", "...X...", "...X..."],
          ["..XXX..", ".X.X.X.", "X..X..X", "XXXXXXX", "X..X..X", ".X.X.X.", "..XXX.."]),
}


def rune(fr, x, y, kind, idx, c, a, ground=False):
    rows = RUNES[kind][idx % 2]
    pal = FIRE if kind == "q" else SPIRIT
    for dy in range(-6, 7):  # koyu element taban diski (run cimende okunsun)
        for dx in range(-6, 7):
            if math.hypot(dx, dy) <= 5.6:
                if ground:
                    fr.g_px(x + dx, y + dy, pal[0][:3], a * 0.6)
                else:
                    fr.px(x + dx, y + dy, pal[0], a * 0.55)
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == "X":
                if ground:
                    fr.g_px(x + i - 3, y + j - 3, c[:3], a)
                else:
                    fr.glow(x + i - 3, y + j - 3, c, a, 0.3)


def seal(fr, x, y, rx, ry, pal, a, rot, ground=True, runes=4):
    draw = fr.g_px if ground else (lambda px_, py_, c, al: fr.px(px_, py_, c, al))
    n = int(TAU * rx * 1.3)
    for i in range(n):
        ang = TAU * i / n
        px_, py_ = x + math.cos(ang) * rx, y + math.sin(ang) * ry
        draw(px_, py_, pal[4], a)
        draw(px_, py_ + 1, pal[3], a * 0.8)
        if i % 3 == 0:
            draw(x + math.cos(ang) * (rx - 4), y + math.sin(ang) * (ry - 1.7), pal[3], a * 0.75)
    for k in range(runes):
        ang = rot + TAU * k / runes
        cx, cy = x + math.cos(ang) * (rx - 2), y + math.sin(ang) * (ry - 0.8)
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1), (0, 1)):
            draw(cx + dx, cy + dy, pal[5], a)


# ------------------------------------------------------------------ A) ELEMENT HALKASI
def ring_A(fr, t, pal):
    d = DIST - R
    band = np.where(np.abs(d + 0.5) < 1.3, 1.0, np.where(np.abs(d + 0.5) < 2.6, 0.55, 0.0))
    inner = np.where((d < 0) & (d > -24), (1 + d / 24) * 0.75, 0.0)
    inner = np.where(DITH < inner, 0.55, 0.0)
    a0 = TAU * t * 0.25
    arc = np.exp(-((((ANG - a0) + math.pi) % TAU - math.pi) ** 2) / 0.06) + np.exp(-((((ANG - a0 - math.pi) + math.pi) % TAU - math.pi) ** 2) / 0.06)
    ground_layer(fr, inner, pal[2])
    ground_layer(fr, band, pal[3])
    ground_layer(fr, np.where(np.abs(d + 0.5) < 2.0, arc, 0), pal[5])


def ripple_A(fr, u, pal):
    if u >= 1:
        return
    rr = 10 + (R - 10) * ease_out(u)
    d = DIST - rr
    k = (1 - u) ** 0.6
    trail = np.where((d < -1.6) & (d > -14), np.where(DITH < (1 + d / 14) * 0.8, 0.75, 0), 0) * k
    edge = np.where(np.abs(d) < 1.6, 1.0, 0) * k
    ground_layer(fr, trail, pal[2])
    ground_layer(fr, edge, pal[4])


def q_A(fr, f):
    ## Kullanici (2026-10-16): "A guzel ancak Q'nun aurasi cok onemli degil, gerek yok ayrintili dis cizgilere ve disa dogru
    ## dalgalanan efektlere. Ates topunu duz bir sekilde atsin, tam totemin ucundaki atesten" -> Q'da halka/dalga YOK (alan hasari
    ## sadece dusmanin ayagindaki alev dilleriyle gorunur); top cekirdegin ICINDE dogar (kare 0), DUZ cizgide sabit hizla gider.
    sc = SCENE["q"]
    tgt = enemy_chest(sc["enemies"][sc["target"]])
    src = (OX + CORE[0], OY + CORE[1])
    vx, vy = tgt[0] - src[0], tgt[1] - src[1]
    dist = math.hypot(vx, vy)
    if f < 4:  # ucus 0.33 sn
        s = f / 4.0
        x, y = src[0] + vx * s, src[1] + vy * s
        size = 1.6 * (0.7 if f == 0 else 1.0)
        fireball(fr, x, y, vx, vy, f, FIRE, size, min(14, dist * s / size))
        if f < 2:  # ates parlamasi: cekirdek bir an buyur + kisa kivilcim isinlari
            u = f / 2.0
            dot(fr, src[0], src[1], 5.5 - 2.0 * u, FIRE, 1.0 - 0.4 * u, 0.5)
            sparks(fr, src[0], src[1] - 1, 0.25 + 0.5 * u, FIRE, 7, 0.3)
    else:
        burst(fr, tgt[0], tgt[1], (f - 4) / 7.0, FIRE, 4, 16, 12, 2)
    for i, e in enumerate(sc["enemies"]):
        flame_lick(fr, OX + e[0], OY + e[1] - 1, (f - i) / 6.0, FIRE)


def e_A(fr, f):
    t = f / NF
    ring_A(fr, t, SPIRIT)
    ripple_A(fr, f / 6.0, SPIRIT)
    src = (OX + CORE[0], OY + CORE[1] + 1)
    for (who, a) in SCENE["e"]["allies"]:
        dst = (OX + a[0], OY + a[1] - 22)
        ctrl = ((src[0] + dst[0]) / 2, min(src[1], dst[1]) - 34)
        p = min(1.0, (f + 0.5) / 3.5)
        fade = 1.0 if f < 4 else max(0.0, 1 - (f - 3) / 3)
        steps = 46
        for i in range(steps + 1):
            s = i / steps
            if s > p or s < p - 0.55:
                continue
            k = 1 - (p - s) / 0.55
            x, y = bez(src, ctrl, dst, s)
            dot(fr, x, y, 0.6 + 1.2 * k, SPIRIT, fade * (0.45 + 0.55 * k), 0.5)
        if f < 4:
            x, y = bez(src, ctrl, dst, p)
            dot(fr, x, y, 2.8, SPIRIT, 1.0, 0.6)
        if f >= 3:
            u = (f - 3) / 7.0
            if u < 1:
                hx, hy = ally_head(a)
                mini_shield(fr, hx, hy - 6 - 6 * ease_out(u), (1 - u) ** 0.6 if u > 0.3 else 1.0)
                for i in range(48):  # ayakta parlama halkasi (2 px)
                    ang = TAU * i / 48
                    for w in (0, 1):
                        fr.px(OX + a[0] + math.cos(ang) * (10 + 8 * u + w), OY + a[1] + 1 + math.sin(ang) * (4 + 3 * u + w * 0.5), SPIRIT[3 + w], (1 - u) * 0.95)
    for e in SCENE["e"]["enemies"]:
        sparks(fr, OX + e[0], OY + e[1] - 16, f / 4.0, SPIRIT, 6, 0.4)


# ------------------------------------------------------------------ B) RUN MUHRU
def ring_B(fr, t, pal, kind, flash):
    rot = TAU * t / 12.0
    gaps = np.zeros_like(DIST, dtype=bool)
    rune_pos = []
    for i in range(8):
        a = rot + TAU * i / 8
        rune_pos.append((OX + math.cos(a) * R, OY + math.sin(a) * R, i))
        da = np.abs(((ANG - a) + math.pi) % TAU - math.pi) * R
        gaps |= da < 8
    d = DIST - R
    line = np.where((np.abs(d + 0.5) < 1.2) & ~gaps, 0.95, 0.0)
    dash = (((ANG - rot * 2) * (R - 9) / 5).astype(int) % 2) == 0
    dots = np.where((np.abs(d + 9) < 1.0) & dash & ~gaps, 0.6, 0.0)
    ground_layer(fr, dots, pal[2])
    ground_layer(fr, line, pal[3])
    for (x, y, i) in rune_pos:
        seq = int(t * 8) % 8 == i
        c = pal[5] if (flash > 0 or seq) else pal[4]
        rune(fr, x, y, kind, i, c, 1.0, ground=True)
        if flash > 0:  # iceri isinlar (2 px)
            for s in range(9, 46):
                k = 1 - s / 46
                bx, by = x + (OX - x) * s / R, y + (OY - y) * s / R
                fr.g_px(bx, by, pal[4], flash * k)
                fr.g_px(bx + 1, by, pal[3], flash * k * 0.8)


def q_B(fr, f):
    t = f / NF
    ring_B(fr, t, FIRE, "q", max(0.0, 1 - f / 3.0))
    if f < 6:
        seal(fr, OX, OY + 1, 24, 10, FIRE, 1 - f / 6, t * 3)
    sc = SCENE["q"]
    e0 = sc["enemies"][sc["target"]]
    tgt = enemy_chest(e0)
    src = (OX + CORE[0], OY + CORE[1])
    if f < 4:
        s = (f + 0.5) / 4
        x, y = src[0] + (tgt[0] - src[0]) * s, src[1] + (tgt[1] - src[1]) * s
        for k in range(1, 9):  # iz
            dot(fr, x - (tgt[0] - src[0]) * 0.025 * k, y - (tgt[1] - src[1]) * 0.025 * k, 1.6 - k * 0.15, FIRE, 1 - k / 9, 0)
        dot(fr, x, y, 4.2, FIRE, 1.0, 0.5)
        for k in range(3):
            a = TAU * (f / 4 + k / 3)
            dot(fr, x + math.cos(a) * 8, y + math.sin(a) * 8, 1.2, FIRE, 1.0)
    else:
        u = (f - 4) / 7.0
        seal(fr, OX + e0[0], OY + e0[1] + 1, 18 + 4 * u, 7 + 1.5 * u, FIRE, (1 - u), u * 2)
        burst(fr, tgt[0], tgt[1], u, FIRE, 3, 12, 10, 3, False)
    for e in sc["enemies"]:
        u = f / 5.0
        if u < 1:
            rune(fr, OX + e[0], OY + e[1] - 50 - 4 * u, "q", 0, FIRE[5] if u < 0.4 else FIRE[4], 1 - u)


def e_B(fr, f):
    t = f / NF
    ring_B(fr, t, SPIRIT, "e", max(0.0, 1 - f / 3.0))
    if f < 6:
        seal(fr, OX, OY + 1, 24, 10, SPIRIT, 1 - f / 6, t * 3)
    src = (OX + CORE[0], OY + CORE[1] + 1)
    for (who, a) in SCENE["e"]["allies"]:
        dst = (OX + a[0], OY + a[1] - 22)
        if f < 2:  # hizli run kivilcimi (duz cizgi)
            s = (f + 1) / 2
            for k in range(12):
                ss = s - k * 0.04
                if ss >= 0:
                    dot(fr, src[0] + (dst[0] - src[0]) * ss, src[1] + (dst[1] - src[1]) * ss, 2.4 - k * 0.17, SPIRIT, 1 - k / 12, 0.4)
        else:
            u = (f - 2) / 8.0
            if u < 1:
                seal(fr, OX + a[0], OY + a[1] + 1, 17, 7, SPIRIT, (1 - u) ** 0.7, u * 4)
                hcol = 46 * min(1.0, u / 0.3)  # isik sutunu (seritler)
                for j in range(int(hcol)):
                    v = j / 46
                    for dx in (-8, -4, 0, 4, 8):
                        if (j + abs(dx) + f * 2) % 4 < 2:
                            fr.glow(OX + a[0] + dx, OY + a[1] - j, SPIRIT[4] if abs(dx) < 5 else SPIRIT[3], (1 - u) * (1 - v) * 0.9, 0.3)
                hx, hy = ally_head(a)
                rune(fr, hx, hy - 10 - 4 * u, "e", 0, SPIRIT[5] if u < 0.3 else SPIRIT[4], (1 - u))
    for e in SCENE["e"]["enemies"]:
        u = f / 5.0
        if u < 1:
            rune(fr, OX + e[0], OY + e[1] - 50 - 4 * u, "e", 1, SPIRIT[5] if u < 0.4 else SPIRIT[4], 1 - u)


# ------------------------------------------------------------------ C) AKIS
def ring_C(fr, t, pal, kind):
    ## renk cimenle %50 karisinca camurlasiyordu (zeytin / camgobegi) -> seyrek ama TAM renkli parlak noktalar
    edge = np.where((DIST < R + 1) & (DIST > R - 18), (1 - np.abs(R - 4 - DIST) / 14) * 0.42, 0.0)
    ground_layer(fr, np.where(DITH < edge, 0.9, 0.0), pal[3])
    n = 44
    for i in range(n):
        ph = (i * 0.618) % 1.0
        a = TAU * i / n + TAU * t * 0.04
        u = (t + ph) % 1.0
        rr = R - 2 + math.sin(TAU * (u + i * 0.3)) * 2
        x, y = OX + math.cos(a) * rr, OY + math.sin(a) * rr
        if kind == "q":
            y -= u * 12
            al = math.sin(math.pi * u)
            dot(fr, x, y, 1.7 - u, pal, al, 0.4)
            fr.px(x, y + 2, pal[2], al * 0.6)
        else:
            al = 0.6 + 0.4 * math.sin(TAU * (u + ph))
            dot(fr, x, y - 2 * math.sin(TAU * u), 1.4, pal, al, 0.45)
            if (i + int(t * NF)) % 7 == 0:
                for k in (2, 3, 4):
                    for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
                        fr.px(x + dx, y + dy, pal[4] if k < 4 else pal[3], al)


def spray_C(fr, u, pal, seed=0.0):
    if u >= 1:
        return
    for i in range(20):
        a = TAU * i / 20 + seed
        for k in range(6):
            d = 12 + (R - 16) * ease_out(max(0.0, u - k * 0.02))
            if k == 0:
                dot(fr, OX + math.cos(a) * d, OY + math.sin(a) * d, 1.8, pal, 1 - u, 0.5)
            else:
                fr.px(OX + math.cos(a) * d, OY + math.sin(a) * d, pal[3], (1 - u) * (1 - k / 6))


def flame_spirit(fr, x, y, vx, vy, f, k_=1.0):
    n = math.hypot(vx, vy) or 1.0
    ux, uy = vx / n, vy / n
    nx, ny = -uy, ux
    for s in np.linspace(-9 * k_, 3 * k_, int(26 * k_)):
        v = (s + 9 * k_) / (12 * k_)
        w = 2.6 * k_ * math.sin(math.pi * min(1.0, v * 1.05)) ** 0.7
        fl = math.sin(f * 2.1 + s) * 0.8 * (1 - v)
        for k in np.linspace(-w, w, max(1, int(w * 2) + 1)):
            c = FIRE[5] if (v > 0.7 and abs(k) < 1) else (FIRE[4] if v > 0.5 and abs(k) < w * 0.6 else (FIRE[3] if v > 0.3 else FIRE[2]))
            fr.glow(x + ux * s + nx * (k + fl), y + uy * s + ny * (k + fl), c, 1.0, 0.25 if abs(k) > w - 1 else 0)
    for k in range(2):  # sarmal korlar
        a = f * 1.9 + k * math.pi
        for j in range(1, 6):
            dot(fr, x - ux * (8 + j * 3) * k_ + nx * math.sin(a - j * 0.9) * 5, y - uy * (8 + j * 3) * k_ + ny * math.sin(a - j * 0.9) * 5,
                1.4 - j * 0.15, FIRE, 1 - j / 6, 0)


def column_C(fr, x, y, u, pal, k_=1.0):
    if u >= 1:
        return
    h = 16 * k_ * math.sin(math.pi * min(1.0, u * 1.4))
    for j in range(int(h)):
        v = j / max(1, h)
        w = 3.2 * k_ * (1 - v * 0.7)
        sw = math.sin(u * 10 + j * 0.6) * v * 1.5
        for dx in np.linspace(-w, w, int(w * 2) + 1):
            c = pal[5] if (v < 0.25 and abs(dx) < 1.2) else (pal[4] if v < 0.5 else (pal[3] if v < 0.8 else pal[2]))
            fr.glow(x + dx + sw, y - j, c, 1 - u * 0.4, 0.2)


def q_C(fr, f):
    t = f / NF
    ring_C(fr, t, FIRE, "q")
    spray_C(fr, f / 6.0, FIRE, 0.1)
    sc = SCENE["q"]
    e0 = sc["enemies"][sc["target"]]
    tgt = enemy_chest(e0)
    src = (OX + CORE[0], OY + CORE[1])
    if f < 4:
        s = (f + 0.5) / 4
        x, y = src[0] + (tgt[0] - src[0]) * s, src[1] + (tgt[1] - src[1]) * s
        flame_spirit(fr, x, y, tgt[0] - src[0], tgt[1] - src[1], f, 1.7)
    else:
        column_C(fr, OX + e0[0], OY + e0[1] - 2, (f - 4) / 7.0, FIRE, 1.7)
        burst(fr, tgt[0], tgt[1], (f - 4) / 7.0, FIRE, 3, 10, 10, 5, False)
    for i, e in enumerate(sc["enemies"]):
        u = (f - i) / 5.0
        if 0 <= u < 1:
            for k in range(8):
                a = TAU * k / 8
                d = 14 * (1 - u)
                dot(fr, OX + e[0] + math.cos(a) * d, OY + e[1] - 14 + math.sin(a) * d * 0.7 - 8 * u, 1.5, FIRE, 1 - u)


def e_C(fr, f):
    t = f / NF
    ring_C(fr, t, SPIRIT, "e")
    spray_C(fr, f / 6.0, SPIRIT, 0.2)
    src = (OX + CORE[0], OY + CORE[1] + 1)
    for (who, a) in SCENE["e"]["allies"]:
        dst = (OX + a[0], OY + a[1] - 22)
        ctrl = ((src[0] + dst[0]) / 2 + (dst[1] - src[1]) * 0.25, (src[1] + dst[1]) / 2 - 24)
        for m in range(5):
            s = (f - m * 0.7) / 4.0
            if 0 <= s <= 1:
                x, y = bez(src, ctrl, dst, s)
                dot(fr, x, y, 2.2, SPIRIT, 1.0, 0.5)
                for k in range(1, 5):
                    xk, yk = bez(src, ctrl, dst, max(0.0, s - 0.03 * k))
                    dot(fr, xk, yk, 1.4 - k * 0.25, SPIRIT, 1 - k / 5, 0)
        u = (f - 4) / 6.0
        if 0 <= u < 1:
            for i in range(60):  # baloncuk parlamasi (2 px)
                ang = TAU * i / 60
                rx, ry = 14 + 3 * u, 21 + 3 * u
                for w in (0, 1):
                    fr.px(OX + a[0] + math.cos(ang) * (rx + w), OY + a[1] - 18 + math.sin(ang) * (ry + w),
                          SPIRIT[4 - w] if math.sin(ang) < 0 else SPIRIT[3 - w], (1 - u) * 0.9)
    for e in SCENE["e"]["enemies"]:
        u = f / 5.0
        if u < 1:
            for k in range(8):
                a = TAU * k / 8 + 0.3
                d = 14 * (1 - u)
                dot(fr, OX + e[0] + math.cos(a) * d, OY + e[1] - 14 + math.sin(a) * d * 0.7, 1.5, SPIRIT, 1 - u)


DIRS = [("A", "Element Halkasi", q_A, e_A), ("B", "Run Muhru", q_B, e_B), ("C", "Akis", q_C, e_C)]


def render(fn, kind, f, bg):
    fr = Frame()
    place_scene(fr, kind, f)
    fn(fr, f)
    return fr.compose(bg)


def main():
    os.makedirs(OUT, exist_ok=True)
    open(os.path.join(OUT, ".gdignore"), "w").close()
    bg = art.grass_bg(CW, CH, seed=4)
    for (key, name, qf, ef) in DIRS:
        frames = []
        for f in range(NF):
            q = render(qf, "q", f, bg)
            e = render(ef, "e", f, bg)
            im = Image.new("RGBA", (CW * 2 + 6, CH), (34, 40, 30, 255))
            im.paste(q, (0, 0))
            im.paste(e, (CW + 6, 0))
            im = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
            frames.append(im.convert("RGB"))
            if f in (1, 5):
                im.save(os.path.join(OUT, "fx_%s_kare%d.png" % (key, f)))
        frames[0].save(os.path.join(OUT, "fx_%s.gif" % key), save_all=True, append_images=frames[1:], duration=int(1000 / FPS), loop=0)
        print(key, name, "ok")


if __name__ == "__main__":
    main()
