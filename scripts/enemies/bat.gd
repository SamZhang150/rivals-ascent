extends CharacterBody2D

signal died

@export var speed := randf_range(120, 140)
@export var max_health := 200
@export var touch_damage := 4
@export var knockback_strength := 110.0
@export var coin_reward: int = 8


@onready var sprite = $AnimatedSprite2D
@onready var hurtbox = $HurtboxArea
@onready var hitbox = $HitboxArea
@onready var health_bar = $HealthBar
@onready var bar_bg = $HealthBar/BarBG
@onready var bar_fill = $HealthBar/BarFill

const BAR_WIDTH := 28.0
const BAR_HEIGHT := 2.0

var health := 0
var dead := false
var last_damager: Node = null
var knockback := Vector2.ZERO
var player: CharacterBody2D = null
var speed_modifier: float = 1.0
var _slow_timer: Timer = null
var _stun_timer: Timer = null
var _stun_active: bool = false

func _ready() -> void:
	add_to_group("enemies")
	hitbox.add_to_group("enemy_hitbox")
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)

	_slow_timer = Timer.new()
	_slow_timer.one_shot = true
	_slow_timer.wait_time = 2.0
	_slow_timer.timeout.connect(_on_slow_finished)
	add_child(_slow_timer)

	_stun_timer = Timer.new()
	_stun_timer.one_shot = true
	_stun_timer.timeout.connect(_on_stun_finished)
	add_child(_stun_timer)

	health = max_health
	health_bar.position = Vector2(-14, -12)
	bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	health_bar.visible = health < max_health
	
	bar_bg.color = Color("#2a2a2a")
	bar_fill.color = Color("#d64b4b")
	



func set_player(target: CharacterBody2D) -> void:
	player = target

func _physics_process(delta: float) -> void:
	if dead:
		return
	if _stun_active:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if knockback.length() > 1.0:
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO, 500.0 * delta)
	elif player != null and is_instance_valid(player):
		var dir := global_position.direction_to(player.global_position)
		velocity = dir * speed * speed_modifier
		sprite.play("run")
		if dir.x != 0:
			sprite.flip_h = dir.x >= 0
	else:
		velocity = Vector2.ZERO
		sprite.play("idle")

	move_and_slide()

func take_damage(amount: int, from_position: Vector2, damager: Node = null) -> void:
	if dead:
		return
		
	if damager != null:
		last_damager = damager


	health -= amount
	health = clamp(health, 0, max_health)

	var ratio := float(health) / float(max_health)
	bar_fill.size.x = BAR_WIDTH * ratio
	health_bar.visible = health < max_health

	knockback = (global_position - from_position).normalized() * knockback_strength
	$Damage.play()
	if health <= 0:
		if last_damager != null and last_damager.has_method("add_gold"):
			last_damager.add_gold(coin_reward)
		die()


func get_slowed(_amount: float) -> void:
	if dead:
		return

	speed_modifier = 0.6
	_set_slow_visual(true)
	if _slow_timer != null:
		_slow_timer.start(2.0)


func apply_chain_stun(incoming_damage: int, stun_time: float, chain_amount: int = 0, chain_damage: float = 0.0, chain_dist: float = 0.0, damager: Node = null) -> void:
	if dead:
		return

	take_damage(incoming_damage, global_position, damager)
	_apply_stun(stun_time)

	if chain_amount <= 0 or chain_damage <= 0.0 or chain_dist <= 0.0:
		return

	_chain_to_nearby_enemies(stun_time, chain_amount, chain_damage, chain_dist, damager)


func _apply_stun(stun_time: float) -> void:
	if stun_time <= 0.0 or dead:
		return
	_stun_active = true
	_refresh_sprite_tint()
	if _stun_timer != null:
		_stun_timer.start(stun_time)


func _on_stun_finished() -> void:
	_stun_active = false
	if not dead:
		_refresh_sprite_tint()


func _chain_to_nearby_enemies(stun_time: float, chain_amount: int, chain_damage: float, chain_dist: float, damager: Node = null) -> void:
	var candidates: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or enemy == self or not is_instance_valid(enemy):
			continue
		if not enemy.has_method("apply_chain_stun"):
			continue
		if enemy.get("dead") == true:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= chain_dist:
			candidates.append({"enemy": enemy, "distance": distance})

	candidates.sort_custom(func(a, b): return a["distance"] < b["distance"])
	var hits := mini(chain_amount, candidates.size())
	for i in hits:
		var chained_enemy: Node = candidates[i]["enemy"]
		if chained_enemy != null and is_instance_valid(chained_enemy):
			_spawn_chain_vfx(global_position, chained_enemy.global_position)
			chained_enemy.apply_chain_stun(int(round(chain_damage)), stun_time, 0, chain_damage, chain_dist, damager)


func _spawn_chain_vfx(from_pos: Vector2, to_pos: Vector2) -> void:
	var world := get_tree().current_scene
	if world == null:
		return

	var bolt := Line2D.new()
	bolt.z_index = 100
	bolt.width = 2.0
	bolt.default_color = Color(1.0, 1.0, 0.25, 0.95)
	bolt.begin_cap_mode = Line2D.LINE_CAP_ROUND
	bolt.end_cap_mode = Line2D.LINE_CAP_ROUND
	bolt.joint_mode = Line2D.LINE_JOINT_ROUND
	bolt.position = Vector2.ZERO
	bolt.points = PackedVector2Array([from_pos, to_pos])
	world.add_child(bolt)

	var fade := bolt.create_tween()
	fade.tween_property(bolt, "modulate:a", 0.0, 0.20)
	fade.finished.connect(func() -> void:
		if is_instance_valid(bolt):
			bolt.queue_free()
	)


func _on_slow_finished() -> void:
	speed_modifier = 1.0
	if not dead:
		_set_slow_visual(false)


func _set_slow_visual(is_slowed: bool) -> void:
	if dead:
		return
	speed_modifier = 0.6 if is_slowed else 1.0
	_refresh_sprite_tint()


func _refresh_sprite_tint() -> void:
	if sprite == null:
		return
	var alpha: float = sprite.modulate.a
	if _stun_active:
		sprite.modulate = Color(1.0, 1.0, 0.25, alpha)
	elif speed_modifier < 0.999:
		sprite.modulate = Color(0.8, 1.0, 0.8, alpha)
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0, alpha)

func _on_hurtbox_area_entered(body: Node) -> void:
	#if body == player and body.has_method("take_damage"):
		#body.take_damage(touch_damage)
		pass
		
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox"):
		var player = area.get_parent()
		#if player.has_method("take_damage"):
			#player.take_damage(touch_damage, global_position)

func die() -> void:
	if dead:
		return
	dead = true
	_stun_active = false
	_refresh_sprite_tint()
	died.emit()
	queue_free()
