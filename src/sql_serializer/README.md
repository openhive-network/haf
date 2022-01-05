# SQL_SERIALIZER
It is a hived plugin which is resposible to dump blocks data to hive_fork_manager
and informs it about important events occurence in the node for example a micro-fork occurence.

## Build
As other hived plugins also sql_serializer is compiled during compiling the hived program.
There is a trick which allows for this: cmake scripts creates a symbolic
link to sql_serializer sources in `hive/libraries/plugins`, then cmake script of hive
submodule find the plugins sources together with sql_serializer - it follows the symbolic link.

## Setup
You need to add plugin to the hived node config.ini file:

```
plugin = sql_serializer
psql-url = dbname=block_log user=postgres password=pass hostaddr=127.0.0.1 port=5432
psql-index-threshold = 1000000
psql-operations-threads-number = 5
psql-transactions-threads-number = 2
psql-account-operations-threads-number = 2
psql-enable-accounts-dump = true
psql-force-open-inconsistent = false
```

## Parameters
The sql_serializer extend hived about new parameters:
* **psql-url** contains line of parameters which are used to connect to the database
    - *dbname* name of the database on PostgreSQL cluster
    - *user* a Postgres role name used to connect to the database
    - *hostaddr* an internet address of the PostgreSQL cluster
    - *port* a TCP port on wich the PostgreSQL cluster is listening

  ```
  Example:
  psql-url = dbname=block_log user=postgres password=pass hostaddr=127.0.0.1 port=5432
  ```
* **psql-index-threshold** [default: 1'000'000] an integer number that represents the limit of blocks which allows continuing synchronizing blocks after the node restart without disabling SQL indexes. During massive synchronization
  (for example, using block_log) inserting a large number of blocks of data will be drastically slowed down by the indexes, so it
  is good to remove them, but removed indexes have to be recreated before the live sync start (otherwise HAF will be too slow for applications).
  Recreating indexes lasts a lot of time (depending on the number of blocks in the database) and there is a need to find a trade-off: is
  better to sync slowly not a large number of blocks with indexes and avoid delay for re-creating them, or is it better
  to faster synchronize a large number of blocks and deal with the delay. psql-index-threshold is the limit of a number of blocks that will
  be synchronized slowly with enabled indexes.
* **psql-operations-threads-number**[default: 5] a number of threads which are used to dump blockchain operations to the database. Operations
  are the biggest part of the block's data. because there is a large number of operations to sync. The operations are goruped
  to packages which are dumped conurently to the database.
* **psql-transactions-threads-number**[default: 2] a number of threads used to dump transaction to the database
* **psql-account-operations-threads-number**[default: 2] a number of threads used to dump account operations to the database
* **psql-enable-accounts-dump**[default: true] a boolen value, if true account and account operations will be dumped during the blocks synchronization
* **psql-force-open-inconsistent**[default: false] a boolean value, if true the plugin will connect to the database even it is in inconsitent state.
  During syncing blocks it may happen that the hived will crash, and the irreversible part of blocks data in the database may stay inconsistent because
  threads which dumped blocks were brutally broken. The HAF database contains information about inconsistency of the data, and during restart of the
  hived sql_serialzier will fail. The Hive Fork Manager has functionallity that repairs the datatbase, but it may last very long time and thus it is required
  to explictly force open the database and start the rescue action by using switch: `-psql-force-open-inconsistent=true`

### Example hived command

	./hived --replay-blockchain --stop-replay-at-block 5000000 --exit-after-replay -d ../../../datadir --force-replay --psql-index-threshold 65432

## Synchronization blocks process
The sql_serializer is connected to chainbase of hive node by notification ( boost signals ). The chain base notifies about starting/ending
reindex process (replay form block.log), processes a new blocks, a new transaction and a new operations.
### 1. Synchronization state
The sql_serializer works in different ways when the node is reindexing blocks from block.log, from network (using P2P), and
when is live syncing new blocks (is processing blocks that are no more than 1 minute older than the network's head block). This is important
aspect of sql_serializer because it is strongly connected with synchronization performance. Below is a state machine diagram
for synchronization:

![](./doc/sync_state_machine.png)

The current state of synchronization is controlled by the object of class [indexation_state](./include/hive/plugins/sql_serializer/indexation_state.hpp).

### 2. Collect data from hive chainbase
In each state of synchronization blocks data are cached to the [cached_data_t](./include/hive/plugins/sql_serializer/cached_data.h). 

![](./doc/collecting_block_in_cache.png)

At the end of ```sql_serializer_plugin_impl::on_post_apply_block``` method ```indexation_state::trigger_data_flush```
that will dump or not the blocks to the datatabse depending on the synchronization state.

### 3. Dumping cached blocks data to PostgreSQL database
There are two class which are responisble to dump blocks data to hive_fork_manager.
- [reindex_data_dumper](./include/hive/plugins/sql_serializer/reindex_data_dumper.h)
  It is used to massively dump only irreversible blocks to the database directly to irrevesible tables in hive_fork_manager.
  The dumper is optimized to dump batches of large number of blocks. Each batch is dumped using several threads with separated
  conections to the database. The threads do not wait for each other, so during using 'reindex_dumper' FOREIGN KEY-s constraints
  have to be disabled. Because threads do no wait for each other the contetnt of irreversible tables of hive fork manager may
  be inconsistent, there is an rendvouz pattern used to inform the datatabse which block is already known as a head of fully dumped, consistent blocks.
  
  ![](./doc/reindex_dumper.png)
- [livesync_data_dumper](./include/hive/plugins/sql_serializer/livesync_data_dumper.h)
  The dumper is used to dump one block in each turn using `hive.push_block` hive_fork_manager function. Both reversible
  and irreversible blocks can be dumped. The data of the block are processed by  few threads which convert them
  to std::string-s that contains SQL presentation of irreversible tables rows. When all the threads finish processing
  blocks data then randevouz object forms SQL syntence for calling `hive.push_block` with the prepared strings as it's parameters
  and call the function on the database.
  ![](./doc/livesync_dumper.png)

The dumpers are triggered by the implementation of `indexation_state::flush_trigger`, that make decision if cached data can be dumped or not. There
are 3 implemantation of triggers:
- **reindex_flush_trigger**
  <p>Blocks are dumped when 1000 blocks are in cache.
- **p2p_flush_trigger**
  <p>Blocks are dumped when at least 1000 blocks are in cache, but dumped are only those blocks which are irreversible.
- **live_flush_trigger**
  <p>Each block is dumped immediatly when cached.

On each state of indexation there is a different combination of the flush_trigger and a dumper:
- **p2_psync** : p2p_flush_trigger + reindex_data_dumper
- **reindex** : reindex_flush_trigger + reindex_data_dumper
- **live** : live_flush_trigger + livesync_data_dumper