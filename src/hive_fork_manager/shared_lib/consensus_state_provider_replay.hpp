#pragma once

#include <string>
#include <vector>

#include <hive/chain/full_block.hpp>


namespace fc
{
  class variant;
}

namespace hive::chain
{
  class database;
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
  class postgres_database_helper;
  struct csp_session_type
  {
      csp_session_type(const char* context, const char* shared_memory_bin_path, const char* postgres_url);

      std::string shared_memory_bin_path;
      std::unique_ptr<postgres_database_helper> conn;
      std::unique_ptr<haf_state_database> db;
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
