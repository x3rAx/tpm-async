ensure_tpm_path_exists() {
	mkdir -p "$(tpm_path)"
}

fail_helper() {
	local message="$1"
	echo "$message" >&2
	FAIL="true"
}

exit_value_helper() {
	if [ "$FAIL" == "true" ]; then
		exit 1
	else
		exit 0
	fi
}

trim_whitespace() {
	local var="$1"

	# Remove leading whitespace characters
	var="${var#"${var%%[![:space:]]*}"}"

	# Remove trailing whitespace characters
	var="${var%"${var##*[![:space:]]}"}"

	echo "$var"
}
