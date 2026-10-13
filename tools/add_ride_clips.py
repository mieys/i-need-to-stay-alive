#!/usr/bin/env python3
"""Karakter SpriteFrames'lerine "ride_<yon>" klibi ekler: oturma (sit) klibinin SON karesi, tek kare, dongu.

Neden (2026-10-13, Cadi E - Ucan Supurge): supurgeye binen HER karakter (cadi + yolcular) oturmus pozda durur. "sit_*" klibi
ayaktan oturmaya GECIS animasyonudur (4 kare, dongu) - dogrudan oynatilirsa karakter surekli kalkip oturur. Klip ADI agdan
diger istemcilere gittigi icin (main.gd cur_anim -> remote_player.gd ayni adi oynatir) ayri bir ad olmasi gerekir; bu ad
karakterin SpriteFrames'inde yoksa uzak kopyada sessizce donar (CLAUDE.md madde 4).

Oturma sayfasi olmayan karakter (Oakley) atlanir - o binince bekleme (idle) pozunda kalir (player.gd CharAnim.pick).
Tekrar calistirilabilir (klip varsa dokunmaz). tools/import_character_sheets.py ile bir karakter yeniden ice alinirsa
bu betik yeniden kosulmalidir.

Kullanim (repo kokunden): python tools/add_ride_clips.py
"""
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHAR_DIR = os.path.join(ROOT, "assets", "characters")
DIRS = ["down", "left", "right", "up"]


def patch(path):
    with open(path, "r", encoding="utf-8", newline="") as f:
        text = f.read()
    name = os.path.basename(path)
    if '&"sit_down"' not in text:
        print(f"    {name}: oturma klibi yok, atlandi")
        return False
    if '&"ride_down"' in text:
        print(f"    {name}: ride_* zaten var, atlandi")
        return False
    anims = []
    for d in DIRS:
        at = text.index(f'&"sit_{d}"')
        start = text.rindex('"frames"', 0, at)
        refs = re.findall(r'SubResource\("([^"]+)"\)', text[start:at])
        if not refs:
            raise SystemExit(f"{name}: sit_{d} kareleri bulunamadi")
        anims.append('{"frames": [{"duration": 1.0,"texture": SubResource("%s")}],"loop": true,"name": &"ride_%s","speed": 1.0}' % (refs[-1], d))
    end = text.rindex("}]")
    text = text[:end] + "}, " + ", ".join(anims) + "]" + text[end + 2:]
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    print(f"    {name}: +4 klip (ride_*)")
    return True


def main():
    for p in sorted(glob.glob(os.path.join(CHAR_DIR, "*_frames.tres"))):
        patch(p)


if __name__ == "__main__":
    main()
