-- === Placement ===
-- 0, not the default 1: HL_INITIAL_WORKSPACE_TOKEN is inherited by every child
-- of the startup daemons, and they were dropping new windows on workspace 31.
hl.config({
	misc = {
		initial_workspace_tracking = 0,
	},
})

-- === Layout ===
hl.config({
	dwindle = {
		preserve_split = true,
	},

	master = {
		new_status = "master",
	},
})

-- === Basics ===
hl.bind("SUPER + C",         hl.dsp.window.close())
hl.bind("SUPER + V",         hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + SHIFT + V", hl.dsp.window.pin())
hl.bind("SUPER + P",         hl.dsp.window.pseudo())
hl.bind("SUPER + SHIFT + K", hl.dsp.window.kill(), { description = "Click a window to kill it" })

hl.bind("SUPER + F",         hl.dsp.window.fullscreen({ mode = "maximized",  action = "toggle" }))
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

-- dwindle's split toggle.
hl.bind("SUPER + backslash", hl.dsp.layout("togglesplit"))

local mon = require("config.monitors")

-- === Focus ===
-- get_workspace_windows returns stack order, not screen order, so sort first.
local AXES = {
	horizontal = function(a, b)
		if a.at.x ~= b.at.x then return a.at.x < b.at.x end
		return a.at.y < b.at.y
	end,
	vertical = function(a, b)
		if a.at.y ~= b.at.y then return a.at.y < b.at.y end
		return a.at.x < b.at.x
	end,
}

local function windows_in_order(ws, axis)
	local wins = ws and hl.get_workspace_windows(ws) or {}
	table.sort(wins, AXES[axis] or AXES.horizontal)
	return wins
end

-- Focus the window at one end of the current workspace along an axis.
-- focus({ window = "first" }) does not resolve; it only warns.
local function focus_edge(which, axis)
	local wins = windows_in_order(hl.get_active_workspace(), axis)
	if #wins == 0 then return end
	local target = which == "first" and wins[1] or wins[#wins]
	hl.dispatch(hl.dsp.focus({ window = "address:" .. target.address }))
end

-- Move focus along an axis; at the edge, spill into the neighbouring workspace
-- and land on the window nearest the edge you came through. Walks the sorted
-- list by index rather than dispatching movefocus, which crosses monitors at a
-- workspace edge and so cannot be used for edge detection.
local function focus_or_spill(axis, step, landing)
	return function()
		local wins   = windows_in_order(hl.get_active_workspace(), axis)
		local active = hl.get_active_window()

		local index
		if active then
			for i, w in ipairs(wins) do
				if w.address == active.address then
					index = i
					break
				end
			end
		end

		local target = index and wins[index + step]
		if target then
			hl.dispatch(hl.dsp.focus({ window = "address:" .. target.address }))
			return
		end

		-- Capped at both ends of the monitor's block.
		local ws     = hl.get_active_workspace()
		local target_ws = ws and mon.step(ws.id, step)
		if not target_ws then return end

		hl.dispatch(hl.dsp.focus({ workspace = target_ws }))
		focus_edge(landing, axis)
	end
end

hl.bind("SUPER + left",  focus_or_spill("horizontal", -1, "last"),
	{ description = "Focus left, spilling into the previous workspace at the edge" })
hl.bind("SUPER + right", focus_or_spill("horizontal",  1, "first"),
	{ description = "Focus right, spilling into the next workspace at the edge" })
hl.bind("SUPER + up",    focus_or_spill("vertical",   -1, "last"),
	{ description = "Focus up, spilling into the previous workspace at the edge" })
hl.bind("SUPER + down",  focus_or_spill("vertical",    1, "first"),
	{ description = "Focus down, spilling into the next workspace at the edge" })

-- hjkl stays plain within-workspace focus.
hl.bind("SUPER + H", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + J", hl.dsp.focus({ direction = "d" }))
hl.bind("SUPER + K", hl.dsp.focus({ direction = "u" }))
hl.bind("SUPER + L", hl.dsp.focus({ direction = "r" }))

hl.bind("SUPER + Home", function() focus_edge("first", "horizontal") end)
hl.bind("SUPER + End",  function() focus_edge("last", "horizontal") end)

-- Built at load time so a bad argument shows up in `Hyprland --verify-config`.
local float_toggle = hl.dsp.window.float({ action = "toggle" })
local pseudo       = hl.dsp.window.pseudo()
local cycle_prev   = hl.dsp.window.cycle_next({ prev = true })
local raise        = hl.dsp.window.bring_to_top()
local centre       = hl.dsp.window.center()
local size_1080p   = hl.dsp.window.resize({ x = 1920, y = 1080 })

-- Cycle backwards through a floating stack and raise whatever lands on top.
hl.bind("SUPER + Tab", function()
	hl.dispatch(cycle_prev)
	hl.dispatch(raise)
end)

-- === Move ===
local directions = { left = "l", down = "d", up = "u", right = "r" }
for arrow, dir in pairs(directions) do
	hl.bind("SUPER + SHIFT + " .. arrow, hl.dsp.window.move({ direction = dir }))
end

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Move window" })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })

-- === Size ===
-- window.resize only speaks pixels, and sizes are logical: hence the divide by scale.
local function resize_fraction(fw, fh, relative)
	local mon = hl.get_active_monitor()
	if not mon then return end
	hl.dispatch(hl.dsp.window.resize({
		x        = math.floor(mon.width  / mon.scale * fw),
		y        = math.floor(mon.height / mon.scale * fh),
		relative = relative,
	}))
end

hl.bind("SUPER + minus",         function() resize_fraction(-0.1, 0, true) end, { repeating = true })
hl.bind("SUPER + equal",         function() resize_fraction( 0.1, 0, true) end, { repeating = true })
hl.bind("SUPER + SHIFT + minus", function() resize_fraction(0, -0.1, true) end, { repeating = true })
hl.bind("SUPER + SHIFT + equal", function() resize_fraction(0,  0.1, true) end, { repeating = true })

-- Half-width, full-height, centred. Floats briefly so the size takes.
hl.bind("SUPER + SHIFT + N", function()
	hl.dispatch(float_toggle)
	hl.dispatch(pseudo)
	resize_fraction(0.5, 1.0, false)
	hl.dispatch(float_toggle)
end, { description = "Centre window at half width" })

hl.bind("SUPER + SHIFT + O", function()
	hl.dispatch(size_1080p)
	hl.dispatch(centre)
end, { description = "Resize to 1080p and centre" })

-- === Groups (tabs) ===
hl.bind("SUPER + SHIFT + G", hl.dsp.group.toggle())
hl.bind("SUPER + G",         hl.dsp.group.active({ index = "+1" }))
hl.bind("SUPER + CTRL + G",  hl.dsp.group.move_window("r"))

hl.config({
	group = {
		auto_group = false,
		col = {
			border_active   = "0xeeff4444",
			border_inactive = "0xee3b3b3b",
		},
		groupbar = {
			font_family  = "JetBrainsMono Nerd Font",
			font_size    = 14,
			height       = 14,
			text_color   = "0xeeffffff",
			col = {
				active   = "0xeeff4444",
				inactive = "0xeefaf9f6",
			},
		},
	},
})

-- === Window rules ===
hl.window_rule({ match = { class = "^(org\\.wezfurlong\\.wezterm)$" }, tile = true })
hl.window_rule({ match = { class = "^(gnome-control-center)$" }, tile = true })
hl.window_rule({ match = { class = "^(pavucontrol)$" }, tile = true })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" }, tile = true })
hl.window_rule({ match = { class = "^(org\\.gnome\\.Calculator)$" }, float = true })
hl.window_rule({ match = { class = "^(gnome-calculator)$" }, float = true })
hl.window_rule({ match = { class = "^(galculator)$" }, float = true })
hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true })
hl.window_rule({ match = { class = "^(org\\.gnome\\.Nautilus)$" }, float = true })
hl.window_rule({ match = { class = "^(xdg-desktop-portal)$" }, float = true })
hl.window_rule({ match = { class = "^(zoom)$" }, float = true })
hl.window_rule({ match = { class = "^(firefox)$", title = "^(Picture-in-Picture)$" }, float = true })
hl.window_rule({
	match = { class = "^(steam)$", title = "^(notificationtoasts)" },
	no_initial_focus = true,
	pin = true,
})

-- === Layer rules ===
hl.layer_rule({ name = "launcher-blur", match = { namespace = "launcher" }, blur = true })
hl.layer_rule({ match = { namespace = "^(quickshell)$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^dms:.*" }, no_anim = true })

-- xray blurs the bar and frame against the wallpaper, not the window under them.
hl.layer_rule({ match = { namespace = "^dms:bar$" },   xray = true })
hl.layer_rule({ match = { namespace = "^dms:frame$" }, xray = true })
