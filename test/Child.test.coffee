assert    = require('chai').assert
Mockis    = require '../src/Mockis'
_         = require 'underscore'

describe "A parent and a child mockis", ->
  child = new Mockis()
  parent = new Mockis()
  parent.set
  parent.addChild child

  beforeEach (done) ->
    child.flushall ->
      parent.flushall ->
        done()

  it 'should propagate changes from the child to parent', (done) ->
    child.set 'foo', 1, (err, result) ->
      assert not err?
      parent.get 'foo', (err, result) ->
        assert not err?
        assert result is "1", "result not propagated"
        done()

  it 'should propagate changes from the parent to the child', (done) ->
    parent.set 'foo', 1, (err, result) ->
      assert not err?
      child.get 'foo', (err, result) ->
        assert not err?
        assert result is "1", "result not propagated"
        done()

  it 'should be able to publish changes on the parent and recieve them on the child', (done) ->
    child.on 'subscribe', (channel, count) ->
      assert.equal channel, "foo"
      assert.equal count, 1
      child.on 'message', (channel, message) ->
        assert.equal channel, "foo"
        assert.equal message, "bar"
        done()
      parent.publish "foo", "bar"
    child.subscribe "foo"

describe "A mockis that has subscribed to a channel", ->
  mockis = new Mockis()
  mockis.subscribe("funny stuff from the internet")
  it 'will emit an error when trying to call other commands', (done) ->
    mockis.on "error", (error) ->
      done()
    mockis.get('a')

  it 'can unsubscribe from that channel and begin issuing commands', (done) ->
    mockis.on "unsubscribe", ->
      mockis.get "foo", ->
        done()
    mockis.unsubscribe("funny stuff from the internet") # NO BUZZFEED
