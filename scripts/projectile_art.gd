extends RefCounted

## MERMİ SANATI (madde 201; prototip madde 199 tools/proto_20261017/mermi_proto.py, dokular tools/gen_mermi_sprites.py).
## Kullanıcı seçimi (2026-10-17): Yay + Arbalet (ikisi de A'nın oku; zaten aynı arrow_projectile sahnesi), Tüftüf, Fişek = A Zanaatkâr;
## Tabanca, Tüfek, Arcane, Buz = C Işık İzi. .tscn'lere dokunulmadı: görünüm projectile.gd _ready'de (_setup_trail) buradan kurulur -
## kaster ve diğer oyunculardaki kozmetik kopya AYNI sahne/betik olduğu için iki tarafta da aynı (ek RPC yok).
## Yoğunluk: doku pikseli = WeaponTierArt.WORLD_PX (0,575 dünya px, silahlarla aynı). Gövde kökün çocuğu: kök sahibin ölçeğiyle (0,5)
## çarpılır -> yerel ölçek PUPPET_ICON_SCALE (kritikte kök x1,4 -> gövde büyür). İz global ölçekle (WORLD_PX) sabitlenir, büyümez (eski iz gibi).
## Gövde + iz +x = uçuş yönü çizildi; yönü projectile.gd her fizik adımında direction'dan verir (silahın eski çapraz sprite ofseti
## ranged_projectile_rotation_offset gövdeyi döndürmesin).

const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")
const DIR := "res://assets/weapons/mermi/"
const WORLD_PX := WeaponTierArt.WORLD_PX
const LAUNCH_FRAMES := 3 ## iz dokusunda önce uzayan kareler (boyun %25/%50/%75'i), sonra "fly"
const LAUNCH_FPS := 30.0

## sahne adı -> doku adı (<ad>_govde.png / <ad>_iz.png), gövde kare sayısı + fps, iz "fly" kare sayısı + fps, iz offset.x (izin baş
## pikseli gövde pivotunun gerisinde; gen_mermi_sprites.py sonunda yazdırılan tabloyla AYNI olmalı - kare boyu dokudan okunur).
const ART := {
	"arrow_projectile": {"name": "ok", "bf": 1, "bfps": 1.0, "tf": 2, "tfps": 25.0, "tox": -21.5},
	"dart_projectile": {"name": "dart", "bf": 1, "bfps": 1.0, "tf": 2, "tfps": 25.0, "tox": -20.5},
	"tabanca_projectile": {"name": "tabanca", "bf": 1, "bfps": 1.0, "tf": 2, "tfps": 25.0, "tox": -16.5},
	"tufek_projectile": {"name": "tufek", "bf": 1, "bfps": 1.0, "tf": 2, "tfps": 25.0, "tox": -30.5},
	"arcane_projectile": {"name": "arcane", "bf": 4, "bfps": 14.0, "tf": 4, "tfps": 14.0, "tox": -23.5},
	"ice_bolt_projectile": {"name": "buz", "bf": 4, "bfps": 12.0, "tf": 2, "tfps": 12.0, "tox": -23.5},
}

## Fişek (A): uçan roket zaten silahın kademe ikonu (firework_projectile.gd set_art_tier); arkasına egzoz alevi + kısa duman (3 kare).
## Alev dokusu -x yönüne çizildi, tabanı sağ kenarda (FLAME_OFFSET_X). Roket ikonda çapraz (burun sağ-üst) -> alev -45 derece döner;
## FISEK_TAIL = kademe 1..5 roketinin kuyruk noktası (ikon doku pikseli, ikon merkezine göre; silah_zanaat_proto.py A_fisek: gövde
## sonu b0 = -4..-8, kanatçıklı kademelerde -1,8 geride, alev tabanı 0,8 içeride; çapraz çerçeve AS 0,955).
const FLAME_OFFSET_X := -10.0
const FLAME_FPS := 15.0
const FISEK_TAIL := [Vector2(-2.0, 3.0), Vector2(-3.55, 4.55), Vector2(-4.23, 5.23), Vector2(-4.9, 5.9), Vector2(-5.58, 6.58)]

static var _cache: Dictionary = {}


static func has_art(scene_key: String) -> bool:
	return ART.has(scene_key)


static func _frames(tex: Texture2D, n: int, anims: Array) -> SpriteFrames:
	## anims: [[ad, ilk kare, kare sayısı, fps, döngü], ...] - yatay şerit dokudan AtlasTexture kareleri.
	var sf := SpriteFrames.new()
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")
	var w: int = int(tex.get_width() / n)
	var h: int = tex.get_height()
	for a in anims:
		var nm := StringName(a[0])
		sf.add_animation(nm)
		sf.set_animation_speed(nm, float(a[3]))
		sf.set_animation_loop(nm, bool(a[4]))
		for i in range(int(a[1]), int(a[1]) + int(a[2])):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * w, 0, w, h)
			sf.add_frame(nm, at)
	return sf


static func body_frames(scene_key: String) -> SpriteFrames:
	var k := "body:" + scene_key
	if not _cache.has(k):
		var cfg: Dictionary = ART[scene_key]
		var tex: Texture2D = load(DIR + str(cfg["name"]) + "_govde.png")
		_cache[k] = _frames(tex, int(cfg["bf"]), [["fly", 0, int(cfg["bf"]), float(cfg["bfps"]), true]])
	return _cache[k]


static func trail_frames(scene_key: String) -> SpriteFrames:
	var k := "trail:" + scene_key
	if not _cache.has(k):
		var cfg: Dictionary = ART[scene_key]
		var tex: Texture2D = load(DIR + str(cfg["name"]) + "_iz.png")
		var tf: int = int(cfg["tf"])
		_cache[k] = _frames(tex, LAUNCH_FRAMES + tf, [["launch", 0, LAUNCH_FRAMES, LAUNCH_FPS, false],
				["fly", LAUNCH_FRAMES, tf, float(cfg["tfps"]), true]])
	return _cache[k]


static func fisek_flame_frames() -> SpriteFrames:
	if not _cache.has("flame"):
		_cache["flame"] = _frames(load(DIR + "fisek_alev.png"), 3, [["loop", 0, 3, FLAME_FPS, true]])
	return _cache["flame"]


static func fisek_tail(tier: int) -> Vector2:
	return FISEK_TAIL[clampi(tier, 1, FISEK_TAIL.size()) - 1]


## Gövdeyi (sahnedeki "Anim" AnimatedSprite2D ya da "Bullet" Sprite2D) yeni sanata çevirir ve izi ekler. İkisi de GİZLİ döner:
## projectile.gd ilk fizik adımında (yön belli olunca) çevirip açar. Dönüş: {"body": Node2D, "trail": AnimatedSprite2D}.
static func apply(proj: Node2D, scene_key: String, trail_tint: Color = Color.WHITE) -> Dictionary:
	var cfg: Dictionary = ART[scene_key]
	var body: Node2D = null
	var anim := proj.get_node_or_null("Anim") as AnimatedSprite2D
	var bullet := proj.get_node_or_null("Bullet") as Sprite2D
	if anim:
		anim.sprite_frames = body_frames(scene_key)
		anim.offset = Vector2.ZERO
		anim.centered = true
		body = anim
	elif bullet:
		bullet.texture = load(DIR + str(cfg["name"]) + "_govde.png")
		bullet.offset = Vector2.ZERO
		bullet.centered = true
		body = bullet
	if body:
		body.scale = Vector2.ONE * WeaponTierArt.PUPPET_ICON_SCALE
		body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		body.visible = false
	var trail := AnimatedSprite2D.new()
	trail.name = "ArtTrail"
	trail.sprite_frames = trail_frames(scene_key)
	trail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	trail.show_behind_parent = true ## gövde izin üstünde
	trail.centered = true
	trail.offset = Vector2(float(cfg["tox"]), 0.0)
	trail.modulate = trail_tint
	trail.visible = false
	proj.add_child(trail)
	trail.play("launch")
	trail.animation_finished.connect(func() -> void:
		if is_instance_valid(trail) and trail.animation == &"launch":
			trail.play("fly"))
	return {"body": body, "trail": trail}
