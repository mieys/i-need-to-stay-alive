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
## >= 0 ise ipucundaki bekleme süresi (taban, sn) bu - yeteneğin kendi zamanlama tablosu yerine (Shaman golem formunda Q/E'nin
## form hâlleri kendi sayaçlarıyla çalışır, bkz. player.gd get_hud_skill_override / hud.gd _apply_hud_skill_override).
var cooldown_override: float = -1.0

var tooltip_panel: PanelContainer = null
## Shift'e basılı tutulunca bu oyundaki hasar/can/kalkan (bkz. damage_stats.gd) - ipucu açıkken Shift durumu değişirse yeniden kurulur.
const DamageStats := preload("res://scripts/damage_stats.gd")
const UiAnim := preload("res://scripts/ui_anim.gd")
const HudTheme := preload("res://scripts/hud_theme.gd")
const HudTooltip := preload("res://scripts/hud_tooltip.gd")
const COOLDOWN_ICON := preload("res://assets/ui/stat_mini/cooldown_reduction.png")
## İpucu levhası genişliği (32 px m5x7 ile satır ~24 harf) ve başlıktaki ikon (144 px sanat 1/3 = 3 px/sanat pikseli, keskin).
const TOOLTIP_WIDTH := 516.0
const TOOLTIP_ICON := 48.0
## Bekleme bitince ikon bir kez parlayıp "nefes" alır (madde 200): 1 -> 0, READY_FLASH_TIME sn.
const READY_FLASH_TIME := 0.35
var _ready_flash: float = 0.0
var _tooltip_shift: bool = false

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_layout_stack_badge)
	_layout_stack_badge()

func _process(delta: float) -> void:
	if tooltip_panel and is_instance_valid(tooltip_panel) and tooltip_panel.visible:
		if Input.is_key_pressed(KEY_SHIFT) != _tooltip_shift:
			_on_mouse_entered()
			return
		_update_tooltip_position()
	if is_active:
		_pulse_time += delta
	if _enchant_glow > 0.0:
		_enchant_glow_t += delta
		queue_redraw()
	if _ready_flash > 0.0:
		_ready_flash = maxf(0.0, _ready_flash - delta / READY_FLASH_TIME)
		queue_redraw()

func _exit_tree() -> void:
	if tooltip_panel and is_instance_valid(tooltip_panel):
		tooltip_panel.queue_free()
		tooltip_panel = null

func _on_mouse_entered() -> void:
	## Shift değişince yeniden kurulur (_process) - o zaman belirme animasyonu yok, sadece ilk açılışta.
	var rebuilding: bool = tooltip_panel != null and is_instance_valid(tooltip_panel)
	if rebuilding:
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
	var keybind_text: String = ""
	## Açıklamanın başında tür yoksa ("ULTİ: ...") etikete yazılacak tür.
	var kind_fallback: String = "YETENEK"
	## Bekleme satırı: cd_now < 0 = bekleme yok; cd_base != cd_now ise eski (taban) süre üstü çizili yanında.
	var cd_now: float = -1.0
	var cd_base: float = -1.0
	var cd_note: String = ""
	_tooltip_shift = Input.is_key_pressed(KEY_SHIFT)

	if name == "PassiveIcon":
		## Pasif adı çoğu karakterde açıklamanın başında ("Yıldırım Hızı: ..."); yoksa başlık karakterin adı.
		desc = def.get("passive", "Pasif yetenek açıklaması bulunmuyor.") as String
		var pn: Array = _split_passive_name(desc)
		title = str(def.get("passive_name", pn[0] if pn[0] != "" else def.get("name", "Pasif Yetenek")))
		desc = pn[1]
		keybind_text = ""
		kind_fallback = "PASİF"
	elif name == "SkillIcon":
		title = def.get("skill_name", "Aktif Yetenek") as String
		if not name_override.is_empty():
			title = name_override
		desc = def.get("skill_desc", "Aktif yetenek açıklaması bulunmuyor.") as String
		if not desc_override.is_empty():
			desc = desc_override
		keybind_text = "Q"

		var base_cd: float = 20.0
		var current_cd: float = 20.0
		var skill_id_val: int = def.get("skill", 1) as int

		if player and is_instance_valid(player) and "SKILL_TIMING" in player:
			## Yetenek evrimlerinin bekleme/süre değişiklikleri dahil (player.gd _skill_timing_for -> _evo_timing).
			var timing: Dictionary = (player.call("_skill_timing_for", skill_id_val) if player.has_method("_skill_timing_for") \
				else player.SKILL_TIMING.get(skill_id_val, {"cooldown": 20.0})) as Dictionary
			base_cd = timing["cooldown"] as float
			current_cd = player._skill_cooldown as float
		if cooldown_override >= 0.0:
			base_cd = cooldown_override
			var cdr_q: float = float(player.get_cooldown_reduction()) if player and is_instance_valid(player) and "cooldown_reduction_percent" in player else 0.0
			current_cd = base_cd * (1.0 - cdr_q)
		cd_now = current_cd
		cd_base = base_cd
	elif name == "SpiritIcon":
		## Ruhani Yetenek (F, bkz. spiritual_skills.gd): karakterden bağımsız, kendi tanımından okunur. Bekleme süresi
		## "Bekleme Süresi Azaltma" statından etkilenmez (kullanıcı isteği) - bu yüzden "taban" karşılaştırması yok.
		var spirit_def: Dictionary = SpiritualSkillsScript.get_def(GameManager.selected_spiritual)
		title = str(spirit_def.get("name", "Ruhani Yetenek"))
		desc = str(spirit_def.get("desc", ""))
		kind_fallback = "RUHANİ"
		if bool(spirit_def.get("active", false)):
			keybind_text = GameManager.get_action_key_label("skill4")
			cd_now = float(spirit_def.get("cooldown", 0.0))
			cd_base = cd_now
			cd_note = "azaltılamaz"
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
		kind_fallback = "ULTİ"

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
			## Yetenek evrimlerinin bekleme/süre değişiklikleri dahil (player.gd _skill3_timing_for -> _evo_timing).
			if player.SKILL3_TIMING.has(skill3_id_val) and player.has_method("_skill3_timing_for"):
				timing3 = player.call("_skill3_timing_for", skill3_id_val) as Dictionary
			base_cd3 = timing3["cooldown"] as float
			var cdr3: float = float(player.get_cooldown_reduction()) if "cooldown_reduction_percent" in player else 0.0
			current_cd3 = base_cd3 * (1.0 - cdr3)
		else:
			current_cd3 = base_cd3
		## Bekleme süresi olmayan TOGGLE'lar (Vampir Çocuk R'si) - "0 sn" yerine "bekleme yok".
		if base_cd3 > 0.0:
			cd_now = current_cd3
			cd_base = base_cd3
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
		kind_fallback = "TEMEL"

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
			## Yetenek evrimlerinin bekleme/süre değişiklikleri dahil (player.gd _skill2_timing_for -> _evo_timing).
			var timing: Dictionary = (player.call("_skill2_timing_for", skill2_id_val) if player.has_method("_skill2_timing_for") \
				else player.SKILL2_TIMING.get(skill2_id_val, {"cooldown": 15.0})) as Dictionary
			base_cd = timing["cooldown"] as float
			## DÜZELTME: player._skill2_cooldown Büyücü Kız için hiç
			## güncellenmiyor (standart skill2_state makinesini kullanmıyor,
			## bkz. player.gd _buyucu_try_activate_variation) - bekleme
			## süresi azaltma statını (cooldown_reduction_percent) doğrudan
			## temel süreye uygulayan bu formül TÜM karakterlerde doğru sonucu
			## verir ve Büyücü'ye özel bir dal gerektirmez.
			var cdr: float = float(player.get_cooldown_reduction()) if "cooldown_reduction_percent" in player else 0.0
			current_cd = base_cd * (1.0 - cdr)
		if cooldown_override >= 0.0:
			base_cd = cooldown_override
			var cdr_e: float = float(player.get_cooldown_reduction()) if player and is_instance_valid(player) and "cooldown_reduction_percent" in player else 0.0
			current_cd = base_cd * (1.0 - cdr_e)
		cd_now = current_cd
		cd_base = base_cd

	## Açıklamanın başındaki tür ("ULTİ: ...") etikete taşınır; sondaki gömülü "(20sn bekleme)" atılır - bekleme artık
	## başlıktaki satırda CANLI (bekleme süresi azaltmasıyla) yazıyor (eskiden metindeki sayı da canlıya çevriliyordu).
	var parts: Array = _split_kind(desc)
	var kind: String = str(parts[0]) if str(parts[0]) != "" else kind_fallback
	desc = _strip_cooldown_note(str(parts[2]))

	# --- İpucu (2026-10-18, kullanıcı: "şuanki arayüze uygun olacak şekilde tasarla yeniden"): yetenek panelinin koyu ahşap
	## levhası (HudTooltip, madde 207 "Kısık Ahşap"), başlıkta ikon + ad + tür etiketi + canlı bekleme + tuş kapağı, açık
	## mürekkep renkleri (HudTheme.INK), evrimler / bu oyunda bölümleri koyu kuyuda, yuvaya inen basamaklı uç.
	## Yazı boyutları eskisi gibi: ana metin UIKit.FS_BODY (32, m5x7 keskin), ikincil bölümler 24.
	tooltip_panel = HudTooltip.make_panel(TOOLTIP_WIDTH)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 9)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(vbox)

	# Başlık: [ikon] AD / etiket + bekleme  ...  [tuş]
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)

	var icon_well: PanelContainer = PanelContainer.new()
	icon_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_well.add_theme_stylebox_override("panel", HudTooltip.well_style(3.0, 3.0))
	icon_well.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(icon_well)
	var mini_icon: Control = (get_script() as GDScript).new()
	mini_icon.custom_minimum_size = Vector2(TOOLTIP_ICON, TOOLTIP_ICON)
	mini_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_icon.set("frame_border", 0.0)
	mini_icon.set("skill_id", skill_id)
	mini_icon.set("custom_texture", custom_texture)
	icon_well.add_child(mini_icon)

	var head_col: VBoxContainer = VBoxContainer.new()
	head_col.add_theme_constant_override("separation", 3)
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(head_col)

	var lbl_title: Label = HudTooltip.make_label(title.to_upper(), UIKit.FS_BODY, HudTheme.ACCENT)
	lbl_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head_col.add_child(lbl_title)

	var sub: HBoxContainer = HBoxContainer.new()
	sub.add_theme_constant_override("separation", 9)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_col.add_child(sub)
	sub.add_child(HudTooltip.make_tag(kind))
	## Pasiflerde (tuşu yok) bekleme satırı hiç yok - "Bekleme yok" sadece tuşlu aç/kapa yeteneklerde anlamlı.
	var show_cd: bool = keybind_text != ""
	if cd_now >= 0.0:
		var cd_icon: TextureRect = TextureRect.new()
		cd_icon.texture = COOLDOWN_ICON
		cd_icon.custom_minimum_size = Vector2(24, 24)
		cd_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cd_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cd_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cd_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.add_child(cd_icon)
	if show_cd:
		var lbl_cd: RichTextLabel = HudTooltip.make_rich(UIKit.FS_BODY, HudTheme.TEXT, false)
		lbl_cd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lbl_cd.text = _cooldown_bbcode(cd_now, cd_base, cd_note)
		sub.add_child(lbl_cd)

	if keybind_text != "":
		var key: PanelContainer = HudTooltip.make_keycap(keybind_text)
		key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		header.add_child(key)

	if locked_level > 0:
		vbox.add_child(HudTooltip.make_label("Seviye %d'de açılır" % locked_level, MenuKit.FS_SMALL, HudTheme.BAD))

	vbox.add_child(HudTooltip.make_divider())

	# Açıklama
	var lbl_desc: RichTextLabel = HudTooltip.make_rich(UIKit.FS_BODY, HudTheme.TEXT)
	lbl_desc.text = _format_lol_style(desc)
	vbox.add_child(lbl_desc)

	## Yetenek evrimleri (2026-09-28): bu yuvada alınmış evrimler, açıklamanın hemen altında (ad + ne yaptığı) - koyu kuyuda.
	var evo_text: String = _evolution_tooltip_text(player)
	if evo_text != "":
		var evo_well: PanelContainer = HudTooltip.make_well()
		vbox.add_child(evo_well)
		var lbl_evo: RichTextLabel = HudTooltip.make_rich(MenuKit.FS_SMALL, HudTheme.TEXT)
		lbl_evo.text = evo_text
		evo_well.add_child(lbl_evo)

	## Shift: bu oyunda bu yeteneğin GERÇEKTEN verdiği hasar / can / kalkan (kullanıcı isteği 2026-10-17; ölçüm kaynağı
	## DamageStats = balans telemetrisinin kaynak başına sayaçları). Basılı değilken altta tek satır ipucu.
	if _tooltip_shift:
		var slot: String = str(DamageStats.ICON_SLOT.get(String(name), "e"))
		var ink: Dictionary = HudTheme.INK.duplicate()
		ink["cooldown"] = "#" + HudTheme.DIM.to_html(false) ## tooltip_bbcode "cooldown"u soluk ikincil yazı olarak kullanır
		var stats_well: PanelContainer = HudTooltip.make_well()
		vbox.add_child(stats_well)
		var lbl_detail: RichTextLabel = HudTooltip.make_rich(UIKit.FS_BODY, HudTheme.TEXT)
		lbl_detail.text = "[color=#%s]BU OYUNDA[/color]\n%s" % [HudTheme.ACCENT.to_html(false), DamageStats.tooltip_bbcode(slot, ink)]
		stats_well.add_child(lbl_detail)
	else:
		var lbl_hint: RichTextLabel = HudTooltip.make_rich(MenuKit.FS_SMALL, HudTheme.DIM)
		lbl_hint.text = "[color=#%s]Shift[/color] basılı tut: bu oyundaki etkisi" % HudTheme.TEXT.to_html(false)
		vbox.add_child(lbl_hint)

	hud_layer.add_child(tooltip_panel)
	_update_tooltip_position()
	if not rebuilding:
		UiAnim.reveal(tooltip_panel, 0.0, 0.12)

func _on_mouse_exited() -> void:
	if tooltip_panel and is_instance_valid(tooltip_panel):
		tooltip_panel.queue_free()
		tooltip_panel = null

func _update_tooltip_position() -> void:
	if tooltip_panel and is_instance_valid(tooltip_panel):
		HudTooltip.place_above(tooltip_panel, self)

## characters.gd'nin statik skill_desc/skill2_desc metinlerinin sonunda gömülü "(20sn bekleme)" notu var. İpucu bekleme
## süresini başlıkta CANLI gösterdiği için (bekleme süresi azaltması dahil) metindeki kopya atılır - eskiden bu sayı
## canlı değerle değiştiriliyordu (kullanıcı bildirimi: azaltma açıklamada görünmüyordu), şimdi tek yerde.
func _strip_cooldown_note(desc: String) -> String:
	var regex: RegEx = RegEx.new()
	if regex.compile("\\s*\\(\\d+(?:\\.\\d+)?\\s*sn bekleme\\)") != OK:
		return desc
	return regex.sub(desc, "", true).strip_edges()


## Açıklamanın başındaki tür ("ULTİ: ...", "YETENEK (aç/kapa): ...") -> [tür, not, gövde]. Tür yoksa ["", "", metin].
## menu_character_details.gd _split_kind ile aynı kural (karakter seçimindeki yetenek satırları).
static func _split_kind(desc: String) -> Array:
	var re := RegEx.new()
	re.compile("^\\s*((?:\\d+\\.\\s*)?[A-ZÇĞİÖŞÜ]+)\\s*(?:\\(([^)]*)\\))?\\s*:\\s*")
	var m: RegExMatch = re.search(desc)
	if m == null or m.get_string(1).length() <= 1:
		return ["", "", desc]
	var body: String = desc.substr(m.get_end())
	if m.get_string(2) != "":
		body = "(%s) %s" % [m.get_string(2), body]
	return [m.get_string(1), m.get_string(2), body]


## Pasif açıklamasının başındaki kısa ad ("Yıldırım Hızı: ...") -> [ad, gövde]; ad yoksa ["", metin]. Uzun/sayılı/virgüllü
## önek ad sayılmaz (cümlenin kendisidir).
static func _split_passive_name(desc: String) -> Array:
	var i: int = desc.find(": ")
	if i <= 0 or i > 28:
		return ["", desc]
	var head: String = desc.substr(0, i)
	if head == head.to_upper(): ## "PASİF: ..." gibi tür öneki ad değildir
		return ["", desc]
	var re := RegEx.new()
	re.compile("[0-9(),%]")
	if re.search(head) != null:
		return ["", desc]
	return [head, desc.substr(i + 2)]


## Başlıktaki bekleme yazısı: "51 sn" (azalmışsa yanında üstü çizili taban "60 sn"), yoksa "Bekleme yok".
func _cooldown_bbcode(now: float, base: float, note: String) -> String:
	if now < 0.0:
		return "[color=#%s]Bekleme yok[/color]" % HudTheme.DIM.to_html(false)
	var out: String = "[color=%s]%s sn[/color]" % [HudTheme.INK["cooldown"], _format_cd_number(now)]
	if base > 0.0 and absf(base - now) > 0.05:
		out += " [color=#%s][s]%s sn[/s][/color]" % [HudTheme.DIM.to_html(false), _format_cd_number(base)]
	if note != "":
		out += " [color=#%s]%s[/color]" % [HudTheme.DIM.to_html(false), note]
	return out


## "20" gibi tam sayılara yakın değerleri tam sayı olarak ("20"), gerçekten
## kesirli olanları ise bir ondalık basamakla ("16.8") biçimlendirir - böylece
## bekleme süresi azaltma statı olmayan karakterlerde metin eskisi gibi
## "20sn bekleme" görünmeye devam eder, tam sayı olmayan bir küsürat
## eklenmez.
func _format_cd_number(v: float) -> String:
	if abs(v - round(v)) < 0.05:
		return str(int(round(v)))
	return "%.1f" % v


## 2026-10-18: ipucu koyu HUD levhasında (hud_tooltip.gd) - renkler koyu zeminde okunan açık mürekkep tonları (TEK kaynak
## HudTheme.INK; anahtarlar UIKit.INK ile aynı, level kartları bej zeminde UIKit.INK'i kullanmaya devam eder).
func _format_lol_style(text: String) -> String:
	var ink: Dictionary = HudTheme.INK
	# Replace keywords first
	text = text.replace("ULTİ", "[color=%s][b]ULTİ[/b][/color]" % ink["damage"])
	text = text.replace("TEMEL", "[color=%s][b]TEMEL[/b][/color]" % ink["shield"])
	text = text.replace("PASİF", "[color=%s][b]PASİF[/b][/color]" % ink["passive"])
	
	# Highlight stats/mechanics
	text = text.replace("hasar", "[color=%s]hasar[/color]" % ink["damage"])
	text = text.replace("Hasar", "[color=%s]Hasar[/color]" % ink["damage"])
	text = text.replace("can", "[color=%s]can[/color]" % ink["health"])
	text = text.replace("Can", "[color=%s]Can[/color]" % ink["health"])
	text = text.replace("kalkan", "[color=%s]kalkan[/color]" % ink["shield"])
	text = text.replace("Kalkan", "[color=%s]Kalkan[/color]" % ink["shield"])
	## "mana kalkanı" tek renk olsun (yukarıdaki "kalkan" boyaması "mana"yı dışarıda bırakıyordu).
	text = text.replace("mana [color=%s]kalkan[/color]" % ink["shield"], "[color=%s]mana kalkan[/color]" % ink["shield"])
	text = text.replace("Mana [color=%s]Kalkan[/color]" % ink["shield"], "[color=%s]Mana Kalkan[/color]" % ink["shield"])
	text = text.replace("zırh", "[color=%s]zırh[/color]" % ink["shield_pen"])
	text = text.replace("Zırh", "[color=%s]Zırh[/color]" % ink["shield_pen"])
	text = text.replace("saldırı hızı", "[color=%s]saldırı hızı[/color]" % ink["attack_speed"])
	text = text.replace("bekleme", "[color=%s]bekleme[/color]" % ink["cooldown"])

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
				result += "[color=%s]" % ink["value"] + match_str + "[/color]"
			last_pos = m.get_end()
		result += text.substr(last_pos)
		text = result

	return text

## Sahnede (hud.tscn) hazır duran ama eskiden hiç bağlanmamış "Cooldown"
## Label'ı - kullanıcı isteği: "yetenekler bekleme süresindeyken geri
## sayım olsun ikonlarının üstünde". character_select.tscn'deki önizleme
## ikonlarında bu node YOK, o yüzden get_node_or_null kullanılıyor.
@onready var cooldown_label: Label = get_node_or_null("Cooldown")


## Yetenek yuvası kilidi (kullanıcı isteği 2026-09-24: "kapalı oldukları vaziyette üstlerinde 5 levelde açılacağı ve
## 10 levelde açılacağı level numaralarıyla yazsın") - > 0 iken ikon karartılır, üstte piksel asma kilit, altında açılış
## seviyesi yazar; bekleme örtüsü/sayacı gizlenir. hud.gd her karede player.get_skill_slot_unlock_level ile ayarlar.
var locked_level: int = 0
var _lock_label: Label = null

func set_locked_level(lv: int) -> void:
	if lv == locked_level:
		return
	locked_level = lv
	if lv > 0 and _lock_label == null:
		_lock_label = Label.new()
		_lock_label.name = "LockLabel"
		_lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lock_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lock_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_lock_label.offset_bottom = -frame_border * 0.5
		UIKit.style_label(_lock_label, 24, Color(1.0, 0.86, 0.55), 4)
		add_child(_lock_label)
	## Kullanıcı isteği (2026-09-24): "yetenekler level atlamasıyla açılmadan üstlerinde hangi tuşla kullanıldığı yazmasın
	## (E ve R)" - kilitliyken tuş etiketi gizli, açılınca geri gelir.
	var key_label: Node = get_node_or_null("KeyLabel")
	if key_label is CanvasItem:
		(key_label as CanvasItem).visible = lv <= 0
	if _lock_label:
		_lock_label.visible = lv > 0
		_lock_label.text = str(lv) ## sadece sayı: 52 px ikona "Lv10" sığmıyor (m5x7 24px = 18 px/harf), kilit simgesi zaten "kapalı" diyor
	_update_cooldown_label()
	queue_redraw()


func update_state(p_progress: float, p_active: bool, p_remaining: float = 0.0, p_active_fraction: float = 0.0) -> void:
	if progress < 1.0 and p_progress >= 1.0 and not p_active and locked_level <= 0 and UiAnim.is_enabled():
		_ready_flash = 1.0
		UiAnim.pop(self)
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

## DÜZELTME (kullanıcı bildirimi 2026-09-24: "necromancerın ruh pasifindeki sayı göstergesi bozuk titreşimli görünüyor"):
## hud.gd bunu HER KAREDE çağırıyor; eskiden her çağrı rozeti baştan yerleştiriyordu (font önce taban boyuta
## sıfırlanıp sığana kadar küçültülüyordu, ama Label'ın minimum boyutu override'dan hemen sonra güncellenmediği için
## ölçüm bir önceki boyuta göre yapılıyordu) -> font kareden kareye 22 <-> 20 arasında gidip geliyordu. Artık yalnızca
## sayı değişince yerleşim yapılıyor ve genişlik fontun kendisinden (get_string_size) ölçülüyor.
var _last_stack_count: int = -2

func set_stack_count(n: int) -> void:
	if stack_badge == null:
		return
	if n == _last_stack_count and stack_badge.visible == (n >= 0):
		return
	_last_stack_count = n
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
	var font: Font = stack_badge.get_theme_font("font")
	var font_size: int = _badge_base_font_size
	while font_size > STACK_BADGE_MIN_FONT and font != null \
			and font.get_string_size(stack_badge.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > fit_width:
		font_size -= 2
	stack_badge.add_theme_font_size_override("font_size", font_size)
	var badge_size: Vector2 = Vector2.ZERO
	if font != null:
		badge_size = Vector2(ceilf(font.get_string_size(stack_badge.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x), ceilf(font.get_height(font_size)))
	else:
		badge_size = stack_badge.get_combined_minimum_size()
	stack_badge.size = badge_size
	stack_badge.position = Vector2(size.x - margin - badge_size.x, margin)
	## 2026-09-26: kilit etiketiyle aynı krem yazı + koyu kontur (eskiden camgöbeği, ikon renklerine karışıyordu);
	## arkasındaki plaka _draw_badge_plate'te.
	stack_badge.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	stack_badge.add_theme_color_override("font_outline_color", PIP_OUTLINE)
	stack_badge.add_theme_constant_override("outline_size", 4)
	queue_redraw()


## Yük (şarj) göstergesi - Korsan Saatli Bomba, Assasin Şahin Hamlesi (hud.gd). Kullanıcı bildirimi (2026-09-26): "yük olan
## karakterlerin stack göstergesi doğru gösterilmiyor ve ikonlarla hiç uyumlu değil" - eski tasarım sağ-üstte (Label'ın
## font yüksekliği kadar) uzun bir kutu + etrafında saat yönünde dolan yeşil/camgöbeği çerçeveydi; sayı bomba ikonunun
## camgöbeği çizgileriyle aynı renkte okunmuyor, kutu ikonun yarısını kaplıyordu. Artık sol-üst köşede koyu ahşap bir
## plakanın üstünde maksimum yük kadar küçük PİKSEL boncuk (kilit simgesiyle aynı piksel birimi ve altın paleti): dolu =
## altın, boş = koyu, dolmakta olan = aşağıdan yukarı dolan soluk altın. count < 0 ya da max_count <= 0 = gizli.
var _charge_count: int = -1
var _charge_max: int = 0
var _charge_fraction: float = 0.0

func set_charges(count: int, max_count: int, fraction: float) -> void:
	if count == _charge_count and max_count == _charge_max and is_equal_approx(fraction, _charge_fraction):
		return
	_charge_count = count
	_charge_max = max_count
	_charge_fraction = clampf(fraction, 0.0, 1.0)
	queue_redraw()


## Sadece GERÇEKTEN bekleme süresindeyken (aktif değil ve daha hazır değil)
## sayısal geri sayımı gösterir - saniyeler yukarı yuvarlanır (3.9sn -> "4")
## klasik geri sayım hissi için.
func _update_cooldown_label() -> void:
	if cooldown_label == null:
		return
	if locked_level > 0:
		cooldown_label.visible = false
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

	if locked_level > 0:
		_draw_lock(inner)
		return

	## Buğulu bekleme örtüsü SADECE cooldown'dayken (aktif değilken) çizilir -
	## aktif süre artık kendi ayrı, kenarları daralan çerçevesiyle (aşağıda)
	## gösteriliyor, ikisi aynı anda karışmasın diye ayrıştırıldı.
	if progress < 1.0 and not is_active:
		_draw_cooldown_veil(inner, progress)
	if _ready_flash > 0.0:
		draw_rect(inner, Color(1.0, 0.96, 0.82, 0.42 * _ready_flash), true)

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

	_draw_enchant_glow(inner)
	_draw_charge_pips(inner)
	_draw_evolution_pips(inner)
	_draw_badge_plate()


## Kilitli yuva: koyu örtü + üst yarıda piksel asma kilit (gövde + halka, 1 px koyu kontur). Seviye numarası _lock_label.
func _draw_lock(inner: Rect2) -> void:
	draw_rect(inner, Color(0.04, 0.03, 0.02, 0.72), true)
	var px: float = maxf(1.0, round(inner.size.x / 22.0))
	var c := Vector2(inner.position.x + inner.size.x * 0.5, inner.position.y + inner.size.y * 0.36)
	var body := Rect2(c + Vector2(-4.0, -1.0) * px, Vector2(8.0, 6.0) * px)
	var outline := Color(0.08, 0.05, 0.03, 1.0)
	var gold := Color(0.93, 0.74, 0.3, 1.0)
	var gold_d := Color(0.7, 0.5, 0.18, 1.0)
	## halka (ters U)
	draw_rect(Rect2(c + Vector2(-4.0, -6.0) * px, Vector2(8.0, 6.0) * px), outline, true)
	draw_rect(Rect2(c + Vector2(-3.0, -5.0) * px, Vector2(6.0, 5.0) * px), gold_d, true)
	draw_rect(Rect2(c + Vector2(-2.0, -4.0) * px, Vector2(4.0, 4.0) * px), outline, true)
	draw_rect(Rect2(c + Vector2(-1.0, -3.0) * px, Vector2(2.0, 3.0) * px), Color(0.04, 0.03, 0.02, 1.0), true)
	## gövde
	draw_rect(body.grow(px), outline, true)
	draw_rect(body, gold, true)
	draw_rect(Rect2(body.position + Vector2(0.0, body.size.y - px), Vector2(body.size.x, px)), gold_d, true)
	draw_rect(Rect2(c + Vector2(-0.5, 1.0) * px, Vector2(1.0, 2.0) * px), outline, true) ## anahtar deliği


const PIP_OUTLINE := Color(0.08, 0.05, 0.03, 1.0)
const PIP_EMPTY := Color(0.24, 0.17, 0.11, 1.0)
const PIP_GOLD := Color(0.93, 0.74, 0.3, 1.0)
const PIP_GOLD_HI := Color(1.0, 0.93, 0.62, 1.0)
const PIP_FILLING := Color(0.72, 0.55, 0.24, 1.0)

## bkz. set_charges. Birim = kilit simgesiyle aynı piksel birimi (iç alan / 22). Her boncuk 2x2 birim, aralarında ve
## çevresinde 1 birim koyu kontur (ortak kenarlar paylaşılır) -> 3 yükte 10x4 birimlik plaka.
func _draw_charge_pips(inner: Rect2) -> void:
	if _charge_count < 0 or _charge_max <= 0:
		return
	var u: float = maxf(1.0, round(inner.size.x / 22.0))
	var origin: Vector2 = inner.position + Vector2(u, u)
	var plate := Rect2(origin, Vector2(1.0 + 3.0 * _charge_max, 4.0) * u)
	draw_rect(plate, PIP_OUTLINE, true)
	for i in range(_charge_max):
		var pip := Rect2(origin + Vector2(1.0 + 3.0 * i, 1.0) * u, Vector2(2.0, 2.0) * u)
		if i < _charge_count:
			draw_rect(pip, PIP_GOLD, true)
			draw_rect(Rect2(pip.position, Vector2(u, u)), PIP_GOLD_HI, true)
		else:
			draw_rect(pip, PIP_EMPTY, true)
			if i == _charge_count and _charge_fraction > 0.0:
				var h: float = round(pip.size.y * _charge_fraction)
				if h > 0.0:
					draw_rect(Rect2(pip.position + Vector2(0.0, pip.size.y - h), Vector2(pip.size.x, h)), PIP_FILLING, true)


## Sayısal rozetin (Necromancer ruh sayısı) arkasına koyu ahşap plaka - yazı kilit etiketiyle aynı krem renkte
## (bkz. _layout_stack_badge). Eski halinde plaka yoktu, camgöbeği yazı ikonun rengine karışıyordu.
func _draw_badge_plate() -> void:
	if stack_badge == null or not stack_badge.visible:
		return
	var r: Rect2 = Rect2(stack_badge.position, stack_badge.size).grow_individual(3.0, 0.0, 3.0, 0.0)
	draw_rect(r, Color(PIP_OUTLINE.r, PIP_OUTLINE.g, PIP_OUTLINE.b, 0.82), true)


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


## ---------------------------------------------------------------- Yetenek evrimleri (2026-09-28)
## Bu ikonun yuvası ("skill"/"skill2"/"skill3" - pasif/ruhani ikonlarda "").
func _evolution_slot() -> String:
	match String(name):
		"SkillIcon":
			return "skill"
		"Skill2Icon":
			return "skill2"
		"Skill3Icon":
			return "skill3"
	return ""


## İpucunun "EVRİMLER (2/5)" bölümü: bu yuvada alınmış her evrimin adı + ne yaptığı (skill_evolutions.gd metni). Yoksa "".
func _evolution_tooltip_text(player: Node) -> String:
	var slot: String = _evolution_slot()
	if slot == "" or player == null or not is_instance_valid(player) or not ("skill_evolutions" in player):
		return ""
	var char_id: int = GameManager.selected_char_id
	var owned_list: Array = SkillEvolutionsScript.owned_in_slot(char_id, slot, player.skill_evolutions)
	if owned_list.is_empty():
		return ""
	var total: int = SkillEvolutionsScript.slot_list(char_id, slot).size()
	var out: String = "[color=#%s][b]EVRİMLER (%d/%d)[/b][/color]" % [EVO_PIP_COLOR.to_html(false), owned_list.size(), total]
	for e in owned_list:
		var col: Color = EVO_PIP_FINAL if bool(e.get("final", false)) else EVO_PIP_COLOR
		out += "\n[color=#%s]%s:[/color] %s" % [col.to_html(false), str(e.get("name", "")), str(e.get("desc", ""))]
	return out


const SkillEvolutionsScript := preload("res://scripts/skill_evolutions.gd")
## Evrim boncukları: ikonun ALT kenarında, sağa yaslı - alınan evrim sayısı kadar mor (final altın) boncuk + kalanlar koyu.
## Hiç evrim yoksa çizilmez (erken oyunda ikonlar sade kalsın). hud.gd her karede player.get_evolution_progress ile ayarlar.
const EVO_PIP_COLOR := Color(0.78, 0.55, 1.0, 1.0)
const EVO_PIP_HI := Color(0.93, 0.82, 1.0, 1.0)
const EVO_PIP_FINAL := Color(1.0, 0.78, 0.35, 1.0)
var _evo_owned: int = 0
var _evo_total: int = 0
var _evo_final_owned: bool = false


func set_evolution_progress(owned: int, total: int, final_owned: bool = false) -> void:
	if owned == _evo_owned and total == _evo_total and final_owned == _evo_final_owned:
		return
	_evo_owned = owned
	_evo_total = total
	_evo_final_owned = final_owned
	queue_redraw()


func _draw_evolution_pips(inner: Rect2) -> void:
	if _evo_owned <= 0 or _evo_total <= 0:
		return
	var u: float = maxf(1.0, round(inner.size.x / 22.0))
	var w: float = (1.0 + 3.0 * _evo_total) * u
	var origin := Vector2(inner.end.x - w - u, inner.end.y - 5.0 * u)
	draw_rect(Rect2(origin, Vector2(w, 4.0 * u)), PIP_OUTLINE, true)
	for i in range(_evo_total):
		var pip := Rect2(origin + Vector2(1.0 + 3.0 * i, 1.0) * u, Vector2(2.0, 2.0) * u)
		if i < _evo_owned:
			var is_final_pip: bool = _evo_final_owned and i == _evo_total - 1
			draw_rect(pip, EVO_PIP_FINAL if is_final_pip else EVO_PIP_COLOR, true)
			draw_rect(Rect2(pip.position, Vector2(u, u)), EVO_PIP_HI, true)
		else:
			draw_rect(pip, PIP_EMPTY, true)


## ---------- Büyücü Kız "Efsunlu Büyü" (Q finali, kullanıcı isteği 2026-10-04) ----------
## "nasıl efsunlandığını yetenek butonunun parıldamasından anlayacağız" - efsunlu varyasyonu taşıyan buton altın-mor parıldar:
## nabız gibi yanan iki katlı çerçeve (dışta altın, içte mor), çerçeve boyunca dönen iki kıvılcım ve hafif iç ışık. Piksel birimi
## evrim boncuklarıyla aynı (ikonun 1/22'si - HUD'un 48x48 piksel dili). level: 0 = kapalı, 1 = tam (bu buton efsunlu), 0,5 =
## sönük (Q butonu: efsunlu yetenek DİĞER sette - set değiştir ipucu). hud.gd her karede player.is_buyucu_slot_enchanted'tan yazar.
const ENCHANT_GLOW_GOLD := Color(1.0, 0.84, 0.42, 1.0)
const ENCHANT_GLOW_VIOLET := Color(0.78, 0.5, 1.0, 1.0)
const ENCHANT_GLOW_SPARK := Color(1.0, 0.97, 0.82, 1.0)
const ENCHANT_GLOW_PULSE_SPEED := 5.0
const ENCHANT_GLOW_SPARK_SPEED := 0.45 ## çevre turu / sn
var _enchant_glow: float = 0.0
var _enchant_glow_t: float = 0.0


func set_enchant_glow(level: float) -> void:
	if is_equal_approx(level, _enchant_glow):
		return
	_enchant_glow = level
	queue_redraw()


func _draw_enchant_glow(inner: Rect2) -> void:
	if _enchant_glow <= 0.0:
		return
	var u: float = maxf(1.0, round(inner.size.x / 22.0))
	var pulse: float = 0.55 + 0.45 * sin(_enchant_glow_t * ENCHANT_GLOW_PULSE_SPEED)
	var a: float = _enchant_glow
	draw_rect(inner, Color(1.0, 0.86, 0.5, 0.12 * pulse * a), true)
	var gold: Color = ENCHANT_GLOW_GOLD
	gold.a = (0.55 + 0.45 * pulse) * a
	_draw_pixel_border(inner, u, gold)
	var violet: Color = ENCHANT_GLOW_VIOLET
	violet.a = 0.6 * pulse * a
	_draw_pixel_border(inner.grow(-u), u, violet)
	## İki kıvılcım çerçeve boyunca karşılıklı döner (artı şeklinde: 2x2 çekirdek + 1 birimlik kollar).
	var spark: Color = ENCHANT_GLOW_SPARK
	spark.a = a
	var arm: Color = gold
	arm.a = 0.8 * a
	for k in range(2):
		var f: float = fmod(_enchant_glow_t * ENCHANT_GLOW_SPARK_SPEED + 0.5 * float(k), 1.0)
		var p: Vector2 = _perimeter_point(inner.grow(-u * 0.5), f)
		p = inner.position + ((p - inner.position) / u).floor() * u
		draw_rect(Rect2(p - Vector2(u, u), Vector2(2.0 * u, 2.0 * u)), spark, true)
		draw_rect(Rect2(p + Vector2(-2.0 * u, -0.5 * u), Vector2(u, u)), arm, true)
		draw_rect(Rect2(p + Vector2(u, -0.5 * u), Vector2(u, u)), arm, true)
		draw_rect(Rect2(p + Vector2(-0.5 * u, -2.0 * u), Vector2(u, u)), arm, true)
		draw_rect(Rect2(p + Vector2(-0.5 * u, u), Vector2(u, u)), arm, true)


## Dolu dikdörtgenlerle w kalınlığında çerçeve (draw_rect'in çizgi kalınlığı köşelerde yumuşar - piksel keskin kalsın).
func _draw_pixel_border(r: Rect2, w: float, col: Color) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, w)), col, true)
	draw_rect(Rect2(Vector2(r.position.x, r.end.y - w), Vector2(r.size.x, w)), col, true)
	draw_rect(Rect2(Vector2(r.position.x, r.position.y + w), Vector2(w, r.size.y - 2.0 * w)), col, true)
	draw_rect(Rect2(Vector2(r.end.x - w, r.position.y + w), Vector2(w, r.size.y - 2.0 * w)), col, true)


## Dikdörtgen çevresinde f (0..1) oranındaki nokta - sol üstten saat yönünde.
func _perimeter_point(r: Rect2, f: float) -> Vector2:
	var per: float = 2.0 * (r.size.x + r.size.y)
	var d: float = fposmod(f, 1.0) * per
	if d < r.size.x:
		return r.position + Vector2(d, 0.0)
	d -= r.size.x
	if d < r.size.y:
		return Vector2(r.end.x, r.position.y + d)
	d -= r.size.y
	if d < r.size.x:
		return Vector2(r.end.x - d, r.end.y)
	d -= r.size.x
	return Vector2(r.position.x, r.end.y - d)
