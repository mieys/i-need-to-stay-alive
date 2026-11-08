# BATIK NEKROPOL (harita seçimi, 3 yeni haritanın 1.si, madde 449): "Zindan Tileseti (Roguelike)" (Dungeon3) + "Zindan Eşyaları" ağları.
# 214x214 (ana haritanın alanının %70'i). Rastgele oda saçma YOK: elle tasarlanmış şehir planı, her semtin kendi biçim dili:
#   orta  BATIK SARNIÇ   - su basmış dev salon, çapraz geçitler, ortadaki adada Kemik Sunağı (ruh alevli heykel)
#   halka HALKA CADDE    - sarnıcın çevresinde 7 hücrelik cadde, semtleri bağlar
#   K     ÖLÜLER KATEDRALİ - sütun dizili nef, apsis (elit sandık), dört yan şapel (dikenli kapılar)
#   KB/KD MOZOLE AVLULARI - serbest duran mozoleler (yüzünde kemer + meşale), mezar sıraları; KD'de su birikintileri
#   B     LAHİT GALERİLERİ - beş uzun galeri yılan gibi bağlı, duvar dibinde dikili lahitler, açık lahitler = saklanma
#   D     KEMİK OCAĞI    - sık kemik odaları kümesi (örnek haritadaki gibi), kemik yığınları, kafatası nişleri, ejder başları
# Yapı dili örnek haritadan (Dungeon3.tmx): yüzlerde paye + kemer/kapı/pencere ritmi (`facade`), yükseltilmiş platform + merdiven
# (walls_floor 1..3 x 7..10 + stairs 1..3 x 1..2: apsis, sunak kürsüsü, doğuş kürsüsü), su kıyısı kiti (örnekten öğrenilir, ornek_su.py). Zemin: kum + C taş derzi shader'ı (levha/plaka yok).
#   GB    BEKÇİ KIŞLASI  - koridor + koğuşlar, avcının ini, sandıklar
#   G     GİRİŞ SALONU   - doğuş: yüzündeki merdivenden inilir
#   GD    EJDER MAHZENİ  - sütun ormanı (dörtgen paye blokları), payelerin yüzünde ruh ateşi püskürten ejder başları (tuzak)
# Etkileşimler Kemik Mahzeni'ninki (tema 'kemik'): parmaklık/diken kapı, diken tuzak, Ruh Kandili, Kemik Sunağı, sandık, açık lahit,
# Mahzen Bekçisi + bu haritaya özgü EJDER BAŞI (tuzak tur 'ejder': yüzdeki ejder başı aşağıya 2x4 ruh ateşi, dungeon_props STYLE "ejder").
# Çalıştır: python tools/zindan/gen_batik_nekropol.py [--write]  (önizleme tools/zindan/out/batik_nekropol_*.png)
#   sonra: Godot --headless --path . --import ; Godot --headless --path . -s res://tools/zindan/bake_zindan.gd -- batik_nekropol
import math
import os
import random
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zindan_core as Z  # noqa: E402
import zindan_paint as P  # noqa: E402
import gen_kemik_mahzeni as KM  # noqa: E402
import gen_kadim_derinlikler as KD  # noqa: E402  (hızlı bağlılık denetimi + WF_TUCK köşe kuralı)
import ornek_su  # noqa: E402  (örnekten öğrenilen su kıyısı tablosu)

ID = 'batik_nekropol'
TITLE = 'Batık Nekropol'
W = H = 214
SEED = 6101
RL = KM.RL
ZE = KM.ZE
SAMPLE = KM.SAMPLE
TEMA = 'kemik'

# ince ayar 2 (2026-11-08): KM.URNS'un son ikisi aslında ANAHTAR (yerde katı süs + toplanır sanılıyordu) -> yalnız iki gri küp
URNS = KM.URNS[:2]
ORDER = ['Su', 'Su altı', 'Su ayrıntı', 'Su ayrıntı 2', 'Zemin', 'Zemin ayrıntı', 'Zemin desen', 'Zemin süsü', 'Yer süsü', 'Duvar', 'Duvar süsü', 'Eşya alt', 'Eşya',
         'Eşya üst', 'Engel']

# su (Water_coasts_animation): gövde (1, 30) animasyonlu; kıyı zemini 3x3 ada bloğu (1..3, 6..8) + yüzün suya taşan alt yarısı (1..3, 9);
# iç köşeler (yalnız çaprazda su): GD (5, 5), GB (7, 5), KD (5, 9), KB (7, 9)
WATER_BODY = (1, 30)
SUNKEN = (5, 6, 7, 8, 9, 10, 11, 12, 13)   # su altı tuğla/çatlak izleri (Water_coasts 30. satır, saydam; 2..4 = yüz altı batık duvar)
INNER = {(1, 1): (5, 5), (-1, 1): (7, 5), (1, -1): (5, 9), (-1, -1): (7, 9)}
# su dalgacık öbekleri (water_details_animation, örnekteki gibi su üstünde süzülen açık lekeler): (sütun, satır, en, boy)
RIPPLES = [(1, 1, 15, 3), (17, 1, 12, 3), (1, 5, 12, 3), (16, 5, 13, 3), (17, 8, 8, 2), (1, 9, 13, 2), (32, 1, 4, 2), (26, 8, 5, 2)]
DRAGON_SHEET = 'dragon_trap.png'
LIGHT_GAIN = 1.3    # ışık nesnelerinin gücü (ince ayar: harita çok karanlıktı; ortam da map_profiles'ta açıldı)
LIGHT_REACH = 1.1


def make_bank():
    bank = Z.TilesetBank(ID)
    bank.add('wf', os.path.join(RL, 'walls_floor.png'))
    bank.add('cof', os.path.join(RL, 'coffins.png'))
    bank.add('obj', os.path.join(RL, 'other_objects.png'))
    bank.add('st', os.path.join(RL, 'stairs.png'))
    bank.add('cdl', os.path.join(RL, 'candles.png'), anims=Z.sample_anims(SAMPLE, 'candles'))
    bank.add('tor', os.path.join(RL, 'torches.png'), anims=Z.sample_anims(SAMPLE, 'torches'))
    bank.add('sta', os.path.join(RL, 'Statue_fire.png'), anims=Z.sample_anims(SAMPLE, 'Statue_fire'))
    bank.add('rel', os.path.join(RL, 'scull_bas-relief.png'), anims=Z.sample_anims(SAMPLE, 'scull_bas-relief'))
    bank.add('arc', os.path.join(RL, 'Arches_columns.png'))
    bank.add('wc', os.path.join(RL, 'Water_coasts_animation.png'), name='su_kiyi.png',
             anims=Z.sample_anims(SAMPLE, 'Water_coasts_animation'))
    bank.add('wd', os.path.join(RL, 'water_details_animation.png'), name='su_dalga.png',
             anims=Z.sample_anims(SAMPLE, 'Water_detilazation'))
    bank.add('web', os.path.join(ZE, 'web.png'), name='web_eslik.png')
    bank.add('eng', 'engel', name='engel.png', img=Z.make_marker_sheet())
    return bank


# ================================================================================================ yerleşim
class Plan:
    """Elle tasarlanmış yerleşim: odalar (oda kimliği + tür + ad), koridorlar (koridor kimliği), duvar blokları, su."""

    def __init__(self):
        self.lay = Z.Layout(W, H, SEED)
        self.eid = 0
        self.named = {}      # ad -> Room
        self.blocks = []     # (x, y, w, h, tür) serbest duran duvar blokları (mozole, paye)
        self.pools = []      # (x, y, w, h)

    def room(self, name, x, y, w, h, kind='oda'):
        r = self.lay.add_room(x, y, w, h, kind)
        r.name = name
        self.lay.carve_rect(x, y, w, h, Z.F, r.id)
        self.named[name] = r
        return r

    def corr(self, x, y, w, h):
        self.lay.carve_rect(x, y, w, h, Z.F)
        x0, y0, x1, y1 = max(1, x), max(1, y), min(W - 1, x + w), min(H - 1, y + h)
        sub = self.lay.corr_id[y0:y1, x0:x1]
        free = self.lay.room_id[y0:y1, x0:x1] < 0
        sub[free] = self.eid
        self.eid += 1

    def block(self, x, y, w, h, kind='mozole'):
        lay = self.lay
        lay.t[y:y + h, x:x + w] = Z.S
        lay.room_id[y:y + h, x:x + w] = -1
        self.blocks.append((x, y, w, h, kind))

    def water(self, x, y, w, h):
        sub = self.lay.t[y:y + h, x:x + w]
        sub[sub == Z.F] = Z.W
        self.pools.append((x, y, w, h))

    def blob(self, name, x, y, w, h, kind, rough=0.3):
        r = self.lay.add_room(x, y, w, h, kind)
        r.name = name
        rng = self.lay.rng
        cx, cy = x + w / 2.0, y + h / 2.0
        noise = P.value_noise(w + 2, h + 2, SEED + r.id * 31, cell=5.0)
        cells = []
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                dx, dy = (xx + 0.5 - cx) / (w / 2.0), (yy + 0.5 - cy) / (h / 2.0)
                d = math.hypot(dx, dy) + (noise[yy - y + 1, xx - x + 1] - 0.5) * rough * 2
                if d < 0.92:
                    self.lay.t[yy, xx] = Z.F
                    self.lay.room_id[yy, xx] = r.id
                    cells.append((xx, yy))
        r.cells = cells
        self.named[name] = r
        _ = rng
        return r


def build_layout():
    pl = Plan()
    R, C = pl.room, pl.corr

    # ---- HALKA CADDE (sarnıcın çevresi) + sarnıç salonu
    C(64, 64, 88, 7)      # kuzey kol  x64..151 y64..70
    C(64, 146, 88, 7)     # güney kol  y146..152
    C(64, 64, 7, 89)      # batı kol   x64..70
    C(145, 64, 7, 89)     # doğu kol   x145..151
    R('Batık Sarnıç', 75, 75, 66, 67, 'kalp')            # x75..140 y75..141
    C(104, 71, 7, 4)
    C(104, 142, 7, 4)
    C(71, 105, 4, 7)
    C(141, 105, 4, 7)
    # su: kenar yürüyüşü + çapraz geçit (7) + ada (23x23) dışı
    lay = pl.lay
    pool = (81, 83, 54, 53)                               # x81..134 y83..135
    keep = np.zeros((H, W), bool)
    keep[83:136, 104:111] = True                          # dikey geçit
    keep[105:112, 81:135] = True                          # yatay geçit
    keep[97:120, 96:119] = True                           # ada
    for (qx, qy, qw, qh) in ((81, 83, 9, 7), (126, 83, 9, 7), (81, 129, 9, 7), (126, 129, 9, 7)):
        keep[qy:qy + qh, qx:qx + qw] = True               # köşe iskeleleri (kenar yürüyüşüne bağlı; mumlu lahit setleri)
    x0, y0, pw, ph = pool
    for y in range(y0, y0 + ph):
        for x in range(x0, x0 + pw):
            if not keep[y, x] and lay.t[y, x] == Z.F:
                lay.t[y, x] = Z.W
    pl.pools.append(pool)

    # ---- K: ÖLÜLER KATEDRALİ
    R('Katedral Nefi', 74, 24, 66, 36, 'sutun')          # x74..139 y24..59
    R('Apsis', 94, 10, 26, 14, 'kalp')                   # x94..119 y10..23
    C(104, 60, 7, 4)                                      # nef -> halka
    for (nm, x, y) in (('Batı Şapeli', 62, 30), ('Kuzeybatı Şapeli', 62, 46), ('Doğu Şapeli', 142, 30), ('Kuzeydoğu Şapeli', 142, 46)):
        R(nm, x, y, 10, 9, 'lahit')
    C(72, 33, 2, 3)        # şapel kapıları (3 satır: yatay diken kapı)
    C(72, 49, 2, 3)
    C(140, 33, 2, 3)
    C(140, 49, 2, 3)

    # ---- KB: MOZOLE AVLUSU
    R('Kuzeybatı Mozole Avlusu', 6, 8, 52, 52, 'kemik')  # x6..57 y8..59
    for (bx, by, bw, bh) in ((11, 15, 9, 7), (26, 13, 12, 8), (44, 15, 9, 7), (11, 33, 8, 7), (27, 34, 10, 7), (44, 33, 8, 7)):
        pl.block(bx, by, bw, bh)
    C(58, 49, 4, 3)        # avlu -> kuzeybatı şapeli
    C(50, 60, 7, 4)        # avlu -> halka
    C(50, 64, 14, 7)
    C(20, 60, 5, 14)       # avlu -> galeriler

    # ---- KD: SU BASMIŞ AVLU
    R('Su Basmış Avlu', 156, 8, 52, 52, 'kemik')         # x156..207 y8..59
    for (bx, by, bw, bh) in ((182, 13, 10, 8), (161, 33, 8, 7), (196, 34, 8, 7)):
        pl.block(bx, by, bw, bh)
    for (wx, wy, ww, wh) in ((163, 16, 10, 7), (196, 15, 8, 6), (176, 31, 13, 8), (166, 47, 9, 5), (190, 48, 10, 5)):
        pl.water(wx, wy, ww, wh)
    C(152, 49, 4, 3)
    C(158, 60, 7, 4)
    C(152, 64, 14, 7)
    C(192, 60, 5, 12)      # avlu -> kafatası salonu

    # ---- B: LAHİT GALERİLERİ (beş galeri, yılan gibi)
    gy = [74, 87, 100, 113, 126]
    for i, y in enumerate(gy):
        R('Galeri %d' % (i + 1), 10, y, 48, 7, 'lahit')
    for i in range(4):
        ox = 11 if i % 2 == 0 else 54
        C(ox, gy[i] + 7, 3, 6)
    C(32, gy[1] + 7, 2, 6)                               # orta omurga (galeri 2-3, 3-4; 2 geniş: parmaklık kapısı)
    C(32, gy[2] + 7, 2, 6)
    C(58, 74, 6, 7)
    C(58, 100, 6, 7)
    C(58, 126, 6, 7)
    C(30, 133, 5, 25)      # galeriler -> kışla

    # ---- D: KEMİK OCAĞI (organik)
    # örnek harita gibi sık oda kümesi (organik mağara bu setin dili değil: basamaklı yüzler)
    R('Kemik Ocağı', 158, 72, 20, 14, 'kemik')           # x158..177 y72..85
    R('Kafatası Salonu', 182, 72, 24, 12, 'kemik')       # x182..205 y72..83
    R('Ölü Kuyusu', 158, 90, 22, 20, 'kalp')             # x158..179 y90..109
    R('Urne Odası', 184, 88, 22, 16, 'kemik')            # x184..205 y88..103
    R('Kemik Yarığı', 158, 114, 16, 28, 'kemik')         # x158..173 y114..141
    R('Kemik Rafları', 178, 114, 28, 12, 'lahit')        # x178..205 y114..125
    R('Kemik Kuyusu', 178, 130, 28, 12, 'kemik')         # x178..205 y130..141
    C(178, 77, 4, 3)
    C(166, 86, 3, 4)
    C(193, 84, 3, 4)
    C(180, 95, 4, 3)
    C(163, 110, 3, 4)
    C(192, 104, 3, 10)
    C(174, 118, 4, 3)
    C(190, 126, 3, 4)
    C(174, 134, 4, 3)
    C(152, 76, 6, 5)
    C(152, 98, 6, 5)
    C(152, 128, 6, 5)

    # ---- GB: BEKÇİ KIŞLASI
    C(10, 180, 50, 7)                                     # kışla koridoru y180..186
    for (nm, x, w, kind) in (('Silahlık', 10, 12, 'oda'), ('Koğuş', 26, 14, 'oda'), ('Nöbet Odası', 44, 14, 'oda')):
        R(nm, x, 158, w, 16, kind)                        # y158..173
        C(x + w // 2 - 1, 174, 3, 6)
    for (nm, x, w, kind) in (('Bekçi İni', 10, 16, 'kalp'), ('Zindan Hücreleri', 30, 12, 'oda'), ('Erzak Odası', 46, 12, 'oda')):
        R(nm, x, 193, w, 12, kind)                        # y193..204
        C(x + w // 2 - 1, 187, 3, 6)
    C(44, 146, 20, 7)                                     # kışla -> halka
    C(44, 153, 6, 5)
    C(60, 181, 24, 6)                                     # kışla -> giriş

    # ---- G: GİRİŞ SALONU (doğuş)
    R('Giriş Salonu', 84, 166, 46, 34, 'giris')          # x84..129 y166..199
    C(88, 153, 7, 13)
    C(120, 153, 7, 13)
    C(130, 181, 28, 6)                                    # giriş -> ejder mahzeni

    # ---- GD: EJDER MAHZENİ (sütun ormanı)
    R('Ejder Mahzeni', 158, 160, 48, 42, 'sutun')        # x158..205 y160..201
    for bx in (165, 179, 193):
        for by in (167, 184):
            pl.block(bx, by, 6, 7, 'paye')               # 6x7 paye: tepe 4 + yüz 3
    C(152, 146, 14, 7)
    C(160, 153, 6, 7)
    C(193, 142, 5, 18)     # kemik kuyusu -> ejder mahzeni

    lay.fix_thickness(min_v=4, min_h=2)
    KD.normalize_steps(lay)
    lay.fix_thickness(min_v=4, min_h=2)
    spawn = (107, 171)
    lay.keep_main_component(spawn)
    pl.spawn = spawn
    return pl


# ================================================================================================ boyama
# GRİ LEVHA ve PLAKA DÖŞEME YOK (madde 449, kullanıcı: önce "plakalardan hoşlanmadım", sonra levha için "bazı yerlerde çok absürt görünüyor ...
# onun yerine ... açık gri çatlak kayalara benzeyen yüzeyi kullan"): tüm zemin kum + zemin shader'ının C taş derzleri (shaders/zindan_zemin.gdshader).
# yükseltilmiş platformlar (örnekteki taht kürsüsü): (x, y, w, h, merdiven x listesi); ön yüz y + h satırında (1 satır, merdiven dışı engel)
PLATFORMS = [
    (94, 10, 26, 10, [105]),            # apsis kürsüsü
    (100, 99, 15, 12, [106]),           # Kemik Sunağı kürsüsü (ada)
    (94, 166, 27, 8, [98, 106, 114]),   # doğuş kürsüsü
]


def paint_base(pl, bank, tl, region=None):
    lay = pl.lay
    P.paint_walls_34(lay, bank, tl, 'wf', floor=(2, 8), tuck=KD.WF_TUCK, region=region)
    paint_water(lay, bank, tl, region)


_SU_TABLO = None


def su_tablo():
    global _SU_TABLO
    if _SU_TABLO is None:
        _SU_TABLO = ornek_su.learn()
    return _SU_TABLO


def _h(x, y):
    return ((x * 73856093) ^ (y * 19349663)) & 0xffff


def paint_water(lay, bank, tl, region=None):
    """Su kıyısı ÖRNEKTEN (ornek_su.learn: Dungeon3.tmx'te her kıyı hücresinin 8 komşu desenine göre kullanılan karo); desen örnekte
    yoksa kendi kuralı. Zemin kıyısı -> 'Zemin', yüzün suya taşan parçası su hücresinin 'Zemin'inde, batık duvar/tuğla 'Su altı'nda."""
    FLOOR, OVER, SUB = su_tablo()
    t = lay.t
    x0, y0, x1, y1 = region or (0, 0, W, H)
    x0, y0, x1, y1 = max(1, x0), max(1, y0), min(W - 1, x1), min(H - 1, y1)

    def wat(x, y):
        return 0 <= x < W and 0 <= y < H and t[y, x] == Z.W

    def flo(x, y):
        return 0 <= x < W and 0 <= y < H and t[y, x] == Z.F

    def floor_tile(x, y):
        m = ornek_su.mask(wat, x, y)
        if not m:
            return None
        if m in FLOOR:
            v = FLOOR[m]
            return v[_h(x // 3, y) % len(v)]   # uzun kenarda 3'lü öbeklerle değişir (örnekteki (2,8)/(6,5) yüz yükseklikleri)
        n, s_, e, w_ = wat(x, y - 1), wat(x, y + 1), wat(x + 1, y), wat(x - 1, y)
        if n or s_ or e or w_:
            return (1 if w_ else (3 if e else 2), 6 if n else (8 if s_ else 7))
        for (dx, dy), tt in INNER.items():
            if wat(x + dx, y + dy):
                return tt
        return None

    for y in range(y0, y1):
        for x in range(x0, x1):
            if t[y, x] == Z.W:
                tl.put('Su', x, y, bank.gid('wc', *WATER_BODY))
                tl.put('Zemin', x, y, 0)
                tl.put('Su altı', x, y, 0)
                m = ornek_su.mask(flo, x, y)
                h = _h(x, y)
                over = None
                if flo(x, y - 1):
                    above = floor_tile(x, y - 1)
                    if above == (6, 5):
                        over = (6, 6)
                    elif above is not None and above[1] == 8 and above[0] in (1, 2, 3):
                        over = (above[0], 9)
                if over is None and m in OVER:
                    over = next((v for v in OVER[m] if v != (6, 6)), None)
                if over is None and flo(x, y - 1):
                    over = (1 if wat(x - 1, y - 1) else (3 if wat(x + 1, y - 1) else 2), 9)
                if over is not None:
                    tl.put('Zemin', x, y, bank.gid('wc', *over))
                sub = None
                if m in SUB:
                    sub = SUB[m][0]
                elif flo(x, y - 1):
                    lw = wat(x - 1, y) and flo(x - 1, y - 1)
                    rw = wat(x + 1, y) and flo(x + 1, y - 1)
                    sub = (2 if (rw and not lw) else (4 if (lw and not rw) else 3), 30)
                elif (flo(x - 1, y) or flo(x + 1, y)) and h % 100 < 40:   # yan kıyı dibinde batık tuğla / çatlak
                    sub = (SUNKEN[h % len(SUNKEN)], 30)
                elif h % 1000 < 25:
                    sub = (SUNKEN[(h // 7) % len(SUNKEN)], 30)
                if sub is not None:
                    tl.put('Su altı', x, y, bank.gid('wc', *sub))
                continue
            if t[y, x] != Z.F:
                continue
            tile = floor_tile(x, y)
            if tile is not None:
                tl.put('Su', x, y, bank.gid('wc', *WATER_BODY))
                tl.put('Zemin', x, y, bank.gid('wc', *tile))


def paint_slabs(pl, bank, tl):
    """Zemin çatlak ayrıntıları (kum tonunda). Gri levha / plaka döşeme kaldırıldı (bkz. üstteki not)."""
    lay = pl.lay
    dist = P.wall_distance(lay, cap=4)
    sand = lay.t == Z.F
    P.floor_details(lay, bank, tl, 'wf', KM.DETAIL_SAND, density=0.08, seed=SEED, layer='Zemin süsü', mask=sand & (dist <= 2))
    P.floor_details(lay, bank, tl, 'wf', KM.DETAIL_SAND, density=0.015, seed=SEED + 7, layer='Zemin süsü', mask=sand & (dist > 2))


PLAT9 = ((1, 7), (2, 7), (3, 7), (1, 8), (2, 8), (3, 8), (1, 9), (2, 9), (3, 9))
STAIRS_DOWN = ('st', (1, 1, 3, 2))   # platformun alt kenarı + ön yüzdeki basamaklar


def paint_platforms(pl, bank, tl):
    """Yükseltilmiş platform: üst 9 dilim (kenar çizgili), altında 1 satır taş ön yüz, yüzde 3 geniş merdiven. Yüz hücreleri (merdiven dışı)
    pl.ledge'e (süslemede hareket engeli)."""
    pl.ledge, pl.stairs = [], []
    for (x, y, w, h, stairs) in PLATFORMS:
        P.nine_slice(tl, bank, 'Zemin ayrıntı', 'wf', PLAT9, x, y, w, h)
        for (xx, yy) in [(xx, yy) for yy in range(y, y + h) for xx in range(x, x + w)]:
            tl.put('Zemin desen', xx, yy, 0)
            tl.put('Zemin süsü', xx, yy, 0)
        fy = y + h
        for i in range(w):
            tl.put('Zemin ayrıntı', x + i, fy, bank.gid('wf', 1 if i == 0 else (3 if i == w - 1 else 2), 10))
            tl.put('Zemin süsü', x + i, fy, 0)
        sc = set()
        for sx in stairs:
            Z.stamp(bank, tl, 'Zemin ayrıntı', STAIRS_DOWN[0], STAIRS_DOWN[1], sx, fy - 1)
            sc |= {sx, sx + 1, sx + 2}
            pl.stairs.append((sx, fy))
        pl.ledge += [(x + i, fy) for i in range(w) if x + i not in sc]


# ---- cephe: paye + kemer ritmi (örnek haritanın Walls2 / Arches_columns kullanımı)
PIL_SQ = [('arc', (c, 10, 1, 3)) for c in (1, 2, 3, 4, 5, 6, 7)]
PIL_RD = [('arc', (c, 10, 1, 3)) for c in (8, 9, 10)]
FACADE_DEFAULT = ('torch', 'arch', 'relief', 'torch', 'none', 'arch')


def face_runs(dz, x0, y0, x1, y1):
    """(y, xa, xb): y zemin satırı, xa..xb-1 sütunlarının üstündeki 3 satır kesintisiz yüz."""
    t = dz.lay.t
    runs = []
    for y in range(max(4, y0), min(H - 1, y1)):
        x = max(1, x0)
        xe = min(W - 1, x1)
        while x < xe:
            if t[y, x] == Z.F and dz.is_face(x, y - 1, 1) and dz.is_face(x, y - 3, 3):
                xa = x
                while x < xe and t[y, x] == Z.F and dz.is_face(x, y - 1, 1) and dz.is_face(x, y - 3, 3):
                    x += 1
                runs.append((y, xa, x))
            else:
                x += 1
    return runs


def facade(dz, x0, y0, x1, y1, pil=PIL_SQ, contents=FACADE_DEFAULT, step=5, light=P.CYAN, arches=None):
    arches = arches or KM.ARCH_FACE
    for (y, xa, xb) in face_runs(dz, x0, y0, x1, y1):
        if xb - xa < 4:
            continue
        ps = list(range(xa, xb, step))
        if xb - 1 - ps[-1] >= 3:
            ps.append(xb - 1)
        style = pil[(xa * 3 + y) % len(pil)]
        for p in ps:
            if not dz.occ[y - 3:y, p].any():
                dz.put('Duvar süsü', style, p, y - 3)
                dz.occ[y - 3:y, p] = True
        for i, (a, b) in enumerate(zip(ps, ps[1:])):
            gap = b - a - 1
            if gap < 2:
                continue
            cx = a + 1 + (gap - 2) // 2
            if dz.occ[y - 3:y, cx:cx + 2].any():
                continue
            kind = contents[(i + xa // 3 + y) % len(contents)]
            if kind == 'arch':
                dress_face(dz, cx, y, arches[(cx + y) % len(arches)])
            elif kind == 'torch':
                dress_face(dz, cx, y, KM.TORCH_WALL[(cx // 5) % 2], light=light)
            elif kind == 'relief':
                dz.put('Duvar süsü', KM.RELIEF, cx, y - 2)
                dz.occ[y - 2:y, cx:cx + 2] = True
            elif kind == 'hang':
                spec = KM.HANGING[(cx + y) % len(KM.HANGING)]
                hh = spec[1][3]
                if dz.face_free(cx, y - hh, spec[1][2], hh):
                    dz.put('Duvar süsü', spec, cx, y - hh)
                    dz.occ[y - hh:y, cx:cx + spec[1][2]] = True


def paint_ripples(pl, bank, tl, rng):
    """Örnekteki gibi su hücrelerinin çoğunda süzülen dalgacık (water_details, iki katman): sığan öbek her su hücresinden denenir."""
    t = pl.lay.t
    cells = [(int(x), int(y)) for (y, x) in np.argwhere(t == Z.W)]
    placed = 0
    for layer in ('Su ayrıntı', 'Su ayrıntı 2'):
        used = np.zeros((H, W), bool)
        rng.shuffle(cells)
        for (x, y) in cells:
            if used[y, x]:
                continue
            for _ in range(4):
                sx, sy, w, h = RIPPLES[rng.randrange(len(RIPPLES))]
                if x + w >= W or y + h >= H or not (t[y:y + h, x:x + w] == Z.W).all() or used[y:y + h, x:x + w].any():
                    continue
                Z.stamp(bank, tl, layer, 'wd', (sx, sy, w, h), x, y)
                used[y:y + h, x:x + w] = True
                placed += 1
                break
    return placed


# ================================================================================================ süsleme
def face_run_spots(dz, x0, y0, x1, y1, w=2):
    """(x, y): y zemin satırı, üstündeki 3 satır yüz (k 3/2/1), w sütun boyunca; yüz hücreleri boş."""
    out = []
    t = dz.lay.t
    for y in range(max(4, y0), min(H - 1, y1)):
        for x in range(max(1, x0), min(W - w - 1, x1)):
            if all(t[y, x + i] == Z.F and dz.is_face(x + i, y - 1, 1) and dz.is_face(x + i, y - 3, 3) for i in range(w)) and \
                    not dz.occ[y - 3:y, x:x + w].any():
                out.append((x, y))
    return out


def dress_face(dz, x, y, spec, light=None, light_r=104):
    key, (sx, sy, w, h) = spec
    dz.put('Duvar süsü', spec, x, y - 3)
    dz.occ[y - 3:y, x:x + w] = True
    if light is not None:
        dz.light((x + w / 2.0) * 16, (y - 1.8) * 16, light, r=light_r, energy=0.9)


def dress_faces(dz, x0, y0, x1, y1, every=7, arch_every=3, light=P.CYAN):
    """Bölgedeki tüm kuzey yüzleri: her `every` hücrede meşale, her `arch_every`. yerde kemer/pencere, arada kabartma."""
    spots = face_run_spots(dz, x0, y0, x1, y1)
    spots.sort(key=lambda p: (p[1], p[0]))
    last = {}
    n = 0
    for (x, y) in spots:
        if x - last.get(y, -99) < every or dz.occ[y - 3:y, x:x + 2].any():
            continue
        n += 1
        if n % arch_every == 0:
            dress_face(dz, x, y, KM.ARCH_FACE[dz.rng.randrange(len(KM.ARCH_FACE))])
        elif n % 4 == 1:
            dress_face(dz, x, y, KM.TORCH_WALL[n % 2], light=light)
        else:
            dz.put('Duvar süsü', KM.RELIEF, x, y - 2)
            dz.occ[y - 2:y, x:x + 2] = True
        last[y] = x


# serbest duran sütun: Arches_columns 8-13. sütunlar (yuvarlak başlık). 1-7. sütunların tepesinde duvara yaslanmak için koyu bant var - açık
# zeminde "kahverengi direk" gibi duruyordu (ince ayar, kullanıcı: mimari ayrıntı); onlar yalnız yüz payesi (facade).
FREE_COLS = (8, 9, 10, 12, 13)


def column(dz, x, y, n=0):
    """Serbest duran sütun, 1x4 (başlık + iki gövde + taban), tabanı (x, y) - yalnız hareketi keser."""
    if not dz.is_free(x, y - 3, 1, 4, allow_reserve=True):
        return False
    if not dz.solidify([(x, y)]):
        return False
    c = FREE_COLS[n % len(FREE_COLS)]
    for j, row in enumerate((10, 11, 11, 12)):
        Z.stamp(dz.bank, dz.tl, 'Eşya', 'arc', (c, row, 1, 1), x, y - 3 + j)
    dz.occ[y - 3:y + 1, x] = True
    return True


def clusters(dz, r, choices, n_clusters, per=4, rad=2, solid=False, wd=None):
    """Kemik/kafatası ÖBEKLERİ (tek tek saçmak gürültülüydü): öbek merkezleri duvar dibinde (wd <= 2), her öbekte `per` parça."""
    rng = dz.rng
    cells = r.cells if r.cells is not None else [(x, y) for y in range(r.y, r.y + r.h) for x in range(r.x, r.x + r.w)]
    cand = [(x, y) for (x, y) in cells if dz.lay.t[y, x] == Z.F and (wd is None or wd[y, x] <= 2) and not dz.occ[y, x]]
    rng.shuffle(cand)
    made = 0
    centers = []
    for (cx, cy) in cand:
        if made >= n_clusters:
            break
        if any(abs(cx - a) + abs(cy - b) < 8 for (a, b) in centers):
            continue
        got = 0
        if solid:
            # ince ayar 2: dik duran eşya rastgele noktaya değil, öbek merkezine yakın ve DUVARA / öbeğin öteki eşyasına bitişik yere (örnekteki
            # sıkı yığınlar; yol kuralı aralık bırakan yerleşimi reddettiği için rastgele konum öbeği seyreltiyordu)
            for _ in range(per * 4):
                if got >= per:
                    break
                spec = choices[rng.randrange(len(choices))]
                w, h = spec[1][2], spec[1][3]
                cands = []
                for y in range(cy - rad - h + 1, cy + rad + 1):
                    for x in range(cx - rad - w + 1, cx + rad + 1):
                        cands.append((-_touch(dz, foot_cells(dz.bank, spec, x, y) or [(x + i, y + h - 1) for i in range(w)]),
                                      abs(x + w / 2.0 - cx - 0.5) + abs(y + h - 1 - cy), rng.random(), x, y))
                cands.sort()
                for (_t, _d, _r, x, y) in cands:
                    if solid_prop(dz, spec, x, y, lane=True):
                        got += 1
                        break
        for _ in range(0 if solid else per * 8):
            if got >= per:
                break
            spec = choices[rng.randrange(len(choices))]
            w, h = spec[1][2], spec[1][3]
            x, y = cx + rng.randint(-rad, rad), cy + rng.randint(-rad, rad)
            if solid:
                ok = solid_prop(dz, spec, x, y, lane=True)
            else:
                ok = dz.is_free(x, y, w, h, allow_reserve=True, allow_door=True)
                if ok:
                    dz.put('Yer süsü', spec, x, y)
            got += 1 if ok else 0
        if got:
            centers.append((cx, cy))
            made += 1
    return made


def grave_plots(dz, r, n):
    """Mezarlık: 2-4 mezarlık kısa sıralar (aynı aileden, 1 hücre ara), çevresinde 1 hücre boşluk; ızgara gibi değil."""
    rng = dz.rng
    families = [KM.WOOD_H, KM.TOMBS_H, KM.TOMBS_V_SMALL, KM.WOOD_V[1:]]
    placed = 0
    for _ in range(n * 60):
        if placed >= n:
            break
        fam = families[rng.randrange(len(families))]
        k = rng.randint(2, 4)
        specs = [fam[rng.randrange(len(fam))] for _ in range(k)]
        w = max(s[1][2] for s in specs)
        h = max(s[1][3] for s in specs)
        tw = k * (w + 1) - 1
        if r.w - tw - 4 < 1 or r.h - h - 6 < 1:
            continue
        x0 = rng.randint(r.x + 2, r.x + r.w - tw - 2)
        y0 = rng.randint(r.y + 4, r.y + r.h - h - 2)
        if not dz.is_free(x0 - 1, y0 - 1, tw + 2, h + 2):
            continue
        n_ok = sum(1 for i, sp in enumerate(specs) if solid_prop(dz, sp, x0 + i * (w + 1), y0))
        if n_ok:
            placed += 1
    return placed


# ---- AYAK İZİ + YOL (ince ayar 2, 2026-11-08; kullanıcı: "kutuların collisionları çok büyük sürekli yolu kesiyor, alakasız collisionlar var")
# Eskiden kalıbın taban satırının TAMAMI engeldi: 3 hücrelik kalıpta tek hücrelik kazan 3 hücre, boş yarılı kalıplar görünmez engel, ışık halesi
# dahil küçük mum / şişe / anahtar da engeldi. Artık ayak izi kalıbın KENDİ pikselinden: en alttaki dolu satırın, en az FOOT_MIN opak (alfa >=
# FOOT_ALPHA: hale/gölge sayılmaz) piksel taşıyan hücreleri. Toplam opak piksel SMALL_TOTAL'dan azsa eşya küçük: engel değil ama yine derinlik
# katmanında (karakter arkasındayken örtülür). lane=True (rastgele öbekler): yerleşim, çevresindeki hiçbir yürünür hücrenin geçit genişliğini
# (yatay / dikey koşunun küçüğü, LANE_W'de kırpılır) düşüremez -> tek / iki hücrelik aralık ve sokağı daraltan öbek yok.
FOOT_ALPHA = 160
FOOT_MIN = 40
SMALL_TOTAL = 200
LANE_W = 3
_foot_cache = {}


def spec_counts(bank, spec):
    """Kalıbın hücre başına opak piksel sayısı [satır][sütun] (alfa >= FOOT_ALPHA)."""
    key, (sx, sy, w, h) = spec
    ck = (id(bank), key, sx, sy, w, h)
    if ck not in _foot_cache:
        img = bank.sets[key].img
        a = np.array(img.crop((sx * 16, sy * 16, (sx + w) * 16, (sy + h) * 16)).convert('RGBA'))[:, :, 3] >= FOOT_ALPHA
        _foot_cache[ck] = [[int(a[j * 16:(j + 1) * 16, i * 16:(i + 1) * 16].sum()) for i in range(w)] for j in range(h)]
    return _foot_cache[ck]


def foot_cells(bank, spec, x, y, base_rows=1):
    cnt = spec_counts(bank, spec)
    if sum(map(sum, cnt)) < SMALL_TOTAL:
        return []
    rows = [j for j in range(len(cnt)) if max(cnt[j]) >= FOOT_MIN]
    if not rows:
        return []
    jb = rows[-1]
    out = []
    for j in range(max(0, jb - base_rows + 1), jb + 1):
        out += [(x + i, y + j) for i in range(len(cnt[j])) if cnt[j][i] >= FOOT_MIN]
    return out


def _lane_blocked(dz):
    lay = dz.lay
    return (lay.t != Z.F) | (lay.solid_obj > 0) | dz.gate


def _lane_width(blk, x, y):
    Hh, Ww = blk.shape

    def run(dx, dy):
        n, xx, yy = 0, x + dx, y + dy
        while n < LANE_W and 0 <= xx < Ww and 0 <= yy < Hh and not blk[yy, xx]:
            n += 1
            xx += dx
            yy += dy
        return n
    return min(LANE_W, 1 + run(-1, 0) + run(1, 0), 1 + run(0, -1) + run(0, 1))


def _touch(dz, foot):
    """Ayak izinin 4 komşusundan kaçı engel (duvar / su / katı nesne) - öbek yerleşiminde bitişik konum tercihi."""
    blk = _lane_blocked(dz)
    Hh, Ww = blk.shape
    fs = set(foot)
    n = 0
    for (x, y) in foot:
        for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            c = (x + dx, y + dy)
            if c not in fs and (not (0 <= c[0] < Ww and 0 <= c[1] < Hh) or blk[c[1], c[0]]):
                n += 1
    return n


def lane_ok(dz, foot):
    """foot engel olunca çevresindeki yürünür hücrelerin geçit genişliği düşüyor mu (bkz. AYAK İZİ + YOL notu)."""
    if not foot:
        return True
    blk = _lane_blocked(dz)
    xs = [c[0] for c in foot]
    ys = [c[1] for c in foot]
    Hh, Ww = blk.shape
    x0, x1 = max(0, min(xs) - LANE_W - 1), min(Ww, max(xs) + LANE_W + 2)
    y0, y1 = max(0, min(ys) - LANE_W - 1), min(Hh, max(ys) + LANE_W + 2)
    before = {}
    for yy in range(y0, y1):
        for xx in range(x0, x1):
            if not blk[yy, xx]:
                before[(xx, yy)] = _lane_width(blk, xx, yy)
    after = blk.copy()
    fs = set(foot)
    for (xx, yy) in foot:
        after[yy, xx] = True
    for c, wb in before.items():
        if c not in fs and _lane_width(after, c[0], c[1]) < wb:
            return False
    return True


def solid_prop(dz, spec, x, y, layer='Eşya', base_rows=1, light=None, light_r=80, lane=False):
    key, (sx, sy, w, h) = spec
    if not dz.is_free(x, y, w, h, allow_reserve=True):
        return False
    foot = foot_cells(dz.bank, spec, x, y, base_rows)
    if lane and not lane_ok(dz, foot):
        return False
    if foot and not dz.solidify(foot):
        return False
    dz.put(layer, spec, x, y)
    if light is not None:
        dz.light((x + w / 2.0) * 16, (y + h * 0.45) * 16, light, r=light_r, energy=0.75)
    return True


def flat_prop(dz, spec, x, y):
    key, (sx, sy, w, h) = spec
    if not dz.is_free(x, y, w, h, allow_reserve=True, allow_door=True):
        return False
    dz.put('Zemin süsü', spec, x, y)
    return True


def open_coffin(dz, x, y):
    spec = KM.OPEN_EMPTY_V[dz.rng.randrange(len(KM.OPEN_EMPTY_V))]
    key, (sx, sy, w, h) = spec
    if not dz.is_free(x, y, w, h, allow_reserve=True, allow_door=True):
        return False
    dz.put('Eşya alt', spec, x, y)
    for j in range(1, h):
        for i in range(w):
            dz.hide[y + j, x + i] = True
    dz.add_obj('saklanma', 'Açık Lahit', x, y + 1, w, h - 1)
    return True


def near(fn, dz, x, y, *a, rad=7, **kw):
    """fn(dz, x, y) tutmazsa en yakın konumlar denenir (sabit koordinatlı yerleşim mezarla/süsle çakışınca kaybolmasın)."""
    offs = sorted(((dx, dy) for dy in range(-rad, rad + 1) for dx in range(-rad, rad + 1)), key=lambda d: d[0] * d[0] + d[1] * d[1])
    for (dx, dy) in offs:
        if fn(dz, x + dx, y + dy, *a, **kw):
            return True
    dz.notes.append('UYARI: %s yeri yok (%d,%d)' % (fn.__name__, x, y))
    return False


def wall_coffin_open(dz, x, ry):
    """Galeri yüzünün önünde dikili AÇIK lahit (üst 2 satırı yüzün önünde): zemindeki alt satırlar saklanma."""
    spec = KM.OPEN_EMPTY_V[0]
    key, (sx, sy, w, h) = spec
    if not dz.is_free(x, ry, w, h - 2, allow_reserve=True, allow_door=True):
        return False
    dz.put('Eşya alt', spec, x, ry - 2)
    for j in range(h - 2):
        for i in range(w):
            dz.hide[ry + j, x + i] = True
    dz.occ[ry - 2:ry + h - 2, x:x + w] = True
    dz.add_obj('saklanma', 'Açık Lahit', x, ry, w, h - 2)
    return True


def resource(dz, x, y):
    """Ruh Kandili (çalışma anında çizilir 2x3): tabanı (x..x+1, y) engel."""
    if not dz.is_free(x - 1, y - 2, 4, 3, allow_reserve=True) or not dz.solidify([(x + i, y - j) for j in range(3) for i in range(2)]):  # ince ayar 2: dikdörtgenin TAMAMI engel (çalışma anında çizilen nesnenin arkasına/içine girilip üstüne çiziliyordu)
        return False
    dz.occ[y - 2:y + 1, x:x + 2] = True
    dz.add_obj('kaynak', 'ruh_kandili', x, y - 2, 2, 3, tur='ruh_kandili')
    return True


def chest_at(dz, x, y, elite=False):
    if not dz.is_free(x, y, 2, 2, allow_reserve=True) or not dz.solidify([(x + i, y + j) for j in range(2) for i in range(2)]):  # ince ayar 2: dikdörtgenin TAMAMI engel (çalışma anında çizilen nesnenin arkasına/içine girilip üstüne çiziliyordu)
        return False
    dz.occ[y:y + 2, x:x + 2] = True
    dz.add_obj('sandik', 'Elit Sandık' if elite else 'Sandık', x, y, 2, 2, elit=1 if elite else 0)
    return True


def dragon(dz, x, y, zone_h=3):
    """EJDER BAŞI: (x, y) yüzün altındaki ilk zemin satırı; baş yüzün alt satırında (çalışma anında çizilir), ateş 2 x zone_h aşağı."""
    if not all(dz.is_face(x + i, y - 1, 1) for i in range(2)) or dz.occ[y - 2:y, x:x + 2].any():
        return False
    if not (dz.lay.t[y:y + zone_h, x:x + 2] == Z.F).all():
        return False
    dz.occ[y - 2:y, x:x + 2] = True
    dz.add_obj('tuzak', 'Ejder Başı', x, y, 2, zone_h, tur='ejder')
    dz.light((x + 1) * 16, (y + 1.5) * 16, P.CYAN, r=72, energy=0.5, flicker=1)
    return True


def gate_ew(dz, x, y, style='diken'):
    """Yatay geçitte 1x3 kapı (x, y..y+2)."""
    for j in range(3):
        dz.gate[y + j, x] = True
        dz.occ[y + j, x] = True
    dz.add_obj('kapi', dz.GATE_NAMES.get(style, style), x, y, 1, 3, stil=style)


def gate_ns(dz, x, y, style='parmaklik'):
    """Dikey geçitte 2x3 kapı (x..x+1, y..y+2)."""
    for j in range(3):
        for i in range(2):
            dz.gate[y + j, x + i] = True
            dz.occ[y + j, x + i] = True
    dz.add_obj('kapi', dz.GATE_NAMES.get(style, style), x, y, 2, 3, stil=style)


def scatter_in(dz, r, choices, n, solid=False, light=None):
    # yürünür süs 'Yer süsü'nde: zemin shader'ı (taş derzi) kemiğin/altının üstünden geçmesin
    dz.scatter(r, choices, n, solid=solid, light=light, layer=None if solid else 'Yer süsü')


def decorate(pl, bank, tl):
    lay = pl.lay
    dz = P.Decorator(lay, bank, tl, seed=SEED, paint=lambda reg: paint_base(pl, bank, tl, reg))
    rng = dz.rng
    N = pl.named
    wd = P.wall_distance(lay, cap=3)
    sx, sy = pl.spawn
    dz.spawn = (sx, sy)
    dz.add_obj('dogus', 'Doğuş', sx - 1, sy - 1, 3, 2)
    dz.reserve[sy - 3:sy + 4, sx - 4:sx + 5] = True
    # platform ön yüzleri: hareket engeli (merdivenler açık), üstlerine süs yok
    dz.solidify(pl.ledge, check=False)
    for (x, y) in pl.ledge:
        dz.occ[y, x] = True
    for (x, y) in pl.stairs:
        dz.occ[y - 1:y + 1, x:x + 3] = True
        dz.reserve[y + 1:y + 4, x:x + 3] = True

    # ---------------- G: GİRİŞ SALONU (yüzdeki merdivenden kürsüye inilir)
    g = N['Giriş Salonu']
    dz.put('Duvar süsü', KM.STAIRS_UP, 106, 162)
    dz.occ[162:166, 106:109] = True
    for (x, spec) in ((100, KM.STATUES[0]), (113, KM.STATUES[1])):
        solid_prop(dz, spec, x, 166)
    for (x, y) in ((95, 167), (118, 167)):
        solid_prop(dz, KM.CANDLES_FLOOR[(x + y) % len(KM.CANDLES_FLOOR)], x, y, light=P.CYAN)
    for x in range(87, 128, 5):
        if not (101 <= x <= 113):
            column(dz, x, 181, x)
            column(dz, x, 193, x + 1)
    for (x, y) in ((86, 197), (126, 197)):
        solid_prop(dz, KM.CANDLES_FLOOR[x % len(KM.CANDLES_FLOOR)], x, y - 1, light=P.CYAN)
    facade(dz, g.x, g.y, g.x + g.w, g.y + 1, contents=('torch', 'arch', 'relief', 'arch'))

    # ---------------- ORTA: BATIK SARNIÇ
    s = N['Batık Sarnıç']
    ax, ay = 105, 100                       # Kemik Sunağı: kürsünün üstünde ruh alevli heykel (5x5, alt 2 satır engel)
    dz.put('Eşya', KM.STATUE_FIRE, ax, ay)
    dz.solidify([(ax + i, ay + j) for i in range(1, 4) for j in (3, 4)], check=False)
    dz.occ[ay:ay + 5, ax:ax + 5] = True
    dz.reserve[ay + 5:ay + 8, ax:ax + 5] = True
    dz.add_obj('sunak', 'Kemik Sunağı', ax, ay + 5, 5, 2)
    dz.light((ax + 2.5) * 16, (ay + 1.5) * 16, P.CYAN, r=170, energy=1.3)
    for (x, y) in ((101, 100), (112, 100), (101, 106), (112, 106)):
        solid_prop(dz, KM.CANDLES_FLOOR[(x + y) % len(KM.CANDLES_FLOOR)], x, y, light=P.CYAN, light_r=64)
    near(resource, dz, 98, 116)
    near(resource, dz, 116, 116)
    for (x, y) in ((97, 98), (117, 98)):
        solid_prop(dz, URNS[(x // 3) % len(URNS)], x, y)
    # kenar yürüyüşünde suya bakan sütun sıraları
    for y in range(81, 137, 5):
        if not (102 <= y <= 114):
            column(dz, 79, y, y)
            column(dz, 136, y, y + 3)
    for x in range(85, 132, 5):
        if not (100 <= x <= 114):
            column(dz, x, 81, x)
            column(dz, x, 140, x + 2)
    for (qx, qy) in ((81, 83), (126, 83), (81, 129), (126, 129)):   # köşe iskeleleri: lahit + mum
        solid_prop(dz, KM.TOMB_BIG_H[(qx + qy) % 2], qx + 2, qy + 1, base_rows=2)
        solid_prop(dz, KM.CANDLES_FLOOR[qx % len(KM.CANDLES_FLOOR)], qx + 6, qy + 4, light=P.CYAN, light_r=64)
    facade(dz, s.x, s.y, s.x + s.w, s.y + 1, contents=('torch', 'arch', 'relief', 'arch'))

    # ---------------- K: KATEDRAL (yuvarlak sütunlu nef, kürsülü apsis)
    nave = N['Katedral Nefi']
    for y in range(28, 58, 4):
        column(dz, 87, y, 0)
        column(dz, 127, y, 1)
    for y in range(26, 57, 5):
        solid_prop(dz, KM.TOMBS_H[(y // 5) % len(KM.TOMBS_H)], 76, y)
        solid_prop(dz, KM.TOMBS_H[(y // 5 + 2) % len(KM.TOMBS_H)], 135, y)
        if y % 10 == 6:
            solid_prop(dz, KM.CANDLES_FLOOR[y % 6], 80, y, light=P.CYAN, light_r=64)
            solid_prop(dz, KM.CANDLES_FLOOR[(y + 2) % 6], 132, y, light=P.CYAN, light_r=64)
    # nef ortası: iki katafalk (büyük lahit + iki yanında mum) + döşeme yolunun iki kenarında mum dizisi
    for cy in (33, 45):
        solid_prop(dz, KM.TOMB_BIG_H[0], 105, cy, base_rows=2)
        solid_prop(dz, KM.CANDLES_FLOOR[cy % 6], 102, cy + 1, light=P.CYAN, light_r=72)
        solid_prop(dz, KM.CANDLES_FLOOR[(cy + 2) % 6], 110, cy + 1, light=P.CYAN, light_r=72)
    for y in range(27, 58, 6):
        if not any(cy - 1 <= y <= cy + 3 for cy in (33, 45)):
            solid_prop(dz, KM.CANDLES_FLOOR[(y + 1) % 6], 99, y, light=P.CYAN, light_r=56)
            solid_prop(dz, KM.CANDLES_FLOOR[(y + 4) % 6], 114, y, light=P.CYAN, light_r=56)
    for (x, spec) in ((96, KM.STATUES[2]), (100, KM.STATUES[0]), (113, KM.STATUES[1]), (117, KM.STATUES[3])):
        solid_prop(dz, spec, x, 10)
    for (x, y) in ((95, 16), (118, 16)):
        solid_prop(dz, KM.CANDLES_FLOOR[x % 6], x, y, light=P.CYAN)
    near(chest_at, dz, 106, 12, elite=True)
    near(resource, dz, 101, 17)
    near(resource, dz, 112, 17)
    facade(dz, 74, 9, 141, 26, pil=PIL_RD, contents=('arch', 'torch', 'relief', 'torch'))
    facade(dz, nave.x, nave.y, nave.x + nave.w, nave.y + nave.h, pil=PIL_RD, contents=('arch', 'torch', 'relief'))
    for nm in ('Batı Şapeli', 'Kuzeybatı Şapeli', 'Doğu Şapeli', 'Kuzeydoğu Şapeli'):
        c = N[nm]
        solid_prop(dz, KM.TOMB_BIG_H[0], c.x + 3, c.y + 3, base_rows=2)
        near(open_coffin, dz, c.x + 1, c.y, rad=3)
        solid_prop(dz, KM.CANDLES_FLOOR[1], c.x + c.w - 2, c.y, light=P.CYAN)
        facade(dz, c.x, c.y, c.x + c.w, c.y + 1, pil=PIL_RD, contents=('relief',))
    near(chest_at, dz, 146, 31)
    near(chest_at, dz, 66, 47)

    # ---------------- MOZOLE AVLULARI
    for (bx, by, bw, bh, kind) in pl.blocks:
        fy = by + bh  # yüzün altındaki ilk zemin satırı
        if kind == 'mozole':
            cx = bx + bw // 2 - 1
            dz.put('Duvar süsü', PIL_SQ[bx % 7], bx, fy - 3)
            dz.put('Duvar süsü', PIL_SQ[(bx + 1) % 7], bx + bw - 1, fy - 3)
            dz.occ[fy - 3:fy, bx] = True
            dz.occ[fy - 3:fy, bx + bw - 1] = True
            dress_face(dz, cx, fy, KM.ARCH_FACE[(bx + by) % len(KM.ARCH_FACE)])
            if bw >= 9:
                dress_face(dz, bx + 2, fy, KM.TORCH_WALL[0], light=P.CYAN)
                dress_face(dz, bx + bw - 4, fy, KM.TORCH_WALL[1], light=P.CYAN)
            dz.reserve[fy:fy + 3, bx:bx + bw] = True   # mozole önü açık kalsın (mezar sırası kapıyı kapatmasın)
            solid_prop(dz, KM.CANDLES_FLOOR[bx % 6], cx - 2, fy, light=P.CYAN, light_r=64)
            solid_prop(dz, KM.CANDLES_FLOOR[(bx + 3) % 6], cx + 2, fy, light=P.CYAN, light_r=64)
        else:  # paye (ejder mahzeni): yüzünde ejder başı
            dragon(dz, bx + bw // 2 - 1, fy)
            dz.put('Duvar süsü', PIL_SQ[0], bx, fy - 3)
            dz.put('Duvar süsü', PIL_SQ[0], bx + bw - 1, fy - 3)
            dz.occ[fy - 3:fy, bx] = True
            dz.occ[fy - 3:fy, bx + bw - 1] = True
    for nm in ('Kuzeybatı Mozole Avlusu', 'Su Basmış Avlu'):
        r = N[nm]
        facade(dz, r.x, r.y, r.x + r.w, r.y + 1)
        # mezarlık: kısa mezar sıraları (2-4, aynı aile) serbest yerleşim + duvar diplerinde kemik/urne öbekleri
        grave_plots(dz, r, 13 if nm.startswith('Kuzeybatı') else 7)
        clusters(dz, r, KM.BONES + KM.SKULLS, 4, per=3, rad=1, wd=wd)
        clusters(dz, r, URNS, 3, per=2, solid=True, wd=wd)
        scatter_in(dz, r, KM.GOLD, 2)
    near(resource, dz, 31, 26)
    near(resource, dz, 14, 52)
    near(resource, dz, 186, 26)
    near(resource, dz, 200, 54)
    near(chest_at, dz, 31, 23)
    near(chest_at, dz, 172, 55)

    # ---------------- B: LAHİT GALERİLERİ (dikili lahit sırası yüzün önünde)
    for i in range(5):
        r = N['Galeri %d' % (i + 1)]
        x = r.x + 2
        k = 0
        while x + 2 <= r.x + r.w - 2:
            if dz.is_face(x, r.y - 1, 1) and dz.is_face(x + 1, r.y - 1, 1) and not dz.occ[r.y - 3:r.y, x:x + 2].any():
                ok = False
                if k % 4 == 2:
                    ok = wall_coffin_open(dz, x, r.y)
                elif k % 4 == 0:
                    dress_face(dz, x, r.y, KM.TORCH_WALL[k % 2], light=P.CYAN)
                    ok = True
                else:
                    spec = KM.TOMBS_V[k % 2] if k % 3 else KM.TOMBS_V_SMALL[k % len(KM.TOMBS_V_SMALL)]
                    hh = spec[1][3]
                    if dz.is_free(x, r.y, 2, hh - 2, allow_reserve=True) and dz.solidify([(x, r.y + hh - 3), (x + 1, r.y + hh - 3)]):
                        dz.put('Eşya', spec, x, r.y - 2)
                        dz.occ[r.y - 2:r.y + hh - 2, x:x + 2] = True
                        ok = True
                k += 1
                x += 4 if ok else 1
            else:
                x += 1
        for x in range(r.x + 3, r.x + r.w - 3, 5):
            if rng.random() < 0.5:
                solid_prop(dz, URNS[rng.randrange(len(URNS))], x, r.y + r.h - 2)
        scatter_in(dz, r, KM.BONES + KM.SKULLS, 4)
    near(resource, dz, 24, 104)
    near(resource, dz, 44, 130)
    near(chest_at, dz, 50, 117)

    # ---------------- D: KEMİK OCAĞI (kafatası nişleri, kemik yığınları, kemik rafları)
    for nm in ('Kemik Ocağı', 'Kafatası Salonu', 'Ölü Kuyusu', 'Urne Odası', 'Kemik Yarığı', 'Kemik Rafları', 'Kemik Kuyusu'):
        r = N[nm]
        facade(dz, r.x, r.y, r.x + r.w, r.y + 1, contents=('relief', 'hang', 'torch', 'relief', 'none'), step=4)
        clusters(dz, r, KM.BONE_PILES + URNS, 2, per=2, solid=True, wd=wd)   # kemik yığını öbekleri duvar dibinde
        clusters(dz, r, KM.BONES + KM.SKULLS, 2, per=3, rad=1, wd=wd)
        dz.corner_candles(r, KM.CANDLES_FLOOR, count=2)
    nd = 0
    for (y, xa, xb) in face_runs(dz, 156, 70, 208, 144):
        for x in range(xa + 1, xb - 2, 3):
            if nd >= 4:
                break
            if all(math.dist((x, y), (o['x'] // 16, o['y'] // 16)) > 12 for o in dz.objects if o['type'] == 'tuzak') and dragon(dz, x, y, zone_h=3):
                nd += 1
                break
    near(resource, dz, 166, 98)
    near(resource, dz, 194, 91)
    near(chest_at, dz, 200, 118)

    # ---------------- GB: BEKÇİ KIŞLASI (pencereli/kapılı cepheler)
    for nm in ('Silahlık', 'Koğuş', 'Nöbet Odası', 'Bekçi İni', 'Zindan Hücreleri', 'Erzak Odası'):
        r = N[nm]
        cont = ('arch',) if nm == 'Zindan Hücreleri' else ('torch', 'arch', 'relief')
        arches = [KM.ARCH_FACE[1], KM.ARCH_FACE[4]] if nm == 'Zindan Hücreleri' else None
        facade(dz, r.x, r.y, r.x + r.w, r.y + 1, contents=cont, step=4, arches=arches)
        scatter_in(dz, r, KM.BONES, 3)
    for (x, y) in ((12, 160), (17, 160)):
        solid_prop(dz, KM.BENCH[1], x, y)
    near(chest_at, dz, 14, 166)
    near(chest_at, dz, 50, 197)
    for x in range(28, 39, 4):
        solid_prop(dz, KM.WOOD_V[x % len(KM.WOOD_V)], x, 160)
    solid_prop(dz, KM.BENCH[0], 48, 165)
    near(resource, dz, 18, 196)
    facade(dz, 10, 180, 60, 181, contents=('arch', 'torch'), arches=[KM.ARCH_FACE[1], KM.ARCH_FACE[2]])

    # ---------------- GD: EJDER MAHZENİ
    e = N['Ejder Mahzeni']
    facade(dz, e.x, e.y, e.x + e.w, e.y + 1)
    near(chest_at, dz, 201, 197, elite=True)
    near(resource, dz, 162, 197)
    scatter_in(dz, e, KM.BONES + KM.SKULLS, 14)
    scatter_in(dz, e, KM.BONE_PILES, 3, solid=True)

    # ---------------- kalan tüm yüzler (halka cadde, koridorlar): seyrek paye + meşale
    facade(dz, 0, 0, W, H, step=6, contents=('torch', 'none', 'relief', 'none'))
    return dz


def place_gates(dz, pl):
    # galeri omurgası (2 geniş dikey geçit) + şapel kapıları + kışla/giriş + ejder mahzeni bağlantıları
    gate_ns(dz, 32, 95)
    gate_ns(dz, 32, 108)
    gate_ew(dz, 72, 49)
    gate_ew(dz, 140, 49)
    gate_ew(dz, 70, 181)
    gate_ew(dz, 143, 181)
    gate_ew(dz, 58, 101)


def place_traps(dz):
    for (x, y) in ((11, 82), (54, 95), (11, 108), (54, 121)):   # galeri dirsekleri (3 geniş geçit)
        if not dz.occ[y:y + 3, x:x + 3].any():
            dz.occ[y:y + 3, x:x + 3] = True
            dz.add_obj('tuzak', 'diken', x, y, 3, 3, tur='diken')
    dz.traps('diken', count=3)


def dwellers(dz, pl):
    for r in pl.lay.rooms:
        if r.kind == 'giris':
            continue
        prof = r.kind if r.kind in ('lahit', 'kemik', 'sutun', 'kalp', 'oda') else 'oda'
        dz.dwellers(r, prof)


def escape_check(pl, dz):
    lay = pl.lay
    gates = []
    for o in dz.objects:
        if o['type'] == 'kapi':
            gates.append(P.obj_cells(o))
    p = lay.passable() & (lay.solid_obj == 0)
    base = lay.bfs([pl.spawn], p)
    unreach = int((p & (base < 0)).sum())
    fails = []
    for i, cells in enumerate(gates):
        pp = p.copy()
        for (x, y) in cells:
            pp[y, x] = False
        d = lay.bfs([pl.spawn], pp)
        lost = int((pp & (d < 0)).sum())
        if lost > 0:
            fails.append((i, cells[0], lost))
    return {'zemin': int(p.sum()), 'ulasilmaz': unreach, 'kapi_hapsi': fails}


def main(write=False):
    t0 = time.time()
    pl = build_layout()
    lay = pl.lay
    os.makedirs(Z.OUT, exist_ok=True)
    print('yerleşim %.1f sn, zemin %d hücre (%%%.1f), su %d' % (time.time() - t0, int((lay.t == Z.F).sum()),
                                                            100.0 * int((lay.t != Z.S).sum()) / (W * H), int((lay.t == Z.W).sum())))
    bank = make_bank()
    tl = Z.TileLayers(W, H, ORDER)
    paint_base(pl, bank, tl)
    paint_slabs(pl, bank, tl)
    paint_platforms(pl, bank, tl)
    rng = random.Random(SEED + 5)
    print('dalgacık', paint_ripples(pl, bank, tl, rng))
    dz = decorate(pl, bank, tl)
    place_gates(dz, pl)
    place_traps(dz)
    for o in dz.objects:   # ince ayar (kullanıcı: ışık / karanlık): meşale/mum ışıkları daha güçlü ve biraz daha geniş
        if o['type'] == 'isik':
            o['props']['g'] = '%.2f' % min(1.8, float(o['props']['g']) * LIGHT_GAIN)
            o['props']['r'] = int(round(int(o['props']['r']) * LIGHT_REACH))
    dwellers(dz, pl)
    dz.hunter_route('kemik_bekcisi')
    for o in dz.objects:
        o.setdefault('props', {})['tema'] = TEMA
    P.write_engel(lay, bank, tl, dz)
    rep = escape_check(pl, dz)
    counts = {}
    for o in dz.objects:
        counts[o['type']] = counts.get(o['type'], 0) + 1
    print('nesneler', counts)
    print('kaçış', rep)
    for s_ in lay.notes + dz.notes:
        print(' ', s_)
    Z.semantic_png(lay, dz.objects, os.path.join(Z.OUT, ID + '_sema.png'), scale=3)
    img = Z.render(bank, tl, W, H, skip=('Engel',))
    img.resize((W * 4, H * 4), Z.Image.BOX).save(os.path.join(Z.OUT, ID + '_tam.png'))
    for (nm, cx, cy) in (('sarnic', 107, 108), ('katedral', 107, 34), ('avlu', 32, 34), ('galeri', 36, 103), ('ocak', 182, 106),
                         ('kisla', 34, 181), ('sukose', 96, 96), ('giris', 107, 183), ('ejder', 182, 181), ('suavlu', 182, 34)):
        img.crop(((cx - 32) * 16, (cy - 20) * 16, (cx + 32) * 16, (cy + 20) * 16)).save(os.path.join(Z.OUT, '%s_%s.png' % (ID, nm)))
    print('önizleme %.1f sn' % (time.time() - t0))
    pl.dz, pl.bank, pl.tl = dz, bank, tl
    if write:
        write_out(pl)
    return pl


def write_out(pl):
    bank, tl, dz = pl.bank, pl.tl, pl.dz
    bank.write_files()
    for pack in (ID, 'kemik_mahzeni'):
        P.copy_runtime_sheets(RL, pack, KM.RUNTIME_SHEETS + [DRAGON_SHEET])
    tmx = os.path.join(Z.ZROOT, ID + '.tmx')
    Z.write_tmx(tmx, bank, tl, dz.objects, W, H, props={'ad': TITLE}, hidden=('Engel',))
    print('yazıldı:', tmx)


if __name__ == '__main__':
    main('--write' in sys.argv)
