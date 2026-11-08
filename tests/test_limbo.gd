extends Node

## Madde 438 (2026-11-07): RUH HÂLİ - level/pazar/sandık menüsündeki oyuncu donar (aktif süreler dahil), dokunulmazdır, mavi ruh görünür;
## dünyaya bıraktığı (sahibi alanından ya da açık etiketten bulunan) düğümler de donar. Menüden dönünce hepsi kaldığı yerden devam eder.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const LimboScript := preload("res://scripts/limbo.gd")
const LimboFxScript := preload("res://scripts/limbo_fx.gd")

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1


func _make_player(char_id: int = 1) -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = char_id
	GameManager.selected_character = Characters.get_def(char_id)["skill"]
	NetworkManager.is_multiplayer_active = false
	GameManager.merchant_zone_active = false
	var player: Node = PlayerScene.instantiate()
	get_tree().current_scene.add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(1000.0, 1000.0)
	player._last_damage_taken_at_msec = -999999
	return player


func _owned_node(field: StringName, value: Variant) -> Node2D:
	var scr := GDScript.new()
	scr.source_code = "extends Node2D\nvar %s\n" % String(field)
	scr.reload()
	var n := Node2D.new()
	n.set_script(scr)
	n.set(field, value)
	get_tree().current_scene.add_child(n)
	_spawned.append(n)
	return n


func _cleanup() -> void:
	LimboScript.reset()
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func test_limbo_freezes_player_and_makes_it_untouchable() -> void:
	var player: Node = _make_player()
	var hp0: float = player.health
	var shadow: CanvasItem = player.get_node("Shadow") as CanvasItem
	var shadow_vis0: bool = shadow.visible
	player.set_limbo(true)
	assert(player.process_mode == Node.PROCESS_MODE_DISABLED, "ruh hâlinde oyuncu düğümü durur (aktif süreler dahil)")
	assert(player.is_safe_zone_frozen(), "evcil/totem/kafatası is_safe_zone_frozen'dan donar")
	assert(player.anim.process_mode == Node.PROCESS_MODE_ALWAYS, "okuma klibi oynasın diye sprite ALWAYS")
	player.take_damage(50.0)
	assert(is_equal_approx(player.health, hp0), "ruh hâlinde hasar yok: %s" % player.health)
	player.apply_stun(2.0)
	assert(not player.is_stunned, "ruh hâlinde sersemletme yok")
	player.apply_knockback_force(Vector2.RIGHT, 500.0)
	assert(player._knockback_velocity == Vector2.ZERO, "ruh hâlinde itme yok")
	player.health = hp0 - 20.0
	player.heal(10.0, false)
	assert(is_equal_approx(player.health, hp0 - 20.0), "ruh hâlinde can basılmaz")
	for w in player.owned_weapon_nodes:
		assert(not w.visible, "silahlar gizli")
	var fx: Node = player.get_node_or_null(LimboFxScript.NODE_NAME)
	assert(fx != null, "mavi ruh görseli kuruldu")
	assert(not shadow.visible, "ruh hâlinde ayak gölgesi yok (kullanıcı: hayalet olsun ama gölge olmamalı)")
	player.set_limbo(false)
	assert(player.process_mode == Node.PROCESS_MODE_INHERIT, "dönünce oyuncu yeniden işler")
	assert(not player.is_safe_zone_frozen(), "dönünce zaman akar")
	assert(player.anim.process_mode == Node.PROCESS_MODE_INHERIT, "sprite eski moduna döner")
	assert(player.anim.visible, "asıl sprite yeniden görünür")
	assert(shadow.visible == shadow_vis0, "dönünce gölge eski hâline döner")
	for w in player.owned_weapon_nodes:
		assert(w.visible, "silahlar geri gelir")
	player.take_damage(10.0)
	assert(player.health < hp0 - 20.0 + 0.001, "dönünce yeniden hasar alır")
	_cleanup()


func test_world_nodes_of_limbo_owner_freeze_and_resume() -> void:
	var player: Node = _make_player()
	var me: int = LimboScript.local_peer()
	var totem: Node2D = _owned_node(&"caster", player)
	var pet: Node2D = _owned_node(&"owner_body", player)
	var tagged := Node2D.new()
	LimboScript.own(tagged, me)
	get_tree().current_scene.add_child(tagged)
	_spawned.append(tagged)
	var stranger := Node2D.new()
	_spawned.append(stranger)
	var other: Node2D = _owned_node(&"caster", stranger) ## oyuncu olmayan sahip (yaratık mermisi gibi) donmaz
	var foe: Node2D = _owned_node(&"owner_player", player)
	foe.add_to_group("enemies") ## Kopyanı Öldür kopyası gibi düşmanlar sahip alanı taşısa da donmaz
	var prev_totem: int = totem.process_mode
	LimboScript.apply(get_tree(), {me: true})
	assert(totem.process_mode == Node.PROCESS_MODE_DISABLED, "sahibi ruh hâlindeki totem donar")
	assert(pet.process_mode == Node.PROCESS_MODE_DISABLED, "evcil (owner_body) donar")
	assert(tagged.process_mode == Node.PROCESS_MODE_DISABLED, "açık etiketli düğüm donar")
	assert(other.process_mode != Node.PROCESS_MODE_DISABLED, "sahibi oyuncu olmayan düğüm donmaz")
	assert(foe.process_mode != Node.PROCESS_MODE_DISABLED, "düşman grubundakiler donmaz")
	assert(player.process_mode != Node.PROCESS_MODE_DISABLED, "oyuncunun kendisi limbo.gd'de değil set_limbo'da yönetilir")
	LimboScript.apply(get_tree(), {})
	assert(totem.process_mode == prev_totem, "sahip dönünce totem eski moduna döner")
	assert(not LimboScript.is_frozen(pet) and not LimboScript.is_frozen(tagged), "hepsi çözülür")
	_cleanup()


func test_node_spawned_while_owner_in_limbo_freezes_next_frame() -> void:
	var player: Node = _make_player()
	var me: int = LimboScript.local_peer()
	get_tree().current_scene.child_entered_tree.connect(LimboScript.on_child_added)
	LimboScript.apply(get_tree(), {me: true})
	var bomb: Node2D = _owned_node(&"owner_player", player)
	await get_tree().process_frame
	assert(bomb.process_mode == Node.PROCESS_MODE_DISABLED, "ruh hâlindeyken doğan düğüm de donar (alan add_child'dan sonra yazılsa bile)")
	get_tree().current_scene.child_entered_tree.disconnect(LimboScript.on_child_added)
	_cleanup()



## Kullanıcı 2026-11-07: "level atladıktan sonra oyun devam edince karakter görünmez oldu" - LimboFx silinmeden önceki son karesinde
## (queue_free kare sonunda) _process asıl sprite'ı / gölgeyi yeniden gizliyordu; geri yükleme kilidi _exit_tree'deki düzeltmeyi de engelliyordu.
func test_character_visible_after_frames_once_limbo_ends() -> void:
	var player: Node = _make_player()
	var shadow: CanvasItem = player.get_node("Shadow") as CanvasItem
	var shadow_vis0: bool = shadow.visible
	player.set_limbo(true)
	await get_tree().process_frame
	await get_tree().process_frame
	player.set_limbo(false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(player.anim.visible, "ruh hâli bittikten kareler sonra karakter görünür olmalı")
	assert(shadow.visible == shadow_vis0, "ruh hâli bittikten kareler sonra gölge eski hâlinde olmalı")
	assert(player.get_node_or_null("LimboFx") == null, "ruh görseli silinmiş olmalı")
	## art arda ikinci seviye (aynı karede bitip yeniden başlama) da düzgün: yeniden ruh, sonra yine görünür
	player.set_limbo(true)
	player.set_limbo(false)
	player.set_limbo(true)
	await get_tree().process_frame
	player.set_limbo(false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(player.anim.visible, "art arda ruh hâlinden sonra da karakter görünür")
	_cleanup()
