"""Uçan Şeytan (FİNAL) sahnesi (scenes/creatures/enemy_ucansetan1.tscn). Kullanım: python -I tools/gen_demon_scene.py.
Ölçek 1,6 (100% sanatta "normal" boy); "normal halinden 4 kat" enemy_spawner.gd FIXED_BOSS_STATS "scale" 4.0."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_pumpkin_scenes import scene, OUT  # noqa: E402

A = "res://assets/enemies/demon/"
text = scene("Enemy_Ucansetan1", 80, 1.6, (0, -18),
             {"speed": 90.0, "max_health": 100.0, "contact_damage": 150.0, "contact_interval": 1.5, "xp_value": 18.0, "orb_count": 3,
              "gold_chance": 1.0, "gold_min": 3, "gold_max": 6, "sprite_fps": 8.0},
             {"walk_texture": "demon_fly.png", "idle_texture": "demon_fly.png", "hurt_texture": "demon_hurt.png",
              "death_texture": "demon_death.png", "attack_texture": "demon_attack.png"}, 4,
             special={"cast": "demon_cast.png"}, body=17.0, hit=23.0, asset_dir=A)
with open(os.path.join(OUT, "enemy_ucansetan1.tscn"), "w", encoding="utf-8", newline="\n") as f:
    f.write(text)
print("yazıldı enemy_ucansetan1.tscn")
