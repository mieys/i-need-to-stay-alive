extends "res://scripts/fx_animation.gd"

## Yetenek evrimi efektlerinin (2026-09-28, tools/gen_evolution_fx.py sayfaları) ortak tek seferlik oynatıcısı: "play"
## animasyonunu bir kez oynatıp siler (fx_animation.gd). Yarıçapı oyunda değişen efektler (Hadime Süpernova - kara delik
## "Genişleyen Boşluk" ile büyür, Korsan patlama yarıçapı vb.) setup(radius) ile ölçeklenir: sayfa base_radius dünya
## birimlik bir alana göre çizildi (sahnede yazılı). Hem yerelde (player.gd _evo_world_fx) hem diğer oyuncularda
## (network_manager.gd "hitscan_impact" - radius gelirse setup çağırır) AYNI yoldan kurulur.

@export var base_radius: float = 0.0


func setup(radius: float, _color: Color = Color.WHITE) -> void:
	if base_radius > 0.0 and radius > 0.0:
		scale = scale * (radius / base_radius)
