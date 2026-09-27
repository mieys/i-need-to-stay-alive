#!/usr/bin/env python3
"""Korsan pasifi "Papağan" - sprite sayfası + pasif ikonu.

Çalıştır (repo kökünden):  python tools/gen_korsan_parrot.py      (sonra Godot'ta `--headless --import`)

Kullanıcı isteği (2026-09-26): "korsanın pasifini değiştiriyoruz ... Papağanı korsanın omzunda durur ve etrafta altın
varsa uçarak altını alarak korsanın omzuna tekrar geri döner ... Topladığı altını ayağının altında tutarak korsana getirir.
Papağan için 48x48 pixel sanatında korsanın omzunda aşırı küçük veya büyük durmayacak bir papağan tasarlaman gerekiyor.
bunu spritesheet olarak yap ki performans kaybı yaşanmasın."

Çıktı:
  assets/characters/korsan_parrot/parrot_sheet.png + parrot_frames.tres (48x48 hücreler, TEK doku):
    "perch" 4 kare (omuzda: nefes/baş eğme/göz kırpma, 4 fps döngü), "fly" 4 kare (kanat yukarı-orta-aşağı-orta, 12 fps
    döngü), "coins" 3 kare (ayağın altında 1/2/3 altın - hız 0, kare elle seçilir, scripts/korsan_parrot.gd).
  assets/skills/korsan_papagan_icon.png (48x48 kare ikon, gen_elara_korsan_icons.py'nin zemin/kontur kiti).

Boyut kuralı: papağan Korsan'ın KENDİ sanat pikseli yoğunluğunda çizilir (oyunda aynı ölçekle - korsan_parrot.gd
karakterin sprite ölçeğini kopyalar). Omuzdayken ~10x15 px (Korsan'ın kafası ~10-12 px; ilk denemedeki 12x18 kafayı/şapkayı
kapatıyordu), uçarken gövde ~19 px.
Hepsi 48x48 hücrede; AYAK noktası (tünediği / altını tuttuğu yer) her karede hücrenin (24, 30) pikselinde - script
sprite'ı bu noktaya hizalar.
Renk: kızıl ara papağanı (kırmızı gövde, sarı-mavi kanat, beyaz yüz, fildişi/siyah gaga) - Korsan'ın lacivert/beyaz
kıyafetinden ve yeşil çimden ayrışır.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "characters", "korsan_parrot")
CELL = 48
ANCHOR = (24, 30)  # ayak noktası (tünek / taşınan altının üst kenarı)


def hexc(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


PAL = {
    'o': hexc('#2a1618'),  # kontur (koyu kahve-bordo, siyah değil)
    'R': hexc('#d83a2c'),  # kırmızı
    'r': hexc('#9e2424'),  # koyu kırmızı (gölge)
    'h': hexc('#f26a4c'),  # kırmızı ışık
    'Y': hexc('#f2c23a'),  # sarı
    'y': hexc('#c08a1e'),  # koyu sarı
    'B': hexc('#3b78d8'),  # mavi
    'b': hexc('#244c9a'),  # koyu mavi
    'W': hexc('#f4efe4'),  # yüz
    'E': hexc('#140c0c'),  # göz
    'I': hexc('#eadcbc'),  # gaga (üst, fildişi)
    'D': hexc('#3a3032'),  # gaga (alt, koyu)
    'F': hexc('#7c706a'),  # ayak
    'C': hexc('#f2c142'),  # altın
    'c': hexc('#a8761e'),  # altın gölge/kontur
    'L': hexc('#fff2a8'),  # altın parlama
}

# ---------------------------------------------------------------- omuzda (sağa bakan profil)
# 'X' = ayak noktası işareti (çizilmez; hizalama için). Satırlar eşit uzunlukta olmak zorunda değil.
PERCH = [
    "...ooo....",
    "..ohRRo...",
    ".ohRRWWo..",
    ".oRRWEWIo.",
    ".oRRRWoIIo",
    ".orRRRoDo.",
    "orRRRRRo..",
    "oYYRRRRo..",
    "oBYYRRro..",
    "obBBYRro..",
    ".obBBrro..",
    ".oobboFoF.",
    "..obBo.X..",
    "..obo.....",
    "...o......",
]
PERCH_BODY_ROWS = 11  # nefes karesinde 1 px çöken üst kısım (ayak/kuyruk satırları sabit)

# ---------------------------------------------------------------- uçarken gövde (sağa bakan, yatay)
FLY_BODY = [
    "............oooo...",
    "...........ohRRRo..",
    "..........ohRRRWWo.",
    "oo.......oRRRRWWEWo",
    "oBoo...ooRRRRRWWIIIo",
    "obBBooRRRRRRRRRoDIo.",
    ".obBBBRRRRRRRRRooo..",
    "..oobbBRRRRRRro.....",
    ".....oooRRRrooo.....",
    "........oFoFo.......",
    ".........X..........",
]
BODY_SHOULDER = (10, 5)  # kanadın gövdeye bağlandığı nokta (FLY_BODY içinde)

WING_UP = [  # sağ-alt köşesi omza oturur
    "oo......",
    "oBBo....",
    "obBBo...",
    ".obBYo..",
    "..obBYo.",
    "...obYRo",
    "....oYRo",
    ".....oRo",
]
WING_MID = [  # sağ ucu omza oturur (geriye yatay)
    "..ooooooo...",
    "ooBBBYYYRRo.",
    "obbBBBBYYRRo",
    ".ooooooooooo",
]
WING_DOWN = [  # sağ-üst köşesi omza oturur
    ".....oRo",
    "....oYRo",
    "...obYRo",
    "..obBYo.",
    ".obBBo..",
    "obBBo...",
    "obbo....",
    "ooo.....",
]

COINS = [
    [".ccc.", "cLCCc", "cCCCc", "cCCyc", ".ccc."],
    [".ccc...", "cLCCc..", "cCC.ccc", "cCcLCCc", ".ccCCCc", "...cCyc", "....ccc"],
    ["..ccc..", ".cLCCc.", "ccCCCcc", "LCCcLCC", "CCyccCC", "Cyc.cCy", "cc...cc"],
]


def draw(im, grid, ox, oy):
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch in PAL:
                im.putpixel((ox + x, oy + y), PAL[ch])


def find(grid, mark='X'):
    for y, row in enumerate(grid):
        x = row.find(mark)
        if x >= 0:
            return x, y
    raise ValueError('mark yok')


def cell():
    return Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))


def perch_frames():
    fx, fy = find(PERCH)
    ox, oy = ANCHOR[0] - fx, ANCHOR[1] - fy
    frames = []
    # 0: temel, 1: gövde 1 px çöker (nefes), 2: temel, 3: göz kırpma
    for i in range(4):
        im = cell()
        grid = [row for row in PERCH]
        if i == 3:
            grid = [row.replace('E', 'o') for row in grid]
        if i == 1:
            # ayaklar/kuyruk yerinde, üst gövde 1 px aşağı
            top = grid[:PERCH_BODY_ROWS]
            bottom = grid[PERCH_BODY_ROWS:]
            draw(im, top, ox, oy + 1)
            draw(im, bottom, ox, oy + PERCH_BODY_ROWS)
        else:
            draw(im, grid, ox, oy)
        frames.append(im)
    return frames


def fly_frames():
    fx, fy = find(FLY_BODY)
    ox, oy = ANCHOR[0] - fx, ANCHOR[1] - fy
    sx, sy = ox + BODY_SHOULDER[0], oy + BODY_SHOULDER[1]
    frames = []
    for wing in (WING_UP, WING_MID, WING_DOWN, WING_MID):
        im = cell()
        draw(im, FLY_BODY, ox, oy)
        w = max(len(r) for r in wing)
        h = len(wing)
        if wing is WING_UP:
            draw(im, wing, sx - w + 1, sy - h + 1)
        elif wing is WING_MID:
            draw(im, wing, sx - w + 1, sy - 1)
        else:
            draw(im, wing, sx - w + 1, sy)
        frames.append(im)
    return frames


def coin_frames():
    frames = []
    for g in COINS:
        im = cell()
        w = max(len(r) for r in g)
        draw(im, g, ANCHOR[0] - w // 2, ANCHOR[1])
        frames.append(im)
    return frames


def save_sheet(frames, path):
    sheet = Image.new("RGBA", (CELL * len(frames), CELL), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * CELL, 0))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.save(path)
    print("wrote", os.path.relpath(path, ROOT), sheet.size)


def res(path):
    return "res://" + os.path.relpath(path, ROOT).replace("\\", "/")


def build_sheet():
    frames = perch_frames() + fly_frames() + coin_frames()
    png = os.path.join(OUT, "parrot_sheet.png")
    save_sheet(frames, png)
    write_sprite_frames(os.path.join(OUT, "parrot_frames.tres"), res(png), CELL, CELL, [
        ("perch", (0, 0), 4, True, 4.0),
        ("fly", (4, 0), 4, True, 12.0),
        ("coins", (8, 0), 3, False, 0.0),
    ])


def build_icon():
    """Pasif ikonu: gen_elara_korsan_icons.py'nin kare zemin/kontur kiti (eski altın ikonuyla aynı deniz yeşili zemin),
    üstünde sağa bakan kızıl ara papağanı pençesinde bir altınla. 48x48, 1 piksel detay, 3x NEAREST."""
    import gen_elara_korsan_icons as ik
    from PIL import ImageDraw
    C = ik.C
    base = ik.tile(C('#1e6a72'), C('#082628'), C('#2e8a88'), C('#5ab8b0'), C('#041416'))
    e = ik.canvas()
    d = ImageDraw.Draw(e)
    RED, RED_D, RED_H = C('#d83a2c'), C('#9e2424'), C('#f26a4c')
    YEL, BLU, BLU_D = C('#f2c23a'), C('#3b78d8'), C('#244c9a')
    WHT, IVO, DRK, EYE, FOOT = C('#f4efe4'), C('#eadcbc'), C('#3a3032'), C('#140c0c'), C('#7c706a')
    # kuyruk (sol-aşağı, arkada)
    d.polygon([(15, 31), (20, 33), (12, 45), (7, 45)], fill=BLU_D)
    d.polygon([(16, 31), (19, 32), (11, 44), (9, 44)], fill=BLU)
    d.line((13, 38, 11, 42), fill=RED)
    # gövde
    d.ellipse((13, 15, 31, 37), fill=RED)
    d.ellipse((14, 16, 26, 30), fill=RED_H)
    d.ellipse((15, 17, 30, 36), fill=RED)
    # kanat: kırmızı omuz, sarı bant, mavi uç tüyleri
    d.polygon([(14, 21), (24, 22), (27, 31), (19, 38), (12, 34)], fill=RED_D)
    d.polygon([(14, 25), (25, 25), (26, 30), (13, 30)], fill=YEL)
    d.polygon([(13, 30), (26, 30), (21, 38), (12, 36)], fill=BLU)
    for x0 in (15, 18, 21):
        d.line((x0, 31, x0 - 2, 37), fill=BLU_D)
    # baş
    d.ellipse((21, 5, 37, 21), fill=RED)
    d.ellipse((22, 6, 30, 12), fill=RED_H)
    d.ellipse((28, 9, 38, 19), fill=WHT)          # yüz
    ik.put(e, [(31, 12), (32, 12), (31, 13), (32, 13)], EYE)
    ik.put(e, [(31, 12)], C('#ffffff'))
    # gaga: fildişi üst çene kancalı, koyu alt çene
    d.polygon([(36, 10), (41, 12), (42, 16), (40, 20), (38, 17), (35, 16)], fill=IVO)
    d.polygon([(35, 16), (38, 17), (39, 20), (36, 20)], fill=DRK)
    ik.put(e, [(41, 13), (41, 14)], C('#fff8e6'))
    # ayaklar + pençedeki altın
    COIN_R, COIN_F, COIN_I, COIN_H = C('#a86c14'), C('#f0bc3c'), C('#d49a28'), C('#fff0a8')
    d.ellipse((21, 37, 33, 47), fill=COIN_R)
    d.ellipse((22, 38, 32, 46), fill=COIN_F)
    d.ellipse((24, 40, 30, 44), fill=COIN_I)
    d.arc((22, 38, 32, 46), start=200, end=260, fill=COIN_H, width=1)
    for fx0 in (24, 29):
        d.line((fx0, 35, fx0, 39), fill=FOOT)
        ik.put(e, [(fx0 - 1, 39), (fx0 + 1, 39)], FOOT)
    fx = ik.canvas()
    ik.sparkle(fx, 40, 29, C('#ffffff'), C('#fff0a8'), 2)
    ik.sparkle(fx, 7, 9, C('#ffffff'), C('#ffe08a'), 1)
    ik.finish(base, e, fx, "korsan_papagan_icon.png")


if __name__ == "__main__":
    build_sheet()
    build_icon()
