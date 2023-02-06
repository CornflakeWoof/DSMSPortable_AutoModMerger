extends HBoxContainer
class_name ModFolderEntry

@export var ModPath : TextEdit
@export var MoveUp : Button
@export var MoveDown: Button
@export var DeleteButton : Button
@export var Disabled : CheckBox

@export var MH : DSMSGUI_MainHandler

#SIGNAL TO CONTROL WHICH WAY WE'RE MOVING THE MODFOLDERENTRY IN ITS PARENT'S HIERARCHY

signal move_mfe_requested(downiftrue:bool)

func connect_self_method(methodname:String,signalname:String,object=self):
	var newcallable = Callable(self,methodname)
	object.connect(signalname,newcallable)

#UP AND DOWN BUTTONS FUNCTIONS

func _move_up_pressed():
	emit_signal("move_mfe_requested",false)

func _move_down_pressed():
	emit_signal("move_mfe_requested",true)

#MFE ADJUSTMENT METHODS

func move_modfolderentry(downiftrue:bool=false):
	#SETUP WHICH WAY WE'RE MOVING OUR MFE
	var moveindex = 1 if downiftrue else -1
	#GET THE MFE'S INDEX ON ITS PARENT
	var myindex = self.get_index()
	#GET THE MFE CONTAINER'S TOTAL NUMBER OF CHILDREN
	var numofmfes : int = get_parent().get_child_count()-1
	#CREATE OUR DESIRED NEW DESIRED INDEX AND WRAP IT AROUND THE TOTAL NUMBER OF MFES
	var desiredmoveindex = myindex+moveindex
	wrapi(desiredmoveindex,0,numofmfes)
	#GET OUR PARENT, PRESUMED TO BE MODFOLDERSCONTAINER, AND ASK IT TO MOVE THIS NODE TO THE DESIRED INDEX
	get_parent().move_child(self,desiredmoveindex)

func delete_mod_folder_entry():
	#DISABLE THIS ENTRY, CHECK IF OWNER HAS MFC, ASSUME IT'S MAINHANDLER IF SO, AND ASK IT TO SAVE
	Disabled.button_pressed = false
	if is_instance_valid(MH):
		MH.save_mainhandler_data()
	call_deferred("queue_free")

func _ready():
	connect_self_method("delete_mod_folder_entry","pressed",DeleteButton)
	connect_self_method("move_modfolderentry","move_mfe_requested",self)
	connect_self_method("_move_up_pressed","pressed",MoveUp)
	connect_self_method("_move_down_pressed","pressed",MoveDown)
