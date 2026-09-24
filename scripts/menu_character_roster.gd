extends GridContainer

## Karakter kartı ızgarası - tek oyunculu (character_select.gd) ve çok oyunculu (lobby_menu.gd) ekranların ORTAK bileşeni.
## Eskiden iki ekranda "birebir aynı" tutulan iki ayrı kopya vardı (kart stili, isim sığdırma, seçim çerçevesi) ve her
## düzeltme iki yere ayrı ayrı yapılmak zorundaydı; artık tek yer. 6 sütun x 2 satır (12 karakter) - bkz. MenuKit.CARD_SIZE.

signal character_picked(char_id: int)

const CardScript: GDScript = preload("res://scripts/menu_character_card.gd")
const COLUMNS := 6
const H_SEP := 4
const V_SEP := 6

var cards: Dictionary = {}


func build() -> void:
	columns = COLUMNS
	add_theme_constant_override("h_separation", H_SEP)
	add_theme_constant_override("v_separation", V_SEP)
	for child in get_children():
		child.queue_free()
	cards.clear()
	for char_id in Characters.DEFS:
		var card: Control = CardScript.new()
		card.name = "Card%d" % char_id
		add_child(card)
		card.setup(char_id, Characters.DEFS[char_id])
		card.pressed.connect(_on_card_pressed)
		cards[char_id] = card


## Izgaranın toplam boyutu (yerleşim hesapları için): 6 x 180 + 5 x 4 = 1100 px genişlik, 2 x 216 + 6 = 438 px yükseklik.
static func grid_size(count: int) -> Vector2:
	var rows: int = int(ceil(float(count) / COLUMNS))
	return Vector2(COLUMNS * MenuKit.CARD_SIZE.x + (COLUMNS - 1) * H_SEP, rows * MenuKit.CARD_SIZE.y + (rows - 1) * V_SEP)


func select(char_id: int) -> void:
	for id in cards:
		cards[id].selected = (id == char_id)


func focus_card(char_id: int) -> void:
	if cards.has(char_id):
		(cards[char_id] as Control).grab_focus()


func _on_card_pressed(char_id: int) -> void:
	select(char_id)
	character_picked.emit(char_id)
