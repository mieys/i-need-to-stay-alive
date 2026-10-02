extends Node2D

## Talon "Kalkan Çemberi" evrimi (E finali, 2026-09-28): Silah Salvosu sürerken silahların çizdiği çemberde (yerel 130
## birim - TalonFormationMath.SALVO_RADIUS; sayfa aynı yarıçapta çizildi) dönen turuncu koruyucu halka. Asıl engelleme
## enemy_projectile.gd / enemy_fireball.gd'de (get_talon_ward_radius). Karakterin çocuğu: kaster player.gd
## _play_and_broadcast_skill_fx ile, diğer oyuncular AYNI sahneyi "skill_scene" ile kurar; salvo bitince
## _stop_and_broadcast_skill_fx -> stop() (solarak kaybolur). Kapanış paketi kaybolursa güvenlik süresi.
## BUG DÜZELTMESİ (2026-09-30, Assasin evrimleri sırasında headless derlemede bulundu): kök eskiden AnimatedSprite2D'ydi -
## buradaki stop() onun yerel stop()'unu eziyor, projede bu uyarı HATA sayıldığı için script HİÇ yüklenmiyordu: halka
## scriptsiz, dönmeden/solmadan duruyor, salvo bitince çağrılan stop() da sadece yerel animasyonu durdurup düğümü silmiyordu
## (halka Talon'un etrafında kalıyordu). Artık kök Node2D, sayfa çocuk "Sprite"ta (bkz. fx_evo_loop.gd aynı not).

const SPIN_SPEED := 0.9 ## rad/sn - silahlarla aynı yöne yavaşça döner (sayfanın kendi parıltı döngüsüne ek)
const FADE_IN := 0.2
const FADE_OUT := 0.25
const SAFETY_LIFETIME := 7.0 ## en uzun salvo (Uzun Girdap) 5 sn

var _t: float = 0.0
var _stopping: bool = false
var _stop_t: float = 0.0


func _ready() -> void:
	modulate.a = 0.0
	var spr: AnimatedSprite2D = get_node_or_null("Sprite") as AnimatedSprite2D
	if spr != null:
		spr.play(&"loop")


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
