#!/bin/sh
LANG=de_DE.UTF-8
export LANG
cd /usr/home/dm/Hay || exit 65
set -e
case "${1}" in
auto)
	./fetch-wiki.rb
#	./fetch-wiki.rb team:pps:puppet_pool
#	if diff -q scene11_fixed.wiki scene11.fixed
#	then
#		exit 0
#	else
#		cp -pv scene11_fixed.wiki scene11.fixed
#	fi
	;;
esac

make

#./makeall.sh > all.wiki

#./read-scene.rb scene11.fixed
#./read-scene.rb scene11.wiki scene12.wiki scene13.wiki 
./read-scene.rb scene*.wiki

set +e
final_dinoex/PPSMoments qscript.txt test.html
set -e

#rsync -aq subs.ini subs.txt
#cat -n qscript.txt > numbered-qscript.txt
make

#ed test.html << EOF
#%s///g
#/\/body>
#-1
#.r html.html
#w
#EOF

# tidy4 -wrap 5000 out.html > tidy.html

#lynx -dump -display_charset=utf-8 -nonumbers -width=5000 out.html |
#fgrep -v 'file:' >out.txt

#lynx -dump -display_charset=utf-8 -nonumbers -width=5000 test.html |
#fgrep -v 'file:' > test.txt

#echo 'wdiff [-out.html-] {+test.html+}' > test.wdiff
#set +e
#wdiff -n out.html test.html >> test.wdiff
#set -e
echo "vim -c 'set syn=wdiff' test.wdiff"

# scp -p out.html anime.dinoex.net:public_html/anime.dinoex.net/pps.html
#cp qscript.txt ~/Downloads/qscript.txt
#cp out.html ~/Downloads/out.html
#cp scene11.fixed ~/Downloads/wiki_fixed.txt

diff -ubq OLD/ . |
grep -v '^Only in'

if diff -q out.html UPLOAD/out.html
then
	if diff -q qscript.txt UPLOAD/qscript.txt
	then
		exit 0
	fi
fi

#./makepdf.sh clothes.pdf

if test -f hold.txt
then
	echo "upload on hold."
	exit 0
fi

echo "upload"
# lynx lynx https://anime.dinoex.net/pps.html
# lynx out.html
#mv -v out.txt out.bak
#mv -v test.txt out.txt
case "${1}" in
auto)
	./upload-wiki.rb
#	./upload-wiki.rb out.html qscript.txt out.txt clothes.pdf all.wiki numbered-qscript.txt subs.txt all.pdf
	;;
esac
#mv -v out.txt test.txt
#mv -v out.bak out.txt

#./fetch-wiki.rb ef25:events:pps:qscript:all.raw
#./makepdf.sh all.pdf
#case "${1}" in
#auto)
#	./upload-wiki.rb all.pdf
#	;;
#esac

# eof
