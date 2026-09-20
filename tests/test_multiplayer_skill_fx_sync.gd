extends Node

## Çok oyunculu senkron testi sırasında bulunan hata (CLAUDE.md "kaster görür, diğerleri görmez" sınıfı):
## _play_and_broadcast_skill_fx uzak kopyanın konumunu HER ZAMAN Vector2.ZERO'ya eziyordu, ama Life/Mana
## Recovery aura sahneleri (0, 30) ofsetiyle çiziliyor -> kaster halkayı ayağının altında, diğer oyuncular
## 30 birim yukarıda görüyordu. Bu test hem gönderici (kaster kendi kopyasının gerçek konumunu yollar)
## hem alıcı (broadcast_player_vfx "skill_scene" konumu uygular) tarafını denetler.
## Gerçek iki süreçli (host + client, ENet) doğrulama ayrıca elle koşuldu; bu dosya onun hızlı, tek
## süreçli regresyon koruması.

const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const LIFE_SCENE := "res://scenes/fx_recovery_life.tscn"
const MANA_SCENE := "res://scenes/fx_recovery_mana.tscn"
const FAKE_PEER_ID := 4242


## Sahne ağacında current_scene gibi davranan, sadece bir RemotePlayer döndüren sahte "Main".
class FakeMain extends Node2D:
	var puppet: RemotePlayer = null

	func _get_or_spawn_remote_player(_peer_id: int, _allow_spawn: bool = true) -> RemotePlayer:
		return puppet


func _strip_comments(src: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	for line: String in src.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		var idx: int = line.find("#")
		out.append(line.substr(0, idx) if idx != -1 else line)
	return "\n".join(out)


func _function_body(src: String, start_marker: String, end_marker: String) -> String:
	var start: int = src.find(start_marker)
	var end: int = src.find(end_marker, start + 1)
	assert(start != -1 and end > start, "fonksiyon bulunamadı: %s" % start_marker)
	return _strip_comments(src.substr(start, end - start))


## Gönderici: uzak kopyaya kasterin KENDİ kopyasının gerçek konumu yollanmalı, sabit ZERO değil.
func test_sender_forwards_the_fx_own_position_not_a_hardcoded_zero() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	var body: String = _function_body(src, "func _play_and_broadcast_skill_fx(", "func _spawn_burst(")
	assert(not body.contains('"position": Vector2.ZERO'),
		"_play_and_broadcast_skill_fx uzak kopyanın konumunu Vector2.ZERO'ya eziyor (ofsetli aura'lar kayar)")
	assert(body.contains("(fx as Node2D).position"),
		"_play_and_broadcast_skill_fx kasterin kendi FX konumunu (fx.position) göndermeli")


## Kaynak sahnelerin gerçekten ofsetli olduğunu bilelim (yukarıdaki düzeltmenin gerekçesi bozulmasın).
func test_recovery_aura_scenes_are_drawn_at_the_ground_offset() -> void:
	for path: String in [LIFE_SCENE, MANA_SCENE]:
		var fx: Node2D = (load(path) as PackedScene).instantiate() as Node2D
		assert(fx.position.is_equal_approx(Vector2(0.0, 30.0)), "%s (0,30) ofsetiyle çizilmeli: %s" % [path, str(fx.position)])
		fx.free()


## Alıcı: gelen konum uzak kopyaya uygulanmalı ve aura kuklaya kayıtlı olmalı (erken iptalde durdurulabilsin).
func test_receiver_applies_forwarded_offset_and_registers_the_aura() -> void:
	var previous_scene: Node = get_tree().current_scene
	var fake_main := FakeMain.new()
	get_tree().root.add_child(fake_main) ## current_scene sadece kök pencerenin doğrudan çocuğu olabilir
	get_tree().current_scene = fake_main
	var puppet: RemotePlayer = RemotePlayerScene.instantiate()
	puppet.peer_id = FAKE_PEER_ID
	fake_main.add_child(puppet)
	fake_main.puppet = puppet

	for entry: Array in [[LIFE_SCENE, "heal"], [MANA_SCENE, "shield"]]:
		var path: String = entry[0]
		var key: String = entry[1]
		var local_copy: Node2D = (load(path) as PackedScene).instantiate() as Node2D
		var sent_position: Vector2 = local_copy.position ## gönderici bunu yollar (bkz. yukarıdaki test)
		local_copy.free()
		NetworkManager.broadcast_player_vfx(FAKE_PEER_ID, "skill_scene", Vector2.ZERO, {
			"scene_path": path,
			"position": sent_position
		})
		var remote_copy: Node2D = null
		for c: Node in puppet.get_children():
			if c.scene_file_path == path:
				remote_copy = c as Node2D
		assert(remote_copy != null, "%s uzak kopyası kukla üstünde oluşmalı" % path)
		assert(remote_copy.position.is_equal_approx(Vector2(0.0, 30.0)),
			"%s uzak kopyası kasterle aynı konumda olmalı: %s" % [path, str(remote_copy.position)])
		assert(puppet._ally_aura_fx.has(key) and puppet._ally_aura_fx[key] == remote_copy,
			"%s uzak kopyası kuklanın _ally_aura_fx['%s'] kaydında olmalı" % [path, key])
		## erken iptal: broadcast_ally_aura_stop kopyayı gerçekten durdurmalı (kasterde kapanıp diğerinde kalmasın)
		puppet.stop_ally_aura_fx(key)
		assert(not puppet._ally_aura_fx.has(key), "durdurulunca kayıt silinmeli")
		assert(remote_copy._stopping, "durdurulan uzak kopya sönmeye geçmeli (stop_aura)")
		remote_copy.free()

	get_tree().current_scene = previous_scene
	fake_main.free()
