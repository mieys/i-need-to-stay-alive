"""Wendigo (Kademe 12 bossu) sprite sayfalarını projeye alır (kullanıcı isteği 2026-10-09, masaüstü `wendigo` paketi, 100% (100x100)).
Paketin satır sırası: aşağı, SOL, SAĞ, YUKARI -> projenin sırası aşağı, YUKARI, SOL, SAĞ (yeni satır <- kaynak: 0<-0, 1<-3, 2<-1, 3<-2).
Sayfa kullanımı: walk 4, idle 4, attack (= "attack 1", normal pençe saldırısı) 7, vine (= "attack 2", sarmaşık çağırma) 12, slam (= "attack 3", yere vurma) 8, death 8, hurt 2.
Sarmaşık efekti: "branch - full animation (16x32)" = 6 kare uyarı (büyüyen kırmızı elips) + 13 kare yerden çıkış -> assets/fx/wendigo/vine.png (tek satır).
Kullanım: python -I tools/import_wendigo_sheets.py [kaynak_klasör]   sonra Godot'u bir kez `--headless --import` ile aç.
"""
import os
import sys

from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.expanduser("~"), "Desktop", "wendigo", "100% (100x100)")
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
ROW_MAP = [0, 3, 1, 2]
CELL = 100
SHEETS = {
    "wendigo_walk.png": "wendigo - walk.png",
    "wendigo_idle.png": "wendigo - idle.png",
    "wendigo_attack.png": "wendigo - attack 1.png",
    "wendigo_vine.png": "wendigo - attack 2.png",
    "wendigo_slam.png": "wendigo - attack 3.png",
    "wendigo_death.png": "wendigo - death.png",
    "wendigo_hurt.png": "wendigo - hit.png",
}


def main():
    out_e = os.path.join(ROOT, "enemies", "wendigo")
    out_f = os.path.join(ROOT, "fx", "wendigo")
    os.makedirs(out_e, exist_ok=True)
    os.makedirs(out_f, exist_ok=True)
    for dst, src in SHEETS.items():
        im = Image.open(os.path.join(SRC, src)).convert("RGBA")
        w, h = im.size
        assert h == CELL * 4 and w % CELL == 0, (src, im.size)
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        for new_row, src_row in enumerate(ROW_MAP):
            out.paste(im.crop((0, src_row * CELL, w, (src_row + 1) * CELL)), (0, new_row * CELL))
        out.save(os.path.join(out_e, dst))
        print(dst, w // CELL, "kare")
    vine = Image.open(os.path.join(SRC, "branch - full animation (16x32).png")).convert("RGBA")
    vine.save(os.path.join(out_f, "vine.png"))
    print("vine.png", vine.size, vine.size[0] // 16, "kare")


if __name__ == "__main__":
    main()
