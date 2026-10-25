extends Node2D

const W = 1000  # ширина мира в клетках
const H = 1000  # высота мира в клетках
const CELL = 32
const RADIUS = 40  # сколько клеток вокруг игрока рисуем

const GRASS = Vector2i(0, 0)     # светлая трава
const BUSH = Vector2i(1, 0)      # тёмный куст
const MOUNTAIN = Vector2i(2, 0)  # гора (стена)
const SPAWN = Vector2i(500, 500) # где появляется игрок

# шейдер тумана: внутри круга всё как есть, дальше плавно становится тёмно-серым
const FOG_SHADER = """
shader_type canvas_item;
uniform vec2 center_uv = vec2(0.5, 0.5);
uniform float clear_radius = 150.0;
uniform float fade_width = 100.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
void fragment() {
    vec2 offset = (SCREEN_UV - center_uv) / SCREEN_PIXEL_SIZE;
    float d = length(offset);
    float t = smoothstep(clear_radius, clear_radius + fade_width, d);
    vec3 scene = texture(screen_tex, SCREEN_UV).rgb;
    float gray = dot(scene, vec3(0.299, 0.587, 0.114));
    COLOR = vec4(mix(scene, vec3(gray * 0.4), t), 1.0);
}
"""

@onready var ground: TileMapLayer = $Ground
@onready var player = $Player
@onready var mob = $Mob

var mountains := FastNoiseLite.new()
var bushes := FastNoiseLite.new()
var last_center := Vector2i(-99999, -99999)
var grid: Node2D
var fog_material: ShaderMaterial

func _ready():
	mountains.seed = 12345
	mountains.frequency = 0.03  # меньше число = горы крупнее
	bushes.seed = 777
	bushes.frequency = 0.08
	player.position = Vector2(SPAWN * CELL) + Vector2(CELL / 2.0, CELL / 2.0)
	mob.position = player.position + Vector2(3 * CELL, 0)

	# сетка поверх карты (под игроком)
	grid = Node2D.new()
	add_child(grid)
	move_child(grid, 1)
	grid.draw.connect(_draw_grid)

	# туман поверх всего
	var layer = CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var fog_rect = ColorRect.new()
	fog_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = FOG_SHADER
	fog_material = ShaderMaterial.new()
	fog_material.shader = shader
	fog_rect.material = fog_material
	layer.add_child(fog_rect)

func tile_at(cell: Vector2i) -> Vector2i:
	# край мира: сплошные горы
	if cell.x <= 0 or cell.y <= 0 or cell.x >= W - 1 or cell.y >= H - 1:
		return MOUNTAIN
	# рядом со стартом всегда чисто
	if Vector2(cell).distance_to(Vector2(SPAWN)) < 6:
		return GRASS
	if mountains.get_noise_2d(cell.x, cell.y) > 0.3:  # больше число = меньше гор
		return MOUNTAIN
	if bushes.get_noise_2d(cell.x, cell.y) > 0.35:  # больше число = меньше кустов
		return BUSH
	return GRASS

func is_walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= W or cell.y >= H:
		return false
	return tile_at(cell) != MOUNTAIN  # по кустам ходить можно, по горам нет

func _process(_delta):
	# подгрузка карты вокруг игрока
	var c = ground.local_to_map(player.position)
	if maxi(absi(c.x - last_center.x), absi(c.y - last_center.y)) >= 8:
		last_center = c
		redraw(c)

	# сетка
	grid.queue_redraw()

	# туман
	var fog_px = player.fog_radius() * CELL
	fog_material.set_shader_parameter("clear_radius", fog_px * 0.6)
	fog_material.set_shader_parameter("fade_width", fog_px * 0.4)
	var screen_pos = player.get_global_transform_with_canvas().origin
	fog_material.set_shader_parameter("center_uv", screen_pos / get_viewport().get_visible_rect().size)

func redraw(center: Vector2i):
	ground.clear()
	for x in range(maxi(center.x - RADIUS, 0), mini(center.x + RADIUS, W - 1) + 1):
		for y in range(maxi(center.y - RADIUS, 0), mini(center.y + RADIUS, H - 1) + 1):
			var cell = Vector2i(x, y)
			ground.set_cell(cell, 0, tile_at(cell))

func _grid_alpha(point: Vector2, radius_px: float) -> float:
	var d = point.distance_to(player.position)
	# в центре видно хорошо, к краю плавно стирается
	return 0.4 * (1.0 - smoothstep(radius_px * 0.4, radius_px, d))

func _draw_grid():
	var radius_px = player.grid_radius() * CELL
	var c = ground.local_to_map(player.position)
	var n = int(ceil(player.grid_radius())) + 1
	for cx in range(c.x - n, c.x + n + 2):
		for cy in range(c.y - n, c.y + n + 2):
			var p = Vector2(cx * CELL, cy * CELL)
			var a1 = _grid_alpha(p + Vector2(0, CELL / 2.0), radius_px)
			if a1 > 0.01:
				grid.draw_line(p, p + Vector2(0, CELL), Color(1, 1, 1, a1))
			var a2 = _grid_alpha(p + Vector2(CELL / 2.0, 0), radius_px)
			if a2 > 0.01:
				grid.draw_line(p, p + Vector2(CELL, 0), Color(1, 1, 1, a2))
