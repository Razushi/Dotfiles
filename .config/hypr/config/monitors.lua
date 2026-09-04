-- Monitor identity, keyed by description rather than connector: connectors renumber.

local M = {}

-- The "description" field of `hyprctl monitors`.
M.desc = {
	main = "ViewSonic Corporation VX3218C-QHD X1J234600746",
	side = "Microstep MSI G273 CA7A471A00224",
	lap  = "Lenovo Group Limited 0x403D",
}

-- Position here decides the ID range: append, never insert.
M.order = { "main", "side", "lap" }

M.sel = {}
for prefix, desc in pairs(M.desc) do
	M.sel[prefix] = "desc:" .. desc
end

-- One block of IDs per monitor: main 1-9, side 11-19, lap 21-29.
M.per_monitor = 9
M.stride      = 10

-- Last slot of each block: the void, for parking windows out of the way.
M.void = 10

-- First N of each block are created at config load, so bar order is stable.
M.persistent = 5

M.base = {}
for i, prefix in ipairs(M.order) do
	M.base[prefix] = (i - 1) * M.stride
end

-- Block start for a monitor. Unlisted screens are parked past the known blocks.
function M.base_for(monitor)
	if not monitor then return nil end
	for prefix, desc in pairs(M.desc) do
		if monitor.description == desc then return M.base[prefix] end
	end
	return (#M.order + (monitor.id or 0)) * M.stride
end

-- This monitor's Nth workspace, for whichever monitor is focused right now.
function M.workspace(n, monitor)
	local base = M.base_for(monitor or hl.get_active_monitor())
	if not base then return nil end
	return base + n
end

-- Step from workspace `id` by `delta` without leaving the focused monitor's
-- block. Returns nil at either end, which callers treat as "stay put".
function M.step(id, delta, monitor)
	-- Special workspaces (negative ids) are not part of any block.
	if not id or id < 0 then return nil end

	local base = M.base_for(monitor or hl.get_active_monitor())
	if not base then return nil end

	local n = id - base
	if n < 1 or n > M.per_monitor then
		-- Outside this monitor's block: step back onto it.
		return base + 1
	end

	local target = n + delta
	if target < 1 or target > M.per_monitor then return nil end
	return base + target
end

return M
