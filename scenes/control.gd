extends Control

@onready var image_a = $Image_A
@onready var image_b = $Image_B

var textures = [
	preload("res://assets/Main Menu/Desk.png"),
	preload("res://assets/Main Menu/Burned_desk.png"),
	preload("res://assets/Main Menu/Leaves.png")
]

var current_index = 0
var showing_a = true

func _ready():
	
	image_a.texture = textures[0]
	image_a.modulate.a = 1.0

	image_b.modulate.a = 0.0

	start_slide()

func change_image():
	var current = image_a if showing_a else image_b
	var next = image_b if showing_a else image_a
	
	current_index = (current_index + 1) % textures.size()
	
	next.texture = textures[current_index]
	next.modulate.a = 0.0
	
	next.material.set_shader_parameter("offset_y",0.0)
	next.material.set_shader_parameter("zoom",1.0)
	
	var fade = create_tween()
	
	fade.parallel().tween_property(
		next,
		"modulate:a",
		1.0,
		1.5
	)
	
	await fade.finished
	
	showing_a = !showing_a
	
	start_slide()
	
func start_slide():

	var active = image_a if showing_a else image_b

	active.material.set_shader_parameter("offset_y", 0.0)
	active.material.set_shader_parameter("zoom", 1.0)

	var tween = create_tween()

	tween.parallel().tween_method(
		func(v):
			active.material.set_shader_parameter("offset_y", v),
		0.0,
		0.3,
		6.0
	)

	tween.parallel().tween_method(
		func(v):
			active.material.set_shader_parameter("zoom", v),
		1.0,
		1.15,
		6.0
	)

	tween.finished.connect(change_image)
	
