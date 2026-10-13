"""Evcil hayvan PERİ (2026-10-12, kullanıcı 3. tur prototiplerinden "J"yi seçti: "J yi seçiyorum 4 direction olsun"): sarışın, mavi
elbiseli, asasını havaya kaldırmış peri. Can %100'ün altındayken 6 sn'de bir can basar (bkz. scripts/peri_pet.gd).
4 YÖN: ön (down), arka (up), yan (side; sola bakış = flip_h). Katmanlar: kanat pozu (yukarı / açık / aşağı) + gövde + asa yıldızı.
  - Ön: onaylanan kare (kanat "açık"). Kanatlar gövdenin ARKASINDA; sol yarı yazılır, sağ yarı aynalanır (orta sütun 12).
  - Arka: saç başı örter (yüz yok), asa izleyicinin SOLUNDA, kanat kökleri sırtta gövdenin ÜSTÜNDE.
  - Yan (sağa bakar): profil baş, asa önde; kanat olarak öndeki görünümün SOL kanadı (arkada kalan tek kanat).
  fly_<yön>  : 4 kare (kanat yukarı, açık, aşağı, açık), döngü, 10 fps
  cast_<yön> : 4 kare, tek sefer, 10 fps - asanın yeşil yıldızı büyür, patlar, halka olur, söner (can basma büyüsü)
Gövde merkezi her karede hücrenin 23. sütununda, göğüs ~24. satırda -> düğüm orijini = gövde.
Çıktı: assets/pets/peri/peri_sheet.png (8 x 3 hücre, 48x48) + peri_frames.tres
       tools/proto_20261012/out/peri_yonler.{png,gif} (önizleme)
Kullanım (proje kökünden): python -I tools/gen_peri.py   (sonra Godot --headless --path . --import)
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
sys.path.insert(0, HERE)
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

OUT = os.path.join(ROOT, 'assets', 'pets', 'peri')
PREVIEW = os.path.join(HERE, 'proto_20261012', 'out')
CELL = 48
ART_W, ART_H = 25, 21
TOP = 3                      # satırlar yıldız patlaması için 3 aşağı kaydırılır
ART_AT = (11, 13)            # sanatın hücredeki sol üst köşesi
PAL = {
    'o': (46, 30, 44), 's': (248, 216, 186), 'e': (44, 28, 36),
    'd': (196, 134, 34), 'h': (246, 198, 72), 'H': (255, 238, 158),
    'k': (44, 96, 170), 'g': (86, 150, 220), 'G': (150, 204, 250),
    'x': (70, 150, 150), 'v': (150, 220, 214), 'w': (200, 244, 236), 'W': (240, 255, 250),
    'n': (150, 96, 50), 'T': (96, 206, 96), 'Y': (240, 255, 230), 'm': (56, 160, 72),
}
ALPHA = {'v': 215, 'w': 215, 'W': 235}
FLAP = ['U', 'M', 'D', 'M']

## Sol kanat (13 sütun: 0..12, orta 12). Ön/arka için aynalanır; yan görünümde olduğu gibi kullanılır.
WINGS = {
    'U': [
        "...xx........",
        "..xWWx.......",
        "..xWwwx......",
        "..xwWwwx.....",
        "...xwwwvx....",
        "...xwwvvx....",
        "....xwvvvx...",
        ".....xxvvx...",
        "...xxxxxx....",
        "..xwwwvvx....",
        "...xxwvx.....",
        ".....xx......",
        ".............",
    ],
    'M': [
        ".............",
        ".............",
        "..xxx........",
        ".xWWwx.......",
        ".xWwwwx......",
        ".xwwwvvx.....",
        "..xwvvvvx....",
        "...xxvvvvx...",
        ".....xxxx....",
        "....xxxxx....",
        "...xwwvx.....",
        "...xwvx......",
        "....xx.......",
    ],
    'D': [
        ".............",
        ".............",
        ".............",
        ".............",
        ".............",
        "....xxxx.....",
        "..xxwwvvx....",
        ".xWwwwvvvx...",
        ".xWwwvvxxx...",
        "..xxxxvvx....",
        "....xwvx.....",
        "....xwx......",
        ".....x.......",
    ],
}
BODY = {
    'down': [
        "",
        "..........ooooo",
        ".........ohHHhho",
        ".........ohsssho.n",
        ".........ohesedo.so",
        ".........odsssdoso",
        "..........oooooso",
        "..........oGGgo",
        "........osoGGgo",
        ".........oGGggko",
        "........oGgGggkko",
        "........okgkgkgko",
        ".........oososoo",
        "..........osoo",
        "...........o",
    ],
    'up': [
        "",
        "..........ooooo",
        ".........ohHHhho",
        ".......n.ohhHhho",
        "......os.ohhhhdo",
        ".......osodhhddo",
        "........osooooo",
        "..........oGGgo",
        "..........oGGgoso",
        ".........oGGggko",
        "........oGgGggkko",
        "........okgkgkgko",
        ".........oososoo",
        "...........ooso",
        ".............o",
    ],
    'side': [
        "",
        "..........ooooo",
        ".........ohHHhho",
        ".........ohhhsso",
        ".........ohhseso",
        ".........oddssso.n",
        "..........ooooooon",
        "..........oGGgsss",
        "..........oGGgooo",
        ".........oGGggko",
        "........oGgGggkko",
        "........okgkgkgko",
        ".........oossooo",
        ".........osso",
        "..........oo",
    ],
}
STAR_AT = {'down': (17, 1), 'up': (7, 1), 'side': (17, 3)}
## Arka: kanat kökleri sırtta (gövdenin üstüne çizilir; x aynalanır).
BACK_ROOTS = [(10, 7, 'x'), (11, 8, 'x')]

N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
DIAG = ((1, 1), (-1, 1), (1, -1), (-1, -1))


def star_cells(state):
    """Yıldızın merkezine göre (dx, dy, renk harfi). 'idle' = küçük artı; c0..c3 = can basma patlaması."""
    out = []
    if state == 'idle':
        out += [(dx, dy, 'T') for dx, dy in N4] + [(0, 0, 'Y')]
    elif state == 'c0':
        out += [(dx * 2, dy * 2, 'T') for dx, dy in N4] + [(dx, dy, 'T') for dx, dy in DIAG]
        out += [(dx, dy, 'Y') for dx, dy in N4] + [(0, 0, 'Y')]
    elif state == 'c1':
        out += [(dx * 3, dy * 3, 'T') for dx, dy in N4] + [(dx * 2, dy * 2, 'T') for dx, dy in DIAG]
        out += [(dx * 2, dy * 2, 'Y') for dx, dy in N4] + [(dx, dy, 'Y') for dx, dy in N4 + DIAG] + [(0, 0, 'Y')]
    elif state == 'c2':
        out += [(dx * 3, dy * 3, 'Y') for dx, dy in N4] + [(dx * 2, dy * 2, 'T') for dx, dy in DIAG]
        out += [(dx, dy, 'T') for dx, dy in N4] + [(0, 0, 'Y')]
    elif state == 'c3':
        out += [(dx * 4, dy * 4, 'm') for dx, dy in N4] + [(dx * 3, dy * 3, 'm') for dx, dy in DIAG]
        out += [(dx, dy, 'T') for dx, dy in N4] + [(0, 0, 'Y')]
    return out


def put(px, x, y, ch):
    if ch != '.' and 0 <= x < ART_W and 0 <= y + TOP < ART_H:
        c = PAL[ch]
        px[x, y + TOP] = (c[0], c[1], c[2], ALPHA.get(ch, 255))


def draw_rows(px, rows):
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            put(px, x, y, ch)


def wing_rows(pose, mirror):
    for r in WINGS[pose]:
        assert len(r) == 13, (pose, r)
    return [r + r[-2::-1] for r in WINGS[pose]] if mirror else WINGS[pose]


def frame(direction, pose, star):
    im = Image.new('RGBA', (ART_W, ART_H), (0, 0, 0, 0))
    px = im.load()
    if direction == 'up':
        draw_rows(px, BODY['up'])
        draw_rows(px, wing_rows(pose, True))
        for x, y, ch in BACK_ROOTS:
            put(px, x, y, ch)
            put(px, ART_W - 1 - x, y, ch)
    else:
        draw_rows(px, wing_rows(pose, direction == 'down'))
        draw_rows(px, BODY[direction])
    sx, sy = STAR_AT[direction]
    for dx, dy, ch in star_cells(star):
        put(px, sx + dx, sy + dy, ch)
    return im


def font(sz):
    for c in (r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\arial.ttf'):
        if os.path.exists(c):
            return ImageFont.truetype(c, sz)
    return ImageFont.load_default()


def main():
    dirs = ['down', 'up', 'side']
    fly = {d: [frame(d, k, 'idle') for k in FLAP] for d in dirs}
    cast = {d: [frame(d, k, 'c%d' % i) for i, k in enumerate(FLAP)] for d in dirs}
    sheet = Image.new('RGBA', (CELL * 8, CELL * 3), (0, 0, 0, 0))
    for row, d in enumerate(dirs):
        for col, f in enumerate(fly[d] + cast[d]):
            sheet.alpha_composite(f, (col * CELL + ART_AT[0], row * CELL + ART_AT[1]))
    os.makedirs(OUT, exist_ok=True)
    png = os.path.join(OUT, 'peri_sheet.png')
    sheet.save(png)
    anims = []
    for row, d in enumerate(dirs):
        anims.append(('fly_' + d, (0, row), 4, True, 10.0))
        anims.append(('cast_' + d, (4, row), 4, False, 10.0))
    write_sprite_frames(os.path.join(OUT, 'peri_frames.tres'), 'res://assets/pets/peri/peri_sheet.png', CELL, CELL, anims)
    print('wrote', png, sheet.size)

    # ---- önizleme: 4 yön (sol = yanın aynası); üst sıra uçuş, alt sıra can basma büyüsü
    Z = 7
    labels = [('Ön', 'down', False), ('Arka', 'up', False), ('Sağ', 'side', False), ('Sol', 'side', True)]
    cw, top = ART_W * Z + 12, 24
    rh = top + ART_H * Z + 6

    def strip(i):
        im = Image.new('RGBA', (cw * 4, rh * 2), (34, 30, 40, 255))
        dr = ImageDraw.Draw(im)
        for row, (src, title) in enumerate(((fly, 'uçuş'), (cast, 'can basma büyüsü'))):
            for c, (name, d, flip) in enumerate(labels):
                p = Image.new('RGBA', (ART_W, ART_H), (58, 66, 74, 255))
                a = src[d][i]
                p.alpha_composite(a.transpose(Image.FLIP_LEFT_RIGHT) if flip else a)
                im.alpha_composite(p.resize((ART_W * Z, ART_H * Z), Image.NEAREST), (c * cw + 6, row * rh + top))
                dr.text((c * cw + 8, row * rh + 3), '%s - %s' % (name, title), font=font(15), fill=(236, 230, 214))
        return im

    os.makedirs(PREVIEW, exist_ok=True)
    frames = [strip(i) for i in range(4)]
    gif = [f.convert('P', palette=Image.ADAPTIVE, colors=64) for f in frames]
    gif[0].save(os.path.join(PREVIEW, 'peri_yonler.gif'), save_all=True, append_images=gif[1:], duration=100, loop=0, disposal=2)
    Zc = 4
    chk = Image.new('RGBA', (8 * (ART_W * Zc + 4), 3 * (ART_H * Zc + 4)), (34, 30, 40, 255))
    for row, d in enumerate(dirs):
        for col, f in enumerate(fly[d] + cast[d]):
            p = Image.new('RGBA', (ART_W, ART_H), (58, 66, 74, 255))
            p.alpha_composite(f)
            chk.alpha_composite(p.resize((ART_W * Zc, ART_H * Zc), Image.NEAREST), (col * (ART_W * Zc + 4), row * (ART_H * Zc + 4)))
    chk.convert('RGB').save(os.path.join(PREVIEW, 'peri_yonler.png'))
    print('wrote preview', chk.size)


if __name__ == '__main__':
    main()
