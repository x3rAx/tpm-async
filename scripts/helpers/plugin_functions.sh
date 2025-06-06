HELPERS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$HELPERS_DIR/tmux_echo_functions.sh"
source "$HELPERS_DIR/utility.sh"

# using @tpm_plugins is now deprecated in favor of using @plugin syntax
tpm_plugins_variable_name="@tpm_plugins"

# manually expanding tilde char or `$HOME` variable.
_manual_expansion() {
	local path="$1"
	local expanded_tilde="${path/#\~/$HOME}"
	echo "${expanded_tilde/#\$HOME/$HOME}"
}

_tpm_path() {
	local string_path="$(tmux start-server\; show-environment -g TMUX_PLUGIN_MANAGER_PATH | cut -f2 -d=)/"
	_manual_expansion "$string_path"
}

_CACHED_TPM_PATH="$(_tpm_path)"

# Get the absolute path to the users configuration file of TMux.
# This includes a prioritized search on different locations.
#
_get_user_tmux_conf() {
	# Define the different possible locations.
	xdg_location="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
	default_location="$HOME/.tmux.conf"

	# Search for the correct configuration file by priority.
	if [ -f "$xdg_location" ]; then
		echo "$xdg_location"

	else
		echo "$default_location"
	fi
}

_tmux_conf_contents() {
	user_config=$(_get_user_tmux_conf)
	cat /etc/tmux.conf "$user_config" 2>/dev/null
	if [ "$1" == "full" ]; then # also output content from sourced files
		local file
		for file in $(_sourced_files); do
			cat $(_manual_expansion "$file") 2>/dev/null
		done
	fi
}

# return files sourced from tmux config files
_sourced_files() {
	_tmux_conf_contents |
		sed -E -n -e "s/^[[:space:]]*source(-file)?[[:space:]]+(-q+[[:space:]]+)?['\"]?([^'\"]+)['\"]?/\3/p"
}

# Want to be able to abort in certain cases
trap "exit 1" TERM
export TOP_PID=$$

_fatal_error_abort() {
	echo >&2 "Aborting."
	kill -s TERM $TOP_PID
}

# PUBLIC FUNCTIONS BELOW

tpm_path() {
	if [ "$_CACHED_TPM_PATH" == "/" ]; then
		echo >&2 "FATAL: Tmux Plugin Manager not configured in tmux.conf"
		_fatal_error_abort
	fi
	echo "$_CACHED_TPM_PATH"
}

tpm_plugins_list_helper() {
	# lists plugins from @tpm_plugins option
	echo "$(tmux start-server\; show-option -gqv "$tpm_plugins_variable_name")"

	# read set -g @plugin "tmux-plugins/tmux-example-plugin" entries
	_tmux_conf_contents "full" |
		awk '/^[ \t]*set(-option)? +-g +@plugin/ { gsub(/'\''/,""); gsub(/'\"'/,""); print $4 }'
}

# @DEPRECATED: Use `plugin_parse_spec`
#
# $attr_name can be one of
# - repo:        The full repo description
# - repo_url:    The repo url without the branch spec
# - repo_name:   The name of the repo (the part after the last slash)
# - repo_branch: The branch (the part after the `#`)
_get_plugin_spec_repo_attr() {
	local attr_name="$1"
	local spec="$2"

	if [[ $attr_name == 'repo' ]]; then
		# Get plugin repo from spec
		echo "$(trim_whitespace "${spec[0]}")"
		return
	fi

	local repo="$(trim_whitespace "${spec[0]}")"

	IFS='#' read -ra repo <<< "$repo"
	local url="${repo[0]}"
	local branch="${repo[1]}"

	case "$attr_name" in
		'repo_url')
			echo "$url"
			;;

		'repo_name')
			echo "$(basename "$url")"
			;;

		'repo_branch')
			echo "$branch"
			;;

		*)
			echo >&2 "ERROR: Not a valid repo attribute: $attr_name"
			exit 1
			;;
	esac
}

# @DEPRECATED: Use `plugin_parse_spec`
#
# Get an attribute value from the plugin spec. The plugin spec has the
# following format:
#
# ```
# <repo>[#<branch>][[;<attr>=<value>]...]
# ```
#
# To get `valueN`, pass `attrN` as `$attr_name`.
#
# Special attrs are:
# - repo:        The full repo description
# - repo_url:    The repo url without the branch spec
# - repo_name:   The name of the repo (the part after the last slash)
# - repo_branch: The branch (the part after the `#`)
get_plugin_spec_attr() {
	local attr_name="$1"
	local spec="$2"
	local fallback="${3:-}"

	# TODO: Test if attr_name is valid

	# Split spec by `;`
	IFS=';' read -ra spec <<< "$spec"

	if [[ $attr_name =~ ^repo(_.*)?$ ]]; then
		_get_plugin_spec_repo_attr "$attr_name" "$spec" "$fallback"
		return
	fi

	# Remove repo from spec
	spec=("${spec[@]:1}")

	# Find the attribute
	for elem in "${spec[@]}"; do
		if [[ $elem =~ ^"${attr_name}=" ]]; then
			echo "$(trim_whitespace "${elem#*=}")"
			return
		fi
	done

	echo "$(trim_whitespace "$fallback")"
}

plugin_parse_spec() {
	local -n _spec="$1"
	local spec_str="$2"

	# Split spec_str by `;`
	IFS=';' read -ra spec_arr <<< "$spec_str"

	local plugin="$(trim_whitespace "${spec_arr[0]}")"

	# Split plugin by branch specifier `#`
	IFS='#' read -ra plugin_arr <<< "$plugin"

	_spec['plugin']="$plugin"
	_spec['url']="${plugin_arr[0]}"
	_spec['branch']="${plugin_arr[1]}"

	# Remove repo from spec_arr, everything else is `key=value`
	spec_arr=("${spec_arr[@]:1}")

	# Set default values
	_spec['alias']=''
	_spec['async']=''

	for elem in "${spec_arr}"; do
		case "$elem" in
			'') ;;

			'alias='*)
				_spec['alias']="${elem#*=}"
				;;

			'async='*)
				_spec['async']="${elem#*=}"
				;;

			*)
				attr_name="${elem%%=*}"
				echo_err "Ignoring invalid spec attribute: ${attr_name}"
				;;
		esac
	done
}

plugin_get_name() {
	local -n spec__MCJFEI="$1"

	if [[ -n ${spec__MCJFEI[alias]} ]]; then
		echo "${spec__MCJFEI[alias]}"
		return
	fi

	local url="${spec__MCJFEI[url]}"
	# Get only the part after the last slash, e.g. "plugin_name.git"
	local base_name="$(basename "$url")"
	# Remove ".git" extension (if it exists) to get only the name
	local name="${base_name%.git}"

	echo "$name"
}

# @DEPRECATED: Use `plugin_get_name`
#
# Allowed plugin name formats:
# 1. "git://github.com/user/plugin_name.git"
# 2. "user/plugin_name"
# 3. "user/plugin_name;alias=plugin_name_alias"
plugin_name_helper() {
	local spec="$1"

	local alias="$(get_plugin_spec_attr alias "$spec")"

	if [[ -n $alias ]]; then
		echo "$alias"
		return
	fi

	local repo="$(get_plugin_spec_attr repo_url "$spec")"

	# Get only the part after the last slash, e.g. "plugin_name.git"
	local plugin_name="$(basename "$repo")"

	# remove ".git" extension (if it exists) to get only "plugin_name"
	local plugin_name="${plugin_name%.git}"
	echo "$plugin_name"
}

plugin_get_dir() {
	local -n spec__VX6GRY="$1"
	local name="$(plugin_get_name spec__VX6GRY)"
	echo "$(tpm_path)/${name}"
}

# @DEPRECATED: Use `get_plugin_dir`
plugin_path_helper() {
	local plugin="$1"
	local plugin_name="$(plugin_name_helper "$plugin")"
	echo "$(tpm_path)${plugin_name}/"
}

plugin_already_installed() {
	local plugin="$1"
	local plugin_path="$(plugin_path_helper "$plugin")"
	[ -d "$plugin_path" ] &&
		cd "$plugin_path" &&
		git remote >/dev/null 2>&1
}
