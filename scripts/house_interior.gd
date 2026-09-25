extends Node2D
class_name HouseInterior

## Başlangıç evine "F" ile girip çıkma sistemi (kullanıcı isteği: "haritamda
## başlangıç kısmında bir ev var, çok yaklaşınca F'ye basarak içeri
## girilsin, içerideyken aşağıya yaklaşınca F'ye basıp çıkılabilsin").
## GÜNCEL: F sadece DIŞARIDAN İÇERİ girmek için; içeriden çıkış artık iç haritadaki "Kapı"
## katmanına basınca (bkz. _create_exit_trigger). İç haritanın çarpışmaları da (Kapı, Eşya
## alt, zemin, İç oda giriş HARİÇ tüm katmanlar) çalışma anında üretilir (bkz.
## _add_interior_collisions).
##
## Yaratıkların içeri saldıramaması (kullanıcı isteği) BURADA değil,
## player.gd'nin is_indoors bayrağı + enemy.gd'nin _find_closest_target_player
## (oyuncuyu is_invisible_now ile AYNI şekilde hedef dışı bırakıyor) ve
## enemy_spawner.gd'nin (is_indoors iken yeni yaratık üretmeyi durduruyor)
## kontrolleriyle sağlanıyor - bu script SADECE giriş/çıkış tetiklemesini,
## oyuncunun ışınlanmasını ve "F'ye bas" ipucunu yönetiyor.
##
## İç mekan (res://scenes/ev_ici_baked.tscn - "Ev içi/ev denemesi.tmx"nin
## YATI ile bake edilmiş hali, bkz. tools/bake_ev_ici.gd) dünyanın geri
## kalanından tamamen uzak bir noktaya (INTERIOR_OFFSET) yerleştiriliyor;
## böylece dışarıdaki hiçbir yaratık/obje ile asla çakışmıyor.

const InteriorScene: PackedScene = preload("res://scenes/ev_ici_baked.tscn")

## İç mekanın dünya üzerindeki konumu - oynanış alanından (harita 0..4096)
## tamamen uzak, boş bir bölge.
const INTERIOR_OFFSET := Vector2(20000.0, 0.0)

## "ev denemesi.tmx" zemin katmanının piksel sınırları (bkz. get_tilemap_layout
## ile ölçülen değerler): x:[16,304] y:[80,320]. Kapı/giriş-çıkış güney
## (alt) duvarda kabul ediliyor.
const ROOM_MIN := Vector2(16.0, 80.0)
const ROOM_MAX := Vector2(304.0, 320.0)
const WALL_THICKNESS := 16.0

## Kullanıcı isteği: "smooth vinyet efektini iptal et en iyisi siyah olsun
## evin dışı" - artık yumuşak geçiş YOK, oda içeriğinin (zemin+duvarlar,
## bkz. "Tile Layer 1"/"ekstra" katmanlarının ölçülen birleşik piksel sınırı
## x:[0,320] y:[64,320]) HEMEN dışı düz siyah dolgu ile kaplanıyor (bkz.
## _add_black_backdrop).
const VIGNETTE_MIN := Vector2(0.0, 64.0)
const VIGNETTE_MAX := Vector2(320.0, 320.0)
## Siyah dolgunun kapladığı alan (dünya birimi) - kamera hangi zoom'da
## olursa olsun görünen tüm boşluğu kaplayacak kadar büyük.
const VIGNETTE_SIZE := 3000.0

## Oyuncu içeri girince belirdiği nokta - odanın ortası olarak güncellendi.
const INTERIOR_SPAWN_POS := Vector2(160.0, 200.0)
## Kullanıcı isteği (ev içi güncellemesi): dışarı çıkış artık F ile DEĞİL - iç haritadaki
## "Kapı" katmanına (Tiled'da "Kapı" adlı tile layer) basınca oluyor; F sadece DIŞARIDAN
## içeri girmek için kalıyor. Çıkış tetikleyicisi çalışma anında bu katmanın hücrelerinden
## üretilir (bkz. _create_exit_trigger) - kapı Tiled'da taşınırsa kod değişikliği gerekmez.
const INTERIOR_DOOR_LAYER := "Kapı"
## SADECE "Kapı" katmanı iç sahnede bulunamazsa (eski bake, katman yeniden adlandırılmış)
## kullanılan yedek çıkış alanı: eski kapı bölgesi. Oyuncu içeride hapsolmasın diye.
const FALLBACK_INTERIOR_EXIT_POS := Vector2(160.0, 306.0)
const FALLBACK_INTERIOR_EXIT_RADIUS := 50.0

## Kullanıcı isteği (ev içi güncellemesi): "kapı, eşya alt, zemin ve iç oda giriş haricindeki
## TÜM layerlara collision shape ile kapla, eşyaları ve duvarları kapsadığı için oyuncular
## içinden geçememeli". Çarpışması OLMAYAN katmanlar (Tiled'daki tam adlarıyla) - bunların
## DIŞINDAKİ her TileMapLayer (Duvarlar, Duvarlar -1, iki "ekstra" ...) kaplanır. Dışlama
## listesi bilerek: aynı adlı ikinci "ekstra" katmanı Godot'ta otomatik ad aldığı için
## ("@TileMapLayer@3") isimle "dahil etme" yerine isimle "hariç tutma" güvenilir.
const INTERIOR_NO_COLLISION_LAYERS: Array[String] = ["Kapı", "Eşya alt", "zemin", "İç oda giriş"]
## Ev içi çarpışma gövdelerinin (InteriorBounds + InteriorCollision) fizik katmanı BİT DEĞERİ
## (8 = 4. katman). KÖK NEDEN NOTU (kullanıcı bildirimi: "evin duvarlarını collision shape ile
## kaplamamışsın"): player.tscn'de collision_mask = 0 (yaratıklar oyuncuyu duvara
## sıkıştırmasın diye bilerek sıfırlandı, bkz. player.gd _block_movement_into_enemies notu) -
## yani oyuncunun fizik gövdesi HİÇBİR statik gövdeye çarpmıyor. Eskiden burada 4 kullanılıyordu
## ("player'ın maskesi 4" varsayımı bayattı; 4 aynı zamanda yaratık katmanı): şekiller ve
## çevre duvarı oyuncuyu hiç durdurmuyordu. Artık ayrı, başka hiçbir yerde kullanılmayan bir
## katman (8) ve oyuncunun maskesine SADECE içerideyken eklenir (bkz. _do_enter_house/
## _do_exit_house) - dışarıdaki oyuncu/yaratık davranışı hiç değişmez.
const INTERIOR_COLLISION_LAYER := 8

## DÜZELTME (kullanıcı bildirimi: "evden çıkınca eski konumundan çıkıyor, evin
## konumu değişti"): dışarıdaki evin konumu eskiden BURADA sabit koordinatlarla
## tutuluyordu (3032,1912) - ev Tiled'da taşınınca (şimdi x:[1854,2030] y:[1237,1365])
## giriş tetikleyicisi ve oyun başındaki dönüş noktası eski yerde kaldı. Artık ikisi
## de çalışma anında haritadaki "ev/Ev" katmanından türetiliyor (bkz.
## _locate_exterior_house) - ev bir daha taşınırsa kod değişikliği gerekmez. Aşağıdaki
## iki FALLBACK sabiti SADECE harita sahnede yokken (testler, ana menü) kullanılır;
## yeni evin ölçülmüş konumudur (main.tscn'deki (-2,21) harita kaymasıyla dünya
## koordinatı).
const FALLBACK_EXTERIOR_ENTRANCE_POS := Vector2(1942.0, 1357.0)
const EXTERIOR_ENTRANCE_RADIUS := 55.0

## Kullanıcı bildirimi: "oyun başında evden çıkarken evin kapısında takılı
## kalıyor karakterim" - _do_exit_house() normalde _exterior_return_pos'u
## kullanır, ve bu değer normal (F ile) girişte oyuncunun O ANDA GERÇEKTEN
## DURDUĞU - yürüyerek ulaştığı, dolayısıyla çarpışmasız - konumdan alınır.
## Ama oyun başlangıcındaki OTOMATİK girişte (bkz. _ready()) oyuncu hiç
## yürümedi; sahnede tanımlı ham başlangıç konumu (main.tscn Player) evin
## güney duvarına denk gelebiliyor ve oyuncu oraya ışınlanınca duvarın/kapı
## eşiğinin çarpışma sınırına gömülüp kıpırdayamıyordu. Oyun başlangıcı için
## evin biraz GÜNEYİNDE, duvardan kesin uzak, su/ev/orman karosu OLMAYAN bir
## dönüş noktası kullanılıyor (bkz. _locate_exterior_house) - hâlâ
## EXTERIOR_ENTRANCE_RADIUS içinde kalıyor.
const FALLBACK_EXTERIOR_SAFE_RETURN_POS := Vector2(1926.0, 1389.0)

## Haritadaki evin (Tiled "ev" grubundaki "Ev" katmanı) sahne yolu - HouseInterior
## main.tscn'de Harita'nın kardeşi. Su/orman katmanları güvenli dönüş noktasının
## engelsiz olduğunu doğrulamak için.
const HOUSE_LAYER_PATH := "../Harita/ev/Ev"
const BLOCKING_LAYER_PATHS: Array[String] = [
	"../Harita/ev/Ev",
	"../Harita/Su/Su",
	"../Harita/Orman parçaları/Orman parçaları",
]

## _locate_exterior_house() tarafından haritadan çözülür (bkz. oradaki not).
var _exterior_entrance_pos: Vector2 = FALLBACK_EXTERIOR_ENTRANCE_POS
var _exterior_safe_return_pos: Vector2 = FALLBACK_EXTERIOR_SAFE_RETURN_POS

var _player: CharacterBody2D = null
var _interior_instance: Node2D = null
var _entrance_area: Area2D = null
var _exit_area: Area2D = null
var _prompt_label: Label = null

var _near_entrance: bool = false

## Kullanıcı isteği: "oyunda evin içindeyken ortam müziğinin çalmasını
## istemiyorum ve rüzgar efektinin olduğu canvaslayer'ın gözükmesini
## istemiyorum." - evin DIŞINA ait iki atmosfer öğesi:
##   _wind_layer  = harita sahnesindeki rüzgar katmanı (harita_baked.tscn ->
##                  "Harita/CanvasLayer", içindeki ColorRect "rüzgar efekti"
##                  shader'ını kullanıyor; ekranın üstüne rüzgar çizgileri
##                  çizen bir kaplama).
##   _ambient_player = main.gd'nin oluşturduğu ortam müziği düğümü
##                  ("WindBreezeAmbient", bkz. wind_breeze_ambient.gd ->
##                  forest_ambient.mp3 döngüde).
## İkisi de eve girince kapatılıyor, çıkınca geri açılıyor (bkz.
## _set_outdoor_atmosphere_enabled). Referanslar bir kez bulunup önbelleğe
## alınır; bulunamazlarsa (ör. main.gd onları house_interior'un _ready()'sinden
## SONRA oluşturuyorsa) _process içinde tekrar aranır.
var _wind_layer: CanvasLayer = null
var _ambient_player: AudioStreamPlayer = null


## Evin dışına ait atmosfer düğümlerini (rüzgar katmanı + ortam müziği) bulur.
## Zaten bulunmuş ve hâlâ geçerliyse hiçbir şey yapmaz.
func _find_outdoor_atmosphere() -> void:
	if not is_inside_tree():
		return
	var root: Node = get_tree().current_scene
	if root == null:
		return
	if _wind_layer == null or not is_instance_valid(_wind_layer):
		var map_node: Node = root.get_node_or_null("Harita")
		if map_node:
			_wind_layer = map_node.get_node_or_null("CanvasLayer") as CanvasLayer
	if _ambient_player == null or not is_instance_valid(_ambient_player):
		_ambient_player = root.get_node_or_null("WindBreezeAmbient") as AudioStreamPlayer


## enabled=false: içerideyiz -> rüzgar katmanı gizlenir, ortam müziği susar.
## enabled=true : dışarıdayız -> ikisi de geri gelir.
## Müzik stop() yerine stream_paused ile duraklatılıyor: döngü kaldığı yerden
## devam ediyor, eve girip çıkınca müzik baştan başlayıp "zıplamıyor".
func _set_outdoor_atmosphere_enabled(enabled: bool) -> void:
	_find_outdoor_atmosphere()
	if _wind_layer and is_instance_valid(_wind_layer):
		_wind_layer.visible = enabled
	if _ambient_player and is_instance_valid(_ambient_player):
		if enabled:
			_ambient_player.stream_paused = false
			if not _ambient_player.playing:
				_ambient_player.play()
		else:
			## Eve girerken müzik duraklatılır. Ambient düğümü henüz
			## oluşmamışsa (main.gd onu house_interior'un _ready()'sinden
			## sonra ekliyor) bu çağrı hiçbir şey bulamaz - _process'teki
			## "içerideyken referans eksikse tekrar dene" kontrolü bir
			## sonraki karede yakalayıp susturur.
			_ambient_player.stream_paused = true

var _exterior_return_pos: Vector2 = Vector2.ZERO

## Kullanıcı isteği: "bir evin içine girince veya çıkınca aniden girip
## çıkmasın ekran azcık kararsın ve sonra aydınlansın öyle giriş çıkışlar
## olsun" - scripts/splash_screen.gd ile AYNI ColorRect + Tween "renk alfası"
## deseni, giriş/çıkış anında burada tekrar kullanılıyor.
const FADE_DURATION := 0.22
var _fade_layer: CanvasLayer = null
var _fade_overlay: ColorRect = null
var _transitioning: bool = false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_locate_exterior_house()
	_spawn_interior()
	_create_entrance_trigger()
	_create_exit_trigger()
	_create_prompt_ui()

	# Kullanıcı isteği: Oyun başladığında karakter direkt evin içinde (yatağın
	# önünde) başlasın. Burada fade YOK - oyun zaten yeni başlıyor, geçiş
	# efekti sadece oyuncunun F ile tetiklediği GERÇEK giriş/çıkışlarda
	# anlamlı (bkz. _enter_house/_exit_house).
	if is_instance_valid(_player):
		_do_enter_house()
		## bkz. FALLBACK_EXTERIOR_SAFE_RETURN_POS üstündeki not - _do_enter_house()'un
		## az önce yakaladığı ham (main.tscn'deki, eski evin yerinde kalmış olabilen)
		## başlangıç konumunu, haritadaki GÜNCEL evin güneyindeki güvenli bir
		## konumla değiştiriyoruz.
		_exterior_return_pos = _exterior_safe_return_pos


## Dışarıdaki evin giriş noktasını ve oyun başındaki güvenli dönüş noktasını
## haritadaki "ev/Ev" katmanından çözer (bkz. FALLBACK_EXTERIOR_ENTRANCE_POS üstündeki
## DÜZELTME notu). Harita/katman yoksa ya da boşsa FALLBACK değerleri kalır.
##  - Ev = katmandaki EN BÜYÜK bitişik (8 komşuluk) hücre kümesi; ev dışında kalmış
##    tek tük artık karolar (Tiled'da ev taşınırken geride bırakılanlar) yok sayılır.
##  - Giriş = evin güney (alt) duvarının orta hücresi, hücrenin dünya merkezi
##    (harita kaymasıyla birlikte - katmanın global dönüşümü kullanılır).
##  - Güvenli dönüş = girişin 2-6 hücre güneyinde, su/ev/orman karosu olmayan ilk
##    hücre (önce bir hücre batıya, eski düzenle aynı, sonra doğuya/yanlara).
func _locate_exterior_house() -> void:
	_exterior_entrance_pos = FALLBACK_EXTERIOR_ENTRANCE_POS
	_exterior_safe_return_pos = FALLBACK_EXTERIOR_SAFE_RETURN_POS
	var house_layer: TileMapLayer = get_node_or_null(HOUSE_LAYER_PATH) as TileMapLayer
	if house_layer == null:
		return
	var rect: Rect2i = _largest_cluster_rect(house_layer)
	if rect.size == Vector2i.ZERO:
		return
	var door_cell := Vector2i(rect.position.x + rect.size.x / 2, rect.end.y - 1)
	_exterior_entrance_pos = house_layer.to_global(house_layer.map_to_local(door_cell))
	_exterior_safe_return_pos = _exterior_entrance_pos + Vector2(-16.0, 32.0)
	var blockers: Array[TileMapLayer] = []
	for path: String in BLOCKING_LAYER_PATHS:
		var layer: TileMapLayer = get_node_or_null(path) as TileMapLayer
		if layer != null:
			blockers.append(layer)
	for dy: int in range(2, 7):
		for dx: int in [-1, 0, 1, -2, 2]:
			var world: Vector2 = house_layer.to_global(house_layer.map_to_local(door_cell + Vector2i(dx, dy)))
			if _cell_is_free(blockers, world):
				_exterior_safe_return_pos = world
				return


## `world` konumundaki hücre verilen katmanların HİÇBİRİNDE dolu değilse true.
func _cell_is_free(layers: Array[TileMapLayer], world: Vector2) -> bool:
	for layer: TileMapLayer in layers:
		if layer.get_cell_source_id(layer.local_to_map(layer.to_local(world))) != -1:
			return false
	return true


## `layer`daki en büyük 8-komşuluklu bitişik hücre kümesinin hücre dikdörtgeni
## (son hücre DAHİL; katman boşsa boş Rect2i).
static func _largest_cluster_rect(layer: TileMapLayer) -> Rect2i:
	var remaining: Dictionary = {}
	var used: Array[Vector2i] = layer.get_used_cells()
	for cell: Vector2i in used:
		remaining[cell] = true
	var best_size: int = 0
	var best_rect := Rect2i()
	for start: Vector2i in used:
		if not remaining.has(start):
			continue
		remaining.erase(start)
		var stack: Array[Vector2i] = [start]
		var count: int = 0
		var min_cell: Vector2i = start
		var max_cell: Vector2i = start
		while not stack.is_empty():
			var cell: Vector2i = stack.pop_back()
			count += 1
			min_cell = Vector2i(mini(min_cell.x, cell.x), mini(min_cell.y, cell.y))
			max_cell = Vector2i(maxi(max_cell.x, cell.x), maxi(max_cell.y, cell.y))
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var neighbor := Vector2i(cell.x + dx, cell.y + dy)
					if remaining.has(neighbor):
						remaining.erase(neighbor)
						stack.append(neighbor)
		if count > best_size:
			best_size = count
			best_rect = Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)
	return best_rect


func _spawn_interior() -> void:
	_interior_instance = InteriorScene.instantiate()
	_interior_instance.position = INTERIOR_OFFSET
	_interior_instance.visible = false
	add_child(_interior_instance)

	## İç mekanı görünmeyen bir sınırla çevreler - tmx'te henüz gerçek duvar
	## çarpışma verisi yok (Tiled tarafında hiçbir tile için collision objesi
	## tanımlanmamış), bu olmadan oyuncu dekore edilmiş zeminin dışına,
	## boş/karanlık alana yürüyebilirdi.
	var walls := StaticBody2D.new()
	walls.name = "InteriorBounds"
	walls.collision_layer = INTERIOR_COLLISION_LAYER
	walls.collision_mask = 0
	walls.position = INTERIOR_OFFSET
	add_child(walls)
	var size: Vector2 = ROOM_MAX - ROOM_MIN
	var center: Vector2 = (ROOM_MIN + ROOM_MAX) * 0.5
	_add_wall_segment(walls, Vector2(center.x, ROOM_MIN.y - WALL_THICKNESS * 0.5), Vector2(size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS))
	_add_wall_segment(walls, Vector2(center.x, ROOM_MAX.y + WALL_THICKNESS * 0.5), Vector2(size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS))
	_add_wall_segment(walls, Vector2(ROOM_MIN.x - WALL_THICKNESS * 0.5, center.y), Vector2(WALL_THICKNESS, size.y + WALL_THICKNESS * 2.0))
	_add_wall_segment(walls, Vector2(ROOM_MAX.x + WALL_THICKNESS * 0.5, center.y), Vector2(WALL_THICKNESS, size.y + WALL_THICKNESS * 2.0))

	_add_interior_collisions()
	_add_black_backdrop()


## Ev içindeyken oda içeriğinin (VIGNETTE_MIN/MAX) hemen dışını düz siyaha
## boyar - kullanıcı isteği: "smooth vinyet efektini iptal et en iyisi siyah
## olsun evin dışı" (yumuşak geçiş kaldırıldı, sert/dolgun siyah kullanılıyor).
## Oda etrafını çevreleyen 4 dikdörtgen ("çerçeve") ile yapılıyor - ortadaki
## delik tam VIGNETTE_MIN/MAX dikdörtgeni, yani oda içeriğinin kendisi hiç
## kapatılmıyor. _interior_instance'ın SON çocukları olarak ekleniyor ki tüm
## zemin/duvar/eşya katmanlarının ÜSTÜNDE çizilsinler; interior_instance.
## visible ile birlikte otomatik gizlenip/gösteriliyorlar.
func _add_black_backdrop() -> void:
	var rect := ColorRect.new()
	rect.name = "IndoorBackdrop"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0.0, 0.0, 0.0, 1.0)
	# Çok büyük bir siyah arka plan oluşturup en arkaya koyuyoruz.
	# Böylece hem evin dışı tamamen siyah olur, hem de duvar kenarlarındaki
	# yarı saydam piksellerin arkasından gri ekran arkaplanı görünmez.
	rect.position = Vector2(-VIGNETTE_SIZE, -VIGNETTE_SIZE)
	rect.size = Vector2(VIGNETTE_SIZE * 2.0, VIGNETTE_SIZE * 2.0)
	
	# add_child yerine, TileMapLayer'ların ARKASINDA çizilmesi için en başa ekliyoruz.
	_interior_instance.add_child(rect)
	_interior_instance.move_child(rect, 0)


func _add_wall_segment(parent: StaticBody2D, center: Vector2, size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = center
	parent.add_child(shape)


func _create_entrance_trigger() -> void:
	_entrance_area = Area2D.new()
	_entrance_area.name = "HouseEntranceTrigger"
	_entrance_area.collision_layer = 0
	_entrance_area.collision_mask = 2 ## bkz. main.tscn Player collision_layer = 2
	_entrance_area.position = _exterior_entrance_pos
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = EXTERIOR_ENTRANCE_RADIUS
	shape.shape = circle
	_entrance_area.add_child(shape)
	add_child(_entrance_area)
	_entrance_area.body_entered.connect(_on_entrance_body_entered)
	_entrance_area.body_exited.connect(_on_entrance_body_exited)


## Kullanıcı isteği (ev içi güncellemesi) - bkz. INTERIOR_NO_COLLISION_LAYERS. İç sahnedeki
## çarpışması olması gereken TÜM TileMapLayer'ların dolu hücrelerini TEK bir doluluk
## ızgarasında birleştirip (katmanlar üst üste binse de çift şekil olmasın) hücreye TAM
## oturan dikdörtgen çarpışma şekillerine böler: yatay olarak bitişik hücreler önce
## satır parçalarına, aynı genişlikteki üst üste satırlar da tek dikdörtgene birleşir.
## Bu, birebir hücre-hücre kare koymaya göre AYNI alanı kaplar ama şekiller arası dikişleri
## azaltır (CharacterBody2D'nin dikişlerde takılması azalır). Çalışma anında üretildiği
## için ev içi Tiled'da değişip yeniden bake edilse de otomatik güncel kalır.
func _add_interior_collisions() -> void:
	var cells: Dictionary = {} ## Vector2i (dünya hücresi, iç sahne yerelinde) -> true
	var tile_size := Vector2i(16, 16)
	var origin := Vector2.ZERO
	var found_layer: bool = false
	for child: Node in _interior_instance.get_children():
		var layer := child as TileMapLayer
		if layer == null or INTERIOR_NO_COLLISION_LAYERS.has(String(layer.name)):
			continue
		if layer.tile_set != null:
			tile_size = layer.tile_set.tile_size
		origin = layer.position
		found_layer = true
		for cell: Vector2i in layer.get_used_cells():
			cells[cell] = true
	if not found_layer or cells.is_empty():
		return
	var body := StaticBody2D.new()
	body.name = "InteriorCollision"
	body.collision_layer = INTERIOR_COLLISION_LAYER
	body.collision_mask = 0
	body.position = INTERIOR_OFFSET
	add_child(body)
	for rect: Rect2i in _merge_cells_into_rects(cells):
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(rect.size.x * tile_size.x, rect.size.y * tile_size.y)
		shape.shape = box
		shape.position = origin + Vector2(rect.position.x * tile_size.x, rect.position.y * tile_size.y) + box.size * 0.5
		body.add_child(shape)


## Hücre kümesini (Vector2i -> true) çakışmayan hücre dikdörtgenlerine böler: satır satır
## (soldan sağa) bitişik hücre parçaları, aynı [x0,x1] aralığına sahip ardışık satırlar
## dikeyde birleştirilir.
static func _merge_cells_into_rects(cells: Dictionary) -> Array[Rect2i]:
	var rows: Dictionary = {} ## y -> Array[int] (sıralı x'ler)
	for cell: Vector2i in cells:
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)
	var ys: Array = rows.keys()
	ys.sort()
	var result: Array[Rect2i] = []
	var open_runs: Dictionary = {} ## Vector2i(x0, x1) -> başlangıç y (henüz kapanmamış dikdörtgen)
	var prev_y: int = 0
	for y: int in ys:
		var xs: Array = rows[y]
		xs.sort()
		## Bu satırın bitişik hücre parçaları
		var runs: Array[Vector2i] = []
		var start: int = xs[0]
		var last: int = xs[0]
		for i: int in range(1, xs.size()):
			if xs[i] == last + 1:
				last = xs[i]
			else:
				runs.append(Vector2i(start, last))
				start = xs[i]
				last = xs[i]
		runs.append(Vector2i(start, last))
		## Bir önceki satırla bitişik değilse (arada boş satır) açık dikdörtgenlerin hepsini kapat.
		if not open_runs.is_empty() and y != prev_y + 1:
			for key: Vector2i in open_runs:
				var y0: int = open_runs[key]
				result.append(Rect2i(key.x, y0, key.y - key.x + 1, prev_y - y0 + 1))
			open_runs.clear()
		var next_open: Dictionary = {}
		for run: Vector2i in runs:
			if open_runs.has(run):
				next_open[run] = open_runs[run] ## aynı aralık: dikeyde uzat
				open_runs.erase(run)
			else:
				next_open[run] = y
		## Devam etmeyenleri kapat
		for key: Vector2i in open_runs:
			var y0: int = open_runs[key]
			result.append(Rect2i(key.x, y0, key.y - key.x + 1, prev_y - y0 + 1))
		open_runs = next_open
		prev_y = y
	for key: Vector2i in open_runs:
		var y0: int = open_runs[key]
		result.append(Rect2i(key.x, y0, key.y - key.x + 1, prev_y - y0 + 1))
	return result


## Kullanıcı isteği (ev içi güncellemesi): dışarı çıkış "Kapı" katmanına basınca - bkz.
## INTERIOR_DOOR_LAYER. Katmanın her dolu hücresi için bir dikdörtgen alan (oyuncunun
## gövdesi kapı karosuna değince tetiklenir). Katman yoksa yedek dairesel alan.
func _create_exit_trigger() -> void:
	_exit_area = Area2D.new()
	_exit_area.name = "HouseExitTrigger"
	_exit_area.collision_layer = 0
	_exit_area.collision_mask = 2
	_exit_area.position = INTERIOR_OFFSET
	var door_layer: TileMapLayer = _interior_instance.get_node_or_null(INTERIOR_DOOR_LAYER) as TileMapLayer
	var door_cells: Array[Vector2i] = []
	if door_layer != null:
		door_cells = door_layer.get_used_cells()
	if door_cells.is_empty():
		push_warning("HouseInterior: iç sahnede '%s' katmanı yok/boş - yedek çıkış alanı kullanılıyor" % INTERIOR_DOOR_LAYER)
		var fallback := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = FALLBACK_INTERIOR_EXIT_RADIUS
		fallback.shape = circle
		fallback.position = FALLBACK_INTERIOR_EXIT_POS
		_exit_area.add_child(fallback)
	else:
		var tile_size := Vector2(door_layer.tile_set.tile_size) if door_layer.tile_set != null else Vector2(16.0, 16.0)
		for cell: Vector2i in door_cells:
			var shape := CollisionShape2D.new()
			var box := RectangleShape2D.new()
			box.size = tile_size
			shape.shape = box
			shape.position = door_layer.position + door_layer.map_to_local(cell)
			_exit_area.add_child(shape)
	add_child(_exit_area)
	_exit_area.body_entered.connect(_on_exit_body_entered)


func _create_prompt_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HouseInteriorPromptLayer"
	layer.layer = 50
	add_child(layer)
	_prompt_label = Label.new()
	_prompt_label.name = "InteractPrompt"
	_prompt_label.add_theme_font_size_override("font_size", 24)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.offset_left = -180.0
	_prompt_label.offset_right = 180.0
	_prompt_label.offset_top = -170.0
	_prompt_label.offset_bottom = -130.0
	_prompt_label.visible = false
	layer.add_child(_prompt_label)


func _on_entrance_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_near_entrance = true


func _on_entrance_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_near_entrance = false


## Oyuncunun gövdesi "Kapı" katmanının bir karosuna değdi -> dışarı çık (F GEREKMEZ).
func _on_exit_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or _transitioning:
		return
	if not bool(body.get("is_indoors")):
		return
	_exit_house()


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(_player):
			return
	## Geçiş (fade) sürerken tekrar F'ye basılıp _enter_house/_exit_house'un
	## üst üste tetiklenmesini engelle.
	if _transitioning:
		return

	var indoors: bool = bool(_player.get("is_indoors"))
	## Kullanıcı isteği: içerideyken ortam müziği + rüzgar katmanı kapalı
	## olmalı. Referanslar main.gd tarafından house_interior'un _ready()'sinden
	## SONRA oluşturulabildiği için (ör. oyun doğrudan evin içinde başlıyorsa)
	## bulunamadıkları sürece burada tekrar aranıp uygulanır - bulunduktan
	## sonra bu blok her karede sadece iki null kontrolü yapar.
	if indoors and (_wind_layer == null or _ambient_player == null):
		_set_outdoor_atmosphere_enabled(false)
	## "interact" (varsayılan BOŞLUK) - bkz. game_manager.gd _setup_input_actions. Chat kutusu
	## açıkken (bkz. player.gd is_chat_typing) mesaj içindeki "f" harfi
	## yanlışlıkla eve girip çıkmayı tetiklemesin.
	var f_just_pressed: bool = Input.is_action_just_pressed("interact") and not bool(_player.get("is_chat_typing"))

	## Ölü/yerde yatan (Suriyeli Hadime'nin hayaleti dahil) oyuncu kapının yanında düştüyse eve giremesin.
	if not indoors and _near_entrance and _player.get("is_dead") != true:
		_prompt_label.text = "Eve girmek için %s tuşuna bas" % GameManager.get_action_key_label("interact")
		_prompt_label.visible = true
		if f_just_pressed:
			_enter_house()
	else:
		_prompt_label.visible = false


## F'ye basınca çağrılır - ekranı kısaca karartıp asıl ışınlama/durum
## değişimini (_do_enter_house) kararmışken uygular, sonra tekrar aydınlatır.
func _enter_house() -> void:
	_near_entrance = false
	_transitioning = true
	await _fade_transition(_do_enter_house)
	_transitioning = false


func _exit_house() -> void:
	_transitioning = true
	await _fade_transition(_do_exit_house)
	_transitioning = false


## Gerçek ışınlama/durum değişimi - fade YOK, hem _enter_house/_exit_house'un
## karardığı anda çağırdığı hem de _ready()'nin oyun başında ANINDA (geçişsiz)
## kullandığı çekirdek mantık burada.
func _do_enter_house() -> void:
	_exterior_return_pos = _player.global_position
	_player.global_position = INTERIOR_OFFSET + INTERIOR_SPAWN_POS
	_player.reset_physics_interpolation() ## ışınlama: kamera eski yerden kaymasın (bkz. physics_interp.gd)
	_player.is_indoors = true
	## Oyuncu fizik gövdesi içeride duvarlara/eşyalara çarpsın (bkz. INTERIOR_COLLISION_LAYER).
	_player.collision_mask = int(_player.collision_mask) | INTERIOR_COLLISION_LAYER
	_interior_instance.visible = true
	_near_entrance = false
	_set_combat_visuals_hidden(true)
	## Kullanıcı isteği: içerideyken ortam müziği çalmasın ve rüzgar efekti
	## katmanı görünmesin (bkz. _set_outdoor_atmosphere_enabled).
	_set_outdoor_atmosphere_enabled(false)


func _do_exit_house() -> void:
	_player.global_position = _exterior_return_pos
	_player.reset_physics_interpolation() ## ışınlama: kamera eski yerden kaymasın (bkz. physics_interp.gd)
	_player.is_indoors = false
	_player.collision_mask = int(_player.collision_mask) & ~INTERIOR_COLLISION_LAYER
	_interior_instance.visible = false
	_set_combat_visuals_hidden(false)
	## Dışarı çıkınca ortam müziği ve rüzgar efekti geri gelir.
	_set_outdoor_atmosphere_enabled(true)


func _ensure_fade_overlay() -> void:
	if _fade_layer and is_instance_valid(_fade_layer):
		return
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "HouseFadeLayer"
	_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_layer.layer = 95 ## ipucu katmanının (50) üstünde
	add_child(_fade_layer)
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_overlay)


## Ekranı karartıp (fade in), kararmışken `apply_change`'i çalıştırıp, tekrar
## aydınlatır (fade out) - giriş/çıkış artık ani bir kesme yerine yumuşak bir
## geçişle oluyor (bkz. sınıf üstü FADE_DURATION notu).
func _fade_transition(apply_change: Callable) -> void:
	_ensure_fade_overlay()
	var tw_in := create_tween()
	tw_in.tween_property(_fade_overlay, "color:a", 1.0, FADE_DURATION)
	await tw_in.finished
	apply_change.call()
	var tw_out := create_tween()
	tw_out.tween_property(_fade_overlay, "color:a", 0.0, FADE_DURATION)
	await tw_out.finished


## Kullanıcı bildirimi: "Necromancerin golemi evin içine gelmemeli ve
## karakterin silahları içeride gözükmemeli" - silahlar (owned_weapon_nodes,
## oyuncunun çocuğu olduğu için zaten teleport ile birlikte içeri "geliyor")
## ve Necromancer'ın yaratıkları (_necro_active_pets - golem + iskeletler,
## sahibini uzaktan takip edip yetişmeye çalışıyor, bkz. golem_pet.gd/
## skeleton_pet.gd _process_movement) burada tamamen gizlenip işlemesi
## durduruluyor. process_mode = DISABLED, o node'un (ve varsa alt Timer'larının)
## HİÇBİR şey yapmamasını (ateş etmeme, hareket etmeme, yaşam süresi
## tükenmeme) garantiler - dışarı çıkınca INHERIT'e dönünce yaratıklar zaten
## var olan "sahipten çok uzaksa hemen yanına ışınlan" mantığıyla (bkz.
## CATCH_UP_DISTANCE) sorunsuz devam eder.
func _set_combat_visuals_hidden(hidden: bool) -> void:
	if not is_instance_valid(_player):
		return
	## bkz. player.gd set_combat_active() - eskiden buradaki döngüler elle
	## yazılıydı, artık seyyar satıcının güvenli bölgesiyle (bkz.
	## traveling_merchant.gd) PAYLAŞILAN tek bir yerden geliyor.
	if _player.has_method("set_combat_active"):
		_player.set_combat_active(not hidden)
