SUBDIRS = $(dir $(wildcard */build.sh))
TARS = $(addsuffix .tar, $(SUBDIRS:/=))

.PHONY: all
all: $(TARS)

%.tar: FORCE
	tar --dereference -cf $@ $(@:.tar=/)

FORCE:
