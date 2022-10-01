#pragma once

// STL
#include <sstream>
#include <string>
#include <atomic>
#include <functional>

// Boost
#include <boost/thread/sync_queue.hpp>
#include <boost/multi_index_container.hpp>
#include <boost/multi_index/ordered_index.hpp>
#include <boost/multi_index/mem_fun.hpp>
#include <boost/multi_index/tag.hpp>

// Internal
#include <hive/chain/util/extractors.hpp>
#include <hive/chain/hive_object_types.hpp>
#include <hive/chain/account_object.hpp>
#include <hive/chain/util/operation_extractor.hpp>

#ifndef HIVE_SQL_SERIALIZER_SPACE_ID
#define HIVE_SQL_SERIALIZER_SPACE_ID 20
#endif

namespace hive
{
  namespace plugins
  {
    namespace sql_serializer
    {

      namespace PSQL
      {
        template <typename T>
        using queue = boost::concurrent::sync_queue<T>;
        using escape_function_t = std::function<fc::string(const char *)>;
        using escape_raw_function_t = std::function<fc::string(const char *, const size_t)>;

        using hive::protocol::operation;
        using hive::protocol::signature_type;
        using hive::protocol::checksum_type;
        using hive::protocol::public_key_type;

        namespace processing_objects
        {
          struct block_data_base
          {
            block_data_base(const int _block_number) : block_number{_block_number} {}
            int block_number = 0;
          };

          struct block_data_with_hash : public block_data_base
          {
            using hash_t = fc::ripemd160;

            block_data_with_hash(const hash_t &_hash, const int block_number) : block_data_base(block_number), hash{_hash} {}
            hash_t hash;
          };


          struct process_block_t
            : public block_data_with_hash
          {
            using block_data_with_hash::hash_t;
            fc::time_point_sec created_at;
            hash_t prev_hash;
            int32_t producer_account_id = 0;
            checksum_type transaction_merkle_root;
            fc::optional<std::string> extensions;
            signature_type witness_signature;
            public_key_type signing_key;

            process_block_t(const hash_t &_hash, const int _block_number, const fc::time_point_sec _tp, const hash_t &_prev, const int _producer_account_id,
                            const checksum_type& _transaction_merkle_root, const fc::optional<std::string>& _extensions, const signature_type& _witness_signature, const public_key_type& _signing_key)
            : block_data_with_hash{_hash, _block_number}, created_at{_tp}, prev_hash{_prev}, producer_account_id{_producer_account_id},
            transaction_merkle_root{_transaction_merkle_root}, extensions{_extensions}, witness_signature{_witness_signature}, signing_key{_signing_key}
            {}
          };

          struct process_transaction_t
            : public block_data_with_hash
          {
            using block_data_with_hash::hash_t;

            int32_t trx_in_block = 0;
            uint16_t ref_block_num = 0;
            uint32_t ref_block_prefix = 0;
            fc::time_point_sec expiration;
            fc::optional<signature_type> signature;

            process_transaction_t(const block_data_with_hash::hash_t& _hash, const int _block_number, const int32_t _trx_in_block,
                                  const uint16_t _ref_block_num, const uint32_t _ref_block_prefix, const fc::time_point_sec& _expiration, const fc::optional<signature_type>& _signature)
              : block_data_with_hash{_hash, _block_number}, trx_in_block{_trx_in_block},
              ref_block_num{_ref_block_num}, ref_block_prefix{_ref_block_prefix}, expiration{_expiration}, signature{_signature}
            {}
          };

          struct process_transaction_multisig_t : public block_data_with_hash
          {
            using block_data_with_hash::hash_t;

            signature_type signature;

            process_transaction_multisig_t(const block_data_with_hash::hash_t& _hash, const int _block_number, const signature_type& _signature)
            : block_data_with_hash{_hash, _block_number}, signature{_signature}
            {}
          };

          struct process_operation_t
            : public block_data_base
          {
            int64_t operation_id = 0;
            int32_t trx_in_block = 0;
            int32_t op_in_trx = 0;
            fc::time_point_sec timestamp;
            operation op;

            process_operation_t(
                int64_t _operation_id
              , int32_t _block_number
              , const int32_t _trx_in_block
              , const int32_t _op_in_trx
              , const fc::time_point_sec& time, const operation &_op
            )
            : block_data_base( _block_number )
            , operation_id{_operation_id }, trx_in_block{_trx_in_block}
            , op_in_trx{_op_in_trx}, timestamp(time), op{_op} {}
          };

          /// Holds account information to be put into database
          struct applied_hardforks_t
            : public block_data_base
          {
            int32_t hardfork_num = 0;
            int64_t hardfork_vop_id = 0;

            applied_hardforks_t(int32_t _hardfork_num, int32_t _block_number, int64_t _hardfork_vop_id)
            : block_data_base( _block_number )
            , hardfork_num{_hardfork_num}
            , hardfork_vop_id{_hardfork_vop_id}
            {}
          };

          struct account_data_t
            : public block_data_base
          {
            account_data_t(int _id, std::string _n, int32_t _block_number)
            : block_data_base( _block_number )
            , id{_id}
            , name{ std::move(_n) }
            {}

            int32_t id = 0;
            std::string name;
          };

          /// Holds association between account and its operations.
          struct account_operation_data_t
            : public block_data_base
          {
            int64_t operation_id;
            int32_t account_id;
            int32_t operation_seq_no;
            int32_t op_type_id;

            account_operation_data_t(int32_t _block_number, int64_t _operation_id, int32_t _account_id, int32_t _operation_seq_no, int32_t _op_type_id)
            : block_data_base( _block_number )
            , operation_id{ _operation_id }
            , account_id{ _account_id }
            , operation_seq_no{ _operation_seq_no }
            , op_type_id( _op_type_id )
            {}
          };
        }; // namespace processing_objects

        inline fc::string generate(std::function<void(fc::string &)> fun)
        {
          fc::string ss;
          fun(ss);
          return ss;
        }
        struct name_gathering_visitor
        {
          using result_type = fc::string;

          template <typename op_t>
          result_type operator()(const op_t &) const
          {
            return boost::typeindex::type_id<op_t>().pretty_name();
          }
        };

        constexpr const char *SQL_bool(const bool val) { return (val ? "TRUE" : "FALSE"); }

        inline fc::string get_all_type_definitions( const type_extractor::operation_extractor& op_extractor )
        {
          type_extractor::operation_extractor::operation_details_container_t result = op_extractor.get_operation_details();

          if (result.empty())
            return fc::string{};
          else
          {
            return generate([&](fc::string &ss) {
              ss.append("INSERT INTO hive.operation_types VALUES ");
              for (auto it = result.begin(); it != result.end(); it++)
              {
                if (it != result.begin())
                  ss.append(",");
                ss.append("( ");
                ss.append(std::to_string(it->first));
                ss.append(" , '");
                ss.append(it->second.first);
                ss.append("', ");
                ss.append(SQL_bool(it->second.second));
                ss.append(" )");
              }
              ss.append(" ON CONFLICT DO NOTHING");
            });
          }
        }
        using cache_contatiner_t = std::set<fc::string>;

      } // namespace PSQL

      enum sql_serializer_object_types
      {
        account_ops_seq_object_type = ( HIVE_SQL_SERIALIZER_SPACE_ID << 8 )
      };

      class account_ops_seq_object : public chainbase::object< account_ops_seq_object_type, account_ops_seq_object >
      {
        CHAINBASE_OBJECT( account_ops_seq_object );
        public:
          template< typename Allocator >
          account_ops_seq_object( chainbase::allocator< Allocator > a, uint64_t _id,
            const hive::chain::account_object& _account )
          : id( _account.get_id() ), operation_count( 0 )
          {}

          uint32_t operation_count;

          CHAINBASE_UNPACK_CONSTRUCTOR(account_ops_seq_object);
      };
      typedef chainbase::oid_ref< account_ops_seq_object > account_ops_seq_id_type;

      typedef boost::multi_index_container<
        account_ops_seq_object,
        boost::multi_index::indexed_by<
          boost::multi_index::ordered_unique< boost::multi_index::tag< hive::chain::by_id >,
            boost::multi_index::const_mem_fun< account_ops_seq_object, account_ops_seq_object::id_type, &account_ops_seq_object::get_id > >
          >,
        chainbase::allocator< account_ops_seq_object >
      > account_ops_seq_index;

    }    // namespace sql_serializer
  }      // namespace plugins
} // namespace hive

FC_REFLECT( hive::plugins::sql_serializer::account_ops_seq_object, (id)(operation_count) )
CHAINBASE_SET_INDEX_TYPE( hive::plugins::sql_serializer::account_ops_seq_object, hive::plugins::sql_serializer::account_ops_seq_index )
