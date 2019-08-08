# Makefile

SRC!=	ls scene*.wiki

all:	subs.txt numbered-qscript.txt out.txt test.txt test.wdiff \
	all.wiki clothes.pdf all.pdf puppet_pool.csv tidy.html

pre:	all.wiki puppet_pool.csv

subs.txt:	subs.ini
	rsync -aq subs.ini subs.txt

numbered-qscript.txt:	qscript.txt
	cat -n qscript.txt > numbered-qscript.txt

out.txt:	out.html
	lynx -dump -display_charset=utf-8 -nonumbers -width=5000 out.html |\
	fgrep -v 'file:' >out.txt

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

all.wiki:	makeall.sh header.wiki
	./makeall.sh > all.wiki

puppet_pool.csv:	puppet_pool.rb puppet_pool.wiki media/smileys.txt
	./puppet_pool.rb
	./get-media.sh

all.html:	${SRC}
	./fetch-wiki.rb ef25:events:pps:qscript:all.html

tidy.html:	out.html
	-tidy4 -wrap 5000 out.html > tidy.html

do::
	diff -bu OLD/ . | grep -v '^Only in' | less

du::
	diff -bu UPLOAD/ . | grep -v '^Only in' | less

dt::
	diff -biu out.txt test.txt | less

lint::
	rubocop *.rb

save-lint::
	rubocop --auto-gen-config *.rb

doc::
	rdoc -V *.rb

# eof
