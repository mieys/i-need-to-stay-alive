extends Area2D

## Mirror of scripts/projectile.gd (the player's shot) but for ranged enemies
## (Demon/Lich/Röntgen/İblis, see enemy.gd's is_ranged) - flies toward the
## player and calls their take_damage() instead of an enemy's.

@export var speed: float = 208.0 ## genel hız ayarı: 260'tan %20 düşürüldü
var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var source: Node2D = null
var tint: Color = Color(1.0, 0.55, 0.15, 1.0)
## Menzilli yaratıkların İKİNCİ, zayıf ama GARANTİ İSABETLİ atışı (bkz.
## enemy.gd _fire_homing_attack) bunu true yapar - her karede direction
## oyuncunun GÜNCEL konumuna göre yeniden hesaplanır, yani asla ıskalamaz
## (sadece oyuncunun "sıyrılma" stat'ı take_damage() içinde onu durdurabilir,
## normal bir isabet gibi). false iken (büyü/spell) davranış eskisi gibi
## sabit yönlü düz bir mermi.
var homing: bool = false

@onready var visual = $Visual

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if visual:
		visual.glow_color = tint
		visual.queue_redraw()
	get_tree().create_timer(3.0).timeout.connect(func(): if is_instance_valid(self): queue_free())


func _physics_process(delta: float) -> void:
	if homing:
		var player := get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			direction = (player.global_position - global_position).normalized()
	position += direction * speed * delta

	## Şovalye (Paladin) ultisi aktifken koruma alanının içine hiçbir menzilli
	## saldırı giremiyor - bkz. player.gd paladin_zone_active/paladin_zone_
	## radius. Sınıra değince hasar vermeden sessizce kayboluyor. Kullanıcı
	## isteği: "ne olursa olsun hiçbir yaratığın kalkanın içine giremeyip
	## atışların da kalkanın içine girememesi lazım" - eskiden SADECE bu
	## client'ın kendi yerel oyuncusunun kalkanına bakılıyordu; artık aktif
	## kalkanı olan HERHANGİ bir oyuncu (yerel + tüm RemotePlayer'lar)
	## kontrol ediliyor, mermi kime hedeflenmiş olursa olsun.
	var dome_candidates: Array = [get_tree().get_first_node_in_group("player")]
	if NetworkManager.is_multiplayer_active:
		dome_candidates.append_array(get_tree().get_nodes_in_group("remote_players"))
	for p in dome_candidates:
		if p and is_instance_valid(p) and "paladin_zone_active" in p and p.get("paladin_zone_active") == true:
			if global_position.distance_to(p.global_position) <= p.get("paladin_zone_radius"):
				queue_free()
				return

	## Seyyar satıcının güvenli bölgesi - yukarıdaki Şovalye kalkanıyla AYNI
	## "sınıra değince sessizce kaybol" davranışı, ama sabit bir dünya
	## konumuna göre (bkz. enemy.gd'deki AYNI desen notu).
	if GameManager.merchant_zone_active and global_position.distance_to(GameManager.merchant_zone_pos) <= GameManager.MERCHANT_ZONE_RADIUS:
		queue_free()
		return


func _on_body_entered(body: Node) -> void:
	## Multiplayer görsel kopya — hasar verme, sadece yok ol
	if get_meta("network_spawned", false):
		_spawn_impact()
		queue_free()
		return
	## "player_ally" (TEKİL - Matthew'in tilkisi, bkz. player_pet.gd) artık
	## HEDEF ALINMIYOR - kullanıcı isteği: "yaratıklar onu görmezden gelmeli".
	## Menzilli düşman mermileri ona hiç değmemiş gibi geçip gidiyor (sadece
	## oyuncuya çarpıp patlıyor). Necromancer iskelet/hortlakları
	## ("player_allies" - ÇOĞUL) ise hasar alabilir ve mermileri engelleyebilir.
	##
	## DÜZELTME (kullanıcı bildirimi kümesi: "bazen bir oyuncu hasar alınca
	## diğer oyuncu da hasar alıyor" / "bazen canavarlar bana vurmasa bile
	## hasar alıyorum"): RemotePlayer (=gerçek bir uzak katılımcının kuklası,
	## bkz. remote_player.gd) "player" grubunda DEĞİL - "player_ally" (TEKİL,
	## Matthew'in tilkisiyle aynı isim ama AYRI bir grup) ve "remote_players"
	## grubunda. Buradaki eski kontrol sadece "player" + "player_allies"
	## (ÇOĞUL, necromancer yaratıkları) grubuna bakıyordu, yani RemotePlayer'ı
	## HİÇ TANIMIYORDU. Sonuç: host'ta gerçek bir menzilli mermi fiziksel
	## olarak bir uzak oyuncunun kuklasına tam isabet etse bile is_target
	## false döndüğü için hiçbir şey olmuyordu - mermi hasar vermeden İÇİNDEN
	## GEÇİP gidiyordu (uzak oyuncular menzilli mermilere fiilen bağışıktı).
	## Bu, host'un ekranında bir mermi görsel olarak bir uzak oyuncuya isabet
	## ederken hasarın farklı görünmesi/hiç görünmemesi ("bir oyuncunun
	## hasarı diğerine karışıyor" izlenimi) durumuna da katkıda bulunmuş
	## olabilir - özellikle eski homing hedefleme hatasıyla birlikte (bkz.
	## enemy.gd _fire_homing_attack düzeltmesi). Artık RemotePlayer'ın
	## GERÇEK, benzersiz grubu ("remote_players" - SADECE RemotePlayer bu
	## gruba ekleniyor, Matthew'in tilkisi eklenmiyor) de tanınıyor.
	var is_target: bool = body.is_in_group("player") or body.is_in_group("player_allies") or body.is_in_group("remote_players")
	if is_instance_valid(body) and is_target and body.has_method("take_damage"):
		body.take_damage(damage, source)
		_spawn_impact()
		queue_free()


func _spawn_impact() -> void:
	var ring := Node2D.new()
	ring.set_script(load("res://scripts/fx_ring.gd"))
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position
	ring.color = tint
	ring.max_radius = 28.0
	ring.life = 0.3
