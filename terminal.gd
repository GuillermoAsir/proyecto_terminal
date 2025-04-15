extends Control

@onready var history = $Background/MarginContainer/Rows/GameInfo/History
@onready var nano_panel = $NanoPanel
@onready var editor = $NanoPanel/Editor
@onready var save_button = $NanoPanel/GuardarBoton
@onready var mision2_popup = $Mision2Popup

var current_command = ""
var current_path = "/"  # Ruta relativa dentro de ubuntu_sim
const BASE_PATH = "user://ubuntu_sim"  # Ruta real base
var current_file_being_edited = ""
var mision2_completada = false

const USER_COLOR = "[color=green]usuario@usuario[/color]"
const PROMPT_BASE = "$"

func _ready():
	history.bbcode_enabled = true
	nano_panel.visible = false
	mision2_popup.visible = false
	init_structure()
	show_prompt()
	save_button.pressed.connect(_on_save_button_pressed)

func init_structure():
	if not DirAccess.dir_exists_absolute(BASE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.make_dir("ubuntu_sim")
			dir.change_dir("ubuntu_sim")
			for folder in ["home", "etc", "var", "secret", "bin"]:
				dir.make_dir(folder)
			dir.make_dir("home/usuario1")
			dir.make_dir("home/usuario1/Documents")
			dir.make_dir("home/usuario1/Descargas")
			dir.make_dir("home/usuario1/Escritorio")

func _input(event):
	if event is InputEventKey and event.pressed:
		if nano_panel.visible and editor.has_focus():
			return
		if mision2_popup.visible and event.keycode == KEY_ENTER:
			mision2_popup.visible = false
			return

		if nano_panel.visible:
			if event.keycode == KEY_ENTER:
				return  # Evita procesar comandos mientras estás en nano

		if event.keycode == KEY_ENTER:
			process_command(current_command.strip_edges())
			current_command = ""
		elif event.keycode == KEY_BACKSPACE:
			if current_command.length() > 0:
				current_command = current_command.left(current_command.length() - 1)
				history.text = history.text.left(history.text.length() - 1)
		elif event.unicode > 0:
			var char_input = char(event.unicode)
			current_command += char_input
			history.append_text(char_input)

func show_prompt():
	var path_color = "[color=skyblue]" + current_path + "[/color]"
	history.append_text("\n" + USER_COLOR + ":" + path_color + PROMPT_BASE + " ")

func get_full_path():
	var normalized = current_path
	if normalized != "/" and normalized.ends_with("/"):
		normalized = normalized.substr(0, normalized.length() - 1)
	return BASE_PATH + normalized

func process_command(command: String):
	var output := ""

	if command.begins_with("cd "):
		var target = command.substr(3).strip_edges()
		var new_path = current_path

		if target == "..":
			if current_path != "/":
				var parts = current_path.split("/")
				parts = parts.filter(func(p): return p != "")
				if parts.size() > 0:
					parts.remove_at(parts.size() - 1)
					new_path = "/" + "/".join(parts) if parts.size() > 0 else "/"
		elif target == "/":
			new_path = "/"
		else:
			new_path = target if target.begins_with("/") else current_path.rstrip("/") + "/" + target

		var full_path = BASE_PATH + new_path
		if DirAccess.dir_exists_absolute(full_path):
			current_path = new_path
		else:
			output = "No existe el directorio: " + target

	elif command == "ls":
		var full_path = get_full_path()
		var dir = DirAccess.open(full_path)
		if dir:
			var dirs = dir.get_directories()
			var files = dir.get_files()
			output = "  ".join(dirs + files)
		else:
			output = "No se pudo abrir el directorio."

		# Verificamos si se completa la misión 2
		if current_path == "/home/usuario1/Documents" and not mision2_completada:
			mision2_completada = true
			mision2_popup.visible = true

	elif command.begins_with("mkdir "):
		var target = command.substr(6).strip_edges()
		var path = get_full_path() + "/" + target
		if not DirAccess.dir_exists_absolute(path):
			var dir = DirAccess.open(get_full_path())
			if dir:
				dir.make_dir(target)
				output = "Directorio creado: " + target
		else:
			output = "El directorio ya existe."

	elif command.begins_with("touch "):
		var filename = command.substr(6).strip_edges()
		var file_path = get_full_path() + "/" + filename
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if file:
			output = "Archivo creado: " + filename
			file.close()
		else:
			output = "No se pudo crear el archivo."

	elif command.begins_with("nano "):
		var filename = command.substr(5).strip_edges()
		var file_path = get_full_path() + "/" + filename
		current_file_being_edited = file_path
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			editor.text = file.get_as_text()
			file.close()
		else:
			editor.text = ""
		nano_panel.visible = true
		history.release_focus()
		editor.grab_focus()
		output = "Editando " + filename + " (usa el botón para guardar y salir)"

	elif command.begins_with("rm "):
		var args = command.substr(3).strip_edges().split(" ")
		var target = args[0]
		var recursive = "-r" in args or "--recursive" in args
		var full_path = get_full_path() + "/" + target
		if DirAccess.dir_exists_absolute(full_path):
			if recursive:
				var dir = DirAccess.open(full_path)
				if dir:
					dir.remove(full_path)
					output = "Directorio eliminado: " + target
				else:
					output = "No se pudo eliminar el directorio: " + target
			else:
				output = "rm: no se puede eliminar '" + target + "': Es un directorio. Usa -r para eliminar recursivamente."
		elif FileAccess.file_exists(full_path):
			var file = FileAccess.open(full_path, FileAccess.READ)
			if file:
				file.close()
				DirAccess.remove_absolute(full_path)
				output = "Archivo eliminado: " + target
			else:
				output = "No se pudo eliminar el archivo: " + target
		else:
			output = "rm: no se puede eliminar '" + target + "': No existe tal archivo o directorio"

	elif command == "clear":
		history.text = ""
		show_prompt()
		return

	elif command == "help":
		output = "Comandos disponibles:\ncd [dir], ls, mkdir [nombre], touch [archivo], nano [archivo], rm [-r] [archivo/directorio], clear, help"

	elif command == "":
		pass
	else:
		output = "{command}: Comando no encontrado.".format({"command": command.split(" ")[0]})

	if output != "":
		history.append_text("\n" + output)

	show_prompt()

func _on_save_button_pressed():
	var file = FileAccess.open(current_file_being_edited, FileAccess.WRITE)
	if file:
		file.store_string(editor.text)
		file.close()
		nano_panel.visible = false
		history.append_text("\nArchivo guardado: " + current_file_being_edited)
		show_prompt()
