class_name TuningPanel
extends CanvasLayer
## Live sliders for every `@export_range` property on the bound Resources.
## Changes apply immediately. "Save" writes the Resource back to its .tres
## file, so a tuning you like can be committed.
##
## Toggle with Back/Select (gamepad) or Tab.

const PANEL_WIDTH := 380.0

var _sections: VBoxContainer
var _root: PanelContainer


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = PanelContainer.new()
	_root.anchor_top = 0.0
	_root.anchor_bottom = 1.0
	_root.anchor_left = 1.0
	_root.anchor_right = 1.0
	_root.offset_left = -PANEL_WIDTH
	_root.visible = false
	add_child(_root)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)

	_sections = VBoxContainer.new()
	_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_sections)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tuning"):
		_root.visible = not _root.visible
		get_viewport().set_input_as_handled()


## Adds a section with one slider per ranged property of `resource`.
func bind(resource: Resource, title: String) -> void:
	var header := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 18)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)

	var save := Button.new()
	save.text = "Save"
	save.disabled = resource.resource_path.is_empty()
	save.pressed.connect(func() -> void:
		var err := ResourceSaver.save(resource)
		save.text = "Saved" if err == OK else "Error %d" % err
		get_tree().create_timer(1.0).timeout.connect(func() -> void: save.text = "Save"))
	header.add_child(save)
	_sections.add_child(header)

	# Group headers are only added once a slider in that group shows up, so
	# built-in groups with nothing tunable (e.g. "Resource") are skipped.
	var pending_group := ""
	for prop in resource.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_GROUP:
			pending_group = prop["name"]
		elif usage & PROPERTY_USAGE_EDITOR and prop["hint"] == PROPERTY_HINT_RANGE:
			if not pending_group.is_empty():
				var group := Label.new()
				group.text = "  " + pending_group
				group.modulate = Color(0.7, 0.8, 1.0)
				_sections.add_child(group)
				pending_group = ""
			_sections.add_child(_make_slider_row(resource, prop))

	_sections.add_child(HSeparator.new())


func _make_slider_row(resource: Resource, prop: Dictionary) -> Control:
	var prop_name: String = prop["name"]
	var parts: PackedStringArray = str(prop["hint_string"]).split(",")

	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = prop_name.capitalize()
	name_label.custom_minimum_size.x = 170
	name_label.clip_text = true
	name_label.tooltip_text = prop_name
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = float(parts[0])
	slider.max_value = float(parts[1])
	slider.step = float(parts[2]) if parts.size() > 2 else 0.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Don't steal gamepad focus from riding.
	slider.focus_mode = Control.FOCUS_NONE
	slider.value = resource.get(prop_name)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 56
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = _format(slider.value)
	row.add_child(value_label)

	slider.value_changed.connect(func(value: float) -> void:
		resource.set(prop_name, int(value) if prop["type"] == TYPE_INT else value)
		value_label.text = _format(value))
	return row


static func _format(value: float) -> String:
	return str(snappedf(value, 0.001))
