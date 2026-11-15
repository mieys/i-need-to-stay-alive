"""Shaman Q ATES TOPU + E KALKAN GONDERME prototipleri (madde 562, oyuna bagli DEGIL).

Arka plan: gercek cizici yakalamasi (yakala.ps1 -Mode bos: Shaman + Q/E run taslari + hedef yaratik + muttefik Elara, 1080p,
1 dunya birimi = 2,67 ekran px). Efektler bunun ustune OYUN OLCEGINDE cizilir: 1 efekt pikseli = karakter pikseli 0,903 dunya birimi
(madde 295: 0,575 1080p'de kayboluyor), sprite'lar en yakin komsu buyutulur (oyundaki gibi esitsiz piksel genislikleri).
Dither / noktali halka / seyrek parazit YOK (madde 557: "parazitli" bulundu). Renkler: ates = oyunun yanma alevi paleti, kalkan = E tasi.

  A  Kor Topu + Kalkan Kuresi   Q: duz ucan kucuk kor topu + kisa kuyruk      E: her saniye taştan kavisle ucan kure (tik)
  B  Run Mermisi + Run Bagi     Q: kizgin run isareti ucar, kul dokulur       E: SUREKLI gergin isik bagi, ustunde kayan run elmaslari
  C  Alev Yayi + Isik Seridi    Q: kavisle dusen buyuk alev topu + yer atesi  E: SUREKLI tastan muttefige dalgalanarak akan isik seridi
  D  Isik Mizragi + Mavi Hale   Q: anlik kizgin isik mizragi + parlama        E: SUREKLI muttefikte mavi dis hat + saniyede bir parilti

Kullanim (repo kokunden): python -I tools/proto_20261111/shaman_mermi/mermi_proto.py
Cikti: tools/proto_20261111/shaman_mermi/out/{A,B,C,D,suan}.gif, karsilastirma.gif (alt alta), ozet.png
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "out")
BG_DIR = os.path.join(OUT, "yakala_bos")
NOW_DIR = os.path.join(OUT, "yakala_suan")
FONT = os.path.join(ROOT, "assets", "fonts", "m5x7.ttf")

META = json.load(open(os.path.join(BG_DIR, "meta.json"), encoding="utf-8"))
S = META["px_per_world"]          # ekran px / dunya birimi
ART = 0.903                       # efekt pikseli (dunya)
F = ART * S                       # ekran px / efekt pikseli (~2,41)
FPS = 20
DUR = 3.0
NFR = int(DUR * FPS)


def W(v):  # dunya birimi -> ekran px
    return v * S


def hx(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


# Oyunun yanma alevi paleti (assets/fx/burn/yer_alevi_sheet.png) + E tasinin mavileri (tools/gen_shaman_rune_stones.py)
FIRE = {"b": hx("#661a0f"), "r": hx("#d64c1f"), "o": hx("#fa9433"), "y": hx("#ffdb75"), "w": hx("#fff4cf")}
ICE = {"n": hx("#16306e"), "b": hx("#1e50b4"), "m": hx("#4aa8ff"), "l": hx("#a6d8ff"), "w": hx("#ffffff")}

Q_SRC = tuple(META["q_rune"])
E_SRC = tuple(META["e_rune"])
ENEMY_HIT = (META["enemy_feet"][0] - 2, META["enemy_feet"][1] - W(20))
ENEMY_GROUND = (META["enemy_feet"][0] - 4, META["enemy_feet"][1] - W(2))
Q_GROUND = tuple(META["q_feet"])
CHEST = {
    "shaman": (META["shaman_feet"][0], META["shaman_feet"][1] - W(15)),
    "ally": (META["ally_feet"][0], META["ally_feet"][1] - W(14)),
}
Q_SHOTS = [0.15, 1.15, 2.15]
E_TICKS = [0.5, 1.5, 2.5]


# ------------------------------------------------------------------ cizim yardimcilari
def art(rows, pal):
    h = len(rows)
    w = max(len(r) for r in rows)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                px[x, y] = pal[ch]
    return im


_cache = {}


def scaled(im, f=F):
    key = (id(im), round(f, 4))
    if key not in _cache:
        _cache[key] = (im, im.resize((max(1, round(im.width * f)), max(1, round(im.height * f))), Image.NEAREST))
    return _cache[key][1]


def paste(fr, im, x, y, alpha=1.0):
    """im'i (zaten ekran olceginde) fr'ye x,y sol ustten alfa ile karistir (tasan kisimlar kirpilir)."""
    x, y = int(round(x)), int(round(y))
    if alpha <= 0.0:
        return
    if alpha < 1.0:
        im = im.copy()
        im.putalpha(im.getchannel("A").point(lambda v: int(v * alpha)))
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(fr.width, x + im.width), min(fr.height, y + im.height)
    if x1 <= x0 or y1 <= y0:
        return
    crop = im.crop((x0 - x, y0 - y, x1 - x, y1 - y))
    fr.alpha_composite(crop, (x0, y0))


def blit(fr, a, c, alpha=1.0, f=F):
    im = scaled(a, f)
    paste(fr, im, c[0] - im.width / 2, c[1] - im.height / 2, alpha)


def tint(a, rgb, alpha=1.0):
    r, g, b, al = a.split()
    r = r.point(lambda v: int(v * rgb[0]))
    g = g.point(lambda v: int(v * rgb[1]))
    b = b.point(lambda v: int(v * rgb[2]))
    al = al.point(lambda v: int(v * alpha))
    return Image.merge("RGBA", (r, g, b, al))


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def smooth(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


def ball(radius, layers, outline, hl=None, off=(0.0, 0.0)):
    """Kat kat yuvarlak top (sanat pikseli): layers = [(yaricap, renk)...] icten disa; outline = dis hat rengi."""
    n = int(math.ceil(radius)) * 2 + 1
    c = n // 2
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = im.load()
    for y in range(n):
        for x in range(n):
            d = math.hypot(x - c - off[0], y - c - off[1])
            if d > radius:
                continue
            col = outline
            for rr, cc in layers:
                if d <= rr:
                    col = cc
                    break
            px[x, y] = col
    if hl:
        px[c - 1, c - 1] = hl
    return im


def star4(arm, pal_center, pal_arm, pal_tip=None):
    n = arm * 2 + 1
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = im.load()
    for k in range(-arm, arm + 1):
        col = pal_center if k == 0 else (pal_tip if (pal_tip and abs(k) == arm) else pal_arm)
        px[arm + k, arm] = col
        px[arm, arm + k] = col
    return im


class Overlay:
    """Ekran uzayinda sanat pikseli bloklari (isin / bag cizgileri)."""

    def __init__(self, size):
        self.im = Image.new("RGBA", size, (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def block(self, x, y, col, a=1.0):
        c = (col[0], col[1], col[2], int(col[3] * a))
        self.d.rectangle([int(round(x - F / 2)), int(round(y - F / 2)), int(round(x + F / 2)) - 1, int(round(y + F / 2)) - 1], fill=c)


# ------------------------------------------------------------------ A: Kor Topu + Kalkan Kuresi
A_HEAD = [ball(3.8, [(1.3, FIRE["w"]), (2.3, FIRE["y"]), (3.1, FIRE["o"])], FIRE["b"], off=(0.4, -0.4)),
          ball(3.6, [(1.2, FIRE["w"]), (2.2, FIRE["y"]), (3.0, FIRE["o"])], FIRE["b"], off=(-0.3, 0.3))]
A_TAIL = [ball(2.2, [(1.2, FIRE["o"])], FIRE["r"]), ball(1.6, [(0.6, FIRE["r"])], FIRE["r"]), ball(1.0, [], FIRE["b"])]
A_ORB = art([".bbb.", "blwlb", "bllmb", "bmmmb", ".bbb."], ICE)
A_ORB_S = art([".m.", "mlm", ".m."], ICE)
A_STAR = star4(2, ICE["w"], ICE["l"], ICE["m"])
A_STAR_S = star4(1, ICE["w"], ICE["l"])
FIRE_STAR = star4(3, FIRE["w"], FIRE["y"], FIRE["o"])
FIRE_STAR_S = star4(2, FIRE["y"], FIRE["o"])


def flame_tongue(h):
    rows = []
    for i in range(h):
        u = i / max(1, h - 1)
        rows.append("y" if u < 0.34 else ("o" if u < 0.7 else "r"))
    return art(rows, FIRE)


def draw_fire_burst(fr, c, age, big=1.0):
    """Isabet: parlama -> radyal alev dilleri -> dagilan kor (0,3 sn)."""
    if age < 0 or age > 0.32:
        return
    if age < 0.06:
        blit(fr, FIRE_STAR, c)
        return
    k = (age - 0.06) / 0.26
    n = 8
    for i in range(n):
        ang = i * math.tau / n + 0.3
        dist = W(3 + 7 * smooth(k)) * big
        p = (c[0] + math.cos(ang) * dist, c[1] + math.sin(ang) * dist * 0.8)
        if k < 0.55:
            col = FIRE["o"] if k < 0.25 else FIRE["r"]
            blit(fr, art(["x", "x"], {"x": col}), p)
        else:
            blit(fr, art(["x"], {"x": FIRE["b"]}), (p[0], p[1] + W(4) * (k - 0.55)), 1.0 - (k - 0.55) / 0.45)
    if k < 0.4:
        blit(fr, ball(1.6, [(0.7, FIRE["y"])], FIRE["o"]), c, 1.0 - k / 0.4)


def variant_A(fr, t):
    q_A(fr, t)
    e_A(fr, t)


def q_A(fr, t):
    # Q: duz ucan kor topu
    for t0 in Q_SHOTS + [Q_SHOTS[-1] - DUR]:
        travel = 0.32
        u = (t - t0) / travel
        if 0 <= u <= 1:
            p = lerp(Q_SRC, ENEMY_HIT, u)
            d = (ENEMY_HIT[0] - Q_SRC[0], ENEMY_HIT[1] - Q_SRC[1])
            ln = math.hypot(*d)
            dx, dy = d[0] / ln, d[1] / ln
            for k, (tail, gap, a) in enumerate(zip(A_TAIL, (4.5, 7.5, 10.0), (1.0, 0.85, 0.7))):
                back = min(gap * F, u * ln)
                blit(fr, tail, (p[0] - dx * back, p[1] - dy * back), a)
            blit(fr, A_HEAD[int(t * 15) % 2], p)
        if 0 <= t - t0 < 0.08:
            blit(fr, FIRE_STAR_S, Q_SRC)
        draw_fire_burst(fr, ENEMY_HIT, t - t0 - travel)


def e_A(fr, t):
    # E: tikte taştan kavisle ucan kure
    for t0 in E_TICKS + [E_TICKS[-1] - DUR]:
        for who in ("shaman", "ally"):
            dst = CHEST[who]
            travel = 0.55
            u = (t - t0) / travel
            if 0 <= u <= 1:
                e = smooth(u)
                p = lerp(E_SRC, dst, e)
                p = (p[0], p[1] - W(16) * 4 * e * (1 - e))
                for k, (b, a) in enumerate(((0.06, 0.8), (0.12, 0.5))):
                    eb = smooth(max(0.0, u - b))
                    q = lerp(E_SRC, dst, eb)
                    q = (q[0], q[1] - W(16) * 4 * eb * (1 - eb))
                    blit(fr, A_ORB_S, q, a if u > b else 0)
                blit(fr, A_ORB, p)
            age = t - t0 - travel
            if 0 <= age < 0.3:
                blit(fr, A_STAR if age < 0.12 else A_STAR_S, (dst[0], dst[1] - W(2) * age / 0.3), 1.0 if age < 0.15 else 1 - (age - 0.15) / 0.15)
        if 0 <= t - t0 < 0.1:
            blit(fr, A_STAR_S, E_SRC)


# ------------------------------------------------------------------ B: Run Mermisi + Run Bagi
B_RUNE = art([
    ".rrr...",
    ".ryr.r.",
    ".ryrryr",
    ".ryyyyr",
    ".ryrryr",
    "rryyyr.",
    "ryyyyr.",
    "rrrrr..",
], FIRE)
B_RUNE_HOT = art([
    ".ooo...",
    ".owo.o.",
    ".owooyo",
    ".owwwwo",
    ".owooyo",
    "oowwwo.",
    "owwwwo.",
    "ooooo..",
], FIRE)
B_DIAMOND = art([".l.", "lwl", ".l."], ICE)

B_ASH = [art(["xx", "xx"], {"x": FIRE["r"]}), art(["x"], {"x": FIRE["b"]})]
B_NODE = art(["ll", "ll"], ICE)


def draw_line_blocks(ov, a, b, col, alpha, skip_ends=0.0):
    ln = math.hypot(b[0] - a[0], b[1] - a[1])
    n = max(1, int(ln / F))
    for i in range(n + 1):
        u = i / n
        if u < skip_ends or u > 1 - skip_ends:
            continue
        p = lerp(a, b, u)
        ov.block(p[0], p[1], col, alpha)


def variant_B(fr, t, rng):
    # Q: kizgin run ucar, arkasindan kul dokulur
    for t0 in Q_SHOTS + [Q_SHOTS[-1] - DUR]:
        travel = 0.36
        u = (t - t0) / travel
        if 0 <= u <= 1:
            p = lerp(Q_SRC, ENEMY_HIT, u)
            p = (p[0], p[1] - W(3) * math.sin(u * math.pi))
            # kul: gecmis konumlardan dusen kor kirintilari (belirli, zamana bagli)
            for j in range(4):
                ub = u - (j + 1) * 0.09
                if ub < 0:
                    continue
                q = lerp(Q_SRC, ENEMY_HIT, ub)
                age = (u - ub) * travel
                q = (q[0], q[1] - W(3) * math.sin(ub * math.pi) + W(40) * age * age + W(5) * age)
                col = FIRE["o"] if j < 1 else (FIRE["r"] if j < 3 else FIRE["b"])
                blit(fr, B_ASH[col == FIRE["b"]], q, 1.0 - j / 5)

            blit(fr, B_RUNE_HOT if int(t * 12) % 3 == 0 else B_RUNE, p)
        if 0 <= t - t0 < 0.1:
            blit(fr, FIRE_STAR_S, Q_SRC)
        age = t - t0 - travel
        if 0 <= age < 0.3:
            k = age / 0.3
            if age < 0.05:
                blit(fr, FIRE_STAR, ENEMY_HIT)
            # run dort parcaya ayrilir
            for i, (ox, oy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
                piece = B_RUNE.crop((0 if ox < 0 else 3, 0 if oy < 0 else 4, 4 if ox < 0 else 7, 4 if oy < 0 else 8))
                q = (ENEMY_HIT[0] + ox * W(2 + 8 * k), ENEMY_HIT[1] + oy * W(2 + 5 * k) + W(10) * k * k)
                blit(fr, piece, q, 1.0 - k)
    # E: surekli gergin bag + kayan run elmaslari
    ov = Overlay(fr.size)
    pulse = 0.5 + 0.5 * math.sin(t * 2.4)
    for who in ("shaman", "ally"):
        dst = CHEST[who]
        draw_line_blocks(ov, E_SRC, dst, ICE["m"], 0.5 + 0.2 * pulse)
    fr.alpha_composite(ov.im)
    for who in ("shaman", "ally"):
        dst = CHEST[who]
        ln = math.hypot(dst[0] - E_SRC[0], dst[1] - E_SRC[1])
        spacing = W(26)
        speed = W(44)
        off = (t * speed) % spacing
        s_ = off
        while s_ < ln:
            u = s_ / ln
            a = smooth(u / 0.12) * smooth((1 - u) / 0.12)
            blit(fr, B_DIAMOND, lerp(E_SRC, dst, u), a)
            s_ += spacing
        blit(fr, B_NODE, dst, 0.6 + 0.3 * pulse)
    blit(fr, B_NODE, E_SRC, 0.6 + 0.3 * pulse)


# ------------------------------------------------------------------ C: Alev Yayi + Isik Seridi
C_HEAD = [ball(4.2, [(1.4, FIRE["w"]), (2.5, FIRE["y"]), (3.4, FIRE["o"])], FIRE["b"], off=(0.5, -0.5)),
          ball(4.0, [(1.3, FIRE["w"]), (2.4, FIRE["y"]), (3.3, FIRE["o"])], FIRE["b"], off=(-0.4, -0.2))]
C_SHADOW = [art(["." + "x" * (w - 2) + ".", "x" * w, "." + "x" * (w - 2) + "."], {"x": (0, 0, 0, 70)}) for w in (5, 7, 9)]
C_FLAME = [art(["..y..", "..o..", ".oyo.", ".oyo.", "rooor", "rrorr", ".rrr."], FIRE),
           art(["...y.", "..oo.", ".oyo.", ".oyo.", "royor", "rroor", ".rrr."], FIRE)]




def variant_C(fr, t):
    for t0 in Q_SHOTS + [Q_SHOTS[-1] - DUR]:
        travel = 0.6
        u = (t - t0) / travel
        height = W(40)
        if 0 <= u <= 1:
            base = lerp(Q_SRC, ENEMY_GROUND, u)
            h = height * 4 * u * (1 - u)
            p = (base[0], base[1] - h)
            g = lerp(Q_GROUND, ENEMY_GROUND, u)
            sh = C_SHADOW[2 if h < W(12) else (1 if h < W(28) else 0)]
            blit(fr, sh, g)
            # yon: turev
            du = 0.02
            b2 = lerp(Q_SRC, ENEMY_GROUND, min(1, u + du))
            p2 = (b2[0], b2[1] - height * 4 * (u + du) * (1 - u - du))
            vx, vy = p2[0] - p[0], p2[1] - p[1]
            vl = math.hypot(vx, vy) or 1
            for k, (tail, gap, a) in enumerate(zip(A_TAIL, (5.0, 8.5, 11.5), (1.0, 0.85, 0.65))):
                blit(fr, tail, (p[0] - vx / vl * gap * F, p[1] - vy / vl * gap * F), a if u * travel > k * 0.04 else 0)
            blit(fr, C_HEAD[int(t * 15) % 2], p)
        if 0 <= t - t0 < 0.1:
            blit(fr, FIRE_STAR_S, Q_SRC)
        age = t - t0 - travel
        if 0 <= age < 0.6:
            if age < 0.06:
                blit(fr, FIRE_STAR, (ENEMY_GROUND[0], ENEMY_GROUND[1] - W(3)))
            # yer atesi: elips uzerinde 5 alevcik, buyur - titrer - batar
            grow = smooth(age / 0.1)
            sink = smooth((age - 0.4) / 0.2)
            for i in range(5):
                ang = i * math.tau / 5 + 0.6
                q = (ENEMY_GROUND[0] + math.cos(ang) * W(9), ENEMY_GROUND[1] + math.sin(ang) * W(4))
                fl = C_FLAME[(int(t * 10) + i) % 2]
                hh = max(1, round(fl.height * grow * (1 - sink)))
                part = fl.crop((0, 0, fl.width, fl.height)).resize((fl.width, hh), Image.NEAREST) if hh != fl.height else fl
                im = scaled(part)
                paste(fr, im, q[0] - im.width / 2, q[1] - im.height, 1.0)
            for i in range(3):
                k = age / 0.6
                q = (ENEMY_GROUND[0] + (i - 1) * W(5), ENEMY_GROUND[1] - W(4) - W(22) * k)
                blit(fr, art(["x"], {"x": FIRE["o"] if k < 0.5 else FIRE["r"]}), q, 1.0 - k)
    # E: surekli ISIK SERIDI: tastan muttefige kavisli, dalgalanarak akan 2 tonlu serit (dalga muttefige dogru yurur)
    ov = Overlay(fr.size)
    for who in ("shaman", "ally"):
        dst = CHEST[who]
        dx, dy = dst[0] - E_SRC[0], dst[1] - E_SRC[1]
        ln = math.hypot(dx, dy)
        n = max(2, int(ln / F))
        for i in range(n + 1):
            u = i / n
            p = lerp(E_SRC, dst, u)
            arc = W(12) * 4 * u * (1 - u)
            # yerel teget -> dik
            u2 = min(1.0, u + 1.0 / n)
            p2 = lerp(E_SRC, dst, u2)
            a2 = W(12) * 4 * u2 * (1 - u2)
            tx, ty = p2[0] - p[0], (p2[1] - a2) - (p[1] - arc)
            tl = math.hypot(tx, ty) or 1
            nx, ny = -ty / tl, tx / tl
            phase = u * ln / W(26) * math.tau - t * math.tau * 2.2
            wave = math.sin(phase) * W(2.2) * math.sin(u * math.pi)
            c = (p[0] + nx * wave, p[1] - arc + ny * wave)
            fade = smooth(u / 0.1) * smooth((1 - u) / 0.1)
            crest = math.cos(phase) > 0.75
            ov.block(c[0], c[1] + F, ICE["b"], 0.55 * fade)
            ov.block(c[0], c[1], ICE["w"] if crest else ICE["l"], 0.85 * fade)
    fr.alpha_composite(ov.im)


# ------------------------------------------------------------------ D: Isik Mizragi + Mavi Hale
D_STAR = star4(4, FIRE["w"], FIRE["y"], FIRE["o"])
D_GLINT = star4(2, ICE["w"], ICE["l"], ICE["m"])


def load_mask(name, rect, feet):
    m = Image.open(os.path.join(BG_DIR, name)).convert("RGB")
    w, h = m.size
    px = m.load()
    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    x0, y0, rw, rh = rect
    for y in range(max(0, int(y0)), min(h, int(y0 + rh))):
        if y > feet[1] - 2:
            continue
        for x in range(max(0, int(x0)), min(w, int(x0 + rw))):
            r, g, b = px[x, y]
            bg_like = g < 70 and abs(r - b) < 50 and r > 60
            if not bg_like:
                mp[x, y] = 255
    return mask


def outline_from(mask, width=2):
    from PIL import ImageFilter
    dil = mask.filter(ImageFilter.MaxFilter(width * 2 + 1))
    ring = Image.eval(Image.merge("L", [dil]), lambda v: v)
    ring = Image.composite(Image.new("L", mask.size, 0), ring, mask)  # maskenin icini sil
    return ring


D_OUTLINES = {}


def d_outline(who):
    if who not in D_OUTLINES:
        if who == "shaman":
            mk = load_mask("maske_shaman.png", META["shaman_rect"], META["shaman_feet"])
        else:
            mk = load_mask("maske_elara.png", META["ally_rect"], META["ally_feet"])
        D_OUTLINES[who] = outline_from(mk, 2)
    return D_OUTLINES[who]


def variant_D(fr, t):
    for t0 in Q_SHOTS + [Q_SHOTS[-1] - DUR]:
        age = t - t0
        if 0 <= age < 0.36:
            d = (ENEMY_HIT[0] - Q_SRC[0], ENEMY_HIT[1] - Q_SRC[1])
            ln = math.hypot(*d)
            dx, dy = d[0] / ln, d[1] / ln
            nx, ny = -dy, dx
            front = min(1.0, age / 0.05)
            if age < 0.14:
                widths = [(2, FIRE["r"], 0.9), (1, FIRE["o"], 1.0), (0, FIRE["y"], 1.0)]
            elif age < 0.22:
                widths = [(1, FIRE["r"], 1.0), (0, FIRE["y"], 1.0)]
            else:
                widths = [(0, FIRE["o"], 1.0 - (age - 0.22) / 0.14)]
            ov = Overlay(fr.size)
            n = int(ln / F)
            for i in range(n + 1):
                u = i / n
                if u > front:
                    break
                taper = min(1.0, u / 0.12)
                p = (Q_SRC[0] + dx * u * ln, Q_SRC[1] + dy * u * ln)
                for wdt, col, a in widths:
                    ww = int(round(wdt * taper))
                    for s_ in range(-ww, ww + 1):
                        if abs(s_) != ww and wdt > 0:
                            continue
                        ov.block(p[0] + nx * s_ * F, p[1] + ny * s_ * F, col, a)
                if widths[-1][0] == 0 and age < 0.14:
                    ov.block(p[0], p[1], FIRE["w"], 1.0)
            fr.alpha_composite(ov.im)
            if age < 0.08:
                blit(fr, FIRE_STAR_S, Q_SRC)
            if 0.05 <= age < 0.22:
                blit(fr, D_STAR if age < 0.13 else FIRE_STAR_S, ENEMY_HIT)
            if 0.08 <= age < 0.32:
                k = (age - 0.08) / 0.24
                for i in range(4):
                    ang = math.pi / 4 + i * math.pi / 2
                    q = (ENEMY_HIT[0] + math.cos(ang) * W(4 + 9 * k), ENEMY_HIT[1] + math.sin(ang) * W(3 + 7 * k))
                    blit(fr, art(["x"], {"x": FIRE["o"] if k < 0.5 else FIRE["r"]}), q, 1.0 - k)
    # E: surekli mavi dis hat + tikte omuzda parilti, tasta kucuk parlama
    pulse = 0.5 + 0.5 * math.sin(t * math.tau / 1.6)
    for who in ("shaman", "ally"):
        ring = d_outline(who)
        a = 0.45 + 0.35 * pulse
        col = Image.new("RGBA", fr.size, (108, 196, 255, 255))
        col.putalpha(ring.point(lambda v: int(v * a)))
        fr.alpha_composite(col)
    for t0 in E_TICKS + [E_TICKS[-1] - DUR]:
        age = t - t0
        if 0 <= age < 0.45:
            a = smooth(age / 0.1) * (1 - smooth((age - 0.15) / 0.3))
            blit(fr, D_GLINT, E_SRC, a)
            for who in ("shaman", "ally"):
                dst = CHEST[who]
                blit(fr, D_GLINT, (dst[0] + W(6), dst[1] - W(7) - W(3) * age), a)


# ------------------------------------------------------------------ yazi + birlestirme
def label(fr, text):
    try:
        fnt = ImageFont.truetype(FONT, 32)
    except OSError:
        fnt = ImageFont.load_default()
    d = ImageDraw.Draw(fr)
    tw = d.textlength(text, font=fnt)
    d.rectangle([8, 6, 8 + tw + 16, 6 + 30], fill=(42, 30, 20, 220))
    d.text((16, 6), text, font=fnt, fill=(240, 226, 196, 255))


NAMES = {
    "suan": "ŞU AN",
    "A": "A - Kor Topu + Kalkan Küresi (tik)",
    "B": "B - Rün Mermisi + Rün Bağı (sürekli)",
    "C": "C - Alev Yayı + Işık Şeridi (sürekli)",
    "D": "D - Işık Mızrağı + Mavi Hale (sürekli)",
}


def render(variant, bgs):
    frames = []
    for i in range(NFR):
        t = i / FPS
        fr = bgs[i % len(bgs)].copy()
        if variant == "A":
            variant_A(fr, t)
        elif variant == "B":
            variant_B(fr, t, None)
        elif variant == "C":
            variant_C(fr, t)
        elif variant == "D":
            variant_D(fr, t)
        label(fr, NAMES[variant])
        frames.append(fr)
    return frames


def load_seq(d):
    files = sorted(f for f in os.listdir(d) if f.startswith("kare_"))
    return [Image.open(os.path.join(d, f)).convert("RGBA") for f in files]


def save_gif(frames, path):
    rgb = [f.convert("RGB") for f in frames]
    rgb[0].save(path, save_all=True, append_images=rgb[1:], duration=int(1000 / FPS), loop=0)
    print(path, os.path.getsize(path) // 1024, "KB")


def main():
    bgs = load_seq(BG_DIR)
    seqs = {}
    if os.path.isdir(NOW_DIR):
        now = load_seq(NOW_DIR)[:NFR]
        seqs["suan"] = []
        for fr in now:
            fr = fr.copy()
            label(fr, NAMES["suan"])
            seqs["suan"].append(fr)
    for v in "ABCD":
        seqs[v] = render(v, bgs)
        save_gif(seqs[v], os.path.join(OUT, "%s.gif" % v))
    order = [k for k in ("suan", "A", "B", "C", "D") if k in seqs]
    w, h = bgs[0].size
    stacked = []
    n = min(len(seqs[k]) for k in order)
    for i in range(n):
        im = Image.new("RGBA", (w, (h + 4) * len(order) - 4), (20, 16, 12, 255))
        for j, k in enumerate(order):
            im.paste(seqs[k][i], (0, j * (h + 4)))
        stacked.append(im)
    save_gif(stacked, os.path.join(OUT, "karsilastirma.gif"))
    # ozet: her varyanttan iki an (Q ucarken + isabet / E gorunur), alt alta
    picks = {"suan": (5, 12), "A": (6, 12), "B": (6, 12), "C": (8, 16), "D": (4, 15)}
    rows = []
    for k in order:
        a, b = picks[k]
        rows.append((seqs[k][min(a, n - 1)], seqs[k][min(b, n - 1)]))
    sheet = Image.new("RGBA", (w * 2 + 6, (h + 6) * len(rows)), (20, 16, 12, 255))
    for j, (a, b) in enumerate(rows):
        sheet.paste(a, (0, j * (h + 6)))
        sheet.paste(b, (w + 6, j * (h + 6)))
    sheet.convert("RGB").save(os.path.join(OUT, "ozet.png"))
    print("ozet:", os.path.join(OUT, "ozet.png"))


# ------------------------------------------------------------------ SECIM (madde 562 ek): Q = A + E = C, bag kalkana baglı
# Kullanici: "ates topu A. Kalkan C aktifken karakterlerin kendi kalkan yenilenme efekti aktif olsa ve bu bag kalkana bagli olsa".
# Arka plan yakala.ps1 -Mode kalkan: iki karakterin KENDI kalkan yenilenme baloncugu acik (Shaman Standart = limon, Elara Kale = mavi;
# baloncuk rengi kalkan turune gore, ShieldEnchantDefs.EFFECT_OF). Serit tasta E mavisiyle baslar, son ucte birde o karakterin kalkan
# rengine doner, baloncugun TASA BAKAN yuzeyine baglanir; degdigi yerde yuzeyde parlayan kisa yay, dalga tepesi varinca parlar.
K_DIR = os.path.join(OUT, "yakala_kalkan")
BUBBLE_PAL = {  # kalkan turunun baloncuk sanatindan (assets/fx/shield_bubble*/bubble_sheet.png)
    "shield_standart": {"core": hx("#89ff39"), "edge": hx("#5bff39"), "crest": hx("#e2ff39")},
    "shield_kale": {"core": hx("#39e7ff"), "edge": hx("#39abff"), "crest": hx("#dbeaff")},
}
BUBBLE_TYPE = {"shaman": "shield_standart", "ally": "shield_kale"}


def mix(a, b, k):
    return tuple(int(round(a[i] + (b[i] - a[i]) * k)) for i in range(4))


def bubble_geo(meta, who):
    x, y, w, h = meta["shaman_bubble" if who == "shaman" else "ally_bubble"]
    return (x + w / 2, y + h / 2), w * 0.46


def e_C_bubble(fr, t, meta):
    ov = Overlay(fr.size)
    for who in ("shaman", "ally"):
        pal = BUBBLE_PAL[BUBBLE_TYPE[who]]
        c, R = bubble_geo(meta, who)
        vx, vy = E_SRC[0] - c[0], E_SRC[1] - c[1]
        vl = math.hypot(vx, vy) or 1
        th0 = math.atan2(vy, vx)
        dst = (c[0] + vx / vl * R, c[1] + vy / vl * R)
        dx, dy = dst[0] - E_SRC[0], dst[1] - E_SRC[1]
        ln = math.hypot(dx, dy)
        n = max(2, int(ln / F))
        arc_h = W(10)
        end_phase = 0.0
        for i in range(n + 1):
            u = i / n
            p = lerp(E_SRC, dst, u)
            arc = arc_h * 4 * u * (1 - u)
            u2 = min(1.0, u + 1.0 / n)
            p2 = lerp(E_SRC, dst, u2)
            a2 = arc_h * 4 * u2 * (1 - u2)
            tx, ty = p2[0] - p[0], (p2[1] - a2) - (p[1] - arc)
            tl = math.hypot(tx, ty) or 1
            nx, ny = -ty / tl, tx / tl
            phase = u * ln / W(26) * math.tau - t * math.tau * 2.2
            end_phase = phase
            wave = math.sin(phase) * W(2.0) * math.sin(u * math.pi)
            q = (p[0] + nx * wave, p[1] - arc + ny * wave)
            fade = smooth(u / 0.1)
            k = smooth((u - 0.6) / 0.4)  # son ucte birde kalkanin rengine
            crest = math.cos(phase) > 0.75
            edge = mix(ICE["b"], pal["edge"], k)
            core = mix(ICE["w"] if crest else ICE["l"], pal["crest"] if crest else pal["core"], k)
            ov.block(q[0], q[1] + F, edge, 0.55 * fade)
            ov.block(q[0], q[1], core, 0.85 * fade)
        # baloncuk yuzeyinde parlayan yay: degme noktasindan iki yana sonen, dalga tepesi varinca parlar
        glow = 0.55 + 0.45 * max(0.0, math.cos(end_phase))
        span = math.radians(42)
        steps = max(4, int(R * span * 2 / F))
        for j in range(steps + 1):
            a = th0 - span + 2 * span * j / steps
            off = abs(a - th0) / span
            q = (c[0] + math.cos(a) * R, c[1] + math.sin(a) * R)
            hot = mix(pal["crest"], ICE["w"], 0.65)  # degme noktasi baloncugun kenarindan ayrissin
            ov.block(q[0], q[1], hot if off < 0.3 else pal["crest"], min(1.0, 1.2 * glow * max(0.0, 1 - off) ** 1.3))
            if off < 0.6:  # ic sira: yuzeye yayilan isik
                qi = (c[0] + math.cos(a) * (R - F), c[1] + math.sin(a) * (R - F))
                ov.block(qi[0], qi[1], pal["core"], 0.45 * glow * (1 - off / 0.6))
    fr.alpha_composite(ov.im)


def render_secim():
    meta_k = json.load(open(os.path.join(K_DIR, "meta.json"), encoding="utf-8"))
    bg_k = load_seq(K_DIR)
    bg_b = load_seq(BG_DIR)
    rows = {"gogus": [], "kalkan": []}
    for i in range(NFR):
        t = i / FPS
        a = bg_b[i % len(bg_b)].copy()
        q_A(a, t)
        variant_C_e_only(a, t)
        label(a, "Q: A Kor Topu  +  E: C Işık Şeridi (göğse)")
        rows["gogus"].append(a)
        b = bg_k[i % len(bg_k)].copy()
        q_A(b, t)
        e_C_bubble(b, t, meta_k)
        label(b, "Q: A Kor Topu  +  E: C Işık Şeridi, kalkana bağlı")
        rows["kalkan"].append(b)
    save_gif(rows["kalkan"], os.path.join(OUT, "secim_A_C_kalkan.gif"))
    w, h = bg_b[0].size
    stacked = []
    for i in range(NFR):
        im = Image.new("RGBA", (w, h * 2 + 4), (20, 16, 12, 255))
        im.paste(rows["gogus"][i], (0, 0))
        im.paste(rows["kalkan"][i], (0, h + 4))
        stacked.append(im)
    save_gif(stacked, os.path.join(OUT, "secim_karsilastirma.gif"))
    # yakin: E bolgesi x2
    zoom = []
    for fr in rows["kalkan"]:
        c = fr.crop((470, 40, 1000, 236))
        zoom.append(c.resize((c.width * 2, c.height * 2), Image.NEAREST))
    save_gif(zoom, os.path.join(OUT, "secim_yakin.gif"))


def variant_C_e_only(fr, t):
    """C'nin yalniz E kismi (Q'su olmadan): variant_C'yi Q atislari bos kalacak bir zamanda cagirmak yerine ayri cizer."""
    global Q_SHOTS
    saved = Q_SHOTS
    Q_SHOTS = [-99.0]
    try:
        variant_C(fr, t)
    finally:
        Q_SHOTS = saved


# ------------------------------------------------------------------ DALGA prototipleri (madde 562 ek 2)
# Kullanici: "kalkan gonderirkenki dalganin gorunusunun daha iyi gorunmesi icin 4 prototip hazirla". Ayni sahne (baloncuklar acik),
# ayni yol (tastan baloncugun tasa bakan yuzune kavis), ayni renk gecisi (E mavisi -> kalkan rengi) ve ayni yuzey yayi; YALNIZ seridin
# kendisi degisir. Su anki (C): 1 px dalgali cizgi + alt golge, tepede beyaz piksel -> ince/merdivenli/silik.
#   A Kivrilan Kurdele: 3 px bant, kendi ekseninde doner (yuz/kenar: genislik |cos|), ust kenar parlak alt kenar koyu, akisla ilerler
#   B Isik Atimi     : soluk 1 px hat + uzerinde kayan parlak atimlar (bas 2 px + sonen kuyruk); atim varinca yuzey yayi parlar
#   C Cift Sarmal    : iki ince iplik (acik + koyu) birbirine dolanir, onde olan ustte, kesisimde parlama
#   D Isik Tulu      : yumusak genis tul (disari dogru 3 alfa basamagi, dither yok) + parlak 1 px orta cizgi, yavas dalga
DALGA_NAMES = {
    "suan": "ŞU AN (C şeridi)",
    "A": "A - Kıvrılan Kurdele",
    "B": "B - Işık Atımı",
    "C": "C - Çift Sarmal",
    "D": "D - Işık Tülü",
}


def ribbon_path(meta, who):
    """Tastan baloncugun tasa bakan yuzune kavisli yol: [(u, nokta, normal)], uzunluk, baloncuk merkezi/yaricap/aci."""
    c, R = bubble_geo(meta, who)
    vx, vy = E_SRC[0] - c[0], E_SRC[1] - c[1]
    vl = math.hypot(vx, vy) or 1
    th0 = math.atan2(vy, vx)
    dst = (c[0] + vx / vl * R, c[1] + vy / vl * R)
    ln = math.hypot(dst[0] - E_SRC[0], dst[1] - E_SRC[1])
    n = max(2, int(ln / F))
    arc_h = W(10)
    pts = []
    for i in range(n + 1):
        u = i / n
        p = lerp(E_SRC, dst, u)
        arc = arc_h * 4 * u * (1 - u)
        u2 = min(1.0, u + 1.0 / n)
        p2 = lerp(E_SRC, dst, u2)
        a2 = arc_h * 4 * u2 * (1 - u2)
        tx, ty = p2[0] - p[0], (p2[1] - a2) - (p[1] - arc)
        tl = math.hypot(tx, ty) or 1
        pts.append((u, (p[0], p[1] - arc), (-ty / tl, tx / tl)))
    return pts, ln, c, R, th0


def col_at(pal, u, base, target):
    return mix(base, pal[target], smooth((u - 0.6) / 0.4))


def surface_arc(ov, pal, c, R, th0, glow):
    span = math.radians(42)
    steps = max(4, int(R * span * 2 / F))
    for j in range(steps + 1):
        a = th0 - span + 2 * span * j / steps
        off = abs(a - th0) / span
        q = (c[0] + math.cos(a) * R, c[1] + math.sin(a) * R)
        hot = mix(pal["crest"], ICE["w"], 0.65)
        ov.block(q[0], q[1], hot if off < 0.3 else pal["crest"], min(1.0, 1.2 * glow * max(0.0, 1 - off) ** 1.3))
        if off < 0.6:
            qi = (c[0] + math.cos(a) * (R - F), c[1] + math.sin(a) * (R - F))
            ov.block(qi[0], qi[1], pal["core"], 0.45 * glow * (1 - off / 0.6))


def _wave_A(ov, pal, pts, ln, t):
    # Kivrilan kurdele: genislik |cos| ile 1..3 px, ust kenar parlak, alt kenar koyu; donme fazi akisla yurur
    for u, p, nrm in pts:
        ph = u * ln / W(22) * math.tau - t * math.tau * 1.6
        wave = math.sin(ph * 0.5) * W(1.2) * math.sin(u * math.pi)
        q = (p[0] + nrm[0] * wave, p[1] + nrm[1] * wave)
        face = abs(math.cos(ph))
        fade = smooth(u / 0.08)
        if face < 0.35:  # kenardan gorunus: tek parlak piksel
            ov.block(q[0], q[1], col_at(pal, u, ICE["w"], "crest"), 0.95 * fade)
        else:
            ov.block(q[0] - nrm[0] * F, q[1] - nrm[1] * F, col_at(pal, u, ICE["l"], "crest"), 0.9 * fade)
            ov.block(q[0], q[1], col_at(pal, u, ICE["m"], "core"), 0.85 * fade)
            ov.block(q[0] + nrm[0] * F, q[1] + nrm[1] * F, col_at(pal, u, ICE["b"], "edge"), 0.75 * fade)
    return 0.55 + 0.45 * abs(math.cos(ln / W(22) * math.tau - t * math.tau * 1.6))


def _wave_B(ov, pal, pts, ln, t):
    # Isik atimi: soluk hat + kayan atimlar
    for u, p, nrm in pts:
        ov.block(p[0], p[1], col_at(pal, u, ICE["m"], "core"), 0.38 * smooth(u / 0.08))
    spacing = W(34)
    speed = W(80)
    tail = 9
    nearest_end = 99.0
    s_ = (t * speed) % spacing
    while s_ < ln + tail * F:
        head_u = s_ / ln
        for k in range(tail, -1, -1):
            uu = (s_ - k * F) / ln
            if not (0.0 <= uu <= 1.0):
                continue
            idx = min(len(pts) - 1, int(uu * (len(pts) - 1)))
            _u, p, nrm = pts[idx]
            a = (1.0 - (k / (tail + 1)) ** 1.6) * smooth(uu / 0.08)
            base = ICE["w"] if k == 0 else (ICE["l"] if k < 5 else ICE["m"])
            ov.block(p[0], p[1], col_at(pal, uu, base, "crest" if k < 5 else "core"), a)
            if k <= 3:  # bas + boyun 3 px kalin
                for sg in (-1, 1):
                    ov.block(p[0] + nrm[0] * sg * F, p[1] + nrm[1] * sg * F, col_at(pal, uu, ICE["l"] if k == 0 else ICE["m"], "crest" if k == 0 else "core"), a * (0.85 if k == 0 else 0.6))
        if head_u <= 1.0:
            nearest_end = min(nearest_end, (1.0 - head_u) * ln / S)
        s_ += spacing
    return 0.45 + 0.55 * max(0.0, 1.0 - nearest_end / 8.0)


def _wave_C(ov, pal, pts, ln, t):
    # Cift sarmal: iki iplik, onde olan ustte, kesisimde parlama
    back, front = [], []
    for u, p, nrm in pts:
        ph = u * ln / W(18) * math.tau - t * math.tau * 1.4
        amp = W(2.6) * math.sin(u * math.pi) ** 0.7
        fade = smooth(u / 0.08)
        for sgn, base, tgt in ((1, ICE["l"], "crest"), (-1, ICE["b"], "edge")):
            o = math.sin(ph) * amp * sgn
            q = (p[0] + nrm[0] * o, p[1] + nrm[1] * o)
            depth = math.cos(ph) * sgn
            cross = abs(math.sin(ph)) < 0.22 and amp > W(1)
            colk = col_at(pal, u, ICE["w"], "crest") if cross else col_at(pal, u, base, tgt)
            (front if depth > 0 else back).append((q, colk, fade * (0.95 if depth > 0 else 0.6)))
    for q, colk, a in back + front:
        ov.block(q[0], q[1], colk, a)
    return 0.55 + 0.45 * abs(math.sin(ln / W(18) * math.tau - t * math.tau * 1.4))


D_LAYERS = {  # (yari genislik efekt pikseli, taban renk, hedef rol, alfa) - disaridan ice
    "D": ((3, ICE["m"], "core", 0.14), (2, ICE["m"], "core", 0.26), (1, ICE["l"], "crest", 0.42)),
    "D2": ((2, ICE["m"], "core", 0.18), (1, ICE["l"], "crest", 0.38)),  # biraz ince: 2 basamak (5 px)
    "D3": ((1, ICE["l"], "crest", 0.34),),  # daha ince: tek basamak (3 px)
}


def _wave_D(ov, pal, pts, ln, t, layers=None):
    # Isik tulu: 3 alfa basamagi disaridan ice, parlak orta cizgi, yavas dalga
    def at(u, p, nrm):
        ph = u * ln / W(34) * math.tau - t * math.tau * 1.0
        wave = math.sin(ph) * W(1.4) * math.sin(u * math.pi)
        return ph, (p[0] + nrm[0] * wave, p[1] + nrm[1] * wave)

    for half, base, tgt, alpha in (layers or D_LAYERS["D"]):
        for u, p, nrm in pts:
            _ph, q = at(u, p, nrm)
            w = max(0, round(half * math.sin(u * math.pi) ** 0.5))
            fade = smooth(u / 0.08)
            for k in range(-w, w + 1):
                ov.block(q[0] + nrm[0] * k * F, q[1] + nrm[1] * k * F, col_at(pal, u, base, tgt), alpha * fade)
    for u, p, nrm in pts:
        ph, q = at(u, p, nrm)
        bright = 0.5 + 0.5 * math.cos(ph)
        ov.block(q[0], q[1], col_at(pal, u, ICE["w"] if bright > 0.8 else ICE["l"], "crest"), (0.7 + 0.3 * bright) * smooth(u / 0.08))
    return 0.6 + 0.4 * (0.5 + 0.5 * math.cos(ln / W(34) * math.tau - t * math.tau * 1.0))


WAVES = {"A": _wave_A, "B": _wave_B, "C": _wave_C, "D": _wave_D,
         "D2": lambda ov, pal, pts, ln, t: _wave_D(ov, pal, pts, ln, t, D_LAYERS["D2"]),
         "D3": lambda ov, pal, pts, ln, t: _wave_D(ov, pal, pts, ln, t, D_LAYERS["D3"])}
DALGA_NAMES["D2"] = "D - Işık Tülü, biraz ince (5 px)"
DALGA_NAMES["D3"] = "D - Işık Tülü, daha ince (3 px)"


def e_wave(fr, t, meta, style):
    ov = Overlay(fr.size)
    for who in ("shaman", "ally"):
        pal = BUBBLE_PAL[BUBBLE_TYPE[who]]
        pts, ln, c, R, th0 = ribbon_path(meta, who)
        glow = WAVES[style](ov, pal, pts, ln, t)
        surface_arc(ov, pal, c, R, th0, glow)
    fr.alpha_composite(ov.im)


def render_dalga():
    meta_k = json.load(open(os.path.join(K_DIR, "meta.json"), encoding="utf-8"))
    bg_k = load_seq(K_DIR)
    crop = (470, 40, 1000, 236)
    full = {}
    for key in ("suan", "A", "B", "C", "D"):
        seq = []
        for i in range(NFR):
            t = i / FPS
            fr = bg_k[i % len(bg_k)].copy()
            q_A(fr, t)
            if key == "suan":
                e_C_bubble(fr, t, meta_k)
            else:
                e_wave(fr, t, meta_k, key)
            seq.append(fr.crop(crop))
        full[key] = seq
        if key != "suan":
            big = []
            for c in seq:
                c2 = c.resize((c.width * 2, c.height * 2), Image.NEAREST)
                label(c2, DALGA_NAMES[key])
                big.append(c2)
            save_gif(big, os.path.join(OUT, "dalga_%s.gif" % key))
    zoom = 1.5
    small = {}
    for key, seq in full.items():
        out = []
        for c in seq:
            c2 = c.resize((round(c.width * zoom), round(c.height * zoom)), Image.NEAREST)
            label(c2, DALGA_NAMES[key])
            out.append(c2)
        small[key] = out
    w, h = small["A"][0].size
    grid = []
    for i in range(NFR):
        im = Image.new("RGBA", (w * 2 + 6, (h + 6) * 3 - 6), (20, 16, 12, 255))
        im.paste(small["suan"][i], ((w + 6) // 2, 0))
        for j, k in enumerate("ABCD"):
            im.paste(small[k][i], ((j % 2) * (w + 6), (j // 2 + 1) * (h + 6)))
        grid.append(im)
    save_gif(grid, os.path.join(OUT, "dalga_karsilastirma.gif"))
    grid[14].convert("RGB").save(os.path.join(OUT, "dalga_ozet.png"))
    print("ozet:", os.path.join(OUT, "dalga_ozet.png"))


def render_dalga_ince():
    """D'nin uc kalinligi alt alta (madde 562 ek 3): D (7 px, 3 basamak) / D2 (5 px) / D3 (3 px); E bolgesi x1,5 + D2/D3 x2."""
    meta_k = json.load(open(os.path.join(K_DIR, "meta.json"), encoding="utf-8"))
    bg_k = load_seq(K_DIR)
    crop = (470, 40, 1000, 236)
    rows = {}
    names = {"D": "D - Işık Tülü, şimdiki (7 px)", "D2": DALGA_NAMES["D2"], "D3": DALGA_NAMES["D3"]}
    for key in ("D", "D2", "D3"):
        seq, big = [], []
        for i in range(NFR):
            t = i / FPS
            fr = bg_k[i % len(bg_k)].copy()
            q_A(fr, t)
            e_wave(fr, t, meta_k, key)
            c = fr.crop(crop)
            c1 = c.resize((round(c.width * 1.5), round(c.height * 1.5)), Image.NEAREST)
            label(c1, names[key])
            seq.append(c1)
            if key != "D":
                c2 = c.resize((c.width * 2, c.height * 2), Image.NEAREST)
                label(c2, names[key])
                big.append(c2)
        rows[key] = seq
        if big:
            save_gif(big, os.path.join(OUT, "dalga_%s.gif" % key))
    w, h = rows["D"][0].size
    stacked = []
    for i in range(NFR):
        im = Image.new("RGBA", (w, (h + 6) * 3 - 6), (20, 16, 12, 255))
        for j, k in enumerate(("D", "D2", "D3")):
            im.paste(rows[k][i], (0, j * (h + 6)))
        stacked.append(im)
    save_gif(stacked, os.path.join(OUT, "dalga_D_ince.gif"))
    stacked[14].convert("RGB").save(os.path.join(OUT, "dalga_D_ince.png"))


# ------------------------------------------------------------------ IZGARALI SERIT (madde 562 ek 4)
# Kullanici: "efekt neden parazitli duruyor?" -> teshis: serit pikselleri ORTAK IZGARAYA oturmuyordu (her blok kavis boyunca kesirli
# konuma ayri konuyordu: 1 efekt pikseli = 2,41 ekran px -> kimi 2 kimi 3 px'e yuvarlanip ust uste biniyor / 1 px bosluk birakiyor,
# dalga kaydikca yuvarlama her karede degisip kenarlar "kayniyordu") + GIF kare basina 256 renk (dither, renk kaymasi).
# Duzeltme: serit DUNYAYA SABIT tek bir dusuk cozunurluklu piksel katmanina cizilir (her hucre merkezinin dalgali orta cizgiye
# uzakligina gore ya tam dolu ya bos), katman BIR KEZ en yakin komsuyla buyutulur (oyundaki sprite gibi tutarli izgara); GIF ortak
# paletle, dither'siz. Oyuna alinirken ayni ilke: dunyaya sabit izgaraya oturan shader / dusuk cozunurluklu katman.
import numpy as np

BUBBLE_PX = 1.905  # kalkan baloncugu pikseli (24 px kare -> ekranda 122 px = 45,7 dunya)
IZGARA = {
    # anahtar: (hucre dunya boyu, katmanlar [(yari genislik hucre, taban, rol, alfa) disaridan ice], ad)
    "G1": (ART, ((2.5, ICE["m"], "core", 0.18), (1.5, ICE["l"], "crest", 0.38)), "Izgaralı - karakter pikseli (0,903)"),
    "G2": (BUBBLE_PX, ((1.5, ICE["l"], "crest", 0.34),), "Izgaralı - kalkan pikseli (1,9)"),
}


def _smooth_np(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def _mix_np(base, target, k):
    b = np.array(base[:3], dtype=np.float32)
    g = np.array(target[:3], dtype=np.float32)
    return b[None, :] + (g - b)[None, :] * k[:, None]


def grid_ribbon(size, t, meta, cell_world, layers):
    cp = cell_world * S  # ekran px / hucre
    gw, gh = int(math.ceil(size[0] / cp)) + 2, int(math.ceil(size[1] / cp)) + 2
    rgb = np.zeros((gh, gw, 3), dtype=np.float32)
    alpha = np.zeros((gh, gw), dtype=np.float32)

    def put(iy, ix, cols, al):
        cur = alpha[iy, ix]
        m = al > cur
        rgb[iy[m], ix[m]] = cols[m]
        alpha[iy[m], ix[m]] = al[m]

    for who in ("shaman", "ally"):
        pal = BUBBLE_PAL[BUBBLE_TYPE[who]]
        c, R = bubble_geo(meta, who)
        vx, vy = E_SRC[0] - c[0], E_SRC[1] - c[1]
        vl = math.hypot(vx, vy) or 1
        th0 = math.atan2(vy, vx)
        dst = (c[0] + vx / vl * R, c[1] + vy / vl * R)
        D = np.array([dst[0] - E_SRC[0], dst[1] - E_SRC[1]])
        ln = float(np.hypot(*D))
        H = W(10)
        N = max(16, int(ln / (cp * 0.35)))
        u = np.linspace(0.0, 1.0, N + 1)
        P = np.stack([E_SRC[0] + D[0] * u, E_SRC[1] + D[1] * u - H * 4 * u * (1 - u)], axis=1)
        dP = np.stack([np.full_like(u, D[0]), D[1] - H * (4 - 8 * u)], axis=1)
        dP /= np.linalg.norm(dP, axis=1, keepdims=True)
        nrm = np.stack([-dP[:, 1], dP[:, 0]], axis=1)
        phase = u * ln / W(34) * math.tau - t * math.tau * 1.0
        disp = np.sin(phase) * W(1.4) * np.sin(np.pi * u)
        C = (P + nrm * disp[:, None]) / cp  # orta cizgi, hucre koordinati
        A, B = C[:-1], C[1:]
        AB = B - A
        ab2 = np.maximum((AB ** 2).sum(1), 1e-9)
        pad = layers[0][0] + 2
        x0, y0 = int(max(0, np.floor(C[:, 0].min() - pad))), int(max(0, np.floor(C[:, 1].min() - pad)))
        x1, y1 = int(min(gw - 1, np.ceil(C[:, 0].max() + pad))), int(min(gh - 1, np.ceil(C[:, 1].max() + pad)))
        ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]
        cells = np.stack([xs.ravel() + 0.5, ys.ravel() + 0.5], axis=1)
        AP = cells[:, None, :] - A[None, :, :]
        tt = np.clip((AP * AB[None, :, :]).sum(2) / ab2[None, :], 0.0, 1.0)
        proj = A[None, :, :] + AB[None, :, :] * tt[:, :, None]
        dist = np.linalg.norm(cells[:, None, :] - proj, axis=2)
        mi = dist.argmin(1)
        d = dist[np.arange(len(cells)), mi]
        un = (mi + tt[np.arange(len(cells)), mi]) / len(A)
        taper = np.sin(np.pi * un) ** 0.5
        fade = _smooth_np(un / 0.08)
        kcol = _smooth_np((un - 0.6) / 0.4)
        iy, ix = ys.ravel(), xs.ravel()
        for half, base, role, al in layers:
            m = d <= np.maximum(0.5, half * taper)
            cols = _mix_np(base, pal[role], kcol)
            put(iy[m], ix[m], cols[m], (al * fade)[m])
        ph_n = un * ln / W(34) * math.tau - t * math.tau * 1.0
        bright = 0.5 + 0.5 * np.cos(ph_n)
        m = (d <= 0.5) & (taper > 0.12)
        hi = bright > 0.8
        cols = np.where(hi[:, None], _mix_np(ICE["w"], pal["crest"], kcol), _mix_np(ICE["l"], pal["crest"], kcol))
        put(iy[m], ix[m], cols[m], np.clip((0.7 + 0.3 * bright) * fade, 0, 1)[m])
        # baloncuk yuzeyinde yay (ayni izgara)
        glow = 0.6 + 0.4 * (0.5 + 0.5 * math.cos(ln / W(34) * math.tau - t * math.tau * 1.0))
        cg = np.array(c) / cp
        Rg = R / cp
        span = math.radians(42)
        bx0, by0 = int(max(0, cg[0] - Rg - 2)), int(max(0, cg[1] - Rg - 2))
        bx1, by1 = int(min(gw - 1, cg[0] + Rg + 2)), int(min(gh - 1, cg[1] + Rg + 2))
        ys2, xs2 = np.mgrid[by0:by1 + 1, bx0:bx1 + 1]
        px_ = xs2.ravel() + 0.5 - cg[0]
        py_ = ys2.ravel() + 0.5 - cg[1]
        rr = np.hypot(px_, py_)
        ang = np.arctan2(py_, px_)
        off = np.abs((ang - th0 + np.pi) % (2 * np.pi) - np.pi) / span
        iy2, ix2 = ys2.ravel(), xs2.ravel()
        m_in = (np.abs(rr - (Rg - 1)) <= 0.5) & (off < 0.6)
        put(iy2[m_in], ix2[m_in], np.tile(np.array(pal["core"][:3], np.float32), (m_in.sum(), 1)),
            (0.45 * glow * (1 - off / 0.6))[m_in])
        m_rim = (np.abs(rr - Rg) <= 0.5) & (off <= 1.0)
        hot = np.array(mix(pal["crest"], ICE["w"], 0.65)[:3], np.float32)
        crest = np.array(pal["crest"][:3], np.float32)
        cols = np.where((off < 0.3)[:, None], hot[None, :], crest[None, :])
        put(iy2[m_rim], ix2[m_rim], cols[m_rim], np.clip(1.2 * glow * np.maximum(0, 1 - off) ** 1.3, 0, 1)[m_rim])
    rgba = np.dstack([rgb, alpha * 255.0]).clip(0, 255).astype(np.uint8)
    lay = Image.fromarray(rgba, "RGBA")
    lay = lay.resize((round(gw * cp), round(gh * cp)), Image.NEAREST)
    return lay.crop((0, 0, size[0], size[1]))


def save_gif_clean(frames, path):
    """Ortak palet + dither YOK (onizlemedeki renk titremesi oyunda olmayan bir yan etkiydi)."""
    rgb = [f.convert("RGB") for f in frames]
    step = max(1, len(rgb) // 8)
    samples = rgb[::step]
    w, h = rgb[0].size
    mont = Image.new("RGB", (w, h * len(samples)))
    for i, f in enumerate(samples):
        mont.paste(f, (0, i * h))
    pal = mont.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in rgb]
    q[0].save(path, save_all=True, append_images=q[1:], duration=int(1000 / FPS), loop=0)
    print(path, os.path.getsize(path) // 1024, "KB")


def render_izgara():
    meta_k = json.load(open(os.path.join(K_DIR, "meta.json"), encoding="utf-8"))
    bg_k = load_seq(K_DIR)
    crop = (470, 40, 1000, 236)
    names = {"eski": "Eski çizim (D, 5 px)", "G1": IZGARA["G1"][2], "G2": IZGARA["G2"][2]}
    rows = {}
    for key in ("eski", "G1", "G2"):
        seq, big = [], []
        for i in range(NFR):
            t = i / FPS
            fr = bg_k[i % len(bg_k)].copy()
            q_A(fr, t)
            if key == "eski":
                e_wave(fr, t, meta_k, "D2")
            else:
                cell, layers, _n = IZGARA[key]
                fr.alpha_composite(grid_ribbon(fr.size, t, meta_k, cell, layers))
            c = fr.crop(crop)
            c1 = c.resize((round(c.width * 1.5), round(c.height * 1.5)), Image.NEAREST)
            label(c1, names[key])
            seq.append(c1)
            if key != "eski":
                c2 = c.resize((c.width * 2, c.height * 2), Image.NEAREST)
                label(c2, names[key])
                big.append(c2)
        rows[key] = seq
        if big:
            save_gif_clean(big, os.path.join(OUT, "izgara_%s.gif" % key))
    w, h = rows["eski"][0].size
    stacked = []
    for i in range(NFR):
        im = Image.new("RGBA", (w, (h + 6) * 3 - 6), (20, 16, 12, 255))
        for j, k in enumerate(("eski", "G1", "G2")):
            im.paste(rows[k][i], (0, j * (h + 6)))
        stacked.append(im)
    save_gif_clean(stacked, os.path.join(OUT, "izgara_karsilastirma.gif"))
    stacked[14].convert("RGB").save(os.path.join(OUT, "izgara_karsilastirma.png"))


if __name__ == "__main__":
    import sys
    if "--izgara" in sys.argv:
        render_izgara()
    elif "--dalga-ince" in sys.argv:
        render_dalga_ince()
    elif "--dalga" in sys.argv:
        render_dalga()
    elif "--secim" in sys.argv:
        render_secim()
    else:
        main()
