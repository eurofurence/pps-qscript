#!/bin/sh
LANG=de_DE.UTF-8
export LANG
if test ! -f ./fetch-wiki.rb
then
	cd "${HOME}/pps-qscript" || exit 65
fi
set -e
case "${1}" in
auto)
	./fetch-wiki.rb
	;;
esac

make pre

# use ls to sort the filenames
./read-scene.rb $(make -V SRC)
#set +e
#final_dinoex/PPSMoments qscript.txt test.tmp
#set -e
#if diff -q test.tmp test.html
#then
#	rm -f test.tmp
#else
#	mv -vf test.tmp test.html
#fi

if test -f media/availability.csv
then
	./availability.rb
fi

make

#echo "vim -c 'set syn=wdiff' test.wdiff"

if test -f hold.txt
then
	echo "upload on hold."
	exit 0
fi

set +e
diff -bq OLD/ . |
grep -v '^Only in'
set -e

files_unchanged() {
	for file in out.html qscript.txt availability.html assignment-list.csv
	do
		if ! diff -q "${file}" "UPLOAD/${file}"
		then
			return 1
		fi
	done
	return 0
}

if files_unchanged
then
	exit 0
fi

echo "upload"
case "${1}" in
auto)
	./upload-wiki.rb
	if test -f hold-actors.txt
	then
		echo "upload actors on hold."
		exit 0
	fi
	./upload-wiki.rb actors/*.pdf
	./upload-wiki.rb actors/*.html
	./upload-wiki.rb actors.wiki actors-html.wiki
	;;
esac

# eof
