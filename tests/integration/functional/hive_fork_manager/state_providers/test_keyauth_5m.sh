#! /usr/bin/env bash

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
  local ACCOUNT_NAME="$1"  
  local EXPECTED_OUTPUT="$2"


  local KEYAUTH_SQL_QUERY="
    SELECT hive.public_key_to_string(key),
        account_id,
        key_kind,
        a.block_num,
        op_serial_id
    FROM hive.mmm_keyauth_a a
    JOIN hive.mmm_keyauth_k ON key_serial_id = key_id
    JOIN hive.mmm_accounts_view av ON account_id = av.id
    WHERE av.name = '$ACCOUNT_NAME'
  "

  local ACTUAL_OUTPUT=$(psql -d $HAF_POSTGRES_URL -c "$KEYAUTH_SQL_QUERY")

  compare_actual_vs_expected "$ACTUAL_OUTPUT" "$EXPECTED_OUTPUT"
}

check_accountauth_result()
{
  local ACCOUNT_NAME="$1"  
  local EXPECTED_OUTPUT="$2"

  local ACCOUNTAUTH_SQL_QUERY="
  SELECT
      account_id,
      av_with_mainaccount.name,
      key_kind,
      account_auth_id,
      av_with_supervisaccount.name as supervisaccount,
      a.block_num,
      op_serial_id
  FROM hive.mmm_accountauth_a a
  JOIN hive.mmm_accounts_view av_with_mainaccount ON account_id = av_with_mainaccount.id
  JOIN hive.mmm_accounts_view av_with_supervisaccount ON account_auth_id = av_with_supervisaccount.id
  WHERE av_with_mainaccount.name = '$ACCOUNT_NAME'
  "

  local ACTUAL_OUTPUT=$(psql -d $HAF_POSTGRES_URL -c "$ACCOUNTAUTH_SQL_QUERY")
  compare_actual_vs_expected "$ACTUAL_OUTPUT" "$EXPECTED_OUTPUT"

}

execute_sql()
{
  local RUN_FOR="$1"
  local ACCOUNT_NAME="$2"
  local EXPECTED_OUTPUT="$3"

  drop_keyauth
  apply_keyauth

  echo
  echo Running state provider against account "'$ACCOUNT_NAME'" for ${RUN_FOR}m
  echo
  psql -d $HAF_POSTGRES_URL -c "SELECT mmm.main_test('mmm',1, ${RUN_FOR}000000, 100000);" 2> accountauth_run_${RUN_FOR}m.log
}


run_keyauthauth_test()
{
  local RUN_FOR="$1"
  local ACCOUNT_NAME="$2"
  local EXPECTED_OUTPUT="$3"
  execute_sql "$RUN_FOR" "$ACCOUNT_NAME" "$EXPECTED_OUTPUT"
  check_keyauthauth_result "$ACCOUNT_NAME" "$EXPECTED_OUTPUT"
}

run_accountauth_test()
{
  local RUN_FOR="$1"
  local ACCOUNT_NAME="$2"
  local EXPECTED_OUTPUT="$3"
  execute_sql "$RUN_FOR" "$ACCOUNT_NAME" "$EXPECTED_OUTPUT"
  check_accountauth_result "$ACCOUNT_NAME" "$EXPECTED_OUTPUT"
}


check_database_sql_serialized()
{
  local count=$(psql -d $HAF_POSTGRES_URL -c "SELECT COUNT(*) FROM hive.blocks;" -t -A)


  if [ "$count" -ne 5000000 ]; then
      echo "Database not SQL-serialized!"
      exit 1
  fi
}

check_database_sql_serialized

# Tests

# 'streemian' and 'gtg' use pow_operation to create themselves
RUN_FOR=3
ACCOUNT_NAME='streemian'
EXPECTED_OUTPUT=$(cat <<'EOF'
 account_id |   name    | key_kind | account_auth_id | supervisaccount | block_num | op_serial_id 
------------+-----------+----------+-----------------+-----------------+-----------+--------------
       9223 | streemian | OWNER    |            1489 | xeroc           |   1606743 |      2033587
(1 row)
EOF
)
run_accountauth_test "$RUN_FOR" "$ACCOUNT_NAME" "$EXPECTED_OUTPUT"


# 'wackou' update_witness_operation
RUN_FOR=1
ACCOUNT_NAME='wackou'
EXPECTED_OUTPUT=$(cat <<'EOF'
                 public_key_to_string                  | account_id |    key_kind     | block_num | op_serial_id 
-------------------------------------------------------+------------+-----------------+-----------+--------------
 STM8Nb7Fn1LkHqGCdUq2kvdJYNMgcLoufPePi6TtfQBn18HE9Qbyp |        696 | OWNER           |    827105 |      1098806
 STM8TskdYLGtCtWRqGrXtJiePngvrJVpL9ue9nrMnFqwsLeth8978 |        696 | ACTIVE          |    827105 |      1098806
 STM6HRMhY5XQoX6S8Q26Kb32r3KCbBVWr9rwcYKHv6bzeX3uQFvfZ |        696 | POSTING         |    827105 |      1098806
 STM8Nb7Fn1LkHqGCdUq2kvdJYNMgcLoufPePi6TtfQBn18HE9Qbyp |        696 | MEMO            |    827105 |      1098806
 STM6Kq8bD5PKn53MYQkJo35BagfjvfV2yY13j9WUTsNRAsAU8TegZ |        696 | WITNESS_SIGNING |    957259 |      1263434
(5 rows)
EOF
)
run_keyauthauth_test "$RUN_FOR" "$ACCOUNT_NAME" "$EXPECTED_OUTPUT"

# 'dodl01' uses pow2_operation
RUN_FOR=5
ACCOUNT_NAME='dodl01'
EXPECTED_OUTPUT=$(cat <<'EOF'
                 public_key_to_string                  | account_id | key_kind | block_num | op_serial_id 
-------------------------------------------------------+------------+----------+-----------+--------------
 STM5NWg5uMtGBdzn2ikdER7YatgS8ZefpCC47bUemGffnMbR5KH1T |      26844 | OWNER    |   4103291 |     12948444
 STM5NWg5uMtGBdzn2ikdER7YatgS8ZefpCC47bUemGffnMbR5KH1T |      26844 | ACTIVE   |   4103291 |     12948444
 STM5NWg5uMtGBdzn2ikdER7YatgS8ZefpCC47bUemGffnMbR5KH1T |      26844 | POSTING  |   4103291 |     12948444
 STM5NWg5uMtGBdzn2ikdER7YatgS8ZefpCC47bUemGffnMbR5KH1T |      26844 | MEMO     |   4103291 |     12948444
(4 rows)
EOF
)
run_keyauthauth_test "$RUN_FOR" "$ACCOUNT_NAME" "$EXPECTED_OUTPUT"

# 'dodl11' uses pow2_operation as its first operation
RUN_FOR=5
ACCOUNT_NAME='dodl11'
EXPECTED_OUTPUT=$(cat <<'EOF'
                 public_key_to_string                  | account_id |    key_kind     | block_num | op_serial_id 
-------------------------------------------------------+------------+-----------------+-----------+--------------
 STM7yAJhZTNXvB7sP5g3oxR8SSkvmnwk9kYWCciaetJ9aH2mJHJhF |      65045 | OWNER           |   4107639 |     12987166
 STM7yAJhZTNXvB7sP5g3oxR8SSkvmnwk9kYWCciaetJ9aH2mJHJhF |      65045 | ACTIVE          |   4107639 |     12987166
 STM7yAJhZTNXvB7sP5g3oxR8SSkvmnwk9kYWCciaetJ9aH2mJHJhF |      65045 | POSTING         |   4107639 |     12987166
 STM7yAJhZTNXvB7sP5g3oxR8SSkvmnwk9kYWCciaetJ9aH2mJHJhF |      65045 | MEMO            |   4107639 |     12987166
 STM7yAJhZTNXvB7sP5g3oxR8SSkvmnwk9kYWCciaetJ9aH2mJHJhF |      65045 | WITNESS_SIGNING |   4107639 |     12987166
(5 rows)
EOF
)

run_keyauthauth_test "$RUN_FOR" "$ACCOUNT_NAME" "$EXPECTED_OUTPUT"


RUN_FOR=3
ACCOUNT_NAME='gtg'
EXPECTED_OUTPUT=$(cat <<'EOF'
                 public_key_to_string                  | account_id |    key_kind     | block_num | op_serial_id 
-------------------------------------------------------+------------+-----------------+-----------+--------------
 STM5F9tCbND6zWPwksy1rEN24WjPiQWSU2vwGgegQVjAcYDe1zTWi |      14007 | OWNER           |   2885463 |      3762783
 STM6AzXNwWRzTWCVTgP4oKQEALTW8HmDuRq1avGWjHH23XBNhux6U |      14007 | ACTIVE          |   2885463 |      3762783
 STM69ZG1hx2rdU2hxQkkmX5MmYkHPCmdNeXg4r6CR7gvKUzYwWPPZ |      14007 | POSTING         |   2885463 |      3762783
 STM78Vaf41p9UUMMJvafLTjMurnnnuAiTqChiT5GBph7VDWahQRsz |      14007 | MEMO            |   2885463 |      3762783
 STM5F9tCbND6zWPwksy1rEN24WjPiQWSU2vwGgegQVjAcYDe1zTWi |      14007 | WITNESS_SIGNING |   2881920 |      3756818
(5 rows)
EOF
)
run_keyauthauth_test "$RUN_FOR" "$ACCOUNT_NAME" "$EXPECTED_OUTPUT"


RUN_FOR=5
ACCOUNT_NAME='gtg'
EXPECTED_OUTPUT=$(cat <<'EOF'
                 public_key_to_string                  | account_id |    key_kind     | block_num | op_serial_id 
-------------------------------------------------------+------------+-----------------+-----------+--------------
 STM5RLQ1Jh8Kf56go3xpzoodg4vRsgCeWhANXoEXrYH7bLEwSVyjh |      14007 | OWNER           |   3399202 |      6688632
 STM4vuEE8F2xyJhwiNCnHxjUVLNXxdFXtVxgghBq5LVLt49zLKLRX |      14007 | ACTIVE          |   3399203 |      6688640
 STM5tp5hWbGLL1R3tMVsgYdYxLPyAQFdKoYFbT2hcWUmrU42p1MQC |      14007 | POSTING         |   3399203 |      6688640
 STM4uD3dfLvbz7Tkd7of4K9VYGnkgrY5BHSQt52vE52CBL5qBfKHN |      14007 | MEMO            |   3399203 |      6688640
 STM6GmnhcBN9DxmFcj1e423Q2RkFYStUgSotviptAMSdy74eHQSYM |      14007 | WITNESS_SIGNING |   4104564 |     12959431
(5 rows)
EOF
)
run_keyauthauth_test  "$RUN_FOR" "$ACCOUNT_NAME" "$EXPECTED_OUTPUT"


RUN_FOR=5
ACCOUNT_NAME='streemian'
EXPECTED_OUTPUT=$(cat <<'EOF'
 account_id |   name    | key_kind | account_auth_id | supervisaccount | block_num | op_serial_id 
------------+-----------+----------+-----------------+-----------------+-----------+--------------
       9223 | streemian | OWNER    |            1489 | xeroc           |   3410418 |      6791007
       9223 | streemian | ACTIVE   |            1489 | xeroc           |   3410418 |      6791007
       9223 | streemian | POSTING  |            1489 | xeroc           |   3410418 |      6791007
(3 rows)
EOF
)
run_accountauth_test "$RUN_FOR" "$ACCOUNT_NAME" "$EXPECTED_OUTPUT"


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

