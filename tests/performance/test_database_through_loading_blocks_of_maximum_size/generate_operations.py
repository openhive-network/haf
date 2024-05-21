from __future__ import annotations

import copy
import json
import random
import time
from concurrent.futures import Future, ProcessPoolExecutor, as_completed
from functools import partial
from collections import OrderedDict

import requests
from generate_block_log_with_varied_signature_types import NUMBER_OF_ACCOUNTS, generate_random_text
from generate_transaction_template import SimpleTransaction, generate_transaction_template

import test_tools as tt
import wax
from schemas.operations.comment_operation import CommentOperation
from schemas.operations.comment_options_operation import CommentOptionsOperation
from schemas.operations.custom_json_operation import CustomJsonOperation
from schemas.operations.extensions.comment_options_extensions import BeneficiaryRoute, CommentPayoutBeneficiaries
from schemas.operations.representations import HF26Representation
from schemas.operations.transfer_operation import TransferOperation
from schemas.operations.vote_operation import VoteOperation


def draw_comment(comment_data: dict) -> tuple:
    permlink = random.choice(list(comment_data.keys()))
    account_name = comment_data[permlink]
    return permlink, account_name


def generate_random_custom_json_as_string():
    avg_json_elements_number = 3
    elements = random.randint(1, avg_json_elements_number * 2)
    output_as_string = "{"
    for it in range(elements):
        key_name = generate_random_text(3, random.randint(4, 15))
        value = generate_random_text(50, 1000) if it % 2 == 0 else random.randint(-1000000, 1000000)
        output_as_string += (
            '"' + key_name + '": ' + str(value) + ", "
            if isinstance(value, int)
            else '"' + key_name + '": "' + value + '", '
        )

    output_as_string = output_as_string[:-2]  # get rid of last comma and space
    output_as_string += "}"
    return output_as_string


def get_last_index_from(data_dict: dict) -> int:
    return int(max(data_dict.keys(), key=lambda x: int(x.split("-")[-1]))[
                   len(max(data_dict.keys(), key=lambda x: int(x.split("-")[-1]))) - 1])


def __prepare_operation(
        account_name: str, comment_data_per_chunk: dict, comment_data_for_current_iteration: dict, worker_num: int,
) -> VoteOperation | CommentOperation | CustomJsonOperation | TransferOperation | CommentOptionsOperation:
    operation_mapping = {
        range(0, 15): lambda: create_transfer(account_name),  # transfer 15%
        range(15, 25): lambda: create_vote(account_name, comment_data_per_chunk),  # vote 10%
        range(25, 35): lambda: create_comment_operation(account_name, comment_data_per_chunk,
                                                        comment_data_for_current_iteration, worker_num),  # comment 10%
        range(35, 101): lambda: create_custom_json(account_name),  # custom json 65%
    }
    random_number = random.randint(0, 100)
    for range_value, operation_func in operation_mapping.items():
        if random_number in range_value:
            return operation_func()


def create_transfer(from_account: str) -> TransferOperation:
    return TransferOperation(
        from_=from_account,
        to=from_account,
        amount=tt.Asset.Test(0.001),
        memo=generate_random_text(3, 200),
    )


def create_vote(account_name: str, comment_data: dict) -> VoteOperation:
    vote_weight = 0
    while vote_weight == 0:
        vote_weight = random.randint(-100, 100)

    permlink_to_vote_on, content_author = draw_comment(comment_data)
    return VoteOperation(voter=account_name, author=content_author, permlink=permlink_to_vote_on, weight=vote_weight)


def create_comment_operation(
        account_name: str, comment_data: dict, comment_data_for_current_iteration: dict, worker_num: int,

) -> CommentOperation:
    if account_name in comment_data.values():
        return []

    comment_body = generate_random_text(100, 1000)

    # 20% chance for creating new article instead of just reply
    if random.randint(0, 5) == 0:
        parent_comment_permlink = f"article-category-{comment_body[-10:]}"
        parent_author = ""
    else:
        parent_comment_permlink, parent_author = draw_comment(comment_data)
    index = (
        get_last_index_from(comment_data)
        if len(comment_data_for_current_iteration) == 0
        else (get_last_index_from(comment_data_for_current_iteration))
    )

    current_permlink = f"permlink-{worker_num}-{index + 1}"
    comment_data_for_current_iteration[current_permlink] = account_name

    return CommentOperation(
        parent_author=parent_author,
        parent_permlink=parent_comment_permlink,
        author=account_name,
        permlink=current_permlink,
        title=comment_body[:random.randint(5, 15)],
        body=comment_body,
        json_metadata="{}",
    )


def create_custom_json(account_name: str) -> CustomJsonOperation:
    return CustomJsonOperation(
        required_auths=[],
        required_posting_auths=[account_name],
        id_=generate_random_text(3, 32),
        json_=generate_random_custom_json_as_string(),
    )


def create_comment_options(
        account_name: str, comment_data_for_current_iteration: dict, worker_num: int,
) -> CommentOptionsOperation:
    # comment options is created only with article
    author_of_comment = account_name
    index = get_last_index_from(comment_data_for_current_iteration)
    permlink = f"permlink-{worker_num}-{index}"
    beneficiaries = []

    while len(beneficiaries) < 3:  # draw 3 accounts to be beneficiaries
        account_number = random.randint(0, NUMBER_OF_ACCOUNTS)
        beneficiary_name = f"account-{account_number}"
        for beneficiary in beneficiaries:
            # avoid duplicating beneficiary and making comment author as beneficiary
            if beneficiary in (beneficiary_name, account_name):
                continue
        beneficiaries.append(beneficiary_name)
    beneficiaries = sorted(beneficiaries)
    beneficiaries = [BeneficiaryRoute(account=beneficiary_name, weight=500) for beneficiary_name in beneficiaries]

    prepared_beneficiaries = CommentPayoutBeneficiaries(beneficiaries=beneficiaries)
    extensions = [{"type": "comment_payout_beneficiaries", "value": prepared_beneficiaries}]

    return CommentOptionsOperation(
        author=author_of_comment,
        permlink=permlink,
        max_accepted_payout=tt.Asset.Tbd(100),
        percent_hbd=10000,
        allow_votes=True,
        allow_curation_rewards=True,
        extensions=extensions,
    )


def generate_blocks(
        stop_at_block: int,
        log_interval: int,
        ops_in_one_element: int,
        elements_number_for_iteration,
        tokens: list[str],
        beekeeper_url: str,
        node: tt.InitNode,
        max_broadcast_workers: int,
        public_keys: list,
) -> list:
    """
    :param stop_at_block: The block where the program stops. If `None`, full blocks will be generated indefinitely,
    :param log_interval: The time interval between logging the parameters of sent transactions,
    :param ops_in_one_element: determines: how many operations will be inserted in every element of output list,
    :param elements_number_for_iteration: will add chosen amount of records to output list,
    :param tokens: beekeeper open session tokens,
    :param beekeeper_url: beekeeper application url address,
    :param node: witness node to which transactions will be sent,
    :param max_broadcast_workers: maximum number of workers sending transactions,
    :param public_keys: keys needed to sign sent transactions.
    """

    splitted_accounts = split_to_chunks(list(range(NUMBER_OF_ACCOUNTS)), max_broadcast_workers)
    operation_chunks = split_to_chunks(list(range(elements_number_for_iteration)), max_broadcast_workers)

    with ProcessPoolExecutor(max_workers=len(tokens)) as executor:
        main_iteration = 0
        start_time = time.time()
        operation_counter: dict = {"comment": 0, "custom_json": 0, "transfer": 0, "vote": 0}
        comment_data = {key: OrderedDict({f"permlink-{index}": f"account-{index}" for index in range(100_000)}) for key
                        in range(16)}

        assert len(splitted_accounts) == len(operation_chunks)

        while True:
            block = []

            operations_futures: list[Future] = []
            for worker_num, (chunk, account_range) in enumerate(
                    zip(operation_chunks, splitted_accounts)
            ):
                operations_futures.append(
                    executor.submit(
                        generate_chunk_of_operations,
                        chunk,
                        comment_data[worker_num],
                        ops_in_one_element,
                        account_range.copy(),
                        worker_num,
                    )
                )

            results = {}
            comments_created_during_current_iteration = OrderedDict()
            for future in as_completed(operations_futures):
                results.update(future.result())
            for worker_number in results:
                block.extend(results[worker_number][0])  # add to block futures transactions
                comments_created_during_current_iteration.update({worker_number: results[worker_number][1]})
            operations_futures.clear()

            for transactions in block:
                for operation in transactions:
                    operation_name = operation.get_name()
                    if operation_name in operation_counter:
                        operation_counter[operation_name] += 1
                    else:
                        operation_counter[operation_name] = 1

            # sign and create transaction section
            gdpo = node.api.database.get_dynamic_global_properties()
            node_config = node.api.database.get_config()
            chunks = split_to_chunks(block, len(tokens))
            sign_futures: list[Future] = []
            for chunk, token in zip(chunks, tokens):
                sign_futures.append(
                    executor.submit(
                        sign,
                        gdpo,
                        node_config,
                        beekeeper_url,
                        chunk,
                        token,
                        public_keys,
                    )
                )
            results = [None] * len(chunks)
            for future in as_completed(sign_futures):
                index = sign_futures.index(future)
                results[index] = future.result()
            sign_futures.clear()

            # broadcasting section
            broadcast_futures: list[Future] = []
            to_broadcast = [item for sublist in results for item in sublist]

            r = list(map(wrap_in_send_pack, to_broadcast))
            length = len(r)
            size = length // max_broadcast_workers
            remainder = length % max_broadcast_workers
            broadcast = [
                r[i * size + min(i, remainder): (i + 1) * size + min(i + 1, remainder)]
                for i in range(max_broadcast_workers)
            ]

            processor = BroadcastTransactionsChunk()
            single_transaction_broadcast_with_address = partial(
                processor.broadcast_chunk_of_transactions, init_node_address=node.http_endpoint
            )
            broadcast_futures.extend(list(executor.map(single_transaction_broadcast_with_address, broadcast)))
            broadcast_futures.clear()

            for num in comment_data:
                comment_data[num].update(comments_created_during_current_iteration[num])
                for _ in range(len(comments_created_during_current_iteration[num])):
                    comment_data[num].popitem(last=False)

            if main_iteration == stop_at_block:
                executor.shutdown(cancel_futures=False, wait=True)
                tt.logger.info(f"Finishing generate full block at block {node.get_last_block_number()}.")
                return
            if node.get_last_block_number() % 10 == 0 or time.time() - start_time > log_interval:
                tt.logger.info(
                    f"Operations generated from last 10 blocks: {sum(operation_counter.values())},"
                    f" {dict(sorted(operation_counter.items(), key=lambda x: x[0]))}")
                start_time = time.time()
                operation_counter.clear()

            main_iteration += 1


def split_to_chunks(input_list, num_parts):
    part_length = len(input_list) // num_parts
    remainder = len(input_list) % num_parts
    return [
        input_list[i * part_length + min(i, remainder): (i + 1) * part_length + min(i + 1, remainder)]
        for i in range(num_parts)
    ]


def generate_chunk_of_operations(
        elements_number_for_iteration: list[int],
        comment_data_per_chunk: OrderedDict,
        ops_in_one_element: int,
        accounts: list[int],
        worker_num: int,
):
    comment_data_for_current_iteration = {}
    account_it = random.choice(accounts)

    list_of_trx = []
    for _ in elements_number_for_iteration:
        operations_in_transaction: list = []
        for __ in range(ops_in_one_element):
            if account_it >= accounts[-1]:
                account_it = accounts[0]
            generated_op = __prepare_operation(
                f"account-{account_it}", comment_data_per_chunk, comment_data_for_current_iteration, worker_num)
            if generated_op == []:
                account_it += 1
                continue

            operations_in_transaction.append(generated_op)

            # add comment options to new article
            if generated_op.get_name() == "comment":
                comment_data_for_current_iteration[generated_op.permlink] = f"account-{account_it}"
                if generated_op.get_name() == "comment" and generated_op.parent_author == "":
                    operations_in_transaction.append(
                        create_comment_options(f"account-{account_it}", comment_data_for_current_iteration, worker_num)
                    )

            account_it += 1
        if len(operations_in_transaction) > 0:
            list_of_trx.append(operations_in_transaction)
    return {worker_num: (list_of_trx, comment_data_for_current_iteration)}


class BroadcastTransactionsChunk:
    @staticmethod
    def broadcast_chunk_of_transactions(chunk: list[dict], init_node_address: str) -> None:
        remote_node = tt.RemoteNode(http_endpoint=init_node_address)
        for trx in chunk:
            requests.post(remote_node.http_endpoint.as_string(), json=trx, headers={"Content-Type": "application/json"})


def wrap_in_send_pack(transaction) -> dict:
    template = {
        "jsonrpc": "2.0",
        "method": "network_broadcast_api.broadcast_transaction",
        "params": {},
        "id": 0,
    }

    message = copy.deepcopy(template)
    if isinstance(transaction, bytes):
        message["params"] = {"trx": json.loads(wax.deserialize_transaction(transaction).result.decode("ascii"))}
    else:
        message["params"] = {"trx": transaction.dict()}
    return message


def sign(gdpo, node_config, url, chunk, token, public_keys):
    singed_chunks = []
    for operation in chunk:
        try:
            trx = create_and_sign_transaction(
                operation, gdpo, node_config, url, token, public_keys, binary_transaction=True
            )
            singed_chunks.append(trx)
        except:  # noqa: PERF203, E722
            tt.logger.info("Fail in create transaction")
    return singed_chunks


def create_and_sign_transaction(
        operations: list, gdpo, node_config, url, token, public_keys, binary_transaction: bool = False
):
    trx: SimpleTransaction = generate_transaction_template(gdpo)

    # fixme:  workaround - problem with serialization field `json_` in CustomJsonOperation
    for operation in operations:
        if isinstance(operation, CustomJsonOperation):
            operation.json_ = json.dumps(operation.json_)

    trx.operations.extend([HF26Representation(type=op.get_name_with_suffix(), value=op) for op in operations])
    if len(public_keys) != 0:
        headers = {"Content-Type": "application/json"}

        for key in public_keys:
            sig_digest_pack = {
                "jsonrpc": "2.0",
                "method": "beekeeper_api.sign_digest",
                "params": {
                    "token": token,
                    "sig_digest": "",
                    "public_key": key,
                },
                "id": 1,
            }

            sig_digest = wax.calculate_sig_digest(
                trx.json(by_alias=True).encode("ascii"), node_config.HIVE_CHAIN_ID.encode("ascii")
            ).result.decode("ascii")
            sig_digest_pack["params"]["sig_digest"] = sig_digest
            response_sig_digest = requests.post(url, json=sig_digest_pack, headers=headers)
            signature = json.loads(response_sig_digest.text)["result"]["signature"]
            trx.signatures.append(signature)
    if binary_transaction:
        trx = wax.serialize_transaction(trx.json(by_alias=True).encode("ascii")).result
    return trx