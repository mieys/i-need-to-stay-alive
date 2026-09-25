extends Node2D

## Gece ışık kaynağı (kullanıcı isteği 2026-09-25: "tüm skill atışları ve efektleri parıltılı olacak karanlıkta, yani
## karanlığı azaltacak ışık gibi" + asa/tabanca/tüfek/havai fişek mermileri ve uçları parıltı yayacak).
##
## Bu düğüm KENDİSİ hiçbir şey çizmez - sadece "night_glow" grubunda durur; atmosphere_overlay.gd her karede gruptaki
## ışıkları düşük çözünürlüklü bir ışık haritasına yumuşak lekeler olarak çizer, ekran renk geçişi (atmosphere_grade.
## gdshader) o haritayla karanlığı kaldırır + renkli parıltı ekler. Gündüz ışık kazancı 0'dır: ışıklar sadece hava
## kararınca (ve hafifçe yağmurlu havada) görünür.
##
## Işık, takıldığı efektin ÇOCUĞU olduğu için: efektle birlikte hareket eder, gizlenince (ör. sis düşman mermisini
## gizleyince) söner, silinince yok olur. Efektin modulate.a'sı (solma) ışığa da yansır. Kullanıcı hangi efekte hangi
## ışığın takılacağını seçmez - liste TEK yerde: night_glow_catalog.gd (yerel VE uzak kopyalar AYNI sahne/script
## yolundan üretildiği için katalog ikisine de otomatik takar, bkz. CLAUDE.md'deki "kaster görür, diğerleri görmez"
## hata sınıfı).
##
## Sahibinin isteğe bağlı kancaları (duck typing, hepsi opsiyonel):
##  - get_glow_segment() -> Array: [başlangıç, bitiş] (DÜNYA konumu) - ışık bir nokta yerine bu çizgi boyunca yayılır
##    (şimşek ışını, zincir, lazer). Boş dizi = o an ışık yok.
##  - get_night_glow_color() -> Color: rengi çalışma anında sahip belirler (ör. görev alanının türü).
##  - get_night_glow_energy() -> float: 0..1 ek çarpan (ör. lazerin uyarı/ateş evresi).

const GROUP := &"night_glow"

var color: Color = Color(1.0, 0.8, 0.5)
## Işığın yarıçapı (DÜNYA birimi; 1 birim = 1080p'de 2 ekran pikseli, harita karolarıyla aynı piksel).
var radius: float = 48.0
## Merkezdeki ışık gücü (0..1).
var energy: float = 0.8
## 0..1 - ateş/şimşek gibi titreyen kaynaklar için rastgele-ama-yumuşak parlaklık dalgalanması.
var flicker: float = 0.0
## >0 ise: flaş - ışık bu kadar saniyede doğrusal söner (namlu ateşi, patlama). 0 = sahibi yaşadıkça sabit.
var decay: float = 0.0
## Sahibi sisin DIŞINDA (takımın göremediği yerde) ise ışık hiç çizilmez - düşman büyüleri için: gizli yaratığın
## ışığı sisin içinde konumunu ele vermesin (sis düşmanın kendisini zaten gizliyor, bkz. vision_fog.gd).
var hide_in_fog: bool = false
## Işık sahibinin modulate.a'sıyla (ve 3 kuşak atasınınkiyle) birlikte sönsün mü.
var fade_with_owner: bool = true

var _age: float = 0.0
var _seed: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_seed = randf() * 100.0
	## Kendi çizimi yok; sadece yaş sayacı (flaş/titreme) için işlenir.
	set_process(decay > 0.0 or flicker > 0.0)


func _process(delta: float) -> void:
	_age += delta
	if decay > 0.0 and _age >= decay:
		queue_free()


## Bir sahibe ışık takar. profile: {color, radius, energy, flicker, decay, offset (sahibin YEREL koordinatında),
## hide_in_fog, fade_with_owner}. Döndürdüğü düğüm sahibin çocuğudur.
static func attach(target: Node, profile: Dictionary) -> Node2D:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return null
	var glow := Node2D.new()
	glow.set_script(load("res://scripts/night_glow.gd"))
	glow.name = "NightGlow"
	glow.set("color", profile.get("color", Color(1.0, 0.8, 0.5)))
	glow.set("radius", float(profile.get("radius", 48.0)))
	glow.set("energy", float(profile.get("energy", 0.8)))
	glow.set("flicker", float(profile.get("flicker", 0.0)))
	glow.set("decay", float(profile.get("decay", 0.0)))
	glow.set("hide_in_fog", bool(profile.get("hide_in_fog", false)))
	glow.set("fade_with_owner", bool(profile.get("fade_with_owner", true)))
	glow.position = Vector2(profile.get("offset", Vector2.ZERO))
	target.add_child(glow)
	return glow


## Bu karedeki etkin ışık gücü (0 = çizme). atmosphere_overlay.gd çağırır.
func current_energy() -> float:
	if not is_visible_in_tree():
		return 0.0
	var e: float = energy
	var owner_node: Node = get_parent()
	if owner_node != null and owner_node.has_method("get_night_glow_energy"):
		e *= clampf(float(owner_node.call("get_night_glow_energy")), 0.0, 1.0)
	if decay > 0.0:
		e *= clampf(1.0 - _age / decay, 0.0, 1.0)
	if flicker > 0.0:
		## İki farklı frekanslı sinüs - rastgele gürültü gibi titrer ama kareden kareye zıplamaz.
		var t: float = _age * 9.0 + _seed
		e *= 1.0 - flicker * (0.5 + 0.25 * sin(t) + 0.25 * sin(t * 2.7 + 1.3))
	if fade_with_owner:
		var n: Node = owner_node
		var depth: int = 0
		while n != null and n is CanvasItem and depth < 4:
			var ci := n as CanvasItem
			e *= ci.modulate.a
			if depth == 0:
				e *= ci.self_modulate.a
			n = n.get_parent()
			depth += 1
	return e


func current_color() -> Color:
	var owner_node: Node = get_parent()
	if owner_node != null and owner_node.has_method("get_night_glow_color"):
		return owner_node.call("get_night_glow_color")
	return color


## [başlangıç, bitiş] dünya konumu (çizgi ışık) ya da boş dizi (nokta ışık).
func current_segment() -> Array:
	var owner_node: Node = get_parent()
	if owner_node != null and owner_node.has_method("get_glow_segment"):
		return owner_node.call("get_glow_segment")
	return []


func is_segment_light() -> bool:
	var owner_node: Node = get_parent()
	return owner_node != null and owner_node.has_method("get_glow_segment")
