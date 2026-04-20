extends Control

func _ready():
	$TextureButton.pressed.connect(_on_play_pressed)
	$TextureButton.mouse_entered.connect(_on_button_hover)
	$TextureButton.mouse_exited.connect(_on_button_unhover)

func _on_play_pressed():
	Fade.transition_to("res://scenes/levels/shared/lobby.tscn")

func _on_button_hover():
	$TextureButton.scale = Vector2(.11, 0.11)

func _on_button_unhover():
	$TextureButton.scale = Vector2(0.1, 0.1)
