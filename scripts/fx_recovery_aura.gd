extends AnimatedSprite2D

## Kullanıcı isteği ("efekt sistemi" - CraftPix Life/Mana Recovery): Melek'in Can
## Basma (Life = yeşil) ve Kalkan Yenileme (Mana = mavi) yetenekleri süresince
## hem Melek'in kendi üstünde hem hedef dostun üstünde, ayrıca Oakley'nin
## çiçeğinin üstünde bu büyü çemberi görünür. Kullanıcı notu: "melekteki eski
## efekt intro loop outro bu efekte uygun değil bu efekt tam loop halinde" -
## bu yüzden eski fx_melek_ally_aura.gd'nin 3 fazlı (intro/loop/outro) kare
## kontrolü YOK: 12 karelik animasyon baştan sona kesintisiz döner
## (SpriteFrames "loop" animasyonu loop=true), sadece açılış/kapanışta
## kısacık bir alfa geçişi var ki aniden belirip kaybolmasın.
##
## Kareler assets/fx/recovery/ altında, tools/pixelate_recovery_fx.py ile
## kaynak (yumuşak vektör) görselden pixel-art'a çevrilmiş halde - halka
## merkezi karenin tam ortasında, bu yüzden node konumu = halkanın merkezi.
## Karakter sahnelerinde konum (0, 30): karakter karelerinin İÇİNE gömülü
## gölgenin merkezi (bkz. player.gd _load_character_frames sonundaki "gölgesi
## karelerin içinde gömülü" notu - Player'ın kendi Shadow node'u gizli, o yüzden
## eski aura'nın FOOT_LEVEL=55'i gerçek ayak hizası DEĞİLDİ, ~25 birim aşağıdaydı).
##
## Kullanım (bkz. player.gd _set_ally_aura/_skill_heal/_skill_kalkan_yenileme,
## oakley_flower.gd _ready): sahneyi node'a child olarak ekle, bitirmek için
## stop_aura() çağır. stop_aura() alfa geçişinden sonra kendini siler.

## "heal" / "shield" - player.gd/remote_player.gd _ally_aura_fx anahtarı.
## Boş ("") ise (çiçek gibi) hiçbir sözlüğe kaydolmaz, sadece parent ile ölür.
@export var aura_type: String = ""
## Güvenlik ağı: normalde player.gd yetenek bitince stop_aura() çağırır, ama
## kaster oyundan çıkarsa vb. bir uzak kopya sonsuza dek kalmasın diye. 0 =
## sınırsız (çiçek: ömrünü kendi parent'ı belirliyor - alınınca/silinince gider).
## Melek yetenekleri 6 sn sürüyor (bkz. player.gd SKILL_TIMING[1]/SKILL2_TIMING[10]).
@export var max_lifetime: float = 9.0

const FADE_IN_TIME := 0.15
const FADE_OUT_TIME := 0.25

var _age: float = 0.0
var _stopping: bool = false
var _fade_out_left: float = FADE_OUT_TIME


func _ready() -> void:
	modulate.a = 0.0
	play(&"loop")
	## Uzak kopya kaydı: Melek'in KENDİ üstündeki aura ağda "skill_scene" olarak
	## yayınlanıyor (bkz. player.gd _play_and_broadcast_skill_fx ->
	## network_manager.gd broadcast_player_vfx "skill_scene") - orada node
	## sadece rp.add_child() ile ekleniyor, RemotePlayer._ally_aura_fx'e hiç
	## yazılmıyordu. Bu yüzden yetenek erken iptal edilince gelen "durdur" RPC'si
	## (broadcast_ally_aura_stop -> stop_ally_aura_fx) uzakta hiçbir şey
	## bulamıyor, kopya zaman aşımına kadar oynamaya devam ediyordu (CLAUDE.md'deki
	## "kasterde kapandı, diğerinde eski efekt kalıyor" hata sınıfı). Burada
	## kendimizi parent'ın sözlüğüne yazıyoruz; zaten kayıtlıysa (start_ally_aura_fx
	## yolu) dokunmuyoruz.
	if aura_type != "":
		var host: Node = get_parent()
		if host and "_ally_aura_fx" in host:
			var registry: Dictionary = host.get("_ally_aura_fx")
			if not (registry.has(aura_type) and is_instance_valid(registry[aura_type])):
				registry[aura_type] = self


## Yetenek bitince / bağ kopunca çağrılır (bkz. player.gd stop_ally_aura_fx).
## Not: "stop" AnimatedSprite2D'nin yerleşik metoduyla çakışacağı için stop_aura.
func stop_aura() -> void:
	_stopping = true


func _process(delta: float) -> void:
	_age += delta
	if not _stopping and max_lifetime > 0.0 and _age >= max_lifetime:
		_stopping = true
	if _stopping:
		_fade_out_left -= delta
		## minf: fade-in bitmeden durdurulursa alfa 1'e sıçramasın.
		modulate.a = minf(modulate.a, clampf(_fade_out_left / FADE_OUT_TIME, 0.0, 1.0))
		if _fade_out_left <= 0.0:
			queue_free()
		return
	modulate.a = clampf(_age / FADE_IN_TIME, 0.0, 1.0)
