# -*- coding: utf-8 -*-
"""ARCANE "C - Kaos Yarığı" + ZEHİR "B - Kabarcık" oyun sayfaları (madde 749, kullanıcı seçimi 2026-11-16; prototip madde 729
tools/proto_20261116/asa_efekt_proto.py - çizim kodu ORADAN: aynı Layer / renkler / yardımcılar, aynı zamanlama).
1 sanat pikseli = 1 DÜNYA birimi (prototipteki yoğunluk; oyunda kamera x2 -> 2 ekran px). Titreşim / dither YOK (düz alfa).

Çıktılar:
  assets/weapons/mermi/kaos_govde.png (4 kare, 16 fps)  kaos_iz.png (3 fırlatma + 4 uçuş)  kabarcik_govde.png (6 kare döngü)
      -> scripts/projectile_art.gd ART (wpx 1.0); iz ofseti KAOS_TOX (aşağıda yazdırılır)
  assets/fx/hit_effects/asa/<ad>_sheet.png + _frames.tres ("play", tek seferlik; scenes/fx_*.tscn fx_animation.gd):
      void_crack (Arcane isabeti), kaos_namlu (Arcane namlu), kabarcik_isabet (Zehir isabeti + sıçrama varışı),
      kabarcik_bulut (zehirli ölüm bulutu = sıçramanın kalkışı), kabarcik_namlu (Zehir namlu)
  assets/fx/enchant/void_rift_open / void_rift_pop_45 / void_rift_pop_60 (_sheet.png + _frames.tres; fx_enchant_sprite "sprite",
      merkez = yarığın merkezi; yankı yarıçapı 45 temel, Geniş Yankı 60 - ölçekleme yerine ikinci sayfa)
  assets/fx/poison/kabarcik_puf.png (6 hücre 10x10: r 1,5..4 dolu daire, opak; alfa çizimde) -> poison_drip_fx.gd mermi izi
Kullanım (proje kökünden): python -I tools/gen_asa_efekt_fx.py
"""
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "proto_20261116"))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402
import asa_efekt_proto as A  # noqa: E402

TAU = math.tau
MERMI = os.path.join(ROOT, "assets", "weapons", "mermi")
HIT = os.path.join(ROOT, "assets", "fx", "hit_effects", "asa")
ENCH = os.path.join(ROOT, "assets", "fx", "enchant")
POISON = os.path.join(ROOT, "assets", "fx", "poison")


def to_img(L):
    a = L.A
    rgb = np.zeros_like(L.C)
    m = a > 1e-6
    rgb[m] = L.C[m] / a[m][:, None]
    out = np.zeros(a.shape + (4,), np.uint8)
    out[..., :3] = np.clip(np.round(rgb), 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(np.round(a * 255.0), 0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def strip(frames):
    w, h = frames[0].size
    im = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im.paste(f, (i * w, 0))
    return im


def check_edges(name, frames):
    """Hiçbir şey kare kenarına değmesin (düz kesik olmasın)."""
    for i, f in enumerate(frames):
        a = np.asarray(f)[..., 3]
        if a[0, :].any() or a[-1, :].any() or a[:, 0].any() or a[:, -1].any():
            raise SystemExit("%s kare %d kenara değiyor" % (name, i))


def save_strip(path, frames):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    strip(frames).save(path)
    print("  %-46s %dx%d x %d" % (os.path.relpath(path, ROOT), frames[0].size[0], frames[0].size[1], len(frames)))


def save_anim(folder, res_folder, name, frames, fps, edge_check=True):
    if edge_check:
        check_edges(name, frames)
    save_strip(os.path.join(folder, name + "_sheet.png"), frames)
    w, h = frames[0].size
    write_sprite_frames(os.path.join(folder, name + "_frames.tres"), res_folder + name + "_sheet.png", w, h,
                        [("play", (0, 0), len(frames), False, float(fps))])


def frames_of(n, w, h, draw):
    out = []
    for i in range(n):
        L = A.Layer(w, h)
        draw(L, i)
        out.append(to_img(L))
    return out


# ====================================================================== ARCANE C - Kaos Yarığı
KAOS_W, KAOS_H = 32, 11
KAOS_TOX = -(KAOS_W / 2.0 + 2.0)  # iz karesi pivotun tamamen gerisinde: yerel x [-W-2, -2]


def kaos_body():
    ## kare TEK boyutlu (pivot pikseli tam ortada, test_projectile_art): 21 px, merkez 10. pikselin ortası
    return frames_of(4, 21, 21, lambda L, i: A._orb_C(L, 10.5, 10.5, i * 0.06 + 0.001))


def kaos_trail():
    out = []
    for i in range(7):
        L = A.Layer(KAOS_W, KAOS_H)
        length = 26.0 * (0.25, 0.5, 0.75)[i] if i < 3 else 26.0
        st = i if i >= 3 else 0
        ox, cy = KAOS_W + 2.0, KAOS_H / 2.0  # pivot karenin sağ dışında
        for seg in range(3):  # prototip _arc_C: 3 kopuk yırtık parçası, kuyruğa doğru söner
            s0, s1 = 5 + seg * length / 3, 5 + (seg + 1) * length / 3 - 2
            if s1 - s0 < 1.5:
                continue
            a = A.B(1 - seg / 3.0, 3)
            x0, x1 = ox - s0, ox - s1
            A._jag(L, x0, cy, x1, cy, st + seg, 1.8, 3, A.VOID[2], a, 2)
            A._jag(L, x0, cy - 1, x1, cy - 1, st + seg, 1.8, 3, A.VOID[1], a)
        out.append(to_img(L))
    return out


def void_crack():
    def d(L, i):
        a = i / 25.0
        q = a / 0.22
        c = 13.0
        for j in range(5):
            aa = j * TAU / 5 + 0.3
            A._jag(L, c, c, c + math.cos(aa) * (5 + 4 * q), c + math.sin(aa) * (5 + 4 * q), j, 1.0, 2, A.VOID[1], A.B(1 - q, 3))
        L.ring(c, c, 3 + 6 * q, 3 + 6 * q, 1, A.VOID[0], A.B(1 - q, 3))
        if i < 2:
            L.disc(c, c, 2.5, A.VOID[3], 0.9)
    return frames_of(6, 26, 26, d)


def kaos_muzzle():
    def d(L, i):
        q = (i / 25.0) / 0.15
        c = 9.0
        L.disc(c, c, 3 * (1 - q) + 1, A.VOID[3], 0.9)
        L.ring(c, c, 4 + 3 * q, 4 + 3 * q, 1, A.VOID[1], A.B(1 - q, 3))
    return frames_of(4, 18, 18, d)


def _rift(L, cx, cy, h, w, rim=A.VOID[1], a=1.0):
    if h < 2:
        return
    pts = [(math.sin(math.pi * (i / 12.0)) * w * (1 if s > 0 else -1), (i / 12.0 - 0.5) * h)
           for s in (1, -1) for i in (range(13) if s > 0 else range(12, -1, -1))]
    L.shape(pts, 0.0, cx, cy, lambda LX, LY: np.where((np.abs(LX) < 1.2)[..., None], np.array(A.VOID[2], A.f32),
                                                      np.array(A.VOID[3], A.f32)), ol=rim, a=a)
    L.px(cx, cy - h / 2 - 1, A.VOID[0], a)
    L.px(cx, cy + h / 2, A.VOID[0], a)


def rift_open():
    """0,8 sn (yankı gecikmesi) 20 fps: karanlık çekilir, yarık açılır (prototip _arc_C echo_age bölümü)."""
    W, H = 72, 60
    cx, cy = W / 2.0, H / 2.0

    def d(L, i):
        t = i / 20.0
        p = t / A.ECHO_DELAY
        g = A.ease_out(p / 0.5)
        h = 28 * g
        w = 3.5 * g + 0.6 * math.sin(t * 20) * g
        for j in range(6):
            ph = ((t * 2.5 + j / 6.0) % 1.0)
            r = 32 * (1 - ph)
            aa = j * TAU / 6 + 0.4
            if r > 6:
                bx, by = cx + math.cos(aa) * r, cy + math.sin(aa) * r * 0.8
                L.line(bx, by, bx - math.cos(aa) * 3, by - math.sin(aa) * 3 * 0.8, A.VOID[2], A.B(g * 0.9, 3), 2)
                L.px(bx - math.cos(aa) * 3, by - math.sin(aa) * 3 * 0.8, A.VOID[1], A.B(g, 3))
        _rift(L, cx, cy, h, w)
        st = int(t / 0.07)
        if g > 0.05:
            A._jag(L, cx, cy - h / 2, cx + 3, cy - h / 2 - 5 * g, st, 1.0, 2, A.VOID[1], g)
            A._jag(L, cx, cy + h / 2, cx - 3, cy + h / 2 + 5 * g, st + 3, 1.0, 2, A.VOID[1], g)
    return frames_of(int(round(A.ECHO_DELAY * 20)), W, H, d)


def rift_pop(R):
    """0,4 sn 25 fps: yarık kapanırken kırık halka şok dalgası (merkez yarığın 4 px altı, dikey x0,75)."""
    W = int(2 * R + 10)
    H = int(2 * (0.75 * R + 10))
    cx, cy = W / 2.0, H / 2.0 - 4

    def d(L, i):
        pop = i / 25.0
        q = pop / 0.4
        if pop < 0.15:
            k = 1 - pop / 0.15
            _rift(L, cx, cy, 28 * k, 5 * k, rim=A.VOID[0])
            L.disc(cx, cy, 10 * k, A.VOID[3], 0.7)
        r = 6 + (R - 6) * A.ease_out(q * 1.3)
        for j in range(6):
            a0 = j * 60 + 10 + q * 30
            L.arc(cx, cy + 4, r, r * 0.75, a0, a0 + 40, 2, A.VOID[1], A.B(1 - q, 3))
            L.arc(cx, cy + 4, r - 2, (r - 2) * 0.75, a0 + 5, a0 + 35, 1, A.VOID[0], A.B(1 - q, 3))
    return frames_of(10, W, H, d)


# ====================================================================== ZEHİR B - Kabarcık
def bubble_body():
    """6 karelik dikişsiz döngü (18 fps = 0,33 sn): esneme + içte dönen girdap noktası (prototip _bubble)."""
    def d(L, i):
        ph = TAU * i / 6.0
        c = 6.5
        wob = 0.5 * math.sin(ph)
        r = 4.0
        L.ell(c, c, r + wob, r - wob, A.POI[2], 0.35)
        L.ring(c, c, r + wob, r - wob, 1, A.POI[1], 0.9)
        L.px(c - r * 0.5, c - r * 0.55, A.WHITE)
        L.px(c - r * 0.5 + 1, c - r * 0.75, A.WHITE)
        L.px(c + math.cos(ph) * r * 0.45, c + math.sin(ph) * r * 0.45, A.POI[0])
    return frames_of(6, 13, 13, d)


def bubble_muzzle():
    def d(L, i):
        q = (i / 25.0) / 0.2
        L.disc(7.0, 7.0, 2 + 3 * q, A.POI[1], A.B(0.5 * (1 - q), 3))
    return frames_of(5, 14, 14, d)


def bubble_hit():
    """0,4 sn: kabarcık 4 yay parçasına kırılır + bulut hedefe EMİLİR (yerde kalmaz) - prototip _zeh_B isabet."""
    W, H = 30, 26
    cx, cy = W / 2.0, H / 2.0

    def d(L, i):
        a = i / 25.0
        if a < 0.2:
            q = a / 0.2
            r = 4 + 5 * q
            for j in range(4):
                a0 = j * 90 + 20
                L.arc(cx, cy, r, r, a0, a0 + 50, 1, A.POI[1], A.B(1 - q, 3))
        q = a / 0.4
        g = 1 - q
        circ = [(cx + ox * g, cy + oy * g, (4 + 4 * A.ease_out(q * 3)) * g + 1) for (ox, oy) in ((-5, -2), (4, -4), (0, 3), (6, 2))]
        L.cloud(circ, (A.POI[2], A.POI[1]), (A.B(0.4 * g), A.B(0.55 * g)), grow=(1.0, 0.6))
    return frames_of(10, W, H, d)


def bubble_cloud():
    """0,7 sn 20 fps: zehirli ölüm = temiz zehir bulutu (daire birleşimi, 3 düz alfa bandı), kabarır sonra küçülerek söner."""
    W, H = 54, 52
    cx, cy = W / 2.0, H / 2.0 + 3

    def d(L, i):
        death = i / 20.0
        q = death / 0.7
        g = A.ease_out(death / 0.4)
        sh = 1 - 0.5 * max(0.0, (death - 0.3) / 0.4)
        circ = [(cx + ox * (1 + 0.6 * g), cy + oy * (1 + 0.6 * g) - 4 * g, r0 * (1 + 0.6 * g) * sh)
                for (ox, oy, r0) in ((0, 0, 7), (-8, 2, 6), (8, 1, 6), (-3, -7, 6), (5, -6, 5), (-10, -3, 4), (11, -3, 4))]
        L.cloud(circ, (A.POI[3], A.POI[2], A.POI[1]), (A.B(0.35 * (1 - q)), A.B(0.5 * (1 - q)), A.B(0.6 * (1 - q))))
    return frames_of(14, W, H, d)


def puff_atlas():
    cells = []
    for r in (1.5, 2.0, 2.5, 3.0, 3.5, 4.0):
        L = A.Layer(10, 10)
        L.disc(5.0, 5.0, r, A.POI[2], 1.0)
        cells.append(to_img(L))
    return cells


def main():
    print("ARCANE C - Kaos Yarığı")
    body = kaos_body()
    check_edges("kaos_govde", body)
    save_strip(os.path.join(MERMI, "kaos_govde.png"), body)
    trail = kaos_trail()
    check_edges("kaos_iz", trail)
    save_strip(os.path.join(MERMI, "kaos_iz.png"), trail)
    save_anim(HIT, "res://assets/fx/hit_effects/asa/", "void_crack", void_crack(), 25)
    save_anim(HIT, "res://assets/fx/hit_effects/asa/", "kaos_namlu", kaos_muzzle(), 25)
    save_anim(ENCH, "res://assets/fx/enchant/", "void_rift_open", rift_open(), 20)
    for R in (45, 60):
        save_anim(ENCH, "res://assets/fx/enchant/", "void_rift_pop_%d" % R, rift_pop(R), 25)
    print("ZEHİR B - Kabarcık")
    bb = bubble_body()
    check_edges("kabarcik_govde", bb)
    save_strip(os.path.join(MERMI, "kabarcik_govde.png"), bb)
    save_anim(HIT, "res://assets/fx/hit_effects/asa/", "kabarcik_namlu", bubble_muzzle(), 25)
    save_anim(HIT, "res://assets/fx/hit_effects/asa/", "kabarcik_isabet", bubble_hit(), 25)
    save_anim(HIT, "res://assets/fx/hit_effects/asa/", "kabarcik_bulut", bubble_cloud(), 20)
    save_strip(os.path.join(POISON, "kabarcik_puf.png"), puff_atlas())
    print("projectile_art.gd: kaos iz tox = %.1f (kare %dx%d)" % (KAOS_TOX, KAOS_W, KAOS_H))


if __name__ == "__main__":
    main()
