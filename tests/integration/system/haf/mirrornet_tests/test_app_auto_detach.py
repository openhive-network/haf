import pytest

import copy

import test_tools as tt

from haf_local_tools.system.haf.mirrornet.constants import (
    SKELETON_KEY,
    CHAIN_ID,
)

from sqlalchemy.pool import NullPool
from sqlalchemy import (
  create_engine
  ,text
  )

def execute_sql_query(dbUrl, _query):
    engine = create_engine(dbUrl, echo=True, poolclass=NullPool)

    with engine.begin() as con:
        query = text(_query)
        con.execute(query)

def execute_sql_script(dbUrl, filePath):
    with open(filePath) as file:
        query = file.read()
        execute_sql_query(dbUrl, query)

WITNESSES_1M: list[str] = [
  "datasecuritynode",
  "steempty",
  "silversteem",
  "abit",
  "jabbasteem",
  "hr402",
  "pharesim",
  "kushed",
  "smooth.witness",
  "dele-puppy",
  "steemed",
  "nextgencrypto",
  "clayop",
  "arhag",
  "witness.svk",
  "bhuz",
  "roadscape",
  "au1nethyb1",
  "complexring",
  "xeldal",
  "steemychicken1"
]

@pytest.mark.mirrornet
def test_app_autodetach(witness_node_with_haf, block_log_5m_path, tmp_path):

    block_log_5m = tt.BlockLog(block_log_5m_path)
    block_log_1m = block_log_5m.truncate(tmp_path, 1000000)

    witness_node_with_haf.config.witness = WITNESSES_1M

    witness_node_with_haf.run(
        replay_from=block_log_1m,
        time_offset=block_log_1m.get_head_block_time(
            serialize=True, serialize_format=tt.TimeFormats.TIME_OFFSET_FORMAT
        ),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID, "--skeleton-key", SKELETON_KEY],
    )

    haf_node = witness_node_with_haf

    adminUrl=appUrl=haf_node.session.bind.url.set(username="haf_admin")
    appUrl=haf_node.session.bind.url.set(username="test_app_owner")

    tt.logger.info(f"Working on database connection: {haf_node.session.bind.url=}, {adminUrl=}")
    tt.logger.info(f"appUrl connection: {appUrl=}")

    execute_sql_script(adminUrl, "../../applications/auto_detaching/test_app.sql")
    execute_sql_script(adminUrl, "../../applications/auto_detaching/test_utils.sql")
    execute_sql_script(appUrl, "../../applications/auto_detaching/scenario1.sql")

    last_block_num = haf_node.get_last_block_number()
    tt.logger.info(f"Wait until block: {last_block_num} become irreversible...")
    haf_node.wait_for_irreversible_block(last_block_num)

    execute_sql_query(appUrl, "CALL test.scenario1_prepare('03:59:00'::interval);")

    awaited_block_count = 20+10 # 1 min is a threshold when auto detach should happen, next 10 blocks for potential shifts

    tt.logger.info(f"Waiting for next {awaited_block_count} blocks...")

    haf_node.wait_number_of_blocks(awaited_block_count)
    awaited_block_num = haf_node.get_last_block_number()
    tt.logger.info(f"Block: {awaited_block_num} reached. Performing a context state verification")
    execute_sql_query(appUrl, "SET ROLE test_app_owner; CALL test.scenario1_verify('03:59:00'::interval);")
