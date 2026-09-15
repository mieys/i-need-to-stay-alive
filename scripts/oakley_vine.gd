extends Node2D

## Oakley'in Sarmaşıklar yeteneği (E, kullanıcı isteği: "Oakley yeni
## yetenekleri" 2. Yetenek - SADECE Oakley, Melek'e dokunulmadı) - en yakın
## bir yaratığa doğru ilerleyen tek bir sarmaşık. player.gd _skill_oakley_
## vines() üç tanesini AYRI hedeflerle
## oluşturur.
##
## NOT (kapsam sınırı): Bu efekt SADECE döken oyuncunun kendi istemcisinde
## var - weapon.gd'nin mermileri gibi ayrıca "kozmetik kopya" yayınlanmıyor,
## bu yüzden multiplayer'da DİĞER oyuncular sarmaşıkları GÖRMEZ (host-yetkili
## hasar/sabitleme - enemy.gd take_damage/apply_root - yine de doğru şekilde
## TÜM istemcilere yansır, sadece görsel eksik). Gerçek bir kozmetik yayın
## eklemek istenirse network_manager.gd broadcast_player_vfx'e chain_
## lightning ile AYNI desende yeni bir vfx_type eklenebilir.

const SPEED := 340.0
const LIFETIME := 6.0
const HIT_RADIUS := 22.0
const ROOT_DURATION := 4.0
const BOSS_SLOW_PERCENT := 0.30
const DAMAGE_RATIO := 0.60 ## saldırı gücünün %60'ı

var _target: Node2D = null
var _damage_bonus: float = 0.0
var _lifetime_remaining: float = LIFETIME
var _hit: bool = false
var _visual: Line2D = null


func setup(target: Node2D, caster_damage_bonus: float) -> void:
	_target = target
	_damage_bonus = caster_damage_bonus


func _ready() -> void:
	z_index = 4
	_visual = Line2D.new()
	_visual.width = 5.0
	_visual.default_color = Color(0.25, 0.65, 0.2, 0.9)
	add_child(_visual)


func _process(delta: float) -> void:
	if _hit:
		return
	if not is_instance_valid(_target) or bool(_target.get("is_dead")):
		queue_free()
		return
	_lifetime_remaining -= delta
	if _lifetime_remaining <= 0.0:
		queue_free()
		return
	var to_target: Vector2 = _target.global_position - global_position
	var dist: float = to_target.length()
	_visual.points = PackedVector2Array([Vector2.ZERO, to_target])
	if dist <= HIT_RADIUS:
		_on_hit()
		return
	global_position += (to_target / dist) * SPEED * delta


func _on_hit() -> void:
	_hit = true
	if is_instance_valid(_target) and not bool(_target.get("is_dead")):
		if _target.has_method("take_damage"):
			_target.call("take_damage", _damage_bonus * DAMAGE_RATIO)
		var is_boss: bool = bool(_target.get("is_boss"))
		if is_boss:
			if _target.has_method("apply_slow"):
				## DÜZELTME: apply_slow(percent, duration, allow_boss=false) -
				## 3. argüman verilmezse varsayılan false'a düşüp enemy.gd'nin
				## "if is_dead or (is_boss and not allow_boss): return" kontrolü
				## bossu SESSİZCE yavaşlatmıyordu, "bossları sabitleyemez ama
				## %30 yavaşlatır" isteği hiç çalışmıyordu.
				_target.call("apply_slow", BOSS_SLOW_PERCENT, ROOT_DURATION, true)
		else:
			if _target.has_method("apply_root"):
				_target.call("apply_root", ROOT_DURATION)
	queue_free()
