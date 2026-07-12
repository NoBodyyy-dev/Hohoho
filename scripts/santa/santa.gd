class_name Santa
extends CharacterBody3D
## Санта — игрок от первого лица (база будущего контроллера грабителя).
## Цель: занести подарки и свалить. Ловушки его замедляют/оглушают/сбивают с ног.
## Бота нет: за эту сторону всегда играет человек.

signal delivered(spot: Vector2i)
signal escaped
signal sacked_kid(kid: Kid)
signal hoho_used
signal present_sense_used

const BASE_SPEED := 4.6
const GRAVITY := 20.0
const PLACE_TIME := 2.6

var player_controlled := false
var house: HouseBuilder

var stun_t := 0.0
var slow_mult := 1.0
var slow_t := 0.0
var place_t := 0.0
var sack_cd := 0.0
var capture_mult := 1.0
var enraged := false

# статус-эффекты
var dizzy_t := 0.0          # головокружение: виляет, не может сажать в мешок
var wet_t := 0.0            # мокрый: шокер бьёт вдвое сильнее (скрытое комбо)
var knock_vel := Vector3.ZERO
var knock_t := 0.0          # неуправляемый полёт/скольжение (банан, шарики)

var danger: Dictionary = {}
var known_traps: Dictionary = {}
var walk_t := 0.0

var spots_left: Array = []
var blocked_entries: Dictionary = {}
var chosen_entry := 0

var model: Node3D
var kids_ref: Array = []
var rage_light: OmniLight3D
var stars: Node3D
var sense_cd := 0.0
var hoho_cd := 0.0
var psense_cd := 0.0   # «чуйка на подарки» (F) — примерные места доставки

# управление игроком (от первого лица)
var yaw := 0.0
var pitch := 0.0
var eyes: Node3D
var camera: Camera3D

func setup(p_house: HouseBuilder, p_player_controlled: bool) -> void:
	house = p_house
	player_controlled = p_player_controlled
	add_to_group("santa")
	collision_layer = 5
	collision_mask = 1

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	col.shape = shape
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

	model = Minifig.build_santa()
	add_child(model)

	spots_left = house.present_spots.duplicate()
	chosen_entry = randi() % house.entries.size()
	var e: Dictionary = house.entries[chosen_entry]
	var outer: Vector2i = e["cell"] + e["out_dir"]
	global_position = Defs.cell_to_world(outer) + Vector3(e["out_dir"].x, 0, e["out_dir"].y) * 3.0

	if player_controlled:
		model.visible = false
		eyes = Node3D.new()
		eyes.position = Vector3(0, 1.7, 0)
		add_child(eyes)
		camera = Camera3D.new()
		camera.fov = 78
		camera.near = 0.05
		eyes.add_child(camera)
		camera.current = true

## Фаза Санты началась. Без игрока за Санту фигурка просто стоит у входа.
func go() -> void:
	pass

## Последняя минута: Санта звереет — быстрее, замедления слабее.
func enrage() -> void:
	if enraged:
		return
	enraged = true
	rage_light = OmniLight3D.new()
	rage_light.light_color = Color(1.0, 0.25, 0.15)
	rage_light.light_energy = 1.6
	rage_light.omni_range = 3.5
	rage_light.position = Vector3(0, 1.5, 0)
	add_child(rage_light)

# ================================================================ ЭФФЕКТЫ ЛОВУШЕК

func apply_trap_effect(stun: float, slow: float, slow_dur: float, _scare: bool, p_capture_mult: float, extra: Dictionary = {}) -> void:
	if stun > stun_t:
		stun_t = stun
	if slow < 1.0:
		slow_mult = maxf(slow, 0.65) if enraged else slow
		slow_t = maxf(slow_t, slow_dur)
	capture_mult = maxf(p_capture_mult, 1.0)
	_flash(Color(1, 0.4, 0.2))
	# --- статус-эффекты
	if float(extra.get("dizzy", 0.0)) > 0.0:
		dizzy_t = maxf(dizzy_t, float(extra["dizzy"]))
	if extra.get("wet", false):
		wet_t = Defs.WET_DURATION
		_flash(Color(0.4, 0.6, 1.0))
	if extra.get("disorient", false):
		_disorient()
	var knock := float(extra.get("knock", 0.0))
	if absf(knock) > 0.01:
		var dir := Vector3(velocity.x, 0, velocity.z)
		if dir.length() < 0.5:
			dir = Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
		dir = dir.normalized() * signf(knock)
		knock_vel = dir * absf(knock) * 1.9
		knock_t = 0.55
		stun_t = maxf(stun_t, 0.01)  # прерываем текущее действие

## Дезориентация: Санта «забывает» всё, что приметил.
func _disorient() -> void:
	known_traps.clear()
	danger.clear()

func is_dizzy() -> bool:
	return dizzy_t > 0.0

func is_stunned() -> bool:
	return stun_t > 0.0

func _flash(c: Color) -> void:
	for child in model.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = child.material_override
			var orig: Color = mat.albedo_color
			var tw := create_tween()
			tw.tween_method(func(v: float): mat.albedo_color = orig.lerp(c, v), 1.0, 0.0, 0.6)

# ================================================================ ФИЗИКА

func _physics_process(delta: float) -> void:
	sack_cd = maxf(sack_cd - delta, 0.0)
	sense_cd = maxf(sense_cd - delta, 0.0)
	hoho_cd = maxf(hoho_cd - delta, 0.0)
	psense_cd = maxf(psense_cd - delta, 0.0)
	dizzy_t = maxf(dizzy_t - delta, 0.0)
	wet_t = maxf(wet_t - delta, 0.0)
	if slow_t > 0.0:
		slow_t -= delta
		if slow_t <= 0.0:
			slow_mult = 1.0
			capture_mult = 1.0
	# неуправляемый полёт от банана/шариков: контроля нет, ловушки по пути срабатывают
	if knock_t > 0.0:
		knock_t -= delta
		velocity.x = knock_vel.x
		velocity.z = knock_vel.z
		knock_vel = knock_vel.lerp(Vector3.ZERO, 4.0 * delta)
		model.rotation.z = sin(Time.get_ticks_msec() * 0.04) * 0.35
		model.rotation.x = -0.3
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		if knock_t <= 0.0:
			model.rotation.x = 0.0
			stun_t = maxf(stun_t, 1.0)  # шлёпнулся — встаёт
		return
	if stun_t > 0.0:
		stun_t -= delta
		velocity.x = 0
		velocity.z = 0
		# трясётся в ловушке, над головой кружат звёздочки
		model.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.06
		_update_stars(delta, true)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	model.rotation.z = 0.0
	_update_stars(delta, dizzy_t > 0.0)

	if player_controlled:
		_player_move(delta)
	else:
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()

	var hvel := Vector2(velocity.x, velocity.z).length()
	walk_t += delta * hvel * 2.0
	Minifig.animate_walk(model, walk_t, clampf(hvel / BASE_SPEED, 0.0, 1.2))

func _update_stars(delta: float, active: bool) -> void:
	if active:
		if stars == null:
			stars = Node3D.new()
			stars.position = Vector3(0, 2.2, 0)
			for i in 3:
				var s := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.07
				sm.height = 0.14
				s.mesh = sm
				s.material_override = Defs.flat_mat(Color(1.0, 0.9, 0.3), 2.5)
				var ang := i * TAU / 3.0
				s.position = Vector3(cos(ang) * 0.4, 0, sin(ang) * 0.4)
				stars.add_child(s)
			add_child(stars)
		stars.rotation.y += delta * 5.0
	elif stars != null:
		stars.queue_free()
		stars = null

func current_speed() -> float:
	var s := BASE_SPEED * slow_mult
	if enraged:
		s *= 1.3
	if dizzy_t > 0.0:
		s *= 0.85
	return s

# ================================================================ ИГРОК (FP)

func _unhandled_input(event: InputEvent) -> void:
	if not player_controlled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0026
		pitch = clampf(pitch - event.relative.y * 0.0026, -1.35, 1.35)
	if event.is_action_pressed("ability1") and sense_cd <= 0.0:
		sense_cd = Defs.SANTA_SENSE_CD
		_use_sense()
	if event.is_action_pressed("ability2") and hoho_cd <= 0.0:
		hoho_cd = Defs.SANTA_HOHO_CD
		_use_hoho()
	if event.is_action_pressed("trap_mode") and psense_cd <= 0.0:
		psense_cd = Defs.SANTA_PSENSE_CD
		present_sense_used.emit()

## Q — «чуйка»: подсветить все ловушки рядом.
func _use_sense() -> void:
	for trap in get_tree().get_nodes_in_group("traps"):
		if not trap.spent and global_position.distance_to(trap.global_position) < Defs.SANTA_SENSE_RANGE:
			trap.reveal()

## R — «ХО-ХО-ХО»: пугает пацанов рядом, сбивает им установку ловушек.
func _use_hoho() -> void:
	var tw := model.create_tween()
	tw.tween_property(model, "scale", Vector3(1.12, 1.12, 1.12), 0.15)
	tw.tween_property(model, "scale", Vector3.ONE, 0.25)
	hoho_used.emit()

func _player_move(delta: float) -> void:
	var roll := sin(Time.get_ticks_msec() * 0.005) * 0.09 if dizzy_t > 0.0 else 0.0
	eyes.rotation = Vector3(pitch, yaw, roll)
	model.rotation.y = yaw + PI
	if Input.is_action_pressed("interact"):
		var near := _near_spot()
		if near != Vector2i(-99, -99):
			place_t += delta
			velocity.x = 0
			velocity.z = 0
			move_and_slide()
			if place_t >= PLACE_TIME:
				place_t = 0.0
				spots_left.erase(near)
				delivered.emit(near)
				if spots_left.is_empty():
					escaped.emit()
			return
	else:
		place_t = 0.0
	var input_dir := Input.get_vector("move_left", "move_right", "move_fwd", "move_back")
	var dir := (Basis(Vector3.UP, yaw) * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var spd := current_speed() * (1.3 if Input.is_action_pressed("sprint") else 1.0)
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()

func _near_spot() -> Vector2i:
	for s in spots_left:
		if global_position.distance_to(Defs.cell_to_world(s)) < 1.2:
			return s
	return Vector2i(-99, -99)

func place_progress() -> float:
	return clampf(place_t / PLACE_TIME, 0.0, 1.0)
