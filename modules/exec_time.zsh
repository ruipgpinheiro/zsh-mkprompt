#########################################
# Author: Rui Pinheiro
#
# mkprompt "exec_time" module
# Shows the execution time of the last command if it exceeds a certain amount

function mkprompt_exec_time {
	# Parameters
	typeset -g _mkpmod_exec_time_min=5
	local style=""
	while [[ "$#" -gt "0" ]]; do
		case "$1" in
		"-s"|"--style")
			style="$2"
			shift 2
			;;
		"-min"|"--minimum")
			_mkpmod_exec_time_min="$2"
			shift 2
			;;
		*)
			if [[ -z "$style" ]]; then
				style="$1"
			else
				mkputils_error "Invalid parameter '$1', ignored" "$0"
			fi
			shift 1
			;;
		esac
	done

	# Generate prompt message
	function _mkpmod_exec_time_update {
		local stop=$EPOCHSECONDS
		local start=${_mkpmod_exec_time_cmd_timestamp:-$stop}
		integer elapsed=$stop-$start
		if (($elapsed >= $_mkpmod_exec_time_min)); then
			typeset -g _mkpmod_exec_time_msg="$( mkputils_human_readable_seconds $elapsed )"
		else
			typeset -g _mkpmod_exec_time_msg=""
		fi
		unset elapsed
		unset _mkpmod_exec_time_cmd_timestamp # Reset timestamp
	}

	function _mkpmod_exec_time_preexec {
		typeset -g _mkpmod_exec_time_cmd_timestamp=$EPOCHSECONDS
	}

	add-zsh-hook preexec _mkpmod_exec_time_preexec
	add-zsh-hook precmd _mkpmod_exec_time_update

	# Add message to the prompt
	mkprompt_add -s "$style" -env "_mkpmod_exec_time_msg"
}
