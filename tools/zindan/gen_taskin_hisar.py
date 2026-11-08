# TAŞKIN HİSAR (harita seçimi, 3 yeni haritanın 2.si, madde 449): "Piksel Zindan Assetleri" (Dungeon1) - mavi-gri taş kale.
# 214x214. Biçim dili Batık Nekropol'den (merkez + halka) tamamen farklı: KB'deki TAŞKIN HAVUZU'ndan GD'deki BOŞALTIM HAVUZU'na dik açılarla
# merdiven gibi inen, iki yanı rıhtımlı bir KANAL haritayı ikiye böler:
#   KD yarı  HİSAR        - taht salonu (kürsü + Boynuz sunağı), iç avlu (kuyu), kışla, silahhane, kuzey ambarı, doğu ambarları, kale önü
#   GB yarı  AŞAĞI KALE   - kapı meydanı (doğuş kürsüsü), şarap mahzenleri, fıçı deposu, merdivenli mahzen, liman, sarnıçlar, zindan hücreleri
# Kanalın üstünde 6 köprü: yatay kanal kollarındaki 4 köprüde demir parmaklık; bu haritaya özgü KÖPRÜ KOLLARI (yeni nesne "kol", grup başına
# iki köprü) gruptaki parmaklıkları birlikte indirir (diğer köprüler açık kalır - kaçış). Etkileşimler Boynuzlu Kapı'nınki (tema 'boynuz').
# Zemin: kum (Dungeon1 açık mavi-gri) + zemin shader'ı C taş derzi (profil "zemin_rengi"); levha / plaka YOK (madde 449 dersleri).
# Genel yardımcılar gen_batik_nekropol'den (BN); Dungeon1'e özgü değerler (su gövdesi, batık izler, kürsü merdiveni) BN'nin modül
# değişkenlerine bu dosyada yazılır (her üreteç kendi sürecinde koşar).
# Çalıştır: python tools/zindan/gen_taskin_hisar.py [--write]  ->  Godot --import ; bake_zindan.gd -- taskin_hisar
import math
import os
import random
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zindan_core as Z  # noqa: E402
import zindan_paint as P  # noqa: E402
import gen_batik_nekropol as BN  # noqa: E402
import gen_boynuzlu_kapi as BK  # noqa: E402

ID = 'taskin_hisar'
TITLE = 'Taşkın Hisar'
W = H = 214
SEED = 7203
TEMA = 'boynuz'
D1 = BK.D1
S_D1 = BK.S_D1
ORDER = BN.ORDER[:BN.ORDER.index('Duvar süsü') + 1] + ['Duvar süsü 2'] + BN.ORDER[BN.ORDER.index('Duvar süsü') + 1:]   # 2: niş içindeki mum

# ---- Dungeon1 değerleri (BN yardımcılarına)
BN.WATER_BODY = (11, 30)          # Dungeon1 su gövdesi (opak); (7..10, 30) seyrek çeşitler
BN.SUNKEN = (5, 6)                # saydam batık tuğla izleri (Dungeon1'de 7..11 opak su, 12..13 boş)
BODY_ALT = [(7, 30), (8, 30), (9, 30), (10, 30)]
FLOOR_RGB = (128, 138, 163)       # Dungeon1 zemin (2, 8) - zemin shader'ı bu renge taş derzi çizer

# ---- Dungeon1 süs sözlüğü
WIN = BK.WIN_FACE                 # yüze oturan kemerli pencere / açık kemer / ahşap kapı / demir ızgara (2x3)
WIN_BARRED = [WIN[3]]
TORCH = BK.CANDLE                 # duvar meşalesi alevi (fire_animation2, 2x2)
FIRE_BIG = BK.BRAZIER             # büyük ateş (fire_animation, 3x3)
BASIN = ('d1o', (1, 5, 2, 2))     # taş çukur / kuyu (örnekte merdivenli çukur; mangal kaidesi DEĞİL)
# İNCE AYAR 2 (2026-11-08, kullanıcı: "kutuların collisionları çok büyük, alakasız collisionlar, çok sayıda etkileşim sorunu"): BK'nin listeleri
# nesne sayfasında İKİ ayrı nesneyi birleştiriyordu (sandık + altındaki küpler, sandık + KOL), "fıçılar"da süs SANDIK (açılmaz, gerçek sandıkla
# karışıyordu), "küpler"de yere konmuş duvar KALKANI vardı; boş yarıları görünmez engel oluyordu. Kalıplar sayfanın bağlı bileşenlerinden, tek
# nesnelik (ölçüm: scratchpad bilesen.py). Süs sandık / kol / anahtar / altın yığını yere saçılmaz (toplanır ya da açılır sanılıyordu).
CRATES = [('d1o', (17, 1, 2, 3)), ('d1o', (19, 1, 2, 3)), ('d1o', (21, 1, 2, 2)), ('d1o', (3, 5, 2, 2)), ('d1o', (8, 5, 2, 2)),
          ('d1o', (5, 5, 1, 2)), ('d1o', (10, 5, 1, 2))]
BARRELS = [('d1o', (6, 5, 2, 2)), ('d1o', (11, 5, 2, 2)), ('d1o', (21, 5, 2, 2)), ('d1o', (19, 4, 2, 2)), ('d1o', (21, 3, 2, 2))]
VASES = [('d1o', (1, 7, 2, 2)), ('d1o', (3, 7, 1, 2)), ('d1o', (4, 7, 1, 2))] + [('d1o', (c, 5, 1, 2)) for c in (13, 14, 15, 16, 17, 18)]
LADDER = BK.LADDER
STAIRS_OBJ = [BK.STAIRS_UP, BK.STAIRS_UP2]   # duvara yaslanan çapraz merdiven (Objects)
SHIELDS = [('d1o', (6, 7, 1, 1)), ('d1o', (7, 7, 1, 1))]
NICHE_CANDLE = (0, 1, 2, 2)       # fire_animation küçük mum (alev 1. satırda); kemerli pencerenin alt iki satırına
SMALL = [('d1o', (c, 5, 1, 2)) for c in (13, 14, 15, 16, 17, 18)]


def make_bank():
    bank = Z.TilesetBank(ID)
    bank.add('wf', os.path.join(D1, 'walls_floor.png'))
    bank.add('d1o', os.path.join(D1, 'Objects.png'), name='hisar_esyalari.png')
    bank.add('d1f', os.path.join(D1, 'fire_animation.png'), anims=Z.sample_anims(S_D1, 'fire_animation'))
    bank.add('d1f2', os.path.join(D1, 'fire_animation2.png'), anims=Z.sample_anims(S_D1, 'fire_animation2'))
    bank.add('cr', os.path.join(D1, 'decorative_cracks_floor.png'), name='zemin_catlaklari.png')
    bank.add('wc', os.path.join(D1, 'Water_coasts_animation.png'), name='su_kiyi.png',
             anims=Z.sample_anims(S_D1, 'Water_coasts_animation'))
    bank.add('wd', os.path.join(D1, 'water_details_animation.png'), name='su_dalga.png',
             anims=Z.sample_anims(S_D1, 'Water_detilazation'))
    bank.add('eng', 'engel', name='engel.png', img=Z.make_marker_sheet())
    return bank


# ================================================================================================ yerleşim
CANAL = [   # su dikdörtgenleri (x, y, w, h): taşkın havuzu -> merdiven gibi kanal -> boşaltım havuzu
    (12, 16, 26, 16),     # R1 Taşkın Havuzu
    (38, 24, 66, 8),      # S1 yatay
    (96, 32, 8, 77),      # S2 dikey
    (104, 101, 67, 8),    # S3 yatay
    (163, 109, 8, 64),    # S4 dikey
    (150, 173, 40, 18),   # R2 Boşaltım Havuzu
]
QUAY = 5
# köprüler (x, y, w, h) su üstünde zemin; 'g' = parmaklık grubu (kol), None = kapısız
BRIDGES = [
    (56, 24, 4, 8, 'bati'), (82, 24, 4, 8, 'bati'),       # S1 üstü
    (96, 58, 8, 3, None),                                   # S2 üstü (yatay köprü; güverte 3 satır, altında kemer yüzü)
    (120, 101, 4, 8, 'dogu'), (146, 101, 4, 8, 'dogu'),   # S3 üstü
    (163, 136, 8, 3, None),                                 # S4 üstü
]
# KAPISIZ KÖPRÜ (ince ayar 2, kullanıcı "köprüleri"; eskiden düz zemin şeridiydi, kanal orada kesilmiş gibi okunuyordu). Setin köprü
# karosu yok -> kürsü dilinde güverte (walls_floor 9 dilimin orta sütunu: üst kenar (2, 7) / dolgu (2, 8) / alt kenar (2, 9); uçta yan
# kenar YOK, rıhtım zeminine kesintisiz bağlanır) + önünde 2 satırlık içi saydam taş KEMER dizisi (6..7 x 26..27, örnekteki açık kemer),
# kemerin içinden alttaki su görünür. Köprünün altında kanal kesintisiz su boyanır (boyarken güverte su sayılır, sonra yürünür zemine döner).
ARCH = (6, 26)
LEVERS = {'bati': (70, 19), 'dogu': (136, 96)}   # kolun zemin hücresi (kol yüzün alt satırında çizilir)
PLATFORMS = [
    (147, 24, 30, 5, [160]),            # taht salonu kürsüsü (Boynuz sunağı)
]
# AŞAĞI ŞEHİR (GB + doğu şeridi): oda + koridor DEĞİL, boşluk tasarımı - bölge açık zemin, içine ev/depo blokları; sokaklar blok arası,
# bloklar kaydırıldığı için L biçimli dar sokaklar + küçük meydanlar. (Batık Nekropol'den oda ölçeğinde ayrışma, kullanıcı "farklılaştır")
TOWN_RECTS = [(8, 38, 83, 74), (8, 115, 150, 49), (8, 164, 136, 43), (177, 97, 31, 66)]
PLAZA = (32, 127, 28, 21)          # Çeşme Meydanı (doğuş): bina yok, ortada çeşme havuzu
FOUNTAIN = (43, 134, 6, 4)
SPAWN = (46, 143)
# çeşme meydanının dört mangalı (fountain() ile aynı konumlar) ve örnekteki gibi altlarında basamaklı taş KÜRSÜ (ince ayar)
_fx, _fy, _fw, _fh = FOUNTAIN
PLAZA_BRAZIERS = [(_fx - 4, _fy - 2), (_fx + _fw + 3, _fy - 2), (_fx - 4, _fy + _fh + 1), (_fx + _fw + 3, _fy + _fh + 1)]
PLATFORMS += [(bx - 2, by, 5, 4, [bx]) for (bx, by) in PLAZA_BRAZIERS]   # 5x4 kürsü, mangal ortasında (fountain: by + 1), basamak önünde
# kürsü basamağı (walls_floor): dar kürsüde 1 hücre (1, 12..13), genişte 2 hücre (10..11, 10..11). Eski (10, 10, 3, 2) damgasının 3.
# sütunu (12, x) ayrı bir korkuluk parçasıydı -> taht kürsüsünde basamağın yanında kopuk "|" çiziyordu.
STAIR_1 = ('wf', (1, 12, 1, 2))
STAIR_2 = ('wf', (10, 10, 2, 2))
TOWN_NAMES = {   # iç mekan adı -> (oda türü, süs profili)
    'Meyhane': ('salon', 'meyhane'), 'Şarap Mahzeni': ('oda', 'mahzen'), 'Fıçı Deposu': ('oda', 'mahzen'), 'Liman Ambarı': ('oda', 'ambar'),
    'Tuz Ambarı': ('oda', 'ambar'), 'Zindan Hücresi': ('oda', 'hucre'), 'Gardiyan Evi': ('oda', 'hucre'), 'Sarnıç': ('kalp', 'sarnic'),
    'Tüccar Evi': ('oda', 'ev'), 'Mühürcü Evi': ('oda', 'ev'), 'Mum Atölyesi': ('oda', 'ev'),
}


def bsp(x, y, w, h, rng, out, depth=0):
    """Bölgeyi sokaklarla bloklara böler (sokak 3-5); yaprak = blok adayı."""
    if (w <= 22 and h <= 19) or depth > 9:
        out.append((x, y, w, h))
        return
    st = rng.randint(3, 5)
    if w >= h * 1.15 or h <= 19:
        if w < 2 * 8 + st:
            out.append((x, y, w, h))
            return
        cut = rng.randint(x + 8, x + w - 8 - st)
        bsp(x, y, cut - x, h, rng, out, depth + 1)
        bsp(cut + st, y, x + w - cut - st, h, rng, out, depth + 1)
    else:
        if h < 2 * 9 + st:
            out.append((x, y, w, h))
            return
        cut = rng.randint(y + 9, y + h - 9 - st)
        bsp(x, y, w, cut - y, rng, out, depth + 1)
        bsp(x, cut + st, w, y + h - cut - st, rng, out, depth + 1)


def _overlap(a, b, pad=0):
    return a[0] < b[0] + b[2] + pad and b[0] < a[0] + a[2] + pad and a[1] < b[1] + b[3] + pad and b[1] < a[1] + a[3] + pad


def build_town(pl, rng):
    lay = pl.lay
    town = np.zeros((H, W), bool)
    for (x, y, w, h) in TOWN_RECTS:
        town[y:y + h, x:x + w] = True
    lay.t[town] = Z.F
    tr = lay.add_room(8, 38, 200, 169, 'oda')
    tr.name = 'Aşağı Şehir'
    tr.cells = [(int(x), int(y)) for (y, x) in np.argwhere(town)]
    lay.room_id[town] = tr.id
    pl.named['Aşağı Şehir'] = tr
    leaves = []
    for (x, y, w, h) in TOWN_RECTS:
        bsp(x, y, w, h, rng, leaves)
    names = list(TOWN_NAMES)
    rng.shuffle(names)
    pl.houses = []
    n_int = 0
    for (x, y, w, h) in leaves:
        if _overlap((x, y, w, h), PLAZA, pad=2) or w < 7 or h < 7 or rng.random() < 0.08:
            continue   # meydan / küçük boşluk
        # kenarlardan rastgele 0-1 içeri: sokaklarda kırık köşe (L) ve genişlik farkı
        x0 = x + rng.randint(0, 1)
        y0 = y + rng.randint(0, 1)
        x1 = x + w - rng.randint(0, 1)
        y1 = y + h - rng.randint(0, 1)
        bw, bh = x1 - x0, y1 - y0
        lay.t[y0:y1, x0:x1] = Z.S
        lay.room_id[y0:y1, x0:x1] = -1
        # bazı blokların bir köşesi oyulur: L biçimli bina, köşede küçük avlu
        if bw >= 14 and bh >= 12 and rng.random() < 0.35:
            cw, ch = rng.randint(4, bw // 2 - 2), rng.randint(4, bh // 2 - 1)
            cx = x0 if rng.random() < 0.5 else x1 - cw
            lay.t[y1 - ch:y1, cx:cx + cw] = Z.F
            lay.room_id[y1 - ch:y1, cx:cx + cw] = tr.id
        house = {'rect': (x0, y0, bw, bh), 'room': None}
        # iç mekan: duvarlar üst/alt 4 (yüz), yan 2
        if bw >= 12 and bh >= 13 and n_int < len(names):
            ix, iy, iw, ih = x0 + 2, y0 + 4, bw - 4, bh - 8
            if (lay.t[iy:iy + ih, ix:ix + iw] == Z.S).all():
                door = None
                cxm = ix + iw // 2 - 1
                for (dx, dy, dw, dh, ox, oy) in ((cxm, iy + ih, 3, 4, cxm + 1, iy + ih + 4), (cxm, y0, 3, 4, cxm + 1, y0 - 1),
                                                 (x0, iy + ih // 2 - 1, 2, 3, x0 - 1, iy + ih // 2), (ix + iw, iy + ih // 2 - 1, 2, 3, ix + iw + 2, iy + ih // 2)):
                    if 0 <= oy < H and 0 <= ox < W and town[oy, ox] and lay.t[oy, ox] == Z.F:
                        door = (dx, dy, dw, dh)
                        break
                if door is not None:
                    nm = names[n_int]
                    n_int += 1
                    kind, prof = TOWN_NAMES[nm]
                    r = pl.room(nm, ix, iy, iw, ih, kind)
                    r.prof = prof
                    pl.corr(*door)
                    house['room'] = r
                    if prof == 'sarnic' and iw >= 10 and ih >= 6:
                        pl.water(ix + 2, iy + 2, iw - 4, ih - 3)
        pl.houses.append(house)
    # çeşme meydanı: ortada küçük havuz
    pl.water(*FOUNTAIN)


def build_castle(pl):
    """HİSAR: kalın sur (bailey ile rıhtım arası 8), sur köşe/orta kuleleri (avluya taşan bloklar), sur kapıları, dış avluda binalar,
    ortada kendi köşe kuleleri olan iç kale (taht salonu + iç avlu)."""
    R, C = pl.room, pl.corr
    lay = pl.lay
    R('Dış Avlu', 117, 11, 86, 77, 'salon')               # x117..202 y11..87
    for (x, y, w, h) in ((117, 11, 8, 8), (195, 11, 8, 8), (117, 80, 8, 8), (195, 80, 8, 8), (155, 11, 10, 5), (117, 44, 5, 8),
                         (198, 44, 5, 8)):
        pl.block(x, y, w, h, 'kule')
    # iç kale: dolu blok + kuleler, sonra içi oyulur
    pl.block(139, 20, 46, 44, 'kale')
    for (x, y) in ((134, 16), (183, 16), (134, 58), (183, 58)):
        pl.block(x, y, 7, 7, 'kule')
    R('Taht Salonu', 145, 24, 34, 10, 'kalp')             # x145..178 y24..33
    R('İç Avlu', 145, 38, 34, 20, 'salon')                # y38..57
    C(160, 34, 4, 4)                                       # taht <-> iç avlu
    C(161, 58, 2, 6)                                       # iç kale kapısı (güney, parmaklık)
    C(139, 46, 6, 3)                                       # batı yan kapı (kapısız)
    # dış avlu binaları (içine girilen)
    for (nm, x, y, w, h, kind) in (('Kışla', 119, 22, 13, 16, 'oda'), ('Silahhane', 119, 56, 13, 15, 'oda'),
                                   ('Ahır', 191, 22, 11, 16, 'oda'), ('Kale Ambarı', 191, 50, 11, 16, 'oda')):
        pl.block(x, y, w, h, 'bina')
        r = R(nm, x + 2, y + 4, w - 4, h - 8, kind)
        r.prof = 'kale'
        C(x + w // 2 - 1, y + h - 4, 3, 4)
    # sur kapıları
    C(109, 47, 8, 4)        # batı kapısı -> S2 doğu rıhtımı (kapısız)
    C(157, 88, 2, 8)        # güney kapısı -> S3 kuzey rıhtımı (parmaklık)
    C(132, 88, 4, 8)        # güney arka kapı (kapısız)
    C(189, 88, 4, 9)        # doğu kapısı -> doğu şeridi şehir


def build_layout():
    pl = BN.Plan()
    lay = pl.lay
    rng = random.Random(SEED)
    pl.houses = []

    # ---- KANAL + RIHTIMLAR
    wmask = np.zeros((H, W), bool)
    for (x, y, w, h) in CANAL:
        wmask[y:y + h, x:x + w] = True
    quay = wmask.copy()
    for _ in range(QUAY):
        q2 = quay.copy()
        q2[1:, :] |= quay[:-1, :]
        q2[:-1, :] |= quay[1:, :]
        q2[:, 1:] |= quay[:, :-1]
        q2[:, :-1] |= quay[:, 1:]
        q2[1:, 1:] |= quay[:-1, :-1]
        q2[1:, :-1] |= quay[:-1, 1:]
        q2[:-1, 1:] |= quay[1:, :-1]
        q2[:-1, :-1] |= quay[1:, 1:]
        quay = q2
    k = lay.add_room(7, 11, 189, 185, 'oda')
    k.name = 'Kanal Rıhtımı'
    k.cells = [(int(x), int(y)) for (y, x) in np.argwhere(quay & ~wmask)]
    pl.named['Kanal Rıhtımı'] = k
    lay.t[quay] = Z.F
    lay.room_id[quay] = k.id

    build_town(pl, rng)
    build_castle(pl)

    # ---- su + köprüler
    lay.t[wmask & (lay.t == Z.F)] = Z.W
    for (x, y, w, h, g) in BRIDGES:
        lay.t[y:y + h, x:x + w] = Z.F
        lay.room_id[y:y + h, x:x + w] = k.id
    pl.pools += list(CANAL)

    lay.fix_thickness(min_v=4, min_h=2)
    BN.KD.normalize_steps(lay)
    lay.fix_thickness(min_v=4, min_h=2)
    pl.spawn = SPAWN
    lay.keep_main_component(SPAWN)
    return pl


# ================================================================================================ boyama
def open_decks():
    return [(x, y, w, h) for (x, y, w, h, g) in BRIDGES if g is None]


def paint_base(pl, bank, tl, region=None):
    t = pl.lay.t
    for (x, y, w, h) in open_decks():   # köprü altı: kanal kesintisiz (bkz. ARCH notu)
        t[y:y + h, x:x + w] = Z.W
    P.paint_walls_34(pl.lay, bank, tl, 'wf', floor=(2, 8), tuck=BN.KD.WF_TUCK, region=region)
    BN.paint_water(pl.lay, bank, tl, region)
    _water_variety(pl, bank, tl, region)
    for (x, y, w, h) in open_decks():
        t[y:y + h, x:x + w] = Z.F


def _water_variety(pl, bank, tl, region):
    # su gövdesine seyrek çeşit (örnekteki gibi)
    t = pl.lay.t
    x0, y0, x1, y1 = region or (0, 0, W, H)
    for (y, x) in np.argwhere(t == Z.W):
        x, y = int(x), int(y)
        if not (x0 <= x < x1 and y0 <= y < y1):
            continue
        # ince ayar: batık duvar parçası YALNIZ kıyı yüzünün hemen altında (örnekteki gibi); rastgele saçılanlar suyun içinde koyu
        # kare lekeler gibi duruyordu
        if t[y - 1, x] != Z.F:
            tl.put('Su altı', x, y, 0)
        h = BN._h(x, y)
        if h % 100 < 6 and not tl.get('Zemin', x, y):
            tl.put('Su', x, y, bank.gid('wc', *BODY_ALT[h % len(BODY_ALT)]))


PLAT9 = ((1, 7), (2, 7), (3, 7), (1, 8), (2, 8), (3, 8), (1, 9), (2, 9), (3, 9))


def paint_platforms(pl, bank, tl):
    """Örnekteki yükseltilmiş kürsü: açık kenarlı üst (walls_floor 1..3 x 7..9), altında 1 satır taş yüz (1..3, 10), yüzde basamak
    (STAIR_1 / STAIR_2). Yüz hücreleri (basamak dışı) pl.ledge'e; pl.stairs = (x, yüz satırı, genişlik)."""
    pl.ledge, pl.stairs = [], []
    for (x, y, w, h, stairs) in PLATFORMS:
        P.nine_slice(tl, bank, 'Zemin ayrıntı', 'wf', PLAT9, x, y, w, h)
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                tl.put('Zemin desen', xx, yy, 0)
                tl.put('Zemin süsü', xx, yy, 0)
        fy = y + h
        for i in range(w):
            tl.put('Zemin ayrıntı', x + i, fy, bank.gid('wf', 1 if i == 0 else (3 if i == w - 1 else 2), 10))
            tl.put('Zemin süsü', x + i, fy, 0)
        spec = STAIR_1 if w <= 6 else STAIR_2
        sw = spec[1][2]
        sc = set()
        for sx in stairs:
            Z.stamp(bank, tl, 'Zemin ayrıntı', spec[0], spec[1], sx, fy - 1)
            sc |= set(range(sx, sx + sw))
            pl.stairs.append((sx, fy, sw))
        pl.ledge += [(x + i, fy) for i in range(w) if x + i not in sc]


def paint_bridges(pl, bank, tl):
    """Kapısız köprü: güverte (yürünür) + altında 2 satır kemer dizisi (su hücreleri, yürünmez). Bkz. ARCH notu."""
    for (x, y, w, h) in open_decks():
        for i in range(w):
            for j in range(h):
                tl.put('Zemin ayrıntı', x + i, y + j, bank.gid('wf', 2, 7 if j == 0 else (9 if j == h - 1 else 8)))
                tl.put('Zemin desen', x + i, y + j, 0)
                tl.put('Zemin süsü', x + i, y + j, 0)
            for j in range(2):
                tl.put('Zemin ayrıntı', x + i, y + h + j, bank.gid('wf', ARCH[0] + i % 2, ARCH[1] + j))
        # uçlar: rıhtımın kıyı çizgisi güverte boyunca sürüp köprüyle rıhtım arasında dikiş çiziyordu -> güverte satırlarında düz zemin
        for j in range(h):
            for xx in (x - 1, x + w):
                if pl.lay.t[y + j, xx] == Z.F:
                    tl.put('Zemin', xx, y + j, bank.gid('wf', 2, 8))


def floor_cracks(pl, bank, tl):
    lay = pl.lay
    dist = P.wall_distance(lay, cap=4)
    sand = lay.t == Z.F
    cr = bank.sets['cr']
    tiles = [(c, r) for r in range(cr.rows) for c in range(cr.cols) if cr.opaque(c, r)]
    P.floor_details(lay, bank, tl, 'cr', tiles[:12], density=0.035, seed=SEED, layer='Zemin süsü', mask=sand & (dist <= 2))


# ================================================================================================ süsleme
def facade(dz, x0, y0, x1, y1, contents=('torch', 'win', 'none', 'shield', 'torch', 'win'), step=6, wins=WIN):
    """Kuzey yüzlerinde ritim: meşale alevi (amber ışık), kemerli pencere/kapı/ızgara, kalkan."""
    for (y, xa, xb) in BN.face_runs(dz, x0, y0, x1, y1):
        if xb - xa < 4:
            continue
        for i, x in enumerate(range(xa + 1, xb - 2, step)):
            if dz.occ[y - 3:y, x:x + 2].any():
                continue
            kind = contents[(i + xa // 3 + y) % len(contents)]
            if kind == 'torch':
                dz.put('Duvar süsü', TORCH[(x + y) % 2], x, y - 3)
                dz.occ[y - 3:y, x:x + 2] = True
                dz.light((x + 1) * 16, (y - 2) * 16, P.AMBER, r=110, energy=1.05)
            elif kind == 'win':
                BN.dress_face(dz, x, y, wins[(x * 3 + y) % len(wins)])
            elif kind == 'niche':
                # örnekteki mumlu niş: kemerli pencere + içinde mum (örneğin 'Lights' katmanındaki fire_animation 0..1 x 2..3 karoları)
                BN.dress_face(dz, x, y, WIN[0])
                Z.stamp(dz.bank, dz.tl, 'Duvar süsü 2', 'd1f', NICHE_CANDLE, x, y - 2)   # ışık nesnesi yok: karoda hale çizili (FPS)
            elif kind == 'ladder':
                # örnekteki gibi yüze yaslı merdiven, alt ucu zeminde
                if dz.occ[y, x] or not dz.is_free(x, y, 1, 1, allow_reserve=True):
                    continue
                dz.put('Duvar süsü', LADDER, x, y - 3)
                dz.occ[y - 3:y + 1, x:x + 1] = True
            elif kind == 'shield':
                dz.put('Duvar süsü', SHIELDS[(x + y) % 2], x, y - 2)
                dz.occ[y - 2:y - 1, x:x + 1] = True


def brazier(dz, x, y):
    """Ayaklı mangal (fire_animation 3x3: kasesi + alevi aynı karoda), (x, y)..(x+1, y+1) alanında; ayağı (x, y + 1) engel.
    ince ayar: önceden altına Objects (1, 5) konuyordu - örnekte o karo merdivenli ÇUKUR, mangal kaidesi değil; alev de üstünde
    süzülüyordu. Örnekteki gibi mangal kendi başına durur."""
    if not dz.is_free(x - 1, y - 1, 3, 3, allow_reserve=True) or not dz.solidify([(x, y + 1)]):
        return False
    dz.put('Eşya', FIRE_BIG[(x + y) % 2], x - 1, y - 1)
    dz.occ[y - 1:y + 2, x - 1:x + 2] = True
    dz.light((x + 0.5) * 16, (y + 0.6) * 16, P.AMBER, r=150, energy=1.25)
    return True


def resource(dz, x, y):
    """Işık Kristali düğümü (çalışma anında çizilir, 3x3 görsel), tabanı 2 hücre engel."""
    if not dz.is_free(x - 1, y - 2, 4, 3, allow_reserve=True) or not dz.solidify([(x + i, y - j) for j in range(3) for i in range(2)]):  # ince ayar 2: dikdörtgenin TAMAMI engel (çalışma anında çizilen nesnenin arkasına/içine girilip üstüne çiziliyordu)
        return False
    dz.occ[y - 2:y + 1, x - 1:x + 3] = True
    dz.add_obj('kaynak', 'isik_kristali', x, y - 2, 2, 3, tur='isik_kristali')
    return True


def gate(dz, x, y, group=None, style='demir'):
    """Dikey geçitte 2x3 demir parmaklık; group verilirse yalnız kolla iner."""
    for j in range(3):
        for i in range(2):
            dz.gate[y + j, x + i] = True
            dz.occ[y + j, x + i] = True
    props = {'stil': style}
    if group:
        props['grup'] = group
    dz.add_obj('kapi', 'Köprü Parmaklığı' if group else 'Demir Parmaklık', x, y, 2, 3, **props)


def lever(dz, group, x, y):
    """KOL: zemin hücresi (x, y) etkileşim alanı, kol yüzün alt satırında (çalışma anında çizilir)."""
    dz.occ[y - 1:y + 1, x:x + 1] = True
    dz.reserve[y:y + 2, x - 1:x + 2] = True
    dz.add_obj('kol', 'Köprü Kolu', x, y, 1, 1, grup=group)
    dz.light((x + 0.5) * 16, (y - 0.5) * 16, P.AMBER, r=60, energy=0.6, flicker=0)


def fountain(dz):
    """Çeşme Meydanı: havuzun dört köşesinde ateş ocağı, kenarlarda fıçı/vazo."""
    x, y, w, h = FOUNTAIN
    for (bx, by) in PLAZA_BRAZIERS:
        brazier(dz, bx, by + 1)
    dz.reserve[y - 2:y + h + 3, x - 2:x + w + 2] = True


def interior(dz, r, wd):
    prof = getattr(r, 'prof', 'ev')
    if prof in ('mahzen',):
        x = r.x + 1
        while x + 2 <= r.x + r.w - 1:      # kuzey duvarı dibinde fıçı sırası
            x += 3 if BN.solid_prop(dz, BARRELS[(x // 2) % len(BARRELS)], x, r.y) else 1
        BN.clusters(dz, r, BARRELS, 1, per=3, solid=True, wd=wd)
    elif prof in ('ambar', 'kale'):
        BN.clusters(dz, r, CRATES + BARRELS, 2, per=3, solid=True, wd=wd)
    elif prof == 'meyhane':
        BN.clusters(dz, r, BARRELS, 2, per=2, solid=True, wd=wd)
        BN.clusters(dz, r, VASES, 2, per=2, solid=True, wd=wd)
    elif prof == 'hucre':
        BN.clusters(dz, r, SMALL, 1, per=2, solid=True, wd=wd)
    elif prof == 'sarnic':
        BN.clusters(dz, r, VASES, 1, per=2, solid=True, wd=wd)
    else:
        BN.clusters(dz, r, VASES + CRATES, 1, per=3, solid=True, wd=wd)
    wins = WIN_BARRED if prof == 'hucre' else WIN
    facade(dz, r.x, r.y, r.x + r.w, r.y + 1, contents=('niche', 'win', 'shield', 'torch'), step=4, wins=wins)


def water_glow(dz, every=14):
    """Kanal / havuz ortasında (kıyıya en az 2 hücre) aralıklı soluk mavi ışık; titremez."""
    t = dz.lay.t
    wet = t == Z.W
    deep = wet.copy()
    for (dy, dx) in ((-2, 0), (2, 0), (0, -2), (0, 2), (-1, 0), (1, 0), (0, -1), (0, 1)):
        sh = np.zeros_like(wet)
        sh[max(0, dy):H + min(0, dy), max(0, dx):W + min(0, dx)] = wet[max(0, -dy):H + min(0, -dy), max(0, -dx):W + min(0, -dx)]
        deep &= sh
    placed = []
    for (y, x) in sorted(((int(y), int(x)) for (y, x) in np.argwhere(deep)), key=lambda p: (p[0] // 4, p[1])):
        if all(abs(x - a) + abs(y - b) >= every for (a, b) in placed):
            placed.append((x, y))
            dz.light((x + 0.5) * 16, (y + 0.5) * 16, (0.5, 0.76, 1.0), r=112, energy=0.36, flicker=0)
    return len(placed)


def alley_traps(dz, n=7):
    """Dar sokaklarda (iki duvar arası 3-5 hücre) 3x3 diken tuzağı; kapı/meydan/doğuşa uzak."""
    lay = dz.lay
    t = lay.t
    cands = []
    for y in range(4, H - 4):
        x = 2
        while x < W - 6:
            if t[y, x - 1] == Z.S and t[y, x] == Z.F:
                x2 = x
                while x2 < W - 1 and t[y, x2] == Z.F:
                    x2 += 1
                if 3 <= x2 - x <= 5 and t[y, x2] == Z.S and all(t[y + j, x:x2].all() and t[y + j, x - 1] == Z.S for j in range(-2, 4)):
                    cands.append((x + (x2 - x - 3) // 2, y))
                x = x2
            else:
                x += 1
    dz.rng.shuffle(cands)
    chosen = []
    for (x, y) in cands:
        if len(chosen) >= n:
            break
        if dz.occ[y:y + 3, x:x + 3].any() or dz.gate[y - 3:y + 6, x - 3:x + 6].any() or dz.reserve[y:y + 3, x:x + 3].any():
            continue
        if any(math.dist((x, y), c) < 22 for c in chosen) or math.dist((x, y), SPAWN) < 20:
            continue
        chosen.append((x, y))
        dz.occ[y:y + 3, x:x + 3] = True
        dz.add_obj('tuzak', 'diken', x, y, 3, 3, tur='diken')


def decorate(pl, bank, tl):
    lay = pl.lay
    dz = P.Decorator(lay, bank, tl, seed=SEED, paint=lambda reg: paint_base(pl, bank, tl, reg))
    N = pl.named
    wd = P.wall_distance(lay, cap=3)
    sx, sy = pl.spawn
    dz.spawn = (sx, sy)
    dz.add_obj('dogus', 'Doğuş', sx - 1, sy - 1, 3, 2)
    dz.reserve[sy - 3:sy + 4, sx - 4:sx + 5] = True
    dz.solidify(pl.ledge, check=False)
    for (x, y) in pl.ledge:
        dz.occ[y, x] = True
    for (x, y, sw) in pl.stairs:
        dz.occ[y - 1:y + 1, x:x + sw] = True
        dz.reserve[y + 1:y + 4, x - 1:x + sw + 1] = True
    for (x, y, w, h) in open_decks():   # kapısız köprü güvertesi + iki ucundaki ağız boş kalır
        dz.occ[y:y + h, x - 2:x + w + 2] = True

    # ---- köprü parmaklıkları + kollar
    for (x, y, w, h, g) in BRIDGES:
        if g is None:
            continue
        gy = y + h // 2 - 1
        for gx in range(x, x + w, 2):
            gate(dz, gx, gy, group=g)
    for g, (x, y) in LEVERS.items():
        lever(dz, g, x, y)
    # ---- sur / iç kale parmaklıkları (tek başına)
    gate(dz, 157, 90)
    gate(dz, 161, 59)

    # ---- ÇEŞME MEYDANI
    fountain(dz)

    # ---- HİSAR
    t = N['Taht Salonu']
    ax, ay = 160, 24
    dz.add_obj('sunak', 'Boynuz Sunağı', ax - 1, ay + 1, 4, 2)
    dz.reserve[ay + 1:ay + 5, ax - 1:ax + 3] = True
    for x in (152, 167):
        brazier(dz, x, 25)
    BN.solid_prop(dz, CRATES[2], 148, 25)        # ince ayar 2: eskiden süs sandık (açılmıyordu) - gerçek seçkin sandık 174, 25
    BN.near(BN.chest_at, dz, 174, 25, elite=True)
    facade(dz, t.x, t.y, t.x + t.w, t.y + 1, contents=('shield', 'torch', 'win', 'torch'), step=4)
    ic = N['İç Avlu']
    for (x, y) in ((147, 40), (175, 40), (147, 54), (175, 54)):
        brazier(dz, x, y)
    BN.clusters(dz, ic, CRATES + BARRELS, 2, per=3, solid=True, wd=wd)
    da = N['Dış Avlu']
    BN.solid_prop(dz, BASIN, 159, 76)          # kuyu
    for (x, y) in ((128, 74), (186, 74), (140, 13), (180, 13)):
        brazier(dz, x, y)
    BN.clusters(dz, da, CRATES + BARRELS, 9, per=3, solid=True, wd=wd)
    for nm in ('Kışla', 'Silahhane', 'Ahır', 'Kale Ambarı'):
        interior(dz, N[nm], wd)
    BN.near(BN.chest_at, dz, 125, 30)
    BN.near(BN.chest_at, dz, 196, 58)

    # ---- AŞAĞI ŞEHİR: iç mekanlar + sokak süsleri
    for hs in pl.houses:
        r = hs['room']
        if r is not None:
            interior(dz, r, wd)
    town = N['Aşağı Şehir']
    BN.clusters(dz, town, CRATES + BARRELS, 38, per=3, solid=True, wd=wd)   # ince ayar 26 -> 38, 10 -> 14 (örnek çok daha dolu)
    BN.clusters(dz, town, VASES, 14, per=2, solid=True, wd=wd)   # ince ayar 2: dik duran küpler derinlik katmanında (solid_prop)
    chest_rooms = [hs['room'] for hs in pl.houses if hs['room'] is not None]
    dz.rng.shuffle(chest_rooms)
    for i, r in enumerate(chest_rooms[:6]):
        BN.near(BN.chest_at, dz, r.x + r.w // 2, r.y + 1, elite=(i == 0))

    # ---- KANAL RIHTIMI
    q = N['Kanal Rıhtımı']
    BN.clusters(dz, q, CRATES + BARRELS, 18, per=3, solid=True, wd=wd)

    # ---- tüm kuzey yüzleri (bina önleri, sur, rıhtım duvarı): meşale / pencere-kapı / kalkan ritmi
    # ince ayar: örnekteki gibi sık (5 -> 4, boş yuva yok) + mumlu niş + yüze yaslı merdiven
    facade(dz, 0, 0, W, H, contents=('torch', 'niche', 'win', 'ladder', 'shield', 'niche', 'win', 'torch'), step=4)

    # ---- su ışıltısı (ince ayar): örnekte su parlak mavi; oyunda karanlık ortamda lacivert kalıyordu -> kanal ortasında soluk mavi ışık
    water_glow(dz)

    # ---- kaynaklar (Işık Kristali): şehir, hisar, rıhtım
    for (x, y) in ((126, 60), (190, 40), (150, 66), (165, 50), (20, 50), (70, 70), (30, 100), (100, 128), (130, 150), (60, 170),
                   (110, 190), (192, 130), (40, 30)):
        BN.near(resource, dz, x, y, rad=9)
    return dz


def place_gates(dz):
    pass   # kapılar decorate'te (köprü grupları + sur/iç kale)


def place_traps(dz):
    alley_traps(dz, n=7)


def escape_check(pl, dz):
    """Doğuştan her zemine ulaşılıyor mu; tek kapı ya da bir KOL GRUBU (gruptaki tüm parmaklıklar) kapanınca kopan zemin var mı."""
    lay = pl.lay
    p = lay.passable() & (lay.solid_obj == 0)
    base = lay.bfs([pl.spawn], p)
    unreach = int((p & (base < 0)).sum())
    sets = {}
    for i, o in enumerate(dz.objects):
        if o['type'] == 'kapi':
            key = o['props'].get('grup') or 'tek%d' % i
            sets.setdefault(key, []).extend(P.obj_cells(o))
    fails = []
    for key, cells in sets.items():
        pp = p.copy()
        for (x, y) in cells:
            pp[y, x] = False
        d = lay.bfs([pl.spawn], pp)
        lost = int((pp & (d < 0)).sum())
        if lost > 0:
            fails.append((key, cells[0], lost))
    return {'zemin': int(p.sum()), 'ulasilmaz': unreach, 'kapi_hapsi': fails}


def main(write=False):
    t0 = time.time()
    BN.PLATFORMS = PLATFORMS
    pl = build_layout()
    lay = pl.lay
    os.makedirs(Z.OUT, exist_ok=True)
    print('yerleşim %.1f sn, zemin %d hücre (%%%.1f), su %d' % (time.time() - t0, int((lay.t == Z.F).sum()),
                                                            100.0 * int((lay.t != Z.S).sum()) / (W * H), int((lay.t == Z.W).sum())))
    bank = make_bank()
    tl = Z.TileLayers(W, H, ORDER)
    paint_base(pl, bank, tl)
    floor_cracks(pl, bank, tl)
    paint_platforms(pl, bank, tl)
    paint_bridges(pl, bank, tl)
    print('dalgacık', BN.paint_ripples(pl, bank, tl, random.Random(SEED + 5)))
    dz = decorate(pl, bank, tl)
    place_gates(dz)
    place_traps(dz)
    for o in dz.objects:
        if o['type'] == 'isik':
            o['props']['g'] = '%.2f' % min(1.8, float(o['props']['g']) * BN.LIGHT_GAIN)
            o['props']['r'] = int(round(int(o['props']['r']) * BN.LIGHT_REACH))
    for r in lay.rooms:
        if r.kind != 'giris':
            dz.dwellers(r, r.kind if r.kind in ('salon', 'kalp', 'oda') else 'oda')
    dz.hunter_route('boynuzlu_bekci')
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
    for (nm, cx, cy) in (('meydan', 46, 138), ('taht', 162, 30), ('avlu', 160, 60), ('kanal', 72, 30), ('kopru', 122, 104),
                         ('sehir1', 45, 75), ('sehir2', 100, 140), ('sehir3', 70, 185), ('dogu', 192, 130), ('sur', 130, 50)):
        img.crop(((cx - 32) * 16, (cy - 20) * 16, (cx + 32) * 16, (cy + 20) * 16)).save(os.path.join(Z.OUT, '%s_%s.png' % (ID, nm)))
    print('önizleme %.1f sn' % (time.time() - t0))
    pl.dz, pl.bank, pl.tl = dz, bank, tl
    if write:
        bank.write_files()
        tmx = os.path.join(Z.ZROOT, ID + '.tmx')
        Z.write_tmx(tmx, bank, tl, dz.objects, W, H, props={'ad': TITLE}, hidden=('Engel',))
        print('yazıldı:', tmx)
    return pl


if __name__ == '__main__':
    main('--write' in sys.argv)
