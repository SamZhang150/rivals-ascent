extends Control

@onready var label: Label = $Label
@onready var icon: TextureRect = $CoinIcon

@export var rise_distance: float = 18.0
@export var lifetime: float = 1.5

func show_amount(amount: int) -> void:
	
	if amount >= 0:
		label.text = "+" + str(amount)
		label.modulate = Color(0.222, 0.891, 0.439, 1.0)
	else:
		label.text = str(amount)
		label.modulate = Color(1.0, 0.3, 0.3, 1.0)
		
	visible = true
	modulate.a = 1.5

	var end_pos := global_position + Vector2(0, -rise_distance)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", end_pos, lifetime)
	tween.tween_property(self, "modulate:a", 0.0, lifetime)
	tween.finished.connect(queue_free)
