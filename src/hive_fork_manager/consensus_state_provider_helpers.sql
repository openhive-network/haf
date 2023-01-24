DROP TYPE IF EXISTS hive.current_account_balance_return_type  CASCADE;
CREATE TYPE hive.current_account_balance_return_type  AS
(
    account                 CHAR(16),
    balance                 BIGINT,
    hbd_balance             BIGINT,
    vesting_shares          BIGINT,
    savings_hbd_balance     BIGINT,
    reward_hbd_balance      BIGINT
);

CREATE OR REPLACE FUNCTION hive.current_all_accounts_balances_C(IN _context TEXT)
RETURNS SETOF hive.current_account_balance_return_type
AS 'MODULE_PATHNAME', 'current_all_accounts_balances_C' LANGUAGE C;



CREATE OR REPLACE FUNCTION hive.consensus_state_provider_replay(in _from INT, in _to INT, IN _context TEXT, IN _postgres_url TEXT)
RETURNS VOID
AS 'MODULE_PATHNAME', 'consensus_state_provider_replay' LANGUAGE C;

CREATE OR REPLACE FUNCTION hive.consensus_state_provider_finish(IN _context TEXT)
RETURNS VOID
AS 'MODULE_PATHNAME', 'consensus_state_provider_finish' LANGUAGE C;

CREATE OR REPLACE FUNCTION hive.consensus_state_provider_get_expected_block_num(IN _context TEXT)
RETURNS INTEGER
AS 'MODULE_PATHNAME', 'consensus_state_provider_get_expected_block_num' LANGUAGE C;
