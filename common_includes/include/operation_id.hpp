#pragma once

#include <cstdint>

// These type aliases are kept for asset_unique_id.hpp compatibility.
// The operation_id encoding (block_num << 32 | pos) has been removed;
// operations are now identified by (block_num, op_pos_in_block) composite key.
using OperationId = uint64_t;
using OperationPositionInBlock = uint32_t;
using OperationBlockNum = uint32_t;
