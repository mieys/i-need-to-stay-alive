// EnemyWorld - yaratık simülasyonunun C++ çekirdeği (yaratık yeniden yazımı, docs/yaratik_yeniden_yazim/PLAN.md §4, §4.1).
//
// Tek düğüm (Main'in çocuğu) TÜM yaratıkların hareket durumunu düz dizilerde tutar ve tek fizik adımında günceller:
// hedef seçimi (ağaç > tahrik > Şovalye baloncuğu odağı > en yakın), hedef başına akış alanı + düz çizgi kuralı, itilme,
// geri itme, orman duvarı probu, takılma çözücü, hedefsiz dolaşma, korku (kaçış / rastgele), menzilli dur + görüş hattı +
// atış zamanlayıcısı, oyuncu gövdesi / Şovalye baloncuğu / satıcı bölgesi "sert yapıştırma", yön satırı + yürüme karesi,
// yakın dövüş / baloncuk / hayalet / atış olayları. Oyun olayları (saldırı başlatma, hasar, durum etkileri, yetenekler)
// GDScript'te kalır; C++ olay kuyruğuyla bildirir (pop_events). Davranış enemy.gd _physics_process ile BİREBİR olmalı;
// bilinçli farklar PLAN §4.1'de.
//
// Kimlik: add_enemy bir "slot" döner; silinince slot boş listesine girer ve yeniden kullanılır. GDScript yaratık düğümü
// slotunu meta olarak tutar.
#pragma once

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/rid.hpp>

#include <cstdint>
#include <vector>

namespace godot {

class EnemyWorld : public Node {
	GDCLASS(EnemyWorld, Node)

public:
	// Yaratık bayrakları (set_flags) - enemy.gd durumlarının karşılığı.
	enum Flag : uint32_t {
		F_DEAD = 1u << 0,
		F_FROZEN = 1u << 1, // is_frozen (buz ya da sersemletme): hareket yok, hedef/saldırı yok, yön değişmez
		F_ROOTED = 1u << 2, // is_rooted: hareket yok (en sonda), saldırı VAR
		F_ATTACK_LOCK = 1u << 3, // _state == ATTACK: kendi isteğiyle yürümez
		F_ABILITY_LOCK = 1u << 4, // ability_move_lock > 0
		F_RANGED = 1u << 5, // is_ranged
		F_BOSS = 1u << 6, // is_boss (yetenek itmesi x0,4)
		F_GHOST_INVISIBLE = 1u << 7, // is_ability_invisible: yakın menzile girince GHOST_REVEAL olayı
		F_STATUS_ACTIVE = 1u << 8, // GDScript durum etkisi işlemesi gerekiyor (köprü okur)
		F_NO_SIM = 1u << 9, // simülasyon dışı (ör. ölüm animasyonu, kopya görevi) - konum yazılmaz
		F_FEAR_FLEE = 1u << 10, // is_feared, kaynaktan kaç (set_fear_source)
		F_FEAR_WANDER = 1u << 11, // is_feared + _fear_wander: rastgele yönlerde sendele
		F_UNTARGETABLE = 1u << 12, // "untargetable" metası (görünmez hayalet) - silah hedeflemesi (query_nearest) seçmez
		F_PUPPET = 1u << 13, // istemci (host olmayan) kuklası: AI YOK, ağdan gelen konuma ölü hesaplamayla yaklaşır (step_puppet)
	};

	// Aday (hedef) türleri.
	enum TargetKind : int32_t {
		T_PLAYER = 0, // yerel oyuncu
		T_REMOTE = 1, // uzak oyuncu kuklası
		T_ALLY = 2, // player_allies (Necromancer yaratıkları)
		T_TREE = 3, // "Ağacı Koru" görev ağacı - doluysa her şeyin önünde
	};

	// Olay türleri (pop_events): [tür, slot, hedef aday indeksi] üçlüleri.
	enum EventType : int32_t {
		E_MELEE = 0, // yakın dövüş saldırısı başlat
		E_BARRIER_HIT = 1, // Şovalye baloncuğuna saldırı
		E_GHOST_REVEAL = 2, // görünmez hayalet yakın menzile girdi (zamanlayıcı SIFIRLANMAZ, enemy.gd ile aynı)
		E_RANGED_FIRE = 3, // menzilli büyü (_fire_ranged_attack), hedef ranged_range x1,6 içinde
		E_HOMING_FIRE = 4, // garanti isabet atışı (_fire_homing_attack), x1,6 - x2,5 arası
		E_TAUNT_LOST = 5, // kışkırtan artık hedeflenemiyor: tahrik bitti (görsel kaldırılmalı), hedef = -1
		E_LOCO = 6, // yürüme/bekleme geçişi (enemy.gd _update_locomotion_state): üçüncü alan = yeni durum (A_WALK/A_IDLE)
	};

	// Animasyon durumu (set_anim_state): WALK/IDLE karelerini C++ yazar, OTHER (saldırı/hasar/ölüm) GDScript'te.
	enum AnimState : int32_t {
		A_WALK = 0,
		A_IDLE = 1,
		A_OTHER = 2,
	};

private:
	// ---------------------------------------------------------------- yaratık dizileri (slot)
	std::vector<uint8_t> alive;
	std::vector<uint64_t> node_id, sprite_id, anim_sprite_id; // sprite = Sprite2D (kare), anim_sprite = AnimatedSprite2D (flip_h)
	std::vector<float> px, py; // konum
	std::vector<float> prev_x, prev_y; // adım ÖNCESİ konum (PhysicsInterp: _interp_prev_pos)
	std::vector<int32_t> cur_target; // BU karenin hedefi (enemy.gd "player": korku/donma/dolaşmada -1)
	std::vector<float> ivx, ivy; // son düşünme kararındaki hız (_ai_velocity)
	std::vector<float> kvx, kvy; // geri itme hızı
	std::vector<float> sepx, sepy; // yumuşatılmış itilme
	std::vector<float> sep_tx, sep_ty; // hedef itilme (seyrek hesaplanır)
	std::vector<float> radius, speed, speed_mult, rage_mult; // speed_mult = chill x slow, rage ayrı (korku-dolaşma rage'siz)
	std::vector<uint32_t> flags;
	std::vector<float> contact_interval, contact_timer;
	std::vector<int32_t> target; // bu karenin hedefi (aday indeksi), -1 = yok
	std::vector<int32_t> closest; // önbellekli "en yakın" (4 karede bir), geçersiz kılmalar her düşünmede üstüne
	std::vector<float> target_dist;
	std::vector<float> ai_true_contact, ai_min_sep, ai_accum;
	std::vector<uint8_t> has_decision, wandering, routing;
	std::vector<int32_t> facing_row;
	std::vector<uint8_t> face_left; // AnimatedSprite2D (ork) sayfaları için flip_h
	std::vector<float> anim_t, anim_fps, walk_anim_mult;
	std::vector<int32_t> anim_cols, anim_state;
	std::vector<uint8_t> anim_walking; // 1 = yürüme/bekleme karesini C++ ilerletir (Sprite2D varsa)
	std::vector<uint8_t> anim_idle_tex; // bekleme sayfası var mı (yoksa IDLE'da 0. karede durur)
	std::vector<uint8_t> anim_pending; // geçiş olayı gönderildi, GDScript set_anim_state'i bekleniyor (kare yazılmaz)
	std::vector<float> loco_px, loco_py, loco_speed, idle_timer;
	std::vector<uint8_t> loco_init;
	std::vector<int8_t> view_flip; // AnimatedSprite2D'ye en son yazılan flip_h (-1 = hiç)
	std::vector<uint8_t> line_blocked; // hedefe düz çizgi orman duvarından geçiyor mu (seyrek yenilenir)
	std::vector<int32_t> line_target; // line_blocked hangi hedef için hesaplandı
	std::vector<float> view_x, view_y; // düğüme en son yazılan konum (değişmediyse yazılmaz)
	std::vector<int32_t> view_frame; // Sprite2D'ye en son yazılan kare
	// tahrik
	std::vector<uint64_t> taunt_id; // kışkırtanın instance id'si (aday kimliği)
	std::vector<float> taunt_t;
	// korku
	std::vector<float> fear_x, fear_y, fear_wdx, fear_wdy, fear_retarget;
	// menzilli
	std::vector<float> ranged_range, ranged_interval, homing_interval, ranged_timer;
	std::vector<uint64_t> los_target; // görüş önbelleği hangi aday için
	std::vector<double> los_until;
	std::vector<uint8_t> los_value;
	// takılma
	std::vector<float> stuck_timer, stuck_x, stuck_y, stuck_side;
	std::vector<uint8_t> is_stuck;
	// hedefsiz dolaşma
	std::vector<float> wander_x, wander_y, wander_timer;
	std::vector<uint8_t> wander_moving;
	// geri itme (mesafe) tekrar penceresi
	std::vector<int64_t> last_kb_msec;
	// HitArea eşleniği: yerel oyuncunun fizik çemberi yaratığın temas çemberine GİRDİĞİ kare temas zamanlayıcısı sıfırlanır
	// (enemy.gd _on_hit_area_body_entered - gövdeler kapalıyken Area2D artık algılamıyor)
	std::vector<float> hit_radius;
	std::vector<uint8_t> hit_inside;
	// görüş sisi (vision_fog.gd _manage_item eşleniği): bu yaratık sis tarafından bir kez "yönetildi" mi (VIS_META var mı)
	std::vector<uint8_t> fog_init;
	std::vector<float> fog_vis; // en son yazılan vision_fog_vis (fog_init ise geçerli)
	// istemci kuklası (F_PUPPET): host'tan gelen son konum + türetilmiş hız + o paketten beri geçen süre (enemy.gd
	// update_network_state / _physics_process istemci dalı)
	std::vector<float> net_x, net_y, net_vx, net_vy, net_t;
	std::vector<uint8_t> net_received;
	bool fog_active = false; // sis şu an yaratıkları yönetiyor mu (vision_fog.gd _active)
	PackedVector2Array fog_sources;
	float fog_radius = 1.0f, fog_width_scale = 1.0f, fog_softness = 0.1f;

	// çizim sırası (main.gd _update_creature_draw_order eşleniği): ayak = görsel düğümün global y'si + yerel ayak satırı x |ölçek|
	std::vector<uint64_t> foot_vis_id;
	std::vector<float> foot_local;
	std::vector<uint8_t> foot_known;
	// son verilen draw index ve o andaki ağaç indeksi: ikisi de aynıysa RenderingServer çağrısı atlanır (motor draw index'i
	// sadece ağaç indeksi değişince - NOTIFICATION_MOVED_IN_PARENT - sıfırlar)
	std::vector<int32_t> draw_given, draw_tree;
	int32_t draw_calls = 0; // her DRAW_FULL_REFRESH çağrıda bir önbellek yok sayılır (indeks gidip geri dönerse kaçmasın)
	struct DrawEnt {
		float y;
		int32_t idx;
		RID rid;
		uint64_t id;
		int32_t slot; // -1 = ekstra (önbelleksiz)
	};
	std::vector<DrawEnt> draw_ents;
	std::vector<int32_t> draw_idx;
	std::vector<uint64_t> draw_last; // test: son draw_order'ın ayak sırasıyla düğümleri
	std::vector<int32_t> draw_last_idx; // test: verilen draw index'ler
	std::vector<uint8_t> mm_seen; // minimap_points piksel tekilleştirme

	std::vector<int32_t> free_slots;
	int32_t slot_count = 0;
	int32_t live_count = 0;

	// ---------------------------------------------------------------- harita ızgarası (orman duvarı)
	std::vector<uint8_t> blocked;
	int gox = 0, goy = 0, gw = 0, gh = 0;
	float cell = 16.0f, lox = 0.0f, loy = 0.0f;

	// ---------------------------------------------------------------- adaylar (hedefler) - her kare GDScript'ten
	std::vector<float> tx, ty, t_body, t_zone;
	std::vector<int32_t> t_kind;
	std::vector<uint8_t> t_targetable, t_ghost;
	std::vector<uint64_t> t_id; // instance id (tahrik ve görüş önbelleği kareler arası bununla eşleşir)
	int32_t tree_index = -1;
	float body_block_scale = 1.0f;
	int64_t hit_enter_total = 0; // ölçüm/test: toplam HitArea girişi
	float probe_x = 0.0f, probe_y = 0.0f, probe_r = -1.0f; // yerel oyuncunun fizik çemberi (<0 = yok / çarpışması kapalı)
	bool merchant_active = false;
	float merchant_x = 0.0f, merchant_y = 0.0f, merchant_r = 0.0f;

	// ---------------------------------------------------------------- akış alanları (aday başına)
	struct Flow {
		std::vector<int32_t> dist, stamp;
		int32_t gen = 0;
		int cx = -99999, cy = -99999;
		uint64_t owner = 0; // hangi adayın alanı (aday sırası kareler arası değişebilir)
	};
	std::vector<Flow> flows; // aday indeksiyle aynı sıra
	std::vector<int32_t> bfs_queue;

	// ---------------------------------------------------------------- uzamsal ızgara
	std::vector<int32_t> bucket_head, bucket_next, used_buckets;
	int bw = 0, bh = 0;
	float box = 0.0f, boy = 0.0f;
	float sep_cell_cache = 24.0f; // bu adımın kova boyutu (enemy.gd _sep_cell ile aynı formül)
	float bucket_max_r = 0.0f; // kovadaki en büyük gövde yarıçapı (sorgu payı)
	// Kova ızgarası adım başında kurulur; adımdan SONRA kaydolan / silinen yaratık için ilk sorgu ızgarayı yeniden kurar ve yeni
	// kayıtların konumunu düğümden tazeler (doğumda add_child SONRASI konumlama) - yoksa ilk adıma kadar sorgularda görünmezlerdi.
	bool buckets_dirty = true;
	std::vector<int32_t> fresh_slots;
	void ensure_query_ready();
	// kayıtsız "enemies" üyeleri (görev kopyaları): yaratıkları iter, kendileri C++'ta hareket etmez (enemy.gd itilme ızgarası
	// onları da içeriyordu)
	std::vector<float> ext_x, ext_y, ext_r;
	std::vector<int32_t> q_slots; // sorgu geçici
	std::vector<float> q_keys;

	// ---------------------------------------------------------------- olaylar, rastgelelik, ölçüm
	PackedInt32Array ev_data; // [tür, slot, hedef] x n
	uint64_t frame = 0;
	double world_time = 0.0;
	uint64_t rng_state = 0x9E3779B97F4A7C15ull;
	double last_step_ms = 0.0;
	double last_view_ms = 0.0; // last_step_ms'nin write_views kısmı

	void ensure_capacity(int32_t n);
	inline bool solid_cell(int cx, int cy) const;
	inline bool solid_world(float x, float y) const;
	void rebuild_flow(int32_t t);
	bool cells_line_blocked(float ax, float ay, float bx, float by) const;
	bool world_line_blocked(float ax, float ay, float bx, float by) const;
	bool los_clear(float ax, float ay, float bx, float by) const;
	bool flow_waypoint(int32_t t, float x, float y, float &wx, float &wy) const;
	int32_t find_closest(int32_t i) const;
	int32_t apply_overrides(int32_t i, int32_t t);
	bool has_los(int32_t i, int32_t t);
	void rebuild_buckets();
	void compute_separation(int32_t i);
	void update_stuck(int32_t i, float dt, bool moving_intent);
	void steer(int32_t i, float &dx, float &dy) const;
	void wander_velocity(int32_t i, float delta, float &vx, float &vy);
	void process_ranged(int32_t i, int32_t t, float dist, float delta);
	void face(int32_t i, float dx, float dy);
	void push_event(int32_t type, int32_t slot, int32_t t);
	inline float randf();
	inline float randf_range(float a, float b) { return a + (b - a) * randf(); }
	void write_views();
	void step_puppet(int32_t i, float delta);
	void step_loco_anim(int32_t i, float delta);
	void sync_external_moves();
	void collect_candidates(float minx, float miny, float maxx, float maxy);
	bool fog_ray_blocked(float ax, float ay, float bx, float by) const;
	float fog_visibility_at(float x, float y) const;

protected:
	static void _bind_methods();

public:
	// Kurulum
	void set_grid(const PackedByteArray &p_blocked, const Vector2i &p_origin, const Vector2i &p_size, float p_cell,
			const Vector2 &p_layer_origin);
	void set_targets(const PackedVector2Array &p_pos, const PackedInt32Array &p_kind, const PackedByteArray &p_targetable,
			const PackedByteArray &p_ghost, const PackedFloat32Array &p_body, const PackedFloat32Array &p_zone,
			const PackedInt64Array &p_ids);
	void set_merchant_zone(bool p_active, const Vector2 &p_pos, float p_radius);
	void set_body_block_scale(float p_scale) { body_block_scale = p_scale; }
	void set_extra_bodies(const PackedVector2Array &p_pos, const PackedFloat32Array &p_radius);
	void set_hit_probe(const Vector2 &p_center, float p_radius) {
		probe_x = p_center.x;
		probe_y = p_center.y;
		probe_r = p_radius;
	}
	void set_seed(int64_t p_seed) { rng_state = (uint64_t)p_seed * 0x9E3779B97F4A7C15ull + 1; }

	// Yaratık yaşam döngüsü
	int32_t add_enemy(Object *p_node, Object *p_sprite, const Vector2 &p_pos, const Dictionary &p_params);
	void remove_enemy(int32_t p_slot);

	// Yaratık durumu (GDScript yazar)
	void set_flags(int32_t p_slot, int64_t p_flags);
	int64_t get_flags(int32_t p_slot) const;
	void set_speed(int32_t p_slot, float p_speed);
	void set_radius(int32_t p_slot, float p_radius);
	void set_hit_radius(int32_t p_slot, float p_radius);
	void set_speed_mult(int32_t p_slot, float p_mult);
	void set_rage_mult(int32_t p_slot, float p_mult);
	void set_position(int32_t p_slot, const Vector2 &p_pos);
	void set_knockback(int32_t p_slot, const Vector2 &p_vel);
	Vector2 get_knockback(int32_t p_slot) const;
	void set_anim(int32_t p_slot, int32_t p_cols, float p_fps, bool p_walking, float p_walk_mult);
	void set_anim_state(int32_t p_slot, int32_t p_state, int32_t p_cols, float p_fps, float p_walk_mult, bool p_idle_tex);
	void set_contact(int32_t p_slot, float p_interval, float p_timer);
	void set_ranged(int32_t p_slot, float p_range, float p_interval, float p_homing_interval);
	void set_fear_source(int32_t p_slot, const Vector2 &p_pos);
	void set_taunt(int32_t p_slot, int64_t p_taunter_id, float p_duration);
	float get_taunt_time(int32_t p_slot) const;
	// enemy_abilities.gd'nin dışarıdan yazdığı alanlar (enemy.gd bunları özellik olarak C++'a yönlendirir)
	void set_contact_timer(int32_t p_slot, float p_t);
	float get_contact_timer(int32_t p_slot) const;
	void set_ranged_timer(int32_t p_slot, float p_t);
	float get_ranged_timer(int32_t p_slot) const;
	void force_think(int32_t p_slot); // _ai_has_decision = false: bir sonraki karede yeniden düşünür
	void set_face(int32_t p_slot, const Vector2 &p_dir); // _update_facing (yetenek nişanı)
	// istemci kuklası: host'tan yeni konum paketi (hız GDScript'te türetilir, enemy.gd update_network_state ile aynı)
	void set_net_target(int32_t p_slot, const Vector2 &p_pos, const Vector2 &p_vel);
	float get_net_time(int32_t p_slot) const;

	// enemy.gd itme formülleri (host tarafı; istemci yönlendirmesi GDScript'te kalır)
	void apply_knockback_force(int32_t p_slot, const Vector2 &p_dir, float p_force);
	void apply_knockback_distance(int32_t p_slot, const Vector2 &p_dir, float p_distance);
	void apply_skill_push(int32_t p_slot, const Vector2 &p_dir, float p_distance);

	// Okuma
	Vector2 get_position(int32_t p_slot) const;
	Vector2 get_prev_position(int32_t p_slot) const;
	int32_t get_target(int32_t p_slot) const;
	float get_target_dist(int32_t p_slot) const;
	int32_t get_facing_row(int32_t p_slot) const;
	bool get_face_left(int32_t p_slot) const;
	bool is_wandering(int32_t p_slot) const;
	int32_t get_count() const { return live_count; }
	int64_t get_hit_enter_total() const { return hit_enter_total; }
	bool is_solid_at(const Vector2 &p_pos) const { return solid_world(p_pos.x, p_pos.y); }
	bool is_line_blocked(const Vector2 &p_from, const Vector2 &p_to) const {
		return world_line_blocked(p_from.x, p_from.y, p_to.x, p_to.y);
	}
	bool is_los_clear(const Vector2 &p_from, const Vector2 &p_to) const { return los_clear(p_from.x, p_from.y, p_to.x, p_to.y); }
	PackedVector2Array get_positions() const;

	// İsabet sorguları (PLAN §4.3): mermiler/alanlar yaratığı body_entered yerine bunlarla bulur. Gövde çemberi
	// (radius) ile kesişen CANLI yaratık DÜĞÜMLERİ döner. query_segment a'dan b'ye ilk temas sırasıyla sıralı (delici mermi
	// için "ilk vurulan" = birincil hedef), query_circle merkeze uzaklık sırasıyla.
	Array query_circle(const Vector2 &p_center, float p_radius);
	Array query_segment(const Vector2 &p_from, const Vector2 &p_to, float p_radius);
	// enemy.gd get_enemies_near eşleniği: MERKEZİ p_radius içinde olan canlı yaratıklar (gövde yarıçapı eklenmez),
	// kova sırasıyla (sıralama yok - eski ızgara da hücre sırasıyla dönüyordu).
	Array query_points(const Vector2 &p_center, float p_radius);

	// Görüş sisi (vision_fog.gd _apply_enemy_visibility/_manage_item/_target_visibility + vision_occluders.gd is_ray_blocked
	// BİREBİR): kayıtlı yaratıkların vision_fog_vis metası ve gizle/göster durumu. fog_reset: sis kapanınca (GDScript
	// metaları kendisi siler) "ilk kez görülüyor" durumuna dön.
	void fog_update(const PackedVector2Array &p_sources, float p_radius, float p_width_scale, float p_softness,
			float p_hide_below, int32_t p_interval, int64_t p_frame);
	void fog_reset();
	// weapon.gd _get_nearest_enemy eşleniği (kayıtlı yaratıklar): canlı, "untargetable" değil, VisionFog.can_target (sis
	// metası >= p_min_vis; meta yoksa sis açıkken geometrik hesap, sis kapalıysa hedeflenebilir) olan EN YAKIN; yoksa null.
	Object *query_nearest(const Vector2 &p_origin, float p_min_vis);

	// Çizim sırası (main.gd _update_creature_draw_order eşleniği, PLAN Aşama 3): yaratıklar ağaçta TAŞINMAZ (move_child her
	// seferinde O(çocuk)); bunun yerine görünür yaratıkların ŞU AN işgal ettiği ağaç indeksleri ayak y'sine göre dağıtılıp
	// RenderingServer.canvas_item_set_draw_index ile verilir - diğer kardeşlere göre konumlar aynı kalır. extras: kayıtsız
	// (ölmekte / görev kopyası / müttefik) düğümler + ayak y'leri (GDScript hesaplar). Ayak verisi set_foot ile bir kez
	// verilir; foot_missing bunu henüz almamış (ya da görseli silinmiş) kayıtlı yaratıkları döner.
	Array foot_missing();
	void set_foot(int32_t p_slot, Object *p_visual, float p_local);
	void draw_order(Object *p_parent, const Array &p_extras, const PackedFloat32Array &p_extras_foot);
	Array get_last_draw_order() const; // test: [düğüm, draw_index] çiftleri, ayak sırasıyla
	// minimap.gd düşman noktaları (kayıtlı, boss OLMAYAN, untargetable olmayan, sis görünürlüğü >= p_min_vis; meta yoksa
	// 1): görünüm merkezine göre harita pikseli ofseti (yuvarlanmış, aynı piksele düşenler tekilleştirilmiş), |ofset| <= p_max_r.
	PackedVector2Array minimap_points(const Vector2 &p_center, float p_world_per_px, float p_max_r, float p_min_vis);

	// Adım
	void step(float p_delta);
	PackedInt32Array pop_events();
	double get_last_step_ms() const { return last_step_ms; }
	double get_last_view_ms() const { return last_view_ms; }
};

} // namespace godot

VARIANT_ENUM_CAST(EnemyWorld::Flag);
VARIANT_ENUM_CAST(EnemyWorld::TargetKind);
VARIANT_ENUM_CAST(EnemyWorld::EventType);
VARIANT_ENUM_CAST(EnemyWorld::AnimState);
