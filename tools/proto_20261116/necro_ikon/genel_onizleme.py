# Necro E/R için "Genel iconlar" adayları (paket, satır, sütun; 0'dan) -> out/genel_onizleme.png + out/genel_<kod>.png (144x144)
import colorsys, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import genel_cikar as g
from PIL import Image, ImageDraw
SK = "../../../assets/skills/necromancer_%s_icon.png"
NE = "Necromancer-Skill-Pixel-Art-Icons2-720x480.webp"
UN = "Free-Undead-Skill-Pixel-Art-Icons2.jpg"
SU = "Summoner-32x32-Skills-RPG-Icon-Pack2-720x480.webp"
AR = "Archer-Skills-Pixel-Art-Icons2-720x480.webp"

def hue_rot(im, d):  # tüm doygun tonları d derece döndür, luma koru
    im = im.copy(); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g_, b, a = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g_ / 255, b / 255)
            if s < .15: continue
            nr, ng, nb = [c * 255 for c in colorsys.hsv_to_rgb((h + d / 360) % 1, s, v)]
            l0 = .299 * r + .587 * g_ + .114 * b; l1 = .299 * nr + .587 * ng + .114 * nb
            k = l0 / l1 if l1 > .5 else 1
            px[x, y] = tuple(int(min(255, c * k)) for c in (nr, ng, nb)) + (a,)
    return im

E = [("E1", NE, 0, 3, "Necro: iskelet (yesil)"), ("E2", NE, 0, 5, "Necro: mezardan iskelet"),
     ("E3", NE, 0, 1, "Necro: iskelet (pembe)"), ("E4", AR, 2, 7, "Archer: kukuleteli okcu"),
     ("E5", AR, 0, 7, "Archer: yesil ok yagmuru"), ("E6", AR, 3, 7, "Archer: yesil ok"),
     ("E7", UN, 1, 0, "Undead: ok yagmuru")]
R = [("R1", NE, 4, 2, "Necro: uc hayalet"), ("R2", NE, 2, 3, "Necro: zombi ikilisi"),
     ("R3", NE, 2, 0, "Necro: mezardan el"), ("R4", NE, 3, 0, "Necro: kalkan olular"),
     ("R5", UN, 5, 4, "Undead: mezardan hayalet"), ("R6", SU, 3, 0, "Summoner: golge ordu"),
     ("R7", UN, 4, 2, "Undead: cagrilanlar")]
rows = [("PASIF (yeni yesil)  +  Q", [(Image.open(SK % "passive"), "pasif B yesil"), (Image.open(SK % "iskelet_cagir"), "Q")])]
for title, lst, cur in (("E Kemik Okcusu", E, "hortlak_cagir"), ("R Oluler Ordusu", R, "lanetli_kafatasi")):
    items = [(Image.open(SK % cur), "simdi")]
    for code, pack, r, c, lab in lst:
        im = g.icon(pack, r, c); im.save("out/genel_%s.png" % code)
        items.append((im, code + " " + lab))
    rows.append((title, items))
y1 = hue_rot(g.icon(NE, 4, 2), 70); y1.save("out/genel_R1_yesil.png")
rows[2][1].append((y1, "R1 yesile boyali"))
W, H = 164, 190
out = Image.new("RGBA", (10 + 9 * W, len(rows) * (H + 22)), (34, 30, 38, 255)); d = ImageDraw.Draw(out)
for r, (title, items) in enumerate(rows):
    y0 = r * (H + 22); d.text((10, y0 + 4), title, fill=(255, 220, 120, 255))
    for c, (im, lab) in enumerate(items):
        x = 10 + c * W; out.alpha_composite(im.convert("RGBA"), (x, y0 + 22))
        d.text((x, y0 + 170), lab[:26], fill=(230, 230, 230, 255))
out.save("out/genel_onizleme.png")
