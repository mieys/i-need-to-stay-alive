extends TotemBase
class_name TotemAttack

## Saldırı Totemi (Shaman TEMEL/E, skill2 id 27): "Etrafındaki yaratıklara
## düzenli olarak ateş eder. Her saldırı shaman'ın saldırı gücünün %150'si
## kadar hasar verir, saldırı hızı da shaman'ın kendi saldırı hızının %150'si
## kadardır."
##
## Hasar doğrudan enemy.take_damage() üzerinden - bu fonksiyon zaten host/
## client farkını kendi içinde çözüyor (bkz. enemy.gd take_damage), çağıran
## tarafın host olup olmadığını düşünmesi gerekmiyor. Vuruş her zaman
## caster'ın KENDİ client'ında (bkz. TotemBase._process, _is_network_visual
## koruması) hesaplanıp gönderiliyor, bu yüzden match_damage_dealt istatistiği
## (bkz. enemy.gd take_damage üstündeki not) ve öldürme pasifleri (bkz.
## enemy.gd die() -> on_enemy_killed) otomatik olarak doğru oyuncuya
## atfediliyor.
## DÜZELTME (kullanıcı isteği: "shamanın tek hedefli saldırı yeteneğinin
## saldırı gücü %150 olmalı") - eskiden 1.0 (yani caster.damage_bonus'un
## %100'ü) idi, artık 1.5.
const ATTACK_POWER_RATIO := 1.5

## Yeteneğe özgü saldırı efekti (KOZMETİK - hasarla hiçbir ilgisi yok):
## her atışta totemin tepesinden hedefe bir alev oku uçar (bkz.
## fx_totem_fire_bolt.gd). Mermi başlangıcı totem sprite'ının tepesine denk
## gelen nokta (bkz. totem_attack.tscn - TotemSprite y=-24'te, 64px sprite).
const BOLT_ORIGIN_OFFSET := Vector2(0, -44)

## Ağ GÖRSEL kopyalarında (gerçek totem başka bir client'ta) atışları göstermek
## için ayrı kozmetik zamanlayıcı - gerçek atış TICK_INTERVAL'le aynı ritimde.
const TotemFireBolt := preload("res://scripts/fx_totem_fire_bolt.gd")
var _visual_shot_timer: float = 0.0


func _init() -> void:
	totem_color = Color(1.0, 0.55, 0.25)
	totem_radius = 260.0


func _process(delta: float) -> void:
	super(delta)
	## Kozmetik atış döngüsü - SADECE ağ görsel kopyalarında çalışır (gerçek
	## totem atışlarını zaten _tick'te kendisi çizer). Aynen kalkan toteminin
	## dalga efektindeki gibi: salt çizim, hiçbir oyun durumu paylaşmaz, yani
	## "kastın ekranında doğru, diğerinde yok" hatasına düşmez.
	if not _is_network_visual:
		return
	_visual_shot_timer -= delta
	if _visual_shot_timer > 0.0:
		return
	_visual_shot_timer += _current_tick_interval()
	var vis_target: Node2D = _find_nearest_enemy()
	if vis_target:
		TotemFireBolt.spawn(get_tree().current_scene, global_position + BOLT_ORIGIN_OFFSET, vis_target, totem_color)


func _tick() -> void:
	if not ("damage_bonus" in caster):
		return
	var target: Node2D = _find_nearest_enemy()
	if not target:
		return
	var dmg: float = float(caster.damage_bonus) * ATTACK_POWER_RATIO
	var is_crit: bool = false
	if caster.has_method("_roll_ability_crit"):
		is_crit = caster._roll_ability_crit()
	if caster.has_method("_apply_ability_crit"):
		dmg = caster._apply_ability_crit(dmg, is_crit)
	if target.has_method("take_damage"):
		target.call("take_damage", dmg, is_crit)
		## Yetenek efekti: atış anında totemden hedefe alev oku uçar. Salt
		## kozmetik - hasar hesabı yukarıda bitti, bu satır silinse bile
		## skilin davranışı değişmez.
		TotemFireBolt.spawn(get_tree().current_scene, global_position + BOLT_ORIGIN_OFFSET, target, totem_color)


## DÜZELTME (kullanıcı isteği: "shamanın tek hedefli saldırı yeteneğinin
## saldırı hızı shaman'ın statlarının %150'si kadar geçerli olmalı") - bkz.
## totem_base.gd _current_tick_interval() üstündeki DÜZELTME notu. caster'ın
## KENDİ saldırı hızı statı player.gd'deki fire_rate_mult (silahın taban
## fire_rate'ine çarpılan genel saldırı hızı çarpanı - DÜŞÜK değer = HIZLI
## saldırı, bkz. weapon.gd set_fire_rate_mult). Totemin taban 1sn'lik tiki bu
## çarpanla ölçeklenip SONRA /1.5 ile ayrıca hızlandırılıyor - shaman saldırı
## hızı yükseltince (fire_rate_mult düşünce) totem de otomatik hızlanır,
## üstüne istenen sabit %50 bonus (1.5x) ekleniyor. caster'da bu stat yoksa
## (ör. ağ görsel kopyasındaki RemotePlayer kuklası) sessizce taban aralığa
## düşer - sadece kozmetik atış ritmini etkiler, hasarı değil.
func _current_tick_interval() -> float:
	if is_instance_valid(caster) and ("fire_rate_mult" in caster):
		return max(0.05, TICK_INTERVAL * float(caster.fire_rate_mult) / 1.5)
	return TICK_INTERVAL


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = totem_radius
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if not (e is Node2D):
			continue
		var d: float = global_position.distance_to((e as Node2D).global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = e as Node2D
	return nearest
