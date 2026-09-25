"""Suriyeli Hadime (karakter 14) yetenek efektleri - pixel-art sprite sayfalari -> assets/fx/hadime/

Kullanici istegi (2026-09-25): yeni karakter Suriyeli Hadime + "efektleri spritesheete donustur yoksa performans kaybi
olur". Hicbir efekt her karede _draw() ile cizilmez: hepsi burada bir kez uretilen sayfalardan AnimatedSprite2D ile oynar
(hareket eden efektlerde sadece dugumun KONUMU script'le degisir - bkz. scripts/fx_hadime_curse.gd).

Hepsi 1 sanat pikseli = TEXEL 1.212 yerel birim (projedeki FX dili, bkz. hafiza "pixel density 48"): 1 piksel kontur,
1 piksel parlamalar, iri blok yok. Kareler PNG + SpriteFrames .tres (tools/gen_perf_sprite_fx_tres.write_sprite_frames).

  Q  Lanet Kitabi
     curse_orb     (16x16,  6 kare, 12 fps, dongu)    kitaptan yukari firlayip yaratiga dusen lanet kuresi
     curse_mote    ( 8x8,   5 kare, 16 fps, tek)      kurenin arkasinda biraktigi kivilcim izi
     curse_launch  (24x24,  6 kare, 20 fps, tek)      kitaptan cikis parlamasi
     curse_impact  (48x40, 11 kare, 20 fps, tek)      yaratiga dusus: yesil cizgi + zemin rune halkasi + mor duman
     levitate      (48x32, 12 kare, 12 fps, dongu)    kanal boyunca havada suzulen Hadime'nin ayak altinda karanlik
                                                      ucma efekti (kullanici istegi 2026-09-25)
  E  Kara Delik (2026-09-25 ikinci istek: ilk tasarim "Kara Buyu" ve kalkan zerreleri kaldirildi - "kalkan cekme efektine
     gerek yok")
     black_hole    (192x96, giris 8 / dongu 16 / cokus 8 kare - uc satir)  zeminde donen mor birikim diski, ortada kara
                   kure + ustunde bukulen isik halkasi, HOLE_RADIUS halkasindan kureye sarmal cizerek akan zerreler
  R  Karabasan
     nightmare_aura  (180x96, 16 kare, 10 fps, dongu) ayak altinda karanlik havuz + disa uzanip cekilen golge pencelerı
     nightmare_burst (128x96, 11 kare, 18 fps, tek)   donusum anindaki kara duman patlamasi
  Pasif (hayalet): efekt sayfasi YOK - kullanici istegi: "hayalet formu Hadime'nin kendisi, sadece yari saydam hali"
     (karakterin kendi kareleri; kalkis = olum klibinin tersi "ghostrise_<yon>", bkz. import_character_sheets.py).

Calistir: python tools/gen_hadime_fx.py   (sonra Godot --headless --import; yepyeni sayfalar icin 2 import gerekebilir)
"""

import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "hadime")
RES = "res://assets/fx/hadime/"

# --- lanet: mor + hastalikli yesil (Hadime'nin yesil gozleri / koyu mor-siyah cubbesi) ---
V_OUT = (18, 6, 26)
V_DEEP = (42, 15, 58)
V_MID = (91, 42, 134)
V_LIGHT = (150, 92, 204)
G_DEEP = (34, 96, 34)
G_MID = (111, 220, 74)
G_LIGHT = (200, 255, 154)
G_WHITE = (240, 255, 226)
# --- karabasan: siyah-mor duman ---
N_BLACK = (8, 4, 12)
N_DEEP = (24, 11, 33)
N_MID = (46, 21, 60)
N_EDGE = (80, 40, 100)

TAU = 2 * math.pi


def q_alpha(a):
    """Az sayida alfa seviyesi (pixel dili): 0 / .3 / .55 / .8 / 1."""
    for lv in (1.0, 0.8, 0.55, 0.3):
        if a >= lv - 0.12:
            return lv
    return 0.0


def plot(img, x, y, col, a=1.0, over=False):
    """over=False: zaten daha opak bir piksel varsa ezmez (katmanlar birbirini sondurmesin)."""
    x, y = int(round(x)), int(round(y))
    if not (0 <= x < img.width and 0 <= y < img.height):
        return
    a = q_alpha(a)
    if a <= 0:
        return
    if not over:
        old = img.getpixel((x, y))
        if old[3] > int(255 * a):
            return
    img.putpixel((x, y), col + (int(255 * a),))


def disc(img, cx, cy, r, col, a=1.0, over=True, ry=None):
    ry = r if ry is None else ry
    if r <= 0 or ry <= 0:
        return
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if ((x + 0.5 - cx) / r) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                plot(img, x, y, col, a, over)


def ring(img, cx, cy, rx, ry, col, a=1.0, over=True, gap=None):
    """1 piksel kalin elips halka. gap: (a0, a1) radyan araligi cizilmez."""
    if rx <= 0.5 or ry <= 0.5:
        plot(img, cx, cy, col, a, over)
        return
    n = max(24, int(TAU * max(rx, ry) * 1.6))
    for i in range(n):
        t = TAU * i / n
        if gap is not None and gap[0] <= t <= gap[1]:
            continue
        plot(img, cx + rx * math.cos(t), cy + ry * math.sin(t), col, a, over)


def line(img, x0, y0, x1, y1, col, a=1.0, over=True):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n + 1):
        t = i / max(1, n)
        plot(img, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, col, a, over)


def spark(img, cx, cy, arm, core, armcol, a=1.0):
    plot(img, cx, cy, core, a, True)
    for i in range(1, arm + 1):
        f = a * (1.0 - 0.25 * (i - 1))
        for dx, dy in ((i, 0), (-i, 0), (0, i), (0, -i)):
            plot(img, cx + dx, cy + dy, armcol, f)


def outline(img, col, a=1.0):
    """Opak piksellerin disina 1 px kontur (bos komsulara)."""
    src = img.copy()
    px = src.load()
    w, h = src.size
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0:
                continue
            near = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] >= 200:
                    near = True
                    break
            if near:
                img.putpixel((x, y), col + (int(255 * q_alpha(a)),))


def fade_img(img, k):
    """Tum pikselleri k (0..1) ile soluklastir (alfa seviyeleri yine az sayida kalir)."""
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, al = px[x, y]
            if al:
                na = q_alpha(al / 255.0 * k)
                px[x, y] = (r, g, b, int(255 * na)) if na > 0 else (0, 0, 0, 0)


def sheet(frames):
    w, h = frames[0].size
    s = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (i * w, 0))
    return s


def save(name, frames, anim, loop, fps):
    os.makedirs(OUT, exist_ok=True)
    sheet(frames).save(os.path.join(OUT, name + "_sheet.png"))
    w, h = frames[0].size
    write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), RES + name + "_sheet.png", w, h,
                        [(anim, (0, 0), len(frames), loop, fps)])
    print("   %-16s %dx%d x %d kare" % (name, w, h, len(frames)))


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


# ====================================================================== Q - curse_orb (dongu)
def curse_orb():
    frames = []
    n = 6
    for i in range(n):
        im = new(16, 16)
        cx, cy = 7.5, 7.5
        pulse = 0.5 + 0.5 * math.cos(TAU * i / n)
        disc(im, cx, cy, 4.6, V_MID)
        disc(im, cx - 0.8, cy - 0.8, 2.2, V_LIGHT)
        disc(im, cx, cy, 2.4 + 0.5 * pulse, G_MID)
        disc(im, cx, cy, 1.2 + 0.4 * pulse, G_LIGHT)
        plot(im, cx - 0.5, cy - 0.5, G_WHITE, 1.0, True)
        # kurenin etrafinda donen 3 yesil kivilcim (2*pi/3 simetrisi: 6 karede tam tur gerekmez)
        for k in range(3):
            t = TAU * (i / n) / 3.0 + TAU * k / 3.0
            plot(im, cx + 6.0 * math.cos(t), cy + 6.0 * math.sin(t) * 0.8, G_LIGHT, 1.0, True)
        outline(im, V_OUT, 0.8)
        frames.append(im)
    save("curse_orb", frames, "loop", True, 12.0)


def curse_mote():
    frames = []
    for i in range(5):
        im = new(8, 8)
        if i == 0:
            spark(im, 3.5, 3.5, 2, G_WHITE, G_LIGHT)
        elif i == 1:
            spark(im, 3.5, 3.5, 1, G_LIGHT, G_MID)
        elif i == 2:
            spark(im, 3.5, 3.5, 1, G_MID, V_LIGHT, 0.8)
        elif i == 3:
            plot(im, 3.5, 3.5, V_LIGHT, 0.55)
        else:
            plot(im, 3.5, 3.5, V_MID, 0.3)
        frames.append(im)
    save("curse_mote", frames, "mote", False, 16.0)


def curse_launch():
    frames = []
    n = 6
    for i in range(n):
        im = new(24, 24)
        t = i / (n - 1)
        cx, cy = 11.5, 13.5
        r = 2 + 8 * (1 - (1 - t) ** 2)
        a = 1.0 - t * 0.85
        col = G_WHITE if t < 0.2 else (G_LIGHT if t < 0.5 else (G_MID if t < 0.8 else V_LIGHT))
        ring(im, cx, cy, r, r * 0.7, col, a)
        if i < 3:
            disc(im, cx, cy, 2.5 - i * 0.7, G_WHITE if i == 0 else G_LIGHT, 1.0)
        # yukari kivrilan 3 kisa isin (lanet yukari firliyor)
        for k, dx in enumerate((-4, 0, 4)):
            ln = 3 + 5 * t
            y0 = cy - 3 - 6 * t
            line(im, cx + dx * (0.5 + t), y0, cx + dx * (0.7 + t), y0 - ln, G_LIGHT if k == 1 else G_MID, a * 0.9)
        frames.append(im)
    save("curse_launch", frames, "burst", False, 20.0)


def curse_impact():
    frames = []
    n = 11
    gx, gy = 23.5, 30.0
    rng = [(-9, 1.4, 0.0), (7, 1.1, 0.12), (-2, 1.7, 0.2), (11, 1.2, 0.3), (-12, 1.0, 0.35)]
    for i in range(n):
        im = new(48, 40)
        t = i / (n - 1)
        # 1) dusen yesil cizgi (ilk 2 kare)
        if i <= 1:
            top = 0 if i == 0 else 14
            for y in range(top, int(gy)):
                w = 1 if y < gy - 6 else 2
                for dx in range(-w + 1, w):
                    plot(im, gx + dx, y, G_LIGHT if abs(dx) == 0 else G_MID, 1.0 if y > top + 3 else 0.55)
            plot(im, gx, gy - 1, G_WHITE, 1.0, True)
        # 2) zemin halkasi + 4 rune (kare 1-8)
        if 1 <= i <= 8:
            k = (i - 1) / 7.0
            rx = 5 + 11 * (1 - (1 - k) ** 2)
            ry = rx * 0.42
            a = 1.0 if k < 0.5 else 1.0 - (k - 0.5) * 1.6
            ring(im, gx, gy, rx, ry, G_LIGHT if k < 0.3 else G_MID, a)
            ring(im, gx, gy, rx - 2, ry - 1, V_MID, a * 0.8)
            for j in range(4):
                ang = TAU * j / 4 + k * 0.6
                rxj, ryj = gx + (rx + 1) * math.cos(ang), gy + (ry + 1) * math.sin(ang)
                for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                    plot(im, rxj + dx, ryj + dy, V_LIGHT, a)
                plot(im, rxj, ryj, G_WHITE if k < 0.4 else G_LIGHT, a, True)
            if i <= 3:
                disc(im, gx, gy - 1, 4 - i, G_WHITE if i <= 2 else G_LIGHT, 1.0, ry=2.2 - i * 0.4)
        # 3) yukselen mor duman (kare 3-10)
        if i >= 3:
            k = (i - 3) / 7.0
            for (dx, sp, off) in rng:
                kk = max(0.0, min(1.0, k * 1.1 - off))
                if kk <= 0:
                    continue
                px = gx + dx * (0.5 + 0.5 * kk)
                py = gy - 2 - 16 * kk * sp
                r = 2.6 - 1.4 * kk
                a = 0.9 - 0.8 * kk
                disc(im, px, py, r, V_MID if kk < 0.5 else V_DEEP, a, over=False)
                plot(im, px - 1, py - 1, V_LIGHT, a * 0.9)
        frames.append(im)
    save("curse_impact", frames, "burst", False, 20.0)


# ====================================================================== E - black_hole (giris / dongu / cokus)
HOT = (255, 222, 250)   # diskin en sicak (ic kenar) tonu
PINK = (222, 128, 236)


def draw_hole(im, cx, cy, k, ph, part_a, flash=0.0):
    """Tek kare kara delik. k = boyut (0..1, giris/cokus), ph = donme fazi (dongu: 2pi'de kapanir), part_a = iceri akan
    zerrelerin gorunurlugu. Zemin duzleminde (y x 0.45) elips disk; kure diskin merkezinde, biraz yukarida."""
    if k <= 0.02:
        return
    ey = 0.45
    # 0) cekim alaninin siniri (HOLE_RADIUS ~ 90 sanat px): yavasca donen kesikli halka - alan okunsun
    if part_a > 0:
        rxo, ryo = 88 * k, 88 * ey * k
        n = int(TAU * rxo * 1.2)
        for i in range(n):
            a = TAU * i / n
            if int((a - ph / 3.0) / (TAU / 36)) % 2 == 0:
                plot(im, cx + rxo * math.cos(a), cy + ryo * math.sin(a), V_MID, 0.55 * part_a)
    # 1) zeminde cekimin kararttigi alan (seyrek dama)
    rx, ry = 44 * k, 44 * k * ey
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            e = ((x + 0.5 - cx) / max(rx, 0.5)) ** 2 + ((y + 0.5 - cy) / max(ry, 0.5)) ** 2
            if e < 0.5:
                plot(im, x, y, N_DEEP, 0.55)
            elif e < 1.0 and ((x + y) & 1) == 0:
                plot(im, x, y, N_DEEP, 0.3)
    # 2) iceri sarmal cizerek akan zerreler (alan sinirindan kureye) - her biri kendi fazinda, dongu 1 turda kapanir
    if part_a > 0:
        n_parts = 26
        for j in range(n_parts):
            th0 = TAU * j / n_parts + (j % 3) * 0.37
            off = (j * 11 % n_parts) / n_parts
            u = (ph / TAU + off) % 1.0
            for tail in range(5):
                uu = max(0.0, u - tail * 0.022)
                r = 15 + 72 * (1 - uu) ** 1.2
                th = th0 + 2.4 * uu
                px = cx + r * math.cos(th) * k
                py = cy + r * math.sin(th) * ey * k
                near = 1 - (r - 15) / 72
                col = HOT if near > 0.8 else (PINK if near > 0.4 else V_LIGHT)
                a = part_a * (0.8 + 0.2 * near) * (1.0 - tail * 0.18)
                plot(im, px, py, col if tail < 2 else V_MID, a)
    # 3) birikim diski: arka yari (kurenin ARKASINDA kalan), sonra kure, sonra on yari
    def disk(front):
        for rr in (23.0, 25.0, 27.0, 29.0, 31.0):
            rxd, ryd = rr * k, rr * ey * k
            n = max(24, int(TAU * rxd * 1.5))
            for i in range(n):
                a = TAU * i / n
                if (math.sin(a) > 0) != front:
                    continue
                lobe = 0.5 + 0.5 * math.cos(3 * (a - ph))
                inner = (31.0 - rr) / 8.0
                t = min(1.0, 0.35 * lobe + 0.65 * inner)
                col = HOT if t > 0.85 else (PINK if t > 0.6 else (V_LIGHT if t > 0.35 else V_MID))
                plot(im, cx + rxd * math.cos(a), cy + ryd * math.sin(a), col, 1.0 if t > 0.35 else 0.8, True)
    disk(False)
    # 4) kure (olay ufku) + ustunde bukulen isik halkasi (diskin arka yuzunun kure uzerinden gorunen goruntusu)
    sr = 11.0 * k
    scy = cy - 4 * k
    ring(im, cx, scy - 0.5, sr + 4.0 * k, sr + 2.6 * k, V_LIGHT, 0.8, gap=(0.2, math.pi - 0.2))
    disc(im, cx, scy, sr + 1.0, V_OUT, 1.0)
    disc(im, cx, scy, sr, N_BLACK, 1.0)
    ring(im, cx, scy, sr + 1.0, sr + 1.0, PINK, 0.8, gap=(0.35, math.pi - 0.35))
    disk(True)
    if flash > 0:
        spark(im, cx, scy, 3, HOT, PINK, flash)


def black_hole():
    w, h = 192, 96
    cx, cy = 95.5, 50.0
    intro, loop, outro = [], [], []
    for i in range(8):                       # giris: noktadan buyur (0.4 sn)
        t = i / 7.0
        im = new(w, h)
        draw_hole(im, cx, cy, 1 - (1 - t) ** 2, 0.0, t * t, flash=1.0 if i < 3 else 0.0)
        intro.append(im)
    for i in range(16):                      # dongu: disk doner, zerreler iceri akar (1.33 sn'de bir tur)
        im = new(w, h)
        draw_hole(im, cx, cy, 1.0, TAU * i / 16, 1.0)
        loop.append(im)
    for i in range(8):                       # cokus: iceri kapanir, en sonda parlayip genisleyen sok halkasi
        t = i / 7.0
        im = new(w, h)
        if i < 5:
            draw_hole(im, cx, cy, 1 - (t * 1.35) ** 2 if t * 1.35 < 1 else 0.0, TAU * t * 0.5, max(0.0, 1 - t * 2))
        if i >= 4:
            u = (i - 4) / 3.0
            ring(im, cx, cy - 2, 6 + 30 * u, (6 + 30 * u) * 0.45, PINK if u < 0.5 else V_LIGHT, 1.0 - u * 0.7)
            if i == 4:
                spark(im, cx, cy - 3, 4, HOT, PINK)
        outro.append(im)
    os.makedirs(OUT, exist_ok=True)
    s = Image.new("RGBA", (w * 16, h * 3), (0, 0, 0, 0))
    for row, frames in enumerate((intro, loop, outro)):
        for i, f in enumerate(frames):
            s.paste(f, (i * w, row * h))
    s.save(os.path.join(OUT, "black_hole_sheet.png"))
    write_sprite_frames(os.path.join(OUT, "black_hole_frames.tres"), RES + "black_hole_sheet.png", w, h,
                        [("intro", (0, 0), 8, False, 20.0), ("loop", (0, 1), 16, True, 12.0), ("outro", (0, 2), 8, False, 16.0)])
    print("   %-16s %dx%d x 8+16+8 kare" % ("black_hole", w, h))


def levitate():
    """Q kanali: havada suzulen Hadime'nin ayaklari altinda karanlik ucma efekti - zeminde donen kara duman topaklari,
    ayaklardan zemine suzulen koyu mor zerreler (birkac yesil kivilcim) ve altta hafif karanlik pus. 12 karelik dikissiz
    dongu (tum periyotlar 12 karenin tam bolenleri)."""
    frames = []
    n = 12
    cx, gy = 23.5, 20.0
    drops = [(-7, 0.0, V_MID), (5, 0.17, N_EDGE), (-2, 0.33, V_MID), (8, 0.5, G_MID), (-9, 0.58, N_EDGE),
             (2, 0.75, V_MID), (-4, 0.83, G_MID), (10, 0.92, N_EDGE)]
    for i in range(n):
        im = new(48, 32)
        ph = TAU * i / n
        # 1) zeminde karanlik pus
        for y in range(int(gy - 4), int(gy + 6)):
            for x in range(int(cx - 15), int(cx + 16)):
                e = ((x + 0.5 - cx) / 13.0) ** 2 + ((y + 0.5 - gy - 1) / 4.5) ** 2
                if e < 0.5:
                    plot(im, x, y, N_DEEP, 0.55)
                elif e < 1.0 and ((x + y) & 1) == 0:
                    plot(im, x, y, N_DEEP, 0.3)
        # 2) ayaklardan zemine suzulen zerreler (her biri kendi fazinda asagi ve disa)
        for (dx, off, col) in drops:
            u = (i / n + off) % 1.0
            px = cx + dx * (0.35 + 0.65 * u)
            py = gy - 7 + 9 * u
            plot(im, px, py, col, 0.9 * (1.0 - u) + 0.1)
            if u < 0.5:
                plot(im, px, py - 1, col, 0.55 * (1.0 - u))
        # 3) ayak hizasinin hemen altinda donen kara duman topaklari
        for k in range(7):
            a = TAU * k / 7 + ph
            px = cx + 11 * math.cos(a)
            py = gy - 2 + 3.2 * math.sin(a)
            r = 2.2 + 0.7 * math.sin(2 * ph + k)
            disc(im, px, py, r, N_MID, 0.8, over=False)
            plot(im, px - 1, py - 1, N_EDGE, 0.8)
        frames.append(im)
    save("levitate", frames, "loop", True, 12.0)


# ====================================================================== R - nightmare_aura (dongu, zemin)
def nightmare_aura():
    frames = []
    n = 16
    gx, gy = 89.5, 64.0
    prx, pry = 30.0, 11.0
    claws = [(0.15, 62, 1), (0.95, 54, -1), (1.75, 70, 1), (2.55, 50, -1), (3.4, 66, 1), (4.2, 58, -1),
             (5.05, 72, 1), (5.7, 52, -1)]
    wisps = [(-14, 0.0), (9, 0.37), (-3, 0.71), (17, 0.18), (-20, 0.55), (4, 0.86), (-9, 0.28), (13, 0.63)]
    for i in range(n):
        im = new(180, 96)
        ph = TAU * i / n
        # 1) karanlik havuz: kenari dalgalanan elips (dongu: faz 2pi/16 adimla)
        for y in range(int(gy - pry - 3), int(gy + pry + 4)):
            for x in range(int(gx - prx - 5), int(gx + prx + 6)):
                ang = math.atan2((y + 0.5 - gy) / pry, (x + 0.5 - gx) / prx)
                wob = 1.0 + 0.09 * math.sin(3 * ang + ph) + 0.05 * math.sin(5 * ang - 2 * ph)
                e = math.sqrt(((x + 0.5 - gx) / prx) ** 2 + ((y + 0.5 - gy) / pry) ** 2) / wob
                if e < 0.62:
                    plot(im, x, y, N_BLACK, 0.8)
                elif e < 0.86:
                    plot(im, x, y, N_DEEP, 0.8)
                elif e < 1.0 and ((x + y) & 1) == 0:
                    plot(im, x, y, N_MID, 0.55)
        # 2) golge pencelerı: havuzdan zeminde disa uzanip geri cekilir (her biri kendi fazinda)
        for k, (ang, reach, curl_dir) in enumerate(claws):
            ext = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(ph + k * 1.9))
            length = reach * ext
            steps = int(length * 1.2)
            last = None
            for s in range(steps + 1):
                u = s / max(1, steps)
                curl = curl_dir * 0.35 * u * u
                a2 = ang + curl
                dist = prx * 0.8 + (length - prx * 0.8) * u if length > prx * 0.8 else prx * 0.8 * u
                px = gx + math.cos(a2) * dist
                py = gy + math.sin(a2) * dist * 0.42
                width = 2 if u < 0.55 else 1
                col = N_DEEP if u < 0.7 else N_MID
                for wdx in range(width):
                    plot(im, px, py + wdx, col, 0.8)
                last = (px, py, a2)
            if last is not None:
                # uc: 3 kucuk tirnak
                px, py, a2 = last
                for f in (-0.6, 0.0, 0.6):
                    fx = px + math.cos(a2 + f) * 3
                    fy = py + math.sin(a2 + f) * 3 * 0.42
                    line(im, px, py, fx, fy, N_EDGE, 0.8)
        # 3) havuzdan yukselen kara dumanlar (her biri dongu boyunca yukari kayar, sonra basa doner)
        for (dx, off) in wisps:
            u = (i / n + off) % 1.0
            px = gx + dx + math.sin(TAU * u + dx) * 1.5
            py = gy - 3 - u * 34
            r = 2.4 - 1.4 * u
            a = 0.8 if u < 0.5 else 0.8 - (u - 0.5) * 1.6
            disc(im, px, py, r, N_MID if u < 0.6 else N_DEEP, a, over=False)
            plot(im, px - 1, py - 1, N_EDGE, a * 0.9)
        # 4) havuzda seyrek yesil goz kirpmalari
        for (dx, dy, off) in ((-12, 1, 0.0), (15, -2, 0.5)):
            v = 0.5 + 0.5 * math.cos(ph + off * TAU)
            if v > 0.55:
                plot(im, gx + dx, gy + dy, G_MID, v)
                plot(im, gx + dx + 2, gy + dy, G_MID, v)
        frames.append(im)
    save("nightmare_aura", frames, "loop", True, 10.0)


def nightmare_burst():
    frames = []
    n = 11
    gx, gy = 63.5, 70.0
    for i in range(n):
        im = new(128, 96)
        t = i / (n - 1)
        grow = 1 - (1 - t) ** 2
        fade = 1.0 if t < 0.55 else max(0.0, 1 - (t - 0.55) / 0.45)
        # sok halkasi
        if i < 7:
            rx = 8 + 46 * grow
            ring(im, gx, gy, rx, rx * 0.42, N_EDGE, 1.0 - t)
        # disa savrulan duman topaklari: iki halka, boy/aci/mesafe topak basina sabit ama DUZENSIZ (boncuk dizisi gibi
        # gorunmesin); koyu cekirdek + ust-sol kenarda mor isik
        for ring_i, (cnt, reach, base_r) in enumerate(((12, 40.0, 5.0), (7, 22.0, 3.6))):
            for k in range(cnt):
                j = (k * 37 + ring_i * 11) % 7 / 6.0
                ang = TAU * k / cnt + 0.13 + (j - 0.5) * 0.35
                d = (6 + reach * grow) * (0.8 + 0.3 * ((k * 53 + ring_i) % 5) / 4.0)
                px = gx + math.cos(ang) * d
                py = gy + math.sin(ang) * d * 0.42 - (6 + 4 * j) * grow
                r = (base_r + 2.2 * j) * (1.0 - 0.55 * t)
                disc(im, px, py, r, N_DEEP, fade, over=False)
                disc(im, px - 0.8, py - 0.8, max(0.8, r - 1.4), N_MID, fade, over=False)
                plot(im, px - r * 0.5, py - r * 0.6, N_EDGE, fade * 0.9)
        # yukari kalkan kara duman kivrimlari (govdeyi saran karanlik)
        for k, dx in enumerate((-10, -4, 3, 9)):
            h = 10 + 38 * grow * (0.8 + 0.2 * (k % 2))
            for y in range(int(gy - h), int(gy - 2)):
                u = (gy - y) / max(1.0, h)
                plot(im, gx + dx + math.sin(u * 6 + k) * 1.5, y, N_DEEP if u < 0.6 else N_MID, fade * (0.8 - u * 0.5), over=False)
        # merkez: siyah cekirdek + ilk karelerde yesil parlama
        disc(im, gx, gy, 10 * (1 - t) + 2, N_BLACK, fade * 0.8, ry=(10 * (1 - t) + 2) * 0.45, over=False)
        if i < 3:
            spark(im, gx, gy - 4, 3 - i, G_WHITE, G_MID)
        frames.append(im)
    save("nightmare_burst", frames, "burst", False, 18.0)


if __name__ == "__main__":
    print("Hadime FX ->", os.path.relpath(OUT, ROOT))
    curse_orb()
    curse_mote()
    curse_launch()
    curse_impact()
    levitate()
    black_hole()
    nightmare_aura()
    nightmare_burst()
