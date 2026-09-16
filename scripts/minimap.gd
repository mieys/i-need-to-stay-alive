extends Control
class_name Minimap

## Yuvarlak minimap: harita üzerinde oyuncu konumunu, düşmanları ve harita
## sınırlarını gösterir.

const RADIUS: float = 80.0

const MAP_MIN: Vector2 = Vector2(0.0, 0.0)
const MAP_MAX: Vector2 = Vector2(4096.0, 4096.0)

const COLOR_BG: Color = Color(0.06, 0.10, 0.08, 0.85)
const COLOR_BORDER: Color = Color(0.8, 0.75, 0.5, 0.9)
const COLOR_PLAYER: Color = Color(0.2, 1.0, 0.4, 1.0)
const COLOR_REMOTE_PLAYER: Color = Color(0.3, 0.6, 1.0, 1.0)
const COLOR_ENEMY: Color = Color(1.0, 0.2, 0.2, 0.9)
const COLOR_BOSS: Color = Color(1.0, 0.5, 0.0, 1.0)
const COLOR_NORTH: Color = Color(1.0, 0.9, 0.4, 0.8)
const COLOR_MERCHANT: Color = Color(1.0, 0.85, 0.2, 1.0)

## Seyyar satıcı belirdiğinde/ayrıldığında main.gd tarafından ayarlanır (bkz.
## traveling_merchant.gd -> NetworkManager.merchant_spawned/merchant_departed
## sinyalleri). Kullanıcı isteği: "ne tarafta olduğu haritada işaretle
## gösterilir."
var _merchant_marker_active: bool = false
var _merchant_marker_pos: Vector2 = Vector2.ZERO

func set_merchant_marker(pos: Vector2, active: bool) -> void:
	_merchant_marker_pos = pos
	_merchant_marker_active = active
	queue_redraw()

var _player: Node = null
var _enemy_refresh_timer: float = 0.0
const ENEMY_REFRESH_INTERVAL: float = 0.2

var _alpha: float = 1.0

var _enemy_dots: Array = []
var _player_dots: Array = []
var _has_any_player: bool = false

## #29 DÜZELTME: minimap'te oyuncular artık düz renkli nokta yerine kendi
## karakter portreleriyle ("kafa") gösteriliyor - bkz. Characters.DEFS[id]
## "portrait" alanı. Tekstürler karakter başına bir kez yükleyip burada
## önbelleğe alınıyor (her frame load() çağırmamak için).
var _portrait_cache: Dictionary = {}

func _ready() -> void:
	set_process(true)
	custom_minimum_size = Vector2(RADIUS * 2.0 + 4.0, RADIUS * 2.0 + 4.0)
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	# Collect ALL player positions (local + remote)
	var player_dots: Array = []
	var local_id: int = 0
	if multiplayer.has_multiplayer_peer():
		local_id = multiplayer.get_unique_id()
	for p: Node in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not ("global_position" in p):
			continue
		if p.get("is_dead") == true:
			continue
		var is_local: bool = (p == _player)
		player_dots.append({"pos": p.global_position, "is_local": is_local, "char_id": GameManager.selected_char_id})
	## DÜZELTME (#29'un yan etkisi olarak keşfedildi): minimap eskiden SADECE
	## "player" grubunu tarıyordu - ama RemotePlayer kuklaları "player"
	## grubuna hiç eklenmiyor (bkz. remote_player.gd add_to_group çağrıları:
	## "player_ally" + "remote_players"). Yani diğer oyuncular minimap'te
	## HİÇ görünmüyordu - COLOR_REMOTE_PLAYER sabiti tanımlı olduğu halde
	## hiç kullanılmıyordu. Şimdi "remote_players" grubu da taranıyor.
	for rp: Node in get_tree().get_nodes_in_group("remote_players"):
		if not is_instance_valid(rp) or not ("global_position" in rp):
			continue
		if rp.get("is_dead") == true:
			continue
		var remote_char_id: int = 1
		if "char_id" in rp:
			remote_char_id = rp.char_id
		player_dots.append({"pos": rp.global_position, "is_local": false, "char_id": remote_char_id})
	_player_dots = player_dots
	_has_any_player = not player_dots.is_empty()

	_enemy_refresh_timer += delta
	if _enemy_refresh_timer >= ENEMY_REFRESH_INTERVAL:
		_enemy_refresh_timer = 0.0
		## BUG DÜZELTMESİ (kullanıcı bildirimi: "evin içine girince yaratıklar
		## görünmeye devam ediyor") - enemy.gd'ler is_indoors durumundan
		## bağımsız hep "enemies" grubunda kalıyor ve gerçek dünya konumlarını
		## koruyor; minimap bunu hiç filtrelemediği için ev içindeyken bile
		## dışarıdaki yaratıklar kırmızı nokta olarak görünmeye devam
		## ediyordu. enemy_spawner.gd/enemy.gd'nin AYNI is_indoors_now()
		## kontrolüyle - içerideyken minimap'teki yaratık noktaları boşaltılır.
		var player_indoors: bool = _player != null and is_instance_valid(_player) and _player.has_method("is_indoors_now") and _player.is_indoors_now()
		if player_indoors:
			_enemy_dots = []
		else:
			var dots: Array = []
			for enemy: Node in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy) or not ("global_position" in enemy):
					continue
				if enemy.get("is_dead") == true:
					continue
				var is_boss: bool = false
				if "is_boss" in enemy:
					is_boss = bool(enemy.is_boss)
				dots.append({"pos": enemy.global_position, "is_boss": is_boss})
			_enemy_dots = dots

		## PERF DÜZELTMESİ (profiler: Minimap._draw tek çağrıda ~6ms, düşman
		## sayısı arttıkça büyüyor - immediate-mode draw_circle her nokta için
		## ayrı bir RenderingServer çağrısı). Eskiden queue_redraw() HER FRAME
		## (saniyede 60 kez) tetikleniyordu, halbuki düşman verisi zaten
		## sadece ENEMY_REFRESH_INTERVAL'de (0.2sn = saniyede 5 kez) değişiyor
		## - aradaki 55 çizim tamamen israftı. Redraw'ı da aynı aralığa
		## bağladık: minimap artık saniyede 5 kez çiziliyor, oyuncu noktaları
		## da bu aralıkta güncelleniyor (küçük köşe UI'ı için gözle fark
		## edilmez bir ödün, ama büyük CPU kazancı).
		queue_redraw()

func _draw() -> void:
	var center: Vector2 = Vector2(RADIUS + 2.0, RADIUS + 2.0)

	# --- Draw solid green-tinted background ---
	draw_circle(center, RADIUS, COLOR_BG)
	draw_circle(center, RADIUS - 2.0, Color(0.15, 0.28, 0.12, 0.6))

	# --- Düşman noktaları ---
	for dot: Dictionary in _enemy_dots:
		var epos: Vector2 = _world_to_map(dot["pos"] as Vector2)
		var offset: Vector2 = epos - center
		if offset.length() > RADIUS - 4.0:
			offset = offset.normalized() * (RADIUS - 4.0)
			epos = center + offset

		var is_boss: bool = dot["is_boss"] as bool
		var ecol: Color = COLOR_BOSS if is_boss else COLOR_ENEMY
		var esize: float = 5.0 if is_boss else 3.0
		draw_circle(epos, esize, ecol)

	# --- Tüm oyuncu noktaları ---
	for dot: Dictionary in _player_dots:
		var ppos: Vector2 = _world_to_map(dot["pos"] as Vector2)
		var offset: Vector2 = ppos - center
		if offset.length() > RADIUS - 5.0:
			offset = offset.normalized() * (RADIUS - 5.0)
			ppos = center + offset
		var is_local: bool = dot["is_local"] as bool
		var pcol: Color = COLOR_PLAYER if is_local else COLOR_REMOTE_PLAYER
		var psize: float = 5.0 if is_local else 4.0
		## #29 DÜZELTME (kullanıcı bildirimi: "Minimap'te karakter portreleri
		## (kafalar) görünsün"): düz renkli noktalar yerine, portre bulunabiliyorsa
		## küçük bir kare ikon olarak karakterin kendi portresi çiziliyor,
		## etrafına da (yerel/uzak ayrımı için) renkli bir halka ekleniyor.
		## Portre bulunamazsa (asset eksikse) eski davranışa (düz nokta) dönülüyor.
		var portrait: Texture2D = _get_portrait(int(dot.get("char_id", 1)))
		if portrait:
			var icon_radius: float = psize + 2.0
			var icon_size: float = icon_radius * 2.0
			var rect: Rect2 = Rect2(ppos - Vector2(icon_radius, icon_radius), Vector2(icon_size, icon_size))
			draw_texture_rect(portrait, rect, false)
			draw_circle(ppos, icon_radius, pcol, false, 1.5)
		else:
			draw_circle(ppos, psize, pcol)
			# Small border for visibility
			draw_circle(ppos, psize + 1.0, Color(0.1, 0.1, 0.1, 0.5), false, 1.0)

	# --- Seyyar satıcı işareti ---
	if _merchant_marker_active:
		var mpos: Vector2 = _world_to_map(_merchant_marker_pos)
		var moffset: Vector2 = mpos - center
		if moffset.length() > RADIUS - 5.0:
			moffset = moffset.normalized() * (RADIUS - 5.0)
			mpos = center + moffset
		draw_circle(mpos, 6.0, COLOR_MERCHANT)
		draw_circle(mpos, 6.0, Color(0.1, 0.1, 0.1, 0.6), false, 1.5)
		draw_string(ThemeDB.fallback_font, mpos + Vector2(-3.0, 3.0), "$",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.15, 0.1, 0.0, 1.0))

	# --- Kuzey yönü göstergesi ---
	var north_pos: Vector2 = center + Vector2(0, -(RADIUS - 8.0))
	draw_circle(north_pos, 4.0, COLOR_NORTH)
	draw_string(ThemeDB.fallback_font, north_pos + Vector2(-3.0, 4.0), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.1, 0.1, 0.1, 1.0))

	# --- Kenarlık ---
	draw_arc(center, RADIUS, 0.0, TAU, 64, COLOR_BORDER, 2.5, true)

func _world_to_map(world: Vector2) -> Vector2:
	var center: Vector2 = Vector2(RADIUS + 2.0, RADIUS + 2.0)
	var map_size: Vector2 = MAP_MAX - MAP_MIN
	var t: Vector2 = (world - MAP_MIN) / map_size
	t = t.clamp(Vector2.ZERO, Vector2.ONE)
	var usable: float = RADIUS - 5.0
	return center + (t - Vector2(0.5, 0.5)) * 2.0 * usable

## #29: karakter portresini Characters.DEFS[char_id]["portrait"]'ten yükleyip
## önbelleğe alır. Bulunamazsa null döner (çağıran taraf eski nokta çizimine
## geri döner) - eksik/hatalı bir asset yüzünden minimap'in kırılmaması için.
func _get_portrait(char_id: int) -> Texture2D:
	if _portrait_cache.has(char_id):
		return _portrait_cache[char_id]
	var tex: Texture2D = null
	var def: Dictionary = Characters.get_def(char_id)
	var path: String = def.get("portrait", "")
	if path != "" and ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			tex = res
	_portrait_cache[char_id] = tex
	return tex


func _draw_player_arrow(pos: Vector2, color: Color) -> void:
	var tip: Vector2 = pos + Vector2(0.0, -6.0)
	var left: Vector2 = pos + Vector2(-4.0, 4.0)
	var right: Vector2 = pos + Vector2(4.0, 4.0)
	var tri: PackedVector2Array = PackedVector2Array([tip, left, right])
	draw_colored_polygon(tri, color)
	var tip2: Vector2 = pos + Vector2(0.0, -3.5)
	var l2: Vector2 = pos + Vector2(-2.0, 2.5)
	var r2: Vector2 = pos + Vector2(2.0, 2.5)
	draw_colored_polygon(PackedVector2Array([tip2, l2, r2]), Color.WHITE)
