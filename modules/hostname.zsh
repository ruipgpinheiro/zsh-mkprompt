#########################################
# Author: Rui Pinheiro
#
# mkprompt "hostname" module
# Shorthand for the zsh prompt hostname (%m)

function mkprompt_hostname {
	local style="$1"
	[[ "$1" == "-s" ]] && style="$2"
	mkprompt_add -s "$style" -- "%m"
}
