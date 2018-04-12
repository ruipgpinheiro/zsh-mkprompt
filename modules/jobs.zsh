#########################################
# Author: Rui Pinheiro
#
# mkprompt "jobs" module
# Lists any background jobs attached to the current shell

function mkprompt_jobs {
	# Style
	local style="$1"
	[[ "$1" == "-s" ]] && style="$2"

	# Generate prompt message
	function _mkpmod_jobs_update {
		local jobs_arr=()
		local j i
		for a (${(k)jobstates}) {
			j=$jobstates[$a]
			i="${${(@s,:,)j}[2]}"
			jobs_arr+=($a${i//[^+-]/})
		}
		unset j i

		if [[ -n $jobs_arr ]]; then
			typeset -g _mkpmod_jobs_msg="[${(j:,:)jobs_arr}]"
		else
			typeset -g _mkpmod_jobs_msg=""
		fi
	}

	add-zsh-hook precmd _mkpmod_jobs_update

	# Add message to the prompt
	mkprompt_add -s "$style" -env "_mkpmod_jobs_msg"
}
