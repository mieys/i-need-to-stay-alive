extends Area2D

## Kullanıcı isteği: "yaratıklardan nadiren mıknatıs düşsün, mıknatısı
## aldığımızda bütün exp orblarını ve altınları çeksin." Bkz. enemy.gd
## _drop_magnet() (nadir düşme şansı) ve xp_orb.gd/gold_drop.gd
## attract_to_player() (asıl çekim mantığı zaten bu iki script'te vardı,
## burada sadece tüm "xp_orbs"/"gold_drops" grubuna tek seferde uygulanıyor).

const FloatingText := preload("res://scenes/floating_text.tscn")

var bob_time: float = 0.0
var _last_bob_offset: float = 0.0


## bkz. xp_orb.gd üstündeki AYNI BUG DÜZELTMESİ notu (kullanıcı bildirimi:
## "Fps bir noktadan sonra hostta inanılmaz düşüyor").
const EXPIRE_SECONDS := 300.0


func _ready() -> void:
	add_to_group("magnet_drops")
	body_entered.connect(_on_body_entered)
	queue_redraw()
	get_tree().create_timer(EXPIRE_SECONDS).timeout.connect(_on_expire)


func _on_expire() -> void:
	if not is_instance_valid(self) or get_meta("network_spawned", false):
		return
	if NetworkManager.is_multiplayer_active:
		if not NetworkManager.is_host:
			return
		var drop_id: int = int(get_meta("drop_network_id", 0))
		if drop_id > 0:
			NetworkManager.queue_remove_drop(drop_id)
	queue_free()


func _draw() -> void:
	draw_arc(Vector2(0, 0), 7.0, PI * 0.15, PI * 0.85, 16, Color(0.75, 0.1, 0.15), 5.0, true)
	draw_rect(Rect2(-8.5, -2, 3.5, 7), Color(0.8, 0.8, 0.85))
	draw_rect(Rect2(5.0, -2, 3.5, 7), Color(0.8, 0.8, 0.85))
	draw_rect(Rect2(-8.5, 3, 3.5, 2), Color(0.7, 0.15, 0.2))
	draw_rect(Rect2(5.0, 3, 3.5, 2), Color(0.7, 0.15, 0.2))


func _process(delta: float) -> void:
	bob_time += delta
	var bob_offset: float = sin(bob_time * 4.0) * 3.0
	position.y += bob_offset - _last_bob_offset
	_last_bob_offset = bob_offset


func _on_body_entered(body: Node) -> void:
	## bkz. gold_drop.gd _on_body_entered aynı düzeltme - eskiden sadece
	## "player" (yerel/host karakteri) kabul ediliyordu, bir RemotePlayer
	## (gerçek uzak client) host'un simülasyonundaki gerçek nesneye üstüne
	## yürüse bile hiçbir şey olmuyordu.
	if not (body.is_in_group("player") or body.is_in_group("remote_players")):
		return

	## Multiplayer: client tarafındaki görsel kopya → host'a toplama isteği gönder
	if NetworkManager.is_multiplayer_active and get_meta("network_spawned", false):
		var drop_id: int = int(get_meta("drop_network_id", 0))
		if drop_id > 0:
			## Verimlilik notu (derin multiplayer denetimi bulgusu) - bkz.
			## gold_drop.gd aynı DÜZELTME notu: broadcast yerine host'a hedefli.
			NetworkManager.request_drop_pickup.rpc_id(NetworkManager._host_peer_id(), drop_id, "magnet")
			## Kritik cokme duzeltmesi: bkz. xp_orb.gd ayni notu.
			NetworkManager.discard_visual_drop(drop_id)
		queue_free()
		return

	## #32 DÜZELTME (kullanıcı bildirimi: "Mıknatısla çekilen objeler her
	## zaman mıknatısı tutana gitmeli"): eskiden hiçbir hedef belirtilmeden
	## attract_to_player() çağrılıyordu, bu da xp_orb.gd/gold_drop.gd'nin
	## "en yakın oyuncu" mantığına düşmesine yol açıyordu - mıknatısı gerçekte
	## ALAN oyuncu en yakın olan olmayabiliyordu. Artık burada mıknatısı
	## GERÇEKTEN toplayan oyuncunun (body) peer id'si hesaplanıp hem yerel
	## çağrıya hem de ağ yayınına iletiliyor.
	var target_peer_id: int = -1
	if NetworkManager.is_multiplayer_active:
		if body.is_in_group("player"):
			target_peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
		elif "peer_id" in body:
			target_peer_id = body.peer_id

	get_tree().call_group("xp_orbs", "attract_to_player", target_peer_id)
	get_tree().call_group("gold_drops", "attract_to_player", target_peer_id)
	var ft = FloatingText.instantiate()
	get_tree().current_scene.add_child(ft)
	ft.global_position = body.global_position + Vector2(14, -34)
	ft.setup("MIKNATIS!", Color(0.85, 0.35, 0.95))
	if NetworkManager.is_multiplayer_active:
		NetworkManager.sync_magnet_pickup.rpc(target_peer_id)
		var drop_id: int = int(get_meta("drop_network_id", 0))
		if drop_id > 0:
			NetworkManager.queue_remove_drop(drop_id)
	_play_pickup_sound()
	queue_free()


## bkz. gold_drop.gd _play_pickup_sound() aynı desen: node queue_free()
## olmadan önce ses çalan AudioStreamPlayer2D'yi ayırıp kendi başına
## bitirmesine izin veriyoruz, yoksa ses yarıda kesilir.
func _play_pickup_sound() -> void:
	var sfx: AudioStreamPlayer2D = get_node_or_null("PickupSound")
	if not sfx:
		return
	var world_pos: Vector2 = sfx.global_position
	remove_child(sfx)
	get_tree().current_scene.add_child(sfx)
	sfx.global_position = world_pos
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
