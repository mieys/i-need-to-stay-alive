# DERİN ORMAN (madde 358/359) ortak çekirdek: Harita.tmx okuma (sonsuz harita, 16x16 chunk), bölge (havza) hesabı, atlas tanımı.
# Bölgeler: geçilmez hücreler = "Orman parçaları" (uçurum duvarı) + "Su" (köprü altı açık). Duvara en az R hücre uzak çekirdekler 4-komşu
# parçalara ayrılır (dar geçitler kopar), sonra serbest hücrelere geri büyütülür -> doğal "havzalar". Bölge = tohum hücresinin havzası + sınır kutusu.
import os
import re
import xml.etree.ElementTree as ET
from collections import deque

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
TMX = os.path.join(PROJECT, 'harita', 'Harita.tmx')
ART = os.path.normpath(os.path.join(PROJECT, '..', 'Harita içerikleri'))
N = 256
R = 4

## ad: (tohum hücresi, x aralığı, y aralığı). Maske kanalı sırası = tablo sırası (R kuzey, G batı, B doğu, A güney).
## Kuzey ve batı AYNI halka havzası (tepe arkası şeridi), x = 80'de ayrılır; doğu nehrin sağındaki ayrı havza (doğuş noktası dışarıda);
## güney (madde 361) evin güneyindeki uçurumun altından denize inen ova - sol alt madenlerle sağ alt düşman üssünün arası, daha az tehlikeli.
ZONES = {
    'kuzey': ((150, 15), (80, 256), (0, 51), 7),
    'bati': ((30, 30), (0, 80), (0, 140), 7),
    'dogu': ((235, 60), (203, 256), (15, 141), 7),
    'guney': ((140, 215), (89, 201), (184, 256), 6),
    ## madde 385: Kadim Kara Orman kuzeybatıya uzar - kuzeyle AYNI derinlik (y < 51) ve aynı dalgalı kenarlar (x = 80 / y = 51 kenar tohumları
    ## kuzeyinkiyle aynı -> dikişsiz); ayrı bölge olarak işlenir ki kuzeyin mevcut yerleşimi (Kemik Mahzeni dahil) birebir kalsın
    'kuzey_bati': ((30, 30), (0, 80), (0, 51), 7),
    ## madde 387 (kullanıcı: "sisli sazlığı sol tarafındaki çayırı komple dolduracak şekilde genişlet (toprak kısımlardan bahsetmiyorum)"):
    ## sazlığın batısındaki çayır = uçurumlarla çevrili AYRI havza (x 29..95, y 181..255) -> kutusuz, havzanın tamamı; toprak hücreleri hariç
    ## (GRASS_ONLY). Ayrı bölge: güneyin mevcut yerleşimi birebir kalır, maske kanalı güneyinki (MASK_PARTS).
    'guney_bati': ((60, 225), (0, 256), (0, 256), 0),
}
## Toprak hücreleri (Zemin Toprak'ta olup Zemin Çimen'de olmayan: yol, açıklık) bölgeye girmeyen bölgeler (madde 387). Zemin pişirmesinde bu
## bölgelerin çevresindeki toprak pikselleri de olduğu gibi kalır (keep_dirt_cells, zemin_karolari.Baker.overlay).
GRASS_ONLY = {'guney_bati'}
KEEP_DIRT_REACH = 8
OUTER_REACH = 40   ## dış çerçeve kalınlığı (32/20 hücre, madde 119) + pay
## madde 385 (kullanıcı: "ışıyan kayalıklar ve kızıl bataklığı sil"): Batı ve Doğu bölgesi KALDIRILDI - hücresi yok, maske kanalı boş kalır
## (kanal SIRASI aynı: shader'lar, ışıklar, duyurular ve zindan kapısı renkleri kanal numarasıyla çalışır). Zindan girişleri yerinde
## (place_derin_orman.py KEPT_GATES). Geri getirmek için buradan çıkar.
REMOVED = {'bati', 'dogu'}
## maske kanalı -> o kanalı dolduran bölgeler (varsayılan: kendisi)
MASK_PARTS = {'kuzey': ['kuzey', 'kuzey_bati'], 'guney': ['guney', 'guney_bati']}
## 4. alan: kutu kenarının açık arazide düz kesik görünmemesi için gürültüyle dalgalanma genliği (hücre). Dalga KENARIN DEĞERİNE bağlı
## (_jitter tohumu = kenar koordinatı): kuzeyin x0 = 80'i ile batının x1 = 80'i AYNI dalgayı çizer -> aralarında boşluk/çakışma kalmaz.
## Açık arazide kutu kenarının ötesi (aynı havza) maskede RAMP hücrelik yumuşak geçiş alır (gen_bolge_maskesi.py, madde 361 2. tur).
ZONE_ORDER = ['kuzey', 'bati', 'dogu', 'guney']

## Kullanıcının "Harita içerikleri"ne yüklediği craftpix arşivleri (madde 361): sayfalar AÇILMADAN zip'ten okunur ("zip:<arşiv>|<iç yol>").
ZIP_UNDEAD = 'craftpix-net-695666-free-undead-tileset-top-down-pixel-art.zip'
ZIP_CURSED = 'craftpix-net-958568-free-cursed-land-top-down-pixel-art-tileset.zip'
ZIP_CAVE = 'craftpix-net-688848-cave-tileset-top-down-pixel-art.zip'
ZIP_SWAMP = 'craftpix-net-624156-swamp-top-down-tileset-pixel-art.zip'
ZIP_ROCKY = 'craftpix-net-235765-rocky-top-down-tileset-pixel-art-for-rpg.zip'


def zsheet(archive, inner):
    return 'zip:%s|%s' % (archive, inner)


def open_sheet(spec):
    """Sayfa yolu ya da zsheet() -> RGBA PIL görüntüsü."""
    from PIL import Image
    if spec.startswith('zip:'):
        import io
        import zipfile
        archive, inner = spec[4:].split('|', 1)
        with zipfile.ZipFile(os.path.join(ART, archive)) as zf:
            return Image.open(io.BytesIO(zf.read(inner))).convert('RGBA')
    return Image.open(spec).convert('RGBA')

YO_ANIM = os.path.join(ART, 'Yari Olu Tileseti', 'Tiled_files', 'Objects_animated.png')
YO_OBJ = os.path.join(ART, 'Yari Olu Tileseti', 'Tiled_files', 'Objects.png')
PM_OBJ = os.path.join(ART, 'Parlayan Magara Tileseti', 'Tiled_files', 'Objects.png')
LT_OBJ = os.path.join(ART, 'Lanetli Toprak Tileseti', 'Tiled_files', 'Objects.png')
KY_OBJ = os.path.join(ART, 'Kayalik Tileset', 'Tiled_files', 'Objects.png')
UD_OBJ = 'zip:craftpix-net-695666-free-undead-tileset-top-down-pixel-art.zip|PNG/Objects.png'
UD_A5 = 'zip:craftpix-net-695666-free-undead-tileset-top-down-pixel-art.zip|PNG/Animation5.png'
CU_OBJ = 'zip:craftpix-net-958568-free-cursed-land-top-down-pixel-art-tileset.zip|PNG/Objects.png'
CU_GROUND = 'zip:craftpix-net-958568-free-cursed-land-top-down-pixel-art-tileset.zip|Tiled_files/Ground.png'
CV_OBJ = 'zip:craftpix-net-688848-cave-tileset-top-down-pixel-art.zip|PNG/Objects_source.png'
SW_OBJ = 'zip:craftpix-net-624156-swamp-top-down-tileset-pixel-art.zip|PNG/Objects.png'
SW_ANIM = 'zip:craftpix-net-624156-swamp-top-down-tileset-pixel-art.zip|Tiled_files/sprites_animated.png'
## Atlas parçaları: ad -> (sayfa, x, y, w, h). Ölü ağaç/taht animasyonlu sayfada 6 kare (kare aralığı 112 px); burada tek kare (sallanma = ağaç shader'ı).
SPRITES = {
    'olu_agac_b': (YO_ANIM, 23, 18, 100, 124), 'olu_agac_b2': (YO_ANIM, 23 + 336, 18, 100, 124),
    'olu_agac_o': (YO_ANIM, 21, 148, 70, 89), 'olu_agac_o2': (YO_ANIM, 21 + 224, 148, 70, 89), 'olu_agac_k': (YO_ANIM, 17, 246, 62, 56),
    'solgun_agac_b': (YO_OBJ, 17, 499, 63, 89), 'solgun_agac_o': (YO_OBJ, 85, 516, 59, 69),
    'taht_b': (YO_ANIM, 22, 316, 83, 100),
    'dev_iskelet': (YO_OBJ, 69, 323, 150, 113), 'kafa_yigini': (YO_OBJ, 23, 439, 71, 51), 'harabe_b': (YO_OBJ, 16, 16, 80, 95),
    'harabe_k': (YO_OBJ, 289, 65, 47, 46), 'dev_kafa': (YO_OBJ, 297, 328, 31, 47), 'kaburga': (YO_OBJ, 258, 320, 30, 64),
    'el_b': (YO_OBJ, 209, 530, 61, 62), 'el_mavi': (YO_OBJ, 274, 533, 45, 57), 'el_yesil': (YO_OBJ, 321, 534, 31, 53), 'el_k': (YO_OBJ, 355, 546, 28, 43),
    'kemik_1': (YO_OBJ, 243, 229, 26, 22), 'kemik_2': (YO_OBJ, 290, 233, 25, 22), 'kemik_3': (YO_OBJ, 320, 227, 32, 29), 'kemik_4': (YO_OBJ, 353, 228, 22, 28),
    'kemikler_k': (YO_OBJ, 21, 390, 34, 35),
    'diken_b': (YO_OBJ, 16, 592, 110, 80), 'diken_o': (YO_OBJ, 146, 615, 94, 53), 'diken_k': (YO_OBJ, 257, 626, 58, 46),
    'kutuk_b': (YO_OBJ, 27, 275, 84, 39), 'kutuk_o': (YO_OBJ, 212, 273, 41, 31), 'kutuk_2': (YO_OBJ, 259, 277, 42, 26), 'kaya_k': (YO_OBJ, 134, 217, 34, 33),
    'mavi_ot_1': (PM_OBJ, 238, 260, 21, 32), 'isik_bitki_k': (PM_OBJ, 165, 358, 20, 25), 'isik_bitki_o': (PM_OBJ, 83, 339, 37, 43),
    'mor_mantar_k': (PM_OBJ, 293, 377, 22, 39), 'turuncu_mantar_k': (PM_OBJ, 101, 405, 23, 27), 'mantar_k': (PM_OBJ, 133, 180, 22, 43),

    ## --- BATI "Kızıl Bataklık" (Lanetli Toprak) ---
    'kizil_kok': (LT_OBJ, 17, 888, 168, 209),
    'disli_bitki_b': (LT_OBJ, 22, 752, 109, 127), 'disli_bitki_o': (LT_OBJ, 133, 784, 75, 92), 'disli_bitki_k': (LT_OBJ, 218, 800, 51, 74),
    'mercan_b': (LT_OBJ, 24, 657, 98, 93), 'mercan_o': (LT_OBJ, 129, 665, 79, 81), 'mercan_k': (LT_OBJ, 215, 691, 51, 56),
    'yumurta_agac_b': (LT_OBJ, 289, 809, 45, 62), 'yumurta_agac_k': (LT_OBJ, 336, 820, 32, 56), 'yumurta_agac_kk': (LT_OBJ, 371, 835, 28, 40),
    'dokunac_b': (LT_OBJ, 17, 531, 156, 123), 'dokunac_o': (LT_OBJ, 149, 564, 89, 88), 'dokunac_k': (LT_OBJ, 245, 594, 75, 59), 'dokunac_kk': (LT_OBJ, 327, 593, 33, 60),
    'et_halka': (LT_OBJ, 17, 19, 109, 105), 'et_kaya_b': (LT_OBJ, 18, 133, 75, 71), 'et_kaya_o': (LT_OBJ, 103, 132, 51, 59), 'et_kaya_k': (LT_OBJ, 164, 149, 38, 39),
    'et_kaya_kk': (LT_OBJ, 209, 162, 29, 29), 'goz_kaya_b': (LT_OBJ, 24, 210, 66, 60), 'goz_kaya_o': (LT_OBJ, 101, 215, 54, 49), 'goz_kaya_k': (LT_OBJ, 167, 220, 32, 30),
    'et_tumsek_b': (LT_OBJ, 24, 282, 67, 64), 'et_tumsek_o': (LT_OBJ, 100, 294, 53, 56), 'tumsek_k1': (LT_OBJ, 160, 296, 46, 37), 'tumsek_k2': (LT_OBJ, 213, 297, 39, 36),
    'disli_agiz': (LT_OBJ, 336, 304, 64, 77), 'dev_goz': (LT_OBJ, 19, 406, 137, 114), 'kapan_b': (LT_OBJ, 180, 451, 74, 69), 'kapan_o': (LT_OBJ, 274, 453, 60, 56),
    'kapan_k': (LT_OBJ, 357, 469, 41, 38),
    'sari_yumurta_b': (LT_OBJ, 277, 135, 39, 34), 'sari_yumurta_o': (LT_OBJ, 328, 139, 30, 28), 'sari_yumurta_k': (LT_OBJ, 375, 137, 19, 18),
    'kese_b': (LT_OBJ, 275, 182, 69, 58), 'kese_o': (LT_OBJ, 357, 180, 42, 42), 'kese_k': (LT_OBJ, 360, 231, 31, 32),
    'kz_kemik_1': (LT_OBJ, 17, 357, 41, 38), 'kz_kemik_2': (LT_OBJ, 67, 358, 44, 33), 'kz_kemik_3': (LT_OBJ, 115, 359, 36, 32), 'kz_kemik_4': (LT_OBJ, 213, 358, 35, 35),
    'goz_sapi_1': (LT_OBJ, 252, 519, 51, 56), 'goz_sapi_2': (LT_OBJ, 316, 517, 39, 57), 'goz_sapi_k': (LT_OBJ, 368, 534, 31, 40), 'pembe_et': (LT_OBJ, 298, 697, 27, 34),
    ## --- DOĞU "Işıyan Kayalıklar" (Kayalık + Parlayan Mağara) ---
    'cam_b': (KY_OBJ, 306, 18, 76, 92), 'cam_o': (KY_OBJ, 385, 37, 63, 70), 'cam_k': (KY_OBJ, 454, 66, 36, 46),
    'bonsai_b': (KY_OBJ, 553, 406, 78, 73), 'bonsai_o': (KY_OBJ, 371, 405, 58, 70), 'bonsai_k': (KY_OBJ, 439, 420, 52, 58), 'bonsai_kk': (KY_OBJ, 644, 422, 55, 57),
    'kule_yikik': (KY_OBJ, 25, 17, 67, 92), 'kule_parca': (KY_OBJ, 106, 38, 51, 63), 'yilan_iskelet': (KY_OBJ, 425, 134, 139, 82), 'yilan_kuyruk': (KY_OBJ, 578, 143, 84, 67),
    'heykel': (KY_OBJ, 23, 401, 163, 139),
    'kaya_beyaz_b': (KY_OBJ, 288, 160, 64, 96), 'kaya_beyaz_o': (KY_OBJ, 289, 256, 62, 64), 'kaya_beyaz_k': (KY_OBJ, 354, 261, 46, 54), 'kaya_beyaz_k2': (KY_OBJ, 353, 165, 47, 55),
    'kaya_bej_b': (KY_OBJ, 19, 162, 56, 62), 'kaya_bej_o': (KY_OBJ, 146, 164, 60, 57), 'kaya_bej_o2': (KY_OBJ, 147, 260, 58, 57), 'kaya_bej_k': (KY_OBJ, 21, 258, 53, 61),
    'kristal_b1': (KY_OBJ, 277, 326, 41, 72), 'kristal_b2': (KY_OBJ, 325, 326, 41, 72), 'kristal_b3': (KY_OBJ, 373, 326, 41, 73),
    'kristal_o1': (KY_OBJ, 418, 344, 28, 54), 'kristal_o2': (KY_OBJ, 450, 344, 28, 54), 'kristal_o3': (KY_OBJ, 482, 344, 28, 54),
    'kristal_k1': (KY_OBJ, 520, 355, 16, 40), 'kristal_k2': (KY_OBJ, 617, 346, 18, 47), 'kristal_k3': (KY_OBJ, 646, 345, 21, 32),
    'mavi_mantar_b': (KY_OBJ, 742, 337, 56, 63), 'mavi_mantar_o': (KY_OBJ, 770, 290, 45, 46), 'mavi_mantar_k': (KY_OBJ, 705, 304, 30, 32),
    'tas_k1': (KY_OBJ, 16, 128, 32, 32), 'tas_k2': (KY_OBJ, 288, 128, 32, 32), 'tas_k3': (KY_OBJ, 81, 177, 41, 46), 'tas_k4': (KY_OBJ, 214, 176, 51, 47),
    'teal_cali': (KY_OBJ, 371, 482, 43, 43), 'teal_cali_k': (KY_OBJ, 417, 498, 29, 27),
    'mor_kristal': (PM_OBJ, 21, 80, 38, 48), 'mor_kristal_k': (PM_OBJ, 74, 86, 28, 39), 'altin_kristal': (PM_OBJ, 166, 11, 52, 50),

    ## --- madde 361: yeni arşivlerden ---
    ## KUZEY: topraktan çıkan taçlı dev iskelet, çığlık atan kafatası taşları
    'tacli_dev': (UD_OBJ, 5, 3, 150, 113), 'ciglik_tasi_1': (UD_OBJ, 633, 376, 31, 47), 'ciglik_tasi_2': (UD_OBJ, 681, 376, 31, 47),
    'mezar_taslari': (UD_OBJ, 66, 373, 57, 56), 'kemik_yigini_b': (UD_OBJ, 199, 375, 71, 51),
    ## BATI: zindan girişi "Et Kuyusu" (zemine gömülü dişli çukur; düz açık zemin pikselleri saydam yapılır, bkz. gen_atlas CLEAR_BG)
    'et_kuyusu': (CU_OBJ, 160, 480, 64, 77),
    ## madde 364: KÖK TÜMSEĞİ - lanetli toprak paketinin kendi zemin sayfasındaki tek başına duran kök öbeği (tepesi açık / çamur, + ayna);
    ## Batı'nın siyah gölcüklerinin yerine (kullanıcı: "siyah siyah öbekleri beğenmedim doğal durmuyor"). 6. alan 'ayna' = yatay çevrilir.
    'kok_hoyuk_a': (CU_GROUND, 13, 11, 89, 111), 'kok_hoyuk_a_ayna': (CU_GROUND, 13, 11, 89, 111, 'ayna'),
    'kok_hoyuk_c': (CU_GROUND, 13, 459, 89, 111), 'kok_hoyuk_c_ayna': (CU_GROUND, 13, 459, 89, 111, 'ayna'),
    ## GÜNEY "Sisli Sazlık" (bataklık arşivi)
    'yosun_kaya_b': (SW_OBJ, 7, 134, 67, 56), 'yosun_kaya_o': (SW_OBJ, 325, 84, 54, 43), 'yosun_kaya_o2': (SW_OBJ, 391, 84, 50, 40),
    'yosun_kaya_k': (SW_OBJ, 148, 137, 37, 35), 'yosun_kaya_kk': (SW_OBJ, 453, 71, 21, 19), 'yosun_kaya_k2': (SW_OBJ, 355, 503, 42, 39),
    'yosun_kaya_k3': (SW_OBJ, 404, 498, 42, 35), 'tas_yigini': (SW_OBJ, 384, 1, 48, 63), 'dikenli_kaya': (SW_OBJ, 352, 307, 64, 65),
    'dev_bataklik_agaci': (SW_OBJ, 3, 2, 104, 122), 'bataklik_agac_b': (SW_OBJ, 214, 196, 70, 107), 'bataklik_agac_o': (SW_OBJ, 71, 309, 53, 87),
    'bataklik_agac_k': (SW_OBJ, 403, 240, 41, 64), 'egri_agac': (SW_OBJ, 3, 192, 121, 112), 'kuru_dal_agac': (SW_OBJ, 192, 304, 80, 80),
    'mantar_agac_mor': (SW_OBJ, 288, 208, 64, 85), 'mantar_agac_mor_k': (SW_OBJ, 354, 250, 45, 50), 'mantar_agac_beyaz': (SW_OBJ, 4, 309, 50, 90),
    'mantar_agac_beyaz_k': (SW_OBJ, 278, 306, 37, 62), 'mantar_agac_mor2': (SW_OBJ, 133, 312, 56, 69),
    'kivrik_bitki': (SW_OBJ, 130, 196, 77, 106), 'kivrik_bitki_k': (SW_OBJ, 419, 312, 59, 81),
    'geyik_totem': (SW_OBJ, 369, 386, 47, 78), 'kutuk_y': (SW_OBJ, 276, 379, 40, 30), 'kafa_cubugu': (SW_OBJ, 185, 553, 17, 39),
    'fener_cicek_1': (SW_OBJ, 72, 483, 22, 48), 'fener_cicek_2': (SW_OBJ, 34, 489, 22, 53), 'fener_cicek_3': (SW_OBJ, 132, 499, 23, 45),
    'egrelti_1': (SW_OBJ, 7, 551, 36, 35), 'egrelti_2': (SW_OBJ, 100, 549, 41, 37), 'egrelti_3': (SW_OBJ, 55, 553, 34, 31),
    'saz_1': (SW_OBJ, 221, 558, 24, 29), 'saz_2': (SW_OBJ, 276, 553, 24, 29), 'saz_3': (SW_OBJ, 112, 593, 24, 29), 'saz_4': (SW_OBJ, 178, 596, 24, 28),
}
## Animasyonlu parçalar (madde 361): ad -> (sayfa, [(x, y) her karenin sol üstü], w, h, kare süresi ms, renk değişimi). Atlasta kareler
## alt alta (aynı aralıkla) dizilir, tileset'te her karoya Tiled <animation> yazılır (YATI -> Godot animation_separation).
ANIMS = {
    ## KUZEY zindan girişi "Kemik Mahzeni": kafatası taçlı mahzen kapısı, yeşil ruh alevleri (18 karenin her üçüncüsü)
    'kemik_mahzen': (UD_A5, [(6 + 96 * (k % 6), 12 + 112 * (k // 6)) for k in range(0, 18, 3)], 83, 100, 160, None),
    ## DOĞU zindan girişi "Boynuzlu Kapı": boynuzlu kafatası, ışıyan kapı - iki parlaklık karesi nabız atar; sarı ışık bölgenin mavisine
    'boynuzlu_kapi': (CV_OBJ, [(2, 2), (66, 2), (66, 2), (2, 2)], 61, 70, 380, 'mavi'),
    ## GÜNEY: yaşayan yüzlü yaşlı ağaç + bataklık kulübesi (fener titrer)
    'yuzlu_agac': (SW_ANIM, [(0, 10 + 368 * k) for k in range(6)], 112, 102, 170, None),
    'bataklik_kulube': (SW_ANIM, [(149, 256 + 368 * k) for k in range(6)], 70, 104, 170, None),
}
ATLAS_PNG = os.path.join(PROJECT, 'harita', 'derin_orman.png')
ATLAS_TSX = os.path.join(PROJECT, 'harita', 'Derin orman.tsx')
ATLAS_JSON = os.path.join(HERE, 'atlas.json')


def tmx_layers(text):
    """{katman adı: {(x, y): gid}} (sonsuz harita chunk'ları)."""
    root = ET.fromstring(text)
    out = {}
    for lay in root.iter('layer'):
        cells = {}
        d = lay.find('data')
        for ch in d.findall('chunk'):
            cx, cy, w = int(ch.get('x')), int(ch.get('y')), int(ch.get('width'))
            vals = [int(v) for v in ch.text.replace('\r', '').replace('\n', '').split(',') if v.strip()]
            for i, v in enumerate(vals):
                if v:
                    cells[(cx + i % w, cy + i // w)] = v
        out[lay.get('name')] = cells
    return out


def _jitter(i, k):
    """Kutu kenarı dalgası: tamsayı -> [-1, 1] yumuşak değer gürültüsü (k = kenar tohumu)."""
    def h(n):
        v = (((n * 374761393) ^ (k * 668265263)) & 0xFFFFFFFF)
        v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
        return (v & 0xFFFF) / 32767.5 - 1.0
    f = i / 7.0
    a = int(f // 1)
    t = f - a
    t = t * t * (3 - 2 * t)
    return h(a) * (1 - t) + h(a + 1) * t


def zone_cells(layers, name, boxed=True, removed_too=False):
    """Bölge hücreleri (havza x dalgalı kutu). boxed=False: kutusuz tüm havza (maskenin açık arazideki yumuşak geçişi için).
    Kaldırılan bölge (REMOVED) boş döner; removed_too=True eski hücrelerini verir."""
    if name in REMOVED and not removed_too:
        return set()
    z = ZONES[name]
    seed, (x0, x1), (y0, y1) = z[0], z[1], z[2]
    jit = z[3] if len(z) > 3 else 0
    wall = (set(layers['Orman parçaları']) | set(layers['Su'])) - set(layers['Köprü alt'])
    free = [[(x, y) not in wall for x in range(N)] for y in range(N)]
    dist = [[999] * N for _ in range(N)]
    q = deque()
    for y in range(N):
        for x in range(N):
            if not free[y][x] or x in (0, N - 1) or y in (0, N - 1):
                dist[y][x] = 0
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                nx, ny = x + dx, y + dy
                if 0 <= nx < N and 0 <= ny < N and dist[ny][nx] > dist[y][x] + 1:
                    dist[ny][nx] = dist[y][x] + 1
                    q.append((nx, ny))
    comp = [[-1] * N for _ in range(N)]
    cid = 0
    for y in range(N):
        for x in range(N):
            if dist[y][x] >= R and comp[y][x] < 0:
                comp[y][x] = cid
                dq = deque([(x, y)])
                while dq:
                    a, b = dq.popleft()
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        na, nb = a + dx, b + dy
                        if 0 <= na < N and 0 <= nb < N and comp[nb][na] < 0 and dist[nb][na] >= R:
                            comp[nb][na] = cid
                            dq.append((na, nb))
                cid += 1
    dq = deque((x, y) for y in range(N) for x in range(N) if comp[y][x] >= 0)
    while dq:
        x, y = dq.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < N and 0 <= ny < N and free[ny][nx] and comp[ny][nx] < 0:
                comp[ny][nx] = comp[y][x]
                dq.append((nx, ny))
    target = comp[seed[1]][seed[0]]

    def inside(x, y):
        if not boxed:
            return True
        if not jit:
            return x0 <= x < x1 and y0 <= y < y1
        ## dalga tohumu = kenarın kendisi: komşu bölgelerin ortak kenarı aynı dalgayı çizer; harita kenarındaki (0 / N) kenar dalgalanmaz
        def edge(v, t, k):
            return v if v <= 0 or v >= N else v + jit * _jitter(t, k + v)
        return edge(x0, y, 1000) <= x < edge(x1, y, 1000) and edge(y0, x, 3000) <= y < edge(y1, x, 3000)
    out = {(x, y) for y in range(N) for x in range(N) if comp[y][x] == target and inside(x, y)}
    if name in GRASS_ONLY:
        out -= set(layers['Zemin Toprak']) - set(layers['Zemin Çimen'])
    return out


def keep_dirt_cells(layers):
    """Madde 387: toprak pikselleri bölge zeminine (yol karosuna) çevrilmeyen hücreler - GRASS_ONLY bölgelerine KEEP_DIRT_REACH hücre yakın,
    diğer bölgelerin havzası hariç (onların yolları eskisi gibi bölgenin yol karosu)."""
    others = set()
    for name in ZONES:
        if name not in GRASS_ONLY and name not in REMOVED:
            others |= zone_cells(layers, name, boxed=False)
    out = set()
    r = KEEP_DIRT_REACH
    for name in GRASS_ONLY:
        for (x, y) in zone_cells(layers, name):
            out.update((x + dx, y + dy) for dx in range(-r, r + 1) for dy in range(-r, r + 1))
    out = {c for c in out if 0 <= c[0] < N and 0 <= c[1] < N} - others
    ## dış çerçeve (oyun alanı dışı) maskenin KENAR değerini alır -> kenar hücresi korunuyorsa dışarıdaki sütunu/satırı da
    edge = set()
    for (x, y) in out:
        dirs = [(-1, 0)] * (x == 0) + [(1, 0)] * (x == N - 1) + [(0, -1)] * (y == 0) + [(0, 1)] * (y == N - 1)
        for dx, dy in dirs:
            edge.update((x + dx * k, y + dy * k) for k in range(1, OUTER_REACH + 1))
    return out | edge


def tilesets(text):
    """[(firstgid, source)] sıralı."""
    return [(int(a), b) for a, b in re.findall(r'<tileset firstgid="(\d+)" source="([^"]+)"/>', text)]


## ---------------- HARİTANIN KENDİ AĞAÇ TÜRLERİ (madde 365) ----------------
## Kullanıcı: "bazı bölgelerde ağaçlar bölgeleriyle uyumsuz görünüyor" - gri kül Kuzey'de ve bej taş Doğu'da orta bölgenin açık yeşil yapraklı
## ağaçları, sisli Güney'de palmiye/yonca ağacı kalmıştı. Ağaç 0/1/2'deki her karo tileset'teki NESNESİNE (opak piksel bileşeni; anahtar =
## (tileset, bileşenin sol üst pikseli)) bağlanır, nesnenin türü bu tablodan. Tabloda olmayan (sonradan Tiled'da eklenen) tür dokunulmadan kalır.
## Türler: igne (iğne yapraklı / sivri taçlı), yaprak (yuvarlak yapraklı), kabarik (karnabahar taçlı), yosunlu (sarkan yosunlu yaşlı ağaç),
## pembe (çiçekli), palmiye, tropik (yonca yapraklı), olu (yapraksız), sarmasik.
AGAC_TURU = {
    ('Objects.tsx', 145, 1): 'yaprak', ('Objects.tsx', 81, 2): 'igne', ('Objects.tsx', 371, 2): 'yaprak', ('Objects.tsx', 283, 3): 'kabarik',
    ('Objects.tsx', 5, 5): 'igne', ('Objects.tsx', 243, 78): 'kabarik', ('Objects.tsx', 18, 80): 'igne', ('Objects.tsx', 131, 80): 'yaprak',
    ('Objects.tsx', 353, 80): 'yaprak', ('Objects.tsx', 80, 82): 'igne', ('Objects.tsx', 165, 144): 'yaprak', ('Objects.tsx', 227, 150): 'yaprak',
    ('bataklık spritesheet.tsx', 872, 1624): 'sarmasik', ('bataklık spritesheet.tsx', 592, 1876): 'olu', ('meyve sebze.tsx', 192, 119): 'yaprak',
    ('sade ağaç ve taş.tsx', 144, 0): 'igne', ('sade ağaç ve taş.tsx', 81, 1): 'yaprak', ('sade ağaç ve taş.tsx', 209, 6): 'yaprak',
    ('sade ağaç ve taş.tsx', 70, 80): 'yaprak', ('sade ağaç ve taş.tsx', 128, 83): 'igne', ('sade ağaç ve taş.tsx', 183, 86): 'yaprak',
    ('sade ağaç ve taş.tsx', 241, 86): 'yaprak', ('sade ağaç ve taş.tsx', 4, 145): 'kabarik',
    ('sadece agac golgeli.tsx', 417, 2): 'yosunlu', ('sadece agac golgeli.tsx', 547, 2): 'pembe', ('sadece agac golgeli.tsx', 417, 81): 'pembe',
    ('sadece agac golgeli.tsx', 368, 82): 'yosunlu', ('sadece agac golgeli.tsx', 289, 150): 'pembe',
    ('sadece_agac.tsx', 417, 2): 'yosunlu', ('sadece_agac.tsx', 547, 2): 'pembe', ('sadece_agac.tsx', 609, 4): 'tropik',
    ('sadece_agac.tsx', 673, 5): 'palmiye', ('sadece_agac.tsx', 357, 8): 'olu', ('sadece_agac.tsx', 311, 80): 'olu',
    ('sadece_agac.tsx', 368, 82): 'yosunlu', ('sadece_agac.tsx', 532, 84): 'palmiye', ('sadece_agac.tsx', 134, 146): 'yosunlu',
    ('sadece_agac.tsx', 97, 147): 'olu',
}


class AgacTurleri:
    """gid -> (tür ya da None, nesne anahtarı, karonun nesne içindeki atlas konumu). Nesne = tileset resmindeki 8-komşu opak piksel bileşeni
    (atlas komşuluğu kuralının piksel hâli: bitişik karolara taşan tek ağaç bir nesne); bileşenler karo karo gerektikçe bulunur."""

    def __init__(self, text):
        self.sets = sorted(tilesets(text))
        self.img = {}
        self.res = {}

    def _sheet(self, src):
        if src not in self.img:
            from PIL import Image
            p = os.path.join(PROJECT, 'harita', src)
            root = ET.parse(p).getroot()
            ip = os.path.normpath(os.path.join(os.path.dirname(p), root.find('image').get('source')))
            a = np.asarray(Image.open(ip).convert('RGBA'))[..., 3] > 0
            self.img[src] = (a, int(root.get('columns')), np.zeros(a.shape, np.int32), [None])
        return self.img[src]

    def lookup(self, gid):
        g = gid & 0x1FFFFFFF
        best = None
        for fg, src in self.sets:
            if fg <= g:
                best = (fg, src)
        return best[1], g - best[0]

    def of(self, gid):
        src, lid = self.lookup(gid)
        if (src, lid) in self.res:
            return self.res[(src, lid)]
        a, cols, lab, comps = self._sheet(src)
        r, c = divmod(lid, cols)
        tile = a[r * 16:(r + 1) * 16, c * 16:(c + 1) * 16]
        out = (None, None, (c, r))
        if tile.any():
            sub = lab[r * 16:(r + 1) * 16, c * 16:(c + 1) * 16]
            ## en çok pikseli olan bileşen (karoya komşu ağacın ucu girmiş olabilir); etiketsiz pikselden yeni bileşen
            for y, x in zip(*tile.nonzero()):
                if not sub[y, x]:
                    self._label(a, lab, comps, r * 16 + y, c * 16 + x)
            ids, counts = np.unique(sub[tile], return_counts=True)
            k = ids[counts.argmax()]
            key = (src,) + comps[k]
            out = (AGAC_TURU.get(key), key, (c, r))
        self.res[(src, lid)] = out
        return out

    @staticmethod
    def _label(a, lab, comps, y0, x0):
        h, w = a.shape
        n = len(comps)
        lab[y0, x0] = n
        q = deque([(y0, x0)])
        mx, my = x0, y0
        while q:
            y, x = q.popleft()
            mx, my = min(mx, x), min(my, y)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    v, u = y + dy, x + dx
                    if 0 <= v < h and 0 <= u < w and a[v, u] and not lab[v, u]:
                        lab[v, u] = n
                        q.append((v, u))
        comps.append((int(mx), int(my)))

    def instances(self, cells):
        """{hücre: gid} (bir katman) -> [(tür, nesne anahtarı, [hücreler])]: aynı nesnenin karoları hücre - atlas konumu (çapa) aynı olan
        hücreler, sprite'ın boş köşe karoları dahil (çevrilmiş karoda çapa tutmaz -> çevrilmişler aynı nesneli 4-komşu hücre öbeği)."""
        groups = {}
        flipped = {}
        empty = []
        for c, g in cells.items():
            tur, key, (tc, tr) = self.of(g)
            if g & 0xE0000000:
                if key is not None:
                    flipped[c] = (tur, key)
                continue
            anchor = (self.lookup(g)[0], c[0] - tc, c[1] - tr)
            if key is None:
                empty.append((anchor, c))   ## tamamen saydam karo (ağaç sprite'ının boş köşesi): aynı çapadaki ağaca katılır
                continue
            groups.setdefault(anchor + key, (tur, key, []))[2].append(c)
        by_anchor = {k[:3]: v for k, v in groups.items()}
        for anchor, c in empty:
            if anchor in by_anchor:
                by_anchor[anchor][2].append(c)
        out = list(groups.values())
        seen = set()
        for c in sorted(flipped):
            if c in seen:
                continue
            tur, key = flipped[c]
            comp, st = [], [c]
            seen.add(c)
            while st:
                p = st.pop()
                comp.append(p)
                for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    q = (p[0] + d[0], p[1] + d[1])
                    if q in flipped and q not in seen and flipped[q][1] == key:
                        seen.add(q)
                        st.append(q)
            out.append((tur, key, comp))
        return out

