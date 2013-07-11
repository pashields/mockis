# Mockis
A self indulgent coffeescript mock of redis.

### Status
It works for certain things. It should match the success behavior of the node_redis library. Failure behavior may not match, but we try to do something sane.

It's also very incomplete. I've implemented the basic things I need. I will try to add other things as well, but if it's missing things you need, send a PR.

### Limitations
Currently there is no way to have two instances of Mockis pointing at the same storage, but this shouldn't be two difficult to change.

Also it doesn't support all caps commands. This is easy to fix, BUT WHY?

### Supported Commands
##### Keys
 * expire
 * exists

##### Strings
 * set
 * get
 * del
 * incr

##### Sets
 * sadd
 * smembers
 * srem

##### Sorted Sets
 * zadd
 * zrange
 * zremrangebyscore
 * zrem
 
##### Hashes
 * hset
 * hget
 * hgetall
 * hmset

##### Server
 * flushall

##### Transactions
 * multi
 * exec
 * discard

### Contribution
Contributions are totes welcome. When possible, please submit a PR for each command. This isn't a requirement, but it can streamline reviewing them.

Please create at least the most basic of tests for any command you add. Also, test only pull requests are greatly appreciated.

### Alternatives
 * [redis-mock](https://github.com/faeldt/redis-mock)

### License
Apache 2.0

### Author(s)
 * Pat Shields (Adzerk)
