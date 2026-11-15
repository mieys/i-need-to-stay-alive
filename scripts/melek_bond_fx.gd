extends Node2D

## Melek Q (Can Basma) / E (Kalkan Yenileme) bağı - kullanıcının seçtiği "A Işık İpi" (madde 212; prototip
## tools/proto_20261017/gen_melek_bag.py, "sihirli bir bağ kuruyormuş da o bağdan müttefiğe bir dalgalanma gidiyormuş gibi").
## Bu düğüm BAĞLI DOSTUN çocuğudur: player.gd / remote_player.gd start_ally_aura_fx(tür, kaster) kurar ve _ally_aura_fx["heal"/
## "shield"] sözlüğüne yazar; stop_ally_aura_fx -> stop_aura() ile çözülür.
##  - Bel halkası: dostun belinde 2:1, dönen 4 rün çentiği; arka yarısı gövdenin arkasında (z -1), ön yarısı önünde - sayfa
##    assets/fx/melek_bond/ring_<tür>.png (tools/gen_melek_bond_fx.py; 0-11 döngü, 12-23 parlak, 24-25 açılış, 26-31 kapanış,
##    32-38 yankı).
##  - İp: melek_bond_ribbon.gd (sahnenin çocuğu) Melek'in HALESİNİN dosta bakan altın pikselinden bel halkasının yakın kenarına.
##  - Kuruluş (HEAD_TIME): parlak baş haleden dosta koşar; değince halka açılır + yankı + Q büyük yeşil artı / E yıldız.
##  - pulse() (her tik): bağın üstünden DALGA PAKETİ sabit hızla dosta koşar; varınca halka parlar, yankı halkası açılır,
##    Q yeşil artı / E mana kristali yükselir.
##  - stop_aura(): ip ortadan hilallere kopar, halka kapanır, sonra düğüm silinir.
## Ağ: kasterde _set_ally_aura -> yerel kurulum + broadcast_ally_aura_start(kaster id, hedef id, tür); her tik
## _spawn_wave_beam_to_ally -> yerel pulse() + broadcast_wave_fx -> alıcıda hedefin bağına pulse(). İki tarafta aynı kod.
## BALONCUK KİPİ (madde 565, E "shield" + dostun mana kalkanı varsa; prototip tools/proto_20261111/melek_e_kalkan/ C1 + C4):
##  - dostun kalkan baloncuğu bağ boyunca AÇIK (kalkan yenilenme efekti): sahibi player.gd _update_shield_bubble / kukla
##    remote_player.gd refresh_bond_bubble holds_bubble()'a bakar (ek ağ alanı yok: hedefin kendi kararı shield_bubble_visible
##    ile zaten herkese gider, kukla yerelde de açar ki gecikmede ip boş kenara bağlanmasın).
##  - ip bel halkası yerine baloncuğun Melek'e bakan YÜZEYİNE iner (rope_end_world -> melek_bond_ribbon.gd), bel halkası gizli.
##  - değme noktasında BAĞ HALKASI + varışta kenar ışığı; kaster Kutsal Zırh (melek_e1) evrimliyse SARMAL BAĞ (melek_bond_joint.gd).
##  - her varışta baloncuk bağın açık mavisine parlar (shield_visual.gd pour).

const BondMath := preload("res://scripts/melek_bond_math.gd")
const RibbonScript := preload("res://scripts/melek_bond_ribbon.gd")
const JointScript := preload("res://scripts/melek_bond_joint.gd")
const RING_TEX := {
	"heal": preload("res://assets/fx/melek_bond/ring_heal.png"),
	"shield": preload("res://assets/fx/melek_bond/ring_shield.png"),
}
const GLYPH_TEX: Texture2D = preload("res://assets/fx/melek_bond/glyphs.png")
const GLYPH_N := 11
const MAX_LIFETIME := 9.0 ## güvenlik ağı (yetenek 6 sn; durdurma RPC'si kaybolursa)
const WAIST_ROW := 3.5 ## halka merkezi: dostun kare merkezinin bu kadar sanat pikseli altı (prototip feet-13)
const CHEST := Vector2(1.5, -5.5) ## dostun göğsü (artı/kristal), kare merkezine göre
const RING_HFRAMES := 39
const RING_LOOP := 12
const RING_BRIGHT0 := 12
const RING_OPEN0 := 24
const RING_CLOSE0 := 26
const RING_CLOSE_N := 6
const RING_ECHO0 := 32
const RING_ECHO_N := 7
const GLYPH_LIFE := 8.0 / BondMath.PROTO_FPS
const STAR_LIFE := 4.0 / BondMath.PROTO_FPS
## Baloncuk kipi (madde 565). Tek anahtar: false = eski bel halkası.
const BUBBLE_JOINT_ENABLED := true
const BUBBLE_RIM_PX := 10.5 ## baloncuk sanatının görünen kenarı (24x24 karede bbox 1..23; 4 tür sayfası aynı)
## "grow" karelerinin görünen yarıçapı (bubble_frames.tres ölçüldü, 12 fps: 0,42 sn'de tam boy) - büyürken ip havada kalmasın
const BUBBLE_GROW_R := [3.0, 5.0, 9.0, 10.0, 10.0, 11.0, 11.0, 11.0, 11.0, 11.0]
const CONTACT_AIM_UP := 30.0 ## değme noktası kasterin bu kadar üstüne (halesine) bakar
const RIPPLE_TIME := 0.42
const POUR_TIME := 0.38 ## shield_visual.gd POUR_TIME ile aynı (halkanın varış parlaması)
const ARMOR_EVO := "melek_e1" ## Kutsal Zırh: sarmal bağ

var kind: String = "heal"
var caster: Node2D = null
## Gece ışığı rengi (night_glow_catalog.gd "cp") - Q yeşil, E mavi.
var glow_color: Color:
	get:
		return BondMath.palette(kind)[3]

## Kabul edilen tik sayısı (MP denetimi: tools/mp_audit/melek_audit.gd).
var pulses_received: int = 0
var _t: float = 0.0
var _connected: bool = false
var _stopping: bool = false
var _stop_t: float = 0.0
var _bright_until: float = -1.0
var _pulses: Array[float] = [] ## pulse() anları (_t)
var _echoes: Array[float] = [] ## yankı halkası başlangıçları
var _glyphs: Array = [] ## [Sprite2D, doğuş _t, glif türü]
var _ring_back: Sprite2D
var _ring_front: Sprite2D
var _echo_back: Sprite2D
var _echo_front: Sprite2D
var _ribbon: Node2D = null
var _bubble_mode: bool = false
var _conn_t: float = -1.0
var _pour_t: float = -10.0
var _ripples: Array[float] = []
var _joint: Node2D = null


## Hedefin bu türdeki bağına bir dalga paketi yollar; bağ yoksa false. player.gd _spawn_wave_beam_to_ally (kaster) ve
## network_manager.gd broadcast_wave_fx (alıcılar) ortak kullanır.
static func pulse_on(target: Node, p_kind: String) -> bool:
	if target == null or not is_instance_valid(target) or not ("_ally_aura_fx" in target):
		return false
	var reg: Dictionary = target.get("_ally_aura_fx")
	var b: Variant = reg.get(p_kind, null)
	if b == null or not is_instance_valid(b) or not (b as Object).has_method("pulse"):
		return false
	(b as Object).call("pulse")
	return true


func setup(p_kind: String, p_caster: Node2D) -> void:
	kind = "shield" if p_kind == "shield" else "heal"
	caster = p_caster


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex: Texture2D = RING_TEX[kind]
	_ring_back = _make_ring_sprite(tex, -1)
	_ring_front = _make_ring_sprite(tex, 0)
	_echo_back = _make_ring_sprite(tex, -1)
	_echo_front = _make_ring_sprite(tex, 0)
	if caster != null and is_instance_valid(caster):
		_ribbon = RibbonScript.new()
		_ribbon.setup(self, kind)
		var scene_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		scene_root.add_child(_ribbon)
	_bubble_mode = _decide_bubble_mode()
	if _bubble_mode:
		_joint = JointScript.new()
		_joint.set("bond", self)
		add_child(_joint)
		_notify_bubble()
	_update_ring_position()
	_update_ring_frames()


func _exit_tree() -> void:
	if _ribbon != null and is_instance_valid(_ribbon):
		_ribbon.queue_free()
	_ribbon = null


func _make_ring_sprite(tex: Texture2D, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = RING_HFRAMES
	s.vframes = 2
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_index = z
	s.visible = false
	add_child(s)
	return s


## Bir tik: bağın üstünden dosta dalga paketi. Kuruluş bitmeden gelen tik yok sayılır (E'nin ilk tiki kurulumla aynı anda).
## İp yoksa (kaster bu istemcide bulunamadı) varış hemen oynar.
func pulse() -> void:
	if _stopping or not _connected:
		return
	pulses_received += 1
	if _ribbon == null or not is_instance_valid(_ribbon):
		_arrive("plus" if kind == "heal" else "crystal")
		return
	_pulses.append(_t)


func stop_aura() -> void:
	if _stopping:
		return
	_stopping = true
	_stop_t = _t
	_notify_bubble()


func is_connected_bond() -> bool:
	return _connected


func is_stopping() -> bool:
	return _stopping


## Yolda olan dalga paketi sayısı.
func pulse_count() -> int:
	return _pulses.size()


func time_alive() -> float:
	return _t


func dissolve_amount() -> float:
	return 0.0 if not _stopping else clampf((_t - _stop_t) / BondMath.DISSOLVE_TIME, 0.0, 1.0)


## İp üstündeki paketler [Vector2(merkez s, ağırlık)] - ip (melek_bond_ribbon.gd) her karede okur.
func packets_at(total: float, head: float) -> Array:
	var out: Array = []
	for t0: float in _pulses:
		var c: float = (_t - t0) * BondMath.WAVE_SPEED
		if c >= -6.0 and c <= total + 10.0:
			out.append(Vector2(c, 1.0))
	if _t >= BondMath.HEAD_TIME - 2.0 / BondMath.PROTO_FPS and _t < BondMath.HEAD_TIME + 1.0 / BondMath.PROTO_FPS:
		out.append(Vector2(minf(head, total), 0.8)) ## kuruluşun son anlarında başın kendisi parlak paket
	return out


func _process(delta: float) -> void:
	_t += delta
	if not _stopping and (_t >= MAX_LIFETIME or (caster != null and not is_instance_valid(caster))):
		stop_aura()
	if not _connected and not _stopping and _t >= BondMath.HEAD_TIME:
		_connected = true
		_conn_t = _t
		_arrive("plus_big" if kind == "heal" else "star")
	## varış: paketin merkezi ipin sonuna değdi (uzunluk ipin son çiziminden)
	var total: float = float(_ribbon.get("last_total")) if _ribbon != null and is_instance_valid(_ribbon) else 0.0
	for i in range(_pulses.size() - 1, -1, -1):
		if total > 0.0 and (_t - _pulses[i]) * BondMath.WAVE_SPEED >= total:
			_pulses.remove_at(i)
			_arrive("plus" if kind == "heal" else "crystal")
	for i in range(_ripples.size() - 1, -1, -1):
		if _t - _ripples[i] > RIPPLE_TIME:
			_ripples.remove_at(i)
	_update_ring_position()
	_update_ring_frames()
	_update_glyphs()
	var done_t: float = maxf(BondMath.DISSOLVE_TIME, float(RING_CLOSE_N + 1) / BondMath.PROTO_FPS)
	if _stopping and _t - _stop_t >= done_t and _glyphs.is_empty() and _echoes.is_empty():
		queue_free()


func _arrive(glyph: String) -> void:
	_bright_until = _t + BondMath.BRIGHT_TIME
	_echoes.append(_t)
	_spawn_glyph(glyph)
	if _bubble_mode:
		_ripples.append(_t)
		if glyph != "star": ## dalga kalkana girdi: baloncuk parlar
			_pour_t = _t
			var sv: Node = _shield_visual()
			if sv != null and sv.has_method("pour"):
				sv.call("pour")


# ---------------------------------------------------------------- halka + glifler
func _body_sprite() -> Node2D:
	var p: Node = get_parent()
	if p == null:
		return null
	return p.get_node_or_null("AnimatedSprite2D") as Node2D


## Dostun gövde sprite'ında kare merkezine göre `rel` (sanat pikseli) noktası - bu düğümün yerel uzayında.
func _body_local(rel: Vector2) -> Vector2:
	var s: Node2D = _body_sprite()
	if s == null:
		return Vector2.ZERO
	var off: Variant = s.get("offset")
	return s.position + ((off as Vector2) if off is Vector2 else Vector2.ZERO) * s.scale + rel * s.scale


func _local_px_scale() -> float:
	var p: Node2D = get_parent() as Node2D
	var gs: float = absf(p.global_scale.x) if p != null else 1.0
	return BondMath.TEXEL_W / maxf(gs, 0.0001)


func _update_ring_position() -> void:
	var w: Vector2 = _body_local(Vector2(0.0, WAIST_ROW))
	var sc := Vector2.ONE * _local_px_scale()
	for s: Sprite2D in [_ring_back, _ring_front, _echo_back, _echo_front]:
		s.position = w
		s.scale = sc


## Bel halkasının dünya merkezi (ip buraya bağlanır).
func ring_world_center() -> Vector2:
	return to_global(_body_local(Vector2(0.0, WAIST_ROW)))


## Halkanın bu anki karesi (-1 = görünmez).
func ring_frame_now() -> int:
	if not _connected:
		return -1
	if _stopping:
		var k: int = int((_t - _stop_t) * BondMath.PROTO_FPS)
		return -1 if k >= RING_CLOSE_N else RING_CLOSE0 + k
	var since: float = _t - BondMath.HEAD_TIME
	if since < 2.0 / BondMath.PROTO_FPS:
		return RING_OPEN0 + clampi(int(since * BondMath.PROTO_FPS), 0, 1)
	var loop_i: int = int(_t * BondMath.PROTO_FPS) % RING_LOOP
	return (RING_BRIGHT0 if _t < _bright_until else 0) + loop_i


func _update_ring_frames() -> void:
	var f: int = ring_frame_now()
	_ring_back.visible = f >= 0
	_ring_front.visible = f >= 0
	if f >= 0:
		_ring_back.frame = f
		_ring_front.frame = RING_HFRAMES + f
	for i in range(_echoes.size() - 1, -1, -1):
		if int((_t - _echoes[i]) * BondMath.PROTO_FPS) >= RING_ECHO_N:
			_echoes.remove_at(i)
	_echo_back.visible = not _echoes.is_empty()
	_echo_front.visible = not _echoes.is_empty()
	if not _echoes.is_empty():
		var k: int = clampi(int((_t - _echoes[_echoes.size() - 1]) * BondMath.PROTO_FPS), 0, RING_ECHO_N - 1)
		_echo_back.frame = RING_ECHO0 + k
		_echo_front.frame = RING_HFRAMES + RING_ECHO0 + k
	if _bubble_mode: ## bağ baloncuğa bağlı: bel halkası + yankısı yok (yerine melek_bond_joint.gd)
		for s: Sprite2D in [_ring_back, _ring_front, _echo_back, _echo_front]:
			s.visible = false


func _spawn_glyph(glyph: String) -> void:
	var s := Sprite2D.new()
	s.texture = GLYPH_TEX
	s.hframes = GLYPH_N
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_index = 60
	add_child(s)
	_glyphs.append([s, _t, glyph])
	_update_glyphs()


func glyph_count() -> int:
	return _glyphs.size()


func _update_glyphs() -> void:
	var sc: float = _local_px_scale()
	var base: Vector2 = _body_local(CHEST)
	for i in range(_glyphs.size() - 1, -1, -1):
		var e: Array = _glyphs[i]
		var s: Sprite2D = e[0]
		var glyph: String = e[2]
		var age: float = _t - float(e[1])
		var life: float = STAR_LIFE if glyph == "star" else GLYPH_LIFE
		if age >= life or not is_instance_valid(s):
			if is_instance_valid(s):
				s.queue_free()
			_glyphs.remove_at(i)
			continue
		var k: int = int(age * BondMath.PROTO_FPS)
		s.frame = BondMath.glyph_frame(glyph, k)
		s.scale = Vector2.ONE * sc
		var dy: float = 1.0 if glyph == "star" else -float(k) * (1.2 if glyph == "crystal" else 1.3)
		s.position = base + Vector2(0.0, dy) * sc


# ---------------------------------------------------------------- baloncuk kipi (madde 565)
func _decide_bubble_mode() -> bool:
	if not BUBBLE_JOINT_ENABLED or kind != "shield" or caster == null or not is_instance_valid(caster):
		return false
	var p: Node = get_parent()
	if p == null or p.get_node_or_null("ShieldVisual/BubbleSprite") == null:
		return false
	var m: Variant = p.get("item_shield_max")
	return m != null and float(m) > 0.0


## Bağ dostun kalkan baloncuğunu açık tutuyor mu (player.gd _update_shield_bubble / remote_player.gd refresh_bond_bubble).
func holds_bubble() -> bool:
	return _bubble_mode and not _stopping


func is_bubble_mode() -> bool:
	return _bubble_mode


## Kaster Kutsal Zırh evrimli mi (yerel Player ya da kukla - ikisinde de has_evo; kukla main.gd extra["evo"]'dan bilir).
func armor_wrap() -> bool:
	if caster == null or not is_instance_valid(caster) or not caster.has_method("has_evo"):
		return false
	return bool(caster.call("has_evo", ARMOR_EVO))


func _notify_bubble() -> void:
	var p: Node = get_parent()
	if p != null and p.has_method("refresh_bond_bubble"):
		p.call_deferred("refresh_bond_bubble")


func _shield_visual() -> Node:
	var p: Node = get_parent()
	return p.get_node_or_null("ShieldVisual") if p != null else null


func _bubble_sprite() -> AnimatedSprite2D:
	var p: Node = get_parent()
	return p.get_node_or_null("ShieldVisual/BubbleSprite") as AnimatedSprite2D if p != null else null


## Baloncuğun ŞU ANKİ görünen kenarı (baloncuk sanat pikseli).
func bubble_rim_px() -> float:
	var b: AnimatedSprite2D = _bubble_sprite()
	if b != null and b.animation == &"grow":
		return float(BUBBLE_GROW_R[clampi(b.frame, 0, BUBBLE_GROW_R.size() - 1)]) - 0.5
	return BUBBLE_RIM_PX


## Baloncuğun Melek'e bakan kenar noktası (dünya) - ip buraya iner, bağ halkası burada.
func contact_world() -> Vector2:
	var b: AnimatedSprite2D = _bubble_sprite()
	if b == null:
		return ring_world_center()
	var c: Vector2 = b.global_position
	var aim: Vector2 = c + Vector2(-1.0, -0.4)
	if caster != null and is_instance_valid(caster):
		aim = caster.global_position - Vector2(0.0, CONTACT_AIM_UP)
	var dir: Vector2 = (aim - c).normalized() if aim.distance_squared_to(c) > 0.01 else Vector2.LEFT
	return c + dir * (bubble_rim_px() - 0.5) * absf(b.global_scale.x)


## İpin ucu (dünya) - baloncuk kipinde değme noktası, yoksa null (ip bel halkasının kenarına iner).
func rope_end_world() -> Variant:
	if not _bubble_mode or caster == null or not is_instance_valid(caster):
		return null
	return contact_world()


## melek_bond_joint.gd'nin çizimi için anlık durum (bu düğümün yereli = dostun yereli; çocuk düğümün dönüşümü yok).
func joint_state() -> Dictionary:
	var b: AnimatedSprite2D = _bubble_sprite()
	if not _bubble_mode or b == null:
		return {}
	var c: Vector2 = to_local(b.global_position)
	var g: float = clampf(1.0 - (_t - _pour_t) / POUR_TIME, 0.0, 1.0)
	## baloncuk sanat pikseli bu düğümün yerelinde: dünya ölçeği / bu düğümün dünya ölçeği
	var own: float = maxf(absf(global_scale.x), 0.0001)
	return {
		"c": c,
		"bp": absf(b.global_scale.x) / own,
		"rim": bubble_rim_px(),
		"a0": (to_local(contact_world()) - c).angle(),
		"tx": _local_px_scale(),
		"t": _t,
		"conn_t": _conn_t,
		"stop_t": _stop_t if _stopping else -1.0,
		"glow": g * g,
		"ripples": _ripples,
		"wrap": armor_wrap(),
	}
