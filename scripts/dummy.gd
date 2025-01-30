extends Node


func _ready() -> void:
	$skeleton/Skeleton3D/RightIK.start()
	$skeleton/Skeleton3D/LeftIK.start()


func handle_hit() -> G.HitHandleResult:
	var result := G.HitHandleResult.new()
	result.extra_colliders_to_ignore.append_array($skeleton/Skeleton3D/PhysicalBoneSimulator3D.get_children())
	return result


func handle_hit_effect(weapon, position: Vector3, normal: Vector3):
	G.flesh_hit_effects(weapon, position, normal)
	
	$skeleton/Skeleton3D/DMWBWigglePositionModifier3D.add_force_impulse(normal * 5)
	$skeleton/Skeleton3D/DMWBWiggleRotationModifier3D.add_force_impulse(normal * 0.01)
