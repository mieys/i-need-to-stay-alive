"""Uçan Şeytan (FİNAL bossu) sprite sayfalarını projeye alır (kullanıcı isteği 2026-10-09, masaüstü `uçan şeytan` paketi: `flying demon/light outline/100% (80x80)/Blue`, `fire shot/100% (32x24)`).
Paketin satır sırası aşağı, SOL, SAĞ, YUKARI -> projenin aşağı, YUKARI, SOL, SAĞ (0<-0, 1<-3, 2<-1, 3<-2).
Sayfa kullanımı: fly 4 (uçuş = yürüme VE bekleme), attack 5 (kılıç savurma), cast 6 (iyileşme büyüsü), death 6, hurt 2. Ateş topu: `fire shot (red)` 128x24 = 4 kare 32x24 (kare 0 uçuş, 1-3 patlama) -> assets/fx/demon/fire_shot.png.
Kullanım: python -I tools/import_demon_sheets.py [kaynak_klasör]  sonra Godot'u bir kez `--headless --import` ile aç.
"""
import os
import sys

from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.expanduser("~"), "Desktop", "uçan şeytan")
BODY = os.path.join(SRC, "flying demon", "light outline", "100% (80x80)", "Blue")
SHOT = os.path.join(SRC, "fire shot", "100% (32x24)", "fire shot (red).png")
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
ROW_MAP = [0, 3, 1, 2]
CELL = 80
SHEETS = {
    "demon_fly.png": "flying demon (blue) - fly.png",
    "demon_attack.png": "flying demon (blue) - attack.png",
    "demon_cast.png": "flying demon (blue) - cast.png",
    "demon_death.png": "flying demon (blue) - death.png",
    "demon_hurt.png": "flying demon (blue) - hit.png",
}

out_e = os.path.join(ROOT, "enemies", "demon")
out_f = os.path.join(ROOT, "fx", "demon")
os.makedirs(out_e, exist_ok=True)
os.makedirs(out_f, exist_ok=True)
for dst, src in SHEETS.items():
    im = Image.open(os.path.join(BODY, src)).convert("RGBA")
    w, h = im.size
    assert h == CELL * 4 and w % CELL == 0, (src, im.size)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for new_row, src_row in enumerate(ROW_MAP):
        out.paste(im.crop((0, src_row * CELL, w, (src_row + 1) * CELL)), (0, new_row * CELL))
    out.save(os.path.join(out_e, dst))
    print(dst, w // CELL, "kare")
shot = Image.open(SHOT).convert("RGBA")
shot.save(os.path.join(out_f, "fire_shot.png"))
print("fire_shot.png", shot.size, shot.size[0] // 32, "kare")
