# ET KUYUSU (Batı zindanı, madde 373): "Kanalizasyon Tileseti" tuğla tünelleri + çatlak kumtaşı + KAN KANALLARI (kanalizasyon suyu kana boyandı),
# "Hapishane Assetleri" hücre koğuşu, "Zindan Eşyaları" simya laboratuvarı (canavarlı şişeler, iksir masaları, giyotin), "Lanetli Toprak" et bitkileri.
# Kaynak: KAN KEHRİBARI (et keselerinden). Sunak = Simyacı (laboratuvar). Kaçış: kanallar geçilmez ama görüşü kesmez -> köprüler darboğaz;
# kafesli kanal kapıları (kuzey ağızlar) + et duvarı (yatay koridorlar), 3 çıkış (kuyu merdiveni + batı/doğu merdiven).
# Çalıştır: python tools/zindan/gen_et_kuyusu.py [--write]
import colorsys
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zindan_core as Z  # noqa: E402
import zindan_paint as P  # noqa: E402

ID = 'et_kuyusu'
KZ = os.path.join(Z.ART, 'Kanalizasyon Tileseti', 'Tiled_files')
HP = os.path.join(Z.ART, 'Hapishane Assetleri', 'Tiled_files')
ZE = os.path.join(Z.ART, 'Zindan Esyalari Assetleri', 'Tiled_files')
LT = os.path.join(Z.ART, 'Lanetli Toprak Tileseti', 'Tiled_files')
SAMPLE = os.path.join(KZ, 'Inside.tmx')
W, H = 116, 112
SEED = 9203
TMX = os.path.join(Z.ZROOT, 'et_kuyusu.tmx')

ORDER = ['Kan', 'Zemin', 'Zemin ayrıntı', 'Zemin süsü', 'Duvar', 'Duvar süsü', 'Eşya alt', 'Eşya', 'Eşya üst', 'Engel']
RUNTIME_SHEETS = [('Door_darker-lattice.png', KZ), ('Lever.png', KZ), ('Guillotine.png', ZE), ('Alchemist_Idle.png', KZ)]

# ---- karolar
LADDER = ('ze', (18, 9, 2, 4))
LADDER2 = ('ze', (21, 9, 2, 4))
WOOD_STAIRS = ('ze', (14, 10, 3, 3))
CRATES = [('kd', (0, 0, 3, 4)), ('kd', (3, 0, 3, 4)), ('kd', (6, 0, 3, 4)), ('kd', (11, 0, 3, 4)), ('kd', (0, 4, 3, 3)), ('kd', (3, 4, 3, 3)),
          ('kd', (6, 4, 4, 3))]
BARRELS = [('kd', (14, 0, 2, 2)), ('kd', (18, 0, 2, 2)), ('kd', (22, 0, 2, 2)), ('kd', (26, 0, 2, 2)), ('kd', (14, 2, 2, 2)), ('kd', (16, 2, 2, 2))]
BOXES = [('kd', (10, 4, 2, 3)), ('kd', (12, 4, 2, 3)), ('kd', (14, 4, 2, 3)), ('kd', (16, 4, 2, 3)), ('kd', (0, 7, 2, 3)), ('kd', (2, 7, 2, 3))]
MUSHROOMS = [('kd', (11, 7, 2, 3)), ('kd', (13, 7, 2, 2)), ('kd', (15, 7, 3, 3)), ('kd', (18, 7, 2, 3)), ('kd', (22, 7, 3, 2)),
             ('kd', (25, 7, 2, 2)), ('kd', (0, 10, 2, 2)), ('kd', (2, 10, 2, 2)), ('kd', (4, 10, 2, 2)), ('kd', (8, 10, 2, 2))]
BRIDGE_V = ('kd', (6, 7, 2, 3))   # yatay kanalın üstünden geçen dikey tahta köprü (2 geniş, 3 boy)
BRIDGE_H = ('kd', (8, 7, 3, 2))   # dikey kanalın üstünden geçen yatay köprü (3 geniş, 2 boy)
MOSS = [('kt', (0, 0, 2, 3)), ('kt', (3, 0, 3, 2)), ('kt', (12, 0, 3, 2)), ('kt', (6, 2, 3, 3)), ('kt', (11, 2, 2, 2)), ('kt', (13, 2, 2, 2))]
FIRES = [('kf', (0, 2, 3, 3))]
# Walls_floor_downstairs satır 9-10: 2 satırlık kuru duvar yüzüne oturan kemer (açık gider ağzı / kapalı kemer)
ARCH2 = [('wd', (3, 9, 3, 2)), ('wd', (0, 9, 3, 2)), ('wd', (9, 9, 3, 2))]
WEBS = [('kw', (0, 0, 5, 4)), ('kw', (10, 0, 4, 4)), ('kw', (14, 0, 5, 3))]
CELL_DOOR = ('hd', (0, 0, 2, 3))      # hapishane hücre kapısı (kafes) - duvar yüzünde
CELL_WINDOW = ('hd', (0, 3, 2, 3))
CHAINED = [('hc', (0, 0, 2, 3)), ('hc', (2, 0, 2, 3))]
BUNK = ('ho', (0, 0, 3, 4))
SHELVES = [('ho', (3, 0, 2, 4)), ('ho', (5, 0, 2, 4))]
BANNER = ('ho', (9, 0, 2, 4))
DESK = [('ho', (2, 4, 4, 3)), ('ho', (6, 4, 3, 3))]
HAY = [('ho', (1, 13, 4, 4)), ('ho', (5, 13, 4, 4)), ('ho', (9, 14, 3, 3))]
BEDS = [('ho', (7, 10, 2, 3)), ('ho', (9, 10, 2, 3))]
ROOT_PODS = [('ze', (0, 0, 5, 5)), ('ze', (1, 5, 3, 4)), ('ze', (4, 5, 4, 4)), ('ze', (8, 6, 3, 3))]
JARS = [('ze', (14, 0, 3, 4)), ('ze', (19, 1, 2, 3)), ('ze', (14, 5, 3, 4)), ('ze', (19, 6, 2, 3))]
ALCH_TABLES = [('ze', (1, 16, 3, 3)), ('ze', (8, 16, 3, 3)), ('ze', (20, 16, 3, 3)), ('ze', (7, 19, 3, 3)), ('ze', (14, 19, 3, 3))]
ALCH_SHELVES = [('ze', (4, 15, 2, 4)), ('ze', (6, 15, 2, 4)), ('ze', (11, 15, 2, 4)), ('ze', (13, 15, 2, 4)), ('ze', (18, 15, 2, 4))]
FLASKS = [('zf', (0, 0, 3, 4)), ('zf', (5, 1, 2, 3)), ('zf', (3, 2, 2, 2)), ('zf', (7, 2, 2, 2))]
FLESH_ROCK = [('lt', (1, 8, 5, 5)), ('lt', (6, 8, 4, 4)), ('lt', (1, 17, 5, 5)), ('lt', (6, 18, 4, 4))]
FLESH_PLANTS = [('lt', (11, 28, 5, 5)), ('lt', (17, 28, 4, 4)), ('lt', (8, 49, 5, 6)), ('lt', (9, 35, 6, 6)), ('lt', (8, 41, 5, 6))]
EYE_PODS = [('lt', (1, 13, 5, 4)), ('lt', (6, 13, 4, 4)), ('lt', (43, 50, 3, 5))]
BONES_LT = [('lt', (1, 22, 3, 3)), ('lt', (4, 22, 3, 3))]
MAW = ('lt', (21, 19, 4, 5))
BIG_EYE = ('lt', (1, 25, 9, 8))
ROOT_VEIN = [('lt', (22, 58, 9, 9)), ('lt', (31, 61, 8, 5))]


def blood(img, dark=0.85):
    """Kanalizasyonun yeşil/camgöbeği suyunu kana çevirir: yeşil-mavi tonlu, doygun pikseller kırmızı tona (ton ~0,99) döner."""
    im = img.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if 0.25 <= h <= 0.58 and s > 0.22 and v > 0.18:
                nh = 0.985 + (h - 0.4) * 0.05
                nr, ng, nb = colorsys.hsv_to_rgb(nh % 1.0, min(1.0, s * 1.15 + 0.1), v * dark)
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return im


def flesh_floor(img):
    """Su altı zemini (kanal tabanı): koyu kan."""
    im = img.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            v = (r * 0.3 + g * 0.55 + b * 0.15) / 255.0
            v = max(0.0, min(1.0, (v - 0.25) * 2.2))  # kontrast: taban dokusu seçilsin
            px[x, y] = (int(48 + v * 150), int(6 + v * 26), int(12 + v * 26), a)
    return im


def flask_anims(img):
    """Flasks_monsters: 6 kare, kare adımı 4 satır (tüm 4 tür)."""
    cols = img.width // 16
    out = {}
    for y in range(4):
        for x in range(cols):
            lid = y * cols + x
            out[lid] = [((y + 4 * k) * cols + x, 160) for k in range(6)]
    return out


def make_bank():
    bank = Z.TilesetBank(ID)
    wsrc = os.path.join(KZ, 'Walls_water_downstairs.png')
    bank.add('sw', wsrc, name='duvar_kanli.png', img=blood(Z.open_sheet(wsrc)), anims=Z.sample_anims(SAMPLE, 'Walls_water_downstairs'))
    bank.add('fc', os.path.join(KZ, 'walls_floor_cracks_darker.png'))
    bank.add('wd', os.path.join(KZ, 'Walls_floor_downstairs.png'), name='duvar_kuru.png')
    usrc = os.path.join(KZ, 'floor_walls_under_water.png')
    bank.add('uw', usrc, name='kanal_tabani.png', img=flesh_floor(Z.open_sheet(usrc)))
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
    bank.add('zf', os.path.join(ZE, 'Flasks_monsters.png'), img=fl, anims=flask_anims(fl))
    bank.add('lt', os.path.join(LT, 'Objects.png'), name='et_nesneleri.png')
    bank.add('eng', 'engel', name='engel.png', img=Z.make_marker_sheet())
    return bank


def build_layout(seed=SEED):
    lay = Z.Layout(W, H, seed)
    giris = lay.add_room(50, 7, 15, 10, 'giris')
    lay.add_room(44, 88, 28, 16, 'kalp')
    lay.add_room(4, 50, 11, 9, 'cikis')
    lay.add_room(101, 60, 11, 9, 'cikis')
    lay.scatter_rooms([
        (4, (19, 23), (12, 14), 'kanal'),
        (2, (17, 21), (10, 12), 'hucre'),
        (3, (14, 17), (10, 12), 'bahce'),
        (9, (8, 11), (6, 8), 'oda'),
    ], mx=8, my=11)
    lay.build_graph(k=3, loop_ratio=0.5, max_len=55)
    lay.carve_rooms()
    lay.carve_all_corridors(width=Z.CORRIDOR_W)
    lay.fix_thickness(min_v=4, min_h=2)
    exits = [r.center() for r in lay.rooms if r.kind in ('giris', 'cikis')]
    Z.repair_escape(lay, exits, width=Z.CORRIDOR_W)
    lay.fix_thickness(min_v=4, min_h=2)
    lay.keep_main_component(giris.center())
    return lay


# ------------------------------------------------------------------------------------------------ kan kanalları (geometri)
def carve_canals(lay, rng):
    """'kanal' odalarına odayı ikiye bölen 3 hücrelik kan kanalı + 2 köprü (köprü hücreleri yürünür). Kanalın uçlarına koridor
    giriyorsa (oda kenarında aynı satırda/sütunda zemin varsa) o yön denenmez; ikisi de olmazsa ortada köprüsüz havuz."""
    bridges = []
    t = lay.t
    for r in lay.rooms:
        if r.kind != 'kanal':
            continue
        cx, cy = r.center()
        options = ['h', 'v']
        rng.shuffle(options)
        done = False
        for o in options:
            if o == 'h':
                y0 = cy - 1
                rows = range(y0, y0 + 3)
                if any(t[y, r.x - 1] != Z.S or t[y, r.x + r.w] != Z.S for y in rows):
                    continue
                for y in rows:
                    for x in range(r.x, r.x + r.w):
                        t[y, x] = Z.W
                for bx in (r.x + r.w // 3 - 1, r.x + 2 * r.w // 3 - 1):
                    for y in rows:
                        for x in (bx, bx + 1):
                            t[y, x] = Z.F
                    bridges.append(('v', bx, y0))
                done = True
            else:
                x0 = cx - 1
                cols = range(x0, x0 + 3)
                if any(t[r.y - 1, x] != Z.S or t[r.y + r.h, x] != Z.S for x in cols):
                    continue
                for x in cols:
                    for y in range(r.y, r.y + r.h):
                        t[y, x] = Z.W
                for by in (r.y + r.h // 3 - 1, r.y + 2 * r.h // 3 - 1):
                    for x in cols:
                        for y in (by, by + 1):
                            t[y, x] = Z.F
                    bridges.append(('h', x0, by))
                done = True
            if done:
                break
        if not done:
            # ortada havuz (köprüsüz): odanın iç halkasına ve artısına değmez
            pw, ph = max(3, r.w // 3), 3
            px0, py0 = cx - pw // 2 + (pw // 2 + 2), cy - 4
            for y in range(py0, py0 + ph):
                for x in range(px0, px0 + pw):
                    if r.inside(x, y) and x < r.x + r.w - 2 and y > r.y + 1:
                        t[y, x] = Z.W
    return bridges


def paint_canals(lay, bank, tl, rng, bridges):
    t = lay.t
    Hh, Ww = t.shape
    for y in range(Hh):
        for x in range(Ww):
            if t[y, x] == Z.W:
                c = (6 + rng.randrange(5), 7)
                tl.put('Kan', x, y, bank.gid('uw', c[0], c[1]))
                tl.put('Zemin', x, y, 0)
    bridge_cells = set()
    for kind, bx, by in bridges:
        if kind == 'v':
            for j in range(3):
                for i in range(2):
                    bridge_cells.add((bx + i, by + j))
        else:
            for j in range(2):
                for i in range(3):
                    bridge_cells.add((bx + i, by + j))
    for (x, y) in bridge_cells:
        tl.put('Kan', x, y, bank.gid('uw', 6 + (x + y) % 5, 7))
        tl.put('Zemin', x, y, 0)
    return bridge_cells


# Zemin: çatlaklı kumtaşı (fc 2..8 x 1..8) + KENAR ÇERÇEVESİ (boşluğa/kanala bakan zemin = kumtaşı dudak; örnek haritanın platformları;
# eskiden zemin boşluğa çıplak değiyordu) + koyu çatlak yamaları (fc 16..20 x 11..15, yumuşak kenarlı 9 parça) + tuğla kırıkları
# (duvar dibinde) + lekeler. Kuru duvar yüzü Walls_floor_downstairs (2 satır, uçlar komşu hücreye taşar); kanala bakan duvar su
# çizgili Walls_water_downstairs (kan rengi). Eskiden kuru zeminde de kan çizgili su duvarı + sağ uçta boş karo (siyah kare) vardı.
FLOOR_POOL = [(x, y) for x in range(2, 9) for y in range(1, 9)]
FRAME = {'T': lambda x, y: (2 + (x * 3) % 7, 0), 'B': lambda x, y: (2 + (x * 5) % 7, 9), 'L': lambda x, y: (1, 1 + (y * 5) % 8),
         'R': lambda x, y: (9, 1 + (y * 3) % 8), 'TL': (1, 0), 'TR': (9, 0), 'BL': (1, 9), 'BR': (9, 9)}
CRACK9 = ((16, 11), [(17, 11), (18, 11), (19, 11)], (20, 11), [(16, 12), (16, 13), (16, 14)],
          [(17, 12), (18, 12), (19, 12), (17, 13), (18, 13), (19, 13), (17, 14), (18, 14), (19, 14)], [(20, 12), (20, 13), (20, 14)],
          (16, 15), [(17, 15), (18, 15), (19, 15)], (20, 15))
BRICK_BITS = [(0, 11), (1, 11), (2, 11), (3, 11), (0, 12), (1, 12), (2, 12), (3, 12), (4, 12), (5, 12), (6, 12), (7, 12), (8, 12),
              (9, 12), (10, 12), (11, 12), (12, 12), (13, 12)]
SPOTS = [(0, 0), (2, 0), (4, 0), (7, 0), (8, 0), (1, 2), (5, 2), (13, 2), (11, 3), (2, 4), (2, 5), (10, 5), (2, 7), (7, 7), (7, 8), (13, 8), (4, 9)]


def paint_walls(lay, bank, tl, region=None):
    P.paint_walls_34(lay, bank, tl, 'sw', floor=(4, 4), region=region, top=((1, 1),) * 6,
                     face_key='wd', face_rows={1: 5, 2: ('sw', 6, (1, [2, 3, 4], 5)), 3: ('sw', 5, (1, [2, 3, 4], 5))},
                     face_cols=(14, [15, 16, 17], 18), face_caps=(13, 19),
                     water_face=('sw', {1: 7, 2: 6, 3: 5}, (1, [2, 3, 4], 5)),
                     floor_fn=lambda x, y: ('fc', P.hpick(FLOOR_POOL, x, y)))


def paint_base(lay, bank, tl, rng=None, bridges=()):
    """Duvar + zemin + kanal + çerçeve + yamalar/ayrıntı. Süslemeden önce; test_desen.py de bunu çağırır. Dönüş: köprü hücreleri."""
    import random
    h, w = lay.t.shape
    rng = rng or random.Random(SEED + 5)
    paint_walls(lay, bank, tl)
    bridge_cells = paint_canals(lay, bank, tl, rng, bridges)
    P.floor_frame(lay, bank, tl, 'fc', FRAME, skip=lambda x, y: (x, y) in bridge_cells)
    # çerçeve karosunun kanala bakan yarısı saydam: altına kanal tabanı (yoksa kenarda siyah şerit görünüyordu)
    t = lay.t
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if t[y, x] == Z.F and (x, y) not in bridge_cells and Z.W in (t[y - 1, x], t[y + 1, x], t[y, x - 1], t[y, x + 1]):
                tl.put('Kan', x, y, bank.gid('uw', 6 + (x + y) % 5, 7))
    dist = P.wall_distance(lay, cap=5)
    mask = (lay.t == Z.F) & (dist >= 2)
    for (x, y, rw, rh) in P.place_rugs(mask, P.value_noise(w, h, SEED + 4, 8.0), 0.6, random.Random(SEED + 9),
                                       sizes=((5, 5), (4, 4), (5, 4), (4, 3), (3, 3)), gap=2):
        P.nine_slice(tl, bank, 'Zemin ayrıntı', 'fc', CRACK9, x, y, rw, rh)
    P.floor_details(lay, bank, tl, 'wd', BRICK_BITS, density=0.16, seed=SEED + 2, layer='Zemin süsü', mask=(dist == 1))
    P.floor_details(lay, bank, tl, 'ks', SPOTS, density=0.05, seed=SEED, layer='Zemin ayrıntı', mask=(dist >= 2))
    return bridge_cells


def main(write=False):
    import random
    lay = build_layout()
    rng = random.Random(SEED + 5)
    bridges = carve_canals(lay, rng)
    bank = make_bank()
    tl = Z.TileLayers(W, H, ORDER)
    paint = lambda reg=None: paint_walls(lay, bank, tl, region=reg)  # noqa: E731
    dz = P.Decorator(lay, bank, tl, seed=SEED, paint=paint)
    dz.hatch_spec = WOOD_STAIRS
    bridge_cells = paint_base(lay, bank, tl, rng, bridges)
    for kind, bx, by in bridges:
        dz.put('Eşya alt', BRIDGE_V if kind == 'v' else BRIDGE_H, bx, by)
    decorate(dz)
    objs = dz.objects
    P.write_engel(lay, bank, tl, dz)
    os.makedirs(Z.OUT, exist_ok=True)
    Z.semantic_png(lay, objs, os.path.join(Z.OUT, 'et_sema.png'))
    exits = [P.obj_center_cell(o) for o in objs if o['type'] == 'cikis']
    gates = [P.obj_cells(o) for o in objs if o['type'] == 'kapi']
    rep = Z.escape_report(lay, exits, gates)
    print('oda', len(lay.rooms), 'kenar', len(lay.edges), 'nesne', len(objs), 'köprü', len(bridges))
    print('kaçış:', {k: v for k, v in rep.items() if k != 'tikanma_hatasi'}, 'tıkanma hatası', len(rep['tikanma_hatasi']))
    for n in lay.notes + dz.notes:
        print(n)
    img = Z.render(bank, tl, W, H, skip=('Engel',))
    img.save(os.path.join(Z.OUT, 'et_tam.png'))
    if write:
        bank.write_files()
        for name, src in RUNTIME_SHEETS:
            P.copy_runtime_sheets(src, ID, [name])
        # kan rengindeki kafes kapı sayfası değişmez; kesenin çalışma anı görseli lanetli toprak sayfasından
        Z.write_tmx(TMX, bank, tl, objs, W, H, props={'zindan': ID, 'ad': 'Et Kuyusu'}, hidden=('Engel',))
        print('yazıldı', TMX)
    return lay, bank, tl, dz


def decorate(dz):
    lay = dz.lay
    rng = dz.rng
    for r in lay.rooms:
        if r.kind == 'giris':
            dz.exit_stairs(r, LADDER, 'Kuyu Merdiveni', main=True)
            dz.wall_fires(r, FIRES, step=6, light=P.AMBER)
            dz.scatter(r, BARRELS, 2, solid=True)
            dz.corner_webs(r, key='kw')
            dz.spawn_point(r)
        elif r.kind == 'cikis':
            west = r.x < W // 2
            dz.exit_stairs(r, LADDER2 if west else LADDER, 'Taşma Merdiveni' if west else 'Kanal Merdiveni')
            dz.wall_fires(r, FIRES, step=7, light=P.AMBER)
            dz.scatter(r, MUSHROOMS, 3)
            dz.scatter(r, CRATES, 1, solid=True)
        elif r.kind == 'kalp':
            dz.altar(r, ALCH_TABLES[0], 'Simyacı', light=P.AMBER, light_r=130)
            dz.npc_spot(r, 'simyaci')
            dz.resource_nodes(r, 'et_kesesi', 2)
            dz.wall_row(r, ALCH_SHELVES, step=3, layer='Eşya', solid=True)
            dz.scatter(r, FLASKS, 5, solid=True, light=P.RED)
            dz.scatter(r, ALCH_TABLES[1:], 3, solid=True)
            dz.scatter(r, JARS, 3, solid=True)
            dz.wall_fires(r, FIRES, step=6, light=P.AMBER)
            dz.dwellers(r, 'lab')
        elif r.kind == 'kanal':
            dz.resource_nodes(r, 'et_kesesi', 1)
            dz.wall_fires(r, FIRES, step=7, light=P.AMBER)
            dz.scatter(r, CRATES, 2, solid=True)
            dz.scatter(r, BARRELS, 3, solid=True)
            dz.scatter(r, MUSHROOMS, 3)
            dz.wall_hangings(r, MOSS, step=5)
            dz.corner_webs(r, key='kw')
            dz.dwellers(r, 'kanal')
        elif r.kind == 'hucre':
            dz.wall_row(r, [CELL_DOOR, CELL_WINDOW], step=3, layer='Duvar süsü', face=True)
            dz.wall_hangings(r, CHAINED, step=6)
            dz.hide_alcove(r, spec=('hd', (8, 0, 2, 3)))  # açık hücre kapısı = saklanma
            dz.scatter(r, HAY, 3)
            dz.scatter(r, BEDS + [BUNK], 2, solid=True)
            dz.wall_fires(r, FIRES, step=8, light=P.AMBER)
            dz.dwellers(r, 'hucre')
        elif r.kind == 'bahce':
            dz.resource_nodes(r, 'et_kesesi', 2)
            dz.scatter(r, FLESH_PLANTS, 3, solid=True)
            dz.scatter(r, FLESH_ROCK, 2, solid=True)
            dz.scatter(r, EYE_PODS, 2, solid=True)
            dz.scatter(r, ROOT_PODS, 1, solid=True)
            dz.scatter(r, BONES_LT, 2)
            dz.hide_spot_object(r, ROOT_PODS[0], 'Et Kökü')
            dz.dwellers(r, 'bahce')
        else:
            roll = rng.random()
            if roll < 0.3:
                dz.chest(r)
                dz.scatter(r, BOXES, 2, solid=True)
            elif roll < 0.6:
                dz.scatter(r, CRATES + BARRELS, 3, solid=True)
            elif roll < 0.8:
                dz.scatter(r, FLESH_PLANTS[:2] + FLESH_ROCK[1:2], 2, solid=True)
            else:
                dz.scatter(r, DESK + SHELVES, 2, solid=True)
            dz.scatter(r, MUSHROOMS, 2)
            dz.corner_webs(r, key='kw')
            if rng.random() < 0.6:
                dz.dwellers(r, 'oda')
        _furnish(dz, r)
    dz.corridor_dressing(MUSHROOMS[:6], density=0.010)
    dz.corridor_glow(MUSHROOMS[:5], every=15, light=P.AMBER)
    dz.corridor_face_decor(ARCH2[:1] + [MOSS[1]] + ARCH2[1:] + [MOSS[2]], every=11, rows=2)
    dz.gates(max_count=7, styles=('kafes', 'barikat'), ns_narrow=False)
    dz.traps('giyotin', count=5)
    _extra_chests(dz)
    dz.hunter_route('kuyu_kasabi')



def _furnish(dz, r):
    """Odaya özel süslemeden SONRA: kuzey yüzüne kemer, duvar diplerine fıçı/kasa/raf (simya ve hücre odaları kendi düzeninde)."""
    if r.kind not in ('hucre',) and r.w >= 8:
        dz.wall_row(r, ARCH2, step=6 + dz.rng.randrange(4), layer='Duvar süsü', face=True)
    north = BARRELS + BOXES[:3] + (SHELVES if r.kind in ('kalp', 'oda') else [])
    dz.edge_props(r, north, 'n', step=2 + dz.rng.randrange(3), n_max=4)
    if r.kind != 'bahce':
        dz.edge_props(r, BARRELS + CRATES[4:6], 's', step=3 + dz.rng.randrange(3), n_max=3)
    else:
        dz.edge_props(r, FLESH_PLANTS + MUSHROOMS, 's', step=2 + dz.rng.randrange(3), n_max=4)


def _extra_chests(dz):
    """Kalp odasında ELİT sandık + belirli oda türlerinde birer sandık (risk -> ödül)."""
    for r in dz.lay.rooms:
        if r.kind == 'kalp':
            dz.chest(r, elite=True)
        elif r.kind in ('hucre', 'bahce'):
            dz.chest(r)

if __name__ == '__main__':
    main('--write' in sys.argv)


def paint_test(lay):
    """test_desen.py: yalnız duvar + zemin boyaması (süsleme / kanal yok)."""
    bank = make_bank()
    h, w = lay.t.shape
    tl = Z.TileLayers(w, h, ORDER)
    # desende küçük bir kan kanalı (kanala bakan su çizgili duvar + kumtaşı çerçeve denemesi)
    lay.t[23:26, 56:70] = Z.W
    paint_base(lay, bank, tl)
    return bank, tl
