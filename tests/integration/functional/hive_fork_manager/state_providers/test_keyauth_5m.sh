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
      echo "$EXPECTED_OUTPUT" > expected_output.txt
      echo 
      echo "Actual Output:"
      echo "$ACTUAL_OUTPUT"
      echo "$ACTUAL_OUTPUT" > actual_output.txt
      exit 1
  fi
}

execute_keyauth_query()
{
  local account_name="$1"
  local haf_postgres_url="$2"

  local keyauth_sql_query="
    SELECT hive.public_key_to_string(key),
        account_id,
        key_kind,
        a.block_num,
        op_serial_id
    FROM hive.mmm_keyauth_a a
    JOIN hive.mmm_keyauth_k ON key_serial_id = key_id
    JOIN hive.mmm_accounts_view av ON account_id = av.id
    WHERE av.name = '$account_name'
  "

  local actual_output=$(psql -d $haf_postgres_url -c "$keyauth_sql_query")
  echo "$actual_output"
}

check_keyauthauth_result()
{
  local account_name="$1"  
  local expected_output="$2"

  local actual_output=$(execute_keyauth_query "$account_name" "$HAF_POSTGRES_URL")

  compare_actual_vs_expected "$actual_output" "$expected_output"
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
  echo Running state provider against account "'$ACCOUNT_NAME'" for ${RUN_FOR}
  echo
  psql -d $HAF_POSTGRES_URL -c "SELECT mmm.main_test('mmm',1, ${RUN_FOR}, 100000);" 2> accountauth_run_${RUN_FOR}.log
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

# dump_account


# Tests

# 'streemian' and 'gtg' use pow_operation to create themselves
RUN_FOR=3000000
ACCOUNT_NAME='streemian'
EXPECTED_OUTPUT=$(cat <<'EOF'
 account_id |   name    | key_kind | account_auth_id | supervisaccount | block_num | op_serial_id 
------------+-----------+----------+-----------------+-----------------+-----------+--------------
       9223 | streemian | OWNER    |            1489 | xeroc           |   1606743 |      2033587
(1 row)
EOF
)
run_accountauth_test "$RUN_FOR" "$ACCOUNT_NAME" "$EXPECTED_OUTPUT"




# # RUN_FOR=5000000
# # ACCOUNT_NAME='alibaba'
# # EXPECTED_OUTPUT=$(cat <<'EOF'
# #  account_id |   name    | key_kind | account_auth_id | supervisaccount | block_num | op_serial_id 
# # ------------+-----------+----------+-----------------+-----------------+-----------+--------------
# #        9223 | streemian | OWNER    |            1489 | xeroc           |   1606743 |      2033587
# # (1 row)
# # EOF
# # )
# #  "$RUN_FOR" "$ACCOUNT_NAME" "$EXPECTED_OUTPUT"

RUN_FOR=4085934
ACCOUNT_NAME='snail-157'
EXPECTED_OUTPUT=$(cat <<'EOF'
                 public_key_to_string                  | account_id |    key_kind     | block_num | op_serial_id 
-------------------------------------------------------+------------+-----------------+-----------+--------------
 STM6KAT3hPJj4bhZL1gh9Q4zFMbcTCFe6X2omuXajc8CrBPsoWxCu |      63770 | OWNER           |   4085279 |     12829051
 STM6KAT3hPJj4bhZL1gh9Q4zFMbcTCFe6X2omuXajc8CrBPsoWxCu |      63770 | ACTIVE          |   4085934 |     12833844
 STM6KAT3hPJj4bhZL1gh9Q4zFMbcTCFe6X2omuXajc8CrBPsoWxCu |      63770 | POSTING         |   4085279 |     12829051
 STM6KAT3hPJj4bhZL1gh9Q4zFMbcTCFe6X2omuXajc8CrBPsoWxCu |      63770 | MEMO            |   4085279 |     12829051
 STM6KAT3hPJj4bhZL1gh9Q4zFMbcTCFe6X2omuXajc8CrBPsoWxCu |      63770 | WITNESS_SIGNING |   4085304 |     12829285
(5 rows)
EOF
)
run_keyauthauth_test "$RUN_FOR" "$ACCOUNT_NAME" "$EXPECTED_OUTPUT"

RUN_FOR=5000000
ACCOUNT_NAME='snail-157'
EXPECTED_OUTPUT=$(cat <<'EOF'
                 public_key_to_string                  | account_id |    key_kind     | block_num | op_serial_id 
-------------------------------------------------------+------------+-----------------+-----------+--------------
 STM6KAT3hPJj4bhZL1gh9Q4zFMbcTCFe6X2omuXajc8CrBPsoWxCu |      63770 | OWNER           |   4085279 |     12829051
 STM6KAT3hPJj4bhZL1gh9Q4zFMbcTCFe6X2omuXajc8CrBPsoWxCu |      63770 | ACTIVE          |   4104771 |     12961220
 STM6KAT3hPJj4bhZL1gh9Q4zFMbcTCFe6X2omuXajc8CrBPsoWxCu |      63770 | POSTING         |   4085279 |     12829051
 STM6KAT3hPJj4bhZL1gh9Q4zFMbcTCFe6X2omuXajc8CrBPsoWxCu |      63770 | MEMO            |   4085279 |     12829051
 STM6Y3zjt2pLJwua4S2hNgEnmVFigbDJNtgTtwRqFwcWjxxP2rinZ |      63770 | WITNESS_SIGNING |   4105317 |     12965992
(5 rows)
EOF
)
run_keyauthauth_test "$RUN_FOR" "$ACCOUNT_NAME" "$EXPECTED_OUTPUT"

# 'wackou' update_witness_operation
RUN_FOR=1000000
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
RUN_FOR=5000000
ACCOUNT_NAME='dodl01'
EXPECTED_OUTPUT=$(cat <<'EOF'
                 public_key_to_string                  | account_id | key_kind | block_num | op_serial_id 
-------------------------------------------------------+------------+----------+-----------+--------------
 STM5NWg5uMtGBdzn2ikdER7YatgS8ZefpCC47bUemGffnMbR5KH1T |      26844 | OWNER    |   3298952 |      5694156
 STM5NWg5uMtGBdzn2ikdER7YatgS8ZefpCC47bUemGffnMbR5KH1T |      26844 | ACTIVE   |   4103291 |     12948444
 STM5NWg5uMtGBdzn2ikdER7YatgS8ZefpCC47bUemGffnMbR5KH1T |      26844 | POSTING  |   3298952 |      5694156
 STM5NWg5uMtGBdzn2ikdER7YatgS8ZefpCC47bUemGffnMbR5KH1T |      26844 | MEMO     |   3298952 |      5694156
(4 rows)
EOF
)
run_keyauthauth_test "$RUN_FOR" "$ACCOUNT_NAME" "$EXPECTED_OUTPUT"

# 'dodl11' uses pow2_operation as its first operation
RUN_FOR=5000000
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


RUN_FOR=3000000
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


RUN_FOR=5000000
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


RUN_FOR=5000000
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



dump_account()
{
  local ACCOUNT_NAME=alibaba
  local BLOCKS=(



  302741
  302741
  304387
  304409
  304418
  304437
  304437
  304443
  304470
  304470
  304482
  304501
  304520
  304524
  304556
  304576
  304592
  304610
  304627
  304647
  304651
  304673
  304690
  304710
  304729
  304738
  304770
  304778
  304811
  308556
  310171
  310209
  310230
  310242
  310261
  310278
  310316
  310323
  310349
  310362
  310362
  310390
  310411
  310429
  310454
  310467
  310495
  310520
  310542
  310569
  310579
  310611
  311159
  312730
  312748
  312754
  312774
  312779
  312816
  312823
  312855
  312859
  312879
  312898
  312902
  312933
  312963
  312968
  312996
  313015
  313029
  313029
  313056
  313073
  313104
  313125
  313143
  315150
  316719
  316734
  316748
  316767
  316791
  316816
  316840
  316855
  316879
  316896
  316913
  316943
  316954
  316994
  317009
  317031
  317047
  317059
  317082
  317104
  317126
  317184
  318749
  318775
  318797
  318812
  318824
  318845
  318885
  318891
  318910
  318932
  318967
  318988
  318998
  319026
  319041
  319060
  319091
  319107
  319125
  319142
  319165
  321941
  323582
  323600
  323611
  323631
  323650
  323669
  323687
  323696
  323728
  323747
  323937
  323956
  323971
  323993
  326146
  327797
  327820
  327848
  327870
  327883
  327909
  327922
  327937
  327963
  327998
  328000
  328020
  328025
  328058
  328070
  328087
  328116
  328116
  328141
  328165
  328172
  328189
  328209
  328224
  328857
  330509
  330535
  330550
  330578
  330592
  330605
  330624
  330628
  330652
  330680
  330704
  330709
  330729
  330746
  330765
  330789
  330805
  330816
  330841
  330869
  330881
  330905
  330928
  337479
  339176
  339203
  339233
  339244
  339257
  339285
  339307
  339333
  339348
  339369
  339399
  339416
  339441
  339447
  339470
  339502
  339509
  339537
  339562
  339586
  339610
  340598
  342270
  342292
  342292
  342303
  342334
  342353
  342368
  342398
  342425
  342445
  342453
  342474
  342505
  342520
  342541
  342557
  342585
  342606
  342631
  342649
  342663
  342694
  343518
  345206
  345233
  345261
  345263
  345296
  345312
  345342
  345363
  345373
  345401
  345426
  345426
  345433
  345467
  345479
  345493
  345513
  345520
  345544
  345565
  345582
  345602
  345629
  347213
  348854
  348883
  348915
  348930
  348943
  348964
  348985
  349016
  349028
  349043
  349069
  349069
  349086
  349118
  349132
  349151
  349174
  349191
  349229
  349244
  349264
  349289
  350436
  352136
  352156
  352190
  352209
  352216
  352251
  352268
  352290
  352316
  352322
  352353
  352372
  352388
  352405
  352405
  352423
  352445
  352472
  352502
  352521
  352545
  352563
  353458
  355172
  355182
  355209
  355232
  355255
  355263
  355279
  355316
  355334
  355357
  355383
  355397
  355413
  355439
  355451
  355481
  355497
  355513
  355534
  355557
  355589
  375700
  377507
  377532
  377540
  377558
  377572
  377584
  377615
  377615
  377637
  377656
  377670
  377699
  377707
  377725
  377739
  377757
  377776
  377794
  377817
  377841
  377867
  377893
  377903
  377903
  377931
  382732
  383453
  384474
  384497
  384527
  384547
  384568
  384576
  384594
  384608
  384618
  384649
  384664
  384683
  384683
  384704
  384732
  384761
  384769
  384787
  384809
  384845
  384861
  384878
  384907
  387035
  388761
  388792
  388804
  388817
  388850
  388865
  388886
  388903
  388938
  388960
  388977
  388984
  389012
  389031
  389058
  389080
  389092
  389128
  389144
  389158
  389188
  389493
  391200
  391221
  391242
  391261
  391292
  391309
  391335
  391347
  391359
  391382
  391382
  391402
  391423
  391448
  391468
  391489
  391509
  391541
  391561
  391587
  391590
  391617
  392911
  394570
  394590
  394609
  394627
  394652
  394663
  394677
  394699
  394735
  394751
  394763
  394783
  394810
  394839
  394845
  394881
  394895
  394919
  394931
  394951
  394978
  394997
  396269
  397983
  398003
  398022
  398035
  398052
  398056
  398073
  398085
  398111
  398129
  398154
  398171
  398190
  398209
  398236
  398250
  398268
  398285
  398291
  398309
  398326
  398329
  398347
  398350
  398368
  398388
  398410
  398544
  399683
  401377
  401395
  401422
  401445
  401459
  401485
  401504
  401540
  401546
  401575
  401588
  401614
  401636
  401657
  401677
  401694
  401694
  401711
  401741
  401758
  401773
  401793
  401812
  402987
  404647
  404659
  404682
  404695
  404720
  404744
  404760
  404779
  404804
  404829
  404854
  404866
  404897
  404916
  404943
  404955
  404968
  405000
  405007
  405047
  405069
  405069
  754288
  781109
  782940
  782954
  782984
  782995
  783010
  783037
  783062
  783078
  783094
  783125
  783137
  783154
  783195
  783209
  783220
  783242
  783261
  783286
  783310
  783327
  783362
  812179
  814057
  814084
  814104
  814115
  814136
  814166
  814172
  814212
  814227
  814246
  814246
  814274
  814277
  814307
  814322
  814350
  814380
  814383
  814408
  814440
  814461
  814485
  905693
  921192
  923198
  929888
  931873
  933644
  935614
  935629
  948470
  950498
 1120388
 1122311
 1122540
 1124569
 1124569
 1124702
 1126758
 1126964
 1128936
 1128937
 1130880
 1131279
 1133267
 1152315
 1154275
 1172441
 1174442
 1190204
 1192175
 1203933
 1205934
 1217382
 1219392
 1219718
 1221602
 1228286
 1230269
 1232669
 1234644
 1242180
 1244133
 1247757
 1249601
 1252275
 1254214
 1255469
 1257470
 1277811
 1279803
 1283127
 1285099
 1291045
 1293036
 1306466
 1308462
 1308462
 1310449
 1312450
 1355391
 1357382
 1377607
 1379608
 1380772
 1382796
 1395574
 1397565
 1398379
 1405570
 1407587
 1424422
 1426440
 1427173
 1429169
 1445264
 1447272
 1466527
 1468555
 1504448
 1506514
 1517385
 1519388
 1519988
 1521974
 1543371
 1545335
 1545512
 1547513
 1552264
 1554262
 1561479
 1563463
 1565144
 1567155
 1583052
 1585048
 1603715
 1605712
 1620912
 1622901
 1640712
 1642657
 1645630
 1647705
 1664413
 1666433
 1684417
 1686425
 1689178
 1691187
 1695788
 1697758
 1701361
 1703370
 1704027
 1706068
 1708294
 1710302
 1711338
 1713341
 1717633
 1719682
 1730072
 1732085
 1739904
 1741929
 1744996
 1746954
 1750946
 1752909
 1771898
 1773835
 1776129
 1778115
 1784655
 1786641
 1793548
 1795551
 1796023
 1798027
 1805243
 1807294
 1807557
 1809606
 1814895
 1816882
 1829830
 1831834
 1833991
 1835984
 1852524
 1854548
 1857912
 1859954
 1896092
 1898094
 1983217
 1985128
 2064219
 2066283
 2066563
 2068577
 2072628
 2074684
 2076541
 2078505
 2078507
 2080522
 2089095
 2091107
 2113468
 2115537
 2129000
 2131064
 2159416
 2161542
 2201748
 2203768
 2299270
 2301296
 2307344
 2309452
 2432531
 2434616
 2462022
 2464081
 2523955
 2526034
 2526034
 2541306
 2543323
 2543594
 2545680
 2545777
 2547863
 2564751
 2566831
 2569852
 2571950
 2585732
 2587829
 2614264
 2616324
 2624220
 2626300
 2631936
 2634001
 2668394
 2670469
 2688162
 2690133
 2691770
 2693852key_au
 2696284
 2698363
 2714301
 2716409
 2716409
 2718158
 2720282
 2734487
 2736471
 2746768
 2748821
 2811450
 2813529
 2826717
 2828810
 2828810
 2863710
 2865820
 2874279
 2876440
 2880960
 2883056
 2915788
 2917846
 2936992
 2939088
 2968177
 2970248
 3022754
 3024830
 3036751
 3038766
 3062266
 3064378
 3074674
 3076704
 3088870
 3090995
 3091306
 3093385
 3096511
 3098611
 3167105
 3169103
 3177064
 3179144
 3193996
 3985646
    )


  local LOG_FILE_DIR=/tmp/hive2

  local FROM=1
  for NUM in "${BLOCKS[@]}"
  do
      TO=$NUM
      echo "Running FROM: $FROM TO: $TO"
      psql -d $HAF_POSTGRES_URL -c "SELECT mmm.main_test('mmm',$FROM, $TO, 100000000);" 2> keyauth_run$TO.log
      LOG_FILE=${LOG_FILE_DIR}/${ACCOUNT_NAME}_${TO}.sqlresult
      echo Writing to file $LOG_FILE
      execute_keyauth_query "$ACCOUNT_NAME" "$HAF_POSTGRES_URL" 2>&1 | tee -i -a $LOG_FILE

      FROM=$((TO + 1))
  done
}
