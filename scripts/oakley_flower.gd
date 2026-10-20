extends Node2D

## Oakley'in Çiçek yeteneği (Q, kullanıcı isteği: "Oakley yeni yetenekleri"
## 1. Yetenek - SADECE Oakley, Melek'e dokunulmadı) - yere bırakılan, kendisi
## veya bir dost tarafından alınabilen bir can yenileme eşyası.
##
## AĞ DESENİ: Her istemci KENDİ yerel kopyasını (bkz. player.gd _try_oakley_
## flower -> NetworkManager.broadcast_player_vfx "oakley_flower_spawn")
## bağımsız oluşturuyor - konum/saldırı gücü/kimlik (flower_id) hepsi aynı
## veriyle kuruluyor. Toplama fiziksel çarpışma (Area2D) YERİNE her karede
## SADECE bu istemcinin KENDİ yerel oyuncusuna (bkz. player.tscn'in
## collision_layer'ı 0 olduğu için gold_drop.gd gibi Area2D tabanlı
## toplama zaten yerel oyuncuyu hiç yakalayamıyor - bkz. "beni oku.txt"
## gerektirmeyen basit bir mesafe kontrolüyle) karşı mesafe kontrolüyle
## yapılıyor - bu istemci zaten kendi can/hız statlarına yetkili. Alınınca
## "flower_picked" yayınlanır ki DİĞER istemciler de (kendi yerel oyuncuları
## için AYRI AYRI aynı kontrolü çalıştırıyor olsalar da, ilk alan kazansın
## diye) kendi çiçek kopyalarını kaldırsın (bkz. network_manager.gd
## broadcast_flower_picked). Bu proje genelindeki "her istemci kendi
## görselini/etkisini üretir, sonra diğerlerine bildirir" deseniyle (bkz.
## proje kökündeki CLAUDE.md) birebir aynı.

const LIFETIME := 180.0
const GROWTH_INTERVAL := 5.0
const GROWTH_STAGE_BONUS := 0.40 ## her büyümede TABAN değere +%40 (kümülatif, en fazla 2 büyüme)
const PICKUP_RADIUS := 26.0
const HEAL_RATIO_OF_ATTACK := 0.50 ## can = saldırı gücünün %50'si (büyüme öncesi taban)
## DÜZELTME (kullanıcı isteği: "Oakleyin Q yeteneğinin can vermesiyle beraber
## aynı zamanda alan kişinin %2 maksimum kalkanı ve oakleyin %15 saldırı gücü
## statı kadar kalkan yenilemeli ve bu etkinin gücü can vermede olduğu gibi
## bitki büyüdükçe artmalı") - can ile AYNI büyüme çarpanını (GROWTH_STAGE_
## BONUS) kullanan AYRI bir kalkan miktarı, bkz. _current_shield_amount.
const SHIELD_PERCENT_OF_TARGET_MAX := 0.02 ## alanın kendi max kalkanının %2'si
const SHIELD_RATIO_OF_ATTACK := 0.15 ## + Oakley'nin saldırı gücünün %15'i
const PICKUP_SPEED_BONUS := 0.25
const PICKUP_SPEED_DURATION := 2.0
## Kullanıcı bildirimi: "Oakley yere bitki bırakamıyor çünkü bıraktığı anda
## tüketiliyor" - çiçek caster'ın TAM konumunda spawn olduğu için _process
## ilk karede zaten PICKUP_RADIUS içinde buluyordu, hiç yere düşmeden
## kayboluyordu. Bırakıldıktan sonra bu kadar süre alım kontrolü tamamen
## devre dışı, herkes (caster dahil) sadece bu süre geçtikten sonra alabilir.
const PICKUP_DELAY := 0.5

var flower_id: String = ""
var _caster_damage_bonus: float = 0.0
var _growth_stage: int = 0 ## 0, 1, 2
var _lifetime_remaining: float = LIFETIME
var _growth_timer: float = GROWTH_INTERVAL
var _pickup_delay_remaining: float = PICKUP_DELAY
var _picked: bool = false

var _sprite: AnimatedSprite2D = null

## NOT: çiçeği sıradan dekordan ayıran büyü efekti ("çiçeklerin üstüne sihirli yeşil bir efekt koy, haritadaki diğer çiçeklerden farkı belli
## olsun"): önce yumuşak vektör halka, sonra CraftPix Life Recovery çemberi, 2026-10-19'dan beri "YAPRAK HALKASI" (madde 285 prototip C,
## scripts/oakley_flower_fx.gd): yerde ışık havuzu + çiçeğin çevresinde dönen yapraklar, aşamayla büyüyüp gelişir (2/4/6 yaprak).

## DÜZELTME (kullanıcı isteği: "efekt sistemi" - Oakley'nin çiçek yeteneğinin
## 3 dönüşümü için gerçek bir sprite eklendi) - eskiden burada gerçek sanat
## eseri olmadığı için basit bir sarı Polygon2D çiziliyordu (bkz. yorum
## geçmişi). Artık fx_oakley_flower_stages_frames.tres'teki 3 kare
## (stage0/1/2, soldan sağa) kullanılıyor - _growth_stage (0,1,2) hangi
## karenin gösterileceğini doğrudan belirliyor, "stage%d" adlandırması bunun
## için seçildi.
const FlowerStagesFrames := preload("res://assets/generated/fx_oakley_flower_stages_frames.tres")
## Yaprak Halkası: tek materyal (_fx_mat) + üç dörtgen - zemin (_spawn_ground_fx), arka (sprite'tan önce), ön (sprite'tan sonra); durum fx_state().
const FlowerFx := preload("res://scripts/oakley_flower_fx.gd")
const DepthScript := preload("res://scripts/depth_occluders.gd")
const EnemyAbilities := preload("res://scripts/enemy_abilities.gd")
const BalanceLogScript := preload("res://scripts/balance_log.gd")

## DERİNLİK (2026-10-19, kullanıcı: "çiçek Y eksenine tabi değil bazı şeylerin üstünde duruyor"): eskiden çiçek z 5'teydi - oyuncuların (z 1),
## yaratıkların (z 0/2) ve ağaç/ev ön kopyalarının (z 3) HEPSİNİN üstünde çiziliyordu; çember de çocuğu olduğu için (z -1 göreli = 4) oyuncunun
## ayağının üstündeydi. Artık:
##  - çiçek z 0 + YSORT_GROUP: main.gd yaratık/evcil sıralamasına (ayak hizası) katılır -> önündeki yaratık üstte, arkasındaki altta;
##  - arkasında duran (ayağı çiçeğin kökünün üstünde, gövdesi çiçekle örtüşen) oyuncu/kukla varsa z 2 (oyuncu z 1'in üstü, ağaç kopyası z 3'ün altı);
##  - DEPTH_GROUP: depth_occluders.gd ağaç/ev/maden ön kopyaları önündeki çiçeği (ve zemin efektini) örter;
##  - büyü efekti AYRI zemin düğümü (EnemyAbilities.place_on_ground: haritanın hemen üstü, yaratık/oyuncuların altı), çiçekle birlikte silinir.
## Tamamen yerel/kozmetik (her istemci kendi kopyasında), ağ yok.
const YSORT_GROUP := "ysort_props" ## main.gd CREATURE_SORT_GROUPS
const DEPTH_GROUP := "depth_props" ## depth_occluders.gd update_creatures
const FLOWER_Z := 0
const FLOWER_FRONT_Z := 2
const FOOT_Y := 20.0 ## 31x42 ortalı karenin en alt opak satırı (41) -> kökün 20 px altı = yere değdiği çizgi
## Aşama başına örtü alanı: çiçek (fx_oakley_flower_stages.png opak alanı 9/15/16 x 14/20/34) VE dönen yapraklar (yörünge R + yaprak yarısı,
## yerden H + R x 0,45 + yaprak + sallanma) - hangisi büyükse. Merkezden en uzak kenar (yarım genişlik) ve ayaktan tepeye boy.
const STAGE_HALF_W: Array[float] = [14.0, 18.0, 23.0]
const STAGE_HEIGHT: Array[float] = [16.0, 21.0, 34.0]
const DEPTH_EVERY := 3 ## kare - oyuncu çiçeğin arkasına 3 karede geçemez
## Efekt yalnız ekrandayken güncellenir (yaprak konumları her karede materyale yazılır); dikdörtgen üç dörtgeni (oakley_flower_fx.gd QUAD_*) kapsar.
const FX_VIS_RECT := Rect2(-32.0, -36.0, 64.0, 72.0)

var _ground_fx: Node2D = null
var _fx_mat: ShaderMaterial = null ## Yaprak Halkası boyaması GPU'da (oakley_flower_fx.gd FPS notu); üç dörtgen paylaşır
var _fx_age: float = 0.0
var _orbit_phase: float = 0.0
var _grow_from: int = 0 ## son büyümeden önceki aşama (geçiş animasyonu)
var _grow_age: float = 99.0 ## son büyümeden beri geçen sn
var _fx_on_screen: bool = true


func _ready() -> void:
	add_to_group("oakley_flowers")
	add_to_group(YSORT_GROUP)
	add_to_group(DEPTH_GROUP)
	z_index = FLOWER_Z
	## Arka yarı yapraklar sprite'tan ÖNCE (çiçeğin arkasında), ön yarı SONRA (önünde) - aynı materyal, katman dörtgenin dokusunda.
	_fx_mat = FlowerFx.make_material()
	FlowerFx.update_material(_fx_mat, fx_state())
	add_child(FlowerFx.make_quad(_fx_mat, FlowerFx.LAYER_BACK))
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "AnimatedSprite2D" ## main.gd _find_creature_visual / depth_occluders.creature_body adıyla bulur (ayak + gövde ölçüsü)
	_sprite.sprite_frames = FlowerStagesFrames
	_sprite.play("stage0")
	add_child(_sprite)
	add_child(FlowerFx.make_quad(_fx_mat, FlowerFx.LAYER_FRONT))
	var vis := VisibleOnScreenNotifier2D.new()
	vis.rect = FX_VIS_RECT
	vis.screen_entered.connect(func() -> void: _fx_on_screen = true)
	vis.screen_exited.connect(func() -> void: _fx_on_screen = false)
	add_child(vis)
	_update_depth_body()
	## "oakleyin bitkisinin üstünde de sürekli aktif olacak bu efekt alınana kadar" - çağıran konumu add_child'dan SONRA veriyor -> zemin
	## düğümü kare sonunda kurulur. Her istemci kendi çiçeğini kurduğu için ayrı RPC gerekmez.
	_spawn_ground_fx.call_deferred()


func _spawn_ground_fx() -> void:
	var parent: Node = get_parent()
	if _picked or not is_inside_tree() or parent == null:
		return
	_ground_fx = Node2D.new()
	_ground_fx.set_script(FlowerFx)
	_ground_fx.set("flower", self)
	_ground_fx.z_index = FLOWER_Z
	_ground_fx.add_child(FlowerFx.make_quad(_fx_mat, FlowerFx.LAYER_GROUND))
	parent.add_child(_ground_fx)
	_ground_fx.global_position = global_position ## çizim çiçeğin yerel koordinatında (kök = çiçek merkezi)
	EnemyAbilities.place_on_ground(get_tree(), _ground_fx)
	_ground_fx.set_meta("_depth_body", Vector2(FlowerFx.GROUND_HALF_W, FlowerFx.GROUND_HEIGHT))
	_ground_fx.set_meta("_foot_visual", _ground_fx)
	_ground_fx.set_meta("_foot_local", FlowerFx.GROUND_FOOT)
	_ground_fx.add_to_group(DEPTH_GROUP)


## Yaprak Halkası durumu (oakley_flower_fx.gd state): yaş, yörünge fazı, geçiş.
func fx_state() -> Array:
	return FlowerFx.state(_fx_age, _orbit_phase, _grow_from, _growth_stage, _grow_age)


func _exit_tree() -> void:
	if is_instance_valid(_ground_fx):
		_ground_fx.queue_free()
	_ground_fx = null


## depth_occluders.creature_body düğüm başına bir kez ölçüp meta'ya yazıyor (ilk kare = filiz) - büyüdükçe biz güncelliyoruz.
func _update_depth_body() -> void:
	set_meta("_depth_body", Vector2(STAGE_HALF_W[_growth_stage], STAGE_HEIGHT[_growth_stage] + 2.0))


## Arkasında (ayağı kökün üstünde, tepesinin altında) ve yatayda örtüşen bir karakter varsa çiçek onun üstüne çıkar.
func _update_depth() -> void:
	var base_y: float = global_position.y + FOOT_Y
	var top_y: float = base_y - STAGE_HEIGHT[_growth_stage]
	var half_w: float = STAGE_HALF_W[_growth_stage]
	var behind: bool = false
	for c: Vector4 in DepthScript.collect_characters(get_tree()):
		if c.y < base_y and c.y > top_y and absf(c.x - global_position.x) < half_w + c.z:
			behind = true
			break
	z_index = FLOWER_FRONT_Z if behind else FLOWER_Z


## player.gd tarafından spawn anında, network_manager.gd tarafından da
## uzak-oyunculardan gelen "oakley_flower_spawn" VFX'inde çağrılır - ikisi de
## AYNI veriyle (caster'ın O ANKİ saldırı gücü + benzersiz kimlik) kuruyor,
## yani hangi istemcide alınırsa alınsın can miktarı her yerde birebir aynı.
func setup(caster_damage_bonus: float, p_flower_id: String) -> void:
	_caster_damage_bonus = caster_damage_bonus
	flower_id = p_flower_id


func _process(delta: float) -> void:
	if _picked:
		return
	if _pickup_delay_remaining > 0.0:
		_pickup_delay_remaining -= delta
	else:
		var local_player: Node = get_tree().get_first_node_in_group("player")
		if local_player and is_instance_valid(local_player) and local_player is Node2D \
				and global_position.distance_to((local_player as Node2D).global_position) <= PICKUP_RADIUS:
			_pick_up(local_player)
			return
	_lifetime_remaining -= delta
	if _lifetime_remaining <= 0.0:
		queue_free()
		return
	_growth_timer -= delta
	if _growth_timer <= 0.0 and _growth_stage < 2:
		_grow_from = _growth_stage
		_grow_age = 0.0
		_growth_stage += 1
		_growth_timer = GROWTH_INTERVAL
		_update_depth_body()
		if _sprite:
			## Büyüme geri bildirimi: 3 dönüşümün kendi karesine geçiliyor
			## (bkz. FlowerStagesFrames üstündeki DÜZELTME notu).
			_sprite.play("stage%d" % _growth_stage)
	if (Engine.get_process_frames() + get_instance_id()) % DEPTH_EVERY == 0:
		_update_depth()
	_process_fx(delta)


## Yaprak Halkası saati: faz BİRİKİR (hız aşamayla artınca yapraklar sıçramasın), geçişte hız da yumuşak kayar.
func _process_fx(delta: float) -> void:
	_fx_age += delta
	_grow_age += delta
	var k: float = clampf(_grow_age / FlowerFx.TRANS, 0.0, 1.0)
	_orbit_phase = fmod(_orbit_phase + lerpf(FlowerFx.SPEED[_grow_from], FlowerFx.SPEED[_growth_stage], k) * delta, TAU * 64.0)
	if _fx_on_screen and _fx_mat:
		FlowerFx.update_material(_fx_mat, fx_state())


func _current_heal_amount() -> float:
	return _caster_damage_bonus * HEAL_RATIO_OF_ATTACK * (1.0 + GROWTH_STAGE_BONUS * _growth_stage)


## bkz. SHIELD_PERCENT_OF_TARGET_MAX üstündeki DÜZELTME notu - can miktarıyla
## AYNI büyüme çarpanını kullanır, ama alanın KENDİ max kalkanına da bağlı
## olduğu için (can'ın aksine) body parametre alıyor.
func _current_shield_amount(body: Node) -> float:
	var target_max_shield: float = float(body.item_shield_max) if "item_shield_max" in body else 0.0
	return (target_max_shield * SHIELD_PERCENT_OF_TARGET_MAX + _caster_damage_bonus * SHIELD_RATIO_OF_ATTACK) \
			* (1.0 + GROWTH_STAGE_BONUS * _growth_stage)


## Bu istemcinin Oakley'sinin çiçeği mi (flower_id = "<peer>_<sayaç>", player.gd _try_oakley_flower)? Shift ipucu "BU OYUNDA" için.
func _is_own_flower() -> bool:
	var me: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	return flower_id.begins_with("%d_" % me) or (not NetworkManager.is_multiplayer_active and flower_id.begins_with("0_"))


func _pick_up(body: Node) -> void:
	_picked = true
	var heal_amount: float = _current_heal_amount()
	var own: bool = _is_own_flower()
	if own:
		BalanceLogScript.on_util("s:oakley_cicek", "flower", 1.0)
	if "health" in body and "max_health" in body:
		if own:
			BalanceLogScript.on_gain("s:oakley_cicek", minf(heal_amount, float(body.max_health) - float(body.health)), 0.0)
		body.health = min(body.max_health, body.health + heal_amount)
		if body.has_signal("health_changed"):
			body.health_changed.emit(body.health, body.max_health)
	## DÜZELTME (kullanıcı isteği: "can vermesiyle beraber aynı zamanda ...
	## kalkan yenilemeli") - can ile AYNI anda, ayrı bir kalkan miktarı.
	if "item_shield_hp" in body and "item_shield_max" in body and float(body.item_shield_max) > 0.0:
		var shield_amount: float = _current_shield_amount(body)
		if own:
			BalanceLogScript.on_gain("s:oakley_cicek", 0.0, minf(shield_amount, float(body.item_shield_max) - float(body.item_shield_hp)))
		body.item_shield_hp = min(body.item_shield_max, body.item_shield_hp + shield_amount)
		if body.has_signal("item_shield_changed"):
			body.item_shield_changed.emit(body.item_shield_hp, body.item_shield_max)
	if body.has_method("apply_temp_speed_boost"):
		body.call("apply_temp_speed_boost", PICKUP_SPEED_BONUS, PICKUP_SPEED_DURATION)
	if body.has_method("_spawn_floating_text"):
		body.call("_spawn_floating_text", "+%d" % int(round(heal_amount)), Color(0.5, 1.0, 0.5))
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_flower_picked.rpc(flower_id)
	queue_free()


## network_manager.gd broadcast_flower_picked alıcı tarafta (BAŞKA bir
## istemcide alınmış çiçeğin bu istemcideki kopyasını kaldırmak için) çağırır.
func remove_remotely() -> void:
	if _picked:
		return
	_picked = true
	if _is_own_flower(): ## Oakley'nin çiçeğini bir dost aldı (Shift ipucu "BU OYUNDA")
		BalanceLogScript.on_util("s:oakley_cicek", "flower", 1.0)
	queue_free()
