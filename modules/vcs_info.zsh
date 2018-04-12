#########################################
# Author: Rui Pinheiro
#
# mkprompt "vcs_info" module
# Shows the version control information of the current path in the prompt
# NOTE: In order to avoid taking too long to show the prompt, only local file systems are shown
#
# Parameters:
# -s         : style
# -dirty     : style of symbols indicating a dirty repository
# -nc        : disable checking for changes
# -ar        : enable checking remote file systems (slow!)

function mkprompt_vcs_info {
	# Parameters
	typeset -g _mkpmod_vcs_info_allow_remote_fs=0
	local check_for_changes=1
	local style=""
	local dirty_style=""
	local has_dirty_style=0
	while [[ "$#" -gt "0" ]]; do
		case "$1" in
		"-s"|"--style")
			style="$2"
			shift 2
			;;
		"-dirty"|"--dirty-style")
			dirty_style="$2"
			has_dirty_style=1
			shift 2
			;;
		"-ar"|"--allow-remote-fs")
			_mkpmod_vcs_info_allow_remote_fs=1
			shift 1
			;;
		"-nc"|"--no-changes")
			check_for_changes=0
			shift 1
			;;
		*)
			if [[ -z "$style" ]]; then
				style="$1"
			else
				mkputils_error "[mkprompt] Invalid $0 parameter '$1', ignored" "$0"
			fi
			shift 1
			;;
		esac
	done

	# Post-process parameters
	[[ "$style" == "$dirty_style" ]] && has_dirty_style=0
	local switch_to_dirty_style=""
	local switch_to_normal_style=""
	if [[ "$has_dirty_style" -ne "0" ]]; then
		local switch_to_dirty_style="%{$reset_color$dirty_style%}"
		local switch_to_normal_style="%{$reset_color$style%}"
	fi

	# vcs_info module
	autoload -Uz vcs_info
	zstyle ':vcs_info:*' enable git svn

	zstyle ':vcs_info:*' formats "%b%c%u"
	zstyle ':vcs_info:*' actionformats "%b%c%u (%a:%m)"
	zstyle ':vcs_info:*' unstagedstr "${switch_to_dirty_style}${MKPROMPT_VCS_INFO_SYM_STAGED-!}${switch_to_normal_style}"
	zstyle ':vcs_info:*' stagedstr "${switch_to_dirty_style}${MKPROMPT_VCS_INFO_SYM_UNSTAGED-+}${switch_to_dirty_style}"
	zstyle ':vcs_info:git:*' patch-format '%7>>%p%<< %n/%a'
	zstyle ':vcs_info:git:*' nopatch-format '%b %n/%a'
	[[ "$check_for_changes" -ne "0" ]] && zstyle ':vcs_info:*' check-for-changes true

	# Reload VCS information before every prompt for local filesystems
	function _mkpmod_vcs_info {
		if [[ "$_mkpmod_vcs_info_allow_remote_fs" -ne "0" ]] || mkputils_is_local_fs "$PWD" ; then
			vcs_info
			typeset -g _mkpmod_vcs_info_msg="$vcs_info_msg_0_"
		else
			typeset -g _mkpmod_vcs_info_msg=""
		fi
	}
	add-zsh-hook precmd _mkpmod_vcs_info

	# Add vcs_info information to the prompt
	mkprompt_add -s "$style" -env "_mkpmod_vcs_info_msg"
}
