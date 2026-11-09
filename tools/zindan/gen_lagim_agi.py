# LAĞIM AĞI (harita seçimi, 3 yeni haritanın 3.sü, madde 449): "Kanalizasyon Tileseti" (özgün YEŞİL lağım suyu; Et Kuyusu'ndaki kan boyası
# yok) + "Hapishane Assetleri" (hücre kapısı, zincirli mahkum) + "Zindan Eşyaları" (simya masaları, şişeler).
# 214x214. Biçim dili öbür ikisinden farklı: TÜNEL AĞI - her tünelin ortasında akan kanal, iki yanında yürüme yolu; kanaldan yalnız tahta
# köprülerle ya da KAVŞAK HAVUZLARINDA (ortada havuz, çevresinde yol) geçilir. Beş dikey kol tünel güneydeki ANA TOPLAYICI'ya akar,
# aralarında kademeli yatay bağlantı tünelleri; kuzeyde kuru ÜST GALERİ; tünellere kapıyla açılan kuru yan odalar (simyacı laboratuvarı =
# sunak, hırsız ini, pompa odası, mantar bahçesi, hücre koğuşu, bekçi odası, depo, taşkın havuzu). Doğuş: kuzeyde merdivenle inilen
# LAĞIM GİRİŞİ. Bu haritaya özgü GAZ FIÇISI (nesne "fici"): E ile ateşlenir, fitilden sonra patlar, çevresindeki yaratıklara büyük hasar
# (oyuncuya az), bir süre sonra yeniden dolar (dungeon_manager.gd request_barrel). Etkileşimler Et Kuyusu'nunki (tema 'et').
# Duvar ressamı + kanal kenarı Et Kuyusu üretecinden (gen_et_kuyusu, EK), kana boyanmamış özgün sayfalarla.
# Çalıştır: python tools/zindan/gen_lagim_agi.py [--write]  ->  Godot --import ; bake_zindan.gd -- lagim_agi
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
import gen_et_kuyusu as EK  # noqa: E402

ID = 'lagim_agi'
TITLE = 'Lağım Ağı'
W = H = 214
SEED = 8311
TEMA = 'et'
KZ = EK.KZ
HP = EK.HP
ZE = EK.ZE
SAMPLE = EK.SAMPLE
FLOOR_RGB = (147, 124, 98)        # çatlak kumtaşı zeminin baskın rengi (%85): zemin shader'ı taş derzini buna çizer

ORDER = ['Su', 'Su ayrıntı', 'Su ayrıntı 2', 'Zemin', 'Kıyı 2', 'Zemin ayrıntı', 'Zemin süsü', 'Yer süsü', 'Duvar', 'Duvar kenarı', 'Duvar kenarı 2', 'Duvar süsü',
         'Su kapısı', 'Su kapısı 2', 'Eşya alt', 'Eşya', 'Eşya üst', 'Engel']
WATER = [(6, 7), (7, 7), (8, 7), (9, 7), (10, 7)]   # floor_walls_under_water: yeşil lağım suyu yüzeyi (örneğin 'Bottom' katmanı)
TUBE = ('sw', (12, 9, 2, 4))                         # duvardan kanala akan boru (Walls_water_downstairs, animasyonlu)
LADDER = EK.LADDER
# İNCE AYAR (madde 449): örnek Inside.tmx'in dili. Yollar suyun üstünde taş kenarlı PLATFORM: kıyı karoları Water_coasts_downstairs
# (örnekteki 'Water_coasts_topside' tileset'i aslında bu resmi kullanır; dolgu rengi zeminle birebir 147,124,98 -> zemin shader'ı derzi
# kıyıya da çizer). Şablon platform (sayfanın 7..9. satırı, 0..6. sütun): zemin hücresi = üst kenar (satır 7, üstü 5 px saydam) / alt kenar
# (satır 8, yüzün başı) / dolgu (1, 1); su hücresi = yan taşma (sütun 0 / 6, 5 px), yüzün suya sarkan parçası (satır 9), alt köşe (0/6, 9).
# Sayfa 6 kare x 10 satır animasyonlu (dalga çizgisi). İç köşe karosu yok -> su yalnız düz şeritler (duvarda biter ya da başka şeride
# akar), havuz/genişleme yok.
COAST_FILL = (1, 1)
BRIDGE_H3 = ((8, 7), (9, 7), (10, 7))    # dikey kanalın üstünde yatay tahta: sol uç / orta (tekrar) / sağ uç; 2 satır (7, 8)
BRIDGE_V3 = ((6, 7), (6, 8), (6, 9))     # yatay kanalın üstünde dikey tahta: üst uç / orta (tekrar) / alt uç; 2 sütun (6, 7)
CELL_DOOR, CHAINED = EK.CELL_DOOR, EK.CHAINED
RIPPLES = BN.RIPPLES


def coast_anims(path, ms=150):
    """Kıyı sayfası 6 kare x 10 satır (örnekteki animasyon: yerel id + 130 x k, 150 ms). Örnek yalnız kullandığı karoları tanımlar; burada
    ilk karedeki her karo için kareler farklıysa animasyon kurulur (dolgu gibi değişmeyenler durağan kalır)."""
    from PIL import ImageChops
    img = Z.open_sheet(path)
    cols, frames = img.width // 16, img.height // 160
    per = cols * 10
    out = {}
    for lid in range(per):
        c, r = lid % cols, lid // cols
        t0 = img.crop((c * 16, r * 16, c * 16 + 16, r * 16 + 16))
        seq = [lid + per * k for k in range(frames)]
        if any(ImageChops.difference(t0, img.crop((c * 16, (r + 10 * k) * 16, c * 16 + 16, (r + 10 * k) * 16 + 16))).getbbox()
               for k in range(1, frames)):
            out[lid] = [(s, ms) for s in seq]
    return out


def make_bank():
    bank = Z.TilesetBank(ID)
    bank.add('sw', os.path.join(KZ, 'Walls_water_downstairs.png'), anims=Z.sample_anims(SAMPLE, 'Walls_water_downstairs'))
    bank.add('fc', os.path.join(KZ, 'walls_floor_cracks_darker.png'))
    bank.add('wd', os.path.join(KZ, 'Walls_floor_downstairs.png'), name='duvar_kuru.png')
    bank.add('uw', os.path.join(KZ, 'floor_walls_under_water.png'), name='kanal_tabani.png')
    # örnek koyu dalgacık sayfasını kullanır (parlak olan gürültülü çizgiler gibiydi)
    bank.add('wdd', os.path.join(KZ, 'water_details_animation_darker.png'), name='su_dalga.png',
             anims=Z.sample_anims(SAMPLE, 'Water_detilazation'))
    cp = os.path.join(KZ, 'Water_coasts_downstairs.png')
    bank.add('kc', cp, name='kiyi.png', anims=coast_anims(cp))
    for key, fn, nm in (('gw', 'Door_darker-water.png', 'su_kapisi.png'), ('gl', 'Door_darker-lattice.png', 'su_kapisi_izgara.png')):
        bank.add(key, os.path.join(KZ, fn), name=nm, anims=Z.sample_anims(SAMPLE, 'Door_lighter-full', src_override=fn))
    bank.add('kd', os.path.join(KZ, 'Downstairs_objects.png'))
    bank.add('kt', os.path.join(KZ, 'Objects_topstairs.png'))
    bank.add('kf', os.path.join(KZ, 'Fire_animation.png'), anims=Z.sample_anims(SAMPLE, 'Fire_animation'))
    bank.add('kw', os.path.join(KZ, 'web.png'), name='ag_kanal.png')
    bank.add('ks', os.path.join(KZ, 'Spots.png'))
    bank.add('hd', os.path.join(HP, 'Doors.png'), name='hucre_kapilari.png')
    bank.add('hc', os.path.join(HP, 'Chains_prisoner.png'))
    bank.add('ho', os.path.join(HP, 'Interior_objects.png'))
    bank.add('ze', os.path.join(ZE, 'Objects.png'), name='simya_esyalari.png')
    fl = Z.open_sheet(os.path.join(ZE, 'Flasks_monsters.png'))
    bank.add('zf', os.path.join(ZE, 'Flasks_monsters.png'), img=fl, anims=EK.flask_anims(fl))
    bank.add('lt', os.path.join(EK.LT, 'Objects.png'), name='et_nesneleri.png')
    bank.add('eng', 'engel', name='engel.png', img=Z.make_marker_sheet())
    return bank


# ================================================================================================ yerleşim
# dikey kol tüneller: (ad, x) - 13 geniş: 4 yol + 5 kanal + 4 yol; hepsi kuru üst galeriden (y26) ana toplayıcıya (y172) iner. Tepede
# MENFEZ: kanalın üstünde 7x6 duvar bloğu, güney yüzünde ızgaralı su kapısı (örneğin büyük kemeri); kanal oradan çıkar, iki yol bloğun
# yanından galeriye çıkar. Kanal toplayıcının kuzey yolunu keserek ana kanala akar (yol üstünde köprü).
VERT = [('Batı Kolu', 18), ('Orta Batı Kolu', 58), ('Giriş Kolu', 100), ('Orta Doğu Kolu', 146), ('Doğu Kolu', 186)]
TUN_Y0, TUN_Y1 = 26, 172
BULK_Y, BULK_H = 31, 6                  # menfez bloğu satırları 31..36, kanal 37'den başlar
# yatay bağlantı tünelleri: (ad, y, sol kol, sağ kol) - 11 boy: KANAL KUZEY DUVARINA YASLI (3) + tek geniş yol (8); yüzden kanala boru
# akar. Kanal iki yandaki kolların yolunu keserek kol kanallarına T ile bağlanır (yol üstünde dikey tahta köprü).
HORZ = [('Kuzey Bağlantı', 50, 0, 1), ('Orta Bağlantı', 96, 1, 2), ('Doğu Bağlantı', 60, 2, 3), ('Güney Doğu Bağlantı', 120, 3, 4),
        ('Güney Batı Bağlantı', 132, 0, 1)]
COLLECTOR = (10, 172, 195, 21)          # x10..204 y172..192: kanal 7 (y179..185) duvardan duvara, yollar 7
FLOOD_ROWS = 10                         # Taşkın Havuzu'nun kuzey 10 satırı duvardan duvara su (düz kıyı)
SIDE = [   # (ad, x, y, w, h, tür, kapı (x, y, w, h))
    ('Lağım Girişi', 90, 6, 34, 18, 'giris', None),
    ('Simyacı Laboratuvarı', 122, 28, 18, 20, 'lab', (113, 36, 9, 3)),
    ('Hırsız İni', 36, 68, 18, 20, 'oda', (31, 76, 5, 3)),
    ('Pompa Odası', 163, 28, 18, 18, 'kanal', (159, 34, 4, 3)),
    ('Mantar Bahçesi', 72, 114, 24, 22, 'bahce', (96, 124, 4, 3)),
    ('Hücre Koğuşu', 162, 138, 22, 26, 'hucre', (159, 148, 3, 3)),
    ('Bekçi Odası', 36, 150, 18, 16, 'oda', (31, 156, 5, 3)),
    ('Depo', 122, 82, 18, 22, 'oda', (141, 90, 5, 3)),
    ('Taşkın Havuzu', 116, 140, 26, 24, 'kalp', (142, 150, 4, 3)),
]
UPPER = (18, 26, 181, 5)                # kuru üst galeri x18..198 y26..30 (kol tepelerini bağlar)
SPAWN = (107, 15)
BRIDGE_EVERY = 26


def build_layout():
    pl = BN.Plan()
    lay = pl.lay
    R, C = pl.room, pl.corr
    pl.bridges = []        # ('h', x0, y, boy): dikey kanal üstü yatay tahta (2 satır) | ('v', x, y0, boy): yatay kanal üstü dikey (2 sütun)
    pl.gates = []          # menfez su kapıları (x, y) 5x5
    chan = np.zeros((H, W), bool)
    t = lay.t

    for (nm, x) in VERT:
        y0 = 24 if nm == 'Giriş Kolu' else TUN_Y0     # Giriş Kolu doğuş odasına (y6..23) bağlanır
        R(nm, x, y0, 13, TUN_Y1 - y0, 'kanal')
        chan[BULK_Y + BULK_H:TUN_Y1, x + 4:x + 9] = True
    for (nm, y, a, b) in HORZ:
        xl, xr = VERT[a][1], VERT[b][1]
        R(nm, xl + 13, y, xr - xl - 13, 11, 'kanal')
        chan[y:y + 3, xl + 9:xr + 4] = True                # sol kol kanalından sağ kol kanalına (iki yolu keser)
    cx0, cy0, cw, chh = COLLECTOR
    R('Ana Toplayıcı', cx0, cy0, cw, chh, 'kalp')
    chan[cy0 + 7:cy0 + 14, cx0:cx0 + cw] = True
    for (nm, x) in VERT:
        chan[cy0:cy0 + 7, x + 4:x + 9] = True              # kol kanalı toplayıcının kuzey yolunu keserek ana kanala akar
    for (nm, x, y, w, h, kind, door) in SIDE:
        R(nm, x, y, w, h, kind)
        if door:
            C(*door)
    C(*UPPER)
    th = pl.named['Taşkın Havuzu']
    chan[th.y:th.y + FLOOD_ROWS, th.x:th.x + th.w] = True
    t[chan & (t == Z.F)] = Z.W
    for (nm, x) in VERT:                                  # menfez bloğu (kanalın çıktığı duvar), yollar yanından geçer
        t[BULK_Y:BULK_Y + BULK_H, x + 3:x + 10] = Z.S
        pl.gates.append((x + 4, BULK_Y + BULK_H - 3))

    def bridge(kind, x, y, n):
        """n: uçlar dahil boy; uçlar zeminde, aradakiler suda olmalı (yürünür olur)."""
        if kind == 'h':
            mid, ends = t[y:y + 2, x + 1:x + n - 1], (t[y - 1:y + 3, x], t[y - 1:y + 3, x + n - 1])
        else:
            mid, ends = t[y + 1:y + n - 1, x:x + 2], (t[y, x - 1:x + 3], t[y + n - 1, x - 1:x + 3])
        if not (mid == Z.W).all() or not all((e == Z.F).all() for e in ends):
            return False
        mid[...] = Z.F
        pl.bridges.append((kind, x, y, n))
        return True

    for (nm, x) in VERT:                                  # kol boyunca BRIDGE_EVERY'de bir + toplayıcının kuzey yolunda
        for by in range(BULK_Y + BULK_H + 10, TUN_Y1 - 4, BRIDGE_EVERY):
            for d in (0, 2, -2, 4, -4):
                if bridge('h', x + 3, by + d, 7):
                    break
        bridge('h', x + 3, cy0 + 2, 7)
    for (nm, y, a, b) in HORZ:                            # bağlantı kanalının kestiği kol yolları
        xl, xr = VERT[a][1], VERT[b][1]
        bridge('v', xl + 10, y - 1, 5)
        bridge('v', xr + 1, y - 1, 5)
    for bx in range(30, 200, 34):                         # ana kanal: 7 boy
        for d in (0, 3, -3, 6):
            if bridge('v', bx + d, cy0 + 6, 9):
                break

    lay.fix_thickness(min_v=4, min_h=2)
    BN.KD.normalize_steps(lay)
    lay.fix_thickness(min_v=4, min_h=2)
    pl.spawn = SPAWN
    lay.keep_main_component(SPAWN)
    return pl


# ================================================================================================ boyama
def paint_base(pl, bank, tl, region=None):
    lay = pl.lay
    EK.paint_walls(lay, bank, tl, region=region, caps_by_key={'sw': (0, 6)})   # madde 492: 2./3. yüz satırının ve su yüzünün paket uç parçaları
    P.paint_wall_edges(lay, bank, tl, 'wd', region=region)   # madde 492: duvar kütlesinin kenar + köşeleri paketin kendi karolarıyla
    t = lay.t
    x0, y0, x1, y1 = region or (0, 0, W, H)
    for y in range(max(0, y0), min(H, y1)):
        for x in range(max(0, x0), min(W, x1)):
            if t[y, x] == Z.W:
                tl.put('Su', x, y, bank.gid('uw', *WATER[BN._h(x, y) % len(WATER)]))
                tl.put('Zemin', x, y, 0)
            elif t[y, x] == Z.S and y + 1 < H and t[y + 1, x] == Z.W:
                # suya bakan yüzün alt karosu (su çizgisi) altı saydam: paketin örneğinde altında SU var; zemin görünüyordu (madde 492)
                tl.put('Su', x, y, bank.gid('uw', *WATER[BN._h(x, y) % len(WATER)]))
                tl.put('Zemin', x, y, 0)


def bridge_cells(pl):
    """Köprünün yürünür hücreleri (uçlar hariç): görselde SU sayılır (kıyı köprünün altında devam eder)."""
    out = set()
    for (kind, x, y, n) in pl.bridges:
        for i in range(1, n - 1):
            for j in range(2):
                out.add((x + i, y + j) if kind == 'h' else (x + j, y + i))
    return out


def paint_coasts(pl, bank, tl):
    """Örnek şablon platformundan kıyı (bkz. ORDER üstündeki not). Su hücresinde iki parça gerekirse ikincisi 'Kıyı 2'ye."""
    t = pl.lay.t
    bc = pl.bcells

    def wv(x, y):
        return 0 <= x < W and 0 <= y < H and (t[y, x] == Z.W or (x, y) in bc)

    def fv(x, y):
        return 0 <= x < W and 0 <= y < H and t[y, x] == Z.F and (x, y) not in bc

    coast = np.zeros((H, W), bool)
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            h = BN._h(x, y)
            if fv(x, y):
                wN, wS, wE, wW = wv(x, y - 1), wv(x, y + 1), wv(x + 1, y), wv(x - 1, y)
                if not (wN or wS or wE or wW):
                    if any(wv(x + dx, y + dy) for dx in (-1, 1) for dy in (-1, 1)):   # iç köşe (olmamalı): düz dolgu
                        tl.put('Zemin', x, y, bank.gid('kc', *COAST_FILL))
                        coast[y, x] = True
                    continue
                col = 1 if (wW and not wE) else (5 if (wE and not wW) else 2 + h % 3)
                tile = (col, 8) if wS else ((col, 7) if wN else COAST_FILL)
                tl.put('Su', x, y, bank.gid('uw', *WATER[h % len(WATER)]))   # üst kenarın saydam 5 px'i suyu gösterir
                tl.put('Zemin', x, y, bank.gid('kc', *tile))
                coast[y, x] = True
            elif wv(x, y):
                pieces = []
                if fv(x, y - 1):
                    pieces.append((1 + h % 5, 9))                                 # yüzün suya sarkan parçası
                for (dx, top, mid, bot) in ((1, (0, 7), (0, 4), (0, 8)), (-1, (6, 7), (3, 4), (6, 8))):
                    if fv(x + dx, y):                                             # yan taşma (komşu zeminin türüne göre)
                        pieces.append(top if wv(x + dx, y - 1) else (bot if wv(x + dx, y + 1) else mid))
                    elif not fv(x, y - 1) and fv(x + dx, y - 1) and wv(x + dx, y):
                        pieces.append(((0, 9) if dx == 1 else (6, 9)))            # alt köşe: yüzün yan ucu
                for lname, p in zip(('Zemin', 'Kıyı 2'), pieces):
                    tl.put(lname, x, y, bank.gid('kc', *p))
                if pieces:
                    coast[y, x] = True
    pl.coast = coast
    return int(coast.sum())


def paint_bridges(pl, bank, tl):
    for (kind, x, y, n) in pl.bridges:
        for i in range(n):
            part = 0 if i == 0 else (2 if i == n - 1 else 1)
            if kind == 'h':
                c, r = BRIDGE_H3[part]
                tl.put('Zemin ayrıntı', x + i, y, bank.gid('kd', c, r))
                tl.put('Zemin ayrıntı', x + i, y + 1, bank.gid('kd', c, r + 1))
            else:
                c, r = BRIDGE_V3[part]
                tl.put('Zemin ayrıntı', x, y + i, bank.gid('kd', c, r))
                tl.put('Zemin ayrıntı', x + 1, y + i, bank.gid('kd', c + 1, r))


def paint_floor(pl, bank, tl):
    lay = pl.lay
    t = lay.t
    pl.bcells = bcells = bridge_cells(pl)
    for (x, y) in bcells:
        tl.put('Su', x, y, bank.gid('uw', *WATER[BN._h(x, y) % len(WATER)]))
        tl.put('Zemin', x, y, 0)
    wet = (t == Z.W)
    for (x, y) in bcells:
        wet[y, x] = True
    near_w = wet.copy()
    near_w[1:, :] |= wet[:-1, :]
    near_w[:-1, :] |= wet[1:, :]
    near_w[:, 1:] |= wet[:, :-1]
    near_w[:, :-1] |= wet[:, 1:]
    near_w[1:, 1:] |= wet[:-1, :-1]
    near_w[1:, :-1] |= wet[:-1, 1:]
    near_w[:-1, 1:] |= wet[1:, :-1]
    near_w[:-1, :-1] |= wet[1:, 1:]
    # duvar kenarı çerçevesi yalnız duvara bakan kenarda (suya bakan kenar kıyı karosu)
    P.floor_frame(lay, bank, tl, 'fc', EK.FRAME, against_up=(), against_side=(Z.S,), skip=lambda x, y: bool(near_w[y, x]))
    print('kıyı', paint_coasts(pl, bank, tl))
    paint_bridges(pl, bank, tl)
    dist = P.wall_distance(lay, cap=5)
    dry = (t == Z.F) & ~near_w
    P.floor_details(lay, bank, tl, 'wd', EK.BRICK_BITS, density=0.12, seed=SEED + 2, layer='Zemin süsü', mask=(dist == 1) & dry)
    P.floor_details(lay, bank, tl, 'ks', EK.SPOTS, density=0.04, seed=SEED, layer='Zemin süsü', mask=(dist >= 2) & (t == Z.F) & ~wet)


def paint_ripples(pl, bank, tl, rng):
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
                Z.stamp(bank, tl, layer, 'wdd', (sx, sy, w, h), x, y)
                used[y:y + h, x:x + w] = True
                placed += 1
                break
    return placed


# ================================================================================================ süsleme
def facade(dz, x0, y0, x1, y1, contents=('fire', 'arch', 'none', 'web'), step=6):
    for (y, xa, xb) in BN.face_runs(dz, x0, y0, x1, y1):
        if xb - xa < 4:
            continue
        for i, x in enumerate(range(xa + 1, xb - 3, step)):
            if dz.occ[y - 3:y, x:x + 3].any():
                continue
            kind = contents[(i + xa // 3 + y) % len(contents)]
            if kind == 'fire':
                BN.solid_prop(dz, EK.FIRES[0], x, y, light=P.AMBER, light_r=130)
            elif kind == 'arch':
                spec = EK.ARCH2[(x + y) % len(EK.ARCH2)]
                if dz.face_free(x, y - 2, 3, 2):
                    dz.put('Duvar süsü', spec, x, y - 2)
                    dz.occ[y - 2:y, x:x + 3] = True
            elif kind == 'web':
                spec = EK.WEBS[(x + y) % len(EK.WEBS)]
                if dz.face_free(x, y - 3, spec[1][2], 3):
                    dz.put('Duvar süsü', (spec[0], (spec[1][0], spec[1][1], spec[1][2], 3)), x, y - 3)
                    dz.occ[y - 3:y, x:x + spec[1][2]] = True


def tubes(dz, pl):
    """Kanala yaslı kuzey yüzlerinden (yatay bağlantı tünelleri) kanala akan borular: boru yüzde, akıntı suya iner."""
    lay = pl.lay
    t = lay.t
    n = 0
    last = {}
    for y in range(4, H - 1):
        for x in range(1, W - 2):
            if t[y, x] == Z.W and t[y, x + 1] == Z.W and dz.is_face(x, y - 1, 1) and dz.is_face(x + 1, y - 1, 1) and dz.is_face(x, y - 3, 3)                     and dz.is_face(x + 1, y - 3, 3) and x - last.get(y, -99) >= 9 and not dz.occ[y - 3:y, x:x + 2].any():
                dz.put('Duvar süsü', TUBE, x, y - 3)
                dz.occ[y - 3:y, x:x + 2] = True
                last[y] = x
                n += 1
    return n


def barrel(dz, x, y):
    """GAZ FIÇISI (çalışma anında çizilir, 2x2): taban satırı engel."""
    if not dz.is_free(x, y, 2, 2, allow_reserve=True) or not dz.solidify([(x + i, y + j) for j in range(2) for i in range(2)]):  # ince ayar 2: dikdörtgenin TAMAMI engel (çalışma anında çizilen nesnenin arkasına/içine girilip üstüne çiziliyordu)
        return False
    dz.occ[y - 1:y + 2, x - 1:x + 3] = True
    dz.add_obj('fici', 'Gaz Fıçısı', x, y, 2, 2, tur='gaz')
    return True


def resource(dz, x, y):
    """Et Kesesi (Kan Kehribarı) düğümü: çalışma anında çizilir (3x3 görsel), tabanı 2 hücre engel."""
    if not dz.is_free(x - 1, y - 2, 4, 3, allow_reserve=True) or not dz.solidify([(x + i, y - j) for j in range(3) for i in range(2)]):  # ince ayar 2: dikdörtgenin TAMAMI engel (çalışma anında çizilen nesnenin arkasına/içine girilip üstüne çiziliyordu)
        return False
    dz.occ[y - 2:y + 1, x - 1:x + 3] = True
    dz.add_obj('kaynak', 'et_kesesi', x, y - 2, 2, 3, tur='et_kesesi')
    return True


def wall_spots(dz, r, wd):
    """Odanın duvar dibindeki (wd == 1) zemin hücreleri - fıçı / sandık yeri."""
    cells = r.cells if r.cells is not None else [(x, y) for y in range(r.y, r.y + r.h) for x in range(r.x, r.x + r.w)]
    return [(x, y) for (x, y) in cells if dz.lay.t[y, x] == Z.F and wd[y, x] == 1]


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
    for (x, y) in pl.bcells:
        dz.reserve[y, x] = True
    for (kind, x, y, n) in pl.bridges:                    # köprü ayakları + önündeki 2 hücre boş kalır (kaynak/sandık çıkışı tıkamasın;
        if kind == 'h':                                   # kaynak/sandık reserve'e izin verir, occ'a vermez)
            dz.occ[max(0, y - 1):y + 3, max(0, x - 2):x + n + 2] = True
        else:
            dz.occ[max(0, y - 2):y + n + 2, max(0, x - 1):x + 3] = True

    # ---- LAĞIM GİRİŞİ: yüzde inilen merdiven, iki ateş kazanı
    g = N['Lağım Girişi']
    if dz.face_free(sx, g.y - 4, 2, 4):
        dz.put('Duvar süsü', LADDER, sx, g.y - 4)
        dz.occ[g.y - 4:g.y, sx:sx + 2] = True
    for x in (g.x + 3, g.x + g.w - 6):
        BN.solid_prop(dz, EK.FIRES[0], x, g.y + 4, light=P.AMBER, light_r=140)

    # ---- SİMYACI LABORATUVARI: simya masası = sunak, yanında simyacı
    lab = N['Simyacı Laboratuvarı']
    dz.altar(lab, EK.ALCH_TABLES[0], 'Simyacı', light=P.AMBER, light_r=140)
    dz.npc_spot(lab, 'simyaci')
    for o in dz.objects:   # ince ayar 2: simyacının durduğu hücre engel (içinden yürünüp üstüne çiziliyordu)
        if o['type'] == 'npc':
            dz.solidify([(o['x'] // 16, o['y'] // 16)], check=False)
    BN.clusters(dz, lab, EK.ALCH_TABLES[1:] + EK.ALCH_SHELVES, 2, per=2, solid=True, wd=wd)
    BN.clusters(dz, lab, EK.FLASKS, 2, per=2, solid=True, wd=wd)

    # ---- yan odalar
    for nm in ('Hırsız İni', 'Depo', 'Pompa Odası', 'Bekçi Odası'):
        r = N[nm]
        BN.clusters(dz, r, EK.CRATES + EK.BARRELS + EK.BOXES, 3, per=3, solid=True, wd=wd)
    BN.clusters(dz, N['Mantar Bahçesi'], EK.MUSHROOMS, 6, per=3, solid=True, wd=None)
    BN.clusters(dz, N['Mantar Bahçesi'], EK.FLESH_PLANTS[:2], 2, per=1, solid=True, wd=None)
    hk = N['Hücre Koğuşu']
    x = hk.x + 1
    while x + 2 <= hk.x + hk.w - 1:          # kuzey yüzünde hücre kapıları + zincirli mahkumlar
        if dz.face_free(x, hk.y - 3, 2, 3):
            dz.put('Duvar süsü', CELL_DOOR if (x // 3) % 2 == 0 else EK.CELL_WINDOW, x, hk.y - 3)
            dz.occ[hk.y - 3:hk.y, x:x + 2] = True
            x += 4
        else:
            x += 1
    BN.clusters(dz, hk, CHAINED, 2, per=1, solid=True, wd=wd)
    BN.clusters(dz, hk, EK.HAY, 2, per=1, wd=None)

    # ---- MENFEZLER: kol kanalının çıktığı ızgaralı büyük su kapısı (örnek: Door_water + Door_arc üst üste), yüze 3 + suya 2 satır
    for (gx, gy) in pl.gates:
        Z.stamp(bank, tl, 'Su kapısı', 'gw', (0, 0, 5, 5), gx, gy)
        Z.stamp(bank, tl, 'Su kapısı 2', 'gl', (0, 0, 5, 5), gx, gy)
        dz.occ[gy - 3:gy + 5, gx - 1:gx + 6] = True
        dz.light((gx + 2.5) * 16, (gy + 4) * 16, (0.45, 1.0, 0.55), r=130, energy=0.7, flicker=0)

    # ---- tüneller: kanal üstüne akan borular, yüz süsleri, duvar diplerinde fıçı/sandık ÖBEKLERİ (örnekteki gibi köşelerde toplu)
    print('boru', tubes(dz, pl))
    facade(dz, 0, 0, W, H)
    for r in lay.rooms:
        if r.kind in ('kanal', 'kalp'):
            n = max(1, (r.w * r.h) // 700)
            BN.clusters(dz, r, EK.BARRELS + EK.BOXES, n, per=3, solid=True, wd=wd)
            BN.clusters(dz, r, EK.MUSHROOMS, n, per=3, solid=True, wd=wd)   # ince ayar 2: dik mantar derinlik katmanında (küçükse engel değil)

    # ---- ZEHİRLİ SU IŞILTISI (kanal boyunca soluk yeşil ışık, kaynak yok: suyun kendisi) + köprü başlarında ateş kazanı (örnekte
    # platform köşelerinde); yalnız geniş yollarda (toplayıcı) - 4 hücrelik kol yolunu kazan tıkardı
    t = lay.t
    glow = []
    for (y, x) in np.argwhere(t == Z.W):
        x, y = int(x), int(y)
        if all(abs(x - a) + abs(y - b) >= 15 for (a, b) in glow):
            glow.append((x, y))   # ince ayar: 0,55 -> 0,4 ve daha az doygun (oyunda kanal neon yeşil kaçıyordu)
            dz.light((x + 0.5) * 16, (y + 0.5) * 16, (0.55, 0.95, 0.62), r=104, energy=0.4, flicker=0)
    cx0, cy0, cw, chh = COLLECTOR
    for (kind, x, y, n) in pl.bridges:
        if kind == 'v' and y == cy0 + 6:                  # ana kanal köprüsü: iki yakada köprünün yanında
            BN.solid_prop(dz, EK.FIRES[0], x + 3, cy0 + 3, light=P.AMBER, light_r=130)
            BN.solid_prop(dz, EK.FIRES[0], x - 4, cy0 + 16, light=P.AMBER, light_r=130)

    # ---- GAZ FIÇILARI: tünel yollarında ve kavşaklarda duvar dibinde, birbirinden uzak
    spots = []
    for r in lay.rooms:
        if r.kind in ('kanal', 'kalp'):
            spots += wall_spots(dz, r, wd)
    rng.shuffle(spots)
    placed = []
    for (x, y) in spots:
        if len(placed) >= 16:
            break
        if any(math.dist((x, y), p) < 22 for p in placed) or math.dist((x, y), pl.spawn) < 24:
            continue
        if barrel(dz, x, y):
            placed.append((x, y))
    print('gaz fıçısı', len(placed))

    # ---- kaynaklar (Et Kesesi), sandıklar
    for (x, y) in ((40, 80), (80, 120), (128, 92), (170, 36), (170, 150), (124, 150), (30, 60), (110, 60), (160, 110), (40, 158),
                   (70, 186), (150, 186), (196, 80)):
        BN.near(resource, dz, x, y, rad=9)
    for (x, y, e) in ((44, 74, True), (128, 90, False), (166, 32, False), (80, 130, False), (176, 160, False), (40, 160, False),
                      (130, 156, True), (24, 182, False), (190, 186, False)):
        BN.near(BN.chest_at, dz, x, y, elite=e)
    return dz


def place_gates(dz):
    """Kapı YOK: yan odalar tek girişli (kapı hapseder), tüneller geniş; bu haritanın etkileşimi gaz fıçısı."""
    return


def place_traps(dz):
    dz.traps('giyotin', count=5)


def escape_check(pl, dz):
    lay = pl.lay
    p = lay.passable() & (lay.solid_obj == 0)
    base = lay.bfs([pl.spawn], p)
    unreach = int((p & (base < 0)).sum())
    fails = []
    for i, o in enumerate(dz.objects):
        if o['type'] != 'kapi':
            continue
        pp = p.copy()
        for (x, y) in P.obj_cells(o):
            pp[y, x] = False
        d = lay.bfs([pl.spawn], pp)
        lost = int((pp & (d < 0)).sum())
        if lost > 0:
            fails.append((i, lost))
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
    paint_floor(pl, bank, tl)
    dz = decorate(pl, bank, tl)
    print('dalgacık', paint_ripples(pl, bank, tl, random.Random(SEED + 5)))
    place_gates(dz)
    place_traps(dz)
    for o in dz.objects:
        if o['type'] == 'isik':
            o['props']['g'] = '%.2f' % min(1.8, float(o['props']['g']) * BN.LIGHT_GAIN)
            o['props']['r'] = int(round(int(o['props']['r']) * BN.LIGHT_REACH))
    for r in lay.rooms:
        if r.kind != 'giris':
            dz.dwellers(r, r.kind if r.kind in ('kanal', 'hucre', 'bahce', 'lab', 'kalp', 'oda') else 'oda')
    dz.hunter_route('kuyu_kasabi')
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
    for (nm, cx, cy) in (('giris', 107, 30), ('menfez', 30, 40), ('baglanti', 40, 56), ('lab', 131, 40), ('toplayici', 64, 180),
                         ('kol', 24, 100), ('bahce', 84, 125), ('hucre', 172, 150), ('havuz', 128, 150)):
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
