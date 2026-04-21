extends Control

@onready var health_bar: ProgressBar = $HealthContainer/ProgressBar
@onready var label: Label = $HealthContainer/Label
@onready var heart_icon: TextureRect = $HealthContainer/Heart

func _ready() -> void:
	# health bar style
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(90, 12)

	var fill = StyleBoxFlat.new()
	fill.bg_color = Color("#d64562")
	fill.corner_radius_top_left = 8
	fill.corner_radius_top_right = 8
	fill.corner_radius_bottom_left = 8
	fill.corner_radius_bottom_right = 8
	health_bar.add_theme_stylebox_override("fill", fill)

	var bg = StyleBoxFlat.new()
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
