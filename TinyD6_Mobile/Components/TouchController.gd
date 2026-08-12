extends Node
class_name TouchController

## Edge-tapping and horizontal swipe touch controller for mobile portrait reading

signal swipe_left
signal swipe_right
signal tap_left_edge
signal tap_right_edge

@export var swipe_threshold: float = 60.0
@export var edge_margin: float = 80.0

var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_active: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_active = true
			_touch_start_pos = event.position
		else:
			if _touch_active:
				_touch_active = false
				var delta: Vector2 = event.position - _touch_start_pos
				if abs(delta.x) > swipe_threshold and abs(delta.x) > abs(delta.y) * 1.5:
					if delta.x < 0:
						swipe_left.emit()
					else:
						swipe_right.emit()
				elif delta.length() < 15.0:
					var screen_width: float = get_viewport().get_visible_rect().size.x
					if event.position.x < edge_margin:
						tap_left_edge.emit()
					elif event.position.x > screen_width - edge_margin:
						tap_right_edge.emit()
