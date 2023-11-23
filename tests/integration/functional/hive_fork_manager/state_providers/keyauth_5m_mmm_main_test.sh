


# sudo /etc/init.d/postgresql status






if [ -z "$HAF_POSTGRES_URL" ]; then
    export HAF_POSTGRES_URL="haf_block_log"
fi


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
    psql -d $HAF_POSTGRES_URL -c "$SQL_COMMANDS"

}

drop_keyauth()
{
SQL_COMMANDS="
SELECT hive.app_state_provider_drop('KEYAUTH', 'mmm');
SELECT hive.app_remove_context('mmm');
"
    psql -d $HAF_POSTGRES_URL -c "$SQL_COMMANDS"

}

compare_actual_vs_expected()
{
  local ACTUAL_OUTPUT="$1"
  local EXPECTED_OUTPUT="$2"

  if [ "$ACTUAL_OUTPUT" == "$EXPECTED_OUTPUT" ]; then
      echo "Result is OK"
      echo 
  else
      echo "Result is NOT OK"
      echo "Expected Output:"
      echo "$EXPECTED_OUTPUT"
      echo 
      echo "Actual Output:"
      echo "$ACTUAL_OUTPUT"
      exit 1
  fi
}

check_keyauthauth_result()
{
  local account_name="$1"  
  local EXPECTED_OUTPUT="$2"


  local KEYAUTH_SQL_QUERY="
  select hive.public_key_to_string(key),
    account_id,
    key_kind,
    a.block_num,
    op_serial_id
  from hive.mmm_keyauth_a a
  join hive.mmm_keyauth_k on key_serial_id = key_id
  join hive.mmm_accounts_view av on account_id = av.id
  WHERE av.name = '$account_name'
  "

  local ACTUAL_OUTPUT=$(psql -d $HAF_POSTGRES_URL -c "$KEYAUTH_SQL_QUERY")

  compare_actual_vs_expected "$ACTUAL_OUTPUT" "$EXPECTED_OUTPUT"
}

check_accountauth_result()
{
  local account_name="$1"  
  local EXPECTED_OUTPUT="$2"

  local ACCOUNTAUTH_SQL_QUERY="
select 
    account_id,
    av.name,
    key_kind,
    account_auth_id,
    av2.name as supervisaccount,
    a.block_num,
    op_serial_id
  from hive.mmm_accountauth_a a
  
  join hive.mmm_accounts_view av on account_id = av.id
  join hive.mmm_accounts_view av2 on account_auth_id = av2.id
  WHERE av.name = '$account_name'
 "

  local ACTUAL_OUTPUT=$(psql -d $HAF_POSTGRES_URL -c "$ACCOUNTAUTH_SQL_QUERY")
  compare_actual_vs_expected "$ACTUAL_OUTPUT" "$EXPECTED_OUTPUT"

}

execute_sql()
{
  local RUN_FOR="$1"
  local account_name="$2"
  local EXPECTED_OUTPUT="$3"

  drop_keyauth
  apply_keyauth

  echo
  echo Running state provider against account "'$account_name'" for ${RUN_FOR}m
  echo
  psql -d $HAF_POSTGRES_URL -c "SELECT mmm.main_test('mmm',1, ${RUN_FOR}000000, 100000);" 2> accountauth_run_${RUN_FOR}m.log
}


run_keyauthauth_test()
{
  local RUN_FOR="$1"
  local account_name="$2"
  local EXPECTED_OUTPUT="$3"
  execute_sql "$RUN_FOR" "$account_name" "$EXPECTED_OUTPUT"
  check_keyauthauth_result "$account_name" "$EXPECTED_OUTPUT"
}

run_accountauth_test()
{
  local RUN_FOR="$1"
  local account_name="$2"
  local EXPECTED_OUTPUT="$3"
  execute_sql "$RUN_FOR" "$account_name" "$EXPECTED_OUTPUT"
  check_accountauth_result "$account_name" "$EXPECTED_OUTPUT"
}


RUN_FOR=3
account_name='streemian'
EXPECTED_OUTPUT=" account_id |   name    | key_kind | account_auth_id | supervisaccount | block_num | op_serial_id 
------------+-----------+----------+-----------------+-----------------+-----------+--------------
       9223 | streemian | OWNER    |            1489 | xeroc           |   1606743 |      2033587
(1 row)"
run_accountauth_test "$RUN_FOR" "$account_name" "$EXPECTED_OUTPUT"



RUN_FOR=3
account_name='gtg'
EXPECTED_OUTPUT="                 public_key_to_string                  | account_id | key_kind | block_num | op_serial_id 
-------------------------------------------------------+------------+----------+-----------+--------------
 STM5F9tCbND6zWPwksy1rEN24WjPiQWSU2vwGgegQVjAcYDe1zTWi |      14007 | OWNER    |   2885463 |      3762783
 STM6AzXNwWRzTWCVTgP4oKQEALTW8HmDuRq1avGWjHH23XBNhux6U |      14007 | ACTIVE   |   2885463 |      3762783
 STM69ZG1hx2rdU2hxQkkmX5MmYkHPCmdNeXg4r6CR7gvKUzYwWPPZ |      14007 | POSTING  |   2885463 |      3762783
 STM78Vaf41p9UUMMJvafLTjMurnnnuAiTqChiT5GBph7VDWahQRsz |      14007 | MEMO     |   2885463 |      3762783
(4 rows)"
run_keyauthauth_test "$RUN_FOR" "$account_name" "$EXPECTED_OUTPUT"


RUN_FOR=5
account_name='gtg'
EXPECTED_OUTPUT="                 public_key_to_string                  | account_id | key_kind | block_num | op_serial_id 
-------------------------------------------------------+------------+----------+-----------+--------------
 STM5RLQ1Jh8Kf56go3xpzoodg4vRsgCeWhANXoEXrYH7bLEwSVyjh |      14007 | OWNER    |   3399202 |      6688632
 STM4vuEE8F2xyJhwiNCnHxjUVLNXxdFXtVxgghBq5LVLt49zLKLRX |      14007 | ACTIVE   |   3399203 |      6688640
 STM5tp5hWbGLL1R3tMVsgYdYxLPyAQFdKoYFbT2hcWUmrU42p1MQC |      14007 | POSTING  |   3399203 |      6688640
 STM4uD3dfLvbz7Tkd7of4K9VYGnkgrY5BHSQt52vE52CBL5qBfKHN |      14007 | MEMO     |   3399203 |      6688640
(4 rows)"
run_keyauthauth_test  "$RUN_FOR" "$account_name" "$EXPECTED_OUTPUT"


RUN_FOR=5
account_name='streemian'
EXPECTED_OUTPUT=" account_id |   name    | key_kind | account_auth_id | supervisaccount | block_num | op_serial_id 
------------+-----------+----------+-----------------+-----------------+-----------+--------------
       9223 | streemian | OWNER    |            1489 | xeroc           |   3410418 |      6791007
       9223 | streemian | ACTIVE   |            1489 | xeroc           |   3410418 |      6791007
       9223 | streemian | POSTING  |            1489 | xeroc           |   3410418 |      6791007
(3 rows)"
run_accountauth_test "$RUN_FOR" "$account_name" "$EXPECTED_OUTPUT"


exit 0

BLOCKS=(2794855 2794856 2885317 2885318 2885325 2885326 2885369 2885370)
FROM=1
for NUM in "${BLOCKS[@]}"
do
    TO=$NUM
    echo "Running FROM: $FROM TO: $TO"
    psql -d $HAF_POSTGRES_URL -c "SELECT mmm.main_test('mmm',$FROM, $TO, 100000000);" 2> keyauth_run$TO.log
    print_result 'gtg'

    # Update FROM for the next iteration
    FROM=$((TO + 1))
done

