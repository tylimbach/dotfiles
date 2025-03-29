local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.font = wezterm.font({
	family = "Iosevka Term Slab",
	-- family = "CaskaydiaCove Nerd Font",
	-- family = "MonoLisa",
	-- family = "Berkeley Mono Trial",
	-- family = "DejaVuSansM Nerd Font",
	-- family = "CommitMono",
	-- family = "Operator Mono",
	-- family = "Operator Mono Lig",
	-- family = "FiraCode Nerd Font",
	harfbuzz_features = { "liga" },
})
config.font_size = 12

-- config.freetype_load_flags = "NO_HINTING"
config.front_end = "OpenGL"
config.freetype_load_target = "HorizontalLcd"
config.max_fps = 120
config.line_height = 1.0

config.window_background_opacity = 1.00
config.adjust_window_size_when_changing_font_size = false

if wezterm.target_triple == "x86_64-pc-windows-msvc" then
	config.default_prog = { "C:/Program Files/Git/bin/bash.exe" }
end
config.audible_bell = "Disabled"

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

local function scheme_for_appearance(appearance)
	if appearance:find 'Dark' then
		return "Gruvbox dark, soft (base16)"
	else
		return "Gruvbox light, soft (base16)"
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
