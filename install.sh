#!/usr/bin/env bash
mkdir -p /usr/share/banks
cp {"${adjectives_bank:-adjectives.txt}","${nouns_bank:-nouns.txt}"} /usr/share/banks/
cp rug.sh /usr/lib/password-store/extensions/rug.bash
cp docs/pass-rug.1.gz /usr/share/man/man1/
mkdir -p /usr/share/lincenses/pass-rug
cp COPYING /usr/share/lincenses/pass-rug
