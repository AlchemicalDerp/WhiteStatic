extends Node
## Procedural audio for the radio: a continuous static bed, synthesized Morse
## tones for incoming traffic, and a live sidetone while the player keys. Also
## the entry point for diegetic and hallucinated one-shots.
##
## Everything is generated with AudioStreamGenerator so the scaffold needs no
## sound assets. All buffer work is guarded so it is safe under the headless
## "Dummy" audio driver (CI, servers).

const MIX_RATE: float = 22050.0
const BUFFER_LENGTH: float = 0.1

## Carrier frequency of the Morse tone, Hz. A typical receiver sidetone.
@export var tone_hz: float = 650.0
@export var sidetone_hz: float = 600.0

var static_level: float = 0.0    ## 0 (silent) .. 1; raised when receiving

var _static_player: AudioStreamPlayer
var _tone_player: AudioStreamPlayer
var _side_player: AudioStreamPlayer

var _static_pb: AudioStreamGeneratorPlayback
var _tone_pb: AudioStreamGeneratorPlayback
var _side_pb: AudioStreamGeneratorPlayback

var _tone_samples: PackedFloat32Array = PackedFloat32Array()
var _tone_pos: int = 0
var _tone_fidelity: float = 1.0

var _side_on: bool = false
var _phase: float = 0.0
var _side_phase: float = 0.0


func _ready() -> void:
	_static_player = _make_player()
	_tone_player = _make_player()
	_side_player = _make_player()
	_static_pb = _static_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_tone_pb = _tone_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_side_pb = _side_player.get_stream_playback() as AudioStreamGeneratorPlayback
	# Auto-play any incoming traffic announced on the bus.
	EventBus.morse_incoming.connect(_on_morse_incoming)


func _process(_delta: float) -> void:
	_fill_static()
	_fill_tone()
	_fill_side()


# --- Public API ----------------------------------------------------------

func set_static_level(v: float) -> void:
	static_level = clampf(v, 0.0, 1.0)


## Play a Morse timeline (from MorseSystem.build_timeline). `fidelity` < 1
## roughens the tone so a poorly-sent/poorly-received message sounds degraded.
func play_morse_timeline(timeline: Array, fidelity: float = 1.0) -> void:
	_tone_fidelity = clampf(fidelity, 0.0, 1.0)
	_tone_samples = _render_timeline(timeline)
	_tone_pos = 0


func play_text(text: String, wpm: float = MorseSystem.DEFAULT_WPM, fidelity: float = 1.0) -> void:
	play_morse_timeline(MorseSystem.build_timeline(text, wpm), fidelity)


func stop_morse() -> void:
	_tone_samples = PackedFloat32Array()
	_tone_pos = 0


func start_sidetone() -> void:
	_side_on = true


func stop_sidetone() -> void:
	_side_on = false


## Hook for diegetic/hallucinated one-shots (boots in snow, a name in the
## static, an aircraft engine). See SymptomSystem hallucination requests.
func play_oneshot(id: String) -> void:
	# TODO: map ids to rendered/asset streams once audio content exists.
	pass


# --- Generation ----------------------------------------------------------

func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = BUFFER_LENGTH
	p.stream = gen
	add_child(p)
	p.play()
	return p


func _fill_static() -> void:
	if _static_pb == null or static_level <= 0.0:
		return
	var frames := _static_pb.get_frames_available()
	for i in frames:
		var n := randf_range(-1.0, 1.0) * static_level
		_static_pb.push_frame(Vector2(n, n))


func _fill_tone() -> void:
	if _tone_pb == null:
		return
	var frames := _tone_pb.get_frames_available()
	var step := TAU * tone_hz / MIX_RATE
	for i in frames:
		var s := 0.0
		if _tone_pos < _tone_samples.size():
			var env := _tone_samples[_tone_pos]
			if env > 0.0:
				# Low fidelity adds amplitude noise / a slight tremor.
				var rough := 1.0 - (1.0 - _tone_fidelity) * randf_range(0.0, 0.6)
				s = sin(_phase) * 0.35 * env * rough
				_phase += step
			_tone_pos += 1
		_tone_pb.push_frame(Vector2(s, s))


func _fill_side() -> void:
	if _side_pb == null:
		return
	var frames := _side_pb.get_frames_available()
	var step := TAU * sidetone_hz / MIX_RATE
	for i in frames:
		var s := 0.0
		if _side_on:
			s = sin(_side_phase) * 0.3
			_side_phase += step
		_side_pb.push_frame(Vector2(s, s))


## Render a timeline to a mono envelope buffer (1.0 during tones, 0.0 in gaps)
## with short ramps so tones do not click.
func _render_timeline(timeline: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var ramp := int(0.004 * MIX_RATE)  # 4 ms attack/release
	for seg in timeline:
		var count := int(seg["ms"] / 1000.0 * MIX_RATE)
		if seg["on"]:
			for i in count:
				var env := 1.0
				if i < ramp:
					env = float(i) / float(ramp)
				elif i > count - ramp:
					env = float(count - i) / float(ramp)
				out.append(clampf(env, 0.0, 1.0))
		else:
			for i in count:
				out.append(0.0)
	return out


func _on_morse_incoming(message: Dictionary) -> void:
	var text: String = message.get("text", "")
	var wpm: float = message.get("wpm", MorseSystem.DEFAULT_WPM)
	var fidelity: float = message.get("fidelity", 1.0)
	if text != "":
		set_static_level(maxf(static_level, 0.35))
		play_text(text, wpm, fidelity)
