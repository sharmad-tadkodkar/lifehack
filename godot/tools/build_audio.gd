extends SceneTree
## Synthesizes every default sound effect, the garage ambience and the music loop into
## res://assets/audio/*.wav (no recorded audio, no licences). Recipes follow the web game's sound
## kit (src/engine/Audio.ts): enveloped tones with pitch slides, and filtered noise bursts.
## Any of them can be replaced by a recording through config/audio.cfg ([sfx.<id>] file=...).
##   godot --headless --path godot -s res://tools/build_audio.gd

const OUT := "res://assets/audio/"
const RATE := 22050


class Buf:
	var data: PackedFloat32Array

	func _init(seconds: float) -> void:
		data.resize(int(seconds * RATE))

	## Enveloped oscillator: quick attack, exponential decay; optional exponential pitch slide.
	func tone(freq: float, dur: float, shape: String, vol: float, at := 0.0, slide_to := 0.0, attack := 0.01) -> void:
		var start := int(at * RATE)
		var count := int(dur * RATE)
		var phase := 0.0
		for i in count:
			var n := start + i
			if n >= data.size():
				break
			var t := float(i) / RATE
			var f := freq if slide_to <= 0.0 else freq * pow(slide_to / freq, t / dur)
			phase = fmod(phase + f / RATE, 1.0)
			var env := minf(t / attack, 1.0) * exp(-5.0 * t / dur)
			data[n] += _wave(shape, phase) * vol * env

	## Filtered white noise with an exponential fade (bandpass / lowpass / highpass).
	func burst(dur: float, freq: float, q: float, vol: float, at := 0.0, kind := "bandpass", fade := 5.0, attack := 0.002) -> void:
		var filter := Biquad.new(kind, freq, q)
		var start := int(at * RATE)
		for i in int(dur * RATE):
			var n := start + i
			if n >= data.size():
				break
			var t := float(i) / RATE
			var env := minf(t / attack, 1.0) * exp(-fade * t / dur)
			data[n] += filter.step(randf() * 2.0 - 1.0) * vol * env

	## Noise through a bandpass whose centre sweeps from `f0` to `f1` (zips, hisses, scrapes).
	func sweep(dur: float, f0: float, f1: float, q: float, vol: float, at := 0.0, attack := 0.05) -> void:
		var filter := Biquad.new("bandpass", f0, q)
		var start := int(at * RATE)
		var count := int(dur * RATE)
		for i in count:
			var n := start + i
			if n >= data.size():
				break
			var k := float(i) / count
			if i % 64 == 0:
				filter.set_freq(f0 * pow(f1 / f0, k))
			var env := minf(k * dur / attack, 1.0) * (1.0 - k)
			data[n] += filter.step(randf() * 2.0 - 1.0) * vol * env

	func normalize(peak := 0.9) -> void:
		var top := 0.0001
		for v in data:
			top = maxf(top, absf(v))
		for i in data.size():
			data[i] = data[i] * peak / top

	func save(path: String, loop := false) -> void:
		var bytes := PackedByteArray()
		bytes.resize(data.size() * 2)
		for i in data.size():
			bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32767.0))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = RATE
		wav.stereo = false
		wav.data = bytes
		if loop:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = data.size()
		wav.save_to_wav(ProjectSettings.globalize_path(path))

	static func _wave(shape: String, p: float) -> float:
		match shape:
			"square":
				return 1.0 if p < 0.5 else -1.0
			"saw":
				return 2.0 * p - 1.0
			"triangle":
				return 4.0 * absf(p - 0.5) - 1.0
		return sin(TAU * p)


## RBJ cookbook biquad.
class Biquad:
	var kind: String
	var q: float
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	func _init(kind_: String, freq: float, q_: float) -> void:
		kind = kind_
		q = q_
		set_freq(freq)

	func set_freq(freq: float) -> void:
		var w := TAU * clampf(freq, 20.0, RATE * 0.45) / RATE
		var alpha := sin(w) / (2.0 * q)
		var c := cos(w)
		var a0 := 1.0 + alpha
		match kind:
			"lowpass":
				b0 = (1.0 - c) / 2.0; b1 = 1.0 - c; b2 = b0
			"highpass":
				b0 = (1.0 + c) / 2.0; b1 = -(1.0 + c); b2 = b0
			_:
				b0 = alpha; b1 = 0.0; b2 = -alpha
		b0 /= a0; b1 /= a0; b2 /= a0
		a1 = -2.0 * c / a0
		a2 = (1.0 - alpha) / a0

	func step(x: float) -> float:
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1; x1 = x; y2 = y1; y1 = y
		return y


func _initialize() -> void:
	seed(7)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var made := 0
	for id in RECIPES:
		var b: Buf = call("_" + id)
		b.save(OUT + id + ".wav", id in LOOPS)
		made += 1
	print("[audio] wrote %d sounds to %s; now run: godot --headless --path godot --import" % [made, OUT])
	quit()


const RECIPES := ["nut_crack", "ratchet", "nut_spin", "nut_drop", "nut_thread", "nut_seat",
	"jack_place", "jack_pump", "car_creak", "valve_hiss", "car_settle", "wheel_slide", "wheel_thud",
	"pickup", "putdown", "good", "bad", "stamp", "fanfare", "ui_move", "ui_select", "garage_hum", "music_loop"]
const LOOPS := ["garage_hum", "music_loop"]


# --- nuts ----------------------------------------------------------------------------

## The nut breaking free: a sharp metallic crack with a short ring.
func _nut_crack() -> Buf:
	var b := Buf.new(0.5)
	b.burst(0.05, 2600, 1.5, 0.9)
	b.tone(1250, 0.22, "triangle", 0.35, 0.004)
	b.tone(1870, 0.16, "triangle", 0.2, 0.004)
	b.tone(140, 0.12, "sine", 0.5, 0.0, 70)
	b.normalize()
	return b


## A wrench pull: six ratchet clicks (web kit's ratchet()).
func _ratchet() -> Buf:
	var b := Buf.new(0.5)
	for i in 6:
		b.burst(0.03, 3200, 4, 0.8, i * 0.07)
		b.tone(4200, 0.015, "square", 0.05, i * 0.07)
	b.normalize(0.8)
	return b


## A loose nut spun off the stud: rising metallic zip.
func _nut_spin() -> Buf:
	var b := Buf.new(0.45)
	b.sweep(0.42, 1400, 4200, 6, 1.0)
	for i in 7:
		b.burst(0.012, 5000, 3, 0.25, 0.04 + i * 0.05)
	b.normalize(0.7)
	return b


## A nut landing in the pile.
func _nut_drop() -> Buf:
	var b := Buf.new(0.35)
	b.tone(2900, 0.12, "triangle", 0.5)
	b.tone(4100, 0.08, "triangle", 0.3, 0.003)
	b.tone(3100, 0.07, "triangle", 0.25, 0.09)
	b.burst(0.02, 6000, 2, 0.3)
	b.normalize(0.7)
	return b


## Threading a nut on by hand: soft falling zip.
func _nut_thread() -> Buf:
	var b := Buf.new(0.45)
	b.sweep(0.4, 3600, 1300, 5, 1.0)
	b.burst(0.03, 900, 1, 0.3, 0.38)
	b.normalize(0.6)
	return b


## Final torque: a firm low clunk as the nut seats.
func _nut_seat() -> Buf:
	var b := Buf.new(0.4)
	b.tone(110, 0.25, "sine", 0.9, 0.0, 60)
	b.burst(0.08, 1500, 1.2, 0.5)
	b.tone(980, 0.15, "triangle", 0.15, 0.005)
	b.normalize()
	return b


# --- jack and car ----------------------------------------------------------------------

## The jack set down on concrete (web kit's clank(), heavier).
func _jack_place() -> Buf:
	var b := Buf.new(0.6)
	b.tone(95, 0.3, "sine", 0.8, 0.0, 55)
	b.tone(620, 0.35, "triangle", 0.3, 0.002)
	b.tone(930, 0.28, "triangle", 0.18, 0.004)
	b.burst(0.1, 2400, 1.5, 0.5)
	b.normalize()
	return b


## One pump stroke: lever squeak, then a short hydraulic push.
func _jack_pump() -> Buf:
	var b := Buf.new(0.6)
	b.tone(820, 0.16, "saw", 0.12, 0.0, 1050, 0.03)
	b.sweep(0.3, 500, 260, 3, 0.8, 0.12)
	b.tone(75, 0.22, "sine", 0.45, 0.18, 62)
	b.burst(0.02, 3000, 3, 0.25, 0.3)
	b.normalize(0.75)
	return b


## The body creaking as it rises or settles.
func _car_creak() -> Buf:
	var b := Buf.new(0.8)
	var f := 230.0
	for i in 9:
		b.tone(f + randf() * 40.0, 0.09, "saw", 0.14, i * 0.075, f * 0.85, 0.02)
	b.burst(0.75, 180, 0.7, 0.15, 0.0, "lowpass", 3.0, 0.1)
	b.normalize(0.55)
	return b


## Opening the release valve: a long hydraulic hiss that fades as the car comes down.
func _valve_hiss() -> Buf:
	var b := Buf.new(2.2)
	b.burst(0.12, 800, 1.0, 0.4)
	b.burst(2.1, 2400, 0.8, 0.5, 0.05, "bandpass", 2.5, 0.15)
	b.burst(2.1, 6500, 0.9, 0.18, 0.05, "highpass", 3.0, 0.2)
	b.normalize(0.6)
	return b


## The tyre taking the car's weight: low thump and a creak.
func _car_settle() -> Buf:
	var b := Buf.new(0.9)
	b.tone(62, 0.45, "sine", 1.0, 0.0, 38)
	b.burst(0.3, 260, 0.8, 0.5)
	b.tone(210, 0.3, "saw", 0.08, 0.15, 160, 0.05)
	b.normalize()
	return b


# --- wheels and items --------------------------------------------------------------------

func _wheel_slide() -> Buf:
	var b := Buf.new(0.7)
	b.sweep(0.65, 300, 650, 1.2, 1.0, 0.0, 0.1)
	b.burst(0.6, 140, 0.8, 0.3, 0.02, "lowpass", 2.0, 0.1)
	b.normalize(0.55)
	return b


func _wheel_thud() -> Buf:
	var b := Buf.new(0.6)
	b.tone(72, 0.4, "sine", 1.0, 0.0, 44)
	b.burst(0.18, 420, 0.8, 0.55)
	b.tone(64, 0.2, "sine", 0.4, 0.18, 44)
	b.normalize()
	return b


## Taking something into the hand (web kit's pop()).
func _pickup() -> Buf:
	var b := Buf.new(0.25)
	b.tone(520, 0.1, "sine", 0.5, 0.0, 900)
	b.burst(0.05, 1800, 1.2, 0.3)
	b.normalize(0.6)
	return b


## Setting something down: a soft clank.
func _putdown() -> Buf:
	var b := Buf.new(0.35)
	b.tone(160, 0.18, "sine", 0.6, 0.0, 90)
	b.tone(760, 0.2, "triangle", 0.15, 0.003)
	b.burst(0.05, 2200, 1.5, 0.35)
	b.normalize(0.65)
	return b


# --- feedback and UI -----------------------------------------------------------------------

func _good() -> Buf:
	var b := Buf.new(0.5)
	b.tone(660, 0.18, "sine", 0.4)
	b.tone(990, 0.3, "sine", 0.36, 0.09)
	b.normalize(0.6)
	return b


func _bad() -> Buf:
	var b := Buf.new(0.45)
	b.tone(180, 0.3, "saw", 0.3, 0.0, 120)
	b.tone(150, 0.3, "saw", 0.2, 0.12, 95)
	b.normalize(0.5)
	return b


func _stamp() -> Buf:
	var b := Buf.new(0.5)
	b.tone(90, 0.3, "sine", 0.9, 0.0, 45)
	b.burst(0.18, 900, 0.7, 0.45)
	b.normalize()
	return b


## Four-note finish jingle.
func _fanfare() -> Buf:
	var b := Buf.new(1.6)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in notes.size():
		var length := 0.9 if i == notes.size() - 1 else 0.22
		b.tone(notes[i], length, "triangle", 0.35, i * 0.13)
		b.tone(notes[i] * 2.0, length, "sine", 0.1, i * 0.13)
	b.normalize(0.6)
	return b


func _ui_move() -> Buf:
	var b := Buf.new(0.06)
	b.tone(2400, 0.03, "square", 0.3)
	b.normalize(0.35)
	return b


func _ui_select() -> Buf:
	var b := Buf.new(0.15)
	b.tone(1200, 0.05, "square", 0.25)
	b.tone(1800, 0.07, "square", 0.25, 0.05)
	b.normalize(0.4)
	return b


# --- ambience and music ----------------------------------------------------------------------

## Faint fluorescent hum and room tone; loops cleanly (whole periods of 60 Hz).
func _garage_hum() -> Buf:
	var seconds := 4.0
	var b := Buf.new(seconds)
	var filter := Biquad.new("lowpass", 300, 0.7)
	for i in b.data.size():
		var t := float(i) / RATE
		b.data[i] = 0.30 * sin(TAU * 60.0 * t) + 0.12 * sin(TAU * 120.0 * t) + 0.05 * sin(TAU * 180.0 * t) \
			+ 0.35 * filter.step(randf() * 2.0 - 1.0)
	b.normalize(0.5)
	return b


## Light, quirky loop: 8 bars at 100 BPM in C major. Walking pizzicato bass, a bouncy marimba-ish
## lead, offbeat plucks and brushed hats.
func _music_loop() -> Buf:
	var bpm := 100.0
	var beat := 60.0 / bpm
	var bars := 8
	var b := Buf.new(bars * 4 * beat)
	var chords := [[48, 52, 55], [45, 48, 52], [41, 45, 48], [43, 47, 50]]  # C Am F G
	# lead melody, one entry per 8th note (MIDI note or -1 rest), two 4-bar phrases
	var melody := [
		72, -1, 76, 79, -1, 76, 74, -1,   72, -1, 69, 72, -1, 76, -1, -1,
		77, -1, 76, 74, -1, 72, 74, -1,   71, -1, 74, 79, -1, 77, 76, 74,
		72, -1, 76, 79, -1, 81, 79, -1,   76, -1, 72, 76, -1, 74, -1, -1,
		77, 81, -1, 77, 76, -1, 74, -1,   79, -1, 77, 74, 71, -1, 72, -1]
	for bar in bars:
		var chord: Array = chords[bar % 4]
		var t0 := bar * 4 * beat
		# bass: root on 1, fifth on 3, walking note on 4-and
		b.tone(_hz(chord[0] - 12), beat * 0.9, "triangle", 0.55, t0)
		b.tone(_hz(chord[2] - 12), beat * 0.9, "triangle", 0.45, t0 + 2 * beat)
		b.tone(_hz(chord[1] - 12), beat * 0.45, "triangle", 0.35, t0 + 3.5 * beat)
		# offbeat chord plucks
		for k in 4:
			for note in chord:
				b.tone(_hz(note + 12), beat * 0.25, "square", 0.035, t0 + (k + 0.5) * beat)
		# hats on every 8th, a soft kick on 1 and 3
		for k in 8:
			b.burst(0.05, 7000, 1.0, 0.09 if k % 2 == 1 else 0.05, t0 + k * beat * 0.5, "highpass")
		b.tone(90, 0.18, "sine", 0.4, t0, 50)
		b.tone(90, 0.18, "sine", 0.3, t0 + 2 * beat, 50)
		# lead: marimba-ish (sine + bright 4th harmonic, fast decay)
		for k in 8:
			var note: int = melody[bar * 8 + k]
			if note < 0:
				continue
			var at := t0 + k * beat * 0.5
			b.tone(_hz(note), beat * 0.7, "sine", 0.3, at, 0.0, 0.004)
			b.tone(_hz(note) * 4.0, beat * 0.15, "sine", 0.06, at, 0.0, 0.002)
	b.normalize(0.7)
	return b


static func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)
