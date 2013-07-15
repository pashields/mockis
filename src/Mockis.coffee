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
    @addFn name, fn for name, fn of Mockis.prototype

  addFn: (name, fn) ->
    @[name] = =>
      op =
        name: name,
        args: argsToArray arguments,
      @buffer.push op
      @

  discard: ->
    @buffer = []

  exec: (callback) ->
    bufferIterator = =>
      i = 0
      {next: => @buffer[i++]}

    iter = bufferIterator()
    results = []

    callNextOp = (err) =>
      callback err, null if err?
      op = iter.next()
      if not op?
        callback err, results
      else
        @mockis[op.name].apply @mockis, op.args

    for op in @buffer
      op.args.push (err, result) =>
        results.push result
        callNextOp(err)

    callNextOp()

class Mockis

  constructor: ->
    @storage = {}

  #############################################################################
  # Key
  #############################################################################
  expire: ->
    [key, time, callback] = splitThree arguments

    res = Number(@storage[key]?)

    if res is 1
      setTimeout (=>
        delete @storage[key] if @storage[key]?
        ), time * 1000

    callback null, res

  exists: ->
    [key, callback] = splitTwo arguments

    callback null, Number(@storage[key]?)

  #############################################################################
  # Strings
  #############################################################################
  set: ->
    [key, val, callback] = splitThree arguments

    @storage[key] = String(val)
    callback null, "OK"

  setex: ->
    [key, time, val, callback] = splitFour arguments
    @set key, val, (err, result) =>
      @expire key, time, (err, result) ->
        callback null, "OK"

  get: (key, callback) ->
    [key, callback] = splitTwo arguments
    callback null, @storage[key] or null

  del: ->
    [keys, callback] = splitTwo arguments

    keys = [keys] unless _.isArray keys

    keys = _.filter keys, (key) => @storage[key]?
    delete @storage[key] for key in keys
    callback null, _.size keys

  incr: ->
    [key, callback] = splitTwo arguments

    @storage[key] ?= 0
    
    callback null, ++@storage[key]

  #############################################################################
  # Set
  #############################################################################
  sadd: ->
    [key, mems, callback] = splitThree arguments

    mems = [mems] unless _.isArray mems

    @storage[key] ?= []
    startSize = _.size @storage[key]
    @storage[key].push mem for mem in mems
    @storage[key] = _.uniq @storage[key]

    callback null, _.size(@storage[key]) - startSize

  smembers: (key, callback) ->
    [key, callback] = splitTwo arguments
    if @storage[key]?
      mems = @storage[key]
    else
      mems = []

    callback null, mems

  srem: ->
    [key, mems, callback] = splitThree arguments

    numRemoved = 0
    if @storage[key]?
      startSize = _.size @storage[key]
      @storage[key] = _.difference @storage[key], mems
      numRemoved = startSize - _.size @storage[key]

    callback null, numRemoved

  #############################################################################
  # Sorted Set
  #############################################################################
  zadd: ->
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

  zrange: ->
    [key, args, callback] = splitThree arguments

    return callback null, [] if not @storage[key]?

    if _.size(args) is 2
      [start, stop] = args
    else
      [start, stop, withScores] = args

    withScores = withScores? and withScores.toUpperCase() is 'WITHSCORES'

    if start < 0 
      start = _.size(@storage[key]) + ++start
    if stop < 0
      stop = if stop is -1 then undefined else _.size(@storage[key]) + ++stop

    selected = @storage[key].slice(start, stop)
    mems = _.pluck selected, "value"
    if withScores 
      scos = _.map(selected, (elem) -> String(elem.score))
      res = _.flatten _.zip(mems, scos)
    else
      res = mems

    callback null, res

  zremrangebyscore: ->
    [key, min, max, callback] = splitFour arguments

    return 0 unless @storage[key]?

    startSize = _.size @storage[key]

    @storage[key] = _.filter @storage[key], (elem) ->
      not ((elem.score >= min or (typeof min is "string" and min.toLowerCase() is "-inf")) and
      (elem.score <= max or (typeof max is "string" and max.toLowerCase() is "inf")))

    callback null, startSize - _.size @storage[key]

  zrem: ->
    [key, args, callback] = splitThree arguments

    return callback null, 0 if not @storage[key]?

    startSize = _.size @storage[key]

    @storage[key] = _.filter @storage[key], (elem) ->
      debugger
      not _.contains args, elem.value

    callback null, startSize - _.size @storage[key]

  #############################################################################
  # Hash
  #############################################################################
  hset: ->
    [key, hashKey, value, callback] = splitFour arguments
    @storage[key] ?= {}

    numAdded = Number(not @storage[key][hashKey]?)

    @storage[key][hashKey] = String(value)

    callback null, numAdded

  hmset: ->
    [key, fields, callback] = splitThree arguments

    # Support both object and array inputs
    if _.isArray fields
      fields = chunkTwo fields
    else
      fields = _.pairs fields

    @storage[key] ?= {}

    @storage[key][hashKey] = String(value) for [hashKey, value] in fields

    callback null, "OK"

  hget: ->
    [key, hashKey, callback] = splitThree arguments

    if not @storage[key]? or not @storage[key][hashKey]?
      callback null, null
    else
      callback null, @storage[key][hashKey]

  hgetall: (key, callback) ->
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

  #############################################################################
  # Server
  #############################################################################
  flushall: (callback) ->
    @storage = {}
    callback null

module.exports = Mockis