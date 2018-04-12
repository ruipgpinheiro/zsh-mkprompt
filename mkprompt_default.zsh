########################################
# Author: Rui Pinheiro
#
# zsh-mkprompt defaults

#------------------------------
# Configuration

#------------------------------
# Left prompt
mkprompt_start "PROMPT"

if mkputils_is_ssh ; then
	mkprompt_username "$fg[blue]" --root-style "$bg[magenta]$fg_bold[black]"
	mkprompt_set_delim "@"
	mkprompt_hostname "$fg[yellow]"
	mkprompt_set_delim ":"
fi
mkprompt_cwd "$fg[yellow]"
mkprompt_prompt
mkprompt_add_raw " "


#------------------------------
# Right Prompt
mkprompt_start "RPROMPT"

mkprompt_clock "$fg[blue]"
mkprompt_jobs "$fg[blue]"
mkprompt_exec_time "$fg[blue]" -min 2
mkprompt_vcs_info_async "$bold_color" -dirty "$fg_bold[red]" -action ""
mkprompt_vimode "$bg[red]$fg_bold[black]"
