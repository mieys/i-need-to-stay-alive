extends Node

## 2026-10-07 (kullanıcı isteği): "bundan sonra elit sandıklardan sadece epik item çıkacak ... normal sandıklar sırayla
## oyunculara verilecek, bir oyuncu normal sandığı aldığında sıra onda değilse sandık grup penceresinden o kişinin barına
## gidecek. elit sandıklar herkese eşit dağıtılacak". Kapsam: sıra mantığı (NetworkManager.next_chest_turn /
## advance_chest_turn), uçuş efekti (chest_pass_fx.gd) + konum API'leri (grup paneli / HUD), elit sandık menüsü (epik havuz).

const ChestPassFx := preload("res://scripts/chest_pass_fx.gd")
const PartyPanelScript := preload("res://scripts/party_panel.gd")
const ChestMenuScript := preload("res://scripts/chest_menu.gd")

const ALLY_SOURCE := """
extends Node2D
var peer_id: int = 0
var player_name: String = "Dost"
var char_id: int = 1
var health: float = 80.0
var max_health: float = 100.0
var item_shield_max: float = 0.0
var item_shield_hp: float = 0.0
var is_dead: bool = false
var is_downed: bool = false
"""


# ------------------------------------------------------------------ sıra mantığı

func test_next_chest_turn_cycles_in_peer_id_order() -> void:
	assert(NetworkManager.next_chest_turn([], 0) == 0, "boş listede kazanan yok")
	assert(NetworkManager.next_chest_turn([1, 5, 9], 0) == 1, "ilk sandık en küçük peer'e (host) gider")
	assert(NetworkManager.next_chest_turn([1, 5, 9], 1) == 5, "sıra bir sonraki peer'e geçer")
	assert(NetworkManager.next_chest_turn([1, 5, 9], 5) == 9)
	assert(NetworkManager.next_chest_turn([1, 5, 9], 9) == 1, "son peer'den sonra başa sarar")
	assert(NetworkManager.next_chest_turn([9, 1, 5], 1) == 5, "giriş sırası önemsiz, peer id'ye göre döner")
	assert(NetworkManager.next_chest_turn([7], 7) == 7, "tek oyuncu her sandığı alır")
	assert(NetworkManager.next_chest_turn([1, 5, 9], 100) == 1, "tüm id'lerden büyük son alan -> başa sar")


func test_chest_turn_skips_missing_players_and_welcomes_new_ones() -> void:
	## 5 öldü/ayrıldı: sıra 1'den sonra 9'a atlar.
	assert(NetworkManager.next_chest_turn([1, 9], 1) == 9, "ayrılan/ölü oyuncu atlanmalı")
	## Sırası gelen peer (5) o an yok: kalanlardan ondan BÜYÜK ilk id alır.
	assert(NetworkManager.next_chest_turn([1, 9], 5) == 9, "son alan yok olsa da sıra kaybolmamalı")
	## Yeni katılan 6: 5'ten sonra 6, sonra 9.
	assert(NetworkManager.next_chest_turn([1, 5, 6, 9], 5) == 6, "yeni katılan sıraya girer")


func test_advance_chest_turn_is_fair_over_many_chests() -> void:
	var saved: int = NetworkManager._chest_turn_last_peer
	NetworkManager._chest_turn_last_peer = 0
	var counts: Dictionary = {1: 0, 2: 0, 3: 0}
	var seq: Array = []
	for i in range(9):
		var w: int = NetworkManager.advance_chest_turn([3, 1, 2])
		counts[w] += 1
		seq.append(w)
	assert(seq == [1, 2, 3, 1, 2, 3, 1, 2, 3], "sıra 1-2-3 döngüsü olmalı: %s" % str(seq))
	for id in counts.keys():
		assert(counts[id] == 3, "herkes eşit sayıda sandık almalı: %s" % str(counts))
	assert(NetworkManager.advance_chest_turn([]) == 0, "boş listede sıra ilerlemez")
	assert(NetworkManager._chest_turn_last_peer == 3, "boş çağrı sırayı bozmamalı")
	NetworkManager._chest_turn_last_peer = saved


func test_picker_does_not_decide_the_receiver() -> void:
	## Eski kural "sandığı alan alır"dı. Şimdi alan kişi önemsiz: aynı kişi (2) üst üste 3 sandık toplasa bile sıra döner.
	var saved: int = NetworkManager._chest_turn_last_peer
	NetworkManager._chest_turn_last_peer = 0
	var got: Array = []
	for i in range(3):
		got.append(NetworkManager.advance_chest_turn([1, 2, 3]))
	assert(got == [1, 2, 3], "toplayan kim olursa olsun sıradaki alır: %s" % str(got))
	NetworkManager._chest_turn_last_peer = saved


# ------------------------------------------------------------------ uçuş efekti + konumlar

func test_chest_pass_fx_flies_and_cleans_up() -> void:
	assert(ChestPassFx.play(get_tree(), Vector2.INF, Vector2(100, 100)) == null, "sonsuz konumda efekt kurulmamalı")
	var fx: Control = ChestPassFx.play(get_tree(), Vector2(1600, 300), Vector2(900, 980))
	assert(fx != null and is_instance_valid(fx), "efekt kurulmalı")
	var layer: Node = fx.get_parent()
	assert(layer is CanvasLayer and layer.name == ChestPassFx.LAYER_NAME, "efekt kendi CanvasLayer'ında olmalı")
	assert((layer as CanvasLayer).layer > 96, "katman grup panelinin (96) üstünde olmalı")
	assert(layer.process_mode == Node.PROCESS_MODE_ALWAYS, "oyun duraklıyken (sandık menüsü) de oynamalı")
	var start: Vector2 = fx.position
	await _wait(0.6)
	assert(is_instance_valid(fx) and fx.position.distance_to(start) > 50.0, "sandık uçuşta hareket etmeli")
	await _wait(2.2)
	assert(not is_instance_valid(fx), "uçuş bitince sandık silinmeli")
	assert(layer.get_child_count() == 0, "halka/kıvılcımlar da temizlenmeli, kalan: %d" % layer.get_child_count())
	## İkinci efekt aynı katmanı yeniden kullanmalı.
	var fx2: Control = ChestPassFx.play(get_tree(), Vector2(10, 10), Vector2(300, 300))
	assert(fx2.get_parent() == layer, "katman paylaşılmalı")
	await _wait(2.8)
	layer.queue_free()


func test_chest_pass_fx_between_peers_uses_hud_positions() -> void:
	## Sahte HUD: yerel çubuk + grup paneli satırı. Alan = müttefik (2), sıradaki = biz (1).
	var hud := Node.new()
	hud.name = "HUD"
	hud.set_script(_script("""
extends Node
func get_own_bar_center() -> Vector2:
	return Vector2(960, 1000)
"""))
	var layer := Node.new()
	layer.name = "PartyPanelLayer"
	hud.add_child(layer)
	var panel := Node.new()
	panel.name = "PartyPanel"
	panel.set_script(_script("""
extends Node
func get_row_center(peer_id: int) -> Vector2:
	return Vector2(1700, 300) if peer_id == 2 else Vector2.INF
"""))
	layer.add_child(panel)
	add_child(hud) ## current_scene = bu test düğümü (run_tests.gd)
	assert(ChestPassFx.bar_center(hud, 1, 1) == Vector2(960, 1000), "kendi çubuğumuz HUD'dan okunmalı")
	assert(ChestPassFx.bar_center(hud, 2, 1) == Vector2(1700, 300), "müttefik çubuğu grup panelinden okunmalı")
	assert(not is_finite(ChestPassFx.bar_center(hud, 3, 1).x), "panelde olmayan peer için konum yok")
	assert(ChestPassFx.play_between_peers(get_tree(), 1, 1, 1) == null, "alan = sıradaki ise uçuş yok")
	assert(ChestPassFx.play_between_peers(get_tree(), 0, 1, 1) == null, "alan bilinmiyorsa uçuş yok")
	assert(ChestPassFx.play_between_peers(get_tree(), 3, 1, 1) == null, "alanın çubuğu yoksa uçuş atlanır (yazı yine görünür)")
	var fx: Control = ChestPassFx.play_between_peers(get_tree(), 2, 1, 1)
	assert(fx != null, "müttefikten bize uçuş kurulmalı")
	assert(fx.position.distance_to(Vector2(1700, 300) - fx.size * 0.5) < 1.0, "uçuş alanın satırından başlamalı")
	var fx2: Control = ChestPassFx.play_between_peers(get_tree(), 1, 2, 1)
	assert(fx2 != null, "bizden müttefike uçuş kurulmalı")
	assert(fx2.position.distance_to(Vector2(960, 1000) - fx2.size * 0.5) < 1.0, "uçuş bizim çubuğumuzdan başlamalı")
	await _wait(2.8)
	var fx_layer: Node = get_node_or_null(ChestPassFx.LAYER_NAME)
	if fx_layer:
		fx_layer.queue_free()
	hud.queue_free()


func test_party_panel_reports_row_center_for_allies() -> void:
	var ally := Node2D.new()
	ally.set_script(_script(ALLY_SOURCE))
	ally.set("peer_id", 42)
	ally.add_to_group("remote_players")
	add_child(ally)
	var panel := Control.new()
	panel.set_script(PartyPanelScript)
	add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	var c: Vector2 = panel.call("get_row_center", 42)
	assert(is_finite(c.x) and is_finite(c.y), "müttefik satırının konumu bulunmalı")
	assert(not is_finite(panel.call("get_row_center", 43).x), "olmayan peer için Vector2.INF dönmeli")
	panel.call("set_collapsed", true) ## telefonda kapalı panel: satır görünmez -> konum yok, efekt güvenle atlanır
	assert(not is_finite(panel.call("get_row_center", 42).x), "kapalı panelde konum verilmemeli")
	panel.queue_free()
	ally.queue_free()


# ------------------------------------------------------------------ elit sandık = epik eşya

func test_item_pool_normal_is_parts_elite_is_epic() -> void:
	var parts: Array = ChestMenuScript.item_pool(false, 1)
	var epics: Array = ChestMenuScript.item_pool(true, 1)
	assert(not parts.is_empty() and not epics.is_empty(), "iki havuz da dolu olmalı")
	for k in parts:
		assert(Items.kademe(str(k)) == Items.KADEME_PARCA, "normal sandık sadece parça vermeli: %s" % k)
	for k in epics:
		assert(Items.kademe(str(k)) == Items.KADEME_EPIK, "elit sandık sadece epik vermeli: %s" % k)
	## Efsanevi hiçbir sandıktan çıkmaz; destekçi-özel eşya destekçi olmayan karaktere çıkmaz.
	for k in Items.KEYS:
		if Items.kademe(str(k)) == Items.KADEME_EFSANEVI:
			assert(not epics.has(k) and not parts.has(k), "efsanevi sandıktan çıkmamalı: %s" % k)
	for char_id in [1, 2, 10]:
		for k in ChestMenuScript.item_pool(true, char_id):
			assert(not Items.is_support_only(str(k)) or Items.is_ally_support_char(char_id), "destekçi eşya yanlış karaktere çıktı: %s" % k)


func test_elite_chest_menu_shows_epic_card_and_gives_item() -> void:
	var saved_gold: Dictionary = GameManager.pending_chest_gold.duplicate(true)
	GameManager.pending_chest_gold = {"normal": [111], "elite": [222]}
	var menu = (load("res://scenes/chest_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	var player := Node2D.new()
	player.set_script(_script("""
extends Node2D
var got: Array = []
func get_max_item_slots() -> int:
	return 3
func acquire_item(key: String, _plan: Dictionary = {}, _paid: int = 0) -> bool:
	got.append(key)
	return true
"""))
	add_child(player)
	menu.setup(player, 0, true)
	assert(menu.title_label.text == "ELİT SANDIK", "elit sandık başlığı: %s" % menu.title_label.text)
	assert(menu._is_elite and menu._reward_tier == menu.ELITE_CARD_TIER, "elit modda kart çerçevesi epik olmalı")
	assert(is_instance_valid(menu._chest_icon) and bool(menu._chest_icon.get("_elite")), "açılış animasyonu ELİT sandık sayfasıyla oynamalı")
	assert(menu._chest_gold == 222, "elit sandık kendi altın kuyruğunu çekmeli (normal kuyruğa dokunmaz): %d" % menu._chest_gold)
	assert(GameManager.pending_chest_gold["normal"] == [111], "normal altın kuyruğu korunmalı")
	menu._chest_gold_released = true ## altın efekti bu testin konusu değil
	var column: Control = menu._build_card({"type": "item", "key": "kemik_kolye"})
	menu.cards_container.add_child(column)
	var ribbon_ok: bool = false
	for l in _labels(column):
		if l.text == "Epik":
			ribbon_ok = true
	assert(ribbon_ok, "kartın kurdelesinde 'Epik' yazmalı")
	assert(int(column.get_child(0).get_meta("reward_tier", 0)) == 3, "kart çerçevesi epik (tier 3) olmalı")
	var closed: Array = [false]
	menu.closed.connect(func() -> void: closed[0] = true)
	var al: Button = column.get_meta("al_button")
	assert(not al.disabled and al.text == "AL", "slot boşken AL açık olmalı")
	menu._on_al_pressed({"type": "item", "key": "kemik_kolye"}, 600)
	assert(player.get("got") == ["kemik_kolye"], "AL epik eşyayı oyuncuya vermeli: %s" % str(player.get("got")))
	assert(closed[0], "AL sonrası menü kapanmalı")
	GameManager.pending_chest_gold = saved_gold
	player.free()


func test_normal_chest_menu_still_gives_parts_only() -> void:
	var menu = (load("res://scenes/chest_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	var player := Node2D.new()
	player.set_script(_script("""
extends Node2D
func get_max_item_slots() -> int:
	return 2
"""))
	add_child(player)
	menu.setup(player, 2)
	assert(not menu._is_elite and menu._reward_tier == 1, "normal sandık elit olmamalı, çerçeve Tier 1")
	assert(is_instance_valid(menu._chest_icon) and not bool(menu._chest_icon.get("_elite")), "normal sandık normal sayfayla oynamalı")
	assert(menu.title_label.text == "KADEME V-VI SANDIK", "normal sandık başlığı kademeye bağlı: %s" % menu.title_label.text)
	menu.free()
	player.free()


# ------------------------------------------------------------------ yardımcılar

func _script(source: String) -> GDScript:
	var s := GDScript.new()
	s.source_code = source
	s.reload()
	return s


func _labels(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append(n)
	for c in n.get_children():
		out.append_array(_labels(c))
	return out


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await get_tree().process_frame
