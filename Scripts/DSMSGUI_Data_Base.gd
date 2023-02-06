extends Node
class_name DSMS_Data_Base

#MAINHANDLER SAVE VARS

const SaveFolder : String = "DSMSGUI_Data"
const SaveFile : String = "DSMSGUI_Config.ini"


#DATA SEARCH CONSTS
enum ft {csv,fmg,massedit,anibnd}
enum fmg{item,menu}
const ValidTextTypes : Array = ["&&item&&","&&menu&&"]
const ValidSearchTypes : Array = [".csv",".fmg",".massedit",".anibnd.dcx"]
const ValidModFolders : Dictionary = {
	"ER":["action","asset","chr","event","expression","facegen","font","map","material","menu","msg","mtd","parts"]
}
#VALID TEXT MERGE NAMES - USED SO WE CAN SORT WHICH TEXT NEEDS TO BE MERGED WHERE
var ValidTextNames : Dictionary = {
	"ER":{
		"Item":[],
		"Menu":[]
	}
}

#DATA SEARCH FUNCTIONS

func get_all_files_with_filetype(directory:String,filetype:String=".csv",checksubfolders:bool=false)->Array:
	var finalarray : Array = []
	#CREATE AN ARRAY CONTAINING EVERY DIRECTORY WE'RE CHECKING
	var directoriestocheck : Array = []
	#ALWAYS INCLUDE DIRECTORY - WE'RE ASSUMING THIS DIRECTORY HAS ALREADY BEEN VALIDATED!
	directoriestocheck.append(directory)
	#IF CHECKSUBFOLDERS IS TRUE, RECURSIVELY ITERATE OVER THE FOLDERS INSIDE DIRECTORY TO FIND ALL THE DIRS TO CHECK- BE VERY CAREFUL WITH THIS!
	#WE'RE ASSUMING DIRECTORY HAS ALREADY BEEN VALIDATED ELSEWHERE!
	if checksubfolders:
		var subfolders : Array = DirAccess.get_directories_at(directory)
		#ADD TO DIRECTORIES TO CHECK
		directoriestocheck.append_array(subfolders)
		for x in subfolders.size():
			#CHECK FOR SUB-SUBFOLDERS
			var ssfolders : Array = DirAccess.get_directories_at(directory+"/"+subfolders[x])
			#ADD TO DIRECTORIES TO CHECK
			directoriestocheck.append_array(ssfolders)
	print_debug(directoriestocheck)
	#NOW WE HAVE ALL THE DIRECTORIES WE WANT TO CHECK, ITERATE OVER ALL OF THEM AND ADD ANY FILES FOUND TO FINALARRAY
	for x in directoriestocheck.size():
		var newfiles = Array(DirAccess.get_files_at(directoriestocheck[x]))
		#ADD DIRECTORIESTOCHECK PATHS TO EACH NEWFILES ENTRY
		add_path_to_string_array(newfiles,directoriestocheck[x])
		print_debug("FORMATTED: "+str(newfiles))
		finalarray.append_array(newfiles)
	#NOW WE SHOULD HAVE ALL THE FILES WE NEED (ASSUMING THEY WEREN'T NESTED TOO DEEPLY), FILTER OUT THE ENTRIES THAT DON'T HAVE OUR DESIRED FILETYPE
	#AND RETURN THE RESULTING ARRAY
	finalarray = filter_array_by_filetype(finalarray,filetype)
	print_debug(finalarray)
	return finalarray

func filter_array_by_filetype(arraytocheck:Array=[],filetype:String=".csv")->Array:
	var finalarray : Array = []
	for x in arraytocheck.size():
		#CATCH .FMG.JSONs AND TRY TO DETERMINE WHETHER THEY SHOULD BE 
		#CHECK FOR EITHER THE FILETYPE AS TYPED OR THE FILETYPE IN ALL CAPS
		if filetype in arraytocheck[x] or filetype.to_upper() in arraytocheck[x]:
			finalarray.append(arraytocheck[x])
	#print_debug(finalarray)
	return finalarray

func remove_texttype_from_string(stringtoedit:String):
	for x in ValidTextTypes.size():
		if ValidTextTypes[x] in stringtoedit:
			stringtoedit = stringtoedit.replace(ValidTextTypes[x],"")
	return stringtoedit

func remove_filetypes_from_array(array:Array=[],filetypes:Array=[".fmg.json",".fmg.xml",".fmg"])->Array:
	#FOR ALL ENTRIES IN ARRAY, CHECK IF THEY HAVE EITHER FILETYPE AND REMOVE THEM
	for x in array.size():
		for y in filetypes.size():
			if filetypes[y] in array[x]:
				array[x] = array[x].replace(filetypes[y],"")
	return array

#INFORMATION FUNCTIONS

func update_valid_text_names_from_gametype():
	var gt = get_gametype()
	ValidTextNames[gt]["Item"]=DirAccess.get_files_at("res://Data/ValidTextNames/"+gt+"/ItemText/")
	ValidTextNames[gt]["Menu"]=DirAccess.get_files_at("res://Data/ValidTextNames/"+gt+"/MenuText/")
	ValidTextNames[gt]["Item"]=remove_filetypes_from_array(ValidTextNames[gt]["Item"])
	ValidTextNames[gt]["Menu"]=remove_filetypes_from_array(ValidTextNames[gt]["Menu"])
	print_debug(ValidTextNames[gt]["Item"])
	print_debug(ValidTextNames[gt]["Menu"])

func validate_text_file_name_and_type(filename:String)->Array:
	var gt = get_gametype()
	var menutext : bool = false
	var validname : bool = false
	#CHECK THROUGH ITEMTEXTNAMES FIRST
	for x in ValidTextNames[gt]["Item"].size():
		if ValidTextNames[gt]["Item"][x] in filename:
			validname = true
			menutext =false
	#CHECK THROUGH MENUTEXTNAMES NEXT AND SET MENUTEXT TO TRUE IF SO
	for x in ValidTextNames[gt]["Menu"].size():
		if ValidTextNames[gt]["Menu"][x] in filename:
			validname = true
			menutext = true
	#RETURN FINAL ARRAY
	var returnarray : Array = [validname,menutext]
	return returnarray

func get_gametype(lowercase:bool=false)->String:
	var gt : String = get_node("/root/GlobalVariables").gametype
	if lowercase:
		gt = gt.to_lower()
	return gt

func get_exe_path()->String:
	return OS.get_executable_path().get_base_dir()
	
func get_data_folder_path()->String:
	return get_exe_path()+"/"+SaveFolder

func get_save_file_path()->String:
	return get_data_folder_path()+"/"+SaveFile

func get_output_bat_path()->String:
	return get_data_folder_path()+"/DSMSBatch.bat"

func get_newline_separated_array_from_file(filepath:String)->Array:
	var finalarray : Array = []
	if FileAccess.file_exists(filepath):
		var file = FileAccess.open(filepath,FileAccess.READ)
		while !file.eof_reached():
			var newline = str(file.get_line())
			if newline != "":
				finalarray.append(newline)
		print_debug(finalarray)
	else:
		print_debug("GetNewlineSeparatedArray failed: Couldn't find file at "+filepath)
	return finalarray

func create_copy_command_if_regbin_backup_present(basepath:String)->String:
	var finalstring = ""
	const copycommandstart = "copy /y "
	#STORE A VARIABLE TO DECIDE IF WE'VE FOUND ANYTHING
	var foundone : bool = false
	#FILE TO USE - PREFER reg-copy AS .PREV HAS A DANGER OF BEING "TAINTED" BY AN ALREADY MERGED MOD
	var filetouse : String = ""
	#FIRST CHECK FOR "regulation - (Copy).bin", INDICATING A BACKUP THE PLAYER'S MADE
	if FileAccess.file_exists(basepath+"/regulation - (Copy).bin"):
		foundone = true
		filetouse = "/regulation - (Copy).bin"
	elif FileAccess.file_exists(basepath+"/regulation.bin.prev"):
		foundone = true
		filetouse = "/regulation.bin.prev"
	
	#IF WE FOUND ONE, APPLY THE VALUES TO FINALSTRING
	if foundone:
		finalstring = copycommandstart+basepath+filetouse+" "+basepath+"/regulation.bin\n"
		print_debug(finalstring)
		
	return finalstring

#FORMATTING FUNCTIONS

func attempt_csv_yapped_to_dsms_conversion(csv:String):
	if FileAccess.file_exists(csv):
		var c = FileAccess.open(csv,FileAccess.READ)
		var csvtext = c.get_as_text()
		#CHECK FOR YAPPED STYLE ID AND NAME FIELDS, AS THIS WILL THROW A "COULD NOT PARSE CORRECT DATA TYPES" ERROR FROM DSMS
		if "Row ID" in csvtext or "Row Name" in csvtext:
			OS.alert(csv+"\nappears to be a Yapped .csv export, which DSMS may throw a 'Could Not Parse Data Types' error on trying to import.\nAMM will now attempt conversion - please note there may be some fields that DSMS needs that Yapped .csvs do not provide, usually the 'pad' values. If DSMSP gives you a 'CSV has wrong number of entries' error, this is most likely why.")
			csvtext = csvtext.replace("Row ID","ID")
			csvtext = csvtext.replace("Row Name","Name")
			#ALSO CHECK FOR SEMICOLON IF THIS IS THE CASE, AS THIS SEEMS TO BE THE DEFAULT SEPARATOR FOR YAPPED
			if ";" in csvtext:
				#MAKE SURE THERE AREN'T ANY COMMAS ANYWHERE ELSE
				csvtext = csvtext.replace(",","")
				csvtext = csvtext.replace(";",",")
			#WRITE NEW VERSION BACK TO FILE
			var cw = FileAccess.open(csv,FileAccess.WRITE)
			cw.store_line(csvtext)
			
			
		

func add_quotes_around_string(stringtoreturn:String):
	var finalstring = stringtoreturn
	#ADD QUOTES AT END
	finalstring = finalstring+"\""
	#ADD QUOTES AT START
	finalstring = finalstring.indent("\"")
	return finalstring

func array_to_string(convarray:Array)->String:
	var strtoreturn = ""
	for x in convarray.size():
		#QUOTE THE STRINGS AS THESE WILL MOST LIKELY BE PATHS
		strtoreturn += add_quotes_around_string(str(convarray[x]))
		#ADD A SPACE BETWEEN THE ENTRIES
		if x != convarray.size()-1:
			strtoreturn += " "
	return strtoreturn

func format_double_backslash_to_frontslash(stringtoedit:String)->String:
	return stringtoedit.replace("/","\\")

func add_quotes_around_array(arraytoquote:Array=[])->Array:
	if arraytoquote.size() > 0:
		for x in arraytoquote.size():
			arraytoquote[x]=add_quotes_around_string(arraytoquote[x])
	return arraytoquote

func add_path_to_string(filepath:String,basestring:String)->String:
	return basestring.indent(filepath+"/")

func add_path_to_string_array(arraytoformat:Array=[],path:String="")->Array:
	if arraytoformat.size() > 0:
		for x in arraytoformat.size():
			arraytoformat[x]=add_path_to_string(path,arraytoformat[x])
	return arraytoformat
	
#FILE HANDLING FUNCTIONS

func create_directory(path:String):
	if !DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_absolute(path)
	
func copy_all_files_from_source_directory_to_target_directory(dirfrom:String,dirto:String,overwrite:bool=false,filetypefilter:String=""):
	#CHECK IF SOURCE DIRECTORY EXISTS AND GET THE FILES THERE
	if DirAccess.dir_exists_absolute(dirfrom):
		var fromfiles : Array = DirAccess.get_files_at(dirfrom)
		#FORMAT FROMFILES WITH FULL PATH
		fromfiles = add_path_to_string_array(fromfiles,dirfrom)
		#IF FILETYPEFILTER IS NOT EMPTY, ITERATE OVER EACH ENTRY IN THIS ARRAY AND REMOVE THOSE THAT DON'T HAVE THE FILETYPE
		if filetypefilter != "":
			for x in fromfiles.size():
				if !filetypefilter in fromfiles[x]:
					fromfiles.remove_at(x)
		#CHECK IF DIRTO EXISTS, MAKE IT RECURSIVELY IF IT DOESN'T
		if !DirAccess.dir_exists_absolute(dirto):
			DirAccess.make_dir_recursive_absolute(dirto)
		#GET THE FILES AVAILABLE AT DIRTO
		var tofile : Array = DirAccess.get_files_at(dirto)
		#FORMAT TOFILE
		#ITERATE OVER ALL FROMFILES - IF A FILE OF THE SAME NAME EXISTS AT DIRTO, CHECK IF OVERWRITE IS TRUE AND KEEP COPYING, OTHERWISE MOVE ON
		for x in fromfiles.size():
			var currentfile: String = dirfrom+"/"+fromfiles[x]
			var destfile:String = dirto+"/"+fromfiles[x]
			if !tofile.has(fromfiles[x]) or overwrite:
				print_debug("Copying "+currentfile+", as either tofiles doesn't have it or overwrite is true.")
				DirAccess.copy_absolute(currentfile,destfile)

#OTHER FUNCTIONS

func connect_self_method(methodname:String,signalname:String,object=self):
	var newcallable = Callable(self,methodname)
	object.connect(signalname,newcallable)

func create_bat_at_path(path:String,content:String):
	var bat = FileAccess.open(path,FileAccess.WRITE)
	bat.store_line(content)
	print_debug("Creating .bat at "+path)

