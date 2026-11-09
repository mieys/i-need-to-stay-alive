extends Node

## Madde 493: altın hediyesi alıcıda üst ortada dikkat çeken levha (scripts/gift_notice.gd, main.gd show_gift_notice).

const GiftNoticeScript := preload("res://scripts/gift_notice.gd")


func test_layout_on_pixel_grid_and_counts_up() -> void:
	var n: Control = GiftNoticeScript.make("Mira", 250, 10)
	add_child(n)
	var w: float = n.size.x
	var h: float = n.size.y
	var start: int = int(n.call("shown_amount"))
	n.set("_t", 5.0)
	var done: int = int(n.call("shown_amount"))
	var long_name: Control = GiftNoticeScript.make("Çokuzunbiroyuncuadıburadaduruyorvesığmaz", 10, 0)
	var long_w: float = long_name.size.x
	n.queue_free()
	long_name.free()
	assert(h == 102.0 and w >= 300.0, "levha boyu: %s" % str(Vector2(w, h)))
	assert(is_equal_approx(fmod(w, 3.0), 0.0), "genişlik 3 px ızgarasında: %s" % w)
	assert(start == 0 and done == 250, "miktar 0'dan sayar: %d -> %d" % [start, done])
	assert(long_w <= 900.0, "uzun ad kısalır, levha taşmaz: %s" % long_w)


func test_receiver_shows_notice() -> void:
	var nm_src: String = FileAccess.get_file_as_string("res://scripts/network_manager.gd")
	var i: int = nm_src.find("func receive_gold_gift(")
	var j: int = nm_src.find("\nfunc ", i + 10)
	var body: String = nm_src.substr(i, j - i)
	assert(body.find("show_gift_notice") != -1, "alıcı (receive_gold_gift) hediye levhasını göstermeli")
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(main_src.find("func show_gift_notice(") != -1 and main_src.find("_present_notice(n, GIFT_NOTICE_HOLD, true)") != -1,
			"main.gd üst ortada (top_center) sunmalı")
