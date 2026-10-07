extends SceneTree

## "Silah satıcısı" (demirci dükkanı iç mekanı) TMX'ini res://scenes/silah_saticisi_baked.tscn'e "bake" eder - bkz.
## tools/bake_ev_ici.gd ile AYNI yöntem (YATI'nin TilemapCreator'ı elle çalıştırılır; tmx proje içinde normal import akışına
## sokulmamış, kaynak Tiled dosyası olarak duruyor). Çalıştırma:
##   Godot --headless --path <proje> -s res://tools/bake_silah_saticisi.gd
## Tileset PNG'leri proje DIŞINDA (../../Harita içerikleri/blacksmith/...) olduğu için YATI onları sahneye HAM RGBA8
## ImageTexture olarak gömer; tools/bake_harita.gd ile aynı sebeple (sahne boyutu/yükleme süresi) kayıpsız sıkıştırılmış
## PortableCompressedTexture2D'ye çevrilir (piksel aynı).
## Katman adları kodda kullanılır (scripts/weapon_shop.gd): "blacksmith kapı iç" = çıkış kapısı, "Eleman pozisyon" = örs
## etkileşim noktası, çarpışma dışı katmanlar NO_COLLISION_LAYERS'ta - Tiled'da yeniden adlandırılırsa orası da güncellenmeli.

const TMX_PATH := "res://harita/silah satıcısı.tmx"
const OUT_PATH := "res://scenes/silah_saticisi_baked.tscn"

var _compacted: int = 0


func _init() -> void:
	var creator_script: GDScript = preload("res://addons/YATI/TilemapCreator.gd")
	var creator: RefCounted = creator_script.new()
	var map_node: Node = creator.create(TMX_PATH) as Node
	if map_node == null:
		printerr("Silah satıcısı bake başarısız: TilemapCreator boş node döndürdü.")
		quit(1)
		return
	_compact_embedded_textures(map_node, {})
	var packed_scene: PackedScene = PackedScene.new()
	var pack_result: Error = packed_scene.pack(map_node)
	map_node.free()
	if pack_result != OK:
		printerr("Silah satıcısı bake başarısız: PackedScene.pack sonucu %s" % pack_result)
		quit(1)
		return
	var save_result: Error = ResourceSaver.save(packed_scene, OUT_PATH)
	if save_result != OK:
		printerr("Silah satıcısı bake başarısız: ResourceSaver sonucu %s" % save_result)
		quit(1)
		return
	print("Silah satıcısı bake tamamlandı: %s (sıkıştırılan gömülü texture: %d)" % [OUT_PATH, _compacted])
	quit(0)


## bkz. tools/bake_harita.gd _compact_embedded_textures (aynı iş).
func _compact_embedded_textures(node: Node, seen: Dictionary) -> void:
	if node is TileMapLayer:
		var tile_set: TileSet = (node as TileMapLayer).tile_set
		if tile_set != null and not seen.has(tile_set):
			seen[tile_set] = true
			for i: int in tile_set.get_source_count():
				var source := tile_set.get_source(tile_set.get_source_id(i)) as TileSetAtlasSource
				if source == null or not (source.texture is ImageTexture):
					continue
				var packed := PortableCompressedTexture2D.new()
				packed.keep_compressed_buffer = true
				packed.create_from_image(source.texture.get_image(), PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
				source.texture = packed
				_compacted += 1
	for child: Node in node.get_children():
		_compact_embedded_textures(child, seen)
