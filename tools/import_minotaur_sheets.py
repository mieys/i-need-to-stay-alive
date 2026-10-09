"""Minotaur (Kademe 3 bossu) sprite sayfalarını projeye alır.

Kaynak: masaüstündeki `minotaur/black outline/100% (80x80)` paketi (hücre 80x80, 4 satır).
Paketin satır sırası  : aşağı, SOL, SAĞ, YUKARI.
Projenin satır sırası : aşağı, YUKARI, SOL, SAĞ (enemy.gd ROW_DOWN/ROW_UP/ROW_LEFT/ROW_RIGHT; C++ EnemyWorld aynısını kullanır).
Bu araç satırları yeniden dizip `assets/enemies/minotaur/` altına yazar. Eşleme (yeni satır <- kaynak satır): 0<-0, 1<-3, 2<-1, 3<-2.

Kullanım:  python tools/import_minotaur_sheets.py [kaynak_klasör]
Sonra Godot'u bir kez `--headless --import` ile aç (yeni PNG'lerin .import dosyaları oluşur).
"""
import os
import sys

from PIL import Image

CELL = 80
SRC_DEFAULT = os.path.join(os.path.expanduser("~"), "Desktop", "minotaur", "black outline", "100% (80x80)")
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "enemies", "minotaur")

## yeni dosya adı -> kaynak dosya adı (paket adları)
SHEETS = {
    "minotaur_walk.png": "minotaur - run.png",            # 8 kare: yürüme/koşu (paketin yürüme klibi yok, koşu kullanılır)
    "minotaur_idle.png": "minotaur - idle.png",           # 4 kare
    "minotaur_attack.png": "minotaur - horn attack.png",  # 6 kare: 0-2 başı eğik (hücum pozu), 3-5 boynuz savurup doğrulma
    "minotaur_death.png": "minotaur - death.png",         # 6 kare
    "minotaur_hurt.png": "minotaur - hit.png",            # 2 kare
}
ROW_MAP = [0, 3, 1, 2]  # yeni satır i <- kaynak satır ROW_MAP[i]


def repack(src_path: str, dst_path: str) -> tuple:
    im = Image.open(src_path).convert("RGBA")
    w, h = im.size
    assert h == CELL * 4 and w % CELL == 0, f"{src_path}: beklenmeyen boyut {im.size}"
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for new_row, src_row in enumerate(ROW_MAP):
        strip = im.crop((0, src_row * CELL, w, (src_row + 1) * CELL))
        out.paste(strip, (0, new_row * CELL))
    out.save(dst_path)
    return out.size, w // CELL


def main() -> None:
    src_dir = sys.argv[1] if len(sys.argv) > 1 else SRC_DEFAULT
    os.makedirs(OUT_DIR, exist_ok=True)
    for dst_name, src_name in SHEETS.items():
        size, cols = repack(os.path.join(src_dir, src_name), os.path.join(OUT_DIR, dst_name))
        print(f"{dst_name}: {size[0]}x{size[1]} ({cols} kare)")


if __name__ == "__main__":
    main()
