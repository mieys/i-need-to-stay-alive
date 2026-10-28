# KEMİK MAHZENİ (Kuzey zindanı, madde 373): "Zindan Tileseti (Roguelike)" kriptası + "Zindan Eşyaları" örümcek ağları.
# Ruh alevli mumlar/meşaleler, lahit salonları (açık lahitler = saklanma), kemik ocakları, sütunlu salon, Ruh Kuyusu (Kemik Sunağı).
# Kaynak: RUH KÖZÜ (ruh kandillerinden toplanır, kandil söner). Kaçış: 3 çıkış (giriş merdiveni + batı/doğu merdiveni), parmaklık + diken kapıları.
# Çalıştır: python tools/zindan/gen_kemik_mahzeni.py [--write]   (--write olmadan yalnız önizleme: tools/zindan/out/kemik_*.png)
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zindan_core as Z  # noqa: E402
import zindan_paint as P  # noqa: E402

ID = 'kemik_mahzeni'
RL = os.path.join(Z.ART, 'Zindan Tileseti (Roguelike)', 'Tiled_files')
ZE = os.path.join(Z.ART, 'Zindan Esyalari Assetleri', 'Tiled_files')
SAMPLE = os.path.join(RL, 'Dungeon3.tmx')
W, H = 132, 100
SEED = 7101
TMX = os.path.join(Z.ZROOT, 'kemik_mahzeni.tmx')

ORDER = ['Zemin', 'Zemin ayrıntı', 'Zemin desen', 'Zemin süsü', 'Duvar', 'Duvar süsü', 'Eşya alt', 'Eşya', 'Eşya üst', 'Engel']
# Çalışma zamanında çizilen (açılan/kapanan) parçaların sayfaları - TMX'te kullanılmaz, scripts/dungeon kopyadan okur.
RUNTIME_SHEETS = ['doors.png', 'chest_lever.png', 'Spikes.png', 'torches.png', 'column_trap.png']

# ---- karolar (sayfa, (x, y, w, h) karo dikdörtgeni)
STAIRS_UP = ('st', (1, 4, 3, 4))          # duvara oyulmuş yukarı merdiven (çıkış)
STAIRS_UP2 = ('st', (5, 4, 3, 4))
STAIRS_UP3 = ('st', (9, 4, 3, 4))
STATUE_FIRE = ('sta', (0, 0, 5, 5))       # Kemik Sunağı (ruh alevli heykel, animasyonlu)
STATUES = [('obj', (1, 1, 2, 3)), ('obj', (4, 1, 2, 3)), ('obj', (6, 1, 2, 3)), ('obj', (9, 1, 2, 3))]
TOMBS_V = [('cof', (0, 0, 2, 4)), ('cof', (6, 0, 2, 4))]                       # büyük dikey (kapalı oymalı / iskeletli açık)
TOMBS_V_SMALL = [('cof', (8, 4, 2, 3)), ('cof', (12, 4, 2, 3)), ('cof', (14, 4, 2, 3)), ('cof', (16, 4, 2, 3)),
                 ('cof', (20, 4, 2, 3)), ('cof', (22, 4, 2, 3))]
TOMBS_H = [('cof', (9, 0, 3, 2)), ('cof', (15, 0, 3, 2)), ('cof', (18, 0, 3, 2)), ('cof', (16, 2, 3, 2)), ('cof', (19, 2, 3, 2))]
TOMB_BIG_H = [('cof', (0, 4, 4, 3)), ('cof', (5, 4, 3, 3))]
OPEN_EMPTY_V = [('cof', (3, 0, 2, 4)), ('cof', (10, 4, 2, 3)), ('cof', (18, 4, 2, 3))]   # saklanma lahitleri
WOOD_V = [('cof', (5, 7, 3, 3)), ('cof', (8, 7, 2, 3)), ('cof', (11, 7, 2, 3)), ('cof', (14, 7, 2, 3))]
WOOD_H = [('cof', (17, 8, 3, 2)), ('cof', (20, 8, 3, 2)), ('cof', (23, 8, 3, 2)), ('cof', (26, 8, 3, 2))]
BONES = [('obj', (7, 11, 3, 2)), ('obj', (8, 13, 3, 2)), ('obj', (3, 14, 3, 2)), ('obj', (8, 15, 3, 2)), ('obj', (1, 14, 2, 2)),
         ('obj', (6, 13, 2, 2)), ('obj', (6, 15, 2, 2)), ('obj', (3, 16, 3, 1)), ('obj', (3, 18, 3, 1)), ('obj', (1, 16, 2, 1))]
BONE_PILES = [('obj', (6, 17, 2, 2)), ('obj', (8, 17, 3, 2))]
SKULLS = [('obj', (1, 21, 2, 2)), ('obj', (3, 21, 1, 2)), ('obj', (6, 21, 2, 2)), ('obj', (8, 21, 1, 2)), ('obj', (4, 22, 1, 1)),
          ('obj', (9, 22, 1, 1))]
URNS = [('obj', (1, 19, 2, 2)), ('obj', (3, 19, 1, 2)), ('obj', (6, 19, 2, 2)), ('obj', (8, 19, 1, 2))]
HANGING = [('obj', (7, 9, 2, 2)), ('obj', (9, 9, 2, 2)), ('obj', (1, 11, 2, 3)), ('obj', (3, 11, 2, 3))]
GOLD = [('obj', (8, 4, 2, 2)), ('obj', (1, 7, 2, 2)), ('obj', (6, 7, 2, 2)), ('obj', (9, 7, 2, 2))]
BENCH = [('obj', (1, 9, 4, 2)), ('obj', (5, 9, 2, 2))]
CANDLES_FLOOR = [('cdl', (0, 1, 2, 2)), ('cdl', (2, 1, 2, 2)), ('cdl', (4, 1, 2, 2)), ('cdl', (0, 7, 2, 2)), ('cdl', (2, 7, 2, 2)),
                 ('cdl', (4, 7, 2, 2))]
TORCH_WALL = [('tor', (4, 0, 2, 3)), ('tor', (9, 0, 2, 3))]
RELIEF = ('rel', (0, 0, 2, 2))
# Arches_columns: duvar yüzüne oyulmuş kemerler (karanlık geçit / parmaklıklı pencere / ahşap kapı; 2x3, örnek haritanın Walls2'si)
# + yüzün önünde duran sütunlar (1x3). Eskiden uzun yüzler düz tuğla şeridiydi.
ARCH_FACE = [('arc', (1, 1, 2, 3)), ('arc', (3, 1, 2, 3)), ('arc', (5, 1, 2, 3)), ('arc', (7, 1, 2, 3)), ('arc', (9, 1, 2, 3)),
             ('arc', (11, 1, 2, 3))]
COLUMNS = [('arc', (c, 10, 1, 3)) for c in range(1, 8)]
NARROW = [('obj', (3, 19, 1, 2)), ('obj', (8, 19, 1, 2)), ('obj', (3, 21, 1, 2)), ('obj', (8, 21, 1, 2))]


def make_bank():
    bank = Z.TilesetBank(ID)
    bank.add('wf', os.path.join(RL, 'walls_floor.png'))
    bank.add('pl', os.path.join(RL, 'plates.png'), name='plakalar.png')
    bank.add('cof', os.path.join(RL, 'coffins.png'))
    bank.add('obj', os.path.join(RL, 'other_objects.png'))
    bank.add('st', os.path.join(RL, 'stairs.png'))
    bank.add('cdl', os.path.join(RL, 'candles.png'), anims=Z.sample_anims(SAMPLE, 'candles'))
    bank.add('tor', os.path.join(RL, 'torches.png'), anims=Z.sample_anims(SAMPLE, 'torches'))
    bank.add('sta', os.path.join(RL, 'Statue_fire.png'), anims=Z.sample_anims(SAMPLE, 'Statue_fire'))
    bank.add('rel', os.path.join(RL, 'scull_bas-relief.png'), anims=Z.sample_anims(SAMPLE, 'scull_bas-relief'))
    bank.add('arc', os.path.join(RL, 'Arches_columns.png'))
    bank.add('web', os.path.join(ZE, 'web.png'), name='web_eslik.png')
    bank.add('eng', 'engel', name='engel.png', img=Z.make_marker_sheet())
    return bank


def build_layout(seed=SEED):
    lay = Z.Layout(W, H, seed)
    giris = lay.add_room(58, 7, 16, 10, 'giris')
    lay.add_room(52, 76, 28, 16, 'kalp')
    lay.add_room(5, 38, 11, 9, 'cikis')     # batı çıkışı
    lay.add_room(116, 50, 11, 9, 'cikis')   # doğu çıkışı
    lay.scatter_rooms([
        (4, (17, 22), (10, 12), 'lahit'),
        (2, (12, 15), (8, 10), 'kemik'),
        (2, (16, 20), (10, 12), 'sutun'),
        (12, (8, 11), (6, 8), 'oda'),
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


# Zemin: kum (2, 8) + odalarda gri taş LEVHA (paketin Floor1_dark 9 parçası, örnek haritadaki gri oda zeminleri) + koridorda seyrek
# levha yamaları. Çatlak ayrıntıları renge göre: satır 23-24 kum tonunda (kum zemine), 21-22 gri (levhaya) - karışınca kumda koyu "+" duruyordu.
SLAB9 = ((1, 22), (2, 22), (3, 22), (1, 23), (2, 23), (3, 23), (1, 24), (2, 24), (3, 24))
DETAIL_SAND = [(10, 23), (11, 23), (13, 23), (10, 24), (11, 24), (12, 24), (13, 24), (14, 24)]
DETAIL_SLAB = [(10, 21), (11, 21), (13, 21), (10, 22), (11, 22), (12, 22), (13, 22), (14, 22)]
SLAB_ROOMS = ('giris', 'kalp', 'cikis', 'lahit', 'sutun')
# plates.png plaka ızgarası: plakalar karo KÖŞELERİNE ortalı (yarım karo kayık) - 9 parça (8..12, 0..5) bloğundan
PLATE9 = ((8, 0), [(9, 0), (10, 0), (11, 0)], (12, 0), [(8, 1), (8, 2), (8, 3), (8, 4)], [(9, 1), (10, 1), (11, 1), (9, 2), (10, 2), (11, 2), (9, 3), (10, 3), (11, 3)],
          [(12, 1), (12, 2), (12, 3), (12, 4)], (8, 5), [(9, 5), (10, 5)], (12, 5))


def paint_base(lay, bank, tl):
    """Duvar + zemin (+ levhalar, zemin ayrıntısı). Süslemeden önce; test_desen.py de bunu çağırır."""
    import numpy as np
    P.paint_walls_34(lay, bank, tl, 'wf', floor=(2, 8))
    h, w = lay.t.shape
    slab = np.zeros((h, w), bool)
    for r in lay.rooms:
        if r.kind not in SLAB_ROOMS and not (r.kind == 'oda' and (r.x * 7 + r.y * 3) % 3 != 0):
            continue
        x0, y0, x1, y1 = r.x + 1, r.y + 1, r.x + r.w - 1, r.y + r.h - 1
        if x1 - x0 < 2 or y1 - y0 < 2 or not (lay.t[y0:y1, x0:x1] == Z.F).all():  # su / duvar varsa levha yok
            continue
        P.nine_slice(tl, bank, 'Zemin ayrıntı', 'wf', SLAB9, x0, y0, x1 - x0, y1 - y0)
        slab[y0:y1, x0:x1] = True
        if x1 - x0 >= 5 and y1 - y0 >= 5:
            P.nine_slice(tl, bank, 'Zemin desen', 'pl', PLATE9, x0 + 1, y0 + 1, x1 - x0 - 2, y1 - y0 - 2)
    dist = P.wall_distance(lay, cap=4)
    sand = (lay.t == Z.F) & ~slab
    P.floor_details(lay, bank, tl, 'wf', DETAIL_SAND, density=0.09, seed=SEED, layer='Zemin süsü', mask=sand & (dist <= 2))
    inner = slab.copy()
    inner[1:, :] &= slab[:-1, :]
    inner[:-1, :] &= slab[1:, :]
    inner[:, 1:] &= slab[:, :-1]
    inner[:, :-1] &= slab[:, 1:]
    P.floor_details(lay, bank, tl, 'wf', DETAIL_SLAB, density=0.06, seed=SEED + 1, layer='Zemin süsü', mask=inner)


def main(write=False):
    lay = build_layout()
    bank = make_bank()
    tl = Z.TileLayers(W, H, ORDER)
    paint = lambda reg=None: P.paint_walls_34(lay, bank, tl, 'wf', floor=(2, 8), region=reg)  # noqa: E731
    dz = P.Decorator(lay, bank, tl, seed=SEED, paint=paint)
    dz.hatch_spec = ('st', (13, 15, 3, 2))
    paint_base(lay, bank, tl)
    decorate(dz)
    objs = dz.objects
    P.write_engel(lay, bank, tl, dz)
    os.makedirs(Z.OUT, exist_ok=True)
    Z.semantic_png(lay, objs, os.path.join(Z.OUT, 'kemik_sema.png'))
    exits = [P.obj_center_cell(o) for o in objs if o['type'] == 'cikis']
    gates = [P.obj_cells(o) for o in objs if o['type'] == 'kapi']
    rep = Z.escape_report(lay, exits, gates)
    print('oda', len(lay.rooms), 'kenar', len(lay.edges), 'nesne', len(objs))
    print('kaçış:', {k: v for k, v in rep.items() if k != 'tikanma_hatasi'}, 'tıkanma hatası', len(rep['tikanma_hatasi']))
    for n in lay.notes + dz.notes:
        print(n)
    img = Z.render(bank, tl, W, H, skip=('Engel',))
    img.save(os.path.join(Z.OUT, 'kemik_tam.png'))
    crop = Z.render(bank, tl, W, H, 40, 0, 100, 40, skip=('Engel',))
    crop.resize((crop.width * 2, crop.height * 2), Z.Image.NEAREST).save(os.path.join(Z.OUT, 'kemik_onizleme.png'))
    if write:
        bank.write_files()
        P.copy_runtime_sheets(RL, ID, RUNTIME_SHEETS)
        Z.write_tmx(TMX, bank, tl, objs, W, H, props={'zindan': ID, 'ad': 'Kemik Mahzeni'}, hidden=('Engel',))
        print('yazıldı', TMX)
    return lay, bank, tl, dz


# ------------------------------------------------------------------------------------------------ süsleme
def decorate(dz):
    lay = dz.lay
    rng = dz.rng
    for r in lay.rooms:
        if r.kind == 'giris':
            dz.exit_stairs(r, STAIRS_UP, 'Mahzen Merdiveni', main=True)
            dz.statue_pair(r, STATUES[0])
            dz.wall_torches(r, TORCH_WALL, step=6, light=P.CYAN)
            dz.corner_candles(r, CANDLES_FLOOR, light=P.CYAN)
            dz.spawn_point(r)
        elif r.kind == 'cikis':
            west = r.x < W // 2
            dz.exit_stairs(r, STAIRS_UP2 if west else STAIRS_UP3, 'Batı Merdiveni' if west else 'Doğu Merdiveni')
            dz.wall_torches(r, TORCH_WALL, step=7, light=P.CYAN)
            dz.scatter(r, BONES, 2)
            dz.scatter(r, SKULLS, 2)
        elif r.kind == 'kalp':
            dz.altar(r, STATUE_FIRE, 'Kemik Sunağı', light=P.CYAN, light_r=150)
            dz.resource_nodes(r, 'ruh_kandili', 2)
            dz.wall_torches(r, TORCH_WALL, step=5, light=P.CYAN)
            dz.tomb_rows(r, TOMBS_V_SMALL, OPEN_EMPTY_V, margin_top=7, hide_every=0)
            dz.corner_candles(r, CANDLES_FLOOR, light=P.CYAN)
            dz.dwellers(r, 'kalp')
        elif r.kind == 'lahit':
            dz.resource_nodes(r, 'ruh_kandili', 1)
            dz.wall_torches(r, TORCH_WALL, step=7, light=P.CYAN)
            dz.wall_reliefs(r, RELIEF, step=9)
            dz.tomb_rows(r, TOMBS_V + TOMBS_V_SMALL, OPEN_EMPTY_V, margin_top=2, hide_every=3)
            if not dz.hide[r.y:r.y + r.h, r.x:r.x + r.w].any():  # sıralar orta haça çarpınca açık lahit kalmıyordu: en az bir saklanma
                dz.hide_spot_object(r, OPEN_EMPTY_V[0], 'Açık Lahit', layer='Eşya alt', rows=OPEN_EMPTY_V[0][1][3] - 1, inset=0)
            dz.corner_webs(r)
            dz.dwellers(r, 'lahit')
        elif r.kind == 'kemik':
            dz.resource_nodes(r, 'ruh_kandili', 2)
            dz.wall_hangings(r, HANGING, step=4)
            dz.scatter(r, BONE_PILES, 3, solid=True)
            dz.scatter(r, BONES, 6)
            dz.scatter(r, SKULLS, 5)
            dz.scatter(r, URNS, 2, solid=True)
            dz.corner_candles(r, CANDLES_FLOOR, light=P.CYAN)
            dz.dwellers(r, 'kemik')
        elif r.kind == 'sutun':
            dz.pillars(r, ('wf', (15, 1, 1, 4)), spacing=4)
            dz.wall_torches(r, TORCH_WALL, step=6, light=P.CYAN)
            dz.scatter(r, WOOD_H, 2, solid=True)
            dz.hide_alcove(r)
            dz.dwellers(r, 'sutun')
        else:
            roll = rng.random()
            if roll < 0.3:
                dz.chest(r)
                dz.scatter(r, GOLD, 2)
            elif roll < 0.55:
                dz.scatter(r, WOOD_V + WOOD_H, 2, solid=True)
                dz.scatter(r, BONES, 3)
            elif roll < 0.75:
                dz.statue_pair(r, STATUES[rng.randrange(len(STATUES))])
                dz.scatter(r, URNS, 2, solid=True)
            else:
                dz.scatter(r, BENCH, 1, solid=True)
                dz.scatter(r, SKULLS, 3)
            dz.corner_candles(r, CANDLES_FLOOR, light=P.CYAN, count=1)
            dz.corner_webs(r)
            if rng.random() < 0.6:
                dz.dwellers(r, 'oda')
        _furnish(dz, r)
    _extra_chests(dz)
    # koridorlar: kemikler, meşaleler, kapılar, tuzaklar, avcı rotası
    dz.corridor_dressing(BONES + SKULLS, density=0.012)
    dz.corridor_torches(TORCH_WALL, every=14, light=P.CYAN)
    dz.corridor_face_decor(ARCH_FACE[:3] + [RELIEF] + ARCH_FACE[3:], every=12)
    dz.gates(max_count=7, styles=('parmaklik', 'diken'))
    dz.traps('diken', count=6)
    dz.hunter_route('kemik_bekcisi')



def _furnish(dz, r):
    """Her odaya: kuzey yüzüne kemer/pencere/kapı oyması, yüz önüne sütunlar, güney duvar dibine küp/kemik yığını/tabut,
    yan duvar diplerine dar küp ve kafatası; zemine kemik kırıntısı. Odaya özel süslemeden SONRA (yer kalan yerlere)."""
    if r.w >= 8:
        dz.wall_row(r, ARCH_FACE, step=7 + dz.rng.randrange(4), layer='Duvar süsü', face=True)
    if r.kind != 'kalp':
        dz.edge_props(r, COLUMNS, 'n', step=4 + dz.rng.randrange(3))
    dz.edge_props(r, URNS + BONE_PILES + (WOOD_H if r.kind in ('oda', 'sutun') else []), 's', step=2 + dz.rng.randrange(3), n_max=4)
    for side in ('w', 'e'):
        dz.edge_props(r, NARROW, side, step=2 + dz.rng.randrange(3), n_max=3)
    dz.scatter(r, BONES + SKULLS, 2 + dz.rng.randrange(3))


def _extra_chests(dz):
    """Kalp odasında ELİT sandık + belirli oda türlerinde birer sandık (risk -> ödül)."""
    for r in dz.lay.rooms:
        if r.kind == 'kalp':
            dz.chest(r, elite=True)
        elif r.kind in ('kemik', 'sutun'):
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
