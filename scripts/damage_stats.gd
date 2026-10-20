extends RefCounted

## SİLAH VE YETENEK HASAR İSTATİSTİĞİ (kullanıcı isteği 2026-10-17: "demircide ve oyun sonunda hangi silahın ne kadar hasar
## verdiğini görebilelim; yetenekler için de aynı - sadece oyun sonunda veya Shift'e basılı tutarak yeteneğe basınca,
## hasarı/canı/kalkanı göstersin").
##
## VERİ KAYNAĞI: yeni bir sayaç yok - balans telemetrisi (balance_log.gd, madde 75/91) zaten her isabeti kaynağıyla toplar:
## `_dealt` = kaynak -> [hasar, isabet, kritik] ("w:<silah anahtarı>" silah, "s:..." yetenek/pasif/evcil/eşya, "dot:..." süregelen,
## "diger" etiketsiz). Yeteneğin bastığı can/kalkan için `_gain` eklendi (BalanceLog.on_gain; player.gd heal/heal_shield/
## _apply_*_to_ally `src` parametresi). Bu sınıf sadece o ham veriyi ekranlara uygun satırlara çevirir.
## Sayaçlar YEREL oyuncunun makinesindedir (arkadaşın hasarı yok); koşu başında main.gd BalanceLog.reset() ile sıfırlanır.
##
## Yeni bir yetenek hasarı/iyileştirmesi eklerken: take_damage'den önce BalanceLog.tag(&"s:<anahtar>") (zaten zorunlu) ve
## BURADAKİ SLOT tablosuna anahtarı ekle - tabloda olmayan "s:" kaynağı ekranda "Diğer" satırına düşer.

const BalanceLogScript := preload("res://scripts/balance_log.gd")
const WeaponCatalogScript := preload("res://scripts/weapon_catalog.gd")
const SpiritualSkillsScript := preload("res://scripts/spiritual_skills.gd")

## Slotlar: q / e / r = yetenek tuşları, p = pasif, f = ruhani yetenek (4. yuva), diger = evcil/eşya/evrim/süregelen/etiketsiz.
const SLOT_Q := "q"
const SLOT_E := "e"
const SLOT_R := "r"
const SLOT_P := "p"
const SLOT_F := "f"
const SLOT_OTHER := "diger"
const SLOT_ORDER := ["q", "e", "r", "p", "f"]

## kaynak etiketi -> slot. Ayrıntı satırı adları NAMES'te.
const SLOT := {
	## Talon
	"s:talon_dash": "q", "s:talon_spin": "e", "s:talon_ayna": "r", "s:talon_pasif": "p",
	## Oakley
	"dot:ari_zehri": "q", "s:oakley_sarmasik": "e", "s:oakley_agac": "r", "s:oakley_cicek": "p",
	## Matthew
	"s:matthew_tilki_hucumu": "q", "s:matthew_simsek_hucumu": "q", "s:matthew_elektrik_topu": "e", "s:matthew_kubbe": "r",
	"s:matthew_yildirim_izi": "p", ## "s:matthew_kopek" artık herkesin EVCİL köpeği (madde 98/103) -> "diger" + PET_SOURCES
	## Büyücü Kız (Q = set değiştirir; E = Arcane Lanet / Hortum; R = Don Nova / Meteor)
	"s:buyucu_sekme": "e", "s:buyucu_arcane_patlama": "e", "s:buyucu_kasirga": "e", "s:buyucu_buz_nova": "r", "s:buyucu_meteor": "r",
	"s:buyucu_degisim": "q", "s:buyucu_pasif": "p",
	## Assasin
	"s:assasin_dash2": "q", "s:assasin_gorunmez": "e", "s:assasin_dash": "r", "s:assasin_pasif": "p",
	## Şovalye
	"s:sovalye_kiskirtma": "q", "s:sovalye_yansitma": "e", "s:sovalye_misilleme": "r",
	"s:sovalye_bariyer": "e", "s:sovalye_kubbe": "r", "s:sovalye_pasif": "p",
	## Elara
	"s:elara_sivisma": "q", "s:elara_gercek_hasar": "e", "s:elara_cift_tetik": "r",
	## Korsan
	"s:korsan_patlat": "q", "s:korsan_bomba": "e", "s:korsan_bombardiman": "r", "s:korsan_pasif": "p",
	## Melek (hasarı yok; can/kalkan)
	"s:melek_can": "q", "s:melek_kalkan": "e", "s:melek_korku": "r", "s:melek_pasif": "p",
	## Necromancer
	"s:necro_iskelet": "q", "s:necro_golem": "e", "s:necro_kafatasi": "r", "s:necro_kemik": "q", "s:necro_ruh": "p",
	## Shaman
	"s:shaman_totem": "q", "s:shaman_totem_alan": "q", "s:shaman_kalkan_totemi": "e", "s:shaman_kalkan_alan": "e", "s:shaman_golem_alan": "r",
	## Vampir
	"s:vampir_kan_emme": "q", "s:vampir_yarasa_temas": "e", "s:vampir_yarasa_r": "r", "s:vampir_r_patlama": "r", "s:vampir_pasif": "p",
	## Suriyeli Hadime
	"s:hadime_lanet": "q", "s:hadime_lanet_patlama": "q", "s:hadime_kuyu": "e", "s:hadime_kabus": "r",
	## Cadı
	"s:cadi_duman": "q", "s:cadi_supurge_temas": "e", "s:cadi_supurge": "e", "s:cadi_patlama": "r", "s:cadi_don": "r", "s:cadi_korku": "r",
	"s:cadi_iksir": "r", "s:cadi_kalkan": "r",
	## Ruhani yetenekler (4. yuva)
	"s:ruhani_tank": "f", "s:ruhani_can": "f", "s:ruhani_kalkan_bagi": "f",
}

## Ayrıntı satırlarında görünen kısa ad (slotun kendi adı zaten başlıkta; birden çok kaynak varsa hangisi ne kadar).
const NAMES := {
	"s:talon_dash": "Atılış", "s:talon_spin": "Dönen silahlar", "s:talon_ayna": "Ayna formu", "s:talon_pasif": "Güç yükleri",
	"dot:ari_zehri": "Arı zehri", "s:oakley_sarmasik": "Sarmaşık",
	"s:matthew_tilki_hucumu": "Tilki hücumu", "s:matthew_simsek_hucumu": "Şimşek", "s:matthew_elektrik_topu": "Elektrik topu",
	"s:matthew_kubbe": "Kalkan patlaması", "s:matthew_kopek": "Köpek", "s:matthew_yildirim_izi": "Yıldırım izi",
	"s:kelebek_ruhu": "Kelebek lazeri", "s:evcil_kirpi": "Kirpi dikenleri", "s:evcil_peri": "Peri",
	"s:buyucu_sekme": "Sekme", "s:buyucu_arcane_patlama": "Arcane patlama", "s:buyucu_kasirga": "Hortum", "s:buyucu_buz_nova": "Don Nova",
	"s:buyucu_meteor": "Meteor", "s:buyucu_degisim": "Set değişimi",
	"s:assasin_dash2": "Şahin hamlesi", "s:assasin_gorunmez": "Gölge adımı", "s:assasin_dash": "Gölge hücumu", "s:assasin_pasif": "Bıçak uzmanlığı",
	"s:sovalye_kiskirtma": "Kışkırtma", "s:sovalye_yansitma": "Yansıtma", "s:sovalye_misilleme": "Misilleme",
	"s:sovalye_bariyer": "Koruma bariyeri", "s:sovalye_kubbe": "Koruma baloncuğu", "s:sovalye_pasif": "Dirençli duruş", "s:oakley_agac": "Hayat ağacı", "s:oakley_cicek": "Çiçek",
	"s:elara_sivisma": "Sıvışma", "s:elara_gercek_hasar": "Gerçek hasar", "s:elara_cift_tetik": "Çift tetik",
	"s:korsan_bomba": "Bomba", "s:korsan_bombardiman": "Bombardıman",
	"s:melek_can": "Can basma", "s:melek_kalkan": "Kalkan yenileme", "s:melek_korku": "Kutsal korku", "s:melek_pasif": "Pasif",
	"s:necro_iskelet": "İskelet", "s:necro_golem": "Golem", "s:necro_kafatasi": "Kafatası", "s:necro_kemik": "Kemik fedası",
	"s:shaman_totem": "Totem atışı", "s:shaman_totem_alan": "Totem alanı", "s:shaman_kalkan_totemi": "Kalkan totemi", "s:shaman_kalkan_alan": "Totem alanı", "s:shaman_golem_alan": "Golem alanı",
	"s:vampir_kan_emme": "Kan emme", "s:vampir_yarasa_temas": "Yarasa teması", "s:vampir_yarasa_r": "Yarasalar", "s:vampir_r_patlama": "Patlama", "s:vampir_pasif": "Can emme",
	"s:hadime_lanet": "Lanet", "s:hadime_lanet_patlama": "Lanet patlaması", "s:hadime_kuyu": "Kara delik", "s:hadime_kabus": "Karabasan",
	"s:cadi_duman": "Zehirli duman", "s:cadi_supurge_temas": "Süpürge teması", "s:cadi_supurge": "Süpürge", "s:cadi_patlama": "İksir patlaması",
	"s:cadi_don": "Don iksiri", "s:cadi_korku": "Korku iksiri", "s:cadi_iksir": "İksir", "s:cadi_kalkan": "Kalkan iksiri",
	"s:ruhani_tank": "Tank", "s:ruhani_can": "Can", "s:ruhani_kalkan_bagi": "Kalkan bağı",
}


## "w:" kaynağı mı (silah)?
static func is_weapon(src: String) -> bool:
	return src.begins_with("w:")


## Kaynağın slotu: SLOT tablosu, yoksa "diger".
static func slot_of(src: String) -> String:
	return str(SLOT.get(src, SLOT_OTHER))


static func weapon_name(key: String) -> String:
	if key == "efsun":
		return "Silah özellikleri"
	return str(WeaponCatalogScript.NAMES.get(key, key.capitalize()))


static func source_name(src: String) -> String:
	if NAMES.has(src):
		return str(NAMES[src])
	if src.begins_with("s:evo_"):
		return "Evrim"
	if src.begins_with("dot:"):
		return {"dot:yanma": "Yanma", "dot:zehir": "Zehir", "dot:kanama": "Kanama"}.get(src, "Süregelen hasar")
	if src.begins_with("s:evcil") or src == "s:kelebek_ruhu" or src == "s:korsan_papagan_firtinasi":
		return "Evcil hayvan"
	if src == "s:esya_diken":
		return "Eşya"
	if src == "diger":
		return "Etiketsiz"
	return src.trim_prefix("s:").replace("_", " ").capitalize()


## Sahip olunan (ya da satılmış) her silahın verdiği hasar, çoktan aza. Satır: {key, name, dmg, hits, crit, share}.
## share = o silahın tüm hasar (silah + yetenek + diğer) içindeki payı (0-1).
static func weapon_rows(dealt: Dictionary = {}) -> Array:
	if dealt.is_empty():
		dealt = BalanceLogScript.dealt_snapshot()
	var total: float = total_damage(dealt)
	var rows: Array = []
	for src in dealt.keys():
		var s: String = str(src)
		if not is_weapon(s):
			continue
		var r: Array = dealt[src]
		rows.append({"key": s.trim_prefix("w:"), "name": weapon_name(s.trim_prefix("w:")), "dmg": float(r[0]), "hits": int(r[1]),
				"crit": int(r[2]), "share": float(r[0]) / maxf(total, 1.0), "tier": weapon_tier(s.trim_prefix("w:"))})
	rows.sort_custom(func(a, b): return float(a["dmg"]) > float(b["dmg"]))
	return rows


## Elde olan silahın seviyesi (demirci geliştirmesi: 1 = temel ... 5 = final, kontür rengi sırası; weapon_shop_screen _slot_tier ile AYNI kural).
## Satılmış / hiç alınmamış silah için 0 (seviye gösterilmez).
static func weapon_tier(key: String) -> int:
	for e in GameManager.owned_weapons:
		if e is Dictionary and str((e as Dictionary).get("key", "")) == key:
			var ench: Dictionary = (e as Dictionary).get("enchant", {})
			if ench.is_empty():
				return 1
			if bool(ench.get("final", false)):
				return 5
			return mini(4, 1 + (ench.get("ups", []) as Array).size())
	return 0


## Tek silahın verdiği hasar (satın alma ekranı kartı için). Yoksa 0.
static func weapon_damage(key: String) -> Dictionary:
	var dealt: Dictionary = BalanceLogScript.dealt_snapshot()
	var r: Array = dealt.get("w:" + key, [0.0, 0, 0])
	return {"dmg": float(r[0]), "hits": int(r[1]), "crit": int(r[2]), "share": float(r[0]) / maxf(total_damage(dealt), 1.0)}


static func total_damage(dealt: Dictionary = {}) -> float:
	if dealt.is_empty():
		dealt = BalanceLogScript.dealt_snapshot()
	var t: float = 0.0
	for src in dealt:
		t += float((dealt[src] as Array)[0])
	return t


## Bir slotun toplamı: {dmg, hits, crit, heal, shield, parts: [{name, dmg, heal, shield}] (çoktan aza)}.
## slot "diger" ise slotu tabloda olmayan her şey (evcil/eşya/evrim/süregelen/etiketsiz + silah özelliği) buraya girer; silahlar HARİÇ.
static func slot_totals(slot: String, dealt: Dictionary = {}, gain: Dictionary = {}) -> Dictionary:
	if dealt.is_empty():
		dealt = BalanceLogScript.dealt_snapshot()
	if gain.is_empty():
		gain = BalanceLogScript.gain_snapshot()
	var out: Dictionary = {"dmg": 0.0, "hits": 0, "crit": 0, "heal": 0.0, "shield": 0.0}
	var parts: Dictionary = {}
	for src in dealt.keys():
		var s: String = str(src)
		if is_weapon(s) or slot_of(s) != slot:
			continue
		var r: Array = dealt[src]
		out["dmg"] += float(r[0])
		out["hits"] += int(r[1])
		out["crit"] += int(r[2])
		var nm: String = source_name(s)
		var part: Dictionary = parts.get(nm, {"name": nm, "dmg": 0.0, "heal": 0.0, "shield": 0.0})
		part["dmg"] += float(r[0])
		parts[nm] = part
	for src in gain.keys():
		var s2: String = str(src)
		if slot_of(s2) != slot:
			continue
		var g: Array = gain[src]
		out["heal"] += float(g[0])
		out["shield"] += float(g[1])
		var nm2: String = source_name(s2)
		var part2: Dictionary = parts.get(nm2, {"name": nm2, "dmg": 0.0, "heal": 0.0, "shield": 0.0})
		part2["heal"] += float(g[0])
		part2["shield"] += float(g[1])
		parts[nm2] = part2
	var list: Array = parts.values()
	list.sort_custom(func(a, b): return float(a["dmg"]) + float(a["heal"]) + float(a["shield"]) > float(b["dmg"]) + float(b["heal"]) + float(b["shield"]))
	out["parts"] = list
	## Hasar/can/kalkan dışı fayda: engellenen hasar (BalanceLog._prevented) + ölçüler (BalanceLog._util, UTIL_LABELS).
	var prev: Dictionary = BalanceLogScript.prevented_snapshot()
	out["prevented"] = 0.0
	for src3 in prev.keys():
		if slot_of(str(src3)) == slot:
			out["prevented"] += float(prev[src3])
	var util_out: Dictionary = {}
	var util: Dictionary = BalanceLogScript.util_snapshot()
	for src4 in util.keys():
		if slot_of(str(src4)) != slot:
			continue
		var row: Dictionary = util[src4]
		for m in row.keys():
			util_out[m] = float(util_out.get(m, 0.0)) + float(row[m])
	out["util"] = util_out
	return out


## Yeteneğin hasar/can/kalkan dışı fayda ölçüleri (BalanceLog.on_util / on_cc / set_window) -> ipucundaki satır adı (sıra = ipucu sırası).
## Kontrol türleri (root/slow/fear/freeze/stun/mad) yaratık başına uygulama sayısıdır (süre dolmadan tazelenen sayılmaz).
const UTIL_LABELS := {
	"ally": "Dostlardan üstlenilen hasar",
	"during_w": "Etki sürerken silah hasarı",
	"during": "Etki sürerken verilen hasar",
	"root": "Sabitlenen yaratık", "slow": "Yavaşlatılan yaratık", "fear": "Korkutulan yaratık", "freeze": "Dondurulan yaratık",
	"stun": "Sersemletilen yaratık", "mad": "Çıldırtılan yaratık",
	"surge": "Güçlendirilmiş atış", "bombs": "Patlatılan bomba", "gold": "Kazanılan altın", "souls": "Toplanan ruh",
	"summon": "Çağrılan", "passenger": "Süpürgeye binen arkadaş", "flower": "Alınan çiçek",
}
## Hasar türü ölçüler (hasar renginde yazılır); gerisi sayı/fayda (kalkan renginde).
const UTIL_DAMAGE := ["during_w", "during"]


## Oyun sonu tablosu için yetenek satırları: Q/E/R/pasif/ruhani + "Diğer"; yalnız bir şey yapmış olanlar.
## Satır: {slot, label (tuş), name (yetenek adı), dmg, heal, shield, crit_pct, share}.
static func skill_rows(char_id: int, dealt: Dictionary = {}, gain: Dictionary = {}) -> Array:
	if dealt.is_empty():
		dealt = BalanceLogScript.dealt_snapshot()
	if gain.is_empty():
		gain = BalanceLogScript.gain_snapshot()
	var total: float = total_damage(dealt)
	var def: Dictionary = Characters.get_def(char_id)
	var names := {"q": str(def.get("skill_name", "")), "e": str(def.get("skill2_name", "")), "r": str(def.get("skill3_name", "")),
			"p": str(def.get("passive_name", "Pasif")), "f": "Ruhani yetenek"}
	var icons := {"q": str(def.get("skill_icon", "")), "e": str(def.get("skill2_icon", "")), "r": str(def.get("skill3_icon", "")),
			"p": str(def.get("passive_icon", "")), "f": str(SpiritualSkillsScript.get_def(GameManager.selected_spiritual).get("icon", ""))}
	names["f"] = str(SpiritualSkillsScript.get_def(GameManager.selected_spiritual).get("name", "Ruhani yetenek"))
	var labels := {"q": "Q", "e": "E", "r": "R", "p": "P", "f": "F", "diger": "+"}
	var rows: Array = []
	for slot in SLOT_ORDER + [SLOT_OTHER]:
		var t: Dictionary = slot_totals(slot, dealt, gain)
		if float(t["dmg"]) <= 0.0 and float(t["heal"]) <= 0.0 and float(t["shield"]) <= 0.0:
			continue
		rows.append({"slot": slot, "label": labels[slot], "icon": icons.get(slot, ""), "name": names.get(slot, "Diğer: evcil, eşya, süregelen"), "dmg": float(t["dmg"]),
				"heal": float(t["heal"]), "shield": float(t["shield"]),
				"crit_pct": (100.0 * float(t["crit"]) / float(maxi(int(t["hits"]), 1))) if int(t["hits"]) > 0 else 0.0,
				"share": float(t["dmg"]) / maxf(total, 1.0)})
	return rows


## 12345 -> "12.345" (oyun sonu tablosuyla aynı biçim), 1_250_000 -> "1,25 Mn".
static func fmt(v: float) -> String:
	var n: int = int(round(v))
	if n >= 10_000_000:
		return "%.1f Mn" % (n / 1_000_000.0)
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## HUD yetenek ikonu düğüm adı -> slot (skill_icon.gd; E ikonu "Skill2Icon" değil genel dalda, adı hud.tscn'de "Skill2Icon").
const ICON_SLOT := {"PassiveIcon": "p", "SkillIcon": "q", "Skill2Icon": "e", "Skill3Icon": "r", "SpiritIcon": "f"}


## Yetenek ipucunda Shift'e basılıyken gösterilen "bu oyunda" bölümü (BBCode). ink = UIKit.INK. Boşsa: henüz bir şey yapmadı.
static func tooltip_bbcode(slot: String, ink: Dictionary) -> String:
	var t: Dictionary = slot_totals(slot)
	var c_dmg: String = str(ink.get("damage", "#a82a1e"))
	var c_hp: String = str(ink.get("health", "#2f7a1f"))
	var c_sh: String = str(ink.get("shield", "#2a58a8"))
	var c_dim: String = str(ink.get("cooldown", "#5e3f24"))
	var lines: PackedStringArray = []
	if float(t["dmg"]) > 0.0:
		var crit: String = ""
		if int(t["hits"]) > 0:
			crit = "  [color=%s](%d isabet, kritik %%%d)[/color]" % [c_dim, int(t["hits"]), int(round(100.0 * float(t["crit"]) / float(int(t["hits"]))))]
		lines.append("• Hasar: [color=%s][b]%s[/b][/color]%s" % [c_dmg, fmt(float(t["dmg"])), crit])
	if float(t["heal"]) > 0.0:
		lines.append("• Can: [color=%s][b]%s[/b][/color]" % [c_hp, fmt(float(t["heal"]))])
	if float(t["shield"]) > 0.0:
		lines.append("• Kalkan: [color=%s][b]%s[/b][/color]" % [c_sh, fmt(float(t["shield"]))])
	if float(t.get("prevented", 0.0)) > 0.0:
		lines.append("• Engellenen hasar: [color=%s][b]%s[/b][/color]" % [c_sh, fmt(float(t["prevented"]))])
	var util: Dictionary = t.get("util", {})
	var metrics: Array = UTIL_LABELS.keys()
	for m in util.keys():
		if not metrics.has(m):
			metrics.append(m)
	for m in metrics:
		if float(util.get(m, 0.0)) > 0.0:
			lines.append("• %s: [color=%s][b]%s[/b][/color]" % [str(UTIL_LABELS.get(m, m)), c_dmg if UTIL_DAMAGE.has(m) else c_sh, fmt(float(util[m]))])
	var live: PackedStringArray = live_lines(slot, ink)
	if lines.is_empty():
		if not live.is_empty():
			return "\n".join(live)
		return "[color=%s]Bu oyunda henüz bir etkisi olmadı.[/color]" % c_dim
	## Birden çok kaynak varsa (ör. Büyücü Hortum + Arcane) hangisi ne kadar.
	var parts: Array = t["parts"]
	if parts.size() > 1:
		for p in parts:
			var bits: PackedStringArray = []
			if float(p["dmg"]) > 0.0:
				bits.append("%s hasar" % fmt(float(p["dmg"])))
			if float(p["heal"]) > 0.0:
				bits.append("%s can" % fmt(float(p["heal"])))
			if float(p["shield"]) > 0.0:
				bits.append("%s kalkan" % fmt(float(p["shield"])))
			if not bits.is_empty():
				lines.append("[color=%s]   %s: %s[/color]" % [c_dim, str(p["name"]), ", ".join(bits)])
	lines.append_array(live)
	return "\n".join(lines)


## Pasifin ŞU ANKİ etkisi (sayaç değil, yerel oyuncunun canlı değeri): Elara saldırı hızı, Matthew hız, Talon yük, Korsan saldırı gücü,
## Cadı şans. Karakter "skill" id'siyle seçilir (characters.gd: Talon 38, Matthew 43, Elara 12, Korsan 18, Cadı 51).
static func live_lines(slot: String, ink: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	if slot != SLOT_P:
		return out
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var p: Node = tree.get_first_node_in_group("player") if tree != null else null
	if p == null:
		return out
	var c_val: String = str(ink.get("value", "#9a6a10"))
	var lbl := func(label: String, value: String) -> String:
		return "• Şu an: [color=%s][b]%s[/b][/color] %s" % [c_val, value, label]
	match int(Characters.get_def(GameManager.selected_char_id).get("skill", -1)):
		12: ## Elara: seviye başına %1 saldırı hızı (en fazla %30; player.gd ELARA_PASSIVE_*)
			out.append(lbl.call("saldırı hızı", "+%%%d" % int(round(100.0 * minf(float(p.get("level")) * 0.01, 0.3)))))
		43: ## Matthew: toplam hareket hızı bonusu, her %1'i = %0,5 saldırı hızı
			var mv: int = int(p.get("_matthew_move_percent"))
			out.append(lbl.call("hareket hızı (+%%%s saldırı hızı)" % str(snappedf(mv * 0.5, 0.5)), "+%%%d" % mv))
		38: ## Talon: güç yükleri
			out.append(lbl.call("güç yükü", str(int(p.get("_talon_passive_stacks")))))
		18: ## Korsan: cüzdandaki her 30 altın = +1 saldırı gücü
			out.append(lbl.call("saldırı gücü (altından)", "+%d" % int(p.get("_korsan_gold_ap_applied"))))
		51: ## Cadı: eksik her %5 can = 1 şans
			out.append(lbl.call("şans", "+%d" % int(round(float(p.get("_cadi_passive_luck"))))))
	return out


## ---------------------------------------------------------------- EVCİL HAYVAN (kullanıcı isteği 2026-10-18: "skill barında sahip
## olduğumuz pete mouse'u götürünce ne kadar hasar verdiği, hasar azalttığı, iyileştirdiği v.b gözüksün") - hud_pet_slot.gd ipucu.
## Hasar/can BalanceLog._dealt/_gain'den (kaynak etiketleri aşağıda), engellenen hasar BalanceLog._prevented, Papağan eşyası
## BalanceLog._pet_drops. Kelebek'in +%10 saldırı hızı / Papağan'ın +10 şansı sabit (sayaç değil) - açıklamada zaten yazıyor.
## Yeni evcil hayvan etkisi eklerken: kaynağı buraya ekle + take_damage'den önce BalanceLog.tag / heal(..., src) / on_prevented.
const PET_SOURCES := {
	"kopek": ["s:matthew_kopek"],
	"papagan": [],
	"kelebek": ["s:kelebek_ruhu"],
	"peri": ["s:evcil_peri"],
	"kirpi": ["s:evcil_kirpi"],
}


## {dmg, hits, crit, heal, shield, prevented, drops} - bu koşuda, YEREL oyuncunun evcil hayvanı.
static func pet_totals(key: String, dealt: Dictionary = {}, gain: Dictionary = {}, prevented: Dictionary = {}) -> Dictionary:
	if dealt.is_empty():
		dealt = BalanceLogScript.dealt_snapshot()
	if gain.is_empty():
		gain = BalanceLogScript.gain_snapshot()
	if prevented.is_empty():
		prevented = BalanceLogScript.prevented_snapshot()
	var out: Dictionary = {"dmg": 0.0, "hits": 0, "crit": 0, "heal": 0.0, "shield": 0.0, "prevented": 0.0, "drops": 0}
	for src in PET_SOURCES.get(key, []):
		var r: Array = dealt.get(src, [0.0, 0, 0])
		out["dmg"] += float(r[0])
		out["hits"] += int(r[1])
		out["crit"] += int(r[2])
		var g: Array = gain.get(src, [0.0, 0.0])
		out["heal"] += float(g[0])
		out["shield"] += float(g[1])
		out["prevented"] += float(prevented.get(src, 0.0))
	if key == "papagan":
		out["drops"] = BalanceLogScript.pet_drops()
	return out


## Evcil yuvası ipucunun "BU OYUNDA" bölümü (BBCode, tooltip_bbcode ile aynı mürekkep anahtarları).
static func pet_tooltip_bbcode(key: String, ink: Dictionary) -> String:
	var t: Dictionary = pet_totals(key)
	var c_dmg: String = str(ink.get("damage", "#a82a1e"))
	var c_hp: String = str(ink.get("health", "#2f7a1f"))
	var c_sh: String = str(ink.get("shield", "#2a58a8"))
	var c_gold: String = str(ink.get("value", "#9a6a10"))
	var c_dim: String = str(ink.get("cooldown", "#5e3f24"))
	var lines: PackedStringArray = []
	if float(t["dmg"]) > 0.0:
		var extra: String = ""
		if int(t["hits"]) > 0:
			extra = "  [color=%s](%d isabet)[/color]" % [c_dim, int(t["hits"])]
		lines.append("• Hasar: [color=%s][b]%s[/b][/color]%s" % [c_dmg, fmt(float(t["dmg"])), extra])
	if float(t["prevented"]) > 0.0:
		lines.append("• Engellenen hasar: [color=%s][b]%s[/b][/color]" % [c_sh, fmt(float(t["prevented"]))])
	if float(t["heal"]) > 0.0:
		lines.append("• İyileştirme: [color=%s][b]%s[/b][/color]" % [c_hp, fmt(float(t["heal"]))])
	if float(t["shield"]) > 0.0:
		lines.append("• Kalkan: [color=%s][b]%s[/b][/color]" % [c_sh, fmt(float(t["shield"]))])
	if int(t["drops"]) > 0:
		lines.append("• Ağaçtan düşürülen eşya: [color=%s][b]%d[/b][/color]" % [c_gold, int(t["drops"])])
	if lines.is_empty():
		return "[color=%s]Bu oyunda henüz bir şey yapmadı.[/color]" % c_dim
	return "\n".join(lines)
