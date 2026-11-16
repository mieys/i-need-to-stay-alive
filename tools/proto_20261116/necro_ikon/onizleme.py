# Necro ikon önizlemesi: pasif renk seçenekleri + E/R için Raven adayları (16x16 x9 = 144, HUD ikonuyla aynı boy).
import colorsys, os
from PIL import Image, ImageDraw
ROOT = os.path.dirname(os.path.abspath(__file__))
SH = Image.open("C:/Users/perva/Desktop/Free - Raven Fantasy Icons/Full Spritesheet/16x16.png").convert("RGBA")
SK = "assets/skills/necromancer_%s_icon.png"

def raven(i):
    j = i - 1
    return SH.crop(((j % 16) * 16, (j // 16) * 16, (j % 16) * 16 + 16, (j // 16) * 16 + 16)).resize((144, 144), Image.NEAREST)

def hue_to(im, target):  # doygun pikselleri hedef tona çevir, luma koru
    im = im.copy(); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0: continue
            h, s, v = colorsys.rgb_to_hsv(r/255, g/255, b/255)
            if s < 0.2: continue
            nr, ng, nb = [c*255 for c in colorsys.hsv_to_rgb(target/360, s, v)]
            l0 = .299*r+.587*g+.114*b; l1 = .299*nr+.587*ng+.114*nb
            k = l0/l1 if l1 > .5 else 1
            px[x, y] = tuple(int(min(255, c*k)) for c in (nr, ng, nb)) + (a,)
    return im

def colorize(im, target):  # tek renkli tonlama: koyu = doygun hedef ton, açık = soluk; luma korunur
    im = im.copy(); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0: continue
            l0 = (.299*r+.587*g+.114*b)/255
            nr, ng, nb = [c*255 for c in colorsys.hsv_to_rgb(target/360, 0.85-0.6*l0, 1)]
            l1 = (.299*nr+.587*ng+.114*nb)/255
            px[x, y] = tuple(int(min(255, c*l0/l1)) for c in (nr, ng, nb)) + (a,)
    return im

rows = [
    ("PASIF (simdi -> secenekler)", [(Image.open(SK % "passive"), "simdi (mavi)"),
        (Image.open(ROOT + "/out/pasif_mor.png"), "A mor"),
        (Image.open(ROOT + "/out/pasif_yesil.png"), "B yesil"),
        (Image.open(ROOT + "/out/pasif_zumrut.png"), "C zumrut"),
        (Image.open(SK % "iskelet_cagir"), "(Q yaninda)"),
        (Image.open(SK % "hortlak_cagir"), "(E yaninda)")]),
    ("E Kemik Okcusu", [(Image.open(SK % "hortlak_cagir"), "simdi"),
        (raven(1100), "fa1100 yay+yesil"), (raven(1751), "fa1751 kara yay"),
        (raven(1750), "fa1750 yesil kirisli"), (raven(835), "fa835 yesil ok izi"),
        (raven(843), "fa843 mor ok izi"), (raven(862), "fa862 kafatasi")]),
    ("R Oluler Ordusu", [(Image.open(SK % "lanetli_kafatasi"), "simdi"),
        (colorize(raven(1166), 110), "fa1166 yesil ton"), (colorize(raven(1166), 280), "fa1166 mor ton"),
        (raven(1438), "fa1438 kara"), (raven(1116), "fa1116 yesil cagri"),
        (raven(1120), "fa1120 mor cagri"), (raven(1082), "fa1082 mor halka")]),
]
W = 164; H = 190
out = Image.new("RGBA", (10 + 7 * W, len(rows) * (H + 22)), (34, 30, 38, 255)); d = ImageDraw.Draw(out)
for r, (title, items) in enumerate(rows):
    y0 = r * (H + 22); d.text((10, y0 + 4), title, fill=(255, 220, 120, 255))
    for c, (im, lab) in enumerate(items):
        x = 10 + c * W; out.alpha_composite(im.convert("RGBA").resize((144, 144), Image.NEAREST), (x, y0 + 22))
        d.text((x, y0 + 170), lab, fill=(230, 230, 230, 255))
out.save(ROOT + "/out/onizleme.png")
