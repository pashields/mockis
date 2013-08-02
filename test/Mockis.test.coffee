assert    = require('chai').assert
Mockis    = require '../src/Mockis'
_         = require 'underscore'

#redisModule = require 'redis'
#redis = redisModule.createClient()
redis = new Mockis()

describe 'A decent redis mock', ->
  beforeEach (done) ->
    redis.flushall ->
    done()

  #############################################################################
  # Key
  #############################################################################
  it 'should be able to expire a key', (done) ->
    redis.set 'foo', 1, (err, result) ->
      redis.expire 'foo', 1, (err, result) ->
        assert not err?
        assert.equal result, 1
        redis.get 'foo', (err, result) ->
          assert not err?
          assert.equal result, 1
          setTimeout (->
            redis.get 'foo', (err, result) ->
              assert not err?
              assert.equal result, null
              done()
            ), 1000

  it 'should be able to check if a key exists', (done) ->
    redis.exists 'foo', (err, result) ->
      assert not err?
      assert.equal result, 0
      redis.set 'foo', 1, (err) ->
        assert not err?
        redis.exists 'foo', (err, result) ->
          assert not err?
          assert.equal result, 1
          done()

  #############################################################################
  # String
  #############################################################################
  it 'should be able to save and get a key', (done) ->
    key = "foo"
    val = "bar"
    redis.set key, val, (err, result) ->
      assert not err?
      assert.equal result, "OK"
      redis.get key, (err, result) ->
        assert not err?
        assert.equal result, val
        done()

  it 'should be able to set and expire a key in one command', (done) ->
    key = "foo"
    val = "bar"
    duration = 1
    redis.setex key, duration, val, (err, result) ->
      assert not err?
      assert.equal result, "OK"
      testFn = ->
        redis.exists key, (err, result) ->
          assert not err?
          assert result is 0, "SETEX expiration didn't take"
          done()
      setTimeout testFn, 1100

  it 'should be able to do not-existing set', (done) ->
    key = "foo"
    val = "bar"
    valTwo = "not bar"
    redis.set key, val, (err, result) ->
      assert not err?
      assert.equal result, "OK"
      redis.setnx key, valTwo, (err, result) ->
        assert not err?
        assert.equal result, 0
        redis.get key, (err, result) ->
          assert not err?
          assert result isnt valTwo
          done()

  it 'should do the same crazy stuff as node redis for undefined', (done) ->
    key = "foo"
    val = undefined
    redis.set key, val, (err, result) ->
      assert not err?
      assert.equal result, "OK"
      redis.get key, (err, result) ->
        assert not err?
        assert.equal result, "undefined"
        done()

  it 'should be able to delete keys', (done) ->
    redis.set 'foo', '1', (err, result) ->
      redis.set 'bar', '1', (err, result) ->
        redis.del 'foo', 'bar', (err, result) ->
          assert not err?
          assert.equal result, 2
          redis.get 'foo', (err, result) ->
            assert not err?
            assert.isNull result
            done()

  it 'should be able to increment keys', (done) ->
    redis.incr 'foo', (err, result) ->
      assert not err?
      assert.equal result, 1
      redis.incr 'foo', (err, result) ->
        assert not err?
        assert.equal result, 2
        done()

  it 'should be able to get multiple keys at once', (done) ->
    redis.mset "a", 1, "b", 2, (err, result) ->
      assert not err?
      assert.equal result, "OK"
      redis.mget "a", "b", (err, result) ->
        assert not err?
        assert.deepEqual result, ["1", "2"]
        done()

  #############################################################################
  # Set
  #############################################################################
  it 'should be able add a member to a set', (done) ->
    redis.sadd 'a', 1, (err, result) ->
      assert not err?
      assert.equal result, 1
      done()

  it 'should have no effect to add the same element to a set twice', (done) ->
    redis.sadd 'a', 'b', (err, result) ->
      assert not err?
      assert.equal result, 1
      redis.sadd 'a', 'b', (err, result) ->
        assert not err?
        assert.equal result, 0
        done()

  it 'should be able to add multiple elements to a set at once', (done) ->
    redis.sadd 'a', 'b', 'c', 'd', 'c', (err, result) ->
      assert not err?
      assert.equal result, 3
      done()

  it 'should be able to get all elements from a set', (done) ->
    redis.sadd 'a', 'b', 'c', (err, result) ->
      redis.smembers 'a', (err, result) ->
        assert not err?
        assert.equal _.size(_.difference(result, ['b', 'c'])), 0
        done()

  it 'should be able to remove elements from the set', (done) ->
    redis.sadd 'a', ['b', 'c', 'd'], (err, result) ->
      redis.srem 'a', 'b', 'c', (err, result) ->
        assert not err?
        assert.equal result, 2
        redis.smembers 'a', (err, result) ->
          assert.deepEqual result, ['d']
          done()

  #############################################################################
  # Sorted Set
  #############################################################################
  it 'should be able to add and retrieve an element to a sorted set', (done) ->
    redis.zadd 'a', 1, 'hi', (err, result) ->
      assert not err?
      assert.equal result, 1
      redis.zrange 'a', 0, -1, 'WITHSCORES', (err, result) ->
        assert not err?
        assert.deepEqual result, ['hi', '1']
        done()

  it 'should return an empty list for a range on an empty sorted set', (done) ->
    redis.zrange 'b', 0, -1, (err, result) ->
      assert not err?
      assert.deepEqual [], result
      done()

  it 'should return the correct list for a range on a sorted set', (done) ->
    redis.zadd 'a', 1, 'hi', 2, 'bye', 3, 'test', (err, result) ->
      redis.zrange 'a', 0, -1, (err, result) ->
        assert not err?
        assert.deepEqual ['hi', 'bye', 'test'], result
        done()

  it 'should return a "reversed" empty list for a range on an empty sorted set', (done) ->
    redis.zrevrange 'b', 0, -1, (err, result) ->
      assert not err?
      assert.deepEqual [], result
      done()

  it 'should return the correct list for a range on a sorted set in reverse', (done) ->
    redis.zadd 'a', 1, 'hi', 2, 'bye', 3, 'test', (err, result) ->
      redis.zrevrange 'a', 0, -1, (err, result) ->
        assert not err?
        assert.deepEqual ['test', 'bye', 'hi'], result
        done()

  it 'should be able to remove elements from a sorted set using their rank', (done) ->
    redis.zadd 'a', 1, 'hi', 2, 'bye', 3, 'test', (err, result) ->
      redis.zremrangebyrank 'a', -2, -2, (err, result) ->
        assert not err?
        assert.equal result, 1
        redis.zrange 'a', 0, -1, (err, result) ->
          assert.deepEqual ['hi', 'test'], result
          done()

  it 'should be able to remove elements from a sorted set using their score', (done) ->
    redis.zadd 'a', 1, 'hi', 2, 'bye', 3, 'test', (err, result) ->
      redis.zremrangebyscore 'a', "-inf", 2, (err, result) ->
        assert not err?
        assert.equal result, 2
        redis.zrange 'a', 0, -1, (err, result) ->
          assert.deepEqual ['test'], result
          done()

  it 'should be able to remove elements from a sorted set using by member', (done) ->
    redis.zadd 'a', 1, 'hi', 2, 'bye', 3, 'test', (err, result) ->
      redis.zrem 'a', 'bye', 'test', (err, numRemoved) ->
        assert not err?
        assert.equal numRemoved, 2
        redis.zrange 'a', 0, -1, (err, result) ->
          assert.deepEqual ['hi'], result
          done()

  #############################################################################
  # Hash
  #############################################################################
  it 'should be able to set and get element in a hash', (done) ->
    redis.hset 'a', 'a', 1, (err, result) ->
      assert not err?
      assert.equal result, 1
      redis.hget 'a', 'a', (err, result) ->
        assert not err?
        assert.equal result, 1
        done()

  it 'should be able to get all elements from a hash', (done) ->
    redis.hset 'a', 'a', 1, (err, result) ->
      redis.hset 'a', 'b', 1, (err, result) ->
        redis.hgetall 'a', (err, result) ->
          assert not err?
          expected =
            a: '1'
            b: '1'
          assert.deepEqual result, expected
          done()

  it 'should be able to set multiple hash fields at once', (done) ->
    redis.hmset 'a', {a:1, b:1}, (err, result) ->
      assert not err?
      redis.hgetall 'a', (err, result) ->
        assert not err?
        expected =
          a: '1'
          b: '1'
        assert.deepEqual result, expected
        done()

  #############################################################################
  # Transactions
  #############################################################################
  it 'should be able to perform multi/exec transactions', (done) ->
    redis.multi().set('a', 1).set('b', 2).exec (err, result) ->
      assert not err?
      assert.deepEqual result, ["OK", "OK"]
      done()

  it 'should be able to use watch to guarantee atomicity', (done) ->
    redis.set 'a', 1, (err, result) ->
      assert not err?
      redis.watch 'a', (err, result) ->
        assert not err?
        redis.set 'a', 2, (err, result) ->
          redis.multi().get('a').exec (err, result) ->
            assert not err?
            assert.isNull result, "Watch before exec didn't fail"
            done()

  it 'should be able to use watch when it is unrelated', (done) ->
    redis.set 'a', 1, (err, result) ->
      assert not err?
      redis.watch 'b', (err, result) ->
        assert not err?
        redis.set 'a', 2, (err, result) ->
          redis.multi().get('a').exec (err, result) ->
            assert not err?
            assert.deepEqual result, ['2'], "Watch failed when it shouldn't have"
            done()

  it 'should be able to unwatch a key', (done) ->
    redis.watch 'a', (err, result) ->
      assert not err?
      redis.set 'a', 1, (err, result) ->
        assert not err?
        redis.unwatch (err, result) ->
          assert not err?
          redis.multi().get('a').exec (err, result) ->
            assert not err?
            assert.deepEqual result, ['1'], "Watch failed when it shouldn't have"
            done()
