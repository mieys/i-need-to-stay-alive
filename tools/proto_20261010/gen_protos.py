"""2026-10-10 prototipleri (kullanıcı seçecek; seçilen sonra oyuna/spritesheet'e bağlanır):
 1) talon_ult.png   - Talon ultisi aktifken: kırmızı parıltı + kırmızı gözler + kendi rengi koyu siyah-kırmızı (2 prototip: A Kızıl Gölge, B Kor Kalp)
 2) sovalye_bubble.png - Şovalye ultisi koruma baloncuğu yerine 4 koruma büyüsü/bariyer (statik; seçilince spritesheet olarak anime edilecek)
 3) melek_heal.png  - Melek pasifi: kendisi ve takım arkadaşlarının üstünde ara ara minimalist iyileştirme efekti (4 prototip, 3'er kare)
Hepsi gerçek harita çimi üstünde, karakterlerin oyundaki piksel ölçeğinde (1 sanat px = 1 dünya px; karakter karesi x0,54), ekran için x3 büyütülmüş.
Kullanım (proje kökünden): python -I tools/proto_20261010/gen_protos.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)
GRASS = (126, 176, 84)
CHAR_SCALE = 0.54 * 0.85 * 2.0  ## sprite karesi oyunda ~0,92 dünya px / sanat px; burada 1:1'e yakın göstermek için x0,92


def font(sz):
    for c in (r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\arial.ttf'):
        if os.path.exists(c):
            return ImageFont.truetype(c, sz)
    return ImageFont.load_default()


def char_frame(name, col=0, row=0, size=48):
    sheet = Image.open(os.path.join(PROJECT, 'assets', 'characters', name, 'sheets', 'idle.png')).convert('RGBA')
    return sheet.crop((col * size, row * size, col * size + size, row * size + size))


def grass(w, h):
    img = Image.new('RGBA', (w, h), GRASS + (255,))
    rng = random.Random(4)
    px = img.load()
    for _ in range(w * h // 18):
        x, y = rng.randrange(w), rng.randrange(h)
        c = rng.choice([(116, 166, 76), (134, 184, 92), (110, 158, 72)])
        px[x, y] = c + (255,)
    return img


def label_sheet(panels, cols, title_h=34):
    """panels: [(başlık, Image)] -> tek görsel (x3)"""
    pw = max(p[1].width for p in panels) * 3
    ph = max(p[1].height for p in panels) * 3
    rows = (len(panels) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * (pw + 12) + 12, rows * (ph + title_h + 12) + 12), (24, 24, 28))
    d = ImageDraw.Draw(sheet)
    f = font(22)
    for i, (t, im) in enumerate(panels):
        cx = 12 + (i % cols) * (pw + 12)
        cy = 12 + (i // cols) * (ph + title_h + 12)
        d.text((cx, cy + 4), t, fill=(240, 236, 220), font=f)
        sheet.paste(im.resize((im.width * 3, im.height * 3), Image.NEAREST).convert('RGB'), (cx, cy + title_h))
    return sheet


# ------------------------------------------------------------------ 1) Talon ultisi
EYES = [(21, 17), (22, 17), (25, 17), (26, 17)]


def tint(fr, target, amount, keep_lum=True):
    out = fr.copy()
    px = out.load()
    for y in range(fr.height):
        for x in range(fr.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255.0
            tr = [int(c * (0.35 + 0.9 * lum)) if keep_lum else c for c in target]
            px[x, y] = (int(r + (tr[0] - r) * amount), int(g + (tr[1] - g) * amount), int(b + (tr[2] - b) * amount), a)
    return out


def outline(fr, color, width=1, alpha=255):
    w, h = fr.size
    src = fr.load()
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] > 0:
                continue
            near = False
            for dy in range(-width, width + 1):
                for dx in range(-width, width + 1):
                    if abs(dx) + abs(dy) > width:
                        continue
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < w and 0 <= yy < h and src[xx, yy][3] > 0:
                        near = True
            if near:
                op[x, y] = color + (alpha,)
    return out


def red_eyes(fr, glow_px, core=(255, 40, 40), glow=(255, 90, 60)):
    px = fr.load()
    for (x, y) in EYES:
        px[x, y] = core + (255,)
    gl = Image.new('RGBA', fr.size, (0, 0, 0, 0))
    gp = gl.load()
    for (x, y) in EYES:
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)) if glow_px else ():
            xx, yy = x + dx, y + dy
            if px[xx, yy][3] > 0 and (xx, yy) not in EYES:
                gp[xx, yy] = glow + (140,)
    return Image.alpha_composite(fr, gl)


def talon_variants():
    base = char_frame('talon')
    panels = []
    ## A - Kızıl Gölge: gövde koyu kızıl-siyaha boyanır (%65), 1 px kırmızı dış hat (yarı saydam) + 2. dış hat soluk, gözler kırmızı
    for k, a_glow in enumerate([0.85, 0.55]):
        g = grass(64, 64)
        fr = tint(base, (95, 18, 22), 0.65)
        fr = red_eyes(fr, True)
        o1 = outline(fr, (230, 40, 40), 1, int(220 * a_glow))
        o2 = outline(Image.alpha_composite(o1, fr), (200, 30, 30), 1, int(90 * a_glow))
        layer = Image.new('RGBA', g.size, (0, 0, 0, 0))
        layer.alpha_composite(o2, (8, 8)); layer.alpha_composite(o1, (8, 8)); layer.alpha_composite(fr, (8, 8))
        g.alpha_composite(layer)
        panels.append(('A · Kızıl Gölge' + (' (nabız)' if k else ''), g))
    ## B - Kor Kalp: gövde neredeyse siyah (%80, kontrast korunur), kenarlarda kızıl iç parlama (rim), altta kızıl zemin halkası, gözler beyaz-kırmızı akkor
    for k, pulse in enumerate([1.0, 0.6]):
        g = grass(64, 64)
        fr = tint(base, (40, 10, 14), 0.8)
        px = fr.load()
        w, h = fr.size
        for y in range(h):
            for x in range(w):
                if px[x, y][3] == 0:
                    continue
                edge = any(not (0 <= x + dx < w and 0 <= y + dy < h) or px[x + dx, y + dy][3] == 0 for dx, dy in ((1, 0), (0, -1)))
                if edge:
                    r, gg, b, a = px[x, y]
                    px[x, y] = (min(255, int(r + 150 * pulse)), int(gg + 20 * pulse), int(b + 18 * pulse), a)
        fr = red_eyes(fr, True, core=(255, 220, 200), glow=(255, 40, 30))
        ring = Image.new('RGBA', g.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(ring)
        cx, cy = 32, 8 + 41
        rr = 11 + (1 if pulse > 0.8 else 0)
        d.ellipse((cx - rr, cy - rr // 2, cx + rr, cy + rr // 2), outline=(220, 30, 30, int(170 * pulse)))
        for ang in range(0, 360, 45):
            a = math.radians(ang + (0 if pulse > 0.8 else 22))
            sx, sy = cx + math.cos(a) * (rr + 3), cy + math.sin(a) * (rr / 2 + 2) - 2
            ring.putpixel((int(sx), int(sy)), (255, 70, 40, int(200 * pulse)))
        g.alpha_composite(ring)
        layer = Image.new('RGBA', g.size, (0, 0, 0, 0)); layer.alpha_composite(fr, (8, 8))
        g.alpha_composite(layer)
        panels.append(('B · Kor Kalp' + (' (nabız)' if k else ''), g))
    orig = grass(64, 64); orig.alpha_composite(base, (8, 8))
    panels.insert(0, ('Şu anki Talon', orig))
    label_sheet(panels, 5).save(os.path.join(OUT, 'talon_ult.png'))


# ------------------------------------------------------------------ 2) Şovalye koruma baloncuğu (yarıçap 126 dünya px)
R = 126


def px_circle(d, cx, cy, r, color, step=1.0, squash=1.0, width=1):
    n = int(2 * math.pi * r / step)
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = round(cx + math.cos(a) * r), round(cy + math.sin(a) * r * squash)
        d.rectangle((x, y, x + width - 1, y + width - 1), fill=color)


def bubble_base():
    W = 2 * R + 40
    g = grass(W, W)
    kn = char_frame('sovalye')
    return g, kn, W // 2, W // 2


def bubble_a():  ## Kutsal Kalkan: altıgen ağlı kubbe, altın kenar, açık mavi dolgu
    g, kn, cx, cy = bubble_base()
    L = Image.new('RGBA', g.size, (0, 0, 0, 0)); d = ImageDraw.Draw(L)
    d.ellipse((cx - R, cy - R, cx + R, cy + R), fill=(140, 200, 255, 38))
    s = 14
    for row in range(-12, 13):
        for col in range(-12, 13):
            hx = cx + col * s * 1.5
            hy = cy + row * s * math.sqrt(3) + (s * math.sqrt(3) / 2 if col % 2 else 0)
            if math.hypot(hx - cx, hy - cy) > R - 6:
                continue
            pts = [(round(hx + s * math.cos(math.radians(60 * k))), round(hy + s * math.sin(math.radians(60 * k)))) for k in range(6)]
            fade = 1.0 - math.hypot(hx - cx, hy - cy) / R
            d.line(pts + [pts[0]], fill=(190, 230, 255, int(40 + 70 * (1 - fade))), width=1)
    px_circle(d, cx, cy, R, (255, 214, 110, 255), width=2)
    px_circle(d, cx, cy, R - 3, (255, 245, 200, 140))
    g.alpha_composite(L)
    g.alpha_composite(kn, (cx - 24, cy - 30))
    return g


def bubble_b():  ## Rün Halkası: ince çift halka, aralarında dönen rünler, çok soluk dolgu
    g, kn, cx, cy = bubble_base()
    L = Image.new('RGBA', g.size, (0, 0, 0, 0)); d = ImageDraw.Draw(L)
    d.ellipse((cx - R, cy - R, cx + R, cy + R), fill=(120, 170, 255, 22))
    px_circle(d, cx, cy, R, (150, 210, 255, 230), width=2)
    px_circle(d, cx, cy, R - 12, (150, 210, 255, 160))
    rng = random.Random(7)
    for i in range(24):
        a = 2 * math.pi * i / 24
        x, y = cx + math.cos(a) * (R - 6), cy + math.sin(a) * (R - 6)
        glyph = rng.choice(['I', 'V', 'X', 'L', 'T', 'Y'])
        for (gx, gy) in {'I': [(0, -2), (0, -1), (0, 0), (0, 1), (0, 2)], 'V': [(-1, -2), (-1, -1), (0, 0), (0, 1), (1, -1), (1, -2)],
                         'X': [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)], 'L': [(-1, -2), (-1, -1), (-1, 0), (-1, 1), (0, 1), (1, 1)],
                         'T': [(-1, -2), (0, -2), (1, -2), (0, -1), (0, 0), (0, 1)], 'Y': [(-1, -2), (1, -2), (0, -1), (0, 0), (0, 1)]}[glyph]:
            d.point((round(x + gx), round(y + gy)), fill=(220, 240, 255, 255))
    for k in range(4):  ## merkeze bakan 4 ışık çizgisi
        a = math.pi / 4 + k * math.pi / 2
        for t in range(10, R - 14, 3):
            d.point((round(cx + math.cos(a) * t), round(cy + math.sin(a) * t)), fill=(170, 220, 255, int(80 * (t / R))))
    g.alpha_composite(L)
    g.alpha_composite(kn, (cx - 24, cy - 30))
    return g


def bubble_c():  ## Kristal Kubbe: yüzeyli kristal, üçgen faset çizgileri, parlak parçalar
    g, kn, cx, cy = bubble_base()
    L = Image.new('RGBA', g.size, (0, 0, 0, 0)); d = ImageDraw.Draw(L)
    d.ellipse((cx - R, cy - R, cx + R, cy + R), fill=(120, 230, 240, 34))
    rng = random.Random(3)
    pts = [(cx, cy)]
    for i in range(10):
        a = 2 * math.pi * i / 10 + rng.uniform(-0.1, 0.1)
        pts.append((cx + math.cos(a) * R * 0.55, cy + math.sin(a) * R * 0.55))
    rim = [(cx + math.cos(2 * math.pi * i / 20) * R, cy + math.sin(2 * math.pi * i / 20) * R) for i in range(20)]
    for i in range(10):
        a, b = pts[1 + i], pts[1 + (i + 1) % 10]
        d.line([pts[0], a], fill=(200, 250, 255, 90))
        d.line([a, b], fill=(200, 250, 255, 120))
        d.line([a, rim[2 * i]], fill=(200, 250, 255, 90)); d.line([a, rim[2 * i + 1]], fill=(200, 250, 255, 70))
    d.polygon(rim, outline=(140, 245, 255, 255))
    for (sx, sy) in [(-0.45, -0.55), (-0.3, -0.62), (0.5, -0.3)]:  ## parlak parçalar
        x, y = cx + sx * R, cy + sy * R
        d.polygon([(x, y - 5), (x + 3, y), (x, y + 5), (x - 3, y)], fill=(240, 255, 255, 200))
    g.alpha_composite(L)
    g.alpha_composite(kn, (cx - 24, cy - 30))
    return g


def bubble_d():  ## Işık Sütunları: zeminde soluk daire + çevrede 8 ışık sütunu + aralarında ince ışık perdesi
    g, kn, cx, cy = bubble_base()
    L = Image.new('RGBA', g.size, (0, 0, 0, 0)); d = ImageDraw.Draw(L)
    d.ellipse((cx - R, cy - R, cx + R, cy + R), fill=(255, 235, 170, 26))
    px_circle(d, cx, cy, R, (255, 230, 150, 150))
    cols = []
    for i in range(8):
        a = 2 * math.pi * i / 8 + math.pi / 8
        x, y = round(cx + math.cos(a) * R), round(cy + math.sin(a) * R)
        cols.append((x, y))
    for i in range(8):  ## perde: komşu sütun tepeleri arasında soluk ışık
        (x1, y1), (x2, y2) = cols[i], cols[(i + 1) % 8]
        d.line([(x1, y1 - 26), (x2, y2 - 26)], fill=(255, 240, 190, 70))
    for (x, y) in cols:
        d.rectangle((x - 2, y - 30, x + 2, y), fill=(255, 236, 170, 120))
        d.rectangle((x - 1, y - 34, x + 1, y), fill=(255, 250, 225, 230))
        d.ellipse((x - 4, y - 2, x + 4, y + 2), fill=(255, 220, 120, 160))
    g.alpha_composite(L)
    g.alpha_composite(kn, (cx - 24, cy - 30))
    return g


# ------------------------------------------------------------------ 3) Melek pasifi iyileştirme efekti
def melek_scene(effect, t):
    g = grass(110, 70)
    me = char_frame('melek'); ally = char_frame('elara')
    g.alpha_composite(me, (6, 14)); g.alpha_composite(ally, (56, 14))
    L = Image.new('RGBA', g.size, (0, 0, 0, 0))
    for (hx, hy) in ((30, 22), (80, 22)):  ## baş üstü noktaları
        effect(L, hx, hy, t)
    g.alpha_composite(L)
    return g


def eff_plus(L, hx, hy, t):  ## Artı Işıltısı: 2 küçük yeşil-beyaz artı (5x5, koyu kontursuz) yükselir ve söner
    d = ImageDraw.Draw(L)
    for k, (ox, ph) in enumerate(((-7, 0.0), (6, 0.45))):
        tt = (t + ph) % 1.0
        y = round(hy + 10 - tt * 16)
        a = int(255 * math.sin(tt * math.pi))
        x = hx + ox
        for (dx, dy) in ((0, -2), (0, -1), (-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0), (0, 1), (0, 2)):
            d.point([(x + dx, y + dy)], fill=(120, 235, 140, a))
        d.point([(x, y)], fill=(240, 255, 240, a))
        d.point([(x, y - 1), (x - 1, y)], fill=(200, 255, 210, a))


def eff_halo(L, hx, hy, t):  ## Hale Nabzı: başın üstünde altın hale (2 px), nabızla genişleyip söner + tepede küçük ışık
    d = ImageDraw.Draw(L)
    r = 5 + t * 7
    a = int(240 * (1 - t))
    d.ellipse((hx - r, hy - 5 - r / 3, hx + r, hy - 5 + r / 3), outline=(255, 220, 110, a), width=2)
    if t < 0.45:
        d.point([(hx, hy - 9), (hx - 1, hy - 8), (hx + 1, hy - 8), (hx, hy - 7)], fill=(255, 250, 220, 230))


def eff_feather(L, hx, hy, t):  ## Tüy Süzülmesi: 2 beyaz tüy (5 px) salınarak iner; yere yaklaşınca parıltıya dönüşür
    d = ImageDraw.Draw(L)
    for k, ph in enumerate((0.0, 0.5)):
        tt = (t + ph) % 1.0
        x = round(hx + (-7 if k == 0 else 7) + math.sin(tt * 6.0) * 3)
        y = round(hy - 8 + tt * 20)
        a = int(255 * min(1.0, (1 - tt) * 2.2))
        d.line([(x - 2, y - 2), (x + 2, y + 2)], fill=(250, 250, 255, a))
        d.point([(x - 1, y - 2), (x + 2, y + 1), (x, y - 1)], fill=(205, 215, 250, a))
        if tt > 0.7:
            d.point([(x, y + 4), (x - 1, y + 5), (x + 1, y + 5), (x, y + 6)], fill=(255, 245, 190, int(255 * (tt - 0.7) / 0.3)))


def eff_motes(L, hx, hy, t):  ## Işık Zerreleri: gövde çevresinde sarmal yükselen 4 altın zerre (2x2 + iz)
    d = ImageDraw.Draw(L)
    for k in range(4):
        tt = (t + k / 4.0) % 1.0
        a = tt * 2 * math.pi * 1.2 + k * 1.6
        x = round(hx + math.cos(a) * 11)
        y = round(hy + 26 - tt * 34)
        al = int(255 * math.sin(tt * math.pi))
        d.rectangle((x, y, x + 1, y + 1), fill=(255, 232, 130, al))
        d.point([(x, y + 2), (x + 1, y + 3)], fill=(255, 200, 90, al // 2))


def melek_variants():
    panels = []
    for name, eff in (('A · Artı Işıltısı', eff_plus), ('B · Hale Nabzı', eff_halo), ('C · Tüy Süzülmesi', eff_feather), ('D · Işık Zerreleri', eff_motes)):
        for t in (0.15, 0.5, 0.8):
            panels.append(('%s  t=%.2f' % (name, t), melek_scene(eff, t)))
    label_sheet(panels, 3).save(os.path.join(OUT, 'melek_heal.png'))


if __name__ == '__main__':
    talon_variants()
    label_sheet([('A · Kutsal Kalkan', bubble_a()), ('B · Rün Halkası', bubble_b()), ('C · Kristal Kubbe', bubble_c()), ('D · Işık Sütunları', bubble_d())], 2).save(
        os.path.join(OUT, 'sovalye_bubble.png'))
    melek_variants()
    print('tamam')
