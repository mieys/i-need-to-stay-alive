"""Yeraltı Canavarı'nın (Kademe 5 bossu) solucan uzuvlarının sprite sayfalarını projeye alır.

Kaynak: masaüstündeki `solucan boss/light outline/100% (80x80)` (hücre 80x80, 4 satır) ve `solucan boss/poison shot/100%`.
Paketin satır sırası  : aşağı, SAĞ, SOL, YUKARI (solucanın ağzı/başı hangi yana bakıyorsa o satır; minotaur paketinden FARKLI).
Projenin satır sırası : aşağı, YUKARI, SOL, SAĞ (enemy.gd ROW_DOWN/ROW_UP/ROW_LEFT/ROW_RIGHT; C++ EnemyWorld aynısını kullanır).
Eşleme (yeni satır <- kaynak satır): 0<-0, 1<-3, 2<-2, 3<-1.

Çıktı `assets/enemies/sandworm/`: sandworm_{idle,emerge,lash,spit,hide,death}.png (+ asit mermisi acid_loop.png / acid_end.png, satır YOK: tek şerit, 20x21 kareler, sağa uçar).
Kullanım:  python tools/import_sandworm_sheets.py [kaynak_klasör]
Sonra Godot'u bir kez `--headless --import` ile aç (yeni PNG'lerin .import dosyaları oluşur).
"""
import os
import shutil
import sys

from PIL import Image

CELL = 80
SRC_DEFAULT = os.path.join(os.path.expanduser("~"), "Desktop", "solucan boss")
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "enemies", "sandworm")

## yeni dosya adı -> paketteki dosya adı (light outline/100% (80x80) altında)
SHEETS = {
    "sandworm_idle.png": "sand worm - idle.png",      # 4 kare: bekleme (C++ yürüme/bekleme döngüsü)
    "sandworm_emerge.png": "sand worm - come out.png",  # 4 kare: delikten çıkış
    "sandworm_lash.png": "sand worm - attack1.png",   # 7 kare: 0-2 kıvrılma, 3-4 SAVURMA (isabet karesi 3), 5-6 geri çekilme
    "sandworm_spit.png": "sand worm - attack2.png",   # 6 kare: ağzı açıp asit tükürme (atış karesi ~3)
    "sandworm_hide.png": "sand worm - hide.png",      # 8 kare: yere gömülme
    "sandworm_death.png": "sand worm - death.png",    # 7 kare: parçalanma
}
ROW_MAP = [0, 3, 2, 1]  # yeni satır i <- kaynak satır ROW_MAP[i]


def repack(src_path: str, dst_path: str) -> tuple:
    im = Image.open(src_path).convert("RGBA")
    w, h = im.size
    assert h == CELL * 4 and w % CELL == 0, f"{src_path}: beklenmeyen boyut {im.size}"
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for new_row, src_row in enumerate(ROW_MAP):
        out.paste(im.crop((0, src_row * CELL, w, (src_row + 1) * CELL)), (0, new_row * CELL))
    out.save(dst_path)
    return out.size, w // CELL


def main() -> None:
    src_root = sys.argv[1] if len(sys.argv) > 1 else SRC_DEFAULT
    sheet_dir = os.path.join(src_root, "light outline", "100% (80x80)")
    os.makedirs(OUT_DIR, exist_ok=True)
    for dst_name, src_name in SHEETS.items():
        size, cols = repack(os.path.join(sheet_dir, src_name), os.path.join(OUT_DIR, dst_name))
        print(f"{dst_name}: {size[0]}x{size[1]} ({cols} kare)")
    for dst_name, src_name in {"acid_loop.png": "poison shot - loop.png", "acid_end.png": "poison shot - ending.png"}.items():
        shutil.copyfile(os.path.join(src_root, "poison shot", "100%", src_name), os.path.join(OUT_DIR, dst_name))
        print(f"{dst_name}: {Image.open(os.path.join(OUT_DIR, dst_name)).size}")
    ## Görünmez boss düğümünün 1 karelik saydam dokusu (4 yön satırı x 1 sütun, hücre 8): boss'un sprite'ı yok.
    Image.new("RGBA", (8, 32), (0, 0, 0, 0)).save(os.path.join(OUT_DIR, "empty.png"))
    print("empty.png: 8x32")


if __name__ == "__main__":
    main()
