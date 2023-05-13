#include "operation_base.hpp"

#include <hive/protocol/forward_impacted.hpp>
#include <hive/protocol/misc_utilities.hpp>

#include <fc/io/json.hpp>
#include <fc/string.hpp>

#include <vector>





#include "consensus_state_provider_replay.hpp"



// int main()
// {
//     auto ok = consensus_state_provider::consensus_state_provider_replay_impl(
//         1,
//         5000000,
//         "driverc",
//         "postgresql:///haf_block_log",
//         "/home/hived/datadir/consensus_state_provider");
//     return ok ? 0 : 1;
// }

#include <iostream>
#include <boost/program_options.hpp>

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

    std::cout << "from: " << from << "\n";
    std::cout << "to: " << to << "\n";
    std::cout << "context: " << context << "\n";
    std::cout << "postgres_url: " << postgres_url << "\n";
    std::cout << "consensus_state_provider_storage: " << consensus_state_provider_storage << "\n";


    bool ok = true;
    for (int i = from; i < to; i += step)
    {
        std::cout << "Stepping from " << i << " to " << i + step - 1<< "\n";

       
        auto step_ok = consensus_state_provider::consensus_state_provider_replay_impl(
            i,
            i+ step -1,
            context.c_str(),
            postgres_url.c_str(),
            consensus_state_provider_storage.c_str());
        if(!step_ok)
        {
            ok = false;
            break;
        }
    }    
    return ok ? 0 : 1;
}
