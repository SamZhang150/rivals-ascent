extends Control

@onready var heart: TextureRect = $Heart
@onready var label: Label = $Label
@onready var health_bar: ProgressBar = $ProgressBar

@export var is_left: bool = false

func _ready() -> void:
	if is_left:
		position = Vector2(5, 235)
		heart.position = Vector2(0, 1)
		label.position = Vector2(22 + health_bar.custom_minimum_size.x, 2)
		health_bar.position = Vector2(17, 2)
	else:
		position = Vector2(338, 235)
		heart.position = Vector2(22 + health_bar.custom_minimum_size.x, 0)
		label.position = Vector2(-30, 2)
		health_bar.position = Vector2(17, 2)
		
	
	health_bar.custom_minimum_size = Vector2(61, 6)

	health_bar.show_percentage = false

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("e52f44ff")
	fill.border_color = Color("630a16ff")
	fill.corner_radius_top_left = 8
	fill.corner_radius_top_right = 8
	fill.corner_radius_bottom_left = 8
	fill.corner_radius_bottom_right = 8
	health_bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#2a2a35")
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8
	bg.corner_radius_bottom_right = 8
	health_bar.add_theme_stylebox_override("background", bg)

func set_health(current: int, max_health: int) -> void:
	health_bar.max_value = max_health
	health_bar.value = current
	label.text = str(current) + " / " + str(max_health)
