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
##   p1_up, p1_down, p1_left, p1_right, p1_attack, p1_ready, p1_interact, p1_dash
##   p2_up, p2_down, p2_left, p2_right, p2_attack, p2_ready, p2_interact, p2_dash
##   p1_aim_up, p1_aim_down, p1_aim_left, p1_aim_right
##   p2_aim_up, p2_aim_down, p2_aim_left, p2_aim_right

extends CharacterBody2D

# ─── CONFIG ──────────────────────────────────────────────
@export var speed: float = 50.0
@export var max_health: int = 100
@export_dir var weapon_scene_directory: String = "res://scenes/entities/weapons"
@export var starter_weapon_key: String = "pistol"
@export var weapon_offset: Vector2 = Vector2(5, -1)
@export var aim_deadzone: float = 0.25
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.3
@export var dash_cooldown: float = 0.9

# ─── STATE ───────────────────────────────────────────────
var player_id: int = 1  # set by game manager on spawn

var can_move: bool = true
var can_attack: bool = false
var can_take_damage: bool = false
var damage_uses_coins: bool = false
var is_readied_up: bool = false


var is_attacking: bool = false
var last_move_direction: Vector2 = Vector2.RIGHT
var last_aim_direction: Vector2 = Vector2.RIGHT
var equipped_weapon: Node2D = null
var current_weapon_index: int = 0

var is_invulnerable: bool = false
var damage_knockback: Vector2 = Vector2.ZERO
var magnet_pull: Vector2 = Vector2.ZERO


# Contact damage tracking
var _enemies_in_contact: Array[Node] = []
var _contact_damage_timer: Timer = null
@export var contact_damage_interval: float = 0.5  # How often to take damage while in contact

# Shop / progression state
const STARTING_GOLD := 30
var gold: int = STARTING_GOLD
var inventory: Array[String] = []
var nearby_station: Area2D = null
var shop_ui_open: bool = false

# Input action prefixes
var _prefix: String = "p1_"

var _weapon_scenes: Dictionary = {}
var _weapon_instances: Dictionary = {}
const _WEAPON_KEY_ALIASES := {
	"grenadelauncher": "grenade_launcher",
	"goldak47": "gold_ak"
}

# Dash
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var _dash_anim_playing: bool = false
var _dash_timer: Timer = null
var _dash_recharge_timer: Timer = null
var _teleport_fade_tween: Tween = null
var _slow_timer: Timer = null
var _slow_active: bool = false
var _damage_flash_active: bool = false
var _stun_timer: Timer = null
var _stun_active: bool = false
var _stun_saved_can_move: bool = true
var _stun_saved_can_attack: bool = false
var speed_modifier = 1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_timer: Timer = $AttackCooldownTimer
@onready var hitbox: Area2D = $HitboxArea

@export var health_ui_path: NodePath
var health_ui = get_node_or_null(health_ui_path)

@export var coin_ui_path: NodePath
var coin_ui = get_node_or_null(coin_ui_path)
var ammo_ui = null
@export var coin_popup_scene: PackedScene = preload("res://scenes/ui/coin_popup.tscn")

@onready var shop_ui: Node = get_tree().current_scene.get_node("UI/ShopUI")

signal died(player_id: int)
signal weapon_changed(weapon: Node2D)


func _ready() -> void:
	add_to_group("player")
	hitbox.add_to_group("player_hitbox")
	hitbox.monitoring = true
	hitbox.monitorable = true
	
	_prefix = "p1_" if player_id == 1 else "p2_"
	_register_weapon_scenes()
	attack_area.monitoring = false
	attack_timer.timeout.connect(_on_attack_cooldown_finished)
	
	# Set up contact damage timer
	_contact_damage_timer = Timer.new()
	_contact_damage_timer.wait_time = contact_damage_interval
	_contact_damage_timer.autostart = false
	_contact_damage_timer.timeout.connect(_on_contact_damage_timer)
	add_child(_contact_damage_timer)
	
	# Dash timers
	_dash_timer = Timer.new()
	_dash_timer.one_shot = true
	_dash_timer.wait_time = dash_duration
	_dash_timer.timeout.connect(_on_dash_finished)
	add_child(_dash_timer)

	_dash_recharge_timer = Timer.new()
	_dash_recharge_timer.one_shot = true
	_dash_recharge_timer.wait_time = dash_cooldown
	_dash_recharge_timer.timeout.connect(_on_dash_recharge_finished)
	add_child(_dash_recharge_timer)

	_slow_timer = Timer.new()
	_slow_timer.one_shot = true
	_slow_timer.wait_time = 2.0
	_slow_timer.timeout.connect(_on_slow_finished)
	add_child(_slow_timer)

	_stun_timer = Timer.new()
	_stun_timer.one_shot = true
	_stun_timer.wait_time = 0.1
	_stun_timer.timeout.connect(_on_stun_finished)
	add_child(_stun_timer)
	
	# Connect hitbox signals to track enemies in contact
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hitbox.area_exited.connect(_on_hitbox_area_exited)
	sprite.animation_finished.connect(_on_sprite_animation_finished)

	# Keep movement speed source-of-truth in global stats.
	if Global.player_stats.has(player_id):
		if not Global.player_stats[player_id].has("speed"):
			Global.player_stats[player_id]["speed"] = speed
		speed = float(Global.player_stats[player_id]["speed"])
	
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

	if _stun_active:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# During dash, ignore normal movement input
	if is_dashing:
		velocity = dash_direction * dash_speed
		velocity += damage_knockback
		damage_knockback = damage_knockback.move_toward(Vector2.ZERO, get_knockback_decay() * _delta)
		move_and_slide()
		return

	# Gather movement and aiming input. Movement keeps analog magnitude for controllers.
	var input_dir := _get_move_input()
	var aim_dir := _get_aim_input()
	
	if input_dir != Vector2.ZERO:
		last_move_direction = input_dir
		if aim_dir == Vector2.ZERO:
			last_aim_direction = input_dir.normalized()
		velocity = input_dir * get_move_speed() * speed_modifier
		if not _dash_anim_playing:
			sprite.play(_prefix + "run")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, get_move_speed())
		if not _dash_anim_playing:
			sprite.play(_prefix + "idle")

	if aim_dir != Vector2.ZERO:
		last_aim_direction = aim_dir

	var facing_dir := input_dir if input_dir != Vector2.ZERO else last_aim_direction
	if facing_dir.x != 0:
		sprite.flip_h = facing_dir.x < 0
		attack_area.scale.x = -1 if facing_dir.x < 0 else 1

	_update_weapon_pose(last_aim_direction)
		
	velocity += damage_knockback
	damage_knockback = damage_knockback.move_toward(Vector2.ZERO, get_knockback_decay() * _delta)

	velocity += magnet_pull
	magnet_pull = Vector2.ZERO
	
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if shop_ui_open:
		if event.is_action_pressed(_prefix + "back"):
			close_shop_ui()
		return

	if _stun_active:
		return

	if nearby_station != null and event.is_action_pressed(_prefix + "interact"):
		open_shop_ui(nearby_station.station_type)
		return

	if event.is_action_pressed(_prefix + "dash"):
		_try_dash()
		return

	if event.is_action_pressed(_prefix + "invprev"):
		cycle_weapon(-1)
		return

	if event.is_action_pressed(_prefix + "invnext"):
		cycle_weapon(1)
		return

	if not can_attack:
		return


func can_fire_weapon() -> bool:
	return not shop_ui_open and not is_readied_up and can_move and visible


func set_ready_state(is_ready: bool) -> void:
	is_readied_up = is_ready


func get_last_move_direction() -> Vector2:
	return last_move_direction


func get_weapon_aim_direction() -> Vector2:
	if last_aim_direction != Vector2.ZERO:
		return last_aim_direction
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


func get_move_speed() -> float:
	if Global.player_stats.has(player_id):
		return float(Global.player_stats[player_id].get("speed", speed))
	return speed


func is_dead() -> bool:
	return Global.player_stats[player_id]["is_dead"]


func _set_health(value: int) -> void:
	Global.player_stats[player_id]["health"] = clamp(value, 0, get_max_health())


func _set_dead(value: bool) -> void:
	Global.player_stats[player_id]["is_dead"] = value
	
func set_phase_state(show_health: bool, damage_enabled: bool, use_coins: bool = false) -> void:
	can_take_damage = damage_enabled
	damage_uses_coins = use_coins
	if not damage_enabled:
		_clear_temporary_damage_status()
	if health_ui != null:
		health_ui.visible = show_health


func _clear_temporary_damage_status() -> void:
	_damage_flash_active = false
	_slow_active = false
	speed_modifier = 1.0

	if _slow_timer != null:
		_slow_timer.stop()

	if _stun_active:
		_stun_active = false
		can_move = _stun_saved_can_move
		can_attack = _stun_saved_can_attack

	if _stun_timer != null:
		_stun_timer.stop()

	_refresh_sprite_tint()

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
	$Coin.play()
	$EnemyDeath.play()


func award_fast_clear_bonus(amount: int = 15) -> void:
	gold += amount
	_update_coin_ui()
	_show_coin_popup(amount, "+%d gold\n(fast\nclear\nbonus)" % amount)
	$Coin.play()

func _show_coin_popup(amount: int, custom_text: String = "") -> void:
	if coin_popup_scene == null:
		print("no coin popup scene assigned")
		return

	var popup = coin_popup_scene.instantiate()
	var world = get_tree().current_scene.get_node("World")
	world.add_child(popup)

	popup.position = global_position + Vector2(0, -30)
	popup.visible = true

	print("spawned popup at ", popup.position)

	if custom_text != "" and popup.has_method("show_text"):
		popup.show_text(custom_text)
	elif popup.has_method("show_amount"):
		popup.show_amount(amount)
	else:
		print("popup missing show_amount")

func _equip_starter_weapon() -> void:
	if not inventory.has("pistol"):
		inventory.append("pistol")
	# if not inventory.has("deagle"):
	# 	inventory.append("deagle")
	# if not inventory.has("baseball"):
	# 	inventory.append("baseball")
	# if not inventory.has("6shooter"):
	# 	inventory.append("6shooter")
	# if not inventory.has("gungun"):
	# 	inventory.append("gungun")
	# if not inventory.has("papershuriken"):
	# 	inventory.append("papershuriken")
	# if not inventory.has("shuriken"):
	# 	inventory.append("shuriken")
	# if not inventory.has("slimelauncher"):
	# 	inventory.append("slimelauncher")
	# if not inventory.has("50cal"):
	# 	inventory.append("50cal")
	# if not inventory.has("grenade_launcher"):
	# 	inventory.append("grenade_launcher")
	# if not inventory.has("revolver"):
	# 	inventory.append("revolver")
	# if not inventory.has("shotgun"):
	# 	inventory.append("shotgun")
	# if not inventory.has("sawedoff"):
	# 	inventory.append("sawedoff")
	# if not inventory.has("ak47"):
	# 	inventory.append("ak47")
	# if not inventory.has("gold_ak"):
	# 	inventory.append("gold_ak")
	# if not inventory.has("watergun"):
	# 	inventory.append("watergun")
	# if not inventory.has("stratocaster"):
	# 	inventory.append("stratocaster")
	# if not inventory.has("jazzmaster"):
	# 	inventory.append("jazzmaster")
	# if not inventory.has("telecaster"):
	# 	inventory.append("telecaster")
	# if not inventory.has("2xbow"):
	# 	inventory.append("2xbow")
	# if not inventory.has("sparkbolt"):
	# 	inventory.append("sparkbolt")
	# if not inventory.has("zeusbolt"):
	# 	inventory.append("zeusbolt")
	# if not inventory.has("taserlaser"):
	# 	inventory.append("taserlaser")
	current_weapon_index = inventory.find(starter_weapon_key)
	if current_weapon_index == -1:
		current_weapon_index = 0
	var starter_scene := get_weapon_scene_for_key(starter_weapon_key)
	if starter_scene != null:
		equip_weapon_scene(starter_scene)


func _register_weapon_scenes() -> void:
	_weapon_scenes.clear()
	var dir := DirAccess.open(weapon_scene_directory)
	if dir == null:
		push_warning("Unable to open weapon scene directory: " + weapon_scene_directory)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "tscn":
			var scene_path := weapon_scene_directory.path_join(file_name)
			var scene := load(scene_path) as PackedScene
			if scene != null:
				var base_name := file_name.get_basename().to_lower()
				var weapon_key := String(_WEAPON_KEY_ALIASES.get(base_name, base_name))
				_weapon_scenes[weapon_key] = scene
		file_name = dir.get_next()
	dir.list_dir_end()


func get_weapon_scene_for_key(weapon_key: String) -> PackedScene:
	if not _weapon_scenes.has(weapon_key):
		return null
	return _weapon_scenes[weapon_key] as PackedScene


func add_weapon_to_inventory(weapon_key: String, auto_equip: bool = true) -> bool:
	if weapon_key == "":
		return false
	if not _weapon_scenes.has(weapon_key):
		push_warning("Unknown weapon key: " + weapon_key)
		return false
	if not inventory.has(weapon_key):
		inventory.append(weapon_key)

	if auto_equip:
		var idx := inventory.find(weapon_key)
		if idx != -1:
			current_weapon_index = idx
		equip_weapon_scene(_weapon_scenes[weapon_key])

	return true


func has_weapon_scene(weapon_scene: PackedScene) -> bool:
	var weapon_key := get_weapon_key_for_scene(weapon_scene)
	if weapon_key.is_empty():
		return false
	return inventory.has(weapon_key)


func add_weapon_scene_to_inventory(weapon_scene: PackedScene, auto_equip: bool = true) -> bool:
	var weapon_key := get_weapon_key_for_scene(weapon_scene)
	if weapon_key.is_empty():
		push_warning("Unable to map weapon scene to key: " + str(weapon_scene))
		return false
	return add_weapon_to_inventory(weapon_key, auto_equip)


func get_weapon_key_for_scene(weapon_scene: PackedScene) -> String:
	if weapon_scene == null:
		return ""
	for weapon_key in _weapon_scenes.keys():
		if _weapon_scenes[weapon_key] == weapon_scene:
			return weapon_key
	return ""


func cycle_weapon(direction: int) -> void:
	if inventory.size() <= 1:
		return
	if shop_ui_open or not can_move:
		return
	if is_dashing:
		return

	current_weapon_index = wrapi(current_weapon_index + direction, 0, inventory.size())
	var weapon_key: String = inventory[current_weapon_index]
	if not _weapon_scenes.has(weapon_key):
		return

	equip_weapon_scene(_weapon_scenes[weapon_key])


func equip_weapon_scene(weapon_scene: PackedScene) -> void:
	if weapon_scene == null:
		return
	if equipped_weapon != null and is_instance_valid(equipped_weapon):
		_set_weapon_active(equipped_weapon, false)

	equipped_weapon = _get_or_create_weapon_instance(weapon_scene)
	if equipped_weapon == null:
		return

	_set_weapon_active(equipped_weapon, true)
	equipped_weapon.position = weapon_offset
	_update_weapon_pose(last_aim_direction)

	if ammo_ui != null and ammo_ui.has_method("set_weapon"):
		ammo_ui.call("set_weapon", equipped_weapon)
	weapon_changed.emit(equipped_weapon)


func _get_or_create_weapon_instance(weapon_scene: PackedScene) -> Node2D:
	var cache_key: String = _get_weapon_cache_key(weapon_scene)
	if _weapon_instances.has(cache_key):
		var cached_weapon := _weapon_instances[cache_key] as Node2D
		if is_instance_valid(cached_weapon):
			return cached_weapon
		_weapon_instances.erase(cache_key)

	var weapon_instance := weapon_scene.instantiate() as Node2D
	if weapon_instance == null:
		return null

	_weapon_instances[cache_key] = weapon_instance
	add_child(weapon_instance)
	return weapon_instance


func _get_weapon_cache_key(weapon_scene: PackedScene) -> String:
	if not weapon_scene.resource_path.is_empty():
		return weapon_scene.resource_path
	return str(weapon_scene.get_instance_id())


func _set_weapon_active(weapon: Node2D, active: bool) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if weapon.has_method("set_equipped"):
		weapon.call("set_equipped", active)
	else:
		weapon.visible = active


func _get_move_input() -> Vector2:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis(_prefix + "left", _prefix + "right")
	input_dir.y = Input.get_axis(_prefix + "up", _prefix + "down")
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	return input_dir


func _get_aim_input() -> Vector2:
	var aim_dir := Vector2.ZERO
	aim_dir.x = Input.get_axis(_prefix + "aim_left", _prefix + "aim_right")
	aim_dir.y = Input.get_axis(_prefix + "aim_up", _prefix + "aim_down")
	if aim_dir.length() < aim_deadzone:
		return Vector2.ZERO
	if aim_dir.length() > 1.0:
		aim_dir = aim_dir.normalized()
	return aim_dir


func _update_weapon_pose(move_dir: Vector2) -> void:
	if equipped_weapon == null or not is_instance_valid(equipped_weapon):
		return

	if move_dir == Vector2.ZERO:
		move_dir = last_move_direction
	move_dir = move_dir.normalized()

	var radius: float = absf(weapon_offset.x)
	equipped_weapon.position = (move_dir * radius) + Vector2(0.0, weapon_offset.y)
	equipped_weapon.rotation = move_dir.angle() + PI

	var on_right_semicircle: bool = move_dir.x >= 0.0

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
	if is_dead() or is_invulnerable or is_dashing:
		return
		
	if damage_uses_coins:
		if is_invulnerable:
			return
		gold = max(gold - amount, 0)
		_update_coin_ui()
		$Damage.play()
		if not gold <= 0:
			_show_coin_popup(-amount)
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

	_damage_flash_active = true
	_refresh_sprite_tint()
	get_tree().create_timer(0.15).timeout.connect(func() -> void:
		if not is_dead():
			_damage_flash_active = false
			_refresh_sprite_tint()
	)
	$Damage.play()
	if get_health() <= 0:
		$Death.play()
		_die()

func get_slowed(_amount: float) -> void:
	if is_dead() or is_dashing:
		return

	if not can_take_damage:
		return

	_slow_active = true
	speed_modifier = _amount
	_set_slow_visual(true)
	if _slow_timer != null:
		_slow_timer.start(1.5)


func apply_chain_stun(incoming_damage: int, stun_time: float, _chain_amount: int = 0, _chain_damage: float = 0.0, _chain_dist: float = 0.0, _damager: Node = null) -> void:
	if is_dead():
		return
	if not can_take_damage:
		return
	take_damage(incoming_damage, global_position)
	_apply_stun(stun_time * 0.75)


func _apply_stun(stun_time: float) -> void:
	if stun_time <= 0.0 or is_dead():
		return

	if not _stun_active:
		_stun_saved_can_move = can_move
		_stun_saved_can_attack = can_attack

	_stun_active = true
	can_move = false
	can_attack = false

	if is_dashing:
		is_dashing = false
		_set_dash_collision_ignored(false)

	_refresh_sprite_tint()
	if _stun_timer != null:
		_stun_timer.start(stun_time)


func _on_stun_finished() -> void:
	if not _stun_active:
		return
	_stun_active = false

	if not is_dead():
		can_move = _stun_saved_can_move
		can_attack = _stun_saved_can_attack
		_refresh_sprite_tint()


func apply_magnet_pull(force: Vector2) -> void:
	magnet_pull += force
	

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


func _set_dash_collision_ignored(ignored: bool) -> void:
	hitbox.monitoring = not ignored
	hitbox.monitorable = not ignored
	if ignored:
		_enemies_in_contact.clear()
		_contact_damage_timer.stop()
		return
	call_deferred("_refresh_enemy_contacts")


func _refresh_enemy_contacts() -> void:
	if hitbox == null or not hitbox.monitoring:
		return

	_enemies_in_contact.clear()
	for area in hitbox.get_overlapping_areas():
		if not area.is_in_group("enemy_hitbox"):
			continue
		var enemy := area.get_parent()
		if enemy != null and is_instance_valid(enemy) and not _enemies_in_contact.has(enemy):
			_enemies_in_contact.append(enemy)

	if _enemies_in_contact.is_empty():
		_contact_damage_timer.stop()
		return

	var enemy := _enemies_in_contact[0]
	var touch_damage = enemy.get("touch_damage")
	if touch_damage != null:
		take_damage(int(touch_damage), enemy.global_position)

	if _contact_damage_timer.is_stopped():
		_contact_damage_timer.start()


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
	modulate = Color.WHITE
	sprite.modulate = Color.WHITE
	speed_modifier = 1.0
	is_attacking = false
	attack_area.monitoring = false
	_set_dash_collision_ignored(false)

	is_dashing = false
	dash_direction = Vector2.ZERO
	_dash_anim_playing = false
	_stun_active = false
	if _stun_timer != null:
		_stun_timer.stop()


func reset_for_new_match() -> void:
	gold = STARTING_GOLD
	inventory.clear()
	current_weapon_index = 0
	nearby_station = null
	shop_ui_open = false

	for weapon in _weapon_instances.values():
		var weapon_node := weapon as Node2D
		if weapon_node != null and is_instance_valid(weapon_node):
			weapon_node.queue_free()
	_weapon_instances.clear()
	equipped_weapon = null

	_equip_starter_weapon()
	reset_for_round()
	_update_coin_ui()


func respawn_at(pos: Vector2) -> void:
	reset_for_round()
	teleport_to_position(pos)
	_start_invuln(get_invuln_time())


func teleport_to_position(pos: Vector2, fade_duration: float = 0.4) -> void:
	global_position = pos
	_play_teleport_fade(fade_duration)


func _play_teleport_fade(fade_duration: float = 0.4) -> void:
	if _teleport_fade_tween != null:
		_teleport_fade_tween.kill()

	visible = true
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	if fade_duration <= 0.0:
		modulate.a = 1.0
		return

	var step_alphas := [0.25, 0.5, 0.75, 1.0]
	var step_duration := fade_duration / step_alphas.size()
	_teleport_fade_tween = create_tween()
	for alpha in step_alphas:
		_teleport_fade_tween.tween_interval(step_duration)
		_teleport_fade_tween.tween_callback(_set_teleport_fade_alpha.bind(alpha))


func _set_teleport_fade_alpha(alpha: float) -> void:
	modulate.a = alpha


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

func _try_dash() -> void:
	var stats = Global.player_stats[player_id]
	var dashes_available: int = int(stats.get("dashes_available", 0))
	
	if dashes_available <= 0:
		return
	if _dash_recharge_timer.is_stopped() == false:
		return
	if not can_move:
		return
	if shop_ui_open:
		return

	var input_dir := _get_move_input()
	input_dir = input_dir.normalized()

	if input_dir == Vector2.ZERO:
		input_dir = last_move_direction.normalized()

	if input_dir == Vector2.ZERO:
		return

	is_dashing = true
	_set_dash_collision_ignored(true)
	_dash_anim_playing = true
	sprite.play(_prefix + "dash")
	sprite.frame = 0
	sprite.frame_progress = 0.0
	dashes_available -= 1
	stats["dashes_available"] = dashes_available
	
	dash_direction = input_dir
	last_move_direction = input_dir

	if dash_direction.x != 0:
		sprite.flip_h = dash_direction.x < 0
		attack_area.scale.x = -1 if dash_direction.x < 0 else 1

	_update_weapon_pose(dash_direction)

	_dash_timer.start()
	$Dash.play()
	
	# If all dashes used, start recharge timer
	if dashes_available <= 0:
		_dash_recharge_timer.start()


func _on_dash_finished() -> void:
	is_dashing = false
	_set_dash_collision_ignored(false)


func _on_sprite_animation_finished() -> void:
	if sprite.animation == _prefix + "dash":
		_dash_anim_playing = false


func _on_dash_recharge_finished() -> void:
	var stats = Global.player_stats[player_id]
	stats["dashes_available"] = int(stats.get("dashes_max", 0))


func _on_slow_finished() -> void:
	_slow_active = false
	speed_modifier = 1.0
	if not is_dead():
		_set_slow_visual(false)


func _set_slow_visual(is_slowed: bool) -> void:
	_slow_active = is_slowed
	_refresh_sprite_tint()


func _refresh_sprite_tint() -> void:
	if sprite == null:
		return
	var alpha: float = sprite.modulate.a
	if _damage_flash_active:
		sprite.modulate = Color(1.0, 0.3, 0.3, alpha)
	elif _stun_active:
		sprite.modulate = Color(1.0, 1.0, 0.25, alpha)
	elif _slow_active:
		sprite.modulate = Color(0.6, 1.0, 0.6, alpha)
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0, alpha)

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
