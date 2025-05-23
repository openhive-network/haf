# HIVE_FORK_MANAGER
The fork manager is composed of SQL scripts to create a Postgres extension that provides an API that simplifies reverting app data when a fork switch occurs on the Hive blockchain.

## Installation
It is possible to install the fork manager in two forms - as a regular Postgres extension or as a simple set of tables and functions, but installation as an extension is recommended.

### Install fork manager as a postgres extension
1. Create a `build` directory somewhere and make it the current working directory.
2. `cmake <path to root of the project psql_tools>`
3. `make extension.hive_fork_manager`
4. `make install`

To start using the extension in a new database, create a database and execute the psql command to install the extension:
1. `createdb -O hive my_db_name`
2. `psql -d my_db_name -c "CREATE EXTENSION hive_fork_manager CASCADE;"`
The CASCADE option is needed to automatically install extensions that the hive_fork_manager depends on.


### Alternatively, you can manually execute the SQL scripts to directly install the fork manager
The required ordering of the sql scripts is included in the cmake file [src/hive_fork_manager/CMakeLists.txt](./CMakeLists.txt).
Execute each script one-by-one with `psql` as in this example: `psql -d my_db_name -a -f  context_rewind/data_schema.sql`

## Architecture
All elements of the fork manager are organized into two schemas: **`hive`** and **`hafd`**.
- **Schema `hafd`** contains data types and data collected by the Hive Application Framework (HAF). These objects are critical to the system and **cannot be modified or dropped** during the HAF update process. This is because there is no efficient or safe method to alter the data that has already been collected in the tables.
- **Schema `hive`**, on the other hand, contains types and run-time code definitions, such as functions, procedures, and views. These objects **can be freely modified or removed** during updates, as they are not tied to persistent data but are responsible for executing run-time logic.
- **Schema `hive_update`**, contains only functions which are used during updating HAF.

As part of the update operation, **the `hive` schema and all its objects are dropped at the beginning** of the update process to ensure a clean environment for the new definitions.

 

The fork manager is written using an "events source" architecture style. This means that during live sync, hived only schedules new events (by writing block data to the database), and then HAF apps process them at their own pace (by using fork manager API queries to get alerted whenever hived has modified the block data).

The fork manager is designed to work with [transaction isolation level](https://www.postgresql.org/docs/10/transaction-iso.html) `READ COMMITTED`, which is the default for PostgreSQL.

The fork manager enables multiple Hive apps to use a single block database and process blocks completely independently of each other (apps do not need to place locks on the shared blockchain data tables).

Hive block data is stored in two separated, but similar tables: irreversible and reversible blocks. Whenever a block becomes irreversible, hived uses the hive_fork_manager api to signal that the associated data should be moved from the reversible tables to the irreversible tables.

A HAF app groups its tables into a named "context". A context name can only be composed of alphanumerical characters and underscores. An app's context holds information about its processed events, blocks, and the fork which is now being processed by the app. These pieces of information
are enough to automatically create views which combine irreversible and reversible block data seamlessly for queries by the app. The auto-constructed view names use the following template: '{context_schema}.{blocks|transactions|multi_signatures|operations}_view'.

### Overview of the fork manager and its interactions with hived and HAF apps
![alt text](./doc/evq_c3.png )

### Hived block-processing algorithm
![alt text](./doc/evq_hived_process_blocks.png)


### Requirements for an HAF app algorithm using the fork manager API
Only roles ( users ) which inherits from 'hive_applications_group' have access to 'The App API', and only these roles allow apps to work with 'hive_fork_manager'

Any HAF app must first create a context, then create its tables which inherit from `hive.<context_name>`. The context is owned and can be accessed only by the role which created it.

#### Recommended synchronization loop algorithm for applications
It turned out that most applications (if not all) have synchronization divided into stages relative
to the distance between the Hive head block and the application's last synchronized blocks.
Usually, at different stages, some indexes are dropped or created, which impacts synchronization performance.
Based on this observation, a simple algorithm for block synchronization is proposed.
In this algorithm, the context defines stages with a name, distance to the head block when they 
will be enabled, and the number of blocks to process in one turn.
There is no need to have knowledge about the fork manager's implementation details to correctly 
determine the range of blocks to synchronize, commit, and stop the application.

![alt text](./doc/evq_new_app_process_block.png)

1. The author of the application needs to divide synchronization into stages. Stages are defined here: [src/application_loop/stages.sql]
   There is a special stage LIVE, which is always chosen when application is working near to head block or on reversible blocks.
   There is also another special stage 'wait_for_haf' which is automatically set on an application when it waits for HAF entering to live blocks synchronization.
   In 'wait_for_haf' stage applications cannot process blocks because they won't get ranges of blocks for processing.
2. During the creation of a context, an array of stages needs to be passed to 'hive.app_create_context'. The array must contain LIVE stage, which is returned by 'hive.live_stage' function.
3. The procedure 'hive.app_next_iteration' will return the range of blocks to synchronize (as the out parameter _blocks_range) or NULL if there are no new blocks.
4. The name of the current stage of a context can be obtained with 'hive.get_current_stage_name'.
5. At the beginning of 'hive.app_next_iteration', a transaction commit is issued.
6. If the application needs to be stopped, then stop processing immediately after calling 'hive.app_next_iteration'.

#### Old still supported, most flexible but complicated algorithm
For the sake of compliance with applications that used the old fork manager version, the old method of
block synchronization is still supported. It is a complicated algorithm in which the application 
author needs to understand concepts such as massive sync, details of context attachments, the current
block state, and when to issue a commit. While this method has proven to be prone to bugs,
it offers more flexibility to applications without requiring predefined stages.

![alt text](./doc/evq_app_process_block.png)

A HAF app calls `hive.app_next_block` to get the next block number to process. If NULL was returned, the app must immediatly call `hive.app_next_block` again. Note: the app will automatically be blocked when it calls `hive.app_next_block` if there are no blocks to process. 

When a range of block numbers is returned by app_next_block, the app may edit its own tables and use the appropriate snapshot of the blocks
data by querying the '{context_schema}.{ blocks | transactions | operations | transactions_multisig }' views. These view present a data snapshot for the first block in the returned block range. If the number of blocks in the returned range is large, then it may be more efficient for the app to do a "massive sync" instead of syncing block-by-block.

To perform a massive sync, an app should detach the context, execute its sync algorithm using the block data, then reattach the context. This will eliminate the performance overhead associated with the triggers installed by the fork manager that monitor changes to the app's tables.

It is possible that an app's operation will be stopped for some reason during a massive sync (i.e. when its context is detached). To deal with this potential scenario, when an app is restarted it should check if its context is attached using `hive.app_context_is_attached`, and if not then it needs to attach again using `hive.app_context_attach` and then 'COMMIT' a pending transaction.

To attach the context, the app has to know the block number of the last processed block. An app in massive sync (detached context mode) should call `app_set_current_block_num` after processing a batch of blocks (just before commiting the new app state) to periodically update the current block number to allow proper context re-attachment. Note: this function should only be called during massive sync and to prevent it from being called during normal sync it will throw an exception if called with an attached context.

#### Note: an app's commit timing is important to preserve app consistentcy after an interruption
In order to make sure apps maintain a consistent state when interrupted and restarted, commits should be done
after changing all state associated with processing a block (or a batch of blocks during massive sync). 

The current_block_number is automatically incremented by app_get_next_block when a context is attached,
so DO NOT call commit after making this call until the app has finished processing the block 
(otherwise, if the app is interrupted during normal sync, it will think it has finished processing an unfinished block).

Similarly, when an app is operating with a detached context (in massive sync), do not make a commit call until
all blocks in a batch are fully processed AND the current_block_number has been updated using hive.app_set_current_block_num.

#### Using a group of contexts
In certain situations, it becomes necessary to ensure that multiple contexts are synchronized
and point to the same block. This synchronization of contexts allows for consistent behavior
across different applications. To achieve this, there are specific functions/procedures available, such as 'hive.app_next_iteration',
that operate on an array of contexts and move them synchronously.

When using synchronized contexts, it is of utmost importance to ensure that all the contexts within a group
are consistently in the same state. This means that the contexts shall always traverse blocks together within 
the same group of contexts passed to the functions.

#### Managing Indexes

Indexes in **HAF** are managed by **`hived`**, ensuring consistency, security, and optimal
query performance. The **Index Management API** is designed to manage indexes on **HAF-managed
tables** only. Applications must not create indexes manually on these tables. However, for
application-specific private tables, applications retain full control over index creation and
management.

##### - Registering an Index Dependency

Applications should use the function **`hive.register_index_dependency`** to declare an index
they require on **HAF-managed tables**. This function:
- Parses the **`CREATE INDEX`** command.
- Associates the index with a **specific application context**.
- Ensures that indexes are only created by **`hived`**, preventing direct modifications by
  applications.

##### Example Usage:
```sql
SELECT hive.register_index_dependency(
    'my_app_context',
    'CREATE INDEX my_index ON my_schema.my_table (column_name);'
);
```
This request is stored in **`hafd.indexes_constraints`**, and `hived` will later process and
create the required indexes.

##### - Checking Index Creation Status

Applications can check if `hived` has finished creating the registered indexes using
**`hive.check_if_registered_indexes_created`**.

##### Example Usage:
```sql
SELECT hive.check_if_registered_indexes_created('my_app_context');
```
- Returns `TRUE` if all indexes registered under the given application context are created.
- Returns `FALSE` if any index is still missing.

##### - Removing Index Dependencies

When an application no longer needs its registered indexes, it should call
**`hive.remove_index_dependencies`** to clean up the dependency records. However, indexes
are **not removed if other application contexts depend on them**. The system ensures that
indexes remain available until all dependent applications have deregistered their use.

##### Example Usage:
```sql
SELECT hive.remove_index_dependencies('my_app_context');
```
- This removes the application context from the index dependency list.
- If no other application contexts rely on the index, the index will be **dropped**.

##### - Index Creation Timing Considerations

The timing of index creation significantly impacts performance and system efficiency.
Applications should consider:

- **Before Synchronization:** Registering index dependencies prior to synchronization allows
  `hived` to incorporate these indexes during its initial setup. This ensures that indexes
  are built non-concurrently alongside other HAF indexes, leading to a streamlined process.

- **After Synchronization:** If indexes are registered post-synchronization, `hived` will create
  them concurrently to avoid disrupting operations. This may result in longer index creation
  times and increased resource usage.

**Recommendation:**
To optimize performance, applications should register their required indexes **before**
initiating synchronization. This approach ensures that index creation is integrated into the
synchronization process, improving efficiency and reducing system load.

#### Managing Table Vacuuming

`hived` is responsible for maintaining the integrity and performance of the database by executing
periodic vacuum operations at optimal moments. To enhance efficiency and prevent table bloat,
an API for managing table vacuuming has been introduced. This API allows applications to request
vacuuming for specific tables while ensuring that excessive vacuum operations do not negatively
impact system performance.

#####  API Functions

##### Requesting Table Vacuuming
Applications can request vacuuming for a table using the function **`hive.app_request_table_vacuum`**.
This function:
- Inserts a vacuum request for the specified table.
- Optionally checks if the table has been vacuumed recently to avoid redundant operations.
- Updates the request status to ensure that the vacuuming process is tracked properly.

###### Example Usage:
An application can request vacuuming of a specific table, ensuring that it has not been vacuumed
within a given interval. If the table was vacuumed recently, the request will be ignored.

```sql
-- Request vacuuming for 'my_table' if it has not been vacuumed in the last hour
SELECT hive.app_request_table_vacuum('my_table', INTERVAL '1 hour');
```

#### Using HAF built-in roles
Based on extensive experience with a diverse range of applications, it is recommended to configure Postgres roles
in accordance with the guidelines depicted in the image below. This illustration provides a comprehensive overview
of how to effectively leverage HAF built-in roles for both application-specific and administrative purposes.
![alt text](./doc/roles.png)

##### Impersonate roles
Usually the applications should have two roles, one which owns the context-creates it and modify application data,
and second which is used  only to read application outcome tables. Such setup separates private role which executes
an application algorithm from a role which is used by the public interface to have access to the application results.

Certain applications utilize a group of contexts which combines contexts from different applications. The owners roles
of grouped applications must be explicitly granted membership in the primary application owner role.
This guarantees that the main application owner role can edit group of contexts with hfm api (see 'hive.can_impersonate' ).

### Non-forking apps
It is expected that some apps will only want to process blocks after they become irreversible. 

For example, some apps perform irreversible external operations such as a transfer of funds on a blockchain which could result in a financial loss to the app's operator or users in the case of a blockchain fork. One of the most common examples of such an app would be be a transaction scanner used by an exchange to detect cryptocurrency deposits. 

Other apps require very high performance, and don't want to incur the extra performance overhead associated with maintaining the data required to rollback blocks in the case of a fork. In such case, it may make sense to trade off the responsiveness of presenting the most recent blockchain data in order to create an app that can respond to api queries faster and support more users.

HAF distinguish which appl will only traverse irreversible block data. This means that calls to `hive.app_next_iteration` will return only the range of irreversible blocks which are not already processed or NULL (blocks that are not yet marked as irreversible will be excluded). Similarly, the set of views for an irreversible context only deliver a snapshot of irreversible data up to the block already processed by the app.
The user needs to decide if an application is non-forking, he can do this during creation af a context with 'hive.app_create_context' and passing an argument
'_is_forking' = FALSE.

It is possible to change an already created context from non-forking to forking and vice versa with methods
`hive.app_context_set_non_forking(context_name)` and `hive.app_context_set_forking(context_name)`

:warning: **Switching from forking to non-forking appl will delete all its reversible data**

In summary, a non-forking HAF appl is coded in much the same way as a forking app (making it relatively easy to change the app's code to operate in either of these two modes), but a non-forking app only served up information about irreversible blocks.

### Sharing tables with other HAF apps
If an app wants to expose some of its tables for reading by other apps, then it  only needs to grant the SELECT privilege on such tables to hive_applications_group.
```
GRANT SELECT ON my_table TO hive_applications_group;
```
:warning: An app which uses tables exposed by another app must be written taking into account that apps work at different speeds, and they may contain data computed for different forks and block ranges.

### Important notice about irreversible data
:warning: **Although reversible and irreversible block tables are directly visible to apps, these tables should not be queried directly. It is expected that the structure of the underlying tables may change in the future, but the structure of a context's views will likely stay constant. This means that any app which ignores this warning and directly reads the blockchain tables instead of the views may need to be refactored in the future to use newer versions of the fork manager.**

### Examples of the app
Two app examples written in Python3 were prapared. Both programs use `sqlalchemy` package as a database engine. The apps are very simple: both of them collect the number of transaction per day and prepare histograms in a table named `trx_histogram`.

One is a non-forking app: it only operates on blocks after they become irreversible. The second app works on the most recent blocks in the blockchain and supports rolling back its data whenever there is a blockchain fork.These example apps are here:
- forking app [doc/examples/hive_fork_app.py](./doc/examples/hive_fork_app.py)
- non-forking app [doc/examples/hive_non_fork_app.py](./doc/examples/hive_non_fork_app.py)
- forking app with a state provider [doc/examples/hive_accounts_state_provider.py](./doc/examples/hive_accounts_state_provider.py)

The forking and non-forking app are very similar, the only difference is in the lines which create a 'trx_histogram' table: the table in the forking app
inherits from`hive.trx_histogram` to register it into the context 'trx_histogram'. Here is a diff of the two apps:
```diff
--- hive_non_fork_app.py
+++ hive_fork_app.py
@@ -6 +6 @@
-SQL_CREATE_HISTOGRAM_TABLE = """
+SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE = """
@@ -11 +11,2 @@
-    """
+    INHERITS( hive.{} )
+    """.format( APPLICATION_CONTEXT )
@@ -51 +52 @@
-        db_connection.execute( SQL_CREATE_HISTOGRAM_TABLE )
+        db_connection.execute( SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE )
```

To switch from non-forking app to a forking one, all the app's tables have to be registered in contexts using the `hive.app_register_table` method.

### apps without their own tables
It turns out that some apps may not need to collect data into their own specific tables, because tables of the Hive Fork Manager
contain all the data the need. One example of such an app is the `HAF Account History (aka hafah)` app. Such apps do not need to create contexts and implement "the HAF app algorithm".
Instead such apps can just read the data for the current HEAD BLOCK using the views:
* hive.account_operations_view
* hive.accounts_view
* hive.blocks_view
* hive.transactions_view
* hive.operations_view_extended
* hive.operations_view
* hive.transactions_multisig_view
* hive.applied_hardforks_view

#### It is possible to get only irreversible block data
The apps without their own tables may be interested only in data from blocks that have become irreversible.
Here are views which return only irreversible data:
* hive.irreversible_account_operations_view
* hive.irreversible_accounts_view
* hive.irreversible_blocks_view
* hive.irreversible_transactions_view
* hive.irreversible_operations_view
* hive.irreversible_operations_view_extended
* hive.irreversible_transactions_multisig_view
* hive.irreversible_applied_hardforks_view


## Shared lib
There are some functions that can be done efficiently only with low-level code such as C/C++. Moreover, sometimes there is a need to
reuse some code already working in hived, and execute it inside Hive Fork Manager or a HAF app. One example is parsing an operation's JSON to get the list
of accounts impacted by the operation. Such functionality was already implemented in hived and there is no sense to implement this code again in a new language.
The folder 'shared_lib' contains an implementation of a shared library which is loaded and used by Hive Fork Manger extension.
The apps may call functions from this library with the SQL interface prepared by the extension.

## State Providers Library
There are examples of HAF apps that generated generic data such that their tables could be used by a wide range of other HAF apps.
The tables present in a more convenient way some part of the blockchain state included in the original block data.
Some of the common apps are embedded inside hive_fork_manager in the form of state providers: tables definitions and the code which fill these tables with data.

### Basic concept
A state provider is a SQL code that contains tables definitions and methods which fill those tables. An app may import a state provider with the SQL command `hive.app_state_provider_import( _state_name, _context )`. 

During import, new tables are created and registered in the app's context. Next, during block processing, the app needs to call `hive.app_state_provider_import( range_of_blocks )` to update the tables created by imported states providers.

The import of 'state providers' must be done by an app before any call of its massive sync or hive.app_next_block (in other words, the state providers must be imported before any blocks are processed). Repeating an import more than once does nothing.

### A state provider structure
Each state provider is a SQL file placed in the `state_providers` folder and defines these functions:

* `hive.start_provider_<provider_name>( context )`
  The function gets app context name and creates tables to hold the state.
  The tables name have format `hive.<context_name>_<base table_name>` and returns list of created tables names.

* `hive.update_state_provider_<provider_name>( first_block, last_block, context )`
  The function updates all 'state providers' tables registered in the context.

* `hive.drop_state_provider_<provider_name>( _context hafd.context_name )`
  The function drops all tables created by the state provider for a given context.

### How to add a new state provider
The template for creating a new state provider is here: [state_providers/state_provider.template](state_providers/state_provider.template).
You may copy the template, change the file extension to .sql,  add it to the CMakeLists.txt, and change '<provider_name>' in the new file to a new state provider name.
After this, the enum `hafd.state_providers` has to be extended with the new provider name.

### State providers and forks
When the context is a non-forking one, then the state provider's tables are not registered to be rewound during a fork servicing. When the context
is a forking one, the state provider's tables are registered with the forking mechanism and will be rewound during forks, just like the app's tables. When the context is changing from a non-forking to a forking one, then the provider's tables are registered to be rewound in the case of a fork.

### State providers API
Apps can import, update and drop state providers with these functions:
* `hive.app_state_provider_import( state_provider, _context )`
* `hive.app_state_providers_update( _first_block, _last_block, _context )`
* `hive.app_state_provider_drop( state_provider, _context )`


### Why we introduced States Providers instead of delivering regular apps?
The problem is that HAF apps work with different speeds, so they work on data snapshots from different blockchain times.
If we delivered state providers as regular apps, then all user apps won't be synchronized with the delivered apps, and the user's apps might read data from prepared apps which is not synced to their own blockchain time.

### Why we introduced The States Providers instead of extending the set of reversible/irreversible tables?
There is one big difference between reversible data and other tables - reversible data are only inserted or removed ( whole rows are inserted or removed )
, other tables can also be updated ( fields in particular row may be updated ). Whole reversible/irreversible mechanics is based on assumption
that the rows are only inserted or removed when a fork is serviced. 

### Disadvantages
Each app which imports any 'state provider' gets the tables exclusively for its PostgreSQL Role. A lot of data may be
redundant in the case when a few apps use the same state provider because each of them has its own private instance of its tables.
It may look redundant for some cases, but indeed there is no other method to guarantee consistency between the provider's
state and other app's tables. Even small differences between head blocks of two apps may result in large differences between contents of their provider's tables

## Important implementation details
### REVERSIBLE AND IRREVERSIBLE BLOCKS
IRREVERSIBLE BLOCKS is a set of database tables for blocks which the blockchain considers irreversible - they will never change (i.e. they can no longer be reverted by a fork switch).
These tables are defined in [src/hive_fork_manager/irreversible_blocks.sql](./irreversible_blocks.sql). Hived may push massivly block data into irreversible tables and the data may be temporarily inconsistant.

Hived pushes MASSIVE_SYNC_EVENT and NEW_IRREVERSIBLE_EVENT to mark the block number for which data is consistent so that it can be read directly from the irreversible tables.

REVERSIBLE BLOCKS is a set of database tables for blocks which could still be reverted by a fork switch.
These tables are defined in [src/hive_fork_manager/reversible_blocks.sql](./reversible_blocks.sql)

Each app should work on a snapshot of block information, which is a combination of reversible and irreversible information based on the current status of the app's context (status being the state of the app's last processed block and the associated fork for that block).

Because apps may work at different speeds, the fork manager has to hold reversible blocks information for every block and fork not already processed by any of the apps. This requires an efficient data structure. Fortunately the solution is quite simple - it is enough to add
a fork id to the block data inserted by hived to the irreversible blocks table. The fork manager manages forks ids - 
information about each fork is stored in the hafd.fork table. When 'hived' pushes a new block with a call to `hive.push_block`, the fork manager adds information about the current fork to a new reversible data row. Reversible data tables are presented in a generalised form in the example below:

| block_num| fork id | data      |
|----------|---------|-----------|
|    1     |    1    |  DATA_11  |
|    2     |    1    |  DATA_21  |
|    3     |    1    |  DATA_31  |
|    2     |    2    |  DATA_22  |
|    3     |    2    |  DATA_32  |
|    4     |    2    |  DATA_42  |
|    4     |    3    |  DATA_43  |

If an app is working on fork=2 and block_num=3 (this information is held by `hafd.contexts` ), then its snapshot of data for the example above is:

| block_num| fork id | data      |
|----------|---------|-----------|
|    1     |    1    |  DATA_11  |
|    2     |    2    |  DATA_22  |
|    3     |    2    |  DATA_32  |

This means that the snaphot of data for an app with context `app_context` can be obtained by filtering blocks and forks with a relativly simple SQL query like:
```
SELECT
      DISTINCT ON (block_num) block_num
    , fork_id
    , data
FROM data_reversible
JOIN hafd.contexts hc ON fork_id <= hc.fork_id AND block_num <= hc.current_block_num
WHERE hc.name = 'app_context'
ORDER BY block_num DESC, fork_id DESC
```
Remark: The fork_id is not a part of the real blockchain data, it is an artifact created by the fork manager, and may differ across instances of an app running in different HAF databases.

### EVENTS QUEUE
The events queue is a table defined in [src/hive_fork_manager/events_queue.sql](./events_queue.sql). Each row in the table represents an event. Each event is defined with its **id**, **type** and BIGINT **block_num** value. The `block_num` value has different meaning for different types of events:

|   event type     | block_num meaning                                           |
|----------------- |-------------------------------------------------------------|
| BACK_FROM_FORK   | fork id of corresponding entry in `hafd.fork`               |
| NEW_BLOCK        | number of the new block                                     |
| NEW_IRREVERSIBLE | number of the latest irreversible block                     |
| MASSIVE_SYNC     | the highest number of blocks pushed massively by hived node |

Events are ordered by the **id**, thus events that happen earlier have lower ids than subsequent events. The events queue is traversed by an app when it calls `hive.app_next_block` - the lowest event from all events with an id higher than the `event_id` stored in the app's context is chosen and processed, and at the end the context's 'event_id' is updated.

#### Optimizaton of forks
There are situations when an app doesn't have to traverse the events queue and process all the events. When there are `BACK_FROM_FORK` events ahead of a context's `event_id`, then the app can ignore all events before the fork with lower `block_num` (because all such blocks have been reverted by a fork switch). Here is a diagram to show this situation:
![](./doc/evq_events_optimization.png)

The optimization above is implemented in [src/hive_fork_manager/app_api_impl.sql](./app_api_impl.sql) in function `hive.squash_events` (which is automatically called by the `hive.app_next_block` function).

#### Optimizations of MASSIVE_SYNC_EVENTs
MASSIVE_SYNC_EVENTs are squashed - it means that the context is moved to the newest MASSIVE_SYNC_EVENT. MASSIVE_SYNC_EVENTS ensures that older blocks
are irreversible, so there is no sense to process lowest events.

#### Removing obsolete events
Once a block becomes irreversible, events related to that block which have been processed by all contexts (apps) are no longer needed by apps. These events are automatcially removed from the events queue by the function `hive.set_irreversible` (this function is periodically called by hived when the last irreversible block number changes).

#### Using hive_fork_manager_update_script_generator.sh to upgrade existing HAF database
When using HAF database, you may want to update already installed extension instead of dropping it and installing new database and filling it with data again. Using `hive_fork_manager_update_script_generator.sh` script located in `/build/extensions/hive_fork_manager`.

To use this script you have to rebuild the project and then run `hive_fork_manager_update_script_generator.sh`. If you did not build your PostgreSQL server and HAF database with recommended methods (setup scripts) you may need to use flags `--haf-admin-account=NAME` and `--haf-db-name=NAME` to change default values (haf_admin, haf_block_log).

#### How the Update Works

1. **Determine Update Feasibility**
   The script first checks if the update is possible by creating a temporary database with the new version of the `hive_fork_manager`.
   It computes the database hash using a "naked" database (only the core extension is installed, without any contexts or block data):
    - Functions from the `update.sql` file are added to the new database. This file creates a temporary schema, `hive_update`, containing utility functions for the update process.
    - Functions within the `hive_update` schema compute the database hash. The hash is based on:
        - Column definitions of tables in the `hafd` schema (excluding tables created by state providers).
        - The bodies of `start_providers` functions that are actively used in the database being updated.

2. **Compute Database Hash for the Current Database**
    - A similar procedure as above is used to compute the hash for the database being updated.
    - The `hive_update` schema is injected into the existing database using the new version's sources, it means the same
      hash algorith is used for old and new version.

3. **Compare Database Hashes**
    - The hash of the "naked" `hive_fork_manager` database is compared with the hash of the current database:
        - If the hashes are **equal**, it indicates no structural differences exist between the old and new `hafd` schema or state providers, and the update is deemed possible.
        - If the hashes **differ**, the update is impossible, and the procedure terminates.

4. Generate update extension sql script
5. Checks for any tables using types or domains from the `hive` schema:
        - If such tables exist, the update is aborted because their columns would be removed when the `hive` schema is dropped.
6. All views are saved to the `deps_saved_ddl` table. This prevents the loss of views containing elements from the `hive` schema, which would otherwise be cascade-deleted when the schema is dropped.
7. The update process executes the command: `ALTER EXTENSION hive_fork_manager UPDATE`.
    - The update script performs the following steps:
        - The `hive` schema is dropped along with all its content. The `hafd` schema remains unmodified.
        - A new version of the `hive` schema is created, containing only runtime code and excluding tables.
8. Saved views are restored.
9. Functions connected to the 'shared lib' are verified to ensure they use the correct version of the shared library.


**Warning**: The update check ensures that the database schema structure allows for the update, but it **does not guarantee compatibility of the shared library (written in C++)** with the current table content.
While most updates are compatible, changes in the shared library may introduce functionality that conflicts with the existing data.


### CONTEXT REWIND
Context_rewind is the part of the fork manager which is responsible for registering app tables and the saving/rewinding operation on the tables to handle fork switching.

Apps and hived shall not directly use any function from the [src/hive_fork_manager/context_rewind](./context_rewind/) directory.

An app must register any of its tables which are dependant on changes to hive blocks. Any table is automatically registered during its creation into context only when it inherits from hive.<context_name> table. Base table `hive.<context_name>` is always created when a context is created.

```
CREATE TABLE table1( id INTEGER ) INHERITS( hive.context )
```

Data from 'hive.<context_name>' is used by the fork manager to rewind operations. Column 'hive_rowid' is used by the system to distinguish between edited rows. During table registration, a set of triggers are enabled on the table that record any changes. 

Moreover a new table is created - a shadow table whose structure is a copy of the registered table + columns for operation registered tables. A shadow table is the place where triggers record the changes to the associated app table. A shadow table is created in the 'hive' schema and its name is created using the rule below:
```
hafd.shadow_<table_schema>_<table_name>
```
It is possible to rewind all operations stored in shadow tables with `hive.context_back_from_fork`

Because the triggers add some significant overhead when modifying app tables, in some situations it may be necessary to temporarally disable the triggers for the sake of better performance. To do this there are functions: 
* `hive.detach_table` to remove triggers
* 'hive.attach_table' to add triggers. 

When triggers are disabled, no support for fork management is enabled for a table,
so the app should solve the situation. In most cases this should only be done when irreversible blocks being processed, in which case no forks can happen there.

It is quite possible that apps which use the fork system will want to change the structure of its registered tables. This is possible only when coresponding shadow tables are empty. This means, that before an upgrade to the schema, the app must be in a state in which there is no pending fork. The system will block ( raise an exception ) 'ALTER TABLE' command if the corresponding shadow table for the table which is being altered is not empty.

When a table is edited, its shadow table is automatically adapted to the new structure (the old shadow table is dropped and a new one is created with the new structure).

## Database structure
### Fork manager
![alt text](./doc/evq_fork_db.png)

#### Reversible blocks
Tables for reversible blocks are copies of irreveersible + columns for fork_id
##### hafd.blocks_reversible
##### hafd.transactions_reversible
##### hafd.transactions_multisig_reversible
##### hafd.operations_reversible

### CONTEXT REWIND
![alt text](./doc/evq_context_rewind_db.png)

## SQL API
The set of scripts implements an API for the apps:
### Public - for the user
#### HIVED API
The functions which are used by hived
##### hive.back_from_fork( _block_num_before_fork )
Schedules back from fork

###### Schema verification

##### hive.push_block( _block, transactions[], signatures[], operations[] )
Push new block with its transactions, their operations and signatures

##### hive.set_irreversible( _block_num )
Marks a block as irreversible

#### hive.end_massive_sync(block_num)
After finishing a massive push of blocks, hived will invoke this method to schedule a MASSIVE_SYNC event. The parameter `_block_num`
is the last massively synced block - head or irreversible blocks.

#### hive.disable_indexes_of_irreversible()
There are some indexes created by the extension on irreversible block data. Those indexes may slow down massive dumps of blocks data by hived. This function drops and saves description of indexes and FK constraints created on irreversible blocks table. Hived will use this function before starting massive sync of blocks.

#### hive.enable_indexes_of_irreversible()
It restores indexes and FK constarint dropped and saved by the function above.

#### hive.connect( _git_sha, _block_num )
The Hive node (hived) calls this function each time it starts synchronization with the database. This function
clear irreversible data from inconsistent blocks (blocks which are not fully dumped during previous connection) and
saves information about the connection occurence into table hived_connections.
- **_git_sha** - is a GIT version of hived code
- **_block_num** - head block number for which the hived is synchronized

#### hive.set_irreversible_dirty()
Sets 'dirty' flag, what marks irreversible data as inconsistent.

#### hive.set_irreversible_not_dirty()
Unsets 'dirty' flag, what marks irreversible data as consistent.

#### hive.is_irreversible_dirty()
Reads the 'dirty' flag.

#### APP API
The functions which should be used by a HAF app

##### hive.app_create_context( _name, _schema, _is_forking = TRUE, _is_attached = TRUE, _stages = NULL )
Creates a new context. Context name can contain only characters from the set: `a-zA-Z0-9_`.
- '_schema' name of postgreSQL schema used by context to hold there its views
- '_is_forking' sets contexts as forking or non-forking.
- '_is_attached' if create attached or not attched context
- '_stages' optional array of stages, required for `hive.app_next_iteration`

##### hive.app_remove_context( _name hafd.context_name )
Remove the context and unregister all its tables.

##### hive.app_next_block( _context_name )
##### hive.app_next_block( _array_of_contexts )
Returns `hive.blocks_range` -range of blocks numbers to process (or NULL if no blocks to process).
It is the most important function for any app.
To ensure correct work of the fork rewind mechanism, any app must process returned blocks and modify their tables according to blockchain state on time where the returned block is a head block.

If NULL is returned, then there is no block to process, or events which did not deliver blocks were processed. 

Returns range of blocks to process. If first and last blocks in the range are the same, then an app must process the one returned block. If more than one block is returned (i.e. last_block -first_block > 0), it means that hived
executed a massive sync (or that the app has been started later than HAF server started receiving blocks) and a large number of irreversible blocks have been added to the HAF database that the app has not yet processed. The app can opt to process these blocks massively without
fork control (detach of context is required first) or it can still process them one by one (process the first_block in the range and then again call `hive.app_next_block` to get the next block, but such blocks will be processed slower than processing them in massive sync mode because of the overhead from the triggers on the app's tables that support block rewinding).

hive.app_next_block cannot be used when a context is detached - in such case an exception is thrown.

##### hive.app_context_detach( context_name )
##### hive.app_context_detach( array_of_contexts )
Detaches triggers attached to tables registered in a given context or contexts. It allows to do a massive sync of irreversible blocks without overhead from triggers. The context's views are recreated to return only all irreversible data.

##### hive.appproc_context_attach( context_name )
##### hive.appproc_context_attach( array_of_contexts )
Stored procedures. Enables triggers attached to registered tables in a given context. The context `current_block_num` cannot
be greater than the latest irreversible block. The context's views are recreated to return both reversible and irreversible data limited to the context's current block.


##### hive.app_context_attach( context_name )
##### hive.app_context_attach( array_of_contexts )
:warning: These functions have been deprecated and will be removed in future releases. They perform the same tasks as their procedural equivalents presented above, which should be used instead.
Committing pending transaction with 'COMMIT' after attaching context is mandatory, otherwise intermittent problems with finding a first event to process will occur - race conditions
between hived process and an application being moving to the next event after attach.

##### hive.app_context_is_attached( context_name )
Returns TRUE when a given context is attached. It will throw an exception when there is no a context with the given context_name.
Committing pending transaction with 'COMMIT' after attaching context is mandatory, otherwise intermittent problems with finding a first event to process will occur - race conditions
between hived process and an application being moving to the next event after attach.

##### hive.app_context_are_attached( array_of_contexts )
Equivalent of 'hive.app_context_is_attached' for a group of contexts. When an array of contexts consists attached and detached
contexts, then an exception is raised.

##### hive.app_set_current_block_num( _context_name )
##### hive.app_set_current_block_num( _array_of_contexts )
Apps should call this to set the last block of a batch of blocks processed during a massive sync.
Function will throw if it is call on an attached context (when app is processing blocks one-at-a-time).

##### hive.app_get_current_block_num( _context_name )
##### hive.app_get_current_block_num( _array_of_contexts )
Returns last block processed by the app.

#### hive.app_context_exists( context_name )
Returns TRUE when a context with the given name exists.

#### hive.app_register_table( table_name, context_name );
Register a not-already-registered table with name 'table_name' into context. It enables creation of app which automatically supports forks.

#### hive.app_get_irreversible_block( context_name DEFAULT '' )
Returns last irreversible block number, or 0 if there is no irreversible block.
When the default is passed (hive.app_get_irreversible_block() ), then it returns the current top irreversible block num known by the hive fork manager.

#### hive.app_is_forking( context_name )
Returns boolean information if a given context is forking ( returns TRUE ) or non-forking ( returns FALSE )

#### hive.app_is_forking( _array_of_contexts )
Equivalent of 'hive.app_is_forking' for a group of contexts. When an array of contexts consists forking and non-forking
contexts, then an exception is raised.

#### hive.app_context_set_non_forking( _context_name )
Sets given context as non-forking - means process only irreversible data. All the context's reversible data will be deleted.
The context will back to last processed irreversible block. 

#### hive.app_contexts_set_non_forking( _array_of_contexts )
Equivalent of 'hive.app_contexts_set_non_forking' for a group of contexts.

#### hive.app_context_set_forking( _context_name )
Sets given context as forking - means process also reversible data and rewind them during back form abandoned fork.

#### hive.app_context_set_forking( _array_of_contexts )
Equivalent of 'hive.app_context_set_forking' for a group of contexts.

#### hive.app_state_provider_import( state_provider, context )
Imports state provider into contexts - the state provider tables are created and registered in `hafd.state_providers_registered` table.

#### hive.app_state_providers_update( _first_block, _last_block, _context )
All state provider registerd by the contexts are updated.

#### hive.hive.app_state_provider_drop( state_provider, context )
State provider become unregistered from contexts, and its tables are dropped.

#### hive.app_state_provider_drop_all( context )
All state providers become unregistered from contexts,and their tables are dropped.

#### hive.get_current_stage_name( context )
Function. Returns name  of a current context stage computed by `hive.app_next_iteration`

#### hive.app_next_iteration( _array_of_contexts, [OUT] _blocks_range, _override_max_batch INTEGER = NULL )
The procedure finds a possible range of blocks to process, decides in which stage the application will work,
and attaches or detaches the context. It issues the pending transaction commit. It requires contexts 
to have defined stages. When the returned _blocks_range is NULL, it means that there were 
no blocks to process during the last call.

It is possible to override the batch size of blocks to process by using the parameter '_override_max_batch'.
With this parameter, the number of blocks to process in one turn will be less than or equal to the specified value.

#### hive.stage( hafd.stage_name, hafd.blocks_distance, hafd.blocks_count, _processing_alarm_threshold INTERVAL = '5 seconds' )
This function is designed to create a stage for application context in a
streamlined manner. Instead of directly creating the hafd.application_stage
type, use this function to ensure seamless migration of an application to
newer versions of the Hive Application Framework (HAF). This approach
provides better compatibility and maintainability across updates.

#### CONTEXT REWIND
Context rewind functions shall not be used by hived and apps.

##### hive.context_detach( context_name )
Detaches triggers atatched to register tables in a given context

##### hive.context_attach( context_name, block_num )
Enables triggers attached to register tables in a given context and set current context block num 

##### hive.context_create( context_name, forkid, irreversible_block )
Creates the context with controll block number on which the registered tables are working. The 'fork_id' and
'irreversible_block' are used only by app api.

##### hive.context_create( context_name )
Removes the context: removes triggers, remove hive_row id columns from registered tables, unregister all tables, removes
base table hive.<context>

##### hive.context_next_block( context_name )
Moves a context to the next available block

##### hive.context_back_from_fork( context_name, block_num )
Rewind only tables registered in given context to given block_num

##### hive.registered_table
Registers an user table in the fork system, is used by the trigger for CREATE TABLE

##### hive.create_shadow_table
Creates shadow table for given table

##### hive.attach_table( schema, table )
Enables triggers atatched to a register table.

##### hive.detach_table( schema, table )
Disables triggers attached to a register table. It is useful for processing irreversible block when forks are impossible, so we don't want to have trigger overhead for each modification of a table.

#### SHARED_LIB API

##### hive.get_impacted_accounts( operation_body )
Returns list of accounts ( their names ) impacted by the operation. 

###### hive_update.calculate_schema_hash()
Calculates hash for group of tables in hafd schema, used by hive.create_database_hash.
###### hive_update.create_database_hash()
Used in update procedure, creates database hash.

## Known Problems
1. FOREIGN KEY constraints must be DEFERRABLE, otherwise we cannot guarantee success rewinding changes - the process may temporarily violate tables constraints.
   More informations about DEFERRABLE constraint can be found in PosgreSQL documentation for [CREATE TABLE](https://www.postgresql.org/docs/10/sql-createtable.html)
   and [SET CONSTRAINTS](https://www.postgresql.org/docs/10/sql-set-constraints.html)
2. HAF apps usually are divided into two separate processes: an `indexer` which processes the block data written to the HAF database and generates auxiliary table data for the app, and an `API server` which responds to remote queries by formatting and returning the data generated by the indexer. In the case of a micro-fork, a race condition during a rewind of data is possible between the indexer and the API server. For example, the API server may make some action
   when some 'Account' exists, but the 'Account' is being removing by the micro-fork rewind code:
   ![race conditions](doc/race_conditions.png)
   In a such case as at the picture above, the server response for a query will fail. For most apps, there is an assumption that we can accept this situation, because the next query will be serviced properly. If this behavior isn't acceptable for an app, then it can make an exclusive lock on registered tables for a time of back from micro-fork, but the consequences would be dramatic, including the possibility of that a buggy HAF app might lock up the the whole HAF server.
      

    
## Other architectures which were abandoned
### C++-based extension for fork management
There was a hope that an extension written in C/C++ might be more performant and that access to a lower level of PostgreSQL could give some benefits.

The most important problem faced by the fork manager is to rewind reversible changes in a way which does not violate constraints on the app tables. The C++-based extension was implemented by encoding changed blobs of rows from the registered tables into byte arrays and saving them in a separated table in the order in which the changes occurred (actually a stack of changed rows was implemented). This extension was
implemented and then abandoned with the [commit](https://gitlab.syncad.com/hive/psql_tools/-/commit/e6ac13be5d137fe0de5d7fe916905a9b97a11bdc).

There were a few reasons to retreat from the C/C++-based fork manager extension:
1. The extension could cause a crash not only in the client connection but also in the main PostgreSQL server process (this occurred multiple times during development).
2. The documentation for PostgreSQL C interface is terse, and for some details PostgresSQL source code needed to be analyzed.
3. There was a doubt about portability of such an extension between different versions of PostgreSQL, indeed the extension was working with PostgreSQL 10, but did not work with PostgreSQL 13.
4. It turned out that it was impossible to execute some actions only with the C iterface and executing some SQL queries from the C++ code was required.
5. It turned out that the C/C++ extension was slower than the current SQL implementation in every test. The report is [here](https://gitlab.syncad.com/hive/psql_tools/-/blob/c1140df5f72a29df4d3d26d95f63e52595702c3c/doc/Performance.md)
6. The C/C++ version was more complicated than the SQL version. The implementation of rewinding reversible operations in C++ took more than 3 weeks, whereas implementation of similar functionality with SQL took a week.
   
### SQL extension with one stack of changes ( no shadow tables )
It turned out that it is impossible to implement with SQL a similar stack of changed rows as was implemented in the C++ extension.

There is no method to take and save a blob of a table's row in a generic form, so it is not possible to have a common table for all changes from different tables.

### SQL extension without events queue
When the SQL method of rewinding reversible tables was implemented (this part is now named `context_rewind`), there was a noble idea to use it for rewinding both the apps tables and the tables filled directly by hived. This would make for a relatively simple implementation of the whole extension - hived would have its tables registered in its context and in case of a fork switch, the block tables would be reverted.

Unfortunately, during analysis, it was found that this kind of architecture will require the use of locks on hived's tables to solve a race condition between reading of hived tables by the apps and modifications to those tables by hived. 

Introducing locking would make hived's operation dependent on the quality of the apps operating on the data - how fast they will commit transactions to release their locks on the data being written by hived. Moreover, the apps become dependant on each other, because one app may block hived and other apps would then not get new live blocks during the time that app blocked hived from adding new blocks.
