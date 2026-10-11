"""Wendigo bossu sahnesini yazar (scenes/creatures/enemy_wendigo1.tscn). Kullanım: python -I tools/gen_wendigo_scene.py (sayfalar önce tools/import_wendigo_sheets.py ile alınmış olmalı).
Ölçek: 100% sanat x 1,6 ("normal" boy, Minotaur ile aynı); "normal halinden 3 kat büyük" asıl enemy_spawner.gd FIXED_BOSS_STATS "scale" 3.0'da."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_pumpkin_scenes import scene, OUT  # noqa: E402

A = "res://assets/enemies/wendigo/"
text = scene("Enemy_Wendigo1", 100, 1.6, (0, -22),
             {"speed": 80.0, "max_health": 100.0, "contact_damage": 120.0, "contact_interval": 1.8, "xp_value": 18.0, "orb_count": 3,
              "gold_chance": 1.0, "gold_min": 3, "gold_max": 6, "sprite_fps": 9.0},
             {"walk_texture": "wendigo_walk.png", "idle_texture": "wendigo_idle.png", "hurt_texture": "wendigo_hurt.png",
              "death_texture": "wendigo_death.png", "attack_texture": "wendigo_attack.png"}, 4,
             special={"vine": "wendigo_vine.png", "slam": "wendigo_slam.png"}, asset_dir=A)
with open(os.path.join(OUT, "enemy_wendigo1.tscn"), "w", encoding="utf-8", newline="\n") as f:
    f.write(text)
print("yazıldı enemy_wendigo1.tscn")
