extends Node2D
class_name MissionTree

## "Ağacı Koru" görevi (bkz. world_event_manager.gd) - kullanıcı isteği: "ağaç için temsili
## birşey hazırla" (gerçek büyüme-fazlı sprite paketi hâlâ yok, zip konumu bulunamadı - bkz.
## world_event_manager.gd dosya başı notu). tools/gen_tree_assets.py ile ÜRETİLMİŞ 5 fazlı
## piksel-sanatı bir yer tutucu kullanıyor (assets/generated/mission_tree_phase_0..4.png,
## 64x80, 48x48 piksel yoğunluğu kuralına uyar - bkz. hafıza "Pixel density 48x48"). Gerçek
## asset gelince SADECE PHASE_TEXTURE_PATH_FMT/_apply_phase_texture() değişmesi yeterli, geri kalan
## (can/kalkan/faz zamanlayıcı/ateş topu/agro yönlendirme) AYNEN kalır.
##
## AĞ MİMARİSİ: bu Node HER istemcide (host dahil) world_event_started ile aynı konumda
## yerel olarak kuruluyor (bkz. main.gd _on_world_event_started) - SADECE HOST'ta gerçek
## simülasyon (can/kalkan/ateş topu/hedef yönlendirme) çalışır (enemy.gd'nin AYNI host-
## authoritative deseni), client'larda bu Node SALT GÖRSEL bir kozmetik kopyadır. Can/kalkan
## görüntüsü world_event_progress (value=health+shield, target=max_health+max_shield) ile
## TÜM istemcilere senkron kalıyor - bkz. world_event_manager.gd _tick_mission. Faz (büyüme)
## zamanlayıcısı ise SENKRON GEREKTİRMEZ (sadece kozmetik, PHASE_DURATION sabiti tüm
## istemcilerde aynı ve hepsi world_event_started'ı AYNI anda aldığı için doğal senkron kalır).
## BİLİNEN EKSİK (kullanıcıya bildirilmeli): ateş topu mermisinin GÖRSELİ şu an SADECE
## host'ta görünür (projectile.tscn client'lara broadcast edilmiyor) - hasar/can senkronu
## (yukarıdaki world_event_progress) doğru çünkü o zaten ayrı, ama client host'un ateş
## topunu ATARKEN göremeyebilir. "Geçici" kapsamı gereği şimdilik bırakıldı.

const NUM_PHASES := 5
const PHASE_DURATION := 10.0
const ATTACK_RANGE := 260.0
const ATTACK_INTERVAL := 1.5
const FIREBALL_DAMAGE := 35.0
const BASE_MAX_HEALTH := 3000.0
const BASE_MAX_SHIELD := 800.0
const FIREBALL_COLOR := Color(0.35, 0.65, 1.0, 1.0)
## Kullanıcı isteği (2026-09-24): "ağacın kalkanı hasar almadığında 7 saniye sonra yenilenmeye
## başlamalı yavaşça" - oyuncu kalkanlarındaki (bkz. player.gd _shield_hit_regen_delay) DEĞİŞKEN
## gecikme yerine ağaç için SABİT, tek bir sayı istendi. Hız için net bir sayı verilmedi - "yavaşça"
## sözüne uyacak şekilde max_shield'in %5'i/sn seçildi (boştan dolana ~20sn).
const SHIELD_REGEN_DELAY := 7.0
const SHIELD_REGEN_RATE_RATIO := 0.05 ## max_shield'in bu oranı kadar / saniye
const ProjectileScene := preload("res://scenes/projectile.tscn")
## tools/gen_tree_assets.py'deki AYNI sabitler (W/H/GROUND_Y) - PNG'nin gövde tabanının tuval
## içindeki konumu, sprite'ı bu Node'un global_position'ına (zemin noktası) hizalamak için.
const PHASE_TEXTURE_W := 64
const PHASE_TEXTURE_H := 80
const PHASE_GROUND_Y := 76
const PHASE_TEXTURE_PATH_FMT := "res://assets/generated/mission_tree_phase_%d.png"

var max_health: float = BASE_MAX_HEALTH
var health: float = BASE_MAX_HEALTH
var max_shield: float = BASE_MAX_SHIELD
var shield: float = BASE_MAX_SHIELD
var phase: int = 0
var is_dead: bool = false

var _phase_timer: float = PHASE_DURATION
var _attack_timer: float = 0.0
var _no_damage_timer: float = 0.0 ## bkz. SHIELD_REGEN_DELAY - hasar alınca sıfırlanır
var _is_host_simulated: bool = true
var _sprite: Sprite2D = null
var _last_drawn_phase: int = -1
## Kullanıcı isteği: "ağacın can ve kalkan barı oyuncuların üstündeki can ve kalkan barı gibi
## olsun" - artık scripts/overhead_bar.gd'nin AYNI kopyası (enemy.gd _create_overhead_bar ile
## BİREBİR aynı kurulum deseni), elle çizilen iki düz dikdörtgen DEĞİL.
var _overhead_bar: Node2D = null


func setup(player_count: int, simulated: bool) -> void:
	var mult: float = 1.0 + float(max(0, player_count - 1)) * 0.3
	max_health = BASE_MAX_HEALTH * mult
	health = max_health
	max_shield = BASE_MAX_SHIELD * mult
	shield = max_shield
	_is_host_simulated = simulated


func _ready() -> void:
	z_index = 5
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST ## piksel sanatı bulanıklaşmasın
	## PHASE_GROUND_Y'deki (tuval içindeki gövde tabanı) piksel bu Node'un global_position'ına
	## (zemin noktası) denk gelsin diye - bkz. dosya başı const'lardaki not.
	_sprite.position = Vector2(0.0, float(PHASE_GROUND_Y) - float(PHASE_TEXTURE_H) * 0.5)
	add_child(_sprite)
	_overhead_bar = Node2D.new()
	_overhead_bar.set_script(preload("res://scripts/overhead_bar.gd"))
	add_child(_overhead_bar)
	## enemy.gd'nin boss'lar için yaptığı AYNI şey (bkz. set_overhead_bar_always_visible) -
	## ağacın barı normal bir yaratık gibi bir süre sonra SOLMAZ, görev boyunca hep görünür.
	_overhead_bar.visible = true
	_apply_phase_texture()
	_overhead_bar.call("set_health", health, max_health)
	_overhead_bar.call("set_shield", shield, max_shield)
	set_physics_process(true)


func _apply_phase_texture() -> void:
	if phase == _last_drawn_phase:
		return
	_last_drawn_phase = phase
	var path: String = PHASE_TEXTURE_PATH_FMT % phase
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
	## Faz büyüdükçe taç yükseliyor - bar her seferinde o fazın tepesine göre yeniden konumlanır
	## (bkz. enemy.gd get_overhead_bar_offset - AYNI "sprite boyutuna göre payla yerleştir" fikri).
	if _overhead_bar:
		_overhead_bar.call("set_offset", -_canopy_top_offset() - 22.0)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	## Kozmetik büyüme fazı - HER istemcide (host dahil) yerel, senkron gerektirmez (bkz.
	## dosya başı not).
	_phase_timer -= delta
	if _phase_timer <= 0.0 and phase < NUM_PHASES - 1:
		phase += 1
		_phase_timer = PHASE_DURATION
		_apply_phase_texture()
	if not _is_host_simulated:
		return
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = ATTACK_INTERVAL
		_try_fire_at_nearest_enemy()
	## bkz. SHIELD_REGEN_DELAY notu - hasarsız 7sn sonra kalkan yavaşça yenilenir.
	if shield < max_shield:
		_no_damage_timer += delta
		if _no_damage_timer >= SHIELD_REGEN_DELAY:
			shield = min(max_shield, shield + max_shield * SHIELD_REGEN_RATE_RATIO * delta)
			if _overhead_bar:
				_overhead_bar.call("set_shield", shield, max_shield)


func _try_fire_at_nearest_enemy() -> void:
	var best: Node2D = null
	var best_d: float = ATTACK_RANGE
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var d: float = global_position.distance_to((e as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return
	var proj: Area2D = ProjectileScene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position
	proj.direction = (best.global_position - global_position).normalized()
	proj.damage = FIREBALL_DAMAGE
	proj.modulate = FIREBALL_COLOR


## Oyuncu take_damage(amount, source) imzasıyla AYNI (bkz. enemy.gd _apply_aggro_overrides'ın
## GameManager.defend_tree_ref'i "hedef oyuncu" gibi kullanması - yaratıklar bu ağaca TAM OLARAK
## bir oyuncuya saldırdıkları gibi saldırır, bu yüzden çağrı imzası birebir uymalı).
func take_damage(amount: float, _source: Node2D = null) -> void:
	if is_dead or not _is_host_simulated:
		return
	_no_damage_timer = 0.0
	if shield > 0.0:
		var absorbed: float = min(shield, amount)
		shield -= absorbed
		amount -= absorbed
	if amount > 0.0:
		health = max(0.0, health - amount)
	if _overhead_bar:
		_overhead_bar.call("set_health", health, max_health)
		_overhead_bar.call("set_shield", shield, max_shield)
	if health <= 0.0:
		is_dead = true


## Sadece görsel senkron için (bkz. dosya başı not) - client'lar host'un gerçek can/kalkanını
## world_event_progress'ten burada uygular, kendi take_damage'ları çalışmaz (_is_host_simulated=false).
func apply_synced_health(total: float, max_total: float) -> void:
	if max_total <= 0.0:
		return
	var ratio: float = clamp(total / max_total, 0.0, 1.0)
	health = max_health * ratio
	shield = max_shield * ratio
	if _overhead_bar:
		_overhead_bar.call("set_health", health, max_health)
		_overhead_bar.call("set_shield", shield, max_shield)


## tools/gen_tree_assets.py'deki trunk_h/canopy_r formülüyle AYNI (yaklaşık) oranlar - piksel-
## piksel eşleşmesi gerekmiyor, sadece can/kalkan çubuğunu (bkz. _overhead_bar) o fazın taç
## tepesine yakın tutmak için.
func _canopy_top_offset() -> float:
	var t: float = float(phase) / float(NUM_PHASES - 1)
	var trunk_h: float = 8.0 + t * 22.0
	var canopy_r: float = 9.0 + t * 15.0
	return trunk_h + canopy_r * 1.4
