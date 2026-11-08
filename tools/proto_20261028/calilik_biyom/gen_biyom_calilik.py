"""SAKLANMA ÇALILIĞI - BÖLGEYE UYGUN prototipler (2026-10-28; kullanıcı: "saklanma çalıları bulundukları biyoma uygun görünmüyor").
Bugün her bölgede aynı L1 "Uzun Yaprak" çalılığı (madde 281) bölge bitki rengine boyanıyor (harita_renk_bitki_d): Kuzey'de griye dönmüş gür taze ot, Güney'de düz
yeşil uzun ot. Prototipler bölgenin KENDİ paket bitkilerinden (harita/derin_orman.png, atlas.json) şekil + palet alır:
  ka  K-A Kara Diken   (Kuzey; diken_b/o/k paleti: kurumuş kara-bordo sivri yapraklar, seyrek kırmızı uçlar)
  kb  K-B Ruh Otu       (Kuzey; isik_bitki/mavi_ot: arduvaz yapraklar, soluk camgöbeği uçlar)
  ga  G-A Kamışlık      (Güney; saz_1..4: ince zeytin kamış yaprakları + kahverengi püsküller)
  gb  G-B Eğrelti Yatağı (Güney; egrelti_1/2: geniş, tırtıklı, dışa sarkan eğrelti yaprakları)
KARO DÜZENİ AYNI (256x64, sütun = kenar maskesi, satır = 4 çeşit; tools/proto_20261019/gen_lol_calilik.py'nin dolgu/sınır tutamı/kontür kuralları
aynen) -> hışırtı, içerideki karakter örtüsü, dikişsizlik değişmez. Atlaslar ZATEN bölge renginde: oyunda bu karolara bitki boyası (do_bitki) uygulanmaz.
Çıktı: out/atlas_<etiket>.png + out/atlas_onizleme.png. Oyunda: biyom_run.ps1. Kullanım: python -I tools/proto_20261028/calilik_biyom/gen_biyom_calilik.py
SEÇİLEN (madde 390): Kuzey DEĞİŞMEDİ (L1 + bölge boyası), Güney = G-B Eğrelti Yatağı. `--oyun`: harita/saklanma_calilik.png'yi 8 satıra yazar - satır 0-3
bugünkü atlasın üst 64 px'i AYNEN, 4-7 Eğrelti (OYUN_SATIRLARI); ilk yazımda eski atlas harita/yedek/'e. Sonra: "harita/saklanma_calilik.tsx" tilecount 128 /
height 128, tools/derin_orman/place_derin_orman.py (GUNEY 'brush_rows' öbekleri 4. satıra taşır) + `--headless --import` + bake.
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(PROJ, 'tools', 'proto_20261019'))
import gen_lol_calilik as G  # noqa: E402

OUT = os.path.join(HERE, 'out')
TILE, N, E = G.TILE, G.N, G.E
TOP, BOTTOM, LEFT, RIGHT = G.TOP, G.BOTTOM, G.LEFT, G.RIGHT

## palet: 0 kontür, 1 derin, 2..5 gövde koyudan açığa, 6 uç, 7 uç parıltısı, 8.. türe özel (diken: diken koyu/açık; kamış: püskül koyu/orta/açık)
STYLES = {
    'ka': dict(name='K-A · Kara Diken', desc='Kuzey: kurumuş kara-bordo sivri yapraklar, seyrek kırmızı diken uçları (diken_b/o/k paleti)', kind='ot',
               pal=[(12, 8, 9), (26, 17, 16), (42, 29, 27), (55, 39, 36), (69, 50, 46), (86, 64, 58), (108, 86, 77), (158, 60, 42)],
               shadow=(14, 10, 12), w=(2, 2, 1), ln=(9.0, 12.5), tufts=6, leaves=(3, 4), spread=0.3, lobes=0),
    'kb': dict(name='K-B · Ruh Otu', desc='Kuzey: arduvaz yapraklar, soluk camgöbeği uçlar (isik_bitki / mavi_ot)', kind='ot',
               pal=[(12, 15, 20), (22, 27, 33), (27, 35, 45), (34, 47, 58), (44, 69, 76), (58, 92, 94), (90, 161, 139), (158, 224, 210)],
               shadow=(12, 16, 22), w=(3, 3, 2), ln=(8.0, 11.5), tufts=5, leaves=(2, 3), spread=0.22, lobes=0),
    'ga': dict(name='G-A · Kamışlık', desc='Güney: ince zeytin kamış yaprakları + kahverengi püsküller (saz_1..4)', kind='kamis',
               pal=[(30, 40, 22), (44, 64, 21), (62, 93, 27), (76, 108, 31), (92, 125, 36), (106, 137, 35), (124, 146, 70), (156, 166, 96),
                    (52, 24, 18), (88, 54, 38), (142, 98, 58)],
               shadow=(26, 34, 16), w=(2, 1, 2), ln=(10.0, 13.5), tufts=6, leaves=(2, 3), spread=0.12, lobes=0, cattails=1),
    'gb': dict(name='G-B · Eğrelti Yatağı', desc='Güney: geniş, tırtıklı, dışa sarkan eğrelti yaprakları (egrelti_1/2)', kind='egrelti',
               pal=[(18, 39, 22), (34, 70, 36), (50, 96, 43), (60, 111, 46), (76, 128, 47), (97, 148, 56), (110, 160, 58), (130, 178, 70)],
               shadow=(16, 34, 20), w=(4, 5, 4), ln=(7.0, 10.0), tufts=4, leaves=(3, 4), spread=0.5, lobes=0),
}


def wiggle_rows(it, lf):
    """diken dalı: yaprak satırları + sinüs kıvrımı (dal), genişlik hep 1"""
    rows = []
    by = int(math.floor(it.y))
    ph = (lf['phase'])
    for r in range(lf['H']):
        t = r / max(1, lf['H'] - 1)
        cx = it.x + lf['dx'] + lf['lean'] * r + lf['curve'] * r * r + 0.9 * math.sin(r * 0.85 + ph) * min(1.0, r / 3.0)
        x0 = int(math.floor(cx + 0.5))
        rows.append((by - r, x0, x0, t))
    return rows


def _prep(it, st):
    """türe göre yaprak ayarı (Item rastgelesinden bağımsız, anahtar tohumlu -> karo/çeşitte aynı ortak tutam aynı kalır)"""
    rng = random.Random(it.key ^ 0x5bd1e995)
    for lf in it.leaves:
        lf['phase'] = rng.uniform(0, 6.28)
        if st['kind'] == 'diken':
            lf['curve'] *= 2.2
        elif st['kind'] == 'egrelti':
            ## eğrelti yaprağı dışa sarkar: eğrilik yaslanma yönünde güçlü
            lf['curve'] = (0.05 + rng.uniform(0.0, 0.03)) * (1 if lf['lean'] >= 0 else -1)
        elif st['kind'] == 'kamis':
            lf['curve'] *= 0.5
    return it


def _fit(it, mask, st):
    """G.fit_leaves'in dal kıvrımlı sürümü (diken): kıvrım sınıra taşarsa kısalt"""
    if st['kind'] != 'diken':
        return G.fit_leaves(it, mask)
    lx = 1 if mask & LEFT else 2
    hx = TILE - 2 if mask & RIGHT else TILE - 3
    ly = 1 if mask & TOP else 2
    hy = TILE - 2 if mask & BOTTOM else TILE - 3
    keep = []
    for lf in it.leaves:
        while lf['H'] >= 3:
            rr = wiggle_rows(it, lf)
            if all(ly <= y <= hy and lx <= x0 - 1 and x1 + 1 <= hx for (y, x0, x1, _) in rr):
                keep.append(lf)
                break
            lf['H'] -= 1
    it.leaves = keep
    return it


def draw_twig(idx, it, lf, fill_mask):
    """dal: 1 px, kökte koyu uca doğru açılır; her ~3 satırda bir yana kısa diken (önce koyu bordo, ucu kırmızı)"""
    rows = wiggle_rows(it, lf)
    side = 1 if (lf['phase'] > 3.14) else -1
    for r, (y, x0, _x1, t) in enumerate(rows):
        cy, cx = y + E, x0 + E
        if not (0 <= cy < N and 0 <= cx < N):
            continue
        v = 3 if t < 0.3 else (4 if t < 0.65 else (5 if t < 0.9 else 6))
        idx[cy, cx] = v
        if 0.2 < t < 0.92 and (r + int(lf['phase'] * 3)) % 3 == 0:
            sx = cx + side
            if 0 <= sx < N:
                idx[cy, sx] = 8
            if 0 <= sx + side < N and 0 <= cy - 1 < N and r % 2 == 0:
                idx[cy - 1, sx + side] = 9
            side = -side
    if rows:
        y, x0, _, _ = rows[-1]
        if 0 <= y + E < N and 0 <= x0 + E < N:
            idx[y + E, x0 + E] = 9 if lf['H'] >= 8 else 6


def draw_frond(idx, it, lf, fill_mask):
    """eğrelti yaprağı: satır satır; ortada koyu damar, kenarlar tırtıklı (tek satırlarda kenar yaprakçığı 1 px dışarı, çiftlerde 1 px içeri)"""
    for r, (y, x0, x1, t) in enumerate(G.leaf_rows(it, lf)):
        cy = y + E
        if cy < 0 or cy >= N:
            continue
        w = x1 - x0 + 1
        base = 3 if t < 0.25 else (4 if t < 0.6 else 5)
        if w >= 3 and 0.12 < t < 0.85:
            if r % 2:
                x0, x1 = x0 - 1, x1 + 1
            else:
                x0, x1 = x0 + 1, x1 - 1
        mid = (x0 + x1) // 2
        for x in range(x0, x1 + 1):
            cx = x + E
            if not 0 <= cx < N:
                continue
            if t >= 0.85:
                v = 6 if lf['H'] >= 6 else 5
            elif x == x0:
                v = min(6, base + 1) if r % 2 else base
            elif x == x1:
                v = base - 1
            elif x == mid and w >= 3:
                v = base - 1
            else:
                v = base
            idx[cy, cx] = int(min(7, max(1, v + (lf['tone'] if t < 0.85 else 0))))
        sx = x1 + 1 + E
        if 0 <= sx < N and t < 0.85 and (idx[cy, sx] >= 0 or fill_mask[cy, sx]):
            idx[cy, sx] = 1


def draw_cattail(idx, x, ytop):
    """püskül: 1 px sap ucunda 2x5 kahverengi kapsül (sol kenar açık, sağ kenar koyu), tepesinde 1 px sap ucu"""
    for dy in range(5):
        for dx, v in ((0, 10 if 0 < dy < 4 else 9), (1, 9 if dy < 4 else 8)):
            cy, cx = ytop + 1 + dy + E, x + dx + E
            if 0 <= cy < N and 0 <= cx < N:
                idx[cy, cx] = v
    cy, cx = ytop + E, x + E
    if 0 <= cy < N and 0 <= cx < N:
        idx[cy, cx] = 6


def tile(mask, seed, st):
    """G.tile ile aynı adımlar (dolgu, ortak sınır tutamları, çeşit tutamları, üst köşe yayı, dış kontür, alt ön yüz + gölge); çizim türe göre"""
    fill_ok = G._fill_fn(mask, seed)
    idx = np.full((N, N), -1, np.int16)
    for yy in range(N):
        for xx in range(N):
            if fill_ok(xx - E + 0.5, yy - E + 0.5):
                idx[yy, xx] = 2
    fill_mask = idx >= 0
    kind = st['kind']

    def draw(it):
        for lf in it.leaves:
            if kind == 'diken':
                draw_twig(idx, it, lf, fill_mask)
            elif kind == 'egrelti':
                draw_frond(idx, it, lf, fill_mask)
            else:
                G.draw_leaf(idx, it, lf, fill_mask)
    for it in G._shared_items(mask, st):
        _prep(it, st)
        if kind == 'diken':
            _fit(it, mask, st)
        draw(it)
    items = G._variant_items(mask, seed, st, fill_ok)
    tall = []
    for it in items:
        _prep(it, st)
        _fit(it, mask, st)
        draw(it)
        if it.leaves:
            top = min(G.leaf_rows(it, lf)[-1][0] for lf in it.leaves)
            tall.append((top, it))
    if st.get('cattails'):
        ## en uzun tutamların ucuna püskül (kapalı yanda sınıra 2 px pay; karo içinde kalır -> dikişsizlik bozulmaz)
        rng = random.Random(seed * 101 + mask * 13 + 7)
        tall.sort(key=lambda e: e[0])
        ly = 1 if mask & TOP else 2
        lx = 1 if mask & LEFT else 2
        hx = TILE - 3 if mask & RIGHT else TILE - 4
        ## karo başına en çok `cattails` püskül, uygun tutamlar arasından RASTGELE (en uzunlar seçilince her karoda aynı
        ## yere düşüp ızgara gibi diziliyordu)
        cand = []
        for top, it in tall:
            lf = max(it.leaves, key=lambda l: l['H'])
            y, x0, _x1, _t = G.leaf_rows(it, lf)[-1]
            ## püskül yaprağın UCUNA oturur (uzun kamışların ucu karo tepesine dayanır; üstüne sap eklemek sınırı aşıyordu)
            if ly <= y and y + 5 <= TILE - 2 and lx <= x0 <= hx:
                cand.append((x0, y))
        rng.shuffle(cand)
        ## her kenar maskesinin 4 çeşidinden 2'sinde (haritada hücre çeşidi rastgele -> hücrelerin ~yarısında, dağınık)
        for x0, y in cand[:st['cattails'] if (seed + mask) % 2 else 0]:
            draw_cattail(idx, x0, y)
    for (a, b2, ccx) in ((TOP, LEFT, G.ENV_R), (TOP, RIGHT, TILE - G.ENV_R)):
        if mask & a and mask & b2:
            ccy = 1.0 + G.ENV_R
            qx = (G.XX < ccx) if ccx < TILE / 2 else (G.XX > ccx)
            out_c = qx & (G.YY < ccy) & ((G.XX - ccx) ** 2 + (G.YY - ccy) ** 2 > G.ENV_R ** 2)
            idx[out_c] = -1
    op = idx >= 0
    inner = np.zeros((N + 2, N + 2), bool)
    inner[1:-1, 1:-1] = op
    near = inner[:-2, 1:-1] | inner[2:, 1:-1] | inner[1:-1, :-2] | inner[1:-1, 2:]
    idx = np.where(~op & near, 0, idx)
    core = idx[E:E + TILE, E:E + TILE].copy()
    opc = core >= 0
    if mask & BOTTOM:
        for x in range(TILE):
            col = np.where(opc[:, x])[0]
            if len(col):
                yb = col[-1]
                for y in range(max(0, yb - 2), yb + 1):
                    if 2 < core[y, x] < 6:
                        core[y, x] -= 1
    pal = st['pal']
    img = np.zeros((TILE, TILE, 4), np.uint8)
    for y in range(TILE):
        for x in range(TILE):
            if core[y, x] >= 0:
                img[y, x] = (*pal[int(core[y, x])], 255)
    if mask & BOTTOM:
        for x in range(TILE):
            col = np.where(opc[:, x])[0]
            if len(col):
                yb = col[-1]
                for k, a in enumerate((120, 70)):
                    yy = yb + 1 + k
                    if yy < TILE and img[yy, x, 3] == 0:
                        img[yy, x] = (*st['shadow'], a)
    return Image.fromarray(img, 'RGBA')


def build(st):
    atlas = Image.new('RGBA', (TILE * 16, TILE * G.SEEDS), (0, 0, 0, 0))
    for s in range(G.SEEDS):
        for m in range(16):
            atlas.alpha_composite(tile(m, s, st), (m * TILE, s * TILE))
    return atlas


def sample_patch(atlas, w=11, h=6, seed=3):
    """atlas karolarıyla örnek öbek (kenar maskesi komşuluktan, çeşit rastgele) - önizleme"""
    rng = random.Random(seed)
    cells = {(x, y) for y in range(h) for x in range(w) if not ((x in (0, w - 1)) and y in (0, h - 1))}
    im = Image.new('RGBA', (w * TILE, h * TILE), (0, 0, 0, 0))
    for (x, y) in sorted(cells, key=lambda c: c[1]):
        m = (TOP if (x, y - 1) not in cells else 0) | (BOTTOM if (x, y + 1) not in cells else 0) | \
            (LEFT if (x - 1, y) not in cells else 0) | (RIGHT if (x + 1, y) not in cells else 0)
        s = rng.randrange(G.SEEDS)
        im.alpha_composite(atlas.crop((m * TILE, s * TILE, (m + 1) * TILE, (s + 1) * TILE)), (x * TILE, y * TILE))
    return im


def preview(built):
    S = 4
    rows = []
    for key, a in built:
        p = sample_patch(a)
        bg = Image.new('RGBA', (p.width + 32, p.height + 32), (92, 104, 70, 255) if key.startswith('g') else (74, 78, 74, 255))
        bg.alpha_composite(p, (16, 16))
        big = bg.resize((bg.width * S, bg.height * S), Image.NEAREST)
        at = a.resize((a.width * 2, a.height * 2), Image.NEAREST)
        row = Image.new('RGB', (big.width + at.width + 30, max(big.height, at.height) + 30), (28, 28, 28))
        row.paste(big.convert('RGB'), (0, 26))
        atbg = Image.new('RGBA', at.size, (60, 60, 60, 255))
        atbg.alpha_composite(at)
        row.paste(atbg.convert('RGB'), (big.width + 20, 26))
        st = STYLES.get(key, {'name': 'ŞU AN (L1 Uzun Yaprak)', 'desc': 'boyamasız atlas'})
        ImageDraw.Draw(row).text((4, 4), '%s - %s' % (st['name'], st['desc']), fill=(255, 240, 200))
        rows.append(row)
    W = max(r.width for r in rows)
    out = Image.new('RGB', (W, sum(r.height for r in rows)), (28, 28, 28))
    y = 0
    for r in rows:
        out.paste(r, (0, y))
        y += r.height
    return out


## oyun atlasında bölge satırları: etiket -> ilk satır (0-3 = L1)
OYUN_SATIRLARI = {'gb': 4}
OYUN_ATLAS = os.path.join(PROJ, 'harita', 'saklanma_calilik.png')
YEDEK_ATLAS = os.path.join(PROJ, 'harita', 'yedek', 'saklanma_calilik_2026-10-28_oncesi_egrelti.png.bak')


def write_game_atlas():
    import shutil
    if not os.path.exists(YEDEK_ATLAS):
        shutil.copy2(OYUN_ATLAS, YEDEK_ATLAS)
    base = Image.open(OYUN_ATLAS).convert('RGBA').crop((0, 0, TILE * 16, TILE * G.SEEDS))
    rows = G.SEEDS * (1 + len(OYUN_SATIRLARI))
    out = Image.new('RGBA', (TILE * 16, TILE * rows), (0, 0, 0, 0))
    out.alpha_composite(base, (0, 0))
    for key, row in OYUN_SATIRLARI.items():
        out.alpha_composite(build(STYLES[key]), (0, row * TILE))
    out.save(OYUN_ATLAS)
    print('oyun atlası', OYUN_ATLAS, out.size)


if __name__ == '__main__':
    if '--oyun' in sys.argv:
        write_game_atlas()
        sys.exit(0)
    os.makedirs(OUT, exist_ok=True)
    built = [('simdi', Image.open(os.path.join(PROJ, 'harita', 'saklanma_calilik.png')).convert('RGBA'))]
    for key, st in STYLES.items():
        a = build(st)
        a.save(os.path.join(OUT, 'atlas_%s.png' % key))
        built.append((key, a))
    preview(built).save(os.path.join(OUT, 'atlas_onizleme.png'))
    print('tamam')
