#!/usr/bin/env python3
"""Vampir Cocuk'un E yetenegi (Yarasa Formu) - buyuk yarasa gorunumu, PIXEL-ART yeniden tasarim + SPRITESHEET.

Kullanici istegi (2026-09-24): "vampir cocugun yarasa donusumundeki yarasa formunu daha iyi bir sekilde yeniden
pixel tarzda tasarla ... sonrasinda spritesheete donustur ki performans kaybi olmasin."
Eski kareler (tools/gen_vampir_assets.py make_bat_frames) 16 AYRI PNG'ydi, duz renkli ImageDraw poligonlariyla
cizilmis karikaturumsu bir yarasaydi ve karakterin kendi 48x48 cizim dilinden (koyu sac, kizil atki, siyah pelerin)
kopuktu. Yeni tasarim:
  * Karakterin paleti: neredeyse siyah mor kurk (ust-sol isikli 3 ton), bordo -> kizil kanat zari (govdeye yakin koyu,
    kenara dogru acik, arka kenarda 1 px kizil parlak cizgi), koyu kemik parmaklar (1 px isikli kenar), parlayan kirmizi
    gozler, beyaz disler, kulaklarin ici kizil. 1 px koyu kontur.
  * Gercek yarasa kanadi iskeleti: omuz -> bilek (kol kemigi) -> 3 parmak ucu; parmak uclari arasinda ICERI kivrik
    ("taraklı") arka kenar, bilekte kucuk beyaz basparmak pencesi.
  * 4 yon (down/left/right/up) x 4 kare kanat cirpma (yukari - orta - asagi - orta), govde kanat vurusunun tersine
    hafifce iner/kalkar.
Tuval ve konum eskisiyle AYNI (96x112, govde merkezi y~51) - karakterin anim.offset'i/olcegi ve havada durma
yuksekligi degismez, klip adlari (bat_<yon>) degismez (uzak oyuncular bu adi taniyor, bkz. vampir_math.gd).
Cikti: assets/characters/vampir/bat_sheet.png (4 satir: down, left, right, up; 4 sutun: kareler).
vampir_frames.tres'teki bat_<yon> klipleri bu sayfanin AtlasTexture bolgelerini kullanir (bkz. import_character_sheets.py).
Kullanim: python tools/gen_vampir_bat_form.py [onizleme.png]
"""
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_PATH = os.path.join(ROOT, "assets", "characters", "vampir", "bat_sheet.png")
CELL_W, CELL_H = 96, 112
DIRS = ["down", "left", "right", "up"]  # import_character_sheets.py DIR_ROWS ile ayni sira
BODY_Y = 51  # govde merkezi satiri (eski karelerle ayni havada durma yuksekligi)


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


OUTLINE = hexc("#07030a")
FUR = [hexc("#140b14"), hexc("#24162a"), hexc("#3a2640"), hexc("#5a4264")]  # koyu -> acik
MEM = [hexc("#330914"), hexc("#5c1223"), hexc("#86192d"), hexc("#b8394a")]  # koyu -> kenar parlak
BONE, BONE_H = hexc("#1c0d16"), hexc("#553346")
EAR_IN = hexc("#8e2234")
EYE, EYE_H, EYE_D = hexc("#ff3030"), hexc("#ffd6d6"), hexc("#a3101a")
FANG = hexc("#f4efe8")
CLAW = hexc("#d9d0c8")


class Canvas:
    def __init__(self):
        self.p = {}

    def mask_poly(self, pts):
        im = Image.new("L", (CELL_W, CELL_H), 0)
        ImageDraw.Draw(im).polygon([(round(x), round(y)) for x, y in pts], fill=255)
        px = im.load()
        return {(x, y) for y in range(CELL_H) for x in range(CELL_W) if px[x, y] > 127}

    def mask_ellipse(self, cx, cy, rx, ry):
        out = set()
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    out.add((x, y))
        return out

    def line(self, a, b, col, width=1):
        x0, y0 = a
        x1, y1 = b
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        pts = []
        for i in range(n + 1):
            t = i / n
            p = (int(round(x0 + (x1 - x0) * t)), int(round(y0 + (y1 - y0) * t)))
            pts.append(p)
            self.p[p] = col
            if width > 1:
                self.p[(p[0], p[1] + 1)] = col
        return pts

    def image(self):
        im = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
        px = im.load()
        for (x, y), c in self.p.items():
            if 0 <= x < CELL_W and 0 <= y < CELL_H:
                px[x, y] = c
        # 1 px kontur
        src = im.copy()
        spx = src.load()
        for y in range(CELL_H):
            for x in range(CELL_W):
                if spx[x, y][3] > 0:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < CELL_W and 0 <= ny < CELL_H and spx[nx, ny][3] > 0 and spx[nx, ny] != OUTLINE:
                        px[x, y] = OUTLINE
                        break
        return im


def scallop(a, b, wrist, pull=0.28):
    """a ile b parmak uclari arasindaki arka kenar: bilege dogru ice kivrik 2 ara nokta."""
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    cx, cy = mx + (wrist[0] - mx) * pull, my + (wrist[1] - my) * pull
    return [((a[0] + cx) / 2, (a[1] + cy) / 2 + 0.5), (cx, cy), ((b[0] + cx) / 2, (b[1] + cy) / 2 + 0.5)]


def draw_wing(cv, shoulder, wrist, tips, attach, far=False):
    """shoulder/wrist/tips/attach mutlak koordinat. Zar -> ton bolgeleri -> kemikler."""
    outline = [shoulder, wrist, tips[0]]
    for i in range(len(tips) - 1):
        outline += scallop(tips[i], tips[i + 1], wrist) + [tips[i + 1]]
    outline += scallop(tips[-1], attach, wrist, 0.18) + [attach]
    mem = cv.mask_poly(outline)
    tone_shift = 1 if far else 0
    for (x, y) in mem:
        # govdeye/omuza yakin koyu, disa dogru acik
        d_sh = ((x - shoulder[0]) ** 2 + (y - shoulder[1]) ** 2) ** 0.5
        d_tip = min(((x - t[0]) ** 2 + (y - t[1]) ** 2) ** 0.5 for t in tips)
        f = d_sh / max(d_sh + d_tip, 1)
        idx = 0 if f < 0.28 else (1 if f < 0.62 else 2)
        cv.p[(x, y)] = MEM[max(0, idx - tone_shift)]
    # arka kenar parlak cizgi: zarin altinda bos komsusu olan pikseller
    for (x, y) in mem:
        if (x, y + 1) not in mem and ((x - shoulder[0]) ** 2 + (y - shoulder[1]) ** 2) > 30:
            cv.p[(x, y)] = MEM[3] if not far else MEM[2]
    # kemikler
    bone_h = BONE_H if not far else BONE
    cv.line(shoulder, wrist, BONE, 2)
    for t in tips:
        pts = cv.line(wrist, t, BONE, 1)
        for p in pts[1:-1:2]:
            if (p[0], p[1] - 1) in mem:
                cv.p[(p[0], p[1] - 1)] = bone_h
    cv.p[(int(wrist[0]), int(wrist[1]) - 1)] = bone_h
    # basparmak pencesi
    cv.p[(int(wrist[0]), int(wrist[1]) - 2)] = CLAW
    return mem


def shade_fur(cv, mask, light_dir=(-1, -1)):
    if not mask:
        return
    xs = [p[0] for p in mask]
    ys = [p[1] for p in mask]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    rx, ry = max((max(xs) - min(xs)) / 2, 1), max((max(ys) - min(ys)) / 2, 1)
    ## Küresel gölgelendirme: parçanın elips kutusundan yüzey normali, sol-üst-önden ışık -> hilal biçimli ton bölgeleri
    ## (düz doğrusal ışık çapraz "şeker çubuğu" bantları üretiyordu).
    lx, ly, lz = light_dir[0] * 0.55, light_dir[1] * 0.55, 0.63
    for (x, y) in mask:
        u, v = (x + 0.5 - cx) / (rx + 0.5), (y + 0.5 - cy) / (ry + 0.5)
        w = max(0.0, 1.0 - u * u - v * v) ** 0.5
        lit = u * lx + v * ly + w * lz
        if lit > 0.72:
            c = FUR[3]
        elif lit > 0.45:
            c = FUR[2]
        elif lit > 0.12:
            c = FUR[1]
        else:
            c = FUR[0]
        cv.p[(x, y)] = c


# kanat vurusu: omuza gore bilek ve 3 parmak ucu (sag kanat; sol kanat x aynasi)
FRONT_FLAP = [
    ((13, -15), [(31, -30), (40, -17), (35, -3)], (5, 13)),   # yukari
    ((18, -5), [(39, -13), (44, 0), (35, 11)], (5, 13)),      # orta
    ((15, 6), [(32, 20), (25, 27), (14, 26)], (5, 14)),       # asagi
    ((18, -3), [(38, -10), (43, 3), (34, 13)], (5, 13)),      # orta (donus)
]
BOB = [0, -1, 1, 0]


def bat_front(phase, back=False):
    cv = Canvas()
    bob = BOB[phase] + (BODY_Y - 44)
    wrist_o, tips_o, attach_o = FRONT_FLAP[phase]
    for side in (-1, 1):
        sh = (48 + side * 6, 37 + bob)
        wrist = (sh[0] + side * wrist_o[0], sh[1] + wrist_o[1])
        tips = [(sh[0] + side * t[0], sh[1] + t[1]) for t in tips_o]
        attach = (sh[0] + side * attach_o[0], sh[1] + attach_o[1])
        draw_wing(cv, sh, wrist, tips, attach, far=back)
    body = cv.mask_ellipse(48, 45 + bob, 9, 11)
    shade_fur(cv, body)
    head = cv.mask_ellipse(48, 30 + bob, 9.5, 8)
    ears = cv.mask_poly([(40, 27 + bob), (37, 14 + bob), (45, 23 + bob)]) | cv.mask_poly([(56, 27 + bob), (59, 14 + bob), (51, 23 + bob)])
    shade_fur(cv, ears | head)
    for side in (-1, 1):  # ayaklar
        cv.p[(48 + side * 3, 56 + bob)] = FUR[1]
        cv.p[(48 + side * 3, 57 + bob)] = CLAW
        cv.p[(48 + side * 4, 57 + bob)] = CLAW
    if not back:
        for p in cv.mask_poly([(40, 25 + bob), (38, 17 + bob), (43, 23 + bob)]) | cv.mask_poly([(56, 25 + bob), (58, 17 + bob), (53, 23 + bob)]):
            cv.p[p] = EAR_IN
        # gogus tuyu (acik V) + karin
        for i in range(5):
            cv.p[(46 - i // 2, 38 + bob + i)] = FUR[3]
            cv.p[(50 + i // 2, 38 + bob + i)] = FUR[3]
        # gozler
        for ex in (44, 51):
            for dy in range(2):
                for dx in range(2):
                    cv.p[(ex + dx, 29 + bob + dy)] = EYE
            cv.p[(ex, 29 + bob)] = EYE_H
            cv.p[(ex + 1, 31 + bob)] = EYE_D
        # burun + agiz + disler
        cv.p[(47, 33 + bob)] = FUR[0]
        cv.p[(48, 33 + bob)] = FUR[0]
        for x in range(45, 51):
            cv.p[(x, 35 + bob)] = FUR[0]
        cv.p[(46, 36 + bob)] = FANG
        cv.p[(46, 37 + bob)] = FANG
        cv.p[(50, 36 + bob)] = FANG
        cv.p[(50, 37 + bob)] = FANG
    else:
        # sirt: omurga cizgisi + kulak arkasi koyu
        for y in range(36, 53):
            cv.p[(48, y + bob)] = FUR[0]
        for p in ears:
            if p in cv.p and cv.p[p] == FUR[3]:
                cv.p[p] = FUR[2]
    return cv.image()


SIDE_FLAP = [
    ((-7, -17), [(-22, -29), (-31, -18), (-28, -5)], (-6, 9)),
    ((-14, -7), [(-32, -12), (-37, 0), (-27, 9)], (-6, 9)),
    ((-10, 7), [(-25, 19), (-17, 25), (-7, 22)], (-4, 10)),
    ((-13, -5), [(-31, -9), (-36, 2), (-26, 11)], (-6, 9)),
]


def bat_side(phase):
    """Saga bakan profil: uzak kanat govdenin arkasinda (koyu), yakin kanat onde."""
    cv = Canvas()
    bob = BOB[phase] + (BODY_Y - 44)
    wrist_o, tips_o, attach_o = SIDE_FLAP[phase]

    def wing(off, far):
        sh = (50 + off[0], 38 + bob + off[1])
        draw_wing(cv, sh, (sh[0] + wrist_o[0], sh[1] + wrist_o[1]), [(sh[0] + t[0], sh[1] + t[1]) for t in tips_o],
                  (sh[0] + attach_o[0], sh[1] + attach_o[1]), far=far)

    wing((5, -2), True)
    tail = cv.mask_poly([(36, 44 + bob), (29, 50 + bob), (37, 50 + bob)])
    for p in tail:
        cv.p[p] = MEM[1]
    body = cv.mask_ellipse(46, 45 + bob, 12, 8.5)
    shade_fur(cv, body)
    head = cv.mask_ellipse(59, 37 + bob, 8, 7)
    ear = cv.mask_poly([(55, 33 + bob), (58, 21 + bob), (62, 31 + bob)])
    snout = cv.mask_poly([(63, 35 + bob), (69, 38 + bob), (63, 41 + bob)])
    shade_fur(cv, head | ear | snout)
    for p in cv.mask_poly([(57, 31 + bob), (58, 25 + bob), (60, 31 + bob)]):
        cv.p[p] = EAR_IN
    cv.p[(63, 35 + bob)] = EYE
    cv.p[(64, 35 + bob)] = EYE
    cv.p[(63, 34 + bob)] = EYE_H
    cv.p[(64, 36 + bob)] = EYE_D
    cv.p[(69, 38 + bob)] = FUR[0]
    cv.p[(66, 41 + bob)] = FANG
    cv.p[(66, 42 + bob)] = FANG
    for x in range(61, 68):
        cv.p[(x, 40 + bob)] = FUR[0]
    for dx in (0, 5):  # toplanmis ayaklar
        cv.p[(42 + dx, 54 + bob)] = FUR[1]
        cv.p[(42 + dx, 55 + bob)] = CLAW
    wing((0, 0), False)
    return cv.image()


def center_frames(frames):
    """4 karenin BIRLESIK kutusuna gore yatayda ortala (kareler arasi titreme olmasin)."""
    box = None
    for f in frames:
        b = f.getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    dx = int(round(CELL_W / 2 - (box[0] + box[2]) / 2))
    out = []
    for f in frames:
        g = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
        g.paste(f, (dx, 0), f)
        out.append(g)
    return out


def build():
    rows = {}
    rows["down"] = center_frames([bat_front(p) for p in range(4)])
    rows["up"] = center_frames([bat_front(p, back=True) for p in range(4)])
    rows["right"] = center_frames([bat_side(p) for p in range(4)])
    rows["left"] = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in rows["right"]]
    sheet = Image.new("RGBA", (CELL_W * 4, CELL_H * 4), (0, 0, 0, 0))
    for r, d in enumerate(DIRS):
        for c, f in enumerate(rows[d]):
            sheet.paste(f, (c * CELL_W, r * CELL_H), f)
    return sheet, rows


def write_sheet():
    sheet, _rows = build()
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    sheet.save(OUT_PATH)
    print("wrote", OUT_PATH, sheet.size)
    return sheet


def main():
    sheet = write_sheet()
    if len(sys.argv) > 1:
        S = 3
        prev = Image.new("RGBA", (CELL_W * S * 4 + 50, CELL_H * S * 4 + 50), (58, 72, 52, 255))
        prev.alpha_composite(sheet.resize((CELL_W * 4 * S, CELL_H * 4 * S), Image.NEAREST), (10, 10))
        prev.save(sys.argv[1])
        print("preview ->", sys.argv[1])


if __name__ == "__main__":
    main()
