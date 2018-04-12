#########################################
# Author: Rui Pinheiro
#
# mkprompt "prompt" module
# Shorthand for the zsh prompt symbol (%#)

function mkprompt_prompt {
	local style="$1"
	[[ "$1" == "-s" ]] && style="$2"
	mkprompt_add -s "$style" -- "%#"
}
