extends SceneTree
## Headless smoke test of the Morse heart (the one fully pure, autoload-free
## system, so it can be exercised in isolation). Run:
##   godot --headless --script res://tests/selftest.gd
## Exit code is the number of failures (0 = OK). The wider systems are covered
## by booting the project headless (see docs/ROADMAP.md).

func _initialize() -> void:
	var ms: Node = load("res://src/autoload/morse_system.gd").new()
	ms._ready()  # build the decode table (no SceneTree needed)

	var fails := 0
	fails += _eq("encode CQ", ms.encode("CQ"), "-.-. --.-")
	fails += _eq("round-trip", ms.decode(ms.encode("SOS HELP")), "SOS HELP")
	fails += _ok("single dit timeline", ms.build_timeline("E", 12.0).size() == 1)
	fails += _ok("unknown token marked", ms.decode(".-.-.-.-.-").find("#") != -1)

	var steady: Dictionary = ms.simulate_send("CQ DE PARA", 1.0)
	var shaky: Dictionary = ms.simulate_send("CQ DE PARA", 0.1)
	fails += _eq("steady copy is clean", steady["text"], "CQ DE PARA")
	fails += _ok("steady fidelity high", steady["fidelity"] >= 0.8)
	fails += _ok("steady has duration", steady["duration"] > 0.0)
	fails += _ok("shaky no better than steady", shaky["fidelity"] <= steady["fidelity"])

	ms.free()
	if fails == 0:
		print("SELFTEST OK")
	else:
		print("SELFTEST FAILURES: %d" % fails)
	quit(fails)


func _eq(label: String, got: Variant, want: Variant) -> int:
	if str(got) == str(want):
		return 0
	print("FAIL %s: got '%s' want '%s'" % [label, got, want])
	return 1


func _ok(label: String, cond: bool) -> int:
	if cond:
		return 0
	print("FAIL %s" % label)
	return 1
