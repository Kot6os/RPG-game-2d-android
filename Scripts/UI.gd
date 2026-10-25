extends CanvasLayer
# Интерфейс собирается кодом: уровень, полоска HP, полоска опыта (сверху слева).

const HP_GOOD = Color(0.30, 0.78, 0.35)
const HP_MID = Color(0.95, 0.65, 0.20)
const HP_LOW = Color(0.90, 0.22, 0.22)
const XP_COLOR = Color(0.35, 0.60, 0.95)
const PANEL_BG = Color(0.08, 0.09, 0.12, 0.88)
const PANEL_BORDER = Color(1, 1, 1, 0.18)
const GOLD = Color(1.0, 0.85, 0.35)

var player = null
var stats = null

var level_label: Label
var hp_bar: ProgressBar
var hp_fill: StyleBoxFlat
var hp_text: Label
var xp_bar: ProgressBar
var xp_text: Label
var hp_tween: Tween
var xp_tween: Tween


func _ready():
	layer = 10
	add_to_group("ui")   # по этой группе игрок находит интерфейс
	# старый интерфейс из сцены убираем, теперь всё строится здесь
	for child in get_children():
		remove_child(child)
		child.queue_free()
	build_hud()
	call_deferred("connect_player")   # ждём, пока загрузится игрок


func connect_player():
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("UI: игрок не найден (у него должна быть группа player)")
		return
	stats = player.stats
	stats.changed.connect(refresh)
	set_hp(player.hp, player.max_hp)
	refresh()


# ============ ИНСТРУМЕНТЫ ДЛЯ СБОРКИ ИНТЕРФЕЙСА ============

func make_style(color: Color, radius: int = 6, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if border.a > 0.0:
		s.set_border_width_all(2)
		s.border_color = border
	return s


func make_label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# полоска со скруглением, рамкой и текстом по центру
func make_bar(fill: StyleBoxFlat, height: int, font_size: int) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(280, height)
	bar.add_theme_stylebox_override("background", make_style(Color(0, 0, 0, 0.55), 6, PANEL_BORDER))
	bar.add_theme_stylebox_override("fill", fill)
	var text = make_label("", font_size)
	text.name = "Text"
	text.add_theme_constant_override("outline_size", 4)
	text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(text)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return bar


# ============ ПАНЕЛЬ СВЕРХУ СЛЕВА ============

func build_hud():
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)

	var panel = PanelContainer.new()
	var panel_style = make_style(PANEL_BG, 12, PANEL_BORDER)
	panel_style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)
	margin.add_child(panel)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	level_label = make_label("Ур. 1", 22, GOLD)
	box.add_child(level_label)

	hp_fill = make_style(HP_GOOD)
	hp_bar = make_bar(hp_fill, 28, 18)
	box.add_child(hp_bar)
	hp_text = hp_bar.get_node("Text")

	xp_bar = make_bar(make_style(XP_COLOR), 18, 13)
	box.add_child(xp_bar)
	xp_text = xp_bar.get_node("Text")


# ============ ОБНОВЛЕНИЕ (это вызывает игрок и статы) ============

func refresh():
	set_level(stats.level)
	set_xp(stats.xp, stats.xp_needed())


func set_hp(current: float, maximum: float):
	if hp_bar == null:
		return
	hp_bar.max_value = maximum
	if hp_tween:
		hp_tween.kill()
	hp_tween = create_tween()
	hp_tween.tween_property(hp_bar, "value", current, 0.2)
	hp_text.text = "%d / %d" % [ceili(current), ceili(maximum)]
	var ratio = current / maximum
	if ratio > 0.5:
		hp_fill.bg_color = HP_GOOD
	elif ratio > 0.25:
		hp_fill.bg_color = HP_MID
	else:
		hp_fill.bg_color = HP_LOW


func set_xp(current: float, needed: float):
	if xp_bar == null:
		return
	xp_bar.max_value = needed
	if xp_tween:
		xp_tween.kill()
	xp_tween = create_tween()
	xp_tween.tween_property(xp_bar, "value", current, 0.25)
	xp_text.text = "XP %d / %d" % [int(current), int(needed)]


func set_level(level):
	if level_label:
		level_label.text = "Ур. " + str(level)
