extends Control

## Kullanıcı isteği: "seyyar satıcı geldiğinde oyunculara nerede olduğunun
## bildirimi verilmiyor (varolduğu sürece konumu ok ile gösterilmeli)" -
## minimap.gd'deki küçük "$" noktası (bkz. o dosya set_merchant_marker)
## yeterince fark edilmiyordu. main.gd merchant_spawned/merchant_departed
## sinyalleriyle set_target_active(pos, true/false) çağırıp açıp kapatır.
##
## DÜZELTME (kullanıcı bildirimi: "Satıcının ne tarafta olduğunu gösteren
## gösterge hiç görünmüyor neredeyse... ekranın orta üst kısımlarında
## olmalı") - eski tasarım oyuncuyu ortalayan ekran merkezi ETRAFINDA
## (RING_RADIUS yarıçapında) dönen bir okku - kamera oyuncuyu ortaladığı
## için ok yöne göre ekranın HERHANGİ bir kenarına (genelde HUD elemanlarının
## arkasına) düşebiliyordu. Artık ekranın SABİT üst-orta noktasında duran,
## sadece YÖNÜNÜ (rotation) satıcıya göre değiştiren bir pusula okuna
## dönüştü - konumu asla değişmediği için her zaman görünür.
##
## DÜZELTME (kullanıcı isteği: "Satıcının ne kadar süre sonra ayrılacağı...
## geri sayım şeklinde gözüksün") - satıcının GERÇEK kalan süresi (bkz.
## traveling_merchant.gd _visit_timer) SADECE HOST'ta işliyor (client'lar o
## _process'i hiç çalıştırmıyor, bkz. o dosyadaki "AĞ MİMARİSİ" notu), yani
## buradan ağ üzerinden okunamaz. Bunun yerine set_target_active(true)
## çağrıldığı an (TÜM client'larda AYNI merchant_spawned sinyaliyle, bkz.
## main.gd _on_merchant_spawned) TravelingMerchant.VISIT_DURATION'dan
## (CLAUDE.md "iki ayrı yer" uyarısı gereği tek kaynak - burada AYRI bir
## sabit YAZILMIYOR) kendi yerel geri sayımı başlatılıyor.

const ARROW_LENGTH := 22.0
const ARROW_WIDTH := 15.0
const ARROW_FILL := Color(1.0, 0.85, 0.2, 0.95)
const ARROW_OUTLINE := Color(0.1, 0.08, 0.02, 0.85)
## Sabit gösterge konumu: ekranın yatayda ortası, üstten bu kadar aşağıda.
const ANCHOR_TOP_OFFSET := 86.0

var _active: bool = false
var _target_pos: Vector2 = Vector2.ZERO
var _player: Node = null
var _remaining: float = 0.0


func _ready() -> void:
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_target_active(pos: Vector2, active: bool) -> void:
	_target_pos = pos
	_active = active
	if active:
		_remaining = TravelingMerchant.VISIT_DURATION
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _remaining > 0.0:
		_remaining = max(0.0, _remaining - delta)
	queue_redraw()


func _format_countdown(seconds: float) -> String:
	var total: int = int(ceil(seconds))
	return "%d:%02d" % [total / 60, total % 60]


func _draw() -> void:
	if not _active or not _player or not is_instance_valid(_player):
		return
	var dir: Vector2 = (_target_pos - _player.global_position)
	if dir.length() < 1.0:
		return
	dir = dir.normalized()
	## DÜZELTME (kullanıcı bildirimi: "ok alakasız bir şekilde ekranın sol üst
	## dışında kalıyor, orta üst kısımlarında olmalı") - bu Control'ün ebeveyni
	## bir CanvasLayer (main.gd, Control DEĞİL), yani PRESET_FULL_RECT'in
	## dayandığı "size" bazı durumlarda (ör. bu düğüm sahneden değil elle
	## Control.new()+add_child ile kurulduğu için, bkz. main.gd) viewport'un
	## GERÇEK genişliğine hiç eşitlenmeyip küçük/varsayılan kalabiliyordu -
	## bu da "ortalanmış" hesaplanan X'i aslında sıfıra yakın (ekranın en
	## soluna) düşürüyordu. get_viewport_rect() Control'ün kendi "size"ına
	## bağlı olmadığı için GERÇEK ekran genişliğini garanti veriyor.
	var anchor: Vector2 = Vector2(get_viewport_rect().size.x * 0.5, ANCHOR_TOP_OFFSET)
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var tip: Vector2 = anchor + dir * (ARROW_LENGTH * 0.5)
	var base_l: Vector2 = anchor - dir * (ARROW_LENGTH * 0.5) + perp * (ARROW_WIDTH * 0.5)
	var base_r: Vector2 = anchor - dir * (ARROW_LENGTH * 0.5) - perp * (ARROW_WIDTH * 0.5)
	var tri := PackedVector2Array([tip, base_l, base_r])
	draw_colored_polygon(tri, ARROW_FILL)
	draw_polyline(PackedVector2Array([tip, base_l, base_r, tip]), ARROW_OUTLINE, 2.5)
	var font: Font = ThemeDB.fallback_font
	var label: String = "Seyyar Satıcı"
	var label_pos: Vector2 = anchor + Vector2(0.0, ARROW_WIDTH * 0.5 + 18.0)
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	draw_string(font, label_pos - Vector2(text_size.x * 0.5, 0.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.95, 0.8, 0.95))
	var countdown: String = _format_countdown(_remaining)
	var cd_pos: Vector2 = label_pos + Vector2(0.0, 20.0)
	var cd_size: Vector2 = font.get_string_size(countdown, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_string(font, cd_pos - Vector2(cd_size.x * 0.5, 0.0), countdown,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ARROW_FILL)
