# TEMA HARİTALARI (madde 445): her zindan setinin KENDİ haritası (Kadim Derinlikler'deki üç setin karışımı beğenilmedi). Ana haritanın alanının
# %70'i (214x214 hücre), tek tema: Kemik Katakombu (Zindan Tileseti Roguelike - örnek Dungeon3.tmx), Kızıl Lağım (Kanalizasyon + Hapishane +
# Lanetli Toprak - örnek Inside.tmx), Boynuz Mağaraları (Piksel Zindan + Parlayan Mağara + Mağara - örnek Dungeon1.tmx / Cave.tmx).
# Altyapı gen_kadim_derinlikler.py'den (yerleşim, kaçış kuralı, 1 satırlık basamak düzeltmesi, köşe kuralı `tuck`, harita kipi nesneleri):
# burada yalnız yapılandırma (salonlar / yollar / kümeler) + temaya özgü salon süslemeleri.
#   - İskelet HER HARİTADA FARKLI (cfg_*): Kemik simetrik bazilika, Et yatay lağım hatları, Boynuz asimetrik mağara ağı; aralarda temanın
#     kendi oda türlerinden kümeler (5 hücrelik koridorlar). İlk salon = doğuş. Etkileşimler temanın zindanınınkiler (kapı stili, tuzak, kaynak, sunak/NPC, avcı).
#   - Örneklerden: Roguelike = taş levhalı yükseltilmiş zeminler, kemerli/sütunlu yüzler, ruh alevli heykel kürsüsü, lahit sıraları;
#     Kanalizasyon = kanallar + tahta köprüler, lağım kemerleri, hücre koğuşu, simya masaları; Piksel Zindan + Mağara = kapılı yüzler,
#     mangallar, kristal / dikit / lav kayası / mantar mağaraları, boynuzlu kafatası.
# Çalıştır: python tools/zindan/gen_tema_haritalari.py kemik|et|boynuz|hepsi [--write]
#   --write: harita/zindan/<id>.tmx + paket klasörü -> Godot --import -> -s res://tools/zindan/bake_zindan.gd -- <id>
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zindan_core as Z  # noqa: E402
import zindan_paint as P  # noqa: E402
import gen_kadim_derinlikler as G  # noqa: E402

KM, EK, BK = G.KM, G.EK, G.BK
SIZE = 214
RW = G.RW

TEMALAR = {
    'kemik': {'id': 'kemik_katakombu', 'ad': 'Kemik Katakombu', 'seed': 5101},
    'et': {'id': 'kizil_lagim', 'ad': 'Kızıl Lağım', 'seed': 5203},
    'boynuz': {'id': 'boynuz_magaralari', 'ad': 'Boynuz Mağaraları', 'seed': 5307},
}

# ---- her haritanın KENDİ iskeleti (madde 445 ek: "yerleşimler de farklı olsun"). Yol = (x, y, w, h); salon kenarlarına değer.
ODA = ((8, 11), (6, 8))


def kumeler(spec):
    """spec: [(ad, (x0, y0, x1, y1), [(adet, (wmin,wmax), (hmin,hmax), tür)])] - bölge yalnız yerleşim sınırı (yol payı + oda payı ayrıca)."""
    return [(None, ad, reg, v) for (ad, reg, v) in spec]


def cfg_kemik():
    """KEMİK KATAKOMBU - simetrik BAZİLİKA (Roguelike örneği Dungeon3: kürsülü heykel-sunak, kemerli/sütunlu yüzler): kuzeyde Ruh Sunağı,
    ortada doğuş avlusu, batı/doğu kanatta lahit ve ölüler salonları, güneyde kemik ocağı; artı biçimli ana eksen + köşelerden dolanan revak."""
    halls = [('Bekçi Avlusu', (82, 88, 50, 40), {}), ('Ruh Sunağı', (77, 8, 60, 36), {}), ('Lahit Galerisi', (6, 92, 58, 32), {}),
             ('Ölüler Salonu', (150, 92, 58, 32), {}), ('Kemik Ocağı', (77, 170, 60, 36), {})]
    roads = [(103, 44, RW, 44), (103, 128, RW, 42), (64, 104, 18, RW), (132, 104, 18, RW),          # artı eksen
             (32, 22, 45, RW), (32, 30, RW, 62), (137, 22, 45, RW), (174, 30, RW, 62),              # kuzey revak
             (32, 124, RW, 62), (32, 182, 45, RW), (174, 124, RW, 62), (137, 182, 45, RW)]          # güney revak
    d = kumeler([
        ('Kuzeybatı Lahitleri', (44, 34, 100, 90), [(1, (17, 21), (10, 12), 'lahit'), (1, (12, 15), (8, 10), 'kemik'), (3,) + ODA + ('oda',)]),
        ('Kuzeydoğu Mahzeni', (114, 34, 170, 90), [(1, (26, 28), (14, 16), 'kalp'), (2,) + ODA + ('oda',)]),
        ('Güneybatı Kemiklik', (44, 130, 100, 178), [(1, (17, 21), (10, 12), 'lahit'), (3,) + ODA + ('oda',)]),
        ('Güneydoğu Sütunları', (114, 130, 170, 178), [(1, (16, 19), (10, 11), 'sutun'), (1, (12, 15), (8, 10), 'kemik'), (2,) + ODA + ('oda',)]),
        ('Batı Nişleri', (4, 4, 28, 88), [(3,) + ODA + ('oda',)]),
        ('Doğu Nişleri', (186, 4, 210, 88), [(3,) + ODA + ('oda',)]),
        ('Güney Nişleri', (4, 130, 28, 210), [(1, (12, 15), (8, 10), 'kemik'), (2,) + ODA + ('oda',)]),
        ('Güneydoğu Nişleri', (186, 130, 210, 210), [(1, (16, 19), (10, 11), 'sutun'), (2,) + ODA + ('oda',)]),
    ])
    return halls, roads, d, (40, 30, 104, 92)


def cfg_et():
    """KIZIL LAĞIM - YATAY LAĞIM HATLARI (Kanalizasyon örneği Inside: kanallar + köprüler, lağım kemerleri): üstte haritayı boydan boya geçen
    ana lağım tüneli, ortada simya - kan havzası - et bahçesi dizisi, altta neredeyse harita genişliğinde köprülü dev Taşkın Kanalı."""
    halls = [('Kan Havzası', (70, 80, 74, 46), {'kanal': True}), ('Hücre Koğuşu', (77, 6, 60, 30), {}), ('Simya Salonu', (8, 90, 50, 34), {}),
             ('Et Bahçesi', (156, 90, 50, 34), {}), ('Taşkın Kanalı', (20, 168, 174, 38), {'kanal': True})]
    roads = [(12, 50, 190, RW),                                   # ana lağım tüneli
             (103, 36, RW, 14), (103, 58, RW, 22),                # hücre koğuşu - tünel - havza
             (28, 58, RW, 32), (178, 58, RW, 32),                 # tünel -> simya / bahçe
             (58, 103, 12, RW), (144, 103, 12, RW),               # orta dizi
             (28, 124, RW, 44), (178, 124, RW, 44), (103, 126, RW, 42)]   # orta dizi -> taşkın kanalı
    d = kumeler([
        ('Kuzeybatı Hücreleri', (4, 4, 72, 44), [(1, (17, 20), (10, 12), 'hucre'), (2,) + ODA + ('oda',)]),
        ('Kuzeydoğu Laboratuvarı', (142, 4, 210, 44), [(1, (26, 28), (14, 16), 'kalp')]),
        ('Batı Kanalları', (38, 62, 66, 86), [(1,) + ODA + ('oda',)]),
        ('Doğu Kanalları', (148, 62, 176, 86), [(1,) + ODA + ('oda',)]),
        ('Güneybatı Kuyuları', (36, 130, 100, 164), [(1, (19, 23), (12, 14), 'kanal'), (2,) + ODA + ('oda',)]),
        ('Güneydoğu Kuyuları', (112, 130, 176, 164), [(1, (17, 20), (10, 12), 'hucre'), (1, (14, 17), (10, 12), 'bahce'), (1,) + ODA + ('oda',)]),
        ('Batı Lağımları', (4, 62, 24, 164), [(2,) + ODA + ('oda',)]),
        ('Doğu Lağımları', (188, 62, 210, 164), [(1, (14, 17), (10, 12), 'bahce'), (1,) + ODA + ('oda',)]),
    ])
    return halls, roads, d, (4, 4, 76, 60)


def cfg_boynuz():
    """BOYNUZ MAĞARALARI - ASİMETRİK MAĞARA AĞI (Piksel Zindan Dungeon1 + Mağara Cave + Parlayan Mağara): farklı boyutlarda dağınık mağaralar,
    sol üstte tapınak, sağ üstte dev kristal mağarası, uzun lav yarığı; kıvrımlı L yollarla tek halka, odalar ortadaki boşlukta."""
    halls = [('Boynuz Tapınağı', (20, 18, 66, 42), {}), ('Kristal Mağarası', (120, 10, 86, 52), {'magara': True}),
             ('Lav Yarığı', (130, 100, 50, 62), {'magara': True}), ('Mantar Korusu', (10, 120, 72, 50), {'magara': True}),
             ('Mühür Salonu', (90, 168, 60, 38), {})]
    roads = [(86, 30, 34, RW),                     # tapınak -> kristal
             (150, 62, RW, 38),                    # kristal -> lav
             (40, 60, RW, 60),                     # tapınak -> mantar
             (82, 150, 30, RW), (104, 158, RW, 10),          # mantar -> mühür (L)
             (160, 162, RW, 28), (150, 182, 18, RW),         # lav -> mühür (L)
             (48, 84, 82, RW)]                     # orta geçit: mantar yolundan lav yarığına
    d = kumeler([
        ('Orta Yarıklar', (52, 64, 126, 146), [(1, (26, 30), (14, 16), 'kalp'), (1, (20, 24), (13, 15), 'magara'), (1, (18, 21), (12, 13), 'kristal'),
                                               (2,) + ODA + ('oda',)]),
        ('Batı Çatlakları', (4, 62, 36, 116), [(2,) + ODA + ('oda',)]),
        ('Doğu Mağaraları', (184, 66, 210, 190), [(1, (18, 21), (12, 13), 'kristal'), (1, (18, 21), (10, 12), 'salon'), (1,) + ODA + ('oda',)]),
        ('Güneybatı Odaları', (4, 174, 86, 210), [(1, (18, 21), (10, 12), 'salon'), (2,) + ODA + ('oda',)]),
        ('Kuzey Kovukları', (88, 40, 118, 60), [(1,) + ODA + ('oda',)]),
    ])
    return halls, roads, d, (48, 60, 128, 120)


CFG = {'kemik': cfg_kemik, 'et': cfg_et, 'boynuz': cfg_boynuz}


# ================================================================================================ temaya özgü salon süslemeleri
def deco_kemik_ocagi(dz, r):
    """Kemik ocağı (ossuary): kemik yığınları, küpler, kafatası duvarları, mumlar."""
    G.hall_slab_rugs(dz, r)
    dz.wall_hangings(r, KM.HANGING, step=3)
    dz.wall_torches(r, KM.TORCH_WALL, step=7, light=P.CYAN)
    dz.wall_reliefs(r, KM.RELIEF, step=8)
    dz.edge_props(r, KM.URNS + KM.BONE_PILES, 's', step=3, n_max=10)
    for side in ('w', 'e'):
        dz.edge_props(r, KM.NARROW, side, step=3, n_max=4)
    dz.scatter(r, KM.BONE_PILES, 16, solid=True)
    dz.scatter(r, KM.URNS, 10, solid=True)
    dz.scatter(r, KM.WOOD_V + KM.WOOD_H, 4, solid=True)
    dz.scatter(r, KM.CANDLES_FLOOR, 9, light=P.CYAN)
    dz.scatter(r, KM.BONES + KM.SKULLS, 45)
    dz.corner_candles(r, KM.CANDLES_FLOOR, light=P.CYAN)
    dz.corner_webs(r)
    dz.resource_nodes(r, 'ruh_kandili', 2)
    dz.chest(r)
    dz.hide_alcove(r)
    G.quad_dwellers(dz, r, 'kemik', 2, 1)


def deco_oluler(dz, r):
    """Ölüler salonu: kuzey duvarında heykel sırası, ortada büyük lahitler (sıra), kemerli yüz, mumlar."""
    dz.edge_props(r, KM.STATUES, 'n', step=5, n_max=8)
    dz.wall_row(r, KM.ARCH_FACE, step=6, layer='Duvar süsü', face=True)
    dz.wall_torches(r, KM.TORCH_WALL, step=7, light=P.CYAN)
    mid = G.sub_room(r, r.x, r.y + 6, r.w, r.h - 8)
    dz.tomb_rows(mid, KM.TOMBS_V + KM.TOMB_BIG_H, KM.OPEN_EMPTY_V, margin_top=1, hide_every=3)
    for side in ('w', 'e'):
        dz.edge_props(r, KM.NARROW, side, step=3, n_max=4)
    dz.scatter(r, KM.BONES + KM.SKULLS, 14)
    dz.corner_candles(r, KM.CANDLES_FLOOR, light=P.CYAN)
    dz.corner_webs(r)
    dz.resource_nodes(r, 'ruh_kandili', 1)
    dz.chest(r)
    G.quad_dwellers(dz, r, 'lahit', 2, 1)


def deco_avlu(dz, r):
    """Bekçi avlusu: levha zemin + sütun dizisi, banklar, tahta tabutlar, heykel çifti, altın."""
    ix0, iy0, iw, ih = r.x + 8, r.y + 6, r.w - 16, r.h - 12
    P.nine_slice(dz.tl, dz.bank, 'Zemin ayrıntı', 'wf', KM.SLAB9, ix0, iy0, iw, ih)
    P.nine_slice(dz.tl, dz.bank, 'Zemin desen', 'pl', KM.PLATE9, ix0 + 1, iy0 + 1, iw - 2, ih - 2)
    G.colonnade(dz, ('wf', (15, 1, 1, 4)), ix0, iy0, iw, ih, step=6)
    dz.statue_pair(r, KM.STATUES[2])
    dz.wall_torches(r, KM.TORCH_WALL, step=8, light=P.CYAN)
    dz.wall_row(r, KM.ARCH_FACE, step=9, layer='Duvar süsü', face=True)
    dz.edge_props(r, KM.WOOD_H + KM.URNS, 's', step=4, n_max=8)
    dz.scatter(r, KM.BENCH, 4, solid=True)
    dz.scatter(r, KM.WOOD_V, 3, solid=True)
    dz.scatter(r, KM.GOLD, 4)
    dz.scatter(r, KM.BONES, 10)
    dz.corner_candles(r, KM.CANDLES_FLOOR, light=P.CYAN)
    dz.resource_nodes(r, 'ruh_kandili', 1)
    dz.chest(r)
    dz.hide_alcove(r)
    G.quad_dwellers(dz, r, 'sutun', 2, 1)


def deco_hucre_kogusu(dz, r):
    """Hücre koğuşu (Hapishane): kuzey yüzünde hücre kapıları / pencereleri, zincirler, saman, ranzalar; açık hücre = saklanma."""
    dz.wall_row(r, [EK.CELL_DOOR, EK.CELL_WINDOW], step=3, layer='Duvar süsü', face=True)
    dz.wall_hangings(r, EK.CHAINED, step=5)
    dz.hide_alcove(r, spec=('hd', (8, 0, 2, 3)))
    dz.hide_alcove(r, spec=('hd', (8, 0, 2, 3)))
    dz.wall_fires(r, EK.FIRES, step=8, light=P.AMBER)
    dz.scatter(r, EK.HAY, 10)
    dz.scatter(r, EK.BEDS + [EK.BUNK], 9, solid=True)
    dz.scatter(r, EK.CRATES + EK.BARRELS, 6, solid=True)
    dz.scatter(r, EK.BONES_LT, 4)
    dz.edge_props(r, EK.BARRELS + EK.BOXES[:3], 's', step=3, n_max=8)
    dz.scatter(r, EK.MUSHROOMS, 6)
    dz.corner_webs(r, key='kw')
    dz.resource_nodes(r, 'et_kesesi', 1)
    dz.chest(r)
    G.quad_dwellers(dz, r, 'hucre', 2, 1)


def deco_simya(dz, r):
    """Simya salonu: duvar dibinde raflar, ortada masalar, canavarlı şişeler (kırmızı ışık), kavanozlar, kök keseleri."""
    dz.wall_row(r, EK.ALCH_SHELVES, step=3, layer='Eşya', solid=True)
    dz.wall_fires(r, EK.FIRES, step=7, light=P.AMBER)
    dz.scatter(r, EK.ALCH_TABLES, 10, solid=True)
    dz.scatter(r, EK.FLASKS, 12, solid=True, light=P.RED)
    dz.scatter(r, EK.JARS, 8, solid=True)
    dz.scatter(r, EK.CRATES + EK.BOXES, 5, solid=True)
    dz.scatter(r, EK.DESK, 2, solid=True)
    dz.scatter(r, EK.ROOT_PODS[1:], 2, solid=True)
    dz.edge_props(r, EK.BARRELS + EK.BOXES[:3], 's', step=3, n_max=8)
    dz.scatter(r, EK.MUSHROOMS, 5)
    dz.corner_webs(r, key='kw')
    dz.resource_nodes(r, 'et_kesesi', 2)
    dz.chest(r)
    G.quad_dwellers(dz, r, 'lab', 2, 1)


def deco_et_bahce(dz, r):
    """Et bahçesi (Lanetli Toprak): et bitkileri, göz keseleri, dev göz, ağız, kök damarları."""
    G.statue_at(dz, EK.BIG_EYE, r.x + r.w // 2 - 4, r.y + 2, light=P.RED, light_r=130)
    G.statue_at(dz, EK.MAW, r.x + 4, r.y + r.h - 8, light=P.RED, light_r=90)
    dz.wall_row(r, EK.ARCH2, step=8, layer='Duvar süsü', face=True)
    dz.wall_fires(r, EK.FIRES, step=8, light=P.AMBER)
    dz.scatter(r, EK.FLESH_PLANTS, 12, solid=True)
    dz.scatter(r, EK.FLESH_ROCK, 7, solid=True)
    dz.scatter(r, EK.EYE_PODS, 7, solid=True, light=P.RED)
    dz.scatter(r, EK.ROOT_VEIN, 3)
    dz.scatter(r, EK.BONES_LT, 6)
    dz.scatter(r, EK.MUSHROOMS, 6)
    dz.hide_spot_object(r, EK.ROOT_PODS[0], 'Et Kökü')
    dz.resource_nodes(r, 'et_kesesi', 2)
    dz.chest(r)
    G.quad_dwellers(dz, r, 'bahce', 2, 1)


def deco_lav(dz, r):
    """Lav yarığı (Mağara örneği): lav kayaları (turuncu ışık), boynuzlu kafatası, dikitler, kristaller, dev örümcek."""
    G.statue_at(dz, BK.HORN_SKULL[0], r.x + r.w // 2 - 2, r.y + 2, light=(1.0, 0.55, 0.25), light_r=140)
    dz.wall_row(r, BK.HANGING, step=3, layer='Duvar süsü', face=True)
    dz.blob_scatter(r, BK.LAVA_ROCKS, 10, solid=True, light=(1.0, 0.55, 0.25))
    dz.blob_scatter(r, BK.STALAG + BK.PILLARS, 10, solid=True, vision=True)
    dz.blob_scatter(r, BK.BLUE_CRYSTAL_BIG + BK.DARK_CRYSTAL, 6, solid=True, vision=True, light=P.CYAN)
    dz.blob_scatter(r, BK.SPIDER, 2, solid=True)
    dz.blob_scatter(r, BK.WEB + BK.MOSS, 6)
    dz.blob_scatter(r, BK.BLUE_SHARDS, 8)
    dz.edge_props(r, BK.STALAG + BK.BLUE_CRYSTAL, 'n', step=3, n_max=8)
    dz.blob_hide(r, BK.BLUE_CRYSTAL_BIG[1], 'Kristal Gölgesi')
    dz.resource_nodes(r, 'isik_kristali', 2)
    dz.chest(r)
    G.quad_dwellers(dz, r, 'magara', 2, 1)


def deco_mantar(dz, r):
    """Mantar korusu (Parlayan Mağara): ışıyan mantarlar / bitkiler, mantar evleri (saklanma), eğrelti, mercan, denizanası."""
    dz.wall_row(r, BK.HANGING, step=4, layer='Duvar süsü', face=True)
    dz.blob_scatter(r, BK.MUSHROOMS, 10, solid=True, light=(0.85, 0.6, 1.0))
    dz.blob_scatter(r, BK.GLOW_PLANTS, 8, solid=True, light=(0.6, 0.95, 0.8))
    dz.blob_scatter(r, BK.PM_CRYSTALS + BK.PINK_CRYSTALS, 6, solid=True, light=P.VIOLET)
    dz.blob_scatter(r, BK.FERNS + BK.CORAL + BK.JELLY, 18)
    dz.blob_scatter(r, BK.MOSS, 6)
    dz.blob_scatter(r, [('pms', (0, 0, 4, 4))], 10, layer='Zemin süsü')
    dz.blob_hide(r, BK.MUSH_HOUSE[1], 'Mantar Kovuğu')
    dz.blob_hide(r, BK.MUSH_HOUSE[0], 'Mantar Evi')
    dz.edge_props(r, BK.MUSHROOMS[2:], 's', step=3, n_max=8, light=(0.85, 0.6, 1.0))
    dz.resource_nodes(r, 'isik_kristali', 2)
    dz.chest(r)
    G.quad_dwellers(dz, r, 'magara', 2, 1)


def deco_muhur(dz, r):
    """Mühür salonu (Piksel Zindan örneği): koyu halı + sütunlar, mangallar, kemerli pencereler, boynuzlu kafatası çifti, fıçı/küp."""
    cx0, cy0, cw, ch = r.x + 7, r.y + 7, r.w - 14, r.h - 14
    P.nine_slice(dz.tl, dz.bank, 'Zemin ayrıntı', 'wf', BK.DARK9, cx0, cy0, cw, ch)
    G.colonnade(dz, ('wf', (15, 1, 1, 4)), cx0 - 2, cy0 - 2, cw + 4, ch + 4, step=6)
    dz.statue_pair(r, BK.HORN_SKULL[1])
    dz.wall_fires(r, BK.BRAZIER, step=6, light=P.AMBER)
    dz.wall_row(r, BK.WIN_FACE, step=6, layer='Duvar süsü', face=True)
    dz.edge_props(r, BK.BARRELS + BK.VASES + BK.CRATES[:2], 's', step=3, n_max=8)
    dz.scatter(r, BK.CRATES + BK.BARRELS, 4, solid=True)
    dz.scatter(r, BK.VASES, 3, solid=True)
    dz.scatter(r, BK.GOLD, 3)
    dz.corner_candles(r, BK.CANDLE, light=P.AMBER)
    dz.hide_alcove(r, spec=('wf', (1, 26, 2, 2)))
    dz.resource_nodes(r, 'isik_kristali', 1)
    dz.chest(r)
    G.quad_dwellers(dz, r, 'salon', 2, 1)


DECO = {'Ruh Sunağı': G.deco_buyuk_salon, 'Lahit Galerisi': G.deco_katedral, 'Kemik Ocağı': deco_kemik_ocagi,
        'Ölüler Salonu': deco_oluler, 'Bekçi Avlusu': deco_avlu,
        'Kan Havzası': G.deco_havza, 'Hücre Koğuşu': deco_hucre_kogusu, 'Simya Salonu': deco_simya, 'Taşkın Kanalı': G.deco_havza,
        'Et Bahçesi': deco_et_bahce,
        'Boynuz Tapınağı': G.deco_tapinak, 'Kristal Mağarası': G.deco_magara, 'Lav Yarığı': deco_lav, 'Mantar Korusu': deco_mantar,
        'Mühür Salonu': deco_muhur}


def configure(tema):
    t = TEMALAR[tema]
    halls, roads, districts, kume = CFG[tema]()
    G.W = G.H = SIZE
    G.THEMES = (tema,)
    G.ID, G.TITLE, G.SEED = t['id'], t['ad'], t['seed']
    G.TMX = os.path.join(Z.ZROOT, t['id'] + '.tmx')
    G.OUT_PREFIX = t['id']
    G.HALLS = [(name, tema, rect, flags) for (name, rect, flags) in halls]
    G.ROADS = [(rect, tema) for rect in roads]
    G.DISTRICTS = [(tema, ad, reg, specs) for (_, ad, reg, specs) in districts]
    cx0, cy0, cw, ch = halls[0][1]
    G.CROPS = (('merkez', (cx0 - 4, cy0 - 6, cx0 + cw + 4, cy0 + ch + 4)), ('kume', kume))
    G.HALL_DECO.update(DECO)


def main():
    write = '--write' in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    temalar = list(TEMALAR) if (not args or args[0] == 'hepsi') else args
    for tema in temalar:
        print('=====', tema, TEMALAR[tema]['ad'])
        configure(tema)
        G.main(write)


if __name__ == '__main__':
    main()
