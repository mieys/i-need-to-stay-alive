extends Node2D

## Ruhani Yetenek "Kalkan Bağı"nın piksel tarzı bağ görseli (kullanıcı isteği: "Kalkan bağı için pixel tarzda
## bir kalkan bağı efekti hazırla") - HER İKİ oyuncunun da KENDİ üstünde duran bir kopyası vardır (kaster VE
## partner, bkz. player.gd _ensure_kalkan_bagi_link_fx/receive_kalkan_bagi_bond - CLAUDE.md'nin "kaster
## görür, diğerleri görmez" hatasına düşmemek için FxPaladinBarrierLink ile AYNI desen). Şovalye'nin
## bariyerinden farkı: o SADECE sahibinin etrafında dönen soyut bir halka, bu GERÇEKTEN iki oyuncu arasına
## gerilen, partnerin CANLI konumunu her karede okuyan bir enerji hattı çiziyor.

const PixelDraw := preload("res://scripts/pixel_draw.gd")

var _owner_ref: Node2D = null
var _t: float = 0.0


func setup(owner_node: Node2D) -> void:
	_owner_ref = owner_node


func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(_owner_ref):
		queue_free()
		return
	queue_redraw()


## Partnerin KENDİ (owner'ın) yerel uzayındaki konumu - bulunamazsa ZERO (çizilmez).
func _partner_local_pos() -> Vector2:
	if not is_instance_valid(_owner_ref) or not ("_kalkan_bagi_partner_peer_id" in _owner_ref):
		return Vector2.ZERO
	var pid: int = int(_owner_ref.get("_kalkan_bagi_partner_peer_id"))
	if pid <= 0:
		return Vector2.ZERO
	for rp in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and "peer_id" in rp and int(rp.peer_id) == pid:
			return (rp as Node2D).global_position - _owner_ref.global_position
	return Vector2.ZERO


func _draw() -> void:
	var to_partner: Vector2 = _partner_local_pos()
	var dist: float = to_partner.length()
	if dist < 4.0:
		return
	var dir: Vector2 = to_partner / dist
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var col := Color(0.45, 0.8, 1.0, 0.72)
	## Akan kesikli enerji hattı (düz bir çizgi yerine) - hafif dalgalanarak partnere doğru "kayan" parçalar.
	var seg_len: float = 9.0
	var gap: float = 6.0
	var period: float = seg_len + gap
	var offset: float = fmod(_t * 46.0, period)
	var travelled: float = -offset
	while travelled < dist:
		var a: float = maxf(travelled, 0.0)
		var b: float = minf(travelled + seg_len, dist)
		if b > a:
			var wobble_a: float = sin(_t * 3.2 + a * 0.045) * 2.0
			var wobble_b: float = sin(_t * 3.2 + b * 0.045) * 2.0
			PixelDraw.line(self, dir * a + perp * wobble_a, dir * b + perp * wobble_b, col, 1)
		travelled += period
	## İki uçta küçük kalkan parıltıları.
	for p in [Vector2.ZERO, to_partner]:
		PixelDraw.px(self, p, 2, Color(0.8, 0.96, 1.0, 0.55 + 0.25 * sin(_t * 5.0)))
