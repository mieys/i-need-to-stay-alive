"""Shaman Q (Saldiri Totemi) "A - KOR TOPU" ates topu dokulari (madde 567; prototip madde 562 A, kullanici secti).

Cikti assets/fx/shaman_kor/ (her biri tek kare; oyunda 1 piksel = karakter pikseli 0,903 dunya, fx_totem_fire_bolt.gd):
  kor_bas_0.png / kor_bas_1.png   9x9 kor topu (iki titresim karesi): bordo dis hat, kirmizi-turuncu-sari kat, beyaz cekirdek
  kor_kuyruk_0..2.png             kuyruk topaklari 7x7 / 5x5 / 3x3 (turuncu-kirmizi -> kirmizi -> bordo)
  kor_merkez.png                  5x5 isabet ani cekirdek (sari + turuncu)
  kor_yildiz.png / kor_yildiz_k.png  7x7 / 5x5 dort koseli parlama (isabet / cikis)
Palet = oyunun yanma alevi (assets/fx/burn/yer_alevi_sheet.png). Dither yok.
Kullanim: python -I tools/gen_shaman_kor_topu.py  ; ardindan Godot --headless --import
"""
import math
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "shaman_kor")


def hx(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


FIRE = {"b": hx("#661a0f"), "r": hx("#d64c1f"), "o": hx("#fa9433"), "y": hx("#ffdb75"), "w": hx("#fff4cf")}


def ball(radius, layers, outline, off=(0.0, 0.0)):
    n = int(math.ceil(radius)) * 2 + 1
    c = n // 2
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = im.load()
    for y in range(n):
        for x in range(n):
            d = math.hypot(x - c - off[0], y - c - off[1])
            if d > radius:
                continue
            col = outline
            for rr, cc in layers:
                if d <= rr:
                    col = cc
                    break
            px[x, y] = col
    return im


def star4(arm, center, arm_col, tip=None):
    n = arm * 2 + 1
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = im.load()
    for k in range(-arm, arm + 1):
        col = center if k == 0 else (tip if (tip and abs(k) == arm) else arm_col)
        px[arm + k, arm] = col
        px[arm, arm + k] = col
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    parts = {
        "kor_bas_0": ball(3.8, [(1.3, FIRE["w"]), (2.3, FIRE["y"]), (3.1, FIRE["o"])], FIRE["b"], off=(0.4, -0.4)),
        "kor_bas_1": ball(3.6, [(1.2, FIRE["w"]), (2.2, FIRE["y"]), (3.0, FIRE["o"])], FIRE["b"], off=(-0.3, 0.3)),
        "kor_kuyruk_0": ball(2.2, [(1.2, FIRE["o"])], FIRE["r"]),
        "kor_kuyruk_1": ball(1.6, [(0.6, FIRE["r"])], FIRE["r"]),
        "kor_kuyruk_2": ball(1.0, [], FIRE["b"]),
        "kor_merkez": ball(1.6, [(0.7, FIRE["y"])], FIRE["o"]),
        "kor_yildiz": star4(3, FIRE["w"], FIRE["y"], FIRE["o"]),
        "kor_yildiz_k": star4(2, FIRE["y"], FIRE["o"]),
    }
    for name, im in parts.items():
        im.save(os.path.join(OUT, name + ".png"))
        print(name, im.size)


if __name__ == "__main__":
    main()
