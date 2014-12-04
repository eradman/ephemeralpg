#!/bin/sh
#
# 2014 Eric Radman <ericshane@eradman.com>

export TMPDIR=$(mktemp -td ephemeral_pg_tests.XXXXXX)
trap 'printf "$0: exit code $? on line $LINENO\n"; exit 1' ERR \
	2> /dev/null || exec bash $0 "$@"
trap 'rm -rf $TMPDIR' EXIT

printf "Running tests... "
printf "initdb "
uri=$(./ephemeral-pg initdb)
printf "start "
uri=$(./ephemeral-pg -t 2 start)
printf "psql "
[ "$(psql -At -c 'select 5' $uri)" -eq "5" ]
printf "stop "
sleep 5
$(psql -At -c 'select 5' $uri 2> /dev/null) && false
echo "verify"

echo "OK"
exit 0

