extends Node

const TRACK_PATH := "res://assets/audio/mars.mp3"  # cambia por el nombre real

var player := AudioStreamPlayer.new()


func _ready():
	add_child(player)
	player.volume_db = -10.0
	var stream = load(TRACK_PATH)
	if stream is AudioStreamMP3:
		stream.loop = true
	player.stream = stream
	player.play()
