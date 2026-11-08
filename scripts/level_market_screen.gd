extends CanvasLayer

## LEVEL PAZARI EKRANI (madde 432, kullanıcı 2026-11-06: level menüsü "karmaşık" bulunuyordu -> "öyle yapalım": önce kart, sonra
## pazar). Kart ekranı (level_up_screen.gd) artık yalnız kart seçtirir ve kapanır; bu ekran seviye kuyruğunun SONUNDA (art arda
## birkaç seviye atlandıysa hepsinin kartları seçildikten sonra) BİR KEZ açılır - main.gd _try_open_level_market. Altın yetmese de
## açılır (alınamayan "altın eksik" yazar, kaydedilebilir; madde 432 ek 2). Görünüş level_market_view.gd "market" kipi, kurallar level_market.gd.
## DEVAM ET / Enter kapatır, Boşluk = KARIŞTIR (kart ekranındaki gibi). Çok oyunculuda ortak sayaç açılışta en az
## Market.MARKET_SECONDS'a uzar (pazarın kendi süresi); dolunca ekran kendiliğinden kapanır. Ağaç bu sırada duraklı.

signal closed

const LevelMarketView := preload("res://scripts/level_market_view.gd")
const Market := preload("res://scripts/level_market.gd")
const ReadingUiWatcher := preload("res://scripts/reading_ui_watcher.gd")

## add_child'dan ÖNCE verilir (main.gd)
var player_ref: Node = null
var level: int = 1
var offers: Dictionary = {}

var view: Control = null
var _closing: bool = false


func _enter_tree() -> void:
	add_to_group(ReadingUiWatcher.GROUP) ## karakter okuma pozuna geçer (kart ekranıyla aynı)
	GameManager.register_blocking_panel(self)


func _exit_tree() -> void:
	GameManager.unregister_blocking_panel(self)


func _ready() -> void:
	layer = 1 ## level_up_screen.tscn ile aynı katman
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.02, 0.04, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	view = LevelMarketView.new()
	view.name = "LevelMarket"
	add_child(view)
	view.setup_market(player_ref, level, offers)
	view.continue_pressed.connect(close)
	if NetworkManager.is_multiplayer_active:
		NetworkManager.multiplayer_level_up_timer_tick.connect(_on_timer_tick)
		if NetworkManager.level_up_timer_active:
			view.set_countdown(NetworkManager.level_up_countdown)


func _input(event: InputEvent) -> void:
	if _closing or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var p: Node = get_tree().get_first_node_in_group("player")
	if p and bool(p.get("is_chat_typing")):
		return
	var k: int = (event as InputEventKey).keycode
	if k == KEY_ENTER or k == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		close()
	elif k == KEY_SPACE:
		## odaktaki yuvaya "ui_accept" gidip satın almasın - Boşluk yalnız karıştırır
		get_viewport().set_input_as_handled()
		view.reroll()


func _on_timer_tick(remaining: float) -> void:
	if view:
		view.set_countdown(remaining)
	if remaining <= 0.0:
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
