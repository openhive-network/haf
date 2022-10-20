    raise notice 'zawartosc_old=%',(select json_agg(t) FROM (SELECT * from hive.get_balance_impacting_operations_old(True)) t);
