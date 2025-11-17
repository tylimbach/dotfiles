export def set-theme-dark [] {
	let bg0 = "#282828"
	let bg1 = "#3c3836"
	let bg2 = "#504945"
	let bg3 = "#665c54"
	let fg0 = "#ebdbb2"
	let fg1 = "#d5c4a1"
	let red = "#fb4934"
	let orange = "#fe8019"
	let yellow = "#fabd2f"
	let green = "#b8bb26"
	let aqua = "#8ec07c"
	let blue = "#83a598"
	let purple = "#d3869b"
	let gray = "#928374"

	let theme = {
		separator: $gray
		leading_trailing_space_bg: $bg2
		header: $green
		datetime: $blue
		filesize: $aqua
		row_index: $aqua
		bool: $orange
		int: $purple
		duration: $yellow
		range: $yellow
		float: $purple
		string: $fg1
		nothing: $red
		binary: $red
		cell-path: $aqua
		hints: $gray

		shape_garbage: { fg: "#ffffff" bg: $red attr: b }
		shape_bool: $green
		shape_int: { fg: $purple attr: b }
		shape_float: { fg: $purple attr: b }
		shape_range: { fg: $yellow attr: b }
		shape_internalcall: { fg: $aqua attr: b }
		shape_external: $aqua
		shape_externalarg: { fg: $yellow attr: b }
		shape_literal: $blue
		shape_operator: $orange
		shape_signature: { fg: $green attr: b }
		shape_string: $green
		shape_filepath: $blue
		shape_globpattern: { fg: $blue attr: b }
		shape_variable: $purple
		shape_flag: { fg: $blue attr: b }
		shape_custom: { attr: b }
		shape_nothing: $aqua
		shape_list: { fg: $aqua attr: b }
		shape_record: { fg: $aqua attr: b }
		shape_table: { fg: $blue attr: b }
		shape_pipe: { fg: $purple attr: b }
		shape_string_interpolation: { fg: $aqua attr: b }
	}

	$env.config = (
		$env.config
		| upsert color_config $theme
		| upsert table { mode: "rounded" }
		| upsert ls { use_ls_colors: true }
		| upsert use_ansi_coloring true
	)

	if not (which vivid | is-empty) {
		$env.LS_COLORS = (vivid generate gruvbox-dark)
	}
}

