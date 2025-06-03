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
	local -n spec__E057TG="$1"
	local tpm_async="${2:-true}"

	local plugin_path="$(plugin_get_dir spec__E057TG)"
	local plugin_tmux_files="${plugin_path}/*.tmux"

	if ! plugin_dir_exists "$plugin_path"; then
		return
	fi

	for tmux_file in "${plugin_path}/"*".tmux"; do
		# if the glob didn't find any files this will be the
		# unexpanded glob which obviously doesn't exist
		[ -f "$tmux_file" ] || continue

		local async="$tpm_async"
		[[ -n ${spec__E057TG[async]} ]] \
			&& async="${spec__E057TG[async]}"

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
	local tpm_async="$(get_tmux_option "@tpm_async" "true")"
	local specs="$(tpm_plugins_list_helper)"

	local spec_str
	for spec_str in $specs; do
		local -A spec
		plugin_parse_spec spec "$spec_str"

		silently_source_all_tmux_files spec "$tpm_async"
	done

	wait
}

main() {
	source_plugins
}
main
