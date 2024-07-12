CREATE TYPE hive.trigger_operation AS ENUM( 'INSERT', 'DELETE', 'UPDATE' );

CREATE DOMAIN hive.ctext AS TEXT COLLATE "C";
