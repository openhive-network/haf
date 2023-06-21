from sqlalchemy.orm.session import sessionmaker
import threading
import subprocess

import test_tools as tt

from haf_local_tools import wait_for_irreversible_progress, get_irreversible_block, create_app
from haf_local_tools import get_head_block
from haf_local_tools.tables import BlocksReversible, IrreversibleData

from haf_local_tools.system.haf import (
    assert_are_blocks_sync_with_haf_db,
    assert_are_indexes_restored,
    connect_nodes,
    prepare_and_send_transactions,
)
from haf_local_tools import make_fork, wait_for_irreversible_progress


#replay_all_nodes==false and TIMEOUT==300s therefore START_TEST_BLOCK has to be less than 100 blocks 
START_TEST_BLOCK = 50

CONTEXT_ATTACH_BLOCK = 40
APPLICATION_CONTEXT = "trx_histogram"


def update_app_continuously(session, application_context, cycles):
    for i in range(cycles):
        blocks_range = session.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( application_context ) ).fetchone()
        (first_block, last_block) = blocks_range
        if last_block is None:
            continue
        tt.logger.info( "next blocks_range: {}\n".format( blocks_range ) )
        session.execute( "SELECT public.update_histogram( {}, {} )".format( first_block, last_block ) )
        session.commit()
        ctx_stats = session.execute( "SELECT current_block_num, irreversible_block FROM hive.contexts WHERE NAME = '{}'".format( application_context ) ).fetchone()
        tt.logger.info(f'ctx_stats-update-app: cbn {ctx_stats[0]} irr {ctx_stats[1]}')
    assert cycles>0
    return blocks_range


def get_events_id(session, application_context):
    query = "select events_id from hive.contexts;"
    eid = session.execute(query).fetchone()
    return eid


def test_double_production_failing(prepared_networks_and_database_12_8_with_double_production, extra_witnesses):
    tt.logger.info(f'Start test_double_production')


    #What is tested?
# update?        #UPDATE hive.contexts
        #SET irreversible_block = _new_irreversible_block
        #WHERE current_block_num <= irreversible_block;
    #(SQL function: hive.remove_obsolete_reversible_data)

    #Important:
    #The value of `current_block_num` has to be less than `irreversible_block`.

    #Scenario
    #A context executes some `hive.app_next_block` and after that stays in 'broken' state. It means, that a context is still attached, but nothing happens.

    #Result
    #Finally a value of `irreversible_block` for given context has to be equal to current value of `irreversible_block` in HAF.


    # GIVEN
    networks_builder, sessions = prepared_networks_and_database_12_8_with_double_production

    session_0 = sessions[0]
    session_1 = sessions[1]

    tt.logger.info(f"{session_0=}")
    tt.logger.info(f"{session_0.get_bind()=}")
    tt.logger.info(f"{session_0.get_bind().url=}")
    url_0 = session_0.get_bind().url
    url_1 = session_1.get_bind().url

    subprocess.check_call(f'psql {url_0} -c "create extension intarray;" ', shell=True)
    # subprocess.check_call(f'psql {url_1} -c "create extension intarray;" ', shell=True)
    # from time import sleep

    # sleep(6)
    subprocess.check_call(f'docker run -v /var/run/postgresql/.s.PGSQL.5432:/var/run/postgresql/.s.PGSQL.5432 registry.gitlab.syncad.com/hive/hivemind/instance:instance-1241ff5aab7a175a1112908392509ac1a2d4e627 --test-max-block=50 --database-url={url_0}', shell=True)
    # subprocess.check_call(f'docker run -v /var/run/postgresql/.s.PGSQL.5432:/var/run/postgresql/.s.PGSQL.5432 registry.gitlab.syncad.com/hive/hivemind/instance:instance-1241ff5aab7a175a1112908392509ac1a2d4e627 --test-max-block=50 --database-url={url_1}', shell=True)

    subprocess.check_call(f'docker run -dit -v /var/run/postgresql/.s.PGSQL.5432:/var/run/postgresql/.s.PGSQL.5432 registry.gitlab.syncad.com/hive/hivemind/instance:instance-1241ff5aab7a175a1112908392509ac1a2d4e627 --database-url={url_0}', shell=True)
    # subprocess.check_call(f'docker run -dit -v /var/run/postgresql/.s.PGSQL.5432:/var/run/postgresql/.s.PGSQL.5432 registry.gitlab.syncad.com/hive/hivemind/instance:instance-1241ff5aab7a175a1112908392509ac1a2d4e627 --database-url={url_1}', shell=True)

    # create_app(session_0, APPLICATION_CONTEXT)




    init_node = networks_builder.networks[0].node('InitNode0')
    witness_node_0 = networks_builder.networks[0].node('WitnessNode0')
    witness_node_1 = networks_builder.networks[1].node('WitnessNode1')
    api_node_0 = networks_builder.networks[0].node('ApiNode0')
    api_node_1 = networks_builder.networks[1].node('ApiNode1')
    alpha_net = networks_builder.networks[0]
    beta_net = networks_builder.networks[1]

    # WHEN
    witness_node_0.wait_for_block_with_number(START_TEST_BLOCK)

    wallet_init = tt.Wallet(attach_to=init_node)
    wallet_0 = tt.Wallet(attach_to=api_node_0)
    wallet_1 = tt.Wallet(attach_to=api_node_1)

    PUBLIC_KEY = tt.Account('random').public_key

    # init_node.api.witness.disable_fast_confirm()
    # witness_node_0.api.witness.disable_fast_confirm()
    # witness_node_1.api.witness.disable_fast_confirm()


    # tt.logger.info(f"{extra_witnesses=}")
    # with wallet_0.in_single_transaction():
    #     for witness_name in extra_witnesses:
    #         tt.logger.info(f"updating {witness_name=}")
    #         wallet_0.api.update_witness(witness_name, "", PUBLIC_KEY, {"account_creation_fee": tt.Asset.Test(3), "maximum_block_size": 65536, "sbd_interest_rate": 0})
    # wallet_0.close()
    # with wallet_0.in_single_transaction():
    #     for witness_name in extra_witnesses[10:]:
    #         tt.logger.info(f"updating {witness_name=}")
    #         wallet_0.api.update_witness(witness_name, "", PUBLIC_KEY, {"account_creation_fee": tt.Asset.Test(3), "maximum_block_size": 65536, "sbd_interest_rate": 0})
    w = "witness2-alpha"
    tt.logger.info(f"{w=}")
    wallet_0.api.update_witness(w, "", PUBLIC_KEY, {"account_creation_fee": tt.Asset.Test(3), "maximum_block_size": 65536, "sbd_interest_rate": 0})

    key_change_head = get_head_block(witness_node_0)
    tt.logger.info(f"{key_change_head=}")
    def restrict_connections(node_with_restrictions, allowed_nodes):
        ids = [node.api.network_node.get_info()["node_id"] for node in allowed_nodes]
        node_with_restrictions.api.network_node.set_allowed_peers(allowed_peers=ids)


    # first_block, last_block = update_app_continuously(session_0, APPLICATION_CONTEXT, 125)
    # while first_block is None or first_block <= 137:
    #     first_block, last_block = update_app_continuously(session_0, APPLICATION_CONTEXT, 1)
    #     tt.logger.info(f"{first_block=} {last_block=}")

    restrict_connections(init_node, [api_node_0])

    # sleep(120)
    tt.logger.info(f"before block 137")
    init_node.wait_for_block_with_number(137)
    witness_node_0.wait_for_block_with_number(137)
    witness_node_1.wait_for_block_with_number(137)
    # api_node_0.wait_for_block_with_number(137)



    tt.logger.info(f"block 137")
    init_node.wait_for_block_with_number(138)
    witness_node_0.wait_for_block_with_number(138)
    witness_node_1.wait_for_block_with_number(138)

    # first_block, last_block = update_app_continuously(session_0, APPLICATION_CONTEXT, 1)
    # while first_block is None or first_block < 138:
    #     first_block, last_block = update_app_continuously(session_0, APPLICATION_CONTEXT, 1)
    #     tt.logger.info(f"{first_block=} {last_block=}")
    # api_node_0.wait_for_block_qwith_number(138)
    tt.logger.info(f"block 138")


    def f_init():
        wallet_init = tt.Wallet(attach_to=init_node)
        wallet_init.api.create_account("initminer", "aliceinit", "{}")
    def f_0():
        wallet_0 = tt.Wallet(attach_to=api_node_0)
        wallet_0.api.create_account("initminer", "alice0", "{}")
    def f_1():
        wallet_1 = tt.Wallet(attach_to=api_node_1)
        wallet_1.api.create_account("initminer", "alice1", "{}")

    # restrict_connections(init_node, [api_node_0])
    # restrict_connections(api_node_0, [init_node])

    tt.logger.info(f"before trxs send")
    t_init = threading.Thread(target=f_init)
    t_0 = threading.Thread(target=f_0)
    t_1 = threading.Thread(target=f_1)
    t_init.start()
    t_0.start()
    t_1.start()
    t_init.join()
    t_0.join()
    t_1.join()
    tt.logger.info(f"after trxs send")



    from datetime import datetime, timedelta
    from time import sleep
    start = datetime.now()
    while datetime.now() < start + timedelta(seconds=60):
        tt.logger.info(f"{get_events_id(session_0, 'hivemind')=}")
        # first_block, last_block = update_app_continuously(session_0, APPLICATION_CONTEXT, 1)
        # tt.logger.info(f"{first_block=} {last_block=}")
        sleep(2)

    witness_node_0.wait_for_block_with_number(139)
    # witness_node_1.wait_for_block_with_number(139)
    # restrict_connections(api_node_0, [])

    # first_block, last_block = update_app_continuously(session_0, APPLICATION_CONTEXT, 1)
    # tt.logger.info(f"{first_block=} {last_block=}")



    witness_node_0.wait_for_block_with_number(169)


    start = datetime.now()
    while datetime.now() < start + timedelta(seconds=60):
        tt.logger.info(f"{get_events_id(session_0, 'hivemind')=}")
        # first_block, last_block = update_app_continuously(session_0, APPLICATION_CONTEXT, 1)
        # tt.logger.info(f"{first_block=} {last_block=}")
        sleep(2)
    return


    tt.logger.info(f"block 138")
    tt.logger.info(f"before trxs send")
    restrict_connections(init_node, [api_node_0])
    restrict_connections(api_node_0, [init_node])
    restrict_connections(api_node_0, [])
    # alpha_net.disconnect_from(beta_net)
    # restrict_connections(api_node_0, init_node)

    # wallet_0.api.create_account("initminer", "alice", "{}")
    tt.logger.info(f"before trxs send")
    def f_init():
        wallet_init.api.create_account("initminer", "aliceinit", "{}")
    def f_0():
        wallet_0.api.create_account("initminer", "alice0", "{}")
    def f_1():
        wallet_1.api.create_account("initminer", "alice1", "{}")
    t_init = threading.Thread(target=f_init)
    t_0 = threading.Thread(target=f_0)
    t_1 = threading.Thread(target=f_1)
    t_init.start()
    t_0.start()
    t_1.start()
    t_init.join()
    t_0.join()
    t_1.join()
    tt.logger.info(f"after trxs send")
    init_node.wait_for_block_with_number(139)
    witness_node_0.wait_for_block_with_number(140)
    witness_node_1.wait_for_block_with_number(140)
    tt.logger.info(f"got block 140")

    tt.logger.info(f"will update_app_continuously")
    update_app_continuously(session_0, APPLICATION_CONTEXT, 19)
    tt.logger.info(f"did update_app_continuously")

    restrict_connections(api_node_0, [])

    api_node_0.wait_for_next_fork(timeout=threading.TIMEOUT_MAX)

    tt.logger.info(f"networks reconnected")
    update_app_continuously(session_0, APPLICATION_CONTEXT, 10)
    # tt.logger.info(f"update_app_continuously more")
    # update_app_continuously(session_0, APPLICATION_CONTEXT, 1)
    # update_app_continuously(session_0, APPLICATION_CONTEXT, 1)
    # update_app_continuously(session_0, APPLICATION_CONTEXT, 1)
    # update_app_continuously(session_0, APPLICATION_CONTEXT, 1)
    # tt.logger.info(f"update_app_continuously more more")
    # update_app_continuously(session_0, APPLICATION_CONTEXT, 30)


    from time import sleep
    sleep(60)


    # restrict_connections(init_node, api_node_0)
    # restrict_connections(init_node, api_node_0)
    # init_node.api.network_node.set_allowed_peers(allowed_peers=[])
    # api_node_0.api.network_node.set_allowed_peers(allowed_peers=[])


    # alpha_net.connect_with(beta_net)


    # restrict_connections(api_node_0, witness_node_1)
    # api_node_0.wait_for_next_fork(timeout=threading.TIMEOUT_MAX)
    # sleep(60)

    # alpha_net.connect_with(beta_net)


    # sleep(60)4a1e75065e005b65dce52f892ece33be29c69 ...[0;mIMEOUT_MAX)

    # sleep(60)
    # alpha_net.connect_with(beta_net)
    # sleep(60)
    # make fork

    # transaction1 = wallet_0.api.transfer('initminer', 'null', tt.Asset.Test(2345), 'memo', broadcast=False)
    # transaction2 = wallet_1.api.transfer_to_vesting('initminer', 'null', tt.Asset.Test(2345), broadcast=False)
    # after_fork_block = make_fork(
    #     networks_builder.networks,
    #     main_chain_trxs=[transaction1],
    #     fork_chain_trxs=[transaction2],
    # )

    # witness_node_0.wait_for_irreversible_block()
    # witness_node_1.wait_for_irreversible_block()
    # from time import sleep

    # sleep(60)


    # update_app_continuously(session_0, APPLICATION_CONTEXT, 150)
    # update_app_continuously(session_1, APPLICATION_CONTEXT, 150)

    # update_app_continuously(session_0, APPLICATION_CONTEXT, 150)
    # update_app_continuously(session_1, APPLICATION_CONTEXT, 150)
    # system under test
    # create_app(second_session, APPLICATION_CONTEXT)

    # blocks_range = session.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()
    # (first_block, last_block) = blocks_range
    # # Last event in `events_queue` == `NEW_IRREVERSIBLE` (before it was `NEW_BLOCK`) therefore first call `hive.app_next_block` returns {None, None}
    # if first_block is None:
    #     blocks_range = session.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()
    #     (first_block, last_block) = blocks_range

    # tt.logger.info(f'first_block: {first_block}, last_block: {last_block}')

    # ctx_stats = session.execute( "SELECT current_block_num, irreversible_block FROM hive.contexts WHERE NAME = '{}'".format( APPLICATION_CONTEXT ) ).fetchone()
    # tt.logger.info(f'ctx_stats-before-detach: cbn {ctx_stats[0]} irr {ctx_stats[1]}')

    # session.execute( "SELECT hive.app_context_detach( '{}' )".format( APPLICATION_CONTEXT ) )
    # session.execute( "SELECT public.update_histogram( {}, {} )".format( first_block, CONTEXT_ATTACH_BLOCK ) )
    # session.execute( "SELECT hive.app_context_attach( '{}', {} )".format( APPLICATION_CONTEXT, CONTEXT_ATTACH_BLOCK ) )
    # session.commit()

    # ctx_stats = session.execute( "SELECT current_block_num, irreversible_block FROM hive.contexts WHERE NAME = '{}'".format( APPLICATION_CONTEXT ) ).fetchone()
    # tt.logger.info(f'ctx_stats-after-attach: cbn {ctx_stats[0]} irr {ctx_stats[1]}')

    # # THEN
    # nr_cycles = 10
    # update_app_continuously(second_session, APPLICATION_CONTEXT, nr_cycles)
    # wait_for_irreversible_progress(node_under_test, START_TEST_BLOCK)

    # ctx_stats = session.execute( "SELECT current_block_num, irreversible_block FROM hive.contexts WHERE NAME = '{}'".format( APPLICATION_CONTEXT ) ).fetchone()
    # tt.logger.info(f'ctx_stats-after-waiting: cbn {ctx_stats[0]} irr {ctx_stats[1]}')

    # # application is not updated (=broken)
    # wait_for_irreversible_progress(node_under_test, START_TEST_BLOCK+3)

    # ctx_stats = session.execute( "SELECT current_block_num, irreversible_block FROM hive.contexts WHERE NAME = '{}'".format( APPLICATION_CONTEXT ) ).fetchone()
    # tt.logger.info(f'ctx_stats-after-waiting-2: cbn {ctx_stats[0]} irr {ctx_stats[1]}')

    # irreversible_block = get_irreversible_block(node_under_test)
    # tt.logger.info(f'irreversible_block {irreversible_block}')

    # haf_irreversible = session.query(IrreversibleData).one()
    # tt.logger.info(f'consistent_block {haf_irreversible.consistent_block}')

    # context_irreversible_block = session.execute( "SELECT irreversible_block FROM hive.contexts WHERE NAME = '{}'".format( APPLICATION_CONTEXT ) ).fetchone()[0]
    # tt.logger.info(f'context_irreversible_block {context_irreversible_block}')

    # assert irreversible_block == haf_irreversible.consistent_block
    # assert irreversible_block == context_irreversible_block

    # assert irreversible_block == haf_irreversible.consistent_block

    # blks = session.query(BlocksReversible).order_by(BlocksReversible.num).all()
    # if len(blks) == 0:
    #     tt.logger.info(f'OBI can make an immediate irreversible block, so all reversible data can be cleared out')
    # else:
    #     block_min = min([block.num for block in blks])
    #     tt.logger.info(f'min of blocks_reversible is {block_min}')
    #     assert irreversible_block == block_min

