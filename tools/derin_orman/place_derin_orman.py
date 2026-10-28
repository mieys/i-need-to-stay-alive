# DERİN ORMAN - üç "tepe arkası" bölgesi Harita.tmx'te (madde 359/360; prototip madde 358):
#   KUZEY "Kadim Kara Orman": haritanın KENDİ koyu orman kümeleri gürültüye göre basılır, ~%18 yerine Yarı Ölü ölü ağaç öbeği, kemik taht açıklığı (sabit).
#   BATI "Kızıl Bataklık": mevcut ağaçların ~%65'i Lanetli Toprak kızıl bitki/ağaçlarıyla değişir, et kayaları, göz bitkileri, yumurta keseleri;
#        set parçaları (otomatik en geniş açıklık): Yutan Ağız, Dev Göz, Et Halkası.
#   DOĞU "Işıyan Kayalıklar": ağaçların ~%50'si Kayalık çam/bonsai ağaçlarıyla değişir, beyaz/bej kayalar, kristaller, ışıyan mavi mantarlar;
#        set parçaları: Yıkık Kule, Deniz Yılanı İskeleti, Kanatlı Heykel.
#   MADDE 385: BATI ve DOĞU KALDIRILDI (zindan girişleri yerinde, KEPT_GATES); KUZEY kuzeybatıya uzadı (KUZEY_BATI, aynı derinlik).
#   MADDE 387: GÜNEY batısındaki çayıra uzadı (GUNEY_BATI; toprak yol/açıklık bölgeye girmez, toprak pikselleri olduğu gibi kalır).
# Katmanlar: ağaç benzeri parçalar -> "Ağaç ölü" (Ağaç önekli: sallanma + derinlik + gövde çarpışması), engel nesneler -> "Derin orman nesneleri"
# (derinlik + çarpışma), düz süsler -> "Derin orman süsleri" (engel değil). Bölgedeki "Çiçekler 1" karoları silinir.
# Karolar harita/derin_orman.png ("Derin orman.tsx", gen_atlas.py). Bölgeler derin_orman_core.ZONES (havza).
# Kullanım:
#   python -I tools/derin_orman/place_derin_orman.py               -> kuru çalışma: sayılar + out/onizleme.png + şu anki md5
#   python -I tools/derin_orman/place_derin_orman.py --out <klasör>  -> doğrulama: YEDEKTEN kurar, TMX + maske + zemin atlası + places o klasöre
#   python -I tools/derin_orman/place_derin_orman.py --apply <md5> -> Harita.tmx'e yazar (md5 kapısı), ilk yazımda yedek; bölge maskesini yazar ve
#       bölge zeminini GERÇEK KAROLARA pişirir (apply_zemin / zemin_karolari.py, madde 363: harita/derin_orman_zemin.png + "Derin orman zemin.tsx")
#       harita/yedek/Harita_2026-10-21_oncesi_derin-orman.tmx.bak
# Tekrar koşma: derin orman katmanları varsa ve canlı TMX son yazdığımızla aynıysa (out/son_yazim.md5) hep YEDEKTEN yeniden kurulur; değilse DURUR.
import hashlib
import json
import os
import random
import re
import shutil
import sys
from collections import Counter, deque

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import derin_orman_core as C  # noqa: E402

OUT = os.path.join(C.HERE, 'out')
## madde 385: taban = 2026-10-21 derin orman öncesi yedek + çayır süsleri (madde 383, derin orman yazımının ÜSTÜNE yapılmıştı; hücreleri çakışmıyor)
YEDEK = os.path.join(C.PROJECT, 'harita', 'yedek', 'Harita_2026-10-27_oncesi_derin-orman_cayir-dahil.tmx.bak')
STAMP = os.path.join(OUT, 'son_yazim.md5')
TREE_LAYERS = ['Ağaç 0', 'Ağaç 1', 'Ağaç 2']
DEAD = 'Ağaç ölü'
OBJ = 'Derin orman nesneleri'
DECOR = 'Derin orman süsleri'
PIT = 'Derin orman çukurları'   ## madde 361: zemine gömülü parçalar (Et Kuyusu) - karakterin ALTINDA çizilir, ayak izinin tamamı engel
PLACES_GD = os.path.join(C.PROJECT, 'scripts', 'deep_forest_places.gd')

## ---------------- KUZEY (madde 359; madde 361: seyreltildi + zindan girişi) ----------------
## B'nin orman kümeleri (prototip kaliplar.png'den, kutu sol üst hücresi): koyu iğne yapraklı / koyu yuvarlak gruplar + haritanın 2 ölü ağacı.
B_PICK = ['13,131', '138,52', '144,228', '164,227', '22,172', '230,65', '234,104', '238,81', '249,102', '25,79', '3,18', '36,2', '37,223', '41,1',
          '61,100', '73,102', '76,249', '67,251', '238,111', '248,120', '237,58', '83,35', '202,228', '224,242']
## Madde 361 (kullanıcı: "yeni bölgelerde bişeyleri çok fazla yerleştirmişsin hep"): süs sayıları ~1/3, saçılan süsler gürültü ÖBEKLERİNDE
## ('clump': değer gürültüsü bu eşiğin altındaki hücrelere süs konmaz -> aralarda boş zemin), ağaç değişimi/ek ağaç azaldı. Bölgenin
## kimliğini artık ZEMİN taşıyor (gen_zemin_dokusu.py + harita_renk.gdshaderinc do_zemin_uygula).
KUZEY = {
    'seed': 20261021, 'mode': 'stamp', 'noise_thr': 0.44, 'dead_ratio': 0.2, 'clump': 0.52, 'erase_cim': True, 'fill_holes': True,
    ## madde 365: gri kül zeminde açık yeşil yapraklı / karnabahar taçlı ağaçlar ölü-solgun ağaca döner (sığmazsa silinir); iğne yapraklı +
    ## yosunlu kadim ağaçlar kalır (yaprakları shader'da bölgenin koyu paletine boyanır, harita_renk.gdshaderinc DOA_*)
    'agac_kalir': {'igne', 'olu', 'yosunlu'}, 'tree_fallback': ['olu_agac_k'],
    ## madde 385: eski Batı'nın sildiği dikiş ağaçları (legacy_reach) dönüşümde sona -> kuzeyin eski ağaçlarının rastgele sırası/türleri aynı
    'convert_late': True,
    'tree_kinds': [('olu_agac_b', 0.15), ('olu_agac_b2', 0.15), ('olu_agac_o', 0.25), ('olu_agac_o2', 0.2), ('solgun_agac_b', 0.13), ('solgun_agac_o', 0.12)],
    'base_deco': ['mantar_k', 'turuncu_mantar_k', 'mor_mantar_k', 'isik_bitki_k'], 'base_deco_p': 0.12,
    ## (parça, ayak hücresi, katman): kemik taht açıklığı + geçit ağzı
    'fixed': [
        ('taht_b', (120, 17), OBJ), ('kafa_yigini', (115, 25), OBJ), ('dev_iskelet', (142, 24), OBJ), ('kaburga', (134, 20), OBJ),
        ('el_b', (115, 21), DECOR), ('el_mavi', (124, 21), DECOR), ('el_yesil', (119, 24), DECOR),
        ('diken_o', (113, 14), DECOR), ('kemikler_k', (124, 27), DECOR),
        ('harabe_b', (116, 31), OBJ), ('harabe_k', (133, 34), OBJ), ('kemik_3', (126, 32), DECOR),
    ],
    ## (x, y, w, h): taht açıklığı, geçit koridoru, dev iskelet
    'reserved': [(112, 12, 16, 15), (119, 26, 10, 20), (135, 15, 15, 11)],
    ## ZİNDAN GİRİŞİ "Kemik Mahzeni" (animasyonlu, yeşil ruh alevleri) + çığlık atan kafatası taşları (taçlı dev = taht yanındaki dev_iskelet)
    'auto': [
        [('kemik_mahzen', (0, 0), OBJ), ('ciglik_tasi_1', (-5, 1), OBJ), ('ciglik_tasi_2', (5, 1), OBJ), ('kemik_1', (-2, 3), DECOR), ('kemik_4', (3, 3), DECOR)],
    ],
    'gates': {'kemik_mahzen': 'Kemik Mahzeni'},
    'scatter': [
        (['mavi_ot_1', 'isik_bitki_k', 'isik_bitki_o'], 12, 140.0, False, DECOR),
        (['mor_mantar_k', 'turuncu_mantar_k', 'mantar_k'], 10, 140.0, False, DECOR),
        (['diken_b', 'diken_o', 'kutuk_b', 'kutuk_o', 'kaya_k', 'kemik_yigini_b'], 14, 150.0, False, DECOR),
        (['kemik_1', 'kemik_2', 'kemik_4'], 8, 150.0, True, DECOR),
    ],
}
## ---------------- BATI "Kızıl Bataklık" ----------------
BATI = {
    ## 2. tur: haritanın yeşil ağaçlarının HEPSİ gider (kızıl bölgede yeşil ağaç tasarım hatasıydı); yerine bitki sığmazsa ağaç sadece silinir
    'seed': 20261022, 'mode': 'replace', 'replace_p': 1.0, 'erase_all': True, 'clump': 0.5, 'erase_cim': True, 'fill_holes': True,
    ## haritanın yeşil çalı öbekleri kızıla boyanınca düz koyu bordo bloklar oluyordu -> Batı'da kalkar (saklanma çalılığı - oynanış - kalır)
    'erase_layers': ['Çalılar', 'Çalılar1', 'Animasyonsuz çalılar'],
    ## bölge kenarındaki duvar/uçurum hücrelerinde duran yeşil ağaçlar da (bölgeye 3 hücre yakın) gider
    'tree_reach': 3,
    'tree_fallback': ['disli_bitki_k', 'mercan_k', 'yumurta_agac_k', 'yumurta_agac_kk'],
    'tree_kinds': [('disli_bitki_b', 0.16), ('disli_bitki_o', 0.2), ('mercan_b', 0.12), ('mercan_o', 0.14), ('dokunac_o', 0.1), ('yumurta_agac_b', 0.1),
                   ('dokunac_b', 0.08), ('kizil_kok', 0.04), ('disli_bitki_k', 0.06)],
    'base_deco': ['kese_k', 'sari_yumurta_k', 'goz_sapi_k', 'et_kaya_kk', 'pembe_et'], 'base_deco_p': 0.1,
    'fixed': [], 'reserved': [],
    ## otomatik set parçaları: en geniş açıklıklar (parça, ayağa göre ofset, katman); ilk parça çapa.
    ## ZİNDAN GİRİŞİ "Et Kuyusu" (zemine gömülü dişli çukur, PIT katmanı: karakterin altında, tamamı engel)
    'auto': [
        [('et_kuyusu', (0, 0), PIT), ('goz_sapi_2', (-5, 0), DECOR), ('goz_sapi_k', (5, 0), DECOR), ('kz_kemik_1', (-3, 3), DECOR), ('kz_kemik_3', (3, 3), DECOR)],
        [('dev_goz', (0, 0), OBJ), ('goz_sapi_1', (-7, 1), DECOR), ('goz_kaya_o', (-8, 4), OBJ), ('kz_kemik_2', (4, 3), DECOR)],
        [('et_halka', (0, 0), OBJ), ('kese_b', (6, 0), DECOR), ('sari_yumurta_b', (-6, 1), DECOR)],
    ],
    'gates': {'et_kuyusu': 'Et Kuyusu'},
    'extra': [(['disli_bitki_o', 'mercan_o', 'mercan_k', 'yumurta_agac_k', 'dokunac_o', 'disli_bitki_k'], 18, 120.0, DEAD, 0.5),
              ## madde 364: kök tümsekleri (engel + derinlik; eski siyah gölcüklerin yerine), öbek öbek
              (['kok_hoyuk_a', 'kok_hoyuk_a_ayna', 'kok_hoyuk_c', 'kok_hoyuk_c_ayna'], 18, 90.0, OBJ, 0.3)],
    'scatter': [
        (['et_kaya_b', 'et_kaya_o', 'goz_kaya_b', 'goz_kaya_o', 'et_tumsek_o', 'kapan_b', 'kapan_o', 'disli_agiz'], 14, 170.0, False, OBJ),
        (['et_kaya_k', 'et_kaya_kk', 'goz_kaya_k', 'tumsek_k1', 'kapan_k'], 14, 130.0, False, DECOR),
        (['kese_b', 'kese_o', 'kese_k', 'sari_yumurta_o', 'sari_yumurta_k'], 12, 140.0, False, DECOR),
        (['goz_sapi_1', 'goz_sapi_k', 'dokunac_k', 'dokunac_kk', 'pembe_et'], 12, 140.0, False, DECOR),
        (['kz_kemik_1', 'kz_kemik_2', 'kz_kemik_4'], 8, 160.0, True, DECOR),
    ],
}
## ---------------- DOĞU "Işıyan Kayalıklar" ----------------
DOGU = {
    'seed': 20261023, 'mode': 'replace', 'replace_p': 0.45, 'clump': 0.5, 'erase_cim': True, 'fill_holes': True, 'tree_fallback': ['cam_k', 'bonsai_kk', 'teal_cali'],
    ## madde 365: bej taş kayalıkta yalnız iğne yapraklı (+ yapraksız) kalır; yapraklı/çiçekli/yosunlu ağaçlar çam-bonsaiye döner
    'agac_kalir': {'igne', 'olu'},
    'tree_kinds': [('cam_b', 0.2), ('cam_o', 0.2), ('cam_k', 0.1), ('bonsai_b', 0.15), ('bonsai_o', 0.15), ('bonsai_k', 0.1), ('bonsai_kk', 0.1)],
    'base_deco': ['mavi_mantar_k', 'kristal_k1', 'kristal_k3', 'teal_cali_k'], 'base_deco_p': 0.1,
    'fixed': [], 'reserved': [],
    ## ZİNDAN GİRİŞİ "Boynuzlu Kapı" (boynuzlu kafatası, mavi ışıyan kapı - nabız atar) + iki büyük kristal
    'auto': [
        [('boynuzlu_kapi', (0, 0), OBJ), ('kristal_b1', (-4, 0), OBJ), ('kristal_b3', (4, 0), OBJ), ('mavi_mantar_k', (-2, 3), DECOR), ('kristal_k2', (3, 3), DECOR)],
        [('heykel', (0, 0), OBJ), ('mavi_mantar_k', (-3, 2), DECOR)],
        [('yilan_iskelet', (0, 0), OBJ), ('yilan_kuyruk', (9, -1), OBJ), ('mavi_mantar_o', (-3, 3), DECOR)],
        [('kule_yikik', (0, 0), OBJ), ('kule_parca', (5, 1), OBJ)],
    ],
    'gates': {'boynuzlu_kapi': 'Boynuzlu Kapı'},
    'extra': [(['kaya_beyaz_b', 'kaya_beyaz_o', 'kaya_beyaz_k', 'kaya_bej_b', 'kaya_bej_o', 'kaya_bej_k'], 16, 130.0, OBJ, 0.45),
              (['kristal_b1', 'kristal_b2', 'kristal_b3', 'mor_kristal', 'altin_kristal', 'mavi_mantar_b'], 10, 150.0, OBJ, 0.45)],
    'scatter': [
        (['kristal_o1', 'kristal_o2', 'kristal_k1', 'kristal_k2', 'kristal_k3', 'mor_kristal_k'], 16, 120.0, False, DECOR),
        (['mavi_mantar_o', 'mavi_mantar_k'], 12, 130.0, False, DECOR),
        (['tas_k1', 'tas_k3', 'tas_k4', 'teal_cali'], 12, 130.0, True, DECOR),
    ],
}
## ---------------- GÜNEY "Sisli Sazlık" (madde 361, daha az tehlikeli) ----------------
## Bataklık arşivi: yosunlu taşlar, mantar ağaçları, eğrelti, saz; set parçaları: YAŞAYAN yüzlü yaşlı ağaç (animasyonlu, gözünü kırpar), bataklık
## kulübesi (feneri titrer) + taş yığını, dev bataklık ağacı + geyik kafatası totemi. Zindan girişi YOK (tehlikeli bölge değil).
GUNEY = {
    'seed': 20261024, 'mode': 'replace', 'replace_p': 0.4, 'clump': 0.5, 'tree_fallback': ['bataklik_agac_k', 'mantar_agac_mor_k', 'mantar_agac_beyaz_k'],
    ## madde 365: sisli bataklıkta palmiye, yonca yapraklı tropik ağaç ve çiçekli ağaç bataklık ağacına döner
    'agac_kalir': {'igne', 'yaprak', 'kabarik', 'yosunlu', 'olu', 'sarmasik'},
    'tree_kinds': [('bataklik_agac_b', 0.22), ('bataklik_agac_o', 0.22), ('bataklik_agac_k', 0.14), ('mantar_agac_mor', 0.1), ('mantar_agac_beyaz', 0.1),
                   ('mantar_agac_mor2', 0.08), ('kivrik_bitki', 0.07), ('egri_agac', 0.07)],
    'base_deco': ['egrelti_1', 'egrelti_3', 'saz_1', 'saz_2'], 'base_deco_p': 0.12,
    'fixed': [], 'reserved': [],
    'auto': [
        [('yuzlu_agac', (0, 0), DEAD), ('fener_cicek_1', (-5, 1), DECOR), ('fener_cicek_3', (5, 1), DECOR), ('egrelti_2', (3, 2), DECOR)],
        [('bataklik_kulube', (0, 0), OBJ), ('tas_yigini', (4, 0), OBJ), ('kafa_cubugu', (-3, 1), DECOR), ('fener_cicek_2', (-4, 2), DECOR), ('kutuk_y', (3, 3), DECOR)],
        [('dev_bataklik_agaci', (0, 0), DEAD), ('geyik_totem', (5, 1), OBJ), ('yosun_kaya_k', (-5, 2), OBJ)],
    ],
    'gates': {},
    'extra': [(['yosun_kaya_b', 'yosun_kaya_o', 'yosun_kaya_o2', 'yosun_kaya_k2', 'dikenli_kaya'], 12, 140.0, OBJ, 0.5),
              (['mantar_agac_beyaz_k', 'mantar_agac_mor_k', 'kivrik_bitki_k', 'kuru_dal_agac'], 8, 160.0, DEAD, 0.5)],
    'scatter': [
        (['egrelti_1', 'egrelti_2', 'egrelti_3', 'fener_cicek_1', 'fener_cicek_2', 'fener_cicek_3'], 16, 120.0, False, DECOR),
        (['saz_1', 'saz_2', 'saz_3', 'saz_4'], 14, 110.0, False, DECOR),
        (['yosun_kaya_kk', 'yosun_kaya_k3', 'kutuk_y', 'kafa_cubugu'], 8, 150.0, False, DECOR),
    ],
}
## ---------------- KUZEYBATI (madde 385): Kadim Kara Orman'ın kuzeybatı uzantısı (eski Batı bölgesinin üst şeridi, kuzeyle aynı derinlik) ----------------
## Kuzeyle aynı kurallar (damga + ölü ağaç öbekleri + süsler + tür dönüşümü), kendi tohumu, kuzeyin damga kalıpları (aynı orman kümeleri);
## saçılan süs sayıları alanına göre (3641 / 6271 hücre). Set parçası / kapı yok - eski Batı'nın Et Kuyusu KEPT_GATES ile yerinde, çevresi boş.
## edge_clamp: oyun alanı dışındaki (dış çerçeve, y < 0 / x < 0) ağaçlar maskenin kenar değerini aldığı için (oyunda bölge rengi) kenar hücresiyle
## sayılır -> uymayan türü dönüşür/silinir (eskiden Batı'nın tree_reach'i siliyordu)
KUZEY_BATI = dict(KUZEY, seed=20261027, fixed=[], reserved=[], auto=[], gates={}, templates_from='kuzey', convert_late=False, edge_clamp=True, scatter=[
    (['mavi_ot_1', 'isik_bitki_k', 'isik_bitki_o'], 7, 140.0, False, DECOR),
    (['mor_mantar_k', 'turuncu_mantar_k', 'mantar_k'], 6, 140.0, False, DECOR),
    (['diken_b', 'diken_o', 'kutuk_b', 'kutuk_o', 'kaya_k', 'kemik_yigini_b'], 8, 150.0, False, DECOR),
    (['kemik_1', 'kemik_2', 'kemik_4'], 5, 150.0, True, DECOR),
])
## ---------------- GÜNEYBATI (madde 387): Sisli Sazlık'ın batısındaki çayır (uçurumlarla çevrili ayrı havza, toprak yol/açıklık hariç) ----------------
## Güneyle aynı kurallar (ağaç değişimi + tür dönüşümü + ek parçalar + süsler), kendi tohumu, set parçası yok; sayılar alanına göre (3368 / 6499
## hücre). edge_clamp: alt kenarın altındaki dış çerçeve ağaçları kenar hücresiyle sayılır (oyunda maskenin kenar değerini alıyorlar).
GUNEY_BATI = dict(GUNEY, seed=20261028, auto=[], edge_clamp=True,
                  extra=[(['yosun_kaya_b', 'yosun_kaya_o', 'yosun_kaya_o2', 'yosun_kaya_k2', 'dikenli_kaya'], 6, 140.0, OBJ, 0.5),
                         (['mantar_agac_beyaz_k', 'mantar_agac_mor_k', 'kivrik_bitki_k', 'kuru_dal_agac'], 4, 160.0, DEAD, 0.5)],
                  scatter=[(['egrelti_1', 'egrelti_2', 'egrelti_3', 'fener_cicek_1', 'fener_cicek_2', 'fener_cicek_3'], 8, 120.0, False, DECOR),
                           (['saz_1', 'saz_2', 'saz_3', 'saz_4'], 7, 110.0, False, DECOR),
                           (['yosun_kaya_kk', 'yosun_kaya_k3', 'kutuk_y', 'kafa_cubugu'], 4, 150.0, False, DECOR)])
## madde 385: Batı (BATI) ve Doğu (DOGU) bölgesi kaldırıldı (derin_orman_core.REMOVED) - ayarları geri getirme ihtimaline karşı yukarıda duruyor,
## işlenmiyor; tek kullanılan parçaları zindan kapısı grupları (KEPT_GATES).
ZCFG = {'kuzey': KUZEY, 'kuzey_bati': KUZEY_BATI, 'guney': GUNEY, 'guney_bati': GUNEY_BATI}
## İşleme sırası: kuzey ÖNCE ve eskisi gibi (yerleşimi + Kemik Mahzeni birebir kalsın), sonra kaldırılan bölgelerin kapıları, sonra kuzeybatı
## (kapının çevresini boş bırakır), güney (diğerlerinden uzak, yerleşimi aynı), en son güneybatı (madde 387; güneyin rastgele sırası kaymasın).
RUN_ORDER = ['kuzey', 'kapilar', 'kuzey_bati', 'guney', 'guney_bati']
## Kaldırılan bölgelerin ZİNDAN GİRİŞLERİ (kullanıcı: "silinecek biyomların zindan girişlerine v.b. dokunma"): kapı + yanındaki süsler o
## bölgelerin otomatik yerleşiminin bulduğu eski çapada, aynı karolarla; deep_forest_places.gd'de aynı sıra ve bölge numarası (zindan eşlemesi,
## kapı halesinin rengi, kapıdan yükselen ışık türü aynı). Ayak izinin altındaki çiçek + Çimler lekesi silinir (bölge varken de silikti).
KEPT_GATES = [('bati', (39, 32), BATI), ('dogu', (241, 53), DOGU)]
## 'fill_holes' (2. tur): bölgedeki küçük çimen DELİKLERİ (<= HOLE_MAX hücre; altındaki toprak bölgede yol rengine dönüp köşeli koyu blok ve
## gölcük kesiği yapıyordu) + onlara bakan çimen kenarı karoları tam çimen karosuyla (FULL_GRASS) doldurulur. Uzun yollar (büyük parçalar) kalır.
HOLE_MAX = 20
FULL_GRASS = 135
## 'erase_cim' (2. tur, "ani kesikler"): "Çimler" katmanı aslında leke (spots_lianas) + ot süsü (Yol parçaları) karoları; bölgede bitki rengine
## boyanınca karo karo köşeli bloklar/dikdörtgen ton farkları çıkıyordu -> kuzey/batı/doğu bölge hücrelerinde silinir (zemin süsleri onların yerine).
## Güneyde kalır (zeytin rengi bataklık otu olarak oturuyor).
AUTO_CLEAR = 8   ## otomatik set parçası çevresinde ağaç/süs basılmayan yarıçap (hücre)


def md5(p):
    return hashlib.md5(open(p, 'rb').read()).hexdigest()


def value_noise(x, y, cell, seed):
    def h(i, j):
        v = np.sin(i * 127.1 + j * 311.7 + seed * 74.7) * 43758.5453
        return v - np.floor(v)
    gx, gy = x / cell, y / cell
    ix, iy = np.floor(gx), np.floor(gy)
    fx, fy = gx - ix, gy - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b, c, d = h(ix, iy), h(ix + 1, iy), h(ix, iy + 1), h(ix + 1, iy + 1)
    return float((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy)


class World:
    """Tüm bölgelerin ortak durumu: haritanın katmanları + yeni/eklenen/silinen hücreler."""

    def __init__(self, layers, atlas, firstgid):
        self.L = layers
        self.atlas = atlas
        self.new = {DEAD: {}, OBJ: {}, DECOR: {}, PIT: {}}
        self.add_trees = {k: {} for k in TREE_LAYERS}
        self.erased = set()          ## silinen (değiştirilen) mevcut ağaç hücreleri
        self.erased_at = {k: set() for k in TREE_LAYERS}   ## madde 365: tür dönüşümünde TEK katmanda silinen hücreler (üst üste binen komşu ağaç kalır)
        self.erase_flowers = set()
        self.erase_cim = set()           ## madde 361 2. tur: bölgedeki "Çimler" (leke/ot süsü) karoları
        self.fill_grass = {}             ## madde 361 2. tur: Zemin Çimen'e yazılacak tam çimen (delik + kenar karoları)
        self.erase_other = {}            ## madde 361 2. tur: katman -> bölgede silinen hücreler ('erase_layers')
        self.placed = []
        self.gates = []              ## (bölge, ad, ayak hücresi) - zindan girişleri (scripts/deep_forest_places.gd)
        self.sets = []               ## (bölge, parça, ayak hücresi) - otomatik set parçaları
        self.kept_clear = []         ## madde 385: korunan kapıların çevresi (x, y, w, h) - sonra işlenen bölgeler buraya basmaz
        self.templates = {}          ## bölge -> damga kalıpları ('templates_from' başka bölgeninkini kullanır)
        self.convert_late = set()    ## madde 385: tür dönüşümünde SONA alınan ağaç hücreleri (main: legacy_reach)
        a = np.asarray(Image.open(C.ATLAS_PNG).convert('RGBA'))[..., 3]
        cols = atlas['cols']
        anims = atlas.get('anims', {})
        self.opaque = {}
        for name, (tx, ty, tw, th) in atlas['sprites'].items():
            ## animasyonlu parça: karo, HERHANGİ bir karesinde opaksa konur (ilk karede boş ama sonra alev/fener görünen karolar kesilmesin)
            fr = anims.get(name, {'frames': 1, 'stride': 0})
            self.opaque[name] = [(i, j, firstgid + (ty + j) * cols + (tx + i)) for j in range(th) for i in range(tw)
                                 if any(a[(ty + j + k * fr['stride']) * 16:(ty + j + k * fr['stride'] + 1) * 16, (tx + i) * 16:(tx + i + 1) * 16].max() > 0
                                        for k in range(fr['frames']))]
        self.walls = set(layers['Orman parçaları']) | set(layers['Orman parçaları 2']) | set(layers['Su'])
        ## köprü güvertesi + inişi: üstüne parça konmaz (2. turda bir kızıl bitki batı köprüsünün inişini tıkıyordu), altındaki süs silinmez
        self.bridge = set(layers['Köprü alt']) | set(layers['Köprü üst'])
        self.walls |= self.bridge
        self.near_bridge = {(c[0] + dx, c[1] + dy) for c in self.bridge for dx in range(-2, 3) for dy in range(-2, 3)}
        self.soft = set(layers['Saklanma Çalılığı']) | set(layers['Çalılar']) | set(layers['Çalılar1']) | set(layers['Animasyonsuz çalılar'])
        self.grass = set(layers['Zemin Çimen'])
        self.trees = None            ## madde 365: C.AgacTurleri (main kurar - metin gerekiyor)

    def orig_tree(self, c):
        return c not in self.erased and any(c in self.L[k] and c not in self.erased_at[k] for k in TREE_LAYERS)

    def tree_at(self, c):
        return self.orig_tree(c) or any(c in self.add_trees[k] for k in TREE_LAYERS) or c in self.new[DEAD] or c in self.new[OBJ] or c in self.new[PIT]


class Zone:
    def __init__(self, W, name):
        self.W = W
        self.name = name
        self.cfg = ZCFG[name]
        self.zone = C.zone_cells(W.L, name)
        self.rng = random.Random(self.cfg['seed'])
        self.reserved_rects = list(self.cfg['reserved']) + W.kept_clear
        self.stats = {}

    def blocked(self, c, allow_path=False):
        W = self.W
        if c not in self.zone or c in W.walls or c in W.soft or W.tree_at(c):
            return True
        return not allow_path and c not in W.grass

    def reserved(self, c):
        return any(x <= c[0] < x + w and y <= c[1] < y + h for x, y, w, h in self.reserved_rects)

    def far(self, c, px):
        d2 = (px / 16.0) ** 2
        return all((p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 >= d2 for p in self.W.placed)

    def sprite_cells(self, name, foot):
        tw, th = self.W.atlas['sprites'][name][2], self.W.atlas['sprites'][name][3]
        x0, y0 = foot[0] - tw // 2, foot[1] - th + 1
        return [((x0 + i, y0 + j), gid) for i, j, gid in self.W.opaque[name]], (x0, y0, tw, th)

    def can_put(self, name, foot, layer, allow_path=False, force=False):
        W = self.W
        cells, (x0, y0, tw, th) = self.sprite_cells(name, foot)
        for (c, _g) in cells:
            if c in W.new[layer] or (layer != DECOR and W.tree_at(c)):
                return None
            if force:
                continue
            if c in W.walls or c not in self.zone:
                return None
            ## gövde / taban satırları (alt 2): ağaç, çalı, yol üstüne oturmaz
            if c[1] >= y0 + th - 2 and (c in W.soft or W.tree_at(c) or (not allow_path and c not in W.grass)):
                return None
        return cells

    def put(self, name, foot, layer, allow_path=False, force=False):
        cells = self.can_put(name, foot, layer, allow_path, force)
        if cells is None:
            return False
        for (c, g) in cells:
            self.W.new[layer][c] = g
        self.W.placed.append(foot)
        return True

    def pick(self, kinds):
        r = self.rng.random()
        acc = 0.0
        for name, w in kinds:
            acc += w
            if r < acc:
                return name
        return kinds[-1][0]

    def bases(self, comp):
        s = set(comp)
        cand = sorted(comp, key=lambda c: (0 if (c[0], c[1] + 1) not in s else 1, self.rng.random()))
        res = []
        for c in cand:
            if all((b[0] - c[0]) ** 2 + (b[1] - c[1]) ** 2 >= 3.5 ** 2 for b in res):
                res.append(c)
        return res

    def tree_components(self):
        cells = {c for c in self.zone if self.W.orig_tree(c)}
        reach = self.cfg.get('tree_reach', 0)
        if reach:
            near = {(c[0] + dx, c[1] + dy) for c in self.zone for dx in range(-reach, reach + 1) for dy in range(-reach, reach + 1)}
            cells |= {c for c in near if self.W.orig_tree(c)}
        seen, out = set(), []
        for c in sorted(cells):
            if c in seen:
                continue
            comp, st = [], [c]
            seen.add(c)
            while st:
                p = st.pop()
                comp.append(p)
                for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    q = (p[0] + d[0], p[1] + d[1])
                    if q in cells and q not in seen:
                        seen.add(q)
                        st.append(q)
            out.append(sorted(comp))
        return out

    def templates(self):
        if self.cfg.get('templates_from'):
            return self.W.templates[self.cfg['templates_from']]
        cells = {}
        for k in TREE_LAYERS:
            for c, g in self.W.L[k].items():
                if c not in self.zone and 0 <= c[0] < C.N and 0 <= c[1] < C.N:
                    cells.setdefault(c, []).append((k, g))
        seen = set()
        out = []
        for c in cells:
            if c in seen:
                continue
            comp, st = [], [c]
            seen.add(c)
            while st:
                p = st.pop()
                comp.append(p)
                for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    q = (p[0] + d[0], p[1] + d[1])
                    if q in cells and q not in seen:
                        seen.add(q)
                        st.append(q)
            bx, by = min(p[0] for p in comp), min(p[1] for p in comp)
            if '%d,%d' % (bx, by) in B_PICK:
                bw, bh = max(p[0] for p in comp) - bx + 1, max(p[1] for p in comp) - by + 1
                out.append({'key': '%d,%d' % (bx, by), 'size': (bw, bh),
                            'cells': [((p[0] - bx, p[1] - by), k, g) for p in comp for k, g in cells[p]]})
        out.sort(key=lambda t: t['key'])
        self.W.templates[self.name] = out
        return out

    def clearance(self):
        """Bölge hücresinin en yakın engel/yol/ağaç/bölge dışı hücreye uzaklığı (Chebyshev, BFS)."""
        dist = {}
        q = deque()
        xs = [c[0] for c in self.zone]
        ys = [c[1] for c in self.zone]
        for x in range(min(xs) - 1, max(xs) + 2):
            for y in range(min(ys) - 1, max(ys) + 2):
                if self.blocked((x, y)):
                    dist[(x, y)] = 0
                    q.append((x, y))
        while q:
            c = q.popleft()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (c[0] + dx, c[1] + dy)
                    if n in self.zone and n not in dist:
                        dist[n] = dist[c] + 1
                        q.append(n)
        return dist

    def auto_sets(self):
        placed = 0
        for group in self.cfg['auto']:
            dist = self.clearance()
            cand = sorted((c for c in self.zone if dist.get(c, 0) >= 4 and not self.reserved(c)), key=lambda c: (-dist[c], self.rng.random()))
            for a in cand:
                if not self.far(a, 10 * 16):
                    continue
                ## engel parçaları (çapa + OBJ) zorunlu ve birbiriyle çakışmamalı; düz süsler (DECOR) sığarsa konur
                taken = set()
                ok = True
                for name, (dx, dy), layer in group:
                    if layer == DECOR:
                        continue
                    cells = self.can_put(name, (a[0] + dx, a[1] + dy), layer)
                    if cells is None or any(c in taken for c, _ in cells):
                        ok = False
                        break
                    taken.update(c for c, _ in cells)
                if not ok:
                    continue
                for name, (dx, dy), layer in group:
                    self.put(name, (a[0] + dx, a[1] + dy), layer)
                self.reserved_rects.append((a[0] - AUTO_CLEAR, a[1] - AUTO_CLEAR, AUTO_CLEAR * 2 + 1, AUTO_CLEAR * 2 + 1))
                self.stats.setdefault('set', []).append((group[0][0], a))
                self.W.sets.append((self.name, group[0][0], a))
                if group[0][0] in self.cfg.get('gates', {}):
                    self.W.gates.append((self.name, self.cfg['gates'][group[0][0]], a))
                placed += 1
                break
            else:
                print('UYARI: %s set parçası yer bulamadı: %s' % (self.name, group[0][0]))
        return placed

    def fill_holes(self):
        W = self.W
        g = W.L['Zemin Çimen']
        walls = set(W.L['Orman parçaları']) | set(W.L['Su']) | set(W.L['Orman parçaları 2'])
        holes = {c for c in self.zone if c not in g and c not in walls}
        fill = set()
        seen = set()
        for c in sorted(holes):
            if c in seen:
                continue
            comp, st = [], [c]
            seen.add(c)
            while st:
                p = st.pop()
                comp.append(p)
                for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    q = (p[0] + d[0], p[1] + d[1])
                    if q in holes and q not in seen:
                        seen.add(q)
                        st.append(q)
            if len(comp) <= HOLE_MAX:
                fill.update(comp)
        ## deliğe bakan kenar karoları: tüm komşuları çimen (ya da doldurulan) ise tam karo olur
        ring = set()
        for c in fill:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (c[0] + dx, c[1] + dy)
                    if n in g and g[n] != FULL_GRASS and n in self.zone and n not in walls:
                        if all(((n[0] + a, n[1] + b) in g or (n[0] + a, n[1] + b) in fill) for a in (-1, 0, 1) for b in (-1, 0, 1)):
                            ring.add(n)
        for c in fill | ring:
            W.fill_grass[c] = FULL_GRASS
        W.grass.update(fill)
        self.stats['delik'] = (len(fill), len(ring))

    def run(self):
        W, cfg = self.W, self.cfg
        if cfg.get('fill_holes'):
            self.fill_holes()
        for name, foot, layer in cfg['fixed']:
            if not self.put(name, foot, layer, allow_path=True, force=True):
                print('UYARI: set parçası sığmadı', name, foot)
        self.auto_sets()
        zl = sorted(self.zone)
        if cfg['mode'] == 'stamp':
            temps = self.templates()
            cells = []
            for _ in range(4):
                once = list(zl)
                self.rng.shuffle(once)
                cells += once
            stamped = dead = 0
            for c in cells:
                t = temps[self.rng.randrange(len(temps))]
                sw, sh = t['size']
                if value_noise(c[0] + sw * 0.5, c[1] + sh * 0.5, 20.0, 7) < cfg['noise_thr']:
                    continue
                ok = True
                for (d, _k, _g) in t['cells']:
                    q = (c[0] + d[0], c[1] + d[1])
                    if self.blocked(q) or self.reserved(q):
                        ok = False
                        break
                if not ok:
                    continue
                comp = sorted({(c[0] + d[0], c[1] + d[1]) for (d, _k, _g) in t['cells']})
                if self.rng.random() < cfg['dead_ratio']:
                    for b in self.bases(comp):
                        self.put(self.pick(cfg['tree_kinds']), b, DEAD)
                    dead += 1
                    continue
                for (d, k, g) in t['cells']:
                    W.add_trees[k][(c[0] + d[0], c[1] + d[1])] = g
                stamped += 1
                self.base_deco(comp)
            self.stats['kume'] = stamped
            self.stats['olu_oebek'] = dead
        else:
            changed = kept = 0
            for comp in self.tree_components():
                if self.rng.random() >= cfg['replace_p'] or any(self.reserved(c) for c in comp):
                    kept += 1
                    continue
                W.erased.update(comp)
                n = 0
                for b in self.bases(comp):
                    for kind in [self.pick(cfg['tree_kinds'])] + cfg.get('tree_fallback', []):
                        if self.put(kind, b, DEAD):
                            n += 1
                            break
                if n == 0 and not cfg.get('erase_all'):
                    W.erased.difference_update(comp)
                    kept += 1
                    continue
                changed += 1
                self.base_deco(comp)
            self.stats['degisen_agac'] = changed
            self.stats['kalan_agac'] = kept
            for kinds, count, px, layer, thr in cfg.get('extra', []):
                n = 0
                once = list(zl)
                self.rng.shuffle(once)
                for c in once:
                    if n >= count:
                        break
                    if value_noise(c[0], c[1], 14.0, self.cfg['seed'] % 97) < thr:
                        continue
                    if self.blocked(c) or self.reserved(c) or not self.far(c, px) or not self.clumped(c):
                        continue
                    if self.put(kinds[self.rng.randrange(len(kinds))], c, layer):
                        n += 1
                self.stats.setdefault('ek', []).append(n)
        for kinds, count, px, allow_path, layer in cfg['scatter']:
            n = 0
            once = list(zl)
            self.rng.shuffle(once)
            for c in once:
                if n >= count:
                    break
                if self.blocked(c, allow_path) or self.reserved(c) or not self.far(c, px) or not self.clumped(c):
                    continue
                if self.put(kinds[self.rng.randrange(len(kinds))], c, layer, allow_path):
                    n += 1
        W.erase_flowers.update(c for c in W.L['Çiçekler 1'] if c in self.zone)
        if cfg.get('erase_cim'):
            W.erase_cim.update(c for c in W.L['Çimler'] if c in self.zone)
        for lname in cfg.get('erase_layers', []):
            W.erase_other.setdefault(lname, set()).update(c for c in W.L[lname] if c in self.zone and c not in W.near_bridge)
        return self.stats

    def convert_trees(self):
        """Madde 365: bölgede kalan haritanın kendi ağaçlarından (+ kuzeyin damgaladığı kümelerden) türü 'agac_kalir'da olmayanlar silinir,
        ayak hücresine bölgenin ağacı konur (sığmazsa küçükleri, hiçbiri sığmazsa sadece silinir). TÜM bölgelerin run()'ından SONRA ve kendi
        rastgelesiyle (main): set parçaları / zindan kapıları / süsler ve diğer bölgelerin yerleşimi madde 364'teki yerinde kalır."""
        W, cfg = self.W, self.cfg
        rng = random.Random(cfg['seed'] * 7 + 365)
        clamp = cfg.get('edge_clamp')

        def inz(c):
            if clamp:
                c = (min(max(c[0], 0), C.N - 1), min(max(c[1], 0), C.N - 1))
            return c in self.zone
        found = []
        for k in TREE_LAYERS:
            cur = {c: g for c, g in W.L[k].items() if c not in W.erased and c not in W.erased_at[k]}
            for src, cells in ((False, cur), (True, W.add_trees[k])):
                for tur, key, comp in W.trees.instances(cells):
                    if tur is None or tur in cfg['agac_kalir'] or 2 * sum(1 for c in comp if inz(c)) < len(comp):
                        continue
                    bottom = max(c[1] for c in comp)
                    row = [c[0] for c in comp if c[1] == bottom]
                    found.append(((round(sum(row) / len(row)), bottom), k, src, tur, comp))
        late = W.convert_late if cfg.get('convert_late') else set()
        found.sort(key=lambda e: (any(c in late for c in e[4]), e[0][1], e[0][0]))
        changed = erased = 0
        kinds_by = Counter()
        for foot, k, stamped, tur, comp in found:
            for c in comp:
                if stamped:
                    W.add_trees[k].pop(c, None)
                else:
                    W.erased_at[k].add(c)
            kinds_by[tur] += 1
            ## eski ağacın tabanı: çimen olmayabilir (Güney'in deniz kıyısı palmiyeleri kumda/bölgenin çamur yolunda) -> yol tabanına izin
            for kind in [self.pick_with(rng, cfg['tree_kinds'])] + cfg.get('tree_fallback', []):
                if self.put(kind, foot, DEAD, allow_path=True):
                    changed += 1
                    break
            else:
                erased += 1
        self.stats['tur_donusum'] = (changed, erased, dict(kinds_by))

    @staticmethod
    def pick_with(rng, kinds):
        r = rng.random()
        acc = 0.0
        for name, w in kinds:
            acc += w
            if r < acc:
                return name
        return kinds[-1][0]

    def clumped(self, c):
        """Madde 361: saçılan süsler gürültü öbeklerinde toplanır (aralarda boş zemin kalır)."""
        return value_noise(c[0], c[1], 18.0, self.cfg['seed'] % 89 + 11) >= self.cfg.get('clump', 0.0)

    def base_deco(self, comp):
        for b in self.bases(comp):
            if self.rng.random() < self.cfg['base_deco_p']:
                m = (b[0] + self.rng.randint(-1, 1), b[1] + 1)
                if not self.blocked(m) and not self.reserved(m):
                    self.put(self.cfg['base_deco'][self.rng.randrange(len(self.cfg['base_deco']))], m, DECOR)


def place_kept_gates(W):
    """Madde 385: KEPT_GATES - kaldırılan bölgenin kapı grubu eski çapasında, bölge/çimen kuralı olmadan (hepsi eskiden de sığmıştı)."""
    for zname, anchor, cfg in KEPT_GATES:
        group = cfg['auto'][0]
        cells_all = []
        for name, (dx, dy), layer in group:
            tw, th = W.atlas['sprites'][name][2], W.atlas['sprites'][name][3]
            foot = (anchor[0] + dx, anchor[1] + dy)
            x0, y0 = foot[0] - tw // 2, foot[1] - th + 1
            for i, j, g in W.opaque[name]:
                c = (x0 + i, y0 + j)
                assert c not in W.new[layer] and (layer == DECOR or not W.tree_at(c)), ('korunan kapı parçası dolu hücreye', name, c)
                W.new[layer][c] = g
                cells_all.append(c)
            W.placed.append(foot)
        W.sets.append((zname, group[0][0], anchor))
        W.gates.append((zname, cfg['gates'][group[0][0]], anchor))
        W.erase_flowers.update(c for c in cells_all if c in W.L['Çiçekler 1'])
        W.erase_cim.update(c for c in cells_all if c in W.L['Çimler'])
        W.kept_clear.append((anchor[0] - AUTO_CLEAR, anchor[1] - AUTO_CLEAR, AUTO_CLEAR * 2 + 1, AUTO_CLEAR * 2 + 1))
        print('korunan kapı: %s %s %s (%d hücre)' % (zname, cfg['gates'][group[0][0]], anchor, len(cells_all)))


def legacy_reach(W):
    """Madde 385: eski Batı bölgesinin (tree_reach) sildiği ağaç hücreleri. Artık silinmiyorlar; kuzey/kuzeybatı onları da dönüştürür, kuzey
    SONA alır (convert_late) - yoksa kuzeyin tür dönüşümü sırası kayar ve doğusundaki ölü ağaçların türü değişir."""
    z = C.zone_cells(W.L, 'bati', removed_too=True)
    r = BATI['tree_reach']
    near = {(c[0] + dx, c[1] + dy) for c in z for dx in range(-r, r + 1) for dy in range(-r, r + 1)}
    return {c for c in near if W.orig_tree(c)}


def zone_channel(name):
    """Bölge adı -> maske kanalı numarası (derin_orman_core.ZONE_ORDER; kuzey_bati kuzeyin kanalında)."""
    for ch, parts in C.MASK_PARTS.items():
        if name in parts:
            return C.ZONE_ORDER.index(ch)
    return C.ZONE_ORDER.index(name)


def preview(W, zones, path):
    K = 3
    im = Image.new('RGB', (C.N * K, C.N * K), (150, 120, 80))
    d = ImageDraw.Draw(im)

    def paint(cells, col):
        for (x, y) in cells:
            if 0 <= x < C.N and 0 <= y < C.N:
                d.rectangle([x * K, y * K, (x + 1) * K - 1, (y + 1) * K - 1], fill=col)
    paint(W.grass, (104, 150, 78))
    for z in zones:
        paint(z.zone, [(60, 100, 70), (120, 80, 80), (80, 100, 130), (120, 140, 70)][zone_channel(z.name)])
    paint(W.L['Su'], (64, 104, 168))
    paint(W.L['Orman parçaları 2'], (190, 200, 110))
    paint(W.L['Orman parçaları'], (40, 62, 36))
    for k in TREE_LAYERS:
        paint({c for c in W.L[k] if c not in W.erased and c not in W.erased_at[k]}, (25, 90, 35))
        paint(W.add_trees[k], (10, 50, 40))
    paint(W.new[DEAD], (30, 20, 25))
    paint(W.new[OBJ], (230, 220, 200))
    paint(W.new[DECOR], (200, 120, 200))
    paint(W.new[PIT], (255, 40, 40))
    im.save(path)


def layer_span(text, name):
    m = re.search(r'\n  <layer id="\d+" name="%s"[^>]*>\n   <data encoding="csv">\n(.*?)\n   </data>\n  </layer>' % re.escape(name), text, re.S)
    assert m, 'katman yok: ' + name
    return m


def parse_chunks(body):
    chunks = {}
    for cm in re.finditer(r'<chunk x="(-?\d+)" y="(-?\d+)" width="16" height="16">\s*(.*?)\s*</chunk>', body, re.S):
        vals = np.array([int(v) for v in cm.group(3).replace('\n', '').split(',') if v.strip()], np.int64).reshape(16, 16)
        chunks[(int(cm.group(1)), int(cm.group(2)))] = vals
    return chunks


def write_chunks(chunks):
    parts = []
    for (cx, cy) in sorted(chunks, key=lambda k: (k[1], k[0])):
        rows = [','.join(str(int(v)) for v in r) for r in chunks[(cx, cy)]]
        parts.append('    <chunk x="%d" y="%d" width="16" height="16">\n%s\n</chunk>' % (cx, cy, ',\n'.join(rows)))
    return '\n'.join(parts)


def set_cells(chunks, cells, erase=False):
    for (x, y), g in cells.items():
        cx, cy = (x // 16) * 16, (y // 16) * 16
        if (cx, cy) not in chunks:
            chunks[(cx, cy)] = np.zeros((16, 16), np.int64)
        if not erase:
            assert chunks[(cx, cy)][y - cy, x - cx] == 0, ('dolu hücreye yazılıyordu', x, y)
        chunks[(cx, cy)][y - cy, x - cx] = 0 if erase else g


def build(text, W, firstgid):
    assert '\r' not in text
    for name in TREE_LAYERS:
        m = layer_span(text, name)
        ch = parse_chunks(m.group(1))
        set_cells(ch, {c: 0 for c in W.erased | W.erased_at[name] if c in W.L[name]}, erase=True)
        set_cells(ch, W.add_trees[name])
        text = text[:m.start(1)] + write_chunks(ch) + text[m.end(1):]
    m = layer_span(text, 'Zemin Çimen')
    ch = parse_chunks(m.group(1))
    for (x, y), gid in W.fill_grass.items():
        cx, cy = (x // 16) * 16, (y // 16) * 16
        if (cx, cy) not in ch:
            ch[(cx, cy)] = np.zeros((16, 16), np.int64)
        ch[(cx, cy)][y - cy, x - cx] = gid
    text = text[:m.start(1)] + write_chunks(ch) + text[m.end(1):]
    for lname, cells in [('Çiçekler 1', W.erase_flowers), ('Çimler', W.erase_cim)] + sorted(W.erase_other.items()):
        m = layer_span(text, lname)
        ch = parse_chunks(m.group(1))
        set_cells(ch, {c: 0 for c in cells}, erase=True)
        text = text[:m.start(1)] + write_chunks(ch) + text[m.end(1):]
    nid = int(re.search(r'nextlayerid="(\d+)"', text).group(1))

    def block(lid, name, cells):
        ch = {}
        set_cells(ch, cells)
        return '\n  <layer id="%d" name="%s" width="320" height="296">\n   <data encoding="csv">\n%s\n   </data>\n  </layer>' % (lid, name, write_chunks(ch))
    m0 = layer_span(text, 'Ağaç 0')
    text = text[:m0.start()] + block(nid, DECOR, W.new[DECOR]) + block(nid + 3, PIT, W.new[PIT]) + text[m0.start():]
    m2 = layer_span(text, 'Ağaç 2')
    text = text[:m2.end()] + block(nid + 1, DEAD, W.new[DEAD]) + block(nid + 2, OBJ, W.new[OBJ]) + text[m2.end():]
    text = re.sub(r'nextlayerid="\d+"', 'nextlayerid="%d"' % (nid + 4), text, count=1)
    if 'source="Derin orman.tsx"' not in text:
        last = list(re.finditer(r'\n <tileset firstgid="\d+" source="[^"]+"/>', text))[-1]
        text = text[:last.end()] + '\n <tileset firstgid="%d" source="Derin orman.tsx"/>' % firstgid + text[last.end():]
    return text


## ---------------- BÖLGE ZEMİNİ GERÇEK KAROLAR (madde 363) ----------------
ZEMIN_INPLACE = [('Su ayrıntılar 2', 'su'), ('Orman parçaları 2', 'plato'), ('Orman parçaları', 'yesil'), ('orman parçaları -1', 'yesil'),
                 ('Orman parçaları 3', 'yesil'), ('Orman parçaları 4', 'yesil')]


def apply_zemin(text, firstgid, mask_out):
    """Bölge maskesini yazar, bölge zeminini karolara pişirir (zemin_karolari.py) ve metne ekler: Yer/Derin orman zemini katmanı (Zemin Çimen'in
    üstü), yerinde değiştirilen kıyı/plato/uçurum karoları, pişmiş hücrelerdeki Çimler düz çimen karolarının silinmesi, "Derin orman zemin.tsx"."""
    import zemin_karolari as Z
    import gen_bolge_maskesi as GM
    import gen_zemin_dokusu as GZ
    layers = C.tmx_layers(text)
    mask = GM.build_mask(layers)
    mask.save(mask_out)
    if not os.path.exists(GZ.OUT):
        GZ.main()
    field = Z.Field(mask, Image.open(GZ.OUT))
    ts = Z.Tilesets(text)
    bk = Z.Baker(field, ts)
    grass, dirt = layers['Zemin Çimen'], layers['Zemin Toprak']
    cands = Z.candidate_cells(field, set(grass) | set(dirt))
    over = bk.overlay(cands, grass, dirt, C.keep_dirt_cells(layers))
    cand_set = set(cands)
    inplace = {}
    for lname, mode in ZEMIN_INPLACE:
        sub = {c: g for c, g in layers[lname].items() if c in cand_set}
        inplace[lname] = bk.inplace(sub, mode)
    cim_erase = set()
    for c in over:
        g = layers['Çimler'].get(c)
        if g:
            fr = ts.frames(g)
            if fr and Z.is_flat_grass(fr[0][0]):
                cim_erase.add(c)
    usage = [(c, key) for cells in list(inplace.values()) + [over] for c, key in cells.items()]
    ids, parts, region_of = bk.write_atlas(usage)
    count = sum(p[2] for p in parts)

    def gid_of(c, key):
        return firstgid + ids[(region_of[(c[0] // 16, c[1] // 16)], key)]
    used = len({(region_of[(c[0] // 16, c[1] // 16)], key) for c, key in usage})
    print('zemin karoları: aday hücre %d | katman %d | yerinde %s | Çimler silinen %d | karo %d (tek %d + animasyon %d) | %d parça, parçalardaki karo %d (tekil %d, kopya payı %.0f%%)' % (
        len(cands), len(over), {k: len(v) for k, v in inplace.items()}, len(cim_erase), count, len(bk.static_list),
        len(bk.anim_list), len(parts), used, len(bk.static_list) + len(bk.anim_list), 100.0 * (used / max(1, len(bk.static_list) + len(bk.anim_list)) - 1.0)))
    for lname, cells in inplace.items():
        if not cells:
            continue
        m = layer_span(text, lname)
        ch = parse_chunks(m.group(1))
        for (x, y), key in cells.items():
            cx, cy = (x // 16) * 16, (y // 16) * 16
            ch[(cx, cy)][y - cy, x - cx] = gid_of((x, y), key)
        text = text[:m.start(1)] + write_chunks(ch) + text[m.end(1):]
    m = layer_span(text, 'Çimler')
    ch = parse_chunks(m.group(1))
    set_cells(ch, {c: 0 for c in cim_erase}, erase=True)
    text = text[:m.start(1)] + write_chunks(ch) + text[m.end(1):]
    nid = int(re.search(r'nextlayerid="(\d+)"', text).group(1))
    och = {}
    set_cells(och, {c: gid_of(c, k) for c, k in over.items()})
    block = '\n  <layer id="%d" name="%s" width="320" height="296">\n   <data encoding="csv">\n%s\n   </data>\n  </layer>' % (
        nid, Z.OVERLAY, write_chunks(och))
    mz = layer_span(text, 'Zemin Çimen')
    text = text[:mz.end()] + block + text[mz.end():]
    text = re.sub(r'nextlayerid="\d+"', 'nextlayerid="%d"' % (nid + 1), text, count=1)
    last = list(re.finditer(r'\n <tileset firstgid="\d+" source="[^"]+"/>', text))[-1]
    text = text[:last.end()] + ''.join('\n <tileset firstgid="%d" source="%s"/>' % (firstgid + base, name) for name, base, _n in parts) + text[last.end():]
    return text


def write_places(W, path=PLACES_GD):
    """scripts/deep_forest_places.gd: zindan girişleri + set parçaları (oyunda yakınlık bildirimi, testler). ÜRETİLEN dosya - elle düzenleme."""
    gates = ',\n'.join('\t{"zone": %d, "name": "%s", "cell": Vector2i(%d, %d)}' % (zone_channel(z), n, c[0], c[1]) for z, n, c in W.gates)
    sets = ',\n'.join('\t{"zone": %d, "piece": "%s", "cell": Vector2i(%d, %d)}' % (zone_channel(z), n, c[0], c[1]) for z, n, c in W.sets)
    src = ('extends RefCounted\n\n'
           '## ÜRETİLDİ: tools/derin_orman/place_derin_orman.py --apply (madde 361) - elle düzenleme, betiği yeniden koş.\n'
           '## Derin orman bölgelerinin zindan girişleri ve set parçaları: hücre = parçanın AYAK hücresi (Harita.tmx), bölge = maske kanalı\n'
           '## (0 Kuzey, 1 Batı, 2 Doğu, 3 Güney).\n\n'
           'const GATES: Array[Dictionary] = [\n%s,\n]\n\nconst SETS: Array[Dictionary] = [\n%s,\n]\n') % (gates, sets)
    open(path, 'w', encoding='utf-8', newline='\n').write(src)


def main():
    os.makedirs(OUT, exist_ok=True)
    live = open(C.TMX, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in live else '\n'   ## Tiled CRLF yazıyor; işlem LF ile, yazarken geri
    live = live.replace('\r\n', '\n')
    base_text = live
    out_dir = sys.argv[2] if len(sys.argv) >= 3 and sys.argv[1] == '--out' else None
    if out_dir:
        ## doğrulama: hep YEDEKTEN kurar, çıktıların hepsi (TMX, maske, zemin atlası, places) bu klasöre - canlı dosyalara dokunmaz
        base_text = open(YEDEK, encoding='utf-8', newline='').read().replace('\r\n', '\n')
    elif 'name="%s"' % DEAD in live:
        if os.path.exists(STAMP) and open(STAMP).read().strip() == md5(C.TMX) and os.path.exists(YEDEK):
            print('Derin orman katmanları zaten var ve TMX son yazımımızla aynı -> yedekten yeniden kuruluyor')
            base_text = open(YEDEK, encoding='utf-8', newline='').read().replace('\r\n', '\n')
        else:
            print('DURDU: Harita.tmx\'te derin orman katmanları var ve TMX son yazımdan beri değişmiş (Tiled?). Elle karar ver.')
            sys.exit(2)
    atlas = json.load(open(C.ATLAS_JSON, encoding='utf-8'))
    ts = C.tilesets(base_text)
    last_gid, last_src = ts[-1]
    m = re.search(r'tilecount="(\d+)"', open(os.path.join(C.PROJECT, 'harita', last_src), encoding='utf-8').read())
    firstgid = last_gid + int(m.group(1))
    layers = C.tmx_layers(base_text)
    W = World(layers, atlas, firstgid)
    W.trees = C.AgacTurleri(base_text)
    W.convert_late = legacy_reach(W)
    zones = []
    for name in RUN_ORDER:
        if name == 'kapilar':
            place_kept_gates(W)
            continue
        z = Zone(W, name)
        st = z.run()
        zones.append(z)
        print('%s: hücre %d | %s' % (name, len(z.zone), st))
    for z in zones:
        if 'agac_kalir' in z.cfg:
            z.convert_trees()
            print('%s tür dönüşümü (değişen, sadece silinen, tür):' % z.name, z.stats['tur_donusum'])
    print('katmanlar:', {k: len(v) for k, v in W.new.items()}, '| eklenen ağaç hücresi', sum(len(v) for v in W.add_trees.values()),
          '| silinen ağaç hücresi', len(W.erased), '| silinen çiçek', len(W.erase_flowers), '| silinen Çimler', len(W.erase_cim), '| firstgid', firstgid)
    preview(W, zones, os.path.join(OUT, 'onizleme.png'))
    if len(sys.argv) >= 3 and sys.argv[1] == '--apply':
        have = md5(C.TMX)
        if have != sys.argv[2]:
            print('DURDU: Harita.tmx md5 değişmiş (%s), Tiled\'dan kaydedilmiş olabilir' % have)
            sys.exit(2)
        built = build(base_text, W, firstgid)
        atlas_count = json.load(open(C.ATLAS_JSON, encoding='utf-8'))['tilecount']
        import gen_bolge_maskesi as GM
        res = apply_zemin(built, firstgid + atlas_count, GM.OUT).replace('\n', nl)
        if not os.path.exists(YEDEK):
            shutil.copy2(C.TMX, YEDEK)
        tmp = C.TMX + '.tmp'
        open(tmp, 'w', encoding='utf-8', newline='').write(res)
        os.replace(tmp, C.TMX)
        open(STAMP, 'w').write(md5(C.TMX))
        write_places(W)
        print('YAZILDI | yeni md5', md5(C.TMX))
    elif out_dir:
        import zemin_karolari as Z
        os.makedirs(out_dir, exist_ok=True)
        Z.ATLAS_DIR = out_dir
        built = build(base_text, W, firstgid)
        atlas_count = json.load(open(C.ATLAS_JSON, encoding='utf-8'))['tilecount']
        res = apply_zemin(built, firstgid + atlas_count, os.path.join(out_dir, 'derin_orman_bolge.png')).replace('\n', nl)
        open(os.path.join(out_dir, 'Harita.tmx'), 'w', encoding='utf-8', newline='').write(res)
        write_places(W, os.path.join(out_dir, 'deep_forest_places.gd'))
        print('DOĞRULAMA ÇIKTISI ->', out_dir)
    else:
        print('kuru çalışma | şu anki md5', md5(C.TMX))


if __name__ == '__main__':
    main()
