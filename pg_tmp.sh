#!/bin/sh
#
# Copyright (c) 2014 Eric Radman <ericshane@eradman.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

usage() {
	>&2 echo "release: ${release}"
	>&2 echo "usage: pg_tmp [-k] [-t [-p port]] [-w timeout] [-o extra-options] [-d datadir]"
	exit 1
}

trap 'printf "$0: exit code $? on line $LINENO\n" >&2; exit 1' ERR \
	2> /dev/null || exec bash $0 "$@"
trap '' HUP
set +o posix

USER_OPTS=""
>/dev/null getopt ktp:w:o:d: "$@" || usage
while [ $# -gt 0 ]; do
	case "$1" in
		-k) KEEP=$1 ;;
		-t) LISTENTO="127.0.0.1" ;;
		-p) PGPORT="$2"; shift ;;
		-w) TIMEOUT="$2"; shift ;;
		-o) USER_OPTS="$2"; shift ;;
		-d) TD="$2"; shift ;;
		 *) CMD=$1 ;;
	esac
	shift
done

initdb -V > /dev/null || exit 1
PGVER=$(pg_ctl -V | awk '{print $NF}')

[ -n "$LISTENTO" ] && [ -z "$PGPORT" ] && {
	PGPORT="$(getsocket)"
}

case ${CMD:-start} in
initdb)
	[ -z $TD ] || mkdir -p $TD
	[ -z $TD ] && TD="$(mktemp -d ${SYSTMP:-/tmp}/ephemeralpg.XXXXXX)"
	initdb --nosync -D $TD/$PGVER -E UNICODE -A trust > $TD/initdb.out
	cat <<-EOF >> $TD/$PGVER/postgresql.conf
	    unix_socket_directories = '$TD'
	    listen_addresses = ''
	    shared_buffers = 12MB
	    fsync = off
	    synchronous_commit = off
	    full_page_writes = off
	    log_min_duration_statement = 0
	    log_connections = on
	    log_disconnections = on
	EOF
	touch $TD/NEW
	echo $TD
	;;
start)
	# 1. Find a temporary database directory owned by the current user
	# 2. Create a new datadir if nothing was found
	# 3. Launch a background task to create a datadir for future invocations
	if [ -z $TD ]; then
		for d in $(ls -d ${SYSTMP:-/tmp}/ephemeralpg.*/$PGVER 2> /dev/null); do
			td=$(dirname "$d")
			test -O $td/NEW && rm $td/NEW 2> /dev/null && { TD=$td; break; }
		done
		[ -z $TD ] && { TD=$($0 initdb); rm $TD/NEW; }
		nice -n 19 $0 initdb > /dev/null &
	else
		[ -O $TD/$PGVER ] || TD=$($0 initdb -d $TD)
	fi
	if [ ${TIMEOUT:-1} -gt 0 ]; then
		nice -n 19 $0 $KEEP -w ${TIMEOUT:-60} -d $TD -p ${PGPORT:-5432} stop > $TD/stop.log 2>&1 &
	fi
	[ -n "$PGPORT" ] && OPTS="-c listen_addresses='*' -c port=$PGPORT"
	LOGFILE="$TD/$PGVER/postgres.log"
	pg_ctl -W -o "$OPTS $USER_OPTS" -s -D $TD/$PGVER -l $LOGFILE start
	PGHOST=$TD
	export PGPORT PGHOST
	if [ -n "$PGPORT" ]; then
		url="postgresql://$(whoami)@$LISTENTO:$PGPORT/test"
	else
		url="postgresql:///test?host=$(echo $PGHOST | sed 's:/:%2F:g')"
	fi
	for n in 1 2 3 4 5; do
		sleep 0.1
		createdb -E UNICODE test > /dev/null 2>&1 && break
	done
	[ $? != 0 ] && { >&2 tail $LOGFILE; exit 1; }
	[ -t 1 ] && echo "$url" || echo -n "$url"
	;;
stop)
	[ -O $TD/$PGVER/postgresql.conf ] || {
		>&2 echo "Please specify a PostgreSQL data directory using -d"
		exit 1
	}
	[ "$KEEP" == "" ] && trap "rm -r $TD" EXIT
	PGHOST=$TD
	export PGHOST PGPORT
	q="SELECT count(*) FROM pg_stat_activity WHERE datname='test';"
	until [ "${count:-2}" -lt "2" ]; do
		sleep ${TIMEOUT:-5}
		count=$(psql test --no-psqlrc -At -c "$q" || echo 0)
	done
	pg_ctl -W -D $TD/$PGVER stop
	sleep 1
	;;
selftest)
	export SYSTMP=$(mktemp -d /tmp/ephemeralpg-selftest.XXXXXX)
	trap "rm -r $SYSTMP" EXIT
	printf "Running: "
	printf "initdb "; dir=$($0 initdb)
	printf "start " ; url=$($0 -w 3 -o '-c log_temp_files=100' start)
	printf "psql "  ; [ "$(psql --no-psqlrc -At -c 'select 5' $url)" == "5" ]
	printf "stop "  ; sleep 10
	printf "verify "; ! [ -d dir ]
	echo; echo "OK"
	;;
*)
	usage
	;;
esac

