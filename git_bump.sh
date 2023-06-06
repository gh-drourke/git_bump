#!/bin/bash

default_version="0.1.0"

# reg exp to test for a valid version tag
# local regex="^v\d+\.\d+\.\d+$" # does not work

regexV="^v[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}$"
regex="^[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}$"

match_pattern() {
	input_str="$1"
	pattern_str="$2"

	if [[ "$input_str" =~ $pattern_str ]]; then
		echo true
	else
		echo false
	fi
}

prompt_confirm() {
	# usage: prompt_confirm "message" || exit 0
	local msg=$1
	local reply
	while true; do
		read -r -n 1 -p "$msg [y/n]: " reply
		case $reply in
		[yY]) return 0 ;;
		[nN]) return 1 ;;
		*) printf " \033[31m %s \n\033[0m" "invalid input" ;;
		esac
	done
}

# return single letter choice
get_input_choice() {
	# param $1: list of single letter choices
	local choices=$1
	local msg="choices: [$choices]"
	local valid_pattern="^[$choices]$"

	while true; do
		read -rn 1 -p "$msg" input_char
		err_echo ""
		if [[ $input_char =~ $valid_pattern ]]; then
			break
		fi
	done
	# err_echo "length input: ${#input_char}"
	echo "${input_char:0:1}"
}

err_echo() {
	echo "$1" >&2
}

exit_on_quit() {
	# err_echo "------------"
	local var="$1"
	# err_echo "enter () exit_on_quit: param is: $var"
	# err_echo "...  length param is: ${#var}"
	# for i in $(seq ${#var}); do
	# 	err_echo "$i : ${var:$i:1}"
	# done
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

filter_lines() {
	local keywords=("$@")
	local file="${keywords[-1]}"
	local filtered_lines
	unset 'keywords[${#keywords[@]}-1]' # Remove the last element (file name)

	pattern=$(
		IFS="|"
		echo "${keywords[*]}"
	)
	filtered_lines=$(awk -v pattern="$pattern" '!($0 ~ pattern)' "$file")
	echo "$filtered_lines"
}

# Check for existence of .git repository.
check_is_repository() {
	if [[ ! -d ".git" ]]; then
		echo "Not initialised for git"
		read -r -n 1 -p "Press 'y' to initialise: " input
		if [[ $input == 'y' ]]; then
			git init --initial-branch="main"
			echo "-> git is now initialised"
		else
			echo "-> Exiting: No git repository"
			exit
		fi
	fi
}

show_current_branch() {
	echo "-> current branch:    $(git rev-parse --abbrev-ref HEAD)"
}

show_commit_count() {
	if [[ $(git_has_commits) == true ]]; then
		count=$(git rev-list HEAD --count)
		echo "-> has $count commits"
	else
		echo "-> has No commits"
	fi
}
# Return true is git has commits
git_has_commits() {
	if [[ "$(git log --oneline 2>/dev/null | wc -l)" -eq 0 ]]; then
		echo false
	else
		echo true
	fi
}

populate_files() {
	# if [[ ! -f VERSION ]]; then
	# 	echo "creating file: VERSION"
	# fi
	# echo "$new_version" >VERSION

	if [[ ! -f GIT_MSG ]]; then # TODO TAG_MSG
		echo "creating file: GIT_MSG"
		touch GIT_MSG
	fi
}

handle_error() {
	echo "A trap error occurred!"
	# Additional error handling logic can be added here
}

# Get the latest version tag
NO_TAGS="<no tags>"

git_latest_tag() {
	local latest_tag

	if [[ $(git tag | wc -l) == 0 ]]; then
		latest_tag=$NO_TAGS
	else
		latest_tag=$(git describe --tags --abbrev=0)
	fi
	echo "$latest_tag"
}

check_ver_format() {
	local ver=$1
	if [[ $ver =~ $regex ]]; then
		echo "true"
	else
		echo "false"
	fi
}

check_tag_format() {
	local tag=$1
	if [[ $tag =~ $regexV ]]; then
		echo true
	else
		echo false
	fi
}

# Get default version from previous commit.
# If no previous commits, then use default.
get_default_version() {
	# params: none
	local latest_tag=""

	if [[ $(git_has_commits) == true ]]; then
		latest_tag=$(git_latest_tag)
		# err_echo "-> latest tag compare:        $latest_tag"
		if [[ $latest_tag == "$NO_TAGS" ]]; then
			latest_tag=$NO_TAGS
		elif
			[[ $(check_tag_format "$latest_tag") == true ]]
		then
			latest_tag=$(remove_first_character "$latest_tag")
		else
			err_echo "-> ERROR: bad tag format"
			latest_tag=default_version
		fi
	fi
	echo "$latest_tag"
}

get_suggested_bump() {
	local cur_version=$1
	local bump_type=$2
	local v_major v_minor v_patch
	local new_version # return value
	local suggested_version
	if [[ $(check_ver_format "$cur_version") == false ]]; then
		err_echo "Version found has incorrect format"
		err_echo "Correction to default version: $default_version"
		cur_version=$default_version
	fi

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
bump_current_version() {
	# param $1: version to bump
	# param $2: bump_code -- Major, minor, patch
	# return wanted version number in M.m.p format
	local cur_version=$1
	local bump_code=$2
	local new_version # return value
	local suggested_version
	# err_echo "enter bump_current_version: ver=$cur_version  bump_code=$bump_code"

	if [[ $cur_version == "$NO_TAGS" ]]; then
		cur_version=$default_version
		err_echo "-> setting to default version: $cur_version"
	fi

	if [[ $bump_code == 'n' ]]; then
		err_echo "Not using a version number for this branch commit"
		echo ""
	else
		suggested_version=$(get_suggested_bump "$cur_version" "$bump_code")
		# err_echo "returned value for suggested version: $suggested_version"
		err_echo ""
		err_echo "-> Press Enter to accept suggested version, or"
		err_echo "-> ... override with a value in M.m.p format"
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

# return single letter bump choice
get_bump_choice() {
	local cur_ver=$1
	local msg
	local result
	# local tag_pattern='^[Mmpq]$'
	err_echo
	if [[ $cur_ver == "$NO_TAGS" ]]; then
		err_echo "-> There are no tagged version"
		err_echo "-> The first default tag is: $default_version"
	else
		err_echo "-> current version:    $cur_ver"
	fi
	err_echo "Choose next version as:"
	err_echo "  Major        [M]"
	err_echo "  minor        [m]"
	err_echo "  patch        [p]"
	err_echo "  <no version> [n]"
	err_echo "  quit [q]"
	result=$(get_input_choice "Mmpnq")
	echo "${result:0:1}"
}

get_commit_kind() {
	local input_char
	err_echo ""
	err_echo "Specify kind of commit?"
	err_echo "  Branch commit only [B]"
	err_echo "  Branch and Tag commit [T]"
	err_echo "  Quit [q]"
	input_char=$(get_input_choice "BTq")
	# err_echo "  --> get_commit_kind returning: $input_char"
	echo "$input_char"
}

# return git message
form_git_message() {
	# param $1: new version
	local version=$1
	local fout
	local lines
	fout=$(mktemp)
	# err_echo "enter form_git_message with version: $version"

	if [[ $(check_ver_format "$version") == false ]]; then
		title="no version"
	else
		title="version: ${version}"
	fi
	err_echo "title is: $title"

	echo "$title" >"$fout"
	echo "" >>"$fout"
	cat GIT_MSG >>"$fout"
	# cat -s "$fout" >&2
	while IFS= read -r line; do
		lines+=("$line")
	done <"$fout"

	for line in "${lines[@]}"; do
		echo "$line"
	done
}

# Clean the current branch and commit it with message from GIT_MSG
commit_branch() {
	local version=$1
	echo "=> git add ."
	git add .
	echo "=> git commit"
	result=$(form_git_message "$version") # result is an array of strings
	# echo "--- file ---"
	# echo -e "$result"
	# echo "--- file ---"
	# prompt_confirm "Continue commit_branch? " || exit

	git commit -m "$result"
	git tag "v${version}"

	err_echo ""
	read -rn 1 -p "Push origin? [y,n] " input
	if [[ $input == 'y' ]]; then
		echo "=> git push origin -- branch":
		git push origin
	fi
}

write_changes_file() {
	local fout
	fout="$(mktemp)"
	git log --pretty=medium >"$fout"
	result=$(filter_lines "Date" "commit" "Author" "$fout")
	# remove leading spaces (sed) and collapse multiple blank lines (cat -s)
	echo "$result" | sed "s/^[ \t]*//" | cat -s >CHANGES
}

commit_tag() {
	local new_version=$1

	if [[ -z "$new_version" ]]; then
		echo "-> new_version String is empty"
		echo "-> Aborting commit"
		exit
	else
		echo "-> proceeding with commit"
	fi

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
	echo "-> Current directory: $(pwd)"
	check_is_repository
	show_current_branch
	show_commit_count
	cur_ver=$(get_default_version)
	echo "-> current version: $cur_ver"
	populate_files

	bump_choice=$(get_bump_choice "$cur_ver")
	exit_on_quit "$bump_choice" || exit 1
	# echo "-> bump choice: $bump_choice"

	new_ver=$(bump_current_version "$cur_ver" "$bump_choice")
	echo "-> new version will be: $new_ver"

	prompt_confirm "Continue commit_branch? " || exit
	commit_branch "$new_ver"
	write_changes_file

	echo ""
	prompt_confirm "Continue commit tag? " || exit
	commit_tag "$new_ver"
	echo

	# echo -e "\n----- changes -----"
	# head -n 15 CHANGES
	# echo -e "----------"
}

main

# match_pattern "fatal:" "^fatal:"
#
# result=$(git_latest_tag)
# echo "result is: $result"
# echo "---"
