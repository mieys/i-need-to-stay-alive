#!/usr/bin/env python3
"""Shaman totemleri v4 (madde 176) - OYUN assetleri: kullanicinin sectigi "A" yonu.

Q Saldiri Totemi = A "Element Catali" (obsidyen sutun + altin, boynuz-catal arasinda ates cekirdegi).
E Kalkan Totemi  = A-E "Koruyucu Kanat" (mermer kule + mazgalli kaide, tas kanatlar arasinda suzulen mavi ISIK KALKANI).
Cizim kodu TEK yerde: tools/proto_20261016/shaman_totem_proto2.py (totem_a / totem_a_e); bu betik onu cagirip yazar:
  assets/shaman/totem_attack_idle.png, totem_shield_idle.png   8 kare x 40x56 (320x56), 10 fps
  assets/skills/shaman_{saldiri,kalkan}_totemi_icon.png        48x48 madalyon (gen_shaman_assets.medallion) -> x3 = 144
  scenes/totem_{attack,shield}.tscn                            AtlasTexture bolgeleri + kare sayisi/hiz + TotemSprite konum/olcek (idempotent)
Sprite olcegi = Shaman'in pikseli (DEFS[12] scale 2.2368375 x EntityScale 0.8075 x 0.5 = 0.903 dunya birimi/px), ayak satiri y=52.
Not: tools/gen_shaman_assets.py'yi TAM calistirmak v3 totemleri geri yazar - sesler icin gerekirse sonra bunu yeniden calistir.
Calistir (repo kokunden): python tools/gen_shaman_totems_v4.py  ; ardindan Godot --headless --import
"""
import importlib.util
import os
import re
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

_spec = importlib.util.spec_from_file_location("shaman_totem_proto2", os.path.join(ROOT, "tools", "proto_20261016", "shaman_totem_proto2.py"))
art = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(art)

import gen_shaman_assets as g  # medallion / MEDALLIONS / S / K

SPRITE_SCALE = 0.903
FOOT_ROW = art.GY  # 52
# TotemSprite.position.y: ayak satirinin ortasi dugum kokunun ~3 birim altina (eski kaidenin golgeyle iliskisi korunur)
SPRITE_Y = -19
TOTEMS = {
    "attack": ("q", "saldiri", os.path.join(ROOT, "scenes", "totem_attack.tscn")),
    "shield": ("e", "kalkan", os.path.join(ROOT, "scenes", "totem_shield.tscn")),
}
ICON_CROP = (1, 7, 37, 43)  # 36x36, eksen x=19 ortada: cekirdek/kalkan + catal/kanat + bilezik


def build_sheet(kind):
    frames = [art.totem_a(kind, f) for f in range(art.FRAMES)]
    sheet = Image.new("RGBA", (art.W * art.FRAMES, art.H), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i * art.W, 0), fr)
    return sheet, frames


def build_icon(icon_name, frame):
    base = g.medallion(*g.MEDALLIONS[icon_name])
    crop = frame.crop(ICON_CROP)
    mask = Image.new("L", (g.S, g.S), 0)
    ImageDraw.Draw(mask).ellipse((5, 5, 42, 42), fill=255)
    layer = Image.new("RGBA", (g.S, g.S), (0, 0, 0, 0))
    layer.paste(crop, (6, 6))
    layer = Image.composite(layer, Image.new("RGBA", (g.S, g.S), (0, 0, 0, 0)), mask)
    base.alpha_composite(layer)
    return base.resize((g.S * g.K, g.S * g.K), Image.NEAREST)


def patch_scene(path):
    s = open(path, encoding="utf-8").read()
    i0 = s.index('[sub_resource type="AtlasTexture"')
    i1 = s.index("[node name=")
    blocks = []
    for i in range(art.FRAMES):
        blocks.append('[sub_resource type="AtlasTexture" id="Atlas_%d"]\natlas = ExtResource("2_sheet")\nregion = Rect2(%d, 0, %d, %d)\n'
                      % (i, i * art.W, art.W, art.H))
    frames = ", {".join('\n"duration": 1.0,\n"texture": SubResource("Atlas_%d")\n}' % i for i in range(art.FRAMES))
    blocks.append('[sub_resource type="SpriteFrames" id="SpriteFrames_idle"]\nanimations = [{\n"frames": [{%s],\n"loop": true,\n'
                  '"name": &"idle",\n"speed": %.1f\n}]\n' % (frames, float(art.FPS)))
    s = s[:i0] + "\n".join(blocks) + "\n" + s[i1:]
    s = re.sub(r'(\[node name="TotemSprite"[^\]]*\]\n(?:[^\[]*?\n)?)position = Vector2\([^)]*\)', r'\1position = Vector2(0, %d)' % SPRITE_Y, s, count=1)
    s = re.sub(r'(\[node name="TotemSprite"[^\]]*\]\n(?:[^\[]*?\n)?)scale = Vector2\([^)]*\)', r'\1scale = Vector2(%s, %s)' % (SPRITE_SCALE, SPRITE_SCALE), s, count=1)
    open(path, "w", encoding="utf-8", newline="\n").write(s)


def main():
    only = sys.argv[1:] or list(TOTEMS)  # ornek: python tools/gen_shaman_totems_v4.py attack
    for name, (kind, icon_name, scene) in TOTEMS.items():
        if name not in only:
            continue
        sheet, frames = build_sheet(kind)
        sheet.save(os.path.join(ROOT, "assets", "shaman", "totem_%s_idle.png" % name))
        build_icon(icon_name, frames[1]).save(os.path.join(ROOT, "assets", "skills", "shaman_%s_totemi_icon.png" % icon_name))
        patch_scene(scene)
        print(name, "->", sheet.size)


if __name__ == "__main__":
    main()
