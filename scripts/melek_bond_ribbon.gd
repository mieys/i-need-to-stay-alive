extends Node2D

## Melek Q/E bağının İPİ (madde 212, "A Işık İpi"). melek_bond_fx.gd kurar; sahnenin çocuğudur (top_level, dünya koordinatı).
## Her karede: Melek'in halesinin dosta bakan altın pikseli (halo_point) -> dostun bel halkasının yakın kenarı; taban eğrisi
## boyunca geniş bir şerit ağı (RenderingServer üçgen dizisi, ~L/2 örnek) Melek'in SANAT PİKSELİ çözünürlüğündeki bir
## SubViewport'a çizilir (shaders/melek_bond.gdshader ipin kendisini boyar; her parça = bir sanat pikseli -> kıymık yok), sonra
## Sprite2D en yakın komşu ölçekle Melek'in piksel ızgarasına oturtur (ip halenin pikselinden kaymadan çıkar).
## Neden SubViewport: şeridi doğrudan dünyaya çizip piksel ızgarasına shader'da (türevle) oturtmak, sanat pikseli ~2,7 ekran
## pikseli olduğundan üçgen sınırlarında tek hücreyi iki tona bölüyordu (gerçek çizicide ince çizgiler görüldü).
## process_priority yüksek: karakterler bu karede yer değiştirdikten SONRA kurulur (yoksa ip bir kare geride kalır).
## Kuruluşta koşan baş parlaması glif sayfasının 9/10. karesi.

const BondMath := preload("res://scripts/melek_bond_math.gd")
const RIBBON_SHADER: Shader = preload("res://shaders/melek_bond.gdshader")
const GLYPH_TEX: Texture2D = preload("res://assets/fx/melek_bond/glyphs.png")
const GLYPH_N := 11
const VP_STEP := 32 ## SubViewport boyutu bu katlara büyür (her karede yeniden boyutlanmasın)

var bond: Node2D = null
var _mat: ShaderMaterial = null
var _head: Sprite2D = null
var _vp: SubViewport = null
var _ci: RID = RID()
var _spr: Sprite2D = null
var _idx := PackedInt32Array() ## üçgen indeksleri (örnek sayısı değişmedikçe aynı)
## Son kurulumun ip uzunluğu (sanat pikseli) - bağ varış hesabında kullanır.
var last_total: float = 0.0


func setup(p_bond: Node2D, kind: String) -> void:
	bond = p_bond
	top_level = true
	position = Vector2.ZERO
	z_index = 60
	process_priority = 100
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat = ShaderMaterial.new()
	_mat.shader = RIBBON_SHADER
	var pal: Array = BondMath.palette(kind)
	var hot: Array = BondMath.hot_palette(kind)
	_mat.set_shader_parameter("c_out", pal[1])
	_mat.set_shader_parameter("c_edge", pal[2])
	_mat.set_shader_parameter("c_mid", pal[3])
	_mat.set_shader_parameter("c_core", pal[4])
	_mat.set_shader_parameter("h_edge", hot[2])
	_mat.set_shader_parameter("h_mid", hot[3])
	_mat.set_shader_parameter("h_core", hot[4])
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_vp.size = Vector2i(VP_STEP, VP_STEP)
	add_child(_vp)
	_ci = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_ci, _vp.find_world_2d().canvas)
	RenderingServer.canvas_item_set_material(_ci, _mat.get_rid())
	_spr = Sprite2D.new()
	_spr.centered = false
	_spr.texture = _vp.get_texture()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.visible = false
	add_child(_spr)
	_head = Sprite2D.new()
	_head.texture = GLYPH_TEX
	_head.hframes = GLYPH_N
	_head.frame = 10 if kind == "shield" else 9
	_head.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_head.visible = false
	add_child(_head)


func _exit_tree() -> void:
	if _ci.is_valid():
		RenderingServer.free_rid(_ci)
		_ci = RID()


## İpin bu karedeki örnekleri + uç noktaları (kurulum ve testler ortak kullanır). Boş = çizilecek bir şey yok.
func compute() -> Dictionary:
	if bond == null or not is_instance_valid(bond):
		return {}
	var caster: Node2D = bond.get("caster")
	if caster == null or not is_instance_valid(caster):
		return {}
	var ring_c: Vector2 = bond.call("ring_world_center")
	var hp: Array = BondMath.halo_point(caster, ring_c)
	var p0: Vector2 = hp[0]
	var texel: float = maxf(float(hp[2]), 0.01)
	var side: float = -1.0 if ring_c.x >= p0.x else 1.0 ## halkanın Melek'e bakan kenarı
	var p1: Vector2 = ring_c + Vector2(side * (BondMath.RING_RX - 1.0), -1.0) * BondMath.TEXEL_W
	var p1a: Vector2 = (p1 - p0) / texel
	var total: float = BondMath.bezier_length(p1a)
	var t: float = float(bond.call("time_alive"))
	var head: float = BondMath.head_s(t, total)
	var smp: Dictionary = BondMath.ribbon_samples(p1a, t, bond.call("packets_at", total, head), head, float(bond.call("dissolve_amount")))
	last_total = float(smp["total"])
	return {"p0": p0, "p1": p1, "origin": hp[1], "texel": texel, "smp": smp, "head": head, "total": last_total}


func _process(_delta: float) -> void:
	_rebuild()


func _rebuild() -> void:
	if not _ci.is_valid():
		return
	RenderingServer.canvas_item_clear(_ci)
	var r: Dictionary = compute()
	if r.is_empty():
		_spr.visible = false
		_head.visible = false
		return
	var smp: Dictionary = r["smp"]
	var base: PackedVector2Array = smp["base"]
	var nrm: PackedVector2Array = smp["nrm"]
	var sv: PackedFloat32Array = smp["s"]
	var disp: PackedFloat32Array = smp["disp"]
	var hw: PackedFloat32Array = smp["hw"]
	var hot: PackedByteArray = smp["hot"]
	var texel: float = r["texel"]
	var origin: Vector2 = r["origin"]
	var total: float = r["total"]
	var head: float = r["head"]
	## Melek'in piksel ızgarasında sanat pikseli koordinatı: kök = halenin pikseli (tam sayı + 0,5)
	var p0g: Vector2 = ((r["p0"] as Vector2) - origin) / texel
	_mat.set_shader_parameter("total", total)
	var m: int = base.size()
	## görüntü kutusu: taban noktaları + şerit yarı genişliği (normaller birim)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in range(m):
		lo = lo.min(base[i])
		hi = hi.max(base[i])
	var pad: float = BondMath.STRIP_HALF + 3.0
	var bmin := Vector2i(int(floor(p0g.x + lo.x - pad)), int(floor(p0g.y + lo.y - pad)))
	var need := Vector2i(int(ceil(p0g.x + hi.x + pad)), int(ceil(p0g.y + hi.y + pad))) - bmin
	var cur: Vector2i = _vp.size
	if need.x > cur.x or need.y > cur.y:
		_vp.size = Vector2i(ceili(float(maxi(need.x, cur.x)) / VP_STEP) * VP_STEP, ceili(float(maxi(need.y, cur.y)) / VP_STEP) * VP_STEP)
	var org: Vector2 = p0g - Vector2(bmin)
	var nv: int = (m + 2) * 2
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(nv)
	cols.resize(nv)
	uvs.resize(nv)
	var w: float = BondMath.STRIP_HALF
	## uçlarda 2 sanat pikseli uzatma: son piksel şeridin kenarında kesilmesin (shader s<0 / s>total'ı atar)
	for i in range(-1, m + 1):
		var j: int = clampi(i, 0, m - 1)
		var b: Vector2 = base[j]
		var s: float = sv[j]
		if i < 0:
			b += (base[0] - base[1]).normalized() * 2.0
			s -= 2.0
		elif i >= m:
			b += (base[m - 1] - base[m - 2]).normalized() * 2.0
			s += 2.0
		var ja: int = maxi(j - 1, 0)
		var jb: int = mini(j + 1, m - 1)
		var ds: float = sv[jb] - sv[ja]
		var slope: float = (disp[jb] - disp[ja]) / ds if ds > 0.001 else 0.0
		var col := Color(clampf((disp[j] + 8.0) / 16.0, 0.0, 1.0), clampf(hw[j] / 4.0, 0.0, 1.0), float(hot[j]),
				clampf((slope + 3.0) / 6.0, 0.0, 1.0))
		var nw: Vector2 = nrm[j] * w
		var k: int = (i + 1) * 2
		verts[k] = org + b + nw
		verts[k + 1] = org + b - nw
		uvs[k] = Vector2(s, w)
		uvs[k + 1] = Vector2(s, -w)
		cols[k] = col
		cols[k + 1] = col
	if _idx.size() != (nv / 2 - 1) * 6:
		_idx = PackedInt32Array()
		_idx.resize((nv / 2 - 1) * 6)
		for q in range(nv / 2 - 1):
			var a: int = q * 2
			var o: int = q * 6
			_idx[o] = a
			_idx[o + 1] = a + 1
			_idx[o + 2] = a + 2
			_idx[o + 3] = a + 1
			_idx[o + 4] = a + 3
			_idx[o + 5] = a + 2
	RenderingServer.canvas_item_add_triangle_array(_ci, _idx, verts, cols, uvs)
	_spr.visible = true
	_spr.global_position = origin + Vector2(bmin) * texel
	_spr.scale = Vector2.ONE * texel
	## kuruluşta koşan baş parlaması (Melek'in piksel ızgarasına oturur)
	_head.visible = head < total
	if _head.visible:
		var hi_i: int = 0
		while hi_i < m - 1 and sv[hi_i] < head:
			hi_i += 1
		var hg: Vector2 = p0g + base[hi_i] + nrm[hi_i] * disp[hi_i]
		_head.global_position = origin + (hg.floor() + Vector2(0.5, 0.5)) * texel
		_head.scale = Vector2.ONE * texel
