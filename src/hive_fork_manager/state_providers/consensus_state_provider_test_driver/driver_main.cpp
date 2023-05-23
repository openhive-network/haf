//#include "operation_base.hpp"

#include <hive/protocol/forward_impacted.hpp>
//#include <hive/protocol/misc_utilities.hpp>

//#include <fc/io/json.hpp>
//#include <fc/string.hpp>

#include <vector>

#include <chrono>

#include <iomanip>

#include "../../shared_lib/consensus_state_provider_replay.hpp"




#include <iostream>
#include <boost/program_options.hpp>



#include <iostream>
#include <fstream>
#include <string>
#include <sstream>

unsigned long get_memory_usage_kb() {
    std::ifstream status_file("/proc/self/status");
    std::string line;

    while (std::getline(status_file, line)) {
        if (line.find("VmRSS") != std::string::npos) {
            std::istringstream iss(line);
            std::string key;
            unsigned long value;
            iss >> key >> value;
            return value;
        }
    }

    return 0;
}


namespace po = boost::program_options;

int main(int argc, char *argv[]) {
    int from, to, step;
    std::string  context, postgres_url, consensus_state_provider_storage;

    po::options_description desc("Allowed options");
    desc.add_options()
        ("help,h", "produce help message")
        ("from,f", po::value<int>(&from)->default_value(1), "from value (default: 1)")
        ("to,t", po::value<int>(&to)->default_value(5000000), "to value (default: 5000000)")
        ("step,e", po::value<int>(&step)->default_value(100000), "step value (default: 100000)")
        ("context,c", po::value<std::string>(&context)->default_value("driverc"), "context (default: driverc)")
        ("postgres_url,p", po::value<std::string>(&postgres_url)->default_value("postgresql:///haf_block_log"), "PostgreSQL URL (default: postgresql:///haf_block_log)")
        ("consensus_state_provider_storage,s", po::value<std::string>(&consensus_state_provider_storage)->default_value("/home/hived/datadir/consensus_state_provider"), "Consensus state provider storage (optional)")
        ;


    po::variables_map vm;
    try {
        po::store(po::parse_command_line(argc, argv, desc), vm);

        if (vm.count("help")) {
            std::cout << desc << "\n";
            return 1;
        }

        po::notify(vm);
    } catch (const po::error &e) {
        std::cerr << "Error: " << e.what() << "\n";
        std::cerr << desc << "\n";
        return 1;
    }


    std::locale::global(std::locale(""));
    std::cout.imbue(std::locale());

    

    std::cout << "from: " << std::fixed << std::setprecision(0) << std::showbase << from << "\n";
    std::cout << "to: " << std::fixed << std::setprecision(0) << std::showbase << to << "\n";
    std::cout << "step: " << std::fixed << std::setprecision(0) << std::showbase << step << "\n";
    std::cout << "context: " << context << "\n";
    std::cout << "postgres_url: " << postgres_url << "\n";
    std::cout << "consensus_state_provider_storage: " << consensus_state_provider_storage << "\n";

    auto alltogether_start = std::chrono::high_resolution_clock::now();

    bool ok = true;
    for (int i = from; i < to; i += step)
    {
        int current_step_end = std::min(i + step - 1, to);

        std::cout << "Stepping from " << std::fixed << std::setprecision(0) << std::showbase << i << " to " << current_step_end << " ";

        auto start = std::chrono::high_resolution_clock::now();

        auto step_ok = consensus_state_provider::consensus_state_provider_replay_impl(
            i,
            current_step_end,
            context.c_str(),
            postgres_url.c_str(),
            consensus_state_provider_storage.c_str());

        auto end = std::chrono::high_resolution_clock::now();            
        auto duration = std::chrono::duration_cast<std::chrono::seconds>(end - start);
        print_duration("All", duration);
        std::cout << "Memory (KB): " << get_memory_usage_kb() << std::endl;



        if(current_step_end == 5000000)
        {
            using namespace consensus_state_provider;
            collected_account_balances_collection_t account_balances = collect_current_all_accounts_balances(context.c_str());

            std::sort(account_balances.begin(), account_balances.end(),
                      [](const collected_account_balances_t& a, const collected_account_balances_t& b) { return a.balance > b.balance; });

            collected_account_balances_collection_t top_15_results(account_balances.begin(), account_balances.begin() + 15);

            for(const auto& account : top_15_results)
            {
              std::cout << "Account: " << account.account_name << ", Balance: " << account.balance << std::endl;
            }

            // clang-format off
            std::vector<std::tuple<std::string, long long>> expected_values = 
            {
                std::make_tuple("steemit", 4778859891),
                std::make_tuple("poloniex", 1931250425),
                std::make_tuple("bittrex", 499025114),
                std::make_tuple("steemit2", 197446682),
                std::make_tuple("aurel", 97417738),
                std::make_tuple("openledger", 52275479),
                std::make_tuple("ben", 50968139),
                std::make_tuple("blocktrades", 29594875),
                std::make_tuple("steem", 29315310),
                std::make_tuple("imadev", 23787999),
                std::make_tuple("smooth", 20998219),
                std::make_tuple("steemit60", 20000000),
                std::make_tuple("taker", 15014283),
                std::make_tuple("steemit1", 10000205),
                std::make_tuple("ashold882015", 9895158)
            };
            // clang-format on

            bool is_equal = std::equal(top_15_results.begin(), top_15_results.end(), expected_values.begin(),
                                       [](const collected_account_balances_t& account, const std::tuple<std::string, long long>& expected) {
                                         return account.account_name == std::get<0>(expected) && account.balance == std::get<1>(expected);
                                       });

            // Output the comparison result
            if(is_equal)
            {
              std::cout << "The sorted result MATCHES the expected values." << std::endl;
            }
            else
            {
              std::cout << "The sorted result does NOT match the expected values." << std::endl;
            }
        }

        if(!step_ok)
        {
            ok = false;
            break;
        }
    }    

    auto alltogether_end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::seconds>(alltogether_end - alltogether_start);
    print_duration("Alltogether", duration);

    return ok ? 0 : 1;
}
