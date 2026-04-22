extends Control

@onready var coin_icon: TextureRect = $CoinIcon
@onready var label: Label = $CoinLabel

@export var is_left: bool = false

func _ready() -> void:
	# top-right of each player's screen
	if is_left:
		position = Vector2(5, 218)
		coin_icon.position = Vector2(0, -1)
		label.position = Vector2(18, 1)
		
	else:
		position = Vector2(412, 218)
		coin_icon.position = Vector2(18, -1)
		label.position = Vector2(1, 2)
	

	
	label.text = "0"

func set_coins(amount: int) -> void:
	label.text = str(amount)
