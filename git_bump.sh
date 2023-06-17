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
	# err_echo ".. check_for_used_version result: $result"
	echo "$result"
}

prompt_confirm() {
	# usage: prompt_confirm "message" || exit 0
	local msg=$1
	local reply
	while true; do
		read -r -n 1 -p "$msg [y/n]: " reply
		case $reply in
		[yY]) return 0 ;; # true
		[nN]) return 1 ;; # false
		*) printf " \033[31m %s \n\033[0m" "invalid input" ;;
		esac
	done
}

# return value: single letter choice
get_input_choice() {
	local choices=$1 # string of single letter choices
	local rv         # return value
	local msg="choices: [$choices] "
	local valid_pattern="^[$choices]$"

	while true; do
		read -rn 1 -p "$msg " input_char
		err_echo ""
		if [[ $(match_pattern "$valid_pattern" "$input_char") == true ]]; then
			break
		fi
	done
	rv="${input_char:0:1}"
	echo "$rv"
}

# output to stderr.
err_echo() {
	echo "$1" >&2
}

# Test input character for 'q'
exit_on_quit() {
	local var="$1"
	case ${var:0:1} in
	q) return 1 ;;
	*) return 0 ;;
	esac
}

remove_first_character() {
	local input_string="${1}"
	local substring="${input_string:1}"
	echo "${substring}"
}

# filter out all lines matching list of keywords
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

# Check for existence of .git repository.
# If respoitory not present, offer to initialise one.
check_is_repository() {
	# params: None
	# return value: None
	if [[ ! -d ".git" ]]; then
		echo "Git respoitory Not initialised"
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
	# err_echo "check_ver_format of: $ver"
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
		err_echo "-> Error: bad tag format"
		err_echo "-> Reverting to NULL tag"
		default_ver=$NULL_VERSION
	fi

	err_echo "-> current version:   $default_ver"
	echo "$default_ver"
}

# return single letter bump choice
get_bump_choice() {
	# No params
	local result # return value
	local msg
	err_echo
	err_echo "Next version bump kind:"
	err_echo "  Major        [M]"
	err_echo "  minor        [m]"
	err_echo "  patch        [p]"
	err_echo "  <no version> [n]"
	err_echo "  quit         [q]"
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
		err_echo "-> Error: 'get_suggested_bump' no param 2: $bump_type"
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
		# err_echo "returned value for suggested version: $suggested_version"
		err_echo ""
		err_echo "-> Press Enter to accept suggested version, or"
		err_echo "-> Over-ride with a value in M.m.p format"
		err_echo ""
		exit_loop=false
		while [[ $exit_loop != true ]]; do
			read -rp "Suggested version:      [$suggested_version]: " new_version
			err_echo ""
			if [ "$new_version" = "" ]; then
				new_version=$suggested_version # accept default
			fi
			if [[ $(check_ver_format "$new_version") == true ]]; then
				exit_loop=true
			fi
		done

		err_echo "-> new version will be:  $new_version"

		result=$(confirm_valid_version "$new_version")
		# err_echo "result value is: |""$result""|"

		if [[ "$result" == false ]]; then
			err_echo "-> Error: can not use this version. exiting"
			new_version=""
		else
			err_echo "-> all good!"
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
	err_echo "git -m title is: $title"

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

# Apptend marker line to end of GIT_MSG file
mark_git_msg_file() {
	local ver=$1 # param $1. version just commited
	echo "--- Contents above this line were committed in version: $ver ---" >>GIT_MSG
}

confirm_valid_version() {
	local ver_num=$1 # param $1: version to check
	local result # return value

	if [[ $ver_num == "$UNVERSIONED_TEXT" ]]; then
		result=true

	elif [[ $(check_for_used_version v"$ver_num") == true ]]; then
		err_echo "-> Error: This version number $ver_num has already been used."
		result=false

	elif [[ $(check_ver_format "$ver_num") == false ]]; then
		err_echo "-> Error: Improperly formatted version: $ver_num"
		result=false

	else
		result=true
	fi
	echo "$result"
}

# Populate the CHANGE_LOG file based on output from "git log"
# Note: This is done after a commit so this operation creates an 'unstaged' file.
write_changes_file() {
	# No params
	# No return value.
	# Side effect: writes to CHANGE_LOG file
	local result
	local fout
	fout="$(mktemp)"
	git log --pretty=medium >"$fout"
	result=$(filter_lines "Date" "commit" "Author" "$fout")
	# remove leading spaces (sed) and collapse multiple blank lines (cat -s)
	echo "$result" | sed "s/^[ \t]*//" | cat -s >CHANGE_LOG
}

# Clean the current branch, commit it with message from GIT_MSG, tag and push origin
commit_local_branch() {
	# param $1: version to commit
    # return value: None
	local version=$1

	prompt_confirm "Continue commit_local_branch? " || exit

	echo -e "\n=> git add ."
	echo
	git add .
	echo "=> git commit"
	result=$(create_git_message "$version") # result is an array of strings
	if [[ $TEST_MODE == false ]]; then
		git commit -m "$result"
	else
		echo "-> TEST_MODE - no commit"
	fi
	mark_git_msg_file "$version"
	if [[ $version != "$UNVERSIONED_TEXT" ]]; then
		if [[ $TEST_MODE == false ]]; then
			git tag "v${version}"
		else
			echo "-> TEST_MODE - no git tag"
		fi
	fi

	echo
	read -rn 1 -p "Push origin? [y,n] " input
	if [[ $input == 'y' ]]; then
		echo -e "\n=> git push origin -- branch":
		if [[ $TEST_MODE == false ]]; then
			git push origin
		else
			echo "-> TEST_MODE - no git push origin"
		fi
	fi
}

# Do a tag commit
create_annotated_tag() {
	local new_version=$1 # param 1
	# No return value
	local can_proceed

	prompt_confirm "Create annotated tag? " || exit

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
		echo -e "\n=> git tag -a -m"
		git tag -a -m "Tagging version $new_version" "v$new_version" # annotated tag

		read -rn 1 -p "Push origin? [y,n] " input
		if [[ $input == 'y' ]]; then
			echo -e "\n=> git push origin refs/tags/v""$new_version"""

			if [[ $TEST_MODE == false ]]; then
				# git push origin --tags
                git push origin refs/tags/v"$new_version"
			else
				echo "-> TEST_MODE - no git push origin "
			fi
		fi
	fi
}

main() {
	if [[ $TEST_MODE == true ]]; then
		echo "In test mode"
	fi


	local cur_ver new_ver
	populate_files

	# Locate our context
    echo "-> $(git --version)"
	echo "-> current directory: $(pwd)"
	check_is_repository
	show_current_branch
	show_commit_count
	cur_ver=$(get_default_version)

	# Specify intent
	bump_choice=$(get_bump_choice)
	new_ver=$(bump_current_version "$cur_ver" "$bump_choice")
	if [[ $new_ver == "" ]]; then exit 1; fi

	# Execute intent
	echo
	commit_local_branch "$new_ver"
	write_changes_file

	echo
	create_annotated_tag "$new_ver"
	echo
}

main
