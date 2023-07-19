#!/bin/bash

# reg exp to test for a valid version tag
# local RE_VER="^v\d+\.\d+\.\d+$" # does not work

# Globals
RE_BASE="[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}"
RE_VER="^${RE_BASE}$"
RE_TAG="^v${RE_BASE}$"
UNVERSIONED_TEXT="( no version tag )"
# Do not commit, tag, or push when TEST_MODE is true
TEST_MODE=false
# 'null version' has a valid version format but indicates
# no version info present in the repository.
NULL_VERSION="0.0.0"
NULL_TAG="v$NULL_VERSION"

source ./read_yn.sh

function check_ssh_agent() {
	local processId
	processId=$(pgrep ssh-agent)

	if [[ -z "$processId" ]]; then
		echo false
	else
		echo true
	fi
}

function start_ssh_agent() {
	# Check if ssh-agent process is running
	local processId
	processId=$(pgrep ssh-agent)

	# If ssh-agent process is not running, start it
	if [[ -z "$processId" ]]; then
		eval "$(ssh-agent)"
		echo "ssh-agent started."
	fi
	echo
}

function add_ssh_keys_to_agent() {
	# Add all private keys in ~/.ssh to ssh-agent
	local privateKeyFiles
	privateKeyFiles=$(ls ~/.ssh/id_* 2>/dev/null)

	for privateKeyFile in $privateKeyFiles; do
		if [[ $privateKeyFile != *.pub ]]; then
			ssh-add "$privateKeyFile"
			# echo "Added key: $privateKeyFile"
		fi
	done
}

match_pattern() {
	input_str="$1"
	pattern_str="$2"

	if [[ "$input_str" =~ $pattern_str ]]; then
		echo true
	else
		echo false
	fi
}

match_str() {
	local list=("$@")              # First parameter: list of strings
	local search_str="${list[-1]}" # Last element of the list is the search string
	unset 'list[-1]'               # Remove the search string from the list
	local found=false

	for item in "${list[@]}"; do
		if [[ "$item" == "$search_str" ]]; then
			found=true
			break
		fi
	done

	echo "$found"
}

# return true  version already in use
check_for_used_version() {
	local search_str=$1
	local result
	list=($(git tag))
	result=$(match_str "${list[@]}" "$search_str")
	# stderr_echo ".. check_for_used_version result: $result"
	echo "$result"
}

# return value: single letter choice
get_input_choice() {
	local choices=$1 # string of single letter choices
	local rv         # return value
	local msg="choices: [$choices] "
	local valid_pattern="^[$choices]$"

	while true; do
		read -rn 1 -p "$msg " input_char
		stderr_echo ""
		if [[ $(match_pattern "$valid_pattern" "$input_char") == true ]]; then
			break
		fi
	done
	rv="${input_char:0:1}"
	echo "$rv"
}

# output to stderr.
stderr_echo() {
	echo -e "$1" >&2
}

test_echo() {
	echo "    -> TEST_MODE - $1 "
}

remove_first_character() {
	local input_string="${1}"
	local substring="${input_string:1}"
	echo "${substring}"
}

# filter out all lines in given file matching list of keywords
# TODO this works on a string not a file
filter_lines() {
	local keywords=("$@")               # list of keywords
	local file="${keywords[-1]}"        # file to process
	local filtered_lines                # return values
	unset 'keywords[${#keywords[@]}-1]' # Remove the last element (file name)

	pattern=$(
		IFS="|"
		echo "${keywords[*]}"
	)
	filtered_lines=$(awk -v pattern="$pattern" '!($0 ~ pattern)' "$file")
	echo "$filtered_lines"
}

combine_commit_lines() {
	local input_lines=$1    # Input lines string
	local combined_lines="" # Output lines string

	# Read the input lines string line by line
	while IFS= read -r line1; do
		# Check if the line starts with "commit"
		if [[ $line1 == commit* ]]; then
			read -r line2
			read -r line3
			combined_line="$line3 $line2          (${line1})"$'\n'
			combined_lines+="$combined_line" # Add the combined line to the output string
		else
			combined_lines+="$line1"$'\n'
		fi
	done <<<"$input_lines"

	echo "$combined_lines" # Pass the output string back to the calling code
}

revise_git_log() {
	input_file=$1
	output_file=$2

	while IFS= read -r line; do
		revised_line=$(shorten_commit_hash "$line")
		# revised_line="$revised_line\n"
		echo "$revised_line" >>"$output_file"
		# stderr_echo "$revised_line"
	done <"$input_file"
}

# Check for existence of .git repository.
# If respoitory not present, offer to initialise one.
check_is_repository() {
	# params: None
	# return value: None
	if [[ ! -d ".git" ]]; then
		echo "Git respository Not initialised"
		read -r -n 1 -p "Press 'y' to initialise: " input
		echo
		if [[ $input == 'y' ]]; then
			git init --initial-branch="main"
			echo "-> git repository is now initialised"
		else
			echo "-> Exiting: Git repository is Not initializlised"
			exit
		fi
	fi
}

show_current_branch() {
	# echo "-> current branch:    $(git rev-parse --abbrev-ref HEAD)"
	echo "-> current branch:    $(git branch --show-current)"
}

# Return true is git has commits
git_has_commits() {
	if [[ "$(git log --oneline 2>/dev/null | wc -l)" -eq 0 ]]; then
		echo false
	else
		echo true
	fi
}

show_commit_count() {
	if [[ $(git_has_commits) == true ]]; then
		count=$(git rev-list HEAD --count)
		echo "-> number of commits: $count"
	else
		echo "-> number of commits: 0"
	fi
}

populate_files() {
	if [[ ! -f GIT_MSG ]]; then
		echo "-> creating file: GIT_MSG"
		touch GIT_MSG
	fi
}

# return true if 'version has valid format
check_ver_format() {
	local ver=$1
	# stderr_echo "check_ver_format of: $ver"
	if [[ $ver =~ $RE_VER ]]; then
		echo true
	else
		echo false
	fi
}

# return true if tag format conforms to:  v<digits>.<digits>.<digits>
check_tag_format() {
	local tag=$1
	if [[ $tag =~ $RE_TAG ]]; then
		echo true
	else
		echo false
	fi
}

# Get the latest tag: example tag: "v0.1.8"
# ret val: latest_tag is one exist, otherwise NULL_TAG
get_latest_tag() {
	# params: None
	local latest_tag # return value

	if [[ $(git_has_commits) == false ]]; then
		latest_tag=$NULL_TAG
	elif [[ $(git tag | wc -l) == 0 ]]; then
		latest_tag="$NULL_TAG"
	else
		latest_tag=$(git describe --tags --abbrev=0)
	fi
	echo "$latest_tag"
}

# Get default version from previous commit.
# This version is the basis for the bump increment.
# If no previous commits, then use default.
# return the latest tag used.
get_default_version() {
	# No params
	local default_ver # return value

	latest_tag="$(get_latest_tag)"

	if [[ $(check_tag_format "$latest_tag") == true ]]; then
		default_ver=$(remove_first_character "$latest_tag")
	else
		stderr_echo "-> Error: bad tag format"
		stderr_echo "-> Reverting to NULL tag"
		default_ver=$NULL_VERSION
	fi

	stderr_echo "-> current version:   $default_ver"
	echo "$default_ver"
}

# return single letter bump choice
get_bump_choice() {
	# No params
	local result # return value
	local msg
	stderr_echo
	stderr_echo "Next version bump kind:"
	stderr_echo "  Major        [M]"
	stderr_echo "  minor        [m]"
	stderr_echo "  patch        [p]"
	stderr_echo "  <no version> [n]"
	stderr_echo "  quit         [q]"
	result=$(get_input_choice "Mmpnq")
	echo "$result"
}

# return a suggested version tag based on the last one used
get_suggested_bump() {
	local cur_version=$1
	local bump_type=$2
	local v_major v_minor v_patch
	local new_version # return value
	local suggested_version

	base_list=($(echo "$cur_version" | tr '.' ' '))
	v_major=${base_list[0]}
	v_minor=${base_list[1]}
	v_patch=${base_list[2]}

	case $bump_type in
	'M')
		v_major=$((v_major + 1))
		v_minor=0
		v_patch=0
		;;
	'm')
		v_minor=$((v_minor + 1))
		v_patch=0
		;;
	'p') v_patch=$((v_patch + 1)) ;;
	'n') ;;
	*)
		stderr_echo "-> Error: 'get_suggested_bump' no param 2: $bump_type"
		exit
		;;
	esac

	suggested_version="$v_major.$v_minor.$v_patch"
	echo "$suggested_version"
}

bump_current_version() {
	local cur_version=$1 # param $1: version to bump
	local bump_code=$2   # param $2: bump_code -- Major, minor, patch, none
	local new_version    # return value

	local suggested_version
	local exit_loop
	local result

	exit_on_quit "$bump_choice" || exit 1

	if [[ $bump_code == 'n' ]]; then
		new_version="$UNVERSIONED_TEXT"
	else
		suggested_version=$(get_suggested_bump "$cur_version" "$bump_code")
		# stderr_echo "returned value for suggested version: $suggested_version"
		stderr_echo ""
		stderr_echo "-> Press Enter to accept suggested version, or"
		stderr_echo "-> Over-ride with a value in M.m.p format"
		stderr_echo ""
		exit_loop=false
		while [[ $exit_loop != true ]]; do
			read -rp "Suggested version:      [$suggested_version]: " new_version
			stderr_echo ""
			if [ "$new_version" = "" ]; then
				new_version=$suggested_version # accept default
			fi
			if [[ $(check_ver_format "$new_version") == true ]]; then
				exit_loop=true
			fi
		done

		stderr_echo "-> new version will be:  $new_version"

		result=$(confirm_valid_version "$new_version")
		# stderr_echo "result value is: |""$result""|"

		if [[ "$result" == false ]]; then
			stderr_echo "-> Error: can not use this version. exiting"
			new_version=""
		else
			stderr_echo "-> all good!"
		fi

		echo "$new_version"
	fi
}

# return git message based on contents of file: GIT_MSG
create_git_message() {
	# param $1: new version
	local version=$1
	local fout  # temp file
	local lines # return value
	fout=$(mktemp)

	title="version: ${version}"
	stderr_echo "-> git -m title is: $title\n"

	echo "$title" >"$fout"
	echo "" >>"$fout"
	cat GIT_MSG >>"$fout"

	while IFS= read -r line; do
		lines+=("$line")
	done <"$fout"

	for line in "${lines[@]}"; do
		echo "$line" # return list of lines
	done
}

# Append marker line to end of GIT_MSG file
mark_git_msg_file() {
	local ver=$1 # param $1. version just commited
	echo "--- Contents above this line were committed in version: $ver ---" >>GIT_MSG
}

confirm_valid_version() {
	local ver_num=$1 # param $1: version to check
	local result     # return value

	if [[ $ver_num == "$UNVERSIONED_TEXT" ]]; then
		result=true

	elif [[ $(check_for_used_version v"$ver_num") == true ]]; then
		stderr_echo "-> Error: This version number $ver_num has already been used."
		result=false

	elif [[ $(check_ver_format "$ver_num") == false ]]; then
		stderr_echo "-> Error: Improperly formatted version: $ver_num"
		result=false

	else
		result=true
	fi
	echo "$result"
}

# Populate the CHANGE_LOG file based on output from "git log"
# Note: This is done after a commit so this operation creates an 'unstaged' file.
populate_change_log() {
	# No return value.
	# Side effect: writes to CHANGE_LOG file
	local result
	local fout
	fout="$(mktemp)"
	# git log --pretty=medium >"$fout"
	git log --abbrev-commit >"$fout"
	# result=$(filter_lines "Date" "commit" "Author" "$fout")
	result=$(filter_lines "Date" "Author" "$fout")
	# remove leading spaces (sed) and collapse multiple blank lines (cat -s)
	echo "$result" | sed "s/^[ \t]*//" | cat -s >CHANGE_LOG
}

populate_change_log1() {
	# No params
	# No return value.
	# Side effect: writes to CHANGE_LOG file
	local result_lines
	local log_lines
	log_lines="$(mktemp)"

	git log --abbrev-commit >"$log_lines"
	result_lines=$(filter_lines "Date" "Author" "$log_lines")
	echo -e "\n===== filter lines ====="
	echo -e "$result_lines"
	echo "===== filter lines ====="

	result_lines=$(combine_commit_lines "$result_lines")

	echo -e "\n\n==== combine lines ==="
	echo -e "$result_lines"
	echo "========================"

	# remove leading spaces (sed) and collapse multiple blank lines (cat -s)
	echo "$result_lines" | sed "s/^[ \t]*//" | cat -s >CHANGE_LOG
}

truncate_git_msg_file() {
	local reply
	echo
	reply=$(read_yn "Truncate GIT_MSG?" "y")
	if [[ $reply == 'y' ]]; then
		echo -e "-> Truncating GIT_MSG file"
		cat /dev/null >GIT_MSG
	fi
}

push_annotated_tag() {
	local reply
	reply=$(read_yn "Push origin?" "y")
	if [[ $reply == 'y' ]]; then
		echo -e "\n=> git push origin refs/tags/v""$new_version"""

		if [[ $TEST_MODE == false ]]; then
			git push origin refs/tags/v"$new_version"
		else
			test_echo "no git push origin"
		fi
	fi
}

push_commit() {
	local reply
	reply=$(read_yn "Push origin" "y")
	echo
	if [[ $reply == 'y' ]]; then
		reply=$(read_yn "Use ssh_agent and add id's?" "y")
		if [[ $reply == 'y' ]]; then
			pkill ssh-agent
			start_ssh_agent
			add_ssh_keys_to_agent
		fi

		if [[ $TEST_MODE == false ]]; then
			git push origin
		else
			test_echo "no git push origin"
		fi
	fi
}

# Clean the current branch, commit it with message from GIT_MSG, tag and push origin
commit_local_branch() {
	# param $1: version to commit
	# return value: None
	local version=$1
	local reply
	reply=$(read_yn "Continue to commit local branch" "y")
	if [ "$reply" = "n" ]; then exit; fi

	echo -e "\n=> \$ git add ."
	git add .
	echo "=> \$ git commit"
	result=$(create_git_message "$version") # result is an array of strings
	if [[ $TEST_MODE == false ]]; then
		git commit -m "$result"
	else
		test_echo "no commit"
	fi
	mark_git_msg_file "$version"
	if [[ $version != "$UNVERSIONED_TEXT" ]]; then
		execute_if_not_true $TEST_MODE "no git tag" "git tag v${version}"
		# if [[ $TEST_MODE == false ]]; then
		# 	git tag "v${version}"
		# else
		# 	test_echo "no git tag"
		# fi
	fi

	echo
	push_commit
}

# Do a tag commit
create_annotated_tag() {
	local new_version=$1 # param 1
	# No return value
	local can_proceed
	local reply

	reply=$(read_yn "Create annotated tag?" "n")
	if [ "$reply" = "n" ]; then exit; fi

	# error check
	if [[ -z "$new_version" ]]; then
		echo "-> new_version String is empty"
		echo "-> aborting commit"
		can_proceed=false
	else
		echo "-> proceeding with create annotated tag"
		can_proceed=true
	fi

	if [[ $can_proceed == true ]]; then
		echo -e "\n=> \$ git tag -a -m"
        local cmd
        # cmd="git tag -a -m "tagging version "$new_version"" "v"$new_version"""
        # execute_if_not_true "$TEST_MODE" "Tagging" "$cmd"
		git tag -a -m "tagging version $new_version" "v$new_version" # annotated tag
		push_annotated_tag
	fi
}

main() {
	if [[ $TEST_MODE == true ]]; then
		echo "In test mode"
	fi

	local cur_ver new_ver
	populate_files

	# 1. Describe context
	echo "-> $(git --version)"
	echo "-> current directory: $(pwd)"
	check_is_repository
	show_current_branch
	show_commit_count
	cur_ver=$(get_default_version)

	# 2. Specify intent
	bump_choice=$(get_bump_choice)
	new_ver=$(bump_current_version "$cur_ver" "$bump_choice")
	if [[ $new_ver == "" ]]; then exit 1; fi

	# 3. Execute intent
	echo
	commit_local_branch "$new_ver"
	populate_change_log
	truncate_git_msg_file

	echo
	create_annotated_tag "$new_ver"
	echo
}

main
# populate_change_log1
