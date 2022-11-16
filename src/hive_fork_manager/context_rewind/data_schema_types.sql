DROP TYPE IF EXISTS hive.trigger_operation CASCADE;
CREATE TYPE hive.trigger_operation AS ENUM( 'INSERT', 'DELETE', 'UPDATE' );
