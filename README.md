# Mockis
A self indulgent coffeescript mock of redis.

### Status
[![Build Status](https://travis-ci.org/pashields/mockis.png?branch=master)](https://travis-ci.org/pashields/mockis)

It works for certain things. It should match the success behavior of the node_redis library. Failure behavior may not match, but we try to do something sane.

It's also very incomplete. I've implemented the basic things I need. I will try to add other things as well, but if it's missing things you need, send a PR.

### Supported Commands
##### Keys
 * expire
 * exists
 * ttl
 * persist

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

##### Pub/sub
 * subscribe
 * unsubscribe
 * publish

##### Transactions
 * multi
 * exec
 * discard
 * watch
 * unwatch

### Sharing storage between mockis instances
Multiple instances of Mockis can share the same storage like such:

```coffeescript
parent = new Mockis()
child = new Mockis()
parent.addChild(child)

child.set "foo", "bar", ->
  parent.get "foo", (err, result) ->
    result is "bar" # true
```

One important note about this is that if the child already has data, it will be lost. There is no merge.

Parents can have arbitrary numbers of children. The whole children of children thing can get wacky. Don't do it.

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
