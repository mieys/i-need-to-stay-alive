extends RefCounted

## Harita gölgeleri - kullanıcı isteği (2026-10-02): "oyunuma gölge sistemi eklemek istiyorum", 4 prototipten "B - Tepe
## gölgesi" seçildi (kaya düzeltmeleriyle). Yönsüz ve saatten bağımsız: güneş tam tepede - ağaç tacının ezilmiş gölgeliği
## gövdenin dibinde, kaya/kütük/çalı gibi yerdeki objelerin alt hattında ince hilal, ev/tarla/uçurumda alt kenar şeridi.
## (1 Ekim'de güneşe göre eğilen gölgeler "3D gibi" bulunup geri alınmıştı - yön/uzama EKLEME.)
##
## Gölgeler oyunda HESAPLANMAZ: tools/bake_map_shadows.gd + .py haritadan bir kez tek kanallı bir doku pişirir
## (assets/map/harita_golgeleri.png, 4096x4096 = harita, 1 piksel = 1 harita texel'i, değer = gölge yoğunluğu). Burada o doku
## tek bir Sprite2D olarak zemin+su katmanlarının HEMEN üstüne, tüm objelerin altına eklenir ve çarpma (multiply) karışımıyla
## çizilir: renk = mix(beyaz, TINT, yoğunluk). Kare başına maliyet tek bir doku çizimi; her oyuncuda aynı dosyadan aynı
## sonuç çıktığı için ağ senkronu gerekmez. Harita yeniden bake edilirse gölge dokusu da yeniden pişirilmeli (bkz. araç).
## Yerdeki küçük objelerin (sandık, altın, exp orbu, yemek, mıknatıs) gölgesi ayrı: scripts/drop_shadow.gd (aynı TINT).

const TEXTURE_PATH := "res://assets/map/harita_golgeleri.png"
## Gölge rengi (çarpılır): prototipte onaylanan serin yeşil-mavi ton. drop_shadow.gd de bunu kullanır.
const TINT := Color(0.28, 0.36, 0.42)
## Güneş kayması (kullanıcı isteği 2026-10-02: "gölgeler güneş açısıyla uyuşmuyor, biraz sola kaymaları gerekiyor"): güneş
## ışınları sağ üstten geliyor (sun_clouds.gd), gölgeler tam altta kalınca uyumsuz duruyordu. TÜM gölgeler (harita dokusu,
## karakter ayak gölgesi ground_shadow.gd, yerdeki obje gölgesi drop_shadow.gd) bu kadar dünya pikseli SOLA kayar - tek
## sabit, üçü birlikte değişir. Sadece sabit öteleme: eğme/uzatma/saate göre dönme YOK (1 Ekim'de "3D gibi" bulunup geri alındı).
const SUN_SHIFT_X := -3.0
const NODE_NAME := "Gölgeler"
## Bu katmanlardan SONRA (üstte) çizilir - zemin ve su; geri kalan her şey (orman parçaları, ev, tarla, ağaçlar...) üstte.
const AFTER_NODES := ["Yer", "Su"]

static var _material: ShaderMaterial = null


static func shadow_material() -> ShaderMaterial:
	if _material == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
render_mode blend_mul;
uniform vec3 tint = vec3(0.28, 0.36, 0.42);
void fragment() {
	float a = texture(TEXTURE, UV).r;
	COLOR = vec4(mix(vec3(1.0), tint, a), 1.0);
}
"""
		_material = ShaderMaterial.new()
		_material.shader = sh
		_material.set_shader_parameter("tint", Vector3(TINT.r, TINT.g, TINT.b))
	return _material


## main.gd _ready'de Harita düğümüyle çağrılır. Doku yoksa (henüz pişirilmemiş) sessizce hiçbir şey yapmaz.
static func attach(harita: Node) -> Sprite2D:
	if harita == null or not ResourceLoader.exists(TEXTURE_PATH) or harita.get_node_or_null(NODE_NAME) != null:
		return null
	var spr := Sprite2D.new()
	spr.name = NODE_NAME
	spr.texture = load(TEXTURE_PATH) as Texture2D
	spr.centered = false
	spr.position = Vector2(SUN_SHIFT_X, 0.0)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.material = shadow_material()
	harita.add_child(spr)
	var idx: int = 0
	for n in AFTER_NODES:
		var c: Node = harita.get_node_or_null(n)
		if c != null:
			idx = maxi(idx, c.get_index() + 1)
	harita.move_child(spr, idx)
	return spr
