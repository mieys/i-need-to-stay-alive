extends Node2D

## oakley_bee_swarm.gd'nin alan göstergesi - Oakley'in Arı Sürüsü (Q) alanı.
## Kullanıcı isteği (2026-09-21): "alanın içinde minik arılar uçuşsun, efekti pixel tarzda
## yeniden tasarla, ses efektiyle beraber" -> artık (2026-09-23 güncellemesi, "en ucuz olanı
## yap") PROSEDÜREL değil, BAKED sprite: eski hal HER karede halka/dolgu için ~2800 draw_rect()
## çağrısı yapıyordu (özellikle disc_dither dolgusu tek başına ~1900) ve bu SÜREKLİ 10 saniye
## boyunca devam ediyordu - tools/gen_perf_sprite_fx.py ile PNG'ye pişirildi, artık 3 statik
## Sprite2D (dolgu + 2 halka, RADIUS her zaman 130 sabit olduğu için hiç ölçeklenmiyor) + 18
## minik AnimatedSprite2D (arı, 2 kareli kanat çırpma) ile oynatılıyor - toplam ~21 çizim.
## Halkaların "kesikli, yavaşça dönen" hissi PNG'lerde SABİT pişirildi, dönüş burada script'te
## node.rotation ile taklit ediliyor (tek çarpma, draw_rect eklemez). Arı gölgeleri (eski
## per-bee 1px karartma) basitlik için kaldırıldı - görsel etkisi ihmal edilebilir.
## Bu düğüm hem GERÇEK alanda (oakley_bee_swarm.gd) hem uzak istemcilerde (network_manager.gd
## "oakley_bee_swarm_spawn") aynı dosyadan doğar - görsel/ses iki tarafta AYNI (bkz. proje
## kökündeki CLAUDE.md).

const BUZZ_PATH := "res://assets/audio/oakley/oakley_bees.wav"
const FILL_TEX := preload("res://assets/fx/oakley_bee_ring/fill.png")
const RING_OUTER_TEX := preload("res://assets/fx/oakley_bee_ring/ring_outer.png")
const RING_INNER_TEX := preload("res://assets/fx/oakley_bee_ring/ring_inner.png")
const BEE_FRAMES := preload("res://assets/fx/oakley_bee_ring/bee_flap_frames.tres")
const BEE_COUNT := 18
const BUZZ_GAP := 0.8 ## iki vızıltı arası boşluk (sn)
## bkz. sınıf üstü not - eski `ring(..., phase=_t*8.0)` / `phase=-_t*10.0` dash kaymasının
## yaklaşık açısal karşılığı (dash indeksi/sn * halka başına adım açısı) - PNG'ler pişerken
## sabit fazda (phase=0) çizildi, "kesikli halkanın yavaşça dönmesi" hissi burada verilir.
const OUTER_SPIN_SPEED := 0.075 ## rad/sn
const INNER_SPIN_SPEED := -0.096 ## rad/sn (ters yönde)

## RADIUS her zaman 130.0 (bkz. oakley_bee_swarm.gd RADIUS const, tek çağrı yeri) - PNG'ler
## bu değere göre pişirildi, setup() radius almasına rağmen fiilen ölçekleme YAPMAZ (bkz. not).
var _radius: float = 130.0
var _t: float = 0.0
var _bees: Array = [] ## {r, w, phase, phase2, wob, spd2, node}
var _sfx: AudioStreamPlayer2D = null
var _gap_timer: float = 0.0

var _outer_ring: Sprite2D = null
var _inner_ring: Sprite2D = null


func setup(radius: float) -> void:
	_radius = radius


func _ready() -> void:
	z_index = 3
	var fill := Sprite2D.new()
	fill.texture = FILL_TEX
	fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(fill)

	_outer_ring = Sprite2D.new()
	_outer_ring.texture = RING_OUTER_TEX
	_outer_ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_outer_ring)

	_inner_ring = Sprite2D.new()
	_inner_ring.texture = RING_INNER_TEX
	_inner_ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_inner_ring)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(BEE_COUNT):
		var node := AnimatedSprite2D.new()
		node.sprite_frames = BEE_FRAMES
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(node)
		node.play("flap")
		_bees.append({
			"r": rng.randf_range(0.12, 0.9),
			"w": rng.randf_range(0.5, 1.5) * (1.0 if i % 2 == 0 else -1.0),
			"phase": rng.randf_range(0.0, TAU),
			"phase2": rng.randf_range(0.0, TAU),
			"wob": rng.randf_range(0.15, 0.4),
			"spd2": rng.randf_range(1.6, 3.4),
			"node": node,
		})
	var stream: AudioStream = load(BUZZ_PATH) as AudioStream
	if stream != null:
		_sfx = AudioStreamPlayer2D.new()
		_sfx.stream = stream
		_sfx.volume_db = -9.0
		_sfx.max_distance = 900.0
		add_child(_sfx)
		_sfx.finished.connect(func() -> void: _gap_timer = BUZZ_GAP)
		_sfx.play()


func _process(delta: float) -> void:
	_t += delta
	if _sfx != null and not _sfx.playing:
		_gap_timer -= delta
		if _gap_timer <= 0.0:
			_sfx.play()
	_outer_ring.rotation = _t * OUTER_SPIN_SPEED
	_inner_ring.rotation = _t * INNER_SPIN_SPEED
	for b in _bees:
		var p: Vector2 = _bee_pos(b)
		var ahead: Vector2 = _bee_pos_at(b, 0.05) - p
		var face_right: bool = ahead.x >= 0.0
		var bob: float = sin(_t * 9.0 + float(b["phase"])) * 1.2
		var node: AnimatedSprite2D = b["node"]
		## centered=true (varsayılan) kullanılıyor: node.position ~= arının görsel merkezi -
		## orijinaldeki tam "gövde arka ucu" referansından birkaç birim sapma var ama arı zaten
		## sürekli hareket/çırpınma halinde, gözle fark edilmiyor (bkz. sınıf üstü not).
		node.position = p + Vector2(0, bob)
		node.flip_h = not face_right


func _bee_pos(b: Dictionary) -> Vector2:
	var theta: float = float(b["phase"]) + float(b["w"]) * _t + float(b["wob"]) * sin(_t * float(b["spd2"]) + float(b["phase2"]))
	var rr: float = _radius * float(b["r"]) * (1.0 + 0.12 * sin(_t * 1.7 + float(b["phase2"])))
	return Vector2(cos(theta) * rr, sin(theta) * rr * 0.86)


func _bee_pos_at(b: Dictionary, dt: float) -> Vector2:
	var t_save: float = _t
	_t += dt
	var p: Vector2 = _bee_pos(b)
	_t = t_save
	return p
