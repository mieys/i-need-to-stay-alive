extends Node2D
class_name WorldEventManager

## Rastgele dünya görevleri (kullanıcı isteği, 2026-09-23). Altı görev: Capture the point /
## Escort the van / Defend tree / Secure the area / Kill your copy / Collect - hepsi burada.
## Şema: MissionKind bir görev ekler, _available_kinds() listeye alır, _begin_warning/
## _activate_mission/_tick_mission/_end_mission'daki `match` dallarına o türün kurulum/
## ilerleme/bitiş mantığı eklenir. Görsel/kozmetik taraf main.gd + mission_*.gd script'lerinde
## (bkz. o dosyaların kendi başlık notları).
##
## BİLİNEN BASİTLEŞTİRMELER (kullanıcıya bildirildi, "geçici" kapsam kabul edildi):
##  - Defend tree: gerçek büyüme-fazlı sprite paketi hâlâ yok (zip konumu bulunamadı) -
##    mission_tree.gd prosedürel bir yer tutucu çiziyor, faz geçişinde SADECE ölçek değişiyor.
##    Ayrıca ateş topu mermisinin GÖRSELİ şu an sadece host'ta görünür (bkz. o dosyanın notu).
##  - Kill your copy: weapon.gd takılmıyor; kopya silah sahnelerinin aralık/menzil/oranıyla kendi saldırısını
##    yapıyor (bkz. mission_player_copy.gd dosya başı notu - weapon.gd'yi bir NPC'ye bağlamak riskli/pahalı).
##  - Escort the van / Kill your copy / Defend tree ödül miktarları da diğer ikisi gibi tahmini.
##
## AĞ MİMARİSİ (seyyar satıcıyla BİREBİR aynı desen, bkz. traveling_merchant.gd dosya başı):
## karar SADECE host'ta (bu script'in _process'i host olmayan istemcilerde erken döner),
## sonuç NetworkManager.broadcast_world_event_* RPC'leriyle (call_local, TÜM peer'lere)
## yayılır. İstemciler kendi başlarına görev seçmez/zamanlamaz/tamamlamaz.

enum MissionKind { CAPTURE_POINT, SECURE_AREA, COLLECT, ESCORT_VAN, DEFEND_TREE, KILL_YOUR_COPY }

const MISSION_LABELS := {
	MissionKind.CAPTURE_POINT: "Bayrağı Ele Geçir",
	MissionKind.SECURE_AREA: "Alanı Güvenceye Al",
	MissionKind.COLLECT: "Topla",
	MissionKind.ESCORT_VAN: "Konvoyu Koru",
	MissionKind.DEFEND_TREE: "Ağacı Koru",
	MissionKind.KILL_YOUR_COPY: "Kopyanı Öldür",
}
const MISSION_KIND_NAMES := {
	MissionKind.CAPTURE_POINT: "capture_point",
	MissionKind.SECURE_AREA: "secure_area",
	MissionKind.COLLECT: "collect",
	MissionKind.ESCORT_VAN: "escort_van",
	MissionKind.DEFEND_TREE: "defend_tree",
	MissionKind.KILL_YOUR_COPY: "kill_your_copy",
}
## Bkz. main.gd _on_world_event_announced/_started - "toplama görevinde toplanması gereken
## objeler ve kopyaların konumu gösterilmeyecek" (kullanıcı isteği): bu iki tür için harita/
## pusula işareti HİÇ gösterilmez (sadece bildirim metni).
## DÜZELTME (kullanıcı bildirimi 2026-09-24: "görevlerden çoğu çalışmıyor") - Topla da buradaydı: objeler
## rastgele bir harita noktasının 500 birim çevresine dağılıyor ama o ALAN da hiç gösterilmiyordu, oyuncu
## nereye gideceğini bilemiyordu. Kullanıcının asıl isteği "objelerin TAM konumu gizli" - artık Topla'nın
## ALANI (merkez) işaretleniyor, tek tek objeler yine haritada yok. Kopyalar oyuncuyu kendisi kovaladığı
## için Kopyanı Öldür'de işaret hâlâ gereksiz/gizli.
const HIDDEN_LOCATION_KINDS := [MissionKind.KILL_YOUR_COPY, MissionKind.COLLECT]

## Kullanıcı isteği: "Aynı anda sadece 2 görev aktif olabilir ve görevler arasında bekleme
## süreleri bulunur." - iki BAĞIMSIZ slot, her biri kendi döngüsünü (bekleme -> uyarı ->
## aktif -> bekleme) işletir.
const SLOT_COUNT := 2
const WARN_SECONDS := 60.0 ## "1 dakika önce bildirim" (kullanıcı isteği, sabit)
## Kullanıcı bildirimi (2026-09-24): "görevler sürekli spawnlanıyor daha yavaş spawnlanmalı" - iki slot bağımsız döndüğü
## için eski 90-180sn'lik bekleme pratikte ~1 dakikada bir yeni görev uyarısı demekti. 90-180 -> 240-360sn; ayrıca 2. slot
## artık oturumun başında da tam bir bekleme süresiyle başlar (bkz. _ready), ikisi birden erken tetiklenmesin.
const COOLDOWN_MIN := 240.0
const COOLDOWN_MAX := 360.0
## DÜZELTME (kullanıcı bildirimi: "görevlerin hiçbiri başlamıyor, 1 dakika bekledim,
## bildirim/uyarı vermiyor") - mekanizma BOZUK DEĞİL (gerçek zamanlı + zorla-ilerletme
## testiyle doğrulandı, bkz. hafıza project_world_events_mission_system notu): oturumun
## İLK görevi rastgele 45-90sn beklemeden UYARI bile göstermiyordu, yani "1 dakika"
## bazı RNG çekilişlerinde (90'a yakın) tam olarak HİÇBİR ŞEY görmeden geçebiliyordu.
## İlk izlenim için bu çok uzun/sessiz bir bekleme - iki slot da 15-30sn'ye çekildi ki
## bir görev uyarısı HER ZAMAN 1 dakikadan önce görünsün. COOLDOWN_MIN/MAX (görevler
## ARASI bekleme) kasıtlı olarak DEĞİŞMEDİ, bu sadece oturumun İLK görevi için.
const INITIAL_DELAY_MIN := 15.0
const INITIAL_DELAY_MAX := 30.0
## Kullanıcı isteği (2026-09-24): "Aynı anda nadiren 2 görev olsun ve aynı anda aynı görevler olamamalı" -
## bir slot uyarıya geçmek istediğinde diğer slotta zaten bir görev (uyarı/aktif) varsa SADECE bu olasılıkla
## başlar, aksi halde yeni bir bekleme süresine döner. İkinci görev başlarsa diğer slottaki türü SEÇEMEZ.
const SECOND_CONCURRENT_MISSION_CHANCE := 0.2

## Kullanıcı isteği (2026-09-24): "Görev ödülleri olarak her oyuncuya 1 adet rasgele tierlı sandık verilmeli"
## - başarılı her görevde (altın ödülüne EK olarak) hayattaki HER oyuncuya ayrı ayrı 1 sandık (bkz.
## _grant_chest_to_all_players). 2026-09-25: "efsunlar ... görev ödülleri ... sandık ödüllerinde çalışacak" + "elit
## sandıklardan efsun çıksın" - görev sandığı artık ELİT sandık (açılınca efsun ekranı). Sandıklar kişisel
## bekleyen-sandık kuyruğuna girer (bir sonraki seviye atlamasında açılır).

## Kullanıcı isteği (2026-09-24): "Görevler collision shape içeren şeylerin içinde spawnlanmamalı" - eskiden
## görev noktası SADECE tek bir merkez pikseli için kontrol ediliyordu; nesnenin gövdesi (ağaç tacı, konvoy,
## bayrak) ya da konvoyun gideceği yol duvar/su/ev karolarına taşabiliyordu. Artık her türün kendi gövde
## yarıçapı kadar dairesel bir alan (bkz. _is_area_clear) ve konvoyun tüm yolu (bkz. _is_path_clear) boş olmalı.
const CLEARANCE_SAMPLE_STEP := 12.0 ## karo boyutundan (16) küçük - ince duvarlar örnekler arasından kaçmasın
const SPAWN_CLEARANCE := {
	MissionKind.CAPTURE_POINT: 64.0,
	MissionKind.SECURE_AREA: 64.0,
	MissionKind.COLLECT: 48.0,
	MissionKind.ESCORT_VAN: 48.0,
	MissionKind.DEFEND_TREE: 96.0,
	MissionKind.KILL_YOUR_COPY: 32.0,
}
const COLLECT_ITEM_CLEARANCE := 16.0

## Capture the Point ayarları. "Ekranın en fazla yarısını kaplamalı" (kullanıcı isteği) -
## Camera2D zoom=2.0 (bkz. player.tscn), tasarım çözünürlüğü 1920x1080 -> ekran yarı-yüksekliği
## dünya biriminde (1080/2)/2.0=270; payla birlikte bunun biraz altında tutuluyor.
const CAPTURE_RADIUS := 240.0
const CAPTURE_FILL_TIME_SOLO := 45.0
const CAPTURE_FILL_TIME_MIN := 12.0
const CAPTURE_TIMEOUT := 150.0
const CAPTURE_REWARD_GOLD := 120

## Secure the Area (kullanıcı isteği: "~300 düşman, 3 dakika içinde").
const SECURE_RADIUS := 300.0
const SECURE_KILL_TARGET := 300
const SECURE_DURATION := 180.0
const SECURE_REWARD_GOLD := 200
## DÜZELTME (kullanıcı bildirimi 2026-09-24: "görevlerden çoğu çalışmıyor") - normal yaratık akışı 3
## dakikada 300 öldürmeye (1.7/sn) HİÇ yetmiyordu; bölgede oyuncu varken kenardan ek dalga doğar
## (bkz. enemy_spawner.gd spawn_mission_wave - yaratık tavanına uyar).
const SECURE_WAVE_INTERVAL := 1.0
const SECURE_WAVE_COUNT := 3
## Sürekli ilerleyen görevlerin (bayrak/konvoy/ağaç/kopya) ilerleme yayını her karede GÜVENİLİR bir RPC'ydi
## (60/sn) - çok oyunculuda güvenilir kanalı tıkayıp diğer RPC'leri geciktiriyordu; saniyede 10'a indirildi.
const PROGRESS_SYNC_INTERVAL := 0.1

## Collect (kullanıcı isteği: "singleplayer 25, coop'ta 25 + oyuncu başına +10").
const COLLECT_BASE_TARGET := 25
const COLLECT_PER_EXTRA_PLAYER := 10
const COLLECT_SPREAD_RADIUS := 500.0
const COLLECT_DURATION := 150.0
## Kullanıcı bildirimi (2026-09-24): "Toplama görevinde toplamamız gereken şeyler haritada görünmüyor, ... haritada
## rasgele yerlerde olması gerekiyor. ayrıca toplanması gereken miktardan %50 daha fazla şey üretmen gerek görev bitince
## veya başarısız olunca da hepsi kaybolmalı." - objeler artık tek bir merkezin 500 birim çevresine DEĞİL, haritanın
## tamamına rastgele (engelsiz) dağılır; hedefin bu katı kadar obje üretilir (hedefe ulaşınca görev biter, artanlar
## main.gd _on_world_event_completed'da silinir - başarı da başarısızlık da aynı yol). Konumlar minimapte noktalar
## olarak gösterilir (bkz. minimap.gd set_collect_dots), tek bir "görev merkezi" işareti yok (HIDDEN_LOCATION_KINDS).
const COLLECT_ITEM_RATIO := 1.5
const COLLECT_REWARD_GOLD := 150
const CollectItemScript := preload("res://scripts/mission_collect_item.gd")

## Escort the Van (kullanıcı isteği: küçük daire, yakın durunca ittir, uzaklaşınca %20 hızla
## geri kayar, gidiş hızı da çok hızlı olmasın, oyuncu sayısıyla biraz artabilir).
const ESCORT_PUSH_RADIUS := 130.0
const ESCORT_BASE_SPEED := 8.0 ## dünya birimi/sn - "çok hızlı olmasın"
const ESCORT_RETREAT_RATIO := 0.2 ## "%20si kadar"
const ESCORT_SPEED_PER_EXTRA_PLAYER := 0.15 ## "biraz hızı artabilir"
const ESCORT_MAX_SPEED_MULT := 1.6
## Kullanıcı isteği (2026-09-24): "arabayı götüreceğimiz yerler çok daha uzak olmalı görevler çok kolay ve hızlı
## bitiyor süreleri uzamalı" - eskiden 500-900 birimlik DÜZ bir çizgiydi (8 u/sn'de ~1-2 dk). Artık ROTA UZUNLUĞU
## (duvarları dolanan yol, bkz. _escort_route) 1600-2600 birim (~3.5-5.5 dk kesintisiz itme; geri kaymalarla daha uzun).
const ESCORT_MIN_DISTANCE := 1600.0
const ESCORT_MAX_DISTANCE := 2600.0
## Bulunan yol düz çizgiden en fazla bu kadar uzun olabilir (çok dolambaçlı, geri dönen rotalar elensin).
const ESCORT_MAX_DETOUR := 1.6
const EnemyPathingScript: GDScript = preload("res://scripts/enemy_pathing.gd")
const ESCORT_TIMEOUT_BUFFER := 2.6 ## süre = mesafe/hız * bu çarpan (geri kaymalara pay)
const ESCORT_REWARD_GOLD := 180
const VanScript := preload("res://scripts/mission_van.gd")

## Defend the Tree (kullanıcı isteği: can+kalkan, faz her 10sn, mavi ateş topu, yaratıklar
## ağaca odaklanır; "geçici bi ağaç yap sonra değiştiririz").
const TREE_NUM_PHASES := 5
const TREE_PHASE_DURATION := 10.0
const TREE_REWARD_GOLD := 220
const TreeScript := preload("res://scripts/mission_tree.gd")

## Kill Your Copy (kullanıcı isteği: %90 az hasar alır/verir, %20 yavaş, yetenek yok, renk
## tersine çevrilmiş, 5 dakika, öldürülmezse yok olur).
const COPY_LIFETIME := 300.0
const COPY_BASE_DAMAGE := 10.0 ## kaynağın damage_bonus'u okunamazsa: BASE_STATS "Hasar:10" ile aynı taban (bkz. lobby_menu.gd)
const COPY_REWARD_GOLD := 250
const CopyScript := preload("res://scripts/mission_player_copy.gd")

var _next_mission_id: int = 1
## Her biri null ya da bir Dictionary.
var _slots: Array = [null, null]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in range(SLOT_COUNT):
		var first: float = _rng.randf_range(INITIAL_DELAY_MIN, INITIAL_DELAY_MAX)
		if i > 0:
			first += _rng.randf_range(COOLDOWN_MIN, COOLDOWN_MAX)
		_slots[i] = {"state": "cooldown", "timer": first}
	GameManager.enemy_died.connect(_on_enemy_died)
	NetworkManager.world_event_item_collected.connect(_on_item_collected)


func _process(delta: float) -> void:
	if GameManager.is_game_over:
		return
	## bkz. enemy_spawner.gd'nin AYNI satırı - host-authoritative desen.
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return
	for i in range(SLOT_COUNT):
		_process_slot(i, delta)


func _process_slot(slot_i: int, delta: float) -> void:
	var slot: Dictionary = _slots[slot_i]
	match slot.get("state"):
		"cooldown":
			slot["timer"] -= delta
			if slot["timer"] <= 0.0:
				_begin_warning(slot_i)
		"warning":
			slot["timer"] -= delta
			if slot["timer"] <= 0.0:
				_activate_mission(slot_i)
		"active":
			_tick_mission(slot_i, delta)


func _available_kinds() -> Array:
	return [MissionKind.CAPTURE_POINT, MissionKind.SECURE_AREA, MissionKind.COLLECT,
		MissionKind.ESCORT_VAN, MissionKind.DEFEND_TREE, MissionKind.KILL_YOUR_COPY]


## Debug menüsü (bkz. debug_menu.gd) - "istediğimiz görevi başlattırma" isteği. _begin_warning'in
## AYNI kurulum adımlarını izler (rastgele kind seçimi HARİÇ - burada kind DIŞARIDAN verilir) ama
## WARN_SECONDS'lık bekleme YOK, sonraki tek _process tikinde (timer<=0) doğrudan aktifleşir -
## debug amaçlı, oyuncuyu 1 dakika bekletmenin anlamı yok. Boş (cooldown'da) bir slot varsa onu
## kullanır, yoksa slot 0'ı ZORLA devralır (üstündeki görev varsa sessizce iptal edilmiş sayılır -
## debug aracı için kabul edilebilir). Host-authoritative (bkz. debug_spawn_creature'daki AYNI not).
func debug_force_start_mission(kind_name: String, pos_override: Vector2 = Vector2.ZERO) -> bool:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return false
	var kind: Variant = null
	for k in MISSION_KIND_NAMES.keys():
		if MISSION_KIND_NAMES[k] == kind_name:
			kind = k
			break
	if kind == null:
		return false
	var pos: Vector2 = pos_override if pos_override != Vector2.ZERO else _random_map_position(float(SPAWN_CLEARANCE.get(kind, 48.0)))
	if pos == Vector2.ZERO:
		return false
	var radius: float = CAPTURE_RADIUS
	match kind:
		MissionKind.SECURE_AREA:
			radius = SECURE_RADIUS
		MissionKind.COLLECT:
			radius = COLLECT_SPREAD_RADIUS
		MissionKind.ESCORT_VAN:
			radius = ESCORT_PUSH_RADIUS
		MissionKind.DEFEND_TREE:
			radius = 260.0
		MissionKind.KILL_YOUR_COPY:
			radius = 0.0
	var slot_i := 0
	for i in range(SLOT_COUNT):
		if _slots[i].get("state") == "cooldown":
			slot_i = i
			break
	var id: int = _next_mission_id
	_next_mission_id += 1
	_slots[slot_i] = {
		"id": id, "kind": kind, "state": "warning", "timer": 0.0,
		"pos": pos, "radius": radius, "progress": 0.0, "target": 1.0,
	}
	if not HIDDEN_LOCATION_KINDS.has(kind):
		NetworkManager.broadcast_world_event_announced.rpc(id, kind_name, pos, radius, 0.0, MISSION_LABELS[kind])
	else:
		NetworkManager.broadcast_world_event_announced.rpc(id, kind_name, Vector2.ZERO, 0.0, 0.0, MISSION_LABELS[kind])
	return true


func _begin_warning(slot_i: int) -> void:
	## bkz. SECOND_CONCURRENT_MISSION_CHANCE - diğer slotta süren görev varsa nadiren başla, türünü tekrarlama.
	var busy_kinds: Array = []
	for i in range(SLOT_COUNT):
		if i != slot_i and _slots[i].get("state") in ["warning", "active"]:
			busy_kinds.append(_slots[i].get("kind"))
	if not busy_kinds.is_empty() and _rng.randf() >= SECOND_CONCURRENT_MISSION_CHANCE:
		_slots[slot_i] = {"state": "cooldown", "timer": _rng.randf_range(COOLDOWN_MIN, COOLDOWN_MAX)}
		return
	var kinds: Array = _available_kinds().filter(func(k): return not busy_kinds.has(k))
	if kinds.is_empty():
		_slots[slot_i] = {"state": "cooldown", "timer": _rng.randf_range(COOLDOWN_MIN, COOLDOWN_MAX)}
		return
	var kind: MissionKind = kinds[_rng.randi() % kinds.size()]
	var pos: Vector2 = _random_map_position(float(SPAWN_CLEARANCE.get(kind, 48.0)))
	if pos == Vector2.ZERO:
		_slots[slot_i] = {"state": "cooldown", "timer": 5.0}
		return
	var radius: float = CAPTURE_RADIUS
	match kind:
		MissionKind.SECURE_AREA:
			radius = SECURE_RADIUS
		MissionKind.COLLECT:
			radius = COLLECT_SPREAD_RADIUS
		MissionKind.ESCORT_VAN:
			radius = ESCORT_PUSH_RADIUS
		MissionKind.DEFEND_TREE:
			radius = 260.0
		MissionKind.KILL_YOUR_COPY:
			radius = 0.0
	var id: int = _next_mission_id
	_next_mission_id += 1
	_slots[slot_i] = {
		"id": id, "kind": kind, "state": "warning", "timer": WARN_SECONDS,
		"pos": pos, "radius": radius, "progress": 0.0, "target": 1.0,
	}
	if not HIDDEN_LOCATION_KINDS.has(kind):
		NetworkManager.broadcast_world_event_announced.rpc(id, MISSION_KIND_NAMES[kind], pos, radius, WARN_SECONDS, MISSION_LABELS[kind])
	else:
		NetworkManager.broadcast_world_event_announced.rpc(id, MISSION_KIND_NAMES[kind], Vector2.ZERO, 0.0, WARN_SECONDS, MISSION_LABELS[kind])


func _activate_mission(slot_i: int) -> void:
	var slot: Dictionary = _slots[slot_i]
	slot["state"] = "active"
	var extra: Dictionary = {}
	var player_count: int = _player_count()
	match slot["kind"]:
		MissionKind.CAPTURE_POINT:
			slot["timer"] = CAPTURE_TIMEOUT
			slot["target"] = 1.0
		MissionKind.SECURE_AREA:
			slot["timer"] = SECURE_DURATION
			slot["target"] = float(SECURE_KILL_TARGET)
			extra["kill_target"] = SECURE_KILL_TARGET
		MissionKind.COLLECT:
			var target: int = COLLECT_BASE_TARGET + COLLECT_PER_EXTRA_PLAYER * max(0, player_count - 1)
			var items: PackedVector2Array = _map_scatter_positions(int(ceil(float(target) * COLLECT_ITEM_RATIO)))
			slot["timer"] = COLLECT_DURATION
			## Hedef = toplanması GEREKEN sayı (üretilen objelerin 1/1.5'i); obje az bulunduysa (dar harita) hedef
			## hiçbir zaman üretilen sayıyı aşmasın.
			slot["target"] = float(mini(target, items.size()))
			slot["items_total"] = int(slot["target"])
			slot["collected_set"] = {}
			extra["items"] = items
			extra["collect_target"] = int(slot["target"])
		MissionKind.ESCORT_VAN:
			var start_pos: Vector2 = slot["pos"]
			var route: PackedVector2Array = _escort_route(start_pos)
			var end_pos: Vector2 = route[route.size() - 1]
			var dist: float = VanScript.path_length(route)
			slot["start_pos"] = start_pos
			slot["end_pos"] = end_pos
			slot["route"] = route
			slot["distance"] = dist
			slot["timer"] = (dist / ESCORT_BASE_SPEED) * ESCORT_TIMEOUT_BUFFER
			slot["target"] = dist
			slot["progress"] = 0.0
			extra["start"] = start_pos
			extra["end"] = end_pos
			extra["route"] = route
			extra["push_radius"] = ESCORT_PUSH_RADIUS
		MissionKind.DEFEND_TREE:
			slot["timer"] = float(TREE_NUM_PHASES) * TREE_PHASE_DURATION
			slot["target"] = 1.0
			var tree: Node2D = TreeScript.new()
			get_tree().current_scene.add_child(tree)
			tree.global_position = slot["pos"]
			tree.setup(player_count, true)
			slot["tree"] = tree
			GameManager.defend_tree_active = true
			GameManager.defend_tree_ref = tree
			extra["max_health"] = tree.max_health
			extra["max_shield"] = tree.max_shield
		MissionKind.KILL_YOUR_COPY:
			slot["timer"] = COPY_LIFETIME
			var spawned: Dictionary = _spawn_copies(slot["id"])
			slot["copies"] = spawned["nodes"]
			slot["target"] = float(spawned["nodes"].size())
			## Konumları HARİTADA gösterilmiyor (kullanıcı isteği) ama istemcilerin kendi
			## kozmetik kopyalarını kurabilmesi için world_event_started ile (bkz. main.gd)
			## AYNI yayına biniyor - "gösterilmeme" sadece UI/harita işareti anlamına geliyor.
			extra["copies"] = spawned["meta"]
	_slots[slot_i] = slot
	NetworkManager.broadcast_world_event_started.rpc(slot["id"], MISSION_KIND_NAMES[slot["kind"]], slot.get("pos", Vector2.ZERO), slot["radius"], slot["timer"], extra)
	NetworkManager.broadcast_world_event_progress.rpc(slot["id"], slot["progress"], slot["target"])


func _tick_mission(slot_i: int, delta: float) -> void:
	var slot: Dictionary = _slots[slot_i]
	slot["timer"] -= delta
	var done := false
	var success := false
	match slot["kind"]:
		MissionKind.CAPTURE_POINT:
			var players_inside: int = _players_in_radius(slot["pos"], slot["radius"])
			if players_inside > 0:
				var fill_time: float = max(CAPTURE_FILL_TIME_MIN, CAPTURE_FILL_TIME_SOLO / float(players_inside))
				slot["progress"] = min(1.0, slot["progress"] + delta / fill_time)
				_sync_progress(slot, slot["progress"], 1.0)
				if slot["progress"] >= 1.0:
					done = true
					success = true
		MissionKind.SECURE_AREA:
			## İlerleme _on_enemy_died'dan geliyor.
			if _players_in_radius(slot["pos"], slot["radius"]) > 0:
				slot["wave_acc"] = float(slot.get("wave_acc", 0.0)) + delta
				if slot["wave_acc"] >= SECURE_WAVE_INTERVAL:
					slot["wave_acc"] = 0.0
					var spawner: Node = get_tree().current_scene.get_node_or_null("EnemySpawner")
					if spawner and spawner.has_method("spawn_mission_wave"):
						spawner.spawn_mission_wave(slot["pos"], slot["radius"] * 0.85, SECURE_WAVE_COUNT)
			if slot["progress"] >= float(SECURE_KILL_TARGET):
				done = true
				success = true
		MissionKind.COLLECT:
			if slot["progress"] >= float(slot["items_total"]):
				done = true
				success = true
		MissionKind.ESCORT_VAN:
			var pushers: int = _players_in_radius(_escort_current_pos(slot), ESCORT_PUSH_RADIUS)
			var speed: float = ESCORT_BASE_SPEED
			var pushed: bool = pushers > 0
			if pushed:
				speed *= min(ESCORT_MAX_SPEED_MULT, 1.0 + float(pushers - 1) * ESCORT_SPEED_PER_EXTRA_PLAYER)
				slot["progress"] = min(slot["distance"], slot["progress"] + speed * delta)
			else:
				## "Uzaklaşırsak daire geri döner yavaşça (gidiş hızının %20si kadar)".
				slot["progress"] = max(0.0, slot["progress"] - speed * ESCORT_RETREAT_RATIO * delta)
			_sync_progress(slot, slot["progress"], slot["distance"])
			if slot["progress"] >= slot["distance"]:
				done = true
				success = true
		MissionKind.DEFEND_TREE:
			var tree: Node2D = slot.get("tree")
			if tree == null or not is_instance_valid(tree) or tree.is_dead:
				done = true
				success = false
			else:
				_sync_progress(slot, tree.health + tree.shield, tree.max_health + tree.max_shield)
				if slot["timer"] <= 0.0:
					## Faz süresi (kullanıcı isteği: her 10sn'de bir faz, TREE_NUM_PHASES fazın
					## tamamı) bitene kadar ağaç hayattaysa görev BAŞARILI - normal "süre dolunca
					## başarısız" kuralının TERSİ, bu görevde süre = hayatta kalma hedefi.
					done = true
					success = true
		MissionKind.KILL_YOUR_COPY:
			var copies: Array = slot.get("copies", [])
			var alive := 0
			for c in copies:
				if is_instance_valid(c) and not c.is_dead:
					alive += 1
			_sync_progress(slot, float(copies.size() - alive), float(copies.size()))
			if alive == 0:
				done = true
				success = true
	## DEFEND_TREE kendi başarı/başarısızlık kuralını yukarıda zaten uyguladı (süre = hedef,
	## tersine çevrilmiş) - normal "süre dolunca başarısız" kuralı SADECE diğer türlerde geçerli.
	if not done and slot["timer"] <= 0.0 and slot["kind"] != MissionKind.DEFEND_TREE:
		done = true
		success = false
	if done:
		_end_mission(slot_i, success)
		return
	_slots[slot_i] = slot


## bkz. PROGRESS_SYNC_INTERVAL - sürekli ilerleyen görevlerde yayını seyrelt (son değer bir sonraki
## yayında zaten gider; bitişte _end_mission'ın completed yayını durumu kesinleştirir).
func _sync_progress(slot: Dictionary, value: float, target: float) -> void:
	if NetworkManager.should_throttle("wev_progress_%d" % int(slot["id"]), PROGRESS_SYNC_INTERVAL):
		return
	NetworkManager.broadcast_world_event_progress.rpc(slot["id"], value, target)


func _end_mission(slot_i: int, success: bool) -> void:
	var slot: Dictionary = _slots[slot_i]
	var reward_pos: Vector2 = slot.get("pos", Vector2.ZERO)
	var reward_radius: float = slot.get("radius", 99999.0)
	if success:
		var reward: int = CAPTURE_REWARD_GOLD
		match slot["kind"]:
			MissionKind.SECURE_AREA:
				reward = SECURE_REWARD_GOLD
			MissionKind.COLLECT:
				reward = COLLECT_REWARD_GOLD
				reward_radius = 999999.0 ## dağınık toplama - takım hep birlikte ödüllenir
			MissionKind.ESCORT_VAN:
				reward = ESCORT_REWARD_GOLD
				reward_pos = slot.get("end_pos", reward_pos)
				reward_radius = ESCORT_PUSH_RADIUS * 2.0
			MissionKind.DEFEND_TREE:
				reward = TREE_REWARD_GOLD
			MissionKind.KILL_YOUR_COPY:
				reward = COPY_REWARD_GOLD
				reward_radius = 999999.0 ## kopyalar dağınık yerlerde - takım hep birlikte ödüllenir
		_grant_reward_to_zone_players(reward_pos, reward_radius, reward)
		_grant_chest_to_all_players()
	## Temizlik (bkz. ilgili mission_*.gd notları).
	match slot["kind"]:
		MissionKind.DEFEND_TREE:
			GameManager.defend_tree_active = false
			GameManager.defend_tree_ref = null
			var tree: Node2D = slot.get("tree")
			if is_instance_valid(tree):
				tree.queue_free()
		MissionKind.KILL_YOUR_COPY:
			for c in slot.get("copies", []):
				if is_instance_valid(c):
					c.queue_free()
	NetworkManager.broadcast_world_event_completed.rpc(slot["id"], MISSION_KIND_NAMES[slot["kind"]], success)
	_slots[slot_i] = {"state": "cooldown", "timer": _rng.randf_range(COOLDOWN_MIN, COOLDOWN_MAX)}


func _on_enemy_died(death_pos: Vector2) -> void:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return
	for i in range(SLOT_COUNT):
		var slot: Dictionary = _slots[i]
		if slot.get("state") != "active" or slot.get("kind") != MissionKind.SECURE_AREA:
			continue
		if death_pos.distance_to(slot["pos"]) > slot["radius"]:
			continue
		slot["progress"] = min(float(SECURE_KILL_TARGET), slot["progress"] + 1.0)
		_slots[i] = slot
		NetworkManager.broadcast_world_event_progress.rpc(slot["id"], slot["progress"], float(SECURE_KILL_TARGET))


## Topla: herhangi bir istemcinin KENDİ yerel oyuncusu bir objeye dokununca bu RPC ile buraya
## ulaşır (bkz. mission_collect_item.gd/network_manager.gd notu) - host ilerlemeyi artırır.
func _on_item_collected(mission_id: int, item_index: int) -> void:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return
	for i in range(SLOT_COUNT):
		var slot: Dictionary = _slots[i]
		if slot.get("state") != "active" or slot.get("kind") != MissionKind.COLLECT or slot.get("id") != mission_id:
			continue
		var collected: Dictionary = slot.get("collected_set", {})
		if collected.has(item_index):
			return ## zaten sayılmış (ör. gecikmeli çift RPC) - bir kez say
		collected[item_index] = true
		slot["collected_set"] = collected
		slot["progress"] = float(collected.size())
		_slots[i] = slot
		NetworkManager.broadcast_world_event_progress.rpc(slot["id"], slot["progress"], float(slot["items_total"]))
		return


func _players_in_radius(pos: Vector2, radius: float) -> int:
	var n := 0
	for group_name in ["player", "remote_players"]:
		for p: Node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(p) and p.get("is_dead") != true and (p as Node2D).global_position.distance_to(pos) <= radius:
				n += 1
	return n


func _grant_reward_to_zone_players(pos: Vector2, radius: float, gold: int) -> void:
	var any_player: Node = get_tree().get_first_node_in_group("player")
	for group_name in ["player", "remote_players"]:
		for p: Node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(p) or (p as Node2D).global_position.distance_to(pos) > radius:
				continue
			var peer_id: int = int(p.get("peer_id")) if "peer_id" in p else 0
			if p == any_player or peer_id == 0 or peer_id == multiplayer.get_unique_id():
				GameManager.gold += gold
				var ft_scene: PackedScene = load("res://scenes/floating_text.tscn") as PackedScene
				if ft_scene and is_instance_valid(any_player):
					var ft: Node = ft_scene.instantiate()
					get_tree().current_scene.add_child(ft)
					ft.global_position = any_player.global_position + Vector2(14, -34)
					if ft.has_method("setup"):
						ft.setup("+%d altın (görev)" % gold, Color(1.0, 0.85, 0.25))
			else:
				NetworkManager.grant_personal_gold.rpc_id(peer_id, gold)


## bkz. yukarıdaki görev sandığı notu. Host kendi kuyruğuna ekler, uzak oyunculara open_elite_chest_for_peer (elit
## sandık paylaşımıyla AYNI RPC, bkz. NetworkManager.host_award_elite_chest).
func _grant_chest_to_all_players() -> void:
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	for p: Dictionary in NetworkManager.get_reward_participants():
		var peer_id: int = int(p["peer_id"])
		if not NetworkManager.is_multiplayer_active or peer_id == local_id:
			GameManager.add_pending_elite_chest()
			var node: Node = p["node"]
			var ft_scene: PackedScene = load("res://scenes/floating_text.tscn") as PackedScene
			if ft_scene and is_instance_valid(node) and node is Node2D:
				var ft: Node = ft_scene.instantiate()
				get_tree().current_scene.add_child(ft)
				ft.global_position = (node as Node2D).global_position + Vector2(-14, -52)
				if ft.has_method("setup"):
					ft.setup("+1 Elit Sandık (görev)", Color(0.85, 0.6, 1.0))
		else:
			NetworkManager.open_elite_chest_for_peer.rpc_id(peer_id)


func _player_count() -> int:
	return 1 + get_tree().get_nodes_in_group("remote_players").size()


func _random_map_position(clearance: float = 48.0) -> Vector2:
	var rect: Rect2 = GameManager.get_map_world_rect()
	if rect.size == Vector2.ZERO:
		return Vector2.ZERO
	var margin := 200.0
	for _attempt in range(80):
		var pos := Vector2(
			_rng.randf_range(rect.position.x + margin, rect.position.x + rect.size.x - margin),
			_rng.randf_range(rect.position.y + margin, rect.position.y + rect.size.y - margin))
		if not _is_area_clear(pos, clearance):
			continue
		return pos
	return Vector2.ZERO


## pos merkezli, clearance yarıçaplı dairenin içinde HİÇBİR engel yoksa true: (1) su/ev/orman karoları
## (GameManager.is_position_blocked_by_terrain - oyuncu/yaratık engelleriyle AYNI kaynak) CLEARANCE_SAMPLE_STEP
## aralıklı bir ızgarayla, (2) fizik dünyasındaki gerçek StaticBody2D çarpışma şekilleri (ör. ev içi duvarlar,
## ileride haritaya eklenecek engeller) tek bir daire sorgusuyla. Yaratıklar/oyuncular/Area2D'ler SAYILMAZ.
func _is_area_clear(pos: Vector2, clearance: float) -> bool:
	if GameManager.is_position_blocked_by_terrain(pos):
		return false
	var steps: int = int(ceil(clearance / CLEARANCE_SAMPLE_STEP))
	for ix in range(-steps, steps + 1):
		for iy in range(-steps, steps + 1):
			var off := Vector2(ix, iy) * CLEARANCE_SAMPLE_STEP
			if off.length() > clearance:
				continue
			if GameManager.is_position_blocked_by_terrain(pos + off):
				return false
	## Fizik sorgusu SADECE fizik adımında yapılabilir (Godot, _process'ten direct_space_state sorgusuna "Space state is
	## inaccessible right now" hatası verir - görev zamanlayıcısı _process'te çalışıyor). Açık haritada StaticBody2D engeli
	## yok (engeller karo katmanı, yukarıda kontrol edildi); bu ek kontrol sadece fizik adımından çağrıldığında devreye girer.
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state if (is_inside_tree() and Engine.is_in_physics_frame()) else null
	if space != null and clearance > 0.0:
		var circle := CircleShape2D.new()
		circle.radius = clearance
		var params := PhysicsShapeQueryParameters2D.new()
		params.shape = circle
		params.transform = Transform2D(0.0, pos)
		params.collide_with_areas = false
		params.collide_with_bodies = true
		for hit: Dictionary in space.intersect_shape(params, 16):
			if hit.get("collider") is StaticBody2D:
				return false
	return true


## Konvoy düz bir çizgide a -> b ilerler (bkz. _escort_current_pos) - yolun HER noktası (konvoy gövdesi
## genişliğinde) boş olmalı, yoksa konvoy duvarın/suyun içinden geçerdi.
func _is_path_clear(a: Vector2, b: Vector2, clearance: float) -> bool:
	var length: float = a.distance_to(b)
	var n: int = maxi(1, int(ceil(length / CLEARANCE_SAMPLE_STEP)))
	var dir: Vector2 = (b - a) / maxf(length, 0.001)
	var side: Vector2 = dir.orthogonal()
	for i in range(n + 1):
		var p: Vector2 = a.lerp(b, float(i) / float(n))
		for k in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			if GameManager.is_position_blocked_by_terrain(p + side * clearance * k):
				return false
	return _is_area_clear(b, clearance)


## Topla: haritanın tamamına dağılmış 'count' adet engelsiz nokta (bkz. COLLECT_ITEM_RATIO üstündeki not). Birbirine
## çok yakın düşmesinler diye aralarında en az COLLECT_MIN_SPACING bırakılır (bulunamazsa gevşetilir).
const COLLECT_MIN_SPACING := 160.0

func _map_scatter_positions(count: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var spacing: float = COLLECT_MIN_SPACING
	var tries := 0
	while out.size() < count and tries < count * 80:
		tries += 1
		if tries % (count * 10) == 0:
			spacing *= 0.5 ## harita dolduysa aralığı gevşet
		var pos: Vector2 = _random_map_position(COLLECT_ITEM_CLEARANCE)
		if pos == Vector2.ZERO:
			continue
		var ok := true
		for q in out:
			if q.distance_to(pos) < spacing:
				ok = false
				break
		if ok:
			out.append(pos)
	return out


## (Eski) center etrafında (COLLECT_SPREAD_RADIUS içinde) 'count' adet engelsiz nokta - artık Topla kullanmıyor.
func _scatter_positions(center: Vector2, radius: float, count: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var tries := 0
	while out.size() < count and tries < count * 12:
		tries += 1
		var ang: float = _rng.randf() * TAU
		var dist: float = sqrt(_rng.randf()) * radius ## alan içinde EŞİT dağılım (sqrt düzeltmesi)
		var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * dist
		if not _is_area_clear(pos, COLLECT_ITEM_CLEARANCE):
			continue
		out.append(pos)
	return out


## Escort the Van rotası: [başlangıç, dönüş noktaları..., bitiş]. Haritada engelsiz rastgele bir bitiş seçilir,
## yaratıkların A*'ı (enemy_pathing.gd - orman duvarlarını dolanır) ile yol bulunur; yol uzunluğu ESCORT_MIN/MAX_DISTANCE
## aralığında, düz çizgiye göre en fazla ESCORT_MAX_DETOUR kat uzun ve her parçası su/ev/orman'dan açık olmalı.
## ÖLÇÜM (2026-09-24, iki süreçli test + gerçek harita 4096x4096 üzerinde 30 başlangıç x 14 deneme): A* ızgarası SADECE
## ormanı bilir - yollar suyu/evleri kesebiliyor ve köşelerde ormana sıfır mesafeden geçiyor; eskiden her parçada
## "genişliğin yarısı" payı istenince 30 başlangıcın 0'ında rota bulunuyor, görev HEP eski 500-900'lük düz çizgiye
## düşüyordu. Artık önce geniş paylı (ESCORT_ROUTE_WIDE_CLEARANCE) bir rota aranır; yoksa o turda bulunan ilk "merkez
## çizgisi açık" (su/ev/orman'a hiç girmeyen) rota kullanılır (ölçüm: 26/30 başlangıçta rota). Bulunamazsa uzunluk alt
## sınırı kademeli gevşetilir; en son eski düz çizgi yedeğine düşülür.
const ESCORT_ROUTE_ATTEMPTS := 20
const ESCORT_ROUTE_WIDE_CLEARANCE := 12.0

func _escort_route(start_pos: Vector2) -> PackedVector2Array:
	var clearance: float = float(SPAWN_CLEARANCE[MissionKind.ESCORT_VAN])
	for min_len: float in [ESCORT_MIN_DISTANCE, ESCORT_MIN_DISTANCE * 0.7, ESCORT_MIN_DISTANCE * 0.45]:
		var narrow_route := PackedVector2Array()
		for _attempt in range(ESCORT_ROUTE_ATTEMPTS):
			var end_pos: Vector2 = _random_map_position(clearance)
			if end_pos == Vector2.ZERO:
				continue
			var straight: float = start_pos.distance_to(end_pos)
			if straight < min_len * 0.85 or straight > ESCORT_MAX_DISTANCE:
				continue
			var route := PackedVector2Array([start_pos])
			if EnemyPathingScript.line_blocked(start_pos, end_pos):
				var waypoints: PackedVector2Array = EnemyPathingScript.find_path(start_pos, end_pos)
				if waypoints.is_empty():
					continue
				route.append_array(waypoints)
			else:
				route.append(end_pos)
			var length: float = VanScript.path_length(route)
			if length < min_len or length > ESCORT_MAX_DISTANCE * 1.2:
				continue
			if length > start_pos.distance_to(route[route.size() - 1]) * ESCORT_MAX_DETOUR:
				continue
			if _route_clear(route, ESCORT_ROUTE_WIDE_CLEARANCE):
				return route
			if narrow_route.is_empty() and _route_clear(route, 0.0):
				narrow_route = route
		if not narrow_route.is_empty():
			return narrow_route
	return PackedVector2Array([start_pos, _escort_end_position(start_pos)])


func _route_clear(route: PackedVector2Array, clearance: float) -> bool:
	for i in range(route.size() - 1):
		if not _is_path_clear(route[i], route[i + 1], clearance):
			return false
	return true


## Eski düz çizgi yedeği (bkz. _escort_route): başlangıçtan 500-900 arası engelsiz bir bitiş noktası.
func _escort_end_position(start_pos: Vector2) -> Vector2:
	var rect: Rect2 = GameManager.get_map_world_rect()
	for min_dist: float in [500.0, 300.0, 150.0]:
		for _attempt in range(16):
			var ang: float = _rng.randf() * TAU
			var dist: float = _rng.randf_range(min_dist, 900.0)
			var pos: Vector2 = start_pos + Vector2(cos(ang), sin(ang)) * dist
			if rect.size != Vector2.ZERO and not rect.grow(-150.0).has_point(pos):
				continue
			if not _is_path_clear(start_pos, pos, float(SPAWN_CLEARANCE[MissionKind.ESCORT_VAN])):
				continue
			return pos
	return start_pos + Vector2(500.0, 0.0) ## son çare - engellenmiş olsa bile ilerlemeyi durdurmasın


## Arabanın şu anki konumu - istemcilerin çizimiyle AYNI fonksiyon (mission_van.gd point_on_path).
func _escort_current_pos(slot: Dictionary) -> Vector2:
	return VanScript.point_on_path(slot["route"], float(slot["progress"]))


## Kill Your Copy: her canlı oyuncu için (yerel "player" + "remote_players") kendi karakterinin
## rastgele bir konumdaki, renk tersine çevrilmiş, zayıflatılmış bir kopyası (bkz.
## mission_player_copy.gd dosya başı notu).
## Döner: {"nodes": Array[CharacterBody2D] (bu istemcinin GERÇEK, simüle edilen kopyaları),
## "meta": Array[Dictionary] ("char_id"/"pos", client'ların kendi kozmetik kopyalarını
## kurması için world_event_started.extra["copies"]'e konur - bkz. dosya başı not)}.
## Kopyanın taşıyacağı silahlar (kullanıcı isteği 2026-09-24: "tıpkı benim gibi silahları olmalı"): yerel oyuncu için
## kalıcı envanter (GameManager.owned_weapons - Talon Ayna Formu'nun geçici kopyaları dahil DEĞİL), uzak oyuncu için
## kuklasının zaten senkron tuttuğu anahtar listesi (remote_player.gd _weapon_keys).
func _copy_weapon_keys_of(p: Node) -> Array:
	var keys: Array = []
	if p.is_in_group("player"):
		for entry in GameManager.owned_weapons:
			keys.append(str(entry.get("key", "")))
	elif "_weapon_keys" in p:
		for k in p.get("_weapon_keys"):
			keys.append(str(k))
	return keys


func _spawn_copies(mission_id: int) -> Dictionary:
	var copies: Array = []
	var meta: Array = []
	var idx := 0
	for group_name in ["player", "remote_players"]:
		for p: Node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(p) or p.get("is_dead") == true:
				continue
			var pos: Vector2 = _random_map_position(float(SPAWN_CLEARANCE[MissionKind.KILL_YOUR_COPY]))
			if pos == Vector2.ZERO:
				continue
			var char_id: int = int(p.get("char_id")) if "char_id" in p else int(GameManager.selected_char_id)
			## Gerçek (bonuslu) yürüme hızı - bkz. player.gd/remote_player.gd get_effective_move_speed. Kopya ayrıca
			## source_player üzerinden bunu her karede yeniden okur (hız buff'ları anında yansısın).
			## Kalıcı hız (yetenek buff'ları hariç - bkz. mission_player_copy.gd hız notu).
			var spd: float = float(p.call("get_base_move_speed")) if p.has_method("get_base_move_speed") else Characters.BASE_MOVE_SPEED
			var maxhp_v: Variant = p.get("max_health")
			var maxhp: float = float(maxhp_v) if maxhp_v != null else 100.0
			## Kalkan (kullanıcı isteği 2026-09-24: "kopyanın kalkanı yok") - yerel Player ve RemotePlayer'da aynı alan adı.
			var maxsh_v: Variant = p.get("item_shield_max")
			var maxsh: float = float(maxsh_v) if maxsh_v != null else 0.0
			var dmg_v: Variant = p.get("damage_bonus")
			var dmg: float = float(dmg_v) if dmg_v != null else COPY_BASE_DAMAGE
			var copy: CharacterBody2D = CopyScript.new()
			get_tree().current_scene.add_child(copy)
			copy.global_position = pos
			copy.setup(mission_id, idx, char_id, maxhp, maxsh, spd, dmg, true)
			copy.set("source_player", p)
			var weapon_keys: Array = _copy_weapon_keys_of(p)
			copy.set_weapon_keys(weapon_keys)
			copies.append(copy)
			meta.append({"char_id": char_id, "pos": pos, "weapons": weapon_keys, "max_hp": maxhp, "max_shield": maxsh})
			idx += 1
	return {"nodes": copies, "meta": meta}
