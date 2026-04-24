extends CharacterBody2D

@export var damage: int = 2
@export var projectile_radius: float = 3.0
@export var projectile_speed: float = 240.0
@export var gravity: float = 650.0
@export var bounces: int = 2
@export var detonation_time: float = 1.25
@export var explosion_radius: float = 26.0
@export var bounce_damping: float = 0.78
@export var bounce_phase_ratio: float = 0.72
@export var roll_deceleration: float = 340.0
@export var downward_accel_scale: float = 1.12
@export var spin_speed_degrees: float = 540.0

var projectile_owner: Node = null
var _velocity: Vector2 = Vector2.ZERO
var _travel_direction: Vector2 = Vector2.RIGHT
var _horizontal_speed: float = 0.0
var _last_segment_index: int = 0
var _bounce_phase_end: float = 1.0
var _detonation_elapsed: float = 0.0
var _pending_sprite_texture: Texture2D = null
var _arc_strength: float = 0.0
var _arc_segments: Array = []
var _arc_vertical_sign: float = -1.0
var _ring_colors: Array[Color] = [Color(1.0, 0.9, 0.4, 1.0), Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.3, 0.1, 1.0)]
var _has_exploded: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_refresh_collision_exceptions()
	if sprite != null and _pending_sprite_texture != null:
		sprite.texture = _pending_sprite_texture
	if collision_shape == null or collision_shape.shape == null:
		var shape := CircleShape2D.new()
		shape.radius = projectile_radius
		collision_shape.shape = shape
	else:
		_update_collision_shape()


func setup(
	new_damage: int,
	new_radius: float,
	new_speed: float,
	new_direction: Vector2,
	new_owner: Node,
	new_bounces: int,
	new_detonation_time: float,
	new_explosion_radius: float,
	new_sprite: Texture2D = null,
	arc_strength: float = 170.0,
	new_ring_colors: Array = []
) -> void:
	damage = max(new_damage, 0)
	projectile_radius = max(new_radius, 1.0)
	projectile_speed = max(new_speed, 1.0)
	projectile_owner = new_owner
	bounces = max(new_bounces, 0)
	detonation_time = max(new_detonation_time, 0.05)
	explosion_radius = max(new_explosion_radius, 1.0)

	var direction := new_direction.normalized() if new_direction != Vector2.ZERO else Vector2.RIGHT
	_travel_direction = direction
	_arc_vertical_sign = 1.0 if direction.x < 0.0 else -1.0
	_horizontal_speed = projectile_speed
	_last_segment_index = 0
	_velocity = direction * _horizontal_speed
	_arc_strength = absf(arc_strength)
	_ring_colors = _normalize_ring_colors(new_ring_colors)
	_compute_arc_segments(bounces, _arc_strength)
	rotation = _velocity.angle()
	_update_collision_shape()

	_pending_sprite_texture = new_sprite


func _physics_process(delta: float) -> void:
	if _has_exploded:
		return

	_detonation_elapsed += delta
	if _detonation_elapsed >= detonation_time:
		explode()
		return

	var t := clampf(_detonation_elapsed / maxf(detonation_time, 0.05), 0.0, 1.0)
	var segment_index := _get_arc_segment_index(t)
	if segment_index >= 0 and segment_index > _last_segment_index:
		for i in range(segment_index - _last_segment_index):
			_horizontal_speed *= bounce_damping
		_last_segment_index = segment_index
	elif segment_index == -1 and t > _bounce_phase_end:
		_horizontal_speed = maxf(_horizontal_speed - (roll_deceleration * delta), 0.0)
	_velocity = _travel_direction * _horizontal_speed

	var collision := move_and_collide(_velocity * delta)
	if collision != null:
		explode()
		return

	if _horizontal_speed > 0.0:
		if sprite != null:
			sprite.rotation += deg_to_rad(spin_speed_degrees) * delta

	# Visual bounce arcs: each arc uses an asymmetric curve with an earlier apex so descent
	# feels slightly stronger than ascent. Only the sprite is offset; collision stays on the line.
	# Only the sprite is offset — the collision shape travels in a straight line.
	if sprite != null and _arc_segments.size() > 0:
		var found := false
		for seg in _arc_segments:
			if t >= float(seg["start"]) and t <= float(seg["end"]):
				var local_t: float = (t - float(seg["start"])) / maxf(float(seg["end"]) - float(seg["start"]), 0.0001)
				sprite.position.y = _arc_vertical_sign * _compute_arc_height(local_t, float(seg["height"]))
				found = true
				break
		if not found:
			sprite.position.y = 0.0


func explode() -> void:
	if _has_exploded:
		return
	_has_exploded = true

	if get_tree() == null:
		queue_free()
		return
	for node in get_tree().get_nodes_in_group("player"):
		if node == null or not is_instance_valid(node):
			continue
		if node == projectile_owner:
			continue
		if not node.has_method("take_damage"):
			continue
		if node.global_position.distance_to(global_position) > explosion_radius:
			continue
		node.take_damage(damage, global_position)

	for node in get_tree().get_nodes_in_group("enemies"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("take_damage"):
			continue
		if node.global_position.distance_to(global_position) > explosion_radius:
			continue
		node.take_damage(damage, global_position, projectile_owner)

	_horizontal_speed = 0.0
	_velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if collision_shape != null:
		collision_shape.disabled = true
	if sprite != null:
		sprite.visible = false

	_play_explosion_rings()
	
	$Explode.play()

	var cleanup_tween := create_tween()
	cleanup_tween.tween_interval(0.42)
	cleanup_tween.tween_callback(queue_free)


# Divides total flight time into (num_bounces + 1) equal-duration arcs.
# Each arc is a parabola that touches 0 at each bounce point, with decreasing height.
func _compute_arc_segments(num_bounces: int, height: float, decay: float = 0.55) -> void:
	_arc_segments.clear()
	var num_arcs := num_bounces + 1
	var phase_ratio := clampf(bounce_phase_ratio, 0.2, 1.0)
	_bounce_phase_end = phase_ratio
	var seg_duration := phase_ratio / float(num_arcs)
	for i in range(num_arcs):
		_arc_segments.append({
			"start": float(i) * seg_duration,
			"end": float(i + 1) * seg_duration,
			"height": height * pow(decay, i)
		})


func _compute_arc_height(local_t: float, height: float) -> float:
	var t := clampf(local_t, 0.0, 1.0)
	var apex := clampf(0.5 / maxf(downward_accel_scale, 0.5), 0.35, 0.5)
	if t <= apex:
		var rise_t := t / maxf(apex, 0.0001)
		return height * (2.0 * rise_t - (rise_t * rise_t))
	var fall_t := (t - apex) / maxf(1.0 - apex, 0.0001)
	return height * (1.0 - (fall_t * fall_t))


func _get_arc_segment_index(normalized_time: float) -> int:
	for i in range(_arc_segments.size()):
		var seg: Dictionary = _arc_segments[i]
		if normalized_time >= float(seg["start"]) and normalized_time <= float(seg["end"]):
			return i
	return -1


func _normalize_ring_colors(input_colors: Array) -> Array[Color]:
	var colors: Array[Color] = []
	for value in input_colors:
		if value is Color:
			colors.append(value)
	if colors.size() < 3:
		for i in range(colors.size(), 3):
			colors.append(_ring_colors[i])
	elif colors.size() > 3:
		colors.resize(3)
	return colors


func _play_explosion_rings() -> void:
	var ring_container := Node2D.new()
	add_child(ring_container)

	var base_width := maxf(explosion_radius * 0.12, 1.5)
	var radii := [explosion_radius * 0.45, explosion_radius * 0.72, explosion_radius * 1.0]
	var durations := [0.20, 0.26, 0.34]
	var delays := [0.00, 0.04, 0.08]

	for i in range(3):
		var ring := _create_ring(float(radii[i]), base_width)
		ring.modulate = _ring_colors[i]
		ring.modulate.a = 0.95
		ring.scale = Vector2.ONE * 0.18
		ring_container.add_child(ring)

		var tween := create_tween()
		tween.tween_interval(float(delays[i]))
		tween.set_parallel(true)
		tween.tween_property(ring, "scale", Vector2.ONE, float(durations[i])).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(ring, "modulate:a", 0.0, float(durations[i])).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _create_ring(radius: float, width: float) -> Line2D:
	var ring := Line2D.new()
	ring.closed = true
	ring.width = width
	ring.antialiased = true

	var points := 36
	for i in range(points):
		var angle := TAU * float(i) / float(points)
		ring.add_point(Vector2(cos(angle), sin(angle)) * radius)

	return ring


func _update_collision_shape() -> void:
	if collision_shape == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = projectile_radius
	collision_shape.shape = shape


func _refresh_collision_exceptions() -> void:
	if get_tree() == null:
		return
	for node in get_tree().get_nodes_in_group("player"):
		if node != null and is_instance_valid(node) and node is PhysicsBody2D:
			add_collision_exception_with(node)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node != null and is_instance_valid(node) and node is PhysicsBody2D:
			add_collision_exception_with(node)
