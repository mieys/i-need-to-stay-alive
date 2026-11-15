extends "res://scripts/mana_shield_fx.gd"

## KALKAN DARBE PROTOTİPİ (oyuna bağlı DEĞİL; yakala.gd kullanır). Mana Kalkanı efektinin alt sınıfı: "suan" = bugünkü
## darbe mührü (izometrik dönen disk), a-d = darbe baloncuğa DIŞARIDAN vurur. Yüzey baloncuğun kendi karesinden
## (ShieldVisual/BubbleSprite "loop") baloncuk_darbe.gdshader ile çizilir; kıvılcım/iz/flaş pikselleri _px_draw'da AYNI
## ızgarada (düğüm ölçeği = baloncuk texel'i, tam sayı konumlar) - madde 564 ek 4 dersi: tek ortak ızgara, blok blok
## kesirli konum yok.

const SURF_SHADER: Shader = preload("res://tools/proto_20261111/kalkan_darbe/baloncuk_darbe.gdshader")
const CANVAS := 48
const R := 11.0
const LIFE := 0.95
const DENT := 4.6 ## B: en derin çöküş (texel; shader DENT ile aynı)
const CONTACT := 0.06 ## D: dışarıdan gelen izin kenara varış süresi
const VARIANT_ID := {"a": 1, "b": 2, "c": 3, "d": 4, "e": 5}
## E (kullanıcı 2026-11-11: "A'yı seçiyorum fakat bir yerden menzilli hasar gelince D'nin seken darbesi gibi bir efekt olsun"):
## yakın dövüş = A yaması, menzilli = D sekmesi. MENZİLLİ KURALI (uzaklık DEĞİL - ilk deneme 70 birim eşiğiydi, Lich 65 birimden
## ateş edince yakın sayıldı): hasar MERMİ/YETENEK yolundan geldi = kaynak yaratık is_ranged (normal saldırısı enemy_projectile
## mermisi) YA DA o an işlenen yaratık yeteneği türü RANGED_KINDS'te (take_special_damage -> BalanceLog.set_taken_kind; kemik,
## ateş topu, lazer...). Oyuna alınırken: enemy_projectile.gd + bu yetenekler take_damage'e "menzilli" bilgisini kendisi verir,
## player.gd mana_fx.hit(açı, broke, menzilli)'ye geçirir; prototip kaynağı göremediği için TAM o açıdaki yaratığı bulur (_is_ranged).
const RANGED_KINDS := ["bone", "fireball", "laser", "rock", "bossfire", "demonfire", "cosmic"]
const BalanceLogS := preload("res://scripts/balance_log.gd")
const KIND_A := 1.0
const KIND_D := 4.0

var variant: String = "suan"
var _p_surf: Node2D = null
var _spr: Sprite2D = null
var _px_node: Node2D = null
var _smat: ShaderMaterial = null
var _p_hits: Array = [] ## {"angle": float, "age": float, "spark": Array}
var _p_clock: float = 0.0
var _light: Color = Color(0.8, 1.0, 0.7)
var _light_key: String = ""
var last_hit_ranged: bool = false ## yakala_gercek.gd günlüğü için
var last_hit_info: String = "" ## günlük: kaynağın uzaklığı + adı (yoksa "kaynak-yok")


func _ready() -> void:
	super()
	if variant == "suan":
		return
	var bub: Node2D = host.get_node_or_null("ShieldVisual/BubbleSprite") as Node2D
	var sv: Node2D = host.get_node_or_null("ShieldVisual") as Node2D
	_p_surf = Node2D.new()
	_p_surf.name = "BubbleHitProto"
	_p_surf.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_p_surf.position = (sv.position if sv else Vector2.ZERO) + (bub.position if bub else Vector2.ZERO)
	_p_surf.scale = bub.scale if bub else Vector2(4.37475, 4.37475)
	host.add_child.call_deferred(_p_surf) ## karakter sprite'ından ve baloncuktan SONRA çizilir
	var img := Image.create(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	_spr = Sprite2D.new()
	_spr.texture = ImageTexture.create_from_image(img)
	_spr.centered = true
	_smat = ShaderMaterial.new()
	_smat.shader = SURF_SHADER
	_smat.set_shader_parameter("variant", int(VARIANT_ID.get(variant, 1)))
	_smat.set_shader_parameter("canvas_px", float(CANVAS))
	_smat.set_shader_parameter("contact_delay", CONTACT if variant == "d" else 0.0)
	_spr.material = _smat
	_spr.visible = false
	_p_surf.add_child(_spr)
	_px_node = Node2D.new()
	_p_surf.add_child(_px_node)
	_px_node.draw.connect(_px_draw)


func hit(angle: float, broke: bool) -> void:
	if variant == "suan":
		super.hit(angle, broke)
		return
	if _is_suppressed() or broke:
		return
	var kind := KIND_A
	if variant == "d":
		kind = KIND_D
	elif variant == "e":
		last_hit_ranged = _is_ranged(angle)
		kind = KIND_D if last_hit_ranged else KIND_A
	var sparks: Array = []
	for off: float in [-1.05, -0.45, 0.45, 1.05]:
		sparks.append(off + randf_range(-0.15, 0.15))
	_p_hits.append({"angle": angle, "age": 0.0, "spark": sparks, "reach": randf_range(7.5, 9.5), "kind": kind})
	if _p_hits.size() > 4:
		_p_hits.pop_front()


func _process(delta: float) -> void:
	super(delta)
	if _p_surf == null:
		return
	_p_clock += delta
	for i in range(_p_hits.size() - 1, -1, -1):
		_p_hits[i]["age"] = float(_p_hits[i]["age"]) + delta
		if float(_p_hits[i]["age"]) >= LIFE:
			_p_hits.remove_at(i)
	_spr.visible = not _p_hits.is_empty()
	if _spr.visible:
		_bind_frame()
		var ang := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
		var ages := PackedFloat32Array([-1.0, -1.0, -1.0, -1.0])
		var kinds := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
		for i in _p_hits.size():
			ang[i] = float(_p_hits[i]["angle"])
			ages[i] = float(_p_hits[i]["age"])
			kinds[i] = float(_p_hits[i]["kind"])
		_smat.set_shader_parameter("hit_kind", kinds)
		_smat.set_shader_parameter("hit_angle", ang)
		_smat.set_shader_parameter("hit_age", ages)
	_px_node.queue_redraw()


## E: hasar menzilli mi? take_damage açıyı (kaynak - oyuncu).angle() ile hesaplar; aynı karede o açıda duran yaratık kaynaktır.
## Kaynak bulunamazsa (ölmüş / null -> rastgele açı) yalnız yetenek türüne bakılır.
func _is_ranged(angle: float) -> bool:
	var best := INF
	var src_node: Node = null
	for e in host.get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or not is_instance_valid(e):
			continue
		var dv: Vector2 = (e as Node2D).global_position - host.global_position
		if dv.length_squared() < 1.0:
			continue
		if absf(angle_difference(dv.angle(), angle)) < 0.004 and dv.length() < best:
			best = dv.length()
			src_node = e
			last_hit_info = "%d %s" % [int(best), (e as Node).name]
	var src_ranged := false
	if best == INF:
		last_hit_info = "kaynak-yok"
	else:
		src_ranged = bool(src_node.get("is_ranged")) if src_node != null and is_instance_valid(src_node) else false
	var kind: String = BalanceLogS._taken_kind
	last_hit_info += " is_ranged=%s tur=%s" % [str(src_ranged), kind if kind != "" else "-"]
	return src_ranged or RANGED_KINDS.has(kind)


## Baloncuğun o anki "loop" karesi (tür değişince sprite_frames da değişir) + ondan türeyen açık ton.
func _bind_frame() -> void:
	var bub: AnimatedSprite2D = host.get_node_or_null("ShieldVisual/BubbleSprite") as AnimatedSprite2D
	if bub == null or bub.sprite_frames == null or not bub.sprite_frames.has_animation("loop"):
		return
	var n: int = bub.sprite_frames.get_frame_count("loop")
	var tex := bub.sprite_frames.get_frame_texture("loop", int(_p_clock * 10.0) % maxi(n, 1)) as AtlasTexture
	if tex == null:
		return
	_smat.set_shader_parameter("sheet", tex.atlas)
	_smat.set_shader_parameter("sheet_size", tex.atlas.get_size())
	_smat.set_shader_parameter("frame_rect", Vector4(tex.region.position.x, tex.region.position.y, tex.region.size.x, tex.region.size.y))
	var key := str(tex.atlas.resource_path)
	if key != _light_key:
		_light_key = key
		var im: Image = tex.atlas.get_image()
		if im:
			if im.is_compressed():
				im.decompress()
			var acc := Vector3.ZERO
			var cnt := 0
			for y in range(int(tex.region.position.y), int(tex.region.end.y)):
				for x in range(int(tex.region.position.x), int(tex.region.end.x)):
					var c := im.get_pixel(x, y)
					if c.a > 0.55:
						acc += Vector3(c.r, c.g, c.b)
						cnt += 1
			if cnt > 0:
				acc /= float(cnt)
				_light = Color(acc.x, acc.y, acc.z).lerp(Color.WHITE, 0.45)
		_smat.set_shader_parameter("light_col", Vector3(_light.r, _light.g, _light.b))


func _p_dot(p: Vector2, col: Color) -> void:
	_px_node.draw_rect(Rect2(p.floor(), Vector2.ONE), col)


func _plus(c: Vector2, arm: int, col: Color) -> void:
	_p_dot(c, col)
	for k in range(1, arm + 1):
		for o: Vector2 in [Vector2(k, 0), Vector2(-k, 0), Vector2(0, k), Vector2(0, -k)]:
			_p_dot(c + o, col)


func _diamond(c: Vector2, r: int, col: Color) -> void:
	for x in range(-r, r + 1):
		var y := r - absi(x)
		_p_dot(c + Vector2(x, y), col)
		if y != 0:
			_p_dot(c + Vector2(x, -y), col)


## Ortak ızgarada pikseller: darbe flaşı (A/B/C), dışarıdan gelen iz + seken kıvılcımlar (D), cana geçen 2 turuncu piksel (hepsi).
func _px_draw() -> void:
	var light := _light
	var dim := Color(_light.r, _light.g, _light.b, 0.55)
	for h: Dictionary in _p_hits:
		var a: float = h["angle"]
		var age: float = h["age"]
		var n := Vector2(cos(a), sin(a))
		var t := age
		if float(h["kind"]) == KIND_D:
			if variant == "d" and age < CONTACT: ## yalnız saf D: dışarıdan gelen iz (E'de mermi zaten kendisi gelir)
				var head := n * (R + 0.5 + 9.0 * (1.0 - age / CONTACT))
				_p_dot(head, Color.WHITE)
				_p_dot(head + n, CREAM)
				_p_dot(head + n * 2.0, light)
				_p_dot(head + n * 3.0, dim)
				continue
			if variant == "d":
				t = age - CONTACT
			var hit_p := n * (R + 0.5)
			if t < 0.06:
				_plus(hit_p, 2, Color.WHITE)
			elif t < 0.12:
				for o: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
					_p_dot(hit_p + o, light)
				_p_dot(hit_p, CREAM)
			var u := clampf(t / 0.32, 0.0, 1.0)
			if u < 1.0:
				var reach: float = h["reach"]
				for off: float in h["spark"]:
					var dir := Vector2(cos(a + off), sin(a + off))
					var p := hit_p + dir * (0.5 + reach * (1.0 - pow(1.0 - u, 2.0)))
					_p_dot(p, Color.WHITE if u < 0.35 else light)
					if u < 0.7:
						_p_dot(p - dir, light if u < 0.35 else dim)
					if u < 0.35:
						_p_dot(p - dir * 2.0, dim)
		else:
			var rp := R - 0.5
			if variant == "b":
				var s := t / 0.05 if t < 0.05 else exp(-(t - 0.05) * 7.0) * cos((t - 0.05) * 24.0)
				rp = R - 0.5 - DENT * maxf(s, 0.0)
			var c := n * rp
			if t < 0.06:
				_plus(c, 1, Color.WHITE)
			elif t < 0.14:
				_diamond(c, 2, light)
	## Bugünkü efektin 2 turuncu "cana geçen pay" kıvılcımı burada YOK: baloncuk ızgarasında (texel ~2,2 dünya) iri
	## kalıp kuzey darbesinde yüzde "kırmızı göz" gibi okunuyordu (ilk çekim).
