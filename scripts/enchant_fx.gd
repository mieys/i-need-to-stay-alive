extends RefCounted

## EFSUN GÖRSELLERİ - TEK KAYNAK (bkz. CLAUDE.md "yeni yetenek eklerken eskisi kalıyor" hata sınıfı).
## play()  = yerelde spawn() + NetworkManager.broadcast_enchant_fx ile diğer istemcilere AYNI çağrı.
## spawn() = sadece yerel; uzak istemcideki RPC de bunu çağırır -> kaster ile diğer oyuncular birebir aynı efekti görür.
## Kalıcı alanlar (lav, zehir bulutu, kovan, ok yağmuru...) enchant_area.gd'de; bunların uzak kopyası "area" türüyle gelir.
## Efsunlu mermilerin görünümü apply_projectile_look ile hem kasterde (weapon.gd) hem uzak kopyada (broadcast_projectile).
## Tüm çizimler pixel ızgarasında (PixelDraw) - bkz. hafıza "Pixel-style FX".

const ExplosionScene := preload("res://scenes/fx_korsan_explosion.tscn")
const ChainScene := preload("res://scenes/fx_lightning_chain.tscn")
const StormStrikeScene := preload("res://scenes/fx_storm_strike.tscn")
const FloatingTextScene := preload("res://scenes/floating_text.tscn")
const PixelDraw := preload("res://scripts/pixel_draw.gd")
const PixelFxScript := preload("res://scripts/fx_enchant_pixel.gd")
const ParticleTrail := preload("res://scripts/fx_particle_trail.gd")
const ENCHANT_AREA_PATH := "res://scripts/enchant_area.gd"


static func play(tree: SceneTree, kind: String, pos: Vector2, data: Dictionary = {}) -> void:
	spawn(tree, kind, pos, data)
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_enchant_fx.rpc(kind, pos, data)


static func spawn(tree: SceneTree, kind: String, pos: Vector2, data: Dictionary = {}) -> void:
	if tree == null or tree.current_scene == null:
		return
	var root: Node = tree.current_scene
	match kind:
		"explosion":
			var ex: Node2D = ExplosionScene.instantiate() as Node2D
			root.add_child(ex)
			ex.global_position = pos
			if ex.has_method("setup"):
				ex.setup(float(data.get("radius", 80.0)), Color(data.get("color", Color(1.0, 0.6, 0.2))))
		"chain":
			var ch: Node2D = ChainScene.instantiate() as Node2D
			root.add_child(ch)
			if ch.has_method("setup_positions"):
				ch.setup_positions(pos, Vector2(data.get("to", pos)))
			if data.has("color"):
				ch.modulate = Color(data["color"])
		"bolt":
			var bolt: Node2D = StormStrikeScene.instantiate() as Node2D
			bolt.set("warn_time", float(data.get("warn", 0.05)))
			bolt.set("play_sounds", bool(data.get("sound", false)))
			root.add_child(bolt)
			bolt.global_position = pos
		"burst":
			PixelDraw.spawn_burst(root, pos, str(data.get("palette", "spark")), int(data.get("count", 14)),
				float(data.get("speed", 140.0)), float(data.get("life", 0.5)))
		"bursts":
			## Tek RPC'de birden çok küçük patlama (Havai Fişek Gösterisi parçacıkları, buz kıymıkları).
			for pt in data.get("points", []):
				PixelDraw.spawn_burst(root, Vector2(pt), str(data.get("palette", "spark")), int(data.get("count", 8)),
					float(data.get("speed", 90.0)), float(data.get("life", 0.35)))
			if float(data.get("radius", 0.0)) > 0.0:
				for pt in data.get("points", []):
					spawn(tree, "ring", Vector2(pt), {"radius": float(data["radius"]), "color": Color(data.get("color", Color.WHITE)), "duration": 0.3})
		"text":
			var ft: Node2D = FloatingTextScene.instantiate() as Node2D
			root.add_child(ft)
			ft.global_position = pos + Vector2(0.0, -42.0)
			if ft.has_method("setup"):
				ft.setup(str(data.get("text", "")), Color(data.get("color", Color.WHITE)))
		"ring", "wave", "holy", "slam", "spark_ring":
			var px := Node2D.new()
			px.set_script(PixelFxScript)
			px.set("kind", kind)
			px.set("radius", float(data.get("radius", 80.0)))
			px.set("color", Color(data.get("color", Color.WHITE)))
			px.set("duration", float(data.get("duration", 0.45)))
			root.add_child(px)
			px.global_position = pos
		"area":
			var area_script: GDScript = load(ENCHANT_AREA_PATH) as GDScript
			area_script.spawn(tree, str(data.get("area", "")), pos, data, false)


## Efsunlu mermi görünümü: tint (Color), trail ("fire"/"ice"/"missile"), scale (çarpan), pierce (uzak kopya kaç düşmanın
## içinden geçsin - görsel), life (ek uçuş süresi sn).
static func apply_projectile_look(proj: Node2D, look: Dictionary) -> void:
	if proj == null or look.is_empty():
		return
	if look.has("tint"):
		proj.modulate = Color(look["tint"])
	if look.has("scale"):
		proj.scale *= float(look["scale"])
	if look.has("trail"):
		ParticleTrail.attach(proj, str(look["trail"]))
	if look.has("pierce"):
		proj.set_meta("visual_pierce", int(look["pierce"]))
	if look.has("life") and "_extra_life" in proj:
		proj.set("_extra_life", float(look["life"]))
	if look.has("apex_pause") and "apex_pause" in proj:
		proj.set("apex_pause", float(look["apex_pause"]))
