local terminal     = "ghostty +new-window"
local file_manager = "dolphin"
local launcher     = "vicinae vicinae://toggle"

-- === Launch ===
hl.bind("SUPER + Q", hl.dsp.exec_cmd(terminal),     { description = "Terminal" })
hl.bind("SUPER + E", hl.dsp.exec_cmd(file_manager), { description = "File manager" })
hl.bind("SUPER + R", hl.dsp.exec_cmd(launcher),     { description = "Launcher" })

-- === Daemons ===
hl.on("hyprland.start", function()
	hl.exec_cmd("vicinae server")
end)
