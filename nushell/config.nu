# zellij
alias zja = zellij attach -c main
alias zjn = zellij

def set-zellij-theme [mode: string] {
    # Cross-platform Zellij config path
    let cfg = if $nu.os-info.name == "Windows" {
        ($env.APPDATA | path join "zellij" "config.kdl")
    } else {
        ($nu.home-path | path join ".config" "zellij" "config.kdl")
    }

    if not ($cfg | path exists) {
        print "[zellij] config not found: $cfg"
        return
    }

    let new_line = if $mode == "dark" {
        'theme "gruvbox-dark"'
    } else {
        'theme "gruvbox-light"'
    }

    # Load entire config as string
    let old = (open $cfg | into string)

    # Replace ANY existing theme line (greedy, safe)
    let updated = ($old | str replace -r 'theme\s*"[^"]+"' $new_line)

    # Save the file
    $updated | save -f $cfg

    print $"[zellij] switched to: ($mode)"
}

# yazi
def --env y [...args] {
	let tmp = if $nu.os-info.name == "Windows" {
		# Windows uses a different mktemp
		($env.TEMP | path join ("yazi-cwd-" + (random uuid) + ".tmp"))
	} else {
		mktemp -t "yazi-cwd.XXXXXX"
	}

	yazi ...$args --cwd-file $tmp
	let cwd = (open $tmp)

	if $cwd != "" and $cwd != $env.PWD {
		cd $cwd
	}

	rm $tmp
}

# alacritty
def --env set-alacritty-theme [theme: string] {
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

use ($nu.default-config-dir | path join "gruvbox-dark.nu") *
use ($nu.default-config-dir | path join "gruvbox-light.nu") *

def --env aladark [] {
    set-alacritty-theme dark
    set-theme-dark
    set-zellij-theme "dark"
}

def --env alalight [] {
    set-alacritty-theme light
    set-theme-light
    set-zellij-theme "light"
}

# disable the hook for now to change themes
# def --env switch_theme [] {
#     const dark_theme = 1
#     const light_theme = 2
#     let system_theme = term query "\e[?996n" --prefix "\e[?997;" --terminator "n" | decode | into int
#
#     if $system_theme == $dark_theme {
# 		set-theme-dark
#     } else if $system_theme == $light_theme {
#         set-theme-light
#     } else {
#         let error_msg = "Unknown system theme returned from terminal: " + ($system_theme | into string)
#         error make {msg: $error_msg }
#     }
# }
#
# $env.config.hooks = (
# 	$env.config.hooks
# 	| upsert pre_execution [switch_theme]
# )
