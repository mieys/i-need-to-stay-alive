extends Node2D

## "Kopyanı Öldür" görevindeki kopyaların menzilli saldırısı için basit, kendi kendine yeten bir
## mermi (bkz. mission_player_copy.gd _fire_at notu). weapon.gd/projectile.gd'nin paylaşılan
## mermisi KASITLI OLARAK kullanılmadı: projectile.gd'nin _on_body_entered'ı SADECE "enemies"
## grubundaki gövdelere hasar verir (bkz. o dosyadaki satır) - kopyanın hedefi ise bir OYUNCU,
## yani o mermiyi olduğu gibi kullansak mermi oyuncunun İÇİNDEN GEÇER, hiç hasar vermez.
##
## DÜZELTME (kullanıcı bildirimi 2026-09-24: "kopyanın silahları var ama saldıramıyor"): mermi eskiden hedefin ateş
## anındaki NOKTASINA uçup sadece varışta oraya 28 px yakın oyuncuya vuruyordu - yürüyen oyuncu o arada uzaklaştığı
## için neredeyse hiç isabet etmiyordu. Artık from -> to yönünde düz uçar ve YOLU BOYUNCA gövdesine değdiği ilk
## (canlı, yerde olmayan) oyuncuya vurup yok olur; orman duvarına çarpınca da söner (yaratık mermileri gibi).
## Kozmetik kopya (host olmayan istemcide) aynı kurala göre söner ama hasar VERMEZ.
##
## GÖRÜNÜM (kullanıcı bildirimi 2026-10-05: "kopya benim silahlarıma sahip ama onlarla ateş etmiyor, başka ateşler ediyor"):
## eskiden her silah için AYNI mor ColorRect mermi atılıyordu. Artık `visual` verilirse (bkz. mission_player_copy.gd attack_info)
## silahın KENDİ mermi sahnesi (ok, kurşun, ateş topu, buz oku...) görsel olarak kopyalanır: betik/çarpışma/ses sökülür, sadece
## sprite + animasyon kalır; hasar mantığı AYNI (yolu boyunca değen ilk oyuncuya vurur), hız silahın merminin hızıdır.
## `visual` boşsa (bilinmeyen silah) eski mor mermi.

const SPEED := 340.0
const HIT_RADIUS := 20.0 ## mermi + oyuncu gövdesi toleransı
const COLOR := Color(0.75, 0.25, 0.85, 1.0) ## kopyanın mor tonuyla uyumlu
const CORE_COLOR := Color(0.95, 0.8, 1.0, 1.0)

var _damage: float = 1.0
var _source: Node2D = null
var _traveled: float = 0.0
var _total_dist: float = 0.0
var _dir: Vector2 = Vector2.RIGHT
var _cosmetic: bool = false ## host olmayan istemcideki salt görsel kopya - hasar VERMEZ
var _speed: float = SPEED
var _visual: Dictionary = {} ## {"proj": PackedScene, "speed", "scale", "rot"} - boşsa mor mermi

## Silahın mermi sahnesinin kopyası, oyuncunun karakter ölçeğiyle çarpılır (weapon.gd _fire_at: proj.scale *= karakter ölçeği).
const VISUAL_CHAR_SCALE := 0.5


func setup(from_pos: Vector2, to_pos: Vector2, damage: float, source: Node2D, cosmetic: bool = false, visual: Dictionary = {}) -> void:
	position = from_pos ## ağaca eklenmeden ÖNCE çağrılır (mission_player_copy.gd spawn_bolt) - ekledikten sonra global_position verir
	_damage = damage
	_source = source
	_cosmetic = cosmetic
	_visual = visual
	_speed = maxf(float(visual.get("speed", SPEED)), 1.0) if not visual.is_empty() else SPEED
	_total_dist = from_pos.distance_to(to_pos)
	_dir = (to_pos - from_pos).normalized() if _total_dist > 0.001 else Vector2.RIGHT
	rotation = _dir.angle()
	z_index = 8


func _ready() -> void:
	var clone: Node2D = null
	if _visual.get("proj") is PackedScene:
		clone = make_visual(_visual["proj"], float(_visual.get("scale", 1.0)), float(_visual.get("rot", 0.0)))
	if clone != null:
		add_child(clone)
	else:
		var rect := ColorRect.new()
		rect.color = COLOR
		rect.size = Vector2(10, 6)
		rect.position = Vector2(-5, -3)
		add_child(rect)
		var core := ColorRect.new()
		core.color = CORE_COLOR
		core.size = Vector2(4, 2)
		core.position = Vector2(0, -1)
		add_child(core)
	get_tree().create_timer(3.0).timeout.connect(func(): if is_instance_valid(self): queue_free())


## Silahın mermi sahnesinden SALT GÖRSEL kopya: betik (hasar/çarpışma mantığı), çarpışma şekilleri ve sesler sökülür; sprite ve
## animasyonlar kalır. Sahne ağaca eklenmeden örneklenir (betiğin _ready'si hiç çalışmaz). Düğümü çağıran ekler.
static func make_visual(scene: PackedScene, scale_mult: float, rot_offset: float) -> Node2D:
	var v: Node = scene.instantiate()
	if not (v is Node2D):
		v.free()
		return null
	v.set_script(null)
	for c: Node in v.get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D or c is AudioStreamPlayer or c is AudioStreamPlayer2D:
			v.remove_child(c)
			c.free()
		elif c is AnimatedSprite2D and (c as AnimatedSprite2D).sprite_frames != null:
			(c as AnimatedSprite2D).play()
	if v is Area2D:
		(v as Area2D).monitoring = false
		(v as Area2D).monitorable = false
	var n2d: Node2D = v as Node2D
	n2d.scale *= scale_mult * VISUAL_CHAR_SCALE
	n2d.rotation = rot_offset
	return n2d


func _physics_process(delta: float) -> void:
	var step: float = _speed * delta
	_traveled += step
	position += _dir * step
	var victim: Node = _touching_player()
	if victim:
		if not _cosmetic and victim.has_method("take_damage"):
			victim.take_damage(_damage, _source if is_instance_valid(_source) else null)
		queue_free()
		return
	if _traveled >= _total_dist or GameManager.is_position_blocked_by_forest(global_position):
		queue_free()


func _touching_player() -> Node:
	for group_name in ["player", "remote_players"]:
		for p: Node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(p) or p.get("is_dead") == true or p.get("is_downed") == true:
				continue
			if (p as Node2D).global_position.distance_to(global_position) <= HIT_RADIUS:
				return p
	return null
