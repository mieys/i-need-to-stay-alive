"""Sovalye R kubbe TACI onizlemesi (2026-10-17): gercek kubbe sayfalari + Zanaatkar silah ikonlari, dome_weapon_ring.gd formulu.
Cikti: tac_onizleme.png (oyun zoom'u x2). Oyuna bagli DEGIL, sadece oran kontrolu."""
import math
from PIL import Image

R = 126.0
CROWN_GAP, CROWN_SPACING, CROWN_MIN = 2.0, 28.0, 26.0
FW, FH, OX, OY = 256, 196, 128, 128
KEYS = ["tabanca", "yay", "arcane", "boomerang", "tufek", "crossbow", "fire_staff", "lightning_staff", "buz_asasi", "tuftuf", "fisek", "uzunkilic"]


def frame(sheet, i=0):
    im = Image.open(sheet).convert("RGBA")
    c, r = i % 4, i // 4
    return im.crop((c * FW, r * FH, c * FW + FW, r * FH + FH))


def crown(count):
    cr = max(CROWN_MIN, count * CROWN_SPACING / math.tau)
    cy = -(R + CROWN_GAP + cr)
    if count <= 1:
        return [(0.0, cy)]
    return [(math.cos(-math.pi / 2 + math.tau * i / count) * cr, cy + math.sin(-math.pi / 2 + math.tau * i / count) * cr) for i in range(count)]


def panel(count):
    W, H = 300, 400
    cx, cy = W // 2, 300
    img = Image.new("RGBA", (W, H), (58, 84, 52, 255))
    floor = Image.open("assets/fx/paladin_dome/iso_floor.png").convert("RGBA")
    img.alpha_composite(floor, (cx - 128, cy - 68))
    img.alpha_composite(frame("assets/fx/paladin_dome/iso_back_sheet.png"), (cx - OX, cy - OY))
    img.alpha_composite(frame("assets/fx/paladin_dome/iso_front_sheet.png"), (cx - OX, cy - OY))
    for i, (x, y) in enumerate(crown(count)):
        ic = Image.open("assets/weapons/zanaat/%s_L1.png" % KEYS[i % len(KEYS)]).convert("RGBA")
        ic = ic.resize((ic.width // 2, ic.height // 2), Image.NEAREST)
        img.alpha_composite(ic, (int(round(cx + x - ic.width / 2)), int(round(cy + y - ic.height / 2))))
    return img


out = Image.new("RGBA", (900, 400))
for k, n in enumerate([3, 6, 12]):
    out.alpha_composite(panel(n), (k * 300, 0))
out = out.resize((out.width * 2, out.height * 2), Image.NEAREST)
out.save("tools/proto_20261017/kubbe_ses/tac_onizleme.png")
print("ok")
