#########################################
# Author: Rui Pinheiro
#
# mkprompt "cwd" module
# Shows the CWD using a choice of formatters
#
# Parameters:
#   -s    : style
#   -f    : formatter
#   -abs  : Use absolute paths (instead of shortening $HOME and directory hashes with ~)
#
# Formatters:
#   'zsh' :
#     Default zsh prompt expansion formatter (%~)
#
#   'prefix' :
#     If CWD is above <wpct> percent of the terminal width, directories will be replaced by their prefix characters until it fits
#     the desired width.
#     Example (with             -e "."): /this/is/a/long/long/long/path => /t./is/a/l./l./long/path
#     Example (with       -ss 1 -e "."): /this/is/a/long/long/long/path => /t.s/is/a/l.g/l.g/long/path
#     Example (with -ps 0 -ss 1 -e "."): /this/is/a/long/long/long/path => /.s/is/a/.g/.g/long/path
#
#   'prefix-unique' :
#     Same as 'prefix', but instead of just the prefix character shows the shortest possible prefix that is unique.
#     Example (with -e "." -ps 1):
#       /this/is/a/longlong/long/long/path => /t./is/a/longl./l./long/path
#       /this/is/a/long/long/long/path     => /t./is/a/long/l./long/path
#     Example (with -e "." -ps 1 -ss 1):
#       /this/is/a/longlong/long/long/path => /t.s/is/a/longl.g/l.g/long/path
#       /this/is/a/long/long/long/path     => /t.s/is/a/long/l.g/long/path
#
#   'custom' :
#     Expects that a custom _mkpmod_cwd_shortener function is defined by the user.
#     This function receives as prefix parameter the full path to the parent folder (NOTE: May include '~') and as second parameter
#     the folder name that needs to be shortened.
#     It needs to set the variables _mkpmod_cwd_shortened to the resulting shortened folder name, and _mkpmod_cwd_shortened_len to
#     the length (in printable characters) after shortening.
#
# Parameters for non-'zsh' formatters:
#   -e    : Sets ellipsis character (default is empty)
#   -wpct : Sets the maximum allowed width of the CWD before the path prefixs being shortened (default=60)
#   -sr   : Tells formatters to also shorten the root of the folder.
#           By default, "~dirhash/path/to/folder" will become "~dirhash/l./p./to/folder".
#           With this option, it becomes "~d./l./p./to/folder" instead.
#   -ms   : Minimum number of characters shorter than the original that the shortened folder name must be for it to be used
#           (default=1)
#   -ps   : Size of the prefix in characters (for 'prefix' formatters, default=1)
#   -ss   : Size of the suffix in characters (for 'prefix' formatters, default=0)

function mkprompt_cwd {
	# Parameters
	local style=""
	local formatter="zsh"
	local prompt_escape="%~"
	local ellipsis=""
	local width_pct=60
	local shorten_root=0
	local prefix_size=1
	local suffix_size=0
	local minimum_shorter=1
	while [[ "$#" -gt "0" ]]; do
		case "$1" in
		"-s"|"--style")
			style="$2"
			shift 2
			;;
		"-f"|"--format"|"--formatter")
			formatter="$2"
			shift 2
			;;
		"-abs"|"--absolute")
			prompt_escape="%/"
			shift 1
			;;
		# Shortener-specific parameters
		"-e"|"--ellipsis")
			ellipsis="$2"
			shift 2
			;;
		"-wpct"|"--width-pct"|"--width-percent")
			width_pct="$2"
			shift 2
			;;
		"-sr"|"--shorten-root")
			shorten_root=1
			shift 1
			;;
		"-ps"|"--prefix-size")
			prefix_size="$2"
			shift 2
			;;
		"-ss"|"--suffix-size")
			suffix_size="$2"
			shift 2
			;;
		"-ms"|"--minimum-shorter")
			minimum_shorter="$2"
			shift 2
			;;
		*)
			if [[ -z "$style" ]]; then
				style="$1"
			else
				mkputils_error "[mkprompt] Invalid parameter '$1', ignored" "$0"
			fi
			shift 1
			;;
		esac
	done

	case "$formatter" in
	# Default ZSH cwd format (%~)
	""|"zsh")
		mkprompt_add -s "$style" -- "$prompt_escape" # TODO: Customization
		;;

	# Shared code for all custom formatters
	*)
		typeset -g _mkpmod_cwd_sym_ellipsis=$(mkputils_pad_unicode "$ellipsis")
		typeset -g _mkpmod_cwd_sym_ellipsis_len="$#ellipsis"
		typeset -g _mkpmod_cwd_prompt_escape="$prompt_escape"
		typeset -g _mkpmod_cwd_shorten_pct="$width_pct"
		typeset -g _mkpmod_cwd_shorten_root="$shorten_root"
		typeset -g _mkpmod_cwd_prefix_size="$prefix_size"
		typeset -g _mkpmod_cwd_suffix_size="$suffix_size"
		typeset -g _mkpmod_cwd_minimum_shorter="$minimum_shorter"
		typeset -g _mkpmod_cwd_formatter="$formatter"
		typeset -g _mkpmod_cwd_shorten_msg=""
		mkprompt_add -s "$style" -env "_mkpmod_cwd_shorten_msg"

		function _mkpmod_cwd_shorten {
			local cwd="${(%)_mkpmod_cwd_prompt_escape}"

			# Calculate maximum length
			local max_len
			(( max_len = ( ${_mkpmod_cwd_shorten_pct}.0 / 100 ) * $COLUMNS ))

			# If it fits, we don't need to do anything
			(( $#cwd <= max_len )) && _mkpmod_cwd_shorten_msg="$cwd" && return

			# Initialize result
			local estimated_len="$#cwd"
			local res=""
			local parent=""
			local split_cwd=(${(s:/:)cwd})

			# Remove ~ | / | ~/ from the first element
			local first="$split_cwd[1]"
			if [[ "${cwd:0:1}"   == "/" ]] then
				res+="/"
				parent+="/"
			else
				[[ "${first:0:1}" == "~" ]] && res+="~" && parent+="~" && first="${first:1}"
				[[ "${first:0:1}" == "/" ]] && res+="/" && parent+="/" && first="${first:1}"
			fi
			split_cwd[1]="$first"

			# Shorten path until it fits
			local i=0
			for ((i=1; i<=$#split_cwd; i++)); do
				local cur_dir="$split_cwd[$i]"
				[[ -z "$cur_dir" ]] && continue

				[[ "$i" -gt "1" ]] && res+="/" && parent+="/"

				if [[ "$_mkpmod_cwd_shorten_root" -eq "0" && "$i" -eq "1" ]]; then
					res+="$cur_dir"
				else
					typeset -g _mkpmod_cwd_shortened=""
					typeset -g _mkpmod_cwd_shortened_len=0
					_mkpmod_cwd_shortener "$parent" "$cur_dir"

					# Use shortened version if it is smaller
					if (( $_mkpmod_cwd_shortened_len > 0 &&
					      $#cur_dir >= $_mkpmod_cwd_shortened_len + $_mkpmod_cwd_minimum_shorter )); then
						res+="$_mkpmod_cwd_shortened"
						(( estimated_len += -$#cur_dir + $_mkpmod_cwd_shortened_len ))
					else
						res+="$cur_dir"
					fi
				fi
				parent+="$cur_dir"

				# Check if we now fit
				(( estimated_len <= max_len )) && break
			done
			unset _mkpmod_cwd_shortened _mkpmod_cwd_shortened_len

			# Appsuffix remaining path
			local remaining="${(@j:/:)split_cwd:$i}"
			if [[ ! -z "$remaining" ]]; then
				[[ "$i" -gt "0" ]] && res+="/"
				res+="$remaining"
			fi
			#echo_debug "estimated $estimated_len vs. real ${#res//$_mkpmod_cwd_sym_ellipsis/${(l:$_mkpmod_cwd_sym_ellipsis_len:)}}" "_mkpmod_cwd_shorten"

			# Store in prompt variable
			_mkpmod_cwd_shorten_msg="$res"
		}
		add-zsh-hook precmd _mkpmod_cwd_shorten
		;| # Continue evaluating conditions to find the _mkpmod_cwd_shortener implementation

	# Prefix + Ellipsis
	"prefix")
		function _mkpmod_cwd_shortener {
			local prefix="${2:0:$_mkpmod_cwd_prefix_size}"
			local suffix=""
			[[ "$_mkpmod_cwd_suffix_size" -gt "0" ]] && suffix="${2: -$_mkpmod_cwd_suffix_size}"

			_mkpmod_cwd_shortened="$prefix$_mkpmod_cwd_sym_ellipsis$suffix"
			(( _mkpmod_cwd_shortened_len = $_mkpmod_cwd_prefix_size + $_mkpmod_cwd_suffix_size + $_mkpmod_cwd_sym_ellipsis_len ))
		}
		;;

	# Replaces each directory with the smallest possible unique prefix
	"prefix-unique")
		function _mkpmod_cwd_shortener {
			setopt local_options null_glob
			local parent="$1" dir="$2"

			# Calculate the necessary number of iterations before we simply give up
			# After this number of iterations, we would get the same length as the original directory name
			local num_iter
			(( num_iter = $#dir - $_mkpmod_cwd_sym_ellipsis_len ))

			# Escape path
			# NOTE: The "tilde" at the prefix of the path (if any) must not be escaped
			if [[ "${parent:0:1}" == "~" ]]; then
				parent="${parent:0:1}${(qqqq)parent:1}"
			else
				parent="${(qqqq)parent}"
			fi

			# If we want the suffix
			local suffix="${dir: -$_mkpmod_cwd_suffix_size}"
			(( num_iter -= $_mkpmod_cwd_suffix_size ))

			# Find shortest unique path
			local j=0
			for ((j=$_mkpmod_cwd_prefix_size; j<=$num_iter; j++)); do
				local prefix="${dir:0:$j}"
				eval "local glob=( $parent${(qqqq)prefix}*(/Y2) )"

				[[ "$#glob" -le "1" ]] && break
			done

			# Return shortest unique path found
			if [[ "$j" -lt "$num_iter" ]]; then
				_mkpmod_cwd_shortened="$prefix$_mkpmod_cwd_sym_ellipsis$suffix"
				(( _mkpmod_cwd_shortened_len = $#prefix + $_mkpmod_cwd_suffix_size + $_mkpmod_cwd_sym_ellipsis_len ))
			fi
		}
		;;

	# User-defined _mkpmod_cwd_shortener function
	"custom")
		;;

	*)
		mkputils_error "[mkprompt] Invalid cwd formatter '$formatter', ignored" "$0"
		;;
	esac
}
