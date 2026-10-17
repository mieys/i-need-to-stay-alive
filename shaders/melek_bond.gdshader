shader_type canvas_item;

// Melek Q/E bağı "A Işık İpi" (madde 212, prototip tools/proto_20261017/gen_melek_bag.py). melek_bond_ribbon.gd ipi Melek'in
// SANAT PİKSELİ çözünürlüğündeki bir SubViewport'a çizer (her parça = bir sanat pikselinin merkezi -> ince şerit/kıymık yok),
// sonra en yakın komşu ölçekle Melek'in piksel ızgarasına oturtur. Bu shader taban eğrisi boyunca geniş şerit ağının
// içindeki asıl ipi boyar:
//   UV    = (s, v): s yay boyu, v taban eğrisinin normali boyunca uzaklık - ikisi de sanat pikseli
//   COLOR = kodlu örnek verisi: r = ipin sapması ((d + 8) / 16), g = yarı genişlik (/4), b = dalga paketi (0/1), a = eğim ((e + 3) / 6)
// Tonlar prototipteki gibi: çekirdek / açık / orta, 1 piksel yumuşak kontur; paket geçerken paket paleti (Q hale altını, E krem).

uniform vec4 c_out : source_color;
uniform vec4 c_edge : source_color;
uniform vec4 c_mid : source_color;
uniform vec4 c_core : source_color;
uniform vec4 h_edge : source_color;
uniform vec4 h_mid : source_color;
uniform vec4 h_core : source_color;
uniform float total = 100.0;

varying vec4 v_attr;

void vertex() {
	v_attr = COLOR;
}

void fragment() {
	float disp = v_attr.r * 16.0 - 8.0;
	float hw = v_attr.g * 4.0;
	float slope = v_attr.a * 6.0 - 3.0;
	float d = abs(UV.y - disp) / sqrt(1.0 + slope * slope);
	if (UV.x < -0.01 || UV.x > total + 0.01 || hw < 0.3 || d > hw + 1.0) {
		discard;
	}
	bool hot = v_attr.b > 0.5;
	vec4 col = c_out;
	if (d <= hw) {
		float k = d / max(hw, 0.5);
		if (k < 0.36) {
			col = hot ? h_core : c_core;
		} else if (k < 0.72) {
			col = hot ? h_mid : c_mid;
		} else {
			col = hot ? h_edge : c_edge;
		}
	}
	COLOR = vec4(col.rgb, 1.0);
}
