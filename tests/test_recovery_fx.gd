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
const FLOWER_SCENE := "res://scenes/fx_recovery_life_flower.tscn"
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
	for path: String in [LIFE_SCENE, MANA_SCENE, FLOWER_SCENE]:
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


## CLAUDE.md hata sınıfı: iki dosya aynı sahneleri ayrı preload ediyor.
func test_player_and_remote_player_reference_the_new_scenes_and_no_old_ones() -> void:
	for path: String in ["res://scripts/player.gd", "res://scripts/remote_player.gd"]:
		var src: String = _strip_comments(_read(path))
		assert(src.contains("fx_recovery_life.tscn"), "%s Life sahnesini kullanmalı" % path)
		assert(src.contains("fx_recovery_mana.tscn"), "%s Mana sahnesini kullanmalı" % path)
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


func test_flower_carries_looping_recovery_fx_until_picked() -> void:
	var flower := Node2D.new()
	flower.set_script(load("res://scripts/oakley_flower.gd"))
	add_child(flower)
	flower.call("setup", 50.0, "test_1")
	var found: AnimatedSprite2D = null
	for c: Node in flower.get_children():
		if c is AnimatedSprite2D and c.get_script() == load("res://scripts/fx_recovery_aura.gd"):
			found = c
	assert(found != null, "çiçek fx_recovery_aura taşımalı")
	assert(found.max_lifetime == 0.0, "çiçekteki efekt sınırsız süreli olmalı (alınana kadar)")
	for i in 100:  ## 10 sn - Melek'in güvenlik süresini aşsa da çiçekteki efekt gitmemeli
		found._process(0.1)
	assert(not found.is_queued_for_deletion(), "çiçek alınana kadar efekt kalmalı")
	flower.call("remove_remotely")  ## alınınca çiçek queue_free olur, çocuğu da onunla gider
	assert(flower.is_queued_for_deletion(), "çiçek alınınca silinmeli (efekt de onunla gider)")
	var src: String = _strip_comments(_read("res://scripts/oakley_flower.gd"))
	assert(not src.contains("draw_circle") and not src.contains("draw_arc"),
		"eski yumuşak vektör halka çiçekten kaldırılmış olmalı (pixel efektle çelişiyordu)")
