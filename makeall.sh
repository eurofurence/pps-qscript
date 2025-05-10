#!/bin/sh
show="$(grep :events:pps:script: index.wiki | head -1 | cut -d : -f2)"
cat header.wiki
for scene in $( make -V SRC )
do
	echo "{{page>${show}:events:pps:script:${scene%.wiki}}}"
done
exit 0
# eof
