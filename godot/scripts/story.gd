extends RefCounted
## STORY — Episode 2: "THE HOUSESIT". Same Fears-to-Fathom skeleton as Episode 1
## (7 chapters, phone dread, knock, blackout, hunter, 3 escapes, 4 endings),
## with a brand-new story: Jamie, 17, housesitting for the Millers. One storm.
## One cat named Biscuit. And "Daniel", who says he's their son.

const CFG := preload("res://scripts/config.gd")
const WorldScript := preload("res://scripts/world.gd")

const NOTES := {
	"mail": {"title": "Letter — Hollow Creek HOA", "body": "NOTICE TO ALL RESIDENTS\n\nSeveral homeowners have reported a man standing at the edge of properties after dark. Just standing. Watching.\n\nHe leaves if you speak to him. He always comes back.\n\nKeep doors locked. Keep porch lights ON.\n\n— The Association"},
	"fridge": {"title": "HOUSE RULES — Dana", "body": "JAMIE!! Welcome!! Rules:\n\n1. Biscuit gets ONE scoop. He WILL lie to you.\n2. Lasagna's in the fridge, 3 min in the microwave. Eat like you mean it.\n3. Master bedroom door sticks — just leave it shut.\n4. Breaker box is in the laundry if the storm trips anything.\n5. !!! If ANYONE says they're our son — WE DON'T HAVE A SON. Call us IMMEDIATELY.\n\nHave fun!! — Dana :)"},
	"photo": {"title": "Framed photo (back)", "body": "In neat pen: \"Dana, Martin & Biscuit. Summer '23. Our perfect family.\"\n\nThe photo shows three figures on this very porch.\n\nAt the far edge of the frame there's a fourth shape. Tall. Blurred. Like someone who stepped in at the last second — or was cropped out."},
	"doodle": {"title": "Essay margin", "body": "College essay draft — \"Describe a place that shaped you.\" Half a page.\n\nIn the margin you've doodled the Millers' house. And by the fence, a tall figure with no face.\n\nYou don't remember drawing that."},
	"master": {"title": "Note on the master bed — Martin", "body": "D —\n\nCalled the locksmith AGAIN about the bedroom window latch. It DOESN'T lock. I've told you four times. Anyone could get in through there.\n\nWedge a chair under it until it's fixed. I'm serious this time.\n\n— M."},
	"bath": {"title": "Old sitter's emergency card", "body": "A laminated card, yellowed: \"SITTER EMERGENCY NUMBERS — the Millers.\"\n\nOn the back, in different handwriting, dated last spring:\n\n\"quit. not doing this house again. third night in a row he just STOOD in the yard watching the windows. dana laughed it off. i'm done. — K.\"\n\nP.S. — if he gets INSIDE: he ALWAYS checks the closets first. Watched him do it twice. Under the bed. TRUST me. — K.\""},
	"manual": {"title": "Breaker box manual", "body": "HOLLOW CREEK ELECTRIC — Model FB-3\n\n\"If all breakers trip at once, flip each switch LEFT then RIGHT, one at a time. Wait for the click.\n\nWARNING: simultaneous trips usually mean a surge... or manual interference at the meter.\"\n\nSomeone has circled \"manual interference\" in red."},
	"priya_note": {"title": "Note slipped under the door", "body": "In Priya's handwriting, shaky:\n\n\"jamie i drove by and there was a guy standing by the side of the house just STARING at the windows. i honked and he looked RIGHT at me and smiled. i'm going home. DO NOT open the door tonight. call me\"\n\nThe ink is smeared, like it was written fast."},
	"grocery": {"title": "Dana's grocery list (fridge)", "body": "FRESHMART RUN — please!! 🙏\n\n☐ Milk (2%!!)\n☐ Eggs\n☐ Bread\n☐ Biscuit's cat food (the EXPENSIVE one, he knows the difference)\n☐ AA batteries (storm!!)\n☐ Mint chip ice cream (for you, obviously)\n\nTake the $50 from the cookie jar. Keep the change, sweetie. — Dana"},
	"shed": {"title": "Clippings — the shed wall", "body": "Newspaper clippings, taped to the shed wall in neat rows.\n\n'HOLLOW CREEK FAMILY OF THREE SETTLES IN' ... 'MILLER REJOINS HOA BOARD' ... 'LOCAL TEEN WINS REGIONAL SPELLING BEE' — that one's about YOU, from two years ago.\n\nIn every photo of Dana, the eyes are scratched out. Not angrily. Carefully.\n\nOn the doorframe, a height chart in pencil. The top mark reads 6'4\".\n\nUnder it, one word: 'PATIENT.'"},
	"cellar": {"title": "Unsent letter — Martin", "body": "Dana —\n\nThird one this month. Same handwriting, same words: 'coming home soon.'\n\nWe never HAD a son. I burned the others. Don't show Jamie. Don't tell the HOA — they already think we're dramatic.\n\n— M.\n\nP.S. The height chart in the shed wasn't us."},
	"shrine": {"title": "Waterlogged prayer card", "body": "A prayer card, ink half-washed away: '...rest the soul of...' The name is scratched out. Deliberately. With something sharp.\n\nUnder the cross: candle stubs, a dead flashlight, and one child's mitten. The other is nowhere.\n\nOn the back, in pencil: 'I'M SORRY I LEFT.'"},
	"attic": {"title": "Nursery box — attic", "body": "A moving box labeled 'NURSERY' in marker that isn't Dana's looping hand or Martin's block print.\n\nInside: one folded baby blanket. A height chart torn from a doorframe — the top mark reads 6'4\".\n\nUnderneath, where no one was meant to look: a newer tag that just says 'MINE.'\n\nThe box smells like him. Rain and old pennies."},
	"garage": {"title": "Workbench list — Martin", "body": "On graph paper, in Martin's block print:\n\n- deadbolt (front) — DONE\n- window latches — locksmith AGAIN??\n- motion light, backyard — DONE\n- Dana's birthday — DON'T FORGET THIS TIME\n- ask police about extra patrols??\n\nThe last line is underlined three times."},
	"flyer": {"title": "Missing-person flyer (FreshMart board)", "body": "Sun-bleached, corners curling: 'MISSING — HAVE YOU SEEN THIS BOY?'\n\nThe photo is ten years of sun and rain. The name is smeared past reading.\n\nSomeone has written under it in fresh marker: 'HE'S NOT MISSING. HE'S WAITING.'\n\nThe handwriting makes your stomach drop. You've seen it before. On the shed wall."},
}

const CHAPTERS := [
	{"kicker": "7:48 PM", "name": "Arrival", "sub": "One night. One cat. What could go wrong?"},
	{"kicker": "8:15 PM", "name": "Chores", "sub": "Biscuit gets ONE scoop."},
	{"kicker": "9:10 PM", "name": "Dinner & Static", "sub": "Something on the news. Something outside."},
	{"kicker": "10:05 PM", "name": "Knock Knock", "sub": "\"I'm Daniel. The Millers' son.\""},
	{"kicker": "10:41 PM", "name": "Blackout", "sub": "The dark is full of sounds."},
	{"kicker": "11:12 PM", "name": "He's Inside", "sub": "Don't run. Don't breathe. Don't shine light."},
	{"kicker": "11:47 PM", "name": "Run", "sub": "Whatever you do — don't let him touch you."},
]

# R5: retrospective typewriter narration under each chapter card (spec §2.6).
const NARR := [
	"Looking back, the storm was already inside the house before I ever locked the door.",
	"Every chore felt normal. That is what I keep coming back to. It all felt normal.",
	"The lasagna was good. The news was bad. I should have left during the commercials.",
	"He knew my name before I ever said it. I still do not know how.",
	"Darkness has a sound. It is the sound of your own house, deciding.",
	"Under the bed, I counted his footsteps. I lost count at eleven.",
	"Three ways out. I only remember choosing one.",
]

var audio
var world
var enemy: CharacterBody3D
var player: CharacterBody3D
var root: Node3D
var tree: SceneTree
var ui
var phone: RefCounted

var chapter := -1
var flags := {}
var objectives: Array = []
var items := {}
var notes_found: Array = []
var choices: Array = []
var clock_min := 19.0 * 60.0 + 48.0
var start_msec := 0
var spotted := 0
var finished := false
var script_token := 0
var photosafe := false # R4: set by main.apply_settings; kills strobes
var nap_token := -1 # R4: guards the fade_swap nap callback
var micro := {"state": "idle", "t": 0.0}
var news_t := 0.0
var news_seg := 0
var police_t := -1.0
var police_light: OmniLight3D
var police_phase := 0.0
var stranger_out := false
var essay_pages := 0
var fuse_n := 0
var throw_cd := 0.0
var flicker_t := 0.0
var flicker_room := ""
var dialog_open := false
var note_open := false
var cam_open := false
var peep_open := false
var call_open := false
var story_open := false
var tick_on := false
var tick_t := 0.0
var tick_alt := false
var hide_warned := false
var flash_is_on := false
var _whisp_t := 0.0
var _rain2 := false
var market
var cat
var mic
var I
var pet_def := {}
var eggs: Array = []
var market_defs: Array = []
var cellar_defs: Array = []
var attic_defs: Array = []
var bolt_t := 12.0
var crow_t := 30.0
var mic_cool := 0.0
var mic_warned := false
var pa_t := 30.0


func setup(deps: Dictionary) -> void:
	audio = deps["audio"]
	world = deps["world"]
	enemy = deps["enemy"]
	player = deps["player"]
	root = deps["root"]
	tree = deps["tree"]
	ui = deps["ui"]
	phone = deps["phone"]
	market = deps["market"]
	cat = deps["cat"]
	mic = deps["mic"]


func reset_state() -> void:
	chapter = -1
	flags = {}
	objectives = []
	items = {"flash": false, "flash_on": false, "battery": 100.0, "batteries": 0, "master_key": false, "car_keys": false, "food": "", "trash": false}
	notes_found = []
	choices = []
	clock_min = 19.0 * 60.0 + 48.0
	start_msec = Time.get_ticks_msec()
	spotted = 0
	finished = false
	script_token = 0
	micro = {"state": "idle", "t": 0.0}
	news_t = 0.0
	news_seg = 0
	police_t = -1.0
	if police_light and is_instance_valid(police_light):
		police_light.queue_free()
	police_light = null
	police_phase = 0.0
	stranger_out = false
	essay_pages = 0
	fuse_n = 0
	throw_cd = 0.0
	flicker_t = 0.0
	flicker_room = ""
	dialog_open = false
	note_open = false
	cam_open = false
	peep_open = false
	call_open = false
	story_open = false
	hide_warned = false
	flash_is_on = false
	_whisp_t = 0.0
	_rain2 = false
	tick_on = true
	tick_t = 0.5
	tick_alt = false
	eggs = []
	bolt_t = 12.0
	crow_t = 30.0
	mic_cool = 0.0
	mic_warned = false
	pa_t = 30.0
	pet_def = {}
	if I:
		for id in market_defs:
			I.remove(id)
		for id in cellar_defs:
			I.remove(id)
		for id in attic_defs:
			I.remove(id)
	market_defs = []
	cellar_defs = []
	attic_defs = []


func ui_busy() -> bool:
	return dialog_open or note_open or peep_open or call_open or story_open or cam_open or finished


# ---------- helpers ----------
func toast(t: String) -> void:
	ui.toast(t)


func sub(t: String, dur := 4.0) -> void:
	ui.subtitle(t, dur)


func obj(id: String, text: String) -> void:
	for o in objectives:
		if o["id"] == id:
			return
	objectives.append({"id": id, "text": text, "done": false})
	render_obj()


func done(id: String) -> void:
	for o in objectives:
		if o["id"] == id and not bool(o["done"]):
			o["done"] = true
			audio.pickup()
			render_obj()
			toast("✓ " + String(o["text"]))
			check_advance()
			return


func is_done(id: String) -> bool:
	for o in objectives:
		if o["id"] == id:
			return bool(o["done"])
	return false


func render_obj() -> void:
	ui.objectives(objectives)


func say(sp: String, text: String, opts: Array) -> void:
	dialog_open = true
	player.set("frozen", true)
	player.set("fov_target", 52.0) # F2F talk-zoom: punch in on the speaker
	var wrapped: Array = []
	for o in opts:
		var cb: Callable = o["cb"]
		wrapped.append({"text": o["text"], "cb": func(): _close_say(cb)})
	ui.show_dialog(sp, text, wrapped)


func _close_say(cb: Callable) -> void:
	dialog_open = false
	player.set("frozen", false)
	player.set("fov_target", float(player.get("fov_base")))
	ui.close_dialog()
	cb.call()


func read_note(id: String) -> void:
	if not NOTES.has(id):
		return
	if not notes_found.has(id):
		notes_found.append(id)
		toast("📄 Note (%d/%d)" % [notes_found.size(), NOTES.size()])
	note_open = true
	player.set("frozen", true)
	player.set("fov_target", 52.0) # lean in to read
	audio.ui_click()
	ui.note_show(String(NOTES[id]["title"]), String(NOTES[id]["body"]))


func close_note() -> void:
	note_open = false
	player.set("frozen", false)
	player.set("fov_target", float(player.get("fov_base")))
	ui.note_close()


func _play_machine() -> void:
	if bool(flags.get("machine_played", false)):
		return
	flags["machine_played"] = true
	var t := script_token # R4: every beat guarded — quitting mid-tape must not sub the menu
	audio.microwave_beep(true)
	sub("ANSWERING MACHINE — message 1 of 2:", 3.0)
	await tree.create_timer(3.2, false).timeout
	if t != script_token or finished:
		audio.set_whisper(false)
		return
	sub("DANA (fond, fast): \"...jamie honey it's Dana, we're stuck at the airport, don't wait up! Milk's in the fridge, lasagna's in the freezer, 375 for 40 minutes, you remember! Love you, bye!\"", 7.0)
	await tree.create_timer(7.2, false).timeout
	if t != script_token or finished:
		audio.set_whisper(false)
		return
	audio.microwave_beep(true)
	sub("ANSWERING MACHINE — message 2 of 2:", 3.0)
	await tree.create_timer(3.2, false).timeout
	if t != script_token or finished:
		audio.set_whisper(false)
		return
	audio.set_whisper(true)
	sub("(breathing. slow. close to the receiver. and a smile you can hear: \"nice house.\")", 7.0)
	await tree.create_timer(7.2, false).timeout
	if t != script_token or finished:
		audio.set_whisper(false)
		return
	audio.set_whisper(false)
	audio.static_burst()
	sub("Click. End of messages.", 3.5)


func cam_show() -> void:
	cam_open = true
	player.set("frozen", true)
	audio.ui_click()
	ui.cam_show()


func cam_close() -> void:
	if not cam_open:
		return
	cam_open = false
	player.set("frozen", false)
	audio.ui_click()
	ui.cam_close()


func close_story() -> void:
	story_open = false
	ui.close_story()
	if not (dialog_open or note_open or peep_open or call_open or cam_open):
		player.set("frozen", false)


func clock_str() -> String:
	var h24 := int(clock_min / 60.0) % 24
	var m := int(clock_min) % 60
	var h := (h24 + 11) % 12 + 1
	var ap := "PM" if h24 >= 12 else "AM"
	return "%d:%02d %s" % [h, m, ap]


# ---------- game flow ----------
func new_game() -> void:
	reset_state()
	player.global_position = Vector3(0, 0, 7.4)
	player.call("set_look", 0.0, 0.0)
	goto_chapter(0)


func serialize() -> Dictionary:
	var dones: Array = []
	for o in objectives:
		if bool(o["done"]):
			dones.append(o["id"])
	return {
		"chapter": chapter, "flags": flags, "items": items, "notes_found": notes_found,
		"choices": choices, "clock_min": clock_min, "essay_pages": essay_pages,
		"eggs": eggs,
		"objectives_done": dones,
		"pos": [player.global_position.x, player.global_position.z],
		"yaw": float(player.get("yaw")),
	}


func load_data(s: Dictionary) -> void:
	reset_state()
	for k in (s.get("flags", {}) as Dictionary).keys():
		flags[k] = (s["flags"] as Dictionary)[k]
	for k in (s.get("items", {}) as Dictionary).keys():
		items[k] = (s["items"] as Dictionary)[k]
	notes_found = (s.get("notes_found", []) as Array).duplicate()
	choices = (s.get("choices", []) as Array).duplicate()
	eggs = (s.get("eggs", []) as Array).duplicate()
	clock_min = float(s.get("clock_min", clock_min))
	essay_pages = int(s.get("essay_pages", 0))
	var pos: Array = s.get("pos", [0.0, 7.4])
	if pos.size() < 2 or not ((pos[0] is float or pos[0] is int) and (pos[1] is float or pos[1] is int)):
		pos = [0.0, 7.4] # R4: corrupt saves land on the porch, they don't crash
	player.global_position = Vector3(float(pos[0]), 0.0, float(pos[1]))
	player.call("set_look", float(s.get("yaw", 0.0)), 0.0)
	goto_chapter(int(s.get("chapter", 0)))
	tick_on = chapter < 3
	for id in (s.get("objectives_done", []) as Array):
		for o in objectives:
			if o["id"] == id:
				o["done"] = true
	render_obj()


func goto_chapter(n: int) -> void:
	script_token += 1
	chapter = n
	var c: Dictionary = CHAPTERS[n]
	ui.chapter_card(String(c["kicker"]), "Chapter %d: %s" % [n, String(c["name"])], String(c["sub"]), NARR[clampi(n, 0, NARR.size() - 1)])
	objectives = []
	match n:
		0:
			_setup0()
		1:
			_setup1()
		2:
			_setup2()
		3:
			_setup3()
		4:
			_setup4()
		5:
			_setup5()
		6:
			_setup6()
	if n >= 3:
		audio.sting()
	render_obj()
	ui.autosave()


func check_advance() -> void:
	if chapter == 0 and is_done("lock"):
		goto_chapter(1)
	elif chapter == 1 and is_done("biscuit") and is_done("mail") and is_done("trash") and is_done("thermo") and is_done("essay"):
		if not bool(flags.get("market_trip", false)):
			_market_ask()
		elif is_done("market"):
			goto_chapter(2)
	elif chapter == 2 and is_done("dinner") and is_done("news") and is_done("priya") and is_done("woods"):
		goto_chapter(3)
	elif chapter == 3 and is_done("peep") and is_done("door") and is_done("millersreply") and is_done("attic"):
		goto_chapter(4)
	elif chapter == 4 and is_done("flash") and is_done("fuse") and is_done("cellar"):
		goto_chapter(5)
	elif chapter == 5 and is_done("key") and is_done("carkeys"):
		goto_chapter(6)


# ================= CHAPTER SETUPS =================
func _setup0() -> void:
	obj("lock", "Get inside and lock the front door")
	sub("Rain. A strange house. Mrs. Miller's spare key under the mat — right where she said.", 5.0)
	phone.call("incoming", "millers", [
		"Hi Jamie!! Thank you again for watching the house 🏠",
		"Biscuit gets ONE scoop, not two — he will lie to you",
		"Spare key's under the mat. Lock up behind you!! — Dana",
	], 1.6, script_token)
	_ch0_priya()


func _ch0_priya() -> void:
	var t := script_token
	await tree.create_timer(9.0, false).timeout
	if t != script_token:
		return
	phone.call("incoming", "priya", ["jamieeee u housesitting tonight??", "the millers place?? that house is CREEPY lol"], 1.6, t, func(): _ch0_replies())


func _ch0_replies() -> void:
	phone.call("set_replies", [
		{"text": "\"Come keep me company?\"", "cb": func(): _reply_priya_invite(true)},
		{"text": "\"Nah, I got Biscuit. 🐈\"", "cb": func(): _reply_priya_invite(false)},
	])


func _reply_priya_invite(yes: bool) -> void:
	phone.call("clear_replies")
	phone.call("send", "priya", "Come keep me company?" if yes else "Nah, I got Biscuit. 🐈")
	flags["invited_priya"] = yes
	choices.append("Invited Priya over" if yes else "Told Priya not to come")
	if yes:
		phone.call("incoming", "priya", ["omw after dinner!!", "bringing snacks AND my pepper spray. for the vibes 😭"], 1.6, script_token)
	else:
		phone.call("incoming", "priya", ["booo", "fineee. text me if the cat starts talking or whatever 😘"], 1.6, script_token)


func _setup1() -> void:
	obj("biscuit", "Feed Biscuit (ONE scoop — he will lie)")
	obj("mail", "Bring in the mail from the mailbox")
	obj("trash", "Take the trash out to the bin")
	obj("thermo", "Turn the thermostat down (it's roasting)")
	obj("essay", "Finish your college essay at the desk (3 pages)")
	if bool(flags.get("market_trip", false)) and not is_done("market"):
		obj("market", _market_obj_text())
	sub("The house ticks and settles. It always sounds bigger in the rain.", 5.0)
	_ch1_texts()


func _ch1_texts() -> void:
	var t := script_token
	await tree.create_timer(20.0, false).timeout
	if t != script_token:
		return
	phone.call("incoming", "millers", ["How's our favorite housesitter? 😊 Biscuit behaving?"], 1.6, t, func(): _ch1_after_msgs(t))


func _ch1_after_msgs(t: int) -> void:
	phone.call("set_replies", [
		{"text": "\"All good! He's an angel.\"", "cb": func(): _ch1_reply(true)},
		{"text": "\"He bit me. Twice.\"", "cb": func(): _ch1_reply(false)},
	])
	await tree.create_timer(25.0, false).timeout
	if t != script_token or chapter != 1:
		return
	call_millers()


func _ch1_reply(nice: bool) -> void:
	phone.call("clear_replies")
	if nice:
		phone.call("send", "millers", "All good! He's an angel.")
		phone.call("incoming", "millers", ["That's my boy!! Give him a chin scratch for me 🐈"], 1.6, script_token)
	else:
		phone.call("send", "millers", "He bit me. Twice.")
		phone.call("incoming", "millers", ["That's also my boy!! He loves you really 😅"], 1.6, script_token)


func call_millers() -> void:
	call_open = true
	player.set("frozen", true)
	audio.phone_buzz()
	ui.call_show("Dana Miller 📞",
		func(): _call_millers_end(true),
		func(): _call_millers_end(false))


func _call_millers_end(accepted: bool) -> void:
	call_open = false
	player.set("frozen", false)
	ui.call_close()
	if accepted:
		sub("DANA: \"Just checking on my favorite housesitter! Biscuit fed? Doors locked? ...Good. We land tomorrow. You're a lifesaver, Jamie.\"", 7.0)
	else:
		phone.call("incoming", "millers", ["Wow. Declining your housesitting clients. 😒", "Kidding!! Call if you need ANYTHING."], 1.6, script_token)


func _setup2() -> void:
	obj("dinner", "Heat the lasagna and eat it on the couch")
	obj("news", "Watch TV until the news is over")
	obj("priya", "Reply to Priya")
	obj("woods", "Get some air past the north-fence gate")
	sub("Your stomach growls. The fridge hums. Outside, the storm gets louder.", 5.0)
	sub("The house feels small tonight. The gate in the NORTH fence hangs open — five minutes of cold air.", 5.0)
	_ch2_texts()


func _ch2_texts() -> void:
	var t := script_token
	await tree.create_timer(15.0, false).timeout
	if t != script_token:
		return
	if bool(flags.get("invited_priya", false)):
		flags["invited_priya"] = false
		flags["priya_bailed"] = true
		phone.call("incoming", "priya", ["jamie its POURING", "mom wont let me drive in this 😭", "tomorrow for sure, promise"], 1.6, t, func(): _ch2_after_msgs())
	else:
		phone.call("incoming", "priya", ["btw have you seen the news??", "theres some creep going around hollow creek", "prob fake but lock ur doors lol"], 1.6, t, func(): _ch2_after_msgs())


func _ch2_after_msgs() -> void:
	phone.call("set_replies", [
		{"text": "\"lol it's just rain. chill.\"", "cb": func(): _ch2_reply(false)},
		{"text": "\"Wait, what?? Tell me.\"", "cb": func(): _ch2_reply(true)},
	])
	toast("✉ Priya is waiting for a reply — TAB to open your phone.")
	phone.call("incoming", "millers", ["Storm's getting nasty — if the power flickers, the breaker box is in the laundry. You've got this. 💛"], 1.6, script_token)


func _ch2_reply(worried: bool) -> void:
	phone.call("clear_replies")
	if worried:
		phone.call("send", "priya", "Wait, what?? Tell me.")
		phone.call("incoming", "priya", ["some tall guy just STANDS in peoples yards at night", "cops got like 5 calls. he never does anything tho. just watches 👀"], 1.6, script_token)
	else:
		phone.call("send", "priya", "lol it's just rain. chill.")
		phone.call("incoming", "priya", ["if u die in a horror movie im saying i told u so"], 1.6, script_token)
	done("priya")


func _setup3() -> void:
	obj("peep", "Look through the peephole")
	obj("door", "Deal with whoever is at the door (DO NOT OPEN IT)")
	obj("millersreply", "Reply to Mrs. Miller")
	if bool(flags.get("stranger_gone", false)):
		obj("attic", "Search the ATTIC for proof he's lying (laundry ladder?)")
	_ch3_seq()


func _ch3_seq() -> void:
	var t := script_token
	await tree.create_timer(9.0, false).timeout
	if t != script_token:
		return
	audio.stop_rain()
	world.set_rain(false)
	audio.set_hum(false)
	sub("The rain stops. The house goes very, very quiet.", 4.0)
	await tree.create_timer(5.0, false).timeout
	if t != script_token:
		return
	_knock_sequence()


func _knock_sequence() -> void:
	var t := script_token
	# The clock stops dead. A breath of true silence. Then the knock.
	tick_on = false
	flags["clock_dead"] = true
	sub("The clock stops ticking.", 3.0)
	await tree.create_timer(1.6, false).timeout
	if t != script_token:
		return
	audio.scare_duck() # R5: half a beat of wrong silence before the knock
	audio.knock_at(Vector3(0, 1.5, 5.5), "soft3")
	enemy.call("perch", WorldScript.PERCHES["porch"])
	stranger_out = true
	sub("Knocking. Three slow knocks. Nobody visits at 10 PM in a storm.", 5.0)
	toast("🚪 Someone is at the front door")
	await tree.create_timer(20.0, false).timeout
	if t != script_token:
		return
	if not is_done("peep"):
		audio.knock_at(Vector3(0, 1.5, 5.5), "heavy3")
		sub("Again. Heavier this time.", 4.0)
	await tree.create_timer(25.0, false).timeout
	if t != script_token:
		return
	if not is_done("door") and not bool(flags.get("talking", false)):
		flags["talking"] = true
		audio.knock_at(Vector3(0, 1.5, 5.5), "heavy2")
		audio.voice("daniel_01")
		say("??? (through the door)", "\"...hey. Hey. I'm Daniel — the Millers' son. Locked myself out like an idiot. Can you let me in? It'll just take a second.\"", _daniel_opts())


func talk_through_door() -> void:
	if bool(flags.get("talking", false)) or is_done("door"):
		return
	flags["talking"] = true
	audio.voice("daniel_01")
	say("??? (through the door)", "\"...hey. Hey. I'm Daniel — the Millers' son. Locked myself out like an idiot. Can you let me in? It'll just take a second.\"", _daniel_opts())


func _daniel_opts() -> Array:
	var opts := [
		{"text": "\"The Millers don't HAVE a son. Leave.\"", "cb": func(): stranger_talk("lie")},
		{"text": "\"...How do you know my name is Jamie?\"", "cb": func(): stranger_talk("ask")},
		{"text": "(Say nothing. Step away from the door.)", "cb": func(): stranger_talk("silent")},
	]
	if notes_found.has("fridge"):
		opts.append({"text": "(Text the MILLERS right now — like Dana's note said.)", "cb": func(): _warn_millers_ch3()})
	return opts


func _warn_millers_ch3() -> void:
	flags["millers_warned_ch3"] = true
	choices.append("Texted the Millers about Daniel (ch3)")
	phone.call("send", "millers", "SOMEONE IS AT THE DOOR SAYING HES YOUR SON. Your note said text you!!")
	audio.knock_at(Vector3(0, 1.5, 5.5), "soft3")
	audio.voice("daniel_05")
	sub("\"...hello? You still there?\"", 4.0)
	phone.call("incoming", "millers", ["WHAT. Jamie we DON'T HAVE A SON.", "Do NOT open that door. Calling the neighbors NOW."], 1.4, script_token)
	after_stranger()


func stranger_talk(how: String) -> void:
	choices.append("Stranger talk: " + how)
	if how == "lie":
		enemy.set("aggression", int(enemy.get("aggression")) + 1)
		audio.voice("daniel_02")
		say("???", "\"...Dana always forgets me. Let me IN, Jamie.\"", [
			{"text": "(Back away. Say nothing more.)", "cb": func(): after_stranger()},
		])
	elif how == "ask":
		audio.knock_at(Vector3(0, 1.5, 5.5), "one")
		enemy.set("aggression", int(enemy.get("aggression")) + 1)
		audio.voice("daniel_03")
		say("???", "\"Dana talks about you all the time. Her favorite housesitter... Jamie.\"", [
			{"text": "(He knows your name. Back away.)", "cb": func(): after_stranger()},
		])
	else:
		audio.knock_at(Vector3(0, 1.5, 5.5), "soft3")
		audio.voice("daniel_04")
		sub("Silence. Then, very quietly: \"...okay. Okay. I'll come back later, then, Jamie.\"", 6.0)
		after_stranger()


func after_stranger() -> void:
	var t := script_token
	flags["talking"] = false
	done("door")
	enemy.call("vanish")
	stranger_out = false
	flags["stranger_gone"] = true
	obj("attic", "Search the ATTIC for proof he's lying (laundry ladder?)")
	await tree.create_timer(7.0, false).timeout
	if t != script_token:
		return
	audio.sting()
	phone.call("incoming", "millers", [
		"JAMIE. Look at this. NOW.",
		"📷 [photo attached: this house, from the street. A TALL FIGURE stands under the streetlamp, facing your window.]",
		"A neighbor just sent me this!!! There is a MAN outside the house",
		"And Jamie... WE DON'T HAVE A SON. Lock EVERYTHING. I'm calling the police.",
		"Martin says check the attic — if he lived here there'd be PROOF. Ladder's in the laundry.",
	], 1.4, t, func(): _after_stranger_msgs())


func _after_stranger_msgs() -> void:
	phone.call("set_replies", [
		{"text": "\"Someone knocked. I didn't open it.\"", "cb": func(): _ch3_reply(true)},
		{"text": "\"It's probably nothing, Mrs. Miller.\"", "cb": func(): _ch3_reply(false)},
	])
	flags["priya_note"] = true
	toast("📄 Something slides under the front door...")


func _ch3_reply(good: bool) -> void:
	phone.call("clear_replies")
	if good:
		phone.call("send", "millers", "Someone knocked. I didn't open it.")
		phone.call("incoming", "millers", ["GOOD. Stay away from the windows. Police are on the way."], 1.6, script_token)
	else:
		phone.call("send", "millers", "It's probably nothing, Mrs. Miller.")
		phone.call("incoming", "millers", ["JAMIE. This is NOT nothing. STAY AWAY FROM THE WINDOWS."], 1.6, script_token)
	done("millersreply")


func _ch4_reply(ask: bool) -> void:
	phone.call("clear_replies")
	if ask:
		phone.call("send", "unknown", "When will it be back on??")
		phone.call("incoming", "unknown", ["Estimated restoration: UNKNOWN.", "Do not call 911 about the outage. Do not go outside. Do not answer the door.", "Thank you for choosing Hollow Creek Electric. 💡"], 1.6, script_token)
	else:
		phone.call("send", "unknown", "Wrong number.")
		phone.call("incoming", "unknown", ["This is not a wrong number, Jamie."], 1.6, script_token)


func _setup4() -> void:
	obj("flash", "Find the flashlight (laundry shelf?)")
	obj("fuse", "Reset the breaker box — 3 breakers")
	if bool(items.get("flash", false)):
		done("flash")
	_ch4_seq()


func _ch4_seq() -> void:
	var t := script_token
	await tree.create_timer(6.0, false).timeout
	if t != script_token:
		return
	audio.power_down()
	world.set_power(false)
	audio.set_hum(false)
	sub("The lights die. The fridge sighs into silence. Only the storm's echo remains.", 5.0)
	toast("⚡ POWER OUT")
	phone.call("incoming", "millers", ["Power's out?? The furnace pilot probably died too — can you peek at the little window on it? Cellar, kitchen door. Don't touch anything, just look!"], 1.6, t)
	obj("cellar", "Check the furnace window in the cellar")
	phone.call("incoming", "unknown", ["Hollow Creek Electric: outage reported in your area. Crews dispatched. Reply STOP to end alerts."], 1.6, t)
	phone.call("set_replies", [
		{"text": "\"When will it be back on??\"", "cb": func(): _ch4_reply(true)},
		{"text": "\"Wrong number.\"", "cb": func(): _ch4_reply(false)},
	])
	audio.knock_at(Vector3(8.0, 1.5, 3.0), "one")
	await tree.create_timer(12.0, false).timeout
	if t != script_token:
		return
	phone.call("incoming", "unknown", ["the dark suits this house", "i cut the lights so i could see you better, jamie"], 2.5, t, func(): _ch4_after_msgs(t))


func _ch4_after_msgs(t: int) -> void:
	await tree.create_timer(8.0, false).timeout
	if t != script_token or chapter != 4:
		return
	call_open = true
	player.set("frozen", true)
	audio.phone_buzz()
	ui.call_show("Unknown number",
		func(): _unknown_call_end(true),
		func(): _unknown_call_end(false))


func _unknown_call_end(accepted: bool) -> void:
	call_open = false
	player.set("frozen", false)
	ui.call_close()
	if accepted:
		sub("...breathing. Slow. Close. Then a click. Then your own porch creak, through the phone.", 7.0)
		audio.sting()
		choices.append("Answered the unknown call")
	else:
		phone.call("incoming", "unknown", ["rude. ill just talk to you in person"], 1.6, script_token)
		choices.append("Declined the unknown call")


func _setup5() -> void:
	audio.set_drone(true)
	audio.set_tense(true)
	obj("key", "Find the master bedroom key (kitchen drawer?)")
	obj("carkeys", "Get the CAR KEYS from the master bedroom")
	_ch5_seq()


func _ch5_seq() -> void:
	var t := script_token
	await tree.create_timer(2.5, false).timeout
	if t != script_token:
		return
	audio.scare_duck()
	audio.glass_at(Vector3(1.5, 1.5, -5.5))
	sub("GLASS. From the back of the house. The master window — the one that never locked.", 6.0)
	toast("🪟 Something broke the back window")
	enemy.set("aggression", int(enemy.get("aggression")) + 1)
	await tree.create_timer(9.0, false).timeout
	if t != script_token:
		return
	enemy.set("visible", true)
	enemy.call("place", 2.5, -4.0, 0.0)
	enemy.set("wp", 0)
	enemy.set("state", "patrol")
	sub("Floorboards. Slow footsteps. He is INSIDE the house.", 6.0)
	toast("🔦 Turn OFF your flashlight. Crouch. Hide under the BED or in a CLOSET.")
	phone.call("incoming", "millers", ["My car keys are in the bedroom dresser. If ANYTHING happens, take the car and GO. Police are 10 minutes out. HIDE. I love you like my own, Jamie — PLEASE be safe."], 1.6, t)


func _setup6() -> void:
	obj("escA", "🏃 Unlock the front door & run to the NEIGHBOR'S porch")
	obj("escB", "🪟 Climb out the GUEST WINDOW & reach the STREET")
	obj("escC", "📞 Call 911 on your phone, then HIDE until police arrive")
	enemy.set("aggression", int(enemy.get("aggression")) + 1)
	enemy.set("speed_mul", 1.12)
	sub("Car keys in your fist. Three ways out. Pick one and COMMIT.", 6.0)
	phone.call("set_replies", [{"text": "📞 CALL 911 NOW", "cb": func(): call911()}])
	phone.call("show", "millers")
	toast("📞 Open your phone (TAB) to call 911 — or RUN.")


func call911() -> void:
	if chapter != 6 or police_t >= 0.0:
		return
	call_open = true
	player.set("frozen", true)
	audio.phone_buzz()
	ui.call_show("911",
		func(): _call911_end(true),
		func(): _call911_end(false))


func _call911_end(accepted: bool) -> void:
	call_open = false
	player.set("frozen", false)
	ui.call_close()
	if accepted:
		if bool(flags.get("millers_warned_ch3", false)):
			sub("911: \"Hollow Creek? We already have a car on your street — someone called ahead. Stay QUIET.\"", 7.0)
			audio.voice("op_01")
			police_t = 30.0
		else:
			sub("911: \"Stay on the line. Officers are en route. Hide somewhere with a LOCK — and stay QUIET.\"", 7.0)
			audio.voice("op_02")
			police_t = 0.0
		toast("🚔 Police incoming. HIDE and stay quiet.")
		choices.append("Called 911")
		phone.call("clear_replies")
	else:
		phone.call("set_replies", [{"text": "📞 CALL 911 NOW", "cb": func(): call911()}])


# ================= SUPERMARKET (Chapter 1 errand) =================
func _market_obj_text() -> String:
	if bool(flags.get("paid", false)):
		return "🛒 Head HOME with the groceries"
	if not bool(flags.get("in_market", false)):
		return "🛒 Walk to FreshMart (front door)"
	var n := (flags.get("groceries", []) as Array).size()
	if n >= 6:
		return "🛒 Pay at the checkout"
	return "🛒 Grab groceries (%d/6)" % n


func upd_obj(id: String, text: String) -> void:
	for o in objectives:
		if o["id"] == id:
			o["text"] = text
	render_obj()


func _egg_found(id: String, text: String) -> void:
	if eggs.has(id):
		return
	eggs.append(id)
	audio.pickup()
	toast("🥚 Easter egg (%d/%d): %s" % [eggs.size(), CFG.EGGS_TOTAL, text])
	choices.append("Easter egg: " + text)


func _market_ask() -> void:
	flags["market_trip"] = true
	flags["groceries"] = []
	flags["grocery_note"] = true
	obj("market", _market_obj_text())
	var t := script_token
	phone.call("incoming", "millers", [
		"Jamie you're DONE?? Already?? 🏆",
		"Okay okay ONE more tiny favor... storm's about to get BAD bad",
		"Could you run to FreshMart? List's on the fridge. $50's in the cookie jar!!",
	], 1.4, t, func(): _market_ask_replies())


func _market_ask_replies() -> void:
	phone.call("set_replies", [
		{"text": "\"On my way! 🛒\"", "cb": func(): _market_reply(true)},
		{"text": "\"Ugh, in THIS rain?\"", "cb": func(): _market_reply(false)},
	])
	toast("🛒 New errand: FreshMart. Check the list on the fridge!")


func _market_reply(eager: bool) -> void:
	phone.call("clear_replies")
	if eager:
		phone.call("send", "millers", "On my way! 🛒")
		phone.call("incoming", "millers", ["You're the BEST!! Get yourself a treat too 😘"], 1.6, script_token)
	else:
		phone.call("send", "millers", "Ugh, in THIS rain?")
		phone.call("incoming", "millers", ["I'll add $20 for pain and suffering 😘", "FINE print: suffering mandatory"], 1.6, script_token)
	toast("🚶 Head out the FRONT DOOR to FreshMart.")


func go_market() -> void:
	if chapter != 1 or not bool(flags.get("market_trip", false)) or is_done("market"):
		return
	if bool(flags.get("in_market", false)):
		return
	root.enter_market()


func _cellar_prompt() -> String:
	if chapter == 6:
		return "No time — RUN"
	var est := String(enemy.get("state"))
	if est == "chase" or est == "investigate":
		return "Not with HIM that close"
	return "Go down to the CELLAR"


func _cellar_use() -> void:
	if chapter == 6:
		return
	var est := String(enemy.get("state"))
	if est == "chase" or est == "investigate":
		audio.locked()
		sub("You hear him moving. Going down there now would corner you like a rat.", 4.0)
		return
	root.enter_cellar()


func cellar_enter() -> void:
	cellar_defs.append("c-exit")
	I.add({"id": "c-exit", "area": I.halo(Vector3(-120.0, 1.2, 9.8), 1.0),
		"prompt": func(_c): return "Climb back UPSTAIRS",
		"on_use": func(_c): root.exit_cellar()})
	cellar_defs.append("sw-cellar")
	_sw_def(I, "cellar", Vector3(-119.0, 1.35, 10.7), "Cellar")
	cellar_defs.append("note-cellar")
	_note_def(I, "cellar", Vector3(-130.5, 1.15, -8.5))
	cellar_defs.append("c-pack")
	I.add({"id": "c-pack", "area": I.halo(Vector3(-128.0, 1.0, -7.5), 0.6),
		"prompt": func(_c): return "Take the spare AA pack" if not bool(flags.get("pack", false)) else "",
		"on_use": func(_c): _pack_use()})
	cellar_defs.append("c-furnace")
	I.add({"id": "c-furnace", "area": I.halo(Vector3(-111.0, 1.0, -5.2), 0.9),
		"prompt": func(_c): return "Stare into the furnace window (hold)" if not eggs.has("furnace") else "The furnace ticks as it cools",
		"hold": func(_c): return 6.0 if not eggs.has("furnace") else 0.0,
		"on_use": func(_c): _furnace_stare()})
	if chapter == 4 and not is_done("cellar"):
		done("cellar")
	sub("Concrete, oil, and dust. The furnace ticks. The dark down here feels... occupied.", 5.0)


func cellar_exit() -> void:
	for id in cellar_defs:
		I.remove(id)
	cellar_defs = []


func _pack_use() -> void:
	if bool(flags.get("pack", false)):
		return
	flags["pack"] = true
	items["batteries"] = int(items.get("batteries", 0)) + 2
	audio.pickup()
	toast("🔋 Spare AAs pocketed (%d). Press F to hot-swap when the light dies." % int(items.get("batteries", 0)))


func _furnace_stare() -> void:
	if eggs.has("furnace"):
		return
	if flash_is_on:
		sub("The flashlight washes it out. Whatever's in there, it only shows in the dark.", 4.0)
		return
	audio.sting()
	world.spawn_glimpse(Vector3(-111.0, 1.0, -5.0), 1.0)
	_egg_found("furnace", "The Furnace Man")
	sub("For one second the inspection window isn't a window. It's an EYE. Then it's rust again.", 5.0)


func _attic_prompt() -> String:
	if chapter == 6:
		return "No time — RUN"
	var est := String(enemy.get("state"))
	if est == "chase" or est == "investigate":
		return "Not with HIM that close"
	return "Climb up to the ATTIC"


func _attic_use() -> void:
	if chapter == 6:
		return
	var est := String(enemy.get("state"))
	if est == "chase" or est == "investigate":
		audio.locked()
		sub("You hear him moving. The attic is a dead end with one ladder.", 4.0)
		return
	root.enter_attic()


func attic_enter() -> void:
	attic_defs.append("a-exit")
	I.add({"id": "a-exit", "area": I.halo(Vector3(0, 1.2, -119.2), 1.0),
		"prompt": func(_c): return "Climb back DOWN",
		"on_use": func(_c): root.exit_attic()})
	attic_defs.append("sw-attic")
	_sw_def(I, "attic", Vector3(0, 1.4, -123.6), "Attic")
	attic_defs.append("note-attic")
	_note_def(I, "attic", Vector3(-8.0, 1.0, -133.0))
	attic_defs.append("a-music")
	I.add({"id": "a-music", "area": I.halo(Vector3(7.5, 1.0, -131.0), 0.6),
		"prompt": func(_c): return "Wind the music box (hold)" if not eggs.has("musicbox") else "The music box sits silent",
		"hold": func(_c): return 5.0 if not eggs.has("musicbox") else 0.0,
		"on_use": func(_c): _music_use()})
	obj("attic", "Search the ATTIC for proof he's lying (laundry ladder?)")
	if chapter == 3 and not is_done("attic"):
		done("attic")
	sub("Heat, dust, and mothballs. Rain hammers the roof like fingers. Somebody small lived up here once. Or was supposed to.", 6.0)


func attic_exit() -> void:
	for id in attic_defs:
		I.remove(id)
	attic_defs = []


func _music_use() -> void:
	if eggs.has("musicbox"):
		return
	audio.musicbox()
	_egg_found("musicbox", "The Nursery Rhyme")
	sub("Eight notes. A lullaby you almost know. The cylinder keeps turning after the song ends. It should not do that.", 6.0)


func market_enter() -> void:
	pa_t = 25.0
	var taken: Array = flags.get("groceries", [])
	for id in (market.ITEMS as Dictionary).keys():
		if not taken.has(id):
			_market_item_def(id)
	market_defs.append("m-cashier")
	I.add({"id": "m-cashier", "area": I.halo(Vector3(127.5, 1.2, 6.6), 0.9),
		"prompt": func(_c): return _cashier_prompt(),
		"on_use": func(_c): _talk_cashier()})
	market_defs.append("m-exit")
	I.add({"id": "m-exit", "area": I.halo(Vector3(120.0, 1.4, 10.4), 1.1),
		"prompt": func(_c): return "Head HOME with the groceries" if bool(flags.get("paid", false)) else "EXIT (finish shopping first)",
		"on_use": func(_c): _market_exit_use()})
	market_defs.append("note-flyer")
	_note_def(I, "flyer", Vector3(118.0, 1.6, 10.5))
	if not bool(flags.get("keanu_done", false)):
		market.set_folks_home(false)
		market_defs.append("m-john")
		I.add({"id": "m-john", "area": I.halo(Vector3(122.5, 1.4, -7.2), 0.9),
			"prompt": func(_c): return "Talk to the man in the black suit",
			"on_use": func(_c): _talk_john()})
		market_defs.append("m-charlie")
		I.add({"id": "m-charlie", "area": I.halo(Vector3(121.2, 1.4, -6.9), 0.9),
			"prompt": func(_c): return "Talk to his friend",
			"on_use": func(_c): _talk_charlie()})
	sub("FreshMart. Bright, humming, aggressively normal. Dana's list burns in your pocket.", 5.0)
	toast("🛒 " + _market_obj_text())


func market_exit() -> void:
	for id in market_defs:
		I.remove(id)
	market_defs = []


func _market_item_def(id: String) -> void:
	var d: Dictionary = (market.ITEMS as Dictionary)[id]
	market_defs.append("m-item-" + id)
	I.add({"id": "m-item-" + id, "area": I.halo(d["pos"], 0.8),
		"prompt": func(_c): return "Take " + String((d["name"] as String).split(" (")[0]),
		"on_use": func(_c): _grab_item(id)})


func _grab_item(id: String) -> void:
	var taken: Array = flags.get("groceries", [])
	if taken.has(id):
		return
	taken.append(id)
	flags["groceries"] = taken
	audio.scan()
	market.take_item(id)
	I.remove("m-item-" + id)
	market_defs.erase("m-item-" + id)
	var d: Dictionary = (market.ITEMS as Dictionary)[id]
	toast("🛒 " + String(d["name"]))
	upd_obj("market", _market_obj_text())
	if taken.size() == 3 and not bool(flags.get("keanu_done", false)):
		sub("Two men by the dairy case. One in a black suit. They're... staring at the eggs?", 5.0)
		toast("👔 Maybe go say hi. Or don't. Your call.")
	elif taken.size() >= 6:
		sub("That's everything. Dot's waving you over like you've won something.", 4.0)
		toast("🧾 Pay at the CHECKOUT.")


func _cashier_prompt() -> String:
	if bool(flags.get("paid", false)):
		return "Dot (paid — head home!)"
	var n := (flags.get("groceries", []) as Array).size()
	if n < 6:
		return "Checkout (%d/6 — keep shopping)" % n
	return "Pay $47.83"


func _talk_cashier() -> void:
	if bool(flags.get("paid", false)):
		sub("DOT: \"Have a good night, hon! Careful out there — storm's turning mean.\"", 4.0)
		return
	var n := (flags.get("groceries", []) as Array).size()
	if n < 6:
		say("Dot · Cashier", "\"Hey, hon. That basket looks... partial. Dairy case is in the back — and if you see the bread guy? Tall. Suit. Doesn't blink. Anyway!\"", [
			{"text": "\"Thanks, Dot.\"", "cb": func(): pass},
		])
		return
	say("Dot · Cashier", "\"...and that's $47.83. ...Rough night out there, huh? Radio says the storm's got a name now. They only name the mean ones.\"", [
		{"text": "Pay $47.83 (keep the change)", "cb": func(): _market_pay()},
		{"text": "\"Seen a tall man hanging around?\"", "cb": func(): _market_ask_dot()},
	])


func _market_ask_dot() -> void:
	say("Dot · Cashier", "\"Hon, it's FreshMart at 9 PM. Everybody here looks like a cryptid.\" She winks. \"That'll be $47.83.\"", [
		{"text": "Pay $47.83", "cb": func(): _market_pay()},
	])


func _market_pay() -> void:
	flags["paid"] = true
	audio.cash()
	upd_obj("market", _market_obj_text())
	toast("🧾 Paid! $2.17 change. Big spender.")
	sub("DOT: \"Walk safe, hon! And if a tall fella offers you a ride — you run.\"", 5.0)
	if not bool(flags.get("keanu_done", false)):
		toast("👔 Those two by the dairy case are still there...")


func _market_exit_use() -> void:
	if not bool(flags.get("paid", false)):
		var n := (flags.get("groceries", []) as Array).size()
		if n < 6:
			sub("The doors sigh open. Rain hammers the parking lot. Nope — groceries first.", 4.0)
		else:
			sub("Dot clears her throat behind you. \"HON.\" Right. Pay first.", 4.0)
		return
	root.exit_market()


func _talk_charlie() -> void:
	if bool(flags.get("keanu_done", false)):
		return
	sub("CHARLIE: \"Ask John. He knows things. ...Mostly about dogs.\"", 4.0)
	_talk_john()


func _talk_john() -> void:
	if bool(flags.get("keanu_done", false)):
		return
	say("JOHN", "The man in the black suit turns. Calm eyes. Very still. Like the store's hum gets quieter around him.\n\n\"...Yes?\"", [
		{"text": "\"Nice suit. Big night?\"", "cb": func(): _john_2()},
		{"text": "(Back away slowly)", "cb": func(): _john_leave(false)},
	])


func _john_2() -> void:
	_egg_found("keanu", "Yeah... he's thinking he's back")
	say("CHARLIE", "The friend grabs John's sleeve.\n\n\"John. JOHN. Where is my dog, John?\"", [
		{"text": "\"...Everything okay, guys?\"", "cb": func(): _john_3()},
		{"text": "(Nod politely. Leave.)", "cb": func(): _john_leave(true)},
	])


func _john_3() -> void:
	say("JOHN", "\"Yeah.\" A long pause. The fluorescents buzz.\n\n\"...I'm thinking he's back.\"", [
		{"text": "\"Back from... where? The dairy aisle?\"", "cb": func(): _john_4()},
		{"text": "(Say nothing. Just stare.)", "cb": func(): _john_4()},
	])


func _john_4() -> void:
	say("CHARLIE", "\"Sorry. Wrong John.\" They both stare at you for one second too long — then walk out into the rain. Without buying anything.", [
		{"text": "(Watch them go.)", "cb": func(): _john_leave(true)},
	])


func _john_leave(keep: bool) -> void:
	flags["keanu_done"] = true
	market.folks_leave()
	I.remove("m-john")
	I.remove("m-charlie")
	market_defs.erase("m-john")
	market_defs.erase("m-charlie")
	if keep:
		sub("The automatic doors sigh shut behind them. The hum feels louder now.", 4.0)
		choices.append("Met John (probably not that John)")
	else:
		sub("You back away. John's eyes follow you all the way to the bread aisle.", 4.0)


# ================= EASTER EGG: VINYL =================
func _vinyl() -> void:
	if String(player.get("hidden")) != "":
		return
	if not world.power:
		sub("The turntable sits silent. No power. The record waits.", 4.0)
		return
	if not bool(flags.get("adapter", false)): # R5: the egg is a HUNT now
		sub("The record needs a 45 adapter. Martin would stash one with the dress clothes...", 5.0)
		return
	if bool(flags.get("vinyl_played", false)):
		sub("Side B. Still funky. Still nobody here to moonwalk for.", 3.0)
		return
	flags["vinyl_played"] = true
	audio.mj_groove()
	_egg_found("mj", "Smooth Criminal")
	sub("🎩 A single glittering glove tucked behind the records... You drop the needle — and MOONWALK across the rug. Hee-hee! ...Biscuit is judging you.", 7.0)


# ---------- per-frame ----------
func update(dt: float) -> void:
	clock_min += dt / 4.0
	throw_cd = maxf(0.0, throw_cd - dt)
	if tick_on and player.global_position.x < 60.0:
		tick_t -= dt
		if tick_t <= 0.0:
			tick_t = 1.0
			tick_alt = not tick_alt
			audio.tick_at(world.CLOCK_POS, tick_alt)
			world.clock_tick()
	var s := clock_str()
	ui.vhs(s)
	phone.call("set_clock", s)
	if cam_open and chapter >= 4 and not bool(flags.get("camegg", false)) and world.cam_idx < world.cam_labels.size() and String(world.cam_labels[world.cam_idx]).find("WOODS") >= 0:
		flags["camegg"] = true
		world.spawn_glimpse(Vector3(-3.2, 1.0, -31.5), 1.2)
		audio.sting()
		_egg_found("trailcam", "Smile for the camera")
	flash_is_on = bool(items.get("flash_on", false)) and bool(items.get("flash", false)) and float(items.get("battery", 0.0)) > 0.0
	if flash_is_on:
		items["battery"] = float(items["battery"]) - CFG.FLASH_DRAIN * dt
		if float(items["battery"]) <= 0.0:
			items["battery"] = 0.0
			items["flash_on"] = false
			flash_is_on = false
			toast("🔦 Battery dead. Find batteries (kitchen drawer).")
	if String(micro["state"]) == "running":
		micro["t"] = float(micro["t"]) - dt
		world.micro_light.visible = true
		world.micro_light.light_energy = 1.5 + sin(Time.get_ticks_msec() * 0.02) * 0.7
		if float(micro["t"]) <= 0.0:
			micro["state"] = "done"
			world.micro_light.visible = false
			audio.microwave_beep(true)
			player.set("noise", minf(100.0, float(player.get("noise")) + 25.0))
			toast("🔔 The microwave beeps. (That was LOUD.)")
	if chapter == 2 and world.tv_on and bool(player.get("sitting")) and not is_done("news"):
		news_t += dt
		var segs := [
			[2.0, "📺 \"...police are asking Hollow Creek residents to lock their doors tonight...\""],
			[45.0, "📺 \"...five separate calls about a tall figure standing in yards, watching homes...\""],
			[90.0, "📺 \"...officials say he leaves when approached. He has never— [STATIC] —he is never gone...\""],
		]
		if news_seg < segs.size() and news_t >= float(segs[news_seg][0]):
			sub(String(segs[news_seg][1]), 6.0)
			audio.static_burst()
			news_seg += 1
		if news_t >= CFG.NEWS_TIME:
			done("news")
			sub("📺 \"...we'll be right back after—\" The screen cuts to static. The house feels colder.", 6.0)
	if police_t >= 0.0 and not finished:
		police_t += dt
		if police_t > 120.0 and police_light == null:
			audio.siren()
			police_light = OmniLight3D.new()
			police_light.light_energy = 6.0
			police_light.omni_range = 30.0
			police_light.position = Vector3(0, 3, 10)
			root.add_child(police_light)
			sub("SIRENS. Red and blue wash the windows. Just a little longer—", 6.0)
		if police_light:
			police_phase += dt * 6.0
			police_light.light_color = Color(1, 0.13, 0.13) if sin(police_phase) > 0.0 else Color(0.13, 0.27, 1.0)
		if police_t >= CFG.POLICE_WAIT:
			sub("\"POLICE! SHOW ME YOUR HANDS— ...Clear! Kid? KID, YOU'RE SAFE NOW.\"", 7.0)
			finish("C")
	var est: String = String(enemy.get("state"))
	var hunted: bool = est == "chase" or est == "investigate"
	var pp: Vector3 = player.global_position
	var ep: Vector3 = enemy.global_position
	var near_hidden: bool = String(player.get("hidden")) != "" and Vector2(pp.x - ep.x, pp.z - ep.z).length() < 5.0 and est != "dormant" and est != "gone" and est != "perch"
	audio.set_heart(hunted or near_hidden, est == "chase")
	# R4: stalk layer — a low presence that swells as he closes in.
	var estalk := est == "patrol" or est == "investigate" or est == "search" or est == "chase"
	var edist := Vector2(pp.x - ep.x, pp.z - ep.z).length()
	audio.set_stalk(estalk and edist < 13.0 and pp.x < 60.0, clampf(1.0 - edist / 13.0, 0.0, 1.0))
	if flicker_t > 0.0 and flicker_room != "":
		flicker_t -= dt
		if world.room_lights.has(flicker_room):
			for l in ((world.room_lights[flicker_room] as Dictionary)["lights"] as Array):
				(l as OmniLight3D).visible = world.power and bool((world.room_lights[flicker_room] as Dictionary)["on"]) and randf() > 0.5
		if flicker_t <= 0.0:
			world.apply_lights()
	if near_hidden:
		_whisp_t += dt
		if _whisp_t > 9.0:
			_whisp_t = 0.0
			sub("Floorboards inches away. Breathing. \"...I can hear your little heart, Jamie...\"", 5.0)
	if chapter >= 5 and not _rain2:
		_rain2 = true
		world.set_rain(true)
		audio.start_rain()
	_mic_update(dt)
	_bolt_update(dt)
	_pa_update(dt)
	_crow_update(dt)
	if not world.power:
		audio.mj_stop()
	# The pet-Biscuit halo follows the cat around the house.
	if not pet_def.is_empty():
		var area := pet_def.get("area") as Area3D
		if area and is_instance_valid(area) and cat:
			area.position = cat.head_pos() if not (bool(flags.get("in_market", false)) or bool(flags.get("in_cellar", false)) or bool(flags.get("in_attic", false))) else Vector3(0, -50, 0)


func _crow_update(dt: float) -> void:
	if finished or chapter < 2:
		return
	var lr := String(root.get("last_room"))
	if lr != "woods" and lr != "backyard":
		return
	crow_t -= dt
	if crow_t <= 0.0:
		crow_t = randf_range(25.0, 60.0)
		audio.crow_at(player.global_position + Vector3(randf_range(-8.0, 8.0), 3.0, randf_range(-8.0, 8.0)))


func _pa_update(dt: float) -> void:
	if not bool(flags.get("in_market", false)) or finished:
		return
	pa_t -= dt
	if pa_t <= 0.0:
		pa_t = randf_range(40.0, 70.0)
		audio.pa()
		var lines := ["📢 \"...cleanup on aisle three...\"", "📢 \"...will the owner of the black sedan please...\"", "📢 \"...FreshMart reminder: the storm is outside. You are inside. Stay inside...\""]
		sub(lines[randi() % lines.size()], 4.0)


func _bolt_update(dt: float) -> void:
	if finished or bool(flags.get("in_market", false)) or bool(flags.get("in_cellar", false)) or bool(flags.get("in_attic", false)):
		return
	if chapter == 0 or chapter == 3:
		return
	bolt_t -= dt
	if bolt_t <= 0.0:
		bolt_t = randf_range(9.0, 22.0)
		if chapter == 4 or chapter >= 5:
			bolt_t *= 0.6
		root.flash_lightning()


func _mic_update(dt: float) -> void:
	mic_cool = maxf(0.0, mic_cool - dt)
	if finished or not mic.enabled or mic.muted or not mic.available:
		return
	if bool(flags.get("in_market", false)) or bool(flags.get("in_cellar", false)) or bool(flags.get("in_attic", false)):
		mic.consume_heard()
		return
	if not mic.consume_heard():
		return
	if mic_cool > 0.0:
		return
	mic_cool = CFG.MIC_COOL
	var est := String(enemy.get("state"))
	if String(player.get("hidden")) != "" and (est == "chase" or est == "investigate" or est == "patrol" or est == "search"):
		enemy.call("yank_to_hiding", player)
		audio.sting()
		ui.flash()
		sub("👂 HE HEARD YOU. Stay QUIET — or RUN.", 4.0)
		spotted += 1
	elif est == "patrol" or est == "investigate" or est == "search":
		enemy.call("hear_at", player.global_position)
		sub("👂 He heard that...", 3.0)
	elif est == "dormant" or est == "perch" or est == "gone":
		if chapter >= 3 and not mic_warned and String(player.get("hidden")) != "":
			mic_warned = true
			sub("🎙 Careful — with the mic on, noise travels. (M to mute.)", 4.0)


func on_room(room: String) -> void:
	ui.room_toast(world.room_name(room))
	if room == "bath" and chapter == 4 and not bool(flags.get("mirror", false)):
		flags["mirror"] = true
		flicker("bath", 2.5)
		audio.sting()
		sub("On the fogged mirror, finger-written from the INSIDE of the glass: \"HE KNOWS YOUR NAME.\"", 7.0)
	if room == "master" and chapter >= 5 and not bool(flags.get("master_enter", false)):
		flags["master_enter"] = true
		sub("The back window gapes open. Glass on the carpet. Curtains breathing in the wind.", 6.0)
	if room == "woods" and not bool(flags.get("woods_enter", false)):
		flags["woods_enter"] = true
		sub("Pine needles underfoot. The streetlights don't reach back here. Someone burnt candles at that cross — recently.", 6.0)
	if room == "woods" and chapter == 2 and not is_done("woods"):
		done("woods")
	if room == "yard" and chapter == 6 and not bool(flags.get("yard_run", false)):
		flags["yard_run"] = true
		world.spawn_glimpse(Vector3(-8.0, 1.2, 12.0), 0.8)
		audio.sting()
		sub("Between the houses — standing — GONE. Don't stop. DON'T STOP.", 4.0)
	if room == "hall" and chapter == 5 and not bool(flags.get("hall5", false)):
		flags["hall5"] = true
		world.spawn_glimpse(Vector3(0.0, 1.2, -4.0), 0.7)
		audio.sting()
		sub("At the end of the hall — tall — GONE. He was never there. Keep telling yourself that.", 5.0)
	if room == "laundry" and chapter == 5 and not bool(flags.get("laun5", false)):
		flags["laun5"] = true
		audio.knock_at(Vector3(7.8, 1.5, -2.6), "one")
		sub("One slow knock from inside the wall by the breaker box. Then nothing.", 5.0)
	if room == "garage" and chapter == 4 and not bool(flags.get("gar4", false)):
		flags["gar4"] = true
		audio.sting()
		sub("The sedan's headlights flash once. The keys are in the house. The car is empty.", 5.0)
	# Dread director: the house gaslights you before he arrives. No cues, no
	# explanations — you simply find things wrong.
	if (room == "living" or room == "kitchen") and chapter == 1 and not bool(flags.get("dread_e1", false)):
		flags["dread_e1"] = true
		var ld = world.doors.get("laundry")
		if ld != null and not bool(ld.get("is_open")):
			ld.call("toggle") # started the night shut; now it stands open
	if room == "living" and chapter == 2 and not bool(flags.get("dread_e2", false)):
		flags["dread_e2"] = true
		if world.porch_on:
			world.porch_on = false
			world.apply_lights()
			sub("The porch light is out. You definitely left that on.", 4.5)
	if room == "hall" and chapter == 4 and not bool(flags.get("dread_e4", false)):
		flags["dread_e4"] = true
		audio.knock_at(Vector3(1.4, 1.5, -2.2), "one")
		sub("A single knock. From inside the house. From behind you.", 4.5)
	if room == "hall" and chapter == 5 and not bool(flags.get("dread_e5", false)):
		flags["dread_e5"] = true
		world.spawn_glimpse(Vector3(-7.0, 0, -0.5), 0.3)
	if room == "yard" and chapter == 6 and not bool(flags.get("dread_e6", false)):
		flags["dread_e6"] = true
		world.spawn_glimpse(Vector3(8.0, 0, 11.5), 0.4)
	if room == "garage" and not bool(flags.get("garage_seen", false)):
		flags["garage_seen"] = true
		sub("The Millers' garage. Oil, old rain, and a car that hasn't moved in weeks.", 5.0)
	if room == "backyard" and chapter >= 5 and not bool(flags.get("dread_yard", false)):
		flags["dread_yard"] = true
		world.spawn_glimpse(Vector3(-9.0, 0, -10.5), 0.5)
		sub("Between the shed slats — was that a face? No. Boards and shadow. Boards and shadow.", 6.0)


func flicker(room: String, dur: float) -> void:
	if photosafe:
		return # R4: room strobes are the #1 photosensitivity risk after lightning
	flicker_room = room
	flicker_t = dur


func closet_found() -> void:
	if finished or bool(flags.get("closet_doom", false)):
		return
	flags["closet_doom"] = true
	var t := script_token
	audio.scare_duck()
	audio.sting()
	ui.flash()
	sub("He stops. Turns. Walks straight toward your closet —", 2.5)
	enemy.call("yank_to_hiding", player)
	await tree.create_timer(1.4, false).timeout
	flags["closet_doom"] = false
	if t != script_token or finished:
		return
	var h := String(player.get("hidden"))
	if h == "closet" or h == "pcloset":
		ui.jumpscare(func(): finish("D", "He checked the closet first. The old sitter's note tried to warn you."))


func on_spotted() -> void:
	spotted += 1
	audio.scare_duck()
	audio.sting()
	ui.flash()
	sub("HE SEES YOU. R U N .", 3.0)


# ---------- doors ----------
func toggle_door(id: String) -> void:
	var d = world.doors.get(id)
	if d == null:
		return
	if id == "master" and bool(d.get("locked")):
		if bool(items.get("master_key", false)):
			d.set("locked", false)
			flags["master_open"] = true
			audio.pickup()
			toast("🔑 The key turns. The master bedroom sighs open...")
		else:
			audio.locked()
			d.jiggle()
			sub("Locked. The Millers' room. (Dana said the door sticks — the key must be around here somewhere...)", 4.0)
			return
	if id == "front":
		if chapter == 0 and not bool(flags.get("deadbolt", false)):
			if player.global_position.z > 5.5:
				if bool(d.get("is_open")):
					player.global_position = Vector3(clampf(player.global_position.x, -0.4, 0.4), 0.0, 4.9)
					player.call("set_look", 0.0, 0.0)
					audio.step_at(player.global_position, false)
				else:
					d.call("toggle")
					audio.door_creak(true)
				return
			d.set("is_open", false)
			d.set("target", 0.0)
			flags["deadbolt"] = true
			audio.door_shut_at(Vector3(0, 1.2, 5.5))
			done("lock")
			sub("Deadbolt ON. The strange house seals itself around you like a held breath.", 4.0)
			return
		if chapter == 1 and bool(flags.get("market_trip", false)) and not is_done("market"):
			go_market()
			return
		if chapter == 3 and stranger_out:
			if not is_done("door") and not bool(flags.get("talking", false)):
				talk_through_door()
				return
			if not is_done("door"):
				return
			say("Front door", "Your hand is on the deadbolt. He is RIGHT THERE on the other side.", [
				{"text": "OPEN THE DOOR.", "cb": func(): _open_door_death(d)},
				{"text": "(Step back. Keep it locked.)", "cb": func(): pass},
			])
			return
		if chapter == 6 and bool(flags.get("deadbolt", false)) and not bool(flags.get("deadbolt_off", false)) and not bool(d.get("is_open")):
			flags["deadbolt_off"] = true
			audio.door_shut_at(Vector3(0, 1.2, 5.5))
			player.set("noise", 100.0)
			toast("🔓 Deadbolt OFF. RUN TO THE NEIGHBOR'S PORCH.")
			sub("The deadbolt CLACKS. Behind you, something stands up very fast.", 4.0)
			enemy.call("place", 2.5, 7.2, PI)
			enemy.set("state", "investigate")
			enemy.set("target", Vector3(0, 0, 6))
			return
	d.call("toggle")
	if bool(d.get("is_open")):
		audio.door_creak(true)
	else:
		audio.door_creak(false)
	player.set("noise", minf(100.0, float(player.get("noise")) + 18.0))


func _open_door_death(d) -> void:
	d.set("is_open", true)
	d.set("target", float(d.get("swing")))
	audio.door_creak(true)
	ui.jumpscare(func(): finish("D", "You opened the door."))


# ---------- flashlight / hiding / sitting ----------
func toggle_flash() -> void:
	if not bool(items.get("flash", false)):
		toast("🔦 You don't have a flashlight yet.")
		return
	if float(items.get("battery", 0.0)) <= 0.0:
		if int(items.get("batteries", 0)) > 0:
			items["batteries"] = int(items.get("batteries", 0)) - 1
			items["battery"] = 100.0
			items["flash_on"] = true
			audio.pickup()
			toast("🔋 Swapped in spares — 100% (%d left)." % int(items.get("batteries", 0)))
			return
		toast("🔦 Battery dead — find batteries (kitchen drawer, cellar workbench).")
		return
	items["flash_on"] = not bool(items.get("flash_on", false))
	if bool(items.get("flash_on", false)) and String(player.get("hidden")) != "":
		toast("⚠️ Light ON while hiding = he WILL see you. Press F to kill it.")


func hide(where: String) -> void:
	if String(player.get("hidden")) == where:
		player.set("hidden", "")
		player.set("frozen", false)
		audio.door_creak(false)
		if where == "bed":
			player.global_position = Vector3(-6.4, 0, -3.0)
			player.call("set_look", -2.6, 0.0)
		elif where == "closet":
			player.global_position = Vector3(-3.6, 0, -2.0)
			player.call("set_look", 0.75, 0.0)
		elif where == "pcloset":
			player.global_position = Vector3(2.2, 0, -2.0)
			player.call("set_look", 0.67, 0.0)
		return
	player.set("hidden", where)
	player.set("frozen", true)
	var h: Dictionary = WorldScript.HIDE[where]
	player.call("look_at_spot", h["pos"], h["look"])
	audio.door_creak(true)
	ui.flash_hide("Under the bed. Don't move. Don't breathe." if where == "bed" else "Inside the closet. Darkness is your only friend.")
	if (where == "closet" or where == "pcloset") and chapter >= 5 and not bool(flags.get("closet_warned", false)):
		flags["closet_warned"] = true
		toast("⚠️ This closet feels exposed. He'd look here first.")
	if flash_is_on and not hide_warned:
		hide_warned = true
		toast("⚠️ YOUR FLASHLIGHT IS ON. Press F. NOW.")
	if mic and mic.enabled and not mic.muted and mic.available:
		toast("🎙 Mic is LIVE — stay QUIET or he hears you. (M to mute)")


func sit_toggle() -> void:
	if bool(player.get("sitting")):
		player.set("sitting", false)
		player.set("frozen", false)
		player.global_position = Vector3(-2, 0, 4.15)
		player.call("set_look", PI, 0.0)
	else:
		player.set("sitting", true)
		player.set("frozen", true)
		var h: Dictionary = WorldScript.HIDE["couch"]
		player.call("look_at_spot", h["pos"], h["look"])
		toast("📺 Sitting. Press E on the couch to stand.")


func throw_distraction() -> void:
	if finished or chapter < 0:
		return
	if bool(phone.get("visible")):
		return
	if String(player.get("hidden")) != "":
		toast("Not from in here.")
		return
	if throw_cd > 0.0:
		toast("Nothing left to throw. (%ds)" % int(ceil(throw_cd)))
		return
	throw_cd = 8.0
	var yaw: float = float(player.get("yaw"))
	var dir := Vector3(-sin(yaw), 0, -cos(yaw))
	var start: Vector3 = player.global_position + Vector3(0, 1.4, 0)
	var land: Vector3 = player.global_position + dir * 5.0
	var bmin: Vector2 = player.get("bounds_min")
	var bmax: Vector2 = player.get("bounds_max")
	land.x = clampf(land.x, bmin.x + 0.3, bmax.x - 0.3)
	land.z = clampf(land.z, bmin.y + 0.3, bmax.y - 0.3)
	land.y = 0.06
	var can: Node3D = world.box(0.09, 0.12, 0.09, world.mat(Color(0.7, 0.7, 0.72), 0.4, 0.6), start)
	var tw := tree.create_tween()
	tw.set_parallel(true)
	tw.tween_property(can, "position:x", land.x, 0.45)
	tw.tween_property(can, "position:z", land.z, 0.45)
	tw.tween_property(can, "rotation:x", 7.0, 0.45)
	tw.tween_property(can, "position:y", start.y + 0.6, 0.4)
	tw.set_parallel(false)
	tw.tween_property(can, "position:y", 0.06, 0.2)
	var t := script_token # R4: the can may land after a quit — guard the payoff
	tw.tween_callback(func(): _throw_land(can, land, t))


func _throw_land(can: Node3D, land: Vector3, t: int) -> void:
	if is_instance_valid(can):
		can.queue_free()
	if t != script_token or finished:
		return
	audio.clatter(land + Vector3(0, 0.3, 0))
	enemy.call("hear_at", land)
	toast("The can clatters down the hall.")


# ---------- peephole ----------
func peep() -> void:
	peep_open = true
	player.set("frozen", true)
	var html := ""
	if chapter == 3 and stranger_out:
		html = "A tall man. Too close to the door.\nHe is holding something long and dark.\nA crowbar? An umbrella?\n\nHe looks DIRECTLY at the peephole.\n\nHe smiles."
		audio.knock_at(Vector3(0, 1.5, 5.5), "one")
		choices.append("Looked through the peephole")
		_peep_voice()
	elif chapter >= 5:
		html = "Empty porch. Swinging bulb.\n...why is that comforting? He's not out there.\nHe's in here with you."
	elif chapter == 3 and not stranger_out and not is_done("door"):
		html = "Empty porch. Wet footprints lead AWAY...\nno. Toward the side of the house.\nToward the BACK windows."
	else:
		html = "Rain. The mailbox. The streetlamp buzzing.\nEverything normal. Everything fine."
	ui.peephole(html)
	if chapter == 3:
		done("peep")


func _peep_voice() -> void:
	var t := script_token
	await tree.create_timer(2.5, false).timeout
	if t == script_token and peep_open:
		sub("\"...I can see your little shadow under the door, Jamie.\"", 5.0)


func close_peep() -> void:
	peep_open = false
	player.set("frozen", false)
	ui.close_peephole()


# ---------- endings ----------
func finish(id: String, custom := "") -> void:
	if finished:
		return
	finished = true
	script_token += 1
	# R4: bury any open modal first — the ending must own the screen.
	dialog_open = false
	note_open = false
	peep_open = false
	call_open = false
	story_open = false
	cam_open = false
	ui.hide_modals()
	player.set("frozen", true)
	audio.set_heart(false)
	audio.set_stalk(false)
	audio.set_subbass(false)
	audio.set_tv(false)
	audio.set_drone(false)
	audio.set_tense(false)
	tick_on = false
	var mins := int((Time.get_ticks_msec() - start_msec) / 60000.0)
	var texts := {
		"A": ["You slam into the neighbor's porch screaming. Lights explode on up and down the street. Behind you, at the edge of the lawn, a tall figure STOPS — watches — and then simply... isn't there anymore.\n\nThe police find wet footprints through the MILLERS' house. All the way to the front door. Stopping where you stood.\n\nDana cries and hugs you for a full minute. You never housesit again.", "The police find no one. But every officer who walks that hallway goes quiet at the master window."],
		"B": ["Glass in your palms. Rain in your mouth. You hit the grass running and you do not look back — but you HEAR him, right behind the fence, matching you step for step, breathing like a man who has waited years for this.\n\nThen headlights. A car. A horn. And the breathing is gone.\n\nThe driver says you appeared out of nowhere, screaming. She says there was no one behind you.\n\nShe is wrong. You saw the streetlamp flicker as he stepped under it.", "You got out. That's more than the footprints in the yard suggest anyone else did."],
		"C": ["Under the guest bed, cheek to the carpet, phone glowing against your chest. Footsteps circle the room. Once, the closet door creaks. Once, something kneels — you see black shoes by the bed skirt — and breathes.\n\n\"...I can hear your little heart, Jamie...\"\n\nThen: SIRENS. Shouting. Running. A flashlight beam sweeps under the bed and finds your face.\n\n\"Kid? KID, YOU'RE SAFE NOW.\"\n\nThey never catch him. But they find his footprints. Under your window. In the hallway. Stopping, for a long time, beside your bed.", "You survived the night. The morning news calls it \"a break-in.\" You know better."],
		"D": [(custom + "\n\n" if custom != "" else "") + "A hand like winter closes over your mouth.\n\nThe last thing you hear is breathing, right against your ear, almost tender:\n\n\"...shhh...\"\n\n[ECHOES IN THE DARK — EPISODE 2: BAD END]", "He was always faster than you. Be smarter next time."],
	}
	var last_choices := "no choices made"
	if not choices.is_empty():
		last_choices = "choices: " + " · ".join(choices.slice(maxi(0, choices.size() - 4)))
	ui.show_ending(id, String(texts[id][0]), String(texts[id][1]),
		"⏱ %d min · 👁 spotted %d× · 📄 notes %d/%d · 🥚 eggs %d/%d · %s" % [mins, spotted, notes_found.size(), NOTES.size(), eggs.size(), CFG.EGGS_TOTAL, last_choices])


# ================= INTERACTABLES =================
func _door_prompt(id: String, label: String) -> String:
	var d = world.doors.get(id)
	if id == "front" and chapter == 0 and not bool(flags.get("deadbolt", false)):
		if player.global_position.z > 5.5:
			return "Open the front door" if not bool(d.get("is_open")) else "Get inside"
		return "Lock the front door"
	if id == "front" and chapter == 1 and bool(flags.get("market_trip", false)) and not is_done("market"):
		return "🚶 Walk to FreshMart"
	if id == "front" and chapter == 3 and stranger_out and not is_done("door"):
		return "Speak through the door"
	if id == "front" and chapter == 3 and stranger_out:
		return "Front door (he is RIGHT THERE)"
	if id == "front" and chapter == 6 and bool(flags.get("deadbolt", false)) and not bool(flags.get("deadbolt_off", false)):
		return "Throw the deadbolt & RUN"
	if id == "master" and bool(d.get("locked")) and not bool(items.get("master_key", false)):
		return "Master bedroom door (locked)"
	if id == "master" and bool(d.get("locked")) and bool(items.get("master_key", false)):
		return "Unlock with key"
	return ("Close " if bool(d.get("is_open")) else "Open ") + label


func _door_def(inter, id: String, x: float, z: float, label: String) -> void:
	inter.add({"id": "door-" + id, "area": inter.halo(Vector3(x, 1.2, z), 0.7),
		"prompt": func(_c): return _door_prompt(id, label),
		"on_use": func(_c): toggle_door(id)})


func _note_def(inter, id: String, pos: Vector3, flag: String = "") -> void:
	inter.add({"id": "note-" + id, "area": inter.halo(pos, 0.55),
		"prompt": func(_c): return "" if (flag != "" and not bool(flags.get(flag, false))) or note_open else "Read",
		"on_use": func(_c): read_note(id)})


func _sw_def(inter, room: String, pos: Vector3, label: String) -> void:
	inter.add({"id": "sw-" + room, "area": inter.halo(pos, 0.32),
		"prompt": func(_c): return _sw_prompt(room, label),
		"on_use": func(_c): _sw_use(room)})


func _sw_prompt(room: String, label: String) -> String:
	if not world.power:
		return label + " light (no power)"
	return label + " light (" + ("on" if bool((world.room_lights[room] as Dictionary)["on"]) else "off") + ")"


func _sw_use(room: String) -> void:
	if not world.power:
		audio.locked()
		return
	world.set_room_light(room, not bool((world.room_lights[room] as Dictionary)["on"]))
	audio.ui_click()


func _switch_prompt(room: String, label: String) -> String:
	var on := bool(world.porch_on) if room == "porch" else bool((world.room_lights[room] as Dictionary)["on"])
	return "Turn the %s light off" % label if on else "Turn the %s light on" % label


func _switch_use(room: String, label: String) -> void:
	audio.ui_click()
	if room == "porch":
		world.porch_on = not world.porch_on
	else:
		(world.room_lights[room] as Dictionary)["on"] = not bool((world.room_lights[room] as Dictionary)["on"])
	world.apply_lights()
	var on2 := bool(world.porch_on) if room == "porch" else bool((world.room_lights[room] as Dictionary)["on"])
	toast("💡 %s %s." % [label.capitalize(), "lit" if on2 else "dark"])


func _switch_def(inter, id: String, room: String, pos: Vector3, label: String) -> void:
	inter.add({"id": id, "area": inter.halo(pos, 0.45),
		"prompt": func(_c): return _switch_prompt(room, label),
		"on_use": func(_c): _switch_use(room, label)})


func _shower() -> void:
	if bool(flags.get("showered", false)):
		return
	flags["showered"] = true
	var t := script_token # R4: quitting mid-shower must not unfreeze/flow onto the menu
	player.set("frozen", true)
	audio.set_shower(true)
	sub("Hot water. Steam. For a minute the night can't touch you.", 5.0)
	await tree.create_timer(6.0, false).timeout
	audio.set_shower(false)
	if t != script_token or finished:
		return
	clock_min += 30.0
	player.set("frozen", false)
	choices.append("Took a hot shower")
	toast("🚿 That helped more than you expected. (%s)" % clock_str())


func _nap() -> void:
	if bool(flags.get("napped", false)):
		return
	flags["napped"] = true
	nap_token = script_token
	player.set("frozen", true)
	ui.fade_swap(func(): _nap_wake(), 0.9)


func _nap_wake() -> void:
	if nap_token != script_token or finished:
		return # R4: stale fade callback — never wake onto a menu/ending
	clock_min += 30.0
	player.set("frozen", false)
	choices.append("Napped on the guest bed")
	sub("You surface from a dream about teeth and doorbells. %s already." % clock_str(), 5.0)


func register(inter) -> void:
	_door_def(inter, "front", 0.0, 5.5, "front door")
	_door_def(inter, "guest", -5.5, -1.5, "guest room door")
	_door_def(inter, "master", 1.5, -1.5, "master bedroom door")
	_door_def(inter, "bath", 5.2, -1.5, "bathroom door")
	_door_def(inter, "laundry", 7.25, -1.5, "laundry door")
	_door_def(inter, "garage", 8.0, -0.5, "garage door")
	_door_def(inter, "shed", -9.5, -10.0, "shed door")
	inter.add({"id": "cams", "area": inter.halo(Vector3(-3.5, 1.1, -1.1), 0.7),
		"prompt": func(_c): return "Check security cameras",
		"on_use": func(_c): cam_show()})
	inter.add({"id": "machine", "area": inter.halo(Vector3(-2.55, 0.6, 0.85), 0.9),
		"prompt": func(_c): return "Play answering machine" if not bool(flags.get("machine_played", false)) else "",
		"on_use": func(_c): _play_machine()})
	inter.add({"id": "peephole", "area": inter.halo(Vector3(0, 1.6, 5.3), 0.4),
		"prompt": func(c): return "Look through peephole" if (c["player"] as CharacterBody3D).global_position.z < 5.4 else "",
		"on_use": func(_c): peep()})
	inter.add({"id": "biscuit", "area": inter.halo(Vector3(6.4, 0.4, 4.9), 0.6),
		"prompt": func(_c): return "Feed Biscuit (ONE scoop)" if chapter == 1 and not is_done("biscuit") else "",
		"hold": func(_c): return 3.0,
		"on_use": func(_c): _feed_biscuit()})
	inter.add({"id": "mailtake", "area": inter.halo(Vector3(2.2, 1.25, 9.0), 0.6),
		"prompt": func(_c): return "Take the mail" if chapter == 1 and not bool(flags.get("mail_taken", false)) else "",
		"on_use": func(_c): _take_mail()})
	inter.add({"id": "trashbag", "area": inter.halo(Vector3(4.9, 0.5, 2.6), 0.6),
		"prompt": func(_c): return "Grab the trash bag" if chapter == 1 and not is_done("trash") and not bool(items.get("trash", false)) else "",
		"on_use": func(_c): _take_trash()})
	inter.add({"id": "trashbin", "area": inter.halo(Vector3(-2.6, 0.8, 6.3), 0.8),
		"prompt": func(_c): return "Dump the trash" if bool(items.get("trash", false)) and not is_done("trash") else "",
		"on_use": func(_c): _dump_trash()})
	inter.add({"id": "thermo", "area": inter.halo(Vector3(-1, 1.5, -1.3), 0.4),
		"prompt": func(_c): return "Turn thermostat down (78°?!)" if chapter == 1 and not is_done("thermo") else "Thermostat (72° — perfect)",
		"on_use": func(_c): _thermo()})
	inter.add({"id": "essay", "area": inter.halo(Vector3(-3.0, 0.95, -5.0), 0.6),
		"prompt": func(_c): return "Write essay (page %d/3)" % (essay_pages + 1) if chapter == 1 and not is_done("essay") else "",
		"hold": func(_c): return CFG.HOMEWORK_HOLD,
		"on_use": func(_c): _essay_page()})
	inter.add({"id": "fridge", "area": inter.halo(Vector3(7.0, 1.2, 1.0), 0.7),
		"prompt": func(_c): return _fridge_prompt(),
		"on_use": func(_c): _fridge_use()})
	inter.add({"id": "micro", "area": inter.halo(Vector3(7.2, 1.25, 1.9), 0.6),
		"prompt": func(_c): return _micro_prompt(),
		"on_use": func(_c): _micro_use()})
	inter.add({"id": "tv", "area": inter.halo(Vector3(-2, 0.95, 1.0), 0.8),
		"prompt": func(_c): return "Turn TV off" if world.tv_on else "Turn TV on",
		"on_use": func(_c): _tv_use()})
	inter.add({"id": "couch", "area": inter.halo(Vector3(-2, 0.8, 3.3), 0.9),
		"prompt": func(_c): return _couch_prompt(),
		"hold": func(_c): return 3.0 if (bool(player.get("sitting")) and String(items.get("food", "")) == "hot") else 0.0,
		"on_use": func(_c): _couch_use()})
	inter.add({"id": "drawer", "area": inter.halo(Vector3(4.2, 0.75, 2.8), 0.6),
		"prompt": func(_c): return _drawer_prompt(),
		"on_use": func(_c): _drawer_use()})
	inter.add({"id": "cellardoor", "area": inter.halo(Vector3(6.1, 1.2, 1.5), 0.7),
		"prompt": func(_c): return _cellar_prompt(),
		"on_use": func(_c): _cellar_use()})
	inter.add({"id": "atticdoor", "area": inter.halo(Vector3(6.9, 1.2, -2.6), 0.7),
		"prompt": func(_c): return _attic_prompt(),
		"on_use": func(_c): _attic_use()})
	inter.add({"id": "flashlight", "area": inter.halo(Vector3(6.8, 1.25, -3.6), 0.6),
		"prompt": func(_c): return "Take the flashlight" if not bool(items.get("flash", false)) else "",
		"on_use": func(_c): _take_flash()})
	inter.add({"id": "fuse", "area": inter.halo(Vector3(7.8, 1.55, -2.6), 0.6),
		"prompt": func(_c): return "Reset breaker %d/3 (hold)" % (fuse_n + 1) if chapter == 4 and not is_done("fuse") else "Breaker box (humming normally)",
		"hold": func(_c): return 2.5 if chapter == 4 and not is_done("fuse") else 0.0,
		"on_use": func(_c): _fuse()})
	inter.add({"id": "hidebed", "area": inter.halo(Vector3(-6.4, 0.5, -3.3), 0.7),
		"prompt": func(_c): return "Crawl out" if String(player.get("hidden")) == "bed" else "Hide under the bed",
		"on_use": func(_c): hide("bed")})
	inter.add({"id": "hidecloset", "area": inter.halo(Vector3(-2.7, 1.2, -2.0), 0.7),
		"prompt": func(_c): return "Step out" if String(player.get("hidden")) == "closet" else "Hide in the closet",
		"on_use": func(_c): hide("closet")})
	inter.add({"id": "hidepcloset", "area": inter.halo(Vector3(3.2, 1.2, -2.0), 0.7),
		"prompt": func(_c): return "Step out" if String(player.get("hidden")) == "pcloset" else "Hide in the master closet",
		"on_use": func(_c): hide("pcloset")})
	inter.add({"id": "carkeys", "area": inter.halo(Vector3(3.3, 1.0, -5.1), 0.6),
		"prompt": func(_c): return "Take the CAR KEYS" if chapter >= 5 and not bool(items.get("car_keys", false)) else "",
		"on_use": func(_c): _take_carkeys()})
	inter.add({"id": "bedwindow", "area": inter.halo(Vector3(-5.5, 1.4, -5.35), 0.7),
		"prompt": func(_c): return "CLIMB OUT the window (hold)" if chapter >= 6 else "Guest window (Dana: NEVER open at night)",
		"hold": func(_c): return (1.5 if notes_found.has("master") else 3.0) if chapter >= 6 else 0.0,
		"on_use": func(_c): _climb_window()})
	inter.add({"id": "neighbordoor", "area": inter.halo(Vector3(-18.2, 1.3, 7.3), 1.2),
		"prompt": func(_c): return "BANG on the neighbor's door (hold)" if chapter == 6 else "",
		"hold": func(_c): return 1.5,
		"on_use": func(_c): _neighbor()})
	_note_def(inter, "mail", Vector3(2.2, 1.25, 9.0), "mail_taken")
	_note_def(inter, "fridge", Vector3(7.0, 1.55, 1.0))
	_note_def(inter, "photo", Vector3(-7.6, 0.95, 0.95))
	_note_def(inter, "doodle", Vector3(-2.7, 0.9, -5.1))
	_note_def(inter, "master", Vector3(0.6, 0.95, -4.2), "master_open")
	_switch_def(inter, "sw_living", "living", Vector3(0.65, 1.35, 5.3), "living room")
	_switch_def(inter, "sw_porch", "porch", Vector3(0.78, 1.35, 5.3), "porch")
	_switch_def(inter, "sw_kitchen", "kitchen", Vector3(0.91, 1.35, 5.3), "kitchen")
	_switch_def(inter, "sw_hall", "hall", Vector3(-4.9, 1.35, 0.3), "hallway")
	_switch_def(inter, "sw_guest", "guest", Vector3(-4.85, 1.35, -1.3), "guest room")
	_switch_def(inter, "sw_master", "master", Vector3(2.1, 1.35, -1.3), "master bedroom")
	_switch_def(inter, "sw_bath", "bath", Vector3(4.6, 1.35, -1.3), "bathroom")
	_switch_def(inter, "sw_laundry", "laundry", Vector3(6.67, 1.35, -1.3), "laundry")
	_switch_def(inter, "sw_garage", "garage", Vector3(7.85, 1.35, 0.2), "garage")
	inter.add({"id": "shower", "area": inter.halo(Vector3(4.6, 1.2, -4.5), 0.9),
		"prompt": func(_c): return "Take a quick shower" if chapter >= 1 and not bool(flags.get("showered", false)) else "",
		"hold": func(_c): return 2.5 if chapter >= 1 and not bool(flags.get("showered", false)) else 0.0,
		"on_use": func(_c): _shower()})
	inter.add({"id": "nap", "area": inter.halo(Vector3(-6.4, 0.9, -4.9), 0.6),
		"prompt": func(_c): return "Lie down for a bit" if (chapter == 1 or chapter == 2) and not bool(flags.get("napped", false)) else "",
		"hold": func(_c): return 2.0 if (chapter == 1 or chapter == 2) and not bool(flags.get("napped", false)) else 0.0,
		"on_use": func(_c): _nap()})
	_note_def(inter, "bath", Vector3(5.2, 1.1, -2.0))
	_note_def(inter, "manual", Vector3(7.8, 0.95, -3.0))
	_note_def(inter, "priya_note", Vector3(0, 0.35, 5.15), "priya_note")
	_sw_def(inter, "living", Vector3(-3.4, 1.45, 0.32), "Living room")
	_sw_def(inter, "kitchen", Vector3(3.4, 1.45, 0.32), "Kitchen")
	_sw_def(inter, "hall", Vector3(0, 1.45, -1.32), "Hallway")
	_sw_def(inter, "guest", Vector3(-5.0, 1.45, -1.32), "Guest room")
	_sw_def(inter, "master", Vector3(2.0, 1.45, -1.32), "Master bedroom")
	_sw_def(inter, "bath", Vector3(5.9, 1.45, -1.32), "Bathroom")
	_sw_def(inter, "laundry", Vector3(6.9, 1.45, -1.32), "Laundry")
	inter.add({"id": "mirror", "area": inter.halo(Vector3(5.2, 1.6, -1.9), 0.5),
		"prompt": func(_c): return "Look in the mirror",
		"on_use": func(_c): _mirror()})
	inter.add({"id": "vinyl", "area": inter.halo(Vector3(-7.45, 1.25, 2.5), 0.6),
		"prompt": func(_c): return "Drop the needle (\"MIDNIGHT — the 1982 pressing\")",
		"on_use": func(_c): _vinyl()})
	inter.add({"id": "adapter", "area": inter.halo(Vector3(3.2, 1.0, -2.0), 0.8),
		"prompt": func(_c): return "Search the wardrobe boxes" if not bool(flags.get("adapter", false)) else "",
		"on_use": func(_c): _take_adapter()})
	pet_def = {"id": "petcat", "area": inter.halo(Vector3(5.6, 0.45, 4.4), 0.7),
		"prompt": func(_c): return "Pet Biscuit" if not bool(flags.get("in_market", false)) else "",
		"on_use": func(_c): _pet_cat()}
	inter.add(pet_def)
	_note_def(inter, "grocery", Vector3(6.55, 1.45, 0.55), "grocery_note")
	_note_def(inter, "shed", Vector3(-9.4, 0.8, -11.4))
	_note_def(inter, "shrine", Vector3(-3.2, 1.0, -31.0))
	_note_def(inter, "garage", Vector3(9.6, 1.1, -3.05))


func _feed_biscuit() -> void:
	done("biscuit")
	sub("One scoop. Biscuit screams like you've starved him for years, then forgives you instantly. MRROW.", 5.0)


func _take_mail() -> void:
	flags["mail_taken"] = true
	world.set_prop_visible("mailpapers", false)
	audio.pickup()
	done("mail")
	sub("Bills, coupons... and an official-looking letter from the HOA. (Read it with E.)", 4.0)


func _take_trash() -> void:
	items["trash"] = true
	world.set_prop_visible("trashbag", false)
	audio.pickup()
	toast("🗑️ Trash bag acquired. It's leaking. Great.")


func _dump_trash() -> void:
	items["trash"] = false
	audio.door_shut_at(Vector3(-2.6, 0.8, 6.3))
	done("trash")
	sub("The bin lid CLANGS. Across the street, the streetlamp flickers. Was someone standing under it?", 5.0)


func _thermo() -> void:
	if chapter != 1 or is_done("thermo"):
		return
	audio.ui_click()
	done("thermo")
	sub("72°. The vents sigh. Somewhere, the house ticks like a cooling engine.", 4.0)


func _essay_page() -> void:
	essay_pages += 1
	clock_min += 25.0
	if essay_pages >= 3:
		done("essay")
		sub("Done. Three pages on 'a place that shaped you.' Your hand is dead but your conscience is clean.", 5.0)
	else:
		toast("📝 Page %d/3 done. Only %d more..." % [essay_pages, 3 - essay_pages])


func _fridge_prompt() -> String:
	if chapter == 2 and String(items.get("food", "")) == "" and String(micro["state"]) == "idle":
		return "Take Dana's lasagna"
	return "Fridge (lasagna, milk, regret)"


func _fridge_use() -> void:
	if chapter == 2 and String(items.get("food", "")) == "" and String(micro["state"]) == "idle":
		items["food"] = "cold"
		audio.pickup()
		toast("🍝 Cold lasagna. The microwave is right there.")
	else:
		audio.ui_click()


func _micro_prompt() -> String:
	if String(items.get("food", "")) == "cold" and String(micro["state"]) == "idle":
		return "Microwave the lasagna (75s)"
	if String(micro["state"]) == "running":
		return "Microwaving... (%ds)" % int(ceil(float(micro["t"])))
	if String(micro["state"]) == "done":
		return "Take the hot lasagna"
	return "Microwave (empty, humming faintly)"


func _micro_use() -> void:
	if String(items.get("food", "")) == "cold" and String(micro["state"]) == "idle":
		items["food"] = ""
		micro["state"] = "running"
		micro["t"] = CFG.MICRO_TIME
		world.micro_light.visible = true
		audio.ui_click()
		toast("⏱ 75 seconds. Maybe watch TV while you wait...")
	elif String(micro["state"]) == "done":
		micro["state"] = "idle"
		items["food"] = "hot"
		audio.pickup()
		toast("🍝 Hot lasagna! Eat it on the couch like a civilized goblin.")


func _tv_use() -> void:
	if not world.power:
		audio.locked()
		toast("📺 No power. Right.")
		return
	world.set_tv(not world.tv_on)
	audio.set_tv(world.tv_on)
	audio.ui_click()
	if world.tv_on:
		sub("\"...LOCAL NEWS AT NINE. Our top story tonight: Hollow Creek police—\" Sit down to watch.", 5.0)


func _couch_prompt() -> String:
	if bool(player.get("sitting")) and String(items.get("food", "")) == "hot":
		return "Eat dinner (hold)"
	if bool(player.get("sitting")):
		return "Stand up"
	return "Sit on the couch"


func _couch_use() -> void:
	if bool(player.get("sitting")) and String(items.get("food", "")) == "hot":
		items["food"] = ""
		done("dinner")
		sub("Peak cuisine: couch lasagna. Eaten with a plastic fork. Zero regrets.", 5.0)
	else:
		sit_toggle()


func _drawer_prompt() -> String:
	if not bool(flags.get("batteries", false)):
		return "Search the junk drawer"
	if chapter >= 5 and not bool(items.get("master_key", false)):
		return "Search the drawer again (key?)"
	return "Junk drawer (dead pens, takeout menus)"


func _drawer_use() -> void:
	audio.ui_click()
	if not bool(flags.get("batteries", false)):
		flags["batteries"] = true
		items["batteries"] = int(items.get("batteries", 0)) + 1
		items["battery"] = 100.0
		toast("🔋 Batteries! Flashlight recharged to 100%.")
		sub("A full pack of AAs. Dana labels everything: \"FLASHLIGHT — DO NOT STEAL -DANA.\"", 4.0)
	elif chapter >= 5 and not bool(items.get("master_key", false)):
		items["master_key"] = true
		audio.pickup()
		done("key")
		sub("Taped under the drawer: a brass key. \"MASTER — DO NOT.\" ...Sorry, Dana.", 5.0)
	else:
		sub("Dead pens. Soy sauce packets. A Size D battery. Nope.", 3.0)


func _take_adapter() -> void:
	flags["adapter"] = true
	audio.pickup()
	choices.append("Found the 45 adapter in the master wardrobe")
	sub("Buried in wool coats: a glittery 45 adapter. The record shelf suddenly matters.", 5.0)


func _pet_cat() -> void:
	# R5: the Cat Whisperer egg — five REAL pets (cooldown-gated, not spam).
	if float(cat.get("pet_cool")) <= 0.0:
		flags["pets"] = int(flags.get("pets", 0)) + 1
		if int(flags["pets"]) >= 5:
			_egg_found("catwhisper", "Cat Whisperer")
			sub("Biscuit headbutts your hand, hard, then stares at the front door. The fur on his spine stands up.", 6.0)
		elif int(flags["pets"]) == 3:
			toast("🐈 Biscuit is starting to trust you. (%d/5)" % int(flags["pets"]))
	cat.pet()


func _take_flash() -> void:
	items["flash"] = true
	world.set_prop_visible("flashprop", false)
	audio.pickup()
	done("flash")
	toast("🔦 Flashlight! Press F to toggle. Watch the battery.")


func _fuse() -> void:
	if chapter != 4 or is_done("fuse"):
		return
	fuse_n += 1
	audio.static_burst()
	player.set("noise", 60.0)
	if fuse_n >= 3:
		world.set_power(true)
		audio.power_up()
		audio.set_hum(true)
		done("fuse")
		sub("CLICK. The house gasps back to life. Light floods the hallway — and for one frame, a TALL SHADOW shrinks off the wall.", 6.0)
		flicker("hall", 1.5)
	else:
		toast("⚡ Breaker %d/3... the box growls." % fuse_n)


func _take_carkeys() -> void:
	items["car_keys"] = true
	world.set_prop_visible("carkeys", false)
	audio.pickup()
	done("carkeys")
	sub("Car keys. You can't drive stick. But the panic button... the headlights... options. Or just RUN.", 6.0)


func _climb_window() -> void:
	if chapter < 6:
		sub("Dana's rule #1: windows stay shut at night. ...Rules might change tonight.", 4.0)
		return
	if notes_found.has("master"):
		toast("🔓 Martin's note was right — the latch never locked. Through in seconds.")
	world.escape_win_body.get_child(0).set_deferred("disabled", true)
	player.set("hidden", "")
	player.set("frozen", false)
	player.global_position = Vector3(-5.5, 0, -6.5)
	player.call("set_look", -PI * 0.5, 0.0)
	player.set("noise", 100.0)
	audio.glass_at(Vector3(-5.5, 1.4, -5.5))
	flags["escaped_window"] = true
	sub("Cold air. Wet grass. RUN — east side, around the fence, to the STREET.", 6.0)
	toast("🏃 REACH THE STREET (south, past the fence)!")
	enemy.call("place", -1.5, -6.8, -PI * 0.5)
	enemy.set("state", "investigate")
	enemy.set("target", Vector3(-5.5, 0, -6.5))
	enemy.set("speed_mul", 1.15)


func _neighbor() -> void:
	if chapter != 6:
		return
	audio.knock_at(Vector3(-18.2, 1.3, 7.3), "heavy3")
	finish("A")


func _mirror() -> void:
	if chapter >= 4 and not bool(flags.get("mirror_look", false)):
		flags["mirror_look"] = true
		audio.sting()
		sub("Your reflection blinks a half-second late. Behind it, for one frame: the hallway. A tall shape. Gone.", 6.0)
	else:
		sub("You look great. Terrified, but great.", 3.0)
