extends Area2D

## "Topla" görevi (bkz. world_event_manager.gd) objesi - "obje olarak temsili bir şey ekle"
## (kullanıcı isteği) için basit, prosedürel çizilmiş bir mücevher; yeni bir sanat eseri
## gerektirmiyor. fx_ring.gd gibi TAMAMEN kod içinde kurulur, .tscn YOK.
##
## AĞ MİMARİSİ (bkz. network_manager.gd world_event_item_collected notu): konumlar
## world_event_started'ın extra["items"]'inden HER istemcide (host dahil) yerel olarak
## kuruluyor - bu yüzden item_index'ler TÜM istemcilerde AYNI sırada aynı konumlara denk
## gelir. Sadece bu istemcinin KENDİ yerel oyuncusu ("player" grubu, uzak kuklalar DEĞİL -
## yoksa her istemci gördüğü HERHANGİ bir oyuncu/kukla temasında ayrı ayrı rapor ederdi)
## dokununca broadcast_world_event_item_collected çağrılır; host bunu dinleyip ilerlemeyi
## artırır, AYNI RPC'nin call_local'ı sayesinde TÜM istemciler (bu obje dahil) o index'i
## gizler.

const RADIUS := 14.0
const PICKUP_RADIUS := 30.0
## Kullanıcı bildirimi (2026-09-24): obje görünmüyordu / pixel art + spritesheet olmalı - eskiden her karede
## draw_colored_polygon ile yumuşak kenarlı bir elmas çiziliyordu. Artık tools/gen_collect_item_sprite.py'nin pişirdiği
## 6 karelik kristal döngüsü (1 sanat pikseli = PixelDraw.TEXEL, karakterlerle aynı yoğunluk).
const CrystalFrames := preload("res://assets/fx/mission_collect/crystal_frames.tres")
const TEXEL := 1.212 ## PixelDraw.TEXEL
var _sprite: AnimatedSprite2D = null

var mission_id: int = 0
var item_index: int = 0
var _collected: bool = false
var _bob_time: float = 0.0
var _base_y: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 ## oyuncu katmanı (bkz. player.tscn CollisionShape2D layer) - diğer objelerle çakışmasın
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = CrystalFrames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * TEXEL
	_sprite.offset = Vector2(0, -8) ## gölge (karenin altı) objenin konumuna otursun
	add_child(_sprite)
	_sprite.play("idle")
	_sprite.frame = randi() % 6 ## hepsi aynı anda parlamasın
	_base_y = position.y
	set_process(true)


func _process(delta: float) -> void:
	## Kullanıcı isteği yok ama xp_orb/gold_drop'un AYNI "nefes alma" dilinde hafif bir
	## yukarı-aşağı sallanma - farkedilir/canlı dursun diye (bkz. xp_orb.gd PULSE_* notu).
	_bob_time += delta
	if _sprite:
		_sprite.position.y = round(sin(_bob_time * 2.2) * 2.0) * TEXEL ## tam texel adımlarıyla (pixel kalsın)
	## DÜZELTME (kullanıcı bildirimi 2026-09-24: "görevlerden çoğu çalışmıyor") - toplama SADECE
	## body_entered (fizik, collision_mask=2) ile algılanıyordu ama Player'ın collision_layer'ı 0 (bkz.
	## player.tscn), yani objeler HİÇ toplanamıyordu. Bayrak/Konvoy ile AYNI mesafe kontrolü; her istemci
	## sadece KENDİ yerel oyuncusuna bakar, sonuç yine RPC ile host'a gider.
	if not _collected:
		for p: Node in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and p.get("is_dead") != true and (p as Node2D).global_position.distance_to(global_position) <= PICKUP_RADIUS:
				_on_body_entered(p)
				break


func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	NetworkManager.broadcast_world_event_item_collected.rpc(mission_id, item_index)
	_fade_out()


## world_event_manager.gd'nin main.gd üzerinden çağırdığı, bu index toplanınca (kendi
## istemcimizde toplanmamış olsa bile - bkz. call_local) görsel kopyayı kaldırmak için.
func mark_collected() -> void:
	_collected = true
	_fade_out()


## Toplanan obje (kendimiz topladıysak da, başkası topladıysa da) kısa bir solmayla sahneden SİLİNİR - eskiden kendi
## topladığımız obje sadece gizlenip görev bitene kadar görünmez olarak sahnede kalıyordu.
var _fading: bool = false

func _fade_out() -> void:
	if _fading:
		return
	_fading = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
