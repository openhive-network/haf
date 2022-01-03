# Scripts which allow to use pg_dump and pg_restore with hive_fork manager

Tables which are parts of a postgres extension are not dumped by pg_dump, to solve this problem
they must be removed from the extension, so the procedure to dump the dabase looks as below:
1. execute [drop_from_extension.sql](./drop_from_extension.sql) on the db, to drop dables from the extension
2. issue pg_dump on the db
3. execute [add_to_extension.sql](./add_to_extension.sql) on the db, to restore its valid state 

Restore procedure:
1. issue pg_restore with --disable_triggers
2. execute [add_to_extension.sql](./add_to_extension.sql) on the db, to restore its valid state