extends DSMS_Data_Base
class_name DSMS_Data_FiletypeCollector

#THIS CLASS WILL BE RESPONSIBLE FOR FINDING AND HOLDING ON TO ALL THE FILES OF ITS REGISTERED 
#FILETYPE WITHIN THE MOD FOLDERS PROVIDED BY MAINHANDLER. WHEN THE TIME COMES, IT WILL ADD THESE
#TO MAINHANDLER'S JOB QUEUE, WHICH WILL LET MH DETERMINE WHICH PROCEDURES WE NEED TO RUN VIA DSMSPORTABLE.

#FILES NEED TO BE GROUPED ON A PER MOD FOLDER BASIS SO WE CAN DO THE SAME FOR MAINHANDLER AND CALL DSMS BASED
#ON WHAT EACH MOD REQUIRES

@export_enum(".csv",".fmg",".massedit",".tae") var FileTypeToSearchFor : int
@export var MH : DSMSGUI_MainHandler
@export_enum("item","menu") var FMGParamType : int

var FileArray : Array = []
var ModFolderFileArrays : Dictionary = {}

func clear_filearray():
	FileArray = []
	ModFolderFileArrays = {}

func check_modfolders_for_filetype(modfolders:Array=[],autoregisterwithmh:bool=true):
	for x in modfolders.size():
		var newfiles : Array = get_all_files_with_filetype(modfolders[x],get_filetype_name_from_mh(),true)
		#ADD NEWFILES TO MODFOLDERFILEARRAYS DICTIONARY
		if !ModFolderFileArrays.has(modfolders[x]):
			ModFolderFileArrays[modfolders[x]] = []
		ModFolderFileArrays[modfolders[x]].append_array(newfiles)
	print_debug(ModFolderFileArrays)
	if autoregisterwithmh:
		register_files_with_mh()
		
func register_files_with_mh():
	var entry : String = get_filetype_name_from_mh()
	#WITH EACH MODFOLDERFILEARRAY AS A BASE, ADD THEIR VALUES DIRECTLY TO MH'S MHDSMSJOBQUEUE
	for x in ModFolderFileArrays.keys().size():
		#CHECK IF DSMSQUEUE HAS THE FILETYPE
		if !MH.MHDSMSQueue.has(entry):
			MH.MHDSMSQueue[entry]={}
		#CHECK IF THE FILETYPE DICTIONARY IN DSMSQUEUE HAS THE CURRENT MODFOLDER
		if !MH.MHDSMSQueue[entry].has(ModFolderFileArrays.keys()[x]):
			MH.MHDSMSQueue[entry][ModFolderFileArrays.keys()[x]] = []
		MH.MHDSMSQueue[entry][ModFolderFileArrays.keys()[x]].append_array(ModFolderFileArrays[ModFolderFileArrays.keys()[x]])
#GET_FILETYPETOSEARCHFOR_REALNAME_FROM_MAINHANDLER
func get_filetype_name_from_mh()->String:
	return MH.ValidSearchTypes[FileTypeToSearchFor]

func try_converting_csvs():
	#ONLY CSV FILECOLLECTORS WILL PERFORM THIS
	if FileTypeToSearchFor == ft.csv:
		for x in ModFolderFileArrays.keys().size():
			var currentarray : Array = ModFolderFileArrays[ModFolderFileArrays.keys()[x]]
			#ITERATE OVER EACH CSV ENTRY TO TRY AND CONVERT THEM
			for y in currentarray.size():
				attempt_csv_yapped_to_dsms_conversion(currentarray[y])

func add_self_to_mh_filetypecollectors():
	MH.FiletypeCollectors.append(self)

func _ready():
	add_self_to_mh_filetypecollectors()
