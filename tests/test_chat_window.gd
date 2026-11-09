extends Node

## Madde 499: masaüstü sohbet penceresi (chat_window.gd) + emoji jetonları (chat_emoji.gd) + balon (chat_bubble.gd).

const ChatEmoji: GDScript = preload("res://scripts/chat_emoji.gd")
const ChatWindow: GDScript = preload("res://scripts/chat_window.gd")
const ChatBubble: GDScript = preload("res://scripts/chat_bubble.gd")
const F: Font = preload("res://assets/fonts/m5x7.ttf")


func test_every_emoji_has_art() -> void:
	for key: String in ChatEmoji.LIST:
		var t: Texture2D = ChatEmoji.tex(key)
		assert(t != null, "emoji dokusu yok: %s" % key)
		assert(t.get_size() == Vector2(ChatEmoji.SIZE, ChatEmoji.SIZE), "emoji 9x9 olmali: %s" % key)


func test_segments_split_known_tokens_only() -> void:
	var seg: Array = ChatEmoji.segments(":gul: selam :yok: :kalp:")
	assert(seg.size() == 3, str(seg))
	assert(seg[0] == ["e", "gul"])
	assert(seg[1] == ["t", " selam :yok: "], "bilinmeyen jeton duz yazi kalmali: %s" % str(seg[1]))
	assert(seg[2] == ["e", "kalp"])


func test_shortcuts_only_as_separate_words() -> void:
	assert(ChatEmoji.normalize(":) naber <3") == ":gul: naber :kalp:")
	assert(ChatEmoji.normalize("saat:D oldu") == "saat:D oldu", "sozcuk ici kisaltma dokunulmamali")


func test_wrap_keeps_tokens_whole_and_fits() -> void:
	var text := "bu tarafa gelin :yardim: cok yaratik var :kafa: :kafa: :ates: hemen kosun arkadaslar"
	var lines: PackedStringArray = ChatEmoji.wrap(text, F, 32, ChatWindow.MAX_TEXT, 3.0, 6)
	assert(lines.size() >= 2)
	var joined: String = " ".join(lines)
	assert(joined == text, "metin bozulmamali: '%s'" % joined)
	for l: String in lines:
		assert(ChatEmoji.measure(l, F, 32, 3.0) <= ChatWindow.MAX_TEXT + 0.01, "satir tasti: %s" % l)


func test_window_shows_last_four_idle_and_six_typing() -> void:
	var w: Control = ChatWindow.new()
	add_child(w)
	for i in 8:
		w.call("add_message", "Oyuncu%d" % i, "mesaj %d :gul:" % i, 2, Color.WHITE)
	assert((w.call("visible_entries") as Array).size() == ChatWindow.SHOW_IDLE)
	w.call("set_typing", true)
	var vis: Array = w.call("visible_entries")
	assert(vis.size() == ChatWindow.SHOW_TYPING)
	assert(str(vis[-1]["name"]) == "Oyuncu7", "en yeni en altta")
	var h: float = 0.0
	for e: Dictionary in vis:
		h += ChatWindow.block_h(e)
		assert(ChatWindow.box_w(e) <= ChatWindow.W - ChatWindow.BOX_X + 0.01, "kutu pencereden tasti")
	assert(h + (vis.size() - 1) * ChatWindow.GAP <= ChatWindow.BLOCKS_MAX_H + 0.01)
	w.queue_free()


func test_gift_line_names_both_players() -> void:
	var w: Control = ChatWindow.new()
	add_child(w)
	w.call("add_gift", "Kerem", Color.RED, "Mira", Color.BLUE, 50)
	var e: Dictionary = (w.get("entries") as Array)[-1]
	assert(e["kind"] == "gift" and e["from"] == "Kerem" and e["to"] == "Mira" and int(e["amount"]) == 50)
	assert(str((e["lines"] as PackedStringArray)[0]).contains("50"))
	w.queue_free()


func test_emoji_picker_inserts_token_at_caret() -> void:
	var w: Control = ChatWindow.new()
	add_child(w)
	var le := LineEdit.new()
	add_child(le)
	w.call("attach_input", le)
	w.call("set_typing", true)
	le.text = "selam"
	le.caret_column = 5
	w.call("_pick_emoji", "kalp")
	assert(le.text == "selam :kalp: ", "'%s'" % le.text)
	assert(not bool(w.call("is_picker_open")))
	w.queue_free()
	le.queue_free()


func test_bubble_with_emoji_sizes_box() -> void:
	var b: Node2D = ChatBubble.new()
	add_child(b)
	b.call("show_message", "geliyorum :begen:")
	var box: Rect2 = b.get("_box")
	assert(box.size.x > 0.0 and box.end.y <= ChatBubble.BUBBLE_BOTTOM_Y - ChatBubble.TAIL_H + 0.01)
	assert((b.get("_lines") as PackedStringArray)[0] == "geliyorum :begen:")
	b.queue_free()
