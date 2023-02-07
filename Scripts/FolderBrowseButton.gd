extends Button
class_name FolderBrowseButton

@export var dirbrowse : FileDialog
@export var target : TextEdit
@export var dirsignal : String = "dir_selected"

func set_target_text(newtext:String):
	target.text = newtext

func connectbrowse(disconnectiftrue:bool=false):
	var browsecallable = Callable(self,"set_target_text")
	if disconnectiftrue:
		dirbrowse.disconnect(dirsignal,browsecallable)
	else:
		dirbrowse.connect(dirsignal,browsecallable)

func _ready():
	var pressedcallable = Callable(self,"_on_pressed")
	connect("pressed",pressedcallable)

func _on_pressed():
	connectbrowse()
	self.disabled = true
	dirbrowse.visible = true
	await (dirbrowse.visibility_changed)
	dirbrowse.visible = false
	connectbrowse(true)
	self.disabled = false
	
