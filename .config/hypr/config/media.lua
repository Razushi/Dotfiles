local locked     = { locked = true }
local held       = { locked = true, repeating = true }

-- === Volume ===
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),   held)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),   held)
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   locked)
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), locked)

-- === Brightness ===
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd([[dms ipc call brightness increment 5 ""]]), held)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd([[dms ipc call brightness decrement 5 ""]]), held)

-- === Playback ===
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       locked)
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   locked)
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), locked)
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), locked)
