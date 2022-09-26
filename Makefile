INSTALL = /bin/install -c
DESTDIR =
PREFIX = /usr/local
BINDIR = /bin

all: install

install:
	$(INSTALL) -d $(DESTDIR)$(PREFIX)$(BINDIR)
	$(INSTALL) -m755 weather.sh $(DESTDIR)$(PREFIX)$(BINDIR)/weather.sh
	$(INSTALL) -m755 forecast.sh $(DESTDIR)$(PREFIX)$(BINDIR)/forecast.sh
