#include "enemy_sim_bench.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/time.hpp>

#include <cmath>
#include <algorithm>

using namespace godot;

static constexpr float SEP_CELL = 32.0f;
static constexpr float SEP_DIST = 22.0f;
static constexpr float ATTACK_RANGE = 40.0f;
static constexpr int FLOW_RADIUS_CELLS = 70;

void EnemySimBench::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup_grid", "blocked", "origin", "size", "cell", "layer_origin"), &EnemySimBench::setup_grid);
	ClassDB::bind_method(D_METHOD("add", "pos", "speed"), &EnemySimBench::add);
	ClassDB::bind_method(D_METHOD("set_player", "pos"), &EnemySimBench::set_player);
	ClassDB::bind_method(D_METHOD("step", "delta"), &EnemySimBench::step);
	ClassDB::bind_method(D_METHOD("get_positions"), &EnemySimBench::get_positions);
	ClassDB::bind_method(D_METHOD("get_velocities"), &EnemySimBench::get_velocities);
	ClassDB::bind_method(D_METHOD("get_last_ms"), &EnemySimBench::get_last_ms);
	ClassDB::bind_method(D_METHOD("get_count"), &EnemySimBench::get_count);
}

void EnemySimBench::setup_grid(const PackedByteArray &p_blocked, const Vector2i &p_origin, const Vector2i &p_size, float p_cell,
		const Vector2 &p_layer_origin) {
	gox = p_origin.x;
	goy = p_origin.y;
	gw = p_size.x;
	gh = p_size.y;
	cell = p_cell;
	lox = p_layer_origin.x;
	loy = p_layer_origin.y;
	blocked.assign(p_blocked.ptr(), p_blocked.ptr() + p_blocked.size());
	const size_t cells = (size_t)gw * (size_t)gh;
	dist.assign(cells, 0);
	work.assign(cells, 0);
	dist_stamp.assign(cells, 0);
	work_stamp.assign(cells, 0);
	queue.assign(cells, 0);
	bw = (int)std::ceil((float)gw * cell / SEP_CELL) + 2;
	bh = (int)std::ceil((float)gh * cell / SEP_CELL) + 2;
	box = lox + (float)gox * cell - SEP_CELL;
	boy = loy + (float)goy * cell - SEP_CELL;
	bucket_head.assign((size_t)bw * (size_t)bh, -1);
}

void EnemySimBench::add(const Vector2 &p_pos, float p_speed) {
	px.push_back(p_pos.x);
	py.push_back(p_pos.y);
	vx.push_back(0.0f);
	vy.push_back(0.0f);
	speed.push_back(p_speed);
	slow_t.push_back(0.0f);
	atk_cd.push_back(0.0f);
	frame_t.push_back(0.0f);
	bucket_next.push_back(-1);
	n++;
}

void EnemySimBench::set_player(const Vector2 &p_pos) {
	player_x = p_pos.x;
	player_y = p_pos.y;
}

inline bool EnemySimBench::solid_world(float x, float y) const {
	const int cx = (int)std::floor((x - lox) / cell) - gox;
	const int cy = (int)std::floor((y - loy) / cell) - goy;
	if (cx < 0 || cy < 0 || cx >= gw || cy >= gh) {
		return true;
	}
	return blocked[(size_t)cy * gw + cx] != 0;
}

void EnemySimBench::rebuild_flow(int pcx, int pcy) {
	work_gen++;
	const int tx = pcx - gox, ty = pcy - goy;
	if (tx < 0 || ty < 0 || tx >= gw || ty >= gh) {
		return;
	}
	int head = 0, tail = 0;
	const int i0 = ty * gw + tx;
	work[i0] = 0;
	work_stamp[i0] = work_gen;
	queue[tail++] = i0;
	const int32_t wg = work_gen;
	while (head < tail) {
		const int idx = queue[head++];
		const int d = work[idx] + 1;
		if (d > FLOW_RADIUS_CELLS) {
			continue;
		}
		const int x = idx % gw, y = idx / gw;
		const int nb[4][2] = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } };
		for (int k = 0; k < 4; k++) {
			const int nx = x + nb[k][0], ny = y + nb[k][1];
			if (nx < 0 || ny < 0 || nx >= gw || ny >= gh) {
				continue;
			}
			const int ni = ny * gw + nx;
			if (blocked[ni] != 0 || (work_stamp[ni] == wg && work[ni] <= d)) {
				continue;
			}
			work[ni] = d;
			work_stamp[ni] = wg;
			queue[tail++] = ni;
		}
	}
	std::swap(dist, work);
	std::swap(dist_stamp, work_stamp);
	std::swap(dist_gen, work_gen);
	work_gen = std::max(work_gen, dist_gen);
	flow_cx = pcx;
	flow_cy = pcy;
}

void EnemySimBench::flow_dir(float x, float y, float &dx, float &dy) const {
	dx = 0.0f;
	dy = 0.0f;
	const int cx = (int)std::floor((x - lox) / cell) - gox;
	const int cy = (int)std::floor((y - loy) / cell) - goy;
	if (cx < 1 || cy < 1 || cx >= gw - 1 || cy >= gh - 1) {
		return;
	}
	const int i = cy * gw + cx;
	const int32_t g = dist_gen;
	if (dist_stamp[i] != g) {
		return;
	}
	int best = dist[i];
	const int nbi[4] = { i + 1, i - 1, i + gw, i - gw };
	const float ndx[4] = { 1, -1, 0, 0 }, ndy[4] = { 0, 0, 1, -1 };
	for (int k = 0; k < 4; k++) {
		const int j = nbi[k];
		if (dist_stamp[j] == g && dist[j] < best) {
			best = dist[j];
			dx = ndx[k];
			dy = ndy[k];
		}
	}
}

void EnemySimBench::step(float delta) {
	const uint64_t t0 = Time::get_singleton()->get_ticks_usec();
	const int pcx = (int)std::floor((player_x - lox) / cell);
	const int pcy = (int)std::floor((player_y - loy) / cell);
	if (pcx != flow_cx || pcy != flow_cy) {
		rebuild_flow(pcx, pcy);
	}
	const uint64_t t1 = Time::get_singleton()->get_ticks_usec();

	// uzamsal ızgara
	for (int b : used_buckets) {
		bucket_head[b] = -1;
	}
	used_buckets.clear();
	for (int i = 0; i < n; i++) {
		const int bx = std::clamp((int)((px[i] - box) / SEP_CELL), 0, bw - 1);
		const int by = std::clamp((int)((py[i] - boy) / SEP_CELL), 0, bh - 1);
		const int bi = by * bw + bx;
		if (bucket_head[bi] == -1) {
			used_buckets.push_back(bi);
		}
		bucket_next[i] = bucket_head[bi];
		bucket_head[bi] = i;
	}

	const float sep2 = SEP_DIST * SEP_DIST;
	for (int i = 0; i < n; i++) {
		const float x = px[i], y = py[i];
		const float tpx = player_x - x, tpy = player_y - y;
		const float dist_p = std::sqrt(tpx * tpx + tpy * tpy);
		float wx = 0.0f, wy = 0.0f;
		if (dist_p < ATTACK_RANGE) {
			atk_cd[i] = std::max(0.0f, atk_cd[i] - delta);
			if (atk_cd[i] <= 0.0f) {
				atk_cd[i] = 1.2f;
			}
		} else if (dist_p < 120.0f) {
			wx = tpx / dist_p;
			wy = tpy / dist_p;
		} else {
			flow_dir(x, y, wx, wy);
			if (wx == 0.0f && wy == 0.0f) {
				wx = tpx / dist_p;
				wy = tpy / dist_p;
			}
		}
		float pushx = 0.0f, pushy = 0.0f;
		const int bx = (int)((x - box) / SEP_CELL), by = (int)((y - boy) / SEP_CELL);
		for (int oy = -1; oy <= 1; oy++) {
			const int yy = by + oy;
			if (yy < 0 || yy >= bh) {
				continue;
			}
			for (int ox = -1; ox <= 1; ox++) {
				const int xx = bx + ox;
				if (xx < 0 || xx >= bw) {
					continue;
				}
				for (int j = bucket_head[yy * bw + xx]; j != -1; j = bucket_next[j]) {
					if (j == i) {
						continue;
					}
					const float dx = x - px[j], dy = y - py[j];
					const float d2 = dx * dx + dy * dy;
					if (d2 < sep2 && d2 > 0.0001f) {
						const float d = std::sqrt(d2);
						const float f = (1.0f - d / SEP_DIST) / d;
						pushx += dx * f;
						pushy += dy * f;
					}
				}
			}
		}
		const float sp = speed[i] * (slow_t[i] > 0.0f ? 0.5f : 1.0f);
		slow_t[i] = std::max(0.0f, slow_t[i] - delta);
		const float vxx = wx * sp + pushx * 60.0f, vyy = wy * sp + pushy * 60.0f;
		float nx = x + vxx * delta, ny = y + vyy * delta;
		if (solid_world(nx, y)) {
			nx = x;
		}
		if (solid_world(nx, ny)) {
			ny = y;
		}
		px[i] = nx;
		py[i] = ny;
		vx[i] = vxx;
		vy[i] = vyy;
		frame_t[i] += delta * 8.0f;
	}
	const uint64_t t2 = Time::get_singleton()->get_ticks_usec();
	last_flow_ms = (double)(t1 - t0) / 1000.0;
	last_sim_ms = (double)(t2 - t1) / 1000.0;
}

PackedVector2Array EnemySimBench::get_positions() const {
	PackedVector2Array out;
	out.resize(n);
	Vector2 *w = out.ptrw();
	for (int i = 0; i < n; i++) {
		w[i] = Vector2(px[i], py[i]);
	}
	return out;
}

PackedVector2Array EnemySimBench::get_velocities() const {
	PackedVector2Array out;
	out.resize(n);
	Vector2 *w = out.ptrw();
	for (int i = 0; i < n; i++) {
		w[i] = Vector2(vx[i], vy[i]);
	}
	return out;
}

Dictionary EnemySimBench::get_last_ms() const {
	Dictionary d;
	d["flow_ms"] = last_flow_ms;
	d["sim_ms"] = last_sim_ms;
	return d;
}
