#!/usr/bin/env python3
"""assets/characters/vampir_frames.tres (SpriteFrames) dosyasini uretir.

Shaman'in SpriteFrames yapisi (idle_*, walk_*, spellcast_*, hurt) + Vampir'e ozel bat_<yon> (E yetenegi,
buyuk yarasa formu; 4 karelik dongu). Once tools/gen_vampir_assets.py calistirilmis olmali.
Kullanim: python tools/gen_vampir_frames.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "characters", "vampir_frames.tres")
DIRS = ["up", "left", "down", "right"]

# (isim öneki, kare sayısı, loop, hız)
GROUPS = [
    ("idle", 2, True, 2.0),
    ("walk", 9, True, 10.0),
    ("spellcast", 7, False, 12.0),
    ("bat", 4, True, 10.0),
]


def main():
    ext = []
    anims = []

    def add_tex(name):
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/characters/vampir/{name}.png" id="{len(ext) + 1}"]')
        return len(ext)

    for prefix, count, loop, speed in GROUPS:
        for d in DIRS:
            ids = [add_tex(f"{prefix}_{d}_{i}") for i in range(1, count + 1)]
            frames = ", ".join('{"duration": 1.0,"texture": ExtResource("%d")}' % i for i in ids)
            anims.append('{"frames": [%s],"loop": %s,"name": &"%s_%s","speed": %s}' % (frames, "true" if loop else "false", prefix, d, speed))
    ids = [add_tex(f"hurt_{i}") for i in range(1, 7)]
    frames = ", ".join('{"duration": 1.0,"texture": ExtResource("%d")}' % i for i in ids)
    anims.append('{"frames": [%s],"loop": false,"name": &"hurt","speed": 12.0}' % frames)

    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(ext) + 1} format=3]', ""]
    lines += ext
    lines += ["", "[resource]", "animations = [" + ", ".join(anims) + "]", ""]
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("yazildi:", OUT, len(ext), "doku")


if __name__ == "__main__":
    main()
