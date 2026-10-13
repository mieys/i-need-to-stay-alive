"""2026-10-12 prototipleri, 3. tur - CAN BASAN PERİ (kullanıcı: "4 prototip daha yap ve ışık perisi ile asılı perinin fenotipine
benzeyebilirler" -> 2. turun E "Işıktan Peri" + F "Asalı Peri" tipleri esas alındı). OYUNA BAĞLI DEĞİL, duran kare.
    I  Işıktan Asalı Peri - E'nin ışıktan bedeni + F'nin yandan uçuşu ve asası (altın yıldız)
    J  Asalı Peri, önden  - F'nin kızı dik süzülür, asayı havaya kaldırmış (büyü anı), iki yana açık kanat
    K  Altın Işık Perisi  - E'nin sıcak (altın-beyaz) hali, göğsünde yeşil şifa küresi, sivri kırlangıç kanat
    L  Fenerli Peri       - F tipi yandan uçuş; kızıl saç, yaprak elbise, yusufçuk kanadı, asa yerine sopada fener
Çıktı: out/peri_{i,j,k,l}.png (48x48) + out/peri_pet_v3_sheet.png (sağda karşılaştırma: E ve F)
Kullanım (proje kökünden): python -I tools/proto_20261012/gen_peri_pet_v3.py
"""
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from gen_peri_pet import EYE, GRASS, INK, OUT, SKIN, font, shadow  # noqa: E402
import gen_peri_pet_v2 as v2  # noqa: E402

LIGHT_WING = {'x': (84, 160, 186), 'v': (168, 222, 236), 'w': (212, 242, 248), 'W': (246, 254, 255)}
TEAL_WING = {'x': (70, 150, 150), 'v': (150, 220, 214), 'w': (200, 244, 236), 'W': (240, 255, 250)}
BLONDE = {'d': (196, 134, 34), 'h': (246, 198, 72), 'H': (255, 238, 158)}
BLUE = {'k': (44, 96, 170), 'g': (86, 150, 220), 'G': (150, 204, 250)}

FAIRIES = {
    'i': {
        'name': 'I  Işıktan Asalı Peri',
        'pal': dict({
            'r': (44, 150, 118), 'p': (150, 236, 190), 'P': (214, 252, 228), 'C': (250, 255, 250),
            'n': (176, 130, 70), 'T': (255, 214, 96), 'Y': (255, 252, 224),
        }, **LIGHT_WING),
        'full': [
            "",
            "...xxx......rrrr",
            "..xWWwx....rPCCPr",
            "..xWwwwx...rCCCCr",
            "..xwWwwvx..rCCCCr...T",
            "...xwwWvvx.rPCCPr..TYT",
            "....xxwwvx..rrrr....T",
            "......xxvvxrCPr....n",
            ".......xxxrCCPPr..n",
            "...xxxxxxrCCPPPPPPr",
            "..xwwvvrCCPPprrrr",
            "...xxxrPPpppr",
            "....rPPrrrrr",
            "..rPPrr",
            "...rr",
        ],
        'dust': [(17, 12, '.'), (20, 9, '.'), (9, 14, '.')],
        'dust_pal': [(255, 252, 224), (255, 222, 120)],
    },
    'j': {
        'name': 'J  Asalı Peri (önden)',
        'pal': dict({
            'o': INK, 's': SKIN, 'e': EYE,
            'n': (150, 96, 50), 'T': (96, 206, 96), 'Y': (240, 255, 230),
        }, **BLONDE, **BLUE, **TEAL_WING),
        'full': [
            "................T",
            ".........ooooo.TYT",
            ".xxx....ohHHhho.T..xxx",
            "xWWwx...ohsssho.n.xwWWx",
            "xWwwwx..ohesedo.sowwwWx",
            "xwwwvvx.odsssdosovvwwwx",
            ".xwvvvvx.ooooosovvvvwx",
            "..xxvvvvxoGGgoxvvvvxx",
            "....xxxosoGGgo..xxx",
            "...xxxxxoGGggkoxxxxx",
            "..xwwvxoGgGggkkoxvwwx",
            "..xwvx.okgkgkgko.xvwx",
            "...xx...oososoo...xx",
            ".........osoo",
            "..........o",
        ],
        'dust': [(13, 0, '.'), (19, 0, '.'), (20, 14, '.'), (4, 14, '.')],
        'dust_pal': [(240, 255, 230), (150, 232, 150)],
    },
    'k': {
        'name': 'K  Altın Işık Perisi',
        'pal': {
            'r': (196, 128, 36), 'p': (255, 214, 110), 'P': (255, 238, 170), 'C': (255, 252, 236),
            'x': (214, 150, 90), 'v': (255, 214, 170), 'w': (255, 236, 208), 'W': (255, 250, 240),
            'q': (96, 206, 96), 'Q': (176, 248, 160), 'Y': (240, 255, 230),
        },
        'half': [
            ".............",
            ".xx..........",
            "xWWx.......rr",
            "xWwwx.....rPC",
            ".xwWwx....rCC",
            ".xwwWwx...rPC",
            "..xwwvvx...rC",
            "...xxwvvxrPQY",
            ".....xxxx.rqQ",
            "....xwwx.rPCC",
            "...xwvx.rPPCC",
            "..xwvx..rpPpC",
            "..xwx....rrPr",
            "..xx.......r.",
        ],
        'dust': [(12, 15, '+'), (7, 15, '.'), (18, 14, '.')],
        'dust_pal': [(240, 255, 230), (150, 240, 150)],
    },
    'l': {
        'name': 'L  Fenerli Peri (yandan)',
        'pal': dict({
            'o': INK, 's': SKIN, 'e': EYE,
            'd': (130, 50, 30), 'h': (196, 84, 40), 'H': (236, 140, 70),
            'n': (130, 90, 50), 'T': (255, 214, 96), 'Y': (255, 250, 200),
        }, **v2.GREENS, **LIGHT_WING),
        'full': [
            "",
            "..xx........oooo",
            "..xWx......ohHHho",
            "...xWwx...ohHhhhso",
            "....xwWx..ohhhssso",
            ".....xwwx.odhsseso",
            "......xwvxoddssso..noo",
            ".......xvvxoGgoo..n.YY",
            ".xxxxxxxxxoGGggo.n..TT",
            "xWwwwwvvvoGGggssso..oo",
            ".xxxxxxoGGggkoooo",
            "......oggkkko",
            "....ossooooo",
            "..ossoo",
            "...oo",
        ],
        'dust': [(18, 6, '.'), (19, 11, '.'), (21, 12, '+')],
        'dust_pal': [(255, 250, 200), (255, 214, 96)],
    },
}


def main():
    sprites = {k: v2.build(spec) for k, spec in FAIRIES.items()}
    for k, spr in sprites.items():
        v2.frame48(spr).save(os.path.join(OUT, 'peri_%s.png' % k))
        print(k, spr.size)
    ref = [v2.build(v2.FAIRIES['e']), v2.build(v2.FAIRIES['f'])]

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
    d.text((pad, top_h + 4), 'Oyun ölçeği (x4)  |  sağda karşılaştırma: önceki turun E ve F perileri', font=font(13), fill=(190, 186, 176))
    strip = Image.new('RGBA', (strip_w, strip_h), GRASS + (255,))
    chars = ['melek', 'elara', 'oakley', 'buyucu']
    slot = 56
    for i, spr in enumerate(sprites.values()):
        cx = 2 + i * slot
        strip.alpha_composite(v2.char_frame(chars[i]), (cx - 8, 8))
        fx = cx + 27
        strip.alpha_composite(shadow(9), (fx + spr.width // 2 - 4, 47))
        strip.alpha_composite(spr, (fx, 6))
    strip.alpha_composite(ref[0], (4 * slot + 6, 8))
    strip.alpha_composite(ref[1], (4 * slot + 38, 10))
    sheet.alpha_composite(strip.resize((strip_w * G, strip_h * G), Image.NEAREST), (0, top_h + 26))
    path = os.path.join(OUT, 'peri_pet_v3_sheet.png')
    sheet.convert('RGB').save(path)
    print(path, sheet.size)


if __name__ == '__main__':
    main()
