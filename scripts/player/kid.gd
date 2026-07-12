class_name Kid
extends CharacterBody3D
## Пацан: контроллер от ПЕРВОГО лица. Руки с предметом, качка головы, спринт.
## Состояния: свободен / канал установки (frozen) / в мешке.

signal sacked_state_changed(is_sacked: bool)

const GRAVITY := 20.0
const JUMP := 6.8
const MOUSE_SENS := 0.0026
const BASE_FOV := 78.0

var char_id := "speedy"
var char_def: Dictionary
var speed := 5.5
var place_mult := 1.0
var vis_mult := 1.0

var frozen := false
var is_sacked := false   # связан грабителем
var sack_mash := 0
var tank_escape_left := 0
var match_ref: Node          # Match — обыск мебели и окна через него
var action: Dictionary = {}  # текущее удержание E: {type, t, total, ...}

var yaw := 0.0
var pitch := 0.0
var bob_t := 0.0
var walk_t := 0.0
var land_dip := 0.0
var was_on_floor := true

var eyes: Node3D
var camera: Camera3D
var model: Node3D
var hands: Node3D
var held_slot: Node3D
var held_id := ""

func setup(p_char_id: String) -> void:
	char_id = p_char_id
	char_def = Defs.CHARACTERS[char_id]
	speed = char_def["speed"]
	place_mult = float(char_def["place_mult"]) * SaveGame.place_level_mult(char_id)
	if char_id == "tiny":
		vis_mult = 0.8
	if char_id == "tank":
		tank_escape_left = 1

	add_to_group("kids")
	collision_layer = 2
	collision_mask = 1

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.1
	col.shape = shape
	col.position = Vector3(0, 0.55, 0)
	add_child(col)

	model = Minifig.build_kid(SaveGame.char_colors(char_id))
	model.visible = false  # от первого лица своё тело не видно (для сетевой игры пригодится)
	add_child(model)

	eyes = Node3D.new()
	eyes.position = Vector3(0, 0.95, 0)
	add_child(eyes)
	camera = Camera3D.new()
	camera.fov = BASE_FOV
	camera.near = 0.05
	eyes.add_child(camera)
	camera.current = true

	_build_hands()

func _build_hands() -> void:
	hands = Node3D.new()
	camera.add_child(hands)
	var skin := Color(0.99, 0.84, 0.7)
	var sleeve: Color = SaveGame.char_colors(char_id)["shirt"]
	for side in [-1, 1]:
		var hand := Minifig.build_fp_hand(side, skin, sleeve)
		hand.position = Vector3(side * 0.27, -0.27, -0.45)
		hand.rotation_degrees = Vector3(-18, side * -8, side * 6)
		hands.add_child(hand)
	held_slot = Node3D.new()
	held_slot.position = Vector3(0.27, -0.22, -0.58)
	hands.add_child(held_slot)

## Показать предмет в руке (выбранный в режиме ловушек).
func set_held(item_id: String) -> void:
	if held_id == item_id:
		return
	held_id = item_id
	for c in held_slot.get_children():
		c.queue_free()
	if item_id != "":
		held_slot.add_child(Minifig.build_held_item(item_id))

func _unhandled_input(event: InputEvent) -> void:
	if is_sacked:
		if event.is_action_pressed("jump"):
			_mash_sack()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENS
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -1.35, 1.35)

func _physics_process(delta: float) -> void:
	eyes.rotation = Vector3(pitch, yaw, 0)
	model.rotation.y = yaw + PI
	if frozen or is_sacked:
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return

	# удержание E — заколотить окно / порыться в мебели (через Match)
	if match_ref != null and Input.is_action_pressed("interact"):
		if action.is_empty():
			action = match_ref.kid_action_at(self)
		if not action.is_empty():
			action["t"] += delta
			match_ref.hud.update_qte(action["t"] / action["total"], -1.0, false)
			velocity.x = 0
			velocity.z = 0
			move_and_slide()
			if action["t"] >= action["total"]:
				var done: Dictionary = action
				action = {}
				match_ref.hud.hide_qte()
				match_ref.kid_action_done(self, done)
			return
	elif not action.is_empty():
		action = {}
		match_ref.hud.hide_qte()

	var input_dir := Input.get_vector("move_left", "move_right", "move_fwd", "move_back")
	var dir := (Basis(Vector3.UP, yaw) * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var sprinting := Input.is_action_pressed("sprint") and input_dir.length() > 0.1
	var spd := speed * (1.35 if sprinting else 1.0)
	# плавный разгон/торможение
	velocity.x = move_toward(velocity.x, dir.x * spd, spd * 9.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * spd, spd * 9.0 * delta)
	# лёгкий наклон камеры при стрейфе
	camera.rotation.z = lerpf(camera.rotation.z, -input_dir.x * 0.03, 8.0 * delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP

	move_and_slide()

	# приземление — лёгкий присед камеры
	if is_on_floor() and not was_on_floor:
		land_dip = 0.08
	was_on_floor = is_on_floor()
	land_dip = move_toward(land_dip, 0.0, delta * 0.4)

	# качка головы и FOV
	var hvel := Vector2(velocity.x, velocity.z).length()
	if hvel > 0.5 and is_on_floor():
		bob_t += delta * hvel * 1.6
	camera.position = Vector3(cos(bob_t * 0.5) * 0.018, sin(bob_t) * 0.03 * minf(hvel / speed, 1.3) - land_dip, 0)
	camera.fov = lerpf(camera.fov, BASE_FOV + (8.0 if sprinting else 0.0), 8.0 * delta)

	# анимация тела (для будущего мультиплеера)
	walk_t += delta * hvel * 2.2
	Minifig.animate_walk(model, walk_t, clampf(hvel / speed, 0.0, 1.0))

# ---------------------------------------------------------------- АНИМАЦИЯ УСТАНОВКИ

var place_tween: Tween

## Руки ритмично «возятся» с ловушкой, пока идёт установка.
func play_place_anim() -> void:
	cancel_place_anim()
	place_tween = create_tween().set_loops()
	place_tween.tween_property(hands, "position:y", -0.09, 0.3).set_trans(Tween.TRANS_SINE)
	place_tween.tween_property(hands, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_SINE)

func cancel_place_anim() -> void:
	if place_tween != null and place_tween.is_valid():
		place_tween.kill()
	hands.position.y = 0.0

# ---------------------------------------------------------------- МЕШОК

func put_in_sack() -> void:
	if is_sacked:
		return
	if tank_escape_left > 0:
		tank_escape_left -= 1
		return
	is_sacked = true
	sack_mash = 0
	model.visible = false
	hands.visible = false
	sacked_state_changed.emit(true)

func _mash_sack() -> void:
	sack_mash += 1
	if sack_mash >= Defs.SACK_MASH_NEED:
		escape_sack()

func escape_sack() -> void:
	is_sacked = false
	hands.visible = true
	sacked_state_changed.emit(false)

func sack_progress() -> float:
	return float(sack_mash) / float(Defs.SACK_MASH_NEED)
