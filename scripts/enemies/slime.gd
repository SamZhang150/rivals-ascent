extends CharacterBody2D

signal died

@export var speed := 10.0
@export var max_health := 7
@export var touch_damage := 2
@export var knockback_strength := 110.0

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
var knockback := Vector2.ZERO
var player: CharacterBody2D = null

func _ready() -> void:
	add_to_group("enemies")
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)

	health = max_health
	health_bar.position = Vector2(-14, -12)
	bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	health_bar.visible = false

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
		velocity = dir * speed
		sprite.play("run")
		if dir.x != 0:
			sprite.flip_h = dir.x < 0
	else:
		velocity = Vector2.ZERO
		sprite.play("idle")

	move_and_slide()

func take_damage(amount: int, from_position: Vector2) -> void:
	if dead:
		return

	health -= amount
	health = clamp(health, 0, max_health)

	var ratio := float(health) / float(max_health)
	bar_fill.size.x = BAR_WIDTH * ratio
	health_bar.visible = health < max_health

	knockback = (global_position - from_position).normalized() * knockback_strength

	if health <= 0:
		die()

func _on_hurtbox_area_entered(body: Node) -> void:
	if body == player and body.has_method("take_damage"):
		body.take_damage(touch_damage)
		
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox"):
		var player = area.get_parent()
		if player.has_method("take_damage"):
			player.take_damage(touch_damage)

func die() -> void:
	if dead:
		return
	dead = true
	died.emit()
	queue_free()
