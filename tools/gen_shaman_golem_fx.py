#!/usr/bin/env python3
"""Shaman R - Elemental Golem efektleri (pixel-art sprite sayfalari + SpriteFrames .tres).

Kullanici istegi (2026-09-30): golem formu + formdayken degisen Q/E. Butun efektler onceden pisirilmis sayfa (performans,
bkz. hafiza "Heavy FX sprite bake") ve DUNYA konumunda oynayan tek seferlik sahneler (scenes/fx_shaman_golem_*.tscn,
scripts/fx_oneshot_sprite.gd) - diger oyunculara sahne yoluyla "hitscan_impact" yayiniyla gider.
Olcek: 1 sanat pikseli = PixelDraw.TEXEL (1.212) dunya birimi -> karakterin pikseliyle ayni irilik. Yaricaplar
scripts/shaman_golem_math.gd'deki oyun yaricaplariyla ayni (dunya birimi / 1.212):
  slam      (otomatik darbe, AUTO_RADIUS 90)  -> 160x88,  8 kare, 18 fps : cati flasi + yer catlagi + genisleyen toz halkasi + tas kiriklari
  quake     (Q Sarsici Darbe, Q_RADIUS 140)   -> 256x144, 10 kare, 16 fps: amber (ruh atesi) yarilan zemin + cift sok halkasi + firlayan kayalar
  land      (E Golem Sicrayisi, E_RADIUS 150)  -> 272x152, 10 kare, 18 fps: ICE akan toz cizgileri (cekme) + inis krateri + toz halkasi
  transform (R donusum / formdan cikis)        -> 128x160, 11 kare, 18 fps: ayak altinda rün halkasi, yukari toplanan taslar, amber parlama, toz
Kullanim: python tools/gen_shaman_golem_fx.py   (sonra Godot: --headless --import)
"""
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "shaman_golem")
RES = "res://assets/fx/shaman_golem/"
TEXEL = 1.212
SQUASH = 0.5  # yer duzlemi (ust-asagi bakis) elips orani


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


DUST = [hexc("#8a7a5e"), hexc("#b9a682"), hexc("#e3d4b3")]
STONE = [hexc("#2b2420"), hexc("#433932"), hexc("#5c5147"), hexc("#786c5f"), hexc("#978a78")]
GLOW = [hexc("#7a2a10"), hexc("#b04a18"), hexc("#e07a26"), hexc("#ffb347"), hexc("#ffe08a"), hexc("#fff8e0")]
CRACK = hexc("#1f1814")
DUST_EDGE = hexc("#6e604a")
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


class Frame:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = {}

    def put(self, x, y, c, alpha=1.0):
        """alpha < 1: Bayer dither ile seyreltilir (yari saydam pixel yok - pixel dili)."""
        x, y = int(round(x)), int(round(y))
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        if alpha < 1.0 and alpha * 16 <= BAYER[y & 3][x & 3]:
            return
        self.px[(x, y)] = c

    def image(self):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def ring(f, cx, cy, r, c, alpha=1.0, thick=1, squash=SQUASH, gap=0.0, seed=0):
    if r <= 0:
        return
    n = max(24, int(2 * math.pi * r * 1.3))
    rnd = random.Random(seed)
    for i in range(n):
        a = 2 * math.pi * i / n
        if gap > 0 and rnd.random() < gap:
            continue
        for t in range(thick):
            rr = r - t
            f.put(cx + math.cos(a) * rr, cy + math.sin(a) * rr * squash, c, alpha)


def jagged(rnd, cx, cy, ang, length, step=3.0, wobble=0.45, squash=SQUASH):
    """Yerde merkezden disa uzanan zikzak catlak - nokta listesi (yer duzleminde)."""
    pts = [(cx, cy)]
    x, y, a = cx, cy, ang
    d = 0.0
    while d < length:
        a += rnd.uniform(-wobble, wobble)
        x += math.cos(a) * step
        y += math.sin(a) * step * squash
        d += step
        pts.append((x, y))
    return pts


def draw_poly(f, pts, c, alpha=1.0, upto=1.0):
    n = max(1, int((len(pts) - 1) * upto))
    for i in range(n):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        m = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for k in range(m + 1):
            t = k / m
            f.put(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c, alpha)


def crack(f, pts, alpha=1.0, upto=1.0, glow=None, glow_upto=0.7):
    """2 px koyu yarik (alt satir da), istenirse ic kisminda amber cekirdek."""
    draw_poly(f, [(x, y + 1) for (x, y) in pts], CRACK, alpha, upto)
    draw_poly(f, pts, CRACK, alpha, upto)
    if glow is not None:
        draw_poly(f, pts, glow, alpha, min(upto, glow_upto))


def rock(f, x, y, size, shade=2):
    """Kaya parcasi: s x s govde (ust-sol isik, alt koyu) + 1 px koyu kontur."""
    s = int(size)
    x, y = int(round(x)), int(round(y))
    for dy in range(-1, s + 1):
        for dx in range(-1, s + 1):
            if dx in (-1, s) or dy in (-1, s):
                if not ((dx in (-1, s)) and (dy in (-1, s))):
                    f.put(x + dx, y + dy, CRACK)
                continue
            lvl = shade + (1 if dy == 0 else 0) + (1 if dx == 0 and dy == 0 else 0) - (1 if dy == s - 1 and s > 1 else 0)
            f.put(x + dx, y + dy, STONE[max(0, min(4, lvl))])


def dust_puff(f, x, y, r, alpha, seed):
    """Dolu, golgeli toz bulutu: ust acik / orta / alt koyu ton + alt kenarda 1 px koyu hat; sonmede kenardan dither."""
    rnd = random.Random(seed)
    rx, ry = r, r * 0.72
    wob = [rnd.uniform(0.82, 1.08) for _ in range(8)]
    for yy in range(int(-ry) - 1, int(ry) + 2):
        for xx in range(int(-rx) - 1, int(rx) + 2):
            a = math.atan2(yy, xx)
            k = wob[int((a + math.pi) / (2 * math.pi) * 8) % 8]
            e = (xx / (rx * k)) ** 2 + (yy / (ry * k)) ** 2
            if e > 1.0:
                continue
            below = ((xx) / (rx * k)) ** 2 + ((yy + 1) / (ry * k)) ** 2 > 1.0
            tone = DUST_EDGE if below else DUST[2] if yy < -ry * 0.25 + xx * 0.15 else DUST[1] if yy < ry * 0.35 else DUST[0]
            edge_a = alpha if e < 0.55 else alpha * 0.8
            f.put(x + xx, y + yy, tone, edge_a)


def spark(f, x, y, lvl):
    f.put(x, y, GLOW[min(5, lvl + 1)])
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        f.put(x + dx, y + dy, GLOW[max(0, lvl - 1)])


# ------------------------------------------------------------------ otomatik darbe
def slam():
    W, H, cx, cy = 160, 88, 80, 50
    R = 90.0 / TEXEL
    n = 8
    rnd = random.Random(301)
    cracks = [jagged(rnd, cx, cy, i * 2 * math.pi / 5 + rnd.uniform(-0.3, 0.3), rnd.uniform(9, 15), 2.5, 0.35)
              for i in range(5)]
    chips = [(rnd.uniform(0, 2 * math.pi), rnd.uniform(14, 34), rnd.uniform(8, 16), rnd.choice((1, 2, 2, 3))) for _ in range(8)]
    puffs = [(k * 2 * math.pi / 9 + rnd.uniform(-0.2, 0.2), rnd.uniform(0.75, 0.95), rnd.uniform(3.0, 5.0)) for k in range(9)]
    frames = []
    for i in range(n):
        t = i / (n - 1)
        f = Frame(W, H)
        fade = 1.0 - max(0.0, (t - 0.5) / 0.5)
        for pts in cracks:
            crack(f, pts, fade, min(1.0, 0.5 + t * 2.5), GLOW[max(1, 4 - i)] if i <= 3 else None, 0.6)
        r = 12 + (R - 12) * (1 - (1 - t) ** 2.4)
        ring(f, cx, cy, r, DUST[2], 0.95 * fade, 1, gap=0.08, seed=i)
        ring(f, cx, cy + 1, r - 1, DUST_EDGE, 0.7 * fade, 1, gap=0.25, seed=i + 40)
        # toz bulutlari halkanin hemen icinde, yukselerek buyur
        for k, (ang, pr, sz) in enumerate(puffs):
            rr = r * pr
            dust_puff(f, cx + math.cos(ang) * rr, cy + math.sin(ang) * rr * SQUASH - t * 4, sz * (0.6 + t * 0.7),
                      fade, k * 13 + i)
        dust_puff(f, cx, cy - 2 - t * 5, 4 + t * 5, fade, 99 + i)
        if i == 0:
            for k in range(-4, 5):
                f.put(cx + k * 2, cy, GLOW[4])
            for k in range(-6, 2):
                f.put(cx, cy + k, GLOW[5] if abs(k) < 3 else GLOW[3])
        elif i == 1:
            spark(f, cx - 7, cy - 6, 3)
            spark(f, cx + 8, cy - 5, 3)
        for (ang, dist, hmax, sz) in chips:
            x = cx + math.cos(ang) * dist * t * 1.3
            y = cy + math.sin(ang) * dist * t * 1.3 * SQUASH - hmax * 4 * t * (1 - t)
            if t < 0.95:
                rock(f, x, y, sz)
        frames.append(f.image())
    save("slam", frames, 18.0)


# ------------------------------------------------------------------ Q: Sarsici Darbe
def quake():
    W, H, cx, cy = 256, 144, 128, 76
    R = 140.0 / TEXEL
    n = 10
    rnd = random.Random(902)
    fiss = [jagged(rnd, cx, cy, i * 2 * math.pi / 8 + rnd.uniform(-0.2, 0.2), rnd.uniform(R * 0.5, R * 0.8), 3.0, 0.28)
            for i in range(8)]
    branches = []
    for pts in fiss:
        k = len(pts) // 2
        bx, by = pts[k]
        ang = math.atan2((pts[k + 1][1] - by) / SQUASH, pts[k + 1][0] - bx) + rnd.choice((-0.7, 0.7))
        branches.append(jagged(rnd, bx, by, ang, rnd.uniform(8, 14), 2.5, 0.35))
    boulders = [(rnd.uniform(0, 2 * math.pi), rnd.uniform(10, R * 0.5), rnd.uniform(14, 28), rnd.choice((2, 3, 3, 4)))
                for _ in range(11)]
    puffs = [(k * 2 * math.pi / 13 + rnd.uniform(-0.15, 0.15), rnd.uniform(0.78, 0.95), rnd.uniform(4.5, 7.5)) for k in range(13)]
    frames = []
    for i in range(n):
        t = i / (n - 1)
        f = Frame(W, H)
        grow = min(1.0, 0.3 + t * 2.2)
        heat = max(0, 4 - int(max(0.0, t - 0.3) * 8))  # yarik ici: parlak -> sonuk
        fade = 1.0 - max(0.0, (t - 0.65) / 0.35)
        for pts in branches:
            crack(f, pts, fade, grow)
        for pts in fiss:
            crack(f, pts, fade, grow, GLOW[heat] if heat > 0 else None, 0.75)
        r = 16 + (R - 16) * (1 - (1 - t) ** 2.0)
        ring(f, cx, cy, r, DUST[2], (1.0 - t ** 1.6), 2, gap=0.06, seed=i * 3)
        ring(f, cx, cy + 1, r - 2, DUST_EDGE, (1.0 - t ** 1.6) * 0.8, 1, gap=0.2, seed=i * 7)
        ring(f, cx, cy, r - 5, GLOW[3], (1.0 - t) * 0.6, 1, gap=0.5, seed=i * 5)
        for k, (ang, pr, sz) in enumerate(puffs):
            rr = r * pr
            dust_puff(f, cx + math.cos(ang) * rr, cy + math.sin(ang) * rr * SQUASH - t * 6, sz * (0.6 + t * 0.6),
                      fade, k * 29 + i)
        dust_puff(f, cx, cy - 4 - t * 8, 7 + t * 9, fade, 77 + i)
        if i <= 1:
            for k in range(-7, 8):
                f.put(cx + k * 2, cy, GLOW[5 - i])
            for k in range(-10, 3):
                f.put(cx, cy + k, GLOW[5 - i] if abs(k) < 5 else GLOW[3])
        for (ang, dist, hmax, sz) in boulders:
            x = cx + math.cos(ang) * dist * (0.4 + t)
            y = cy + math.sin(ang) * dist * (0.4 + t) * SQUASH - hmax * 4 * t * (1 - t)
            if t < 0.92:
                rock(f, x, y, sz, shade=2 if sz < 4 else 3)
        if 2 <= i <= 6:  # sersemletme kivilcimlari
            for k in range(6):
                ang = k * 2 * math.pi / 6 + t * 3
                spark(f, cx + math.cos(ang) * R * 0.5, cy - 14 + math.sin(ang) * R * 0.22, 3 if (i + k) % 2 else 4)
        frames.append(f.image())
    save("quake", frames, 16.0)


# ------------------------------------------------------------------ E: Golem Sicrayisi inisi
def land():
    W, H, cx, cy = 272, 152, 136, 80
    R = 150.0 / TEXEL
    n = 10
    rnd = random.Random(515)
    streaks = [(i * 2 * math.pi / 12 + rnd.uniform(-0.12, 0.12), rnd.uniform(0.85, 1.0)) for i in range(12)]
    cracks = [jagged(rnd, cx, cy, i * 2 * math.pi / 6 + rnd.uniform(-0.3, 0.3), rnd.uniform(14, 24), 2.5, 0.3)
              for i in range(6)]
    chips = [(rnd.uniform(0, 2 * math.pi), rnd.uniform(14, 36), rnd.uniform(10, 20), rnd.choice((1, 2, 2, 3))) for _ in range(10)]
    puffs = [(k * 2 * math.pi / 10 + rnd.uniform(-0.2, 0.2), rnd.uniform(0.8, 0.95), rnd.uniform(4.0, 6.5)) for k in range(10)]
    frames = []
    for i in range(n):
        t = i / (n - 1)
        f = Frame(W, H)
        fade = 1.0 - max(0.0, (t - 0.6) / 0.4)
        # ICE cekilen toz cizgileri (2 px, uc parlak) - herkesi birbirine ceker
        pull = min(1.0, t * 1.5)
        if pull < 1.0:
            for (ang, rr) in streaks:
                head = R * rr * (1 - pull) + 12
                for k in range(12):
                    d = head + k * 2.0
                    aa = ang + (d / R) * 0.4
                    if d > R * rr + 6:
                        break
                    col = GLOW[4] if k == 0 else DUST[2] if k < 4 else DUST[1] if k < 8 else DUST[0]
                    al = 1.0 if k < 7 else 0.55
                    x, y = cx + math.cos(aa) * d, cy + math.sin(aa) * d * SQUASH
                    f.put(x, y, col, al)
                    f.put(x, y + 1, DUST_EDGE if k else GLOW[3], al)
        for pts in cracks:
            crack(f, pts, fade, min(1.0, 0.4 + t * 2.0), GLOW[max(1, 4 - i)] if i <= 3 else None, 0.6)
        r = 10 + (R * 0.6 - 10) * (1 - (1 - t) ** 2.2)
        ring(f, cx, cy, r, DUST[2], 0.95 * fade, 2, gap=0.08, seed=i)
        ring(f, cx, cy + 1, r - 2, DUST_EDGE, 0.7 * fade, 1, gap=0.25, seed=i + 5)
        ring(f, cx, cy, R, GLOW[2], 0.7 * (1 - pull), 1, gap=0.35, seed=i + 90)  # cekme alani siniri
        for k, (ang, pr, sz) in enumerate(puffs):
            rr = r * pr
            dust_puff(f, cx + math.cos(ang) * rr, cy + math.sin(ang) * rr * SQUASH - t * 5, sz * (0.6 + t * 0.6),
                      fade, k * 17 + i)
        dust_puff(f, cx, cy - 3 - t * 6, 6 + t * 8, fade, 33 + i)
        if i == 0:
            for k in range(-6, 7):
                f.put(cx + k * 2, cy, GLOW[5])
            spark(f, cx, cy - 7, 4)
        for (ang, dist, hmax, sz) in chips:
            x = cx + math.cos(ang) * dist * t * 1.3
            y = cy + math.sin(ang) * dist * t * 1.3 * SQUASH - hmax * 4 * t * (1 - t)
            if t < 0.95:
                rock(f, x, y, sz)
        frames.append(f.image())
    save("land", frames, 18.0)


# ------------------------------------------------------------------ R: donusum
def transform():
    W, H, cx, gy = 128, 160, 64, 124   # gy = yer (ayak) satiri
    body_y = gy - 30
    n = 11
    rnd = random.Random(77)
    shards = [(rnd.uniform(0, 2 * math.pi), rnd.uniform(26, 44), rnd.choice((2, 2, 3, 3, 4)), rnd.uniform(0, 0.25)) for _ in range(16)]
    frames = []
    for i in range(n):
        t = i / (n - 1)
        f = Frame(W, H)
        fade = 1.0 - max(0.0, (t - 0.65) / 0.35)
        # ayak altinda amber run halkasi (elips) - acilir, sonra soner
        rr = 12 + 26 * min(1.0, t * 2.5)
        ring(f, cx, gy, rr, GLOW[3] if t < 0.5 else GLOW[2], fade, 1, gap=0.0, seed=i)
        ring(f, cx, gy, rr - 4, GLOW[1], fade * 0.7, 1, gap=0.4, seed=i + 7)
        for k in range(6):  # halkadaki runler
            a = k * 2 * math.pi / 6 + t * 1.5
            x, y = cx + math.cos(a) * (rr - 2), gy + math.sin(a) * (rr - 2) * SQUASH
            f.put(x, y - 1, GLOW[4], fade)
            f.put(x, y + 1, GLOW[4], fade)
            f.put(x - 1, y, GLOW[3], fade)
            f.put(x + 1, y, GLOW[3], fade)
        # yerden kopup govdeye toplanan tas parcalari (t 0..0.55)
        for (a, dist, s, delay) in shards:
            tt = min(1.0, max(0.0, (t - delay) / 0.5))
            if tt >= 1.0:
                continue
            e = tt * tt
            x = cx + math.cos(a) * dist * (1 - e)
            y = gy + math.sin(a) * dist * SQUASH * (1 - e) - (gy - body_y) * e - 8 * math.sin(tt * math.pi)
            rock(f, x, y, s, shade=2)
        # govdede amber parlama (dikey elips, dither)
        g = max(0.0, 1.0 - abs(t - 0.5) / 0.3)
        if g > 0:
            for yy in range(-26, 27):
                for xx in range(-14, 15):
                    e = (xx / 14.0) ** 2 + (yy / 26.0) ** 2
                    if e <= 1.0:
                        lvl = 5 if e < 0.12 else 4 if e < 0.35 else 3 if e < 0.7 else 2
                        f.put(cx + xx, body_y + yy, GLOW[lvl], g * (1.0 - e * 0.6))
        # toz patlamasi (sonda)
        if t > 0.45:
            tt = (t - 0.45) / 0.55
            for k in range(8):
                a = k * 2 * math.pi / 8
                dust_puff(f, cx + math.cos(a) * (14 + tt * 30), gy + math.sin(a) * (14 + tt * 30) * SQUASH - tt * 6,
                          3 + tt * 3, 0.8 * (1 - tt), k * 11 + i)
        if i in (4, 5, 6):
            for (sx, sy) in ((-20, -40), (22, -30), (-12, -60), (16, -54)):
                spark(f, cx + sx, body_y + sy + 30, 3 + (i % 2))
        frames.append(f.image())
    save("transform", frames, 18.0)


def save(name, frames, fps):
    os.makedirs(OUT, exist_ok=True)
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i * w, 0))
    sheet.save(os.path.join(OUT, name + "_sheet.png"))
    write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), RES + name + "_sheet.png", w, h,
                        [("play", (0, 0), len(frames), False, fps)])


if __name__ == "__main__":
    slam()
    quake()
    land()
    transform()
