import test_tools as tt
from pathlib import Path
from haf_local_tools.system.haf.mirrornet.constants import SKELETON_KEY

CHAIN_ID: str = "44"

def test_generate_block_log_for_testing_denser(mirrornet_witness_node):
    block_log_5m_path = Path("/home/dev/block_log_chain_id_44/blockchain/block_log")
    block_log_5m = tt.BlockLog(block_log_5m_path)

    mirrornet_witness_node.run(
        replay_from=block_log_5m,
        time_control=tt.StartTimeControl(start_time="head_block_time", speed_up_rate=25),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID, "--skeleton-key", SKELETON_KEY],
    )

    wallet = tt.Wallet(attach_to=mirrornet_witness_node, additional_arguments=[f"--chain-id={CHAIN_ID}"])

    # create accounts
    for account_name in [f"denserautotest{index}" for index in range(5)]:
        wallet.api.create_account_with_keys("blocktrades", account_name, "",
                                            owner=tt.Account(account_name, secret="owner").public_key,
                                            active=tt.Account(account_name, secret="active").public_key,
                                            posting=tt.Account(account_name, secret="posting").public_key,
                                            memo=tt.Account(account_name, secret="memo").public_key,
                                            )
        with open("block_log_specification.txt", "a") as file:
            for key_type in ["owner", "active", "posting", "memo"]:
                key = tt.Account(account_name, secret=key_type).private_key
                file.write(f"account_name: {account_name}, private_{key_type}: {key}\n")
                wallet.api.import_key(key)
            file.write("-" * 95 + 2 * "\n")

    # fund_accounts
    with wallet.in_single_transaction():
        for account, amount in [("denserautotest1", 1), ("denserautotest3", 1_000), ("denserautotest4", 100)]:
            wallet.api.transfer("blocktrades", account, tt.Asset.Hive(amount), "memo")
            wallet.api.transfer("blocktrades", account, tt.Asset.Hbd(amount), "memo")
            wallet.api.transfer_to_vesting("blocktrades", account, tt.Asset.Hive(amount))

    # create_posts
    for post_num in range(40):
        wallet.api.post_comment("denserautotest4", f"post-test-{post_num}", "", "someone0", f"test-title-{post_num}",
                                f"content Test {post_num} numer", "{}")
        tt.logger.info(f"Post {post_num} created. Wait...")
        mirrornet_witness_node.wait_number_of_blocks(21 * 5)  # wait HIVE_MIN_ROOT_COMMENT_INTERVAL ( 5 min )

    mirrornet_witness_node.wait_for_irreversible_block()
    mirrornet_witness_node.block_log.copy_to(Path(__file__).parent)
