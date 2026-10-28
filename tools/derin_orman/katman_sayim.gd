extends SceneTree

## Doğrulama (madde 362): pişmiş harita sahnesindeki (scenes/harita_baked.tscn) her TileMapLayer'ın dolu hücre sayısını yazdırır
## ("KATMAN <yol>|<sayı>"). tools/derin_orman/katman_karsilastir.py Harita.tmx'in sayılarıyla karşılaştırır (bake TMX'in güncel halini mi taşıyor).
## Kullanım: Godot --headless --path . -s tools/derin_orman/katman_sayim.gd


func _initialize() -> void:
	var h: Node = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	for n: Node in h.find_children("*", "TileMapLayer", true, false):
		var l := n as TileMapLayer
		print("KATMAN ", String(h.get_path_to(l)), "|", l.get_used_cells().size())
	h.free()
	quit()
