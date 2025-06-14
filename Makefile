# Makefile

DDATE!=		date +%Y-%m-%d
QSPATH!=	grep ^qspath: wiki-config.yml | cut -d '"' -f2
FILTER!=	grep ^sources: wiki-config.yml | cut -d '"' -f2
SRC!=		grep ':script:' index.wiki | cut -d '|' -f1 | cut -d ':' -f6 | sed -e 's|$$|.wiki|' | grep -E '${FILTER}'
ACTORS_HTML!=	ls actors/*.html

ACTORS_HTMLS=	${ACTORS_HTML:S/.html/.html,/g:S/,$//}
ACTORS_PDF=	${ACTORS_HTML:S/html/pdf/g}
ACTORS_LIST=	${ACTORS_HTML:S/.html//g}

all:	numbered-qscript.txt out.txt \
	all.wiki plain.wiki clothes.pdf all.pdf \
	puppet_pool.json tidy.html \
	actors/run.log actors

.if exists(media/availability.csv)
all:	availability.txt
.endif

.if exists(test.html)
all:	test.txt test.wdiff
.endif

pre:	all.wiki puppet_pool.json

numbered-qscript.txt:	qscript.txt
	cat -n qscript.txt > numbered-qscript.txt

#hs-qscript.txt:	qscript.txt Makefile
#	sed \
#		-e 's|techProp|handProp|g' \
#		-e 's|TechProp|HandProp|g' \
#		qscript.txt > hs-qscript.txt

out.txt:	out.html
	lynx -dump -display_charset=utf-8 -nonumbers -width=5000 out.html |\
	fgrep -v 'file:' >out.txt

availability.txt:	availability.html
	lynx -dump -display_charset=utf-8 -nonumbers -width=5000 availability.html |\
	fgrep -v 'file:' >availability.txt

test.txt:	test.html
	lynx -dump -display_charset=utf-8 -nonumbers -width=5000 test.html |\
	fgrep -v 'file:' > test.txt

test.wdiff:	out.html test.html
	echo 'wdiff [-out.html-] {+test.html+}' > test.wdiff
	-wdiff -n out.html test.html >> test.wdiff

clothes.pdf:	makepdf.sh makepdf.sed clothes.html
	./makepdf.sh clothes.pdf

all.pdf:	makepdf.sh makepdf.sed all.html
	./makepdf.sh all.pdf

all.ps:		all.pdf
	pdf2ps all.pdf

actors/run.log:	highlite-actors.rb all.html wiki-actors.json
	./highlite-actors.rb

.for actor in ${ACTORS_LIST}
${actor}.pdf:	makepdf.sh makepdf.sed ${actor}.html
	./makepdf.sh ${actor}.pdf

.endfor

actors::	${ACTORS_PDF}

all.wiki:	makeall.sh header.wiki index.wiki
	./makeall.sh > all.wiki

plain.wiki:	Makefile all.wiki
	sed -e '/^@media (prefers-color-scheme/,/^}/d' all.wiki > plain.wiki

puppet_pool.json:	puppet_pool.rb puppet_pool.wiki media/smileys.txt
	./puppet_pool.rb
	./get-media.sh

all.html:	${SRC} UPLOAD/all.wiki
	./fetch-wiki.rb "${QSPATH}:all.html"

index.wiki:
	./fetch-wiki.rb

tidy.html:	out.html
	-tidy4 -wrap 5000 out.html > tidy.html 2>tidy.log

do::
	diff -bu OLD/ . | grep -v '^Only in' | less

du::
	diff -bu UPLOAD/ . | grep -v '^Only in' | less

dt::
	diff -biu out.txt test.txt | less

cop::
	rubocop *.rb

save-cop::
	rubocop --auto-gen-config *.rb

doc::
	rdoc -V *.rb

hold::
	touch hold.txt

unhold:
	rm -f hold.txt

dump:
	/media/furry/fp/bin/dump-json.rb wiki_actors.json

save::
	rsync -a OLD/ all.html all.html.orig HISTORY/${DDATE}/

clean:
	touch hold-actors.txt hold.txt
	rm -vf ${SRC} index.wiki all.wiki all.html.orig.*
	rm -vf availability.csv availability.debug availability.*.json \
		availability.html availability.txt
	rm -vf actors/UPLOAD/*.* UPLOAD/*.*
	touch 00_dummy.wiki
	cp header.wiki.sample header.wiki
	cp roles.wiki.sample roles.wiki
	cp subs.wiki.sample subs.wiki
	# ./upload-wiki.rb header.wiki subs.wiki roles.wiki
	# qsript:index.wiki copy?

# eof
