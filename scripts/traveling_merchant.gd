extends Node2D
class_name TravelingMerchant

## Kullanıcı isteği: "Haritamın belli gölgelerinde tüccar gelir (seyyar
## satıcı.tmx harita dosyası seyyar satıcıyı içeriyor) (oyunda sadece çalı
## layer'larına ait parçaların olduğu noktalara gelir ve herhangi bir
## collision shape ile temas etmemelidir konumsal olarak) tüccar 4 dakika
## boyunca orada bekler, dükkan geldiğinde oyunculara bildirim gelir ve ne
## tarafta olduğu haritada işaretle gösterilir."
##
## GÖRSEL NOT (ÇÖZÜLDÜ): harita/Seyyar satıcı.tmx'in referans verdiği tileset
## dosyaları ("Seyyar satıcı parçaları.tsx", "Horse_with_shadow.tsx") projede
## YOK sanılıyordu (bkz. eski "Tileset file ... not found" hatası) - aslında
## vardılar ama .tmx'teki göreli yol YANLIŞTI ("../../../seyyar satıcı/...",
## 3 üst dizin + "Harita içerikleri" segmenti eksik). Gerçek konum "Harita
## içerikleri/seyyar satıcı/Tiled_files/..." (proje kökünün YANINDA, 2 üst
## dizin) - yol düzeltildi. `godot --headless --script res://tools/bake_
## seyyar_satici.gd` yeniden çalıştırılıp res://scenes/seyyar_satici_baked.
## tscn tazelendiğinde _spawn_visual() aşağıda otomatik olarak gerçek
## görsele geçer (bake hâlâ boşsa/eskiyse sessizce placeholder'a döner, bkz.
## _load_baked_visual).
##
## KONUM SEÇİMİ (kullanıcı isteği): "sadece çalı layer'larına ait parçaların
## olduğu noktalara gelir" - haritadaki üç çalı katmanının (Harita/Shader
## Eklenecek/Çalılar, Çalılar1, Animasyonsuz çalılar) KULLANILMIŞ
## hücrelerinden biri seçilir. "herhangi bir collision shape ile temas
## etmemelidir" - haritada gerçek statik collision shape YOK (bkz.
## GameManager.is_position_blocked_by_terrain üstündeki yorum - TÜM
## engelleme karo-sorgusuna dayalı, gerçek CollisionShape2D hiç kullanılmıyor,
## bkz. scenes/harita_baked.tscn içinde sıfır StaticBody2D/CollisionShape2D)
## - bu yüzden kural en pratik/anlamlı karşılığıyla uygulanıyor: aday nokta
## su/ev karosunda OLMAMALI (is_position_blocked_by_terrain) VE o an hiçbir
## oyuncu/yaratığın gövdesine DEĞMEMELİ (SPAWN_CLEARANCE_RADIUS).
##
## AĞ MİMARİSİ: sadece HOST (ya da tek oyunculu) _process'te ne zaman/nerede
## kararını verir ve NetworkManager.broadcast_merchant_spawned/departed
## RPC'siyle (call_local) yayınlar - HER peer (host dahil) bu sinyalden
## GameManager.merchant_zone_* durumunu ve görseli günceller, main.gd de
## AYRICA aynı sinyalden bildirim/minimap işaretini günceller (bkz. o
## dosyadaki _on_merchant_spawned/_on_merchant_departed).

## DÜZELTME (kullanıcı isteği: "dükkanın spawnlanma sıklığını 2 dakikaya
## düşür ve kalma süresi de 2 dakika olsun") - eskiden 4 dakika (240.0)
## bekliyordu, artık 2 dakika (120.0).
const VISIT_DURATION := 180.0
## DÜZELTME (aynı istek: "2 dakika kaldıktan sonra gidip 2 dakika sonra
## tekrar gelcek") - eskiden 3-6 dakika arası RASTGELE bir bekleme vardı
## (kullanıcı ilk turda süreyi belirtmemişti); artık MIN=MAX=120.0 olduğu
## için randf_range(COOLDOWN_MIN, COOLDOWN_MAX) her zaman tam 2 dakika
## döndürüyor - sabit bir döngü.
const COOLDOWN_MIN := 120.0
const COOLDOWN_MAX := 120.0
## İlk ziyaret oyunun tam başında değil, biraz oynadıktan sonra gelsin diye.
## GEÇİCİ TEST DEĞERİ (kullanıcı isteği: "deneme açısından oyun ilk
## başladığında ... seyyar satıcı spawnlansın") - bildirim/ok/görsel
## sistemini hemen doğrulayabilmek için 60-150sn yerine birkaç saniyeye
## çekildi. Test bitince eski değerlere (60.0 / 150.0) döndürülmeli.
const INITIAL_DELAY_MIN := 3.0
const INITIAL_DELAY_MAX := 5.0

const BUSH_LAYER_PATHS := [
	"Shader Eklenecek/Çalılar",
	"Shader Eklenecek/Çalılar1",
	"Shader Eklenecek/Animasyonsuz çalılar",
]
const SPAWN_CLEARANCE_RADIUS := 90.0
const SPAWN_CANDIDATE_ATTEMPTS := 30

## Kullanıcı isteği (İKİNCİ tur): "Seyyar satıcı dükkandan rasgele 6 item
## gösterecek. Ekstralar, silahlar, kalkanlar dahil." - satıcı BELİRİRKEN
## (bkz. _generate_stock) bu üç havuzdan (bkz. items.gd Items.KEYS + bu iki
## "deliberate copy" liste - shop_panel.gd/chest_menu.gd/merchant_shop_
## screen.gd ile AYNI desen) 6 benzersiz giriş rastgele seçilir.
const STOCK_SIZE := 6
const WEAPON_KEYS := ["dagger", "fire_staff", "lightning_staff", "tabanca", "tuftuf", "tufek", "arcane", "yay", "crossbow", "boomerang", "buz_asasi", "fisek", "pence", "topuz", "uzunkilic"]
const SHIELD_TYPE_KEYS := ["shield_standart", "shield_enerji", "shield_kale", "shield_savas"]
## Kullanıcı isteği: "oyun başında seçtiğimiz silahın ... çıkma olasılığı
## daha fazla olmalı" - _generate_stock()'taki ağırlıklı havuzda oyuncunun
## başlangıç silahının kaç kat daha sık göründüğü (bkz. o fonksiyon).
const WEAPON_START_WEIGHT := 4
## Kullanıcı isteği: "seyyar satıcı herkese aynı eşyayı satıyor, herkese
## farklı şeyler çıkmalıydı" - _generate_stock() artık HOST'ta bir kere
## üretilip ağdan dağıtılmıyor, HER istemci kendi stokunu KENDİ yerel
## çağrısıyla üretiyor (bkz. _on_merchant_spawned) - her istemci ayrı bir
## işlem olduğu için Godot'un varsayılan (otomatik tohumlanmış) global rastgele
## sayı üreticisi zaten birbirinden bağımsız/farklı sonuçlar verir.
## Kullanıcı isteği: "Seyyar satıcıdaki eşyaları rerollama butonu ekle, 1
## reroll hakkı olucak her oyuncunun her seyyar satıcı geldiğinde. Önceki
## gelişindeki reroll kullanılmazsa sonrakine eklenerek 2 reroll hakkı olacak.
## (en fazla 3 olabilir)" - bkz. try_reroll_stock()/_reroll_charges.
const REROLL_MAX_CHARGES := 3

## Kullanıcı isteği: "Seyyar satıcı ile etkileşime girip item alabilecez" -
## house_interior.gd _create_entrance_trigger/_create_prompt_ui ile AYNI
## desen (Area2D + "F'ye bas" etiketi), ama F'ye basınca ışınlanma DEĞİL
## merchant_shop_screen.gd açılıyor.
const INTERACT_RADIUS := 80.0

var _active: bool = false
var _visit_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _visual: Node2D = null
var _current_stock: Array = []
## DÜZELTME (kullanıcı bildirimi: "Dükkanda birşey aldığımızda dükkanın
## alanından çıkıp veya kapatıp tekrar açınca aynı şeyi tekrar alabiliyoruz
## bunun olmaması gerekiyor çünkü tüccarın her gelişi başına her itemden
## sadece 1 tane alabilmeliydik") - kök neden: bu dizi eskiden merchant_
## shop_screen.gd'nin KENDİ üzerinde yaşıyordu, o ekran her açılışta baştan
## kuruluyordu (kapanışta queue_free()) - yani ekranı kapatıp AYNI ziyaret
## içinde tekrar açmak "satıldı" kaydını sıfırlıyordu. _current_stock İLE
## AYNI şekilde bu TravelingMerchant node'unda (ziyaret boyunca kalıcı)
## yaşıyor artık - bkz. merchant_shop_screen.gd _entry_can_buy/
## _on_buy_pressed/_refresh_all_buy_states (artık burayı okuyup yazıyorlar).
## Reroll SADECE bunu sıfırlar (kullanıcı isteği: "rerolla tekrar o itemden
## gelirse bu alamama sınırına dahil değildir") - bkz. _on_merchant_spawned/
## try_reroll_stock.
var sold_item_indices: Array = []
## bkz. dosya başı "REROLL_MAX_CHARGES" notu - SADECE bu istemcinin/oyuncunun
## kendi yerel hakkı (ağdan senkronize edilmiyor, tıpkı stok gibi kişisel).
var _reroll_charges: int = 0
## Bir ziyarette birden fazla kez _on_merchant_spawned tetiklenirse (ör.
## sonradan katılan bir oyuncu için _on_peer_needs_game_catchup) AYNI ziyaret
## için ikinci kez +1 hak verilmesin diye - bkz. _on_merchant_spawned/
## _on_merchant_departed.
var _reroll_granted_this_visit: bool = false

## Kullanıcı isteği: "deneme açısından oyun ilk başladığında eve yakın
## biyerde seyyar satıcı spawnlansın" - SADECE oturumun İLK ziyareti için
## (bkz. _pick_spawn_position) aday konum "eve yakınlığa" göre seçilir,
## sonraki tüm ziyaretler eskisi gibi tamamen rastgele kalır.
var _is_first_visit: bool = true
## "Ev" için ayrı bir sabit/kopya TUTMUYORUZ (main.tscn'deki Player başlangıç
## konumuyla sapabilirdi) - oyunun kendi başlangıç anındaki oyuncu konumu
## zaten "ev" konumunun ta kendisi, bkz. _ready().
var _home_position: Vector2 = Vector2.ZERO

var _interact_area: Area2D = null
var _prompt_layer: CanvasLayer = null
var _prompt_label: Label = null
var _player_near: bool = false
var _shop_screen: CanvasLayer = null

const MerchantShopScreenScript := preload("res://scripts/merchant_shop_screen.gd")
## Kullanıcı isteği: "dıştaki kalkan efekti şovalye adamın kalkan baloncuğu
## gibi görünmüyor" - kendi basit çizimimiz yerine ŞOVALYE'NİN "Koruma
## Baloncuğu" ultisiyle BİREBİR AYNI görsel (bkz. player.gd _skill_paladin_
## ulti, fx_paladin_barrier.gd, shaders/shield_dome.gdshader) yeniden
## kullanılıyor - sadece radius/color farklı, teknik/görsel dil AYNI.
const ProtectionBubbleScript := preload("res://scripts/fx_paladin_barrier.gd")


func _ready() -> void:
	NetworkManager.merchant_spawned.connect(_on_merchant_spawned)
	NetworkManager.merchant_departed.connect(_on_merchant_departed)
	## BUG DÜZELTMESİ (kullanıcı sorusu: "son eklenen şeylerle ilgili
	## multiplayer senkronizasyon sorunu var mı?") - merchant_spawned/departed
	## sinyalleri SADECE olay anında bir kez ateşlenir; sonradan katılan/
	## yeniden bağlanan bir oyuncu o anda ZATEN aktif olan bir ziyareti asla
	## öğrenemiyordu (bkz. enemy_spawner.gd'nin AYNI sorunu AYNI mekanizmayla
	## çözdüğü _on_peer_needs_game_catchup - burada da birebir kopyalandı).
	NetworkManager.peer_needs_game_catchup.connect(_on_peer_needs_game_catchup)
	_cooldown_timer = randf_range(INITIAL_DELAY_MIN, INITIAL_DELAY_MAX)
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		_home_position = player.global_position


## bkz. enemy_spawner.gd _on_peer_needs_game_catchup ile BİREBİR AYNI desen -
## host, o an aktif bir ziyaret varsa mevcut durumu (konum + stok) SADECE
## yeni katılan bu peer'e hedefli (rpc_id) olarak tekrar gönderir. call_local
## sayesinde host'ta da yeniden tetiklenebilir ama _on_merchant_spawned zaten
## kendi eski görsel/etkileşim düğümlerini önce serbest bıraktığı için
## (bkz. _spawn_visual/_create_interaction) bu zararsızdır.
func _on_peer_needs_game_catchup(peer_id: int) -> void:
	if not NetworkManager.is_host:
		return
	if not _active:
		return
	NetworkManager.broadcast_merchant_spawned.rpc_id(peer_id, GameManager.merchant_zone_pos, _current_stock)


func _process(delta: float) -> void:
	_process_interaction()
	## bkz. enemy_spawner.gd _process - AYNI ilk koruma, oyun bittikten sonra
	## yeni bir ziyaret başlatılmasın.
	if GameManager.is_game_over:
		return
	## Sadece HOST (ya da tek oyunculu) ne zaman/nerede kararını verir -
	## client'lar SADECE yukarıdaki sinyalleri dinleyip uygular, kendi
	## kararlarını vermez (host-authoritative, tıpkı enemy_spawner.gd gibi).
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return
	if _active:
		_visit_timer -= delta
		if _visit_timer <= 0.0:
			_broadcast_departed()
		return
	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		var pos: Vector2 = _pick_spawn_position()
		if pos == Vector2.ZERO:
			## Uygun nokta bulunamadı (aşırı nadir - tüm çalı noktaları
			## dolu/su-ev üstünde) - kısa süre sonra tekrar dene.
			_cooldown_timer = 15.0
			return
		_broadcast_spawned(pos, _generate_stock())
		_is_first_visit = false


func _broadcast_spawned(pos: Vector2, stock: Array) -> void:
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_merchant_spawned.rpc(pos, stock)
	else:
		NetworkManager.merchant_spawned.emit(pos, stock)


func _broadcast_departed() -> void:
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_merchant_departed.rpc()
	else:
		NetworkManager.merchant_departed.emit()


## DÜZELTME (kullanıcı bildirimi: "seyyar satıcı herkese aynı eşyayı satıyor,
## herkese farklı şeyler çıkmalıydı") - ağdan gelen "stock" parametresi artık
## KULLANILMIYOR (SADECE RPC/sinyal imzasını değiştirmemek için hâlâ duruyor,
## bkz. dosya başı notu) - her istemci kendi stokunu burada YEREL olarak
## üretir, böylece host dahil her oyuncu birbirinden bağımsız/farklı 6 eşya
## görür.
func _on_merchant_spawned(_pos: Vector2, _stock: Array) -> void:
	_active = true
	_visit_timer = VISIT_DURATION
	_current_stock = _generate_stock()
	sold_item_indices = []
	## Kullanıcı isteği: "1 reroll hakkı olucak her oyuncunun her seyyar
	## satıcı geldiğinde" - bu ziyaret için hak DAHA ÖNCE verilmediyse (bkz.
	## _reroll_granted_this_visit üstündeki yorum) +1, en fazla
	## REROLL_MAX_CHARGES'a kadar.
	if not _reroll_granted_this_visit:
		_reroll_granted_this_visit = true
		_reroll_charges = min(REROLL_MAX_CHARGES, _reroll_charges + 1)
	GameManager.merchant_zone_active = true
	GameManager.merchant_zone_pos = _pos
	_spawn_visual(_pos)
	_create_interaction(_pos)


func _on_merchant_departed() -> void:
	_active = false
	_cooldown_timer = randf_range(COOLDOWN_MIN, COOLDOWN_MAX)
	GameManager.merchant_zone_active = false
	_current_stock = []
	## Kullanıcı isteği: "Önceki gelişindeki reroll kullanılmazsa sonrakine
	## eklenerek..." - kullanılmayan _reroll_charges BİLEREK sıfırlanmıyor,
	## bir sonraki ziyarette üstüne +1 eklenecek (bkz. _on_merchant_spawned).
	## SADECE "bu ziyaret için hak zaten verildi" bayrağı sıfırlanıyor.
	_reroll_granted_this_visit = false
	_free_visual()
	_free_interaction()
	if _shop_screen and is_instance_valid(_shop_screen):
		_shop_screen.queue_free()
	_shop_screen = null


func get_reroll_charges() -> int:
	return _reroll_charges


func get_reroll_max() -> int:
	return REROLL_MAX_CHARGES


## merchant_shop_screen.gd'nin "Yeniden Çevir" butonu tarafından çağrılır -
## hakkı varsa 1 harcayıp TAZE bir stok üretir ve döner, yoksa null döner
## (çağıran taraf butonu zaten 0 haktayken disabled bıraktığı için bu SADECE
## bir güvenlik payı).
func try_reroll_stock() -> Variant:
	if _reroll_charges <= 0:
		return null
	_reroll_charges -= 1
	_current_stock = _generate_stock()
	sold_item_indices = []
	return _current_stock


## Oyuncunun şu an sahip olduğu (= oyun başında seçtiği, bkz. main.gd
## _grant_selected_item) kalkan türü - kalkan türleri BİRBİRİNİ DIŞLAR
## (bkz. merchant_shop_screen.gd _entry_can_buy "shield" dalı: "owned == ''
## or owned == key"), yani bir tür seçildikten sonra DİĞER türler o oyun
## boyunca hiç satın alınamaz hale gelir - merchant_shop_screen.gd'deki
## AYNI mantığın (deliberate copy) burada da bir kopyası.
func _owned_shield_type() -> String:
	for key in SHIELD_TYPE_KEYS:
		if int(GameManager.get(key + "_level")) > 0:
			return key
	return ""


## bkz. dosya başı "STOCK_SIZE/WEAPON_START_WEIGHT" notu.
## DÜZELTME (kullanıcı bildirimi: "Seyyar satıcıda kalkan da çıkmalı") -
## kalkanlar havuzda sadece 4/32 giriş olduğu için saf rastgele seçimde
## ziyaretlerin ~%42'sinde HİÇ çıkmıyorlardı - artık 6 slottan 1 tanesi HER
## ZAMAN bir kalkan. DÜZELTME (kullanıcı bildirimi: "oyun başında
## seçtiğimiz ... kalkanının çıkma olasılığı daha fazla olmalı") - bu
## garantili slot oyuncunun ZATEN SAHİP OLDUĞU türü kullanır (henüz hiç
## kalkanı yoksa rastgele bir türle başlar) - FARKLI bir tür göstermek
## zaten anlamsız olurdu (yukarıdaki _owned_shield_type() notuna bkz.,
## satın alınamaz).
## Kalan 5 slot Items.KEYS + WEAPON_KEYS + (kalan) SHIELD_TYPE_KEYS'ten
## ağırlıklı bir havuzla çekilir: oyuncunun başlangıç silahı (kullanıcı
## isteği: "oyun başında seçtiğimiz silahın ... çıkma olasılığı daha fazla
## olmalı") WEAPON_START_WEIGHT kat daha sık havuza eklenir - bu SADECE bir
## ağırlık (garanti DEĞİL, silahlar birbirini dışlamaz, çeşitlilik önemli),
## kalkanlarınkinin AKSİNE.
func _generate_stock() -> Array:
	var stock: Array = []
	var owned_shield: String = _owned_shield_type()
	var guaranteed_shield_key: String = owned_shield if owned_shield != "" else SHIELD_TYPE_KEYS[randi() % SHIELD_TYPE_KEYS.size()]
	stock.append({"type": "shield", "key": guaranteed_shield_key})

	var starting_weapon_key: String = ""
	if not GameManager.owned_weapons.is_empty():
		starting_weapon_key = str((GameManager.owned_weapons[0] as Dictionary).get("key", ""))

	var pool: Array = []
	for k in Items.KEYS:
		pool.append({"type": "item", "key": k})
	for k in WEAPON_KEYS:
		var weight: int = WEAPON_START_WEIGHT if k == starting_weapon_key else 1
		for _i in range(weight):
			pool.append({"type": "weapon", "key": k})
	for k in SHIELD_TYPE_KEYS:
		if k != guaranteed_shield_key:
			pool.append({"type": "shield", "key": k})
	pool.shuffle()

	## Ağırlık için havuza kopyalanmış girişler (ör. başlangıç silahı) aynı
	## eşyayı stokta İKİ KEZ göstermesin diye (type, key) bazında tekilleştir.
	var used: Dictionary = {"shield:" + guaranteed_shield_key: true}
	for raw_entry in pool:
		if stock.size() >= STOCK_SIZE:
			break
		var entry: Dictionary = raw_entry as Dictionary
		var dedup_key: String = str(entry["type"]) + ":" + str(entry["key"])
		if used.has(dedup_key):
			continue
		used[dedup_key] = true
		var final_entry: Dictionary = entry.duplicate()
		if final_entry["type"] == "item":
			final_entry["tier"] = TierSystem.roll()
		stock.append(final_entry)
	## Garantili kalkan hep 1. karta düşmesin diye kartların gösterim sırası
	## da karıştırılıyor.
	stock.shuffle()
	return stock


## bkz. dosya başı "KONUM SEÇİMİ" notu.
func _pick_spawn_position() -> Vector2:
	var harita: Node = get_tree().current_scene.get_node_or_null("Harita")
	if not harita:
		return Vector2.ZERO
	var candidates: Array = []
	for path in BUSH_LAYER_PATHS:
		var layer := harita.get_node_or_null(path) as TileMapLayer
		if not layer:
			continue
		for cell in layer.get_used_cells():
			candidates.append(layer.to_global(layer.map_to_local(cell)))
	if candidates.is_empty():
		return Vector2.ZERO
	## bkz. dosya başı "_is_first_visit" notu - ilk ziyarette rastgele karıştırmak
	## yerine eve en yakın adaylardan başlanır, sonraki tüm ziyaretler eskisi
	## gibi tam rastgele.
	if _is_first_visit:
		candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool:
			return a.distance_squared_to(_home_position) < b.distance_squared_to(_home_position))
	else:
		candidates.shuffle()
	var found: Vector2 = _first_valid_candidate(candidates, min(SPAWN_CANDIDATE_ATTEMPTS, candidates.size()))
	if found != Vector2.ZERO:
		return found
	## DÜZELTME: eve en yakın adaylar oyuncunun KENDİSİNE çok yakınsa (oyunun
	## ilk birkaç saniyesi, bkz. _is_first_visit) SPAWN_CLEARANCE_RADIUS
	## hepsini eleyebilir - bu durumda ilk ziyaret süresiz denemede takılı
	## kalmasın diye kalan adaylar (varsa) rastgele sırayla da denenir.
	if _is_first_visit and candidates.size() > SPAWN_CANDIDATE_ATTEMPTS:
		var rest: Array = candidates.slice(SPAWN_CANDIDATE_ATTEMPTS)
		rest.shuffle()
		return _first_valid_candidate(rest, min(SPAWN_CANDIDATE_ATTEMPTS, rest.size()))
	return Vector2.ZERO


func _first_valid_candidate(candidates: Array, attempts: int) -> Vector2:
	for i in range(attempts):
		var pos: Vector2 = candidates[i]
		if GameManager.is_position_blocked_by_terrain(pos):
			continue
		if _position_clear_of_entities(pos):
			return pos
	return Vector2.ZERO


## bkz. dosya başı "GÖRSEL NOT" - koruma alanının (GameManager.MERCHANT_ZONE_
## RADIUS) görsel karşılığı. _visual'ın çocuğu olduğu için satıcının konumuna
## otomatik ortalanır, satıcı ayrılınca (_free_visual) onunla birlikte silinir.
## radius/color, fx_paladin_barrier.gd'nin _ready()'si tarafından OKUNUYOR -
## bu yüzden node AĞACA EKLENMEDEN (add_child'dan ÖNCE) atanmalı, yoksa
## _ready() varsayılan (126.0, mavi) değerlerle kurulur (bkz. player.gd
## _skill_paladin_ulti'nin AYNI sırayı izlemesi gereken notu).
func _create_protection_bubble() -> Node2D:
	var bubble := Node2D.new()
	bubble.name = "ProtectionBubble"
	bubble.set_script(ProtectionBubbleScript)
	bubble.radius = GameManager.MERCHANT_ZONE_RADIUS
	## Şovalye'nin savaş kalkanıyla (mavi) karışmasın diye altın/ticaret
	## temalı bir renk - görsel TEKNİK (dome shader, parıltı, nabız) birebir
	## aynı, sadece renk farklı.
	bubble.color = Color(1.0, 0.82, 0.25, 0.9)
	bubble.active = true
	return bubble


func _position_clear_of_entities(pos: Vector2) -> bool:
	for group_name in ["player", "remote_players", "enemies"]:
		for n in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(n) and pos.distance_to(n.global_position) < SPAWN_CLEARANCE_RADIUS:
				return false
	return true


const BakedMerchantScene := preload("res://scenes/seyyar_satici_baked.tscn")

func _spawn_visual(pos: Vector2) -> void:
	_free_visual()
	_visual = _load_baked_visual(pos)
	if not _visual:
		_visual = _create_placeholder_visual(pos)
	get_tree().current_scene.add_child(_visual)
	_visual.add_child(_create_protection_bubble())


func _free_visual() -> void:
	if _visual and is_instance_valid(_visual):
		_visual.queue_free()
	_visual = null


## bkz. dosya başı "GÖRSEL NOT" - artık gerçek bake'i dener, sadece hâlâ
## eski/boş bake'e (bkz. TileSet'i sıfır kaynaklı, hiç hücre boyanmamış -
## tools/bake_seyyar_satici.gd yeniden çalıştırılmadan ÖNCEKİ durum) sahipse
## null döner ve çağıran taraf _create_placeholder_visual'a düşer. Böylece
## kullanıcı bake aracını yeniden çalıştırana kadar oyun eski placeholder'ı
## göstermeye devam eder, hiçbir şey (görünmez düğüm) göstermez.
func _load_baked_visual(pos: Vector2) -> Node2D:
	var root: Node2D = BakedMerchantScene.instantiate() as Node2D
	if not root:
		return null
	var layers: Array = []
	for child in root.get_children():
		if child is TileMapLayer and not (child as TileMapLayer).get_used_cells().is_empty():
			layers.append(child)
	if layers.is_empty():
		root.free()
		return null
	## Kaynak .tmx'teki içerik 10x10'luk ızgaranın ortasında değil (bkz.
	## harita/Seyyar satıcı.tmx katman verileri - çadır/at/araba ızgaranın
	## sol-alt bölgesine yakın duruyor), bu yüzden TileMapLayer'ları oldukları
	## gibi bırakırsak görsel `pos`'un (etkileşim çemberinin/okun/bildirimin
	## işaret ettiği TAM konumun) belirgin şekilde dışında kalırdı. Sabit bir
	## piksel sayısı HARDCODE ETMEK yerine (kaynak .tmx değişirse sessizce
	## yanlış kalırdı) dolu hücrelerin gerçek sınır kutusunu map_to_local ile
	## hesaplayıp merkezini sıfıra kaydırıyoruz.
	var min_local: Vector2 = Vector2.ZERO
	var max_local: Vector2 = Vector2.ZERO
	var first: bool = true
	for layer: TileMapLayer in layers:
		for cell in layer.get_used_cells():
			var p: Vector2 = layer.map_to_local(cell)
			if first:
				min_local = p
				max_local = p
				first = false
			else:
				min_local.x = min(min_local.x, p.x)
				min_local.y = min(min_local.y, p.y)
				max_local.x = max(max_local.x, p.x)
				max_local.y = max(max_local.y, p.y)
	var center_offset: Vector2 = (min_local + max_local) * 0.5
	for layer: TileMapLayer in layers:
		layer.position -= center_offset
	root.global_position = pos
	return root


## bkz. dosya başı "GÖRSEL NOT" - gerçek çadır/at/araba sahnesi bake
## edilemediği sürece basit, prosedürel bir çadır silueti + etiket.
func _create_placeholder_visual(pos: Vector2) -> Node2D:
	var root := Node2D.new()
	root.name = "MerchantPlaceholder"
	root.global_position = pos
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([Vector2(-46, -20), Vector2(46, -20), Vector2(0, -50)])
	roof.color = Color(0.75, 0.15, 0.15, 1.0)
	root.add_child(roof)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-40, -20), Vector2(40, -20), Vector2(48, 20), Vector2(-48, 20)])
	body.color = Color(0.55, 0.35, 0.15, 1.0)
	root.add_child(body)
	var label := Label.new()
	label.text = "Seyyar Satıcı"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(-60, -80)
	label.size = Vector2(120, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(label)
	return root


## ---------- Etkileşim (F ile dükkanı aç) ----------
## bkz. house_interior.gd _create_entrance_trigger/_create_prompt_ui ile
## BİREBİR AYNI desen (Area2D + "F'ye bas" etiketi) - tek fark F'ye
## basınca ışınlanma DEĞİL merchant_shop_screen.gd açılması.
func _create_interaction(pos: Vector2) -> void:
	_free_interaction()
	_interact_area = Area2D.new()
	_interact_area.name = "MerchantInteractTrigger"
	_interact_area.collision_layer = 0
	_interact_area.collision_mask = 2 ## bkz. main.tscn Player collision_layer = 2
	_interact_area.position = pos
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INTERACT_RADIUS
	shape.shape = circle
	_interact_area.add_child(shape)
	get_tree().current_scene.add_child(_interact_area)
	_interact_area.body_entered.connect(_on_interact_body_entered)
	_interact_area.body_exited.connect(_on_interact_body_exited)

	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "MerchantPromptLayer"
	_prompt_layer.layer = 50
	_prompt_label = Label.new()
	_prompt_label.text = "Seyyar Satıcı ile konuşmak için F'ye bas"
	_prompt_label.add_theme_font_size_override("font_size", 24)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.offset_left = -220.0
	_prompt_label.offset_right = 220.0
	_prompt_label.offset_top = -170.0
	_prompt_label.offset_bottom = -130.0
	_prompt_label.visible = false
	_prompt_layer.add_child(_prompt_label)
	add_child(_prompt_layer)


func _free_interaction() -> void:
	if _interact_area and is_instance_valid(_interact_area):
		_interact_area.queue_free()
	_interact_area = null
	if _prompt_layer and is_instance_valid(_prompt_layer):
		_prompt_layer.queue_free()
	_prompt_layer = null
	_prompt_label = null
	_player_near = false


func _on_interact_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_near = true


func _on_interact_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_near = false


## bkz. house_interior.gd _process'in AYNI F-tuşu deseni. Sadece LOKAL
## oyuncunun kendi yakınlığına göre çalışır - her istemci bunu bağımsız
## çalıştırır (merchant_shop_screen.gd zaten TAMAMEN yerel/kişisel bir UI,
## bkz. o dosyanın dosya başı notu).
func _process_interaction() -> void:
	if not _player_near or not _prompt_label:
		_hide_prompt()
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		_hide_prompt()
		return
	## Dükkan zaten açıkken (ör. çift F basımı) tekrar açmayı/ipucunu önle.
	if _shop_screen and is_instance_valid(_shop_screen):
		_hide_prompt()
		return
	_prompt_label.visible = true
	var f_just_pressed: bool = Input.is_action_just_pressed("interact") and not bool(player.get("is_chat_typing"))
	if f_just_pressed:
		_open_shop_screen(player)


func _hide_prompt() -> void:
	if _prompt_label:
		_prompt_label.visible = false


func _open_shop_screen(player: Node) -> void:
	if _shop_screen and is_instance_valid(_shop_screen):
		return
	_shop_screen = MerchantShopScreenScript.new()
	get_tree().current_scene.add_child(_shop_screen)
	_shop_screen.setup(player, _current_stock, self)
	_shop_screen.closed.connect(func():
		_shop_screen = null
	)
