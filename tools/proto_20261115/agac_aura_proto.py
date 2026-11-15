"""2026-11-15 prototipi: Oakley R "Hayat Ağacı" AURASI (kullanıcı: "oakleyin ağacının aurası çok kötü bir efekte sahip").
Teşhis (madde 655): alan sanatı 169 x 84,5'te çizili, ekranda ZONE_VISUAL_SCALE = 350/169 = 2,07 ile NEAREST büyütülüyor ->
düz sarı elips çıkartması + kalın basamaklı kenar bandı + 2 kat kalın/uzun ışık çizgileri (oyundaki diğer her şey 1 sanat px).
OYUNA BAĞLI DEĞİL. Yönler:
  0 Şimdiki        oyundaki gibi (alan.png + isik_*.png x2,07 NEAREST)
  A Yumuşak Işık   kontursuz, düz alfa bantlı sıcak ışık havuzu: ağacın dibinde yoğun, kenara doğru basamaklarla söner; kenarda
                   nefes alan bantlı halka (sınır okunur, çizgi yok) + yükselen altın pırıltı.
  B Yaprak Halkası çiçeğin Yaprak Halkası (madde 316) büyük ölçekte: kenarda dönerek süzülen yapraklar (yerde gölgesi var) +
                   altında soluk bantlı halka; iç neredeyse temiz.
  C Altın Işıltı   en sade: dolgu yok, kenarda doğal ölçekte (1 px) yükselen ışık çizgileri (şimdikinin düzeltilmişi) + az polen.
TİTREŞİM (Bayer/dama/gürültü) YOK - kullanıcı 2026-11-15 "parazit": yumuşaklık yalnız düz alfa bantlarıyla.
Ölçek: 1 GIF pikseli = 1 dünya birimi (oyunda kamera x2 -> 2 ekran px); arka plan proto_20261016 gerçek çizici yakalaması.
Çıktı: out/agac_aura/aura_{0,A,B,C}.gif + aura_ozet.png. Kullanım (proje kökünden): python -I tools/proto_20261115/agac_aura_proto.py
"""
import importlib.util
import math
import os

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
_spec = importlib.util.spec_from_file_location('ha_proto', os.path.join(PROJECT, 'tools', 'proto_20261018', 'hayat_agaci_proto.py'))
HA = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(HA)

FX = os.path.join(PROJECT, 'assets', 'fx', 'oakley', 'hayat_agaci')
OUT = os.path.join(HERE, 'out', 'agac_aura')
BG = HA.rgba(HA.BG_PATH)
## yakalamaya gömülü 2 oyuncu karakteri yandaki çimenle örtülür (aura katmanı onların üstüne düşüyordu)
for (_x0, _y0, _x1, _y1, _dx) in ((424, 258, 445, 293, 26), (461, 294, 486, 331, -40)):
    BG.paste(BG.crop((_x0 + _dx, _y0, _x1 + _dx, _y1)), (_x0, _y0))
W, H = BG.size
TAU = math.tau
C = (480.0, 290.0)  ## ağaç gövde dibi = alan merkezi
RX, RY = 350.0, 175.0  ## oakley_tree.gd ZONE_RX/RY
VS = RX / 169.0  ## ZONE_VISUAL_SCALE
P = 2.8
DT = 0.07
NF = int(round(P / DT))
CROP = (100, 30, 860, 510)
GOLD = HA.GOLD
NAMES = {'0': 'Şimdiki (oyunda)', 'A': 'A  Yumuşak Işık', 'B': 'B  Yaprak Halkası', 'C': 'C  Altın Işıltı'}

YY, XX = np.mgrid[0:H, 0:W]
R = np.sqrt(((XX + 0.5 - C[0]) / RX) ** 2 + ((YY + 0.5 - C[1]) / RY) ** 2)
INSIDE = R <= 1.0

## ---------------------------------------------------------------- sanat
TREE = HA.nscale(HA.rgba(os.path.join(FX, 'agac_buyuk.png')), 1.3)
TREE_XY = (C[0] - 1.3 * 30.5, C[1] - 1.3 * 68.0)
ZONE_OLD = HA.nscale(HA.rgba(os.path.join(FX, 'alan.png')), VS)
RAYS_OLD = {}
for key in ('arka', 'on'):
    sh = HA.rgba(os.path.join(FX, f'isik_{key}.png'))
    RAYS_OLD[key] = [HA.nscale(sh.crop((i * 344, 0, i * 344 + 344, sh.height)), VS) for i in range(14)]

OAK = (C[0] - 70.0, C[1] + 52.0)
ALLIES = [('korsan', C[0] + 120.0, C[1] + 22.0), ('sovalye', C[0] - 210.0, C[1] - 48.0)]
SLIMES = [(a, C[0] + 1.13 * RX * math.cos(a), C[1] + 1.13 * RY * math.sin(a)) for a in (0.25, 2.75, 3.75, 5.55, 1.2)]


def leaf_sprites():
    masks = [["..###", ".####", "####.", "###.."], [".####.", "######", ".####."], [".##", "###", "##."]]
    pals = [((40, 86, 38), (110, 170, 64), (178, 218, 98)),
            ((46, 96, 44), (150, 198, 84), (222, 240, 170)),
            ((96, 70, 20), (222, 180, 64), (252, 230, 140))]
    out = []
    for v, rows in enumerate(masks):
        m = np.array([[c == '#' for c in r] for r in rows], bool)
        m = np.pad(m, 1)
        o = HA.dilate(m) & ~m
        top = m & ~np.roll(m, 1, axis=0)
        im = np.zeros(m.shape + (4,), np.uint8)
        dk, md, lt = pals[v]
        im[o] = dk + (255,)
        im[m] = md + (255,)
        im[top] = lt + (255,)
        a = Image.fromarray(im, 'RGBA')
        out.append([a, a.transpose(Image.FLIP_LEFT_RIGHT)])
    return out


LEAVES = leaf_sprites()


## ---------------------------------------------------------------- yardımcılar
def overlay(levels):
    """levels: [(maske, rgb, alfa)] -> tam kare RGBA katman."""
    c = np.zeros((H, W, 4), np.float32)
    for (m, rgb, a) in levels:
        a = np.broadcast_to(np.asarray(a, np.float32), (H, W))[m]
        d = c[m]
        oa = a + d[:, 3] * (1 - a)
        col = (np.array(rgb, np.float32) / 255.0 * a[:, None] + d[:, :3] * d[:, 3:4] * (1 - a)[:, None]) / np.maximum(oa[:, None], 1e-6)
        c[m] = np.concatenate([col, oa[:, None]], 1)
    return Image.fromarray(np.clip(c * 255.0, 0, 255).astype(np.uint8), 'RGBA')


def bands(f, n, rgb, amax):
    """Düz alfa basamakları (titreşim yok): f 0..1 -> n seviyeye yuvarlanır, her seviye tek düz alfa."""
    lv = np.clip(np.floor(f * n + 0.5) / n, 0.0, 1.0)
    return [(lv > 0, rgb, lv * amax)]


def vnoise(x, y, cell, seed):
    gx, gy = x / cell, y / cell
    ix, iy = np.floor(gx).astype(np.int64), np.floor(gy).astype(np.int64)
    fx, fy = gx - ix, gy - iy
    sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)

    def h(a, b):
        v = ((a + 1000) * 374761393 + (b + 1000) * 668265263 + seed * 1442695041) & 0xffffffff
        v = ((v ^ (v >> 13)) * 1274126177) & 0xffffffff
        return ((v ^ (v >> 16)) & 0xffff) / 65535.0
    a0 = h(ix, iy) + (h(ix + 1, iy) - h(ix, iy)) * sx
    a1 = h(ix, iy + 1) + (h(ix + 1, iy + 1) - h(ix, iy + 1)) * sx
    return a0 + (a1 - a0) * sy


def rnd(i, k):
    v = (i * 2654435761 + k * 40503 + 12345) & 0xffffffff
    v = ((v ^ (v >> 15)) * 2246822519) & 0xffffffff
    return ((v ^ (v >> 13)) & 0xffff) / 65535.0


MOTES = []
for i in range(30):
    rr, th = math.sqrt(rnd(i, 1)) * 0.9, TAU * rnd(i, 2)
    MOTES.append((C[0] + RX * rr * math.cos(th), C[1] + RY * rr * math.sin(th), rnd(i, 3)))


def motes(layer, t, n):
    for i, (x, y, o) in enumerate(MOTES[:n]):
        q = (t / P + o) % 1.0
        a = HA.band(math.sin(math.pi * q) * 0.9, 4)
        if a < 0.5:  ## tek sönük piksel = parazit; yalnız tam pırıltı görünür
            continue
        px, py = int(round(x + 1.5 * math.sin(TAU * (q + o)))), int(round(y - 6 - q * 24))
        dot = Image.new('RGBA', (3, 3))
        dot.putpixel((1, 1), GOLD[4] + (int(255 * a),))
        if a >= 0.7:
            for (dx, dy) in ((0, 1), (2, 1), (1, 0), (1, 2)):
                dot.putpixel((dx, dy), GOLD[3] + (int(255 * a * 0.5),))
        HA.comp(layer, dot, px - 1, py - 1)


def ray_px(items, t, n, front_only=None):
    """C: doğal ölçekte (1 px) ışık çizgileri; (taban y, katman) sıralı öğe olarak eklenir."""
    for i in range(n):
        a = TAU * i / n + 0.15
        x = C[0] + RX * 0.97 * math.cos(a)
        y = C[1] + RY * 0.97 * math.sin(a)
        ph = (2.0 * t / P + i * 0.37) % 1.0
        L = 12 + 5 * ((i * 7) % 3)
        lift = ph * 18
        im = Image.new('RGBA', (1, L))
        for j in range(L):
            al = HA.band((1 - j / L) * (1 - ph) * 1.0, 4)
            col = GOLD[4] if j < 2 else GOLD[3]
            im.putpixel((0, L - 1 - j), col + (int(255 * al),))
        items.append((y, im, x, y - lift - L + 1))


## ---------------------------------------------------------------- kare
def frame(var, t):
    img = BG.copy()
    ph = TAU * t / P
    items = []  ## (sıra y, resim, x, y)
    top = []  ## en üstte (z 2)
    if var == '0':
        HA.comp(img, ZONE_OLD, C[0] - ZONE_OLD.width / 2, C[1] - ZONE_OLD.height / 2)
        rf = int(t * 12) % 14
        HA.comp(img, RAYS_OLD['arka'][rf], C[0] - VS * 172, C[1] - VS * (46 + 84.5))
        top.append((RAYS_OLD['on'][rf], C[0] - VS * 172, C[1] - VS * 46))
    elif var == 'A':
        breath = 0.5 + 0.5 * math.sin(ph)
        core = np.clip(1 - R, 0, 1) ** 1.2 * 0.75
        rim = np.exp(-((R - 0.94) / 0.04) ** 2) * (0.62 + 0.3 * breath)
        f = np.clip(core + rim, 0, 1)
        f[~INSIDE] = 0
        img.alpha_composite(overlay(bands(f, 4, GOLD[3], 0.30)))
    elif var == 'B':
        f = np.exp(-((R - 0.955) / 0.05) ** 2) * 0.6 + np.clip(1 - R, 0, 1) ** 2 * 0.3
        f[~INSIDE] = 0
        img.alpha_composite(overlay(bands(f, 4, (226, 250, 170), 0.26)))
        N = 60
        for i in range(N):
            v = i % 3
            th = TAU * i / N + (0.0, 0.031, -0.027)[v] + (TAU * 3 / N) * (t / P)
            rr = (0.985, 0.955, 1.0)[v]
            gx, gy = C[0] + RX * rr * math.cos(th), C[1] + RY * rr * math.sin(th)
            hgt = 7 + 3.0 * math.sin(th * 6 + 2 * ph)
            fl = int(math.floor(8 * t / P + 13 * th / TAU)) % 2
            spr = LEAVES[v][fl]
            sh = Image.new('RGBA', (spr.width - 1, 1), (28, 48, 22, 90))
            HA.comp(img, sh, gx - sh.width / 2, gy)
            items.append((gy, spr, gx - spr.width / 2, gy - hgt - spr.height))
    elif var == 'C':
        f = np.exp(-((R - 0.965) / 0.035) ** 2) * 0.6
        f[~INSIDE] = 0
        img.alpha_composite(overlay(bands(f, 3, GOLD[3], 0.27)))
        ray_px(items, t, 64)
    ## karakterler, ağaç, yaratıklar (ayak y sırası)
    items.append((C[1], TREE, TREE_XY[0], TREE_XY[1]))
    items.append((OAK[1], HA.OAK_IDLE[2][int(t * 5) % 4], OAK[0] - HA.CHAR_CX, OAK[1] - HA.CHAR_FEET))
    for (k, x, y) in ALLIES:
        items.append((y, HA.ALLY_IDLE[k][0][int(t * 5 + x) % 4], x - HA.CHAR_CX, y - HA.CHAR_FEET))
    for (a, x, y) in SLIMES:
        items.append((y + 8, HA.SLIME_WALK[0][int(t * 10 + x) % 8], x - HA.SLIME_HALF, y - HA.SLIME_HALF))
    for (_, im, x, y) in sorted(items, key=lambda e: e[0]):
        HA.comp(img, im, x, y)
    for (im, x, y) in top:
        HA.comp(img, im, x, y)
    if var in ('A', 'C'):
        motes(img, t, 30 if var == 'A' else 12)
    out = img.crop(CROP)
    dr = ImageDraw.Draw(out)
    fnt = HA.font(18)
    dr.text((11, 9), NAMES[var], fill=(20, 30, 14), font=fnt)
    dr.text((10, 8), NAMES[var], fill=(250, 246, 226), font=fnt)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    stills = []
    for var in ('0', 'A', 'B', 'C'):
        frames = [frame(var, k * DT).convert('RGB') for k in range(NF)]
        pal = frames[0].quantize(colors=255, method=Image.Quantize.MEDIANCUT)
        q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
        path = os.path.join(OUT, f'aura_{var}.gif')
        q[0].save(path, save_all=True, append_images=q[1:], duration=int(DT * 1000), loop=0, optimize=True)
        stills.append(frames[14])
        print(path, os.path.getsize(path) // 1024, 'KB')
    w, h = stills[0].size
    sheet = Image.new('RGB', (w * 2, h * 2))
    for i, s in enumerate(stills):
        sheet.paste(s, ((i % 2) * w, (i // 2) * h))
    sheet.save(os.path.join(OUT, 'aura_ozet.png'))
    print('özet', sheet.size)


if __name__ == '__main__':
    main()
