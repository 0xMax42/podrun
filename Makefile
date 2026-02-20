.PHONY: install uninstall clean build

PREFIX  ?= /usr
BINDIR  := $(PREFIX)/bin
DESTDIR ?=

install:
	install -d $(DESTDIR)$(BINDIR)
	install -m 0755 podrun.sh $(DESTDIR)$(BINDIR)/podrun
	install -d $(DESTDIR)$(PREFIX)/share/doc/podrun
	install -m 0644 README.md $(DESTDIR)$(PREFIX)/share/doc/podrun/README.md

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/podrun
	rm -f $(DESTDIR)$(PREFIX)/share/doc/podrun/README.md

clean:
	:

build:
	: