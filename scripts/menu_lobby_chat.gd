extends VBoxContainer

## Lobi sohbeti kutusu (oda lobisi + karakter seçimi ORTAK; 2026-10-11). Oyun içi sohbetle AYNI RPC
## (NetworkManager.broadcast_chat_message, "call_local" - gönderen kendi mesajını da sinyalden alır). Geçmiş
## NetworkManager.lobby_chat_log'da: oda lobisinden karakter seçimine geçince mesajlar kaybolmaz.

const MAX_LINES := 50

var _fs_body: int = MenuKit.FS_BODY
var _fs_small: int = MenuKit.FS_SMALL
var _mobile: bool = false
var _scroll: ScrollContainer = null
var _log: VBoxContainer = null
var _input: LineEdit = null


func setup(sz: Dictionary, mobile: bool, log_min_h: float, expand: bool = false) -> void:
	_fs_body = int(sz["fs_body"])
	_fs_small = int(sz.get("chat_fs", sz["fs_small"]))
	_mobile = mobile
	add_theme_constant_override("separation", 6)
	add_child(MenuKit.make_section_header("Sohbet", _fs_body))
	var log_box := MenuKit.make_panel("inset")
	if expand:
		log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(log_box)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, log_min_h)
	log_box.add_child(_scroll)
	_log = VBoxContainer.new()
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_constant_override("separation", 2)
	_scroll.add_child(_log)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_input = LineEdit.new()
	_input.placeholder_text = "Mesaj yaz..."
	_input.max_length = 200
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.custom_minimum_size = Vector2(0, float(sz.get("chat_input_h", sz["ctl_h"])))
	_input.add_theme_font_size_override("font_size", int(sz.get("chat_input_fs", _fs_body)))
	_input.text_submitted.connect(func(_t: String) -> void: _send())
	row.add_child(_input)
	var send := MenuKit.make_button("Gönder", "tan", _fs_body, float(sz["ctl_h"]))
	send.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	send.pressed.connect(_send)
	row.add_child(send)
	for e in NetworkManager.lobby_chat_log:
		_add_line(str(e["name"]), str(e["text"]))
	NetworkManager.chat_message_received.connect(_on_message)
	_scroll_to_end.call_deferred()


func _exit_tree() -> void:
	if NetworkManager.chat_message_received.is_connected(_on_message):
		NetworkManager.chat_message_received.disconnect(_on_message)


func _send() -> void:
	var text: String = _input.text.strip_edges()
	_input.text = ""
	if text.is_empty() or not NetworkManager.is_multiplayer_active or not multiplayer.has_multiplayer_peer():
		return
	NetworkManager.broadcast_chat_message.rpc(multiplayer.get_unique_id(), NetworkManager.local_player_name, text)
	if not _mobile:
		_input.grab_focus.call_deferred() ## arka arkaya yazabilsin (telefonda klavye kendiliğinden kapanır)


func _on_message(_peer_id: int, player_name: String, text: String) -> void:
	_add_line(player_name, text)
	_scroll_to_end()


func _add_line(player_name: String, text: String) -> void:
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("normal_font_size", _fs_small)
	line.add_theme_font_size_override("bold_font_size", _fs_small)
	line.add_theme_color_override("default_color", MenuKit.C_TEXT)
	line.text = "[color=#%s]%s:[/color] %s" % [MenuKit.C_ACCENT.to_html(false), player_name.xml_escape(), text.xml_escape()]
	_log.add_child(line)
	while _log.get_child_count() > MAX_LINES:
		var old: Node = _log.get_child(0)
		_log.remove_child(old)
		old.queue_free()


func _scroll_to_end() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
