extends Node2D
class_name HouseInterior

## Başlangıç evine "F" ile girip çıkma sistemi (kullanıcı isteği: "haritamda
## başlangıç kısmında bir ev var, çok yaklaşınca F'ye basarak içeri
## girilsin, içerideyken aşağıya yaklaşınca F'ye basıp çıkılabilsin").
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
## Çıkış tetikleme alanı - kapıya (güney duvara) yakın olduğu için giriş
## noktasıyla neredeyse aynı bölge.
const INTERIOR_EXIT_POS := Vector2(160.0, 306.0)
const INTERIOR_EXIT_RADIUS := 50.0

## Dışarıdaki evin konumu (bkz. scenes/harita_baked.tscn "ev/Ev" katmanı,
## piksel sınırları x:[2944,3120] y:[1792,1920]) - alt (güney) duvarın orta
## noktası, oyuncunun oyun başlangıcı konumuyla (main.tscn Player
## position=3016,1920) örtüşüyor.
const EXTERIOR_ENTRANCE_POS := Vector2(3032.0, 1912.0)
const EXTERIOR_ENTRANCE_RADIUS := 55.0

## Kullanıcı bildirimi: "oyun başında evden çıkarken evin kapısında takılı
## kalıyor karakterim" - _do_exit_house() normalde _exterior_return_pos'u
## kullanır, ve bu değer normal (F ile) girişte oyuncunun O ANDA GERÇEKTEN
## DURDUĞU - yürüyerek ulaştığı, dolayısıyla çarpışmasız - konumdan alınır.
## Ama oyun başlangıcındaki OTOMATİK girişte (bkz. _ready()) oyuncu hiç
## yürümedi; sahnede tanımlı ham başlangıç konumu (main.tscn Player
## position=3016,1920) tam olarak evin güney duvarının çizgisinde duruyor
## (bkz. yukarısı - ev kutusu y:[1792,1920]). Oyuncu oraya ışınlanınca
## duvarın/kapı eşiğinin çarpışma sınırına gömülüp bir daha kıpırdayamıyordu.
## Oyun başlangıcı için, evin biraz GÜNEYİNE (avluya, duvardan kesin uzak)
## sabit bir dönüş noktası kullanılıyor - hâlâ EXTERIOR_ENTRANCE_RADIUS
## içinde kalıyor, yani "eve girmek için F'ye bas" ipucu istenirse hemen
## tekrar çıkıyor.
const EXTERIOR_SAFE_RETURN_POS := Vector2(3016.0, 1950.0)

var _player: CharacterBody2D = null
var _interior_instance: Node2D = null
var _entrance_area: Area2D = null
var _exit_area: Area2D = null
var _prompt_label: Label = null

var _near_entrance: bool = false
var _near_exit: bool = false

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
		## bkz. EXTERIOR_SAFE_RETURN_POS üstündeki not - _do_enter_house()'un
		## az önce yakaladığı ham (duvar hattındaki) başlangıç konumunu,
		## dışarı çıkınca takılmayacakları güvenli bir konumla değiştiriyoruz.
		_exterior_return_pos = EXTERIOR_SAFE_RETURN_POS
		# Kapıdan girmedikleri için kapı ipucunu sıfırlayalım.
		_near_exit = false


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
	walls.collision_layer = 4 ## player.tscn'in collision_mask'ı (4) ile eşleşir
	walls.collision_mask = 0
	walls.position = INTERIOR_OFFSET
	add_child(walls)
	var size: Vector2 = ROOM_MAX - ROOM_MIN
	var center: Vector2 = (ROOM_MIN + ROOM_MAX) * 0.5
	_add_wall_segment(walls, Vector2(center.x, ROOM_MIN.y - WALL_THICKNESS * 0.5), Vector2(size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS))
	_add_wall_segment(walls, Vector2(center.x, ROOM_MAX.y + WALL_THICKNESS * 0.5), Vector2(size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS))
	_add_wall_segment(walls, Vector2(ROOM_MIN.x - WALL_THICKNESS * 0.5, center.y), Vector2(WALL_THICKNESS, size.y + WALL_THICKNESS * 2.0))
	_add_wall_segment(walls, Vector2(ROOM_MAX.x + WALL_THICKNESS * 0.5, center.y), Vector2(WALL_THICKNESS, size.y + WALL_THICKNESS * 2.0))

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
	_entrance_area.position = EXTERIOR_ENTRANCE_POS
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = EXTERIOR_ENTRANCE_RADIUS
	shape.shape = circle
	_entrance_area.add_child(shape)
	add_child(_entrance_area)
	_entrance_area.body_entered.connect(_on_entrance_body_entered)
	_entrance_area.body_exited.connect(_on_entrance_body_exited)


func _create_exit_trigger() -> void:
	_exit_area = Area2D.new()
	_exit_area.name = "HouseExitTrigger"
	_exit_area.collision_layer = 0
	_exit_area.collision_mask = 2
	_exit_area.position = INTERIOR_OFFSET + INTERIOR_EXIT_POS
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INTERIOR_EXIT_RADIUS
	shape.shape = circle
	_exit_area.add_child(shape)
	add_child(_exit_area)
	_exit_area.body_entered.connect(_on_exit_body_entered)
	_exit_area.body_exited.connect(_on_exit_body_exited)


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


func _on_exit_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_near_exit = true


func _on_exit_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_near_exit = false


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
	## "interact" (F) - bkz. game_manager.gd _setup_input_actions. Chat kutusu
	## açıkken (bkz. player.gd is_chat_typing) mesaj içindeki "f" harfi
	## yanlışlıkla eve girip çıkmayı tetiklemesin.
	var f_just_pressed: bool = Input.is_action_just_pressed("interact") and not bool(_player.get("is_chat_typing"))

	if not indoors and _near_entrance:
		_prompt_label.text = "Eve girmek için F'ye bas"
		_prompt_label.visible = true
		if f_just_pressed:
			_enter_house()
	elif indoors and _near_exit:
		_prompt_label.text = "Dışarı çıkmak için F'ye bas"
		_prompt_label.visible = true
		if f_just_pressed:
			_exit_house()
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
	_near_exit = false
	_transitioning = true
	await _fade_transition(_do_exit_house)
	_transitioning = false


## Gerçek ışınlama/durum değişimi - fade YOK, hem _enter_house/_exit_house'un
## karardığı anda çağırdığı hem de _ready()'nin oyun başında ANINDA (geçişsiz)
## kullandığı çekirdek mantık burada.
func _do_enter_house() -> void:
	_exterior_return_pos = _player.global_position
	_player.global_position = INTERIOR_OFFSET + INTERIOR_SPAWN_POS
	_player.is_indoors = true
	_interior_instance.visible = true
	_near_entrance = false
	_near_exit = true ## oyuncu tam kapının hemen iç tarafında beliriyor
	_set_combat_visuals_hidden(true)
	## Kullanıcı isteği: içerideyken ortam müziği çalmasın ve rüzgar efekti
	## katmanı görünmesin (bkz. _set_outdoor_atmosphere_enabled).
	_set_outdoor_atmosphere_enabled(false)


func _do_exit_house() -> void:
	_player.global_position = _exterior_return_pos
	_player.is_indoors = false
	_interior_instance.visible = false
	_near_exit = false
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
