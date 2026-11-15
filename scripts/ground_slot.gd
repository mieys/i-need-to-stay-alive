extends RefCounted

## ZEMİN YUVASI - TEK KURAL (madde 563, 573). Harita katmanları ("Harita" altındaki TileMapLayer'lar) da yaratıklar da mutlak z 0'da ve
## sahnede y-sort yok: aynı z'deki kardeşler AĞAÇ SIRASIYLA çizilir. Bu yüzden sahne köküne SONRADAN eklenen z 0 düğüm o ana kadar doğmuş
## yaratıkların ÜSTÜNE, z -1 düğüm ise haritanın ALTINA çizilir (hiç görünmez - Topuz/Tırpan/Kalkan zemin efektleri böyle kaybolmuştu,
## ölçüm tools/proto_20261111/zemin_fx/). Zemin efekti z 0 kalır ve sahne kökünde "Harita"nın hemen arkasına taşınır: haritanın üstü,
## yaratık/oyuncu/düşenlerin altı. Harita yoksa (test sahnesi) sıra değişmez. Bağımlılığı yok (her yerden preload edilebilir).
## Kullananlar: EnemyAbilities.place_on_ground (yalnız sıra), Büyücü (fx_arcane_blast/impact), TopuzSlamMath, TirpanReapMath, KalkanBashMath.
## BÜYÜK zemin çizimleri (ağaç/ev boyunu aşan) place() değil add_on_floor() kullanır (haritanın içi, zemin katmanlarının arkası): Shaman E aura sınırı.


## Düğümü zemine indir: z 0 (göreli) + "Harita"nın hemen arkası. Düğüm sahne kökünün çocuğu olmalı - add_child'DAN SONRA çağır
## (sahnenin kendi _ready'si z'yi ezebilir).
static func place(node: CanvasItem) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.z_index = 0
	node.z_as_relative = true
	move_after_map(node)


## Yalnız sıra (z'ye dokunmaz): sahne kökünde "Harita"nın hemen arkası.
static func move_after_map(node: Node) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	var root: Node = node.get_tree().current_scene
	if root == null or node.get_parent() != root:
		return
	var map_node: Node = root.get_node_or_null("Harita")
	if map_node != null:
		root.move_child(node, map_node.get_index() + 1)


## HARİTA ZEMİNİ (madde 586): ev/ağaç boyunu aşan BÜYÜK zemin çizimi (Shaman E aura sınırı) haritanın İÇİNE, zemin katmanlarının hemen
## arkasına girer: zemin + suyun üstü, plato/orman parçaları/ev/köprü/çalı/ağaç/zindan duvarı ve bütün karakterlerin altı. place() burada
## yetmez: "Harita"nın arkası haritanın BÜTÜN katmanlarının üstü demek (440 birimlik halka evin çatısını ve ağaç taçlarını kesiyordu).
## Kural (floor_index): harita "Duvar" katmanı taşıyorsa (zindan haritaları: düz katman listesi, zemin/su duvardan önce) onun hemen önü;
## yoksa yüzey haritaları ("Yer" + "Su" grupları: ana harita, Kara Bataklık, Altın Kumlar) ikisinin sonuncusunun hemen arkası.
## Harita / bilinen katman yoksa (test sahnesi) anchor'ın ebeveynine eklenir (ebeveyn sahne köküyse place() kuralıyla).
## Düğümün dönüşümü haritaya göre olur ("Harita" ana haritada (-2, 21)'de): dünya koordinatıyla çizen düğüm to_local kullanmalı.
static func add_on_floor(node: CanvasItem, anchor: Node) -> void:
	var root: Node = anchor.get_tree().current_scene if anchor.is_inside_tree() else null
	var map_node: Node = root.get_node_or_null("Harita") if root != null else null
	var idx: int = floor_index(map_node) if map_node != null else -1
	if idx < 0:
		var parent: Node = anchor.get_parent()
		if parent == null:
			return
		parent.add_child(node)
		if parent == root:
			place(node)
		return
	map_node.add_child(node)
	map_node.move_child(node, idx)


## Haritanın çocukları arasında zemin çiziminin gireceği sıra; bilinmiyorsa -1.
static func floor_index(map_node: Node) -> int:
	if map_node == null:
		return -1
	var wall: Node = map_node.get_node_or_null("Duvar")
	if wall != null:
		return wall.get_index()
	var last: int = -1
	for layer_name: String in ["Yer", "Su"]:
		var c: Node = map_node.get_node_or_null(layer_name)
		if c != null:
			last = maxi(last, c.get_index())
	return last + 1 if last >= 0 else -1
