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
	echo "usage: $prog [-w expiration] [-t]"
	exit 2
}

trap 'printf "$0: exit code $? on line $LINENO\n"; exit 1' ERR \
	2> /dev/null || exec bash $0 "$@"
set +o posix

TIMEOUT=60
args=`getopt w:d:t $*`
[ $? -ne 0 ] && usage
set -- $args
while [ $# -gt 1 ]; do
	case "$1"
	in
		-w) TIMEOUT="$2"; shift; shift;;
		-d) TD="$2"; shift; shift;;
		-t) LISTENTO="127.0.0.1"; PGPORT="$(getsocket)"; shift;;
		--) shift; break;;
	esac
done
[ $# -ne 1 ] && usage

case $1 in
initdb)
	TD="$(mktemp -d ${SYSTMP:-/tmp}/ephemeralpg.XXXXXX)"
	# disabling fsync cuts time down by .5 seconds
	initdb --nosync -D $TD/db -E UNICODE -A trust > $TD/initdb.out
	mkdir $TD/socket
	# drop shared_buffers to allow numerous concurrent instances
	cat <<-EOF >> $TD/db/postgresql.conf
	    unix_socket_directories='$TD/socket'
	    listen_addresses=''
	    shared_buffers=12MB
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
	# disabling fsync cuts startup by .8 seconds
	[ -n "$PGPORT" ] && OPTS="-c listen_addresses='$LISTENTO' -c port=$PGPORT"
	pg_ctl -o "-F" -o "$OPTS" -s -D $TD/db -l $TD/log start
	# uri format documented at
	# http://www.postgresql.org/docs/9.4/static/libpq-connect.html
	PGHOST=$TD/socket
	if [ -n "$PGPORT" ]; then
		url="postgresql://$LISTENTO:$PGPORT/ephemeral"
	else
		url="postgresql://$(echo $PGHOST | sed 's:/:%2F:g')/ephemeral"
	fi
	# .4 seconds faster than start -w
	for n in 1 2 3 4 5; do
		sleep 0.1
		export PGPORT PGHOST
		createdb -E UNICODE ephemeral 2> $TD/log && break
	done
	[ $? != 0 ] && cat $TD/log
	echo -n "$url"
	# background initdb cuts startup by 3.8 seconds
	nohup $0 initdb > $TD/initdb.log &
	# shutting down takes nearly 1.3 seconds
	# return control so the calling process can use the connection
	nohup $0 -w $TIMEOUT -d $TD stop >> $TD/stop.log &
	;;
stop)
	sleep $TIMEOUT
	pg_ctl -D $TD/db stop -m immediate || true
	sleep 1
	rm -rf $TD
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

