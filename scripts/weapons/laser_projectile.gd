extends Area2D

@export var damage: int = 1
@export var bullet_radius: float = 2.0
@export var bullet_length: float = 10.0
@export var bullet_speed: float = 220.0
@export var life_time: float = 2.0
@export var base_color: Color = Color(0.95, 0.12, 0.12, 1.0)

var direction: Vector2 = Vector2.RIGHT
var projectile_owner: Node = null
var _elapsed: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 49
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_update_collision_shape()
	queue_redraw()


func _process(delta: float) -> void:
	global_position += direction * bullet_speed * delta
	_elapsed += delta
	if _elapsed >= life_time:
		queue_free()


func setup(new_damage: int, new_radius: float, new_length: float, new_speed: float, new_direction: Vector2, new_owner: Node = null, new_base_color: Color = Color(0.95, 0.12, 0.12, 1.0)) -> void:
	damage = new_damage
	bullet_radius = max(new_radius, 0.5)
	bullet_length = max(new_length, 0.0)
	bullet_speed = max(new_speed, 1.0)
	direction = new_direction.normalized() if new_direction != Vector2.ZERO else Vector2.RIGHT
	projectile_owner = new_owner
	base_color = new_base_color
	rotation = direction.angle()
	_update_collision_shape()
	queue_redraw()


func _update_collision_shape() -> void:
	if collision_shape == null:
		return

	var shape := RectangleShape2D.new()
	shape.size = Vector2((bullet_radius * 2.0) + bullet_length, bullet_radius * 2.0)
	collision_shape.shape = shape


func _draw() -> void:
	var r := bullet_radius
	var body_len := bullet_length
	var half_capsule := (body_len * 0.5) + r
	var left_center := Vector2(-body_len * 0.5, 0.0)
	var right_center := Vector2(body_len * 0.5, 0.0)
	var outer_color := base_color

	# Outer colored pill
	var outer_rect := Rect2(Vector2(-body_len * 0.5, -r), Vector2(body_len, r * 2.0))
	draw_rect(outer_rect, outer_color, true)
	draw_circle(left_center, r, outer_color)
	draw_circle(right_center, r, outer_color)

	# Inner white core
	var inner_r: float = max(r - 0.8, 0.2)
	var inner_len: float = max(body_len - 1.6, 0.0)
	var inner_left := Vector2(-inner_len * 0.5, 0.0)
	var inner_right := Vector2(inner_len * 0.5, 0.0)
	var inner_rect := Rect2(Vector2(-inner_len * 0.5, -inner_r), Vector2(inner_len, inner_r * 2.0))
	draw_rect(inner_rect, Color(1.0, 1.0, 1.0, 1.0), true)
	draw_circle(inner_left, inner_r, Color(1.0, 1.0, 1.0, 1.0))
	draw_circle(inner_right, inner_r, Color(1.0, 1.0, 1.0, 1.0))

	# Soft glow on the right side
	var glow_center := Vector2(half_capsule + (r * 0.6), 0.0)
	var glow_tint := outer_color.lerp(Color.WHITE, 0.35)
	for i in range(4):
		var t := float(i) / 3.0
		var glow_r := r * (1.6 + t * 1.2)
		var alpha := 0.16 * (1.0 - t)
		draw_circle(glow_center, glow_r, Color(glow_tint.r, glow_tint.g, glow_tint.b, alpha))


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target == null or target == projectile_owner:
		return

	if target.is_in_group("enemies"):
		_apply_enemy_damage(target)
		queue_free()
		return

	if area.is_in_group("player_hitbox") and target.is_in_group("player"):
		_apply_player_damage(target)
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == null or body == projectile_owner:
		return

	if body.is_in_group("enemies"):
		_apply_enemy_damage(body)
		queue_free()
		return

	if body.is_in_group("player"):
		_apply_player_damage(body)
		queue_free()
		return

	queue_free()


func _apply_enemy_damage(enemy: Node) -> void:
	if enemy.has_method("lower_health"):
		enemy.lower_health(damage)
	elif enemy.has_method("take_damage"):
		enemy.take_damage(damage, global_position, projectile_owner)


func _apply_player_damage(player: Node) -> void:
	if player.has_method("take_damage"):
		player.take_damage(damage, global_position)
