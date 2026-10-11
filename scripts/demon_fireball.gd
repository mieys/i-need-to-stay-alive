extends Node2D

## UÇAN ŞEYTAN ATEŞ TOPU (FİNAL boss, kullanıcı isteği 2026-10-09: "oyunculara doğru çok seri ateş topları gönderir; çarpınca patlayarak 200 hasar verir, sonrasında yakarak her saniye 50 hasar"): dünya efekti.
## Düz çizgide uçar; ilk değdiği oyuncuda / duvarda / Şovalye kalkanında / satıcı bölgesinde PATLAR: yarıçaptaki HER oyuncuya `damage` (take_special_damage "demonfire": player.gd isabette
## 50/sn yanma başlatır). Yetkili örnek hasar verir, istemcideki görsel kopya sadece uçar + patlar. Sanat: paketin "fire shot (red)" şeridi (kare 0 uçuş, 1-3 patlama). data: dir, speed, life, radius, blast.

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const FxUtil := preload("res://scripts/boss_fx_util.gd")
const SHEET := "res://assets/fx/demon/fire_shot.png"
const WALL_IGNORE_TIME := 0.06

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _dir: Vector2 = Vector2.RIGHT
var _speed: float = 300.0
var _max_life: float = 3.0
var _radius: float = 9.0
var _blast: float = 44.0
var _life: float = 0.0
var _done: bool = false


func _ready() -> void:
	z_index = 11
	_dir = Vector2(data.get("dir", Vector2.RIGHT))
	if _dir.length() < 0.01:
		_dir = Vector2.RIGHT
	_dir = _dir.normalized()
	_speed = float(data.get("speed", 300.0))
	_max_life = float(data.get("life", 3.0))
	_radius = float(data.get("radius", 9.0))
	_blast = float(data.get("blast", 44.0))
	rotation = _dir.angle() ## sayfadaki top SAĞA bakar (kuyruk solda)
	var sp := Sprite2D.new()
	sp.texture = load(SHEET) as Texture2D
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.hframes = 4
	sp.frame = 0
	sp.scale = Vector2.ONE * 1.3
	sp.offset = Vector2(-8.0, 0.0)
	add_child(sp)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_life += delta
	if _life >= _max_life:
		queue_free()
		return
	global_position += _dir * _speed * delta
	if _life >= WALL_IGNORE_TIME and GameManager.is_position_blocked_by_forest(global_position):
		_explode()
		return
	if GameManager.merchant_zone_active and global_position.distance_to(GameManager.merchant_zone_pos) <= GameManager.MERCHANT_ZONE_RADIUS:
		_explode()
		return
	for p in AbilitiesScript.damageable_players(get_tree()):
		var pn := p as Node2D
		if "paladin_zone_active" in pn and pn.get("paladin_zone_active") == true \
				and global_position.distance_to(pn.global_position) <= float(pn.get("paladin_zone_radius")):
			_explode(false)
			return
		if pn.has_method("get_talon_ward_radius"):
			var ward_r: float = float(pn.call("get_talon_ward_radius"))
			if ward_r > 0.0 and global_position.distance_to(pn.global_position) <= ward_r:
				_explode(false)
				return
		if global_position.distance_to(pn.global_position) <= _radius + AbilitiesScript.TARGET_BODY_RADIUS:
			_explode()
			return


## damaging=false: kalkana çarptı (alan hasarı yok).
func _explode(damaging: bool = true) -> void:
	_done = true
	if authoritative and damaging:
		for p in AbilitiesScript.damageable_players(get_tree()):
			if global_position.distance_to((p as Node2D).global_position) <= _blast + AbilitiesScript.TARGET_BODY_RADIUS:
				AbilitiesScript.deal_special_damage(p, damage, source, "demonfire")
	FxUtil.play_once(get_tree().current_scene, global_position, FxUtil.frames_from_strip(SHEET, 32, 24, &"burst", 14.0, false, 1, 3), &"burst", 2.2)
	queue_free()
