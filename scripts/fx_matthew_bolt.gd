extends Node2D

## Matthew Q "Şimşek Hücumu": Matthew'dan hedefe çakan şimşek (madde 98; eski köpek atılışının yerine). Dünyada durur.
## Madde 99 (FPS): şimşek artık çalışma anında HESAPLANMAZ - assets/fx/matthew_lightning/bolt_tiles.png döşeme sayfasından (tools/bake_matthew_bolt.gd;
## biçim kuralları eski hesaplayıcıyla aynı: zikzak + Bresenham + 1/3/5 px + çatal + kopma) BAŞ + ORTA... + SON parçaları hedefe doğru dizilir.
## Eski sürümde her evre değişiminde Dictionary'ye basılıp satır koşularına çevriliyordu (400 px'lik şimşek: evre başı ~5 ms, çakış başına 6 evre,
## uzak kopyalarda da); şimdi bir çakış = n adet Sprite2D, evre değişince sadece region_rect kayar.
## 6 evre (BOLT_STAGE_TIME'da bir): öncü çizgi -> kalın + çatallı -> titrek -> kopuk -> kesik çizgiler -> kıvılcım.
## Kurulum: player.gd _evo_world_fx(sahne, başlangıç, UZUNLUK, AÇI) -> rotation = açı, setup(uzunluk) (uzak kopyada da aynı sıra:
## network_manager.gd "hitscan_impact"). Parça seçimi konum + uzunluktan türetilen tohumla yapılır - iki ekranda aynı şimşek.
## Parça sayısı round(uzunluk / BOLT_TILE_LEN); artan/eksilen fark parçaların boyuna hafifçe gerilmesiyle (en çok ~%20) kapanır.
## Hücre boyu WORLD_TEXEL (Matthew'in pikselinin dünyadaki boyu - bkz. matthew_lightning.gd ÖLÇEK notu).

const ML := preload("res://scripts/matthew_lightning.gd")
const LAST_STAGE := 5

var _t: float = 0.0
var _stage: int = -1
var _tiles: Array = [] ## [[Sprite2D, int satır], ...]


func _ready() -> void:
	z_index = 60
	set_process(false)


func setup(length: float, _color: Color = Color.WHITE) -> void:
	var dir: Vector2 = Vector2.RIGHT.rotated(rotation)
	rotation = 0.0
	global_position = (global_position / ML.WORLD_TEXEL).round() * ML.WORLD_TEXEL
	var len_px: float = maxf(4.0, length / ML.WORLD_TEXEL)
	var seed_v: int = absi(int(global_position.x) * 73856093 ^ int(global_position.y) * 19349663 ^ int(length * 8.0) * 83492791) % 1000003 + 1
	var tex: Texture2D = ML.sheet_texture("bolt_tiles")
	if tex == null:
		queue_free()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n: int = maxi(2, roundi(len_px / float(ML.BOLT_TILE_LEN)))
	var stretch: float = len_px / (float(n) * float(ML.BOLT_TILE_LEN))
	var step: float = float(ML.BOLT_TILE_LEN) * stretch * ML.WORLD_TEXEL
	var prev_mid: int = -1
	for k in range(n):
		var row: int
		if k == 0:
			row = ML.BOLT_ROW_START + rng.randi() % ML.BOLT_START_VARIANTS
		elif k == n - 1:
			row = ML.BOLT_ROW_END + rng.randi() % ML.BOLT_END_VARIANTS
		else:
			var v: int = _pick_mid(rng)
			if v == prev_mid: ## art arda aynı parça olmasın
				v = _pick_mid(rng)
			prev_mid = v
			row = ML.BOLT_ROW_MID + v
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false
		spr.region_enabled = true
		spr.offset = Vector2(-float(ML.BOLT_TILE_PAD), -(float(ML.BOLT_TILE_CY) + 0.5)) ## parçanın orta satırı yerel y=0'a, içeriğin sol kenarı x=0'a
		spr.rotation = dir.angle()
		spr.scale = Vector2(stretch, 1.0) * ML.WORLD_TEXEL
		spr.position = dir * (float(k) * step)
		add_child(spr)
		_tiles.append([spr, row])
	_t = 0.0
	_set_stage(0)
	set_process(true)


## Orta parça: çatallı iki varyant seyrek (yaklaşık %20) - eski şimşekte de çatal sayısı uzunluğa bağlı değil, birkaç tane.
func _pick_mid(rng: RandomNumberGenerator) -> int:
	if rng.randf() < 0.2:
		return ML.BOLT_FORK_VARIANTS[rng.randi() % ML.BOLT_FORK_VARIANTS.size()]
	var plain: Array[int] = []
	for v in range(ML.BOLT_MID_VARIANTS):
		if not ML.BOLT_FORK_VARIANTS.has(v):
			plain.append(v)
	return plain[rng.randi() % plain.size()]


func _process(delta: float) -> void:
	_t += delta
	var s: int = int(_t / ML.BOLT_STAGE_TIME)
	if s > LAST_STAGE:
		queue_free()
		return
	if s != _stage:
		_set_stage(s)


func _set_stage(s: int) -> void:
	_stage = s
	for t: Array in _tiles:
		(t[0] as Sprite2D).region_rect = Rect2(float(s * ML.BOLT_TILE_W), float(int(t[1]) * ML.BOLT_TILE_H), float(ML.BOLT_TILE_W), float(ML.BOLT_TILE_H))
