"""2026-10-12 prototipleri: yeni evcil hayvan PERİ (kullanıcı: "oyunun pixel sanatıyla uyumlu 4 adet sihirli uçan peri prototipi
hazırlar mısın sonrasında anime edeceğiz onaylarsam"). Peri: can %100'ün altındayken 6 sn'de bir saldırı gücünün %10'u kadar can basar.
SADECE DURAN KARE - animasyon yok, OYUNA BAĞLI DEĞİL.
  A  Orman Perisi  - yaprak kanat, yeşil taç yaprağı elbise, kestane saç
  B  Işık Perisi   - kelebek kanat, sarı topuz, beyaz-altın elbise
  C  Ay Perisi     - yusufçuk kanadı (4 ince), gümüş uzun saç, lacivert uzun etek (bacak yok)
  D  Peri Işığı    - gövdesiz ışık küresi + 4 kanat (en minimal)
Dil: evcil hayvanlarla aynı (köpek/papağan): 48x48 kare, 1 sanat pikseli = 1 texel, koyu 1 px kontur; karakterler gibi ÖNDEN bakış.
Peri ~14 px boy (karakter gövdesi ~33 px, papağan ~15 px). Kanatlar yumuşak renkli konturla (yarı saydam his), gövde koyu konturla.
Sol yarı yazılır, sağ yarı AYNALANIR (orta sütun 12); asimetrik ayrıntılar (peri tozu) sonradan eklenir.
Çıktı: out/peri_{a,b,c,d}.png (48x48) + out/peri_pet_sheet.png
Kullanım (proje kökünden): python -I tools/proto_20261012/gen_peri_pet.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)

GRASS = (126, 176, 84)
INK = (46, 30, 44)          # gövde konturu (köpek konturuyla aynı aile)
SKIN = (248, 216, 186)
EYE = (44, 28, 36)
HALF = 13                   # sol yarı sütun sayısı (0..12), 12 = orta
W, H = 25, 18

FAIRIES = {
    'a': {
        'name': 'A  Orman Perisi',
        'pal': {
            'o': INK, 's': SKIN, 'e': EYE,
            'd': (112, 52, 30), 'h': (176, 88, 40), 'H': (222, 140, 66),
            'k': (40, 104, 48), 'g': (82, 160, 62), 'G': (150, 212, 92), 'L': (170, 226, 104),
            'x': (44, 112, 58), 'v': (104, 184, 88), 'w': (168, 226, 124), 'W': (224, 248, 180),
        },
        'rows': [
            ".............",
            "...........oL",
            ".........oooG",
            ".xx.....ohhHH",
            "xWwx....ohHhh",
            "xWWwx...ohsss",
            "xwWwwx..ohses",
            ".xwWwwx.odsss",
            "..xwwWvx.ooss",
            "...xxwvvx.oGg",
            "....xxvvxosGg",
            ".....xwvxoGgk",
            "......xwxokgo",
            ".......x..oso",
            "...........o.",
        ],
        'dust': [(3, 14, '+'), (21, 12, '.'), (19, 15, '.')],
        'dust_pal': [(255, 255, 224), (176, 248, 160)],
    },
    'b': {
        'name': 'B  Işık Perisi',
        'pal': {
            'o': INK, 's': SKIN, 'e': EYE,
            'd': (196, 134, 34), 'h': (246, 198, 72), 'H': (255, 238, 158),
            'k': (232, 170, 60), 'g': (246, 226, 176), 'G': (255, 252, 236),
            'x': (206, 128, 40), 'v': (255, 206, 96), 'w': (255, 232, 156), 'W': (255, 250, 222),
        },
        'rows': [
            "...........oo",
            "..xxx.....ohH",
            ".xWWwx...oohh",
            "xWWwwvx.ohHHh",
            "xWwwwvx.ohhhh",
            "xwwwvvx.ohhss",
            ".xwvvvx.ohses",
            "..xxvvvxodsss",
            "...xxxvvxooss",
            "...xwwxxx.oGG",
            "...xwwvvxosGg",
            "....xwvvxoGGg",
            ".....xxx.okkk",
            "..........oso",
            "...........o.",
        ],
        'dust': [(21, 14, '+'), (2, 13, '.'), (5, 15, '.')],
        'dust_pal': [(255, 255, 236), (255, 222, 110)],
    },
    'c': {
        'name': 'C  Ay Perisi',
        'pal': {
            'o': INK, 's': SKIN, 'S': (226, 171, 131), 'e': EYE, 'y': (255, 220, 96),
            'd': (150, 146, 196), 'h': (206, 204, 236), 'H': (240, 240, 255),
            'k': (44, 42, 120), 'g': (70, 72, 176), 'G': (104, 110, 220),
            'x': (40, 110, 170), 'v': (96, 190, 230), 'w': (160, 228, 250), 'W': (226, 250, 255),
        },
        'rows': [
            ".............",
            "..........ooo",
            "xxx......ohHH",
            "xWWxx...ohhhy",
            ".xwWWxx.ohsss",
            "..xxwWwxohses",
            "....xxwvohsss",
            "......xvohSss",
            ".....xxvodkGg",
            "....xwwvodsGg",
            "...xwwxx.ookg",
            "...xxx....okg",
            "..........okg",
            "...........ok",
            "............o",
        ],
        'dust': [(20, 14, '+'), (16, 15, '.'), (6, 15, '.')],
        'dust_pal': [(240, 252, 255), (150, 214, 255)],
    },
    'd': {
        'name': 'D  Peri Işığı',
        'pal': {
            'r': (196, 62, 134), 'p': (255, 132, 192), 'P': (255, 194, 226), 'C': (255, 248, 252),
            'x': (140, 104, 200), 'v': (198, 180, 240), 'w': (226, 214, 250), 'W': (250, 246, 255),
        },
        'rows': [
            "...xx........",
            "..xWWx.......",
            "..xWwwx......",
            "..xwWwwx.....",
            "...xwWwvx....",
            "....xwwvx..rr",
            ".....xxvvxrpP",
            ".......xxrpPC",
            ".........rpCC",
            "......xxxrpPC",
            ".....xwvx.rpP",
            ".....xwx...rr",
            "......x......",
        ],
        'dust': [(12, 13, '.'), (10, 15, '.'), (14, 16, '+'), (11, 17, '.')],
        'dust_pal': [(255, 250, 252), (255, 160, 208)],
    },
}
WING = set('xvwW')
WING_ALPHA = {'x': 255, 'v': 215, 'w': 215, 'W': 235}


def font(sz):
    for c in (r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\arial.ttf'):
        if os.path.exists(c):
            return ImageFont.truetype(c, sz)
    return ImageFont.load_default()


def build(spec):
    """Sol yarı satırlarını aynalayıp W x H RGBA kare üretir (+ peri tozu)."""
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    for y, left in enumerate(spec['rows']):
        assert len(left) == HALF, (spec['name'], y, left, len(left))
        row = left + left[-2::-1]
        for x, ch in enumerate(row):
            if ch == '.':
                continue
            c = spec['pal'][ch]
            px[x, y] = (c[0], c[1], c[2], WING_ALPHA[ch] if ch in WING else 255)
    bright, mid = spec['dust_pal']
    for x, y, kind in spec['dust']:
        if kind == '+':
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if 0 <= x + dx < W and 0 <= y + dy < H and px[x + dx, y + dy][3] == 0:
                    px[x + dx, y + dy] = mid + (255,)
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = bright + (255,)
    return im


def frame48(spr):
    """Evcil hayvan karesi: 48x48, peri ortada (papağan sayfasıyla aynı kare ölçüsü)."""
    f = Image.new('RGBA', (48, 48), (0, 0, 0, 0))
    f.alpha_composite(spr, ((48 - W) // 2, (48 - H) // 2))
    return f


def shadow(w):
    s = Image.new('RGBA', (w, 3), (0, 0, 0, 0))
    d = ImageDraw.Draw(s)
    d.rectangle((1, 0, w - 2, 2), fill=(20, 40, 20, 70))
    d.rectangle((0, 1, w - 1, 1), fill=(20, 40, 20, 70))
    return s


def main():
    sprites = {k: build(v) for k, v in FAIRIES.items()}
    for k, spr in sprites.items():
        frame48(spr).save(os.path.join(OUT, 'peri_%s.png' % k))

    # ---- sayfa: üstte x10 yakın çekim, altta oyun ölçeğinde (x4) karakterin yanında + mevcut evciller
    Z, G = 10, 4
    pad = 22
    cell_w = W * Z + pad * 2
    sheet_w = cell_w * 4
    top_h = 30 + H * Z + pad
    strip_w, strip_h = sheet_w // G, 58
    sheet = Image.new('RGBA', (sheet_w, top_h + 26 + strip_h * G + 8), (34, 30, 40, 255))
    d = ImageDraw.Draw(sheet)
    f_title, f_small = font(17), font(13)
    for i, (k, spr) in enumerate(sprites.items()):
        x0 = i * cell_w
        d.text((x0 + pad, 6), FAIRIES[k]['name'], font=f_title, fill=(236, 230, 214))
        panel = Image.new('RGBA', (W, H), (58, 66, 74, 255))
        panel.alpha_composite(spr)
        sheet.alpha_composite(panel.resize((W * Z, H * Z), Image.NEAREST), (x0 + pad, 30))
    d.text((pad, top_h + 4), 'Oyun ölçeği (x4): karakterin omuz hizasında süzülür  |  sağda mevcut evciller (köpek, papağan)',
           font=f_small, fill=(190, 186, 176))

    strip = Image.new('RGBA', (strip_w, strip_h), GRASS + (255,))
    chars = ['melek', 'elara', 'oakley', 'buyucu']
    slot = 56
    for i, (k, spr) in enumerate(sprites.items()):
        ch = Image.open(os.path.join(PROJECT, 'assets', 'characters', chars[i], 'sheets', 'idle.png')).convert('RGBA').crop((0, 0, 48, 48))
        cx = 2 + i * slot
        strip.alpha_composite(ch, (cx - 8, 8))
        fx, fy = cx + 26, 8
        strip.alpha_composite(shadow(9), (fx + 8, 47))
        strip.alpha_composite(spr, (fx, fy))
    dog = Image.open(os.path.join(PROJECT, 'assets', 'pets', 'dog', 'dog_sheet.png')).convert('RGBA').crop((0, 48, 48, 96))
    par = Image.open(os.path.join(PROJECT, 'assets', 'characters', 'korsan_parrot', 'parrot_sheet.png')).convert('RGBA').crop((0, 0, 48, 48))
    strip.alpha_composite(dog, (4 * slot - 10, 8))
    strip.alpha_composite(par, (4 * slot + 22, 6))
    sheet.alpha_composite(strip.resize((strip_w * G, strip_h * G), Image.NEAREST), (0, top_h + 26))
    path = os.path.join(OUT, 'peri_pet_sheet.png')
    sheet.convert('RGB').save(path)
    print(path, sheet.size)


if __name__ == '__main__':
    main()
