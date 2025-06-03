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

clone() {
	local repo_url="$1"
	local branch="$2"
	local name="$3"

	local git_cmd=(git clone --single-branch --recursive)
	[[ -n "$branch" ]] && git_cmd+=(-b "$branch")
	git_cmd+=("$repo_url" "$(tpm_path)/${name}")

	GIT_TERMINAL_PROMPT=0 "${git_cmd[@]}" >/dev/null 2>&1
}

# tries cloning:
# 1. plugin name directly - works if it's a valid git url
# 2. expands the plugin name to point to a GitHub repo and tries cloning again
clone_plugin() {
	local repo_url="$1"
	local branch="$2"
	local name="$3"

	clone "$repo_url" "$branch" "$name" ||
		clone "https://git::@github.com/$repo_url" "$branch" "$name"
}

# clone plugin and produce output
install_plugin() {
	local -n spec_NWPQ82="$1"

	local repo="${spec_NWPQ82[plugin]}"
	local url="${spec_NWPQ82[url]}"
	local branch="${spec_NWPQ82[branch]}"

	local name="$(plugin_get_name spec_NWPQ82)"

	if plugin_already_installed "$name"; then
		echo_ok "Already installed \"$name\" ($repo)"
	else
		echo_ok "Installing \"$name\" ($repo)"
		clone_plugin "$url" "$branch" "$name" &&
			echo_ok "  \"$name\" download success" ||
			echo_err "  \"$name\" download fail"
	fi
}

install_plugins() {
	local specs="$(tpm_plugins_list_helper)"

	local spec_str
	for spec_str in $specs; do
		local -A spec
		plugin_parse_spec spec "$spec_str"

		install_plugin spec
	done
}

verify_tpm_path_permissions() {
	local path="$(tpm_path)"
	# check the write permission flag for all users to ensure
	# that we have proper access
	[ -w "$path" ] ||
		echo_err "$path is not writable!"
}

main() {
	ensure_tpm_path_exists
	verify_tpm_path_permissions
	install_plugins
	exit_value_helper
}
main
