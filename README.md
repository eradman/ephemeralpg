Ephemeral PostgreSQL
====================

Run tests on an isolated, temporary Postgres database.

Temporary database created with `pg_tmp` have a limited shared memory footprint
and are automatically garbage-collected after the number of seconds specified by
the `-w` option (the default is 60).

`pg_tmp` reduces the wait time for a new database to less than one second by
initializing a database in the background that is used by subsequent
invocations.

Examples
--------

*Shell*

    uri=$(pg_tmp)
    echo "Using $uri"
    psql $uri -c 'select now()'

*Python*

    import psycopg2
    from subprocess import check_output
    
    url = check_output(["pg_tmp"])
    with psycopg2.connect(url) as conn:
        with conn.cursor() as cursor:
            cursor.execute("select now();")
            print(cursor.fetchone()[0])


Installation
------------

    make install

Or to specify a specific installation location

    PREFIX=$HOME/local make install

Requirements
------------

* KSH or BASH
* PostgreSQL 9.3+

News
----

A release history as well as features in the upcoming release are covered in the
[NEWS][NEWS] file.

License
-------

Source is under and ISC-style license. See the [LICENSE][LICENSE] file for more
detailed information on the license used for compatibility libraries.

[NEWS]: http://www.bitbucket.org/eradman/ephemeralpg/src/default/NEWS
[LICENSE]: http://www.bitbucket.org/eradman/ephemeralpg/src/default/LICENSE

