## Voting/Downvoting before paid out

### Preconditions
Users: A, B, C. User B has higher reputation than user A, A has reputation 100, and probably more initial settings for users.

It looks like a good candidate to make fixture form it.

### Some tests from https://gitlab.syncad.com/hive/hive/-/issues/505 presented as a table:(values in a tables are from thumb, they are only examples)

#### 1. User votes for the own post.
| Block | CreatePosts( users list ) | Vote( Who, Whose Post, Value) | RC( who)->value | VotingPower(who)->value | VoteAdded( who, whose post)->bool | ExpectOperation( type, ...)->bool |
|-------|---------------------------|-------------------------------|-----------------|-------------------------|-----------------------------------|-----------------------------------|
| 0     | A                         |                               |                 |                         |                                   |                                   | 
| +1    |                           | (A, A, 95%)                   | (A)->22         | (A)->30                 | (A,A)->true                       | (ecv,A vote on post A)->true      |

#### 2. User votes for the someone else's post.
| Block | CreatePosts( users list ) | Vote( Who, Whose Post, Value) | RC( who)->value | VotingPower(who)->value | VoteAdded( who, whose post)->bool | ExpectOperation( type, ...)->bool |
|-------|---------------------------|-------------------------------|-----------------|-------------------------|-----------------------------------|-----------------------------------|
| 0     | A                         |                               |                 |                         |                                   |                                   |
| +1    |                           | (B, A, 95%)                   | (B)->22         | (B)->30                 | (B,A)->true                       | (ecv,B vote on post A)->true      |

#### 3. User votes for the own comment.
| Block | CreatePosts( users list ) | Vote( Who, Whose Post, Value) | Comment( Who, Whose Post ) | RC( who)->value | VotingPower(who)->value | VoteAdded( who, post/comment description)->bool | ExpectOperation( type, ...)->bool |
|-------|---------------------------|-------------------------------|----------------------------|-----------------|-------------------------|-------------------------------------------------|-----------------------------------|
| 0     | C                         |                               |                            |                 |                         |                                                 |                                   |
| +1    |                           |                               | (A, C)                     |                 |                         |                                                 |                                   |
| +2    |                           | (A, comment A, 95%)           |                            | (A)->95         | (A)->30                 | (A, Comment A on C post )                       | (ecv,A vote on comment A)->true   |

#### 4. User votes for the someone else's comment.
| Block | CreatePosts( users list ) | Vote( Who, Whose Post, Value) | Comment( Who, Whose Post ) | RC( who)->value | VotingPower(who)->value | VoteAdded( who, post/comment description)->bool | ExpectOperation( type, ...)->bool |
|-------|---------------------------|-------------------------------|----------------------------|-----------------|-------------------------|-------------------------------------------------|-----------------------------------|
| 0     | C                         |                               |                            |                 |                         |                                                 |                                   |
| +1    |                           |                               | (A, C)                     |                 |                         |                                                 |                                   |
| +2    |                           | (B, comment A, 95%)           |                            | (B)->95         | (A)->30                 | (B, Comment A on C post )                       | (ecv,B vote on comment A)->true   |

#### 5. User downvotes for the own post.
| Block | CreatePosts( users list ) | Vote( Who, Whose Post, Value) | RC( who)->value | VotingPower(who)->value  | DownVotingPower(who)->value | VoteAdded( who, whose post)->bool | ExpectOperation( type, ...)->bool |
|-------|---------------------------|-------------------------------|-----------------|--------------------------|-----------------------------|-----------------------------------|-----------------------------------|
| 0     | A                         |                               |                 |                          |                             |                                   |                                   | 
| +1    |                           | (A, A, -95%)                  | (A)->22         |                          | (A)->30                     | (A,A)->true                       | (ecv,A vote on post A)->true      |

#### 6. User downvotes for the someone else's post.
| Block | CreatePosts( users list ) | Vote( Who, Whose Post, Value) | RC( who)->value | VotingPower(who)->value | DownVotingPower(who)->value | VoteAdded( who, whose post)->bool | ExpectOperation( type, ...)->bool |
|-------|---------------------------|-------------------------------|-----------------|-------------------------|-----------------------------|-----------------------------------|-----------------------------------|
| 0     | A                         |                               |                 |                         |                             |                                   |                                   |
| +1    |                           | (B, A, -95%)                  | (B)->22         |                         | (B)->30                     | (B,A)->true                       | (ecv,B vote on post A)->true      |

#### 7. User downvotes for the own comment.
| Block | CreatePosts( users list ) | Vote( Who, Whose Post, Value) | Comment( Who, Whose Post ) | RC( who)->value | VotingPower(who)->value  | DownVotingPower(who)->value | VoteAdded( who, post/comment description)->bool | ExpectOperation( type, ...)->bool   |
|-------|---------------------------|-------------------------------|----------------------------|-----------------|--------------------------|-----------------------------|-------------------------------------------------|-------------------------------------|
| 0     | C                         |                               |                            |                 |                          |                             |                                                 |                                     |
| +1    |                           |                               | (A, C)                     |                 |                          |                             |                                                 |                                     |
| +2    |                           | (A, comment A, -95%)          |                            | (A)->95         |                          | (A)->30                     | (A, Comment A on C post )->true                 | (ecv,A vote on comment A)->true     |

#### 8. User downvotes for the someone else's comment.
| Block | CreatePosts( users list ) | Vote( Who, Whose Post, Value) | Comment( Who, Whose Post ) | RC( who)->value | VotingPower(who)->value   | DownVotingPower(who)->value | VoteAdded( who, post/comment description)->bool | ExpectOperation( type, ...)->bool |
|-------|---------------------------|-------------------------------|----------------------------|-----------------|---------------------------|-----------------------------|-------------------------------------------------|-----------------------------------|
| 0     | C                         |                               |                            |                 |                           |                             |                                                 |                                   |
| +1    |                           |                               | (A, C)                     |                 |                           |                             |                                                 |                                   |
| +2    |                           | (B, comment A, -95%)          |                            | (B)->95         |                           | (B)->30                     | (B, Comment A on C post )->true                 | (ecv,B vote on comment A)->true   |

#### 35. User votes and later downvotes for the own comment.
| Block | CreatePosts( users list ) | Vote( Who, Whose Post, Value) | EditVote( Who, WhichVote, NewValue) | Comment( Who, Whose Post ) | RC( who)->value | VotingPower(who)->value | DownVotingPower(who)->value | VoteAdded( who, post/comment description)->bool | ExpectOperation( type, ...)->bool              |
|-------|---------------------------|-------------------------------|-------------------------------------|----------------------------|-----------------|-------------------------|-----------------------------|-------------------------------------------------|------------------------------------------------|
| 0     | C                         |                               |                                     |                            |                 |                         |                             |                                                 |                                                |
| +1    |                           |                               |                                     | (A, C)                     |                 |                         |                             |                                                 |                                                |
| +2    |                           | (A, comment A on C, 95%)      |                                     |                            | RC(A)->95       | (A)->30                 |                             | (A, Comment A on C post )                       |                                                |
| +3    |                           |                               | (A, comment A on C, 15%)            |                            | RC(A)->75       |                         | (A)->30                     |                                                 | (ecv,A vote on comment A on C decreased)->true |

#### 60. The author reputation is not reduced, when the comment is downvoted by the user with the higher reputation after paid out.
| Block | CreatePosts( users list ) | Vote( Who, Whose Post, Value)  | EditVote( Who, WhichVote, NewValue) | Comment( Who, Whose Post ) | WaitPaidOut( PostOrComment ) | RC( who )->value | VotingPower(who)->value  | DownVotingPower(who)->value | VoteAdded( who, post/comment description)->bool | ExpectOperation( type, ...)->bool                | Reputation(User)->value |
|-------|---------------------------|--------------------------------|-------------------------------------|----------------------------|------------------------------|------------------|--------------------------|-----------------------------|-------------------------------------------------|--------------------------------------------------|-------------------------|
| 0     | C                         |                                |                                     |                            |                              |                  |                          |                             |                                                 |                                                  |                         |
| +1    |                           |                                |                                     | (A, C)                     |                              |                  |                          |                             |                                                 |                                                  |                         |
| +2    |                           |                                |                                     |                            | Comment A on C post          |                  |                          |                             |                                                 |                                                  |                         |
| +234  |                           | (B, comment A on post C, -95%) |                                     |                            |                              | (B)->95          |                          | (A)->100                    | (B, vote on comment A on C decreased)->true     | (ecv,B vote on comment A on C decreased)->false  | (A)->100                |

## Implementation

In the implementation it may look very simple, the struct/dict will define all columns but for each row only interested are filled
Indeed each column represent a function, it mean all tests for votes requires about  11 functions:
1. CreatePosts
2. Vote
3. EditVote
4. Comment
5. WaitPaidout
6. RC
7. VotingPower
8. DownVotingPower
9. VoteAdded
10. ExpectOperation
11. Reputation

I suppose all of them will be implemented as simple proxies between table column content and already existed test-tools functions

Of-course it s only general idea for the tests implementation, some code which use test-tools and handle nodes behavior needs to be used.
Table values may require relative values, or some tolerance for comparison because at the moment it is impossible to predict when operation are applayed and to which blocks.

There is possibility to add logging inside each function, and enrich the main tests loop for logging and as a result get human-readable
description of test execution

### Test pseudocode
There will be only one function which travers each test table and execute test
```
for row in TestTable:
    # first execute required actions
    if row.CreatePost:
        createPost( row.CreatePost.params )
    if row.Vote:
        vote( Vote::params ) # vote may generate downvote/upvote depends on value <> 0
    if row.EditVote:
        editVote( row.EditVote.params )
    if row.Comment:
        addComment( row.Comment.params )
    if row.WaitPaidOut:
        waitForPaidout( row.WaitPaidOut.params )
    
    WaitForApplyOperations() # this function will wait for a moment where all operations above are applayed to the blockchain

    # check post-actions conditions    

    if row.RC:
        ASSERT( getRc( row.RC.params ) == row.RC.value )
    if row.VotingPower:
        ASSERT( getVotingPower( row.VotingPower.params git add) == row.VotingPower.value )
    if row.DownVotingPower:
        ASSERT( getDownVotingPower( row.DownVotingPower.params ) == row.DownVotingPower.value )
    if row.VoteAdded:
        ASSERT( isVoteAdded( row.VoteAdded.params ) == row.VoteAdded.value )
    if row.ExpectOperation:
        ASSERT( isOperationAdded( row.ExpectOperation.params ) == row.ExpectOperation.value )
    if row.Reputation:
        ASSERT( getReputation( row.Reputation.params ) == row.Reputation.value )
```