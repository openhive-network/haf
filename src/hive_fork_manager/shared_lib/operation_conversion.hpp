#pragma once

#include <hive/protocol/operations.hpp>

#include <psql_utils/postgres_includes.hpp>

#include <string>

hive::protocol::operation raw_to_operation( const char* raw_data, uint32 data_length );
std::string raw_to_json( const char* raw_data, uint32 data_length );
