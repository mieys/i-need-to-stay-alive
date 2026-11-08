extends Node

## Sabit silah sanatı (madde 402; madde 196/198 Zanaatkâr kademe sanatının yerine): masaüstü çizimleri (Uzunkılıç + 5 asa) ve
## yeni silahlar (Mızrak/Kalkan/Yin Yang 1. seviye) sabit dokuda, diğerleri ESKİ ikonlarında; demirci kademesi dokuyu DEĞİŞTİRMEZ,
## kontür parıltısı (enchant_weapon_glow.gd) takılır. Yerel weapon.gd ve uzak kukla remote_player.gd AYNI sanatı/ölçeği/duruşu kullanır.

const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")
const GlowScript := preload("res://scripts/enchant_weapon_glow.gd")
const WeaponCatalog := preload("res://scripts/weapon_catalog.gd")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const BoomerangProjScene: PackedScene = preload("res://scenes/boomerang_projectile.tscn")
const FireworkScene: PackedScene = preload("res://scenes/firework_projectile.tscn")

## anahtar -> assets/weapons/yeni/ dosyası (Tüftüf 2026-11-06'dan beri ZEHİR ASASI, anahtar aynı; Yay + Arbalet madde 413)
const DESKTOP_ART := {"uzunkilic": "uzunkilic", "arcane": "arcane", "fire_staff": "fire_staff", "buz_asasi": "buz_asasi",
	"gokkusagi": "gokkusagi", "tuftuf": "zehir_asasi", "crossbow": "arbalet", "yay": "yay"}
## Yay'ın ipi sol-üst köşegende, ok sağ-alta uçar (+45); diğer çizimler sol-alt -> sağ-üst (-45).
const DESKTOP_FORWARD := {"yay": 45.0}
const NEW_WEAPONS := ["mizrak", "kalkan", "yinyang"]
## Zanaatkâr öncesi ikonlarına dönenler: sahne dokusu (asalarda weapon.gd'nin v3 ikonu).
const OLD_ICONS := {
	"weapon_dagger": "base_knife/icon_v2.png", "weapon_topuz": "topuz/icon.png", "weapon_pence": "pence/icon.png",
	"weapon_lightning": "lightning/icon_v3.png", "weapon_tabanca": "tabanca/icon_v2.png", "weapon_tufek": "tufek/icon.png",
	"weapon_boomerang": "boomerang/icon.png",
	"weapon_fisek": "fisek/icon.png",
}


func test_art_table_is_desktop_art_plus_new_weapons() -> void:
	for key in DESKTOP_ART:
		var tex: Texture2D = WeaponTierArt.texture(key)
		assert(tex != null and tex.resource_path == "res://assets/weapons/yeni/%s.png" % DESKTOP_ART[key], "%s masaüstü çizimi" % key)
		assert(is_equal_approx(float(WeaponTierArt.FORWARD[key]), float(DESKTOP_FORWARD.get(key, -45.0))), "%s çizimin duruşu" % key)
		assert(WeaponCatalog.icon(key) == tex, "%s arayüz ikonu = oyundaki çizim" % key)
	for key in NEW_WEAPONS:
		var nt: Texture2D = WeaponTierArt.texture(key)
		assert(nt != null and nt.resource_path.ends_with("zanaat/%s_L1.png" % key), "%s 1. seviye" % key)
	assert(WeaponTierArt.ART.size() == DESKTOP_ART.size() + NEW_WEAPONS.size(), "tabloda başka silah yok")
	for key in ["dagger", "topuz", "pence", "lightning_staff", "tabanca", "tufek", "boomerang", "fisek"]:
		assert(not WeaponTierArt.has_art(key) and WeaponTierArt.texture(key) == null, "%s eski ikonunda" % key)
	for t in range(1, 6):
		assert(WeaponTierArt.texture("arcane", t) == WeaponTierArt.texture("arcane", 1), "doku kademeyle değişmez")
	for scene_name in WeaponTierArt.SCENE_KEYS:
		assert(ResourceLoader.exists("res://scenes/%s.tscn" % scene_name), "sahne yok: %s" % scene_name)
	assert(WeaponTierArt.clamp_tier(0) == 1 and WeaponTierArt.clamp_tier(9) == 5, "efsunsuz (0) -> 1, üst sınır 5")
	assert(GlowScript.GLOW_ENABLED, "kademe göstergesi kontür parıltısı açık")
	assert(WeaponCatalog.display_name("tuftuf") == "Zehir Asası", "Tüftüf -> Zehir Asası")
	assert(WeaponCatalog.icon("tuftuf") == WeaponTierArt.texture("tuftuf"), "arayüz ikonu = oyundaki çizim")


func _local_weapon(scene_path: String) -> Node2D:
	var owner_node := Node2D.new()
	owner_node.scale = Vector2(0.5, 0.5) ## main.tscn Player kök ölçeği
	add_child(owner_node)
	var w: Node2D = (load(scene_path) as PackedScene).instantiate()
	owner_node.add_child(w)
	return w


func _glow_alive(icon: Node) -> bool:
	var g: Node = icon.get_node_or_null("EnchantGlow")
	return g != null and not g.is_queued_for_deletion()


func test_local_weapon_keeps_fixed_art_and_glows_with_tier() -> void:
	var w: Node2D = _local_weapon("res://scenes/weapon_uzunkilic.tscn")
	var icon: Sprite2D = w.get("icon_sprite")
	assert(icon.texture.resource_path == "res://assets/weapons/yeni/uzunkilic.png", "masaüstü kılıcı: %s" % icon.texture.resource_path)
	assert(is_equal_approx(float(w.get("sprite_forward_angle_deg")), -45.0), "sanat çapraz")
	assert(is_equal_approx(float(w.get("melee_icon_rest_rotation_deg")), -45.0), "dinlenmede uç yukarı (-45)")
	assert(icon.scale.is_equal_approx(Vector2.ONE * WeaponTierArt.WORLD_PX / 0.5), "yakın dövüş ikon ölçeği -> dünya pikseli WORLD_PX")
	w.call("set_enchant", {"id": "ates_nefesi", "ups": [0, 1, 2], "final": false})
	assert(int(w.get("enchant_glow_tier")) == 4, "3 geliştirme = kademe 4")
	assert(icon.texture.resource_path == "res://assets/weapons/yeni/uzunkilic.png", "kademe 4'te doku AYNI")
	assert(_glow_alive(icon) and int(icon.get_node("EnchantGlow").get("tier")) == 4, "kademe 4 kontürü takıldı")
	w.call("set_enchant", {})
	assert(not _glow_alive(icon), "efsun kalkınca kontür gider")
	w.get_parent().queue_free()
	## asa: silah kökü 0,5 x 0,3 -> ikon 1/0,3 (dünya pikseli yine WORLD_PX)
	var staff: Node2D = _local_weapon("res://scenes/weapon_fire.tscn")
	var sicon: Sprite2D = staff.get("icon_sprite")
	assert(sicon.texture.resource_path == "res://assets/weapons/yeni/fire_staff.png", "masaüstü ateş asası")
	assert(is_equal_approx(sicon.scale.x * 0.5 * 0.3, WeaponTierArt.WORLD_PX), "asa dünya pikseli WORLD_PX, bulunan %f" % (sicon.scale.x * 0.15))
	staff.get_parent().queue_free()


func test_other_weapons_are_back_on_their_old_icons() -> void:
	for scene_name in OLD_ICONS:
		var path: String = "res://scenes/%s.tscn" % scene_name
		var want: String = "res://assets/weapons/" + str(OLD_ICONS[scene_name])
		var w: Node2D = _local_weapon(path)
		var icon: Sprite2D = w.get("icon_sprite") as Sprite2D
		assert(icon != null and icon.texture.resource_path == want, "%s eski ikonu: %s" % [scene_name, icon.texture.resource_path if icon else "?"])
		var st: SceneState = (load(path) as PackedScene).get_state()
		var scene_fwd: float = 0.0
		for pi in range(st.get_node_property_count(0)):
			if st.get_node_property_name(0, pi) == &"sprite_forward_angle_deg":
				scene_fwd = float(st.get_node_property_value(0, pi))
		assert(is_equal_approx(float(w.get("sprite_forward_angle_deg")), scene_fwd), "%s eski duruşu (sahne değeri)" % scene_name)
		w.call("set_enchant", {"id": "ates_nefesi", "ups": [0, 1, 2, 3], "final": true})
		assert(icon.texture.resource_path == want, "%s kademe 5'te de eski ikon" % scene_name)
		assert(_glow_alive(icon), "%s kademe 5 kontürü" % scene_name)
		w.get_parent().queue_free()


## Yay + Arbalet (madde 413): kullanıcının çizimi; Yay çizimden türetilen 5 "draw" karesini oynatır, ok karelerin içinde.
func test_bow_and_crossbow_use_desktop_art() -> void:
	var src: Image = (load("res://assets/weapons/yeni/yay.png") as Texture2D).get_image()
	var sf: SpriteFrames = WeaponTierArt.bow_frames()
	assert(sf.get_frame_count(&"draw") == 5 and not sf.get_animation_loop(&"draw") and is_equal_approx(sf.get_animation_speed(&"draw"), 8.0), "5 kare, döngüsüz, 8 fps (eski draw_frames gibi)")
	for k in range(5):
		var ft: Texture2D = sf.get_frame_texture(&"draw", k)
		assert(ft.resource_path == "res://assets/weapons/yeni/yay_d%d.png" % (k + 1), "kare %d dosyası" % (k + 1))
		assert(ft.get_size() == Vector2(src.get_size()), "kare %d çizimle aynı tuval (ölçek/merkez aynı)" % (k + 1))
	var bow: Node2D = _local_weapon("res://scenes/weapon_yay.tscn")
	var bicon: AnimatedSprite2D = bow.get("icon_sprite")
	assert(bicon.sprite_frames == sf and bicon.animation == &"draw", "yerel yay çekiş kareleri")
	assert(is_equal_approx(float(bow.get("sprite_forward_angle_deg")), 45.0), "yay ok yönü +45")
	assert(bicon.scale.is_equal_approx(Vector2.ONE * WeaponTierArt.WORLD_PX / 0.5), "yay ikon ölçeği -> dünya pikseli WORLD_PX")
	assert(bicon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "piksel keskin")
	var arrow: Sprite2D = bicon.get_node_or_null("HeldArrow") as Sprite2D
	assert(arrow == null or arrow.texture == null, "ayrı eski ok gizli (ok karelerin içinde)")
	bow.call("set_enchant", {"id": "ates_nefesi", "ups": [0], "final": false})
	assert(bicon.sprite_frames == sf, "yay kademe 2'de de aynı kareler")
	assert(_glow_alive(bicon), "yay kademe 2 kontürü")
	bow.get_parent().queue_free()
	var cb: Node2D = _local_weapon("res://scenes/weapon_crossbow.tscn")
	var cicon: Sprite2D = cb.get("icon_sprite")
	assert(cicon.texture.resource_path == "res://assets/weapons/yeni/arbalet.png", "masaüstü arbalet")
	assert(is_equal_approx(float(cb.get("sprite_forward_angle_deg")), -45.0), "arbalet çapraz (uç sağ-üst)")
	assert(cicon.scale.is_equal_approx(Vector2.ONE * WeaponTierArt.WORLD_PX / 0.5), "arbalet dünya pikseli WORLD_PX")
	cb.get_parent().queue_free()
	## Kukla: yerel ile aynı kareler/doku, ölçek ve duruş
	var puppet: RemotePlayer = RemotePlayerScene.instantiate()
	puppet.peer_id = 4243
	add_child(puppet)
	puppet.update_weapon_visuals(["yay", "crossbow"])
	## get_weapon_icon_info yalnız Sprite2D döndürür (efsun ikon efekti; yay AnimatedSprite2D) -> ikon listesi doğrudan
	var picons: Array = puppet.get("_weapon_icons")
	var pfwd: Array = puppet.get("_weapon_forward_angle_deg")
	assert(picons.size() == 2 and pfwd.size() == 2, "kukla iki ikon")
	var pb: AnimatedSprite2D = picons[0] as AnimatedSprite2D
	var pc: Sprite2D = picons[1] as Sprite2D
	assert(pb != null and pc != null, "kukla ikon türleri")
	assert(pb.sprite_frames == sf, "kukla yay çekiş kareleri")
	var parrow: Sprite2D = pb.get_node_or_null("HeldArrow") as Sprite2D
	assert(parrow == null or parrow.texture == null, "kuklada ayrı ok gizli")
	assert(pc.texture.resource_path == "res://assets/weapons/yeni/arbalet.png", "kukla arbalet")
	assert(pb.scale.is_equal_approx(Vector2.ONE * WeaponTierArt.PUPPET_ICON_SCALE) and pc.scale.is_equal_approx(Vector2.ONE * WeaponTierArt.PUPPET_ICON_SCALE), "kukla ölçeği yerel ile aynı dünya pikseli")
	assert(is_equal_approx(float(pfwd[0]), 45.0) and is_equal_approx(float(pfwd[1]), -45.0), "kukla duruşları sanattan")
	puppet.queue_free()


func test_remote_puppet_matches_local_art_and_only_glows_with_ench_tiers() -> void:
	var puppet: RemotePlayer = RemotePlayerScene.instantiate()
	puppet.peer_id = 4242
	add_child(puppet)
	puppet.update_weapon_visuals(["tufek", "fire_staff"])
	var i0: Sprite2D = puppet.get_weapon_icon_info(0)[0]
	var i1: Sprite2D = puppet.get_weapon_icon_info(1)[0]
	assert(i0.texture.resource_path.ends_with("tufek/icon.png"), "kukla tüfek eski ikon")
	assert(i1.texture.resource_path == "res://assets/weapons/yeni/fire_staff.png", "kukla asa masaüstü çizimi")
	assert(i1.scale.is_equal_approx(Vector2.ONE * WeaponTierArt.PUPPET_ICON_SCALE), "kukla asa ölçeği yerel ile aynı dünya pikseli")
	assert(is_equal_approx(float(puppet.get_weapon_icon_info(1)[1]), -45.0), "kukla ileri açısı sanattan")
	puppet.call("_apply_enchant_glows", [2, 5])
	assert(i0.texture.resource_path.ends_with("tufek/icon.png") and i1.texture.resource_path.ends_with("yeni/fire_staff.png"), "ench_tiers dokuyu değiştirmez")
	assert(_glow_alive(i0) and _glow_alive(i1), "ench_tiers -> kontür")
	assert(int(i1.get_meta("ench_tier", 0)) == 5 and int(i0.get_meta("ench_tier", 0)) == 2, "uç parıltısı kademesi meta'da")
	puppet.queue_free()


func test_projectiles_fly_with_old_art() -> void:
	var b: Node2D = BoomerangProjScene.instantiate()
	add_child(b)
	b.set("impact_sounds", [] as Array[AudioStream])
	var body: AnimatedSprite2D = b.get("_body")
	assert(body.sprite_frames.resource_path.ends_with("boomerang/rot24_frames.tres"), "bumerang mermisi eski dönüş kareleri")
	assert(not b.has_method("set_art_tier"), "kademe sanatı yok")
	b.queue_free()
	var f: Node2D = FireworkScene.instantiate()
	add_child(f)
	var ficon: Sprite2D = f.get_node("Icon")
	assert(ficon.texture.resource_path.ends_with("fisek/icon.png"), "fişek mermisi eski roket")
	assert(not f.has_method("set_art_tier"), "kademe sanatı yok")
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
	## Final sonrası güçlendirme (madde 297): parıltı kademesi 5'te kalır, stat sürer (+%10 taban hasar, kademe V hızının +%5'i).
	w.call("set_enchant", {"id": "ates_nefesi", "ups": [0, 1, 2, 3], "final": true, "plus": 3})
	assert(int(w.get("enchant_glow_tier")) == 5, "güçlendirme parıltı kademesini 5'in üstüne taşımaz")
	assert(is_equal_approx(float(w.get("damage")), base_dmg * 1.7), "V +3 hasar x1,7, bulunan %f / %f" % [float(w.get("damage")), base_dmg])
	assert(is_equal_approx(float(w.get("fire_rate")), base_rate * 0.8 / 1.15), "V +3 atış aralığı x0,8 / 1,15")
	w.call("set_enchant", {"id": "ates_nefesi", "ups": [0, 1], "final": false, "plus": 3})
	assert(is_equal_approx(float(w.get("damage")), base_dmg * 1.2), "final alınmadan 'plus' sayılmaz")
	w.get_parent().queue_free()


func test_tier_stat_curve_never_reaches_zero_fire_wait() -> void:
	const W := preload("res://scripts/weapon.gd")
	assert(is_equal_approx(W.tier_fire_rate_mult(5), 0.8) and is_equal_approx(W.tier_fire_rate_mult(1), 1.0), "1-5 eski doğrusal eğri")
	var prev: float = W.tier_fire_rate_mult(5)
	for t in range(6, 60):
		var m: float = W.tier_fire_rate_mult(t)
		assert(m > 0.0 and m < prev, "kademe %d atış aralığı pozitif ve azalıyor (%f)" % [t, m])
		prev = m
