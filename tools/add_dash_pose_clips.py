#!/usr/bin/env python3
"""Assasin Cocuk + Talon SpriteFrames'lerine "dash_<yon>" klibi ekler: kosu (run_<yon>) klibinin en genis adimli TEK karesi.

Neden (kullanici istegi 2026-10-16): "ulti esnasinda sabit durmasin, kosarkenki atilmaya benzer framelerden biri olsun gittigi
yone dogru, o sekilde gorunsun golgesi". Golge Hucumu (R) surerken karakter her sicrayista gittigi yone bakan bu atilma
pozunda durur, sicrayis hayaletleri de ayni kareden cizilir (scripts/char_anim.gd DASH_POSE_*). Klip ADI agdan diger
istemcilere gittigi icin (main.gd cur_anim -> remote_player.gd ayni adi oynatir) karakterin SpriteFrames'inde olmali; yoksa
uzak kopyada sessizce donar (CLAUDE.md madde 4).

2026-10-17 (kullanici): Talon Q atilisi da "tipki assasin cocuktaki gibi kosma animasyonunun framelerinden birinde"
gorunsun -> talha_frames.tres de eklendi (ayni 48x48 paket, 2. kare yine en genis adim).

Kare secimi: run_* 6 kare; 2. kare (0'dan) bacaklar en acik + kol onde (sag/sol), on/arka gorunumde de en genis adim.
Tekrar calistirilabilir (klip varsa dokunmaz). tools/import_character_sheets.py ile Assasin/Talon yeniden ice alinirsa bu betik
yeniden kosulmalidir.

Kullanim (repo kokunden): python tools/add_dash_pose_clips.py
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = ["assasin_frames.tres", "talha_frames.tres"]
DIRS = ["down", "left", "right", "up"]
RUN_FRAME = 2  # scripts/char_anim.gd DASH_POSE_RUN_FRAME ile AYNI


def add_clips(name):
    path = os.path.join(ROOT, "assets", "characters", name)
    with open(path, "r", encoding="utf-8", newline="") as f:
        text = f.read()
    if '&"dash_down"' in text:
        print(f"    {name}: dash_* zaten var, atlandi")
        return
    anims = []
    for d in DIRS:
        at = text.index(f'&"run_{d}"')
        start = text.rindex('"frames"', 0, at)
        refs = re.findall(r'SubResource\("([^"]+)"\)', text[start:at])
        if len(refs) <= RUN_FRAME:
            raise SystemExit(f"{name} run_{d}: {RUN_FRAME}. kare yok ({len(refs)} kare)")
        anims.append('{"frames": [{"duration": 1.0,"texture": SubResource("%s")}],"loop": true,"name": &"dash_%s","speed": 1.0}'
                     % (refs[RUN_FRAME], d))
    end = text.rindex("}]")
    text = text[:end] + "}, " + ", ".join(anims) + "]" + text[end + 2:]
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    print(f"    {name}: +4 klip (dash_*)")


def main():
    for name in FILES:
        add_clips(name)


if __name__ == "__main__":
    main()
