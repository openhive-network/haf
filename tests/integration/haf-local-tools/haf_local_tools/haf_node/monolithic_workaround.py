from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from test_tools.__private.user_handles.handles.node_handles.runnable_node_handle import RunnableNodeHandle

def apply_block_log_type_to_monolithic_workaround(node: RunnableNodeHandle) -> None:
    # MORE INFO: hive/tests/python/hive-local-tools/test-tools/package/test_tools/__private/node.py (class Node, block_log property)
    node.config.block_log_split = -1
