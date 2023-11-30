-- Constraint: pk_keyauth_live_keyauth_a

ALTER TABLE IF EXISTS hive.keyauth_live_keyauth_a DROP CONSTRAINT IF EXISTS pk_keyauth_live_keyauth_a;

ALTER TABLE IF EXISTS hive.keyauth_live_keyauth_a
    ADD CONSTRAINT pk_keyauth_live_keyauth_a PRIMARY KEY (key_serial_id, account_id, key_kind )
    USING INDEX TABLESPACE haf_tablespace;

CREATE INDEX IF NOT EXISTS idx_hive_keyauth_live_keyauth_a_account_id_key_kind
    ON hive.keyauth_live_keyauth_a USING btree
    (account_id, key_kind)
    TABLESPACE haf_tablespace;


--analyze verbose hive.keyauth_live_keyauth_k

--analyze verbose hive.keyauth_live_keyauth_k

--analyze verbose hive.keyauth_live_keyauth_k

CREATE OR REPLACE FUNCTION hive.keyauth_live_insert_into_keyauth_a(
  _first_block integer,
  _last_block integer)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
    SET join_collapse_limit='16'
    SET from_collapse_limit='16'
    SET jit=false
AS $BODY$
DECLARE
  __account_ae_count INT;
  __key_ae_count INT;

    BEGIN

WITH matching_op_types as materialized 
    (
    select ot.id from hive.operation_types ot WHERE ot.name IN
      (
      'hive::protocol::pow_operation',
      'hive::protocol::pow2_operation',
      'hive::protocol::account_create_operation',
      'hive::protocol::account_create_with_delegation_operation',
      'hive::protocol::account_update_operation',
      'hive::protocol::account_update2_operation',
      'hive::protocol::create_claimed_account_operation',
      'hive::protocol::recover_account_operation',
      'hive::protocol::request_account_recovery_operation',
      'hive::protocol::witness_set_properties_operation',
      'hive::protocol::witness_update_operation'
      )
    ),
    matching_ops as materialized
    (
      SELECT
                ov.body_binary,
                ov.id,
                ov.block_num,
          ov.trx_in_block,
          ov.op_pos,
                ov.timestamp,
                ov.op_type_id
            FROM hive.keyauth_live_operations_view ov
            WHERE ov.block_num BETWEEN _first_block AND _last_block  AND ov.op_type_id IN (SELECT mot.id FROM matching_op_types mot)
    ),
    raw_auth_records AS MATERIALIZED
    (
      SELECT
                (hive.get_keyauths(ov.body_binary)).*,
                ov.id as op_serial_id,
                ov.block_num,
                ov.timestamp,
                hive.calculate_operation_stable_id(ov.block_num, ov.trx_in_block, ov.op_pos) as op_stable_id
            FROM matching_ops ov
        ),
    extended_auth_records as materialized
    (
      SELECT (select a.id FROM hive.keyauth_live_accounts_view a
          where a.name = r.account_name) as account_id,
      r.*
      FROM raw_auth_records r
    ),
  effective_key_auth_records as materialized
  (
    with effective_tuple_ids as materialized 
    (
    select s.account_id, s.key_kind, max(s.op_stable_id) as op_stable_id
    from extended_auth_records s 
    where s.key_auth IS NOT NULL
    group by s.account_id, s.key_kind
    )
    select s1.*
    from extended_auth_records s1
    join effective_tuple_ids e ON e.account_id = s1.account_id and e.key_kind = s1.key_kind and e.op_stable_id = s1.op_stable_id
    where s1.key_auth IS NOT NULL
  ),
  effective_account_auth_records as materialized
  (
    with effective_tuple_ids as materialized 
    (
    select s.account_id, s.key_kind, max(s.op_stable_id) as op_stable_id
    from extended_auth_records s 
    where s.key_auth IS NULL
    group by s.account_id, s.key_kind
    )
    select s1.*
    from extended_auth_records s1
    join effective_tuple_ids e ON e.account_id = s1.account_id and e.key_kind = s1.key_kind and e.op_stable_id = s1.op_stable_id
    where s1.key_auth IS NULL		
  ),
--- PROCESSING OF KEY BASED AUTHORITIES ---	
    supplement_key_dictionary as materialized
    (
      insert into hive.keyauth_live_keyauth_k as dict (key)
      SELECT DISTINCT s.key_auth
      FROM effective_key_auth_records s
    on conflict (key) do update set key = EXCLUDED.key -- the only way to always get key-id (even it is already in dict)
    returning (xmax = 0) as is_new_key, dict.key_id, dict.key
    ),
  extended_key_auth_records as materialized
  (
    select s.*, kd.key_id
    from effective_key_auth_records s
    join supplement_key_dictionary kd on kd.key = s.key_auth
    where s.key_auth IS NOT NULL
  ),
  changed_key_authorities as materialized 
  (
    select distinct s.account_id as changed_account_id, s.key_kind as changed_key_kind
    from extended_key_auth_records s
  )
    ,delete_obsolete_key_auth_records as materialized (
    DELETE FROM hive.keyauth_live_keyauth_a as ea
    using changed_key_authorities s
    where account_id = s.changed_account_id and key_kind = s.changed_key_kind
    RETURNING account_id as cleaned_account_id, key_kind as cleaned_key_kind, key_serial_id as cleaned_key_id
  )
  ,
  store_key_auth_records as materialized
  (
    INSERT INTO hive.keyauth_live_keyauth_a AS auth_entries
    ( account_id, key_kind, key_serial_id, weight_threshold, w, op_serial_id, block_num, timestamp )
    SELECT s.account_id, s.key_kind, s.key_id, s.weight_threshold, s.w, s.op_serial_id, s.block_num, s.timestamp
    FROM extended_key_auth_records s
--		LEFT JOIN delete_obsolete_key_auth_records d ON d.cleaned_account_id = s.account_id and d.cleaned_key_kind = s.key_kind
    ON CONFLICT ON CONSTRAINT pk_keyauth_live_keyauth_a DO UPDATE SET
      key_serial_id = EXCLUDED.key_serial_id,
      weight_threshold =    EXCLUDED.weight_threshold,
      w =                   EXCLUDED.w,
      op_serial_id =        EXCLUDED.op_serial_id,
      block_num =           EXCLUDED.block_num,
      timestamp =           EXCLUDED.timestamp
    RETURNING (xmax = 0) as is_new_entry, auth_entries.account_id, auth_entries.key_kind, auth_entries.key_serial_id as cleaned_key_id
  )
  ,delete_obsolete_keys_from_dict as
  (
    delete from hive.keyauth_live_keyauth_k as dict
    where dict.key_id in (select distinct s.cleaned_key_id from store_key_auth_records s)
  ),
--- PROCESSING OF ACCOUNT BASED AUTHORITIES ---
    extended_account_auth_records as MATERIALIZED
  (
    SELECT ds.*
    FROM (
    SELECT (select a.id FROM hive.keyauth_live_accounts_view a
        where a.name = s.account_auth) as account_auth_id,
    s.*
    FROM effective_account_auth_records s
    ) ds
    WHERE ds.account_auth_id IS NOT NULL
  ),
  changed_account_authorities as materialized 
  (
    select distinct s.account_id as changed_account_id, s.key_kind as changed_key_kind
    from extended_account_auth_records s
  )	
    ,delete_obsolete_account_auth_records as materialized (
    DELETE FROM hive.keyauth_live_accountauth_a as ae
    using changed_account_authorities s
    where account_id = s.changed_account_id and key_kind = s.changed_key_kind
    RETURNING account_id as cleaned_account_id, key_kind as cleaned_key_kind, account_auth_id as cleaned_account_auth_id
  )
  ,
  store_account_auth_records as
  (
    INSERT INTO hive.keyauth_live_accountauth_a AS ae
    ( account_id, key_kind, account_auth_id, weight_threshold, w, op_serial_id, block_num, timestamp )
    SELECT s.account_id, s.key_kind, s.account_auth_id, s.weight_threshold, s.w, s.op_serial_id, s.block_num, s.timestamp
    FROM extended_account_auth_records s
    ON CONFLICT ON CONSTRAINT pk_keyauth_live_accountauth_a DO UPDATE SET
      account_auth_id = EXCLUDED.account_auth_id,
      weight_threshold =    EXCLUDED.weight_threshold,
      w =                   EXCLUDED.w,
      op_serial_id =        EXCLUDED.op_serial_id,
      block_num =           EXCLUDED.block_num,
      timestamp =           EXCLUDED.timestamp
    RETURNING (xmax = 0) as is_new_entry, ae.account_id, ae.key_kind, ae.account_auth_id as cleaned_account_auth_id
  )
  
SELECT (select count(*) FROM store_account_auth_records) as account_based_authority_entries,
     (select count(*) FROM store_key_auth_records) AS key_based_authority_entries
into __account_ae_count, __key_ae_count;

raise notice 'Processed % account-based and % key-based authority entries', __account_ae_count, __key_ae_count;

        END;
    
$BODY$;

-------------------- Cleanup

CALL hive.appproc_context_detach('keyauth_live');

update hive.contexts
set current_block_num = 0,
 irreversible_block = 0
 where name = 'keyauth_live'
 ;

select * from hive.contexts
where name = 'keyauth_live';

update keyauth_live.app_status
set last_processed_block = 0;

truncate table hive.keyauth_live_keyauth_a;
truncate table hive.keyauth_live_accountauth_a;
truncate table hive.keyauth_live_keyauth_k cascade;

------------- end cleanup

/*
2023-11-29 21:56:54.351861 NOTICE:  Last block processed by application: 0
2023-11-29 21:56:54.365663 NOTICE:  Entering application main loop...
2023-11-29 21:56:54.366799 NOTICE:  HAF instance is ready. Exiting wait loop...
2023-11-29 21:56:54.462583 WARNING:  Waiting for next block...
2023-11-29 21:56:54.462928 NOTICE:  HAF instance is ready. Exiting wait loop...
2023-11-29 21:56:54.474057 NOTICE:  Attempting to process block range: <1,80596932>

2023-11-29 22:23:10.366481 NOTICE:  Attempting to process a block range: <72630001, 72640000>
2023-11-29 22:23:10.501116 NOTICE:  Processed 62 account-based and 230 key-based authority entries
2023-11-29 22:23:10.504042 NOTICE:  Block range: <72630001, 72640000> processed successfully.

2023-11-29 22:28:09.516798 NOTICE:  Attempting to process block range: <72640001,80597557>
2023-11-29 22:28:09.516947 NOTICE:  Entering massive processing of block range: <72640001, 80597557>...
2023-11-29 22:30:09.953033 NOTICE:  Processed 45 account-based and 172 key-based authority entries
2023-11-29 22:30:09.954600 NOTICE:  Block range: <80590001, 80597557> processed successfully.
2023-11-29 22:30:09.954654 NOTICE:  Attaching HAF application context at block: 80597557.

*/
