extends Node

# Audio Manager con Sintesi ASMR e Musica in Loop
@export var music_path: String = "res://assets/Beneath_the_Bedrock.mp3"

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_ensure_bus_exists("Music")
	_ensure_bus_exists("SFX")
	
	# Setup Music Player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.finished.connect(func(): music_player.play())
	add_child(music_player)
	
	# Setup SFX Pool
	for i in range(12): 
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)
	
	call_deferred("_start_bgm")

func _ensure_bus_exists(bus_name: String):
	if AudioServer.get_bus_index(bus_name) == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)

func _start_bgm():
	if ResourceLoader.exists(music_path):
		var stream = load(music_path)
		if stream:
			music_player.stream = stream
			music_player.play()
	else:
		push_warning("Musica non caricata o non trovata in: " + music_path)

# --- EFFETTI SONORI ASMR (SINTETIZZATI) ---

func play_dig_sound():
	_play_synth_asmr(80, 0.08, 0.6, "sin")

func play_break_sound():
	_play_synth_asmr(200, 0.15, 0.4, "noise")

func play_explosion_sound():
	_play_synth_asmr(40, 0.6, 0.8, "rumble")

func play_button_click():
	_play_synth_asmr(1200, 0.05, 0.2, "sin")

func play_upgrade_sound():
	# SUONO DI SUCCESSO (SCALA ASCENDENTE)
	_play_synth_asmr(440, 0.1, 0.4, "sin")
	await get_tree().create_timer(0.08).timeout
	_play_synth_asmr(880, 0.1, 0.4, "sin")

func _play_synth_asmr(freq: float, duration: float, volume: float, type: String):
	var player = _get_free_sfx_player()
	if not player: return
	
	var sample_rate = 44100
	var byte_data = PackedByteArray()
	var num_samples = int(sample_rate * duration)
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var envelope = 1.0 - (float(i) / num_samples)
		var sample = 0.0
		match type:
			"sin":
				sample = sin(2.0 * PI * freq * t) * envelope
			"noise":
				sample = (randf() * 2.0 - 1.0) * envelope * 0.5
			"rumble":
				sample = (randf() * 2.0 - 1.0) * envelope
		
		var val = int(sample * volume * 32767)
		byte_data.append(val & 0xFF)
		byte_data.append((val >> 8) & 0xFF)
	
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	player.stream = stream
	player.play()

func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in sfx_players:
		if not p.playing: return p
	return sfx_players[0]
