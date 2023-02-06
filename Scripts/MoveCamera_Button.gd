extends Button
class_name MoveCameraButton

#GET THE MAINHANDLER SO WE CAN EASILY CONNECT TO IT
@export var MainHandler : DSMSGUI_MainHandler 
@export var WhereToSendCamera : Vector2

#MOVE CAMERA SIGNAL

signal movecamera(where:Vector2)

# Called when the node enters the scene tree for the first time.
func _ready():
	#CONNECT MAINHANDLER'S MOVE CAMERA FUNCTION TO OUR MOVECAMERA SIGNAL
	var movecameracallable = Callable(MainHandler,"move_camera_to")
	connect("movecamera",movecameracallable)
	
	var buttonpressedcallable = Callable(self,"_on_pressed")
	connect("pressed",buttonpressedcallable)


func _on_pressed():
	emit_signal("movecamera",WhereToSendCamera)
