# KADİM DERİNLİKLER (alternatif oyun haritası, madde 441): ana harita büyüklüğünde (256x256 hücre) zindan haritası.
# Üç zindan setinin (Kemik Mahzeni kriptası / Et Kuyusu kanalizasyonu / Boynuzlu Kapı kristal tapınağı) KENDİ boyayıcıları ve süsleyicileri
# bölge bölge kullanılır (gen_kemik_mahzeni / gen_et_kuyusu / gen_boynuzlu_kapi + zindan_core / zindan_paint; o dosyalara dokunulmaz).
#   - 5 DEV SALON: merkezde Büyük Salon (kemik, doğuş), köşelerde Kemik Katedrali (kemik), Boynuz Tapınağı (boynuz), Kan Havzası (et,
#     köprülü kan kanalları), Kristal Mağarası (boynuz).
#   - ANA YOLLAR (8 hücre): salonları halka + çapraz olarak bağlar; kovalanan kalabalık için hep geniş kaçış (kapı/tuzak konmaz).
#   - ODA KÜMELERİ: yolların arasındaki bloklarda eski zindanlar gibi 5 hücrelik koridorlu küçük odalar + özel odalar (kalp/sunak, lahit,
#     kanal, mağara...), kümeler yollara/salonlara birden çok bağlantıyla bağlanır.
# KAÇIŞ kuralı (zindanlarla aynı, üretimde kanıtlanır): her oda bir dev salona ulaşır; tek bir kapı kapalıyken ya da herhangi bir dar
# koridor hücresinde 5x5 tıkanma (kovalayan grup) varken de. Hedef "çıkış" yerine dev salonlar.
# Bölge sınırı: oda hücresi odanın teması, yol hücresi yolun teması, koridor uçlarındaki odaların teması (karışıksa yakın olan), duvar yüzü
# altındaki zeminin teması, kalan kaya en yakın zeminin teması. Her tema tüm haritayı kendi katmanlarına boyar, tema maskesiyle birleşir.
# Çalıştır: python tools/zindan/gen_kadim_derinlikler.py [--write]   (önizleme: tools/zindan/out/kadim_*.png)
# --write: harita/zindan/kadim_derinlikler.tmx + harita/zindan/kadim_derinlikler/ (PNG + .tsx + runtime/). Sonra Godot --import +
#   -s res://tools/zindan/bake_zindan.gd -- kadim_derinlikler  ->  scenes/zindan/kadim_derinlikler_baked.tscn + _data.tres
# Tiled'da elle düzenlersen üreteci yeniden ÇALIŞTIRMA (üzerine yazar), yalnız pişir.
import heapq
import math
import os
import random
import sys
import time
from collections import deque

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zindan_core as Z  # noqa: E402
import zindan_paint as P  # noqa: E402
import gen_kemik_mahzeni as KM  # noqa: E402
import gen_et_kuyusu as EK  # noqa: E402
import gen_boynuzlu_kapi as BK  # noqa: E402

ID = 'kadim_derinlikler'
TITLE = 'Kadim Derinlikler'
W = H = 256
SEED = 4411
TMX = os.path.join(Z.ZROOT, ID + '.tmx')
OUT_PREFIX = 'kadim'
CROPS = (('merkez', (84, 96, 172, 160)), ('kume', (44, 36, 124, 104)), ('havza', (8, 196, 88, 250)), ('magara', (170, 190, 250, 250)))
ORDER = ['Kan', 'Zemin', 'Zemin ayrıntı', 'Zemin desen', 'Zemin süsü', 'Duvar', 'Duvar süsü', 'Eşya alt', 'Eşya', 'Eşya üst', 'Engel']
BASE_LAYERS = ('Kan', 'Zemin', 'Zemin ayrıntı', 'Zemin desen', 'Zemin süsü', 'Duvar')
THEMES = ('kemik', 'et', 'boynuz')
TID = {'kemik': 1, 'et': 2, 'boynuz': 3}
MOD = {'kemik': KM, 'et': EK, 'boynuz': BK}
CW = Z.CORRIDOR_W
RW = 8  # ana yol genişliği

# ---- dev salonlar: (ad, tema, (x, y, w, h))
HALLS = [
    ('Büyük Salon', 'kemik', (86, 102, 84, 52)),
    ('Kemik Katedrali', 'kemik', (14, 12, 60, 36)),
    ('Boynuz Tapınağı', 'boynuz', (182, 12, 60, 36)),
    ('Kan Havzası', 'et', (14, 202, 62, 44), {'kanal': True}),
    ('Kristal Mağarası', 'boynuz', (178, 196, 66, 50), {'magara': True}),
]
# ---- ana yollar: ((x, y, w, h), tema ya da (x, y) -> tema). Halka (K-T kuzey, K-E batı, T-M doğu, E-M güney) + merkezden 4 kol.
# Tema geçişi yolun ortasında değil, kavşak kenarında ya da salon girişinde (yolun ortasında düz kesik "yarım kalmış" gibi duruyordu).
ROADS = [
    ((74, 26, 108, RW), 'kemik'),
    ((124, 34, RW, 68), 'kemik'),
    ((36, 48, RW, 154), lambda x, y: 'kemik' if y < 132 else 'et'),
    ((44, 124, 42, RW), 'kemik'),
    ((210, 48, RW, 148), 'boynuz'),
    ((170, 124, 40, RW), 'boynuz'),
    ((76, 216, 102, RW), 'et'),
    ((124, 154, RW, 62), 'et'),
]
# ---- oda kümeleri: (tema, ad, bölge (x0, y0, x1, y1), [(adet, (wmin, wmax), (hmin, hmax), tür)]) - türler temanın kendi zindanındaki gibi
DISTRICTS = [
    ('kemik', 'Kuzeybatı Mahzenleri', (48, 40, 120, 118),
     [(1, (26, 28), (14, 16), 'kalp'), (2, (17, 21), (10, 12), 'lahit'), (2, (12, 15), (8, 10), 'kemik'), (1, (16, 19), (10, 11), 'sutun'),
      (7, (8, 11), (6, 8), 'oda')]),
    ('kemik', 'Batı Kriptası', (4, 56, 32, 132), [(1, (12, 15), (8, 10), 'kemik'), (4, (8, 11), (6, 8), 'oda')]),
    ('kemik', 'Kuzey Hücreleri', (82, 3, 128, 20), [(2, (8, 11), (6, 7), 'oda')]),
    ('boynuz', 'Kuzeydoğu Tapınakları', (136, 40, 206, 118),
     [(1, (26, 30), (14, 16), 'kalp'), (2, (20, 24), (13, 15), 'magara'), (1, (18, 21), (12, 13), 'kristal'), (1, (18, 21), (10, 12), 'salon'),
      (6, (9, 12), (7, 9), 'oda')]),
    ('boynuz', 'Doğu Yarıkları', (222, 54, 252, 192), [(1, (18, 22), (12, 13), 'kristal'), (1, (18, 22), (10, 12), 'salon'), (4, (9, 12), (7, 9), 'oda')]),
    ('boynuz', 'Kuzey Tapınak Odaları', (130, 3, 174, 20), [(2, (9, 12), (6, 7), 'oda')]),
    ('et', 'Güneybatı Kanalları', (48, 138, 120, 210),
     [(1, (26, 28), (14, 16), 'kalp'), (2, (19, 23), (12, 14), 'kanal'), (1, (17, 20), (10, 12), 'hucre'), (1, (14, 17), (10, 12), 'bahce'),
      (5, (8, 11), (6, 8), 'oda')]),
    ('et', 'Güneydoğu Kuyuları', (136, 138, 206, 210),
     [(1, (19, 23), (12, 14), 'kanal'), (2, (17, 20), (10, 12), 'hucre'), (1, (14, 17), (10, 12), 'bahce'), (6, (8, 11), (6, 8), 'oda')]),
    ('et', 'Batı Lağımları', (4, 134, 32, 196), [(1, (14, 17), (10, 12), 'bahce'), (3, (8, 11), (6, 8), 'oda')]),
    ('et', 'Güney Hücreleri', (84, 230, 170, 253), [(3, (8, 11), (6, 8), 'oda')]),
]


# ================================================================================================ hızlı bağlılık (scipy yok)
def label(p):
    """4-komşu bağlı bileşen etiketi (0 = geçilmez). Satır koşuları + birleşim-bul: 256x256'da ~5-10 ms (Python BFS ~100 ms)."""
    Hh, Ww = p.shape
    pad = np.zeros((Hh, Ww + 2), np.int8)
    pad[:, 1:-1] = p
    d = np.diff(pad, axis=1)
    st = np.argwhere(d == 1)
    en = np.argwhere(d == -1)
    n = len(st)
    if n == 0:
        return np.zeros((Hh, Ww), np.int64)
    rows = st[:, 0]
    s = st[:, 1].tolist()
    e = en[:, 1].tolist()
    rs = np.searchsorted(rows, np.arange(Hh + 1)).tolist()
    parent = list(range(n))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for y in range(1, Hh):
        i, i1, j, j1 = rs[y - 1], rs[y], rs[y], rs[y + 1]
        while i < i1 and j < j1:
            if s[i] < e[j] and s[j] < e[i]:
                a, b = find(i), find(j)
                if a != b:
                    parent[a] = b
            if e[i] < e[j]:
                i += 1
            else:
                j += 1
    roots = np.array([find(k) for k in range(n)], np.int64) + 1
    flat = np.zeros(Hh * (Ww + 1), np.int64)
    base = rows.astype(np.int64) * (Ww + 1)
    flat[base + st[:, 1]] = roots
    flat[base + en[:, 1]] = -roots
    return np.cumsum(flat.reshape(Hh, Ww + 1), axis=1)[:, :Ww]


def _fast_connected_ok(self, cells):
    """Decorator._connected_ok yerine (256x256'da her solidify'da iki tam BFS dakikalar sürüyordu): önce yerel pencere (nesnenin
    çevresi 6 hücre) - her yerel bileşen bölünmeden kalıyorsa harita bölünemez; bölünüyorsa tam etiketle eski kuralın aynısı."""
    lay = self.lay
    if not cells:
        return True
    p = (lay.t == Z.F) & (lay.solid_obj == 0) & ~self.gate
    xs = [c[0] for c in cells]
    ys = [c[1] for c in cells]
    x0, x1 = max(0, min(xs) - 6), min(lay.W, max(xs) + 7)
    y0, y1 = max(0, min(ys) - 6), min(lay.H, max(ys) + 7)
    sub = p[y0:y1, x0:x1]
    sub2 = sub.copy()
    for (x, y) in cells:
        sub2[y - y0, x - x0] = False
    a = label(sub)[sub2]
    if a.size == 0:
        return True
    b = label(sub2)[sub2]
    if len(np.unique(a * 1000003 + b)) == len(np.unique(a)):
        return True
    l1 = label(p)
    p2 = p.copy()
    for (x, y) in cells:
        p2[y, x] = False
    l2 = label(p2)
    sx, sy = self.spawn or lay.rooms[0].center()
    before = int((l1 == l1[sy, sx]).sum()) if l1[sy, sx] else 0
    after = int((l2 == l2[sy, sx]).sum()) if l2[sy, sx] else 0
    lost = sum(1 for (x, y) in cells if p[y, x])
    return after >= before - lost


P.Decorator._connected_ok = _fast_connected_ok

# Köşe kuralı (paketin örnek haritası Dungeon3.tmx gibi, zindan_paint.paint_walls_34 `tuck`): yüzün yanı duvarsa yüz devam eder, öndeki duvarın
# tepesi yüzün yanında kenarlı iner. Kemik ve Boynuz duvar sayfası aynı düzende (walls_floor 9/11/12/15. sütun); Et'in duvar tepesi kenarsız.
# Tema bankası (ThemeBank.theme) üzerinden seçilir: temaların paint_base / paint_walls'ı değişmeden tuck'lı boyar (yalnız bu üreteçte).
WF_TUCK = {'void_r3': (9, 1), 'void_r': (12, 1), 'void_l3': (11, 1), 'void_l': (15, 1), 'lip_r': (12, 2), 'lip_l': (15, 2)}
TUCK = {'kemik': WF_TUCK, 'boynuz': WF_TUCK, 'et': {}}
_paint_walls_orig = P.paint_walls_34


def _paint_walls_tuck(lay, bank, tl, key, *a, **kw):
    if 'tuck' not in kw:
        kw['tuck'] = TUCK.get(getattr(bank, 'theme', None))
    return _paint_walls_orig(lay, bank, tl, key, *a, **kw)


P.paint_walls_34 = _paint_walls_tuck


def normalize_steps(lay, rounds=30):
    """1 satırlık basamak (yan yana iki zemin sütununun üst kenarı 1 satır farklı): iki yüz yarım satır kayık yan yana durur, paketin bunun
    için karosu yok (2 satırlık basamağın var: dudak karosu). Alçak taraftaki üst kenarın TÜM düz parçası 1 satır yükseltilir (kazı = yol hiç
    kapanmaz; hücre hücre yükseltince uzun koridor kenarı her turda bir sütun ilerliyordu), sonra kalınlık düzeltmesi; kalmayana kadar."""
    t = lay.t
    Hh, Ww = t.shape
    total = 0
    for _ in range(rounds):
        f = t != Z.S
        found = []
        top = f[2:, 1:-1] & ~f[1:-1, 1:-1]  # (y, x) zemin, üstü duvar; y >= 2
        for dx in (-1, 1):
            nb1 = f[1:-1, 1 + dx:Ww - 1 + dx]  # komşu sütun y-1 zemin
            nb2 = f[:-2, 1 + dx:Ww - 1 + dx]   # komşu sütun y-2 duvar
            for yy, xx in np.argwhere(top & nb1 & ~nb2):
                found.append((int(xx) + 1, int(yy) + 2, dx))
        if not found:
            break
        for (x, y, dx) in found:
            xx = x
            while 0 < xx < Ww - 1 and t[y, xx] != Z.S and t[y - 1, xx] == Z.S:
                t[y - 1, xx] = Z.F
                total += 1
                xx -= dx
        lay.fix_thickness(min_v=4, min_h=2)
    return total


# ================================================================================================ bankalar / görünümler
class ThemeBank:
    """Birleşik bankanın bir temaya bakan yüzü: temanın kendi anahtarları ('wf', 'obj'...) birleşikte '<tema>_<anahtar>'."""

    def __init__(self, mb, theme):
        self.mb, self.theme = mb, theme
        pre = theme + '_'
        self.sets = {k[len(pre):]: v for k, v in mb.sets.items() if k.startswith(pre)}
        self.sets['eng'] = mb.sets['eng']

    def gid(self, key, col, row, flags=0):
        return self.mb.gid(key if key == 'eng' else self.theme + '_' + key, col, row, flags)

    def decode(self, g):
        return self.mb.decode(g)

    def assign_gids(self):
        self.mb.assign_gids()


# Kemik duvar tepesi (boşluk) tonları -> Boynuz/Et'in lacivert boşluk tonları (yalnız BU haritanın kemik_walls_floor.png kopyasında, sayfanın
# duvar blokları satır 0-6): kayada iki tema buluşunca kahve-siyah ile lacivert arasında merdiven biçimli sınır görünüyordu. Kemik
# zindanının kendi sayfası değişmez.
KEMIK_VOID = {(24, 22, 25): (29, 28, 43), (28, 25, 29): (33, 32, 48), (31, 28, 32): (37, 36, 53)}


def kemik_void_to_navy(img):
    img = img.copy()
    px = img.load()
    for y in range(min(img.height, 7 * Z.CELL)):
        for x in range(img.width):
            c = px[x, y]
            n = KEMIK_VOID.get(c[:3])
            if n is not None and c[3] > 0:
                px[x, y] = n + (c[3],)
    return img


def make_bank():
    mb = Z.TilesetBank(ID)
    for th in THEMES:
        tb = MOD[th].make_bank()
        for key in tb.order:
            if key == 'eng':
                continue
            ts = tb.sets[key]
            img = kemik_void_to_navy(ts.img) if (th, key) == ('kemik', 'wf') and len(THEMES) > 1 else ts.img
            mb.add(th + '_' + key, ts.src, name='%s_%s' % (th, os.path.basename(ts.dest_rel)), img=img, anims=ts.anims)
    mb.add('eng', 'engel', name='engel.png', img=Z.make_marker_sheet())
    return mb


class View:
    """Tek temaya bakan Layout yüzü: ızgara dizileri ORTAK (t / solid_obj / room_id yerinde değişir), odalar ve koridorlar temanın."""

    def __init__(self, lay, rooms, corr_mask=None):
        self.W, self.H = lay.W, lay.H
        self.t = lay.t
        self.room_id = lay.room_id
        self.corr_id = lay.corr_id if corr_mask is None else np.where(corr_mask, lay.corr_id, -1)
        self.rooms = rooms
        self.edges = lay.edges
        self.reserve = lay.reserve
        self.solid_obj = lay.solid_obj
        self.notes = lay.notes
        self.rng = lay.rng

    def passable(self):
        return (self.t == Z.F) & (self.solid_obj == 0)

    def bfs(self, sources, passable=None):
        return Z.Layout.bfs(self, sources, passable)


# ================================================================================================ yerleşim
class Gen:
    def __init__(self, seed=SEED):
        self.lay = Z.Layout(W, H, seed)
        self.rng = random.Random(seed + 1)
        self.road_theme = np.zeros((H, W), np.int8)
        self.road = np.zeros((H, W), bool)
        self.eid_info = {}  # eid -> (tema a, oda a, tema b, oda b)
        self.next_eid = 0
        self.halls = []  # Room (kind 'dev', .hall = ad)
        self.districts = []  # (tema, ad, [Room])
        self.log = []

    def eid(self):
        self.next_eid += 1
        return self.next_eid

    # ---- 1) salonlar + kümeler
    def place(self):
        lay = self.lay
        for entry in HALLS:
            name, th, (x, y, w, h) = entry[:3]
            r = lay.add_room(x, y, w, h, 'dev')
            r.theme, r.hall, r.district = th, name, -1
            r.flags = dict(entry[3]) if len(entry) > 3 else {}
            self.halls.append(r)
        avoid = np.zeros((H, W), bool)
        for (x, y, w, h), _ in ROADS:
            avoid[max(0, y - 6):y + h + 6, max(0, x - 4):x + w + 4] = True
        # sıkı yerleşim: her oda için uygun adaylar toplanır, engele (bölge kenarı / yol payı / komşu oda payı) en yakın olan seçilir -
        # rastgele saçınca büyük odalar bloğun ortasına düşüp küçük odalara yer kalmıyordu
        for di, (th, name, (x0, y0, x1, y1), specs) in enumerate(DISTRICTS):
            got = []
            for count, (wa, wb), (ha, hb), kind in specs:
                placed = 0
                for _ in range(count):
                    best = None
                    for _ in range(900):
                        w, h = lay.rng.randint(wa, wb), lay.rng.randint(ha, hb)
                        if x1 - w < x0 or y1 - h < y0:
                            break
                        x, y = lay.rng.randint(x0, x1 - w), lay.rng.randint(y0, y1 - h)
                        if avoid[y:y + h, x:x + w].any() or not lay.fits(x, y, w, h, 6, 9):
                            continue
                        sc = self._slack(x, y, w, h, (x0, y0, x1, y1), avoid) + lay.rng.random() * 0.5
                        if best is None or sc < best[0]:
                            best = (sc, x, y, w, h)
                    if best is None:
                        break
                    _, x, y, w, h = best
                    r = lay.add_room(x, y, w, h, kind)
                    r.theme, r.hall, r.district = th, None, di
                    got.append(r)
                    placed += 1
                if placed < count:
                    lay.notes.append('uyarı: %s %s %d/%d' % (name, kind, placed, count))
            self.districts.append((th, name, got))

    def _slack(self, x, y, w, h, region, avoid):
        """Adayın en yakın engele boşluğu (küçük = sıkı): bölge kenarı, yol payı, diğer odaların payı (6 yatay / 9 dikey)."""
        x0, y0, x1, y1 = region
        s = min(x - x0, x1 - (x + w), (y - y0) * 0.7, (y1 - (y + h)) * 0.7)
        for k in range(1, 12):
            if (x - k >= 0 and avoid[y:y + h, x - k].any()) or (x + w + k - 1 < W and avoid[y:y + h, x + w + k - 1].any()):
                s = min(s, k - 1)
                break
        for r in self.lay.rooms:
            gx = max(r.x - (x + w), x - (r.x + r.w)) - 6
            gy = max(r.y - (y + h), y - (r.y + r.h)) - 9
            g = max(gx, gy * 0.7)
            if g < s:
                s = g
        return max(0.0, s)

    # ---- 2) oyma
    def carve(self):
        lay = self.lay
        lay.carve_rooms()
        for (x, y, w, h), th in ROADS:
            self._carve_road(x, y, w, h, th)
        for th, name, rooms in self.districts:
            if len(rooms) < 2:
                continue
            tmp = Z.Layout(W, H, SEED + len(rooms))
            tmp.rooms = [Z.Room(i, r.x, r.y, r.w, r.h, r.kind) for i, r in enumerate(rooms)]
            tmp.build_graph(k=3, loop_ratio=0.5, max_len=55)
            for a, b, _ in tmp.edges:
                self.corridor(rooms[a], rooms[b])
        for th, name, rooms in self.districts:
            self.connectors(th, name, rooms)
        self._restamp_roads()

    def _carve_road(self, x, y, w, h, th):
        lay = self.lay
        eid = self.eid()
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                lay.t[yy, xx] = Z.F
                self.road[yy, xx] = True
                self.road_theme[yy, xx] = TID[th(xx, yy) if callable(th) else th]
                if lay.room_id[yy, xx] < 0:
                    lay.corr_id[yy, xx] = eid
        lay.edges.append((-1, -1, eid))

    def _restamp_roads(self):
        lay = self.lay
        m = self.road & (lay.room_id < 0)
        lay.corr_id[m] = 10000  # yollar tek kimlik (tema road_theme'den)
        lay.t[self.road] = Z.F

    def corridor(self, ra, rb, width=CW, forbid=None):
        eid = self.eid()
        ok = astar_carve(self.lay, ra.id, rb.id, eid, width, forbid=forbid)
        if not ok:
            if forbid is not None:
                return False
            self.lay.carve_corridor(ra.id, rb.id, eid, width)
        self.lay.edges.append((ra.id, rb.id, eid))
        self.eid_info[eid] = (ra.theme, ra, rb.theme, rb)
        return True

    def connectors(self, th, name, rooms):
        """Kümeden ana yola / dev salona düz bağlantı koridorları (5 hücre): oda kenarından dik çıkıp yalnız kaya içinden ilerler,
        ilk değdiği zemin YOL ya da SALON olmalı. Kısa olanlardan, oda başına bir, birbirinden >= 16 hücre uzak."""
        lay = self.lay
        t = lay.t
        half = CW // 2
        hall_ids = {r.id for r in self.halls}

        def target(x, y):
            return t[y, x] == Z.F and (self.road[y, x] or lay.room_id[y, x] in hall_ids)
        opts = []
        for r in rooms:
            for d in 'nswe':
                rng_c = range(r.x + half + 1, r.x + r.w - half - 1, 2) if d in 'ns' else range(r.y + half + 1, r.y + r.h - half - 1, 2)
                for c in rng_c:
                    for k in range(1, 46):
                        if d == 'n':
                            line = [(xx, r.y - k) for xx in range(c - half, c + half + 1)]
                            guard = [(c - half - 1, r.y - k), (c + half + 1, r.y - k)]
                        elif d == 's':
                            line = [(xx, r.y + r.h - 1 + k) for xx in range(c - half, c + half + 1)]
                            guard = [(c - half - 1, r.y + r.h - 1 + k), (c + half + 1, r.y + r.h - 1 + k)]
                        elif d == 'w':
                            line = [(r.x - k, yy) for yy in range(c - half, c + half + 1)]
                            guard = [(r.x - k, c - half - 1), (r.x - k, c + half + 1)]
                        else:
                            line = [(r.x + r.w - 1 + k, yy) for yy in range(c - half, c + half + 1)]
                            guard = [(r.x + r.w - 1 + k, c - half - 1), (r.x + r.w - 1 + k, c + half + 1)]
                        if any(not (1 <= x < W - 1 and 4 <= y < H - 1) for x, y in line + guard):
                            break
                        if all(t[y, x] == Z.S for x, y in line):
                            if any(t[y, x] != Z.S and not target(x, y) for x, y in guard):
                                break
                            continue
                        if k > 1 and all(target(x, y) for x, y in line):
                            opts.append((k - 1, r, d, c))
                        break
        opts.sort(key=lambda o: (o[0], o[1].id))
        want = 2 if len(rooms) <= 3 else (3 if len(rooms) < 9 else 4)
        chosen = []
        for o in opts:
            if len(chosen) >= want:
                break
            if any(o[1] is c[1] for c in chosen):
                continue
            pa = _conn_point(o)
            if any(math.dist(pa, _conn_point(c)) < 16 for c in chosen):
                continue
            chosen.append(o)
        for (ln, r, d, c) in chosen:
            eid = self.eid()
            for k in range(1, ln + 1):
                for j in range(-half, half + 1):
                    if d == 'n':
                        x, y = c + j, r.y - k
                    elif d == 's':
                        x, y = c + j, r.y + r.h - 1 + k
                    elif d == 'w':
                        x, y = r.x - k, c + j
                    else:
                        x, y = r.x + r.w - 1 + k, c + j
                    t[y, x] = Z.F
                    lay.corr_id[y, x] = eid
            self.eid_info[eid] = (r.theme, r, r.theme, r)
            lay.edges.append((r.id, -1, eid))
        if len(chosen) < want:
            lay.notes.append('uyarı: %s bağlantı %d/%d' % (name, len(chosen), want))
        self.log.append('%s: %d oda, %d yol bağlantısı' % (name, len(rooms), len(chosen)))

    # ---- 3) kaçış
    def hall_sample(self):
        ys, xs = [], []
        for r in self.halls:
            for (fx, fy) in ((0.5, 0.5), (0.25, 0.3), (0.75, 0.7)):
                ys.append(int(r.y + r.h * fy))
                xs.append(int(r.x + r.w * fx))
        return np.array(ys), np.array(xs)

    def room_samples(self, p):
        """(oda listesi, ys, xs, oda indeksi) - salon olmayan her odadan en çok 6 geçilebilir hücre."""
        rooms, ys, xs, idx = [], [], [], []
        for r in self.lay.rooms:
            if r.hall:
                continue
            cells = [(x, y) for y in range(r.y, r.y + r.h) for x in range(r.x, r.x + r.w) if p[y, x]]
            if not cells:
                continue
            k = len(rooms)
            rooms.append(r)
            for (x, y) in cells[::max(1, len(cells) // 6)][:6]:
                ys.append(y)
                xs.append(x)
                idx.append(k)
        return rooms, np.array(ys), np.array(xs), np.array(idx)

    def cut_rooms(self, m, samples, hs):
        """m geçilebilirlik maskesiyle hiçbir dev salona ulaşamayan odalar (örnek hücresi geçilebilir olanlar)."""
        rooms, ys, xs, idx = samples
        lab = label(m)
        good = np.unique(lab[hs[0], hs[1]])
        good = good[good > 0]
        valid = m[ys, xs]
        ok = valid & np.isin(lab[ys, xs], good)
        nv = np.bincount(idx, weights=valid, minlength=len(rooms))
        no = np.bincount(idx, weights=ok, minlength=len(rooms))
        return [rooms[i] for i in range(len(rooms)) if nv[i] > 0 and no[i] == 0], lab, good

    def blockage(self, points=None, step=3, radius=2):
        lay = self.lay
        p = lay.passable()
        samples = self.room_samples(p)
        hs = self.hall_sample()
        if points is None:
            narrow = (lay.corr_id >= 0) & (lay.room_id < 0) & p & ~self.road
            points = [(int(x), int(y)) for i, (y, x) in enumerate(np.argwhere(narrow)) if i % step == 0]
        out = []
        for (x, y) in points:
            if not p[y, x]:
                continue
            m = p.copy()
            m[max(0, y - radius):y + radius + 1, max(0, x - radius):x + radius + 1] = False
            cut, _, _ = self.cut_rooms(m, samples, hs)
            for r in cut:
                out.append(((x, y), r))
        return out

    def connect_unreached(self):
        """Hiç salona bağlanamayan odaları (engelsiz) en yakın bağlı odaya bağla."""
        for _ in range(30):
            p = self.lay.passable()
            samples = self.room_samples(p)
            cut, lab, good = self.cut_rooms(p, samples, self.hall_sample())
            if not cut:
                return
            a = cut[0]
            self._link_out(a, cut, lab, good, None)
        self.lay.notes.append('UYARI: bağlanamayan oda kaldı')

    def _link_out(self, a, cut, lab, good, forbid):
        cut_ids = {r.id for r in cut}
        cands = []
        for r in self.lay.rooms:
            if r.id in cut_ids:
                continue
            cx, cy = r.center()
            if lab[cy, cx] in good:
                cands.append((math.dist(a.center(), r.center()) * (1.0 if r.theme == a.theme else 1.25), r))
        cands.sort(key=lambda c: c[0])
        for _, b in cands[:5]:
            if self.corridor(a, b, forbid=forbid):
                self.lay.notes.append('kaçış onarımı: oda %d (%s) -> %d (%s)' % (a.id, a.kind, b.id, b.hall or b.kind))
                return True
        self.lay.notes.append('kaçış onarımı BAŞARISIZ: oda %d' % a.id)
        return False

    def repair_blockage(self, passes=3):
        lay = self.lay
        for _ in range(passes):
            fails = self.blockage()
            if not fails:
                return True
            for _ in range(40):
                if not fails:
                    break
                (bx, by), _r = fails[0]
                cut = [r for (pt, r) in fails if pt == (bx, by)]
                p = lay.passable()
                p[max(0, by - 2):by + 3, max(0, bx - 2):bx + 3] = False
                samples = self.room_samples(lay.passable())
                _, lab, good = self.cut_rooms(p, samples, self.hall_sample())
                forbid = np.zeros((H, W), bool)
                forbid[max(0, by - 7):by + 8, max(0, bx - 7):bx + 8] = True
                if not self._link_out(cut[0], cut, lab, good, forbid):
                    fails = [f for f in fails if f[0] != (bx, by)]
                    continue
                fails = self.blockage(points=sorted({pt for pt, _ in fails}))
            lay.fix_thickness(min_v=4, min_h=2)
        return not self.blockage()


def _conn_point(o):
    ln, r, d, c = o
    return (c, r.y) if d == 'n' else ((c, r.y + r.h) if d == 's' else ((r.x, c) if d == 'w' else (r.x + r.w, c)))


def astar_carve(lay, a, b, eid, width=3, turn_cost=4, near_cost=14, room_cost=60, forbid=None, max_it=400000):
    """zindan_core.carve_corridor_astar'ın aynısı + `forbid` (geçilmez bölge: kaçış onarımında tıkanma noktası) + büyük haritada daha
    uzun arama. Bulamazsa False."""
    ra, rb = lay.rooms[a], lay.rooms[b]
    sx, sy = ra.center()
    gx, gy = rb.center()
    near = lay._near_mask({a, b}, width)
    other_room = (lay.room_id >= 0) & (lay.room_id != a) & (lay.room_id != b)
    half = width // 2
    cost = np.ones((H, W), np.float32)
    cost[near] += near_cost
    band = np.zeros_like(other_room)
    for dy in range(-half - 1, half + 2):
        for dx in range(-half - 1, half + 2):
            band |= np.roll(np.roll(other_room, dy, 0), dx, 1)
    cost[band] += room_cost
    inside_ab = (lay.room_id == a) | (lay.room_id == b)
    cost[inside_ab] = 1.0
    if forbid is not None:
        fb = np.zeros_like(forbid)
        for dy in range(-half, half + 1):
            for dx in range(-half, half + 1):
                fb |= np.roll(np.roll(forbid, dy, 0), dx, 1)
        cost[fb] = np.inf
    lo, hi = half + 2, 4 + half
    dirs = ((1, 0), (-1, 0), (0, 1), (0, -1))
    start = (sx, sy, -1)
    g = {start: 0.0}
    prev = {}
    pq = [(abs(gx - sx) + abs(gy - sy), 0.0, start)]
    found = None
    it = 0
    costl = cost.tolist()
    while pq:
        f, gc, st = heapq.heappop(pq)
        if gc > g.get(st, 1e18):
            continue
        x, y, d = st
        if (x, y) == (gx, gy):
            found = st
            break
        it += 1
        if it > max_it:
            break
        for di, (dx, dy) in enumerate(dirs):
            nx, ny = x + dx, y + dy
            if not (lo <= nx < W - lo and hi <= ny < H - lo):
                continue
            c = costl[ny][nx]
            if c == math.inf:
                continue
            nc = gc + c + (turn_cost if d >= 0 and di != d else 0.0)
            ns = (nx, ny, di)
            if nc < g.get(ns, 1e18):
                g[ns] = nc
                prev[ns] = st
                heapq.heappush(pq, (nc + abs(gx - nx) + abs(gy - ny), nc, ns))
    if found is None:
        return False
    path = []
    st = found
    while st in prev:
        path.append((st[0], st[1]))
        st = prev[st]
    lo_o = -(width // 2)
    for (x, y) in path:
        for dy in range(lo_o, lo_o + width):
            for dx in range(lo_o, lo_o + width):
                xx, yy = x + dx, y + dy
                if 1 <= xx < W - 1 and 3 <= yy < H - 1:
                    if lay.t[yy, xx] == Z.S:
                        lay.t[yy, xx] = Z.F
                    if lay.room_id[yy, xx] < 0:
                        lay.corr_id[yy, xx] = eid
    return True


# ================================================================================================ kan kanalları (Kan Havzası)
def carve_lake(lay, r):
    """Kan Havzası: iki uzun kan kanalı (3 satır) karşı duvarlara yaslı, aralarında yılan gibi yol + her kanalda 4 hücrelik iki köprü."""
    t = lay.t
    bridges = []
    q = r.w // 4
    specs = [(r.y + int(r.h * 0.3), r.x, r.x + r.w - 18, (r.x + q - 6, r.x + 2 * q + 2)),
             (r.y + int(r.h * 0.66), r.x + 18, r.x + r.w, (r.x + 2 * q - 2, r.x + 3 * q + 4))]
    for (y0, xa, xb, bxs) in specs:
        if xa == r.x and any(t[y, r.x - 1] != Z.S for y in range(y0 - 1, y0 + 4)):
            xa += 4
        if xb == r.x + r.w and any(t[y, xb] != Z.S for y in range(y0 - 1, y0 + 4)):
            xb -= 4
        for y in range(y0, y0 + 3):
            for x in range(xa, xb):
                if lay.room_id[y, x] == r.id and t[y, x] == Z.F:
                    t[y, x] = Z.W
        for bx in bxs:
            for y in range(y0, y0 + 3):
                for x in range(bx, bx + 4):
                    t[y, x] = Z.F
            bridges.append(('v', bx, y0))
            bridges.append(('v', bx + 2, y0))
    return bridges


# ================================================================================================ tema haritası
def theme_map(gen):
    lay = gen.lay
    t = lay.t
    tm = np.zeros((H, W), np.int8)
    fl = t != Z.S
    for r in lay.rooms:
        sub = tm[r.y:r.y + r.h, r.x:r.x + r.w]
        sub[fl[r.y:r.y + r.h, r.x:r.x + r.w] & (lay.room_id[r.y:r.y + r.h, r.x:r.x + r.w] == r.id)] = TID[r.theme]
    m = fl & (lay.room_id < 0) & gen.road
    tm[m] = gen.road_theme[m]
    for (y, x) in np.argwhere(fl & (tm == 0) & (lay.corr_id >= 0)):
        info = gen.eid_info.get(int(lay.corr_id[y, x]))
        if info is None:
            continue
        ta, ra, tb, rb = info
        if ta == tb:
            tm[y, x] = TID[ta]
        else:
            da = _rect_dist(ra, x, y)
            db = _rect_dist(rb, x, y)
            tm[y, x] = TID[ta] if da <= db else TID[tb]
    # duvar yüzü (altındaki 1-3 hücre içinde zemin) = o zeminin teması: yüz iki temaya bölünmesin
    for y in range(H):
        for x in range(W):
            if t[y, x] == Z.S:
                k = P.k_below(t, x, y)
                if k and tm[y + k, x]:
                    tm[y, x] = tm[y + k, x]
    # kalan kaya: en yakın temalı hücre (8 komşu: sınır iki zeminin orta hattında, düz çizgi değil). Kemik'in duvar tepesi koyu kahve,
    # Boynuz/Et'inki lacivert - bu sınır kayada görünür, yeri bu yüzden zeminlerden en uzak hat.
    q = deque((int(x), int(y)) for y, x in np.argwhere(tm > 0))
    while q:
        x, y = q.popleft()
        v = tm[y, x]
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1), (x + 1, y + 1), (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1)):
            if 0 <= nx < W and 0 <= ny < H and tm[ny, nx] == 0:
                tm[ny, nx] = v
                q.append((nx, ny))
    return tm


def _rect_dist(r, x, y):
    dx = max(r.x - x, 0, x - (r.x + r.w - 1))
    dy = max(r.y - y, 0, y - (r.y + r.h - 1))
    return math.hypot(dx, dy)


# ================================================================================================ salon süslemesi
def sub_room(r, x, y, w, h, kind='oda'):
    s = Z.Room(r.id, x, y, w, h, kind)
    return s


def pillar_at(dz, spec, x, y):
    key, (sx, sy, w, h) = spec
    if dz.is_free(x, y - h + 2, w, h - 1) and dz.solidify([(x, y), (x, y - 1)], val=1):
        dz.put('Eşya', spec, x, y - h + 1)
        return True
    return False


def colonnade(dz, spec, x0, y0, w, h, step=6):
    """(x0, y0, w, h) dikdörtgeninin kenarına sütun dizisi (taban satırı kenarda)."""
    for x in range(x0 + 2, x0 + w - 1, step):
        pillar_at(dz, spec, x, y0 + 1)
        pillar_at(dz, spec, x, y0 + h - 1)
    for y in range(y0 + 1 + step, y0 + h - 2, step):
        pillar_at(dz, spec, x0 + 1, y)
        pillar_at(dz, spec, x0 + w - 2, y)


def statue_at(dz, spec, x, y, light=None, light_r=140):
    """Serbest duran büyük heykel (sol üst x, y): alt 2 satırın ortası engel."""
    key, (sx, sy, w, h) = spec
    if not dz.is_free(x, y, w, h, allow_reserve=True):
        return False
    foot = [(x + i, y + h - 1 - j) for i in range(1, w - 1) for j in range(2)]
    if not dz.solidify(foot):
        return False
    dz.put('Eşya', spec, x, y)
    if light:
        dz.light((x + w / 2.0) * 16, (y + h * 0.4) * 16, light, r=light_r, energy=1.1)
    return True


def quad_dwellers(dz, r, profile, nx=2, ny=2):
    for j in range(ny):
        for i in range(nx):
            x0 = r.x + 1 + i * (r.w - 2) // nx
            y0 = r.y + 1 + j * (r.h - 2) // ny
            w = (r.w - 2) // nx
            h = (r.h - 2) // ny
            dz.add_obj('sakin', profile, x0, y0, w, h, profil=profile, adet=max(3, min(8, w * h // 40)))


def hall_slab_rugs(dz, r, mask_extra=None):
    """Kemik: kum zemine seyrek gri taş levha yamaları (salon kenarında, ortadaki büyük levhanın dışında)."""
    lay = dz.lay
    m = np.zeros((H, W), bool)
    m[r.y + 2:r.y + r.h - 2, r.x + 2:r.x + r.w - 2] = True
    m &= (lay.t == Z.F)
    if mask_extra is not None:
        m &= ~mask_extra
    for (x, y, rw, rh) in P.place_rugs(m, P.value_noise(W, H, SEED + r.id, 7.0), 0.55, random.Random(SEED + r.id),
                                       sizes=((5, 4), (4, 4), (6, 4), (4, 3), (3, 3)), gap=3):
        P.nine_slice(dz.tl, dz.bank, 'Zemin ayrıntı', 'wf', KM.SLAB9, x, y, rw, rh)


def deco_buyuk_salon(dz, r):
    nx0, ny0, nw, nh = r.x + 12, r.y + 9, r.w - 24, r.h - 18
    P.nine_slice(dz.tl, dz.bank, 'Zemin ayrıntı', 'wf', KM.SLAB9, nx0, ny0, nw, nh)
    P.nine_slice(dz.tl, dz.bank, 'Zemin desen', 'pl', KM.PLATE9, nx0 + 1, ny0 + 1, nw - 2, nh - 2)
    nave = np.zeros((H, W), bool)
    nave[ny0 - 2:ny0 + nh + 2, nx0 - 2:nx0 + nw + 2] = True
    hall_slab_rugs(dz, r, nave)
    cx, cy = r.center()
    statue_at(dz, KM.STATUE_FIRE, cx - 12, cy - 4, light=P.CYAN, light_r=170)
    statue_at(dz, KM.STATUE_FIRE, cx + 8, cy - 4, light=P.CYAN, light_r=170)
    colonnade(dz, ('wf', (15, 1, 1, 4)), nx0, ny0, nw, nh, step=6)
    dz.wall_torches(r, KM.TORCH_WALL, step=8, light=P.CYAN)
    dz.wall_reliefs(r, KM.RELIEF, step=13)
    dz.wall_row(r, KM.ARCH_FACE, step=9, layer='Duvar süsü', face=True)
    dz.statue_pair(r, KM.STATUES[1])
    dz.resource_nodes(r, 'ruh_kandili', 2)
    dz.chest(r)
    dz.chest(r)
    dz.hide_alcove(r)
    dz.hide_alcove(r)
    dz.edge_props(r, KM.STATUES, 'n', step=10, n_max=6)
    dz.edge_props(r, KM.COLUMNS, 'n', step=5, n_max=8)
    dz.edge_props(r, KM.URNS + KM.BONE_PILES + KM.WOOD_H, 's', step=4, n_max=9)
    for side in ('w', 'e'):
        dz.edge_props(r, KM.NARROW, side, step=3, n_max=5)
    dz.scatter(r, KM.BENCH, 5, solid=True)
    dz.scatter(r, KM.WOOD_V + KM.WOOD_H, 6, solid=True)
    dz.scatter(r, KM.URNS + KM.BONE_PILES, 6, solid=True)
    dz.scatter(r, KM.CANDLES_FLOOR, 6, light=P.CYAN)
    dz.scatter(r, KM.GOLD, 3)
    dz.scatter(r, KM.BONES + KM.SKULLS, 24)
    dz.corner_candles(r, KM.CANDLES_FLOOR, light=P.CYAN)
    dz.corner_webs(r)
    quad_dwellers(dz, r, 'sutun', 2, 2)


def deco_katedral(dz, r):
    ny0 = r.y + 12
    P.nine_slice(dz.tl, dz.bank, 'Zemin ayrıntı', 'wf', KM.SLAB9, r.x + 3, ny0, r.w - 6, 12)
    P.nine_slice(dz.tl, dz.bank, 'Zemin desen', 'pl', KM.PLATE9, r.x + 4, ny0 + 1, r.w - 8, 10)
    for x in range(r.x + 4, r.x + r.w - 3, 5):
        pillar_at(dz, ('wf', (15, 1, 1, 4)), x, ny0 - 1)
        pillar_at(dz, ('wf', (15, 1, 1, 4)), x, ny0 + 13)
    statue_at(dz, KM.STATUE_FIRE, r.x + 3, ny0 + 3, light=P.CYAN, light_r=160)
    north = sub_room(r, r.x, r.y, r.w, 10)
    south = sub_room(r, r.x, ny0 + 14, r.w, r.y + r.h - (ny0 + 14))
    dz.tomb_rows(north, KM.TOMBS_V_SMALL, KM.OPEN_EMPTY_V, margin_top=2, hide_every=4)
    dz.tomb_rows(south, KM.TOMBS_V + KM.TOMBS_V_SMALL, KM.OPEN_EMPTY_V, margin_top=1, hide_every=4)
    dz.wall_torches(r, KM.TORCH_WALL, step=7, light=P.CYAN)
    dz.wall_reliefs(r, KM.RELIEF, step=9)
    dz.wall_row(r, KM.ARCH_FACE, step=8, layer='Duvar süsü', face=True)
    dz.resource_nodes(r, 'ruh_kandili', 2)
    dz.chest(r)
    dz.hide_alcove(r)
    for side in ('w', 'e'):
        dz.edge_props(r, KM.NARROW, side, step=3, n_max=4)
    dz.scatter(r, KM.BONES + KM.SKULLS, 10)
    dz.corner_candles(r, KM.CANDLES_FLOOR, light=P.CYAN)
    dz.corner_webs(r)
    quad_dwellers(dz, r, 'lahit', 3, 1)


def deco_tapinak(dz, r):
    cx0, cy0, cw, ch = r.x + 8, r.y + 8, r.w - 16, r.h - 16
    P.nine_slice(dz.tl, dz.bank, 'Zemin ayrıntı', 'wf', BK.DARK9, cx0, cy0, cw, ch)
    colonnade(dz, ('wf', (15, 1, 1, 4)), cx0 - 2, cy0 - 2, cw + 4, ch + 4, step=6)
    dz.statue_pair(r, BK.HORN_SKULL[0])
    cx, cy = r.center()
    statue_at(dz, BK.LAVA_ROCKS[0], cx - 10, cy - 2, light=(1.0, 0.55, 0.25), light_r=110)
    statue_at(dz, BK.LAVA_ROCKS[1], cx + 6, cy - 2, light=(1.0, 0.55, 0.25), light_r=110)
    dz.wall_fires(r, BK.BRAZIER, step=6, light=P.AMBER)
    dz.wall_row(r, BK.WIN_FACE, step=7, layer='Duvar süsü', face=True)
    dz.resource_nodes(r, 'isik_kristali', 2)
    dz.chest(r)
    dz.hide_alcove(r, spec=('wf', (1, 26, 2, 2)))
    dz.hide_alcove(r, spec=('wf', (1, 26, 2, 2)))
    dz.edge_props(r, BK.BARRELS + BK.VASES + BK.CRATES[:2], 'n', step=3, n_max=8)
    dz.edge_props(r, BK.BARRELS + BK.VASES + BK.GOLD, 's', step=3, n_max=7)
    for side in ('w', 'e'):
        dz.edge_props(r, BK.SMALL_STONE, side, step=4, n_max=2, solid=False)
    dz.scatter(r, BK.CRATES + BK.BARRELS, 4, solid=True)
    dz.scatter(r, BK.BLUE_CRYSTAL, 4, solid=True, light=P.CYAN)
    dz.scatter(r, BK.BLUE_SHARDS, 8)
    dz.corner_candles(r, BK.CANDLE, light=P.AMBER)
    quad_dwellers(dz, r, 'salon', 2, 2)


def deco_magara(dz, r):
    dz.wall_row(r, BK.HANGING, step=3, layer='Duvar süsü', face=True)
    dz.blob_scatter(r, BK.STALAG + BK.PILLARS, 14, solid=True, vision=True)
    dz.blob_scatter(r, BK.BLUE_CRYSTAL_BIG + BK.DARK_CRYSTAL, 8, solid=True, vision=True, light=P.CYAN)
    dz.blob_scatter(r, BK.BLUE_CRYSTAL + BK.PM_CRYSTALS + BK.PINK_CRYSTALS, 16, solid=True, light=P.VIOLET)
    dz.blob_scatter(r, BK.MUSHROOMS + BK.GLOW_PLANTS, 10, solid=True, light=(0.85, 0.6, 1.0))
    dz.blob_scatter(r, BK.LAVA_ROCKS, 3, solid=True, light=(1.0, 0.55, 0.25))
    dz.blob_scatter(r, BK.SPIDER, 1, solid=True)
    dz.blob_scatter(r, BK.FERNS + BK.CORAL + BK.JELLY, 14)
    dz.blob_scatter(r, BK.MOSS + BK.WEB, 7)
    dz.blob_scatter(r, [('pms', (0, 0, 4, 4))], 10, layer='Zemin süsü')
    dz.blob_hide(r, BK.MUSH_HOUSE[1], 'Mantar Kovuğu')
    dz.blob_hide(r, BK.BLUE_CRYSTAL_BIG[1], 'Kristal Gölgesi')
    dz.blob_hide(r, BK.BLUE_CRYSTAL_BIG[0], 'Kristal Gölgesi')
    dz.edge_props(r, BK.STALAG + BK.BLUE_CRYSTAL, 'n', step=3, n_max=8)
    dz.edge_props(r, BK.BLUE_CRYSTAL + BK.MUSHROOMS[2:], 's', step=3, n_max=8, light=P.VIOLET)
    dz.resource_nodes(r, 'isik_kristali', 3)
    dz.chest(r)
    quad_dwellers(dz, r, 'magara', 2, 2)


def deco_havza(dz, r):
    dz.wall_fires(r, EK.FIRES, step=7, light=P.AMBER)
    dz.wall_row(r, EK.ARCH2, step=8, layer='Duvar süsü', face=True)
    dz.wall_hangings(r, EK.MOSS, step=6)
    statue_at(dz, EK.BIG_EYE, r.x + r.w - 14, r.y + 3, light=P.RED, light_r=120)
    statue_at(dz, EK.MAW, r.x + 6, r.y + r.h - 8, light=P.RED, light_r=90)
    dz.scatter(r, EK.CRATES, 4, solid=True)
    dz.scatter(r, EK.BARRELS, 5, solid=True)
    dz.scatter(r, EK.FLESH_PLANTS, 4, solid=True)
    dz.scatter(r, EK.FLESH_ROCK, 3, solid=True)
    dz.scatter(r, EK.EYE_PODS, 3, solid=True, light=P.RED)
    dz.scatter(r, EK.MUSHROOMS, 8)
    dz.scatter(r, EK.ROOT_VEIN, 2)
    dz.scatter(r, EK.BONES_LT, 4)
    dz.edge_props(r, EK.BARRELS + EK.BOXES[:3], 'n', step=3, n_max=6)
    dz.edge_props(r, EK.BARRELS + EK.CRATES[4:6], 's', step=4, n_max=5)
    dz.corner_webs(r, key='kw')
    dz.resource_nodes(r, 'et_kesesi', 3)
    dz.hide_spot_object(r, EK.ROOT_PODS[0], 'Et Kökü')
    dz.chest(r)
    quad_dwellers(dz, r, 'kanal', 2, 2)


HALL_DECO = {'Büyük Salon': deco_buyuk_salon, 'Kemik Katedrali': deco_katedral, 'Boynuz Tapınağı': deco_tapinak,
             'Kristal Mağarası': deco_magara, 'Kan Havzası': deco_havza}


# ================================================================================================ ana akış
def main(write=False):
    t0 = time.time()
    gen = Gen()
    lay = gen.lay
    gen.place()
    gen.carve()
    print('yerleşim: oda %d, %.1f sn' % (len(lay.rooms), time.time() - t0))
    lay.fix_thickness(min_v=4, min_h=2)
    gen.connect_unreached()
    lay.fix_thickness(min_v=4, min_h=2)
    ok = gen.repair_blockage()
    lay.fix_thickness(min_v=4, min_h=2)
    print('1 satırlık basamak düzeltmesi: %d hücre kazıldı' % normalize_steps(lay))
    gen._restamp_roads()
    spawn = gen.halls[0].center()
    dropped = lay.keep_main_component(spawn)
    print('kaçış onarımı: %s, ana bileşen dışı silinen %d hücre, %.1f sn' % ('temiz' if ok else 'KUSURLU', dropped, time.time() - t0))

    # kan kanalları (Et kanal odaları + Kan Havzası)
    th_rooms = {th: [r for r in lay.rooms if r.theme == th and not r.hall] for th in THEMES}
    th_halls = {th: [r for r in gen.halls if r.theme == th] for th in THEMES}
    bridges = EK.carve_canals(View(lay, th_rooms['et']), random.Random(SEED + 5)) if 'et' in THEMES else []
    for r in gen.halls:
        if r.flags.get('kanal'):
            bridges += carve_lake(lay, r)

    tm = theme_map(gen)
    mb = make_bank()
    tbs = {th: ThemeBank(mb, th) for th in THEMES}
    gtl = Z.TileLayers(W, H, ORDER)
    tls = {th: Z.TileLayers(W, H, ORDER) for th in THEMES}
    corr = (lay.corr_id >= 0) & (lay.room_id < 0)
    # boyama görünümleri: temanın tüm odaları (salonlar dahil); Kristal Mağarası boyamada mağara sayılır (koyu tapınak yaması yok)
    pviews = {th: View(lay, th_rooms[th] + th_halls[th], corr & (tm == TID[th])) for th in THEMES}
    painters = {
        'kemik': lambda reg=None: P.paint_walls_34(pviews['kemik'], tbs['kemik'], tls['kemik'], 'wf', floor=(2, 8), region=reg),
        'boynuz': lambda reg=None: P.paint_walls_34(pviews['boynuz'], tbs['boynuz'], tls['boynuz'], 'wf', floor=(2, 8), region=reg),
        'et': lambda reg=None: EK.paint_walls(pviews['et'], tbs['et'], tls['et'], region=reg),
    }
    painters = {th: painters[th] for th in THEMES}

    def repaint(reg):
        x0, y0, x1, y1 = max(0, reg[0]), max(0, reg[1]), min(W, reg[2]), min(H, reg[3])
        for th in THEMES:
            painters[th](reg)
            m = tm[y0:y1, x0:x1] == TID[th]
            for name in ('Zemin', 'Duvar'):
                g = gtl.L[name][y0:y1, x0:x1]
                g[m] = tls[th].L[name][y0:y1, x0:x1][m]

    saved = {}
    for r in gen.halls:
        if r.flags.get('magara'):
            saved[r.id] = r.kind
            r.kind = 'magara'
    if 'kemik' in THEMES:
        KM.paint_base(pviews['kemik'], tbs['kemik'], tls['kemik'])
    if 'boynuz' in THEMES:
        BK.paint_base(pviews['boynuz'], tbs['boynuz'], tls['boynuz'])
    if 'et' in THEMES:
        EK.paint_base(pviews['et'], tbs['et'], tls['et'], random.Random(SEED + 5), bridges)
    for r in lay.rooms:
        if r.id in saved:
            r.kind = saved[r.id]
    for name in BASE_LAYERS:
        for th in THEMES:
            m = tm == TID[th]
            gtl.L[name][m] = tls[th].L[name][m]
    print('boyama: %.1f sn' % (time.time() - t0))

    # süsleme: ortak durum (doluluk / saklanma / kapı / ayrılmış yol payı) + tema başına süsleyici
    base = P.Decorator(lay, tbs[THEMES[0]], gtl, seed=SEED, paint=repaint)
    base.spawn = spawn
    dzs = {}
    for i, th in enumerate(THEMES):
        dz = P.Decorator(View(lay, th_rooms[th], corr & (tm == TID[th])), tbs[th], gtl, seed=SEED + 11 * (i + 1), paint=repaint)
        dz.occ, dz.hide, dz.gate, dz.reserve, dz.doorway = base.occ, base.hide, base.gate, base.reserve, base.doorway
        dz.spawn = spawn
        dzs[th] = dz
    for kind, bx, by in bridges:
        dzs['et'].put('Eşya alt', EK.BRIDGE_V if kind == 'v' else EK.BRIDGE_H, bx, by)
    ## doğuş: ilk salonun ortasına en yakın açık zemin (kanal / süs yok), 3x2
    sx, sy = spawn_cell(lay, gen.halls[0])
    for dz in dzs.values():
        dz.spawn = (sx, sy)
    dzs[gen.halls[0].theme].add_obj('dogus', 'Doğuş', sx - 1, sy - 1, 3, 2)
    for yy in range(sy - 2, sy + 2):
        for xx in range(sx - 2, sx + 3):
            base.reserve[yy, xx] = True
    for r in gen.halls:
        HALL_DECO[r.hall](dzs[r.theme], r)
    for th in THEMES:
        MOD[th].decorate(dzs[th])
    objs = []
    for th in THEMES:
        for o in dzs[th].objects:
            o.setdefault('props', {})['tema'] = th
            objs.append(o)
    P.write_engel(lay, mb, gtl, base)
    print('süsleme: %.1f sn, nesne %d' % (time.time() - t0, len(objs)))

    # rapor
    gates = [P.obj_cells(o) for o in objs if o['type'] == 'kapi']
    rep = escape_final(gen, base, gates)
    counts = {}
    for o in objs:
        counts[o['type']] = counts.get(o['type'], 0) + 1
    print('oda %d (salon %d), zemin %d hücre (%%%.1f), nesneler %s' % (len(lay.rooms), len(gen.halls), rep['zemin'],
                                                                       100.0 * rep['zemin'] / (W * H), counts))
    print('kaçış:', rep)
    for s in gen.log:
        print(' ', s)
    for n in lay.notes + sum((d.notes for d in dzs.values()), []):
        print(' ', n)
    os.makedirs(Z.OUT, exist_ok=True)
    pre = OUT_PREFIX
    Z.semantic_png(lay, objs, os.path.join(Z.OUT, pre + '_sema.png'), scale=3)
    if len(THEMES) > 1:
        theme_png(tm, lay, os.path.join(Z.OUT, pre + '_tema.png'))
    img = Z.render(mb, gtl, W, H, skip=('Engel',))
    img.resize((W * 4, H * 4), Z.Image.BOX).save(os.path.join(Z.OUT, pre + '_tam.png'))
    for nm, (x0, y0, x1, y1) in (CROPS or ()):
        img.crop((x0 * 16, y0 * 16, x1 * 16, y1 * 16)).save(os.path.join(Z.OUT, '%s_%s.png' % (pre, nm)))
    print('önizleme: %.1f sn' % (time.time() - t0))
    if write:
        mb.write_files()
        if 'kemik' in THEMES:
            P.copy_runtime_sheets(KM.RL, ID, KM.RUNTIME_SHEETS)
        for name, src in (EK.RUNTIME_SHEETS if 'et' in THEMES else []) + (BK.RUNTIME_SHEETS if 'boynuz' in THEMES else []):
            P.copy_runtime_sheets(src, ID, [name])
        Z.write_tmx(TMX, mb, gtl, objs, W, H, props={'zindan': ID, 'ad': TITLE, 'harita': 'alternatif'}, hidden=('Engel',))
        print('yazıldı', TMX)
    return gen, mb, gtl, objs


def spawn_cell(lay, r):
    """Salonun ortasına en yakın, çevresi (5x4) tamamen açık zemin hücresi."""
    cx, cy = r.center()
    best = None
    for y in range(r.y + 3, r.y + r.h - 3):
        for x in range(r.x + 3, r.x + r.w - 3):
            if (lay.t[y - 2:y + 2, x - 2:x + 3] == Z.F).all() and not lay.solid_obj[y - 2:y + 2, x - 2:x + 3].any():
                d = (x - cx) ** 2 + (y - cy) ** 2
                if best is None or d < best[0]:
                    best = (d, x, y)
    return (best[1], best[2]) if best else (cx, cy)


def escape_final(gen, dz, gates):
    lay = gen.lay
    p = lay.passable() & ~np.zeros_like(dz.gate)
    samples = gen.room_samples(p)
    hs = gen.hall_sample()
    lab = label(p)
    good = np.unique(lab[hs[0], hs[1]])
    good = good[good > 0]
    unreach = int((p & ~np.isin(lab, good)).sum())
    gate_fail = []
    for i, cells in enumerate(gates):
        m = p.copy()
        for (x, y) in cells:
            m[y, x] = False
        cut, _, _ = gen.cut_rooms(m, samples, hs)
        gate_fail += [(i, r.id) for r in cut]
    blk = gen.blockage()
    return {'zemin': int(p.sum()), 'ulasilmaz': unreach, 'kapi': len(gates), 'kapi_hatasi': gate_fail, 'tikanma_hatasi': len(blk),
            'tikanma_ornek': blk[:5]}


def theme_png(tm, lay, path, scale=2):
    cols = {1: (150, 150, 160), 2: (170, 70, 60), 3: (70, 150, 190)}
    img = Z.Image.new('RGB', (W, H))
    px = img.load()
    for y in range(H):
        for x in range(W):
            c = cols.get(int(tm[y, x]), (0, 0, 0))
            if lay.t[y, x] == Z.S:
                c = tuple(v // 3 for v in c)
            px[x, y] = c
    img.resize((W * scale, H * scale), Z.Image.NEAREST).save(path)


if __name__ == '__main__':
    main('--write' in sys.argv)
