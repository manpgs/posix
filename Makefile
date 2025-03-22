BASE_URL = https://manp.gs/posix/

base_url = https://pubs.opengroup.org/onlinepubs/9799919799

dirs = 1 3

MANDOC=mandoc
FLAGS=-Oman=../%S/%N,style=../style.css
FILTER=sed '/<pre>/,/<\/pre>/{/^<br\/>$$/d;}'
CMD=$(MANDOC) $(FLAGS) -Thtml "$<" | $(FILTER)
BUILD=$(CMD) > "$@"

REDIRECT = 1

ifeq ($(REDIRECT),1)
	FILTER=sed \
		-e "$$(printf '%s\n' '/<body>/,/<\/body>/c\' '<body>Redirecting&hellip;</body>')"\
		-e '/<title>.*(1P)<\/title>/{ s|<title>.*</title>|<title>$*(1)</title>|; h; s|.*|  <meta http-equiv="refresh" content="0;url=$(base_url)/utilities/$*.html">|; H; x; }' \
		-e '/<title>.*\.H(3P)<\/title>/{ s|<title>.*</title>|<title>$*(3)</title>|; h; s|.*|  <meta http-equiv="refresh" content="0;url=$(base_url)/basedefs/$*.html">|; H; x; }' \
		-e '/<title>.*(3P)<\/title>/{ s|<title>.*</title>|<title>$*(3)</title>|; h; s|.*|  <meta http-equiv="refresh" content="0;url=$(base_url)/functions/$*.html">|; H; x; }'
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
1) echo Utilities ;; \
3) echo "Headers & Functions" ;; \
esac; \
};

html = $(shell find man-posix/man?? -type f \
	! -name *.7p \
	! -name intro.1p \
	! -name shell.1p \
	! -name intro.3p \
	! -name info.3p \
	| sed 's|^.*/\([^/]*\)\.\([0-9]\)p$$|\2/\1.html|')

all: $(dirs) index.html
	cd man-posix && $(MAKE)
	$(MAKE) $(html)
	$(MAKE) sitemap.xml

$(dirs):
	mkdir -p "$@"

whatis:
	/usr/libexec/makewhatis man-posix
	sed -e 's/(\([0-9]\)p)/(\1)/g' -e "s/\[aq]/'/g" man-posix/whatis > whatis
	rm man-posix/whatis

clean:
	$(RM) -r index.html sitemap.xml whatis $(dirs)

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

%/index.html: whatis
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
			s|\(<a href="\./[^"]*\)/|\1_|g; \
			s|^|        <li>|; \
			G; \
			s|\n| \&mdash; |; \
			s|$$|</li>|p; \
		' whatis; \
		printf '      </ul>\n' \
	)" > "$@"

1/%.html: man-posix/man1p/%.1p
	$(BUILD)

3/%.html: man-posix/man3p/%.3p
	$(BUILD)
