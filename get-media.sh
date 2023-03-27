#!/bin/sh
LANG=de_DE.UTF-8
export LANG

#./fetch-wiki.rb team:pps:puppet_pool wiki:logo.png
./fetch-wiki.rb wiki:logo.png

grep -v "^#" media/smileys.txt |
while read url
do
	file="${url##*/}"
	fetch -m -o "media/${file}" "${url}"
done

grep "[.]jpe*g" puppet_pool.csv |
sed -e 's|.*team:pps:puppet_pictures:||' -e 's|".*||' |
sort -u |
while read jpg
do
	if test -e "media/${jpg}"
	then
		continue
	fi
	echo "${jpg}"
	./fetch-wiki.rb "team:pps:puppet_pictures:${jpg}"
done
exit 0
# eof
