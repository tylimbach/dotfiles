local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.wsl_domains = {
	{
		name = "WSL:Ubuntu",
		distribution = "Ubuntu-22.04",
	},
}

config.font = wezterm.font_with_fallback {
	'Operator Mono Medium',
	'Operator Mono Book',
	'Operator Mono Bold',
	'Operator Mono Lig',
	'CaskaydiaCove Nerd Font',
	'UnifontExMono',
	'JuliaMono',
	-- 'Berkeley Mono',
	-- 'Iosevka Nerd Font',
	{
		family = 'Iosevka Nerd Font',
		harfbuzz_features = { "liga", "calt", "ss03" },
	},
}
config.font_size = 12
config.force_reverse_video_cursor = true

-- config.freetype_load_flags = "NO_HINTING"
-- config.enable_wayland = false
-- config.front_end = "OpenGL"
-- config.freetype_load_target = "HorizontalLcd"
config.max_fps = 120
config.line_height = 1.0

config.window_background_opacity = 1.00
config.adjust_window_size_when_changing_font_size = false

config.keys = {
	-- Disable Ctrl-W so Neovim can use it for window commands
	{
		key = 'w',
		mods = 'CTRL',
		action = wezterm.action.DisableDefaultAssignment,
	},
	-- Use Ctrl-Shift-W to close the current pane/tab instead
	{
		key = 'w',
		mods = 'CTRL|SHIFT',
		action = wezterm.action.CloseCurrentPane { confirm = true },
	},
	-- Shift-Enter sends Escape+Enter (useful for some terminals)
	{
		key = "Enter",
		mods = "SHIFT",
		action = wezterm.action.SendString("\x1b\r"),
	},
	-- Toggle fullscreen
	{
		key = "f",
		mods = "CTRL|CMD",
		action = wezterm.action.ToggleFullScreen,
	},
	-- Pass Ctrl+/ through to Neovim (Windows compatibility)
	{
		key = "/",
		mods = "CTRL",
		action = wezterm.action.SendKey { key = "/", mods = "CTRL" },
	},
	{
		key = ' ',
		mods = 'CTRL',
		action = wezterm.action.SendKey { key = ' ', mods = 'CTRL' },
	},
	{
		key = 'z',
		mods = 'CTRL',
		action = wezterm.action.TogglePaneZoomState,
	}
}

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

local function get_appearance()
	if wezterm.gui then
		return wezterm.gui.get_appearance()
	end
	return 'Dark'
end

local function scheme_for_appearance(appearance)
	if appearance:find 'Dark' then
		return "Gruvbox dark, soft (base16)"
	else
		return "Gruvbox light, soft (base16)"
	end
end

local function update_appearance(window)
	local appearance = get_appearance()
	local theme = appearance:find('Dark') and 'dark' or 'light'
	local scheme = scheme_for_appearance(appearance)
	local overrides = window:get_config_overrides() or {}
	overrides.color_scheme = scheme
	overrides.set_environment_variables = {
	  NVIM_THEME = theme,
	}
	window:set_config_overrides(overrides)
end

wezterm.on('window-config-reloaded', update_appearance)

-- Also update on status refresh to catch appearance changes
wezterm.on('update-right-status', update_appearance)

-- Set NVIM_THEME environment variable for child processes (like Neovim)
local appearance = get_appearance()
config.color_scheme = scheme_for_appearance(appearance)
local theme = appearance:find('Dark') and 'dark' or 'light'
config.set_environment_variables = {
  NVIM_THEME = theme,
}

return config
