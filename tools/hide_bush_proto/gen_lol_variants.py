"""SAKLANMA ÇALILIĞI RENK PROTOTİPLERİ (2026-10-10, kullanıcı: "saklanma çalılarının görünüşü çok koyu yeşil durduğu için oyunla uyumsuz, yeniden tasarla 4 prototip
halinde ama ufak parçalar halinde olması gerek önceki gibi çünkü oyuncular içine girince hışırdaması gerekiyor").
Karo sistemi gen_lol_brush.py ile AYNI (16x16 karo, 16 sütun = kenar maskesi 1 üst/2 alt/4 sol/8 sağ açık, SEEDS satır = çeşit; iç karolar yan yana dikişsiz) -> seçilen
prototipin atlası doğrudan harita/saklanma_calilik.png yerine konabilir, kod/TMX değişmez. Fark sadece renk dili: haritanın kendi çim tonlarından (çim ~126,176,84,
koyu çim ~100,145,66, filiz uçları ~177,207,82) türetilmiş, dolgu zeminden yalnız 1-2 ton koyu (eski dolgu 31-44,62-82,30-34 neredeyse siyah-yeşildi).
Çıktı (out/): lol_proto_{a,b,c,d}.png (atlas), lol_proto_karsilastirma.png (gerçek harita çiminde 4 prototip + eski, her birinde içinde bir oyuncu).
Kullanım: python -I tools/hide_bush_proto/gen_lol_variants.py
"""
import os
import math
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_brush_proto as G  # noqa: E402
import gen_lol_brush as L  # noqa: E402

OUT = L.OUT
TILE, SEEDS = L.TILE, L.SEEDS
TOP, BOTTOM, LEFT, RIGHT = L.TOP, L.BOTTOM, L.LEFT, L.RIGHT

FLOWER_TIPS = [[(236, 236, 214), (255, 255, 240)], [(232, 150, 176), (250, 196, 210)], [(240, 206, 92), (255, 232, 140)]]

## Her prototip: dolgu tonları, ana yaprak rampası, ikinci rampa + oranı, uç renkleri + olasılığı, yaprak sayısı/boyu.
PROTOS = {
    'a': {'name': 'A · Çayır', 'desc': 'haritanın çimiyle aynı aile, sık ve parlak uçlu',
          'fill': [(84, 128, 52), (92, 138, 56), (100, 148, 60)],
          'ramp': [(70, 112, 44), (86, 132, 50), (108, 154, 58), (132, 178, 70), (166, 204, 86), (204, 228, 108)],
          'ramp2': [(78, 120, 46), (96, 142, 54), (120, 166, 62), (146, 190, 74), (178, 214, 92), (214, 236, 120)], 'p2': 0.4,
          'tips': None, 'tip_p': 0.0, 'blades': 30, 'h': (5.0, 11.0)},
    'b': {'name': 'B · Zeytin Ot', 'desc': 'sarımsı zeytin, kuru ot gibi; zeminden ayrışır ama koyu değil',
          'fill': [(92, 120, 50), (100, 130, 54), (108, 138, 58)],
          'ramp': [(82, 106, 42), (102, 128, 48), (126, 150, 56), (152, 172, 66), (186, 198, 84), (216, 220, 112)],
          'ramp2': [(76, 112, 44), (94, 132, 50), (116, 156, 58), (140, 180, 68), (172, 206, 84), (206, 228, 108)], 'p2': 0.35,
          'tips': None, 'tip_p': 0.0, 'blades': 28, 'h': (5.0, 11.0)},
    'c': {'name': 'C · Açık Gizemli', 'desc': 'eski stilin aydınlatılmışı: yeşil gövde, seyrek mor/mavi uç',
          'fill': [(70, 112, 52), (78, 122, 56), (86, 132, 60)],
          'ramp': [(62, 102, 46), (78, 124, 52), (100, 148, 60), (126, 172, 72), (160, 198, 88), (198, 224, 112)],
          'ramp2': [(64, 108, 64), (78, 130, 74), (98, 152, 86), (124, 176, 100), (156, 200, 118), (192, 222, 140)], 'p2': 0.45,
          'tips': G.MYSTIC_TIPS, 'tip_p': 0.22, 'blades': 30, 'h': (5.0, 11.0)},
    'd': {'name': 'D · Çiçekli Çalı', 'desc': 'orta yeşil, yer yer beyaz/pembe/sarı çiçek uçları (haritadaki çiçeklerle aynı tonlar)',
          'fill': [(78, 122, 50), (86, 132, 54), (94, 142, 58)],
          'ramp': [(66, 108, 42), (82, 128, 48), (104, 150, 56), (128, 174, 68), (160, 200, 84), (196, 224, 106)],
          'ramp2': [(72, 116, 46), (90, 138, 52), (112, 160, 60), (138, 184, 72), (170, 208, 90), (204, 230, 114)], 'p2': 0.4,
          'tips': FLOWER_TIPS, 'tip_p': 0.12, 'blades': 28, 'h': (5.0, 10.5)},
}


def tile(mask, seed, P):
    rng = random.Random(seed * 7919 + mask * 131)
    side_open = bool(mask & (LEFT | RIGHT))
    img = L.WrapImg(TILE, TILE, wrap=not side_open, wrap_y=not (mask & (TOP | BOTTOM)))
    top_edge = [rng.randint(4, 8) for _ in range(TILE)] if mask & TOP else [0] * TILE
    bot_edge = [TILE - rng.randint(2, 4) for _ in range(TILE)] if mask & BOTTOM else [TILE] * TILE
    lft_edge = [rng.randint(1, 4) for _ in range(TILE)] if mask & LEFT else [0] * TILE
    rgt_edge = [TILE - rng.randint(1, 4) for _ in range(TILE)] if mask & RIGHT else [TILE] * TILE

    def inside(x, y):
        return top_edge[x] <= y < bot_edge[x] and lft_edge[y] <= x < rgt_edge[y]

    fill = P['fill']
    for y in range(TILE):
        for x in range(TILE):
            if inside(x, y):
                img.a[y, x] = (*fill[rng.randrange(3) if rng.random() < 0.35 else 1], 255)
    blades = []
    for i in range(P['blades']):
        x = rng.uniform(0.0, 16.0)
        base = rng.uniform(2.0, 16.0)
        xi, bi = int(x) % TILE, min(TILE - 1, int(base))
        if not inside(xi, bi):
            continue
        h = rng.uniform(*P['h'])
        if mask & TOP:
            h = min(h, base - top_edge[xi] + rng.uniform(1.0, 4.0))
        lean = rng.uniform(-0.32, 0.32)
        if side_open:
            tip = x + lean * h
            if tip < lft_edge[bi] or tip > rgt_edge[bi] - 1:
                lean = -lean
        blades.append((base, x, max(4.0, h), lean))
    blades.sort(key=lambda q: q[0])
    for base, x, h, lean in blades:
        depth = (base - 2.0) / 14.0
        k = 2 if depth < 0.3 else (1 if depth < 0.65 else 0)   ## arka sıra 2 ton koyu, ön sıra kendi tonu
        second = rng.random() < P['p2']
        ramp = G.shift(P['ramp2'] if second else P['ramp'], k)
        tip = rng.choice(P['tips']) if P['tips'] and rng.random() < P['tip_p'] else None
        G.blade(img, x, base, int(h), lean, ramp, rng, tip=tip, wide=True)
    return img.image()


def build(P):
    atlas = Image.new('RGBA', (TILE * 16, TILE * SEEDS), (0, 0, 0, 0))
    for s in range(SEEDS):
        for m in range(16):
            atlas.alpha_composite(tile(m, s, P), (m * TILE, s * TILE))
    return atlas


def patch(atlas, cells, bg, rng):
    for (x, y) in sorted(cells, key=lambda c: c[1]):
        mk = L.mask_of(cells, x, y)
        s = rng.randrange(SEEDS)
        bg.alpha_composite(atlas.crop((mk * TILE, s * TILE, mk * TILE + TILE, s * TILE + TILE)), (x * TILE, y * TILE))


def player(alpha=1.0):
    fr = G.player_frame(alpha)
    s = 0.5 * 0.85   ## oyunda dünya pikseli (player_frame ekran ölçeğinde; oyuncular %15 küçüldü)
    return fr.resize((max(1, round(fr.width * s)), max(1, round(fr.height * s))), Image.NEAREST), round(G.PLAYER_FOOT * s)


def compose(atlases):
    W, H = 12, 8
    m = G.blob_mask(W, H, [(6, 4, 5, 3.2, [(3, 0.12, 0.4)])])
    cells = {(x, y) for y in range(H) for x in range(W) if m[y, x]}
    panels = []
    for key, atlas in atlases:
        bg = G.grass_patch(W, H).copy()
        patch(atlas, cells, bg, random.Random(5))
        pl, foot = player(0.7)
        ## içerideki oyuncu: bacaklar alt sıraların otlarının arkasında - önizlemede üst yarısı açıkta, alt yarısı yarı örtülü
        px, py = 6 * TILE, 4 * TILE + 8
        bg.alpha_composite(pl, (px - pl.width // 2, py - foot))
        cover = bg.crop((0, 0, 1, 1))  # yer tutucu
        cov = Image.new('RGBA', bg.size, (0, 0, 0, 0))
        patch(atlas, {c for c in cells if c[1] >= py // TILE}, cov, random.Random(5))
        cova = np.array(cov)
        top = py - pl.height // 3
        cova[:top, :, 3] = 0
        cova[..., 3] = (cova[..., 3] * 0.5).astype(np.uint8)
        bg.alpha_composite(Image.fromarray(cova, 'RGBA'))
        pl2, _ = player(1.0)
        bg.alpha_composite(pl2, (11 * TILE - pl2.width // 2 - 4, 6 * TILE - foot))   ## dışarıda duran oyuncu (karşılaştırma)
        panels.append((key, bg.resize((bg.width * 3, bg.height * 3), Image.NEAREST)))
    pw, ph = panels[0][1].size
    sheet = Image.new('RGB', (pw * 3 + 40, (ph + 50) * 2 + 10), (24, 24, 28))
    d = ImageDraw.Draw(sheet)
    f = G._font(22)
    for i, (key, img) in enumerate(panels):
        cx, cy = 10 + (i % 3) * (pw + 10), 10 + (i // 3) * (ph + 50)
        sheet.paste(img.convert('RGB'), (cx, cy + 40))
        title = 'ESKİ (şu anki)' if key == 'old' else PROTOS[key]['name']
        d.text((cx, cy + 8), title, fill=(240, 236, 220), font=f)
    return sheet


## 2026-10-10 2. tur (kullanıcı: "yerleşim köşeleri çok keskin bitiyor, blok oyunlarına benziyor, kenarları gerçek çimler gibi doğal olmalı" + "çimlerin
## uzunluğu çok kısa, karakterler içinde saklanmış gibi görünmüyor"): D'nin renkleriyle, KENARLARI kavisli/düzensiz ve otları UZUN çizen sürüm.
##  - Açık kenarın sınırı karonun iki ucunda SABİT derinlikte (komşu kenar karolarıyla dikişsiz birleşir), ortada rastgele kabarır/içeri girer (kavisli,
##    "tırtıklı" ot hattı); iki yanı açık köşeler yuvarlanır (yarıçap ~9 px).
##  - Koyu dolgu sınırın 2 px içinde biter: dış silüeti yapraklar çizer (düz kesik hat yok); üst kenarda yaprak uçları sınırın 8 px'e kadar DIŞINA taşar.
##  - Yapraklar 9-15 px (D: 5-10,5).
NATURAL = dict(PROTOS['d'], name='E · Doğal Kenar', blades=36, h=(9.0, 15.0))
EDGE_DEPTH = 5.0   ## açık kenarın karo uçlarındaki sabit derinliği
SIDE_DEPTH = 3.0
CORNER_R = 12.0


def _profile(rng, base, lo, hi):
    """karo boyunca sınır derinliği: uçlarda tam `base`, ortada rastgele bir kabarma/girinti + küçük dalga (uçlarda 0)"""
    amp = rng.uniform(lo, hi)
    k = rng.choice([2, 3])
    wob = rng.uniform(-1.2, 1.2)
    out = []
    for t in range(TILE):
        u = (t + 0.5) / TILE
        out.append(base + amp * math.sin(math.pi * u) + wob * math.sin(math.pi * k * u))
    return out


def tile_natural(mask, seed, P):
    rng = random.Random(seed * 104729 + mask * 977)
    side_open = bool(mask & (LEFT | RIGHT))
    img = L.WrapImg(TILE, TILE, wrap=not side_open, wrap_y=not (mask & (TOP | BOTTOM)))
    top = _profile(rng, EDGE_DEPTH, -2.0, 7.0) if mask & TOP else [0.0] * TILE
    bot = [TILE - v for v in _profile(rng, SIDE_DEPTH, -1.0, 5.0)] if mask & BOTTOM else [float(TILE)] * TILE
    lft = _profile(rng, SIDE_DEPTH, -1.0, 6.0) if mask & LEFT else [0.0] * TILE
    rgt = [TILE - v for v in _profile(rng, SIDE_DEPTH, -1.0, 6.0)] if mask & RIGHT else [float(TILE)] * TILE

    def corner_ok(x, y, pad=0.0):
        r = CORNER_R - pad
        for open_a, open_b, cx, cy in ((TOP, LEFT, CORNER_R, CORNER_R), (TOP, RIGHT, TILE - CORNER_R, CORNER_R),
                                         (BOTTOM, LEFT, CORNER_R, TILE - CORNER_R), (BOTTOM, RIGHT, TILE - CORNER_R, TILE - CORNER_R)):
            if mask & open_a and mask & open_b:
                inx = x < cx if cx < TILE / 2 else x > cx
                iny = y < cy if cy < TILE / 2 else y > cy
                if inx and iny and (x - cx) ** 2 + (y - cy) ** 2 > r * r:
                    return False
        return True

    def inside(x, y, pad=0.0):
        xi, yi = int(x) % TILE, int(y) % TILE
        return (top[xi] + pad <= y < bot[xi] - pad and lft[yi] + pad <= x < rgt[yi] - pad and corner_ok(x, y, pad))

    fill = P['fill']
    for y in range(TILE):
        for x in range(TILE):
            if inside(x + 0.5, y + 0.5, 2.0 if mask else 0.0):
                img.a[y, x] = (*fill[rng.randrange(3) if rng.random() < 0.35 else 1], 255)
    blades = []
    for i in range(P['blades']):
        x = rng.uniform(0.0, 16.0)
        base = rng.uniform(0.0 if mask == 0 else 3.0, 16.0)
        if not inside(x, min(base, TILE - 0.01)):
            continue
        h = rng.uniform(*P['h'])
        xi = int(x) % TILE
        if mask & TOP:
            h = min(h, base - top[xi] + rng.uniform(2.0, 8.0))   ## uçlar üst sınırın DIŞINA taşar (ot hattı)
        lean = rng.uniform(-0.3, 0.3)
        if mask & LEFT and x < 6.0:
            lean = -abs(lean) - 0.1                               ## kenardaki otlar dışa yatar
        if mask & RIGHT and x > 10.0:
            lean = abs(lean) + 0.1
        blades.append((base, x, max(5.0, h), lean))
    if mask == 0:
        rng.shuffle(blades) ## iç karo: dipler karonun alt kısmında toplanıp en son çizilmesin (her 16 px'te yatay bant)
    else:
        blades.sort(key=lambda q: q[0])
    for base, x, h, lean in blades:
        ## arka/ön tonu karo içindeki yüksekliğe göre DEĞİL rastgele (eski kural her 16 px'te yatay bant çiziyordu); dış kenar karolarında
        ## sınıra yakın yapraklar açık (öndeki otlar) kalır
        k = rng.choice([0, 0, 1, 1, 2])
        second = rng.random() < P['p2']
        ramp = G.shift(P['ramp2'] if second else P['ramp'], k)
        tip = rng.choice(P['tips']) if P['tips'] and rng.random() < P['tip_p'] else None
        G.blade(img, x, base, int(h), lean, ramp, rng, tip=tip, wide=True)
    return img.image()


def build_natural(P):
    atlas = Image.new('RGBA', (TILE * 16, TILE * SEEDS), (0, 0, 0, 0))
    for s in range(SEEDS):
        for m in range(16):
            atlas.alpha_composite(tile_natural(m, s, P), (m * TILE, s * TILE))
    return atlas


if __name__ == '__main__':
    built = []
    old = Image.open(os.path.join(G.PROJECT, 'harita', 'saklanma_calilik.png')).convert('RGBA')
    built.append(('old', old))
    for key, P in PROTOS.items():
        a = build(P)
        a.save(os.path.join(OUT, 'lol_proto_%s.png' % key))
        built.append((key, a))
    e = build_natural(NATURAL)
    e.save(os.path.join(OUT, 'lol_proto_e.png'))
    PROTOS['e'] = NATURAL
    built = [b for b in built if b[0] in ('old', 'd')] + [('e', e)]
    compose(built).save(os.path.join(OUT, 'lol_proto_karsilastirma.png'))
    print('tamam')
