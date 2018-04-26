#########################################
# prompt/modules/vcs_info
# Author: Rui Pinheiro
#
# mkprompt "vcs_info" module with asynchronous capability
# Highly influenced by https://github.com/sindresorhus/pure
# Shows the version control information of the current path in the prompt using zsh-async
#
# Parameters:
# -s         : style
# -dirty     : style of symbols indicating a dirty repository
# -action    : style used for on-going actions (e.g. patch being applied)

function mkprompt_vcs_info_async {
	# vcs_info module
	autoload -Uz vcs_info

	# async module
	async

	# Parameters
	local style=""
	local dirty_style=""
	local has_dirty_style=0
	local action_style=""
	local has_action_style=0
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
		"-action"|"--action-style")
			action_style="$2"
			has_action_style=1
			shift 2
			;;
		*)
			if [[ -z "$style" ]]; then
				style="$1"
			else
				echo "[mkprompt] Invalid $0 parameter '$1', ignored"
			fi
			shift 1
			;;
		esac
	done

	#########
	# Configuration
	typeset -g _mkpmod_vcs_info_async_init=0
	typeset -g _mkpmod_vcs_info_async_worker="vcs_info_async"
	typeset -g _mkpmod_vcs_info_async_last_histcmd=""
	typeset -g _mkpmod_vcs_info_async_pwd=""

	# Styles
	typeset -g _mkpmod_vcs_info_async_style="%{${reset_color}${style}%}"
	[[ "$has_dirty_style" -eq "0" ]] && dirty_style="$style" 
	typeset -g _mkpmod_vcs_info_async_dirty_style="%{${reset_color}${dirty_style}%}"
	[[ "$has_action_style" -eq "0" ]] && action_style="$style" 
	typeset -g _mkpmod_vcs_info_async_action_style="%{${reset_color}${action_style}%}"

	# Symbols
	# Uses pad-unicode to force symbols to have monospace width=1
	typeset -g _mkpmod_vcs_info_async_sym_staged=$(  mkputils_pad_unicode "${MKPROMPT_VCS_INFO_SYM_STAGED-!}")
	typeset -g _mkpmod_vcs_info_async_sym_unstaged=$(mkputils_pad_unicode "${MKPROMPT_VCS_INFO_SYM_UNSTAGED-+}")
	typeset -g _mkpmod_vcs_info_async_sym_initial=$( mkputils_pad_unicode "${MKPROMPT_VCS_INFO_SYM_INITIAL-?}")
	typeset -g _mkpmod_vcs_info_async_sym_unknown=$( mkputils_pad_unicode "${MKPROMPT_VCS_INFO_SYM_UNKNOWN-?}")
	typeset -g _mkpmod_vcs_info_async_sym_working=$( mkputils_pad_unicode "${MKPROMPT_VCS_INFO_SYM_WORKING-?}")
	typeset -g _mkpmod_vcs_info_async_sym_up=$(      mkputils_pad_unicode "${MKPROMPT_VCS_INFO_SYM_UP-}")
	typeset -g _mkpmod_vcs_info_async_sym_down=$(    mkputils_pad_unicode "${MKPROMPT_VCS_INFO_SYM_DOWN-}")
	typeset -g _mkpmod_vcs_info_async_sym_ellipsis=$(mkputils_pad_unicode "${MKPROMPT_VCS_INFO_SYM_ELLIPSIS-…}")
	typeset -g _mkpmod_vcs_info_async_sym_error=$(   mkputils_pad_unicode "${MKPROMPT_VCS_INFO_SYM_ERROR-✘}")

	# Minimum interval in seconds between repeated checks for the same repo (0 disables)
	# NOTE: 'git' commands always trigger a check
	# default: 5 seconds
	typeset -g _mkpmod_vcs_info_async_minimum_interval="${MKPROMPT_VCS_INFO_MINIMUM_INTERVAL:-5}"

	# Maximum interval in seconds between repeated checks for the same repo (0 disables)
	# # default: 10 minutes
	typeset -g _mkpmod_vcs_info_async_maximum_interval="${MKPROMPT_VCS_INFO_MAXIMUM_INTERVAL:-600}"

	# Factor used to calculate the interval between repeated checks for the same repo,
	# using the formula exec_time*factor, where exec_time is the executing time of the asynchronous
	# command represented in seconds as a float
	# default: 10
	typeset -g _mkpmod_vcs_info_async_interval_exec_time_factor="${MKPROMPT_VCS_INFO_INTERVAL_EXEC_TIME_FACTOR:-10}"


	#########
	# Async job handlers

	# Main job, responsible for calling and parsing vcs_info
	# $1=1 -> Checks for dirty repos as well (slower)
	function _mkpmod_vcs_info_async_job {
		local dir="$1" check_for_changes="${2-0}"

		builtin cd -qL "$dir" 2>/dev/null

		# configure vcs_info inside async task, this frees up vcs_info
		# to be used or configured as the user pleases without affecting the prompt
		zstyle ':vcs_info:*' enable svn git
		zstyle ':vcs_info:*' max-exports 6

		if [[ "$check_for_changes" -eq "1" ]]; then
			zstyle ':vcs_info:*' check-for-changes true
		else
			zstyle ':vcs_info:*' check-for-changes false
		fi

		zstyle ':vcs_info:*' formats '%s' '%b' '%R' '%u%c'
		zstyle ':vcs_info:*' actionformats '%s' '%b' '%R' '%u%c' '%a' '%m'

		# formats for git
		zstyle ':vcs_info:git:*' patch-format '%7>>%p%<< %n/%a'
		zstyle ':vcs_info:git:*' nopatch-format '%b %n/%a'

		# Symbols for when the repo is dirty
		zstyle ':vcs_info:*' unstagedstr "$_mkpmod_vcs_info_async_sym_staged"
		zstyle ':vcs_info:*' stagedstr "$_mkpmod_vcs_info_async_sym_unstaged"

		# Call vcs_info
		vcs_info

		# For some reason empty formats become 'a:', so make sure to remove that when parsing results
		local -A info
		info[vcs]="${vcs_info_msg_0_:#a:}"
		info[branch]="${vcs_info_msg_1_:#a:}"
		info[top]="${vcs_info_msg_2_:#a:}"
		info[action]="${vcs_info_msg_4_:#a:}"
		info[misc]="${vcs_info_msg_5_:#a:}"

		if [[ "$check_for_changes" -eq "1" ]]; then
			info[dirty]="${vcs_info_msg_3_:#a:}"
		else
			info[dirty]="$_mkpmod_vcs_info_async_sym_unknown"
		fi

		print -r - ${(@kvqqqq)info/.../${_mkpmod_vcs_info_async_sym_ellipsis}}

		return 0
	}
	function _mkpmod_vcs_info_async_job_initial {
		_mkpmod_vcs_info_async_job "$1" "0"
	}
	function _mkpmod_vcs_info_async_job_full {
		_mkpmod_vcs_info_async_job "$1" "1"
	}

	# Git arrows job: Checks how many commits the current branch is ahead and/or behind upstream
	# Outputs a string to stdout which can be used directly by the prompt
	function _mkpmod_vcs_info_async_job_git_arrows {
		#echo $EPOCHSECONDS
		builtin cd -q $1

		# Run git
		local code=0 output=""
		output=$( command git rev-list --left-right --count HEAD...@'{u}' 2>&1 )
		code=$?

		# If successful, we should parse the results
		if [[ "$code" -eq "0" ]]; then
			local uparrow="${_mkpmod_vcs_info_async_sym_up}"
			local downarrow="${_mkpmod_vcs_info_async_sym_down}"

			local arrownum=("${(@ps:\t:)output}")
			local text=""

			# If enabled, we show count numbers if either count>1
			if [[ "${MKPROMPT_VCS_INFO_ARROW_COUNT:-1}" -eq "1" && ( "$arrownum[1]" -gt "1" || "$arrownum[2]" -gt "1" ) ]]; then
				local extra
				[[ "$arrownum[1]" -gt "0" ]] && extra+="${arrownum[1]}${uparrow}"
				if [[ "$arrownum[2]" -gt "0" ]]; then
					# If enabled, and the count is the same, show number once
					if [[ "${MKPROMPT_VCS_INFO_ARROW_MERGE:-1}" -eq "1" && ( "$arrownum[2]" -eq "$arrownum[1]" ) ]]; then
						extra+="${downarrow}"
					else
						extra+="${arrownum[2]}${downarrow}"
					fi
				fi
				[[ ! -z "$extra" ]] && text+=" $extra"

			# Otherwise we show only the up/down symbols
			else
				[[ "$arrownum[1]" -gt "0" ]] && text+="${uparrow}"
				[[ "$arrownum[2]" -gt "0" ]] && text+="${downarrow}"
			fi

			# Echo output
			echo -n "$text"
		fi

		return $code
	}


	###############
	# Async callback - called once an async worker finishes
	function _mkpmod_vcs_info_async_callback {
		local job="$1" code="$2" output="$3" exec_time="$4"
		#echo_debug "job finished: $job" "vcs_info_async:callback"

		case $job in
			# Normal 'vcs_info' asynchronous request
			"_mkpmod_vcs_info_async_job_initial"|"_mkpmod_vcs_info_async_job_full")
				# Handle errors
				if [[ "$code" -ne "0" ]]; then
					echo -n "\n" # Make sure to print in a separate line from the prompt
					mkputils_error "non-zero error code $code (output='$output')" "vcs_info_async:vcs_info"
					vcs_info_async_error=1
					return 1
				fi
				vcs_info_async_error=0

				# parse output (z) and unquote as array (Q@)
				local output_arr=("${(z)output[@]}")
				local -A info=("${(QQQQ@)output_arr}")

				# If we just changed repo, branch, or vcs make sure we reset the current state
				local reset=0
				if [[ "$info[top]" != "$vcs_info_async[top]" || "$info[vcs]" != "$vcs_info_async[vcs]" || "$info[branch]" != "$vcs_info_async[branch]" ]]; then
					_mkpmod_vcs_info_async_reset
					reset=1
				fi

				# Store new vcs_info values
				vcs_info_async[vcs]="$info[vcs]"
				vcs_info_async[branch]="$info[branch]"
				vcs_info_async[dirty]="$info[dirty]"
				vcs_info_async[top]="$info[top]"
				vcs_info_async[action]="$info[action]"
				vcs_info_async[misc]="$info[misc]"

				#echo "vcs=$vcs_info_async[vcs]"
				#echo "branch=$vcs_info_async[branch]"
				#echo "dirty=$vcs_info_async[dirty]"
				#echo "top=$vcs_info_async[top]"
				#echo "misc=$vcs_info_async[misc]"
				#echo "action=$vcs_info_async[action]"

				# If we are in a valid repo
				if [[ ! -z "$vcs_info_async[top]" ]]; then
					# If it was the initial check
					if [[ "$job" = "_mkpmod_vcs_info_async_job_initial" ]]; then
						_mkpmod_vcs_info_async_update

					# Full check
					else
						# Calculate when we must re-check
						_mkpmod_vcs_info_async_update_wait "full" "$exec_time"

						# If we reset because of this check, make sure to update the status of other asynchronous jobs
						[[ "$reset" -ne "0" ]] && _mkpmod_vcs_info_async_update
					fi
				fi

				vcs_info_async_initial=0
				_mkpmod_vcs_info_async_render 1
				;;

			# git arrows async request
			"_mkpmod_vcs_info_async_job_git_arrows")
				# Success
				if [[ "$code" -eq "0" ]]; then
					vcs_info_async[arrows]="$output"

				# No upstream
				elif [[ "$code" -eq "128" ]]; then
					vcs_info_async[arrows]=""

				# Other errors
				else
					echo -n "\n" # Make sure to print in a separate line from the prompt
					mkputils_error "non-zero error code $code (output='$output')" "vcs_info_async:git_arrows"
					_mkpmod_vcs_info_async[arrows]="?"
				fi

				_mkpmod_vcs_info_async_update_wait "arrows" "$exec_time"
				_mkpmod_vcs_info_async_render 1
				;;

			# zsh-async sometimes calls the handler for job 'async', no idea why
			# This breaks the prompt, for some reason
			"async")
				vcs_info_async_error=1
				return 1
				;;

			# Unknown
			*)
				echo -n "\n" # Make sure to print in a separate line from the prompt
				mkputils_error "Invalid job '$job'." "vcs_info_async:callback"
				vcs_info_async_error=1
				return 1
		esac
		return 0
	}


	###############
	# Main code

	# Called before every prompt is rendered the first time
	function _mkpmod_vcs_info_async_main {
		local real_pwd="`pwd -P`"
		local pwd_changed=0
		[[ "$_mkpmod_vcs_info_async_pwd" != "$real_pwd" ]] && pwd_changed=1

		# If we are not in a known repo, we do a quick initial check
		if [[ -z "$vcs_info_async[top]" || ! "$real_pwd" = "$vcs_info_async[top]"* ]]; then
			# Only do the initial check if this is a new directory
			[[ "$pwd_changed" -eq "1" ]] && _mkpmod_vcs_info_async_initial_check

		# Otherwise, we do a full update
		else
			_mkpmod_vcs_info_async_update
		fi

		_mkpmod_vcs_info_async_pwd="$real_pwd"
	}

	# Prepares the environment and then runs an initial check
	# (e.g. after changing to a new folder)
	function _mkpmod_vcs_info_async_initial_check {
		# Reset state
		_mkpmod_vcs_info_async_reset

		# Check current PWD for repo (fast check)
		async_job "$_mkpmod_vcs_info_async_worker" _mkpmod_vcs_info_async_job_initial "`pwd -P`"
	}

	# Resets the current state of the vcs_info_async module
	function _mkpmod_vcs_info_async_reset {
		# Workaround: async_flush_jobs has a race condition
		# If a job is already running (and only unique jobs are allowed), then flushing and immediately restarting the job might
		# not work. As such, we kill the worker and restart it!

		# stop async worker
		if [[ ! -z "$vcs_info_async[top]" ]]; then
			async_stop_worker "$_mkpmod_vcs_info_async_worker"
			_mkpmod_vcs_info_async_init=0
		else
			async_flush_jobs "$_mkpmod_vcs_info_async_worker"
		fi

		# initialize async worker
		if [[ "$_mkpmod_vcs_info_async_init" -eq "0" ]]; then
			async_start_worker "$_mkpmod_vcs_info_async_worker" -u
			async_register_callback "$_mkpmod_vcs_info_async_worker" _mkpmod_vcs_info_async_callback
			_mkpmod_vcs_info_async_init=1
		fi

		# Reset variables
		typeset -g vcs_info_async_initial=1
		typeset -g vcs_info_async_error=0

		typeset -gA vcs_info_async_wait=()
		typeset -gA vcs_info_async=()
	}

	# Called when inside a known repo
	# (i.e. a folder for which the initial_check returned a valid branch)
	# Responsible for enqueuing any new checks
	function _mkpmod_vcs_info_async_update {
		local refresh=0 # refresh=1 forces a full refresh
		local real_pwd=`pwd -P` # follow symlinks

		# Detect if the last command was current VCS
		if [[ ! -z "$vcs_info_async[vcs]" && "$_mkpmod_vcs_info_async_last_histcmd" -ne "$HISTCMD" ]]; then
			integer histpos=$HISTCMD-1
			local lastcmd=$history[$histpos]
			[[ "$lastcmd" == "$vcs_info_async[vcs]"* ]] && refresh=1
			_mkpmod_vcs_info_async_last_histcmd="$HISTCMD"
		fi

		# Detect if current folder contains a ".git" folder/file and is not the current repo root
		if [[ -e ".git" ]]; then
			if [[ ! -z "$vcs_info_async[top]" && ( "$vcs_info_async[vcs]" != "git" || "$vcs_info_async[top]" != "$real_pwd" ) ]]; then
				refresh=1
			fi
		fi

		# Detect if current folder contains a ".svn" folder/file and is not the current repo root
		if [[ -e ".svn" ]]; then
			if [[ ! -z "$vcs_info_async[top]" && ( "$vcs_info_async[vcs]" != "svn" || "$vcs_info_async[top]" != "$real_pwd" ) ]]; then
				refresh=1
			fi
		fi

		# Check for changes (full check) if enough time has passed
		( [[ "$refresh" -ne "0" ]] || mkputils_time_passed "$vcs_info_async_wait[full]" ) && \
			async_job "$_mkpmod_vcs_info_async_worker" _mkpmod_vcs_info_async_job_full "$real_pwd"

		# Check for git ahead/behind
		if [[ "$vcs_info_async[vcs]" == "git" ]]; then
			# If this is the first time we check git arrows for this repo, set the working string
			[[ -z "$vcs_info_async_wait[arrows]" ]] && vcs_info_async[arrows]="$_mkpmod_vcs_info_async_sym_working"

			# If enough time has passed, do the check
			( [[ "$refresh" -ne "0" ]] || mkputils_time_passed "$vcs_info_async_wait[arrows]" ) && \
				async_job "$_mkpmod_vcs_info_async_worker" _mkpmod_vcs_info_async_job_git_arrows "$real_pwd"
		else
			# Not git
			vcs_info_async[arrows]=""
		fi
	}

	# Called by asynchronous jobs to set up the vcs_info_async_wait hash
	function _mkpmod_vcs_info_async_update_wait {
		local name="$1" exec_time="$2"

		# Calculate delay using exec_time*factor
		integer wait_sec=$exec_time*$_mkpmod_vcs_info_async_interval_exec_time_factor
		# Impose maximum interval
		(( $wait_sec > $_mkpmod_vcs_info_async_maximum_interval )) && wait_sec=$_mkpmod_vcs_info_async_maximum_interval
		# Impose minimum interval
		(( $wait_sec < $_mkpmod_vcs_info_async_minimum_interval )) && wait_sec=$_mkpmod_vcs_info_async_minimum_interval

		# Calculate timestamp when wait will be over and store it
		integer wait_until=$EPOCHSECONDS+$wait_sec
		vcs_info_async_wait[$name]=$wait_until
		unset wait_sec wait_until
		return 0
	}

	################
	# Prompt

	# Renders the $_mkpmod_vcs_info_async_msg variable used by the prompt
	# $1=1 forces zle to redraw the prompt
	function _mkpmod_vcs_info_async_render {
		local new_msg=""

		local branch="$vcs_info_async[branch]"
		if [[ "$vcs_info_async_error" -ne "0" ]]; then
			new_msg+="%{$reset_color$fg_bold[red]%}${_mkpmod_vcs_info_async_sym_error}%{$reset_color%}"

		elif [[ "$vcs_info_async_initial" -ne "0" ]]; then
			new_msg="$_mkpmod_vcs_info_async_sym_initial"

		elif [[ ! -z "$branch" ]]; then
			local dirty="$vcs_info_async[dirty]"
			local arrows="$vcs_info_async[arrows]"
			local action="$vcs_info_async[action]"
			local misc="$vcs_info_async[misc]"

			# (<action>: <misc>) <branch><dirty><arrows>
			new_msg="${_mkpmod_vcs_info_async_style}$vcs_info_async[branch]"

			if [[ ! -z "$dirty" ]]; then
				new_msg+="${_mkpmod_vcs_info_async_dirty_style}$dirty"

				# If both are loading, show only one single 'working' string
				# Otherwise append arrows
				if [[ ! -z "$arrows" ]]; then
					[[ "$arrows" = "$_mkpmod_vcs_info_async_sym_unknown" && "$arrows" = "$dirty" ]] || \
						new_msg+="$arrows"
				fi
			elif [[ ! -z "$arrows" ]]; then
				new_msg+="${_mkpmod_vcs_info_async_dirty_style}$arrows"
			fi

			if [[ ! -z "$action" ]]; then
				local action_msg="${_mkpmod_vcs_info_async_action_style}"
				if [[ ! -z "$misc" ]]; then
					action_msg+="($action: $misc)"
				else
					action_msg+="($action)"
				fi
				new_msg="$action_msg $new_msg"
			fi
		fi

		# Redraw the prompt.
		if [[ "$new_msg" != "$_mkpmod_vcs_info_async_msg" ]]; then
			typeset -g _mkpmod_vcs_info_async_msg="$new_msg"
			[[ "${1-0}" -eq "1" ]] && zle reset-prompt
		fi
	}

	# Precmd handler
	# Calls the main vcs_info method and then renders the prompt the first time
	function _mkpmod_vcs_info_async {
		_mkpmod_vcs_info_async_main
		_mkpmod_vcs_info_async_render 0
	}
	add-zsh-hook precmd _mkpmod_vcs_info_async

	# Register module with the mkprompt mechanism
	typeset -g _mkpmod_vcs_info_async_msg=""
	mkprompt_add -s "$style" -env "_mkpmod_vcs_info_async_msg"
}
