extends Node

## Bildirim levhaları (scripts/game_notice.gd, "A Ahşap Levha") + oyuncular bekleniyor ekranı (scripts/wait_overlay.gd,
## "B Ateş Işığı"), madde 264: boyut/sarma, geri sayım yeri, kademe kuru kafaları, görev ödülü altın kuyusu, bekleme satırları.
## Madde 404: oyunda KÜÇÜK LEVHA (GameNotice.set_compact(true)) - test_compact_*; eski büyük görünüş testleri compact = false ile koşar.

const GameNotice: GDScript = preload("res://scripts/game_notice.gd")
const WaitOverlay: GDScript = preload("res://scripts/wait_overlay.gd")
const TierDisplay: GDScript = preload("res://scripts/tier_display.gd")


func test_toast_wraps_long_title_instead_of_cutting() -> void:
	GameNotice.set_compact(false)
	var short: Control = GameNotice.toast("info", "Kerem oyundan ayrıldı")
	var long: Control = GameNotice.toast("info", "Yeniden başlatma onaylanmadı (süre doldu). Oylama yeniden açılabilir.")
	assert((long.get("_title_lines") as PackedStringArray).size() >= 2, "uzun başlık satırlara sarılmalı")
	assert(long.size.y >= short.size.y, "sarılan başlık levhayı kısaltmamalı (2 satır simge kuyusuna sığar)")
	assert(short.size.x == long.size.x and short.size.x == GameNotice.TOAST_W, "PC genişliği sabit")
	var joined: String = " ".join(long.get("_title_lines"))
	assert(not joined.ends_with("..."), "başlık kesilmemeli: %s" % joined)
	short.free()
	long.free()
	GameNotice.set_compact(true)


func test_countdown_reserves_room_on_title_line() -> void:
	GameNotice.set_compact(false)
	var title := "Alanı Güvenceye Al ve Kristalleri Topla"
	var plain: Control = GameNotice.toast("warn", title, "Görev yakında başlıyor.")
	var timed: Control = GameNotice.toast("warn", title, "Görev yakında başlıyor.")
	timed.call("set_countdown", 30.0)
	var font: Font = GameNotice.FONT
	var room: float = GameNotice.TOAST_W - 16.0 - (GameNotice.PAD + GameNotice.WELL + 14.0) - (font.get_string_size("99 sn", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 12.0)
	for l in (timed.get("_title_lines") as PackedStringArray):
		assert(font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x <= room + 0.5, "sayaçlı başlık satırı sayaca taşmamalı: %s" % l)
	assert(timed.size.y >= plain.size.y)
	plain.free()
	timed.free()
	GameNotice.set_compact(true)


func test_phone_toast_is_wider_with_bigger_text() -> void:
	GameNotice.set_compact(false)
	var t: Control = GameNotice.toast("merchant", "Seyyar Satıcı geldi", "Konumu haritada işaretlendi.", 4.0, true)
	assert(t.size.x == GameNotice.TOAST_W_PHONE and int(t.get("fs")) == 32, "telefonda geniş + 32 px")
	assert(t.custom_minimum_size == t.size, "yerleşim alt sınırı = boyut (offset değişince küçülmesin)")
	t.free()
	GameNotice.set_compact(true)


func test_tier_banner_has_skulls_inside_plaque() -> void:
	GameNotice.set_compact(false)
	var b: Control = GameNotice.banner("tier", TierDisplay.title(4), "", 4.0, 4)
	var row: Control = null
	for c in b.get_children():
		if c.get_script() == TierDisplay:
			row = c
	assert(row != null and int(row.call("get_tier")) == 4, "kademe kuru kafa satırı")
	assert(row.position.y >= GameNotice.PLAQUE_TOP and row.get_rect().end.y <= b.size.y, "kafalar levhanın içinde")
	var plain: Control = GameNotice.banner("ok", "SONSUZ MOD BAŞLADI", "Her kat yaratıklar güçlenir.", 5.0)
	assert(plain.get_child_count() == 0, "kademesiz duyuruda kafa satırı yok")
	b.free()
	plain.free()
	GameNotice.set_compact(true)


func test_mission_complete_coin_well_only_with_gold() -> void:
	GameNotice.set_compact(false)
	var with_gold: Control = GameNotice.complete("Bayrağı Ele Geçir", 120, 5, 3.6)
	var c: Vector2 = with_gold.call("coin_center")
	assert(Rect2(Vector2.ZERO, with_gold.size).has_point(c), "altın kuyusu levhanın içinde: %s" % str(c))
	assert(c.x < with_gold.size.x * 0.5, "altın kuyusu soldan ilk (parçacık sağda)")
	var no_gold: Control = GameNotice.complete("Bayrağı Ele Geçir", 0, 5, 3.6)
	assert(no_gold.call("coin_center").x < 0.0, "bölgede değilse altın kuyusu yok")
	with_gold.free()
	no_gold.free()
	GameNotice.set_compact(true)


# ------------------------------------------------------------ küçük levha (madde 404)
func _row_of(n: Control) -> Control:
	for c in n.get_children():
		if c.get_script() == TierDisplay:
			return c
	return null


func test_compact_toast_is_one_short_line() -> void:
	assert(GameNotice.compact, "oyunda küçük levha açık")
	var n: Control = GameNotice.toast("start", "Topla BAŞLADI", "Haritanın dört bir yanına saçılmış kristallerden yeterince topla.")
	GameNotice.set_compact(false)
	var old: Control = GameNotice.toast("start", "Topla BAŞLADI", "Haritanın dört bir yanına saçılmış kristallerden yeterince topla.")
	GameNotice.set_compact(true)
	assert(n.size.y == 12.0 * 3.0 + 2.0 * GameNotice.C_PAD_Y, "tek satır (simge 12 hücre x 3 px): %s" % str(n.size))
	assert(n.size.y <= old.size.y * 0.6 and n.size.x < old.size.x, "eskisinin yarısı kadar: %s / %s" % [str(n.size), str(old.size)])
	assert(str(n.get("_c_title")) == "Topla BAŞLADI", "başlık aynen")
	assert(n.custom_minimum_size == n.size)
	n.free()
	old.free()


func test_compact_long_title_is_cut_to_one_line() -> void:
	var n: Control = GameNotice.toast("info", "Yeniden başlatma onaylanmadı (süre doldu). Oylama yeniden açılabilir ve herkes yeniden seçebilir.")
	assert(n.size.x <= GameNotice.C_MAX_W, "en çok %d px: %s" % [GameNotice.C_MAX_W, str(n.size)])
	assert(str(n.get("_c_title")).ends_with("..."), "sığmayan başlık kısalır")
	n.free()


func test_compact_countdown_stays_on_the_line() -> void:
	var title := "Alanı Güvenceye Al ve Kristalleri Topla Uzun Ad"
	var n: Control = GameNotice.toast("warn", title)
	var w0: float = n.size.x
	n.call("set_countdown", 60.0)
	var font: Font = GameNotice.FONT
	var text_end: float = float(n.get("_c_text_x")) + font.get_string_size(str(n.get("_c_title")), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var cd_left: float = n.size.x - GameNotice.C_PAD_X - font.get_string_size("99 sn", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	assert(text_end <= cd_left, "başlık sayaca binmez")
	assert(n.size.x <= GameNotice.C_MAX_W and n.size.x >= w0, "sayaç yer açar ama azami genişliği aşmaz")
	n.free()


func test_compact_tier_banner_skulls_after_title() -> void:
	var b: Control = GameNotice.banner("tier", TierDisplay.title(7), "", 4.0, 7)
	var row: Control = _row_of(b)
	assert(row != null and int(row.call("get_tier")) == 7, "kademe kuru kafa satırı")
	assert(Rect2(Vector2.ZERO, b.size).encloses(Rect2(row.position, row.custom_minimum_size)), "kafalar levhanın içinde")
	assert(float(b.get("_c_icon_w")) == 0.0, "kafalı satırda ayrıca simge yok")
	var font: Font = GameNotice.FONT
	assert(row.position.x >= float(b.get("_c_text_x")) + font.get_string_size("KADEME VII", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x, "kafalar başlığın sağında")
	assert(b.size.y == 12.0 * 3.0 + 2.0 * GameNotice.C_PAD_Y, "tek satır")
	b.call("set_countdown", 5.0) ## yeniden yerleşim kafa satırını çoğaltmaz
	var rows: int = 0
	for c in b.get_children():
		rows += 1 if c.get_script() == TierDisplay else 0
	assert(rows == 1, "tek kafa satırı")
	b.free()


func test_compact_mission_complete_line() -> void:
	var n: Control = GameNotice.complete("Bayrağı Ele Geçir", 120, 5, 3.0)
	assert(str(n.get("_c_title")) == "Bayrağı Ele Geçir TAMAMLANDI", str(n.get("_c_title")))
	var c: Vector2 = n.call("coin_center")
	assert(Rect2(Vector2.ZERO, n.size).has_point(c), "altın simgesi levhanın içinde: %s" % str(c))
	var rewards: Array = n.get("_c_rewards")
	assert(rewards.size() == 2 and bool(rewards[0]["gold"]) and float(rewards[0]["x"]) < float(rewards[1]["x"]), "önce altın sonra parçacık")
	assert(n.size.y == 12.0 * 3.0 + 2.0 * GameNotice.C_PAD_Y and n.size.x <= GameNotice.C_MAX_W, str(n.size))
	var no_gold: Control = GameNotice.complete("Bayrağı Ele Geçir", 0, 5, 3.0)
	assert(no_gold.call("coin_center").x < 0.0, "bölgede değilse altın yok")
	n.free()
	no_gold.free()


func test_compact_phone_uses_bigger_pixels() -> void:
	var t: Control = GameNotice.toast("merchant", "Seyyar Satıcı geldi", "Konumu haritada işaretlendi.", 4.0, true)
	assert(int(t.get("fs")) == 32 and t.size.y == 12.0 * 4.0 + 2.0 * GameNotice.C_PAD_Y, "telefonda 32 px yazı / 4 px simge: %s" % str(t.size))
	assert(t.size.x <= GameNotice.C_MAX_W_PHONE)
	t.free()


func test_compact_hold_is_short_except_system_and_full_countdowns() -> void:
	var m: Node = (load("res://scripts/main.gd") as GDScript).new() ## ağaca eklenmez
	assert(is_equal_approx(float(m.call("_notice_hold", "warn", 9.0, 60.0)), 3.0), "görev uyarısı kısa (sayaç görev satırında)")
	assert(is_equal_approx(float(m.call("_notice_hold", "fail", 5.0)), 3.0), "duyuru kısa")
	assert(is_equal_approx(float(m.call("_notice_hold", "info", 14.0)), 14.0), "host devri bağlanma bitene kadar kalır")
	assert(is_equal_approx(float(m.call("_notice_hold", "warn", 30.0, 30.0)), 30.0), "sonuna kadar geri sayan (ev açılışı) kalır")
	m.free()


func test_wait_overlay_rows_me_first_and_busy_flags() -> void:
	var lobby_backup: Dictionary = NetworkManager.lobby_players.duplicate(true)
	var busy_backup: Dictionary = NetworkManager.level_up_busy_peers.duplicate()
	var timer_backup: bool = NetworkManager.level_up_timer_active
	var cd_backup: float = NetworkManager.level_up_countdown
	NetworkManager.lobby_players.clear()
	NetworkManager.lobby_players[1003] = {"name": "Deniz", "char_id": 15}
	NetworkManager.lobby_players[1] = {"name": "Ben", "char_id": 2}
	NetworkManager.lobby_players[1001] = {"name": "Mira", "char_id": 10}
	NetworkManager.level_up_busy_peers.clear()
	NetworkManager.level_up_busy_peers[1003] = true
	NetworkManager.level_up_timer_active = true
	NetworkManager.level_up_countdown = 17.0
	var w: CanvasLayer = WaitOverlay.call("open", self, "level_up")
	var rows: Array = w.get("_rows")
	assert(rows.size() == 3, "lobideki herkes")
	assert(rows[0]["name"] == "Sen", "yerel oyuncu ilk ve 'Sen'")
	assert(rows[1]["name"] == "Mira" and rows[1]["ready"], "peer sırası, Mira hazır")
	assert(rows[2]["name"] == "Deniz" and not rows[2]["ready"], "Deniz seçiyor")
	assert(rows[1]["tex"] != null, "portre karakterden")
	assert(absf(float(w.get("_remaining")) - 17.0) < 0.01, "sayaç NetworkManager'dan")
	NetworkManager.level_up_timer_active = false
	w.call("_poll")
	assert(float(w.get("_remaining")) < 0.0, "sayaç kapalıysa sayı gösterilmez")
	w.free()
	NetworkManager.lobby_players = lobby_backup
	NetworkManager.level_up_busy_peers = busy_backup
	NetworkManager.level_up_timer_active = timer_backup
	NetworkManager.level_up_countdown = cd_backup
