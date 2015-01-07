ephemeralpg
===========

Quickly spin up a temporary Postgres test databases.

`pg_tmp` uses several tricks to reduce the wait time for a new database to less
than one second by initializing a database in the background that is recycled
during subsequent invocations. Additional optimizations include:

* Running with fsync=off
* Spin to discover when the database is available
* Limited shared memory footprint

The temporary database will be automatically garbage-collected after the number
of seconds specified by the `-t` option.

Example
-------

    #!/bin/sh
    uri=$(pg_tmp -t 30)
    echo "Using $uri"
    psql $uri -c 'select now()'

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

