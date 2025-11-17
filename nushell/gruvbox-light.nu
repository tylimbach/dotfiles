export def set-theme-light [] {
	let bg0 = "#fbf1c7"
	let bg1 = "#ebdbb2"
	let bg2 = "#d5c4a1"
	let bg3 = "#bdae93"
	let fg0 = "#3c3836"
	let fg1 = "#504945"
	let red = "#9d0006"
	let orange = "#af3a03"
	let yellow = "#b57614"
	let green = "#79740e"
	let aqua = "#427b58"
	let blue = "#076678"
	let purple = "#8f3f71"
	let gray = "#7c6f64"

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
		$env.LS_COLORS = (vivid generate gruvbox-light)
	}
}

