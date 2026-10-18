extends RefCounted

## ÇİZİM KOMUTU / render-CPU DÖKÜMÜ (FPS turu 3, 2026-10-18; madde 272). fps_micro.gd `draw_sweep` kipinden çağrılır (h = harness SceneTree).
## Alt kip PG_SWEEP: boş/"ab"/"syn" (hepsi), "layers", "groups", "matgroups", "syntile", "synk", "reorder", "phases". Çıktı satırları "PG ..." ile başlar.
##  CENSUS (her kipte ilk iş; pencere gerekmez, --headless de çalışır): görünür CanvasItem'lar kategori başına, sınıf dağılımı, tahmini komut, TileMapLayer tablosu / quadrant /
##     materyal dökümü, yaratıkların ayak sırasına göre doku "koşuları".
##  ab        : kategori kategori RS düzeyinde GİZLEYİP render-CPU / çizim / kare farkı (taban - varyant - taban). Bir kategorinin TAM maliyetini verir.
##  syn/synk/syntile : sentetik düğüm/sprite/TileMapLayer'larla öğe başı maliyet, doku değişimi (toplu çizim kırılması) bedeli.
##  layers/groups/matgroups : TileMapLayer'ları tek tek / gruplar / materyal shader'ına göre gizle.
##  phases    : kare fazları (süreç / çizim / kuyruk=fizik) + görünüm başı render-CPU (kök, ZeminGorunumu SubViewport ...).
##  reorder   : Çimler hücrelerini yerinde yeniden sıralama (çizim sayısı değişmedi: quadrant içi sıra hücre koordinatına göre).
## TUZAKLAR (madde 272): (1) `_ab_interleaved` kare-kare A/B yalnız AYNI nesneler üzerinde güvenilir (doku ataması, görünürlük). ASIL katmanlar <-> KOPYA katmanlar kıyaslamak
##  YANILTTI: kopya katmanlar quadrant küçülünce ucuz görünüp gerçek oyunda (süreç düzeyi A/B) tam tersi çıktı. Oyuna girecek her render değişikliğinin hakemi
##  tools/fps_micro/proc_ab.ps1 (iki ayrı süreç, ortam anahtarı, ardışık tur). (2) Sadece kök görünümün render-CPU'su yetmez: SubViewport'lar da toplanır (_measure hepsini toplar).
##  (3) Çizim komutu SAYISI CPU'yu belirlemez (200 ek çizim = ölçülemeyen fark); maliyet öğe/komut sayısında.
## Çalıştırma: run.ps1 -Mode draw_sweep -Env "PG_N=200;PG_SETTLE=20;PG_SWEEP=phases" (varsayılan görünmez masaüstü; görünür pencere için -Visible -AllowWindow).

const PICKUP_GROUPS: Array[String] = ["xp_orbs", "gold_drops", "food_drops", "chest_drops", "magnet_drops", "shield_orb_drops"]

var h: SceneTree = null
var _hide_fn: Callable = Callable() ## () -> Array[RID]: bu karenin çizimi için RS düzeyinde gizlenecek canvas item'lar
var _hidden: Array[RID] = []


func run(harness: SceneTree) -> void:
	h = harness
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	RenderingServer.frame_post_draw.connect(_post_draw)
	h.process_frame.connect(_frame_start)
	var headless: bool = DisplayServer.get_name() == "headless"
	_census()
	if headless:
		print("PG SWEEP headless: A/B ve sentetik ölçüm atlandı (çizici yok)")
		return
	var which: String = OS.get_environment("PG_SWEEP") ## "" = hepsi | ab | syn | layers
	if which == "" or which == "ab":
		await _ab()
	if which == "" or which == "syn":
		await _synthetic()
	if which == "layers":
		await _layer_sweep()
	if which == "groups":
		await _group_sweep()
	if which == "syntile":
		await _syn_tile()
	if which == "synk":
		await _syn_batching()
	if which == "reorder":
		await _reorder_sweep()
	if which == "matgroups":
		await _matgroup_sweep()
	if which == "phases":
		for i in range(4):
			var m: Dictionary = await _measure(4.0)
			print("PG PHASES %s" % _fmt(m))
		var names: Array = []
		for sv in _viewport_nodes():
			names.append("%s %s upd=%d" % [String(sv.name), str((sv as SubViewport).size) if sv is SubViewport else "root", (sv as SubViewport).render_target_update_mode if sv is SubViewport else -1])
		var m2: Dictionary = await _measure(4.0)
		for vi in range(names.size()):
			print("PG PHASES viewport[%d] %-44s rcpu=%.3f ms" % [vi, names[vi], float((m2["per_vp"] as Array)[vi])])
	_hide_fn = Callable()


var _t_fs: int = 0 ## son process_frame (karenin başı)
var _t_pre: int = 0
var _t_post: int = 0
var _ph_logic: float = 0.0 ## başlangıç -> çizimden hemen önce (mantık + fizik)
var _ph_draw: float = 0.0 ## çizim aşaması (pre_draw -> post_draw: RenderingServer.draw, render-CPU burada)
var _ph_tail: float = 0.0 ## çizimden sonra -> sonraki karenin başı (present / bekleme / sonraki kareye hazırlık)
var _ph_n: int = 0


func _frame_start() -> void:
	var now: int = Time.get_ticks_usec()
	if _t_post > 0 and _t_fs > 0:
		_ph_tail += float(now - _t_post) / 1000.0
		_ph_n += 1
	_t_fs = now


func _pre_draw() -> void:
	_t_pre = Time.get_ticks_usec()
	if _t_fs > 0:
		_ph_logic += float(_t_pre - _t_fs) / 1000.0
	_hidden.clear()
	if _hide_fn.is_valid():
		var v: Array = _hide_fn.call()
		for r in v:
			_hidden.append(r)
			RenderingServer.canvas_item_set_visible(r, false)


func _post_draw() -> void:
	_t_post = Time.get_ticks_usec()
	_ph_draw += float(_t_post - _t_pre) / 1000.0
	for r in _hidden:
		RenderingServer.canvas_item_set_visible(r, true)
	_hidden.clear()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await h.process_frame


## sec boyunca ortalama kare / render-CPU / GPU / çizim sayısı.
func _viewports() -> Array[RID]:
	var out: Array[RID] = [h.root.get_viewport_rid()]
	var stack: Array[Node] = [h.root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			stack.append(c)
			if c is SubViewport:
				out.append((c as SubViewport).get_viewport_rid())
	return out


## TÜM görünümlerin (kök + SubViewport'lar: zemin dünya pikseli geçişi, güneş/bulut ...) render-CPU / GPU toplamı; "rcpu_root" yalnız kök görünüm.
func _measure(sec: float) -> Dictionary:
	var vps: Array[RID] = _viewports()
	for r in vps:
		RenderingServer.viewport_set_measure_render_time(r, true)
	var vp: RID = vps[0]
	await h.process_frame
	var arr: Array = []
	var rcpu: float = 0.0
	var rcpu_root: float = 0.0
	var per_vp: Array = []
	for _i in range(vps.size()):
		per_vp.append(0.0)
	var gpu: float = 0.0
	var draws: float = 0.0
	var t0: int = Time.get_ticks_usec()
	var last: int = t0
	_ph_logic = 0.0
	_ph_draw = 0.0
	_ph_tail = 0.0
	_ph_n = 0
	while float(Time.get_ticks_usec() - t0) / 1.0e6 < sec:
		await h.process_frame
		var now: int = Time.get_ticks_usec()
		arr.append(float(now - last) / 1000.0)
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		for vi in range(vps.size()):
			var c: float = RenderingServer.viewport_get_measured_render_time_cpu(vps[vi])
			rcpu += c
			per_vp[vi] += c
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vps[vi])
		rcpu_root += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	var n: int = maxi(1, arr.size())
	var s: float = 0.0
	for v in arr:
		s += float(v)
	arr.sort()
	var pn: float = maxf(1.0, float(_ph_n))
	var per_vp_avg: Array = []
	for v in per_vp:
		per_vp_avg.append(float(v) / n)
	return {"mean": s / n, "p95": arr[mini(n - 1, int(n * 0.95))], "rcpu": rcpu / n, "rcpu_root": rcpu_root / n, "gpu": gpu / n, "draws": draws / n, "n": n, "vps": vps.size(), "per_vp": per_vp_avg,
			"ph_logic": _ph_logic / pn, "ph_draw": _ph_draw / pn, "ph_tail": _ph_tail / pn}


func _fmt(m: Dictionary) -> String:
	return "frame=%.2f p95=%.2f rcpu=%.2f (kok %.2f, %d gorunum) gpu=%.2f draws=%.0f n=%d | logic=%.2f draw=%.2f tail=%.2f" % [m["mean"], m["p95"], m["rcpu"], m["rcpu_root"], m["vps"], m["gpu"], m["draws"], m["n"], m["ph_logic"], m["ph_draw"], m["ph_tail"]]


# ---------------------------------------------------------------------------------------------------------------------
# 1) CENSUS
# ---------------------------------------------------------------------------------------------------------------------
func _main_node() -> Node:
	return h.current_scene


func _cat_of_top(top: Node) -> String:
	if top.is_in_group("enemies"):
		return "enemy"
	if top.is_in_group("player_ally") or top.is_in_group("player_allies"):
		return "ally"
	if top == h.get("_player"):
		return "player"
	var sp: Variant = top.get_script()
	var sname: String = ""
	if sp != null:
		sname = String((sp as Script).resource_path).get_file().get_basename()
	if sname == "remote_player":
		return "remote_player"
	for g in PICKUP_GROUPS:
		if top.is_in_group(g):
			return "pickup"
	if top is CanvasLayer:
		return "layer:" + String(top.name)
	if String(top.name) == "Harita":
		return "map"
	if sname != "":
		return "main:" + sname
	return "main:" + top.get_class() + "/" + String(top.name)


## Düğümün çizim komutu tahmini (yaklaşık; Control/Label'da yazı = harf başına bir dikdörtgen).
func _cmd_estimate(n: CanvasItem) -> int:
	if n is Label:
		return 1 + (n as Label).text.length()
	if n is RichTextLabel:
		return 1 + (n as RichTextLabel).get_total_character_count()
	if n is Button:
		return 3 + (n as Button).text.length()
	if n is TileMapLayer:
		return (n as TileMapLayer).get_used_cells().size()
	if n is Sprite2D or n is AnimatedSprite2D or n is TextureRect or n is NinePatchRect or n is ColorRect or n is Line2D or n is Polygon2D \
			or n is MeshInstance2D or n is MultiMeshInstance2D or n is Panel or n is PanelContainer or n is ProgressBar or n is TextureProgressBar \
			or n is CPUParticles2D or n is GPUParticles2D:
		return 1
	return 0


class Cat:
	var items: int = 0 ## ağaçta var olan CanvasItem
	var visible: int = 0 ## görünür (ata zinciri dahil)
	var onscreen: int = 0 ## görünür ve ekran dikdörtgeninde (kabaca)
	var cmds: int = 0 ## görünür düğümlerin tahmini komutu
	var custom_draw: int = 0 ## görünür ve betiği _draw tanımlayan
	var classes: Dictionary = {} ## sınıf -> görünür sayı
	var nodes: Array = [] ## (A/B için) üst düğümler


var _cats: Dictionary = {}
var _world_rect: Rect2 = Rect2()
var _screen_rect: Rect2 = Rect2()


func _census() -> void:
	_cats.clear()
	var vp: Viewport = h.root
	_screen_rect = Rect2(Vector2.ZERO, vp.get_visible_rect().size)
	_world_rect = (vp.get_canvas_transform().affine_inverse() * _screen_rect).grow(64.0)
	var main: Node = _main_node()
	for child in h.root.get_children():
		if child == main:
			continue
		_census_walk(child, "autoload:" + String(child.name), false)
	for top in main.get_children():
		_census_walk(top, _cat_of_top(top), false)
	var names: Array = _cats.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return (_cats[a] as Cat).visible > (_cats[b] as Cat).visible)
	var tot_v: int = 0
	var tot_c: int = 0
	for nm in names:
		var c: Cat = _cats[nm]
		tot_v += c.visible
		tot_c += c.cmds
		var cl: Array = c.classes.keys()
		cl.sort_custom(func(a: String, b: String) -> bool: return int(c.classes[a]) > int(c.classes[b]))
		var parts: PackedStringArray = []
		for k in cl.slice(0, 6):
			parts.append("%s=%d" % [k, int(c.classes[k])])
		print("PG CENSUS cat=%-26s items=%5d visible=%5d onscreen=%5d cmds~%6d custom_draw=%3d | %s" % [nm, c.items, c.visible, c.onscreen, c.cmds, c.custom_draw, ", ".join(parts)])
	print("PG CENSUS TOTAL visible=%d cmds~%d" % [tot_v, tot_c])
	_tile_table()
	_tile_analysis()
	_quadrant_census()
	_quadrant_model()
	_layer_children()
	_material_census()
	_inspect_layers()
	_enemy_runs()


func _census_walk(n: Node, cat_name: String, in_layer: bool) -> void:
	var is_ci: bool = n is CanvasItem
	var c: Cat = _cats.get(cat_name)
	if c == null:
		c = Cat.new()
		_cats[cat_name] = c
	if is_ci:
		c.items += 1
		var ci: CanvasItem = n
		if ci.is_visible_in_tree():
			c.visible += 1
			var cls: String = n.get_class()
			c.classes[cls] = int(c.classes.get(cls, 0)) + 1
			var est: int = _cmd_estimate(ci)
			c.cmds += est
			var sp: Variant = n.get_script()
			if sp != null and n.has_method("_draw"):
				c.custom_draw += 1
				if est == 0:
					c.cmds += 1
			if est > 0 or (sp != null and n.has_method("_draw")):
				if in_layer:
					c.onscreen += 1
				elif n is Node2D:
					if _world_rect.has_point((n as Node2D).global_position):
						c.onscreen += 1
				elif n is Control:
					if _screen_rect.intersects((n as Control).get_global_rect()):
						c.onscreen += 1
				else:
					c.onscreen += 1
	var layer_now: bool = in_layer or n is CanvasLayer
	for ch in n.get_children():
		_census_walk(ch, cat_name, layer_now)


func _tile_table() -> void:
	var stack: Array[Node] = [h.root]
	var rows: Array = []
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for ch in nd.get_children():
			stack.append(ch)
			if ch is TileMapLayer:
				var t: TileMapLayer = ch
				var used: Array[Vector2i] = t.get_used_cells()
				var inview: int = 0
				if t.tile_set != null:
					var ts: Vector2i = t.tile_set.tile_size
					var wr: Rect2 = _world_rect
					for cell in used:
						if wr.has_point(t.to_global(Vector2(cell.x * ts.x + ts.x * 0.5, cell.y * ts.y + ts.y * 0.5))):
							inview += 1
				rows.append("PG CENSUS tilemap %-28s visible=%s cells=%6d inview=%6d quadrant=%3d ysort=%s z=%d mat=%s tile=%s" % [
						str(t.get_path()).get_slice("/", 4) if str(t.get_path()).count("/") >= 4 else str(t.name), str(t.is_visible_in_tree()), used.size(), inview,
						t.rendering_quadrant_size, str(t.y_sort_enabled), t.z_index, str(t.material != null), str(t.tile_set.tile_size) if t.tile_set != null else "-"])
	for r in rows:
		print(r)


## Yaratıkları ayak sırasıyla dizip ardışık AYNI dokuları sayar: çizim sırası bu olduğundan "koşu sayısı" ~ yaratık çizimi toplu çizim sayısıdır.
func _enemy_runs() -> void:
	var main: Node = _main_node()
	var items: Array = []
	for e in h.get_nodes_in_group("enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not (e as CanvasItem).is_visible_in_tree():
			continue
		if not _world_rect.has_point((e as Node2D).global_position):
			continue
		var tex_id: int = -1
		var spr: Node = e.get_node_or_null("Sprite2D")
		if spr is Sprite2D and (spr as Sprite2D).texture != null:
			tex_id = (spr as Sprite2D).texture.get_rid().get_id()
		else:
			var asp: Node = e.get_node_or_null("AnimatedSprite2D")
			if asp is AnimatedSprite2D:
				var a: AnimatedSprite2D = asp
				if a.sprite_frames != null and a.sprite_frames.has_animation(a.animation) and a.sprite_frames.get_frame_count(a.animation) > 0:
					var ft: Texture2D = a.sprite_frames.get_frame_texture(a.animation, a.frame)
					if ft != null:
						tex_id = (ft.atlas.get_rid().get_id() if ft is AtlasTexture and (ft as AtlasTexture).atlas != null else ft.get_rid().get_id())
		items.append(Vector2(float(main.call("_creature_foot_y", e)), float(tex_id)))
	items.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var runs: int = 0
	var last: float = -1.0e9
	var distinct: Dictionary = {}
	for it in items:
		distinct[int(it.y)] = true
		if it.y != last:
			runs += 1
			last = it.y
	print("PG CENSUS enemy_batches sprites=%d texture_runs=%d distinct_textures=%d (runs/sprite=%.2f)" % [items.size(), runs, distinct.size(), float(runs) / maxf(1.0, float(items.size()))])


# ---------------------------------------------------------------------------------------------------------------------
# 2) A/B: kategori kategori gizle
# ---------------------------------------------------------------------------------------------------------------------
func _rids_of_group(groups: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for g in groups:
		for n in h.get_nodes_in_group(g):
			if n is CanvasItem and is_instance_valid(n) and (n as CanvasItem).visible and not seen.has(n):
				seen[n] = true
				out.append((n as CanvasItem).get_canvas_item())
	return out


func _rids_of_main_children(cat_names: Array) -> Array:
	var out: Array = []
	for top in _main_node().get_children():
		if top is CanvasItem and (top as CanvasItem).visible and _cat_of_top(top) in cat_names:
			out.append((top as CanvasItem).get_canvas_item())
	return out


func _rids_enemy_empty() -> Array:
	var out: Array = []
	for e in h.get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e as CanvasItem).visible:
			continue
		for cn in ["CollisionShape2D", "HitArea"]:
			var c: Node = e.get_node_or_null(cn)
			if c is CanvasItem and (c as CanvasItem).visible:
				out.append((c as CanvasItem).get_canvas_item())
	return out


func _rids_of_main_other() -> Array:
	var out: Array = []
	var fixed: Array = ["enemy", "ally", "player", "remote_player", "pickup", "map"]
	for top in _main_node().get_children():
		if top is CanvasItem and (top as CanvasItem).visible:
			var c: String = _cat_of_top(top)
			if not (c in fixed) and not c.begins_with("layer:"):
				out.append((top as CanvasItem).get_canvas_item())
	return out


func _layers_named(substrs: Array) -> Array:
	var out: Array = []
	var stack: Array[Node] = [h.root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for ch in nd.get_children():
			stack.append(ch)
			if ch is CanvasLayer:
				var nm: String = String(ch.name).to_lower()
				for s in substrs:
					if nm.find(String(s)) >= 0:
						out.append(ch)
						break
	return out


func _ab() -> void:
	var main: Node = _main_node()
	var hud: Node = main.get_node_or_null("HUD")
	var variants: Array = []
	variants.append(["enemy", func() -> Array: return _rids_of_group(["enemies"])])
	variants.append(["ally", func() -> Array: return _rids_of_group(["player_ally", "player_allies"])])
	variants.append(["player+weapons", func() -> Array: return _rids_of_main_children(["player", "remote_player"])])
	variants.append(["pickup", func() -> Array: return _rids_of_group(PICKUP_GROUPS)])
	variants.append(["enemy_empty_nodes(3/5)", func() -> Array: return _rids_enemy_empty()])
	var dyn: Array = []
	for cn in _cats.keys():
		var cc: Cat = _cats[cn]
		if String(cn).begins_with("main:") and cc.onscreen >= 3:
			dyn.append(cn)
	dyn.sort_custom(func(a: String, b: String) -> bool: return (_cats[a] as Cat).onscreen > (_cats[b] as Cat).onscreen)
	for cn in dyn.slice(0, 6):
		var cn_c: String = cn
		variants.append([cn_c, func() -> Array: return _rids_of_main_children([cn_c])])
	var node_variants: Array = []
	var map_root: Node = main.get_node_or_null("Harita")
	if map_root is CanvasItem:
		node_variants.append(["map(Harita) hepsi", [map_root]])
		var tl: Array = []
		var sl: Array = []
		var stk: Array[Node] = [map_root]
		while not stk.is_empty():
			var nd: Node = stk.pop_back()
			for ch in nd.get_children():
				stk.append(ch)
				if ch is TileMapLayer:
					tl.append(ch)
				elif ch is Sprite2D:
					sl.append(ch)
		node_variants.append(["map: TileMapLayer'lar(%d)" % tl.size(), tl])
		node_variants.append(["map: Sprite2D'ler(%d)" % sl.size(), sl])
	if hud != null:
		node_variants.append(["hud", [hud]])
	for key in [["fog", ["fog", "vision"]], ["atmosphere/sun/weather", ["atmos", "sun", "cloud", "weather", "rain"]]]:
		var ls: Array = _layers_named(key[1])
		if not ls.is_empty():
			node_variants.append([key[0], ls])
	var dn: Node = main.get_node_or_null("DamageNumbers")
	if dn != null and dn is CanvasItem:
		node_variants.append(["damage_numbers", [dn]])
	## taban + her varyant, iki tur (ikinci tur ters sırada)
	var results: Dictionary = {} ## ad -> [Dictionary...]
	var bases: Array = []
	var all: Array = []
	for v in variants:
		all.append({"name": v[0], "fn": v[1], "nodes": []})
	for v in node_variants:
		all.append({"name": v[0], "fn": Callable(), "nodes": v[1]})
	for round_i in range(2):
		var seq: Array = all.duplicate()
		if round_i == 1:
			seq.reverse()
		for v in seq:
			_hide_fn = Callable()
			await _wait(0.4)
			var b: Dictionary = await _measure(3.0)
			bases.append(b)
			_apply_variant(v, true)
			await _wait(0.6)
			var m: Dictionary = await _measure(3.0)
			_apply_variant(v, false)
			if not results.has(v["name"]):
				results[v["name"]] = []
			(results[v["name"]] as Array).append({"base": b, "var": m})
			print("PG SWEEP raw cat=%s round=%d base[%s] var[%s]" % [v["name"], round_i, _fmt(b), _fmt(m)])
	_hide_fn = Callable()
	var base_r: float = 0.0
	var base_d: float = 0.0
	var base_f: float = 0.0
	for b in bases:
		base_r += float(b["rcpu"])
		base_d += float(b["draws"])
		base_f += float(b["mean"])
	base_r /= maxf(1.0, float(bases.size()))
	base_d /= maxf(1.0, float(bases.size()))
	base_f /= maxf(1.0, float(bases.size()))
	print("PG SWEEP BASE rcpu=%.2f draws=%.0f frame=%.2f (n=%d)" % [base_r, base_d, base_f, bases.size()])
	var order: Array = results.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return _delta(results[a], "rcpu") > _delta(results[b], "rcpu"))
	for nm in order:
		var rr: Array = results[nm]
		print("PG SWEEP cat=%-26s d_rcpu=%+.2f d_draws=%+.0f d_frame=%+.2f (hidden frees this much)" % [nm, -_delta(rr, "rcpu"), -_delta(rr, "draws"), -_delta(rr, "mean")])


func _delta(rr: Array, key: String) -> float:
	var s: float = 0.0
	for r in rr:
		s += float(r["base"][key]) - float(r["var"][key])
	return s / maxf(1.0, float(rr.size()))


func _apply_variant(v: Dictionary, on: bool) -> void:
	if on:
		if (v["fn"] as Callable).is_valid():
			_hide_fn = v["fn"]
		for nd in v["nodes"]:
			if nd is CanvasLayer:
				(nd as CanvasLayer).visible = false
			elif nd is CanvasItem:
				(nd as CanvasItem).visible = false
	else:
		_hide_fn = Callable()
		for nd in v["nodes"]:
			if nd is CanvasLayer:
				(nd as CanvasLayer).visible = true
			elif nd is CanvasItem:
				(nd as CanvasItem).visible = true


# ---------------------------------------------------------------------------------------------------------------------
# 3) SENTETİK: öğe başı maliyet + doku değişimi
# ---------------------------------------------------------------------------------------------------------------------
func _creature_textures() -> Array:
	var texs: Array = []
	var seen: Dictionary = {}
	var d: DirAccess = DirAccess.open("res://scenes/creatures")
	if d == null:
		return texs
	for f in d.get_files():
		if not f.begins_with("enemy_") or not f.ends_with(".tscn"):
			continue
		var ps: PackedScene = load("res://scenes/creatures/" + f)
		var inst: Node = ps.instantiate()
		var t: Variant = inst.get("walk_texture")
		if t is Texture2D and not seen.has((t as Texture2D).get_rid()):
			seen[(t as Texture2D).get_rid()] = true
			texs.append(t)
		inst.free()
	return texs


func _synthetic() -> void:
	var texs: Array = _creature_textures()
	print("PG SYN textures=%d" % texs.size())
	if texs.size() < 4:
		return
	var layer := CanvasLayer.new()
	layer.layer = 40
	h.root.add_child(layer)
	var holder := Node2D.new()
	layer.add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var vs: Vector2 = h.root.get_visible_rect().size
	## (a) boş düğümler: 200 ebeveyn x 3 boş çocuk (yaratığın CollisionShape2D / HitArea / HitCollision gibi)
	var empties := Node2D.new()
	holder.add_child(empties)
	for i in range(200):
		var p := Node2D.new()
		p.position = Vector2(rng.randf() * vs.x, rng.randf() * vs.y)
		empties.add_child(p)
		for j in range(3):
			p.add_child(Node2D.new())
	empties.visible = false
	## (b) 200 sprite (ekranda), K farklı dokudan rastgele sırada
	var sprites := Node2D.new()
	holder.add_child(sprites)
	var spr_list: Array = []
	for i in range(200):
		var s := Sprite2D.new()
		s.hframes = 6
		s.vframes = 4
		s.frame = 0
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.texture = texs[0]
		s.position = Vector2(rng.randf() * vs.x, rng.randf() * vs.y)
		sprites.add_child(s)
		spr_list.append(s)
	sprites.visible = false
	## (c) ekran dışı 200 sprite
	var offs := Node2D.new()
	holder.add_child(offs)
	for i in range(200):
		var s := Sprite2D.new()
		s.hframes = 6
		s.vframes = 4
		s.texture = texs[0]
		s.position = Vector2(8000.0 + rng.randf() * 500.0, rng.randf() * vs.y)
		offs.add_child(s)
	offs.visible = false
	## taban: hiçbiri görünür değil
	await _wait(1.0)
	var base0: Dictionary = await _measure(3.0)
	print("PG SYN base %s" % _fmt(base0))
	empties.visible = true
	await _wait(0.5)
	var m_empty: Dictionary = await _measure(3.0)
	print("PG SYN empties(800 Node2D)    %s | d_rcpu=%+.2f" % [_fmt(m_empty), float(m_empty["rcpu"]) - float(base0["rcpu"])])
	empties.visible = false
	offs.visible = true
	await _wait(0.5)
	var m_off: Dictionary = await _measure(3.0)
	print("PG SYN offscreen(200 sprite)  %s | d_rcpu=%+.2f" % [_fmt(m_off), float(m_off["rcpu"]) - float(base0["rcpu"])])
	offs.visible = false
	sprites.visible = true
	for k in [1, 2, 5, 10, 20, 40]:
		var kk: int = mini(k, texs.size())
		for i in range(spr_list.size()):
			(spr_list[i] as Sprite2D).texture = texs[rng.randi() % kk]
		await _wait(0.5)
		var base_k: Dictionary = base0
		sprites.visible = false
		await _wait(0.3)
		base_k = await _measure(2.0)
		sprites.visible = true
		await _wait(0.5)
		var m: Dictionary = await _measure(3.0)
		print("PG SYN sprites200 K=%-2d       %s | d_rcpu=%+.2f d_draws=%+.0f" % [kk, _fmt(m), float(m["rcpu"]) - float(base_k["rcpu"]), float(m["draws"]) - float(base_k["draws"])])
	layer.queue_free()


## Görünümdeki fayansları quadrant (16x16 hücre) ve ATLAS dokusu açısından çözümler: bir quadrant tek bir canvas item'dır; içinde ardışık komutlar aynı dokuyu
## kullanırsa tek toplu çizim olur, doku değişince yeni çizim başlar. Çizim sırası = quadrant içi hücre sırası (burada x sonra y varsayılır; gerçek sıra Godot'a bağlı).
func _tile_analysis() -> void:
	var stack: Array[Node] = [h.root]
	var layers: Array = []
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for ch in nd.get_children():
			stack.append(ch)
			if ch is TileMapLayer and (ch as TileMapLayer).is_visible_in_tree() and (ch as TileMapLayer).tile_set != null:
				layers.append(ch)
	var tot_items: int = 0
	var tot_cells: int = 0
	var tot_runs: int = 0
	var all_tex: Dictionary = {}
	var rows: Array = []
	for t in layers:
		var layer: TileMapLayer = t
		var ts: TileSet = layer.tile_set
		var tsz: Vector2i = ts.tile_size
		var q: int = layer.rendering_quadrant_size
		var quads: Dictionary = {} ## Vector2i(qx,qy) -> Array[Vector2i hücre]
		for cell in layer.get_used_cells():
			var wp: Vector2 = layer.to_global(Vector2(cell.x * tsz.x + tsz.x * 0.5, cell.y * tsz.y + tsz.y * 0.5))
			if not _world_rect.grow(float(q * tsz.x)).has_point(wp):
				continue
			var qk := Vector2i(int(floor(float(cell.x) / q)), int(floor(float(cell.y) / q)))
			if not quads.has(qk):
				quads[qk] = []
			(quads[qk] as Array).append(cell)
		if quads.is_empty():
			continue
		var cells: int = 0
		var runs: int = 0
		var texset: Dictionary = {}
		var ids_cache: Dictionary = {}
		for qk in quads.keys():
			var arr: Array = quads[qk]
			arr.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
			var last_id: int = -2
			for cell in arr:
				cells += 1
				var sid: int = layer.get_cell_source_id(cell)
				var tid: int = -1
				if ids_cache.has(sid):
					tid = ids_cache[sid]
				else:
					var src: TileSetSource = ts.get_source(sid) if ts.has_source(sid) else null
					if src is TileSetAtlasSource and (src as TileSetAtlasSource).texture != null:
						tid = (src as TileSetAtlasSource).texture.get_rid().get_id()
					ids_cache[sid] = tid
				texset[tid] = true
				all_tex[tid] = true
				if tid != last_id:
					runs += 1
					last_id = tid
		tot_items += quads.size()
		tot_cells += cells
		tot_runs += runs
		rows.append([cells, quads.size(), texset.size(), runs, String(layer.name), ts.resource_path.get_file()])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[3] > b[3])
	print("PG CENSUS tiles TOTAL layers_in_view=%d quadrant_items~%d cells=%d texture_runs~%d distinct_atlas_textures=%d (cells/item=%.1f)" % [rows.size(), tot_items, tot_cells, tot_runs, all_tex.size(), float(tot_cells) / maxf(1.0, float(tot_items))])
	for r in rows.slice(0, 16):
		print("PG CENSUS tiles layer=%-26s tileset=%-24s cells=%5d quadrants=%3d atlases=%2d runs=%4d" % [r[4], r[5], r[0], r[1], r[2], r[3]])


## Her TileMapLayer'ı TEK TEK gizleyip çizim sayısı + render-CPU farkını ölçer (çizim sayısı kesin, render-CPU gürültülü: 2 tur).
func _layer_sweep() -> void:
	var stack: Array[Node] = [h.root]
	var layers: Array = []
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for ch in nd.get_children():
			stack.append(ch)
			if ch is TileMapLayer and (ch as TileMapLayer).is_visible_in_tree() and (ch as TileMapLayer).tile_set != null:
				layers.append(ch)
	var rows: Array = [] ## [inview_cells, layer]
	for t in layers:
		var layer: TileMapLayer = t
		var tsz: Vector2i = layer.tile_set.tile_size
		var inview: int = 0
		for cell in layer.get_used_cells():
			if _world_rect.has_point(layer.to_global(Vector2(cell.x * tsz.x + tsz.x * 0.5, cell.y * tsz.y + tsz.y * 0.5))):
				inview += 1
		if inview > 0:
			rows.append([inview, layer])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("PG LAYERS in-view katman=%d" % rows.size())
	var take: int = mini(rows.size(), int(OS.get_environment("PG_LAYERS")) if OS.get_environment("PG_LAYERS") != "" else 24)
	var res: Array = []
	for round_i in range(2):
		for i in range(take):
			var layer2: TileMapLayer = rows[i][1]
			await _wait(0.3)
			var b: Dictionary = await _measure(1.5)
			layer2.visible = false
			await _wait(0.4)
			var m: Dictionary = await _measure(1.5)
			layer2.visible = true
			res.append([i, round_i, float(b["rcpu"]) - float(m["rcpu"]), float(b["draws"]) - float(m["draws"])])
	for i in range(take):
		var rc: float = 0.0
		var dr: float = 0.0
		var cnt: int = 0
		for r in res:
			if int(r[0]) == i:
				rc += float(r[2])
				dr += float(r[3])
				cnt += 1
		var layer3: TileMapLayer = rows[i][1]
		print("PG LAYERS #%02d %-26s inview=%5d total=%6d  frees: rcpu=%+.2f draws=%+.0f" % [i, String(layer3.name), rows[i][0], layer3.get_used_cells().size(), rc / maxf(1.0, float(cnt)), dr / maxf(1.0, float(cnt))])


## Katman GRUPLARI (zemin / Çimler / geri kalan / hepsi): tek katman farkı render-CPU gürültüsünde (±0,3 ms) kaybolduğundan gruplar, çok tur.
func _group_sweep() -> void:
	var stack: Array[Node] = [h.root]
	var all_layers: Array = []
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for ch in nd.get_children():
			stack.append(ch)
			if ch is TileMapLayer and (ch as TileMapLayer).is_visible_in_tree() and (ch as TileMapLayer).tile_set != null:
				all_layers.append(ch)
	var g1: Array = []
	var g2: Array = []
	var g3: Array = []
	for t in all_layers:
		var nm: String = String((t as TileMapLayer).name)
		if nm == "Zemin Toprak" or nm == "Zemin Çimen":
			g1.append(t)
		elif nm == "Çimler":
			g2.append(t)
		else:
			g3.append(t)
	var groups: Array = [["zemin(Toprak+Çimen)", g1], ["Çimler", g2], ["diger(%d katman)" % g3.size(), g3], ["HEPSI(%d)" % all_layers.size(), all_layers]]
	var rounds: int = int(OS.get_environment("PG_ROUNDS")) if OS.get_environment("PG_ROUNDS") != "" else 5
	var acc: Dictionary = {}
	for r in range(rounds):
		var seq: Array = groups.duplicate()
		if r % 2 == 1:
			seq.reverse()
		for g in seq:
			await _wait(0.3)
			var b: Dictionary = await _measure(2.5)
			for l in g[1]:
				(l as TileMapLayer).visible = false
			await _wait(0.4)
			var m: Dictionary = await _measure(2.5)
			for l in g[1]:
				(l as TileMapLayer).visible = true
			if not acc.has(g[0]):
				acc[g[0]] = []
			(acc[g[0]] as Array).append([float(b["rcpu"]) - float(m["rcpu"]), float(b["draws"]) - float(m["draws"]), float(b["mean"]) - float(m["mean"])])
	for g in groups:
		var rr: Array = acc[g[0]]
		var rs: Array = []
		var sd: float = 0.0
		var sdr: float = 0.0
		var sdf: float = 0.0
		for x in rr:
			rs.append(x[0])
			sd += x[1]
			sdr += x[0]
			sdf += x[2]
		var n: float = maxf(1.0, float(rr.size()))
		var mean_r: float = sdr / n
		var var_r: float = 0.0
		for v in rs:
			var_r += (float(v) - mean_r) * (float(v) - mean_r)
		print("PG GROUPS %-24s layers=%2d frees: rcpu=%+.2f (sd %.2f, n=%d) draws=%+.0f frame=%+.2f" % [g[0], (g[1] as Array).size(), mean_r, sqrt(var_r / n), rr.size(), sd / n, sdf / n])


## PG_INSPECT="Çimler,Çalılar": katmandaki kaynak/atlas dağılımı + fayans boyutları (bölme güvenli mi: üst üste binen büyük fayans var mı).
func _inspect_layers() -> void:
	var want: String = OS.get_environment("PG_INSPECT")
	if want == "":
		return
	var names: PackedStringArray = want.split(",")
	var stack: Array[Node] = [h.root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for ch in nd.get_children():
			stack.append(ch)
			if ch is TileMapLayer and names.has(String(ch.name)):
				var layer: TileMapLayer = ch
				var ts: TileSet = layer.tile_set
				var by_src: Dictionary = {}
				var big: int = 0
				var offs: int = 0
				var flips: int = 0
				var anim: int = 0
				var cells: Array[Vector2i] = layer.get_used_cells()
				for cell in cells:
					var sid: int = layer.get_cell_source_id(cell)
					by_src[sid] = int(by_src.get(sid, 0)) + 1
					var ac: Vector2i = layer.get_cell_atlas_coords(cell)
					var src: TileSetSource = ts.get_source(sid)
					if src is TileSetAtlasSource:
						var a: TileSetAtlasSource = src
						var sz: Vector2i = a.get_tile_size_in_atlas(ac)
						if sz != Vector2i.ONE:
							big += 1
						var td: TileData = a.get_tile_data(ac, 0)
						if td != null and td.texture_origin != Vector2i.ZERO:
							offs += 1
						if a.get_tile_animation_frames_count(ac) > 1:
							anim += 1
					if layer.get_cell_alternative_tile(cell) != 0:
						flips += 1
				print("PG INSPECT layer=%s cells=%d material=%s ysort=%s z=%d modulate=%s tex_filter=%d" % [layer.name, cells.size(), str(layer.material), str(layer.y_sort_enabled), layer.z_index, str(layer.modulate), layer.texture_filter])
				for sid in by_src.keys():
					var src2: TileSetSource = ts.get_source(sid)
					var tp: String = ""
					var rs: String = ""
					if src2 is TileSetAtlasSource:
						tp = (src2 as TileSetAtlasSource).texture.resource_path.get_file() if (src2 as TileSetAtlasSource).texture != null else "-"
						rs = str((src2 as TileSetAtlasSource).texture_region_size)
					print("PG INSPECT   source=%d cells=%d texture=%s region=%s" % [sid, by_src[sid], tp, rs])
				print("PG INSPECT   buyuk(size_in_atlas>1)=%d texture_origin!=0: %d alternatif/cevirme!=0: %d animasyonlu=%d" % [big, offs, flips, anim])


## Görünen TileMapLayer'ların materyalleri: ayrı örnek mi paylaşılan mı, hangi shader, katman başına. (PG_INSPECT dışında da çalışır.)
func _material_census() -> void:
	var stack: Array[Node] = [h.root]
	var by_mat: Dictionary = {} ## materyal rid -> [shader yolu, katman adları]
	var none: Array = []
	var total: int = 0
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for ch in nd.get_children():
			stack.append(ch)
			if ch is TileMapLayer and (ch as TileMapLayer).is_visible_in_tree():
				total += 1
				var m: Material = (ch as TileMapLayer).material
				if m == null:
					none.append(String(ch.name))
					continue
				var key: int = m.get_rid().get_id()
				var sh: String = ""
				if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
					sh = (m as ShaderMaterial).shader.resource_path.get_file()
					if sh == "":
						sh = "(gomulu shader #%d)" % (m as ShaderMaterial).shader.get_rid().get_id()
				elif m is CanvasItemMaterial:
					sh = "CanvasItemMaterial blend=%d" % (m as CanvasItemMaterial).blend_mode
				if not by_mat.has(key):
					by_mat[key] = [sh, []]
				(by_mat[key][1] as Array).append(String(ch.name))
	print("PG MATS gorunur katman=%d materyalsiz=%d (%s) farkli materyal ornegi=%d" % [total, none.size(), ", ".join(PackedStringArray(none.slice(0, 6))), by_mat.size()])
	for k in by_mat.keys():
		var arr: Array = by_mat[k][1]
		print("PG MATS   mat#%d shader=%s katman=%d (%s%s)" % [k, by_mat[k][0], arr.size(), ", ".join(PackedStringArray(arr.slice(0, 5))), ", ..." if arr.size() > 5 else ""])


## Görünen TileMapLayer'ları materyalin shader'ına göre gruplar (derinlik / sallanan ot / ağaç / düz renk / diğer) ve her grubu gizleyip serbest kalan render-CPU'yu ölçer.
func _matgroup_sweep() -> void:
	var stack: Array[Node] = [h.root]
	var groups: Dictionary = {} ## shader dosyası -> Array[TileMapLayer]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for ch in nd.get_children():
			stack.append(ch)
			if ch is TileMapLayer and (ch as TileMapLayer).is_visible_in_tree():
				var m: Material = (ch as TileMapLayer).material
				var key: String = "(materyalsiz)"
				if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
					key = (m as ShaderMaterial).shader.resource_path.get_file()
					if key == "":
						key = "(gomulu)"
				if not groups.has(key):
					groups[key] = []
				(groups[key] as Array).append(ch)
	var order: Array = groups.keys()
	var rounds: int = int(OS.get_environment("PG_ROUNDS")) if OS.get_environment("PG_ROUNDS") != "" else 5
	var acc: Dictionary = {}
	for r in range(rounds):
		var seq: Array = order.duplicate()
		if r % 2 == 1:
			seq.reverse()
		for k in seq:
			await _wait(0.3)
			var b: Dictionary = await _measure(2.5)
			for l in groups[k]:
				(l as TileMapLayer).visible = false
			await _wait(0.4)
			var m2: Dictionary = await _measure(2.5)
			for l in groups[k]:
				(l as TileMapLayer).visible = true
			if not acc.has(k):
				acc[k] = []
			(acc[k] as Array).append([float(b["rcpu"]) - float(m2["rcpu"]), float(b["draws"]) - float(m2["draws"]), float(b["mean"]) - float(m2["mean"])])
	for k in order:
		var rr: Array = acc[k]
		var sr: float = 0.0
		var sd: float = 0.0
		var sf: float = 0.0
		for x in rr:
			sr += x[0]
			sd += x[1]
			sf += x[2]
		var n: float = maxf(1.0, float(rr.size()))
		var mr: float = sr / n
		var vr: float = 0.0
		for x in rr:
			vr += (float(x[0]) - mr) * (float(x[0]) - mr)
		print("PG MATGROUPS %-30s layers=%2d frees: rcpu=%+.2f (sd %.2f, n=%d) draws=%+.0f frame=%+.2f" % [k, (groups[k] as Array).size(), mr, sqrt(vr / n), rr.size(), sd / n, sf / n])


## Haritanın TÜM katmanlarında (görünür/dışarıda) boş olmayan quadrant sayısı, quadrant boyutuna göre: ekran dışı quadrant item'ları da her karede ağaç gezintisinde
## (kırpma testi) dolaşılır; sparse katmanlarda quadrant sayısı hücre sayısına yakın olabilir.
func _quadrant_census() -> void:
	var stack: Array[Node] = [h.root]
	var sizes: Array = [16, 32, 64, 128]
	var tot: Dictionary = {}
	for q in sizes:
		tot[q] = 0
	var layers: int = 0
	var cells_all: int = 0
	var rows: Array = []
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for ch in nd.get_children():
			stack.append(ch)
			if ch is TileMapLayer and (ch as TileMapLayer).is_visible_in_tree() and (ch as TileMapLayer).tile_set != null:
				layers += 1
				var cells: Array[Vector2i] = (ch as TileMapLayer).get_used_cells()
				cells_all += cells.size()
				var per: Dictionary = {}
				for q in sizes:
					var set_: Dictionary = {}
					for c in cells:
						set_[Vector2i(int(floor(float(c.x) / q)), int(floor(float(c.y) / q)))] = true
					per[q] = set_.size()
					tot[q] = int(tot[q]) + set_.size()
				rows.append([int(per[16]), cells.size(), String(ch.name), int(per[64])])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("PG QUADS katman=%d hucre=%d  bos olmayan quadrant (tum harita): q16=%d q32=%d q64=%d q128=%d" % [layers, cells_all, tot[16], tot[32], tot[64], tot[128]])
	for r in rows.slice(0, 14):
		print("PG QUADS   %-28s q16=%5d cells=%6d q64=%4d (hucre/quadrant16=%.1f)" % [r[2], r[0], r[1], r[3], float(r[1]) / maxf(1.0, float(r[0]))])


func _tile_layers_visible() -> Array:
	var stack: Array[Node] = [h.root]
	var out: Array = []
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for ch in nd.get_children():
			stack.append(ch)
			if ch is TileMapLayer and (ch as TileMapLayer).is_visible_in_tree() and (ch as TileMapLayer).tile_set != null:
				out.append(ch)
	return out


func _mean(a: Array) -> float:
	var s: float = 0.0
	for v in a:
		s += float(v)
	return s / maxf(1.0, float(a.size()))


func _sd(a: Array) -> float:
	var m: float = _mean(a)
	var s: float = 0.0
	for v in a:
		s += (float(v) - m) * (float(v) - m)
	return sqrt(s / maxf(1.0, float(a.size())))


func _viewport_nodes() -> Array:
	var out: Array = [h.root]
	var stack: Array[Node] = [h.root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			stack.append(c)
			if c is SubViewport:
				out.append(c)
	return out


# ---------------------------------------------------------------------------------------------------------------------
# Çimler katmanı: hücre sırası / atlas bölme deneyi (çizim sayısı + render-CPU + görüntü eşitliği)
# ---------------------------------------------------------------------------------------------------------------------
func _find_layer(layer_name: String) -> TileMapLayer:
	for t in _tile_layers_visible():
		if String((t as TileMapLayer).name) == layer_name:
			return t
	return null


func _snapshot(layer: TileMapLayer) -> Array:
	var recs: Array = []
	for c in layer.get_used_cells():
		recs.append([c, layer.get_cell_source_id(c), layer.get_cell_atlas_coords(c), layer.get_cell_alternative_tile(c)])
	return recs


func _fill(layer: TileMapLayer, recs: Array) -> void:
	layer.clear()
	for r in recs:
		layer.set_cell(r[0], r[1], r[2], r[3])


## Çimler hücreleri (quadrant 16'ya göre) quadrant-major, kaynak-minor sıralı.
func _sorted_recs(recs: Array, q: int) -> Array:
	var buckets: Dictionary = {}
	for r in recs:
		var c: Vector2i = r[0]
		var key := Vector3i(int(floor(float(c.y) / q)), int(floor(float(c.x) / q)), int(r[1]))
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(r)
	var keys: Array = buckets.keys()
	keys.sort()
	var out: Array = []
	for k in keys:
		out.append_array(buckets[k])
	return out


func _capture() -> Image:
	return h.root.get_viewport().get_texture().get_image()


func _img_diff(a: Image, b: Image) -> int:
	if a.get_size() != b.get_size():
		return -1
	var da: PackedByteArray = a.get_data()
	var db: PackedByteArray = b.get_data()
	var n: int = 0
	for i in range(0, da.size(), 4):
		if da[i] != db[i] or da[i + 1] != db[i + 1] or da[i + 2] != db[i + 2]:
			n += 1
	return n


func _reorder_sweep() -> void:
	var layer: TileMapLayer = _find_layer("Çimler")
	if layer == null:
		print("PG REORDER Çimler bulunamadı")
		return
	h.set("_enemy_target", 0) ## donmuş kare karşılaştırmasında yeni yaratık doğmasın
	h.set("_walk", false)
	await _wait(1.0)
	var orig: Array = _snapshot(layer)
	var sorted16: Array = _sorted_recs(orig, 16)
	var by_src: Dictionary = {}
	for r in orig:
		by_src[int(r[1])] = int(by_src.get(int(r[1]), 0)) + 1
	print("PG REORDER Çimler hücre=%d kaynaklar=%s" % [orig.size(), str(by_src)])
	## --- görüntü eşitliği: zamanı dondur, taban yakala, tekrar yakala (kendi kendine fark), varyant yakala
	var saved_ts: float = Engine.time_scale
	Engine.time_scale = 0.0
	await _wait(0.5)
	await h.process_frame
	await h.process_frame
	var base_a: Image = _capture()
	await h.process_frame
	await h.process_frame
	var base_b: Image = _capture()
	print("PG REORDER donmus kare kendi farki (0 olmali): %d piksel" % _img_diff(base_a, base_b))
	_fill(layer, sorted16)
	await _wait(0.5)
	await h.process_frame
	await h.process_frame
	var v_sorted: Image = _capture()
	print("PG REORDER yerinde siralama: taban farki %d piksel" % _img_diff(base_a, v_sorted))
	_fill(layer, orig)
	Engine.time_scale = saved_ts
	await _wait(0.8)
	## --- sure/çizim: taban <-> yerinde sıralama
	var rounds: int = int(OS.get_environment("PG_ROUNDS")) if OS.get_environment("PG_ROUNDS") != "" else 5
	var dr: Array = []
	var dd: Array = []
	var df: Array = []
	for r in range(rounds):
		_fill(layer, orig)
		await _wait(1.0)
		var b: Dictionary = await _measure(2.5)
		_fill(layer, sorted16)
		await _wait(1.0)
		var m: Dictionary = await _measure(2.5)
		dr.append(float(b["rcpu"]) - float(m["rcpu"]))
		dd.append(float(b["draws"]) - float(m["draws"]))
		df.append(float(b["mean"]) - float(m["mean"]))
	_fill(layer, orig)
	print("PG REORDER yerinde sıralama frees: rcpu=%+.2f (sd %.2f) draws=%+.0f frame=%+.2f (n=%d)" % [_mean(dr), _sd(dr), _mean(dd), _mean(df), rounds])


## KARE KARE ARDIŞIK A/B (gürültü sürüklenmesini siler): çift karelerde set_a, tek karelerde set_b uygulanır; her karenin (tüm görünümler) render-CPU ve çizim sayısı
## o karenin durumuna yazılır. Dönüş: ortalama + medyan (ms) ve çizim sayısı, A ve B için.
func _ab_interleaved(set_a: Callable, set_b: Callable, frames: int) -> Dictionary:
	var vps: Array[RID] = _viewports()
	for r in vps:
		RenderingServer.viewport_set_measure_render_time(r, true)
	var ra: Array = []
	var rb: Array = []
	var da: Array = []
	var db: Array = []
	var prev: int = -1
	for i in range(frames + 4):
		await h.process_frame
		if prev >= 0 and i >= 4:
			var c: float = 0.0
			for r in vps:
				c += RenderingServer.viewport_get_measured_render_time_cpu(r)
			var d: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			if prev == 0:
				ra.append(c)
				da.append(d)
			else:
				rb.append(c)
				db.append(d)
		var st: int = i % 2
		if st == 0:
			set_a.call()
		else:
			set_b.call()
		prev = st
	return {"a_mean": _mean(ra), "b_mean": _mean(rb), "a_med": _median(ra), "b_med": _median(rb), "a_draws": _mean(da), "b_draws": _mean(db), "n": ra.size()}


func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b: Array = a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


func _env_int2(k: String, d: int) -> int:
	var v: String = OS.get_environment(k)
	return int(v) if v != "" else d


## Doku değişiminin (toplu çizim kırılması) kesin bedeli: aynı 200 sprite, A = hepsi TEK doku, B = K farklı doku rastgele sırada; kare kare ardışık.
func _syn_batching() -> void:
	var texs: Array = _creature_textures()
	if texs.size() < 8:
		print("PG SYNK doku az")
		return
	var layer := CanvasLayer.new()
	layer.layer = 40
	h.root.add_child(layer)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var vs: Vector2 = h.root.get_visible_rect().size
	var sprites: Array = []
	for i in range(200):
		var sp := Sprite2D.new()
		sp.hframes = 6
		sp.vframes = 4
		sp.frame = 0
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.texture = texs[0]
		sp.position = Vector2(rng.randf() * vs.x, rng.randf() * vs.y)
		layer.add_child(sp)
		sprites.append(sp)
	await _wait(1.0)
	for k in [5, 20, 40]:
		var kk: int = mini(k, texs.size())
		var assign: Array = []
		for i in range(sprites.size()):
			assign.append(texs[rng.randi() % kk])
		var a_fn: Callable = func() -> void:
			for sp in sprites:
				(sp as Sprite2D).texture = texs[0]
		var b_fn: Callable = func() -> void:
			for i in range(sprites.size()):
				(sprites[i] as Sprite2D).texture = assign[i]
		var ra: Array = []
		var rb: Array = []
		var da: Array = []
		var db: Array = []
		for r in range(4):
			var res: Dictionary = await _ab_interleaved(a_fn, b_fn, 300)
			ra.append(res["a_mean"])
			rb.append(res["b_mean"])
			da.append(res["a_draws"])
			db.append(res["b_draws"])
		print("PG SYNK K=%2d: rcpu tek-doku=%.3f karisik=%.3f -> doku degisim bedeli %+.3f ms | cizim %.0f -> %.0f (%+.0f cizim)" % [kk, _mean(ra), _mean(rb), _mean(rb) - _mean(ra), _mean(da), _mean(db), _mean(db) - _mean(da)])
	layer.queue_free()


## Quadrant boyutu maliyet modeli: aday katmanlar (Y-sıralı değil, hücre < PG_QLIMIT) için q başına TOPLAM item, görüşte item ve görüşteki item'larda işlenen hücre sayısı.
## Tahmin: maliyet ~ a*gorus_item + b*islenen_hucre + c*toplam_item (a, b, c ölçümle kalibre edilir, bkz. madde 272).
func _quadrant_model() -> void:
	var limit: int = int(OS.get_environment("PG_QLIMIT")) if OS.get_environment("PG_QLIMIT") != "" else 8000
	var qs: Array = [16, 24, 32, 48, 64, 96, 128]
	var tot_items: Dictionary = {}
	var view_items: Dictionary = {}
	var view_cells: Dictionary = {}
	for q in qs:
		tot_items[q] = 0
		view_items[q] = 0
		view_cells[q] = 0
	var layers: int = 0
	var vr: Rect2 = _world_rect
	for t in _tile_layers_visible():
		var layer: TileMapLayer = t
		if layer.y_sort_enabled:
			continue
		var cells: Array[Vector2i] = layer.get_used_cells()
		if cells.size() >= limit or cells.is_empty():
			continue
		layers += 1
		var tsz: Vector2i = layer.tile_set.tile_size
		for q in qs:
			var per: Dictionary = {}
			for c in cells:
				var qk := Vector2i(int(floor(float(c.x) / q)), int(floor(float(c.y) / q)))
				per[qk] = int(per.get(qk, 0)) + 1
			tot_items[q] = int(tot_items[q]) + per.size()
			for qk in per.keys():
				var origin: Vector2 = layer.to_global(Vector2(qk.x * q * tsz.x, qk.y * q * tsz.y))
				var rect := Rect2(origin, Vector2(q * tsz.x, q * tsz.y))
				if rect.intersects(vr):
					view_items[q] = int(view_items[q]) + 1
					view_cells[q] = int(view_cells[q]) + int(per[qk])
	for q in qs:
		print("PG QMODEL q=%3d aday_katman=%d toplam_item=%5d gorus_item=%4d gorusteki_item_hucre=%6d" % [q, layers, tot_items[q], view_items[q], view_cells[q]])


## Donmuş zamanda durum kurulduktan sonra görüntü YERLEŞENE kadar (iki ardışık yakalama aynı) bekler; en çok max_frames kare. Döner: [Image, yerleşti mi].
func _settled_capture(max_frames: int = 40) -> Array:
	var prev: Image = null
	var cur: Image = null
	for i in range(max_frames):
		await h.process_frame
		cur = _capture()
		if prev != null and _img_diff(prev, cur) == 0:
			return [cur, true]
		prev = cur
	return [cur, false]


## Sentetik TileMapLayer'larla maliyet kaynağı: gerçek TileSet, rastgele yerleşim; q16 <-> q4 kare kare ardışık (RS düzeyinde gizleme).
## Senaryolar: yoğun (görüşte 2000 hücre), seyrek (görüşün 10 katı alana saçılmış 300 hücre), seyrek + gerçek shader materyali.
func _syn_tile() -> void:
	var ref: TileMapLayer = _find_layer("Zemin Toprak")
	var mat_src: TileMapLayer = _find_layer("Çalılar")
	if ref == null:
		print("PG SYNTILE referans katman yok")
		return
	var ts: TileSet = ref.tile_set
	var sid: int = 0
	var ac: Vector2i = ref.get_cell_atlas_coords(ref.get_used_cells()[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var cam: Vector2 = h.root.get_canvas_transform().affine_inverse() * (h.root.get_visible_rect().size * 0.5)
	var scen: Array = [["yogun 2000 hucre", 2000, 1.0, false], ["seyrek 300 hucre / 10x alan", 300, 10.0, false], ["seyrek + gercek shader materyali", 300, 10.0, true]]
	var parent: Node = h.current_scene
	for sc in scen:
		var count: int = sc[1]
		var area_mult: float = sc[2]
		var vs: Vector2 = h.root.get_visible_rect().size * 0.9 * sqrt(area_mult)
		var made: Array = []
		for q in [16, 4]:
			var layer := TileMapLayer.new()
			layer.tile_set = ts
			layer.rendering_quadrant_size = q
			layer.collision_enabled = false
			layer.z_index = 5
			layer.global_position = Vector2.ZERO
			if sc[3] and mat_src != null:
				layer.material = mat_src.material
			parent.add_child(layer)
			rng.seed = 4242
			var used: Dictionary = {}
			while used.size() < count:
				var wp: Vector2 = cam + Vector2((rng.randf() - 0.5) * vs.x, (rng.randf() - 0.5) * vs.y)
				var cell := Vector2i(int(floor(wp.x / 16.0)), int(floor(wp.y / 16.0)))
				if not used.has(cell):
					used[cell] = true
					layer.set_cell(cell, sid, ac)
			made.append(layer)
		await _wait(1.0)
		var rid16: Array = [(made[0] as TileMapLayer).get_canvas_item()]
		var rid4: Array = [(made[1] as TileMapLayer).get_canvas_item()]
		var fn_hide4: Callable = func() -> Array: return rid4
		var fn_hide16: Callable = func() -> Array: return rid16
		var a_fn: Callable = func() -> void:
			_hide_fn = fn_hide4 ## q16 çizilir
		var b_fn: Callable = func() -> void:
			_hide_fn = fn_hide16 ## q4 çizilir
		var none_fn: Callable = func() -> Array: return rid16 + rid4
		var base_gain: Array = []
		var gains: Array = []
		var costs16: Array = []
		var costs4: Array = []
		for r in range(5):
			var res: Dictionary = await _ab_interleaved(a_fn, b_fn, 300)
			gains.append(float(res["a_mean"]) - float(res["b_mean"]))
			costs16.append(res["a_mean"])
			costs4.append(res["b_mean"])
		## her ikisi gizli taban
		var hide_all_a: Callable = func() -> void:
			_hide_fn = none_fn
		var show16_b: Callable = func() -> void:
			_hide_fn = fn_hide4
		var show4_b: Callable = func() -> void:
			_hide_fn = fn_hide16
		var r16: Array = []
		var r4: Array = []
		for r in range(4):
			var x: Dictionary = await _ab_interleaved(hide_all_a, show16_b, 300)
			r16.append(float(x["b_mean"]) - float(x["a_mean"]))
			var y: Dictionary = await _ab_interleaved(hide_all_a, show4_b, 300)
			r4.append(float(y["b_mean"]) - float(y["a_mean"]))
		print("PG SYNTILE %-34s q16 maliyeti=%+.3f ms  q4 maliyeti=%+.3f ms  (q16-q4 kazanc %+.3f, sd %.3f)" % [sc[0], _mean(r16), _mean(r4), _mean(gains), _sd(gains)])
		_hide_fn = Callable()
		for l in made:
			(l as Node).queue_free()
		await _wait(0.5)


## TileMapLayer'ların ÇOCUK düğümleri (kopya katmanlarla karşılaştırmayı bozar: asıl katman gizlenince çocukları da gizlenir) + materyal ve alt çizim bilgisi.
func _layer_children() -> void:
	var n_with: int = 0
	for t in _tile_layers_visible():
		var layer: TileMapLayer = t
		if layer.get_child_count() > 0:
			n_with += 1
			var cls: Dictionary = {}
			for c in layer.get_children():
				cls[c.get_class()] = int(cls.get(c.get_class(), 0)) + 1
			print("PG LCHILD %-28s cocuk=%3d %s" % [layer.name, layer.get_child_count(), str(cls)])
	print("PG LCHILD cocuklu katman sayisi=%d" % n_with)


