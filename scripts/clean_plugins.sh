#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HELPERS_DIR="$CURRENT_DIR/helpers"

source "$HELPERS_DIR/plugin_functions.sh"
source "$HELPERS_DIR/utility.sh"

if [ "$1" == "--tmux-echo" ]; then # tmux-specific echo functions
	source "$HELPERS_DIR/tmux_echo_functions.sh"
else # shell output functions
	source "$HELPERS_DIR/shell_echo_functions.sh"
fi

_get_installed_plugin_names() {
	local plugins plugin plugin_names
	plugins="$(tpm_plugins_list_helper)"

	plugin_names=()
	for plugin in $plugins; do
		# Remove everything after `#`
		plugin="${plugin%%#*}"
		# Remove username and slash
		plugin="${plugin##*/}"

		plugin_names+=( $plugin )
	done

	echo "${plugin_names[*]}"
}

clean_plugins() {
	local plugin plugin_directory
	local specs="$(_get_installed_plugin_names)"
	local names=()

	# Convert plugin specs to plugin names
	local spec
	for spec in $specs; do
		names+=( "$(plugin_name_helper "$spec")" )
	done
	names="${names[*]}"

	for plugin_directory in "$(tpm_path)"/*; do
		[ -d "${plugin_directory}" ] || continue
		name="$(basename "${plugin_directory}")"

		# Add spaces around plugin list to allow matching the full name
		case " ${names} " in
			*" ${name} "*) : ;;
			*)
				[[ "${name}" == "tpm-async" ]] && continue

				echo_ok "Removing \"$name\""
				rm -rf "${plugin_directory}" >/dev/null 2>&1

				[ -d "${plugin_directory}" ] &&
					echo_err "  \"$name\" clean fail" ||
					echo_ok "  \"$name\" clean success"
				;;
		esac
	done
}

main() {
	ensure_tpm_path_exists
	clean_plugins
	exit_value_helper
}
main
