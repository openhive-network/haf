from __future__ import annotations

import os
import subprocess
import random
import time
from pathlib import Path
from typing import Any, TYPE_CHECKING

from typing import Iterable
import test_tools as tt
from haf_local_tools.tables import EventsQueue

if TYPE_CHECKING:
    from sqlalchemy.engine.row import Row
    from sqlalchemy.orm.session import Session


BLOCKS_IN_FORK = 5
BLOCKS_AFTER_FORK = 5
WAIT_FOR_CONTEXT_TIMEOUT = 90.0


class haf_app:

    root_path: Path     = None
    postgres_url: str   = None

    def __init__(self, identifier: int, before_kill_time_min: int, before_kill_time_max: int):
        self.pid: int               = None
        self.identifier             = identifier
        self.args: list[str]        = []
        self.before_kill_time_min   = before_kill_time_min
        self.before_kill_time_max   = before_kill_time_max

        self.create_args()

    def setup(session: Session, path: Path):
        haf_app.root_path       = path
        haf_app.postgres_url    = str(session.get_bind().url)

        return haf_app.root_path is not None and haf_app.postgres_url is not None

    def create_args(self):
        assert haf_app.root_path is not None and haf_app.postgres_url is not None

        self.args.append("./haf_memo_scanner.py")
        self.args.append("--scanner-name")
        self.args.append(f"memo_scanner_{self.identifier}")
        self.args.append("--url")
        self.args.append(f"{haf_app.postgres_url}")
        self.args.append("--range-block")
        self.args.append("1")
        self.args.append("--massive-threshold")
        self.args.append("1000000")
        self.args.append("--searched-item")
        self.args.append(f"{self.identifier}")

    def run(self):

        _after_kill_time    = 2
        _before_kill_time   = random.randint( self.before_kill_time_min, self.before_kill_time_max )

        log_file = Path(f'{self.identifier}.log')
        tt.logger.info( f"Before opening file: {log_file}" )
        _process = None
        with open( log_file, "a") as dump_file:
            try:
                tt.logger.info( f"Start app: id: {self.identifier } before time: {_before_kill_time} {haf_app.root_path} {self.args}")
                _process = subprocess.Popen( self.args, cwd = haf_app.root_path, stdout = dump_file, stderr = subprocess.STDOUT )
                self.pid = _process.pid
                tt.logger.info( f"app started: id: {self.identifier} pid: {self.pid}")
            except Exception as ex:
                tt.logger.info( f"app start problem: {ex}")

            time.sleep( _before_kill_time )

            tt.logger.info( f"before kill: before time: {_before_kill_time} [s] id: {self.pid}" )
            _command = "kill -2 " + str( self.pid )
            try:
                os.system( _command )
                _process.wait()
            except Exception as ex:
                tt.logger.info( f"kill problem: {ex}")

            tt.logger.info( f"after kill: {_command}")

            time.sleep( _after_kill_time )

def make_fork(networks: Iterable[tt.Network], main_chain_trxs=[], fork_chain_trxs=[]):
    alpha_net = networks[0]
    beta_net = networks[1]
    alpha_witness_node = alpha_net.node('WitnessNode0')
    beta_witness_node = beta_net.node('WitnessNode1')

    tt.logger.info(f'Making fork at block {get_head_block(alpha_witness_node)}')

    main_chain_wallet = tt.Wallet(attach_to=alpha_witness_node)
    fork_chain_wallet = tt.Wallet(attach_to=beta_witness_node)
    fork_block = get_head_block(beta_witness_node)
    head_block = fork_block
    alpha_net.disconnect_from(beta_net)

    for trx in main_chain_trxs:
        main_chain_wallet.api.sign_transaction(trx)
    for trx in fork_chain_trxs:
        fork_chain_wallet.api.sign_transaction(trx)

    for node in [alpha_witness_node, beta_witness_node]:
        node.wait_for_block_with_number(head_block + BLOCKS_IN_FORK)
    alpha_net.connect_with(beta_net)
    for node in [alpha_witness_node, beta_witness_node]:
        node.wait_for_block_with_number(head_block + BLOCKS_IN_FORK + BLOCKS_AFTER_FORK)

    head_block = get_head_block(beta_witness_node)
    return head_block


def wait_for_irreversible_progress(node, block_num):
    tt.logger.info(f'Waiting for progress of irreversible block')
    head_block = get_head_block(node)
    irreversible_block = get_irreversible_block(node)
    tt.logger.info(f"Current head_block_number: {head_block}, irreversible_block_num: {irreversible_block}")
    while irreversible_block < block_num:
        node.wait_for_block_with_number(head_block+1)
        head_block = get_head_block(node)
        irreversible_block = get_irreversible_block(node)
        tt.logger.info(f"Current head_block_number: {head_block}, irreversible_block_num: {irreversible_block}")
    return irreversible_block, head_block


def get_head_block(node):
    head_block_number = node.api.database.get_dynamic_global_properties()["head_block_number"]
    return head_block_number


def get_irreversible_block(node):
    irreversible_block_num = node.api.database.get_dynamic_global_properties()["last_irreversible_block_num"]
    return irreversible_block_num


SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE = """
    CREATE TABLE IF NOT EXISTS public.trx_histogram(
          day DATE
        , trx INT
        , CONSTRAINT pk_trx_histogram PRIMARY KEY( day ) )
    INHERITS( hive.{} )
    """
SQL_CREATE_UPDATE_HISTOGRAM_FUNCTION = """
    CREATE OR REPLACE FUNCTION public.update_histogram( _first_block INT, _last_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
    AS
     $function$
     BEGIN
        INSERT INTO public.trx_histogram as th( day, trx )
        SELECT
              DATE(hb.created_at) as date
            , COUNT(1) as trx
        FROM hive.trx_histogram_blocks_view hb
        JOIN hive.trx_histogram_transactions_view ht ON ht.block_num = hb.num
        WHERE hb.num >= _first_block AND hb.num <= _last_block
        GROUP BY DATE(hb.created_at)
        ON CONFLICT ON CONSTRAINT pk_trx_histogram DO UPDATE
        SET
            trx = EXCLUDED.trx + th.trx
        WHERE th.day = EXCLUDED.day;
     END;
     $function$
    """


def create_app(session, application_context):
    session.execute( "SELECT hive.app_create_context( '{}' )".format( application_context ) )
    session.execute( SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE.format( application_context ) )
    session.execute( SQL_CREATE_UPDATE_HISTOGRAM_FUNCTION )
    session.commit()

def wait_until_irreversible_without_new_block(session, final_block, limit):

    assert limit > 0

    cnt = 0
    while cnt < limit:
        #wait many times to be sure that whole network is in stable state
        #Changed from 0.1s to 0.5s, because when a computer is under stress (every CPU is used 100%), better is to wait longer
        time.sleep(0.5)

         #Last event is `NEW_IRREVERSIBLE` instead of `MASSIVE_SYNC`.
        events = session.query(EventsQueue).order_by(EventsQueue.id).all()

        tt.logger.info(f'number of events: {len(events)} block number of last event: {0 if len(events) == 0 else events[len(events) - 1].block_num}')

        if len(events) == 3 and events[1].block_num == final_block:
            return

        cnt += 1

    assert False, "An expected content of `events_queue` table has not been reached."

def wait_until_irreversible(node_under_test, session):
    while True:
        node_under_test.wait_number_of_blocks(1)

        #Sometimes an irreversible block is less than head block so it's necessary to try final condition many times
        head_block = get_head_block(node_under_test)
        irreversible_block = get_irreversible_block(node_under_test)

        tt.logger.info(f'head_block: {head_block} irreversible_block: {irreversible_block}')

        result = session.query(EventsQueue).\
            filter(EventsQueue.block_num == head_block).\
            all()

        if result[ len(result) - 1 ].event == 'NEW_IRREVERSIBLE':
            return


def query_col(session: Session, sql: str, **kwargs) -> list[Any]:
    """Perform a `SELECT n*1`"""
    return [row[0] for row in session.execute(sql, params=kwargs).fetchall()]


def query_all(session: Session, sql: str, **kwargs) -> list[Row]:
    """Perform a `SELECT n*m`"""
    return session.execute(sql, params=kwargs).fetchall()
