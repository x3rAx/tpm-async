HELPERS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$HELPERS_DIR/plugin_functions.sh"

reload_tmux_environment() {
	tmux source-file $(_get_user_tmux_conf) >/dev/null 2>&1
}

get_tmux_option() {
	local option=$1
	local default_value=$2
	local option_value=$(tmux show-option -gqv "$option")
	if [ -z "$option_value" ]; then
		echo "$default_value"
	else
		echo "$option_value"
	fi
}

