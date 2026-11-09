# KARA BATAKLIK atlasları (yeni harita, 2026-11-09): bataklık setinin karo sayfaları + tek tek nesneleri proje içine (harita/bataklik/).
# Kaynaklar (proje DIŞI, salt okunur): ../Harita içerikleri/craftpix-net-624156-swamp-top-down-tileset-pixel-art.zip (Tiled_files + Objects_separated)
# ve ../Harita içerikleri/Bataklık parçaları/PNG/Assets_no_shadow (ikinci bataklık paketi: kemikler, kavisli ağaçlar, mantar evi, heykeller...).
#
# Zemin sayfaları kaynağın düzeniyle AYNI (karo koordinatları kaynaktaki gibi, üreteç onlara göre yazılmış):
#   b_zemin.png  = Ground_grass_swamp (statik)        b_leke.png = spots (statik)
#   b_su.png     = water_detilazation_v2 (kare aralığı 13 satır, zaten düzenli)
#   b_nilufer.png= water_lilis (7 satır)              b_mercimek.png = duckweed (8 satır)
#   b_kiyi.png   = Water_coasts YENİDEN DİZİLİR: kaynağın animasyon kareleri DÜZENSİZ aralıklı (satır 1, 9, 16, 24, 31, 38) - Godot animasyonu
#                  sabit aralık ister (YATI ilk iki kareden aralık çıkarır, sonrakiler kayardı). Burada k. kare = taban satır + 8k.
# Nesne atlası b_nesne.png: her nesne opak sınırına kırpılır, 16 px'lik karo dikdörtgenine ALTTAN oturur (yatayda ortalı), nesneler arası en az
# 1 boş karo (derinlik / sallanma "atlasta komşu karo = aynı nesne" kuralı). Animasyonlu nesnelerin (cadı kulübesi, meşaleler, yüzlü ağaç) kareleri
# kendi bloklarının altında alt alta (aralık = boy + 1 karo), tileset'e Tiled <animation> yazılır. Tablo: tools/bataklik/atlas.json.
# Kullanım (proje kökünden): python -I tools/bataklik/bataklik_atlas.py
import io
import json
import os
import sys
import xml.etree.ElementTree as ET
import zipfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC_DIR = os.path.normpath(os.path.join(ROOT, '..', 'Harita içerikleri'))
ZIP = os.path.join(SRC_DIR, 'craftpix-net-624156-swamp-top-down-tileset-pixel-art.zip')
PACK2 = os.path.join(SRC_DIR, 'Bataklık parçaları', 'PNG', 'Assets_no_shadow')
OUT = os.path.join(ROOT, 'harita', 'bataklik')
JSON_OUT = os.path.join(ROOT, 'tools', 'bataklik', 'atlas.json')
T = 16
FRAME_MS = 150

## (tileset adı, dosya, kaynak, sütun, animasyon kaynağı)
SHEETS = [
    ('Bataklık zemin', 'b_zemin.png', 'Tiled_files/Ground_grass_swamp.png', None),
    ('Bataklık leke', 'b_leke.png', 'Tiled_files/spots.png', None),
    ('Bataklık su', 'b_su.png', 'Tiled_files/water_detilazation_v2.png', 'Tiled_files/Water_detilazation2.tsx'),
    ('Bataklık nilüfer', 'b_nilufer.png', 'Tiled_files/water_lilis.png', 'Tiled_files/water_lilis.tsx'),
    ('Bataklık mercimek', 'b_mercimek.png', 'Tiled_files/duckweed.png', 'Tiled_files/Swamp.tmx#duckweed'),
]
KIYI_SRC = ('Tiled_files/Water_coasts.png', 'Tiled_files/Water_coasts..tsx')
KIYI_BAND = 8  ## yeniden dizilmiş b_kiyi.png'de kare aralığı (satır)

## Nesneler: anahtar -> (kaynak, tür). kaynak: 'sep:<ad>' = Objects_separated/<ad>.png, 'p2:<ad>' = Bataklık parçaları/Assets_no_shadow/<ad>.png,
## 'seq:<ad>%d' = 1..6 kare dizisi, 'anim:<x>,<y>,<w>,<h>' = sprites_animated.png karo dikdörtgeni (6 kare, 23 satır aralık).
## tür: agac (sallanan ağaç katmanı) / nesne (y-sıralı engel adayı) / bitki (sallanan ot) / cicek / yassi (yere serili, karakterin altında) / anim
OBJECTS = {
    ## ağaçlar (Objects_separated)
    'olu_agac_1': ('sep:Tree1_1', 'agac'), 'olu_agac_2': ('sep:Tree1_2', 'agac'), 'olu_agac_3': ('sep:Tree1_3', 'agac'), 'olu_agac_4': ('sep:Tree1_4', 'agac'),
    'yesil_agac_1': ('sep:Tree2_1', 'agac'), 'yesil_agac_2': ('sep:Tree2_2', 'agac'), 'yesil_agac_3': ('sep:Tree2_3', 'agac'), 'yesil_agac_4': ('sep:Tree2_4', 'agac'),
    'egrelti_agac_1': ('sep:Tree3_1', 'agac'), 'egrelti_agac_2': ('sep:Tree3_2', 'agac'), 'egrelti_agac_3': ('sep:Tree3_3', 'agac'), 'egrelti_agac_4': ('sep:Tree3_4', 'agac'),
    'cali_agac_1': ('sep:Tree4_1', 'agac'), 'cali_agac_2': ('sep:Tree4_2', 'agac'), 'cali_agac_3': ('sep:Tree4_3', 'agac'),
    'kavisli_agac_1': ('p2:Curved_tree1', 'agac'), 'kavisli_agac_2': ('p2:Curved_tree2', 'agac'), 'kavisli_agac_3': ('p2:Curved_tree3', 'agac'), 'kavisli_agac_4': ('p2:Curved_tree4', 'agac'),
    'kafa_agaci_2': ('p2:Sculls_tree2', 'agac'), 'kafa_agaci_3': ('p2:Sculls_tree3', 'agac'), 'kafa_agaci_4': ('p2:Sculls_tree4', 'agac'),
    'egrelti_fidan_1': ('p2:Tree-fern1', 'agac'), 'egrelti_fidan_2': ('p2:Tree-fern2', 'agac'),
    ## büyük nesneler (y-sıralı)
    'harabe_1': ('sep:Ruins_grass_shadow1', 'nesne'), 'harabe_2': ('sep:Ruins_grass_shadow2', 'nesne'), 'harabe_3': ('sep:Ruins_grass_shadow3', 'nesne'),
    'harabe_4': ('sep:Ruins_grass_shadow4', 'nesne'), 'harabe_5': ('sep:Ruins_grass_shadow5', 'nesne'),
    'kaya_1': ('sep:Stone_grass_shadow2', 'nesne'), 'kaya_2': ('sep:Stone_grass_shadow3', 'nesne'), 'kaya_3': ('sep:Stone_grass_shadow4', 'nesne'),
    'kaya_4': ('sep:Stone_grass_shadow5', 'nesne'), 'kaya_5': ('sep:Stone_grass_shadow1', 'nesne'),
    'tas_1': ('sep:Stone1_grass_shadow7', 'nesne'), 'tas_2': ('sep:Stone1_grass_shadow6', 'nesne'), 'tas_3': ('sep:Stone1_grass_shadow5', 'nesne'),
    'tas_4': ('sep:Stone1_grass_shadow3', 'nesne'), 'tas_5': ('sep:Stone1_grass_shadow4', 'nesne'), 'tas_6': ('sep:Stone1_grass_shadow2', 'nesne'),
    'tas_7': ('sep:Stone1_grass_shadow1', 'nesne'),
    'dev_mantar_1': ('sep:Musgroom1_1', 'nesne'), 'dev_mantar_2': ('sep:Musgroom1_2', 'nesne'), 'dev_mantar_3': ('sep:Musgroom1_3', 'nesne'), 'dev_mantar_4': ('sep:Musgroom1_4', 'nesne'),
    'ak_mantar_1': ('sep:Mushroom2_2', 'nesne'), 'ak_mantar_2': ('sep:Mushroom2_3', 'nesne'), 'ak_mantar_3': ('sep:Mushroom2_1', 'nesne'), 'ak_mantar_4': ('sep:Mushroom2_4', 'nesne'),
    'ibrik_bitki_1': ('sep:Mushroom3_1', 'nesne'), 'ibrik_bitki_2': ('sep:Mushroom3_2', 'nesne'), 'ibrik_bitki_3': ('sep:Mushroom3_3', 'nesne'), 'ibrik_bitki_4': ('sep:Mushroom3_4', 'bitki'),
    'kafatasi_totem_1': ('sep:Totem_1', 'nesne'), 'kafatasi_totem_2': ('sep:Totem_2', 'nesne'),
    'kirik_agac_4': ('sep:Broken_tree4', 'yassi'), 'kirik_agac_3': ('sep:Broken_tree3', 'yassi'), 'kirik_agac_5': ('sep:Broken_tree5', 'yassi'),
    'kutuk_1': ('sep:Broken_tree1', 'nesne'), 'kutuk_6': ('sep:Broken_tree6', 'nesne'), 'kutuk_7': ('sep:Broken_tree7', 'nesne'), 'kutuk_2': ('sep:Broken_tree2', 'yassi'),
    'kazik_1': ('sep:Stick1', 'nesne'), 'kazik_4': ('sep:Stick4', 'bitki'), 'kazik_5': ('sep:Stick5', 'bitki'), 'kazik_2': ('sep:Stick2', 'bitki'), 'kazik_3': ('sep:Stick3', 'bitki'),
    'kafa_kazik_1': ('sep:Stick_skulls1', 'nesne'), 'kafa_kazik_2': ('sep:Stick_skulls2', 'nesne'),
    ## ikinci paket (Bataklık parçaları)
    'dev_iskelet': ('p2:Bones_full', 'nesne'), 'kemik_1': ('p2:Bones1', 'yassi'), 'kemik_2': ('p2:Bones2', 'yassi'), 'kemik_3': ('p2:Bones3', 'yassi'),
    'kazan_1': ('p2:Cauldron_element1', 'nesne'), 'kazan_2': ('p2:Cauldron_element2', 'nesne'), 'kazan_3': ('p2:Cauldron_element3', 'nesne'),
    'mantar_evi': ('p2:House-mushroom', 'nesne'), 'cadir': ('p2:House_teepee', 'nesne'), 'agac_ev': ('p2:House_tree', 'nesne'),
    'yosun_mercan_1': ('p2:Moss-coral1', 'nesne'), 'yosun_mercan_2': ('p2:Moss-coral2', 'bitki'),
    'kara_mantar_1': ('p2:Mushroom_black1', 'nesne'), 'kara_mantar_2': ('p2:Mushroom_black2', 'nesne'), 'kara_mantar_3': ('p2:Mushroom_black3', 'bitki'),
    'gri_mantar_1': ('p2:Mushroom_gray1', 'bitki'), 'gri_mantar_2': ('p2:Mushroom_gray2', 'bitki'),
    'kizil_mantar_1': ('p2:Mushroom_red1', 'nesne'), 'kizil_mantar_2': ('p2:Mushroom_red2', 'bitki'), 'kizil_mantar_3': ('p2:Mushroom_red3', 'bitki'),
    'yirtici_bitki_1': ('p2:Predator_plant1', 'nesne'), 'yirtici_bitki_2': ('p2:Predator_plant2', 'bitki'), 'yirtici_bitki_3': ('p2:Predator_plant2-1', 'bitki'),
    'kafa_agaci_1': ('p2:Sculls_tree1', 'yassi'),
    'heykel_mizrak': ('p2:Statue1', 'nesne'), 'heykel_bilge': ('p2:Statue2', 'nesne'), 'heykel_el': ('p2:Statue3', 'nesne'),
    'cadi_totem_1': ('p2:Witch_totem1', 'nesne'), 'cadi_totem_2': ('p2:Witch_totem2', 'nesne'), 'cadi_totem_3': ('p2:Witch_totem3', 'nesne'),
    'egrelti_1': ('p2:Fern1', 'bitki'), 'egrelti_2': ('p2:Fern2', 'bitki'),
    ## bitkiler (sallanan ot)
    'sazlik_1': ('sep:Reeds1', 'bitki'), 'sazlik_2': ('sep:Reeds2', 'bitki'), 'sazlik_3': ('sep:Reeds3', 'bitki'), 'sazlik_4': ('sep:Reeds4', 'bitki'),
    'sazlik_5': ('sep:Reeds5', 'bitki'), 'sazlik_6': ('sep:Reeds6', 'bitki'), 'sazlik_7': ('sep:Reeds7', 'bitki'), 'sazlik_8': ('sep:Reeds8', 'bitki'),
    'ot_1': ('sep:Grass_elements1', 'bitki'), 'ot_2': ('sep:Grass_elements2', 'bitki'), 'ot_3': ('sep:Grass_elements3', 'bitki'), 'ot_4': ('sep:Grass_elements4', 'bitki'),
    'ot_5': ('sep:Grass_elements5', 'bitki'), 'ot_6': ('sep:Grass_elements6', 'bitki'), 'ot_7': ('sep:Grass_elements7', 'bitki'),
    'parlak_ot_1': ('sep:Bright_grass_elements1', 'bitki'), 'parlak_ot_2': ('sep:Bright_grass_elements2', 'bitki'), 'parlak_ot_3': ('sep:Bright_grass_elements3', 'bitki'),
    'falez_1': ('sep:Fern1_1', 'bitki'), 'falez_2': ('sep:Fern1_2', 'bitki'), 'falez_3': ('sep:Fern1_3', 'bitki'),
    'falez_4': ('sep:Fern2_1', 'bitki'), 'falez_5': ('sep:Fern2_2', 'bitki'), 'falez_6': ('sep:Fern2_2-1', 'bitki'),
    'cicekli_egrelti_1': ('sep:Fren_flower1', 'bitki'), 'cicekli_egrelti_2': ('sep:Fren_flower3', 'bitki'), 'cicekli_egrelti_3': ('sep:Fren_flower2', 'cicek'),
    'pembe_cicek_1': ('sep:Grass_pink_flowers1', 'cicek'), 'pembe_cicek_2': ('sep:Grass_pink_flowers2', 'cicek'),
    'ak_cicek_1': ('sep:Grass_white_flowers1', 'cicek'), 'ak_cicek_2': ('sep:Grass_white_flowers2', 'cicek'),
    'ak_cicek_3': ('sep:Grass_white_flowers3', 'cicek'), 'ak_cicek_4': ('sep:Grass_white_flowers4', 'cicek'),
    ## animasyonlu
    'cadi_kulubesi': ('seq:Witch_house_grass_shadow%d', 'anim'),
    'mesale': ('seq:torch%d', 'anim'), 'kucuk_mesale': ('seq:torch_small%d', 'anim'),
    'yuzlu_agac': ('anim:0,0,8,7', 'anim'),
}


def zread(z, name):
    return Image.open(io.BytesIO(z.read(name))).convert('RGBA')


def anim_table(z, src):
    """kaynak tsx (ya da tmx#tileset) -> {taban yerel id: [kare yerel id...]}"""
    if '#' in src:
        path, name = src.split('#')
        root = ET.fromstring(z.read(path))
        node = [t for t in root.findall('tileset') if t.get('name') == name][0]
    else:
        node = ET.fromstring(z.read(src))
    out = {}
    for t in node.findall('tile'):
        a = t.find('animation')
        if a is not None:
            out[int(t.get('id'))] = [int(f.get('tileid')) for f in a.findall('frame')]
    return out


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


def canonical_anims(name, anims):
    """Kaynaktaki tek tük yazım hatalarını düzeltir: her karonun kare farkları listesi en sık görülen listeye eşit değilse en sık olan
    kullanılır (water_detilazation_v2'de 137 -> ... 2060 (2061 olmalı) gibi bir kayık kare var; Tiled'da o an komşu karo görünüyordu)."""
    from collections import Counter
    offs = Counter(tuple(f - tid for f in fr) for tid, fr in anims.items())
    canon = list(offs.most_common(1)[0][0])
    fixed = 0
    out = {}
    for tid, fr in anims.items():
        want = [tid + o for o in canon]
        if fr != want and len(fr) == len(want):
            fixed += 1
            fr = want
        out[tid] = fr
    if fixed:
        print('  %s: %d animasyonun kayık karesi düzeltildi' % (name, fixed))
    return out


def build_sheets(z):
    info = {}
    for name, fname, src, anim_src in SHEETS:
        img = zread(z, src)
        img.save(os.path.join(OUT, fname))
        anims = canonical_anims(name, anim_table(z, anim_src)) if anim_src else {}
        cols = img.width // T
        ## aralık düzenli mi (Godot): her animasyonda ardışık kare farkı sabit olmalı
        for tid, fr in anims.items():
            d = [fr[i + 1] - fr[i] for i in range(len(fr) - 1)]
            assert len(set(d)) == 1, (name, tid, fr)
        write_tsx(os.path.join(OUT, name + '.tsx'), name, fname, img.width, img.height, anims)
        info[name] = {'file': fname, 'cols': cols, 'w': img.width, 'h': img.height, 'anims': len(anims)}
    ## kıyı: yeniden dizilim
    src_img = zread(z, KIYI_SRC[0])
    src_anims = anim_table(z, KIYI_SRC[1])
    cols = src_img.width // T
    nfr = max(len(v) for v in src_anims.values())
    dst = Image.new('RGBA', (src_img.width, KIYI_BAND * nfr * T), (0, 0, 0, 0))
    ## statik karolar (ilk bant) aynen
    dst.paste(src_img.crop((0, 0, src_img.width, KIYI_BAND * T)), (0, 0))
    anims = {}
    for tid, fr in src_anims.items():
        bc, br = tid % cols, tid // cols
        assert br < KIYI_BAND, tid
        out = []
        for k, f in enumerate(fr):
            fc, frr = f % cols, f // cols
            tile = src_img.crop((fc * T, frr * T, fc * T + T, frr * T + T))
            dr = br + KIYI_BAND * k
            dst.paste(tile, (bc * T, dr * T))
            out.append(dr * cols + bc)
        anims[tid] = out
    dst.save(os.path.join(OUT, 'b_kiyi.png'))
    write_tsx(os.path.join(OUT, 'Bataklık kıyı.tsx'), 'Bataklık kıyı', 'b_kiyi.png', dst.width, dst.height, anims)
    info['Bataklık kıyı'] = {'file': 'b_kiyi.png', 'cols': cols, 'w': dst.width, 'h': dst.height, 'anims': len(anims)}
    return info


def load_object(z, src):
    """-> kare listesi (RGBA, hepsi aynı boy, ortak opak sınıra kırpılmış)"""
    kind, ref = src.split(':', 1)
    if kind == 'sep':
        frames = [zread(z, 'PNG/Objects_separated/%s.png' % ref)]
    elif kind == 'p2':
        frames = [Image.open(os.path.join(PACK2, ref + '.png')).convert('RGBA')]
    elif kind == 'seq':
        frames = [zread(z, 'PNG/Objects_separated/%s.png' % (ref % i)) for i in range(1, 7)]
    elif kind == 'anim':
        x, y, w, h = [int(v) for v in ref.split(',')]
        sheet = zread(z, 'Tiled_files/sprites_animated.png')
        frames = [sheet.crop((x * T, (y + 23 * k) * T, (x + w) * T, (y + h + 23 * k) * T)) for k in range(6)]
    else:
        raise ValueError(src)
    ## ortak sınır
    bb = None
    for f in frames:
        b = f.getbbox()
        if b is None:
            continue
        bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]), max(bb[2], b[2]), max(bb[3], b[3]))
    return [f.crop(bb) for f in frames]


def build_objects(z):
    items = []
    for key, (src, kind) in OBJECTS.items():
        frames = load_object(z, src)
        w, h = frames[0].size
        wt, ht = (w + T - 1) // T, (h + T - 1) // T
        items.append({'key': key, 'kind': kind, 'frames': frames, 'w': w, 'h': h, 'wt': wt, 'ht': ht})
    ## raf yerleşimi: büyükten küçüğe boy, satır genişliği COLS karo, aralarda 1 boş karo
    COLS = 64
    items.sort(key=lambda it: (-(it['ht'] * len(it['frames']) + len(it['frames']) - 1), -it['wt'], it['key']))
    x = y = 0
    shelf_h = 0
    for it in items:
        nf = len(it['frames'])
        bh = it['ht'] * nf + (nf - 1)  ## kareler alt alta, aralarında 1 boş satır
        if x + it['wt'] > COLS:
            x = 0
            y += shelf_h + 1
            shelf_h = 0
        it['ax'], it['ay'] = x, y
        x += it['wt'] + 1
        shelf_h = max(shelf_h, bh)
    rows = y + shelf_h
    atlas = Image.new('RGBA', (COLS * T, rows * T), (0, 0, 0, 0))
    anims = {}
    catalog = {}
    for it in items:
        wt, ht = it['wt'], it['ht']
        ox = (wt * T - it['w']) // 2  ## yatayda ortalı
        oy = ht * T - it['h']  ## alta oturur
        for k, f in enumerate(it['frames']):
            atlas.alpha_composite(f, ((it['ax']) * T + ox, (it['ay'] + k * (ht + 1)) * T + oy))
        if len(it['frames']) > 1:
            for ty in range(ht):
                for tx in range(wt):
                    base = (it['ay'] + ty) * COLS + it['ax'] + tx
                    anims[base] = [(it['ay'] + ty + k * (ht + 1)) * COLS + it['ax'] + tx for k in range(len(it['frames']))]
        ## opak sınır (blok içi piksel) + alt bantta opak piksel sütun aralığı (gövde/ayak)
        f0 = it['frames'][0]
        catalog[it['key']] = {'kind': it['kind'], 'ax': it['ax'], 'ay': it['ay'], 'wt': wt, 'ht': ht, 'frames': len(it['frames']),
                              'ox': ox, 'oy': oy, 'w': it['w'], 'h': it['h']}
    atlas.save(os.path.join(OUT, 'b_nesne.png'))
    write_tsx(os.path.join(OUT, 'Bataklık nesne.tsx'), 'Bataklık nesne', 'b_nesne.png', atlas.width, atlas.height, anims)
    return catalog, {'file': 'b_nesne.png', 'cols': COLS, 'w': atlas.width, 'h': atlas.height, 'anims': len(anims)}


## Saklanma çalılığı (harita/saklanma_calilik.png, 16 maske x 8 çeşit; eğrelti yatağı satır 4-7) bataklık paletine boyanır: ana haritanın
## serin yeşili bataklığın zeytin çimeninde koyu bir kare gibi duruyordu. Her renk parlaklık SIRASIYLA bataklık çimen rampasına eşlenir
## (en koyu -> en koyu): desen/gölge aynı, yalnız ton. Düzen aynı -> hide_brush / depth_occluders / hide_brush_visual değişmeden çalışır.
SWAMP_RAMP = [(30, 38, 24), (44, 56, 33), (62, 80, 44), (77, 104, 54), (91, 115, 56), (106, 128, 62), (120, 142, 69), (133, 152, 70),
              (144, 163, 71), (160, 173, 76), (174, 183, 80)]


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
        ## açık uçta rampanın üstüne çıkmasın: çalılık çimen zeminden bir ton koyu kalsın (içine girilen gölgelik)
        i = min(len(SWAMP_RAMP) - 1, 1 + int(round(t * (len(SWAMP_RAMP) - 2))))
        m[c] = SWAMP_RAMP[i]
    out = Image.new('RGBA', src.size)
    op = out.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            op[x, y] = m[(r, g, b)] + (a,) if a > 0 else (0, 0, 0, 0)
    out.save(os.path.join(OUT, 'b_calilik.png'))
    write_tsx(os.path.join(OUT, 'Bataklık çalılık.tsx'), 'Bataklık çalılık', 'b_calilik.png', out.width, out.height, {})
    return {'file': 'b_calilik.png', 'cols': out.width // T, 'w': out.width, 'h': out.height, 'anims': 0}


def main():
    if not os.path.exists(ZIP):
        print('Kaynak zip yok:', ZIP)
        sys.exit(1)
    os.makedirs(OUT, exist_ok=True)
    with zipfile.ZipFile(ZIP) as z:
        sheets = build_sheets(z)
        catalog, ninfo = build_objects(z)
    sheets['Bataklık nesne'] = ninfo
    sheets['Bataklık çalılık'] = build_brush()
    with open(JSON_OUT, 'w', encoding='utf-8') as f:
        json.dump({'sheets': sheets, 'objects': catalog}, f, ensure_ascii=False, indent=1, sort_keys=True)
    for k, v in sheets.items():
        print('%-20s %s %dx%d anim=%d' % (k, v['file'], v['w'], v['h'], v['anims']))
    print('nesne:', len(catalog))


if __name__ == '__main__':
    main()
