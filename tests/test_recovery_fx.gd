extends Node

## Life/Mana Recovery pixel-art aura'ları (CraftPix "Magic Buff Effects") -
## kullanıcı isteği: Melek'in Can Basma/Kalkan Yenileme'si süresince kendi ve
## hedef dostun üstünde TAM DÖNGÜLÜ (intro/loop/outro YOK) büyü çemberi, ayrıca
## Oakley'nin çiçeğinin üstünde çiçek alınana kadar sürekli aynı efekt.
##
## Kaynak/yol eşleşmesi (CLAUDE.md "iki yerde aynı bilgi" hata sınıfı):
## player.gd VE remote_player.gd aynı sahne yollarını ayrı ayrı preload ediyor.

const LIFE_SCENE := "res://scenes/fx_recovery_life.tscn"
const MANA_SCENE := "res://scenes/fx_recovery_mana.tscn"
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")


func _read(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


func _strip_comments(src: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	for line: String in src.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		var idx: int = line.find("#")
		out.append(line.substr(0, idx) if idx != -1 else line)
	return "\n".join(out)


func _make(path: String) -> AnimatedSprite2D:
	var packed: PackedScene = load(path)
	assert(packed != null, "%s yüklenebilmeli" % path)
	var inst: Node = packed.instantiate()
	assert(inst is AnimatedSprite2D, "%s kökü AnimatedSprite2D olmalı" % path)
	return inst as AnimatedSprite2D


func test_scenes_are_pixel_art_looping_sprites() -> void:
	for path: String in [LIFE_SCENE, MANA_SCENE]:
		var spr: AnimatedSprite2D = _make(path)
		assert(spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"%s pixel-art olmalı (NEAREST), bulunan: %s" % [path, spr.texture_filter])
		assert(spr.sprite_frames != null, "%s SpriteFrames taşımalı" % path)
		assert(spr.sprite_frames.has_animation(&"loop"), "%s 'loop' animasyonu taşımalı" % path)
		assert(spr.sprite_frames.get_frame_count(&"loop") == 12, "%s 12 kare olmalı" % path)
		assert(spr.sprite_frames.get_animation_loop(&"loop"), "%s animasyonu döngülü olmalı" % path)
		assert(spr.sprite_frames.get_animation_names().size() == 1,
			"%s tek animasyon taşımalı (intro/outro yok - tam loop)" % path)
		assert(spr.z_index < 0, "%s karakterin ALTINDA (z_index<0) çizilmeli" % path)
		spr.free()


func test_life_and_mana_use_different_art_and_aura_keys() -> void:
	var life: AnimatedSprite2D = _make(LIFE_SCENE)
	var mana: AnimatedSprite2D = _make(MANA_SCENE)
	assert(life.aura_type == "heal", "Life 'heal' anahtarını kullanmalı (player.gd _ally_aura_fx)")
	assert(mana.aura_type == "shield", "Mana 'shield' anahtarını kullanmalı (player.gd _ally_aura_fx)")
	assert(life.sprite_frames != mana.sprite_frames, "Life ve Mana farklı sprite'lar olmalı")
	life.free()
	mana.free()


## CLAUDE.md hata sınıfı: iki dosya aynı efekti ayrı kuruyor. 2026-10-17 (madde 212): Melek Q/E dost aurası artık SİHİRLİ
## BAĞ (melek_bond_fx.gd) - iki dosya da onu kurmalı, Life/Mana Recovery aura'ları (Oakley çiçeğinde kaldı) Melek'te kullanılmaz.
func test_player_and_remote_player_reference_the_bond_and_no_old_auras() -> void:
	for path: String in ["res://scripts/player.gd", "res://scripts/remote_player.gd"]:
		var src: String = _strip_comments(_read(path))
		assert(src.contains("melek_bond_fx.gd"), "%s Melek bağını kurmalı" % path)
		assert(not src.contains("fx_recovery_life.tscn"), "%s Melek için Life aurası kalmamalı" % path)
		assert(not src.contains("fx_recovery_mana.tscn"), "%s Melek için Mana aurası kalmamalı" % path)
		assert(not src.contains("fx_melek_heal_aura.tscn"), "%s eski heal aura sahnesine referans vermemeli" % path)
		assert(not src.contains("fx_melek_shield_aura.tscn"), "%s eski shield aura sahnesine referans vermemeli" % path)


## Tam loop: hiç durdurulmadıkça (max_lifetime altında) kareler kesintisiz döner,
## alfa 1'de kalır, kapanış (outro) davranışı başlamaz.
func test_aura_loops_at_full_opacity_until_stopped() -> void:
	var fx: AnimatedSprite2D = _make(LIFE_SCENE)
	add_child(fx)
	assert(fx.is_playing() and fx.animation == &"loop", "efekt 'loop' animasyonunu oynatmalı")
	for i in 40:  ## 40 x 0.1 = 4 sn < max_lifetime
		fx._process(0.1)
	assert(is_equal_approx(fx.modulate.a, 1.0), "durdurulmadıkça tam opak kalmalı, alfa: %s" % fx.modulate.a)
	assert(not fx.is_queued_for_deletion(), "durdurulmadıkça silinmemeli")
	fx.stop_aura()
	fx._process(0.1)
	assert(fx.modulate.a < 1.0 and not fx.is_queued_for_deletion(), "stop_aura sonrası kısa bir sönme olmalı")
	fx._process(0.5)
	assert(fx.is_queued_for_deletion(), "sönme bitince kendini silmeli")
	fx.queue_free()


func test_safety_timeout_removes_orphaned_copy() -> void:
	var fx: AnimatedSprite2D = _make(MANA_SCENE)
	add_child(fx)
	assert(fx.max_lifetime > 6.0, "güvenlik süresi yeteneğin 6 sn'sinden uzun olmalı")
	for i in int(fx.max_lifetime / 0.5) + 2:
		fx._process(0.5)
	fx._process(1.0)
	assert(fx.is_queued_for_deletion(), "durdurma hiç gelmese de güvenlik süresi sonunda silinmeli")
	fx.queue_free()


## Melek'in KENDİ üstündeki aura ağda "skill_scene" olarak yayınlanıp uzakta
## rp.add_child() ile ekleniyor (bkz. network_manager.gd) - RemotePlayer'ın
## _ally_aura_fx sözlüğüne kendini yazmazsa "durdur" RPC'si onu bulamaz.
func test_remote_self_cast_copy_can_be_stopped_by_stop_ally_aura_fx() -> void:
	var rp: Node = RemotePlayerScene.instantiate()
	add_child(rp)
	rp.setup(9, 10, "test")
	var fx: AnimatedSprite2D = load(LIFE_SCENE).instantiate()
	rp.add_child(fx)  ## network_manager.gd "skill_scene" ile birebir aynı ekleme
	assert(rp._ally_aura_fx.get("heal") == fx, "uzak kopya RemotePlayer._ally_aura_fx['heal']'e kaydolmalı")
	rp.stop_ally_aura_fx("heal")  ## broadcast_ally_aura_stop -> bu çağrı
	fx._process(0.1)
	fx._process(0.5)
	assert(fx.is_queued_for_deletion(), "erken iptalde uzak kopya da kapanmalı")
	rp.queue_free()


## 2026-10-19: çiçeğin efekti artık "Yaprak Halkası" (madde 285, oakley_flower_fx.gd): zemin parçası çiçeğin KARDEŞİ (yaratık/oyuncuların altı,
## madde 284), yapraklar çiçeğin kendisinde (arka yarı _draw, ön yarı FxFront çocuğu); çiçek silinince zemin parçası da gider.
func test_flower_carries_leaf_halo_until_picked() -> void:
	var holder := Node2D.new()
	add_child(holder)
	var flower := Node2D.new()
	flower.set_script(load("res://scripts/oakley_flower.gd"))
	holder.add_child(flower)
	flower.global_position = Vector2(100.0, 200.0)
	flower.call("setup", 50.0, "test_1")
	await get_tree().process_frame  ## zemin parçası kare sonunda (call_deferred) kurulur - konum add_child'dan sonra veriliyor
	var ground: Node2D = flower.get("_ground_fx") as Node2D
	assert(ground != null and ground.get_script() == load("res://scripts/oakley_flower_fx.gd"), "çiçek zemine Yaprak Halkası havuzu kurmalı")
	assert(ground.get_parent() == holder, "zemin parçası çiçeğin kardeşi olmalı (çocuğuyken çiçeğin z'siyle oyuncunun üstüne çıkıyordu)")
	assert(ground.global_position.is_equal_approx(Vector2(100.0, 200.0)), "zemin parçası çiçeğin yerel koordinatında çizer (kök aynı)")
	assert(ground.z_index == 0, "Main'de z -1 zeminin altına düşer")
	var front: Node = flower.get_node_or_null("FxFront")
	assert(front != null and front.get_index() > flower.get_node("AnimatedSprite2D").get_index(), "ön yarı yapraklar sprite'tan sonra çizilmeli")
	assert(not FileAccess.file_exists("res://scenes/fx_recovery_life_flower.tscn"), "eski Life Recovery çiçek sahnesi kalktı")
	for i in 100:  ## 10 sn - efekt çiçek alınana kadar kalır
		flower.call("_process_fx", 0.1)
	assert(is_instance_valid(ground) and not ground.is_queued_for_deletion(), "çiçek alınana kadar efekt kalmalı")
	flower.call("remove_remotely")
	assert(flower.is_queued_for_deletion(), "çiçek alınınca silinmeli")
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not is_instance_valid(ground), "çiçek silinince zemin parçası da gitmeli")
	holder.queue_free()
	var src: String = _strip_comments(_read("res://scripts/oakley_flower.gd"))
	assert(not src.contains("draw_circle") and not src.contains("draw_arc"),
		"eski yumuşak vektör halka çiçekten kaldırılmış olmalı (pixel efektle çelişiyordu)")
