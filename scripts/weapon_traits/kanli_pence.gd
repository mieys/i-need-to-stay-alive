extends "res://scripts/enchant_behavior.gd"

## Kanlı Pençe (Pençe, kalıcı özellik) - bkz. EnchantDefs "kanli_pence". Her pençe tek yüklük (süresi tazelenen) süreli kanama
## bırakır (enchant_behavior.gd dot_*); ana hedefe her pençe darbesinde verilen hasarın kp_leech'i kadar can (alan payında YOK, 2026-10-19). "Yırtıcı Darbe" =
## ortak bleeding_bonus (modify_damage, status "bleeding" bu kaydı da sayar). Final: kanayan düşmanı öldürünce kısa saldırı hızı
## + azami canın kp_kill_heal'i kadar can (öldürme = mark_kill olayı ya da kendi kanama tikimizin öldürmesi).
## 2026-10-19 (kullanıcı: "pençe hala çok can çalıyor" -> "sınırları kaldırıp oranları düşür"): can emme oranı %3 -> %1 (Kan Emici %2), final
## %1 -> %0,5 azami can; saniyelik üst sınırlar (eskiden final için "saniyede en fazla bir kez", ara sürüm kp_leech_cap) YOK. Neden oran düşük: can emme
## hasarın yüzdesi, saldırı gücü can sayısından çok hızlı büyüyor (kayıt rev 63 Matthew: saldırı gücü 416, can 655; %3 = vuruş başına ~18 can).
## Kanama tikleri genel can çalma zarı atmaz (dot_rolls_lifesteal): tik "isabet" değil, kanayan her yaratık 0,5 sn'de bir zar atıyordu.
## Aynı ölüm iki yoldan gelir (kp_kill olayı + kanama tikinin ölü kurbanı bulması): final iki kez ödül vermesin diye olay sayılır, işaretli
## kurbanın tik yolu o sayıdan düşer (sınır değil, kurban başına tek ödül).

const KILL_HASTE_TIME := 3.0
const DEDUPE_MSEC := 2000
var _marked: Dictionary = {} ## işaretlenen (kanarken vurulan) kurbanın instance_id'si -> işaret anı (msec)
var _pending_event_rewards: int = 0 ## kp_kill olayıyla ödenip tik yolunda henüz "ödendi" diye düşülmemiş ölüm sayısı
var _pending_msec: int = 0


func dot_rolls_lifesteal() -> bool:
	return false


## Hasardan ÖNCE (modify_damage -> damage_extra): kanayan hedef bu vuruş sırasında ölürse host bize "kp_kill" olayını yollar.
func damage_extra(dmg: float, t: Node2D) -> float:
	if (f("kp_kill_haste") > 0.0 or f("kp_kill_heal") > 0.0) and dot_stacks(t) > 0:
		mark_kill(t, "kp_kill", 0.8)
		var now: int = Time.get_ticks_msec()
		for id in _marked.keys():
			if now - int(_marked[id]) > DEDUPE_MSEC:
				_marked.erase(id)
		_marked[t.get_instance_id()] = now
	return dmg


func hit_extra(t: Node, dmg: float, is_primary: bool, proj: Node2D) -> void:
	if proj != null or not is_enemy(t) or not can_act():
		return
	## Önce kanama, sonra can (2026-10-17): eskiden can "zaten kanıyor mu" kontrolüyle kanamadan ÖNCE veriliyordu -> yeni hedefe ilk
	## vuruş hiç can basmıyordu (kalabalıkta çoğu vuruş). Tek yük (cap 1): kanama birikmez, süresi tazelenir.
	## 2026-10-20 denge turu (BALANCE_REV 94): alan payı hedefleri kanamanın kp_area'sını alır (%30 -> %20/sn). Kanama alandaki HERKESE tam işleyince
	## (80 px'te ~7 yaratık) Pençe'nin kalabalık toplamı %31 kanamadan geliyordu ve Topuz'u geçiyordu; ana hedefin kanaması aynı.
	dot_add(t, ap() * f("kp_ap", 0.20) * (1.0 if is_primary else f("kp_area", 1.0)), f("kp_dur", 3.0), 1)
	if f("kp_leech") > 0.0 and is_primary: ## 2026-10-19: sadece ana hedef (eskiden alan payında %33 - GameManager.LIFESTEAL_EFFECTIVENESS)
		heal_owner(dmg * f("kp_leech"))


func on_event(event: String, _data: Dictionary) -> void:
	if event == "kp_kill":
		_pending_event_rewards += 1
		_pending_msec = Time.get_ticks_msec()
		_kill_bonus()


func on_dot_victim_died(rec: Dictionary) -> void:
	## Olayla zaten ödenmiş ölüm: işaretli kurban + bekleyen olay ödülü varsa bu tik yolu aynı ölümdür (sayı düşer), ikinci ödül yok.
	var now: int = Time.get_ticks_msec()
	var victim: Variant = rec.get("node")
	var vid: int = victim.get_instance_id() if is_instance_valid(victim) else 0
	if vid != 0 and _marked.has(vid):
		var marked_at: int = int(_marked[vid])
		_marked.erase(vid)
		if now - marked_at <= DEDUPE_MSEC and _pending_event_rewards > 0 and now - _pending_msec <= DEDUPE_MSEC:
			_pending_event_rewards -= 1
			return
	_kill_bonus()


func _kill_bonus() -> void:
	if not can_act():
		return
	if f("kp_kill_haste") > 0.0:
		haste(f("kp_kill_haste"), KILL_HASTE_TIME)
	if f("kp_kill_heal") > 0.0:
		heal_owner(max_hp() * f("kp_kill_heal"))
