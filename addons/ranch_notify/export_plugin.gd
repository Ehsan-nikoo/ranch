## Puts the RanchNotify Android library (ranch_notify.aar, built by tools/android_notify/build.sh)
## into the Android export. Needs the Gradle build (export preset: gradle_build/use_gradle_build).
@tool
extends EditorPlugin

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = AndroidLibrary.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class AndroidLibrary extends EditorExportPlugin:
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["ranch_notify/ranch_notify.aar"])  # relative to res://addons/

	func _get_name() -> String:
		return "RanchNotify"
