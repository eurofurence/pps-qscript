#!/bin/sh
LANG=de_DE.UTF-8
export LANG
grep '<sp>' *.wiki | grep -v '</sp>'
grep '<hp>' *.wiki | grep -v '</hp>'
grep '<fp>' *.wiki | grep -v '</fp>'
grep '<pp>' *.wiki | grep -v '</pp>'
egrep '^timeframe|TODO' qscript.txt
# eof
