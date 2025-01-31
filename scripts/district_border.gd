extends StaticBody3D
class_name DistrictBorder

@export var func_godot_properties: Dictionary
@export var is_breached: bool:
	set(v):
		is_breached = v
		mesh.visible = !is_breached
		collider.disabled = is_breached


var mesh: MeshInstance3D
var collider: CollisionShape3D


func _ready() -> void:
	for child in get_children():
		if child is MeshInstance3D: mesh = child
		elif child is CollisionShape3D: collider = child
		
	assert(mesh and collider, "DistrictBorder is missing mesh or collider!")
	
	# @TODO: Reuse this resource across all district borders.
	var replication_config := SceneReplicationConfig.new()
	replication_config.add_property(":is_breached")
	replication_config.property_set_replication_mode(":is_breached", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	
	var syncer := MultiplayerSynchronizer.new()
	syncer.replication_config = replication_config
	add_child(syncer)
	
	add_to_group("district_border")
