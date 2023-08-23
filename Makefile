base_url = https://mirrors.edge.kernel.org/pub/linux/docs/man-pages/man-pages-posix/

BASE_URL = https://manp.gs/posix/

dirs = 0 1 3

MANDOC=mandoc
FLAGS=-Oman=../%S/%N,style=../style.css
FILTER=sed '/<pre>/,/<\/pre>/{/^<br\/>$$/d;}'
CMD=$(MANDOC) $(FLAGS) -Thtml "$<" | $(FILTER)
BUILD=$(CMD) > "$@"

REDIRECT = 1

ifeq ($(REDIRECT),1)
	FILTER=sed \
		-e "$$(printf '%s\n' '/<body>/,/<\/body>/c\' '<body>Redirecting&hellip;</body>')"\
		-e 's|<title>\(.*\)(0P)</title>|&\n  <meta http-equiv="refresh" content="0;url=https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/\1.html">|'\
		-e 's|<title>\(.*\)(1P)</title>|&\n  <meta http-equiv="refresh" content="0;url=https://pubs.opengroup.org/onlinepubs/9699919799/utilities/\1.html">|'\
		-e 's|<title>\(.*\)(3P)</title>|&\n  <meta http-equiv="refresh" content="0;url=https://pubs.opengroup.org/onlinepubs/9699919799/functions/\1.html">|'\
		-e '/http-equiv/y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/'
endif

template = <!doctype html>\n<html lang="en">\n\
\40<head>\n\
\40\40\40<meta charset="utf-8">\n\
\40\40\40<title>%s</title>\n\
\40\40\40<link rel="stylesheet" href="%s">\n\
\40</head>\n\
\40<body>\n\
\40\40\40<main>\n\
\40\40\40\40\40<h1>%s</h1>\n%s\n\
\40\40\40</main>\n\
\40</body>\n</html>\n

sitemap = <?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n%s\n</urlset>\n

desc = desc() { \
case $$1 in \
0) echo Headers ;; \
1) echo Utilities ;; \
3) echo Functions ;; \
esac; \
};

html = $(shell find man/man?? -type f | sed 's|^.*/\([^/]*\)\.\([0-9]\)p$$|\2/\1.html|')

all: man $(dirs) index.html
	$(MAKE) $(html)
	$(MAKE) sitemap.xml

$(dirs):
	mkdir -p "$@"

posix-man-pages.tar.gz:
	curl -o $@ "${base_url}$$(curl ${base_url} | \
		grep -o 'man-pages-posix-[^"]*.tar.gz' | tail -n1)"

man: posix-man-pages.tar.gz
	tar -xf posix-man-pages.tar.gz
	mv man-pages-posix-* man

man/whatis: man
	/usr/libexec/makewhatis man
	printf '%s\n' '1,$$s/(\([0-9]\)p)/(\1)/g' w q | ed -s man/whatis

clean:
	$(RM) -r index.html sitemap.xml $(dirs) man posix-man-pages.tar.gz


index.html: $(addsuffix /index.html,$(dirs))
	$(desc) \
	printf '$(template)' "POSIX Manpages" "style.css" "POSIX Manpages" "$$(\
		for s in $(dirs); do \
			printf '      <h2><a href="%s">%s &mdash; %s</a></h2>\n' \
				"$$s" "$$s" "$$(desc "$$s")"; \
		done; \
	)" > "$@"

sitemap.xml:
	printf '$(sitemap)' "$$(\
		(echo "" && printf '%s/\n' $(dirs)) | while read dir; do \
			printf "  <url><loc>%s%s</loc></url>\n" "$(BASE_URL)" "$$dir"; \
		done; \
		find $(dirs) -type f ! -name index.html | sort | awk '{ \
			sub(/\.[^.]+$$/, ""); \
			gsub(/ /, "%20"); \
			gsub(/\[/, "%5B"); \
			printf "  <url><loc>%s%s</loc></url>\n", "$(BASE_URL)", $$0; \
		}'; \
	)" > "$@"

%/index.html: man/whatis
	$(desc) \
	sect=$$(dirname "$@"); \
	printf '$(template)' "man$$sect &mdash; POSIX Manpages" "../style.css" \
		"<a href=\"../\">POSIX</a> &mdash; $$(desc "$$sect")" "$$(\
		printf '      <ul class="whatis">\n'; \
		sed -n -e ' \
			h; \
			s/ - /\n/; \
			s|.*\n||; \
			x; \
			s| - .*||; \
		' -e 't clear' -e :clear -e ' \
			s|('"$$sect"')|&|; \
		' -e 't link' -e b -e :link -e '\
			s|\([^, ][^(]*\)([0-9n][^)]*)|<a href="./\1">&</a>|g; \
			s|^|        <li>|; \
			G; \
			s|\n| \&mdash; |; \
			s|$$|</li>|p; \
		' man/whatis; \
		printf '      </ul>\n' \
	)" > "$@"

0/%.html: man/man0p/%.0p
	$(BUILD)

1/%.html: man/man1p/%.1p
	$(BUILD)

3/%.html: man/man3p/%.3p
	$(BUILD)
