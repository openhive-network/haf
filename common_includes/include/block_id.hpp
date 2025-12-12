#pragma once

#include <cstdint>
#include <limits>

#include <fc/exception/exception.hpp>

// Use HafBlockId to avoid collision with PostgreSQL's BlockId type
using HafBlockId = int64_t;
using HafBlockNum = int32_t;
using HafForkId = int64_t;

// block_id encoding:
// msb.....................lsb
// || block_num | fork_id ||
// ||   32b     |   32b   ||

inline HafBlockId
make_haf_block_id( HafBlockNum _block_num, HafForkId _fork_id ) {
    constexpr auto FORK_ID_LIMIT = std::numeric_limits< uint32_t >::max(); // 2^32-1
    constexpr auto BLOCK_NUM_LIMIT = std::numeric_limits< int32_t >::max(); // ignore complement code bit
    FC_ASSERT( _fork_id >= 0 && static_cast<uint64_t>(_fork_id) <= FORK_ID_LIMIT, "Fork id is too large to fit in 32 bits" );
    FC_ASSERT( _block_num >= 0 && _block_num <= BLOCK_NUM_LIMIT, "Block num value is larger than 31 bits" );

    int64_t result = _block_num;
    result <<= 32;
    result |= ( static_cast<uint32_t>(_fork_id) );

    return result;
}

inline HafBlockNum
haf_block_id_to_num( HafBlockId _id ) {
    return static_cast<HafBlockNum>( _id >> 32 );
}

inline HafForkId
haf_block_id_to_fork( HafBlockId _id ) {
    return static_cast<HafForkId>( _id & 0xFFFFFFFF );
}
