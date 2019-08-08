#!/bin/sh
LANG=de_DE.UTF-8
export LANG
cd /usr/home/dm/Hay/haskell || exit 65
set -e
case "${1}" in
auto)
	./fetch-wiki.rb
	;;
esac

make pre

./read-scene.rb scene*.wiki

#set +e
set -e
../final_dinoex/PPSMoments qscript.txt test.tmp
set -e
if diff -q test.tmp test.html
then
	rm -f test.tmp
else
	mv -vf test.tmp test.html
fi

make

echo "vim -c 'set syn=wdiff' test.wdiff"

if test -f hold.txt
then
	echo "upload on hold."
	exit 0
fi

set +e
diff -ubq OLD/ . |
grep -v '^Only in'
set -e

if diff -q out.html UPLOAD/out.html
then
	if diff -q qscript.txt UPLOAD/qscript.txt
	then
		exit 0
	fi
fi

echo "upload"
case "${1}" in
auto)
	./upload-wiki.rb
	;;
esac

# eof
