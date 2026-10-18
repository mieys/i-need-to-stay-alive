extends CanvasLayer

signal upgrade_chosen(id: String, tier: int)

## Kategori renkleri artık bej kart parşömeni ÜSTÜNDE okunan koyu tonlar (kullanıcı isteği 2026-09-24: oyun içi arayüzler
## menülerle aynı bej/ahşap kite geçti) - TEK kaynak UIKit (silah seçim kartları da aynılarını kullanır).
const UiAnim := preload("res://scripts/ui_anim.gd")
const CAT_ATTACK := UIKit.C_CAT_ATTACK
const CAT_DEFENSE := UIKit.C_CAT_DEFENSE
const CAT_UTILITY := UIKit.C_CAT_UTILITY

## Kullanıcı isteği: "level atlama kartlarının tier'ı olucak. 4 tier olucak...
## ilk tierın bir kat fazla hali olarak verecek her tierda... rasgele olarak
## çıkacak, şansa bağlı olarak artacak, üst tierlar diğerlerine göre daha
## nadir çıkacak." - Tier 1 kartın normal/varsayılan görünümünü (renk/isim
## yok) korur, Tier 2/3/4 sırasıyla mavi/mor/kırmızı bir çerçeve VE kart
## üzerinde (eskiden kullanılmayan Title etiketinde) tier adını gösterir.
## Gerçek stat değeri player.apply_upgrade()'te tier ile ÇARPILIR (bkz. o
## fonksiyonun üstündeki not).
##
## İsim/renk/nadirlik artık TierSystem'de (bkz. tier_system.gd) yaşıyor -
## kullanıcı isteğiyle ("bundan sonra 'ekstralar' eşyalarının tierları
## olacak") sandık eşyaları da (bkz. chest_menu.gd) AYNI tier görsel dilini
## kullanmaya başladığı için ortak yere taşındı, iki taraf asla sapamaz.

## Fixed typography for every upgrade card. These are applied at runtime to
## all three cards so no inherited/theme difference can change their size.
## Kullanıcı isteği: "başlıkları %15 küçültüp açıklamaları %15 büyüt" -
## Category (kategori rozeti, "Saldırı/Savunma/Yardımcı") başlık olarak
## küçültüldü (48 -> 41), Desc (asıl stat adı+değeri) büyütüldü (24 -> 28).
## Kullanıcı isteği: "yeni level kartları... aynı göründüğünden emin ol" -
## eski düz renkli StyleBoxFlat çerçeve yerine artık her tier'ın kendi çizilmiş
## kart çerçevesi (bkz. TierSystem.FRAME_TEXTURES) kullanılıyor. Çerçevenin süslemeli
## (mücevher/köşe) kısımları yer kapladığı için yazı alanı eskisinden dar -
## font boyutları buna göre küçültüldü (bkz. _apply_card_tier_frame ve
## Content kutusunun scenedeki offset'leri - CARD_CONTENT_* ile AYNI oranlardan
## geliyor, 4 kart dosyası da PIL ile analiz edilip HEPSİNİN çerçevesiyle
## çakışmayan ortak (en dar) iç alan hesaplandı).
## DÜZELTME (kullanıcı isteği: "kartları büyütmekle ilgili değişikliği geri
## al") - kart kutusu (level_up_screen.tscn) ve buradaki font/ikon boyutları
## eski (büyütme öncesi) değerlerine döndürüldü.
## 2026-09-25 (savaş kartı yeniden tasarımı, bkz. scripts/tier_card_fx.gd): açıklama artık kartın alt yarısını kaplayan
## parşömen levhada - m5x7'nin keskin durduğu 32 px'e (UIKit.FS_BODY) büyütüldü; çok uzun bir metin levhaya sığmazsa
## _fit_plaque_desc 24'e kadar küçültür.
const CARD_CATEGORY_FONT_SIZE := 32
const CARD_DESCRIPTION_FONT_SIZE := 32
const CARD_DESCRIPTION_MIN_FONT_SIZE := 24
const CARD_COUNT_FONT_SIZE := 16
const CARD_TIER_FONT_SIZE := 32
const CARD_VALUE_FONT_SIZE := 64
const TierCardFx := preload("res://scripts/tier_card_fx.gd")

## Her tier'ın kendi çizilmiş kart çerçevesi (kullanıcının yüklediği 4 ayrı
## dosya - 499x665, hepsi aynı oranlı/hizalı). Kartın KENDİ StyleBoxFlat
## arka planı artık tamamen saydam (bkz. level_up_screen.tscn CardStyle_
## transparent); görünen çerçeve tamamen bu dokulardan geliyor, "Frame"
## TextureRect'in texture'ı _apply_card_tier_frame() içinde tier'a göre
## buradan atanıyor. Dizinin kendisi artık TierSystem.FRAME_TEXTURES'ta
## yaşıyor (bkz. o dosyadaki not) - seyyar satıcı/sandık ekranları da AYNI
## dokuları kullanabilsin diye tek bir yere taşındı.

## desc metinlerindeki sayılar player.gd'nin apply_upgrade()'iyle birebir eş
## olmalı - level atlama kolaylaştırıldığı için bütün bonuslar orada yarı
## yarıya düşürüldü, buradaki metinler de ona göre güncellendi.
const UPGRADES = [
	{"id": "speed", "title": "Hız", "desc": "+%4", "cat": "Yardımcı", "color": CAT_UTILITY},
	{"id": "max_health", "title": "Can", "desc": "+20", "cat": "Savunma", "color": CAT_DEFENSE},
	{"id": "damage", "title": "Saldırı Gücü", "desc": "+6", "cat": "Saldırı", "color": CAT_ATTACK},
	## "Ateş Hızı" -> "Saldırı Hızı" (2026-09-24): eşyalar/stat ekranı aynı stat için "saldırı hızı" diyordu, iki ayrı stat
	## sanılıyordu (bkz. player.gd get_attack_interval_mult).
	{"id": "fire_rate", "title": "Saldırı Hızı", "desc": "+%6", "cat": "Saldırı", "color": CAT_ATTACK},
	{"id": "health_regen", "title": "Can Yenilenmesi", "desc": "+2", "cat": "Savunma", "color": CAT_DEFENSE},
	{"id": "crit_chance", "title": "Kritik Oran", "desc": "+%2.5", "cat": "Saldırı", "color": CAT_ATTACK},
	## Kullanıcı isteği: "kritik hasar oranını arttıran kartta kritik hasar
	## çarpanı yerine kritik hasar miktarı yazsın" - eskiden "+0.125x kritik
	## vuruş çarpanı" (hem çarpan/x notasyonu hem de player.gd'deki gerçek
	## _nice_up değeriyle uyuşmayan eski bir sayı) yazıyordu. Artık diğer
	## yüzdesel kartlarla (crit_chance, armor_pen_percent, exp_gain vb.)
	## AYNI "+%X miktar" formatında ve player.gd'deki gerçek uygulanan
	## değerle (_nice_up(0.125*1.3,0.005)=0.165 -> %16.5) birebir eşleşiyor.
	## 2026-09-25: %16.5 -> %6 (bkz. player.gd CRIT_DAMAGE_CARD_BASE - ikisi aynı sayıyı göstermeli).
	{"id": "crit_damage", "title": "Kritik Hasar", "desc": "+%6", "cat": "Saldırı", "color": CAT_ATTACK},
	## Kullanıcı isteği (2026-10-04): "toplama mesafesi ve menzili level atlama kartlarından kaldırıyoruz ancak bu statlar
	## oyundan silinmesin ilerde eşyalara vb ekleyeceğim" - "pickup_range" ve "range" kartları havuzdan çıktı; statlar,
	## player.gd apply_upgrade dalları, stat ikonları ve DURUMUN satırları duruyor.
	## 2026-10-10 (kullanıcı: "level atlama kartlarından gelen kalkan delme statlarını kaldır"): "shield_pen_percent" kartı havuzdan çıktı; stat eşya/ruhani yetenekten gelir
	## (player.gd apply_upgrade dalı duruyor, kayıtlı eski kartlar bozulmasın).
	{"id": "exp_gain", "title": "Tecrübe Kazanımı", "desc": "+%5", "cat": "Yardımcı", "color": CAT_UTILITY},
	{"id": "luck", "title": "Şans", "desc": "+1", "cat": "Yardımcı", "color": CAT_UTILITY},
	{"id": "dodge", "title": "Sıvışma", "desc": "+%2.5", "cat": "Savunma", "color": CAT_DEFENSE},
	{"id": "shield_amount", "title": "Mana Kalkanı Miktarı", "desc": "+%5", "cat": "Savunma", "color": CAT_DEFENSE},
	{"id": "cooldown_reduction", "title": "Bekleme Süresi Azaltma", "desc": "-%4", "cat": "Yardımcı", "color": CAT_UTILITY},
	## Kullanıcı isteği (2026-09-26): "geri tepmeyi level atlama kartlarından kaldırıyoruz ... kalkan soğurmayı da level
	## atlama kartlarından kaldırıyoruz" - "knockback" (Geri Tepme) ve "shield_protection" (Kalkan Soğurma) kartları
	## havuzdan çıkarıldı. Geri tepme artık bir stat değil, ileride efsun özelliği olacak. player.gd apply_upgrade'deki
	## dallar duruyor (bu havuzdan artık hiç seçilmiyor).
	## Kullanıcı isteği: "Can çalma veren tüm statları %70 azalt" - +%1 -> +%0.3.
	{"id": "lifesteal", "title": "Can Çalma", "desc": "+%1", "cat": "Saldırı", "color": CAT_ATTACK},
]
## Kullanıcı isteği (1. tur): "kalkan emilimini ve geri tepmeyi kaldır, can
## yenilenmesini ekle" - "shield_protection" (o zamanki adıyla "Kalkan
## Koruması") ve "knockback" (Geri Tepme) kartları bu havuzdan çıkarılmıştı,
## yerine "health_regen" eklenmişti. "shield_protection" artık "Kalkan
## Soğurma" adıyla yeniden eklendi (2. tur kullanıcı isteği), "knockback" da
## şimdi (3. tur) "lifesteal" ile birlikte YUKARIDA geri/yeni eklendi.
## 2026-09-26: ikisi de TEKRAR çıkarıldı (bkz. yukarıdaki "lifesteal" satırının üstündeki not).

@onready var cards: Array = [$CardsContainer/Card1, $CardsContainer/Card2, $CardsContainer/Card3]
@onready var reroll_button: Button = $RerollButton
@onready var level_up_sound: AudioStreamPlayer = $LevelUpSound
## Küçük, diğer panellerle (kart stilleriyle) uyumlu tasarımlı geri sayım
## paneli - bkz. level_up_screen.tscn CountdownPanelStyle. Panelin kendisi
## ("Diğer oyuncular bekleniyor" + sayı) görünürlüğü toggle edilir,
## countdown_label sadece SAYIYI günceller.
@onready var countdown_panel: PanelContainer = $CountdownPanel
@onready var countdown_label: Label = $CountdownPanel/VBox/CountdownLabel
@onready var waiting_label: Label = $CountdownPanel/VBox/WaitingLabel


## Kartların içeri "geliş" animasyonu (bkz. _animate_cards_in) - kullanıcı
## isteği: "kartlar animasyonla gelsin, ease ease olmalı ve yorucu olmamalı."
## Kısa süre + ease-out + küçük bir kademe (stagger) gecikmesiyle her kart
## sırayla, yumuşakça yerine oturuyor - göz yormasın diye zıplama/elastik
## efekt YOK, tek seferlik ve hızlı (bkz. aşağıdaki sabitler).
const CARD_ANIM_DURATION := 0.26
const CARD_ANIM_STAGGER := 0.07
const CARD_ANIM_RISE := 22.0
const CARD_ANIM_START_SCALE := 0.92
## Reroll'a art arda hızlı basılırsa aynı karttaki eski tween'le yenisi
## çakışmasın diye her kartın en son tween'i burada tutulup yenisi
## başlamadan önce öldürülüyor.
var _card_tweens: Array = [null, null, null]

## Bu YEREL oyuncu zaten bir kart seçti mi - bkz. _on_card_pressed /
## _auto_pick_random_card. Süre (25sn) dolduğunda henüz seçmemiş oyuncular
## için otomatik bir kart seçilir; zaten seçmiş oyuncu için (bekleme
## durumundaki) tekrar seçim yapılmaz.
var _has_chosen: bool = false

## Her kartın o anki tier'ı (hover halesi rengi + seçim kutlaması için) ve boşta parlama tween'leri (reroll'da öldürülür).
var _card_tiers: Array = [1, 1, 1]
var _shine_tweens: Array = [null, null, null]
## Seçim kıvılcımlarının çizildiği, tüm ekranı kaplayan en üst katman (bkz. _ensure_fx_layer).
var _fx_layer: Control = null


const ReadingUiWatcher := preload("res://scripts/reading_ui_watcher.gd")
## Kart seçim ekranı açıkken karakter okuma (read) pozuna geçer - bkz. ReadingUiWatcher.
func _enter_tree() -> void:
	add_to_group(ReadingUiWatcher.GROUP)


func _ready() -> void:
	UISound.connect_all_buttons(self)
	UiAnim.skip($CardsContainer) ## kartların kendi giriş/üstüne gelme/seçim animasyonu var (madde 200)
	UISound.apply_wood_buttons(self) ## bkz. ui_sound.gd - tüm butonları ahşap stile çevirir (kart butonları "icon slot" gibi dikey orantılı oldukları için bu zaten atlıyor, bkz. o dosyadaki _looks_like_icon_slot)
	## Yetenek evrimi seviyesi mi (5/10/15... - kartlar evrim kartı olur, bkz. dosya sonundaki "YETENEK EVRİMİ" bloğu).
	_evo_offers = _roll_evolution_offers()
	_evo_mode = not _evo_offers.is_empty()
	_apply_reroll_button_style()
	_apply_kit_style()
	_layout_rows()
	_apply_mobile_layout()
	if _evo_mode:
		_populate_evolution_rows()
	else:
		_populate_cards()
	_wire_card_hover_feedback()
	reroll_button.pressed.connect(_on_reroll_pressed)
	_refresh_reroll_button()
	## Kullanıcı isteği (2026-09-28): "pardon reroll olmasın" - evrim kartlarında karıştırma yok.
	if _evo_mode:
		reroll_button.visible = false
		## Üç geniş kart ekranın sağına kadar uzanır - sağ sütundaki görev satırları (katman 40) üçüncü kartın üstüne
		## binmesin diye ekran onların üstüne alınır (ipucu/geri sayım katmanları 50/90+ yine üstte).
		layer = EVO_LAYER
		var title_lbl: Label = get_node_or_null("Title") as Label
		if title_lbl:
			title_lbl.text = EVO_TITLE
	## Artık autoplay değil (bkz. level_up_screen.tscn) - "hepsinde random
	## pitch olucak" isteğiyle her seviye atlamada hafif farklı bir perde
	## kullanılsın diye elle çalınıyor.
	level_up_sound.pitch_scale = randf_range(0.94, 1.06)
	level_up_sound.play()
	_animate_cards_in()
	
	if NetworkManager.is_multiplayer_active:
		NetworkManager.multiplayer_level_up_timer_tick.connect(_on_level_up_timer_tick)
		## DÜZELTME (kullanıcı isteği: "bir oyuncu diğerlerinin seçmesini
		## beklemeden tüm kartlarını seçebilsin") - bu ekran artık kart
		## seçilir seçilmez ANINDA kapanıyor (bkz. main.gd _on_upgrade_chosen),
		## "diğer oyuncular bekleniyor" durumu hiç yaşanmıyor - panel SADECE bu
		## oyuncunun KENDİ 25sn'lik karar süresini gösteriyor (bkz.
		## waiting_label'a atanan sabit ipucu metni).
		if waiting_label:
			waiting_label.text = "Süre dolarsa otomatik seçilir"
		if countdown_panel:
			countdown_panel.visible = NetworkManager.level_up_timer_active
			if countdown_panel.visible and countdown_label:
				countdown_label.text = "%ds" % int(ceil(NetworkManager.level_up_countdown))


## Kartların arka planı artık saydam olduğu için (görünen çerçeve "Frame"
## TextureRect'in dokusu - bkz. _apply_card_tier_frame) Button'ın kendi
## normal/hover/pressed StyleBox geçişleri hiçbir şey ÇİZMİYOR. Basılabilir
## hissi vermesi için hover/basma geri bildirimi burada elle, "Frame"
## dokusunun modulate'ini hafifçe parlatıp/kartı küçültüp uygulanıyor. Kalıcı
## (tekrar reroll'da bozulmayan) bir bağlantı olduğu için bir kez, _ready()'de
## kuruluyor - id/tier gibi çekilişe özgü bir veriye ihtiyacı yok.
func _wire_card_hover_feedback() -> void:
	for card: Button in cards:
		if not is_instance_valid(card):
			continue
		card.mouse_entered.connect(_on_card_hover.bind(card, true))
		card.mouse_exited.connect(_on_card_hover.bind(card, false))
		## Kumanda (bkz. gamepad_ui.gd): odaklanan kart fareyle üstüne gelinmiş gibi parlar; açılışta ilk odak kartlarda.
		card.focus_entered.connect(_on_card_hover.bind(card, true))
		card.focus_exited.connect(_on_card_hover.bind(card, false))
		card.add_to_group(&"gamepad_first_focus")
		card.button_down.connect(_on_card_press.bind(card, true))
		card.button_up.connect(_on_card_press.bind(card, false))


## Kullanıcı isteği: "level atlama kartlarını 1-2-3 ile seçebilelim" - kartın
## üstüne görsel bir "1/2/3" etiketi eklenmedi (kullanıcı isteği: "üstüne
## bişey yazmana gerek yok"), sadece klavye kısayolu. _has_chosen/card.
## disabled ile AYNI korumalar (bekleme durumunda basılamaz); chat yazarken
## de tetiklenmez - player.gd'nin kendi yetenek kısayollarındaki (bkz. o
## dosyada "and not is_chat_typing") AYNI desen.
func _unhandled_input(event: InputEvent) -> void:
	if _has_chosen or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var idx: int = -1
	match event.keycode:
		KEY_1:
			idx = 0
		KEY_2:
			idx = 1
		KEY_3:
			idx = 2
	if idx < 0 or idx >= cards.size():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and bool(player.get("is_chat_typing")):
		return
	var card: Button = cards[idx]
	if is_instance_valid(card) and card.visible and not card.disabled:
		card.pressed.emit()


## Kullanıcı isteği (2026-09-25): "level seçim kartlarının karıştırması space tuşu ile yeniden rerollanabilsin" -
## Karıştır butonuna basmakla BİREBİR aynı (altın bedeli/yetersiz altında kapalı buton kuralları aynen). GUI'den ÖNCE
## (_input) yakalanır: Space varsayılan "ui_accept" olduğu için yoksa klavye odağındaki KART seçilirdi.
func _input(event: InputEvent) -> void:
	if _has_chosen or not (event is InputEventKey) or not event.pressed or event.echo or event.keycode != KEY_SPACE:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and bool(player.get("is_chat_typing")):
		return
	get_viewport().set_input_as_handled()
	if is_instance_valid(reroll_button) and reroll_button.visible and not reroll_button.disabled:
		reroll_button.pressed.emit()


func _on_card_hover(card: Button, entered: bool) -> void:
	if card.disabled or _has_chosen:
		return ## bekleme/kutlama sırasında kartların üstü hover'la aydınlanmasın
	var frame: TextureRect = card.get_node_or_null("Frame")
	if frame:
		frame.modulate = Color(1.12, 1.12, 1.12, 1.0) if entered else Color(1, 1, 1, 1)
	var idx: int = cards.find(card)
	TierCardFx.set_hover_glow(card, int(_card_tiers[idx]) if idx >= 0 else 1, entered)


func _on_card_press(card: Button, is_down: bool) -> void:
	if _has_chosen:
		return ## seçim kutlaması kartın ölçeğini kendisi canlandırıyor
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.97, 0.97) if is_down else Vector2.ONE


func _on_level_up_timer_tick(remaining: float) -> void:
	if countdown_panel:
		countdown_panel.visible = true
	if countdown_label:
		countdown_label.text = "%ds" % int(ceil(remaining))
	## Süre dolduğunda ("25 saniye içinde otomatik seçilmesi gerekiyor
	## eğer seçmezse" - kullanıcı isteği): bu oyuncu henüz bir kart
	## seçmediyse, kendi adına rastgele bir kart otomatik seçilir - böylece
	## oyun herkes için normal şekilde devam eder, kimse sonsuza kadar
	## beklemede kalmaz.
	if remaining <= 0.0 and not _has_chosen:
		_auto_pick_random_card()


## Süre dolduğunda henüz kart seçmemiş oyuncu için rastgele bir kart
## "tıklanmış" gibi davranır - _on_card_pressed ile TAMAMEN aynı akıştan
## geçer (upgrade_chosen sinyali, player.apply_upgrade, mark_local_upgrade_
## chosen, bekleme durumuna geçiş), tekrar kod yazmaya gerek yok.
func _auto_pick_random_card() -> void:
	if _has_chosen or cards.is_empty():
		return
	## Evrim modunda 3'ten az kart kalmışsa boş satırlar gizli - sadece görünenlerden seçilir.
	var pickable: Array = cards.filter(func(c): return is_instance_valid(c) and c.visible and not c.disabled)
	if pickable.is_empty():
		return
	var card: Button = pickable[randi() % pickable.size()]
	if is_instance_valid(card):
		card.pressed.emit()



## Her kartı hafifçe küçük/saydam/aşağıda başlatıp normal haline (scale 1,
## alfa 1, orijinal konum) ease-out ile yumuşakça getirir - kartlar
## CARD_ANIM_STAGGER kadar arayla, soldan sağa sırayla belirir. _populate_cards
## içerik/etiketlere DOKUNMAZ, bu yüzden reroll'da da güvenle tekrar çağrılabilir.
## Kartlar HBoxContainer'ın çocuğu olduğundan gerçek position/size'ları ancak
## container bir "sort" geçirdikten SONRA doğru olur - bunu _ready()'nin
## kendi karesinde garanti edemediğimiz için (container sort'u deferred
## olabilir) bir kare bekleniyor. Bu tek karede kartların çıplak/final
## haliyle görünüp sonra aniden küçülüp geri büyümesi gibi bir "çakma"
## olmasın diye alfa/scale HEMEN (kare beklemeden) sıfırlanıyor, sadece
## konum/pivot hesabı karenin sonuna bırakılıyor.
func _animate_cards_in() -> void:
	for card in cards:
		if is_instance_valid(card):
			card.modulate.a = 0.0
			card.scale = Vector2(CARD_ANIM_START_SCALE, CARD_ANIM_START_SCALE)
	await get_tree().process_frame
	if not is_instance_valid(self) or not is_inside_tree():
		return
	for i in range(cards.size()):
		var card: Control = cards[i]
		if not is_instance_valid(card):
			continue
		if _card_tweens[i] and _card_tweens[i].is_valid():
			_card_tweens[i].kill()
		card.pivot_offset = card.size * 0.5
		var base_y: float = card.position.y
		card.position.y = base_y + CARD_ANIM_RISE
		var delay: float = i * CARD_ANIM_STAGGER
		var tween := create_tween()
		_card_tweens[i] = tween
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card, "modulate:a", 1.0, CARD_ANIM_DURATION).set_delay(delay)
		tween.tween_property(card, "scale", Vector2.ONE, CARD_ANIM_DURATION).set_delay(delay)
		tween.tween_property(card, "position:y", base_y, CARD_ANIM_DURATION).set_delay(delay)


## Kullanıcı isteği (#36 - önceki %15 bonus yetersiz bulunup tekrar
## bildirildi: "Level kartlarında saldırı/hasar kartı çıkma ihtimalini
## arttır"): Saldırı kategorisindeki kartların çıkma ihtimali diğerlerine
## göre ARTIRILDI - eski %15 bonus %50'ye çıkarıldı. Ağırlıklı, TEKRARSIZ
## bir seçim: her adımda kalan havuzdaki her kartın ağırlığına göre
## (Saldırı = 1.5, diğerleri = 1.0) rastgele bir tanesi seçilip havuzdan
## çıkarılıyor, bu da normal shuffle+ilk N alma yerine kategoriye göre
## ağırlıklı bir dağılım sağlıyor.
const ATTACK_CATEGORY_WEIGHT_BONUS := 0.5

func _weighted_sample(pool: Array, count: int) -> Array:
	var working: Array = pool.duplicate()
	var result: Array = []
	for i in range(count):
		if working.is_empty():
			break
		var weights: Array = []
		var total: float = 0.0
		for item in working:
			var w: float = 1.0 + ATTACK_CATEGORY_WEIGHT_BONUS if item["cat"] == "Saldırı" else 1.0
			weights.append(w)
			total += w
		var r: float = randf() * total
		var idx: int = weights.size() - 1
		var acc: float = 0.0
		for j in range(weights.size()):
			acc += weights[j]
			if r <= acc:
				idx = j
				break
		result.append(working[idx])
		working.remove_at(idx)
	return result


## Kullanıcı isteği: "rerollanan şeyler rerollandığında asla önceki
## seçeneklerden birini içermemeli" - bu ekranda GÖSTERİLMİŞ (ilk açılış +
## tüm reroll'lar) tüm kart id'lerini tutar, bir sonraki çekilişte havuzdan
## çıkarılır. Kalan benzersiz kart sayısı istenenden azsa (havuz tükendi)
## son çare olarak sıfırlanır - sonsuza dek tekrarsız kalmak mümkün değil.
var _shown_upgrade_ids: Array = []

func _populate_cards() -> void:
	var available: Array = UPGRADES.filter(func(u): return not _shown_upgrade_ids.has(u["id"]))
	if available.size() < 3:
		_shown_upgrade_ids.clear()
		available = UPGRADES.duplicate()
	var pool: Array = _weighted_sample(available, 3)
	for u in pool:
		_shown_upgrade_ids.append(u["id"])
	var player := get_tree().get_first_node_in_group("player")

	for i in range(3):
		var upgrade = pool[i]
		var card: Button = cards[i]
		## Her kart için BAĞIMSIZ bir tier zarı - aynı çekilişteki 3 kart
		## farklı tierlarda olabilir (bkz. tier_system.gd TierSystem.WEIGHTS).
		## Kullanıcı isteği: "çıkma ihtimalleri şansa bağlı olarak artacak" -
		## gerçek luck değeri geçiliyor (bkz. TierSystem.TIER_LUCK_WEIGHT_
		## BONUS_PER_POINT).
		var tier: int = TierSystem.roll(player.luck if player and "luck" in player else 0.0)

		# A reroll re-runs this on the same buttons - drop whatever the
		# previous draw connected so clicking never fires an old, stale id.
		for conn in card.pressed.get_connections():
			card.pressed.disconnect(conn["callable"])

		var count: int = 0
		if player and player.has_method("get_upgrade_count"):
			count = player.get_upgrade_count(upgrade["id"])

		## Metin artık tek bir kalın buton yazısı değil; okunması kolay olsun
		## diye başlık/açıklama/tekrar-sayısı ayrı etiketlere ve stat'a özgü
		## bir simgeye (bkz. stat_icon.gd) bölündü.
		card.text = ""
		card.pressed.connect(_on_card_pressed.bind(upgrade["id"], tier, card))

		var content: Node = card.get_node("Content")

		## Category artık (eski: Card'ın doğrudan çocuğu, elle konumlanmış)
		## Content VBoxContainer'ın İLK çocuğu - bkz. level_up_screen.tscn.
		## Böylece Category/Icon/Title/Desc/CountLabel TEK bir dikey yığın
		## olarak otomatik diziliyor, yeni (daha dar) iç alana elle piksel
		## hesabı yapmadan sığıyor.
		## 2026-09-25 savaş kartı: kategori artık koyu tier zemininin üstünde (kartın üst satırı) - krem yazı + koyu kontur
		## (kategori renkleri parşömen için seçilmiş koyu tonlardı, tier renginin üstünde okunmuyordu).
		var category_label: Label = content.get_node("Category")
		category_label.text = upgrade["cat"]
		category_label.modulate = Color(1, 1, 1, 1)
		UIKit.style_label(category_label, CARD_CATEGORY_FONT_SIZE, UIKit.C_CREAM, 4)

		content.get_node("Icon").setup(upgrade["id"], upgrade["color"])

		## Title etiketi = tier adı (Sıradan/Nadir/Epik/Efsanevi) - artık kartın tier renkli kurdelesinin üstünde, krem yazı.
		var title_label: Label = content.get_node("Title") as Label
		title_label.visible = true
		title_label.text = TierSystem.NAMES[tier - 1]
		UIKit.style_label(title_label, CARD_TIER_FONT_SIZE, UIKit.C_CREAM, 4)

		_card_tiers[i] = tier
		_apply_card_tier_frame(card, tier)
		if _shine_tweens[i] and _shine_tweens[i].is_valid():
			_shine_tweens[i].kill()
		_shine_tweens[i] = TierCardFx.start_idle_shine(self, card.get_node_or_null("Frame") as TextureRect, tier, 0.5 + 0.35 * i)

		var desc_label: RichTextLabel = _card_desc(card)
		desc_label.text = _get_friendly_desc(upgrade, tier)
		_set_desc_font_size(desc_label, CARD_DESCRIPTION_FONT_SIZE)

		var count_label: Label = _card_count(card)
		count_label.add_theme_font_size_override("font_size", CARD_COUNT_FONT_SIZE)
		count_label.text = ("%dx alındı" % count) if count > 0 else ""
		_fill_row(card, upgrade, tier, count)
	_fit_plaque_desc.call_deferred()


## Görünür çerçeve artık bir StyleBoxFlat rengi DEĞİL, tier'a özel çizilmiş
## bir doku (bkz. TierSystem.FRAME_TEXTURES) - "Frame" TextureRect'e atanıyor.
## Bir reroll önceki karttan kalma "seçili" parlaklığı/parıltısı miras
## almasın diye modulate/glow burada HER ZAMAN varsayılana sıfırlanıyor.
func _apply_card_tier_frame(card: Button, tier: int) -> void:
	var frame: TextureRect = card.get_node_or_null("Frame")
	if frame:
		TierCardFx.apply_frame(frame, tier)
		## Satır dokusu (savaş kartı yerine) + ışıltı shader'ının sanat pikseli ızgarası satırın boyuna göre.
		## Evrim modunda efsun ekranının dikey kartı (mor / FİNAL kırmızı - bkz. "YETENEK EVRİMİ" bloğu).
		if _evo_mode:
			frame.texture = EnchantScreenScript.CARD_TEXTURES[clampi(tier, 1, 4) - 1]
			(frame.material as ShaderMaterial).set_shader_parameter("art_size", EnchantScreenScript.CARD_ART_SIZE)
		else:
			frame.texture = ROW_TEXTURES[clampi(tier, 1, 4) - 1]
			(frame.material as ShaderMaterial).set_shader_parameter("art_size", ROW_ART_SIZE)
		frame.modulate = Color(1, 1, 1, 1)
	var glow: Control = card.get_node_or_null("SelectGlow")
	if glow:
		glow.visible = false
	TierCardFx.set_hover_glow(card, tier, false)
	card.modulate = Color(1, 1, 1, 1)


## ---------------------------------------------------------------- level atlama SATIRLARI (2026-09-25)
## Kullanıcı isteği: savaş kartı (ve denenen başka kart tasarımları) yerine prototiplerden "A2 - Liste Satırları" seçildi
## (survivor-like: 3 yatay satır; solda ikon yuvası, ortada ad + "Tier · Kategori · Nx alındı", sağda değer). "soldaki düz
## uzun çizgi olmasın, çerçeve sola simetrik hizalansın" (ikon yuvası her kenardan 18 px), "genişlikleri %20 azalt" (804 px),
## "oyunun panellerine benzetmene gerek yok" (koyu gövde + tier renkli çerçeve, bej yok), Tier 1 GRİ. Doku:
## tools/gen_menu_kit.py levelup_row (yuva dokunun içinde). .tscn'ye DOKUNULMADI (açık editör eski hâli üstüne yazabilir):
## kartlar çalışma anında yeni bir dikey "Rows" kutusuna taşınır, satır yazıları burada kurulur; eski Content'in yalnız
## Icon'u kalır (yuvanın içinde), diğer etiketleri gizlenir (yine doldurulurlar, zararsız). Hover halesi / seçim kutlaması
## TierCardFx'in aynı kodu - satır boyutu ve dokusu kart meta'larıyla verilir (bkz. TierCardFx.ensure_glow). Sandık ödül
## kartları (chest_menu.gd) savaş kartında kalır.
const ROW_SIZE := Vector2(804, 150)
## 2026-10-11 "Yüzen Kapsül" (kullanıcı seçimi): doku gövdenin 2 sanat px (6 px) altında yumuşak gölge taşır -> 268x52 sanat
## px; satırın kendisi (tıklama alanı, yazılar, hale) yine 804x150, Frame TextureRect gölge kadar aşağı taşar.
const ROW_ART_SIZE := Vector2(268, 52)
const ROW_SHADOW := 6.0
const ROW_SEPARATION := 22
## Ekran ortasına göre (başlığın altı, karıştır butonunun üstü). 2026-09-25: yeni başlık/karıştır butonu seçilen
## prototipteki yerleşimle geldi - satırlar y 216'dan başlıyor (eskiden 270), buton satırların 90 px altında (y 800).
const ROW_TOP := -324.0
const ROW_TEXTURES := [
	preload("res://assets/ui/game/levelup_row_1.png"),
	preload("res://assets/ui/game/levelup_row_2.png"),
	preload("res://assets/ui/game/levelup_row_3.png"),
	preload("res://assets/ui/game/levelup_row_4.png"),
]
const ROW_GLOW := preload("res://assets/ui/game/levelup_row_glow.png")
## Tier yazı rengi (alt satır) = dokudaki tier "hi" tonu; Tier 1 gri. Işıltı renkleri de Tier 1'de gümüş.
const ROW_TIER_TEXT := [Color("#cdd1d6"), Color("#a6c6f4"), Color("#d8aef4"), Color("#f8a890")]
const ROW_GLOW_COLORS := [Color("#dfe4ea"), Color("#9cc4ff"), Color("#dcb0ff"), Color("#ffc65a")]
const ROW_VALUE_COLOR := Color("#ffd66e")
const ROW_DIM_COLOR := Color("#e6d2b0")
## Satır içi yerleşim (px): ikon (Yüzen Kapsül'de yuva yok, ikon doğrudan gövdede); yazılar ikonun sağından, değer sağa yaslı.
const ROW_ICON_RECT := Rect2(24, 24, 102, 102)
const ROW_TEXT_X := 156.0
const ROW_RIGHT_PAD := 36.0


func _layout_rows() -> void:
	if _evo_mode:
		_layout_evolution_cards()
		return
	var old: Control = get_node_or_null("CardsContainer") as Control
	var row_size: Vector2 = ROW_SIZE
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.theme = UIKit.theme()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", ROW_SEPARATION)
	rows.set_anchors_preset(Control.PRESET_CENTER)
	rows.offset_left = -row_size.x * 0.5
	rows.offset_right = row_size.x * 0.5
	rows.offset_top = ROW_TOP
	rows.offset_bottom = ROW_TOP + row_size.y * cards.size() + ROW_SEPARATION * (cards.size() - 1)
	_apply_desktop_scale(rows)
	add_child(rows)
	if old:
		move_child(rows, old.get_index())
		old.visible = false
	for card: Button in cards:
		if not is_instance_valid(card):
			continue
		card.reparent(rows, false)
		card.custom_minimum_size = row_size
		card.clip_contents = false ## seçim halesi satırın dışına taşar (bkz. TierCardFx.ensure_glow)
		card.set_meta("glow_texture", ROW_GLOW)
		card.set_meta("glow_card_size", row_size)
		card.set_meta("glow_colors", ROW_GLOW_COLORS)
		var frame: TextureRect = card.get_node_or_null("Frame") as TextureRect
		if frame:
			frame.offset_right = row_size.x
			frame.offset_bottom = row_size.y + ROW_SHADOW
		var content: VBoxContainer = card.get_node("Content") as VBoxContainer
		content.clip_contents = false
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.offset_left = ROW_ICON_RECT.position.x
		content.offset_top = ROW_ICON_RECT.position.y
		content.offset_right = ROW_ICON_RECT.end.x
		content.offset_bottom = ROW_ICON_RECT.end.y
		for n in ["Category", "Title", "Desc", "CountLabel"]:
			var node: CanvasItem = content.get_node_or_null(n) as CanvasItem
			if node:
				node.visible = false
		(content.get_node("Icon") as Control).custom_minimum_size = Vector2(90, 90)
		var sel: Control = card.get_node_or_null("SelectGlow") as Control
		if sel:
			sel.visible = false
		var right_x: float = ROW_SIZE.x - ROW_RIGHT_PAD - 300.0
		_row_label(card, "RowName", Rect2(ROW_TEXT_X, 30, 430, 44), 32, UIKit.C_CREAM, HORIZONTAL_ALIGNMENT_LEFT)
		_row_label(card, "RowValue", Rect2(right_x, 18, 300, 80), 64, ROW_VALUE_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
		_row_label(card, "RowVerb", Rect2(right_x, 84, 300, 40), 32, ROW_DIM_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
		var sub := RichTextLabel.new()
		sub.name = "RowSub"
		sub.bbcode_enabled = true
		sub.fit_content = false
		sub.scroll_active = false
		sub.autowrap_mode = TextServer.AUTOWRAP_OFF
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_desc_font_size(sub, 32)
		card.add_child(sub)
		sub.position = Vector2(ROW_TEXT_X, 82)
		sub.size = Vector2(ROW_SIZE.x - ROW_TEXT_X - ROW_RIGHT_PAD, 44)


## ---------------------------------------------------------------- TELEFON (kullanıcı seçimi 2026-10-03, prototip "A")
## Masaüstündeki satırlar aynen, satır kutusu TAM 2 kat (804x150 -> 1608x300 = 6x sanat px; yazılar 32 -> 64, keskin) ve
## ekranın boyu kadar; ekran o kadar geniş değilse 1,5 kat. Karıştır sol kenarda, geri sayım sağ kenarda dikey büyük kutular
## (başparmak bölgesi). Evrim kartları kendi ölçeğini _layout_evolution_cards'ta kurar. Masaüstünde hiçbir şey değişmez.
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const MOBILE_ROW_SEPARATION := 8


func _apply_mobile_layout() -> void:
	if not MobileUIScript.enabled:
		return
	var vp: Viewport = get_viewport()
	var view: Vector2 = vp.get_visible_rect().size
	if not _evo_mode:
		_apply_phone_cards(vp, view)
		return
	var title: Label = get_node_or_null("Title") as Label
	if title:
		title.offset_top = 8.0
		title.offset_bottom = 8.0 + TITLE_SIZE.y
	## Karıştır: sol kenar, zar yazının üstünde.
	var rr: Rect2 = MobileUIScript.choice_side_rect(vp, true, 0, 1, 300.0)
	reroll_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	reroll_button.position = rr.position
	reroll_button.size = rr.size
	reroll_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reroll_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	reroll_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reroll_button.add_theme_font_size_override("font_size", 40)
	for state: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var sb := reroll_button.get_theme_stylebox(state) as StyleBoxTexture
		if sb:
			sb.content_margin_left = 12.0
			sb.content_margin_right = 12.0
			sb.content_margin_top = 40.0
			sb.content_margin_bottom = 24.0
	## Geri sayım: sağ kenar.
	if countdown_panel:
		var cr: Rect2 = MobileUIScript.choice_side_rect(vp, false, 0, 1, 260.0)
		countdown_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		countdown_panel.position = cr.position
		countdown_panel.size = cr.size
		if waiting_label:
			waiting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if countdown_label:
			countdown_label.add_theme_font_size_override("font_size", UIKit.FS_TITLE)
			countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## ---------------------------------------------------------------- TELEFON KARTLARI (madde 276; kullanıcı onayı 2026-10-18,
## madde 253 "Seçenek 1"; prototip tools/proto_20261018/mobil_proto.gd S_level): başlık sol üstte "SEVİYE N!", üç DİKEY kart yan
## yana (640x600 tuval px: nadirlik renkli kenar + şerit, büyük stat simgesi, değer, stat adı, "Şu an" kutusu; kartın kendisi
## düğme - tek dokunuş), Karıştır sol altta, geri sayım sağ üstte. "DOKUN = SEÇ" ve açıklama cümlesi yok. Prototipteki "YASAKLA"
## oyunda olmayan bir mekanik - eklenmedi. "Şu an" = HudStatPanel.values_for (oyuncunun o anki değeri; tahmini "-> yeni" yok).
## Renkler: Gece Sıvası (B) levha + oyunun nadirlik renk ailesi (gri / mavi / mor / kırmızı). Evrim kartları eski telefon yolunda.
const HudStatPanelScript := preload("res://scripts/hud_stat_panel.gd")
const ChestMenuScript := preload("res://scripts/chest_menu.gd") ## telefon üst koyulaşma şeridi (top_fade) ortak
const PH_CARD := Vector2(640, 600)
const PH_CARD_GAP := 64.0
const PH_CARD_TOP := 226.0
const PH_SIDE := 96.0 ## başlık / Karıştır sol kenar payı (prototip SX)
const PH_DIM := Color(0.03, 0.03, 0.06, 0.66)
const PH_PANEL := Color("#23233a")
const PH_INSET := Color("#12121f")
const PH_LINE := Color("#3b3a5a")
const PH_TEXT := Color("#efe6d6")
const PH_DIM_TEXT := Color("#a7a2c0")
const PH_ACCENT := Color("#f4c56e")
const PH_GOOD := Color("#a8d69a")
const PH_TIER := [Color("#9ea4ad"), Color("#5f8fe0"), Color("#a070dc"), Color("#e0604c")]
const PH_TIER_NAMES := ["SIRADAN", "NADİR", "EPİK", "EFSANEVİ"]
var _phone_cards: bool = false


static func _ph_box(fill: Color, border: Color, bw: int, rad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(rad)
	sb.corner_detail = 6
	return sb


func _ph_label(card: Control, n: String, r: Rect2, fs: int, c: Color, align: HorizontalAlignment) -> Label:
	var lbl: Label = card.get_node_or_null(n) as Label
	if lbl == null:
		lbl = Label.new()
		lbl.name = n
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(lbl)
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.clip_text = true
	UIKit.style_label(lbl, fs, c, 0)
	lbl.position = r.position
	lbl.size = r.size
	## _row_label boyutu ertelenmiş de yazar (bkz. orası) - bizimki ondan SONRA çalışsın diye yine ertelenmiş.
	lbl.set_deferred("size", r.size)
	return lbl


func _apply_phone_cards(vp: Viewport, view: Vector2) -> void:
	_phone_cards = true
	var safe: Rect2 = MobileUIScript.safe_margins(vp)
	var dim: ColorRect = get_node_or_null("Dim") as ColorRect
	if dim:
		dim.color = PH_DIM
		var fade: TextureRect = ChestMenuScript.top_fade(view.x)
		add_child(fade)
		move_child(fade, dim.get_index() + 1)
	var title: Label = get_node_or_null("Title") as Label
	if title:
		title.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		UIKit.style_label(title, 96, PH_ACCENT, 6)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.set_anchors_preset(Control.PRESET_TOP_LEFT)
		title.position = Vector2(safe.position.x + PH_SIDE, 20.0)
		title.size = Vector2(900, 104)
		var player: Node = get_tree().get_first_node_in_group("player")
		title.text = ("SEVİYE %d!" % int(player.get("level"))) if player and "level" in player else "SEVİYE ATLADIN!"
	var rows: Control = get_node_or_null("Rows") as Control
	var holder := Control.new()
	holder.name = "PhoneCards"
	holder.theme = UIKit.theme()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(holder)
	if rows:
		move_child(holder, rows.get_index())
		rows.visible = false
	var x0: float = roundf((view.x - (PH_CARD.x * 3.0 + PH_CARD_GAP * 2.0)) * 0.5)
	var top: float = roundf(PH_CARD_TOP + maxf(0.0, (view.y - 1080.0) * 0.5))
	for i in cards.size():
		var card: Button = cards[i]
		if not is_instance_valid(card):
			continue
		card.reparent(holder, false)
		card.custom_minimum_size = PH_CARD
		card.position = Vector2(x0 + i * (PH_CARD.x + PH_CARD_GAP), top)
		card.size = PH_CARD
		card.clip_contents = false
		card.remove_meta("glow_texture") ## dikey kartın varsayılan halesi (satır halesi değil)
		card.set_meta("glow_card_size", PH_CARD)
		var frame: CanvasItem = card.get_node_or_null("Frame") as CanvasItem
		if frame:
			frame.visible = false
		for nm: String in ["PhBg", "PhBand"]:
			if card.get_node_or_null(nm) == null:
				var pn := Panel.new()
				pn.name = nm
				pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.add_child(pn)
				card.move_child(pn, 0 if nm == "PhBg" else 1)
		var bg: Panel = card.get_node("PhBg") as Panel
		bg.position = Vector2.ZERO
		bg.size = PH_CARD
		var band: Panel = card.get_node("PhBand") as Panel
		band.position = Vector2(4, 4)
		band.size = Vector2(PH_CARD.x - 8.0, 72.0)
		var content: Control = card.get_node("Content") as Control
		content.offset_left = PH_CARD.x * 0.5 - 96.0
		content.offset_top = 96.0
		content.offset_right = PH_CARD.x * 0.5 + 96.0
		content.offset_bottom = 288.0
		(content.get_node("Icon") as Control).custom_minimum_size = Vector2(192, 192)
		_ph_label(card, "PhTier", Rect2(0, 4, PH_CARD.x, 72), 48, PH_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		_ph_label(card, "PhCount", Rect2(PH_CARD.x - 136.0, 4, 112, 72), 32, PH_DIM_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		_ph_label(card, "RowValue", Rect2(0, 296, PH_CARD.x, 112), 112, PH_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		_ph_label(card, "RowName", Rect2(0, 416, PH_CARD.x, 64), 64, PH_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		if card.get_node_or_null("PhNowBox") == null:
			var nb := Panel.new()
			nb.name = "PhNowBox"
			nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			nb.add_theme_stylebox_override("panel", _ph_box(Color(PH_INSET, 0.85), PH_LINE, 2, 12))
			card.add_child(nb)
		var nbox: Panel = card.get_node("PhNowBox") as Panel
		nbox.position = Vector2(40, 500)
		nbox.size = Vector2(PH_CARD.x - 80.0, 64)
		_ph_label(card, "PhNow", Rect2(40, 500, PH_CARD.x - 80.0, 64), 48, PH_GOOD, HORIZONTAL_ALIGNMENT_CENTER)
		for hide: String in ["RowVerb", "RowSub"]:
			var h: CanvasItem = card.get_node_or_null(hide) as CanvasItem
			if h:
				h.visible = false
	## Karıştır: sol alt (başparmak); gerçek bedel (altın / ücretsiz) - prototipteki "2 hak" oyunda yok.
	reroll_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	## Alttaki tek düğme: kartların ekseninde ortalı (kullanıcı 2026-10-19: "asimetrilikler ... varsa düzelt" - sol altta tek başına
	## kalıyordu; prototipteki sağ alt YASAKLA oyunda yok).
	reroll_button.size = Vector2(500, 136)
	reroll_button.position = Vector2(roundf(safe.position.x + (view.x - safe.position.x - safe.size.x - 500.0) * 0.5),
			view.y - safe.size.y - 164.0)
	reroll_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	reroll_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	reroll_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	reroll_button.add_theme_font_size_override("font_size", 48)
	reroll_button.expand_icon = true
	reroll_button.add_theme_constant_override("icon_max_width", 66) ## zar 33 px -> 2x
	for state: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var sb := reroll_button.get_theme_stylebox(state) as StyleBoxTexture
		if sb:
			sb.content_margin_left = 40.0
			sb.content_margin_right = 24.0
			sb.content_margin_top = 0.0
			sb.content_margin_bottom = 0.0
	## Geri sayım (çok oyunculu): sağ üst, Gece Sıvası levhası.
	if countdown_panel:
		countdown_panel.add_theme_stylebox_override("panel", _ph_box(Color(PH_PANEL, 0.94), PH_LINE, 3, 14))
		countdown_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		countdown_panel.size = Vector2(420, 120)
		countdown_panel.position = Vector2(view.x - safe.size.x - PH_SIDE - 420.0, 24.0)
		if countdown_label:
			UIKit.style_label(countdown_label, 64, PH_ACCENT, 0)
			countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if waiting_label:
			UIKit.style_label(waiting_label, 32, PH_DIM_TEXT, 0)
			waiting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Telefon kartının yazıları + nadirlik rengi (her çekilişte; _fill_row'dan).
func _fill_phone_card(card: Button, upgrade: Dictionary, tier: int, count: int) -> void:
	var t: int = clampi(tier, 1, 4) - 1
	var tc: Color = PH_TIER[t]
	var light: Color = tc.lightened(0.25)
	(card.get_node("PhBg") as Panel).add_theme_stylebox_override("panel", _ph_box(Color(PH_PANEL, 0.97), tc, 4, 18))
	(card.get_node("PhBand") as Panel).add_theme_stylebox_override("panel", _ph_box(Color(tc, 0.3), Color(0, 0, 0, 0), 0, 14))
	var tier_lbl: Label = card.get_node("PhTier") as Label
	tier_lbl.text = PH_TIER_NAMES[t]
	tier_lbl.add_theme_color_override("font_color", light)
	(card.get_node("PhCount") as Label).text = ("x%d" % count) if count > 0 else ""
	(card.get_node("RowName") as Label).add_theme_color_override("font_color", light if t > 0 else PH_TEXT)
	var now: String = ""
	var player: Node = get_tree().get_first_node_in_group("player")
	if player:
		var id: String = str(upgrade["id"])
		if id == "max_health" and "max_health" in player:
			now = str(int(round(float(player.get("max_health")))))
		else:
			now = str(HudStatPanelScript.values_for(player).get(id, ""))
	var has_now: bool = now != "" and now != "-"
	(card.get_node("PhNowBox") as CanvasItem).visible = has_now
	var now_lbl: Label = card.get_node("PhNow") as Label
	now_lbl.visible = has_now
	now_lbl.text = "Şu an  " + now


## PC'de level atlama satırları ve evrim kartları %15 küçük - kullanıcı isteği (2026-10-03): "pcde level atlama kartlarını
## %15 küçültmeni istiyorum". Telefonla AYNI yöntem (kutu ölçeği, bkz. _apply_mobile_layout 2x/1.5x); telefon kendi ölçeğini
## kurduğu için orada uygulanmaz. Kutu yatayda ortalı ve dikey merkezi yerinde kalır (karıştır düğmesi oynamaz).
const DESKTOP_CARD_SCALE := 0.85


func _apply_desktop_scale(box: Control) -> void:
	if MobileUIScript.enabled or box == null:
		return
	var w: float = box.offset_right - box.offset_left
	var h: float = box.offset_bottom - box.offset_top
	box.offset_left = -roundf(w * DESKTOP_CARD_SCALE * 0.5)
	box.offset_right = box.offset_left + w
	box.offset_top = roundf(box.offset_top + h * (1.0 - DESKTOP_CARD_SCALE) * 0.5)
	box.offset_bottom = box.offset_top + h
	box.scale = Vector2.ONE * DESKTOP_CARD_SCALE


func _row_label(card: Control, lbl_name: String, rect: Rect2, font_size: int, color: Color, align: HorizontalAlignment) -> void:
	var lbl := Label.new()
	lbl.name = lbl_name
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	UIKit.style_label(lbl, font_size, color, 0)
	card.add_child(lbl)
	lbl.position = rect.position
	## Label ağaca girmeden/ilk karede varsayılan temayla en küçük boyutunu büyük ölçebiliyor - boyut ertelenerek de verilir.
	lbl.size = rect.size
	lbl.set_deferred("size", rect.size)


## Satırın yazıları: ad, "Tier · Kategori · Nx alındı" (tier kısmı tier renginde), sağda değer + fiil.
func _fill_row(card: Button, upgrade: Dictionary, tier: int, count: int) -> void:
	var name_lbl: Label = card.get_node_or_null("RowName") as Label
	if name_lbl == null:
		return
	## _populate_cards eski kart yerleşimi için tier adı etiketini (Content/Title) her çekilişte görünür yapıyor - satırda
	## tier adı alt satırda, bu yüzden burada gizlenir.
	var old_title: CanvasItem = card.get_node_or_null("Content/Title") as CanvasItem
	if old_title:
		old_title.visible = false
	name_lbl.text = upgrade["title"]
	var sub_text: String = "[color=#%s]%s  ·  %s[/color]" % [ROW_TIER_TEXT[clampi(tier, 1, 4) - 1].to_html(false),
		TierSystem.NAMES[tier - 1], upgrade["cat"]]
	if count > 0:
		sub_text += "[color=#%s]  ·  %dx alındı[/color]" % [ROW_DIM_COLOR.to_html(false), count]
	(card.get_node("RowSub") as RichTextLabel).text = sub_text
	var is_cdr: bool = upgrade["id"] == "cooldown_reduction"
	var clean_val: String = _scaled_desc_value(upgrade["desc"] as String, tier, str(upgrade["id"])).replace("+", "").replace("-", "")
	(card.get_node("RowValue") as Label).text = ("-" if is_cdr else "+") + clean_val
	(card.get_node("RowVerb") as Label).text = "azalır" if is_cdr else "artar"
	if _phone_cards:
		_fill_phone_card(card, upgrade, tier, count)


func _card_desc(card: Node) -> RichTextLabel:
	var d: Node = card.get_node_or_null("Plaque/Desc")
	return (d if d else card.get_node("Content/Desc")) as RichTextLabel


func _card_count(card: Node) -> Label:
	var c: Node = card.get_node_or_null("Plaque/CountLabel")
	return (c if c else card.get_node("Content/CountLabel")) as Label


static func _set_desc_font_size(desc: RichTextLabel, font_size: int) -> void:
	for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		desc.add_theme_font_size_override(key, font_size)


## Levhaya sığmayan (çok satıra kırılan) açıklamayı CARD_DESCRIPTION_MIN_FONT_SIZE'a kadar küçültür (yerleşimden sonra çağrılır).
func _fit_plaque_desc() -> void:
	if not is_inside_tree():
		return
	for card: Button in cards:
		if not is_instance_valid(card):
			continue
		var desc: RichTextLabel = _card_desc(card)
		var room: float = TierCardFx.PLAQUE_INNER_RECT.size.y - 30.0
		var fs: int = CARD_DESCRIPTION_FONT_SIZE
		_set_desc_font_size(desc, fs)
		while fs > CARD_DESCRIPTION_MIN_FONT_SIZE and float(desc.get_content_height()) > room:
			fs -= 8
			_set_desc_font_size(desc, fs)


func _ensure_fx_layer() -> Control:
	if is_instance_valid(_fx_layer):
		return _fx_layer
	_fx_layer = Control.new()
	_fx_layer.name = "PickFx"
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)
	return _fx_layer


## Yetenek hover ipucundaki (bkz. skill_icon.gd _format_lol_style) İLE AYNI
## fikir: her statın adı kendi anlamını çağrıştıran bir renkte gösterilir
## (kullanıcı isteği: "can yazdığında can rengi yeşil görünüyor ya onun
## gibi") - böylece kartlar tek bakışta hangi kategoriye ait olduğunu
## belli eder. Sayı değeri her zaman altın turuncusuyla (#ffaa00) vurgulanır.
## 2026-09-24: renkler parşömen üstünde okunan koyu "mürekkep" tonlarına çekildi (eski neon tonlar bej kartta kayboluyordu) -
## TEK kaynak UIKit.INK (yetenek ipuçları da aynı tonları kullanır).
const STAT_TITLE_COLORS := {
	"speed": UIKit.INK["speed"],
	"max_health": UIKit.INK["health"],
	"damage": UIKit.INK["damage"],
	"fire_rate": UIKit.INK["attack_speed"],
	"health_regen": UIKit.INK["health"],
	"crit_chance": UIKit.INK["crit"],
	"crit_damage": UIKit.INK["damage"],
	"pickup_range": UIKit.INK["speed"],
	"shield_pen_percent": UIKit.INK["shield_pen"],
	"exp_gain": UIKit.INK["exp"],
	"luck": UIKit.INK["luck"],
	"range": UIKit.INK["range"],
	"dodge": UIKit.INK["health"],
	"shield_amount": UIKit.INK["shield"],
	"cooldown_reduction": UIKit.INK["cooldown"],
	"shield_protection": UIKit.INK["shield"],
}

## Kartta gösterilen sayı, upgrade["desc"]'teki (tier 1) ham sayının tier
## katı kadar büyütülmüş hali - gerçek uygulanan değerle (bkz. player.gd
## apply_upgrade tier_mult) birebir eşleşmesi için AYNI "taban × tier"
## mantığı burada da tekrarlanıyor (ikisi de tek bir kaynaktan - upgrade["desc"]
## ve tier parametresinden - türediği için asla sapamaz).
func _scaled_desc_value(raw_desc: String, tier: int, id: String = "") -> String:
	var sign_str: String = "+"
	var rest: String = raw_desc
	if rest.begins_with("+") or rest.begins_with("-"):
		sign_str = rest.substr(0, 1)
		rest = rest.substr(1)
	var is_percent: bool = rest.begins_with("%")
	if is_percent:
		rest = rest.substr(1)
	## DÜZELTME (kullanıcı isteği: "level atlama kartlarının her tier başına
	## artışını %30 yapalım") - bkz. player.gd apply_upgrade()'teki BİREBİR
	## AYNI formül (tier_mult) - ikisi de tier1=×1.0, tier2=×1.3, tier3=×1.6,
	## tier4=×1.9 versin diye TEK kaynaktan (raw_desc ve tier) türüyor, asla
	## sapamaz.
	## SONRAKİ DÜZELTME (kullanıcı isteği: "Can çalmanı statların 1. kademede
	## 0.3 kademe başına 0.3 arttırarak tekrar düzenle") - "lifesteal" bu
	## paylaşılan tier_mult eğrisinden BİLEREK çıkarıldı (bkz. player.gd
	## apply_upgrade "lifesteal" dalı), burada da AYNI özel dal olmadan
	## gösterilen sayı gerçek uygulanan değerden sapardı.
	## SONRAKİ DÜZELTME (kullanıcı isteği: "can çalma tier 1: %1 ... tier 4:
	## %2.5") - bkz. TierSystem.lifesteal_percent_for_tier (player.gd apply_upgrade
	## ile TEK kaynak). Ayrıca _get_friendly_desc bu fonksiyona eskiden `id`
	## GEÇMİYORDU (yani üstteki özel dal kartta hiç çalışmıyordu, ekranda
	## paylaşılan x1.3 eğrisiyle yanlış sayı görünüyordu) - artık geçiliyor.
	var scaled: float
	if id == "lifesteal":
		scaled = TierSystem.lifesteal_percent_for_tier(tier) * 100.0
	elif id == "max_health":
		scaled = TierSystem.health_card_for_tier(tier) ## 20/35/50/70 - bkz. TierSystem (player.gd ile tek kaynak)
	elif id == "health_regen":
		scaled = TierSystem.regen_card_for_tier(tier) ## 2/4/6/8 - bkz. TierSystem
	else:
		scaled = rest.to_float() * (1.0 + float(tier - 1) * 0.3)
	var formatted: String
	if is_equal_approx(scaled, round(scaled)):
		formatted = str(int(round(scaled)))
	else:
		formatted = "%.1f" % scaled
	return "%s%s%s" % [sign_str, ("%" if is_percent else ""), formatted]


func _get_friendly_desc(upgrade: Dictionary, tier: int) -> String:
	var value: String = _scaled_desc_value(upgrade["desc"] as String, tier, str(upgrade["id"]))
	var clean_val: String = value.replace("+", "").replace("-", "")
	var title_name: String = upgrade["title"] as String
	var title_color: String = STAT_TITLE_COLORS.get(upgrade["id"], UIKit.INK["text"])
	var colored_title: String = "[color=%s][b]%s[/b][/color]" % [title_color, title_name]
	## 2026-09-25 savaş kartı: kazanılan değer levhanın en büyük yazısı (m5x7'nin keskin durduğu 64 px) - kart bir bakışta
	## "ne kadar güçlendim" desin; stat adı üstünde kendi renginde, fiil (artar/azalır) değerin altında küçük.
	var colored_val: String = "[font_size=%d][color=%s]%s%s[/color][/font_size]" % [CARD_VALUE_FONT_SIZE, UIKit.INK["value"],
		"-" if upgrade["id"] == "cooldown_reduction" else "+", clean_val]
	var verb: String = "azalır" if upgrade["id"] == "cooldown_reduction" else "artar"
	return "%s\n%s\n[font_size=%d][color=%s]%s[/color][/font_size]" % [colored_title, colored_val, CARD_COUNT_FONT_SIZE * 2,
		UIKit.C_TEXT_DIM.to_html(false), verb]


## #48 DÜZELTME (kullanıcı isteği: "Level kartı reroll'u altınla olsun,
## level başına +1 altın"): eskiden reroll koşum başına sabit 2 ücretsiz
## hakla sınırlıydı. Artık SINIRSIZ ama her kullanımda altın harcıyor -
## her takım seviye atlayışında kazanılan +1 altınla (bkz. game_manager.gd
## LEVEL_UP_GOLD_REWARD) biriktirilip kullanılabiliyor.
## DÜZELTME (kullanıcı isteği 2026-09-24 denge turu: "oyunun ekonomisine bağlı olarak karıştırma fiyatı düşük
## pahalılıkta başlayıp rolladıkça fiyatı yükselsin") - eskiden sabit 5 altın/sınırsız: altını olan Efsanevi kart
## bulana kadar çevirebiliyordu. Artık:
##   fiyat = 3 altın tabanlı, Kademe/zamanla büyüyen ve her karıştırmada artan (3, 6, 9, 12 ...) formül - formülün
##   TEK kaynağı merchant_shop_screen.gd reroll_cost (seyyar satıcının karıştırması da aynısını kullanır).
## Her seviye atlayışında ekran yeniden oluşturulduğu için sayaç kendiliğinden sıfırlanır.
const MerchantShopScript := preload("res://scripts/merchant_shop_screen.gd")
var _rerolls_this_screen: int = 0


func _reroll_cost() -> int:
	return MerchantShopScript.reroll_cost(_rerolls_this_screen)

## Kullanıcı seçimi (2026-09-25, prototip "Karıştır 2 - Altın Kenarlı + Zar"; eskiden kitin ahşap butonu): koyu gövde +
## altın kenarlı 9-slice buton (tools/gen_menu_kit.py levelup_reroll: 10x10 sanat px, pay 3 sanat px = 9 px), solda piksel
## zar (levelup_die, 33 px), krem yazı "Yeniden Karıştır (N altın)". Altın yetmezse gri kenarlı pasif doku + sönük yazı/zar.
## Prototipteki yerinde: satırların altında y 800..860 (1080p); geri sayım paneli (çok oyunculu) onun altına kaydı.
const REROLL_TEXTURES := {
	"normal": preload("res://assets/ui/game/levelup_reroll_normal.png"),
	"hover": preload("res://assets/ui/game/levelup_reroll_hover.png"),
	"pressed": preload("res://assets/ui/game/levelup_reroll_pressed.png"),
	"disabled": preload("res://assets/ui/game/levelup_reroll_disabled.png"),
}
const REROLL_DIE := preload("res://assets/ui/game/levelup_die.png")
const REROLL_SIZE := Vector2(420, 60)
const REROLL_TOP := 260.0 ## ekran ortasına göre


func _apply_reroll_button_style() -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var sb := StyleBoxTexture.new()
		sb.texture = REROLL_TEXTURES["pressed" if state == "hover_pressed" else state]
		sb.set_texture_margin_all(9.0)
		## Zar sol kenardan 26 px içeride (prototipte zarın merkezi x+42), yazı kalan alanda ortalı.
		sb.content_margin_left = 26.0
		sb.content_margin_right = 16.0
		sb.content_margin_top = 0.0
		sb.content_margin_bottom = 0.0
		reroll_button.add_theme_stylebox_override(state, sb)
	reroll_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	reroll_button.icon = REROLL_DIE
	reroll_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	reroll_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	reroll_button.expand_icon = false
	reroll_button.add_theme_font_size_override("font_size", UIKit.FS_BODY)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		reroll_button.add_theme_color_override(c, UIKit.C_CREAM)
	reroll_button.add_theme_color_override("font_disabled_color", Color(UIKit.C_CREAM, 0.45))
	reroll_button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.45))
	reroll_button.add_theme_color_override("font_outline_color", UIKit.C_OUTLINE)
	reroll_button.add_theme_constant_override("outline_size", 4)
	reroll_button.offset_left = -REROLL_SIZE.x * 0.5
	reroll_button.offset_right = REROLL_SIZE.x * 0.5
	reroll_button.offset_top = REROLL_TOP
	reroll_button.offset_bottom = REROLL_TOP + REROLL_SIZE.y


## "SEVİYE ATLADIN!" başlığı - kullanıcı seçimi (2026-09-25, prototip "Başlık 4 - Işıltılı Yazı"; eskiden kitin kurdelesi):
## krem yazının arkasında 3 basamaklı altın ışık + 4 piksel kıvılcım (tools/gen_menu_kit.py levelup_title_glow, 224x32 sanat
## px = 672x96, esnetilmez - Label tam doku boyunda). Yazı 64 px krem, koyu kontur (prototipteki 2 px piksel kontur).
const TITLE_GLOW := preload("res://assets/ui/game/levelup_title_glow.png")
const TITLE_SIZE := Vector2(672, 96)
const TITLE_TOP := 22.0 ## ekranın üstünden (prototipte dış basamak y 28..112)


## Level atlama ekranı - oyun içi bej kit (bkz. UIKit): sıcak karartma, kurdele başlık, kartlarda koyu yazı (kart
## çerçeveleri TierSystem.FRAME_TEXTURES), kit penceresinde geri sayım, altın seçim parıltısı. CanvasLayer temayı
## çocuklarına aktarmadığı için tema her üst düzey Control'e ayrı verilir. .tscn'ye dokunulmadı (açık editör eski hâli
## üstüne yazabilir) - görünüm tamamen buradan.
func _apply_kit_style() -> void:
	var game_theme: Theme = UIKit.theme()
	var dim: ColorRect = get_node_or_null("Dim") as ColorRect
	if dim:
		dim.color = Color(0.12, 0.07, 0.03, 0.55)
	var title: Label = get_node_or_null("Title") as Label
	if title:
		title.theme = game_theme
		var glow_sb := StyleBoxTexture.new()
		glow_sb.texture = TITLE_GLOW
		title.add_theme_stylebox_override("normal", glow_sb)
		UIKit.style_label(title, UIKit.FS_BIG, UIKit.C_CREAM, 6)
		title.remove_theme_color_override("font_shadow_color")
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.offset_left = -TITLE_SIZE.x * 0.5
		title.offset_right = TITLE_SIZE.x * 0.5
		title.offset_top = TITLE_TOP
		title.offset_bottom = TITLE_TOP + TITLE_SIZE.y
	var container: Control = get_node_or_null("CardsContainer") as Control
	if container:
		container.theme = game_theme
	for card: Button in cards:
		var glow: Panel = card.get_node_or_null("SelectGlow") as Panel
		if glow:
			var gs := StyleBoxFlat.new()
			gs.bg_color = Color(0, 0, 0, 0)
			gs.set_border_width_all(6)
			gs.border_color = Color("#eab748")
			gs.set_corner_radius_all(18)
			gs.shadow_color = Color(0.92, 0.72, 0.28, 0.5)
			gs.shadow_size = 10
			glow.add_theme_stylebox_override("panel", gs)
		var count_label: Label = _card_count(card)
		if count_label:
			count_label.add_theme_color_override("font_color", UIKit.C_TEXT_DIM)
		var desc: RichTextLabel = _card_desc(card)
		if desc:
			desc.add_theme_color_override("default_color", UIKit.C_TEXT)
	reroll_button.theme = game_theme
	if countdown_panel:
		countdown_panel.theme = game_theme
		countdown_panel.add_theme_stylebox_override("panel", UIKit.panel_style("window_tight"))
		countdown_panel.offset_top = REROLL_TOP + REROLL_SIZE.y + 12.0
		countdown_panel.offset_bottom = REROLL_TOP + REROLL_SIZE.y + 86.0
	if waiting_label:
		waiting_label.add_theme_color_override("font_color", UIKit.C_TEXT)
	if countdown_label:
		countdown_label.add_theme_color_override("font_color", UIKit.C_GOLD)


func _refresh_reroll_button() -> void:
	## Kalıcı "Ücretsiz Karıştırma" geliştirmesi (Ruh Mağazası): koşuda bir kez bedava.
	if GameManager.free_rerolls_left > 0:
		reroll_button.text = "Karıştır\nÜCRETSİZ" if MobileUIScript.enabled else "Yeniden Karıştır (ÜCRETSİZ)"
		reroll_button.disabled = false
		return
	var cost: int = _reroll_cost()
	reroll_button.text = ("Karıştır\n%d altın" if MobileUIScript.enabled else "Yeniden Karıştır (%d altın)") % cost
	reroll_button.disabled = GameManager.gold < cost


func _on_reroll_pressed() -> void:
	if not GameManager.try_use_free_reroll():
		var cost: int = _reroll_cost()
		if GameManager.gold < cost:
			return
		GameManager.gold -= cost
		_rerolls_this_screen += 1
	_populate_cards()
	_refresh_reroll_button()
	_animate_cards_in()


## DÜZELTME (kullanıcı isteği: "bir oyuncu diğerlerinin seçmesini beklemeden
## tüm kartlarını seçebilsin FAKAT hepsini seçtikten sonra bekleme süresi
## başlayacak") - eskiden çok oyunculuda burada ekran AÇIK kalıp (kartlar
## kilitlenip yeşil bir "seçildi" vurgusuyla) tüm oyuncular seçene kadar
## bekleniyordu - bir oyuncunun kendi kuyruğunda başka kartlar olsa bile
## HER kart seçiminde bu bekleme tekrarlanıyordu. Artık singleplayer/
## multiplayer FARK ETMEKSİZİN ekran ANINDA kapanıyor (bkz. main.gd
## _on_upgrade_chosen) - kuyruk bitmediyse bir sonraki kart hemen açılır,
## kuyruk BİTTİYSE main.gd ayrı bir "diğer oyuncular bekleniyor" ekranı
## gösterir (bkz. main.gd _show_level_up_wait_overlay).
##
## Kullanıcı isteği (2026-09-25): "bir kartı seçince parıltı ve ödüllendirici bir ses efekti çıksın ve 1 saniye boyunca kart
## parıldasın sonrasında level kart seçim ekranı kapansın böyle çok ruhsuz." - seçim artık önce TierCardFx.celebrate'i
## (ses + parlama + hale + kıvılcım, TierCardFx.PICK_DURATION = 1 sn) oynatıyor, upgrade_chosen ancak o bitince yayılıyor
## (main.gd ekranı onu alınca kapatır). Bu sürede ağaç zaten duraklatılmış (main.gd _show_level_up_screen) - oyun
## akmıyor; _has_chosen HEMEN true olduğundan ikinci bir tık/1-2-3 tuşu/süre dolumu otomatik seçimi yeniden tetiklemez,
## karıştır butonu da kapanır. Tween bu ekrana bağlı: ekran başka bir sebeple (oyun sıfırlama vb.) serbest kalırsa
## sinyal hiç yayılmaz, eski/yarım bir seçim uygulanmaz.
func _on_card_pressed(id: String, tier: int, card: Button) -> void:
	if _has_chosen:
		return
	_has_chosen = true
	if is_instance_valid(reroll_button):
		reroll_button.disabled = true
	for i in range(cards.size()):
		if _shine_tweens[i] and _shine_tweens[i].is_valid():
			_shine_tweens[i].kill()
		if _card_tweens[i] and _card_tweens[i].is_valid():
			_card_tweens[i].kill()
		var other: Button = cards[i]
		if not is_instance_valid(other):
			continue
		other.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if other == card:
			continue
		## Seçilmeyen kartlar sönüp hafifçe geri çekilir - göz seçilen karta gitsin.
		other.pivot_offset = other.size * 0.5
		TierCardFx.set_hover_glow(other, int(_card_tiers[i]), false)
		var fade := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		fade.tween_property(other, "modulate", Color(0.55, 0.52, 0.5, 0.35), 0.3)
		fade.tween_property(other, "scale", Vector2(0.94, 0.94), 0.3)
	## Açılış animasyonu yarıda kesildiyse (ekran açılır açılmaz 1/2/3'e basıldı) kart tam görünür olsun ve HBox onu asıl
	## yerine geri koysun.
	card.modulate = Color(1, 1, 1, 1)
	var container: Container = card.get_parent() as Container
	if container:
		container.queue_sort()
	var frame: TextureRect = card.get_node_or_null("Frame") as TextureRect
	var tw: Tween = TierCardFx.celebrate(self, card, frame, tier, _ensure_fx_layer())
	tw.chain().tween_callback(_finish_pick.bind(id, tier))


## Ekranın kendisini serbest bırakmak main.gd'nin _on_upgrade_chosen'ına bırakılıyor (o zaten _active_level_up_screen'i -
## yani bu sahneyi - queue_free() ediyor).
func _finish_pick(id: String, tier: int) -> void:
	upgrade_chosen.emit(id, tier)


## ================================================================ YETENEK EVRİMİ (2026-09-28)
## Kullanıcı isteği: "her 5 levelde bir her karaktere oynadığı karaktere göre 3 kart sunulacak" - 5/10/15... seviyelerde bu
## ekran normal stat kartları YERİNE karakterin Q/E/R evrimlerinden rastgele 3'ünü gösterir (havuz kuralları ve metinler
## scripts/skill_evolutions.gd'de - TEK kaynak). Seçim upgrade_chosen("evo:<id>") ile gider (main.gd _on_upgrade_chosen ->
## player.apply_skill_evolution). Karıştırma YOK (kullanıcı: "pardon reroll olmasın"). Havuzda 3'ten az evrim kaldıysa boş
## kartlar gizlenir; hiç kalmadıysa (ya da karakterin evrimleri henüz yazılmadıysa) normal kartlar çıkar.
## Görünüm (kullanıcı isteği 2026-10-02: "skill evrimlerinin dikey mor kartlardan olmasını istiyorum final versiyonu da
## kırmızı dikey kartlardan olsun (oyunun içindeki efsun kartlarında bulunuyor bu kartlar)"): yatay satırlar yerine efsun
## ekranının dikey kartı (480x720, 4x sanat pikseli) - normal evrim mor (Tier 3), FİNAL kırmızı (Tier 4). Doku, hale ve
## kart içi yerleşim enchant_screen.gd'den okunur (tek kaynak): sol üstte yeteneğin ikonu + tuşu, sağında "EVRİM n/N" /
## "FİNAL EVRİM" ve "Q · Yetenek adı", altta evrim adı + açıklama (sayılar altın).
const SkillEvolutions := preload("res://scripts/skill_evolutions.gd")
const EnchantScreenScript := preload("res://scripts/enchant_screen.gd")
const EVO_TITLE := "YETENEK EVRİMİ!"
const EVO_CARD_GAP := 30
## 2026-10-02: kartlar 480x720 -> 360x540 (bkz. enchant_screen.gd CARD_TEXEL notu) - başlığın altında, geri sayım hemen altlarında.
const EVO_CARD_TOP := -340.0 ## ekran ortasına göre (başlığın altı) - 540 px kart y 200..740
const EVO_COUNTDOWN_TOP := 216.0 ## karıştır butonu evrimde gizli; geri sayım kartların altına iner
const EVO_TEXT_FONT_SIZE := 32
const EVO_TEXT_MIN_FONT_SIZE := 16
const EVO_TIER_REGULAR := 3
const EVO_TIER_FINAL := 4
const EVO_TITLE_COLOR := Color("#fff0d6")
const EVO_LAYER := 42

## main.gd verir (add_child'dan ÖNCE): bu ekranın ait olduğu takım seviyesi; debug menüsü evrim ekranını seviyeden bağımsız açar.
var screen_level: int = 0
var force_evolution: bool = false
var _evo_mode: bool = false
var _evo_offers: Array = []
## Telefonda evrim kartının 3x'e göre ölçeği (bkz. _layout_evolution_cards); masaüstünde 1.
var _k: float = 1.0


func _roll_evolution_offers() -> Array:
	var char_id: int = GameManager.selected_char_id
	if not SkillEvolutions.has_evolutions(char_id):
		return []
	if not force_evolution and not SkillEvolutions.is_evolution_level(screen_level):
		return []
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not ("skill_evolutions" in player):
		return []
	return SkillEvolutions.roll_offer(char_id, player.skill_evolutions, screen_level)


## Kartlar çalışma anında yatay bir kutuya taşınır (.tscn'ye dokunulmaz - açık editör eski hâli üstüne yazabilir); eski
## Content/SelectGlow gizlenir, efsun kartının yazı düğümleri burada kurulur.
func _layout_evolution_cards() -> void:
	var old: Control = get_node_or_null("CardsContainer") as Control
	var n: int = clampi(_evo_offers.size(), 1, cards.size())
	## Telefon: efsun ekranıyla aynı - kart k katı (5/3 -> 600x900), ekranın boyu kadar (bkz. enchant_screen.gd card_rect).
	var gap: float = EnchantScreenScript.MOBILE_CARD_GAP if MobileUIScript.enabled else float(EVO_CARD_GAP)
	_k = MobileUIScript.choice_card_scale(get_viewport(), EnchantScreenScript.CARD_SIZE, 3, gap)
	var card_size: Vector2 = (EnchantScreenScript.CARD_SIZE * _k).round()
	var total_w: float = card_size.x * n + gap * (n - 1)
	var row := HBoxContainer.new()
	row.name = "EvoCards"
	row.theme = UIKit.theme()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(gap))
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.offset_left = -total_w * 0.5
	row.offset_right = total_w * 0.5
	row.offset_top = EVO_CARD_TOP
	if _k > 1.0:
		row.offset_top = MobileUIScript.CHOICE_TOP - get_viewport().get_visible_rect().size.y * 0.5
	row.offset_bottom = row.offset_top + card_size.y
	_apply_desktop_scale(row)
	add_child(row)
	if old:
		move_child(row, old.get_index())
		old.visible = false
	if countdown_panel:
		countdown_panel.offset_top = EVO_COUNTDOWN_TOP
		countdown_panel.offset_bottom = EVO_COUNTDOWN_TOP + 74.0
	for card: Button in cards:
		if not is_instance_valid(card):
			continue
		card.reparent(row, false)
		card.custom_minimum_size = card_size
		card.clip_contents = false ## seçim halesi kartın dışına taşar (bkz. TierCardFx.ensure_glow)
		card.set_meta("glow_texture", EnchantScreenScript.GLOW_TEXTURE)
		card.set_meta("glow_card_size", card_size)
		card.set_meta("glow_pad", TierCardFx.GLOW_PAD * _k)
		card.set_meta("glow_colors", EnchantScreenScript.GLOW_COLORS)
		var frame: TextureRect = card.get_node_or_null("Frame") as TextureRect
		if frame:
			frame.offset_right = card_size.x
			frame.offset_bottom = card_size.y
		for n_name in ["Content", "SelectGlow"]:
			var node: CanvasItem = card.get_node_or_null(n_name) as CanvasItem
			if node:
				node.visible = false
		var icon_rect: Rect2 = EnchantScreenScript.card_rect(EnchantScreenScript.ICON_RECT, _k)
		var icon := TextureRect.new()
		icon.name = "EvoIcon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(icon)
		icon.position = icon_rect.position
		icon.size = icon_rect.size
		var key_box: float = 32.0 * _k
		_row_label(card, "EvoKey", Rect2(icon_rect.end - Vector2(key_box, key_box), Vector2(key_box, key_box)), 40 if _k > 1.0 else 24, UIKit.C_CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
		var key_lbl: Label = card.get_node("EvoKey") as Label
		key_lbl.add_theme_constant_override("outline_size", 6)
		key_lbl.add_theme_color_override("font_outline_color", UIKit.C_OUTLINE)
		var head_fs: int = EnchantScreenScript.header_fonts(_k)[0]
		_row_label(card, "EvoTier", EnchantScreenScript.card_rect(EnchantScreenScript.TIER_RECT, _k), head_fs, UIKit.C_CREAM, HORIZONTAL_ALIGNMENT_LEFT)
		_row_label(card, "EvoSkill", EnchantScreenScript.card_rect(EnchantScreenScript.CATEGORY_RECT, _k), head_fs, EnchantScreenScript.DIM_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
		for lbl_name in ["EvoTier", "EvoSkill"]:
			(card.get_node(lbl_name) as Label).clip_text = true
		var text := RichTextLabel.new()
		text.name = "EvoDesc"
		text.bbcode_enabled = true
		text.fit_content = false
		text.scroll_active = false
		text.clip_contents = true
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_color_override("default_color", EnchantScreenScript.DIM_COLOR)
		text.add_theme_constant_override("line_separation", 2)
		_set_desc_font_size(text, EVO_TEXT_FONT_SIZE)
		card.add_child(text)
		text.position = EnchantScreenScript.card_rect(EnchantScreenScript.TEXT_RECT, _k).position
		text.size = EnchantScreenScript.card_rect(EnchantScreenScript.TEXT_RECT, _k).size


func _populate_evolution_rows() -> void:
	var player := get_tree().get_first_node_in_group("player")
	for i in range(cards.size()):
		var card: Button = cards[i]
		if not is_instance_valid(card):
			continue
		for conn in card.pressed.get_connections():
			card.pressed.disconnect(conn["callable"])
		card.text = ""
		if i >= _evo_offers.size():
			card.visible = false
			card.disabled = true
			continue
		var evo: Dictionary = _evo_offers[i]
		var tier: int = EVO_TIER_FINAL if bool(evo.get("final", false)) else EVO_TIER_REGULAR
		card.pressed.connect(_on_card_pressed.bind(SkillEvolutions.CHOICE_PREFIX + str(evo["id"]), tier, card))
		_card_tiers[i] = tier
		_apply_card_tier_frame(card, tier)
		if _shine_tweens[i] and _shine_tweens[i].is_valid():
			_shine_tweens[i].kill()
		_shine_tweens[i] = TierCardFx.start_idle_shine(self, card.get_node_or_null("Frame") as TextureRect, tier, 0.5 + 0.35 * i)
		_fill_evolution_card(card, evo, tier, player)
	_fit_evolution_desc.call_deferred()


## Kart yazıları: "EVRİM n/N" ya da "FİNAL EVRİM" (tier renginde), "Q · Yetenek adı", evrim adı + açıklama (sayılar altın).
func _fill_evolution_card(card: Button, evo: Dictionary, tier: int, player: Node) -> void:
	var char_id: int = GameManager.selected_char_id
	var slot: String = str(evo.get("slot", "skill"))
	var def: Dictionary = Characters.get_def(char_id)
	var key: String = str(SkillEvolutions.SLOT_KEYS.get(slot, "Q"))
	var owned: Dictionary = player.skill_evolutions if player != null and "skill_evolutions" in player else {}
	var total: int = SkillEvolutions.slot_list(char_id, slot).size()
	var next_n: int = SkillEvolutions.owned_count(char_id, slot, owned) + 1
	var tier_lbl: Label = card.get_node("EvoTier") as Label
	tier_lbl.text = "FİNAL EVRİM" if tier == EVO_TIER_FINAL else "EVRİM %d/%d" % [next_n, total]
	tier_lbl.add_theme_color_override("font_color", EnchantScreenScript.TIER_TEXT[clampi(tier, 1, 4) - 1])
	EnchantScreenScript._fit_header(tier_lbl, EnchantScreenScript.card_rect(EnchantScreenScript.TIER_RECT, _k).size.x, EnchantScreenScript.header_fonts(_k))
	var skill_lbl: Label = card.get_node("EvoSkill") as Label
	## "<yuva>_evo_name": iki varyasyonlu yuvalar (Büyücü Kız) evrim kartında ikisinin adını birden gösterir.
	skill_lbl.text = "%s  ·  %s" % [key, str(def.get(slot + "_evo_name", def.get(slot + "_name", "")))]
	EnchantScreenScript._fit_header(skill_lbl, EnchantScreenScript.card_rect(EnchantScreenScript.CATEGORY_RECT, _k).size.x, EnchantScreenScript.header_fonts(_k))
	(card.get_node("EvoKey") as Label).text = key
	(card.get_node("EvoDesc") as RichTextLabel).text = "[color=#%s]%s[/color]\n\n%s" % [
		EVO_TITLE_COLOR.to_html(false), str(evo.get("name", "")), _evo_desc_bbcode(str(evo.get("desc", "")))]
	var icon_path: String = str(def.get(slot + "_icon", ""))
	var icon: TextureRect = card.get_node("EvoIcon") as TextureRect
	icon.texture = (load(icon_path) as Texture2D) if (icon_path != "" and ResourceLoader.exists(icon_path)) else null


## Açıklamadaki sayılar/yüzdeler altın renginde (level kartlarındaki değer rengi).
func _evo_desc_bbcode(text: String) -> String:
	var regex := RegEx.new()
	if regex.compile("%?\\d+(?:[.,]\\d+)?(?:\\s*saniye)?") != OK:
		return text
	var out: String = ""
	var last: int = 0
	for m in regex.search_all(text):
		out += text.substr(last, m.get_start() - last)
		out += "[color=#%s]%s[/color]" % [ROW_VALUE_COLOR.to_html(false), m.get_string()]
		last = m.get_end()
	return out + text.substr(last)


## Karta sığmayan metin EVO_TEXT_MIN_FONT_SIZE'a kadar 8'er px küçülür (m5x7 8'in katlarında net; yerleşimden sonra).
func _fit_evolution_desc() -> void:
	if not is_inside_tree():
		return
	for card: Button in cards:
		if not is_instance_valid(card) or not card.visible:
			continue
		var desc: RichTextLabel = card.get_node_or_null("EvoDesc") as RichTextLabel
		if desc == null:
			continue
		var fs: int = EVO_TEXT_FONT_SIZE if _k <= 1.0 else int(EnchantScreenScript.body_fonts(_k)[0])
		_set_desc_font_size(desc, fs)
		## İlk ölçüm de bir kare sonra - yerleşim bitmeden okunan yükseklik eski/şişkin çıkıp yazıyı boşuna küçültüyordu.
		await get_tree().process_frame
		if not is_instance_valid(desc):
			return
		while fs > EVO_TEXT_MIN_FONT_SIZE and float(desc.get_content_height()) > desc.size.y:
			fs -= 8
			_set_desc_font_size(desc, fs)
			## İçerik yüksekliği bir sonraki karede güncellenir - hemen tekrar ölçmek eski değeri okur.
			await get_tree().process_frame
			if not is_instance_valid(desc):
				return
