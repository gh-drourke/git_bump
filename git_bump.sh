#!/bin/bash

# reg exp to test for a valid version tag
# local re_ver="^v\d+\.\d+\.\d+$" # does not work

# Globals
re_tag="^v[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}$"
re_ver="^[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}$"
unversioned_text="( no version tag )"

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
		echo "creating file: GIT_MSG"
		touch GIT_MSG
	fi
}

handle_error() {
	echo "A trap error occurred!"
}

NO_TAGS="<no tags>" # TODO - remove
# null version is a valid version format but indicates
# no version present in the repository.
NULL_VERSION="0.0.0"
NULL_TAG="v$NULL_VERSION"

# return true if 'version has valid format
check_ver_format() {
	local ver=$1
	# err_echo "check_ver_format of: $ver"
	if [[ $ver =~ $re_ver ]]; then
		echo "true"
	else
		echo "false"
	fi
}

# return true if tag format conforms to:  v<digits>.<digits>.<digits>
check_tag_format() {
	local tag=$1
	if [[ $tag =~ $re_tag ]]; then
		echo true
	else
		echo false
	fi
}

# Get the latest tag
# example tag: "v0.1.8"
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
# If no previous commits, then use default.
# return the latest tag used.
# params: none
get_default_version() {
	# No params
	local default_ver # return value

	latest_tag="$(get_latest_tag)"

	if [[ $(check_tag_format "$latest_tag") == true ]]; then
		default_ver=$(remove_first_character "$latest_tag")
	else
		err_echo "-> ERROR: bad tag format"
		err_echo "-> Reverting to NULL tag"
		default_ver=$NULL_VERSION
	fi
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
		err_echo "ERROR: 'get_suggested_bump' no param 2: $bump_type"
		exit
		;;
	esac

	suggested_version="$v_major.$v_minor.$v_patch"
	echo "$suggested_version"
}

# Suggest a new version based on previous version and
# choice from M, m, p prompt.
# return wanted version number in M.m.p format
bump_current_version() {
	# param $1: version to bump
	# param $2: bump_code -- Major, minor, patch, none
	local new_version # return value

	local cur_version=$1
	local bump_code=$2
	local suggested_version

	if [[ $bump_code == 'n' ]]; then
		# err_echo "Not using a version number for this branch commit"
		echo "$unversioned_text"
	else
		suggested_version=$(get_suggested_bump "$cur_version" "$bump_code")
		# err_echo "returned value for suggested version: $suggested_version"
		err_echo ""
		err_echo "-> Press Enter to accept suggested version, or"
		err_echo "-> Over-ride with a value in M.m.p format"
		err_echo ""
		exit_cond=false
		while [[ $exit_cond != true ]]; do
			read -rp "Suggested version:     [$suggested_version]: " new_version
			err_echo ""
			if [ "$new_version" = "" ]; then
				new_version=$suggested_version # accept default
			fi
			if [[ $(check_ver_format "$new_version") == true ]]; then
				exit_cond=true
			fi
		done

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
	# err_echo "enter create_git_message with version: $version"

	# if [[ $(check_ver_format "$version") == false ]]; then
	# 	title="no version"
	# else
	# 	title="version: ${version}"
	# fi

	title="version: ${version}"
	err_echo "title is: $title"

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

mark_git_msg_file() {
	echo "--- Contents above this line have been committed" >>GIT_MSG
}

confirm_valid_version() {
	# param $1: version to check
	local tag=$1
	local result=true

	if [[ $tag == "$unversioned_text" ]]; then
		result=true
	else
		if [[ $(check_for_used_version v"$tag") == true ]]; then
			result=false
			err_echo "This version tag $tag has already been used."
		fi

		if [[ $(check_ver_format "$tag") == false ]]; then
			result=false
			err_echo "Improperly formatted version: $tag"
		fi
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

# Clean the current branch and commit it with message from GIT_MSG
commit_branch() {
	# param $1: version to commit
	local version=$1
	echo "=> git add ."
	git add .
	echo "=> git commit"
	result=$(create_git_message "$version") # result is an array of strings
	git commit -m "$result"
	mark_git_msg_file
	if [[ $version != "$unversioned_text" ]]; then
		git tag "v${version}"
	fi

	err_echo ""
	read -rn 1 -p "Push origin? [y,n] " input
	if [[ $input == 'y' ]]; then
		echo "=> git push origin -- branch":
		git push origin
	fi
}

# Do a tag commit
commit_tag() {
	local new_version=$1

	if [[ -z "$new_version" ]]; then
		echo "-> new_version String is empty"
		echo "-> Aborting commit"
		exit
	else
		echo "-> proceeding with commit"
	fi

	# TODO: test version for proper format

	echo "=> git tag"
	# git tag -a -m "Tagging version $new_version" "v$new_version" # annotated tag
	read -rn 1 -p "Push origin? [y,n] " input
	if [[ $input == 'y' ]]; then
		echo "=> git push origin --tags"
		git push origin --tags
	fi
}

main() {
	local cur_ver new_ver
	populate_files
	echo "-> current directory: $(pwd)"
	check_is_repository
	show_current_branch
	show_commit_count

	cur_ver=$(get_default_version)
	echo "-> current version:   $cur_ver"

	bump_choice=$(get_bump_choice)
	exit_on_quit "$bump_choice" || exit 1

	new_ver=$(bump_current_version "$cur_ver" "$bump_choice")
	echo -e "\n-> new version will be: $new_ver"

	if [[ $(confirm_valid_version "$new_ver") == false ]]; then
		echo "error: can not use this version. exiting"
		exit
	fi

	echo
	prompt_confirm "Continue commit_branch? " || exit
	commit_branch "$new_ver"
	write_changes_file

	echo ""
	prompt_confirm "Continue commit tag? " || exit
	commit_tag "$new_ver" # TODO: check for un-tagged commit
	echo
}

main
