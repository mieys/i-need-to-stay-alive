extends Node2D

## ÜÇ KARDEŞ alan efektleri (kardes_boss.gd _spawn "kardes_zone"; host'ta yetkili + istemcide görsel kopya, AYNI veriyle).
## data.warn sn yerde uyarı halkası (renk türe göre), sonra isabet: yarıçap içindeki oyunculara `damage` (yalnız yetkili örnek, data.kind türüyle) +
## craftpix sprite şeridi. data.fling > 0: isabet edeni merkezden dışa savurur (Kılıç Kardeş Kasırga). Zemine konur (spawn_world_fx place_on_ground);
## isabet sprite'ı kendi z'siyle yaratıkların üstünde çizilir.
## data.style: spin / slash (kılıç) · arrows (ok yağmuru) · bolt (yıldırım) · spikes (buz dikeni) · meteor · rage (öfke patlaması, hasarsız) ·
## dust (sıçrama tozu, hasarsız) · spark (ışınlanma çakması, hasarsız).

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const SheetFx := preload("res://scripts/kardes_sheet_fx.gd")
const DustScript: GDScript = preload("res://scripts/minotaur_dust.gd")
const CameraShakeScript := preload("res://scripts/camera_shake.gd")
const TEX_SWORD := preload("res://assets/enemies/kardesler/fx_sword_aoe.png")
const TEX_BOLT := preload("res://assets/enemies/kardesler/fx_lightning.png")
const TEX_SPIKES := preload("res://assets/enemies/kardesler/fx_ice_spikes.png")
const TEX_METEOR := preload("res://assets/enemies/kardesler/fx_meteor.png")
const TEX_BURST := preload("res://assets/enemies/kardesler/fx_fire_burst.png")
const TEX_ARROW := preload("res://assets/enemies/kardesler/fx_arrow.png")

## Uyarı rengi (halka, dolgu) türe göre
const COLORS := {
	"spin": Color(1.0, 0.82, 0.3), "slash": Color(1.0, 0.82, 0.3), "arrows": Color(1.0, 0.35, 0.25),
	"bolt": Color(0.75, 0.85, 1.0), "spikes": Color(0.45, 0.8, 1.0), "meteor": Color(1.0, 0.45, 0.15),
}
## Şeridin isabetten bu kadar ÖNCE başlaması (düşen meteor / çakan yıldırım isabet anında yere değsin)
const SHEET_LEAD := {"meteor": 0.25, "bolt": 0.12, "spikes": 0.1}
const FALL_TIME := 0.22 ## ok yağmurunda okların düşüş süresi
const LINGER := 0.25

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _style: String = "spin"
var _warn: float = 0.5
var _radius: float = 40.0
var _t: float = 0.0
var _hit: bool = false
var _sheet_started: bool = false


func _ready() -> void:
	z_index = 0
	_style = str(data.get("style", "spin"))
	_warn = maxf(float(data.get("warn", 0.5)), 0.0)
	_radius = float(data.get("radius", 40.0))
	queue_redraw()


func _physics_process(delta: float) -> void:
	_t += delta
	if not _sheet_started and _t >= _warn - float(SHEET_LEAD.get(_style, 0.0)):
		_sheet_started = true
		_play_sheet()
	if not _hit and _t >= _warn:
		_hit = true
		_impact()
	if _t >= _warn + LINGER:
		queue_free()
		return
	queue_redraw()


func _impact() -> void:
	if authoritative and damage > 0.0 and is_inside_tree():
		var kind: String = str(data.get("kind", "kardes_cut"))
		var fling: float = float(data.get("fling", 0.0))
		for p in AbilitiesScript.damageable_players(get_tree()):
			var pn := p as Node2D
			if pn.get("is_downed") == true or pn.get("is_indoors") == true:
				continue
			if global_position.distance_to(pn.global_position) > _radius + AbilitiesScript.TARGET_BODY_RADIUS:
				continue
			AbilitiesScript.deal_special_damage(pn, damage, source, kind)
			if fling > 0.0:
				_fling(pn, fling)
	match _style:
		"meteor":
			DustScript.burst(get_tree(), global_position, Vector2.UP, 0.5)
			CameraShakeScript.add_limited("kardes_meteor", 0.3, 0.25)
		"spin", "arrows":
			DustScript.burst(get_tree(), global_position, Vector2.UP, 0.25)


func _fling(pn: Node2D, distance: float) -> void:
	var dir: Vector2 = pn.global_position - global_position
	dir = dir.normalized() if dir.length() > 1.0 else Vector2.from_angle(randf() * TAU)
	if pn.is_in_group("remote_players"):
		var peer_id: int = int(pn.get("peer_id"))
		if peer_id > 0:
			NetworkManager.forward_player_fling_to_peer.rpc_id(peer_id, dir, distance)
	elif pn.has_method("apply_boss_fling"):
		pn.call("apply_boss_fling", dir, distance)


func _play_sheet() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var pos: Vector2 = global_position
	## Sayfalar HEP oyun boyunda (ölçek 1 = 1 sanat px x ART; kullanıcı kuralı: efekt büyütülmez, piksel yoğunluğu kardeşlerle aynı). Yarıçapı sayfadan
	## büyük alanda (meteor yağmuru, kasırga) aynı sayfanın birkaç kopyası alana dağılır.
	match _style:
		"spin":
			SheetFx.play(parent, pos + Vector2(0.0, -10.0), TEX_SWORD, 7, 18.0)
			if _radius > 70.0:
				for i in range(6):
					var p2: Vector2 = pos + Vector2.from_angle(float(i) * TAU / 6.0 + 0.3) * _radius * 0.62
					SheetFx.play(parent, p2, TEX_SWORD, 7, 22.0)
		"slash":
			SheetFx.play(parent, pos + Vector2(0.0, -6.0), TEX_SWORD, 7, 20.0)
		"bolt":
			SheetFx.play(parent, pos, TEX_BOLT, 10, 22.0, 1.0, 0.0, 6, true)
		"spikes":
			SheetFx.play(parent, pos, TEX_SPIKES, 12, 24.0, 1.0, 0.0, 6, true)
		"meteor":
			SheetFx.play(parent, pos, TEX_METEOR, 12, 16.0, 1.0, 0.0, 6, true)
			var extra: int = clampi(int(roundf(_radius * _radius / (54.0 * 54.0))) - 1, 0, 4)
			for i in range(extra):
				var p3: Vector2 = pos + Vector2.from_angle(float(i) * TAU / float(maxi(extra, 1)) + 0.7) * _radius * 0.55
				SheetFx.play(parent, p3, TEX_METEOR, 12, 17.0, 1.0, 0.0, 6, true)
		"rage":
			SheetFx.play(parent, pos + Vector2(0.0, -20.0), TEX_BURST, 10, 16.0)
		"spark":
			SheetFx.play(parent, pos, TEX_BOLT, 10, 26.0, 1.0, 0.0, 6, true)
		"dust":
			DustScript.burst(get_tree(), pos, Vector2.UP, 0.35)


func _draw() -> void:
	if _warn <= 0.0 or _radius <= 0.0:
		return
	var col: Color = COLORS.get(_style, Color(1.0, 0.3, 0.2))
	if _t < _warn:
		var k: float = clampf(_t / _warn, 0.0, 1.0)
		var pulse: float = 0.5 + 0.5 * sin(_t * 16.0)
		draw_circle(Vector2.ZERO, _radius * k, Color(col, 0.16 + 0.12 * pulse))
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 40, Color(col, 0.9), 3.0)
		draw_arc(Vector2.ZERO, _radius * k, 0.0, TAU, 40, Color(col.lightened(0.4), 0.7), 1.5)
		if _style == "arrows" and _t >= _warn - FALL_TIME:
			## Düşen oklar: alanın içine üç ok gökten iner (aşağı bakan ok sprite'ı)
			var f: float = clampf((_t - (_warn - FALL_TIME)) / FALL_TIME, 0.0, 1.0)
			var s: Vector2 = Vector2.ONE * SheetFx.ART
			for i in range(3):
				var off: Vector2 = Vector2((float(i) - 1.0) * _radius * 0.45, (float(i % 2) - 0.5) * _radius * 0.3)
				draw_set_transform(off + Vector2(0.0, -180.0 * (1.0 - f)), PI * 0.5, s)
				draw_texture(TEX_ARROW, -TEX_ARROW.get_size() * 0.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var a: float = 1.0 - clampf((_t - _warn) / LINGER, 0.0, 1.0)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 40, Color(col, 0.6 * a), 2.0)
