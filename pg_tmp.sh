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
	echo "usage: $prog -t expiration"
	exit 2
}

trap 'printf "$0: exit code $? on line $LINENO\n"; exit 1' ERR \
	2> /dev/null || exec bash $0 "$@"
set +o posix

args=`getopt t:d: $*`
[ $? -ne 0 ] && usage
set -- $args
while [ $# -gt 1 ]; do
	case "$1"
	in
		-t) TIMEOUT="$2"; shift; shift;;
		-d) TD="$2"; shift; shift;;
		--) shift; break;;
	esac
done
[ $# -ne 1 ] && usage

case $1 in
initdb)
	TD="$(mktemp -d ${SYSTMP:-/tmp}/pg_tmp.XXXXXX)"
	# disabling fsync cuts time down by .5 seconds
	initdb --nosync -D $TD/db -E UNICODE -A trust > $TD/initdb.out
	mkdir $TD/socket
	cat <<-EOF >> $TD/db/postgresql.conf
	unix_socket_directories='$TD/socket'
	external_pid_file='$TD/postmaster.pid'
	EOF
	touch $TD/NEW
	echo $TD
	;;
start|--)
	# Find a temporary database directory owned by the current user
	for d in $(ls -d ${SYSTMP:-/tmp}/pg_tmp.* 2> /dev/null); do
		test -O $d/NEW && { TD=$d; break; }
	done
	[ -z $TD ] && TD=$($0 initdb)
	rm $TD/NEW
	# disabling fsync cuts startup by .8 seconds
	# drop shared_buffers to allow numerous concurrent instances
	pg_ctl -s -o \
	    "-c fsync=off -c listen_addresses='' -c shared_buffers=12MB" \
	    -D $TD/db -l $TD/log start
	# .4 seconds faster than start -w
	for n in 1 2 3 4 5; do
		sleep 0.1
		PGHOST=$TD/socket createdb -E UNICODE ephemeral 2> /dev/null && break
	done
	# uri format documented at
	# http://www.postgresql.org/docs/9.4/static/libpq-connect.html
	url="postgresql://$(echo $TD/socket | sed 's:/:%2F:g')/ephemeral"
	echo -n "$url"
	# background initdb cuts startup by 3.8 seconds
	nohup $0 initdb > /dev/null &
	# shutting down takes nearly 1.3 seconds
	# return control so the calling process can use the connection
	nohup $0 -t $TIMEOUT -d $TD stop > /dev/null &
	;;
stop)
	sleep $TIMEOUT
	pg_ctl -D $TD/db stop -m immediate || true
	rm -rf $TD
	;;
selftest)
	export SYSTMP=$(mktemp -d /tmp/pg_tmp-selftest.XXXXXX)
	trap "rm -rf $SYSTMP" EXIT
	printf "Running: "
	printf "initdb "; dir=$($0 initdb)
	printf "start " ; url=$($0 -t 3 start)
	printf "psql "  ; [ "$(psql -At -c 'select 5' $url)" == "5" ]
	printf "stop "  ; sleep 10
	printf "verify "; ! [ -d dir ]
	echo; echo "OK"
	;;
*)
	usage
	;;
esac

