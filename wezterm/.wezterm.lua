local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- config.font = wezterm.font({
-- 	-- family = "Iosevka Term Slab",
-- 	-- family = "CaskaydiaCove Nerd Font",
-- 	-- family = "MonoLisa",
-- 	-- family = "Berkeley Mono",
-- 	-- family = "Monaspace Argon",
-- 	-- family = "Monaspace Neon",
-- 	-- family = "DejaVuSansM Nerd Font",
-- 	-- family = "CommitMono",
-- 	-- family = "Operator Mono",
-- 	-- family = "Operator Mono Lig",
-- 	-- family = "FiraCode Nerd Font",
-- })

config.wsl_domains = {
  {
    name = "WSL:Ubuntu",
    distribution = "Ubuntu-22.04",
  },
}
-- config.default_domain = "WSL:Ubuntu"

config.font = wezterm.font_with_fallback {
	{
		family = 'MonoLisa',
		harfbuzz_features = {
			-- liga - Coding ligatures
			-- "liga",

			-- frac - Fractions, turns 1/2 into ½
			-- "frac",

			-- onum - Old style numbers
			-- "onum",

			-- calt - Whitespace ligatures
			"calt",

			-- zero - Slashed zero
			-- "zero",

			-- ss01 - Normal asterisk
			-- "ss01",

			-- ss02 - Italic Script Version
			-- "ss02",

			-- ss03 - Alternative g
			-- "ss03",

			-- ss04 - Other alternative g
			-- "ss04",

			-- ss05 - Alternative ß
			-- "ss05",

			-- ss06 - Alternative @
			-- "ss06",

			-- ss07 - Alternative curly brackets {}
			-- "ss07",

			-- ss08 - Alternative parenthesis ()
			-- "ss08",

			-- ss09 - Alternative >= ligature
			-- "ss09",

			-- ss10 - Other alternative >= ligature
			-- "ss10",

			-- ss11 - Centered hexadecimal x 0xF
			-- "ss11",

			-- ss12 - Thin backslash
			-- "ss12",

			-- ss13 - Alternative $
			-- "ss13",

			-- ss14 - Alternative &
			-- "ss14",

			-- ss15 - i without serif
			-- "ss15",

			-- ss16 - r without serif
			-- "ss16",

			-- ss17 - Alternative .= and ..= ligature
			-- "ss17",

			-- ss18 - Alternative @
			-- "ss18",
		},
	},
	{
		family = 'Iosevka Nerd Font',
		harfbuzz_features = { "liga", "calt", "ss03"},
	},
	{
		family = 'Monaspace Argon',
		harfbuzz_features = { "liga", "calt", "ss01", "ss02", "ss03", "ss04", "ss05", "ss06", "ss07", "ss08", "ss09" },
	},
	'Operator Mono Lig',
	'Berkeley Mono',
	'Operator Mono Medium',
	'Operator Mono Bold',
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
  {
    key = 'w',
    mods = 'CTRL',
    action = wezterm.action.CloseCurrentPane { confirm = false },
  },
    {
      key = "f",
      mods = "CTRL|CMD",
      action = wezterm.action.ToggleFullScreen,
    },
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

config.color_scheme = scheme_for_appearance(get_appearance())

return config
