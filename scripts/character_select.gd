extends Control

## Karakter seçim ekranı: Characters.DEFS'teki her karakter için bir kart
## oluşturur. Kart seçilince yetenek bilgisi gösterilir, BAŞLA oyunu başlatır.

const BASE_STATS := "Can:100  Hız:240  Hasar:10  AteşHızı:1.0/sn"
const SpiritualPickerScript: GDScript = preload("res://scripts/spiritual_picker.gd")

@onready var grid: GridContainer = $VBox/Grid
## Bilgi paneli artık VBox'ın dışında, ekranın altına sabit, kendi başına
## geniş+kısa bir panel (bkz. kullanıcı bildirimi - "boyu azalsın, eni
## artsın" - eskiden VBox'ın 600px'lik sabit yüksekliğine sıkışıp taşıyordu).
## Kullanıcı isteği: "her açıklama ikonun yanında görünmeli açıklamalar
## ikonlardan bağımsız konumdalar" - eskiden TÜM ikonlar sol tarafta bir
## sütunda, TÜM açıklamalar ise sağda ayrı, tek bir metin bloğunda
## duruyordu (ikon <-> açıklama eşleşmesi görsel olarak belirsizdi). Artık
## her yetenek kendi SATIRINDA: [ikon][o ikona ait açıklama] yan yana -
## bkz. UltiRow/TemelRow/PassiveRow (character_select.tscn).
@onready var name_label: Label = $InfoPanel/InfoMargin/InfoVBoxOuter/NameLabel
@onready var stats_label: Label = $InfoPanel/InfoMargin/InfoVBoxOuter/StatsLabel
## Karakterin yeteneğini gösteren ikon(lar) - skill_icon.gd'nin HUD'da zaten
## kullanılan vektörel çizim mantığını yeniden kullanıyor: custom_texture
## (gerçek sanat eseri ikon) varsa onu, yoksa skill_id'ye göre elle çizilen
## vektör ikonu gösterir (bkz. skill_icon.gd _draw_icon) - bu yüzden HİÇBİR
## karakter ikonsuz kalmaz, sadece Öykü'nün gerçek PNG ikonları var, diğerleri
## otomatik vektör simgeleriyle gösterilir.
@onready var ulti_row: HBoxContainer = $InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/UltiRow
@onready var skill_icon_1 = $InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/UltiRow/SkillIcon1
@onready var ulti_desc_label: Label = $InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/UltiRow/UltiDescLabel
@onready var temel_row: HBoxContainer = $InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/TemelRow
@onready var skill_icon_2 = $InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/TemelRow/SkillIcon2
@onready var temel_desc_label: Label = $InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/TemelRow/TemelDescLabel
## 3. yetenek (R tuşu) satırı - Characters.DEFS'te "skill3" alanı olan
## karakterler için (bkz. characters.gd). Eskiden bu ekranda hiç
## gösterilmiyordu, sadece skill/skill2/passive vardı (kullanıcı bildirimi:
## "karakterler artık 3 yeteneğe sahip, güncellenmesi gerekiyor").
@onready var skill3_row: HBoxContainer = $InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/Skill3Row
@onready var skill_icon_3 = $InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/Skill3Row/SkillIcon3
@onready var skill3_desc_label: Label = $InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/Skill3Row/Skill3DescLabel
## Kullanıcı isteği: "karakterlerin pasiflerinin ikonu da görünmeli" - hud.gd
## _setup_ability_icons() ile birebir aynı mantık: skill_id = -1 (pasifin
## kendine ait bir vektör-fallback'i yok, tüm karakterlerin gerçek
## passive_icon PNG'si zaten var), custom_texture doğrudan def["passive_icon"]
## dosyasından yükleniyor.
@onready var passive_row: HBoxContainer = $InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/PassiveRow
@onready var passive_icon = $InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/PassiveRow/PassiveIcon
@onready var passive_desc_label: Label = $InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/PassiveRow/PassiveDescLabel
@onready var start_button: Button = $StartButton
@onready var back_button: Button = $BackButton

var selected_char: int = -1
var buttons: Dictionary = {}
## Kart = her karakterin PORTRE+İSİM kartını saran bir seçim çerçevesi
## (PanelContainer, bkz. _build_select_frame_style/_ready) - seçili
## karaktere parlak bir çerçeve uygulamak için kullanılıyor, bkz.
## _on_character_pressed.
var cards: Dictionary = {}
var _select_frame_style_off: StyleBoxFlat
var _select_frame_style_on: StyleBoxFlat

## Kullanıcı isteği: "karakterlerin arkasına isimlerini ve görünüşlerini
## kaplayacak minik kartlar eklemeni istiyorum (tıpkı level atlama kartları
## gibi) isimleri ve görüntüleri bu kartlardan dışarı taşmamalı, simetrik
## bir biçimde her karakter bir kartın içinde olmalı." - level_up_screen.tscn
## "CardStyle_normal" ile birebir aynı renk/kenarlık/köşe yarıçapı (ahşap
## tema). TÜM kartlar aynı göründüğü için tek bir paylaşılan StyleBoxFlat
## kaynağı yeterli.
##
## DÜZELTME (kullanıcı isteği: "isim kartları portre kartlarıyla birleşik
## olsun ve isim kartları daha farklı renkte ancak uyumlu bir renkle olsun")
## - artık İKİ AYRI stil var: üst (portre) kartının ALT kenarı köşesiz/
## kenarlıksız, alt (isim) kartının ÜST kenarı köşesiz/kenarlıksız - aradaki
## boşluk (separation) 0'a çekildiği için ikisi TEK PARÇA bir kart gibi
## kaynaşık görünüyor (seam'de çift kalın kenarlık binmesin diye ortak kenar
## kasıtlı olarak kenarlıksız bırakıldı). İsim kartı aynı ahşap paletinin
## daha sıcak/altın bir tonu (uyumlu ama farklı) - portre kartının koyu
## kahvesiyle tezat oluşturup ismi öne çıkarıyor.
static func _build_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.32, 0.2, 0.11, 1)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.16, 0.09, 0.04, 1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style


## Üstteki portre kartı: alt kenar düz/kenarlıksız - hemen altındaki isim
## kartıyla kaynaşacak.
static func _build_portrait_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.32, 0.2, 0.11, 1)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 0
	style.border_color = Color(0.16, 0.09, 0.04, 1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 0
	style.corner_radius_bottom_left = 0
	return style


## Alttaki isim kartı: aynı ahşap paletinin daha sıcak/altın bir tonu -
## uyumlu ama portre kartından ayırt edilebilir. Üst kenar düz/kenarlıksız
## (portre kartının alt kenarıyla kaynaşsın diye).
static func _build_name_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.52, 0.34, 0.15, 1)
	style.border_width_left = 3
	style.border_width_top = 0
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.16, 0.09, 0.04, 1)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style


## DÜZELTME (kullanıcı isteği: "karakterler karanlık gösteriliyor sadece
## seçince aydınlık görünüyorlar bunu kaldırıp ... tıkladığımız karakterin
## kutucuklarının etrafını kaplayan bir çerçeve ekle") - eskiden seçili
## OLMAYAN karakterler modulate ile karartılıyordu (bkz. Git geçmişi);
## artık HİÇBİR kart karartılmıyor (hepsi her zaman tam parlaklıkta), bunun
## yerine SADECE seçili karakterin kartını saran, arka planı tamamen şeffaf
## (bg_color alpha=0) parlak bir çerçeve gösteriliyor - bkz. _select_frame_
## style_on/off ve _on_character_pressed.
static func _build_select_frame_style(highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	var w: int = 5 if highlighted else 0
	style.border_width_left = w
	style.border_width_top = w
	style.border_width_right = w
	style.border_width_bottom = w
	style.border_color = Color(0.22, 0.62, 0.2, 1.0) ## koyu, gözü yormayan yeşil
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	## Sabit içerik boşluğu (border genişliğinden BAĞIMSIZ) - seçiliyken/
	## seçili değilken kenarlık kalınlığı değişse bile (0 <-> 5) içerideki
	## kartın konumu/boyutu ASLA kaymasın diye margin border_width yerine
	## burada sabitleniyor.
	style.content_margin_left = 6
	style.content_margin_top = 6
	style.content_margin_right = 6
	style.content_margin_bottom = 6
	return style


func _ready() -> void:
	## Kullanıcı isteği (2026-09-21): büyük bilgi paneli UIKit ahşap pencere çerçevesinde (konum/boyut DEĞİŞMEDİ).
	var info_panel_node: Control = get_node_or_null("InfoPanel") as Control
	if info_panel_node:
		info_panel_node.add_theme_stylebox_override("panel", UIKit.panel_style("window_tight"))
	var portrait_style := _build_portrait_card_style()
	var name_style := _build_name_card_style()
	_select_frame_style_off = _build_select_frame_style(false)
	_select_frame_style_on = _build_select_frame_style(true)
	for char_id in Characters.DEFS:
		var def: Dictionary = Characters.DEFS[char_id]

		## Kullanıcı isteği: "isim kartları portre kartlarıyla birleşik olsun
		## ve isim kartları daha farklı renkte ancak uyumlu bir renkle olsun"
		## - artık İKİ AYRI stil ile TEK PARÇA görünen bir kart var: üstte
		## portre bölümü, hemen ALTINDA (boşluksuz, kaynaşık) SADECE ismi
		## barındıran daha sıcak tonlu bir bölüm. Seçim vurgusu (modulate)
		## artık bu ikisini saran ORTAK bir Control'e uygulanıyor - CanvasItem
		## modulate'i alt node'lara otomatik miras kaldığı için tek bir
		## atama her iki bölümü de birlikte soluklaştırır/aydınlatır.
		var outer := VBoxContainer.new()
		outer.add_theme_constant_override("separation", 0)
		outer.alignment = BoxContainer.ALIGNMENT_CENTER

		## Sabit boyutlu (148x140) ve clip_contents=true - portre ne kadar
		## büyük olursa olsun kartın DIŞINA asla taşamaz (kullanıcı isteği:
		## "dışarı taşmamalı"), ayrıca her kart aynı boyutta olduğu için grid
		## otomatik olarak simetrik hizalanır.
		var card_panel := PanelContainer.new()
		card_panel.custom_minimum_size = Vector2(148, 140)
		card_panel.clip_contents = true
		card_panel.add_theme_stylebox_override("panel", portrait_style)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		card_panel.add_child(margin)

		var portrait_center := CenterContainer.new()
		margin.add_child(portrait_center)

		var button := TextureButton.new()
		## Ekran 1920x1080 olduğu doğrulandı - kartlar 145px'ten 122px'e biraz
		## küçültüldü (kullanıcı bildirimi: "bilgi paneli kocaman ama içine
		## açıklama sığmıyor") - buradan kazanılan dikey boşluk VBox'ın
		## offset_bottom'unu aşağı çekmeden InfoPanel'e (bkz. .tscn) ayrılıyor,
		## böylece artık uzayan yetenek açıklamaları (saldırı gücü oranlarıyla
		## birlikte) kaydırma yapmadan sığabiliyor.
		button.custom_minimum_size = Vector2(122, 122)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if ResourceLoader.exists(def["portrait"]):
			button.texture_normal = load(def["portrait"])
		button.pressed.connect(_on_character_pressed.bind(char_id))
		portrait_center.add_child(button)
		buttons[char_id] = button

		outer.add_child(card_panel)

		## İsmin kendine özgü mini kartı - portre kartıyla BİRLEŞİK (aralarında
		## boşluk yok) ama farklı/uyumlu bir renk tonunda (bkz.
		## _build_name_card_style). Metne yetecek kadar dar/kısa (148x42) -
		## isim burada da kartın dışına taşmasın diye clip_contents açık.
		var name_card := PanelContainer.new()
		name_card.custom_minimum_size = Vector2(148, 42)
		name_card.clip_contents = true
		name_card.add_theme_stylebox_override("panel", name_style)

		var name_margin := MarginContainer.new()
		name_margin.add_theme_constant_override("margin_left", 4)
		name_margin.add_theme_constant_override("margin_top", 4)
		name_margin.add_theme_constant_override("margin_right", 4)
		name_margin.add_theme_constant_override("margin_bottom", 4)
		name_card.add_child(name_margin)

		var label := Label.new()
		label.text = def["name"]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		name_margin.add_child(label)

		## Kullanıcı isteği: "içindeki karakter ismi fontları biraz daha
		## büyüt ama dışarı taşmamasına dikkat et" - sabit bir font_size
		## yerine, ismin GERÇEK piksel genişliği kutuya göre ölçülüp taşan
		## isimler (ör. "Assasin Çocuk", "Şovalye Adam") otomatik olarak
		## sığana kadar küçültülüyor - kısa isimler (ör. "Elara") ise tam
		## istenen büyük boyutu korur, hiçbiri kartın dışına taşmaz.
		## Kullanıcı isteği: "fontu %15 büyüt" - start/min ikisi de aynı
		## oranda büyütüldü (26->30, 16->18) ki uzun isimler için otomatik
		## küçültme oranı bozulmasın.
		_fit_label_font(label, def["name"], 30, 18, 148 - 8)

		outer.add_child(name_card)

		## Seçim vurgusu artık karartma DEĞİL - kartı saran ayrı bir çerçeve
		## (bkz. _build_select_frame_style). select_frame -> frame_margin ->
		## outer (portre + isim) - çerçevenin kendi kenarlığı, üzerine
		## bindirilmiş "outer" kartının kenarlıklarının biraz DIŞINDA kalıyor.
		var select_frame := PanelContainer.new()
		select_frame.add_theme_stylebox_override("panel", _select_frame_style_off)
		select_frame.add_child(outer)

		grid.add_child(select_frame)
		cards[char_id] = select_frame

	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	start_button.disabled = true
	_on_character_pressed(1)
	## Ruhani Yetenek seçici (kullanıcı isteği: oyun başında karakter seçim ekranında herkes 1 tane seçer) - sol boş alanda,
	## karakter ızgarasının ve bilgi panelinin dışında. Seçim doğrudan GameManager.selected_spiritual'a yazılır.
	var spirit_picker: PanelContainer = SpiritualPickerScript.new()
	spirit_picker.custom_minimum_size = Vector2(420, 0)
	spirit_picker.position = Vector2(40, 110)
	add_child(spirit_picker)
	spirit_picker.setup(3)
	## Karakter kartları YUKARIDA runtime'da oluşturuluyor - connect_all_buttons
	## bu yüzden döngüden SONRA çağrılmalı, yoksa henüz var olmayan butonları
	## kaçırır (bkz. UISound autoload).
	UISound.connect_all_buttons(self)
	## Kullanıcı isteği: "oyundaki bütün butonları bununla değiştirmeni
	## istiyorum" - bkz. ui_sound.gd apply_wood_buttons üstündeki not,
	## connect_all_buttons'ın BİREBİR aynı "tüm ağacı tara" deseni.
	UISound.apply_wood_buttons(self)


## Verilen metni, kutuya (max_width) sığana kadar font_size'ı start_size'dan
## min_size'a kadar 1'er 1'er küçültüp label'a uygular - böylece "biraz daha
## büyüt ama dışarı taşmasın" isteği hem kısa hem uzun isimlerde güvenle
## karşılanır (bkz. yukarıdaki çağrı noktası).
func _fit_label_font(label: Label, txt: String, start_size: int, min_size: int, max_width: float) -> void:
	var font_size: int = start_size
	var font: Font = label.get_theme_font("font")
	if not font:
		font = ThemeDB.fallback_font
	while font_size > min_size:
		var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		if w <= max_width:
			break
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)


func _on_character_pressed(char_id: int) -> void:
	selected_char = char_id
	var def: Dictionary = Characters.get_def(char_id)
	name_label.text = def["name"]
	## Artık herkes ortak ana silahla (yakın dövüş) başlıyor - bkz.
	## Characters.MAIN_WEAPON / player.gd. Eskiden burada "Sınıf: Yakıncı/
	## Menzilli" gibi bir sınıf etiketi de gösteriliyordu; artık TÜM
	## karakterler aynı ortak silahla saldırdığı için böyle bir ayrım
	## kalmadı (bkz. kullanıcı isteği - "sınıf kısmını kaldır").
	stats_label.text = BASE_STATS
	start_button.disabled = false

	## Ulti satırı: ikon + kendi açıklaması (skill_desc zaten "ULTİ:" ile
	## başlıyor) yan yana - isim/tuş bilgisi başına eklenir (bkz. kullanıcı
	## isteği - "her açıklama ikonun yanında görünmeli").
	skill_icon_1.skill_id = def.get("skill", 1)
	skill_icon_1.custom_texture = load(def["skill_icon"]) if def.has("skill_icon") else null
	skill_icon_1.queue_redraw()
	ulti_desc_label.text = "%s (Q tuşu): %s" % [def.get("skill_name", "Ulti"), def["skill_desc"]]

	var has_skill2: bool = def.has("skill2")
	temel_row.visible = has_skill2
	if has_skill2:
		skill_icon_2.skill_id = def.get("skill2", 1)
		skill_icon_2.custom_texture = load(def["skill2_icon"]) if def.has("skill2_icon") else null
		skill_icon_2.queue_redraw()
		temel_desc_label.text = "%s (E tuşu): %s" % [def.get("skill2_name", "Temel"), def["skill2_desc"]]

	## 3. yetenek satırı (R tuşu) - temel_row ile birebir aynı desen, bkz.
	## yukarıdaki skill3_row alan tanımı üstündeki not.
	var has_skill3: bool = def.has("skill3")
	skill3_row.visible = has_skill3
	if has_skill3:
		skill_icon_3.skill_id = def.get("skill3", 1)
		skill_icon_3.custom_texture = load(def["skill3_icon"]) if def.has("skill3_icon") else null
		skill_icon_3.queue_redraw()
		skill3_desc_label.text = "%s (R tuşu): %s" % [def.get("skill3_name", "3. Yetenek"), def["skill3_desc"]]

	## Pasif satırı: hud.gd _setup_ability_icons() ile aynı mantık - pasifi
	## olmayan karakterlerde (ör. Büyücü Kız) satır tamamen gizlenir.
	var has_passive: bool = def.has("passive") and not str(def["passive"]).is_empty()
	passive_row.visible = has_passive
	if has_passive:
		## bkz. hud.gd _setup_ability_icons() üstündeki AYNI DÜZELTME notu -
		## gerçek sanat eseri ikonu olmayan pasifler artık passive_vector_id
		## ile doğru vektör ikonuna düşüyor, -1'de takılı kalmıyor.
		passive_icon.skill_id = def.get("passive_vector_id", -1)
		var p_tex_path: String = def.get("passive_icon", "")
		passive_icon.custom_texture = load(p_tex_path) if p_tex_path != "" and ResourceLoader.exists(p_tex_path) else null
		passive_icon.queue_redraw()
		passive_desc_label.text = "Pasif: %s" % def["passive"]

	for id in cards:
		var frame: PanelContainer = cards[id]
		frame.add_theme_stylebox_override("panel", _select_frame_style_on if id == char_id else _select_frame_style_off)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_start_pressed() -> void:
	if selected_char == -1:
		return
	var def: Dictionary = Characters.get_def(selected_char)
	GameManager.selected_char_id = selected_char
	GameManager.selected_character = def["skill"]
	## Kullanıcı isteği: "oyuna başla dediğimizde yükleme ekranı olsun" -
	## artık main.tscn'e doğrudan değil, önce loading_screen.gd'nin kendi
	## yüklediği (ve barını doldurduğu) yükleme ekranına geçiliyor.
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")
