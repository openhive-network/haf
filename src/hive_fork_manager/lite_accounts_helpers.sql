DROP TYPE IF EXISTS hive.l2_authority CASCADE;
CREATE TYPE hive.l2_authority AS (
    key_type text
  , authority_spec text
  , external_authority_spec text
);

DROP TYPE IF EXISTS hive.l2_operation_auth_spec CASCADE;
CREATE TYPE hive.l2_operation_auth_spec AS (
    op_type text
  , req_authorities hive.l2_authority[]
);

DROP TYPE IF EXISTS hive.l2_op CASCADE;
CREATE TYPE hive.l2_op AS (
    type text
  , value text
);

DROP TYPE IF EXISTS hive.l2_signature CASCADE;
CREATE TYPE hive.l2_signature AS (
  sig bytea
);

DROP TYPE IF EXISTS hive.l2_trx CASCADE;
CREATE TYPE hive.l2_trx AS (
    operations hive.l2_op[]
  , signatures hive.l2_signature[]
);

DROP TYPE IF EXISTS hive.l2_public_key CASCADE;
CREATE TYPE hive.l2_public_key AS (
  public_key TEXT
);


DROP TYPE IF EXISTS hive.get_required_auths_return CASCADE;
CREATE TYPE hive.get_required_auths_return AS
(
    public_key TEXT
  --, op l2_op : temporary disabled
);

CREATE OR REPLACE FUNCTION hive.get_required_auths(IN _trx hive.l2_trx, IN _auth_spec hive.l2_operation_auth_spec[])
    RETURNS SETOF hive.get_required_auths_return
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
BEGIN

 RETURN QUERY with q as
 (
  select unnest( _auth_spec ) x
 )
 , auths AS
 (
  select (x).op_type, (unnest((x).req_authorities)).key_type, (unnest((x).req_authorities)).authority_spec, (unnest((x).req_authorities)).external_authority_spec from q
 )
 select k.public_key
 FROM la_app.keys k
  JOIN la_app.accounts acc ON k.account_id = acc.id
  JOIN la_app.key_tags kt ON k.key_tag_id = kt.id
  JOIN auths a ON a.key_type = kt.name AND a.authority_spec = acc.name;

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_transaction_digest(IN trx JSONB, IN chain_id TEXT)
RETURNS TEXT AS 'MODULE_PATHNAME', 'get_transaction_digest' LANGUAGE C;

CREATE OR REPLACE FUNCTION hive.verify_authority(IN trx JSONB, IN public_keys JSONB, IN chain_id TEXT)
RETURNS INTEGER AS 'MODULE_PATHNAME', 'verify_authority' LANGUAGE C;


--examples:
-- select * from hive.get_required_auths
-- (
--   (
--     ARRAY[
--       ('transfer', '{}'::jsonb)::hive.l2_op,
--       ('battle', '{}'::jsonb)::hive.l2_op
--        ],
--     ARRAY[
--        ROW('\x1f7dd25ddc0f78dffc4b17b919e24166852434c0dee9312621cb4aac2898512dfd5e134dc1713ca9f3425933cf64deb8bc7a137f06e7da54d9993c1630e2ac6602'::bytea)::hive.l2_signature,
--        ROW('\xabababababababab'::bytea)::hive.l2_signature
--        ]
--   )::hive.l2_trx,
--   (
--     ARRAY[
--       ('transfer', ARRAY[('active', 'alice', NULL)::hive.l2_authority]),
--       ('battle', ARRAY[('active', 'bob', NULL)::hive.l2_authority])
--        ]
--   )::hive.l2_operation_auth_spec[]
-- )

-- select * from hive.get_transaction_digest
-- (
-- to_jsonb(
--   (
--     ARRAY[
--       ('transfer', '{}')::hive.l2_op,
--       ('battle', '{}')::hive.l2_op
--        ],
--     ARRAY[
--        ROW('\x1f7dd25ddc0f78dffc4b17b919e24166852434c0dee9312621cb4aac2898512dfd5e134dc1713ca9f3425933cf64deb8bc7a137f06e7da54d9993c1630e2ac6602')::hive.l2_signature,
--        ROW('\xabababababababab')::hive.l2_signature
--        ]
--   )::hive.l2_trx ),
--   '18dcf0a285365fc58b71f18b3d3fec954aa0c141c44e4e5cb4cf777b9eab274e'
-- )

-- select * from hive.verify_authority
-- (
-- to_jsonb(
--   (
--     ARRAY[
--       ('transfer', '{}')::hive.l2_op,
--       ('battle', '{}')::hive.l2_op
--        ],
--     ARRAY[
--        ROW('\x1f7dd25ddc0f78dffc4b17b919e24166852434c0dee9312621cb4aac2898512dfd5e134dc1713ca9f3425933cf64deb8bc7a137f06e7da54d9993c1630e2ac6602')::hive.l2_signature,
--        ROW('\xabababababababab')::hive.l2_signature
--        ]
--   )::hive.l2_trx ),
-- to_jsonb(
--   (
--     ROW(ARRAY[
--       ROW('STM6LLegbAgLAy28EHrffBVuANFWcFgmqRMW13wBmTExqFE9SCkg4')::hive.l2_public_key,
--       ROW('7j1orEPpWp4bU2SuH46eYXuXkFKEMeJkuXkZVJSaru2zFDGaEH')::hive.l2_public_key
--     ])
--     )::hive.l2_public_key
--   ),
--   '18dcf0a285365fc58b71f18b3d3fec954aa0c141c44e4e5cb4cf777b9eab274e'
-- )