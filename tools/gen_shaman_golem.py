#!/usr/bin/env python3
"""Shaman R - Elemental Golem formu: pixel-art golem sprite sayfasi + shaman_frames.tres klipleri + 3 yetenek ikonu.

Kullanici istegi (2026-09-30): "20 saniyeliğine dev bir elemental goleme dönüşür (bunun için pixel art bir golem
hazırlaman gerekiyor vuruş animasyonu atlama animasyonu idle ve 4 direction olmalı)".

Tasarim (Shaman'in kendi dilinden: geyik boynuzu, zeytin yesili pelerin, toprak tonlari; totemlerin ruh atesi):
  * sicak gri-kahve TAS govde (ust-sol isikli 6 ton, yerel koordinata bagli tas benekleri + catlaklar, 1 px koyu kontur),
  * omuzlarda / basin ustunde / sirtta YOSUN (zeytin yesilleri, Shaman'in pelerini ile ayni aile),
  * basindan cikan dallanmis AGAC BOYNUZLARI (Shaman'in boynuzlarinin golem hali),
  * gozlerde, gogus cekirdeginde ve catlaklarda parlayan RUH ATESI (amber - Saldiri Totemi'nin atesiyle ayni aile).
Olcu: karakterin 48x48 sanat yogunlugunda (1 sanat pikseli = karakterin 1 texel'i), golem ~58x64 px (Shaman ~24x37) -
"dev". Hucre 96x144: ayak satiri 88 = hucre merkezinin 16 px alti, Shaman'in 48x48 karelerindeki ayak satiri (40) ile
AYNI goreli konum -> AnimatedSprite2D'nin olcek/ofseti (characters.gd DEFS[12]) degismeden ayaklar ayni yere basar.
Ziplamanin yukselmesi karelerin ICINE pisirilir (uzak oyuncular sadece klip ADINI gorur, ayri ag verisi gerekmez).

Klipler (satir = klip * 4 + yon; yonler DIR_ROWS sirasinda: down, left, right(=left aynasi), up):
  golem_idle  4 kare dongu   - nefes (omuz/kafa 1 px), cekirdek parlamasi nabiz atar
  golem_walk  6 kare dongu   - agir adimlar, kollar ters sallanir
  golem_slam  6 kare tek     - iki yumrugu kaldirip yere indirir (otomatik darbe + Q); darbe ani = kare 3
  golem_jump  8 kare tek     - comelme, havalanma, tepe, dusus, yere yumrukla inis (E); inis ani = kare 6
  golem_slam2 = golem_slam'in AYNI kareleri (ayri ad): arka arkaya darbelerde yerel oyuncu adlari degistirir ki uzak
               istemci her darbede klibi bastan oynatsin (remote_player.gd sadece ad degisince play() cagirir).
Zamanlama sabitleri (darbe/inis ani) scripts/shaman_golem_math.gd ile AYNI olmali (SLAM_FPS/SLAM_IMPACT_FRAME,
JUMP_FRAME_DURATIONS/JUMP_LAND_FRAME).

Kullanim (repo kokunden):  python tools/gen_shaman_golem.py [--preview onizleme.png]
  -> assets/characters/shaman/golem_sheet.png, shaman_frames.tres'e golem_* klipleri (eski golem_* klipleri silinip
     yeniden yazilir; tools/import_character_sheets.py de Shaman'i yeniden uretirken add_golem_clips'i cagirir),
     assets/skills/shaman_{elemental_golem,sarsici_darbe,golem_sicrayisi}_icon.png
  Sonra Godot: --headless --import (ya da editoru ac).
"""
import math
import os
import re
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET_REL = "assets/characters/shaman/golem_sheet.png"
FRAMES_REL = "assets/characters/shaman_frames.tres"
CELL_W, CELL_H = 96, 144
FEET_Y = 88
CX = 48
DIRS = ["down", "left", "right", "up"]

# (klip, kare sayisi, dongu, fps, kare sureleri) - kare sureleri None = hepsi 1.0
SLAM_FPS = 14.0
JUMP_FPS = 20.0
JUMP_FRAME_DURATIONS = [1.4, 1.0, 1.6, 1.6, 1.6, 1.0, 1.6, 1.4]
CLIPS = [
    ("golem_idle", 4, True, 5.0, None),
    ("golem_walk", 6, True, 9.0, None),
    ("golem_slam", 6, False, SLAM_FPS, None),
    ("golem_jump", 8, False, JUMP_FPS, JUMP_FRAME_DURATIONS),
]
ALIASES = [("golem_slam2", "golem_slam")]


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


OUTLINE = hexc("#1a1310")
STONE = [hexc(c) for c in ("#2b2420", "#433932", "#5c5147", "#786c5f", "#978a78", "#b6a993")]
MOSS = [hexc(c) for c in ("#2c3616", "#43521e", "#5d7128", "#7c8f36", "#9db04a")]
WOOD = [hexc(c) for c in ("#35210f", "#56361d", "#7c5530", "#a57a47")]
GLOW = [hexc(c) for c in ("#7a2a10", "#b04a18", "#e07a26", "#ffb347", "#ffe08a", "#fff8e0")]


def h01(*v):
    """Deterministik 0..1 hash (yerel koordinatlara bagli doku kareden kareye kaymasin)."""
    n = 0
    for i, x in enumerate(v):
        n ^= (int(x) * (73856093, 19349663, 83492791, 2654435761)[i % 4]) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


# ------------------------------------------------------------------ sekil maskeleri
def blob(cx, cy, rx, ry, p=2.6):
    """Kosesi yuvarlatilmis kaya (super-elips)."""
    out = set()
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if abs(dx) ** p + abs(dy) ** p <= 1.0:
                out.add((x, y))
    return out


def capsule(a, b, r):
    (ax, ay), (bx, by) = a, b
    out = set()
    for y in range(int(min(ay, by) - r) - 1, int(max(ay, by) + r) + 2):
        for x in range(int(min(ax, bx) - r) - 1, int(max(ax, bx) + r) + 2):
            px, py = x + 0.5, y + 0.5
            vx, vy = bx - ax, by - ay
            L = vx * vx + vy * vy
            t = 0.0 if L == 0 else max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / L))
            if (px - ax - vx * t) ** 2 + (py - ay - vy * t) ** 2 <= r * r:
                out.add((x, y))
    return out


def line_px(a, b):
    (x0, y0), (x1, y1) = a, b
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    return [(int(round(x0 + (x1 - x0) * i / n)), int(round(y0 + (y1 - y0) * i / n))) for i in range(n + 1)]


class Part:
    """Tek bir govde parcasi: maske + malzeme rampasi + yerel koordinat kokeni (doku/catlak buna bagli)."""

    def __init__(self, mask, ramp, origin, size, bias=0.0, moss=0, cracks=(), seed=0, glow_cracks=(), rough=True):
        self.mask = mask
        self.ramp = ramp
        self.ox, self.oy = origin
        self.rx, self.ry = size
        self.bias = bias
        self.moss = moss  # ust kenardan en fazla bu kadar px yosun
        self.cracks = cracks  # yerel koordinatta koyu catlak cizgileri [(a, b), ...]
        self.glow_cracks = glow_cracks  # yerel koordinatta amber catlaklar
        self.seed = seed
        self.rough = rough


def render(parts, glows, img, x_off, y_off, glow_level=1):
    """parts: z-sirali (arkadan one). glows: [(x, y, seviye)] - en ustte, konturdan etkilenmez."""
    owner = {}
    for i, p in enumerate(parts):
        for q in p.mask:
            owner[q] = i
    color = {}
    for (x, y), i in owner.items():
        p = parts[i]
        m = p.mask
        nx = (x + 0.5 - p.ox) / max(p.rx, 1.0)
        ny = (y + 0.5 - p.oy) / max(p.ry, 1.0)
        lv = 2.55 - 1.25 * ny - 0.55 * nx + p.bias
        if (x - 1, y) not in m or (x, y - 1) not in m:
            lv += 0.9
        if (x + 1, y) not in m or (x, y + 1) not in m:
            lv -= 1.0
        lx, ly = x - int(round(p.ox)), y - int(round(p.oy))
        if p.rough:
            h = h01(lx, ly, p.seed)
            if h < 0.08:
                lv -= 0.9
            elif h > 0.94:
                lv += 0.8
        ramp = p.ramp
        # yosun: sutunun ust kenarindan p.moss px icinde (kenar dalgali)
        if p.moss:
            top = y
            while (x, top - 1) in m:
                top -= 1
            depth = 1 + int(h01(lx, p.seed, 7) * p.moss)
            if y - top < depth:
                ramp = MOSS
                lv = 2.3 - 1.0 * ny + (0.9 if (x, y - 1) not in m else 0.0) - (0.6 if y - top == depth - 1 else 0.0)
        idx = int(round(max(0.0, min(len(ramp) - 1, lv * (len(ramp) - 1) / 5.0))))
        color[(x, y)] = ramp[idx]
    # catlaklar (yerel koordinattan)
    for i, p in enumerate(parts):
        for a, b in p.cracks:
            for (lx, ly) in line_px(a, b):
                q = (lx + int(round(p.ox)), ly + int(round(p.oy)))
                if owner.get(q) == i:
                    color[q] = p.ramp[0]
    # ic kontur: on parca, arkasindaki parcaya degdigi kenarda koyulasir
    for (x, y), i in owner.items():
        for q in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            j = owner.get(q)
            if j is not None and j < i and parts[j] is not parts[i]:
                if parts[i].ramp is not MOSS:
                    color[(x, y)] = parts[i].ramp[max(0, 0)]
                break
    # dis kontur
    filled = set(color)
    for (x, y) in list(filled):
        for q in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if q not in filled and q not in color:
                color[q] = OUTLINE
    # amber catlaklar + parlamalar (en ustte)
    for i, p in enumerate(parts):
        for a, b in p.glow_cracks:
            pts = line_px(a, b)
            for k, (lx, ly) in enumerate(pts):
                q = (lx + int(round(p.ox)), ly + int(round(p.oy)))
                if owner.get(q) == i:
                    color[q] = GLOW[max(0, min(5, 2 + glow_level - (1 if k in (0, len(pts) - 1) else 0)))]
    for (x, y, lvl) in glows:
        if (x, y) in color or True:
            color[(x, y)] = GLOW[max(0, min(5, lvl + glow_level - 1))]
    for (x, y), c in color.items():
        X, Y = x + x_off, y + y_off
        if 0 <= X < img.width and 0 <= Y < img.height:
            img.putpixel((X, Y), c)


# ------------------------------------------------------------------ golem govdesi
def antler(side, hx, hy, parts_wood):
    """Basin ustunden cikan dallanmis agac boynuzu (side -1 sol, +1 sag). 2 px ana dal + 1 px catallar."""
    s = side
    base = (hx + s * 4, hy - 5)
    mid = (hx + s * 9, hy - 11)
    tip = (hx + s * 11, hy - 18)
    m = capsule(base, mid, 1.3) | capsule(mid, tip, 1.0)
    m |= capsule((hx + s * 7, hy - 9), (hx + s * 13, hy - 12), 0.8)   # dis catal
    m |= capsule((hx + s * 10, hy - 14), (hx + s * 6, hy - 19), 0.8)  # ic catal
    m |= capsule((hx + s * 12, hy - 12), (hx + s * 15, hy - 16), 0.7)
    parts_wood.append(Part(m, WOOD, (hx + s * 9, hy - 12), (6, 8), bias=0.3 if s < 0 else -0.2, rough=False))


def arm_parts(shoulder, fist, bias, seed, fist_r=(7.0, 6.0)):
    """Kol (kalin tas kapsul) + yumruk (kaya). Dirsek kaba bir kirilmayla disa bukulur."""
    sx, sy = shoulder
    fx, fy = fist
    ex = (sx + fx) / 2 + (-3 if fx < sx else 3 if fx > sx else 0)
    ey = (sy + fy) / 2
    upper = Part(capsule((sx, sy), (ex, ey), 4.4), STONE, ((sx + ex) / 2, (sy + ey) / 2), (5, 7), bias=bias - 0.2, seed=seed)
    fore = Part(capsule((ex, ey), (fx, fy), 4.0), STONE, ((ex + fx) / 2, (ey + fy) / 2), (5, 7), bias=bias - 0.1,
                seed=seed + 1, cracks=[((-1, -2), (1, 1))])
    fr = Part(blob(fx, fy, fist_r[0], fist_r[1], 2.3), STONE, (fx, fy), fist_r, bias=bias + 0.2, seed=seed + 2,
              cracks=[((-3, 0), (-1, 1)), ((1, -2), (2, 0))])
    return upper, fore, fr


def front_view(pose, back=False):
    """Onden (down) / arkadan (up) gorunus. pose: dy (comelme +), lift (zipla), breathe, fists [(x,y),(x,y)],
    feet [(dx, kalkma), ...], glow, fist_front (yumruklar govdenin onunde mi)."""
    dy = pose.get("dy", 0)
    lift = pose.get("lift", 0)
    br = pose.get("breathe", 0)
    feet_y = FEET_Y - lift
    top = dy - lift  # govde kaymasi
    parts, wood, glows = [], [], []
    # bacaklar (ayak yere basar, govde comelince bacak kisalir)
    legs = []
    for k, (side, (fdx, flift)) in enumerate(zip((-1, 1), pose.get("feet", [(0, 0), (0, 0)]))):
        fx = CX + side * 9 + fdx
        fy = feet_y - flift
        hip_y = 66 + top
        leg = Part(capsule((fx, hip_y), (fx, fy - 4), 5.2), STONE, (fx, (hip_y + fy) / 2), (6, 9), bias=-0.3, seed=11 + k,
                   cracks=[((-2, 1), (0, 3))])
        foot = Part(blob(fx + side * 0.5, fy - 2.5, 7.0, 3.6, 2.2), STONE, (fx, fy - 2.5), (7, 4), bias=-0.2, seed=13 + k)
        legs += [leg, foot]
    # kollar
    sh = [(CX - 19, 45 + top + br), (CX + 19, 45 + top + br)]
    fists = pose["fists"]
    arms = []
    for k in range(2):
        f = (fists[k][0], fists[k][1] - lift) if pose.get("fist_abs") else (fists[k][0], fists[k][1] + top)
        arms.append(arm_parts(sh[k], f, 0.15 if k == 0 else -0.25, 30 + k * 5))
    torso = Part(blob(CX, 53 + top + br * 0.5, 19, 15, 2.8), STONE, (CX, 53 + top), (19, 15), seed=3, moss=0 if back else 2,
                 cracks=[((-12, 4), (-8, 8)), ((10, -6), (13, -2)), ((6, 9), (9, 11))],
                 glow_cracks=([((0, -9), (0, 9)), ((0, -2), (-6, -6)), ((0, 3), (6, 7)), ((0, 7), (-5, 11))] if back
                              else [((-3, 0), (-8, -3)), ((3, 0), (8, 3)), ((2, 3), (4, 8))]))
    pelvis = Part(blob(CX, 66 + top, 13, 5, 2.4), STONE, (CX, 66 + top), (13, 5), bias=-0.6, seed=5)
    head_y = 36 + top + br
    head = Part(blob(CX, head_y, 9.5, 7.5, 2.6), STONE, (CX, head_y), (9.5, 7.5), bias=0.2, seed=7, moss=3,
                cracks=[] if back else [((-6, 4), (-2, 4)), ((2, 4), (5, 4))])
    shoulders = [Part(blob(sh[k][0], sh[k][1] - 1, 8.5, 7.5, 2.4), STONE, (sh[k][0], sh[k][1] - 1), (8.5, 7.5),
                      bias=0.2 if k == 0 else -0.1, seed=20 + k, moss=4) for k in range(2)]
    antler(-1, CX, head_y - 1, wood)
    antler(1, CX, head_y - 1, wood)

    arm_behind = pose.get("arms_behind", False)
    fist_front = pose.get("fist_front", False)
    if back:
        order = legs + [head] + wood + [pelvis, torso]
        if arm_behind:  # sirt gorunumunde yumruklar govdenin onunde (kameradan gizli) -> once ciz
            order = legs + [a for arm in arms for a in arm] + [head] + wood + [pelvis, torso] + shoulders
        else:
            order += [a for arm in arms for a in arm[:2]] + shoulders + [arm[2] for arm in arms]
    else:
        order = legs + [pelvis, torso, head] + wood
        if fist_front:
            order += shoulders + [a for arm in arms for a in arm]
        else:
            order += [a for arm in arms for a in arm[:2]] + shoulders + [arm[2] for arm in arms]
    parts = order
    g = pose.get("glow", 1)
    if not back:
        # gozler (2x1, parlak cekirdek) + gogus ruh atesi cekirdegi (elmas)
        for ex in (CX - 5, CX + 3):
            glows += [(ex, head_y, 3), (ex + 1, head_y, 4)]
        cy = 52 + top + int(br * 0.5)
        for (dx, dyy, l) in ((0, -2, 3), (-1, -1, 3), (0, -1, 4), (1, -1, 3), (-2, 0, 2), (-1, 0, 4), (0, 0, 5),
                             (1, 0, 4), (2, 0, 2), (-1, 1, 3), (0, 1, 4), (1, 1, 3), (0, 2, 3)):
            glows.append((CX + dx, cy + dyy, l))
    return parts, glows, g


def side_view(pose):
    """Sola bakan gorunus (right = aynasi): kambur sirt (sagda), one uzanan bas (solda), govdenin onunde sarkan yakin kol,
    arkada koyu uzak kol/bacak. pose: dy, lift, breathe, lean (one egilme), near_fist/far_fist, feet [(dx, kalkma) yakin,
    uzak], near_behind_head (kol basin arkasindan gecer - yukari kalkinca)."""
    dy = pose.get("dy", 0)
    lift = pose.get("lift", 0)
    br = pose.get("breathe", 0)
    lean = pose.get("lean", 0)
    top = dy - lift
    feet_y = FEET_Y - lift
    glows, wood = [], []
    feet = pose.get("feet", [(0, 0), (0, 0)])  # (yakin, uzak)
    legs = []
    for k, (base_x, (fdx, flift)) in enumerate(((CX + 1, feet[0]), (CX + 9, feet[1]))):
        fx = base_x + fdx
        fy = feet_y - flift
        hip = (base_x + 1 - lean // 2, 64 + top)
        bias = -0.2 if k == 0 else -1.2
        leg = Part(capsule(hip, (fx, fy - 4), 5.0), STONE, ((hip[0] + fx) / 2, (hip[1] + fy) / 2), (6, 9), bias=bias,
                   seed=41 + k, cracks=[((-1, 0), (1, 2))])
        foot = Part(blob(fx - 2, fy - 2.5, 7.0, 3.5, 2.2), STONE, (fx - 2, fy - 2.5), (7, 4), bias=bias, seed=43 + k)
        legs.append([leg, foot])
    torso_c = (CX + 4 - lean, 54 + top + br * 0.5 + lean * 0.3)
    torso = Part(blob(torso_c[0], torso_c[1], 15, 14, 2.6), STONE, torso_c, (15, 14), seed=51,
                 cracks=[((6, 5), (9, 9)), ((2, 8), (5, 11))],
                 glow_cracks=[((-9, -2), (-13, -5)), ((-9, -2), (-12, 3)), ((-9, -2), (-6, 1))])
    hump = Part(blob(torso_c[0] + 6, torso_c[1] - 11, 10, 8, 2.4), STONE, (torso_c[0] + 6, torso_c[1] - 11), (10, 8),
                bias=0.1, seed=53, moss=4)
    pelvis = Part(blob(CX + 5 - lean // 2, 65 + top, 9, 5, 2.4), STONE, (CX + 5, 65 + top), (9, 5), bias=-0.8, seed=52)
    head_c = (CX - 10 - lean, 44 + top + br + lean * 0.7)
    head = Part(blob(head_c[0], head_c[1], 8.0, 6.5, 2.5), STONE, head_c, (8, 6.5), bias=0.3, seed=54, moss=3,
                cracks=[((-8, 3), (-4, 3))])
    jaw = Part(blob(head_c[0] - 1, head_c[1] + 5, 6.0, 3.0, 2.2), STONE, (head_c[0] - 1, head_c[1] + 5), (6, 3),
               bias=-0.5, seed=55)
    hx, hy = head_c
    for off, b in ((3, -0.9), (0, 0.25)):  # once uzak (koyu, biraz geride) boynuz, sonra yakin: geriye kivrilan ana dal
        ax, ay = hx + 1 + off, hy - 5 - (1 if off else 0)
        m = capsule((ax, ay), (ax + 4, ay - 6), 1.3) | capsule((ax + 4, ay - 6), (ax + 10, ay - 10), 1.0)
        m |= capsule((ax + 2, ay - 3), (ax - 1, ay - 10), 0.8)   # on catal (yukari-one)
        m |= capsule((ax + 6, ay - 7), (ax + 6, ay - 14), 0.8)   # orta catal (yukari)
        m |= capsule((ax + 9, ay - 9), (ax + 12, ay - 14), 0.7)  # uc catal
        wood.append(Part(m, WOOD, (ax + 5, ay - 7), (5, 6), bias=b, rough=False))
    near_sh = (torso_c[0] - 1, 47 + top + br)
    far_sh = (torso_c[0] + 8, 45 + top + br)
    nf, ff = pose["near_fist"], pose["far_fist"]
    abs_f = pose.get("fist_abs", False)
    near = arm_parts(near_sh, (nf[0], nf[1] - lift) if abs_f else (nf[0], nf[1] + top), 0.3, 61)
    far = arm_parts(far_sh, (ff[0], ff[1] - lift) if abs_f else (ff[0], ff[1] + top), -1.2, 66)
    near_shoulder = Part(blob(near_sh[0], near_sh[1] - 1, 7.5, 7.0, 2.4), STONE, (near_sh[0], near_sh[1] - 1), (7.5, 7),
                         bias=0.25, seed=70, moss=4)
    body = list(far) + legs[1] + [pelvis] + legs[0] + [torso, hump]
    head_group = [wood[0], jaw, head, wood[1]]
    if pose.get("near_behind_head"):
        order = body + list(near[:2]) + [near_shoulder, near[2]] + head_group
    else:
        order = body + head_group + list(near[:2]) + [near_shoulder, near[2]]
    glows += [(int(hx - 5), int(hy), 3), (int(hx - 6), int(hy), 4)]
    return order, glows, pose.get("glow", 1)


# ------------------------------------------------------------------ pozlar
def front_poses(clip):
    L, R = CX - 23, CX + 23
    rest = [(L, 70), (R, 70)]
    if clip == "golem_idle":
        return [dict(fists=rest, breathe=b, glow=g) for b, g in ((0, 1), (1, 2), (1, 2), (0, 1))]
    if clip == "golem_walk":
        out = []
        for i in range(6):
            s = math.sin(i / 6 * 2 * math.pi)
            lf, rf = max(0, s) * 4, max(0, -s) * 4
            bob = 1 if abs(s) < 0.5 else 0
            out.append(dict(dy=bob, feet=[(0, round(lf)), (0, round(rf))],
                            fists=[(L - round(s), 70 + round(s * 3)), (R - round(s), 70 - round(s * 3))], glow=1))
        return out
    if clip == "golem_slam":
        return [
            dict(dy=2, fists=[(L - 2, 70), (R + 2, 70)], glow=1),
            dict(dy=0, fists=[(CX - 17, 40), (CX + 17, 40)], fist_front=True, glow=1),
            dict(dy=-2, fists=[(CX - 6, 14), (CX + 6, 14)], fist_front=True, glow=2),
            dict(dy=5, fists=[(CX - 7, FEET_Y - 4), (CX + 7, FEET_Y - 4)], fist_front=True, fist_abs=True, glow=3),
            dict(dy=6, fists=[(CX - 7, FEET_Y - 4), (CX + 7, FEET_Y - 4)], fist_front=True, fist_abs=True, glow=2),
            dict(dy=2, fists=[(CX - 18, 74), (CX + 18, 74)], glow=1),
        ]
    if clip == "golem_jump":
        return [
            dict(dy=5, fists=[(L - 2, 74), (R + 2, 74)], glow=1),
            dict(lift=6, dy=-2, fists=[(L - 3, 38), (R + 3, 38)], feet=[(0, 1), (0, 1)], glow=1),
            dict(lift=12, fists=[(L, 30), (R, 30)], feet=[(1, 4), (-1, 4)], glow=2),
            dict(lift=14, fists=[(CX - 12, 26), (CX + 12, 26)], fist_front=True, feet=[(1, 5), (-1, 5)], glow=2),
            dict(lift=12, fists=[(CX - 6, 22), (CX + 6, 22)], fist_front=True, feet=[(1, 4), (-1, 4)], glow=2),
            dict(lift=5, fists=[(CX - 9, 52), (CX + 9, 52)], fist_front=True, feet=[(0, 2), (0, 2)], glow=2),
            dict(dy=6, fists=[(CX - 8, FEET_Y - 4), (CX + 8, FEET_Y - 4)], fist_front=True, fist_abs=True, glow=3),
            dict(dy=2, fists=[(CX - 18, 74), (CX + 18, 74)], glow=1),
        ]
    raise KeyError(clip)


def back_poses(clip):
    poses = front_poses(clip)
    out = []
    for p in poses:
        q = dict(p)
        # sirt gorunumu: one indirilen yumruklar govdenin arkasinda (kameradan uzakta) kalir
        if p.get("fist_abs"):
            q["fists"] = [(CX - 9, 62), (CX + 9, 62)]
            q["fist_abs"] = False
            q["arms_behind"] = True
        q["fist_front"] = False
        out.append(q)
    return out


def side_poses(clip):
    rest_n, rest_f = (CX - 6, 71), (CX + 15, 68)
    if clip == "golem_idle":
        return [dict(near_fist=rest_n, far_fist=rest_f, breathe=b, glow=g) for b, g in ((0, 1), (1, 2), (1, 2), (0, 1))]
    if clip == "golem_walk":
        out = []
        for i in range(6):
            s = math.sin(i / 6 * 2 * math.pi)
            c = math.cos(i / 6 * 2 * math.pi)
            near_dx, far_dx = round(-6 * s), round(6 * s)
            near_l, far_l = (round(max(0, c) * 3), round(max(0, -c) * 3))
            out.append(dict(dy=1 if abs(s) > 0.8 else 0, feet=[(near_dx, near_l), (far_dx, far_l)],
                            near_fist=(rest_n[0] + round(5 * s), rest_n[1] - round(abs(s))),
                            far_fist=(rest_f[0] - round(4 * s), rest_f[1]), glow=1))
        return out
    if clip == "golem_slam":
        g = FEET_Y - 4
        return [
            dict(dy=2, near_fist=(CX + 2, 72), far_fist=(CX + 16, 68), glow=1),
            dict(dy=0, near_fist=(CX - 2, 34), far_fist=(CX + 8, 32), near_behind_head=False, glow=1),
            dict(dy=-2, near_fist=(CX + 6, 16), far_fist=(CX + 12, 16), near_behind_head=True, glow=2),
            dict(dy=4, lean=4, near_fist=(CX - 25, g), far_fist=(CX - 17, g - 1), fist_abs=True, glow=3),
            dict(dy=5, lean=4, near_fist=(CX - 25, g), far_fist=(CX - 17, g - 1), fist_abs=True, glow=2),
            dict(dy=2, lean=1, near_fist=(CX - 14, 76), far_fist=(CX, 72), glow=1),
        ]
    if clip == "golem_jump":
        g = FEET_Y - 4
        return [
            dict(dy=5, lean=2, near_fist=(CX + 4, 74), far_fist=(CX + 16, 72), glow=1),
            dict(lift=6, dy=-2, lean=-1, near_fist=(CX + 8, 42), far_fist=(CX + 16, 40), feet=[(3, 2), (-2, 1)], glow=1),
            dict(lift=12, near_fist=(CX - 4, 30), far_fist=(CX + 6, 28), feet=[(2, 5), (-3, 4)], glow=2),
            dict(lift=14, near_fist=(CX + 2, 26), far_fist=(CX + 10, 25), near_behind_head=True, feet=[(1, 6), (-3, 5)],
                 glow=2),
            dict(lift=12, lean=2, near_fist=(CX - 10, 28), far_fist=(CX - 2, 27), feet=[(0, 4), (-2, 4)], glow=2),
            dict(lift=5, lean=3, near_fist=(CX - 20, 58), far_fist=(CX - 12, 56), feet=[(-1, 2), (-1, 2)], glow=2),
            dict(dy=6, lean=4, near_fist=(CX - 25, g), far_fist=(CX - 17, g - 1), fist_abs=True, glow=3),
            dict(dy=2, lean=1, near_fist=(CX - 14, 76), far_fist=(CX, 72), glow=1),
        ]
    raise KeyError(clip)


def draw_frame(dir_name, clip, i):
    img = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    if dir_name in ("down", "up"):
        pose = (front_poses if dir_name == "down" else back_poses)(clip)[i]
        parts, glows, g = front_view(pose, back=(dir_name == "up"))
    else:
        pose = side_poses(clip)[i]
        parts, glows, g = side_view(pose)
    render(parts, glows, img, 0, 0, glow_level=g)
    if dir_name == "right":
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return img


def build_sheet():
    cols = max(c[1] for c in CLIPS)
    sheet = Image.new("RGBA", (cols * CELL_W, len(CLIPS) * 4 * CELL_H), (0, 0, 0, 0))
    for ci, (clip, count, _loop, _fps, _dur) in enumerate(CLIPS):
        for di, d in enumerate(DIRS):
            for i in range(count):
                sheet.paste(draw_frame(d, clip, i), (i * CELL_W, (ci * 4 + di) * CELL_H))
    return sheet


# ------------------------------------------------------------------ SpriteFrames (shaman_frames.tres)
def golem_clip_entries(ext_id, first_sub_index):
    """(sub_resource metinleri, animasyon sozlukleri) - import_character_sheets.py de kullanir."""
    subs, anims, ids_by_clip = [], [], {}
    idx = first_sub_index
    for ci, (clip, count, loop, fps, durs) in enumerate(CLIPS):
        for di, d in enumerate(DIRS):
            refs = []
            for i in range(count):
                sid = f"AtlasTexture_golem_{idx}"
                subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{ext_id}")\n'
                            f"region = Rect2({i * CELL_W}, {(ci * 4 + di) * CELL_H}, {CELL_W}, {CELL_H})\n")
                refs.append((sid, 1.0 if durs is None else durs[i]))
                idx += 1
            ids_by_clip[f"{clip}_{d}"] = (refs, loop, fps)
    for name, (refs, loop, fps) in ids_by_clip.items():
        anims.append(_anim_text(name, refs, loop, fps))
    for alias, src in ALIASES:
        for d in DIRS:
            refs, loop, fps = ids_by_clip[f"{src}_{d}"]
            anims.append(_anim_text(f"{alias}_{d}", refs, loop, fps))
    return subs, anims


def _anim_text(name, refs, loop, fps):
    frames = ", ".join('{"duration": %s,"texture": SubResource("%s")}' % (dur, sid) for sid, dur in refs)
    return '{"frames": [%s],"loop": %s,"name": &"%s","speed": %s}' % (frames, "true" if loop else "false", name, fps)


def add_golem_clips(frames_path):
    """shaman_frames.tres'e golem_* kliplerini ekler (varsa eskilerini once siler) - idempotent."""
    with open(frames_path, encoding="utf-8") as f:
        text = f.read()
    sheet_res = "res://" + SHEET_REL
    # eski golem kayitlari: ext_resource satiri, AtlasTexture_golem_* bloklari, golem_* animasyonlari
    text = re.sub(r'\[ext_resource type="Texture2D" path="%s" id="[^"]+"\]\n' % re.escape(sheet_res), "", text)
    text = re.sub(r'\[sub_resource type="AtlasTexture" id="AtlasTexture_golem_\d+"\]\natlas = [^\n]+\nregion = [^\n]+\n\n?',
                  "", text)
    head, anim_line = text.split("\nanimations = [", 1)
    anim_body = anim_line.rsplit("]", 1)[0]
    entries = _split_top_level(anim_body)
    entries = [e for e in entries if '"name": &"golem_' not in e]
    ext_ids = [int(m) for m in re.findall(r'\[ext_resource [^\]]*id="(\d+)"\]', head)]
    ext_id = str(max(ext_ids) + 1 if ext_ids else 1)
    last_ext = list(re.finditer(r'\[ext_resource [^\]]*\]\n', head))[-1]
    head = head[:last_ext.end()] + f'[ext_resource type="Texture2D" path="{sheet_res}" id="{ext_id}"]\n' + head[last_ext.end():]
    subs, anims = golem_clip_entries(ext_id, 1)
    res_idx = head.index("[resource]")
    head = head[:res_idx] + "\n".join(subs) + "\n" + head[res_idx:]
    steps = len(re.findall(r'\[ext_resource ', head)) + len(re.findall(r'\[sub_resource ', head)) + 1
    head = re.sub(r"load_steps=\d+", f"load_steps={steps}", head, count=1)
    out = head + "\nanimations = [" + ", ".join(entries + anims) + "]\n"
    with open(frames_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(out)
    print(f"  {os.path.relpath(frames_path, ROOT)}: +{len(anims)} golem klibi")


def _split_top_level(body):
    """animations = [ {...}, {...} ] icini ust seviye {} bloklarina ayirir."""
    out, depth, start = [], 0, None
    for i, ch in enumerate(body):
        if ch == "{":
            if depth == 0:
                start = i
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                out.append(body[start:i + 1])
    return out


# ------------------------------------------------------------------ ikonlar (48x48 kare karo, 3x)
def make_icons():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import gen_elara_korsan_icons as ek  # noqa: E402

    def emblem_from_parts(parts, glows, g=1):
        e = ek.canvas()
        tmp = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        render(parts, glows, tmp, 0, 0, glow_level=g)
        # render dis konturu zaten cizdi; finish'in konturu tekrar ekler (zararsiz, 1 px)
        e.alpha_composite(tmp)
        return e

    amber = dict(top=ek.C("#6b3a14"), bottom=ek.C("#1b0f07"), glow=ek.C("#b8622a"), rim_hi=ek.C("#e8a45c"),
                 rim_lo=ek.C("#140a04"))

    # R - Elemental Golem: golem bustu (omuzlar, yosunlu bas, boynuzlar, parlayan gozler + gogus ateşi)
    base = ek.tile(amber["top"], amber["bottom"], amber["glow"], amber["rim_hi"], amber["rim_lo"], glow_center=(24, 26))
    parts, wood = [], []
    hx, hy = 24, 25
    torso = Part(blob(24, 43, 17, 10, 2.6), STONE, (24, 43), (17, 10), seed=3, moss=2,
                 glow_cracks=[((-3, -1), (-8, -4)), ((3, -1), (8, 2))])
    sh = [Part(blob(24 + s * 15, 36, 7, 6.5, 2.4), STONE, (24 + s * 15, 36), (7, 6.5), bias=0.2 * -s, seed=20 + s,
               moss=4) for s in (-1, 1)]
    head = Part(blob(hx, hy, 9, 7.5, 2.6), STONE, (hx, hy), (9, 7.5), bias=0.25, seed=7, moss=3,
                cracks=[((-6, 4), (-2, 4)), ((2, 4), (5, 4))])
    antler(-1, hx, hy - 1, wood)
    antler(1, hx, hy - 1, wood)
    parts = [torso, head] + wood + sh
    glows = [(hx - 5, hy, 3), (hx - 4, hy, 4), (hx + 3, hy, 3), (hx + 4, hy, 4),
             (24, 42, 4), (23, 42, 3), (25, 42, 3), (24, 41, 3), (24, 43, 3)]
    e = emblem_from_parts(parts, glows, 2)
    fx = ek.canvas()
    ek.sparkle(fx, 40, 9, ek.C("#fff8e0"), ek.C("#ffb347"), 1)
    ek.sparkle(fx, 8, 13, ek.C("#fff8e0"), ek.C("#e07a26"), 1)
    ek.finish(base, e, fx, "shaman_elemental_golem_icon.png")

    # Q (golem) - Sarsici Darbe: tas yumruk yere iner, amber catlaklar + sok yaylari + sersemletme yildizlari
    base = ek.tile(ek.C("#5a3417"), ek.C("#160c06"), ek.C("#a4561f"), ek.C("#dc9a55"), ek.C("#120904"), glow_center=(24, 34))
    fist = Part(blob(24, 22, 10, 9, 2.3), STONE, (24, 22), (10, 9), bias=0.2, seed=2,
                cracks=[((-6, 0), (-3, 2)), ((2, -4), (4, -1)), ((-1, 4), (3, 5))])
    armp = Part(capsule((27, 2), (25, 14), 6.0), STONE, (26, 8), (6, 7), bias=-0.2, seed=4, moss=3)
    ground = Part(blob(24, 39, 21, 5.5, 2.0), STONE, (24, 39), (21, 5.5), bias=-0.5, seed=9,
                  glow_cracks=[((0, -2), (-9, -1)), ((-9, -1), (-16, 1)), ((0, -2), (8, 0)), ((8, 0), (15, -1)),
                               ((0, -2), (2, 3)), ((-5, -1), (-7, 3))])
    e = emblem_from_parts([ground, armp, fist], [(24, 31, 4), (23, 31, 3), (25, 31, 3)], 2)
    fx = ek.canvas()
    d = ImageDraw.Draw(fx)
    for r, col in ((15, ek.C("#ffb347")), (19, ek.C("#e07a26"))):
        d.arc((24 - r, 33 - r // 2, 24 + r, 33 + r // 2), 190, 350, fill=col)
    for (sx, sy) in ((9, 11), (38, 12), (41, 26)):
        ek.put(fx, [(sx, sy)], ek.C("#fff4b0"))
        ek.put(fx, [(sx - 1, sy), (sx + 1, sy), (sx, sy - 1), (sx, sy + 1)], ek.C("#ffd24a"))
    ek.finish(base, e, fx, "shaman_sarsici_darbe_icon.png")

    # E (golem) - Golem Sicrayisi: havadaki kucuk golem silueti + noktali yay + inis halkasi ve ice cekilen oklar
    base = ek.tile(ek.C("#4b3a1c"), ek.C("#120d06"), ek.C("#8e6a2c"), ek.C("#d0a860"), ek.C("#0e0904"), glow_center=(26, 36))
    body = Part(blob(17, 17, 7, 6, 2.5), STONE, (17, 17), (7, 6), seed=3, moss=2)
    hd = Part(blob(17, 9, 4.5, 3.8, 2.5), STONE, (17, 9), (4.5, 3.8), bias=0.3, seed=5, moss=2)
    arms = [Part(capsule((17 + s * 6, 14), (17 + s * 9, 6), 2.4), STONE, (17 + s * 8, 10), (3, 4), bias=0.1 * -s,
                 seed=8 + s) for s in (-1, 1)]
    fists = [Part(blob(17 + s * 9, 5, 3.2, 2.8, 2.2), STONE, (17 + s * 9, 5), (3.2, 2.8), bias=0.2, seed=12 + s)
             for s in (-1, 1)]
    legs = [Part(capsule((17 + s * 3, 21), (17 + s * 4, 25), 2.3), STONE, (17 + s * 3, 23), (3, 3), bias=-0.4, seed=15 + s)
            for s in (-1, 1)]
    e = emblem_from_parts(legs + [body] + arms + fists + [hd], [(15, 9, 4), (19, 9, 4), (17, 17, 4)], 2)
    fx = ek.canvas()
    d = ImageDraw.Draw(fx)
    for k in range(7):  # noktali ucus yayi
        t = k / 6
        x = 22 + t * 12
        y = 20 - math.sin(t * math.pi * 0.9) * 6 + t * 16
        ek.put(fx, [(int(x), int(y))], ek.C("#ffe08a") if k % 2 == 0 else ek.C("#e07a26"))
    d.ellipse((24, 36, 44, 44), outline=ek.C("#ffb347"))
    d.ellipse((28, 38, 40, 42), outline=ek.C("#e07a26"))
    for (ax, ay, dx) in ((21, 40, 1), (47, 40, -1)):  # ice cekilen oklar
        ek.put(fx, [(ax, ay), (ax + dx, ay), (ax + 2 * dx, ay), (ax + dx, ay - 1), (ax + dx, ay + 1)], ek.C("#fff4c0"))
    ek.finish(base, e, fx, "shaman_golem_sicrayisi_icon.png")


def main():
    sheet = build_sheet()
    out = os.path.join(ROOT, SHEET_REL)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    print(f"  {SHEET_REL} {sheet.size}")
    add_golem_clips(os.path.join(ROOT, FRAMES_REL))
    make_icons()
    if "--preview" in sys.argv:
        p = sys.argv[sys.argv.index("--preview") + 1]
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(p)
        print("  onizleme:", p)


if __name__ == "__main__":
    main()
