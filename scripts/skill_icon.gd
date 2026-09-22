extends Control

const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")

@export var skill_id: int = 1
## Verilirse vektörel çizim yerine bu doku kullanılır (gerçek sanat eseri
## ikonlar için - bkz. Öykü'nün skill_icon/skill2_icon alanları,
## characters.gd). Boşsa (null) eskisi gibi skill_id'ye göre elle çizilen
## vektör ikon kullanılmaya devam eder - diğer karakterler bundan etkilenmez.
@export var custom_texture: Texture2D = null

var progress: float = 1.0
var is_active: bool = false
## Yetenek bekleme (cooldown) süresindeyken kalan saniye (bkz. player.gd
## skill_timer/skill2_timer) - ikonun üzerindeki sayısal geri sayımı
## (Cooldown Label) beslemek için kullanılır.
var remaining_seconds: float = 0.0
## Yetenek AKTİFKEN kalan sürenin oranı (1.0 = yeni aktifleşti, 0.0'a doğru
## azalır) - bkz. player.gd get_skill_active_fraction()/get_skill2_active_
## fraction(). Aktiflik çerçevesinin kenarlarını buna göre daraltmak için.
var active_fraction: float = 0.0
## bkz. _draw() içindeki beyaz nabız örtüsü - sadece is_active iken ilerler.
var _pulse_time: float = 0.0

## Büyücü Kız'ın TEMEL yeteneği artık 4 varyasyonlu ve varyasyon ULTİ ile
## değiştirilebiliyor (bkz. player.gd BUYUCU_VARIATION_*/get_buyucu_
## variation_name/desc) - characters.gd'deki statik "skill2_name"/
## "skill2_desc" tek bir varyasyonu yazamaz. Boş değilse (hud.gd _process
## tarafından her karede güncellenir) bu ikinin ÜZERİNE geçer; diğer tüm
## karakterlerde boş kalır ve eski davranış (doğrudan characters.gd'den
## okuma) hiç değişmez.
var name_override: String = ""
var desc_override: String = ""

var tooltip_panel: PanelContainer = null

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_layout_stack_badge)
	_layout_stack_badge()

func _process(delta: float) -> void:
	if tooltip_panel and is_instance_valid(tooltip_panel) and tooltip_panel.visible:
		_update_tooltip_position()
	if is_active:
		_pulse_time += delta

func _exit_tree() -> void:
	if tooltip_panel and is_instance_valid(tooltip_panel):
		tooltip_panel.queue_free()
		tooltip_panel = null

func _on_mouse_entered() -> void:
	if tooltip_panel and is_instance_valid(tooltip_panel):
		tooltip_panel.queue_free()
	
	var hud_layer: Node = get_parent().get_parent()
	if not hud_layer:
		return
		
	var char_id: int = GameManager.selected_char_id
	var def: Dictionary = Characters.get_def(char_id)
	var player: Node = null
	if is_inside_tree() and get_tree() != null:
		player = get_tree().get_first_node_in_group("player")
	
	var title: String = ""
	var desc: String = ""
	var cd_text: String = ""
	var keybind_text: String = ""
	
	if name == "PassiveIcon":
		var passive_name_str: String = "Pasif Yetenek"
		if def.has("passive_name"):
			passive_name_str = def["passive_name"] as String
		title = (def.get("name", "") as String) + " - " + passive_name_str
		desc = def.get("passive", "Pasif yetenek açıklaması bulunmuyor.") as String
		cd_text = "Bekleme Süresi: Yok"
		keybind_text = "PASİF"
	elif name == "SkillIcon":
		title = def.get("skill_name", "Aktif Yetenek") as String
		desc = def.get("skill_desc", "Aktif yetenek açıklaması bulunmuyor.") as String
		keybind_text = "Q"
		
		var base_cd: float = 20.0
		var current_cd: float = 20.0
		var skill_id_val: int = def.get("skill", 1) as int
		
		if player and is_instance_valid(player) and "SKILL_TIMING" in player:
			var timing: Dictionary = player.SKILL_TIMING.get(skill_id_val, {"cooldown": 20.0}) as Dictionary
			base_cd = timing["cooldown"] as float
			current_cd = player._skill_cooldown as float
		else:
			base_cd = 20.0
			current_cd = base_cd
			
		if current_cd != base_cd:
			cd_text = "Bekleme Süresi: %.1fs [color=#88ff88](Base: %.1fs)[/color]" % [current_cd, base_cd]
		else:
			cd_text = "Bekleme Süresi: %.1fs" % base_cd
		## DÜZELTME (kullanıcı bildirimi: "bekleme süresinde azalma skillerin
		## bekleme süresini azaltıyor fakat alttaki skill göstergesinde bekleme
		## sürelerinin azaldığı görünmüyor açıklamalarda bekleme süresi aynı
		## görünüyor") - characters.gd'nin statik "skill_desc" metninin içine
		## gömülü "(Xsn bekleme)" sayısı artık yukarıda zaten hesaplanmış GERÇEK
		## current_cd ile değiştiriliyor, cd_text ile TUTARLI olsun diye.
		desc = _apply_live_cooldown_to_desc(desc, current_cd)
	elif name == "SpiritIcon":
		## Ruhani Yetenek (F, bkz. spiritual_skills.gd): karakterden bağımsız, kendi tanımından okunur. Bekleme süresi
		## "Bekleme Süresi Azaltma" statından etkilenmez (kullanıcı isteği) - bu yüzden "Base" karşılaştırması yok.
		var spirit_def: Dictionary = SpiritualSkillsScript.get_def(GameManager.selected_spiritual)
		title = "Ruhani Yetenek - %s" % str(spirit_def.get("name", ""))
		desc = str(spirit_def.get("desc", ""))
		var spirit_cd: float = float(spirit_def.get("cooldown", 0.0))
		if bool(spirit_def.get("active", false)):
			keybind_text = GameManager.get_action_key_label("skill4")
			cd_text = "Bekleme Süresi: %.0fs (bekleme süresi azaltmadan etkilenmez)" % spirit_cd
		else:
			keybind_text = "PASİF"
			cd_text = "Bekleme Süresi: Yok"
	elif name == "Skill3Icon":
		## DÜZELTME (kullanıcı bildirimi: "Tüm ultilerin yetenek açıklamalarında
		## ... sorun var, ulti açıklamaları yanlış gösteriliyor") - R ikonu
		## (Skill3Icon) için bu zincirde HİÇ dal yoktu, aşağıdaki genel "else"
		## (TEMEL/E) dalına düşüp E yeteneğinin adını/açıklamasını/bekleme
		## süresini ve "[E]" tuş etiketini gösteriyordu. Artık R'nin kendi
		## skill3_* alanları ve SKILL3_TIMING kullanılıyor.
		title = def.get("skill3_name", "3. Yetenek") as String
		if not name_override.is_empty():
			title = name_override
		desc = def.get("skill3_desc", "3. yetenek açıklaması bulunmuyor.") as String
		if not desc_override.is_empty():
			desc = desc_override
		keybind_text = "R"

		var base_cd3: float = 15.0
		var current_cd3: float = 15.0
		var skill3_id_val: int = def.get("skill3", 0) as int
		if player and is_instance_valid(player) and player.has_method("get_skill3_id"):
			skill3_id_val = player.get_skill3_id()
		if player and is_instance_valid(player) and "SKILL3_TIMING" in player:
			## Büyücü Kız'ın R varyasyonları (Hortum/Meteor) SKILL3_TIMING'de değil,
			## E ile paylaşılan SKILL2_TIMING kimlik uzayında (bkz. player.gd
			## BUYUCU_VARIATION_SKILL2_IDS) - orada da aranır.
			var timing3: Dictionary = player.SKILL3_TIMING.get(skill3_id_val, player.SKILL2_TIMING.get(skill3_id_val, {"cooldown": 15.0})) as Dictionary
			base_cd3 = timing3["cooldown"] as float
			var cdr3: float = float(player.cooldown_reduction_percent) if "cooldown_reduction_percent" in player else 0.0
			current_cd3 = base_cd3 * (1.0 - cdr3)
		else:
			current_cd3 = base_cd3
		if base_cd3 <= 0.0:
			## Bekleme süresi olmayan TOGGLE'lar (Vampir Çocuk R'si) - "0.0s" yerine "Yok".
			cd_text = "Bekleme Süresi: Yok"
		elif current_cd3 != base_cd3:
			cd_text = "Bekleme Süresi: %.1fs [color=#88ff88](Base: %.1fs)[/color]" % [current_cd3, base_cd3]
		else:
			cd_text = "Bekleme Süresi: %.1fs" % base_cd3
		desc = _apply_live_cooldown_to_desc(desc, current_cd3)
	else:
		## DÜZELTME (Büyücü Kız'ın 4 varyasyonlu TEMEL yeteneği): name_override/
		## desc_override doluysa (hud.gd _process, sadece Büyücü Kız seçiliyken)
		## characters.gd'nin statik metni yerine O ANKİ varyasyonun gerçek
		## adı/açıklaması gösterilir - bkz. player.gd get_buyucu_variation_
		## name/desc().
		title = def.get("skill2_name", "Temel Yetenek") as String
		if not name_override.is_empty():
			title = name_override
		desc = def.get("skill2_desc", "Temel yetenek açıklaması bulunmuyor.") as String
		if not desc_override.is_empty():
			desc = desc_override
		keybind_text = "E"

		var base_cd: float = 15.0
		var current_cd: float = 15.0
		## DÜZELTME: eskiden HER ZAMAN characters.gd'nin statik "skill2"
		## alanından okunuyordu - Büyücü Kız'da bu alan sadece BAŞLANGIÇ
		## varyasyonu (bkz. characters.gd), gerçek/güncel varyasyon kimliği
		## player.get_skill2_id()'nin dinamik override'ında. Diğer TÜM
		## karakterlerde get_skill2_id() zaten def.get("skill2",0) ile birebir
		## aynı değeri döndürdüğü için bu değişiklik onlar için zararsız.
		var skill2_id_val: int = def.get("skill2", 0) as int
		if player and is_instance_valid(player) and player.has_method("get_skill2_id"):
			skill2_id_val = player.get_skill2_id()

		if player and is_instance_valid(player) and "SKILL2_TIMING" in player:
			var timing: Dictionary = player.SKILL2_TIMING.get(skill2_id_val, {"cooldown": 15.0}) as Dictionary
			base_cd = timing["cooldown"] as float
			## DÜZELTME: player._skill2_cooldown Büyücü Kız için hiç
			## güncellenmiyor (standart skill2_state makinesini kullanmıyor,
			## bkz. player.gd _buyucu_try_activate_variation) - bekleme
			## süresi azaltma statını (cooldown_reduction_percent) doğrudan
			## temel süreye uygulayan bu formül TÜM karakterlerde doğru sonucu
			## verir ve Büyücü'ye özel bir dal gerektirmez.
			var cdr: float = float(player.cooldown_reduction_percent) if "cooldown_reduction_percent" in player else 0.0
			current_cd = base_cd * (1.0 - cdr)
		else:
			base_cd = 15.0
			current_cd = base_cd
			
		if current_cd != base_cd:
			cd_text = "Bekleme Süresi: %.1fs [color=#88ff88](Base: %.1fs)[/color]" % [current_cd, base_cd]
		else:
			cd_text = "Bekleme Süresi: %.1fs" % base_cd
		## DÜZELTME: bkz. yukarıdaki SkillIcon dalındaki AYNI düzeltme/yorum -
		## TEMEL yeteneğin açıklamasındaki gömülü bekleme metni de artık canlı.
		desc = _apply_live_cooldown_to_desc(desc, current_cd)

	# Build Tooltip UI
	## Kullanıcı isteği: "oyundaki skill göstergelerinin açıklamaları hiç
	## okunmuyor ... bazıları aşırı küçük" - bu tooltip'in metinleri (aşağıda)
	## oyunun geri kalanına göre çok küçük kalıyordu, büyütüldü; panel
	## genişliği de o kadar metne göre orantılı büyütüldü.
	tooltip_panel = PanelContainer.new()
	tooltip_panel.custom_minimum_size = Vector2(400, 0)
	
	# Apply stylebox
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.78, 0.63, 0.35, 1.0) # Gold border
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_right = 5
	sb.corner_radius_bottom_left = 5
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	tooltip_panel.add_theme_stylebox_override("panel", sb)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	tooltip_panel.add_child(vbox)
	
	# Header (Title + Keybind)
	var header: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header)
	
	## Kullanıcı isteği: "hepsini aynı boyuta getir" - başlık/tuş rozeti de
	## artık açıklama/bekleme metniyle (TOOLTIP_BODY_FONT_SIZE, aşağıda
	## tanımlanmadan önce burada da aynı sabit değer kullanılıyor) BİREBİR
	## aynı font boyutunda; aralarındaki ayrım artık sadece renk/büyük harf
	## ile yapılıyor, boyutla değil.
	const TOOLTIP_HEADER_FONT_SIZE := 17
	var lbl_title: Label = Label.new()
	lbl_title.text = title.to_upper()
	lbl_title.add_theme_font_size_override("font_size", TOOLTIP_HEADER_FONT_SIZE)
	lbl_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	header.add_child(lbl_title)
	
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var lbl_key: Label = Label.new()
	lbl_key.text = "[" + keybind_text + "]"
	lbl_key.add_theme_font_size_override("font_size", TOOLTIP_HEADER_FONT_SIZE)
	lbl_key.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header.add_child(lbl_key)
	
	# Divider
	var div: ColorRect = ColorRect.new()
	div.color = Color(0.3, 0.25, 0.15)
	div.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(div)
	
	# Cooldown
	## DÜZELTME (kullanıcı bildirimi: "yetenek açıklamaları penceresindeki
	## yazılar çok dengesiz, bazıları kocaman bazıları ufacık") - asıl neden:
	## bu RichTextLabel'larda sadece "normal_font_size" override ediliyordu.
	## _format_lol_style() ULTİ/TEMEL/PASİF gibi kelimeleri [b]...[/b] (kalın)
	## etiketiyle sarıyor, ve RichTextLabel'ın KALIN metni AYRI bir tema
	## anahtarından ("bold_font_size") boyut alıyor - bu hiç override
	## edilmediği için projenin genel varsayılan tema boyutuna (bkz.
	## assets/fonts/theme.tres default_font_size = 88!) düşüyordu. Sonuç:
	## aynı açıklama içinde normal kelimeler 16-17px, kalın kelimeler
	## (ULTİ/TEMEL/PASİF, sayılar SARILI DEĞİL ama [b] kullanan başka
	## kelimeler) aniden 88px oluyordu. Artık normal/bold/italics/bold_italics
	## HEPSİ AYNI boyuta sabitleniyor, tüm metin tutarlı tek bir boyutta.
	const TOOLTIP_BODY_FONT_SIZE := 17
	var lbl_cd: RichTextLabel = RichTextLabel.new()
	lbl_cd.bbcode_enabled = true
	lbl_cd.text = "[color=#55ccff]" + cd_text + "[/color]"
	lbl_cd.fit_content = true
	lbl_cd.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_cd.add_theme_font_size_override("normal_font_size", TOOLTIP_BODY_FONT_SIZE)
	lbl_cd.add_theme_font_size_override("bold_font_size", TOOLTIP_BODY_FONT_SIZE)
	lbl_cd.add_theme_font_size_override("italics_font_size", TOOLTIP_BODY_FONT_SIZE)
	lbl_cd.add_theme_font_size_override("bold_italics_font_size", TOOLTIP_BODY_FONT_SIZE)
	lbl_cd.add_theme_font_size_override("mono_font_size", TOOLTIP_BODY_FONT_SIZE)
	vbox.add_child(lbl_cd)
	
	# Description
	var lbl_desc: RichTextLabel = RichTextLabel.new()
	lbl_desc.bbcode_enabled = true
	lbl_desc.text = _format_lol_style(desc)
	lbl_desc.fit_content = true
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_desc.add_theme_font_size_override("normal_font_size", TOOLTIP_BODY_FONT_SIZE)
	lbl_desc.add_theme_font_size_override("bold_font_size", TOOLTIP_BODY_FONT_SIZE)
	lbl_desc.add_theme_font_size_override("italics_font_size", TOOLTIP_BODY_FONT_SIZE)
	lbl_desc.add_theme_font_size_override("bold_italics_font_size", TOOLTIP_BODY_FONT_SIZE)
	lbl_desc.add_theme_font_size_override("mono_font_size", TOOLTIP_BODY_FONT_SIZE)
	vbox.add_child(lbl_desc)
	
	hud_layer.add_child(tooltip_panel)
	tooltip_panel.size = Vector2(320, 0)
	tooltip_panel.reset_size()
	_update_tooltip_position()

func _on_mouse_exited() -> void:
	if tooltip_panel and is_instance_valid(tooltip_panel):
		tooltip_panel.queue_free()
		tooltip_panel = null

func _update_tooltip_position() -> void:
	if tooltip_panel and is_instance_valid(tooltip_panel):
		tooltip_panel.reset_size()
		var center_x: float = global_position.x + (size.x * get_global_transform().get_scale().x - tooltip_panel.size.x) * 0.5
		var top_y: float = global_position.y - tooltip_panel.size.y - 12
		tooltip_panel.global_position = Vector2(center_x, top_y)

## characters.gd'nin statik skill_desc/skill2_desc metinlerinin sonunda hep
## "(Xsn bekleme)" biçiminde gömülü bir sayı var (bkz. characters.gd - örn.
## "(200sn bekleme)", "(20sn bekleme)"). Bu sayı sabit yazıldığı için
## cooldown_reduction_percent gibi statlar bekleme süresini gerçekten
## kısaltsa bile açıklama metni eski/yanlış değeri göstermeye devam
## ediyordu (kullanıcı bildirimi). Bu fonksiyon o gömülü sayıyı, çağıran
## yerde (_on_mouse_entered) zaten doğru hesaplanmış GERÇEK current_cd ile
## değiştirir - cd_text satırıyla (üstteki "Bekleme Süresi: ...") her zaman
## tutarlı olsun diye AYNI current_cd kullanılıyor.
func _apply_live_cooldown_to_desc(desc: String, current_cd: float) -> String:
	var regex: RegEx = RegEx.new()
	## Lookahead ile SADECE "sn bekleme)" tarafından takip edilen sayıyı
	## bulur - parantez/"sn bekleme)" kısmı metinde olduğu gibi kalır,
	## sadece sayı kısmı değiştirilir.
	var err: Error = regex.compile("\\d+(?:\\.\\d+)?(?=sn bekleme\\))")
	if err != OK:
		return desc
	var m: RegExMatch = regex.search(desc)
	if m == null:
		return desc
	return desc.substr(0, m.get_start()) + _format_cd_number(current_cd) + desc.substr(m.get_end())


## "20" gibi tam sayılara yakın değerleri tam sayı olarak ("20"), gerçekten
## kesirli olanları ise bir ondalık basamakla ("16.8") biçimlendirir - böylece
## bekleme süresi azaltma statı olmayan karakterlerde metin eskisi gibi
## "20sn bekleme" görünmeye devam eder, tam sayı olmayan bir küsürat
## eklenmez.
func _format_cd_number(v: float) -> String:
	if abs(v - round(v)) < 0.05:
		return str(int(round(v)))
	return "%.1f" % v


func _format_lol_style(text: String) -> String:
	# Replace keywords first
	text = text.replace("ULTİ", "[color=#ff5555][b]ULTİ[/b][/color]")
	text = text.replace("TEMEL", "[color=#33ccff][b]TEMEL[/b][/color]")
	text = text.replace("PASİF", "[color=#ffcc33][b]PASİF[/b][/color]")
	
	# Highlight stats/mechanics
	text = text.replace("hasar", "[color=#ff5555]hasar[/color]")
	text = text.replace("Hasar", "[color=#ff5555]Hasar[/color]")
	text = text.replace("can", "[color=#55ff55]can[/color]")
	text = text.replace("Can", "[color=#55ff55]Can[/color]")
	text = text.replace("kalkan", "[color=#55aaff]kalkan[/color]")
	text = text.replace("Kalkan", "[color=#55aaff]Kalkan[/color]")
	text = text.replace("zırh", "[color=#eebb55]zırh[/color]")
	text = text.replace("Zırh", "[color=#eebb55]Zırh[/color]")
	text = text.replace("saldırı hızı", "[color=#ffcc33]saldırı hızı[/color]")
	text = text.replace("bekleme", "[color=#aaccff]bekleme[/color]")

	# Regex for numbers, percentages, durations (ignoring bbcode tags)
	var regex: RegEx = RegEx.new()
	var err: Error = regex.compile("(\\[[^\\]]*\\]|%?\\d+(?:\\.\\d+)?(?:\\s*saniye|\\s*sn|\\s*sn\\.|\\s*sn)?|\\b\\d+\\b)")
	if err == OK:
		var result: String = ""
		var last_pos: int = 0
		for m in regex.search_all(text):
			result += text.substr(last_pos, m.get_start() - last_pos)
			var match_str: String = m.get_string()
			if match_str.begins_with("["):
				result += match_str
			else:
				result += "[color=#ffaa00]" + match_str + "[/color]"
			last_pos = m.get_end()
		result += text.substr(last_pos)
		text = result

	return text

## Sahnede (hud.tscn) hazır duran ama eskiden hiç bağlanmamış "Cooldown"
## Label'ı - kullanıcı isteği: "yetenekler bekleme süresindeyken geri
## sayım olsun ikonlarının üstünde". character_select.tscn'deki önizleme
## ikonlarında bu node YOK, o yüzden get_node_or_null kullanılıyor.
@onready var cooldown_label: Label = get_node_or_null("Cooldown")


func update_state(p_progress: float, p_active: bool, p_remaining: float = 0.0, p_active_fraction: float = 0.0) -> void:
	progress = p_progress
	is_active = p_active
	remaining_seconds = p_remaining
	active_fraction = p_active_fraction
	_update_cooldown_label()
	queue_redraw()


## Sol-üst köşedeki sayısal rozet (hud.tscn'de "StackBadge" Label'ı, eskiden
## boş duran tek köşe - bkz. Cooldown/KeyLabel üstündeki yorumlar) - Korsan'ın
## bomba şarj sayısı (bkz. player.gd _korsan_bomb_charges) VE Necromancer'ın
## biriken ruh sayısı (bkz. beni oku.txt: "biriken ruhların sayısı pasif
## ikonunun üstünde görünmeli", player.gd get_necro_souls) gibi standart
## bekleme-süresi modeline uymayan yetenekler için. n < 0 rozeti tamamen
## gizler (diğer TÜM karakterlerde varsayılan/etkisiz durum budur).
@onready var stack_badge: Label = get_node_or_null("StackBadge")

func set_stack_count(n: int) -> void:
	if stack_badge == null:
		return
	if n < 0:
		stack_badge.visible = false
		return
	stack_badge.text = str(n)
	stack_badge.visible = true
	_layout_stack_badge()


## Rozetin ikonun SAĞ-ÜST köşesinde, ikonun İÇİNDE durmasını KODDAN garanti eder.
## DÜZELTME (kullanıcı bildirimi: "yük göstergeleri skill çerçevesinin dışında
## gösteriliyor tam skill penceresinin üstünde olmalı", daha önce de iki kez
## "içinde/sağ üstte olmalı" denmişti) - kök neden: hud.tscn'deki StackBadge
## Label'larında `layout_mode = 0` iken `anchor_left = 1.0` yazılı ama Godot
## yüklerken anchor_left'i 0.0'a geri çekiyor (çalışma anında ölçüldü:
## anchors L/R = 0.0/1.0, pos=(-30,4), size=(78,26)) - yani rozet 78px genişliğinde
## ve ikonun SOLUNA taşan bir kutu oluyordu, _draw_charge_ring de tam bu kutunun
## etrafına çerçeve çizip Q/E ikonlarının üstüne taşıyordu. .tscn'deki anchor/
## offset değerlerine hiç güvenilmiyor: anchor'lar sol-üste sabitlenip konum ve
## boyut ikonun KENDİ boyutundan hesaplanıyor (hem hud.tscn'deki üç hem
## hud.gd'nin kodla kurduğu R ikonu için aynı yol).
## GÖRÜNEN çerçeve ikon kontrolünün KENDİ kenarında değil, BORDER (7px) içeride
## (bkz. _draw: inner = outer.grow(-BORDER)) - rozet+halka (3px pay) bu iç alanın
## içinde kalsın diye kenardan BORDER + halka payı (3) + 1 = 11px içeride.
const STACK_BADGE_MARGIN := 11.0
## Küçük ikonlarda (32px pasif ikonu: iç alan sadece 18px) yük halkası çizilmediği
## için halka payı ayrılmıyor, sadece çerçeve kalınlığı (BORDER) + 1px kalıyor.
const STACK_BADGE_MARGIN_SMALL := 8.0
const STACK_BADGE_MIN_FONT := 10
var _badge_base_font_size: int = -1

func _layout_stack_badge() -> void:
	if stack_badge == null or not is_instance_valid(stack_badge):
		return
	stack_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stack_badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	stack_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stack_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin: float = STACK_BADGE_MARGIN if size.x >= 44.0 else STACK_BADGE_MARGIN_SMALL
	## Sahnede verilen font boyutu ilk seferde hatırlanır; sayı genişleyip (ör. 2-3
	## haneli ruh sayısı) çerçevenin iç alanına sığmazsa font kademeli küçültülür.
	if _badge_base_font_size < 0:
		_badge_base_font_size = stack_badge.get_theme_font_size("font_size")
	var fit_width: float = size.x - 2.0 * margin
	var font_size: int = _badge_base_font_size
	stack_badge.add_theme_font_size_override("font_size", font_size)
	while font_size > STACK_BADGE_MIN_FONT and stack_badge.get_combined_minimum_size().x > fit_width:
		font_size -= 2
		stack_badge.add_theme_font_size_override("font_size", font_size)
	var badge_size: Vector2 = stack_badge.get_combined_minimum_size()
	stack_badge.size = badge_size
	stack_badge.position = Vector2(size.x - margin - badge_size.x, margin)
	queue_redraw()


## Kullanıcı isteği: "yük biriken yeteneği olan karakterlerde (assasin,
## korsan) yetenek birikirken kaç yük olduğunun yanında bir çember/sayaç
## olsun - ◔ bekleme sürüyor, ◑ yarısı doldu, ◕ bitmek üzere, ● hazır".
## Unicode karakter KULLANILMIYOR - StackBadge rozetinin (bkz. yukarısı)
## etrafına doğrudan draw_arc ile AYNI fikri (kısmi/tam daire) çizen bir
## gösterge - bkz. _draw_charge_ring. fraction < 0 göstergeyi tamamen
## gizler (stack sayacı kullanmayan TÜM diğer karakterlerde varsayılan bu).
var _charge_fraction: float = -1.0

func set_charge_progress(fraction: float) -> void:
	_charge_fraction = fraction
	queue_redraw()


## Sadece GERÇEKTEN bekleme süresindeyken (aktif değil ve daha hazır değil)
## sayısal geri sayımı gösterir - saniyeler yukarı yuvarlanır (3.9sn -> "4")
## klasik geri sayım hissi için.
func _update_cooldown_label() -> void:
	if cooldown_label == null:
		return
	if not is_active and progress < 1.0 and remaining_seconds > 0.05:
		cooldown_label.text = str(int(ceil(remaining_seconds)))
		cooldown_label.visible = true
	else:
		cooldown_label.visible = false


## Kare çerçeve: yeni skill_bari.png çerçevesinin içine sığması için marj
## BORDER artırıldı (7.0). Arka plan düz çizimleri kaldırıldı, böylece
## arkasındaki ahşap çerçeve görünür.
## Kullanıcı isteği (2026-09-21): skill çerçeveleri yeniden tasarlandı (assets/ui/kit/hud_skill_frame*.png, 2 px'lik sanat pikselleri) -
## çerçeve kalınlığı artık ikon başına ayarlanabilir: normal 39 sanat pikseli çerçeve = 5 px sanat kenarı = 10 ekran px = 6.67 birim
## (SkillBar x1.5 ölçekli), küçük pasif çerçeve 3 sanat px = 4 birim, ruhani (F) 6 sanat px = 8 birim (hud.gd ayarlar).
var frame_border: float = 6.667

func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	var inner := outer.grow(-frame_border)

	## Yetenek ikonlarının (PNG dosyalarının VEYA fallback vektörel
	## çizimlerin) arkası transparan kalıp arkasındaki ahşap HUD barını
	## göstermesin diye, kare şeklinde koyu bir arkaplan çizilir.
	## Kullanıcı bildirimi: "bazı karakterlerin yetenek ikonları
	## transparan. transparan olmaması gerekiyor kare şeklinde içi dolu
	## bir ikon olması gerekiyor". Bu dolgu sayesinde tüm transparan
	## ikonlar (Elara, Assasin, Büyücü vb.) ve vektörler otomatik
	## olarak kare şeklinde içi dolu piksel-art tarzında görünür.
	draw_rect(inner, Color(0.12, 0.09, 0.07), true)

	_draw_icon(inner)

	## Buğulu bekleme örtüsü SADECE cooldown'dayken (aktif değilken) çizilir -
	## aktif süre artık kendi ayrı, kenarları daralan çerçevesiyle (aşağıda)
	## gösteriliyor, ikisi aynı anda karışmasın diye ayrıştırıldı.
	if progress < 1.0 and not is_active:
		_draw_cooldown_veil(inner, progress)

	if is_active:
		## Kullanıcı isteği: "aktif olan skillerin aktif olduğunu skill
		## ikonunun üstüne beyaz filtreyle aydınlatıp soldurarak belli etmeye
		## çalış" - ikonun üzerinde nabız gibi (sinüs) parlayıp sönen yarı
		## saydam beyaz bir örtü.
		var pulse_alpha: float = 0.15 + 0.20 * (0.5 + 0.5 * sin(_pulse_time * 4.0))
		draw_rect(inner, Color(1.0, 1.0, 1.0, pulse_alpha), true)

		## Kullanıcı isteği: "yetenekler aktifken yeteneklerin altına aktif
		## olduklarını gösteren bir bar ekle o bar yavaşça kapansın aktiflik
		## süresine göre" - ikonun ALT kenarında, kalan aktif süre oranınca
		## (active_fraction) soldan sağa daralan ince bir çubuk.
		var bar_h: float = 4.0
		var bar_rect := Rect2(inner.position.x, inner.position.y + inner.size.y - bar_h, inner.size.x, bar_h)
		draw_rect(bar_rect, Color(0.1, 0.08, 0.05, 0.9), true)
		var fill_w: float = bar_rect.size.x * clamp(active_fraction, 0.0, 1.0)
		if fill_w > 0.0:
			draw_rect(Rect2(bar_rect.position, Vector2(fill_w, bar_h)), Color(1.0, 0.95, 0.5, 1.0), true)

		## Kullanıcı isteği: "aktiflik çerçevesi skill barının çok dışında
		## duruyor direk kenarlarında olması lazım skill butonlarının" -
		## eskiden outer.grow(3.0) idi (butonun gerçek sınırının 3px
		## dışında duruyordu), artık TAM olarak `outer` (butonun kendi
		## kenarı) kullanılıyor - hiç büyütme yok.
		## "kenarlarının süreye göre azalmasını istiyorum" - artık statik/
		## tam bir kare değil, kalan aktif süre oranınca (active_fraction)
		## üst-sol köşeden saat yönünde daralan bir çerçeve çiziliyor.
		_draw_rect_perimeter_partial(outer, active_fraction, Color(1.0, 0.9, 0.4, 0.95), 3.0)

	_draw_charge_ring()


## bkz. set_charge_progress üstündeki kullanıcı isteği notu - StackBadge'in
## (sol-üst köşe, İKONUN İÇİNDE - bkz. hud.tscn/hud.gd StackBadge offset
## düzeltmesi) etrafına saat 12 hizasından
## başlayıp saat yönünde dolan bir yay çizer: fraction=0 -> tamamen boş
## halka (◔'dan da az), 0.5 -> yarım (◑), 1.0 -> tam daire (●).
## DÜZELTME (kullanıcı bildirimi: "stack hakkına sahip skill butonları için
## tasarladığın dolma barı iğrenç olmuş uyumsuz görünüyor butonlarla") - eski
## tasarım StackBadge'in (kare rozet) etrafına ayrık, kayan bir DAİRE
## çiziyordu; kare rozetle çakışan farklı bir şekil dilinde durduğu için
## uyumsuz görünüyordu. Artık aynı köşeli, "saat yönünde dolan çerçeve"
## dilini (bkz. _draw_rect_perimeter_partial - ikonun kendi aktiflik
## çerçevesinde ZATEN kullanılan teknik) rozetin KENDİ dikdörtgen sınırına
## uyguluyor - rozetle aynı şekil, rozetin kendi rengiyle (StackBadge
## font_color) uyumlu.
func _draw_charge_ring() -> void:
	if stack_badge == null or not stack_badge.visible or _charge_fraction < 0.0:
		return
	var rect: Rect2 = Rect2(stack_badge.position, stack_badge.size).grow(3.0)
	const BADGE_COLOR := Color(0.6, 0.95, 1.0, 1.0)
	_draw_rect_perimeter_partial(rect, 1.0, Color(BADGE_COLOR.r, BADGE_COLOR.g, BADGE_COLOR.b, 0.22), 2.0)
	var f: float = clamp(_charge_fraction, 0.0, 1.0)
	if f <= 0.0:
		return
	var ring_color: Color = Color(0.45, 1.0, 0.55, 1.0) if f >= 1.0 else BADGE_COLOR
	_draw_rect_perimeter_partial(rect, f, ring_color, 2.0)


## Bir dikdörtgenin çevresini (perimeter) BAŞLANGIÇ noktasından (üst-sol,
## saat yönünde) itibaren SADECE `fraction` kadarını çizer - fraction 1.0
## iken tam kare, 0.0'a yaklaştıkça kenarlar sırayla kısalıp kaybolur.
## Klasik "dolan/boşalan kare zamanlayıcı" görünümü verir.
func _draw_rect_perimeter_partial(rect: Rect2, fraction: float, color: Color, width: float) -> void:
	var f: float = clamp(fraction, 0.0, 1.0)
	if f <= 0.0:
		return
	var p0: Vector2 = rect.position
	var p1: Vector2 = rect.position + Vector2(rect.size.x, 0.0)
	var p2: Vector2 = rect.position + rect.size
	var p3: Vector2 = rect.position + Vector2(0.0, rect.size.y)
	var pts: PackedVector2Array = PackedVector2Array([p0, p1, p2, p3, p0])

	var total_len: float = 2.0 * (rect.size.x + rect.size.y)
	var target_len: float = total_len * f
	var drawn: float = 0.0

	for i in range(4):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg_len: float = a.distance_to(b)
		if drawn + seg_len <= target_len:
			draw_line(a, b, color, width, false)
			drawn += seg_len
		else:
			var remain: float = target_len - drawn
			if remain > 0.0:
				var t: float = remain / seg_len
				draw_line(a, a.lerp(b, t), color, width, false)
			break


## Yetenek bekleme (cooldown) süresindeyken ikonun üzerine saydam, buğulu/
## "blur" hissi veren bir örtü çizer - örtü tam kaplı başlar (progress=0) ve
## yeteneğin soğuma süresi ilerledikçe ALTTAN YUKARI doğru yavaşça açılıp
## ikonu ortaya çıkarır (progress=1 -> örtü tamamen kalkar). Gerçek bir
## Gaussian blur shader'ı yerine (Control._draw() içinde mümkün değil) üst
## üste binen saydam katmanlar + ince yatay çizgilerle buğulu cam hissi
## taklit edilir.
func _draw_cooldown_veil(inner: Rect2, p: float) -> void:
	var covered_h: float = inner.size.y * (1.0 - p)
	if covered_h <= 0.5:
		return
	var veil := Rect2(inner.position, Vector2(inner.size.x, covered_h))

	## Buğulu cam: donuk beyazımsı taban + koyu saydam katman.
	draw_rect(veil, Color(1.0, 1.0, 1.0, 0.10), true)
	draw_rect(veil, Color(0.05, 0.05, 0.08, 0.55), true)

	## İnce, hafif çizgiler - blur dokusu hissi verir.
	var streaks := 5
	for i in range(streaks):
		var ty: float = veil.position.y + veil.size.y * (float(i) + 0.5) / streaks
		draw_line(Vector2(inner.position.x, ty), Vector2(inner.position.x + inner.size.x, ty), Color(1.0, 1.0, 1.0, 0.05), 2.0)

	## Açılan kenarda parlak ince bir çizgi - "soğuma ilerliyor" hissini
	## netleştirir (bir tür yavaşça yükselen seviye çizgisi gibi).
	var edge_y: float = inner.position.y + covered_h
	draw_line(Vector2(inner.position.x, edge_y), Vector2(inner.position.x + inner.size.x, edge_y), Color(1.0, 1.0, 1.0, 0.5), 1.5)


## custom_texture varsa (gerçek sanat eseri ikonlar) tüm kare alanı KIRPMADAN
## ve ORANINI BOZMADAN doldurur (bkz. _draw_custom_texture) - "yüklediğim
## pngler tamamen görünebilmeli" isteğiyle artık hiçbir kenarı kesilmiyor.
## Vektörel ikonlar (custom_texture olmayan karakterler) eskisi gibi merkeze
## küçük bir ölçekte çizilir.
func _draw_icon(inner: Rect2) -> void:
	if custom_texture:
		_draw_custom_texture(inner)
		return
	var c: Vector2 = inner.position + inner.size * 0.5
	var s: float = min(inner.size.x, inner.size.y) * 0.5 * 0.62
	match skill_id:
		1:
			_icon_heal(c, s)
		2:
			_icon_rage(c, s)
		3:
			_icon_fast_fire(c, s)
		4:
			_icon_shield(c, s)
		5:
			_icon_invisibility(c, s)
		6:
			_icon_haste(c, s)
		15:
			_icon_giant_growth(c, s)
		16:
			_icon_thorns(c, s)


## Dokunun kendi en-boy oranı korunarak ("contain" - kırpma yok), kare alana
## ortalanmış şekilde tam sığdırılır - PNG'nin hiçbir parçası kesilmez.
func _draw_custom_texture(inner: Rect2) -> void:
	var tex_size: Vector2 = custom_texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var scale_factor: float = min(inner.size.x / tex_size.x, inner.size.y / tex_size.y)
	var draw_size: Vector2 = tex_size * scale_factor
	var draw_pos: Vector2 = inner.position + (inner.size - draw_size) * 0.5
	draw_texture_rect(custom_texture, Rect2(draw_pos, draw_size), false)


func _icon_heal(c: Vector2, s: float) -> void:
	var col := Color(0.95, 0.3, 0.35)
	draw_circle(c + Vector2(-s * 0.35, -s * 0.25), s * 0.42, col)
	draw_circle(c + Vector2(s * 0.35, -s * 0.25), s * 0.42, col)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.75, -s * 0.05), c + Vector2(s * 0.75, -s * 0.05), c + Vector2(0, s * 0.85)
	]), col)


func _icon_rage(c: Vector2, s: float) -> void:
	var col := Color(1.0, 0.45, 0.15)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s), c + Vector2(s * 0.6, s * 0.2), c + Vector2(0, s * 0.9), c + Vector2(-s * 0.6, s * 0.2)
	]), col)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s * 0.35), c + Vector2(s * 0.28, s * 0.35), c + Vector2(0, s * 0.7), c + Vector2(-s * 0.28, s * 0.35)
	]), Color(1.0, 0.85, 0.3))


func _icon_fast_fire(c: Vector2, s: float) -> void:
	var col := Color(1.0, 0.9, 0.2)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0.15 * s, -s), c + Vector2(-0.5 * s, 0.1 * s), c + Vector2(0, 0.1 * s),
		c + Vector2(-0.15 * s, s), c + Vector2(0.5 * s, -0.15 * s), c + Vector2(0, -0.15 * s)
	]), col)


func _icon_shield(c: Vector2, s: float) -> void:
	var col := Color(0.35, 0.65, 1.0)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.7, -s * 0.6), c + Vector2(s * 0.7, -s * 0.6), c + Vector2(s * 0.7, s * 0.1),
		c + Vector2(0, s * 0.95), c + Vector2(-s * 0.7, s * 0.1)
	]), col)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.4, -s * 0.35), c + Vector2(s * 0.4, -s * 0.35), c + Vector2(s * 0.4, s * 0.0),
		c + Vector2(0, s * 0.55), c + Vector2(-s * 0.4, s * 0.0)
	]), Color(0.6, 0.85, 1.0))


func _icon_invisibility(c: Vector2, s: float) -> void:
	var col := Color(0.65, 0.5, 0.95)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s, 0), c + Vector2(0, -s * 0.65), c + Vector2(s, 0), c + Vector2(0, s * 0.65)
	]), col)
	draw_circle(c, s * 0.32, Color(0.2, 0.15, 0.3))
	draw_line(c + Vector2(-s * 1.05, -s * 0.75), c + Vector2(s * 1.05, s * 0.75), Color(0.9, 0.85, 1.0), 3.0)


func _icon_haste(c: Vector2, s: float) -> void:
	var col := Color(0.4, 0.85, 1.0)
	for i in range(3):
		var off: float = (i - 1) * s * 0.45
		draw_line(c + Vector2(-s * 0.8, off - s * 0.25), c + Vector2(s * 0.5, off), col, 3.0)
		draw_line(c + Vector2(s * 0.5, off), c + Vector2(s * 0.1, off + s * 0.3), col, 3.0)


## Talon YENİ ULTİ (Devleşme) - gerçek sanat eseri ikon henüz yok, bu yüzden
## bu vektörel ikon devreye giriyor (bkz. skill_icon.gd dosya başı yorumu -
## custom_texture olmayan karakterler için otomatik fallback). Büyüyen iç içe
## iki halka + yukarı ok: boyut/güç artışını simgeliyor.
func _icon_giant_growth(c: Vector2, s: float) -> void:
	var col := Color(1.0, 0.6, 0.1)
	draw_arc(c, s * 0.85, 0, TAU, 24, col, 4.0)
	draw_arc(c, s * 0.5, 0, TAU, 20, Color(1.0, 0.8, 0.4), 3.0)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s * 0.4), c + Vector2(s * 0.22, -s * 0.05), c + Vector2(-s * 0.22, -s * 0.05)
	]), Color(1.0, 0.9, 0.6))


## Şovalye Adam PASİF (Dikenli Zırh) - gerçek sanat eseri ikon henüz yok,
## bu yüzden bu vektörel ikon devreye giriyor (bkz. dosya başı yorumu -
## custom_texture olmayan karakterler için otomatik fallback, Talon'un
## Devleşme'si gerçek ikonu gelene kadar aynı desende kullanılmıştı). Dikenli
## bir kalkan: gövde + etrafında dışa dönük dikenler.
func _icon_thorns(c: Vector2, s: float) -> void:
	var shield_col := Color(0.55, 0.6, 0.68)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.55, -s * 0.5), c + Vector2(s * 0.55, -s * 0.5), c + Vector2(s * 0.55, s * 0.1),
		c + Vector2(0, s * 0.85), c + Vector2(-s * 0.55, s * 0.1)
	]), shield_col)
	var spike_col := Color(0.85, 0.15, 0.15)
	var angles := [-0.9, -0.45, 0.0, 0.45, 0.9]
	for a in angles:
		var dir: Vector2 = Vector2(sin(a), -cos(a))
		var base: Vector2 = c + dir * s * 0.55
		var tip: Vector2 = c + dir * s * 1.05
		var side: Vector2 = Vector2(-dir.y, dir.x) * s * 0.14
		draw_colored_polygon(PackedVector2Array([base - side, base + side, tip]), spike_col)
