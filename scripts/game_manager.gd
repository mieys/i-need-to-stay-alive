extends Node

const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")

## "Body block" sınırının (bkz. enemy.gd PLAYER_BODY_RADIUS/_body_radius ve
## player.gd'nin karşılık gelen engelleme kodu) her iki tarafta da AYNI
## mesafeyi kullanması gerektiği için burada tek bir yerden tanımlanıyor.
## Kullanıcı bildirimi: "daha dokunmadan dokunmuşum gibi itiliyor yaratıklar"
## - gövde yarıçapları toplamı görsel temastan daha erken tetikleniyordu, bu
## çarpanla (1.0'dan) küçültülüp gerçek temasa yaklaştırıldı. İkinci bir
## kullanıcı bildirimi ("hala biraz fazla büyük, kolayca çarpışıyorlar") ile
## 0.72'den biraz daha küçültüldü. ÜÇÜNCÜ tur (kullanıcı isteği: "body
## blockları ufalt yoksa karakterler yaratıkların arasında sıkışıp ölüyor...
## bu kadar büyük olmasın") ile 0.62'den 0.48'e düşürüldü - bkz. player.gd
## PLAYER_BODY_RADIUS (16->12) ile birlikte, ikisi toplamda kalabalık bir
## yaratık grubunda oyuncuyu daha az sıkıştırır.
const BODY_BLOCK_SCALE := 0.48

## Kullanıcı isteği: "can çalma, alan hasarı veren eşyalarda %33 geçerli
## olsun" - GLOBAL kapsamda (eşyalar + karakter pasifleri/yetenekleri +
## silahlar, hepsi) uygulanıyor. player.gd VE weapon.gd'deki TÜM can
## çalma/alan hasarı hesaplarının (on_damage_dealt, _apply_weapon_lifesteal,
## weapon.gd melee AoE splash, _buyucu_on_kill)
## çarptığı TEK ortak sabit - BODY_BLOCK_SCALE ile aynı sebepten burada:
## birden fazla dosyada aynı sayı elle kopyalanırsa biri güncellenirken
## diğeri unutulabilir.
const LIFESTEAL_EFFECTIVENESS := 0.33
const AOE_DAMAGE_EFFECTIVENESS := 0.33

var game_time: float = 0.0
var is_game_over: bool = false

## DÜZELTME (kullanıcı isteği: "3 dakikada bir açılan dükkan sadece level
## atlama ekranından sonra çıkmalı, oyun daha başlamadan öyle açılmalı") -
## eskiden burada "her 3 dakikada bir" saf zamanlayıcı vardı (mini_shop_due
## sinyali + mini_shop_timer/MINI_SHOP_INTERVAL); artık dükkan SADECE level
## atlama akışının bitişinde (bkz. main.gd _resume_gameplay_after_level_flow)
## ve oyun başlangıcındaki ilk silah/kalkan seçiminden hemen sonra (bkz.
## main.gd _start_initial_loadout_selection) tetikleniyor - saf zaman
## tabanlı tetikleyici tamamen kaldırıldı.

## Seçili karakterin kimliği (Characters.DEFS anahtarı) ve o karaktere
## atanmış yetenek kimliği. Yetenek kodu player.gd'de eski 1-9 kimlik
## aralığıyla çalışmaya devam ediyor; karakter -> yetenek eşlemesi
## Characters.DEFS'te ("skill" alanı) yapılır ve seçim ekranı ikisini
## birden ayarlar. Varsayılanlar Talon'a denk gelir (editörden doğrudan
## main.tscn çalıştırılırsa da tutarlı olsun diye).
## BUG DÜZELTMESİ (kullanıcı bildirimi: "Q'su hala yanlış, hala can basma
## skilini kullanıyor dash yerine") - kök neden: bu varsayılan (8) Talon'un
## ÇOK ESKİ bir yetenek id'siydi (Devleşme/Yer Sarsıntısı takasından ÖNCE);
## "Talon yeni skilleri" isteğiyle Talon'un ulti id'si 38'e taşındı ama bu
## varsayılan hiç güncellenmemişti. main.tscn'i karakter seçim ekranından
## GEÇMEDEN (editörden doğrudan) çalıştırınca selected_character hiçbir
## zaman character_select.gd'nin _on_start_pressed()'i tarafından
## ayarlanmıyor - eski/eşleşmeyen bu varsayılan (8) kalıyor, hiçbir "skill"
## case'ine denk gelmediği için _activate_skill()'in en alttaki varsayılanına
## (_skill_heal, Oakley/Melek'in Can Basma'sı) düşüyordu.
var selected_char_id: int = 1
var selected_character: int = 38

## Ruhani Yetenek (F tuşu, bkz. spiritual_skills.gd) - karakter seçim ekranında/lobide seçilir, oyun boyunca sabit.
## reset() bunu BİLEREK sıfırlamaz: seçim oyun başlamadan ÖNCE yapılır. Karakter seçim ekranı/lobi (spiritual_picker.gd)
## açılınca varsayılan (Para) otomatik seçili gelir, yani normal akışta kimse ruhani yeteneksiz başlamaz; boş "" değer
## seçim ekranından hiç geçilmediği (ör. editörden doğrudan main.tscn, testler) anlamına gelir -> ruhani yetenek yok.
var selected_spiritual: String = ""

var gold: int = 0
## Kullanıcı isteği: "altın toplayıcı ve madeni oyundan tamamen kaldır ve
## ekranın sağındaki arayüzlerini de sil" - eskiden burada mine_level/
## gold_collector_level ve ikisinin pasif altın üretimi duruyordu
## (MINE_GOLD_PER_TICK/GOLD_COLLECTOR_GOLD_PER_TICK, _mine_fill_duration/
## _gold_collector_fill_duration, _process'teki üretim bloğu,
## get_*_fill_progress, hud.gd'deki sağdaki üretim butonları ve
## shop_panel.gd'deki "mine"/"gold_collector" kayıtları) - HEPSİ kaldırıldı.
## Altın artık SADECE düşman düşürmesiyle (bkz. gold_drop.gd) ve seviye atlama
## ödülüyle (bkz. LEVEL_UP_GOLD_REWARD) kazanılıyor; pasif gelir YOK.
var spray_level: int = 0
## Eski tek "Sihirli Kalkan" (shield_level) kaldırıldı - artık 4 bağımsız
## kalkan TÜRÜ var (bkz. player.gd SHIELD_TYPES). Kullanıcı isteğiyle
## ("sadece 1 kalkan alınabilmeli") aynı anda EN FAZLA BİRİNİN seviyesi
## sıfırdan büyük olabilir - shop_panel.gd bunu satın alma sırasında
## zorluyor (bkz. _on_buy_upgrade, önce mevcut türü satmadan başkası
## alınamaz). "Aktif" tür artık ayrı bir seçim değil, otomatik olarak
## seviyesi >0 olan tür (bkz. player.gd _owned_shield_type_key) - bu
## yüzden eskiden burada olan "active_shield_type" seçici değişkeni
## tamamen kaldırıldı, gereksizdi.
## DÜZELTME (kullanıcı isteği: "bundan sonra kimsenin başlangıç kalkanı
## yok") - bir önceki "herkes Standart Kalkan'la başlasın" kararı geri
## alındı. Artık HİÇBİR kalkan türü sahiplenilmemiş (0) başlıyor, oyuncu
## main.gd'nin gösterdiği kalkan seçim ekranından (bkz.
## weapon_select_screen.gd) seçtiği türle 1. seviyeye ulaşıyor (bkz.
## reset()'teki AYNI değişiklik).
var shield_standart_level: int = 0
var shield_enerji_level: int = 0
var shield_kale_level: int = 0
var shield_savas_level: int = 0
## Kullanıcı isteği: "Dükkan her level atladığında açılıyor sadece 5 dakika
## bekleme süresi dolunca level atladıktan sonra çıkmalı. Her seferinde 5
## dakika bekleme süresine girmeli." - periyodik dükkan artık HER level
## atlamasında değil, SADECE bu bekleme süresi dolduğunda bir level
## atlamasının SONUNDA açılıyor (bkz. main.gd _show_level_up_screen/
## _mini_shop_cooldown_remaining ile AYNI _process bloğunda azalıyor, yani oyun
## duraklatılınca (dükkan/level-up/sandık ekranları açıkken) SAYMIYOR - sadece
## gerçek oynanış süresi sayılır. (Eskiden aynı blokta maden/toplayıcı
## sayaçları da vardı, kullanıcı isteğiyle kaldırıldılar.)
## Kullanıcı isteği (bu tur): "dükkan 3 dakika bekleme süresine sahip olacak" -
## 300.0 -> 180.0. Kural aynı: dükkan SADECE bu süre dolduğunda, bir level
## atlama akışının SONUNDA (oyun devam etmeden önce) açılır ve açıldığı an
## süre sıfırdan başlar. Çok oyunculuda bu karar HOST tarafından verilip tüm
## peer'lere yayınlanır (bkz. network_manager.gd "MİNİ DÜKKAN KARARI" bloğu).
const MINI_SHOP_COOLDOWN := 180.0 ## 3 dakika (eskiden 300.0 = 5 dakika)
var _mini_shop_cooldown_remaining: float = 0.0

## Kullanıcı isteği: "level atlama aralarında dükkanın çıkmasını kaldır.
## Dükkan asla açılmayacak sonraki bir değişikliğe kadar." - dükkanın HER
## açılma yolu (periyodik mola VE hud.gd'deki altın göstergesine manuel
## tıklama) tek bu bayrağa bağlı; geri açmak için sadece bunu true'ya
## çevirmek yeterli. bkz. is_mini_shop_cooldown_ready() (periyodik akışın TEK
## karar kaynağı - main.gd/network_manager.gd'deki HER çağrı buradan geçiyor)
## ve hud.gd open_shop_panel() (manuel altın göstergesi tıklaması).
const SHOP_ENABLED := false

func is_mini_shop_cooldown_ready() -> bool:
	if not SHOP_ENABLED:
		return false
	return _mini_shop_cooldown_remaining <= 0.0


func start_mini_shop_cooldown() -> void:
	_mini_shop_cooldown_remaining = MINI_SHOP_COOLDOWN

## Oyuncunun sahip olduğu TÜM silahlar burada tutulur - artık otomatik bir
## başlangıç silahı yok (bkz. main.gd weapon_select_screen.gd akışı), ilk
## kopya da oyuncunun seçtiği silah kartıyla buraya eklenir.
## Hiçbir karakterin ayrı, ücretsiz bir "ana silahı" YOK - seçilen silah da
## diğer tüm kopyalarla birebir aynı muamele görür:
## satılabilir, yükseltilebilir, "Geliştirmeler" sekmesinde normal bir satır
## olarak görünür (bkz. shop_panel.gd _on_upgrade_weapon/_on_sell_weapon,
## player.gd set_owned_weapon_level). En fazla MAX_OWNED_WEAPONS (bkz.
## player.gd) kadar, türü karışık olabilir. Her kopyanın KENDİNE ÖZEL bir
## seviyesi var (paylaşılmaz). Her eleman: {"key": String, "level": int,
## "spent": int (o kopyaya şu ana kadar harcanan toplam altın - satışta %70
## iade hesabı için)}.
var owned_weapons: Array = []

## Oyuncunun sahip olduğu TÜM eşyalar (bkz. scripts/items.gd Items.DEFS) -
## silahların aksine seviyelenmezler, sadece kopya sayısı önemli (bkz.
## player.gd _apply_item_stats - N kopya = statlar N ile çarpılır). Her
## eleman: {"key": String, "spent": int (satışta %70 iade için)}. En fazla
## player.gd get_max_item_slots() kadar (karakter başına seviye başı +1).
var owned_items: Array = []

## #48 DÜZELTME (kullanıcı isteği: "Level kartı reroll'u altınla olsun,
## level başına +1 altın"): eskiden sabit sayıda (2 tane) ücretsiz reroll
## hakkı vardı, artık reroll SINIRSIZ ama her kullanımda altın harcıyor
## (bkz. level_up_screen.gd LEVEL_UP_REROLL_COST) - bu yüzden ücretsiz hak
## sayacına artık gerek yok.

## Kullanıcı isteği: sandıklar artık dokunulduğu anda açılmıyor - toplanan
## her sandığın kademesi burada BİRİKTİRİLİYOR (bkz. chest_drop.gd
## _open_chest_for / NetworkManager.open_chest_for_peer - ikisi de artık
## menü açmak yerine buraya ekliyor) ve HUD'da avatarın yanında bir
## simge+sayaç olarak gösteriliyor (bkz. hud.gd _update_chest_indicator).
## Takım seviyesi atlayınca main.gd bunları SIRAYLA otomatik açar (bkz.
## main.gd _try_open_next_pending_chest). Bu liste TAMAMEN yerel/kişiseldir
## (her oyuncunun kendi GameManager'ında) - ağ senkronu GEREKMEZ, çünkü bir
## sandığı hangi oyuncu topladıysa o sandık zaten SADECE o oyuncunun kendi
## GameManager'ına ekleniyor (bkz. yukarıdaki dosyalardaki ilgili yorumlar).
var pending_chest_tiers: Array = []


func add_pending_chest(tier: int) -> void:
	pending_chest_tiers.append(tier)


func pop_pending_chest() -> int:
	if pending_chest_tiers.is_empty():
		return -1
	return pending_chest_tiers.pop_front()


func has_pending_chests() -> bool:
	return not pending_chest_tiers.is_empty()

## Shield modes bought from the shop's "Modlar" category: leveled items
## (0 = not owned), 10 levels, expensive to level up - higher levels make the
## mod's own bonus/penalty stronger (see Player._apply_shield_mode). Only one
## can be the *active* mode at a time - "" means none.
var shield_mod_resilience_level: int = 0
var shield_mod_thorny_level: int = 0
var shield_mod_turtle_level: int = 0
var shield_mod_aggressive_level: int = 0
var shield_mod_lightning_level: int = 0 ## Şimşek Hız Modu
var shield_mod_piercing_level: int = 0 ## Delicilik Modu
var shield_mod_tank_level: int = 0 ## Tank Modu
var active_shield_mode: String = ""


## Kullanıcı isteği: "ayarlara tuş ataması özelliği ekle, isteyen istediği
## tuşu istediği şeyle değiştirebilsin" - bkz. keybind_menu.gd (yeni ayrı
## popup - mevcut ayarlar paneli sığmadığı için) ve set_keybind_override/
## get_keybind_keycode altındaki notlar. ui_sound.gd'nin ses/görüntü
## ayarlarıyla AYNI ConfigFile + user:// deseni.
const KEYBIND_SETTINGS_PATH := "user://keybind_settings.cfg"

## Tuş atama menüsünde gösterilecek, rebind edilebilir action listesi -
## _setup_input_actions()'daki _bind() çağrılarıyla eşleşir (F9 debug paneli
## gibi oyuncuya yönelik olmayanlar bilerek dışarıda bırakıldı).
const REBINDABLE_ACTIONS := [
	{"action": "move_up", "label": "Yukarı Hareket"},
	{"action": "move_down", "label": "Aşağı Hareket"},
	{"action": "move_left", "label": "Sola Hareket"},
	{"action": "move_right", "label": "Sağa Hareket"},
	{"action": "skill", "label": "Ulti (Ana Yetenek)"},
	{"action": "skill2", "label": "Temel Yetenek"},
	{"action": "skill3", "label": "3. Yetenek"},
	{"action": "skill4", "label": "Ruhani Yetenek"},
	{"action": "interact", "label": "Etkileşim / Eve Gir"},
	{"action": "shield_mode_slot_1", "label": "Kalkan Modu 1"},
	{"action": "shield_mode_slot_2", "label": "Kalkan Modu 2"},
	{"action": "shield_mode_slot_3", "label": "Kalkan Modu 3"},
	{"action": "shield_mode_slot_4", "label": "Kalkan Modu 4"},
	{"action": "shield_mode_slot_5", "label": "Kalkan Modu 5"},
]

## action_name -> Key (int) - diskten okunan yerel tuş override'ları,
## _setup_input_actions() çalışmadan ÖNCE _load_keybind_overrides() ile
## doldurulur; _bind() varsa bunu, yoksa kendi varsayılanını kullanır.
var _keybind_overrides: Dictionary = {}

## DÜZELTME (kullanıcı isteği: "gamepad desteği ekle") - klavye override'ları
## ile AYNI mantık ama TAMAMEN AYRI depolama (action_name -> Dictionary
## descriptor, bkz. _make_joypad_event). _bind_joypad() varsa bunu, yoksa
## kendi varsayılanını kullanır. Klavye ve gamepad override'larının birbirini
## SİLMEMESİ (bkz. set_keybind_override/set_keybind_joypad_override'daki
## kök neden notu) için bilerek iki ayrı Dictionary.
var _joypad_overrides: Dictionary = {}

enum JoypadKind { BUTTON, AXIS }


func _ready() -> void:
	_load_keybind_overrides()
	_setup_input_actions()


func _load_keybind_overrides() -> void:
	var config := ConfigFile.new()
	if config.load(KEYBIND_SETTINGS_PATH) != OK:
		return
	if config.has_section("keybinds"):
		for action_name in config.get_section_keys("keybinds"):
			_keybind_overrides[action_name] = int(config.get_value("keybinds", action_name))
	## DÜZELTME (kullanıcı isteği: "gamepad desteği ekle") - AYNI dosyada
	## ayrı bir bölüm; ConfigFile Dictionary değerlerini native serileştirdiği
	## için descriptor'lar (bkz. _make_joypad_event) doğrudan yazılıp okunabiliyor.
	if config.has_section("keybinds_joypad"):
		for action_name in config.get_section_keys("keybinds_joypad"):
			_joypad_overrides[action_name] = config.get_value("keybinds_joypad", action_name)


## Bir action'ın event listesinden SADECE istenen türdeki (klavye YA DA
## gamepad) event'leri siler, diğer türü DOKUNMADAN bırakır.
## DÜZELTME (kullanıcı bildirimi/kök neden - eskiden set_keybind_override()
## InputMap.action_erase_events() ile TÜM event'leri (klavye + varsa gamepad)
## siliyordu; bir action'a gamepad ataması eklendikten sonra o action'ın
## klavye tuşu değiştirilirse gamepad ataması da sessizce kaybolurdu, ve
## tam tersi) - artık her iki set_keybind_*_override() SADECE kendi türünü
## siliyor.
func _erase_events_of_kind(action_name: String, want_key: bool) -> void:
	for event in InputMap.action_get_events(action_name):
		var is_key: bool = event is InputEventKey
		var is_joy: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
		if (want_key and is_key) or (not want_key and is_joy):
			InputMap.action_erase_event(action_name, event)


## Aynı KEYBIND_SETTINGS_PATH dosyasına ekleyerek yazar (diğer action'ların/
## diğer bölümün override'larını korumak için önce yükler) - ui_sound.gd
## set_master_volume_percent ile AYNI ConfigFile deseni.
func _save_override(section: String, action_name: String, value) -> void:
	var config := ConfigFile.new()
	config.load(KEYBIND_SETTINGS_PATH)
	config.set_value(section, action_name, value)
	config.save(KEYBIND_SETTINGS_PATH)


## keybind_menu.gd'den çağrılır - bir action'ın KLAVYE tuşunu anında
## değiştirir VE diske kaydeder. Gamepad ataması varsa (bkz. yukarıdaki kök
## neden notu) artık DOKUNULMUYOR.
func set_keybind_override(action_name: String, keycode: int) -> void:
	_keybind_overrides[action_name] = keycode
	_erase_events_of_kind(action_name, true)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action_name, ev)
	_save_override("keybinds", action_name, keycode)


## keybind_menu.gd'den çağrılır - bir action'ın GAMEPAD atamasını anında
## değiştirir VE diske kaydeder. `descriptor`: {"kind":JoypadKind.BUTTON,
## "button":JoyButton} ya da {"kind":JoypadKind.AXIS,"axis":JoyAxis,
## "sign":1.0/-1.0}. Klavye atamasına DOKUNMUYOR.
func set_keybind_joypad_override(action_name: String, descriptor: Dictionary) -> void:
	_joypad_overrides[action_name] = descriptor
	_erase_events_of_kind(action_name, false)
	var ev: InputEvent = _make_joypad_event(descriptor)
	if ev:
		InputMap.action_add_event(action_name, ev)
	_save_override("keybinds_joypad", action_name, descriptor)


## Bir action'a şu an atanmış fiziksel tuş kodunu döndürür (yoksa KEY_NONE).
func get_keybind_keycode(action_name: String) -> int:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			return event.physical_keycode
	return KEY_NONE


## Bir action'a şu an atanmış gamepad tanımlayıcısını döndürür (yoksa boş
## Dictionary) - keybind_menu.gd'nin gamepad sütununu doldurmak için.
func get_keybind_joypad_descriptor(action_name: String) -> Dictionary:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			return {"kind": JoypadKind.BUTTON, "button": event.button_index}
		if event is InputEventJoypadMotion:
			return {"kind": JoypadKind.AXIS, "axis": event.axis, "sign": signf(event.axis_value)}
	return {}


## descriptor Dictionary'sinden gerçek bir InputEvent üretir (set_keybind_
## joypad_override/_bind_joypad ORTAK fabrikası - iki yer asla sapamaz).
## device = -1: HANGİ kumandanın kaçıncı slotta takılı olduğuna bakmaz,
## bağlı herhangi bir kumandadan gelen basışı kabul eder (tek oyuncu bir
## makinede tek kumanda kullandığı için cihaz numarası ayırt etmeye gerek yok).
func _make_joypad_event(d: Dictionary) -> InputEvent:
	match int(d.get("kind", -1)):
		JoypadKind.BUTTON:
			var e := InputEventJoypadButton.new()
			e.button_index = int(d.get("button", -1)) as JoyButton
			e.device = -1
			return e
		JoypadKind.AXIS:
			var e2 := InputEventJoypadMotion.new()
			e2.axis = int(d.get("axis", -1)) as JoyAxis
			e2.axis_value = float(d.get("sign", 1.0))
			e2.device = -1
			return e2
	return null


func _setup_input_actions() -> void:
	_bind("move_left", KEY_A)
	_bind_joypad("move_left", [
		{"kind": JoypadKind.AXIS, "axis": JOY_AXIS_LEFT_X, "sign": -1.0},
		{"kind": JoypadKind.BUTTON, "button": JOY_BUTTON_DPAD_LEFT},
	])
	_bind("move_right", KEY_D)
	_bind_joypad("move_right", [
		{"kind": JoypadKind.AXIS, "axis": JOY_AXIS_LEFT_X, "sign": 1.0},
		{"kind": JoypadKind.BUTTON, "button": JOY_BUTTON_DPAD_RIGHT},
	])
	_bind("move_up", KEY_W)
	_bind_joypad("move_up", [
		{"kind": JoypadKind.AXIS, "axis": JOY_AXIS_LEFT_Y, "sign": -1.0},
		{"kind": JoypadKind.BUTTON, "button": JOY_BUTTON_DPAD_UP},
	])
	_bind("move_down", KEY_S)
	_bind_joypad("move_down", [
		{"kind": JoypadKind.AXIS, "axis": JOY_AXIS_LEFT_Y, "sign": 1.0},
		{"kind": JoypadKind.BUTTON, "button": JOY_BUTTON_DPAD_DOWN},
	])
	## Tüm karakterlerde: TEMEL yetenek E, ULTİ (ana "skill" alanı) Q.
	## "skill2" alanı olmayan karakterlerde E tuşuna basmanın hiçbir etkisi
	## yok (bkz. player.gd get_skill2_id()/_activate_skill2()).
	_bind("skill", KEY_Q)
	## DÜZELTME (kullanıcı isteği: "gamepad desteği ekle... yetenek
	## tuşlarını da buna göre ayarla") - A/B zaten motorun ui_accept/
	## ui_cancel varsayılanı (dokunulmuyor), bu yüzden 3 yetenek X/Y/RB'ye,
	## interact LB'ye dağıtıldı - hepsi kolayca yeniden atanabilir.
	_bind_joypad("skill", [{"kind": JoypadKind.BUTTON, "button": JOY_BUTTON_Y}])
	_bind("skill2", KEY_E)
	_bind_joypad("skill2", [{"kind": JoypadKind.BUTTON, "button": JOY_BUTTON_X}])
	## Üçüncü aktif yetenek slotu (bkz. player.gd SKILL3_TIMING notu -
	## kullanıcı isteği: Shaman'ın 3 BAĞIMSIZ totem yeteneği var). "skill3"
	## alanı olmayan karakterlerde R tuşuna basmanın hiçbir etkisi yok.
	_bind("skill3", KEY_R)
	_bind_joypad("skill3", [{"kind": JoypadKind.BUTTON, "button": JOY_BUTTON_RIGHT_SHOULDER}])
	## Ev'e girip çıkma etkileşimi (bkz. scripts/house_interior.gd) -
	## kullanıcı isteği: "yaklaşınca F'ye basarak içeri girilsin".
	## Kullanıcı isteği (2026-09-21): "dükkan açma gibi etkileşim tuşu artık space oluyor çünkü yeni skiller geldi" -
	## F artık Ruhani Yetenek (skill4, bkz. spiritual_skills.gd). Gamepad: etkileşim LB'de kaldı (alışkanlık bozulmasın),
	## ruhani yetenek sağ analog çubuğa basmaya (R3) atandı - A/B motorun ui_accept/ui_cancel'ı olduğu için boş kalan düğme.
	_bind("interact", KEY_SPACE)
	_bind_joypad("interact", [{"kind": JoypadKind.BUTTON, "button": JOY_BUTTON_LEFT_SHOULDER}])
	_bind("skill4", KEY_F)
	_bind_joypad("skill4", [{"kind": JoypadKind.BUTTON, "button": JOY_BUTTON_RIGHT_STICK}])
	## Test/geliştirme paneli: saldırı efektlerinin rotasyon/boyutunu oyun
	## içinden ayarlamak için (bkz. debug_tuning_panel.gd). Dev-only - gamepad
	## varsayılanı bilerek yok.
	_bind("debug_tuning", KEY_F9)
	## Alt bardaki kalkan modu seçici kısayolları (bkz. hud.gd
	## _refresh_shield_mode_slots/_unhandled_input) - kullanıcı isteğiyle
	## 1-2-3-4-5 tuşlarıyla o an görünen kalkan modu slotu seçilebiliyor.
	## Bu özellik artık KULLANILMIYOR (bkz. hud.gd shield_mode_slots notu -
	## bar kalıcı gizli) - gamepad varsayılanı bilerek eklenmedi.
	_bind("shield_mode_slot_1", KEY_1)
	_bind("shield_mode_slot_2", KEY_2)
	_bind("shield_mode_slot_3", KEY_3)
	_bind("shield_mode_slot_4", KEY_4)
	_bind("shield_mode_slot_5", KEY_5)
	## Chat (kullanıcı isteği: "enter tuşuna basarak mesaj yazabiliriz") -
	## bkz. hud.gd _unhandled_input - kutu kapalıyken Enter'a basınca açılır,
	## açıkken (LineEdit odaktayken) Enter'a basmak LineEdit'in KENDİ
	## text_submitted sinyalini tetikler (bu action'ı hiç TEKRAR tetiklemez,
	## çünkü odaklı bir Control tuşu önce kendi _gui_input'unda işler).
	## Serbest metin yazımı gamepad'de karşılığı olmadığı için (kullanıcı
	## kararı: sanal klavye YOK) gamepad varsayılanı bilerek eklenmedi.
	_bind("chat", KEY_ENTER)


func _bind(action_name: String, keycode: Key) -> void:
	## Kayıtlı bir kullanıcı override'ı varsa (bkz. _load_keybind_overrides)
	## varsayılan yerine o kullanılır.
	var effective_keycode: int = int(_keybind_overrides.get(action_name, keycode))
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == effective_keycode:
			return
	var ev := InputEventKey.new()
	ev.physical_keycode = effective_keycode
	InputMap.action_add_event(action_name, ev)


## _bind()'ın gamepad karşılığı - `defaults`, bu action için gamepad
## atanmamışsa kullanılacak descriptor listesi (bkz. _make_joypad_event) -
## ör. hareket action'ları hem analog çubuk HEM D-pad'i (2 event) alıyor,
## yetenekler tek bir buton (1 event) alıyor. Kayıtlı bir kullanıcı
## override'ı varsa (bkz. _joypad_overrides) TÜM varsayılanların yerine
## SADECE o kullanılır (_bind()'taki "override varsa öncelikli" mantığıyla
## birebir aynı).
func _bind_joypad(action_name: String, defaults: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var effective: Array = [_joypad_overrides[action_name]] if _joypad_overrides.has(action_name) else defaults
	for d in effective:
		var ev: InputEvent = _make_joypad_event(d)
		if ev == null:
			continue
		var already_present: bool = false
		for existing in InputMap.action_get_events(action_name):
			if existing is InputEventJoypadButton and ev is InputEventJoypadButton \
					and existing.button_index == ev.button_index:
				already_present = true
				break
			if existing is InputEventJoypadMotion and ev is InputEventJoypadMotion \
					and existing.axis == ev.axis and is_equal_approx(existing.axis_value, ev.axis_value):
				already_present = true
				break
		if not already_present:
			InputMap.action_add_event(action_name, ev)


## Bir action'ın ekranda gösterilecek tuş adı (ipucu yazıları için: "Eve girmek için BOŞLUK tuşuna bas").
func get_action_key_label(action_name: String) -> String:
	var code: int = get_keybind_keycode(action_name)
	if code == KEY_NONE:
		return "?"
	if code == KEY_SPACE:
		return "BOŞLUK"
	return OS.get_keycode_string(code as Key).to_upper()


## Ruhani Yetenek "Para" pasifi: dükkandaki altın bedelleri %10 azalır (kullanıcı isteği). Tüm dükkan fiyatları
## (shop_panel.gd _upgrade_cost/_copy_cost/_item_cost, merchant_shop_screen.gd _entry_cost) son adımda buradan geçer.
func apply_shop_discount(cost: int) -> int:
	if selected_spiritual != SpiritualSkillsScript.PARA or cost <= 1:
		return cost
	return maxi(1, int(round(float(cost) * (1.0 - SpiritualSkillsScript.PARA_SHOP_DISCOUNT))))


## ---------- Seyyar Satıcı güvenli bölgesi ----------
## Kullanıcı isteği: "Dükkanın olduğu alanda ... 3 kat daha geniş[tir] ...
## Dışardaki yaratıklar oyuncular bariyerin içindeyken geçirilen zamanla
## güçlenmez veya yeni yaratıklar spawn olmaz." - traveling_merchant.gd
## satıcı belirdiğinde/ayrıldığında bu üç alanı günceller, enemy.gd/
## enemy_spawner.gd/player.gd hepsi BURADAN (tek kaynak) okuyor.
var merchant_zone_active: bool = false
var merchant_zone_pos: Vector2 = Vector2.ZERO
## Şovalye Adam'ın Koruma Baloncuğu'nun (bkz. player.gd PALADIN_ULTI_ZONE_
## RADIUS = 126.0) eskiden TAM 3 katıydı (kullanıcı isteği: "3 kat daha
## geniştir"). DÜZELTME (kullanıcı isteği: "seyyar satıcının kalkan
## bariyerini %30 küçült") - görsel bariyer (bkz. traveling_merchant.gd
## _create_protection_bubble, bubble.radius = MERCHANT_ZONE_RADIUS) bu
## değere DOĞRUDAN bağlı, o yüzden gerçek güvenli bölge de birlikte
## küçültüldü - aksi halde görünen bariyer ile gerçekte güvenli olan alan
## birbirini tutmazdı. 378.0 * 0.7 = 264.6.
const MERCHANT_ZONE_RADIUS := 264.6

func is_position_in_merchant_zone(pos: Vector2) -> bool:
	return merchant_zone_active and merchant_zone_pos.distance_to(pos) <= MERCHANT_ZONE_RADIUS


## enemy_spawner.gd'nin _any_living_player_outdoors()'unun TERSİ: sadece
## bölge aktifse VE canlı HER oyuncu (yerel + tüm uzaklar) şu an bölge
## içindeyse true döner. Tek bir oyuncu bile dışarıda kalırsa false -
## takım, biri dışarıda dövüşürken diğeri bölgede "kamp yaparak" zorluğu/
## spawn'ı donduramaz (kullanıcı isteği: "tabii eğer herkes bariyerin
## içindeyse").
func all_living_players_in_merchant_zone() -> bool:
	if not merchant_zone_active:
		return false
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var found_any: bool = false
	var local_p: Node = tree.get_first_node_in_group("player")
	if local_p and is_instance_valid(local_p) and local_p.get("is_dead") != true:
		found_any = true
		if not (local_p.has_method("is_in_merchant_zone_now") and local_p.is_in_merchant_zone_now()):
			return false
	if NetworkManager.is_multiplayer_active:
		for rp: Node in tree.get_nodes_in_group("remote_players"):
			if not is_instance_valid(rp) or rp.get("is_dead") == true:
				continue
			found_any = true
			var rp_in_zone: bool = rp.get("is_in_merchant_zone") if "is_in_merchant_zone" in rp else false
			if not rp_in_zone:
				return false
	return found_any


## NOT: Eskiden burada testi amaçlı bir "saniyede 1 altın" taban gelir
## (gold_regen_timer/GOLD_REGEN_INTERVAL) VE satın alınabilen Maden/Altın
## Toplayıcı yatırımlarının pasif üretimi vardı - ikisi de kullanıcı
## istekleriyle KALDIRILDI (bkz. yukarıdaki "altın toplayıcı ve madeni
## oyundan tamamen kaldır" notu). Artık altın SADECE savaşarak (düşman
## düşürmesi, bkz. gold_drop.gd) ve seviye atlama ödülüyle kazanılıyor -
## pasif, bedava bir gelir YOK.
func _process(delta: float) -> void:
	## Kullanıcı isteği: "yaratıklar ... geçirilen zamanla güçlenmez" - zorluk
	## SADECE game_time'a bağlı olduğu için (bkz. enemy_spawner.gd
	## _current_tier/_current_interval) herkes seyyar satıcının güvenli
	## bölgesindeyken bu saat tamamen duruyor - dışarıdaki hâlâ hayattaki
	## yaratıklar donduğu andaki güçlerinde kalır, yeni bir Kademe'ye
	## geçilmez. is_game_over ile AYNI basit koruma deseni.
	if not is_game_over:
		if not all_living_players_in_merchant_zone():
			game_time += delta
		if _mini_shop_cooldown_remaining > 0.0:
			_mini_shop_cooldown_remaining -= delta
	## Kullanıcı isteği: "Multiplayerda her oyuncu 3 yeniden canlanma hakkına
	## sahip olmalı ve 1 yeniden canlanma hakkı kaldığında 3 dakikada bir bir
	## yeniden canlanma hakkı kazanmalı" - max_revives zaten 3 (bkz. yukarısı),
	## eksik olan sadece bu zamanlayıcıydı. Host-yetkili (bkz.
	## network_manager.gd _consume_revive_authoritative ile AYNI mimari),
	## sadece multiplayer'da çalışır.
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		_process_revive_regen(delta)


var max_revives: int = 3
## Tek oyunculu (ve multiplayer'da eski/yedek yol) için - tek oyuncu olduğu
## için zaten "kişisel" sayılır, dokunulmadı.
var revives_remaining: int = 3

## DÜZELTME (kullanıcı isteği: "multiplayerda canların takım canı değil
## kişisel olmasını istiyorum herkesin 3 canı olacak") - eskiden yukarıdaki
## TEK revives_remaining TÜM takımın PAYLAŞILAN canlanma hakkıydı (biri
## harcayınca herkesin hakkı azalıyordu). Artık multiplayer'da her oyuncunun
## KENDİ bağımsız hakkı bu sözlükte (peer_id -> kalan hak) tutuluyor - bkz.
## network_manager.gd _consume_revive_authoritative/sync_revive_consumed.
## Henüz hiç harcanmamış bir peer_id burada YOK demektir, o yüzden
## get_peer_revives() görmediği bir id için max_revives döndürür (yeni
## katılan/henüz hiç ölmemiş oyuncu için ayrıca bir "başlangıç" ataması
## gerekmiyor).
var peer_revives: Dictionary = {}

func get_peer_revives(peer_id: int) -> int:
	return int(peer_revives.get(peer_id, max_revives))

signal revives_updated(remaining: int)

## Kullanıcı isteği: "1 yeniden canlanma hakkı kaldığında 3 dakikada bir bir
## yeniden canlanma hakkı kazanmalı" - SADECE tam 1 hak kalmışken sayaç
## işler (0'a düşen kalıcı sayılır, hiç yenilenmez; 2/3 zaten "tam" sayılır,
## saymaya gerek yok). peer_id -> o an biriken saniye.
const REVIVE_REGEN_INTERVAL := 180.0 ## 3 dakika
var _revive_regen_timers: Dictionary = {}

func _process_revive_regen(delta: float) -> void:
	for peer_id in NetworkManager.lobby_players.keys():
		var remaining: int = get_peer_revives(peer_id)
		if remaining != 1:
			## Hak 0'a düştü (kalıcı) ya da zaten tam (2/3) - sayaç anlamsız,
			## bir dahaki "tam olarak 1" anına temiz başlasın diye sıfırlanır.
			_revive_regen_timers.erase(peer_id)
			continue
		var t: float = float(_revive_regen_timers.get(peer_id, 0.0)) + delta
		if t >= REVIVE_REGEN_INTERVAL:
			t -= REVIVE_REGEN_INTERVAL
			var new_remaining: int = min(remaining + 1, max_revives)
			peer_revives[peer_id] = new_remaining
			NetworkManager.sync_revive_consumed.rpc(peer_id, new_remaining)
		_revive_regen_timers[peer_id] = t


## Ortak Takım Seviyesi ve EXP Havuzu (Multiplayer & Tek Oyunculu)
var team_level: int = 1
var team_xp: float = 0.0
## Kullanıcı isteği (İKİNCİ tur - ilk turdaki "karekök" düzeltmesi yönü TERS
## çevirmişti, bkz. aşağıdaki tarihçe): "Erken levellerde hafif kolay, sonraki
## levellerde hafif zorlaşsın - şu anki hali tam tersi olmuş. İlerleyen
## levellerde aşırı zor olmasın, genel olarak da aşırı kolay olmasın."
##
## TARİHÇE:
## 1) ORİJİNAL EĞRİ (üstel, XP_GROWTH_FACTOR=1.192 çarpımı): L1'de 15 XP
##    (neredeyse anında level atlanıyordu), L10'da 76, L20'de 487, L30'da
##    1267 XP. Erken oyun aşırı kolay, geç oyun aşırı zordu.
## 2) İLK DÜZELTME (karekök eğrisi, BASE 50 + 25*sqrt(level-1)): bunun
##    TERSİNE düştü - L1'de 50 XP ile başlıyordu (eskisinden daha zor
##    başlangıç) ama artış hızı seviye başına küçüldüğü için L20'den sonra
##    neredeyse düzleşiyordu (L20: 159, L30: 185, L50: 225 - aşırı kolay
##    geç oyun). Yani "erken kolay, geç hafif zor" isteğinin TAM TERSİ.
##
## 3) BU EĞRİ (doğru yön): gereksinim düşük bir tabanla başlar (erken
##    levellerde hızlı atlama = kolay), sonra HER seviyede bir öncekinden
##    biraz daha FAZLA XP istenir (artış miktarı seviye başına büyür = hafif
##    zorlaşma) - ama bu artış miktarının kendisi bir TAVANDA (MAX_XP_
##    INCREMENT) sınırlanır, yani belirli bir noktadan sonra artış SABİT
##    kalır ve asla üstel şekilde patlamaz ("aşırı zor" olmaz).
##
## Örnek gereksinimler (L1'den itibaren): 30, 36, 44, 54, 66, 80, 96, 114,
## 134, 156 (L10), 204 (L12, tavana ulaşıldı), 276 (L15), 396 (L20),
## 636 (L30), 1116 (L50) - eskisinden (sqrt eğrisi) erken levellerde daha
## kolay, geç levellerde belirgin şekilde daha zor, ama üstel eğrideki gibi
## hiçbir noktada patlamıyor (seviye başına artış hiçbir zaman MAX_XP_
## INCREMENT'i aşmıyor).
## DÜZELTME (kullanıcı isteği: "level atlamak hala çok kolay, şuanki halinin
## %60'ı kadar kolay olsun") - eğrinin 4 sabiti de (BASE/MIN/GROWTH/MAX)
## AYNI ×(1/0.6)=×5/3 çarpanıyla büyütüldü. _xp_needed_for_level() bu 4
## sabitin SADECE doğrusal bir bileşimi olduğu için (başka hiçbir üstel/
## sabit terim yok) bu, eğrinin ŞEKLİNİ (kaç seviyede tavana ulaşılacağı,
## RAMP_STEPS=10) KORUYUP çıktının HER seviyede aynı oranda (×5/3) daha
## fazla XP istemesini sağlıyor - "erken kolay, geç hafif zor" karakteri
## aynen kalıyor, sadece tamamı ~%67 daha zorlaştı.
## DÜZELTME (kullanıcı isteği: "level atlamayı genel olarak %50 zorlaştır") -
## bkz. hemen üstteki DÜZELTME notuyla AYNI yöntem: eğrinin 4 sabiti de
## (BASE/MIN/GROWTH/MAX) AYNI ×1.5 çarpanıyla büyütüldü - şekil (RAMP_STEPS,
## kaç seviyede tavana ulaşılacağı) korunuyor, sadece her seviye %50 daha
## fazla XP istiyor.
const BASE_XP_NEEDED := 75.0
## Seviye 1'den 2'ye geçiş için gereken ilk artış - düşük tutulur ki erken
## oyun hızlı ve kolay hissettirsin.
const MIN_XP_INCREMENT := 15.0
## Her sonraki seviye atlayışında bir önceki artışa eklenen miktar - eğrinin
## "hafifçe zorlaşan" kısmı. Büyütmek zorlaşmayı hızlandırır.
const XP_INCREMENT_GROWTH := 5.0
## Seviye başına artışın asla aşamayacağı tavan - eğrinin "aşırı zor
## olmasın" kısmı. Bu tavana ulaşıldıktan sonra her seviye SABİT bu kadar
## XP daha ister (doğrusal büyüme), üstel/patlayan bir artış YOK.
const MAX_XP_INCREMENT := 60.0
## Artışın MIN_XP_INCREMENT'ten MAX_XP_INCREMENT'e ulaşması kaç seviye
## sürer (6, 8, 10, ..., 24 -> 10 adım). MAX_XP_INCREMENT/MIN_XP_INCREMENT/
## XP_INCREMENT_GROWTH değiştirilirse bu da elle güncellenmeli.
const RAMP_STEPS := 10
var team_xp_needed: float = BASE_XP_NEEDED

## Bir SONRAKİ seviye için gereken XP (bkz. yukarıdaki eğri notu). Her
## seviye atlayışı bir "adım" sayılır (1'den level-1'e kadar); ilk
## RAMP_STEPS adımın artışı MIN_XP_INCREMENT'ten başlayıp XP_INCREMENT_
## GROWTH ile büyür, ondan sonraki adımlar sabit MAX_XP_INCREMENT ekler.
## Tam sayıya yuvarlanıyor ki HUD'da "143 / 156" gibi düzgün görünsün.
func _xp_needed_for_level(level: int) -> float:
	var steps: int = maxi(level - 1, 0)
	var ramp_steps_done: int = mini(steps, RAMP_STEPS)
	var ramp_sum: float = ramp_steps_done * MIN_XP_INCREMENT \
			+ XP_INCREMENT_GROWTH * (ramp_steps_done * (ramp_steps_done - 1) / 2.0)
	var capped_steps: int = maxi(steps - RAMP_STEPS, 0)
	var capped_sum: float = capped_steps * MAX_XP_INCREMENT
	return round(BASE_XP_NEEDED + ramp_sum + capped_sum)

## #48 DÜZELTME (kullanıcı isteği: "Level kartı reroll'u altınla olsun,
## level başına +1 altın"): her takım seviye atlayışında oyuncuya kişisel
## +1 altın veriliyor - böylece reroll'a (bkz. level_up_screen.gd
## LEVEL_UP_REROLL_COST) harcanacak bir kaynak birikiyor. Altın KİŞİSEL
## olduğu için (bkz. gold_drop.gd yorumları) bu artış hem host'un DOĞRUDAN
## _level_up_team() çağırdığı yolda HEM DE her istemcinin senkronize
## set_team_xp_state() çağırdığı yolda AYRI AYRI uygulanıyor - yoksa
## sadece host altın kazanıp diğer oyuncular hiç kazanmazdı.
const LEVEL_UP_GOLD_REWARD := 1

signal team_xp_changed(current: float, needed: float)
signal team_leveled_up(new_level: int)

func add_team_xp(amount: float) -> void:
	if amount <= 0.0 or is_game_over:
		return
	team_xp += amount
	team_xp_changed.emit(team_xp, team_xp_needed)
	while team_xp >= team_xp_needed:
		_level_up_team()

func _level_up_team() -> void:
	team_level += 1
	team_xp -= team_xp_needed
	## bkz. _xp_needed_for_level üstündeki eğri notu - eskiden burada üstel
	## çarpma vardı (team_xp_needed * XP_GROWTH_FACTOR), artık gereksinim
	## doğrudan seviyenin fonksiyonu (her zaman aynı sonucu verir, yeniden
	## yüklenen/geç kalan istemcilerde sapma birikmez).
	team_xp_needed = _xp_needed_for_level(team_level)
	gold += LEVEL_UP_GOLD_REWARD
	team_leveled_up.emit(team_level)
	team_xp_changed.emit(team_xp, team_xp_needed)

func set_team_xp_state(new_xp: float, new_needed: float, new_level: int) -> void:
	var old_level: int = team_level
	team_xp = new_xp
	team_xp_needed = new_needed
	team_level = new_level
	team_xp_changed.emit(team_xp, team_xp_needed)
	if new_level > old_level:
		for lvl in range(old_level + 1, new_level + 1):
			gold += LEVEL_UP_GOLD_REWARD
			team_leveled_up.emit(lvl)


## Kullanıcı isteği: "haritamdaki 'su' ve 'ev' layerlarını collisionshape
## olarak atar mısın, bunların olduğu hiçbir şeye hiç kimse giremez,
## yaratıklar orada spawnlanamaz, içinden geçemez" - TileSet'e fiziksel
## collision shape EKLEMEK yerine (bkz. scenes/harita_baked.tscn: TÜM
## TileMapLayer'lar TEK bir paylaşılan TileSet kullanıyor - aynı atlas
## karosu başka bir katmanda da kullanılırsa collision oraya da "sızardı";
## ayrıca YATI her yeniden bake'te TileSet'i sıfırdan ürettiği için elle
## eklenen fiziği kaybederdi, bkz. tools/bake_harita.gd) doğrudan KARO
## SORGUSUNA dayalı hafif bir engelleme kullanılıyor - player.gd
## _block_movement_into_enemies()/_block_movement_into_players() ile AYNI
## teknik (hıza girmek istediği yöndeki bileşeni iptal etmek), ama başka
## bir cismin gövdesine değil harita_baked.tscn'deki "Su/Su" ve "ev/Ev"
## karolarına karşı. Bu yöntem TileSet'e hiç dokunmadığı için harita Tiled'da
## yeniden düzenlenip bake edildiğinde OTOMATİK olarak güncel kalır (ekstra
## bir post-bake düzeltmesi gerekmez, animation_columns/ekstra 2 gibi).
var _terrain_su_layer: TileMapLayer = null
var _terrain_ev_layer: TileMapLayer = null
var _terrain_forest_layer: TileMapLayer = null
var _terrain_layers_searched: bool = false
var _map_world_rect: Rect2 = Rect2()
var _map_world_rect_searched: bool = false


func _find_terrain_layers() -> void:
	if _terrain_layers_searched:
		return
	_terrain_layers_searched = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var harita: Node = tree.current_scene.get_node_or_null("Harita")
	if harita == null:
		return
	_terrain_su_layer = harita.get_node_or_null("Su/Su") as TileMapLayer
	_terrain_ev_layer = harita.get_node_or_null("ev/Ev") as TileMapLayer
	_terrain_forest_layer = harita.get_node_or_null("Orman parçaları/Orman parçaları") as TileMapLayer


## KULLANICI İSTEĞİ (2026-09-21): "Oyuncular haritanın dışını görememeli" - ana haritanın (sahnedeki "Harita" düğümü)
## DÜNYA koordinatlarındaki sınırları: içindeki tüm TileMapLayer'ların dolu karo alanlarının birleşimi. Sınırı elle bir
## sabite yazmak yerine karolardan okumak, harita Tiled'da büyütülüp yeniden bake edilince kendiliğinden güncel kalır.
## Harita sahnede yoksa (ana menü, testler) Rect2() döner ve sonuç ÖNBELLEĞE ALINMAZ (harita sonradan gelirse bulunur).
## Tüketici: camera_map_limits.gd.
func get_map_world_rect() -> Rect2:
	if _map_world_rect_searched:
		return _map_world_rect
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return Rect2()
	var harita: Node = tree.current_scene.get_node_or_null("Harita")
	if harita == null:
		return Rect2()
	var total: Rect2 = Rect2()
	var found: bool = false
	var stack: Array[Node] = [harita]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		if not (n is TileMapLayer):
			continue
		var layer: TileMapLayer = n
		var used: Rect2i = layer.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var half: Vector2 = (Vector2(layer.tile_set.tile_size) if layer.tile_set != null else Vector2(16.0, 16.0)) * 0.5
		var top_left: Vector2 = layer.to_global(layer.map_to_local(used.position) - half)
		var bottom_right: Vector2 = layer.to_global(layer.map_to_local(used.position + used.size - Vector2i.ONE) + half)
		var r: Rect2 = Rect2(top_left, Vector2.ZERO).expand(bottom_right)
		total = r if not found else total.merge(r)
		found = true
	if not found:
		return Rect2()
	_map_world_rect = total
	_map_world_rect_searched = true
	return _map_world_rect


## Kullanıcı isteği: "Orman parçaları Node2D'nin içindeki 'Orman parçaları'
## layerını collision shape ile kaplamanı istiyorum ve bu ayrıca görüş alanını
## da kısıtlayacak, bunun ardındaki hiçbir şeyi görememeliyiz" - bu katman
## (plato/uçurum kaya duvarları) HEM geçilmez (bkz. is_position_blocked_by_forest)
## HEM görüşü keser (bkz. vision_fog.gd / vision_occluders.gd, katmanı buradan
## alıyorlar - yolun TEK kaynağı burası). Ana harita sahnede yoksa null.
func get_forest_layer() -> TileMapLayer:
	_find_terrain_layers()
	return _terrain_forest_layer if is_instance_valid(_terrain_forest_layer) else null


## world_pos'ta orman katmanında (Harita/Orman parçaları/Orman parçaları) bir
## karo varsa true. player.gd/enemy.gd'nin hareket engellemesi SADECE bunu
## kullanıyor: su/ev engeli oyuncu ve yaratıklar için hâlâ bilerek KAPALI (bkz.
## oradaki "GEÇİCİ OLARAK DEVRE DIŞI" notu - kullanıcı o collision'ları
## sıfırdan, parça parça yeniden diziyor; orman ilk parça).
func is_position_blocked_by_forest(world_pos: Vector2) -> bool:
	var forest: TileMapLayer = get_forest_layer()
	if forest == null:
		return false
	var cell: Vector2i = forest.local_to_map(forest.to_local(world_pos))
	return forest.get_cell_source_id(cell) != -1


## world_pos'ta (Harita/Su/Su, Harita/ev/Ev ya da orman katmanında) bir karo
## varsa true döner - "su", "ev" (dış bina) ya da orman duvarı alanına
## giriliyor demektir. Ana harita sahnede yoksa (ör. ana menü, ev içi ayrı
## bir bake) her zaman false. Spawner/satıcı yerleşimi/pet'ler bunu kullanır.
func is_position_blocked_by_terrain(world_pos: Vector2) -> bool:
	_find_terrain_layers()
	if is_instance_valid(_terrain_su_layer):
		var cell: Vector2i = _terrain_su_layer.local_to_map(_terrain_su_layer.to_local(world_pos))
		if _terrain_su_layer.get_cell_source_id(cell) != -1:
			return true
	if is_instance_valid(_terrain_ev_layer):
		var cell2: Vector2i = _terrain_ev_layer.local_to_map(_terrain_ev_layer.to_local(world_pos))
		if _terrain_ev_layer.get_cell_source_id(cell2) != -1:
			return true
	return is_position_blocked_by_forest(world_pos)


## ==============================================================================
## ENGELLEYİCİ PANEL KAYDI (kullanıcı isteği: "gamepad desteği ekle") -
## shop_panel.gd/merchant_shop_screen.gd gibi ekranlar BİLEREK get_tree().
## paused KULLANMIYOR (takım arkadaşları dışarıda oynamaya devam edebilsin
## diye) - bu yüzden main.gd'nin global ui_cancel/pause-toggle kontrolü
## (bkz. main.gd _process) bu ekranlar açıkken de koşulsuz çalışıp pause
## menüsünü ÜSTLERİNE açardı. Bu ekranlar artık kendi ui_cancel'larını
## KENDİLERİ işleyip kapanıyor (bkz. ilgili script'lerdeki _process); main.gd
## ise "şu an açık bir engelleyici panel var mı" diye burayı sorup varsa
## kendi pause-toggle'ını atlıyor. Input.is_action_just_pressed() bir input
## event'i DEĞİL, global bir "bu karede basıldı mı" bayrağı olduğu için
## normal set_input_as_handled() ile bastırılamıyor - bu yüzden olay tabanlı
## değil, DURUM tabanlı (bu Array) bir koruma kullanılıyor.
## ==============================================================================
var _blocking_panels: Array = []

func register_blocking_panel(panel: Node) -> void:
	if not _blocking_panels.has(panel):
		_blocking_panels.append(panel)


func unregister_blocking_panel(panel: Node) -> void:
	_blocking_panels.erase(panel)


func is_any_blocking_panel_open() -> bool:
	for i in range(_blocking_panels.size() - 1, -1, -1):
		if not is_instance_valid(_blocking_panels[i]):
			_blocking_panels.remove_at(i) ## sahne değişimiyle sessizce geçersizleşenleri süpür
	for panel in _blocking_panels:
		if panel.visible:
			return true
	return false


func reset() -> void:
	_blocking_panels.clear()
	_terrain_su_layer = null
	_terrain_ev_layer = null
	_terrain_forest_layer = null
	_terrain_layers_searched = false
	_map_world_rect = Rect2()
	_map_world_rect_searched = false
	game_time = 0.0
	is_game_over = false
	## Önceki oyundan kalma bir seyyar satıcı bölgesi yeni oyuna sızmasın.
	merchant_zone_active = false
	merchant_zone_pos = Vector2.ZERO
	_mini_shop_cooldown_remaining = 0.0
	team_level = 1
	team_xp = 0.0
	team_xp_needed = BASE_XP_NEEDED
	team_xp_changed.emit(team_xp, team_xp_needed)
	revives_remaining = max_revives
	peer_revives.clear()
	_revive_regen_timers.clear()
	revives_updated.emit(revives_remaining)
	gold = 0
	spray_level = 0
	## Kullanıcı isteği: "kimsenin başlangıç kalkanı yok" - bkz. yukarıdaki
	## var bildirimi üzerindeki AYNI yorum.
	shield_standart_level = 0
	shield_enerji_level = 0
	shield_kale_level = 0
	shield_savas_level = 0
	owned_weapons = []
	owned_items = []
	pending_chest_tiers = []
	shield_mod_resilience_level = 0
	shield_mod_thorny_level = 0
	shield_mod_turtle_level = 0
	shield_mod_aggressive_level = 0
	shield_mod_lightning_level = 0
	shield_mod_piercing_level = 0
	shield_mod_tank_level = 0
	active_shield_mode = ""
