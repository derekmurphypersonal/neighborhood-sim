extends SceneTree
## Lightweight in-repository test runner (D-031). No add-ons.
##
## Run from the repository root:
##   godot --headless --path game --script res://tests/run_tests.gd
## Optional: add "-- <text>" to run only test files whose name contains <text>.
##
## Finds every res://tests/test_*.gd except test_case.gd, runs each method
## whose name starts with "test_", prints a report, and exits with code 0 if
## everything passed or 1 otherwise.

const TESTS_DIR: String = "res://tests"


func _init() -> void:
	var name_filter: String = ""
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if user_args.size() > 0:
		name_filter = user_args[0]

	var files: Array[String] = []
	for file_name: String in DirAccess.get_files_at(TESTS_DIR):
		if file_name.begins_with("test_") and file_name.ends_with(".gd") and file_name != "test_case.gd":
			if name_filter == "" or file_name.contains(name_filter):
				files.append(file_name)
	files.sort()

	var total_tests: int = 0
	var total_checks: int = 0
	var failed_tests: int = 0
	var started_ms: int = Time.get_ticks_msec()

	for file_name: String in files:
		var script: GDScript = load(TESTS_DIR.path_join(file_name))
		if script == null or not script.can_instantiate():
			print("FAIL  %s could not be loaded (script error)" % file_name)
			total_tests += 1
			failed_tests += 1
			continue
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total_tests += 1
			var test: RefCounted = script.new()
			test.call(method_name)
			total_checks += test.get("checks")
			var failures: Array = test.get("failures")
			if failures.is_empty() and test.get("checks") > 0:
				print("ok    %s :: %s" % [file_name, method_name])
			else:
				failed_tests += 1
				print("FAIL  %s :: %s" % [file_name, method_name])
				if test.get("checks") == 0:
					print("        made no checks")
				for failure: String in failures:
					print("        " + failure)

	var elapsed_ms: int = Time.get_ticks_msec() - started_ms
	print("")
	print("%d tests, %d checks, %d failed, %d ms" % [total_tests, total_checks, failed_tests, elapsed_ms])
	if total_tests == 0:
		print("No tests were found.")
	quit(0 if failed_tests == 0 and total_tests > 0 else 1)
