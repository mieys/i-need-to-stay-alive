"""Korsan Saatli Bomba spritesheet'i - kullanicinin 32x32 bomba cizimi (assets/fx/korsan/bomb_source.png) + fitil ucunda
canli kivilcim (2026-11-13, kullanici istegi: "korsanin bombalarini bununla degistir, bomba ipinin ucuna da efekt ekle").

Eskiden bomba gen_korsan_fx_sprites.py'de ASCII kuru kafali bomba olarak ciziliyordu; artik bomba bolumu BU betikte,
o betik bomb_sheet'e dokunmaz. Cikti: assets/fx/korsan/bomb_sheet.png + bomb_frames.tres ("drop" tek sefer, "idle" dongu).

Olcek: 1 kaynak pikseli = korsan_bomb.gd WORLD_TEXEL dunya birimi (0.65 -> govde ~16 birim, eski bomba kadar). Karakter
pikseli (0.90) bombayi neredeyse Korsan boyunda yapiyordu. Kivilcim kivilcik/kor parcaciklari 1 px'te cimende kayboluyor
(hafiza: asa partikulleri) - korlar 2x2 dogar, sonunda 1 px'e iner.

Kare duzeni: node orijini = bomba govdesinin merkezi; betik sonunda yazdirilan SHEET_OFFSET'i korsan_bomb.gd'ye koy.
Calistir: python tools/gen_korsan_bomb_sprite.py  (sonra Godot --headless --path . --import)
"""
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "korsan")
SRC = os.path.join(OUT, "bomb_source.png")
WORLD_TEXEL = 0.65  # korsan_bomb.gd WORLD_TEXEL ile AYNI olmali

# kaynak resimde (32x32) govde merkezi ve fitil ucu
BODY_C = (14.5, 18.5)
FUSE_TIP = (29.5, 2.5)
BODY_BOTTOM = 30

W, H = 56, 112
MARGIN_X = 10  # kaynak resmin karedeki sol kenari
GROUND_Y = H - 6  # golge merkezi (lift=0)
SRC_Y0 = GROUND_Y - 3 - BODY_BOTTOM  # lift=0'da kaynak resmin ust kenari (govde alti golgenin 3 px ustunde)


def rgba(r, g, b, a=1.0):
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)), int(round(a * 255)))


def put(im, x, y, c):
    x, y = int(math.floor(x)), int(math.floor(y))
    if not (0 <= x < im.width and 0 <= y < im.height) or c[3] <= 0:
        return
    if c[3] >= 255:
        im.putpixel((x, y), c)
        return
    base = im.getpixel((x, y))
    a = c[3] / 255.0
    ba = base[3] / 255.0
    oa = a + ba * (1 - a)
    mix = [int(round((c[i] * a + base[i] * ba * (1 - a)) / oa)) for i in range(3)]
    im.putpixel((x, y), (mix[0], mix[1], mix[2], int(round(oa * 255))))


# kivilcim paleti: sicak beyaz -> sari -> turuncu -> kizil -> koyu kor
SPARK = [rgba(1.0, 0.98, 0.86), rgba(1.0, 0.88, 0.4), rgba(1.0, 0.62, 0.16), rgba(0.9, 0.3, 0.08), rgba(0.5, 0.12, 0.06)]
N_LOOP = 12  # idle dongusu (14 fps)


def make_embers(seed):
    """Dongusel kor listesi: (dogum karesi, omur, vx, vy). Kareye cizerken dogum % N_LOOP sarilir -> kusursuz dongu."""
    rnd = random.Random(seed)
    out = []
    for i in range(N_LOOP * 2):  # ~2 kor / kare
        birth = i * N_LOOP / (N_LOOP * 2) + rnd.uniform(-0.3, 0.3)
        a = rnd.uniform(-math.pi * 0.95, -math.pi * 0.05)  # yukari yarim daire, saga hafif egilim asagida
        sp = rnd.uniform(1.2, 2.4)
        out.append((birth, rnd.randint(4, 6), math.cos(a) * sp + 0.35, math.sin(a) * sp))
    return out


EMBERS = make_embers(23)


def draw_spark(im, tx, ty, phase, t):
    """Fitil ucu: nefes alan sicak hale + titresen cekirdek + ucusan korlar. phase 0..N_LOOP-1, t = dongu karesi."""
    breathe = 0.5 + 0.5 * math.sin(phase / N_LOOP * math.tau * 3)
    # yumusak hale (dairesel alfa)
    hr = 4.5 + 1.5 * breathe
    for dy in range(-6, 7):
        for dx in range(-6, 7):
            d = math.hypot(dx + 0.5 - (tx % 1), dy + 0.5 - (ty % 1))
            if d <= hr:
                k = 1.0 - d / hr
                put(im, tx + dx, ty + dy, rgba(1.0, 0.66, 0.2, 0.12 + 0.5 * k * k))
    # korlar (cekirdegin altinda kalsin diye once)
    for birth, life, vx, vy in EMBERS:
        age = (t - birth) % N_LOOP
        if age >= life:
            continue
        x = tx + vx * age
        y = ty + vy * age + 0.18 * age * age  # hafif yercekimi
        c = SPARK[min(4, 1 + int(age / life * 4))]
        put(im, x, y, c)
        if age < life * 0.5:  # genc kor 2x2
            put(im, x + 1, y, c)
            put(im, x, y + 1, c)
            put(im, x + 1, y + 1, c)
    # cekirdek: 4 farkli titresim sekli
    cx, cy = int(math.floor(tx)), int(math.floor(ty))
    shape = phase % 4
    if shape == 0:  # arti
        pts = [((0, 0), 0), ((1, 0), 0), ((0, 1), 0), ((1, 1), 1), ((-1, 0), 1), ((2, 1), 1), ((0, -1), 1), ((1, 2), 1),
               ((-2, 0), 2), ((3, 1), 2), ((0, -2), 2), ((1, 3), 2)]
    elif shape == 1:  # capraz yildiz
        pts = [((0, 0), 0), ((1, 0), 0), ((0, 1), 1), ((1, 1), 0), ((-1, -1), 1), ((2, -1), 1), ((-1, 2), 1), ((2, 2), 1),
               ((-2, -2), 2), ((3, -2), 2), ((-2, 3), 2), ((3, 3), 2)]
    elif shape == 2:  # buyuk patlak
        pts = [((0, 0), 0), ((1, 0), 0), ((0, 1), 0), ((1, 1), 0), ((-1, 0), 1), ((2, 0), 1), ((-1, 1), 1), ((2, 1), 1),
               ((0, -1), 1), ((1, -1), 1), ((0, 2), 1), ((1, 2), 1), ((-2, -1), 2), ((3, -1), 2), ((0, -3), 2), ((1, -3), 3),
               ((-2, 2), 2), ((3, 2), 2)]
    else:  # sonuk titresim
        pts = [((0, 0), 1), ((1, 0), 0), ((1, 1), 1), ((0, 1), 2), ((1, -1), 2), ((2, 0), 2)]
    for (ox, oy), ci in pts:
        put(im, cx + ox, cy + oy, SPARK[ci])


def bomb_frame(src, lift, phase, t):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # golge: yukseldikce kuculur, sert kenarli iki tonlu elips
    shrink = 1.0 - min(0.45, lift / 60.0)
    rx, ry = 11.0 * shrink, 3.2 * shrink
    gx = MARGIN_X + BODY_C[0]
    for dy in range(-5, 6):
        for dx in range(-14, 15):
            if (dx / rx) ** 2 + (dy / ry) ** 2 <= 1.0:
                core = (dx / (rx * 0.62)) ** 2 + (dy / (ry * 0.62)) ** 2 <= 1.0
                put(im, gx + dx, GROUND_Y + dy, rgba(0, 0, 0, 0.36 if core else 0.24))
    y0 = SRC_Y0 - int(round(lift))
    im.alpha_composite(src, (MARGIN_X, y0))
    draw_spark(im, MARGIN_X + FUSE_TIP[0], y0 + FUSE_TIP[1], phase, t)
    return im


def main():
    src = Image.open(SRC).convert("RGBA")
    assert src.size == (32, 32), src.size
    drop_time, bounce_time = 0.28, 0.16
    drop = []
    n_drop = 7
    for i in range(n_drop):
        life = i / (n_drop - 1) * (drop_time + bounce_time)
        if life < drop_time:
            k = 1.0 - life / drop_time
            lift = k * k * 34.0
        else:
            b = (life - drop_time) / bounce_time
            lift = math.sin(b * math.pi) * 5.0
        drop.append(bomb_frame(src, lift / WORLD_TEXEL, i, i))
    idle = [bomb_frame(src, 0, i, i) for i in range(N_LOOP)]
    frames = drop + idle
    sheet = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * W, 0))  # maskesiz: maskeli paste yari saydam hale/golge alfasini ikinci kez carpiyordu
    sheet.save(os.path.join(OUT, "bomb_sheet.png"))
    tres = os.path.join(OUT, "bomb_frames.tres")
    write_sprite_frames(tres, "res://assets/fx/korsan/bomb_sheet.png", W, H,
                        [("drop", (0, 0), len(drop), False, len(drop) / 0.44),
                         ("idle", (len(drop), 0), len(idle), True, 14.0)])
    # eski uid'leri koru (sahneler yol ile preload ediyor ama editor uid'i de tutuyor)
    txt = open(tres, encoding="utf-8").read()
    txt = txt.replace('[gd_resource type="SpriteFrames" format=3]',
                      '[gd_resource type="SpriteFrames" format=3 uid="uid://b8ok8x60ruv1b"]', 1)
    txt = txt.replace('[ext_resource type="Texture2D" path=', '[ext_resource type="Texture2D" uid="uid://cydqyrer0ehxn" path=', 1)
    open(tres, "w", encoding="utf-8", newline="\n").write(txt)
    # node orijini = lift 0'da govde merkezi
    bx, by = MARGIN_X + BODY_C[0], SRC_Y0 + BODY_C[1]
    print("sheet", sheet.size, "cell", (W, H), "SHEET_OFFSET = Vector2(%.1f, %.1f)" % (W / 2 - bx, H / 2 - by))


if __name__ == "__main__":
    main()
