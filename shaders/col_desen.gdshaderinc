// ALTIN KUMLAR (çöl) ZEMİN DESENİ (2026-11-09). Kullanan: scenes/col_zemin.gdshader ("Yer/Zemin Toprak" kum dolgu, "Yer/Zemin Çimen" saçaklı
// çimen, kıyı karoları "Su/Su ayrıntılar 2" - hepsi aynı malzeme). Çöl setinin zemin karoları DÜZ RENK (kum #d2b268, çimen #afa046); doku
// yalnız saçaklarda. Burada yalnız taban rengine yakın (düz) pikseller desenlenir - karoların kenar / saçak / kıyı çizimleri aynen kalır.
// Kural (oyunun piksel dili): desen DÜNYA pikselinde, dither yok, her ton geçişi tek adım düz piksel, düşük kontrast (göz yormasın).
//  - KUM: (1) çok büyük, tek adımlık açık / koyu bölgeler (kumun tepe / çukur hissi), (2) rüzgâr kıvrımları: yalnız bazı bölgelerde, rüzgâr
//    yönünde hafif çapraz, dalgalı, kesik kesik kısa çizgiler (gölge çizgisi + üstünde tek piksel açık sırt), (3) seyrek tek piksel çakıl.
//  - ÇİMEN: Kara Bataklık "B - Ot Tutamları"nın (madde 526) çöl paletli hâli - setin saçak çizim dilinde küçük V tutamlar, kümeler hâlinde.
// Kullanım: float m = cd_kum_maske(rgb); rgb = mix(rgb, cd_kum(rgb, px), m);  float g = cd_cim_maske(rgb); rgb = mix(rgb, cd_cimen(rgb, px), g);

const vec3 CD_KUM_KOYU = vec3(0.796, 0.671, 0.388);      // #cbab63 büyük koyu bölge (tek adım)
const vec3 CD_KUM_ACIK = vec3(0.843, 0.722, 0.431);      // #d7b86e büyük açık bölge
const vec3 CD_KIVRIM_GOLGE = vec3(0.773, 0.643, 0.373);  // #c5a45f rüzgâr kıvrımı gölgesi
const vec3 CD_KIVRIM_SIRT = vec3(0.871, 0.757, 0.459);   // #dec175 kıvrım sırtı
const vec3 CD_CAKIL = vec3(0.663, 0.537, 0.333);         // #a98955
const vec3 CD_CAKIL_ISIK = vec3(0.902, 0.808, 0.533);    // #e6ce88

const vec3 CD_COT_KOYU = vec3(0.498, 0.478, 0.208);      // #7f7a35
const vec3 CD_COT_ORTA = vec3(0.588, 0.565, 0.251);      // #969040
const vec3 CD_COT_TABAN = vec3(0.686, 0.627, 0.275);     // #afa046
const vec3 CD_COT_ACIK = vec3(0.769, 0.690, 0.310);      // #c4b04f
const vec3 CD_COT_PARLAK = vec3(0.851, 0.765, 0.353);    // #d9c35a

uniform vec4 kum_taban : source_color = vec4(0.824, 0.698, 0.408, 1.0);    // #d2b268: düz kum karosu (maske + oran tabanı)
uniform vec4 cim_taban : source_color = vec4(0.686, 0.627, 0.275, 1.0);    // #afa046: düz çimen karosu
uniform float taban_tolerans : hint_range(0.0, 0.2) = 0.045;
uniform float kivrim_araligi : hint_range(4.0, 14.0) = 7.0;               // kıvrım çizgileri arası (dünya px)
uniform float kivrim_payi : hint_range(0.0, 1.0) = 0.42;                  // kıvrımlı bölgelerin kumdaki payı (büyük = daha çok)
uniform float cakil_yogunlugu : hint_range(0.0, 0.2) = 0.035;             // 11 px hücre başına

float cd_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float cd_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(cd_hash(i), cd_hash(i + vec2(1.0, 0.0)), f.x), mix(cd_hash(i + vec2(0.0, 1.0)), cd_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float cd_fbm(vec2 p) {
	return cd_vnoise(p) * 0.55 + cd_vnoise(p * 2.03) * 0.30 + cd_vnoise(p * 4.01) * 0.15;
}

float cd_leke(vec2 px, float olcek, float kivrim) {
	vec2 w = vec2(cd_fbm(px * 0.009), cd_fbm(px * 0.009 + vec2(31.7, 7.3))) - 0.5;
	return cd_fbm((px + w * kivrim) * olcek);
}

float cd_kum_maske(vec3 rgb) {
	return 1.0 - smoothstep(taban_tolerans * 0.55, taban_tolerans * 1.55, distance(rgb, kum_taban.rgb));
}

float cd_cim_maske(vec3 rgb) {
	return 1.0 - smoothstep(taban_tolerans * 0.55, taban_tolerans * 1.55, distance(rgb, cim_taban.rgb));
}

// Karonun kendi rengine ORANLA (taban karoda hedefin birebir aynısı).
vec3 cd_ton(vec3 tex, vec3 taban, vec3 hedef) {
	return tex * (hedef / max(taban, vec3(0.001)));
}

// px = floor(dünya konumu). Döner: desenli kum rengi (maske uygulanmamış).
vec3 cd_kum(vec3 tex, vec2 px) {
	vec3 b = kum_taban.rgb;
	float z = cd_leke(px, 0.0045, 40.0);
	vec3 c = tex;
	if (z > 0.64) { c = cd_ton(tex, b, CD_KUM_KOYU); }
	else if (z < 0.36) { c = cd_ton(tex, b, CD_KUM_ACIK); }
	// Rüzgâr kıvrımları: yalnız kıvrımlı bölgede (büyük leke), rüzgâr yönünde hafif çapraz, menderesli; kesik kesik (her çizgi 10-24 px'lik
	// parçalar), çizgi = 1 px gölge + hemen üstünde 1 px açık sırt.
	float bolge = cd_leke(px + vec2(311.0, 97.0), 0.008, 24.0);
	if (bolge > 1.0 - kivrim_payi) {
		float u = px.y + px.x * 0.28 + 2.6 * sin(px.x * 0.043 + cd_fbm(px * 0.02) * 5.0);
		float k = floor(u / kivrim_araligi);
		float f = u - k * kivrim_araligi;
		float seg_l = 10.0 + floor(cd_hash(vec2(k, 3.7)) * 14.0);
		float seg = floor((px.x + cd_hash(vec2(k, 9.1)) * 40.0) / seg_l);
		bool var_mi = cd_hash(vec2(k, seg)) > 0.38;
		// kıvrım bölgenin kenarına yaklaştıkça seyrekleşir (keskin sınır çizmesin)
		bool icerde = bolge > 1.0 - kivrim_payi + 0.035 || cd_hash(vec2(k, seg) + 5.5) > 0.5;
		if (var_mi && icerde) {
			if (f < 1.0) { c = cd_ton(tex, b, CD_KIVRIM_GOLGE); }
			else if (f < 2.0) { c = cd_ton(tex, b, CD_KIVRIM_SIRT); }
		}
	}
	// Çakıl: 11 px hücrede en çok bir tane, 1 px koyu + bazen sol üstünde 1 px ışık
	const float HC = 11.0;
	vec2 hc = floor(px / HC);
	if (cd_hash(hc + vec2(2.2, 7.7)) < cakil_yogunlugu) {
		vec2 o = hc * HC + 1.0 + floor(vec2(cd_hash(hc + vec2(4.1, 0.6)), cd_hash(hc + vec2(8.3, 5.2))) * (HC - 3.0));
		if (px == o) { c = cd_ton(tex, b, CD_CAKIL); }
		else if (px == o + vec2(-1.0, -1.0) && cd_hash(hc + 1.3) > 0.5) { c = cd_ton(tex, b, CD_CAKIL_ISIK); }
	}
	return c;
}

int cd_satir(int satir, int x, int w) {
	return (satir >> ((w - 1 - x) * 4)) & 0xF;
}

// px = floor(dünya konumu). Döner: desenli çimen rengi (maske uygulanmamış).
vec3 cd_cimen(vec3 tex, vec2 px) {
	vec3 b = cim_taban.rgb;
	float z = cd_leke(px, 0.006, 28.0);
	vec3 c = cd_ton(tex, b, z > 0.63 ? mix(CD_COT_TABAN, CD_COT_ORTA, 0.30) : CD_COT_TABAN);
	const float H = 10.0;
	vec2 ci = floor(px / H);
	float yog = mix(0.06, 0.58, smoothstep(0.42, 0.70, cd_leke(ci * H + 5.0, 0.02, 10.0)));
	if (cd_hash(ci + vec2(1.9, 7.3)) >= yog) {
		return c;
	}
	float tur = cd_hash(ci + vec2(4.6, 2.8));
	vec2 o = ci * H + floor(vec2(cd_hash(ci + vec2(3.1, 0.4)), cd_hash(ci + vec2(6.2, 1.9))) * (H - 8.0));
	vec2 l = px - o;
	int x = int(l.x);
	int y = int(l.y);
	int v = 0;
	if (tur < 0.4) {
		if (x >= 0 && y >= 0 && x < 5 && y < 4) {
			int r[4] = int[4](0x00400, 0x04340, 0x33233, 0x12121);
			v = cd_satir(r[y], x, 5);
		}
	} else if (tur < 0.75) {
		if (x >= 0 && y >= 0 && x < 7 && y < 5) {
			int r[5] = int[5](0x0004000, 0x0403040, 0x0303030, 0x3232323, 0x1121211);
			v = cd_satir(r[y], x, 7);
		}
	} else {
		if (x >= 0 && y >= 0 && x < 3 && y < 3) {
			int r[3] = int[3](0x040, 0x343, 0x121);
			v = cd_satir(r[y], x, 3);
		}
	}
	if (v == 1) { c = cd_ton(tex, b, CD_COT_KOYU); }
	else if (v == 2) { c = cd_ton(tex, b, CD_COT_ORTA); }
	else if (v == 3) { c = cd_ton(tex, b, CD_COT_ACIK); }
	else if (v == 4) { c = CD_COT_PARLAK; }
	return c;
}
