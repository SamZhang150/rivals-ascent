extends Control

func _ready():
	$TextureButton.pressed.connect(_on_play_pressed)
	$TextureButton.mouse_entered.connect(_on_button_hover)
	$TextureButton.mouse_exited.connect(_on_button_unhover)

func _on_play_pressed():
	Fade.transition_to("res://scenes/levels/days/day1.tscn")

func _on_button_hover():
	$TextureButton.scale = Vector2(1.05, 1.05)

func _on_button_unhover():
	$TextureButton.scale = Vector2(1.0, 1.0)
