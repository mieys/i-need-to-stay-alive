# BOYNUZLU KAPI (Doğu zindanı, madde 373): "Piksel Zindan Assetleri" mavi-gri taş tapınak (duvar, merdiven, demir parmaklık, sandık, ateş, tuzak)
# + "Parlayan Mağara" (kristal, ışıyan mantar, ruh ışığı, ışıltı, TOTEM) + "Mağara Tileseti" (mavi kristal kümeleri, sarkıtlar, BOYNUZLU KAFATASI,
# kaynayan lav kayaları, dev örümcek bacakları). Organik mağara salonları (gürültülü elips) + düz tapınak salonları; kalp = Boynuz Totemi.
# Kaynak: IŞIK KRİSTALİ (kristal kümelerinden). Kaçış: sarkıt/kristal sütunları görüşü keser, demir parmaklık (kuzey ağızları) + kristal duvar
# (yatay koridorlar), 3 çıkış.
# Çalıştır: python tools/zindan/gen_boynuzlu_kapi.py [--write]
import colorsys
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zindan_core as Z  # noqa: E402
import zindan_paint as P  # noqa: E402

ID = 'boynuzlu_kapi'
D1 = os.path.join(Z.ART, 'Piksel Zindan Assetleri', 'Tiled_files')
PM = os.path.join(Z.ART, 'Parlayan Magara Tileseti', 'Tiled_files')
MG = os.path.join(Z.ART, 'Magara Tileseti', 'Tiled_files')
ZE = os.path.join(Z.ART, 'Zindan Esyalari Assetleri', 'Tiled_files')
S_D1 = os.path.join(D1, 'Dungeon1.tmx')
S_PM = os.path.join(PM, 'Glowing_cave.tmx')
S_MG = os.path.join(MG, 'Cave.tmx')
W, H = 150, 108
SEED = 6107
TMX = os.path.join(Z.ZROOT, 'boynuzlu_kapi.tmx')

ORDER = ['Zemin', 'Zemin ayrıntı', 'Zemin süsü', 'Duvar', 'Duvar süsü', 'Eşya alt', 'Eşya', 'Eşya üst', 'Engel']
RUNTIME_SHEETS = [('doors_lever_chest_animation.png', D1), ('trap_animation.png', D1)]

STAIRS_UP = ('d1o', (1, 1, 3, 4))
STAIRS_UP2 = ('d1o', (4, 1, 3, 4))
LADDER = ('d1o', (7, 1, 1, 4))
BRAZIER = [('d1f', (5, 0, 3, 3)), ('d1f', (8, 0, 3, 3))]
CANDLE = [('d1f2', (0, 0, 2, 2)), ('d1f2', (2, 0, 2, 2))]
CRATES = [('d1o', (17, 1, 2, 3)), ('d1o', (19, 1, 2, 3)), ('d1o', (3, 5, 2, 4)), ('d1o', (8, 5, 2, 3))]
BARRELS = [('d1o', (9, 1, 2, 2)), ('d1o', (21, 1, 2, 2)), ('d1o', (6, 5, 2, 2)), ('d1o', (11, 5, 2, 2)), ('d1o', (21, 5, 2, 2))]
VASES = [('d1o', (1, 7, 2, 2)), ('d1o', (6, 7, 2, 2))]
GOLD = [('d1o', (9, 3, 2, 2)), ('d1o', (11, 3, 2, 2))]
HORN_SKULL = [('mgo', (32, 25, 4, 5)), ('mgo', (37, 25, 4, 5))]   # boynuzlu kafatası anıtı (sarı ateşi camgöbeğine boyanır)
TOTEM = ('pmt', (0, 0, 6, 6))
# Mağara paketi: satır 1-6 / 10-16 YERDE duran kristaller; satır 7-9 (sütun 4-21), 5-9 (22-40), 17-18 ve 19-28 (kahverengi) TAVANDAN
# SARKAN küme / sarkıt (kaya üstte, uç aşağı) - eskiden yere konuyordu, "ters duran madenler". Sarkanlar artık duvar yüzünden sarkar
# (HANGING, wall_row face=True); yere yalnız dikitler (satır 29-33) ve duran kristaller.
BLUE_CRYSTAL_BIG = [('mgo', (1, 1, 4, 4)), ('mgo', (1, 10, 4, 4))]
BLUE_CRYSTAL = [('mgo', (1, 5, 3, 3)), ('mgo', (1, 14, 3, 3)), ('mgo', (4, 5, 2, 2)), ('mgo', (4, 14, 2, 2)), ('mgo', (24, 1, 3, 4))]
BLUE_SHARDS = [('mgo', (4, 14, 2, 2)), ('mgo', (4, 5, 2, 2)), ('mgo', (16, 5, 1, 1)), ('mgo', (17, 5, 1, 1))]
DARK_CRYSTAL = [('mgo', (5, 1, 4, 4)), ('mgo', (5, 10, 4, 4))]
STALAG = [('mgo', (6, 29, 3, 5)), ('mgo', (25, 29, 3, 5)), ('mgo', (1, 30, 3, 4)), ('mgo', (11, 30, 4, 4)), ('mgo', (30, 30, 4, 4))]
HANGING = [('mgo', (4, 7, 3, 3)), ('mgo', (7, 7, 3, 3)), ('mgo', (10, 7, 3, 3)), ('mgo', (13, 7, 3, 3)), ('mgo', (16, 7, 3, 3)),
           ('mgo', (24, 8, 3, 2)), ('mgo', (1, 19, 3, 4)), ('mgo', (4, 19, 3, 4)), ('pmd', (1, 6, 2, 5)), ('pmd', (3, 6, 2, 4)),
           ('pmd', (11, 6, 2, 5)), ('pmd', (13, 6, 2, 4))]
SPIDER = [('mgo', (4, 34, 6, 6)), ('mgo', (15, 34, 6, 6))]
WEB = [('mgo', (19, 46, 4, 3))]
PM_CRYSTALS = [('pmo', (1, 5, 3, 3)), ('pmo', (4, 5, 3, 3)), ('pmo', (7, 6, 2, 2)), ('pmo', (17, 37, 3, 5)), ('pmo', (15, 38, 2, 4))]
PINK_CRYSTALS = [('pmo', (1, 1, 3, 3)), ('pmo', (4, 1, 3, 3)), ('pmo', (7, 2, 2, 2))]
MUSHROOMS = [('pmo', (1, 8, 4, 6)), ('pmo', (13, 9, 3, 5)), ('pmo', (5, 10, 3, 4)), ('pmo', (8, 11, 2, 3)), ('pmo', (16, 11, 2, 3))]
MUSH_HOUSE = [('pmo', (1, 14, 5, 5)), ('pmo', (6, 15, 3, 4))]
GLOW_PLANTS = [('pmo', (1, 19, 4, 5)), ('pmo', (5, 21, 3, 3)), ('pmo', (8, 21, 2, 3)), ('pmo', (13, 22, 3, 4)), ('pmo', (16, 23, 2, 3))]
FERNS = [('pmo', (11, 19, 3, 3)), ('pmo', (14, 19, 2, 3)), ('pmo', (1, 32, 5, 5)), ('pmo', (6, 33, 4, 4))]
CORAL = [('pmo', (1, 24, 3, 3)), ('pmo', (4, 24, 2, 3)), ('pmo', (12, 27, 2, 3)), ('pmo', (14, 27, 2, 3)), ('pmo', (16, 27, 4, 3))]
JELLY = [('pmo', (1, 37, 6, 5)), ('pmo', (7, 37, 4, 5)), ('pmo', (11, 39, 3, 3))]
# Details: (1..4 / 11..14, 6..10) tavandan sarkan sarkıt (eskiden PILLARS'ta: yerde ters sivri siyah); dikitler (6..9 / 16..19, 7..9)
PILLARS = [('pmd', (5, 0, 3, 6)), ('pmd', (8, 0, 2, 6)), ('pmd', (15, 0, 3, 6)), ('pmd', (18, 0, 2, 6)), ('pmd', (6, 6, 2, 4)),
           ('pmd', (16, 6, 2, 4))]
MOSS = [('pmd', (10, 14, 3, 3)), ('pmd', (13, 14, 3, 3)), ('pmd', (16, 14, 4, 3))]
LAVA_ROCKS = [('mga', (0, 0, 4, 4)), ('mga', (4, 0, 4, 4))]
# walls_floor satır 25-27: 3 satırlık yüze oturan kemerli pencere / açık kemer / kapı / parmaklık (örnek haritanın Windows katmanı)
WIN_FACE = [('wf', (0, 25, 2, 3)), ('wf', (6, 25, 2, 3)), ('wf', (10, 25, 2, 3)), ('wf', (14, 25, 2, 3))]
SMALL_STONE = [('mgo', (16, 5, 1, 1)), ('mgo', (17, 5, 1, 1)), ('mgo', (18, 5, 1, 1)), ('mgo', (19, 5, 1, 1))]


def to_cyan(img):
    """Mağara kafatasının sarı/turuncu ateşini camgöbeğine çevirir (derin orman Boynuzlu Kapı'sıyla aynı yön, madde 361)."""
    im = img.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if 0.03 <= h <= 0.19 and s > 0.45 and v > 0.45:
                nr, ng, nb = colorsys.hsv_to_rgb(0.5 + (h - 0.1) * 0.3, s * 0.9, min(1.0, v * 1.05))
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return im


def make_bank():
    bank = Z.TilesetBank(ID)
    bank.add('wf', os.path.join(D1, 'walls_floor.png'))
    bank.add('d1o', os.path.join(D1, 'Objects.png'), name='tapinak_esyalari.png')
    bank.add('d1f', os.path.join(D1, 'fire_animation.png'), anims=Z.sample_anims(S_D1, 'fire_animation'))
    bank.add('d1f2', os.path.join(D1, 'fire_animation2.png'), anims=Z.sample_anims(S_D1, 'fire_animation2'))
    bank.add('pmo', os.path.join(PM, 'Objects.png'), name='isiyan_nesneler.png')
    bank.add('pmd', os.path.join(PM, 'Details.png'), name='isiyan_ayrinti.png')
    bank.add('pms', os.path.join(PM, 'Shinies_animation.png'), anims=Z.sample_anims(S_PM, 'Shinies_animation'))
    bank.add('pmw', os.path.join(PM, 'Wisps.png'), anims=Z.sample_anims(S_PM, 'Wisps'))
    bank.add('pmt', os.path.join(PM, 'Totem_animation.png'), anims=Z.sample_anims(S_PM, 'Totem_animation'))
    msrc = os.path.join(MG, 'Objects.png')
    bank.add('mgo', msrc, name='magara_nesneleri.png', img=to_cyan(Z.open_sheet(msrc)))
    bank.add('mga', os.path.join(MG, 'Objects_animated.png'), name='lav_kayalari.png', anims=Z.sample_anims(S_MG, 'Objects_animated'))
    bank.add('eng', 'engel', name='engel.png', img=Z.make_marker_sheet())
    return bank


def build_layout(seed=SEED):
    lay = Z.Layout(W, H, seed)
    giris = lay.add_room(66, 7, 16, 10, 'giris')
    lay.add_room(58, 82, 30, 16, 'kalp')
    lay.add_room(5, 44, 11, 9, 'cikis')
    lay.add_room(134, 58, 11, 9, 'cikis')
    lay.scatter_rooms([
        (4, (20, 26), (13, 16), 'magara'),
        (2, (18, 22), (12, 14), 'kristal'),
        (2, (18, 22), (10, 12), 'salon'),
        (10, (9, 12), (7, 9), 'oda'),
    ], mx=8, my=11)
    # mağara/kristal salonları da DİKDÖRTGEN: gürültülü elips (carve_blob) çapraz kenarlarda basamak basamak 1 hücrelik duvar yüzleri
    # bırakıyordu (tuğla duvar paketi çaprazı çizemez); mağara hissi süs (dikitler, kristal sütunları, ışıyan bitkiler) ile verilir.
    lay.build_graph(k=3, loop_ratio=0.55, max_len=60)
    lay.carve_rooms()
    lay.carve_all_corridors(width=Z.CORRIDOR_W)
    lay.fix_thickness(min_v=4, min_h=2)
    exits = [r.center() for r in lay.rooms if r.kind in ('giris', 'cikis')]
    Z.repair_escape(lay, exits, width=Z.CORRIDOR_W)
    lay.fix_thickness(min_v=4, min_h=2)
    lay.keep_main_component(giris.center())
    return lay


# Zemin: açık taş levha (2, 8) + gürültü öbeklerinde çatlaklı açık varyantlar (7..8, 13..14; TAM karo, tabanı ezer) + KOYU YÜZEY
# halıları (11..13, 13..15 dokuz parça; içi 9..10 koyu çatlaklı) - örnek haritanın Floor / Floor_darker_surface katmanları. Koyu
# çatlak karoları tam opak koyu kare: açık zemine konunca "koyu kare" gibi duruyordu, artık yalnız halı içinde.
DARK9 = ((11, 13), (12, 13), (13, 13), (11, 14), [(12, 14), (12, 14), (12, 14), (9, 13), (10, 13), (9, 14), (10, 14)], (13, 14),
         (11, 15), (12, 15), (13, 15))
LIGHT_CRACK = [(7, 13), (8, 13), (7, 14), (8, 14)]
RUG_ROOMS = ('kalp', 'salon', 'giris', 'cikis')


def paint_base(lay, bank, tl):
    """Duvar + zemin (çatlak öbekleri, koyu yüzey halıları). Süslemeden önce; test_desen.py de bunu çağırır."""
    import numpy as np
    h, w = lay.t.shape
    nz = P.value_noise(w, h, SEED + 7, 6.0)

    def floor_fn(x, y):
        if nz[y, x] > 0.6 and P.hpick((0, 1, 1), x, y, 3):
            return 'wf', P.hpick(LIGHT_CRACK, x, y)
        return 'wf', (2, 8)

    P.paint_walls_34(lay, bank, tl, 'wf', floor=(2, 8), floor_fn=floor_fn)
    dist = P.wall_distance(lay, cap=5)
    taken = np.zeros((h, w), bool)
    for r in lay.rooms:
        if r.kind not in RUG_ROOMS:
            continue
        x0, y0, x1, y1 = r.x + 2, r.y + 2, r.x + r.w - 2, r.y + r.h - 2
        if x1 - x0 >= 3 and y1 - y0 >= 3 and (lay.t[y0:y1, x0:x1] == Z.F).all():
            P.nine_slice(tl, bank, 'Zemin ayrıntı', 'wf', DARK9, x0, y0, x1 - x0, y1 - y0)
            taken[y0 - 1:y1 + 1, x0 - 1:x1 + 1] = True
    cave = np.zeros((h, w), bool)
    for r in lay.rooms:
        if r.kind in ('magara', 'kristal'):
            cave[r.y:r.y + r.h, r.x:r.x + r.w] = True
    # koridorda ve mağarada küçük koyu yama delik gibi duruyordu: yalnız tapınak odalarında
    mask = (lay.t == Z.F) & (dist >= 2) & ~taken & (lay.room_id >= 0) & ~cave
    rng = random.Random(SEED + 9)
    for (x, y, rw, rh) in P.place_rugs(mask, P.value_noise(w, h, SEED + 4, 8.0), 0.58, rng,
                                       sizes=((3, 3), (4, 3), (3, 2), (5, 3), (4, 4), (2, 3)), gap=3):
        P.nine_slice(tl, bank, 'Zemin ayrıntı', 'wf', DARK9, x, y, rw, rh)


def main(write=False):
    lay = build_layout()
    bank = make_bank()
    tl = Z.TileLayers(W, H, ORDER)
    paint = lambda reg=None: P.paint_walls_34(lay, bank, tl, 'wf', floor=(2, 8), region=reg)  # noqa: E731
    dz = P.Decorator(lay, bank, tl, seed=SEED, paint=paint)
    dz.hatch_spec = ('d1o', (7, 1, 1, 4))
    paint_base(lay, bank, tl)
    decorate(dz)
    objs = dz.objects
    P.write_engel(lay, bank, tl, dz)
    os.makedirs(Z.OUT, exist_ok=True)
    Z.semantic_png(lay, objs, os.path.join(Z.OUT, 'boynuz_sema.png'))
    exits = [P.obj_center_cell(o) for o in objs if o['type'] == 'cikis']
    gates = [P.obj_cells(o) for o in objs if o['type'] == 'kapi']
    rep = Z.escape_report(lay, exits, gates)
    print('oda', len(lay.rooms), 'kenar', len(lay.edges), 'nesne', len(objs))
    print('kaçış:', {k: v for k, v in rep.items() if k != 'tikanma_hatasi'}, 'tıkanma hatası', len(rep['tikanma_hatasi']))
    for n in lay.notes + dz.notes:
        print(n)
    img = Z.render(bank, tl, W, H, skip=('Engel',))
    img.save(os.path.join(Z.OUT, 'boynuz_tam.png'))
    if write:
        bank.write_files()
        for name, src in RUNTIME_SHEETS:
            P.copy_runtime_sheets(src, ID, [name])
        Z.write_tmx(TMX, bank, tl, objs, W, H, props={'zindan': ID, 'ad': 'Boynuzlu Kapı'}, hidden=('Engel',))
        print('yazıldı', TMX)
    return lay, bank, tl, dz


def decorate(dz):
    lay = dz.lay
    rng = dz.rng
    for r in lay.rooms:
        if r.kind == 'giris':
            dz.exit_stairs(r, STAIRS_UP, 'Boynuz Merdiveni', main=True)
            dz.statue_pair(r, HORN_SKULL[0])
            dz.wall_fires(r, BRAZIER, step=7, light=P.CYAN)
            dz.spawn_point(r)
        elif r.kind == 'cikis':
            west = r.x < W // 2
            dz.exit_stairs(r, STAIRS_UP2, 'Kristal Yarığı' if west else 'Yeraltı Merdiveni')
            dz.wall_fires(r, BRAZIER, step=7, light=P.AMBER)
            dz.scatter(r, BLUE_SHARDS, 3, light=P.CYAN)
        elif r.kind == 'kalp':
            dz.altar(r, TOTEM, 'Boynuz Totemi', light=P.CYAN, light_r=170)
            dz.resource_nodes(r, 'isik_kristali', 3)
            dz.statue_pair(r, HORN_SKULL[1])
            dz.scatter(r, LAVA_ROCKS, 4, solid=True, light=(1.0, 0.55, 0.25))
            dz.scatter(r, BLUE_CRYSTAL, 4, solid=True, light=P.CYAN)
            dz.scatter(r, STALAG, 2, solid=True)
            dz.wall_fires(r, BRAZIER, step=6, light=P.AMBER)
            dz.dwellers(r, 'kalp')
        elif r.kind == 'magara':
            dz.resource_nodes(r, 'isik_kristali', 2)
            dz.blob_scatter(r, STALAG + PILLARS, 4, solid=True, vision=True)
            dz.blob_scatter(r, MUSHROOMS + GLOW_PLANTS, 5, solid=True, light=(0.85, 0.6, 1.0))
            dz.blob_scatter(r, FERNS + CORAL + JELLY, 5)
            dz.blob_scatter(r, MOSS, 3)
            # (Wisps.png ruh ışıkları KALDIRILDI: kareleri düzensiz dizili, YATI animasyonu atlıyor + kare karoları oluşturulamıyordu)
            dz.blob_scatter(r, [('pms', (0, 0, 4, 4))], 3, layer='Zemin süsü')
            dz.blob_hide(r, MUSH_HOUSE[1], 'Mantar Kovuğu')
            dz.dwellers(r, 'magara')
        elif r.kind == 'kristal':
            dz.resource_nodes(r, 'isik_kristali', 3)
            dz.blob_scatter(r, BLUE_CRYSTAL_BIG + DARK_CRYSTAL, 3, solid=True, vision=True, light=P.CYAN)
            dz.blob_scatter(r, BLUE_CRYSTAL + PM_CRYSTALS + PINK_CRYSTALS, 7, solid=True, light=P.VIOLET)
            dz.blob_scatter(r, BLUE_SHARDS, 6)
            dz.blob_scatter(r, [('pms', (0, 0, 4, 4))], 4, layer='Zemin süsü')
            dz.blob_hide(r, BLUE_CRYSTAL_BIG[1], 'Kristal Gölgesi')
            dz.dwellers(r, 'kristal')
        elif r.kind == 'salon':
            dz.pillars(r, ('wf', (15, 1, 1, 4)), spacing=4)
            dz.wall_fires(r, BRAZIER, step=5, light=P.AMBER)
            dz.scatter(r, CRATES + BARRELS, 3, solid=True)
            dz.scatter(r, VASES, 2, solid=True)
            dz.hide_alcove(r, spec=('wf', (1, 26, 2, 2)))
            dz.dwellers(r, 'salon')
        else:
            roll = rng.random()
            if roll < 0.3:
                dz.chest(r)
                dz.scatter(r, GOLD, 2)
            elif roll < 0.5:
                dz.scatter(r, SPIDER, 1, solid=True)
                dz.scatter(r, WEB, 1)
            elif roll < 0.75:
                dz.scatter(r, BLUE_CRYSTAL + PM_CRYSTALS, 3, solid=True, light=P.CYAN)
            else:
                dz.scatter(r, CRATES + BARRELS, 3, solid=True)
            dz.corner_candles(r, CANDLE, light=P.AMBER, count=1)
            if rng.random() < 0.6:
                dz.dwellers(r, 'oda')
        _furnish(dz, r)
    dz.corridor_glow(BLUE_SHARDS, every=14, light=P.CYAN)
    dz.corridor_face_decor(WIN_FACE[:1] + HANGING[:3] + WIN_FACE[1:2] + HANGING[3:6] + WIN_FACE[3:], every=10)
    dz.gates(max_count=7, styles=('demir', 'kristal'))
    dz.traps('diken', count=5)
    _extra_chests(dz)
    dz.hunter_route('boynuzlu_bekci')



def _furnish(dz, r):
    """Odaya özel süslemeden SONRA kalan yerlere: tapınak odalarında yüze pencere/kemer/kapı + duvar dibine fıçı/küp/sandık;
    mağara/kristal salonlarında yüzden sarkan kristal + sarkıt, duvar diplerinde dikit ve kristal; zemine çakıl."""
    cave = r.kind in ('magara', 'kristal')
    if cave:
        dz.wall_row(r, HANGING, step=3 + dz.rng.randrange(3), layer='Duvar süsü', face=True)
        dz.edge_props(r, STALAG + BLUE_CRYSTAL, 'n', step=3 + dz.rng.randrange(3), n_max=4)
        dz.edge_props(r, BLUE_CRYSTAL + MUSHROOMS[2:], 's', step=2 + dz.rng.randrange(3), n_max=4, light=P.VIOLET)
    else:
        if r.w >= 8:
            dz.wall_row(r, WIN_FACE, step=6 + dz.rng.randrange(4), layer='Duvar süsü', face=True)
        dz.edge_props(r, BARRELS + VASES + CRATES[:2], 'n', step=2 + dz.rng.randrange(3), n_max=4)
        dz.edge_props(r, BARRELS + VASES + GOLD, 's', step=3 + dz.rng.randrange(3), n_max=3)
    for side in ('w', 'e'):
        dz.edge_props(r, SMALL_STONE, side, step=4 + dz.rng.randrange(3), n_max=1, solid=False)


def _extra_chests(dz):
    """Kalp odasında ELİT sandık + belirli oda türlerinde birer sandık (risk -> ödül)."""
    for r in dz.lay.rooms:
        if r.kind == 'kalp':
            dz.chest(r, elite=True)
        elif r.kind in ('kristal', 'salon'):
            dz.chest(r)

if __name__ == '__main__':
    main('--write' in sys.argv)


def paint_test(lay):
    """test_desen.py: yalnız duvar + zemin boyaması (süsleme yok)."""
    bank = make_bank()
    h, w = lay.t.shape
    tl = Z.TileLayers(w, h, ORDER)
    paint_base(lay, bank, tl)
    return bank, tl
