set -x 

echo mtlk

pwd
ls -ld /var/run/postgresql

docker ps | true


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

print_result()
{
  psql -d $HAF_POSTGRES_URL -c "select hive.public_key_to_string(key), account_id, key_kind, block_num, op_serial_id  from  hive.mmm_keyauth_a join hive.mmm_keyauth_k on key_serial_id = key_id WHERE account_id = 14007 " 
}

check_result()
{
  local EXPECTED_OUTPUT="$1"
  # Define the SQL query
  SQL_QUERY="select hive.public_key_to_string(key), account_id, key_kind, block_num, op_serial_id from hive.mmm_keyauth_a join hive.mmm_keyauth_k on key_serial_id = key_id WHERE account_id = 14007"

  # Execute the query and store the output
  OUTPUT=$(psql -d $HAF_POSTGRES_URL -c "$SQL_QUERY")

  

  # Compare the actual output with the expected output
  if [ "$OUTPUT" == "$EXPECTED_OUTPUT" ]; then
      echo "Result is OK"
  else
      echo "Result is NOT OK"
      echo "Actual Output:"
      echo "$OUTPUT"
      exit 1
  fi

}

drop_keyauth
apply_keyauth

RUN_FOR=3
EXPECTED_OUTPUT="                 public_key_to_string                  | account_id | key_kind | block_num | op_serial_id 
-------------------------------------------------------+------------+----------+-----------+--------------
 STM5F9tCbND6zWPwksy1rEN24WjPiQWSU2vwGgegQVjAcYDe1zTWi |      14007 | OWNER    |   2885463 |      3762783
 STM6AzXNwWRzTWCVTgP4oKQEALTW8HmDuRq1avGWjHH23XBNhux6U |      14007 | ACTIVE   |   2885463 |      3762783
 STM69ZG1hx2rdU2hxQkkmX5MmYkHPCmdNeXg4r6CR7gvKUzYwWPPZ |      14007 | POSTING  |   2885463 |      3762783
 STM78Vaf41p9UUMMJvafLTjMurnnnuAiTqChiT5GBph7VDWahQRsz |      14007 | MEMO     |   2885463 |      3762783
(4 rows)"
psql -d $HAF_POSTGRES_URL -c "SELECT mmm.main_test('mmm',1, ${RUN_FOR}000000, 100000);" 2> keyauth_run_${RUN_FOR}m.log
print_result
check_result "$EXPECTED_OUTPUT"


exit 0


RUN_FOR=5
EXPECTED_OUTPUT="                 public_key_to_string                  | account_id | key_kind | block_num | op_serial_id 
-------------------------------------------------------+------------+----------+-----------+--------------
 STM5RLQ1Jh8Kf56go3xpzoodg4vRsgCeWhANXoEXrYH7bLEwSVyjh |      14007 | OWNER    |   3399202 |      6688632
 STM4vuEE8F2xyJhwiNCnHxjUVLNXxdFXtVxgghBq5LVLt49zLKLRX |      14007 | ACTIVE   |   3399203 |      6688640
 STM5tp5hWbGLL1R3tMVsgYdYxLPyAQFdKoYFbT2hcWUmrU42p1MQC |      14007 | POSTING  |   3399203 |      6688640
 STM4uD3dfLvbz7Tkd7of4K9VYGnkgrY5BHSQt52vE52CBL5qBfKHN |      14007 | MEMO     |   3399203 |      6688640
(4 rows)"
psql -d $HAF_POSTGRES_URL -c "SELECT mmm.main_test('mmm',1, ${RUN_FOR}000000, 100000);" 2> keyauth_run_${RUN_FOR}m.log
print_result
check_result "$EXPECTED_OUTPUT"






BLOCKS=(2794855 2794856 2885317 2885318 2885325 2885326 2885369 2885370)
FROM=1
for NUM in "${BLOCKS[@]}"
do
    TO=$NUM
    echo "Running FROM: $FROM TO: $TO"
    psql -d $HAF_POSTGRES_URL -c "SELECT mmm.main_test('mmm',$FROM, $TO, 100000000);" 2> keyauth_run$TO.log
    print_result

    # Update FROM for the next iteration
    FROM=$((TO + 1))
done


# # echo 2885369
# # psql -d $HAF_POSTGRES_URL -c "SELECT mmm.main_test('mmm',2885319, 2885369, 100000000);" 2> keyauth_run.log
# # print_result


# # echo 2885370
# # psql -d $HAF_POSTGRES_URL -c "SELECT mmm.main_test('mmm',2885370, 2885370, 100000000);" 2> keyauth_run.log
# # print_result

# # # psql -d $HAF_POSTGRES_URL -c "SELECT mmm.main_test('mmm',1, 2885317, 100000000);" 2> keyauth_run.log
# # # psql -d $HAF_POSTGRES_URL -c "\pset pager off" -c "select hive.public_key_to_string(key), account_id, key_kind, block_num, op_serial_id  from  hive.mmm_keyauth_a join hive.mmm_keyauth_k on key_serial_id = key_id WHERE account_id = 14007 " 
# # # psql -d $HAF_POSTGRES_URL -c "SELECT mmm.main_test('mmm',2885317, 2885370, 1);" 2> keyauth_run.log
# # # psql -d $HAF_POSTGRES_URL -c "\pset pager off" -c "select hive.public_key_to_string(key), account_id, key_kind, block_num, op_serial_id  from  hive.mmm_keyauth_a join hive.mmm_keyauth_k on key_serial_id = key_id WHERE account_id = 14007 " 
