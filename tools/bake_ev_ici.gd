extends SceneTree

## "Ev içi" (house interior) TMX'ini res://scenes/ev_ici_baked.tscn'e "bake"
## eder - bkz. tools/bake_harita.gd ile AYNI yöntem (YATI'nin TilemapCreator'ı
## elle çalıştırılıyor), çünkü bu tmx de proje içinde normal import akışına
## sokulmamış, kaynak Tiled dosyası olarak duruyor.

## Kullanıcı isteği: ev içi haritası artık "harita/ev içi.tmx" dosyasından güncelleniyor
## (eskiden "harita/Ev içi/ev denemesi.tmx"). Tileset'ler "Ev içi/" klasöründe kalıyor.
const TMX_PATH := "res://harita/ev içi.tmx"


func _init() -> void:
	var creator_script: GDScript = preload("res://addons/YATI/TilemapCreator.gd")
	var creator: RefCounted = creator_script.new()
	var map_node: Node = creator.create(TMX_PATH) as Node
	if map_node == null:
		printerr("Ev içi bake başarısız: TilemapCreator boş node döndürdü.")
		quit(1)
		return
	var packed_scene: PackedScene = PackedScene.new()
	var pack_result: Error = packed_scene.pack(map_node)
	map_node.free()
	if pack_result != OK:
		printerr("Ev içi bake başarısız: PackedScene.pack sonucu %s" % pack_result)
		quit(1)
		return
	var save_result: Error = ResourceSaver.save(packed_scene, "res://scenes/ev_ici_baked.tscn")
	if save_result != OK:
		printerr("Ev içi bake başarısız: ResourceSaver sonucu %s" % save_result)
		quit(1)
		return
	print("Ev içi bake tamamlandı: res://scenes/ev_ici_baked.tscn")
	quit(0)
