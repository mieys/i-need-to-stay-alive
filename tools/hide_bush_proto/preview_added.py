"""Eklenen (köşe dışı) çalılıkların önce/sonra önizlemesi: python -I preview_added.py <ilk_yeni_indeks> -> out/yeni_calilik_once_sonra.png (canlı Harita.tmx = sonra, yedek = önce)"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import place_brush as PB
from place_brush import load, render, OUT, PROJECT, W, H
from PIL import Image
before = os.path.join(PROJECT, 'harita', 'yedek', 'Harita_oncesi_agac-kenari-calilik.tmx.bak')
first = int(sys.argv[1])
meta = json.load(open(os.path.join(OUT, 'saklanma_alanlari.json'), encoding='utf-8'))
new = meta['patches'][first:]
ra, ta = load(before); rb, tb = load(PB.LIVE)
tiles = []
for p in new:
    x0, y0, w, h = p['canvas']
    reg = (max(0, x0 - 7), max(0, y0 - 6), min(W, x0 + w + 7), min(H, y0 + h + 6))
    a = render(ra, ta, region=reg).convert('RGB'); b = render(rb, tb, region=reg).convert('RGB')
    both = Image.new('RGB', (a.width * 2 + 6, a.height), (20, 20, 20)); both.paste(a, (0, 0)); both.paste(b, (a.width + 6, 0))
    tiles.append(both.resize((both.width * 2, both.height * 2), Image.NEAREST))
colw = max(t.width for t in tiles)
sheet = Image.new('RGB', (colw * 2 + 10, sum(max(tiles[i].height, tiles[i + 1].height if i + 1 < len(tiles) else 0) + 8 for i in range(0, len(tiles), 2)) + 8), (20, 20, 20))
y = 0
for i in range(0, len(tiles), 2):
    sheet.paste(tiles[i], (0, y))
    if i + 1 < len(tiles): sheet.paste(tiles[i + 1], (colw + 10, y))
    y += max(tiles[i].height, tiles[i + 1].height if i + 1 < len(tiles) else 0) + 8
sheet.save(os.path.join(OUT, 'yeni_calilik_once_sonra.png')); print(sheet.size)
