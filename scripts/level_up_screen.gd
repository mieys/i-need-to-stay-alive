extends CanvasLayer

signal upgrade_chosen(id: String, tier: int)

## Kategori renkleri artık bej kart parşömeni ÜSTÜNDE okunan koyu tonlar (kullanıcı isteği 2026-09-24: oyun içi arayüzler
## menülerle aynı bej/ahşap kite geçti) - TEK kaynak UIKit (silah seçim kartları da aynılarını kullanır).
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
	{"id": "max_health", "title": "Can", "desc": "+15", "cat": "Savunma", "color": CAT_DEFENSE},
	{"id": "damage", "title": "Saldırı Gücü", "desc": "+6", "cat": "Saldırı", "color": CAT_ATTACK},
	## "Ateş Hızı" -> "Saldırı Hızı" (2026-09-24): eşyalar/stat ekranı aynı stat için "saldırı hızı" diyordu, iki ayrı stat
	## sanılıyordu (bkz. player.gd get_attack_interval_mult).
	{"id": "fire_rate", "title": "Saldırı Hızı", "desc": "+%6", "cat": "Saldırı", "color": CAT_ATTACK},
	{"id": "health_regen", "title": "Can Yenilenmesi", "desc": "+0.5", "cat": "Savunma", "color": CAT_DEFENSE},
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
	{"id": "pickup_range", "title": "Toplama Mesafesi", "desc": "+%30", "cat": "Yardımcı", "color": CAT_UTILITY},
	{"id": "shield_pen_percent", "title": "Kalkan Delme", "desc": "+%5", "cat": "Saldırı", "color": CAT_ATTACK},
	{"id": "exp_gain", "title": "Tecrübe Kazanımı", "desc": "+%5", "cat": "Yardımcı", "color": CAT_UTILITY},
	{"id": "luck", "title": "Şans", "desc": "+1", "cat": "Yardımcı", "color": CAT_UTILITY},
	{"id": "range", "title": "Menzil", "desc": "+%12", "cat": "Saldırı", "color": CAT_ATTACK},
	{"id": "dodge", "title": "Sıvışma", "desc": "+%2.5", "cat": "Savunma", "color": CAT_DEFENSE},
	{"id": "shield_amount", "title": "Kalkan Miktarı", "desc": "+%5", "cat": "Savunma", "color": CAT_DEFENSE},
	{"id": "cooldown_reduction", "title": "Bekleme Süresi Azaltma", "desc": "-%4", "cat": "Yardımcı", "color": CAT_UTILITY},
	## Kullanıcı isteği: "kalkan emilimi statının adını kalkan soğurma olarak
	## değiştir ve level atlama kartlarına kalkan soğurma statlarını ekle.
	## (level başına %4) Kalkan soğurma en fazla %92 olsun" - eskiden
	## "shield_protection" (o zamanki adıyla "Kalkan Koruması") bu havuzdan
	## çıkarılmıştı (bkz. aşağıdaki eski yorum), şimdi YENİ isim ve YENİ
	## sabit (+%4, cooldown_reduction ile AYNI desen - kart-güçlendirme
	## çarpanına tabi değil) ile geri eklendi (bkz. player.gd apply_upgrade
	## "shield_protection" dalı, SHIELD_PROTECTION_CAP=0.92).
	{"id": "shield_protection", "title": "Kalkan Soğurma", "desc": "+%4", "cat": "Savunma", "color": CAT_DEFENSE},
	## Kullanıcı isteği (3. tur): "kart seçimlerine itme ve can çalma statını
	## ekle" - "knockback" (Geri Tepme) 1. turda çıkarılmıştı, şimdi geri
	## eklendi; "lifesteal" (Can Çalma) ilk kez ekleniyor (bkz. player.gd
	## apply_upgrade "lifesteal" dalı - mekanizma zaten vardı, kart yoktu).
	{"id": "knockback", "title": "Geri Tepme", "desc": "+19.5", "cat": "Saldırı", "color": CAT_ATTACK},
	## Kullanıcı isteği: "Can çalma veren tüm statları %70 azalt" - +%1 -> +%0.3.
	{"id": "lifesteal", "title": "Can Çalma", "desc": "+%1", "cat": "Saldırı", "color": CAT_ATTACK},
]
## Kullanıcı isteği (1. tur): "kalkan emilimini ve geri tepmeyi kaldır, can
## yenilenmesini ekle" - "shield_protection" (o zamanki adıyla "Kalkan
## Koruması") ve "knockback" (Geri Tepme) kartları bu havuzdan çıkarılmıştı,
## yerine "health_regen" eklenmişti. "shield_protection" artık "Kalkan
## Soğurma" adıyla yeniden eklendi (2. tur kullanıcı isteği), "knockback" da
## şimdi (3. tur) "lifesteal" ile birlikte YUKARIDA geri/yeni eklendi.

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
	UISound.apply_wood_buttons(self) ## bkz. ui_sound.gd - tüm butonları ahşap stile çevirir (kart butonları "icon slot" gibi dikey orantılı oldukları için bu zaten atlıyor, bkz. o dosyadaki _looks_like_icon_slot)
	_apply_reroll_button_style()
	_apply_kit_style()
	_layout_rows()
	_populate_cards()
	_wire_card_hover_feedback()
	reroll_button.pressed.connect(_on_reroll_pressed)
	_refresh_reroll_button()
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
	if is_instance_valid(card) and not card.disabled:
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
	var idx: int = randi() % cards.size()
	var card: Button = cards[idx]
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
const ROW_ART_SIZE := Vector2(268, 50)
const ROW_SEPARATION := 22
const ROW_TOP := -270.0 ## ekran ortasına göre (başlık kurdelesinin altı, karıştır butonunun üstü)
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
## Satır içi yerleşim (px): ikon yuvasının içi (dokuda 18..132, kenar halkası düşülmüş); yazılar yuvanın sağından, değer sağa yaslı.
const ROW_ICON_RECT := Rect2(24, 24, 102, 102)
const ROW_TEXT_X := 156.0
const ROW_RIGHT_PAD := 36.0


func _layout_rows() -> void:
	var old: Control = get_node_or_null("CardsContainer") as Control
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.theme = UIKit.theme()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", ROW_SEPARATION)
	rows.set_anchors_preset(Control.PRESET_CENTER)
	rows.offset_left = -ROW_SIZE.x * 0.5
	rows.offset_right = ROW_SIZE.x * 0.5
	rows.offset_top = ROW_TOP
	rows.offset_bottom = ROW_TOP + ROW_SIZE.y * cards.size() + ROW_SEPARATION * (cards.size() - 1)
	add_child(rows)
	if old:
		move_child(rows, old.get_index())
		old.visible = false
	for card: Button in cards:
		if not is_instance_valid(card):
			continue
		card.reparent(rows, false)
		card.custom_minimum_size = ROW_SIZE
		card.clip_contents = false ## seçim halesi satırın dışına taşar (bkz. TierCardFx.ensure_glow)
		card.set_meta("glow_texture", ROW_GLOW)
		card.set_meta("glow_card_size", ROW_SIZE)
		card.set_meta("glow_colors", ROW_GLOW_COLORS)
		var frame: TextureRect = card.get_node_or_null("Frame") as TextureRect
		if frame:
			frame.offset_right = ROW_SIZE.x
			frame.offset_bottom = ROW_SIZE.y
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
		scaled = TierSystem.health_card_for_tier(tier) ## 15/24/30/38 - bkz. TierSystem (player.gd ile tek kaynak)
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

## Kullanıcı isteği (2026-09-24): oyun içi TÜM arayüzler menülerle aynı bej/ahşap kite geçti - karıştır butonu da artık
## kitin ten (tan) butonu (eski assets/ui/reroll_button.png görseli yerine; eskiden %40 küçültülmüş 29 px'lik yüksekliği
## kit butonunun 9-slice payına (15+15) sığmıyordu, okunaklı 48 px'e büyütüldü - kartların altında, geri sayım panelinin
## üstünde aynı boşlukta).
func _apply_reroll_button_style() -> void:
	UIKit.style_button(reroll_button, "wood", false, UIKit.FS_BODY)
	reroll_button.offset_left = -198.0
	reroll_button.offset_right = 198.0
	reroll_button.offset_top = 258.0
	reroll_button.offset_bottom = 306.0


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
		title.add_theme_stylebox_override("normal", UIKit.panel_style("banner"))
		UIKit.style_label(title, UIKit.FS_TITLE, UIKit.C_TEXT, 0)
		title.remove_theme_color_override("font_shadow_color")
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		var w: float = MenuKit.font().get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FS_TITLE).x + 132.0
		title.offset_left = -roundf(w * 0.5)
		title.offset_right = roundf(w * 0.5)
		title.offset_top = 24.0
		title.offset_bottom = 96.0
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
		countdown_panel.offset_top = 318.0
		countdown_panel.offset_bottom = 392.0
	if waiting_label:
		waiting_label.add_theme_color_override("font_color", UIKit.C_TEXT)
	if countdown_label:
		countdown_label.add_theme_color_override("font_color", UIKit.C_GOLD)


func _refresh_reroll_button() -> void:
	var cost: int = _reroll_cost()
	reroll_button.text = "Yeniden Karıştır (%d altın)" % cost
	reroll_button.disabled = GameManager.gold < cost


func _on_reroll_pressed() -> void:
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
