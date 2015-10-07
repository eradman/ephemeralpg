PREFIX ?= /usr/local
MANPREFIX ?= ${PREFIX}/man
RELEASE = 1.3

all: versioncheck pg_tmp getsocket

pg_tmp: pg_tmp.sh
	sed -e 's/$${release}/${RELEASE}/' $< > $@
	@chmod +x $@

getsocket: getsocket.c
	${CC} ${CFLAGS} ${CPPFLAGS} ${EXTRA_SRC} $< -o $@ ${LDFLAGS}

regress: pg_tmp.sh
	@/bin/echo "Using `pg_ctl --version`"
	@./pg_tmp.sh selftest

install: getsocket
	@mkdir -p ${DESTDIR}${PREFIX}/bin
	@mkdir -p ${DESTDIR}${MANPREFIX}/man1
	install getsocket ${DESTDIR}${PREFIX}/bin/
	install pg_tmp ${DESTDIR}${PREFIX}/bin/
	install -m 644 pg_tmp.1 ${DESTDIR}${MANPREFIX}/man1
	install -m 644 getsocket.1 ${DESTDIR}${MANPREFIX}/man1

uninstall:
	rm ${DESTDIR}${PREFIX}/bin/pg_tmp
	rm ${DESTDIR}${PREFIX}/bin/getsocket
	rm ${DESTDIR}${MANPREFIX}/man1/pg_tmp.1
	rm ${DESTDIR}${MANPREFIX}/man1/getsocket.1

versioncheck:
	@head -n3 NEWS | egrep -q "^= Next Release: ${RELEASE}|^== ${RELEASE}: "

clean:
	rm -f pg_tmp getsocket *.o

.PHONY: all clean install uninstall regress versioncheck
