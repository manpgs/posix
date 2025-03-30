AWK = awk
FIND = find
MAKEWHATIS = /usr/libexec/makewhatis
MANDOC = mandoc
MKDIR_P = mkdir -p
SED = sed

BASE_URL = https://manp.gs/posix/
REDIRECT = 1

base_url = https://pubs.opengroup.org/onlinepubs/9799919799

dirs = 1 3

filter = $(SED) '/<pre>/,/<\/pre>/{/^<br\/>$$/d;}'

ifeq ($(REDIRECT),1)
	filter = $(SED) \
		-e "$$(printf '%s\n' '/<body>/,/<\/body>/c\' '<body>Redirecting&hellip;</body>')"\
		-e '/<title>.*(1P)<\/title>/{ s|<title>.*</title>|<title>$*(1)</title>|; h; s|.*|  <meta http-equiv="refresh" content="0;url=$(base_url)/utilities/$*.html">|; H; g; }' \
		-e '/<title>.*\.H(3P)<\/title>/{ s|<title>.*</title>|<title>$*(3)</title>|; h; s|.*|  <meta http-equiv="refresh" content="0;url=$(base_url)/basedefs/$*.html">|; H; g; }' \
		-e '/<title>.*(3P)<\/title>/{ s|<title>.*</title>|<title>$*(3)</title>|; h; s|.*|  <meta http-equiv="refresh" content="0;url=$(base_url)/functions/$*.html">|; H; g; }'
endif

man2html = $(MANDOC) -Oman=../%S/%N,style=../style.css -Thtml "$<" | $(filter)

convert = $(man2html) > "$@"

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

html = $(shell $(FIND) man-posix/man?? -type f \
	! -name *.7p \
	! -name intro.1p \
	! -name shell.1p \
	! -name intro.3p \
	! -name info.3p \
	| $(SED) 's|^.*/\([^/]*\)\.\([0-9]\)p$$|\2/\1.html|')

all: $(dirs) index.html
	cd man-posix && $(MAKE)
	$(MAKE) $(html)
	$(MAKE) sitemap.xml

$(dirs):
	$(MKDIR_P) "$@"

whatis:
	$(MAKEWHATIS) man-posix
	$(SED) -e 's/(\([0-9]\)p)/(\1)/g' -e "s/\[aq]/'/g" man-posix/whatis > whatis
	$(RM) man-posix/whatis

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
		$(FIND) $(dirs) -type f ! -name index.html | sort | $(AWK) '{ \
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
		$(SED) -n -e ' \
			h; \
			s/ - /\n/; \
			s/.*\n//; \
			x; \
			s/ - .*//; \
		' -e "/($$sect)/!b" -e ' \
			s|\([^, ][^(]*\)([0-9n][^)]*)|<a href="./\1">&</a>|g; \
			s|\(<a href="\./[^"]*\)/|\1_|g; \
			s/^/        <li>/; \
			G; \
			s/\n/ \&mdash; /; \
			s|$$|</li>|p; \
		' whatis; \
		printf '      </ul>\n' \
	)" > "$@"

1/%.html: man-posix/man1p/%.1p
	$(convert)

3/%.html: man-posix/man3p/%.3p
	$(convert)
