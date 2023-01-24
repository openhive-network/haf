#pragma once

#include <string>
#include <vector>

#include <hive/chain/full_block.hpp>


namespace fc 
{
  class variant;
}

namespace hive{ namespace chain{
  class database;
}}




namespace consensus_state_provider {

struct csp_session_type;


bool consensus_state_provider_replay_impl(csp_session_type* csp_session,  int from, int to);                                          

csp_session_type* csp_init_impl(const char* context,
                               const char* shared_memory_bin_path,
                               const char* postgres_url);

void csp_finish_impl(csp_session_type*, bool wipe_clean_shared_memory_bin);
int consensus_state_provider_get_expected_block_num_impl(consensus_state_provider::csp_session_type* csp_session);
                                                         




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
  typedef std::vector<collected_account_balances_t> collected_account_balances_collection_t;

  class haf_full_database;
  struct csp_session_type
  {
    std::string context, shared_memory_bin_path, postgres_url;
    haf_full_database* db;
  };

  collected_account_balances_collection_t collect_current_all_accounts_balances(csp_session_type* csp_session);
  collected_account_balances_collection_t collect_current_all_accounts_balances_impl(csp_session_type* );
  collected_account_balances_collection_t collect_current_account_balances(csp_session_type* csp_session, const std::vector<std::string>& accounts);
  collected_account_balances_collection_t collect_current_account_balances_impl(csp_session_type* , const std::vector<std::string>& accounts);


}  // namespace consensus_state_provider
