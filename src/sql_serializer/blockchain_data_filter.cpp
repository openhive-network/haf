#include <hive/plugins/sql_serializer/blockchain_data_filter.hpp>

namespace hive{ namespace plugins{ namespace sql_serializer {

  bool blockchain_filter::is_enabled() const
  {
    return enabled;
  }

  bool blockchain_filter::is_trx_accepted( int64_t trx_in_block ) const
  {
    return !is_enabled() || trx_in_block_filter_accepted.find( trx_in_block ) != trx_in_block_filter_accepted.end();
  }

  bool blockchain_filter::is_tracked_account( const account_name_type& name ) const
  {
    return !accounts_filter_tracker || accounts_filter_tracker->is_tracked_account( name );
  }

  bool blockchain_filter::is_tracked_operation( const operation& op ) const
  {
    return ( !operations_filter_tracker       ||  operations_filter_tracker->is_tracked_operation( op ) ) &&
           ( !operations_body_filter_tracker  ||  operations_body_filter_tracker->is_tracked_operation( op ) );
  }

  void blockchain_filter::remember_trx_id( int64_t trx_in_block )
  {
    //Remember number of transaction that will be included into a database.
    if( is_enabled() && trx_in_block != -1 )
      trx_in_block_filter_accepted.insert( trx_in_block );
  }

  void blockchain_filter::fill( const boost::program_options::variables_map& options,
                                        const std::string& tracked_accounts,
                                        const std::string& tracked_operations,
                                        const std::string& tracked_body_operations )
  {
    if( is_enabled() )
    {
      ptr_account_tracker         _af   = ptr_account_tracker( new account_filter("acc-sql") );
      ptr_operations_tracker      _of   = ptr_operations_tracker( new operation_filter( "op-sql", op_helper ) );
      ptr_operations_body_tracker _obf  = ptr_operations_body_tracker( new operation_body_filter( "opb-sql", op_helper ) );

      try
      {
        _af->fill( options, tracked_accounts );
      }
      FC_CAPTURE_AND_LOG(("tracked accounts"))

      try
      {
        _of->fill( options, tracked_operations );
      }
      FC_CAPTURE_AND_LOG(("tracked operations"))

      try
      {
        _obf->fill( options, tracked_body_operations );
      }
      FC_CAPTURE_AND_LOG(("tracked body operations"))

      if( _af->empty() && _of->empty() && _obf->empty() )
        enabled = false;

      if( !_af->empty() )
        accounts_filter_tracker = std::move( _af );

      if( !_of->empty() )
        operations_filter_tracker = std::move( _of );

      if( !_obf->empty() )
        operations_body_filter_tracker = std::move( _obf );
    }
  }

  void blockchain_filter::clear()
  {
    if( is_enabled() )
      trx_in_block_filter_accepted.clear();
  }

  blockchain_filter utils::make_filter( const std::string& operation_type, const std::string& body_filter )
  {
    namespace po = boost::program_options;

    type_extractor::operation_extractor op_extractor;
    blockchain_filter filter( true, op_extractor );

    std::stringstream _file;
    _file<<"psql-track-body-operations = ";
    _file<<"[\"";
    _file<<operation_type;
    _file<<"\"";
    _file<<",";
    _file<<"\"";
    _file<<body_filter;
    _file<<"\"";
    _file<<"]";

    po::options_description desc("");
    desc.add_options()
      ("psql-track-account-range", boost::program_options::value< std::vector<std::string> >()->composing()->multitoken(), "")
      ("psql-track-operations", boost::program_options::value< std::vector<std::string> >()->composing(), "")
      ("psql-track-body-operations", boost::program_options::value< std::vector<std::string> >()->composing()->multitoken(), "");

    po::variables_map vm;

    po::store( po::parse_config_file( _file, desc, true ), vm );

    filter.fill( vm, "psql-track-account-range", "psql-track-operations", "psql-track-body-operations" );

    return filter;
  }

}}} // namespace hive::plugins::sql_serializer
