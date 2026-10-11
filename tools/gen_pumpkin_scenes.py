"""Balkabağı Kafa bossu + kabak + yarasa yaratık sahnelerini yazar (scenes/creatures/enemy_balkabagi1.tscn, enemy_kabak1.tscn, enemy_yarasa1.tscn).
Kullanım: python -I tools/gen_pumpkin_scenes.py   (sprite sayfaları önce tools/import_pumpkin_sheets.py ile alınmış olmalı)
Ölçek: "normal" boy = 100% sanat x 1,6 (Minotaur ile aynı); balkabağı bossu 200% sanatla geldiği için 0,8 (= aynı normal boy), asıl 2x büyütme boss çarpanında (enemy_spawner.gd FIXED_BOSS_STATS "scale").
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "scenes", "creatures")
A = "res://assets/enemies/pumpkin/"


def scene(name, cell, scale, offset, base_props, tex, hframes, special=None, body=19.5, hit=25.5, asset_dir=A):
    ext = ['[ext_resource type="Script" path="res://scripts/enemy.gd" id="1"]']
    ids = {}
    n = 2
    for key, fname in tex.items():
        ext.append(f'[ext_resource type="Texture2D" path="{asset_dir}{fname}" id="{n}"]')
        ids[key] = n
        n += 1
    sp_ids = {}
    for key, fname in (special or {}).items():
        ext.append(f'[ext_resource type="Texture2D" path="{asset_dir}{fname}" id="{n}"]')
        sp_ids[key] = n
        n += 1
    lines = ["[gd_scene load_steps=%d format=3]" % (len(ext) + 2), ""] + ext + [
        "",
        '[sub_resource type="CircleShape2D" id="CircleShape2D_body"]', f"radius = {body}", "",
        '[sub_resource type="CircleShape2D" id="CircleShape2D_hit"]', f"radius = {hit}", "",
        f'[node name="{name}" type="CharacterBody2D" groups=["enemies"]]', "collision_layer = 4", "collision_mask = 0", 'script = ExtResource("1")',
    ]
    for k, v in base_props.items():
        lines.append(f"{k} = {v}")
    lines.append(f"cell_size = {cell}")
    for key, i in ids.items():
        lines.append(f'{key} = ExtResource("{i}")')
    if sp_ids:
        lines.append("special_textures = {" + ", ".join(f'"{k}": ExtResource("{i}")' for k, i in sp_ids.items()) + "}")
    lines += ["", '[node name="Sprite2D" type="Sprite2D" parent="."]', "texture_filter = 1", f"scale = Vector2({scale}, {scale})",
              f'texture = ExtResource("{ids["walk_texture"]}")', f"hframes = {hframes}", "vframes = 4", f"offset = Vector2({offset[0]}, {offset[1]})", "",
              '[node name="CollisionShape2D" type="CollisionShape2D" parent="."]', 'shape = SubResource("CircleShape2D_body")', "",
              '[node name="HitArea" type="Area2D" parent="."]', "collision_layer = 0", "collision_mask = 2", "",
              '[node name="HitCollision" type="CollisionShape2D" parent="HitArea"]', 'shape = SubResource("CircleShape2D_hit")', ""]
    return "\n".join(lines)


def main():
    boss = scene("Enemy_Balkabagi1", 200, 0.8, (0, -49),
                 {"speed": 72.0, "max_health": 100.0, "contact_damage": 20.0, "contact_interval": 1.4, "xp_value": 18.0, "orb_count": 3,
                  "gold_chance": 1.0, "gold_min": 3, "gold_max": 6, "sprite_fps": 9.0},
                 {"walk_texture": "balkabagi_walk.png", "idle_texture": "balkabagi_idle.png", "hurt_texture": "balkabagi_hurt.png",
                  "death_texture": "balkabagi_death.png", "attack_texture": "balkabagi_attack.png"}, 4,
                 special={"cast": "balkabagi_cast.png", "summon": "balkabagi_summon.png"})
    kabak = scene("Enemy_Kabak1", 64, 1.0, (0, -15),
                  {"speed": 60.0, "max_health": 38.48, "contact_damage": 0.0, "contact_interval": 1.0, "xp_value": 4.0, "orb_count": 1,
                   "gold_chance": 0.1, "gold_min": 1, "gold_max": 2, "sprite_fps": 9.0},
                  {"walk_texture": "kabak_walk.png", "hurt_texture": "kabak_hurt.png", "death_texture": "kabak_death.png", "attack_texture": "kabak_attack.png"}, 6,
                  body=11.0, hit=15.0)
    yarasa = scene("Enemy_Yarasa1", 64, 1.0, (0, -14),
                   {"speed": 60.0, "max_health": 38.48, "contact_damage": 5.0, "contact_interval": 1.2, "xp_value": 3.0, "orb_count": 1,
                    "gold_chance": 0.1, "gold_min": 1, "gold_max": 2, "sprite_fps": 12.0},
                   {"walk_texture": "yarasa_walk.png", "hurt_texture": "yarasa_hurt.png", "death_texture": "yarasa_death.png", "attack_texture": "yarasa_walk.png"}, 4,
                   body=10.0, hit=14.0)
    for fname, text in (("enemy_balkabagi1.tscn", boss), ("enemy_kabak1.tscn", kabak), ("enemy_yarasa1.tscn", yarasa)):
        with open(os.path.join(OUT, fname), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("yazıldı", fname)


if __name__ == "__main__":
    main()
