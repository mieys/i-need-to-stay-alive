extends Node

## ARAYÜZÜ GİZLE (madde 612, kullanıcı isteği 2026-11-12: "oyunda arayüzü komple kapatmayı sağlayan bir düğme ekle F tuşlarına").
## Varsayılan F3 (GameManager "hide_ui"; F1/F2 teslim oylamasında, F9 hata ayıklama panelinde; Ayarlar > TUŞLAR'dan değişir).
## Yalnız yerel görünüm: ağ, oyun mantığı, hasar/can hesabı HİÇ değişmez; tuşlar (yetenek, hareket, ESC) çalışmaya devam eder.
##
## İKİ KATMAN:
##  1) EKRAN ARAYÜZÜ: HUD, sohbet, grup paneli, minimap, bildirimler, boss barı, görev satırları, ipucu levhaları... Her biri bir
##     CanvasLayer; `mark_layer` ile GROUP_SCREEN grubuna girer. Gizleyince katmanın `visible`'ı kapanır (top_level çocuklar dahil
##     tüm katman gider). Başkası bir katmanı açarsa (level pazarı görev satırlarını kapatıp açar, ev ipucu duraklamada gizlenir)
##     her karede yeniden kapatılır; açarken her katman EN SON gördüğümüz durumuna döner (pazar açıkken gizlenmişse gizli kalır).
##  2) DÜNYA İÇİ ARAYÜZ: karakter/yaratık üstü can-kalkan çubuğu, isim etiketi, düşme sayacı, sohbet balonu, hasar sayıları. Bunların
##     `visible`'ını kendi sahipleri sürekli değiştirir (enemy.gd çubuğu yedi yerde açıp kapatır) - bu yüzden `visibility_layer`
##     bitiyle kapatılır (`mark_world`): 0 = hiçbir görünümde çizilmez, 1 = normal. (visibility_layer'ın tek başka kullanıcısı
##     ground_texel_pass.gd, o yalnız zemin katmanlarında.)
##
## KAPSAM DIŞI (bilerek): modal/etkileşimli ekranlar (level kartı, pazar, sandık, ESC menüsü, ölüm/zafer, teslim oylaması,
## oyuncular bekleniyor, yükleme) - gizlenirse oyun kilitliymiş gibi durur. Telefonda anahtar yok (dokunmatik kontroller de gizlenirdi).
## Oyun/HUD kapanınca (ana menü, yeniden başlama) kendiliğinden sıfırlanır.

const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const GROUP_SCREEN := &"hideable_ui"
const GROUP_WORLD := &"hideable_ui_world"
const ACTION := "hide_ui"
const LAYER_SHOWN := 1
const LAYER_HIDDEN := 0
const PRUNE_AT := 48 ## `_prior` bu kadar büyüyünce silinmiş düğümler atılır (gizliyken doğup ölen bildirim katmanları)

## Şu an gizli mi (yerel). Dünya içi öğeler doğarken `mark_world` bunu okur.
static var hidden: bool = false

## Katman -> gizlemeden önceki (ya da başkasının sonradan açtığı) `visible` değeri.
var _prior: Dictionary = {}


## Ekran arayüzü katmanını kaydeder (CanvasLayer). Gizliyken sonradan eklenen katman bir sonraki `_process`'te (aynı karede, çizimden önce) kapanır.
static func mark_layer(node: Node) -> void:
	if node != null and not node.is_in_group(GROUP_SCREEN):
		node.add_to_group(GROUP_SCREEN)


## Dünya içi arayüz öğesini kaydeder (can çubuğu, etiket, balon...). Gizliyken doğan öğe hemen gizli başlar.
static func mark_world(item: CanvasItem) -> void:
	if item == null:
		return
	if not item.is_in_group(GROUP_WORLD):
		item.add_to_group(GROUP_WORLD)
	if hidden:
		item.visibility_layer = LAYER_HIDDEN


func _init() -> void:
	name = "UiHide"
	process_mode = Node.PROCESS_MODE_ALWAYS ## duraklatma/seviye ekranında da çalışır (bildirim katmanları yine kapanır)
	process_priority = 1000 ## diğer düğümlerin _process'inden SONRA: bu karede açılan katman çizilmeden kapatılır (1 karelik yanıp sönme yok)


func _input(event: InputEvent) -> void:
	if not InputMap.has_action(ACTION) or not event.is_action_pressed(ACTION):
		return
	if MobileUIScript.enabled:
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return ## sohbet/ad kutusuna yazarken (F tuşu zaten metin değil) kutuyu görünmez bırakma
	if toggle():
		get_viewport().set_input_as_handled()


## Gizle/göster. Oyunda değilsek (kayıtlı ekran katmanı yok) hiçbir şey yapmaz ve false döner.
func toggle() -> bool:
	if get_tree().get_nodes_in_group(GROUP_SCREEN).is_empty():
		return false
	set_hidden(not hidden)
	return true


func set_hidden(value: bool) -> void:
	if value == hidden:
		return
	hidden = value
	if hidden:
		_enforce(get_tree().get_nodes_in_group(GROUP_SCREEN))
	else:
		_restore()
	get_tree().set_group(GROUP_WORLD, "visibility_layer", LAYER_HIDDEN if hidden else LAYER_SHOWN)


func _process(_delta: float) -> void:
	if not hidden:
		return
	var layers: Array[Node] = get_tree().get_nodes_in_group(GROUP_SCREEN)
	if layers.is_empty():
		## Oyun/HUD gitti (ana menüye dönüş, yeniden başlama): bir sonraki oyun açık arayüzle başlasın.
		hidden = false
		_prior.clear()
		get_tree().set_group(GROUP_WORLD, "visibility_layer", LAYER_SHOWN)
		return
	_enforce(layers)


## Kayıtlı her katmanı kapalı tutar; açık bulduğumuz katmanın "önceki" değerini true yapar (başkası açmıştır).
func _enforce(layers: Array[Node]) -> void:
	for n: Node in layers:
		if bool(n.get("visible")):
			_prior[n] = true
			n.set("visible", false)
		elif not _prior.has(n):
			_prior[n] = false
	if _prior.size() > PRUNE_AT:
		for k: Variant in _prior.keys():
			if not is_instance_valid(k):
				_prior.erase(k)


func _restore() -> void:
	for k: Variant in _prior.keys():
		if is_instance_valid(k) and bool(_prior[k]):
			(k as Node).set("visible", true)
	_prior.clear()
