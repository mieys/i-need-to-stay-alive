extends Node2D
class_name OakleyTree

## Oakley R "Hayat Ağacı" (skill3 id 39, madde 266; görünüş = madde 265 prototipi C "Bereket Ağacı", ağaç + aura %30 büyük,
## kullanıcı: "ağacın sarmaşık efekti C olsun. ağaç ve aurası %30 büyüsün... ağaç olarak da C olsun").
## Akış (dikimden itibaren, sn): tohum (0,15) -> küçük ağaç topraktan çıkar (0,45-0,73) -> orta (0,82) -> büyük (1,1) + açılış darbesi
## (alandaki yaratıklar itilir) -> DURATION'a kadar: gölgesindeki (2:1 elips ZONE_RX x ZONE_RY) oyunculara HEAL_INTERVAL'de bir
## ağaçtan elma uçar, düştüğü an can + mana kalkanı; ROOT_INTERVAL'de bir kökler toprak altından en yakın ROOT_TARGETS yaratığa
## gider, dibinden fışkırıp ROOT_DURATION sabitler (boss yavaşlar) -> DURATION: ağaç küçülerek toprağa çekilir, 3 çiçek bırakır.
##
## Çok oyunculu (CLAUDE.md "MP iki-yer hatası"): kaster (player.gd _skill_oakley_tree) GERÇEK kopyayı kurar - hedef seçimi, hasar,
## sabitleme, iyileştirme, itme, çiçek SADECE orada. Diğer istemciler "oakley_tree" yayınıyla KOZMETİK kopyayı (caster = null) kurar;
## kök dalgaları "oakley_tree_root" ile gelir (sadece yer altı izi - yaratığın dibindeki kök sarılması enemy.gd root_start
## style ROOT_STYLE ile herkeste kurulur), elmalar her kopyada yerel kuralla (o an alandaki oyuncular) uçar.
## Sanat: tools/gen_hayat_agaci_fx.py -> assets/fx/oakley/hayat_agaci/ (ağaçlar haritanın kendi tileseti, efektler 1 dünya px).

const BalanceLogScript: GDScript = preload("res://scripts/balance_log.gd")
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const VisionFogScript: GDScript = preload("res://scripts/vision_fog.gd")
const EnemyAbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const SwayShader := preload("res://shaders/oakley_agac.gdshader")

const TEX_TREE: Array[Texture2D] = [
	preload("res://assets/fx/oakley/hayat_agaci/agac_kucuk.png"),
	preload("res://assets/fx/oakley/hayat_agaci/agac_orta.png"),
	preload("res://assets/fx/oakley/hayat_agaci/agac_buyuk.png"),
]
const TEX_SMALL_PLAIN := preload("res://assets/fx/oakley/hayat_agaci/agac_kucuk_golgesiz.png")
const TEX_ZONE := preload("res://assets/fx/oakley/hayat_agaci/alan.png")
const TEX_RAYS_BACK := preload("res://assets/fx/oakley/hayat_agaci/isik_arka.png")
const TEX_RAYS_FRONT := preload("res://assets/fx/oakley/hayat_agaci/isik_on.png")
const TEX_RING := preload("res://assets/fx/oakley/hayat_agaci/halka.png")
const TEX_MOUND := preload("res://assets/fx/oakley/hayat_agaci/tumsek.png")
const TEX_FRUIT := preload("res://assets/fx/oakley/hayat_agaci/meyve.png")
const TEX_PLUS := preload("res://assets/fx/oakley/hayat_agaci/arti.png")
const TEX_SEED := preload("res://assets/fx/oakley/hayat_agaci/tohum.png")
const TEX_SPARK: Array[Texture2D] = [
	preload("res://assets/fx/oakley/hayat_agaci/parilti_1.png"),
	preload("res://assets/fx/oakley/hayat_agaci/parilti_2.png"),
	preload("res://assets/fx/oakley/hayat_agaci/parilti_3.png"),
]
## Kırpılmış dokuda gövde dibi + boy (gen_hayat_agaci_fx.py çıktısı) - küçük, orta, büyük.
const TREE_BASE: Array[Vector2] = [Vector2(15.5, 34.0), Vector2(26.5, 61.0), Vector2(30.5, 68.0)]
const TREE_HEIGHT: Array[float] = [35.0, 62.0, 69.0]
## Haritanın ağaç pikseli 1 dünya birimi; kullanıcı isteği "%30 büyüsün" -> 1,3 (alan da aynı oranla, bkz. ZONE_RX).
const TREE_SCALE := 1.3

## ---- zaman (sn, dikimden itibaren) ----
const T_SEED := 0.15
const T_SMALL := 0.45
const RISE := 0.28
const T_MED := 0.82
const T_LARGE := 1.1
## Ağacın ayakta kaldığı süre; player.gd SKILL3_TIMING[39]["duration"] bunu okur, characters.gd metni "12sn".
const DURATION := 12.0
const END_MED := 0.15
const END_SMALL := 0.32
const END_SINK := 0.3
const LIFE := DURATION + END_SMALL + END_SINK + 0.1
const FLOWER_DELAY := 0.4 ## DURATION'dan sonra çiçeklerin düştüğü an (küçük ağaç toprağa girerken)

## ---- alan + etkiler (ÖNERİ değerleri, madde 266; denge değişirse characters.gd DEFS[2] skill3_desc + BALANCE_REV) ----
const ZONE_RX := 169.0 ## 130 x 1,3 (Şovalye kubbesi gibi 2:1 elips)
const ZONE_RY := 84.5
const HEAL_INTERVAL := 1.0
const HEAL_FIRST := T_LARGE + 0.6
const HEAL_AP_RATIO := 0.15 ## tik başına saldırı gücünün %15'i can
const HEAL_MAX_HP_PERCENT := 0.01 ## + azami canın %1'i
const SHIELD_AP_RATIO := 0.08 ## + saldırı gücünün %8'i mana kalkanı
const FRUIT_FLIGHT := 0.5
const ROOT_FIRST := 2.0
const ROOT_INTERVAL := 2.0
const ROOT_TARGETS := 3
const ROOT_RANGE := 260.0
const ROOT_DURATION := 4.0
const ROOT_SPEED := 330.0
const ROOT_DAMAGE_RATIO := 0.40
const BOSS_SLOW_PERCENT := 0.30 ## Sarmaşıklar (E) ile aynı: bosslar sabitlenmez, yavaşlar
const ROOT_STYLE := 1 ## enemy.gd apply_root stil: 0 = E sarmaşığı (entangle), 1 = bu ağacın kökleri (fx_oakley_tree_root.gd)
const OPEN_PUSH_DISTANCE := 42.0
const OPEN_PUSH_RADIUS := 234.0 ## 2:1 ölçüde (alanın 1,4 katı)
## Oyuncu kökü gövde ortası; ayak hizası (alan içi sayılırken) - mission_tree.gd _update_depth ile aynı ofset.
const PLAYER_FEET_OFFSET := 12.75
const FLOWER_OFFSETS: Array[Vector2] = [Vector2(-57.0, 18.0), Vector2(60.0, 10.0), Vector2(5.0, 44.0)]
## Bereketli Meyve evrimi (madde 348): 6 çiçek - ilk 3 yukarıdakiler, sonraki 3 ağacın etrafında biraz daha açıkta.
const FLOWER_OFFSETS_EXTRA: Array[Vector2] = [Vector2(-92.0, 40.0), Vector2(94.0, 34.0), Vector2(-40.0, 62.0)]

## ---- sayfa geometrisi (gen_hayat_agaci_fx.py) ----
const RAY_FRAMES := 14
const RAY_FPS := 12.0
const RAY_W := 344.0
const RAY_TOP_PAD := 46.0
const RING_FRAMES := 6
const RING_FPS := 14.0
const BOSS_GROUP := &"bosses"

var caster: Node = null ## null = kozmetik kopya
## ---- Yetenek evrimleri (madde 348) - spawn(params) add_child'dan ÖNCE atar; boşsa eski değerler ----
var _duration: float = DURATION ## Kadim Gövde: 16 sn (kozmetik kopya da aynı süreyi görsün diye yayınla gelir)
var _zone_mult: float = 1.0 ## Kadim Gövde: gölge alanı x1,25 (görsel + in_zone + açılış darbesi)
var _fruit_mult: float = 1.0 ## Bereketli Meyve: meyvenin can + kalkan miktarı x1,4
var _flower_count: int = 3 ## Bereketli Meyve: 6
var _revive_enabled: bool = false ## Kadim Diriliş: gölgede yere düşen dostu kaldırır
var _revive_used: bool = false ## ... ağaç başına bir kez
var _t: float = 0.0
var _tree: Sprite2D = null
var _seed: Sprite2D = null
var _seed_mound: Sprite2D = null
var _seed_spark: Sprite2D = null
var _zone: Sprite2D = null
var _rays_back: Sprite2D = null
var _rays_front: Sprite2D = null
var _ring: Sprite2D = null
var _last_size: int = -1
var _opened: bool = false
var _flowers_done: bool = false
var _next_heal: float = HEAL_FIRST
var _next_wave: float = ROOT_FIRST
var _recent_roots: Dictionary = {} ## instance_id -> sabitlemenin biteceği _t (aynı yaratığa üst üste kök yollanmasın)


## Kaster: spawn(sahne, nokta, kendisi); diğer istemciler: spawn(sahne, nokta) (network_manager.gd "oakley_tree").
## params: "dur", "zone" (kaster + kozmetik kopya), "fruit", "flowers", "revive" (sadece kaster) - player.gd _skill_oakley_tree.
static func spawn(parent: Node, at: Vector2, p_caster: Node = null, params: Dictionary = {}) -> OakleyTree:
	var t := OakleyTree.new()
	t.caster = p_caster
	t._duration = maxf(1.0, float(params.get("dur", DURATION)))
	t._zone_mult = maxf(0.5, float(params.get("zone", 1.0)))
	t._fruit_mult = float(params.get("fruit", 1.0))
	t._flower_count = int(params.get("flowers", 3))
	t._revive_enabled = bool(params.get("revive", false)) and p_caster != null
	## Konum add_child'dan ÖNCE: _ready alanı/ışıkları/tohumu o anki konuma kurar (sonra atanınca hepsi dünya merkezinde kalıyordu).
	t.position = (parent as Node2D).to_local(at) if parent is Node2D else at
	parent.add_child(t)
	t.global_position = at
	return t


func is_cosmetic() -> bool:
	return caster == null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("oakley_trees")
	_tree = Sprite2D.new()
	_tree.centered = false
	_tree.scale = Vector2.ONE * TREE_SCALE
	_tree.visible = false
	var mat := ShaderMaterial.new()
	mat.shader = SwayShader
	mat.set_shader_parameter("faz", fposmod(global_position.x * 0.013, TAU))
	_tree.material = mat
	add_child(_tree)
	var root: Node = get_tree().current_scene
	_seed_mound = _ground_sprite(root, TEX_MOUND, 2)
	_seed_mound.visible = false
	_seed = _top_sprite(root, TEX_SEED, 3)
	_seed.visible = false
	_seed_spark = _top_sprite(root, TEX_SPARK[0], 3)
	_seed_spark.visible = false
	_zone = _ground_sprite(root, TEX_ZONE, 1)
	_zone.scale = Vector2.ONE * _zone_mult
	_zone.modulate.a = 0.0
	_rays_back = _top_sprite(root, TEX_RAYS_BACK, 0, RAY_FRAMES)
	_rays_back.centered = false
	_rays_back.offset = -Vector2(RAY_W * 0.5, RAY_TOP_PAD + ZONE_RY)
	_rays_back.scale = Vector2.ONE * _zone_mult
	_rays_back.modulate.a = 0.0
	_rays_front = _top_sprite(root, TEX_RAYS_FRONT, 2, RAY_FRAMES)
	_rays_front.centered = false
	_rays_front.offset = -Vector2(RAY_W * 0.5, RAY_TOP_PAD)
	_rays_front.scale = Vector2.ONE * _zone_mult
	_rays_front.modulate.a = 0.0
	_update_visuals()


## Zemin katmanında (haritanın hemen üstü, yaratık/oyuncuların altı) duran düğüm - EnemyAbilities.place_on_ground.
func _ground_sprite(root: Node, tex: Texture2D, hframes: int) -> Sprite2D:
	var s := _make_sprite(tex, hframes)
	root.add_child(s)
	EnemyAbilitiesScript.place_on_ground(get_tree(), s)
	s.global_position = global_position
	return s


func _top_sprite(root: Node, tex: Texture2D, z: int, hframes: int = 1) -> Sprite2D:
	var s := _make_sprite(tex, hframes)
	s.z_index = z
	root.add_child(s)
	s.global_position = global_position
	return s


static func _make_sprite(tex: Texture2D, hframes: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = maxi(1, hframes)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


func _exit_tree() -> void:
	for n in [_seed, _seed_mound, _seed_spark, _zone, _rays_back, _rays_front, _ring]:
		if is_instance_valid(n):
			(n as Node).queue_free()


func _process(delta: float) -> void:
	_t += delta
	_update_visuals()
	if not _opened and _t >= T_LARGE:
		_opened = true
		_on_open()
	if _t < _duration:
		while _t >= _next_heal and _next_heal < _duration:
			_heal_tick()
			_next_heal += HEAL_INTERVAL
		if not is_cosmetic():
			while _t >= _next_wave and _next_wave < _duration - 0.5:
				_root_wave()
				_next_wave += ROOT_INTERVAL
			if _revive_enabled and not _revive_used and _opened:
				_try_revive()
	if not _flowers_done and _t >= _duration + FLOWER_DELAY:
		_flowers_done = true
		_drop_flowers()
	if _t >= _duration + END_SMALL + END_SINK + 0.1: ## = LIFE (varsayılan süre için)
		queue_free()


## (boy 0/1/2 ya da -1, gömülme 0..1, gölgeli doku mu) - testler de kullanır.
static func tree_state(t: float, dur: float = DURATION) -> Array:
	if t < T_SMALL:
		return [-1, 0.0, false]
	if t < T_SMALL + RISE:
		return [0, 1.0 - _ease_out((t - T_SMALL) / RISE), false]
	if t < T_MED:
		return [0, 0.0, true]
	if t < T_LARGE:
		return [1, 0.0, true]
	if t < dur + END_MED:
		return [2, 0.0, true]
	if t < dur + END_SMALL:
		return [1, 0.0, true]
	if t < dur + END_SMALL + END_SINK:
		return [0, _ease_out((t - dur - END_SMALL) / END_SINK), false]
	return [-1, 0.0, false]


static func zone_alpha(t: float, dur: float = DURATION) -> float:
	if t < T_LARGE:
		return 0.0
	if t < dur:
		return _ease_out((t - T_LARGE) / 0.3)
	return maxf(0.0, 1.0 - (t - dur) / 0.4)


static func _ease_out(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - c, 3.0)


static func band(a: float, n: int) -> float:
	return clampf(roundf(a * float(n)) / float(n), 0.0, 1.0)


## 2:1 alan içinde mi (ayak noktası).
func in_zone(feet: Vector2) -> bool:
	var d: Vector2 = feet - global_position
	var rx: float = ZONE_RX * _zone_mult
	var ry: float = ZONE_RY * _zone_mult
	return (d.x / rx) * (d.x / rx) + (d.y / ry) * (d.y / ry) <= 1.0


func _update_visuals() -> void:
	var st: Array = tree_state(_t, _duration)
	var size: int = int(st[0])
	if size < 0:
		_tree.visible = false
	else:
		_tree.visible = true
		var shad: bool = bool(st[2])
		var tex: Texture2D = TEX_TREE[size] if (shad or size != 0) else TEX_SMALL_PLAIN
		if _tree.texture != tex:
			_tree.texture = tex
		var base: Vector2 = TREE_BASE[size]
		var sink_px: int = int(roundf(float(st[1]) * (TREE_HEIGHT[size] + 2.0)))
		if sink_px > 0: ## topraktan çıkar / toprağa çekilir: zemin çizgisinin altı görünmez (ölçek değişmez, piksel bozulmaz)
			_tree.region_enabled = true
			_tree.region_rect = Rect2(0.0, 0.0, float(tex.get_width()), maxf(0.0, base.y + 1.0 - float(sink_px)))
			_tree.offset = Vector2(-base.x, -base.y + float(sink_px))
		else:
			_tree.region_enabled = false
			_tree.offset = -base
		if size != _last_size:
			if _last_size >= 0 or size > 0:
				_spark_burst(size == 2 and _t < _duration)
			_last_size = size
		_tree.z_index = 2 if _player_behind(size) else 0
	## tohum: toprak tümseği + parlayan tane, küçük ağaç çıkana kadar
	var seed_on: bool = _t >= T_SEED and _t < T_SMALL + RISE
	_seed_mound.visible = seed_on
	_seed.visible = seed_on and _t < T_SMALL + 0.1
	_seed_spark.visible = _seed.visible
	if _seed.visible:
		var q: float = (_t - T_SEED) / (T_SMALL + 0.1 - T_SEED)
		_seed.global_position = global_position + Vector2(0.0, -2.0 - 2.0 * q)
		_seed_spark.texture = TEX_SPARK[clampi(int(q * 3.0), 0, 2)]
		_seed_spark.global_position = global_position + Vector2(0.0, -6.0 - 3.0 * q)
	## alan + kenar ışıkları
	var za: float = zone_alpha(_t, _duration)
	_zone.modulate.a = za
	_rays_back.modulate.a = za
	_rays_front.modulate.a = za
	if za > 0.0:
		var rf: int = int(_t * RAY_FPS) % RAY_FRAMES
		_rays_back.frame = rf
		_rays_front.frame = rf
	## açılış halkası
	if _ring != null and is_instance_valid(_ring):
		var f: int = int((_t - T_LARGE) * RING_FPS)
		if f >= RING_FRAMES:
			_ring.queue_free()
			_ring = null
		else:
			_ring.frame = maxi(0, f)


## mission_tree.gd _update_depth ile aynı kural: bir oyuncunun ayağı kökün yukarısında ve ağacın genişliğindeyse ağaç onun üstünde.
func _player_behind(size: int) -> bool:
	var h: float = TREE_HEIGHT[size] * TREE_SCALE
	var half_w: float = TREE_BASE[size].x * TREE_SCALE
	for group_name in ["player", "remote_players"]:
		for p: Node in get_tree().get_nodes_in_group(group_name):
			if not (p is Node2D) or not is_instance_valid(p):
				continue
			var feet: Vector2 = (p as Node2D).global_position + Vector2(0.0, PLAYER_FEET_OFFSET)
			if feet.y < global_position.y and feet.y > global_position.y - h and absf(feet.x - global_position.x) < half_w:
				return true
	return false


func _spark_burst(big: bool) -> void:
	var n: int = 8 if big else 5
	var canopy: Vector2 = global_position + Vector2(0.0, -40.0)
	for i in range(n):
		var a: float = TAU * (float(i) + randf() * 0.6) / float(n)
		var sp: float = randf_range(40.0, 80.0) * (1.4 if big else 1.0)
		var s := Spark.new()
		s.vel = Vector2(cos(a) * sp, sin(a) * sp * 0.7 - 30.0)
		s.life = randf_range(0.5, 0.8)
		get_tree().current_scene.add_child(s)
		s.global_position = canopy + Vector2(cos(a) * 10.0, sin(a) * 12.0)


func _on_open() -> void:
	_ring = _ground_sprite(get_tree().current_scene, TEX_RING, RING_FRAMES)
	_ring.scale = Vector2.ONE * _zone_mult
	if is_cosmetic():
		return
	## Açılış darbesi: alandaki (2:1 ölçüde OPEN_PUSH_RADIUS) yaratıklar ağaçtan dışarı itilir (host'a apply_knockback_distance yolu).
	var push_radius: float = OPEN_PUSH_RADIUS * _zone_mult
	for e in EnemyQueryScript.candidates(get_tree(), global_position, push_radius + 1.0):
		if not _targetable(e):
			continue
		var v: Vector2 = (e as Node2D).global_position - global_position
		if Vector2(v.x, v.y * 2.0).length() > push_radius:
			continue
		if e.has_method("apply_knockback_distance"):
			e.call("apply_knockback_distance", v if v.length() > 0.5 else Vector2.RIGHT, OPEN_PUSH_DISTANCE)


static func _targetable(e: Variant) -> bool:
	return e is Node2D and is_instance_valid(e) and (e as Node).get("is_dead") != true and (e as Node).get("untargetable") != true \
		and not (e as Node).has_meta(&"untargetable") and VisionFogScript.can_target(e)


## Bu kopyada o an alandaki oyuncular (yerel oyuncu + kuklalar); ölü/yerde olanlar hariç.
func _players_in_zone() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for group_name in ["player", "remote_players"]:
		for p: Node in get_tree().get_nodes_in_group(group_name):
			if not (p is Node2D) or not is_instance_valid(p):
				continue
			if p.get("is_dead") == true or p.get("is_downed") == true:
				continue
			if in_zone((p as Node2D).global_position + Vector2(0.0, PLAYER_FEET_OFFSET)):
				out.append(p as Node2D)
	return out


func _heal_tick() -> void:
	var targets: Array[Node2D] = _players_in_zone()
	for i in range(targets.size()):
		var f := Fruit.new()
		f.target = targets[i]
		f.delay = float(i) * 0.12
		if not is_cosmetic():
			f.on_arrive = _heal_target.bind(targets[i])
		get_tree().current_scene.add_child(f)
		f.global_position = global_position + Vector2(randf_range(-18.0, 18.0), -randf_range(48.0, 74.0))


## Elma düştüğü an (sadece gerçek kopya): can + mana kalkanı. Kendisi -> doğrudan; dost -> _apply_heal_to_ally (RPC ile kendi
## istemcisine, asist sayılır).
func _heal_target(target: Node2D) -> void:
	if not is_instance_valid(caster) or not is_instance_valid(target):
		return
	if target.get("is_dead") == true or target.get("is_downed") == true:
		return
	var ap: float = float(caster.get("damage_bonus"))
	var crit: bool = bool(caster.call("_roll_ability_crit")) if caster.has_method("_roll_ability_crit") else false
	var heal: float = (ap * HEAL_AP_RATIO + float(target.get("max_health")) * HEAL_MAX_HP_PERCENT) * _fruit_mult
	var shield: float = ap * SHIELD_AP_RATIO * _fruit_mult
	if caster.has_method("_apply_ability_crit"):
		heal = float(caster.call("_apply_ability_crit", heal, crit))
		shield = float(caster.call("_apply_ability_crit", shield, crit))
	if target == caster:
		caster.call("heal", heal, true, &"s:oakley_agac")
		if float(caster.get("item_shield_max")) > 0.0:
			caster.call("heal_shield", shield, true, true, &"s:oakley_agac")
	elif target.is_in_group("remote_players"):
		if caster.has_method("_apply_heal_to_ally"):
			caster.call("_apply_heal_to_ally", target, heal, &"s:oakley_agac")
		if caster.has_method("_apply_shield_heal_to_ally"):
			caster.call("_apply_shield_heal_to_ally", target, shield, &"s:oakley_agac")


## Kök dalgası (sadece gerçek kopya): menzildeki en yakın ROOT_TARGETS yaratık (yakın zamanda kök yollananlar hariç).
func _root_wave() -> void:
	for id in _recent_roots.keys():
		if float(_recent_roots[id]) <= _t:
			_recent_roots.erase(id)
	var cand: Array = []
	for e in EnemyQueryScript.candidates(get_tree(), global_position, ROOT_RANGE + 1.0):
		if not _targetable(e) or _recent_roots.has((e as Node).get_instance_id()):
			continue
		var d: float = global_position.distance_to((e as Node2D).global_position)
		if d <= ROOT_RANGE:
			cand.append([d, e])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var to: PackedVector2Array = PackedVector2Array()
	for i in range(mini(ROOT_TARGETS, cand.size())):
		var e: Node2D = cand[i][1]
		_recent_roots[e.get_instance_id()] = _t + ROOT_DURATION
		var trail := RootTrail.new()
		trail.from = global_position + Vector2(0.0, 2.0)
		trail.target = e
		trail.to = e.global_position
		trail.seed_phase = float(i) * 1.7
		trail.on_arrive = _on_root_arrive.bind(e)
		_add_trail(trail)
		to.append(e.global_position)
	if to.size() > 0 and NetworkManager.is_multiplayer_active:
		NetworkManager.send_player_vfx(caster.multiplayer.get_unique_id(), "oakley_tree_root", global_position, {"to": to})


func _add_trail(trail: Node2D) -> void:
	get_tree().current_scene.add_child(trail)
	EnemyAbilitiesScript.place_on_ground(get_tree(), trail)


## Diğer istemciler (network_manager.gd "oakley_tree_root"): aynı yer altı izleri, hedefsiz (yayın anındaki konumlara).
static func spawn_root_visuals(parent: Node, from: Vector2, to: PackedVector2Array) -> void:
	for i in range(to.size()):
		var trail := RootTrail.new()
		trail.from = from + Vector2(0.0, 2.0)
		trail.to = to[i]
		trail.seed_phase = float(i) * 1.7
		parent.add_child(trail)
		EnemyAbilitiesScript.place_on_ground(parent.get_tree(), trail)


func _on_root_arrive(e: Node2D) -> void:
	if not _targetable(e):
		return
	if is_instance_valid(caster) and e.has_method("take_damage"):
		BalanceLogScript.tag(&"s:oakley_agac")
		e.call("take_damage", float(caster.get("damage_bonus")) * ROOT_DAMAGE_RATIO)
	if not is_instance_valid(e) or e.get("is_dead") == true:
		return
	if bool(e.get("is_boss")):
		if e.has_method("apply_slow"):
			BalanceLogScript.on_cc("s:oakley_agac", "slow", e, ROOT_DURATION)
			e.call("apply_slow", BOSS_SLOW_PERCENT, ROOT_DURATION, true)
	elif e.has_method("apply_root"):
		BalanceLogScript.on_cc("s:oakley_agac", "root", e, ROOT_DURATION)
		e.call("apply_root", ROOT_DURATION, ROOT_STYLE)


## Kadim Diriliş (madde 348, sadece gerçek kopya): gölge alanında yerde yatan (is_downed) ilk dost kaldırılır, ağaç başına bir kez.
## Oakley'nin kendisi kaldırılmaz (kendini diriltme yok). Yayın player.gd oakley_tree_revive_ally.
func _try_revive() -> void:
	if not is_instance_valid(caster) or not caster.has_method("oakley_tree_revive_ally"):
		return
	for p: Node in get_tree().get_nodes_in_group("remote_players"):
		if not (p is Node2D) or not is_instance_valid(p) or p.get("is_downed") != true:
			continue
		if not in_zone((p as Node2D).global_position + Vector2(0.0, PLAYER_FEET_OFFSET)):
			continue
		if bool(caster.call("oakley_tree_revive_ally", p)):
			_revive_used = true
			return


func _drop_flowers() -> void:
	if is_cosmetic() or not is_instance_valid(caster) or not caster.has_method("_spawn_oakley_flower_at"):
		return
	var offsets: Array[Vector2] = FLOWER_OFFSETS.duplicate()
	if _flower_count > offsets.size():
		offsets.append_array(FLOWER_OFFSETS_EXTRA)
	for off in offsets.slice(0, maxi(0, _flower_count)):
		var p: Vector2 = global_position + off
		if GameManager.is_position_blocked_by_walls(p):
			p = global_position + off * 0.4
			if GameManager.is_position_blocked_by_walls(p):
				continue
		caster.call("_spawn_oakley_flower_at", p, global_position + Vector2(0.0, -30.0))


## ---------------------------------------------------------------- parçacıklar
## Büyüme pırıltısı: 4 uçlu yıldız, büyüyüp küçülür (3 -> 2 -> 1), yerçekimiyle savrulur.
class Spark extends Sprite2D:
	var vel: Vector2 = Vector2.ZERO
	var life: float = 0.6
	var _age: float = 0.0

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		z_index = 3
		texture = OakleyTree.TEX_SPARK[2]

	func _process(delta: float) -> void:
		_age += delta
		if _age >= life:
			queue_free()
			return
		vel.y += 150.0 * delta
		global_position += vel * delta
		var q: float = _age / life
		texture = OakleyTree.TEX_SPARK[2 if q < 0.3 else (1 if q < 0.65 else 0)]
		modulate.a = 1.0 if q < 0.5 else OakleyTree.band(1.0 - (q - 0.5) / 0.5, 3)


## Can tiki: ağacın tacından dosta kavisle uçan elma; düşünce altın artı + iki pırıltı. on_arrive sadece gerçek kopyada dolu.
class Fruit extends Sprite2D:
	var target: Node2D = null
	var delay: float = 0.0
	var on_arrive: Callable = Callable()
	var _start: Vector2 = Vector2.ZERO
	var _age: float = 0.0
	var _end: Vector2 = Vector2.ZERO
	var _started: bool = false

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture = OakleyTree.TEX_FRUIT
		z_index = 3
		visible = false

	func _process(delta: float) -> void:
		if delay > 0.0:
			delay -= delta
			if delay > 0.0:
				return
		if not _started: ## konum add_child'dan SONRA atanıyor - başlangıç ilk karede alınır
			_started = true
			_start = global_position
			_end = (target.global_position + Vector2(0.0, -6.0)) if is_instance_valid(target) else _start
			visible = true
		_age += delta
		if is_instance_valid(target):
			_end = target.global_position + Vector2(0.0, -6.0)
		var q: float = minf(1.0, _age / OakleyTree.FRUIT_FLIGHT)
		global_position = _start.lerp(_end, q) + Vector2(0.0, -26.0 * 4.0 * q * (1.0 - q))
		if q >= 1.0:
			if on_arrive.is_valid():
				on_arrive.call()
			var plus := Rising.new()
			plus.texture = OakleyTree.TEX_PLUS
			get_tree().current_scene.add_child(plus)
			plus.global_position = _end + Vector2(9.0, -22.0)
			for off in [Vector2(-8.0, -12.0), Vector2(7.0, -20.0)]:
				var sp := Spark.new()
				sp.life = 0.45
				get_tree().current_scene.add_child(sp)
				sp.global_position = _end + off
			queue_free()


## Yükselip bantlı solan küçük işaret (can artısı).
class Rising extends Sprite2D:
	var _age: float = 0.0

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		z_index = 3

	func _process(delta: float) -> void:
		_age += delta
		var q: float = _age / 0.7
		if q >= 1.0:
			queue_free()
			return
		position.y -= 17.0 * delta * (1.0 - q) * 2.0
		modulate.a = 1.0 if q < 0.5 else OakleyTree.band(1.0 - (q - 0.5) / 0.5, 3)


## Toprak altında giden kök: başta kabaran tümsek + arkasında solan 1 px çatlak izi (yer katmanı). Hedef varsa (gerçek kopya)
## ona güdümlenir, varınca on_arrive; yoksa (kozmetik) yayındaki noktaya gider. Yol E sarmaşığı gibi hafifçe yana salınır.
class RootTrail extends Node2D:
	const TRAIL_LIFE := 0.9
	const WIGGLE_AMP := 6.0
	const WIGGLE_FREQ := 0.07
	var from: Vector2 = Vector2.ZERO
	var to: Vector2 = Vector2.ZERO
	var target: Node2D = null
	var seed_phase: float = 0.0
	var on_arrive: Callable = Callable()
	var _head: Vector2 = Vector2.ZERO
	var _trav: float = 0.0
	var _pts: PackedVector2Array = PackedVector2Array()
	var _times: PackedFloat32Array = PackedFloat32Array()
	var _age: float = 0.0
	var _arrived_at: float = -1.0
	var _mound: Sprite2D = null

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		global_position = Vector2.ZERO
		_head = from
		_pts.append(from)
		_times.append(0.0)
		_mound = OakleyTree._make_sprite(OakleyTree.TEX_MOUND, 2)
		add_child(_mound)
		_mound.global_position = from

	func _process(delta: float) -> void:
		_age += delta
		if _arrived_at < 0.0:
			var goal: Vector2 = (target.global_position + Vector2(0.0, 5.0)) if is_instance_valid(target) else to + Vector2(0.0, 5.0)
			var v: Vector2 = goal - _head
			var d: float = v.length()
			var stp: float = OakleyTree.ROOT_SPEED * delta
			var pt: Vector2
			if d <= stp or _age > 2.0:
				_head = goal
				pt = goal
				_arrived_at = _age
				_mound.visible = false
				if on_arrive.is_valid():
					on_arrive.call()
			else:
				_head += v / d * stp
				_trav += stp
				var side: Vector2 = Vector2(-v.y, v.x) / d
				var amp: float = WIGGLE_AMP * minf(1.0, minf((d - stp) / 30.0, _trav / 20.0))
				pt = _head + side * amp * sin(WIGGLE_FREQ * _trav + seed_phase)
				_mound.global_position = pt.round()
				_mound.frame = int(_age * 8.0) % 2
			_pts.append(pt)
			_times.append(_age)
		elif _age - _arrived_at > TRAIL_LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var col: Color = Color8(70, 48, 30)
		for i in range(1, _pts.size()):
			var age: float = _age - _times[i]
			if age >= TRAIL_LIFE:
				continue
			col.a = OakleyTree.band(0.85 * (1.0 - age / TRAIL_LIFE), 3)
			if col.a <= 0.0:
				continue
			var a: Vector2 = _pts[i - 1]
			var b: Vector2 = _pts[i]
			var n: int = maxi(1, int(a.distance_to(b)))
			for j in range(n):
				var p: Vector2 = a.lerp(b, float(j) / float(n)).floor()
				draw_rect(Rect2(p, Vector2.ONE), col)
