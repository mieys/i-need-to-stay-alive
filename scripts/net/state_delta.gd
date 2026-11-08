extends RefCounted

## OYUNCU DURUM PAKETİ DELTASI (madde 419; madde 349 bulgu 4: extra_state 1,4 KB, her değişimde tamamı, oyuncu sayısının karesiyle büyür).
## main.gd _send_player_state / _rpc_player_state kullanır: durum sözlüğü (hp, max_hp, s_hp, s_max, p_zone, dead, weapon_keys, extra) tek düz
## sözlüğe çevrilir (üst alanlar "_" önekli, extra anahtarları aynen - extra'da "_" ile başlayan anahtar YOK, ekleme), iki düz durumun farkı
## yalnız değişen/eklenen anahtarları (silinen = null) taşır, alıcı farkı önbelleğine uygular.
## (class_name YOK: başsız çalıştırmalarda yeni genel sınıflar görünmez - preload ile kullan.)

const TOP_KEYS: Array[String] = ["hp", "max_hp", "s_hp", "s_max", "p_zone", "dead", "weapon_keys"]


## Durum sözlüğü -> düz sözlük. Değerler paylaşılır (çağıran gerekiyorsa kopyalasın).
static func flatten(state: Dictionary) -> Dictionary:
	var flat: Dictionary = (state.get("extra", {}) as Dictionary).duplicate()
	for k in TOP_KEYS:
		flat["_" + k] = state.get(k)
	return flat


## Eski -> yeni düz durum farkı: değişen/eklenen anahtar = yeni değer, silinen anahtar = null. Tür değişimi (0 -> 0.0) de fark sayılır.
static func diff(old: Dictionary, new: Dictionary) -> Dictionary:
	var d: Dictionary = {}
	for k in new.keys():
		if not old.has(k) or typeof(old[k]) != typeof(new[k]) or old[k] != new[k]:
			d[k] = new[k]
	for k in old.keys():
		if not new.has(k):
			d[k] = null
	return d


## Alıcı önbelleğine fark uygular (null = sil).
static func apply(cache: Dictionary, delta: Dictionary) -> void:
	for k in delta.keys():
		if delta[k] == null:
			cache.erase(k)
		else:
			cache[k] = delta[k]


## Düz önbellekten extra sözlüğü (derin kopya: alıcı kodu değiştirse de önbellek bozulmaz).
static func extra_of(cache: Dictionary) -> Dictionary:
	var extra: Dictionary = {}
	for k in cache.keys():
		if not str(k).begins_with("_"):
			var v: Variant = cache[k]
			extra[k] = (v as Array).duplicate(true) if v is Array else ((v as Dictionary).duplicate(true) if v is Dictionary else v)
	return extra
