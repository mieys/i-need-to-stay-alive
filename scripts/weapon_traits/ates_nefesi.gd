extends "res://scripts/enchant_behavior.gd"

## ATEŞ NEFESİ - Ateş Asası'nın kalıcı özelliği (tanım: weapon_traits.gd "ates_nefesi"; 2026-10-11'e kadar eski "Destiny of Ice and Fire"
## efsunuydu, o kapalı kart hâlâ bu scripti kullanır: scripts/enchants/destiny.gd -> buz dalı yalnız orada işe yarar).
## Asanın normal atışı KAPANIR (replaces_shot); bunun yerine en yakın düşmana doğru sürekli alev püskürtür: saldırı hızıyla hızlanan
## tiklerde ALEVİN İÇİNDEKİLERE hasar, Ateş'te yanma, Buz'da alevde "freeze_build" sn kalana donma.
## GÖRSEL + ALAN (madde 639, 2026-11-13; kullanıcı: "Pixel FX FIRE VER 1.0'daki flamethrower efektini ateş asasının yeni efekti olarak
## ayarla ve uzunluğuna göre etki alanını değiştir, aynı efektteki gibi olsun etki alanı"): kullanıcının paketindeki "Flamethrower
## Left_Right" (tools/gen_flamethrower_fx.py -> flamethrower_fire / flamethrower_ice; start 6 + loop 12 + end 5 kare, 16,7 fps).
## Hasar alanı ESKİ 60°'lik koni DEĞİL, çizilen alevin kendisi: flamethrower_shape.gd (üreteç yazar) - ağızda ince hat, uçta yukarı
## kabaran ateş bulutu; 1 sanat pikseli = karakter pikseli (WORLD_PX), boy 177 px = 160 birim. "start" animasyonu sürerken alan da
## alevle birlikte uzar (Shape.reach_at). Sola bakarken sayfa dikey aynalanır (bulut hep yukarıda; fx_enchant_sprite "flip_left"),
## alanın y işareti de döner (_flipped). Alevin boyu SABİT (eski "Genişleyen Boğaz" + finalin ayrı büyük alev sayfası kalktı).
## Püskürtme sürdükçe TEK sürekli efekt (fx_enchant_sprite "key"): her tik yaşayan efektin ömrünü uzatır; hedef kalmayınca
## FLAME_LINGER sonunda "end" animasyonuyla söner. Efekt karakterlerin ALTINDA çizilir (fx_enchant_sprite "under").
## Tikler aynı yoldan (enchant_fx "sprite" -> broadcast) diğer oyunculara da gider; anahtar aynı olduğu için orada da tek efekt.
## Eski sayfalar (flame_shower_*, flame_*, spray_*) duruyor, kullanılmıyor.

const Shape := preload("res://scripts/weapon_traits/flamethrower_shape.gd")
## Madde 640: asa dönünce alev bükülür (uç geride kalır) - görsel ve hasar alanı AYNI hesap (flame_bend.gd).
const FlameBend := preload("res://scripts/weapon_traits/flame_bend.gd")
const SpriteFx := preload("res://scripts/fx_enchant_sprite.gd")
const TEXEL := 1.212
const WORLD_PX := 0.903 ## 1 sanat pikseli kaç dünya birimi (karakter pikseli)
## Alanın kenarına eklenen pay (dünya birimi): yaratığın gövdesi alevin çizgisine değiyorsa yanar (konum ayak/merkez noktası).
const HIT_MARGIN := 12.0
const TIP_FROM := 0.62 ## Kavurucu Uç: alevin bu oranından sonrası = uçtaki büyük ateş bulutu
## Son tikten sonra alevin kalma süresi - fx_enchant_sprite.FADE'den (0,25) uzun: tik arasında alev solup yanıp sönmesin.
const FLAME_LINGER := 0.35
const POOL_EVERY := 1.0
const MIN_TICK := 0.06
## Püskürtme sesi (2026-10-11, kullanıcı: "ateş asası ateş püskürtünce ses efekti çıkarsın"): tools/gen_flame_sounds.py.
const FLAME_SFX := "res://assets/audio/fire_staff_spray_loop.wav" ## çok yüksek saldırı hızında bile en sık bu kadar (saniyede ~16 tik)
const PUSH_EVERY := 0.5
## Püskürtme sesi seviyesi (2026-10-12): -1 dB -> ~-25,5 dBFS (diğer silah sesleriyle aynı mertebe). Tepe -3,1 dBFS: kırpma yok.
const FLAME_SFX_DB := -1.0

const WeaponTip := preload("res://scripts/weapon_tip.gd")

var _tick_t: float = 0.0
var _in_cone: Dictionary = {}
var _swept: Dictionary = {} ## id -> [yaratık, en büyük alev oranı]: son tikten beri alevin değdikleri
var _pool_t: float = 0.0
var _push_t: float = 0.0
var _aim: Node2D = null
## Püskürtmenin başladığı an (msn): efekt sönüp yeniden açılınca "start" animasyonu baştan oynar -> alan da baştan uzar.
var _spray_start_ms: int = -1
var _last_tick_ms: int = -1
var _last_iv: float = 0.25
var _bend: RefCounted = FlameBend.new() ## asanın çizili bakış geçmişi (her karede)


func replaces_shot() -> bool:
	return true


## Asa püskürtmenin hedefine bakar (weapon.gd _update_aim) - alev sprite'ı asanın ucundan, baktığı yönden çıkar.
func aim_target() -> Node2D:
	return _aim if is_instance_valid(_aim) else null


func _ice() -> bool:
	return weapon_key() == "buz_asasi"


## Alevin tam boyu (dünya birimi) = çizilen alevin boyu.
func _range() -> float:
	return Shape.LENGTH * WORLD_PX


## Tik aralığı SALDIRI HIZIYLA kısalır (kullanıcı 2026-10-11: "alev asasının püskürtmesi saldırı hızına göre artmalı"). Diğer silahların
## atış aralığıyla AYNI kaynak (weapon._effective_fire_wait) - taban atış aralığına oranı tik aralığını ölçekler.
func _interval() -> float:
	var m: float = 1.0
	if is_instance_valid(weapon) and weapon.has_method("_effective_fire_wait"):
		var base: float = float(weapon.get("_base_fire_rate"))
		if base > 0.0:
			m = float(weapon.call("_effective_fire_wait")) / base
	else:
		var pl: Node = owner_player()
		m = float(pl.call("get_attack_interval_mult")) if pl and pl.has_method("get_attack_interval_mult") else 1.0
		m /= 1.0 + attack_speed_bonus()
	return maxf(MIN_TICK, f("spray_tick", 0.25) * m / (1.0 + f("spray_rate")))


## Sola bakan alev dikey aynalanır (bulut hep yukarıda) - fx_enchant_sprite "flip_left" ile aynı kural (eşik payı orada).
static func _flipped(dir: Vector2) -> bool:
	return dir.x < 0.0


## Dünya noktası alevin içinde mi: [içinde mi, alev boyunca oran 0..1]. origin = ağız, dir = alev yönü (birim), reach = alevin o anki boyu (sanat px).
## bend: FlameBend.angles() (boş = düz alev). Bükülmüş alevdeki nokta önce düz alevdeki karşılığına çevrilir (shader ile aynı).
static func flame_contains(origin: Vector2, dir: Vector2, point: Vector2, reach: float, margin: float = HIT_MARGIN,
		bend: PackedFloat32Array = PackedFloat32Array()) -> Array:
	var to: Vector2 = point - origin
	var lx: float = to.dot(dir) / WORLD_PX
	var ly: float = to.dot(Vector2(-dir.y, dir.x)) / WORLD_PX
	if not bend.is_empty():
		var q: Vector2 = FlameBend.unbend(Vector2(lx, ly), bend, Shape.LENGTH)
		lx = q.x
		ly = q.y
	if _flipped(dir):
		ly = -ly
	var m: float = margin / WORLD_PX
	var r: float = minf(reach, Shape.LENGTH)
	if lx < -m or lx > r + m:
		return [false, 0.0]
	var band: Vector2 = Shape.band_at(clampf(lx, 0.0, r))
	var inside: bool = ly >= band.x - m and ly <= band.y + m
	return [inside, clampf(lx / Shape.LENGTH, 0.0, 1.0)]


## Isınan Nefes çarpanı: kesintisiz püskürtmenin süresiyle artar (final).
func _heat_mult(now_ms: int) -> float:
	if not flag("heat") or _spray_start_ms < 0:
		return 1.0
	var secs: float = float(now_ms - _spray_start_ms) / 1000.0
	return 1.0 + minf(f("heat_cap", 0.45), f("heat_rate", 0.15) * secs)


func process_extra(delta: float) -> void:
	_pool_t = maxf(0.0, _pool_t - delta)
	_push_t = maxf(0.0, _push_t - delta)
	if not can_act() or not is_instance_valid(weapon):
		return
	var icon: Sprite2D = weapon.get("icon_sprite") as Sprite2D
	var now_s: float = Time.get_ticks_msec() / 1000.0
	if icon:
		_bend.call("push", now_s, SpriteFx.icon_aim_angle(icon, float(weapon.get("sprite_forward_angle_deg"))))
	var origin: Vector2 = weapon.global_position
	## Talon E (Silah Salvosu) / kubbe girdabı: püskürtme yaratık aramaz, yaratık olsun olmasın ikonun BAKTIĞI yöne düz sürer (2026-11-12,
	## kullanıcı: "dümdüz saldırı spamlaması gerekirken menzile yaratık girince aktifleşiyor"); alevdeki yaratıklar yine hasar alır.
	var facing: bool = weapon.has_method("_beam_facing_mode") and bool(weapon.call("_beam_facing_mode"))
	var tgt: Node = null if facing else _pick_target(origin)
	_aim = tgt as Node2D
	if tgt == null and not facing:
		_in_cone.clear()
		_swept.clear()
		return
	_tick_t -= delta
	if _tick_t > 0.0:
		_collect_swept(origin, tgt, facing, icon, now_s)
		return
	var iv: float = _interval()
	_tick_t = iv
	var now: int = Time.get_ticks_msec()
	## Önceki efekt söndüyse (son tikten bu yana tik aralığı + kalma süresi geçti) yeni efekt "start"tan başlar.
	if _last_tick_ms < 0 or now - _last_tick_ms > int((_last_iv + FLAME_LINGER) * 1000.0):
		_spray_start_ms = now
		if icon:
			_bend.call("reset", now_s, SpriteFx.icon_aim_angle(icon, float(weapon.get("sprite_forward_angle_deg"))))
	_last_tick_ms = now
	_last_iv = iv
	## Alev asanın ÇİZİLİ UCUNDAN çıkar (eskiden silah kökü = asanın ortası) - hasar alanı da görselle aynı noktadan.
	if icon:
		origin = WeaponTip.tip_global(icon, float(weapon.get("sprite_forward_angle_deg")))
	## Madde 640: alan, görseldeki gibi asanın ÇİZİLİ bakışından çıkar (görsel "follow_aim" ile aynı açı) - büküm de o yöne göre.
	## Asa dönerken hedefe henüz bakmıyorsa alev de oraya varmaz (mermilerdeki "namlunun baktığı yön" kuralı, madde 549).
	var dir: Vector2
	if facing:
		dir = Vector2(weapon.call("_icon_facing_dir"))
	elif icon:
		dir = Vector2.from_angle(SpriteFx.icon_aim_angle(icon, float(weapon.get("sprite_forward_angle_deg"))))
	else:
		dir = dir_to(origin, tgt)
	var reach: float = Shape.reach_at(float(now - _spray_start_ms) / 1000.0)
	var heat: float = _heat_mult(now)
	var k: float = WORLD_PX / TEXEL
	var sheet: String = "flamethrower_ice" if _ice() else "flamethrower_fire"
	## Efekt asanın ucunu ve bakışını izler (fx_enchant_sprite silah takibi, uzak ekranlarda kuklanın asa kopyası).
	var pl: Node = owner_player()
	var slot: int = int(pl.call("get_weapon_net_slot", weapon)) if pl and pl.has_method("get_weapon_net_slot") else -1
	## Sürekli efektin anahtarı: oyuncu + silah slotu + sayfa - her istemcide aynı (bkz. fx_enchant_sprite "key").
	var key_base: String = "destiny:%d:%d" % [my_peer(), slot if slot >= 0 else weapon.get_instance_id()]
	var d: Dictionary = {"rot": dir.angle(), "scale": Vector2(k, k), "offset": Shape.SHEET_OFFSET, "flip_left": true,
		"bend_len": Shape.LENGTH, "loop_time": iv + FLAME_LINGER, "key": "%s:ft" % key_base}
	if heat > 1.001:
		d["bright"] = 1.0 + (heat - 1.0) * 0.8 ## Isınan Nefes: alev ısındıkça parlar
	if not _ice():
		d["loop_sfx"] = FLAME_SFX ## sürekli efektin sesi (bkz. fx_enchant_sprite "loop_sfx")
		d["sfx_db"] = FLAME_SFX_DB
	if slot >= 0:
		d["follow_slot"] = slot
		d["follow_peer"] = my_peer()
		## Yön asanın ÇİZİLİ bakışından alınır (her ekranda asayla aynı yöne bakar; bkz. fx_enchant_sprite "follow_aim").
		d["follow_aim"] = true
		d["rot_offset"] = 0.0
		d["under"] = true ## karakterlerin ALTINDA, sahne kökünde (bkz. fx_enchant_sprite "follow_world")
	sprite(sheet, origin, d)
	var seen: Dictionary = {}
	var push_now: bool = f("spray_push") > 0.0 and _push_t <= 0.0
	if push_now:
		_push_t = PUSH_EVERY
	var bend: PackedFloat32Array = _bend.call("angles", now_s, Shape.LENGTH)
	var base_dmg: float = ap() * f("spray_ap") * _weapon_stat_mult() * heat
	## Tikler arasında alevin SÜPÜRDÜĞÜ yaratıklar da (hedef değiştirirken alev başkalarının üstünden geçer) bu tikte vurulur.
	var touched: Dictionary = {}
	for id in _swept.keys():
		var sw: Array = _swept[id]
		if is_instance_valid(sw[0]):
			touched[id] = sw
	_swept.clear()
	for e in enemies_near(origin, reach * WORLD_PX + HIT_MARGIN + 34.0):
		var res: Array = flame_contains(origin, dir, (e as Node2D).global_position, reach, HIT_MARGIN, bend)
		if bool(res[0]):
			touched[e.get_instance_id()] = [e, float(res[1])]
	for sw in touched.values():
		var e: Node = sw[0]
		if facing and weapon.has_method("_can_target") and not bool(weapon.call("_can_target", e)):
			continue ## sis/çalı: görünmeyen yaratık hedef alınamaz (normal modda hedef seçimi zaten bunu eler)
		var tip_mult: float = 1.0 + (f("tip_bonus") if float(sw[1]) >= TIP_FROM else 0.0)
		hit(e, base_dmg * tip_mult)
		var id: int = e.get_instance_id()
		seen[id] = true
		if _ice():
			var c: float = float(_in_cone.get(id, 0.0)) + iv
			if c >= f("freeze_build", 2.0):
				c = 0.0
				freeze(e, f("freeze_time", 1.5) * f("elem_dur_mult", 1.0))
			_in_cone[id] = c
		else:
			el(e, "burn", elem({"tick": ap() * f("elem_ap"), "dur": f("elem_dur", 3.0) * f("elem_dur_mult", 1.0), "max_stacks": 1}))
		var to_e: Vector2 = (e as Node2D).global_position - origin
		if push_now and not status(e, "boss"):
			el(e, "knock", {"dir": to_e.normalized() if to_e.length() > 1.0 else dir, "dist": f("spray_push"), "quiet": true})
	for id in _in_cone.keys():
		if not seen.has(id):
			_in_cone.erase(id)
	if flag("dragon") and _pool_t <= 0.0 and reach >= Shape.LENGTH:
		_pool_t = POOL_EVERY
		## Lav, alevin ucundaki ateş bulutunun ortasına düşer.
		var lx: float = Shape.LENGTH * 0.85
		var band: Vector2 = Shape.band_at(lx)
		var ly: float = (band.x + band.y) * 0.5 * (-1.0 if _flipped(dir) else 1.0)
		var at: Vector2 = origin + (dir * lx + Vector2(-dir.y, dir.x) * ly) * WORLD_PX
		if _ice():
			area("field", at, {"radius": 55.0, "duration": 2.0, "tick": 0.5, "damage": 0.0, "freeze": 1.5, "stun": 1.0,
				"sheet": "frost_ground", "sheet_scale": 55.0 / (45.0 * 1.212)})
		else:
			area("lava", at, {"radius": 45.0, "duration": 3.0, "burn_tick": ap() * 0.2, "burn_dur": 1.5, "ap": ap(),
				"sheet": "lava_pool", "sheet_scale": 45.0 / (37.0 * 1.212)})


## Tik beklenirken HER KARE: alev görünürken değdiği yaratıkları kaydeder (süpürme). Hasar yine tikte verilir (tik hızı/hasar aynı),
## yalnız alevin dönerken tiklerin arasından geçtiği yaratıklar artık kaçmaz.
func _collect_swept(root: Vector2, tgt: Node, facing: bool, icon: Sprite2D, now_s: float) -> void:
	var now: int = Time.get_ticks_msec()
	if _last_tick_ms < 0 or now - _last_tick_ms > int((_last_iv + FLAME_LINGER) * 1000.0):
		return ## alev şu an yok
	var origin: Vector2 = root
	var dir: Vector2
	if icon:
		origin = WeaponTip.tip_global(icon, float(weapon.get("sprite_forward_angle_deg")))
	if facing:
		dir = Vector2(weapon.call("_icon_facing_dir"))
	elif icon:
		dir = Vector2.from_angle(SpriteFx.icon_aim_angle(icon, float(weapon.get("sprite_forward_angle_deg"))))
	else:
		dir = dir_to(origin, tgt)
	var reach: float = Shape.reach_at(float(now - _spray_start_ms) / 1000.0)
	var bend: PackedFloat32Array = _bend.call("angles", now_s, Shape.LENGTH)
	for e in enemies_near(origin, reach * WORLD_PX + HIT_MARGIN + 34.0):
		var res: Array = flame_contains(origin, dir, (e as Node2D).global_position, reach, HIT_MARGIN, bend)
		if not bool(res[0]):
			continue
		var id: int = e.get_instance_id()
		## Uç bölgesi (Kavurucu Uç) bir kez bile değdiyse sayılır.
		if not _swept.has(id) or float(res[1]) > float((_swept[id] as Array)[1]):
			_swept[id] = [e, float(res[1])]


func _pick_target(origin: Vector2) -> Node:
	var best: Node = null
	var best_d: float = INF
	for e in enemies_near(origin, _range() + 20.0):
		if not (weapon.call("_can_target", e) if is_instance_valid(weapon) and weapon.has_method("_can_target") else VisionFogScript.can_target(e)):
			continue
		var d: float = e.global_position.distance_squared_to(origin)
		if d < best_d:
			best_d = d
			best = e
	return best


## Asanın TEK hasar kaynağı püskürtme `ap()` ile hesaplanır (silahın `damage`ından geçmez): silah hasarı çarpanı (weapon.gd damage_stat_mult, 2026-10-12 deneme) buraya da biner.
func _weapon_stat_mult() -> float:
	return float(weapon.call("damage_stat_mult")) if is_instance_valid(weapon) and weapon.has_method("damage_stat_mult") else 1.0
