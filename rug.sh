#!/usr/bin/env bash

source "$HOME/.config/pass-rug.conf" 2>/dev/null || source /etc/pass-rug/config 2>/dev/null

cmd_rug_generate(){
	local adjective noun username

	read -rd '\n' -a nouns < "${nouns_bank:-/usr/local/share/banks/nouns.txt}"
	read -rd '\n' -a adjectives < "${adjectives_bank:-/usr/local/share/banks/adjectives.txt}"

	adjective=$((RANDOM % "${#adjectives[@]}"))
	noun=$((RANDOM % "${#nouns[@]}"))
	username="${adjectives[$adjective]}_${nouns[$noun]}"

	while getopts 'cfq' flag; do
			case "$flag" in
				c) clip=1;;
				f) force=1;;
			esac
	done

	local path passfile tmp_file username_exists
	path="${@: -1}"
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
	fi
	echo "username:${username}" >> "${tmp_file}"

	$GPG -d -o - "${GPG_OPTS[@]}" "$passfile" 2>/dev/null | diff - "$tmp_file" &>/dev/null && die "Password unchanged."
	while ! $GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}" "$tmp_file"; do
		yesno "GPG encryption failed. Would you like to try again?"
	done
	echo "${username}"
	[[ "$clip" -eq 1 ]] && clip "${username}" "${path}"
	git_add_file "$passfile" "changed the username for $path"
}

cmd_rug_show(){
	local path passfile tmp_username username username64

	path="${@: -1}"
	check_sneaky_paths "$path"
	mkdir -p -v "$PREFIX/$(dirname -- "$path")"
	set_gpg_recipients "$(dirname -- "$path")"
	passfile="$PREFIX/$path.gpg"
	set_git "$passfile"

	tmp_username="$($GPG -d "${GPG_OPTS[@]}" "$passfile" | grep "^username:")"
	username="${tmp_username##username:}"

	while getopts ':c' flag; do
		case $flag in
		c) clip "$username" "$path";;
		esac 
	done
}

case "$1" in
	generate|g) shift; cmd_rug_generate "$@";;
	show|s) shift; cmd_rug_show "$@";;
	*) die "$1: invalid action";;
esac
