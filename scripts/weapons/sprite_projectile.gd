extends Area2D

@export var damage: int = 1
@export var bullet_radius: float = 2.0
@export var bullet_length: float = 10.0
@export var bullet_speed: float = 220.0
@export var life_time: float = 2.0
@export var spin_speed_degrees: float = 540.0

var direction: Vector2 = Vector2.RIGHT
var projectile_owner: Node = null
var _elapsed: float = 0.0
var _pending_sprite_texture: Texture2D = null
var _pending_sprite_frames: SpriteFrames = null
var _pending_animation: String = "default"

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite_node: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 49
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_update_collision_shape()
	if _pending_sprite_frames != null:
		_apply_frames(_pending_sprite_frames, _pending_animation)
	elif _pending_sprite_texture != null:
		_apply_texture(_pending_sprite_texture)


func _process(delta: float) -> void:
	global_position += direction * bullet_speed * delta
	if sprite_node != null:
		sprite_node.rotation += deg_to_rad(spin_speed_degrees) * delta
	_elapsed += delta
	if _elapsed >= life_time:
		queue_free()


func setup(new_damage: int, new_radius: float, new_length: float, new_speed: float, new_direction: Vector2, new_owner: Node = null, _new_base_color: Color = Color(0.95, 0.12, 0.12, 1.0)) -> void:
	damage = new_damage
	bullet_radius = max(new_radius, 0.5)
	bullet_length = max(new_length, 0.0)
	bullet_speed = max(new_speed, 1.0)
	direction = new_direction.normalized() if new_direction != Vector2.ZERO else Vector2.RIGHT
	projectile_owner = new_owner
	rotation = direction.angle()
	_update_collision_shape()


func set_projectile_sprite(texture: Texture2D) -> void:
	_pending_sprite_texture = texture
	if sprite_node != null:
		_apply_texture(texture)


func set_projectile_frames(frames: SpriteFrames, animation: String = "default") -> void:
	_pending_sprite_frames = frames
	_pending_animation = animation
	if sprite_node != null:
		_apply_frames(frames, animation)


func _apply_texture(texture: Texture2D) -> void:
	if sprite_node == null or texture == null:
		return
	var frames := SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_speed("default", 0.0)
	frames.add_frame("default", texture, 1.0)
	_apply_frames(frames, "default")


func _apply_frames(frames: SpriteFrames, animation: String) -> void:
	if sprite_node == null or frames == null:
		return
	sprite_node.sprite_frames = frames
	var anim := animation if frames.has_animation(animation) else frames.get_animation_names()[0]
	sprite_node.play(anim)


func _update_collision_shape() -> void:
	if collision_shape == null:
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2((bullet_radius * 2.0) + bullet_length, bullet_radius * 2.0)
	collision_shape.shape = shape


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
