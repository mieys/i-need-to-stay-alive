extends RefCounted

## Kalkan "Hayalet Kalkan" darbesi + yönlü görünüş - TEK kaynak (weapon.gd = gerçek/yetkili silah, remote_player.gd = diğer
## istemcilerdeki kozmetik kopya). Kullanıcı seçimi 2026-10-20 (madde 330/333 prototipleri -> madde 338): görünüş B "Şövalye",
## efekt D "Hayalet Kalkan". Kullanıcı: "kalkanın yan pozisyonları olmalı, böyle vurunca vurduğu hissedilmez" -> kalkan DÖNMEZ,
## yüzü baktığı yöne dönük görünüş seçilir: 5 görünüş (ön / 50° / 72° yan / 130° / arka) + sola bakanlar flip_h (8 yön).
## Darbe: yüzünü hedefe çevirip hedefin önüne çıkar, geri kurulur, çarpar (temas CONTACT), kısa DURAKLAMA + hareket yönünde
## ezilme, sarsılarak oturur, döner. Temasta kalkanın büyük altın-krem silüeti (hayalet) öne itilip söner; vurulanların ayağında
## kırık halka. Final (Siper "Yıkılmaz Duvar"): 4 yöne hayalet + karakterin çevresinde büyük halka.
##
## Plan çerçevesi: orijin = hedefin saldırı anındaki konumu + ANCHOR, +x = saldırı yönü (KARAKTERDEN hedefe, mızraktaki yön
## dersi madde 305). Kalkan dönmediği için çerçevede y yok; ezilme ekran eksenlerine yön bileşenleriyle dağıtılır.
## Değerler prototipteki (tools/proto_20261020/kalkan_proto.py shield_pose / D_fx) ile AYNI; sanat tools/gen_kalkan_fx.py.
## Yeni bir ayar değiştirirsen SADECE burayı değiştir; iki çağıran dosya aynı fonksiyonları kullanır (CLAUDE.md "iki ayrı yer").

## 5 görünüş yan yana (5 x 48 px), sıra VIEW_YAWS; hayalet = aynı görünüşlerin düz silüeti.
const ViewSheets: Array = [
	preload("res://assets/weapons/kalkan/views_L1.png"), preload("res://assets/weapons/kalkan/views_L2.png"),
	preload("res://assets/weapons/kalkan/views_L3.png"), preload("res://assets/weapons/kalkan/views_L4.png"),
	preload("res://assets/weapons/kalkan/views_L5.png"),
]
const GhostSheets: Array = [
	preload("res://assets/fx/kalkan/ghost_L1.png"), preload("res://assets/fx/kalkan/ghost_L2.png"),
	preload("res://assets/fx/kalkan/ghost_L3.png"), preload("res://assets/fx/kalkan/ghost_L4.png"),
	preload("res://assets/fx/kalkan/ghost_L5.png"),
]
const RingFxScene: PackedScene = preload("res://scenes/fx_kalkan_ring.tscn") ## vurulanın ayağında kırık halka, z -1
const WallFxScene: PackedScene = preload("res://scenes/fx_kalkan_wall.tscn") ## Final: karakterin çevresinde büyük halka, z -1
const MeleeChainMath := preload("res://scripts/melee_chain_math.gd") ## vuruş sonrası bekleme (madde 347 zincir)

const CELL := 48
const VIEW_YAWS := [0, 50, 72, 130, 180] ## tools/gen_kalkan_fx.py ile aynı sıra (hedef aşağı -> yukarı)
const SECTOR_HYSTERESIS := 8.0 ## derece: dilim sınırında titremesin
const META_SECTOR := &"kalkan_sector"
const REF_OWNER_SCALE := 0.5
const FX_WORLD_PX := 0.575 ## sanat pikseli (dünya px, k = 1) = Zanaatkâr silahlarıyla aynı
const ANCHOR := Vector2(0.0, -2.0) ## çerçeve orijini hedefin bu kadar üstünde (yaratığın gövdesi)

## [süre (sn), kalkan merkezinin çerçeve x'i (k = 1; null = önceki nokta), hareket yönünde ölçek, dik ölçek, geçiş]
const STEPS := [
	[0.12, -24.0, 1.0, 1.0, "out"], ## yüzü hedefe dönük, hedefin 24 px önüne çık
	[0.08, -31.0, 0.93, 1.04, "inout"], ## kurulma: 7 px geri
	[0.045, -10.0, 1.05, 1.0, "in"], ## çarpma (temas noktası -13, 3 px aşırı) -> CONTACT
	[0.04, null, 0.80, 1.12, "hold"], ## DURAKLAMA (hit-stop) + hareket yönünde ezilme
	[0.045, -13.0, 1.0, 1.0, "shake"], ## sarsılarak temas noktasına oturur
	[0.07, null, 1.0, 1.0, "lin"], ## bekle
]
const CONTACT := 0.245 ## çarpmanın bittiği an (saldırı başından)
const RETURN := 0.26
const SHAKE_AMP := 1.4
const SHAKE_WAVES := 2.0
const CRIT_GHOST_MULT := 1.2

## Darbe alanı: kalkanın çarptığı noktanın (CONTACT_X) çevresi, önünde (geride en fazla BACK_SLACK) - "geniş vuruş".
const CONTACT_X := -13.0
const HIT_R := 40.0
const BACK_SLACK := 8.0
const PUSH := 45.0 ## dünya px (enemy.gd apply_skill_push: bosslar itilmez)
const PUSH_RADIAL := 0.6 ## itme yönü = saldırı yönü + 0,6 x temastan yaratığa (yandakiler yana açılır)
## Final "Yıkılmaz Duvar": karakterin çevresinde 360°, iki kat itme.
const WALL_R := 140.0
const WALL_PUSH_MULT := 2.0

## Hayalet silüet (prototip D): temas noktasında x1,25 -> x1,85, 26 px öne, alfa 0,7 -> 0, 0,3 sn.
const GHOST_LIFE := 0.3
const GHOST_TRAVEL := 26.0
const GHOST_SCALE0 := 1.25
const GHOST_SCALE1 := 1.85
const GHOST_ALPHA := 0.7
const WALL_GHOST_OFFSET := 16.0
const WALL_GHOST_TRAVEL := 36.0

static var _atlas: Dictionary = {}


## ---------------------------------------------------------------- görünüş
## Dünya yönü -> 8 dilim (0 aşağı, 1 sağ-aşağı, 2 sağ, 3 sağ-yukarı, 4 yukarı, 5 sol-yukarı, 6 sol, 7 sol-aşağı). prev >= 0 ise
## dilim sınırını SECTOR_HYSTERESIS kadar geçmeden değişmez.
static func sector_of(dir: Vector2, prev: int = -1) -> int:
	if dir.length() < 0.0001:
		return maxi(prev, 0)
	var a: float = fposmod(rad_to_deg(atan2(dir.x, dir.y)), 360.0) ## 0 aşağı, 90 sağ, 180 yukarı, 270 sol
	if prev >= 0:
		var diff: float = absf(wrapf(a - float(prev) * 45.0, -180.0, 180.0))
		if diff <= 22.5 + SECTOR_HYSTERESIS:
			return prev
	return posmod(roundi(a / 45.0), 8)


## Dilim -> [görünüş sırası 0..4, ayna]
static func view_of_sector(sector: int) -> Array:
	var s: int = posmod(sector, 8)
	return [s if s <= 4 else 8 - s, s > 4]


static func _sheet_tex(sheets: Array, tag: String, tier: int, idx: int) -> AtlasTexture:
	var t: int = clampi(tier, 1, 5)
	var key: String = "%s%d_%d" % [tag, t, idx]
	if not _atlas.has(key):
		var at := AtlasTexture.new()
		at.atlas = sheets[t - 1]
		at.region = Rect2(CELL * clampi(idx, 0, 4), 0, CELL, CELL)
		_atlas[key] = at
	return _atlas[key]


static func view_texture(tier: int, idx: int) -> AtlasTexture:
	return _sheet_tex(ViewSheets, "v", tier, idx)


static func ghost_texture(tier: int, idx: int) -> AtlasTexture:
	return _sheet_tex(GhostSheets, "g", tier, idx)


static func apply_sector(icon: Node, tier: int, sector: int) -> void:
	if not (icon is Sprite2D) or not is_instance_valid(icon):
		return
	var sp := icon as Sprite2D
	var v: Array = view_of_sector(sector)
	var tex: AtlasTexture = view_texture(tier, int(v[0]))
	if sp.texture != tex:
		sp.texture = tex
	sp.flip_h = bool(v[1])
	sp.rotation = 0.0
	sp.set_meta(META_SECTOR, sector)


## Hücum takibi / nişan: ikonu dönmek yerine yüzü `dir`'e bakan görünüşe geçirir (yerel weapon.gd _face_dir + kukla _wf_face).
static func face(icon: Node, tier: int, dir: Vector2) -> void:
	if not (icon is Sprite2D) or dir.length() < 0.0001:
		return
	apply_sector(icon, tier, sector_of(dir, int(icon.get_meta(META_SECTOR, -1))))


## ---------------------------------------------------------------- plan
## dir: saldırı yönü (karakterden hedefe), target: hedefin saldırı anındaki konumu, size: boyut çarpanı (menzil kartları x alan
## çarpanı), owner_scale: sahibin kök ölçeği, wall: Final darbesi, owner_pos: karakterin konumu (Final'in merkezi).
static func make_plan(dir: Vector2, target: Vector2, size: float, owner_scale: float, wall: bool = false,
		owner_pos: Vector2 = Vector2.INF) -> Dictionary:
	if dir.is_zero_approx():
		dir = Vector2.DOWN
	dir = dir.normalized()
	var k: float = maxf(0.05, size) * owner_scale / REF_OWNER_SCALE
	return {"origin": target + ANCHOR, "dir": dir, "k": k, "wall": wall, "sector": sector_of(dir),
		"owner": owner_pos if owner_pos != Vector2.INF else target - dir * 60.0}


static func point(plan: Dictionary, x: float) -> Vector2:
	return (plan["origin"] as Vector2) + (plan["dir"] as Vector2) * x * float(plan["k"])


static func contact_point(plan: Dictionary) -> Vector2:
	return point(plan, CONTACT_X)


static func contact_delay(speed: float) -> float:
	return CONTACT / maxf(0.01, speed)


## Darbe hareketinin toplam süresi (dönüş hariç).
static func busy_duration(speed: float) -> float:
	var s: float = 0.0
	for st: Array in STEPS:
		s += float(st[0])
	return s / maxf(0.01, speed)


## Darbenin vurduğu canlı yaratıklar (birincil her zaman başta). Kaster hasar için, kukla halkalar için AYNI sorguyu kullanır.
static func victims(tree: SceneTree, plan: Dictionary, primary: Node2D = null) -> Array:
	var out: Array = []
	if is_instance_valid(primary) and primary.get("is_dead") != true:
		out.append(primary)
	if tree == null:
		return out
	var k: float = float(plan["k"])
	var wall: bool = bool(plan.get("wall", false))
	var center: Vector2 = (plan["owner"] as Vector2) if wall else contact_point(plan)
	var r: float = (WALL_R if wall else HIT_R) * k
	var d: Vector2 = plan["dir"]
	for e in Enemy.get_enemies_near(tree, center, r):
		if not is_instance_valid(e) or e == primary or e.get("is_dead") == true or not (e is Node2D):
			continue
		var q: Vector2 = (e as Node2D).global_position - center
		if q.length() > r:
			continue
		if not wall and q.dot(d) < -BACK_SLACK * k:
			continue
		out.append(e)
	return out


## Vurulanın itme yönü: saldırı yönü + temastan yaratığa (Final'de karakterden dışa).
static func push_dir(plan: Dictionary, pos: Vector2) -> Vector2:
	var d: Vector2 = plan["dir"]
	if bool(plan.get("wall", false)):
		var o: Vector2 = pos - (plan["owner"] as Vector2)
		return o.normalized() if o.length() > 0.5 else d
	var r: Vector2 = pos - contact_point(plan)
	var rn: Vector2 = r.normalized() if r.length() > 0.5 else Vector2.ZERO
	return (d + rn * PUSH_RADIAL).normalized()


static func push_distance(plan: Dictionary) -> float:
	return PUSH * (WALL_PUSH_MULT if bool(plan.get("wall", false)) else 1.0)


## ---------------------------------------------------------------- oynatma
static func _axis_scale(s_par: float, s_perp: float, d: Vector2) -> Vector2:
	var ax: float = absf(d.x)
	var ay: float = absf(d.y)
	var n: float = maxf(0.0001, ax + ay)
	ax /= n
	ay /= n
	return Vector2(ax * s_par + ay * s_perp, ax * s_perp + ay * s_par)


static func _apply(icon: Node2D, c: Vector2, s: Vector2, base_scale: Vector2) -> void:
	if not is_instance_valid(icon):
		return
	icon.global_position = c
	icon.scale = Vector2(absf(base_scale.x) * s.x, absf(base_scale.y) * s.y)


static func _set_ease(tr: MethodTweener, kind: String) -> void:
	match kind:
		"out":
			tr.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		"in":
			tr.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		"inout":
			tr.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_:
			tr.set_trans(Tween.TRANS_LINEAR)


## İkonu plana göre oynatır, hayaleti temasta çıkarır. host: tween'in bağlanacağı düğüm (silah / kukla). rest_pos: ikonun YEREL
## dinlenme konumu, base_scale: SABİT taban ölçeği, fx_parent: efektlerin ekleneceği düğüm (sahne kökü). Halkalar çağıranda
## (kurbanlar orada bulunur, bkz. spawn_rings). hold: dönüşten önce son pozda bekleme (MeleeChainMath.hold_time; 0 = hemen döner) -
## sonraki darbe beklemede gelirse kalkan temas noktasından yeniden kurulur; bu arada yüz yönü değişmez (tween sürüyor).
static func play(host: Node, icon: Node2D, plan: Dictionary, tier: int, rest_pos: Vector2, base_scale: Vector2, speed: float,
		crit: bool, fx_parent: Node, hold: float = 0.0) -> Tween:
	var sp: float = maxf(0.01, speed)
	apply_sector(icon, tier, int(plan["sector"]))
	var d: Vector2 = plan["dir"]
	var perp: Vector2 = Vector2(-d.y, d.x) * float(plan["k"])
	var tw: Tween = host.create_tween()
	var prev_c: Vector2 = icon.global_position
	var prev_s: Vector2 = Vector2.ONE
	for i in range(STEPS.size()):
		var st: Array = STEPS[i]
		var c1: Vector2 = prev_c if typeof(st[1]) == TYPE_NIL else point(plan, float(st[1]))
		var s1: Vector2 = _axis_scale(float(st[2]), float(st[3]), d)
		var ca: Vector2 = prev_c
		var sa: Vector2 = prev_s
		var kind: String = str(st[4])
		var step: Callable
		match kind:
			"hold":
				step = func(_e: float) -> void:
					_apply(icon, ca, s1, base_scale)
			"shake":
				step = func(e: float) -> void:
					var eo: float = 1.0 - (1.0 - e) * (1.0 - e)
					_apply(icon, ca.lerp(c1, eo) + perp * SHAKE_AMP * sin(e * PI * 2.0 * SHAKE_WAVES) * (1.0 - e), sa.lerp(s1, eo), base_scale)
			_:
				step = func(e: float) -> void:
					_apply(icon, ca.lerp(c1, e), sa.lerp(s1, e), base_scale)
		_set_ease(tw.tween_method(step, 0.0, 1.0, float(st[0]) / sp), kind)
		if i == 2:
			tw.tween_callback(spawn_ghosts.bind(fx_parent, plan, tier, crit)) ## temas: hayalet(ler)
		prev_c = c1
		prev_s = s1
	MeleeChainMath.append_hold(tw, icon, hold)
	tw.tween_property(icon, "position", rest_pos, RETURN / sp).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(icon, "scale", Vector2(absf(base_scale.x), absf(base_scale.y)), RETURN / sp)
	return tw


## Hayalet silüet(ler): normal darbede temas noktasında öne, Final'de karakterin çevresinde 4 yöne.
static func spawn_ghosts(fx_parent: Node, plan: Dictionary, tier: int, crit: bool = false) -> void:
	if fx_parent == null or not is_instance_valid(fx_parent) or not fx_parent.is_inside_tree():
		return
	var k: float = float(plan["k"]) * (CRIT_GHOST_MULT if crit else 1.0)
	if bool(plan.get("wall", false)):
		var o: Vector2 = plan["owner"]
		for dd: Vector2 in [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]:
			_ghost(fx_parent, o + dd * WALL_GHOST_OFFSET * float(plan["k"]), dd, sector_of(dd), tier, k, WALL_GHOST_TRAVEL)
		spawn_point_fx(WallFxScene, fx_parent, o, float(plan["k"]))
		return
	_ghost(fx_parent, contact_point(plan), plan["dir"], int(plan["sector"]), tier, k, GHOST_TRAVEL)


static func _ghost(fx_parent: Node, pos: Vector2, dir: Vector2, sector: int, tier: int, k: float, travel: float) -> Sprite2D:
	var v: Array = view_of_sector(sector)
	var g := Sprite2D.new()
	g.name = "KalkanHayalet"
	g.texture = ghost_texture(tier, int(v[0]))
	g.flip_h = bool(v[1])
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.z_index = 60
	g.modulate = Color(1.0, 1.0, 1.0, GHOST_ALPHA)
	fx_parent.add_child(g)
	g.global_position = pos
	g.global_scale = Vector2.ONE * FX_WORLD_PX * k * GHOST_SCALE0
	var tw: Tween = g.create_tween().set_parallel(true)
	tw.tween_property(g, "global_position", pos + dir.normalized() * travel * k, GHOST_LIFE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(g, "global_scale", Vector2.ONE * FX_WORLD_PX * k * GHOST_SCALE1, GHOST_LIFE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(g, "modulate:a", 0.0, GHOST_LIFE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(g.queue_free)
	return g


## Vurulanların ayağında kırık halka (kaster: gerçek kurbanlar, kukla: kendi yaratık kuklalarıyla aynı sorgu - kozmetik).
static func spawn_rings(fx_parent: Node, victims_list: Array, plan: Dictionary) -> void:
	for v in victims_list:
		if is_instance_valid(v) and v is Node2D:
			spawn_point_fx(RingFxScene, fx_parent, (v as Node2D).global_position, float(plan["k"]))


static func spawn_point_fx(scene: PackedScene, parent: Node, pos: Vector2, k: float) -> AnimatedSprite2D:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var fx: AnimatedSprite2D = scene.instantiate() as AnimatedSprite2D
	parent.add_child(fx)
	fx.global_position = pos
	fx.global_scale = Vector2.ONE * FX_WORLD_PX * k
	return fx
