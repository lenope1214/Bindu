class_name Sfx
extends Node
## 효과음. 음원 파일 없이 시작할 때 소리를 직접 합성한다.

const RATE := 22050
const VOICES := 14

var sounds := {}  # 이름 -> AudioStreamWAV
var players: Array[AudioStreamPlayer] = []
var next_voice := 0
var last_play := {}  # 이름 -> 마지막 재생 시각(초), 너무 잦은 재생 방지
var muted := false

## 이름: [시작 주파수, 끝 주파수, 길이(초), 파형, 잡음 비율, 음량]
const DEFS := {
	"hit": [1300.0, 900.0, 0.04, "sine", 0.0, 0.25],
	"crit": [1900.0, 1500.0, 0.07, "square", 0.0, 0.22],
	"kill": [700.0, 160.0, 0.11, "square", 0.35, 0.35],
	"core": [90.0, 40.0, 0.32, "sine", 0.4, 0.8],
	"place": [420.0, 380.0, 0.06, "square", 0.0, 0.3],
	"shield": [2400.0, 600.0, 0.12, "saw", 0.2, 0.25],
	"boss": [110.0, 95.0, 0.7, "saw", 0.05, 0.4],
}
const MIN_GAP := {"hit": 0.045, "crit": 0.08, "kill": 0.04}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in DEFS:
		var d: Array = DEFS[k]
		sounds[k] = _synth([[d[0], d[1], d[2]]], d[3], d[4], d[5])
	# 여러 음으로 된 소리
	sounds["wave"] = _synth([[660.0, 660.0, 0.1], [880.0, 880.0, 0.16]], "sine", 0.0, 0.35)
	sounds["reaction"] = _synth([[523.0, 523.0, 0.08], [659.0, 659.0, 0.08], [784.0, 784.0, 0.08], [1046.0, 1046.0, 0.18]], "square", 0.0, 0.25)
	sounds["clear"] = _synth([[784.0, 784.0, 0.09], [1046.0, 1046.0, 0.2]], "sine", 0.0, 0.3)
	sounds["over"] = _synth([[392.0, 392.0, 0.2], [311.0, 311.0, 0.2], [262.0, 200.0, 0.5]], "saw", 0.0, 0.35)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func play(name: String, pitch_jitter := 0.06) -> void:
	if muted or not sounds.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_play.get(name, -1.0) < MIN_GAP.get(name, 0.0):
		return
	last_play[name] = now
	var p := players[next_voice]
	next_voice = (next_voice + 1) % VOICES
	p.stream = sounds[name]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## notes: [[시작Hz, 끝Hz, 길이], ...] 를 이어 붙인 16비트 모노 소리.
func _synth(notes: Array, wave: String, noise: float, vol: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var phase := 0.0
	for n in notes:
		var count := int(n[2] * RATE)
		for i in count:
			var k := float(i) / count
			var f: float = lerpf(n[0], n[1], k)
			phase = fposmod(phase + f / RATE, 1.0)
			var v := 0.0
			match wave:
				"sine": v = sin(phase * TAU)
				"square": v = 1.0 if phase < 0.5 else -1.0
				"saw": v = phase * 2.0 - 1.0
			v = lerpf(v, randf_range(-1.0, 1.0), noise)
			# 짧은 어택 후 감쇠
			var env := minf(k * 40.0, 1.0) * pow(1.0 - k, 1.6)
			var s := int(clampf(v * env * vol, -1.0, 1.0) * 32767.0)
			data.append(s & 0xFF)
			data.append((s >> 8) & 0xFF)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
