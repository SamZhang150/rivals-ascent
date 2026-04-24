extends Node2D

signal ammo_changed(current: int, max_ammo: int)
signal reload_started(duration: float)
signal reload_progress(progress: float)
signal reload_finished()

@export var fire_rate: float = 5.0
@export var is_auto: bool = false
@export var damage: int = 2
@export var bullet_radius: float = 2.0
@export var bullet_length: float = 10.0
@export var bullet_speed: float = 260.0
@export var max_charge_time: float = 0.7
@export var min_charge_speed_scale: float = 0.45
@export var max_charge_squish_pixels: float = 6.0
@export var charge_shake_pixels: float = 1.6
@export var arc_strength: float = 170.0
@export var bounces: int = 2
@export var detonation_timer: float = 1.25
@export var explosion_radius: float = 26.0
@export var ring_colors: Array[Color] = [Color(1.0, 0.9, 0.4, 1.0), Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.3, 0.1, 1.0)]
@export var max_ammo: int = 8
@export var reload_time: float = 1.1
@export var current_ammo: int = 8
@export var ammo_icon: Texture2D
@export var projectile_scene: PackedScene = preload("res://scenes/entities/weapons/projectiles/launcher_projectile.tscn")
@export var projectile_sprite: Texture2D
@export var shop_icon: Texture2D
@export var price: int = 50
@export_multiline var description: String = "This is a gun."

var _fire_cooldown: float = 0.0
var _reload_cooldown: float = 0.0
var _is_reloading: bool = false
var _is_equipped: bool = true
var _is_charging: bool = false
var _charge_elapsed: float = 0.0
@export var shoot_max_polyphony: int = 4
var _base_sprite_scale: Vector2 = Vector2.ONE
var _base_sprite_position: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shoot_sfx: AudioStreamPlayer = $Shoot


func _ready() -> void:
	current_ammo = clamp(current_ammo, 0, max_ammo)
	sprite.animation_finished.connect(_on_gun_animation_finished)
	sprite.play("idle")
	if shoot_sfx != null:
		shoot_sfx.max_polyphony = maxi(1, shoot_max_polyphony)
	_base_sprite_scale = sprite.scale
	_base_sprite_position = sprite.position
	_rng.randomize()
	ammo_changed.emit(current_ammo, max_ammo)


func _process(delta: float) -> void:
	_fire_cooldown = max(_fire_cooldown - delta, 0.0)

	if _is_reloading:
		_cancel_charge(false)
		_reload_cooldown -= delta
		var progress: float = 1.0 - (_reload_cooldown / maxf(reload_time, 0.05))
		reload_progress.emit(clampf(progress, 0.0, 1.0))
		if _reload_cooldown <= 0.0:
			_finish_reload()
		return

	if not _is_equipped:
		_cancel_charge(false)
		return

	if not _can_owner_shoot():
		_cancel_charge(false)
		return

	var owner_player := get_parent()
	if owner_player == null:
		return

	var action := owner_player.call("get_attack_action_name") as String
	if action.is_empty():
		_cancel_charge(false)
		return

	if Input.is_action_just_pressed(action):
		_try_start_charge()

	if _is_charging:
		if Input.is_action_pressed(action):
			_charge_elapsed = minf(_charge_elapsed + delta, maxf(max_charge_time, 0.05))
			_update_charge_visuals()
		elif Input.is_action_just_released(action):
			_release_charged_shot()
		else:
			_cancel_charge(false)


func try_fire(charge_ratio: float = 1.0) -> bool:
	if _fire_cooldown > 0.0 or _is_reloading:
		return false

	if current_ammo <= 0:
		_start_reload()
		return false

	var owner_player := get_parent()
	if owner_player == null:
		return false

	var projectile := projectile_scene.instantiate()
	if projectile == null:
		return false

	var shoot_dir := owner_player.call("get_weapon_aim_direction") as Vector2
	if shoot_dir == Vector2.ZERO:
		shoot_dir = Vector2.RIGHT
	var safe_charge := clampf(charge_ratio, 0.0, 1.0)
	var speed_scale := lerpf(clampf(min_charge_speed_scale, 0.05, 1.0), 1.0, safe_charge)
	var fired_speed := bullet_speed * speed_scale

	current_ammo -= 1
	ammo_changed.emit(current_ammo, max_ammo)
	_fire_cooldown = 1.0 / max(fire_rate, 0.01)

	var spawn_distance := (bullet_length * 0.5) + (bullet_radius * 3.0)
	projectile.global_position = global_position + (shoot_dir * spawn_distance)
	projectile.rotation = shoot_dir.angle()
	projectile.call(
		"setup",
		damage,
		bullet_radius,
		fired_speed,
		shoot_dir,
		owner_player,
		bounces,
		detonation_timer,
		explosion_radius,
		projectile_sprite,
		arc_strength,
		ring_colors
	)

	var world := get_tree().current_scene
	if world == null:
		world = get_tree().root
	world.add_child(projectile)

	_play_fire_animation_from_start()
	if shoot_sfx != null:
		shoot_sfx.play()
	_reset_charge_visuals()
	if current_ammo <= 0:
		_start_reload()
		$Reload.play()

	return true


func _try_start_charge() -> void:
	if _fire_cooldown > 0.0 or _is_reloading:
		return
	if current_ammo <= 0:
		_start_reload()
		return
	_is_charging = true
	_charge_elapsed = 0.0
	_update_charge_visuals()


func _release_charged_shot() -> void:
	if not _is_charging:
		return
	var charge_ratio := clampf(_charge_elapsed / maxf(max_charge_time, 0.05), 0.0, 1.0)
	_is_charging = false
	_charge_elapsed = 0.0
	try_fire(charge_ratio)


func _cancel_charge(reset_visuals: bool = true) -> void:
	if not _is_charging:
		if reset_visuals:
			_reset_charge_visuals()
		return
	_is_charging = false
	_charge_elapsed = 0.0
	if reset_visuals:
		_reset_charge_visuals()


func _update_charge_visuals() -> void:
	if sprite == null:
		return
	var ratio := clampf(_charge_elapsed / maxf(max_charge_time, 0.05), 0.0, 1.0)
	var width := _get_current_sprite_width()
	var squish_px := clampf(max_charge_squish_pixels, 0.0, width * 0.5) * ratio
	var x_scale := 1.0 - (squish_px / maxf(width, 1.0))
	sprite.scale = Vector2(_base_sprite_scale.x * maxf(x_scale, 0.1), _base_sprite_scale.y)

	var shake_strength := charge_shake_pixels * ratio
	sprite.position = _base_sprite_position + Vector2(
		_rng.randf_range(-shake_strength, shake_strength),
		_rng.randf_range(-shake_strength, shake_strength)
	)


func _reset_charge_visuals() -> void:
	if sprite == null:
		return
	sprite.scale = _base_sprite_scale
	sprite.position = _base_sprite_position


func _get_current_sprite_width() -> float:
	if sprite == null or sprite.sprite_frames == null:
		return 24.0
	if not sprite.sprite_frames.has_animation(sprite.animation):
		return 24.0
	var frame_count := sprite.sprite_frames.get_frame_count(sprite.animation)
	if frame_count <= 0:
		return 24.0
	var frame_idx := clampi(sprite.frame, 0, frame_count - 1)
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, frame_idx)
	if tex == null:
		return 24.0
	return maxf(tex.get_width(), 1.0)


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
	_cancel_charge(false)
	_is_reloading = true
	_reload_cooldown = max(reload_time, 0.05)
	reload_started.emit(_reload_cooldown)
	reload_progress.emit(0.0)


func _finish_reload() -> void:
	_is_reloading = false
	current_ammo = max_ammo
	ammo_changed.emit(current_ammo, max_ammo)
	reload_finished.emit()


func _can_owner_shoot() -> bool:
	if not _is_equipped:
		return false
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


func set_equipped(active: bool) -> void:
	_is_equipped = active
	if not active:
		_cancel_charge(false)
	_reset_charge_visuals()
	visible = active
