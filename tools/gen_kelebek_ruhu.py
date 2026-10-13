"""Evcil hayvan KELEBEK RUHU (2026-10-12): pembe ışık küresi + 4 lila kanat. 4 YÖN (kullanıcı: "kelebek ruhu 4 direction dimi?
öyle değilse öyle olmasını sağla"): ön (down), arka (up), yan (side; sola bakış = flip_h). Her yön 4 karelik çırpma (yukarı, açık,
aşağı, açık). Onaylanan önden görünüm tools/proto_20261012/gen_peri_pet_v2.py'deki "D" tasarımı.
  - Ön: simetrik, sol yarı yazılır + aynalanır (orta sütun 12).
  - Arka: ön pozların aynısı; kürenin beyaz çekirdeği yok (C -> P), kanat kökleri kürenin ÜSTÜNDE birleşir (lila V).
  - Yan (sağa bakar): kanatlar arkada (solda); yukarıdayken geniş yüzü, aşağıdayken ince kenarı görünür. Parlak çekirdek öne kayık.
Küre merkezi her karede hücrenin (23, 24) pikselinde -> düğüm orijini = küre (atış buradan çıkar, bkz. scripts/kelebek_ruhu.gd).
Çıktı: assets/pets/kelebek_ruhu/kelebek_sheet.png (4 x 3 hücre, 48x48) + kelebek_frames.tres (fly_down / fly_up / fly_side)
       tools/proto_20261012/out/kelebek_ruhu_yonler.{png,gif} (önizleme)
Kullanım (proje kökünden): python -I tools/gen_kelebek_ruhu.py   (sonra Godot --headless --path . --import)
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
sys.path.insert(0, HERE)
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

OUT = os.path.join(ROOT, 'assets', 'pets', 'kelebek_ruhu')
PREVIEW = os.path.join(HERE, 'proto_20261012', 'out')
CELL = 48
ART_W, ART_H = 25, 13
ART_AT = (11, 16)            # sanatın hücredeki sol üst köşesi: küre merkezi (12, 8) -> hücre (23, 24)
PAL = {
    'r': (196, 62, 134), 'p': (255, 132, 192), 'P': (255, 194, 226), 'C': (255, 248, 252),
    'x': (140, 104, 200), 'v': (198, 180, 240), 'w': (226, 214, 250), 'W': (250, 246, 255),
}
ALPHA = {'v': 215, 'w': 215, 'W': 235}
FLAP = ['U', 'M', 'D', 'M']

FRONT = {
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
## Arka: kanat kökleri kürenin üstünde (sol yarı; x aynalanır).
BACK_ROOTS = {
    'U': [(10, 6, 'x'), (11, 7, 'x'), (12, 8, 'x')],
    'M': [(10, 6, 'x'), (11, 7, 'x'), (12, 8, 'x')],
    'D': [(9, 7, 'x'), (10, 7, 'x'), (11, 7, 'x'), (12, 8, 'x')],
}
SIDE = {
    'U': [
        ".......xx",
        "......xWWx",
        "......xWwwx",
        "......xwWwwx",
        ".......xwWwvx",
        "........xwvrrr",
        "........xxrpPPr",
        "......xxxrppPCPr",
        ".....xwwvrpPCCCr",
        "......xxvrppPCPr",
        "........x.rpPPr",
        "...........rrr",
    ],
    'M': [
        "",
        "...xx",
        "..xWWx",
        "..xwWwx",
        "...xwWwx",
        "....xwwvx..rrr",
        ".....xxvvxrpPPr",
        ".......xxrppPCPr",
        ".....xxxxrpPCCCr",
        "....xwwvxrppPCPr",
        "....xxxx..rpPPr",
        "...........rrr",
    ],
    'D': [
        "",
        "",
        "",
        "",
        "",
        "...........rrr",
        "..........rpPPr",
        "..xxxxxxxrppPCPr",
        ".xwwwwvvvrpPCCCr",
        "..xxxwwvxrppPCPr",
        ".....xxxx.rpPPr",
        "...........rrr",
    ],
}


def paint(rows):
    im = Image.new('RGBA', (ART_W, ART_H), (0, 0, 0, 0))
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != '.':
                c = PAL[ch]
                px[x, y] = (c[0], c[1], c[2], ALPHA.get(ch, 255))
    return im


def front_rows(pose):
    for r in FRONT[pose]:
        assert len(r) == 13, (pose, r)
    return [r + r[-2::-1] for r in FRONT[pose]]


def back_rows(pose):
    rows = [list(r.replace('C', 'P')) for r in front_rows(pose)]
    for x, y, ch in BACK_ROOTS[pose]:
        rows[y][x] = ch
        rows[y][ART_W - 1 - x] = ch
    return [''.join(r) for r in rows]


def poses(direction):
    if direction == 'down':
        return {k: paint(front_rows(k)) for k in FRONT}
    if direction == 'up':
        return {k: paint(back_rows(k)) for k in FRONT}
    return {k: paint(SIDE[k]) for k in SIDE}


def font(sz):
    for c in (r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\arial.ttf'):
        if os.path.exists(c):
            return ImageFont.truetype(c, sz)
    return ImageFont.load_default()


def main():
    dirs = ['down', 'up', 'side']
    art = {d: poses(d) for d in dirs}
    sheet = Image.new('RGBA', (CELL * 4, CELL * 3), (0, 0, 0, 0))
    for row, d in enumerate(dirs):
        for col, k in enumerate(FLAP):
            sheet.alpha_composite(art[d][k], (col * CELL + ART_AT[0], row * CELL + ART_AT[1]))
    os.makedirs(OUT, exist_ok=True)
    png = os.path.join(OUT, 'kelebek_sheet.png')
    sheet.save(png)
    write_sprite_frames(os.path.join(OUT, 'kelebek_frames.tres'), 'res://assets/pets/kelebek_ruhu/kelebek_sheet.png', CELL, CELL, [
        ('fly_down', (0, 0), 4, True, 12.0),
        ('fly_up', (0, 1), 4, True, 12.0),
        ('fly_side', (0, 2), 4, True, 12.0),
    ])
    print('wrote', png, sheet.size)

    # ---- önizleme: 4 yön (sol = yanın aynası), x7
    Z = 7
    labels = [('Ön', 'down', False), ('Arka', 'up', False), ('Sağ', 'side', False), ('Sol', 'side', True)]
    cw, top = ART_W * Z + 12, 24

    def strip(pose_of):
        im = Image.new('RGBA', (cw * 4, top + ART_H * Z + 6), (34, 30, 40, 255))
        dr = ImageDraw.Draw(im)
        for i, (name, d, flip) in enumerate(labels):
            p = Image.new('RGBA', (ART_W, ART_H), (58, 66, 74, 255))
            a = art[d][pose_of]
            p.alpha_composite(a.transpose(Image.FLIP_LEFT_RIGHT) if flip else a)
            im.alpha_composite(p.resize((ART_W * Z, ART_H * Z), Image.NEAREST), (i * cw + 6, top))
            dr.text((i * cw + 8, 3), name, font=font(15), fill=(236, 230, 214))
        return im

    os.makedirs(PREVIEW, exist_ok=True)
    frames = [strip(k) for k in FLAP]
    still = Image.new('RGBA', (frames[0].width, frames[0].height * 3), (34, 30, 40, 255))
    for i, k in enumerate(('U', 'M', 'D')):
        still.alpha_composite(strip(k), (0, i * frames[0].height))
    still.convert('RGB').save(os.path.join(PREVIEW, 'kelebek_ruhu_yonler.png'))
    gif = [f.convert('P', palette=Image.ADAPTIVE, colors=64) for f in frames]
    gif[0].save(os.path.join(PREVIEW, 'kelebek_ruhu_yonler.gif'), save_all=True, append_images=gif[1:], duration=85, loop=0, disposal=2)
    print('wrote preview', still.size)


if __name__ == '__main__':
    main()
