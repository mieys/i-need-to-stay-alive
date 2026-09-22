extends Node2D

## Oakley'in Sarmaşıklar yeteneği (E, kullanıcı isteği: "Oakley yeni
## yetenekleri" 2. Yetenek - SADECE Oakley, Melek'e dokunulmadı) - yaratıklar
## arasında yavaşça dolaşan, isabet ettiği yaratığı sabitleyen bir sarmaşık.
## player.gd _skill_oakley_vines() üç tanesini oluşturur.
##
## DÜZELTME (kullanıcı bildirimi: "sarmaşıklar yaratıklar arasında yavaşça
## hareket etmeli ve her isabet ettiği yaratığı sabitlemeliydi ama sadece 3
## yaratığa çarpıp yok oluyor") - eskiden her sarmaşık CAST ANINDA en yakın
## TEK bir yaratığa kilitlenip ona doğru hızla gidiyor, ilk isabette
## queue_free() ile YOK OLUYORDU (yani en fazla 3 isabet, sonra yetenek
## bitiyordu). Artık bir sarmaşık isabet ettiğinde YOK OLMUYOR - hedefi
## sabitleyip (aynı yaratığa hemen tekrar vurmasın diye _recent_hits
## cooldown'una alıp) YENİ bir yakın yaratık arıyor, LIFETIME (6sn) dolana
## kadar bunu tekrarlıyor. Sabit hedef yoksa (herkes cooldown'da/menzil
## dışında) rastgele bir yöne doğru yavaşça "dolaşıyor" (_wander), donmuş
## durmuyor.
##
## DÜZELTME (kullanıcı isteği: "senkronize et, ben nasıl görüyosam diğer
## oyuncular da öyle görmeli") - eskiden bu efekt SADECE döken oyuncunun
## kendi istemcisinde vardı (hasar/sabitleme enemy.gd'nin host-yetkili
## senkronuyla zaten TÜM istemcilere doğru yansıyordu, ama sarmaşığın
## GÖRSELİ hiç yayınlanmıyordu). Artık skeleton_pet.gd/golem_pet.gd'nin
## "gerçek kopya kendi konumunu periyodik yayınlar, kozmetik kopya SADECE
## bunu takip eder, kendi başına AI çalıştırmaz" deseniyle (bkz.
## network_manager.gd broadcast_oakley_vine_spawn/despawn/state) BİREBİR
## aynı şekilde diğer istemcilere de gösteriliyor. Kozmetik kopyanın gerçek
## bir Enemy referansı olmadığı için (bkz. mark_as_network_visual) hedefin
## KENDİSİ değil ANLIK KONUMU (target_pos) gönderiliyor - Line2D'yi buna göre
## çiziyor. Spawn/despawn yayını player.gd _skill_oakley_vines()'ta yapılıyor
## (bkz. oradaki not - necro pet'lerle AYNI "player.gd spawn/despawn yayınlar,
## pet/vine kendi state'ini yayınlar" görev ayrımı).
## Silah/yetenek hedef seçiminde görünürlük şartı (bkz. VisionFogScript.can_target).
const VisionFogScript: GDScript = preload("res://scripts/vision_fog.gd")

const PixelDrawScript: GDScript = preload("res://scripts/pixel_draw.gd")
const NETWORK_STATE_THROTTLE := 0.2 ## saniyede ~5 kez - skeleton_pet.gd _broadcast_network_state ile AYNI aralık

## player.gd _skill_oakley_vines() tarafından atanır - broadcast_oakley_vine_
## state'in hangi kozmetik kopyaya karşılık geldiğini eşlemek için (bkz.
## network_manager.gd _find_remote_player + remote_player.gd _vine_visuals).
var network_instance_id: String = ""
## true ise bu KOZMETİK bir kopya (başka bir istemcide dolaşan gerçek
## sarmaşığın izleyicisi) - bkz. mark_as_network_visual(). Kendi AI'ı
## (hedef arama/hasar/sabitleme/dolaşma) TAMAMEN kapanır, SADECE
## update_network_vine_state() ile gelen konuma yumuşakça kayar.
var _is_network_visual: bool = false
var _network_target_position: Vector2 = Vector2.ZERO
var _network_target_point: Vector2 = Vector2.ZERO
var _network_has_target: bool = false

const SPEED := 110.0 ## yavaşça hareket etsin diye eski 340'tan düşürüldü
const WANDER_SPEED := 55.0
const LIFETIME := 6.0
const HIT_RADIUS := 22.0
const ROOT_DURATION := 4.0
const BOSS_SLOW_PERCENT := 0.30
const DAMAGE_RATIO := 0.60 ## saldırı gücünün %60'ı
## Yeni hedef ararken bu mesafedeki yaratıklardan RASTGELE biri seçilir -
## "en yakına" değil, böylece 3 sarmaşık aynı yaratığa üşüşmez, dağınık
## davranır (kullanıcı isteği: "rastgele hareket etmesi").
const RETARGET_SEARCH_RADIUS := 280.0
## Bir yaratığa isabet ettikten sonra AYNI yaratığın tekrar hedef olarak
## seçilmemesi için kısa bir süre - yoksa sarmaşık tek bir yaratığın
## üstünde salınıp tekrar tekrar aynısını vurabilirdi.
const TARGET_HIT_COOLDOWN := 1.5

var _damage_bonus: float = 0.0
var _lifetime_remaining: float = LIFETIME
var _target: Node2D = null
## Pixel tarzı dikenli sarmaşık görseli (bkz. oakley_vine_visual.gd) - eskiden Line2D'ydi; `points` arayüzü aynı kaldı.
var _visual: Node2D = null
var _recent_hits: Dictionary = {} ## instance_id -> kalan cooldown süresi
var _wander_point: Vector2 = Vector2.ZERO
var _has_wander_point: bool = false


func setup(caster_damage_bonus: float) -> void:
	_damage_bonus = caster_damage_bonus


func _ready() -> void:
	z_index = 4
	## Kardeş sarmaşıklar birbirinin hedefini görebilsin (bkz. _pick_new_target - aynı yaratığa üşüşmesinler).
	if not _is_network_visual:
		add_to_group("oakley_vines")
	_visual = Node2D.new()
	_visual.set_script(preload("res://scripts/oakley_vine_visual.gd"))
	add_child(_visual)
	## Toprağın içinden çıkış: küçük toprak patlaması (gerçek + kozmetik kopyada aynı).
	PixelDrawScript.spawn_burst(get_tree().current_scene, global_position, "dust", 8, 70.0, 0.4)
	_pick_new_target()


## bkz. dosya başı DÜZELTME notu - kozmetik kopyalar (_is_network_visual)
## KENDİ yapay zekasını hiç çalıştırmaz, SADECE gelen ağ konumuna yumuşakça
## kayar (skeleton_pet.gd _process'teki AYNI erken dal deseni).
func mark_as_network_visual() -> void:
	_is_network_visual = true


## broadcast_oakley_vine_state RPC'sinin (bkz. network_manager.gd) çağırdığı
## istemci tarafı karşılığı.
func update_network_vine_state(pos: Vector2, target_pos: Vector2, has_target: bool) -> void:
	_network_target_position = pos
	_network_target_point = target_pos
	_network_has_target = has_target


func _process(delta: float) -> void:
	if _is_network_visual:
		global_position = global_position.lerp(_network_target_position, min(1.0, delta * 12.0))
		_visual.points = PackedVector2Array([Vector2.ZERO, _network_target_point - global_position]) if _network_has_target else PackedVector2Array()
		return

	_lifetime_remaining -= delta
	if _lifetime_remaining <= 0.0:
		queue_free()
		return

	for id in _recent_hits.keys():
		_recent_hits[id] -= delta
		if _recent_hits[id] <= 0.0:
			_recent_hits.erase(id)

	if not is_instance_valid(_target) or bool(_target.get("is_dead")):
		_pick_new_target()

	if is_instance_valid(_target):
		_has_wander_point = false
		var to_target: Vector2 = _target.global_position - global_position
		var dist: float = to_target.length()
		_visual.points = PackedVector2Array([Vector2.ZERO, to_target])
		if dist <= HIT_RADIUS:
			_on_hit()
			_broadcast_network_state()
			return
		global_position += (to_target / dist) * SPEED * delta
	else:
		## Menzilde uygun (cooldown'da olmayan) yaratık yoksa donup kalmasın
		## diye rastgele bir noktaya doğru yavaşça sürükleniyor - her adımda
		## yeniden hedef arıyor, biri menzile girer girmez ona yöneliyor.
		_visual.points = PackedVector2Array()
		if not _has_wander_point or global_position.distance_to(_wander_point) < 12.0:
			_wander_point = global_position + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * randf_range(50.0, 120.0)
			_has_wander_point = true
		var to_wander: Vector2 = _wander_point - global_position
		if to_wander.length() > 1.0:
			global_position += to_wander.normalized() * WANDER_SPEED * delta
	_broadcast_network_state()


## Sadece GERÇEK sarmaşık (kozmetik olmayan) çalıştırır - bkz. dosya başı
## DÜZELTME notu, skeleton_pet.gd _broadcast_network_state ile AYNI desen.
func _broadcast_network_state() -> void:
	if not NetworkManager.is_multiplayer_active or network_instance_id.is_empty():
		return
	if NetworkManager.should_throttle("oakleyvine_%s" % network_instance_id, NETWORK_STATE_THROTTLE):
		return
	var target_point: Vector2 = _target.global_position if is_instance_valid(_target) else global_position
	NetworkManager.broadcast_oakley_vine_state.rpc(multiplayer.get_unique_id(), network_instance_id, global_position, target_point, is_instance_valid(_target))


## DÜZELTME (kullanıcı isteği: "Oakleyin sarmaşıkları en yakın düşmana
## öncelik vermeli") - eskiden menzildeki (cooldown'da olmayan) yaratıklardan
## RASTGELE birine kilitleniyordu (bkz. RETARGET_SEARCH_RADIUS üstündeki
## eski not - 3 sarmaşığın aynı yaratığa üşüşmemesi içindi). Artık en
## yakın olan seçiliyor.
func _pick_new_target() -> void:
	## Kullanıcı isteği (2026-09-21): "Oakley'in sarmaşıkları 3 tane olmalı" - 3 sarmaşık zaten oluşuyordu ama üçü de EN YAKIN
	## AYNI yaratığa kilitlenip aynı yerde üst üste biniyor, ekranda tek sarmaşık gibi görünüyordu. Artık her sarmaşık, kardeşlerinin
	## henüz KİLİTLENMEDİĞİ en yakın yaratığı seçer (en yakın önceliği korunur); hepsi doluysa (yaratık sayısı 3'ten azsa) yine
	## en yakına gider.
	var claimed: Dictionary = {}
	for other in get_tree().get_nodes_in_group("oakley_vines"):
		if other == self or not is_instance_valid(other):
			continue
		var other_target: Variant = other.get("_target")
		if other_target != null and is_instance_valid(other_target):
			claimed[(other_target as Node).get_instance_id()] = true
	var best: Node2D = null
	var best_dist: float = INF
	var best_any: Node2D = null
	var best_any_dist: float = INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if _recent_hits.has(e.get_instance_id()):
			continue
		if not VisionFogScript.can_target(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d > RETARGET_SEARCH_RADIUS:
			continue
		if d < best_any_dist:
			best_any = e
			best_any_dist = d
		if not claimed.has(e.get_instance_id()) and d < best_dist:
			best = e
			best_dist = d
	_target = best if best != null else best_any


func _on_hit() -> void:
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
		_recent_hits[_target.get_instance_id()] = TARGET_HIT_COOLDOWN
	## DÜZELTME (kök neden): eskiden burada queue_free() vardı - sarmaşık
	## isabetten SONRA artık ölmüyor, hemen yeni bir hedef arıyor (bkz.
	## _process'teki "not is_instance_valid(_target)" dalı bir sonraki karede
	## bunu zaten yapar, burada sadece hedefi boşaltmak yeterli).
	_target = null
