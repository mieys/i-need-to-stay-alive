extends Area2D

const FloatingText := preload("res://scenes/floating_text.tscn")

## 5 yemek tier'i (bkz. enemy.gd FOOD_TIER_COUNT/_roll_food_tier - orada
## ağırlıklı rastgele 1-5 arası seçiliyor, üst tier'ler daha nadir). Her
## tier'in KENDİ ikonu ve KENDİ iyileşme miktarı var - eskiden tier alanı
## sadece "Invalid set index" hatasını durdurmak için vardı, görsel/miktar
## hiç ayrışmıyordu (hepsi aynı çizilmiş elma şeklini kullanıp sabit 25
## can veriyordu). Sıra: yaygın/az iyileştiren -> nadir/çok iyileştiren.
const FOOD_TIER_TEXTURES: Dictionary = {
	1: "res://assets/food/apple.png",
	2: "res://assets/food/carrot.png",
	3: "res://assets/food/steak.png",
	4: "res://assets/food/kebab.png",
	5: "res://assets/food/pie.png",
}

## KULLANICI İSTEĞİ (2026-09-21): "Yiyeceklerin verdiği canı değiştiriyoruz: 1. kademe %8, 2. %16, 3. %24, 4. %32, 5. %40
## can yeniler". Eskiden sabit can miktarıydı (15/20/25/35/50) - artık yiyen oyuncunun MAKSİMUM canının yüzdesi.
## TEK kaynak burası: food_drop (yerel/uzak oyuncu) ve network_manager.gd (host'un istemci adına işlediği yol) get_heal_amount()'u çağırır.
const FOOD_TIER_HEAL_PERCENT: Dictionary = {
	1: 0.08,
	2: 0.16,
	3: 0.24,
	4: 0.32,
	5: 0.40,
}

const DEFAULT_TIER := 1

## İkonun ekranda kaç piksel (en uzun kenar) kaplayacağı - kaynak
## görsellerin çözünürlüğü farklı olsa bile (bkz. kebab.png diğerlerinden
## farklı en-boy oranında) hepsi aynı görünür boyuta normalize edilir.
const TARGET_PIXEL_SIZE := 34.0

@export var tier: int = DEFAULT_TIER:
	set(val):
		tier = val
		_update_visual()

var bob_time: float = 0.0
var _last_bob_offset: float = 0.0
var sprite: Sprite2D = null


func get_heal_percent() -> float:
	return FOOD_TIER_HEAL_PERCENT.get(tier, FOOD_TIER_HEAL_PERCENT[DEFAULT_TIER])


## eater_max_health: yiyen oyuncunun maksimum canı (yüzde onun üzerinden hesaplanır).
func get_heal_amount(eater_max_health: float = 100.0) -> float:
	return get_heal_percent() * eater_max_health


## bkz. xp_orb.gd üstündeki AYNI BUG DÜZELTMESİ notu (kullanıcı bildirimi:
## "Fps bir noktadan sonra hostta inanılmaz düşüyor").
const EXPIRE_SECONDS := 300.0


func _ready() -> void:
	add_to_group("food_drops")
	body_entered.connect(_on_body_entered)
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
	_update_visual()
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


## bkz. chest_drop.gd _update_visual() aynı desen: load() bir sebeple
## null dönerse (ör. .import henüz oluşmamışsa) ham dosyadan Image açıp
## ImageTexture'a çeviriyoruz - böylece editör dosyayı importlamadan da
## ikon doğru görünür.
func _update_visual() -> void:
	var s: Sprite2D = sprite if sprite else get_node_or_null("Sprite2D") as Sprite2D
	if not s:
		return
	var path: String = FOOD_TIER_TEXTURES.get(tier, FOOD_TIER_TEXTURES[DEFAULT_TIER]) as String
	var tex: Texture2D = load(path) as Texture2D
	if not tex:
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			tex = ImageTexture.create_from_image(img)
	if tex:
		s.texture = tex
		var longest: float = max(tex.get_width(), tex.get_height())
		if longest > 0.0:
			s.scale = Vector2.ONE * (TARGET_PIXEL_SIZE / longest)


func _process(delta: float) -> void:
	bob_time += delta
	var bob_offset: float = sin(bob_time * 4.0) * 3.0
	position.y += bob_offset - _last_bob_offset
	_last_bob_offset = bob_offset


func _on_body_entered(body: Node) -> void:
	if not is_instance_valid(body):
		return

	## Multiplayer: client tarafındaki görsel kopya → host'a toplama isteği gönder
	if NetworkManager.is_multiplayer_active and get_meta("network_spawned", false):
		# Client tarafındaki GÖRSEL KOPYA: sadece bu istemcinin KENDİ yerel
		# oyuncusu tetiklesin (bkz. xp_orb.gd aynı notu).
		if not body.is_in_group("player"):
			return
		var drop_id: int = int(get_meta("drop_network_id", 0))
		if drop_id > 0:
			## Verimlilik notu (derin multiplayer denetimi bulgusu) - bkz.
			## gold_drop.gd aynı DÜZELTME notu: broadcast yerine host'a hedefli.
			NetworkManager.request_drop_pickup.rpc_id(NetworkManager._host_peer_id(), drop_id, "food")
			## Kritik cokme duzeltmesi: bkz. xp_orb.gd ayni notu.
			NetworkManager.discard_visual_drop(drop_id)
		queue_free()
		return

	## BUG DÜZELTMESİ (kullanıcı bildirimi: "diğer karakterler birşey
	## toplayınca üstlerinde birikiyor ama yok olmuyor") - bkz. xp_orb.gd
	## aynı notu: burası eskiden SADECE "player" grubunu kabul edip host'un
	## simülasyonundaki GERÇEK uzak oyuncu kuklalarını ("remote_players")
	## koşulsuz reddediyordu; RPC bir sebeple hiç gelmezse yemek o oyuncunun
	## üzerinde sonsuza kadar asılı kalıyordu. Artık host'un gerçek fiziksel
	## çarpışması da bir güvenlik ağı olarak kabul ediliyor. RemotePlayer'ın
	## bir health_changed sinyali OLMADIĞI için (bkz. remote_player.gd) onun
	## .health alanına doğrudan dokunmak yerine kendi kendine yeten heal()
	## metodunu çağırıyoruz - kendi tepe çubuğunu ve uçan yazısını o zaten
	## halleder (mimari: host sadece "iyileştir" olgusunu iletir, görsel
	## sonucu her zaman ilgili tarafın kendi kodu üretir).
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			var healed: float = min(get_heal_amount(body.max_health), body.max_health - body.health)
			if healed > 0:
				body.health += healed
				body.health_changed.emit(body.health, body.max_health)
				var ft = FloatingText.instantiate()
				get_tree().current_scene.add_child(ft)
				ft.follow_target = body
				ft.follow_offset = Vector2(0, -30)
				ft.global_position = body.global_position + Vector2(0, -30)
				ft.setup("%d" % int(healed), Color(0.4, 0.9, 0.45), true)
				## Multiplayer: iyileşmeyi hedef oyuncuya senkronize et
				if NetworkManager.is_multiplayer_active:
					var target_peer: int = body.get("peer_id") if "peer_id" in body else 0
					if target_peer > 0:
						NetworkManager.sync_food_heal.rpc(healed, target_peer)
	elif body.is_in_group("remote_players"):
		if body.has_method("heal"):
			body.heal(get_heal_amount(float(body.max_health) if "max_health" in body else 100.0))
	else:
		return

	if NetworkManager.is_multiplayer_active:
		var drop_id: int = int(get_meta("drop_network_id", 0))
		if drop_id > 0:
			NetworkManager.queue_remove_drop(drop_id)
	queue_free()
