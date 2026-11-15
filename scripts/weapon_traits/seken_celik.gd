extends "res://scripts/enchant_behavior.gd"

## Seken Çelik (Çakram, kalıcı özellik; madde 591, 2026-11-11) - bkz. weapon_traits.gd "seken_celik". Eski "Çifte Dönüş"ün (her N. atışta
## ikinci çakram) yerine; kullanıcı: "chakram şu an boomerangın özelliğini kullanıyor" -> çakrama özgü özellik + final.
##  - SEKME: çarptığı düşmandan sana dönmek yerine rico_range içindeki en yakın, bu atışta vurulmamış düşmana seker (rico_count kez),
##    sekerek vurulan isabet ilk isabetin rico_dmg katı. Mekanik boomerang_projectile.gd'de (_try_bounce); burada mermiye ayarlar yazılır
##    (projectile_extra kasterde, look_extra "props" ile uzak kopyada da) ve her sekme diğer oyunculara "chakram_leg" olarak gider.
##  - Çentik: sekerek vurulan düşman rico_slow kadar 1 sn yavaşlar (hit_extra; proj.bounces_done > 0 = sekme bacağının isabeti).
##  - FİNAL Çelik Değirmen: çakram dönmeye başladığı yerde (son sekme / bacak sonu) kendinin çelik kopyasını bırakır - mill_dur sn yerinde
##    döner, mill_radius içine mill_tick'te bir SG x mill_ap (alan hasarı). Aynı anda en fazla 1 kopya; atış hiçbir şeye vurmadıysa kopya yok.
##    Hasar yalnız kasterde (bu dosya), görsel scripts/chakram_mill_fx.gd (EnchantFx "chakram_mill", güvenilir kanal).
## Tüm hasar/yavaşlatma yetkisi silahın sahibinde (diğer silah vuruşları gibi).

const ChakramMillScript := preload("res://scripts/chakram_mill_fx.gd")
const LimboScript := preload("res://scripts/limbo.gd")
const SLOW_DUR := 1.0

var bounces: int = 0 ## gerçekleşen sekme sayısı (test/gözlem)
var mills: int = 0 ## bırakılan kopya sayısı (test/gözlem)
## Etkin kopya(lar): {pos, t, tick}. Silahın meta'sında (keep) - geliştirme alınınca davranış yeniden kurulsa da süren kopya vurmaya devam eder.
var _mills: Array = []


func _on_setup() -> void:
	_mills = keep_get("seken_mills", []) as Array
	keep_set("seken_mills", _mills)


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	if not ("bounce_left" in proj):
		return
	proj.set("bounce_left", n("rico_count", 1))
	proj.set("bounce_range", f("rico_range", 100.0))
	proj.set("bounce_dmg_mult", f("rico_dmg", 0.4))
	proj.set("net_pid", randi_range(1, 2147483646))


## Uzak kopya da sekme hakkını bilsin (çarpınca kendi dönmesin, kasterin "chakram_leg" mesajını beklesin) + kimliği.
func look_extra(proj: Node2D, d: Dictionary) -> Dictionary:
	if proj == null or not ("bounce_left" in proj) or int(proj.get("bounce_left")) <= 0:
		return d
	var props: Dictionary = (d.get("props", {}) as Dictionary).duplicate()
	props["bounce_left"] = int(proj.get("bounce_left"))
	props["net_pid"] = int(proj.get("net_pid"))
	d["props"] = props
	return d


func hit_extra(t: Node, _dmg: float, _is_primary: bool, proj: Node2D) -> void:
	if f("rico_slow") <= 0.0 or proj == null or not is_instance_valid(proj) or int(proj.get("bounces_done")) <= 0:
		return
	el(t, "slow", {"pct": f("rico_slow"), "dur": SLOW_DUR})


func on_boomerang_bounce(proj: Node2D, _from_body: Node, to_body: Node) -> void:
	bounces += 1
	if NetworkManager.is_multiplayer_active and is_instance_valid(proj) and to_body is Node2D:
		NetworkManager.broadcast_enchant_area.rpc("chakram_leg", proj.global_position,
			{"pid": int(proj.get("net_pid")), "to": (to_body as Node2D).global_position})


func on_boomerang_apex(proj: Node2D) -> void:
	if f("mill_dur") <= 0.0 or not is_instance_valid(proj) or not can_act():
		return
	if int(proj.call("hit_count")) <= 0 or not _mills.is_empty():
		return
	var at: Vector2 = proj.global_position
	mills += 1
	_mills.append({"pos": at, "t": 0.0, "tick": 0.0})
	var data: Dictionary = {"dur": f("mill_dur"), "peer": LimboScript.local_peer()}
	ChakramMillScript.spawn(get_tree(), at, data)
	if NetworkManager.is_multiplayer_active:
		var net: Dictionary = data.duplicate()
		net["peer"] = my_peer()
		NetworkManager.broadcast_enchant_area.rpc("chakram_mill", at, net)


func process_extra(delta: float) -> void:
	if _mills.is_empty():
		return
	var dur: float = f("mill_dur")
	var r: float = f("mill_radius", 32.0)
	var tick: float = maxf(0.08, f("mill_tick", 0.3))
	for i in range(_mills.size() - 1, -1, -1):
		var m: Dictionary = _mills[i]
		m["t"] = float(m["t"]) + delta
		if float(m["t"]) >= dur:
			_mills.remove_at(i)
			continue
		m["tick"] = float(m["tick"]) - delta
		if float(m["tick"]) > 0.0:
			continue
		m["tick"] = tick
		if not can_act():
			continue
		for e in enemies_near(Vector2(m["pos"]), r):
			hit(e, ap() * f("mill_ap"))
