extends TotemBase
class_name TotemAttack

## Saldırı Totemi (Shaman Q, skill id 27): "Etrafındaki yaratıklara
## düzenli olarak ateş eder. Her saldırı shaman'ın saldırı gücünün %150'si
## kadar hasar verir, saldırı hızı da shaman'ın kendi saldırı hızının %150'si
## kadardır."
## Kullanıcı isteği (2026-09-29): "E ve R'nin etkileri artık birleştiriliyor ve tek yetenek haline geliyor fakat yavaşlatma
## etkisi kaldırılıyor. E ve R artık yeni Q yeteneği oluyor" - eski Alan Saldırı Totemi'nin (R, id 28, totem_area.gd -
## SİLİNDİ) alan hasarı + mor alan görselleri bu totemin içine taşındı; yavaşlatma YOK. 2026-09-30: alan hasarı Kalkan
## Totemi'ne de eklendi (kullanıcı isteği) - kod artık totem_base.gd "ALAN HASARI" bloğunda (area_damage_enabled, iki totem
## aynı kodu kullanır). Ateş menzili (totem_radius 260) ile alan yarıçapı (AREA_RADIUS 180) ayrı.
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
## Silah/yetenek hedef seçiminde görünürlük şartı (bkz. VisionFogScript.can_target).
const VisionFogScript: GDScript = preload("res://scripts/vision_fog.gd")

const ATTACK_POWER_RATIO := 1.5

## Yeteneğe özgü saldırı efekti (KOZMETİK - hasarla hiçbir ilgisi yok):
## her atışta totemin tepesinden hedefe bir alev oku uçar (bkz.
## fx_totem_fire_bolt.gd). Mermi başlangıcı totem sprite'ının tepesine denk
## gelen nokta (bkz. totem_attack.tscn - yeni 48x48 sprite, boynuzlu maskenin üstündeki alev; kullanıcı isteği 2026-09-21).
const BOLT_ORIGIN_OFFSET := Vector2(0, -56) ## totem (48x64 kare): koç kafatasının tepesindeki ruh ateşinin merkezi (bkz. tools/shaman_totem_art.py)

## Ağ GÖRSEL kopyalarında (gerçek totem başka bir client'ta) atışları göstermek
## için ayrı kozmetik zamanlayıcı - gerçek atış TICK_INTERVAL'le aynı ritimde.
const TotemFireBolt := preload("res://scripts/fx_totem_fire_bolt.gd")
var _visual_shot_timer: float = 0.0

## Yetenek evrimleri (kart metinleri skill_evolutions.gd DEFS[12]):
##  - "Alev Dokunuşu" (shaman_q2): her totem atışı hedefi, Shaman pasifinin yakmasıyla (enemy.gd try_shaman_weapon_burn ile AYNI
##    sayılar: saniyede saldırı gücünün %10'u, 3 sn) yakar. Pasifin "totem yakınında olma" şartı aranmaz (kullanıcı: totemin
##    saldırıları pasiften yararlanır); silah saldırıları için pasif aynen eskisi gibi.
##  - "Ruh Emici" (shaman_q4): atış isabetinde +%5 can çalma (player.gd evo_hit_lifesteal; can çalma statları zaten aynı isabette
##    on_dealer_hit -> on_damage_dealt ile işler). Çalınan can kasterin kendisine yenilenir (totem hasarı kasterin client'ında).
##  - "Patlayan Alev" (shaman_qf, final): isabet ettiği hedefin etrafındaki yaratıklara atış hasarının %50'si (alan hasarı).
const EVO_BURN_RATIO := 0.10
const EVO_BURN_TIME := 3.0
const EVO_BLAST_RADIUS := 90.0
const EVO_BLAST_RATIO := 0.5


func _init() -> void:
	totem_kind = "attack"
	totem_color = Color(1.0, 0.55, 0.25)
	totem_radius = 260.0
	area_damage_enabled = true ## bkz. totem_base.gd "ALAN HASARI" bloğu
	show_area_aura = false ## mor sınır çemberi kaldırıldı (kullanıcı isteği 2026-10-04); alan hasarı değişmedi


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
		TotemFireBolt.spawn(get_tree().current_scene, global_position + BOLT_ORIGIN_OFFSET, vis_target, totem_color, _blast_radius())


## Patlama yarıçapı (evrim yoksa 0). Ağ görsel kopyasında da çağrılır: patlama halkası her oyuncuda aynı çıksın.
func _blast_radius() -> float:
	return EVO_BLAST_RADIUS if _caster_has_evo("shaman_qf") else 0.0


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
		var hit_pos: Vector2 = target.global_position
		## Ruh Emici: +%5 can çalma SADECE bu isabete (take_damage -> on_dealer_hit eşzamanlı çalışır).
		var evo_ls: float = float(caster.call("get_shaman_totem_lifesteal")) if caster.has_method("get_shaman_totem_lifesteal") else 0.0
		if evo_ls > 0.0 and "evo_hit_lifesteal" in caster:
			caster.set("evo_hit_lifesteal", evo_ls)
		target.call("take_damage", dmg, is_crit)
		if evo_ls > 0.0 and "evo_hit_lifesteal" in caster:
			caster.set("evo_hit_lifesteal", 0.0)
		## Alev Dokunuşu: hedef hâlâ hayattaysa yak (yaratığın üstündeki yanma host-yetkili; apply_burn istemciyi host'a yönlendirir).
		if _caster_has_evo("shaman_q2") and is_instance_valid(target) and target.get("is_dead") != true and target.has_method("apply_burn"):
			target.call("apply_burn", float(caster.damage_bonus) * EVO_BURN_RATIO, EVO_BURN_TIME)
		## Patlayan Alev: isabet noktasının etrafındaki diğer yaratıklara hasarın %50'si.
		var blast: float = _blast_radius()
		if blast > 0.0:
			_explode(target, hit_pos, dmg * EVO_BLAST_RATIO, blast)
		## Yetenek efekti: atış anında totemden hedefe alev oku uçar. Salt
		## kozmetik - hasar hesabı yukarıda bitti, bu satır silinse bile
		## skilin davranışı değişmez.
		TotemFireBolt.spawn(get_tree().current_scene, global_position + BOLT_ORIGIN_OFFSET, target, totem_color, blast)


## Patlayan Alev hasarı: vurulan hedef HARİÇ yarıçaptaki yaratıklara sabit hasar (kritik zarı yok - atışın kendi hasarı zaten kritik
## çarpanını içerir; alan hasarı sayılır, bu yüzden can çalma %33 etkili). Görünürlük (can_target) şartı yok - alan hasarı kuralı.
func _explode(hit_target: Node2D, center: Vector2, blast_dmg: float, radius: float) -> void:
	if blast_dmg <= 0.0:
		return
	for e in EnemyQueryScript.candidates(get_tree(), center, radius + 1.0):
		if e == hit_target or not is_instance_valid(e) or e.get("is_dead") == true or not (e is Node2D):
			continue
		if center.distance_to((e as Node2D).global_position) > radius:
			continue
		if e.has_method("take_damage"):
			e.call("take_damage", blast_dmg, false, 0.0, true)


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
	for e in EnemyQueryScript.candidates(get_tree(), global_position, totem_radius + 1.0):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if not (e is Node2D):
			continue
		if not VisionFogScript.can_target(e):
			continue
		var d: float = global_position.distance_to((e as Node2D).global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = e as Node2D
	return nearest
