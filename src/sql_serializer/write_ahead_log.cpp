#include <iomanip>
#include <sstream>
#include <algorithm>
#include <ranges>
#include <mutex>

#include <boost/date_time/posix_time/posix_time.hpp>
#include <boost/algorithm/string/predicate.hpp>
#include <boost/algorithm/string.hpp>

#include <fc/exception/exception.hpp>
#include <hive/plugins/sql_serializer/write_ahead_log.hpp>

namespace fc {
  void to_variant(const boost::filesystem::path& path, variant& var) { var = path.string(); }
}

namespace hive::plugins::sql_serializer {
  void write_ahead_log_manager::log_file::create(const bfs::path& path, std::string&& creation_time_string, uint32_t serial_number)
  {
    dlog("log_file::create(${path}, ${creation_time_string}, ${serial_number})", (path)(creation_time_string)(serial_number));
    std::ostringstream filename_stream;
    filename_stream << creation_time_string << "." << std::setw(3) << std::setfill('0') << serial_number << ".wal";
    std::string filename = filename_stream.str();
    bfs::path full_path = path / filename;

    FC_ASSERT(!boost::filesystem::exists(full_path), "File ${filename} already exists", (full_path));

    _creation_time_string = std::move(creation_time_string);
    _serial_number = serial_number;
    _filename = std::move(full_path);
    _file.open(_filename, std::ios::trunc | std::ios::in | std::ios::out | std::ios::binary);
    FC_ASSERT(_file, "Error creating new log file ${_filename}", (_filename));
    _file_size = 0;
  }

  /* static */ write_ahead_log_manager::log_file write_ahead_log_manager::log_file::create_new(const bfs::path& path, std::string creation_time_string, uint32_t serial_number)
  {
    log_file new_log_file;
    new_log_file.create(path, std::move(creation_time_string), serial_number);
    return new_log_file;
  }

  void write_ahead_log_manager::log_file::open(const bfs::path& path, const std::string& filename)
  {
    dlog("log_file::open(${path}, ${filename})", (path)(filename));

    // split the filename, which is "<creation_time>.<serial_number>.wal" into parts
    std::vector<std::string> filename_parts;
    boost::split(filename_parts, filename, boost::is_any_of("."));
    FC_ASSERT(filename_parts.size() == 3, "malformed WAL filename ${filename}", (filename));
    FC_ASSERT(filename_parts[2] == "wal", "malformed WAL filename ${filename}", (filename));
    _creation_time_string = std::move(filename_parts[0]);
    _serial_number = strtol(filename_parts[1].c_str(), nullptr, 10);

    _filename = path / filename;
    FC_ASSERT(boost::filesystem::exists(_filename), "File ${_filename} doesn't exist", (_filename));
    _file.open(_filename, std::ios::in | std::ios::out | std::ios::binary | std::ios::app);
    FC_ASSERT(_file, "Error opening existing log file ${_filename}", (_filename));

    // compute file size
    const std::streampos begin = _file.tellg();
    _file.seekg(0, std::ios::end);
    _file_size = _file.tellg() - begin;

    // scan all records in the file to find the range of sequence numbers
    // (we could optimize by reading the first then reading backwards from the
    // end to get the last, but I think this will be fast enough)
    for_each_record([&](sequence_number_t sequence_number, std::string_view sql) {
      if (_sequence_number_range)
        _sequence_number_range->second = sequence_number;
      else
        _sequence_number_range = std::make_pair(sequence_number, sequence_number);
    });

    dlog("Loaded write-ahead log with sequence-number range ${first} to ${last}", ("first", _sequence_number_range->first)("last", _sequence_number_range->second));
  }

  /* static */ write_ahead_log_manager::log_file write_ahead_log_manager::log_file::open_existing(const bfs::path& path, const std::string& filename)
  {
    log_file existing_log_file;
    existing_log_file.open(path, filename);
    return existing_log_file;
  }

  void write_ahead_log_manager::log_file::write_record(const sequence_number_t sequence_number, const std::string_view sql)
  {
    _file << "begin " << std::setw(10) << sequence_number << " " << std::setw(10) << sql.length() << "\n";
    _file_size += 28;

    _file.write(sql.data(), sql.length());
    _file_size += sql.length();

    _file << "\nend " << std::setw(10) << sequence_number << " " << std::setw(10) << sql.length() << "\n\n";
    _file_size += 28;
    _file.flush();
    FC_ASSERT(_file, "Error writing record to log file ${_filename}", (_filename));
    if (_sequence_number_range)
      _sequence_number_range->second = sequence_number;
    else
      _sequence_number_range = std::make_pair(sequence_number, sequence_number);
  }

  std::pair<write_ahead_log_manager::sequence_number_t, std::string> write_ahead_log_manager::log_file::read_record()
  { try {
    // read the "begin" line, and parse out the sequence number and length
    char begin_buffer[28];
    _file.read(begin_buffer, sizeof(begin_buffer));
    FC_ASSERT(_file, "Error reading record from log file ${_filename}", (_filename));
    FC_ASSERT(begin_buffer[sizeof(begin_buffer) - 1] == '\n', "Invalid 'begin' line in log file ${_filename}", (_filename));
    begin_buffer[sizeof(begin_buffer) - 1] = 0;
    std::istringstream begin_stream(begin_buffer);
    std::string begin;
    sequence_number_t sequence_number = 0;
    uint32_t sql_length = 0;
    begin_stream >> begin >> sequence_number >> sql_length;
    FC_ASSERT(begin_stream, "Error parsing 'begin' line in log file ${_filename}", (_filename));
    FC_ASSERT(begin == "begin", "Error parsing 'begin' line in log file ${_filename}", (_filename));
    //edump((sequence_number)(sql_length));

    // read the sql string
    std::unique_ptr<char[]> sql_buffer(new char[sql_length]);
    _file.read(sql_buffer.get(), sql_length);
    FC_ASSERT(_file, "Error reading record from log file ${_filename}", (_filename));
    //edump((std::string(sql_buffer.get(), sql_length)));
    
    // read the "end" line, and parse out the sequence number and length
    char end_buffer[28];
    _file.read(end_buffer, sizeof(end_buffer));
    FC_ASSERT(_file, "Error reading record from log file ${_filename}", (_filename));
    FC_ASSERT(end_buffer[0] == '\n', "Invalid 'end' line in log file ${_filename}", (_filename));
    FC_ASSERT(end_buffer[sizeof(end_buffer) - 1] == '\n', "Invalid 'end' line in log file ${_filename}", (_filename));
    FC_ASSERT(end_buffer[sizeof(end_buffer) - 2] == '\n', "Invalid 'end' line in log file ${_filename}", (_filename));
    //edump((std::string(end_buffer, sizeof(end_buffer))));
    end_buffer[sizeof(end_buffer) - 2] = 0;
    std::istringstream end_stream(end_buffer + 1);
    std::string end;
    sequence_number_t end_sequence_number = 0;
    uint32_t end_sql_length = 0;
    end_stream >> end >> end_sequence_number >> end_sql_length;
    FC_ASSERT(end_stream, "Error parsing 'end' line in log file ${_filename}", (_filename));
    FC_ASSERT(end == "end", "Error parsing 'end' line in log file ${_filename}", (_filename));
    FC_ASSERT(sql_length == end_sql_length, "Error parsing 'end' line in log file ${_filename}", (_filename));
    FC_ASSERT(sequence_number == end_sequence_number, "Error parsing 'end' line in log file ${_filename}", (_filename));

    return std::make_pair(sequence_number, std::string(sql_buffer.get(), sql_length));
  } FC_CAPTURE_AND_RETHROW() }

  // helper function, scans the file and executes a callback for each record in the file
  void write_ahead_log_manager::log_file::for_each_record(std::function<void(sequence_number_t, std::string_view)> callback)
  {
    _file.seekg(0, std::ios::beg);
    while (!_file.eof())
    {
      std::pair<sequence_number_t, std::string> record = read_record();
      callback(record.first, record.second);
      _file.peek(); // find out if we're at EOF
    }
    // clear eof/fail bit
    _file.clear();
  }

  void write_ahead_log_manager::log_file::delete_file()
  {
    _file.close();
    boost::filesystem::remove(_filename);
  }

  write_ahead_log_manager::~write_ahead_log_manager()
  {
    // during normal operation, we keep at least one log file open, even if we know
    // all transactions have been committed to the database, in ordedr to avoid constantly
    // deleting/creating log files.
    // At shutdown, though, it's a good idea to delete the log if we can, so we don't have
    // to snapshot it, and it saves a little work at the next startup
    if (_last_completed_transaction_sequence_number)
      transaction_completed(*_last_completed_transaction_sequence_number, true);
  }

  void write_ahead_log_manager::open(bfs::path wal_directory)
  {
    std::unique_lock<std::mutex> lock(_mutex);
    elog("write_ahead_log_manager::open(${wal_directory})", (wal_directory));
    _wal_directory = std::move(wal_directory);
    boost::filesystem::create_directories(_wal_directory);
    FC_ASSERT(boost::filesystem::is_directory(_wal_directory), "${_wal_directory} must be a directory", (_wal_directory));

    // is_wal_file() is a simple check, just to avoid screwing up if you accidentally drop a log file in the wal directory.
    // it could (maybe should) be more comprehensive
    auto is_wal_file = [](std::string_view filename) { return boost::algorithm::ends_with(filename, ".wal"); };

    // read and sort all the filenames.  filenames are designed so that a lexicographic sort == chronological sort
    std::set<std::string> all_wal_filenames;
    for (bfs::directory_iterator i{_wal_directory}; i != bfs::directory_iterator{}; i++)
    {
      std::string filename = i->path().filename().string();
      if (is_wal_file(filename))
        all_wal_filenames.insert(std::move(filename));
    }

    // open the files
    std::transform(all_wal_filenames.begin(), all_wal_filenames.end(), std::back_inserter(_log_files),
                   [this](const std::string& wal_filename) { return log_file::open_existing(_wal_directory, wal_filename); });
    _last_sequence_number = compute_last_sequence_number();

    _is_open.store(true, std::memory_order_release);
  }

  write_ahead_log_manager::sequence_number_t write_ahead_log_manager::store_transaction(std::string_view sql)
  {
    std::unique_lock<std::mutex> lock(_mutex);
    if (_log_files.empty() ||
        _log_files.back().get_size() > max_log_size)
    {
      // time to create a new log file.  Filename is in the format: yyyymmddThhmmss.###.wal
      // where ### is usually 0, unless we need to create multiple log files in the same second; then we increment it 
      // as needed (so this supports up to 1000 log files per second)
      const std::string time_string = boost::posix_time::to_iso_string(boost::posix_time::second_clock::universal_time());

      std::string filename;
      unsigned serial_number = 0;

      // figure out the first unused serial number
      for (;; ++serial_number)
      {
        std::ostringstream filename_stream;
        filename_stream << time_string << "." << std::setw(3) << std::setfill('0') << serial_number << ".wal";
        filename = filename_stream.str();
        if (_log_files.empty())
          break;
        elog("Want to create log file with base name ${time_string}, last open one has time string ${last}", (time_string)("last", _log_files.back().get_creation_time_string()));
        if (_log_files.back().get_creation_time_string() < time_string)
          break;
        elog("Want to create log file with serial ${serial_number}, last open one has time string ${last}", (serial_number)("last", _log_files.back().get_serial_number()));
        if (_log_files.back().get_serial_number() < serial_number)
          break;
      }
      elog("in store_transaction, calling create_new, dir: ${_wal_directory} file: ${filename}", (_wal_directory)(filename));
      _log_files.push_back(log_file::create_new(_wal_directory, time_string, serial_number));
    }
    sequence_number_t sequence_number = get_next_sequence_number();
    _log_files.back().write_record(sequence_number, sql);
    return sequence_number;
  }

  // returns true if one sequence number is less than the other, allowing for wrap-around
  /* static */ bool write_ahead_log_manager::is_less_than(const sequence_number_t lhs, const sequence_number_t rhs)
  {
    return (lhs < rhs && rhs - lhs < std::numeric_limits<sequence_number_t>::max() / 2) ||
           (lhs > rhs && lhs - rhs > std::numeric_limits<sequence_number_t>::max() / 2);
  }

  // 
  void write_ahead_log_manager::transaction_completed(const sequence_number_t transaction_sequence_number, const bool shutting_down)
  {
    std::unique_lock<std::mutex> lock(_mutex);
    FC_ASSERT(!_log_files.empty(), "I don't know anything about transaction sequence number ${transaction_sequence_number}",
              (transaction_sequence_number));
    _last_completed_transaction_sequence_number = transaction_sequence_number;

    // if we only have one log file, leave it in place, even if all transactions in it have been successfully committed.
    // exception: if we're shutting down, we want to clean up everything possible.
    while (_log_files.size() > 1 ||
           (shutting_down && !_log_files.empty()))
    {
      bool remove_file = false;

      // this should never happen, but if we somehow get an empty log file, with another file after it,
      // get rid of the first one
      if (_log_files.front().is_empty())
        remove_file = true;
      else
      {
        // if the new transaction number is the one at the end of this log file, or it's a later transaction,
        // we don't need the file anymore
        const sequence_number_t last_sequence_in_first_file = _log_files.front().get_last_sequence_number();
        remove_file = transaction_sequence_number == last_sequence_in_first_file ||
                      is_less_than(last_sequence_in_first_file, transaction_sequence_number);
      }
      if (remove_file)
      {
        _log_files.front().delete_file();
        _log_files.pop_front();
      }
      else
        break;
    }
  }

  //used to clean up haf wal if replay was requested
  void write_ahead_log_manager::clear_log()
  {
    std::unique_lock<std::mutex> lock(_mutex);
    while (_log_files.size() > 0)
    {
      _log_files.front().delete_file();
      _log_files.pop_front();
    }
  }

  /* static */ write_ahead_log_manager::sequence_number_t write_ahead_log_manager::get_sequence_number_after(const sequence_number_t sequence_number)
  {
    return sequence_number == std::numeric_limits<sequence_number_t>::max() ? 0 : sequence_number + 1;
  }

  write_ahead_log_manager::sequence_number_t write_ahead_log_manager::get_next_sequence_number()
  {
    _last_sequence_number = _last_sequence_number ? get_sequence_number_after(*_last_sequence_number) : 0;
    return *_last_sequence_number;
  }

  std::optional<write_ahead_log_manager::sequence_number_t> write_ahead_log_manager::compute_last_sequence_number()
  {
    for (auto i = _log_files.rbegin(); i != _log_files.rend(); ++i)
      if (!i->is_empty())
        return i->get_last_sequence_number();
    return std::nullopt;
  }

  std::optional<write_ahead_log_manager::sequence_number_t> write_ahead_log_manager::get_last_sequence_number()
  {
    std::unique_lock<std::mutex> lock(_mutex);
    return _last_sequence_number;
  }

  void write_ahead_log_manager::replay_transactions_after(sequence_number_t last_sequence_number, std::function<void(sequence_number_t, std::string_view)> replay_function)
  {
    std::unique_lock<std::mutex> lock(_mutex);
    for (log_file& file : _log_files)
    {
      if (file.is_empty() || is_less_than(file.get_last_sequence_number(), last_sequence_number))
        continue;

      file.for_each_record([&](sequence_number_t sequence_number, std::string_view sql) {
        if (is_less_than(last_sequence_number, sequence_number))
          replay_function(sequence_number, sql);
      });
    }
  }

} // namespace hive::plugins::sql_serializer

