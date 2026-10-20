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

## 2026-10-19 (madde 310): iç mekan artık COZY EV (harita/cozy_ev.tmx, 40x21 karo; üreticisi tools/proto_20261019/cozy_ev/
## gen_cozy_ev.py). Odanın piksel sınırları: yan duvarların içi x:[16,624], kuzey duvar yüzünün tepesi y 48, alt kiriş y 336.
## Kapı/giriş-çıkış güney (alt) duvarın ortasında (sütun 24-26).
const ROOM_MIN := Vector2(16.0, 48.0)
const ROOM_MAX := Vector2(624.0, 336.0)
const WALL_THICKNESS := 16.0

## Kullanıcı isteği: "smooth vinyet efektini iptal et en iyisi siyah olsun
## evin dışı" - artık yumuşak geçiş YOK, oda içeriğinin (zemin+duvarlar,
## bkz. "Tile Layer 1"/"ekstra" katmanlarının ölçülen birleşik piksel sınırı
## x:[0,320] y:[64,320]) HEMEN dışı düz siyah dolgu ile kaplanıyor (bkz.
## _add_black_backdrop).
const VIGNETTE_MIN := Vector2(0.0, 32.0) ## cozy ev: çatı kirişi satırı (y 32..48) dahil
const VIGNETTE_MAX := Vector2(640.0, 336.0)
## Siyah dolgunun kapladığı alan (dünya birimi) - kamera hangi zoom'da
## olursa olsun görünen tüm boşluğu kaplayacak kadar büyük.
const VIGNETTE_SIZE := 3000.0

## Oyuncu içeri girince (ve oyun başında) belirdiği nokta: cozy evin girişinin hemen içi (giriş x 384..432, çıkış karoları y 320+).
const INTERIOR_SPAWN_POS := Vector2(408.0, 292.0)
## Kullanıcı isteği (ev içi güncellemesi): dışarı çıkış artık F ile DEĞİL - iç haritadaki
## "Kapı" katmanına (Tiled'da "Kapı" adlı tile layer) basınca oluyor; F sadece DIŞARIDAN
## içeri girmek için kalıyor. Çıkış tetikleyicisi çalışma anında bu katmanın hücrelerinden
## üretilir (bkz. _create_exit_trigger) - kapı Tiled'da taşınırsa kod değişikliği gerekmez.
const INTERIOR_DOOR_LAYER := "Kapı"
## SADECE "Kapı" katmanı iç sahnede bulunamazsa (eski bake, katman yeniden adlandırılmış)
## kullanılan yedek çıkış alanı: eski kapı bölgesi. Oyuncu içeride hapsolmasın diye.
const FALLBACK_INTERIOR_EXIT_POS := Vector2(408.0, 328.0)
const FALLBACK_INTERIOR_EXIT_RADIUS := 50.0

## Kullanıcı isteği (ev içi güncellemesi): "kapı, eşya alt, zemin ve iç oda giriş haricindeki
## TÜM layerlara collision shape ile kapla, eşyaları ve duvarları kapsadığı için oyuncular
## içinden geçememeli". Çarpışması OLMAYAN katmanlar (Tiled'daki tam adlarıyla) - bunların
## DIŞINDAKİ her TileMapLayer (Duvarlar, Duvarlar -1, iki "ekstra" ...) kaplanır. Dışlama
## listesi bilerek: aynı adlı ikinci "ekstra" katmanı Godot'ta otomatik ad aldığı için
## ("@TileMapLayer@3") isimle "dahil etme" yerine isimle "hariç tutma" güvenilir.
## "Oda kapıları" (cozy ev, madde 310): yatak odası kütük kapıları çarpışmasız - biri (oyuncu/kukla/babaanne) yaklaşınca açılır
## (bkz. _process_room_doors), kapalı kapıya çarpmak hiç olmaz.
const INTERIOR_NO_COLLISION_LAYERS: Array[String] = ["Kapı", "Eşya alt", "zemin", "İç oda giriş", "Oda kapıları"]
## Bir karonun çarpışma vermesi için opak (alfa > 0,5) piksel oranı: mobilyanın saydam taşan kenarları (lamba başı, koltuk/kitaplık
## kenarı, mum ışıltısı) görünmez duvar olmasın. Duvar/zemin karoları tam doludur.
const COLLISION_MIN_COVER := 0.2
const ROOM_DOOR_LAYER := "Oda kapıları"
const ROOM_DOOR_OPEN_RADIUS := 30.0 ## kapının alt ortasına bu kadar yaklaşan (dünya px) kapıyı açar
const ROOM_DOOR_FRAME_TIME := 0.07
const ROOM_DOOR_FRAMES := 4 ## Kutuk_kapi.png: kare k = atlas sütun 2k..2k+1
const WINDOW_TEX_NAME := "Pencere.png" ## kare 0 gece (orijinal cam), kare 1 gündüz (parlak cam)
const WINDOW_DAY_BELOW := 0.5 ## AtmosphereMath.darkness bunun altındayken gündüz camı
const BabaanneNpcScript := preload("res://scripts/babaanne_npc.gd")
const CozyEvLightScript := preload("res://scripts/cozy_ev_light.gd") ## iç ışık (madde 311)
const AtmosphereMath := preload("res://scripts/atmosphere_math.gd")
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
var exterior_house_rect: Rect2 = Rect2() ## dışarıdaki evin dünya dikdörtgeni (harita yoksa boş)

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
	_setup_room_doors()
	_setup_windows()
	_setup_lighting()
	_spawn_babaanne()
	_setup_depth() ## madde 313: eşya/duvar ön kopyaları (arkasındaki karakteri örter)
	_setup_siege()
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
		## Açılış (madde 313): yeni koşuda herkes evde dinlenirken başlar - oturan/duran yerler + deprem + geri sayım.
		if _intro_wanted():
			_intro.begin()
			place_player_for_intro()


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
	## evin dünya dikdörtgeni (kuşatmacılar duvar diplerine yürür, madde 313)
	var half: Vector2 = Vector2(house_layer.tile_set.tile_size) * 0.5
	var tl: Vector2 = house_layer.to_global(house_layer.map_to_local(rect.position) - half)
	var br: Vector2 = house_layer.to_global(house_layer.map_to_local(rect.end - Vector2i.ONE) + half)
	exterior_house_rect = Rect2(tl, br - tl)
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
	var rects: Array[Rect2] = collision_rects()
	if rects.is_empty():
		return
	var body := StaticBody2D.new()
	body.name = "InteriorCollision"
	body.collision_layer = INTERIOR_COLLISION_LAYER
	body.collision_mask = 0
	body.position = INTERIOR_OFFSET
	add_child(body)
	for r: Rect2 in rects:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = r.size
		shape.shape = box
		shape.position = r.position + r.size * 0.5
		body.add_child(shape)


## ÇARPIŞMA v2 + DERİNLİK (madde 313, kullanıcı: "evin içindeki collisionlar kötü ve kocamanlar, Y ekseni ayarı yok, kapıdan geçince
## odaların duvarı üstümde görünmüyor"). Eskiden %20 opak her karo tam 16x16 engeldi (koltuk sırtı, kitaplığın üstü dahil) ve oyuncunun
## dairesi gövde ortasındaydı (ayağın ~12 px üstü, 8 px) -> eşyaya önden ~20 px'ten fazla yaklaşılamıyordu.
##  - Eşya / duvar katmanlarında (FOOT_LAYERS) NESNE = atlasta komşu karolar (depth_occluders.gd object_bases ile aynı kural); nesnenin kökü
##    (en alt opak satır) ile tepesi arasındaki yüksekliğin FOOT_DEPTH_RATIO'su kadar (FOOT_DEPTH_MIN..MAX) ALT BANT, opak piksellerin enine
##    kırpılmış, ayak izi engeli. "Duvarlar"da TALL_WALL'dan uzun sütun (odaları ayıran dikey duvar) boydan boya engel.
##  - "Duvar yüzü" (arka duvar) eskisi gibi karo bazlı (COLLISION_MIN_COVER).
##  - Oyuncu içerideyken çarpışma dairesi AYAĞINA iner (INDOOR_FOOT_RADIUS, _set_indoor_collider) - ayak izine önden tabana kadar yaklaşır,
##    arkasına geçince nesne onu örter (DEPTH_LAYERS ön kopyaları, depth_occluders.gd setup_interior; yatak odası ön duvarı + kapı dahil).
const FOOT_LAYERS: Array[String] = ["Duvarlar", "ekstra", "ekstra 2"]
const FULL_LAYERS: Array[String] = ["Duvar yüzü"]
## "Oda kapıları" BİLEREK yok: açık kapı karelerinin aralığı zemin pikseliyle dolu ve ön kopya kapının açılıp kapanmasını izlemez - kapı
## aralığındaki karakteri örterdi. Odaya girerken kapının iki yanındaki duvar sütunları karakteri örter.
const DEPTH_LAYERS: Array = ["Duvarlar", "Duvar süsü", "ekstra", "ekstra 2", "Eşya üst", "Eşya üst 2"]
const FOOT_DEPTH_MIN := 8.0
const FOOT_DEPTH_MAX := 40.0
const FOOT_DEPTH_RATIO := 0.6
const FOOT_LIFT := 4.0 ## bant tabanı kökün bu kadar üstünde: ayak dairesinin yarıçapı (önden ayak tam tabana dayanır)
const TALL_WALL := 72.0
const INDOOR_FOOT_RADIUS := 4.0
const OPAQUE_A := 0.5
const DepthOccludersScript := preload("res://scripts/depth_occluders.gd")

var _cover_cache: Dictionary = {}
var _source_images: Dictionary = {}
var _collision_rects_cache: Array[Rect2] = []
var _collision_rects_built: bool = false


## İç sahne yerelinde engel dikdörtgenleri (önbellekli).
func collision_rects() -> Array[Rect2]:
	if _collision_rects_built:
		return _collision_rects_cache
	_collision_rects_built = true
	var out: Array[Rect2] = []
	for layer_name: String in FULL_LAYERS:
		var layer := _interior_instance.get_node_or_null(layer_name) as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		for cell: Vector2i in layer.get_used_cells():
			var sid: int = layer.get_cell_source_id(cell)
			var src := layer.tile_set.get_source(sid) as TileSetAtlasSource
			if src == null or _tile_cover(src, sid, layer.get_cell_atlas_coords(cell)) >= COLLISION_MIN_COVER:
				out.append(Rect2(layer.position + Vector2(cell) * 16.0, Vector2(16.0, 16.0)))
	for layer_name: String in FOOT_LAYERS:
		var layer := _interior_instance.get_node_or_null(layer_name) as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		for group: Array in _object_groups(layer, layer_name == "Duvarlar"):
			for r: Rect2 in _footprints(layer, group, layer_name == "Duvarlar"):
				if r.size.x > 0.0 and r.size.y > 0.0:
					out.append(r)
	_collision_rects_cache = out
	return out


## Atlasta komşu karolar (aynı kaynak + aynı yatay çevirme) tek nesne - depth_occluders.gd object_bases ile AYNI kural. wall: duvar katmanında
## üst üste her karo aynı sütun (dikey bölme duvarı aynı karonun tekrarı - atlas komşusu değil, yoksa kesik kesik engel çıkıyordu).
func _object_groups(layer: TileMapLayer, wall: bool = false) -> Array:
	var info: Dictionary = {}
	for cell: Vector2i in layer.get_used_cells():
		var td: TileData = layer.get_cell_tile_data(cell)
		info[cell] = [layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell), td != null and td.flip_h]
	var parent: Dictionary = {}
	for cell in info:
		parent[cell] = cell
	for cell: Vector2i in info:
		var a: Array = info[cell]
		var right: Vector2i = cell + Vector2i(1, 0)
		if info.has(right):
			var b: Array = info[right]
			if b[0] == a[0] and b[2] == a[2] and b[1] == a[1] + (Vector2i(-1, 0) if a[2] else Vector2i(1, 0)):
				_uf_union(parent, cell, right)
		var down: Vector2i = cell + Vector2i(0, 1)
		if info.has(down):
			var c: Array = info[down]
			if wall or (c[0] == a[0] and c[2] == a[2] and c[1] == a[1] + Vector2i(0, 1)):
				_uf_union(parent, cell, down)
	var groups: Dictionary = {}
	for cell: Vector2i in info:
		var root: Vector2i = _uf_find(parent, cell)
		if not groups.has(root):
			groups[root] = []
		groups[root].append(cell)
	return groups.values()


static func _uf_find(parent: Dictionary, c: Vector2i) -> Vector2i:
	while parent[c] != c:
		parent[c] = parent[parent[c]]
		c = parent[c]
	return c


static func _uf_union(parent: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var ra: Vector2i = _uf_find(parent, a)
	var rb: Vector2i = _uf_find(parent, b)
	if ra != rb:
		parent[rb] = ra


## Nesnenin ayak izi dikdörtgenleri (iç sahne yereli): opak piksel satırları -> kök (en alt) ve tepe; alt bant enine opak piksellere
## kırpılır. Uzun duvar (dikey bölme): karo karo opak genişlik, üst üste aynı genişlikteki parçalar birleşir (köşe kütük uçları şişirmesin).
func _footprints(layer: TileMapLayer, group: Array, wall: bool) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var rows: Dictionary = {} ## y -> Vector2(min x, max x + 1)
	for cell: Vector2i in group:
		_scan_cell(layer, cell, rows)
	if rows.is_empty():
		return out
	var ys: Array = rows.keys()
	ys.sort()
	var top: float = float(ys[0])
	var base: float = float(ys[ys.size() - 1]) + 1.0
	var h: float = base - top
	if wall and h > TALL_WALL:
		var cells: Array = group.duplicate()
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
		for cell: Vector2i in cells:
			var one: Dictionary = {}
			_scan_cell(layer, cell, one)
			if one.is_empty():
				continue
			var x0: float = INF
			var x1: float = -INF
			var y0: float = INF
			var y1: float = -INF
			for y in one:
				var sp: Vector2 = one[y]
				x0 = minf(x0, sp.x)
				x1 = maxf(x1, sp.y)
				y0 = minf(y0, float(y))
				y1 = maxf(y1, float(y) + 1.0)
			var r := Rect2(x0, y0, x1 - x0, y1 - y0)
			if not out.is_empty() and is_equal_approx(out[-1].position.x, r.position.x) and is_equal_approx(out[-1].end.x, r.end.x) 					and absf(out[-1].end.y - r.position.y) <= 1.0:
				out[-1] = out[-1].merge(r)
			else:
				out.append(r)
		if not out.is_empty():
			var last: Rect2 = out[-1]
			last.size.y = maxf(3.0, last.size.y - FOOT_LIFT) ## duvarın dibi: ayak dairesi tabana dayanır
			out[-1] = last
		return out
	out.append(_band_rect(rows, ys, base, h))
	return out


func _band_rect(rows: Dictionary, ys: Array, base: float, h: float) -> Rect2:
	var band_top: float = base - clampf((h - 16.0) * FOOT_DEPTH_RATIO, FOOT_DEPTH_MIN, FOOT_DEPTH_MAX)
	var band_bottom: float = base - FOOT_LIFT
	if band_bottom - band_top < 3.0:
		band_top = band_bottom - 3.0
	var x0: float = INF
	var x1: float = -INF
	for y in ys:
		if float(y) >= band_top and float(y) < base:
			var span: Vector2 = rows[y]
			x0 = minf(x0, span.x)
			x1 = maxf(x1, span.y)
	if not is_finite(x0):
		return Rect2()
	return Rect2(x0, band_top, x1 - x0, band_bottom - band_top)


## Karonun opak piksellerini satır satır (iç sahne yereli) rows'a ekler. Büyük karo (şömine 48x64) hücresinin sol-altına hizalı çizilir.
func _scan_cell(layer: TileMapLayer, cell: Vector2i, rows: Dictionary) -> void:
	var sid: int = layer.get_cell_source_id(cell)
	var src := layer.tile_set.get_source(sid) as TileSetAtlasSource
	if src == null or src.texture == null:
		return
	var atlas: Vector2i = layer.get_cell_atlas_coords(cell)
	if not src.has_tile(atlas):
		return
	if not _source_images.has(sid):
		var im: Image = src.texture.get_image()
		if im != null and im.is_compressed():
			im.decompress()
		_source_images[sid] = im
	var img: Image = _source_images[sid]
	if img == null:
		return
	var td: TileData = layer.get_cell_tile_data(cell)
	var flip_h: bool = td != null and td.flip_h
	var region: Rect2i = src.get_tile_texture_region(atlas)
	var ox: float = layer.position.x + float(cell.x) * 16.0
	var oy: float = layer.position.y + float(cell.y + 1) * 16.0 - float(region.size.y)
	for y in region.size.y:
		var lo: int = -1
		var hi: int = -1
		for x in region.size.x:
			var ax: int = region.size.x - 1 - x if flip_h else x
			if img.get_pixel(region.position.x + ax, region.position.y + y).a > OPAQUE_A:
				if lo < 0:
					lo = x
				hi = x
		if lo < 0:
			continue
		var wy: int = int(oy) + y
		var span := Vector2(ox + lo, ox + hi + 1)
		if rows.has(wy):
			var old: Vector2 = rows[wy]
			span = Vector2(minf(old.x, span.x), maxf(old.y, span.y))
		rows[wy] = span


## Engel hücreleri (iç sahne yereli): bir engel dikdörtgeninin %25'ten fazlasını kapladığı hücreler (babaanne yol bulması + testler).
func _collision_cells() -> Dictionary:
	var cells: Dictionary = {}
	for r: Rect2 in collision_rects():
		for cy in range(floori(r.position.y / 16.0), floori((r.end.y - 0.001) / 16.0) + 1):
			for cx in range(floori(r.position.x / 16.0), floori((r.end.x - 0.001) / 16.0) + 1):
				var cell_rect := Rect2(Vector2(cx, cy) * 16.0, Vector2(16.0, 16.0))
				var inter: Rect2 = cell_rect.intersection(r)
				if inter.get_area() >= 64.0 or r.has_point(cell_rect.get_center()):
					cells[Vector2i(cx, cy)] = true
	return cells


## İçerideyken oyuncunun çarpışma dairesi ayağa iner (küçük daire); çıkınca eski şekline döner.
var _saved_shape: Shape2D = null
var _saved_shape_pos: Vector2 = Vector2.ZERO


func _set_indoor_collider(on: bool) -> void:
	if not is_instance_valid(_player):
		return
	var cs := _player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		return
	if on:
		if _saved_shape == null:
			_saved_shape = cs.shape
			_saved_shape_pos = cs.position
		var sy: float = absf(_player.global_scale.y) if absf(_player.global_scale.y) > 0.001 else 1.0
		var c := CircleShape2D.new()
		c.radius = INDOOR_FOOT_RADIUS / sy
		cs.shape = c
		cs.position = Vector2(0.0, (PLAYER_FEET_OFFSET - INDOOR_FOOT_RADIUS) / sy)
	elif _saved_shape != null:
		cs.shape = _saved_shape
		cs.position = _saved_shape_pos
		_saved_shape = null


func _setup_depth() -> void:
	DepthOccludersScript.new().setup_interior(_interior_instance, DEPTH_LAYERS, _door_frame_tile_sets())


## KAPI ÇERÇEVESİ ön kopyası (madde 328, kullanıcı: "kapılardan geçerken kapının üstü üstümüzde görünmüyor, duvar da aynı şekilde, üstünden
## yürüyoruz"): kapı katmanı (ROOM_DOOR_LAYER) DEPTH_LAYERS'te olamaz (kare tamamen opak: açılan aralıktaki karakteri de örterdi, ön kopya animasyonu da
## izlemez) ama kapı kirişi + yan sütunlar duvarın parçası. Çözüm: karenin 4 açılma karesinde AYNI olan piksellerini (kiriş, sütunlar, eşik) taşıyan
## maskeli bir TileSet ile ön kopya - aralık (kanat + arkasındaki zemin, kareden kareye değişen pikseller) saydam. Kapı açılıp kapanırken çerçeve zaten sabit.
func _door_frame_tile_sets() -> Dictionary:
	var out: Dictionary = {}
	var layer := _interior_instance.get_node_or_null(ROOM_DOOR_LAYER) as TileMapLayer
	if layer == null or layer.tile_set == null or _room_doors.is_empty():
		return out
	var ts: TileSet = layer.tile_set.duplicate(true)
	var done: Dictionary = {}
	for d: Dictionary in _room_doors:
		var sid: int = int(d["sid"])
		if done.has(sid):
			continue
		done[sid] = true
		var src := ts.get_source(sid) as TileSetAtlasSource
		if src == null or src.texture == null:
			continue
		var img: Image = src.texture.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		src.texture = ImageTexture.create_from_image(door_frame_image(img, ROOM_DOOR_FRAMES))
	if not done.is_empty():
		out[ROOM_DOOR_LAYER] = ts
	return out


## Kapı sayfasından (yan yana `frames` açılma karesi, kare = 2 karo genişliğinde) her karede AYNI olan pikselleri taşıyan görüntü; farklı olanlar saydam.
static func door_frame_image(img: Image, frames: int) -> Image:
	var fw: int = 32
	var n: int = mini(frames, img.get_width() / fw)
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	if n <= 0:
		return out
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			var base: int = x % fw
			var same: bool = true
			for k in n:
				if img.get_pixel(k * fw + base, y) != c:
					same = false
					break
			if same:
				out.set_pixel(x, y, c)
	return out


## Karonun opak piksel oranı (0..1), kaynak + atlas başına önbellekli. Doku okunamazsa 1 (çarpışsın).
func _tile_cover(src: TileSetAtlasSource, sid: int, atlas: Vector2i) -> float:
	var key := Vector3i(sid, atlas.x, atlas.y)
	if _cover_cache.has(key):
		return _cover_cache[key]
	var cover: float = 1.0
	if src.texture != null:
		if not _source_images.has(sid):
			var img: Image = src.texture.get_image()
			if img != null and img.is_compressed():
				img.decompress()
			_source_images[sid] = img
		var img2: Image = _source_images[sid]
		if img2 != null:
			var r: Rect2i = src.get_tile_texture_region(atlas)
			var opaque: int = 0
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if img2.get_pixel(x, y).a > 0.5:
						opaque += 1
			cover = float(opaque) / float(maxi(1, r.size.x * r.size.y))
	_cover_cache[key] = cover
	return cover


## Babaanne NPC'sinin yürüyebileceği hücreler: zemin - çarpışma - çıkış kapısı (madde 310).
func walkable_cells() -> Dictionary:
	var floor_layer: TileMapLayer = _interior_instance.get_node_or_null("zemin") as TileMapLayer
	var out: Dictionary = {}
	if floor_layer == null:
		return out
	var blocked: Dictionary = _collision_cells()
	var exit_layer: TileMapLayer = _interior_instance.get_node_or_null(INTERIOR_DOOR_LAYER) as TileMapLayer
	if exit_layer != null:
		for c: Vector2i in exit_layer.get_used_cells():
			blocked[c] = true
	for c: Vector2i in floor_layer.get_used_cells():
		if not blocked.has(c):
			out[c] = true
	return out


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
	## 2026-09-27: alttaki oyuncu paneli (hud.gd dock + üstündeki buff satırı) ~-211'e kadar çıkıyor - ipucu onun üstünde.
	_prompt_label.offset_top = -262.0
	_prompt_label.offset_bottom = -222.0
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
	_process_room_doors(_delta)
	_process_windows(_delta)
	_process_seat_release()
	if not indoors and _near_entrance and _player.get("is_dead") != true and _siege != null and _siege.collapsed:
		## Ev yıkık (madde 313): kapı kapalı, dışarıda savaştıkça onarılır.
		_prompt_label.text = "Ev yıkıldı - onarılıyor %%%d (savaştıkça)" % int(round(_siege.ratio() / HouseSiege.REOPEN_RATIO * 100.0))
		_prompt_label.remove_from_group(&"interact_prompt")
		_prompt_label.visible = true
	elif not indoors and _near_entrance and _player.get("is_dead") != true:
		_prompt_label.text = "Eve girmek için %s tuşuna bas" % GameManager.get_action_key_label("interact")
		_prompt_label.add_to_group(&"interact_prompt") ## telefonda ETKİLEŞİM düğmesi bu uyarı görünürken çıkar (touch_controls.gd)
		_prompt_label.visible = true
		if f_just_pressed:
			_enter_house()
	elif indoors and _player.get("is_dead") != true and is_instance_valid(_babaanne) and _babaanne.can_talk(_player):
		## Babaanne (madde 310): yakındaki oyuncuya konuşma ipucu, etkileşim tuşu bir cümle söyletir.
		_prompt_label.text = "Babaanneyle konuşmak için %s" % GameManager.get_action_key_label("interact")
		_prompt_label.add_to_group(&"interact_prompt")
		_prompt_label.visible = true
		if f_just_pressed:
			_babaanne.talk(_player)
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
	_set_indoor_collider(true) ## madde 313: içeride çarpışma dairesi ayakta
	## Oyuncu fizik gövdesi içeride duvarlara/eşyalara çarpsın (bkz. INTERIOR_COLLISION_LAYER).
	_player.collision_mask = int(_player.collision_mask) | INTERIOR_COLLISION_LAYER
	_interior_instance.visible = true
	_near_entrance = false
	_set_combat_visuals_hidden(true)
	## Kullanıcı isteği: içerideyken ortam müziği çalmasın ve rüzgar efekti
	## katmanı görünmesin (bkz. _set_outdoor_atmosphere_enabled).
	_set_outdoor_atmosphere_enabled(false)


func _do_exit_house() -> void:
	if "intro_seat_face" in _player:
		_player.set("intro_seat_face", "") ## açılışta oturan oyuncu zorla çıkarılırsa (ev yıkıldı / geri katılım) dışarıda oturmasın
	_player.global_position = _exterior_return_pos
	_player.reset_physics_interpolation() ## ışınlama: kamera eski yerden kaymasın (bkz. physics_interp.gd)
	_player.is_indoors = false
	_set_indoor_collider(false)
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


# ------------------------------------------------------------------ cozy ev: babaanne, oda kapıları, pencereler (madde 310)

var _babaanne: BabaanneNpc = null
var _room_doors: Array[Dictionary] = [] ## {"layer", "sid", "origin": Vector2i, "frame": int, "acc": float}
var _windows: Array[Dictionary] = [] ## {"layer", "sid", "cell": Vector2i}
var _window_frame: int = -1
var _window_check: float = 0.0


func get_babaanne() -> BabaanneNpc:
	return _babaanne


var _light: CozyEvLight = null


func get_light() -> CozyEvLight:
	return _light


## Gece-gündüz İÇ IŞIĞI (madde 311, scripts/cozy_ev_light.gd): iç mekanın çocuğu - iç mekanla birlikte görünür/gizlenir, dış dünyaya
## dokunmaz. EV_ISIK=0: kurulmaz (FPS A/B, tools/fps_micro/proc_ab.ps1 -EnvA EV_ISIK=0 -EnvB EV_ISIK=1).
func _setup_lighting() -> void:
	if OS.get_environment("EV_ISIK") == "0":
		return
	_light = CozyEvLightScript.new()
	_interior_instance.add_child(_light)
	_light.setup(_interior_instance)


func _spawn_babaanne() -> void:
	var walk: Dictionary = walkable_cells()
	if walk.is_empty():
		return
	var door_local: Vector2 = FALLBACK_INTERIOR_EXIT_POS
	var exit_layer: TileMapLayer = _interior_instance.get_node_or_null(INTERIOR_DOOR_LAYER) as TileMapLayer
	if exit_layer != null and not exit_layer.get_used_cells().is_empty():
		door_local = Vector2.ZERO
		for c: Vector2i in exit_layer.get_used_cells():
			door_local += exit_layer.position + exit_layer.map_to_local(c)
		door_local /= float(exit_layer.get_used_cells().size())
	_babaanne = BabaanneNpcScript.new()
	_babaanne.house = self
	_interior_instance.add_child(_babaanne)
	_babaanne.window_feet = window_spot(walk)
	_babaanne.configure(_interior_instance, walk, Vector2(16.0, 16.0), INTERIOR_SPAWN_POS, door_local)
	if GameManager.babaanne_dead: ## (geri katılım / yeniden kurulum) bu koşuda zaten öldü
		_babaanne.queue_free()
		_babaanne = null


## Yatak odası kütük kapıları: katmandaki her 2x3 blok (kare 0 sol üst karosu atlas (0,0)) bir kapı. Açılma kareleri atlasta yoksa
## (YATI yalnız haritada kullanılan karoları kurar) burada eklenir.
func _setup_room_doors() -> void:
	_room_doors.clear()
	var layer: TileMapLayer = _interior_instance.get_node_or_null(ROOM_DOOR_LAYER) as TileMapLayer
	if layer == null or layer.tile_set == null:
		return
	for c: Vector2i in layer.get_used_cells():
		if layer.get_cell_atlas_coords(c) != Vector2i(0, 0):
			continue
		var sid: int = layer.get_cell_source_id(c)
		var src := layer.tile_set.get_source(sid) as TileSetAtlasSource
		if src == null:
			continue
		for k in ROOM_DOOR_FRAMES:
			for j in 3:
				for i in 2:
					var a := Vector2i(2 * k + i, j)
					if not src.has_tile(a):
						src.create_tile(a)
		_room_doors.append({"layer": layer, "sid": sid, "origin": c, "frame": 0, "acc": 0.0})


## Biri (yerel oyuncu, kukla, babaanne) kapı aralığının dikey ekseninin yakınındaysa kapı kare kare açılır, uzaklaşınca kapanır.
## Tamamen yerel/görsel (kapı çarpışmasız); herkes kendi ekranında aynı konumlardan aynı sonucu görür.
func _process_room_doors(delta: float) -> void:
	if _room_doors.is_empty() or not _interior_instance.visible:
		return
	var feet_pts: Array[Vector2] = []
	for p: Node2D in NpcActor.live_players(get_tree()):
		feet_pts.append(p.global_position)
	if is_instance_valid(_babaanne):
		feet_pts.append(_babaanne.global_position)
	for d: Dictionary in _room_doors:
		var layer: TileMapLayer = d["layer"]
		var origin: Vector2i = d["origin"]
		var top: Vector2 = layer.to_global(layer.map_to_local(origin) + Vector2(8.0, -8.0))
		var bottom: Vector2 = top + Vector2(0.0, 48.0)
		var want_open: bool = false
		for q: Vector2 in feet_pts:
			var cy: float = clampf(q.y, top.y, bottom.y)
			if q.distance_to(Vector2(top.x, cy)) <= ROOM_DOOR_OPEN_RADIUS:
				want_open = true
				break
		var target: int = ROOM_DOOR_FRAMES - 1 if want_open else 0
		var frame: int = d["frame"]
		if frame == target:
			d["acc"] = 0.0
			continue
		d["acc"] = float(d["acc"]) + delta
		if float(d["acc"]) < ROOM_DOOR_FRAME_TIME:
			continue
		d["acc"] = 0.0
		frame += 1 if target > frame else -1
		d["frame"] = frame
		for j in 3:
			for i in 2:
				layer.set_cell(origin + Vector2i(i, j), int(d["sid"]), Vector2i(2 * frame + i, j))


func room_door_frames() -> Array[int]:
	var out: Array[int] = []
	for d: Dictionary in _room_doors:
		out.append(int(d["frame"]))
	return out


## Pencereler (Pencere.png karo 0 gece / 1 gündüz): gün saatine göre cam karesi.
func _setup_windows() -> void:
	_windows.clear()
	for child: Node in _interior_instance.get_children():
		var layer := child as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		for c: Vector2i in layer.get_used_cells():
			var sid: int = layer.get_cell_source_id(c)
			var src := layer.tile_set.get_source(sid) as TileSetAtlasSource
			if src == null or src.texture == null or src.texture.resource_path.get_file() != WINDOW_TEX_NAME:
				continue
			if not src.has_tile(Vector2i(1, 0)):
				src.create_tile(Vector2i(1, 0))
			_windows.append({"layer": layer, "sid": sid, "cell": c})


func _process_windows(delta: float) -> void:
	if _windows.is_empty():
		return
	_window_check -= delta
	if _window_check > 0.0:
		return
	_window_check = 1.0
	var atmo: Node = get_tree().get_first_node_in_group("atmosphere")
	var dark: float = AtmosphereMath.darkness(float(atmo.get("cycle_time"))) if atmo != null else 0.0
	var frame: int = 1 if dark < WINDOW_DAY_BELOW else 0
	if frame == _window_frame:
		return
	_window_frame = frame
	for w: Dictionary in _windows:
		(w["layer"] as TileMapLayer).set_cell(w["cell"], int(w["sid"]), Vector2i(frame, 0))


# ============================================================================== EV KUŞATMASI + AÇILIŞ (madde 313)
## Kurallar house_siege.gd (ev canı, yıkılış, babaanne canı - host yetkili) ve house_intro.gd (huzur -> deprem -> 30 sn geri sayım) içinde;
## burada sadece bağlantılar: oyuncunun açılış yeri/oturuşu, yıkılınca dışarı atma, kapının kilitlenmesi, babaannenin çıkıp dönmesi,
## bildirimler. Düğüm adları sabit (Main/HouseInterior/HouseSiege, /HouseIntro): RPC yolları her peer'de aynı olmalı.

const HouseSiegeScript := preload("res://scripts/house_siege.gd")
const HouseIntroScript := preload("res://scripts/house_intro.gd")
const HouseDamageFxScript := preload("res://scripts/house_damage_fx.gd")
const PLAYER_FEET_OFFSET: float = 15.0 * 0.85 ## depth_occluders.gd FEET_OFFSET: kök (gövde ortası) ayağın bu kadar üstünde
## Açılışta oyuncu yerleri (dizin sırasıyla; tek oyuncu = 0): ["seat", n] = babaannenin bulduğu n. koltuk (0-1 şömine, 2 okuma),
## yoksa [ayak (iç mekan yereli), yön] ayakta. Ayakta duranlar en yakın açık zemine oturtulur.
const INTRO_SPOTS: Array = [
	["seat", 0], [Vector2(440.0, 120.0), "left"], ["seat", 1], [Vector2(286.0, 262.0), "left"],
	["seat", 2], [Vector2(140.0, 252.0), "left"], [Vector2(148.0, 150.0), "left"], [Vector2(578.0, 292.0), "up"],
]
## Oyuncunun oturuş klibi (ride_) babaanneninkinden alçak: koltuğun ortasına otursun diye babaannenin koltuk noktasından yukarı + sırtlığa
## doğru kaydırılır (kullanıcı: "koltukların çok aşağısına oturuyor", gerçek çizicide ölçüldü).
const PLAYER_SEAT_SHIFT := Vector2(1.0, -3.0) ## x: sırtlığa doğru (sağa bakan koltukta sola), y: yukarı (-6 "koltuğun üstüne doğru" kaldı)
const COLLAPSE_EJECT_DELAY := 1.1 ## yıkılış sesi/döküntüsü görünsün, sonra karartıp dışarı
const GRANNY_OUT_OFFSET := Vector2(30.0, -4.0) ## dışarıda kapının yanında (güvenli dönüş noktasına göre)

const HouseHpBarScript := preload("res://scripts/house_hp_bar.gd")
const HOUSE_BAR_WORLD_W := 96 ## dışarıdaki çubuğun eni (dünya px)
const HOUSE_BAR_WORLD_OFFSET := Vector2(0.0, -84.0) ## evin kapısının üstü (çatının önünde)

var _siege: HouseSiege = null
var _intro: HouseIntro = null
var _damage_fx: HouseDamageFx = null
var _hp_bar: Control = null
var _hp_bar_world: Control = null
var _seat_release_pending: bool = false


func get_siege() -> HouseSiege:
	return _siege


func get_intro() -> HouseIntro:
	return _intro


func get_damage_fx() -> HouseDamageFx:
	return _damage_fx


func _setup_siege() -> void:
	_siege = HouseSiegeScript.new()
	_siege.house_rect = exterior_house_rect
	add_child(_siege)
	_siege.collapsed_changed.connect(_on_siege_collapsed)
	_siege.granny_hp_changed.connect(_on_granny_hp_changed)
	_siege.attack_started.connect(_on_siege_attack_started)
	_intro = HouseIntroScript.new()
	add_child(_intro)
	_intro.setup(self)
	_damage_fx = HouseDamageFxScript.new()
	_interior_instance.add_child(_damage_fx)
	_damage_fx.setup(self, _siege, walkable_cells(), Vector2(16.0, 16.0))
	## Evin canı: içeride ekranın üstünde (HUD), dışarıda hasarlı evin kapısının üstünde (house_hp_bar.gd).
	var hp_layer := CanvasLayer.new()
	hp_layer.name = "HouseHpLayer"
	hp_layer.layer = 38 ## boss barıyla aynı katman (main.gd BossBarLayer)
	add_child(hp_layer)
	_hp_bar = HouseHpBarScript.new()
	_hp_bar.name = "HouseHpBar"
	_hp_bar.siege = _siege
	_hp_bar.house = self
	hp_layer.add_child(_hp_bar)
	UISound.register_ui_opacity(_hp_bar)
	_hp_bar_world = HouseHpBarScript.new()
	_hp_bar_world.name = "HouseHpBarWorld"
	_hp_bar_world.world = true
	_hp_bar_world.bar_w = HOUSE_BAR_WORLD_W
	_hp_bar_world.siege = _siege
	_hp_bar_world.house = self
	_hp_bar_world.z_index = 60
	_hp_bar_world.z_as_relative = false
	add_child(_hp_bar_world)
	_hp_bar_world.position = (_exterior_entrance_pos + HOUSE_BAR_WORLD_OFFSET - Vector2(HOUSE_BAR_WORLD_W * 0.5, 0.0)).round()
	_damage_fx.hp_bar = _hp_bar


## Açılış yalnız GERÇEK oyun başında: ebeveyn Main (bildirim API'si var), geri/geç katılım değil. (game_time'a bakılmaz: menü ve
## yükleme ekranında da işlediği için Main kurulurken birkaç sn dolmuş oluyor - MP denetimi 2026-10-19.)
func _intro_wanted() -> bool:
	var main: Node = get_parent()
	if main == null or not main.has_method("_show_banner_notice"):
		return false
	return not NetworkManager.has_pending_rejoin() and NetworkManager.get("_is_rejoining_midgame") != true \
			and not GameManager.endless_active and GameManager.run_kills == 0


## Pencerenin önü (iç mekan yereli, ayak): şömine eksenine (giriş ortası) en yakın kuzey penceresinin altındaki ilk açık zemin.
func window_spot(walk: Dictionary = {}) -> Vector2:
	if walk.is_empty():
		walk = walkable_cells()
	var axis: float = INTERIOR_SPAWN_POS.x
	var best := Vector2.INF
	for w: Dictionary in _windows:
		var layer: TileMapLayer = w["layer"]
		var p: Vector2 = layer.position + layer.map_to_local(w["cell"])
		if p.y > 120.0:
			continue ## alt duvar pencereleri değil
		if not best.is_finite() or absf(p.x - axis) < absf(best.x - axis):
			best = p
	if not best.is_finite():
		return Vector2.INF
	for dy in range(2, 6):
		var c := Vector2i(floori(best.x / 16.0), floori(best.y / 16.0) + dy)
		if walk.has(c):
			return Vector2(best.x, (float(c.y) + 0.6) * 16.0)
	return Vector2.INF


## Açılış yeri: dizin -> {"feet", "face", "seat", "approach"} (iç mekan yereli).
func intro_spot(index: int) -> Dictionary:
	var spec: Array = INTRO_SPOTS[posmod(index, INTRO_SPOTS.size())]
	if spec[0] is String and is_instance_valid(_babaanne):
		var seats: Array[Dictionary] = []
		for kind: String in ["fire", "read"]:
			for st: Dictionary in _babaanne.seats:
				if st["kind"] == kind:
					seats.append(st)
		var n: int = int(spec[1])
		if n < seats.size():
			var face: String = seats[n]["face"]
			var shift := Vector2(-PLAYER_SEAT_SHIFT.x if face == "right" else PLAYER_SEAT_SHIFT.x, PLAYER_SEAT_SHIFT.y)
			return {"feet": (seats[n]["feet"] as Vector2) + shift, "face": face, "seat": true, "approach": seats[n]["approach"]}
	if spec[0] is String:
		spec = [Vector2(408.0, 128.0), "up"]
	var feet: Vector2 = spec[0]
	var walk: Dictionary = walkable_cells()
	var c := Vector2i(floori(feet.x / 16.0), floori(feet.y / 16.0))
	if not walk.has(c) and not walk.is_empty():
		var best: Vector2i = c
		var best_d: int = 1 << 30
		for w: Vector2i in walk:
			var d: int = (w - c).length_squared()
			if d < best_d:
				best_d = d
				best = w
		feet = (Vector2(best) + Vector2(0.5, 0.6)) * 16.0
	return {"feet": feet, "face": spec[1], "seat": false}


## Yerel oyuncunun dizini: lobi oyuncularının kimlik sırası (her peer aynı sırayı görür -> herkes farklı yerde).
func intro_player_index() -> int:
	if not NetworkManager.is_multiplayer_active:
		return 0
	var ids: Array = []
	for pid in NetworkManager.lobby_players.keys():
		ids.append(int(pid))
	ids.sort()
	return maxi(0, ids.find(multiplayer.get_unique_id()))


func place_player_for_intro() -> void:
	if not is_instance_valid(_player):
		return
	var spot: Dictionary = intro_spot(intro_player_index())
	_player.global_position = INTERIOR_OFFSET + (spot["feet"] as Vector2) - Vector2(0.0, PLAYER_FEET_OFFSET)
	if _player.has_method("reset_physics_interpolation"):
		_player.reset_physics_interpolation()
	if "facing" in _player:
		_player.set("facing", spot["face"])
	if spot["seat"] and "intro_seat_face" in _player:
		## koltuğun karosu çarpışmalı: oturan oyuncu kalkıp açık zemine basana kadar iç mekan çarpışması kapalı (_process_seat_release)
		_player.set("intro_seat_face", spot["face"])
		_player.collision_mask = int(_player.collision_mask) & ~INTERIOR_COLLISION_LAYER
		_seat_release_pending = true


func _process_seat_release() -> void:
	if not _seat_release_pending or not is_instance_valid(_player):
		return
	if String(_player.get("intro_seat_face")) != "":
		return
	var indoors: bool = bool(_player.get("is_indoors"))
	var feet: Vector2 = _player.global_position + Vector2(0.0, PLAYER_FEET_OFFSET) - INTERIOR_OFFSET
	if not indoors or walkable_cells().has(Vector2i(floori(feet.x / 16.0), floori(feet.y / 16.0))):
		_seat_release_pending = false
		if indoors:
			_player.collision_mask = int(_player.collision_mask) | INTERIOR_COLLISION_LAYER


func _on_siege_attack_started() -> void:
	if is_instance_valid(_player) and bool(_player.get("is_indoors")) and _player.get("is_dead") != true:
		_notice("warn", "EVE SALDIRIYORLAR!", "Duvarlar çok dayanmaz - dışarı çık ve savaş!", 4.0)


func _on_siege_collapsed(c: bool) -> void:
	if c:
		if _damage_fx != null:
			_damage_fx.collapse_burst()
		var granny_alive: bool = is_instance_valid(_babaanne) and not _babaanne.is_dead
		_banner("fail", "EV YIKILDI!", "Babaanne dışarıda - onu canavarlardan koru!" if granny_alive else "Savaşarak evi onarın.")
		await get_tree().create_timer(COLLAPSE_EJECT_DELAY).timeout
		if not is_instance_valid(self) or _siege == null or not _siege.collapsed:
			return
		if is_instance_valid(_babaanne) and not _babaanne.is_dead and not _babaanne.outside:
			_babaanne.go_outside(get_parent() as Node2D, _granny_outside_pos())
		if is_instance_valid(_player) and bool(_player.get("is_indoors")):
			_transitioning = true
			await _fade_transition(_eject_local_player)
			_transitioning = false
	else:
		_notice("ok", "EV ONARILDI", "Kapı yeniden açıldı.", 3.0)
		if is_instance_valid(_babaanne) and _babaanne.outside and not _babaanne.is_dead:
			_babaanne.come_home(_exterior_entrance_pos)


func _eject_local_player() -> void:
	_do_exit_house()
	var off: Array[Vector2] = [Vector2.ZERO, Vector2(-26.0, 6.0), Vector2(26.0, 10.0), Vector2(-12.0, 26.0), Vector2(14.0, 30.0)]
	var p: Vector2 = _exterior_safe_return_pos + off[posmod(intro_player_index(), off.size())]
	if GameManager.is_position_blocked_by_walls(p):
		p = _exterior_safe_return_pos
	_player.global_position = p
	if _player.has_method("reset_physics_interpolation"):
		_player.reset_physics_interpolation()
	_seat_release_pending = false


func _granny_outside_pos() -> Vector2:
	var p: Vector2 = _exterior_safe_return_pos + GRANNY_OUT_OFFSET
	if GameManager.is_position_blocked_by_walls(p):
		p = _exterior_safe_return_pos + Vector2(-GRANNY_OUT_OFFSET.x, GRANNY_OUT_OFFSET.y)
	return p


func _on_granny_hp_changed(hp: float, dead: bool) -> void:
	if not is_instance_valid(_babaanne):
		return
	var was_dead: bool = _babaanne.is_dead
	_babaanne.on_hp_changed(hp, dead)
	if dead and not was_dead:
		_banner("fail", "BABAANNE ÖLDÜ", "Bir daha dönmeyecek...", 5.0)


func _notice(kind: String, title: String, body: String, hold: float) -> void:
	var main: Node = get_parent()
	if main != null and main.has_method("_show_notice"):
		main.call("_show_notice", kind, title, body, hold)


func _banner(kind: String, title: String, body: String, hold: float = 4.5) -> void:
	var main: Node = get_parent()
	if main != null and main.has_method("_show_banner_notice"):
		main.call("_show_banner_notice", kind, title, body, hold)
