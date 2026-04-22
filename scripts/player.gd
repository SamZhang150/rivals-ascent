## player.gd
## Attach to the root of player.tscn
##
## === PLAYER.TSCN NODE TREE ===
## Player (CharacterBody2D)             [script: player.gd]
## ├── AnimatedSprite2D                 ← player sprite/animation
## ├── CollisionShape2D                 ← physics body
## ├── HitboxArea (Area2D)              ← detects incoming damage
## │   └── CollisionShape2D
## ├── AttackArea (Area2D)              ← deals damage on attack
## │   └── CollisionShape2D
## └── AttackCooldownTimer (Timer)      [wait_time=0.4, one_shot=true]
##
## === INPUT MAP (Project > Input Map) ===
## You should have:
##   p1_up, p1_down, p1_left, p1_right, p1_attack, p1_ready, p1_interact
##   p2_up, p2_down, p2_left, p2_right, p2_attack, p2_ready, p2_interact

extends CharacterBody2D

# ─── CONFIG ──────────────────────────────────────────────
@export var speed: float = 50.0
@export var max_health: int = 100
@export var starter_weapon_scene: PackedScene = preload("res://scenes/entities/weapons/pistol.tscn")
@export var weapon_offset: Vector2 = Vector2(5, -1)

# ─── STATE ───────────────────────────────────────────────
var player_id: int = 1  # set by game manager on spawn

var can_move: bool = true
var can_attack: bool = false
var can_take_damage: bool = false
var damage_uses_coins: bool = false


var is_attacking: bool = false
var last_move_direction: Vector2 = Vector2.RIGHT
var equipped_weapon: Node2D = null

var is_invulnerable: bool = false
var damage_knockback: Vector2 = Vector2.ZERO

# Contact damage tracking
var _enemies_in_contact: Array[Node] = []
var _contact_damage_timer: Timer = null
@export var contact_damage_interval: float = 0.5  # How often to take damage while in contact

# Shop / progression state
var gold: int = 100
var inventory: Array[String] = []
var nearby_station: Area2D = null
var shop_ui_open: bool = false

# Input action prefixes
var _prefix: String = "p1_"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_timer: Timer = $AttackCooldownTimer
@onready var hitbox: Area2D = $HitboxArea

@export var health_ui_path: NodePath
var health_ui = get_node_or_null(health_ui_path)

@export var coin_ui_path: NodePath
var coin_ui = get_node_or_null(coin_ui_path)
@export var coin_popup_scene: PackedScene = preload("res://scenes/ui/coin_popup.tscn")


@onready var shop_ui: Node = get_tree().current_scene.get_node("UI/ShopUI")

signal died(player_id: int)


func _ready() -> void:
	add_to_group("player")
	hitbox.add_to_group("player_hitbox")
	
	_prefix = "p1_" if player_id == 1 else "p2_"
	attack_area.monitoring = false
	attack_timer.timeout.connect(_on_attack_cooldown_finished)
	
	# Set up contact damage timer
	_contact_damage_timer = Timer.new()
	_contact_damage_timer.wait_time = contact_damage_interval
	_contact_damage_timer.autostart = false
	_contact_damage_timer.timeout.connect(_on_contact_damage_timer)
	add_child(_contact_damage_timer)
	
	# Connect hitbox signals to track enemies in contact
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hitbox.area_exited.connect(_on_hitbox_area_exited)
	
	_set_health(get_max_health())
	_update_health_ui()
	_update_coin_ui()
	
	sprite.play(_prefix + "idle")
	_equip_starter_weapon()


func _physics_process(_delta: float) -> void:
	if shop_ui_open:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Gather directional input
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis(_prefix + "left", _prefix + "right")
	input_dir.y = Input.get_axis(_prefix + "up", _prefix + "down")
	input_dir = input_dir.normalized()
	
	if input_dir != Vector2.ZERO:
		last_move_direction = input_dir
		velocity = input_dir * speed
		sprite.play(_prefix + "run")
		if input_dir.x != 0:
			sprite.flip_h = input_dir.x < 0
			attack_area.scale.x = -1 if input_dir.x < 0 else 1
		_update_weapon_pose(input_dir)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		sprite.play(_prefix + "idle")
		
	velocity += damage_knockback
	damage_knockback = damage_knockback.move_toward(Vector2.ZERO, get_knockback_decay() * _delta)

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if shop_ui_open:
		if event.is_action_pressed(_prefix + "back"):
			close_shop_ui()
		return

	if nearby_station != null and event.is_action_pressed(_prefix + "interact"):
		open_shop_ui(nearby_station.station_type)
		return

	if not can_attack:
		return


func can_fire_weapon() -> bool:
	return not shop_ui_open and can_move and visible


func get_last_move_direction() -> Vector2:
	return last_move_direction


func get_attack_action_name() -> String:
	return _prefix + "attack"

func get_attack_damage() -> int:
	return Global.player_stats[player_id]["attack_damage"]


func get_attack_duration() -> float:
	return Global.player_stats[player_id]["attack_duration"]


func get_attack_cooldown() -> float:
	return Global.player_stats[player_id]["attack_cooldown"]
	
func get_invuln_time() -> float:
	return Global.player_stats[player_id]["invuln_time"]


func get_knockback_strength() -> float:
	return Global.player_stats[player_id]["knockback_strength"]


func get_knockback_decay() -> float:
	return Global.player_stats[player_id]["knockback_decay"]


func get_health() -> int:
	return Global.player_stats[player_id]["health"]

func get_max_health() -> int:
	return Global.player_stats[player_id]["max_health"]


func is_dead() -> bool:
	return Global.player_stats[player_id]["is_dead"]


func _set_health(value: int) -> void:
	Global.player_stats[player_id]["health"] = clamp(value, 0, get_max_health())


func _set_dead(value: bool) -> void:
	Global.player_stats[player_id]["is_dead"] = value
	
func set_phase_state(show_health: bool, damage_enabled: bool, use_coins: bool = false) -> void:
	can_take_damage = damage_enabled
	damage_uses_coins = use_coins
	if health_ui != null:
		health_ui.visible = show_health

func _update_health_ui() -> void:
	if health_ui != null and health_ui.has_method("set_health"):
		health_ui.set_health(get_health(), get_max_health())

func _update_coin_ui() -> void:
	if coin_ui != null and coin_ui.has_method("set_coins"):
		coin_ui.set_coins(gold)
		
func add_gold(amount: int) -> void:
	gold += amount
	_update_coin_ui()
	_show_coin_popup(amount)

func _show_coin_popup(amount: int) -> void:
	if coin_popup_scene == null:
		print("no coin popup scene assigned")
		return

	var popup = coin_popup_scene.instantiate()
	var world = get_tree().current_scene.get_node("World")
	world.add_child(popup)

	popup.position = global_position + Vector2(0, -30)
	popup.visible = true

	print("spawned popup at ", popup.position)

	if popup.has_method("show_amount"):
		popup.show_amount(amount)
	else:
		print("popup missing show_amount")
		
func _equip_starter_weapon() -> void:
	if starter_weapon_scene == null:
		return
	if equipped_weapon != null and is_instance_valid(equipped_weapon):
		equipped_weapon.queue_free()

	equipped_weapon = starter_weapon_scene.instantiate() as Node2D
	if equipped_weapon == null:
		return

	equipped_weapon.position = weapon_offset
	add_child(equipped_weapon)
	_update_weapon_pose(last_move_direction)


func _update_weapon_pose(move_dir: Vector2) -> void:
	if equipped_weapon == null or not is_instance_valid(equipped_weapon):
		return

	if move_dir == Vector2.ZERO:
		move_dir = last_move_direction
	move_dir = move_dir.normalized()

	var x: float = absf(weapon_offset.x)
	var y: float = weapon_offset.y
	var on_right_semicircle: bool = move_dir.x > 0.0

	if absf(move_dir.x) >= absf(move_dir.y):
		if move_dir.x < 0.0:
			equipped_weapon.position = Vector2(-x, y)
		else:
			equipped_weapon.position = Vector2(x, y)
	else:
		if move_dir.y < 0.0:
			equipped_weapon.position = Vector2(y, -x)
		else:
			equipped_weapon.position = Vector2(y, x)

	if on_right_semicircle:
		var right_angle: float = atan2(move_dir.y, move_dir.x)
		equipped_weapon.rotation = PI + right_angle
	else:
		var left_angle: float = atan2(-move_dir.y, -move_dir.x)
		equipped_weapon.rotation = left_angle

	var weapon_sprite := equipped_weapon.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if weapon_sprite != null:
		weapon_sprite.flip_h = false
		weapon_sprite.flip_v = on_right_semicircle


func _perform_attack() -> void:
	is_attacking = true
	attack_area.monitoring = true
	attack_timer.wait_time = get_attack_cooldown()
	attack_timer.start()


func _on_attack_cooldown_finished() -> void:
	is_attacking = false
	attack_area.monitoring = false

func take_damage(amount: int, from_position: Vector2) -> void:
	if is_dead():
		return
		
	if damage_uses_coins:
		if is_invulnerable:
			return
		gold = max(gold - amount, 0)
		_update_coin_ui()
		#print("lost ", amount, " coins")
		#print("now has ", gold, " coins")
		_start_invuln(get_invuln_time())
		damage_knockback = (global_position - from_position).normalized() * get_knockback_strength()
		return

	if not can_take_damage or is_invulnerable:
		return


	_set_health(get_health() - amount)
	_update_health_ui()
	_start_invuln(get_invuln_time())
	damage_knockback = (global_position - from_position).normalized() * get_knockback_strength()
		
	sprite.modulate = Color.RED
	get_tree().create_timer(0.15).timeout.connect(func() -> void:
		if not is_dead():
			sprite.modulate = Color.WHITE
	)

	if get_health() <= 0:
		_die()


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		var enemy = area.get_parent()
		if enemy != null and not _enemies_in_contact.has(enemy):
			_enemies_in_contact.append(enemy)
			
			take_damage(enemy.get("touch_damage"), enemy.global_position)
			
			# Start damage timer if not already running
			if _contact_damage_timer.is_stopped():
				_contact_damage_timer.start()


func _on_hitbox_area_exited(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		var enemy = area.get_parent()
		if enemy != null:
			var idx = _enemies_in_contact.find(enemy)
			if idx != -1:
				_enemies_in_contact.remove_at(idx)
			# Stop timer if no enemies in contact
			if _enemies_in_contact.is_empty():
				_contact_damage_timer.stop()


func _on_contact_damage_timer() -> void:
	if is_dead():
		return
		
	_enemies_in_contact = _enemies_in_contact.filter(func(e): return is_instance_valid(e))
	if _enemies_in_contact.is_empty():
		_contact_damage_timer.stop()
		return
	
	# Apply damage from all enemies in contact
	for enemy in _enemies_in_contact:
		var dmg = enemy.get("touch_damage")
		if dmg != null:
			take_damage(int(dmg), enemy.global_position)
			break


func _die() -> void:
	if shop_ui_open:
		close_shop_ui()

	_set_dead(true)
	can_move = false
	can_attack = false
	visible = false

	var game_manager := get_tree().current_scene
	if game_manager != null and game_manager.has_method("on_player_died"):
		game_manager.on_player_died(player_id)


func reset_for_round() -> void:
	if shop_ui_open:
		close_shop_ui()

	_set_dead(false)
	_set_health(get_max_health())
	_update_health_ui()

	is_invulnerable = false
	can_move = true
	visible = true
	sprite.modulate = Color.WHITE
	is_attacking = false
	attack_area.monitoring = false


func respawn_at(pos: Vector2) -> void:
	reset_for_round()
	global_position = pos
	_start_invuln(get_invuln_time())


func _start_invuln(duration: float) -> void:
	is_invulnerable = true
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "modulate:a", 0.2, 0.1)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		tween.kill()
		sprite.modulate.a = 1.0
		is_invulnerable = false
	)


# ─── SHOP INTERACTION ────────────────────────────────────

func set_near_shop_station(station: Area2D) -> void:
	nearby_station = station
	if shop_ui != null and shop_ui.has_method("show_prompt"):
		shop_ui.show_prompt("Press interact to use station")


func clear_shop_station(station: Area2D) -> void:
	if nearby_station == station:
		nearby_station = null
		if shop_ui != null and shop_ui.has_method("hide_prompt"):
			shop_ui.hide_prompt()


func open_shop_ui(mode: String) -> void:
	shop_ui_open = true
	can_move = false
	can_attack = false

	if shop_ui != null and shop_ui.has_method("open_ui"):
		shop_ui.open_ui(mode, self)


func close_shop_ui() -> void:
	shop_ui_open = false
	can_move = true
	can_attack = true

	if shop_ui != null and shop_ui.has_method("close_ui_for_player"):
		shop_ui.close_ui_for_player(player_id)
