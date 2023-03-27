#!/bin/sh
cat header.wiki
for scene in *scene*.wiki
do
	echo "{{page>ef26:events:pps:script:${scene%.wiki}}}"
done
exit 0
# eof
