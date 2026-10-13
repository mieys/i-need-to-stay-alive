"""2026-10-12 prototipleri, 2. tur (kullanıcı: "D yi başka bir pet için seçiyorum adı: kelebek ruhu ... can basan peri için ise
daha farklı prototipler üret"). OYUNA BAĞLI DEĞİL.
  CAN BASAN PERİ - ilk turdaki önden bakan bebek tipinden FARKLI dört fikir:
    E  Işıktan Peri      - yüzü olmayan, ışıktan beden (nane-beyaz), büyük şeffaf kanatlar
    F  Asalı Peri        - YANDAN, öne eğik uçuş; ucunda yeşil şifa yıldızı olan asa
    G  Ters Lale Perisi  - kocaman ters lale şapkalı maskot, minik kanat
    H  Karahindiba Perisi - karahindiba tohumuna tutunup süzülür
  KELEBEK RUHU (ilk turun D'si; %10 saldırı hızı + ilk silahın vurduğu düşmana minik pembe lazer, saldırı gücünün %20'si):
    3 kanat pozu (yukarı / açık / aşağı) -> 4 karelik çırpma + lazer için iki seçenek (ışın / atış).
Çıktı: out/peri_{e,f,g,h}.png (48x48), out/peri_pet_v2_sheet.png, out/kelebek_ruhu_sheet.png (4 x 48x48), out/kelebek_ruhu.gif
Kullanım (proje kökünden): python -I tools/proto_20261012/gen_peri_pet_v2.py [kontrol_png_yolu]
"""
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from gen_peri_pet import EYE, GRASS, INK, OUT, PROJECT, SKIN, WING, WING_ALPHA, font, shadow  # noqa: E402

GREENS = {'k': (40, 104, 48), 'g': (82, 160, 62), 'G': (150, 212, 92)}

FAIRIES = {
    'e': {
        'name': 'E  Işıktan Peri',
        'pal': {
            'r': (44, 150, 118), 'p': (150, 236, 190), 'P': (214, 252, 228), 'C': (250, 255, 250),
            'x': (84, 160, 186), 'v': (168, 222, 236), 'w': (212, 242, 248), 'W': (246, 254, 255),
        },
        'half': [
            "..xxxx.......",
            ".xWWWwx......",
            "xWWwwwvx...rr",
            "xWwwwwvvx.rPC",
            "xwwwwvvvx.rCC",
            ".xwwvvvvx.rPC",
            "..xxvvvvvx.rC",
            "....xxxvvxrPC",
            "......xxx.rPC",
            ".....xwwxrPCC",
            "....xwwvrPPCC",
            "...xwwvxrpPpC",
            "...xwvx..rrPr",
            "...xxx.....r.",
        ],
        'dust': [(12, 15, '+'), (8, 14, '.'), (17, 15, '.')],
        'dust_pal': [(246, 255, 248), (150, 240, 180)],
    },
    'f': {
        'name': 'F  Asalı Peri (yandan)',
        'pal': {
            'o': INK, 's': SKIN, 'e': EYE,
            'd': (196, 134, 34), 'h': (246, 198, 72), 'H': (255, 238, 158),
            'k': (44, 96, 170), 'g': (86, 150, 220), 'G': (150, 204, 250),
            'x': (70, 150, 150), 'v': (150, 220, 214), 'w': (200, 244, 236), 'W': (240, 255, 250),
            'n': (150, 96, 50), 'T': (96, 206, 96), 'Y': (240, 255, 230),
        },
        'full': [
            "",
            "...xxx......oooo",
            "..xWWwx....ohHHho",
            "..xWwwwx..ohHhhhso",
            "..xwWwwvx.ohhhssso..T",
            "...xwwWvvxodhsseso.TYT",
            "....xxwwvxoddssso...T",
            "......xxvvxoGgoo...n",
            ".......xxxoGGggo..n",
            "...xxxxxxoGGggsssso",
            "..xwwvvoGGggkoooo",
            "...xxxoggkkko",
            "....ossooooo",
            "..ossoo",
            "...oo",
        ],
        'dust': [(17, 12, '.'), (20, 9, '.'), (8, 14, '.')],
        'dust_pal': [(240, 255, 230), (150, 232, 150)],
    },
    'g': {
        'name': 'G  Ters Lale Perisi',
        'pal': dict({
            'o': INK, 's': SKIN, 'e': EYE, 'b': (240, 150, 140),
            'D': (150, 34, 32), 'R': (226, 70, 44), 'T': (252, 140, 74),
            'x': (204, 172, 100), 'v': (246, 230, 172), 'w': (253, 247, 216), 'W': (255, 255, 246),
        }, **GREENS),
        'half': [
            "............G",
            "...........oG",
            "..........ooR",
            ".........oRTT",
            "........oRRTT",
            ".......oRRDRT",
            ".......oRDDDD",
            "..xx...oDsess",
            ".xWwx...osbss",
            ".xwWwx...osss",
            "..xwwvvxx.ogG",
            "...xxxvvxosgG",
            "......xxxokgg",
            "..........oso",
            "...........o.",
        ],
        'dust': [(5, 14, '.'), (19, 15, '+')],
        'dust_pal': [(255, 255, 236), (255, 190, 120)],
    },
    'h': {
        'name': 'H  Karahindiba Perisi',
        'pal': {
            'o': INK, 's': SKIN, 'e': EYE,
            'd': (96, 58, 40), 'h': (150, 92, 56), 'H': (200, 138, 86),
            'k': (206, 140, 24), 'g': (246, 196, 48), 'G': (255, 234, 128),
            'f': (200, 220, 214), 'F': (255, 255, 255), 'n': (150, 124, 80),
            'x': (110, 160, 120), 'v': (188, 230, 180), 'w': (224, 246, 210), 'W': (246, 255, 240),
        },
        'full': [
            "........FFFFF",
            "......FF.f.f.FF",
            ".....F..f.f.f..F",
            ".....F...fff...F",
            "..........n",
            "..........n.ooooo",
            "..........nohHHhho",
            "..........nohsssho",
            ".........osodesedo..xx",
            "......xx.osodsssdoxWwx",
            ".....xwwxosooooooxwwvx",
            "......xvvxosGGggsoxvvx",
            ".......xxx.oGGggkoxxx",
            "...........ogkgko",
            "............ososo",
            ".............o.o",
        ],
        'dust': [(3, 5, '.'), (18, 3, '.'), (20, 15, '.')],
        'dust_pal': [(255, 255, 255), (220, 236, 228)],
    },
}

# ---------------------------------------------------------------- Kelebek Ruhu (ilk turun D'si) - 3 kanat pozu
ORB_PAL = {
    'r': (196, 62, 134), 'p': (255, 132, 192), 'P': (255, 194, 226), 'C': (255, 248, 252),
    'x': (140, 104, 200), 'v': (198, 180, 240), 'w': (226, 214, 250), 'W': (250, 246, 255),
}
ORB_POSES = {
    'U': [
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
    'M': [
        ".............",
        ".............",
        ".xxxx........",
        "xWWwwxx......",
        "xWwWwwwxx....",
        ".xwwWwwvvx.rr",
        "..xxwwwvvxrpP",
        "....xxxxxrpPC",
        ".........rpCC",
        ".....xxxxrpPC",
        "....xwwvx.rpP",
        "....xxxx...rr",
        ".............",
    ],
    'D': [
        ".............",
        ".............",
        ".............",
        ".............",
        ".............",
        "...........rr",
        "....xxxxx.rpP",
        "..xxwwwvvrpPC",
        ".xWwWwwvxrpCC",
        ".xWwwwxxxrpPC",
        "..xxxxwvx.rpP",
        "......xxx..rr",
        ".............",
    ],
}
FLAP = ['U', 'M', 'D', 'M']
LASER = [(255, 248, 252), (255, 132, 192), (196, 62, 134)]   # çekirdek, pembe, koyu pembe

DUMMY = [
    "...ooooo...",
    "..oTTTtto..",
    "..oTTttto..",
    "..oTtttto..",
    "...ooooo...",
    "ooooobooooo",
    "oTTTTbtttto",
    "ooooobooooo",
    "...oTbto...",
    "...oTbto...",
    "...oTbto...",
    "...ooboo...",
    "....obo....",
    "....obo....",
    "....obo....",
    "....ooo....",
]
DUMMY_PAL = {'o': INK, 'T': (214, 170, 110), 't': (170, 124, 74), 'b': (110, 74, 44)}


def paint(rows, pal, mirror):
    """Satır listesinden RGBA kare. mirror=True: 13 sütunluk sol yarı aynalanır (orta sütun 12)."""
    if mirror:
        for y, r in enumerate(rows):
            assert len(r) == 13, (y, r, len(r))
        rows = [r + r[-2::-1] for r in rows]
    w = max(len(r) for r in rows)
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == '.':
                continue
            c = pal[ch]
            px[x, y] = (c[0], c[1], c[2], WING_ALPHA[ch] if ch in WING else 255)
    return im


def build(spec):
    body = paint(spec['half'], spec['pal'], True) if 'half' in spec else paint(spec['full'], spec['pal'], False)
    im = Image.new('RGBA', (body.width, body.height + 3), (0, 0, 0, 0))
    im.alpha_composite(body)
    px = im.load()
    bright, mid = spec['dust_pal']
    for x, y, kind in spec['dust']:
        if not (0 <= x < im.width and 0 <= y < im.height):
            continue
        if kind == '+':
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if 0 <= x + dx < im.width and 0 <= y + dy < im.height and px[x + dx, y + dy][3] == 0:
                    px[x + dx, y + dy] = mid + (255,)
        px[x, y] = bright + (255,)
    return im.crop(im.getbbox())


def frame48(spr):
    f = Image.new('RGBA', (48, 48), (0, 0, 0, 0))
    f.alpha_composite(spr, ((48 - spr.width) // 2, (48 - spr.height) // 2))
    return f


def char_frame(name):
    return Image.open(os.path.join(PROJECT, 'assets', 'characters', name, 'sheets', 'idle.png')).convert('RGBA').crop((0, 0, 48, 48))


def fairy_sheet(sprites, orb):
    Z, G = 10, 4
    pw, ph = 26, 20
    pad = 17
    cell_w = pw * Z + pad * 2
    sheet_w = cell_w * 4
    top_h = 30 + ph * Z + pad
    strip_w, strip_h = sheet_w // G, 58
    sheet = Image.new('RGBA', (sheet_w, top_h + 26 + strip_h * G + 8), (34, 30, 40, 255))
    d = ImageDraw.Draw(sheet)
    for i, (k, spr) in enumerate(sprites.items()):
        x0 = i * cell_w
        d.text((x0 + pad, 6), FAIRIES[k]['name'], font=font(17), fill=(236, 230, 214))
        panel = Image.new('RGBA', (pw, ph), (58, 66, 74, 255))
        panel.alpha_composite(spr, ((pw - spr.width) // 2, (ph - spr.height) // 2))
        sheet.alpha_composite(panel.resize((pw * Z, ph * Z), Image.NEAREST), (x0 + pad, 30))
    d.text((pad, top_h + 4), 'Oyun ölçeği (x4)  |  sağda karşılaştırma: Kelebek Ruhu, köpek, papağan', font=font(13), fill=(190, 186, 176))
    strip = Image.new('RGBA', (strip_w, strip_h), GRASS + (255,))
    chars = ['melek', 'elara', 'oakley', 'buyucu']
    slot = 54
    for i, spr in enumerate(sprites.values()):
        cx = 2 + i * slot
        strip.alpha_composite(char_frame(chars[i]), (cx - 8, 8))
        fx = cx + 27
        strip.alpha_composite(shadow(9), (fx + spr.width // 2 - 4, 47))
        strip.alpha_composite(spr, (fx, 6))
    strip.alpha_composite(orb, (4 * slot - 2, 10))
    dog = Image.open(os.path.join(PROJECT, 'assets', 'pets', 'dog', 'dog_sheet.png')).convert('RGBA').crop((0, 48, 48, 96))
    par = Image.open(os.path.join(PROJECT, 'assets', 'characters', 'korsan_parrot', 'parrot_sheet.png')).convert('RGBA').crop((0, 0, 48, 48))
    strip.alpha_composite(dog, (4 * slot + 14, 8))
    strip.alpha_composite(par, (4 * slot + 44, 6))
    sheet.alpha_composite(strip.resize((strip_w * G, strip_h * G), Image.NEAREST), (0, top_h + 26))
    path = os.path.join(OUT, 'peri_pet_v2_sheet.png')
    sheet.convert('RGB').save(path)
    print(path, sheet.size)


def line_points(x0, y0, x1, y1):
    n = int(max(abs(x1 - x0), abs(y1 - y0)))
    return [(int(round(x0 + (x1 - x0) * i / n)), int(round(y0 + (y1 - y0) * i / n))) for i in range(n + 1)]


def spark(px, w, h, x, y, big):
    arms = ((1, 0), (-1, 0), (0, 1), (0, -1))
    for dx, dy in arms:
        for r in range(1, 3 if big else 2):
            xx, yy = x + dx * r, y + dy * r
            if 0 <= xx < w and 0 <= yy < h:
                px[xx, yy] = (LASER[1] if r == 1 else LASER[2]) + (255,)
    if 0 <= x < w and 0 <= y < h:
        px[x, y] = LASER[0] + (255,)


def orb_scene(poses, f, mode):
    """Tek sahne karesi (sanat pikseli, büyütülmemiş). mode: 'isin' (anlık ışın) | 'atis' (hızlı giden kısa mermi)."""
    w, h = 132, 56
    im = Image.new('RGBA', (w, h), GRASS + (255,))
    im.alpha_composite(char_frame('buyucu'), (2, 6))
    dummy = paint(DUMMY, DUMMY_PAL, False)
    im.alpha_composite(shadow(13), (104, 45))
    im.alpha_composite(dummy, (105, 31))
    bob = int(round(math.sin(f / 12.0 * math.tau)))
    ox, oy = 34, 6 + bob
    im.alpha_composite(shadow(9), (ox + 8, 47))
    im.alpha_composite(poses[FLAP[f % 4]], (ox, oy))
    px = im.load()
    for i in range(3):                                   # dökülen peri tozu
        age = (f + i * 4) % 12
        if age < 9:
            px[ox + 12 + (i - 1) * 2, oy + 13 + age // 2] = (LASER[0] if age < 4 else LASER[1]) + (255,)
    src = (ox + 12, oy + 8)
    dst = (110, 38)
    t = f % 12 - 4                                       # silah isabeti kare 3'te, lazer 4..7
    if t == -1:
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2)):
            px[dst[0] + dx, dst[1] + dy] = (255, 255, 255, 255)
    pts = line_points(src[0], src[1], dst[0], dst[1])
    if mode == 'isin':
        if t == 0:
            for x, y in pts:
                px[x, y] = LASER[0] + (255,)
            spark(px, w, h, dst[0], dst[1], True)
        elif t == 1:
            for x, y in pts:
                px[x, y] = LASER[1] + (255,)
            spark(px, w, h, dst[0], dst[1], False)
        elif t == 2:
            for i, (x, y) in enumerate(pts):
                if i % 3 == 0:
                    px[x, y] = LASER[2] + (255,)
    else:
        if 0 <= t <= 2:
            head = int(len(pts) * (t + 1) / 3.0) - 1
            for i in range(9):
                j = head - i
                if j < 3:
                    break
                x, y = pts[j]
                px[x, y] = (LASER[0] if i < 3 else LASER[1] if i < 6 else LASER[2]) + (255,)
            if t == 2:
                spark(px, w, h, dst[0], dst[1], True)
        elif t == 3:
            spark(px, w, h, dst[0], dst[1], False)
    return im


def kelebek(check_path):
    poses = {k: paint(rows, ORB_PAL, True) for k, rows in ORB_POSES.items()}
    sheet = Image.new('RGBA', (48 * 4, 48), (0, 0, 0, 0))
    for i, k in enumerate(FLAP):
        sheet.alpha_composite(poses[k], (i * 48 + 11, 17))
    sheet.save(os.path.join(OUT, 'kelebek_ruhu_sheet.png'))

    G = 4
    frames = []
    for f in range(24):
        a, b = orb_scene(poses, f, 'isin'), orb_scene(poses, f, 'atis')
        fr = Image.new('RGBA', (a.width * G, (a.height * 2) * G + 44), (34, 30, 40, 255))
        d = ImageDraw.Draw(fr)
        d.text((8, 2), '1  Işın: anında ince pembe çizgi, 3 karede söner', font=font(14), fill=(236, 230, 214))
        fr.alpha_composite(a.resize((a.width * G, a.height * G), Image.NEAREST), (0, 22))
        d.text((8, 24 + a.height * G), '2  Atış: kısa pembe mermi hedefe uçar', font=font(14), fill=(236, 230, 214))
        fr.alpha_composite(b.resize((b.width * G, b.height * G), Image.NEAREST), (0, 44 + a.height * G))
        frames.append(fr.convert('P', palette=Image.ADAPTIVE, colors=128))
    path = os.path.join(OUT, 'kelebek_ruhu.gif')
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=85, loop=0, disposal=2)
    print(path, frames[0].size)

    if check_path:                                       # kendi gözle kontrol: 3 poz + lazer kareleri
        Z = 6
        chk = Image.new('RGBA', (792, 13 * Z + 8 + 56 * 3 * 2), (34, 30, 40, 255))
        for i, k in enumerate(('U', 'M', 'D')):
            p = Image.new('RGBA', (25, 13), (58, 66, 74, 255))
            p.alpha_composite(poses[k])
            chk.alpha_composite(p.resize((25 * Z, 13 * Z), Image.NEAREST), (i * (25 * Z + 8), 0))
        for row, mode in enumerate(('isin', 'atis')):
            for col, f in enumerate((4, 5)):
                s = orb_scene(poses, f, mode)
                chk.alpha_composite(s.resize((s.width * 3, s.height * 3), Image.NEAREST), (col * 396, 13 * Z + 8 + row * 168))
        chk.convert('RGB').save(check_path)
    return poses['U']


def main():
    sprites = {k: build(v) for k, v in FAIRIES.items()}
    for k, spr in sprites.items():
        frame48(spr).save(os.path.join(OUT, 'peri_%s.png' % k))
        print(k, spr.size)
    orb = kelebek(sys.argv[1] if len(sys.argv) > 1 else '')
    fairy_sheet(sprites, orb)


if __name__ == '__main__':
    main()
