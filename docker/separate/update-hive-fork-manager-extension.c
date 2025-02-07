/* Simple wrapper to call hive_fork_manager_update_script_generator.sh that can be made setuid root */
#define STR(x) #x
#define XSTR(x) STR(x)

#include <unistd.h>
int main() {
  setuid(0);
  execle("/bin/bash","bash","/usr/share/postgresql/" XSTR(POSTGRES_MAJOR_VERSION) "/extension/hive_fork_manager_update_script_generator.sh", (char*)NULL, (char*)NULL);
}
