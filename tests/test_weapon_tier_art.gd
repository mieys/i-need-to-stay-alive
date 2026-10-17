extends Node

## Zanaatkâr silah seti (madde 196): efsun kademesi -> silah ikonu sanatı. Yerel weapon.gd ve uzak kukla remote_player.gd AYNI
## sanatı/ölçeği/duruşu kullanmalı (weapon_tier_art.gd tek kaynak); bumerang/fişek mermisi de kademe sanatıyla uçar.

const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const BoomerangProjScene: PackedScene = preload("res://scenes/boomerang_projectile.tscn")
const FireworkScene: PackedScene = preload("res://scenes/firework_projectile.tscn")


func test_every_weapon_has_five_tiers_of_art() -> void:
	for key in WeaponTierArt.FORWARD:
		for t in range(1, 6):
			var tex: Texture2D = WeaponTierArt.texture(key, t)
			assert(tex != null, "%s L%d dokusu yok" % [key, t])
			assert(tex.get_size() == Vector2(48, 48), "%s L%d 48x48 değil" % [key, t])
		## sahne dosyasından anahtar (weapon.gd _ready shop_key'den önce çalışır)
	for scene_name in WeaponTierArt.SCENE_KEYS:
		assert(ResourceLoader.exists("res://scenes/%s.tscn" % scene_name), "sahne yok: %s" % scene_name)
		assert(WeaponTierArt.has_art(WeaponTierArt.key_from_scene("res://scenes/%s.tscn" % scene_name)), "anahtar eşlemesi: %s" % scene_name)
	for t in range(1, 6):
		assert(WeaponTierArt.bow_frames(t).get_frame_count(&"draw") == 5, "yay L%d draw kareleri 5 olmalı" % t)
		assert(WeaponTierArt.boomerang_rot_frames(t).get_frame_count(&"spin") == 24, "bumerang L%d 24 dönüş karesi" % t)
	assert(WeaponTierArt.clamp_tier(0) == 1 and WeaponTierArt.clamp_tier(9) == 5, "efsunsuz (0) -> 1, üst sınır 5")


func _local_weapon(scene_path: String) -> Node2D:
	var owner_node := Node2D.new()
	owner_node.scale = Vector2(0.5, 0.5) ## main.tscn Player kök ölçeği
	add_child(owner_node)
	var w: Node2D = (load(scene_path) as PackedScene).instantiate()
	owner_node.add_child(w)
	return w


func test_local_weapon_swaps_art_with_tier_and_keeps_world_pixel() -> void:
	var w: Node2D = _local_weapon("res://scenes/weapon_uzunkilic.tscn")
	var icon: Sprite2D = w.get("icon_sprite")
	assert(icon.texture.resource_path.ends_with("zanaat/uzunkilic_L1.png"), "doğuşta 1. seviye: %s" % icon.texture.resource_path)
	assert(is_equal_approx(float(w.get("sprite_forward_angle_deg")), -45.0), "yeni sanat çapraz")
	assert(is_equal_approx(float(w.get("melee_icon_rest_rotation_deg")), -45.0), "dinlenmede uç yukarı (-45)")
	assert(icon.scale.is_equal_approx(Vector2.ONE * WeaponTierArt.WORLD_PX / 0.5), "yakın dövüş ikon ölçeği 1 -> dünya pikseli WORLD_PX")
	w.call("_apply_tier_art", 4)
	assert(icon.texture.resource_path.ends_with("uzunkilic_L4.png"), "kademe 4 sanatı")
	w.get_parent().queue_free()
	## asa: silah kökü 0,5 x 0,3 -> ikon 1/0,3 (dünya pikseli yine 0,5)
	var staff: Node2D = _local_weapon("res://scenes/weapon_fire.tscn")
	var sicon: Sprite2D = staff.get("icon_sprite")
	assert(is_equal_approx(sicon.scale.x * 0.5 * 0.3, WeaponTierArt.WORLD_PX), "asa dünya pikseli WORLD_PX, bulunan %f" % (sicon.scale.x * 0.15))
	staff.get_parent().queue_free()


func test_bow_uses_tier_draw_frames_and_hides_old_arrow() -> void:
	var w: Node2D = _local_weapon("res://scenes/weapon_yay.tscn")
	var icon: AnimatedSprite2D = w.get("icon_sprite")
	assert(icon.sprite_frames == WeaponTierArt.bow_frames(1), "yay L1 kareleri")
	var arrow: Sprite2D = icon.get_node_or_null("HeldArrow") as Sprite2D
	assert(arrow == null or arrow.texture == null, "eski ayrı ok sprite'ı gizli (ok karelerin içinde)")
	w.call("_apply_tier_art", 5)
	assert(icon.sprite_frames == WeaponTierArt.bow_frames(5), "yay L5 kareleri")
	w.get_parent().queue_free()


func test_remote_puppet_matches_local_art_and_follows_ench_tiers() -> void:
	var puppet: RemotePlayer = RemotePlayerScene.instantiate()
	puppet.peer_id = 4242
	add_child(puppet)
	puppet.update_weapon_visuals(["tufek", "fire_staff"])
	var i0: Sprite2D = puppet.get_weapon_icon_info(0)[0]
	var i1: Sprite2D = puppet.get_weapon_icon_info(1)[0]
	assert(i0.texture.resource_path.ends_with("tufek_L1.png"), "kukla tüfek L1")
	assert(i1.scale.is_equal_approx(Vector2.ONE * WeaponTierArt.PUPPET_ICON_SCALE), "kukla asa ölçeği yerel ile aynı dünya pikseli")
	assert(is_equal_approx(float(puppet.get_weapon_icon_info(1)[1]), -45.0), "kukla ileri açısı yeni sanattan")
	puppet.call("_apply_enchant_glows", [2, 5])
	assert(i0.texture.resource_path.ends_with("tufek_L2.png"), "ench_tiers -> kukla tüfek L2")
	assert(i1.texture.resource_path.ends_with("fire_staff_L5.png"), "ench_tiers -> kukla asa L5")
	puppet.queue_free()


func test_projectiles_fly_with_tier_art() -> void:
	var b: Node2D = BoomerangProjScene.instantiate()
	add_child(b)
	b.set("impact_sounds", [] as Array[AudioStream])
	var body: AnimatedSprite2D = b.get("_body")
	assert(body.sprite_frames == WeaponTierArt.boomerang_rot_frames(1), "bumerang mermisi L1")
	b.call("set_art_tier", 3)
	assert(body.sprite_frames == WeaponTierArt.boomerang_rot_frames(3), "bumerang mermisi L3")
	b.queue_free()
	var f: Node2D = FireworkScene.instantiate()
	add_child(f)
	var ficon: Sprite2D = f.get_node("Icon")
	assert(ficon.texture.resource_path.ends_with("fisek_L1.png"), "fişek mermisi L1")
	assert(is_equal_approx(float(f.get("_rot_correction")), PI / 4.0), "çapraz burun -> +45 derece düzeltme")
	f.call("set_art_tier", 5)
	assert(ficon.texture.resource_path.ends_with("fisek_L5.png"), "fişek mermisi L5")
	f.queue_free()


## Demirci kademesi stat verir (weapon.gd TIER_*): kademe 5'te hasar x1,40, atış aralığı x0,80; efsunsuz/1. kademe değişmez.
func test_tier_gives_damage_and_fire_rate() -> void:
	var w: Node2D = _local_weapon("res://scenes/weapon_uzunkilic.tscn")
	w.call("set_damage_bonus", 100.0) ## taban hasar 0; hasar saldırı gücünden gelir
	var base_dmg: float = float(w.get("damage"))
	var base_rate: float = float(w.get("fire_rate"))
	assert(base_dmg > 0.0 and base_rate > 0.0, "taban değerleri")
	w.call("set_enchant", {"id": "ates_nefesi", "ups": [0, 1, 2], "final": false})
	assert(int(w.get("enchant_glow_tier")) == 4, "3 geliştirme = kademe 4")
	assert(is_equal_approx(float(w.get("damage")), base_dmg * 1.3), "kademe 4 hasar x1,3, bulunan %f / %f" % [float(w.get("damage")), base_dmg])
	assert(is_equal_approx(float(w.get("fire_rate")), base_rate * 0.85), "kademe 4 atış aralığı x0,85")
	w.call("set_enchant", {})
	assert(is_equal_approx(float(w.get("damage")), base_dmg) and is_equal_approx(float(w.get("fire_rate")), base_rate), "efsun kalkınca eski stat")
	w.get_parent().queue_free()
