"""2026-10-13 prototipleri - YENİ KİRPİ (kullanıcı: "daha yeni şirin pixel art bir kirpi ... animasyonlardan önce 4 prototip;
eskisinden referans alma ama oyunun pixel sanatıyla uyumlu olsun"). OYUNA BAĞLI DEĞİL, duran kare; her tasarım diken KAPALI + AÇIK.
    A  Tombul Kirpi   - yandan, kahverengi diken + krem uç, krem yüz, pembe yanak
    B  Pofuduk Top    - önden, kızıl-turuncu diken halesi, iri gözler
    C  Elmalı Kirpi   - yandan, koyu diken + beyaz uç, uzun burun, sırtında elma
    D  Bebek Kirpi    - ayakta/oturan, açık renk diken kapüşonu, krem göbek
Kontur otomatik (dolgunun 4 komşusu, köpek/peri ile aynı mürekkep rengi). Açık diken = diken bölgesinin dış kenarına 2 px'lik uçlar.
Çıktı: out/kirpi_{a,b,c,d}_{kapali,acik}.png + out/kirpi_v2_sheet.png
Kullanım (proje kökünden): python -I tools/proto_20261013/gen_kirpi_pet.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HERE, 'out')

GRASS = (126, 176, 84)
INK = (46, 30, 44)
EYE = (44, 28, 36)
QUILL = set('dmlt')
M = 3                       # kenar payı (açık dikenler + kontur sığsın)

FACE = {'f': (250, 226, 190), 's': (226, 188, 148), 'c': (244, 152, 146), 'n': (58, 36, 46), 'e': EYE, 'w': (255, 255, 255),
        'E': (236, 158, 148), 'p': (214, 166, 130), 'o': INK}

HOGS = {
    'a': {
        'name': 'A  Tombul Kirpi',
        'pal': dict(FACE, d=(96, 62, 50), m=(140, 96, 68), l=(178, 130, 90), t=(240, 220, 178)),
        'hub': (6, 7), 'arc': (28, 205, 9),
        'rows': [
            ".....qqqqqq.........",
            "...qqqqqqqqqq.......",
            "..qqqqqqqqqqqq......",
            ".qqqqqqqqqqqqq......",
            ".qqqqqqqqqqqqEfff...",
            "qqqqqqqqqqqqqffeff..",
            "qqqqqqqqqqqqfffefffn",
            "qqqqqqqqqqqsfccffff.",
            ".qqqqqqqqqssfffff...",
            "..qqsssssssssff.....",
            "...pp......pp.......",
        ],
    },
    'b': {
        'name': 'B  Pofuduk Top',
        'pal': dict(FACE, d=(118, 64, 42), m=(170, 98, 56), l=(212, 140, 80), t=(255, 232, 184)),
        'hub': (8, 7), 'arc': (-25, 205, 12),
        'rows': [
            "......qqqqq......",
            "...qqqqqqqqqqq...",
            "..qqqqqqqqqqqqq..",
            ".qqqqqqqqqqqqqqq.",
            ".qqqqEqqqqqEqqqq.",
            "qqqqqfffffffqqqqq",
            "qqqqfffffffffqqqq",
            "qqqqfwefffwefqqqq",
            "qqqqceefnfeecqqqq",
            ".qqqffffsffffqqq.",
            ".qqqqfffffffqqqq.",
            "..qqqsssssssqqq..",
            "....pp.....pp....",
        ],
    },
    'c': {
        'name': 'C  Elmalı Kirpi',
        'pal': dict(FACE, d=(62, 50, 62), m=(98, 84, 92), l=(140, 126, 128), t=(232, 226, 214),
                    f=(236, 200, 154), s=(204, 160, 118), a=(214, 52, 56), A=(250, 130, 118), R=(150, 30, 48), G=(96, 170, 70), k=(110, 72, 48)),
        'hub': (7, 10), 'arc': (30, 205, 10),
        'rows': [
            ".......kG............",
            "......aAaa...........",
            ".....aAaaaR..........",
            "....qqaaaRRq.........",
            "..qqqqqaRRqqq........",
            ".qqqqqqqqqqqqqq......",
            "qqqqqqqqqqqqqqq......",
            "qqqqqqqqqqqqqqEfff...",
            "qqqqqqqqqqqqqqffeff..",
            "qqqqqqqqqqqqqsffefffn",
            ".qqqqqqqqqqqssfccff..",
            "..qqsssssssssssff....",
            "...pp.......pp.......",
        ],
    },
    'd': {
        'name': 'D  Bebek Kirpi',
        'pal': dict(FACE, d=(176, 150, 132), m=(224, 208, 186), l=(244, 234, 216), t=(132, 98, 84),
                    f=(255, 228, 204), s=(238, 196, 172), b=(255, 244, 232), E=(244, 160, 160), n=(226, 112, 124)),
        'hub': (7, 7), 'arc': (-42, 222, 12), 'tip_step': 3,
        'rows': [
            ".....qqqqq.....",
            "...qqqqqqqqq...",
            "..qqqqqqqqqqq..",
            ".qqqqqqqqqqqqq.",
            ".qqEfffffffEqq.",
            "qqqfffffffffqqq",
            "qqqffefffeffqqq",
            "qqqffefnfeffqqq",
            ".qqqcffsffcqqq.",
            "..qqqsssssqqq..",
            ".qqqfbbbbbfqqq.",
            ".qqffbbbbbffqq.",
            ".qqqsbbbbbsqqq.",
            "..qqqbbbbbqqq..",
            "...pp.....pp...",
        ],
    },
}


def font(sz):
    for c in (r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\arial.ttf'):
        if os.path.exists(c):
            return ImageFont.truetype(c, sz)
    return ImageFont.load_default()


def grid(spec):
    w = max(len(r) for r in spec['rows'])
    g = {}
    for y, row in enumerate(spec['rows']):
        assert len(row) == w, (spec['name'], y, row, len(row), w)
        for x, ch in enumerate(row):
            if ch != '.':
                g[(x + M, y + M)] = ch
    return g, w + M * 2, len(spec['rows']) + M * 2


def texture(g, step=4):
    """'q' diken bölgesini boyar: üst kenar açık, alt kenar / yüz komşusu koyu, arada seyrek şaşırtmalı krem uçlar."""
    out = dict(g)
    for (x, y), ch in g.items():
        if ch != 'q':
            continue
        up, down = g.get((x, y - 1)), g.get((x, y + 1))
        side = [g.get((x - 1, y)), g.get((x + 1, y))]
        tone = 'm'
        if up is None:
            tone = 'l'
        elif down != 'q' or any(n is not None and n != 'q' for n in side):
            tone = 'd'
        elif y % 2 == 0 and (x + (y // 2 % 2) * (step // 2)) % step == 0:
            tone = 't'
        elif g.get((x, y - 2)) is None:
            tone = 'l'
        out[(x, y)] = tone
    for (x, y), ch in list(out.items()):          # her ucun sol altına koyu gölge: nokta değil, diken çizgisi okunsun
        if ch == 't' and out.get((x - 1, y + 1)) == 'm':
            out[(x - 1, y + 1)] = 'd'
    return out


def spikes(g, hub, arc):
    """Diken AÇIK: merkezden eşit açılarla ışın; ışının değdiği en dış diken pikselinden 2 px'lik uç (açık ton + krem)."""
    out = dict(g)
    a0, a1, n = arc
    hx, hy = hub[0] + M, hub[1] + M
    for i in range(n):
        a = math.radians(a0 + (a1 - a0) * i / (n - 1))
        dx, dy = math.cos(a), -math.sin(a)
        base = None
        r = 30.0
        while r > 0.0:
            p = (round(hx + dx * r), round(hy + dy * r))
            if p in g:
                base = p if g[p] in QUILL else None
                break
            r -= 0.25
        if base is None:
            continue
        p1 = (round(base[0] + dx * 1.3), round(base[1] + dy * 1.3))
        p2 = (round(base[0] + dx * 2.5), round(base[1] + dy * 2.5))
        if p1 in g or p2 in g:
            continue
        out[p1] = 'l'
        out[p2] = 't'
    return out


def render(g, w, h, pal):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()
    for (x, y), ch in g.items():
        px[x, y] = pal[ch] + (255,)
    for y in range(h):
        for x in range(w):
            if (x, y) in g:
                continue
            if any((x + dx, y + dy) in g for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = INK + (255,)
    return im


def build(spec):
    g, w, h = grid(spec)
    g = texture(g, spec.get('tip_step', 4))
    return render(g, w, h, spec['pal']), render(spikes(g, spec['hub'], spec['arc']), w, h, spec['pal'])


def shadow(w):
    s = Image.new('RGBA', (w, 3), (0, 0, 0, 0))
    d = ImageDraw.Draw(s)
    d.rectangle((1, 0, w - 2, 2), fill=(20, 40, 20, 70))
    d.rectangle((0, 1, w - 1, 1), fill=(20, 40, 20, 70))
    return s


def char_frame(name):
    return Image.open(os.path.join(PROJECT, 'assets', 'characters', name, 'sheets', 'idle.png')).convert('RGBA').crop((0, 0, 48, 48))


def main():
    os.makedirs(OUT, exist_ok=True)
    sprites = {k: build(spec) for k, spec in HOGS.items()}
    for k, (shut, opened) in sprites.items():
        shut.crop(shut.getbbox()).save(os.path.join(OUT, 'kirpi_%s_kapali.png' % k))
        opened.crop(opened.getbbox()).save(os.path.join(OUT, 'kirpi_%s_acik.png' % k))
        print(k, shut.getbbox(), opened.getbbox())

    Z, G = 9, 4
    pw, ph = 28, 22
    pad = 8
    cell_w = pw * Z + pad * 2
    sheet_w = cell_w * 4
    top = 32
    row_h = ph * Z + pad
    strip_w, strip_h = sheet_w // G, 56
    strip_y = top + row_h * 2 + 22
    sheet = Image.new('RGBA', (sheet_w, strip_y + strip_h * G + 8), (34, 30, 40, 255))
    d = ImageDraw.Draw(sheet)
    for i, (k, pair) in enumerate(sprites.items()):
        x0 = i * cell_w
        d.text((x0 + pad, 5), HOGS[k]['name'], font=font(18), fill=(236, 230, 214))
        for j, spr in enumerate(pair):
            panel = Image.new('RGBA', (pw, ph), (58, 66, 74, 255))
            panel.alpha_composite(spr, ((pw - spr.width) // 2, ph - spr.height))
            y0 = top + j * row_h
            sheet.alpha_composite(panel.resize((pw * Z, ph * Z), Image.NEAREST), (x0 + pad, y0))
            d.text((x0 + pad + 6, y0 + 3), ('Diken kapalı', 'Diken açık')[j], font=font(13), fill=(176, 184, 190))
    d.text((pad, strip_y - 20), 'Oyun ölçeği (x4): karakter + diken kapalı + diken açık', font=font(13), fill=(190, 186, 176))
    strip = Image.new('RGBA', (strip_w, strip_h), GRASS + (255,))
    chars = ['melek', 'elara', 'oakley', 'buyucu']
    slot = strip_w // 4
    ground = 49
    for i, pair in enumerate(sprites.values()):
        cx = i * slot
        strip.alpha_composite(char_frame(chars[i]), (cx - 12, 5))
        x = cx + 22
        for spr in pair:
            box = spr.getbbox()
            body = spr.crop(box)
            strip.alpha_composite(shadow(body.width - 4), (x + 2, ground - 2))
            strip.alpha_composite(body, (x, ground - body.height))
            x += body.width + 1
    sheet.alpha_composite(strip.resize((strip_w * G, strip_h * G), Image.NEAREST), (0, strip_y))
    path = os.path.join(OUT, 'kirpi_v2_sheet.png')
    sheet.convert('RGB').save(path)
    print(path, sheet.size)


if __name__ == '__main__':
    main()
