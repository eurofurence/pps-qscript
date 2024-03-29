#!/bin/sh

make_pdf() {
	src="${1}"
	shift
	tmp="${1}"
	shift
	pdf="${1}"
	shift
	sed -f makepdf.sed "${src}" > "${tmp}"
	echo \
	wkhtmltopdf --print-media-type --page-size A4 --image-dpi 600 --enable-local-file-access --disable-smart-shrinking "${@}" "${tmp}" "${pdf}"
	wkhtmltopdf --print-media-type --page-size A4 --image-dpi 600 --enable-local-file-access --disable-smart-shrinking "${@}" "${tmp}" "${pdf}"
	rm -f "${tmp}"
}

case "${1}" in
clothes.pdf)
	make_pdf clothes.html tmp.clothes.html clothes.pdf -O Landscape
	;;
dinoex*.pdf)
	name="${1%.*}"
	make_pdf "${name}.html" "tmp.${name}.html" "${name}.pdf"
	;;
break.pdf)
	make_pdf break.html tmp.break.html break.pdf --grayscale --footer-right "edited ${ddate} [page]/[topage]" --zoom 1.35 --margin-top 15 --margin-bottom 15 --margin-left 15 --margin-right 15
	;;
actors/*.pdf)
	source=`ls -t *scene*.wiki | head -1`
	seconds=`stat -f "%m" "${source}"`
	echo "${seconds}"
	ddate=`date -r "${seconds}" "+%Y-%m-%d %H:%M"`
	html="${1%.pdf}.html"
	actor="${1##*/}"
	actor="${actor%.pdf}"
	make_pdf "${html}" "tmp.${html##*/}" "${1}" --load-media-error-handling ignore --footer-right "${actor} edited ${ddate} [page]/[topage]" --zoom 1.35 --margin-top 15 --margin-bottom 15 --margin-left 15 --margin-right 15
	;;
all.pdf)
	source=`ls -t *scene*.wiki | head -1`
	seconds=`stat -f "%m" "${source}"`
	echo "${seconds}"
	ddate=`date -r "${seconds}" "+%Y-%m-%d %H:%M"`
	make_pdf all.html tmp.all.html all.pdf --load-media-error-handling ignore --grayscale --footer-right "edited ${ddate} [page]/[topage]" --zoom 1.35 --margin-top 15 --margin-bottom 15 --margin-left 15 --margin-right 15
	;;
*)
	${0} clothes.pdf
	${0} all.pdf
	;;
esac
exit 0
# eof
