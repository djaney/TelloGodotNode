@icon("res://addons/tello_node/drone_icon.png")

extends Node



signal command_send(cmd)
signal recived_control_code(val)
signal recived_control_code_ok()
signal recived_control_code_error()
signal recived_telemery(key, val)
signal recived_telemery_pitch(val)
signal recived_telemery_roll(val)
signal recived_telemery_yaw(val)
signal recived_telemery_vgx(val)
signal recived_telemery_vgy(val)
signal recived_telemery_vgz(val)
signal recived_telemery_templ(val)
signal recived_telemery_temph(val)
signal recived_telemery_tof(val)
signal recived_telemery_h(val)
signal recived_telemery_bat(val)
signal recived_telemery_baro(val)
signal recived_telemery_time(val)
signal recived_telemery_agx(val)
signal recived_telemery_agy(val)
signal recived_telemery_agz(val)


@export var activate_telemetry : bool = true
@export_range(-1, 10) var telemetry_update_time : float = 0.2
@export_range(0, 8) var keep_active_time : float = 0
@export var local_ctrl_port : int = 8889
@export var local_telemetry_port : int = 8890
@export var drone_ip : String = "192.168.10.1"
@export var drone_ctrl_port : int = 8889


var last_command : String
var last_ctrl_msg : String
var is_active : bool:
	get:
		return is_processing()


var _ctrl_socket : PacketPeerUDP
var _tele_socket : PacketPeerUDP
var _keep_active_timer : Timer
var _telemetry_update_timer : Timer
var _telemetry_raw : String


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_process_ctrl()
	_process_telemetry()
	if telemetry_update_time == 0:
		update_telemetry()


func start() -> void:
	if is_processing():
		return
	_init_ctrl_socket()
	_init_tele_socket()
	if keep_active_time > 0:
		_keep_active_timer = Timer.new()
		_keep_active_timer.wait_time = 5
		_keep_active_timer.one_shot = false
		_keep_active_timer.connect("timeout", _on_keep_active_timer_timeout)
		add_child(_keep_active_timer)
		_keep_active_timer.start(keep_active_time)
	if activate_telemetry:
		if telemetry_update_time > 0:
			_telemetry_update_timer = Timer.new()
			_telemetry_update_timer.wait_time = telemetry_update_time
			_telemetry_update_timer.one_shot = false
			_telemetry_update_timer.connect("timeout", _on_telemetry_update_timer_timeout)
			add_child(_telemetry_update_timer)
			_telemetry_update_timer.start()
	command()
	last_ctrl_msg = "none"


func _on_telemetry_update_timer_timeout() -> void:
	update_telemetry()


func _on_keep_active_timer_timeout() -> void:
	command()


func _init_tele_socket() -> void:
	if !activate_telemetry:
		return
	_tele_socket = PacketPeerUDP.new()
	# warning-ignore:return_value_discarded
	_tele_socket.bind(local_telemetry_port)


func _init_ctrl_socket() -> void:
	# warning-ignore:return_value_discarded
	_ctrl_socket = PacketPeerUDP.new()
	_ctrl_socket.bind(local_ctrl_port)


func _process_telemetry() -> void:
	if !_tele_socket:
		return
	var count := _tele_socket.get_available_packet_count()
	if count < 1:
		return
	var bytes : PackedByteArray
	for _i in range(count):
		bytes = _tele_socket.get_packet()
	_telemetry_raw = bytes.get_string_from_ascii()


func update_telemetry() -> Dictionary:
	var raw := _telemetry_raw
	var split1 := raw.split(";", false, 15)
	var d := {}
	for item1 in split1:
		var split2 := String(item1).split(":", false, 2)
		var k := split2[0]
		var v := split2[1]
		d[k] = v
		emit_signal("recived_telemery", k, v)
		match k:
			"pitch":
				emit_signal("recived_telemery_pitch", int(v))
			"roll":
				emit_signal("recived_telemery_roll", int(v))
			"yaw":
				emit_signal("recived_telemery_yaw", int(v))
			"vgx":
				emit_signal("recived_telemery_vgx", int(v))
			"vgy":
				emit_signal("recived_telemery_vgy", int(v))
			"vgz":
				emit_signal("recived_telemery_vgz", int(v))
			"templ":
				emit_signal("recived_telemery_templ", int(v))
			"temph":
				emit_signal("recived_telemery_temph", int(v))
			"tof":
				emit_signal("recived_telemery_tof", int(v))
			"h":
				emit_signal("recived_telemery_h", int(v))
			"bat":
				emit_signal("recived_telemery_bat", int(v))
			"baro":
				emit_signal("recived_telemery_baro", int(v))
			"time":
				emit_signal("recived_telemery_time", int(v))
			"agx":
				emit_signal("recived_telemery_agx", float(v))
			"agy":
				emit_signal("recived_telemery_agy", float(v))
			"agz":
				emit_signal("recived_telemery_agz", float(v))
	return d


func _process_ctrl() -> void:
	var count := _ctrl_socket.get_available_packet_count()
	if count < 1:
		return
	for _i in range(count):
		var bytes := _ctrl_socket.get_packet()
		var msg := bytes.get_string_from_ascii().rstrip("\n")
		last_ctrl_msg = msg
		emit_signal("recived_control_code", msg)
		match msg:
			"ok":
				emit_signal("recived_control_code_ok")
			"error":
				emit_signal("recived_control_code_error")
	if _keep_active_timer:
		_keep_active_timer.paused = false


func send_cmd(cmd: String) -> void:
	if !is_processing() and !cmd.begins_with("command"):
		return
	if keep_active_time > 0:
		_keep_active_timer.start(keep_active_time)
		_keep_active_timer.paused = true
	last_ctrl_msg = ""
	last_command = cmd
	emit_signal("command_send", cmd)
	var packet := cmd.to_ascii_buffer()
	# warning-ignore:return_value_discarded
	_ctrl_socket.set_dest_address(drone_ip, drone_ctrl_port)
	# warning-ignore:return_value_discarded
	_ctrl_socket.put_packet(packet)
	set_process(true)



func command() -> void:
	send_cmd("command")


func takeoff() -> void:
	send_cmd("takeoff")


func land() -> void:
	send_cmd("land")


func emergency() -> void:
	send_cmd("emergency")


func up(distance: int) -> void:
	if distance < 0:
		down(abs(distance))
	if distance < 20:
		push_error("up distance must be greater than or equeals 20")
		return
	if distance > 500:
		push_error("up distance must be smaller than or equeals 500")
		return
	send_cmd("up " + str(distance))


func down(distance: int) -> void:
	if distance < 20:
		push_error("down distance must be greater than or equeals 20")
		return
	if distance > 500:
		push_error("down distance must be smaller than or equeals 500")
		return
	send_cmd("down " + str(distance))


func left(distance: int) -> void:
	if distance < 20:
		push_error("left distance must be greater than or equeals 20")
		return
	if distance > 500:
		push_error("left distance must be smaller than or equeals 500")
		return
	send_cmd("left " + str(distance))


func right(distance: int) -> void:
	if distance < 20:
		push_error("right distance must be greater than or equeals 20")
		return
	if distance > 500:
		push_error("right distance must be smaller than or equeals 500")
		return
	send_cmd("right " + str(distance))


func forward(distance: int) -> void:
	if distance < 20:
		push_error("forward distance must be greater than or equeals 20")
		return
	if distance > 500:
		push_error("forward distance must be smaller than or equeals 500")
		return
	send_cmd("forward " + str(distance))


func back(distance: int) -> void:
	if distance < 20:
		push_error("backward distance must be greater than or equeals 20")
		return
	if distance > 500:
		push_error("backward distance must be smaller than or equeals 500")
		return
	send_cmd("back " + str(distance))


func cw(angle: int) -> void:
	if angle < 1:
		push_error("clockwise angle must be greater than or equeals 1")
		return
	if angle > 3600:
		push_error("clockwise angle must be smaller than or equeals 3600")
		return
	send_cmd("cw " + str(angle))


func ccw(angle: int) -> void:
	if angle < 1:
		push_error("counter clockwise angle must be greater than or equeals 1")
		return
	if angle > 3600:
		push_error("counter clockwise angle must be smaller than or equeals 3600")
		return
	send_cmd("ccw " + str(angle))


func flip(direction: int) -> void:
	match direction:
		1:
			send_cmd("flip f")
		2:
			send_cmd("flip r")
		3:
			send_cmd("flip b")
		4:
			send_cmd("flip l")
		_:
			push_error("flip direction unknown")


func go(x: int, y: int, z: int, s: int) -> void:
	# TODO boundy checks
	send_cmd("go {x} {y} {z} {s}".format({"x": x, "y": y, "z": z, "s": s}))


func curve(coord1: Vector3i, coord2: Vector3i, s: int) -> void:
	# TODO boundy checks
	# TODO check x/y/z can’t be between -20 – 20 at the same time
	# TODO check if the arc radius is not within the range of 0.5-10 meters, it responses false
	send_cmd("curve {x1} {y1} {z1} {x2} {y2} {z3} {s}".format(
		{"x1": coord1.x, "y1": coord1.y, "z1": coord1.z, "x2": coord2.x, "y2": coord2.y, "z2": coord2.z, "s": s}
		))


func speed(s: int) -> void:
	if s < 10 or s > 100:
		push_error("speed under 10 or over 100")
		return
	send_cmd("speed " + str(s))


func rc(left_right: int, forward_backward: int, up_down: int, yaw: int) -> void:
	if left_right < -100 or forward_backward < -100 or up_down < -100 or yaw < -100:
		push_error("rc all values must be over -100")
		return
	if left_right > 100 or forward_backward > 100 or up_down > 100 or yaw > 100:
		push_error("rc all values must be under 100")
		return
	send_cmd("rc {lr} {fb} {ud} {y}".format(
		{"lr": left_right, "fb": forward_backward, "ud": up_down, "y": yaw}
		))


func wifi(ssid: String, password: String) -> void:
	if ssid.length() == 0:
		push_error("wifi ssid can not be an empty string")
		return
	send_cmd("wifi {ssid} {pass}".format({"ssid": ssid, "pass": password}))


func speed_q() -> void:
	send_cmd("speed?")


func battery_q() -> void:
	send_cmd("battery?")


func time_q() -> void:
	send_cmd("time?")


func height_q() -> void:
	send_cmd("height?")


func temp_q() -> void:
	send_cmd("temp?")


func attitude_q() -> void:
	send_cmd("attitude?")


func baro_q() -> void:
	send_cmd("baro?")


func acceleration_q() -> void:
	send_cmd("acceleration?")


func tof_q() -> void:
	send_cmd("tof?")


func wifi_q() -> void:
	send_cmd("wifi?")
