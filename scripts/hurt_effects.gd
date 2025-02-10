extends Node

@export var hurt_radial: GPUParticles3D
@export var world_env: WorldEnvironment

func _process(_delta: float) -> void:
	if !is_instance_valid(G.viewer_mercenary):
		hurt_radial.emitting = false
		world_env.environment.adjustment_saturation = 1
		return
	
	var health := clampf(G.viewer_mercenary.health, 0, 1)
	
	hurt_radial.emitting = true
	hurt_radial.amount_ratio = 1 - health
	world_env.environment.adjustment_saturation = health
