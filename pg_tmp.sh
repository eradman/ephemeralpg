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
	prog=$(basename $0)
	echo "usage: $prog [-w timeout] [-l logfile] [-t]"
	exit 2
}

trap 'printf "$0: exit code $? on line $LINENO\n"; exit 1' ERR \
	2> /dev/null || exec bash $0 "$@"
set +o posix

TIMEOUT=60
args=`getopt w:d:l:th $*`
[ $? -ne 0 ] && usage
set -- $args
while [ $# -gt 1 ]; do
	case "$1"
	in
		-w) TIMEOUT="$2"; shift; shift;;
		-d) TD="$2"; shift; shift;;
		-l) LOGFILE="$2"; shift; shift;;
		-t) LISTENTO="127.0.0.1"; PGPORT="$(getsocket)"; shift;;
		-h) usage;;
		--) shift; break;;
	esac
done
[ $# -ne 1 ] && usage

case $1 in
initdb)
	TD="$(mktemp -d ${SYSTMP:-/tmp}/ephemeralpg.XXXXXX)"
	initdb --nosync -D $TD/db -E UNICODE -A trust > $TD/initdb.out
	mkdir $TD/socket
	cat <<-EOF >> $TD/db/postgresql.conf
	    unix_socket_directories='$TD/socket'
	    listen_addresses=''
	    shared_buffers=12MB
	    log_min_duration_statement = 0
	    log_connections = on
	    log_disconnections = on
	EOF
	touch $TD/NEW
	echo $TD
	;;
start|--)
	# Find a temporary database directory owned by the current user
	for d in $(ls -d ${SYSTMP:-/tmp}/ephemeralpg.* 2> /dev/null); do
		test -O $d/NEW && { TD=$d; break; }
	done
	[ -z $TD ] && TD=$($0 initdb)
	rm $TD/NEW
	[ -n "$PGPORT" ] && OPTS="-c listen_addresses='$LISTENTO' -c port=$PGPORT"
	[ -n "$LOGFILE" ] || LOGFILE="$TD/db/postgres.log"
	pg_ctl -o "-F" -o "$OPTS" -s -D $TD/db -l $LOGFILE start
	PGHOST=$TD/socket
	export PGPORT PGHOST
	if [ -n "$PGPORT" ]; then
		url="postgresql://$LISTENTO:$PGPORT/ephemeral"
	else
		url="postgresql://$(echo $PGHOST | sed 's:/:%2F:g')/ephemeral"
	fi
	for n in 1 2 3 4 5; do
		sleep 0.1
		createdb -E UNICODE ephemeral > /dev/null 2>&1 && break
	done
	[ $? != 0 ] && cat $LOGFILE
	[ -t 1 ] && echo "$url" || echo -n "$url"
	nohup nice -n 19 $0 initdb > $TD/initdb.log &
	nohup nice -n 19 $0 -w $TIMEOUT -d $TD stop > $TD/stop.log &
	;;
stop)
	trap "rm -rf $TD" EXIT
	export PGHOST=$TD/socket
	until [ "$connections" == "1" ]; do
		sleep $TIMEOUT
		connections=$(psql ephemeral -At -c 'SELECT count(*) FROM pg_stat_activity;')
	done
	pg_ctl -D $TD/db stop
	sleep 2
	;;
selftest)
	export SYSTMP=$(mktemp -d /tmp/ephemeralpg-selftest.XXXXXX)
	trap "rm -rf $SYSTMP" EXIT
	printf "Running: "
	printf "initdb "; dir=$($0 initdb)
	printf "start " ; url=$($0 -w 3 start)
	printf "psql "  ; [ "$(psql -At -c 'select 5' $url)" == "5" ]
	printf "stop "  ; sleep 10
	printf "verify "; ! [ -d dir ]
	echo; echo "OK"
	;;
*)
	usage
	;;
esac

