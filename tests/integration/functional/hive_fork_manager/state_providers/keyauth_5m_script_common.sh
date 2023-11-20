
apply_keyauth()
{
SQL_COMMANDS="
CREATE SCHEMA IF NOT EXISTS mmm;
SELECT hive.app_create_context('mmm');
SELECT hive.app_state_provider_import('KEYAUTH', 'mmm');
SELECT hive.app_context_detach('mmm');

CREATE OR REPLACE FUNCTION mmm.main_test(
    IN _appContext VARCHAR,
    IN _from INT,
    IN _to INT,
    IN _step INT
)
RETURNS void
LANGUAGE 'plpgsql'

AS
\$\$
DECLARE
_last_block INT ;
BEGIN

  FOR b IN _from .. _to BY _step LOOP
    _last_block := b + _step - 1;

    IF _last_block > _to THEN --- in case the _step is larger than range length
      _last_block := _to;
    END IF;

    RAISE NOTICE 'Attempting to process a block range: <%s, %s>', b, _last_block;

    PERFORM hive.app_state_providers_update(b, _last_block, _appContext);

    RAISE NOTICE 'Block range: <%s, %s> processed successfully.', b, _last_block;

  END LOOP;

  RAISE NOTICE 'Leaving massive processing of block range: <%s, %s>...', _from, _to;
END
\$\$;
"
    psql -d haf_block_log -c "$SQL_COMMANDS"

}

drop_keyauth()
{
SQL_COMMANDS="
SELECT hive.app_state_provider_drop('KEYAUTH', 'mmm');
SELECT hive.app_remove_context('mmm');
"
    psql -d haf_block_log -c "$SQL_COMMANDS"

}

drop_keyauth
apply_keyauth
psql -d haf_block_log -c "SELECT mmm.main_test('mmm',1, 5000000,2000000);"
psql -d haf_block_log -c "\pset pager off" -c "select hive.public_key_to_string(key), * from  hive.mmm_keyauth_a join hive.mmm_keyauth_k on key_serial_id = key_id WHERE account_id = 14007 "