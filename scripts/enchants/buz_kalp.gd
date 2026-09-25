extends "res://scripts/enchant_behavior.gd"

## Donmuş Kalp (EnchantDefs "buz_kalp"): asanın vuruşu donmuş + canı eşiğin altındaki düşmanı paramparça eder (host,
## enemy.gd "shatter" - donma durumunu host kendisi kontrol eder, istemci görsel durumuna güvenilmez). Kıymık / çevre
## dondurma parametreleri de orada. Final (Şanslı Zar) Buz Tahtı: paramparça başına (host -> "shatter" olayı) %10
## (şansla artar) ihtimalle 3 sn tüm silahlara +%20 saldırı hızı (player.enchant_haste).


func hit_extra(t: Node, _dmg: float, is_primary: bool, _proj: Node2D) -> void:
	if not is_primary or not is_enemy(t) or t.get("is_boss") == true:
		return
	## İstemcide "donmuş" görseli gelmişse ya da tek oyunculuda donmuşsa gönder (gereksiz RPC olmasın).
	if not status(t, "frozen"):
		return
	t.apply_element("shatter", elem({"th": f("shatter_th", 0.15), "shards": n("shatter_shards"),
		"freeze_aoe": f("shatter_freeze_aoe"), "throne": flag("ice_throne")}))


func on_event(event: String, _data: Dictionary) -> void:
	if event != "shatter" or not flag("ice_throne"):
		return
	if randf() < 0.10 * (1.0 + 0.05 * luck()):
		var p: Node = owner_player()
		if p and p.has_method("enchant_haste"):
			p.enchant_haste(0.2, 3.0)
			fx("text", p.global_position, {"text": "Buz Tahtı", "color": Color(0.75, 0.9, 1.0)})
