extends CanvasLayer

## LoL tarzı görüş alanı / "savaş sisi"
const ENABLED := true

## Görüş alanının yarıçapı (DÜNYA birimi)
const VISION_RADIUS := 250.0

## LoL'deki gibi dairesel/hafif oval yapı (1.6'dan 1.1'e çekildi)
const VISION_WIDTH_SCALE := 1.4

## Görüş sınırındaki yumuşama bandı (LoL tarzı net ama hafif yumuşak kenar)
const EDGE_SOFTNESS := 0.14

## LoL'de görüşe giriş (açılma) neredeyse anlıktır (1.0 sn yerine 0.15 sn)
const FADE_IN_TIME := 0.3

## Görüşten çıkınca arkada kalan izin kapanma süresi (2.0 sn yerine 1.2 sn)
const FADE_OUT_TIME := 1.2

## LoL'ün soğuk lacivert/gece tonu, daha koyu ve renksizleştirilmiş sis efekti
const FOG_TINT := Color(0.02, 0.05, 0.12, 1.0)
const FOG_DARKNESS := 0.32
const FOG_DESATURATION := 0.3

## Düşman gizleme eşikleri
const HIDE_BELOW := 0.02
const SIDE_ELEMENT_MIN_VISIBILITY := 0.5
## Silah/yetenek HEDEF SEÇİMİ için asgari görünürlük (bkz. can_target): oyuncunun
## GERÇEKTEN gördüğü (sisin yaratık için hesapladığı VIS_META, takım görüşü DAHİL)
## bir yaratık hedeflenebilir; görmediğimiz (duvarın ardı / görüş elipsinin dışı)
## hedeflenemez. Kullanıcı isteği: "göremediğimiz yaratıklara saldıramamalıyız,
## silahlar ve yetenekler onları hedef alamamalı".
const TARGETABLE_MIN_VISIBILITY := 0.5

## Duvar gölgesi kenarlarının yumuşatma yarıçapı (DÜNYA birimi; ~1.5 karo). Duvar
## gölgesi hücre-hücre/ikili hesaplandığı için ham hâli merdiven basamaklı ve sert çıkıyor;
## sis çizilirken maske bu yarıçapla yumuşatılır (bkz. vision_fog.gdshader mask_blur_uv).
## Sadece harita duvar ızgarası varken uygulanır - duvarsız sis eskisiyle birebir aynı.
## 0 = yumuşatma yok.
const MASK_BLUR_WORLD := 22.0

const MASK_DOWNSCALE := 4
const MAX_STEP := 0.1
const MAX_SOURCES := 8

const FOG_GROUP := "vision_fog"
const SOURCE_GROUPS: Array[String] = ["player", "remote_players"]
## DÜZELTME (kullanıcı isteği 2026-09-23: "oyuncunun ve dostlarının görüş alanı dışındaki hiçbir şeyin
## görünmesini istemiyorum, xp orb, sandık, altın v.b. yaratıkların görünmediği gibi onların da görünmemesini
## istiyorum") - yerdeki düşürülen eşyalar da (bkz. drop_attraction.gd/xp_orb.gd/gold_drop.gd/food_drop.gd/
## chest_drop.gd/magnet_drop.gd) artık düşmanlarla AYNI kurala tabi: görüş alanı dışında gizli.
const HIDEABLE_GROUPS: Array[String] = ["enemies", "enemy_projectiles", "xp_orbs", "gold_drops", "food_drops", "chest_drops", "magnet_drops"]

const HIDDEN_META := &"vision_fog_hidden"
const ALPHA_META := &"vision_fog_alpha"
const VIS_META := &"vision_fog_vis"

const FogShader: Shader = preload("res://shaders/vision_fog.gdshader")
const MaskShader: Shader = preload("res://shaders/vision_fog_mask.gdshader")
const VisionOccludersScript: GDScript = preload("res://scripts/vision_occluders.gd")

## Görüşü kesen karoların ızgarası (bkz. vision_occluders.gd). Harita sahnede yoksa
## (ana menü, testler, ev içi) null kalır ve sis eskisi gibi sadece elipse bakar.
var _occluders: RefCounted = null
var _occluders_searched: bool = false

var _rect: ColorRect = null
var _material: ShaderMaterial = null
var _mask_viewport: SubViewport = null
var _mask_material: ShaderMaterial = null

var _half_extent: Vector2 = Vector2.ZERO
var _world_sources: PackedVector2Array = PackedVector2Array()
var _uv_sources: PackedVector2Array = PackedVector2Array()
var _cell_sources: PackedVector2Array = PackedVector2Array()
var _source_count: int = 0
var _active: bool = false
var _has_managed: bool = false

var _needs_reset: bool = true
var _prev_origin: Vector2 = Vector2.ZERO
var _prev_zoom: Vector2 = Vector2.ONE

## Kullanıcı isteği (2026-09-25): "gece olunca görüş açısı %25 azalacak (hava kararmaya doğru kademeli şekilde yavaş
## yavaş ... daha dar görüş açısı)". Elips artık sabit VISION_RADIUS değil, bu değer: VISION_RADIUS x atmosferin görüş
## çarpanı (atmosphere.gd -> atmosphere_math.gd vision_multiplier: gündüz 1.0, gece 0.75, arası kademeli). Saat host'tan
## senkron geldiği için her istemcide aynı. Atmosfer yoksa (ana menü, testler) VISION_RADIUS'ta kalır.
var _vision_radius: float = VISION_RADIUS
var _atmosphere: Node = null
var _screen_copy: BackBufferCopy = null


func _ready() -> void:
	add_to_group(FOG_GROUP)
	layer = 1
	process_priority = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ENABLED:
		set_process(false)
		return

	_uv_sources.resize(MAX_SOURCES)
	_cell_sources.resize(MAX_SOURCES)

	_mask_viewport = SubViewport.new()
	_mask_viewport.name = "MaskViewport"
	_mask_viewport.disable_3d = true
	_mask_viewport.transparent_bg = false
	_mask_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_fit_mask_to_viewport(get_viewport().get_visible_rect().size)
	add_child(_mask_viewport)

	_mask_material = ShaderMaterial.new()
	_mask_material.shader = MaskShader
	_mask_material.set_shader_parameter("edge_softness", EDGE_SOFTNESS)
	_mask_material.set_shader_parameter("sources", _uv_sources)
	_mask_material.set_shader_parameter("source_count", 0)
	_mask_material.set_shader_parameter("source_cells", _cell_sources)
	_mask_material.set_shader_parameter("min_wall_crossing", VisionOccludersScript.MIN_WALL_CROSSING)

	var mask_rect := ColorRect.new()
	mask_rect.name = "MaskRect"
	mask_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask_rect.material = _mask_material
	_mask_viewport.add_child(mask_rect)
	mask_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_material = ShaderMaterial.new()
	_material.shader = FogShader
	_material.set_shader_parameter("fog_mask", _mask_viewport.get_texture())
	_material.set_shader_parameter("fog_tint", FOG_TINT)
	_material.set_shader_parameter("fog_darkness", FOG_DARKNESS)
	_material.set_shader_parameter("fog_desaturation", FOG_DESATURATION)

	## Gün-gece renk geçişi (atmosphere_overlay.gd) de ekranı okuyup sisten hemen ÖNCE çiziliyor. Godot 2B'de ekran
	## kopyasını art arda okuyan iki geçişten ikincisi ilkinin sonucunu göremeyebilir (kopya bir kez alınır) - sis tam
	## ekranı opak yazdığı için bu durumda gece renkleri tamamen silinirdi. Bu kopya sisin, önündeki her şey (dünya +
	## gece renkleri) çizildikten SONRAKİ ekranı okumasını garanti eder. Sis kapalıyken bu da kapalı.
	_screen_copy = BackBufferCopy.new()
	_screen_copy.name = "ScreenCopy"
	_screen_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_screen_copy.visible = false
	add_child(_screen_copy)

	_rect = ColorRect.new()
	_rect.name = "Fog"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	_rect.visible = false
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _exit_tree() -> void:
	if is_inside_tree():
		_apply_enemy_visibility(false, 0.0)


func _process(_delta: float) -> void:
	update_fog()


func is_active() -> bool:
	return _active


func get_source_count() -> int:
	return _source_count


static func fog_visibility_of(node: Node) -> float:
	return float(node.get_meta(VIS_META, 1.0))


static func normalized_distance(offset: Vector2, radius: float, width_scale: float) -> float:
	return Vector2(offset.x / (radius * maxf(width_scale, 0.05)), offset.y / radius).length()


static func visibility_from_distance(normalized: float, softness: float) -> float:
	var half_band: float = maxf(softness, 0.01) * 0.5
	return 1.0 - smoothstep(1.0 - half_band, 1.0 + half_band, normalized)


func is_world_pos_visible(world_pos: Vector2) -> bool:
	if not _active:
		return true
	return _target_visibility(world_pos) >= TARGETABLE_MIN_VISIBILITY


## Bu yaratık (ya da düşman mermisi) silah/yetenek tarafından HEDEF olarak seçilebilir mi?
## Silahlar/yetenekler hedef SEÇERKEN (en yakın/rastgele/en canlı düşman, zincir
## sıçraması, totem/sarmaşık/hortum/yarasa hedefi...) bunu kontrol etmeli. Alan hasarı
## (nova, itme, patlama), mermi/kılıç çarpışması ve hareket engelleme hedef SEÇMEDİĞİ için
## bunu kullanmaz.
##  - Sis yaratığı zaten yönetiyorsa (VIS_META var) o değer kullanılır: oyuncunun ekranda
##    gördüğüyle BİREBİR aynı, ve takım arkadaşlarının görüşü de dahil (SOURCE_GROUPS).
##  - Henüz yönetilmemişse (yeni doğmuş, sis o karede daha çalışmadı) sisin geometrik
##    hesabına sorulur; sis yoksa/kapalıysa (ana menü, ev içi, testler) her şey hedeflenebilir.
static func can_target(node: Node) -> bool:
	## Yaratık yeteneği (2026-09-24): görünmez hayalet hedef alınamaz (bkz. enemy.gd set_ability_invisible).
	if node.has_meta(&"untargetable"):
		return false
	if node.has_meta(VIS_META):
		return float(node.get_meta(VIS_META)) >= TARGETABLE_MIN_VISIBILITY
	if not node.is_inside_tree() or not (node is Node2D):
		return true
	var fog: Node = node.get_tree().get_first_node_in_group(FOG_GROUP)
	if fog == null or not fog.has_method("is_world_pos_visible"):
		return true
	return fog.is_world_pos_visible((node as Node2D).global_position)


func update_fog(delta: float = -1.0) -> void:
	if _material == null:
		return
	if get_tree().paused:
		_mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if delta < 0.0:
		delta = get_process_delta_time()
	delta = minf(delta, MAX_STEP)
	_ensure_occluders()

	var world_sources: PackedVector2Array = _collect_source_positions()
	_active = not world_sources.is_empty() and not _local_player_indoors()
	_vision_radius = VISION_RADIUS * _atmosphere_vision_multiplier()
	if _active:
		_world_sources = world_sources
		_source_count = world_sources.size()
		_update_half_extent()
		for i: int in range(MAX_SOURCES):
			_uv_sources[i] = _world_to_uv(world_sources[i]) if i < _source_count else Vector2.ZERO
		_push_mask_uniforms(delta)
		_mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		_world_sources = PackedVector2Array()
		_source_count = 0
		_needs_reset = true
		_mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_rect.visible = _active
	_screen_copy.visible = _active
	_apply_enemy_visibility(_active, delta)


func _atmosphere_vision_multiplier() -> float:
	if _atmosphere == null or not is_instance_valid(_atmosphere):
		_atmosphere = get_tree().get_first_node_in_group("atmosphere")
		if _atmosphere == null:
			return 1.0
	return float(_atmosphere.call("get_vision_multiplier"))


## O anki (gece daralmış) görüş yarıçapı - sisin DIŞINDAN elipsi kendi hesaplayan yerler için (bkz. player.gd Matthew
## Tilki Hücumu). Sis yoksa VISION_RADIUS.
static func current_radius(tree: SceneTree) -> float:
	var fog: Node = tree.get_first_node_in_group(FOG_GROUP) if tree else null
	if fog == null:
		return VISION_RADIUS
	return float(fog.get("_vision_radius"))


func _push_mask_uniforms(delta: float) -> void:
	var viewport: Viewport = get_viewport()
	var size: Vector2 = viewport.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var xform: Transform2D = viewport.get_canvas_transform()
	var origin: Vector2 = xform.origin
	var zoom: Vector2 = xform.get_scale()
	
	var shift_px: Vector2 = _prev_origin - origin
	var resized: bool = _fit_mask_to_viewport(size)
	
	var jumped: bool = absf(shift_px.x) > size.x * 0.5 or absf(shift_px.y) > size.y * 0.5 \
			or not zoom.is_equal_approx(_prev_zoom)
	var keep: float = 0.0 if (_needs_reset or resized or jumped) else 1.0
	_needs_reset = false
	_prev_origin = origin
	_prev_zoom = zoom

	_mask_material.set_shader_parameter("sources", _uv_sources)
	_mask_material.set_shader_parameter("source_count", _source_count)
	_mask_material.set_shader_parameter("half_extent", _half_extent)
	_push_occluder_uniforms(size, origin, zoom)
	_mask_material.set_shader_parameter("shift_uv", shift_px / size)
	_mask_material.set_shader_parameter("history_keep", keep)
	_mask_material.set_shader_parameter("up_step", delta / maxf(FADE_IN_TIME, 0.01))
	_mask_material.set_shader_parameter("down_step", delta / maxf(FADE_OUT_TIME, 0.01))


## Ekran UV'sini (maske pikseli) harita KARO koordinatına çeviren doğrusal dönüşüm
## + kaynakların karo koordinatları. Dünya = (UV * ekran - canvas_origin) / zoom,
## karo = (dünya - ızgara_kökeni) / karo_boyu (bkz. vision_fog_mask.gdshader).
func _push_occluder_uniforms(size: Vector2, origin: Vector2, zoom: Vector2) -> void:
	var enabled: bool = _occluders != null and not _occluders.is_empty()
	_mask_material.set_shader_parameter("occluder_enabled", enabled)
	var blur_uv := Vector2.ZERO
	if enabled and MASK_BLUR_WORLD > 0.0:
		blur_uv = Vector2(MASK_BLUR_WORLD * absf(zoom.x) / size.x, MASK_BLUR_WORLD * absf(zoom.y) / size.y)
	_material.set_shader_parameter("mask_blur_uv", blur_uv)
	if not enabled:
		return
	var cell_size: float = _occluders.get_cell_size()
	var world_origin: Vector2 = _occluders.get_world_origin()
	_mask_material.set_shader_parameter("occluder_grid_origin", Vector2(_occluders.get_grid_origin()))
	_mask_material.set_shader_parameter("occluder_grid_size", Vector2(_occluders.get_grid_size()))
	_mask_material.set_shader_parameter("uv_to_cell_scale", size / (zoom * cell_size))
	_mask_material.set_shader_parameter("uv_to_cell_offset", (-origin / zoom - world_origin) / cell_size)
	for i: int in range(MAX_SOURCES):
		_cell_sources[i] = _occluders.world_to_cell_f(_world_sources[i]) if i < _source_count else Vector2.ZERO
	_mask_material.set_shader_parameter("source_cells", _cell_sources)


## Görüşü kesen karo ızgarasını (orman/uçurum duvarı) bir kere kurar. Harita henüz
## sahnede değilse (ana menü) sonraki karede tekrar dener; bulunca texture'ı maskeye verir.
func _ensure_occluders() -> void:
	if _occluders_searched:
		return
	var layer: TileMapLayer = GameManager.get_forest_layer()
	if layer == null:
		return
	_occluders_searched = true
	var built: RefCounted = VisionOccludersScript.new()
	## Kullanıcı isteği: "küçük parçaların görüşü engellememe sınırını kaldır, onları
	## haritadan kaldırdım, bu layerdaki HER ŞEY görüşü engellesin" - eskiden 20
	## hücreden küçük kümeler (taş/mantar/çalı) eleniyordu, artık katmanın tüm
	## hücreleri keser (çarpışmayla, bkz. GameManager.is_position_blocked_by_forest, aynı küme).
	built.build(layer)
	set_occluders(built)


## Testler ve _ensure_occluders için: engel ızgarasını verir (null = engel yok).
func set_occluders(occluders: RefCounted) -> void:
	_occluders = occluders
	_occluders_searched = true
	if _mask_material == null:
		return
	var texture: ImageTexture = null
	if occluders != null:
		texture = occluders.make_texture()
	_mask_material.set_shader_parameter("occluders", texture)


func _fit_mask_to_viewport(size: Vector2) -> bool:
	var wanted := Vector2i(
		maxi(1, ceili(size.x / float(MASK_DOWNSCALE))),
		maxi(1, ceili(size.y / float(MASK_DOWNSCALE))))
	if _mask_viewport.size == wanted:
		return false
	_mask_viewport.size = wanted
	return true


func _collect_source_positions() -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for group_name: String in SOURCE_GROUPS:
		for node: Node in get_tree().get_nodes_in_group(group_name):
			var body: Node2D = node as Node2D
			if body == null or not _gives_vision(body):
				continue
			result.append(body.global_position)
			if result.size() >= MAX_SOURCES:
				return result
	return result


func _gives_vision(body: Node2D) -> bool:
	if body.get("is_indoors") == true:
		return false
	var dead: bool = body.get("is_dead") == true
	var downed: bool = body.get("is_downed") == true
	return (not dead) or downed


func _local_player_indoors() -> bool:
	var local_player: Node = get_tree().get_first_node_in_group("player")
	return local_player != null and local_player.has_method("is_indoors_now") and local_player.is_indoors_now()


func _update_half_extent() -> void:
	var viewport: Viewport = get_viewport()
	var size: Vector2 = viewport.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var zoom: Vector2 = viewport.get_canvas_transform().get_scale()
	var half_width_world: float = _vision_radius * maxf(VISION_WIDTH_SCALE, 0.05)
	_half_extent = Vector2(half_width_world * absf(zoom.x) / size.x, _vision_radius * absf(zoom.y) / size.y)


func _world_to_uv(world_pos: Vector2) -> Vector2:
	var viewport: Viewport = get_viewport()
	var size: Vector2 = viewport.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	return (viewport.get_canvas_transform() * world_pos) / size


## En iyi kaynağın görünürlüğü: her kaynak için elips görünürlüğü, ARADA görüşü kesen
## bir duvar varsa (bkz. vision_occluders.gd) 0. Duvar taraması sadece bir kaynak
## şu ana kadarki en iyiyi GEÇEBİLİYORSA yapılır (çoğu düşman elipsin dışında).
## GPU'daki maske (vision_fog_mask.gdshader) AYNI kuralı piksel başına uygular.
func _target_visibility(world_pos: Vector2) -> float:
	var best: float = 0.0
	for source: Vector2 in _world_sources:
		var vis: float = visibility_from_distance(
				normalized_distance(world_pos - source, _vision_radius, VISION_WIDTH_SCALE), EDGE_SOFTNESS)
		if vis <= best:
			continue
		if _occluders != null and _occluders.is_ray_blocked(source, world_pos):
			continue
		best = vis
	return best


## PERF (kullanıcı bildirimi: 200 yaratıkta FPS çöküşü - gerçek oyunda ölçüldü:
## bu fonksiyon gerçek haritada kare başına ~3-4ms; oyuncuyu saran kümenin
## tamamı görüş elipsinin içinde olduğu için HER yaratık için HER karede bir
## duvar ışın taraması yapılıyordu). Artık her öğe MANAGE_INTERVAL_FRAMES karede
## bir (instance_id'ye göre kaydırmalı) güncelleniyor - iş yükü 1/3. Görünürlük artık
## İKİLİ olduğu için (bkz. _manage_item) bunun tek etkisi, sınırı geçen bir öğenin
## görünüp/gizlenmesinin en fazla MANAGE_INTERVAL_FRAMES kare (~50ms) gecikmesi -
## fark edilmeyecek kadar kısa. İlk kez görülen öğe (VIS_META yok) beklemeden hemen
## işleniyor ki yeni doğan yaratık sisin içinde bir an bile görünür kalmasın.
const MANAGE_INTERVAL_FRAMES := 3

func _apply_enemy_visibility(enable: bool, delta: float) -> void:
	if not enable and not _has_managed:
		return
	var any_managed: bool = false
	var frame: int = Engine.get_process_frames()
	for group_name: String in HIDEABLE_GROUPS:
		for node: Node in get_tree().get_nodes_in_group(group_name):
			var item: Node2D = node as Node2D
			if item == null:
				continue
			if enable:
				any_managed = true
				if not item.has_meta(VIS_META):
					_manage_item(item, delta)
				elif (frame + item.get_instance_id()) % MANAGE_INTERVAL_FRAMES == 0:
					_manage_item(item, delta * MANAGE_INTERVAL_FRAMES)
			else:
				_release_item(item)
	_has_managed = any_managed


## DÜZELTME (kullanıcı isteği 2026-09-23: "görüş alanına giren veya görüş alanından çıkan şeyler (yaratıklar
## dahil) opaklaşarak görünmesin bir anda görünsün") - eskiden move_toward ile FADE_IN_TIME (0.3sn)/FADE_OUT_TIME
## (1.2sn) boyunca modulate.a yavaşça 0<->1 arasında YUMUŞAK geçiyordu. Artık görünürlük TAMAMEN İKİLİ: öğe
## görüş alanına girdiği/çıktığı karede DOĞRUDAN tam görünür/tam gizli olur, ara bir "yarı saydam" durum YOK -
## VIS_META hâlâ can_target()/is_world_pos_visible()/minimap.gd/floating_text.gd'nin okuduğu HAM (zaman
## gecikmesiz) konumsal değeri taşıyor, o tarafların 0.5 eşiği DEĞİŞMEDİ.
func _manage_item(item: Node2D, _delta: float) -> void:
	var target: float = _target_visibility(item.global_position)
	## PERF DÜZELTMESİ (kullanıcı bildirimi: yaratık sayısı 200'e yaklaşırken FPS 20'lere düşüyordu) - bu fonksiyon
	## HER "enemies"/"enemy_projectiles"/eşya üyesi için HER PROCESS KARESİNDE çağrılıyor (bkz.
	## _apply_enemy_visibility), eleman sayısıyla DOĞRUSAL büyüyor. Oyuncudan uzak öğelerin büyük çoğunluğu
	## zaten görünmez durumda KALICI olarak sabit kalıyor - hedef görünürlük 0 VE zaten gizliyse hiçbir şey
	## değişmeyecek, get_meta/set_meta'ya bile gerek yok.
	if target <= 0.0 and not item.visible:
		return
	item.set_meta(VIS_META, target)
	## Fog sadece KENDİ gizlediğini (HIDDEN_META) geri açar - başka bir sistemin (ör. ölüm, "sıyrılma"
	## görünmezliği) visible=false yaptığı bir öğeye asla dokunmaz (bkz. test_fog_does_not_unhide_nodes_
	## hidden_by_someone_else). Eski move_toward'lı sürümde bu, "vis 1'e sadece HIDDEN_META varsa görünür yap"
	## dalıyla zımnen sağlanıyordu - ikili modelde de AYNI kural açıkça korunuyor.
	if target > HIDE_BELOW:
		if item.has_meta(HIDDEN_META):
			item.remove_meta(HIDDEN_META)
			item.visible = true
	elif item.visible:
		item.visible = false
		item.set_meta(HIDDEN_META, true)


func _release_item(item: Node2D) -> void:
	if item.has_meta(HIDDEN_META):
		item.remove_meta(HIDDEN_META)
		item.visible = true
	if item.has_meta(ALPHA_META):
		item.remove_meta(ALPHA_META)
		var color: Color = item.modulate
		color.a = 1.0
		item.modulate = color
	if item.has_meta(VIS_META):
		item.remove_meta(VIS_META)
