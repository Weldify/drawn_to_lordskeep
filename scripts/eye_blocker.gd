extends Node3D

const ITERATIONS := 5
const STEP := 0.005
const BASE_RADIUS := 0.06

var smooth_insideness := 0.0

@onready var caster := $ShapeCast3D
@onready var blocker := $Blocker

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	
	
	const sub_per_step := 1.0 / float(ITERATIONS)
	var insideness := 1.0
	for i in ITERATIONS:
		caster.shape.radius = BASE_RADIUS + i * STEP
		caster.global_position = camera.global_position - camera.basis.z * caster.shape.radius
		caster.force_shapecast_update()
		if caster.is_colliding():
			break
		
		insideness -= sub_per_step
	
	var old := smooth_insideness
	smooth_insideness = lerpf(smooth_insideness, insideness, delta * 5)
	if insideness == 1: smooth_insideness = 1
	
	if old != smooth_insideness and smooth_insideness == 1:
		$AudioStreamPlayer.play()
	
	blocker.modulate.a = smooth_insideness
