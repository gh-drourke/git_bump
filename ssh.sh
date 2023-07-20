
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
