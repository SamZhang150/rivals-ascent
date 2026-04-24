extends CharacterBody2D

signal died

@export var speed := randf_range(45, 55)
@export var max_health := 80
@export var touch_damage := 4
@export var knockback_strength := 110.0
@export var coin_reward: int = 7

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


func _on_slow_finished() -> void:
	speed_modifier = 1.0
	if not dead:
		_set_slow_visual(false)


func _set_slow_visual(is_slowed: bool) -> void:
	if sprite == null:
		return
	var alpha: float = sprite.modulate.a
	if is_slowed:
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
	died.emit()
	queue_free()
