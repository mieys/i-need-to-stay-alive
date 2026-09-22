#!/usr/bin/env python3
"""assets/characters/vampir_frames.tres (SpriteFrames) dosyasini uretir.

UYARI (2026-09-22): vampir_frames.tres artik tools/import_character_sheets.py ile (yeni karakter sayfalarindan) uretiliyor;
BU betigi calistirmak yeni sayfa kadrosunu ESKI kadroyla ezer - yalnizca eski kadroya donmek istersen calistir.

Karakter animasyonlari assets/characters/vampir/sheets/<ad>.png sayfalarindan AtlasTexture ile okunur
(48x48 hucre; satirlar: asagi, sol, sag, yukari - bkz. tools/gen_vampir_assets.py); her sayfadan
<ad>_<yon> adli 4 animasyon uretilir. Ek olarak Vampir'e ozel bat_<yon> (E yetenegi, buyuk yarasa formu;
4 karelik dongu, ayri PNG'ler) eklenir. Once tools/gen_vampir_assets.py calistirilmis olmali.
Kullanim: python tools/gen_vampir_frames.py

Hangi animasyon oyunda ne zaman oynar: bkz. player.gd (_update_animation, _play_hurt_animation,
on_food_picked_up, _play_cast_animation, set_reading_ui_active) ve scripts/char_anim.gd.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "characters", "vampir_frames.tres")
SHEET_DIR = os.path.join(ROOT, "assets", "characters", "vampir", "sheets")
RES_DIR = "res://assets/characters/vampir"
CELL = 48
# Sayfalardaki satir sirasi (kullanici bildirimi: asagi-sol-sag-yukari).
DIR_ROWS = [("down", 0), ("left", 1), ("right", 2), ("up", 3)]

# (sayfa, kare sayisi, dongu, hiz fps)
#  eat    : 3 kare / 6 fps = 0.5 sn (kullanici istegi: "yaklasik 0.5 saniye")
#  hurt   : 2 kare, tek seferlik
#  read   : dukkan/kart ekrani acikken dongude
#  shrug  : yetenek kullaniminda tek seferlik; odaklanarak kanal yapan yeteneklerde player.gd bitince yeniden baslatir
#  downed : yerde yatma (dusme) pozu, death: kalici olum; strike/chop/pickup henuz oyunda kullanilmiyor.
SHEET_ANIMS = [
    ("idle", 4, True, 4.0),
    ("walk", 6, True, 8.0),
    ("run", 6, True, 12.0),
    ("eat", 3, False, 6.0),
    ("hurt", 2, False, 6.0),
    ("read", 4, True, 4.0),
    ("shrug", 4, False, 10.0),
    ("downed", 2, False, 4.0),
    ("death", 3, False, 5.0),
    ("strike", 4, False, 10.0),
    ("chop", 4, False, 10.0),
    ("pickup", 4, False, 10.0),
]
# Yarasa formu (E): ayri kare PNG'leri, (onek, kare sayisi, dongu, hiz)
BAT_ANIM = ("bat", 4, True, 10.0)


def main():
    ext = []  # ext_resource satirlari
    subs = []  # sub_resource bloklari
    anims = []

    def add_ext(path):
        ext.append(f'[ext_resource type="Texture2D" path="{path}" id="{len(ext) + 1}"]')
        return len(ext)

    def add_atlas(ext_id, col, row):
        idx = len(subs) + 1
        subs.append(
            f'[sub_resource type="AtlasTexture" id="AtlasTexture_{idx}"]\n'
            f'atlas = ExtResource("{ext_id}")\n'
            f"region = Rect2({col * CELL}, {row * CELL}, {CELL}, {CELL})\n"
        )
        return f"AtlasTexture_{idx}"

    def add_anim(name, frame_refs, loop, speed):
        frames = ", ".join('{"duration": 1.0,"texture": %s}' % ref for ref in frame_refs)
        anims.append('{"frames": [%s],"loop": %s,"name": &"%s","speed": %s}' % (frames, "true" if loop else "false", name, speed))

    for sheet, count, loop, speed in SHEET_ANIMS:
        png = os.path.join(SHEET_DIR, sheet + ".png")
        if not os.path.exists(png):
            raise SystemExit(f"eksik sayfa: {png} - once tools/gen_vampir_assets.py --src <klasor> calistirin")
        w, h = Image.open(png).size
        if w != count * CELL or h != len(DIR_ROWS) * CELL:
            raise SystemExit(f"{sheet}.png {w}x{h}: {count} kare x {len(DIR_ROWS)} yon ({count * CELL}x{len(DIR_ROWS) * CELL}) bekleniyordu")
        ext_id = add_ext(f"{RES_DIR}/sheets/{sheet}.png")
        for d, row in DIR_ROWS:
            refs = [f'SubResource("{add_atlas(ext_id, c, row)}")' for c in range(count)]
            add_anim(f"{sheet}_{d}", refs, loop, speed)

    prefix, count, loop, speed = BAT_ANIM
    for d, _row in DIR_ROWS:
        refs = [f'ExtResource("{add_ext(f"{RES_DIR}/{prefix}_{d}_{i}.png")}")' for i in range(1, count + 1)]
        add_anim(f"{prefix}_{d}", refs, loop, speed)

    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(ext) + len(subs) + 1} format=3]', ""]
    lines += ext
    lines += [""]
    lines += ["\n".join(subs)] if subs else []
    lines += ["[resource]", "animations = [" + ", ".join(anims) + "]", ""]
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("yazildi:", OUT, len(ext), "doku,", len(subs), "atlas karesi,", len(anims), "animasyon")


if __name__ == "__main__":
    main()
