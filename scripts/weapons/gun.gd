extends Node2D

@export var fire_rate: float = 5.0
@export var is_auto: bool = false
@export var damage: int = 2
@export var bullet_radius: float = 2.0
@export var bullet_length: float = 10.0
@export var bullet_speed: float = 260.0
@export var max_ammo: int = 8
@export var reload_time: float = 1.1
@export var current_ammo: int = 8
@export var projectile_scene: PackedScene

var _fire_cooldown: float = 0.0
var _reload_cooldown: float = 0.0
var _is_reloading: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	current_ammo = clamp(current_ammo, 0, max_ammo)
	sprite.animation_finished.connect(_on_gun_animation_finished)
	sprite.play("idle")


func _process(delta: float) -> void:
	_fire_cooldown = max(_fire_cooldown - delta, 0.0)

	if _is_reloading:
		_reload_cooldown -= delta
		if _reload_cooldown <= 0.0:
			_finish_reload()
		return

	if not _can_owner_shoot():
		return

	var owner_player := get_parent()
	if owner_player == null:
		return

	var action := owner_player.call("get_attack_action_name") as String
	if action.is_empty():
		return

	var wants_to_fire := Input.is_action_pressed(action) if is_auto else Input.is_action_just_pressed(action)
	if wants_to_fire:
		try_fire()


func try_fire() -> void:
	if _fire_cooldown > 0.0 or _is_reloading:
		return

	if current_ammo <= 0:
		_start_reload()
		return

	var owner_player := get_parent()
	if owner_player == null:
		return

	var projectile := projectile_scene.instantiate()
	if projectile == null:
		return

	var shoot_dir := owner_player.call("get_weapon_aim_direction") as Vector2
	if shoot_dir == Vector2.ZERO:
		shoot_dir = Vector2.RIGHT

	current_ammo -= 1
	_fire_cooldown = 1.0 / max(fire_rate, 0.01)

	var spawn_distance := (bullet_length * 0.5) + (bullet_radius * 3.0)
	projectile.global_position = global_position + (shoot_dir * spawn_distance)
	projectile.rotation = shoot_dir.angle()
	projectile.call("setup", damage, bullet_radius, bullet_length, bullet_speed, shoot_dir, owner_player)

	var world := get_tree().current_scene
	if world == null:
		world = get_tree().root
	world.add_child(projectile)

	_play_fire_animation_from_start()
	if current_ammo <= 0:
		_start_reload()


func _play_fire_animation_from_start() -> void:
	# Restarting guarantees visual shot timing stays aligned with actual projectile spawns.
	if sprite == null:
		return
	if sprite.animation == "fire":
		sprite.stop()
	sprite.play("fire")
	sprite.frame = 0
	sprite.frame_progress = 0.0


func _start_reload() -> void:
	if _is_reloading or current_ammo >= max_ammo:
		return
	_is_reloading = true
	_reload_cooldown = max(reload_time, 0.05)


func _finish_reload() -> void:
	_is_reloading = false
	current_ammo = max_ammo


func _can_owner_shoot() -> bool:
	var owner_player := get_parent()
	if owner_player == null:
		return false
	if not owner_player.is_in_group("player"):
		return false
	if owner_player.has_method("can_fire_weapon"):
		return owner_player.call("can_fire_weapon")
	return true


func _on_gun_animation_finished() -> void:
	if sprite.animation == "fire":
		sprite.play("idle")
