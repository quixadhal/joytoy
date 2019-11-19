extends Sprite

var ourJoystick			= 0				# Just assume we have only 1 until we need to handle more.
var deadZone			= 0.1			# Ignore tiny movements as noise.
var sensitivity			= 3				# A scale for adjusting movement sensitivity

var udpScaling			= 32767.0		# used to scale floats into integers of the desired size
var udpServerAddress	= "192.168.0.16"
var udpServerPort		= 6787
var udpClientAddress	= "*"			# Whe we care, I don't know...
var udpClientPort		= 6788
var udpPacketSkip		= 10			# How many processing loops to NOT send in-between sending, 0 means 60 per second
var toSkip				= udpPacketSkip

var tickTime = OS.get_system_time_msecs()
var udpSocket = PacketPeerUDP.new()

const axisMap = {
	"LEFT ANALOG X"		: JOY_ANALOG_LX,
	"LEFT ANALOG Y"		: JOY_ANALOG_LY,
	"RIGHT ANALOG X"	: JOY_ANALOG_RX,
	"RIGHT ANALOG Y"	: JOY_ANALOG_RY,
	"LEFT TRIGGER"		: JOY_ANALOG_L2,
	"RIGHT TRIGGER"		: JOY_ANALOG_R2,
	}
const buttonMap = {
	"A"					: JOY_XBOX_A,
	"X"					: JOY_XBOX_X,
	"B"					: JOY_XBOX_B,
	"Y"					: JOY_XBOX_Y,
	"L"					: JOY_L,
	"L2"				: JOY_L2,		# This is the analog trigger as a boolean
	"L3"				: JOY_L3,
	"R"					: JOY_R,
	"R2"				: JOY_R2,		# This is the analog trigger as a boolean
	"R3"				: JOY_R3,
	"DPAD LEFT"			: JOY_DPAD_LEFT,
	"DPAD RIGHT"		: JOY_DPAD_RIGHT,
	"DPAD UP"			: JOY_DPAD_UP,
	"DPAD DOWN"			: JOY_DPAD_DOWN,
	"SELECT"			: JOY_SELECT,
	"START"				: JOY_START,
	}
const buttonBitMap = {
	"A"					: 0x0001,
	"X"					: 0x0002,
	"B"					: 0x0004,
	"Y"					: 0x0008,
	"L"					: 0x0010,
	#"L2"				: 0x0020,		# This is the analog trigger as a boolean
	"L3"				: 0x0040,
	"R"					: 0x0080,
	#"R2"				: 0x0100,		# This is the analog trigger as a boolean
	"R3"				: 0x0200,
	"DPAD LEFT"			: 0x0400,
	"DPAD RIGHT"		: 0x0800,
	"DPAD UP"			: 0x1000,
	"DPAD DOWN"			: 0x2000,
	"SELECT"			: 0x4000,
	"START"				: 0x8000,
	}

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.connect("joy_connection_changed", self, "joy_con_changed")
	var joy = Input.get_connected_joypads()
	for joyIndex in range(0, joy.size()):
		var known = "Unknown"
		if Input.is_joy_known(joyIndex):
			known = Input.get_joy_name(joyIndex)
		print(known + " Joystick " + str(joyIndex) + " already connected.")
	var err = udpSocket.listen(udpClientPort, udpClientAddress)
	if err != OK:
		print("Error opening socket " + udpClientAddress + ":" + str(udpClientPort) + ": " + str(err))
	else:
		print("Socket opened " + udpClientAddress + ":" + str(udpClientPort))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var joystickData = {}
	var packetData
	var t = OS.get_system_time_msecs()
	
	joystickData["DONE"] = 0
	if Input.get_connected_joypads().size() > 0:
		for k in axisMap:
			var v = Input.get_joy_axis(ourJoystick, axisMap[k])
			if abs(v) < deadZone:
				# If you want to handle deadzones on the other side, omit this.
				v = 0.0
			joystickData[k] = v
		for k in buttonMap:
			var v = Input.is_joy_button_pressed(ourJoystick, buttonMap[k])
			joystickData[k] = v

		var v = joystickData["LEFT ANALOG X"]
		if v < 0.0:
			self.position.x -= 100 * delta * (sensitivity * abs(v))
		elif v > 0.0:
			self.position.x += 100 * delta * (sensitivity * abs(v))
		v = joystickData["LEFT ANALOG Y"]
		if v < 0.0:
			self.position.y -= 100 * delta * (sensitivity * abs(v))
		elif v > 0.0:
			self.position.y += 100 * delta * (sensitivity * abs(v))
		
		if t - 1000 > tickTime:
			tickTime = t
			print("-----------------------------------------------------------------")
			for k in joystickData:
				print("data[\"" + k + "\"] = " + str(joystickData[k]))
	else:
		for k in axisMap:
			joystickData[k] = 0.0
		for k in buttonMap:
			joystickData[k] = false

	if Input.is_key_pressed(KEY_Q):
		joystickData["DONE"] = 1
		udpSocket.close()
		get_tree().quit()
	
	joystickData["TIME"] = t
	packetData = pack_joystick_data(joystickData)
	toSkip -= 1
	if toSkip < 1:
		toSkip = udpPacketSkip
		send_joystick_packet(packetData)
	
	if udpSocket.get_available_packet_count() > 0:
		var message = udpSocket.get_packet()
		print("Server said: " + message.get_string_from_ascii())

func joy_con_changed(deviceID, isConnected):
	if isConnected:
		var known = "Unknown"
		var joy = Input.get_connected_joypads()
		var joyIndex = joy.find(deviceID)
		
		if Input.is_joy_known(joyIndex):
			known = Input.get_joy_name(joyIndex)
		print(known + " Joystick " + str(deviceID) + " connected.")
	else:
		print("Joystick " + str(deviceID) + " disconnected.")

func pack_joystick_data(joystickData):
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = true
	
	buffer.put_u8(joystickData["DONE"])			# Just a boolean to say we're finished
	
	buffer.put_u32(joystickData["TIME"] / 1000)	# Unix timestamp
	buffer.put_u16(joystickData["TIME"] % 1000)	# Milliseconds of timestamp
	
	buffer.put_16(int(joystickData["LEFT ANALOG X"] * udpScaling))
	buffer.put_16(int(joystickData["LEFT ANALOG Y"] * udpScaling))
	buffer.put_16(int(joystickData["RIGHT ANALOG X"] * udpScaling))
	buffer.put_16(int(joystickData["RIGHT ANALOG Y"] * udpScaling))
	buffer.put_16(int(joystickData["LEFT TRIGGER"] * udpScaling))
	buffer.put_16(int(joystickData["RIGHT TRIGGER"] * udpScaling))
	
	var buttons = 0
	for k in buttonBitMap:
		if joystickData[k]:
			buttons |= buttonBitMap[k]
	buffer.put_u16(buttons)
	
	return buffer.data_array

func send_joystick_packet(data):
	#if udpSocket.is_listening():
	var err = udpSocket.set_dest_address(udpServerAddress, udpServerPort)
	if err != OK:
		print("==== Error setting destination address: " + str(err))
	else:
		err = udpSocket.put_packet(data)
		if err != OK:
			print("==== Error sending packet: " + str(err))
		else:
			print("==== Packet sent!")
