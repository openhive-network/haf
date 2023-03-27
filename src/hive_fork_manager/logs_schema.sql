CREATE TABLE IF NOT EXISTS hive.log_properties(lvl INT);

SELECT pg_catalog.pg_extension_config_dump('hive.log_properties', '');

INSERT INTO hive.log_properties VALUES (100);
