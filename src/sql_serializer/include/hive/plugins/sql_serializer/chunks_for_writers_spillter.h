#pragma once

#include <cmath>
#include <memory>
#include <vector>

namespace hive::plugins::sql_serializer {
  class block_num_rendezvous_trigger;

  template< typename TableWriter >
  class chunks_for_writers_splitter_base
    {
    public:
      virtual ~chunks_for_writers_splitter_base() = default;

      chunks_for_writers_splitter_base( chunks_for_writers_splitter_base& ) = delete;
      chunks_for_writers_splitter_base( chunks_for_writers_splitter_base&& ) = delete;
      chunks_for_writers_splitter_base& operator=( chunks_for_writers_splitter_base& ) = delete;
      chunks_for_writers_splitter_base& operator=( chunks_for_writers_splitter_base&& ) = delete;

      void trigger( typename TableWriter::DataContainerType::container&& data, uint32_t last_block_num );
      void join();
      void complete_data_processing();

    protected:
      chunks_for_writers_splitter_base( std::string description ):_description( std::move(description) ){}

      template< typename... Parameters >
      void emplace_writer( Parameters... params ) { writers.emplace_back( params... ); }

    private:
      std::vector< TableWriter > writers;
      const std::string _description;
    };

  template< typename TableWriter >
  class chunks_for_sql_writers_splitter : public chunks_for_writers_splitter_base< TableWriter >
  {
  public:
    chunks_for_sql_writers_splitter(
        uint8_t number_of_threads
      , std::string psqlUrl
      , std::string description
      , std::shared_ptr< block_num_rendezvous_trigger > _randezvous_trigger
      , synchronicity_data::synchronicity_data_ptr synchronicity
    );

    virtual ~chunks_for_sql_writers_splitter() override = default;
  };

  template< typename TableWriter >
  class chunks_for_string_writers_splitter : public chunks_for_writers_splitter_base< TableWriter >
  {
    public:
      using callback = std::function< void(std::string&&) >;
      using strings = std::vector< std::string >;
      using callbacks = std::vector< callback >;

      chunks_for_string_writers_splitter(
          uint32_t number_of_threads
        , std::string description
        , std::shared_ptr< block_num_rendezvous_trigger > _randezvous_trigger
        , synchronicity_data::synchronicity_data_ptr synchronicity
      );

      virtual ~chunks_for_string_writers_splitter() override = default;

      std::string get_merged_strings();
    private:
      strings _strings;
      callbacks _callbacks;
  };

  template< typename TableWriter >
  inline
  chunks_for_sql_writers_splitter< TableWriter >::chunks_for_sql_writers_splitter(
    uint8_t number_of_threads
    , std::string psqlUrl
    , std::string description
    , std::shared_ptr< block_num_rendezvous_trigger > _randezvous_trigger
    , synchronicity_data::synchronicity_data_ptr synchronicity
    ) : chunks_for_writers_splitter_base< TableWriter >( description ) {
      FC_ASSERT( number_of_threads > 0 );
      for ( auto writer_num = 0; writer_num < number_of_threads; ++writer_num ) {
        auto writer_description = description + "_" + std::to_string( writer_num );
        chunks_for_writers_splitter_base< TableWriter >::emplace_writer( psqlUrl, writer_description, _randezvous_trigger, synchronicity );
      }
    }

  template< typename TableWriter >
  inline
  chunks_for_string_writers_splitter< TableWriter >::chunks_for_string_writers_splitter(
      uint32_t number_of_threads
    , std::string description
    , std::shared_ptr< block_num_rendezvous_trigger > _randezvous_trigger
    , synchronicity_data::synchronicity_data_ptr synchronicity
    ) : chunks_for_writers_splitter_base< TableWriter >( description ) {
      FC_ASSERT( number_of_threads > 0 );
      _strings.resize( number_of_threads );
      for ( auto& str : _strings ) {
        _callbacks.push_back( [&str]( std::string&& _str ){ str = std::move( _str ); } );
    }

    for ( auto writer_num = 0u; writer_num < _callbacks.size(); ++writer_num ) {
      auto writer_description = description + "_" + std::to_string( writer_num );
      chunks_for_writers_splitter_base< TableWriter >::emplace_writer(
        _callbacks[ writer_num ], writer_description, _randezvous_trigger, synchronicity
      );
    }
  }

  template< typename TableWriter >
  inline
  std::string
  chunks_for_string_writers_splitter< TableWriter >::get_merged_strings() {
    std::string result;
    for ( auto& str : _strings ) {
      if ( str.empty() )
        continue;

      if ( result.empty() ) {
        result += str;
      } else {
        result += ',' + str;
      }
      str.clear();
    }

    return result;
  }

  template< typename TableWriter >
  inline void
  chunks_for_writers_splitter_base< TableWriter >::trigger( typename TableWriter::DataContainerType::container&& data, uint32_t last_block_num ) {
    auto data_ptr = std::make_shared< typename TableWriter::DataContainerType::container >( std::move(data) );
    uint32_t length_of_batch = std::ceil( data_ptr->size() / double( writers.size() ) );
    uint32_t writer_num = 0;
    for ( auto& writer : writers ) {
      auto begin_range_it = ( writer_num * length_of_batch ) < data_ptr->size()
        ? data_ptr->begin() + writer_num * length_of_batch
        : data_ptr->end()
      ;

      auto end_range_it = ( ( ( writer_num + 1 ) * length_of_batch ) < data_ptr->size() )
        ? data_ptr->begin() + ( writer_num + 1 ) * length_of_batch
        : data_ptr->end()
      ;

      typename TableWriter::DataContainerType batch( data_ptr, begin_range_it, end_range_it );
      writer.trigger( std::move(batch), last_block_num );
      ++writer_num;
    }
  }

  template< typename TableWriter >
  inline void
  chunks_for_writers_splitter_base< TableWriter >::join() {
    for ( auto& writer : writers ) {
      writer.join();
    }
  }

  template< typename TableWriter >
  inline void
  chunks_for_writers_splitter_base< TableWriter >::complete_data_processing() {
    for ( auto& writer : writers ) {
      writer.complete_data_processing();
    }
  }

} //namespace hive::plugins::sql_serializer
