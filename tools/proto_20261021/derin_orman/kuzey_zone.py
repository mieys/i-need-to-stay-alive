# DERİN ORMAN prototipi (kuzey "Solgun Orman" / "Kadim Kara Orman", oyuna bağlı DEĞİL): kuzey bölgesinin hücrelerini Harita.tmx'ten çıkarır.
# Yöntem: geçilmez hücreler = "Orman parçaları" (uçurum duvarı) + "Su" (köprü altı açık). Duvara en az R hücre uzak çekirdekler 4-komşu
# bağlı parçalara ayrılır (dar geçitler kopar), sonra parçalar serbest hücrelere geri büyütülür -> doğal "havzalar".
# Kuzey = (150, 15)'i içeren havza, x >= 80 ve y <= 50 (batı/kuzeybatı ayrı bölge, aşağısı ev bölgesi).
# Çıktı: out/kuzey_zone.txt ("x,y" satırları, kuzey_capture.gd okur) + out/kuzey_mask.png (hücre başına 1 px, 0..255; kuzey_sheet.py okur).
# Kullanım: python tools/proto_20261021/derin_orman/kuzey_zone.py
import os
import xml.etree.ElementTree as ET
from collections import deque

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(HERE, 'out')
N = 256
R = 4
SEED = (150, 15)


def layer_cells(root, name):
    out = set()
    for lay in root.iter('layer'):
        if lay.get('name') != name:
            continue
        for ch in lay.find('data').findall('chunk'):
            cx, cy, w = int(ch.get('x')), int(ch.get('y')), int(ch.get('width'))
            vals = [int(v) for v in ch.text.replace('\n', '').split(',') if v.strip()]
            for i, v in enumerate(vals):
                if v:
                    out.add((cx + i % w, cy + i // w))
    return out


def main():
    root = ET.parse(os.path.join(PROJ, 'harita', 'Harita.tmx')).getroot()
    wall = (layer_cells(root, 'Orman parçaları') | layer_cells(root, 'Su')) - layer_cells(root, 'Köprü alt')
    free = [[(x, y) not in wall for x in range(N)] for y in range(N)]
    dist = [[999] * N for _ in range(N)]
    q = deque()
    for y in range(N):
        for x in range(N):
            if not free[y][x] or x in (0, N - 1) or y in (0, N - 1):
                dist[y][x] = 0
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                nx, ny = x + dx, y + dy
                if 0 <= nx < N and 0 <= ny < N and dist[ny][nx] > dist[y][x] + 1:
                    dist[ny][nx] = dist[y][x] + 1
                    q.append((nx, ny))
    comp = [[-1] * N for _ in range(N)]
    cid = 0
    for y in range(N):
        for x in range(N):
            if dist[y][x] >= R and comp[y][x] < 0:
                comp[y][x] = cid
                dq = deque([(x, y)])
                while dq:
                    a, b = dq.popleft()
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        na, nb = a + dx, b + dy
                        if 0 <= na < N and 0 <= nb < N and comp[nb][na] < 0 and dist[nb][na] >= R:
                            comp[nb][na] = cid
                            dq.append((na, nb))
                cid += 1
    dq = deque((x, y) for y in range(N) for x in range(N) if comp[y][x] >= 0)
    while dq:
        x, y = dq.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < N and 0 <= ny < N and free[ny][nx] and comp[ny][nx] < 0:
                comp[ny][nx] = comp[y][x]
                dq.append((nx, ny))
    target = comp[SEED[1]][SEED[0]]
    cells = [(x, y) for y in range(N) for x in range(N) if comp[y][x] == target and x >= 80 and y <= 50]
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, 'kuzey_zone.txt'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(f'{x},{y}' for x, y in cells))
    mask = Image.new('L', (N, N), 0)
    for c in cells:
        mask.putpixel(c, 255)
    mask.save(os.path.join(OUT, 'kuzey_mask.png'))
    print('kuzey hücre', len(cells))


if __name__ == '__main__':
    main()
