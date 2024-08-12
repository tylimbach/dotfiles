local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- appearance
config.font = wezterm.font({
	family = "Iosevka Nerd Font",
	harfbuzz_features = { "liga", "ss08" },
})
config.freetype_load_target = "HorizontalLcd"
config.font_size = 15
config.line_height = 1.00
config.max_fps = 120

config.window_background_opacity = 0.95
config.adjust_window_size_when_changing_font_size = false

-- default cli program
if wezterm.target_triple == "x86_64-pc-windows-msvc" then
	config.default_prog = { "C:/Program Files/Git/bin/bash.exe" }
end
config.audible_bell = "Disabled"

-- zen mode neovim fix
wezterm.on("user-var-changed", function(window, pane, name, value)
	local overrides = window:get_config_overrides() or {}
	if name == "ZEN_MODE" then
		local incremental = value:find("+")
		local number_value = tonumber(value)
		if incremental ~= nil then
			while number_value > 0 do
				window:perform_action(wezterm.action.IncreaseFontSize, pane)
				number_value = number_value - 1
			end
			overrides.enable_tab_bar = false
		elseif number_value < 0 then
			window:perform_action(wezterm.action.ResetFontSize, pane)
			overrides.font_size = nil
			overrides.enable_tab_bar = true
		else
			overrides.font_size = number_value
			overrides.enable_tab_bar = false
		end
	end
	window:set_config_overrides(overrides)
end)

-- color schemes
function scheme_for_appearance(appearance)
	if appearance:find("Dark") then
		return "GruvboxDark"
	else
		return "GruvboxLight"
	end
end

wezterm.on("window-config-reloaded", function(window, pane)
	local overrides = window:get_config_overrides() or {}
	local appearance = window:get_appearance()
	local scheme = scheme_for_appearance(appearance)
	if overrides.color_scheme ~= scheme then
		overrides.color_scheme = scheme
		window:set_config_overrides(overrides)
	end
end)

return config
