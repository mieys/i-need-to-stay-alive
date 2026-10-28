# DERİN ORMAN atlası: Yarı Ölü + Parlayan Mağara setlerinden seçilen parçalar (derin_orman_core.SPRITES) TEK bir 16 px ızgaralı sayfaya
# (harita/derin_orman.png) + Tiled tileset'i (harita/Derin orman.tsx) + parça -> karo dikdörtgeni tablosu (tools/derin_orman/atlas.json).
# Her parça kendi karo dikdörtgeninde, ALTI dikdörtgenin alt kenarına oturur, yatayda ortalı; parçalar arasında en az 1 boş karo (derinlik/sallanma
# "atlasta komşu karolar = bir nesne" kuralı parçaları karıştırmasın). Kullanıcı aynı tileset'le Tiled'da elle de boyayabilir.
# Animasyonlu parçalar (derin_orman_core.ANIMS, madde 361): kareler atlasın altında, her parça kendi sütun bloğunda ALT ALTA (aralık = boy + 1 karo);
# tileset'te parçanın 1. karesindeki her karoya Tiled <animation> yazılır (YATI bunu Godot animation_separation'a çevirir). Haritada sadece 1. kare kullanılır.
# Kullanım: python tools/derin_orman/gen_atlas.py
import colorsys
import json
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import derin_orman_core as C  # noqa: E402

COLS = 32
## Parçanın kenarına değen düz zemin pikselleri saydam yapılır (zemine gömülü parça, bölge zeminine otursun): ad -> [(renk), ...]
CLEAR_BG = {'et_kuyusu': [(205, 150, 115), (198, 137, 106), (190, 135, 104)]}
CLEAR_TOL = 22


def clear_bg(img, colors):
    w, h = img.size
    px = img.load()

    def near(c):
        return c[3] > 0 and any(sum(abs(c[i] - k[i]) for i in range(3)) <= CLEAR_TOL for k in colors)
    st = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    seen = set()
    while st:
        x, y = st.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        if px[x, y][3] == 0 or near(px[x, y]):
            px[x, y] = (0, 0, 0, 0)
            st.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    return img


def recolor(img, mode):
    """'mavi': sarı/turuncu ışık pikselleri (doygun + parlak) Doğu bölgesinin camgöbeği-mavisine döner, koyu pikseller aynı kalır."""
    if mode is None:
        return img
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if 0.04 <= hh <= 0.2 and ss > 0.4 and vv > 0.5:
                nh = 0.54 - (hh - 0.04) * 0.25
                rr, gg, bb = colorsys.hsv_to_rgb(nh, min(1.0, ss * 0.95), vv)
                px[x, y] = (int(rr * 255), int(gg * 255), int(bb * 255), a)
    return img


def drop_intruders(img):
    """Kırpma kutusuna giren komşu parçaları siler: kutu kenarına değen VE toplam pikselin %20'sinden küçük 8-komşu parçalar
    (ör. dev iskeletin kutusuna giren hayvan kafatası kesiği). Asıl parça kutuyu tanımladığı için kenara değse de büyüktür."""
    w, h = img.size
    px = img.load()
    seen = set()
    comps = []
    total = 0
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0 or (x, y) in seen:
                continue
            st = [(x, y)]
            seen.add((x, y))
            cells = []
            edge = False
            while st:
                a, b = st.pop()
                cells.append((a, b))
                if a in (0, w - 1) or b in (0, h - 1):
                    edge = True
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        u, v = a + dx, b + dy
                        if 0 <= u < w and 0 <= v < h and (u, v) not in seen and px[u, v][3] > 0:
                            seen.add((u, v))
                            st.append((u, v))
            comps.append((cells, edge))
            total += len(cells)
    for cells, edge in comps:
        if edge and len(cells) < total * 0.2:
            for a, b in cells:
                px[a, b] = (0, 0, 0, 0)
    return img


def main():
    sheets = {}
    items = []
    for name, spec in C.SPRITES.items():
        path, x, y, w, h = spec[:5]
        if path not in sheets:
            sheets[path] = C.open_sheet(path)
        img = drop_intruders(sheets[path].crop((x, y, x + w, y + h)))
        if len(spec) > 5 and spec[5] == 'ayna':
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        if name in CLEAR_BG:
            img = clear_bg(img, CLEAR_BG[name])
        bb = img.getbbox()
        img = img.crop(bb)
        items.append((name, img))
    anims = []
    for name, (path, frames, w, h, ms, col) in C.ANIMS.items():
        if path not in sheets:
            sheets[path] = C.open_sheet(path)
        imgs = [recolor(drop_intruders(sheets[path].crop((fx, fy, fx + w, fy + h))), col) for fx, fy in frames]
        bb = [w, h, 0, 0]
        for im in imgs:
            b = im.getbbox()
            bb = [min(bb[0], b[0]), min(bb[1], b[1]), max(bb[2], b[2]), max(bb[3], b[3])]
        anims.append((name, [im.crop(tuple(bb)) for im in imgs], ms))
    ## raf yerleşimi: büyükten küçüğe, satır yüksekliği = raftaki en yüksek parça
    items.sort(key=lambda e: (-math.ceil(e[1].height / 16), -e[1].width))
    table = {}
    tx = ty = 0
    shelf_h = 0
    placed = []
    for name, img in items:
        tw, th = math.ceil(img.width / 16), math.ceil(img.height / 16)
        if tx + tw > COLS:
            tx = 0
            ty += shelf_h + 1
            shelf_h = 0
        placed.append((name, img, tx, ty, tw, th))
        table[name] = [tx, ty, tw, th]
        tx += tw + 1
        shelf_h = max(shelf_h, th)
    rows = ty + shelf_h
    ## animasyonlu parçalar: statiklerin altında yan yana sütun blokları
    anim_tab = {}
    ay = rows + 1
    ax = 0
    a_rows = 0
    for name, imgs, ms in anims:
        tw, th = math.ceil(imgs[0].width / 16), math.ceil(imgs[0].height / 16)
        assert ax + tw <= COLS, 'animasyon blokları atlasa sığmadı'
        stride = th + 1
        for k, img in enumerate(imgs):
            placed.append((name + '#%d' % k, img, ax, ay + k * stride, tw, th))
        table[name] = [ax, ay, tw, th]
        anim_tab[name] = {'frames': len(imgs), 'stride': stride, 'ms': ms}
        a_rows = max(a_rows, len(imgs) * stride)
        ax += tw + 1
    if anims:
        rows = ay + a_rows    ## parçalar raf içinde alta hizalı: rafın alt satırına göre değil kendi dikdörtgeninin altına -> dikdörtgen = (tx, ty .. ty+th)
    atlas = Image.new('RGBA', (COLS * 16, rows * 16), (0, 0, 0, 0))
    for name, img, tx, ty, tw, th in placed:
        ox = tx * 16 + (tw * 16 - img.width) // 2
        oy = ty * 16 + th * 16 - img.height
        atlas.alpha_composite(img, (ox, oy))
    atlas.save(C.ATLAS_PNG)
    count = COLS * rows
    tiles = []
    for name, info in anim_tab.items():
        tx, ty, tw, th = table[name]
        for j in range(th):
            for i in range(tw):
                tid = (ty + j) * COLS + tx + i
                fr = ''.join('   <frame tileid="%d" duration="%d"/>\n' % (tid + k * info['stride'] * COLS, info['ms']) for k in range(info['frames']))
                tiles.append((tid, ' <tile id="%d">\n  <animation>\n%s  </animation>\n </tile>\n' % (tid, fr)))
    tiles.sort()
    tsx = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<tileset version="1.10" tiledversion="1.12.2" name="Derin orman" tilewidth="16" tileheight="16" tilecount="%d" columns="%d">\n'
           ' <image source="derin_orman.png" width="%d" height="%d"/>\n'
           '%s</tileset>\n') % (count, COLS, COLS * 16, rows * 16, ''.join(t for _, t in tiles))
    open(C.ATLAS_TSX, 'w', encoding='utf-8', newline='\n').write(tsx)
    json.dump({'cols': COLS, 'rows': rows, 'tilecount': count, 'sprites': table, 'anims': anim_tab}, open(C.ATLAS_JSON, 'w', encoding='utf-8'), indent=1)
    print('atlas', atlas.size, 'karo', count, 'parça', len(table))


if __name__ == '__main__':
    main()
