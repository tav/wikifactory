# Public Domain (-) 2014 The Wikifactory Authors.
# See the Wikifactory UNLICENSE file for details.

define 'µ', (µ, root) ->

  root.mu = µ
  µ._ = _ = {}

  _.noop = noop = ->
    return

  _.isArray = root.Array.isArray

  _.isError = (err) ->
    err instanceof Error

  _.isFn = isFn = (fn) ->
    typeof fn is 'function'

  _.keys = root.Object.keys

  console = root.console
  if typeof console is 'object'
    if not isFn console.log
      console.log = noop
    if not isFn console.error
      console.error = console.log
  else
    console =
      log: noop
      error: noop

  _.console = console

  now = root.Date.now
  if COMPAT
    if now is undefined
      now = ->
        (new Date).getTime()

  µ.now = now

  return
