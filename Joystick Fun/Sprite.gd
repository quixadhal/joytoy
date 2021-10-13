extends Sprite

var deadZone			= 0.1			# Ignore tiny movements as noise.
var sensitivity			= 3				# A scale for adjusting movement sensitivity

var udpScaling			= 32767.0		# used to scale floats into integers of the desired size
var udpClientAddress	= "*"			# Whe we care, I don't know...
var udpClientPort		= 6780
var udpPacketSkip		= 10			# How many processing loops to NOT send in-between sending, 0 means 60 per second
var toSkip				= udpPacketSkip

var tickTime = OS.get_system_time_msecs()
var udpSocket = PacketPeerUDP.new()

var joystickMap = [
	"Player 1",
	"Player 2",
	"Player 3",
	"Player 4",
	"Player 5",
	"Player 6",
	"Player 7",
	"Player 8",
	"Player 9"
]	# Hardcoded list of users
var connectedMap = [
	false,
	false,
	false,
	false,
	false,
	false,
	false,
	false,
	false
]
var udpInfo = [						# Hardcoded set of address/port data to use
	{
		"address" : "192.168.0.11",
		"port" : 6781
	},
	{
		"address" : "192.168.0.11",
		"port" : 6782
	},
	{
		"address" : "192.168.0.11",
		"port" : 6783
	},
	{
		"address" : "192.168.0.11",
		"port" : 6784
	},
	{
		"address" : "192.168.0.11",
		"port" : 6785
	},
	{
		"address" : "192.168.0.11",
		"port" : 6786
	},
	{
		"address" : "192.168.0.11",
		"port" : 6787
	},
	{
		"address" : "192.168.0.11",
		"port" : 6788
	},
	{
		"address" : "192.168.0.11",
		"port" : 6789		
	}
]

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
		var thisJoystick = joy[joyIndex]
		var known = "Unknown"
		if Input.is_joy_known(thisJoystick):
			known = Input.get_joy_name(thisJoystick)
		var thisUser = joystickMap[thisJoystick]
		connectedMap[thisJoystick] = true
		print(known + " Joystick " + str(thisJoystick) + " already connected for " + thisUser + ".")
	var err = udpSocket.listen(udpClientPort, udpClientAddress)
	if err != OK:
		print("Error opening socket " + udpClientAddress + ":" + str(udpClientPort) + ": " + str(err))
	else:
		print("Socket opened " + udpClientAddress + ":" + str(udpClientPort))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var packetData
	var joy = Input.get_connected_joypads()
	var isDone = false
	toSkip -= 1
	
	if Input.is_key_pressed(KEY_Q):
		# This should quite the whole application.
		isDone = true

	for joyIndex in range(0, joy.size()):
		var thisJoystick = joy[joyIndex]
		var thisUser = joystickMap[thisJoystick]
		var joystickData = {}
		joystickData["DONE"] = 0
		if isDone:
			joystickData["DONE"] = 1
			
		joystickData["JOYSTICK"] = thisJoystick
		joystickData["USER"] = thisUser
		var t = OS.get_system_time_msecs()

		for k in axisMap:
			var v = Input.get_joy_axis(thisJoystick, axisMap[k])
			if abs(v) < deadZone:
				# If you want to handle deadzones on the other side, omit this.
				v = 0.0
			joystickData[k] = v
		for k in buttonMap:
			var v = Input.is_joy_button_pressed(thisJoystick, buttonMap[k])
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

		joystickData["TIME"] = t
		packetData = pack_joystick_data(joystickData)

		if t - 1000 > tickTime:
			tickTime = t
			var guid = Input.get_joy_guid(thisJoystick)
			#print("-----------------------------------------------------------------")
			#print("Joystick GUID: " + guid)
			#for k in joystickData:
			#	print("data[\"" + k + "\"] = " + str(joystickData[k]))

		if toSkip < 1 or isDone:
			# send the data to each joystick target, but try not to spam
			# always send the done packet though...
			send_joystick_packet(thisJoystick, packetData)

	if toSkip < 1:
		# And outside the loop, reset the skip counter
		toSkip = udpPacketSkip
	
	if udpSocket.get_available_packet_count() > 0:
		var message = udpSocket.get_packet()
		print("Server said: " + message.get_string_from_ascii())

	if isDone:
		# This should quite the whole application.
		udpSocket.close()
		get_tree().quit()


func joy_con_changed(deviceID, isConnected):
	var thisJoystick = deviceID
	var known = "Unknown"
	var thisUser = joystickMap[thisJoystick]
	var joy = Input.get_connected_joypads()
	var joyIndex = joy.find(thisJoystick)
	
	if joyIndex < 0:
		print("Joystick " + str(thisJoystick) + " not found.")
	
	if Input.is_joy_known(thisJoystick):
		known = Input.get_joy_name(thisJoystick)
	
	if isConnected:
		connectedMap[thisJoystick] = true
		print(known + " Joystick " + str(thisJoystick) + " connected for " + thisUser + ".")
	else:
		connectedMap[thisJoystick] = false
		print("Joystick " + str(thisJoystick) + " disconnected from " + thisUser + ".")


func pack_joystick_data(joystickData):
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = true
	
	buffer.put_u8(joystickData["DONE"])			# Just a boolean to say we're finished
	buffer.put_u8(joystickData["JOYSTICK"])		# Joystick ID
	
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

	if joystickData["DONE"] == 1:
		print("DONE for " + str(joystickData["JOYSTICK"]) + " on " + joystickData["USER"])
	
	return buffer.data_array

func send_joystick_packet(joystick, data):
	#if udpSocket.is_listening():
	var err = udpSocket.set_dest_address(udpInfo[joystick]["address"], udpInfo[joystick]["port"])
	if err != OK:
		print("==== Error setting destination address: " + str(err))
	else:
		err = udpSocket.put_packet(data)
		if err != OK:
			print("==== Error sending packet: " + str(err))
		else:
			pass
			#print("==== Packet sent!")
