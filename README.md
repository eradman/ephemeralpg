Ephemeral PostgreSQL
====================

Run tests on an isolated, temporary PostgreSQL database.

Temporary database created with `pg_tmp` have a limited shared memory footprint
and are automatically garbage-collected after the number of seconds specified by
the `-w` option (the default is 60).

`pg_tmp` reduces the wait time for a new database to less than one second by
initializing a database in the background that is used by subsequent
invocations.

Source Installation - BSD, Mac OS, and Linux
--------------------------------------------

    make install

Or to specify a specific installation location

    PREFIX=$HOME/local make install

Source Installation - Solaris
-----------------------------

    LDFLAGS='-lsocket -lnsl' make install

Man Page Examples for pg_tmp(1)
-------------------------------

Create a temporary database and run a query:

    uri=$(pg_tmp)
    psql $uri -f my.sql

Start a temporary server with a custom extension:

    uri=$(pg_tmp -o "-c shared_preload_libraries=$PWD/auth_hook")
    psql $uri -c "SELECT 1"

Man Page Examples for ddl_compare(1)
------------------------------------

Find the differences between a test instance and a schema definition

    pg_dump -s $test_url > test.sql
    ddl_compare -g roles.sql test.sql schema.sql

News
----

A release history as well as features in the upcoming release are covered in the
[NEWS](NEWS) file.
