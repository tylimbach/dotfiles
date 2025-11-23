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
if wezterm.target_triple == "x86_64-pc-windows-msvc" then
	config.default_prog = { "pwsh" }
else
	config.default_prog = { "zsh", "-l" }
end

config.audible_bell = "Disabled"

-- ============================================================================
-- Dynamic Font Switching (via Neovim font picker)
-- ============================================================================
wezterm.on("user-var-changed", function(window, pane, name, value)
	local overrides = window:get_config_overrides() or {}

	if name == "ZEN_MODE" and value then
		-- value can be like "+2" (increment), "-1" (reset), or "14" (set absolute)
		local inc = value:match("^%%+(%d+)$")
		if inc then
			local n = tonumber(inc) or 1
			for i = 1, n do
				window:perform_action(wezterm.action.IncreaseFontSize, pane)
			end
			overrides.enable_tab_bar = false
		elseif value:match("^%-") then
			-- any negative value resets
			window:perform_action(wezterm.action.ResetFontSize, pane)
			overrides.font_size = nil
			overrides.enable_tab_bar = true
		else
			local n = tonumber(value)
			if n then
				overrides.font_size = n
				overrides.enable_tab_bar = false
			end
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
	local a = appearance and appearance:lower() or ""
	if a:find("dark") then
		return "Gruvbox dark, soft (base16)"
	else
		return "Gruvbox light, soft (base16)"
	end
end

local function theme_for_appearance(appearance)
	local a = appearance and appearance:lower() or ""
	return a:find("dark") and "dark" or "light"
end

local function update_appearance(window)
	local appearance = get_appearance()
	local new_scheme = scheme_for_appearance(appearance)
	local new_theme = theme_for_appearance(appearance)

	local overrides = window:get_config_overrides() or {}
	-- if nothing to change for this window, skip work
	if
		overrides.color_scheme == new_scheme
		and overrides.set_environment_variables
		and overrides.set_environment_variables.NVIM_THEME == new_theme
	then
		return
	end

	overrides.color_scheme = new_scheme
	local env = overrides.set_environment_variables or {}
	env.NVIM_THEME = new_theme
	overrides.set_environment_variables = env

	window:set_config_overrides(overrides)

	-- Force redraw of all panes
	local mux = wezterm.mux
	for _, win in ipairs(mux.get_windows()) do
		for _, tab in ipairs(win:tabs()) do
			for _, pane in ipairs(tab:panes()) do
				pane:send_key({ key = "l", mods = "CTRL" })
			end
		end
	end
end

-- Update appearance on config reload and status refresh
wezterm.on("window-config-reloaded", update_appearance)
wezterm.on("update-right-status", update_appearance)
-- Also handle system appearance changes (Light/Dark) and force redraws
wezterm.on("appearance_changed", function(appearance)
	local theme = scheme_for_appearance(appearance)
	local ntheme = theme_for_appearance(appearance)
	for _, win in ipairs(wezterm.mux.get_windows()) do
		local overrides = win:get_config_overrides() or {}
		if
			overrides.color_scheme ~= theme
			or not (overrides.set_environment_variables and overrides.set_environment_variables.NVIM_THEME == ntheme)
		then
			overrides.color_scheme = theme
			local env = overrides.set_environment_variables or {}
			env.NVIM_THEME = ntheme
			overrides.set_environment_variables = env
			win:set_config_overrides(overrides)
			-- force a redraw of panes in this window
			for _, tab in ipairs(win:tabs()) do
				for _, pane in ipairs(tab:panes()) do
					pane:send_key({ key = "l", mods = "CTRL" })
				end
			end
		end
	end
end)

-- Set initial appearance
local appearance = get_appearance()
config.color_scheme = scheme_for_appearance(appearance)
config.set_environment_variables = config.set_environment_variables or {}
config.set_environment_variables.NVIM_THEME = theme_for_appearance(appearance)

return config
