#!/bin/bash

# Test input character for 'q'
exit_on_quit() {
	local var="$1"
	case ${var:0:1} in
	q) return 1 ;;
	*) return 0 ;;
	esac
}

prompt_confirm() {
	# usage: prompt_confirm "message" || exit 0
	local msg=$1 # "y" or "n"
	local reply
	while true; do
		read -r -n 1 -p "$msg [yn]: " reply
		case $reply in
		[yY]) return 0 ;; # true
		[nN]) return 1 ;; # false
		*) printf " \033[31m %s \n\033[0m" "invalid input" ;;
		esac
	done
}

read_yn() {
	local prompt="$1"
	local default="$2" # letter to capitalize
	local choice="yn"  # default choice

	# capitalize the default value (if any)
	if [ -n "$default" ]; then
		if [[ $default == 'y' ]]; then
			choice="Yn"
		elif [[ $default == 'n' ]]; then
			choice="yN"
		fi
	fi

	# Display the prompt
	prompt="$prompt [$choice]"
	local input

	# Loop until a valid input is received
	while true; do
		read -rn1 -p "$prompt " input

		# Use the default value if input is empty
		if [ -z "$input" ]; then
			input="$default"
		fi

		# Validate the input
		case "$input" in
		[yY])
			echo "y"
			return 0
			;;
		[nN])
			echo "n"
			return 0
			;;
		*)
			echo -e "   \033[31m invalid input \033[0m" >&2
			# echo "Invalid input. Please enter 'y' or 'n'." >&2
			;;
		esac
	done
}

# test

# result=$(read_yn "Do you want to proceed?" "y")
# echo -e "\n --> result: $result"
#
# if [ "$result" = "y" ]; then
# 	echo "User chose yes."
# else
# 	echo "User chose no."
# fi

execute_if_not_true() {
	# $1 true or false
	# $2 true message to echo if $1 is not true
	# $3 ... command
    bool=$1
	msg=$2
	if [ "$bool" = false ]; then
		shift
		shift
		command="$*"
		eval "$command"
	else
		echo "  $msg"
	fi
}

# test
# execute_if_not_true "true" "no execute" "git status"
