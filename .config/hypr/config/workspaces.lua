local mon = require("config.monitors")

-- === Numbered ===
-- SUPER+N is "this monitor's Nth", resolved at press time, so these are
-- closures rather than plain dispatchers.
local function on_focused(n, dispatch)
	return function()
		local ws = mon.workspace(n)
		if ws then hl.dispatch(dispatch(ws)) end
	end
end

for i = 1, mon.per_monitor do
	hl.bind("SUPER + " .. i,
		on_focused(i, function(ws) return hl.dsp.focus({ workspace = ws }) end),
		{ description = "Focus workspace " .. i .. " on the focused monitor" })
	hl.bind("SUPER + SHIFT + " .. i,
		on_focused(i, function(ws) return hl.dsp.window.move({ workspace = ws }) end),
		{ description = "Move window to workspace " .. i .. " on the focused monitor" })
end

-- === Relative ===
-- Capped to the focused monitor's block by mon.step: 1 is the floor, 9 the ceiling.
local function step_ws(delta, dispatch)
	return function()
		local ws     = hl.get_active_workspace()
		local target = ws and mon.step(ws.id, delta)
		if not target then return end
		hl.dispatch(dispatch(target))
	end
end

local function focus_ws(w) return hl.dsp.focus({ workspace = w }) end
local function carry_ws(w) return hl.dsp.window.move({ workspace = w }) end

hl.bind("SUPER + Page_Up",           step_ws(-1, focus_ws))
hl.bind("SUPER + Page_Down",         step_ws( 1, focus_ws))
hl.bind("SUPER + SHIFT + Page_Up",   step_ws(-1, carry_ws))
hl.bind("SUPER + SHIFT + Page_Down", step_ws( 1, carry_ws))

hl.bind("SUPER + mouse_up",   step_ws(-1, focus_ws))
hl.bind("SUPER + mouse_down", step_ws( 1, focus_ws))

-- === Scratchpad ===
hl.bind("SUPER + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind("SUPER + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- === Void ===
-- The last slot of each block: windows out of the way, SUPER+0 retrieves.
-- `follow = false`, never `silent = true` -- hl.dsp.* drops unknown keys.
local function void_ws()
	return mon.workspace(mon.void)
end

-- The void collects windows from monitors of different sizes, so a tiled
-- arrival takes the whole screen and shoves the rest aside. Float on the way in.
local function float_window(w)
	if w and not w.floating then
		hl.dispatch(hl.dsp.window.float({ window = "address:" .. w.address }))
	end
end

hl.bind("SUPER + SHIFT + H", function()
	local w, ws = hl.get_active_window(), void_ws()
	if not (w and ws) then return end
	float_window(w)
	hl.dispatch(hl.dsp.window.move({ window = "address:" .. w.address, workspace = ws, follow = false }))
end, { description = "Send window to the void on the focused monitor" })

-- Floating windows all land in the same spot, so cascade them for a visible corner.
local CASCADE_STEP, CASCADE_WRAP = 48, 8

local function cascade(windows)
	for i, w in ipairs(windows) do
		local n, lane = (i - 1) % CASCADE_WRAP, math.floor((i - 1) / CASCADE_WRAP)
		hl.dispatch(hl.dsp.window.move({
			window = "address:" .. w.address,
			x = CASCADE_STEP + n * CASCADE_STEP + lane * 24,
			y = CASCADE_STEP + n * CASCADE_STEP,
			exact = true,
		}))
	end
end

-- Floats on the way out too, for windows that reached the void by another route.
hl.bind("SUPER + 0", function()
	local ws = void_ws()
	if not ws then return end
	local windows = hl.get_workspace_windows(ws)
	for _, w in ipairs(windows) do float_window(w) end
	cascade(windows)
	hl.dispatch(hl.dsp.focus({ workspace = ws }))
end, { description = "Focus the void workspace on the focused monitor" })
