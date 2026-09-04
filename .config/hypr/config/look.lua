-- === Knobs ===
local ACCENT      = "rgba(ff4444ff)"
local INACTIVE    = "rgba(2f2f2fff)"
local GAPS_IN     = 4
local GAPS_OUT    = 8
local BORDER_SIZE = 1
local ROUNDING    = 3

-- === General ===
hl.config({
	general = {
		gaps_in     = GAPS_IN,
		gaps_out    = GAPS_OUT,
		border_size = BORDER_SIZE,

		col = {
			active_border   = ACCENT,
			inactive_border = INACTIVE,
		},

		resize_on_border = false,

		-- Read https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before enabling
		allow_tearing = false,

		layout = "dwindle",
	},

	-- === Decoration ===
	decoration = {
		rounding       = ROUNDING,
		rounding_power = 6,

		active_opacity   = 1,
		inactive_opacity = 0.98,

		dim_special = 0.0,

		shadow = {
			enabled      = true,
			range        = 30,
			render_power = 3,
			color        = "rgba(00000066)", -- Keep at #181818 because alt looks bad with group:groupbar
		},

		blur = {
			enabled  = true,
			size     = 3,
			passes   = 1,
			vibrancy = 0.1696,
		},
	},
})

-- === Animation curves ===
hl.curve("myBezier",       { type = "bezier", points = { {0.1, 1},     {0.1, 1}   } })
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}  } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}  } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}     } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1.0}} })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}   } })

-- === Animations ===
hl.config({
	animations = {
		enabled = true,
	},
})

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 2.94, bezier = "easeOutQuint", style = "slidevert" })

-- === Misc ===
hl.config({
	misc = {
		force_default_wallpaper = -1,    -- 0/1 to disable mascot wallpapers
		disable_hyprland_logo   = false,
	},
})
