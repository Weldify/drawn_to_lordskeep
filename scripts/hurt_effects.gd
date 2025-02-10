extends Node

@export var hurt_radial: GPUParticles3D
@export var world_env: WorldEnvironment

func _process(delta: float) -> void:
	if !is_instance_valid(G.viewer_mercenary):
		hurt_radial.emitting = false
		world_env.environment.adjustment_saturation = 1
		return
	
	hurt_radial.emitting = true
	hurt_radial.amount_ratio = 1 - G.viewer_mercenary.health
	world_env.environment.adjustment_saturation = G.viewer_mercenary.health
