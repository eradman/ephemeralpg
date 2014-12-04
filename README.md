ephemeral-pg
============

Quickly spin up a temporary Postgres test databases.

`ephemeral-pg` uses several tricks to reduce the wait time for a new database to
less than one second by initializing a database in the background that is
recycled during subsequent invocations. Additional optimizations include:

* Running with fsync=off
* Spin to discover when the database is available
* Limited shared memory footprint

The temporary database will be automatically garbage-collected after the number
of seconds specified by the `-t` option.

Example:
--------

    #!/bin/sh
    uri=$(./ephemeral-pg -t 30 start)
    echo "Using $uri"
    psql $uri -c 'select now()'

Requirements
------------

* PostgreSQL 9.3+

