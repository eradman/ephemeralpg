PREFIX ?= /usr/local
MANPREFIX ?= ${PREFIX}/man

all: pg_tmp

pg_tmp: pg_tmp.sh
	ln -s pg_tmp.sh pg_tmp

regress: pg_tmp
	@/bin/echo "Using `pg_ctl --version`"
	@./pg_tmp.sh selftest

install:
	@mkdir -p ${DESTDIR}${PREFIX}/bin
	@mkdir -p ${DESTDIR}${MANPREFIX}/man1
	install pg_tmp ${DESTDIR}${PREFIX}/bin/pg_tmp
	install -m 644 pg_tmp.1 ${DESTDIR}${MANPREFIX}/man1

clean:
	rm pg_tmp
	rm -rf /tmp/pg_tmp-selftest*

.PHONY: clean distclean
