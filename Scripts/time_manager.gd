# TimeManager.gd
extends Node

# Time variables
var current_time : float = 840.0 # 14 * 60 = 840 minutes (starts the game at 14:00) 
var day_length_minutes : float = 1440.0 # 24 hours


@export var time_speed : float = 2.0 # 1 hour per 30 seconds of real time

# Calendar variables
var day : int = 1
var month : int = 0
var year : int = 300
var era_name : String = "Era of Veilfire"

const MONTHS = [
	"Luminar", "Verdalis", "Pyrosol", "Zepheral", "Aquenox",
	"Obscurion", "Solsticea", "Thornmere", "Glacivorne", "Starvane"
]

const WEEKDAYS = [
	"Mornis", "Ferros", "Eldra", "Solyn", "Umbra", "Nexar"
]

const DAYS_PER_MONTH = 36
const MONTHS_PER_YEAR = 10
const DAYS_PER_WEEK = 6

signal time_updated(current_time)

func _process(delta: float) -> void:
	current_time += delta * time_speed
	if current_time >= day_length_minutes:
		current_time = 0.0
		advance_day()
	emit_signal("time_updated", current_time)

func advance_day():
	day += 1
	if day > DAYS_PER_MONTH:
		day = 1
		month += 1
		if month >= MONTHS_PER_YEAR:
			month = 0
			year += 1

func get_hour() -> int:
	return int(current_time / 60.0)

func get_minute() -> int:
	return int(current_time) % 60

func get_time_string() -> String:
	return "In-Game Time: %02d:%02d" % [get_hour(), get_minute()]

func get_date_string() -> String:
	var weekday_index = ((year * MONTHS_PER_YEAR * DAYS_PER_MONTH) + (month * DAYS_PER_MONTH) + day - 1) % DAYS_PER_WEEK
	return "In Game Date: %s, %s %d, Year %d — %s" % [
		WEEKDAYS[weekday_index],
		MONTHS[month],
		day,
		year,
		era_name
	]
