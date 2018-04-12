#########################################
# Author: Rui Pinheiro
#
# mkprompt "username" module
# Shorthand to the zsh prompt username (%n)
# Supports a different style for the root user

function mkprompt_username {
	# Parameters
	local style=""
	local root_style=""
	while [[ "$#" -gt "0" ]]; do
		case "$1" in
		"-s"|"--style")
			style="$2"
			shift 2
			;;
		"-root"|"--root-style")
			root_style="$2"
			shift 2
			;;
		*)
			if [[ -z "$style" ]]; then
				style="$1"
			else
				mkputils_error "[mkprompt] Invalid parameter '$1', ignored" "$0"
			fi
			shift 1
			;;
		esac
	done

	# If we are root, apply root style
	[[ ! -z "$root_style" && "$UID" -eq "0" ]] && style="$root_style"

	# Add section
	mkprompt_add -s "$style" -- "%n"
}
