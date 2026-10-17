shader_type canvas_item;
render_mode world_vertex_coords;

// Mermi parçacık izi (scripts/fx_particle_trail.gd, madde 215): parçacıklar GPU'da yaşar.
// Örnek (instance) başına: konum = doğduğu yer (MODEL_MATRIX), INSTANCE_CUSTOM = (doğuş saati, varyant satırı, hız.x, hız.y).
// Konum/yerçekimi/sayfa karesi yaştan hesaplanır; merkez sanat pikseli ızgarasına oturur (kayarken titremesin).

uniform float clock = 0.0;
uniform float life = 0.3;
uniform vec2 drift = vec2(0.0);
uniform float gravity = 0.0;
uniform float texel = 1.212;
uniform float frames = 8.0;
uniform float variants = 2.0;

varying flat float v_frame;
varying flat float v_variant;
varying flat float v_alive;

void vertex() {
	float age = clock - INSTANCE_CUSTOM.x;
	v_alive = (age >= 0.0 && age < life) ? 1.0 : 0.0;
	vec2 at = MODEL_MATRIX[3].xy;
	vec2 offs = VERTEX - at;
	vec2 c = at + (drift + INSTANCE_CUSTOM.zw) * age + vec2(0.0, 0.5 * gravity * age * age);
	c = floor(c / texel + 0.5) * texel;
	VERTEX = c + offs;
	v_frame = min(frames - 1.0, floor(age / life * frames));
	v_variant = INSTANCE_CUSTOM.y;
}

void fragment() {
	if (v_alive < 0.5) {
		discard;
	}
	vec2 uv = (vec2(v_frame, v_variant) + UV) / vec2(frames, variants);
	COLOR = texture(TEXTURE, uv);
}
