"""Oakley Q/E/R pixel-art efekt sayfalari -> assets/fx/oakley/

Kullanici istegi (2026-09-25): "Oakleyin pasif harici yeteneklerinin efektlerinin yeniden tasarlanmasini istiyorum pixel
tarzda. sonrasinda spritesheete donustur ki kalite kaybi yasanmasin." + "suankiler cok kotu o yuzden istedim yeniden daha
iyi tasarlamani" -> eski halka/dither kure/Line2D sarmasik tamamen birakildi, sifirdan tasarlandi.

Hepsi 1 sanat pikseli = TEXEL (1.212 dunya/yerel birim) - projedeki FX dili (bkz. gen_sovalye_fx.py). Uretilenler:
  Q  Ari Surusu (2026-09-25 ikinci tasarim - Oakley'yi takip eden koruyucu suru, bkz. scripts/fx_oakley_bee_guard.gd):
     bee_tiny        fly (4 kare, 24 fps): minik siyah-sari ari (saga bakar, script flip_h ile cevirir).
     bee_sting       sting (8 kare, 20 fps, tek sefer): yaratiga sokma - altin yildiz + sacilan zehir damlalari.
     bee_swarm_burst burst (10 kare, 18 fps, tek sefer): yetenek acilisi - altin girdap halkasi, disa firlayan arilar.
  E  Sarmasiklar (dunyada):
     vine_seg     d0..d15 (3 varyant: duz / dikenli / yaprakli): yerde yolu izleyen sarmasik govdesinin bir parcasi, her yon
                  ayri cizilir (dondurulmez). Uclarda kontur yok -> parcalar tek govde gibi birlesir.
     vine_head    d0..d15 (3 kare, 8 fps): kivrik uclu, dikenli sarmasik basi (ilerleme yonune bakar).
     vine_emerge  (11 kare, tek sefer): topragin catlayip dikenli sarmasigin fiskirmasi (cikis noktasi).
     entangle_{s,m,l}_{back,front}  grow / loop / break: sabitlenen yaratigin bacaklarina sarilan dikenli sarmasik
                  (yaratik boyuna gore 3 boy; arka yarisi yaratigin ARKASINDA, on yarisi ONUNDE cizilir).
  R  Koruyucu Buyu (oyuncunun cocugu):
     ward_{back,front}  open / loop / close: ayak altinda altin runlu yaprak muhru + govde etrafinda donen yapraklar.
     ward_hit     (7 kare): hasar aninda yaprak kalkan parlamasi + savrulan yaprak kiriklari.
     ward_cast    (12 kare): Oakley buyuyu yaparken ayak altinda acilan altin muhur + yukari sarmal yapraklar.
  preview.png (scratchpad'e degil OUT'a DEGIL - --preview <yol> ile): cim zemin uzerinde oyun olceginde onizleme.

Calistir: python tools/gen_oakley_fx.py [--preview <png>]   (sonra Godot editoru import eder; yeni sayfalar 2 import isteyebilir)
"""

import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "oakley")
RES = "res://assets/fx/oakley/"
TEXEL = 1.212

# --- bal / ari ---
H_OUT = (92, 46, 12)
H_DEEP = (156, 88, 18)
H_MID = (214, 138, 26)
H_GOLD = (246, 192, 54)
H_PALE = (255, 228, 122)
H_CREAM = (255, 247, 208)
B_OUT = (34, 22, 16)
B_BLACK = (52, 36, 26)
B_WING = (236, 248, 255)
B_WING2 = (170, 206, 236)
# --- yaprak ---
L_OUT = (20, 46, 20)
L_DARK = (38, 94, 34)
L_MID = (72, 150, 52)
L_LIGHT = (134, 206, 84)
L_PALE = (200, 242, 146)
OLIVE = (126, 122, 52)
OLIVE_D = (92, 84, 38)
# --- toprak ---
S_OUT = (40, 26, 16)
S_DARK = (70, 46, 28)
S_MID = (106, 72, 42)
S_LIGHT = (148, 106, 64)
S_PALE = (186, 146, 96)
# --- diken / buyu ---
T_THORN = (228, 210, 150)
T_TIP = (255, 246, 214)
W_GOLD = (246, 214, 110)
W_MINT = (188, 255, 198)
W_WHITE = (242, 255, 236)


# ============================================================================ ortak
def q_alpha(a):
    """Az sayida alfa seviyesi (pixel dili, gen_sovalye_fx.py ile ayni): 0 / .3 / .55 / .8 / 1."""
    for lv in (1.0, 0.8, 0.55, 0.3):
        if a >= lv - 0.12:
            return lv
    return 0.0


def ease_out(t):
    t = max(0.0, min(1.0, t))
    return 1 - (1 - t) ** 3


def ease_in(t):
    t = max(0.0, min(1.0, t))
    return t * t


def lerp_col(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def h01(*k):
    """Deterministik 0..1 karma (her calistirmada ayni sayfa)."""
    x = 0
    for v in k:
        x = (x * 1103515245 + int(v) * 2654435761 + 12345) & 0xFFFFFFFF
    x ^= x >> 13
    x = (x * 0x5BD1E995) & 0xFFFFFFFF
    x ^= x >> 15
    return (x & 0xFFFF) / 65535.0


class Canvas:
    """(x, y) -> (renk, alfa) sozlugu; piksel (x, y) [x, x+1) araligini kaplar."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = {}

    def ok(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def put(self, x, y, col, a=1.0):
        x, y = int(math.floor(x)), int(math.floor(y))
        a = q_alpha(a)
        if a > 0 and self.ok(x, y):
            self.px[(x, y)] = (col, a)

    def under(self, x, y, col, a=1.0):
        """Sadece bos ya da daha soluk bir pikselin yerine yazar."""
        x, y = int(math.floor(x)), int(math.floor(y))
        a = q_alpha(a)
        if a <= 0 or not self.ok(x, y):
            return
        old = self.px.get((x, y))
        if old is None or old[1] < a:
            self.px[(x, y)] = (col, a)

    def blend(self, x, y, col, a):
        """Yari saydam katman: alttaki rengi karistirir (kanat gibi)."""
        x, y = int(math.floor(x)), int(math.floor(y))
        if not self.ok(x, y):
            return
        old = self.px.get((x, y))
        if old is None:
            self.put(x, y, col, a)
            return
        self.px[(x, y)] = (lerp_col(old[0], col, a), max(old[1], q_alpha(a)))

    def image(self):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for (x, y), (c, a) in self.px.items():
            im.putpixel((x, y), tuple(c) + (int(round(255 * a)),))
        return im


N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


def stamp(cv, pix, outline=None, oa=None):
    """Bir nesnenin piksellerini (sozluk) kontur ile basar: kontur nesnenin disindaki 4-komsulara."""
    if outline is not None:
        ring = {}
        for (x, y), (_c, a) in pix.items():
            for dx, dy in N4:
                q = (x + dx, y + dy)
                if q not in pix:
                    ring[q] = max(ring.get(q, 0.0), a)
        for (x, y), a in ring.items():
            cv.put(x, y, outline, (oa if oa is not None else 1.0) * a)
    for (x, y), (c, a) in pix.items():
        cv.put(x, y, c, a)


def leaf_pix(bx, by, ang, L, W, pal, a=1.0):
    """(bx, by) sapindan ang yonune uzanan piksel yaprak. pal = (isik, golge, damar). Isik sol-ustten."""
    dx, dy = math.cos(ang), math.sin(ang)
    nx, ny = -dy, dx
    light_side = 1.0 if (nx * -0.7 + ny * -0.7) > 0 else -1.0
    pix = {}
    r = int(L + W + 2)
    for yy in range(int(by) - r, int(by) + r + 1):
        for xx in range(int(bx) - r, int(bx) + r + 1):
            px_, py_ = xx + 0.5 - bx, yy + 0.5 - by
            u = px_ * dx + py_ * dy
            v = px_ * nx + py_ * ny
            if u < -0.3 or u > L + 0.3:
                continue
            t = max(0.0, min(1.0, u / L))
            hw = W * (math.sin(math.pi * t) ** 0.75) * (1.0 - 0.2 * t)
            if abs(v) > hw + 0.35:
                continue
            if L >= 6 and abs(v) < 0.55 and 0.12 < t < 0.85:
                c = pal[2]
            elif v * light_side > 0:
                c = pal[0]
            else:
                c = pal[1]
            pix[(xx, yy)] = (c, a)
    return pix


def ellipse_ring(cv, cx, cy, rx, ry, col, a, keep=None, step=None):
    """1 piksellik elips cizgisi. keep(aci, i) False donerse o piksel atlanir (kesikli cizgi)."""
    n = step or max(32, int(2 * math.pi * max(rx, ry) * 1.6))
    seen = set()
    for i in range(n):
        ang = 2 * math.pi * i / n
        x, y = int(math.floor(cx + rx * math.cos(ang))), int(math.floor(cy + ry * math.sin(ang)))
        if (x, y) in seen:
            continue
        seen.add((x, y))
        if keep is not None and not keep(ang, len(seen)):
            continue
        cv.put(x, y, col, a)


def save_rows(name, rows):
    """rows: [(anim_adi, [PIL kareleri], loop, fps), ...] - her animasyon kendi satirinda."""
    os.makedirs(OUT, exist_ok=True)
    w, h = rows[0][1][0].size
    cols = max(len(fr) for _n, fr, _l, _f in rows)
    s = Image.new("RGBA", (w * cols, h * len(rows)), (0, 0, 0, 0))
    anims = []
    for r, (an, frs, loop, fps) in enumerate(rows):
        for i, f in enumerate(frs):
            assert f.size == (w, h), (name, an, f.size)
            s.paste(f, (i * w, r * h))
        anims.append((an, (0, r), len(frs), loop, fps))
    png = os.path.join(OUT, name + "_sheet.png")
    s.save(png)
    tres = os.path.join(OUT, name + "_frames.tres")
    write_sprite_frames(tres, RES + name + "_sheet.png", w, h, anims)
    with open(tres, "rb") as f:
        data = f.read().replace(b"\r\n", b"\n")
    with open(tres, "wb") as f:
        f.write(data)
    PREVIEW[name] = rows


PREVIEW = {}


# ============================================================================ Q - Ari Surusu (koruyucu suru)
# 2026-09-25 ikinci tasarim (kullanici: "oakleyin ari yetenegini siliyoruz artik oakley ari yetenegini actiginda kendisini
# takip eden minik arilar olsun ve kendisine yaklasan dusmanlari zehirleyip onlari geriye itsin"): sabit alan (bee_zone)
# kaldirildi. Arilar Oakley'nin cocugu (onu takip eder), yaklasan yaratiga dalip sokar (bkz. scripts/fx_oakley_bee_guard.gd).
POISON_D = (58, 110, 30)
POISON_M = (120, 190, 50)
POISON_L = (196, 238, 110)


def bee_tiny():
    """Minik ari: 11x9 tuval, saga bakar (script flip_h ile cevirir), 4 kare kanat cirpma."""
    W, H = 11, 9
    frames = []
    for wy, wa in ((-2.4, 0.8), (-1.2, 0.8), (0.0, 0.55), (-1.2, 0.8)):
        cv = Canvas(W, H)
        body = {}
        cx, cy = 4.6, 5.4
        for yy in range(H):
            for xx in range(W):
                X, Y = xx + 0.5, yy + 0.5
                if ((X - cx) / 2.7) ** 2 + ((Y - cy) / 1.9) ** 2 <= 1.0:
                    rel = X - cx
                    c = B_BLACK if -0.4 < rel < 0.7 else (H_GOLD if Y < cy + 0.1 else H_MID)
                    body[(xx, yy)] = (c, 1.0)
        for yy in range(H):
            for xx in range(W):
                if math.hypot(xx + 0.5 - 7.9, yy + 0.5 - 5.1) <= 1.2:
                    body[(xx, yy)] = (B_BLACK, 1.0)
        body[(8, 4)] = (B_WING, 1.0)  # goz parlamasi
        body[(3, 4)] = (H_CREAM, 1.0)  # sirt parlamasi
        body[(1, 6)] = (B_BLACK, 1.0)  # igne
        stamp(cv, body, B_OUT, 1.0)
        for ox, sc, col in ((3.9, 0.8, B_WING2), (5.1, 1.0, B_WING)):
            wx, wyc = ox, 3.6 + wy
            for yy in range(H):
                for xx in range(W):
                    if ((xx + 0.5 - wx) / (1.8 * sc)) ** 2 + ((yy + 0.5 - wyc) / 1.2) ** 2 <= 1.0:
                        cv.blend(xx, yy, col, wa)
        frames.append(cv.image())
    save_rows("bee_tiny", [("fly", frames, True, 24)])


def bee_sting():
    """Sokma ani (dunyada, yaratigin uzerinde): once altin yildiz parlamasi, sonra disa sacilan zehir damlalari + genisleyen
    yesil dither halka. 24x24 tuval, merkez = isabet noktasi. 8 kare / 20 fps, tek sefer."""
    W = H = 24
    c = 12.0
    rnd = random.Random(33)
    drops = [(rnd.random() * 2 * math.pi, rnd.uniform(0.7, 1.15)) for _ in range(7)]
    frames = []
    for f in range(8):
        t = (f + 1) / 8
        cv = Canvas(W, H)
        fade = 1.0 if f < 5 else [0.8, 0.55, 0.3][f - 5]
        if f < 3:
            ln = [3, 4, 2][f]
            for k in range(1, ln + 1):
                for dx, dy in N4:
                    cv.put(c + dx * k, c + dy * k, H_PALE if k < ln else H_GOLD, 1.0)
            for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
                cv.put(c + dx, c + dy, H_GOLD, 0.8)
            cv.put(c, c, H_CREAM, 1.0)
        if f >= 1:
            r = 2.5 + 7.0 * ease_out((f - 1) / 6)
            ellipse_ring(cv, c, c, r, r * 0.8, POISON_M, 0.55 * fade, keep=lambda a, k: (k + f) % 2 == 0)
        for ang, sp in drops:
            if f < 1:
                continue
            d = (3.0 + 8.0 * sp * ease_out((f - 1) / 6))
            x = c + d * math.cos(ang)
            y = c + d * math.sin(ang) * 0.8 + 3.0 * ((f - 1) / 6) ** 2
            pix = {(int(x), int(y)): (POISON_L if sp > 0.95 else POISON_M, fade)}
            stamp(cv, pix, POISON_D, 0.8 * fade)
        frames.append(cv.image())
    save_rows("bee_sting", [("sting", frames, False, 20)])


def bee_swarm_burst():
    """Yetenek acilisi (Oakley'nin uzerinde): altin bal girdabi halkasi acilir, minik arilar disa firlayip yorungeye dagilir,
    polen parlar. 64x56 tuval, merkez (32,30) = govde ortasi. 10 kare / 18 fps, tek sefer."""
    W, H = 64, 56
    cx, cy = 32.0, 30.0
    rnd = random.Random(8)
    bees = [(2 * math.pi * k / 8 + rnd.uniform(-0.2, 0.2), rnd.uniform(0.8, 1.1)) for k in range(8)]
    motes = [(rnd.random() * 2 * math.pi, rnd.uniform(6, 26)) for _ in range(14)]
    frames = []
    for f in range(10):
        t = (f + 1) / 10
        cv = Canvas(W, H)
        fade = 1.0 if f < 7 else [0.8, 0.55, 0.3][f - 7]
        e = ease_out(t)
        r = 6 + 20 * e
        ellipse_ring(cv, cx, cy + 10, r, r * 0.34, H_GOLD if f > 1 else H_CREAM, fade)
        ellipse_ring(cv, cx, cy + 10, r - 3, (r - 3) * 0.34, H_MID, 0.55 * fade, keep=lambda a, k: k % 2 == 0)
        # sarmal disa firlayan arilar (siyah-sari 3x2 lekeler + kanat pikseli)
        for ang, sp in bees:
            d = 4 + 22 * sp * ease_out(min(1.0, t * 1.3))
            a2 = ang + 1.2 * t
            x = cx + d * math.cos(a2)
            y = cy + d * math.sin(a2) * 0.55 - 4 * math.sin(math.pi * t)
            pix = {(int(x), int(y)): (H_GOLD, fade), (int(x) + 1, int(y)): (B_BLACK, fade), (int(x) + 2, int(y)): (H_GOLD, fade)}
            stamp(cv, pix, B_OUT, fade)
            cv.blend(int(x) + 1, int(y) - 1, B_WING, 0.8 * fade)
        for ang, d in motes:
            tt = min(1.0, t * 1.2)
            x = cx + d * tt * math.cos(ang)
            y = cy + d * tt * math.sin(ang) * 0.6 - 6 * tt
            cv.put(x, y, H_PALE if f % 2 == 0 else H_CREAM, fade * (1.0 - 0.5 * tt))
        if f < 3:
            for dx, dy in N4:
                for k in range(1, 3 + f):
                    cv.put(cx + dx * k, cy + dy * k, H_CREAM if k < 2 else H_GOLD, 1.0 - 0.25 * f)
        frames.append(cv.image())
    save_rows("bee_swarm_burst", [("burst", frames, False, 18)])


# ============================================================================ E - toprak / sarmasik parcalari
# 2026-09-25 ikinci tur (kullanici: "hareket eden sarmasik sarmasik gibi degil bi fidan gibi cok kotu ama yaratiklari
# sabitledigi hali iyi"): topraktan tumsek + arkasinda biten fidanlar kaldirildi. Artik yerde GERCEK yolu izleyen kesintisiz
# dikenli bir sarmasik govdesi: yolun her ~8 sanat pikselinde bir PARCA (16 yon icin ayri cizilmis - dondurulmez, piksel
# kaymaz) + kivrik uclu bir BAS (16 yon x 3 kare). Parcalarin uclarinda kontur YOK (sadece yanlarda) - ust uste binen
# parcalar "bogum" cizgisi olmadan tek govde gibi gorunur.
N_DIRS = 16
SEG_CELL = 16


def _dir_vec(k):
    a = 2 * math.pi * k / N_DIRS
    return math.cos(a), math.sin(a)


def _stroke_side_outline(cv, pts_core, dx, dy, u_min, u_max, cx, cy, alpha=1.0):
    """pts_core: {(x,y): renk} govde pikselleri. Kontur sadece govdenin YANLARINA (uclara degil) basilir."""
    ring = set()
    for (x, y) in pts_core:
        for ox, oy in N4:
            q = (x + ox, y + oy)
            if q in pts_core:
                continue
            u = (q[0] + 0.5 - cx) * dx + (q[1] + 0.5 - cy) * dy
            if u_min + 0.6 <= u <= u_max - 0.6:
                ring.add(q)
    for (x, y) in ring:
        cv.put(x, y, L_OUT, 0.8 * alpha)
    for (x, y), c in pts_core.items():
        cv.put(x, y, c, alpha)


def _seg_image(k, variant):
    W = H = SEG_CELL
    cx = cy = W / 2.0
    dx, dy = _dir_vec(k)
    nx, ny = -dy, dx
    cv = Canvas(W, H)
    half = 5.5
    core = {}
    steps = 40
    for i in range(steps + 1):
        u = -half + 2 * half * i / steps
        x, y = cx + dx * u, cy + dy * u
        X, Y = int(math.floor(x)), int(math.floor(y))
        # 2 piksel kalin govde: isik tarafi (sol-ust) acik, diger yan koyu
        core[(X, Y)] = L_MID
        sx, sy = int(math.floor(x + nx * 0.9)), int(math.floor(y + ny * 0.9))
        light_side = (nx * -0.7 + ny * -0.7) > 0
        core.setdefault((sx, sy), L_LIGHT if light_side else L_DARK)
        ox_, oy_ = int(math.floor(x - nx * 0.9)), int(math.floor(y - ny * 0.9))
        core.setdefault((ox_, oy_), L_DARK if light_side else L_LIGHT)
    # zemine düşen hafif gölge (govdenin 2 px alti) - cimen ustunde govde secilsin
    for (x, y) in core:
        cv.under(x, y + 2, (22, 44, 18), 0.3)
    _stroke_side_outline(cv, core, dx, dy, -half, half, cx, cy)
    side = 1 if variant == 1 else -1
    if variant == 1:  # diken cifti
        bx, by = cx + nx * 1.8 * side, cy + ny * 1.8 * side
        cv.put(bx, by, T_THORN, 1.0)
        cv.put(bx + nx * 1.1 * side + dx * 0.8, by + ny * 1.1 * side + dy * 0.8, T_TIP, 1.0)
    elif variant == 2:  # kucuk yaprak
        stamp(cv, leaf_pix(cx + nx * 1.6 * side, cy + ny * 1.6 * side, math.atan2(ny * side, nx * side) + 0.5 * side, 4.0, 1.5,
                           (L_LIGHT, L_MID, L_PALE)), L_OUT, 0.8)
    return cv.image()


def vine_seg():
    rows = []
    for k in range(N_DIRS):
        rows.append(("d%d" % k, [_seg_image(k, v) for v in range(3)], False, 0))
    save_rows("vine_seg", rows)


def _head_image(k, f):
    """Kivrik (egreltiotu) uclu sarmasik basi: govde arkaya (-u) uzanir, uc +u yonunde kivrilir. f: kivrilma evresi."""
    W = H = 20
    cx = cy = W / 2.0
    dx, dy = _dir_vec(k)
    nx, ny = -dy, dx
    cv = Canvas(W, H)
    core = {}
    light_side = (nx * -0.7 + ny * -0.7) > 0
    back = -7.5
    front = 1.5
    steps = 40
    wig = [0.0, 0.5, -0.4][f]
    for i in range(steps + 1):
        u = back + (front - back) * i / steps
        w = wig * math.sin((u - back) / (front - back) * math.pi)
        x, y = cx + dx * u + nx * w, cy + dy * u + ny * w
        X, Y = int(math.floor(x)), int(math.floor(y))
        core[(X, Y)] = L_MID
        a_ = (int(math.floor(x + nx * 0.9)), int(math.floor(y + ny * 0.9)))
        b_ = (int(math.floor(x - nx * 0.9)), int(math.floor(y - ny * 0.9)))
        core.setdefault(a_, L_LIGHT if light_side else L_DARK)
        core.setdefault(b_, L_DARK if light_side else L_LIGHT)
    # ucta kivrilan ince filiz (1 piksel), evreye gore acilip kapanir
    r0 = 2.6 + 0.4 * f
    px0, py0 = cx + dx * front, cy + dy * front
    ccx, ccy = px0 + nx * r0, py0 + ny * r0
    th0 = math.atan2(py0 - ccy, px0 - ccx)
    sweep = [1.5, 1.8, 1.3][f] * math.pi
    tip = {}
    n = 30
    for i in range(1, n + 1):
        al = sweep * i / n
        rr = r0 * (1.0 - 0.5 * al / (2 * math.pi))
        th = th0 + al * (1 if True else -1)
        x, y = ccx + rr * math.cos(th), ccy + rr * math.sin(th)
        tip[(int(math.floor(x)), int(math.floor(y)))] = L_LIGHT
    for q, c in tip.items():
        core.setdefault(q, c)
    # kontur: arka uc HARIC (son parcaya baglanir)
    ring = set()
    for (x, y) in core:
        for ox, oy in N4:
            q = (x + ox, y + oy)
            if q in core:
                continue
            u = (q[0] + 0.5 - cx) * dx + (q[1] + 0.5 - cy) * dy
            if u >= back + 0.6:
                ring.add(q)
    for (x, y) in ring:
        cv.put(x, y, L_OUT, 0.8)
    for (x, y), c in core.items():
        cv.put(x, y, c, 1.0)
    # iki diken
    for side, uu in ((1, -4.0), (-1, -1.5)):
        bx, by = cx + dx * uu + nx * 1.9 * side, cy + dy * uu + ny * 1.9 * side
        cv.put(bx, by, T_THORN, 1.0)
        cv.put(bx + nx * 1.0 * side + dx * 0.8, by + ny * 1.0 * side + dy * 0.8, T_TIP, 1.0)
    # yere dusen gölge izi (govdenin altina 1 px koyu)
    return cv.image()


def vine_head():
    rows = []
    for k in range(N_DIRS):
        rows.append(("d%d" % k, [_head_image(k, f) for f in range(3)], True, 8))
    save_rows("vine_head", rows)


def _vine_stroke_pix(pts, alpha=1.0, thorn_every=5, thorn_side=1, thin_from=None):
    """Kalin (2 piksel) sarmasik govdesi: orta ton + ust parlak, belli araliklarla diken."""
    pix = {}
    thorns = {}
    for i, (x, y) in enumerate(pts):
        X, Y = int(math.floor(x)), int(math.floor(y))
        pix[(X, Y)] = (L_MID, alpha)
        if thin_from is None or i < thin_from:
            pix[(X + 1, Y)] = (L_DARK, alpha)
        if i % 3 == 0:
            pix[(X, Y)] = (L_LIGHT, alpha)
        if thorn_every and i % (thorn_every * 3) == thorn_every * 2 and 0 < i < (thin_from or len(pts)) - 2:
            ax, ay = pts[min(i + 1, len(pts) - 1)]
            bx, by = pts[max(i - 1, 0)]
            tx, ty = ax - bx, ay - by
            ln = math.hypot(tx, ty) or 1.0
            nx, ny = -ty / ln * thorn_side, tx / ln * thorn_side
            thorns[(int(math.floor(x + nx * 1.6)), int(math.floor(y + ny * 1.6)))] = (T_THORN, alpha)
            thorns[(int(math.floor(x + nx * 2.6 + tx / ln * 0.8)), int(math.floor(y + ny * 2.6 + ty / ln * 0.8)))] = (T_TIP, alpha)
    return pix, thorns


def vine_emerge():
    W, H = 44, 40
    cx, gy = 22.0, 31.0
    n = 11
    rnd = random.Random(11)
    chunks = [(rnd.uniform(-1, 1), rnd.uniform(0.55, 1.0), rnd.choice([1, 2]), rnd.random()) for _ in range(11)]
    frames = []
    for f in range(n):
        cv = Canvas(W, H)
        t = f / (n - 1)
        crater_a = 1.0 if f < 8 else [0.8, 0.55, 0.3][f - 8]
        # krater + catlaklar
        rx = 5.0 + 5.0 * ease_out(min(1.0, f / 3))
        for yy in range(H):
            for xx in range(W):
                if ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - gy) / (rx * 0.38)) ** 2 <= 1.0:
                    cv.put(xx, yy, S_DARK, 0.8 * crater_a)
        ellipse_ring(cv, cx, gy, rx + 0.5, rx * 0.38 + 0.5, S_MID, crater_a)
        if f < 7:
            for k in range(5):
                ang = math.pi * (0.1 + 0.8 * k / 4) + math.pi
                ln = rx + 1 + min(f, 3) * 1.5
                for s in range(int(rx), int(ln)):
                    cv.put(cx + math.cos(ang) * s, gy - math.sin(ang) * s * 0.38 * -1, S_OUT, 0.8)
        # firlayan toprak topaklari
        for vx, vy, size, ph in chunks:
            tt = t * 1.25
            x = cx + vx * 16 * tt
            y = gy - 3 - vy * 26 * tt + 26 * tt * tt
            if y > gy + 2 or tt > 1.05:
                continue
            pix = {}
            for dx in range(size):
                for dy in range(size):
                    pix[(int(x) + dx, int(y) + dy)] = (S_LIGHT if ph > 0.5 else S_MID, 1.0)
            stamp(cv, pix, S_OUT, 0.8)
        # fiskiran dikenli sarmasik (yukselir, kivrilir, geri cekilir)
        if 1 <= f <= 9:
            up = ease_out(min(1.0, (f - 0) / 5.0)) if f <= 5 else 1.0 - ease_in((f - 5) / 4.0)
            hgt = 22.0 * up
            if hgt > 1.0:
                pts = []
                stem_h = hgt * 0.72
                steps = int(stem_h * 2.2) + 2
                for s_ in range(steps + 1):
                    u = s_ / steps
                    pts.append((cx - 0.5 + 2.0 * math.sin(u * 3.0), gy - 2 - stem_h * u))
                # uc: govdeden saga kivrilan, iceri daralan sarmal (egreltiotu filizi)
                r0 = 2.0 + 2.8 * min(1.0, hgt / 22.0)
                stem_n = len(pts)
                px0, py0 = pts[-1]
                ccx = px0 + r0
                sweep = 1.9 * math.pi * min(1.0, hgt / 16.0)
                n_c = int(sweep * r0 * 1.6) + 2
                for s_ in range(1, n_c + 1):
                    al_ = sweep * s_ / n_c
                    rr_ = r0 * (1.0 - 0.55 * al_ / (2 * math.pi))
                    th_ = math.pi + al_
                    pts.append((ccx + rr_ * math.cos(th_), py0 + rr_ * math.sin(th_)))
                pix, thorns = _vine_stroke_pix(pts, thin_from=stem_n)
                stamp(cv, pix, L_OUT, 1.0)
                for (x, y), (c, a) in thorns.items():
                    cv.put(x, y, c, a)
                if hgt > 8:
                    lx, ly = pts[int(stem_n * 0.45)]
                    stamp(cv, leaf_pix(lx + 1.5, ly, -0.35, 5.0, 1.7, (L_LIGHT, L_MID, L_PALE)), L_OUT, 0.8)
        if f >= 6:
            # geri cekilirken kopan yapraklar
            for k, side in enumerate((-1, 1)):
                tt = (f - 6) / 4.0
                x = cx + side * (4 + 9 * tt)
                y = gy - 16 + 12 * tt * tt - 4 * tt
                stamp(cv, leaf_pix(x, y, side * 0.8 + tt * 2.0 * side, 3.6, 1.3, (L_LIGHT, L_MID, L_LIGHT), 1.0 - tt * 0.6), L_OUT, 0.8 * (1.0 - tt * 0.6))
        frames.append(cv.image())
    save_rows("vine_emerge", [("burst", frames, False, 20)])


# ============================================================================ E - entangle (yaratik uzerinde)
ENT_SIZES = {
    # boy: (tuval W, H, zemin y, silindir yaricapi, yukseklik, dal sayisi)
    "s": (34, 30, 24.0, 5.5, 13.0, 3),
    "m": (46, 42, 33.0, 9.0, 21.0, 3),
    "l": (70, 62, 51.0, 15.5, 34.0, 4),
}


def _entangle_frame(size, mode, i, n):
    """Yaratigin bacaklarina SEYREK sarilan dikenli dallar: her dal yarim tur doner, yukari incelir, ucu dikenle biter
    (yaratigin kendisi arkadan gorunmeye devam eder). Donus: (arka katman, on katman)."""
    W, H, gy, rc, hmax, count = ENT_SIZES[size]
    cx = W / 2.0
    back, front = Canvas(W, H), Canvas(W, H)
    grow, squeeze, frag_t, alpha = 1.0, 0.0, 0.0, 1.0
    if mode == "grow":
        grow = ease_out((i + 1) / n)
    elif mode == "loop":
        squeeze = math.sin(2 * math.pi * i / n)
    else:  # break
        frag_t = (i + 1) / n
        grow = 1.0 - ease_in(frag_t)
        alpha = 1.0 if i < 2 else [0.8, 0.8, 0.55, 0.3][min(3, i - 2)]
    # zemin: dama desenli karartilmis toprak (ayak altinda, arka katman)
    grx, gry = rc + 3.5, (rc + 3.5) * 0.36
    ga = alpha * (min(1.0, (i + 1) / 2.0) if mode == "grow" else 1.0)
    for yy in range(H):
        for xx in range(W):
            if ((xx + 0.5 - cx) / grx) ** 2 + ((yy + 0.5 - gy) / gry) ** 2 <= 1.0 and (xx + yy) % 2 == 0:
                back.put(xx, yy, S_DARK, 0.55 * ga)
    for k in range(count):
        th0 = 2 * math.pi * k / count + 0.3 + 0.5 * h01(k, 4)
        hk = hmax * (0.72 + 0.28 * h01(k, 5))
        twist = 0.5 + 0.18 * h01(k, 9)
        h_cur = hk * grow
        # dalin topraktan cikis noktasinda kucuk kok kivrimi
        bx = cx + rc * 1.05 * math.cos(th0)
        by = gy + rc * 1.05 * 0.36 * math.sin(th0)
        for m in range(1, 4):
            rr = rc * 1.05 + m * 0.9
            ang = th0 - 0.12 * m
            (front if math.sin(th0) > 0 else back).put(cx + rr * math.cos(ang), gy + rr * 0.36 * math.sin(ang) + (m == 3), S_MID, 0.8 * ga)
        layers = {"b": {}, "f": {}}
        thorn_px = {"b": {}, "f": {}}
        steps = int(h_cur * 4) + 2
        last = None
        for s_ in range(steps + 1):
            z = h_cur * s_ / steps
            th = th0 + 2 * math.pi * twist * z / hk
            r = rc * (1.05 - 0.25 * z / hk) * (1.0 - 0.06 * squeeze * (0.6 + 0.4 * math.sin(k * 2.1)))
            x = cx + r * math.cos(th)
            y = gy - z + r * 0.36 * math.sin(th)
            key = "f" if math.sin(th) > 0 else "b"
            X, Y = int(math.floor(x)), int(math.floor(y))
            thick = z < hk * 0.6
            layers[key][(X, Y)] = ((L_MID if key == "f" else L_DARK), alpha)
            if thick:
                layers[key][(X, Y + 1)] = ((L_DARK if key == "f" else L_OUT), alpha)
            if key == "f" and s_ % 3 == 0:
                layers[key][(X, Y)] = (L_LIGHT, alpha)
            if s_ % 12 == 7 and s_ < steps - 2:
                side = 1 if math.cos(th) >= 0 else -1
                glint = mode == "loop" and ((i + k) % n) == 0
                thorn_px[key][(X + side, Y - 1)] = (T_THORN, alpha)
                thorn_px[key][(X + side * 2, Y - 2)] = (T_TIP if glint else T_THORN, alpha)
            last = (X, Y, key, th)
        for key, cv in (("b", back), ("f", front)):
            if layers[key]:
                stamp(cv, layers[key], L_OUT, 0.8 * alpha)
            for (x, y), (c, a_) in thorn_px[key].items():
                cv.put(x, y, c, a_)
        if last is not None and h_cur > 2:
            X, Y, key, th = last
            cv = front if key == "f" else back
            side = 1 if math.cos(th) >= 0 else -1
            cv.put(X + side, Y - 1, T_THORN, alpha)
            cv.put(X + side, Y - 2, T_TIP, alpha)
        # dalin ortasinda bir yaprak
        if grow > 0.55:
            z = hk * 0.42
            if z <= h_cur:
                th = th0 + 2 * math.pi * twist * z / hk
                r = rc * (1.05 - 0.25 * z / hk)
                x = cx + r * math.cos(th)
                y = gy - z + r * 0.36 * math.sin(th)
                side = 1 if math.cos(th) >= 0 else -1
                flutter = 0.25 * math.sin(2 * math.pi * i / max(n, 1) + k) if mode == "loop" else 0.0
                ang = -math.pi / 2 + side * (1.0 + flutter)
                lcv = front if math.sin(th) > 0 else back
                stamp(lcv, leaf_pix(x + side * 1.0, y, ang, 4.0 if size != "l" else 5.5, 1.5, (L_LIGHT, L_MID, L_PALE), alpha),
                      L_OUT, 0.8 * alpha)
        # kopma: ust parcalar savrulur
        if mode == "break":
            for m in range(2):
                z = hk * (0.5 + 0.25 * m)
                th = th0 + 2 * math.pi * twist * z / hk
                side = 1 if math.cos(th) >= 0 else -1
                x = cx + rc * math.cos(th) + side * frag_t * (6 + 3 * m)
                y = gy - z + 16 * frag_t * frag_t - 5 * frag_t
                cv = front if math.sin(th) > 0 else back
                pix = {(int(x), int(y)): (L_MID, alpha), (int(x) + side, int(y) - 1): (L_LIGHT, alpha)}
                stamp(cv, pix, L_OUT, 0.8 * alpha)
    # buyume aninda firlayan toprak
    if mode == "grow" and i < 4:
        for k in range(6):
            ang = math.pi + math.pi * k / 5
            dist = grx * (0.7 + 0.25 * i)
            x = cx + math.cos(ang) * dist
            y = gy + math.sin(ang) * gry - 3 * math.sin(math.pi * (i + 1) / 5)
            front.put(x, y, S_LIGHT, 1.0 - 0.2 * i)
    return back.image(), front.image()


def entangle():
    spec = (("grow", 8, False, 16), ("loop", 6, True, 6), ("break", 6, False, 14))
    for size in ENT_SIZES:
        rows_b, rows_f = [], []
        for mode, n, loop, fps in spec:
            fb, ff = [], []
            for i in range(n):
                b, f = _entangle_frame(size, mode, i, n)
                fb.append(b)
                ff.append(f)
            rows_b.append((mode, fb, loop, fps))
            rows_f.append((mode, ff, loop, fps))
        save_rows("entangle_%s_back" % size, rows_b)
        save_rows("entangle_%s_front" % size, rows_f)


# ============================================================================ R - ward (Koruyucu Buyu)
WARD_W, WARD_H = 72, 96
WARD_FEET = (36.0, 84.0)
ORB_C = (36.0, 57.0)
ORB_RX, ORB_RY = 25.0, 7.5
N_LEAVES = 8


def _sigil(back, f, n, sweep=1.0, alpha=1.0, flash=0.0, decimate=0.0):
    cx, cy = WARD_FEET
    pulse = 0.5 + 0.5 * math.sin(2 * math.pi * f / max(n, 1))

    def keep_outer(ang, k):
        a = (ang + math.pi / 2) % (2 * math.pi)
        return a <= 2 * math.pi * sweep and h01(k, 77) >= decimate

    ring_col = W_WHITE if flash > 0.5 else W_GOLD
    ellipse_ring(back, cx, cy, 22.0, 7.0, ring_col, (0.8 if pulse > 0.5 else 0.55) * alpha + flash * 0.3, keep=keep_outer)
    ellipse_ring(back, cx, cy, 22.0, 8.0, H_DEEP, 0.55 * alpha, keep=lambda a, k: keep_outer(a, k) and k % 2 == 0)
    ellipse_ring(back, cx, cy, 16.5, 5.2, W_MINT, 0.55 * alpha,
                 keep=lambda a, k: keep_outer(a, k) and (k + f) % 3 != 0)
    # altin yaprak glifleri halkada doner (loop boyunca bir glif araligi -> dikissiz)
    for k in range(6):
        th = 2 * math.pi * k / 6 + (f / max(n, 1)) * (2 * math.pi / 6)
        if (th + math.pi / 2) % (2 * math.pi) > 2 * math.pi * sweep or h01(k, 31) < decimate:
            continue
        x = cx + 22.0 * math.cos(th)
        y = cy + 7.0 * math.sin(th)
        stamp(back, leaf_pix(x - 1.5, y + 0.5, -0.6, 3.2, 1.2, (W_GOLD, H_GOLD, W_GOLD), alpha), H_DEEP, 0.55 * alpha)


def _orbit_leaves(back, front, f, n, spread=1.0, spin=0.0, drop=0.0, alpha=1.0, count=N_LEAVES):
    cx, cy = ORB_C
    for k in range(count):
        phi = 2 * math.pi * k / count + (f / max(n, 1)) * (2 * math.pi / count) + spin
        rx, ry = ORB_RX * spread, ORB_RY * spread
        bob = 1.2 * math.sin(3 * phi)
        x = cx + rx * math.cos(phi)
        y = cy + ry * math.sin(phi) + bob + drop * (0.6 + 0.4 * h01(k, 3))
        tx, ty = -rx * math.sin(phi), ry * math.cos(phi)
        ang = math.atan2(ty, tx) + 0.35 * math.sin(4 * phi)
        is_front = math.sin(phi) > 0
        if is_front:
            pal, cv, a, oc = (W_MINT, L_LIGHT, W_WHITE), front, alpha, L_OUT
        else:
            pal, cv, a, oc = (L_LIGHT, L_MID, L_PALE), back, alpha * 0.8, L_OUT
        stamp(cv, leaf_pix(x - math.cos(ang) * 3.5, y - math.sin(ang) * 3.5, ang, 7.0, 2.4, pal, a), oc, 0.8 * a)


def _ward_motes(back, front, f, n, alpha=1.0):
    cx, cy = WARD_FEET
    for k in range(6):
        psi = 2 * math.pi * k / 6 + 0.4
        t = ((f + k * n / 6) % n) / n
        x = cx + 18 * math.cos(psi) * (1 - 0.3 * t)
        y = cy + 6 * math.sin(psi) - t * 30
        a = math.sin(math.pi * t) * alpha
        (front if math.sin(psi) > 0 else back).put(x, y, W_MINT if k % 2 else W_GOLD, a)


def _dome(back, f, n, alpha=1.0):
    """Cok soluk kubbe kenari (sadece ust yay, seyrek) + dongude bir kez gecen parlak serit."""
    cx, cy = 36.0, 56.0
    sweep_c = math.pi + math.pi * (f / max(n, 1))
    ellipse_ring(back, cx, cy, 27.0, 38.0, W_MINT, 0.3 * alpha,
                 keep=lambda a, k: math.sin(a) < -0.35 and k % 3 == 0)
    ellipse_ring(back, cx, cy, 27.0, 38.0, W_WHITE, 0.55 * alpha,
                 keep=lambda a, k: math.sin(a) < -0.35 and abs(((a - sweep_c + math.pi) % (2 * math.pi)) - math.pi) < 0.22)


def ward():
    n = 16
    rows_b, rows_f = [], []
    # open
    fb, ff = [], []
    for i in range(8):
        e = ease_out((i + 1) / 8)
        back, front = Canvas(WARD_W, WARD_H), Canvas(WARD_W, WARD_H)
        flash = 1.0 if i in (3, 4) else 0.0
        _sigil(back, 0, n, sweep=min(1.0, e * 1.15), flash=flash)
        if flash:
            ellipse_ring(back, WARD_FEET[0], WARD_FEET[1], 25.0, 8.5, W_MINT, 0.55)
        _orbit_leaves(back, front, 0, n, spread=1.0 + 1.3 * (1 - e), spin=-math.pi * (1 - e), alpha=min(1.0, 0.35 + e))
        fb.append(back.image())
        ff.append(front.image())
    rows_b.append(("open", fb, False, 16))
    rows_f.append(("open", ff, False, 16))
    # loop
    fb, ff = [], []
    for f in range(n):
        back, front = Canvas(WARD_W, WARD_H), Canvas(WARD_W, WARD_H)
        _dome(back, f, n)
        _sigil(back, f, n)
        _ward_motes(back, front, f, n)
        _orbit_leaves(back, front, f, n)
        fb.append(back.image())
        ff.append(front.image())
    rows_b.append(("loop", fb, True, 10))
    rows_f.append(("loop", ff, True, 10))
    # close
    fb, ff = [], []
    for i in range(8):
        e = (i + 1) / 8
        back, front = Canvas(WARD_W, WARD_H), Canvas(WARD_W, WARD_H)
        _sigil(back, i, n, alpha=1.0 - 0.3 * e, decimate=e)
        _orbit_leaves(back, front, i, n, spread=1.0 + 0.9 * e, drop=14 * e * e, alpha=1.0 - e * 0.85)
        fb.append(back.image())
        ff.append(front.image())
    rows_b.append(("close", fb, False, 14))
    rows_f.append(("close", ff, False, 14))
    save_rows("ward_back", rows_b)
    save_rows("ward_front", rows_f)


def ward_hit():
    frames = []
    rnd = random.Random(21)
    shards = [(rnd.random() * 2 * math.pi, rnd.uniform(0.7, 1.2), rnd.random()) for _ in range(10)]
    for i in range(7):
        t = (i + 1) / 7
        cv = Canvas(WARD_W, WARD_H)
        a = 1.0 - t
        # yaprak kalkani nabzi: yorunge elipsi parlar ve genisler + govdeyi saran dalga
        ellipse_ring(cv, ORB_C[0], ORB_C[1], ORB_RX + 2 * i, ORB_RY + 0.6 * i, W_WHITE if i < 2 else W_MINT, a + 0.1)
        ellipse_ring(cv, 36.0, 55.0, 18 + 3 * i, 28 + 3 * i, W_MINT, 0.55 * a, keep=lambda ang, k: k % 2 == 0)
        for ang, sp, ph in shards:
            dist = ORB_RX * (0.8 + 0.7 * sp * ease_out(t))
            x = ORB_C[0] + dist * math.cos(ang)
            y = ORB_C[1] + dist * 0.45 * math.sin(ang) + 18 * t * t - 6 * t
            stamp(cv, leaf_pix(x, y, ang + ph * 3 + t * 4, 3.4, 1.3, (W_MINT, L_LIGHT, W_WHITE), a + 0.15), L_OUT, 0.8 * (a + 0.15))
        frames.append(cv.image())
    save_rows("ward_hit", [("hit", frames, False, 20)])


def ward_cast():
    frames = []
    n = 12
    for i in range(n):
        t = (i + 1) / n
        cv = Canvas(WARD_W, WARD_H)
        fade = 1.0 if i < n - 3 else [0.8, 0.55, 0.3][i - (n - 3)]
        # ayak altinda acilan altin muhur
        e = ease_out(min(1.0, t * 1.8))
        rx = 6 + 18 * e
        ellipse_ring(cv, WARD_FEET[0], WARD_FEET[1], rx, rx * 0.32, W_WHITE if i < 3 else W_GOLD, fade)
        ellipse_ring(cv, WARD_FEET[0], WARD_FEET[1], rx * 0.72, rx * 0.23, H_GOLD, 0.55 * fade, keep=lambda a, k: k % 2 == 0)
        # yukselen yaprak girdabi: yapraklar cember etrafinda esit dagilir, birlikte yukselip daralir
        for k in range(10):
            u = t * 1.3 - 0.05 * (k % 3)
            if u <= 0 or u > 1.15:
                continue
            phi = 2 * math.pi * k / 10 + u * 4.2
            r = 22 * (1 - 0.6 * u)
            x = 36 + r * math.cos(phi)
            y = WARD_FEET[1] - 4 - u * 58 + r * 0.32 * math.sin(phi)
            la = fade * (1.0 if u < 0.9 else 0.55)
            pal = (W_MINT, L_LIGHT, W_WHITE) if k % 3 else (W_GOLD, H_GOLD, W_GOLD)
            stamp(cv, leaf_pix(x, y, phi + math.pi / 2 + 0.6, 4.5, 1.6, pal, la), L_OUT, 0.8 * la)
        # tepede parlama
        if i >= n - 5:
            k = i - (n - 5)
            for dx, dy in N4:
                for s in range(1, 2 + (k % 3)):
                    cv.put(36 + dx * s, 18 + dy * s, W_WHITE if s == 1 else W_MINT, fade)
            cv.put(36, 18, W_WHITE, fade)
        frames.append(cv.image())
    save_rows("ward_cast", [("cast", frames, False, 18)])


# ============================================================================ onizleme
def _grass_tile(S):
    """Oyundaki duz cim tonu (Ground_grass.png ortalamasi) + harita pikseli (2 dunya birimi) boyunda benekler."""
    n = 64
    rnd = random.Random(5)
    t = Image.new("RGBA", (n, n), (100, 155, 81, 255))
    for _ in range(420):
        x, y = rnd.randrange(n), rnd.randrange(n)
        c = rnd.choice([(86, 136, 70), (86, 136, 70), (118, 172, 90), (74, 120, 62)])
        t.putpixel((x, y), c + (255,))
    return t.resize((int(n * 2.0 * S), int(n * 2.0 * S)), Image.NEAREST)


def preview(path):
    """Oyun olceginde (1 dunya birimi = 3 px) cim zemin uzerinde tum animasyonlar; Oakley boy karsilastirmasi icin."""
    S = 3.0
    tile = _grass_tile(S)
    oak = Image.open(os.path.join(ROOT, "assets", "characters", "oakley", "sheets", "idle.png")).convert("RGBA").crop((0, 0, 48, 48))
    oak_s = oak.resize((int(48 * 2.125 * S), int(48 * 2.125 * S)), Image.NEAREST)
    blocks = []
    for name, rows in PREVIEW.items():
        for an, frs, _loop, _fps in rows:
            picks = frs if len(frs) <= 8 else [frs[int(j * (len(frs) - 1) / 7)] for j in range(8)]
            w, h = picks[0].size
            cw, ch = int(w * TEXEL * S), int(h * TEXEL * S)
            blocks.append((name + ":" + an, [p.resize((cw, ch), Image.NEAREST) for p in picks]))
    pad = 8
    width = max(sum(im.width + pad for im in ims) for _n, ims in blocks) + pad
    width = min(width, 4200)
    heights = [max(im.height for im in ims) + 22 for _n, ims in blocks]
    H = sum(heights) + pad
    out = Image.new("RGBA", (width, H), (0, 0, 0, 255))
    for yy in range(0, H, tile.height):
        for xx in range(0, width, tile.width):
            out.paste(tile, (xx, yy))
    from PIL import ImageDraw
    dr = ImageDraw.Draw(out)
    y = pad
    for (name, ims), hh in zip(blocks, heights):
        dr.text((pad, y), name, fill=(255, 255, 255, 255))
        x = pad
        for im in ims:
            if x + im.width > width:
                break
            out.alpha_composite(im, (x, y + 14))
            x += im.width + pad
        y += hh
    out.save(path)
    # karakterle birlikte (R muhru + Q alani olcek kontrolu)
    comp = Image.new("RGBA", (900, 520), (0, 0, 0, 255))
    for yy in range(0, 520, tile.height):
        for xx in range(0, 900, tile.width):
            comp.paste(tile, (xx, yy))
    wb = PREVIEW["ward_back"][1][1][4]
    wf = PREVIEW["ward_front"][1][1][4]
    ws = (int(WARD_W * TEXEL * S), int(WARD_H * TEXEL * S))
    # karakter koku (0,0) = ward ayak (36,84) -> yerel +33
    ox, oy = 560, 60
    comp.alpha_composite(wb.resize(ws, Image.NEAREST), (ox, oy))
    feet_px = (ox + int(36 * TEXEL * S), oy + int(84 * TEXEL * S))
    char_root = (feet_px[0], feet_px[1] - int(33 * S))
    oak_pos = (char_root[0] - oak_s.width // 2, char_root[1] - int((24 + 1.8) * 2.125 * S))
    comp.alpha_composite(oak_s, oak_pos)
    comp.alpha_composite(wf.resize(ws, Image.NEAREST), (ox, oy))
    comp.save(path.replace(".png", "_scale.png"))
    print("preview:", path)


def main():
    bee_tiny()
    bee_sting()
    bee_swarm_burst()
    vine_seg()
    vine_head()
    vine_emerge()
    entangle()
    ward()
    ward_hit()
    ward_cast()
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])


if __name__ == "__main__":
    main()
