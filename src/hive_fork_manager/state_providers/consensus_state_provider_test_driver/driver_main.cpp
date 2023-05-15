//#include "operation_base.hpp"

//#include <hive/protocol/forward_impacted.hpp>
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


    bool ok = true;
    for (int i = from; i < to; i += step)
    {
        std::cout << "Stepping from " << std::fixed << std::setprecision(0) << std::showbase << i << " to " << i + step - 1 << " ";

        auto start = std::chrono::high_resolution_clock::now();

        auto step_ok = consensus_state_provider::consensus_state_provider_replay_impl(
            i,
            i+ step -1,
            context.c_str(),
            postgres_url.c_str(),
            consensus_state_provider_storage.c_str());

        auto end = std::chrono::high_resolution_clock::now();            
        auto duration = std::chrono::duration_cast<std::chrono::seconds>(end - start);
        print_duration("All", duration);
        std::cout << "Memory (KB): " << get_memory_usage_kb() << std::endl;
        


        if(!step_ok)
        {
            ok = false;
            break;
        }
    }    
    return ok ? 0 : 1;
}
