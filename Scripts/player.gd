extends CharacterBody2D
# Свободное движение во все стороны (8 направлений), без клеток.
# Стены (горы) и мобы проверяются вручную: перед шагом смотрим, свободно ли там.

const CELL = 32  # размер клетки мира в пикселях (нужен для карты и удара)
@export var speed: float = 200.0      # пикселей в секунду
@export var body_size: float = 24.0   # размер тела игрока (квадрат), меньше клетки, чтобы пролезать в проходы
@export var damage: float = 1.0       # урон без меча
@export var max_hp: float = 10.0
@export var attack_reach: float = 32.0  # как далеко перед собой бьём (в пикселях)
@export var attack_size: float = 32.0   # размер розового квадрата удара
@export var vision_fog: float = 9.0   # радиус круга, за которым серый туман (в клетках)
@export var vision_grid: float = 6.0  # до скольки клеток видна сетка

var hp: float
var dead := false
var facing := Vector2.DOWN  # куда смотрит персонаж (теперь может быть и по диагонали)
var attacking := false

@onready var sword: Node2D = get_node_or_null("Sword")
@onready var hitbox: Area2D = $SwordHitbox
@onready var flash: ColorRect = $SwordHitbox/Flash
@onready var stats = $Stats
@onready var world = get_parent()


func _ready():
	add_to_group("player")
	hp = max_hp
	stats.leveled_up.connect(_on_leveled_up)
	update_hitbox()
	update_sword()
	call_deferred("update_hp_ui")   # ждём, пока интерфейс загрузится


# Радиусы видимости. Скрипт тумана и сетки берёт значения отсюда.
func fog_radius() -> float:
	return vision_fog

func grid_radius() -> float:
	return vision_grid


func _on_leveled_up(_new_level):
	hp = max_hp   # новый уровень лечит полностью; не хочешь так, удали эти две строки
	update_hp_ui()


func update_sword():
	if sword:
		sword.rotation = facing.angle() + PI / 2


# зона удара стоит перед игроком и повёрнута туда, куда он смотрит
func update_hitbox():
	hitbox.position = facing * attack_reach
	hitbox.rotation = facing.angle()
	# розовый квадрат всегда того же размера, что и зона удара
	flash.size = Vector2(attack_size, attack_size)
	flash.position = -flash.size / 2.0


# ---------- ПРОВЕРКИ "МОЖНО ЛИ ТУДА" ----------

# занята ли эта точка игроком. Это зовут мобы, чтобы не залезть в нас.
func occupies(pos: Vector2) -> bool:
	return position.distance_to(pos) < CELL * 0.8


# можно ли телу игрока стоять в точке pos: не в горе и не в мобе
func spot_is_free(pos: Vector2) -> bool:
	if not world.body_fits(pos, body_size):
		return false
	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob.position.distance_to(pos) < CELL * 0.8:
			# если уже стоим вплотную, разрешаем отходить (иначе застрянем)
			if mob.position.distance_to(pos) < mob.position.distance_to(position):
				return false
	return true


# ---------- ЗДОРОВЬЕ ----------

func update_hp_ui():
	var ui = get_tree().get_first_node_in_group("ui")
	if ui:
		ui.set_hp(hp, max_hp)


func take_damage(amount: float):
	if dead:
		return
	hp -= amount
	print("игрок получил ", amount, ", осталось ", hp)
	update_hp_ui()
	if hp <= 0:
		die()
		return
	# покраснеть при ударе
	var hit_flash = create_tween()
	hit_flash.tween_property(self, "modulate", Color(1, 0.4, 0.4), 0.05)
	hit_flash.tween_property(self, "modulate", Color(1, 1, 1), 0.1)


func die():
	dead = true
	var screen = get_tree().get_first_node_in_group("death_screen")
	if screen:
		screen.show_death()


# ---------- ДВИЖЕНИЕ И УДАР ----------

func _physics_process(delta):
	if dead:
		return

	# get_vector сам собирает 4 кнопки в одно направление и делает диагональ
	# такой же скорости, как прямое движение (иначе по диагонали бегали бы быстрее)
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if dir != Vector2.ZERO:
		facing = dir.normalized()
		update_hitbox()
		if not attacking:
			update_sword()
		var move = dir * speed * delta
		# двигаемся по X и по Y отдельно: так у стены не застреваем,
		# а скользим вдоль неё
		var try_x = position + Vector2(move.x, 0)
		if spot_is_free(try_x):
			position = try_x
		var try_y = position + Vector2(0, move.y)
		if spot_is_free(try_y):
			position = try_y

	if Input.is_action_just_pressed("attack") and not attacking:
		attack()


func attack():
	attacking = true
	# урон берём из меча, а если меча нет, то из самого игрока
	var dmg = damage
	if sword:
		dmg = sword.damage
		var base = facing.angle() + PI / 2
		sword.rotation = base - 1.0  # замах
		var swing = create_tween()
		swing.tween_property(sword, "rotation", base + 1.0, 0.15)
	# бьём всех мобов, чей квадрат хоть краем задевает розовый квадрат удара
	for mob in get_tree().get_nodes_in_group("mobs"):
		if hits(mob):
			mob.take_damage(dmg)
	flash.visible = true
	await get_tree().create_timer(0.2).timeout
	flash.visible = false
	attacking = false
	update_sword()


# задевает ли розовый квадрат удара квадрат моба.
# Квадрат удара повёрнут туда, куда смотрим, поэтому «поворачиваем» моба обратно
# и сравниваем как два ровных квадрата: пересекаются, если по X и по Y
# центры ближе, чем половина одного + половина другого.
func hits(mob) -> bool:
	var center = position + facing * attack_reach
	var local = (mob.position - center).rotated(-facing.angle())
	var reach = attack_size / 2.0 + mob.body_size / 2.0
	return absf(local.x) < reach and absf(local.y) < reach
