#pragma once

#include <cstdint>
#include <limits>

#include <fc/exception/exception.hpp>

using OperationId = uint64_t;
using OperationTypeId = uint32_t;
using OperationPositionInBlock = uint32_t;
using OperationBlockNum = uint32_t;

inline OperationId
to_operation_id( OperationBlockNum _block_num, OperationTypeId _type_id, OperationPositionInBlock _pos_in_block ) {
    //msb.....................lsb
    // || block | seq | type ||
    // ||  32b  | 24b |  8b  ||
    constexpr auto  TYPE_ID_LIMIT = 255; // 2^8-1
    constexpr auto NUMBER_IN_BLOCK_LIMIT = 16777215; // 2^24-1
    constexpr auto BLOCK_NUM_LIMIT = std::numeric_limits< int32_t >::max(); // ignore complement code bit
    FC_ASSERT(  _type_id <= TYPE_ID_LIMIT, "Operation type is to large to fit in 8 bits" );
    FC_ASSERT( _pos_in_block <= NUMBER_IN_BLOCK_LIMIT , "Operation in block number is to large to fit in 24 bits" );
    FC_ASSERT(  _block_num <= BLOCK_NUM_LIMIT, "Block num value is larger than 31 bits" );

int64_t result = _block_num;
result <<= 32;
result |= ( _pos_in_block << 8 );
result |= _type_id;

return result;
}

inline OperationTypeId
operation_id_to_type_id( OperationId _id ) {
return _id & 0xFF;
}

inline OperationPositionInBlock
operation_id_to_pos( OperationId _id ) {
return ( _id >> 8 ) & 0xFFFFFF;
}

inline OperationBlockNum
operation_id_to_block_num( OperationId _id ) {
return _id >> 32;
}


