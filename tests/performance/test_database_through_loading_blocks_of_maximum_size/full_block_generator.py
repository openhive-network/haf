from __future__ import annotations

import copy
import json
import os
from pathlib import Path
from shutil import rmtree
import requests
from typing import Final, Literal

from beekeepy import beekeeper_factory
from beekeepy.settings import Settings
from generate_block_log_with_varied_signature_types import CHAIN_ID, WITNESSES
from generate_operations import generate_blocks

import test_tools as tt

SIGNATURE_TYPE: Literal["open_sign", "single_sign", "multi_sign"] = "single_sign"
P2P_ENDPOINT = "0.0.0.0:2000"
BLOCK_LOG_DIRECTORY: Final[Path] = Path(__file__).parent / f"block_log_{SIGNATURE_TYPE}"

# Node parameters
SHARED_MEMORY_FILE_DIRECTORY: Final[str] = Path(__file__).parent/"generated"
SHARED_MEMORY_FILE_SIZE: Final[int] = 24
WEBSERVER_THREAD_POOL_SIZE: Final[int] = 16

# Processes parameters
SIGNING_MAX_WORKERS: Final[int] = 63
BROADCASTING_MAX_WORKERS: Final[int] = 16

# Block parameters
STOP_AT_BLOCK: int | None = None
OPERATIONS_IN_TRANSACTION: Final[int] = 1
# 37 (2325 trx for open_sign), 35 ( 2205 trx for single_sign ), 25 (1600 trx for multi_sign)
TRANSACTIONS_IN_ONE_BLOCK: Final[int] = SIGNING_MAX_WORKERS * 35
LOG_INTERVAL: Final[int] = 30


def full_block_generator(signature_type: Literal["open_sign", "multi_sign", "single_sign"]) -> None:
    generated_directory = Path(__file__).parent / "generated"
    if os.path.exists(generated_directory):
        rmtree(generated_directory)
    if not os.path.exists(generated_directory):
        os.makedirs(generated_directory)

    block_log = tt.BlockLog(BLOCK_LOG_DIRECTORY / "block_log")
    alternate_chain_spec_path = BLOCK_LOG_DIRECTORY / tt.AlternateChainSpecs.FILENAME
    tt.logger.info(f"Alternate chain spec path: {alternate_chain_spec_path}")

    node = tt.InitNode()
    node.config.p2p_endpoint = f"{P2P_ENDPOINT}"
    node.config.plugin.remove("account_by_key")
    node.config.plugin.remove("state_snapshot")
    node.config.plugin.remove("account_by_key_api")
    node.config.shared_file_size = f"{SHARED_MEMORY_FILE_SIZE}G"
    node.config.webserver_thread_pool_size = f"{WEBSERVER_THREAD_POOL_SIZE!s}"
    node.config.log_logger = (
        '{"name":"default","level":"info","appender":"stderr"} '
        '{"name":"user","level":"debug","appender":"stderr"} '
        '{"name":"chainlock","level":"error","appender":"p2p"} '
        '{"name":"sync","level":"debug","appender":"p2p"} '
        '{"name":"p2p","level":"info","appender":"p2p"}'
    )

    for witness in WITNESSES:
        key = tt.Account(witness).private_key
        node.config.witness.append(witness)
        node.config.private_key.append(key)

    node.run(
        replay_from=block_log,
        timeout=120,
        wait_for_live=True,
        alternate_chain_specs=tt.AlternateChainSpecs.parse_file(alternate_chain_spec_path),
        # Code needed if the script is running with real system time
        time_control=tt.StartTimeControl(start_time=block_log.get_head_block_time()),
        arguments=[f"--shared-file-dir={SHARED_MEMORY_FILE_DIRECTORY}", f"--chain-id={CHAIN_ID}"],
    )

    # Create and unlock wallets
    beekeeper = beekeeper_factory(settings=Settings(working_directory=tt.context.get_current_directory() / "beekeeper"))
    wallets = []
    tokens = []
    for _ in range(SIGNING_MAX_WORKERS):
        session = beekeeper.create_session()
        tokens.append(session.token)
        if _ == 0:
            wallets.append(session.create_wallet(name="my_only_wallet", password="my_password"))
            import_keys_to_beekeeper(wallets[-1], signature_type)
        else:
            wallets.append(session.open_wallet(name="my_only_wallet"))
            wallets[-1].unlock(password="my_password")

    # Create signing transactions
    generate_blocks(
        stop_at_block=STOP_AT_BLOCK,
        log_interval=LOG_INTERVAL,
        ops_in_one_element=OPERATIONS_IN_TRANSACTION,
        elements_number_for_iteration=TRANSACTIONS_IN_ONE_BLOCK,
        tokens=tokens,
        beekeeper_url=beekeeper._Beekeeper__instance.http_endpoint.as_string(),  # noqa: SLF001
        node=node,
        max_broadcast_workers=BROADCASTING_MAX_WORKERS,
        public_keys=get_public_keys(signature_type)["active"],
    )


def import_keys_to_beekeeper(wallet, signature_type: str) -> None:
    match signature_type:
        case "single_sign":
            for authority_type in ["owner", "active", "posting"]:
                wallet.import_key(private_key=tt.Account("account", secret=authority_type).private_key)
        case "multi_sign":
            for authority_type, num_keys in [("owner", 3), ("active", 6), ("posting", 10)]:
                for num in range(num_keys):
                    wallet.import_key(private_key=tt.Account("account", secret=f"{authority_type}-{num}").private_key)


def start_session(url, chunk_num):
    headers = {"Content-Type": "application/json"}
    template = {"jsonrpc": "2.0", "method": "", "params": {}, "id": 1}

    create_session = copy.deepcopy(template)
    create_session["method"] = "beekeeper_api.create_session"
    create_session["params"] = {"salt": chunk_num, "notifications_endpoint": url}
    response_token = requests.post(url, json=create_session, headers=headers)
    token = json.loads(response_token.text)["result"]["token"]

    unlock = copy.deepcopy(template)
    unlock["method"] = "beekeeper_api.unlock"
    unlock["params"] = {
        "token": token,
        "wallet_name": "my_only_wallet",
        "password": "my_password",
    }
    requests.post(url, json=unlock, headers=headers)

    return token


def get_public_keys(authority_type: Literal["open_sign", "multi_sign", "single_sign"]) -> dict[str:list]:
    match authority_type:
        case "open_sign":
            return {
                "owner": [],
                "active": [],
                "posting": [],
            }
        case "single_sign":
            return {
                "owner": [tt.Account("account", secret="owner").public_key[3:]],
                "active": [tt.Account("account", secret="active").public_key[3:]],
                "posting": [tt.Account("account", secret="posting").public_key[3:]],
            }
        case "multi_sign":
            return {
                "owner": [tt.Account("account", secret=f"owner-{num}").public_key[3:] for num in range(3)],
                "active": [tt.Account("account", secret=f"active-{num}").public_key[3:] for num in range(6)],
                "posting": [tt.Account("account", secret=f"posting-{num}").public_key[3:] for num in range(10)],
            }


if __name__ == "__main__":
    full_block_generator(SIGNATURE_TYPE)
