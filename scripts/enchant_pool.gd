extends RefCounted

## EFSUN KART HAVUZU (tasarım belgesi "Kart havuzu kuralları"). Yerel oyuncunun sahip olduğu silah kopyalarından 3 kart:
##   - efsunsuz kopya -> o silahın 5 efsununun Temel kartları (yasaklananlar hariç)
##   - yolu süren kopya -> sıradaki geliştirme (I-V); V bitti + katalizör eşya envanterde -> Final
##   - tamamlanmış kopya -> Aşkın kartı (sınırsız)
## Yolu süren bir kopya varsa kartlardan en az biri onun sıradaki adımıdır. Havuz 3'ten küçükse genel Aşkın kartları,
## o da yetmezse altın kesesi doldurur. Kart = {"type", "slot", "id", "step", "tier"} (+ "gold").

## chest_menu.gd WEAPON_ICON_TEXTURES ile aynı yollar.
const WEAPON_ICONS := {
	"dagger": "res://assets/weapons/base_knife/icon_v2.png",
	"fire_staff": "res://assets/weapons/fire/firestaff_icon_v3.png",
	"lightning_staff": "res://assets/weapons/lightning/icon_v3.png",
	"tabanca": "res://assets/weapons/tabanca/icon_v2.png",
	"tuftuf": "res://assets/weapons/tuftuf/icon_v2.png",
	"tufek": "res://assets/weapons/tufek/icon.png",
	"arcane": "res://assets/weapons/arcane/icon_v3.png",
	"yay": "res://assets/weapons/yay/draw1.png",
	"crossbow": "res://assets/weapons/crossbow/icon.png",
	"boomerang": "res://assets/weapons/boomerang/icon.png",
	"buz_asasi": "res://assets/weapons/buz_asasi/icon_v3.png",
	"fisek": "res://assets/weapons/fisek/icon.png",
	"pence": "res://assets/weapons/pence/icon.png",
	"topuz": "res://assets/weapons/topuz/icon.png",
	"uzunkilic": "res://assets/weapons/uzunkilic/icon.png",
}
const GOLD_CARD_AMOUNT := 15


static func card_key(c: Dictionary) -> String:
	return "%s:%d:%s" % [str(c.get("type", "")), int(c.get("slot", -1)), str(c.get("id", ""))]


static func has_catalyst(item_key: String) -> bool:
	for entry in GameManager.owned_items:
		if str(entry.get("key", "")) == item_key:
			return true
	return false


## exclude: bu ekranda daha önce gösterilmiş kart anahtarları (karıştırınca aynı kart tekrar gelmesin; havuz yetmezse yok sayılır).
static func build(player: Node, exclude: Array = []) -> Array:
	var luck: float = float(player.get("luck")) if player and "luck" in player else 0.0
	var progress: Array = []
	var temel: Array = []
	var askin: Array = []
	for i in range(GameManager.owned_weapons.size()):
		var entry: Dictionary = GameManager.owned_weapons[i]
		var key: String = str(entry.get("key", ""))
		if not EnchantDefs.has_weapon(key):
			continue
		var ench: Dictionary = entry.get("enchant", {})
		if ench.is_empty():
			for id in EnchantDefs.BY_WEAPON[key]:
				if GameManager.enchant_banished.has("%d:%s" % [i, id]):
					continue
				temel.append({"type": "temel", "slot": i, "id": id, "step": 0})
			continue
		var id2: String = str(ench.get("id", ""))
		var taken: int = (ench.get("steps", []) as Array).size()
		if taken < EnchantDefs.FINAL_STEP:
			progress.append({"type": "step", "slot": i, "id": id2, "step": taken})
		elif taken == EnchantDefs.FINAL_STEP:
			if has_catalyst(str(EnchantDefs.get_def(id2).get("catalyst", ""))):
				progress.append({"type": "final", "slot": i, "id": id2, "step": taken})
		else:
			askin.append({"type": "askin", "slot": i, "id": id2, "step": taken})
	var picks: Array = _pick(progress, temel, askin, exclude)
	if picks.size() < 3 and not exclude.is_empty():
		## Karıştırmada havuz tükendiyse (az silah) tekrar kartlara izin ver.
		picks = _pick(progress, temel, askin, [])
	var general: Array = [{"type": "general_rp"}, {"type": "general_dmg"}]
	general.shuffle()
	while picks.size() < 3 and not general.is_empty():
		picks.append(general.pop_front())
	while picks.size() < 3:
		picks.append({"type": "gold", "gold": GOLD_CARD_AMOUNT})
	for c in picks:
		match str(c["type"]):
			"final", "gold":
				c["tier"] = 1
			_:
				c["tier"] = TierSystem.roll(luck)
	return picks


static func _pick(progress: Array, temel: Array, askin: Array, exclude: Array) -> Array:
	var p: Array = progress.filter(func(c): return not exclude.has(card_key(c)))
	var t: Array = temel.filter(func(c): return not exclude.has(card_key(c)))
	var a: Array = askin.filter(func(c): return not exclude.has(card_key(c)))
	p.shuffle()
	t.shuffle()
	a.shuffle()
	var picks: Array = []
	if not p.is_empty():
		picks.append(p.pop_front())
	var rest: Array = p + t
	rest.shuffle()
	while picks.size() < 3 and not rest.is_empty():
		picks.append(rest.pop_front())
	while picks.size() < 3 and not a.is_empty():
		picks.append(a.pop_front())
	return picks


## Kartın ekrandaki metinleri (kullanıcı geri bildirimi 2026-09-25: "efsun açıklamaları çok belirsiz"). Alanlar:
##   title      - efsun adı                      tier_line - "Nadir · II / V" (nadirlik + aşama)
##   category   - silah adı (aynı silahtan iki kopya varsa numarası)
##   lead       - efsunun ne yaptığı (tek cümle, element adıyla)
##   head/body  - "BU KART" + bu kartın verdiği şey
##   power      - efsun gücü önce -> sonra ve neyi çarptığı (Temel/I-V/Aşkın)
##   note       - Final için gereken eşya (V ve Final kartında; sende var mı)
static func describe(c: Dictionary) -> Dictionary:
	var kind: String = str(c.get("type", ""))
	var tier: int = int(c.get("tier", 1))
	var tier_pow: float = float(EnchantDefs.TIER_POWER[clampi(tier, 1, 4) - 1])
	var tier_name: String = str(TierSystem.NAMES[clampi(tier, 1, 4) - 1])
	var out: Dictionary = {"title": "", "tier_line": tier_name, "category": "", "lead": "", "head": "BU KART", "body": "",
		"power": "", "note": "", "icon": "", "color": Color("#d9d2c4"), "final": kind == "final", "banishable": kind == "temel"}
	match kind:
		"temel", "step", "final", "askin":
			var def: Dictionary = EnchantDefs.get_def(str(c.get("id", "")))
			var slot: int = int(c.get("slot", -1))
			var wkey: String = str(def.get("weapon", ""))
			var wname: String = str(EnchantDefs.WEAPON_NAMES.get(wkey, wkey))
			if _count_copies(wkey) > 1:
				wname += " (%d. kopya)" % (slot + 1)
			var element: String = str(def.get("element", "fiziksel"))
			out["icon"] = str(WEAPON_ICONS.get(wkey, ""))
			out["color"] = EnchantDefs.element_color(element)
			out["title"] = str(def.get("name", ""))
			out["category"] = wname
			out["lead"] = "%s efsunu. %s" % [EnchantDefs.element_name(element), str(def.get("desc", ""))]
			var step: int = int(c.get("step", 0))
			var steps: Array = def.get("steps", [])
			var label: String = str(def.get("power_label", "efsun etkisi"))
			var now_power: float = _current_power(slot)
			if kind == "askin":
				out["tier_line"] = "%s · Aşkın" % tier_name
				out["head"] = "AŞKIN (efsun tamamlandı)"
				out["body"] = "Bu efsunu daha da güçlendirir. Sınırsız kez alınabilir."
				out["power"] = _power_line(now_power, now_power + EnchantDefs.askin_power(tier), label)
			else:
				out["tier_line"] = "Final" if kind == "final" else "%s · %s" % [tier_name, EnchantDefs.STEP_LABELS[clampi(step, 0, 6)]]
				out["head"] = "FİNAL KARTI" if kind == "final" else ("BU KART (efsunu başlatır)" if kind == "temel" else "BU KART")
				out["body"] = str(steps[step].get("text", "")) if step < steps.size() else ""
				if kind != "final":
					out["power"] = _power_line(now_power, now_power + EnchantDefs.card_power(tier), label)
				if step >= EnchantDefs.FINAL_STEP - 1:
					var cat: String = str(def.get("catalyst", ""))
					var cat_name: String = str(Items.get_def(cat).get("name", cat))
					if kind == "final":
						out["note"] = "Gereken eşya: %s (sende var)" % cat_name
					else:
						out["note"] = "Sıradaki kart FİNAL: %s eşyası gerekir (%s)" % [cat_name, "sende var" if has_catalyst(cat) else "sende yok"]
		"general_rp":
			out["title"] = "Tepkime Gücü"
			out["category"] = "Tüm silahlar"
			out["tier_line"] = "%s · Genel Aşkın" % tier_name
			out["lead"] = "İki farklı element aynı düşmanda buluşunca tepkime olur (ör. donma + yanma = Buhar Patlaması)."
			out["body"] = "Tetiklediğin tüm tepkimelerin hasarı %%%d artar." % int(round(EnchantDefs.GENERAL_REACTION_POWER * tier_pow * 100.0))
			out["color"] = Color("#c98cff")
		"general_dmg":
			out["title"] = "Keskinlik"
			out["category"] = "Tüm silahlar"
			out["tier_line"] = "%s · Genel Aşkın" % tier_name
			out["lead"] = "Efsunu olsun olmasın bütün silahlarını etkiler."
			out["body"] = "Tüm silahlarının hasarı %%%d artar." % int(round(EnchantDefs.GENERAL_DAMAGE_PERCENT * tier_pow * 100.0))
			out["color"] = Color("#ff8a5a")
		"gold":
			out["title"] = "Altın Kesesi"
			out["category"] = "Efsun kalmadı"
			out["tier_line"] = "Altın"
			out["lead"] = "Şu an alınabilecek efsun kartı yok. Yeni bir silah ya da Final için gereken eşyayı edin."
			out["body"] = "+%d altın." % int(c.get("gold", GOLD_CARD_AMOUNT))
			out["color"] = Color("#ffd66e")
	return out


## "Efsun gücü %100 -> %110" + neyi çarptığı. Güç = 1 + alınan kartların gücü + Aşkın (EnchantDefs.resolve).
static func _power_line(before: float, after: float, label: String) -> String:
	return "Efsun gücü: %%%d → %%%d\n(%s bu oranla çarpılır)" % [int(round(before * 100.0)), int(round(after * 100.0)), label]


static func _current_power(slot: int) -> float:
	if slot < 0 or slot >= GameManager.owned_weapons.size():
		return 1.0
	var ench: Dictionary = GameManager.owned_weapons[slot].get("enchant", {})
	if ench.is_empty():
		return 1.0
	return float(EnchantDefs.resolve(ench).get("power_mult", 1.0))


## Ekranın üstündeki "sahip olduğun efsunlar" satırı: her silah kopyası için efsun adı + aşama ya da "efsunsuz".
static func owned_summary() -> String:
	var parts: Array = []
	for i in range(GameManager.owned_weapons.size()):
		var entry: Dictionary = GameManager.owned_weapons[i]
		var key: String = str(entry.get("key", ""))
		if not EnchantDefs.has_weapon(key):
			continue
		var wname: String = str(EnchantDefs.WEAPON_NAMES.get(key, key))
		var ench: Dictionary = entry.get("enchant", {})
		if ench.is_empty():
			parts.append("%s: efsunsuz" % wname)
			continue
		var def: Dictionary = EnchantDefs.get_def(str(ench.get("id", "")))
		var taken: int = (ench.get("steps", []) as Array).size()
		var stage: String = "Aşkın" if taken >= EnchantDefs.STEP_COUNT else EnchantDefs.STEP_LABELS[clampi(taken - 1, 0, 6)]
		parts.append("%s: %s (%s)" % [wname, str(def.get("name", "")), stage])
	return "   ·   ".join(parts)


static func _count_copies(key: String) -> int:
	var c: int = 0
	for e in GameManager.owned_weapons:
		if str(e.get("key", "")) == key:
			c += 1
	return c
