# -*- coding: utf-8 -*-
"""ESKİ PAKET SANDIKLARI (madde 409, 2026-11-06; kullanıcı: "sandığı eski haline döndür, senin yaptığını değil eski ai olmayan versiyonu").
Kaynak = oyunun ilk sürümündeki paket sanatı (ilk committe var, üretici yok): assets/sprites/chest_tier_*.png (32x128, 4 kare dikey: kapalı /
kapak aralık / altın görünür / tam açık) + elit için aynı paketin assets/sprites/chests.png 10. sütunu (koyu, gümüş-kristal).
ÇİZİME DOKUNULMAZ: kareler chest_art.gd'nin 20 karelik düzenine yalnız DİZİLİR (0-3 kapalı, 4-7 kapalı +-1 px sallanma, 8 aralık,
9-10 altın görünür, 11-19 tam açık). Çıktı assets/sprites/chests/paket_k0..k5.png (kademe bandı 0-5 = I-II ... XI+) + paket_elite.png,
640x32 yatay şerit. Çalıştır: python tools/gen_chest_from_pack.py  (sonra Godot --headless --path . --import)
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, ".."))
SRC = os.path.join(GAME, "assets", "sprites")
OUT = os.path.join(SRC, "chests")
F = 32
N = 20
BANDS = ["chest_tier_1_2", "chest_tier_3_4", "chest_tier_5_6", "chest_tier_7_8", "chest_tier_9_10", "chest_tier_11_up"]
ELITE_COL = 9  # chests.png: 10 sütun x 4 satır
# 20 kare -> (kaynak kare, x kayması)
LAYOUT = [(0, 0)] * 4 + [(0, -1), (0, 1), (0, -1), (0, 1)] + [(1, 0), (2, 0), (2, 0)] + [(3, 0)] * 9


def frames_from_vertical(img):
    return [img.crop((0, i * F, F, (i + 1) * F)) for i in range(4)]


def frames_from_pack_col(img, col):
    return [img.crop((col * F, i * F, (col + 1) * F, (i + 1) * F)) for i in range(4)]


def strip(frames):
    out = Image.new("RGBA", (F * N, F), (0, 0, 0, 0))
    for i, (src, dx) in enumerate(LAYOUT):
        out.alpha_composite(frames[src], (i * F + dx, 0))
    return out


def base_row(img):
    a = img.getchannel("A")
    bb = a.getbbox()
    return bb[3] if bb else F


def main():
    bases = []
    for k, name in enumerate(BANDS):
        fr = frames_from_vertical(Image.open(os.path.join(SRC, name + ".png")).convert("RGBA"))
        bases.append(base_row(fr[0]))
        strip(fr).save(os.path.join(OUT, "paket_k%d.png" % k))
    pack = Image.open(os.path.join(SRC, "chests.png")).convert("RGBA")
    fr = frames_from_pack_col(pack, ELITE_COL)
    bases.append(base_row(fr[0]))
    strip(fr).save(os.path.join(OUT, "paket_elite.png"))
    print("yazildi:", OUT)
    print("taban satirlari (kapali kare, alfa bbox alt):", bases, "-> chest_art.gd CHEST_ANCHOR_PX.y =", max(set(bases), key=bases.count))


if __name__ == "__main__":
    main()
