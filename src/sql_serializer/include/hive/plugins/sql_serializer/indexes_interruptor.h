#pragma once

#include <string>
#include <thread>
#include <atomic>

namespace appbase { class application; }

namespace hive::plugins::sql_serializer {

class indexes_interruptor {
public:
  indexes_interruptor(const std::string& db_url, appbase::application& app);
  ~indexes_interruptor();

  indexes_interruptor(const indexes_interruptor&) = delete;
  indexes_interruptor& operator=(const indexes_interruptor&) = delete;

private:
  void run();

  const std::string _db_url;
  appbase::application& _app;
  std::thread _worker;
  std::atomic<bool> _stop{false};
};

} // namespace hive::plugins::sql_serializer
