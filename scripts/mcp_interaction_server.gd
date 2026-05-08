extends Node

# MCP Interaction Server for Godot
# Allows the AI assistant to interact with the running game

var server: TCPServer
var peer: StreamPeerTCP
var port: int = 9090

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	server = TCPServer.new()
	var err = server.listen(port)
	if err == OK:
		print("McpInteractionServer: Listening on 127.0.0.1:", port)
	else:
		push_error("McpInteractionServer: Failed to listen on port " + str(port))

func _process(_delta):
	if server.is_connection_available():
		peer = server.take_connection()
		print("McpInteractionServer: Client connected")
	
	if peer and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		if peer.get_available_bytes() > 0:
			var request_raw = peer.get_utf8_string(peer.get_available_bytes())
			var json = JSON.new()
			var err = json.parse(request_raw)
			
			if err == OK:
				var data = json.get_data()
				_handle_request(data)
			else:
				_send_response({"success": false, "error": "Invalid JSON"})

func _handle_request(data: Dictionary):
	var command = data.get("command", "")
	var args = data.get("args", {})
	
	match command:
		"screenshot":
			_take_screenshot()
		"get_ui":
			_get_ui_elements()
		"click":
			_simulate_click(args)
		"key":
			_simulate_key(args)
		"get_performance":
			_get_performance()
		_:
			_send_response({"success": false, "error": "Unknown command: " + command})

func _send_response(response: Dictionary):
	if peer and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var json_string = JSON.stringify(response)
		peer.put_utf8_string(json_string)

func _take_screenshot():
	var image = get_viewport().get_texture().get_image()
	var buffer = image.save_png_to_buffer()
	var b64 = Marshalls.raw_to_base64(buffer)
	_send_response({"success": true, "image": b64})

func _get_ui_elements():
	var elements = []
	_scan_nodes(get_tree().root, elements)
	_send_response({"success": true, "elements": elements})

func _scan_nodes(node: Node, list: Array):
	if node is Control and node.visible:
		var data = {
			"name": node.name,
			"type": node.get_class(),
			"position": {"x": node.global_position.x, "y": node.global_position.y},
			"size": {"width": node.size.x, "height": node.size.y},
			"path": str(node.get_path())
		}
		if node is Label or node is Button:
			data["text"] = node.text
		list.append(data)
	
	for child in node.get_children():
		_scan_nodes(child, list)

func _simulate_click(args: Dictionary):
	var x = args.get("x", 0)
	var y = args.get("y", 0)
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(x, y)
	event.pressed = true
	Input.parse_input_event(event)
	
	await get_tree().create_timer(0.1).timeout
	
	event.pressed = false
	Input.parse_input_event(event)
	_send_response({"success": true, "clicked": {"x": x, "y": y}})

func _simulate_key(args: Dictionary):
	var key_name = args.get("key", "")
	var action = args.get("action", "")
	
	if action != "":
		Input.action_press(action)
		await get_tree().create_timer(0.1).timeout
		Input.action_release(action)
		_send_response({"success": true, "action": action})
	else:
		_send_response({"success": false, "error": "No action specified"})

func _get_performance():
	_send_response({
		"success": true,
		"fps": Engine.get_frames_per_second(),
		"memory": OS.get_static_memory_usage(),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	})
