class_name GameAudio
extends Node
## Cycle 16: the audio layer. The original's engine is a single
## procedural WebAudio class (bundle main @74465-93932): master ->
## compressor -> destination; sfxBus / musicBus / cryBus (filtered)
## / kitBus (filtered, -> sfxBus); volume defaults {master .8,
## music .5, sfx .7, cries .6} (@75068) applied as master = vol,
## sfx = vol.sfx x .55, music = vol.music x .32, cries = vol.cries
## x .45 (@78627). Almost every sound is SYNTHESIZED from tone /
## noise primitives; only species cries and music tracks are files
## there — and neither file set ships here (recorded cries and
## composed tracks are the original's IP). Our sounds are rendered
## from the same recipes into WAV buffers, lazily on first use;
## cries are synthesized per species; BGM loops are synthesized
## from the bundle's own (never-called) sequencer design
## (playSong @90925: moods + degree progressions + the 16th-note
## schedule() @92745) standing in for the file tracks (Ec @73814).
##
## Harness surface: play_counts (per sound name, incremented on
## every accepted play), duck_count, current_track. Counting is
## call-level — the checks never depend on a real audio device.

static var instance: GameAudio = null

const SR := 22050          # SFX / cry render rate
const MSR := 11025         # music render rate
const MAX_VOICES := 26     # bundle: coarse-pointer voice cap
const BUS_NAMES := ["Music", "SFX", "Cries", "Kit"]

var vol := {"master": 0.8, "music": 0.5, "sfx": 0.7, "cries": 0.6}
var play_counts := {}
var duck_count := 0
var current_track := ""

var _last_play := {}       # ok() throttle stamps (bundle @78837)
var _streams := {}         # name -> AudioStreamWAV (lazy render)
var _cry_streams := {}     # species id -> AudioStreamWAV
var _noise := PackedFloat32Array()   # the 1 s white-noise buffer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _cry_players: Array[AudioStreamPlayer] = []
var _cry_cursor := 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_fade := [0.0, 0.0]        # per player: 0 silent .. 1 full
var _music_fade_target := [0.0, 0.0]
var _music_active := 0
var _hidden_mute := false
var _master_eff := 0.8
var _duck_t := 0.0
var _duck_ratio := 1.0
var _duck_level := 1.0

const W_SINE := 0
const W_SQUARE := 1
const W_TRI := 2
const W_SAW := 3

func _ready() -> void:
	instance = self
	_ensure_buses()
	# The bundle's noise buffer: 1 s of white noise (build()
	# in the class @74465). Ours is seeded for reproducibility.
	_noise.resize(SR)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261016
	for i in range(SR):
		_noise[i] = rng.randf_range(-1.0, 1.0)
	for i in range(MAX_VOICES):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	for i in range(4):
		var p := AudioStreamPlayer.new()
		p.bus = "Cries"
		add_child(p)
		_cry_players.append(p)
	for i in range(2):
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		_music_players.append(p)
	_apply_volumes()
	_master_eff = vol["master"]

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ensure_buses() -> void:
	for bn in BUS_NAMES:
		if AudioServer.get_bus_index(bn) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bn)
			AudioServer.set_bus_send(idx, "SFX" if bn == "Kit" else "Master")
	# Master compressor (threshold -14, ratio 4, attack .003,
	# release .2 — build() in the class @74465).
	var mi := AudioServer.get_bus_index("Master")
	var has_comp := false
	for ei in range(AudioServer.get_bus_effect_count(mi)):
		if AudioServer.get_bus_effect(mi, ei) is AudioEffectCompressor:
			has_comp = true
	if not has_comp:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -14.0
		comp.ratio = 4.0
		comp.attack_us = 3000.0
		comp.release_ms = 200.0
		AudioServer.add_bus_effect(mi, comp)
	# Bus filters: cryBus lowpass 6000, kitBus lowpass 5200
	# (their highshelf stages are not reproduced — DIFF cycle 16).
	_add_lowpass("Cries", 6000.0)
	_add_lowpass("Kit", 5200.0)

func _add_lowpass(bus: String, hz: float) -> void:
	var bi := AudioServer.get_bus_index(bus)
	if bi < 0:
		return
	for ei in range(AudioServer.get_bus_effect_count(bi)):
		if AudioServer.get_bus_effect(bi, ei) is AudioEffectLowPassFilter:
			return
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = hz
	AudioServer.add_bus_effect(bi, lp)

## setVolumes (@78321): merge + re-apply.
func set_volumes(v: Dictionary) -> void:
	for k in v.keys():
		if vol.has(k):
			vol[k] = clampf(float(v[k]), 0.0, 1.0)
	_apply_volumes()

func _lin_db(x: float) -> float:
	return linear_to_db(maxf(x, 0.0001))

func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), _lin_db(float(vol["sfx"]) * 0.55))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Cries"), _lin_db(float(vol["cries"]) * 0.45))
	# Master and Music are (re)driven per frame in _process:
	# master rides the hidden-mute ramp, music rides duck().

## setHiddenMute (@78395): ramp master to 0 / back over .15 s
## (the ramp runs in _process).
func set_hidden_mute(on: bool) -> void:
	_hidden_mute = on

func _process(delta: float) -> void:
	# Hidden-mute ramp (.15 s in the bundle).
	var mtarget := 0.0 if _hidden_mute else float(vol["master"])
	var step := delta / 0.15 * maxf(float(vol["master"]), 0.01)
	_master_eff = move_toward(_master_eff, mtarget, step)
	AudioServer.set_bus_volume_db(0, _lin_db(_master_eff))
	# duck(): music gain toward the duck level (down fast,
	# restore slow — the bundle ramps .3 s down / .8 s up).
	if _duck_t > 0.0:
		_duck_t -= delta
		_duck_level = move_toward(_duck_level, _duck_ratio, delta / 0.3)
	else:
		_duck_level = move_toward(_duck_level, 1.0, delta / 0.8)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),
		_lin_db(float(vol["music"]) * 0.32 * _duck_level))
	# Music crossfades (.8 s in / .6 s out — playTrack @91356).
	for i in range(2):
		var rate := delta / (0.8 if _music_fade_target[i] > _music_fade[i] else 0.6)
		_music_fade[i] = clampf(move_toward(float(_music_fade[i]), float(_music_fade_target[i]), rate), 0.0, 1.0)
		var p := _music_players[i]
		if p.playing:
			p.volume_db = _lin_db(float(_music_fade[i]))
			if _music_fade[i] <= 0.0 and _music_fade_target[i] <= 0.0:
				p.stop()

## duck(ratio, secs) (@89408): dip the music bus, restore after.
func duck(ratio: float, secs: float) -> void:
	_duck_ratio = ratio
	_duck_t = secs
	duck_count += 1

# ------------------------------------------------------------ playback

## ok(key, secs) @78837: per-key minimum interval gate.
func _ok(key: String, secs: float) -> bool:
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - float(_last_play.get(key, -1000.0)) < secs:
		return false
	_last_play[key] = now
	return true

func _count(name: String) -> void:
	play_counts[name] = int(play_counts.get(name, 0)) + 1

func count_of(name: String) -> int:
	return int(play_counts.get(name, 0))

func sfx_voice_count() -> int:
	return _sfx_players.size()

## Play a rendered SFX buffer on the voice pool (round-robin
## steal — the bundle caps live voices at 26 on coarse
## pointers; the pool IS the cap).
func _play(name: String, stream: AudioStreamWAV, pitch := 1.0, vol_db := 0.0) -> void:
	if stream == null:
		return
	var p := _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()
	_count(name)

## Render-on-first-use lookup (recipes below). "track:<name>"
## resolves to the BGM song cache (rendered from the base
## track for the pitched variants).
func stream_for(name: String) -> AudioStreamWAV:
	if name.begins_with("track:"):
		return _track_stream(name.trim_prefix("track:"))
	if _streams.has(name):
		return _streams[name]
	var s: AudioStreamWAV = _render_sfx(name)
	_streams[name] = s
	return s

func stream_length(name: String) -> float:
	var s := stream_for(name)
	return s.get_length() if s else 0.0

func _sfx(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	_play(name, stream_for(name), pitch, vol_db)

# ------------------------------------------------------------ synthesis

func _wave(phase: float, kind: int) -> float:
	var f: float = phase - floor(phase)
	match kind:
		W_SINE:
			return sin(f * TAU)
		W_SQUARE:
			return 1.0 if f < 0.5 else -1.0
		W_TRI:
			return 2.0 * absf(2.0 * (f - floor(f + 0.5))) - 1.0
		W_SAW:
			return 2.0 * f - 1.0
	return 0.0

func _mk(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * SR) + 2)
	return b

## tone() @78963: exponential attack/decay envelope, exponential
## frequency slide (slide = end/start ratio over the duration).
func _tone(mix: PackedFloat32Array, at: float, freq: float, dur: float,
		kind: int, v: float, slide := 1.0, delay := 0.0, attack := 0.004) -> void:
	var start := int((at + delay) * SR)
	var n := int(dur * SR)
	var phase := 0.0
	var lo := 0.0001
	for i in range(n):
		var idx := start + i
		if idx < 0 or idx >= mix.size():
			break
		var t := float(i) / SR
		var fr := freq * pow(maxf(slide, 0.001), t / maxf(dur, 0.001)) if slide != 1.0 else freq
		phase += fr / SR
		var env: float
		if t < attack:
			env = lo * pow(v / lo, t / maxf(attack, 0.0001))
		else:
			env = v * pow(lo / v, (t - attack) / maxf(dur - attack, 0.0001))
		mix[idx] += _wave(phase, kind) * env

## noise(): the shared white-noise buffer through a one-pole
## filter (lowpass / highpass / bandpass approximation of their
## biquads), optional exponential frequency slide.
func _noise_hit(mix: PackedFloat32Array, at: float, dur: float, v: float,
		freq: float, ftype: String, slide := 1.0, delay := 0.0) -> void:
	var start := int((at + delay) * SR)
	var n := int(dur * SR)
	var lp1 := 0.0
	var lp2 := 0.0
	for i in range(n):
		var idx := start + i
		if idx < 0 or idx >= mix.size():
			break
		var t := float(i) / SR
		var f := freq * pow(maxf(slide, 0.001), t / maxf(dur, 0.001)) if slide != 1.0 else freq
		var x: float = _noise[(start + i) % SR]
		var a := 1.0 - exp(-TAU * f / SR)
		lp1 += a * (x - lp1)
		var y := lp1
		if ftype == "highpass":
			y = x - lp1
		elif ftype == "bandpass":
			var a2 := 1.0 - exp(-TAU * f * 0.55 / SR)
			lp2 += a2 * (x - lp2)
			y = lp1 - lp2
		var env := 1.0 - t / maxf(dur, 0.001)
		mix[idx] += y * v * env

func _to_stream(mix: PackedFloat32Array, sr: int, loop := false) -> AudioStreamWAV:
	if loop and mix.size() > 256:
		# 循环曲目首尾 128 采样点柔顺过零交叉淡变，避免循环接缝处出现耳机爆音
		var fade_n := 128
		for i in range(fade_n):
			var k := float(i) / float(fade_n)
			mix[i] *= k
			mix[mix.size() - 1 - i] *= k
	var peak := 0.001
	for x in mix:
		peak = maxf(peak, absf(x))
	var g := minf(1.0, 0.92 / peak)
	var bytes := PackedByteArray()
	bytes.resize(mix.size())
	for i in range(mix.size()):
		bytes[i] = int(clampf(mix[i] * g, -1.0, 1.0) * 127.0) + 128
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = sr
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = mix.size()
	return w

# ------------------------------------------------------------ SFX recipes
## Every recipe mirrors the bundle method of the same name in the
## audio class (@74465): frequencies / durations / waves / volumes
## are the mined values; per-call random jitter is applied as
## pitch_scale at play time instead.

func _render_sfx(name: String) -> AudioStreamWAV:
	var m: PackedFloat32Array
	match name:
		"click":
			m = _mk(0.07); _tone(m, 0, 900, 0.04, W_SQUARE, 0.05)
		"hover":
			m = _mk(0.05); _tone(m, 0, 1300, 0.025, W_SINE, 0.03)
		"deny":
			m = _mk(0.36)
			_tone(m, 0, 200, 0.15, W_SQUARE, 0.10)
			_tone(m, 0, 150, 0.20, W_SQUARE, 0.10, 1.0, 0.12)
		"coin":
			m = _mk(0.28)
			_tone(m, 0, 1319, 0.06, W_SQUARE, 0.06)
			_tone(m, 0, 1976, 0.18, W_SQUARE, 0.06, 1.0, 0.06)
		"power":
			m = _mk(0.48)
			var ps := [392.0, 523.0, 659.0, 784.0, 1047.0]
			for i in range(ps.size()):
				_tone(m, 0, ps[i], 0.20, W_SQUARE, 0.06, 1.0, i * 0.05)
		"heal":
			m = _mk(0.48)
			var hs := [523.0, 659.0, 784.0, 1047.0]
			for i in range(hs.size()):
				_tone(m, 0, hs[i], 0.25, W_TRI, 0.10, 1.0, i * 0.06)
		"level_up":
			m = _mk(0.98)
			var ls := [523.0, 659.0, 784.0, 1047.0, 1319.0]
			for i in range(ls.size()):
				_tone(m, 0, ls[i], 0.30, W_SQUARE, 0.08, 1.0, i * 0.07)
			for f in [262.0, 330.0, 392.0]:
				_tone(m, 0, f, 0.60, W_TRI, 0.10, 1.0, 0.30)
		"victory":
			m = _mk(1.30)
			var vs := [523.0, 523.0, 523.0, 659.0, 784.0, 659.0, 784.0, 1047.0]
			for i in range(vs.size()):
				_tone(m, 0, vs[i], 0.25, W_SQUARE, 0.09, 1.0, i * 0.14)
		"defeat":
			m = _mk(1.50)
			var ds := [392.0, 370.0, 349.0, 330.0, 311.0]
			for i in range(ds.size()):
				_tone(m, 0, ds[i], 0.40, W_TRI, 0.10, 1.0, i * 0.25)
		"hit_weak", "hit_neutral", "hit_super", "hit_crit":
			var f := 360.0
			if name == "hit_weak":
				f = 220.0
			elif name == "hit_super":
				f = 520.0
			m = _mk(0.16)
			_tone(m, 0, f, 0.07, W_SQUARE, 0.12, 0.5)
			_noise_hit(m, 0, 0.05, 0.15, 3000, "highpass")
			if name == "hit_crit":
				_tone(m, 0, 1200, 0.12, W_TRI, 0.12, 1.5, 0.01)
		"mega":
			m = _mk(0.28)
			_tone(m, 0, 1568, 0.10, W_TRI, 0.13, 1.2)
			_tone(m, 0, 2093, 0.14, W_SINE, 0.10, 1.0, 0.05)
			_tone(m, 0, 110, 0.16, W_SINE, 0.20, 0.5)
		"pop":
			m = _mk(0.12); _tone(m, 0, 850, 0.08, W_SINE, 0.12, 2.0)
		"xp":
			m = _mk(0.14)
			_tone(m, 0, 784, 0.08, W_TRI, 0.09, 1.02)
			_tone(m, 0, 1568, 0.05, W_SINE, 0.035, 1.0, 0.015)
		"boom":
			m = _mk(0.75)
			_noise_hit(m, 0, 0.65, 0.40, 1200, "lowpass", 0.1)
			_tone(m, 0, 110, 0.50, W_SINE, 0.35, 0.3)
		"shot_fire":
			m = _mk(0.22); _noise_hit(m, 0, 0.18, 0.18, 2500, "bandpass", 0.3)
		"shot_water":
			m = _mk(0.17)
			_tone(m, 0, 600, 0.12, W_SINE, 0.12, 0.4)
			_noise_hit(m, 0, 0.10, 0.08, 1800, "bandpass")
		"shot_electric":
			m = _mk(0.14)
			_tone(m, 0, 1400, 0.08, W_SAW, 0.07, 0.3)
			_noise_hit(m, 0, 0.06, 0.10, 5000, "highpass")
		"shot_grass":
			m = _mk(0.14); _noise_hit(m, 0, 0.10, 0.12, 4000, "bandpass", 0.5)
		"shot_ice":
			m = _mk(0.19); _tone(m, 0, 1800, 0.15, W_TRI, 0.08, 0.6)
		"shot_psychic":
			m = _mk(0.24); _tone(m, 0, 900, 0.20, W_SINE, 0.10, 1.8)
		"shot_ghost":
			m = _mk(0.29); _tone(m, 0, 300, 0.25, W_TRI, 0.10, 0.6)
		"shot_default":
			m = _mk(0.12); _tone(m, 0, 700, 0.08, W_SQUARE, 0.07, 0.6)
		"beam":
			m = _mk(0.58)
			_tone(m, 0, 300, 0.50, W_SAW, 0.10, 1.5)
			_noise_hit(m, 0, 0.50, 0.10, 2000, "bandpass")
		"beam_ice":
			m = _mk(0.58)
			_tone(m, 0, 1200, 0.50, W_SAW, 0.10, 1.5)
			_noise_hit(m, 0, 0.50, 0.10, 2000, "bandpass")
		"cone_fire":
			m = _mk(0.40); _noise_hit(m, 0, 0.35, 0.16, 1500, "bandpass", 0.6)
		"cone_other":
			m = _mk(0.40); _noise_hit(m, 0, 0.35, 0.16, 3000, "bandpass", 0.6)
		"nova":
			m = _mk(0.48)
			_tone(m, 0, 200, 0.40, W_SINE, 0.30, 0.4)
			_noise_hit(m, 0, 0.35, 0.20, 900, "lowpass", 0.2)
		"nova_ground":
			m = _mk(0.48)
			_tone(m, 0, 80, 0.40, W_SINE, 0.30, 0.4)
			_noise_hit(m, 0, 0.35, 0.20, 900, "lowpass", 0.2)
		"slash":
			m = _mk(0.16); _noise_hit(m, 0, 0.12, 0.20, 5000, "highpass", 0.3)
		"whoosh":
			m = _mk(0.30); _noise_hit(m, 0, 0.25, 0.14, 800, "bandpass", 4.0)
		"zap":
			m = _mk(0.17)
			_tone(m, 0, 2000, 0.12, W_SAW, 0.06, 0.2)
			_noise_hit(m, 0, 0.10, 0.12, 6000, "highpass")
		"hurt":
			m = _mk(0.25)
			_tone(m, 0, 220, 0.20, W_SQUARE, 0.18, 0.4)
			_noise_hit(m, 0, 0.12, 0.20, 1500, "lowpass")
		"dodge":
			m = _mk(0.14); _tone(m, 0, 1500, 0.10, W_SINE, 0.08, 1.5)
		"jump":
			m = _mk(0.18); _tone(m, 0, 330, 0.14, W_SQUARE, 0.06, 2.0)
		"land":
			m = _mk(0.14); _noise_hit(m, 0, 0.10, 0.12, 600, "lowpass")
		"dive":
			m = _mk(0.38)
			_tone(m, 0, 1100, 0.32, W_SINE, 0.07, 0.35)
			_noise_hit(m, 0, 0.30, 0.10, 1800, "bandpass", 2.0)
		"slam":
			m = _mk(0.85)
			_tone(m, 0, 70, 0.70, W_SINE, 0.42, 0.45)
			_tone(m, 0, 150, 0.12, W_SQUARE, 0.12, 0.5)
			_noise_hit(m, 0, 0.75, 0.47, 900, "lowpass", 0.2)
			_noise_hit(m, 0, 0.12, 0.18, 3500, "highpass", 1.0, 0.03)
		"alarm":
			m = _mk(1.05)
			for k in range(3):
				_tone(m, 0, 660, 0.14, W_SQUARE, 0.10, 1.0, k * 0.22)
				_tone(m, 0, 440, 0.14, W_SQUARE, 0.10, 1.0, k * 0.22 + 0.11)
		"boss_start":
			m = _mk(1.55)
			_tone(m, 0, 55, 1.40, W_SAW, 0.25, 0.8)
			_noise_hit(m, 0, 1.20, 0.20, 400, "lowpass", 0.3)
			var bs := [220.0, 207.0, 196.0]
			for i in range(bs.size()):
				_tone(m, 0, bs[i], 0.40, W_SQUARE, 0.10, 1.0, i * 0.35)
		"encounter":
			m = _mk(0.45)
			var es := [659.0, 784.0, 988.0, 1319.0]
			for i in range(es.size()):
				_tone(m, 0, es[i], 0.15, W_SQUARE, 0.08, 1.0, i * 0.08)
		"throw_ball":
			m = _mk(0.35); _noise_hit(m, 0, 0.30, 0.12, 1200, "bandpass", 3.0)
		"ball_open":
			m = _mk(0.32)
			_tone(m, 0, 520, 0.22, W_SQUARE, 0.07, 2.4)
			_tone(m, 0, 1040, 0.18, W_SINE, 0.05, 2.0, 0.04)
			_noise_hit(m, 0, 0.25, 0.08, 2500, "bandpass", 2.0)
		"ball_click":
			m = _mk(0.45)
			_noise_hit(m, 0, 0.05, 0.30, 4000, "highpass")
			_tone(m, 0, 180, 0.08, W_SQUARE, 0.14, 0.6)
			var bc := [1568.0, 2093.0, 2637.0]
			for i in range(bc.size()):
				_tone(m, 0, bc[i], 0.14, W_SINE, 0.05, 1.0, 0.12 + i * 0.07)
		"ball_shake":
			m = _mk(0.24)
			_tone(m, 0, 300, 0.08, W_SQUARE, 0.12)
			_tone(m, 0, 250, 0.10, W_SQUARE, 0.10, 1.0, 0.09)
		"caught":
			m = _mk(0.95)
			var cs := [523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0, 1319.0]
			for i in range(cs.size()):
				_tone(m, 0, cs[i], 0.22, W_SQUARE, 0.09, 1.0, i * 0.11)
		"chest":
			m = _mk(0.55)
			var ch := [784.0, 988.0, 1175.0, 1568.0]
			for i in range(ch.size()):
				_tone(m, 0, ch[i], 0.18, W_TRI, 0.10, 1.0, i * 0.07)
			_noise_hit(m, 0, 0.40, 0.08, 6000, "highpass", 0.2)
		"slot_tick":
			m = _mk(0.05); _tone(m, 0, 1400, 0.025, W_SQUARE, 0.025)
		"slot_stop":
			m = _mk(0.12)
			_tone(m, 0, 260, 0.08, W_SQUARE, 0.12, 0.7)
			_noise_hit(m, 0, 0.06, 0.14, 3000, "highpass")
		"slot_lever":
			m = _mk(0.32)
			_tone(m, 0, 140, 0.12, W_SQUARE, 0.14, 0.6)
			_noise_hit(m, 0, 0.08, 0.16, 900, "bandpass")
			for k in range(4):
				_tone(m, 0, 900.0 - k * 90.0, 0.02, W_SQUARE, 0.04, 1.0, 0.10 + k * 0.035)
		"slot_coins":
			m = _mk(0.48)
			for k in range(6):
				_tone(m, 0, 1500.0 + float((k * 397) % 900), 0.05, W_SQUARE, 0.03, 1.3, 0.05 + k * 0.06)
		"slot_curse":
			m = _mk(1.05)
			var sc := [392.0, 330.0, 262.0]
			for i in range(sc.size()):
				_tone(m, 0, sc[i], 0.22, W_SAW, 0.07, 0.85, i * 0.20)
			_noise_hit(m, 0, 0.90, 0.06, 500, "lowpass", 0.4)
		"jackpot":
			m = _mk(1.65)
			var js := [523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0, 1319.0, 1568.0]
			for i in range(js.size()):
				_tone(m, 0, js[i], 0.20, W_SQUARE, 0.08, 1.0, i * 0.09)
			for k in range(10):
				_tone(m, 0, 1976, 0.05, W_SQUARE, 0.04, 1.0, 0.75 + k * 0.07)
				_tone(m, 0, 2637, 0.08, W_SQUARE, 0.035, 1.0, 0.78 + k * 0.07)
		"bell":
			m = _mk(2.70)
			var bl := [[196.0, 1.0], [233.0, 0.5], [392.0, 0.45], [523.0, 0.3], [740.0, 0.18]]
			for pr in bl:
				_tone(m, 0, pr[0], 2.60, W_SINE, 0.16 * pr[1], 0.995)
			_noise_hit(m, 0, 0.08, 0.20, 3000, "bandpass")
		"evolve_done":
			m = _mk(2.05)
			_noise_hit(m, 0, 0.50, 0.18, 3000, "highpass", 0.3)
			var e1 := [523.0, 659.0, 784.0, 1047.0]
			for i in range(e1.size()):
				_tone(m, 0, e1[i], 0.16, W_SQUARE, 0.08, 1.0, i * 0.07)
			var e2 := [523.0, 659.0, 784.0, 1047.0, 1319.0]
			for f in e2:
				_tone(m, 0, f, 1.60, W_TRI, 0.07, 1.0, 0.32, 0.02)
			for f in [262.0, 392.0]:
				_tone(m, 0, f, 1.60, W_SQUARE, 0.04, 1.0, 0.32)
			for k in range(8):
				_tone(m, 0, 1568.0 + float((k * 613) % 1500), 0.08, W_SINE, 0.035, 1.0, 0.40 + k * 0.08)
		"charge":
			m = _mk(0.25)
			_tone(m, 0, 330, 0.20, W_SINE, 0.05, 1.04)
			_tone(m, 0, 495, 0.14, W_TRI, 0.02, 1.0, 0.03)
		"streak":
			m = _mk(0.09); _tone(m, 0, 440, 0.06, W_SQUARE, 0.025, 1.2)
		_:
			m = _mk(0.05)
	return _to_stream(m, SR)

# ------------------------------------------------------------ cries
## cry(id) @90240 fetches a recorded cry file and loudness-
## normalizes it (jc @74098). The recordings are the original's
## IP and never ship here: our cry is a deterministic per-species
## chirp (base frequency + pulse pattern hashed from the id) at a
## fixed normalized level — a structural placeholder.

func cry(species_id: String, pitch := 1.0) -> void:
	if species_id == "":
		return
	var s: AudioStreamWAV
	if _cry_streams.has(species_id):
		s = _cry_streams[species_id]
	else:
		s = _render_cry(species_id)
		_cry_streams[species_id] = s
	var p := _cry_players[_cry_cursor]
	_cry_cursor = (_cry_cursor + 1) % _cry_players.size()
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = 0.0
	p.play()
	_count("cry:" + species_id)

func _render_cry(species_id: String) -> AudioStreamWAV:
	var h := species_id.hash()
	var rng := RandomNumberGenerator.new()
	rng.seed = h
	var base := 280.0 + float(abs(h) % 520)
	var m := _mk(0.42)
	var pulses: int = 2 + abs(h >> 3) % 2
	for i in range(pulses):
		var f := base * (1.0 + rng.randf_range(-0.08, 0.15) - 0.14 * i)
		var at := i * 0.13
		_tone(m, at, f, 0.10, W_SAW, 0.16, 0.72)
		_tone(m, at, f * 1.5, 0.09, W_TRI, 0.10, 0.8)
		_tone(m, at, f * 0.5, 0.11, W_SINE, 0.12, 0.9)
	return _to_stream(m, SR)

# ------------------------------------------------------------ music
## File tracks in the bundle (Ec @73814): menu / ingame1-4 /
## boss (+ a seasonal menu variant). playTrack @91356 loops with
## a .8 s fade-in and .6 s fade-out; the track gain kc = .75 is
## folded into our music bus factor (.32 of the music volume —
## the same product to within the placeholder's tolerance).
## Selection: menu track on menus; a run draws one of the four
## ingame tracks at random (@1440396); `boss` overrides while
## the guardian lives (musicFor @1440442). Our tracks are loops
## synthesized from the bundle's sequencer design (schedule()
## @92745): pad chords on bar starts, bass on quarters, kick /
## snare / hats, a square lead arp and triangle sparkle, over
## the mood progressions of playSong @90925 (bright [0,5,3,4],
## mystic [0,5,6,4], tense [0,6,5,4], calm [0,3,5,4]).
## ingame3/ingame4 are pitch variants of the two rendered ingame
## loops (their lengths in Ec are file properties, not design
## constants — DIFF cycle 16).

const TRACK_SRC := {
	"menu": {"root": 57, "scale": [0, 2, 4, 7, 9], "bpm": 92.0, "prog": [0, 3, 5, 4], "bars": 12, "pitch": 1.0},
	"ingame1": {"root": 53, "scale": [0, 2, 4, 7, 9], "bpm": 112.0, "prog": [0, 5, 3, 4], "bars": 15, "pitch": 1.0},
	"ingame2": {"root": 55, "scale": [0, 2, 3, 7, 8], "bpm": 100.0, "prog": [0, 5, 6, 4], "bars": 13, "pitch": 1.0},
	"ingame3": {"root": 53, "scale": [0, 2, 4, 7, 9], "bpm": 112.0, "prog": [0, 5, 3, 4], "bars": 15, "pitch": 1.122462},
	"ingame4": {"root": 55, "scale": [0, 2, 3, 7, 8], "bpm": 100.0, "prog": [0, 5, 6, 4], "bars": 13, "pitch": 0.890899},
	"boss": {"root": 50, "scale": [0, 2, 3, 7, 8], "bpm": 107.0, "prog": [0, 6, 5, 4], "bars": 4, "pitch": 1.0},
}
const TRACK_BASE := {"ingame3": "ingame1", "ingame4": "ingame2"}

func _track_stream(name: String) -> AudioStreamWAV:
	var base: String = TRACK_BASE.get(name, name)
	var key := "track:" + base
	if _streams.has(key):
		return _streams[key]
	var cfg: Dictionary = TRACK_SRC[base]
	var s := _render_song(cfg)
	_streams[key] = s
	return s

func _midi(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)

func _deg(scale: Array, e: int) -> int:
	var n := scale.size()
	return int(scale[((e % n) + n) % n]) + 12 * floori(float(e) / float(n))

## A tone written at the music rate (the SFX helpers are bound
## to SR; songs render at MSR).
func _mtone(mix: PackedFloat32Array, at: float, freq: float, dur: float,
		kind: int, v: float, slide := 1.0, attack := 0.01) -> void:
	var start := int(at * MSR)
	var n := int(dur * MSR)
	var phase := 0.0
	var lp := 0.0
	for i in range(n):
		var idx := start + i
		if idx < 0 or idx >= mix.size():
			break
		var t := float(i) / MSR
		var fr := freq * pow(maxf(slide, 0.001), t / maxf(dur, 0.001)) if slide != 1.0 else freq
		phase += fr / MSR
		var env: float
		if t < attack:
			env = v * t / attack
		else:
			env = v * pow(0.0001 / v, (t - attack) / maxf(dur - attack, 0.0001)) if dur > attack else 0.0
		var x := _wave(phase, kind)
		if kind == W_SAW:
			lp += 0.25 * (x - lp)   # soften the pad/lead saws
			x = lp
		mix[idx] += x * env

func _mnoise(mix: PackedFloat32Array, at: float, dur: float, v: float,
		freq: float, ftype: String) -> void:
	var start := int(at * MSR)
	var n := int(dur * MSR)
	var lp1 := 0.0
	var lp2 := 0.0
	for i in range(n):
		var idx := start + i
		if idx < 0 or idx >= mix.size():
			break
		var x: float = _noise[(start + i) % SR]
		var a := 1.0 - exp(-TAU * freq / MSR)
		lp1 += a * (x - lp1)
		var y := lp1
		if ftype == "highpass":
			y = x - lp1
		elif ftype == "bandpass":
			var a2 := 1.0 - exp(-TAU * freq * 0.55 / MSR)
			lp2 += a2 * (x - lp2)
			y = lp1 - lp2
		mix[idx] += y * v * (1.0 - float(i) / maxf(float(n), 1.0))

func _render_song(cfg: Dictionary) -> AudioStreamWAV:
	var root := float(cfg["root"])
	var scale: Array = cfg["scale"]
	var prog: Array = cfg["prog"]
	var bpm := float(cfg["bpm"])
	var bars := int(cfg["bars"])
	var step := 60.0 / bpm / 4.0
	var total := bars * 16
	var mix := PackedFloat32Array()
	mix.resize(int(total * step * MSR) + 2)
	var lead_pat := [0, 2, 4, 7, 4, 2, 0, 4]
	for s in range(total):
		var at := s * step
		var bar := s / 16
		var o := s % 16
		var chord_root := root + _deg(scale, int(prog[bar % prog.size()]))
		if o == 0:
			for dn in [0, 2, 4]:
				_mtone(mix, at, _midi(chord_root + _deg(scale, dn)), step * 15.0, W_SAW, 0.055, 1.0, 0.3)
		if o % 4 == 0:
			_mtone(mix, at, 150.0, 0.18, W_SINE, 0.50, 0.25, 0.002)          # kick
			_mtone(mix, at, _midi(chord_root - 12), step * 3.5, W_TRI, 0.22, 1.0, 0.01)  # bass
		if o == 4 or o == 12:
			_mnoise(mix, at, 0.12, 0.20, 2500, "bandpass")                    # snare
			_mtone(mix, at, 220, 0.08, W_TRI, 0.10, 0.6)
		if o % 2 == 0:
			_mnoise(mix, at, 0.03, 0.05 if o % 4 == 2 else 0.025, 8000, "highpass")  # hat
			_mtone(mix, at, _midi(root + 12 + _deg(scale, int(prog[bar % prog.size()]) + lead_pat[o % 8])), step * 1.6, W_SQUARE, 0.045)
		if o % 4 == 0 or (o % 2 == 0 and (s * 7) % 5 == 0):
			var a := (s * 13 + bar * 5) % 7
			_mtone(mix, at, _midi(root + 24 + _deg(scale, int(prog[bar % prog.size()]) + a)), step * 2.5, W_TRI, 0.07)
	return _to_stream(mix, MSR, true)

## playTrack(name) @91356: crossfade to the named loop; asking
## for the current track is a no-op. stop_music fades out.
func play_track(name: String) -> void:
	if name == current_track:
		return
	current_track = name
	var s := _track_stream(name)
	var nxt := 1 - _music_active
	var p := _music_players[nxt]
	p.stream = s
	p.pitch_scale = float(TRACK_SRC[name]["pitch"])
	p.volume_db = -60.0
	p.play()
	_music_fade[nxt] = 0.0
	_music_fade_target[nxt] = 1.0
	_music_fade_target[_music_active] = 0.0
	_music_active = nxt
	_count("track:" + name)

func stop_music() -> void:
	current_track = ""
	_music_fade_target[0] = 0.0
	_music_fade_target[1] = 0.0

# ------------------------------------------------------------ one-shot API
## The bundle engine's public surface, same names/semantics.
## Throttle intervals are the ok() values from the class.

func click() -> void:
	_sfx("click")

func hover() -> void:
	if _ok("hover", 0.04):
		_sfx("hover")

func deny() -> void:
	_sfx("deny")

func coin() -> void:
	if _ok("coin", 0.05):
		_sfx("coin")

func power() -> void:
	_sfx("power")

func heal() -> void:
	_sfx("heal")

func level_up() -> void:
	_sfx("level_up")

func victory() -> void:
	_sfx("victory")

func defeat() -> void:
	_sfx("defeat")

## hit(effectiveness, crit) @82036: pitch follows the type
## chart (520 super / 220 weak / 360 neutral), crit adds the
## 1200 ping (a separate render), mega crits prepend a jingle.
func hit(eff: float, crit := false) -> void:
	if not _ok("hit", 0.035):
		return
	var jitter := 0.9 + randf() * 0.2
	if crit:
		_play("hit_crit", stream_for("hit_crit"), jitter)
	elif eff > 1.01:
		_play("hit_super", stream_for("hit_super"), jitter)
	elif eff < 0.99:
		_play("hit_weak", stream_for("hit_weak"), jitter)
	else:
		_play("hit_neutral", stream_for("hit_neutral"), jitter)

func hit_mega() -> void:
	if _ok("mega", 0.09):
		_sfx("mega")

func pop() -> void:
	if _ok("pop", 0.03):
		_sfx("pop", 0.85 + randf() * 0.35)

## xp(step): the pentatonic ladder — step 1..15 maps onto the
## [0,2,4,7,9] scale degrees (rendered at step 1, pitch-shifted).
func xp(step: int = 1) -> void:
	if not _ok("xp", 0.035):
		return
	var n := clampi(step - 1, 0, 14)
	var deg: int = [0, 2, 4, 7, 9][n % 5] + 12 * (n / 5)
	_play("xp", stream_for("xp"), pow(2.0, float(deg) / 12.0))

func boom(size: float = 1.0) -> void:
	if _ok("boom", 0.06):
		_sfx("boom", clampf(size, 0.7, 1.3))

func shot(type: String) -> void:
	if not _ok("shot:" + type, 0.05):
		return
	var key := "shot_" + type
	if not _render_sfx_has(key):
		key = "shot_default"
	_play("shot_" + type, stream_for(key))

func _render_sfx_has(key: String) -> bool:
	return key in ["shot_fire", "shot_water", "shot_electric", "shot_grass",
		"shot_ice", "shot_psychic", "shot_ghost", "shot_default"]

func beam(type: String) -> void:
	_sfx("beam_ice" if type == "ice" else "beam")

func cone(type: String) -> void:
	if _ok("cone", 0.2):
		_sfx("cone_fire" if type == "fire" else "cone_other")

func nova(ground := false) -> void:
	if _ok("nova", 0.1):
		_sfx("nova_ground" if ground else "nova")

func slash() -> void:
	if _ok("slash", 0.05):
		_sfx("slash")

func whoosh() -> void:
	if _ok("whoosh", 0.08):
		_sfx("whoosh")

func zap() -> void:
	if _ok("zap", 0.05):
		_sfx("zap")

func hurt() -> void:
	if _ok("hurt", 0.1):
		_sfx("hurt")

func dodge() -> void:
	if _ok("dodge", 0.1):
		_sfx("dodge")

func jump(mult: float = 1.0) -> void:
	if _ok("jump", 0.05):
		_sfx("jump", mult)

func land() -> void:
	if _ok("land", 0.1):
		_sfx("land")

func dive() -> void:
	if _ok("dive", 0.2):
		_sfx("dive")

func slam(size: float) -> void:
	if _ok("slam", 0.15):
		_sfx("slam", 0.85 + 0.3 * size)

func alarm() -> void:
	_sfx("alarm")

func boss_start() -> void:
	_sfx("boss_start")

func encounter() -> void:
	_sfx("encounter")

func throw_ball() -> void:
	_sfx("throw_ball")

func ball_open() -> void:
	_sfx("ball_open")

func ball_click() -> void:
	_sfx("ball_click")

func ball_shake() -> void:
	_sfx("ball_shake")

func caught() -> void:
	_sfx("caught")

func chest() -> void:
	_sfx("chest")

func slot_tick() -> void:
	if _ok("slotTick", 0.05):
		_sfx("slot_tick", 0.95 + randf() * 0.15)

func slot_stop() -> void:
	_sfx("slot_stop")

func slot_lever() -> void:
	_sfx("slot_lever")

func slot_coins() -> void:
	_sfx("slot_coins")

func slot_curse() -> void:
	_sfx("slot_curse")

func jackpot() -> void:
	_sfx("jackpot")

func bell() -> void:
	if _ok("bell", 0.4):
		_sfx("bell")

func evolve_done() -> void:
	_sfx("evolve_done")

## charge(ratio): rising pitch with the altar's charge level
## (330 x 2^(1.5 x ratio) in the bundle; ours pitch-shifts).
func charge(ratio: float) -> void:
	if _ok("charge", 0.22):
		_sfx("charge", pow(2.0, 1.5 * clampf(ratio, 0.0, 1.0)))

## streak(n): the kill-streak blip, pitch climbing the octave.
func streak(n: int) -> void:
	if _ok("streak", 0.06):
		_sfx("streak", pow(2.0, float(mini(24, n % 25)) / 12.0))
