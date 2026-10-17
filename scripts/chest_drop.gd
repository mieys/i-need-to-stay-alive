extends Area2D

## Yerdeki sandık. Kullanıcı isteği (2026-09-25): "elite sandıklar ve normal sandıklar olarak 2 ayrım oluştur - elitler
## bosslardan ve güçlü yaratıklardan nadiren düşsün, normal sandıklar yaratıklardan rasgele düşsün" + "normal sandıklar tek
## oyuncuya gider elit sandıklar ise paylaşılır". 2026-10-07: "elit sandıklardan sadece epik item çıkacak çünkü efsunları
## kaldırmıştık" + "normal sandıklar sırayla oyunculara verilecek (alan kişi sıradaki değilse sandık grup penceresinden
## sıradakinin barına gidecek), elit sandıklar herkese eşit dağıtılacak". Normal: SIRADAKİ oyuncuya
## (NetworkManager.host_award_chest / next_chest_turn), açılınca parça kartı (chest_menu.gd). Elit: HER yaşayan oyuncuya bir
## elit sandık (NetworkManager.host_award_elite_chest), açılınca epik eşya kartı (main.gd _show_elite_chest, chest_menu.gd
## elit mod). Düşme kuralları enemy.gd _drop_chest'te.
##
## Görsel (2026-10-17, madde 242 "B Işık Sütunu"): sandık sayfası + arkasında ayrı ışık sütunu sayfası, ikisi de chest_art.gd'den
## (0,5 dünya px/piksel). Sandık 0-3 bekleme, toplanınca 4-12 (sallanma + kapak patlaması); sütun 0-23 döngü, açılışta sallanır
## ve sandığa çöker. Lost Ark/Diablo ganimeti gibi sandık YERDE DURUR (eski süzülme kalktı); gölgesi yerde.

const ChestArt := preload("res://scripts/chest_art.gd")
const NORMAL_SHEET := ChestArt.NORMAL_SHEET
const DropShadowScript := preload("res://scripts/drop_shadow.gd")
const ELITE_SHEET := ChestArt.ELITE_SHEET
const SHADOW_TEX := preload("res://assets/sprites/chests/chest_shadow.png")
const FRAME_COUNT := ChestArt.FRAME_COUNT
## Karede sandığın alt kenarı y=42 dünya px (48'lik kare, ortalı sprite'ta +18): sprite -10'a kayınca taban kökün 8 px altında.
const SPRITE_Y := -10.0
const SHADOW_Y := 8.0
const OPEN_FRAMES := [4, 5, 6, 7, 8, 9, 10, 11, 12]
const OPEN_FRAME_TIME := 0.05
## Normal sandık çoğu zaman durur, arada bir asma kilidinde parıltı çakar; elit sandığın mor taşı nabız atar.
const NORMAL_GLINT_EVERY := 2.4
const ELITE_IDLE_STEP := 0.3

## "KADEME" - hangi dünya evresinden düştü (sandık menüsünün başlığı, bkz. chest_menu.gd CHEST_TITLES). Görsele etkisi yok.
@export var chest_tier: int = 0
## Elit sandık (epik eşya, herkese). Ağ kopyası için broadcast_drop "elite_chest" türü bunu add_child'dan önce kurar.
@export var is_elite: bool = false:
	set(val):
		is_elite = val
		if is_inside_tree():
			_update_visual()

## Gece ışığının rengi (night_glow_catalog.gd "cp", madde 243): ışık sütununun rengi.
var night_glow_color: Color:
	get:
		return Color(0.86, 0.64, 1.0) if is_elite else Color(1.0, 0.8, 0.45) ## elit: koyu mor gece zemininde sönük kalıyordu -> açık mor
var bob_time: float = 0.0
var sprite: Sprite2D = null
var _shadow: Sprite2D = null
var _beam: Sprite2D = null ## ışık sütunu + yer halkası (sandığın arkasında)
var _idle_t: float = 0.0

func _ready() -> void:
	add_to_group("chest_drops")
	body_entered.connect(_on_body_entered)
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
	bob_time = randf() * TAU
	_idle_t = randf() * NORMAL_GLINT_EVERY
	_update_visual()
	## Gölge (2026-10-02, harita gölgeleriyle aynı "B" dili - bkz. drop_shadow.gd): sprite dinlenme konumundayken ölçülür,
	## sonra sadece sprite zıpladığı için gölge yerde kalır.
	DropShadowScript.attach(self, sprite, false, 3, Rect2(), true)


func _update_visual() -> void:
	var s: Sprite2D = sprite if sprite else get_node_or_null("Sprite2D") as Sprite2D
	if s == null:
		return
	s.texture = ELITE_SHEET if is_elite else NORMAL_SHEET
	s.hframes = FRAME_COUNT
	s.vframes = 1
	s.frame = 0
	s.scale = Vector2.ONE * ChestArt.TEXEL
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = Vector2(0.0, SPRITE_Y)
	if _shadow == null:
		_shadow = Sprite2D.new()
		_shadow.name = "Shadow"
		_shadow.texture = SHADOW_TEX
		_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_shadow.position = Vector2(0.0, SHADOW_Y)
		add_child(_shadow)
		move_child(_shadow, 0)
	if _beam == null:
		_beam = Sprite2D.new()
		_beam.name = "Beam"
		_beam.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_beam.hframes = ChestArt.BEAM_FRAMES
		_beam.scale = Vector2.ONE * ChestArt.TEXEL
		add_child(_beam)
		move_child(_beam, s.get_index()) ## sandığın hemen arkası (gölgelerin önü)
	_beam.texture = ChestArt.ELITE_BEAM_SHEET if is_elite else ChestArt.BEAM_SHEET
	_beam.position = s.position + ChestArt.BEAM_OFFSET_PX * ChestArt.TEXEL
	_beam.frame = 0
	_beam.visible = true


func _process(delta: float) -> void:
	if sprite == null or _is_opening:
		return
	_idle_t += delta
	if _beam != null:
		_beam.frame = int(_idle_t / ChestArt.BEAM_IDLE_STEP) % ChestArt.BEAM_IDLE
	if is_elite:
		sprite.frame = int(_idle_t / ELITE_IDLE_STEP) % 4
	else:
		## Döngü sonunda 2 kare parıltı (2, 3), gerisi düz kapalı sandık.
		var t: float = fmod(_idle_t, NORMAL_GLINT_EVERY)
		sprite.frame = 2 if t > NORMAL_GLINT_EVERY - 0.16 and t <= NORMAL_GLINT_EVERY - 0.08 else 3 if t > NORMAL_GLINT_EVERY - 0.08 else 0

var _is_opening: bool = false
## ÇİFT AÇILIŞ DÜZELTMESİ (2026-10-12, kullanıcı: "arkadaşımla aynı elit sandığı aldık, 2 sandık açıldı"): sandığın iki giriş yolu vardı -
## host'un kendi fiziksel teması (_on_body_entered, _is_opening'i işaretler) ve bir istemcinin RPC'si (request_drop_pickup ->
## _open_for_player, "claimed" işaretler) - ikisi birbirinin işaretini görmüyordu. Host ile bir istemci aynı anda alınca ödül İKİ KEZ
## dağıtılıyordu (elitte herkese 2 sandık). Artık ödül dağıtımı TEK kapıdan geçer: _open_for_player ilk çağrıda _awarded'ı kurar,
## sonrakiler (temas ya da RPC, hangi sırayla gelirse gelsin) hiçbir şey yapmaz.
var _awarded: bool = false

func _on_body_entered(body: Node) -> void:
	if _is_opening or _awarded or not is_instance_valid(body):
		return
	if not (body.is_in_group("player") or body.is_in_group("remote_players")):
		return

	## Multiplayer: client tarafındaki görsel kopya → host'a sandık açma isteği gönder
	if NetworkManager.is_multiplayer_active and get_meta("network_spawned", false):
		# Client tarafındaki GÖRSEL KOPYA: sadece bu istemcinin KENDİ yerel
		# oyuncusu tetiklesin (bkz. xp_orb.gd aynı notu).
		if not body.is_in_group("player"):
			return
		var drop_id: int = int(get_meta("drop_network_id", 0))
		if drop_id > 0:
			## Verimlilik notu (derin multiplayer denetimi bulgusu) - bkz.
			## gold_drop.gd aynı DÜZELTME notu: broadcast yerine host'a hedefli.
			## Elit mi normal mi host'taki GERÇEK sandık bilir (aynı "chest" isteği).
			NetworkManager.request_drop_pickup.rpc_id(NetworkManager._host_peer_id(), drop_id, "chest")
			## Kritik cokme duzeltmesi: bkz. xp_orb.gd ayni notu.
			NetworkManager.discard_visual_drop(drop_id)
		queue_free()
		return

	_is_opening = true

	# Disconnect body_entered to prevent multiple triggers
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)

	## BUG DÜZELTMESİ (kullanıcı bildirimi: "diğer karakterler birşey
	## toplayınca üstlerinde birikiyor ama yok olmuyor") - bkz. xp_orb.gd
	## aynı notu: host'un GERÇEK sandığı bir uzak oyuncunun host'taki gerçek
	## kuklasına fiziksel olarak değerse (RPC bir sebeple hiç gelmese bile)
	## artık burada da doğrudan güvenlik ağı olarak, doğru sahibi için açılıyor.
	## Çok oyunculuda ödül host'ta dağıtılır (bkz. _open_for_player).
	if body.is_in_group("remote_players") or NetworkManager.is_multiplayer_active:
		_open_for_player(body)
	else:
		_award_chest_gold([])
		_open_chest_for(body)


## Sandığı belirtilen oyuncu için açar (hem singleplayer hem multiplayer host). award_to_local=false: sadece açılış
## animasyonu/sesi + drop temizliği, kuyruğa ekleme YAPMAZ (çok oyunculuda ödülü _open_for_player dağıttı).
func _open_chest_for(_body: Node, award_to_local: bool = true) -> void:
	_is_opening = true
	## DÜZELTME (KRİTİK - oyunun export'ta hiç açılmamasının kök nedeni): eskiden burada projede OLMAYAN
	## `res://assets/audio/yay_draw.mp3` yükleniyordu ve export'ta tüm zinciri çökertiyordu. Mevcut, ahşap bir darbe
	## sesi (0.6 pitch ile kalın bir "gıcırtı").
	var sfx: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	sfx.stream = load("res://Sound FX Starter Pack Vol. 1/Motions and Impacts/Impact Redwood.wav") as AudioStream
	sfx.pitch_scale = 0.6
	sfx.volume_db = 2.0
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

	## Dünyadaki kısa açılış: sallanma + aralıktan ışık + kapak patlaması (ödül ekranındaki uzun animasyonun ilk yarısı).
	if sprite:
		sprite.position.y = SPRITE_Y
	var tw: Tween = create_tween()
	for f: int in OPEN_FRAMES:
		tw.tween_callback(func() -> void:
			if sprite:
				sprite.frame = f
			if is_instance_valid(_beam):
				var bf: int = ChestArt.beam_frame_for_open(f)
				_beam.visible = bf >= 0
				if bf >= 0:
					_beam.frame = bf
		).set_delay(OPEN_FRAME_TIME)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)

	## Sandık seçim ekranı ANINDA açılmaz - kullanıcı isteği: "biriken sandıklar seviye atlayınca otomatik açılsın":
	## kuyruğa eklenir (normal: GameManager.pending_chest_tiers, elit: pending_elite_chests), main.gd
	## _try_open_next_pending_chest takım seviye atlayınca sırayla açar.
	tw.tween_callback(func() -> void:
		if award_to_local:
			if is_elite:
				GameManager.add_pending_elite_chest()
			else:
				GameManager.add_pending_chest(chest_tier)
		if NetworkManager.is_multiplayer_active:
			var drop_id: int = int(get_meta("drop_network_id", 0))
			if drop_id > 0:
				NetworkManager.remove_drop.rpc(drop_id)
		queue_free()
	)


## Multiplayer: host tarafında, sandığı GERÇEKTEN toplayan oyuncu için açar. Normal sandık SIRADAKİ oyuncuya gider (toplayan
## sıradaki değilse sandık ona uçar - 2026-10-07, NetworkManager.host_award_chest); elit sandık yaşayan HER oyuncuya birer tane
## (2026-09-25, NetworkManager.host_award_elite_chest). Tek oyunculu (multiplayer kapalı) akışta toplayan alır.
## Kullanıcı isteği (2026-10-02, yeni eşya sistemiyle birlikte): "oyunda yere düşen sandıklardan 90-150 civarı altın
## çıkmasını ve bu altınların oyuncularla paylaşılmasını istiyorum (herkese aynı miktar gönderilir oyuncu başına bu miktar
## %10 azalır)". Yetkili taraf (host / tek oyunculu) bir kez çeker; her katılımcı AYNI payı alır: miktar x (1 - %10 x
## (oyuncu sayısı - 1)). Sadece NORMAL yer sandıkları verir (elit sandık vermez - kullanıcı isteği, aynı gün).
## Aynı gün düzeltme ("sandık açılırken kart çıkar çıkmaz ordan gitmesini istiyorum altın barına"): bu yerden SANDIK alan
## oyuncunun payı sandıkla birlikte bekler (GameManager.add_pending_chest_gold), sandık ekranında kart inince karttan
## panele uçar. Sandık almayan takım arkadaşlarının payı (normal sandık tek kişiye gider) boss altını gibi sandığın
## yerinden dünyada KENDİ karakterlerine uçar ve doğrudan eklenir (grant_personal_gold + _rpc_gold_share_fx).
const CHEST_GOLD_MIN := 90
const CHEST_GOLD_MAX := 150
const CHEST_GOLD_CUT_PER_PLAYER := 0.10


static func chest_gold_share(amount: int, players: int) -> int:
	return maxi(1, int(round(float(amount) * maxf(0.1, 1.0 - CHEST_GOLD_CUT_PER_PLAYER * float(maxi(1, players) - 1)))))


## chest_receivers: bu yerden sandık alan peer id'leri (normal: toplayan/kazanan, elit: herkes). Tek oyunculuda yok sayılır.
func _award_chest_gold(chest_receivers: Array) -> void:
	## Kullanıcı isteği (2026-10-02): "elit sandıklardan altın çıkmasını istemiyorum" - sadece normal yer sandıkları.
	if is_elite or get_meta("gold_awarded", false):
		return
	set_meta("gold_awarded", true)
	var amount: int = randi_range(CHEST_GOLD_MIN, CHEST_GOLD_MAX)
	if not NetworkManager.is_multiplayer_active:
		GameManager.add_pending_chest_gold(is_elite, chest_gold_share(amount, 1))
		return
	var participants: Array = NetworkManager.get_reward_participants()
	if participants.is_empty():
		return
	var share: int = chest_gold_share(amount, participants.size())
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var fx_shares: Dictionary = {}
	for p: Dictionary in participants:
		var pid: int = int(p["peer_id"])
		if chest_receivers.has(pid):
			if pid == local_id:
				GameManager.add_pending_chest_gold(is_elite, share)
			else:
				NetworkManager.queue_chest_gold.rpc_id(pid, is_elite, share)
			continue
		if pid == local_id:
			NetworkManager.grant_personal_gold(share)
		else:
			NetworkManager.grant_personal_gold.rpc_id(pid, share)
		fx_shares[pid] = share
	if not fx_shares.is_empty():
		NetworkManager._rpc_gold_share_fx.rpc(global_position, fx_shares)


func _open_for_player(player_node: Node) -> void:
	if _awarded:
		return
	_awarded = true
	set_meta("claimed", true)
	if not NetworkManager.is_multiplayer_active:
		if player_node and is_instance_valid(player_node) and player_node.is_in_group("player"):
			_open_chest_for(player_node)
			return
		queue_free()
		return
	## Toplayanın peer id'si: host'un kendi oyuncusuysa host'un id'si, uzak kuklaysa onun peer_id'si.
	var picker_id: int = 0
	var picker_is_local: bool = player_node != null and is_instance_valid(player_node) and player_node.is_in_group("player")
	if player_node and is_instance_valid(player_node):
		if picker_is_local:
			picker_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		elif "peer_id" in player_node:
			picker_id = int(player_node.peer_id)
	if is_elite:
		if NetworkManager.host_award_elite_chest(picker_id) == 0 and picker_is_local:
			GameManager.add_pending_elite_chest() ## katılımcı yok (herkes ölü): sandık boşa gitmesin
	else:
		var winner_id: int = NetworkManager.host_award_chest(chest_tier, picker_id)
		if winner_id == 0 and picker_is_local:
			## Katılımcı listesi boş (ör. herkes ölü): yine de host'un yerel oyuncusuna ver, sandık boşa gitmesin.
			GameManager.add_pending_chest(chest_tier)
		_award_chest_gold([winner_id])
	if picker_is_local:
		## Toplayan host'un kendisiyse açılış animasyonu/sesi oynasın (ödül yukarıda dağıtıldı).
		_open_chest_for(player_node, false)
		return
	## Toplayan uzak bir client (ya da bulunamadı): host'ta animasyon yok, sandık hemen kalkar.
	var drop_id2: int = int(get_meta("drop_network_id", 0))
	if drop_id2 > 0:
		NetworkManager.remove_drop.rpc(drop_id2)
	queue_free()
