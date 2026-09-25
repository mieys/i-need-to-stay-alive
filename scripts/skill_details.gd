extends RefCounted

## Yetenek ipucunun Shift'e basılı tutulunca açılan "Ayrıntılar" bölümü (kullanıcı isteği 2026-09-25: "shifte basılı
## tutunca yeteneklerin ayrıntılı açıklamaları ve ne kadar hasar verip ne kadar iyileştirdiği hasar soğurduğunu v.b
## göstersin (skilin özelliklerine bağlı olarak)").
##
## TEK KAYNAK = yeteneğin kendi açıklama metni (characters.gd / spiritual_skills.gd / Büyücü varyasyon metni). Her
## karakter için ayrı ayrı kod yazmak yerine metindeki oranlar ("saldırı gücünün %110'u", "maksimum kalkanının %5'i",
## "EKSİK kalkanının %5'i", "maksimum canın %15'i" ...) oyuncunun O ANKİ statlarıyla sayıya çevrilir ve metnin geri
## kalanından ne olduğu (hasar / kalkan / iyileştirme / soğurma) anlaşılır. Böylece açıklama güncellenince ayrıntılar da
## kendiliğinden doğru kalır; yeni yetenek eklendiğinde ekstra iş yok. "saniyede / her saniye" geçen değerler için
## yeteneğin süresi biliniyorsa toplam da verilir.

const PERCENT_REF := [
	## [metindeki ifade (regex), stat anahtarı, okunur ad]
	["saldırı gücünün\\s*%(\\d+(?:[.,]\\d+)?)", "ap", "saldırı gücü"],
	["(?:EKSİK|eksik) kalkan(?:ının|ın)\\s*%(\\d+(?:[.,]\\d+)?)", "missing_shield", "eksik kalkan"],
	["(?:MAKSİMUM|maksimum|maks\\.?) kalkan(?:ının|ın)\\s*%(\\d+(?:[.,]\\d+)?)", "max_shield", "maks. kalkan"],
	["(?:maksimum|maks\\.?|MAKSİMUM) can(?:ının|ın)\\s*%(\\d+(?:[.,]\\d+)?)", "max_health", "maks. can"],
	["saniyede\\s*%(\\d+(?:[.,]\\d+)?)\\s*kalkan", "max_shield", "maks. kalkan"],
	["saniyede\\s*%(\\d+(?:[.,]\\d+)?)\\s*can", "max_health", "maks. can"],
	["Anında\\s*%(\\d+(?:[.,]\\d+)?)\\s*can", "max_health", "maks. can"],
]


static func _stat(player: Node, key: String) -> float:
	match key:
		"ap":
			return float(player.get("damage_bonus"))
		"max_shield":
			return float(player.get("item_shield_max"))
		"missing_shield":
			return maxf(0.0, float(player.get("item_shield_max")) - float(player.get("item_shield_hp")))
		"max_health":
			return float(player.get("max_health"))
	return 0.0


## Oranın ne için kullanıldığı: eşleşmenin hemen sonrasındaki (ya da öncesindeki) kelimelerden.
static func _kind(after: String, before: String) -> String:
	var a: String = after.to_lower()
	var b: String = before.to_lower()
	for pair in [["hasar", "Hasar"], ["kalkan yenile", "Kalkan"], ["kalkan", "Kalkan"], ["can yenile", "İyileştirme"],
			["iyileş", "İyileştirme"], ["can", "İyileştirme"], ["soğur", "Soğurma"]]:
		if a.find(pair[0]) != -1:
			return pair[1]
	if b.find("yenile") != -1:
		return "Yenileme"
	return "Değer"


static func _fmt(v: float) -> String:
	if absf(v - roundf(v)) < 0.05:
		return str(int(roundf(v)))
	return "%.1f" % v


## desc: ipucunda gösterilen açıklama; duration: yeteneğin etkin süresi (sn, bilinmiyorsa 0).
## Döner: BBCode metni (boşsa gösterecek sayısal ayrıntı yok).
static func build(desc: String, player: Node, duration: float, ink: Dictionary) -> String:
	if player == null or not is_instance_valid(player):
		return ""
	var lines: PackedStringArray = []
	var seen: Dictionary = {}
	for ref in PERCENT_REF:
		var re := RegEx.new()
		if re.compile(String(ref[0])) != OK:
			continue
		for m in re.search_all(desc):
			if seen.has(m.get_start()):
				continue
			seen[m.get_start()] = true
			var pct: float = float(m.get_string(1).replace(",", ".")) / 100.0
			var base: float = _stat(player, String(ref[1]))
			var value: float = base * pct
			var after: String = desc.substr(m.get_end(), 48)
			var before: String = desc.substr(maxi(0, m.get_start() - 32), mini(32, m.get_start()))
			var kind: String = _kind(after, before)
			## "saniyede / her saniye" aynı cümlede oranın ÖNÜNDE geçiyorsa değer saniye başınadır (ör. "her saniye EKSİK
			## kalkanının %5'i + MAKSİMUM kalkanının %5'i" - ikisi de /sn).
			var sentence: String = desc.substr(0, m.get_start())
			var cut: int = maxi(sentence.rfind("."), sentence.rfind(":"))
			if cut != -1:
				sentence = sentence.substr(cut + 1)
			var per_sec: bool = sentence.find("saniyede") != -1 or sentence.find("her saniye") != -1 \
					or desc.substr(m.get_start(), 14).begins_with("saniyede")
			var color: String = ink.get("damage", "#a3301c") if kind == "Hasar" else (ink.get("shield", "#2c5c9a") if kind in ["Kalkan", "Soğurma", "Yenileme"] else ink.get("health", "#3d6616"))
			var line: String = "• %s: [color=%s][b]%s[/b][/color]" % [kind, color, _fmt(value)]
			if per_sec:
				line += " /sn"
				if duration > 0.05:
					line += "  (toplam ~%s, %ssn)" % [_fmt(value * duration), _fmt(duration)]
			line += "  [color=%s](%s %s x %%%s)[/color]" % [ink.get("cooldown", "#5e3f24"), _fmt(base), String(ref[2]), _fmt(pct * 100.0)]
			lines.append(line)
	if duration > 0.05 and duration < 900.0:
		lines.append("• Süre: [b]%ssn[/b]" % _fmt(duration))
	var ap: float = float(player.get("damage_bonus"))
	lines.append("[color=%s]Saldırı gücün: %s  •  Maks. can: %s  •  Kalkan: %s / %s[/color]" % [ink.get("cooldown", "#5e3f24"),
			_fmt(ap), _fmt(float(player.get("max_health"))), _fmt(float(player.get("item_shield_hp"))), _fmt(float(player.get("item_shield_max")))])
	return "\n".join(lines)
