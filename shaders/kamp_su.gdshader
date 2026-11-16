shader_type canvas_item;
#include "res://shaders/su_dalgacik.gdshaderinc"

// ANA MENÜ "Nehir Kenarı Kampı" nehrinin dalgacıkları (2026-11-16, kullanıcı: "ana menüdeki su shaderı normal ana haritadaki su shaderı gibi
// değil"). Taban nehir_kamp.png ana haritanın DURAĞAN yakalaması (dalgacıklar kapalıyken çekildi); bu shader tabanın üstünde oyundaki
// scenes/su.gdshader'ın dalgacıklarını BİREBİR çizer: aynı ortak kod (su_dalgacik.gdshaderinc), aynı kıyı/akış dokuları (water_fx.gd),
// aynı dünya pikseli. Tabanın pikseli -> dünya pikseli: dunya_origin + UV * dunya_size (yakalamanın sol üstü, kamp_capture.gd yazar).
// Oyunda dalgacık su karosunun rengine sirt_guc ile karışır ve saydamlık 0,8 -> 0,88 olur; burada su zemine zaten karışmış durduğundan
// karışım sirt_guc * 0.88'e yaklaştırılır. Gece tonu sonra kamp_gunbatimi.gdshader'da (dalgacıklar da o ışığı alır).

uniform vec2 dunya_origin = vec2(0.0, 0.0);
uniform vec2 dunya_size = vec2(320.0, 180.0);
uniform float zaman_olcek = 1.0; // menüde harita animasyonları idle'lar gibi yavaş (menu_camp_scene.gd IDLE_SLOW)

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = floor(dunya_origin + UV * dunya_size);
	if (dalgacik_acik && kiyi(px) > 3.5 && dalgacik(px, TIME * zaman_olcek)) {
		c.rgb = mix(c.rgb, sirt_renk.rgb, sirt_guc * 0.88);
	}
	COLOR = c;
}
