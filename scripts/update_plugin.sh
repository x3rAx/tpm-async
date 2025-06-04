#!/usr/bin/env bash

# this script handles core logic of updating plugins

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HELPERS_DIR="$CURRENT_DIR/helpers"

source "$HELPERS_DIR/plugin_functions.sh"
source "$HELPERS_DIR/utility.sh"

if [ "$1" == "--tmux-echo" ]; then # tmux-specific echo functions
	source "$HELPERS_DIR/tmux_echo_functions.sh"

	# from now on ignore first script argument
	shift
else # shell output functions
	source "$HELPERS_DIR/shell_echo_functions.sh"
fi


pull_changes() {
	local plugin="$1"
	local plugin_path="$(plugin_path_helper "$plugin")"
	cd "$plugin_path" &&
		GIT_TERMINAL_PROMPT=0 git pull &&
		GIT_TERMINAL_PROMPT=0 git submodule update --init --recursive
}

update() {
	local plugin="$1" output
	output=$(pull_changes "$plugin" 2>&1)
	if (( $? == 0 )); then
		echo_ok "  \"$plugin\" update success"
		echo_ok "$(echo "$output" | sed -e 's/^/    | /')"
	else
		echo_err "  \"$plugin\" update fail"
		echo_err "$(echo "$output" | sed -e 's/^/    | /')"
	fi
}

update_all() {
	echo_ok "Updating all plugins!"
	echo_ok ""

	local specs="$(tpm_plugins_list_helper)"

	for spec_str in $specs; do
		local -A spec
		plugin_parse_spec spec "$spec_str"

		local name="$(plugin_get_name spec)"

		# updating only installed plugins
		if plugin_already_installed "$name"; then
			update "$name" &
		fi
	done

	wait
}

update_plugins() {
	local plugins="$@"

	for plugin in "${plugins[@]}"; do
		IFS=';' read -ra plugin <<< "$plugin"
		IFS='#' read -ra plugin <<< "${plugin[0]}"
		local plugin_name="$(plugin_name_helper "${plugin[0]}")"
		if plugin_already_installed "$plugin_name"; then
			update "$plugin_name" &
		else
			echo_err "$plugin_name not installed!" &
		fi
	done

	wait
}

main() {
	ensure_tpm_path_exists
	if [ "$1" == "all" ]; then
		update_all
	else
		update_plugins "$@"
	fi
	exit_value_helper
}
main "$@"
