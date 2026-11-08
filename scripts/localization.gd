extends RefCounted
## DİL DESTEĞİ (2026-11-07, madde 446). Kaynak dil Türkçe: metnin KENDİSİ çeviri anahtarıdır (gettext msgid), çeviriler `res://localization/<kod>.po`.
##
## Nasıl çalışır:
## - Label / Button / tooltip metni Godot'da çizilirken kendiliğinden çevrilir (auto_translate). Yani `label.text = "Tam Ekran"` gibi DÜZ bir metin
##   .po'da çevirisi varsa ekstra kod olmadan İngilizce görünür, dil değişince de kendiliğinden yenilenir.
## - Birleştirilmiş / biçimlenmiş metin ("Kademe " + str(n), "%d kıymık" % n) bu yoldan ÇEVRİLMEZ (sonuç katalogda yok) -> kalıp `tr()` ile
##   sarılır: `tr("%d kıymık · kilit aç") % n`. `_draw` içindeki `draw_string` de kendiliğinden çevrilmez -> `tr()`.
## - Çevrilmemiş (boş msgstr) metin Türkçe görünür, oyun bozulmaz.
## - TUZAK: Godot bulamadığı metni yedek dilden (`internationalization/locale/fallback` = en) arar; İngilizce katalog yüklüyken Türkçe seçilse
##   bile İngilizce çıkar. Bu yüzden SADECE seçili dilin kataloğu yüklü tutulur (apply).
## - Ağ: karşıya düz Türkçe metin giderse alıcıda kendi dilinde görünür; biçimlenmiş metin gönderilmez, kalıp + sayılar gönderilir.
## - Oyuncu adı / sohbet gibi çevrilmemesi gereken etiketlerde `auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED`.
##
## Araçlar: `python -I tools/dil/dil_cikar.py` (metin adaylarını çıkarır, en.po'yu birleştirir, rapor). Sahte yerelleştirme (taşma ve
## çevrilmeyen yer bulma): ortam değişkeni `DIL_SAHTE=1` -> tüm çevrilen metinler [köşeli ayraçlı] ve %35 uzun; köşeli ayraçsız kalan metin
## çeviri yolundan geçmiyor demektir.

## [kod, kendi dilindeki adı]. Ad çevrilmez (her dil kendi adıyla görünür). Yeni dil = buraya satır + localization/<kod>.po.
const LANGUAGES: Array = [["tr", "Türkçe"], ["en", "English"]]
const SOURCE := "tr"
const PO_DIR := "res://localization/"
const PSEUDO_EXPANSION := 0.35

static var _loaded: Translation = null
static var _current: String = SOURCE


static func codes() -> Array:
	var out: Array = []
	for l in LANGUAGES:
		out.append(l[0])
	return out


static func names() -> Array:
	var out: Array = []
	for l in LANGUAGES:
		out.append(l[1])
	return out


static func index_of(code: String) -> int:
	return maxi(codes().find(code), 0)


static func current() -> String:
	return _current


## İlk açılış: işletim sistemi Türkçe ise Türkçe, değilse (çevirisi olan) İngilizce.
static func os_default() -> String:
	var os_lang: String = OS.get_locale_language()
	if os_lang == SOURCE:
		return SOURCE
	if codes().has(os_lang) and ResourceLoader.exists(PO_DIR + os_lang + ".po"):
		return os_lang
	return "en" if ResourceLoader.exists(PO_DIR + "en.po") else SOURCE


## Dili uygular. Önceki katalog her zaman çıkarılır (yedek dil tuzağı, üst not). Kaynak dil (tr) = katalog yok.
static func apply(code: String) -> void:
	if not codes().has(code):
		code = SOURCE
	if _loaded != null:
		TranslationServer.remove_translation(_loaded)
		_loaded = null
	if code != SOURCE:
		var path: String = PO_DIR + code + ".po"
		if ResourceLoader.exists(path):
			var t: Translation = load(path) as Translation
			if t != null:
				TranslationServer.add_translation(t)
				_loaded = t
		else:
			push_warning("Localization: %s yok, Türkçe kalıyor" % path)
			code = SOURCE
	_current = code
	TranslationServer.set_locale(code)
	_apply_pseudo()


## static fonksiyonlarda tr() yok: kısa yol. Ekrana giden BİRLEŞİK metnin parçaları kaynakta bununla çevrilir; veri (kimlik, kayıt) Türkçe kalır.
static func t(msg: String) -> String:
	return TranslationServer.translate(msg)


## Türkçe yüzde ("%15", "+%2.5") -> İngilizcede "15%", "+2.5%". Hazır biçimlenmiş, sayı içeren metinler için (kalıp çevrilemeyen yerler);
## kalıp çevrilebiliyorsa "%%%d" -> "%d%%" çevirisi tercih edilir. Kaynak dilde dokunmaz.
static func pct(s: String) -> String:
	if _current == SOURCE or s.find("%") < 0:
		return s
	var re := RegEx.new()
	re.compile("%(\\d+(?:[.,]\\d+)?)")
	return re.sub(s, "$1%", true)


## TANIM TABLOLARI (karakter / eşya / efsun / ruhani; madde 446 3. parti): get_def bunu çağırır -> ekranlar seçili dilde ad + açıklama alır,
## gösterim yerlerinin tek tek sarılması gerekmez. Kaynak dilde AYNI sözlük döner (kopya yok). Diğer dillerde metin alanları çevrilmiş,
## dil başına önbelleklenmiş derin kopya (iç içe "upgrades" satırları dahil; dizi/sözlük türü korunur). Mantık alanları (stats, kademe,
## recipe, element...) dokunulmaz. Kayıt/ağ için Türkçe gerekiyorsa çevrilmemiş tablo okunur (Characters.get_def_raw, ör. balans kaydı).
static var _def_cache: Dictionary = {}


static func localized(cache_key: String, src: Dictionary) -> Dictionary:
	if _current == SOURCE or src.is_empty():
		return src
	var c: Array = _def_cache.get(cache_key, [])
	if c.size() == 2 and c[0] == _current:
		return c[1]
	var d: Dictionary = _deep(src)
	_def_cache[cache_key] = [_current, d]
	return d


static func _is_text_key(k: String) -> bool:
	return k == "name" or k == "desc" or k == "text" or k == "passive" or k.ends_with("_name") or k.ends_with("_desc")


static func _deep(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = (v as Dictionary).duplicate()
		for k in d:
			var x: Variant = d[k]
			if x is String and _is_text_key(str(k)):
				d[k] = pct(t(x))
			elif x is Dictionary or x is Array:
				d[k] = _deep(x)
		return d
	if v is Array:
		var a: Array = (v as Array).duplicate()
		for i in a.size():
			if a[i] is Dictionary or a[i] is Array:
				a[i] = _deep(a[i])
		return a
	return v


static func _apply_pseudo() -> void:
	var on: bool = OS.get_environment("DIL_SAHTE") == "1"
	if on == TranslationServer.pseudolocalization_enabled:
		return
	if on:
		## Aksan KAPALI: piksel yazı tiplerinde (m5x7) aksanlı harf yok, kutu çıkar. Uzatma + köşeli ayraç yeter.
		ProjectSettings.set_setting("internationalization/pseudolocalization/replace_with_accents", false)
		ProjectSettings.set_setting("internationalization/pseudolocalization/expansion_ratio", PSEUDO_EXPANSION)
		ProjectSettings.set_setting("internationalization/pseudolocalization/prefix", "[")
		ProjectSettings.set_setting("internationalization/pseudolocalization/suffix", "]")
	TranslationServer.pseudolocalization_enabled = on
	TranslationServer.reload_pseudolocalization()
