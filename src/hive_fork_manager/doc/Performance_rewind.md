# Performance `OPTIMIZED REWIND` vs `ONE BY ONE REVERT`
To make a comparison tests test.funcional.fork_extension.performance_.* vs test.funcional.sql_fork_extension.performance_.*

OPTIMIZED REWIND - fully optimized  rewind queries with only rewert first  operation in blocks range for a given row
ONE BY ONE REVERT - current implementation which revert opertions one by one in a given blocks range

Little slowdown of insert, delete and update operation is an effect of adding index for row_id for each registered table.
This is required to speeds up rewind about 100x.

## Results
| Test                        | OPTIMIZED REWIND [ms]        | ONE BY ONE REVERT [ms]          | OnybyOne/Optimized [-]|
| :------------------------   | :-----------------------     | :---------------------------    | :-------------------  |
| Insert 10k rows in one query| 55, 55, 55           **[55]**| 64, 64, 63            **[63.6]**|   1.16                |
| Insert 10k rows one by one  | 285, 277, 282     **[281.3]**| 318, 293, 298          **[303]**|   1.08                |
| Delete 10k rows in one query| 20, 20, 22         **[20.6]**| 38, 38, 40            **[38.7]**|   1.88                |
| Delete 10k rows one by one  | 3670, 3635, 3688 **[3664.3]**| 3646, 3627, 3586      **[3620]**|   0.99                |
| Update 10k rows in one query| 56, 56, 57         **[57.6]**| 65, 66, 67              **[66]**|   1.14                |
| Update 10k rows one by one  | 6368, 6478, 6494 **[6446.6]**| 6322, 6366, 6507      **[6398]**|   0.99                |
| Truncate 10k rows           | 31, 31, 31           **[31]**| 34, 33, 34            **[33.7]**|   1.09                |
| Back from insert 10k rows   | 23, 24, 23         **[23.3]**| 124, 124, 125        **[124.3]**|   5.33                |
| Back from delete 10k rows   | 36, 35, 36         **[35.6]**| 174, 169, 170          **[171]**|   4.80                |
| Back from update 10k rows   | 48, 48, 48           **[48]**| 238, 245, 239        **[240.7]**|   5.01                |
| Back from truncate 10k rows | 32, 31, 32         **[35.6]**| 166, 173, 166        **[168.3]**|   4.72                |


