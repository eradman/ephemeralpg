#!/bin/sh
#
# Copyright (c) 2019 Eric Radman <ericshane@eradman.com>
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

trap 'printf "$0: exit code $? on line $LINENO\n" >&2; exit 1' ERR \
	2> /dev/null || exec bash $0 "$@"
set +o posix

usage() {
	>&2 echo "release: ${release}"
	>&2 echo "usage: ddl_compare [-v] [-g globals.sql] [-n schema] a.sql b.sql"
	exit 1
}

download_ddlx() {
	>&2 echo "${DDLX} not found"
	echo "Install the schema extractor for PostgreSQL ${MAJOR} using"
	case `uname` in
		OpenBSD)
			echo "ftp -o $DDLX -n $DDLX_URL"
			;;
		Linux)
			echo "wget -q -O $DDLX $DDLX_URL"
			;;
		Darwin|*)
			echo "curl -f -s -o $DDLX $DDLX_URL"
			;;
	esac
	exit 1
}

MAJOR=$(pg_ctl -V | awk '{match($NF, "[0-9][0-9]"); print substr($NF, RSTART, RLENGTH)}')
[ -n "$MAJOR" ] || {
	>&2 echo "pg_ctl >= 10 not found"
	exit 1
}

DDLX_URL=${DDLX_URL:-"http://eradman.com/ephemeralpg/ddlx/ddlx${MAJOR}.sql"}
DDLX=${DDLX:-"/usr/share/misc/ddlx${MAJOR}.sql"}
[ -f $DDLX ] || download_ddlx

VERBOSE=""
SCHEMA="public"
GLOBALS=""

>/dev/null getopt vg:n: "$@" || usage
while [ $# -gt 2 ]; do
	case "$1" in
		-v) VERBOSE="true" ;;
		-g) GLOBALS=$2; shift ;;
		-n) SCHEMA=$2; shift ;;
	esac
	shift
done

[ $# == 2 ] || usage

for util in pg_tmp git; do
	p=$(which $util 2> /dev/null) || {
		echo "pg_compare: could not locate the '$util' utility" >&2
		exit 1
	}
done

for dir in a b
do
	[ -d $dir ] || mkdir $dir && rm -f $dir/*
	url=$(pg_tmp -w 20)
	[ -z "$VERBOSE" ] || echo $url
	psql_values="psql $url -q --no-psqlrc -At"
	psql_quiet="psql $url -q -v ON_ERROR_STOP=1"
	
	[ -z "$GLOBALS" ] || $psql_quiet -f $GLOBALS
	$psql_quiet -f $DDLX
	$psql_quiet -f $1
	
	ALL_TABLES="
	  SELECT table_name
	  FROM information_schema.tables
	  WHERE table_schema='$SCHEMA'
	  ORDER BY table_name
	"
	printf "\e[1m$1\e[0m\n"
	printf " \e[1m${dir}/\e[0m"
	for table in $($psql_values -c "$ALL_TABLES")
	do
		printf " $table"
		$psql_values -c "SELECT ddlx_script('$SCHEMA.$table'::regclass)" > $dir/$table
	done
	printf "\n"
	shift
done

echo "----"
files=$(find a b -name ".*" -prune -o -type f -exec basename {} \; | sort -u)
for f in $files
do
	touch {a,b}/$f
	for dir in a b
	do
		sed -i -r -e 's/OWNER TO ([_a-z0-9]+)/OWNER TO CURRENT_USER/g' $dir/$f
		sed -i -r -e 's/Owner: ([_a-z0-9]+)/Owner: CURRENT_USER/g' $dir/$f
	done
done
git diff --color --stat {a,b}/ | sed -e "s:{a => b}:${VISUALDIFF} {a,b}:"
