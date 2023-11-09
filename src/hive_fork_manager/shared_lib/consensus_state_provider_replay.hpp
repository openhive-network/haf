#pragma once

#include <hive/chain/full_block.hpp>
#include <appbase/application.hpp>
#include <hive/chain/sync_block_writer.hpp>
#include <hive/chain/irreversible_block_writer.hpp>


#include <string>
#include <vector>




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

  class csp_session_type;
  using csp_session_ref_type = csp_session_type&;
  using csp_session_ptr_type = csp_session_type*;

  class custom_block_reader : public hive::chain::fork_db_block_reader 
  {
  public:
    custom_block_reader(hive::chain::fork_database& fork_db, hive::chain::block_log& block_log, csp_session_ref_type csp_session)
      : fork_db_block_reader(fork_db, block_log), csp_session(csp_session) 
    {
    }

    virtual std::shared_ptr<hive::chain::full_block_type> read_block_by_num( uint32_t block_num ) const override;
    private:
      csp_session_ref_type csp_session;
  
  };
  
  class empty_block_writer : public hive::chain::sync_block_writer
  {
      virtual void store_block( uint32_t current_irreversible_block_num, uint32_t state_head_block_number ) override
      {

      }

    public:
      empty_block_writer( hive::chain::database& db, appbase::application& app, csp_session_ref_type csp_session )
      :
        sync_block_writer(db, app), _custom_reader(_fork_db, _block_log, csp_session) 
      {
      }
    virtual hive::chain::block_read_i& get_block_reader() override {
      return _custom_reader;
    }

  

private:
  custom_block_reader _custom_reader;

  };

  struct csp_session_type
  {
      csp_session_type(const char* context, const char* shared_memory_bin_path, const char* postgres_url);

      std::string shared_memory_bin_path;
      std::unique_ptr<postgres_database_helper> conn;

      //hive::chain::irreversible_block_writer reindex_block_writer;

      std::unique_ptr<haf_state_database> db;
      empty_block_writer e_block_writer;

      appbase::application theApp;
  };



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
