extends Area2D

@export var station_type: String = ""
@onready var station_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

var _nearby_players: Dictionary = {}


func _ready() -> void:
	_set_station_animation("default")


func _set_station_animation(animation_name: String) -> void:
	if station_sprite == null or station_sprite.sprite_frames == null:
		return
	if not station_sprite.sprite_frames.has_animation(animation_name):
		return
	if station_sprite.animation != animation_name:
		station_sprite.play(animation_name)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_near_shop_station"):
		_nearby_players[body.get_instance_id()] = true
		_set_station_animation("interact")
		body.set_near_shop_station(self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("clear_shop_station"):
		_nearby_players.erase(body.get_instance_id())
		if _nearby_players.is_empty():
			_set_station_animation("default")
		body.clear_shop_station(self)
