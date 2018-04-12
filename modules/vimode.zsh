#########################################
# Author: Rui Pinheiro
#
# mkprompt "vimode" module
# Shows 'vi' if ZLE is in vimode

function mkprompt_vimode {
	# Style
	local style="$1"
	[[ "$1" == "-s" ]] && style="$2"

	# Regenerate the vimode prompt message anytime the prompt is redrawn
	function _mkpmod_vimode {
		typeset -g _mkpmod_vimode_msg="${${KEYMAP/vicmd/vi}/(main|viins)/}"
	}
	add-zsh-hook precmd _mkpmod_vimode

	# Hook Zsh keymap change event
	function zle-keymap-select {
		_mkpmod_vimode
		zle reset-prompt
	}
	zle -N zle-keymap-select

	# Add to prompt
	mkprompt_add -s "$style" -env "_mkpmod_vimode_msg"
}
