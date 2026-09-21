extends Node2D

## Korsan'ın TEMEL yeteneği (Saatli Bomba, skill2 id 17, bkz. player.gd
## _korsan_try_place_bomb/characters.gd DEFS[9]) ile bırakılan saatli bomba.
## Kendisi hiçbir çarpışma/Area2D içermez - patlama hasarı doğrudan bir
## mesafe taramasıyla (bkz. detonate(), Talon'un
## Yer Sarsıntısı'yla AYNI desen) uygulanır.
##
## Multiplayer notu: bu sahne HEM gerçek bombayı (bırakan istemcide,
## player.gd'nin _korsan_bombs dizisinde takip edilir, ULTİ ile detonate()
## çağrılır) HEM DE diğer istemcilerdeki SADECE KOZMETİK kopyayı (bkz.
## player.gd _korsan_try_place_bomb'daki broadcast_player_vfx "muzzle_flash"
## çağrısı - world-space bir konuma sahne spawn eden JENERİK mekanizma)
## temsil eder. Kozmetik kopyaya asla detonate() çağrılmadığı için (sadece
## bırakan istemcinin kendi _korsan_bombs dizisindeki GERÇEK referansı
## çağrılır) hiçbir zaman hasar vermez - sadece burada aşağıdaki
## kalıcıdır; yalnızca gerçek bomba detonate() ile kaldırılır.

## Bombalar bırakıldıkları sürece kalıcıdır; yalnızca Korsan'ın ultisiyle
## detonate() çağrıldığında kaldırılırlar.
## fx_matthew_explosion.tscn kendi patlama sesini (shield_break.wav) zaten
## içeriyor - ayrı bir ses dosyasına gerek yok.
const EXPLOSION_FX_SCENE := preload("res://scenes/fx_korsan_explosion.tscn")

## #39 DÜZELTME (kullanıcı bildirimi: "Korsan bomba/ulti düzenlemeleri"):
## patlama yarıçapı 130 -> 150 büyütüldü (damage varsayılanı zaten
## player.gd _korsan_try_place_bomb() tarafından KORSAN_BOMB_DAMAGE_FLAT/
## _POWER_RATIO ile üzerine yazılıyor, buradaki 20.0 sadece bir varsayılan).
var damage: float = 20.0
var radius: float = 150.0
var _is_detonated: bool = false
var _life: float = 0.0

## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir" - bombayı
## bırakan oyuncuya referans (bkz. player.gd _korsan_try_place_bomb), patlama
## anında player.gd'nin paylaşılan kritik yardımcılarını kullanmak için.
var owner_player: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)


func _process(delta: float) -> void:
	if _is_detonated:
		return
	_life += delta
	## Fitil parlaması: bomba artık yaşam süresiyle silinmez.
	## Yanıp sönme yalnızca görsel amaçlıdır ve süresiz devam eder.
	var blink_speed: float = 3.0
	var glow: float = 0.5 + 0.5 * sin(_life * blink_speed)
	if sprite:
		sprite.modulate = Color(1.0, lerp(0.4, 1.0, glow), lerp(0.3, 1.0, glow))


## Sadece GERÇEK bombayı bırakan istemci çağırır (bkz. player.gd
## _skill_korsan_detonate_all) - kozmetik kopyalarda hiç referans tutulmadığı
## için buraya asla ulaşılmaz.
func detonate() -> void:
	if _is_detonated:
		return
	_is_detonated = true
	## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir" - tek bir
	## patlama, tek bir kritik zarı (aynı anda vurduğu herkese aynı sonuç).
	var is_crit: bool = false
	var dmg: float = damage
	if owner_player and is_instance_valid(owner_player) and owner_player.has_method("_roll_ability_crit"):
		is_crit = owner_player._roll_ability_crit()
		dmg = owner_player._apply_ability_crit(dmg, is_crit)
	var _total_dealt: float = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if global_position.distance_to(e.global_position) <= radius and e.has_method("take_damage"):
			e.take_damage(dmg, is_crit)
			_total_dealt += dmg
	_spawn_explosion_fx()
	queue_free()


func _spawn_explosion_fx() -> void:
	var fx := EXPLOSION_FX_SCENE.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
