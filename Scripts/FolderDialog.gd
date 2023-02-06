extends Node

@onready var fd = $FileDialog

var SavedText : String = ""
var TransmitTextTo : TextEdit = null
var ButtonToReactivate : FolderBrowseButton = null

func save_dialog_text(texttoset:String):
	#IF TTT IS A VALID TEXTEDIT NODE,
	if is_instance_valid(TransmitTextTo):
		TransmitTextTo.text = texttoset

func _on_file_dialog_dir_selected(dir):
	save_dialog_text(dir)
