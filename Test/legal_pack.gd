extends SceneTree
## Run with the exported Linux binary, from outside the source project.
## Absolute --script is the probe; res:// resolves exclusively inside its PCK.
func _initialize() -> void:
	var expected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expected="):
			expected = arg.trim_prefix("--expected=")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expected))
	for name in ["privacy_zh", "privacy_en", "terms_zh", "terms_en"]:
		var doc: Resource = load("res://assets/legal/" + name + ".tres")
		assert(doc != null, "Missing bundled legal document: " + name)
		var body := String(doc.get("text"))
		assert(body.sha256_text() == manifest["text_sha256"][name], "Exported legal text differs: " + name)
		print("LEGAL PCK PASS ", name, " chars=", body.length())
	print("LEGAL PCK DONE 4/4")
	quit()
