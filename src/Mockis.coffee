_ = require 'underscore'

argsToArray = (rawArgs) ->
  len  = rawArgs.length
  args = new Array(len)
  args[i] = rawArgs[i] for i in [0...len]

  _.flatten args

argSplitter = (numChunks, rawArgs) ->
  args = argsToArray rawArgs

  return args if _.size(args) is numChunks

  splitArgs = _.take args, numChunks-2
  splitArgs.push args.slice numChunks-2, _.size(args) - 1
  splitArgs.push _.last args
  splitArgs

chunk = (chunkSize, arr) ->
  arr.slice i, i + chunkSize for i in [0..._.size(arr)] by chunkSize

splitTwo   = _.partial argSplitter, 2
splitThree = _.partial argSplitter, 3
splitFour  = _.partial argSplitter, 4

chunkTwo = _.partial chunk, 2

class Multi
  constructor: (@mockis) ->
    @buffer = []
    @addFn name, @mockis[name] for name in _.functions(@mockis)

  addFn: (name, fn) ->
    @[name] = =>
      op =
        name: name,
        args: argsToArray arguments,
      @buffer.push op
      @

  watchesAreSafe: ->
    _.all @mockis.watchList, (val, key) =>
      return _.isEqual val, (@mockis.storage[key] or null)

  discard: ->
    @buffer = []

  exec: (callback) ->
    watchesAreSafe = @watchesAreSafe()

    # Clear watch list
    @mockis.watchList = {}

    return callback null, null unless watchesAreSafe

    results = []
    for op in @buffer
      op.args.push (err, result) -> [err, result]
      [err, result] = @mockis['_' + op.name].apply @mockis, op.args
      return callback err if err?
      results.push result

    callback null, results

class Mockis

  constructor: ->
    @storage = {}
    @watchList = {}
    @expireList = {}
    @expireTimers = {}

    # wrap all the redis fns so that they in turn can wrap their callback in
    # a process.nextTick. I am clear that this is insane.
    fns = _.filter _.functions(@), (key) ->
      key[0] is '_'
    _.each fns, (fn) =>
      @[fn.substr(1)] = =>
        callback = _.last arguments
        arguments[arguments.length - 1] = ->
          callbackArgs = arguments
          process.nextTick ->
            callback.apply null, callbackArgs
        @[fn].apply @, arguments

  #############################################################################
  # Key
  #############################################################################
  _expire: ->
    [key, time, callback] = splitThree arguments

    res = Number(@storage[key]?)

    @expireList[key] = new Date().valueOf() + time * 1000
    clearTimeout(@expireTimers[key]) if @expireTimers[key]?

    if res is 1
      @expireTimers[key] = setTimeout (=>
        delete @storage[key] if @storage[key]?
        delete @expireList[key]
        delete @expireTimers[key]
        ), time * 1000
    callback null, res

  _ttl: ->
    [key, callback] = splitTwo arguments

    res = if @expireList[key]?
      @expireList[key] - new Date()
    else
      -1

    callback null, res

  _persist: ->
    [key, callback] = splitTwo arguments
    isttld = @expireTimers[key]?

    clearTimeout(@expireTimers[key]) if isttld
    delete @expireList[key]

    callback null, Number(isttld)

  _exists: ->
    [key, callback] = splitTwo arguments

    callback null, Number(@storage[key]?)

  #############################################################################
  # Strings
  #############################################################################
  _set: ->
    [key, val, callback] = splitThree arguments

    return callback "set value must not be undefined or null, is #{val}", null unless val?

    @storage[key] = String(val)
    callback null, "OK"

  _mset: ->
    [pairs, callback] = splitTwo arguments
    pairs = chunkTwo pairs

    if _.size(_.compact(pairs)) isnt _.size(pairs)
      return callback "set value must not be undefined or null", null

    @storage[key] = String(val) for [key, val] in pairs
    callback null, "OK"

  _setex: ->
    [key, time, val, callback] = splitFour arguments

    return callback "set value must not be undefined or null, is #{val}", null unless val?

    @_set key, val, (err, result) =>
      @_expire key, time, (err, result) ->
        callback null, "OK"

  _setnx: ->
    [key, val, callback] = splitThree arguments

    return callback "set value must not be undefined or null, is #{val}", null unless val?

    ret = if @storage[key]? then 0 else 1
    @storage[key] ?= val

    callback null, ret

  _get: (key, callback) ->
    [key, callback] = splitTwo arguments
    callback null, @storage[key] or null

  _mget: ->
    [keys, callback] = splitTwo arguments

    keys = [keys] unless _.isArray keys

    vals = _.map keys, (key) => @storage[key]
    callback null, vals

  _del: ->
    [keys, callback] = splitTwo arguments

    keys = [keys] unless _.isArray keys

    keys = _.filter keys, (key) => @storage[key]?
    delete @storage[key] for key in keys
    callback null, _.size keys

  _incr: ->
    [key, callback] = splitTwo arguments

    @storage[key] ?= 0

    callback null, ++@storage[key]

  #############################################################################
  # Set
  #############################################################################
  _sadd: ->
    [key, mems, callback] = splitThree arguments

    mems = [mems] unless _.isArray mems

    @storage[key] ?= []
    startSize = _.size @storage[key]
    @storage[key].push mem for mem in mems
    @storage[key] = _.uniq @storage[key]

    callback null, _.size(@storage[key]) - startSize

  _smembers: (key, callback) ->
    [key, callback] = splitTwo arguments
    if @storage[key]?
      mems = @storage[key]
    else
      mems = []

    callback null, mems

  _srem: ->
    [key, mems, callback] = splitThree arguments

    numRemoved = 0
    if @storage[key]?
      startSize = _.size @storage[key]
      @storage[key] = _.difference @storage[key], mems
      numRemoved = startSize - _.size @storage[key]

    callback null, numRemoved

  _sismember: ->
    [key, member, callback] = splitThree arguments

    return callback null, 0 unless @storage[key]?

    if _.contains @storage[key], member
      callback null, 1
    else
      callback null, 0

  #############################################################################
  # Sorted Set
  #############################################################################
  _zadd: ->
    [key, mems, callback] = splitThree arguments

    mems = chunkTwo mems

    @storage[key] ?= []
    startSize = _.size @storage[key]

    for [score, value] in mems
      existingMem = _.find @storage[key], (potMem) ->
        potMem.value is value

      if existingMem?
        existingMem.score = score
      else
        @storage[key].push {score, value}

    _.sortBy @storage[key], (a, b) -> a.score > b.score

    callback null, _.size(@storage[key]) - startSize

  __zrangeHelper: (key, args, callback, orderingFn) ->
    return callback null, [] if not @storage[key]?

    if _.size(args) is 2
      [start, stop] = args
    else
      [start, stop, withScores] = args

    withScores = withScores? and withScores.toUpperCase() is 'WITHSCORES'

    if start < 0
      start = _.size(@storage[key]) + start
    if stop < 0
      stop = if stop is -1 then undefined else _.size(@storage[key]) + ++stop

    selected = @storage[key].slice(start, stop)
    selected = orderingFn(selected) if orderingFn?

    mems = _.pluck selected, "value"
    if withScores
      scos = _.map(selected, (elem) -> String(elem.score))
      res = _.flatten _.zip(mems, scos)
    else
      res = mems

    callback null, res

  _zrange: ->
    [key, args, callback] = splitThree arguments
    @__zrangeHelper key, args, callback

  _zrevrange: ->
    [key, args, callback] = splitThree arguments
    @__zrangeHelper key, args, callback, (x) -> _.clone(x).reverse()

  _zremrangebyscore: ->
    [key, min, max, callback] = splitFour arguments

    return 0 unless @storage[key]?

    startSize = _.size @storage[key]

    @storage[key] = _.filter @storage[key], (elem) ->
      not ((elem.score >= min or (typeof min is "string" and min.toLowerCase() is "-inf")) and
      (elem.score <= max or (typeof max is "string" and max.toLowerCase() is "inf")))

    callback null, startSize - _.size @storage[key]

  _zremrangebyrank: ->
    [key, start, stop, callback] = splitFour arguments

    return 0 unless @storage[key]?

    @_zrange key, [start, stop], (err, elemsToRemove) =>
      startSize = _.size @storage[key]
      @storage[key] = _.filter @storage[key], (elem) ->
        not _.contains elemsToRemove, elem.value
      callback null, startSize - _.size @storage[key]

  _zrem: ->
    [key, args, callback] = splitThree arguments

    return callback null, 0 if not @storage[key]?

    args = [args] unless _.isArray(args)

    startSize = _.size @storage[key]

    @storage[key] = _.filter @storage[key], (elem) ->
      not _.contains args, elem.value

    callback null, startSize - _.size @storage[key]

  #############################################################################
  # Hash
  #############################################################################
  _hset: ->
    [key, hashKey, value, callback] = splitFour arguments
    @storage[key] ?= {}

    numAdded = Number(not @storage[key][hashKey]?)

    @storage[key][hashKey] = String(value)

    callback null, numAdded

  _hmset: ->
    [key, fields, callback] = splitThree arguments

    # Support both object and array inputs
    if _.isArray fields
      fields = chunkTwo fields
    else
      fields = _.pairs fields

    @storage[key] ?= {}

    @storage[key][hashKey] = String(value) for [hashKey, value] in fields

    callback null, "OK"

  _hget: ->
    [key, hashKey, callback] = splitThree arguments

    if not @storage[key]? or not @storage[key][hashKey]?
      callback null, null
    else
      callback null, @storage[key][hashKey]

  _hgetall: (key, callback) ->
    [key, callback] = splitTwo arguments

    if not @storage[key]?
      callback null, {}
    else
      callback null, _.clone @storage[key]

  #############################################################################
  # Transactions
  #############################################################################
  multi: ->
    new Multi(@)

  _watch: ->
    [key, callback] = splitTwo arguments

    @watchList[key] ?= @storage[key] or null

    callback null, "OK"

  _unwatch: (callback) ->
    @watchList = {}

    callback null, "OK"

  #############################################################################
  # Server
  #############################################################################
  _flushall: (callback) ->
    @storage = {}
    clearTimeout timeout for timeout in @expireTimers
    @watchList = {}
    @expireList = {}
    @expireTimers = {}
    callback null

module.exports = Mockis
