.POSIX:
include rsxiv.mk

BOLD   = \033[1m
CYAN   = \033[1;36m
GREEN  = \033[1;32m
RESET  = \033[0m

inc_fonts_0 =
inc_fonts_1 = -I/usr/include/freetype2 -I$(PREFIX)/include/freetype2
lib_fonts_0 =
lib_fonts_1 = -lXft -lfontconfig
lib_exif_0 =
lib_exif_1 = -lexif

rsxiv_cppflags = -D_XOPEN_SOURCE=700 \
  -DHAVE_LIBEXIF=$(HAVE_LIBEXIF) -DHAVE_LIBFONTS=$(HAVE_LIBFONTS) \
  -DHAVE_INOTIFY=$(HAVE_INOTIFY) $(inc_fonts_$(HAVE_LIBFONTS)) \
  $(CPPFLAGS) -MMD -MP

rsxiv_ldlibs = -lImlib2 -lX11 \
  $(lib_exif_$(HAVE_LIBEXIF)) $(lib_fonts_$(HAVE_LIBFONTS)) \
  $(LDLIBS) -lm

objs = autoreload.o commands.o image.o main.o options.o \
  thumbs.o util.o window.o wallpaper.o
deps = $(objs:.o=.d)

.SUFFIXES:
.SUFFIXES: .c .o

define compile_c
	@t0=$$(date +%s%N); \
	out=$$($(CC) $(CFLAGS) $(rsxiv_cppflags) -c -o $@ $< 2>&1); rc=$$?; \
	t1=$$(date +%s%N); ms=$$(( (t1 - t0) / 1000000 )); \
	( \
		flock -w 10 200; \
		if [ $$rc -eq 0 ]; then \
			printf "$(GREEN)%-8s$(RESET) $(BOLD)%-15s$(RESET) %-20s\t$(CYAN)%dms$(RESET)\n" \
				"$(CC)" "$<" "$@" "$$ms"; \
		else \
			printf "$(GREEN)%-8s$(RESET) $(BOLD)%-15s$(RESET) FAILED\t$(CYAN)%dms$(RESET)\n" \
				"$(CC)" "$<" "$$ms"; \
			printf "%s\n" "$$out"; \
		fi \
	) 200>/tmp/.rsxiv-build.lock; \
	exit $$rc
endef

define link_bin
	@t=$$(date +%s%N); \
	printf " $(GREEN)link$(RESET)%-4s$(BOLD)$@$(RESET)%-35s"; \
	$(CC) $(LDFLAGS) -o $@ $(objs) $(rsxiv_ldlibs); \
	rc=$$?; \
	ms=$$(( ($$(date +%s%N) - t) / 1000000 )); \
	[ $$rc -eq 0 ] && printf "$(CYAN)%dms$(RESET)\n" $$ms || exit $$rc
endef

.PHONY: all bench clean distclean install install-all install-desktop \
        install-icon uninstall uninstall-icon dump_cppflags

all: rsxiv

rsxiv: $(objs)
	$(call link_bin)

.c.o:
	$(call compile_c)

$(objs): Makefile rsxiv.mk rsxiv.h config.h commands.h
options.o: version.h optparse.h
window.o: icon/data.h utf8.h

-include $(deps)

config.h:
	@echo "GEN $@"
	@cp config.def.h $@

version.h: rsxiv.mk .git/index
	@v="$$(git describe 2>/dev/null || true)"; \
	payload=$$(printf '#define VERSION "%s"' "$${v:-$(VERSION)}"); \
	if ! printf '%s\n' "$$payload" | cmp -s - "$@" 2>/dev/null; then \
		echo "GEN $@"; \
		printf '%s\n' "$$payload" >"$@"; \
	fi

.git/index:

bench:
	@t=$$(date +%s%N); \
	$(MAKE) --no-print-directory rsxiv; \
	rc=$$?; \
	ms=$$(( ($$(date +%s%N) - t) / 1000000 )); \
	if [ $$rc -eq 0 ]; then \
		printf "\n$(BOLD)Build finished in$(RESET) $(CYAN)%dms$(RESET)\n" $$ms; \
	else \
		exit $$rc; \
	fi

dump_cppflags:
	@echo $(rsxiv_cppflags)

clean:
	rm -f *.o *.d rsxiv version.h
	@printf "$(GREEN)CLEANED$(RESET)\n"

distclean: clean
	rm -f config.h

install-all: install install-desktop install-icon

install-desktop:
	@echo "INSTALL rsxiv.desktop"
	mkdir -p $(DESTDIR)$(PREFIX)/share/applications
	cp etc/rsxiv.desktop $(DESTDIR)$(PREFIX)/share/applications

install-icon:
	@echo "INSTALL icon"
	for f in $(ICONS); do \
		dir="$(DESTDIR)$(PREFIX)/share/icons/hicolor/$${f%.png}/apps"; \
		mkdir -p "$$dir"; \
		cp "icon/$$f" "$$dir/rsxiv.png"; \
		chmod 644 "$$dir/rsxiv.png"; \
	done

uninstall-icon:
	@echo "REMOVE icon"
	for f in $(ICONS); do \
		dir="$(DESTDIR)$(PREFIX)/share/icons/hicolor/$${f%.png}/apps"; \
		rm -f "$$dir/rsxiv.png"; \
	done

install: all
	@echo "INSTALL bin/rsxiv"
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp rsxiv $(DESTDIR)$(PREFIX)/bin/
	chmod 755 $(DESTDIR)$(PREFIX)/bin/rsxiv
	@echo "INSTALL rsxiv.1"
	mkdir -p $(DESTDIR)$(MANPREFIX)/man1
	sed "s!EGPREFIX!$(EGPREFIX)!g; s!PREFIX!$(PREFIX)!g; s!VERSION!$(VERSION)!g" \
		etc/rsxiv.1 >$(DESTDIR)$(MANPREFIX)/man1/rsxiv.1
	chmod 644 $(DESTDIR)$(MANPREFIX)/man1/rsxiv.1
	@echo "INSTALL share/rsxiv/"
	mkdir -p $(DESTDIR)$(EGPREFIX)
	cp etc/examples/* $(DESTDIR)$(EGPREFIX)
	chmod 755 $(DESTDIR)$(EGPREFIX)/*

uninstall: uninstall-icon
	@echo "REMOVE bin/rsxiv"
	rm -f $(DESTDIR)$(PREFIX)/bin/rsxiv
	@echo "REMOVE rsxiv.1"
	rm -f $(DESTDIR)$(MANPREFIX)/man1/rsxiv.1
	@echo "REMOVE rsxiv.desktop"
	rm -f $(DESTDIR)$(PREFIX)/share/applications/rsxiv.desktop
	@echo "REMOVE share/rsxiv/"
	rm -rf $(DESTDIR)$(EGPREFIX)
