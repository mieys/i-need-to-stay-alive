extends Node2D

## MEDUSA TAŞLAŞMASI görseli (madde 682; player.gd apply_petrify / apply_stone_slow). Oyuncuya (ya da uzak kopyasına, "skill_scene" yayınıyla -
## player.gd _play_and_broadcast_skill_fx) çocuk olarak eklenir: sahibinin AnimatedSprite2D'sinin o anki karesini birebir kopyalayan bir kaplama,
## renkleri gri taş tonlarına çevrilmiş (parlaklık korunur -> figür, gölge ve kontür okunur). mode 0 = TAŞLAŞMA (tüm beden), mode 1 = TAŞ AĞIRLIĞI
## (yavaşlama: yalnız bacaklar, karenin alt LEG_FRACTION'ı). `duration` sonunda FADE ile söner, kendini siler. Sahibin malzemesine/rengine dokunmaz.

const LEG_FRACTION := 0.42
const FADE := 0.25
const SHADER_CODE := """
shader_type canvas_item;
uniform float y_cut = -100000.0; // yerel y: bunun üstü çizilmez (mode 1)
uniform float alpha = 1.0;
varying float ly;
void vertex() { ly = VERTEX.y; }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float b = floor(clamp(l * 1.15, 0.0, 1.0) * 4.0 + 0.5) / 4.0; // 5 basamaklı taş tonu (yumuşak geçiş yok)
	vec3 stone = mix(vec3(0.26, 0.25, 0.23), vec3(0.84, 0.82, 0.76), b);
	float keep = step(y_cut, ly);
	COLOR = vec4(stone, c.a * alpha * keep);
}
"""

static var _shader: Shader = null

var duration: float = 2.0
var mode: int = 0

var _t: float = 0.0
var _src: AnimatedSprite2D = null
var _copy: AnimatedSprite2D = null
var _mat: ShaderMaterial = null


func _ready() -> void:
	z_index = 1
	var p: Node = get_parent()
	_src = p.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D if p != null else null
	if _src == null:
		queue_free()
		return
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_copy = AnimatedSprite2D.new()
	_copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_copy.material = _mat
	add_child(_copy)
	_sync()


## Aynı tazelemeyle tekrar uygulanırsa süre baştan.
func refresh(new_duration: float) -> void:
	_t = 0.0
	duration = maxf(duration, new_duration)


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration or _src == null or not is_instance_valid(_src):
		queue_free()
		return
	_sync()
	_mat.set_shader_parameter("alpha", clampf((duration - _t) / FADE, 0.0, 1.0))


func _sync() -> void:
	if _copy.sprite_frames != _src.sprite_frames:
		_copy.sprite_frames = _src.sprite_frames
	if _copy.animation != _src.animation:
		_copy.animation = _src.animation
	_copy.frame = _src.frame
	_copy.flip_h = _src.flip_h
	_copy.flip_v = _src.flip_v
	_copy.offset = _src.offset
	_copy.centered = _src.centered
	_copy.position = _src.position
	_copy.scale = _src.scale
	_copy.rotation = _src.rotation
	_copy.visible = _src.visible
	var cut: float = -100000.0
	if mode == 1 and _src.sprite_frames != null and _src.sprite_frames.has_animation(_src.animation):
		var tex: Texture2D = _src.sprite_frames.get_frame_texture(_src.animation, _src.frame)
		if tex != null:
			var h: float = float(tex.get_height())
			var top: float = _src.offset.y - (h * 0.5 if _src.centered else 0.0)
			cut = top + h * (1.0 - LEG_FRACTION)
	_mat.set_shader_parameter("y_cut", cut)
