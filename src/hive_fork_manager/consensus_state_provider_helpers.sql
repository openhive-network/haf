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


CREATE OR REPLACE FUNCTION hive.csp_init(IN _context TEXT, IN shared_memory_bin_path TEXT, IN _postgres_url TEXT)
RETURNS BIGINT
AS 'MODULE_PATHNAME', 'csp_init' LANGUAGE C;

CREATE OR REPLACE FUNCTION hive.session_current_all_accounts_balances(IN _session_ptr BIGINT)
RETURNS SETOF hive.current_account_balance_return_type
AS 'MODULE_PATHNAME', 'session_current_all_accounts_balances' LANGUAGE C;

CREATE OR REPLACE FUNCTION hive.session_current_account_balances(IN _session_ptr BIGINT, IN accounts TEXT[])
RETURNS SETOF hive.current_account_balance_return_type
AS 'MODULE_PATHNAME', 'session_current_account_balances' LANGUAGE C;

CREATE OR REPLACE FUNCTION hive.session_consensus_state_provider_replay(IN _session_ptr BIGINT, in _from INT, in _to INT)
RETURNS BOOLEAN
AS 'MODULE_PATHNAME', 'session_consensus_state_provider_replay' LANGUAGE C;

CREATE OR REPLACE FUNCTION hive.session_consensus_state_provider_finish(IN _session_ptr BIGINT)
RETURNS VOID
AS 'MODULE_PATHNAME', 'session_consensus_state_provider_finish' LANGUAGE C;

CREATE OR REPLACE FUNCTION hive.session_consensus_state_provider_get_expected_block_num(IN _session_ptr BIGINT)
RETURNS INTEGER
AS 'MODULE_PATHNAME', 'session_consensus_state_provider_get_expected_block_num' LANGUAGE C;
