#!/bin/bash

default_version="0.1.0"

# reg exp to test for a valid version tag
# local regex="^v\d+\.\d+\.\d+$" # does not work

regexV="^v[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}$"
regex="^[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}$"

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
		read -rp "Press 'y' to initialise: " input
		if [[ $input == 'y' ]]; then
			git init --initial-branch="main"
			echo "-> git is now initialised"
		else
			echo "-> Exiting: No git repository"
		fi
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

# Get the latest version tag
git_latest_tag() {
	local latest_tag
	latest_tag=$(git describe --tags --abbrev=0)
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
	local latest_tag

	if [[ $(git_has_commits) == true ]]; then
		latest_tag=$(git_latest_tag)
		echo "-> latest tag:        $latest_tag" >&2
		if [[ $(check_tag_format "$latest_tag") == true ]]; then
			remove_first_character "$latest_tag"
			exit
		else
			echo "-> ERROR: bad tag format" >&2
		fi
	fi
	echo "-> using default version: $default_version" >&2
	# echo "$default_version"

	# if [[ -f VERSION ]]; then
	# 	ver=$(cat VERSION)
	# 	if [[ $(check_ver_format $ver) == false ]]; then
	# 		echo "$default_version"
	# 	else
	# 		echo "$ver"
	# 	fi
	# else
	# 	echo "$default_version"
	# fi
}

# Suggest a new version based on previous version and
# choice from M, m, p prompt.
bump_current_version() {
	# param $1: version to bump
	# param $2: part to bump -- Major, minor, patch
	# return wanted version number in M.m.p format
	local cur_version=$1
	local part=$2
	local v_major v_minor v_patch
	local new_version # return value
	local suggested_version

	base_list=($(echo "$cur_version" | tr '.' ' '))
	v_major=${base_list[0]}
	v_minor=${base_list[1]}
	v_patch=${base_list[2]}

	case $part in
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
	*)
		echo "ERROR: 'bump_current_version' no param 2: $part" >&2
		exit
		;;
	esac

	suggested_version="$v_major.$v_minor.$v_patch"
	# read -rp "Enter a version number [$suggested_version]: " new_version

	# if [ "$new_version" = "" ]; then
	# 	new_version=$suggested_version # accept default
	# fi
	exit_cond=false
	while [[ $exit_cond != true ]]; do
		echo "-> Press Enter to accept suggested version, or" >&2
		echo "-> ... override with a value in M.m.p format" >&2
		read -rp "Suggested version:     [$suggested_version]: " new_version
        echo "" >&2
		if [ "$new_version" = "" ]; then
			new_version=$suggested_version # accept default
		fi
		if [[ $(check_ver_format "$new_version") == true ]]; then
			exit_cond=true
		fi
	done
	echo "$new_version"
}

git_commit() {
	local new_version=$1
	if [[ -z "$new_version" ]]; then
		echo "-> new_version String is empty"
		echo "-> Aborting commit"
		exit
	else
		echo "-> preceding with commit"
	fi

	OUT="$(mktemp)"
	{
		echo "Version: $new_version"
		echo ""
		cat GIT_MSG
	} >"$OUT"

	echo -e "\n----- git_msg -----"
	cat "$OUT"
	echo "----------"

	echo "=> git add ."
	git add .
	echo "=> git commit"
	git commit -m "$(cat "$OUT")"
	echo "=> git tag"
	git tag -a -m "Tagging version $new_version" "v$new_version"
	read -rn 1 -p "Push origin? [y,n] " input
	if [[ $input == 'y' ]]; then
		echo "=> git push origin --tags"
		git push origin --tags
	fi

	OUT2="$(mktemp)"
	git log --pretty=medium >"$OUT2"
	result=$(filter_lines "Date" "commit" "Author" "$OUT2")
	# remove leading spaces (sed) and collapse multiple blank lines (cat -s)
	echo "$result" | sed "s/^[ \t]*//" | cat -s >CHANGES
}

populate_files() {
	# if [[ ! -f VERSION ]]; then
	# 	echo "creating file: VERSION"
	# fi
	# echo "$new_version" >VERSION

	if [[ ! -f GIT_MSG ]]; then
		echo "creating file: GIT_MSG"
		touch GIT_MSG
	fi
}

show_commit_count() {
	if [[ $(git_has_commits) == true ]]; then
		count=$(git rev-list HEAD --count)
		echo "-> has $count commits"
	else
		echo "-> has No commits"
	fi
}

get_bump_choice() {
	local cur_ver=$1
	local msg
	local valid_pattern='^[Mmpq]$'
	echo "-> current version is: $cur_ver" >&2
	msg="Do you want to bump M(ajor), (m)inor, (p)atch or (q)uit? [M,m,p,q] "
	while true; do
		read -rn 1 -p "$msg" input_char
		# echo >&2
		if [[ $input_char =~ $valid_pattern ]]; then
			break
		fi
	done
	echo "$input_char"
}

main() {
	local cur_ver new_ver
	echo "-> Current directory: $(pwd)"
	check_is_repository
	show_commit_count
	cur_ver=$(get_default_version)
	bump_choice=$(get_bump_choice "$cur_ver")
	test "$bump_choice" || exit
    if [[ "$bump_choice" == 'q' ]]; then exit; fi
	echo "-> bump choice: $bump_choice"
	new_ver=$(bump_current_version "$cur_ver" "$bump_choice")
	echo "-> new version will be: $new_ver"
	prompt_confirm "Continue? " || exit
	echo
	populate_files
	git_commit "$new_ver"

	# echo -e "\n----- version -----"
	# cat VERSION
	echo -e "\n----- changes -----"
	head -n 15 CHANGES
	echo -e "----------"
}

main
