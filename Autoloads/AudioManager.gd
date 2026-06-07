extends Node

const DEFAULT_MUSIC_FADE: float = 0.75
const DEFAULT_STOP_FADE: float = 0.45
const MIN_VOLUME_DB: float = -80.0
const SFX_POOL_SIZE: int = 12

const MUSIC: Dictionary = {
	&"classroom_normal": "res://audios/MundoBonito.mp3",
	&"classroom_sad": "res://audios/MundoFeo.mp3",
	&"hallway": "res://audios/MundoFeo.mp3",
	&"bathroom": "res://audios/PeleaBa#U00f1os.mp3",
	&"cafeteria": "res://audios/MundoFeo.mp3",
	&"cafeteria_battle": "res://audios/PeleaCafeteria.mp3",
	&"final_boss_phase_1": "res://audios/Fase1Boss.mp3",
	&"final_boss_phase_2": "res://audios/Fase2Boss.mp3",
	&"final_boss_phase_3": "res://audios/Fase3Boss.mp3",
}

const SFX: Dictionary = {
	&"player_melee": "res://audios/AtaqueMele.wav",
	&"player_water": "res://audios/AtaqueDistancia.wav",
	&"player_hurt": "res://audios/RecibirDa#U00f1o.wav",
	&"game_over": "res://audios/GameOver.wav",
	&"interact": "res://audios/Interactuar.wav",
	&"pickup": "res://audios/RecogerItem.wav",
	&"door": "res://audios/Puertas.wav",
	&"photo": "res://audios/Foto.wav",
	&"candy": "res://audios/Caramelo .wav",
	&"transition": "res://audios/Transicion.wav",
	&"pan": "res://audios/Pan.wav",
	&"entropy_invert": "res://audios/ControlesInvertidos.wav",
	&"entropy_lag": "res://audios/InputLag.wav",
	&"camera_flip": "res://audios/CamaraVolteada.wav",
	&"robot_dash": "res://audios/DashRobot.wav",
	&"robot_shoot": "res://audios/BasicoCarcaj.wav",
	&"robot_jump": "res://audios/SaltoCarcaj.wav",
	&"robot_fall": "res://audios/Caida.wav",
	&"robot_stomp": "res://audios/Pisoton del suelo.wav",
	&"robot_explosion": "res://audios/CarcajExplotando .wav",
	&"minion_damage": "res://audios/Da#U00f1arMinions.wav",
	&"boss_laser": "res://audios/Laser3Boss.wav",
	&"boss_missile": "res://audios/MisilFinalBoss.wav",
	&"boss_focus": "res://audios/FocoFase2Boss.wav",
	&"spawn_minions": "res://audios/SpawnEsbirros.wav",
	&"final_explosion": "res://audios/ExplosionRobotFase3.wav",
	&"bathroom_warning": "res://audios/WarningBa#U00f1os.wav",
	&"bathroom_detect": "res://audios/Detectar a elio.wav",
	&"bathroom_cubicle": "res://audios/EntradaCubiculo.wav",
	&"bathroom_locker": "res://audios/Locker.wav",
	&"bathroom_laser_lock": "res://audios/Laser lockea en un ba#U00f1o.wav",
}

var current_music_key: StringName = &""
var current_music_path: String = ""

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0


func _ready() -> void:
	_ensure_audio_buses()
	_music_a = _create_music_player(&"MusicA")
	_music_b = _create_music_player(&"MusicB")
	_create_sfx_pool()


func play_music(key_or_path: Variant, fade_seconds: float = DEFAULT_MUSIC_FADE, target_volume_db: float = 0.0) -> void:
	var path: String = _resolve_audio_path(key_or_path, MUSIC)
	if path.is_empty():
		push_warning("AudioManager: no se encontro musica para: %s" % str(key_or_path))
		return

	if current_music_path == path and _active_music_player != null and _active_music_player.playing:
		return

	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("AudioManager: no se pudo cargar musica: %s" % path)
		return

	_set_stream_loop(stream, true)

	var previous_player: AudioStreamPlayer = _active_music_player
	var next_player: AudioStreamPlayer = _music_b if _active_music_player == _music_a else _music_a

	next_player.stop()
	next_player.stream = stream
	next_player.bus = _get_bus_or_master("Music")
	next_player.volume_db = MIN_VOLUME_DB if fade_seconds > 0.0 else target_volume_db
	next_player.play()

	_active_music_player = next_player
	current_music_path = path
	current_music_key = StringName(str(key_or_path))

	_fade_music_players(previous_player, next_player, fade_seconds, target_volume_db)


func stop_music(fade_seconds: float = DEFAULT_STOP_FADE) -> void:
	if _active_music_player == null:
		return

	var player_to_stop: AudioStreamPlayer = _active_music_player
	_active_music_player = null
	current_music_key = &""
	current_music_path = ""

	if fade_seconds <= 0.0:
		player_to_stop.stop()
		player_to_stop.stream = null
		return

	var tween: Tween = create_tween()
	tween.tween_property(player_to_stop, "volume_db", MIN_VOLUME_DB, fade_seconds)
	tween.finished.connect(func() -> void:
		if is_instance_valid(player_to_stop):
			player_to_stop.stop()
			player_to_stop.stream = null
	)


func play_sfx(key_or_path: Variant, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var path: String = _resolve_audio_path(key_or_path, SFX)
	if path.is_empty():
		push_warning("AudioManager: no se encontro SFX para: %s" % str(key_or_path))
		return

	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("AudioManager: no se pudo cargar SFX: %s" % path)
		return

	_set_stream_loop(stream, false)

	var player: AudioStreamPlayer = _get_available_sfx_player()
	player.stop()
	player.stream = stream
	player.bus = _get_bus_or_master("SFX")
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func set_music_volume_linear(value: float) -> void:
	_set_bus_volume_linear("Music", value)


func set_sfx_volume_linear(value: float) -> void:
	_set_bus_volume_linear("SFX", value)


func set_voice_volume_linear(value: float) -> void:
	_set_bus_volume_linear("Voice", value)


func get_music_path(key: StringName) -> String:
	return String(MUSIC.get(key, ""))


func get_sfx_path(key: StringName) -> String:
	return String(SFX.get(key, ""))


func _create_music_player(node_name: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = String(node_name)
	player.bus = _get_bus_or_master("Music")
	add_child(player)
	return player


func _create_sfx_pool() -> void:
	for index: int in range(SFX_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SFX_%02d" % index
		player.bus = _get_bus_or_master("SFX")
		add_child(player)
		_sfx_players.append(player)


func _get_available_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			return player

	var fallback: AudioStreamPlayer = _sfx_players[_sfx_cursor % _sfx_players.size()]
	_sfx_cursor += 1
	return fallback


func _fade_music_players(previous_player: AudioStreamPlayer, next_player: AudioStreamPlayer, fade_seconds: float, target_volume_db: float) -> void:
	if fade_seconds <= 0.0:
		if previous_player != null:
			previous_player.stop()
			previous_player.stream = null
		next_player.volume_db = target_volume_db
		return

	var tween: Tween = create_tween()
	if previous_player != null:
		tween.parallel().tween_property(previous_player, "volume_db", MIN_VOLUME_DB, fade_seconds)
	tween.parallel().tween_property(next_player, "volume_db", target_volume_db, fade_seconds)
	tween.finished.connect(func() -> void:
		if previous_player != null and is_instance_valid(previous_player) and previous_player != _active_music_player:
			previous_player.stop()
			previous_player.stream = null
	)


func _resolve_audio_path(key_or_path: Variant, catalog: Dictionary) -> String:
	if key_or_path == null:
		return ""

	var text: String = str(key_or_path)
	var key: StringName = StringName(text)

	if catalog.has(key):
		return String(catalog[key])
	if catalog.has(text):
		return String(catalog[text])
	if text.begins_with("res://"):
		return text
	return ""


func _set_stream_loop(stream: AudioStream, should_loop: bool) -> void:
	if stream == null:
		return

	for property: Dictionary in stream.get_property_list():
		if String(property.get("name", "")) == "loop":
			stream.set("loop", should_loop)
			return


func _ensure_audio_buses() -> void:
	for bus_name: String in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus(AudioServer.get_bus_count())
		var bus_index: int = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_send(bus_index, "Master")


func _get_bus_or_master(bus_name: String) -> StringName:
	return StringName(bus_name if AudioServer.get_bus_index(bus_name) != -1 else "Master")


func _set_bus_volume_linear(bus_name: String, value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return

	var clamped_value: float = clampf(value, 0.0, 1.0)
	var volume_db: float = MIN_VOLUME_DB if clamped_value <= 0.0 else linear_to_db(clamped_value)
	AudioServer.set_bus_volume_db(bus_index, volume_db)
