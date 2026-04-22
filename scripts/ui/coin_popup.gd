extends Control

@onready var label: Label = $Label
@onready var icon: TextureRect = $CoinIcon

@export var rise_distance: float = 18.0
@export var lifetime: float = 0.8

func show_amount(amount: int) -> void:
	label.text = "+" + str(amount)
	modulate.a = 1.5

	var end_pos := global_position + Vector2(0, -rise_distance)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", end_pos, lifetime)
	tween.tween_property(self, "modulate:a", 0.0, lifetime)
	tween.finished.connect(queue_free)
