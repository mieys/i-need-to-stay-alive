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

## NOT: eskiden burada _draw() ile çizilen yumuşak (vektör) bir yeşil halka +
## dönen kıvılcımlar vardı ("çiçeklerin üstüne sihirli yeşil bir efekt koy,
## haritadaki diğer çiçeklerden farkı belli olsun" isteği). Yerine pixel-art
## Life Recovery çemberi geçti (bkz. _ready() ve FlowerRecoveryFxScene) - aynı
## amacı (çiçeği sıradan dekordan ayırmak) görüntü diliyle uyumlu şekilde
## karşılıyor, ikisi üst üste binince yumuşak halka piksel efektle çelişiyordu.

## DÜZELTME (kullanıcı isteği: "efekt sistemi" - Oakley'nin çiçek yeteneğinin
## 3 dönüşümü için gerçek bir sprite eklendi) - eskiden burada gerçek sanat
## eseri olmadığı için basit bir sarı Polygon2D çiziliyordu (bkz. yorum
## geçmişi). Artık fx_oakley_flower_stages_frames.tres'teki 3 kare
## (stage0/1/2, soldan sağa) kullanılıyor - _growth_stage (0,1,2) hangi
## karenin gösterileceğini doğrudan belirliyor, "stage%d" adlandırması bunun
## için seçildi.
const FlowerStagesFrames := preload("res://assets/generated/fx_oakley_flower_stages_frames.tres")
## bkz. _ready() - çiçeğin altında sürekli dönen Life Recovery büyü çemberi.
const FlowerRecoveryFxScene := preload("res://scenes/fx_recovery_life_flower.tscn")


func _ready() -> void:
	add_to_group("oakley_flowers")
	z_index = 5
	## Kullanıcı isteği (CraftPix Life Recovery): "oakleyin bitkisinin üstünde de
	## sürekli aktif olacak bu efekt alınana kadar" - çiçeğin ÇOCUĞU olduğu için
	## çiçek alınınca (_pick_up/remove_remotely -> queue_free) ya da ömrü dolunca
	## kendiliğinden yok olur, ayrıca stop çağırmaya gerek yok. Bu node her
	## istemcide kendi _ready()'sini çalıştırdığı için (bkz. dosya başı AĞ DESENİ)
	## efekt diğer oyuncularda da otomatik görünür, ayrı RPC gerekmez.
	add_child(FlowerRecoveryFxScene.instantiate())
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FlowerStagesFrames
	_sprite.play("stage0")
	add_child(_sprite)


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
		_growth_stage += 1
		_growth_timer = GROWTH_INTERVAL
		if _sprite:
			## Büyüme geri bildirimi: 3 dönüşümün kendi karesine geçiliyor
			## (bkz. FlowerStagesFrames üstündeki DÜZELTME notu).
			_sprite.play("stage%d" % _growth_stage)


func _current_heal_amount() -> float:
	return _caster_damage_bonus * HEAL_RATIO_OF_ATTACK * (1.0 + GROWTH_STAGE_BONUS * _growth_stage)


## bkz. SHIELD_PERCENT_OF_TARGET_MAX üstündeki DÜZELTME notu - can miktarıyla
## AYNI büyüme çarpanını kullanır, ama alanın KENDİ max kalkanına da bağlı
## olduğu için (can'ın aksine) body parametre alıyor.
func _current_shield_amount(body: Node) -> float:
	var target_max_shield: float = float(body.item_shield_max) if "item_shield_max" in body else 0.0
	return (target_max_shield * SHIELD_PERCENT_OF_TARGET_MAX + _caster_damage_bonus * SHIELD_RATIO_OF_ATTACK) \
			* (1.0 + GROWTH_STAGE_BONUS * _growth_stage)


func _pick_up(body: Node) -> void:
	_picked = true
	var heal_amount: float = _current_heal_amount()
	if "health" in body and "max_health" in body:
		body.health = min(body.max_health, body.health + heal_amount)
		if body.has_signal("health_changed"):
			body.health_changed.emit(body.health, body.max_health)
	## DÜZELTME (kullanıcı isteği: "can vermesiyle beraber aynı zamanda ...
	## kalkan yenilemeli") - can ile AYNI anda, ayrı bir kalkan miktarı.
	if "item_shield_hp" in body and "item_shield_max" in body and float(body.item_shield_max) > 0.0:
		var shield_amount: float = _current_shield_amount(body)
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
	queue_free()
