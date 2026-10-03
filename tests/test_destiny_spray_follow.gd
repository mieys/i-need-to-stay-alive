extends Node

## Kullanıcı bildirimi (2026-09-30): "ejder nefesi efsunundaki ateş ve buz püskürtme efekti silahı takip etmiyor, konumu
## yanlış". Kök neden: Destiny her tikte koni sprite'ını silah KÖKÜNDEN (asanın ortası) dünyaya SABİT bırakıyordu - 0,25
## sn ömrü boyunca oyuncu/asa hareket edince geride kalıyordu; asa da efsunun değil kendi hedefine bakıyordu.
## Bu test GERÇEK oyuncu + gerçek asa (yerel) ve gerçek RemotePlayer kuklası (uzak) ile şunları denetler:
##  - sprite asanın kök düğümüne bağlı ve asanın ÇİZİLİ UCUNDA (weapon_tip.gd), kökte değil
##  - oyuncu yer değiştirince sprite asanın yeni ucunda
##  - asa efsunun hedefine bakıyor, sprite'ın dünya ölçeği tasarımdaki gibi (ebeveyn ölçeği telafi edilmiş)
##  - uzak kukla: aynı veri kuklanın asa kopyasına bağlanıyor, yön yayınlanan açı

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const SpriteFx := preload("res://scripts/fx_enchant_sprite.gd")
const WeaponTip := preload("res://scripts/weapon_tip.gd")
const FAKE_PEER_ID := 4343

var _sprays: Array = []


class FakeMain extends Node2D:
	var puppet: RemotePlayer = null

	func _get_or_spawn_remote_player(_peer_id: int, _allow_spawn: bool = true) -> RemotePlayer:
		return puppet


func _on_node_added(n: Node) -> void:
	if n.get_script() != null and str(n.get_script().resource_path).ends_with("fx_enchant_sprite.gd"):
		_sprays.append(n)


func _full(id: String, final: bool) -> Dictionary:
	var ups: Array = []
	for i in range((EnchantDefs.get_def(id)["upgrades"] as Array).size()):
		ups.append(i)
	return {"id": id, "ups": ups, "final": final}


## Gerçek süre kadar bekler; oyuncunun seviye/kart ekranları ağacı duraklatabilir (test_new_enchants ile aynı önlem).
func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await get_tree().process_frame
		get_tree().paused = false


func _latest_spray(prefix: String) -> Node2D:
	for i in range(_sprays.size() - 1, -1, -1):
		var n: Node = _sprays[i]
		if is_instance_valid(n) and str(n.get("sheet")).begins_with(prefix):
			return n as Node2D
	return null


func test_local_spray_follows_staff_tip() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var prev_weapons: Array = GameManager.owned_weapons.duplicate(true)
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = 1
	GameManager.selected_character = int(Characters.DEFS[1]["skill"])
	var p: Node2D = PlayerScene.instantiate()
	p.scale = Vector2(0.5, 0.5) ## main.tscn Player ölçeği - asanın kafa üstü süzülme ofseti buna göre
	add_child(p)
	p.global_position = Vector2(2000.0, 2000.0)
	p.max_health = 100000.0
	p.health = 100000.0
	for w0 in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w0):
			w0.queue_free()
	p.owned_weapon_nodes.clear()
	for key in ["fire_staff", "buz_asasi"]:
		for final in [false, true]:
			for w1 in p.owned_weapon_nodes.duplicate():
				w1.free()
			p.owned_weapon_nodes.clear()
			GameManager.owned_weapons = [{"key": key, "level": 1, "enchant": _full("destiny", final)}]
			assert(p.buy_weapon_copy(key, 1), "asa verilemedi")
			var w: Node2D = p.owned_weapon_nodes[0]
			var icon: Sprite2D = w.get("icon_sprite")
			var fwd: float = float(w.get("sprite_forward_angle_deg"))
			await _wait(0.15) ## asa kafa üstündeki yerine süzülsün
			var e: Node2D = EnemyScene.instantiate()
			add_child(e)
			e.global_position = w.global_position + Vector2(70.0, 25.0)
			e.set("speed", 0.0)
			e.max_health = 60000.0
			e.health = 60000.0
			_sprays.clear()
			get_tree().node_added.connect(_on_node_added)
			## 2026-10-03 alev sanatı: TEK sürekli döngülü alev flame_fire / flame_ice (eski 6 karelik spray_*[_big] sayfaları kalktı;
			## final "_big" sayfa yerine menzil x2 + yan yana alt alevler) - 2026-10-03 test güncellemesi.
			var prefix: String = "flame_ice" if key == "buz_asasi" else "flame_fire"
			## Asa nişanına yerleşsin (yumuşak dönüş), sonra taze bir tikin sprite'ını incele.
			await _wait(0.6)
			var s: Node2D = _latest_spray(prefix)
			assert(s != null, "%s: süren püskürtme yok" % key)
			assert(str(s.get("sheet")) == prefix, "%s final=%s: sayfa %s" % [key, final, s.get("sheet")])
			assert(s.get_parent() == w, "%s: sprite asanın köküne bağlı olmalı, ebeveyn: %s" % [key, s.get_parent()])
			var tip: Vector2 = WeaponTip.tip_global(icon, fwd)
			assert(s.global_position.distance_to(tip) < 1.0, "%s: sprite asanın ucunda olmalı (%s / uç %s)" % [key, s.global_position, tip])
			assert(tip.distance_to(w.global_position) > 5.0, "%s: uç asanın ortasından (kökten) ayrı olmalı: %.1f" % [key, tip.distance_to(w.global_position)])
			var spr: Node2D = s.get_node("Sprite") as Node2D
			var want: Vector2 = Vector2(s.get("sprite_scale")) * SpriteFx.TEXEL
			assert(absf(spr.global_scale.x - want.x) < 0.02 and absf(spr.global_scale.y - want.y) < 0.02,
				"%s: dünya ölçeği %s, beklenen %s (ebeveyn ölçeği telafi)" % [key, spr.global_scale, want])
			## Asa efsunun hedefine döner (tik başında zaten bakıyor olmalı).
			var aim_dir: Vector2 = icon.global_transform.basis_xform(Vector2.from_angle(deg_to_rad(fwd))).normalized()
			var to_e: Vector2 = (e.global_position - tip).normalized()
			assert(absf(aim_dir.angle_to(to_e)) < deg_to_rad(20.0), "%s: asa hedefe bakmıyor (%.1f°)" % [key, rad_to_deg(aim_dir.angle_to(to_e))])
			## Oyuncu yer değiştirir: sprite ömrü içinde asanın YENİ ucunda olmalı (eskiden eski yerde kalıyordu).
			var start: Vector2 = s.global_position
			p.global_position += Vector2(40.0, -30.0)
			await _wait(0.06)
			if is_instance_valid(s):
				var tip2: Vector2 = WeaponTip.tip_global(icon, fwd)
				assert(s.global_position.distance_to(tip2) < 1.0, "%s: hareket sonrası uçta değil (%s / %s)" % [key, s.global_position, tip2])
				assert(s.global_position.distance_to(start) > 5.0, "%s: sprite oyuncuyla birlikte gitmedi" % key)
			get_tree().node_added.disconnect(_on_node_added)
			e.queue_free()
			p.global_position = Vector2(2000.0, 2000.0)
			await get_tree().process_frame
	p.queue_free()
	GameManager.owned_weapons = prev_weapons
	await get_tree().process_frame
	if prev_scene != null and is_instance_valid(prev_scene) and prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = prev_scene


func test_remote_copy_attaches_to_puppet_staff() -> void:
	var prev_scene: Node = get_tree().current_scene
	var fake_main := FakeMain.new()
	get_tree().root.add_child(fake_main)
	get_tree().current_scene = fake_main
	var puppet: RemotePlayer = RemotePlayerScene.instantiate()
	puppet.peer_id = FAKE_PEER_ID
	fake_main.add_child(puppet)
	fake_main.puppet = puppet
	puppet.global_position = Vector2(500.0, 400.0)
	puppet.update_weapon_visuals(["dagger", "fire_staff"])
	var info: Array = puppet.get_weapon_icon_info(1)
	assert(info.size() == 2, "kuklanın 2. slot ikonu bulunamadı")
	var icon: Sprite2D = info[0]
	assert(str(icon.texture.resource_path).contains("fire"), "slot 1 ateş asası olmalı: %s" % icon.texture.resource_path)
	var was_mp: bool = NetworkManager.is_multiplayer_active
	NetworkManager.is_multiplayer_active = true ## spawn RPC atmaz; sadece "bu sahibin kuklası" yolunu seçtirir
	var n: Node2D = SpriteFx.spawn(get_tree(), Vector2(9999.0, 9999.0), {"sheet": "spray_fire", "follow_slot": 1,
		"follow_peer": FAKE_PEER_ID, "rot": 0.3, "offset": Vector2(44.0, 0.0), "z": 9})
	NetworkManager.is_multiplayer_active = was_mp
	assert(n != null and n.get_parent() == puppet, "uzak kopya kuklaya bağlanmalı, ebeveyn: %s" % (n.get_parent() if n else null))
	var tip: Vector2 = WeaponTip.tip_global(icon, float(info[1]))
	assert(n.global_position.distance_to(tip) < 1.0, "uzak kopya asa ucunda olmalı: %s / %s" % [n.global_position, tip])
	assert(absf(angle_difference(n.global_rotation, 0.3)) < 0.01, "yön yayınlanan açı olmalı: %.3f" % n.global_rotation)
	puppet.global_position += Vector2(-60.0, 20.0)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(n):
		var tip2: Vector2 = WeaponTip.tip_global(icon, float(info[1]))
		assert(n.global_position.distance_to(tip2) < 1.0, "kukla hareket edince kopya uçta kalmalı")
	## Silah bulunamazsa eski davranış: dünyada verilen konumda.
	var lost: Node2D = SpriteFx.spawn(get_tree(), Vector2(123.0, 45.0), {"sheet": "spray_fire", "follow_slot": 7, "follow_peer": 0})
	assert(lost != null and lost.get_parent() == fake_main and lost.global_position.is_equal_approx(Vector2(123.0, 45.0)),
		"silah yoksa sabit konuma düşmeli")
	fake_main.queue_free()
	await get_tree().process_frame
	if prev_scene != null and is_instance_valid(prev_scene):
		get_tree().current_scene = prev_scene
