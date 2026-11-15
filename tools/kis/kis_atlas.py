# AYAZ DAĞI (kış haritası, 2026-11-12) atlasları: craftpix kış setinin karo sayfaları + tek tek kesilmiş nesneler proje içine (harita/kis/).
# Kaynak (proje DIŞI, salt okunur): ../Harita içerikleri/Kis Tileseti/Tiled_files (craftpix-net-448424 winter top-down; örnek harita Winter.tmx).
# Altın Kumlar atlasının (tools/col/col_atlas.py) kış karşılığı - aynı paket ailesi, aynı karo düzeni + aynı nesne atlası kuralları.
#
# Zemin sayfaları kaynağın düzeniyle AYNI (üreteç kaynak koordinatlarıyla yazılmış):
#   k_zemin.png  = Ground_ice (kar dolgu (13,30); kar adası bloğu (12,29)+(15,29); toprak yaması bloğu (1,29)+(4,29); buz dolgu 2x2 x5 satır 45-46)
#   k_catlak.png = cracks (çatlaklı TAM buz karoları: 2x2 küçük, 4x4 büyük - buz dolgunun yerine konur)
#   k_leke.png   = spots (toprak lekeleri üst yarı, kar lekeleri alt yarı)
#   k_su.png     = water_detilazation (sıcak kaynağın dalga izleri; örnek Winter.tmx animasyonları: kare = taban + 481k, 6 kare)
# Nesne atlası k_nesne.png (kaynaktan opak sınıra kırpılır, karo bloğuna ALTTAN oturur, yatayda ortalı, aralarında 1 boş karo - "atlasta komşu
# karo = aynı nesne" kuralı, depth_occluders / tree_sway / terrain_collision):
#   Objects.png kar tabanlı çeşit (satır 0-44) = anahtar_s, toprak tabanlı çeşit (satır 44-88, +704 px) = anahtar_g; Ground_ice'ın kapalı kaya
#   tepeleri (tepe_*); details.png kar / toprak öbekleri; Ground_ice ayak izleri + buz deliği.
#   ATEŞ (kış setinde ateş YOK, oyunun mevcut sanatı): kamp ateşi (assets/map/kamp/ates.png, 12 kare), meşale (Kara Bataklık meşalesi
#   harita/bataklik/b_nesne.png - yeşil alevi zindan ateşinin turuncu rampasına, dibindeki çimen tutamı kara boyanır; yalnız TON), ayaklı
#   mangal + büyük mangal (Piksel Zindan fire_animation, 6 kare; içine çizili koyu hale saydam yapılır - karda kirli leke gibi duruyordu, gece
#   ışığını kis_fx.gd verir), çadır + kütük (assets/map/kamp).
# k_calilik.png = saklanma çalılığı atlası (harita/saklanma_calilik.png) kışın donuk çam yeşili -> kırağı rampasına boyanmış hâli.
# Tablo: tools/kis/atlas.json. Kullanım (proje kökünden): python -I tools/kis/kis_atlas.py
import json
import os
import sys
import xml.etree.ElementTree as ET
from collections import Counter

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.normpath(os.path.join(ROOT, '..', 'Harita içerikleri', 'Kis Tileseti', 'Tiled_files'))
ZINDAN_FIRE = os.path.normpath(os.path.join(ROOT, '..', 'Harita içerikleri', 'Piksel Zindan Assetleri', 'Tiled_files', 'fire_animation.png'))
KAMP = os.path.join(ROOT, 'assets', 'map', 'kamp')
SWAMP_ATLAS = os.path.join(ROOT, 'tools', 'bataklik', 'atlas.json')
SWAMP_OBJ = os.path.join(ROOT, 'harita', 'bataklik', 'b_nesne.png')
OUT = os.path.join(ROOT, 'harita', 'kis')
JSON_OUT = os.path.join(ROOT, 'tools', 'kis', 'atlas.json')
T = 16
FRAME_MS = 150
GROUND_SHIFT_Y = 704  ## Objects.png: toprak tabanlı çeşitler kar çeşitlerinin 44 karo altında (ölçüldü: şablon eşleşmesi)

## Objects.png kar çeşidinin piksel dikdörtgeni (x0, y0, x1, y1; içeride opak sınıra kırpılır) -> tür. Toprak çeşidi +704 px (boyu tutmayan alınmaz).
## tür: agac (Ağaç katmanı, sallanır) / nesne (y-sıralı "Animasyonsuz çalılar"; katılığı terrain_collision is_solid_prop) / kaya (y-sıralı kaya
## katmanları, üst üste binebilir) / bitki (sallanan küçük bitki) / cicek / yassi (yere serili: "Yer/Kar süsleri"). Kristal ve mantar
## filizleri bitki DEĞİL nesne: rüzgârda sallanmasınlar.
STATIC = {
    'yuvarlak_agac_1': ((18, 17, 95, 100), 'agac'), 'yuvarlak_agac_2': ((96, 34, 145, 96), 'agac'),
    'yuvarlak_agac_3': ((152, 64, 182, 96), 'agac'), 'harabe_ev': ((18, 100, 126, 196), 'kaya'),
    'kizil_agac_1': ((190, 18, 256, 96), 'agac'), 'kizil_agac_2': ((261, 32, 315, 99), 'agac'), 'kizil_agac_3': ((328, 52, 361, 96), 'agac'),
    'kaya_buyuk': ((369, 34, 431, 97), 'kaya'), 'kaya_orta': ((436, 48, 492, 99), 'kaya'), 'kaya_kucuk': ((504, 64, 537, 97), 'kaya'),
    'tas_1': ((548, 51, 573, 76), 'yassi'), 'tas_2': ((552, 80, 567, 97), 'yassi'),
    'harabe_kule': ((133, 117, 202, 187), 'kaya'), 'harabe_kemer': ((210, 131, 268, 192), 'kaya'), 'harabe_duvar': ((275, 144, 319, 192), 'kaya'),
    'harabe_kucuk': ((322, 161, 349, 194), 'kaya'),
    'cam_yuvarlak_1': ((387, 117, 458, 193), 'agac'), 'cam_yuvarlak_2': ((466, 128, 525, 194), 'agac'), 'cam_yuvarlak_3': ((534, 150, 573, 191), 'agac'),
    'dev_buz_agaci': ((14, 192, 278, 399), 'nesne'),
    'kardan_adam_1': ((210, 218, 254, 273), 'nesne'), 'kardan_adam_2': ((274, 221, 302, 272), 'nesne'), 'kardan_adam_3': ((326, 224, 357, 273), 'nesne'),
    'kardan_adam_4': ((374, 233, 409, 268), 'nesne'), 'kardan_adam_5': ((428, 242, 450, 269), 'nesne'), 'kardan_adam_6': ((471, 246, 489, 269), 'nesne'),
    'totem_1': ((516, 196, 571, 271), 'nesne'), 'totem_2': ((529, 272, 559, 336), 'nesne'),
    'buz_agaci_1': ((291, 274, 399, 399), 'agac'), 'buz_agaci_2': ((414, 302, 494, 399), 'agac'), 'buz_agaci_3': ((516, 338, 571, 396), 'agac'),
    'yilbasi_agaci': ((19, 394, 108, 509), 'agac'),
    'cam_1': ((130, 418, 206, 510), 'agac'), 'cam_2': ((226, 436, 289, 508), 'agac'), 'cam_3': ((311, 450, 347, 496), 'agac'),
    'mantar_agac_1': ((381, 405, 448, 494), 'agac'), 'mantar_agac_2': ((466, 424, 509, 489), 'agac'), 'mantar_agac_3': ((534, 438, 569, 487), 'agac'),
    'mantar_1': ((19, 514, 79, 591), 'nesne'), 'mantar_2': ((83, 534, 125, 596), 'nesne'), 'mantar_3': ((130, 548, 159, 589), 'nesne'),
    'buz_cicek_1': ((178, 544, 223, 595), 'cicek'), 'buz_cicek_2': ((241, 550, 271, 591), 'cicek'), 'buz_cicek_3': ((295, 563, 317, 591), 'cicek'),
    'kristal_dev': ((337, 511, 454, 591), 'nesne'), 'kristal_2': ((469, 529, 524, 593), 'nesne'), 'kristal_3': ((535, 548, 568, 589), 'nesne'),
    'diken_cicek_1': ((291, 596, 335, 669), 'bitki'), 'diken_cicek_2': ((337, 615, 381, 668), 'bitki'), 'diken_cicek_3': ((388, 616, 415, 666), 'bitki'),
    'kizil_kristal_1': ((433, 596, 480, 658), 'nesne'), 'kizil_kristal_2': ((502, 612, 537, 660), 'nesne'), 'kizil_kristal_3': ((552, 617, 570, 655), 'nesne'),
    'kaya_yigin': ((145, 626, 221, 704), 'kaya'), 'kaya_yay': ((226, 647, 285, 702), 'kaya'), 'tas_3': ((291, 679, 319, 703), 'yassi'),
    'buz_kristal_1': ((484, 677, 521, 713), 'nesne'), 'buz_kristal_2': ((528, 674, 576, 719), 'nesne'),
    'buz_kristal_3': ((420, 690, 443, 712), 'nesne'), 'buz_kristal_4': ((449, 690, 478, 716), 'nesne'),
}
## Ground_ice.png kapalı kaya tepeleri (setin yükselti karolarından tek parça çizilmiş "mesa"lar): dağ kayası olarak y-sıralı, katı.
## _s = kar eteği, _g = toprak eteği.
TEPE = {
    'tepe_s': (24, 149, 88, 200), 'tepe_krater_s': (280, 149, 344, 200),
    'tepe_g': (27, 53, 85, 102), 'tepe_krater_g': (283, 53, 340, 102),
    'tepe_yuksek_g': (24, 256, 97, 320), 'tepe_krater_yuksek_g': (280, 256, 353, 320),
}
## Ground_ice.png buz deliği (karın içinde 2x2 açık su deliği; olta deliği) - yere serili
ICE_HOLE = (144, 568, 176, 608)
## Ground_ice.png ayak izi grupları (satır 41-46, sütun 18-30): bileşenler (2 px boşlukla) ayrı yere serili süs
FOOTPRINT_RECT = (288, 656, 496, 752)
## details.png: kar öbekleri (y < 64) ve toprak öbekleri (y >= 64)
DETAIL_SPLIT_Y = 64

## Zindan ateşi (fire_animation.png, 11 sütun, 6 kare = 3 satır aralık): küçük ayaklı mangal sütun 8-10, büyük mangal (kase) sütun 5-7
FIRE_ANIM = {'mangal': (8, 0, 3, 3), 'buyuk_mangal': (5, 0, 3, 3)}
FIRE_FRAMES, FIRE_STRIDE_ROWS = 6, 3
HALO_ALPHA = 200  ## bunun altındaki alfa = içine çizili hale (saydam yapılır)


def crop_opaque(img, rect):
    x0, y0, x1, y1 = rect
    sub = img.crop((x0, y0, x1, y1))
    bb = sub.getbbox()
    if bb is None:
        return None
    return sub.crop(bb)


## Dikdörtgeni komşu nesnelere taşan büyük nesneler: yalnız en büyük piksel kümesi (8-komşu, 1 px boşluk köprülenir) alınır - piksel piksel.
MAIN_ONLY = {'dev_buz_agaci'}


def main_component(img, rect):
    a = np.array(img.crop(rect))
    op = a[..., 3] > 0
    h, w = op.shape
    lab = np.zeros((h, w), np.int32)
    sizes = [0]
    n = 0
    for y0, x0 in zip(*np.nonzero(op)):
        if lab[y0, x0]:
            continue
        n += 1
        lab[y0, x0] = n
        st = [(y0, x0)]
        c = 0
        while st:
            y, x = st.pop()
            c += 1
            for dy in (-2, -1, 0, 1, 2):
                for dx in (-2, -1, 0, 1, 2):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and op[ny, nx] and not lab[ny, nx]:
                        lab[ny, nx] = n
                        st.append((ny, nx))
        sizes.append(c)
    if n == 0:
        return None
    a[lab != int(np.argmax(sizes))] = 0
    out = Image.fromarray(a, 'RGBA')
    return out.crop(out.getbbox())


def green_ratio(im):
    a = np.array(im).astype(float) / 255.0
    op = a[..., 3] > 0.5
    if op.sum() == 0:
        return 0.0
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return float(((g > r + 0.05) & (g > b + 0.05) & op).sum()) / float(op.sum())


def write_tsx(path, name, img_file, w, h, anims):
    cols = w // T
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<tileset version="1.10" tiledversion="1.12.2" name="%s" tilewidth="16" tileheight="16" tilecount="%d" columns="%d">' % (name, cols * (h // T), cols),
             ' <image source="%s" width="%d" height="%d"/>' % (img_file, w, h)]
    for tid in sorted(anims):
        lines.append(' <tile id="%d">' % tid)
        lines.append('  <animation>')
        for f in anims[tid]:
            lines.append('   <frame tileid="%d" duration="%d"/>' % (f, FRAME_MS))
        lines.append('  </animation>')
        lines.append(' </tile>')
    lines.append('</tileset>')
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


def tmx_inline_anims(path, ts_name):
    node = ET.parse(path).getroot()
    for ts in node.findall('tileset'):
        if ts.get('name') != ts_name:
            continue
        out = {}
        for t in ts.findall('tile'):
            a = t.find('animation')
            if a is not None:
                out[int(t.get('id'))] = [int(f.get('tileid')) for f in a.findall('frame')]
        return out
    return {}


def canonical_anims(name, anims):
    offs = Counter(tuple(f - tid for f in fr) for tid, fr in anims.items())
    canon = list(offs.most_common(1)[0][0])
    fixed = 0
    out = {}
    for tid, fr in anims.items():
        want = [tid + o for o in canon]
        if fr != want:
            fixed += 1
            fr = want
        out[tid] = fr
    if fixed:
        print('  %s: %d animasyonun kayık karesi düzeltildi' % (name, fixed))
    return out


def build_sheets():
    info = {}
    for name, fname, src in [('Kış zemin', 'k_zemin.png', 'Ground_ice.png'), ('Kış çatlak', 'k_catlak.png', 'cracks.png'),
                             ('Kış leke', 'k_leke.png', 'spots.png')]:
        img = Image.open(os.path.join(SRC, src)).convert('RGBA')
        img.save(os.path.join(OUT, fname))
        write_tsx(os.path.join(OUT, name + '.tsx'), name, fname, img.width, img.height, {})
        info[name] = {'file': fname, 'cols': img.width // T, 'w': img.width, 'h': img.height, 'anims': 0}
    simg = Image.open(os.path.join(SRC, 'water_detilazation.png')).convert('RGBA')
    simg.save(os.path.join(OUT, 'k_su.png'))
    san = canonical_anims('Kış su', tmx_inline_anims(os.path.join(SRC, 'Winter.tmx'), 'Water_detilazation'))
    san.pop(0, None)  ## (0,0) düz su (animasyonsuz)
    write_tsx(os.path.join(OUT, 'Kış su.tsx'), 'Kış su', 'k_su.png', simg.width, simg.height, san)
    info['Kış su'] = {'file': 'k_su.png', 'cols': simg.width // T, 'w': simg.width, 'h': simg.height, 'anims': len(san)}
    return info


## ---------------------------------------------------------------- ateş yeniden boyama (yalnız ton)
def _hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(axis=-1), rgb.min(axis=-1)
    d = mx - mn + 1e-6
    hue = np.where(mx == r, ((g - b) / d) % 6.0, np.where(mx == g, (b - r) / d + 2.0, (r - g) / d + 4.0)) / 6.0
    sat = d / (mx + 1e-6)
    return hue, sat, mx


def _lum(rgb):
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def fire_ramp():
    """zindan ateşinin (ayaklı mangal, kare 0) alev renkleri, parlaklık sırasıyla"""
    img = np.array(Image.open(ZINDAN_FIRE).convert('RGBA')).astype(float) / 255.0
    sub = img[0:48, 128:176]
    op = sub[..., 3] > 0.95
    hue, sat, val = _hsv(sub[..., :3])
    flame = op & ((hue < 0.17) | (hue > 0.95)) & (sat > 0.35) & (val > 0.45)
    cols = {tuple((sub[y, x, :3] * 255).round().astype(int)) for y, x in zip(*np.nonzero(flame))}
    return sorted(cols, key=lambda c: c[0] * 0.299 + c[1] * 0.587 + c[2] * 0.114)


SNOW_TUFT = [(150, 170, 186), (186, 204, 214), (214, 228, 234), (236, 243, 246)]  ## setin kar öbeği tonları (koyu -> açık)


def recolor_torch(frames):
    ramp = fire_ramp()
    out = []
    for im in frames:
        a = np.array(im).astype(float) / 255.0
        rgb = a[..., :3]
        hue, sat, val = _hsv(rgb)
        op = a[..., 3] > 0
        teal = op & (hue > 0.36) & (hue < 0.58) & (sat > 0.18)
        olive = op & (hue > 0.14) & (hue <= 0.36) & (sat > 0.25)
        lum = _lum(rgb)
        res = (a * 255).round().astype(np.uint8)
        if teal.any():
            lo, hi = lum[teal].min(), lum[teal].max()
            for y, x in zip(*np.nonzero(teal)):
                t = (lum[y, x] - lo) / max(1e-6, hi - lo)
                c = ramp[min(len(ramp) - 1, int(round(t * (len(ramp) - 1))))]
                res[y, x, :3] = c
        if olive.any():
            lo, hi = lum[olive].min(), lum[olive].max()
            for y, x in zip(*np.nonzero(olive)):
                t = (lum[y, x] - lo) / max(1e-6, hi - lo)
                res[y, x, :3] = SNOW_TUFT[min(len(SNOW_TUFT) - 1, int(round(t * (len(SNOW_TUFT) - 1))))]
        out.append(Image.fromarray(res, 'RGBA'))
    return out


def strip_halo(im):
    a = np.array(im)
    a[a[..., 3] < HALO_ALPHA] = 0
    return Image.fromarray(a, 'RGBA')


def common_crop(frames):
    bb = None
    for f in frames:
        b = f.getbbox()
        if b:
            bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]), max(bb[2], b[2]), max(bb[3], b[3]))
    return [f.crop(bb) for f in frames]


def components(alpha, gap):
    """opak piksel kümeleri (4-komşu, gap kadar genişletilmiş) -> [(x0, y0, x1, y1)]"""
    h, w = alpha.shape
    d = alpha.copy()
    for _ in range(gap):
        n = d.copy()
        n[1:] |= d[:-1]
        n[:-1] |= d[1:]
        n[:, 1:] |= d[:, :-1]
        n[:, :-1] |= d[:, 1:]
        d = n
    seen = np.zeros_like(d)
    out = []
    for y0, x0 in zip(*np.nonzero(d)):
        if seen[y0, x0]:
            continue
        st = [(y0, x0)]
        seen[y0, x0] = True
        ys, xs = [], []
        while st:
            y, x = st.pop()
            ys.append(y)
            xs.append(x)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and d[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    st.append((ny, nx))
        ys, xs = np.array(ys), np.array(xs)
        m = alpha[ys, xs]
        if m.sum() < 12:
            continue
        out.append((int(xs[m].min()), int(ys[m].min()), int(xs[m].max()) + 1, int(ys[m].max()) + 1))
    return sorted(out, key=lambda b: (b[1] // 16, b[0]))


def collect_items():
    obj = Image.open(os.path.join(SRC, 'Objects.png')).convert('RGBA')
    gi = Image.open(os.path.join(SRC, 'Ground_ice.png')).convert('RGBA')
    det = Image.open(os.path.join(SRC, 'details.png')).convert('RGBA')
    items = []

    def add(key, kind, frames):
        assert frames and frames[0] is not None, key
        items.append({'key': key, 'kind': kind, 'frames': frames})

    for key, (rect, kind) in STATIC.items():
        crop = main_component if key in MAIN_ONLY else crop_opaque
        sim = crop(obj, rect)
        add(key + '_s', kind, [sim])
        x0, y0, x1, y1 = rect
        gim = crop(obj, (x0, y0 + GROUND_SHIFT_Y, x1, y1 + GROUND_SHIFT_Y))
        ## toprak çeşidi: aynı boyda olmalı (kaynakta bazı küçük taşların toprak çeşidi yok / kayık) - değilse alınmaz
        if gim is not None and abs(gim.width - sim.width) <= 8 and abs(gim.height - sim.height) <= 8:
            add(key + '_g', kind, [gim])
        else:
            print('  toprak çeşidi yok:', key, None if gim is None else gim.size, sim.size)
    for key, rect in TEPE.items():
        add(key, 'kaya', [crop_opaque(gi, rect)])
    add('buz_deligi', 'yassi', [crop_opaque(gi, ICE_HOLE)])
    fa = np.array(gi)[..., 3] > 0
    sub = np.zeros_like(fa)
    x0, y0, x1, y1 = FOOTPRINT_RECT
    sub[y0:y1, x0:x1] = fa[y0:y1, x0:x1]
    k = 0
    for (bx0, by0, bx1, by1) in components(sub, 3):
        if (bx1 - bx0) * (by1 - by0) < 60:
            continue
        k += 1
        add('iz_%d' % k, 'yassi', [gi.crop((bx0, by0, bx1, by1))])
    da = np.array(det)[..., 3] > 0
    ks = kg = 0
    for (bx0, by0, bx1, by1) in components(da, 1):
        im = det.crop((bx0, by0, bx1, by1))
        if (by0 + by1) / 2.0 < DETAIL_SPLIT_Y:
            ks += 1
            add('kar_obek_%d' % ks, 'yassi', [im])
        else:
            kg += 1
            add('toprak_obek_%d' % kg, 'yassi', [im])
    ## ATEŞ: kamp ateşi (12 kare yatay şerit 36x29)
    ates = Image.open(os.path.join(KAMP, 'ates.png')).convert('RGBA')
    fw = ates.width // 12
    add('kamp_atesi', 'ates', common_crop([ates.crop((i * fw, 0, (i + 1) * fw, ates.height)) for i in range(12)]))
    ## meşale (bataklık meşalesi, alev turuncuya)
    sw = json.load(open(SWAMP_ATLAS, encoding='utf-8'))['objects']['mesale']
    simg = Image.open(SWAMP_OBJ).convert('RGBA')
    fr = []
    for i in range(sw['frames']):
        ty = sw['ay'] + i * (sw['ht'] + 1)
        fr.append(simg.crop((sw['ax'] * T, ty * T, (sw['ax'] + sw['wt']) * T, (ty + sw['ht']) * T)))
    add('mesale', 'mesale', common_crop(recolor_torch(fr)))
    ## ayaklı mangal + ateş çukuru (zindan ateşi; içine çizili hale saydam)
    zf = Image.open(ZINDAN_FIRE).convert('RGBA')
    for key, (c, r, wt, ht) in FIRE_ANIM.items():
        frs = [strip_halo(zf.crop((c * T, (r + i * FIRE_STRIDE_ROWS) * T, (c + wt) * T, (r + i * FIRE_STRIDE_ROWS + ht) * T)))
               for i in range(FIRE_FRAMES)]
        add(key, 'ates', common_crop(frs))
    ## kamp: çadırlar + kütükler
    for key, fname, kind in [('cadir_1', 'tent1.png', 'kaya'), ('cadir_2', 'tent2.png', 'kaya'), ('kutuk_yatay', 'logs_0.png', 'nesne'),
                             ('kutuk_yatay_2', 'logs_3.png', 'nesne'), ('kutuk_dik', 'logs_1.png', 'nesne')]:
        im = Image.open(os.path.join(KAMP, fname)).convert('RGBA')
        add(key, kind, [im.crop(im.getbbox())])
    return items


def pack(items, file_name, cols=64):
    for it in items:
        w, h = it['frames'][0].size
        it['w'], it['h'] = w, h
        it['wt'], it['ht'] = (w + T - 1) // T, (h + T - 1) // T
    items.sort(key=lambda it: (-(it['ht'] * len(it['frames']) + len(it['frames']) - 1), -it['wt'], it['key']))
    x = y = 0
    shelf_h = 0
    for it in items:
        nf = len(it['frames'])
        bh = it['ht'] * nf + (nf - 1)
        if x + it['wt'] > cols:
            x = 0
            y += shelf_h + 1
            shelf_h = 0
        it['ax'], it['ay'] = x, y
        x += it['wt'] + 1
        shelf_h = max(shelf_h, bh)
    rows = y + shelf_h
    atlas = Image.new('RGBA', (cols * T, rows * T), (0, 0, 0, 0))
    anims = {}
    catalog = {}
    for it in items:
        wt, ht = it['wt'], it['ht']
        ox = (wt * T - it['w']) // 2
        oy = ht * T - it['h']
        for k, f in enumerate(it['frames']):
            atlas.alpha_composite(f, (it['ax'] * T + ox, (it['ay'] + k * (ht + 1)) * T + oy))
        if len(it['frames']) > 1:
            for ty in range(ht):
                for tx in range(wt):
                    base = (it['ay'] + ty) * cols + it['ax'] + tx
                    anims[base] = [(it['ay'] + ty + k * (ht + 1)) * cols + it['ax'] + tx for k in range(len(it['frames']))]
        catalog[it['key']] = {'kind': it['kind'], 'ts': 'nesne', 'ax': it['ax'], 'ay': it['ay'], 'wt': wt, 'ht': ht,
                              'frames': len(it['frames']), 'ox': ox, 'oy': oy, 'w': it['w'], 'h': it['h'],
                              'green': round(green_ratio(it['frames'][0]), 3)}
    atlas.save(os.path.join(OUT, file_name))
    write_tsx(os.path.join(OUT, 'Kış nesne.tsx'), 'Kış nesne', file_name, atlas.width, atlas.height, anims)
    return catalog, {'file': file_name, 'cols': cols, 'w': atlas.width, 'h': atlas.height, 'anims': len(anims)}


## Saklanma çalılığı: KIRAĞILI ÇAM ÇALISI (atlasın uzun yaprak satırları). Rampa setin karlı çamlarından (koyu çam yeşili gölge -> kırağı
## beyazı uç): karda koyu bir halı gibi durmasın, kar yemiş çalı öbeği gibi okunsun.
WINTER_RAMP = [(44, 82, 88), (56, 100, 104), (70, 118, 120), (88, 136, 138), (108, 154, 156), (130, 172, 176), (152, 190, 194),
               (174, 206, 210), (196, 220, 226), (218, 234, 238), (238, 246, 250)]  ## ilk koyu rampa karda koyu halı gibiydi -> açık kırağı


def build_brush():
    src = Image.open(os.path.join(ROOT, 'harita', 'saklanma_calilik.png')).convert('RGBA')
    px = src.load()
    cols = sorted({px[x, y][:3] for y in range(src.height) for x in range(src.width) if px[x, y][3] > 0},
                  key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2])
    lum = [0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2] for c in cols]
    lo, hi = lum[0], lum[-1]
    m = {}
    for c, l in zip(cols, lum):
        t = (l - lo) / max(1e-6, hi - lo)
        m[c] = WINTER_RAMP[min(len(WINTER_RAMP) - 1, int(round(t * (len(WINTER_RAMP) - 1))))]
    out = Image.new('RGBA', src.size)
    op = out.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            op[x, y] = m[(r, g, b)] + (a,) if a > 0 else (0, 0, 0, 0)
    out.save(os.path.join(OUT, 'k_calilik.png'))
    write_tsx(os.path.join(OUT, 'Kış çalılık.tsx'), 'Kış çalılık', 'k_calilik.png', out.width, out.height, {})
    return {'file': 'k_calilik.png', 'cols': out.width // T, 'w': out.width, 'h': out.height, 'anims': 0}


def ensure_base_tiles():
    """k_taban.png: 0 = düz mavi su (collision su sayar; görünüşü kis_su.gdshader), 1 = tamamen saydam (görünmez engel)."""
    img = Image.new('RGBA', (32, 16), (0, 0, 0, 0))
    for y in range(16):
        for x in range(16):
            img.putpixel((x, y), (40, 96, 200, 255))
    img.save(os.path.join(OUT, 'k_taban.png'))
    write_tsx(os.path.join(OUT, 'Kış taban.tsx'), 'Kış taban', 'k_taban.png', 32, 16, {})
    return {'file': 'k_taban.png', 'cols': 2, 'w': 32, 'h': 16, 'anims': 0}


def main():
    for p in (SRC, ZINDAN_FIRE, SWAMP_OBJ):
        if not os.path.exists(p):
            print('Kaynak yok:', p)
            sys.exit(1)
    os.makedirs(OUT, exist_ok=True)
    sheets = build_sheets()
    sheets['Kış taban'] = ensure_base_tiles()
    cat, inf = pack(collect_items(), 'k_nesne.png')
    sheets['Kış nesne'] = inf
    sheets['Kış çalılık'] = build_brush()
    with open(JSON_OUT, 'w', encoding='utf-8') as f:
        json.dump({'sheets': sheets, 'objects': cat}, f, ensure_ascii=False, indent=1, sort_keys=True)
    for k, v in sheets.items():
        print('%-12s %s %dx%d anim=%d' % (k, v['file'], v['w'], v['h'], v['anims']))
    print('nesne: %d  %s' % (len(cat), dict(Counter(v['kind'] for v in cat.values()))))


if __name__ == '__main__':
    main()
