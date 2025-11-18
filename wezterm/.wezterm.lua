local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- ============================================================================
-- WSL Configuration
-- ============================================================================
config.wsl_domains = {
	{
		name = "WSL:Ubuntu",
		distribution = "Ubuntu-24.04",
	},
}

-- ============================================================================
-- Font Configuration
-- ============================================================================
local default_fonts = {
	"Operator Mono Medium",
	"Operator Mono Book",
	"Operator Mono Bold",
	"Monaspace Krypton NF",
}

config.font = wezterm.font_with_fallback(default_fonts)
config.font_size = 10
config.force_reverse_video_cursor = true

-- ============================================================================
-- Display Settings
-- ============================================================================
config.line_height = 1.0
config.window_background_opacity = 1.00
config.adjust_window_size_when_changing_font_size = false

-- ============================================================================
-- Key Bindings
-- ============================================================================
config.keys = {
	-- Disable Ctrl-W so Neovim can use it for window commands
	{
		key = "w",
		mods = "CTRL",
		action = wezterm.action.DisableDefaultAssignment,
	},

	{
		key = "Enter",
		mods = "SHIFT",
		action = wezterm.action({ SendString = "\x1b\r" }),
	},
	-- Use Ctrl-Shift-W to close the current pane/tab instead
	{
		key = "w",
		mods = "CTRL|SHIFT",
		action = wezterm.action.CloseCurrentPane({ confirm = true }),
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
		action = wezterm.action.SendKey({ key = "/", mods = "CTRL" }),
	},
	-- Pass Ctrl+Space through to Neovim
	{
		key = " ",
		mods = "CTRL",
		action = wezterm.action.SendKey({ key = " ", mods = "CTRL" }),
	},
	-- Toggle pane zoom
	{
		key = "z",
		mods = "CTRL",
		action = wezterm.action.TogglePaneZoomState,
	},
	{
		key = "r",
		mods = "CTRL|SHIFT",
		action = wezterm.action.RotatePanes("Clockwise"),
	},
}

-- ============================================================================
-- Platform-Specific Configuration
-- ============================================================================
-- config.default_prog = { "nu" }
-- if wezterm.target_triple == "x86_64-pc-windows-msvc" then
-- 	config.default_prog = { "C:/Program Files/Git/bin/bash.exe" }
-- end

config.audible_bell = "Disabled"

-- ============================================================================
-- Dynamic Font Switching (via Neovim font picker)
-- ============================================================================
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
	elseif name == "WEZTERM_FONT" then
		if value and value ~= "" and value ~= "RESET" then
			-- Build new font list with selected font first, then fallback to defaults
			local new_fallback = { value }
			for _, font in ipairs(default_fonts) do
				local font_name = type(font) == "string" and font or font.family
				if font_name ~= value then
					table.insert(new_fallback, font)
				end
			end
			overrides.font = wezterm.font_with_fallback(new_fallback)
		elseif value == "RESET" then
			overrides.font = nil
		end
	end

	window:set_config_overrides(overrides)
end)

-- ============================================================================
-- Theme & Appearance Management
-- ============================================================================
local function get_appearance()
	if wezterm.gui then
		return wezterm.gui.get_appearance()
	end
	return "Dark"
end

local function scheme_for_appearance(appearance)
	if appearance:find("Dark") then
		return "Gruvbox dark, soft (base16)"
	else
		return "Gruvbox light, soft (base16)"
	end
end

local function theme_for_appearance(appearance)
	return appearance:find("Dark") and "dark" or "light"
end

local function update_appearance(window)
	local appearance = get_appearance()
	local overrides = window:get_config_overrides() or {}
	overrides.color_scheme = scheme_for_appearance(appearance)
	overrides.set_environment_variables = {
		NVIM_THEME = theme_for_appearance(appearance),
	}
	window:set_config_overrides(overrides)
end

-- Update appearance on config reload and status refresh
wezterm.on("window-config-reloaded", update_appearance)
wezterm.on("update-right-status", update_appearance)

-- Set initial appearance
local appearance = get_appearance()
config.color_scheme = scheme_for_appearance(appearance)
config.set_environment_variables = {
	NVIM_THEME = theme_for_appearance(appearance),
}

return config
