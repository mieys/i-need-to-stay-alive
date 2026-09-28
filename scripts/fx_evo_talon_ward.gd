extends AnimatedSprite2D

## Talon "Kalkan Çemberi" evrimi (E finali, 2026-09-28): Silah Salvosu sürerken silahların çizdiği çemberde (yerel 130
## birim - TalonFormationMath.SALVO_RADIUS; sayfa aynı yarıçapta çizildi) dönen turuncu koruyucu halka. Asıl engelleme
## enemy_projectile.gd / enemy_fireball.gd'de (get_talon_ward_radius). Karakterin çocuğu: kaster player.gd
## _play_and_broadcast_skill_fx ile, diğer oyuncular AYNI sahneyi "skill_scene" ile kurar; salvo bitince
## _stop_and_broadcast_skill_fx -> stop() (solarak kaybolur). Kapanış paketi kaybolursa güvenlik süresi.

const SPIN_SPEED := 0.9 ## rad/sn - silahlarla aynı yöne yavaşça döner (sayfanın kendi parıltı döngüsüne ek)
const FADE_IN := 0.2
const FADE_OUT := 0.25
const SAFETY_LIFETIME := 7.0 ## en uzun salvo (Uzun Girdap) 5 sn

var _t: float = 0.0
var _stopping: bool = false
var _stop_t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modulate.a = 0.0
	play(&"loop")


func stop() -> void:
	_stopping = true


func _process(delta: float) -> void:
	_t += delta
	rotation += SPIN_SPEED * delta
	if _stopping:
		_stop_t += delta
		modulate.a = clampf(1.0 - _stop_t / FADE_OUT, 0.0, 1.0)
		if _stop_t >= FADE_OUT:
			queue_free()
		return
	modulate.a = clampf(_t / FADE_IN, 0.0, 1.0)
	if _t >= SAFETY_LIFETIME:
		_stopping = true
