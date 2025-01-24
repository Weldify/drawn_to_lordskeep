extends Node


func _ready() -> void:
	$skeleton/Skeleton3D/RightIK.start()
	$skeleton/Skeleton3D/LeftIK.start()


func handle_hit() -> G.HitHandleResult:
	var result := G.HitHandleResult.new()
	result.extra_colliders_to_ignore.append_array($skeleton/Skeleton3D/PhysicalBoneSimulator3D.get_children())
	return result


func handle_hit_effect(weapon, position: Vector3, normal: Vector3):
	if weapon.blunt:
		var damage_blunt := preload("res://damage_blunt.tscn").instantiate()
		$"/root".add_child(damage_blunt, true)
		
		damage_blunt.look_at_from_position(position, position + normal)
		damage_blunt.restart()
		damage_blunt.finished.connect(damage_blunt.queue_free)
	else:
		var damage_sharp := preload("res://damage_sharp.tscn").instantiate()
		$"/root".add_child(damage_sharp, true)
		
		damage_sharp.look_at_from_position(position, position + normal)
		damage_sharp.restart()
		damage_sharp.finished.connect(damage_sharp.queue_free)
	
	$skeleton/Skeleton3D/DMWBWigglePositionModifier3D.add_force_impulse(normal * 5)
	$skeleton/Skeleton3D/DMWBWiggleRotationModifier3D.add_force_impulse(normal * 0.01)
