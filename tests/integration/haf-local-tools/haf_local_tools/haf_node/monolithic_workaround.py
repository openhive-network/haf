from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from test_tools.__private.user_handles.handles.node_handles.runnable_node_handle import RunnableNodeHandle

def apply_block_log_type_to_monolithic_workaround(node: RunnableNodeHandle) -> None:
    # MORE INFO: https://gitlab.syncad.com/hive/test-tools/-/blob/3b0a51cb93802e02a2fd3643c6b7d801c07acbc7/package/test_tools/__private/node.py#L141
    node.config.block_log_split = -1
