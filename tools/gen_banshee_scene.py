"""Banshee bossu sahnesi (scenes/creatures/enemy_banshee1.tscn). Kullanım: python -I tools/gen_banshee_scene.py.
Ölçek 1,6 (100% sanatta "normal" boy); "normal halinden 3 kat" enemy_spawner.gd FIXED_BOSS_STATS "scale" 3.0."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_pumpkin_scenes import scene, OUT  # noqa: E402

A = "res://assets/enemies/banshee/"
text = scene("Enemy_Banshee1", 80, 1.6, (0, -18),
             {"speed": 90.0, "max_health": 100.0, "contact_damage": 120.0, "contact_interval": 1.5, "xp_value": 18.0, "orb_count": 3,
              "gold_chance": 1.0, "gold_min": 3, "gold_max": 6, "sprite_fps": 8.0},
             {"walk_texture": "banshee_walk.png", "idle_texture": "banshee_idle.png", "hurt_texture": "banshee_hurt.png",
              "death_texture": "banshee_death.png", "attack_texture": "banshee_attack.png"}, 4,
             special={"dash": "banshee_attack.png", "scream": "banshee_scream.png", "appear": "banshee_appear.png"},
             body=17.0, hit=23.0, asset_dir=A)
with open(os.path.join(OUT, "enemy_banshee1.tscn"), "w", encoding="utf-8", newline="\n") as f:
    f.write(text)
print("yazıldı enemy_banshee1.tscn")
