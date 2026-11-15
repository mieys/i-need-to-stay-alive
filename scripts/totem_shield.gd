extends TotemBase
class_name TotemShield

## Kalkan Totemi (Shaman ULTİ, skill id 26): "Etrafındaki müttefiklere her
## saniye kendi kalkanlarının %0.5'ini yeniler ve shaman'ın saldırı gücünün
## %20'si kadar kalkan yeniler."
##
## Ally'ye kalkan verme _apply_shield_heal_to_ally() üzerinden YAPILMALI
## (bkz. player.gd, CLAUDE.md'nin bahsettiği TAM hata sınıfı) - doğrudan
## .heal_shield() çağırmak sadece caster'ın o ally'nin KOZMETİK kuklasını
## etkiler, gerçek client'ına ulaşmaz.
##
## DÜZELTME (kullanıcı isteği: "saldırı gücü oranını %10'dan %20'ye
## yükselt") - eskiden 0.10 idi.
const SELF_PERCENT := 0.005
## Kullanıcı isteği (2026-09-24 denge turu): "Shaman'ın kalkanı %12 AP olsun" - 0.20 -> 0.12 (30sn boyunca tüm takıma
## saniyede AP'nin %20'si kalkan, AP ile sınırsız büyüyen en güçlü takım savunmalarından biriydi).
const ATTACK_POWER_RATIO := 0.07 ## 2026-10-10: 0,12 -> 0,07 (kullanıcı: "Shaman'ın kalkan veren yeteneğinin saldırı gücü oranlarını biraz düşür, çok kalkan veriyor")
## Yetenek evrimleri (kart metinleri skill_evolutions.gd DEFS[12]): "Güçlü Kalkan" (shaman_e4) verilen kalkan x1.5;
## "Savaş Ritmi" (shaman_e2) alandaki oyunculara +%15 saldırı hızı (player.gd enchant_haste_value "atk_speed" buff'ı okur).
const EVO_SHIELD_MULT := 1.5
const EVO_ATTACK_SPEED := 0.15
const EVO_SLOW_PERCENT := 0.7 ## Yapışkan Zemin (shaman_e3): alandaki yaratıklar %70 yavaşlar (temel yavaşlatma YOK - evrim getirir)
const EVO_SLOW_TIME := 1.5 ## alan tiki 1 sn'de bir - yavaşlatma bir sonraki tikte yenilenir, alandan çıkınca ~0.5 sn sonra biter
const EVO_PUSH_DISTANCE := 34.0 ## İtici Dalga (shaman_ef): her hasar tikinde merkezden dışarı itme (dünya birimi)
const EVO_BUFF_TIME := 1.6 ## player.gd EVO_BUFF_REFRESH_TIME ile aynı (tik 1 sn; buff tikler arasında düşmesin)

## KALKAN ŞERİDİ (madde 567, kullanıcı: "kalkan göndermenin tick-tick olması şart değil devamlı veren bir şey de olabilir" -> prototip
## madde 562, seçilen "D Işık Tülü" ince + dünya ızgarası): taştan menzildeki her hedefe SÜREKLİ ışık tülü (`totem_link_ribbon.gd`),
## hedefin kendi kalkan baloncuğuna bağlanır ve onun renginde biter; bağlıyken yerel oyuncunun baloncuğu açık kalır
## (player.gd set_shaman_link -> _bubble_active -> ağda "shield_bubble_visible"). TAMAMEN kozmetik: _tick'teki kalkan hesabına etkisi yok.
## Her istemcide yerel çizilir (gerçek totem + ağ görsel kopyası aynı _process yolu), ek RPC yok. Eski tikte uçan kalkan simgesi
## (totem_shield_wave.gd) silindi.
const LinkRibbonScript := preload("res://scripts/totem_link_ribbon.gd")
## Bu kadar yakın (totemin dibindeki = dikeni Shaman'ın kendisi) hedeflere şerit çizilmez.
const WAVE_MIN_DISTANCE := 40.0
## Kalkan şeridi RÜN TAŞINDAN çıkar (madde 557: "kalkan orbları bu taştan gönderilecek"): E taşının rün merkezi - rünlerin birleşik
## kutusu 32x32 karede (15, 15.5) -> (-1, -0.5) x 0.632 + TotemSprite y -8 (bkz. totem_shield.tscn) = (-0.6, -8.3).
const ORB_ORIGIN_OFFSET := Vector2(-1, -8)

var _wave_timer: float = 0.0
## hedefin instance_id -> TotemLinkRibbon
var _links: Dictionary = {}

## AURA SINIRI (madde 586, kullanıcı: "Shaman'ın E yeteneğinin aura sınırının görünmesini sağla", prototip C "Işık Perdesi"): totem_radius
## çemberinde yerde çizgi + alçak ışık duvarı. Totemin çocuğu DEĞİL - haritanın içinde zemin katmanlarının hemen arkasında (GroundSlot.
## add_on_floor; ağaç/ev/karakterler onu örter). Totemi izler, totem gidince kendisi söner (totem_aura_border.gd). Gerçek totem ve ağ
## görsel kopyası aynı _ready yolu -> herkes görür. Madde 557 ek 2'de silinen halkalardan (noktalı halka, dönen rün, dolgu, nabız) ayrı.
const AuraBorderScript := preload("res://scripts/totem_aura_border.gd")
const GroundSlotScript := preload("res://scripts/ground_slot.gd")
var _aura_border: Node2D = null


func _ready() -> void:
	super()
	_aura_border = AuraBorderScript.new()
	_aura_border.set("totem", self)
	GroundSlotScript.add_on_floor(_aura_border, self)


## Test / ayıklama: bu totemin aura sınırı düğümü (sönmüşse null).
func aura_border() -> Node2D:
	return _aura_border if is_instance_valid(_aura_border) else null


func _init() -> void:
	totem_kind = "shield"
	totem_color = Color(0.35, 0.65, 1.0)
	totem_radius = 220.0
	rune_center = ORB_ORIGIN_OFFSET
	## Kullanıcı isteği (2026-09-30): Saldırı Totemi'nin alan hasarı bu totemde de (bkz. totem_base.gd "ALAN HASARI").
	area_damage_enabled = true
	## Mor alan çemberi + tik nabız halkası çizilmez (madde 557 ek 2, kullanıcı: "dış halkaları kaldır"); alan hasarı aynen çalışır.
	show_area_aura = false


## Kalkan Totemi evrimleri (alan hasar tiki, bkz. totem_base.gd _on_area_enemy_tick): "Yapışkan Zemin" ve final "İtici Dalga".
## slow/push enemy.gd'nin host-yönlendirmeli çağrılarıdır (istemci kasterden de çalışır).
func _on_area_enemy_tick(enemy: Node2D) -> void:
	if _caster_has_evo("shaman_e3") and enemy.has_method("apply_slow"):
		BalanceLogScript.on_cc("s:shaman_kalkan_alan", "slow", enemy, EVO_SLOW_TIME)
		enemy.call("apply_slow", EVO_SLOW_PERCENT, EVO_SLOW_TIME)
	if _caster_has_evo("shaman_ef") and enemy.has_method("apply_skill_push"):
		var away: Vector2 = enemy.global_position - global_position
		if away.length() < 1.0:
			away = Vector2.from_angle(randf() * TAU)
		enemy.call("apply_skill_push", away.normalized(), EVO_PUSH_DISTANCE)


func _process(delta: float) -> void:
	## Gerçek mantık: TotemBase._process - _tick YALNIZCA dikeni oyuncunun kendi client'ında, ağ kopyalarında asla çalışmaz.
	super(delta)
	## Kozmetik şerit + tik parlaması ağ GÖRSEL kopyalarında DA çalışır (salt çizim, oyun durumu paylaşılmaz).
	_update_links(delta)
	_wave_timer -= delta
	if _wave_timer > 0.0:
		return
	_wave_timer += TICK_INTERVAL
	## Tikte taş kısa parlar + çok kısık kalkan cıngırtısı (30 sn boyunca saniyede bir - rahatsız etmesin diye çok yumuşak).
	_flare_stone()
	ShamanSfx.play_at(get_tree().current_scene, ShamanSfx.SHIELD_PULSE, global_position, -19.0, 0.04)


## Şerit hedefleri: _tick'in kalkan verdiği kişiler (menzilde + item_shield_max), yaşayan, totemin dibinde olmayan. "player_ally" grubu
## yalnız uzak kuklaları (ve evcilleri) içerir, yerel oyuncu "player" grubunda - ikisi birden taranır (tek oyunculu dahil).
func _link_targets() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	var pool: Array = get_tree().get_nodes_in_group("player_ally")
	for p in get_tree().get_nodes_in_group("player"):
		if not pool.has(p):
			pool.append(p)
	for target in pool:
		if not is_instance_valid(target) or not (target is Node2D):
			continue
		if not ("item_shield_max" in target):
			continue
		if target.get("is_dead") == true or target.get("is_downed") == true:
			continue
		var dist: float = global_position.distance_to((target as Node2D).global_position)
		if dist > totem_radius or dist < WAVE_MIN_DISTANCE:
			continue
		out.append(target)
	return out


func _update_links(delta: float) -> void:
	var src: Vector2 = global_position + ORB_ORIGIN_OFFSET + _stone_hover() ## süzülen taşla birlikte (madde 569)
	var alive: Dictionary = {}
	for target in _link_targets():
		var key: int = (target as Node).get_instance_id()
		alive[key] = true
		var ribbon: Variant = _links.get(key)
		if ribbon == null or not is_instance_valid(ribbon) or ribbon.call("is_releasing"):
			ribbon = LinkRibbonScript.new()
			add_child(ribbon)
			_links[key] = ribbon
		ribbon.call("update_link", src, target, delta)
		## Bağlıyken hedefin kalkan baloncuğu açık (yalnız yerel Player'da var; kuklanınki sahibinden ağla gelir).
		if target.has_method("set_shaman_link"):
			target.call("set_shaman_link")
	for key in _links.keys():
		if alive.has(key):
			continue
		var r: Variant = _links[key]
		if is_instance_valid(r):
			r.call("release")
		_links.erase(key)


## Test / ayıklama: şu an çizilen (sönmeyen) şerit sayısı.
func link_count() -> int:
	var n: int = 0
	for r in _links.values():
		if is_instance_valid(r) and not r.call("is_releasing"):
			n += 1
	return n


func _tick() -> void:
	if not ("damage_bonus" in caster):
		return
	var flat_bonus: float = float(caster.damage_bonus) * ATTACK_POWER_RATIO
	var evo_shield_mult: float = EVO_SHIELD_MULT if _caster_has_evo("shaman_e4") else 1.0
	var haste_buff: bool = _caster_has_evo("shaman_e2") and caster.has_method("_evo_give_buff")
	## Savaş Ritmi: kendisi (alandaysa) + alandaki müttefikler. Buff her tikte tazelenir, alandan çıkınca/totem kapanınca kısa sürede düşer.
	if haste_buff and global_position.distance_to(caster.global_position) <= totem_radius:
		caster._evo_give_buff(caster, "atk_speed", EVO_ATTACK_SPEED, EVO_BUFF_TIME)

	## Kendi kalkanı.
	if "item_shield_max" in caster and "item_shield_hp" in caster:
		var self_amount: float = (float(caster.item_shield_max) * SELF_PERCENT + flat_bonus) * evo_shield_mult
		if caster.has_method("heal_shield"):
			caster.heal_shield(self_amount, true, true, &"s:shaman_kalkan_totemi")

	## Etraftaki müttefikler - Oakley'nin pasif can yenileme döngüsüyle
	## (player.gd _process_healer_shield_tick benzeri) AYNI "player_ally"
	## grubu taraması.
	for ally in caster.get_tree().get_nodes_in_group("player_ally"):
		if not is_instance_valid(ally):
			continue
		if global_position.distance_to(ally.global_position) > totem_radius:
			continue
		if haste_buff:
			caster._evo_give_buff(ally, "atk_speed", EVO_ATTACK_SPEED, EVO_BUFF_TIME)
		if not ("item_shield_max" in ally):
			continue
		var ally_amount: float = (float(ally.item_shield_max) * SELF_PERCENT + flat_bonus) * evo_shield_mult
		if caster.has_method("_apply_shield_heal_to_ally"):
			caster._apply_shield_heal_to_ally(ally, ally_amount, &"s:shaman_kalkan_totemi")


func _area_balance_tag() -> StringName:
	return &"s:shaman_kalkan_alan"
