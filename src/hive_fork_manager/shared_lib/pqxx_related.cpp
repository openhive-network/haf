


#include "fc/variant.hpp"
#include <fc/io/json.hpp>
#include <fc/io/sstream.hpp>

#include "hive/protocol/forward_impacted.hpp"
#include "hive/protocol/operations.hpp"
#include <iostream>
#include <pqxx/pqxx>


#ifdef HAF_SHARED_LIB

#pragma message ("HAF_SHARED_LIB defined !!! hey")

#endif



namespace hive { namespace app {

void sanity_check(const char *&postgres_url) 
{
    pqxx::connection c{postgres_url};
    pqxx::work txn{c};
    pqxx::result r{txn.exec("SELECT COUNT(*) FROM hive.blocks")};

    std::cout << "mtlk columns count=" << r.columns() << "\n";
    std::cout << "mtlk column name=" << r.column_name(0) << "\n";
    std::cout << "mtlk rows  count=" << r.size() << "\n";

    for (auto row : r)
      std::cout
          // Address column by name.  Use c_str() to get C-style string.
          << row["count"].c_str()
          << " makes "
          // Address column by zero-based index.  Use as<int>() to parse as int.
          << row[0].as<int>() << "." << std::endl;
    txn.commit();

  for(auto i = 0u; i < r.columns(); ++i)
  {
    std::cout << "Column " << i << " name=" << r.column_name(i) << " type= " << r.column_type(r.column_name(i)) << std::endl;
  }
}

std::string fixTime(const pqxx::field& t)
{
  std::string r =t.c_str();
  r[10] = 'T';
  return r;
}


const char* fixHex(const pqxx::field& h)
{
    return h.c_str() + 2;
}


#define MULTISIGS_IN_C


struct Postgres2Blocks
{



  pqxx::result blocks;
  pqxx::result transactions;
  pqxx::result operations;
  std::multimap<std::string, std::string> multisigs;

  int transaction_expecting_block;
  pqxx::result::const_iterator transactions_it;
  int operations_expecting_block;
  int operations_expecting_transaction;
  pqxx::result::const_iterator operations_it;


void get_data_from_postgres(int from, int to, const char* postgres_url)
{
  pqxx::connection c{postgres_url};

  pqxx::work blocks_work{c};
  blocks = {blocks_work.exec("SELECT * FROM hive.blocks JOIN hive.accounts ON  id = producer_account_id WHERE num >= " 
                            + std::to_string(from) 
                            + " and num <= " 
                            + std::to_string(to) 
                            + " ORDER BY num ASC")};
  blocks_work.commit();

  pqxx::work transactions_work{c};
  transactions = {transactions_work.exec("SELECT block_num, trx_in_block, ref_block_num, ref_block_prefix, expiration, trx_hash, signature FROM hive.transactions WHERE block_num >= " 
                            + std::to_string(from) 
                            + " and block_num <= " 
                            + std::to_string(to) 
                            + " ORDER BY block_num, trx_in_block ASC")};
  transactions_work.commit();


  pqxx::work operations_work{c};
  operations = {operations_work.exec("SELECT block_num, body, trx_in_block FROM hive.operations WHERE block_num >= " 
                            + std::to_string(from) 
                            + " and block_num <= " 
                            + std::to_string(to) 
                            + " AND op_type_id <= 49 "
                            + " ORDER BY id ASC")};
  operations_work.commit();



#ifdef MULTISIGS_IN_C

  pqxx::work transactions_multisig_work{c};
  pqxx::result transactions_multisig{
    transactions_multisig_work.exec(
      std::string("SELECT trx_hash,signature FROM hive.transactions_multisig"))};


  for( auto row : transactions_multisig)
  {
    std::string key(std::string(row["trx_hash"].c_str()+2));
    multisigs.insert(std::make_pair(key, row["signature"].c_str()+2));
  }

  transactions_multisig_work.commit();

#endif

}

void prepare_iterators()
{
  transaction_expecting_block = -1;
  transactions_it = transactions.begin();
  if( transactions.size() > 0)
  {
      const auto& first_transaction = transactions[0];
      transaction_expecting_block = first_transaction["block_num"].as<int>();
  }

  operations_expecting_block = -1;
  operations_expecting_transaction = -1;
  operations_it = operations.begin();
  if(operations.size() > 0)
  {
    const auto& first_operation = operations[0];
    operations_expecting_block =  first_operation["block_num"].as<int>();
    operations_expecting_transaction = first_operation["trx_in_block"].as<int>();

  }
}

void handle_operations(int block_num, int trx_in_block, std::vector<fc::variant>& operations_vector)
{
  for(; operations_it != operations.end(); ++operations_it)
  {
    const auto operation = (*operations_it);
    if(operation["block_num"].as<int>() == block_num && operation["trx_in_block"].as<int>() == trx_in_block)
    {
      // fill in op here

      const auto &o = operation["body"];
      std::string json = std::string(o.c_str());
      fc::variant ov = fc::json::from_string(json);

      hive::protocol::operation op;
      fc::from_variant(ov, op);

      operations_vector.push_back(ov);
    }
    else
    {
      operations_expecting_block = operations_it["block_num"].as<int>();
      operations_expecting_transaction =
          operations_it["trx_in_block"].as<int>();
      break;
    }
  }
}
void handle_transactions(int block_num, 
  std::vector<variant>& transaction_ids_vector,
  std::vector<fc::variant>& trancactions_vector)
 {
  for (; transactions_it != transactions.end(); ++transactions_it) {
    const auto transaction = (*transactions_it);
    if (transaction["block_num"].as<int>() == block_num) {
      auto trx_in_block = transaction["trx_in_block"].as<int>();

      // fill in transaction here
      std::vector<std::string> signa;
      if (strlen(transaction["signature"].c_str())) {
        signa.push_back(transaction["signature"].c_str() + 2);

#ifndef MULTISIGS_IN_C
        pqxx::work transactions_multisig_work{c};
        pqxx::result transactions_multisig{transactions_multisig_work.exec(
            std::string("SELECT signature FROM hive.transactions_multisig "
                        "WHERE trx_hash  = '") +
            (transaction["trx_hash"].c_str()) + "'")};

        for (auto row : transactions_multisig) {
          signa.push_back(row["signature"].c_str() + 2);
        }

        transactions_multisig_work.commit();
#else
        auto range = multisigs.equal_range(transaction["trx_hash"].c_str() + 2);
        for (auto it = range.first; it != range.second; ++it) {
          signa.push_back(it->second);
        }
#endif
      }

      fc::variant_object_builder transaction_v;
      transaction_v("ref_block_num", transaction["ref_block_num"].as<int>())(
          "ref_block_prefix", transaction["ref_block_prefix"].as<int64_t>())(
          "expiration", fixTime(transaction["expiration"]))("signatures", signa);

      transaction_ids_vector.push_back(transaction["trx_hash"].c_str() + 2);


      // rewind
      while (operations_expecting_block < block_num) {
        operations_it++;
        operations_expecting_block = operations_it["block_num"].as<int>();
        operations_expecting_transaction =
            operations_it["trx_in_block"].as<int>();
      }

      std::vector<fc::variant> operations_vector;
      if(block_num == operations_expecting_block && trx_in_block == operations_expecting_transaction)
        handle_operations(block_num, trx_in_block, operations_vector);


      transaction_v("operations", operations_vector);

      variant tv;
      to_variant(transaction_v.get(), tv);
      trancactions_vector.push_back(tv);

    } else {
      transaction_expecting_block = transaction["block_num"].as<int>();
      break;
    }
  }
}


fc::variant block2variant(const pqxx::row& block)
{
  auto block_num = block["num"].as<int>();

  std::vector<variant> transaction_ids_variants;
  std::vector<fc::variant> transaction_variants;
  if(block_num == transaction_expecting_block)
    handle_transactions(block_num, transaction_ids_variants, transaction_variants);

  std::string json = block["extensions"].c_str();
  variant extensions = fc::json::from_string(json.empty() ?"[]":json);

  // fill in block header here
  fc::variant_object_builder block_variant_builder; 
  block_variant_builder
  ("witness", block["name"].c_str())
  ("block_id", fixHex(block["hash"]))
  ("previous", fixHex(block["prev"]))
  ("timestamp", fixTime(block["created_at"]))
  ("extensions", extensions)
  ("signing_key", block["signing_key"].c_str())
  ("transactions", transaction_variants)
  ("witness_signature", fixHex(block["witness_signature"]))
  ("transaction_merkle_root", fixHex(block["transaction_merkle_root"]))
  ("transaction_ids", transaction_ids_variants);

  variant block_variant;
  to_variant(block_variant_builder.get(), block_variant);
  return block_variant;
}

void blocks2replay(const char *context)
{


 for(const auto& block : blocks)
  {
    fc::variant v = block2variant(block);

    auto block_num = block["num"].as<int>();

    //std::string json = fc::json::to_pretty_string(v);
    //wlog("block_num=${block_num} header=${j}", ("block_num", block_num) ( "j", json));

    int n = consume_variant_block_impl(v, context, block_num);
    n=n;
  }
}

void run(int from, int to, const char *context, const char *postgres_url) 
{
  get_data_from_postgres(from, to, postgres_url);

  prepare_iterators();
  
  blocks2replay(context);
}

};

void consensus_state_provider_replay_impl(int from, int to, const char *context,
                                const char *postgres_url) 
{
  sanity_check(postgres_url);

  Postgres2Blocks p2b;
  p2b.run(from, to, context, postgres_url); 
}



}}

