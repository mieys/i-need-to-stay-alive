#!/usr/bin/env python3
"""Matthew'in evcil hayvanı (KÖPEK, eskiden tilki) -> assets/pets/dog/dog_sheet.png + dog_frames.tres

Kullanici istegi (2026-10-08): "masaustunde wolf-hellhound adinda bir spritesheet var ve wolf-guide diye bir resim var, guide
sayesinde ogrendigin bilgilerle matthewin tilkisini wolf-hellhound dosyasindaki ile degistir" + "adini kopek yapalim hatta kurt
degil bu sanirim". Kilavuz (wolf-guide.png) sayfanin duzenini veriyor: 48x48 hucre, 5 sutun, 19 satir:
    0-3 WALK down/left/right/up (4 kare)     4-7 RUN down/left/right/up (4 kare)
    8-11 EAT down/left/right/up (5 kare)     12-15 BITE down/left/right/up (5 kare)
    16 HOWL left (5)   17 HOWL right (5)     18 SLEEP down (4)
Oyundaki pet (scripts/player_pet.gd) tilkiden kalan sozlesmeyle calisir: idle/walk/run/hurt/death x {down,left,right,up}. Kopek sayfasinda
idle, hurt ve death yok; eslesme:
    idle_<yon>  = yuruyus 0. karesi (duran kopek)      hurt_<yon> = ayni kare
    death_<yon> = SLEEP karelerine (yatma) - 4 yonde de ayni, dongusuz
    bite_<yon>  = ISIRMA (saldiri animasyonu, player_pet.gd _process_attack oynatir)
    eat_<yon>, howl_left/right, sleep_down = kilavuzdaki gibi (simdilik kullanilmiyor, ileride hazir)
Kullanim (repo kokunden):  python tools/import_dog_sheet.py [kaynak_png]   (sonra Godot `--headless --import`)
"""
import os
import shutil
import sys

SRC_DEFAULT = os.path.join(os.path.expanduser("~"), "Desktop", "wolf-hellhound.png")
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "pets", "dog")
CELL = 48
DIRS = ["down", "left", "right", "up"]
# (anim adi, satir, kare sayisi, hiz, dongu)
ROWS = []
for i, d in enumerate(DIRS):
    ROWS.append((f"walk_{d}", i, 4, 8.0, True))
    ROWS.append((f"run_{d}", 4 + i, 4, 11.0, True))
    ROWS.append((f"eat_{d}", 8 + i, 5, 8.0, True))
    ROWS.append((f"bite_{d}", 12 + i, 5, 16.0, False))
ROWS.append(("howl_left", 16, 5, 6.0, False))
ROWS.append(("howl_right", 17, 5, 6.0, False))
ROWS.append(("sleep_down", 18, 4, 5.0, False))


def main() -> None:
    src = sys.argv[1] if len(sys.argv) > 1 else SRC_DEFAULT
    os.makedirs(OUT_DIR, exist_ok=True)
    shutil.copyfile(src, os.path.join(OUT_DIR, "dog_sheet.png"))
    subs = []
    anims = []
    count = [0]

    def region(row, col):
        count[0] += 1
        sid = f"AT_{count[0]}"
        subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1")\nregion = Rect2({col * CELL}, {row * CELL}, {CELL}, {CELL})\n')
        return sid

    def anim(name, frames, speed, loop):
        body = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % f for f in frames)
        anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (body, "true" if loop else "false", name, speed))

    sheet = {}
    for name, row, n, speed, loop in ROWS:
        sheet[name] = [region(row, c) for c in range(n)]
        anim(name, sheet[name], speed, loop)
    for d in DIRS:
        idle = sheet[f"walk_{d}"][:1]
        anim(f"idle_{d}", idle, 6.0, True)
        anim(f"hurt_{d}", idle, 8.0, False)
        anim(f"death_{d}", sheet["sleep_down"], 5.0, False)
    tres = ('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n'
            '[ext_resource type="Texture2D" path="res://assets/pets/dog/dog_sheet.png" id="1"]\n\n' % (len(subs) + 2))
    tres += "\n".join(subs) + "\n[resource]\nanimations = [" + ", ".join(anims) + "]\n"
    with open(os.path.join(OUT_DIR, "dog_frames.tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write(tres)
    print("ok:", len(subs), "kare,", len(anims), "animasyon")


if __name__ == "__main__":
    main()
