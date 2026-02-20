.PHONY: install uninstall clean build

PREFIX  ?= /usr
BINDIR  := $(PREFIX)/bin
DESTDIR ?=

install:
	install -d $(DESTDIR)$(BINDIR)
	install -m 0755 podrun.sh $(DESTDIR)$(BINDIR)/podrun

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/podrun

clean:
	:

build:
	: