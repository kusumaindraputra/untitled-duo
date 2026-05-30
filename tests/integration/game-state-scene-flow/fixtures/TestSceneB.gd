## Lifecycle-instrumented fixture for scene_manager_test.gd.
## Records _ready() and _exit_tree() events to TestEventLog for TR-GSF-003 ordering verification.
extends Node2D

func _ready() -> void:
	TestEventLog.events.append("TestSceneB:ready")

func _exit_tree() -> void:
	TestEventLog.events.append("TestSceneB:exit_tree")
