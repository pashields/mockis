# Mockis
A self indulgent coffeescript mock of redis.

### Status
[![Build Status](https://travis-ci.org/pashields/mockis.png?branch=master)](https://travis-ci.org/pashields/mockis)

It works for certain things. It should match the success behavior of the node_redis library. Failure behavior may not match, but we try to do something sane.

It's also very incomplete. I've implemented the basic things I need. I will try to add other things as well, but if it's missing things you need, send a PR.

### Limitations
Currently there is no way to have two instances of Mockis pointing at the same storage, but this shouldn't be two difficult to change.

Also it doesn't support all caps commands. This is easy to fix, BUT WHY?

### Supported Commands
##### Keys
 * expire
 * exists
 * ttl

##### Strings
 * set
 * setex
 * setnx
 * get
 * del
 * incr
 * mget
 * mset

##### Sets
 * sadd
 * smembers
 * srem
 * sismember

##### Sorted Sets
 * zadd
 * zrange
 * zrevrange
 * zremrangebyscore
 * zrem
 * zremrangebyrank

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
 * watch
 * unwatch

### Contribution
Contributions are totes welcome. When possible, please submit a PR for each command. This isn't a requirement, but it can streamline reviewing them.

All methods must call callbacks synchronously. Multi requires it.

Please create at least the most basic of tests for any command you add. Also, test only pull requests are greatly appreciated.

### Alternatives
 * [redis-mock](https://github.com/faeldt/redis-mock)

### License
Apache 2.0

### Author(s)
 * Pat Shields (Adzerk)
