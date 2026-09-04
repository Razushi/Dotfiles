-- Re-home windows stranded by an undock. Everything it does is in
-- scripts/ws-rehome; this file is only the trigger.
--
--     ~/.config/hypr/scripts/ws-rehome --dry-run
--     ~/.config/hypr/scripts/ws-rehome --collapse

local HOOK = os.getenv("HOME") .. "/.config/hypr/scripts/ws-rehome-hook"

hl.on("monitor.removed", function()
	hl.exec_cmd(HOOK .. " monitor.removed")
end)
