-- === Environment ===
hl.env("__GL_GSYNC_ALLOWED", "1")
hl.env("__GL_VRR_ALLOWED", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct:qt6ct")

-- === Startup ===
hl.on("hyprland.start", function()
	hl.exec_cmd("systemctl --user start nixos-fake-graphical-session.target")
	hl.exec_cmd("dms run")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	hl.exec_cmd("hyprctl setcursor BreezeX-Dark-hyprcursor 32")
	hl.exec_cmd("hyprctl dispatch workspace 1")
end)

-- === Lock and exit ===
hl.bind("SUPER + ALT + L",   hl.dsp.exec_cmd("hyprlock"))
hl.bind("SUPER + SHIFT + L", hl.dsp.dpms({ action = "off" }), { description = "Blank the monitors" })
hl.bind("SUPER + SHIFT + M", hl.dsp.exit())
hl.bind("CTRL + ALT + Delete", hl.dsp.exit())

-- === Screen capture ===
hl.bind("SUPER + Print",         hl.dsp.exec_cmd("sh -c 'grimblast --freeze save area - | swappy -f -'"))
hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd("grimblast --notify --freeze save screen"))

hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("sh -c 'wl-paste | tesseract stdin stdout | wl-copy'"),
	{ description = "OCR the clipboard" })

-- === Shell panels ===
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("vicinae vicinae://extensions/vicinae/clipboard/history"),
	{ description = "Clipboard history" })
hl.bind("SUPER + CTRL + O",  hl.dsp.exec_cmd("dms ipc call notifications toggle"))
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("dms ipc call hypr toggleOverview"))
hl.bind("SUPER + SHIFT + slash", hl.dsp.exec_cmd("dms ipc call keybinds toggle hyprland"),
	{ description = "Keybind cheat sheet" })
hl.bind("SUPER + comma", hl.dsp.exec_cmd("dms ipc call settings focusOrToggle"))
hl.bind("SUPER + X",     hl.dsp.exec_cmd("dms ipc call powermenu toggle"))

-- hl.bind("SUPER + SHIFT + X", hl.dsp.exec_cmd(
-- \t[[kitty --title="Launch Scripts" "/path/to/Launch-Scripts.sh"]]), { float = true })
