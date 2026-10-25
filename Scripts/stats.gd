extends Node
# Пока только уровень и опыт. Статы (сила, ловкость и т.д.) убраны до ребаланса.

signal changed              # изменился опыт или уровень
signal leveled_up(new_level)

const XP_BASE = 25.0        # опыта до 2 уровня
const XP_GROWTH = 50.0      # на сколько больше нужно с каждым уровнем

var level = 0
var xp = 0.0


func xp_needed() -> float:
	return XP_BASE + (level - 1) * XP_GROWTH


func add_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		leveled_up.emit(level)
	changed.emit()
