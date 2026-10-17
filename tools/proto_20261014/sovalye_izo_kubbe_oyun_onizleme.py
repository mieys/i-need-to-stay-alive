"""Oyuna giren GERCEK sayfalarla (assets/fx/paladin_dome/iso_* + sovalye bariyer.png) birlesik onizleme (madde 160).

Katman sirasi oyundakiyle ayni: zemin ayak izi + arka kabuk (z 0) -> karakterler (z 1) -> on kabuk (z 20). Sovalye scripts/paladin_dome.gd
levitate_offset ile havada (ayni sabitler elle kopyalandi), golgesi yerde. Silahlar dome_weapon_ring.gd rim_point (elips + RIM_LIFT).
Cikti: out/sovalye_izo_kubbe_oyun.gif (x2 kamera).
"""
import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DOME = os.path.join(ROOT, "assets", "fx", "paladin_dome")
ZOOM = 2
W, H = 340, 262
CX, CY = 170, 166
R = 126.0
RX, RY = R, R / 2
CHAR_PX = 2.2368375 * 0.8075 * 0.5
FRAMES = 32  # 4 sn @ 8 fps
TREMBLE = [(0, 0), (1, 0), (-1, 0), (0, 0), (1, 0), (0, 1), (-1, 0), (1, 0), (0, 0), (-1, 0), (0, -1), (0, 0)]


def grid_frames(name, cell_w, cell_h, count):
    sheet = Image.open(os.path.join(DOME, name)).convert("RGBA")
    return [sheet.crop(((i % 4) * cell_w, (i // 4) * cell_h, (i % 4) * cell_w + cell_w, (i // 4) * cell_h + cell_h))
            for i in range(count)]


def up(img):
    return img.resize((img.width * ZOOM, img.height * ZOOM), Image.NEAREST)


def lev(t):
    lift = 10 + round(math.sin(t * 3.0) * 3)
    tx, ty = TREMBLE[int(t * 18) % len(TREMBLE)]
    return tx, -lift + ty


def main():
    floor = Image.open(os.path.join(DOME, "iso_floor.png")).convert("RGBA")
    back = grid_frames("iso_back_sheet.png", 256, 129, 16)
    front = grid_frames("iso_front_sheet.png", 256, 196, 16)
    knight = Image.open(os.path.join(ROOT, "assets", "characters", "sovalye", "sheets", "bariyer.png")).convert("RGBA")
    elara = Image.open(os.path.join(ROOT, "assets", "characters", "elara", "sheets", "idle.png")).convert("RGBA")
    s = round(48 * CHAR_PX * ZOOM)
    weapons = []
    for rel in ["tabanca/icon_v2.png", "tufek/icon.png", "uzunkilic/icon.png", "buz_asasi/icon.png", "crossbow/icon.png", "topuz/icon.png"]:
        im = Image.open(os.path.join(ROOT, "assets", "weapons", rel)).convert("RGBA")
        im = im.crop(im.getbbox())
        k = 26 * ZOOM / max(im.size)
        im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
        a = im.split()[3].point(lambda v: 255 if v > 110 else 0)
        im.putalpha(a)
        weapons.append(im)
    out = []
    for f in range(FRAMES):
        t = f / 8.0
        bg = Image.new("RGBA", (W, H), (80, 138, 58, 255))
        px = bg.load()
        for y in range(H):
            for x in range(W):
                if (x * 7 + y * 13) % 17 == 0:
                    px[x, y] = (92, 152, 64, 255)
        bg.alpha_composite(floor, (CX - 128, CY - 68))
        bg.alpha_composite(back[f % 16], (CX - 128, CY - 128))
        canvas = up(bg)
        d = ImageDraw.Draw(canvas, "RGBA")
        slots = []
        for i in range(6):
            a = -math.pi / 2 + 2 * math.pi * i / 6
            gx, gy = math.cos(a) * (RX + 12), math.sin(a) * (RY + 12)
            slots.append((gy, i, CX + gx, CY + gy - 6))
        for gy, i, wx, wy in slots:
            d.ellipse([(wx - 7) * ZOOM, (wy + 6 - 2.5) * ZOOM, (wx + 7) * ZOOM, (wy + 6 + 2.5) * ZOOM], fill=(20, 40, 20, 80))
        # karakter golgeleri (yerde kalir)
        for x, y in ((CX - 4, CY + 22), (CX + 40, CY + 6)):
            d.ellipse([(x - 9) * ZOOM, (y - 3) * ZOOM, (x + 9) * ZOOM, (y + 3) * ZOOM], fill=(20, 40, 20, 90))
        for gy, i, wx, wy in sorted(slots):
            if gy < 0:
                canvas.alpha_composite(weapons[i], (round(wx * ZOOM - weapons[i].width / 2), round(wy * ZOOM - weapons[i].height / 2)))
        # Elara (arka), Sovalye (on, havada)
        el = elara.crop(((f // 2 % 4) * 48, 0, (f // 2 % 4) * 48 + 48, 48)).resize((s, s), Image.NEAREST)
        canvas.alpha_composite(el, (round((CX + 40) * ZOOM - s / 2), round((CY + 6 + 4 * CHAR_PX) * ZOOM - s)))
        kf = knight.crop(((f % 6) * 48, 0, (f % 6) * 48 + 48, 48))
        ox, oy = lev(t)
        kf = kf.resize((s, s), Image.NEAREST)
        canvas.alpha_composite(kf, (round((CX - 4 + ox * CHAR_PX) * ZOOM - s / 2), round((CY + 22 + (4 + oy) * CHAR_PX) * ZOOM - s)))
        canvas.alpha_composite(up(front[f % 16]), ((CX - 128) * ZOOM, (CY - 128) * ZOOM))
        for gy, i, wx, wy in sorted(slots):
            if gy >= 0:
                canvas.alpha_composite(weapons[i], (round(wx * ZOOM - weapons[i].width / 2), round(wy * ZOOM - weapons[i].height / 2)))
        out.append(canvas.convert("RGB").quantize(colors=255, method=Image.MEDIANCUT, dither=Image.NONE))
        if f == 3:
            canvas.save(os.path.join(HERE, "out", "sovalye_izo_kubbe_oyun_kare.png"))
    out[0].save(os.path.join(HERE, "out", "sovalye_izo_kubbe_oyun.gif"), save_all=True, append_images=out[1:],
                duration=125, loop=0, disposal=1)
    print("tamam")


if __name__ == "__main__":
    main()
