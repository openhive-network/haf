from datetime import datetime, timezone
import time
import json

from test_tools import logger, Wallet, BlockLog, Account

from witnesses import alpha_witness_names, beta_witness_names


BLOCKS_IN_FORK = 5
WAIT_FOR_FORK_TIMEOUT = 60.0


def make_fork(world, main_chain_trxs=[], fork_chain_trxs=[]):
    alpha_net = world.network('Alpha')
    beta_net = world.network('Beta')
    alpha_witness_node = alpha_net.node('WitnessNode0')
    beta_witness_node = beta_net.node(name='WitnessNode0')

    logger.info(f'Making fork at block {get_head_block(alpha_witness_node)}')

    main_chain_wallet = Wallet(attach_to=alpha_witness_node)
    fork_chain_wallet = Wallet(attach_to=beta_witness_node)
    fork_block = get_head_block(beta_witness_node)
    head_block = fork_block
    alpha_net.disconnect_from(beta_net)
    for wallet in [main_chain_wallet, fork_chain_wallet]:
        import_witnesses_keys(wallet)

    for trx in main_chain_trxs:
        main_chain_wallet.api.sign_transaction(trx)
    for trx in fork_chain_trxs:
        fork_chain_wallet.api.sign_transaction(trx)

    for node in [alpha_witness_node, beta_witness_node]:
        node.wait_for_block_with_number(head_block + BLOCKS_IN_FORK)


def back_from_fork(world):
    alpha_net = world.network('Alpha')
    beta_net = world.network('Beta')
    node_under_test = world.network('Beta').node('NodeUnderTest')
    alpha_net.connect_with(beta_net)
    waited = wait_for_back_from_fork(node_under_test)
    logger.info(f'Switched to different work after {waited} seconds')

    head_block = get_head_block(node_under_test)
    return head_block


def wait_for_back_from_fork(node, timeout=WAIT_FOR_FORK_TIMEOUT):
    already_waited = 0
    while not switched_fork(node):
        if timeout - already_waited <= 0:
            raise TimeoutError('Waited too long for switching forks')

        sleep_time = min(1.0, timeout)
        time.sleep(sleep_time)
        already_waited += sleep_time

    return already_waited


def switched_fork(node):
    # TODO use notification system when it is ready instead of parsing stderr
    with open(node.directory / 'stderr.txt') as node_stderr:
        for line in node_stderr:
            if 'Switching to fork' in line:
                return True

    return False


def import_witnesses_keys(wallet):
    for name in alpha_witness_names:
        wallet.api.import_key(Account(name).private_key)
    for name in beta_witness_names:
        wallet.api.import_key(Account(name).private_key)


def wait_for_irreversible_progress(node, block_num):
    logger.info(f'Waiting for progress of irreversible block')
    head_block = get_head_block(node)
    irreversible_block = get_irreversible_block(node)
    logger.info(f"Current head_block_number: {head_block}, irreversible_block_num: {irreversible_block}")
    while irreversible_block < block_num:
        node.wait_for_block_with_number(head_block+1)
        head_block = get_head_block(node)
        irreversible_block = get_irreversible_block(node)
        logger.info(f"Current head_block_number: {head_block}, irreversible_block_num: {irreversible_block}")
    return irreversible_block, head_block


def get_head_block(node):
    head_block_number = node.api.database.get_dynamic_global_properties()["head_block_number"]
    return head_block_number


def get_irreversible_block(node):
    irreversible_block_num = node.api.database.get_dynamic_global_properties()["last_irreversible_block_num"]
    return irreversible_block_num


def get_timestamp_from_file(name):
    timestamp = ''
    with open(name, 'r') as f:
        timestamp = f.read()
    timestamp = timestamp.strip()
    return timestamp


def run_networks(world, blocklog_directory):
    timestamp = ''
    with open(blocklog_directory/'timestamp', 'r') as f:
        timestamp = f.read()

    block_log = BlockLog(None, blocklog_directory/'block_log', include_index=False)

    logger.info('Running nodes...')
    world.run_all_nodes(block_log, timestamp=timestamp, speedup=3, wait_for_live=True)


def create_node_with_database(network, url):
    api_node = network.create_api_node()
    api_node.config.plugin.append('sql_serializer')
    api_node.config.psql_url = str(url)
    return api_node


def get_account_history(session, Base, name, reversible=False):
    if reversible:
        accounts = Base.classes.accounts_reversible
        account_operations = Base.classes.account_operations_reversible
        operations = Base.classes.operations_reversible
    else:
        accounts = Base.classes.accounts
        account_operations = Base.classes.account_operations
        operations = Base.classes.operations

    account = session.query(accounts).filter(accounts.name == name).one_or_none()
    if account == None:
        return []

    id = account.id
    acc_ops = session.query(account_operations).\
        filter(account_operations.account_id == id).\
        order_by(account_operations.account_op_seq_no).all()
    types = []
    for acc_op in acc_ops:
        operation_id = acc_op.operation_id
        op = session.query(operations).filter(operations.id==operation_id).one()
        types.append(json.loads(op.body)['type'])

    return types
