RUBY ?= ruby
RUBOCOP ?= rubocop
PREFIX ?= /usr/local
MANPREFIX ?= ${PREFIX}/man
RELEASE = 3.3
TARGETS = pg_tmp getsocket

all: ${TARGETS}

pg_tmp: pg_tmp.sh
	sed -e 's/$${release}/${RELEASE}/' $< > $@
	@chmod +x $@

getsocket: getsocket.c
	${CC} ${CFLAGS} ${CPPFLAGS} ${EXTRA_SRC} ${LDFLAGS} $< -o $@

test: ${TARGETS}
	@${RUBY} ./test_getsocket.rb
	@${RUBY} ./test_pg_tmp.rb

selftest: pg_tmp
	@/bin/echo "Using `pg_ctl --version`"
	@./pg_tmp.sh selftest

install: ${TARGETS}
	@mkdir -p ${DESTDIR}${PREFIX}/bin
	@mkdir -p ${DESTDIR}${MANPREFIX}/man1
	install getsocket ${DESTDIR}${PREFIX}/bin/
	install pg_tmp ${DESTDIR}${PREFIX}/bin/
	install -m 644 getsocket.1 ${DESTDIR}${MANPREFIX}/man1
	install -m 644 pg_tmp.1 ${DESTDIR}${MANPREFIX}/man1

uninstall:
	rm ${DESTDIR}${PREFIX}/bin/getsocket
	rm ${DESTDIR}${PREFIX}/bin/pg_tmp
	rm ${DESTDIR}${MANPREFIX}/man1/getsocket.1
	rm ${DESTDIR}${MANPREFIX}/man1/pg_tmp.1

format:
	${RUBOCOP} -A

clean:
	rm -f ${TARGETS}

.PHONY: all clean install format uninstall test selftest
