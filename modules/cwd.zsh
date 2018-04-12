#########################################
# Author: Rui Pinheiro
#
# mkprompt "cwd" module
# Shorthand for the hash-expanded default zsh CWD (%~)

function mkprompt_cwd {
	local style="$1"
	[[ "$1" == "-s" ]] && style="$2"
	mkprompt_add -s "$style" -- "%~" # TODO: Customization
}
