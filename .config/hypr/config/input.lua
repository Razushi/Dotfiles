-- === Keyboard & pointer ===
hl.config({
	input = {
		kb_layout  = "us",
		kb_variant = "",
		kb_model   = "",
		kb_options = "",
		kb_rules   = "",

		follow_mouse = 1,
		sensitivity  = 0, -- -1.0..1.0; 0 = no change

		touchpad = {
			natural_scroll = false,
		},
	},
})

-- === Cursor ===
hl.config({
	cursor = {
		no_hardware_cursors = false,
		use_cpu_buffer      = true,
		no_warps            = false,
	},
})

hl.env("XCURSOR_SIZE", "32")
hl.env("XCURSOR_THEME", "BreezeX-Dark-hyprcursor")
hl.env("HYPRCURSOR_SIZE", "32")
hl.env("HYPRCURSOR_THEME", "BreezeX-Dark-hyprcursor")

-- === Per-device ===
hl.device({
	name          = "logitech-g502-hero-gaming-mouse",
	accel_profile = "flat",
})

-- === Gestures ===
hl.gesture({
	fingers   = 3,
	direction = "horizontal",
	action    = "workspace",
})
