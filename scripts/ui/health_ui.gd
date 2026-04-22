extends Control

@onready var heart: TextureRect = $Heart
@onready var label: Label = $Label
@onready var health_bar: ProgressBar = $ProgressBar

@export var is_left: bool = false

func _ready() -> void:
	position = Vector2(10, 230)
	
	if !is_left:
		position = Vector2(275, 230)
		
	heart.position = Vector2(0, 0)
	label.position = Vector2(22 + health_bar.custom_minimum_size.x, -7)
	health_bar.position = Vector2(20, 2)
	health_bar.custom_minimum_size = Vector2(60, 6)

	health_bar.show_percentage = false

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#d64562")
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
