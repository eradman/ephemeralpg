PREFIX ?= /usr/local
MANPREFIX ?= ${PREFIX}/man

all: getsocket

getsocket: getsocket.c
	${CC} ${CFLAGS} ${CPPFLAGS} ${EXTRA_SRC} getsocket.c -o $@ ${LDFLAGS}
	@chmod +x $@

regress: pg_tmp.sh
	@/bin/echo "Using `pg_ctl --version`"
	@./pg_tmp.sh selftest

install: getsocket
	@mkdir -p ${DESTDIR}${PREFIX}/bin
	@mkdir -p ${DESTDIR}${MANPREFIX}/man1
	install getsocket ${DESTDIR}${PREFIX}/bin/
	install pg_tmp.sh ${DESTDIR}${PREFIX}/bin/pg_tmp
	install -m 644 pg_tmp.1 ${DESTDIR}${MANPREFIX}/man1
	install -m 644 getsocket.1 ${DESTDIR}${MANPREFIX}/man1

uninstall:
	rm ${DESTDIR}${PREFIX}/bin/pg_tmp
	rm ${DESTDIR}${PREFIX}/bin/getsocket
	rm ${DESTDIR}${MANPREFIX}/man1/pg_tmp.1
	rm ${DESTDIR}${MANPREFIX}/man1/getsocket.1

clean:
	rm -f pg_tmp getsocket *.o

.PHONY: clean distclean
