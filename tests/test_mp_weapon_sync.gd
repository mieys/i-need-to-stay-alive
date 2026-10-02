extends Node

## 2026-09-30 çok oyunculu silah senkron analizi - bulunan ve düzeltilen hatalar (kaster doğru görür, diğerleri yanlış):
##  1) Kalıcı efsun alanları (kara delik, ok yağmuru, Zeus ışını, yarık/iz, lav/buz zemini, kozmik disk, Astral, shuriken)
##     ve "area_end" UNRELIABLE kanaldan gidiyordu - tek kayıp paket alanı diğer oyuncuda hiç göstermiyor / asılı bırakıyordu.
##  2) Seken Mermiler: kasterde mermi düşmandan düşmana sekerken uzak kopya düz uçup düşmanların içinden geçiyordu.
##  3) Güdümlü mermiler (Prizm kopyaları): uzak kopya düz uçuyordu.
##  4) broadcast_weapon_attack (kozmetik yakın dövüş savuruşu, her vuruşta) reliable'dı - paket kaybında aynı kanaldaki
##     hasar isteklerini bekletiyordu.
## Alıcı tarafı gerçek mermi sahnesi + gerçek yaratıkla (NetworkManager.broadcast_projectile doğrudan çağrılır), kanal
## ayarları kaynaktan denetlenir. Gerçek iki süreçli doğrulama bu dosyada değil.

const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const PROJ := "res://scenes/ice_bolt_projectile.tscn"


func _rpc_mode(src: String, func_name: String) -> String:
	var i: int = src.find("func %s(" % func_name)
	assert(i > 0, "fonksiyon yok: %s" % func_name)
	var head: String = src.substr(0, i)
	var j: int = head.rfind("@rpc(")
	return head.substr(j, head.find(")", j) - j + 1)


func test_channels() -> void:
	var nm: String = FileAccess.get_file_as_string("res://scripts/network_manager.gd")
	assert(_rpc_mode(nm, "broadcast_enchant_area").contains("\"reliable\""), "efsun alanı güvenilir kanaldan gitmeli")
	assert(_rpc_mode(nm, "broadcast_enchant_fx").contains("\"unreliable\""), "kısa görseller unreliable kalmalı")
	assert(_rpc_mode(nm, "broadcast_weapon_attack").contains("\"unreliable\""), "yakın dövüş savuruş görseli unreliable olmalı")
	var fx: String = FileAccess.get_file_as_string("res://scripts/enchant_fx.gd")
	assert(fx.contains("kind == \"area\" or kind == \"area_end\"") and fx.contains("broadcast_enchant_area.rpc"),
		"EnchantFx.play alan/alan bitişini güvenilir kanala yollamalı")
	var ar: String = FileAccess.get_file_as_string("res://scripts/enchant_area.gd")
	assert(ar.contains("broadcast_enchant_area.rpc(\"area\"") and not ar.contains("broadcast_enchant_fx.rpc(\"area\""),
		"EnchantArea.spawn güvenilir kanalı kullanmalı")
	var beh: String = FileAccess.get_file_as_string("res://scripts/enchant_behavior.gd")
	assert(beh.contains("weapon.broadcast_projectile_redirect(proj, dir"), "sekme uzak ekranlara yeni kopya yayınlamalı")


func test_bounce_not_counted_as_visual_pierce() -> void:
	var st: Dictionary = EnchantDefs.resolve({"id": "seken_mermiler", "ups": [0, 1, 2, 3], "final": false})
	assert(int(st.get("bounce", 0)) >= 4, "sekme sayısı: %s" % st.get("bounce"))
	var b: Node = (load("res://scripts/enchants/seken_mermiler.gd") as GDScript).new()
	b.set("stats", st)
	var look: Dictionary = b.call("projectile_look", null)
	assert(not look.has("pierce"), "sekme uzak kopyanın delme sayısına eklenmemeli: %s" % str(look))
	b.free()


func _spawn_copy(from: Vector2, dir: Vector2, look: Dictionary) -> Node2D:
	var before: Array = get_children()
	NetworkManager.broadcast_projectile(PROJ, from, dir, 0.0, Vector2.ONE, Vector2.ZERO, 0, look)
	for c in get_children():
		if not before.has(c) and c.get_meta("network_spawned", false):
			return c as Node2D
	return null


func _enemy(at: Vector2, net_id: int) -> Node2D:
	var e: Node2D = EnemyScene.instantiate()
	add_child(e)
	e.global_position = at
	e.set("speed", 0.0)
	e.max_health = 60000.0
	e.health = 60000.0
	e.set_meta("network_enemy_id", net_id)
	NetworkManager._enemies_by_net_id[net_id] = e
	return e


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await get_tree().physics_frame
		get_tree().paused = false


func test_remote_copy_homes_and_bounce_copy_skips_spawn_enemy() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var was_mp: bool = NetworkManager.is_multiplayer_active
	NetworkManager.is_multiplayer_active = false
	## Güdüm: yukarı fırlatılan kopya sağdaki hedefe döner; güdümsüz kontrol kopyası dönmez.
	var tgt: Node2D = _enemy(Vector2(900.0, 500.0), 99101)
	var homing: Node2D = _spawn_copy(Vector2(500.0, 500.0), Vector2(0.0, -1.0), {"home_id": 99101})
	var plain: Node2D = _spawn_copy(Vector2(500.0, 700.0), Vector2(0.0, -1.0), {})
	assert(homing != null and plain != null, "uzak kopyalar doğmadı")
	await _wait(0.25)
	if is_instance_valid(homing):
		var to_t: Vector2 = (tgt.global_position - homing.global_position).normalized()
		assert(Vector2(homing.get("direction")).dot(to_t) > 0.8, "güdümlü uzak kopya hedefe dönmedi: %s" % homing.get("direction"))
	if is_instance_valid(plain):
		assert(Vector2(plain.get("direction")).is_equal_approx(Vector2(0.0, -1.0)), "güdümsüz kopya yön değiştirmemeli")
	for c in get_children():
		c.queue_free()
	await get_tree().physics_frame
	## Sekme kopyası: A'nın içinde doğar (kasterdeki sekme noktası), A'yı delip B'de biter.
	var a: Node2D = _enemy(Vector2(500.0, 500.0), 99102)
	var bn: Node2D = _enemy(Vector2(620.0, 500.0), 99103)
	var cp: Node2D = _spawn_copy(a.global_position, Vector2.RIGHT, {"pierce": 1})
	assert(cp != null, "sekme kopyası doğmadı")
	await _wait(0.08)
	assert(is_instance_valid(cp) and not bool(cp.get("_impacted")), "sekme kopyası doğduğu düşmanda bitmemeli")
	await _wait(1.0)
	assert(not is_instance_valid(cp) or bool(cp.get("_impacted")), "sekme kopyası sonraki düşmanda bitmeli")
	## Delmesiz sıradan uzak kopya ilk düşmanda biter (uzakta sekme artık yeni kopyalarla çizilir).
	var plain2: Node2D = _spawn_copy(a.global_position + Vector2(-120.0, 0.0), Vector2.RIGHT, {})
	await _wait(0.5)
	assert(not is_instance_valid(plain2) or bool(plain2.get("_impacted")), "delmesiz kopya ilk düşmanda bitmeli")
	for id in [99101, 99102, 99103]:
		NetworkManager._enemies_by_net_id.erase(id)
	for c in get_children():
		c.queue_free()
	NetworkManager.is_multiplayer_active = was_mp
	await get_tree().physics_frame
	if prev_scene != null and is_instance_valid(prev_scene) and prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = prev_scene
