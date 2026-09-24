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
const CARD_CATEGORY_FONT_SIZE := 32
const CARD_DESCRIPTION_FONT_SIZE := 24
const CARD_COUNT_FONT_SIZE := 16

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
	{"id": "max_health", "title": "Can", "desc": "+10", "cat": "Savunma", "color": CAT_DEFENSE},
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
	{"id": "crit_damage", "title": "Kritik Hasar", "desc": "+%16.5", "cat": "Saldırı", "color": CAT_ATTACK},
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


const ReadingUiWatcher := preload("res://scripts/reading_ui_watcher.gd")
## Kart seçim ekranı açıkken karakter okuma (read) pozuna geçer - bkz. ReadingUiWatcher.
func _enter_tree() -> void:
	add_to_group(ReadingUiWatcher.GROUP)


func _ready() -> void:
	UISound.connect_all_buttons(self)
	UISound.apply_wood_buttons(self) ## bkz. ui_sound.gd - tüm butonları ahşap stile çevirir (kart butonları "icon slot" gibi dikey orantılı oldukları için bu zaten atlıyor, bkz. o dosyadaki _looks_like_icon_slot)
	_apply_reroll_button_style()
	_apply_kit_style()
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


func _on_card_hover(card: Button, entered: bool) -> void:
	if card.disabled:
		return ## bekleme durumunda karartılmış kartın üstü hover'la aydınlanmasın
	var frame: TextureRect = card.get_node_or_null("Frame")
	if frame:
		frame.modulate = Color(1.12, 1.12, 1.12, 1.0) if entered else Color(1, 1, 1, 1)


func _on_card_press(card: Button, is_down: bool) -> void:
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
		var category_label: Label = content.get_node("Category")
		category_label.text = upgrade["cat"]
		category_label.modulate = Color(1, 1, 1, 1)
		category_label.add_theme_color_override("font_color", upgrade["color"])
		category_label.add_theme_font_size_override("font_size", CARD_CATEGORY_FONT_SIZE)

		content.get_node("Icon").setup(upgrade["id"], upgrade["color"])

		## Title etiketi eskiden hiç kullanılmıyordu (bkz. eski "Hide the
		## title" yorumu) - artık tier adını (Sıradan/Nadir/Epik/Efsanevi)
		## tier rengiyle göstermek için kullanılıyor.
		var title_label: Label = content.get_node("Title") as Label
		title_label.visible = true
		title_label.text = TierSystem.NAMES[tier - 1]
		title_label.add_theme_color_override("font_color", TierSystem.COLORS[tier - 1])

		_apply_card_tier_frame(card, tier)

		var desc_label: RichTextLabel = content.get_node("Desc") as RichTextLabel
		desc_label.text = _get_friendly_desc(upgrade, tier)
		desc_label.add_theme_font_size_override("normal_font_size", CARD_DESCRIPTION_FONT_SIZE)
		desc_label.add_theme_font_size_override("bold_font_size", CARD_DESCRIPTION_FONT_SIZE)
		desc_label.add_theme_font_size_override("italics_font_size", CARD_DESCRIPTION_FONT_SIZE)
		desc_label.add_theme_font_size_override("bold_italics_font_size", CARD_DESCRIPTION_FONT_SIZE)

		var count_label: Label = content.get_node("CountLabel") as Label
		count_label.add_theme_font_size_override("font_size", CARD_COUNT_FONT_SIZE)
		count_label.text = ("%dx alındı" % count) if count > 0 else ""


## Görünür çerçeve artık bir StyleBoxFlat rengi DEĞİL, tier'a özel çizilmiş
## bir doku (bkz. TierSystem.FRAME_TEXTURES) - "Frame" TextureRect'e atanıyor.
## Bir reroll önceki karttan kalma "seçili" parlaklığı/parıltısı miras
## almasın diye modulate/glow burada HER ZAMAN varsayılana sıfırlanıyor.
func _apply_card_tier_frame(card: Button, tier: int) -> void:
	var frame: TextureRect = card.get_node_or_null("Frame")
	if frame:
		frame.texture = TierSystem.FRAME_TEXTURES[tier - 1]
		frame.modulate = Color(1, 1, 1, 1)
	var glow: Control = card.get_node_or_null("SelectGlow")
	if glow:
		glow.visible = false
	card.modulate = Color(1, 1, 1, 1)


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
	var colored_val: String = "[color=%s]%s[/color]" % [UIKit.INK["value"], clean_val]
	if upgrade["id"] == "cooldown_reduction":
		return "%s %s azalır" % [colored_title, colored_val]
	else:
		return "%s %s artar" % [colored_title, colored_val]


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
		var count_label: Label = card.get_node_or_null("Content/CountLabel") as Label
		if count_label:
			count_label.add_theme_color_override("font_color", UIKit.C_TEXT_DIM)
		var desc: RichTextLabel = card.get_node_or_null("Content/Desc") as RichTextLabel
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
func _on_card_pressed(id: String, tier: int, _card: Button) -> void:
	_has_chosen = true
	## Ekranın kendisini serbest bırakmak main.gd'nin _on_upgrade_chosen'ına
	## bırakılıyor (o zaten _active_level_up_screen'i - yani bu sahneyi -
	## queue_free() ediyor) - burada AYRICA çağırmak zararsız ama gereksiz
	## tekrar olurdu.
	upgrade_chosen.emit(id, tier)
