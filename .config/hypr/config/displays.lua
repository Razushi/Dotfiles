local mon = require("config.monitors")

-- === Monitor layout ===
-- cizhi owns it. `cizhi status` / `cizhi apply` / `cizhi watch`.
-- What is left here is the catch-all: anything plugged in lights up at its
-- preferred mode, side by side.
local connected = {}
for _, m in ipairs(hl.get_monitors()) do
	for prefix, desc in pairs(mon.desc) do
		if m.description == desc then
			connected[prefix] = true
		end
	end
end

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- === Workspace placement ===
-- Each monitor owns a block, pinned by description. default_name keeps the bar
-- readable: the ID stays globally unique, every monitor labels its own block 1..9.
-- Only screens actually plugged in get persistent workspaces.
local is_active = connected

for _, prefix in ipairs(mon.order) do
	for i = 1, mon.per_monitor do
		local rule = {
			workspace    = mon.base[prefix] + i,
			monitor      = mon.sel[prefix],
			default_name = tostring(i),
		}
		if is_active[prefix] and i <= mon.persistent then
			rule.persistent = true
		end
		hl.workspace_rule(rule)
	end

	-- The void slot: same screen, never persistent. Ruling it stops an unclaimed
	-- ID between blocks from sorting to the front of the next one.
	hl.workspace_rule({
		workspace    = mon.base[prefix] + mon.void,
		monitor      = mon.sel[prefix],
		default_name = "0",
	})
end

-- === Monitor navigation ===
hl.bind("SUPER + CTRL + left",          hl.dsp.focus({ monitor = "l" }))
hl.bind("SUPER + CTRL + right",         hl.dsp.focus({ monitor = "r" }))
hl.bind("SUPER + CTRL + SHIFT + left",  hl.dsp.window.move({ monitor = "l" }))
hl.bind("SUPER + CTRL + SHIFT + right", hl.dsp.window.move({ monitor = "r" }))
