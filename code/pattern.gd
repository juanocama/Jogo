extends TextureRect

func _process(delta):
	material.set_shader_parameter(
		"offset_y",
		min(Time.get_ticks_msec() / 10000.0, 0.5)
	)
