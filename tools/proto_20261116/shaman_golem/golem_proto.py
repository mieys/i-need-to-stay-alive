#!/usr/bin/env python3
"""Shaman R ELEMENTAL GOLEM formu - yeni GORUNUS prototipleri (2026-11-16; oyuna bagli DEGIL).

Kullanici: "Shamanin ultisindeki golem formu icin yeni prototip hazirla". Mekanik / sayilar / darbe efektleri DEGISMEZ,
yalniz golemin GOVDESI. Kullanicinin "ai gorsel sevmiyorum" notu (2026-11-16) yuzunden govde kodla CIZILMEZ: ya
kullanicinin KENDI cizimlerinden ya da oyundaki piksel sanatci golem paketlerinden kurulur.
  Su anki : tools/gen_shaman_golem.py'nin kodla cizdigi tas + boynuz golem (karsilastirma icin)
  A  Run Tasi Golemi  : Shaman'in Q/E RUN TASLARI (kullanicinin 32x32 cizimleri + madde 569'un akkor run / hale / tas isigi
                        dokulari AYNEN) havada suzulen 5 parca: bas = E tasi (mavi run = yuz), gogus = iki Q tasi (kor runler),
                        yumruklar = runsuz taslar. Tas pikseli = Shaman pikseli (0,903 dunya), totemlerle ayni.
  B  Yosun Golemi     : Golem 1 paketi (Necro'nun golemiyle AYNI cizim) - yalniz TON zeytine
  C  Kehribar Kristal : Golem 2 paketi (zindan yaratigi) - mor kristaller kehribara
  D  Boynuzlu Muhafiz : Golem 3 paketi (zindan avcisi "Boynuzlu Bekci") - mavi dikenler yosun yesiline; kirmizi tac + kor gogus ayni
Ton = YIQ (I, Q) dondurme, parlaklik birebir (renk_ayar.rotate_hue; hafiza "Recolor = hue only").
Olcu: kamera x2; Shaman / Su anki / A pikseli 0,903 dunya; paket pikseli 1,52325 x EntityScale.SIZE 0,8075 = 1,230 dunya
(golem_pet.tscn / enemy_golem*.tscn ile ayni). Paket gölgesi (40,41,63,89) govdeden ayrilip elips olarak yeniden cizilir
(sicrayista yerde kalsin diye). Arka plan = haritanin cimen karosu (Ground_grass gid 135, toprak 78 ustunde).
Cikti out/: suan.gif A.gif B.gif C.gif D.gif, karsilastirma.gif (5'i ayni anda), ozet.png (4 yon + darbe ani + sicrayis tepesi
+ paketlerde 2 ton secenegi).
Kullanim (repo kokunden): python tools/proto_20261116/shaman_golem/golem_proto.py
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "proto_20261109", "yetenek_ikon"))
import renk_ayar as RA  # noqa: E402

OUT = os.path.join(HERE, "out")
ZOOM = 2.0
FPS = 20
T_CHAR = 2.2368375 * 0.8075 * 0.5  # Shaman sanat pikseli (dunya birimi)
T_PACK = 1.52325 * 0.8075  # golem paketi pikseli (dunya birimi)
GOLEM_SH = (19.0, 5.5)  # oyuncu golem gölgesi yari eksenleri (dunya) ~ insan (8.3, 3.4) x SHADOW_SCALE (2.3, 1.6)
HUMAN_SH = (8.3, 3.4)


def P(*a):
    return os.path.join(ROOT, *a)


def load(*a):
    return Image.open(P(*a)).convert("RGBA")


def ease_out(x):
    x = min(max(x, 0.0), 1.0)
    return 1 - (1 - x) * (1 - x)


def ease_in(x):
    x = min(max(x, 0.0), 1.0)
    return x * x


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def lerp(a, b, k):
    return a + (b - a) * k


def player_shadow(img, cx, cy, rx, ry):
    """ground_shadow.gd gibi iki tonlu (ic 0,2 / kenar 0,28) piksel elips - img'nin kendi piksel izgarasinda."""
    lay = Image.new("RGBA", img.size)
    d = ImageDraw.Draw(lay)
    box = (round(cx - rx), round(cy - ry), round(cx + rx), round(cy + ry))
    d.ellipse(box, fill=(0, 0, 0, 51), outline=(0, 0, 0, 71))
    img.alpha_composite(lay)


# ---------------------------------------------------------------------------------------------------------------
# Su anki golem (tools/gen_shaman_golem.py ciktisi)
class CurrentGolem:
    name = "Şu anki"
    W, H, FEET = 96, 144, 88
    ROW = {"down": 0, "left": 1, "right": 2, "up": 3}
    JUMP_D = [1.4, 1.0, 1.6, 1.6, 1.6, 1.0, 1.6, 1.4]
    JUMP_SH = [1.05, 0.9, 0.7, 0.6, 0.66, 0.85, 1.15, 1.05]
    texel = T_CHAR
    anchor = (48, 88)
    impact_t = {"slam": 3 / 14.0 + 0.01, "jump": 0.24}

    def __init__(self):
        self.sheet = load("assets", "characters", "shaman", "golem_sheet.png")

    def cell(self, clip, d, f):
        r = clip * 4 + self.ROW[d]
        return self.sheet.crop((f * self.W, r * self.H, f * self.W + self.W, r * self.H + self.H))

    def frame(self, state, d, t):
        clip, f, shk = 0, int(t * 5) % 4, 1.0
        if state == "walk":
            clip, f = 1, int(t * 9) % 6
        elif state == "slam" and t < 6 / 14.0:
            clip, f = 2, int(t * 14)
        elif state == "jump":
            acc = 0.0
            for i, dd in enumerate(self.JUMP_D):
                acc += dd / 20.0
                if t < acc:
                    clip, f, shk = 3, i, self.JUMP_SH[i]
                    break
        img = Image.new("RGBA", (self.W, self.H))
        player_shadow(img, 48, 88, GOLEM_SH[0] / T_CHAR * shk, GOLEM_SH[1] / T_CHAR * shk)
        img.alpha_composite(self.cell(clip, d, f))
        return img


# ---------------------------------------------------------------------------------------------------------------
# Paket golemleri (B / C / D)
PACK_PATH = "visuals/Yaratıklar/Tüm Yaratıklar/Golem %d/PNG/Golem%d/With_shadow/Golem%d_%s_with_shadow.png"
PACK_ROW = {"down": 0, "up": 1, "left": 2, "right": 3}
SH_RGB = (40, 41, 63)
PACK_JUMP = [(1, 0.10), (2, 0.10), (3, 0.30), (4, 0.12), (5, 0.12), (6, 0.07), (7, 0.07), (8, 0.07)]
JUMP_PEAK = 26.0  # dunya birimi
HEAD = 40  # paket hucresinin ustune sicrayis payi


def recolor(im, target, band=None):
    """Yalniz TON: govde piksellerinin (band verilirse o ton araligi) baskin tonu target'in tonuna doner, Y ayni."""
    a = np.asarray(im)
    w = (a[..., 3] > 0).astype(float)
    if band:
        w = w * RA.hue_band(im, band[0], band[1])
    rgb = np.asarray(RA.rotate_hue(im, target, weight=w))
    return Image.fromarray(np.dstack([rgb, a[..., 3]]).astype(np.uint8), "RGBA")


def pack_lift(t):
    if t < 0.18:
        return 0.0
    if t < 0.42:
        return JUMP_PEAK * math.sin((t - 0.18) / 0.24 * math.pi / 2)
    if t < 0.62:
        return JUMP_PEAK * (1 - ease_in((t - 0.42) / 0.20))
    return 0.0


class PackGolem:
    texel = T_PACK
    anchor = (64, 80 + HEAD)
    impact_t = {"slam": 5 / 14.0 + 0.01, "jump": 0.42}

    def __init__(self, n, name, target=None, band=None):
        self.n, self.name, self.target, self.band = n, name, target, band
        self.sheets = {}
        for clip in ("Idle", "Walk", "Attack"):
            im = load(PACK_PATH % (n, n, n, clip))
            a = np.asarray(im).copy()
            sh = (a[..., 0] == SH_RGB[0]) & (a[..., 1] == SH_RGB[1]) & (a[..., 2] == SH_RGB[2])
            a[sh] = 0
            im = Image.fromarray(a, "RGBA")
            if target:
                im = recolor(im, target, band)
            self.sheets[clip] = im
        # gölge elipsi: Idle 0. karede gölge renkli piksellerin en genis satiri = merkez, alt kenar - merkez = ry
        idle = np.asarray(load(PACK_PATH % (n, n, n, "Idle")))
        self.sh = {}
        for d, r in PACK_ROW.items():
            c = idle[r * 128:(r + 1) * 128, 0:128]
            m = (c[..., 0] == SH_RGB[0]) & (c[..., 1] == SH_RGB[1]) & (c[..., 2] == SH_RGB[2]) & (c[..., 3] > 0)
            ys, xs = np.nonzero(m)
            rows = np.bincount(ys)
            cy = int(np.argmax(rows))
            self.sh[d] = ((xs.min() + xs.max() + 1) / 2.0, cy + 0.5, (xs.max() - xs.min() + 1) / 2.0, ys.max() + 1 - cy - 0.5)

    def tinted(self, target, band):
        g = PackGolem.__new__(PackGolem)
        g.__dict__.update(self.__dict__)
        g.sheets = {}
        for clip in ("Idle", "Walk", "Attack"):
            im = load(PACK_PATH % (self.n, self.n, self.n, clip))
            a = np.asarray(im).copy()
            a[(a[..., 0] == SH_RGB[0]) & (a[..., 1] == SH_RGB[1]) & (a[..., 2] == SH_RGB[2])] = 0
            g.sheets[clip] = recolor(Image.fromarray(a, "RGBA"), target, band)
        return g

    def frame(self, state, d, t):
        lift = 0.0
        if state == "walk":
            clip, f = "Walk", int(t * 10) % 8
        elif state == "slam":
            clip, f = "Attack", min(int(t * 14), 8)
        elif state == "jump":
            clip, f, acc = "Attack", 8, 0.0
            for ff, dd in PACK_JUMP:
                acc += dd
                if t < acc:
                    f = ff
                    break
            lift = pack_lift(t)
        else:
            clip, f = "Idle", int(t * 7) % 4
        r = PACK_ROW[d]
        cell = self.sheets[clip].crop((f * 128, r * 128, f * 128 + 128, r * 128 + 128))
        img = Image.new("RGBA", (128, 128 + HEAD))
        cx, cy, rx, ry = self.sh[d]
        k = 1 - 0.38 * lift / JUMP_PEAK
        lay = Image.new("RGBA", img.size)
        ImageDraw.Draw(lay).ellipse((round(cx - rx * k), round(cy + HEAD - ry * k), round(cx + rx * k) - 1,
                                     round(cy + HEAD + ry * k) - 1), fill=SH_RGB + (89,))
        img.alpha_composite(lay)
        img.alpha_composite(cell, (0, HEAD - round(lift / T_PACK)))
        return img


# ---------------------------------------------------------------------------------------------------------------
# A - Run Tasi Golemi (kullanicinin run tasi cizimleri + oyundaki run dokulari)
RS = ("assets", "shaman", "rune_stone")
STONE = {k: load(*RS, "%s_tas.png" % k) for k in "qe"}
ISIK = {k: load(*RS, "%s_tas_isik.png" % k) for k in "qe"}
RUNES = {k: load(*RS, "%s_runler.png" % k) for k in "qe"}
_piece_cache = {}


def _alpha(im, a):
    im = im.copy()
    al = np.asarray(im.getchannel("A")).astype(float) * a
    im.putalpha(Image.fromarray(np.clip(al, 0, 255).astype(np.uint8)))
    return im


def piece(kind, rune_row, mirror, halo, glow):
    """36x36: tas isigi (tasin disinda) + tas + hale + akkor run; alfa 1/8 basamakli (oyundaki gibi)."""
    halo = round(min(halo, 1.0) * 8) / 8.0
    glow = round(min(glow, 1.0) * 8) / 8.0
    key = (kind, rune_row, mirror, halo, glow)
    if key in _piece_cache:
        return _piece_cache[key]
    c = Image.new("RGBA", (36, 36))
    if glow > 0:
        c.alpha_composite(_alpha(ISIK[kind], glow), (0, 0))
    c.alpha_composite(STONE[kind], (2, 2))
    if rune_row is not None:
        sh = RUNES[kind]
        if halo > 0:
            c.alpha_composite(_alpha(sh.crop((32, rune_row * 32, 64, rune_row * 32 + 32)), halo), (2, 2))
        c.alpha_composite(sh.crop((0, rune_row * 32, 32, rune_row * 32 + 32)), (2, 2))
    if mirror:
        c = ImageOps.mirror(c)
    _piece_cache[key] = c
    return c


# parcalar: ad -> (tas, run satiri, ayna, merkez (x, y) yere gore, havada suzulme dahil); y negatif = yukari
A_FRONT = {
    "head": ("e", 0, False, (0, -62)),
    "chestL": ("q", 0, True, (-11, -40)),
    "chestR": ("q", 0, False, (11, -40)),
    "fistL": ("e", None, True, (-28, -22)),
    "fistR": ("q", None, False, (28, -22)),
}
A_PHASE = {"head": 0.0, "chestL": 0.9, "chestR": 1.7, "fistL": 2.6, "fistR": 3.4}
FIST_UP = {"fistL": (-15, -80), "fistR": (15, -80)}
FIST_GROUND = {"fistL": (-10, -15), "fistR": (10, -15)}


class RuneGolem:
    name = "A - Rün Taşı Golemi"
    texel = T_CHAR
    W, H = 128, 150
    anchor = (64, 136)
    impact_t = {"slam": 0.31, "jump": 0.42}

    def layout(self, state, d, t):
        """-> (cizim sirasi [(ad, tas, run, ayna, x, y)], kaldirma, parlama)"""
        pos = {k: list(v[3]) for k, v in A_FRONT.items()}
        flare_dt = None
        lift = 0.0
        # suzulme (totem taslari gibi 2,6 sn, +-1,6)
        bob = {k: 1.6 * math.sin(2 * math.pi * t / 2.6 + A_PHASE[k]) for k in pos}
        if state == "walk":
            ph = 2 * math.pi * t / 0.6
            for k in ("head", "chestL", "chestR"):
                bob[k] += 1.0 * math.sin(2 * ph)
            if d in ("down", "up"):
                pos["fistL"][1] += 2.5 * math.sin(ph)
                pos["fistR"][1] -= 2.5 * math.sin(ph)
        if state in ("slam", "jump"):
            if state == "slam":
                t_up, t_hold, t_hit, t_back0, t_back1 = 0.20, 0.24, 0.30, 0.40, 0.65
                crouch = 0.0
            else:
                t_up, t_hold, t_hit, t_back0, t_back1 = 0.42, 0.55, 0.62, 0.70, 0.95
                lift = pack_lift(t) / T_CHAR
                crouch = 3.0 * smooth(t / 0.15) * (1 - smooth((t - 0.15) / 0.1)) if t < 0.25 else 0.0
            for k in ("fistL", "fistR"):
                rest, up, gr = A_FRONT[k][3], FIST_UP[k], FIST_GROUND[k]
                if t < t_up:
                    e = ease_out(t / t_up)
                    p = (lerp(rest[0], up[0], e), lerp(rest[1], up[1], e))
                elif t < t_hold:
                    p = up
                elif t < t_hit:
                    e = ease_in((t - t_hold) / (t_hit - t_hold))
                    p = (lerp(up[0], gr[0], e), lerp(up[1], gr[1], e))
                elif t < t_back0:
                    p = gr
                else:
                    e = smooth((t - t_back0) / (t_back1 - t_back0))
                    p = (lerp(gr[0], rest[0], e), lerp(gr[1], rest[1], e))
                pos[k] = list(p)
                if t_hit <= t < t_back0 + 0.05:
                    bob[k] = 0.0
            for k in ("head", "chestL", "chestR"):
                pos[k][1] += crouch
                if t >= t_hit:
                    pos[k][1] += 2.0 * (1 - smooth((t - t_hit) / 0.25))
            if t >= t_hit:
                flare_dt = t - t_hit
            fists_front = t_hold <= t < t_back0 + 0.1
            # yere inen yumruklar kaldirmadan etkilenmez (yere vururlar)
            if lift > 0:
                for k in pos:
                    if not (k.startswith("fist") and t >= t_hit):
                        pos[k][1] -= lift
        else:
            fists_front = False
        for k in pos:
            pos[k][1] += bob[k]
        order = ["head", "chestL", "chestR", "fistL", "fistR"]
        runes_on = True
        if d == "up" and state not in ("slam", "jump"):
            order = ["fistL", "fistR", "chestL", "chestR", "head"]
            runes_on = False
            for k in pos:
                pos[k][0] = -pos[k][0]
        elif d in ("left", "right") and state not in ("slam", "jump"):
            # yan gorunus (saga bakar; sol = ayna): uzak yumruk/gogus arkada, yakin one
            sw = math.sin(2 * math.pi * t / 0.6) if state == "walk" else 0.0
            side = {
                "fistL": (-5 - 4 * sw, -23), "chestL": (-6, -40), "head": (4, -62),
                "chestR": (4, -39), "fistR": (13 + 4 * sw, -21),
            }
            for k, v in side.items():
                pos[k] = [v[0], v[1] + bob[k]]
            order = ["fistL", "chestL", "head", "chestR", "fistR"]
        elif fists_front:
            order = ["head", "chestL", "chestR", "fistL", "fistR"]
        out = []
        for k in order:
            kind, row, mir, _ = A_FRONT[k]
            if not runes_on:
                row, mir = None, not mir
            if d in ("left", "right") and state not in ("slam", "jump") and k == "chestL":
                row = None
            out.append((k, kind, row, mir, pos[k][0], pos[k][1]))
        return out, lift, flare_dt

    def frame(self, state, d, t):
        parts, lift, flare_dt = self.layout(state, d, t)
        img = Image.new("RGBA", (self.W, self.H))
        ax, ay = self.anchor
        shk = 1 - 0.38 * (lift * T_CHAR) / JUMP_PEAK
        player_shadow(img, ax, ay, GOLEM_SH[0] / T_CHAR * shk, GOLEM_SH[1] / T_CHAR * shk)
        fl = 0.0 if flare_dt is None else max(0.0, 1 - flare_dt / 0.35)
        br = 0.5 + 0.5 * math.sin(2.4 * t)
        halo = 0.6 + 0.25 * br + 0.4 * fl
        glow_body = (0.35 + 0.35 * br) * (0.5 if d == "up" and state not in ("slam", "jump") else 1.0) + 0.5 * fl
        for k, kind, row, mir, x, y in parts:
            g = glow_body if row is not None or d == "up" else 0.2 + 0.8 * fl
            pc = piece(kind, row, mir, halo, g)
            img.alpha_composite(pc, (round(ax + x - 18), round(ay + y - 18)))
        if d == "left" and state not in ("slam", "jump"):
            img = ImageOps.mirror(img)
        return img


# ---------------------------------------------------------------------------------------------------------------
# sahne
SHAMAN_IDLE = load("assets", "characters", "shaman", "sheets", "idle.png")


def shaman_frame(t):
    f = int(t * 5) % (SHAMAN_IDLE.width // 48)
    img = Image.new("RGBA", (48, 48))
    player_shadow(img, 24, 40, HUMAN_SH[0] / T_CHAR, HUMAN_SH[1] / T_CHAR)
    img.alpha_composite(SHAMAN_IDLE.crop((f * 48, 0, f * 48 + 48, 48)))
    return img


GRASS = load("harita", "orman tileset", "PNG", "Ground_grass.png")


def _tile(gid):
    i = gid - 1
    return GRASS.crop(((i % 19) * 16, (i // 19) * 16, (i % 19) * 16 + 16, (i // 19) * 16 + 16))


def make_bg(w, h):
    t = _tile(78).copy()
    t.alpha_composite(_tile(135))
    bg = Image.new("RGBA", (w + 32, h + 32))
    for y in range(0, h + 32, 16):
        for x in range(0, w + 32, 16):
            bg.paste(t, (x, y))
    bg = bg.crop((5, 9, 5 + w, 9 + h))
    return bg.resize((round(w * ZOOM), round(h * ZOOM)), Image.NEAREST)


def blit(canvas, img, anchor, texel, sx, sy):
    s = ZOOM * texel
    w, h = img.size
    im = img.resize((max(1, round(w * s)), max(1, round(h * s))), Image.NEAREST)
    lay = Image.new("RGBA", canvas.size)
    lay.paste(im, (round(sx - anchor[0] * s), round(sy - anchor[1] * s)))
    canvas.alpha_composite(lay)


FONT = ImageFont.truetype(P("assets", "fonts", "m5x7.ttf"), 32)


def text(canvas, xy, s, fill=(255, 246, 214, 255)):
    d = ImageDraw.Draw(canvas)
    d.fontmode = "1"
    x, y = xy
    for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1), (1, 1)):
        d.text((x + ox, y + oy), s, font=FONT, fill=(26, 19, 16, 255))
    d.text((x, y), s, font=FONT, fill=fill)


# sekans: (durum, yon, sure, hareket (dx, dy) dunya)
SEQ = [
    ("idle", "down", 1.0, (0, 0), "bekleme"),
    ("walk", "right", 0.8, (40, 0), "yürüme"),
    ("walk", "down", 0.5, (0, 20), "yürüme"),
    ("walk", "left", 0.8, (-40, 0), "yürüme"),
    ("walk", "up", 0.5, (0, -20), "yürüme"),
    ("idle", "down", 0.3, (0, 0), "bekleme"),
    ("slam", "down", 0.65, (0, 0), "otomatik darbe / Q"),
    ("slam", "down", 0.65, (0, 0), "otomatik darbe / Q"),
    ("jump", "down", 0.95, (0, 0), "E: sıçrayış"),
    ("idle", "down", 0.5, (0, 0), "bekleme"),
]
VIEW = (-100, -100, 90, 34)  # dunya: x0, y0, x1, y1 (golem baslangic ayagi = 0, 0)
SHAMAN_AT = (-76, 2)


def state_at(t):
    acc, x, y = 0.0, 0.0, 0.0
    for st, d, dur, mv, lab in SEQ:
        if t < acc + dur:
            k = (t - acc) / dur
            return st, d, t - acc, x + mv[0] * k, y + mv[1] * k, lab
        acc += dur
        x += mv[0]
        y += mv[1]
    return "idle", "down", 0.0, x, y, "bekleme"


TOTAL = sum(s[2] for s in SEQ)


def render_panel(golem, t):
    w, h = VIEW[2] - VIEW[0], VIEW[3] - VIEW[1]
    can = make_bg(w, h)

    def scr(wx, wy):
        return (wx - VIEW[0]) * ZOOM, (wy - VIEW[1]) * ZOOM

    st, d, lt, gx, gy, lab = state_at(t)
    sx, sy = scr(*SHAMAN_AT)
    gsx, gsy = scr(gx, gy)
    items = [(SHAMAN_AT[1], shaman_frame(t), (24, 40), T_CHAR, sx, sy),
             (gy, golem.frame(st, d, lt), golem.anchor, golem.texel, gsx, gsy)]
    for _, im, anc, tex, x, y in sorted(items, key=lambda i: i[0]):
        blit(can, im, anc, tex, x, y)
    text(can, (8, -4), golem.name)
    text(can, (8, can.height - 30), lab, (214, 230, 255, 255))
    return can


def save_gif(frames, path):
    h = frames[0].height
    picks = frames[:: max(1, len(frames) // 10)][:10]
    sample = Image.new("RGB", (frames[0].width, h * len(picks)))
    for i, f in enumerate(picks):
        sample.paste(f.convert("RGB"), (0, i * h))
    pal = sample.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q = [f.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    q[0].save(path, save_all=True, append_images=q[1:], duration=int(1000 / FPS), loop=0, optimize=False)


def build_golems():
    cur = CurrentGolem()
    a = RuneGolem()
    b = PackGolem(1, "B - Yosun Golemi", (120, 124, 60))
    c = PackGolem(2, "C - Kehribar Kristal", (255, 190, 70), (175, 225))
    dd = PackGolem(3, "D - Boynuzlu Muhafız", (100, 130, 60), (120, 185))
    return [cur, a, b, c, dd]


TONE_ALTS = {
    "B": [((96, 128, 62), None, "yosun"), ((150, 110, 70), None, "kil (orijinal)")],
    "C": [((110, 200, 90), (175, 225), "yeşim"), ((255, 130, 40), (175, 225), "kor turuncu")],
    "D": [((140, 100, 60), (120, 185), "boynuz kahve"), ((80, 150, 150), (120, 185), "camgöbeği")],
}


def render_summary(golems):
    cw, ch = 84, 132  # hucre (dunya)
    cols = ["aşağı", "sol", "sağ", "yukarı", "darbe anı", "sıçrayış tepe", "ton 2", "ton 3"]
    lab_w = 220
    sh_w = 40
    W = lab_w + round(sh_w * ZOOM) + round(cw * ZOOM) * len(cols)
    H = 34 + round(ch * ZOOM) * len(golems)
    can = Image.new("RGBA", (W, H), (34, 30, 26, 255))
    for i, c in enumerate(cols):
        text(can, (lab_w + round(sh_w * ZOOM) + i * round(cw * ZOOM) + 8, -4), c)
    for r, g in enumerate(golems):
        y0 = 34 + r * round(ch * ZOOM)
        bg = make_bg(sh_w + cw * len(cols), ch)
        can.alpha_composite(bg, (lab_w, y0))
        foot = y0 + (ch - 14) * ZOOM
        blit(can, shaman_frame(0.0), (24, 40), T_CHAR, lab_w + sh_w * ZOOM / 2, foot)
        cells = [("idle", "down", 0.0), ("idle", "left", 0.0), ("idle", "right", 0.0), ("idle", "up", 0.0),
                 ("slam", "down", g.impact_t["slam"]), ("jump", "down", g.impact_t["jump"])]
        for i, (st, d, t) in enumerate(cells):
            x = lab_w + sh_w * ZOOM + (i + 0.5) * cw * ZOOM
            blit(can, g.frame(st, d, t), g.anchor, g.texel, x, foot)
        key = g.name.split(" ")[0]
        for j, (tgt, band, nm) in enumerate(TONE_ALTS.get(key, [])):
            x = lab_w + sh_w * ZOOM + (6 + j + 0.5) * cw * ZOOM
            alt = g.tinted(tgt, band) if nm != "kil (orijinal)" else PackGolem(1, "")
            blit(can, alt.frame("idle", "down", 0.0), alt.anchor, alt.texel, x, foot)
            text(can, (round(x - cw * ZOOM / 2) + 6, y0 - 2), nm, (214, 230, 255, 255))
        for li, line in enumerate(g.name.split(" - ")):
            text(can, (8, y0 + 4 + li * 24), line)
    return can


def main():
    os.makedirs(OUT, exist_ok=True)
    golems = build_golems()
    n = int(round(TOTAL * FPS))
    files = ["suan", "A", "B", "C", "D"]
    panels = {f: [] for f in files}
    for i in range(n):
        t = i / FPS
        for f, g in zip(files, golems):
            panels[f].append(render_panel(g, t))
    for f in files:
        save_gif(panels[f], os.path.join(OUT, f + ".gif"))
    pw, ph = panels["A"][0].size
    gap = 4
    comp = []
    for i in range(n):
        c = Image.new("RGBA", (pw * 3 + gap * 2, ph * 2 + gap), (34, 30, 26, 255))
        for j, f in enumerate(files):
            c.alpha_composite(panels[f][i], ((j % 3) * (pw + gap), (j // 3) * (ph + gap)))
        comp.append(c)
    # 6. hucre: aciklama
    for c in comp:
        x0, y0 = 2 * (pw + gap) + 10, ph + gap + 6
        for li, line in enumerate([
            "Sol: Shaman (ölçek için).",
            "Mekanik / sayılar / darbe",
            "efektleri DEĞİŞMEZ;",
            "yalnız golemin gövdesi.",
            "",
            "A: Shaman'ın kendi rün taşları",
            "B-D: oyundaki golem paketleri,",
            "yalnız ton değişti.",
        ]):
            text(c, (x0, y0 + li * 24), line)
    save_gif(comp, os.path.join(OUT, "karsilastirma.gif"))
    render_summary(golems).save(os.path.join(OUT, "ozet.png"))
    print("ok", n, "kare ->", OUT)


if __name__ == "__main__":
    main()
