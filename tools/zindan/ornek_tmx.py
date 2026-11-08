# ÖRNEK TMX OKUYUCU (madde 447): zindan setlerinin KENDİ örnek haritalarını (Dungeon3 / Inside / Dungeon1 / Cave / Glowing_cave / Hapishane
# Interior) eksiksiz okur - gömülü + dış tileset (eksik dış tsx atlanır), sonlu + sonsuz (chunk) csv, grup katmanları, boş katmanlar, çevirme
# bayrakları, karo animasyonları. Tema haritaları bu örneklerin parçalarını (ressamın dizdiği hâliyle) kullanır.
# Kullanım: python tools/zindan/ornek_tmx.py <tmx> [çıktı.png]  -> katman listesi (+ çizim)
import os
import sys
import xml.etree.ElementTree as ET

from PIL import Image

FH, FV, FD = 0x80000000, 0x40000000, 0x20000000
GID_MASK = 0x1FFFFFFF


class Sheet:
    def __init__(self, firstgid, name, path, cols, count, anims):
        self.firstgid, self.name, self.path, self.cols, self.count, self.anims = firstgid, name, path, cols, count, anims
        self._img = None

    @property
    def img(self):
        if self._img is None:
            self._img = Image.open(self.path).convert('RGBA')
        return self._img

    def tile(self, lid):
        c, r = lid % self.cols, lid // self.cols
        return self.img.crop((c * 16, r * 16, c * 16 + 16, r * 16 + 16))


class Sample:
    """layers: [(ad, {(x, y): gid})] çizim sırasıyla (grup içindekiler grup adıyla 'Grup/Katman'); x, y örneğin kendi koordinatı."""

    def __init__(self, path):
        self.path = path
        self.dir = os.path.dirname(path)
        root = ET.parse(path).getroot()
        self.sheets = []
        for ts in root.findall('tileset'):
            fg = int(ts.get('firstgid'))
            node, base = ts, self.dir
            if ts.get('source'):
                src = os.path.normpath(os.path.join(self.dir, ts.get('source')))
                if not os.path.exists(src):
                    continue
                node, base = ET.parse(src).getroot(), os.path.dirname(src)
            img = node.find('image')
            if img is None:
                continue
            ip = os.path.normpath(os.path.join(base, img.get('source')))
            if not os.path.exists(ip):
                continue
            anims = {}
            for t in node.findall('tile'):
                an = t.find('animation')
                if an is not None:
                    anims[int(t.get('id'))] = [(int(f.get('tileid')), int(f.get('duration'))) for f in an.findall('frame')]
            self.sheets.append(Sheet(fg, node.get('name') or os.path.splitext(os.path.basename(ip))[0], ip,
                                     int(node.get('columns') or 1), int(node.get('tilecount') or 0), anims))
        self.sheets.sort(key=lambda s: s.firstgid)
        self.layers = []
        self._walk(root, '')
        xs = [x for _, c in self.layers for (x, y) in c]
        ys = [y for _, c in self.layers for (x, y) in c]
        self.x0, self.y0 = (min(xs), min(ys)) if xs else (0, 0)
        self.x1, self.y1 = (max(xs) + 1, max(ys) + 1) if xs else (0, 0)

    def _walk(self, node, prefix):
        for ch in node:
            if ch.tag == 'group' and ch.get('visible') != '0':
                self._walk(ch, prefix + ch.get('name', '') + '/')
            elif ch.tag == 'layer' and ch.get('visible') != '0':
                cells = {}
                data = ch.find('data')
                if data is None:
                    continue
                chunks = data.findall('chunk') or [data]
                for chk in chunks:
                    if not (chk.text or '').strip():
                        continue
                    cx, cy = int(chk.get('x', 0)), int(chk.get('y', 0))
                    cw = int(chk.get('width', ch.get('width')))
                    vals = [int(v) for v in chk.text.replace('\n', '').split(',') if v.strip()]
                    for i, v in enumerate(vals):
                        if v:
                            cells[(cx + i % cw, cy + i // cw)] = v
                self.layers.append((prefix + ch.get('name', ''), cells))

    def sheet_of(self, gid):
        g = gid & GID_MASK
        for s in reversed(self.sheets):
            if g >= s.firstgid:
                return s, g - s.firstgid
        return None, 0

    def tile_img(self, gid):
        s, lid = self.sheet_of(gid)
        if s is None or lid >= max(1, s.count) and s.count:
            return None
        t = s.tile(lid)
        if gid & FD:
            t = t.transpose(Image.TRANSPOSE)
        if gid & FH:
            t = t.transpose(Image.FLIP_LEFT_RIGHT)
        if gid & FV:
            t = t.transpose(Image.FLIP_TOP_BOTTOM)
        return t

    def render(self, x0=None, y0=None, x1=None, y1=None, skip=()):
        x0 = self.x0 if x0 is None else x0
        y0 = self.y0 if y0 is None else y0
        x1 = self.x1 if x1 is None else x1
        y1 = self.y1 if y1 is None else y1
        img = Image.new('RGBA', ((x1 - x0) * 16, (y1 - y0) * 16), (10, 9, 12, 255))
        for name, cells in self.layers:
            if any(k in name for k in skip):
                continue
            for (x, y), g in cells.items():
                if x0 <= x < x1 and y0 <= y < y1:
                    t = self.tile_img(g)
                    if t is not None:
                        img.alpha_composite(t, ((x - x0) * 16, (y - y0) * 16))
        return img


if __name__ == '__main__':
    smp = Sample(sys.argv[1])
    print('boyut %dx%d köken (%d,%d), sayfa %d' % (smp.x1 - smp.x0, smp.y1 - smp.y0, smp.x0, smp.y0, len(smp.sheets)))
    for name, cells in smp.layers:
        sheets = {}
        for g in cells.values():
            s, _ = smp.sheet_of(g)
            if s:
                sheets[s.name] = sheets.get(s.name, 0) + 1
        print('  %-28s %5d  %s' % (name, len(cells), ', '.join('%s:%d' % kv for kv in sorted(sheets.items(), key=lambda kv: -kv[1])[:4])))
    if len(sys.argv) > 2:
        smp.render().save(sys.argv[2])
