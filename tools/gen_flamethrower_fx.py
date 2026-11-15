# -*- coding: utf-8 -*-
# Ateş Asası "FLAMETHROWER" püskürtmesi (madde 639, 2026-11-13): kullanıcının "Pixel FX FIRE VER 1.0" paketindeki
# "Flamethrower Left_Right.gif" (193x69, 23 kare, 60 ms) oyuna pişirilir. Kaynak kopyası: tools/flamethrower/.
#   Kare 0-5  -> "start" (alev ağızdan uzar, döngüsüz)
#   Kare 6-17 -> "loop"  (tam alev, dikişsiz döngü)
#   Kare 18-22 -> "end"  (alev kopup söner, döngüsüz)
# Arka plan rengi (34,32,52) saydam olur; çizim/renkler AYNEN (6 renk). Buz dalı (eski kapalı "Destiny" efsunu) paketin
# kendi "Blue Fire Palette"i ile renk renk eşlenir.
# Çıktı: assets/fx/enchant/flamethrower_{fire,ice}_sheet.png + _frames.tres (fx_enchant_sprite), ve HASAR ALANI profili
# scripts/weapon_traits/flamethrower_shape.gd (alevin gerçek şekli: ağızda ince hat, uçta yukarı kabaran ateş bulutu).
# Çalıştır: python -I tools/gen_flamethrower_fx.py
import os
import sys
from statistics import median

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "flamethrower", "Flamethrower_Left_Right.gif")
OUT = os.path.join(ROOT, "assets", "fx", "enchant")
SHAPE = os.path.join(ROOT, "scripts", "weapon_traits", "flamethrower_shape.gd")
RES = "res://assets/fx/enchant/"
BG = (34, 32, 52)
FPS = 1000.0 / 60.0
ANIMS = [("start", range(0, 6), False), ("loop", range(6, 18), True), ("end", range(18, 23), False)]
COLS = 6
STEP = 4  # profil örnekleme aralığı (sanat px)
ICE = {
    (255, 255, 186): (206, 255, 255), (248, 215, 81): (41, 231, 255), (241, 148, 0): (0, 173, 255),
    (215, 92, 8): (0, 132, 255), (189, 18, 25): (0, 74, 255), (133, 12, 27): (0, 24, 181),
}


def load_frames():
    im = Image.open(SRC)
    frames = []
    for i in range(im.n_frames):
        im.seek(i)
        fr = im.convert("RGBA")
        px = fr.load()
        w, h = fr.size
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if (r, g, b) == BG:
                    px[x, y] = (0, 0, 0, 0)
        frames.append(fr)
    return frames


def nozzle(frames):
    """Döngü karelerinde en soldaki opak pikselin konumu = alevin çıktığı ağız."""
    fr = frames[6]
    px = fr.load()
    w, h = fr.size
    for x in range(w):
        ys = [y for y in range(h) if px[x, y][3] > 0]
        if ys:
            return x, int(round(median(ys)))
    raise SystemExit("ağız bulunamadı")


def write_tres(name, cw, ch, n):
    lines = ['[gd_resource type="SpriteFrames" format=3]', "",
             '[ext_resource type="Texture2D" path="%s%s_sheet.png" id="1"]' % (RES, name), ""]
    for i in range(n):
        lines += ['[sub_resource type="AtlasTexture" id="AT_%d"]' % i, 'atlas = ExtResource("1")',
                  "region = Rect2(%d, %d, %d, %d)" % ((i % COLS) * cw, (i // COLS) * ch, cw, ch), ""]
    anims = []
    for aname, idx, loop in ANIMS:
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("AT_%d")\n}' % i for i in idx)
        anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.4f\n}'
                     % (fr, "true" if loop else "false", aname, FPS))
    lines += ["[resource]", "animations = [%s]" % ", ".join(anims), ""]
    with open(os.path.join(OUT, name + "_frames.tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def save_sheet(name, frames, box):
    x0, y0, x1, y1 = box
    cw, ch = x1 - x0, y1 - y0
    rows = (len(frames) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (cw * COLS, ch * rows), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.crop(box), ((i % COLS) * cw, (i // COLS) * ch))
    sheet.save(os.path.join(OUT, name + "_sheet.png"))
    write_tres(name, cw, ch, len(frames))


def recolor(fr, table):
    out = fr.copy()
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0:
                nr, ng, nb = table.get((r, g, b), (r, g, b))
                px[x, y] = (nr, ng, nb, a)
    return out


def column_extent(fr, x, ny):
    """x sütunundaki opak piksellerin ağız çizgisine göre [üst, alt] (y aşağı +). Boş sütun = None."""
    px = fr.load()
    ys = [y for y in range(fr.size[1]) if px[x, y][3] > 0]
    if not ys:
        return None
    return (min(ys) - ny, max(ys) - ny)


def reach(fr, nx):
    px = fr.load()
    w, h = fr.size
    for x in range(w - 1, -1, -1):
        if any(px[x, y][3] > 0 for y in range(h)):
            return x - nx + 1
    return 0


def main():
    frames = load_frames()
    nx, ny = nozzle(frames)
    # Tüm karelerin birleşik sınırı (ağız sol kenarda kalır).
    xs0, ys0, xs1, ys1 = [], [], [], []
    for fr in frames:
        b = fr.getbbox()
        if b:
            xs0.append(b[0]); ys0.append(b[1]); xs1.append(b[2]); ys1.append(b[3])
    box = (min(min(xs0), nx), min(ys0), max(xs1), max(ys1))
    save_sheet("flamethrower_fire", frames, box)
    save_sheet("flamethrower_ice", [recolor(f, ICE) for f in frames], box)
    cw, ch = box[2] - box[0], box[3] - box[1]
    # Ortalı AnimatedSprite2D: ağız düğüm noktasına otursun (sanat px).
    off_x = cw / 2.0 - (nx - box[0])
    off_y = ch / 2.0 - (ny - box[1])

    loop = frames[6:18]
    length = int(round(median(reach(f, nx) for f in loop)))
    # Profil: her STEP px'lik dilimde döngü karelerinin MEDYAN üst/alt sınırı (dalgalanan dillerin ortalaması).
    prof = []
    for s in range(0, length + 1, STEP):
        tops, bots = [], []
        for fr in loop:
            t_, b_ = 0, 0
            got = False
            for x in range(nx + s, min(nx + s + STEP, fr.size[0])):
                e = column_extent(fr, x, ny)
                if e:
                    t_ = min(t_, e[0]) if got else e[0]
                    b_ = max(b_, e[1]) if got else e[1]
                    got = True
            if got:
                tops.append(t_); bots.append(b_)
            else:
                tops.append(0); bots.append(0)
        prof.append((float(median(tops)), float(median(bots))))
    intro = [reach(f, nx) for f in frames[0:6]]
    outro_from = []
    for fr in frames[18:23]:
        b = fr.getbbox()
        outro_from.append((b[0] - nx) if b else length)

    with open(SHAPE, "w", encoding="utf-8", newline="\n") as f:
        f.write('extends RefCounted\n\n')
        f.write('## OTOMATİK ÜRETİLDİ: tools/gen_flamethrower_fx.py (elle düzenleme - üreteci çalıştır). Madde 639.\n')
        f.write('## Ateş Asası alevinin (kullanıcının "Flamethrower Left_Right" efekti) HASAR ALANI = çizilen alevin şekli.\n')
        f.write('## Birimler SANAT pikseli, ağız (0,0), alev +x yönüne; y aşağı + (sayfadaki gibi: ateş bulutu YUKARI kabarır, y < 0).\n')
        f.write('## Sola bakarken sayfa dikey aynalanır (fx_enchant_sprite "flip_left") -> hasar alanında y işareti de döner.\n\n')
        f.write('const LENGTH := %d.0 ## döngü karelerinde alevin medyan boyu\n' % length)
        f.write('const STEP := %d.0 ## PROFILE örnek aralığı\n' % STEP)
        f.write('## Her STEP px dilimin [üst, alt] sınırı (döngü karelerinin medyanı)\n')
        f.write('const PROFILE := [%s]\n' % ", ".join("Vector2(%.1f, %.1f)" % p for p in prof))
        f.write('## "start" animasyonunun her karesinde alevin ulaştığı boy (alan alevle birlikte uzar)\n')
        f.write('const INTRO_REACH := [%s]\n' % ", ".join("%d.0" % r for r in intro))
        f.write('const FPS := %.4f\n' % FPS)
        f.write('const SHEET_OFFSET := Vector2(%.1f, %.1f) ## ortalı sprite ofseti: ağız düğüm noktasında\n\n\n' % (off_x, off_y))
        f.write('## Alevin ağızdan x uzaklığındaki [üst, alt] sınırı (sanat px; x alan dışındaysa boş aralık).\n')
        f.write('static func band_at(x: float) -> Vector2:\n')
        f.write('\tif x < 0.0 or x > LENGTH:\n\t\treturn Vector2(1.0, -1.0)\n')
        f.write('\tvar i: int = clampi(int(x / STEP), 0, PROFILE.size() - 1)\n')
        f.write('\treturn PROFILE[i]\n\n\n')
        f.write('## Başlangıç animasyonunda geçen süreye göre alevin ulaştığı boy (sanat px).\n')
        f.write('static func reach_at(t: float) -> float:\n')
        f.write('\tvar i: int = int(t * FPS)\n')
        f.write('\tif i >= INTRO_REACH.size():\n\t\treturn LENGTH\n')
        f.write('\treturn minf(LENGTH, float(INTRO_REACH[maxi(0, i)]))\n')
    print("hücre", cw, "x", ch, "ağız", nx - box[0], ny - box[1], "ofset", off_x, off_y, "boy", length)
    print("profil", prof)
    print("giriş", intro, "çıkış başı", outro_from)


if __name__ == "__main__":
    sys.exit(main())
