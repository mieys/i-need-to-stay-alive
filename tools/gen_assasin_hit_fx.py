#!/usr/bin/env python3
"""Assasin Cocuk'un ULTI'si (Golge Hucumu) yaratiga vurunca cikan KESIK efektini pixel-art spritesheet olarak pisirir.

Kullanici istegi (2026-09-24): "Assasin cocugun ultisi yaratiga vurunca cikan kesik efektini pixel tarzda yeniden
tasarla, sonrasinda spritesheete donustur performans sorunu olmamasi icin." - eski efekt (fx_assasin_shadow_hit.gd)
her karede _draw() ile duz draw_line/draw_rect ciziyordu (yumusak, pixel olmayan cizgiler). Artik tek AnimatedSprite2D.

Tasarim (48x48 piksel yogunlugu - 1 sanat pikseli = PixelDraw.TEXEL dunya birimi, 1 px kontur, iri blok yok):
  * Efekt +x yonune (hamle yonune) bakar; oyunda node'un rotation'i = hamle yonu.
  * 0. kare: isabet noktasinda beyaz-mor elmas parlama + kisa 4 kollu yildiz.
  * Iki capraz GOLGE HANCER KESIGI (X): once birinci, bir kare sonra ikinci kesik ucundan ucuna "cizilerek" belirir;
    hilal bicimli (ortada 3-4 px kalin, uclarda 1 px), beyaz-lavanta cekirdek + mor kenar + koyu mor kontur.
  * Kesikler once incelir, sonra kucuk parcaciklara ayrilarak (piksel piksel kopma) soner.
  * Hamle yonune dogru saclan 8 koyu mor golge kiymigi + arkada sonen iki tonlu golge dumani.
Cikti: assets/fx/assasin/shadow_hit_sheet.png + shadow_hit_frames.tres ("hit", 9 kare, 30 fps, tek sefer).
Kullanim: python tools/gen_assasin_hit_fx.py [onizleme.png]
"""
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_enemy_ability_fx import put, rgba, with_alpha, outline_pass, ease_out, _puff  # noqa: E402
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "assasin")
RES = "res://assets/fx/assasin/"

W, H = 72, 64
CX, CY = 34, 32
CORE = rgba(0.97, 0.93, 1.0)
LIGHT = rgba(0.8, 0.62, 1.0)
VIOLET = rgba(0.6, 0.26, 0.95)
DEEP = rgba(0.33, 0.1, 0.55)
OUTLINE = rgba(0.12, 0.03, 0.2)
SMOKE = [rgba(0.42, 0.3, 0.6), rgba(0.28, 0.16, 0.44), rgba(0.18, 0.08, 0.3)]

N_FRAMES = 9
FPS = 30.0


def _hash01(x, y, seed):
    h = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    return ((h & 0xFFFF) / 65535.0)


def slash(im, angle, length, bend, max_w, reveal, thin, dissolve, seed):
    """Merkezden gecen hilal kesik. reveal: 0..1 ne kadari cizildi (bastan sona), thin: 0..1 incelme,
    dissolve: 0..1 piksel kopma orani."""
    ca, sa = math.cos(angle), math.sin(angle)
    nx, ny = -sa, ca  # dikey
    steps = int(length * 2.5)
    for i in range(steps + 1):
        t = i / steps
        if t > reveal:
            break
        u = t * 2.0 - 1.0  # -1..1
        # hilal: merkez cizgisi hafif egri (bend), kalinlik sin
        px_ = CX + ca * u * length * 0.5 + nx * bend * (1.0 - u * u)
        py_ = CY + sa * u * length * 0.5 + ny * bend * (1.0 - u * u)
        w = max_w * math.sin(math.pi * t) * (1.0 - thin * 0.75)
        # cizim ucu (yeni cizilen kisim) daha parlak
        head = reveal < 1.0 and (reveal - t) < 0.12
        r = max(0.5, w * 0.5)
        ri = int(math.ceil(r)) + 1
        for dy in range(-ri, ri + 1):
            for dx in range(-ri, ri + 1):
                d = math.hypot(dx, dy)
                if d > r:
                    continue
                x, y = int(round(px_ + dx)), int(round(py_ + dy))
                if dissolve > 0 and _hash01(x, y, seed) < dissolve:
                    continue
                if head or d < r - 1.2:
                    col = CORE
                elif d < r - 0.4:
                    col = LIGHT
                else:
                    col = VIOLET
                put(im, x, y, col)


def frames():
    rnd = random.Random(4)
    shards = [(rnd.uniform(-0.75, 0.75), rnd.uniform(0.6, 1.0), rnd.choice([1, 2, 2])) for _ in range(8)]
    puffs = [(rnd.uniform(-10, 4), rnd.uniform(-8, 8), rnd.uniform(3.0, 4.5)) for _ in range(5)]
    A1, A2 = math.radians(-28), math.radians(34)  # iki capraz kesik (+x = hamle yonu)
    out = []
    for fi in range(N_FRAMES):
        t = fi / (N_FRAMES - 1)
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        # arkada golge dumani (en altta)
        if t > 0.15:
            k = (t - 0.15) / 0.85
            for ox, oy, rr in puffs:
                r = rr * (0.6 + 0.6 * ease_out(k)) * (1.0 - 0.5 * k)
                if r > 0.7:
                    _puff(im, CX + ox - k * 6, CY + oy - k * 4, r, SMOKE, 0.75 * (1.0 - k))
        # kesik 1: kare 0-1 cizilir, 3'ten itibaren incelir, 5'ten itibaren kopar
        r1 = min(1.0, (fi + 1) / 2.0)
        slash(im, A1, 52, 5.0, 5.0, r1, max(0.0, (fi - 2) / 4.0), max(0.0, (fi - 4) / 4.0), 11)
        # kesik 2: bir kare gecikmeli
        if fi >= 1:
            r2 = min(1.0, fi / 2.0)
            slash(im, A2, 46, -4.0, 4.4, r2, max(0.0, (fi - 3) / 4.0), max(0.0, (fi - 5) / 3.5), 23)
        outline_pass(im, with_alpha(OUTLINE, 1.0 - max(0.0, t - 0.6) * 2.0))
        # isabet parlamasi (kontursuz, ustte)
        if fi <= 2:
            k = 1.0 - fi / 3.0
            rr = int(2 + 4 * k)
            for dy in range(-rr, rr + 1):
                for dx in range(-rr, rr + 1):
                    if abs(dx) + abs(dy) <= rr:
                        put(im, CX + dx, CY + dy, CORE if abs(dx) + abs(dy) < rr - 1 else LIGHT)
            ln = int(4 + 9 * k)
            for s in range(rr, rr + ln):
                c = CORE if s < rr + ln * 0.5 else LIGHT
                put(im, CX + s, CY, c)
                put(im, CX - s, CY, c)
                put(im, CX, CY + s, c)
                put(im, CX, CY - s, c)
        # golge kiymiklari: hamle yonune (+x) acilan koni
        if 0 < fi:
            k = ease_out((fi - 0.5) / (N_FRAMES - 1.5))
            for ang, sp, sz in shards:
                d = 6 + 26 * sp * k
                x = CX + math.cos(ang) * d
                y = CY + math.sin(ang) * d + k * k * 3
                a = 1.0 - max(0.0, k - 0.55) / 0.45
                col = with_alpha(LIGHT if k < 0.4 else VIOLET, a)
                for oy in range(sz):
                    for ox in range(sz):
                        put(im, x + ox, y + oy, col)
                put(im, x - math.cos(ang) * 2, y - math.sin(ang) * 2, with_alpha(VIOLET, a * 0.8))
        out.append(im)
    return out


def main():
    fr = frames()
    sheet = Image.new("RGBA", (W * len(fr), H), (0, 0, 0, 0))
    for i, f in enumerate(fr):
        sheet.paste(f, (i * W, 0), f)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "shadow_hit_sheet.png")
    sheet.save(path)
    print("wrote", path, sheet.size)
    write_sprite_frames(os.path.join(OUT, "shadow_hit_frames.tres"), RES + "shadow_hit_sheet.png", W, H,
                        [("hit", (0, 0), len(fr), False, FPS)])
    if len(sys.argv) > 1:
        S = 5
        prev = Image.new("RGBA", ((W * S + 6) * len(fr) + 6, H * S + 12), (58, 72, 52, 255))
        for i, f in enumerate(fr):
            prev.alpha_composite(f.resize((W * S, H * S), Image.NEAREST), (6 + i * (W * S + 6), 6))
        prev.save(sys.argv[1])
        print("preview ->", sys.argv[1])


if __name__ == "__main__":
    main()
