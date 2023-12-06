CREATE SCHEMA keyauth_live;

CREATE OR REPLACE PROCEDURE keyauth_live.main(
	IN _appcontext character varying,
	IN _from integer,
	IN _to integer,
	IN _step integer)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
	_last_block INT;
BEGIN
  RAISE NOTICE 'Entering massive processing of block range: <%, %>...', _from, _to;
  RAISE NOTICE 'Detaching HAF application context...';
  CALL hive.appproc_context_detach(_appContext);


  FOR b IN _from .. _to BY _step LOOP
    _last_block := b + _step - 1;

    IF _last_block > _to THEN 
      _last_block := _to;
    END IF;

    RAISE NOTICE 'Attempting to process a block range: <%, %>', b, _last_block;

    PERFORM hive.app_state_providers_update(b, _last_block, _appContext);
 
    RAISE NOTICE 'Block range: <%, %> processed successfully.', b, _last_block;

  END LOOP;

 RAISE NOTICE 'Leaving massive processing of block range: <%, %>...', _from, _to;
END
$BODY$;
CREATE TABLE IF NOT EXISTS keyauth_live.keys (
  account text,
  owner_key text[] DEFAULT '{}',
  active_key text[] DEFAULT '{}',
  posting_key text[] DEFAULT '{}',
  memo text[] DEFAULT '{}',
  owner_acc text[] DEFAULT '{}',
  active_acc text[] DEFAULT '{}',
  posting_acc text[] DEFAULT '{}',

CONSTRAINT pk_keyauth_comparison PRIMARY KEY (account)
);
    
CREATE TABLE IF NOT EXISTS keyauth_live.differing_accounts (
  account TEXT
);

CREATE OR REPLACE FUNCTION keyauth_live.current_state(_account text)
RETURNS SETOF keyauth_live.keys -- noqa: LT01
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  RETURN QUERY 
  SELECT
  _account,
  COALESCE(key_subquery.owner_key,'{}'),
  COALESCE(key_subquery.active_key,'{}'),
  COALESCE(key_subquery.posting_key,'{}'),
  COALESCE(key_subquery.memo,'{}'),
  COALESCE(acc_subquery.owner_acc,'{}'),
  COALESCE(acc_subquery.active_acc,'{}'),
  COALESCE(acc_subquery.posting_acc,'{}')
FROM
  (
    SELECT
      MAX(CASE WHEN key_kind = 'OWNER' THEN key_agg END) AS owner_key,
      MAX(CASE WHEN key_kind = 'MEMO' THEN key_agg END) AS memo,
      MAX(CASE WHEN key_kind = 'POSTING' THEN key_agg END) AS posting_key,
      MAX(CASE WHEN key_kind = 'ACTIVE' THEN key_agg END) AS active_key
    FROM (
	  WITH selected AS (
      SELECT
        a.key_kind,
        hive.public_key_to_string(c.key) as key_string
      FROM hive.keyauth_live_keyauth_a a
      JOIN hive.accounts_view b ON a.account_id = b.id
      JOIN hive.keyauth_live_keyauth_k c ON a.key_serial_id = c.key_id
      WHERE b.name = _account AND a.key_kind != 'WITNESS_SIGNING'
      ORDER BY key_string)
	  SELECT key_kind, array_agg(key_string) as key_agg FROM selected GROUP BY key_kind
    ) AS key_agg_subquery
  ) AS key_subquery,
  (
    SELECT
      MAX(CASE WHEN key_kind = 'OWNER' THEN acc_agg::TEXT[] END) AS owner_acc,
      MAX(CASE WHEN key_kind = 'POSTING' THEN acc_agg::TEXT[] END) AS posting_acc,
      MAX(CASE WHEN key_kind = 'ACTIVE' THEN acc_agg::TEXT[] END) AS active_acc
    FROM (
	  WITH selected AS (
      SELECT
        a.key_kind,
        c.name 
      FROM hive.keyauth_live_accountauth_a a
      JOIN hive.accounts_view b ON a.account_id = b.id
      JOIN hive.accounts_view c ON a.account_auth_id = c.id
      WHERE b.name = _account
	  ORDER BY c.name)
	  SELECT key_kind, array_agg(name) as acc_agg FROM selected GROUP BY key_kind
    ) AS acc_agg_subquery
  ) AS acc_subquery;

END
$$;

CREATE OR REPLACE FUNCTION keyauth_live.compare(_account text)
RETURNS SETOF keyauth_live.keys -- noqa: LT01
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  RETURN QUERY 
SELECT * FROM keyauth_live.keys a WHERE a.account =_account 
UNION ALL
SELECT * FROM keyauth_live.current_state(_account);


END 
$$;


CREATE OR REPLACE FUNCTION keyauth_live.filter_key(_key_array JSONB)
RETURNS TEXT[] -- noqa: LT01, CP05
LANGUAGE 'plpgsql'
STABLE
AS
$$
BEGIN
RETURN (
WITH selected AS MATERIALIZED (
SELECT jsonb_array_elements(_key_array) as key_column
)
SELECT array_agg(key_column->>0) FROM selected
);

END
$$;


CREATE OR REPLACE FUNCTION keyauth_live.dump_current_account_stats(account_data jsonb)
RETURNS void
LANGUAGE 'plpgsql'
VOLATILE
AS
$$
BEGIN
INSERT INTO keyauth_live.keys 
 SELECT 
    account_data->>'name' as account,
    COALESCE((SELECT keyauth_live.filter_key(account_data->'owner'->'key_auths')),'{}') AS owner_key,
    COALESCE((SELECT keyauth_live.filter_key(account_data->'active'->'key_auths')),'{}') AS active_key,
    COALESCE((SELECT keyauth_live.filter_key(account_data->'posting'->'key_auths')),'{}') AS posting_key,
	  ARRAY[account_data->>'memo_key'] AS memo,
    COALESCE((SELECT keyauth_live.filter_key(account_data->'owner'->'account_auths')),'{}') AS owner_acc,
    COALESCE((SELECT keyauth_live.filter_key(account_data->'active'->'account_auths')),'{}') AS active_acc,
    COALESCE((SELECT keyauth_live.filter_key(account_data->'posting'->'account_auths')),'{}') AS posting_acc;
END
$$;

CREATE OR REPLACE FUNCTION keyauth_live.compare_accounts()
RETURNS void
LANGUAGE 'plpgsql'
VOLATILE
AS
$$
BEGIN
WITH account_balances AS (
  SELECT *
  FROM keyauth_live.keys
)
INSERT INTO keyauth_live.differing_accounts
SELECT account_balances.account
FROM account_balances
JOIN keyauth_live.current_state(account_balances.account) AS _current_account_stats
ON _current_account_stats.account = account_balances.account
WHERE 
     account_balances.memo != _current_account_stats.memo

  OR NOT account_balances.owner_key @> _current_account_stats.owner_key
  OR NOT account_balances.active_key @> _current_account_stats.active_key
  OR NOT account_balances.posting_key @> _current_account_stats.posting_key
  OR NOT account_balances.owner_acc @> _current_account_stats.owner_acc
  OR NOT account_balances.active_acc @> _current_account_stats.active_acc
  OR NOT account_balances.posting_acc @> _current_account_stats.posting_acc
  
  OR NOT account_balances.owner_key <@ _current_account_stats.owner_key
  OR NOT account_balances.active_key <@ _current_account_stats.active_key
  OR NOT account_balances.posting_key <@ _current_account_stats.posting_key
  OR NOT account_balances.owner_acc <@ _current_account_stats.owner_acc
  OR NOT account_balances.active_acc <@ _current_account_stats.active_acc
  OR NOT account_balances.posting_acc <@ _current_account_stats.posting_acc;
END
$$;