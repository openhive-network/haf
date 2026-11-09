#include <psql_utils/postgres_includes.hpp>

extern "C" {
#include <access/xact.h>
#include <catalog/pg_proc.h>
#include <common/hashfn.h>
#include <storage/proc.h>
#include <utils/memutils.h>
#include <utils/snapmgr.h>
}

/*
 * The horizon of a context's views (hive.context_view_horizon_<field>), read from the context's row in
 * hafd.contexts and cached in backend memory per snapshot, so a view may call it on every probe of a nested loop.
 *
 * A cached row is reused only while the reading snapshot would see the same row: same transaction, same
 * subtransaction (a rolled back subtransaction's writes become invisible without the snapshot changing), and a
 * snapshot whose visibility-determining contents are equal. On a miss the row is read with one SPI query, run as
 * the owner of the called function (the extension's owner), so a reader of the views needs no access to
 * hafd.contexts, while a hit costs no user switch.
 */
namespace {

struct snapshot_key
{
  LocalTransactionId lxid;
  SubTransactionId subxid;
  TransactionId xmin;
  TransactionId xmax;
  uint32 xcnt;
  int32 subxcnt;
  bool suboverflowed;
  CommandId curcid;
  uint64 xids_hash;
};

struct horizon
{
  bool found;
  int32 min_block;
  int32 irreversible_block;
  int32 current_block_num;
  bool fork_id_is_null;
  int64 fork_id;
  bool reversible_range;
};

struct cache_entry
{
  char* context; // in TopMemoryContext, nullptr for an unused entry
  int context_length;
  snapshot_key key;
  horizon value;
};

// a few contexts per backend at most: a query joining the views of several contexts keeps a hit for each
constexpr int CACHE_SIZE = 8;
cache_entry cache[ CACHE_SIZE ];
int next_replaced = 0;

SPIPlanPtr read_plan = nullptr;

snapshot_key key_of( Snapshot snapshot )
{
  snapshot_key key;
#if PG_VERSION_NUM >= 170000
  key.lxid = MyProc->vxid.lxid;
#else
  key.lxid = MyProc->lxid;
#endif
  key.subxid = GetCurrentSubTransactionId();
  key.xmin = snapshot->xmin;
  key.xmax = snapshot->xmax;
  key.xcnt = snapshot->xcnt;
  key.subxcnt = snapshot->subxcnt;
  key.suboverflowed = snapshot->suboverflowed;
  key.curcid = snapshot->curcid;
  key.xids_hash = 0;
  if ( snapshot->xcnt > 0 )
    key.xids_hash = hash_bytes_extended( reinterpret_cast< const unsigned char* >( snapshot->xip ), snapshot->xcnt * sizeof( TransactionId ), key.xids_hash );
  if ( snapshot->subxcnt > 0 )
    key.xids_hash = hash_bytes_extended( reinterpret_cast< const unsigned char* >( snapshot->subxip ), snapshot->subxcnt * sizeof( TransactionId ), key.xids_hash );
  return key;
}

bool keys_equal( const snapshot_key& a, const snapshot_key& b )
{
  return a.lxid == b.lxid && a.subxid == b.subxid && a.xmin == b.xmin && a.xmax == b.xmax && a.xcnt == b.xcnt
    && a.subxcnt == b.subxcnt && a.suboverflowed == b.suboverflowed && a.curcid == b.curcid && a.xids_hash == b.xids_hash;
}

cache_entry* find_entry( const char* context, int context_length )
{
  for ( cache_entry& entry : cache )
  {
    if ( entry.context != nullptr && entry.context_length == context_length && memcmp( entry.context, context, context_length ) == 0 )
      return &entry;
  }
  return nullptr;
}

cache_entry* new_entry( const char* context, int context_length )
{
  cache_entry* entry = &cache[ next_replaced ];
  next_replaced = ( next_replaced + 1 ) % CACHE_SIZE;
  if ( entry->context != nullptr )
    pfree( entry->context );
  entry->context = static_cast< char* >( MemoryContextAlloc( TopMemoryContext, context_length ) );
  memcpy( entry->context, context, context_length );
  entry->context_length = context_length;
  return entry;
}

Oid function_owner( Oid function_oid )
{
  HeapTuple tuple = SearchSysCache1( PROCOID, ObjectIdGetDatum( function_oid ) );
  if ( !HeapTupleIsValid( tuple ) )
    ereport( ERROR, ( errcode( ERRCODE_INTERNAL_ERROR ), errmsg( "cache lookup failed for function %u", function_oid ) ) );
  Oid owner = reinterpret_cast< Form_pg_proc >( GETSTRUCT( tuple ) )->proowner;
  ReleaseSysCache( tuple );
  return owner;
}

// Under the active snapshot (read_only), as `owner`: the caller's user and security context are restored on error too.
horizon read_horizon( text* context, Oid owner )
{
  // every operator is qualified: the read runs as the extension's owner under the caller's search_path
  static const char* const query =
    "SELECT hc.irreversible_block, hc.current_block_num, hc.fork_id, hc.is_forking"
    " FROM hafd.contexts hc WHERE hc.name OPERATOR(pg_catalog.=) $1";
  horizon result{};
  Oid saved_user;
  int saved_security_context;
  GetUserIdAndSecContext( &saved_user, &saved_security_context );
  SetUserIdAndSecContext( owner, saved_security_context | SECURITY_LOCAL_USERID_CHANGE );
  PG_TRY();
  {
    if ( SPI_connect() != SPI_OK_CONNECT )
      ereport( ERROR, ( errcode( ERRCODE_INTERNAL_ERROR ), errmsg( "hive.context_view_horizon: SPI_connect failed" ) ) );
    if ( read_plan == nullptr )
    {
      Oid argument_types[ 1 ] = { TEXTOID };
      SPIPlanPtr plan = SPI_prepare( query, 1, argument_types );
      if ( plan == nullptr )
        ereport( ERROR, ( errcode( ERRCODE_INTERNAL_ERROR ), errmsg( "hive.context_view_horizon: SPI_prepare failed: %s", SPI_result_code_string( SPI_result ) ) ) );
      if ( SPI_keepplan( plan ) != 0 )
        ereport( ERROR, ( errcode( ERRCODE_INTERNAL_ERROR ), errmsg( "hive.context_view_horizon: SPI_keepplan failed" ) ) );
      read_plan = plan;
    }
    Datum arguments[ 1 ] = { PointerGetDatum( context ) };
    int rc = SPI_execute_plan( read_plan, arguments, nullptr, true, 1 );
    if ( rc != SPI_OK_SELECT )
      ereport( ERROR, ( errcode( ERRCODE_INTERNAL_ERROR ), errmsg( "hive.context_view_horizon: reading hafd.contexts failed: %s", SPI_result_code_string( rc ) ) ) );
    if ( SPI_processed > 0 )
    {
      HeapTuple row = SPI_tuptable->vals[ 0 ];
      TupleDesc descriptor = SPI_tuptable->tupdesc;
      bool is_null = false;
      result.found = true;
      result.irreversible_block = DatumGetInt32( SPI_getbinval( row, descriptor, 1, &is_null ) );
      result.current_block_num = DatumGetInt32( SPI_getbinval( row, descriptor, 2, &is_null ) );
      result.fork_id = DatumGetInt64( SPI_getbinval( row, descriptor, 3, &result.fork_id_is_null ) );
      bool is_forking = DatumGetBool( SPI_getbinval( row, descriptor, 4, &is_null ) );
      // a context behind the irreversible block sees the irreversible blocks up to its current block only
      result.min_block = Min( result.irreversible_block, result.current_block_num );
      result.reversible_range = result.current_block_num > result.irreversible_block && is_forking;
    }
    SPI_finish();
  }
  PG_FINALLY();
  {
    SetUserIdAndSecContext( saved_user, saved_security_context );
  }
  PG_END_TRY();
  return result;
}

const horizon& context_horizon( FunctionCallInfo fcinfo )
{
  text* context = PG_GETARG_TEXT_PP( 0 );
  const char* name = VARDATA_ANY( context );
  int name_length = VARSIZE_ANY_EXHDR( context );

  bool pushed_snapshot = false;
  if ( !ActiveSnapshotSet() )
  {
    PushActiveSnapshot( GetTransactionSnapshot() );
    pushed_snapshot = true;
  }
  snapshot_key key = key_of( GetActiveSnapshot() );

  cache_entry* entry = find_entry( name, name_length );
  if ( entry == nullptr || !keys_equal( entry->key, key ) )
  {
    // read before touching the cache, so a failed read leaves no entry claiming this snapshot
    horizon value = read_horizon( context, function_owner( fcinfo->flinfo->fn_oid ) );
    if ( entry == nullptr )
      entry = new_entry( name, name_length );
    entry->key = key;
    entry->value = value;
  }

  if ( pushed_snapshot )
    PopActiveSnapshot();
  return entry->value;
}

} // namespace

extern "C"
{

PG_FUNCTION_INFO_V1( context_view_horizon_min_block );
Datum context_view_horizon_min_block( PG_FUNCTION_ARGS )
{
  const horizon& value = context_horizon( fcinfo );
  if ( !value.found )
    PG_RETURN_NULL();
  PG_RETURN_INT32( value.min_block );
}

PG_FUNCTION_INFO_V1( context_view_horizon_irreversible_block );
Datum context_view_horizon_irreversible_block( PG_FUNCTION_ARGS )
{
  const horizon& value = context_horizon( fcinfo );
  if ( !value.found )
    PG_RETURN_NULL();
  PG_RETURN_INT32( value.irreversible_block );
}

PG_FUNCTION_INFO_V1( context_view_horizon_current_block_num );
Datum context_view_horizon_current_block_num( PG_FUNCTION_ARGS )
{
  const horizon& value = context_horizon( fcinfo );
  if ( !value.found )
    PG_RETURN_NULL();
  PG_RETURN_INT32( value.current_block_num );
}

PG_FUNCTION_INFO_V1( context_view_horizon_fork_id );
Datum context_view_horizon_fork_id( PG_FUNCTION_ARGS )
{
  const horizon& value = context_horizon( fcinfo );
  if ( !value.found || value.fork_id_is_null )
    PG_RETURN_NULL();
  PG_RETURN_INT64( value.fork_id );
}

PG_FUNCTION_INFO_V1( context_view_horizon_reversible_range );
Datum context_view_horizon_reversible_range( PG_FUNCTION_ARGS )
{
  const horizon& value = context_horizon( fcinfo );
  if ( !value.found )
    PG_RETURN_NULL();
  PG_RETURN_BOOL( value.reversible_range );
}

} // extern "C"
