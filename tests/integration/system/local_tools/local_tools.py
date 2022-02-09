from datetime import datetime, timezone
import time
import json
from threading import Thread, Event

from test_tools import logger, Wallet, BlockLog, Account, Asset
from test_tools.private.wait_for import wait_for_event
from witnesses import alpha_witness_names, beta_witness_names
from tables import *


BLOCKS_IN_FORK = 5
WAIT_FOR_FORK_TIMEOUT = 90.0


def get_head_block(node):
    head_block_number = node.api.database.get_dynamic_global_properties()["head_block_number"]
    return head_block_number


def get_irreversible_block(node):
    irreversible_block_num = node.api.database.get_dynamic_global_properties()["last_irreversible_block_num"]
    return irreversible_block_num


def make_fork(world, at_block=None, main_chain_trxs=[], fork_chain_trxs=[]):
    alpha_net = world.network('Alpha')
    beta_net = world.network('Beta')
    alpha_witness_node = alpha_net.node('WitnessNode0')
    beta_witness_node = beta_net.node(name='WitnessNode0')
    node_under_test = beta_net.node(name='NodeUnderTest')

    fork_block = at_block or get_head_block(node_under_test)
    logger.info(f'Making fork at block {fork_block}')
    if at_block is not None:
        node_under_test.wait_for_block_with_number(at_block)

    alpha_net.disconnect_from(beta_net)

    threads = []
    if main_chain_trxs:
        main_chain_wallet = Wallet(attach_to=world.network('Alpha').node('WitnessNode0'))
        import_witnesses_keys(main_chain_wallet)
        t1 = send_transactions_asynchronously(main_chain_wallet, main_chain_trxs)
        threads.append(t1)
    if fork_chain_trxs:
        fork_chain_wallet = Wallet(attach_to=world.network('Beta').node('WitnessNode0'))
        import_witnesses_keys(fork_chain_wallet)
        t2 = send_transactions_asynchronously(fork_chain_wallet, fork_chain_trxs)
        threads.append(t2)

    for t in threads:
        t.join()

    for node in [alpha_witness_node, beta_witness_node]:
        node.wait_for_block_with_number(fork_block + BLOCKS_IN_FORK)
    return fork_block


def send_transactions_asynchronously(wallet, trxs):
    def sign_and_send():
        for trx in trxs:
            wallet.api.sign_transaction(trx)
    t = Thread(target=sign_and_send, daemon=True)
    t.start()
    return t


def back_from_fork(world):
    alpha_net = world.network('Alpha')
    beta_net = world.network('Beta')
    node_under_test = world.network('Beta').node('NodeUnderTest')

    logger.info(f'Reconnecting forks')

    alpha_net.connect_with(beta_net)
    waited = wait_for_back_from_fork(node_under_test)
    logger.info(f'Switching to different fork detected after {waited} seconds')

    head_block = get_head_block(node_under_test)
    return head_block


def wait_for_back_from_fork(node, timeout=WAIT_FOR_FORK_TIMEOUT):
    started_waiting = time.time()
    node.wait_for_fork(timeout)

    return time.time() - started_waiting


def switched_fork(node):
    # TODO use notification system when it is ready instead of parsing stderr
    with open(node.directory / 'stderr.txt') as node_stderr:
        for line in node_stderr:
            if 'Switching to fork' in line:
                return True

    return False


def wait_for_irreversible_progress(node, block_num, logging_frequency=5):
    logger.info(f'Waiting for progress of irreversible block')
    head_block = get_head_block(node)
    irreversible_block = get_irreversible_block(node)
    while irreversible_block < block_num:
        try:
            node.wait_for_block_with_number(head_block+1, timeout=30.0)
        except TimeoutError:
            node.api.network_node.set_allowed_peers(allowed_peers=[node.get_id()])
            node.api.network_node.set_allowed_peers(allowed_peers=[])

        head_block = get_head_block(node)
        irreversible_block = get_irreversible_block(node)
        if head_block % logging_frequency == 0:
            logger.info(f"Current head_block_number: {head_block}, irreversible_block_num: {irreversible_block}")
            logger.info(f"Waiting for irreversible progress until block {block_num}")
    return irreversible_block, head_block


def get_time_offset_from_file(name):
    timestamp = ''
    with open(name, 'r') as f:
        timestamp = f.read()
    timestamp = timestamp.strip()
    current_time = datetime.now(timezone.utc)
    new_time = datetime.strptime(timestamp, '%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc)
    difference = round(new_time.timestamp()-current_time.timestamp()) - 10 # circa 10 seconds is needed for nodes to startup
    time_offset = str(difference) + 's'
    return time_offset


def run_networks(world, blocklog_directory, replay_all_nodes=True):
    world.run_all_nodes(prepared_block_log=True, replay_all_nodes=replay_all_nodes)
    return
    time_offset = get_time_offset_from_file(blocklog_directory/'timestamp')

    block_log = BlockLog(None, blocklog_directory/'block_log', include_index=False)

    logger.info('Running nodes...')

    nodes = world.nodes()
    nodes[0].run(wait_for_live=False, replay_from=block_log, time_offset=time_offset)
    endpoint = nodes[0].get_p2p_endpoint()
    for node in nodes[1:]:
        node.config.p2p_seed_node.append(endpoint)
        if replay_all_nodes:
            node.run(wait_for_live=False, replay_from=block_log, time_offset=time_offset)
        else:
            node.run(wait_for_live=False, time_offset=time_offset)

    for network in world.networks():
        network.is_running = True

    deadline = time.time() + 20
    for node in nodes:
        wait_for_event(
            node._Node__notifications.live_mode_entered_event,
            deadline=deadline,
            exception_message='Live mode not activated on time.'
        )


def create_node_with_database(network, url):
    api_node = network.create_api_node()
    api_node.config.plugin.append('sql_serializer')
    api_node.config.psql_url = str(url)
    return api_node


def get_account_history(session, name, include_reversible=False):
    acc = session.query(Accounts).filter(Accounts.name == name).one_or_none()
    if acc == None:
        acc = session.query(AccountsReversible).filter(AccountsReversible.name == name).one_or_none()
        if acc == None:
            return []

    id = acc.id
    types = []

    acc_ops = session.query(AccountOperations).\
        filter(AccountOperations.account_id == id).\
        order_by(AccountOperations.account_op_seq_no).all()
    for acc_op in acc_ops:
        operation_id = acc_op.operation_id
        op = session.query(Operations).filter(Operations.id==operation_id).one()
        types.append(json.loads(op.body)['type'])

    if include_reversible:
        acc_ops_reversible = session.query(AccountOperationsReversible).\
            filter(AccountOperationsReversible.account_id == id).\
            order_by(AccountOperationsReversible.account_op_seq_no).all()
        for acc_op in acc_ops_reversible:
            operation_id = acc_op.operation_id
            op = session.query(OperationsReversible).filter(OperationsReversible.id==operation_id).one()
            types.append(json.loads(op.body)['type'])

    return types


def import_witnesses_keys(wallet):
    for name in alpha_witness_names:
        wallet.api.import_key(Account(name).private_key)
    for name in beta_witness_names:
        wallet.api.import_key(Account(name).private_key)


def prepare_create_account_trxs(wallet, name):
    transaction1 = wallet.api.create_account('initminer', name, '', broadcast=False)
    transaction2 = wallet.api.transfer('initminer', name, Asset.Test(1), 'memo', broadcast=False)

    return [transaction1, transaction2]


def prepare_transaction1_multisig(wallet):
    import_witnesses_keys(wallet)
    context1 = wallet.in_single_transaction(broadcast=False)
    with context1:
        for name in ['witness1-alpha', 'witness1-beta']:
            wallet.api.transfer(name, "initminer", Asset.Test(1), 'memo')
    transaction1 = context1.get_response()
    return transaction1


def prepare_transaction2_multisig(wallet):
    import_witnesses_keys(wallet)
    context2 = wallet.in_single_transaction(broadcast=False)
    with context2:
        for name in ['witness2-alpha', 'witness2-beta']:
            wallet.api.transfer(name, "initminer", Asset.Test(1), 'memo')
    transaction2 = context2.get_response()
    return transaction2


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


def update_app_continuously(session, application_context):
    class HafApp(Thread):
        def __init__(self, session, application_context):
            Thread.__init__(self, name='haf application')
            self.stop_event = Event()
            self.session = session
            self.application_context = application_context

        def run(self):
            while not self.stop_event.is_set():
                blocks_range = session.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( application_context ) ).fetchone()
                (first_block, last_block) = blocks_range
                if last_block is None:
                    continue
                logger.info( "next blocks_range: {}\n".format( blocks_range ) )
                session.execute( "SELECT public.update_histogram( {}, {} )".format( first_block, last_block ) )
                session.commit()

        def stop(self):
            self.stop_event.set()

        def __enter__(self):
            self.start()
            return self

        def __exit__(self, *args, **kwargs):
            self.stop()
            self.join()

    return HafApp(session, application_context)


def wait_for_application_context(session, timeout=20):
    head_block = session.execute( "SELECT MAX(num) FROM hive.blocks_reversible").fetchone()[0]
    fork_id = session.execute( f"SELECT fork_id FROM hive.blocks_reversible WHERE num={head_block}").fetchone()[0]
    already_waited = 0
    while True:
        if session.execute( "SELECT current_block_num FROM hive.contexts").fetchone()[0] > head_block:
            if session.execute( f"SELECT fork_id FROM hive.contexts").fetchone()[0] == fork_id:
                break
        if timeout - already_waited <= 0:
            raise TimeoutError('Waited too long for switching forks')
        sleep_time = min(1.0, timeout)
        time.sleep(sleep_time)
        already_waited += sleep_time

    return already_waited
