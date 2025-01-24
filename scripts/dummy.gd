extends Node


func _ready() -> void:
	$skeleton/Skeleton3D/RightIK.start()
	$skeleton/Skeleton3D/LeftIK.start()


func handle_hit_effect(weapon: RigidBody3D, normal: Vector3):
	weapon.get_node("DamageBlunt").play()
	
	$skeleton/Skeleton3D/DMWBWigglePositionModifier3D.add_force_impulse(normal * 5)
	$skeleton/Skeleton3D/DMWBWiggleRotationModifier3D.add_force_impulse(normal * 0.01)
