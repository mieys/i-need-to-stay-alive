extends SceneTree

## "Seyyar satıcı" (traveling merchant) TMX'ini res://scenes/seyyar_satici_
## baked.tscn'e "bake" eder - bkz. tools/bake_ev_ici.gd ile BİREBİR AYNI
## yöntem (YATI'nin TilemapCreator'ı elle çalıştırılıyor), çünkü bu tmx de
## proje içinde normal import akışına sokulmamış, kaynak Tiled dosyası olarak
## duruyor. Kullanıcı isteği: "Haritanın belli gölgelerinde tüccar gelir
## (seyyar satıcı.tmx harita dosyası seyyar satıcıyı içeriyor)".

func _init() -> void:
	var creator_script: GDScript = preload("res://addons/YATI/TilemapCreator.gd")
	var creator: RefCounted = creator_script.new()
	var map_node: Node = creator.create("res://harita/Seyyar satıcı.tmx") as Node
	if map_node == null:
		printerr("Seyyar satıcı bake başarısız: TilemapCreator boş node döndürdü.")
		quit(1)
		return
	var packed_scene: PackedScene = PackedScene.new()
	var pack_result: Error = packed_scene.pack(map_node)
	map_node.free()
	if pack_result != OK:
		printerr("Seyyar satıcı bake başarısız: PackedScene.pack sonucu %s" % pack_result)
		quit(1)
		return
	var save_result: Error = ResourceSaver.save(packed_scene, "res://scenes/seyyar_satici_baked.tscn")
	if save_result != OK:
		printerr("Seyyar satıcı bake başarısız: ResourceSaver sonucu %s" % save_result)
		quit(1)
		return
	print("Seyyar satıcı bake tamamlandı: res://scenes/seyyar_satici_baked.tscn")
	quit(0)
