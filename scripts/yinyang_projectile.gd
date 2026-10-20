extends "res://scripts/projectile.gd"

## YİN YANG KİTABI kara küresi (yin, madde 334) - kasterde gerçek mermi, uzak ekranlarda broadcast_projectile kopyası (aynı script).
## Kitaptan ak küreyle birlikte sarmal çizerek YinYangBook.RISE sn yükselir (bu sırada çarpmaz), tepede ayrılır: kara hedefe güdümlenir,
## ak küre (yinyang_light.gd, ayrı düğüm - kara küre isabette silinse de yoluna devam eder) kalkanı alana uçar.
## Kalkan / Yin hasarı / Denge kancası kasterde GERÇEK isabette: YinYangBook.resolve_hit.
## Ağ: alıcı "props" -> yy_rcp_peer (Denge look_extra), hedef "home_id" (projectile_extra home_net_id), sahibin kuklası player_node
## (broadcast_projectile bumerangdaki gibi doldurur). Sahnedeki "Light" sprite'ı yalnız görev kopyasının salt görsel mermisi içindir
## (mission_copy_bolt.make_visual betiği söker); burada silinir.

const YinYang := preload("res://scripts/yinyang_book.gd")
const LightScript := preload("res://scripts/yinyang_light.gd")

var yy_rcp_peer: int = -1 ## -1 karar yok, 0 Yin (kimse kalkan alamıyor -> ak küre de düşmana), > 0 alıcının ağ kimliği
var player_node: Node2D = null ## kitabın sahibi

var _yy_target: Node2D = null
var _yy_rcp: Node2D = null
var _yy_t: float = 0.0
var _yy_inited: bool = false
var _yy_start: Vector2 = Vector2.ZERO
var _yy_drift: Vector2 = Vector2.RIGHT
var _dark: Sprite2D = null


func _ready() -> void:
	super._ready()
	_dark = get_node_or_null("Dark") as Sprite2D
	if _dark:
		_dark.position = Vector2.ZERO
	var l: Node = get_node_or_null("Light")
	if l:
		remove_child(l)
		l.queue_free()
	monitoring = false ## yükselirken çarpmaz


## Kaster (Denge özelliği projectile_extra): hedef + atış anındaki kalkan alıcısı (null = Yin).
func yy_setup(target: Node2D, rcp: Node2D) -> void:
	_yy_target = target
	_yy_rcp = rcp
	yy_rcp_peer = YinYang.peer_of(rcp) if rcp != null else 0


func _yy_init() -> void:
	_yy_inited = true
	_yy_start = global_position
	_yy_drift = direction if direction.length() > 0.01 else Vector2.RIGHT
	if get_meta("network_spawned", false):
		if int(get_meta("home_id", 0)) > 0:
			_yy_target = NetworkManager.find_enemy_by_net_id(int(get_meta("home_id"))) as Node2D
		_yy_rcp = YinYang.node_for_peer(get_tree(), yy_rcp_peer) if yy_rcp_peer > 0 else null
	else:
		if player_node == null and is_instance_valid(source_weapon):
			player_node = source_weapon.get_parent() as Node2D
		if yy_rcp_peer == -1: ## özellik kurmadıysa (yedek yol) kasterde burada karar verilir
			_yy_rcp = YinYang.pick_recipient(player_node)
			yy_rcp_peer = YinYang.peer_of(_yy_rcp) if _yy_rcp != null else 0
	if _dark:
		_dark.scale = Vector2.ONE * YinYang.WORLD_PX * (1.25 if is_crit else 1.0) / maxf(0.01, absf(global_scale.x))
		_dark.z_index = YinYang.Z_FRONT
		_dark.z_as_relative = false
	YinYang.make_trail(self, YinYang.TRAIL_DARK)
	var light: Node2D = LightScript.new()
	light.set("start", _yy_start)
	light.set("drift", _yy_drift)
	light.set("rcp", _yy_rcp if yy_rcp_peer != 0 else null)
	light.set("enemy", _yy_target if yy_rcp_peer == 0 else null)
	light.set("owner_node", player_node)
	light.set("crit", is_crit)
	get_tree().current_scene.add_child(light)


func _physics_process(delta: float) -> void:
	if _impacted:
		return
	if not _yy_inited:
		_yy_init()
	_yy_t += delta
	if _yy_t < YinYang.RISE:
		var o: Array = YinYang.rise_offsets(_yy_t, _yy_drift)
		global_position = _yy_start + (o[0] as Vector2)
		if _dark:
			_dark.z_index = YinYang.Z_FRONT + (1 if float(o[2]) > 0.0 else 0)
		return
	if not monitoring:
		monitoring = true
		if _dark:
			_dark.z_index = YinYang.Z_FRONT
	if is_instance_valid(_yy_target) and _yy_target.get("is_dead") != true:
		direction = (_yy_target.global_position - global_position).normalized()
	if not ProjectileRangeScript.within(self):
		queue_free()
		return
	position += direction * speed * delta
	_ew_poll_hits()


func _on_body_entered(body: Node) -> void:
	if not _yy_inited or _yy_t < YinYang.RISE:
		return
	var before: int = _hit_bodies.size()
	super._on_body_entered(body)
	if get_meta("network_spawned", false) or before != 0 or _hit_bodies.size() != 1:
		return
	if is_instance_valid(source_weapon):
		YinYang.resolve_hit(source_weapon, body, _yy_rcp, yy_rcp_peer == 0)
