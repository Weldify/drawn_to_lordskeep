extends Node3D
class_name District

## This should always be there for any district that isnt the starting district.
@export var district_border: StaticBody3D

var border_base_position: Vector3

@export var border_closed: bool :
	set(v):
		border_closed = v
		
		if district_border:
			district_border.position = border_base_position if border_closed else Vector3(0, -100, 0)


func _ready() -> void:
	$NetSynchronizer.configure()
	
	if !multiplayer.is_server(): return
	
	if district_border:
		border_base_position = district_border.position
	
	border_closed = true
	
	if scene_file_path == "res://scenes/tenurial_district.tscn":
		var enemy := preload("res://scenes/tall_axe_guy.tscn").instantiate()
		$/root/world/Enemies.add_child(enemy, true)
		enemy.global_position = $EnemySpawnpoint.global_position
		print("Hello sire?")


func generate_next_district():
	var last_district: District = get_parent().get_child(-1)
	
	var new_district: District = load("res://scenes/tenurial_district.tscn").instantiate()
	new_district.global_transform = last_district.get_node("Exit").global_transform
	get_parent().add_child(new_district, true)


func advance():
	assert(multiplayer.is_server())
	
	var index_in_parent := get_index()
	assert(index_in_parent == get_parent().get_child_count() - 2)
	
	var last_district: District = get_parent().get_child(-1)
	last_district.border_closed = false
	
	generate_next_district()
	
	assert(get_parent().get_child_count() <= 4)
	if get_parent().get_child_count() == 4:
		border_closed = true
		print("Clos")
		
		var first_district: District = get_parent().get_child(0)
		
		# @TODO: Do something with the items in this district.
		# Maybe they will stop sleeping and fall down, so we can catch and delete them.
		first_district.free()
