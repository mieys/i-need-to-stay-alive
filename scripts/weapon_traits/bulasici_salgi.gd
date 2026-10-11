extends "res://scripts/enchant_behavior.gd"

## Bulaşıcı Salgı (Tüftüf, kalıcı özellik) - bkz. EnchantDefs "bulasici_salgi". Zehrin kendisi ortak poison_* anahtarlarıyla
## (enchant_behavior.gd _generic_hit -> apply_poison_to). Burada sadece bulaşma: zehir parametrelerine enemy.gd "plague"
## eklenir (ölünce, yükleri plague_ratio oranında plague_radius içindeki en çok 6 düşmana kalan süreyle bulaşır; bulaşanlar da
## aynı bulaşmayı taşır = zincirleme salgın). refresh false: kalan süre korunur (4 sn'lik zehir ölümden sonra yeniden 4 sn olmaz).


func poison_extra() -> Dictionary:
	return {"plague": {"radius": f("plague_radius", 100.0), "ratio": f("plague_ratio", 1.0), "refresh": false}}
