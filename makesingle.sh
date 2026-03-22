#!/bin/sh
show="$(grep :events:pps:script: index.wiki | head -1 | cut -d : -f2)"
for scene in $( make -V SRC )
do
	(
		cat header.wiki
		echo "{{page>${show}:events:pps:script:${scene%.wiki}}}"
	) > "tmp.single_${scene}"
	if diff -q "single_${scene}" "tmp.single_${scene}"
	then
		rm -f "tmp.single_${scene}"
		continue
	fi
	mv -fv "tmp.single_${scene}" "single_${scene}"
done
exit 0
# eof
