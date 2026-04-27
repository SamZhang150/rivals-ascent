extends Area2D

@export var speed: float = 180.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var damage: int = 8
var owner_enemy: Node = null

func setup(new_direction: Vector2, new_damage: int, new_owner: Node = null) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	owner_enemy = new_owner

func _ready() -> void:
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	get_tree().create_timer(lifetime).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	print("projectile area hit: ", area.name, " groups: ", area.get_groups())

	if area.is_in_group("player_hitbox"):
		var player := area.get_parent()
		if player != null and player.has_method("take_damage"):
			player.take_damage(damage, global_position)
			queue_free()

func _on_body_entered(body: Node) -> void:
	print("projectile body hit: ", body.name)

	if body == owner_enemy:
		return
