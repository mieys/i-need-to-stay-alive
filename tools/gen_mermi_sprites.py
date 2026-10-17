# -*- coding: utf-8 -*-
"""MERMİ SANATI üretici (madde 201). Prototip: madde 199 `tools/proto_20261017/mermi_proto.py` (çizimler oradan, birebir).
Kullanıcı seçimi (2026-10-17): Yay + Arbalet (ikisi de A'nın oku), Tüftüf, Fişek = A Zanaatkâr; Tabanca, Tüfek, Arcane, Buz = C Işık İzi.

Yoğunluk: 1 doku pikseli = 0,575 dünya px (weapon_tier_art.gd WORLD_PX, silahlarla aynı). Mermi kökü sahibin ölçeğiyle (0,5) çarpıldığı
için sahnede gövde ölçeği 1,15; iz projectile.gd'de global ölçekle (0,575) sabitlenir. +x = uçuş yönü.
Çıktılar:
  assets/weapons/mermi/<ad>_govde.png  gövde kareleri (yatay şerit, kareler TEK boyutlu, pivot pikseli karenin tam ortası)
  assets/weapons/mermi/<ad>_iz.png     iz kareleri (yatay şerit): önce LAUNCH uzayan kareler, sonra FLY; izin başı sağ kenarda
  assets/weapons/mermi/fisek_alev.png  fişek egzoz alevi + kısa duman, 3 kare, alevin tabanı sağ kenarda
  assets/fx/projectile_trails/<stil>_sheet.png  dünya parçacıkları: 8 kare ömür x 2 varyant (fx_particle_trail.gd)
Ölçüler (kare boyu, izin ofseti) scripts/projectile_art.gd ART tablosuyla AYNI olmalı - betik sonunda yazdırılır.
Çalıştırma: python tools/gen_mermi_sprites.py   (sonra: Godot --headless --path . --import)
"""
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "proto_20261017"))
sys.argv = sys.argv[:1]
import mermi_proto as M  # noqa: E402
from mermi_proto import Lay, H2, streak, core, rev, cl, hx, on  # noqa: E402

GAME = os.path.normpath(os.path.join(HERE, ".."))
OUT = os.path.join(GAME, "assets", "weapons", "mermi")
POUT = os.path.join(GAME, "assets", "fx", "projectile_trails")
LAUNCH = (0.25, 0.5, 0.75)  # uzayan iz kareleri (tam boyun oranı)


def eng(fn, f):
    """Silah motoru gövdesi -> Lay (pivot 80,80)."""
    L = Lay()
    L.im.alpha_composite(M.body(fn, f), (H2 - 24, H2 - 24))
    return L


def crop_body(lays):
    """Tüm kareleri kapsayan, pivota göre simetrik TEK boyutlu kesim (Godot centered sprite -> pivot pikselinin ortası kökte)."""
    hx_, hy_ = 0, 0
    for L in lays:
        bb = L.im.getchannel("A").getbbox()
        hx_ = max(hx_, H2 - bb[0], bb[2] - 1 - H2)
        hy_ = max(hy_, H2 - bb[1], bb[3] - 1 - H2)
    box = (H2 - hx_, H2 - hy_, H2 + hx_ + 1, H2 + hy_ + 1)
    return [L.im.crop(box) for L in lays]


def crop_trail(lays, x0, n):
    """İz kesimi: x0 (izin ilk/baş pikseli) sağ kenarda, n piksel geriye; dikeyde simetrik TEK."""
    hy_ = 0
    for L in lays:
        bb = L.im.getchannel("A").getbbox()
        if bb:
            hy_ = max(hy_, H2 - bb[1], bb[3] - 1 - H2)
    box = (H2 + x0 - n + 1, H2 - hy_, H2 + x0 + 1, H2 + hy_ + 1)
    return [L.im.crop(box) for L in lays]


def strip(frames, path):
    w, h = frames[0].size
    im = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        im.paste(fr, (i * w, 0))
    im.save(path)
    return w, h


# ------------------------------------------------------------------ iz çizimleri (prototipteki yerel fonksiyonların İZ kısmı)
def iz_ok(L, f, clip):
    M.tA_yay(L, f, clip)


def iz_dart(L, f, clip):
    M.tA_tuftuf(L, f, clip)


def iz_tabanca(L, f, clip):
    streak(L, -3, 28, 1.5, 0.5, M.AMB, a0=1.0, a1=0.15, ph=2 * f, clip=clip, core=(hx("#ffffff"), 6))


def iz_tufek(L, f, clip):
    streak(L, -5, 52, 1.5, 0.5, M.GOLD, a0=1.0, a1=0.1, ph=2 * f, clip=clip, core=(hx("#ffffff"), 14))


def iz_arcane(L, f, clip):
    for s in (1, -1):
        streak(L, -5, 38, 0.5, 0.5, M.VIOC[1:], a0=0.95, a1=0.15, clip=clip,
               wave=lambda t, i, s=s: s * 4.4 * math.sin(i * 0.34 - f * math.pi / 2) * min(1.0, i / 6.0))
    streak(L, -5, 18, 2.0, 0.5, M.VIOC, a0=0.6, a1=0.1, ph=f, clip=clip)


def iz_buz(L, f, clip):
    streak(L, -7, 34, 3.0, 0.5, M.CYAN[1:], a0=0.8, a1=0.05, ph=2 * f, clip=clip)


# ------------------------------------------------------------------ C gövdeleri (prototipteki yerel fonksiyonların GÖVDE kısmı)
def gv_tabanca(f):
    L = Lay()
    core(L, 3.2, 2.2, rev(M.AMB))
    return L


def gv_tufek(f):
    L = Lay()
    core(L, 5.0, 1.6, rev(M.GOLD))
    return L


def gv_arcane(f):
    L = Lay()
    core(L, 5.8, 5.8, rev(M.VIOC))
    th = f * math.pi / 2
    for k in (0, 1):
        L.put(round(9.0 * math.cos(th + k * math.pi)), round(5.6 * math.sin(th + k * math.pi)), M.VIOC[0])
    return L


def gv_buz(f):
    L = Lay()
    for y in range(-5, 6):
        for x in range(-8, 13):
            d = abs(y) / 5.0 + (x / 12.5 if x > 0 else -x / 8.5)
            if d <= 1.0:
                L.put(x, y, M.CYAN[min(4, int(d * 4.6))] if d > 0.25 else M.CYAN[0])
    L.put(13, 0, M.CYAN[0])
    L.put((-3, 1, 5, 9)[f % 4], -2, hx("#ffffff"))
    return L


# ad: (gövde kareleri, iz fonksiyonu, iz x0, iz n, fly kare sayısı)
SET = {
    "ok": ([eng(M.bA_yay, 0)], iz_ok, -12, 20, 2),
    "dart": ([eng(M.bA_tuftuf, 0)], iz_dart, -14, 14, 2),
    "tabanca": ([gv_tabanca(0)], iz_tabanca, -3, 28, 2),
    "tufek": ([gv_tufek(0)], iz_tufek, -5, 52, 2),
    "arcane": ([gv_arcane(f) for f in range(4)], iz_arcane, -5, 38, 4),
    "buz": ([gv_buz(f) for f in range(4)], iz_buz, -7, 34, 2),
}


def bake_projectiles():
    rows = []
    for name, (bodies, iz, x0, n, nfly) in SET.items():
        bw, bh = strip(crop_body(bodies), os.path.join(OUT, "%s_govde.png" % name))
        lays = []
        for fr in LAUNCH:
            L = Lay()
            iz(L, 0, -x0 + fr * n)
            lays.append(L)
        for f in range(nfly):
            L = Lay()
            iz(L, f, None)
            lays.append(L)
        tw, th = strip(crop_trail(lays, x0, n), os.path.join(OUT, "%s_iz.png" % name))
        ## Godot centered sprite: başın (sağ kenar pikseli) ortası yerel x0'da -> offset.x = x0 - tw/2 + 0,5
        rows.append((name, len(bodies), bw, bh, tw, th, x0 - tw / 2.0 + 0.5, nfly))
    return rows


def bake_flame():
    """Fişek alevi: prototip bA_fisek'in alev katmanları (taban a=0, -x yönüne) + tA_fisek dumanı (alev ucunun hemen arkasından)."""
    lays = []
    for f, ln in enumerate((5.0, 6.6, 5.6)):
        L = Lay()
        M.streak(L, -8, 12, 1.0, 2.0, M.GREY, a0=0.6, a1=0.05, ph=2 * f, solid=0.2)

        def flame(c, _f, ln=ln):
            fo = [(-u * ln, v * 2.5) for u, v in M.S.F1]
            c.layers([fo, M.S.scale_poly(fo, -ln * 0.15, 0, 0.66), M.S.scale_poly(fo, 0.0, 0, 0.3)], "A_fire", (3, 4, 5))

        L.im.alpha_composite(M.body(flame, f), (H2 - 24, H2 - 24))
        lays.append(L)
    fr = crop_trail(lays, 0, 21)
    w, h = strip(fr, os.path.join(OUT, "fisek_alev.png"))
    return w, h, 0 - w / 2.0 + 0.5


# ------------------------------------------------------------------ dünya parçacıkları (8 kare ömür x 2 varyant)
def particle_sheet(name, kind, cols, cell, kinds2=None, r=(1.0, 1.0)):
    im = Image.new("RGBA", (cell * 8, cell * 2), (0, 0, 0, 0))
    px = im.load()
    for v in range(2):
        kd = kind if v == 0 or not kinds2 else kinds2
        for fi in range(8):
            k = (fi + 0.5) / 8.0
            n = len(cols)
            ci = min(n - 1, int(k * n))
            col = cols[ci]
            a = 1.0 - k * k
            cx, cy = fi * cell + cell // 2, v * cell + cell // 2

            def put(x, y, c, aa=1.0):
                if aa >= 1.0 or on(x, y, aa):
                    px[x, y] = tuple(c) + (255,)

            if kd == "dot":
                put(cx, cy, col, a)
            elif kd == "plus":
                put(cx, cy, col)
                if k < 0.55:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        put(cx + dx, cy + dy, cols[min(n - 1, ci + 1)], a)
            elif kd == "drop":
                put(cx, cy, col)
                put(cx, cy - 1, cols[0], a)
            elif kd == "puff":
                rr = (r[0] + (r[1] - r[0]) * k) * (0.75 if v == 1 else 1.0)
                R = int(math.ceil(rr)) + 1
                for dy in range(-R, R + 1):
                    for dx in range(-R, R + 1):
                        if math.hypot(dx, dy) <= rr:
                            put(cx + dx, cy + dy, col, a * 0.85)
    im.save(os.path.join(POUT, "%s_sheet.png" % name))


def bake_particles():
    particle_sheet("zehir_damla", "drop", M.POIS, 5, kinds2="dot")
    particle_sheet("arcane_c", "dot", M.VIOC, 5, kinds2="plus")
    particle_sheet("buz_c", "plus", M.CYAN, 5, kinds2="dot")
    particle_sheet("fisek_kivilcim", "plus", M.SPARK, 5, kinds2="dot")
    particle_sheet("fisek_duman", "puff", M.GREY, 9, r=(1.2, 2.6))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    rows = bake_projectiles()
    fw, fh, fo = bake_flame()
    bake_particles()
    print("ad kare gövde(w,h) iz(w,h) iz_offset_x fly")
    for r in rows:
        print("%-8s %d  %2dx%-2d  %2dx%-2d  %6.1f  %d" % r)
    print("fisek_alev %dx%d offset_x %.1f" % (fw, fh, fo))
