postgres_user=${POSTGRES_USER:-"haf_admin"}
postgres_host=${POSTGRES_HOST:-"localhost"}
postgres_port=${POSTGRES_PORT:-5432}
postgres_url=${POSTGRES_URL:-""}
POSTGRES_ACCESS=${postgres_url:-"postgresql://$postgres_user@$postgres_host:$postgres_port/haf_block_log"}

#drop constraints and indexes
cmd="select hive.disable_fk_of_irreversible();"
psql "$POSTGRES_ACCESS" --command="${cmd}"
cmd="select hive.disable_indexes_of_irreversible();"
psql "$POSTGRES_ACCESS" --command="${cmd}"


#restore indexes
cmd="select hive.restore_indexes( 'hive_data.blocks' );"
psql "$POSTGRES_ACCESS" --command="${cmd}" &
cmd="select hive.restore_indexes( 'hive_data.irreversible_data' );"
psql "$POSTGRES_ACCESS" --command="${cmd}" &
cmd="select hive.restore_indexes( 'hive_data.transactions' );"
psql "$POSTGRES_ACCESS" --command="${cmd}" &
cmd="select hive.restore_indexes( 'hive_data.transactions_multisig' );"
psql "$POSTGRES_ACCESS" --command="${cmd}" &
cmd="select hive.restore_indexes( 'hive_data.operations' );"
psql "$POSTGRES_ACCESS" --command="${cmd}" &
cmd="select hive.restore_indexes( 'hive_data.accounts' );"
psql "$POSTGRES_ACCESS" --command="${cmd}" &
cmd="select hive.restore_indexes( 'hive_data.account_operations' );"
psql "$POSTGRES_ACCESS" --command="${cmd}" &
cmd="select hive.restore_indexes( 'hive_data.applied_hardforks' );"
psql "$POSTGRES_ACCESS" --command="${cmd}" &

wait

