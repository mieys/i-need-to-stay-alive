"""Banshee (Kademe 15 bossu) sprite sayfalarını projeye alır (kullanıcı isteği 2026-10-09, masaüstü `banshee` paketi, 100% (80x80)).
Paketin satır sırası aşağı, SOL, SAĞ, YUKARI -> projenin aşağı, YUKARI, SOL, SAĞ (0<-0, 1<-3, 2<-1, 3<-2).
Sayfa kullanımı: move 4 (yürüme/uçma), idle 4, attack 6 (içinden geçme atılışı = "dash"), scream 7, appear 5, death 5, hurt 2.
Kullanım: python -I tools/import_banshee_sheets.py [kaynak_klasör]  sonra Godot'u bir kez `--headless --import` ile aç.
"""
import os
import sys

from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.expanduser("~"), "Desktop", "banshee", "100% (80x80)")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "enemies", "banshee")
ROW_MAP = [0, 3, 1, 2]
CELL = 80
SHEETS = {
    "banshee_walk.png": "banshee - move.png",
    "banshee_idle.png": "banshee - idle.png",
    "banshee_attack.png": "banshee - attack.png",
    "banshee_scream.png": "banshee - scream.png",
    "banshee_appear.png": "banshee - appear.png",
    "banshee_death.png": "banshee - death.png",
    "banshee_hurt.png": "banshee - hit.png",
}

os.makedirs(OUT, exist_ok=True)
for dst, src in SHEETS.items():
    im = Image.open(os.path.join(SRC, src)).convert("RGBA")
    w, h = im.size
    assert h == CELL * 4 and w % CELL == 0, (src, im.size)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for new_row, src_row in enumerate(ROW_MAP):
        out.paste(im.crop((0, src_row * CELL, w, (src_row + 1) * CELL)), (0, new_row * CELL))
    out.save(os.path.join(OUT, dst))
    print(dst, w // CELL, "kare")
