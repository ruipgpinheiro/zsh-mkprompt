########################################
# Author: Rui Pinheiro
#
# zsh-mkprompt main file

# Store plugin directory
typeset -g _mkprompt_root="${0:A:h}"

# Function: mkprompt_init
# Initializes the mkprompt mechanism
#
# Usage: mkprompt_init [<parameters>]
# Parameters:
#   -d   : default delimiter (default=" ")
function mkprompt_init {
	# Prompt-related shell options required for mkprompt to work
	setopt promptsubst
	setopt prompt_cr

	# Load dependencies
	autoload -Uz add-zsh-hook
	zmodload "zsh/datetime"

	local f
	for f in "$_mkprompt_root/lib/"*.zsh "$_mkprompt_root/modules/"*.zsh ; do
		. "$f"
	done

	# Configuration
	typeset -g _mkprompt_default_delim=" "

	# Initialize
	typeset -g _mkprompt_init=1
	# Prepare mkprompt mechanism
	typeset -g _mkprompt_rtl=1
	typeset -g _mkprompt_var=""
	typeset -g _mkprompt_arr=()

	# Parameters
	while [[ "$#" -gt "0" ]]; do
		case "$1" in
		"-d"|"--delim"|"--delimiter")
			_mkprompt_default_delim="$2"
			shift 2
			;;
		*)
			mkputils_error "[mkprompt] Invalid parameter '$1', ignored" "$0"
			shift 1
			;;
		esac
	done


	# Function: mkprompt_start
	# Starts a new mkprompt variable if $1 is different from the current variable
	#
	# Usage: mkprompt_start [<variable>] [<parameters>]
	#   where <variable> (default="PROMPT") is the destination for the prompt string
	# Parameters:
	#   -ltr : Force left-to-right prompt construction (default)
	#   -rtl : Force right-to-left prompt construction (default for "RPROMPT" only)
	# Defaults:
	function mkprompt_start {
		# Parse parameters
		local new_rtl=""
		local new_var=""

		while [[ "$#" -gt "0" ]]; do
			case "$1" in
			"-ltr"|"--left-to-right")
				new_rtl=0
				shift 1
				;;
			"-rtl"|"--right-to-left")
				new_rtl=1
				shift 1
				;;
			"-"*)
				mkputils_error "Invalid parameter '$1', ignored" "$0"
				shift 1
				;;
			*)
				new_var="$1"
				shift 1
				;;
			esac
		done

		# Assume default parameters
		if [[ -z "$new_var" && -z "$new_rtl" ]]; then
			new_var="PROMPT"
			new_rtl=0
		elif [[ -z "$new_var" ]]; then
			if [[ "$new_rtl" -ne "0" ]]; then
				new_var="RPROMPT"
			else
				new_var="PROMPT"
			fi
		elif [[ -z "$new_rtl" ]]; then
			if [[ "$new_var" == "RPROMPT" ]]; then
				new_rtl=1
			else
				new_rtl=0
			fi
		fi

		# Save previous prompt
		if [[ "$new_var" != "$_mkprompt_var" ]]; then
			mkprompt_save
		fi

		# Start new prompt
		_mkprompt_arr=()
		_mkprompt_rtl="$new_rtl"
		_mkprompt_next_delim=0

		if [[ "$_mkprompt_rtl" -eq "0" ]]; then
			_mkprompt_next_delim_chr=""
			_mkprompt_next_delim_var=""
		fi

		_mkprompt_var="$new_var"
	}

	# Function: _mkprompt_apply_delim
	# Applies the current delimiter
	# NOTE: Internal, should not be called by modules or the user
	function _mkprompt_apply_delim {
		local new_delim_chr="${1:-$_mkprompt_default_delim}" new_delim_var="$2"

		local next_delim="$_mkprompt_next_delim"
		if [[ "$next_delim" -ne "0" ]]; then
			local delim_var
			local delim_chr

			if [[ "$_mkprompt_rtl" -eq "0" ]]; then
				delim_var="$_mkprompt_next_delim_var"
				delim_chr="$_mkprompt_next_delim_chr"
			else
				delim_var="$new_delim_var"
				delim_chr="$new_delim_chr"
			fi

			if [[ ! -z "$delim_chr" ]]; then
				local delim="$delim_chr"
				[[ ! -z "$delim_var" ]] && delim="\${${delim_var}:+${delim_chr}}"
				_mkprompt_arr+=("$delim")
			fi
		fi

		_mkprompt_next_delim=0
		if [[ "$_mkprompt_rtl" -eq "0" ]]; then
			_mkprompt_next_delim_chr="$new_delim_chr"
			_mkprompt_next_delim_var="$new_delim_var"
		fi
	}

	# Function: mkprompt_raw
	# Adds raw text to the prompt
	# NOTE: This resets delimiters and skips various checks. Use with care
	function mkprompt_add_raw {
		_mkprompt_arr+=("$@")
		mkprompt_set_delim ""
	}

	# Function: mkprompt_add
	# Adds a new section to the prompt
	#
	# Usage: mkprompt_add [<parameters>] [-- <content> | -e <content-variable>]
	#   where <parameters> are any of the parameters listed below.
	#   and <content> is the section content
	#   and <content-variable> is an environment variable containing the section content that gets expanded 
	#   every time the prompt is rendered.
	#   "-- <content>" and "-e <content-variable>" are exclusive.
	# Parameters:
	#   -d  : next delimiter character (equivalent to using mkprompt_set_delim after this command)
	#   -s  : style escape code (e.g. "$fg[red]")
	#         NOTE: must be only non-printable characters
	#   -se : same as -s, but as an environment variable that gets expanded every time the prompt is rendered
	function mkprompt_add {
		local style=""
		local content=""
		local new_delim_chr="$_mkprompt_default_delim"
		local new_delim_var=""

		# Parse parameters
		while [[ "$#" -gt "0" ]]; do
			case "$1" in
			"-d"|"--delim"|"--delimiter")
				new_delim_chr="$2"
				shift 2
				;;
			"-e"|"-env"|"--environment")
				[[ ! -z "$content" ]] && mkputils_error "Invalid parameter '$1': already have content" "$0" && break
				content="\${$2}"
				new_delim_var="$2"
				shift 2
				;;
			"-s"|"--style")
				style="$2"
				shift 2
				;;
			"-se"|"-senv"|"--style-environment")
				style="\${$2}"
				shift 1
				;;
			"-c"|"--content")
				[[ ! -z "$content" ]] && mkputils_error "Invalid parameter '$1': already have content" "$0" && break
				content="$2"
				shift 2
				;;
			"--")
				[[ ! -z "$content" ]] && mkputils_error "Invalid parameter '$1': already have content" "$0" && break
				shift 1
				content="$@"
				break
				;;
			*)
				mkputils_error "Invalid $0 parameter '$1', ignored" "$0"
				shift 1
				;;
			esac
		done

		# Add desired section
		if [[ ! -z "$content" ]]; then
			local reset=""
			if [[ ! -z "$style" ]]; then
				style="%{$style%}"
				reset="%{$reset_color%}"
			fi
			local add="${style}${content}${reset}"

			_mkprompt_apply_delim "$new_delim_chr" "$new_delim_var"
			_mkprompt_arr+=("$add")

			_mkprompt_next_delim=1
		fi
	}

	# Function: mkprompt_force_delim
	# Immediately writes the current delimiter
	# Usage: mkprompt_force_delim [<delim>]
	#   where <delim> is the delimiter to use (optional)
	function mkprompt_force_delim {
		local new_delim="$@"
		[[ ! -z "$new_delim" ]] && mkprompt_set_delim "$new_delim"
		_mkprompt_apply_delim
	}

	# Function: mkprompt_set_delim
	# Sets the next delimiter character
	# Usage: mkprompt_set_delim <delim>
	#   where <delim> is the delimiter to use
	#   (can be empty, in which case no delimiter will be output)
	function mkprompt_set_delim {
		local new_delim="$@"
		_mkprompt_next_delim_chr="$new_delim"
		[[ -z "$new_delim" ]] && _mkprompt_next_delim=0
	}

	# Function: mkprompt_save
	# Renders and saves the current prompt variable
	# Usage: mkprompt_save
	function mkprompt_save {
		[[ -z "$_mkprompt_var" ]] && return 0

		local arr
		if [[ "$_mkprompt_rtl" -eq "0" ]]; then
			arr=(${_mkprompt_arr})
		else
			arr=(${(@Oa)_mkprompt_arr})
		fi
		typeset -g "$_mkprompt_var"="${(j::)arr}"
	}

	# Function: mkprompt_finish
	# Finishes the mkprompt process, undefining all mkprompt variables and methods
	#
	# Usage: mkprompt_init [<parameters>]
	# Parameters:
	#   -kns : Does not clear the mkprompt namespace
	function mkprompt_finish {
		# Parse parameters
		local default=0
		local kns=0
		while [[ "$#" -gt "0" ]]; do
			case "$1" in
			"-def"|"--default")
				default=1
				shift 1
				;;
			"-kns"|"--keep-namespace")
				kns=1
				shift 1
				;;
			*)
				mkputils_error "Invalid parameter '$1', ignored" "$0"
				shift 1
				;;
			esac
		done

		[[ "$default" -ne "0" || -z "$_mkprompt_var" ]] && _mkprompt_default
		mkprompt_save

		if [[ "$kns" -eq "0" ]]; then
			setopt local_options extended_glob
			unset -m "mkprompt_*"
			unset -m "_mkprompt_^root"
			unfunction -m "mkprompt_^init"
			unfunction -m "_mkprompt_*"
		fi
	}

	# Functions: _mkprompt_default
	# Sets PROMPT and RPROMPT to the default mkprompt style
	# NOTE: Internal, should not be called by a module and/or user
	function _mkprompt_default {
		. "$_mkprompt_root/mkprompt_default.zsh"
	}
}
