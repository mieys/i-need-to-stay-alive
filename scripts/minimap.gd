extends Control
class_name Minimap

## Yuvarlak minimap: harita üzerinde oyuncu konumunu, düşmanları ve harita
## sınırlarını gösterir.

const VisionFogScript := preload("res://scripts/vision_fog.gd")
const EnemyWorldBridgeScript := preload("res://scripts/enemy_world/enemy_world_bridge.gd")

const RADIUS: float = 80.0
## Kullanıcı isteği (2026-09-21): minimap çerçevesi yeniden tasarlandı - 92 sanat pikseli (184 px) ahşap halka + altın perçinler
## (assets/ui/kit/hud_minimap_ring.png, tools/gen_ui_kit.py). İç yarıçapı RADIUS'a (80 px) denk gelir, harita dairesini üstten örter.
const RING_TEXTURE := preload("res://assets/ui/kit/hud_minimap_ring.png")
const RING_HALF: float = 92.0

## Kullanıcı isteği (2026-09-24): "minimap arkaplanında harita düşük kalitede gözüksün. nerde olduğumu anlayamıyorum" -
## minimap artık OYUNCU MERKEZLİ ve zemininde gerçek haritanın pikselli, düşük çözünürlüklü bir görüntüsü var. Doku
## tools/bake_minimap.gd ile ÖNCEDEN üretilir (harita değişince yeniden çalıştır): 1 texel = MAP_TEXEL_WORLD dünya pikseli,
## GameManager.get_map_world_rect() dikdörtgenini + her yanda MAP_PAD_TEXELS kenar payını kapsar. Çalışma anında maliyet
## tek bir küçük doku + kare başına tek bir dokulu daire çokgeni.
const MAP_TEXTURE_PATH := "res://assets/ui/minimap_map.png"
const MAP_TEXEL_WORLD: float = 32.0
const MAP_PAD_TEXELS: int = 32
## Ekran pikseli başına dünya pikseli: 1 texel = 2 ekran pikseli (HUD'un 2 px sanat ızgarası). Yarıçap 80 px -> 1280 dünya
## pikseli görünür (kamera zoom 2'de ekranın ~2.7 katı genişlik).
const VIEW_WORLD_PER_PX: float = 16.0
const CIRCLE_SEGMENTS: int = 64

## Kullanıcı isteği (2026-09-24): "mini mapi ... unutma" - minimap de menülerle aynı dile geçti: içi PARŞÖMEN HARİTA (bej,
## hafif koyu kenar + soluk menzil halkası), noktalar parşömen üstünde okunan koyu doygun tonlar; kuzey artık çerçevedeki
## "N" levhası (tools/gen_ui_kit.py minimap_ring) - eski sarı nokta kaldırıldı.
const COLOR_BG: Color = Color("#c8a878")
const COLOR_BORDER: Color = Color(0.8, 0.75, 0.5, 0.9)
const COLOR_PLAYER: Color = Color("#ffe07a") ## yeşil haritada okunsun diye altın sarısı
const COLOR_REMOTE_PLAYER: Color = Color("#2a58a8")
const COLOR_ENEMY: Color = Color("#b8321e")
const COLOR_BOSS: Color = Color("#d8661a")
const COLOR_MERCHANT: Color = Color("#d6a23a")
## 2026-10-10 (kullanıcı: "minimapte silah satıcısının konumu gözükmüyor ve bazı şeyler hiç belirgin değil, dostları bulmak zor"): demirci kapısı işareti (örs,
## daire dışındaysa kenarda yön göstergesi) + dostlar büyük portre, parlak turkuaz halka + koyu kontur; dairenin dışındaki dosta kenarda yön oku.
const COLOR_SMITH: Color = Color("#8e98a8")
const COLOR_SMITH_DARK: Color = Color("#2a2d33")
const COLOR_ALLY_RING: Color = Color("#5fe0ff")
const COLOR_OUTLINE: Color = Color("#1a120a")
## Ölü / yerde yatan oyuncu işareti (2026-10-07, bkz. _process): kararmış portre, koyu kırmızı halka, parlak kırmızı çarpı.
const COLOR_DEAD: Color = Color("#a01818")
const COLOR_DEAD_X: Color = Color("#ff4a3a")
const DEAD_PORTRAIT_TINT: Color = Color(0.5, 0.5, 0.55, 1.0)

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

## Görev sistemi (bkz. world_event_manager.gd/world_event_marker.gd) - satıcının TEK
## işaretinin aksine aynı anda en fazla 2 görev olabildiği için id'ye göre bir Dictionary.
## symbol tek karakterlik bir harf/işaret (ör. "!" aktif, "?" uyarı aşaması).
var _mission_markers: Dictionary = {} ## id -> {"pos": Vector2, "color": Color, "symbol": String}

func set_mission_marker(id: int, pos: Vector2, color: Color, symbol: String) -> void:
	_mission_markers[id] = {"pos": pos, "color": color, "symbol": symbol}
	queue_redraw()

func clear_mission_marker(id: int) -> void:
	_mission_markers.erase(id)
	queue_redraw()

## "Topla" görevi kristalleri (bkz. world_event_manager.gd COLLECT_ITEM_RATIO notu): görev id -> {index: dünya konumu}.
## Toplanan kristal remove_collect_dot ile, görev bitince hepsi clear_collect_dots ile kalkar.
var _collect_dots: Dictionary = {}
const COLOR_COLLECT := Color("#2f9a8e")

func set_collect_dots(mission_id: int, positions: PackedVector2Array) -> void:
	var d: Dictionary = {}
	for i in range(positions.size()):
		d[i] = positions[i]
	_collect_dots[mission_id] = d
	queue_redraw()

func remove_collect_dot(mission_id: int, index: int) -> void:
	if _collect_dots.has(mission_id):
		(_collect_dots[mission_id] as Dictionary).erase(index)
		queue_redraw()

func clear_collect_dots(mission_id: int) -> void:
	_collect_dots.erase(mission_id)
	queue_redraw()

var _player: Node = null
var _enemy_refresh_timer: float = 0.0
const ENEMY_REFRESH_INTERVAL: float = 0.2

var _alpha: float = 1.0
## Telefon HUD'u (2026-10-18, madde 273): minimap KARE çizilir - harita kare çokgen, kenara kıstırma kareye göre, halka yerine
## çerçeveyi HUD çizer (ahşap levha). Masaüstünde false (yuvarlak, halka dokusu).
var square: bool = false


## Merkezden `off` kadar uzaktaki nokta görünüm alanının (kenardan `inset` içeride) dışında mı?
func _outside(off: Vector2, inset: float) -> bool:
	if square:
		return maxf(absf(off.x), absf(off.y)) > RADIUS - inset
	return off.length() > RADIUS - inset


## Görünüm dışındaki noktayı kenara kıstırır (yön korunur): kare kipte kare kenarına, değilse daireye.
func _clamp_edge(off: Vector2, inset: float) -> Vector2:
	if square:
		var m: float = maxf(absf(off.x), absf(off.y))
		return off * ((RADIUS - inset) / m) if m > 0.001 else off
	return off.normalized() * (RADIUS - inset)

var _enemy_dots: Array = [] ## {"node": Node2D, "is_boss": bool} - konum çizimde canlı okunur
var _ew_dots_world: Object = null ## yeni yolda C++ EnemyWorld (kayıtlı yaratık noktaları _draw'da ondan), yoksa / ev içinde null
var _map_texture: Texture2D = null
var _map_origin: Vector2 = Vector2.ZERO ## dokunun sol-üst köşesinin dünya konumu
var _map_world_size: Vector2 = Vector2.ZERO
## Görünümün dünya merkezi (yerel oyuncu). Ev içindeyken son dış konumda donar - ev içi haritanın dışında bir yerde.
var _view_center: Vector2 = Vector2(2048.0, 2048.0)
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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(MAP_TEXTURE_PATH):
		_map_texture = load(MAP_TEXTURE_PATH) as Texture2D


## Harita dikdörtgeni harita sahnesi yüklenince bulunur (GameManager önbelleğe alır) - bulunana kadar her karede denenir.
func _ensure_map_mapping() -> void:
	if _map_world_size != Vector2.ZERO or _map_texture == null:
		return
	var rect: Rect2 = GameManager.get_map_world_rect()
	if rect.size == Vector2.ZERO:
		return
	var pad: float = float(MAP_PAD_TEXELS) * MAP_TEXEL_WORLD
	_map_origin = rect.position - Vector2(pad, pad)
	_map_world_size = Vector2(_map_texture.get_size()) * MAP_TEXEL_WORLD

## ZİNDAN (madde 373): oyuncu zindandayken harita dokusu zindanın KEŞİF dokusu (DungeonManager.minimap_info: gezilen yer açılır, çıkışlar
## hep yeşil işaret). Çıkınca ana harita dokusu geri gelir.
var _ow_texture: Texture2D = null
var _ow_origin: Vector2 = Vector2.ZERO
var _ow_size: Vector2 = Vector2.ZERO
var _dungeon_map: String = ""


func _sync_dungeon_map() -> void:
	var v: Variant = _player.get("in_dungeon") if _player != null and is_instance_valid(_player) else null
	var did: String = str(v) if v != null else ""
	if did == _dungeon_map:
		return
	var dm: Node = get_tree().get_first_node_in_group(&"dungeon_manager")
	if did != "" and (dm == null or not dm.has_method("minimap_info")):
		return
	if _dungeon_map == "":
		_ow_texture = _map_texture
		_ow_origin = _map_origin
		_ow_size = _map_world_size
	_dungeon_map = did
	if did == "":
		_map_texture = _ow_texture
		_map_origin = _ow_origin
		_map_world_size = _ow_size
		return
	var info: Dictionary = dm.call("minimap_info", did)
	if info.is_empty():
		return
	_map_texture = info["texture"]
	_map_origin = info["origin"]
	_map_world_size = info["size"]


func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	_ensure_map_mapping()
	_sync_dungeon_map()
	if _player and is_instance_valid(_player) and not (_player.has_method("is_indoors_now") and _player.is_indoors_now()):
		_view_center = (_player as Node2D).global_position
	## Harita her karede kaymalı (5 Hz'de kayınca takılır) - çizim artık ucuz: tek dokulu çokgen + SADECE görünüm içindeki
	## düşmanlar (dışarıdakiler çizilmiyor; eskiden hepsi kenara yığılıp çiziliyordu, asıl maliyet oydu).
	queue_redraw()

	# Collect ALL player positions (local + remote)
	## 2026-10-07 KULLANICI İSTEĞİ: "Ölen oyuncu haritada konumu gözüksün" - ölü/yerde yatan oyuncular artık atlanmıyor: konumları
	## "dead" işaretiyle (kararmış portre + kırmızı çarpı + nabız halkası) çizilir, canlıların ALTINDA kalır. Kalıcı ölü ceset de
	## yerde yatan (kurtarılabilir) arkadaş da aynı işareti alır - aranıp bulunabilsin.
	var alive_dots: Array = []
	var dead_dots: Array = []
	var local_id: int = 0
	if multiplayer.has_multiplayer_peer():
		local_id = multiplayer.get_unique_id()
	for p: Node in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not ("global_position" in p):
			continue
		var is_local: bool = (p == _player)
		var local_dead: bool = p.get("is_dead") == true
		(dead_dots if local_dead else alive_dots).append({"pos": p.global_position, "is_local": is_local, "char_id": GameManager.selected_char_id, "dead": local_dead})
	## DÜZELTME (#29'un yan etkisi olarak keşfedildi): minimap eskiden SADECE
	## "player" grubunu tarıyordu - ama RemotePlayer kuklaları "player"
	## grubuna hiç eklenmiyor (bkz. remote_player.gd add_to_group çağrıları:
	## "player_ally" + "remote_players"). Yani diğer oyuncular minimap'te
	## HİÇ görünmüyordu - COLOR_REMOTE_PLAYER sabiti tanımlı olduğu halde
	## hiç kullanılmıyordu. Şimdi "remote_players" grubu da taranıyor.
	for rp: Node in get_tree().get_nodes_in_group("remote_players"):
		if not is_instance_valid(rp) or not ("global_position" in rp):
			continue
		## Yerde yatan uzak oyuncu ağa is_dead=false (+ is_downed=true) olarak bildirilir (bkz. main.gd state_snapshot) - ikisi de ölü sayılır.
		var remote_dead: bool = rp.get("is_dead") == true or rp.get("is_downed") == true
		var remote_char_id: int = 1
		if "char_id" in rp:
			remote_char_id = rp.char_id
		(dead_dots if remote_dead else alive_dots).append({"pos": rp.global_position, "is_local": false, "char_id": remote_char_id, "dead": remote_dead})
	_player_dots = dead_dots + alive_dots ## ölüler önce çizilir: canlılar üstte kalır
	_has_any_player = not _player_dots.is_empty()

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
			## Bosslar ev içindeyken de daima görünür (kullanıcı isteği: "Bossların yeri haritada daima görünsün").
			_enemy_dots = _collect_boss_dots()
			_ew_dots_world = null
		else:
			## Kullanıcı isteği (LoL tarzı görüş alanı): sisin içindeki düşman
			## ekranda gizleniyorsa/soluyorsa minimap'te de nokta olarak
			## görünmemeli, yoksa minimap karanlıktaki düşmanı ele verir. Sis
			## düşmanı yönetmiyorsa (katman yok / ev içi) fog_visibility_of 1
			## döner - o durumlarda davranış eskisi gibi.
			var dots: Array = []
			## Aday sorgusu (yaratık yeniden yazımı): yeni yolda görünen dairenin (+0,2 sn'lik yürüme payı) içindekiler C++
			## ızgarasından + bosslar (kenarda yön göstergesi olarak her uzaklıkta çizilir); eski yolda tüm grup. Süzgeç aynen aşağıda.
			var scan: Array = get_tree().get_nodes_in_group("enemies")
			_ew_dots_world = EnemyWorldBridgeScript.fog_world(get_tree())
			if _ew_dots_world != null:
				## Yaratık yeniden yazımı (Aşama 3): C++'a kayıtlı sıradan yaratıkların noktaları HER KAREDE C++'tan gelir
				## (_draw, minimap_points - aynı süzgeç, aynı pikseldekiler tekilleştirilmiş); burada sadece bosslar (kenarda
				## yön göstergesi) ve C++'ta olmayan görev kopyaları kalır. 2000 yaratıkta eski tarama ~8 ms/yenileme idi.
				scan = get_tree().get_nodes_in_group("boss") + get_tree().get_nodes_in_group("mission_copies")
			for enemy: Node in scan:
				if not is_instance_valid(enemy) or not ("global_position" in enemy):
					continue
				if enemy.get("is_dead") == true:
					continue
				## Görünmez hayalet (yaratık yeteneği, bkz. enemy.gd set_ability_invisible) minimapte de ele verilmesin.
				if enemy.get("is_ability_invisible") == true:
					continue
				## Yeraltı Canavarı'nın havuz düğümü (underground_boss.gd) oyuncuların ortasında durur ve görünmezdir: minimapte nokta/yön oku olmasın.
				if enemy.has_meta(&"hide_on_minimap"):
					continue
				var is_boss: bool = enemy.is_in_group("boss") or ("is_boss" in enemy and bool(enemy.is_boss))
				## Boss sisin içinde de gizlenmez (yeri daima görünür); sıradan yaratıklar sise tabi.
				if not is_boss and VisionFogScript.fog_visibility_of(enemy) < VisionFogScript.SIDE_ELEMENT_MIN_VISIBILITY:
					continue
				dots.append({"node": enemy, "is_boss": is_boss})
			_enemy_dots = dots

		## (ESKİ NOT - 2026-09-24'ten beri redraw her kare, bkz. _process başı) PERF DÜZELTMESİ (profiler: Minimap._draw tek çağrıda ~6ms, düşman
		## sayısı arttıkça büyüyor - immediate-mode draw_circle her nokta için
		## ayrı bir RenderingServer çağrısı). Eskiden queue_redraw() HER FRAME
		## (saniyede 60 kez) tetikleniyordu, halbuki düşman verisi zaten
		## sadece ENEMY_REFRESH_INTERVAL'de (0.2sn = saniyede 5 kez) değişiyor
		## - aradaki 55 çizim tamamen israftı. Redraw'ı da aynı aralığa
		## bağladık: minimap artık saniyede 5 kez çiziliyor, oyuncu noktaları
		## da bu aralıkta güncelleniyor (küçük köşe UI'ı için gözle fark
		## edilmez bir ödün, ama büyük CPU kazancı).

## Yaşayan bosslar: sis ve ev içi süzgecinden bağımsız, minimapte daima (görünüm dışındaysa kenarda yön oku olarak) çizilir.
func _collect_boss_dots() -> Array:
	var out: Array = []
	for boss: Node in get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(boss) or not ("global_position" in boss):
			continue
		if boss.get("is_dead") == true or boss.has_meta(&"hide_on_minimap"):
			continue
		out.append({"node": boss, "is_boss": true})
	return out

func _draw() -> void:
	var center: Vector2 = Vector2(RADIUS + 2.0, RADIUS + 2.0)

	# --- Zemin: pikselli harita dokusu (yoksa/harita henüz bulunamadıysa düz parşömen) ---
	if square:
		draw_rect(Rect2(center - Vector2(RADIUS, RADIUS), Vector2(RADIUS, RADIUS) * 2.0), COLOR_BG)
	else:
		draw_circle(center, RADIUS, COLOR_BG)
	if _map_texture and _map_world_size != Vector2.ZERO:
		## Merkez 1 ekran pikseline (VIEW_WORLD_PER_PX) oturtuluyor - texel sınırları hep tam piksele düşer, kayarken
		## texel genişlikleri 2/3 px arasında titremez.
		var snapped_center: Vector2 = _map_origin + ((_view_center - _map_origin) / VIEW_WORLD_PER_PX).round() * VIEW_WORLD_PER_PX
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var corners: Array = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
		for i in (4 if square else CIRCLE_SEGMENTS):
			var o: Vector2
			if square:
				o = (corners[i] as Vector2) * RADIUS
			else:
				var a: float = TAU * float(i) / float(CIRCLE_SEGMENTS)
				o = Vector2(cos(a), sin(a)) * RADIUS
			pts.append(center + o)
			uvs.append((snapped_center + o * VIEW_WORLD_PER_PX - _map_origin) / _map_world_size)
		draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, _map_texture)

	# --- Düşman noktaları ---
	## Yeni yol: kayıtlı sıradan yaratıklar (aşağıdaki döngüyle aynı çizim; ofset C++'ta yuvarlanmış harita pikseli)
	if _ew_dots_world != null and is_instance_valid(_ew_dots_world):
		var pts: PackedVector2Array = _ew_dots_world.call("minimap_points", _view_center, VIEW_WORLD_PER_PX,
				(RADIUS * 1.415 if square else RADIUS) - 4.0, VisionFogScript.SIDE_ELEMENT_MIN_VISIBILITY)
		for off: Vector2 in pts:
			if square and _outside(off, 4.0):
				continue
			var epos2: Vector2 = center + off
			draw_rect(Rect2(epos2 - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color("#3a2213"))
			draw_rect(Rect2(epos2 - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), COLOR_ENEMY)
	for dot: Dictionary in _enemy_dots:
		var enode_ref: Variant = dot["node"]
		if not is_instance_valid(enode_ref):
			continue
		var enode: Node2D = enode_ref as Node2D
		var is_boss: bool = dot["is_boss"] as bool
		var epos: Vector2 = _world_to_map(enode.global_position)
		var offset: Vector2 = epos - center
		if _outside(offset, 4.0):
			## Görünüm dışındaki sıradan düşmanlar çizilmez; boss yön göstergesi olarak kenarda kalır.
			if not is_boss:
				continue
			offset = _clamp_edge(offset, 4.0)
			epos = center + offset

		var ecol: Color = COLOR_BOSS if is_boss else COLOR_ENEMY
		var esize: float = 5.0 if is_boss else 3.0
		var half: float = float(int(esize)) # kare nokta (2 px ızgarasına oturur)
		draw_rect(Rect2((epos - Vector2(half, half)).round(), Vector2(half * 2.0, half * 2.0)), Color("#3a2213"))
		draw_rect(Rect2((epos - Vector2(half - 1.0, half - 1.0)).round(), Vector2((half - 1.0) * 2.0, (half - 1.0) * 2.0)), ecol)

	# --- Tüm oyuncu noktaları ---
	for dot: Dictionary in _player_dots:
		var ppos: Vector2 = _world_to_map(dot["pos"] as Vector2)
		var offset: Vector2 = ppos - center
		var clamped: bool = _outside(offset, 5.0)
		if clamped:
			offset = _clamp_edge(offset, 5.0)
			ppos = center + offset
		var is_local: bool = dot["is_local"] as bool
		var is_dead_dot: bool = bool(dot.get("dead", false))
		var pcol: Color = COLOR_DEAD if is_dead_dot else (COLOR_PLAYER if is_local else COLOR_ALLY_RING)
		var psize: float = 5.0 if is_local else 6.0
		if not is_local and not is_dead_dot and clamped:
			## daire dışındaki dost: kenarda dışa bakan ok (nerede olduğu bulunsun)
			var dir: Vector2 = (ppos - center).normalized()
			var tip: Vector2 = ppos + dir * 9.0
			var side: Vector2 = dir.orthogonal() * 5.0
			draw_colored_polygon(PackedVector2Array([tip + dir * 1.5, ppos + dir * 2.0 + side * 1.3, ppos + dir * 2.0 - side * 1.3]), COLOR_OUTLINE)
			draw_colored_polygon(PackedVector2Array([tip, ppos + dir * 3.0 + side, ppos + dir * 3.0 - side]), COLOR_ALLY_RING)
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
			draw_circle(ppos, icon_radius + 2.5, COLOR_OUTLINE) ## koyu taban (yeşil haritada okunsun)
			draw_texture_rect(portrait, rect, false, DEAD_PORTRAIT_TINT if is_dead_dot else Color.WHITE)
			draw_circle(ppos, icon_radius + 1.0, pcol, false, 2.0)
		else:
			draw_circle(ppos, psize, pcol)
			# Small border for visibility
			draw_circle(ppos, psize + 1.0, Color(0.1, 0.1, 0.1, 0.5), false, 1.0)
		if is_dead_dot:
			## Ölü/yerde yatan: kırmızı çarpı (koyu konturlu) + dışa doğru nabız atan halka - uzaktan da fark edilsin.
			var xr: float = psize + 1.0
			for sgn in [1.0, -1.0]:
				draw_line(ppos + Vector2(-xr, -xr * sgn), ppos + Vector2(xr, xr * sgn), Color("#2a0a0a"), 4.0)
			for sgn2 in [1.0, -1.0]:
				draw_line(ppos + Vector2(-xr, -xr * sgn2), ppos + Vector2(xr, xr * sgn2), COLOR_DEAD_X, 2.0)
			var pulse: float = fposmod(float(Time.get_ticks_msec()) / 1000.0, 1.4) / 1.4
			draw_circle(ppos, psize + 2.0 + pulse * 6.0, Color(COLOR_DEAD.r, COLOR_DEAD.g, COLOR_DEAD.b, 0.75 * (1.0 - pulse)), false, 1.5)

	# --- Demirci (silah satıcısı) kapısı: örs simgesi, uzaktaysa kenarda ---
	var smith: Vector2 = _smith_pos()
	if smith != Vector2.ZERO:
		var spos: Vector2 = _world_to_map(smith)
		var soff: Vector2 = spos - center
		if _outside(soff, 7.0):
			spos = center + _clamp_edge(soff, 7.0)
		spos = spos.round()
		draw_circle(spos, 7.0, COLOR_OUTLINE)
		draw_circle(spos, 6.0, Color("#d8c39a"))
		## örs: üst tabla + gövde + taban (piksel)
		draw_rect(Rect2(spos + Vector2(-4, -3), Vector2(8, 2)), COLOR_SMITH_DARK)
		draw_rect(Rect2(spos + Vector2(-5, -3), Vector2(2, 1)), COLOR_SMITH_DARK)
		draw_rect(Rect2(spos + Vector2(-1, -1), Vector2(3, 2)), COLOR_SMITH_DARK)
		draw_rect(Rect2(spos + Vector2(-3, 1), Vector2(7, 2)), COLOR_SMITH_DARK)
		draw_rect(Rect2(spos + Vector2(-3, -3), Vector2(6, 1)), COLOR_SMITH)

	# --- Seyyar satıcı işareti ---
	if _merchant_marker_active:
		var mpos: Vector2 = _world_to_map(_merchant_marker_pos)
		var moffset: Vector2 = mpos - center
		if _outside(moffset, 5.0):
			moffset = _clamp_edge(moffset, 5.0)
			mpos = center + moffset
		draw_circle(mpos, 6.0, COLOR_MERCHANT)
		draw_circle(mpos, 6.0, Color(0.1, 0.1, 0.1, 0.6), false, 1.5)
		draw_string(ThemeDB.fallback_font, mpos + Vector2(-3.0, 3.0), "$",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.15, 0.1, 0.0, 1.0))

	# --- "Topla" kristalleri: küçük turkuaz elmaslar (2 px ızgaraya oturan, koyu konturlu) ---
	for mid in _collect_dots.keys():
		for idx in (_collect_dots[mid] as Dictionary).keys():
			var cpos: Vector2 = _world_to_map((_collect_dots[mid] as Dictionary)[idx]).round()
			if _outside(cpos - center, 3.0):
				continue
			draw_rect(Rect2(cpos - Vector2(2, 2), Vector2(4, 4)), Color("#3a2213"))
			draw_rect(Rect2(cpos - Vector2(1, 1), Vector2(2, 2)), COLOR_COLLECT)

	# --- Görev işaretleri (bkz. world_event_manager.gd) ---
	for id in _mission_markers.keys():
		var m: Dictionary = _mission_markers[id]
		var wpos: Vector2 = _world_to_map(m["pos"])
		var woffset: Vector2 = wpos - center
		if _outside(woffset, 5.0):
			woffset = _clamp_edge(woffset, 5.0)
			wpos = center + woffset
		draw_circle(wpos, 6.0, m["color"])
		draw_circle(wpos, 6.0, Color(0.1, 0.1, 0.1, 0.6), false, 1.5)
		draw_string(ThemeDB.fallback_font, wpos + Vector2(-3.0, 3.0), String(m["symbol"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.1, 0.05, 0.0, 1.0))

	# --- Piksel ahşap halka çerçeve (kenarlık); kare kipte çerçeveyi HUD çizer ---
	if not square:
		draw_texture(RING_TEXTURE, center - Vector2(RING_HALF, RING_HALF))

## Demircinin kapısının önü (dünya; weapon_shop.gd get_exterior_anchor_pos) - sahnede yoksa Vector2.ZERO. Düğüm bir kez aranır.
var _smith_node: Node = null
func _smith_pos() -> Vector2:
	if _smith_node == null or not is_instance_valid(_smith_node):
		var scene: Node = get_tree().current_scene if is_inside_tree() else null
		_smith_node = scene.get_node_or_null("WeaponShop") if scene != null else null
		if _smith_node == null or not _smith_node.has_method("get_exterior_anchor_pos"):
			_smith_node = null
			return Vector2.ZERO
	return _smith_node.call("get_exterior_anchor_pos")


## Oyuncu merkezli: görünüm merkezine göre dünya -> minimap. Daire dışına düşen noktayı çağıran taraf kenara kıstırır/eler.
func _world_to_map(world: Vector2) -> Vector2:
	var center: Vector2 = Vector2(RADIUS + 2.0, RADIUS + 2.0)
	return center + (world - _view_center) / VIEW_WORLD_PER_PX

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
