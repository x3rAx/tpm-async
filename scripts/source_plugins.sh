#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HELPERS_DIR="$CURRENT_DIR/helpers"

source "$HELPERS_DIR/plugin_functions.sh"
source "$HELPERS_DIR/tmux_utils.sh"

plugin_dir_exists() {
	[ -d "$1" ]
}

# Runs all *.tmux files from the plugin directory.
# Files are ran as executables.
# No errors if the plugin dir does not exist.
silently_source_all_tmux_files() {
	local plugin_path="$1"
	local plugin_tmux_files="$plugin_path*.tmux"
	local async="$(get_tmux_option "@tpm_async" "true")"

	if ! plugin_dir_exists "$plugin_path"; then
		return
	fi

	for tmux_file in $plugin_tmux_files; do
		# if the glob didn't find any files this will be the
		# unexpanded glob which obviously doesn't exist
		[ -f "$tmux_file" ] || continue

		if [[ $async == 'false' ]]; then
			# runs *.tmux file as an executable
			$tmux_file >/dev/null 2>&1
		else
			# runs *.tmux file asynchronously as an executable
			$tmux_file >/dev/null 2>&1 &
		fi
	done
}

source_plugins() {
	local plugin plugin_path
	local plugins="$(tpm_plugins_list_helper)"
	for plugin in $plugins; do
		IFS='#' read -ra plugin <<< "$plugin"
		plugin_path="$(plugin_path_helper "${plugin[0]}")"
		silently_source_all_tmux_files "$plugin_path"
	done
}

main() {
	source_plugins
}
main
