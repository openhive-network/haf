#pragma once
#include <set>

#include <boost/filesystem.hpp>
#include <optional>
#include <deque>
#include <atomic>

namespace hive::plugins::sql_serializer {
  namespace bfs = boost::filesystem;

  // The write-ahead log exists to keep the PostgreSQL database in sync with hived.
  // We can only collect the data we need to send to PostgreSQL at the time hived processes
  // the block, either when receiving the block normally in live-sync, or during a replay.
  // Without the write-ahead log, there would always be a short time where hived has 
  // just finished processing a block but PostgreSQL hasn't committed the data, where
  // we would be out of sync in a power failure-type situation.  If the power goes out
  // while processing block `x`, when hived starts up next it will send sql_serializer 
  // the data for block `x + 1`, and the data for block `x` will never have been written
  // to PostgreSQL.
  //
  // When we're in massive sync or p2p sync mode, the problem is far worse because we're 
  // processing many blocks at a time, and any crash virtually guarantees you'd need a 
  // full replay to recover.
  //
  // With the write-ahead log, before we send the data to PostgreSQL, we append the query
  // we plan to execute to the write-ahead log, and assign it a sequence number.  Once
  // it is flushed to disk, we run a transaction on the database that executes the query
  // storing the block data and atomically updating the sequence number.  If there's a 
  // crash, we can recover at the next startup -- we look at the database to see what 
  // sequence number was executed last, and if we have any more recent queries written
  // to our write-ahead log, we know that those were lost and we need to replay them
  // before continuing.  On the database side, the sequence number is stored in a 
  // one-line table `hive.write_ahead_log_state`
  //
  // That's the situation in livesync, which is the only place the write-ahead log
  // is currently used.
  // ## FUTURE PLANS BELOW
  // In massive/p2p sync, we are running several threads that each have a connection 
  // to the database.  That allows us to be writing multiple tables simultaneously. 
  // But it also means that a single sequence number won't do -- we need to track the 
  // sequence number for each connection separately.
  //
  // That will work something like this: when we launch a processing thread that owns
  // a PostgreSQL connection, we assign it a unique connection number, and each connection
  // has its own sequence number.  connection_numbers would be assigned by the database
  // and recycle infrequently; sequence numbers would start at zero.  We would commit the
  // (connection_number, 0) entry pair to the database before allowing that connection
  // to do any work (write anything to the write-ahead log).  When a connection is closed
  // cleanly (e.g, exiting massive sync), it would remove (w/commit) its entry from the 
  // `hive.write_ahead_log_state` table.
  // At startup, we first read the database table to find out what connections were
  // active at shutdown time.  Then, we scan through the write-ahead log.  We can ignore
  // any write-ahead log entries for connection numbers not referenced in the table; those
  // must all be for connections that were closed cleanly.  For any matching connection
  // numbers, we look for sequence numbers after the last one written to the database
  // and execute those to catch up.

  class write_ahead_log_manager {
  public:
    // we'll store the sequence number in a SQL `integer`, and restrict ourselves to
    // the non-negative values, wrapping to 0 when we hit 2147483647
    using sequence_number_t = int32_t;

    // the write-ahead log will be split into files of approximately `max_log_size`.
    // too small, high churn; too large, longer time spent scanning the log at startup
    static constexpr uint32_t max_log_size = 100 << 20; // 100MB

    // log file is a series of records in the format:
    //   "begin %10u %10u\n" (transaction_sequence_number, length_in_bytes) (this line is always 28 bytes total)
    //   <length_in_bytes of SQL>
    //   "\n" (this is always 1 byte)
    //   "end %10u %10u\n\n" (transaction_sequence_number, length_in_bytes) (this line is always 27 bytes total)
    // the file is specified as a binary format, but it should be human-readable.
    //
    // with this format, you can quickly scan forwards through the file:
    //   - read the first line, 28 bytes
    //   - read or skip the next length_in_bytes which is the SQL
    //   - skip the next 28 bytes (extra newline plus "end" line)
    // and backwards:
    //   - read the end line, the last 27 bytes of the file
    //   - the start of the begin line for that transaction would be
    //     28 + length_in_bytes + 1 + 27 bytes before the end of the file
    //   - if that doesn't take you to the start of the file, repeat
    class log_file {
    public:
      log_file(const log_file&) = delete;
      log_file& operator=(const log_file&) = delete;

      log_file(log_file&& rhs) :
        _creation_time_string(std::move(rhs._creation_time_string)),
        _serial_number(rhs._serial_number),
        _filename(std::move(rhs._filename)),
        _file(std::move(rhs._file)),
        _file_size(rhs._file_size),
        _sequence_number_range(std::move(rhs._sequence_number_range))
      {}


      log_file& operator=(log_file&& rhs)
      {
        _filename = std::move(rhs._filename);
        _file = std::move(rhs._file);
        return *this;
      }

      // these functions aren't thread safe, but they're only accessed by the write_ahead_log_manager
      // which ensures that only one thread at a time is using them
      void write_record(sequence_number_t sequence_number, std::string_view sql);
      std::pair<sequence_number_t, std::string> read_record();
      void for_each_record(std::function<void(sequence_number_t, std::string_view)> callback);
      uint32_t get_size() const { return _file_size; }
      const bfs::path& get_path() const { return _filename; }
      bool is_empty() const { return _file_size == 0; }
      const bfs::path& get_filename() const { return _filename; }
      const std::string& get_creation_time_string() const { return _creation_time_string; }
      uint32_t get_serial_number() const { return _serial_number; }

      // only valid when not empty
      sequence_number_t get_first_sequence_number() const { return _sequence_number_range->first; }
      sequence_number_t get_last_sequence_number() const { return _sequence_number_range->second; }

      void delete_file();

      static log_file create_new(const bfs::path& path, std::string creation_time_string, uint32_t serial_number);
      static log_file open_existing(const bfs::path& path, const std::string& filename);
    private:
      log_file() {}
      void create(const bfs::path& path, std::string&& creation_time_string, uint32_t serial_number);
      void open(const bfs::path& path, const std::string& filename);

      // files are named something like 20231225T010203.000.wal
      // creation_time_string: 20231225T010203 - the second in which the file was created
      // serial_number: 000 - first file created during this second
      std::string _creation_time_string;
      uint32_t _serial_number;
      bfs::path _filename; // full filename with path

      std::fstream _file;
      uint32_t _file_size; // current size of the file, used to detect when we've gone over the max and need to create a new one

      // if nonnull, the first and last transaction sequence number stored in this file
      // (if the file is empty, this will be null)
      std::optional<std::pair<sequence_number_t, sequence_number_t>> _sequence_number_range;
    };

    ~write_ahead_log_manager();

    // main interface functions, thread safe
    void open(bfs::path wal_directory);
    bool is_open() const { return _is_open.load(std::memory_order_consume); }

    sequence_number_t store_transaction(std::string_view sql);
    void transaction_completed(sequence_number_t sequence_number, bool shutting_down = false);
    void clear_log();

    std::optional<sequence_number_t> get_last_sequence_number();
    static bool is_less_than(sequence_number_t lhs, sequence_number_t rhs); // compare two sequence numbers
    void replay_transactions_after(sequence_number_t last_sequence_number, std::function<void(sequence_number_t, std::string_view)> replay_function);
  private:
    static sequence_number_t get_sequence_number_after(sequence_number_t sequence_number);
    std::optional<sequence_number_t> compute_last_sequence_number();
    sequence_number_t get_next_sequence_number();

    bfs::path _wal_directory;
    std::deque<log_file> _log_files;
    std::atomic<bool> _is_open = { false };
    std::optional<sequence_number_t> _last_sequence_number;
    std::mutex _mutex; // public API can be called from multiple threads, this guards access
    std::optional<sequence_number_t> _last_completed_transaction_sequence_number;
  };

} // namespace hive::plugins::sql_serializer

