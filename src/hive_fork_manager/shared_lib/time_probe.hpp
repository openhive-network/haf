#pragma once
#include <chrono>
#include <iostream>

namespace consensus_state_provider 
{

class time_probe
{
 public:
  time_probe()
  {
    reset();
  }

  void reset() { duration = std::chrono::nanoseconds(); }

  void start() { start_time = std::chrono::high_resolution_clock::now(); }

  void stop() { duration += std::chrono::high_resolution_clock::now() - start_time; }

  void print_duration(const std::string& message)
  {
    auto minutes = std::chrono::duration_cast<std::chrono::minutes>(duration);
    auto seconds =
        std::chrono::duration_cast<std::chrono::seconds>(duration % std::chrono::minutes(1));

    //std::cout << message << ":" << minutes.count() << "'" << seconds.count() << "\" ";
  }

 private:
  std::chrono::nanoseconds duration;
  std::chrono::high_resolution_clock::time_point start_time;
};
}  // namespace consensus_state_provider