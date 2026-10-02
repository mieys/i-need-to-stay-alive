extends RefCounted

## EFSUN KART HAVUZU. Yerel oyuncunun sahip olduğu silah kopyalarından 3 kart (2026-09-30 yeni efsun seti kuralları -
## bkz. enchant_defs.gd dosya başı):
##   - efsunsuz kopya -> o silaha uyan efsunların Temel kartları (yasaklananlar hariç)
##   - yolu süren kopya -> alınmamış geliştirmelerinden RASTGELE biri (sıra yok); hepsi alındı + katalizör eşya envanterde
##     -> Final. Tamamlanmış kopya için kart YOK (Aşkın kaldırıldı).
## Yolu süren bir kopya varsa kartlardan en az biri onun kartıdır. Havuz 3'ten küçükse genel kartlar (Tepkime Gücü /
## Keskinlik), o da yetmezse altın kesesi doldurur. Kart = {"type", "slot", "id", "up", "tier"} (+ "gold").
## Nadirlik YOK: efsun kartları hep mor (EnchantDefs.CARD_TIER), Final kırmızı (FINAL_CARD_TIER).
## Kalkan efsunları (2026-09-29, bkz. shield_enchant_defs.gd): "shield_pick" / "shield_up" kartları Temel kartlarla AYNI
## torbaya girer. Değerleri sabittir, hep Epik (mor) görünür.

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


## exclude: bu ekranda daha önce gösterilmiş kart anahtarları (karıştırınca aynı kart tekrar gelmesin; havuz yetmezse yok sayılır).
static func build(_player: Node, exclude: Array = []) -> Array:
	var progress: Array = []
	var temel: Array = []
	for i in range(GameManager.owned_weapons.size()):
		var entry: Dictionary = GameManager.owned_weapons[i]
		var key: String = str(entry.get("key", ""))
		if not EnchantDefs.has_weapon(key):
			continue
		var ench: Dictionary = entry.get("enchant", {})
		if ench.is_empty():
			for id in EnchantDefs.enchants_for(key):
				if GameManager.enchant_banished.has("%d:%s" % [i, id]):
					continue
				temel.append({"type": "temel", "slot": i, "id": id})
			continue
		var id2: String = str(ench.get("id", ""))
		if EnchantDefs.is_complete(ench):
			continue
		var def: Dictionary = EnchantDefs.get_def(id2)
		if def.is_empty():
			continue
		var taken: Array = EnchantDefs.upgrades_taken(ench)
		var left: Array = []
		for u in range((def["upgrades"] as Array).size()):
			if not taken.has(u):
				left.append(u)
		if not left.is_empty():
			progress.append({"type": "step", "slot": i, "id": id2, "up": left[randi() % left.size()]})
		else:
			## Tüm geliştirmeler alındı -> Final (2026-10-02: katalizör eşya şartı ekstralarla birlikte kaldırıldı).
			progress.append({"type": "final", "slot": i, "id": id2})
	temel.append_array(ShieldEnchantDefs.pool_cards())
	var picks: Array = _pick(progress, temel, exclude)
	if picks.size() < 3 and not exclude.is_empty():
		## Karıştırmada havuz tükendiyse (az silah) tekrar kartlara izin ver.
		picks = _pick(progress, temel, [])
	var general: Array = [{"type": "general_rp"}, {"type": "general_dmg"}]
	general.shuffle()
	while picks.size() < 3 and not general.is_empty():
		picks.append(general.pop_front())
	while picks.size() < 3:
		picks.append({"type": "gold", "gold": GOLD_CARD_AMOUNT})
	for c in picks:
		match str(c["type"]):
			"final":
				c["tier"] = EnchantDefs.FINAL_CARD_TIER
			"gold":
				c["tier"] = 1
			"shield_pick", "shield_up":
				c["tier"] = ShieldEnchantDefs.CARD_TIER
			_:
				c["tier"] = EnchantDefs.CARD_TIER
	return picks


static func _pick(progress: Array, temel: Array, exclude: Array) -> Array:
	var p: Array = progress.filter(func(c): return not exclude.has(card_key(c)))
	var t: Array = temel.filter(func(c): return not exclude.has(card_key(c)))
	p.shuffle()
	t.shuffle()
	var picks: Array = []
	if not p.is_empty():
		picks.append(p.pop_front())
	var rest: Array = p + t
	rest.shuffle()
	while picks.size() < 3 and not rest.is_empty():
		picks.append(rest.pop_front())
	return picks


## Kartın ekrandaki metinleri. Alanlar:
##   title      - efsun adı                      tier_line - "Temel" / "Geliştirme 2 / 4" / "Final"
##   category   - silah adı (aynı silahtan iki kopya varsa numarası)
##   lead       - efsunun ne yaptığı (tek cümle, element adıyla)
##   head/body  - kartın başlığı (geliştirmenin adı) + bu kartın verdiği şey
##   note       - Final için gereken eşya (son geliştirmede ve Final kartında; sende var mı)
static func describe(c: Dictionary) -> Dictionary:
	var kind: String = str(c.get("type", ""))
	var out: Dictionary = {"title": "", "tier_line": "", "category": "", "lead": "", "head": "BU KART", "body": "",
		"power": "", "note": "", "icon": "", "color": Color("#d9d2c4"), "final": kind == "final", "banishable": kind == "temel"}
	match kind:
		"temel", "step", "final":
			var id: String = str(c.get("id", ""))
			var def: Dictionary = EnchantDefs.get_def(id)
			var slot: int = int(c.get("slot", -1))
			var wkey: String = _slot_weapon(slot)
			var wname: String = str(EnchantDefs.WEAPON_NAMES.get(wkey, wkey))
			if _count_copies(wkey) > 1:
				wname += " (%d. kopya)" % (slot + 1)
			var element: String = EnchantDefs.element_of(id, wkey)
			out["icon"] = str(WEAPON_ICONS.get(wkey, ""))
			out["color"] = EnchantDefs.element_color(element)
			out["title"] = str(def.get("name", ""))
			out["category"] = wname
			out["lead"] = "%s efsunu. %s" % [EnchantDefs.element_name(element), str(def.get("desc", ""))]
			var ups: Array = def.get("upgrades", [])
			var taken: int = _taken_count(slot)
			match kind:
				"temel":
					out["tier_line"] = "Temel"
					out["head"] = "BU KART (efsunu başlatır)"
					out["body"] = str((def.get("base", {}) as Dictionary).get("text", ""))
				"step":
					var u: int = int(c.get("up", 0))
					var up: Dictionary = ups[u] if u >= 0 and u < ups.size() else {}
					out["tier_line"] = "Geliştirme %d / %d" % [taken + 1, ups.size()]
					out["head"] = str(up.get("name", "GELİŞTİRME")).to_upper()
					out["body"] = str(up.get("text", ""))
				"final":
					var fin: Dictionary = def.get("final", {})
					out["tier_line"] = "Final"
					out["head"] = "FİNAL: %s" % str(fin.get("name", "")).to_upper()
					out["body"] = str(fin.get("text", ""))
		"general_rp":
			out["title"] = "Tepkime Gücü"
			out["category"] = "Tüm silahlar"
			out["tier_line"] = "Genel"
			out["lead"] = "İki farklı element aynı düşmanda buluşunca tepkime olur (ör. donma + yanma = Buhar Patlaması)."
			out["body"] = "Tetiklediğin tüm tepkimelerin hasarı %%%d artar." % int(round(EnchantDefs.GENERAL_REACTION_POWER * 100.0))
			out["color"] = Color("#c98cff")
		"general_dmg":
			out["title"] = "Keskinlik"
			out["category"] = "Tüm silahlar"
			out["tier_line"] = "Genel"
			out["lead"] = "Efsunu olsun olmasın bütün silahlarını etkiler."
			out["body"] = "Tüm silahlarının hasarı %%%d artar." % int(round(EnchantDefs.GENERAL_DAMAGE_PERCENT * 100.0))
			out["color"] = Color("#ff8a5a")
		"shield_pick", "shield_up":
			ShieldEnchantDefs.describe(c, out)
		"gold":
			out["title"] = "Altın Kesesi"
			out["category"] = "Efsun kalmadı"
			out["tier_line"] = "Altın"
			out["lead"] = "Şu an alınabilecek efsun kartı yok. Yeni bir silah ya da Final için gereken eşyayı edin."
			out["body"] = "+%d altın." % int(c.get("gold", GOLD_CARD_AMOUNT))
			out["color"] = Color("#ffd66e")
	return out


static func _slot_weapon(slot: int) -> String:
	if slot < 0 or slot >= GameManager.owned_weapons.size():
		return ""
	return str(GameManager.owned_weapons[slot].get("key", ""))


static func _taken_count(slot: int) -> int:
	if slot < 0 or slot >= GameManager.owned_weapons.size():
		return 0
	return (EnchantDefs.upgrades_taken(GameManager.owned_weapons[slot].get("enchant", {})) as Array).size()


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
		var stage: String = "Final" if EnchantDefs.is_complete(ench) else "%d / %d" % [
			(EnchantDefs.upgrades_taken(ench) as Array).size(), (def.get("upgrades", []) as Array).size()]
		parts.append("%s: %s (%s)" % [wname, str(def.get("name", "")), stage])
	var shield_line: String = ShieldEnchantDefs.summary()
	if shield_line != "":
		parts.append(shield_line)
	return "   ·   ".join(parts)


static func _count_copies(key: String) -> int:
	var c: int = 0
	for e in GameManager.owned_weapons:
		if str(e.get("key", "")) == key:
			c += 1
	return c
