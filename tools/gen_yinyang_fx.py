# -*- coding: utf-8 -*-
"""YİN YANG KİTABI oyun sanatı (madde 334; prototipler tools/proto_20261020/yinyang_sanat.py + yinyang_proto.py: kitap = B "Açık
Sayfalar", efekt = B "İkiz Sarmal" v2 - kitaptan yükselip ayrılan kara + ak küre).

Yazdıkları:
  assets/weapons/zanaat/yinyang_L<1..5>.png   kitap (48x48, Zanaatkâr merdiveni; çizim yinyang_sanat.B_book)
  assets/fx/yinyang/orb_dark.png              kara küre (yin) 11x11 - 1 doku pikseli = 0,575 dünya px (WeaponTierArt.WORLD_PX)
  assets/fx/yinyang/orb_light.png             ak küre (yang) 11x11
  assets/fx/yinyang/star.png                  varış parıltısı 7x7 (krem artı)
  assets/fx/yinyang/hit_sheet.png             kara küre isabeti: 9 kare 44x44 (30 fps) - kara kıymıklar + halka + krem yıldız
  + hit_frames.tres                           (scenes/fx_yinyang_hit.tscn, ölçek 0,575)
  assets/fx/enchant/taichi_seal_sheet.png     FİNAL Tai Chi Mührü yer mührü: 16 kare döngü (12 fps), yere yatık (y x0,5)
  + taichi_seal_frames.tres                   (fx_enchant_sprite.gd TEXEL 1,212; alan "sheet_scale" 0,5 -> 0,606 dünya px/doku px)
Saydamlık 4 kademe (dither yok). Çalıştırma: python tools/gen_yinyang_fx.py  (sonra Godot --headless --path . --import)
"""
import math
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
sys.path.insert(0, os.path.join(ROOT, "tools", "proto_20261020"))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402
import yinyang_sanat as YS  # noqa: E402

ZANAAT = os.path.join(ROOT, "assets", "weapons", "zanaat")
FXDIR = os.path.join(ROOT, "assets", "fx", "yinyang")
ENCH = os.path.join(ROOT, "assets", "fx", "enchant")


def hx(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


## prototip yinyang_proto.py ile AYNI palet
INK = [hx(c) for c in "#0c0a12 #1c1826 #2e2a3a #4a4458".split()]
INK_OL = hx("#060509")
CREAM = [hx(c) for c in "#fffdf6 #f2ead6 #d8ccae #aa9e82".split()]
CREAM_OL = hx("#6e6450")


class Cnv:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), np.float32)

    def put(self, x, y, col, al=1.0):
        if al <= 0.0 or not (0 <= x < self.w and 0 <= y < self.h):
            return
        p = self.a[y, x]
        p[:3] = np.array(col, np.float32) / 255.0 * al + p[:3] * (1.0 - al)
        p[3] = al + p[3] * (1.0 - al)

    def image(self):
        out = np.zeros((self.h, self.w, 4), np.uint8)
        al = np.clip(self.a[..., 3], 0.0, 1.0)
        safe = np.maximum(al, 1e-6)[..., None]
        out[..., :3] = np.clip(self.a[..., :3] / safe * 255.0, 0, 255).astype(np.uint8)
        out[..., 3] = (np.ceil(al * 4.0 - 1e-6) / 4.0 * 255.0).astype(np.uint8)  # 4 adım saydamlık (dither yok)
        return Image.fromarray(out, "RGBA")


def strip(frames):
    w, h = frames[0].size
    im = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im.paste(f, (i * w, 0))
    return im


def disc_mask(w, h, cx, cy, r):
    yy, xx = np.mgrid[0:h, 0:w]
    return np.hypot(xx + 0.5 - cx, yy + 0.5 - cy) <= r


def outline_of(m):
    d = m.copy()
    d[1:] |= m[:-1]
    d[:-1] |= m[1:]
    d[:, 1:] |= m[:, :-1]
    d[:, :-1] |= m[:, 1:]
    return d & ~m


# ---------------------------------------------------------------- kitap
def build_book():
    YS.frame("horiz")
    os.makedirs(ZANAAT, exist_ok=True)
    for lv in range(1, 6):
        cv = YS.Cv(lv)
        YS.B_book(cv, lv)
        cv.render().save(os.path.join(ZANAAT, "yinyang_L%d.png" % lv))
    print("kitap: yinyang_L1..5")


# ---------------------------------------------------------------- küreler + yıldız
def orb(base, hi, lo, spec, ol):
    n, r = 11, 3.8
    c = Cnv(n, n)
    m = disc_mask(n, n, 5.5, 5.5, r)
    for (y, x) in zip(*np.nonzero(outline_of(m))):
        c.put(x, y, ol)
    for (y, x) in zip(*np.nonzero(m)):
        k = (x + 0.5 - 5.5 + y + 0.5 - 5.5) / r  # ışık sol-üst
        col = hi if k < -0.55 else (lo if k > 0.75 else base)
        c.put(x, y, col)
    c.put(4, 4, spec)
    return c.image()


def build_orbs():
    os.makedirs(FXDIR, exist_ok=True)
    orb(INK[2], INK[3], INK[1], CREAM[3], INK_OL).save(os.path.join(FXDIR, "orb_dark.png"))
    orb(CREAM[1], CREAM[0], CREAM[2], (255, 255, 255), CREAM_OL).save(os.path.join(FXDIR, "orb_light.png"))
    c = Cnv(7, 7)
    for i in range(1, 4):
        col = CREAM[min(3, i)]
        for dx, dy in ((i, 0), (-i, 0), (0, i), (0, -i)):
            c.put(3 + dx, 3 + dy, col)
    c.put(3, 3, (255, 255, 255))
    for dx, dy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        c.put(3 + dx, 3 + dy, CREAM[1], 0.75)
    c.image().save(os.path.join(FXDIR, "star.png"))
    print("küreler + yıldız")


# ---------------------------------------------------------------- kara küre isabeti (prototip B_fx isabet bölümü, 30 fps)
def build_hit():
    S, n, fps = 44, 9, 30.0
    W = 0.575  # dünya px / doku px
    cx = cy = S / 2.0
    shards = [(0.3, 46.0), (1.25, 38.0), (2.2, 52.0), (3.15, 34.0), (4.05, 48.0), (5.15, 40.0)]
    frames = []
    for f in range(n):
        age = f / fps
        k = age / 0.3
        c = Cnv(S, S)
        e = 1.0 - (1.0 - k) ** 3
        if age < 0.2:  # ince kara halka
            kk = age / 0.2
            ee = 1.0 - (1.0 - kk) ** 3
            rx, ry = (3.0 + 8.0 * ee) / W, (2.5 + 5.0 * ee) / W
            for y in range(S):
                for x in range(S):
                    dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                    rho = math.hypot(dx, dy)
                    if abs(rho - 1.0) * min(rx, ry) < 0.95:
                        c.put(x, y, INK[2], 1.0 - kk)
        for (th, v) in shards:  # uçuşan kara kıymıklar (kısa çizgi, uca incelir)
            r0 = v * 0.3 * e / W
            r1 = r0 + (4.0 * (1.0 - k)) / W
            for s in np.linspace(0.0, 1.0, 9):
                rr = r0 + (r1 - r0) * s
                px = cx + math.cos(th) * rr
                py = cy + math.sin(th) * rr * 0.75
                wdt = (2.2 * (1.0 - k) + 0.8) * (1.0 - 0.6 * s)
                for oy in range(-1, 2):
                    for ox in range(-1, 2):
                        if math.hypot(ox, oy) <= wdt * 0.5:
                            c.put(int(px + ox), int(py + oy), INK[1] if s < 0.5 else INK[2], 1.0 - k)
        if age < 0.07:  # krem çarpma yıldızı
            r = int(round((5.0 * (1.0 - age / 0.07) + 1.0) / W * 0.6))
            for i in range(-r, r + 1):
                col = CREAM[min(3, int(abs(i) / max(1, r) * 4))]
                c.put(int(cx) + i, int(cy), col)
                c.put(int(cx), int(cy) + i, col)
        frames.append(c.image())
    os.makedirs(FXDIR, exist_ok=True)
    strip(frames).save(os.path.join(FXDIR, "hit_sheet.png"))
    write_sprite_frames(os.path.join(FXDIR, "hit_frames.tres"), "res://assets/fx/yinyang/hit_sheet.png", S, S,
                        [("play", (0, 0), n, False, fps)])  # fx_animation.gd "play" oynatır
    print("isabet", n, S)


# ---------------------------------------------------------------- FİNAL Tai Chi Mührü (yer mührü, döngü)
def build_seal():
    RX, RY = 148.0, 74.0
    FW, FH = int(RX * 2) + 6, int(RY * 2) + 6
    cx, cy = FW / 2.0, FH / 2.0
    n, fps = 16, 12.0
    yy, xx = np.mgrid[0:FH, 0:FW]
    U = (xx + 0.5 - cx) / RX  # yere yatık daire -> birim daire
    V = (yy + 0.5 - cy) / RY
    rho = np.hypot(U, V)
    frames = []
    for f in range(n):
        rot = 2 * math.pi * f / n
        c = Cnv(FW, FH)
        g = YS.YY(0.0, 0.0, 0.78, rot=rot + 1e-4)
        g.dtop, g.dbot = g.top, g.bot
        g.dr = 0.78 * 0.2
        ys, xs = np.nonzero(rho <= 1.02)
        for y, x in zip(ys, xs):
            u, v, r = U[y, x], V[y, x], rho[y, x]
            px_r = 1.0 / RY  # bir doku pikselinin birim dairedeki kabaca boyu
            if abs(r - 0.985) < px_r * 1.1:  # dış halka
                c.put(x, y, CREAM[1], 0.75)
                continue
            if abs(r - 0.865) < px_r * 0.6:  # iç halka
                c.put(x, y, CREAM[2], 0.5)
                continue
            if 0.885 < r < 0.965:  # dönen çentikler (8 kısa işaret)
                a = (math.atan2(v, u) - rot) % (math.pi / 4)
                if a < 0.06:
                    c.put(x, y, CREAM[1], 0.75)
                continue
            if r <= 0.78:
                side = g.side(u, v)
                if abs(r - 0.78) < px_r * 0.9:
                    c.put(x, y, CREAM[1] if side == "yin" else INK[2], 0.75)
                elif side == "yin":
                    c.put(x, y, INK[1], 0.5)
                else:
                    c.put(x, y, CREAM[1], 0.25)
        frames.append(c.image())
    os.makedirs(ENCH, exist_ok=True)
    strip(frames).save(os.path.join(ENCH, "taichi_seal_sheet.png"))
    write_sprite_frames(os.path.join(ENCH, "taichi_seal_frames.tres"), "res://assets/fx/enchant/taichi_seal_sheet.png", FW, FH,
                        [("loop", (0, 0), n, True, fps)])
    print("mühür", n, FW, FH)


if __name__ == "__main__":
    build_book()
    build_orbs()
    build_hit()
    build_seal()
