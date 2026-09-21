extends Node

## Chat baloncuğu satır kaydırma (kullanıcı isteği 2026-09-21: baloncuk butona benzesin + yazı büyüsün). Kutu boyutu artık
## fontun gerçek ölçülerinden hesaplanıyor - satırlar sınırı aşmamalı, karakter kaybolmamalı, aşırı uzun metin kısaltılmalı.

const ChatBubble: GDScript = preload("res://scripts/chat_bubble.gd")


func _font() -> Font:
	return ThemeDB.fallback_font


func _w(s: String) -> float:
	return _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, ChatBubble.FONT_SIZE).x


func test_short_text_stays_one_line() -> void:
	var out: String = ChatBubble.wrap_text("Merhaba!", _font(), ChatBubble.FONT_SIZE, ChatBubble.MAX_TEXT_WIDTH)
	assert(out == "Merhaba!", "kisa metin degismemeli: '%s'" % out)


func test_long_text_wraps_within_width_and_loses_nothing() -> void:
	var text := "Bu tarafta çok yaratık var, dikkat edin arkadaşlar, geliyorlar hemen yardıma gelin!"
	var out: String = ChatBubble.wrap_text(text, _font(), ChatBubble.FONT_SIZE, ChatBubble.MAX_TEXT_WIDTH)
	var lines: PackedStringArray = out.split("\n")
	assert(lines.size() >= 2, "uzun metin birden cok satira bolunmeli")
	for l in lines:
		assert(_w(l) <= ChatBubble.MAX_TEXT_WIDTH + 0.01, "satir cok genis: '%s' %s" % [l, _w(l)])
	assert(out.replace("\n", " ") == text, "metin bozulmamali")


func test_giant_word_is_split_by_characters() -> void:
	var word := "a".repeat(120)
	var out: String = ChatBubble.wrap_text(word, _font(), ChatBubble.FONT_SIZE, ChatBubble.MAX_TEXT_WIDTH)
	var lines: PackedStringArray = out.split("\n")
	assert(lines.size() >= 2)
	for l in lines:
		assert(_w(l) <= ChatBubble.MAX_TEXT_WIDTH + 0.01)
	## kisaltma yoksa tum karakterler korunmus olmali
	if not out.ends_with("..."):
		assert(out.replace("\n", "") == word)


func test_over_long_message_is_truncated_to_max_lines() -> void:
	var text := "kelime ".repeat(200).strip_edges()
	var out: String = ChatBubble.wrap_text(text, _font(), ChatBubble.FONT_SIZE, ChatBubble.MAX_TEXT_WIDTH)
	var lines: PackedStringArray = out.split("\n")
	assert(lines.size() == ChatBubble.MAX_LINES, "satir siniri: %d" % lines.size())
	assert(out.ends_with("..."), "kisaltilan metin ... ile bitmeli")


func test_empty_and_whitespace_are_safe() -> void:
	assert(ChatBubble.wrap_text("", _font(), ChatBubble.FONT_SIZE, ChatBubble.MAX_TEXT_WIDTH) == "")
	var out: String = ChatBubble.wrap_text("   ", _font(), ChatBubble.FONT_SIZE, ChatBubble.MAX_TEXT_WIDTH)
	assert(out.strip_edges() == "")
