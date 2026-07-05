extends Node
var sources: Array[GravitySource] = []

func register(source: GravitySource) -> void:
	sources.append(source)

func unregister(source: GravitySource) -> void:
	sources.erase(source)

func get_active_sources(from_position: Vector3) -> Array[GravitySource]:
	var in_soi: Array[GravitySource] = []
	for source in sources:
		if source.soi_radius > 0.0:
			var d: float = (source.global_position - from_position).length()
			if d <= source.soi_radius:
				in_soi.append(source)
	return in_soi
