shader_type canvas_item;

// ==================================================
// SALLANAN OT - Harita > "Shader Eklenecek" > "Çalılar" / "Çalılar1" karo katmanları
// ==================================================
// Kullanıcı isteği (2026-09-26): "çalılar ... layerına şuandakinden daha iyi bir sallanan çimen animasyonu" - sadece sallanma
// (otlar karo katmanında kalır, Tiled'dan eklenen her şey olduğu gibi çalışır) + 2D oyunlardaki yukarı/aşağı önceliği
// ("yukarı yürüyünce otun arkasında, aşağı yürüyünce önünde").
// Eski sallantı.gdshader geri dönülebilsin diye olduğu gibi duruyor. Sorunları: yüksekliği ATLAS UV'sinden hesaplıyordu
// (karonun kendisinden değil) ve 16x16 karo dörtgenini piksel-altı, yumuşak kaydırıyordu (bulanık, 2 karoluk ot ortadan
// kopabiliyor).
//
// Salınım: ot kökünden yumuşakça (texel altı) eğilir - çizim değişmez, kök hiç kıpırdamaz, uç en çok.
// Kök/boy hücre başına (veri dokusu) - scripts/grass_sway.gd oyun başında haritadaki gerçek yerleşimden hesaplar.
//
// ÖN KATMAN (on_katman = true): grass_sway.gd bu katmanların bir kopyasını karakterlerin ÜSTÜNDE çizer; kopya sadece
// kökü karakterin ayağından AŞAĞIDA (yani önünde) olan ot piksellerini ve sadece o karakterin gövdesinin üstünde çizer.

// ---------------- SALINIM
uniform float strength : hint_range(0.0, 6.0) = 1.35;          // ot ucunun en fazla kayması (texel) - hava rüzgarlıysa grass_sway.gd büyütür
uniform float salinim_hizi : hint_range(0.0, 8.0) = 1.7;
uniform float dalga_olcegi : hint_range(0.0, 0.2) = 0.035;      // yan yana otlar dalga halinde sallansın (dünya x'e göre faz)
uniform float egri_ussu : hint_range(0.5, 4.0) = 1.6;           // büyük = alt kısım daha sabit, sadece uçlar sallanır

// ---------------- RENK ÇEŞİTLİLİĞİ - eski sallantı.gdshader'ın BİREBİR aynısı (aynı ızgara, hash ve formül; değerler
// harita_baked.tscn'deki eski materyalden) ki otlar eskisi gibi görünsün.
uniform float plant_grid_size : hint_range(4.0, 64.0) = 56.795;
uniform float hue_shift_amount : hint_range(0.0, 0.2) = 0.064;
uniform float sat_shift_amount : hint_range(0.0, 0.5) = 0.15;
uniform float val_shift_amount : hint_range(0.0, 0.5) = 0.0;

// ---------------- DOLGU: TileSet "use_texture_padding" (varsayılan açık) ile Godot her karonun etrafına 1 px kenar koyan dolgulu
// bir doku üretir ve shader onu görür: karolar 16'lık değil 18'lik hücrelerde, hücrenin 1 px içinde. 16'lık bölmek karonun
// bir kısmını yan karoya ait sanıp otu parçalıyordu (ölçüldü: (1,55) dokuda (19, 991)'de). grass_sway.gd yazar.
uniform float karo_hucre = 18.0;
uniform float karo_dolgu = 1.0;

// ---------------- HÜCRE VERİSİ (grass_sway.gd yazar): her harita hücresi için R = kökün karonun üstünden uzaklığı (texel),
// G = otun boyu - haritadaki GERÇEK yerleşimden (2 karoluk otun üst yarısı tek başına konmuşsa kökü kendi içinde).
// Veri yoksa (editör önizlemesi): kök = karonun alt kenarı.
uniform sampler2D veri : filter_nearest;
uniform bool veri_var = false;
uniform vec2 veri_baslangic = vec2(0.0);
uniform vec2 veri_boyut = vec2(1.0);
uniform vec2 hucre_ofset = vec2(-2.0, 21.0);                    // hücre (0,0)'ın dünyadaki sol-üstü
// Temas eğilmesi (grass_sway.gd her karede yazar, sadece hareketli otlar): R8 = 128 + eğilme x 16 -> ±8 texel, + = sağa.
// Oyuncu değince ot ondan uzağa eğilir ve yay gibi birkaç kez sallanıp durulur; rüzgar salınımına eklenir.
uniform sampler2D egilme_veri : filter_nearest;

// ---------------- ÖN KATMAN (grass_sway.gd yazar): karakterler[i] = (ayak x, ayak y, yarım genişlik, boy) - dünya px
uniform bool on_katman = false;
uniform int karakter_sayisi = 0;
uniform vec4 karakterler[8];

varying vec2 world_pos;
varying float v_plant_color_id;

// Eski shader'ın hash'i (renk ID'si birebir aynı çıksın diye).
float hash_eski(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	v_plant_color_id = hash_eski(floor(world_pos / plant_grid_size) + vec2(55.3, 114.7));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	// Her şey çizilen UV'den (sürekli) türetilir: tam sayıya yuvarlanmış dünya pikselinden türetmek texel sınırlarında
	// kayıp otu parçalıyordu.
	vec2 a = UV / TEXTURE_PIXEL_SIZE;            // doku texel'i (sürekli)
	vec2 karo = floor(a / karo_hucre) * karo_hucre + karo_dolgu; // karonun dokudaki sol-üstü (dolgu hariç)
	vec2 ac = a - karo;                          // karo içi 0..16 (sürekli, atlas yönünde)
	vec2 yerel = floor(ac);
	bool ayna = dFdx(UV.x) < 0.0;                // yatay çevrilmiş karo (flip_h) - ölçüldü: çevrilmişte negatif
	// Karonun dünyadaki sol-üstü: karo boyunca sabit (yuvarlama float hatasını siler).
	vec2 karo_dunya = floor(world_pos - vec2(ayna ? 16.0 - ac.x : ac.x, ac.y) + 0.5);

	// Kök ve boy: hücre verisinden (yoksa karonun alt kenarı).
	float kok = 15.0;
	float boy = 13.0;
	float egilme = 0.0;
	if (veri_var) {
		vec2 hucre = floor((karo_dunya - hucre_ofset) / 16.0 + 0.5) - veri_baslangic;
		if (hucre.x >= 0.0 && hucre.y >= 0.0 && hucre.x < veri_boyut.x && hucre.y < veri_boyut.y) {
			vec2 v = texelFetch(veri, ivec2(hucre), 0).rg * 255.0;
			if (v.y > 0.5) {
				kok = v.x;
				boy = v.y;
			}
			egilme = (texelFetch(egilme_veri, ivec2(hucre), 0).r * 255.0 - 128.0) / 16.0;
		}
	}
	float kok_dunya_y = karo_dunya.y + kok + 1.0;

	// ÖN KATMAN: sadece önünde durduğu karakterin gövdesinde çiz.
	if (on_katman) {
		bool onde = false;
		for (int i = 0; i < 8; i++) {
			if (i >= karakter_sayisi) { break; }
			vec4 c = karakterler[i];
			if (kok_dunya_y > c.y && abs(world_pos.x - c.x) <= c.z && world_pos.y >= c.y - c.w && world_pos.y <= c.y + 1.0) {
				onde = true;
				break;
			}
		}
		if (!onde) { discard; }
	}

	// Salınım: ot kökünden YUMUŞAKÇA eğilir (eski shader gibi bütün halinde - çizim hiç değişmez). Kayma kökten yüksekliğe
	// göre sürekli (texel altı) hesaplanır; 2026-09-26 ilk denemedeki "her satır tam texel kaysın" ince çapraz yaprakları
	// kopuk basamaklara bölüp çizimi bozuyordu (kullanıcı: "eski hali gibi görünüp sallanmasını istedim, şu an çok çirkin").
	// Faz: otun dünya konumu (2 karoluk otun iki yarısı aynı eğriyle).
	float faz = hash12(vec2(karo_dunya.x, kok_dunya_y));
	float h = kok + 1.0 - ac.y;
	float k = pow(clamp(h / max(boy, 1.0), 0.0, 1.0), egri_ussu);
	float t = TIME * salinim_hizi + faz * 6.2832 + karo_dunya.x * dalga_olcegi;
	float sway = strength * (sin(t) * 0.8 + sin(t * 2.3 + faz * 3.1) * 0.2) + egilme;
	float kaynak = ac.x - (ayna ? -sway * k : sway * k); // içerik ekranda sağa (sway > 0) kayar
	if (kaynak < 0.0 || kaynak >= 16.0) {
		discard;
	}
	float kaynak_x = floor(kaynak);
	// textureLod 0: hesaplanan UV texel kenarlarında sıçradığı için texture() yanlış (düşük) mip seçip rengi koyulaştırıyordu.
	vec4 col = textureLod(TEXTURE, (karo + vec2(kaynak_x, yerel.y) + 0.5) * TEXTURE_PIXEL_SIZE, 0.0);
	if (col.a < 0.01) {
		discard;
	}
	// Renk: eski shader'ın birebir aynısı.
	if (col.a > 0.3) {
		vec3 hsv = rgb2hsv(col.rgb);
		hsv.x += (v_plant_color_id - 0.5) * 2.0 * hue_shift_amount;
		hsv.y += (fract(v_plant_color_id * 3.7) - 0.5) * 2.0 * sat_shift_amount;
		hsv.z += (fract(v_plant_color_id * 7.1) - 0.5) * 2.0 * val_shift_amount;
		hsv.y = clamp(hsv.y, 0.0, 1.0);
		hsv.z = clamp(hsv.z, 0.0, 1.0);
		col.rgb = hsv2rgb(hsv);
	}
	COLOR = col;
}
