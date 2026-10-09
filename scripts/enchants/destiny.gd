extends "res://scripts/enchant_behavior.gd"

## Destiny of Ice and Fire (Ateş / Buz Asası) - bkz. EnchantDefs "destiny". Asanın normal atışı KAPANIR (replaces_shot);
## bunun yerine en yakın düşmana doğru sürekli bir koni püskürtür: saldırı hızıyla hızlanan tiklerde koni içindekilere hasar,
## Ateş'te yanma, Buz'da koni içinde "freeze_build" sn kalana donma. Final (Ejderha Hükmü): koni iki kat büyür, Ateş koninin
## ucuna lav birikintisi, Buz donmuş zemin bırakır (enchant_area "lava" / "field" + sprite sayfaları).
## Görsel (2026-10-03): kullanıcının ateş püskürtme sanatı ("yeni ateş püskürtme efekti.zip", tools/import_flame_spray.py ->
## flame_fire; Buz Asası'nda AYNI sanatın buza boyanmışı flame_ice), 61 kare döngü. Püskürtme sürdükçe TEK sürekli alev
## (fx_enchant_sprite "key"): her tik yaşayan alevin ömrünü uzatır ve yönünü günceller (yumuşak döner); hedef kalmayınca
## FLAME_LINGER sonunda söner. Kullanıcı: "spritesheet oynatılıp kapatılıyordu, sürekli devam etmesini istiyorum".
## Eski 6 karelik koni sayfaları (spray_fire/ice[_big], gen_enchant_fx.py) artık kullanılmıyor.
## Tikler aynı yoldan (enchant_fx "sprite" -> broadcast) diğer oyunculara da gider; anahtar aynı olduğu için orada da tek alev.

const TEXEL := 1.212
const FLAME_LEN_PX := 51.0 ## sayfadaki alevin boyu (sanat px) - menzile göre ölçeklenir
const FLAME_OFFSET := Vector2(25.5, -1.1) ## namlu (kare içinde (0, 17.1)) düğüm noktasına otursun (ortalı sprite ofseti)
## Sanatın doğal genişliğinin karşıladığı yarı açı (varsayılan 60° koni). Daha geniş konide dikey en fazla FLAME_MAX_STRETCH
## gerilir; onu da aşınca (Final 90-108°) koni yan yana, ortada örtüşen alevlere bölünür (yoksa "V" gibi ayrık iki dil).
const FLAME_BASE_HALF_DEG := 30.0
const FLAME_MAX_STRETCH := 1.35
const SUB_CONE_OVERLAP := 1.3
## Son tikten sonra alevin kalma süresi - fx_enchant_sprite.FADE'den (0,25) uzun: tik arasında alev solup yanıp sönmesin.
const FLAME_LINGER := 0.35
const POOL_EVERY := 1.0
const PUSH_EVERY := 0.5

const WeaponTip := preload("res://scripts/weapon_tip.gd")

var _tick_t: float = 0.0
var _in_cone: Dictionary = {}
var _pool_t: float = 0.0
var _push_t: float = 0.0
var _aim: Node2D = null


func replaces_shot() -> bool:
	return true


## Asa püskürtmenin hedefine bakar (weapon.gd _update_aim) - koni sprite'ı asanın ucundan, baktığı yönden çıkar.
func aim_target() -> Node2D:
	return _aim if is_instance_valid(_aim) else null


func _ice() -> bool:
	return weapon_key() == "buz_asasi"


func _range() -> float:
	return f("spray_range", 110.0) * f("spray_size", 1.0)


func _half() -> float:
	## Final "boyut iki katına": menzil x2, açı x1.5 (en fazla 140°) - koni oyuncunun arkasına dönmesin.
	var ang: float = f("spray_angle", 60.0) * (1.5 if f("spray_size", 1.0) > 1.0 else 1.0)
	return deg_to_rad(minf(140.0, ang)) * 0.5


func _interval() -> float:
	var pl: Node = owner_player()
	var m: float = float(pl.call("get_attack_interval_mult")) if pl and pl.has_method("get_attack_interval_mult") else 1.0
	return maxf(0.08, f("spray_tick", 0.25) * m / (1.0 + f("spray_rate") + attack_speed_bonus()))


func process_extra(delta: float) -> void:
	_pool_t = maxf(0.0, _pool_t - delta)
	_push_t = maxf(0.0, _push_t - delta)
	if not can_act() or not is_instance_valid(weapon):
		return
	var origin: Vector2 = weapon.global_position
	var tgt: Node = _pick_target(origin)
	_aim = tgt as Node2D
	if tgt == null:
		_in_cone.clear()
		return
	_tick_t -= delta
	if _tick_t > 0.0:
		return
	var iv: float = _interval()
	_tick_t = iv
	## Koni asanın ÇİZİLİ UCUNDAN çıkar (eskiden silah kökü = asanın ortası) - hasar konisi de görselle aynı noktadan.
	var icon: Sprite2D = weapon.get("icon_sprite") as Sprite2D
	if icon:
		origin = WeaponTip.tip_global(icon, float(weapon.get("sprite_forward_angle_deg")))
	var dir: Vector2 = dir_to(origin, tgt)
	var r: float = _range()
	var half: float = _half()
	var sheet: String = "flame_ice" if _ice() else "flame_fire"
	var sx: float = r / (FLAME_LEN_PX * TEXEL)
	var base_half: float = deg_to_rad(FLAME_BASE_HALF_DEG)
	var parts: int = maxi(1, ceili(half / (base_half * FLAME_MAX_STRETCH)))
	var sub_half: float = half / float(parts)
	## Alt alevler yan yana tam bitişik olunca ortada boşluk kalıp "V" gibi iki ayrı dile ayrılıyordu (gerçek harita
	## çekimi): her biri %30 geniş çizilir, ortada örtüşüp tek geniş nefes olur (merkezleri aynı, dış kenar ~sabit).
	var draw_half: float = sub_half * (SUB_CONE_OVERLAP if parts > 1 else 1.0)
	var sy: float = sx * clampf(tan(draw_half) / tan(base_half), 0.8, FLAME_MAX_STRETCH)
	## Sprite asaya bağlı kalır (fx_enchant_sprite silah takibi, uzak ekranlarda kuklanın asa kopyasına): oyuncu yürüse de
	## asanın ucundan çıkmaya devam eder (yön = hasar yönü). pos yalnız silah bulunamazsa kullanılır.
	var pl: Node = owner_player()
	var slot: int = int(pl.call("get_weapon_net_slot", weapon)) if pl and pl.has_method("get_weapon_net_slot") else -1
	## Sürekli alevin anahtarı: oyuncu + silah slotu + alt alev - her istemcide aynı (bkz. fx_enchant_sprite "key").
	var key_base: String = "destiny:%d:%d" % [my_peer(), slot if slot >= 0 else weapon.get_instance_id()]
	for k in range(parts):
		var part_off: float = -half + sub_half * float(2 * k + 1) ## bu alt alevin koni ekseninden (asanın bakışından) açısı
		var d: Dictionary = {"rot": dir.angle() + part_off, "scale": Vector2(sx, sy),
			"offset": FLAME_OFFSET, "z": 9, "loop_time": iv + FLAME_LINGER, "key": "%s:%d" % [key_base, k]}
		if slot >= 0:
			d["follow_slot"] = slot
			d["follow_peer"] = my_peer()
			## Yön asanın ÇİZİLİ bakışından alınır (her ekranda asayla aynı yöne bakar; bkz. fx_enchant_sprite "follow_aim").
			d["follow_aim"] = true
			d["rot_offset"] = part_off
		sprite(sheet, origin, d)
	var seen: Dictionary = {}
	var push_now: bool = f("spray_push") > 0.0 and _push_t <= 0.0
	if push_now:
		_push_t = PUSH_EVERY
	for e in enemies_near(origin, r):
		var to_e: Vector2 = e.global_position - origin
		if to_e.length() > 6.0 and absf(dir.angle_to(to_e)) > half:
			continue
		hit(e, ap() * f("spray_ap"))
		var id: int = e.get_instance_id()
		seen[id] = true
		if _ice():
			var c: float = float(_in_cone.get(id, 0.0)) + iv
			if c >= f("freeze_build", 2.0):
				c = 0.0
				freeze(e, f("freeze_time", 1.5) * f("elem_dur_mult", 1.0))
			_in_cone[id] = c
		else:
			e.apply_element("burn", elem({"tick": ap() * f("elem_ap"), "dur": f("elem_dur", 3.0) * f("elem_dur_mult", 1.0), "max_stacks": 1}))
		if push_now and not e.is_boss:
			e.apply_element("knock", {"dir": to_e.normalized() if to_e.length() > 1.0 else dir, "dist": f("spray_push"), "quiet": true})
	for id in _in_cone.keys():
		if not seen.has(id):
			_in_cone.erase(id)
	if flag("dragon") and _pool_t <= 0.0:
		_pool_t = POOL_EVERY
		var at: Vector2 = origin + dir * r * 0.7
		if _ice():
			area("field", at, {"radius": 55.0, "duration": 2.0, "tick": 0.5, "damage": 0.0, "freeze": 1.5, "stun": 1.0,
				"sheet": "frost_ground", "sheet_scale": 55.0 / (45.0 * 1.212)})
		else:
			area("lava", at, {"radius": 45.0, "duration": 3.0, "burn_tick": ap() * 0.2, "burn_dur": 1.5, "ap": ap(),
				"sheet": "lava_pool", "sheet_scale": 45.0 / (37.0 * 1.212)})


func _pick_target(origin: Vector2) -> Node:
	var best: Node = null
	var best_d: float = INF
	for e in enemies_near(origin, _range() + 20.0):
		if not VisionFogScript.can_target(e):
			continue
		var d: float = e.global_position.distance_squared_to(origin)
		if d < best_d:
			best_d = d
			best = e
	return best
