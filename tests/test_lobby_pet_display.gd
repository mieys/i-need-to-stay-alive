extends Node

## Çok oyunculu karakter seçiminde BAŞKA oyuncunun evcil hayvanı (2026-11-06, kullanıcı: "diğer oyuncuların hangi peti seçtiği
## gösterilmiyor sadece 2 şey gösteriliyor 3. de çarpı var"): evcil eskiden ağdan hiç gitmiyordu, kart yalnız kendi evcilini
## çiziyordu (3. "çarpı" host'un odadan at düğmesi). Artık lobby_players[peer]["pet"] -> kartta (ve eski satır listesinde) simge.

const LU := preload("res://scripts/menu_lobby_ui.gd")
const PetCatalog := preload("res://scripts/pet_catalog.gd")
const PortraitFace := preload("res://scripts/portrait_face.gd")
const HT := preload("res://scripts/hud_theme.gd")
const SS := preload("res://scripts/spiritual_skills.gd")

const OTHER_PID := 4242


static func _tips(n: Node, out: Array) -> Array:
	if n is Control and str((n as Control).tooltip_text).begins_with("Evcil: "):
		out.append(str((n as Control).tooltip_text))
	for c in n.get_children():
		_tips(c, out)
	return out


func test_other_players_pet_shows_on_select_card() -> void:
	var scene: Control = (load("res://scenes/character_select.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	var desk: Node = scene.get("_desk")
	assert(desk != null, "seçim ekranı yok")
	var had: bool = NetworkManager.lobby_players.has(OTHER_PID)
	NetworkManager.lobby_players[OTHER_PID] = {"name": "Arkadaş", "char_id": 1, "weapon": "", "spirit": "", "pet": "kirpi"}
	desk.set("solo", false)
	var card: Node = desk.call("_player_card", OTHER_PID, 1)
	var tips: Array = _tips(card, [])
	assert(tips == ["Evcil: " + PetCatalog.display_name("kirpi")], "başkasının kartında evcil simgesi yok: %s" % [tips])
	card.free()
	## Eski exe "pet" göndermez: kart boş kalır, çökme yok.
	NetworkManager.lobby_players[OTHER_PID].erase("pet")
	card = desk.call("_player_card", OTHER_PID, 1)
	assert(_tips(card, []).is_empty(), "pet alanı yokken evcil simgesi çizilmemeli")
	card.free()
	_check_card_loadout_slots(desk)
	desk.set("solo", true)
	if not had:
		NetworkManager.lobby_players.erase(OTHER_PID)
	scene.queue_free()


## Madde 679 (kullanıcı 2026-11-14: "silahlar karakter penceresinde hiç anlaşılmıyor ... pet ve ruhani pencereleri belirgin değil"):
## kart yuvaları portreyle aynı Gömme Tepsi çerçevesinde, silah açık ahşap kuyuda (siyah konturlu çizimler koyu kuyuda kayboluyordu).
static func _count_framed(n: Node) -> int:
	var k: int = 1 if n is PortraitFace.FramedPortrait else 0
	for c in n.get_children():
		k += _count_framed(c)
	return k


static func _has_well(n: Node, col: Color) -> bool:
	if n is ColorRect and (n as ColorRect).color == col:
		return true
	for c in n.get_children():
		if _has_well(c, col):
			return true
	return false


## Seçim ekranı ikinci kez açılmaz (arka plan yüklemesi dosya sonunda yarım kalıp sahte "Parse Error" veriyordu): ilk testin masası kullanılır.
func _check_card_loadout_slots(desk: Node) -> void:
	var sid: String = str(SS.ORDER[0])
	NetworkManager.lobby_players[OTHER_PID] = {"name": "Arkadaş", "char_id": 1, "weapon": "yay", "spirit": sid, "pet": "kirpi"}
	var card: Node = desk.call("_player_card", OTHER_PID, 1)
	assert(_count_framed(card) == 4, "portre + silah + evcil + ruhani çerçeveli olmalı: %d" % _count_framed(card))
	assert(_has_well(card, HT.ITEM_WELL), "silah yuvası ITEM_WELL (damarlı ahşap) kuyusunda değil")
	card.free()


func test_lobby_row_shows_pet() -> void:
	var row: Control = LU.make_player_row({"name": "Arkadaş", "char_id": 1, "pet": "peri"}, {"fs_body": 16, "fs_small": 16, "k": 1})
	var tips: Array = _tips(row, [])
	assert(tips == ["Evcil: " + PetCatalog.display_name("peri")], "oda satırında evcil simgesi yok: %s" % [tips])
	row.free()


func test_local_loadout_includes_pet() -> void:
	var old: String = str(GameManager.selected_pet)
	GameManager.selected_pet = "papagan"
	assert(NetworkManager.call("_local_pet") == "papagan", "yerel evcil anahtarı yanlış")
	GameManager.selected_pet = "bozuk_anahtar"
	assert(NetworkManager.call("_local_pet") == PetCatalog.DEFAULT_KEY, "bozuk evcil varsayılana düşmeli")
	GameManager.selected_pet = old
