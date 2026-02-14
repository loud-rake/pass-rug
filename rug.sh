#!/usr/bin/env bash
#set -x

source "$HOME/.config/pass-rug.conf" 2>/dev/null || source /etc/pass-rug/config 2>/dev/null

cmd_rug_generate(){
	#TODO: generate a password without writing to a file, instead of dying.
	[[ $# -eq 0 ]] && die "usage: pass rug g|generate [-cf] pass-name"
	local adjective noun username flag path passfile tmp_file username_exists

	read -rd '\n' -a nouns < "${nouns_bank:-/usr/share/banks/nouns.txt}"
	read -rd '\n' -a adjectives < "${adjectives_bank:-/usr/share/banks/adjectives.txt}"

	adjective=$((RANDOM % "${#adjectives[@]}"))
	noun=$((RANDOM % "${#nouns[@]}"))
	username="${adjectives[$adjective]}_${nouns[$noun]}"

	while getopts 'cf' flag; do
			case "$flag" in
				c) clip=1;;
				f) force=1;;
			esac
	done

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
	[[ $# -eq 0 ]] && die "usage: pass rug s|show [-cs] pass-name"
	local path passfile tmp_username username

	path="${@: -1}"
	check_sneaky_paths "$path"
	mkdir -p -v "$PREFIX/$(dirname -- "$path")"
	set_gpg_recipients "$(dirname -- "$path")"
	passfile="$PREFIX/$path.gpg"
	set_git "$passfile"

	#TODO: there has to be a cleaner way to find the username..
	tmp_username="$($GPG -d "${GPG_OPTS[@]}" "$passfile" | grep "^username:")"
	username="${tmp_username##username:}"

	while getopts ':cs' flag; do
		case $flag in
		c) clip "$username" "$path";;
		s) echo "$username";;
		esac 
	done
}

case "$1" in
	generate|g) shift; cmd_rug_generate "$@";;
	show|s) shift; cmd_rug_show "$@";;
	*) cmd_rug_show "$@";;
esac
