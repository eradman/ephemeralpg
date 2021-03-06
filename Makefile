PREFIX ?= /usr/local
MANPREFIX ?= ${PREFIX}/man
RELEASE = 3.2
TARGETS = pg_tmp getsocket ddl_compare

all: versioncheck ${TARGETS}

pg_tmp: pg_tmp.sh
	sed -e 's/$${release}/${RELEASE}/' $< > $@
	@chmod +x $@

ddl_compare: ddl_compare.sh
	sed -e 's/$${release}/${RELEASE}/' $< > $@
	@chmod +x $@

getsocket: getsocket.c
	${CC} ${CFLAGS} ${CPPFLAGS} ${EXTRA_SRC} $< -o $@ ${LDFLAGS}

test: ${TARGETS}
	@ruby ./test_getsocket.rb
	@ruby ./test_pg_tmp.rb
	@ruby ./test_ddl_compare.rb

selftest: pg_tmp
	@/bin/echo "Using `pg_ctl --version`"
	@./pg_tmp.sh selftest

install: ${TARGETS}
	@mkdir -p ${DESTDIR}${PREFIX}/bin
	@mkdir -p ${DESTDIR}${MANPREFIX}/man1
	install ddl_compare ${DESTDIR}${PREFIX}/bin/
	install getsocket ${DESTDIR}${PREFIX}/bin/
	install pg_tmp ${DESTDIR}${PREFIX}/bin/
	install -m 644 ddl_compare.1 ${DESTDIR}${MANPREFIX}/man1
	install -m 644 getsocket.1 ${DESTDIR}${MANPREFIX}/man1
	install -m 644 pg_tmp.1 ${DESTDIR}${MANPREFIX}/man1

uninstall:
	rm ${DESTDIR}${PREFIX}/bin/ddl_compare
	rm ${DESTDIR}${PREFIX}/bin/getsocket
	rm ${DESTDIR}${PREFIX}/bin/pg_tmp
	rm ${DESTDIR}${MANPREFIX}/man1/ddl_compare.1
	rm ${DESTDIR}${MANPREFIX}/man1/getsocket.1
	rm ${DESTDIR}${MANPREFIX}/man1/pg_tmp.1

versioncheck:
	@head -n3 NEWS | egrep -q "^= Next Release: ${RELEASE}|^== ${RELEASE}: "

clean:
	rm -f ${TARGETS}

.PHONY: all clean install uninstall test selftest versioncheck
