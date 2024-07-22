--[[
1. clean install neovim / wezterm 
2. wingit install ripgrep
3. install luarocks
--]]

local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- appearance
config.font = wezterm.font({
	family = "Iosevka Nerd Font",
	harfbuzz_features = { "ss08", "liga" },
})
config.font_size = 16

config.color_scheme = "rose-pine-dawn"
config.color_scheme = "zenbones"

-- program
config.default_prog = { "C:/Program Files/Git/bin/bash.exe" }
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

return config

