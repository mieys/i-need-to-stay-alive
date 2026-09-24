#!/usr/bin/env python3
"""Silah efektleri + yeni Bumerang gorunumu - hepsi pixel-art spritesheet.

Kullanici istegi (2026-09-24):
  "yay, tufek tabanca arbalet tuftuf gibi silahlarin mermilerinin atis aninda arkalarinda mermilerinin rengine bagli
   olacak sekilde acik renkte iz efekti hazirla" -> trail_*: BEYAZ/gri tonlu iz (oyunda mermi rengine gore modulate).
  "kilic ve boomerang silahlarina ozel calisma bicimlerine uygun yeni ozel efektler de hazirla" ->
   sword_arc_*: Uzunkilic oyuncunun etrafinda DONEN bir kilic - arkasindan yorunge boyunca uzanan hilal iz.
   boomerang_whoosh_* / boomerang_catch_*: donen bumerangin etrafinda hava cizgileri + geri yakalanma pariltisi.
  "boomerangin gorunusunu yeniden tasarla (ikonuyla boomerangin oyun ici goruntusu ayni olmali)" ->
   boomerang art 48x48 (1 px kontur, 3 ton ahsap, boyali serit): icon.png bunun TAM 4x buyutulmusu, oyun ici mermi
   AYNI cizimin 12 onceden dondurulmus karesi (RotSprite benzeri: 4x EPX buyut -> dondur -> blok merkezinden ornekle -
   pixel izgarasi bozulmadan doner).
  "bu efektler pixel sanati olacak ve spritesheete donusturulecek" (bkz. hafiza: 48x48 yogunluk, 1 texel detay).

Cikti:
  assets/fx/trails/trail_sheet.png + trail_frames.tres            ("launch" tek sefer, "fly" dongu)
  assets/fx/sword_arc/arc_sheet.png + arc_frames.tres             ("loop" dongu)
  assets/weapons/boomerang/art48.png                              (48x48 kaynak cizim)
  assets/weapons/boomerang/icon.png                               (200x200 - art48 x4, ortali)
  assets/weapons/boomerang/rot_sheet.png                          (12 x 48x48 onceden dondurulmus)
  assets/fx/boomerang/whoosh_sheet.png + whoosh_frames.tres       ("loop")
  assets/fx/boomerang/catch_sheet.png + catch_frames.tres         ("play" tek sefer)
"""
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def rgba(r, g, b, a=1.0):
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)), int(round(a * 255)))


def put(im, x, y, c):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < im.width and 0 <= y < im.height:
        old = im.getpixel((x, y))
        if c[3] >= old[3]:
            im.putpixel((x, y), c)


def save_sheet(frames, path):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.save(path)
    print("wrote", path, sheet.size)
    return w, h


def res(path):
    return "res://" + os.path.relpath(path, ROOT).replace("\\", "/")


# ------------------------------------------------------------------------------------------------ mermi izi
def trail_frame(length, flick, grow=1.0):
    """Sagda (bas) mermiye yapisik, sola dogru incelip saydamlasan beyaz iz. 4 alfa basamagi (dither yok), 3 px kalin
    cekirdek + 1 px yumusak kenar sirasi. flick: kareler arasi kucuk kayma (parilti hissi)."""
    W, H = 32, 7
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    L = max(2, int(round(length * grow)))
    cy = H // 2
    for i in range(L):
        x = W - 1 - i
        f = i / max(L - 1, 1)  # 0 bas .. 1 kuyruk
        if f < 0.2:
            a, half = 0.95, 1
        elif f < 0.45:
            a, half = 0.7, 1
        elif f < 0.7:
            a, half = 0.45, 0 if (i + flick) % 3 else 1
        else:
            a, half = 0.22, 0
        if f > 0.85 and (i + flick) % 2:
            continue
        for dy in range(-half, half + 1):
            put(im, x, cy + dy, rgba(1, 1, 1, a if dy == 0 else a * 0.55))
    # bas: 2 px parlak nokta
    put(im, W - 1, cy, rgba(1, 1, 1, 1))
    put(im, W - 2, cy, rgba(1, 1, 1, 1))
    return im


def gen_trails():
    out = os.path.join(ROOT, "assets", "fx", "trails")
    launch = [trail_frame(28, 0, g) for g in (0.25, 0.5, 0.75, 1.0)]
    fly = [trail_frame(28, k) for k in range(3)]
    cell = save_sheet(launch + fly, os.path.join(out, "trail_sheet.png"))
    write_sprite_frames(os.path.join(out, "trail_frames.tres"), res(os.path.join(out, "trail_sheet.png")), cell[0], cell[1],
                        [("launch", (0, 0), 4, False, 40.0), ("fly", (4, 0), 3, True, 18.0)])


# ------------------------------------------------------------------------------------------------ kilic yorunge izi
def gen_sword_arc():
    """Merkez (oyuncu) karenin ortasinda; iz R yaricapli yorunge boyunca, bas 0 derecede (+x), kuyruk -100 dereceye
    uzanir (kilic artan aciyla doner - bkz. weapon_orbit_math.gd). Bas kalin ve parlak (beyaz-mavi celik), kuyruga dogru
    incelir ve 4 basamakta saydamlasir; kenarda tek tuk kivilcim."""
    out = os.path.join(ROOT, "assets", "fx", "sword_arc")
    R = 60
    S = R * 2 + 16
    c = S // 2
    frames = []
    span = math.radians(100)
    for fi in range(4):
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        steps = int(span * R * 1.6)
        for i in range(steps):
            f = i / steps  # 0 bas .. 1 kuyruk
            a = -f * span
            thick = 5 - int(f * 4.5)  # 5 px -> 1 px
            if f < 0.25:
                col, al = (0.92, 0.97, 1.0), 0.95
            elif f < 0.5:
                col, al = (0.75, 0.88, 1.0), 0.72
            elif f < 0.75:
                col, al = (0.6, 0.78, 1.0), 0.45
            else:
                col, al = (0.5, 0.7, 1.0), 0.22
            for t in range(max(1, thick)):
                rr = R - 2 + t - thick // 2
                put(im, c + math.cos(a) * rr, c + math.sin(a) * rr, rgba(*col, al))
            # dis kenarda ince parlak cizgi (celik yansimasi)
            if f < 0.6:
                rr = R - 2 + thick // 2 + 1
                put(im, c + math.cos(a) * rr, c + math.sin(a) * rr, rgba(1, 1, 1, al * 0.8))
        # kivilcimlar: kareye gore kayan 3 nokta
        for k in range(3):
            f = ((k * 0.31 + fi * 0.09) % 0.8) + 0.05
            a = -f * span
            rr = R + 4 + (k % 2) * 2
            put(im, c + math.cos(a) * rr, c + math.sin(a) * rr, rgba(1, 1, 1, 0.9 - f))
        frames.append(im)
    cell = save_sheet(frames, os.path.join(out, "arc_sheet.png"))
    write_sprite_frames(os.path.join(out, "arc_frames.tres"), res(os.path.join(out, "arc_sheet.png")), cell[0], cell[1],
                        [("loop", (0, 0), 4, True, 16.0)])


# ------------------------------------------------------------------------------------------------ bumerang
WOOD = [rgba(0.86, 0.62, 0.36), rgba(0.66, 0.42, 0.22), rgba(0.45, 0.27, 0.13)]  # acik, orta, koyu
OUTLINE = rgba(0.16, 0.08, 0.05)
PAINT_A = rgba(0.95, 0.9, 0.76)  # krem serit
PAINT_B = rgba(0.78, 0.2, 0.14)  # kirmizi serit


def boomerang_art():
    """48x48: klasik V bicimli bumerang, dirsek ustte-ortada, iki kol asagi-disa acilir, hafif kavisli. Isik sol-ustten:
    ust kenar acik, alt kenar koyu, 1 px koyu kontur, her kolun ucuna yakin krem+kirmizi boyali serit."""
    N = 48
    big = 8  # alt ornekleme icin once 8x cozunurlukte maske
    M = Image.new("L", (N * big, N * big), 0)
    d = ImageDraw.Draw(M)
    # kavisli kol: iki cubic benzeri egriyi kalin cizgiyle ciz
    def arm(p0, p1, p2, w0, w1):
        pts = []
        for i in range(41):
            t = i / 40
            x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
            y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
            w = w0 + (w1 - w0) * t
            pts.append((x, y, w))
        for x, y, w in pts:
            r = w * big / 2
            d.ellipse([x * big - r, y * big - r, x * big + r, y * big + r], fill=255)
    elbow = (24, 12)
    arm(elbow, (14, 16), (5, 33), 9.0, 6.5)
    arm(elbow, (34, 16), (43, 33), 9.0, 6.5)
    mask = M.resize((N, N), Image.BOX).point(lambda v: 255 if v >= 128 else 0)
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    mp = mask.load()
    inside = lambda x, y: 0 <= x < N and 0 <= y < N and mp[x, y] > 0
    for y in range(N):
        for x in range(N):
            if not inside(x, y):
                continue
            edge_up = not inside(x, y - 1) or not inside(x - 1, y - 1)
            edge_dn = not inside(x, y + 1) or not inside(x + 1, y + 1)
            col = WOOD[0] if edge_up else (WOOD[2] if edge_dn else WOOD[1])
            im.putpixel((x, y), col)
    # boyali seritler (kol uclarina yakin, kola dik)
    for side in (-1, 1):
        for t, pc in ((0.62, PAINT_A), (0.7, PAINT_B), (0.78, PAINT_A)):
            # kol ekseni uzerindeki nokta
            p0, p1, p2 = elbow, (24 + side * 10, 16), (24 + side * 19, 33)
            x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
            y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
            tx = 2 * (1 - t) * (p1[0] - p0[0]) + 2 * t * (p2[0] - p1[0])
            ty = 2 * (1 - t) * (p1[1] - p0[1]) + 2 * t * (p2[1] - p1[1])
            ln = math.hypot(tx, ty)
            nx, ny = -ty / ln, tx / ln
            for s in range(-6, 7):
                px_, py_ = int(round(x + nx * s * 0.5)), int(round(y + ny * s * 0.5))
                if inside(px_, py_):
                    im.putpixel((px_, py_), pc)
    # dirsekte kucuk parlak nokta (cila)
    for px_, py_ in ((23, 11), (24, 11), (22, 12)):
        if inside(px_, py_):
            im.putpixel((px_, py_), rgba(0.97, 0.8, 0.55))
    # 1 px dis kontur
    out = im.copy()
    for y in range(N):
        for x in range(N):
            if inside(x, y):
                continue
            if any(inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.putpixel((x, y), OUTLINE)
    return out


def epx(im):
    """Scale2x/EPX: kenarlari yumusatan 2x buyutme (RotSprite'in ilk adimi)."""
    w, h = im.size
    src = im.load()
    out = Image.new("RGBA", (w * 2, h * 2))
    o = out.load()
    g = lambda x, y: src[min(max(x, 0), w - 1), min(max(y, 0), h - 1)]
    for y in range(h):
        for x in range(w):
            P = g(x, y)
            A, B, C, D = g(x, y - 1), g(x + 1, y), g(x - 1, y), g(x, y + 1)
            e0 = A if (C == A and C != D and A != B) else P
            e1 = B if (A == B and A != C and B != D) else P
            e2 = C if (D == C and D != B and C != A) else P
            e3 = D if (B == D and B != A and D != C) else P
            o[2 * x, 2 * y] = e0
            o[2 * x + 1, 2 * y] = e1
            o[2 * x, 2 * y + 1] = e2
            o[2 * x + 1, 2 * y + 1] = e3
    return out


def rotsprite(im, deg):
    up = epx(epx(im))  # 4x
    rot = up.rotate(-deg, resample=Image.NEAREST, center=(up.width / 2, up.height / 2))
    w, h = im.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    r = rot.load()
    for y in range(h):
        for x in range(w):
            out.putpixel((x, y), r[x * 4 + 2, y * 4 + 2])
    return out


def gen_boomerang():
    wdir = os.path.join(ROOT, "assets", "weapons", "boomerang")
    fxdir = os.path.join(ROOT, "assets", "fx", "boomerang")
    art = boomerang_art()
    os.makedirs(wdir, exist_ok=True)
    art.save(os.path.join(wdir, "art48.png"))
    icon = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
    icon.paste(art.resize((192, 192), Image.NEAREST), (4, 4))
    icon.save(os.path.join(wdir, "icon.png"))
    print("wrote icon.png (art48 x4)")
    rots = [rotsprite(art, k * 30) for k in range(12)]
    cell = save_sheet(rots, os.path.join(wdir, "rot_sheet.png"))
    ## "spin": kare = donus acisi (boomerang_projectile.gd kareyi aciya gore SECER, oynatmaz - hiz 0).
    write_sprite_frames(os.path.join(wdir, "rot_frames.tres"), res(os.path.join(wdir, "rot_sheet.png")), cell[0], cell[1],
                        [("spin", (0, 0), 12, True, 0.0)])

    # hava cizgileri: donen bumerangin etrafinda 3 kavisli beyaz cizgi, kare basina donerek kayar (4 kare dongu)
    S = 64
    c = S // 2
    wh = []
    for fi in range(4):
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        for k in range(3):
            base = k * math.tau / 3 + fi * (math.tau / 12)
            for i in range(22):
                a = base + i * 0.045
                rr = 25 + (k % 2)
                al = 0.75 * (1 - i / 22)
                put(im, c + math.cos(a) * rr, c + math.sin(a) * rr, rgba(1, 1, 1, al))
        wh.append(im)
    cell = save_sheet(wh, os.path.join(fxdir, "whoosh_sheet.png"))
    write_sprite_frames(os.path.join(fxdir, "whoosh_frames.tres"), res(os.path.join(fxdir, "whoosh_sheet.png")), cell[0], cell[1],
                        [("loop", (0, 0), 4, True, 20.0)])

    # yakalanma pariltisi: 4 kollu yildiz + halka, 6 kare
    S = 32
    c = S // 2
    ct = []
    for fi in range(6):
        t = fi / 5
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ln = int(3 + t * 9)
        al = 1.0 - t * 0.85
        for i in range(ln):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                put(im, c + dx * i, c + dy * i, rgba(1, 0.95, 0.75, al * (1 - i / (ln + 1))))
        rr = 2 + t * 11
        for i in range(int(math.tau * rr)):
            a = i / (math.tau * rr) * math.tau
            if i % 3 == 0:
                put(im, c + math.cos(a) * rr, c + math.sin(a) * rr, rgba(0.95, 0.75, 0.45, al * 0.8))
        ct.append(im)
    cell = save_sheet(ct, os.path.join(fxdir, "catch_sheet.png"))
    write_sprite_frames(os.path.join(fxdir, "catch_frames.tres"), res(os.path.join(fxdir, "catch_sheet.png")), cell[0], cell[1],
                        [("play", (0, 0), 6, False, 24.0)])


if __name__ == "__main__":
    gen_trails()
    gen_sword_arc()
    gen_boomerang()
