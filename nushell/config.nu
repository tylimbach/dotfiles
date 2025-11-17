alias zja = zellij attach -c main
alias zjn = zellij

def --env y [...args] {
	let tmp = (mktemp -t "yazi-cwd.XXXXXX")
	yazi ...$args --cwd-file $tmp
	let cwd = (open $tmp)
	if $cwd != "" and $cwd != $env.PWD {
		cd $cwd
	}
	rm -f $tmp
}

def --env alacritty-theme [theme: string] {
	let is_windows = ($nu.os-info.name == 'Windows')

	let config_dir = if $is_windows {
		$"($env.APPDATA)/alacritty"
	} else {
		$"($env.HOME)/.config/alacritty"
	}

	let themes_dir  = $"($config_dir)/themes"
	let target_path = $"($config_dir)/alacritty.toml"
	let theme_path  = $"($themes_dir)/gruvbox_($theme).toml"

	if not ($theme_path | path exists) {
		print $"[alacritty] theme not found: ($theme_path)"
		return
	}

	if not ($themes_dir | path exists) {
        mkdir $themes_dir
    }

	# Remove existing target (file or symlink)
	if ($target_path | path exists) {
		rm -f $target_path
	}

	if $is_windows {
		# copy on Windows (symlinks are annoying)
		cp $theme_path $target_path
	} else {
		# symlink on Unix
		ln -s $theme_path $target_path
	}

	print $"[alacritty] switched to gruvbox_($theme)"
}

def set-zellij-theme [mode: string] {
	let cfg = ($nu.home-path | path join ".config" "zellij" "config.kdl")

	if not ($cfg | path exists) {
		return
	}

	let new_theme_line = (
		if $mode == "dark" {
			'theme "gruvbox-dark"'
		} else {
			'theme "gruvbox-light"'
		}
	)

	open $cfg
	| lines
	| each { |l|
		if ($l | str starts-with 'theme "') {
			$new_theme_line
		} else {
			$l
		}
	}
	| str join "\n"
	| save -f $cfg
}


def --env aladark [] {
	alacritty-theme "dark"
	dark apply
	set-zellij-theme "dark"
}
def --env alalight [] {
	alacritty-theme "dark"
	dark apply
	set-zellij-theme "dark"
}

use ($nu.config-path | path dirname | path join "gruvbox-dark.nu") *
use ($nu.config-path | path dirname | path join "gruvbox-light.nu") *

def --env switch_theme [] {
    const dark_theme = 1
    const light_theme = 2
    let system_theme = term query "\e[?996n" --prefix "\e[?997;" --terminator "n" | decode | into int

    if $system_theme == $dark_theme {
		set-theme-dark
    } else if $system_theme == $light_theme {
        set-theme-light
    } else {
        let error_msg = "Unknown system theme returned from terminal: " + ($system_theme | into string)
        error make {msg: $error_msg }
    }
}

# disable the hook for now to change themes
# $env.config.hooks = (
# 	$env.config.hooks
# 	| upsert pre_execution [switch_theme]
# )
