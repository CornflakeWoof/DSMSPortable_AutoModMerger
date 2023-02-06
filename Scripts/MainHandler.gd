extends DSMS_Data_Base
class_name DSMSGUI_MainHandler

#MODFOLDERSCONTAINER
@export var MFC : VBoxContainer

#ADD ModFolderEntry (MFE)
@export var MFE_TextBox : TextEdit
@export var AddMFE : Button
#LOAD/SAVE MFEs
@export var MFE_Load : Button
@export var MFE_Save : Button
@export var MFE_Path_TextBox : TextEdit

#START FRESH CHECK MARK
@export var StartFresh : CheckBox
@export var ConvertCSV : CheckBox

#PATHS
@export var GamePath_ER : TextEdit
@export var ProgPath_DSMSP : TextEdit
@export var ProgPath_OutputModFolder : TextEdit

#START MERGE BUTTON
@export var StartMergeButton : Button
@export var BatNameText : TextEdit

#OPEN DATAFOLDER
@export var OpenDataFolder : Button
@export var OpenMergedModExportFolder : Button

#MSGBND PATHS
@export var MSGBND_Item : TextEdit
@export var MSGBND_Menu : TextEdit

#SAVE BUTTONS
@export var SaveButton2 : Button

#STATUS INDICATOR
@export var Status : Label

#MFESCENEPATH
const MFEScene : String = "res://Scenes/ModFolderEntry.tscn"

#FILETYPE COLLECTORS - THESE SHOULD ADD THEMSELVES TO THIS ARRAY WHEN THEY'RE READY SO WE CAN ITERATE OVER ALL OF THEM AUTOMATICALLY
var FiletypeCollectors : Array[DSMS_Data_FiletypeCollector] = []


var MHSaveDictionary : Dictionary = {
	"path_er":"",
	"path_dsms":"",
	"path_regbin":"",
	"batname":"",
	"mfe_array":[],
	"startfresh":false,
	"convertyappedcsv":false
}

#MH JOB QUEUE - THIS IS WHERE ALL CALLS TO DSMS WILL BE STORED

var MHDSMSQueue : Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	mh_connections()
	load_mainhandler_data()
	update_valid_text_names_from_gametype()
	pass

func _exit_tree():
	save_mainhandler_data()
	
#MAIN MERGING PROCESS

func start_merging_process():
	#CHECK IF WE HAVE ANY MOD FOLDER ENTRIES
	if MFC.get_child_count() > 0:
		#RESET JOB QUEUE
		clear_dsms_job_queue()
		#CLEAR ALL FILECOLLECTORS' DATA
		all_fc_clear()
		#UPDATE VALID TEXT NAMES FOR EVERYONE
		all_fc_update_textnames()
		#FIRST, GET ALL OF OUR FILETYPE COLLECTORS TO SEARCH THEIR MODFOLDERS 
		update_status_indicator("-GETTING RECOGNISED FILETYPES FROM MOD FOLDERS-")
		all_fc_search_for_files_and_add_to_job_queue()
		if ConvertCSV.button_pressed:
			all_fc_convert_csv()
		update_status_indicator("-COMPILING DSMS BAT FILE-")
		process_dsms_job_queue()
	else:
		OS.alert("No Mod Folder Entries detected, cancelling merge.")

func stop_merging_process():
	update_status_indicator("-MERGE COMPLETE-")

#ALL FILETYPE COLLECTOR FUNCTIONS

func all_fc_convert_csv():
	update_status_indicator("-ATTEMPTING YAPPED -> DSMS CSV CONVERSION-")
	if ConvertCSV.button_pressed:
		for x in FiletypeCollectors.size():
			if FiletypeCollectors[x].FileTypeToSearchFor == 0:
				FiletypeCollectors[x].try_converting_csvs()

func all_fc_update_textnames():
	for x in FiletypeCollectors.size():
		FiletypeCollectors[x].update_valid_text_names_from_gametype()
	#ALSO MAKE SURE MH DOES THIS
	update_valid_text_names_from_gametype()

func all_fc_clear():
	for x in FiletypeCollectors.size():
		FiletypeCollectors[x].clear_filearray()

func all_fc_search_for_files_and_add_to_job_queue():
	for x in FiletypeCollectors.size():
		FiletypeCollectors[x].check_modfolders_for_filetype(get_all_modfolderentry_paths_array())
	#SHORT PAUSE TO MAKE SURE EVERYTHING'S FINISHED
	await get_tree().create_timer(0.5).timeout

#DSMS CALLING FUNCTIONS

func process_dsms_job_queue():
	#THIS IS THE MAIN PROCESS THAT APPLIES THE DISCOVERED DSL FILES TO THE STATED REGULATION.BIN
	#FOR EACH MODFOLDER IN THE DSMS JOB QUEUE - WE'LL USE THE MFEARRAYS VARIABLE TO GET THE RIGHT ORDER...
	#CREATE THE INITIAL BATCH FILE STRING
	var batch : String = ""
	#FIRST ADD COPY COMMAND IF WE'RE GOING TO RESET REGBIN
	if StartFresh.button_pressed:
		batch += create_copy_command_if_regbin_backup_present(format_frontslash_to_double_backslash(get_mod_output_folder()))
	update_save_dictionary()
	#FOR EACH DISCOVERED FILETYPE REGISTERED IN MHDSMSQUEUE...
	for x in MHDSMSQueue.keys().size():
		#GET CURRENT FILETYPE NAME
		var curft : String = MHDSMSQueue.keys()[x]
		#ITERATE OVER EACH MOD FOLDER IN THE MFE ARRAY ORDER...
		for y in MHSaveDictionary["mfe_array"].size():
			#IF THE CURRENT FILETYPE KEY HAS AN ARRAY FOR THE CURRENT MODFOLDER
			var newkey :String = MHSaveDictionary["mfe_array"][y]
			if MHDSMSQueue[curft].has(newkey):
				#MAKE SURE CURFT->MODFOLDER ACTUALLY HAS CONTENT BEFORE WE CONTINUE
				if MHDSMSQueue[curft][newkey].size() > 0:
					#CREATE A NEW BATCH FILE ADDITION AND ADD THE DSMS PATH
					var newbatch: String = ""
					newbatch += add_quotes_around_string(get_dsms_path())+" "
					print_debug(curft+" has "+newkey+", processing...")
					update_status_indicator("-PROCESSING '"+newkey+"'-")
					#GET THE RELEVANT DSMS OPERATION AND ADD IT TO THE NEWBATCH LINE
					newbatch += get_next_dsms_operation_from_filetype(curft)+" "
					#FINALLY, ADD THE ARRAY AND A NEWLINE, THEN ADD THIS TO THE OVERALL BATCH FILE
					newbatch += array_to_string(MHDSMSQueue[curft][newkey])
					batch += newbatch+"\n"
				
	#ONCE WE'VE ITERATED OVER ALL FILETYPES AND MFE ARRAY ENTRIES, WRITE THE FINAL BATCH FILE AND RUN IT THROUGH CMD
	create_bat_at_path(get_data_folder_path()+"/DSMSMerge"+get_bat_name()+".bat",batch)
	run_dsms()

func get_next_dsms_operation_from_filetype(filetype:String=".csv",menufmgiftrue:bool=false)->String:#->PackedStringArray:
	var arguments : String
	#STORE DSMS FLAG TO ADD
	var DSMSCommand : String = "-C"
	var DSMSGametype : String = "ER"
	var DSMSNeedsRegBinandGamePath : bool = false
	var DSMSNeedsItemMenuFMG : bool = false
	var DSMSNeedsOutput : bool = true
	match remove_texttype_from_string(filetype):
		".csv":
			DSMSCommand = "-C"
			DSMSNeedsRegBinandGamePath = true
		".massedit":
			DSMSCommand = "-M"
			DSMSNeedsRegBinandGamePath = true
		".fmg":
			DSMSCommand = "--fmg-merge"
			DSMSNeedsItemMenuFMG = true
	
	#WE'RE GOING TO BE RUNNING THIS THROUGH CMD, SO FIRST ADD DSMS AS A BASE APPLICATION
	
	#arguments.append(get_dsms_path())
	
	#ADD DSMS REGBIN AND GAMEPATH IF NEEDED
	if DSMSNeedsRegBinandGamePath:
		arguments += (create_dsms_regbin_and_gametype_arguments())

	#ADD OUTPUT IF NEEDED
		
	#NEXT, ADD THE DSMS COMMAND DETERMINED BY FILETYPE
	arguments += " "+DSMSCommand
	
	#HANDLE ITEM/MENU .FMG IF REQUIRED
	
	print_debug(filetype+" "+str(arguments))
	
	return arguments 
	
func create_dsms_msgbnd_commands(modfolder:String)->String:
	#WE'RE ASSUMING THE --fmg-merge PARAMETER HAS ALREADY BEEN DECIDED 
	var finalmsgbnd : String = ""
	var additionaldsmscall : String = ""
	var dsmscall : String = get_dsms_path()+" --fmg-merge "
	#FIRST, ACCESS MHJOBQUEUE'S .FMG ENTRY FOR THE MODFOLDER IF IT HAS ONE
	if MHDSMSQueue.has(".fmg"):
		if MHDSMSQueue[".fmg"].has(modfolder):
			if MHDSMSQueue[".fmg"][modfolder].size() > 0:
				#CHECK FOR OUTPUT MSGBNDS AND ONLY GO FURTHER IF THEY'RE NOT EMPTY
				var msgbnds : Array = get_output_mod_msgbnd_paths()
				var itemaddition : String = ""
				var menuaddition : String = ""
				#FIRST SORT OUR FMG ENTRIES
				var msgentries : Array = sort_fmg_entries(modfolder)
				#ITERATE OVER BOTH SETS OF DATA - ITEM FIRST, THEN DATA
				for x in msgbnds.size():
					var additiontoaddto : Array = [itemaddition,menuaddition]
					#CHECK THAT PATH ARRAY ISN'T EMPTY
					if msgbnds[x] != "":
						#CHECK THAT THE RELEVANT ARRAY ISN'T EMPTY
						if msgentries[x].size() > 0:
							var newaddition : String = ""
							#ADD RELEVANT FMG DCX PATH FROM MSGBNDS
							newaddition += msgbnds[x]+" "
							#NOW ADD THE SORTED FMG ENTRIES
							for y in msgentries[x].size():
								newaddition += add_quotes_around_string(msgentries[x])+" "
							additiontoaddto[x] += newaddition
				#NOW THAT'S DONE, CHECK EACH xADDITION - IF ITEM IS EMPTY, LET MENU TAKE PRIORITY AND DON'T ADD AN EXTRA DSMS CALL,
				#OTHERWISE LET ITEM TAKE THIS ONE AND ADD A NEW -FMGMERGE RUN OF DSMS FOR THE MENU FMG DCX
				if itemaddition != "" and menuaddition != "":
					finalmsgbnd = itemaddition
					additionaldsmscall = "\n"+dsmscall+menuaddition+"\n"
				elif itemaddition != "":
					pass
				else:
					#IF ITEMADDITION IS EMPTY AND MENUADDITION ISN'T
					finalmsgbnd = menuaddition
	return finalmsgbnd
	
func sort_fmg_entries(modfolder:String)->Array:
	var itemmsg : Array = []
	var menumsg : Array = []
	#MAKE SURE MSDMSQUEUE ACTUALLY HAS AN FMG ENTRY FOR THE MODFOLDER
	if MHDSMSQueue.has(".fmg"):
		if MHDSMSQueue[".fmg"].has(modfolder):
			var mffmgs : Array = MHDSMSQueue[".fmg"][modfolder]
			for x in mffmgs.size():
				var entry : String = mffmgs[x]
				#VALIDATE WHETHER THIS FMG IS A VALID TEXT NAME AND DECIDE WHICH ARRAY IT SHOULD GO IN
				var entryvalid : Array = validate_text_file_name_and_type(entry)
				#IF ENTRY IS VALID...
				if entryvalid[0]:
					#PUT IT IN MENUMSG IF IT HAS A MENU TEXT FILENAME...
					if entryvalid[1]:
						menumsg.append(entry)
					#OTHERWISE PUT IT IN ITEMMSG
					else:
						itemmsg.append(entry)
	print_debug([itemmsg,menumsg])
	return [itemmsg,menumsg]

func get_output_mod_msgbnd_paths()->Array:
	var basepath = get_mod_output_folder()
	var itemmsg:String = ""
	var menumsg:String = ""
	if FileAccess.file_exists(basepath+"/msg/engus/item.msgbnd.dcx"):
		itemmsg=basepath+"/msg/engus/item.msgbnd.dcx"
	if FileAccess.file_exists(basepath+"/msg/engus/menu.msgbnd.dcx"):
		menumsg=basepath+"/msg/engus/menu.msgbnd.dcx"
	return [itemmsg,menumsg]

func get_bat_name()->String:
	var nametoreturn : String = ""
	if BatNameText.text != "":
		nametoreturn = "_"+BatNameText.text
	return nametoreturn

func create_dsms_regbin_and_gametype_arguments()->String:
	var argumentsarray : String = ""
	#FIRST ADD REGULATION PATH BY GETTING MOD OUTPUT FOLDER AND ADDING "regulation.bin"
	argumentsarray += add_quotes_around_string(get_mod_output_folder()+"/regulation.bin")+" "
	#NOW ADD GAMETYPE COMMAND AND CURRENT GAME ID
	argumentsarray += ("-G ")
	argumentsarray += (get_gametype())
	#NOW SET GAMEPATH
	argumentsarray += (" -P ")
	argumentsarray += add_quotes_around_string(GamePath_ER.text)
	
	return argumentsarray

func run_dsms(arguments:String=""):
	#VERIFY IF DSMS PATH ACTUALLY POINTS TO DSMS - OR AT LEAST AN EXECUTABLE NAMED DSMSPortable.exe
	if FileAccess.file_exists(get_dsms_path()) and (".exe" in get_dsms_path() or ".EXE" in get_dsms_path()):
		var finaldsms : String = add_quotes_around_string(get_dsms_path())+" "+arguments
		print_debug("Attempting to run "+get_output_bat_path()+"!")
		OS.alert("DSMSPortable .bat file created! Open the AMM data folder and run 'DSMSMerge.bat' to merge mods!")
		update_status_indicator("-READY-")
	else:
		OS.alert("DSMSPortable.exe not found at '"+get_dsms_path()+"'!\n\nMake sure your DSMS Path is the full path to DSMSPortable.exe, with the executable included.\n\nAMM will now exit.")
		#QUIT TO STOP THIS BEING SPAMMED
		get_tree().quit()
	pass

func get_dsms_path()->String:
	return ProgPath_DSMSP.text

#STATUS FUNCTIONS

func update_status_indicator(texttoset:String="-READY-"):
	Status.text = texttoset
	await get_tree().create_timer(0.1).timeout
	
#FOLDER OPENING FUNCTIONS

func open_data_folder():
	OS.shell_open(get_data_folder_path())

func open_mergedmod_output_folder():
	OS.shell_open(get_mod_output_folder())

#MAINHANDLER CONNECTIONS
func mh_connections():
	connect_self_method("create_new_mfe_from_textbox_contents","pressed",AddMFE)
	connect_self_method("open_data_folder","pressed",OpenDataFolder)
	connect_self_method("save_mainhandler_data","pressed",SaveButton2)
	connect_self_method("start_merging_process","pressed",StartMergeButton)
	connect_self_method("open_mergedmod_output_folder","pressed",OpenMergedModExportFolder)
	connect_self_method("_on_load_mfes_button_pressed","pressed",MFE_Load)
	connect_self_method("_on_save_mfes_button_pressed","pressed",MFE_Save)
#MODFOLDERENTRY FUNCTIONS

func add_modfolderentry(path:String):
	#MAKE SURE WE HAVE A VALID PATH VALUE BEFORE DOING ANYTHING ELSE
	if path != "":
		var newmfe = preload(MFEScene).instantiate()
		newmfe.MH = self
		MFC.add_child(newmfe)
		#SET NEW MFE'S MODFOLDERPATH TEXT FIELD
		newmfe.ModPath.text = path

func get_all_modfolderentry_paths_array()->Array:
	var mfepathsarray : Array = []
	#FIRST, GET ALL OF MODSFOLDERCONTAINER'S CHILDREN
	var mfcchildren = MFC.get_children()
	#IF MFCCHILDREN ISN'T EMPTY, ITERATE OVER EACH ONE, CHECK IF IT HAS A "MODPATH" VARIABLE, AND IF IT DOES
	#ADD IT TO MFEPATHSARRAY
	if mfcchildren.size() > 0:
		for x in mfcchildren.size():
			if "ModPath" in mfcchildren[x]:
				if mfcchildren[x].Disabled.button_pressed:
					mfepathsarray.append(mfcchildren[x].ModPath.text)
	print_debug(mfepathsarray)
	return mfepathsarray

func _on_load_mfes_button_pressed():
	load_mfes_from_file(MFE_Path_TextBox.text)

func load_mfes_from_file(filepath:String):
	#MAKE SURE FILE EXISTS BEFORE WE DO ANYTHING
	if FileAccess.file_exists(filepath):
		#TRY TO LOAD SPECIFIED FILE, CONVERT ITS LINES INTO AN ARRAY WITH NEWLINE (ENTER) AS DELIM
		var filemfearray : Array = get_newline_separated_array_from_file(filepath)
		#ONCE WE'VE GOT THAT, MAKE SURE FILEMFEARRAY ISN'T EMPTY, AND CREATE NEW FMES FROM THIS ARRAY
		if filemfearray.size() > 0:
			clear_mfes_and_replace(filemfearray)
	else:
		OS.alert("Load Mod Folder Entries failed: Could not find '"+filepath+"'")

func _on_save_mfes_button_pressed():
	save_mfes_to_file(MFE_Path_TextBox.text)

func save_mfes_to_file(filepath:String):
	var currentmfes : Array = get_all_modfolderentry_paths_array()
	var stringtoadd : String = ""
	#ITERATE OVER THE ARRAY, AND ADD EACH ON TO THE STRING AND SAVE IT TO THE FILEPATH
	for x in currentmfes.size():
		stringtoadd += currentmfes[x]
		#ADD A NEWLINE IF WE'RE NOT DEALING WITH THE LAST ENTRY IN THE ARRAY
		if x != currentmfes.size()-1:
			stringtoadd += "\n"
	#SAVE FILE
	var mfefile = FileAccess.open(filepath,FileAccess.WRITE)
	if mfefile:
		mfefile.store_line(stringtoadd)
		OS.alert("Mod Folder Entry preset file saved at '"+filepath+"'")
	else:
		OS.alert("Mod Folder Entry save failed: Couldn't open '"+filepath+"' for editing")

func create_mfes_from_array(newmfesarray:Array):
	for x in newmfesarray.size():
		add_modfolderentry(newmfesarray[x])

func clear_mfes_and_replace(newmfesarray:Array):
	clear_mfes()
	create_mfes_from_array(newmfesarray)

func clear_mfes():
	#REMOVE ALL MFENTRIES
	var mfes : Array = MFC.get_children()
	for x in mfes.size():
		mfes[x].queue_free()

#SAVE DICTIONARY FUNCTIONS
func update_save_dictionary():
	MHSaveDictionary["mfe_array"]=get_all_modfolderentry_paths_array()
	MHSaveDictionary["path_er"]=GamePath_ER.text
	MHSaveDictionary["path_dsms"]=ProgPath_DSMSP.text
	MHSaveDictionary["path_regbin"]=ProgPath_OutputModFolder.text
	MHSaveDictionary["startfresh"]=StartFresh.button_pressed
	MHSaveDictionary["batname"]=BatNameText.text
	

func apply_save_dictionary():
	GamePath_ER.text=MHSaveDictionary["path_er"]
	ProgPath_DSMSP.text=MHSaveDictionary["path_dsms"]
	ProgPath_OutputModFolder.text=MHSaveDictionary["path_regbin"]
	StartFresh.button_pressed = MHSaveDictionary["startfresh"]
	BatNameText.text = MHSaveDictionary["batname"]
	ConvertCSV.button_pressed = MHSaveDictionary["convertyappedcsv"]

func create_mfes_from_save_dictionary():
	for x in MHSaveDictionary["mfe_array"].size():
		add_modfolderentry(MHSaveDictionary["mfe_array"][x])

func create_new_mfe_from_textbox_contents():
	add_modfolderentry(MFE_TextBox.text)
	
func open_filedialog_for_modpath():
	var newdialog = FileDialog.new()
	newdialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	get_viewport().add_child(newdialog)
	var foldercallable = Callable(self,"add_modfolderentry")
	newdialog.connect("dir_selected",foldercallable)
	await newdialog.dir_selected
	newdialog.disconnect("dir_selected",foldercallable)
	newdialog.queue_free()

func clear_dsms_job_queue():
	MHDSMSQueue = {}
	
#MAINHANDLER INFORMATION FUNCTIONS

func get_mod_output_folder()->String:
	return ProgPath_OutputModFolder.text
	
#VALIDATION FUNCTIONS

const noquotesreminder : String = "\n\nThere's no need to enclose the path in quotes, as Auto Merger will do this automatically."

func are_required_paths_filled()->bool:
	var booltoreturn : bool = false
	#FIRST CHECK IF AT LEAST ONE GAME PATH IS FULL
	if GamePath_ER.text != "":
		#CHECK IF THE PATH TO DSMSP IS PROVIDED 
		if "DSMSPortable.exe" in ProgPath_DSMSP.text or "DSMSPortable.EXE" in ProgPath_DSMSP.text:
			if ProgPath_OutputModFolder.text != "":
				booltoreturn = true
			else:
				OS.alert("Make sure you've provided the full path to the folder we'll be searching for a regulation.bin and merging our data into!"+noquotesreminder)
		else:
			OS.alert("Make sure you've provided the full path to DSMSPortable.exe on the Paths page!"+noquotesreminder)
	else:
		OS.alert("Make sure at least one game path is filled in on the Paths page!"+noquotesreminder)
	return booltoreturn

#CAMERA MOVEMENT FUNCTIONS

	
#MAINHANDLER SAVING AND LOADING FUNCTIONS

func save_mainhandler_data():
	#CREATE SAVE DIRECTORY IF IT DOESN'T EXIST
	create_directory(get_data_folder_path())
	#print_debug(get_data_folder_path())
	#UPDATE MFE ENTRIES
	update_save_dictionary()
	#CREATE CONFIG FILE
	var conf = ConfigFile.new()
	conf.set_value("modfolderentries","modfolderentriestoload",MHSaveDictionary["mfe_array"])
	conf.set_value("dsms","dsmsexepath",ProgPath_DSMSP.text)
	conf.set_value("gamepaths","path_er",GamePath_ER.text)
	conf.set_value("output","outputmodfolderpath",ProgPath_OutputModFolder.text)
	conf.set_value("output","outputbatname",BatNameText.text)
	conf.set_value("merging","deleteexistingregbin",StartFresh.button_pressed)
	conf.set_value("merging","convertyappedcsv",ConvertCSV.button_pressed)
	conf.save(get_save_file_path())
	
func load_mainhandler_data():
	#FIRST CHECK IF SAVEFILE EXISTS
	if FileAccess.file_exists(get_save_file_path()):
		#CREATE ARRAYS FOR CONFIG HEADERS, VALUES AND INTENDED RECIPIENT
		var conf = ConfigFile.new()
		conf.load(get_save_file_path())
			
		MHSaveDictionary["mfe_array"]=conf.get_value("modfolderentries","modfolderentriestoload")
		MHSaveDictionary["path_er"]=conf.get_value("gamepaths","path_er")
		MHSaveDictionary["path_dsms"]=conf.get_value("dsms","dsmsexepath")
		MHSaveDictionary["path_regbin"]=conf.get_value("output","outputmodfolderpath")
		MHSaveDictionary["startfresh"]=conf.get_value("merging","deleteexistingregbin")
		MHSaveDictionary["batname"]=conf.get_value("output","outputbatname")
		MHSaveDictionary["convertyappedcsv"]=conf.get_value("merging","convertyappedcsv")
		#NOW WE'VE GRABBED THE SAVED MFE ARRAY, CREATE MFES FROM THE LOADED SAVE DICTIONARY
		create_mfes_from_save_dictionary()
		apply_save_dictionary()
	else:
		print_debug("No savefile found at '"+get_save_file_path()+"'")
	
#DEBUG INPUT

func _input(event):
	if Input.is_action_just_pressed("debug_getmodfolders"):
		get_all_modfolderentry_paths_array()
