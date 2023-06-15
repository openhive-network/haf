//#include "operation_base.hpp"

#include <hive/protocol/forward_impacted.hpp>
//#include <hive/protocol/misc_utilities.hpp>

//#include <fc/io/json.hpp>
//#include <fc/string.hpp>

#include <vector>

#include <chrono>

#include <iomanip>

#include "../../shared_lib/consensus_state_provider_replay.hpp"
#include "../../shared_lib/time_probe.hpp" 




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

int main(int argc, char *argv[]) 
{
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

    consensus_state_provider::time_probe alltogether_time_probe; alltogether_time_probe.start();


    bool ok = true;
    for (int i = from; i < to; i += step)
    {
        int current_step_end = std::min(i + step - 1, to);

        std::cout << "Stepping from " << std::fixed << std::setprecision(0) << std::showbase << i << " to " << current_step_end << " ";

        consensus_state_provider::time_probe all_time_probe; all_time_probe.start();

        auto step_ok = consensus_state_provider::consensus_state_provider_replay_impl(
            i,
            current_step_end,
            context.c_str(),
            postgres_url.c_str(),
            consensus_state_provider_storage.c_str());

        all_time_probe.stop(); all_time_probe.print_duration("All");
        std::cout << "Memory (KB): " << get_memory_usage_kb() << std::endl;

        std::vector<std::tuple<std::string, long long>> expected_values;
        if(current_step_end == 5000000)
        {
            // clang-format off
            expected_values = 
            {
                {"steemit", 4778859891},
                {"poloniex", 1931250425},
                {"bittrex", 499025114},
                {"steemit2", 197446682},
                {"aurel", 97417738},
                {"openledger", 52275479},
                {"ben", 50968139},
                {"blocktrades", 29594875},
                {"steem", 29315310},
                {"imadev", 23787999},
                {"smooth", 20998219},
                {"steemit60", 20000000},
                {"taker", 15014283},
                {"steemit1", 10000205},
                {"ashold882015", 9895158}
            };
            // clang-format on
        }
        else if(current_step_end == 23645964)
        {
            // clang-format off
            expected_values = 
            {
                {"bittrex", 22319508517},
                {"poloniex", 14479958335},
                {"binance-hot", 8183911450},
                {"huobi-withdrawal", 2963571300},
                {"steemit2", 2279627277},
                {"ben", 2213971486},
                {"imadev", 788297714},
                {"openledger-dex", 522742188},
                {"upbit-exchange", 477889426},
                {"dan", 471203861},
                {"muchfun", 415000004},
                {"cdec84", 335009000},
                {"dantheman", 300198008},
                {"amcq", 290000001},
                {"alpha", 272174106},
            };
            // clang-format on
        }
        else if(current_step_end == 68676504)
        {
            // clang-format off
            expected_values = 
            {
                {"upbitsteem", 84255436735},
                {"hive.fund", 57945295412},
                {"binance-hot", 22503269770},
                {"bittrex", 7230079627},
                {"bt20hivedkdnel", 4895067376},
                {"hot.dunamu", 4177964215},
                {"honey-swap", 4076035698},
                {"bithumbsend2", 2087406186},
                {"blocktrades", 1836388214},
                {"freedom", 1687237610},
                {"huobi-withdrawal", 1510659148},
                {"alpha", 1477208947},
                {"user.dunamu", 1239472613},
                {"mika", 987553199},
                {"gateiodeposit", 956191238},
            };
            // clang-format on
        }
        else if(current_step_end == 73964098)
        {
            // clang-format off
            expected_values = 
            {
                {"upbitsteem", 93077129841},
                {"hive.fund", 52850986437},
                {"binance-hot", 28693190263},
                {"bittrex", 5745379276},
                {"bithumbsend2", 5249525913},
                {"honey-swap", 4559244755},
                {"hot.dunamu", 3801547810},
                {"freedom", 2172552725},
                {"bt20hivedkdnel", 1895069766},
                {"darthknight", 1831354086},
                {"huobi-withdrawal", 1218250217},
                {"keestone", 953345779},
                {"gateiodeposit", 700293730},
                {"newsflash", 655071805},
                {"bhuz", 578502979},
            };
            // clang-format on
        }
        else if(current_step_end == 74106753)
        {
            // clang-format off
            expected_values = 
            {
                {"upbitsteem", 93077129841},
                {"hive.fund", 52718991035},
                {"binance-hot", 22849127680},
                {"bithumbsend2", 5354620236},
                {"bittrex", 4944739528},
                {"honey-swap", 4665903413},
                {"binance-hot2", 3791124997},
                {"hot.dunamu", 3392514212},
                {"freedom", 2185766269},
                {"bt20hivedkdnel", 1895069766},
                {"darthknight", 1836658652},
                {"huobi-withdrawal", 1207818132},
                {"keestone", 953345779},
                {"gateiodeposit", 710361370},
                {"newsflash", 655071851},
            };
            // clang-format on
        }


        if(!empty(expected_values))
        {

            using namespace consensus_state_provider;
            collected_account_balances_collection_t account_balances = collect_current_all_accounts_balances_impl(context.c_str(), consensus_state_provider_storage.c_str(), postgres_url.c_str());

            std::sort(account_balances.begin(), account_balances.end(),
                      [](const collected_account_balances_t& a, const collected_account_balances_t& b) { return a.balance > b.balance; });

            collected_account_balances_collection_t top_15_results(account_balances.begin(), account_balances.begin() + 15);

            for(const auto& account : top_15_results)
            {
              std::cout << "Account: " << account.account_name << ", Balance: " << account.balance << std::endl;
            }


            bool is_equal = std::equal(top_15_results.begin(), top_15_results.end(), expected_values.begin(),
                                       [](const collected_account_balances_t& account, const std::tuple<std::string, long long>& expected) {
                                         
                                         bool ok =  account.account_name == std::get<0>(expected) && account.balance == std::get<1>(expected);
                                         if(!ok)
                                         {
                                            std::cout << "Actual   account: " << account.account_name << ", Balance: " << account.balance << std::endl;
                                            std::cout << "Expected account: " << std::get<0>(expected)<< ", Balance: " << std::get<1>(expected) << std::endl;
                                         }
                                         return ok;

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




        auto expected_block_num = consensus_state_provider::consensus_state_provider_get_expected_block_num_impl(context.c_str(), consensus_state_provider_storage.c_str(), postgres_url.c_str());
        
        if(expected_block_num < current_step_end)
        {
            std::cout << "Exiting at the end of input data: " << expected_block_num - 1 << std::endl;
        }

        if(!step_ok || expected_block_num < current_step_end)
        {
            ok = false;
            break;
        }
    }    

    alltogether_time_probe.print_duration("Alltogether");

    return ok ? 0 : 1;
}

/*

Started on blockchain with 5000000 blocks, LIB: 4999980
('steemit', 4778859891, 70337438, 225671901920188893)
('poloniex', 1931250425, 158946758, 4404577000000)
('bittrex', 499025114, 81920425, 4404642000000)
('steemit2', 197446682, 106543552, 5213443854825)
('aurel', 97417738, 1457, 47962153427941)
('openledger', 52275479, 18607380, 11850514000000)
('ben', 50968139, 1415, 6599654505904881)
('blocktrades', 29594875, 77246982, 8172549681941451)
('steem', 29315310, 500001, 15636871956265)
('imadev', 23787999, 117353589, 445256469401562)
('smooth', 20998219, 599968, 6261692171889459)
('steemit60', 20000000, 31005142, 1000000000000)
('taker', 15014283, 535515, 4596963565191)
('steemit1', 10000205, 134872472, 1005084292327)
('ashold882015', 9895158, 134, 3101147621378)

        else if(current_step_end == 5000000)
        {
            // clang-format off
            expected_values = 
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
        }
        

Started on blockchain with 23645964
('bittrex', 22319508517, 9982418381, 8546709372209)
('poloniex', 14479958335, 472131272, 4404577000000)
('binance-hot', 8183911450, 3680, 1023055299)
('huobi-withdrawal', 2963571300, 3, 4079848926560)
('steemit2', 2279627277, 4992071, 97494724537487)
('ben', 2213971486, 929, 659751021)
('imadev', 788297714, 452, 445256469401562)
('openledger-dex', 522742188, 40952501, 1033789880)
('upbit-exchange', 477889426, 608800589, 10236655591659)
('dan', 471203861, 427118, 58822357508745)
('muchfun', 415000004, 103, 12360924266)
('cdec84', 335009000, 0, 6093749649)
('dantheman', 300198008, 98623, 212148717653)
('amcq', 290000001, 263989, 8808070581)
('alpha', 272174106, 10328619, 82084887877)



        if(current_step_end == 23645964)
        {
            // clang-format off
            expected_values = 
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
        }
        

Started on blockchain with 68676504
('upbitsteem', 84255436735, 2386398250, 0)
('hive.fund', 57945295412, 18926554396, 0)
('binance-hot', 22503269770, 3732, 194663308093)
('bittrex', 7230079627, 260752840, 8546751875750)
('bt20hivedkdnel', 4895067376, 0, 194817564163)
('hot.dunamu', 4177964215, 214692088, 1959892613804)
('honey-swap', 4076035698, 41453, 2941672427960603)
('bithumbsend2', 2087406186, 0, 3896350945398)
('blocktrades', 1836388214, 52981999, 18528143946987729)
('freedom', 1687237610, 917794, 23100048662529493)
('huobi-withdrawal', 1510659148, 4, 4960547606244)
('alpha', 1477208947, 5801, 12346558419189399)
('user.dunamu', 1239472613, 51222550, 1959434381935)
('mika', 987553199, 3986505, 3987699030141844)
('gateiodeposit', 956191238, 29, 19522873518)


        if(current_step_end == 5000000)
        {
            // clang-format off
            expected_values = 
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
        }
        


Started on blockchain with 73964098
('upbitsteem', 93077129841, 1388690854, 0)
('hive.fund', 52850986437, 20349043966, 0)
('binance-hot', 28693190263, 3732, 194663308093)
('bittrex', 5745379276, 208976385, 8546751875750)
('bithumbsend2', 5249525913, 0, 3896350945398)
('honey-swap', 4559244755, 41534, 2941866223981653)
('hot.dunamu', 3801547810, 144339860, 1959892613804)
('freedom', 2172552725, 1037669, 23100048662529493)
('bt20hivedkdnel', 1895069766, 0, 194817564163)
('darthknight', 1831354086, 287108, 8878054935498957)
('huobi-withdrawal', 1218250217, 4, 4960547606244)
('keestone', 953345779, 1763464, 0)
('gateiodeposit', 700293730, 29, 19522873518)
('newsflash', 655071805, 4, 36914293435806)
('bhuz', 578502979, 13, 691328006278866)

        if(current_step_end == 5000000)
        {
            // clang-format off
            expected_values = 
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
        }
        



Started on blockchain with 74106753
('upbitsteem', 93077129841, 2462437328, 0)
('hive.fund', 52718991035, 20865460662, 0)
('binance-hot', 22849127680, 3732, 194663308093)
('bithumbsend2', 5354620236, 0, 3896350945398)
('bittrex', 4944739528, 206248245, 8546751875750)
('honey-swap', 4665903413, 41539, 2941866223981653)
('binance-hot2', 3791124997, 0, 0)
('hot.dunamu', 3392514212, 215734001, 1959892613804)
('freedom', 2185766269, 1043696, 23100048662529493)
('bt20hivedkdnel', 1895069766, 0, 194817564163)
('darthknight', 1836658652, 290067, 8878054935498957)
('huobi-withdrawal', 1207818132, 4, 4960547606244)
('keestone', 953345779, 1763464, 0)
('gateiodeposit', 710361370, 29, 19522873518)
('newsflash', 655071851, 8, 36914293435806)



        if(current_step_end == 5000000)
        {
            // clang-format off
            expected_values = 
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
        }
        
*/
