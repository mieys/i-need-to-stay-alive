"""EK SAKLANMA ÇALILIKLARI (madde 281, 2026-10-19; kullanıcı: "L1 olsun ayrıca oyunda haritandaki açık alanların nehirin gölün kenarlarına falan da biraz bunlardan koy
ama içine girip saklanılabilecek kıvamda olsun. aşırı az olmamalı yani. ve aynı değişikliği hem bakede hem de harita.tmx e yap ki sonra bakeleyince eksik olmasın bişey").
Mevcut 1186 hücre (madde 63, köşe/koy çalılıkları) AYNEN kalır; yenileri eklenir:
  - 'su'    : nehir/göl kıyısı - suya 1-2 hücre uzaklıktaki çimenden başlayan, kıyı boyunca uzanan öbek (suya değmez: Su hücreleri çarpışmalı)
  - 'çayır' : açık alan - tohum her engelden (duvar/yamaç, ağaç, bina/köprü/maden/üs, yol, su, mevcut süs) en az 4 hücre uzakta (6'da harita sık olduğu için sadece 4 yer çıktı)
Öbek: kıyıya/yatay eksene hizalı gürültülü elips (küçük 3x2 / orta 4,2x2,6 / büyük 5,4x3,2 hücre yarıçap), tek hücrelik çıkıntı ve delik temizlenir;
kabul: >= 12 hücre, >= 2 "derin" hücre (8 komşusu da çalılık: 2 kişi tamamen içeride saklanabilsin), en az 4x3. Öbekler arası >= 8 hücre, eski çalılıklara >= 6.
Karo: kenar maskesi (1 üst/2 alt/4 sol/8 sağ açık) + çeşit (sol/üst komşuyla aynı değil) - place_lol.py ile AYNI kural; gid = 34768 + çeşit*16 + maske.
Okuma/yazma SONSUZ TMX (chunk): okuma tools/dis_cerceve/ring_write.read_back; yazma sadece bu katmanın <data> bloğu, Tiled biçimi (CRLF, chunk satırları ',').
Hesap + katman tabanı hep SRC'den (ek öncesi yedek) -> tekrar koşmak güvenli (aynı tohum = aynı sonuç), canlı TMX'in diğer katmanları aynen kalır.
Kullanım (proje kökünden):
  python -I tools/hide_bush_proto/place_lol_ek.py                -> out/ek_onizleme.png + out/ek_hucreler.json + out/lol_hucreler_tum.json (eski + yeni, patch_baked_single.py için)
  python -I tools/hide_bush_proto/place_lol_ek.py --apply <md5>  -> Harita.tmx (md5 kapısı, yedek harita/yedek/Harita_2026-10-19_oncesi_ek-calilik.tmx.bak)
  python -I tools/hide_bush_proto/patch_baked_single.py lol_hucreler_tum.json 4   -> scenes/harita_baked.tscn (aynı hücreler)
"""
import hashlib
import json
import math
import os
import random
import re
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(PROJECT, 'tools', 'dis_cerceve'))
from ring_core import X0, Y0, W2, H2, PLAY  # noqa: E402
from ring_write import read_back  # noqa: E402

TMX = os.path.join(PROJECT, 'harita', 'Harita.tmx')
YEDEK = os.path.join(PROJECT, 'harita', 'yedek')
## KAYNAK: ek çalılıklardan ÖNCEKİ harita (ilk --apply bunu yedekler). Hesap + çalılık katmanının tabanı hep buradan -> betik tekrar koşulabilir
## (canlı TMX'in çalılık katmanı = kaynak katman + yeni öbekler; diğer katmanlar canlıdan aynen kalır).
SRC = os.path.join(YEDEK, 'Harita_2026-10-19_oncesi_ek-calilik.tmx.bak')
OUT = os.path.join(HERE, 'out')
LAYER = 'Orman parçaları/Saklanma Çalılığı'
LAYER_NAME = 'Saklanma Çalılığı'
FIRSTGID, COLS, SEEDS = 34768, 16, 4
SEED = 20261019
N_SU, N_CAYIR = 20, 16
GAP_NEW, GAP_OLD = 8, 6
SPAWN = ((3016 + 2) / 16.0, (1920 - 21) / 16.0)   ## oyuncu doğuşu (main.tscn harita ofseti (-2, 21))
SIZES = [(3.6, 2.3), (4.4, 2.7), (5.6, 3.3)]
SIZE_W = [0.3, 0.45, 0.25]


def md5(p):
    return hashlib.md5(open(p, 'rb').read()).hexdigest()


def tileset_ranges(text):
    ts = sorted((int(m.group(1)), m.group(2)) for m in re.finditer(r'<tileset firstgid="(\d+)" source="([^"]+)"', text))
    return ts


def ts_name(ts, gid):
    gid &= 0x1FFFFFFF
    name = None
    for f, s in ts:
        if f <= gid:
            name = s
    return name


def any_of(g, keys):
    m = np.zeros((H2, W2), bool)
    for k in keys:
        m |= g[k] != 0
    return m


def dist(mask, maxd=12):
    """8-komşu (Chebyshev) uzaklık: mask'e kaç hücre; maxd'den uzaksa maxd+1"""
    d = np.full(mask.shape, maxd + 1, np.int32)
    cur = mask.copy()
    d[cur] = 0
    for k in range(1, maxd + 1):
        p = np.pad(cur, 1)
        nb = cur.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                nb |= p[1 + dy:1 + dy + cur.shape[0], 1 + dx:1 + dx + cur.shape[1]]
        new = nb & ~cur
        d[new] = k
        cur = nb
    return d


def classify(g, text):
    ts = tileset_ranges(text)
    water = any_of(g, ['Su/Su', 'Su/Su collisionsuz', 'Su/Su altı'])
    wall = any_of(g, [k for k in g if k.startswith('Orman parçaları/') and k != LAYER])
    trees = any_of(g, ['Shader Eklenecek/Ağaç 0', 'Shader Eklenecek/Ağaç 1', 'Shader Eklenecek/Ağaç 2'])
    build = any_of(g, [k for k in g if k.split('/')[0] in ('ev', 'Köprü', 'Etkileşimler', 'Düşman Üssü')])
    ## süs katmanları (çiçek dahil) çalılık katmanından SONRA çizilir: altında kalsa çalılığın üstünde yüzer gibi durur
    decor = any_of(g, ['Shader Eklenecek/Çalılar', 'Shader Eklenecek/Çalılar1', 'Shader Eklenecek/Animasyonsuz çalılar', 'Shader Eklenecek/Çiçekler 1'])
    ## YOL = çimensiz toprak (patika/kum). TUZAK: 'Çimler' katmanındaki 'Yol parçaları' karoları (3587) yol DEĞİL, çayıra serpiştirilmiş çimen süsü -
    ## yol sayılınca öbekler düz kesiklerle kırpılıyordu
    road = (g['Yer/Zemin Çimen'] == 0) & ~water
    play = np.zeros((H2, W2), bool)
    play[-Y0 + 3:-Y0 + PLAY - 3, -X0 + 3:-X0 + PLAY - 3] = True
    old = g[LAYER] != 0
    return dict(water=water, wall=wall, trees=trees, build=build, decor=decor, road=road, play=play, old=old)


def blob(cx, cy, rx, ry, ang, rng):
    k = rng.choice([2, 3])
    ph = rng.uniform(0, math.tau)
    amp = rng.uniform(0.1, 0.2)
    ca, sa = math.cos(ang), math.sin(ang)
    out = set()
    R = int(math.ceil(max(rx, ry) * 1.3)) + 1
    for dy in range(-R, R + 1):
        for dx in range(-R, R + 1):
            u = (dx * ca + dy * sa) / rx
            v = (-dx * sa + dy * ca) / ry
            th = math.atan2(v, u)
            if u * u + v * v <= (1.0 + amp * math.sin(k * th + ph)) ** 2:
                out.add((cx + dx, cy + dy))
    return out


def clean(cells, seed):
    cells = set(cells)
    for _ in range(4):
        rem = [c for c in cells if sum((c[0] + a, c[1] + b) in cells for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))) < 2]
        if not rem:
            break
        cells -= set(rem)
    ## tek hücrelik delikleri doldurma YOK (delik = izin verilmeyen hücre olabilir); en büyük 4-bağlı parça (tohumu içeren tercih)
    comps, seen = [], set()
    for c in cells:
        if c in seen:
            continue
        st, comp = [c], []
        seen.add(c)
        while st:
            p = st.pop()
            comp.append(p)
            for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (p[0] + a, p[1] + b)
                if q in cells and q not in seen:
                    seen.add(q)
                    st.append(q)
        comps.append(comp)
    if not comps:
        return set()
    comps.sort(key=lambda c: (seed in c, len(c)), reverse=True)
    return set(comps[0])


def smooth(cells, ok):
    """tek hücrelik çentik/basamakları azalt: boş hücre 3+ dik komşusu ya da 5+ (8'den) komşusu öbekteyse eklenir, öbek hücresi 2- komşuluysa çıkar
    (karo tabanlı çalılıkta her basamak keskin bir iç köşe çizer - kullanıcı 'blok oyunlarına benziyor' demişti, madde 67)"""
    cells = set(cells)
    for _ in range(2):
        cand = {(x + a, y + b) for (x, y) in cells for a in (-1, 0, 1) for b in (-1, 0, 1)}
        nxt = set()
        for c in cand:
            n8 = sum((c[0] + a, c[1] + b) in cells for a in (-1, 0, 1) for b in (-1, 0, 1) if a or b)
            n4 = sum((c[0] + a, c[1] + b) in cells for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if c in cells:
                if n8 >= 3:
                    nxt.add(c)
            elif ok(c) and (n4 >= 3 or n8 >= 5):
                nxt.add(c)
        cells = nxt
    return cells


def has_hole(cells):
    """öbeğin içinde kapalı boşluk (içerideki ağaç/süs hücresi) var mı: dış çerçeveden 4-komşu taşma ile ulaşılamayan boş hücre"""
    xs = [c[0] for c in cells]
    ys = [c[1] for c in cells]
    x0, x1, y0, y1 = min(xs) - 1, max(xs) + 1, min(ys) - 1, max(ys) + 1
    seen = {(x0, y0)}
    st = [(x0, y0)]
    while st:
        p = st.pop()
        for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (p[0] + a, p[1] + b)
            if x0 <= q[0] <= x1 and y0 <= q[1] <= y1 and q not in seen and q not in cells:
                seen.add(q)
                st.append(q)
    return (x1 - x0 + 1) * (y1 - y0 + 1) - len(seen) - len(cells) > 0


def deep_count(cells):
    return sum(all((x + a, y + b) in cells for a in (-1, 0, 1) for b in (-1, 0, 1)) for (x, y) in cells)


def main():
    src = SRC if os.path.exists(SRC) else TMX
    text = open(src, encoding='utf-8', newline='').read()
    g = read_back(src)
    print('kaynak', os.path.basename(src), '| eski çalılık hücresi', int((g[LAYER] != 0).sum()))
    C = classify(g, text)
    obst = C['wall'] | C['trees'] | C['build'] | C['road'] | C['water'] | C['decor'] | C['old']
    d_water = dist(C['water'], 8)
    d_wall = dist(C['wall'], 8)
    d_trees = dist(C['trees'], 8)
    d_build = dist(C['build'], 8)
    d_road = dist(C['road'], 8)
    d_decor = dist(C['decor'], 8)
    d_old = dist(C['old'], 12)
    d_obst = dist(obst, 12)
    sx, sy = SPAWN
    yy, xx = np.mgrid[0:H2, 0:W2]
    far_spawn = (xx + X0 - sx) ** 2 + (yy + Y0 - sy) ** 2 > 10 ** 2
    ## çalılık hücresine izin: oyun alanı, engelsiz, duvara >= 2 (dar geçit/yamaç dibi değil), binaya >= 4, yola >= 2, ağaca/süse >= 1, suya >= 1, eski çalılığa >= GAP_OLD
    allowed = (C['play'] & ~obst & (d_wall >= 2) & (d_build >= 4) & (d_road >= 2) & (d_trees >= 1) & (d_decor >= 1) & (d_water >= 1)
               & (d_old >= GAP_OLD) & far_spawn)
    rng = random.Random(SEED)
    seeds_su = [(int(x), int(y)) for y, x in zip(*np.nonzero(allowed & (d_water <= 2)))]
    seeds_cay = [(int(x), int(y)) for y, x in zip(*np.nonzero(allowed & (d_obst >= 4)))]
    rng.shuffle(seeds_su)
    rng.shuffle(seeds_cay)
    taken = np.zeros((H2, W2), bool)
    patches = []

    def try_place(kind, sxy):
        x, y = sxy
        if taken[max(0, y - GAP_NEW):y + GAP_NEW + 1, max(0, x - GAP_NEW):x + GAP_NEW + 1].any():
            return False
        rx, ry = rng.choices(SIZES, SIZE_W)[0]
        if kind == 'su':
            ## kıyı boyunca: yakındaki su hücrelerine olan ortalama yön = normal, büyük eksen ona dik; merkez sudan 1-2 hücre içeri
            ws = [(a, b) for b in range(-5, 6) for a in range(-5, 6) if 0 <= y + b < H2 and 0 <= x + a < W2 and C['water'][y + b, x + a]]
            if not ws:
                return False
            nx = sum(a for a, _ in ws) / len(ws)
            ny = sum(b for _, b in ws) / len(ws)
            ang = math.atan2(ny, nx) + math.pi / 2
            ## eksen yatay/dikey'e oturtulur (kıyıya en yakın olan): çapraz elips karo ızgarasında merdiven basamağı çiziyordu (en 'blok' görünüm)
            ang = (0.0 if abs(math.cos(ang)) >= abs(math.sin(ang)) else math.pi / 2) + rng.uniform(-0.15, 0.15)
            ln = math.hypot(nx, ny) or 1.0
            cx, cy = int(round(x - nx / ln * (ry - 0.5))), int(round(y - ny / ln * (ry - 0.5)))
        else:
            ang = rng.uniform(-0.35, 0.35)
            cx, cy = x, y
        def ok(c):
            return 0 <= c[1] < H2 and 0 <= c[0] < W2 and allowed[c[1], c[0]]
        cells = {c for c in blob(cx, cy, rx, ry, ang, rng) if ok(c)}
        cells = smooth(cells, ok)
        cells = clean(cells, (x, y))
        if len(cells) < 16 or deep_count(cells) < 2 or has_hole(cells):
            return False
        xs_ = [c[0] for c in cells]
        ys_ = [c[1] for c in cells]
        if max(xs_) - min(xs_) + 1 < 5 or max(ys_) - min(ys_) + 1 < 3:
            return False
        m = np.zeros((H2, W2), bool)
        for c in cells:
            m[c[1], c[0]] = True
        if (dist(m, GAP_NEW) <= GAP_NEW)[taken].any():
            return False
        taken[m] = True
        patches.append((kind, sorted(cells)))
        return True

    for kind, pool, n in (('su', seeds_su, N_SU), ('çayır', seeds_cay, N_CAYIR)):
        got = 0
        for s in pool:
            if got >= n:
                break
            if try_place(kind, s):
                got += 1
        print(kind, 'öbek', got, '/', n, '(aday', len(pool), ')')
    new_cells = {}
    for kind, cells in patches:
        for c in cells:
            new_cells[c] = kind
    ## mevcut hücreler (TMX): gid -> (maske, çeşit) aynen
    old_cells = {}
    gl = g[LAYER]
    for y, x in zip(*np.nonzero(gl)):
        v = (int(gl[y, x]) & 0x1FFFFFFF) - FIRSTGID
        old_cells[(int(x) + X0, int(y) + Y0)] = (v % COLS, v // COLS)
    ## yeni hücrelerin karosu (mutlak hücre koordinatı)
    absnew = {(x + X0, y + Y0) for (x, y) in new_cells}
    allc = set(old_cells) | absnew
    rng2 = random.Random(SEED + 1)
    seed_of = {c: v[1] for c, v in old_cells.items()}
    out_new = []
    for (x, y) in sorted(absnew, key=lambda c: (c[1], c[0])):
        mk = (1 if (x, y - 1) not in allc else 0) | (2 if (x, y + 1) not in allc else 0) | (4 if (x - 1, y) not in allc else 0) | (8 if (x + 1, y) not in allc else 0)
        avoid = {seed_of.get((x - 1, y)), seed_of.get((x, y - 1))}
        opts = [s for s in range(SEEDS) if s not in avoid] or list(range(SEEDS))
        s = rng2.choice(opts)
        seed_of[(x, y)] = s
        out_new.append({'x': x, 'y': y, 'ax': mk, 'ay': s})
    tum = [{'x': x, 'y': y, 'ax': a, 'ay': b} for (x, y), (a, b) in sorted(old_cells.items(), key=lambda kv: (kv[0][1], kv[0][0]))] + out_new
    print('yeni hücre', len(out_new), '| toplam', len(tum), '| derin hücre/öbek', [deep_count(set(c)) for _, c in patches])
    json.dump(out_new, open(os.path.join(OUT, 'ek_hucreler.json'), 'w'))
    json.dump(tum, open(os.path.join(OUT, 'lol_hucreler_tum.json'), 'w'))
    json.dump([{'tur': k, 'hucre': [[x + X0, y + Y0] for x, y in c]} for k, c in patches], open(os.path.join(OUT, 'ek_obekler.json'), 'w', encoding='utf-8'), ensure_ascii=False)
    preview(C, new_cells)
    if '--apply' in sys.argv:
        apply(out_new, sys.argv[sys.argv.index('--apply') + 1])


def preview(C, new_cells):
    S = 3
    img = np.zeros((PLAY, PLAY, 3), np.uint8)
    sl = (slice(-Y0, -Y0 + PLAY), slice(-X0, -X0 + PLAY))
    img[:] = (118, 168, 84)
    for key, col in (('road', (196, 170, 120)), ('decor', (90, 130, 64)), ('trees', (44, 92, 48)), ('wall', (70, 70, 64)), ('water', (70, 130, 200)),
                     ('build', (150, 90, 60)), ('old', (40, 120, 40))):
        img[C[key][sl]] = col
    for (x, y), k in new_cells.items():
        img[y + Y0, x + X0] = (255, 236, 60) if k == 'su' else (255, 140, 40)   ## dizi indisi -> oyun alanı pikseli
    big = Image.fromarray(img).resize((PLAY * S, PLAY * S), Image.NEAREST)
    big.save(os.path.join(OUT, 'ek_onizleme.png'))


def layer_block(text):
    m = re.search(r'(<layer id="\d+" name="%s"[^>]*>\r?\n   <data encoding="csv">\r?\n)(.*?)(\r?\n   </data>)' % re.escape(LAYER_NAME), text, re.S)
    assert m, 'katman yok'
    return m


def apply(out_new, want):
    have = md5(TMX)
    if have != want:
        print('DURDU: Harita.tmx md5 değişmiş (%s), Tiled\'dan kaydedilmiş olabilir' % have)
        sys.exit(2)
    text = open(TMX, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in text else '\n'
    m = layer_block(text)
    base = layer_block(open(SRC, encoding='utf-8', newline='').read()) if os.path.exists(SRC) else m   ## katman tabanı = ek öncesi çalılık
    chunks = {}
    order = []
    for cm in re.finditer(r'<chunk x="(-?\d+)" y="(-?\d+)" width="16" height="16">\s*(.*?)\s*</chunk>', base.group(2), re.S):
        cx, cy = int(cm.group(1)), int(cm.group(2))
        vals = np.array([int(v) for v in cm.group(3).replace('\r', '').replace('\n', '').split(',') if v.strip()], np.int64).reshape(16, 16)
        chunks[(cx, cy)] = vals
        order.append((cx, cy))
    for c in out_new:
        cx, cy = (c['x'] // 16) * 16, (c['y'] // 16) * 16
        if (cx, cy) not in chunks:
            chunks[(cx, cy)] = np.zeros((16, 16), np.int64)
        assert chunks[(cx, cy)][c['y'] - cy, c['x'] - cx] == 0, ('dolu hücreye yazılıyordu', c)
        chunks[(cx, cy)][c['y'] - cy, c['x'] - cx] = FIRSTGID + c['ay'] * COLS + c['ax']
    keys = sorted(chunks, key=lambda k: (k[1], k[0]))
    parts = []
    for (cx, cy) in keys:
        rows = [','.join(str(int(v)) for v in r) for r in chunks[(cx, cy)]]
        parts.append('    <chunk x="%d" y="%d" width="16" height="16">%s%s%s</chunk>' % (cx, cy, nl, (',' + nl).join(rows), nl))
    body = nl.join(parts)
    stamp = os.path.join(YEDEK, 'Harita_2026-10-19_oncesi_ek-calilik.tmx.bak')
    if not os.path.exists(stamp):
        shutil.copy2(TMX, stamp)
    res = text[:m.start(2)] + body + text[m.end(2):]
    tmp = TMX + '.tmp'
    open(tmp, 'w', encoding='utf-8', newline='').write(res)
    os.replace(tmp, TMX)
    print('YAZILDI. chunk', len(order), '->', len(keys), '| yeni md5', md5(TMX))


if __name__ == '__main__':
    main()
