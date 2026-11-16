// BULANIK (PİS) SU - ortak kod (2026-11-16, Kara Bataklık; kullanıcı: "bataklıktaki suyun görünüşü için shader hazırlar mısın biraz daha
// pis hissetsin ve saydam olsun altındaki toprak görünsün istiyorum biraz").
// Kullanan: scenes/su.gdshader (bütün suların shader'ı, madde 714) + scenes/bataklik_su_ayak.gdshader (suya giren ayak örtüsü). İkisi
// AYNI rengi hesaplamalı: örtü bacakların çevresine suyun rengini boyar, farklı olursa karakterin ayağında dikdörtgen leke görünür.
// Bu yüzden renk yalnız dünya pikseli + TIME'a bağlı (kıyı uzaklığı / akış dokusu YOK - örtüde o dokular yok).
// Açan: harita profilinin "su_doku" -> "bulanik" sözlüğü (scripts/map_profiles.gd; anahtarlar bu dosyanın uniform adları, değer verilmeyen
// uniform aşağıdaki varsayılanı kullanır), materyale scripts/water_fx.gd apply_murk yazar. Kapalıyken (öbür haritalar) hiçbir şey değişmez.
//
// Katmanlar (alttan üste), hepsi dünya pikselinde, dither YOK (düz renk / düz alfa bantları):
//  1. DİP: bataklık su hücrelerinin altında zemin karosu yok (gen_bataklik.py paint_terrain) -> çamur tabanı burada çizilir: TEK düz ton +
//     ince tortu (batık çakıl 2x1 taş + gölge, batık dal / kök yatık 4-6 px çizgi, koyu benek). Renkler setin çamurunun (#7c7538) koyusu.
//  2. SU: profilin sabit su rengi `bulanik_alfa` ile dibin üstüne (0 = berrak, 1 = dip hiç görünmez), her yerde AYNI. Sonuç OPAK.
//  3. YOSUN / KÖPÜK: seyrek 4x2 px soluk sarı-yeşil leke, yerinde (durgun su) belirip söner; her döngüde başka yerde.
// ÖBEK YOK (kullanıcı 2026-11-16: "öbek öbek şeyler olmasını istemiyorum"): ilk sürümdeki iki tonlu büyük dip lekesi ve sürüklenen koyu /
// kahverengi balçık bulutları kaldırıldı - su düzgün bulanık, kir hissi ince tortudan + renkten.
// Dalgacık sırtı (su_dalgacik.gdshaderinc) bunun ÜSTÜNE çizilir (su.gdshader).
// Kabarcık YOK: kabarcık sudan pusunun uyarısı (fx_su_pusu.gd, madde 716) - ortamda kabarcık olursa uyarı okunmaz.
// KARODA GÖMÜLÜ SU (kullanıcı: "bitki kenarlarındaki su efekti uyumsuz oldu suyla"): kıyı çimeni karoları, nilüfer gölgesi, su mercimeği
// parıltısı ve dalga izi süsleri setin eski su paletini (#12342e ... #32905f) taşır -> su_bulanik_karo() o pikselleri yeni suya boyar
// (paletteki parlaklık oranıyla: gölge koyu, parıltı açık kalır). Kullanan: bataklik_zemin.gdshader (kıyı "Su/Su ayrıntılar 2") +
// scenes/bataklik_su_susu.gdshader ("Su/Su süsleri"); katmanlar profilin "su_doku" -> "su_karolari" listesi (water_fx.gd attach).

uniform bool bulanik = false;
uniform float bulanik_alfa : hint_range(0.0, 1.0) = 0.6;
uniform vec4 dip_renk : source_color = vec4(0.333, 0.286, 0.153, 1.0);   // #554927 dip çamuru
uniform vec4 dip_koyu : source_color = vec4(0.259, 0.224, 0.122, 1.0);   // #42391f benek / dal / çakıl gölgesi
uniform vec4 dip_acik : source_color = vec4(0.561, 0.502, 0.290, 1.0);   // #8f804a batık çakıl
uniform vec4 yosun_renk : source_color = vec4(0.561, 0.580, 0.318, 1.0); // #8f9451 yüzen yosun / köpük
uniform float yosun_yogunluk = 0.10; // 13 px hücrede yosun olasılığı

float sb_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// px = floor(dünya konumu). Çamur tabanı (suyun altı).
vec3 sb_dip(vec2 px) {
	vec3 c = dip_renk.rgb;
	// batık çakıl (9 px hücre %16): üstte 2 px açık taş, altında 2 px koyu gölge
	vec2 ci = floor(px / 9.0);
	if (sb_hash(ci + vec2(8.1, 0.6)) < 0.16) {
		vec2 o = ci * 9.0 + floor(vec2(sb_hash(ci + vec2(5.9, 1.1)), sb_hash(ci + vec2(3.4, 9.2))) * 7.0);
		vec2 l = px - o;
		if (l.x >= 0.0 && l.x <= 1.0) {
			if (l.y == 0.0) { return dip_acik.rgb; }
			if (l.y == 1.0) { return dip_koyu.rgb * 0.85; }
		}
	}
	// batık dal / kök (23 px hücre %12): 4-6 px, her 2 px'te bir satır kayan yatık çizgi
	vec2 di = floor(px / 23.0);
	if (sb_hash(di + vec2(1.7, 4.4)) < 0.12) {
		float len = 4.0 + floor(sb_hash(di + vec2(6.6, 2.2)) * 3.0);
		vec2 o = di * 23.0 + floor(vec2(sb_hash(di + vec2(0.3, 7.9)), sb_hash(di + vec2(9.1, 3.3))) * (23.0 - 7.0)) + vec2(0.0, 3.0);
		vec2 l = px - o;
		float yon = sb_hash(di + vec2(4.8, 8.8)) < 0.5 ? 1.0 : -1.0;
		if (l.x >= 0.0 && l.x < len && l.y == yon * floor(l.x * 0.5)) {
			return dip_koyu.rgb * 0.8;
		}
	}
	// koyu benek (3 px hücre %25, tek piksel)
	vec2 bi = floor(px / 3.0);
	vec2 bo = bi * 3.0 + floor(vec2(sb_hash(bi + vec2(2.0, 0.5)), sb_hash(bi + vec2(7.0, 3.5))) * 3.0);
	if (px == bo && sb_hash(bi + vec2(4.4, 9.1)) < 0.25) {
		c = mix(c, dip_koyu.rgb, 0.7);
	}
	return c;
}

// Yüzen yosun / köpük örtüsü 0..1 (düz alfa adımları). 13 px hücre, ~12 sn döngünün %70'inde görünür, her döngüde başka yer / şekil.
float sb_yosun(vec2 px, float t) {
	vec2 ci = floor(px / 13.0);
	float r = sb_hash(ci + vec2(2.3, 7.1));
	if (r >= yosun_yogunluk) { return 0.0; }
	float dongu = t * 0.083 + r / max(yosun_yogunluk, 0.001) * 5.0;
	float faz = fract(dongu);
	if (faz >= 0.7) { return 0.0; }
	float k = floor(dongu);
	vec2 o = ci * 13.0 + floor(vec2(sb_hash(ci + vec2(k * 1.31, 4.2)), sb_hash(ci + vec2(6.8, k * 0.77))) * 10.0);
	vec2 l = px - o;
	if (l.x < 0.0 || l.y < 0.0 || l.x > 3.0 || l.y > 1.0) { return 0.0; }
	// 4x2 şekiller (satır başına 4 bit, soldaki piksel yüksek bit): 1 = yosun
	int s = int(sb_hash(ci + vec2(k * 2.9, 1.5)) * 4.0);
	int ust[4] = int[4](0x6, 0x4, 0xE, 0x2);
	int alt[4] = int[4](0xF, 0xC, 0x6, 0x7);
	int satir = l.y == 0.0 ? ust[s] : alt[s];
	if (((satir >> (3 - int(l.x))) & 1) == 0) { return 0.0; }
	// belirme / sönme: düz iki adım (dither yok)
	float g = (faz < 0.08 || faz > 0.62) ? 0.35 : 0.7;
	return g;
}

// su = profilin sabit su rengi; döner: OPAK su pikseli rengi (dip + bulanık su + yosun).
vec3 su_bulanik(vec3 su, vec2 px, float t) {
	vec3 c = mix(sb_dip(px), su, bulanik_alfa);
	float y = sb_yosun(px, t);
	if (y > 0.0) {
		c = mix(c, yosun_renk.rgb, y);
	}
	return c;
}

// Setin eski su paletinden bir piksel mi -> parlaklığının taban su rengine (#24674b) oranı; değilse 0. Palet karolardan ölçüldü
// (b_su / b_nilufer / b_mercimek / b_kiyi): #12342e kıyı + nilüfer gölgesi, #1b4a3e gölge, #1c4e40 + #205b45 dalga izi, #24674b taban,
// #2c7a59 parıltı / mercimek, #32905f kıyı köpüğü. Karolar kayıpsız + en yakın süzme -> renkler birebir gelir.
float sb_set_su_orani(vec3 c) {
	vec3 p[7] = vec3[7](vec3(0.071, 0.204, 0.180), vec3(0.106, 0.290, 0.243), vec3(0.110, 0.306, 0.251), vec3(0.125, 0.357, 0.271),
		vec3(0.141, 0.404, 0.294), vec3(0.173, 0.478, 0.349), vec3(0.196, 0.565, 0.373));
	float k[7] = float[7](0.515, 0.734, 0.770, 0.888, 1.0, 1.19, 1.38);
	for (int i = 0; i < 7; i++) {
		if (distance(c, p[i]) < 0.012) {
			return k[i];
		}
	}
	return 0.0;
}

// Karoda gömülü eski su pikseli -> yeni bulanık su (aynı parlaklık oranında); başka piksel aynen döner.
vec3 su_bulanik_karo(vec3 c, vec3 su, vec2 px, float t) {
	float k = sb_set_su_orani(c);
	return k > 0.0 ? su_bulanik(su, px, t) * k : c;
}
