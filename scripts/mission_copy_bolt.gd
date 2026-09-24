extends Node2D

## "Kopyanı Öldür" görevindeki kopyaların menzilli saldırısı için basit, kendi kendine yeten bir
## mermi (bkz. mission_player_copy.gd _fire_at notu). weapon.gd/projectile.gd'nin paylaşılan
## mermisi KASITLI OLARAK kullanılmadı: projectile.gd'nin _on_body_entered'ı SADECE "enemies"
## grubundaki gövdelere hasar verir (bkz. o dosyadaki satır) - kopyanın hedefi ise bir OYUNCU,
## yani o mermiyi olduğu gibi kullansak mermi oyuncunun İÇİNDEN GEÇER, hiç hasar vermez. Bunun
## yerine gerçek fizik çarpışması ARAMAYAN, hedefin ateş anındaki konumuna düz bir çizgide uçan
## ve varışta o noktaya yakın oyuncu(lar)a hasar veren kendi basit mermisi.

const SPEED := 340.0
const HIT_RADIUS := 28.0
const COLOR := Color(0.75, 0.25, 0.85, 1.0) ## ters renk temasıyla uyumlu mor-magenta

var _target_pos: Vector2 = Vector2.ZERO
var _damage: float = 1.0
var _source: Node2D = null
var _traveled: float = 0.0
var _total_dist: float = 0.0
var _dir: Vector2 = Vector2.RIGHT
var _cosmetic: bool = false ## host olmayan istemcideki salt görsel kopya - hasar VERMEZ


func setup(from_pos: Vector2, to_pos: Vector2, damage: float, source: Node2D, cosmetic: bool = false) -> void:
	global_position = from_pos
	_target_pos = to_pos
	_damage = damage
	_source = source
	_cosmetic = cosmetic
	_total_dist = from_pos.distance_to(to_pos)
	_dir = (to_pos - from_pos).normalized() if _total_dist > 0.001 else Vector2.RIGHT
	z_index = 8


func _ready() -> void:
	var rect := ColorRect.new()
	rect.color = COLOR
	rect.size = Vector2(8, 8)
	rect.position = Vector2(-4, -4)
	add_child(rect)
	get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(self): queue_free())


func _physics_process(delta: float) -> void:
	var step: float = SPEED * delta
	_traveled += step
	position += _dir * step
	if _traveled >= _total_dist:
		_explode()


func _explode() -> void:
	if _cosmetic:
		queue_free()
		return
	for group_name in ["player", "remote_players"]:
		for p: Node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(p) or p.get("is_dead") == true:
				continue
			if (p as Node2D).global_position.distance_to(_target_pos) <= HIT_RADIUS and p.has_method("take_damage"):
				p.take_damage(_damage, _source)
	queue_free()
