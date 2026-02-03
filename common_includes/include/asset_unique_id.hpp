#pragma once

#include <cstdint>

using AssetUniqueId = unsigned __int128;

/**
 * Bit layout of asset_unique_id (128 bits total):
 *   Bits 64-127: operation_id (64 bits)
 *   Bits 32-63:  NAI (Numeric Asset Identifier) (32 bits)
 *   Bits 0-31:   subsequent_no (32 bits)
 */

inline int64_t
asset_unique_id_to_operation_id(AssetUniqueId _id) {
    return static_cast<int64_t>(_id >> 64);
}

inline uint32_t
asset_unique_id_to_nai(AssetUniqueId _id) {
    return static_cast<uint32_t>((_id >> 32) & 0xFFFFFFFF);
}

inline uint32_t
asset_unique_id_to_subsequent_no(AssetUniqueId _id) {
    return static_cast<uint32_t>(_id & 0xFFFFFFFF);
}
