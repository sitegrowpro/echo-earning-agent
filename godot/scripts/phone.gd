extends RefCounted
## Phone: Fears-to-Fathom signature system. Threads, timed scripts, replies.
## Data lives here; rendering lives in ui.gd.

var threads := {"millers": [], "priya": [], "unknown": []}
var active := "millers"
var visible := false
var unread := {"millers": 0, "priya": 0, "unknown": 0}
var audio
var ui
var story: RefCounted
var tree: SceneTree


func toggle(force := -1) -> bool:
	if force == -1:
		visible = not visible
	else:
		visible = force == 1
	if visible:
		unread[active] = 0
		ui.render_phone()
	ui.set_phone_visible(visible)
	return visible


func show(t: String) -> void:
	active = t
	unread[t] = 0
	ui.render_phone()


func set_replies(opts: Array) -> void:
	ui.set_replies(opts)


func clear_replies() -> void:
	ui.set_replies([])


func send(thread: String, text: String) -> void:
	(threads[thread] as Array).append({"text": text, "me": true})
	if visible and active == thread:
		ui.render_phone()


func sys(text: String) -> void:
	(threads[active] as Array).append({"text": text, "sys": true})
	if visible:
		ui.render_phone()


func incoming(thread: String, texts: Array, gap := 1.6, token := -1, on_done := Callable()) -> void:
	if thread == "unknown":
		ui.show_unknown_tab()
	for t in texts:
		await tree.create_timer(gap * randf_range(0.7, 1.3), false).timeout
		if token >= 0 and int(story.get("script_token")) != token:
			return
		(threads[thread] as Array).append({"text": t})
		audio.text_ding()
		if not visible or active != thread:
			unread[thread] = int(unread[thread]) + 1
			var who := "Mrs. Miller"
			if thread == "priya":
				who = "Priya"
			elif thread == "unknown":
				who = "Unknown number"
			story.call("toast", "✉ " + who)
			ui.render_phone_badges()
		else:
			ui.render_phone()
	if token >= 0 and int(story.get("script_token")) != token:
		return
	if on_done.is_valid():
		on_done.call()


func set_clock(s: String) -> void:
	ui.set_phone_clock(s)
