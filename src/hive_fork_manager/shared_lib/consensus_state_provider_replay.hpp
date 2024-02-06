#pragma once

#include <hive/chain/full_block.hpp>
#include <appbase/application.hpp>
#include <hive/chain/sync_block_writer.hpp>
#include <hive/chain/irreversible_block_writer.hpp>
#include <hive/chain/empty_block_writer.hpp>


#include <string>
#include <vector>

#define USE_PQXX
//#define USE_PQXX_UNDEFINED


namespace fc
{
  class variant;
}

namespace hive::chain
{
  class database;
}

namespace spixx
{
  class postgres_database_helper_spi;
}

namespace pqxx
{
  class postgres_database_helper;
}
namespace consensus_state_provider
{


  struct collected_account_balances_t
  {
    std::string account_name;
    int64_t
      balance,
      hbd_balance,
      vesting_shares,
      savings_hbd_balance,
      reward_hbd_balance;
  };
  using collected_account_balances_collection_t = std::vector<collected_account_balances_t>;

  class haf_state_database;
  
  
  struct csp_session_type
  {
      csp_session_type(const char* context, const char* shared_memory_bin_path, const char* postgres_url);

      std::string shared_memory_bin_path;
      //#ifdef USE_PQXX
        std::unique_ptr<pqxx::postgres_database_helper> pqxx_conn;
      //#else
        std::unique_ptr<spixx::postgres_database_helper_spi> spi_conn;
      //#endif
      std::unique_ptr<haf_state_database> db;
      empty_block_writer e_block_writer;

      appbase::application theApp;

  };

  using csp_session_ref_type = csp_session_type&;
  using csp_session_ptr_type = csp_session_type*;


  bool consensus_state_provider_replay_impl(csp_session_ref_type csp_session, uint32_t from, uint32_t to);

  csp_session_ptr_type csp_init_impl(const char* context,
                                const char* shared_memory_bin_path,
                                const char* postgres_url);

  void csp_finish_impl(csp_session_ref_type csp_session, bool wipe_clean_shared_memory_bin);
  uint32_t consensus_state_provider_get_expected_block_num_impl(csp_session_ref_type csp_session);

  collected_account_balances_collection_t collect_current_all_accounts_balances(csp_session_ref_type csp_session);
  collected_account_balances_collection_t collect_current_all_accounts_balances_impl(csp_session_ref_type csp_session);
  collected_account_balances_collection_t collect_current_account_balances(csp_session_ref_type csp_session, const std::vector<std::string>& accounts);
  collected_account_balances_collection_t collect_current_account_balances_impl(csp_session_ref_type csp_session , const std::vector<std::string>& accounts);


}  // namespace consensus_state_provider
