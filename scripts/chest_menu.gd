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
## bkz. _play_chest_open_sequence - açılış animasyonu için kullanılan sandık
## görseli (chest_drop.gd'deki DÜNYA sandığıyla AYNI doku/tier eşlemesi).
var _chest_icon: TextureRect = null

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

const PAL_CONTENT_BG := Color(0.239, 0.2, 0.149, 1.0)
const PAL_ACCENT := Color(0.83, 0.56, 0.30, 1.0)

# Chest tier titles and borders
const CHEST_TITLES := {
	0: "KADEME 1-2 SANDIK",
	1: "KADEME 3-4 SANDIK",
	2: "KADEME 5-6 SANDIK",
	3: "KADEME 7-8 SANDIK",
	4: "KADEME 9-10 SANDIK",
	5: "KADEME 11+ SANDIK"
}

## chest_drop.gd'deki DÜNYA sandığı dokularıyla BİREBİR aynı (bilinçli kopya -
## o script bir class_name TANIMLAMIYOR, bkz. dosya başındaki WEAPON_* notu
## ile AYNI gerekçe). Her doku 32x128px, dikey 4 kare (hframes=1, vframes=4) -
## kare 0 kapalı sandık, kare 3 tam açık. Kullanıcı isteği: "sandıklar
## açılırken öncesinde sandık ekrana gelecek... açma animasyonu görünecek" -
## bkz. _play_chest_open_sequence.
const CHEST_TEXTURES := {
	0: "res://assets/sprites/chest_tier_1_2.png",
	1: "res://assets/sprites/chest_tier_3_4.png",
	2: "res://assets/sprites/chest_tier_5_6.png",
	3: "res://assets/sprites/chest_tier_7_8.png",
	4: "res://assets/sprites/chest_tier_9_10.png",
	5: "res://assets/sprites/chest_tier_11_up.png",
}
## KULLANICI BİLDİRİMİ (2026-09-21): "Sandık açıldığında sandık özelliklerini gösteren kart ufakken yazılar kocaman kalıyor bu
## yüzden doğru düzgün görünmüyor yazıları." KÖK NEDEN: kart içeriği kenardan sadece 16 px içeride başlıyordu ama çerçeve dokusunun
## (TierSystem.FRAME_TEXTURES) süslü kenarları/mücevheri çok daha içeride - başlık çerçevenin üstüne biniyor, açıklama çerçeve
## çizgilerinin dışına taşıyor, AL/SAT butonları alt çerçeveyi örtüyordu; uzun açıklamalı eşyalarda ise sabit 24 px yazı kartı
## uzatıyordu. Artık içerik, çerçevenin İÇİNDEKİ alana oturuyor (level_up_screen.tscn Content kutusu 28/54/28/52'ydi ama yan çubuklara
## değiyordu - burada biraz daha dar); yazı boyutları o alana göre seçiliyor (_fit_card_texts: isim tek satıra, açıklama alana SIĞANA kadar küçülür).
const CARD_SIZE := Vector2(300, 480)
## Yanlar 46: çerçevenin yan çubukları kart kenarından ~32-42 px arasında (28 olunca yazı/butonlar çubuğa biniyordu); üst 64: üstteki
## elmas süsü kart içine ~57 px sarkıyor (54'te tier yazısı elmasın altına giriyordu).
const CARD_PAD_LEFT := 46
const CARD_PAD_RIGHT := 46
const CARD_PAD_TOP := 64
const CARD_PAD_BOTTOM := 52
const CARD_TIER_FONT_SIZE := 20
const CARD_NAME_FONT_SIZE := 34
const CARD_NAME_MIN_FONT_SIZE := 20
const CARD_DESC_FONT_SIZE := 24
const CARD_DESC_MIN_FONT_SIZE := 13
const CARD_ICON_SIZE := 64.0
const CARD_BUTTON_HEIGHT := 38.0
const CARD_BUTTON_FONT_SIZE := 24
const CHEST_ICON_DISPLAY_SIZE := 176.0 ## kullanıcı isteği: "biraz görünür olmalı boyut olarak"
const CHEST_OPEN_FRAME_DELAY := 0.15 ## dünya sandığındaki 0.08sn'den biraz daha yavaş - UI'da daha net okunsun diye

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

func setup(player: Node, chest_tier: int) -> void:
	_player = player
	_chest_tier = chest_tier

	if not title_label:
		title_label = get_node_or_null("CenterContainer/VBox/Title")
	if not cards_container:
		cards_container = get_node_or_null("CenterContainer/VBox/CardsContainer")
	if cards_container:
		cards_container.add_theme_constant_override("separation", 20)

	# Load theme
	var theme_res = load("res://assets/fonts/theme.tres")
	if theme_res and has_node("Dim"):
		$Dim.theme = theme_res

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
	_reward_tier = TierSystem.roll()
	var candidate: Dictionary = {"type": "item", "key": item_key}

	# Connect UI sounds
	var ui_sound = _get_ui_sound()
	if ui_sound and ui_sound.has_method("connect_all_buttons"):
		ui_sound.connect_all_buttons(self)

	_play_chest_open_sequence(candidate)


## Kullanıcı isteği: "Sandıklar açılırken öncesinde sandık ekrana gelecek
## (biraz görünür olmalı boyut olarak) açma animasyonu görünecek ve içinden
## çıkan eşya kartı sandığın içinden animasyonlu olarak çıkarak oyuncuya
## gösterilecek." - chest_drop.gd'deki DÜNYA sandığının AYNI 4 kareli açılış
## animasyonunu (bkz. CHEST_TEXTURES notu) burada, ödül ekranında tekrar
## oynatır; son karede ödül kartı sandığın konumundan/küçük boyuttan
## büyüyerek/kayarak "çıkar" (bkz. _reveal_reward_card).
func _play_chest_open_sequence(candidate: Dictionary) -> void:
	var vbox: VBoxContainer = get_node_or_null("CenterContainer/VBox")
	if not vbox or not cards_container:
		_reveal_reward_card(candidate) ## güvenlik ağı - sahne beklenmedik şekilde eksikse animasyonsuz devam et
		return

	_chest_icon = TextureRect.new()
	_chest_icon.custom_minimum_size = Vector2(CHEST_ICON_DISPLAY_SIZE, CHEST_ICON_DISPLAY_SIZE)
	_chest_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_chest_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var tex_path: String = CHEST_TEXTURES.get(_chest_tier, CHEST_TEXTURES[0])
	var full_tex: Texture2D = load(tex_path) as Texture2D
	_chest_icon.texture = _chest_frame_texture(full_tex, 0)
	vbox.add_child(_chest_icon)
	vbox.move_child(_chest_icon, cards_container.get_index())

	_chest_icon.scale = Vector2(0.6, 0.6)
	_chest_icon.pivot_offset = Vector2(CHEST_ICON_DISPLAY_SIZE, CHEST_ICON_DISPLAY_SIZE) * 0.5
	_chest_icon.modulate.a = 0.0
	var pop_in := create_tween()
	pop_in.set_parallel(true)
	pop_in.set_ease(Tween.EASE_OUT)
	pop_in.set_trans(Tween.TRANS_BACK)
	pop_in.tween_property(_chest_icon, "modulate:a", 1.0, 0.2)
	pop_in.tween_property(_chest_icon, "scale", Vector2.ONE, 0.3)
	await pop_in.finished
	if not is_instance_valid(self):
		return

	## Kapalıdan (kare 0) tam açığa (kare 3) - dünya sandığındaki AYNI kare
	## sırası, UI'da biraz daha yavaş (CHEST_OPEN_FRAME_DELAY).
	for frame in range(1, 4):
		if not is_instance_valid(self):
			return
		await get_tree().create_timer(CHEST_OPEN_FRAME_DELAY).timeout
		if not is_instance_valid(_chest_icon) or not is_instance_valid(self):
			return
		_chest_icon.texture = _chest_frame_texture(full_tex, frame)
		## Her karede küçük bir "sarsıntı" - açılışın hissedilir olması için.
		var shake := create_tween()
		shake.tween_property(_chest_icon, "rotation", deg_to_rad(6.0), 0.05)
		shake.tween_property(_chest_icon, "rotation", deg_to_rad(-6.0), 0.08)
		shake.tween_property(_chest_icon, "rotation", 0.0, 0.05)

	await get_tree().create_timer(0.12).timeout
	if not is_instance_valid(self):
		return
	_reveal_reward_card(candidate)


func _chest_frame_texture(full_tex: Texture2D, frame: int) -> Texture2D:
	if not full_tex:
		return null
	var frame_h: float = full_tex.get_height() / 4.0
	var atlas := AtlasTexture.new()
	atlas.atlas = full_tex
	atlas.region = Rect2(0.0, frame_h * float(frame), full_tex.get_width(), frame_h)
	return atlas


## Açık sandığı soldurup ödül kartını onun konumundan küçük/saydam başlatıp
## normal boyutuna/konumuna büyüterek "çıkarır" - _animate_cards_in'in eski
## (3 kartlık) versiyonunun yerini alıyor, artık TEK kart için ve sandığın
## konumundan başlıyor.
func _reveal_reward_card(candidate: Dictionary) -> void:
	if cards_container:
		var card = _build_card(candidate)
		## Yazı boyutu yerleşim bittikten sonra ayarlanıyor (bkz. _fit_card_texts) - o bir kareye kadar ayarsız yazı görünmesin.
		card.modulate.a = 0.0
		cards_container.add_child(card)
		cards_container.visible = true
		await get_tree().process_frame
		if not is_instance_valid(self):
			return
		_fit_card_texts(card)
		if card is Control:
			card.pivot_offset = card.size * 0.5
			var final_pos: Vector2 = card.position
			var final_scale: Vector2 = card.scale
			card.scale = final_scale * 0.35
			card.modulate.a = 0.0
			if is_instance_valid(_chest_icon):
				## Sandığın global konumunu kartın yerel (container-içi)
				## konum uzayına çevirip başlangıç noktası yapıyoruz - kart
				## gerçekten sandığın olduğu yerden çıkıyormuş gibi görünür.
				var chest_center: Vector2 = _chest_icon.get_global_rect().get_center()
				var card_parent_pos: Vector2 = card.get_parent().get_global_transform().affine_inverse() * chest_center
				card.position = card_parent_pos - card.size * 0.5
			var out_tween := create_tween()
			out_tween.set_parallel(true)
			out_tween.set_ease(Tween.EASE_OUT)
			out_tween.set_trans(Tween.TRANS_BACK)
			out_tween.tween_property(card, "modulate:a", 1.0, 0.28)
			out_tween.tween_property(card, "scale", final_scale, 0.32)
			out_tween.tween_property(card, "position", final_pos, 0.32)
	if is_instance_valid(_chest_icon):
		var fade_out := create_tween()
		fade_out.tween_property(_chest_icon, "modulate:a", 0.0, 0.25).set_delay(0.15)
		fade_out.tween_callback(func():
			if is_instance_valid(_chest_icon):
				_chest_icon.queue_free()
		)

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
func _build_card(candidate: Dictionary) -> PanelContainer:
	var card_type: String = candidate.get("type", "item")
	var item_key: String = candidate.get("key", "")
	var is_weapon: bool = card_type == "weapon"
	var item_def: Dictionary = {} if is_weapon else Items.get_def(item_key)
	var display_name: String = WEAPON_NAMES.get(item_key, item_key.capitalize()) if is_weapon else item_def.get("name", item_key.capitalize())
	var desc_text: String = "Yeni bir silah - kalıcı olarak edinilir." if is_weapon else item_def.get("desc", "")
	var icon_path: String = WEAPON_ICON_TEXTURES.get(item_key, "") if is_weapon else ("res://assets/generated/item_" + item_key + "_frame_0.png")
	var cost_base: int = WEAPON_COST_BASE.get(item_key, 80) if is_weapon else int(item_def.get("cost_base", 50))
	var power_mult: float = 1.0 if is_weapon else Items.ITEM_TIER_POWER[_reward_tier - 1]

	# 1. Main Card Container
	var card := PanelContainer.new()
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
	frame.texture = TierSystem.FRAME_TEXTURES[(_reward_tier - 1) if not is_weapon else 0]
	card.add_child(frame)

	# 2. Margin Container
	var margin := MarginContainer.new()
	## Çerçeve dokusunun süslü kenarlarının İÇİ (bkz. CARD_PAD_* notu) - eskiden hepsi 16'ydı, içerik çerçevenin üstüne biniyordu.
	margin.add_theme_constant_override("margin_left", CARD_PAD_LEFT)
	margin.add_theme_constant_override("margin_right", CARD_PAD_RIGHT)
	margin.add_theme_constant_override("margin_top", CARD_PAD_TOP)
	margin.add_theme_constant_override("margin_bottom", CARD_PAD_BOTTOM)
	card.add_child(margin)
	
	# 3. VBox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	# 4. Tier badge (SADECE eşyalar - bkz. _build_card üstündeki not)
	if not is_weapon:
		var tier_lbl := Label.new()
		tier_lbl.text = "%s (%%%d güç)" % [TierSystem.NAMES[_reward_tier - 1], int(round(power_mult * 100.0))]
		tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_lbl.add_theme_font_size_override("font_size", CARD_TIER_FONT_SIZE)
		tier_lbl.add_theme_color_override("font_color", TierSystem.COLORS[_reward_tier - 1])
		vbox.add_child(tier_lbl)

	# 5. Item Title
	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	## Kullanıcı isteği: font level atlama kartlarının Title'ıyla (40) aynı
	## boyuta getirildi. autowrap eklendi - eskiden kapalıydı, uzun silah/eşya
	## isimleri ("Yıldırım Asası" gibi) bu büyük fontta tek satıra sığmayıp
	## kartın dışına taşabilirdi (kullanıcı isteği: "dışarı taşmasınlar
	## sakın kelime uzunsa aşağıdan devam etsin").
	## (2026-09-21) 46 -> 34: kart iç alanı 244 px genişliğinde (bkz. CARD_PAD_*); isim önce tek satıra sığacak şekilde küçültülür
	## (_fit_card_texts), o da yetmeyen çok uzun isimler alt satıra kayar (autowrap).
	name_lbl.add_theme_font_size_override("font_size", CARD_NAME_FONT_SIZE)
	name_lbl.add_theme_color_override("font_color", PAL_ACCENT)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_lbl.clip_text = false
	vbox.add_child(name_lbl)
	card.set_meta("name_label", name_lbl)

	# 5. Icon
	var icon_rect := TextureRect.new()
	## Kullanıcı isteği: level atlama kartlarının ikon boyutuyla (bkz.
	## level_up_screen.tscn Icon custom_minimum_size) aynı - büyütme geri
	## alınınca (kullanıcı isteği) bu da 84'e döndü.
	icon_rect.custom_minimum_size = Vector2(CARD_ICON_SIZE, CARD_ICON_SIZE) # Proportional icon size
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path) as Texture2D
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon_rect)

	# 6. Description
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
	desc_lbl.add_theme_color_override("default_color", Color(0.96, 0.93, 0.86, 1.0))
	_set_desc_font_size(desc_lbl, CARD_DESC_FONT_SIZE)
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)
	card.set_meta("desc_label", desc_lbl)

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
	ShopPanel._apply_wood_button_style(al_btn)
	if has_slots:
		al_btn.text = "AL"
	else:
		al_btn.text = "SLOTLAR DOLU"
		al_btn.disabled = true
	al_btn.pressed.connect(_on_al_pressed.bind(candidate, cost_base, power_mult))
	vbox.add_child(al_btn)
	## bkz. _auto_pick_random_card - süre dolduğunda hangi kartların hâlâ
	## seçilebilir ("AL" tıklanabilir) olduğunu bulmak için doğrudan referans.
	card.set_meta("al_button", al_btn)

	# 8. Sat Button
	var refund_gold: int = int(round(cost_base * 0.7))
	var sat_btn := Button.new()
	sat_btn.custom_minimum_size = Vector2(0, CARD_BUTTON_HEIGHT)
	sat_btn.add_theme_font_size_override("font_size", CARD_BUTTON_FONT_SIZE)
	## bkz. al_btn üstündeki ayni not - font_color override'i kaldirildi.
	ShopPanel._apply_wood_button_style(sat_btn)
	sat_btn.text = "SAT (+%d Altın)" % refund_gold
	sat_btn.pressed.connect(_on_sat_pressed.bind(item_key, refund_gold))
	vbox.add_child(sat_btn)
	
	return card

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
