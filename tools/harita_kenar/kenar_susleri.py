# -*- coding: utf-8 -*-
"""OYUN ALANI KENARI DİKİŞİ (madde 475, 2026-11-08; kullanıcı ekran görüntüsü: "bu renk farkı ne?").

Dış çerçeve (madde 119, oyun alanı 0..255 hücrenin dışındaki 32/20 hücrelik orman + deniz halkası) eklenirken çerçevenin çimenine zemin süsü
konmamıştı: oyun alanının kenar şeridinde "Çimler" (ot öbeği / leke, spots_lianas + Yol parçaları) hücrelerin ~%16'sında, "Çiçekler 1" ~%0,6'sında
varken çerçevede hiç yoktu -> x = 256 / x = 0 / y = 0 / y = 256 boyunca düz kenarlı koyu bant (çimenin kendisi ve gölgelendiricisi iki yanda aynı).

Yöntem: çerçeve hücresine, oyun alanı içindeki KAYDIRILMIŞ hücrenin süsü kopyalanır (doğu x-32, batı x+32, kuzey y+20, güney y-20; köşede ikisi):
kenar şeridinin deseni dışarı taşınır, çok karolu öbekler bozulmaz (kaydırma, ayna değil). Yalnız iki ucu da DÜZ ÇİMEN (Zemin Çimen karo 134) olan
ve suyu olmayan hücrelere yazılır; hedefte zaten süs varsa dokunulmaz. Ayrıca (255,61)'deki kıyısız tek su karosu (Tiled'da kazara; mavi kare + görünmez
engel) silinir.

Kullanım: python -I tools/harita_kenar/kenar_susleri.py            -> kuru çalışma (sayılar)
          python -I tools/harita_kenar/kenar_susleri.py --apply <md5> -> Harita.tmx'e yazar (md5 kapısı + yedek)
Sonra: --import -> bake_harita.gd -> uid_geri_yaz.py -> mv -> katman sayımı -> gölge + minimap (bkz. hafıza map-rebake-procedure).
"""
import hashlib
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
TMX = os.path.join(PROJECT, 'harita', 'Harita.tmx')
YEDEK = os.path.join(PROJECT, 'harita', 'yedek', 'Harita_2026-11-08_oncesi_kenar-susleri.tmx.bak')
PLAY = 256
RING_X, RING_Y = 32, 20
DECOR = ['Çimler', 'Çiçekler 1']
GRASS_LAYER = 'Zemin Çimen'
WATER_LAYERS = ['Su', 'Su collisionsuz']
FULL_GRASS_LID = 134          # Ground_grass.tsx düz çimen karosu
STRAY_WATER = [(255, 61)]     # kıyısız tek su karosu
FLAGS = 0xF0000000


def md5(p):
    return hashlib.md5(open(p, 'rb').read()).hexdigest()


def layer_span(text, name):
    m = re.search(r'(<layer [^>]*name="%s"[^>]*>)(.*?)(</layer>)' % re.escape(name), text, re.S)
    if not m:
        raise SystemExit('katman yok: ' + name)
    return m


def read_cells(body):
    cells = {}
    for c in re.finditer(r'<chunk x="(-?\d+)" y="(-?\d+)" width="(\d+)" height="(\d+)">(.*?)</chunk>', body, re.S):
        cx, cy, w, h = map(int, c.groups()[:4])
        vals = [int(v) for v in c.group(5).replace('\r', '').replace('\n', '').split(',') if v.strip()]
        for i, v in enumerate(vals):
            if v:
                cells[(cx + i % w, cy + i // w)] = v
    return cells


def write_data(cells, nl, indent='   '):
    """<data encoding="csv"> ... </data> (16x16 parçalar, Tiled düzeni: satır satır, parça içi satır sonunda virgül)."""
    chunks = sorted({(x // 16 * 16, y // 16 * 16) for (x, y) in cells}, key=lambda c: (c[1], c[0]))
    out = [indent + '<data encoding="csv">']
    for (cx, cy) in chunks:
        out.append(indent + ' <chunk x="%d" y="%d" width="16" height="16">' % (cx, cy))
        rows = []
        for j in range(16):
            rows.append(','.join(str(cells.get((cx + i, cy + j), 0)) for i in range(16)))
        out.append(',\n'.join(rows).replace('\n', nl))
        out.append('</chunk>')  # Tiled kapanışı girintisiz yazar
    out.append(indent + '</data>')
    return nl.join(out)


def source_of(x, y):
    sx, sy = x, y
    if x >= PLAY:
        sx = x - RING_X
    elif x < 0:
        sx = x + RING_X
    if y >= PLAY:
        sy = y - RING_Y
    elif y < 0:
        sy = y + RING_Y
    return sx, sy


def main():
    raw = open(TMX, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in raw else '\n'
    text = raw
    firstgid = int(re.search(r'<tileset firstgid="(\d+)" source="Ground_grass.tsx"', text).group(1))
    full_grass = firstgid + FULL_GRASS_LID
    grass = read_cells(layer_span(text, GRASS_LAYER).group(2))
    water = set()
    for n in WATER_LAYERS:
        water |= set(read_cells(layer_span(text, n).group(2)))

    def plain(c):
        return (grass.get(c, 0) & ~FLAGS) == full_grass and c not in water

    new_layers = {}
    for name in DECOR:
        cells = read_cells(layer_span(text, name).group(2))
        added = 0
        for y in range(-RING_Y, PLAY + RING_Y):
            for x in range(-RING_X, PLAY + RING_X):
                if 0 <= x < PLAY and 0 <= y < PLAY:
                    continue
                if (x, y) in cells or not plain((x, y)):
                    continue
                s = source_of(x, y)
                if s in cells and plain(s):
                    cells[(x, y)] = cells[s]
                    added += 1
        new_layers[name] = (cells, added)
        print('%s: çerçeveye eklenen %d' % (name, added))
    su = read_cells(layer_span(text, 'Su').group(2))
    removed = [c for c in STRAY_WATER if c in su]
    for c in removed:
        del su[c]
    print('silinen tek su karosu:', removed)
    if len(sys.argv) >= 3 and sys.argv[1] == '--apply':
        if md5(TMX) != sys.argv[2]:
            raise SystemExit('DURDU: Harita.tmx md5 değişmiş (%s) - Tiled\'dan kaydedilmiş olabilir' % md5(TMX))
        for name, (cells, _a) in list(new_layers.items()) + [('Su', (su, 0))]:
            m = layer_span(text, name)
            body = m.group(2)
            d = re.search(r'([ \t]*)<data encoding="csv">.*?</data>', body, re.S)
            body = body[:d.start()] + write_data(cells, nl, d.group(1)) + body[d.end():]
            text = text[:m.start(2)] + body + text[m.end(2):]
        if not os.path.exists(YEDEK):
            shutil.copy2(TMX, YEDEK)
        tmp = TMX + '.tmp'
        open(tmp, 'w', encoding='utf-8', newline='').write(text)
        os.replace(tmp, TMX)
        print('YAZILDI | yeni md5', md5(TMX))
    else:
        print('kuru çalışma | şu anki md5', md5(TMX))


if __name__ == '__main__':
    main()
