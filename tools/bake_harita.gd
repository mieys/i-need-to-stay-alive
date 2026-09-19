extends SceneTree

## Haritayı (res://harita/Harita.tmx) YATI ile "bake" edip
## res://scenes/harita_baked_new.tscn olarak kaydeder (oradan res://scenes/
## harita_baked.tscn'in yerine geçirilir).
##
## KORUMA (kullanıcı isteği: "tiled üzerinden değişiklik yaptığımda hiçbir
## shaderın değişmesini istemiyorum çünkü... yeni shaderlar da ekliycem
## onların da aktarılması gerek her yüklememde ve sen onları bilmiyosun
## şuan") - TilemapCreator SADECE Tiled verisinden (katmanlar/tile'lar) bir
## sahne üretir; Godot'a özel HİÇBİR şeyi (materyal/shader, script, elle
## eklenmiş ekstra node) bilmez, bu yüzden düz bir "yeniden bake" her seferinde
## bunları siliyordu (bkz. su.gdshader, çimen kir.gdshader, sallantı.gdshader,
## rüzgar efekti.gdshader + kamera takip.gd'li CanvasLayer/ColorRect - hepsi
## elle eklenmişti).
##
## Artık ESKİ (değiştirilmek üzere olan) harita_baked.tscn okunup taze bake
## edilen sahneyle İSİMLE eşleştiriliyor:
##   - Tiled'da karşılığı OLAN (aynı isimli) bir node'un üzerinde materyal
##     varsa (HANGİ shader olursa olsun - önceden bilinmesine gerek YOK)
##     yeni sahnedeki aynı isimli node'a aynen kopyalanır.
##   - Tiled'da HİÇ karşılığı olmayan (elle eklenmiş) bir node varsa
##     (script'i/materyali/çocukları dahil TAMAMEN) yeni sahneye olduğu gibi
##     taşınır.
## Bu sayede ileride eklenecek HERHANGİ bir yeni shader/node da otomatik
## korunur - bu script'in bir daha güncellenmesine gerek kalmaz.
##
## GÖRÜNÜM ÖZELLİKLERİ (y_sort_enabled, visible, modulate...): materyalle aynı
## mantıkla, Tiled'da karşılığı olan node'larda ESKİ sahnedeki değer yenisine
## yazılır (bkz. CARRIED_PRESENTATION_PROPS). Sebep 1: y_sort_enabled Tiled'da
## YOK, Godot editöründe elle veriliyor ("Shader Eklenecek"/"Çalılar1" -
## taşınmazsa ağaç/çalı çizim sırası sessizce bozulur). Sebep 2: Tiled'da
## bir grubu gizlemek/saydamlaştırmak çoğunlukla sadece editördeki çalışma
## kolaylığı (ör. köprü çizerken ağaçları gizlemek) - YATI bunu olduğu gibi
## visible/modulate'a çevirdiği için taşınmazsa oyundaki TÜM ağaç/çalı
## görünmez olurdu ve su shader'ının alpha'sı ayrıca Su katmanının Tiled
## opaklığıyla çarpılırdı. Oyundaki görünüm Godot'ta belirlenir; Tiled
## SADECE tile içeriğini/katman yapısını belirler. Eski sahnede olmayan
## (yeni) katmanlar Tiled'daki değerleriyle gelir.
##
## GÖMÜLÜ TEXTURE: Proje klasörünün DIŞINDAKİ (res:// altında olmayan) bir
## tileset PNG'sini (ör. ../../Harita içerikleri/...) YATI sahneye HAM
## RGBA8 ImageTexture olarak gömer: Bridges.png + bataklık spritesheet.png
## sahneyi 2.7 MB'tan 26 MB'a, yüklemeyi 0.4 sn'den 3.4 sn'ye çıkardı. Bu
## texture'lar kayıpsız sıkıştırılmış, kendi içinde tam bir
## PortableCompressedTexture2D'ye çevrilir (piksel aynı, import adımı ve
## tsx'lerde yol değişikliği gerekmez, git'e ek asset girmez).
##
## SINIRLAMA: eşleştirme node İSMİYLE yapılıyor - Tiled'da bir katmanı
## yeniden adlandırırsanız, o katmanın üzerindeki materyal/eklenti "eski isim"
## bulunamadığı için otomatik taşınmaz (o durumda eski isimdeki elle eklenmiş
## node olarak, YENİ katmanın YANINA bağımsız bir kopya olarak eklenir -
## kaybolmaz ama otomatik doğru yere oturmaz, elle taşınması gerekir).

const TMX_PATH := "res://harita/Harita.tmx"
const OLD_BAKED_PATH := "res://scenes/harita_baked.tscn"
const NEW_BAKED_PATH := "res://scenes/harita_baked_new.tscn"

## Tiled'ın sahibi olmadığı (ya da oyun içinde Godot'ta belirlenen) görünüm
## özellikleri - eşleşen node'larda eski sahnedeki değer KOŞULSUZ korunur.
const CARRIED_PRESENTATION_PROPS: PackedStringArray = [
	"visible", "modulate", "self_modulate", "y_sort_enabled",
	"z_index", "z_as_relative", "show_behind_parent", "light_mask",
]

var _carried_material_count: int = 0
var _carried_node_count: int = 0
var _carried_property_count: int = 0
var _compacted_texture_count: int = 0


func _init() -> void:
	var creator_script: GDScript = preload("res://addons/YATI/TilemapCreator.gd")
	var creator: RefCounted = creator_script.new()
	var new_root: Node = creator.create(TMX_PATH) as Node
	if new_root == null:
		printerr("Harita bake başarısız: TilemapCreator boş node döndürdü.")
		quit(1)
		return

	var old_root: Node = null
	if ResourceLoader.exists(OLD_BAKED_PATH):
		var old_scene: PackedScene = load(OLD_BAKED_PATH)
		old_root = old_scene.instantiate()
		## Kök node'un kendi üzerinde materyal olması ihtimaline karşı (şu an
		## yok ama gelecekte olabilir) - alt node döngüsünden ayrı, tek seferlik.
		if ("material" in old_root) and old_root.material != null:
			new_root.material = old_root.material
			_carried_material_count += 1
		_merge_customizations(old_root, new_root, new_root)

	_compact_embedded_textures(new_root, {})

	var packed_scene: PackedScene = PackedScene.new()
	var pack_result: Error = packed_scene.pack(new_root)
	new_root.free()
	if old_root != null:
		old_root.free()
	if pack_result != OK:
		printerr("Harita bake başarısız: PackedScene.pack sonucu %s" % pack_result)
		quit(1)
		return
	var save_result: Error = ResourceSaver.save(packed_scene, NEW_BAKED_PATH)
	if save_result != OK:
		printerr("Harita bake başarısız: ResourceSaver sonucu %s" % save_result)
		quit(1)
		return
	print("Harita bake tamamlandı: %s (korunan materyal: %d, korunan ekstra node: %d, korunan görünüm özelliği: %d, sıkıştırılan gömülü texture: %d)" % [NEW_BAKED_PATH, _carried_material_count, _carried_node_count, _carried_property_count, _compacted_texture_count])
	quit(0)


## old_parent/new_parent aynı "seviyedeki" karşılık gelen node çifti -
## old_parent'ın her çocuğu new_parent'ta AYNI İSİMLE aranır.
func _merge_customizations(old_parent: Node, new_parent: Node, new_root: Node) -> void:
	for old_child: Node in old_parent.get_children():
		var new_child: Node = new_parent.get_node_or_null(NodePath(String(old_child.name)))
		if new_child:
			_carry_presentation(old_child, new_child)
			## Tiled'da karşılığı var - üzerinde (hangi shader/kaynak olursa
			## olsun) bir materyal varsa aynen taşı, sonra çocuklarına in.
			if ("material" in old_child) and old_child.material != null:
				new_child.material = old_child.material
				_carried_material_count += 1
				_make_carried_material_visible(new_child)
			_merge_customizations(old_child, new_child, new_root)
		else:
			## Tiled'da HİÇ karşılığı yok - elle eklenmiş bir node (script,
			## materyal, çocukları dahil) - olduğu gibi yeni sahneye taşı.
			var dup: Node = old_child.duplicate(Node.DUPLICATE_USE_INSTANTIATION | Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS)
			new_parent.add_child(dup)
			_set_owner_recursive(dup, new_root)
			_make_carried_material_visible(dup)
			_carried_node_count += 1


## Eski sahnedeki görünüm özelliklerini (bkz. CARRIED_PRESENTATION_PROPS) yeni
## node'a yazar. Değer zaten aynıysa dokunmaz (sayaç sadece gerçek farkı sayar).
func _carry_presentation(old_node: Node, new_node: Node) -> void:
	for prop: String in CARRIED_PRESENTATION_PROPS:
		if not (prop in old_node) or not (prop in new_node):
			continue
		var old_value: Variant = old_node.get(prop)
		if new_node.get(prop) != old_value:
			new_node.set(prop, old_value)
			_carried_property_count += 1


## Sahnedeki TileSet'lerin gömülü (res:// yolu olmayan) ham ImageTexture'larını
## kayıpsız sıkıştırılmış PortableCompressedTexture2D'ye çevirir - nedeni için
## dosya başındaki "GÖMÜLÜ TEXTURE" notuna bak. TÜM katmanlar aynı TileSet'i
## paylaşıyor; `seen` aynı TileSet'in iki kez işlenmesini engeller.
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
				## Kaydedilebilmesi için sıkıştırılmış buffer'ın tutulması şart -
				## create_from_image'den ÖNCE ayarlanmalı, yoksa sahneye veri yazılmaz.
				packed.keep_compressed_buffer = true
				packed.create_from_image(source.texture.get_image(), PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
				source.texture = packed
				_compacted_texture_count += 1
	for child: Node in node.get_children():
		_compact_embedded_textures(child, seen)


## Taşınan/çoğaltılan bir materyalin GERÇEKTEN görünmesini garanti eder.
##
## KULLANICI BİLDİRİMİ: "Su ayrıntılar 2 içinde shader yükledim ama hiç
## görünmüyor" - kök neden: Godot'ta bir CanvasItem'da use_parent_material =
## true ise node KENDİ materyalini TAMAMEN YOK SAYAR ve üst node'un
## materyalini kullanır. "Su ayrıntılar 2" ve "Çiçekler 1" katmanlarında
## geçerli bir shader materyali olmasına rağmen use_parent_material = true
## olduğu için shader hiç çizilmiyordu. Bu bayrak Tiled'daki katmanın
## "use_parent_material" özel özelliğinden geliyor (bkz.
## addons/YATI/TilemapCreator.gd), yani HER bake onu yeniden yazıyor -
## bu yüzden materyal taşınırken bu bayrak burada temizleniyor, yoksa
## koruma işe yaramaz (materyal taşınır ama yine görünmez).
## SADECE gerçekten shader'ı olan bir materyal için temizlenir - shader'sız
## (boş) materyali olan ya da hiç materyali olmayan ve kasten üst materyali
## miras alan katmanlara DOKUNULMAZ.
func _make_carried_material_visible(node: Node) -> void:
	if not ("material" in node):
		return
	var mat: Material = node.material
	if not (mat is ShaderMaterial):
		return
	if (mat as ShaderMaterial).shader == null:
		return
	if ("use_parent_material" in node) and node.use_parent_material:
		node.use_parent_material = false


## PackedScene.pack() sadece owner'ı new_root olan node'ları kaydeder -
## duplicate() edilen alt ağacın HER düğümünde owner elle ayarlanmalı.
func _set_owner_recursive(node: Node, root: Node) -> void:
	node.owner = root
	for child: Node in node.get_children():
		_set_owner_recursive(child, root)
