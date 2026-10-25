extends CanvasLayer


func _ready():
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("death_screen")
	visible = false
	build()


func build():
	var dim = ColorRect.new()
	dim.color = Color(0.3, 0, 0, 0.7)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)

	var label = Label.new()
	label.text = "Вы погибли"
	label.add_theme_font_size_override("font_size", 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	var button = Button.new()
	button.text = "Заново"
	button.custom_minimum_size = Vector2(200, 64)
	button.pressed.connect(restart)
	box.add_child(button)


func show_death():
	visible = true
	get_tree().paused = true


func restart():
	get_tree().paused = false
	get_tree().reload_current_scene()
