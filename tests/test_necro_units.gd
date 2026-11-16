extends Node

## Necromancer iskelet birlikleri (2026-11-16): tools/necro_iskelet/build_frames.py'nin ürettiği SpriteFrames'ler oyunun
## beklediği biçimde mi - her birimde 5 yönlü temel animler var, bir birimin TÜM kareleri aynı toplam boyda (region + margin
## = paketteki tuval; yoksa centered sprite kare kare zıplar ve flip_h gövde ortasından aynalamaz), ayak ofseti makul.

const NecroUnits := preload("res://scripts/necro_units.gd")

const REQUIRED := ["idle", "walk", "attack", "hurt", "death"]


func test_every_unit_has_five_direction_core_animations() -> void:
	for key in NecroUnits.UNITS:
		var frames: SpriteFrames = load(NecroUnits.UNITS[key]["frames"])
		assert(frames != null, "%s frames yüklenmedi" % key)
		for base in REQUIRED:
			for d in NecroUnits.DIRS:
				var n: String = base + "_" + d
				assert(frames.has_animation(n), "%s: %s yok" % [key, n])
				assert(frames.get_frame_count(n) > 0, "%s: %s boş" % [key, n])
		## doğuş: standartta yönlü, hayalette yönsüz - anim_name ikisini de çözmeli (büyücüde rise yok, idle'a düşer)
		var rise: String = NecroUnits.anim_name(frames, "rise", "e")
		assert(frames.has_animation(rise), "%s: rise çözülemedi (%s)" % [key, rise])


func test_all_frames_of_a_unit_share_the_canvas_size() -> void:
	for key in NecroUnits.UNITS:
		var u: Dictionary = NecroUnits.UNITS[key]
		var canvas: Vector2 = Vector2(u["canvas"])
		var frames: SpriteFrames = load(u["frames"])
		for anim in frames.get_animation_names():
			for i in frames.get_frame_count(anim):
				var tex: Texture2D = frames.get_frame_texture(anim, i)
				assert(tex.get_size() == canvas, "%s %s[%d]: boy %s != tuval %s" % [key, anim, i, tex.get_size(), canvas])


func test_feet_offset_puts_feet_below_center() -> void:
	for key in NecroUnits.UNITS:
		var u: Dictionary = NecroUnits.UNITS[key]
		var off: Vector2 = u["offset"]
		## ayaklar tuvalin alt yarısında -> ofset yukarı (negatif), tuvalin yarısından küçük
		assert(off.x == 0.0, "%s: x ofseti sıfır olmalı (flip gövde ortasından)" % key)
		assert(off.y < 0.0 and off.y > -float(u["canvas"].y) / 2.0, "%s: ayak ofseti %s" % [key, off])
		assert(int(u["body_h"]) >= 20, "%s: gövde boyu %s" % [key, u["body_h"]])


func test_knight_and_mage_extra_animations() -> void:
	for key in ["knight", "ghost_knight"]:
		var f: SpriteFrames = load(NecroUnits.UNITS[key]["frames"])
		for base in ["attack2", "attack3", "block"]:
			assert(f.has_animation(base + "_e"), "%s: %s_e yok" % [key, base])
	var mage: SpriteFrames = load(NecroUnits.UNITS["mage"]["frames"])
	assert(mage.has_animation("cast_s") and mage.has_animation("summon_s"), "büyücü cast/summon yok")


func test_dir_of_maps_eight_ways_with_mirroring() -> void:
	assert(NecroUnits.dir_of(Vector2.RIGHT) == ["e", false])
	assert(NecroUnits.dir_of(Vector2.LEFT) == ["e", true])
	assert(NecroUnits.dir_of(Vector2(1, -1)) == ["ne", false])
	assert(NecroUnits.dir_of(Vector2(-1, 1)) == ["se", true])
	## tam kuzey/güney önceki aynalamayı korur
	assert(NecroUnits.dir_of(Vector2.UP, true) == ["n", true])
	assert(NecroUnits.dir_of(Vector2.DOWN, false) == ["s", false])
	assert(NecroUnits.dir_of(Vector2.ZERO, true) == ["s", true])


func test_fx_strips_exist() -> void:
	for key in NecroUnits.FX:
		var row: Array = NecroUnits.FX[key]
		var tex: Texture2D = load(row[0])
		assert(tex != null, "fx %s yüklenmedi" % key)
		assert(tex.get_width() == int(row[1]) * int(row[3]) and tex.get_height() == int(row[2]), "fx %s boyu" % key)


## 2026-11-16 (kullanıcı: "gölgesi yok", "biraz büyümeli", "Y ekseni sorunları", R askerleri "mavi tonlarında"):
## main.gd ayak ölçümü kırpılmış AtlasTexture'ın üst boşluğunu sayar (idle S ayağı = düğüm kökü); birlik gölgesi Sprite'tan önce;
## ayak meta'sı sabit 0 (doğuştaki rise karesi ölçülmez); ordu normal iskelet anahtarlarıyla.
func test_foot_line_shadow_and_army_look() -> void:
	var probe: AnimatedSprite2D = AnimatedSprite2D.new()
	for key in NecroUnits.UNITS:
		var u: Dictionary = NecroUnits.UNITS[key]
		probe.sprite_frames = load(u["frames"])
		probe.animation = &"idle_s"
		probe.offset = u["offset"]
		var foot: float = _foot_local_via_main(probe)
		assert(absf(foot) <= 1.0, "%s: idle S ayağı kökte olmalı (%.1f)" % [key, foot])
	probe.free()
	assert(is_equal_approx(NecroUnits.WORLD_SCALE, 1.0), "ölçek 1,0 (0,9 -> 1,1 fazla büyük geldi)")
	var unit: Node2D = (load("res://scenes/necro_soldier.tscn") as PackedScene).instantiate()
	add_child(unit)
	var sh: Node2D = unit.get_node_or_null("Shadow") as Node2D
	assert(sh != null and sh.get_index() < unit.get_node("Sprite").get_index(), "gölge Sprite'tan önce")
	assert(unit.unit_key == "common", "ordu askeri varsayılanı normal iskelet: %s" % unit.unit_key)
	assert(is_equal_approx(float(unit.get_meta("_foot_local")), 0.0) and unit.get_meta("_foot_visual") == unit.get_node("Sprite"), "ayak meta'sı")
	var ext: Vector2 = unit.get_meta("_depth_extent")
	assert(ext.y < 42.0 and ext.y > 22.0, "derinlik boyu gövdeden: %s" % ext)
	assert(Vector2(sh.get("radius")).x >= 8.0, "gölge yarıçapı")
	unit.queue_free()
	var NecroMath: GDScript = load("res://scripts/necro_army_math.gd")
	for k in NecroMath.army_units(18):
		assert(not String(k).begins_with("ghost_"), "ordu hayalet değil: %s" % k)


## main.gd'nin _visual_foot_local'ı bir örnek üzerinde (Main'in _ready'si çalışmadan) çağrılır.
func _foot_local_via_main(vis: Node2D) -> float:
	var m: Object = (load("res://scripts/main.gd") as GDScript).new()
	var r: float = float(m.call("_visual_foot_local", vis))
	if m is Node:
		(m as Node).free()
	return r
