// Aşama 0 - C++ prototipi (docs/yaratik_yeniden_yazim/PLAN.md §5). bench_soa_gd.gd ile BİREBİR aynı algoritma:
// akış alanı (oyuncudan BFS, nesil damgalı), uzamsal ızgarayla itilme, eksen eksen duvar çarpışması, saldırı ve
// yavaşlatma sayaçları. Sadece ölçüm içindir; gerçek EnemyWorld Aşama 1'de ayrı yazılacak.
#pragma once

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include <vector>
#include <cstdint>

namespace godot {

class EnemySimBench : public Node {
	GDCLASS(EnemySimBench, Node)

	// yaratıklar (SoA)
	std::vector<float> px, py, vx, vy, speed, slow_t, atk_cd, frame_t;
	int n = 0;

	// harita ızgarası
	std::vector<uint8_t> blocked;
	int gox = 0, goy = 0, gw = 0, gh = 0;
	float cell = 16.0f, lox = 0.0f, loy = 0.0f;

	// akış alanı (çift tampon + nesil damgası)
	std::vector<int32_t> dist, work, dist_stamp, work_stamp, queue;
	int32_t dist_gen = 0, work_gen = 0;
	int flow_cx = -99999, flow_cy = -99999;

	// uzamsal ızgara
	std::vector<int32_t> bucket_head, bucket_next, used_buckets;
	int bw = 0, bh = 0;
	float box = 0.0f, boy = 0.0f;

	float player_x = 0.0f, player_y = 0.0f;
	double last_flow_ms = 0.0, last_sim_ms = 0.0;

	inline bool solid_world(float x, float y) const;
	void rebuild_flow(int pcx, int pcy);
	void flow_dir(float x, float y, float &dx, float &dy) const;

protected:
	static void _bind_methods();

public:
	void setup_grid(const PackedByteArray &p_blocked, const Vector2i &p_origin, const Vector2i &p_size, float p_cell,
			const Vector2 &p_layer_origin);
	void add(const Vector2 &p_pos, float p_speed);
	void set_player(const Vector2 &p_pos);
	void step(float delta);
	PackedVector2Array get_positions() const;
	PackedVector2Array get_velocities() const;
	Dictionary get_last_ms() const;
	int get_count() const { return n; }
};

} // namespace godot
