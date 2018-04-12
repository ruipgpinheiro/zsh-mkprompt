########################################
# Author: Rui Pinheiro
#
# zsh-mkprompt utility functions

# Echos an error
function mkputils_error {
	local text="$1"
	local title="${2-mkprompt}"
	echo "$fg_bold[red][$title] ERROR: ${text}${reset_color}"
}

# Workaround unicode character width being counted incorrectly by zsh
# (for strings where width matters, such as prompts)
function mkputils_pad_unicode {
	local chr="$1" width="${2:-1}"
	[[ -z "$chr" ]] && return
	echo "%{${chr}${(l:$width*2::%G:)}%}"
}

# Returns 0 if $EPOCHSECONDS >= $1
function mkputils_time_passed {
	local val=${1-0}
	[[ "$val" -eq "0" ]] && return 0

	(( $EPOCHSECONDS >= $val )) && return 0
	return 1
}

# Echos $1 seconds as a human-readable "Xd Yh Wm Zs"
function mkputils_human_readable_seconds {
	local tmp=$1
	local days=$(( tmp / 60 / 60 / 24 ))
	local hours=$(( tmp / 60 / 60 % 24 ))
	local minutes=$(( tmp / 60 % 60 ))
	local seconds=$(( tmp % 60 ))
	(( $days > 0 )) && echo -n "${days}d"
	(( $hours > 0 )) && echo -n "${hours}h"
	(( $minutes > 0 )) && echo -n "${minutes}m"
	echo -n "${seconds}s"
}

# Returns 0 if $@ is a local file-system
# NOTE (1): Requires shelling out, so shouldn't be abused during shell init
# NOTE (2): The list of local file systems is not exhaustive
function mkputils_is_local_fs {
	local fstype=$( stat -f -L -c %T "$@" )

	case "$fstype" in
	"ext"*|"ntfs"*)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

# Returns 0 if this shell is inside an SSH session, otherwise 1
function mkputils_is_ssh {
	[[ -n "$SSH_CONNECTION" || -n "$SSH_CLIENT" || -n "$SSH_TTY" ]] && return 0
	return 1
}
