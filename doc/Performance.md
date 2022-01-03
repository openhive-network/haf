# Performance `C FORK_EXTENSION` vs `SQL FORK EXTENSION`
To make a comparison tests test.funcional.fork_extension.performance_.* vs test.funcional.sql_fork_extension.performance_.*

Raw SQL means operations without registration into 'fork system' - just simple sql delete/update/insert without additional costs.

## Results
| Test                        | Raw SQL [ms]               | C Fork Extension [ms]      | SQL  Fork Extension [ms] | C Fork/Raw [-]    | SQL Fork/Raw [-] | C Fork/Sql Fork [-] |
| :------------------------   | :------------              | :-----------------------   | :----------------------- | :--------         | :--------------  | :-------------------|
| Insert 10k rows in one query| 21, 20, 20 **[20]**        | 80, 81, 82 **[81]**        | 58, 58, 56 **[57]**         | 4.05           | 2.85             | 1.42                |
| Insert 10k rows one by one  | 58, 60, 58 **[59]**        | 984, 1066, 873 **[974]**   | 277, 271, 281, **[276]**    | 16.5           | 4.67             | 3.52                |
| Delete 10k rows in one query| 3.5, 3.5, 3.4 **[3.46]**   | 64, 64, 62 **[63]**        | 38, 38, 38 **[38]**         | 18.2           | 10.9             | 1.65                |
| Delete 10k rows one by one  | 3140, 3284, 3183 **[3202]**| 4351, 4589, 4251 **[4397]**| 3586, 3528, 3643 **[3585]** | 1.37           | 1.11             | 1.22                |
| Update 10k rows in one query| 22, 23, 23 **[22.6]**      | 135, 134, 132 **[134]**    | 59, 58, 60 **[59]**         | 5.9            | 2.6              | 2.23                |
| Update 10k rows one by one  | 5836, 5759, 5815 **[5803]**| 7050, 7200, 7076 **[7108]**| 6225, 6205, 6302 **[6244]** | 1.22           | 1.07             | 1.13                |
| Truncate 10k rows           | 0.26,0.29,0.49 **[0.33]**  | 63, 59, 59 **[60]**        | 33, 34, 34 **[33]**         | 181            | 100              | 1.81                |
| Back from insert 10k rows   | -------------              | 323, 373, 319 **[338]**    | 18, 18, 18 **[18]**         | ----           | ----             | 17                  |
| Back from delete 10k rows   | -------------              | 35, 38, 36 **[36.3]**      | 32, 31, 31 **[31]**         | ----           | ----             | 1.17                |
| Back from update 10k rows   | -------------              | 2306, 2321, 2419 **[2348]**| 41, 42, 43 **[42]**         | ----           | ----             | 57                  |
| Back from truncate 10k rows | -------------              | 32, 32, 35 **[33]**        | 28, 28, 28 **[28]**         | ----           | ----             | 1.17                |

* `back from fork` in C and SQL extensions implements different algorithms -C extension extracts PK from a table and
  then removes old rows with the PK (in case of DELETE pq copy is used- so it is much more faster), SQL extension uses additional column `hive_rowid` to restore old rows. It means comparison of `back from fork`
  does not make much sense here
  
