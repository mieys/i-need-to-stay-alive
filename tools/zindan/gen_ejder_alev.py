# EJDER BAŞI UZUN ALEV sayfası (madde 492, kullanıcı: "duvardan ateş çıkaran tuzakların daha uzun bir çizgide ateş atması lazım").
# Eski sayfa (runtime/dragon_trap.png, 32 x 80 = baş + 3 hücre alev) yerine: 32 x 160 = baş (2 hücre) + 8 hücre alev, 8 kare.
#   kare 0 uyku, 1 ağız parıltısı, 2-4 büyüyen alev, 5-7 tam boy (üç farklı dalgalanma: DungeonProps hold döngüsü).
# Baş + ağız parıltısı eski sayfadan aynen (üst 25 satır), alev eski paletle (nane çekirdek / camgöbeği gövde / açık hale) elle çizilir.
# Kullanım: python -I tools/zindan/gen_ejder_alev.py  -> harita/zindan/{kemik_mahzeni,batik_nekropol}/runtime/dragon_trap_long.png
import math
import os
import random

import numpy as np
from PIL import Image

PROJECT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = os.path.join(PROJECT, 'harita', 'zindan', 'kemik_mahzeni', 'runtime', 'dragon_trap.png')
DESTS = [os.path.join(PROJECT, 'harita', 'zindan', d, 'runtime', 'dragon_trap_long.png') for d in ('kemik_mahzeni', 'batik_nekropol')]

FW, FH = 32, 160
HEAD_ROWS = 25          # eski karedeki baş + ağız (alev bu satırdan başlar)
FLAME_Y0 = 21           # alevin ağızdan çıktığı satır
ROWS = 8                # hücre cinsinden tam boy
CORE = (89, 248, 193)
BODY = (83, 213, 195)
HALO = (173, 255, 243)
# (eski kare, alev boyu px, dalga fazı, parlaklık)
FRAMES = [(0, 0, 0.0, 0), (1, 0, 0.0, 0), (2, 14, 0.4, 1), (3, 44, 1.1, 1), (4, 86, 1.9, 1),
          (5, 128, 0.0, 1), (5, 128, 2.1, 1), (5, 128, 4.2, 1)]


def blend(img, x, y, rgb, a):
    if not (0 <= x < FW and 0 <= y < FH):
        return
    p = img[y, x]
    a0 = p[3] / 255.0
    a1 = a / 255.0
    ao = a1 + a0 * (1 - a1)
    if ao <= 0:
        return
    for i in range(3):
        img[y, x, i] = int(round((rgb[i] * a1 + p[i] * a0 * (1 - a1)) / ao))
    img[y, x, 3] = int(round(ao * 255))


def flame(img, length, phase, seed):
    if length <= 0:
        return
    rng = random.Random(seed)
    for dy in range(length):
        t = dy / float(length)
        y = FLAME_Y0 + dy
        # gövde yarı genişliği: ağızda dar, ilk çeyrekte açılır, uca doğru sivrilir
        hw = 2.0 + 3.6 * math.sin(math.pi * min(1.0, t * 1.25)) ** 0.6 * (1.0 - 0.55 * t)
        cx = 15.5 + (math.sin(dy * 0.20 + phase) * 1.7 + math.sin(dy * 0.47 + phase * 1.7) * 0.9) * (0.25 + 0.75 * t)
        # hale (iki katman, saydam)
        for x in range(int(cx - hw - 4), int(cx + hw + 5)):
            d = abs(x + 0.5 - cx)
            if d <= hw + 1.6 and d > hw:
                blend(img, x, y, HALO, 61)
            elif d <= hw + 3.4 and d > hw + 1.6:
                blend(img, x, y, HALO, 28)
            elif d <= hw + 5.0 and d > hw + 3.4:
                blend(img, x, y, HALO, 15)
        # gövde + çekirdek (kenar 1 px sıçrar = dalgalı)
        for x in range(int(cx - hw - 1), int(cx + hw + 2)):
            d = abs(x + 0.5 - cx) + rng.uniform(-0.45, 0.45)
            if d <= hw * 0.42:
                blend(img, x, y, CORE, 255)
            elif d <= hw:
                blend(img, x, y, BODY, 255)
        # yan dil: ara sıra 2-4 px yana uzanan çekirdek parçası
        if dy > 6 and dy % 9 == int(phase * 3) % 9 and t < 0.92:
            side = -1 if rng.random() < 0.5 else 1
            for k in range(rng.randint(2, 4)):
                blend(img, int(cx + side * (hw + 0.5 + k)), y - k // 2, CORE if k < 2 else BODY, 255)
    # uç kıvılcımları
    for _ in range(4):
        sx = int(15.5 + rng.uniform(-5, 5))
        sy = FLAME_Y0 + length + rng.randint(1, 7)
        blend(img, sx, sy, CORE, 255)
        for dx, dy2 in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            blend(img, sx + dx, sy + dy2, HALO, 61)


def main():
    old = Image.open(SRC).convert('RGBA')
    sheet = np.zeros((FH, FW * len(FRAMES), 4), dtype=np.uint8)
    for i, (old_f, length, phase, _glow) in enumerate(FRAMES):
        fr = np.zeros((FH, FW, 4), dtype=np.uint8)
        head = np.array(old.crop((old_f * 32, 0, old_f * 32 + 32, HEAD_ROWS)))
        fr[:HEAD_ROWS] = head
        if length > 0:
            # eski karenin alev pikselleri (başın altındaki ilk satırlar) yeni alevle çakışmasın: baş bölgesi yalnız baş (karanlık) pikselleri
            fr[FLAME_Y0:HEAD_ROWS, :, 3] = np.where(fr[FLAME_Y0:HEAD_ROWS, :, 0] < 120, fr[FLAME_Y0:HEAD_ROWS, :, 3], 0)
        flame(fr, length, phase, seed=1000 + i)
        sheet[:, i * FW:(i + 1) * FW] = fr
    out = Image.fromarray(sheet, 'RGBA')
    for d in DESTS:
        os.makedirs(os.path.dirname(d), exist_ok=True)
        out.save(d)
        print('yazıldı', d, out.size)
    # önizleme (4x, koyu zemin)
    bg = Image.new('RGBA', out.size, (52, 54, 60, 255))
    bg.alpha_composite(out)
    prev = os.path.join(PROJECT, 'tools', 'zindan', 'out', 'ejder_alev_onizleme.png')
    os.makedirs(os.path.dirname(prev), exist_ok=True)
    bg.resize((out.width * 3, out.height * 3), Image.NEAREST).save(prev)


if __name__ == '__main__':
    main()
