extends Area2D

const CHEST_TEXTURES: Dictionary = {
	0: "res://assets/sprites/chest_tier_1_2.png",
	1: "res://assets/sprites/chest_tier_3_4.png",
	2: "res://assets/sprites/chest_tier_5_6.png",
	3: "res://assets/sprites/chest_tier_7_8.png",
	4: "res://assets/sprites/chest_tier_9_10.png",
	5: "res://assets/sprites/chest_tier_11_up.png"
}

@export var chest_tier: int = 0:
	set(val):
		chest_tier = val
		_update_visual()

var bob_time: float = 0.0
var _last_bob_offset: float = 0.0
var sprite: Sprite2D = null

func _ready() -> void:
	add_to_group("chest_drops")
	body_entered.connect(_on_body_entered)
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
	_update_visual()

func _update_visual() -> void:
	var s: Sprite2D = sprite if sprite else get_node_or_null("Sprite2D") as Sprite2D
	if s:
		var path: String = CHECH_TEXTURE_PATH(chest_tier)
		var tex: Texture2D = load(path) as Texture2D
		if not tex:
			var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
			if img:
				tex = ImageTexture.create_from_image(img)
		if tex:
			tex.set_meta("path", path)
			s.texture = tex
		s.hframes = 1
		s.vframes = 4
		s.frame = 0

func CHECH_TEXTURE_PATH(tier_id: int) -> String:
	return CHEST_TEXTURES.get(tier_id, CHEST_TEXTURES[0]) as String

func _process(delta: float) -> void:
	bob_time += delta
	var bob_offset: float = sin(bob_time * 4.0) * 3.0
	position.y += bob_offset - _last_bob_offset
	_last_bob_offset = bob_offset

var _is_opening: bool = false

func _on_body_entered(body: Node) -> void:
	if _is_opening or not is_instance_valid(body):
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
	## Kullanıcı isteği (2026-09-21): çok oyunculuda sandığı KİM toplarsa toplasın kazanan rastgele belirlenir
	## (bkz. _open_for_player / NetworkManager.host_award_chest) - tek oyunculuda eskisi gibi toplayan alır.
	if body.is_in_group("remote_players") or NetworkManager.is_multiplayer_active:
		_open_for_player(body)
	else:
		_open_chest_for(body)


## Sandığı belirtilen oyuncu için açar (hem singleplayer hem multiplayer host). award_to_local=false: sadece açılış
## animasyonu/sesi + drop temizliği, kuyruğa ekleme YAPMAZ (çok oyunculuda sandığın sahibini host_award_chest belirler).
func _open_chest_for(body: Node, award_to_local: bool = true) -> void:
	# Play chest opening sound (wooden creak pitched down)
	## DÜZELTME (KRİTİK - oyunun export'ta hiç açılmamasının kök nedeni):
	## burada eskiden `res://assets/audio/yay_draw.mp3` yükleniyordu ama o dosya
	## projede YOK (silinmiş). Eksik dosya `scenes/weapon_yay.tscn`'de preload
	## edildiği için export'ta TÜM zinciri çökertiyordu (weapon_yay.tscn ->
	## weapon.gd -> network_manager.gd "Compilation failed") ve NetworkManager
	## autoload'u yüklenmediği için oyun başlıyor ama hiçbir şey çalışmıyordu
	## (harita/karakter görünmüyor, oyun başlamıyor). Artık mevcut, ahşap bir
	## darbe sesi kullanılıyor (0.6 pitch ile kalın bir "gıcırtı" oluyor -
	## orijinal amaç buydu).
	var sfx: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	sfx.stream = load("res://Sound FX Starter Pack Vol. 1/Motions and Impacts/Impact Redwood.wav") as AudioStream
	sfx.pitch_scale = 0.6
	sfx.volume_db = 2.0
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
		
	# Play opening animation using tween to cycle frames 0 to 3 going down (4 frames total)
	var tw: Tween = create_tween()
	for i in range(1, 4):
		tw.tween_callback(func(): 
			if sprite:
				sprite.frame = i
		).set_delay(0.08)
	
	# Animasyon bitince SANDIK KAPANIR ama seçim ekranı ANINDA açılmaz.
	## Kullanıcı isteği: "sandık alınca sol üstteki avatarın yanına sandık
	## simgesi görünsün, biriken sandıklar seviye atlayınca otomatik açılsın"
	## - eskiden burada hemen ChestMenuScene açılıyordu (ve tek oyunculuda
	## dünyayı duraklatıyordu, çok oyunculuda ise oyuncuyu savunmasız
	## bırakıyordu, bkz. aşağıdaki eski yorum). Artık sandığın kademesi
	## GameManager.pending_chest_tiers'e ekleniyor (bkz. main.gd
	## _try_open_next_pending_chest - takım seviye atladığında sırayla açılır).
	tw.tween_callback(func():
		if award_to_local:
			GameManager.add_pending_chest(chest_tier)
		if NetworkManager.is_multiplayer_active:
			var drop_id: int = int(get_meta("drop_network_id", 0))
			if drop_id > 0:
				NetworkManager.remove_drop.rpc(drop_id)
		queue_free()
	).set_delay(0.08)


## Multiplayer: host tarafında, sandığı GERÇEKTEN toplayan oyuncu için açar.
## Eskiden burada _player_node parametresi TAMAMEN GÖZ ARDI EDİLİP sandık
## HER ZAMAN host'un kendi local player'ına açılıyordu (kullanıcı bildirimi:
## "bir oyuncu sandık aldığında o sandık sadece hosta gidiyor fakat toplayan
## oyuncuya gitmeli hosta değil") - artık toplayan host'un kendisiyse eskisi
## gibi yerel açılıyor, bir RemotePlayer (yani GERÇEK bir uzak client) ise
## host burada hiçbir item eklemiyor, sadece o client'a "senin için bu
## kademede bir sandık aç" diye bir RPC gönderiyor - itemler o client'ın
## kendi GameManager'ına (kişisel envanterine) eklenir.
func _open_for_player(player_node: Node) -> void:
	## Kullanıcı isteği (2026-09-21): "Yaratıklardan sandık düştüğünde bir oyuncu sandığı alırsa o sandık rasgele olacak
	## şekilde birine verilir, herkesin eşit şansı vardır ... sadece 1 kişi alınan sandığı alabilir. Her sandıkta bu yeniden
	## hesaplanır." Toplayan kim olursa olsun kazanan NetworkManager.host_award_chest'te (1/N) belirlenir: kazanan host'sa
	## kendi kuyruğuna, uzak bir client'sa open_chest_for_peer ile onun kuyruğuna eklenir. Tek oyunculu (multiplayer kapalı)
	## akışta eskisi gibi toplayan alır.
	if not NetworkManager.is_multiplayer_active:
		if player_node and is_instance_valid(player_node) and player_node.is_in_group("player"):
			_open_chest_for(player_node)
			return
		queue_free()
		return
	var winner_id: int = NetworkManager.host_award_chest(chest_tier)
	if winner_id == 0 and player_node and is_instance_valid(player_node) and player_node.is_in_group("player"):
		## Katılımcı listesi boş (ör. herkes ölü): yine de host'un yerel oyuncusuna ver, sandık boşa gitmesin.
		GameManager.add_pending_chest(chest_tier)
	if player_node and is_instance_valid(player_node) and player_node.is_in_group("player"):
		## Toplayan host'un kendisiyse açılış animasyonu/sesi oynasın (ödül yukarıda dağıtıldı).
		_open_chest_for(player_node, false)
		return
	## Toplayan uzak bir client (ya da bulunamadı): host'ta animasyon yok, sandık hemen kalkar.
	var drop_id2: int = int(get_meta("drop_network_id", 0))
	if drop_id2 > 0:
		NetworkManager.remove_drop.rpc(drop_id2)
	queue_free()
