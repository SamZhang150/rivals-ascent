extends Area2D

@export var station_type: String = ""

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_near_shop_station"):
		body.set_near_shop_station(self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("clear_shop_station"):
		body.clear_shop_station(self)
