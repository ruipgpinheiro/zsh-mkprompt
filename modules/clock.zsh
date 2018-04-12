#########################################
# Author: Rui Pinheiro
#
# mkprompt "clock" module
# Shorthand for the default zsh clock (%T)

function mkprompt_clock {
	local style="$1"
	[[ "$1" == "-s" ]] && style="$2"
	mkprompt_add -s "$style" -- "%T"
}
