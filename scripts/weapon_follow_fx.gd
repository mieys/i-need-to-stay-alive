class_name WeaponFollowFx
extends RefCounted

## Süzülen silah takibinin görseli (madde 247): en üst kademede UÇ PARILTISI. Yerel weapon.gd ve uzak kukla remote_player.gd
## aynı fonksiyonu kullanır; kural WeaponFollowMath'te. (Silahların arkasındaki ardıl görüntü / iz 2026-10-18'de kaldırıldı, madde 255.)

const GlintScript := preload("res://scripts/weapon_tip_glint.gd")
const WeaponTipScript := preload("res://scripts/weapon_tip.gd")


## Uç parıltısı ("şing"): ikonun çizili ucunda 4 kollu piksel yıldız, ikonu izler. Sadece en üst kademe (çağıran denetler).
static func spawn_glint(host: Node, icon: Node2D, forward_deg: float) -> void:
	if host == null or icon == null or not is_instance_valid(icon) or not host.is_inside_tree():
		return
	var g: Node2D = GlintScript.new()
	g.top_level = true
	host.add_child(g)
	g.setup(icon, forward_deg)
