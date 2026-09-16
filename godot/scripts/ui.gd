extends CanvasLayer
## All UI, built in code: menu, HUD, phone, dialog, notes, peephole, calls,
## pause, endings, jumpscare, VHS overlay. No .tscn UI needed.

const VHS := preload("res://shaders/vhs.gdshader")
const CFG := preload("res://scripts/config.gd")
const PAPER := Color(0.91, 0.88, 0.81)
const DIMC := Color(0.6, 0.64, 0.68)
const RED := Color(0.76, 0.07, 0.12)
const PANEL_BG := Color(0.03, 0.03, 0.05, 0.88)

var game
var story
var phone

var vhs_rect: ColorRect
var hud: Control
var vhs_stamp: Label
var vhs_room := "PORCH"
var crosshair: ColorRect
var obj_vbox: VBoxContainer
var prompt_panel: PanelContainer
var prompt_key: Label
var prompt_text: Label
var holdbar: ProgressBar
var sub_panel: PanelContainer
var sub_label: Label
var sub_tween: Tween
var toast_wrap: VBoxContainer
var stam_bar: ProgressBar
var noise_bar: ProgressBar
var batt_bar: ProgressBar
var batt_row: HBoxContainer
var ch_card: PanelContainer
var ch_kicker: Label
var ch_name: Label
var ch_sub: Label
var ch_tween: Tween
var flash_rect: ColorRect
var fade_rect: ColorRect
var scare: Control
var scare_label: Label
# phone
var phone_panel: PanelContainer
var phone_clock: Label
var thread_btns := {}
var msg_scroll: ScrollContainer
var msg_vbox: VBoxContainer
var reply_vbox: VBoxContainer
var reply_opts: Array = []
var unknown_btn: Button
# dialog / note / peephole / call
var dialog_panel: PanelContainer
var dialog_speaker: Label
var dialog_text: Label
var dialog_opts: VBoxContainer
var dialog_cbs: Array = []
var note_root: CenterContainer
var note_title: Label
var note_body: Label
var peep_root: Control
var peep_view: Label
var call_root: PanelContainer
var call_name: Label
var call_accept: Button
var call_decline: Button
var story_root: ColorRect
# menu / pause / ending
var menu_root: PanelContainer
var continue_btn: Button
var panel_how: VBoxContainer
var panel_endings: VBoxContainer
var panel_settings: VBoxContainer
var endings_vbox: VBoxContainer
var endings_count: Label
var pause_root: CenterContainer
var pause_obj: Label
var ending_root: PanelContainer
var ending_kicker: Label
var ending_title: Label
var ending_text: Label
var ending_stats: Label
var again_btn: Button
var mic_panel: PanelContainer
var mic_bar: ProgressBar
var mic_label: Label
var mic_status: Label
var rec_label: Label
var tc_label: Label
var tc_sec := 0.0
var cam_root: PanelContainer
var cam_box: SubViewportContainer
var cam_title: Label
var cam_night_rect: ColorRect
var cam_flash_rect: ColorRect
var cam_night := false
var warn_root: CenterContainer
var warn_open := false
var intro_root: Control
var intro_cc: CenterContainer
var intro_kick: Label
var intro_name: Label
var intro_sub: Label
var bar_top: ColorRect
var bar_bot: ColorRect
var panel_credits: VBoxContainer


func setup(g, s, p) -> void:
	game = g
	story = s
	phone = p
	_build_all()


# ---------- builders ----------
func _style(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.set_border_width_all(bw)
		s.border_color = border
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _label(text: String, size := 15, color := PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, size := 16) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", PAPER)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.45))
	b.add_theme_stylebox_override("normal", _style(Color(0.07, 0.07, 0.09, 0.95), Color(0.2, 0.2, 0.25), 1, 4))
	b.add_theme_stylebox_override("hover", _style(Color(0.11, 0.07, 0.08, 0.95), RED, 1, 4))
	b.add_theme_stylebox_override("pressed", _style(Color(0.16, 0.05, 0.06, 0.95), RED, 1, 4))
	b.add_theme_stylebox_override("disabled", _style(Color(0.05, 0.05, 0.06, 0.9), Color(0.12, 0.12, 0.14), 1, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _panel(bg := PANEL_BG) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(bg, Color(0.2, 0.2, 0.25), 1, 4))
	return p


func _bar(color: Color, w := 230.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0
	b.max_value = 100
	b.value = 100
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, 10)
	b.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.65), Color(0.2, 0.2, 0.25), 1, 2))
	b.add_theme_stylebox_override("fill", _style(color, Color(0, 0, 0, 0), 0, 2))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _anchor(c: Control, x: float, y: float) -> void:
	c.anchor_left = x
	c.anchor_top = y
	c.anchor_right = x
	c.anchor_bottom = y
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH


func _build_all() -> void:
	var vhs_layer := CanvasLayer.new()
	# Layer 0: below the UI root (default layer 1), above the 3D scene.
	# The screen-sampling VHS shader captures the 3D frame only; HUD, phone,
	# dialogs and menus render clean on top (docs: Custom post-processing).
	vhs_layer.layer = 0
	add_child(vhs_layer)
	vhs_rect = ColorRect.new()
	vhs_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vhs_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = VHS
	vhs_rect.material = sm
	vhs_layer.add_child(vhs_rect)
	_build_hud()
	_build_phone()
	_build_dialog()
	_build_note()
	_build_peephole()
	_build_call()
	_build_cam()
	_build_warn()
	_build_intro()
	_build_menu()
	_build_pause()
	_build_ending()
	_build_story()
	_build_overlays()
	hud.visible = false


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	vhs_stamp = _label("7:48 PM", 20, Color(0.87, 0.9, 0.93))
	vhs_stamp.position = Vector2(22, 18)
	hud.add_child(vhs_stamp)
	crosshair = ColorRect.new()
	crosshair.color = Color(0.91, 0.88, 0.81, 0.8)
	crosshair.anchor_left = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -2.5
	crosshair.offset_top = -2.5
	crosshair.offset_right = 2.5
	crosshair.offset_bottom = 2.5
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(crosshair)
	var obj_panel := _panel()
	obj_panel.position = Vector2(22, 64)
	obj_panel.custom_minimum_size = Vector2(300, 0)
	var ov := VBoxContainer.new()
	ov.add_child(_label("OBJECTIVES", 11, DIMC))
	obj_vbox = VBoxContainer.new()
	ov.add_child(obj_vbox)
	obj_panel.add_child(ov)
	hud.add_child(obj_panel)
	prompt_panel = _panel()
	_anchor(prompt_panel, 0.5, 0.58)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	prompt_key = _label("E", 16)
	prompt_text = _label("", 16)
	ph.add_child(prompt_key)
	ph.add_child(prompt_text)
	prompt_panel.add_child(ph)
	prompt_panel.visible = false
	hud.add_child(prompt_panel)
	holdbar = _bar(RED, 240)
	_anchor(holdbar, 0.5, 0.63)
	holdbar.visible = false
	hud.add_child(holdbar)
	sub_panel = _panel(Color(0, 0, 0, 0.78))
	_anchor(sub_panel, 0.5, 0.86)
	sub_label = _label("", 17)
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_label.custom_minimum_size = Vector2(680, 0)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_panel.add_child(sub_label)
	sub_panel.visible = false
	hud.add_child(sub_panel)
	toast_wrap = VBoxContainer.new()
	toast_wrap.anchor_left = 1.0
	toast_wrap.anchor_right = 1.0
	toast_wrap.offset_left = -372
	toast_wrap.offset_right = -22
	toast_wrap.offset_top = 70
	toast_wrap.offset_bottom = 400
	toast_wrap.add_theme_constant_override("separation", 8)
	hud.add_child(toast_wrap)
	var meters := VBoxContainer.new()
	meters.anchor_top = 1.0
	meters.anchor_bottom = 1.0
	meters.offset_left = 22
	meters.offset_top = -120
	meters.offset_right = 262
	meters.offset_bottom = -22
	meters.add_theme_constant_override("separation", 10)
	stam_bar = _bar(Color(0.5, 0.69, 0.41))
	noise_bar = _bar(RED)
	noise_bar.value = 0
	batt_row = HBoxContainer.new()
	batt_row.add_theme_constant_override("separation", 8)
	batt_bar = _bar(Color(0.91, 0.77, 0.42), 170)
	var bl := _label("LIGHT", 10, DIMC)
	batt_row.add_child(batt_bar)
	batt_row.add_child(bl)
	batt_row.visible = false
	var nl := _label("NOISE", 10, DIMC)
	meters.add_child(stam_bar)
	meters.add_child(noise_bar)
	meters.add_child(nl)
	meters.add_child(batt_row)
	hud.add_child(meters)
	var hint := _label("WASD move · SHIFT run · C crouch · E interact · F flashlight · TAB phone · ESC pause", 11, Color(0.42, 0.44, 0.47))
	hint.anchor_left = 1.0
	hint.anchor_top = 1.0
	hint.anchor_right = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -640
	hint.offset_top = -40
	hint.offset_right = -22
	hint.offset_bottom = -22
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(hint)
	mic_panel = _panel(Color(0, 0, 0, 0.78))
	mic_panel.anchor_left = 1.0
	mic_panel.anchor_top = 1.0
	mic_panel.anchor_right = 1.0
	mic_panel.anchor_bottom = 1.0
	mic_panel.offset_left = -330
	mic_panel.offset_top = -78
	mic_panel.offset_right = -22
	mic_panel.offset_bottom = -46
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 8)
	mh.add_child(_label("🎙", 15))
	mic_bar = _bar(Color(0.5, 0.69, 0.41), 150)
	mh.add_child(mic_bar)
	mic_label = _label("QUIET", 11, DIMC)
	mh.add_child(mic_label)
	mic_panel.add_child(mh)
	mic_panel.visible = false
	hud.add_child(mic_panel)
	ch_card = _panel(Color(0, 0, 0, 0.92))
	ch_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	ch_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	ch_kicker = _label("", 15, RED)
	ch_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ch_name = _label("", 52)
	ch_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ch_sub = _label("", 15, DIMC)
	ch_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(ch_kicker)
	cv.add_child(ch_name)
	cv.add_child(ch_sub)
	cc.add_child(cv)
	ch_card.add_child(cc)
	ch_card.visible = false
	ch_card.modulate.a = 0.0
	hud.add_child(ch_card)
	rec_label = _label("● REC", 16, RED)
	rec_label.anchor_left = 1.0
	rec_label.anchor_right = 1.0
	rec_label.offset_left = -150
	rec_label.offset_top = 18
	rec_label.offset_right = -22
	rec_label.offset_bottom = 40
	rec_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(rec_label)
	tc_label = _label("SP 0:00:00", 13, Color(0.87, 0.9, 0.93))
	tc_label.anchor_left = 1.0
	tc_label.anchor_right = 1.0
	tc_label.offset_left = -150
	tc_label.offset_top = 40
	tc_label.offset_right = -22
	tc_label.offset_bottom = 60
	tc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(tc_label)
	var date_label := _label("SEP 14 · FALL 2024", 12, DIMC)
	date_label.position = Vector2(22, 44)
	hud.add_child(date_label)


func _build_phone() -> void:
	phone_panel = _panel(Color(0.06, 0.06, 0.08, 0.97))
	phone_panel.anchor_left = 1.0
	phone_panel.anchor_top = 1.0
	phone_panel.anchor_right = 1.0
	phone_panel.anchor_bottom = 1.0
	phone_panel.offset_left = -326
	phone_panel.offset_top = -556
	phone_panel.offset_right = -26
	phone_panel.offset_bottom = -26
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	phone_clock = _label("7:48 PM", 13, DIMC)
	phone_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(phone_clock)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 4)
	for t in ["millers", "priya", "unknown"]:
		var b := _button("Dana" if t == "millers" else ("Priya" if t == "priya" else "???"), 13)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tt: String = t
		b.pressed.connect(func(): _on_thread(tt))
		th.add_child(b)
		thread_btns[t] = b
	unknown_btn = thread_btns["unknown"]
	unknown_btn.visible = false
	v.add_child(th)
	msg_scroll = ScrollContainer.new()
	msg_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	msg_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	msg_vbox = VBoxContainer.new()
	msg_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_vbox.add_theme_constant_override("separation", 7)
	msg_scroll.add_child(msg_vbox)
	v.add_child(msg_scroll)
	reply_vbox = VBoxContainer.new()
	reply_vbox.add_theme_constant_override("separation", 6)
	v.add_child(reply_vbox)
	var hint := _label("TAB close · Q threads · 1/2/3 reply", 11, DIMC)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	phone_panel.add_child(v)
	phone_panel.visible = false
	add_child(phone_panel)


func _on_thread(t: String) -> void:
	game.audio.ui_click()
	phone.call("show", t)


func _build_dialog() -> void:
	# F2F subtitle bar: bottom-anchored, near-transparent, minimal chrome.
	dialog_panel = _panel(Color(0.0, 0.0, 0.0, 0.62))
	_anchor(dialog_panel, 0.5, 0.82)
	dialog_panel.custom_minimum_size = Vector2(780, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	dialog_speaker = _label("", 12, RED)
	dialog_text = _label("", 18)
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.custom_minimum_size = Vector2(740, 0)
	dialog_opts = VBoxContainer.new()
	dialog_opts.add_theme_constant_override("separation", 4)
	v.add_child(dialog_speaker)
	v.add_child(dialog_text)
	v.add_child(dialog_opts)
	dialog_panel.add_child(v)
	dialog_panel.visible = false
	add_child(dialog_panel)


func _build_note() -> void:
	note_root = CenterContainer.new()
	note_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	note_root.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	note_root.add_child(bg)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(0.87, 0.83, 0.72), Color(0.4, 0.35, 0.25), 1, 2))
	p.custom_minimum_size = Vector2(540, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	note_title = _label("", 20, Color(0.1, 0.1, 0.1))
	note_body = _label("", 16, Color(0.12, 0.12, 0.12))
	note_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_body.custom_minimum_size = Vector2(490, 0)
	var foot := _label("[E] / click to close", 12, Color(0.4, 0.4, 0.4))
	v.add_child(note_title)
	v.add_child(note_body)
	v.add_child(foot)
	p.add_child(v)
	note_root.add_child(p)
	note_root.gui_input.connect(_on_note_click)
	add_child(note_root)


func _on_note_click(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		game.note_click()


func _build_peephole() -> void:
	peep_root = Control.new()
	peep_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	peep_root.visible = false
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	peep_root.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	var eye := _label("👁", 72)
	eye.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	peep_view = _label("", 18)
	peep_view.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	peep_view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	peep_view.custom_minimum_size = Vector2(520, 0)
	var foot := _label("[E] / click to step back", 13, DIMC)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(eye)
	v.add_child(peep_view)
	v.add_child(foot)
	cc.add_child(v)
	peep_root.add_child(cc)
	peep_root.gui_input.connect(_on_peep_click)
	add_child(peep_root)


func _on_peep_click(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		game.peep_click()


func _build_call() -> void:
	call_root = _panel(Color(0.02, 0.02, 0.03, 0.93))
	call_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	call_root.visible = false
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	call_name = _label("", 44)
	call_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label("incoming call...", 15, DIMC)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 18)
	call_accept = _button("Accept")
	call_decline = _button("Decline")
	hb.add_child(call_accept)
	hb.add_child(call_decline)
	v.add_child(call_name)
	v.add_child(sub)
	v.add_child(hb)
	cc.add_child(v)
	call_root.add_child(cc)
	add_child(call_root)


func _build_cam() -> void:
	cam_root = _panel(Color(0.01, 0.01, 0.02, 0.99))
	cam_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	cam_root.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	cam_title = _label("MILLER SECURITY · CAM 01 · PORCH", 15, PAPER)
	cam_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rec := _label("● REC", 15, RED)
	top.add_child(cam_title)
	top.add_child(rec)
	v.add_child(top)
	cam_box = SubViewportContainer.new()
	cam_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cam_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cam_box.stretch = true
	v.add_child(cam_box)
	cam_night_rect = ColorRect.new()
	cam_night_rect.color = Color(0.15, 0.85, 0.25, 0.22)
	cam_night_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	cam_night_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cam_night_rect.visible = false
	cam_flash_rect = ColorRect.new()
	cam_flash_rect.color = Color(0.9, 0.9, 0.92, 1.0)
	cam_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	cam_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cam_flash_rect.modulate.a = 0.0
	var bot := HBoxContainer.new()
	bot.alignment = BoxContainer.ALIGNMENT_CENTER
	bot.add_theme_constant_override("separation", 12)
	var prev := _button("[<] Prev", 14)
	var next := _button("[>] Next", 14)
	var night := _button("[N] Night mode", 14)
	var exit := _button("[E] Exit", 14)
	prev.pressed.connect(func(): cam_cycle(-1))
	next.pressed.connect(func(): cam_cycle(1))
	night.pressed.connect(func(): cam_night_toggle())
	exit.pressed.connect(func(): game.story.cam_close())
	bot.add_child(prev)
	bot.add_child(next)
	bot.add_child(night)
	bot.add_child(exit)
	v.add_child(bot)
	var hint := _label("A/D switch · N night mode · E exit", 11, DIMC)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	cam_root.add_child(v)
	cam_root.add_child(cam_night_rect)
	cam_root.add_child(cam_flash_rect)
	add_child(cam_root)


func cam_show() -> void:
	var vp: SubViewport = game.world.get("cam_vp")
	if vp != null:
		if vp.get_parent() != null:
			vp.get_parent().remove_child(vp)
		cam_box.add_child(vp)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cam_title.text = "MILLER SECURITY · " + String((game.world.get("cam_labels") as Array)[int(game.world.get("cam_idx"))])
	cam_night = false
	cam_night_rect.visible = false
	cam_root.visible = true
	game.update_mouse()


func cam_close() -> void:
	var vp: SubViewport = game.world.get("cam_vp")
	if vp != null:
		if vp.get_parent() != null:
			vp.get_parent().remove_child(vp)
		game.world.add_child(vp)
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	cam_root.visible = false
	game.update_mouse()


func cam_cycle(dir: int) -> void:
	game.audio.ui_click()
	var label: String = game.world.cam_cycle(dir)
	cam_title.text = "MILLER SECURITY · " + label + (" · NIGHT" if cam_night else "")
	cam_flash_rect.modulate.a = 0.85
	var tw := create_tween()
	tw.tween_property(cam_flash_rect, "modulate:a", 0.0, 0.18)


func cam_night_toggle() -> void:
	game.audio.ui_click()
	cam_night = not cam_night
	cam_night_rect.visible = cam_night
	var base: String = String((game.world.get("cam_labels") as Array)[int(game.world.get("cam_idx"))])
	cam_title.text = "MILLER SECURITY · " + base + (" · NIGHT" if cam_night else "")


func _build_warn() -> void:
	warn_root = CenterContainer.new()
	warn_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 1)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	warn_root.add_child(dim)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(560, 0)
	var t := _label("CONTENT WARNING", 30, RED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := _label("Flashing lights · sudden loud sounds · disturbing content.\nHeadphones recommended. Take breaks.", 15, PAPER)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ok := _button("I understand — [E] / click")
	ok.pressed.connect(func(): game.warn_click())
	v.add_child(t)
	v.add_child(b)
	v.add_child(ok)
	warn_root.add_child(v)
	add_child(warn_root)
	warn_open = true


func warn_close() -> void:
	warn_root.visible = false
	warn_open = false
	game.update_mouse()


func _build_intro() -> void:
	intro_root = Control.new()
	intro_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_root.visible = false
	bar_top = ColorRect.new()
	bar_top.color = Color.BLACK
	bar_top.anchor_right = 1.0
	bar_top.offset_bottom = 90
	bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bot = ColorRect.new()
	bar_bot.color = Color.BLACK
	bar_bot.anchor_top = 1.0
	bar_bot.anchor_right = 1.0
	bar_bot.anchor_bottom = 1.0
	bar_bot.offset_top = -90
	bar_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_cc = CenterContainer.new()
	intro_cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	intro_kick = _label("", 16, RED)
	intro_kick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_name = _label("", 54)
	intro_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_sub = _label("", 15, DIMC)
	intro_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(intro_kick)
	v.add_child(intro_name)
	v.add_child(intro_sub)
	intro_cc.add_child(v)
	var skip := _label("[E] / CLICK TO SKIP", 12, Color(0.5, 0.52, 0.55))
	skip.anchor_left = 0.5
	skip.anchor_top = 1.0
	skip.anchor_right = 0.5
	skip.anchor_bottom = 1.0
	skip.offset_left = -200
	skip.offset_right = 200
	skip.offset_top = -130
	skip.offset_bottom = -105
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_root.add_child(bar_top)
	intro_root.add_child(bar_bot)
	intro_root.add_child(intro_cc)
	intro_root.add_child(skip)
	add_child(intro_root)


func show_intro(on: bool) -> void:
	intro_root.visible = on
	if on:
		intro_kick.text = ""
		intro_name.text = ""
		intro_sub.text = ""
	game.update_mouse()


func intro_tick(t: float) -> void:
	var cards := [
		{"t0": 0.5, "t1": 6.5, "k": "MOHAMMAD R PRESENTS", "n": "ECHOES IN THE DARK", "s": "episode two · the housesit"},
		{"t0": 8.5, "t1": 14.5, "k": "SEPTEMBER 14", "n": "7:48 PM", "s": "the storm is coming"},
		{"t0": 16.5, "t1": 22.5, "k": "MILLER RESIDENCE", "n": "ONE NIGHT", "s": "feed the cat · lock the doors · survive"},
	]
	var shown := false
	for c in cards:
		var t0: float = c["t0"]
		var t1: float = c["t1"]
		if t >= t0 and t <= t1:
			intro_kick.text = String(c["k"])
			intro_name.text = String(c["n"])
			intro_sub.text = String(c["s"])
			intro_cc.modulate.a = clampf(minf(t - t0, t1 - t) / 1.0, 0.0, 1.0)
			shown = true
	if not shown:
		intro_cc.modulate.a = 0.0


func _build_menu() -> void:
	menu_root = _panel(Color(0.02, 0.02, 0.03, 0.55))
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(560, 0)
	var kicker := _label("RAYLL-STYLE EPISODIC HORROR · EPISODE 2", 12, RED)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := _label("ECHOES\nIN THE DARK", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label("\"The Housesit\" — one stormy night for the Millers.", 15, DIMC)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(kicker)
	v.add_child(title)
	v.add_child(sub)
	var by := _label("A GAME BY MOHAMMAD R", 13, Color(0.91, 0.77, 0.42))
	by.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(by)
	var new_btn := _button("▶ New Night")
	continue_btn = _button("Continue")
	var how_btn := _button("How to play")
	var end_btn := _button("Endings")
	endings_count = _label("", 12, DIMC)
	endings_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var set_btn := _button("Settings")
	new_btn.pressed.connect(func(): game.start_new())
	continue_btn.pressed.connect(func(): game.start_continue())
	how_btn.pressed.connect(func(): _toggle_panel("how"))
	end_btn.pressed.connect(func(): _toggle_panel("endings"))
	set_btn.pressed.connect(func(): _toggle_panel("settings"))
	var cred_btn := _button("Credits")
	cred_btn.pressed.connect(func(): _toggle_panel("credits"))
	v.add_child(new_btn)
	v.add_child(continue_btn)
	v.add_child(how_btn)
	v.add_child(end_btn)
	v.add_child(endings_count)
	v.add_child(set_btn)
	v.add_child(cred_btn)
	panel_how = VBoxContainer.new()
	var how_text := _label("You are JAMIE, 17, housesitting for the Millers for one stormy night. Feed the cat. Heat the lasagna. Answer your texts. Then survive what knocks.\n\nWASD move · Mouse look · SHIFT sprint (loud!) · C crouch (quiet)\nE interact / hold E for long tasks · F flashlight · TAB phone · security cameras on the hall monitor\n\nRunning, doors and beeps make NOISE. When HE is inside, noise gets you found. Hide UNDER THE BED or in CLOSETS. Turn the flashlight OFF when hiding.\n\n🎙 MICROPHONE STEALTH (Settings): with a mic on, coughing or talking while hiding gets you HEARD. M mutes.\n\n🛒 Mid-shift you'll walk to FreshMart for groceries. Grab everything on Dana's list. Mind the two guys by the dairy case.\n\n🥚 2 hidden easter eggs. 🐈 Pet the cat. Trust the cat.\n\n4 endings. Your choices and noise matter. ~60 minutes.", 14)
	how_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_how.add_child(_label("HOW TO PLAY", 13, RED))
	panel_how.add_child(how_text)
	panel_how.visible = false
	v.add_child(panel_how)
	panel_endings = VBoxContainer.new()
	panel_endings.add_child(_label("ENDINGS", 13, RED))
	endings_vbox = VBoxContainer.new()
	panel_endings.add_child(endings_vbox)
	panel_endings.visible = false
	v.add_child(panel_endings)
	panel_settings = VBoxContainer.new()
	panel_settings.add_child(_label("SETTINGS", 13, RED))
	_add_slider_row(panel_settings, "Mouse sensitivity", 0.3, 3.0, 0.1, "sens")
	_add_slider_row(panel_settings, "Volume", 0.0, 1.0, 0.05, "vol")
	_add_check_row(panel_settings, "Subtitles", "subs")
	_add_check_row(panel_settings, "Film grain + VHS effect", "grain")
	_add_check_row(panel_settings, "Head-bob", "headbob")
	_add_check_row(panel_settings, "🎙 Microphone stealth (he hears you)", "mic")
	_add_check_row(panel_settings, "High graphics (turn OFF if the game stutters)", "highq")
	_add_slider_row(panel_settings, "Mic sensitivity", 0.0, 1.0, 0.05, "micsens")
	mic_status = _label("", 12, DIMC)
	mic_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_settings.add_child(mic_status)
	panel_settings.visible = false
	v.add_child(panel_settings)
	panel_credits = VBoxContainer.new()
	panel_credits.add_child(_label("CREDITS", 13, RED))
	var credits := _label("MOHAMMAD R — creator · director · writer\nTHE R FAMILY — voice cast (Dana · Priya · Jamie · 911 operator)\n\nMade with Godot 4 · music & sound generated in-game\nThanks for playing — leave the porch light on.", 14)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_credits.add_child(credits)
	panel_credits.visible = false
	v.add_child(panel_credits)
	var foot := _label("Autosaves every chapter · headphones on 🔦", 12, Color(0.33, 0.33, 0.37))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)
	cc.add_child(v)
	menu_root.add_child(cc)
	add_child(menu_root)


func _toggle_panel(which: String) -> void:
	game.audio.ui_click()
	for p in [panel_how, panel_endings, panel_settings, panel_credits]:
		if (which == "how" and p == panel_how) or (which == "endings" and p == panel_endings) or (which == "settings" and p == panel_settings) or (which == "credits" and p == panel_credits):
			p.visible = not p.visible
		else:
			p.visible = false
	if which == "endings" and panel_endings.visible:
		refresh_endings_list()


func _add_slider_row(parent: VBoxContainer, text: String, minv: float, maxv: float, step: float, key: String) -> HSlider:
	var hb := HBoxContainer.new()
	var l := _label(text, 14)
	l.custom_minimum_size = Vector2(220, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sl := HSlider.new()
	sl.min_value = minv
	sl.max_value = maxv
	sl.step = step
	sl.value = float(game.settings.get(key, 1.0))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(func(v): game.setting_changed(key, v))
	hb.add_child(l)
	hb.add_child(sl)
	parent.add_child(hb)
	return sl


func _add_check_row(parent: VBoxContainer, text: String, key: String) -> void:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = bool(game.settings.get(key, true))
	cb.add_theme_font_size_override("font_size", 14)
	cb.add_theme_color_override("font_color", PAPER)
	cb.toggled.connect(func(on): game.setting_changed(key, on))
	parent.add_child(cb)


func _build_pause() -> void:
	pause_root = CenterContainer.new()
	pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.add_child(dim)
	var p := _panel()
	p.custom_minimum_size = Vector2(480, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var t := _label("Paused", 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_obj = _label("", 14)
	pause_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 10)
	var resume_btn := _button("Resume")
	var quit_btn := _button("Quit to menu")
	resume_btn.pressed.connect(func(): game.resume_game())
	quit_btn.pressed.connect(func(): game.quit_to_menu())
	hb.add_child(resume_btn)
	hb.add_child(quit_btn)
	v.add_child(t)
	v.add_child(pause_obj)
	v.add_child(hb)
	_add_slider_row(v, "Mouse sensitivity", 0.3, 3.0, 0.1, "sens")
	_add_slider_row(v, "Volume", 0.0, 1.0, 0.05, "vol")
	p.add_child(v)
	pause_root.add_child(p)
	add_child(pause_root)


func _build_ending() -> void:
	ending_root = _panel(Color.BLACK)
	ending_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ending_root.visible = false
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(620, 0)
	ending_kicker = _label("", 13, RED)
	ending_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_kicker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ending_title = _label("", 52)
	ending_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_text = _label("", 16, Color(0.79, 0.76, 0.68))
	ending_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ending_stats = _label("", 13, DIMC)
	ending_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	again_btn = _button("▶ Play again")
	var menu_btn := _button("Menu")
	again_btn.pressed.connect(func(): game.again_pressed())
	menu_btn.pressed.connect(func(): game.quit_to_menu())
	hb.add_child(again_btn)
	hb.add_child(menu_btn)
	v.add_child(ending_kicker)
	v.add_child(ending_title)
	v.add_child(ending_text)
	v.add_child(ending_stats)
	v.add_child(hb)
	cc.add_child(v)
	ending_root.add_child(cc)
	add_child(ending_root)


func _build_overlays() -> void:
	flash_rect = ColorRect.new()
	flash_rect.color = Color(0.76, 0.07, 0.12, 0.55)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.modulate.a = 0.0
	add_child(flash_rect)
	scare = Control.new()
	scare.set_anchors_preset(Control.PRESET_FULL_RECT)
	scare.visible = false
	scare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scare.add_child(bg)
	scare_label = _label("◉_◉", 380, Color.WHITE)
	scare_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	scare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scare_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scare.add_child(scare_label)
	add_child(scare)
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0.0
	add_child(fade_rect)


func _process(_dt: float) -> void:
	if scare.visible:
		scare_label.position = Vector2(randf_range(-14, 14), randf_range(-10, 10))
	if mic_status and panel_settings.visible and game and game.mic:
		mic_status.text = game.mic.status_text()
	if hud != null and hud.visible:
		tc_sec += _dt
		var tt := int(tc_sec)
		tc_label.text = "SP %d:%02d:%02d" % [tt / 3600, (tt / 60) % 60, tt % 60]
		rec_label.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(tc_sec * 4.0))


# ---------- story API ----------
func toast(msg: String) -> void:
	var p := _panel()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(_label(msg, 14))
	toast_wrap.add_child(p)
	while toast_wrap.get_child_count() > 5:
		(toast_wrap.get_child(0) as Node).queue_free()
	_remove_toast_later(p)


func _remove_toast_later(p: Control) -> void:
	await get_tree().create_timer(4.2, false).timeout
	if is_instance_valid(p):
		p.queue_free()


func subtitle(text: String, dur := 4.0) -> void:
	if not bool(game.settings.get("subs", true)):
		return
	sub_label.text = text
	sub_panel.visible = true
	sub_panel.modulate.a = 1.0
	if sub_tween and sub_tween.is_valid():
		sub_tween.kill()
	sub_tween = create_tween()
	sub_tween.tween_interval(dur)
	sub_tween.tween_property(sub_panel, "modulate:a", 0.0, 0.5)
	sub_tween.tween_callback(func(): sub_panel.visible = false)


func objectives(list: Array) -> void:
	for c in obj_vbox.get_children():
		c.queue_free()
	var lines: Array = []
	for o in list:
		var d: Dictionary = o
		var done := bool(d["done"])
		var l := _label(("✓ " if done else "▸ ") + String(d["text"]), 14, DIMC if done else PAPER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		obj_vbox.add_child(l)
		lines.append(("%s %s" % ["✓" if done else "▸", String(d["text"])]))
	pause_obj.text = "OBJECTIVES\n" + "\n".join(lines)


func chapter_card(kicker: String, card_name: String, sub: String) -> void:
	ch_kicker.text = "▶ TRACKING"
	ch_name.text = "···"
	ch_sub.text = sub
	ch_card.visible = true
	ch_card.modulate.a = 1.0
	if ch_tween and ch_tween.is_valid():
		ch_tween.kill()
	ch_tween = create_tween()
	ch_tween.tween_interval(0.55)
	ch_tween.tween_callback(func():
		ch_kicker.text = kicker
		ch_name.text = card_name)
	ch_tween.tween_interval(2.0)
	ch_tween.tween_property(ch_card, "modulate:a", 0.0, 0.9)
	ch_tween.tween_callback(func(): ch_card.visible = false)


func show_dialog(sp: String, text: String, opts: Array) -> void:
	dialog_speaker.text = sp.to_upper()
	dialog_text.text = text
	for c in dialog_opts.get_children():
		c.queue_free()
	for i in opts.size():
		var o: Dictionary = opts[i]
		var b := _button("%d. %s" % [i + 1, String(o["text"]).to_upper()], 15)
		var cb: Callable = o["cb"]
		b.pressed.connect(func(): _on_dialog_opt(cb))
		dialog_opts.add_child(b)
	dialog_panel.visible = true
	dialog_cbs = []
	for o in opts:
		dialog_cbs.append((o as Dictionary)["cb"])
	game.update_mouse()


func press_dialog(i: int) -> void:
	if dialog_panel.visible and i >= 0 and i < dialog_cbs.size():
		_on_dialog_opt(dialog_cbs[i])


func _on_dialog_opt(cb: Callable) -> void:
	game.audio.ui_click()
	cb.call()


func close_dialog() -> void:
	dialog_panel.visible = false
	game.update_mouse()


func _build_story() -> void:
	story_root = ColorRect.new()
	story_root.color = Color(0, 0, 0, 1)
	story_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	story_root.visible = false
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(620, 0)
	var kick := _label("AS TOLD BY JAMIE K. · FALL 2024", 13, RED)
	kick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t1 := _label("The following is based on a true story.", 22)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := _label("One night. One storm. One housesit for the Millers.\nReconstructed from texts, phone calls, and a 911 recording.", 16, DIMC)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t3 := _label("Names have been changed.", 14, DIMC)
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var foot := _label("[E] / CLICK TO BEGIN THE NIGHT", 15, PAPER)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(kick)
	v.add_child(t1)
	v.add_child(t2)
	v.add_child(t3)
	v.add_child(foot)
	cc.add_child(v)
	story_root.add_child(cc)
	story_root.gui_input.connect(_on_story_click)
	add_child(story_root)


func true_story_card() -> void:
	story_root.visible = true
	game.update_mouse()


func close_story() -> void:
	story_root.visible = false
	game.update_mouse()


func _on_story_click(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		game.story_click()


func note_show(title: String, body: String) -> void:
	note_title.text = title
	note_body.text = body
	note_root.visible = true
	game.update_mouse()


func note_close() -> void:
	note_root.visible = false
	game.update_mouse()


func peephole(text: String) -> void:
	peep_view.text = text
	peep_root.visible = true
	game.update_mouse()


func close_peephole() -> void:
	peep_root.visible = false
	game.update_mouse()


func call_show(caller: String, on_accept: Callable, on_decline: Callable) -> void:
	call_name.text = caller
	for c in [call_accept, call_decline]:
		for conn in (c as Button).pressed.get_connections():
			(c as Button).pressed.disconnect(conn["callable"])
	call_accept.pressed.connect(func(): _on_call_btn(on_accept))
	call_decline.pressed.connect(func(): _on_call_btn(on_decline))
	call_root.visible = true
	game.update_mouse()


func _on_call_btn(cb: Callable) -> void:
	game.audio.ui_click()
	cb.call()


func call_close() -> void:
	call_root.visible = false
	game.update_mouse()


func flash() -> void:
	flash_rect.modulate.a = 0.9
	var tw := create_tween()
	tw.tween_property(flash_rect, "modulate:a", 0.0, 0.3)


func flash_hide(text: String) -> void:
	subtitle(text, 5.0)


func vhs(s: String) -> void:
	vhs_stamp.text = s + "  ▸ " + vhs_room


func room_toast(room_name: String) -> void:
	vhs_room = room_name
	vhs_stamp.text = vhs_stamp.text.split("  ▸ ")[0] + "  ▸ " + vhs_room


func autosave() -> void:
	game.autosave()
	toast("💾 Checkpoint saved.")


func fade_swap(cb: Callable, dur := 0.5) -> void:
	# Fade to black, run cb (teleport etc), fade back in.
	var t := create_tween()
	t.tween_property(fade_rect, "modulate:a", 1.0, dur)
	t.tween_callback(func(): cb.call())
	t.tween_interval(0.15)
	t.tween_property(fade_rect, "modulate:a", 0.0, dur)


func set_mic(show: bool, level: float, loud: bool, warn_hide: bool) -> void:
	mic_panel.visible = show
	if not show:
		return
	mic_bar.value = level * 100.0
	if loud:
		mic_label.text = "HEARD?!"
		mic_label.add_theme_color_override("font_color", RED)
	elif warn_hide:
		mic_label.text = "STAY QUIET"
		mic_label.add_theme_color_override("font_color", Color(0.91, 0.77, 0.42))
	else:
		mic_label.text = "LIVE" if level > 0.02 else "QUIET"
		mic_label.add_theme_color_override("font_color", DIMC)


func jumpscare(cb: Callable) -> void:
	game.audio.sting()
	game.shake(1.2)
	flash()
	scare.visible = true
	await get_tree().create_timer(1.1, false).timeout
	scare.visible = false
	cb.call()


func show_ending(id: String, text: String, sub: String, stats: String) -> void:
	var good := bool((CFG.ENDINGS[id] as Dictionary)["good"])
	ending_kicker.text = sub
	ending_title.text = String((CFG.ENDINGS[id] as Dictionary)["name"]) + (" ✓" if good else " ✗")
	ending_title.add_theme_color_override("font_color", Color(0.5, 0.69, 0.41) if good else RED)
	ending_text.text = text
	ending_stats.text = stats + "\n\nA GAME BY MOHAMMAD R"
	again_btn.text = "↻ Retry from checkpoint" if id == "D" else "▶ Play again"
	game.on_ending(id)
	ending_root.visible = true
	game.update_mouse()


# ---------- HUD updates ----------
func set_prompt(text: String, hold_mode: bool) -> void:
	prompt_panel.visible = text != ""
	if text != "":
		prompt_key.text = "HOLD E" if hold_mode else "E"
		prompt_text.text = text


func set_hold(frac: float) -> void:
	holdbar.visible = frac >= 0.0
	if frac >= 0.0:
		holdbar.value = frac * 100.0


func set_meters(stam: float, noise: float, batt: float, has_flash: bool) -> void:
	stam_bar.value = stam
	noise_bar.value = noise
	batt_row.visible = has_flash
	if has_flash:
		batt_bar.value = batt


# ---------- phone ----------
func set_phone_visible(v: bool) -> void:
	phone_panel.visible = v
	if v:
		render_phone()
	game.update_mouse()


func show_unknown_tab() -> void:
	unknown_btn.visible = true


func set_phone_clock(s: String) -> void:
	phone_clock.text = s


func render_phone_badges() -> void:
	var names := {"millers": "Dana", "priya": "Priya", "unknown": "???"}
	for t in thread_btns.keys():
		var b: Button = thread_btns[t]
		var un := int((phone.get("unread") as Dictionary).get(t, 0))
		var mark := "▸ " if String(phone.get("active")) == t else ""
		b.text = mark + String(names[t]) + (" (%d)" % un if un > 0 else "")


func render_phone() -> void:
	if phone == null:
		return
	for c in msg_vbox.get_children():
		c.queue_free()
	var who := "Dana"
	if String(phone.get("active")) == "priya":
		who = "Priya"
	elif String(phone.get("active")) == "unknown":
		who = "???"
	for m in ((phone.get("threads") as Dictionary)[String(phone.get("active"))] as Array):
		var d: Dictionary = m
		if bool(d.get("sys", false)):
			var s := _label(String(d["text"]), 12, DIMC)
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			msg_vbox.add_child(s)
			continue
		var me := bool(d.get("me", false))
		var nm := _label("You" if me else who, 10, Color(0.62, 0.78, 1.0) if me else DIMC)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if me else HORIZONTAL_ALIGNMENT_LEFT
		msg_vbox.add_child(nm)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		var bub := PanelContainer.new()
		bub.add_theme_stylebox_override("panel", _style(Color(0.15, 0.32, 0.62, 0.95) if me else Color(0.17, 0.17, 0.2, 0.95), Color(0, 0, 0, 0), 0, 10))
		var bl := _label(String(d["text"]), 14, PAPER)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.custom_minimum_size = Vector2(200, 0)
		bub.add_child(bl)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if me:
			row.add_child(sp)
			row.add_child(bub)
		else:
			row.add_child(bub)
			row.add_child(sp)
		msg_vbox.add_child(row)
	render_phone_badges()
	await get_tree().process_frame
	if is_instance_valid(msg_scroll):
		var bar := msg_scroll.get_v_scroll_bar()
		bar.value = bar.max_value


func set_replies(opts: Array) -> void:
	reply_opts = opts
	for c in reply_vbox.get_children():
		c.queue_free()
	for i in opts.size():
		var o: Dictionary = opts[i]
		var b := _button("%d. %s" % [i + 1, String(o["text"])], 13)
		var idx := i
		b.pressed.connect(func(): _on_reply(idx))
		reply_vbox.add_child(b)


func press_reply(i: int) -> void:
	if i >= 0 and i < reply_opts.size():
		_on_reply(i)


func _on_reply(i: int) -> void:
	if i < 0 or i >= reply_opts.size():
		return
	var cb: Callable = (reply_opts[i] as Dictionary)["cb"]
	game.audio.ui_click()
	set_replies([])
	cb.call()


# ---------- screens ----------
func show_hud() -> void:
	menu_root.visible = false
	ending_root.visible = false
	pause_root.visible = false
	hud.visible = true
	tc_sec = 0.0
	fade_rect.modulate.a = 0.0
	game.update_mouse()


func show_menu() -> void:
	hud.visible = false
	ending_root.visible = false
	pause_root.visible = false
	menu_root.visible = true
	refresh_endings_list()
	refresh_continue()
	game.update_mouse()


func show_pause(v: bool) -> void:
	pause_root.visible = v
	game.update_mouse()


func hide_ending() -> void:
	ending_root.visible = false


func refresh_endings_list() -> void:
	var e: Dictionary = game.get_endings()
	for c in endings_vbox.get_children():
		c.queue_free()
	for id in ["A", "B", "C", "D"]:
		var n := int(float(e.get(id, 0)))
		endings_vbox.add_child(_label(("%s %s" % ["✓" if n > 0 else "✗", String((CFG.ENDINGS[id] as Dictionary)["name"])]) + (" ×%d" % n if n > 1 else ""), 14))
	endings_count.text = "(%d/4 found)" % e.size()


func refresh_continue() -> void:
	continue_btn.disabled = not game.has_save()


func set_dread(x: float) -> void:
	if vhs_rect and vhs_rect.material:
		(vhs_rect.material as ShaderMaterial).set_shader_parameter("dread", clampf(x, 0.0, 1.0))


func apply_settings_vis() -> void:
	vhs_rect.visible = bool(game.settings.get("grain", true))
