// EnemyWorld - bkz. enemy_world.h ve docs/yaratik_yeniden_yazim/PLAN.md §4.1.
// Sabitler enemy.gd'deki karşılıklarıyla AYNI tutulur; birini değiştirirsen diğerini de değiştir (yeniden yazım bitene
// kadar iki yol yan yana yaşıyor).
#include "enemy_world.h"

#include <godot_cpp/classes/animated_sprite2d.hpp>
#include <godot_cpp/classes/canvas_item.hpp>
#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/classes/sprite2d.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/object.hpp>

#include <algorithm>
#include <climits>
#include <cmath>

using namespace godot;

namespace {
// enemy.gd karşılıkları
constexpr int AI_THINK_INTERVAL_FRAMES = 3;
constexpr int TARGET_UPDATE_INTERVAL_FRAMES = 4;
constexpr float ALLY_AGGRO_RADIUS = 160.0f;
constexpr float ALLY_AGGRO_BIAS = 0.35f;
constexpr float ZONE_FOCUS_MARGIN = 24.0f;
constexpr float KNOCKBACK_DECAY = 1400.0f;
constexpr float KNOCKBACK_MAX_SPEED = 400.0f;
constexpr float KNOCKBACK_CLAMP_SKIP = 40.0f; // bu hızın üstünde gövde yapıştırması atlanır
constexpr float KNOCKBACK_DISTANCE_MAX = 60.0f;
constexpr float KNOCKBACK_DISTANCE_MULT = 0.20f;
constexpr int64_t KNOCKBACK_REPEAT_WINDOW_MSEC = 700;
constexpr float KNOCKBACK_REPEAT_MULT = 0.25f;
constexpr float SKILL_PUSH_BOSS_MULT = 0.4f;
constexpr float FOREST_PROBE = 10.0f;
constexpr float MELEE_EXTRA = 26.0f; // yakın dövüşçü
constexpr float MELEE_EXTRA_RANGED = 10.0f;
constexpr float BARRIER_TOLERANCE = 24.0f;
constexpr int SEPARATION_UPDATE_INTERVAL_FRAMES = 6;
constexpr float ENEMY_SEPARATION_GAP = 2.0f;
constexpr float ENEMY_SEPARATION_CHECK_RADIUS = 100.0f;
constexpr float ENEMY_SEPARATION_FORCE = 130.0f;
constexpr float ENEMY_SEPARATION_SCALE = 0.75f;
constexpr float ENEMY_SEPARATION_SMOOTH = 0.025f;
constexpr float ENEMY_SEPARATION_DEADZONE = 0.12f;
constexpr float SEPARATION_GRID_CELL_MAX = 140.0f;
constexpr float MAX_ROUTE_DISTANCE = 1600.0f; // enemy_pathing.gd (ağaç hedefinde sınır yok)
constexpr int FLOW_RADIUS_CELLS = 100; // ~1600 dünya birimi (16 px hücre)
constexpr int LINE_CHECK_FRAMES = 12; // enemy.gd ROUTE_LINE_CHECK_INTERVAL 0,2 sn (60 Hz), yaratık başına kaydırmalı
constexpr int FLOW_LOOKAHEAD = 16; // enemy_pathing.gd SMOOTH_LOOKAHEAD: akışta en fazla bu kadar hücre ileri bakılır
constexpr float LOS_SAMPLE_STEP = 10.0f;
constexpr float LOS_END_IGNORE = 10.0f;
constexpr double LOS_CACHE_SEC = 0.150;
constexpr float RANGED_SPELL_MULT = 1.6f;
constexpr float RANGED_MAX_MULT = 2.5f;
constexpr float FEAR_WANDER_SPEED_MULT = 0.7f;
constexpr float FEAR_WANDER_TURN_MIN = 0.45f, FEAR_WANDER_TURN_MAX = 1.0f;
constexpr float STUCK_CHECK_INTERVAL = 0.4f;
constexpr float STUCK_MIN_DISPLACEMENT = 12.0f;
constexpr float STEER_PROBE = 24.0f;
constexpr float WANDER_MOVE_SPEED_MULT = 0.45f;
constexpr float WANDER_RADIUS = 120.0f;
constexpr float WANDER_ARRIVE_DIST = 12.0f;
constexpr float WANDER_MOVE_DURATION_MIN = 1.5f, WANDER_MOVE_DURATION_MAX = 3.5f;
constexpr float WANDER_PAUSE_DURATION_MIN = 1.0f, WANDER_PAUSE_DURATION_MAX = 3.0f;
constexpr float WANDER_PAUSE_CHANCE = 0.4f;
constexpr float TAU_F = 6.28318530718f;
constexpr float IDLE_SPEED_THRESHOLD = 6.0f;
constexpr float IDLE_ENTER_DELAY = 0.12f;
constexpr float IDLE_SPEED_SMOOTHING = 20.0f;
// yön satırları (enemy.gd ROW_*)
constexpr int ROW_DOWN = 0, ROW_UP = 1, ROW_LEFT = 2, ROW_RIGHT = 3;

inline float len2(float x, float y) { return x * x + y * y; }
} // namespace

void EnemyWorld::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_grid", "blocked", "origin", "size", "cell", "layer_origin", "fog_blocked"), &EnemyWorld::set_grid,
			DEFVAL(PackedByteArray()));
	ClassDB::bind_method(D_METHOD("set_targets", "pos", "kind", "targetable", "ghost", "body", "zone", "ids"), &EnemyWorld::set_targets);
	ClassDB::bind_method(D_METHOD("set_merchant_zone", "active", "pos", "radius"), &EnemyWorld::set_merchant_zone);
	ClassDB::bind_method(D_METHOD("set_body_block_scale", "scale"), &EnemyWorld::set_body_block_scale);
	ClassDB::bind_method(D_METHOD("set_extra_bodies", "pos", "radius"), &EnemyWorld::set_extra_bodies);
	ClassDB::bind_method(D_METHOD("set_hit_probe", "center", "radius"), &EnemyWorld::set_hit_probe);
	ClassDB::bind_method(D_METHOD("set_hit_radius", "slot", "radius"), &EnemyWorld::set_hit_radius);
	ClassDB::bind_method(D_METHOD("set_seed", "seed"), &EnemyWorld::set_seed);
	ClassDB::bind_method(D_METHOD("add_enemy", "node", "sprite", "pos", "params"), &EnemyWorld::add_enemy);
	ClassDB::bind_method(D_METHOD("remove_enemy", "slot"), &EnemyWorld::remove_enemy);
	ClassDB::bind_method(D_METHOD("set_flags", "slot", "flags"), &EnemyWorld::set_flags);
	ClassDB::bind_method(D_METHOD("get_flags", "slot"), &EnemyWorld::get_flags);
	ClassDB::bind_method(D_METHOD("set_speed", "slot", "speed"), &EnemyWorld::set_speed);
	ClassDB::bind_method(D_METHOD("set_radius", "slot", "radius"), &EnemyWorld::set_radius);
	ClassDB::bind_method(D_METHOD("set_speed_mult", "slot", "mult"), &EnemyWorld::set_speed_mult);
	ClassDB::bind_method(D_METHOD("set_rage_mult", "slot", "mult"), &EnemyWorld::set_rage_mult);
	ClassDB::bind_method(D_METHOD("set_position", "slot", "pos"), &EnemyWorld::set_position);
	ClassDB::bind_method(D_METHOD("set_knockback", "slot", "vel"), &EnemyWorld::set_knockback);
	ClassDB::bind_method(D_METHOD("get_knockback", "slot"), &EnemyWorld::get_knockback);
	ClassDB::bind_method(D_METHOD("set_anim", "slot", "cols", "fps", "walking", "walk_mult"), &EnemyWorld::set_anim);
	ClassDB::bind_method(D_METHOD("set_anim_state", "slot", "state", "cols", "fps", "walk_mult", "idle_tex"), &EnemyWorld::set_anim_state);
	ClassDB::bind_method(D_METHOD("set_contact", "slot", "interval", "timer"), &EnemyWorld::set_contact);
	ClassDB::bind_method(D_METHOD("set_ranged", "slot", "range", "interval", "homing_interval"), &EnemyWorld::set_ranged);
	ClassDB::bind_method(D_METHOD("set_fear_source", "slot", "pos"), &EnemyWorld::set_fear_source);
	ClassDB::bind_method(D_METHOD("set_taunt", "slot", "taunter_id", "duration"), &EnemyWorld::set_taunt);
	ClassDB::bind_method(D_METHOD("get_taunt_time", "slot"), &EnemyWorld::get_taunt_time);
	ClassDB::bind_method(D_METHOD("set_contact_timer", "slot", "t"), &EnemyWorld::set_contact_timer);
	ClassDB::bind_method(D_METHOD("get_contact_timer", "slot"), &EnemyWorld::get_contact_timer);
	ClassDB::bind_method(D_METHOD("set_ranged_timer", "slot", "t"), &EnemyWorld::set_ranged_timer);
	ClassDB::bind_method(D_METHOD("get_ranged_timer", "slot"), &EnemyWorld::get_ranged_timer);
	ClassDB::bind_method(D_METHOD("force_think", "slot"), &EnemyWorld::force_think);
	ClassDB::bind_method(D_METHOD("set_face", "slot", "dir"), &EnemyWorld::set_face);
	ClassDB::bind_method(D_METHOD("set_net_target", "slot", "pos", "vel"), &EnemyWorld::set_net_target);
	ClassDB::bind_method(D_METHOD("get_net_time", "slot"), &EnemyWorld::get_net_time);
	ClassDB::bind_method(D_METHOD("apply_knockback_force", "slot", "dir", "force"), &EnemyWorld::apply_knockback_force);
	ClassDB::bind_method(D_METHOD("apply_knockback_distance", "slot", "dir", "distance"), &EnemyWorld::apply_knockback_distance);
	ClassDB::bind_method(D_METHOD("apply_skill_push", "slot", "dir", "distance"), &EnemyWorld::apply_skill_push);
	ClassDB::bind_method(D_METHOD("get_position", "slot"), &EnemyWorld::get_position);
	ClassDB::bind_method(D_METHOD("get_prev_position", "slot"), &EnemyWorld::get_prev_position);
	ClassDB::bind_method(D_METHOD("get_target", "slot"), &EnemyWorld::get_target);
	ClassDB::bind_method(D_METHOD("get_target_dist", "slot"), &EnemyWorld::get_target_dist);
	ClassDB::bind_method(D_METHOD("get_facing_row", "slot"), &EnemyWorld::get_facing_row);
	ClassDB::bind_method(D_METHOD("get_face_left", "slot"), &EnemyWorld::get_face_left);
	ClassDB::bind_method(D_METHOD("is_wandering", "slot"), &EnemyWorld::is_wandering);
	ClassDB::bind_method(D_METHOD("get_count"), &EnemyWorld::get_count);
	ClassDB::bind_method(D_METHOD("get_hit_enter_total"), &EnemyWorld::get_hit_enter_total);
	ClassDB::bind_method(D_METHOD("is_solid_at", "pos"), &EnemyWorld::is_solid_at);
	ClassDB::bind_method(D_METHOD("is_line_blocked", "from", "to"), &EnemyWorld::is_line_blocked);
	ClassDB::bind_method(D_METHOD("is_los_clear", "from", "to"), &EnemyWorld::is_los_clear);
	ClassDB::bind_method(D_METHOD("get_positions"), &EnemyWorld::get_positions);
	ClassDB::bind_method(D_METHOD("query_circle", "center", "radius"), &EnemyWorld::query_circle);
	ClassDB::bind_method(D_METHOD("query_segment", "from", "to", "radius"), &EnemyWorld::query_segment);
	ClassDB::bind_method(D_METHOD("query_points", "center", "radius"), &EnemyWorld::query_points);
	ClassDB::bind_method(D_METHOD("fog_update", "sources", "radius", "width_scale", "softness", "hide_below", "interval", "frame"), &EnemyWorld::fog_update);
	ClassDB::bind_method(D_METHOD("fog_reset"), &EnemyWorld::fog_reset);
	ClassDB::bind_method(D_METHOD("query_nearest", "origin", "min_vis"), &EnemyWorld::query_nearest);
	ClassDB::bind_method(D_METHOD("foot_missing"), &EnemyWorld::foot_missing);
	ClassDB::bind_method(D_METHOD("set_foot", "slot", "visual", "local"), &EnemyWorld::set_foot);
	ClassDB::bind_method(D_METHOD("draw_order", "parent", "extras", "extras_foot"), &EnemyWorld::draw_order);
	ClassDB::bind_method(D_METHOD("get_last_draw_order"), &EnemyWorld::get_last_draw_order);
	ClassDB::bind_method(D_METHOD("minimap_points", "center", "world_per_px", "max_r", "min_vis"), &EnemyWorld::minimap_points);
	ClassDB::bind_method(D_METHOD("step", "delta"), &EnemyWorld::step);
	ClassDB::bind_method(D_METHOD("pop_events"), &EnemyWorld::pop_events);
	ClassDB::bind_method(D_METHOD("get_last_step_ms"), &EnemyWorld::get_last_step_ms);
	ClassDB::bind_method(D_METHOD("get_last_view_ms"), &EnemyWorld::get_last_view_ms);

	BIND_ENUM_CONSTANT(F_DEAD);
	BIND_ENUM_CONSTANT(F_FROZEN);
	BIND_ENUM_CONSTANT(F_ROOTED);
	BIND_ENUM_CONSTANT(F_ATTACK_LOCK);
	BIND_ENUM_CONSTANT(F_ABILITY_LOCK);
	BIND_ENUM_CONSTANT(F_RANGED);
	BIND_ENUM_CONSTANT(F_BOSS);
	BIND_ENUM_CONSTANT(F_GHOST_INVISIBLE);
	BIND_ENUM_CONSTANT(F_STATUS_ACTIVE);
	BIND_ENUM_CONSTANT(F_NO_SIM);
	BIND_ENUM_CONSTANT(F_FEAR_FLEE);
	BIND_ENUM_CONSTANT(F_FEAR_WANDER);
	BIND_ENUM_CONSTANT(F_UNTARGETABLE);
	BIND_ENUM_CONSTANT(F_PUPPET);
	BIND_ENUM_CONSTANT(T_PLAYER);
	BIND_ENUM_CONSTANT(T_REMOTE);
	BIND_ENUM_CONSTANT(T_ALLY);
	BIND_ENUM_CONSTANT(T_TREE);
	BIND_ENUM_CONSTANT(E_MELEE);
	BIND_ENUM_CONSTANT(E_BARRIER_HIT);
	BIND_ENUM_CONSTANT(E_GHOST_REVEAL);
	BIND_ENUM_CONSTANT(E_RANGED_FIRE);
	BIND_ENUM_CONSTANT(E_HOMING_FIRE);
	BIND_ENUM_CONSTANT(E_TAUNT_LOST);
	BIND_ENUM_CONSTANT(E_LOCO);
	BIND_ENUM_CONSTANT(A_WALK);
	BIND_ENUM_CONSTANT(A_IDLE);
	BIND_ENUM_CONSTANT(A_OTHER);
}

// ===================================================================================================== kurulum

void EnemyWorld::set_grid(const PackedByteArray &p_blocked, const Vector2i &p_origin, const Vector2i &p_size, float p_cell,
		const Vector2 &p_layer_origin, const PackedByteArray &p_fog_blocked) {
	gox = p_origin.x;
	goy = p_origin.y;
	gw = p_size.x;
	gh = p_size.y;
	cell = p_cell;
	lox = p_layer_origin.x;
	loy = p_layer_origin.y;
	blocked.assign(p_blocked.ptr(), p_blocked.ptr() + p_blocked.size());
	// Görüş (sis) ızgarası: SADECE orman duvarı. Hareket/yol ızgarası (blocked) su + bina tabanı + ağaç gövdesi + maden gibi
	// geçilmez ama görüşü KESMEYEN nesneleri de içerir (2026-10-08); verilmezse (boş / boyut uymuyor) sis da blocked'ı kullanır.
	if (p_fog_blocked.size() == p_blocked.size() && p_fog_blocked.size() > 0) {
		fog_blocked.assign(p_fog_blocked.ptr(), p_fog_blocked.ptr() + p_fog_blocked.size());
	} else {
		fog_blocked.clear();
	}
	bfs_queue.assign((size_t)gw * (size_t)gh, 0);
	for (Flow &f : flows) {
		f.dist.clear();
		f.stamp.clear();
		f.cx = f.cy = -99999;
		f.owner = 0;
	}
}

void EnemyWorld::set_targets(const PackedVector2Array &p_pos, const PackedInt32Array &p_kind, const PackedByteArray &p_targetable,
		const PackedByteArray &p_ghost, const PackedFloat32Array &p_body, const PackedFloat32Array &p_zone,
		const PackedInt64Array &p_ids) {
	const int n = p_pos.size();
	tx.resize(n);
	ty.resize(n);
	t_kind.resize(n);
	t_targetable.resize(n);
	t_ghost.resize(n);
	t_body.resize(n);
	t_zone.resize(n);
	t_id.resize(n);
	tree_index = -1;
	for (int i = 0; i < n; i++) {
		tx[i] = p_pos[i].x;
		ty[i] = p_pos[i].y;
		t_kind[i] = i < p_kind.size() ? p_kind[i] : T_PLAYER;
		t_targetable[i] = i < p_targetable.size() ? p_targetable[i] : 1;
		t_ghost[i] = i < p_ghost.size() ? p_ghost[i] : 0;
		t_body[i] = i < p_body.size() ? p_body[i] : 11.4f;
		t_zone[i] = i < p_zone.size() ? p_zone[i] : 0.0f;
		t_id[i] = i < p_ids.size() ? (uint64_t)p_ids[i] : (uint64_t)(i + 1);
		if (t_kind[i] == T_TREE && t_targetable[i]) {
			tree_index = i;
		}
	}
	if ((int)flows.size() < n) {
		flows.resize(n);
	}
}

void EnemyWorld::set_extra_bodies(const PackedVector2Array &p_pos, const PackedFloat32Array &p_radius) {
	const int n = p_pos.size();
	ext_x.resize(n);
	ext_y.resize(n);
	ext_r.resize(n);
	for (int k = 0; k < n; k++) {
		ext_x[k] = p_pos[k].x;
		ext_y[k] = p_pos[k].y;
		ext_r[k] = k < p_radius.size() ? p_radius[k] : 20.0f;
	}
}

void EnemyWorld::set_merchant_zone(bool p_active, const Vector2 &p_pos, float p_radius) {
	merchant_active = p_active;
	merchant_x = p_pos.x;
	merchant_y = p_pos.y;
	merchant_r = p_radius;
}

// ===================================================================================================== yaşam döngüsü

void EnemyWorld::ensure_capacity(int32_t n) {
	if ((int32_t)alive.size() >= n) {
		return;
	}
	const size_t s = (size_t)n;
	alive.resize(s, 0);
	node_id.resize(s, 0);
	sprite_id.resize(s, 0);
	anim_sprite_id.resize(s, 0);
	px.resize(s, 0.0f);
	py.resize(s, 0.0f);
	prev_x.resize(s, 0.0f);
	prev_y.resize(s, 0.0f);
	cur_target.resize(s, -1);
	ivx.resize(s, 0.0f);
	ivy.resize(s, 0.0f);
	kvx.resize(s, 0.0f);
	kvy.resize(s, 0.0f);
	sepx.resize(s, 0.0f);
	sepy.resize(s, 0.0f);
	sep_tx.resize(s, 0.0f);
	sep_ty.resize(s, 0.0f);
	radius.resize(s, 20.0f);
	speed.resize(s, 0.0f);
	speed_mult.resize(s, 1.0f);
	rage_mult.resize(s, 1.0f);
	flags.resize(s, 0);
	contact_interval.resize(s, 1.0f);
	contact_timer.resize(s, 0.0f);
	target.resize(s, -1);
	closest.resize(s, -1);
	target_dist.resize(s, 0.0f);
	ai_true_contact.resize(s, 0.0f);
	ai_min_sep.resize(s, 0.0f);
	ai_accum.resize(s, 0.0f);
	has_decision.resize(s, 0);
	wandering.resize(s, 0);
	routing.resize(s, 0);
	facing_row.resize(s, ROW_DOWN);
	face_left.resize(s, 0);
	anim_t.resize(s, 0.0f);
	anim_fps.resize(s, 8.0f);
	walk_anim_mult.resize(s, 1.0f);
	anim_cols.resize(s, 1);
	anim_walking.resize(s, 1);
	anim_state.resize(s, A_WALK);
	anim_idle_tex.resize(s, 0);
	anim_pending.resize(s, 0);
	loco_px.resize(s, 0.0f);
	loco_py.resize(s, 0.0f);
	loco_speed.resize(s, 0.0f);
	idle_timer.resize(s, 0.0f);
	loco_init.resize(s, 0);
	view_flip.resize(s, -1);
	line_blocked.resize(s, 0);
	line_target.resize(s, -1);
	view_x.resize(s, NAN);
	view_y.resize(s, NAN);
	view_frame.resize(s, -1);
	taunt_id.resize(s, 0);
	taunt_t.resize(s, 0.0f);
	fear_x.resize(s, 0.0f);
	fear_y.resize(s, 0.0f);
	fear_wdx.resize(s, 1.0f);
	fear_wdy.resize(s, 0.0f);
	fear_retarget.resize(s, 0.0f);
	ranged_range.resize(s, 0.0f);
	ranged_interval.resize(s, 2.0f);
	homing_interval.resize(s, 2.0f);
	ranged_timer.resize(s, 0.0f);
	los_target.resize(s, 0);
	los_until.resize(s, 0.0);
	los_value.resize(s, 1);
	stuck_timer.resize(s, 0.0f);
	stuck_x.resize(s, 0.0f);
	stuck_y.resize(s, 0.0f);
	stuck_side.resize(s, 1.0f);
	is_stuck.resize(s, 0);
	wander_x.resize(s, 0.0f);
	wander_y.resize(s, 0.0f);
	wander_timer.resize(s, 0.0f);
	wander_moving.resize(s, 0);
	last_kb_msec.resize(s, -100000);
	hit_radius.resize(s, 0.0f);
	hit_inside.resize(s, 0);
	fog_init.resize(s, 0);
	fog_vis.resize(s, 0.0f);
	net_x.resize(s, 0.0f);
	net_y.resize(s, 0.0f);
	net_vx.resize(s, 0.0f);
	net_vy.resize(s, 0.0f);
	net_t.resize(s, 0.0f);
	net_received.resize(s, 0);
	foot_vis_id.resize(s, 0);
	foot_local.resize(s, 0.0f);
	foot_known.resize(s, 0);
	draw_given.resize(s, -1);
	draw_tree.resize(s, -1);
	bucket_next.resize(s, -1);
}

int32_t EnemyWorld::add_enemy(Object *p_node, Object *p_sprite, const Vector2 &p_pos, const Dictionary &p_params) {
	int32_t i;
	if (!free_slots.empty()) {
		i = free_slots.back();
		free_slots.pop_back();
	} else {
		i = slot_count++;
		ensure_capacity(slot_count);
	}
	alive[i] = 1;
	node_id[i] = p_node ? p_node->get_instance_id() : 0;
	sprite_id[i] = p_sprite ? p_sprite->get_instance_id() : 0;
	{
		Object *as = p_params.has("anim_sprite") ? (Object *)p_params["anim_sprite"] : nullptr;
		anim_sprite_id[i] = as ? as->get_instance_id() : 0;
	}
	px[i] = p_pos.x;
	py[i] = p_pos.y;
	prev_x[i] = p_pos.x;
	prev_y[i] = p_pos.y;
	cur_target[i] = -1;
	ivx[i] = ivy[i] = kvx[i] = kvy[i] = 0.0f;
	sepx[i] = sepy[i] = sep_tx[i] = sep_ty[i] = 0.0f;
	radius[i] = (float)p_params.get("radius", 20.0);
	speed[i] = (float)p_params.get("speed", 50.0);
	speed_mult[i] = 1.0f;
	rage_mult[i] = 1.0f;
	flags[i] = (uint32_t)(int64_t)p_params.get("flags", 0);
	contact_interval[i] = (float)p_params.get("contact_interval", 1.0);
	contact_timer[i] = 0.0f;
	target[i] = -1;
	closest[i] = -1;
	target_dist[i] = 0.0f;
	ai_true_contact[i] = ai_min_sep[i] = ai_accum[i] = 0.0f;
	has_decision[i] = wandering[i] = routing[i] = 0;
	facing_row[i] = ROW_DOWN;
	face_left[i] = 0;
	anim_t[i] = 0.0f;
	anim_fps[i] = (float)p_params.get("fps", 8.0);
	anim_cols[i] = std::max(1, (int)p_params.get("cols", 1));
	walk_anim_mult[i] = 1.0f;
	anim_walking[i] = (bool)p_params.get("walking", true) ? 1 : 0;
	anim_state[i] = A_WALK;
	anim_idle_tex[i] = (bool)p_params.get("idle_tex", false) ? 1 : 0;
	walk_anim_mult[i] = (float)p_params.get("walk_mult", 1.0);
	anim_pending[i] = 0;
	loco_speed[i] = idle_timer[i] = 0.0f;
	loco_init[i] = 0;
	view_flip[i] = -1;
	line_blocked[i] = 0;
	line_target[i] = -1;
	view_x[i] = view_y[i] = NAN;
	view_frame[i] = -1;
	taunt_id[i] = 0;
	taunt_t[i] = 0.0f;
	fear_x[i] = fear_y[i] = 0.0f;
	fear_wdx[i] = 1.0f;
	fear_wdy[i] = 0.0f;
	fear_retarget[i] = 0.0f;
	ranged_range[i] = (float)p_params.get("ranged_range", 0.0);
	ranged_interval[i] = (float)p_params.get("ranged_interval", 2.0);
	homing_interval[i] = (float)p_params.get("homing_interval", 2.0);
	ranged_timer[i] = 0.0f;
	los_target[i] = 0;
	los_until[i] = 0.0;
	los_value[i] = 1;
	stuck_timer[i] = 0.0f;
	stuck_x[i] = px[i];
	stuck_y[i] = py[i];
	stuck_side[i] = 1.0f;
	is_stuck[i] = 0;
	wander_x[i] = wander_y[i] = wander_timer[i] = 0.0f;
	wander_moving[i] = 0;
	last_kb_msec[i] = -100000;
	hit_radius[i] = (float)p_params.get("hit_radius", 0.0);
	hit_inside[i] = 0;
	fog_init[i] = 0;
	fog_vis[i] = 0.0f;
	net_x[i] = net_y[i] = net_vx[i] = net_vy[i] = net_t[i] = 0.0f;
	net_received[i] = 0;
	foot_vis_id[i] = 0;
	foot_local[i] = 0.0f;
	foot_known[i] = 0;
	draw_given[i] = -1;
	draw_tree[i] = -1;
	live_count++;
	fresh_slots.push_back(i);
	buckets_dirty = true;
	return i;
}

void EnemyWorld::remove_enemy(int32_t p_slot) {
	if (p_slot < 0 || p_slot >= slot_count || !alive[p_slot]) {
		return;
	}
	alive[p_slot] = 0;
	node_id[p_slot] = 0;
	sprite_id[p_slot] = 0;
	anim_sprite_id[p_slot] = 0;
	free_slots.push_back(p_slot);
	live_count--;
	buckets_dirty = true;
}

// ===================================================================================================== durum yazma/okuma

#define SLOT_OK(s) ((s) >= 0 && (s) < slot_count && alive[(s)])

void EnemyWorld::set_flags(int32_t s, int64_t f) {
	if (SLOT_OK(s)) {
		flags[s] = (uint32_t)f;
	}
}
int64_t EnemyWorld::get_flags(int32_t s) const { return SLOT_OK(s) ? (int64_t)flags[s] : 0; }
void EnemyWorld::set_speed(int32_t s, float v) {
	if (SLOT_OK(s)) {
		speed[s] = v;
	}
}
void EnemyWorld::set_radius(int32_t s, float v) {
	if (SLOT_OK(s)) {
		radius[s] = v;
	}
}
void EnemyWorld::set_hit_radius(int32_t s, float v) {
	if (SLOT_OK(s)) {
		hit_radius[s] = v;
	}
}
void EnemyWorld::set_speed_mult(int32_t s, float v) {
	if (SLOT_OK(s)) {
		speed_mult[s] = v;
	}
}
void EnemyWorld::set_rage_mult(int32_t s, float v) {
	if (SLOT_OK(s)) {
		rage_mult[s] = v;
	}
}
void EnemyWorld::set_position(int32_t s, const Vector2 &p) {
	if (SLOT_OK(s)) {
		px[s] = p.x;
		py[s] = p.y;
	}
}
void EnemyWorld::set_knockback(int32_t s, const Vector2 &v) {
	if (SLOT_OK(s)) {
		kvx[s] = v.x;
		kvy[s] = v.y;
	}
}
Vector2 EnemyWorld::get_knockback(int32_t s) const { return SLOT_OK(s) ? Vector2(kvx[s], kvy[s]) : Vector2(); }
void EnemyWorld::set_anim(int32_t s, int32_t cols, float fps, bool walking, float walk_mult) {
	if (SLOT_OK(s)) {
		anim_cols[s] = std::max(1, cols);
		anim_fps[s] = fps;
		anim_walking[s] = walking ? 1 : 0;
		walk_anim_mult[s] = walk_mult;
		anim_t[s] = 0.0f;
		view_frame[s] = -1;
	}
}
// enemy.gd _enter_state çağırır: WALK/IDLE'da kareyi C++ yazar (kare süresi sıfırlanır), OTHER'da GDScript.
void EnemyWorld::set_anim_state(int32_t s, int32_t state, int32_t cols, float fps, float walk_mult, bool idle_tex) {
	if (SLOT_OK(s)) {
		anim_state[s] = state;
		anim_cols[s] = std::max(1, cols);
		anim_fps[s] = fps;
		walk_anim_mult[s] = walk_mult;
		anim_idle_tex[s] = idle_tex ? 1 : 0;
		anim_t[s] = 0.0f;
		anim_pending[s] = 0;
		view_frame[s] = -1;
	}
}
void EnemyWorld::set_contact(int32_t s, float interval, float timer) {
	if (SLOT_OK(s)) {
		contact_interval[s] = interval;
		contact_timer[s] = timer;
	}
}
void EnemyWorld::set_ranged(int32_t s, float range, float interval, float homing) {
	if (SLOT_OK(s)) {
		ranged_range[s] = range;
		ranged_interval[s] = interval;
		homing_interval[s] = homing;
	}
}
void EnemyWorld::set_fear_source(int32_t s, const Vector2 &p) {
	if (SLOT_OK(s)) {
		fear_x[s] = p.x;
		fear_y[s] = p.y;
	}
}
// enemy.gd apply_taunt: süre UZAR, kısalmaz; kışkırtan verilmişse hatırlanır.
void EnemyWorld::set_taunt(int32_t s, int64_t taunter, float duration) {
	if (SLOT_OK(s)) {
		taunt_t[s] = std::max(taunt_t[s], duration);
		if (taunter != 0) {
			taunt_id[s] = (uint64_t)taunter;
		}
	}
}
float EnemyWorld::get_taunt_time(int32_t s) const { return SLOT_OK(s) ? taunt_t[s] : 0.0f; }
void EnemyWorld::set_contact_timer(int32_t s, float v) {
	if (SLOT_OK(s)) {
		contact_timer[s] = v;
	}
}
float EnemyWorld::get_contact_timer(int32_t s) const { return SLOT_OK(s) ? contact_timer[s] : 0.0f; }
void EnemyWorld::set_ranged_timer(int32_t s, float v) {
	if (SLOT_OK(s)) {
		ranged_timer[s] = v;
	}
}
float EnemyWorld::get_ranged_timer(int32_t s) const { return SLOT_OK(s) ? ranged_timer[s] : 0.0f; }
void EnemyWorld::force_think(int32_t s) {
	if (SLOT_OK(s)) {
		has_decision[s] = 0;
	}
}
void EnemyWorld::set_face(int32_t s, const Vector2 &d) {
	if (SLOT_OK(s)) {
		face(s, d.x, d.y);
	}
}
void EnemyWorld::set_net_target(int32_t s, const Vector2 &p, const Vector2 &v) {
	if (SLOT_OK(s)) {
		net_x[s] = p.x;
		net_y[s] = p.y;
		net_vx[s] = v.x;
		net_vy[s] = v.y;
		net_t[s] = 0.0f;
		net_received[s] = 1;
	}
}
float EnemyWorld::get_net_time(int32_t s) const { return SLOT_OK(s) ? net_t[s] : 0.0f; }
Vector2 EnemyWorld::get_position(int32_t s) const { return SLOT_OK(s) ? Vector2(px[s], py[s]) : Vector2(); }
Vector2 EnemyWorld::get_prev_position(int32_t s) const { return SLOT_OK(s) ? Vector2(prev_x[s], prev_y[s]) : Vector2(); }
PackedVector2Array EnemyWorld::get_positions() const {
	// slot sırasıyla (ölü/boş slotlar dahil) - testler/ölçüm için
	PackedVector2Array out;
	out.resize(slot_count);
	for (int32_t i = 0; i < slot_count; i++) {
		out.set(i, Vector2(px[i], py[i]));
	}
	return out;
}
int32_t EnemyWorld::get_target(int32_t s) const { return SLOT_OK(s) ? cur_target[s] : -1; }
float EnemyWorld::get_target_dist(int32_t s) const { return SLOT_OK(s) ? target_dist[s] : 0.0f; }
int32_t EnemyWorld::get_facing_row(int32_t s) const { return SLOT_OK(s) ? facing_row[s] : ROW_DOWN; }
bool EnemyWorld::get_face_left(int32_t s) const { return SLOT_OK(s) && face_left[s]; }
bool EnemyWorld::is_wandering(int32_t s) const { return SLOT_OK(s) && wandering[s]; }

// ===================================================================================================== itme formülleri

// enemy.gd apply_knockback_force: hız ekler, toplam KNOCKBACK_MAX_SPEED ile kırpılır.
void EnemyWorld::apply_knockback_force(int32_t s, const Vector2 &dir, float force) {
	if (!SLOT_OK(s) || force <= 0.0f) {
		return;
	}
	const Vector2 d = dir.length() > 0.001f ? dir.normalized() : Vector2(1, 0);
	kvx[s] += d.x * force;
	kvy[s] += d.y * force;
	const float l = std::sqrt(len2(kvx[s], kvy[s]));
	if (l > KNOCKBACK_MAX_SPEED) {
		kvx[s] = kvx[s] / l * KNOCKBACK_MAX_SPEED;
		kvy[s] = kvy[s] / l * KNOCKBACK_MAX_SPEED;
	}
}

// enemy.gd apply_knockback_distance: mesafe -> başlangıç hızı, tekrar penceresinde küçülür, yöndeki bileşenle birikmez.
void EnemyWorld::apply_knockback_distance(int32_t s, const Vector2 &dir, float distance) {
	if (!SLOT_OK(s) || distance <= 0.0f) {
		return;
	}
	const Vector2 d = dir.length() > 0.001f ? dir.normalized() : Vector2(1, 0);
	const int64_t now = (int64_t)Time::get_singleton()->get_ticks_msec();
	const float repeat_mult = (now - last_kb_msec[s]) < KNOCKBACK_REPEAT_WINDOW_MSEC ? KNOCKBACK_REPEAT_MULT : 1.0f;
	last_kb_msec[s] = now;
	const float v0 = std::sqrt(2.0f * KNOCKBACK_DECAY * std::min(distance * KNOCKBACK_DISTANCE_MULT * repeat_mult, KNOCKBACK_DISTANCE_MAX));
	const float along = kvx[s] * d.x + kvy[s] * d.y;
	if (along < v0) {
		const float add = v0 - std::max(along, 0.0f);
		kvx[s] += d.x * add;
		kvy[s] += d.y * add;
	}
}

// enemy.gd apply_skill_push: tam o mesafeyi kat edecek başlangıç hızı (bosslar x0,4), tavan yok.
void EnemyWorld::apply_skill_push(int32_t s, const Vector2 &dir, float distance) {
	if (!SLOT_OK(s) || distance <= 0.0f || (flags[s] & F_DEAD)) {
		return;
	}
	const Vector2 d = dir.length() > 0.001f ? dir.normalized() : Vector2(1, 0);
	const float dist = distance * ((flags[s] & F_BOSS) ? SKILL_PUSH_BOSS_MULT : 1.0f);
	const float v0 = std::sqrt(2.0f * KNOCKBACK_DECAY * dist);
	const float along = kvx[s] * d.x + kvy[s] * d.y;
	const float add = std::max(v0 - std::max(along, 0.0f), 0.0f);
	kvx[s] += d.x * add;
	kvy[s] += d.y * add;
}

// ===================================================================================================== ızgara / akış alanı

inline bool EnemyWorld::solid_cell(int cx, int cy) const {
	const int x = cx - gox, y = cy - goy;
	if (x < 0 || y < 0 || x >= gw || y >= gh) {
		return false; // ızgara dışı: enemy.gd'deki gibi engel sayılmaz (orman katmanı yok)
	}
	return blocked[(size_t)y * gw + x] != 0;
}

inline bool EnemyWorld::fog_solid_cell(int cx, int cy) const {
	if (fog_blocked.empty()) {
		return solid_cell(cx, cy);
	}
	const int x = cx - gox, y = cy - goy;
	if (x < 0 || y < 0 || x >= gw || y >= gh) {
		return false;
	}
	return fog_blocked[(size_t)y * gw + x] != 0;
}

inline bool EnemyWorld::solid_world(float x, float y) const {
	if (gw <= 0) {
		return false;
	}
	return solid_cell((int)std::floor((x - lox) / cell), (int)std::floor((y - loy) / cell));
}

void EnemyWorld::rebuild_flow(int32_t t) {
	Flow &f = flows[t];
	const size_t cells = (size_t)gw * (size_t)gh;
	if (f.dist.size() != cells) {
		f.dist.assign(cells, 0);
		f.stamp.assign(cells, 0);
		f.gen = 0;
	}
	const int pcx = (int)std::floor((tx[t] - lox) / cell), pcy = (int)std::floor((ty[t] - loy) / cell);
	f.cx = pcx;
	f.cy = pcy;
	f.owner = t_id[t];
	f.gen++;
	const int x0 = pcx - gox, y0 = pcy - goy;
	if (x0 < 0 || y0 < 0 || x0 >= gw || y0 >= gh) {
		return;
	}
	const int32_t g = f.gen;
	// Ağaç sabit durur ve TÜM yaratıklar ona yürür: mesafe sınırı yok (enemy.gd _route_direction ağaç istisnası).
	const int radius_cells = t_kind[t] == T_TREE ? INT32_MAX : FLOW_RADIUS_CELLS;
	int head = 0, tail = 0;
	const int i0 = y0 * gw + x0;
	f.dist[i0] = 0;
	f.stamp[i0] = g;
	bfs_queue[tail++] = i0;
	while (head < tail) {
		const int idx = bfs_queue[head++];
		const int d = f.dist[idx] + 1;
		if (d > radius_cells) {
			continue;
		}
		const int x = idx % gw, y = idx / gw;
		// 4 komşu; ızgara kenarı = sınır
		const int nx[4] = { x + 1, x - 1, x, x };
		const int ny[4] = { y, y, y + 1, y - 1 };
		for (int k = 0; k < 4; k++) {
			if (nx[k] < 0 || ny[k] < 0 || nx[k] >= gw || ny[k] >= gh) {
				continue;
			}
			const int ni = ny[k] * gw + nx[k];
			if (blocked[ni] != 0 || f.stamp[ni] == g) {
				continue;
			}
			f.dist[ni] = d;
			f.stamp[ni] = g;
			bfs_queue[tail++] = ni;
		}
	}
}

// a -> b (kesirli hücre koordinatı, ızgara KÖKENİ DAHİL mutlak hücre) düz çizgisi engelli hücreden geçiyor mu?
// enemy_pathing.gd _cells_line_blocked'ın BİREBİR karşılığı (Amanatides-Woo DDA, başlangıç/bitiş hücresi sayılmaz).
bool EnemyWorld::cells_line_blocked(float ax, float ay, float bx, float by) const {
	const float dx = bx - ax, dy = by - ay;
	int cx = (int)std::floor(ax), cy = (int)std::floor(ay);
	const int ex = (int)std::floor(bx), ey = (int)std::floor(by);
	if (cx == ex && cy == ey) {
		return false;
	}
	const int sx = dx > 0.0f ? 1 : -1, sy = dy > 0.0f ? 1 : -1;
	const float inv_x = 1.0f / std::max(std::fabs(dx), 0.000001f);
	const float inv_y = 1.0f / std::max(std::fabs(dy), 0.000001f);
	float t_x = (dx > 0.0f ? (cx + 1 - ax) : (ax - cx)) * inv_x;
	float t_y = (dy > 0.0f ? (cy + 1 - ay) : (ay - cy)) * inv_y;
	const int max_steps = (int)(std::fabs(dx) + std::fabs(dy)) + 4;
	for (int k = 0; k < max_steps; k++) {
		if (t_x < t_y) {
			cx += sx;
			t_x += inv_x;
		} else {
			cy += sy;
			t_y += inv_y;
		}
		if (cx == ex && cy == ey) {
			return false;
		}
		if (solid_cell(cx, cy)) {
			return true;
		}
	}
	return false;
}

bool EnemyWorld::world_line_blocked(float ax, float ay, float bx, float by) const {
	if (gw <= 0) {
		return false;
	}
	return cells_line_blocked((ax - lox) / cell, (ay - loy) / cell, (bx - lox) / cell, (by - loy) / cell);
}

// enemy.gd line_of_sight_clear: LOS_SAMPLE_STEP aralıkla örnekleme, uçlardan LOS_END_IGNORE içi sayılmaz.
bool EnemyWorld::los_clear(float ax, float ay, float bx, float by) const {
	if (gw <= 0) {
		return true;
	}
	const float dx = bx - ax, dy = by - ay;
	const float length = std::sqrt(dx * dx + dy * dy);
	if (length <= LOS_END_IGNORE * 2.0f) {
		return true;
	}
	const float ux = dx / length, uy = dy / length;
	for (float d = LOS_END_IGNORE; d <= length - LOS_END_IGNORE; d += LOS_SAMPLE_STEP) {
		if (solid_world(ax + ux * d, ay + uy * d)) {
			return false;
		}
	}
	return true;
}

// Akış alanında yaratığın hücresinden en fazla FLOW_LOOKAHEAD adım iner (8 komşu, çaprazda iki yan komşu da boş
// olmalı - köşe sızması yok), sonra bu zincirde yaratıktan DÜZ çizgiyle görülebilen en uzak hücrenin merkezini döner.
// enemy_pathing.gd find_path + _smooth (string-pulling) ile aynı sonuç: basamaklı ızgara zikzağı yok.
bool EnemyWorld::flow_waypoint(int32_t t, float x, float y, float &wx, float &wy) const {
	const Flow &f = flows[t];
	if (f.dist.empty() || f.owner != t_id[t]) {
		return false;
	}
	int cx = (int)std::floor((x - lox) / cell) - gox, cy = (int)std::floor((y - loy) / cell) - goy;
	if (cx < 1 || cy < 1 || cx >= gw - 1 || cy >= gh - 1) {
		return false;
	}
	if (f.stamp[cy * gw + cx] != f.gen) {
		return false; // erişilemez / menzil dışı / duvarın içinde
	}
	int chain_x[FLOW_LOOKAHEAD], chain_y[FLOW_LOOKAHEAD];
	int n = 0;
	while (n < FLOW_LOOKAHEAD) {
		const int i = cy * gw + cx;
		int best = f.dist[i];
		if (best == 0) {
			break;
		}
		int bx = 0, by = 0;
		for (int oy = -1; oy <= 1; oy++) {
			for (int ox = -1; ox <= 1; ox++) {
				if (ox == 0 && oy == 0) {
					continue;
				}
				const int nx = cx + ox, ny = cy + oy;
				if (nx < 0 || ny < 0 || nx >= gw || ny >= gh) {
					continue;
				}
				const int j = ny * gw + nx;
				if (f.stamp[j] != f.gen || f.dist[j] >= best) {
					continue;
				}
				if (ox != 0 && oy != 0 && (blocked[cy * gw + nx] != 0 || blocked[ny * gw + cx] != 0)) {
					continue;
				}
				best = f.dist[j];
				bx = ox;
				by = oy;
			}
		}
		if (bx == 0 && by == 0) {
			break;
		}
		cx += bx;
		cy += by;
		chain_x[n] = cx;
		chain_y[n] = cy;
		n++;
	}
	if (n == 0) {
		return false;
	}
	const float fx = (x - lox) / cell, fy = (y - loy) / cell;
	int pick = 0;
	for (int k = n - 1; k > 0; k--) {
		if (!cells_line_blocked(fx, fy, (float)(chain_x[k] + gox) + 0.5f, (float)(chain_y[k] + goy) + 0.5f)) {
			pick = k;
			break;
		}
	}
	wx = lox + ((float)(chain_x[pick] + gox) + 0.5f) * cell;
	wy = loy + ((float)(chain_y[pick] + goy) + 0.5f) * cell;
	return true;
}

// ===================================================================================================== hedef seçimi

// enemy.gd _find_closest_target_player: hedeflenebilir oyuncu/uzak oyuncu/müttefik arasında en yakın (müttefik
// ALLY_AGGRO_RADIUS içindeyse mesafesi ALLY_AGGRO_BIAS ile küçültülür). Ağaç burada aday değil (geçersiz kılma).
int32_t EnemyWorld::find_closest(int32_t i) const {
	const int n = (int)tx.size();
	int32_t best = -1;
	float best_d = INFINITY;
	for (int t = 0; t < n; t++) {
		if (!t_targetable[t] || t_kind[t] == T_TREE) {
			continue;
		}
		float d = std::sqrt(len2(tx[t] - px[i], ty[t] - py[i]));
		if (t_kind[t] == T_ALLY && d <= ALLY_AGGRO_RADIUS) {
			d *= ALLY_AGGRO_BIAS;
		}
		if (d < best_d) {
			best_d = d;
			best = t;
		}
	}
	return best;
}

// enemy.gd _apply_aggro_overrides: ağaç > tahrik (kışkırtan hedeflenemiyorsa tahrik biter + E_TAUNT_LOST) > Şovalye
// baloncuğu odağı (hedef bir baloncuğun +ZONE_FOCUS_MARGIN içindeyse sahibi; birden çok baloncukta yaratığa en yakını).
int32_t EnemyWorld::apply_overrides(int32_t i, int32_t t) {
	if (tree_index >= 0) {
		return tree_index;
	}
	if (taunt_t[i] > 0.0f && taunt_id[i] != 0) {
		int32_t tt = -1;
		for (int k = 0; k < (int)tx.size(); k++) {
			if (t_id[k] == taunt_id[i]) {
				tt = k;
				break;
			}
		}
		if (tt >= 0 && t_targetable[tt]) {
			t = tt;
		} else {
			taunt_id[i] = 0;
			push_event(E_TAUNT_LOST, i, -1);
		}
	}
	if (t < 0) {
		return t;
	}
	int32_t focus = -1;
	float fd = INFINITY;
	for (int z = 0; z < (int)tx.size(); z++) {
		if (t_zone[z] <= 0.0f) {
			continue;
		}
		if (z == t) {
			return t; // hedef zaten bir baloncuğun sahibi
		}
		if (std::sqrt(len2(tx[t] - tx[z], ty[t] - ty[z])) > t_zone[z] + ZONE_FOCUS_MARGIN) {
			continue;
		}
		const float od = std::sqrt(len2(tx[z] - px[i], ty[z] - py[i]));
		if (od < fd) {
			fd = od;
			focus = z;
		}
	}
	return focus >= 0 ? focus : t;
}

// enemy.gd _has_line_of_sight: hedef başına LOS_CACHE_SEC önbellek.
bool EnemyWorld::has_los(int32_t i, int32_t t) {
	if (los_target[i] == t_id[t] && world_time < los_until[i]) {
		return los_value[i] != 0;
	}
	los_target[i] = t_id[t];
	los_until[i] = world_time + LOS_CACHE_SEC;
	los_value[i] = los_clear(px[i], py[i], tx[t], ty[t]) ? 1 : 0;
	return los_value[i] != 0;
}

// ===================================================================================================== itilme

void EnemyWorld::rebuild_buckets() {
	float max_r = 0.0f;
	for (int32_t i = 0; i < slot_count; i++) {
		if (alive[i] && !(flags[i] & F_DEAD)) {
			max_r = std::max(max_r, radius[i]);
		}
	}
	for (float r : ext_r) {
		max_r = std::max(max_r, r);
	}
	const float sep_cell = std::clamp(2.0f * max_r * ENEMY_SEPARATION_SCALE + ENEMY_SEPARATION_GAP, 24.0f, SEPARATION_GRID_CELL_MAX);
	// kova ızgarası: canlı yaratıkların kapladığı alan
	float minx = INFINITY, miny = INFINITY, maxx = -INFINITY, maxy = -INFINITY;
	for (int32_t i = 0; i < slot_count; i++) {
		if (!alive[i] || (flags[i] & F_DEAD)) {
			continue;
		}
		minx = std::min(minx, px[i]);
		miny = std::min(miny, py[i]);
		maxx = std::max(maxx, px[i]);
		maxy = std::max(maxy, py[i]);
	}
	for (int b : used_buckets) {
		if (b < (int)bucket_head.size()) {
			bucket_head[b] = -1;
		}
	}
	used_buckets.clear();
	if (minx > maxx) {
		bw = bh = 0;
		return;
	}
	box = minx - sep_cell;
	boy = miny - sep_cell;
	bw = (int)((maxx - box) / sep_cell) + 2;
	bh = (int)((maxy - boy) / sep_cell) + 2;
	const size_t need = (size_t)bw * (size_t)bh;
	if (bucket_head.size() < need) {
		bucket_head.assign(need, -1);
	}
	for (int32_t i = 0; i < slot_count; i++) {
		if (!alive[i] || (flags[i] & F_DEAD)) {
			continue;
		}
		const int bx = (int)((px[i] - box) / sep_cell), by = (int)((py[i] - boy) / sep_cell);
		const int bi = by * bw + bx;
		if (bucket_head[bi] == -1) {
			used_buckets.push_back(bi);
		}
		bucket_next[i] = bucket_head[bi];
		bucket_head[bi] = i;
	}
	sep_cell_cache = sep_cell;
	bucket_max_r = max_r;
	buckets_dirty = false;
}

void EnemyWorld::ensure_query_ready() {
	if (!buckets_dirty) {
		return;
	}
	for (int32_t i : fresh_slots) {
		if (i < 0 || i >= slot_count || !alive[i] || node_id[i] == 0) {
			continue;
		}
		Node2D *n = Object::cast_to<Node2D>(ObjectDB::get_instance(node_id[i]));
		if (n != nullptr && n->is_inside_tree()) {
			const Vector2 p = n->get_global_position();
			px[i] = p.x;
			py[i] = p.y;
		}
	}
	fresh_slots.clear();
	rebuild_buckets();
}

void EnemyWorld::compute_separation(int32_t i) {
	if (bw <= 0) {
		return;
	}
	const float c = sep_cell_cache;
	const int bx = (int)((px[i] - box) / c), by = (int)((py[i] - boy) / c);
	float pushx = 0.0f, pushy = 0.0f;
	const float check2 = ENEMY_SEPARATION_CHECK_RADIUS * ENEMY_SEPARATION_CHECK_RADIUS;
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
				float dx = px[i] - px[j], dy = py[i] - py[j];
				const float d2 = dx * dx + dy * dy;
				if (d2 >= check2) {
					continue;
				}
				float d = std::sqrt(d2);
				if (d < 0.001f) {
					// enemy.gd: rastgele küçük yön - burada deterministik (slot farkı)
					dx = (i < j) ? 0.3f : -0.3f;
					dy = 0.2f;
					d = std::sqrt(dx * dx + dy * dy);
				}
				const float min_gap = (radius[i] + radius[j]) * ENEMY_SEPARATION_SCALE + ENEMY_SEPARATION_GAP;
				if (d < min_gap) {
					const float overlap = (min_gap - d) / min_gap;
					pushx += dx / d * overlap;
					pushy += dy / d * overlap;
				}
			}
		}
	}
	// görev kopyaları (az sayıda, doğrudan): enemy.gd ızgarasında onlar da komşuydu
	for (size_t k = 0; k < ext_x.size(); k++) {
		float dx = px[i] - ext_x[k], dy = py[i] - ext_y[k];
		const float d2 = dx * dx + dy * dy;
		if (d2 >= check2) {
			continue;
		}
		float d = std::sqrt(d2);
		if (d < 0.001f) {
			dx = 0.3f;
			dy = 0.2f;
			d = std::sqrt(dx * dx + dy * dy);
		}
		const float min_gap = (radius[i] + ext_r[k]) * ENEMY_SEPARATION_SCALE + ENEMY_SEPARATION_GAP;
		if (d < min_gap) {
			const float overlap = (min_gap - d) / min_gap;
			pushx += dx / d * overlap;
			pushy += dy / d * overlap;
		}
	}
	if (std::sqrt(pushx * pushx + pushy * pushy) < ENEMY_SEPARATION_DEADZONE) {
		sep_tx[i] = sep_ty[i] = 0.0f;
	} else {
		sep_tx[i] = pushx * ENEMY_SEPARATION_FORCE;
		sep_ty[i] = pushy * ENEMY_SEPARATION_FORCE;
	}
}

// ===================================================================================================== isabet sorguları

// Kovalar adımın BAŞINDAKİ konumlarla kuruldu; o kareden beri yaratık en fazla birkaç px kaydı (hız + geri itme tavanı
// 400 px/sn = 60 Hz'de ~7 px) - sorgu kutusu QUERY_SLACK kadar genişletilir, kesin test GÜNCEL konumla yapılır.
static constexpr float QUERY_SLACK = 16.0f;

void EnemyWorld::collect_candidates(float minx, float miny, float maxx, float maxy) {
	ensure_query_ready();
	q_slots.clear();
	if (bw <= 0) {
		return;
	}
	const float pad = bucket_max_r + QUERY_SLACK;
	const float c = sep_cell_cache;
	const int x0 = std::max(0, (int)std::floor((minx - pad - box) / c));
	const int y0 = std::max(0, (int)std::floor((miny - pad - boy) / c));
	const int x1 = std::min(bw - 1, (int)std::floor((maxx + pad - box) / c));
	const int y1 = std::min(bh - 1, (int)std::floor((maxy + pad - boy) / c));
	if (x0 > x1 || y0 > y1) {
		// kova ızgarasının dışı: kenardaki kovalarda olmayanlar (adımdan sonra eklenenler) aşağıda ayrıca taranır
	} else {
		for (int y = y0; y <= y1; y++) {
			for (int x = x0; x <= x1; x++) {
				for (int j = bucket_head[y * bw + x]; j != -1; j = bucket_next[j]) {
					q_slots.push_back(j);
				}
			}
		}
	}
}

Array EnemyWorld::query_circle(const Vector2 &p_center, float p_radius) {
	Array out;
	collect_candidates(p_center.x - p_radius, p_center.y - p_radius, p_center.x + p_radius, p_center.y + p_radius);
	q_keys.clear();
	std::vector<int32_t> hits;
	for (int32_t j : q_slots) {
		if (!alive[j] || (flags[j] & (F_DEAD | F_NO_SIM))) {
			continue;
		}
		const float rr = p_radius + radius[j];
		const float d2 = len2(px[j] - p_center.x, py[j] - p_center.y);
		if (d2 < rr * rr) {
			hits.push_back(j);
			q_keys.push_back(d2);
		}
	}
	std::vector<int32_t> order(hits.size());
	for (size_t k = 0; k < order.size(); k++) {
		order[k] = (int32_t)k;
	}
	std::sort(order.begin(), order.end(), [&](int32_t a, int32_t b) { return q_keys[a] < q_keys[b]; });
	for (int32_t k : order) {
		Object *o = ObjectDB::get_instance(node_id[hits[k]]);
		if (o != nullptr) {
			out.push_back(o);
		}
	}
	return out;
}

Array EnemyWorld::query_points(const Vector2 &p_center, float p_radius) {
	Array out;
	if (p_radius <= 0.0f) {
		return out;
	}
	collect_candidates(p_center.x - p_radius, p_center.y - p_radius, p_center.x + p_radius, p_center.y + p_radius);
	const float r2 = p_radius * p_radius;
	for (int32_t j : q_slots) {
		if (!alive[j] || (flags[j] & (F_DEAD | F_NO_SIM))) {
			continue;
		}
		if (len2(px[j] - p_center.x, py[j] - p_center.y) <= r2) {
			Object *o = ObjectDB::get_instance(node_id[j]);
			if (o != nullptr) {
				out.push_back(o);
			}
		}
	}
	return out;
}

// Hareket eden çember (mermi, yarıçap p_radius) a -> b süpürmesi: yaratığın gövde çemberine değen her yaratık, ilk
// temas anına (t, 0..1) göre sıralı. Area2D body_entered ile aynı küme (iki çemberin çakışması), sadece kare içinde
// atlanan (tünelleme) temaslar da yakalanır.
Array EnemyWorld::query_segment(const Vector2 &p_from, const Vector2 &p_to, float p_radius) {
	Array out;
	collect_candidates(std::min(p_from.x, p_to.x) - p_radius, std::min(p_from.y, p_to.y) - p_radius,
			std::max(p_from.x, p_to.x) + p_radius, std::max(p_from.y, p_to.y) + p_radius);
	const float dx = p_to.x - p_from.x, dy = p_to.y - p_from.y;
	const float L2 = dx * dx + dy * dy;
	q_keys.clear();
	std::vector<int32_t> hits;
	for (int32_t j : q_slots) {
		if (!alive[j] || (flags[j] & (F_DEAD | F_NO_SIM))) {
			continue;
		}
		const float rr = p_radius + radius[j];
		const float fx = px[j] - p_from.x, fy = py[j] - p_from.y;
		float t;
		if (L2 < 1e-8f) {
			if (fx * fx + fy * fy >= rr * rr) {
				continue;
			}
			t = 0.0f;
		} else {
			// en yakın nokta ve ilk temas: |from + t*d - c|^2 = rr^2 çözümünün küçük kökü
			const float tc = std::clamp((fx * dx + fy * dy) / L2, 0.0f, 1.0f);
			const float cx = p_from.x + dx * tc - px[j], cy = p_from.y + dy * tc - py[j];
			if (cx * cx + cy * cy >= rr * rr) {
				continue;
			}
			const float b = -(fx * dx + fy * dy);
			const float cc = fx * fx + fy * fy - rr * rr;
			const float disc = b * b - L2 * cc;
			t = disc > 0.0f ? std::max(0.0f, (-b - std::sqrt(disc)) / L2) : tc;
		}
		hits.push_back(j);
		q_keys.push_back(t);
	}
	std::vector<int32_t> order(hits.size());
	for (size_t k = 0; k < order.size(); k++) {
		order[k] = (int32_t)k;
	}
	std::sort(order.begin(), order.end(), [&](int32_t a, int32_t b) { return q_keys[a] < q_keys[b]; });
	for (int32_t k : order) {
		Object *o = ObjectDB::get_instance(node_id[hits[k]]);
		if (o != nullptr) {
			out.push_back(o);
		}
	}
	return out;
}

// ===================================================================================================== görüş sisi

// vision_occluders.gd is_ray_blocked: DDA, duvara GİRİP en az MIN_WALL_CROSSING karo içinden geçip ÇIKARSA engelli
// (duvarın kendisi görünür, arkası görünmez); en fazla MAX_RAY_STEPS adım. Izgara = orman katmanının dolu hücreleri
// (vision_occluders.gd build ile aynı küme).
bool EnemyWorld::fog_ray_blocked(float ax, float ay, float bx, float by) const {
	constexpr int MAX_RAY_STEPS = 96;
	constexpr float MIN_WALL_CROSSING = 0.75f;
	if (gw <= 0) {
		return false;
	}
	const float a_x = (ax - lox) / cell, a_y = (ay - loy) / cell;
	const float b_x = (bx - lox) / cell, b_y = (by - loy) / cell;
	const float dx = b_x - a_x, dy = b_y - a_y;
	int cx = (int)std::floor(a_x), cy = (int)std::floor(a_y);
	const int ex = (int)std::floor(b_x), ey = (int)std::floor(b_y);
	const int sx = dx > 0.0f ? 1 : -1, sy = dy > 0.0f ? 1 : -1;
	const float inv_x = 1.0f / std::max(std::fabs(dx), 0.000001f);
	const float inv_y = 1.0f / std::max(std::fabs(dy), 0.000001f);
	float t_max_x = (dx > 0.0f ? (cx + 1 - a_x) : (a_x - cx)) * inv_x;
	float t_max_y = (dy > 0.0f ? (cy + 1 - a_y) : (a_y - cy)) * inv_y;
	const float ray_length = std::sqrt(dx * dx + dy * dy);
	bool entered = false;
	float t_enter = 0.0f;
	for (int k = 0; k < MAX_RAY_STEPS; k++) {
		if ((cx == ex && cy == ey) || std::min(t_max_x, t_max_y) > 1.0f) {
			break;
		}
		const float t_cross = std::min(t_max_x, t_max_y);
		if (t_max_x < t_max_y) {
			cx += sx;
			t_max_x += inv_x;
		} else {
			cy += sy;
			t_max_y += inv_y;
		}
		if (fog_solid_cell(cx, cy)) {
			if (!entered) {
				entered = true;
				t_enter = t_cross;
			}
		} else if (entered) {
			if ((t_cross - t_enter) * ray_length >= MIN_WALL_CROSSING) {
				return true;
			}
			entered = false;
		}
	}
	return false;
}

void EnemyWorld::fog_update(const PackedVector2Array &p_sources, float p_radius, float p_width_scale, float p_softness,
		float p_hide_below, int32_t p_interval, int64_t p_frame) {
	static const StringName VIS_META("vision_fog_vis");
	static const StringName HIDDEN_META("vision_fog_hidden");
	fog_active = true;
	fog_sources = p_sources;
	fog_radius = p_radius;
	fog_width_scale = p_width_scale;
	fog_softness = p_softness;
	const int64_t interval = std::max(1, (int)p_interval);
	for (int32_t i = 0; i < slot_count; i++) {
		if (!alive[i] || (flags[i] & (F_DEAD | F_NO_SIM)) || node_id[i] == 0) {
			continue;
		}
		// _apply_enemy_visibility: ilk kez görülen (meta yok) her kare, sonra (kare + instance_id) % aralık == 0
		if (fog_init[i] && ((p_frame + (int64_t)node_id[i]) % interval) != 0) {
			continue;
		}
		Node2D *n = Object::cast_to<Node2D>(ObjectDB::get_instance(node_id[i]));
		if (n == nullptr) {
			continue;
		}
		const float best = fog_visibility_at(px[i], py[i]);
		// _manage_item
		const bool visible = n->is_visible();
		if (best <= 0.0f && !visible) {
			continue; // meta yazılmaz (eski yolda da: ilk kez görülmemiş gizli öğe her kare yeniden bakılır)
		}
		n->set_meta(VIS_META, best);
		fog_init[i] = 1;
		fog_vis[i] = best;
		if (best > p_hide_below) {
			if (n->has_meta(HIDDEN_META)) {
				n->remove_meta(HIDDEN_META);
				n->set_visible(true);
			}
		} else if (visible) {
			n->set_visible(false);
			n->set_meta(HIDDEN_META, true);
		}
	}
}

void EnemyWorld::fog_reset() {
	std::fill(fog_init.begin(), fog_init.end(), 0);
	fog_active = false;
}

// vision_fog.gd _target_visibility: kaynaklar arasında en iyi elips görünürlüğü (smoothstep kenar), duvar arkasındaki
// kaynak sayılmaz (fog_ray_blocked).
float EnemyWorld::fog_visibility_at(float x, float y) const {
	const int ns = fog_sources.size();
	const float rx = fog_radius * std::max(fog_width_scale, 0.05f);
	const float half_band = std::max(fog_softness, 0.01f) * 0.5f;
	const float e0 = 1.0f - half_band, e1 = 1.0f + half_band;
	float best = 0.0f;
	for (int s = 0; s < ns; s++) {
		const Vector2 src = fog_sources[s];
		const float ox = (x - src.x) / rx, oy = (y - src.y) / fog_radius;
		const float nd = std::sqrt(ox * ox + oy * oy);
		const float t = std::clamp((nd - e0) / (e1 - e0), 0.0f, 1.0f);
		const float vis = 1.0f - t * t * (3.0f - 2.0f * t);
		if (vis <= best) {
			continue;
		}
		if (fog_ray_blocked(src.x, src.y, x, y)) {
			continue;
		}
		best = vis;
	}
	return best;
}

Object *EnemyWorld::query_nearest(const Vector2 &p_origin, float p_min_vis) {
	ensure_query_ready(); // adımdan sonra kaydolanların konumu
	int32_t best = -1;
	float best_d2 = INFINITY;
	for (int32_t i = 0; i < slot_count; i++) {
		if (!alive[i] || (flags[i] & (F_DEAD | F_NO_SIM | F_UNTARGETABLE)) || node_id[i] == 0) {
			continue;
		}
		const float d2 = len2(px[i] - p_origin.x, py[i] - p_origin.y);
		if (d2 >= best_d2) {
			continue;
		}
		// VisionFog.can_target: meta varsa o, yoksa sis açıkken geometrik, sis yoksa hedeflenebilir
		if (fog_init[i]) {
			if (fog_vis[i] < p_min_vis) {
				continue;
			}
		} else if (fog_active && fog_visibility_at(px[i], py[i]) < p_min_vis) {
			continue;
		}
		best_d2 = d2;
		best = i;
	}
	return best >= 0 ? ObjectDB::get_instance(node_id[best]) : nullptr;
}

// ===================================================================================================== çizim sırası / minimap

Array EnemyWorld::foot_missing() {
	Array out;
	for (int32_t i = 0; i < slot_count; i++) {
		if (!alive[i] || node_id[i] == 0) {
			continue;
		}
		if (foot_known[i] && (foot_vis_id[i] == 0 || ObjectDB::get_instance(foot_vis_id[i]) != nullptr)) {
			continue;
		}
		Object *o = ObjectDB::get_instance(node_id[i]);
		if (o != nullptr) {
			out.push_back(o);
		}
	}
	return out;
}

void EnemyWorld::set_foot(int32_t s, Object *p_visual, float p_local) {
	if (SLOT_OK(s)) {
		foot_vis_id[s] = p_visual ? p_visual->get_instance_id() : 0;
		foot_local[s] = p_local;
		foot_known[s] = 1;
	}
}

void EnemyWorld::draw_order(Object *p_parent, const Array &p_extras, const PackedFloat32Array &p_extras_foot) {
	Node *parent = Object::cast_to<Node>(p_parent);
	if (parent == nullptr) {
		return;
	}
	draw_ents.clear();
	for (int32_t i = 0; i < slot_count; i++) {
		if (!alive[i] || node_id[i] == 0) {
			continue;
		}
		Node2D *n = Object::cast_to<Node2D>(ObjectDB::get_instance(node_id[i]));
		// main.gd: sadece Main'in doğrudan çocuğu ve görünür (sisin gizlediği çizilmez, sırası önemsiz)
		if (n == nullptr || !n->is_visible() || n->get_parent() != parent) {
			continue;
		}
		Node2D *v = (foot_known[i] && foot_vis_id[i] != 0) ? Object::cast_to<Node2D>(ObjectDB::get_instance(foot_vis_id[i])) : nullptr;
		// görsel yoksa kök (main.gd _creature_foot_y ile aynı)
		const float fy = v != nullptr ? v->get_global_position().y + foot_local[i] * std::fabs(v->get_global_scale().y)
									   : n->get_global_position().y;
		draw_ents.push_back({ fy, (int32_t)n->get_index(true), n->get_canvas_item(), (uint64_t)n->get_instance_id(), i });
	}
	const int ne = p_extras.size();
	for (int k = 0; k < ne; k++) {
		Node2D *n = Object::cast_to<Node2D>((Object *)p_extras[k]);
		if (n == nullptr || n->get_parent() != parent) {
			continue;
		}
		const float fy = k < p_extras_foot.size() ? p_extras_foot[k] : n->get_global_position().y;
		draw_ents.push_back({ fy, (int32_t)n->get_index(true), n->get_canvas_item(), (uint64_t)n->get_instance_id(), -1 });
	}
	if (draw_ents.size() < 2) {
		return;
	}
	draw_idx.resize(draw_ents.size());
	for (size_t k = 0; k < draw_ents.size(); k++) {
		draw_idx[k] = draw_ents[k].idx;
	}
	std::sort(draw_idx.begin(), draw_idx.end());
	// eşit ayakta mevcut sıra korunur (titreme yok)
	std::sort(draw_ents.begin(), draw_ents.end(), [](const DrawEnt &a, const DrawEnt &b) {
		return a.y < b.y || (a.y == b.y && a.idx < b.idx);
	});
	RenderingServer *rs = RenderingServer::get_singleton();
	constexpr int32_t DRAW_FULL_REFRESH = 30; // ~1 sn (main.gd 2 karede bir çağırır)
	const bool full = (++draw_calls % DRAW_FULL_REFRESH) == 0;
	draw_last.resize(draw_ents.size());
	draw_last_idx.resize(draw_ents.size());
	for (size_t k = 0; k < draw_ents.size(); k++) {
		const DrawEnt &e = draw_ents[k];
		if (full || e.slot < 0 || draw_given[e.slot] != draw_idx[k] || draw_tree[e.slot] != e.idx) {
			rs->canvas_item_set_draw_index(e.rid, draw_idx[k]);
			if (e.slot >= 0) {
				draw_given[e.slot] = draw_idx[k];
				draw_tree[e.slot] = e.idx;
			}
		}
		draw_last[k] = draw_ents[k].id;
		draw_last_idx[k] = draw_idx[k];
	}
}

Array EnemyWorld::get_last_draw_order() const {
	Array out;
	for (size_t k = 0; k < draw_last.size(); k++) {
		Array pair;
		pair.push_back(ObjectDB::get_instance(draw_last[k]));
		pair.push_back(draw_last_idx[k]);
		out.push_back(pair);
	}
	return out;
}

PackedVector2Array EnemyWorld::minimap_points(const Vector2 &p_center, float p_world_per_px, float p_max_r, float p_min_vis) {
	PackedVector2Array out;
	const int R = (int)std::ceil(std::max(p_max_r, 0.0f)) + 1;
	const int W = 2 * R + 1;
	mm_seen.assign((size_t)W * (size_t)W, 0);
	const float inv = 1.0f / std::max(p_world_per_px, 0.0001f);
	const float max_r2 = p_max_r * p_max_r;
	for (int32_t i = 0; i < slot_count; i++) {
		if (!alive[i] || node_id[i] == 0 || (flags[i] & (F_DEAD | F_BOSS | F_UNTARGETABLE))) {
			continue;
		}
		// VisionFog.fog_visibility_of: meta varsa o, yoksa 1
		if ((fog_init[i] ? fog_vis[i] : 1.0f) < p_min_vis) {
			continue;
		}
		const float ox = (px[i] - p_center.x) * inv, oy = (py[i] - p_center.y) * inv;
		if (ox * ox + oy * oy > max_r2) {
			continue;
		}
		const int rx = (int)std::round(ox), ry = (int)std::round(oy);
		const size_t cell_i = (size_t)(ry + R) * (size_t)W + (size_t)(rx + R);
		if (rx < -R || rx > R || ry < -R || ry > R || mm_seen[cell_i]) {
			continue;
		}
		mm_seen[cell_i] = 1;
		out.push_back(Vector2((float)rx, (float)ry));
	}
	return out;
}
// ===================================================================================================== küçük davranışlar

inline float EnemyWorld::randf() {
	// xorshift64* - yaratık davranışındaki rastgelelik (enemy.gd randf karşılığı); testlerde set_seed ile sabitlenir
	rng_state ^= rng_state >> 12;
	rng_state ^= rng_state << 25;
	rng_state ^= rng_state >> 27;
	return (float)((rng_state * 0x2545F4914F6CDD1Dull) >> 40) / 16777216.0f;
}

void EnemyWorld::push_event(int32_t type, int32_t slot, int32_t t) {
	ev_data.push_back(type);
	ev_data.push_back(slot);
	ev_data.push_back(t);
}

// enemy.gd _update_facing: 0,1'den kısa yönde değişmez; satır baskın eksene göre, flip_h |x| >= 0,15'te.
void EnemyWorld::face(int32_t i, float dx, float dy) {
	if (dx * dx + dy * dy < 0.01f) {
		return;
	}
	if (std::fabs(dx) > std::fabs(dy)) {
		facing_row[i] = dx > 0.0f ? ROW_RIGHT : ROW_LEFT;
	} else {
		facing_row[i] = dy > 0.0f ? ROW_DOWN : ROW_UP;
	}
	if (std::fabs(dx) >= 0.15f) {
		face_left[i] = dx < 0.0f ? 1 : 0;
	}
}

// enemy.gd _update_stuck_state (dt = düşünme kareleri arasında biriken süre).
void EnemyWorld::update_stuck(int32_t i, float dt, bool moving_intent) {
	stuck_timer[i] -= dt;
	if (stuck_timer[i] > 0.0f) {
		return;
	}
	stuck_timer[i] = STUCK_CHECK_INTERVAL;
	const float disp = std::sqrt(len2(px[i] - stuck_x[i], py[i] - stuck_y[i]));
	is_stuck[i] = (moving_intent && disp < STUCK_MIN_DISPLACEMENT) ? 1 : 0;
	if (is_stuck[i] && randf() < 0.5f) {
		stuck_side[i] = stuck_side[i] > 0.0f ? -1.0f : 1.0f;
	}
	stuck_x[i] = px[i];
	stuck_y[i] = py[i];
}

// enemy.gd _steer_around_obstacle. Fark: prob sadece ORMAN ızgarasına bakar (enemy.gd su+ev+orman); su/ev zaten
// geçilebilir olduğu için orada "sıkışma" fiilen sadece orman duvarında olur.
void EnemyWorld::steer(int32_t i, float &dx, float &dy) const {
	if (!is_stuck[i] || dx * dx + dy * dy < 0.0001f) {
		return;
	}
	if (!solid_world(px[i] + dx * STEER_PROBE, py[i] + dy * STEER_PROBE)) {
		return;
	}
	// dir.rotated(PI/2 * side): +90 -> (-y, x), -90 -> (y, -x)
	const float s = stuck_side[i];
	const float perx = -dy * s, pery = dx * s;
	float rx = perx * 0.75f + dx * 0.25f, ry = pery * 0.75f + dy * 0.25f;
	const float l = std::sqrt(rx * rx + ry * ry);
	if (l > 0.0f) {
		rx /= l;
		ry /= l;
	}
	dx = rx;
	dy = ry;
}

// enemy.gd _compute_wander_velocity.
void EnemyWorld::wander_velocity(int32_t i, float delta, float &vx, float &vy) {
	vx = vy = 0.0f;
	wander_timer[i] -= delta;
	if (wander_timer[i] <= 0.0f ||
			(wander_moving[i] && std::sqrt(len2(wander_x[i] - px[i], wander_y[i] - py[i])) <= WANDER_ARRIVE_DIST)) {
		if (randf() < WANDER_PAUSE_CHANCE) {
			wander_moving[i] = 0;
			wander_timer[i] = randf_range(WANDER_PAUSE_DURATION_MIN, WANDER_PAUSE_DURATION_MAX);
		} else {
			wander_moving[i] = 1;
			const float a = randf() * TAU_F;
			const float d = randf_range(WANDER_RADIUS * 0.3f, WANDER_RADIUS);
			wander_x[i] = px[i] + std::cos(a) * d;
			wander_y[i] = py[i] + std::sin(a) * d;
			wander_timer[i] = randf_range(WANDER_MOVE_DURATION_MIN, WANDER_MOVE_DURATION_MAX);
		}
	}
	if (!wander_moving[i]) {
		return;
	}
	const float tdx = wander_x[i] - px[i], tdy = wander_y[i] - py[i];
	const float l = std::sqrt(tdx * tdx + tdy * tdy);
	if (l <= WANDER_ARRIVE_DIST) {
		return;
	}
	float dx = tdx / l, dy = tdy / l;
	steer(i, dx, dy);
	face(i, dx, dy);
	const float sp = speed[i] * WANDER_MOVE_SPEED_MULT * speed_mult[i] * rage_mult[i];
	vx = dx * sp;
	vy = dy * sp;
}

// enemy.gd _process_ranged_attack: TEK paylaşılan zamanlayıcı; görüş yoksa ateş etmez, sayaç hazır bekler.
void EnemyWorld::process_ranged(int32_t i, int32_t t, float dist, float delta) {
	const float rr = ranged_range[i];
	if (dist > rr * RANGED_MAX_MULT) {
		return;
	}
	ranged_timer[i] -= delta;
	if (ranged_timer[i] > 0.0f) {
		return;
	}
	if (!has_los(i, t)) {
		ranged_timer[i] = 0.0f;
		return;
	}
	if (dist <= rr * RANGED_SPELL_MULT) {
		ranged_timer[i] = ranged_interval[i];
		push_event(E_RANGED_FIRE, i, t);
	} else {
		ranged_timer[i] = homing_interval[i];
		push_event(E_HOMING_FIRE, i, t);
	}
}

// ===================================================================================================== adım

void EnemyWorld::step(float delta) {
	const uint64_t t0 = Time::get_singleton()->get_ticks_usec();
	frame++;
	world_time += delta;
	ev_data.clear();

	// akış alanları: hedef hücre değiştiyse ya da aday sırası kaydıysa yeniden (oyuncu / uzak oyuncu / ağaç)
	const int nt = (int)tx.size();
	if (gw > 0) {
		for (int t = 0; t < nt; t++) {
			if (t_kind[t] == T_ALLY || !t_targetable[t]) {
				continue;
			}
			const int cx = (int)std::floor((tx[t] - lox) / cell), cy = (int)std::floor((ty[t] - loy) / cell);
			if (cx != flows[t].cx || cy != flows[t].cy || flows[t].dist.empty() || flows[t].owner != t_id[t]) {
				rebuild_flow(t);
			}
		}
	}

	sync_external_moves();
	fresh_slots.clear();
	rebuild_buckets();

	for (int32_t i = 0; i < slot_count; i++) {
		if (!alive[i]) {
			continue;
		}
		const uint32_t fl = flags[i];
		if (fl & (F_DEAD | F_NO_SIM)) {
			continue;
		}
		if (fl & F_PUPPET) {
			step_puppet(i, delta);
			step_loco_anim(i, delta);
			continue;
		}
		const bool frozen = (fl & F_FROZEN) != 0;
		const bool ranged = (fl & F_RANGED) != 0;
		ai_accum[i] += delta;

		float vx = 0.0f, vy = 0.0f;
		int32_t t = -1; // bu karenin hedefi (enemy.gd "player"; korku/donma/dolaşmada null)
		float dist = INFINITY, true_contact = 0.0f, min_sep = 0.0f;

		if (frozen) {
			// hareket yok, yön değişmez
		} else if (fl & F_FEAR_WANDER) {
			// enemy.gd _fear_wander_velocity
			fear_retarget[i] -= delta;
			if (fear_retarget[i] <= 0.0f) {
				fear_retarget[i] = randf_range(FEAR_WANDER_TURN_MIN, FEAR_WANDER_TURN_MAX);
				const float a = randf() * TAU_F;
				fear_wdx[i] = std::cos(a);
				fear_wdy[i] = std::sin(a);
			}
			float dx = fear_wdx[i], dy = fear_wdy[i];
			steer(i, dx, dy);
			face(i, fear_wdx[i], fear_wdy[i]);
			const float sp = speed[i] * FEAR_WANDER_SPEED_MULT * speed_mult[i]; // rage YOK (enemy.gd ile aynı)
			vx = dx * sp;
			vy = dy * sp;
		} else if (fl & F_FEAR_FLEE) {
			float ax = px[i] - fear_x[i], ay = py[i] - fear_y[i];
			const float al = std::sqrt(ax * ax + ay * ay);
			if (al > 0.1f) {
				ax /= al;
				ay /= al;
			} else {
				const float a = randf() * TAU_F;
				ax = std::cos(a);
				ay = std::sin(a);
			}
			float dx = ax, dy = ay;
			steer(i, dx, dy);
			const float sp = speed[i] * speed_mult[i] * rage_mult[i];
			vx = dx * sp;
			vy = dy * sp;
			face(i, ax, ay);
		} else {
			if (taunt_t[i] > 0.0f) {
				taunt_t[i] = std::max(0.0f, taunt_t[i] - delta);
			}
			bool think = !has_decision[i] || (frame % AI_THINK_INTERVAL_FRAMES) == (uint64_t)(i % AI_THINK_INTERVAL_FRAMES);
			if (!think && !wandering[i]) {
				const int32_t ct = target[i];
				if (ct < 0 || ct >= nt || !t_targetable[ct]) {
					think = true;
				}
			}
			if (!think) {
				if (wandering[i]) {
					wander_velocity(i, delta, vx, vy);
				} else {
					t = target[i];
					const float tpx = tx[t] - px[i], tpy = ty[t] - py[i];
					dist = std::sqrt(tpx * tpx + tpy * tpy);
					true_contact = ai_true_contact[i];
					min_sep = ai_min_sep[i];
					vx = ivx[i];
					vy = ivy[i];
					if (dist <= min_sep || (fl & F_ATTACK_LOCK)) {
						vx = vy = 0.0f;
					}
					if (ranged) {
						process_ranged(i, t, dist, delta);
					}
					// her karede: rota izleniyorsa son karar yönü, değilse hedef yönü
					if (routing[i] && len2(ivx[i], ivy[i]) > 0.01f) {
						face(i, ivx[i], ivy[i]);
					} else if (dist > 0.1f) {
						face(i, tpx / dist, tpy / dist);
					}
				}
			} else {
				const float think_dt = ai_accum[i];
				ai_accum[i] = 0.0f;
				has_decision[i] = 1;
				wandering[i] = 0;
				routing[i] = 0;
				// "en yakın" önbelleği 4 karede bir (kaydırmalı) ya da geçersizse; geçersiz kılmalar her düşünmede
				int32_t c = closest[i];
				if (c < 0 || c >= nt || !t_targetable[c] || t_kind[c] == T_TREE ||
						(frame % TARGET_UPDATE_INTERVAL_FRAMES) == (uint64_t)(i % TARGET_UPDATE_INTERVAL_FRAMES)) {
					c = find_closest(i);
					closest[i] = c;
				}
				t = apply_overrides(i, c);
				if (t >= 0 && t_targetable[t]) {
					const float tpx = tx[t] - px[i], tpy = ty[t] - py[i];
					dist = std::sqrt(tpx * tpx + tpy * tpy);
					const float dirx = dist > 0.1f ? tpx / dist : 0.0f, diry = dist > 0.1f ? tpy / dist : 0.0f;
					float fdx = dirx, fdy = diry;
					true_contact = (radius[i] + t_body[t]) * body_block_scale;
					min_sep = std::max(true_contact, t_zone[t]);
					if (ranged && dist <= ranged_range[i] && taunt_t[i] <= 0.0f && has_los(i, t)) {
						update_stuck(i, think_dt, false);
					} else if (dist <= min_sep) {
						update_stuck(i, think_dt, false);
					} else {
						update_stuck(i, think_dt, true);
						float mx = dirx, my = diry;
						// enemy.gd _route_direction: hedefe düz çizgi AÇIKKEN düz yürü; orman duvarı araya girince akış
						// alanında görülebilen en uzak hücreye yönel. Müttefik hedefte rota yok; oyuncu hedefinde
						// MAX_ROUTE_DISTANCE sınırı (ağaçta yok).
						const bool route_ok = t_kind[t] != T_ALLY && (t_kind[t] == T_TREE || dist <= MAX_ROUTE_DISTANCE);
						if (route_ok) {
							if (line_target[i] != t || (frame % LINE_CHECK_FRAMES) == (uint64_t)(i % LINE_CHECK_FRAMES)) {
								line_target[i] = t;
								line_blocked[i] = world_line_blocked(px[i], py[i], tx[t], ty[t]) ? 1 : 0;
							}
							float wx, wy;
							if (line_blocked[i] && flow_waypoint(t, px[i], py[i], wx, wy)) {
								const float ddx = wx - px[i], ddy = wy - py[i];
								const float dl = std::sqrt(ddx * ddx + ddy * ddy);
								if (dl > 0.5f) {
									mx = ddx / dl;
									my = ddy / dl;
									routing[i] = 1;
								}
							}
						}
						if (!routing[i]) {
							steer(i, mx, my); // rota izlenirken takılma bükmesi ATLANIR (enemy.gd ile aynı)
						} else {
							fdx = mx;
							fdy = my;
						}
						const float sp = speed[i] * speed_mult[i] * rage_mult[i];
						vx = mx * sp;
						vy = my * sp;
					}
					if (fl & F_ATTACK_LOCK) {
						vx = vy = 0.0f;
					}
					face(i, fdx, fdy);
					if (ranged) {
						process_ranged(i, t, dist, delta);
					}
				} else {
					t = -1;
					wandering[i] = 1;
					wander_velocity(i, delta, vx, vy);
				}
				target[i] = t;
				ivx[i] = vx;
				ivy[i] = vy;
				ai_true_contact[i] = true_contact;
				ai_min_sep[i] = min_sep;
			}
		}

		// ---- itilme + geri itme (donukken uygulanmaz)
		if (!frozen) {
			if ((frame % SEPARATION_UPDATE_INTERVAL_FRAMES) == (uint64_t)(i % SEPARATION_UPDATE_INTERVAL_FRAMES)) {
				compute_separation(i);
			}
			sepx[i] += (sep_tx[i] - sepx[i]) * ENEMY_SEPARATION_SMOOTH;
			sepy[i] += (sep_ty[i] - sepy[i]) * ENEMY_SEPARATION_SMOOTH;
			vx += sepx[i] + kvx[i];
			vy += sepy[i] + kvy[i];
		}
		if (fl & (F_ROOTED | F_ABILITY_LOCK)) {
			vx = vy = 0.0f;
		}

		// ---- orman duvarı: eksen probu (zaten duvarın içindeyse atlanır)
		if ((vx != 0.0f || vy != 0.0f) && !solid_world(px[i], py[i])) {
			if (vx != 0.0f && solid_world(px[i] + (vx > 0.0f ? FOREST_PROBE : -FOREST_PROBE), py[i])) {
				vx = 0.0f;
			}
			if (vy != 0.0f && solid_world(px[i], py[i] + (vy > 0.0f ? FOREST_PROBE : -FOREST_PROBE))) {
				vy = 0.0f;
			}
		}
		px[i] += vx * delta;
		py[i] += vy * delta;

		// ---- geri itme sönümü (donukken de - donma bitince birikmiş itiş patlamasın)
		{
			const float kl = std::sqrt(kvx[i] * kvx[i] + kvy[i] * kvy[i]);
			const float dec = KNOCKBACK_DECAY * delta;
			if (kl <= dec) {
				kvx[i] = kvy[i] = 0.0f;
			} else {
				kvx[i] -= kvx[i] / kl * dec;
				kvy[i] -= kvy[i] / kl * dec;
			}
		}

		// ---- sert yapıştırmalar
		const float kl_now = std::sqrt(kvx[i] * kvx[i] + kvy[i] * kvy[i]);
		if (!frozen && t >= 0 && !t_ghost[t] && min_sep > 0.0f && kl_now < KNOCKBACK_CLAMP_SKIP) {
			const float ax = tx[t] - px[i], ay = ty[t] - py[i];
			const float ad = std::sqrt(ax * ax + ay * ay);
			if (ad < min_sep) {
				const float ux = ad > 0.5f ? -ax / ad : 1.0f, uy = ad > 0.5f ? -ay / ad : 0.0f;
				px[i] = tx[t] + ux * min_sep;
				py[i] = ty[t] + uy * min_sep;
			}
		}
		if (!frozen) {
			for (int z = 0; z < nt; z++) {
				if (z == t || t_zone[z] <= 0.0f) {
					continue;
				}
				const float ax = tx[z] - px[i], ay = ty[z] - py[i];
				const float ad = std::sqrt(ax * ax + ay * ay);
				if (ad < t_zone[z]) {
					const float ux = ad > 0.5f ? -ax / ad : 1.0f, uy = ad > 0.5f ? -ay / ad : 0.0f;
					px[i] = tx[z] + ux * t_zone[z];
					py[i] = ty[z] + uy * t_zone[z];
				}
			}
			if (merchant_active) {
				const float ax = merchant_x - px[i], ay = merchant_y - py[i];
				const float ad = std::sqrt(ax * ax + ay * ay);
				if (ad < merchant_r) {
					const float ux = ad > 0.5f ? -ax / ad : 1.0f, uy = ad > 0.5f ? -ay / ad : 0.0f;
					px[i] = merchant_x + ux * merchant_r;
					py[i] = merchant_y + uy * merchant_r;
				}
			}
		}

		// ---- yakın dövüş / baloncuk saldırısı olayları (mesafe hareketten ÖNCEKİ, enemy.gd ile aynı)
		target_dist[i] = dist;
		cur_target[i] = t;
		if (!frozen && t >= 0) {
			const bool shield_up = t_zone[t] > 0.0f;
			if (!shield_up) {
				contact_timer[i] -= delta;
				const float melee_range = true_contact + (ranged ? MELEE_EXTRA_RANGED : MELEE_EXTRA);
				if (dist <= melee_range && contact_timer[i] <= 0.0f) {
					if (fl & F_GHOST_INVISIBLE) {
						push_event(E_GHOST_REVEAL, i, t);
					} else {
						contact_timer[i] = contact_interval[i];
						push_event(E_MELEE, i, t);
					}
				}
			} else {
				contact_timer[i] = std::max(0.0f, contact_timer[i] - delta);
				const bool can_attack_barrier = !ranged || taunt_t[i] > 0.0f;
				if (can_attack_barrier && dist <= min_sep + BARRIER_TOLERANCE && contact_timer[i] <= 0.0f) {
					contact_timer[i] = contact_interval[i];
					push_event(E_BARRIER_HIT, i, t);
				}
			}
		}

		// ---- HitArea girişi (Area2D body_entered fizik adımının sonunda gelir -> etkisi bir SONRAKİ karenin temas kontrolünde)
		if (hit_radius[i] > 0.0f) {
			const float rr = hit_radius[i] + probe_r;
			const bool inside = probe_r >= 0.0f && len2(px[i] - probe_x, py[i] - probe_y) < rr * rr;
			if (inside && !hit_inside[i]) {
				contact_timer[i] = 0.0f;
				hit_enter_total++;
			}
			hit_inside[i] = inside ? 1 : 0;
		}

		step_loco_anim(i, delta);
	}

	const uint64_t t1 = Time::get_singleton()->get_ticks_usec();
	write_views();
	const uint64_t t2 = Time::get_singleton()->get_ticks_usec();
	last_view_ms = (double)(t2 - t1) / 1000.0;
	last_step_ms = (double)(t2 - t0) / 1000.0;
}

// Yürüme/bekleme + yürüme karesi süresi (host yaratığı ve istemci kuklası ortak).
void EnemyWorld::step_loco_anim(int32_t i, float delta) {
	// ---- yürüme/bekleme (enemy.gd _update_locomotion_state: gerçek yer değiştirmeden, her durumda ölçülür)
	if (!loco_init[i]) {
		loco_px[i] = px[i];
		loco_py[i] = py[i];
		loco_init[i] = 1;
	} else if (delta > 0.0f) {
		const float moved = std::sqrt(len2(px[i] - loco_px[i], py[i] - loco_py[i])) / delta;
		loco_px[i] = px[i];
		loco_py[i] = py[i];
		loco_speed[i] += (moved - loco_speed[i]) * std::min(1.0f, delta * IDLE_SPEED_SMOOTHING);
		if (loco_speed[i] < IDLE_SPEED_THRESHOLD) {
			idle_timer[i] += delta;
		} else {
			idle_timer[i] = 0.0f;
		}
		if (!anim_pending[i]) {
			if (anim_state[i] == A_WALK && idle_timer[i] >= IDLE_ENTER_DELAY) {
				anim_state[i] = A_IDLE;
				anim_pending[i] = 1;
				push_event(E_LOCO, i, A_IDLE);
			} else if (anim_state[i] == A_IDLE && idle_timer[i] <= 0.0f) {
				anim_state[i] = A_WALK;
				anim_pending[i] = 1;
				push_event(E_LOCO, i, A_WALK);
			}
		}
	}
	// ---- kare süresi (enemy.gd _advance_frame_sprite: yürürken x walk_anim_mult)
	if (anim_walking[i] && anim_state[i] != A_OTHER) {
		anim_t[i] += delta * anim_fps[i] * (anim_state[i] == A_WALK ? walk_anim_mult[i] : 1.0f);
	}
}

// İstemci kuklası (enemy.gd _physics_process istemci dalı BİREBİR): son paketten beri geçen süre kadar (en fazla 0,7 sn)
// hızla ileri tahmin, oraya delta*18 yumuşatmayla yaklaşma; anlamlı hareket varken yön hareketten, yoksa 3 karede bir
// ağaca (görevde) ya da en yakın oyuncuya. Paket gelmeden hareket yok.
void EnemyWorld::step_puppet(int32_t i, float delta) {
	cur_target[i] = -1;
	target_dist[i] = INFINITY;
	if (!net_received[i]) {
		return;
	}
	net_t[i] += delta;
	const float extrap = std::min(net_t[i], 0.7f);
	const float pxx = net_x[i] + net_vx[i] * extrap, pyy = net_y[i] + net_vy[i] * extrap;
	const float tox = pxx - px[i], toy = pyy - py[i];
	const float to_len = std::sqrt(tox * tox + toy * toy);
	if (std::sqrt(len2(net_vx[i], net_vy[i])) > 15.0f && to_len > 2.0f) {
		face(i, tox / to_len, toy / to_len);
	} else if ((frame % AI_THINK_INTERVAL_FRAMES) == (uint64_t)(i % AI_THINK_INTERVAL_FRAMES)) {
		const int32_t ft = tree_index >= 0 ? tree_index : find_closest(i);
		if (ft >= 0) {
			const float fx = tx[ft] - px[i], fy = ty[ft] - py[i];
			const float fl = std::sqrt(fx * fx + fy * fy);
			if (fl > 2.0f) {
				face(i, fx / fl, fy / fl);
			}
		}
	}
	const float k = std::min(1.0f, delta * 18.0f);
	px[i] += tox * k;
	py[i] += toy * k;
}

// Düğüm konumu C++'ın son yazdığından farklıysa biri dışarıdan taşımıştır (doğumda add_child SONRASI konumlama,
// vampir ışınlanması, ev/görev ışınlamaları...): onu benimse. Aynı geçişte adım öncesi konum (interpolasyon) saklanır.
void EnemyWorld::sync_external_moves() {
	uint64_t cached_parent = 0;
	bool cached_identity = false;
	for (int32_t i = 0; i < slot_count; i++) {
		if (!alive[i]) {
			continue;
		}
		if (!(flags[i] & (F_DEAD | F_NO_SIM)) && node_id[i] != 0) {
			Node2D *n = Object::cast_to<Node2D>(ObjectDB::get_instance(node_id[i]));
			if (n != nullptr) {
				Node *par = n->get_parent();
				const uint64_t pid = par ? (uint64_t)par->get_instance_id() : 0;
				if (pid != cached_parent) {
					cached_parent = pid;
					CanvasItem *ci = Object::cast_to<CanvasItem>(par);
					cached_identity = ci == nullptr || ci->get_global_transform() == Transform2D();
				}
				const Vector2 p = cached_identity ? n->get_position() : n->get_global_position();
				if (!(p.x == view_x[i] && p.y == view_y[i])) {
					px[i] = p.x;
					py[i] = p.y;
					view_x[i] = p.x;
					view_y[i] = p.y;
				}
			}
		}
		prev_x[i] = px[i];
		prev_y[i] = py[i];
	}
}

// PERF: görünüm yazımı simülasyonun ~4 katıydı (1,1 µs/yaratık, çoğu motorun dönüşüm bildirimi). Ebeveyni birim
// dönüşümlü (yaratıklar Main'in çocuğu) düğümlerde set_global_position yerine set_position (ebeveynin global dönüşümü
// tekrar tekrar sorulmaz); kare ve konum değişmediyse hiç yazılmaz.
void EnemyWorld::write_views() {
	uint64_t cached_parent = 0;
	bool cached_identity = false;
	for (int32_t i = 0; i < slot_count; i++) {
		if (!alive[i] || (flags[i] & F_NO_SIM)) {
			continue;
		}
		Node2D *n = Object::cast_to<Node2D>(ObjectDB::get_instance(node_id[i]));
		if (n == nullptr) {
			continue;
		}
		if (!(flags[i] & F_DEAD) && (px[i] != view_x[i] || py[i] != view_y[i])) {
			view_x[i] = px[i];
			view_y[i] = py[i];
			Node *par = n->get_parent();
			const uint64_t pid = par ? (uint64_t)par->get_instance_id() : 0;
			if (pid != cached_parent) {
				cached_parent = pid;
				CanvasItem *ci = Object::cast_to<CanvasItem>(par);
				cached_identity = ci == nullptr || ci->get_global_transform() == Transform2D();
			}
			if (cached_identity) {
				n->set_position(Vector2(px[i], py[i]));
			} else {
				n->set_global_position(Vector2(px[i], py[i]));
			}
		}
		if (anim_walking[i] && sprite_id[i] != 0 && anim_state[i] != A_OTHER && !anim_pending[i]) {
			const int cols = anim_cols[i];
			const int col = (anim_state[i] == A_IDLE && !anim_idle_tex[i]) ? 0 : ((int)anim_t[i]) % cols;
			const int fr = facing_row[i] * cols + col;
			if (fr != view_frame[i]) {
				Sprite2D *s = Object::cast_to<Sprite2D>(ObjectDB::get_instance(sprite_id[i]));
				if (s != nullptr) {
					s->set_frame(fr);
					view_frame[i] = fr;
				}
			}
		}
		if (anim_sprite_id[i] != 0 && view_flip[i] != (int8_t)face_left[i]) {
			AnimatedSprite2D *as = Object::cast_to<AnimatedSprite2D>(ObjectDB::get_instance(anim_sprite_id[i]));
			if (as != nullptr) {
				as->set_flip_h(face_left[i] != 0);
				view_flip[i] = (int8_t)face_left[i];
			}
		}
	}
}

PackedInt32Array EnemyWorld::pop_events() {
	PackedInt32Array out = ev_data;
	ev_data.clear();
	return out;
}
