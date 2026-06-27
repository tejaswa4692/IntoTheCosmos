extends Node

var sources: Array[GravitySource] = []

func register(source: GravitySource) -> void:
	sources.append(source)

func unregister(source: GravitySource) -> void:
	sources.erase(source)
