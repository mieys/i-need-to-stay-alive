extends CanvasLayer

## GÖRÜNMEZKEN KARANLIK GÖRÜŞ (madde 533, kullanıcı: "görünmez olabilen herkes (assasin çocuk, elara ve hayaletin sağladığı
## görünmezlik) etrafı league of legends'da görünmez oluncaki gibi hafif daha karanlık görmeli"): YALNIZ yerel oyuncunun kendi
## ekranı - LoL'de gizlenen şampiyonun ekranı kenarlardan kararır, orta açık kalır. Diğer oyunculara hiçbir şey gitmez (ağ yok).
## Miktar player.gd stealth_vision_amount() (Assasin E / Elara "Kaybolan Gölge" / evcil Hayalet örtüsü = 1; Assasin odağında
## solmayla birlikte 0 -> 1). Çizim shaders/stealth_vision.gdshader (ekran kopyası yok). main.gd bu katmanı sisten sonra, HUD'dan
## HEMEN önce koyar (aynı layer=1, ağaç sırası): dünya -> renk geçişi -> sis -> BU -> HUD (arayüz kararmaz).

const Shader_: Shader = preload("res://shaders/stealth_vision.gdshader")
const FADE_IN := 0.35 ## sn (0 -> 1)
const FADE_OUT := 0.45 ## sn (1 -> 0)

var amount: float = 0.0
var _rect: ColorRect = null
var _mat: ShaderMaterial = null
var _player: Node = null


func _ready() -> void:
	layer = 1
	_rect = ColorRect.new()
	_rect.name = "StealthVision"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color.WHITE
	_mat = ShaderMaterial.new()
	_mat.shader = Shader_
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	var target: float = 0.0
	if _player != null and is_instance_valid(_player) and _player.has_method("stealth_vision_amount"):
		target = clampf(float(_player.call("stealth_vision_amount")), 0.0, 1.0)
	set_amount_toward(target, delta)


## Testler de kullanır: miktarı hedefe FADE_IN / FADE_OUT hızında yaklaştırır, karartmayı açar/kapar.
func set_amount_toward(target: float, delta: float) -> void:
	var rate: float = 1.0 / (FADE_IN if target > amount else FADE_OUT)
	amount = move_toward(amount, target, rate * delta)
	var on: bool = amount > 0.001
	if _rect != null:
		_rect.visible = on
		if on:
			_mat.set_shader_parameter("amount", amount)
