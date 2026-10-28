extends RefCounted

## ÖZEL LEVEL KARTLARI (madde 367, kullanıcı: "karar kartları + silah türüne bağlı kartlar ekleyelim"): her level atlamada 3 kartın
## 1'i bu havuzdan gelir (level_up_screen.gd _populate_cards), kalan 2'si eski düz stat kartlarıdır. Sebep: 13 düz kartın hepsi
## "+%X stat"ti; seçimlerin %33'ü Saldırı Gücü + Saldırı Hızı'ydı, karar yoktu. İki tür:
##  - TAKAS ("trade"): bir statı yükseltir, başka birini düşürür (Cam Top: +SG / -Can). Kazanç kademe başına +%30 (düz kartlarla AYNI
##    eğri), bedel yalnız +%15 -> üst kademe daha kârlı takas.
##  - SİLAH TÜRÜ ("class"): yalnız yakın dövüş ya da yalnız menzilli silahların hasarını artırır; oyuncuda o türden silah YOKSA çıkmaz.
## Sayılar TEK yerde (burada): kart metni (level_up_screen.gd), uygulama (player.gd apply_upgrade) ve otomatik seçim (auto_pick.gd) hep
## buradan okur - kartta yazan = uygulanan (iki-yer hatası olmasın).
## Bedel tabanları: bir stat zeminine inmişse o bedelli takas ÇIKMAZ (yoksa zemindeyken bedava kazanç olurdu, bkz. can_pay).

const GAIN_STEP := 0.3 ## kazanç: kademe başına +%30 (player.gd apply_upgrade tier_mult ile aynı)
const COST_STEP := 0.15 ## bedel: kademe başına +%15
const MIN_MAX_HEALTH := 40.0 ## takas bedeliyle azami can bunun altına inmez
const MIN_SPEED_CARD := -0.30 ## kartlardan gelen hareket hızı toplamı bunun altına inmez
const MIN_SHIELD_PERCENT := -0.5 ## kartlardan gelen mana kalkanı yüzdesi bunun altına inmez
const MAX_INTERVAL_MULT := 3.0 ## saldırı aralığı çarpanı bunun üstüne çıkmaz (saldırı hızı bedeli)
const CAT_TRADE := "Takas"
const CAT_CLASS := "Silah"

## stat anahtarı -> kartta görünen ad, yuvarlama adımı, yüzde mi
const STATS := {
	"damage": {"label": "Saldırı Gücü", "step": 1.0, "pct": false},
	"max_health": {"label": "Azami Can", "step": 1.0, "pct": false},
	"speed": {"label": "Hareket Hızı", "step": 0.005, "pct": true},
	"fire_rate": {"label": "Saldırı Hızı", "step": 0.005, "pct": true},
	"lifesteal": {"label": "Can Çalma", "step": 0.005, "pct": true},
	"shield": {"label": "Mana Kalkanı", "step": 0.005, "pct": true},
	"melee": {"label": "Yakın Dövüş Hasarı", "step": 0.005, "pct": true},
	"ranged": {"label": "Menzilli Hasar", "step": 0.005, "pct": true},
}

## id -> kart. "icon": stat_icon.gd ICON_PATHS anahtarı. "gain"/"cost": [stat, kademe-1 miktarı]. "needs": silah türü şartı.
## "table_k": düz kartın kademe tablosu ×1,3 eğrisinden DİK (Can 20/35/50/70, Can Çalma %2/4/6/8) - bu statları kazandıran takasın kazancı o TABLONUN k katıdır
## (yoksa üst kademede bedel ödeyip bedelsiz düz karttan DAHA AZ kazanılırdı: Kan Anlaşması %2/2,5/3/4 vs düz %2/4/6/8 - madde 370). "gain" tabanı yalnız kademe 1'in belgesi.
const DEFS := {
	"trade_glass": {"title": "Cam Top", "kind": "trade", "icon": "damage", "gain": ["damage", 10.0], "cost": ["max_health", 20.0]},
	"trade_bulwark": {"title": "Demir Kabuk", "kind": "trade", "icon": "max_health", "gain": ["max_health", 40.0], "table_k": 2.0, "cost": ["fire_rate", 0.08]},
	"trade_boots": {"title": "Rüzgâr Ayakları", "kind": "trade", "icon": "speed", "gain": ["speed", 0.10], "cost": ["max_health", 15.0]},
	"trade_trigger": {"title": "Çılgın Tetik", "kind": "trade", "icon": "fire_rate", "gain": ["fire_rate", 0.12], "cost": ["shield", 0.08]},
	"trade_blood": {"title": "Kan Anlaşması", "kind": "trade", "icon": "lifesteal", "gain": ["lifesteal", 0.06], "table_k": 3.0, "cost": ["speed", 0.06]},
	"trade_aegis": {"title": "Dev Kalkan", "kind": "trade", "icon": "shield_amount", "gain": ["shield", 0.18], "cost": ["speed", 0.08]},
	## Silah türü kartlarının da bedeli var (madde 379): ağır zırh yavaşlatır, nişancı camdan yapılmadır.
	"class_melee": {"title": "Yakın Dövüş Ustalığı", "kind": "class", "icon": "damage", "gain": ["melee", 0.15], "cost": ["speed", 0.05], "needs": "melee"},
	"class_ranged": {"title": "Nişancılık", "kind": "class", "icon": "range", "gain": ["ranged", 0.15], "cost": ["max_health", 12.0], "needs": "ranged"},
}
const ORDER := ["trade_glass", "trade_bulwark", "trade_boots", "trade_trigger", "trade_blood", "trade_aegis", "class_melee", "class_ranged"]

## DÜZ STAT KARTLARININ BEDELİ (madde 379, kullanıcı: "tüm level atlama kartlarına ödül ceza sistemi ekle"): level_up_screen.gd UPGRADES'teki 13 kartın
## KAZANCI olduğu gibi kaldı (player.gd apply_upgrade + kart metni), her birine BAŞKA bir statta küçük bir bedel eklendi: kazancın ~üçte biri değerinde
## (Can kartı 20 can <-> 6 can; Hız %4 <-> %2 kalkan...). Bedel kademeyle +%15 (COST_STEP, takaslarla aynı). Bedel statları zeminli olanlardır
## (azami can 40, hız kartı toplamı -%30, mana kalkanı -%50, saldırı aralığı x3): zemindeki statın bedeli ödenemeyince o kart ÇIKMAZ (can_pay).
## "id": [bedel statı, kademe-1 miktarı]. Kazanç statıyla bedel statı ASLA aynı olmaz (test).
const PLAIN_COSTS := {
	"speed": ["shield", 0.02],
	"max_health": ["speed", 0.015],
	"damage": ["fire_rate", 0.02],
	"fire_rate": ["max_health", 6.0],
	"health_regen": ["fire_rate", 0.02],
	"crit_chance": ["max_health", 6.0],
	"crit_damage": ["shield", 0.02],
	"exp_gain": ["speed", 0.015],
	"luck": ["max_health", 5.0],
	"dodge": ["fire_rate", 0.02],
	"shield_amount": ["speed", 0.015],
	"cooldown_reduction": ["shield", 0.02],
	"lifesteal": ["speed", 0.015],
	"shield_regen": ["speed", 0.015], ## madde 380
	"heal_power": ["fire_rate", 0.02], ## madde 380
}


static func is_special(id: String) -> bool:
	return DEFS.has(id)


static func is_trade(id: String) -> bool:
	return str((DEFS.get(id, {}) as Dictionary).get("kind", "")) == "trade"


## Düz stat kartı mı (PLAIN_COSTS'ta bedeli tanımlı)?
static func is_plain(id: String) -> bool:
	return PLAIN_COSTS.has(id)


## Bu kart bir bedel öder mi (takas, silah türü ya da düz kart)?
static func has_cost(id: String) -> bool:
	return cost_stat(id) != ""


## Bedel kaydı [stat, kademe-1 miktarı]: önce özel kartlar, sonra düz kartlar; yoksa boş.
static func _cost_entry(id: String) -> Array:
	if DEFS.has(id):
		return (DEFS[id] as Dictionary).get("cost", [])
	return PLAIN_COSTS.get(id, [])


static func def(id: String) -> Dictionary:
	return DEFS.get(id, {})


static func stat_label(stat: String) -> String:
	return str((STATS.get(stat, {}) as Dictionary).get("label", stat))


static func _round_to(stat: String, value: float) -> float:
	return snappedf(value, float((STATS.get(stat, {}) as Dictionary).get("step", 0.005)))


## Kademeye göre KAZANÇ miktarı (kartta yazan = uygulanan; yuvarlanmış).
static func gain_value(id: String, tier: int) -> float:
	var d: Dictionary = DEFS.get(id, {})
	var g: Array = d.get("gain", [])
	if g.size() < 2:
		return 0.0
	var k: float = float(d.get("table_k", 0.0))
	if k > 0.0:
		var table_base: float = TierSystem.health_card_for_tier(tier) if str(g[0]) == "max_health" else TierSystem.lifesteal_percent_for_tier(tier)
		return _round_to(str(g[0]), table_base * k)
	return _round_to(str(g[0]), float(g[1]) * (1.0 + float(maxi(tier, 1) - 1) * GAIN_STEP))


## Kademeye göre BEDEL miktarı (takas, silah türü ve düz kartlarda; yoksa 0).
static func cost_value(id: String, tier: int) -> float:
	var c: Array = _cost_entry(id)
	if c.size() < 2:
		return 0.0
	return _round_to(str(c[0]), float(c[1]) * (1.0 + float(maxi(tier, 1) - 1) * COST_STEP))


static func gain_stat(id: String) -> String:
	var g: Array = (DEFS.get(id, {}) as Dictionary).get("gain", [])
	if g.size() >= 2:
		return str(g[0])
	return plain_gain_stat(id)


## Düz kartın kazandırdığı stat (STATS anahtarı); düz kart değilse boş. Kazancın KENDİSİ player.gd apply_upgrade'te.
static func plain_gain_stat(id: String) -> String:
	match id:
		"speed", "max_health", "damage", "fire_rate", "lifesteal":
			return id
		"shield_amount":
			return "shield"
	return ""


static func cost_stat(id: String) -> String:
	var c: Array = _cost_entry(id)
	return str(c[0]) if c.size() >= 2 else ""


## "13" ya da "%15" (işaret yok).
static func format_amount(stat: String, value: float) -> String:
	if bool((STATS.get(stat, {}) as Dictionary).get("pct", false)):
		var p: float = value * 100.0
		return "%%%s" % (str(int(round(p))) if is_equal_approx(p, round(p)) else "%.1f" % p)
	return str(int(round(value)))


## Büyük değer: "+13" / "+%12".
static func gain_text(id: String, tier: int) -> String:
	return "+" + format_amount(gain_stat(id), gain_value(id, tier))


## Bedel satırı: "-20 Azami Can" (yoksa boş).
static func cost_text(id: String, tier: int) -> String:
	var s: String = cost_stat(id)
	if s == "":
		return ""
	return "-%s %s" % [format_amount(s, cost_value(id, tier)), stat_label(s)]


## Kartın alt satırı: her kartta BEDEL (takas, silah türü ve düz kartlar); bedeli olmayan kart (havuzda yok) boş döner.
static func verb_text(id: String, tier: int) -> String:
	return cost_text(id, tier)


## Silah türü kartının kısıtı ("yalnız yakın dövüş"); başka kartlarda boş. Satırın orta kısmında (kategori yanında) gösterilir.
static func restriction_text(id: String) -> String:
	match str((DEFS.get(id, {}) as Dictionary).get("needs", "")):
		"melee":
			return "yalnız yakın dövüş"
		"ranged":
			return "yalnız menzilli"
	return ""


## level_up_screen.gd'nin UPGRADES girdisiyle aynı şekilli kart sözlüğü (+ "special": true, "icon").
static func as_card(id: String) -> Dictionary:
	var d: Dictionary = def(id)
	if d.is_empty():
		return {}
	return {"id": id, "title": str(d["title"]), "desc": "", "cat": CAT_TRADE if str(d["kind"]) == "trade" else CAT_CLASS,
		"icon": str(d["icon"]), "special": true, "kind": str(d["kind"]),
		## Alt satırda kazanılan statın adı (takas) ya da silah türü kısıtı (başlık "Yakın Dövüş" diyor ama "yalnız" şartı burada yazar).
		"gain_label": stat_label(gain_stat(id)) if str(d["kind"]) == "trade" else restriction_text(id)}


## Oyuncudaki silahlar: {"melee": adet, "ranged": adet}.
static func weapon_classes(player: Node) -> Dictionary:
	var out := {"melee": 0, "ranged": 0}
	if player == null or not is_instance_valid(player) or not ("owned_weapon_nodes" in player):
		return out
	for w in (player.get("owned_weapon_nodes") as Array):
		if not is_instance_valid(w):
			continue
		if bool(w.get("melee")):
			out["melee"] += 1
		else:
			out["ranged"] += 1
	return out


## Bu oyuncu bedeli ÖDEYEBİLİR mi (en düşük kademe bedeline göre)? Zemindeki statı daha da düşüremeyen oyuncuya bedelli kart (takas, silah
## türü ya da düz kart) çıkmaz.
static func can_pay(id: String, player: Node) -> bool:
	if not has_cost(id):
		return true
	if player == null or not is_instance_valid(player):
		return true
	var stat: String = cost_stat(id)
	var amount: float = cost_value(id, 1)
	match stat:
		"max_health":
			return _num(player, "max_health", 100.0) - amount >= MIN_MAX_HEALTH
		"speed":
			return _num(player, "speed_card_percent", 0.0) - amount >= MIN_SPEED_CARD
		"shield":
			return _num(player, "shield_max_percent", 0.0) - amount >= MIN_SHIELD_PERCENT
		"fire_rate":
			return _num(player, "fire_rate_mult", 1.0) / maxf(0.2, 1.0 - amount) <= MAX_INTERVAL_MULT
	return true


## Alanı olmayan sahte oyuncu (testler) için güvenli okuma.
static func _num(player: Node, prop: String, fallback: float) -> float:
	var v: Variant = player.get(prop)
	return float(v) if v != null else fallback


## Bu oyuncuya çıkabilecek özel kart kimlikleri (silah türü şartı + bedel ödenebilirliği).
static func available_ids(player: Node) -> Array:
	var cls: Dictionary = weapon_classes(player)
	var out: Array = []
	for id: String in ORDER:
		var need: String = str((DEFS[id] as Dictionary).get("needs", ""))
		if need != "" and int(cls.get(need, 0)) <= 0:
			continue
		if not can_pay(id, player):
			continue
		out.append(id)
	return out


## auto_pick.gd taban değeri (düz kartlarla aynı ölçek: Saldırı Gücü 1,0).
static func auto_value(id: String) -> float:
	return 0.85 if str((DEFS.get(id, {}) as Dictionary).get("kind", "")) == "class" else 0.7
