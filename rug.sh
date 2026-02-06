#!/usr/bin/env bash #set -ex
cmd_rug_edit(){
	local path passfile tmp_file username_exists
	path="${1%/}"
	check_sneaky_paths "$path"
	mkdir -p -v "$PREFIX/$(dirname -- "$path")"
	set_gpg_recipients "$(dirname -- "$path")"
	passfile="$PREFIX/$path.gpg"
	set_git "$passfile"

	tmpdir #Defines $SECURE_TMPDIR
	tmp_file="$(mktemp -u "$SECURE_TMPDIR/XXXXXX")-${path//\//-}.txt"

	if [[ -f $passfile ]]; then
		$GPG -d -o "$tmp_file" "${GPG_OPTS[@]}" "$passfile" || exit 1
		grep -q "^username:" "$tmp_file" && username_exists=1
		[[ "$force" -ne 1 && "$username_exists" -eq 1 ]] && yesno "A username already exists for $path. overwrite it?"
		sed -i '/^username:.*/d' "$tmp_file" || die "write failed, operation aborted."
		echo "username:${username}" >> "${tmp_file}"
	else
		echo "username:${username}" > "${tmp_file}"
	fi
	echo "username:${username}"

	$GPG -d -o - "${GPG_OPTS[@]}" "$passfile" 2>/dev/null | diff - "$tmp_file" &>/dev/null && die "Password unchanged."
	while ! $GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}" "$tmp_file"; do
		yesno "GPG encryption failed. Would you like to try again?"
	done
	git_add_file "$passfile" "changed the username for $path"
}

cmd_rug_generate(){
	local adjective noun username
	[[ $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND pass-name"

	while getopts 'cfq' flag; do
		case "$flag" in
			c) clip=1;;
			f) force=1;;
			q) qrcode=1;;
			*) die "invalid flag"
		esac
	done

	read -rd '\n' -a nouns < "${nouns_bank:-/usr/share/banks/nouns.txt}"
	read -rd '\n' -a adjectives < "${adjectives_bank:-/usr/share/banks/adjectives.txt}"

	adjective=$((RANDOM % "${#adjectives[@]}"))
	noun=$((RANDOM % "${#nouns[@]}"))
	username="${adjectives[$adjective]}_${nouns[$noun]}"

	cmd_rug_edit "$@"
	echo "${username}"
	[[ "$clip" -eq 1 ]] && clip "${username}"
}

cmd_rug_show(){
	local path passfile tmp_username username username64
	path="${2%/}"
	check_sneaky_paths "$path"
	mkdir -p -v "$PREFIX/$(dirname -- "$path")"
	set_gpg_recipients "$(dirname -- "$path")"
	passfile="$PREFIX/$path.gpg"
	set_git "$passfile"

	tmp_username="$($GPG -d "${GPG_OPTS[@]}" "$passfile" | grep "^username:")"
	username="${tmp_username##username:}"
	# from pass:
		# "This base64 business is because bash cannot store binary data in a shell
		#  variable. Specifically, it cannot store nulls nor (non-trivally) store
		#  trailing new lines."
		# and i also dont want to rewrite whole functions that have already been written for pass
	username64="$(base64 <<< "$username")"

	while getopts ':cqs' flag; do
		case $flag in
		q) 
   			qrcode "$username" "$path";;
		c) 
   			clip "$username" "$path";;
		s) 
   			echo "$username";;
		esac 
	done
}

case "$1" in
	generate|g) shift; cmd_rug_generate "$@";;
	show|s) shift; cmd_rug_show "$@";;
	*) die "invalid option";;
esac
