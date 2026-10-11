"""Balkabağı Kafa (Kademe 8 bossu) + balkabağı yaratığı + yarasa + büyü sprite sayfalarını projeye alır.

Kaynak: masaüstündeki `balkabağı herif` paketi (`Pumpkin warlock` hücre 200x200, `Bat and pumpkin` hücre 64x64, `Spell` 36x40; hepsi 200% "light outline").
Paketin satır sırası: aşağı, SOL, SAĞ, YUKARI. Projenin sırası: aşağı, YUKARI, SOL, SAĞ (enemy.gd ROW_*; C++ EnemyWorld aynısı) -> yeni satır <- kaynak satır: 0<-0, 1<-3, 2<-1, 3<-2.
Çıktı: assets/enemies/pumpkin/ (boss + kabak + yarasa, 4 satırlı) ve assets/fx/pumpkin/ (büyü, tek satır).

Kullanım:  python -I tools/import_pumpkin_sheets.py [kaynak_klasör]   sonra Godot'u bir kez `--headless --import` ile aç.
"""
import os
import sys

from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.expanduser("~"), "Desktop", "balkabağı herif")
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
ROW_MAP = [0, 3, 1, 2]

WARLOCK = os.path.join(SRC, "Pumpkin warlock", "light outline", "200% (200x200)")
SMALL = os.path.join(SRC, "Bat and pumpkin", "light outline", "200% (64x64)")
SPELL = os.path.join(SRC, "Spell", "200% (36x40)")

## (kaynak klasör, kaynak dosya) -> yeni dosya, hücre
BOSS = {
    "balkabagi_walk.png": "pumpkin warlock - walk.png",
    "balkabagi_idle.png": "pumpkin warlock - idle.png",
    "balkabagi_attack.png": "pumpkin warlock - attack.png",
    "balkabagi_cast.png": "pumpkin warlock - cast.png",
    "balkabagi_summon.png": "pumpkin warlock - summon bat.png",
    "balkabagi_death.png": "pumpkin warlock - death.png",
    "balkabagi_hurt.png": "pumpkin warlock - hit.png",
}
KABAK = {
    "kabak_walk.png": "pumpkin - jump.png",
    "kabak_attack.png": "pumpkin - attack.png",
    "kabak_death.png": "pumpkin - death.png",
    "kabak_hurt.png": "pumpkin - hit.png",
}
YARASA = {
    "yarasa_walk.png": "bat - fly.png",
    "yarasa_death.png": "bat - death.png",
    "yarasa_hurt.png": "bat - hit.png",
}


def repack(src_path, dst_path, cell):
    im = Image.open(src_path).convert("RGBA")
    w, h = im.size
    assert h == cell * 4 and w % cell == 0, f"{src_path}: beklenmeyen boyut {im.size}"
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for new_row, src_row in enumerate(ROW_MAP):
        out.paste(im.crop((0, src_row * cell, w, (src_row + 1) * cell)), (0, new_row * cell))
    out.save(dst_path)
    return w // cell


def main():
    out_e = os.path.join(ROOT, "enemies", "pumpkin")
    out_f = os.path.join(ROOT, "fx", "pumpkin")
    os.makedirs(out_e, exist_ok=True)
    os.makedirs(out_f, exist_ok=True)
    for table, folder, cell in ((BOSS, WARLOCK, 200), (KABAK, SMALL, 64), (YARASA, SMALL, 64)):
        for dst, src in table.items():
            print(dst, repack(os.path.join(folder, src), os.path.join(out_e, dst), cell), "kare")
    ## idle sayfaları (pakette yok; test_enemy_idle_animation her yaratıkta idle sayfası ister):
    ## kabak = yürüyüş (zıplama) sayfasının 0. karesi (durunca ayakta bekler), yarasa = uçuş sayfası aynen (yarasa duruken de kanat çırpar)
    kw = Image.open(os.path.join(out_e, "kabak_walk.png")).convert("RGBA")
    kw.crop((0, 0, 64, kw.size[1])).save(os.path.join(out_e, "kabak_idle.png"))
    Image.open(os.path.join(out_e, "yarasa_walk.png")).convert("RGBA").save(os.path.join(out_e, "yarasa_idle.png"))
    ## büyü: tek satır, 36x40 kare (uçuş 3 kare, patlama 3 kare)
    for dst, src in (("spell_fly.png", "spell.png"), ("spell_impact.png", "spell - impact.png"), ("spell_full.png", "spell - full animation.png")):
        im = Image.open(os.path.join(SPELL, src)).convert("RGBA")
        im.save(os.path.join(out_f, dst))
        print(dst, im.size, im.size[0] // 36, "kare")


if __name__ == "__main__":
    main()
