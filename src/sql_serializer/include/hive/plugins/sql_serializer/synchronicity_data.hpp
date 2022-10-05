#pragma once

#include <transactions_controller/transaction_controllers.hpp>
#include <fc/exception/exception.hpp>

namespace hive::plugins::sql_serializer {
  class synchronicity_data
  {
    public:

      using synchronicity_data_ptr = std::shared_ptr<synchronicity_data>;
      using transaction_ptr = transaction_controllers::transaction_controller::transaction_ptr;
      using transaction     = transaction_controllers::transaction;

    private:

      bool synchronicity = false;

      const std::string db_url;
      const std::string description;

      std::shared_ptr< transaction_controllers::transaction_controller > transactions_controller;
      transaction_ptr tx;

    public:

      synchronicity_data( bool synchronicity = false, const std::string& db_url = "", const std::string& description = "" )
                        : synchronicity( synchronicity ), db_url( db_url ), description( description )
      {

      }

      bool is_synchronicity() const
      {
        return synchronicity;
      }

      transaction& get_tx()
      {
        FC_ASSERT( tx, "Transaction must be opened");
        return *tx;
      }

      void openTx()
      {
        transactions_controller = transaction_controllers::build_own_transaction_controller( db_url, description );
        tx = transactions_controller->openTx();
      }

      void commit()
      {
        tx->commit();
      }
  };
} // namespace hive::plugins::sql_serializer
