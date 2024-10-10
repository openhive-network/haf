import datetime

import test_tools as tt

from haf_local_tools.haf_node import HafNode
from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround


def prepare_network_with_init_node_and_haf_node(witnesses: str):
    witness_node = tt.RawNode()
    witness_node.config.witness = witnesses
    witness_node.config.private_key = '5JNHfZYKGaomSFvd4NUdQ9qMcEAC43kujbfjueTHpVapX1Kzq2n'
    witness_node.config.shared_file_size = '2G'
    witness_node.config.enable_stale_production = True
    witness_node.config.required_participation = 0
    witness_node.config.plugin = 'database_api witness'
    apply_block_log_type_to_monolithic_workaround(witness_node)

    haf_node = HafNode(keep_database=True)
    haf_node.config.shared_file_size = '6G'

    return witness_node, haf_node
