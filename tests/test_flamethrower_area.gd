extends Node

## Madde 639 (2026-11-13): Ateş Asası alevi = kullanıcının "Flamethrower Left_Right" efekti; hasar alanı alevin ŞEKLİ (eski 60°'lik koni değil).
## Kapsam: üretilmiş profil (flamethrower_shape.gd), alan testi (ates_nefesi.gd flame_contains: ağızda ince, uçta yukarı kabaran bulut,
## sola bakarken aynalanır), başlangıç animasyonunda alanın uzaması, sayfanın start/loop/end animasyonları, özellik tanımının yeni
## geliştirmeleri (Genişleyen Boğaz + finalin büyümesi yok; Kavurucu Uç + Isınan Nefes var), gerçek oyuncu + yaratıkla alan dışı/içi isabet.

const Shape := preload("res://scripts/weapon_traits/flamethrower_shape.gd")
const Trait := preload("res://scripts/weapon_traits/ates_nefesi.gd")
const SpriteFx := preload("res://scripts/fx_enchant_sprite.gd")
const FlameBend := preload("res://scripts/weapon_traits/flame_bend.gd")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")

const W := 0.903


func _world(dir: Vector2, lx: float, ly: float) -> Vector2:
	## sanat px (alevin yerel ekseni, y aşağı +) -> dünya (ağız = 0)
	return (dir * lx + Vector2(-dir.y, dir.x) * ly) * W


func test_profile_shape_thin_nozzle_wide_tip() -> void:
	assert(Shape.LENGTH > 150.0 and Shape.LENGTH < 200.0, "alev boyu %.0f sanat px" % Shape.LENGTH)
	var near: Vector2 = Shape.band_at(10.0)
	var tip: Vector2 = Shape.band_at(Shape.LENGTH * 0.85)
	assert(near.y - near.x <= 3.0, "ağızda ince hat olmalı: %s" % near)
	assert(tip.y - tip.x >= 15.0 and tip.x <= -20.0, "uçta yukarı kabaran bulut olmalı: %s" % tip)
	assert(Shape.band_at(Shape.LENGTH + 5.0).x > Shape.band_at(Shape.LENGTH + 5.0).y, "alevin ötesi boş")


func test_contains_follows_flame_shape() -> void:
	var o := Vector2(500.0, 500.0)
	var r: Vector2 = Vector2.RIGHT
	var full: float = Shape.LENGTH
	## Orta hat: ağız yakınında ve ortada içeride.
	assert(bool(Trait.flame_contains(o, r, o + _world(r, 30.0, 0.0), full)[0]), "ağız yakını orta hat içeride")
	assert(bool(Trait.flame_contains(o, r, o + _world(r, 100.0, 0.0), full)[0]), "orta hat içeride")
	## Ağız yakınında yandaki (eski koninin içi) yaratık DIŞARIDA: 40 sanat px, 35 px yukarı.
	assert(not bool(Trait.flame_contains(o, r, o + _world(r, 40.0, -35.0), full)[0]), "ince hattın yanı dışarıda (eski koni)")
	## Uçtaki bulut (yukarı) içeride, aynı uzaklıkta aşağısı dışarıda (bulut yukarı kabarır).
	var lx: float = full * 0.85
	assert(bool(Trait.flame_contains(o, r, o + _world(r, lx, -26.0), full)[0]), "uçtaki bulut içeride")
	assert(not bool(Trait.flame_contains(o, r, o + _world(r, lx, 34.0), full)[0]), "bulutun altı dışarıda")
	## Boyun ötesi dışarıda.
	assert(not bool(Trait.flame_contains(o, r, o + _world(r, full + 30.0, 0.0), full)[0]), "alevin ötesi dışarıda")
	## Oran: uç = 1'e yakın (Kavurucu Uç bölgesi)
	var res: Array = Trait.flame_contains(o, r, o + _world(r, lx, -20.0), full)
	assert(float(res[1]) >= Trait.TIP_FROM, "uç oranı %.2f" % float(res[1]))


func test_left_facing_mirrors_cloud_up() -> void:
	var o := Vector2(500.0, 500.0)
	var l: Vector2 = Vector2.LEFT
	var lx: float = Shape.LENGTH * 0.85
	## Sola bakarken bulut yine ekranda YUKARIDA (dünya y < ağız y).
	var above: Vector2 = o + Vector2(-lx * W, -26.0 * W)
	var below: Vector2 = o + Vector2(-lx * W, 34.0 * W)
	assert(bool(Trait.flame_contains(o, l, above, Shape.LENGTH)[0]), "sola bakan alevin bulutu yukarıda olmalı")
	assert(not bool(Trait.flame_contains(o, l, below, Shape.LENGTH)[0]), "sola bakan alevin altı dışarıda")


func test_intro_reach_grows() -> void:
	assert(Shape.reach_at(0.0) < 40.0, "ilk karede alev kısa: %.0f" % Shape.reach_at(0.0))
	assert(Shape.reach_at(0.2) > Shape.reach_at(0.0), "alan alevle uzar")
	assert(Shape.reach_at(1.0) == Shape.LENGTH, "döngüde tam boy")
	var o := Vector2.ZERO
	var far: Vector2 = _world(Vector2.RIGHT, 120.0, 0.0)
	assert(not bool(Trait.flame_contains(o, Vector2.RIGHT, far, Shape.reach_at(0.0))[0]), "giriş karesinde uzaktaki yanmaz")


## Madde 640: asa dönünce alev bükülür - ağız hemen döner, uç eski yönde geride kalır; hasar alanı görselle aynı hesap.
func test_bend_history_tip_lags_behind() -> void:
	var b = FlameBend.new()
	b.reset(10.0, 0.0)
	b.push(10.0, 0.0)
	b.push(10.05, 0.5) ## asa 0,05 sn'de 0,5 rad döndü
	var a: PackedFloat32Array = b.angles(10.05, Shape.LENGTH)
	assert(a.size() == FlameBend.N, "örnek sayısı")
	assert(absf(a[0]) < 0.05, "ağız şimdiki yönde: %.2f" % a[0])
	assert(a[FlameBend.N - 1] < -0.4, "uç eski yönde geride kalır: %.2f" % a[FlameBend.N - 1])
	## Uzun süre sabit tutunca alev düzleşir.
	b.push(11.0, 0.5)
	var flat: PackedFloat32Array = b.angles(11.0, Shape.LENGTH)
	assert(absf(flat[FlameBend.N - 1]) < 0.01, "sabit asada alev düz: %.3f" % flat[FlameBend.N - 1])
	## 2pi atlaması bükülme sanılmaz.
	var c = FlameBend.new()
	c.reset(0.0, PI - 0.05)
	c.push(0.02, -PI + 0.05)
	assert(absf(c.angles(0.02, Shape.LENGTH)[FlameBend.N - 1]) < 0.2, "±pi geçişi küçük büküm")


func test_bent_area_follows_bent_flame() -> void:
	var b = FlameBend.new()
	b.reset(5.0, 0.0)
	b.push(5.0, 0.0)
	b.push(5.05, 0.6)
	var bend: PackedFloat32Array = b.angles(5.05, Shape.LENGTH)
	var o := Vector2(100.0, 100.0)
	var dir := Vector2.from_angle(0.6) ## şimdiki asa yönü
	var lx: float = Shape.LENGTH * 0.8
	var th: float = FlameBend.theta_at(bend, lx, Shape.LENGTH)
	var on_bent: Vector2 = o + Vector2(lx, 0.0).rotated(0.6 + th) * W
	var on_straight: Vector2 = o + Vector2(lx, 0.0).rotated(0.6) * W
	assert(bool(Trait.flame_contains(o, dir, on_bent, Shape.LENGTH, Trait.HIT_MARGIN, bend)[0]), "bükülen alevin ucu yakar")
	assert(not bool(Trait.flame_contains(o, dir, on_straight, Shape.LENGTH, Trait.HIT_MARGIN, bend)[0]), "düz çizginin ucu (alev yok) yakmaz")
	## İleri-geri: unbend(bükülmüş nokta) = düz alevdeki nokta.
	var q: Vector2 = FlameBend.unbend(Vector2(lx, 0.0).rotated(th), bend, Shape.LENGTH)
	assert(q.distance_to(Vector2(lx, 0.0)) < 1.0, "unbend tersi tutarlı: %s" % q)


## Bükülen efekt düğümü: gizli AnimatedSprite kareyi ilerletir (start -> loop), çizim "Bend" dörtlüsünde shader'la.
func test_bend_sprite_draws_current_frame() -> void:
	var n: Node2D = SpriteFx.spawn(get_tree(), Vector2(400.0, 400.0), {"sheet": "flamethrower_fire", "loop_time": 1.5,
		"scale": Vector2(W / SpriteFx.TEXEL, W / SpriteFx.TEXEL), "offset": Shape.SHEET_OFFSET, "bend_len": Shape.LENGTH, "flip_left": true,
		"key": "test_bend"})
	assert(n != null, "efekt doğmadı")
	await get_tree().process_frame
	var bend_spr: Sprite2D = n.get_node_or_null("Bend") as Sprite2D
	var anim: AnimatedSprite2D = n.get_node("Sprite") as AnimatedSprite2D
	assert(bend_spr != null and bend_spr.material is ShaderMaterial and not anim.visible, "Bend dörtlüsü çizer, sprite gizli")
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600:
		await get_tree().process_frame
	assert(anim.animation == &"loop", "gizliyken de start -> loop geçti: %s" % anim.animation)
	var reg: Vector4 = (bend_spr.material as ShaderMaterial).get_shader_parameter("region")
	var tex: AtlasTexture = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame) as AtlasTexture
	assert(absf(reg.x - tex.region.position.x) < 0.5 and absf(reg.y - tex.region.position.y) < 0.5, "shader o anki kareyi çizer")
	## Döndür: bir süre sonra büküm uçta eski yöne dönük.
	n.rotation += 0.8
	n.set("_target_rot", n.rotation)
	await get_tree().process_frame
	await get_tree().process_frame
	var bend: PackedFloat32Array = (bend_spr.material as ShaderMaterial).get_shader_parameter("bend")
	assert(bend.size() == FlameBend.N and bend[FlameBend.N - 1] < -0.3, "döndürünce uç geride: %s" % str(bend))
	## Gece ışığı (madde 647): bükülen alevde düz çizgi değil, alevin kavisli orta çizgisi (3+ nokta); uç bükümle geride kalır.
	var path: Array = n.call("get_glow_segment")
	assert(path.size() > 2, "bükülen alevin ışığı çok noktalı yol: %d" % path.size())
	var tip: Vector2 = Vector2(path[path.size() - 1]) - n.global_position
	var straight_tip: Vector2 = Vector2.from_angle(n.global_rotation) * Shape.LENGTH * W
	assert(tip.distance_to(straight_tip) > 8.0, "ışık ucu düz çizgide değil: %s vs %s" % [str(tip), str(straight_tip)])
	assert(absf(tip.length() - straight_tip.length()) < 40.0, "ışık yolu alev boyunda: %.1f" % tip.length())
	n.queue_free()


func test_sheet_has_start_loop_end() -> void:
	for name in ["flamethrower_fire", "flamethrower_ice"]:
		var fr: SpriteFrames = SpriteFx.frames(name)
		assert(fr != null, "%s sayfası yok" % name)
		assert(fr.get_frame_count(&"start") == 6 and fr.get_frame_count(&"loop") == 12 and fr.get_frame_count(&"end") == 5,
			"%s: start/loop/end kare sayısı" % name)
		assert(fr.get_animation_loop(&"loop") and not fr.get_animation_loop(&"start") and not fr.get_animation_loop(&"end"), "%s döngü bayrakları" % name)


func test_trait_upgrades_replaced() -> void:
	var d: Dictionary = preload("res://scripts/weapon_traits/weapon_traits.gd").DEFS["ates_nefesi"] ## ham Türkçe (get_def dile göre çevirir)
	var names: Array = []
	for u in d["upgrades"]:
		names.append(str(u["name"]))
	assert(not names.has("Genişleyen Boğaz") and names.has("Kavurucu Uç"), "geliştirmeler: %s" % str(names))
	var fin: Dictionary = d["final"]["set"]
	assert(not fin.has("spray_size") and bool(fin.get("heat", false)), "final büyümez, ısınır: %s" % str(fin))
	assert(not (d["base"]["set"] as Dictionary).has("spray_angle"), "taban açı anahtarı kalktı")


## Gerçek oyuncu + gerçek yaratıklar: alevin içindeki yaratık hasar alır, eski koninin içinde kalan ama alevin yanındaki almaz.
func test_real_spray_hits_only_flame() -> void:
	var prev_weapons: Array = GameManager.owned_weapons.duplicate(true)
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = 1
	GameManager.selected_character = int(Characters.DEFS[1]["skill"])
	var p: Node2D = PlayerScene.instantiate()
	p.scale = Vector2(0.5, 0.5)
	add_child(p)
	p.global_position = Vector2(3000.0, 3000.0)
	p.max_health = 100000.0
	p.health = 100000.0
	for w0 in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w0):
			w0.free()
	p.owned_weapon_nodes.clear()
	GameManager.owned_weapons = [{"key": "fire_staff", "level": 1, "enchant": {"id": "ates_nefesi", "ups": [], "final": false}}]
	assert(p.buy_weapon_copy("fire_staff", 1), "asa verilemedi")
	var w: Node2D = p.owned_weapon_nodes[0]
	for i in 10:
		await get_tree().physics_frame
	var base: Vector2 = w.global_position
	var target: Node2D = EnemyScene.instantiate()
	add_child(target)
	target.global_position = base + Vector2(80.0, 0.0)
	var side: Node2D = EnemyScene.instantiate()
	add_child(side)
	side.global_position = base + Vector2(110.0, 45.0) ## eski 60°'lik koninin İÇİ (~22°, menzilde) ama alevin altı
	for e in [target, side]:
		e.set("speed", 0.0)
		e.max_health = 60000.0
		e.health = 60000.0
	## Asa hedefe dönerken alev kenardaki yaratığın üstünden SÜPÜREBİLİR (süpürülen yanar) ve yanması 3 sn sürer: önce alevin oturmasını +
	## yanmanın bitmesini bekle, ölçümü sonra yap.
	var settle: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < settle:
		await get_tree().process_frame
	var t0: float = target.health
	var s0: float = side.health
	var t_end: int = Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
	assert(target.health < t0, "alevin içindeki yaratık hasar almalı")
	assert(is_equal_approx(side.health, s0), "alevin yanındaki yaratık hasar almamalı (%.0f -> %.0f)" % [s0, side.health])
	p.free()
	target.queue_free()
	side.queue_free()
	GameManager.owned_weapons = prev_weapons
