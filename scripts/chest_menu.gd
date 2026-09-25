extends CanvasLayer

## Sandıklar artık otomatik/sırayla açıldığı için (bkz. main.gd
## _try_open_next_pending_chest) bu menü kapandığında bir sonrakinin
## açılabilmesi gerekiyor - bu sinyal tam olarak bunun için.
signal closed

var cards_container: HBoxContainer = null
var title_label: Label = null

var _player: Node = null
var _chest_tier: int = 0 ## "KADEME" - hangi dünya evresinden gelen sandık (bkz. CHEST_TITLES), eşya güç tier'ından AYRI bir kavram
## Kullanıcı isteği: "4 lü tier sistemi bundan sonra sandıklara da geliyor,
## sandık gelince üç tane gelmek yerine 1 tane gelecek ve çıkan eşyanın
## tier'ı olacak" - bu, çekilen TEK eşyanın TierSystem tier'ı (1-4,
## Sıradan/Nadir/Epik/Efsanevi). setup() doldurur, _build_card()/
## _on_al_pressed bunu okur.
var _reward_tier: int = 1
## bkz. _play_chest_open_sequence - açılış animasyonu (chest_open_anim.gd); ödül kartı bunun ağzından fırlar.
var _chest_icon: Control = null
## Sandık (kartın ARKASINDA, yerleşimden bağımsız), kartın arkasındaki ışık katmanı ve kıvılcım katmanı (en üstte).
var _stage: Control = null
var _rays_layer: Control = null
var _fx_layer: Control = null
var _rays: Node = null

## Kullanıcı isteği: "bir oyuncu sandık seçerken diğer oyuncularda ve sandık
## seçen kişide 25 saniyelik bekleme süresi olmuyor, onun da bekleme süresi
## olması gerekiyor, tıpkı level kartı seçme ekranı gibi" - level_up_screen.gd
## _on_level_up_timer_tick/_auto_pick_random_card ile AYNI desen: süre
## dolduğunda henüz karar verilmediyse rastgele (uygun/açık) bir karta
## otomatik "AL" basılmış gibi davranılır, kimse sonsuza kadar herkesi
## bekletemez.
var _has_chosen: bool = false
@onready var countdown_panel: PanelContainer = $CenterContainer/VBox/CountdownPanel
@onready var countdown_label: Label = $CenterContainer/VBox/CountdownPanel/VBox/CountdownLabel

# Chest tier titles and borders
const CHEST_TITLES := {
	0: "KADEME 1-2 SANDIK",
	1: "KADEME 3-4 SANDIK",
	2: "KADEME 5-6 SANDIK",
	3: "KADEME 7-8 SANDIK",
	4: "KADEME 9-10 SANDIK",
	5: "KADEME 11+ SANDIK"
}

## Kullanıcı isteği (2026-09-25): "sandık açarken daha iyi ve ödüllendirici heyecan uyandırıcı sandık açma animasyonu" -
## eski 4 karelik kapak açılışı (chest_tier_*.png) yerine yeni piksel sayfa + ışık/ses/flaş (bkz. chest_open_anim.gd).
const ChestOpenAnim := preload("res://scripts/chest_open_anim.gd")
const RewardReveal := preload("res://scripts/reward_reveal.gd")
const RewardRays := preload("res://scripts/reward_rays.gd")
## KULLANICI BİLDİRİMİ (2026-09-21): "Sandık açıldığında sandık özelliklerini gösteren kart ufakken yazılar kocaman kalıyor bu
## yüzden doğru düzgün görünmüyor yazıları." KÖK NEDEN: kart içeriği kenardan sadece 16 px içeride başlıyordu ama çerçeve dokusunun
## (TierSystem.FRAME_TEXTURES) süslü kenarları/mücevheri çok daha içeride - başlık çerçevenin üstüne biniyor, açıklama çerçeve
## çizgilerinin dışına taşıyor, AL/SAT butonları alt çerçeveyi örtüyordu; uzun açıklamalı eşyalarda ise sabit 24 px yazı kartı
## uzatıyordu. Artık içerik, çerçevenin İÇİNDEKİ alana oturuyor (level_up_screen.tscn Content kutusu 28/54/28/52'ydi ama yan çubuklara
## değiyordu - burada biraz daha dar); yazı boyutları o alana göre seçiliyor (_fit_card_texts: isim tek satıra, açıklama alana SIĞANA kadar küçülür).
const CARD_SIZE := Vector2(300, 480)
## 2026-09-25: kartlar savaş kartı dokusuna geçti (tools/gen_menu_kit.py tier_card) - içerik artık kenar paylarıyla değil,
## dokunun sabit bölgelerine (TierCardFx.HEADER_RECT / CREST_CENTER / RIBBON_RECT / PLAQUE_INNER_RECT) yerleşiyor. Yazılar
## m5x7'nin keskin durduğu 32 px'te (üst satır/kurdele), açıklama levhada 24 px'ten başlayıp sığana kadar küçülür.
const TierCardFx := preload("res://scripts/tier_card_fx.gd")
const CARD_TIER_FONT_SIZE := 32
const CARD_POWER_FONT_SIZE := 24
const CARD_NAME_FONT_SIZE := 32
const CARD_NAME_MIN_FONT_SIZE := 20
const CARD_DESC_FONT_SIZE := 24
const CARD_DESC_MIN_FONT_SIZE := 13
const CARD_ICON_SIZE := 96.0
const CARD_BUTTON_HEIGHT := 44.0
const CARD_BUTTON_FONT_SIZE := 24

## DÜZELTME/YENİ ÖZELLİK (kullanıcı isteği: "bundan sonra yere düşen
## sandıklardan rasgele 3 silah düşecek 3 silahtan birini seçmemiz
## gerekecek... silah almak istemeyen silahı satabilir" - kullanıcının
## seçtiği yaklaşım: "hem eşya hem silah karışık gelsin", yani her sandık
## kartı ayrı ayrı rastgele bir EŞYA ya da bir SİLAH olabilir). Bu liste
## shop_panel.gd'deki WEAPON_KEYS/UPGRADE_NAMES/WEAPON_ICON_TEXTURES ile
## BİREBİR aynı verinin bilinçli bir kopyası (WEAPON_COST_BASE aşağıda,
## shop_panel.gd'nin ESKİ COPY_COST_BASE taban fiyatlarının bir kopyasıydı -
## dükkan fiyatlandırması kullanıcı isteğiyle silah sayısına göre kademeli
## hale geldiğinden ayrıldı, ama sandık ÖNİZLEME değeri için bu sabit taban
## fiyatlar hâlâ doğru/yeterli, kasıtlı olarak DEĞİŞTİRİLMEDİ) - shop_panel.gd
## bir class_name TANIMLAMADIĞI için oradaki const'lara güvenli/açık bir
## şekilde erişmenin en basit yolu bu (diğer script'lerdeki paralel
## const kopyalama deseniyle tutarlı).
const WEAPON_KEYS := ["dagger", "fire_staff", "lightning_staff", "tabanca", "tuftuf", "tufek", "arcane", "yay", "crossbow", "boomerang", "buz_asasi", "fisek", "pence", "topuz", "uzunkilic"]
const WEAPON_NAMES := {
	"dagger": "Bıçak", "fire_staff": "Ateş Asası", "lightning_staff": "Yıldırım Asası", "tabanca": "Tabanca",
	"tuftuf": "Tüftüf", "tufek": "Tüfek", "arcane": "Arcane Asası", "yay": "Yay",
	"crossbow": "Arbalet", "boomerang": "Bumerang", "buz_asasi": "Buz Asası", "fisek": "Fişek",
	"pence": "Pençe", "topuz": "Topuz", "uzunkilic": "Uzunkılıç",
}
const WEAPON_ICON_TEXTURES := {
	"dagger": "res://assets/weapons/base_knife/icon_v2.png",
	"fire_staff": "res://assets/weapons/fire/firestaff_icon_v3.png",
	"lightning_staff": "res://assets/weapons/lightning/icon_v3.png",
	"tabanca": "res://assets/weapons/tabanca/icon_v2.png",
	"tuftuf": "res://assets/weapons/tuftuf/icon_v2.png",
	"tufek": "res://assets/weapons/tufek/icon.png",
	"arcane": "res://assets/weapons/arcane/icon_v3.png",
	"yay": "res://assets/weapons/yay/draw1.png",
	"crossbow": "res://assets/weapons/crossbow/icon.png",
	"boomerang": "res://assets/weapons/boomerang/icon.png",
	"buz_asasi": "res://assets/weapons/buz_asasi/icon_v3.png",
	"fisek": "res://assets/weapons/fisek/icon.png",
	"pence": "res://assets/weapons/pence/icon.png",
	"topuz": "res://assets/weapons/topuz/icon.png",
	"uzunkilic": "res://assets/weapons/uzunkilic/icon.png",
}
const WEAPON_COST_BASE := {
	"dagger": 60, "fire_staff": 80, "lightning_staff": 120, "tabanca": 100, "tuftuf": 90, "tufek": 100, "arcane": 110, "yay": 100,
	"crossbow": 100, "boomerang": 110, "buz_asasi": 95, "fisek": 120, "pence": 90, "topuz": 105, "uzunkilic": 100,
}

func _get_game_manager() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/GameManager")

func _get_ui_sound() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/UISound")

const ReadingUiWatcher := preload("res://scripts/reading_ui_watcher.gd")
## Sandık kart seçimi açıkken karakter okuma (read) pozuna geçer - bkz. ReadingUiWatcher.
func _enter_tree() -> void:
	add_to_group(ReadingUiWatcher.GROUP)


func setup(player: Node, chest_tier: int) -> void:
	_player = player
	_chest_tier = chest_tier

	if not title_label:
		title_label = get_node_or_null("CenterContainer/VBox/Title")
	if not cards_container:
		cards_container = get_node_or_null("CenterContainer/VBox/CardsContainer")
	if cards_container:
		cards_container.add_theme_constant_override("separation", 20)

	## 2026-09-24: oyun içi bej kit (menülerle aynı dil, bir ton koyu): sıcak karartma, kurdele başlık, kit penceresinde geri
	## sayım; kart içi yazılar koyu (CanvasLayer temayı aktarmaz - kök Control'e verilir).
	if has_node("Dim"):
		($Dim as ColorRect).color = Color(0.12, 0.07, 0.03, 0.62)
	var center_node: Control = get_node_or_null("CenterContainer") as Control
	if center_node:
		center_node.theme = UIKit.theme()
	if title_label:
		title_label.add_theme_stylebox_override("normal", UIKit.panel_style("banner"))
		UIKit.style_label(title_label, UIKit.FS_TITLE, UIKit.C_TEXT, 0)
		title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		title_label.custom_minimum_size = Vector2(0, 72)
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var cd_panel: PanelContainer = get_node_or_null("CenterContainer/VBox/CountdownPanel") as PanelContainer
	if cd_panel:
		cd_panel.add_theme_stylebox_override("panel", UIKit.panel_style("window_tight"))
		var wl: Label = cd_panel.get_node_or_null("VBox/WaitingLabel") as Label
		if wl:
			wl.add_theme_color_override("font_color", UIKit.C_TEXT)
		var cl: Label = cd_panel.get_node_or_null("VBox/CountdownLabel") as Label
		if cl:
			cl.add_theme_color_override("font_color", UIKit.C_GOLD)

	# Update Title
	if title_label:
		title_label.text = CHEST_TITLES.get(_chest_tier, "EŞYA SANDIĞI")

	# Clear existing children just in case
	if cards_container:
		for child in cards_container.get_children():
			child.queue_free()
		## Sandık açılış animasyonu bitene kadar (bkz. _play_chest_open_
		## sequence) kart alanı boş kalıyor - ödül kartı sandığın İÇİNDEN
		## çıkıyormuş gibi görünecek, o yüzden animasyon bitene kadar bu
		## container gizli.
		cards_container.visible = false

	## Kullanıcı isteği (İKİNCİ tur): "sandık gelince üç tane gelmek yerine 1
	## tane gelecek ve çıkan eşyanın tier'ı olacak çünkü bundan sonra
	## 'ekstralar' eşyalarının tierları olacak." - eskiden 3 aday sunulup biri
	## seçiliyordu (bkz. altındaki eski "silah çıkma ihtimalini kaldır" notu,
	## HÂLÂ geçerli: sadece items.gd'deki pasif eşyalar, silah havuzu yok);
	## artık TEK bir eşya + TEK bir rastgele TierSystem tier'ı (1-4,
	## level_up_screen.gd'deki kartlarla AYNI nadir dağılımı, bkz.
	## tier_system.gd) çekilip doğrudan gösteriliyor. "SAT" butonu (bkz.
	## _build_card) hâlâ duruyor - istemiyorsa altına çevirebilir.
	var item_key: String = Items.KEYS[randi() % Items.KEYS.size()]
	## Kullanıcı isteği (2026-09-24 denge turu: şans "iyi sandık çıkma oranını da arttırmalı") - ödülün kademesi
	## artık sandığı açan oyuncunun şansıyla çekilir (seviye kartlarıyla AYNI TierSystem ağırlığı).
	_reward_tier = TierSystem.roll(float(player.luck) if (player != null and "luck" in player) else 0.0)
	var candidate: Dictionary = {"type": "item", "key": item_key}

	# Connect UI sounds
	var ui_sound = _get_ui_sound()
	if ui_sound and ui_sound.has_method("connect_all_buttons"):
		ui_sound.connect_all_buttons(self)

	_play_chest_open_sequence(candidate)


## Kullanıcı isteği: "Sandıklar açılırken öncesinde sandık ekrana gelecek
## (biraz görünür olmalı boyut olarak) açma animasyonu görünecek ve içinden
## çıkan eşya kartı sandığın içinden animasyonlu olarak çıkarak oyuncuya
## gösterilecek." - 2026-09-25'ten beri tam açılış animasyonu (chest_open_anim.gd: sallanma, ışık, patlama, altınlar).
## İKİNCİ tur (aynı gün: "kart içinden fırlamış gibi görünmüyor"): sandık artık VBox'ta değil, kartın ARKASINDAKİ ayrı bir
## katmanda (_stage) ekranın ortasında durur - eskiden kart eklenince VBox yeniden yerleşip sandığı kaydırıyordu ve kart
## animasyonun tamamı + bekleme bittikten sonra sadece büyüyerek beliriyordu. Artık kapağın patladığı an (burst) kart
## sandığın ağzından fırlar (reward_reveal.gd), indiğinde parlar ve arkasında tier'a göre ışık huzmeleri yanar.
func _play_chest_open_sequence(candidate: Dictionary) -> void:
	if not cards_container:
		_reveal_reward_card(candidate) ## güvenlik ağı - sahne beklenmedik şekilde eksikse animasyonsuz devam et
		return
	var center_node: Node = get_node_or_null("CenterContainer")
	_stage = _make_layer("ChestStage")
	_rays_layer = _make_layer("RewardRays")
	if center_node:
		## Sıra: Dim, sandık, ışık, kart (CenterContainer) - kart her şeyin önünde.
		move_child(_stage, center_node.get_index())
		move_child(_rays_layer, center_node.get_index())
	_fx_layer = _make_layer("RewardFx")

	## Işığın rengi çıkacak eşyanın nadirliği (_reward_tier, setup'ta çekildi) - kart görünmeden önce ipucu.
	var anim: Control = ChestOpenAnim.new()
	anim.setup(false, _reward_tier)
	_stage.add_child(anim)
	var view: Vector2 = get_viewport().get_visible_rect().size
	anim.size = anim.custom_minimum_size
	anim.position = (view - anim.size) * 0.5
	_chest_icon = anim

	anim.pivot_offset = anim.custom_minimum_size * 0.5
	anim.scale = Vector2(0.6, 0.6)
	anim.modulate.a = 0.0
	var pop_in := create_tween()
	pop_in.set_parallel(true)
	pop_in.set_ease(Tween.EASE_OUT)
	pop_in.set_trans(Tween.TRANS_BACK)
	pop_in.tween_property(anim, "modulate:a", 1.0, 0.2)
	pop_in.tween_property(anim, "scale", Vector2.ONE, 0.3)
	anim.burst.connect(func() -> void:
		if is_instance_valid(self):
			_reveal_reward_card(candidate)
	, CONNECT_ONE_SHOT)


func _make_layer(layer_name: String) -> Control:
	var c := Control.new()
	c.name = layer_name
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


## Kart sandığın ağzından fırlar (reward_reveal.gd fly_out), AL/SAT satırları kart indikten sonra belirir; inişte parıltı +
## tier ışığı, tier 2+ kartta boşta parlama döngüsü. Sandık kart indikten sonra aşağı kayarak söner.
func _reveal_reward_card(candidate: Dictionary) -> void:
	if cards_container:
		var column = _build_card(candidate)
		## Yazı boyutu yerleşim bittikten sonra ayarlanıyor (bkz. _fit_card_texts) - o bir kareye kadar ayarsız yazı görünmesin.
		column.modulate.a = 0.0
		cards_container.add_child(column)
		cards_container.visible = true
		await get_tree().process_frame
		if not is_instance_valid(self):
			return
		_fit_card_texts(column)
		var card_panel: Control = column.get_child(0) as Control
		var buttons: Array = []
		for i in range(1, column.get_child_count()):
			var b: Control = column.get_child(i) as Control
			if b:
				b.modulate.a = 0.0
				buttons.append(b)
		column.modulate.a = 1.0
		var tier: int = int(card_panel.get_meta("reward_tier", _reward_tier)) if card_panel else _reward_tier
		if card_panel and is_instance_valid(_rays_layer):
			_rays = RewardRays.new()
			_rays_layer.add_child(_rays)
			_rays.setup(card_panel, CARD_SIZE, 3.0, tier, false)
		if card_panel:
			## Sütunun tamamı uçar (kart + gizli butonlar); pivot kartın ortası.
			var mouth: Vector2 = RewardReveal.chest_mouth(_chest_icon) if is_instance_valid(_chest_icon) else card_panel.get_global_rect().get_center()
			RewardReveal.launch_sparks(_fx_layer, mouth, tier, false)
			var tw: Tween = RewardReveal.fly_out(self, column, mouth, 0.0, 0.08, card_panel.position + card_panel.size * 0.5)
			tw.tween_callback(func() -> void:
				if not is_instance_valid(card_panel):
					return
				var frame: TextureRect = card_panel.get_node_or_null("Frame") as TextureRect
				RewardReveal.land_fx(self, card_panel, frame, tier, false, _fx_layer, _rays)
				TierCardFx.start_idle_shine(self, frame, tier, 1.2)
				for b in buttons:
					if is_instance_valid(b):
						create_tween().tween_property(b, "modulate:a", 1.0, 0.2)
				_hide_chest()
			)
	elif is_instance_valid(_chest_icon):
		_hide_chest()

	## bkz. dosya başındaki _has_chosen notu - geri sayım main.gd tarafından
	## zaten başlatılmış durumda (bkz. _try_open_next_pending_chest
	## NetworkManager.start_chest_countdown), burada sadece gösterilip
	## dinleniyor - level_up_screen.gd _ready()'deki AYNI desen. Açılış
	## animasyonu bitene kadar BAĞLANMIYOR ki 25sn süresi tam o birkaç
	## onda saniyelik pencerede dolarsa henüz var olmayan bir karta
	## otomatik basmaya çalışılmasın (bkz. _on_countdown_tick).
	if NetworkManager.is_multiplayer_active:
		NetworkManager.chest_countdown_tick.connect(_on_countdown_tick)
		if countdown_panel:
			countdown_panel.visible = NetworkManager.chest_countdown_active
			if countdown_panel.visible and countdown_label:
				countdown_label.text = "%ds" % int(ceil(NetworkManager.chest_countdown))


## Açık sandığı kart indikten sonra aşağı kaydırıp söndürür.
func _hide_chest() -> void:
	if not is_instance_valid(_chest_icon):
		return
	var chest: Control = _chest_icon
	var tw := create_tween().set_parallel(true)
	tw.tween_property(chest, "modulate:a", 0.0, 0.3).set_delay(0.1)
	tw.tween_property(chest, "position:y", chest.position.y + 40.0, 0.4).set_delay(0.1).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(chest):
			chest.queue_free()
	)


## Kullanıcı isteği (2026-09-24): "sandık açma kartında 1 tuşu alma tuşunu 2 tuşu satma tuşunu tetikleyecek şekilde
## kısayollansın. butonlara dokunma" - level_up_screen.gd _unhandled_input'la AYNI desen: tuş, ilgili butonun pressed
## sinyalini (fare tıklamasıyla birebir aynı yol) tetikler; butonların kendisi/görünümü değişmedi. Kart henüz açılış
## animasyonundayken (kart yok), AL devre dışıyken (SLOTLAR DOLU) ya da sohbet yazılırken hiçbir şey yapmaz.
func _unhandled_input(event: InputEvent) -> void:
	if _has_chosen or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var meta_key: String = ""
	match event.keycode:
		KEY_1, KEY_KP_1:
			meta_key = "al_button"
		KEY_2, KEY_KP_2:
			meta_key = "sat_button"
	if meta_key == "" or not cards_container:
		return
	if _player and is_instance_valid(_player) and bool(_player.get("is_chat_typing")):
		return
	for card in cards_container.get_children():
		if not card.has_meta(meta_key):
			continue
		var btn: Button = card.get_meta(meta_key)
		if is_instance_valid(btn) and not btn.disabled:
			get_viewport().set_input_as_handled()
			btn.pressed.emit()
		return


func _on_countdown_tick(remaining: float) -> void:
	if countdown_panel:
		countdown_panel.visible = true
	if countdown_label:
		countdown_label.text = "%ds" % int(ceil(remaining))
	if remaining <= 0.0 and not _has_chosen:
		_auto_pick_random_card()


## Süre dolduğunda henüz karar verilmediyse (bkz. yukarıdaki _on_countdown_tick)
## uygun (slotu dolu olmayan) kartlardan rastgele biri "AL" tıklanmış gibi
## seçilir - hiçbiri uygun değilse (tüm slotlar doluysa) sandık ödülü boşa
## harcanıp menü kapatılır, herkes sonsuza kadar bu karara takılı kalmaz.
func _auto_pick_random_card() -> void:
	if _has_chosen or not cards_container:
		return
	var eligible: Array = []
	for card in cards_container.get_children():
		if card.has_meta("al_button"):
			var al: Button = card.get_meta("al_button")
			if is_instance_valid(al) and not al.disabled:
				eligible.append(al)
	if eligible.is_empty():
		_close()
		return
	var al_btn: Button = eligible[randi() % eligible.size()]
	al_btn.pressed.emit()

## DÜZELTME/YENİ ÖZELLİK: artık ham bir item_key yerine {"type","key"}
## şeklinde bir aday alıyor - bkz. setup() üstündeki not. type=="weapon"
## için isim/ikon/maliyet WEAPON_* sabitlerinden, type=="item" için (eskisi
## gibi) Items.get_def()'ten okunuyor.
## Kullanıcı isteği: "çıkan eşyanın tier'ı olacak" - _reward_tier (1-4, bkz.
## setup()) SADECE eşyalar (is_weapon==false) için geçerli; kartın çerçeve
## rengini VE yeni bir tier-adı etiketini (Sıradan/Nadir/Epik/Efsanevi,
## TierSystem ile level atlama kartlarıyla AYNI görsel dil) belirler. Gerçek
## güç çarpanı (bkz. Items.ITEM_TIER_POWER) _on_al_pressed'e kadar taşınır.
func _build_card(candidate: Dictionary) -> Control:
	var card_type: String = candidate.get("type", "item")
	var item_key: String = candidate.get("key", "")
	var is_weapon: bool = card_type == "weapon"
	var item_def: Dictionary = {} if is_weapon else Items.get_def(item_key)
	var display_name: String = WEAPON_NAMES.get(item_key, item_key.capitalize()) if is_weapon else item_def.get("name", item_key.capitalize())
	var desc_text: String = "Yeni bir silah - kalıcı olarak edinilir." if is_weapon else item_def.get("desc", "")
	var icon_path: String = WEAPON_ICON_TEXTURES.get(item_key, "") if is_weapon else ("res://assets/generated/item_" + item_key + "_frame_0.png")
	var cost_base: int = WEAPON_COST_BASE.get(item_key, 80) if is_weapon else int(item_def.get("cost_base", 50))
	var power_mult: float = 1.0 if is_weapon else Items.ITEM_TIER_POWER[_reward_tier - 1]

	## 2026-09-25 savaş kartı (bkz. scripts/tier_card_fx.gd): kart dokusu artık sabit bölgelere bölünmüş (üst satır / kalkan
	## arması / tier kurdelesi / parşömen levha). Eşyaların açıklamaları uzun (250 karaktere kadar) - AL/SAT butonları levhaya
	## sığmayıp açıklamayı okunmaz boyuta küçülteceği için kartın ALTINA taşındı: CardsContainer'a eklenen öğe artık kart +
	## buton satırlarından oluşan bir sütun (name_label/desc_label/al_button/sat_button meta'ları sütunda - _unhandled_input,
	## _auto_pick_random_card ve _fit_card_texts onları cards_container çocuklarından okur).
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)

	# 1. Main Card Container
	var card := PanelContainer.new()
	column.add_child(card)
	## Kullanıcı isteği: "sandık ödülü seçim kartı level kartlarıyla aynı
	## boyutlarda görünsün" - level_up_screen.tscn'deki Card1/2/3 ile birebir
	## aynı boyut. DÜZELTME (kullanıcı isteği: "kartları büyütmekle ilgili
	## değişikliği geri al") - level kartları 300x480'e döndürülünce bu da
	## eşleşmeye devam etsin diye AYNI şekilde 300x480'e döndürüldü (eski
	## 238x406'ya DEĞİL - o değer zaten level kartlarıyla eşleşmiyordu, bu
	## yüzden ilk etapta düzeltilmişti).
	card.custom_minimum_size = CARD_SIZE # Match level up card dimensions

	var sb := StyleBoxFlat.new()
	## Kullanıcı isteği: "sandık ödülü seçme kartı da tiera bağlı olarak level
	## atlama kartları gibi olmalı (aynı kartları kullan arkaplan için)" ve
	## (İKİNCİ tur) "tierı olmayanlar tier 1 kartı kullanmalı" - HER kart
	## (eşya/silah fark etmeksizin) artık düz renk yerine TierSystem.FRAME_
	## TEXTURES (level_up_screen.gd ile PAYLAŞILAN aynı 4 doku) bir "Frame"
	## TextureRect olarak arkaya ekleniyor, panelin kendi StyleBoxFlat'ı
	## SADECE gölge için var, tamamen saydam. Silahın (is_weapon) tier'ı
	## olmadığı için varsayılan olarak tier 1 (Sıradan, gri) kullanılır.
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(12)
	## DÜZELTME (kullanıcı isteği: "sandık seçim ekranı kartlarına dışlarına
	## çerçeve eklemeni istiyorum hafif gölgesi olsun ve panele sızsın, böyle
	## çok çiğ duruyorlar") - kartın kenarlığının hemen dışına, arkaplana
	## doğru yumuşakça yayılan hafif bir gölge eklendi.
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(3, 4)
	card.add_theme_stylebox_override("panel", sb)

	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## KRİTİK: expand_mode verilmezse TextureRect'in minimum boyutu
	## DOKUNUN GERÇEK piksel boyutu (499x665) olur ve bu, anchor'ların
	## kartı küçültme isteğini EZER - kart devasa bir kareye dönüşür
	## (bkz. merchant_shop_screen.gd _build_card'daki AYNI hata/notu -
	## seyyar satıcı ekranında kullanıcı ekran görüntüsüyle yakalandı).
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	TierCardFx.apply_frame(frame, _reward_tier if not is_weapon else 1)
	card.set_meta("reward_tier", _reward_tier if not is_weapon else 1)
	card.add_child(frame)

	## Bölgeler TierCardFx'teki dikdörtgenlere mutlak konumla yerleşiyor (PanelContainer çocuğu düz bir Control kartı kaplar).
	var layout := Control.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(layout)

	# 2. Üst satır: eşya/silah adı (koyu tier zemini üstünde krem yazı). Uzunsa _fit_card_texts tek satıra sığana dek küçültür.
	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.position = TierCardFx.HEADER_RECT.position
	name_lbl.size = TierCardFx.HEADER_RECT.size
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.style_label(name_lbl, CARD_NAME_FONT_SIZE, UIKit.C_CREAM, 4)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_lbl.clip_text = false
	layout.add_child(name_lbl)
	## Ağaca girmeden önce Label en küçük boyutunu varsayılan temanın büyük yazısıyla ölçüp kutusunu büyütüyor (375x70) ve bir
	## daha küçültmüyor - doğru boyut, kart ağaca eklendikten sonra (ertelenmiş) yeniden verilir.
	name_lbl.set_deferred("size", TierCardFx.HEADER_RECT.size)
	column.set_meta("name_label", name_lbl)

	# 3. İkon: kalkan armasının parşömen yüzünde (eşya ikonları 32x32 -> 3x = kartın kendi 3 px piksel yoğunluğu).
	var icon_rect := TextureRect.new()
	icon_rect.size = Vector2(CARD_ICON_SIZE, CARD_ICON_SIZE)
	icon_rect.position = TierCardFx.CREST_CENTER - icon_rect.size * 0.5
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path) as Texture2D
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(icon_rect)

	# 4. Kurdele: tier adı (silahların tier'ı yok - "Silah").
	var tier_lbl := Label.new()
	tier_lbl.text = "Silah" if is_weapon else TierSystem.NAMES[_reward_tier - 1]
	tier_lbl.position = TierCardFx.RIBBON_RECT.position
	tier_lbl.size = TierCardFx.RIBBON_RECT.size
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.style_label(tier_lbl, CARD_TIER_FONT_SIZE, UIKit.C_CREAM, 4)
	layout.add_child(tier_lbl)
	tier_lbl.set_deferred("size", TierCardFx.RIBBON_RECT.size) ## bkz. name_lbl notu

	# 5. Parşömen levha: güç yüzdesi (eşyalar) + açıklama.
	var vbox := VBoxContainer.new()
	vbox.position = TierCardFx.PLAQUE_INNER_RECT.position
	vbox.size = TierCardFx.PLAQUE_INNER_RECT.size
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(vbox)
	if not is_weapon:
		var power_lbl := Label.new()
		power_lbl.text = "%%%d güç" % int(round(power_mult * 100.0))
		power_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIKit.style_label(power_lbl, CARD_POWER_FONT_SIZE, UIKit.C_GOLD, 0)
		vbox.add_child(power_lbl)

	## (2026-09-21) Label -> RichTextLabel (level atlama kartlarındaki Desc ile aynı tür): autowrap'lı bir Label metnin yüksekliğini
	## kartın MİNİMUM boyutuna yansıtıp kartı uzatıyordu; fit_content'siz RichTextLabel ise kalan alana sabit sığar ve
	## _fit_card_texts uzun açıklamayı o alana SIĞANA kadar küçültür.
	var desc_lbl := RichTextLabel.new()
	desc_lbl.bbcode_enabled = true
	desc_lbl.fit_content = false
	desc_lbl.scroll_active = false
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_lbl.text = "[center]%s[/center]" % desc_text.replace("[", "[lb]")
	desc_lbl.add_theme_color_override("default_color", UIKit.C_TEXT)
	_set_desc_font_size(desc_lbl, CARD_DESC_FONT_SIZE)
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)
	column.set_meta("desc_label", desc_lbl)

	# Check slots limit (SİLAH ve EŞYA için AYRI limitler - bkz. is_weapon)
	var has_slots: bool = true
	var gm = _get_game_manager()
	if is_weapon:
		if _player and gm and "owned_weapons" in gm:
			var max_w: int = 5
			if _player.has_method("get_max_owned_weapons"):
				max_w = _player.get_max_owned_weapons()
			has_slots = gm.owned_weapons.size() < max_w
	elif _player and gm and "owned_items" in gm:
		var current_items: int = gm.owned_items.size()
		var max_slots: int = 1
		if _player.has_method("get_max_item_slots"):
			max_slots = _player.get_max_item_slots()
		has_slots = current_items < max_slots

	## Kullanıcı isteği: "oyundaki bütün butonları bununla değiştirmeni
	## istiyorum" - eski yeşil (Al)/kırmızı (Sat) renk ayrımı kaldırıldı,
	## artık oyundaki HER buton gibi ShopPanel'in paylaşılan ahşap plaka
	## stiline sahipler (bkz. shop_panel.gd _apply_wood_button_style).
	
	# 7. Al Button
	## Kullanıcı isteği: "alma ve satma butonlarındaki fontlar dahil" - level
	## atlama kartlarının en küçük kart-içi fontuyla (CountLabel, 28) aynı
	## boyuta getirildi. Sonraki istek ("kartların boyutunu %30 küçült ...
	## butonlar bu değişikliğe uyumlu olmalı"): buton yüksekliği kartla
	## birlikte küçüldü (50->44) ama büyüyen 28px fontu hâlâ rahat sığdıracak
	## kadar bırakıldı.
	var al_btn := Button.new()
	al_btn.custom_minimum_size = Vector2(0, CARD_BUTTON_HEIGHT)
	al_btn.add_theme_font_size_override("font_size", CARD_BUTTON_FONT_SIZE)
	## DÜZELTME (kullanıcı isteği: "butonlardaki yazıların rengini beyaz
	## yapıp dışlarına siyah kontür ekle") - eskiden burada krem rengi bir
	## font_color override'ı vardı, artık kaldırıldı ki tüm butonlarla AYNI
	## şekilde temanın (theme.tres) beyaz+siyah kontürlü varsayılanını alsın.
	## 2026-09-24: AL = onay (adaçayı), SAT = ten - kit butonları, koyu yazı.
	UIKit.style_button(al_btn, "green", false, CARD_BUTTON_FONT_SIZE)
	if has_slots:
		al_btn.text = "AL"
	else:
		al_btn.text = "SLOTLAR DOLU"
		al_btn.disabled = true
	al_btn.pressed.connect(_on_al_pressed.bind(candidate, cost_base, power_mult))
	column.add_child(al_btn)
	## bkz. _auto_pick_random_card - süre dolduğunda hangi kartların hâlâ
	## seçilebilir ("AL" tıklanabilir) olduğunu bulmak için doğrudan referans.
	column.set_meta("al_button", al_btn)

	# 8. Sat Button
	var refund_gold: int = int(round(cost_base * 0.7))
	var sat_btn := Button.new()
	sat_btn.custom_minimum_size = Vector2(0, CARD_BUTTON_HEIGHT)
	sat_btn.add_theme_font_size_override("font_size", CARD_BUTTON_FONT_SIZE)
	## bkz. al_btn üstündeki ayni not - font_color override'i kaldirildi.
	UIKit.style_button(sat_btn, "wood", false, CARD_BUTTON_FONT_SIZE)
	sat_btn.text = "SAT (+%d Altın)" % refund_gold
	sat_btn.pressed.connect(_on_sat_pressed.bind(item_key, refund_gold))
	column.add_child(sat_btn)
	column.set_meta("sat_button", sat_btn) ## bkz. _unhandled_input (2 kısayolu)
	
	return column

static func _set_desc_font_size(desc_lbl: RichTextLabel, font_size: int) -> void:
	for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		desc_lbl.add_theme_font_size_override(key, font_size)


## Kart yerleşimi bittikten SONRA (etiketlerin gerçek boyutu belli) yazıları kartın iç alanına sığdırır: isim tek satıra sığana
## kadar küçülür (alt sınır CARD_NAME_MIN_FONT_SIZE, o da yetmezse alt satıra kayar); açıklama CARD_DESC_FONT_SIZE'dan başlayıp
## metnin yüksekliği ayrılan alana SIĞANA kadar (alt sınır CARD_DESC_MIN_FONT_SIZE) küçülür. Kısa metinler tam boyutta kalır.
func _fit_card_texts(card: Control) -> void:
	var name_lbl: Label = card.get_meta("name_label", null) as Label
	if name_lbl and is_instance_valid(name_lbl) and name_lbl.size.x > 0.0:
		var font: Font = name_lbl.get_theme_font("font")
		var fs: int = CARD_NAME_FONT_SIZE
		while fs > CARD_NAME_MIN_FONT_SIZE and font.get_string_size(name_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > name_lbl.size.x:
			fs -= 1
		name_lbl.add_theme_font_size_override("font_size", fs)
		if font.get_string_size(name_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > name_lbl.size.x:
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var desc_lbl: RichTextLabel = card.get_meta("desc_label", null) as RichTextLabel
	if desc_lbl and is_instance_valid(desc_lbl) and desc_lbl.size.y > 0.0:
		var dfs: int = CARD_DESC_FONT_SIZE
		_set_desc_font_size(desc_lbl, dfs)
		while dfs > CARD_DESC_MIN_FONT_SIZE and float(desc_lbl.get_content_height()) > desc_lbl.size.y:
			dfs -= 1
			_set_desc_font_size(desc_lbl, dfs)


## DÜZELTME/YENİ ÖZELLİK: artık candidate dict alıyor ({"type","key"}, bkz.
## setup() üstündeki not) - type=="weapon" ise bedava bir silah kopyası
## veriliyor (shop_panel.gd _on_buy_copy ile AYNI desen ama gold_HARCAMADAN -
## sandık ödülü ücretsizdir, tıpkı eşyalar gibi), type=="item" ise eskisi
## gibi davranıyor.
## power_mult: bkz. _build_card üstündeki not - sandıktan çekilen eşyanın
## tier'ına göre güç çarpanı (Items.ITEM_TIER_POWER), player.buy_item()'a
## AYNEN iletilir VE owned_items kaydına "power" olarak yazılır ki eşya
## envanterden satılınca (bkz. player.gd remove_owned_item) AYNI çarpanla
## geri alınsın - yoksa Tier 2+ bir eşya satıldığında fazlası kalıcı kalırdı.
func _on_al_pressed(candidate: Dictionary, item_cost: int, power_mult: float = 1.0) -> void:
	_has_chosen = true
	if not _player or not is_instance_valid(_player):
		_close()
		return

	var gm = _get_game_manager()
	if not gm:
		_close()
		return

	var item_key: String = candidate.get("key", "")
	if candidate.get("type", "item") == "weapon":
		var max_w: int = 5
		if _player.has_method("get_max_owned_weapons"):
			max_w = _player.get_max_owned_weapons()
		if gm.owned_weapons.size() >= max_w:
			return
		## shop_panel.gd _on_buy_copy ile AYNI sıra: önce deftere (owned_weapons)
		## ekle, sonra gerçek silah node'unu spawn et - tek fark burada gold
		## hiç harcanmıyor (sandık ödülü).
		gm.owned_weapons.append({"key": item_key, "level": 1, "spent": 0})
		if _player.has_method("buy_weapon_copy"):
			_player.buy_weapon_copy(item_key, 1)
		_close()
		return

	# Double check slots just in case
	var max_slots: int = 1
	if _player.has_method("get_max_item_slots"):
		max_slots = _player.get_max_item_slots()

	if gm.owned_items.size() >= max_slots:
		return

	if _player.has_method("buy_item") and _player.buy_item(item_key, power_mult):
		gm.owned_items.append({"key": item_key, "spent": item_cost, "power": power_mult, "tier": _reward_tier})

	_close()

func _on_sat_pressed(_item_key: String, refund_amount: int) -> void:
	_has_chosen = true
	var gm = _get_game_manager()
	if gm:
		gm.gold += refund_amount
	_spawn_gold_floating_text(refund_amount)
	_close()

func _spawn_gold_floating_text(amount: int) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var FloatingTextScene = load("res://scenes/floating_text.tscn")
	if FloatingTextScene:
		var ft = FloatingTextScene.instantiate()
		get_tree().current_scene.add_child(ft)
		ft.follow_target = _player
		ft.follow_offset = Vector2(0, -30)
		ft.global_position = _player.global_position + Vector2(0, -30)
		ft.setup("+%d" % amount, Color(1.0, 0.82, 0.2), true)

func _close() -> void:
	if NetworkManager.chest_countdown_tick.is_connected(_on_countdown_tick):
		NetworkManager.chest_countdown_tick.disconnect(_on_countdown_tick)
	get_tree().paused = false
	closed.emit()
	queue_free()
