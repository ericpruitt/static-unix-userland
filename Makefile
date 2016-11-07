# Author: Eric Pruitt (https://www.codevat.com)
# License: 2-Clause BSD (http://opensource.org/licenses/BSD-2-Clause)
COMMON_PREFIX = $(PWD)/common
CFLAGS = -I$(COMMON_PREFIX)/include -O3 -s
LDFLAGS = -L$(COMMON_PREFIX)/lib -static

BASH_VERSION = 4.4
COREUTILS_VERSION = 8.25
FINDUTILS_VERSION = 4.6.0
GAWK_VERSION = 4.1.4
GMP_VERSION = 6.1.1
GREP_VERSION = 2.26
LESS_VERSION = 481
LIBEVENT_VERSION = 2.0.22-stable
MPFR_VERSION = 3.1.5
MUSL_VERSION = 1.1.15
NCURSES_VERSION = 6.0
READLINE_VERSION = 7.0
TMUX_VERSION = 2.3

BASH = bash-$(BASH_VERSION)
BASH_PATCHES = $(BASH)-patches
COREUTILS = coreutils-$(COREUTILS_VERSION)
FINDUTILS = findutils-$(FINDUTILS_VERSION)
GAWK = gawk-$(GAWK_VERSION)
GMP = gmp-$(GMP_VERSION)
GREP = grep-$(GREP_VERSION)
LESS = less-$(LESS_VERSION)
LIBEVENT = libevent-$(LIBEVENT_VERSION)
MPFR = mpfr-$(MPFR_VERSION)
MUSL = musl-$(MUSL_VERSION)
MUSL_CC = $(MUSL)/bin/musl-gcc
NCURSES = ncurses-$(NCURSES_VERSION)
READLINE = readline-$(READLINE_VERSION)
TMUX = tmux-src
VIM = vim-src

BASH_FOLDER = $(BASH)/.FOLDER
BASH_PATCHES_FOLDER = $(BASH_PATCHES)/.FOLDER
COREUTILS_FOLDER = $(COREUTILS)/.FOLDER
FINDUTILS_FOLDER = $(FINDUTILS)/.FOLDER
GAWK_FOLDER = $(GAWK)/.FOLDER
GMP_FOLDER = $(GMP)/.FOLDER
GREP_FOLDER = $(GREP)/.FOLDER
LESS_FOLDER = $(LESS)/.FOLDER
LIBEVENT_FOLDER = $(LIBEVENT)/.FOLDER
MPFR_FOLDER = $(MPFR)/.FOLDER
MUSL_FOLDER = $(MUSL)/.FOLDER
NCURSES_FOLDER = $(NCURSES)/.FOLDER
READLINE_FOLDER = $(READLINE)/.FOLDER
TMUX_FOLDER = $(TMUX)/.git
VIM_FOLDER = $(VIM)/.git

GMP_BUILT = common/$(GMP)
LIBEVENT_BUILT = common/$(LIBEVENT)
MPFR_BUILT = common/$(MPFR)
NCURSES_BUILT = common/$(NCURSES)
READLINE_BUILT = common/$(READLINE)

BASENAME = $(@F)
DIRNAME = $(@D)
PATCHES = $(PWD)/patches/$$(echo $@ | cut -d/ -f1)-*
TARGET = $$(echo "$@" | grep "^/" || echo "$(PWD)/$@")

GPG = gpg --homedir=gnupghome
MAN1 = $(MAN)/man1
OS = $$(echo $$(uname)-$$(uname -r) | tr A-Z a-z)
PUBRING = gnupghome/pubring.gpg
WGET = wget --no-use-server-timestamps -nv

BINARIES = \
	$(BASH)/bash \
	$(COREUTILS)/src/coreutils \
	$(FINDUTILS)/find/find \
	$(FINDUTILS)/xargs/xargs \
	$(GAWK)/gawk \
	$(GREP)/src/grep \
	$(LESS)/less \
	$(LESS)/lessecho \
	$(LESS)/lesskey \
	$(TMUX)/tmux \
	$(VIM)/src/vim \
	$(VIM)/src/xxd/xxd \

# These are targets listed in $(VIM)/Filelist that have their contents copied
# into $(BIN)/vimruntime. Among many other things, list includes files needed
# English spell / grammar checking, documentation and a mapping between RGB
# colors and English words.
VIM_RUNTIME_TARGETS = \
	LANG_GEN_BIN \
	RT_ALL \
	RT_DOS \
	RT_SCRIPTS \

# This is a list of individual paths in the runtime folder that are part of a
# target that has lots of other unwanted files.
VIM_RUNTIME_EXTRAS = \
	runtime/doc/tags \

# These features must be disabled to achieve full static linking with glibc.
# The "/**/" ensures that autoconf will not modify these lines since they will
# no longe match the regular expression it uses to find preprocessor
# definitions (/^[\t ]*#[\t ]*(define|undef)[\t ]+.../ in the files reviewed).
PRINT_AUTOCONF_UNDEFS = printf "/**/ \#undef HAVE_%s\n" \
	DLOPEN \
	GETADDRINFO \
	GETHOSTBYNAME \
	GETPROTOBYNUMBER \
	GETPWENT \
	GETPWNAM \
	GETPWUID \
	GETSERVBYNAME \
	GETSERVENT \
	GRP_H \

default: all

# These lines are used to ensure errexit and nounset are enabled for all
# commands with some BSD make variants (.SHELL) and GNU make (.SHELLFLAGS).
# When .POSIX is specified, compliant make implementations should at least set
# errexit even if other targets are ignored.
.POSIX:
.SHELL: path=/bin/sh errFlag=eu
.SHELLFLAGS = -euc

all:
	@if [ -n "$${CC:-}" ]; then \
		vars="CC=$$CC"; \
	elif [ -e $(MUSL_CC) ]; then \
		vars="CC=$$PWD/$(MUSL_CC)"; \
	elif uname | grep -i -q linux; then \
		for make in "$(MAKE)" gmake make; do \
			if $$make --version 2>&1 | grep -q "GNU Make"; then \
				$$make $(MUSL_CC); \
				vars="CC=$$PWD/$(MUSL_CC)"; \
				break; \
			fi; \
		done; \
		if ! [ -e $(MUSL_CC) ]; then \
			echo "Cannot compile musl without GNU Make." >&2; \
			exit 1; \
		fi; \
	fi; \
	if [ -z "$(PWD)" ]; then \
		vars="PWD=$$PWD $${vars:-}"; \
	fi; \
	if ! $(MAKE) -s -k $${vars:-} binaries; then \
		echo "Incomplete build:"; \
		$(MAKE) -s what; \
		exit 1; \
	fi; \
	echo; \
	echo "Sanity checks:"; \
	$(MAKE) -s sanity; \

sanity:
	@set +e; \
	for binary in $(BINARIES); do \
		printf "\055 %s" "$$binary: "; \
		case "$$binary" in \
		  */tmux) \
			"$$binary" -V >/dev/null; \
		  ;; \
		  */xxd) \
			echo | "$$binary" > /dev/null; \
		  ;; \
		  *) \
			"$$binary" --version >/dev/null; \
		  ;; \
		esac; \
		if [ "$$?" -eq 0 ]; then \
			echo "OK"; \
		else \
			exit_status=1; \
		fi; \
	done; \
	exit "$${exit_status:-0}"; \

deps:
	@if [ -e /etc/debian_version ]; then \
		echo "Detected Debian-based Linux: running apt-get..."; \
		apt-get install \
			automake \
			build-essential \
			pkg-config \
		; \
	elif [ "$(OS)" = openbsd-6.0 ]; then \
		echo "Detected OpenBSD 6.0: running pkg_add..."; \
		pkg_add \
			automake-1.15p0 \
			git \
			gnupg-1.4.19p2 \
			wget \
			xz \
		; \
		echo "Please ensure that AUTOCONF_VERSION and" \
		     "AUTOMAKE_VERSION are defined in the environment."; \
	else \
		echo "Unsupported OS: cannot install build dependencies" >&2; \
	fi; \

install what:
	@if [ $@ = install ]; then \
		if [ -z "$(BIN)" ]; then \
			echo "The BIN variable must be set." >&2; \
			exit 1; \
		fi; \
		test -z "$(MAN)" || mkdir -p "$(MAN1)"; \
		echo "Installation options:"; \
		echo BIN = "$(BIN)"; \
		echo MAN = "$(MAN)"; \
		echo; \
	fi; \
	for binary in $(BINARIES); do \
		if [ $@ = what ]; then \
			symbol=" "; \
			if [ -e "$$binary" ]; then \
				symbol="+"; \
			elif [ -e "$${binary%%/*}" ]; then \
				symbol="~"; \
			fi; \
			echo "$$symbol $$binary"; \
		elif [ -e "$$binary" ]; then \
			echo "- $$binary"; \
			something_exists=1; \
			$(MAKE) -S -s BIN="$(BIN)" "$(BIN)/$${binary##*/}"; \
		fi; \
	done; \
	if [ $@ = install ] && [ "$${something_exists:-0}" -eq 0 ]; then \
		echo "No binaries have been compiled." >&2; \
		exit 1; \
	fi; \

clean:
	@PATHS="$(PATHS)"; \
	for path in $${PATHS:-*/}; do \
		if [ -d "$$path" ] && [ "$$path" != patches/ ] && \
		  [ "$$path" != public-keys/ ] && \
		   [ "$$path" != musl-*/ ]; then \
			if [ -d "$$path"/.git ]; then \
				printf "\055 %s: " "$$path"; \
				cd "$$path"; \
				git reset --hard; \
				git clean -d -f -q -x; \
				cd ..; \
			else \
				echo "- $$path"; \
				rm -r -f "$$path"; \
			fi; \
		fi; \
	done; \
	rm -f *.log; \
	if [ -e $(MUSL).tar.gz ] && ! [ -s $(MUSL).tar.gz ]; then \
		printf "\055 %s\n" $(MUSL).tar.gz*; \
		rm "$(MUSL).tar.gz"*; \
	fi; \

purge:
	@if [ -n "$(PATHS)" ]; then \
		echo "PATHS is only valid for 'clean.'" >&2; \
		exit 1; \
	fi; \
	for path in */ *.tar.* *.sig *.asc *.log; do \
		if [ -e "$$path" ] && [ "$$path" != patches/ ] && \
		  [ "$$path" != public-keys/ ]; then \
			echo "- $$path"; \
			rm -r -f "$$path"; \
		fi; \
	done; \

binaries: bash coreutils findutils gawk grep less tmux vim

$(PUBRING):
	mkdir -m 700 $(DIRNAME).tmp; \
	for key in public-keys/*; do \
		test ! -h "$$key" || continue; \
		$(GPG) --homedir="$(DIRNAME).tmp" --import < "$$key"; \
	done; \
	mv $(DIRNAME).tmp $(DIRNAME); \

$(MUSL).tar.gz $(MUSL).tar.gz.asc:
	$(WGET) -nc https://www.musl-libc.org/releases/$@; \

$(MUSL_FOLDER): $(MUSL).tar.gz $(MUSL).tar.gz.asc $(PUBRING)
	$(GPG) --verify $(MUSL).tar.gz.asc; \
	tar -x -z -f $(MUSL).tar.gz; \
	(cat $(PATCHES) || echo) | (cd $(DIRNAME) && patch -p0); \
	touch $(TARGET); \

$(MUSL_CC): $(MUSL_FOLDER)
	cd $(MUSL); \
	test -e config.mak || ./configure \
		CFLAGS="$(CFLAGS)" \
		--disable-shared \
		--prefix="$$PWD" \
	; \
	$(MAKE) -S install; \

$(GMP).tar.xz $(GMP).tar.xz.sig:
	$(WGET) https://ftp.gnu.org/gnu/gmp/$@; \

$(GMP_FOLDER): $(GMP).tar.xz $(GMP).tar.xz.sig $(PUBRING)
	$(GPG) --verify $(GMP).tar.xz.sig; \
	xzcat $(GMP).tar.xz | tar -x -f -; \
	touch $(TARGET); \

$(GMP_BUILT): $(GMP_FOLDER)
	cd $(GMP); \
	./configure -C \
		CFLAGS="$(CFLAGS)" \
		--disable-shared \
		--enable-static \
		--prefix="$(COMMON_PREFIX)" \
	; \
	$(MAKE) -S install; \
	touch $(TARGET); \

$(LIBEVENT).tar.gz $(LIBEVENT).tar.gz.asc:
	$(WGET) -nc https://github.com/libevent/libevent/releases/download/release-$(LIBEVENT_VERSION)/$@; \

$(LIBEVENT_FOLDER): $(LIBEVENT).tar.gz $(LIBEVENT).tar.gz.asc $(PUBRING)
	$(GPG) --verify $(LIBEVENT).tar.gz.asc; \
	tar -x -z -f $(LIBEVENT).tar.gz; \
	(cat $(PATCHES) || echo) | (cd $(DIRNAME) && patch -p0); \
	touch $(TARGET); \

$(LIBEVENT_BUILT): $(LIBEVENT_FOLDER)
	cd $(LIBEVENT); \
	if ! [ -e Makefile ]; then \
		$(PRINT_AUTOCONF_UNDEFS) >> config.h.in; \
		./configure \
			CFLAGS="$(CFLAGS)" \
			LDFLAGS="$(LDFLAGS)" \
			--disable-dependency-tracking \
			--disable-openssl \
			--enable-shared \
			--prefix="$(COMMON_PREFIX)" \
		; \
	fi; \
	$(MAKE) -S install; \
	touch $(TARGET); \

$(MPFR).tar.xz $(MPFR).tar.xz.sig:
	$(WGET) https://ftp.gnu.org/gnu/mpfr/$@; \

$(MPFR_FOLDER): $(MPFR).tar.xz $(MPFR).tar.xz.sig $(PUBRING)
	$(GPG) --verify $(MPFR).tar.xz.sig; \
	xzcat $(MPFR).tar.xz | tar -x -f -; \
	touch $(TARGET); \

$(MPFR_BUILT): $(MPFR_FOLDER) $(GMP_BUILT)
	cd $(MPFR); \
	./configure -C \
		CFLAGS="$(CFLAGS)" \
		LDFLAGS="$(LDFLAGS)" \
		--disable-shared \
		--enable-static \
		--prefix="$(COMMON_PREFIX)" \
	; \
	$(MAKE) -S install; \
	touch $(TARGET); \

$(NCURSES).tar.gz $(NCURSES).tar.gz.sig:
	$(WGET) https://ftp.gnu.org/gnu/ncurses/$@; \

$(NCURSES_FOLDER): $(NCURSES).tar.gz $(NCURSES).tar.gz.sig $(PUBRING)
	$(GPG) --verify $(NCURSES).tar.gz.sig; \
	tar -x -z -f $(NCURSES).tar.gz; \
	(cat $(PATCHES) || echo) | (cd $(DIRNAME) && patch -p0); \
	touch $(TARGET); \

# In its default state, ncurses will fail to build when using BSD Make variants
# because they typically use one shell for each recipe by default which causes
# problems when recipes contain "cd" commands, and BSD Make variants may also
# treat "./$FILE" and "$FILE" as distinct targets. The sed script below edits
# some of the ncurses Makefiles to work around these issues. The sed script
# breaks relative path command execution, so the ncurses subdirectory is added
# to PATH so the leading "./" is no longer needed to run a command.
$(NCURSES_BUILT): $(NCURSES_FOLDER)
	cd $(NCURSES); \
	if ! [ -e Makefile ]; then \
		./configure -C \
			CFLAGS="$(CFLAGS)" \
			--disable-db-install \
			--enable-static \
			--prefix="$(COMMON_PREFIX)" \
			--with-default-terminfo-dir=/etc/terminfo:/lib/terminfo:/usr/share/terminfo \
			--without-ada \
			--without-cxx \
			--without-cxx-binding \
			--without-manpages \
			--without-progs \
			--without-tests \
		; \
	fi; \
	trap 'rm -f -- "$$file.tmp"' EXIT; \
	for file in Makefile ncurses/Makefile; do \
		sed -e 's/\(^	cd .*[^\\;]$$\)/\1 \&\& cd $$(PWD);/' \
		    -e 's/^\.\///' \
		    -e 's/\([ 	]\)\.\//\1/;' "$$file" > "$$file.tmp"; \
		mv "$$file.tmp" "$$file"; \
	done; \
	PATH="$$PATH:$$PWD/ncurses" $(MAKE) -S install; \
	touch $(TARGET); \

$(READLINE).tar.gz $(READLINE).tar.gz.sig:
	$(WGET) https://ftp.gnu.org/gnu/readline/$@; \

$(READLINE_FOLDER): $(READLINE).tar.gz $(READLINE).tar.gz.sig $(PUBRING)
	$(GPG) --verify $(READLINE).tar.gz.sig; \
	tar -x -z -f $(READLINE).tar.gz; \
	(cat $(PATCHES) || echo) | (cd $(DIRNAME) && patch -p0); \
	touch $(TARGET); \

$(READLINE_BUILT): $(READLINE_FOLDER)
	cd $(READLINE); \
	./configure -C \
		CFLAGS="$(CFLAGS)" \
		--disable-shared \
		--prefix="$(COMMON_PREFIX)" \
		--with-curses \
	; \
	$(MAKE) -S install; \
	touch $(TARGET); \

$(BASH).tar.gz $(BASH).tar.gz.sig:
	$(WGET) -nc https://ftp.gnu.org/gnu/bash/$@; \

# When looking for upstream patches, a wget exit status of 8 ("Server issued an
# error response.") is ignored under the assumption that the server failed to
# find the folder because the Bash release is new enough that no patches have
# been posted. The folder will still be created, but it will contain no files.
$(BASH_PATCHES_FOLDER): $(PUBRING)
	$(WGET) -P $(DIRNAME).tmp ftp://ftp.gnu.org/gnu/bash/$(BASH_PATCHES)/* || \
	  test $$? -eq 8; \
	mkdir -p $(DIRNAME).tmp; \
	trap 'rm -f "$$$$.log"' EXIT; \
	for patch in $(DIRNAME).tmp/*[0-9]; do \
		test "$${safe_glob:=0}" -eq 1 -o -e "$$patch" || break; \
		safe_glob=1; \
		if ! $(GPG) --verify "$$patch.sig" "$$patch" 2>$$$$.log; then \
			echo "$$patch:"; \
			sed "s/^gpg:/ /" "$$$$.log" >&2; \
			exit 1; \
		fi; \
	done; \
	mv $(DIRNAME).tmp $(DIRNAME); \
	touch $(TARGET); \

$(BASH_FOLDER): $(BASH).tar.gz $(BASH).tar.gz.sig $(BASH_PATCHES_FOLDER) $(PUBRING)
	$(GPG) --verify $(BASH).tar.gz.sig; \
	tar -x -z -f $(BASH).tar.gz; \
	cd $(DIRNAME); \
	for patch in $(PWD)/$(BASH_PATCHES)/*[0-9]; do \
		test ! -e "$$patch" || patch -p0 < "$$patch"; \
	done; \
	touch $(TARGET); \

$(BASH)/bash: $(BASH_FOLDER) $(READLINE_BUILT)
	cd $(BASH); \
	if ! [ -e Makefile ]; then \
		$(PRINT_AUTOCONF_UNDEFS) >> config.h.in; \
		./configure \
			CFLAGS="$(CFLAGS)" \
			LDFLAGS="$(LDFLAGS)" \
			--disable-nls \
			--with-installed-readline \
			--without-bash-malloc \
		; \
	fi; \
	$(MAKE) -S; \

bash: $(BASH)/bash

$(BIN)/bash: $(BASH)/bash
	if [ -n "$(MAN)" ]; then \
		cp -f "$(BASH)/doc/bash.1" "$(MAN1)"; \
		cp -f "$(BASH)/doc/rbash.1" "$(MAN1)"; \
	fi; \
	ln -s -f bash "$(BIN)/rbash"; \
	cp -f $? $(TARGET); \

$(COREUTILS).tar.xz $(COREUTILS).tar.xz.sig:
	$(WGET) -nc https://ftp.gnu.org/gnu/coreutils/$@; \

$(COREUTILS_FOLDER): $(COREUTILS).tar.xz $(COREUTILS).tar.xz.sig $(PUBRING)
	$(GPG) --verify $(COREUTILS).tar.xz.sig; \
	xzcat $(COREUTILS).tar.xz | tar -x -f -; \
	(cat $(PATCHES) || echo) | (cd $(DIRNAME) && patch -p0); \
	touch $(TARGET); \

$(COREUTILS)/src/coreutils: $(COREUTILS_FOLDER) $(GMP_BUILT)
	cd $(COREUTILS); \
	LDFLAGS="$(LDFLAGS)"; \
	test -e Makefile || ./configure \
		CFLAGS="$(CFLAGS) -std=c99" \
		LDFLAGS="$$LDFLAGS" \
		--disable-dependency-tracking \
		--disable-nls \
		--enable-no-install-program=stdbuf \
		--enable-single-binary=shebangs \
	; \
	grep -q "^_cc:" Makefile || echo '_cc:; @echo CC=$$(CC)' >> Makefile; \
	eval "$$($(MAKE) _cc | grep CC)"; \
	for flag in -no-pie -nopie; do \
		$$CC -dumpspecs | grep -q -e "$$flag" && break; \
		flag=""; \
	done; \
	$(MAKE) -S LDFLAGS="$$LDFLAGS $$flag"; \

coreutils: $(COREUTILS)/src/coreutils

$(BIN)/coreutils: $(COREUTILS)/src/coreutils
	$? --help | grep cp | (cd "$(BIN)" && xargs -n1 ln -s -f coreutils); \
	test ! -e "$(BIN)/ginstall" || ln -s -f ginstall "$(BIN)/install"; \
	if [ -n "$(MAN)" ]; then \
		programs=$$($? --help | grep cp); \
		pages=$$(printf "$(COREUTILS)/man/%s.1\n" $$programs \
		           | sed "s/ginstall/install/"); \
		pages=$$(ls -- $$pages 2>/dev/null || true); \
		cp -f -- $$pages "$(MAN1)"; \
		test -n "$${pages##*test*}" || ln -s -f test.1 "$(MAN1)/[.1"; \
		test -n "$${pages##*install*}" || \
		  ln -s -f install.1 "$(MAN1)/ginstall.1"; \
	fi; \
	cp -f $? $(TARGET); \

$(FINDUTILS).tar.gz $(FINDUTILS).tar.gz.sig:
	$(WGET) -nc https://ftp.gnu.org/gnu/findutils/$@; \

$(FINDUTILS_FOLDER): $(FINDUTILS).tar.gz $(FINDUTILS).tar.gz.sig $(PUBRING)
	$(GPG) --verify $(FINDUTILS).tar.gz.sig; \
	tar -x -z -f $(FINDUTILS).tar.gz; \
	touch $(TARGET); \

# When running make in select directories (as opposed to running it from the
# root to build all available targets), the build for find(1) may fail because
# a file is referenced with a leading "./" in a dependency list while the
# target has no such prefix. To work around this, an alias is added to
# find(1)'s Makefile template before running ./configure.
$(FINDUTILS)/Makefile: $(FINDUTILS_FOLDER)
	cd $(FINDUTILS); \
	echo "./libfindtools.a: libfindtools.a" >> find/Makefile.in; \
	./configure \
		CFLAGS="$(CFLAGS)" \
		LDFLAGS="$(LDFLAGS)" \
		LIBS="-lpthread" \
		--disable-dependency-tracking \
		--disable-nls \
	; \
	$(MAKE) -S -C gl; \
	$(MAKE) -S -C lib; \

$(FINDUTILS)/find/find $(FINDUTILS)/xargs/xargs: $(FINDUTILS)/Makefile
	$(MAKE) -S -C $(FINDUTILS)/$(BASENAME); \

findutils: $(FINDUTILS)/find/find $(FINDUTILS)/xargs/xargs

$(BIN)/find: $(FINDUTILS)/find/find
	test -z "$(MAN)" || \
	  cp -f $(FINDUTILS)/$(BASENAME)/$(BASENAME).1 "$(MAN1)"; \
	cp -f $? $(TARGET); \

$(BIN)/xargs: $(FINDUTILS)/xargs/xargs
	test -z "$(MAN)" || \
	  cp -f $(FINDUTILS)/$(BASENAME)/$(BASENAME).1 "$(MAN1)"; \
	cp -f $? $(TARGET); \

$(GAWK).tar.xz $(GAWK).tar.xz.sig:
	$(WGET) -nc https://ftp.gnu.org/gnu/gawk/$@; \

$(GAWK_FOLDER): $(GAWK).tar.xz $(GAWK).tar.xz.sig $(PUBRING)
	$(GPG) --verify $(GAWK).tar.xz.sig; \
	xzcat $(GAWK).tar.xz | tar -x -f -; \
	(cat $(PATCHES) || echo) | (cd $(DIRNAME) && patch -p0); \
	touch $(TARGET); \

$(GAWK)/gawk: $(GAWK_FOLDER) $(GMP_BUILT) $(MPFR_BUILT) $(NCURSES_BUILT) $(READLINE_BUILT)
	cd $(GAWK); \
	LDFLAGS="$(LDFLAGS)"; \
	if ! [ -e Makefile ]; then \
		./configure \
			CFLAGS="$(CFLAGS) -DREALLYMEAN" \
			LDFLAGS="$$LDFLAGS" \
			--disable-dependency-tracking \
			--disable-nls \
		; \
	fi; \
	grep -q "^_cc:" Makefile || echo '_cc:; @echo CC=$$(CC)' >> Makefile; \
	eval "$$($(MAKE) _cc | grep CC)"; \
	for flag in -no-pie -nopie; do \
		$$CC -dumpspecs | grep -q -e "$$flag" && break; \
		flag=""; \
	done; \
	$(MAKE) -S LDFLAGS="$$LDFLAGS $$flag"; \

gawk: $(GAWK)/gawk

$(BIN)/gawk: $(GAWK)/gawk
	if [ -n "$(MAN)" ]; then \
		ln -s -f gawk.1 "$(MAN1)/awk.1"; \
		cp -f $(GAWK)/doc/gawk.1 "$(MAN1)"; \
		cp -f $(GAWK)/doc/igawk.1 "$(MAN1)"; \
	fi; \
	cp -f -r $(GAWK)/awklib/eg/lib/ "$(BIN)/awklib"; \
	cp -f $(GAWK)/awklib/igawk "$(BIN)"; \
	ln -s -f gawk "$(BIN)/awk"; \
	cp -f $? $(TARGET); \

$(GREP).tar.xz $(GREP).tar.xz.sig:
	$(WGET) -nc https://ftp.gnu.org/gnu/grep/$@; \

$(GREP_FOLDER): $(GREP).tar.xz $(GREP).tar.xz.sig $(PUBRING)
	$(GPG) --verify $(GREP).tar.xz.sig; \
	xzcat $(GREP).tar.xz | tar -x -f -; \
	touch $(TARGET); \

$(GREP)/src/grep: $(GREP_FOLDER)
	cd $(GREP); \
	test -e Makefile || ./configure \
		CFLAGS="$(CFLAGS) -std=c99" \
		LDFLAGS="$(LDFLAGS)" \
		LIBS="-lpthread" \
		--disable-dependency-tracking \
		--disable-nls \
	; \
	$(MAKE) -S; \

grep: $(GREP)/src/grep

$(BIN)/grep: $(GREP)/src/grep
	if [ -n "$(MAN)" ]; then \
		cp -f $(GREP)/doc/grep.1 "$(MAN1)"; \
		ln -s -f grep.1 "$(MAN1)/egrep.1"; \
		ln -s -f grep.1 "$(MAN1)/fgrep.1"; \
	fi; \
	cp -f $(GREP)/src/egrep "$(BIN)"; \
	cp -f $(GREP)/src/fgrep "$(BIN)"; \
	cp -f $? $(TARGET); \

$(LESS).tar.gz $(LESS).tar.gz.sig:
	$(WGET) -nc http://www.greenwoodsoftware.com/less/$@; \

$(LESS_FOLDER): $(LESS).tar.gz $(LESS).tar.gz.sig $(PUBRING)
	$(GPG) --verify $(LESS).tar.gz.sig; \
	tar -x -z -f $(LESS).tar.gz; \
	touch $(TARGET); \

$(LESS)/less: $(LESS_FOLDER) $(NCURSES_BUILT)
	cd $(LESS); \
	test -e Makefile || ./configure \
		CFLAGS="$(CFLAGS)" \
		LDFLAGS="$(LDFLAGS)" \
	; \
	$(MAKE) -S; \

less: $(LESS)/less

$(BIN)/less: $(LESS)/less
	test -z "$(MAN)" || cp -f $(LESS)/less.nro "$(MAN1)/less.1"; \
	cp -f $? $(TARGET); \

$(BIN)/lessecho: $(LESS)/lessecho
	test -z "$(MAN)" || cp -f $(LESS)/lessecho.nro "$(MAN1)/lessecho.1"; \
	cp -f $? $(TARGET); \

$(BIN)/lesskey: $(LESS)/lesskey
	test -z "$(MAN)" || cp -f $(LESS)/lesskey.nro "$(MAN1)/lesskey.1"; \
	cp -f $? $(TARGET); \

$(TMUX_FOLDER):
	git clone -b $(TMUX_VERSION) https://github.com/tmux/tmux.git $(TMUX); \

$(TMUX)/tmux: $(LIBEVENT_BUILT) $(TMUX_FOLDER) $(NCURSES_BUILT)
	cd $(TMUX); \
	test -e configure || ./autogen.sh; \
	test -e Makefile || ./configure \
		CFLAGS="$(CFLAGS)" \
		LDFLAGS="$(LDFLAGS)" \
		LIBEVENT_CFLAGS="-I$(COMMON_PREFIX)/include" \
		LIBEVENT_LIBS="-levent" \
		LIBNCURSES_CFLAGS="-I$(COMMON_PREFIX)/include/ncurses" \
		LIBNCURSES_LIBS="-lncurses" \
		--disable-dependency-tracking \
		--enable-static \
		--sysconfdir=/etc \
	; \
	$(MAKE) -S; \

tmux: $(TMUX)/tmux

$(BIN)/tmux: $(TMUX)/tmux
	test -z "$(MAN)" || \
	  sed "s|@SYSCONFDIR@|/etc|g" $(TMUX)/tmux.1 > "$(MAN1)/tmux.1"; \
	cp -f $? $(TARGET); \

$(VIM_FOLDER):
	git clone https://github.com/vim/vim.git $(VIM); \

$(VIM)/src/auto/config.h: $(VIM_FOLDER) $(NCURSES_BUILT)
	cd $(VIM); \
	git checkout 04e2b4b^ src/mbyte.c; \
	git diff --quiet && (cat $(PATCHES) || echo) | patch -p0; \
	if git diff --quiet src/config.h.in; then \
		{ \
			$(PRINT_AUTOCONF_UNDEFS); \
			echo "#define FEAT_CONCEAL 1"; \
			echo "#define FEAT_TERMGUICOLORS 1"; \
		} >> src/config.h.in; \
	fi; \
	./configure \
		CFLAGS="$(CFLAGS)" \
		LDFLAGS="$(LDFLAGS)" \
		--disable-channel \
		--disable-gpm \
		--disable-gtktest \
		--disable-gui \
		--disable-netbeans \
		--disable-nls \
		--disable-selinux \
		--disable-smack \
		--disable-sysmouse \
		--disable-xsmp \
		--enable-multibyte \
		--prefix=/dev/null \
		--with-features=normal \
		--with-tlib=ncurses \
		--without-x \
	; \

$(VIM)/src/vim: $(VIM)/src/auto/config.h
	$(MAKE) -S -C $(DIRNAME) vim; \

# CFLAGS and LDFLAGS are defined here because Vim's build scripts do not update
# xxd's Makefile.
$(VIM)/src/xxd/xxd: $(VIM)/src/auto/config.h
	$(MAKE) -S -C $(DIRNAME) CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" xxd; \

vim: $(VIM)/src/xxd/xxd $(VIM)/src/vim

$(BIN)/vim: $(VIM)/src/vim
	test ! -e $(TMUX) || VIMRUNTIME="$(VIM)/runtime" \
	                     ./make-tmux-syntax.awk $(TMUX)/*.c > /dev/null; \
	test -e $(VIM)/vimruntime || ln -s -f runtime $(VIM)/vimruntime; \
	target_regex=$$(printf '/%s\\>/,/^$$/p;' $(VIM_RUNTIME_TARGETS)); \
	(cd $(VIM) && \
	ls $$(sed -n "$$target_regex" Filelist) $(VIM_RUNTIME_EXTRAS) \
	  2>/dev/null \
	  | sed -n "s/^runtime/vimruntime/p" \
	  | tar -c -f - -- $$(cat /dev/fd/0) \
	  | (cd $(PWD) && cd "$(BIN)" && tar -x -m -f -)); \
	if [ -n "$(MAN)" ]; then \
		ln -s -f vim.1 "$(MAN1)/vi.1"; \
		cp -f "$(VIM)/runtime/doc/vim.1" "$(MAN1)"; \
	fi; \
	ln -s -f vim "$(BIN)/vi"; \
	cp -f $? $(TARGET); \

$(BIN)/xxd: $(VIM)/src/xxd/xxd
	test -z "$(MAN)" || cp -f "$(VIM)/runtime/doc/xxd.1" "$(MAN1)"; \
	cp -f $? $(TARGET); \
