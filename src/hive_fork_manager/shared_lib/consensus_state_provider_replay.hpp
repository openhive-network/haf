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

  struct csp_session_type;

  bool consensus_state_provider_replay_impl(const csp_session_type* const csp_session,  int from, int to);

  const csp_session_type* csp_init_impl(const char* context,
                                const char* shared_memory_bin_path,
                                const char* postgres_url);

  void csp_finish_impl(const csp_session_type* const csp_session, bool wipe_clean_shared_memory_bin);
  int consensus_state_provider_get_expected_block_num_impl(const consensus_state_provider::csp_session_type* const csp_session);

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

  collected_account_balances_collection_t collect_current_all_accounts_balances(const csp_session_type* const csp_session);
  collected_account_balances_collection_t collect_current_all_accounts_balances_impl(const csp_session_type* const csp_session);
  collected_account_balances_collection_t collect_current_account_balances(const csp_session_type* const csp_session, const std::vector<std::string>& accounts);
  collected_account_balances_collection_t collect_current_account_balances_impl(const csp_session_type* const csp_session , const std::vector<std::string>& accounts);


}  // namespace consensus_state_provider
