#!/bin/sh
LANG=de_DE.UTF-8
export LANG
grep "^| [A-Z]" [0-9]*.wiki |
	sed -e 's/  */ /g' |
	egrep -v -e ':. (Left|Middle|Right)' |
	sort -t : +1
# eof
